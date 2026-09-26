extends SceneTree
## Godot 4.6.3 functional regression. Run after the GLB has been imported:
## godot --headless --path godot_project --script res://tools/verify_production_motion.gd
## No headless FPS or graphical-performance conclusions are made.
## Only this test creates the isolated physics fixture; production nodes are unchanged.

const EXPECTED := {
	"IdleArmed": [3.0, true], "WalkArmed": [1.2, true],
	"RunArmed": [0.8, true], "AimArmed": [3.0, true],
	"FireArmed": [0.267, false], "ReloadArmed": [2.8, false],
	"HitReact": [0.667, false],
}
const ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "sprint", "aim", "fire", "reload"]
const ORIGIN := Vector3(1000.0, 0.0, 1000.0)
const FRAME_TOLERANCE := 1.0 / 30.0 + 0.002
var checks: Array[Dictionary] = []
var failures: int = 0
var world: Node
var player: CharacterBody3D
var anim: AnimationPlayer # Active upper-body player, not the stopped import source.
var lower_anim: AnimationPlayer
var source_anim: AnimationPlayer
var skeleton: Skeleton3D
var starts: Dictionary = {}
var finishes: Dictionary = {}
var finishing := false
var original_mouse_mode: int
var original_max_fps: int
var started_msec: int

func _init() -> void:
	call_deferred("_run")

func _check(id: String, passed: bool, details: Dictionary = {}) -> void:
	checks.append({"id": id, "passed": passed, "details": details})
	if not passed:
		failures += 1
	print("[%s] %s %s" % ["PASS" if passed else "FAIL", id, JSON.stringify(details)])

func _run() -> void:
	started_msec = Time.get_ticks_msec()
	original_mouse_mode = Input.mouse_mode
	original_max_fps = Engine.max_fps
	Engine.max_fps = 60
	create_timer(120.0, true, false, true).timeout.connect(_watchdog)
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check("scene.load", packed != null)
	if packed == null:
		await _finish()
		return
	world = packed.instantiate()
	packed = null
	get_root().add_child(world)
	await process_frame
	await process_frame
	player = world.get_node_or_null("Player") as CharacterBody3D
	_check("scene.player", player != null)
	if player == null:
		await _finish()
		return
	var model := player.get_node_or_null("Model")
	source_anim = _find_type(model, "AnimationPlayer") as AnimationPlayer
	if _has_property(player, "_upper_anim"):
		anim = player.get("_upper_anim") as AnimationPlayer
	if _has_property(player, "_anim"):
		lower_anim = player.get("_anim") as AnimationPlayer
	skeleton = _find_type(model, "Skeleton3D") as Skeleton3D
	_check("scene.animation_source", source_anim != null)
	_check("scene.animation_player", anim != null and lower_anim != null)
	_check("scene.skeleton", skeleton != null and skeleton.get_bone_count() > 0)
	if anim == null or lower_anim == null or source_anim == null or skeleton == null:
		await _finish()
		return
	var api_ok := true
	for method in ["_start_fire", "_start_reload", "receive_hit", "_set_look", "_unhandled_input"]:
		var exists: bool = player.has_method(method)
		_check("api.method." + method, exists)
		api_ok = api_ok and exists
	for field in ["ammo", "reserve_ammo", "is_reloading", "current_action", "max_ammo", "_yaw", "_pitch", "_velocity_y", "locomotion_state", "action_locked", "horizontal_speed"]:
		var exists := _has_property(player, field)
		_check("api.property." + field, exists)
		api_ok = api_ok and exists
	for action in ACTIONS:
		var exists := InputMap.has_action(action)
		_check("input.mapping." + action, exists)
		api_ok = api_ok and exists
	anim.animation_started.connect(_on_started)
	anim.animation_finished.connect(_on_finished)
	_validate_clips()
	_validate_layers()
	if api_ok:
		# Verify the real main-scene floor before moving to an obstacle-free fixture.
		await _wait(1.5)
		var room_y := player.global_position.y
		_check("ground.main_scene_landed", player.is_on_floor() and room_y > -1.0, {"y": room_y})
		await _wait(0.5)
		_check("ground.main_scene_stable", player.is_on_floor() and absf(player.global_position.y - room_y) < 0.03)
		_create_floor()
		await _reset_player(0.0)
		var landed_y := player.global_position.y
		_check("ground.fixture_landed", player.is_on_floor() and absf(landed_y) < 0.12, {"y": landed_y})
		await _wait(0.75)
		_check("ground.fixture_stable", player.is_on_floor() and absf(player.global_position.y - landed_y) < 0.02)
		await _test_directions()
		await _test_locomotion()
		await _test_combat()
		await _test_layered_actions()
		await _test_airborne()
		await _test_missing_reload_clip()
		await _test_mouse_look()
	await _finish()

func _find_type(node: Node, type_name: String) -> Node:
	if node == null:
		return null
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _find_type(child, type_name)
		if found != null:
			return found
	return null

func _has_property(object: Object, field: String) -> bool:
	for property in object.get_property_list():
		if String(property.name) == field:
			return true
	return false

func _resolve_clip(layer: AnimationPlayer, clip: String) -> StringName:
	if layer.has_animation(clip):
		return StringName(clip)
	for name in layer.get_animation_list():
		if String(name).get_file() == clip:
			return name
	return &""

func _validate_clips() -> void:
	var animation_root := source_anim.get_node_or_null(source_anim.root_node)
	for clip in EXPECTED:
		var imported_name := _resolve_clip(source_anim, clip)
		var exists := imported_name != &""
		_check("clip.%s.exists" % clip, exists, {"available": Array(source_anim.get_animation_list())})
		if not exists:
			continue
		var animation: Animation = source_anim.get_animation(imported_name)
		var expected_length: float = EXPECTED[clip][0]
		var looping: bool = EXPECTED[clip][1]
		_check("clip.%s.duration" % clip, absf(animation.length - expected_length) <= FRAME_TOLERANCE,
			{"expected": expected_length, "actual": animation.length, "tolerance": FRAME_TOLERANCE})
		# Imported loop metadata is not authoritative; runtime copies set it explicitly.
		for layer in [lower_anim, anim]:
			var has_runtime_clip: bool = layer.has_animation(clip)
			_check("clip.%s.%s.runtime_exists" % [clip, layer.name], has_runtime_clip)
			if has_runtime_clip:
				_check("clip.%s.%s.loop_mode" % [clip, layer.name], layer.get_animation(clip).loop_mode == (Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE))
		var bone_tracks := 0
		var rotation_tracks := 0
		for track in range(animation.get_track_count()):
			var type: int = animation.track_get_type(track)
			if type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
				continue
			var path := animation.track_get_path(track)
			if path.get_subname_count() == 0 or animation_root == null:
				continue
			var target := animation_root.get_node_or_null(NodePath(path.get_concatenated_names()))
			if not target is Skeleton3D:
				continue
			var target_skeleton := target as Skeleton3D
			var bone_name := String(path.get_subname(0))
			var count := animation.track_get_key_count(track)
			var valid := target_skeleton.find_bone(bone_name) >= 0 and count > 0 and animation.track_is_enabled(track)
			_check("clip.%s.track.%d.valid" % [clip, track], valid, {"path": String(path), "keys": count})
			if not valid:
				continue
			bone_tracks += 1
			if type == Animation.TYPE_ROTATION_3D:
				rotation_tracks += 1
			if looping and type in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D]:
				_validate_seam(clip, animation, track, type)
		_check("clip.%s.bone_tracks" % clip, bone_tracks > 0 and rotation_tracks > 0,
			{"bone_tracks": bone_tracks, "rotation_tracks": rotation_tracks})

func _validate_layers() -> void:
	_check("layers.import_source_inactive", not source_anim.active)
	for clip in EXPECTED:
		if not lower_anim.has_animation(clip) or not anim.has_animation(clip):
			continue
		var lower: Animation = lower_anim.get_animation(clip)
		var upper: Animation = anim.get_animation(clip)
		var lower_paths: Array[String] = []
		for track in range(lower.get_track_count()):
			lower_paths.append(String(lower.track_get_path(track)))
		var overlap: Array[String] = []
		for track in range(upper.get_track_count()):
			var path := String(upper.track_get_path(track))
			if path in lower_paths:
				overlap.append(path)
		_check("layers.%s.disjoint_tracks" % clip, overlap.is_empty() and lower.get_track_count() > 0 and upper.get_track_count() > 0, {"overlap": overlap})

func _key_distance(a: Variant, b: Variant, type: int) -> float:
	if type == Animation.TYPE_ROTATION_3D:
		var qa: Quaternion = a
		var qb: Quaternion = b
		return 2.0 * acos(clampf(absf(qa.normalized().dot(qb.normalized())), 0.0, 1.0))
	var va: Vector3 = a
	var vb: Vector3 = b
	return va.distance_to(vb)

func _validate_seam(clip: String, animation: Animation, track: int, type: int) -> void:
	var count := animation.track_get_key_count(track)
	var first: Variant = animation.track_get_key_value(track, 0)
	var last: Variant = animation.track_get_key_value(track, count - 1)
	var first_time := animation.track_get_key_time(track, 0)
	var last_time := animation.track_get_key_time(track, count - 1)
	# glTF can omit the authored final duplicate sample. Allow only the actual
	# missing time, at measured neighboring velocity, with hard absolute caps.
	var missing := maxf(0.0, animation.length - last_time + first_time)
	var endpoint_speed := 0.0
	if count > 1:
		var dt_first := animation.track_get_key_time(track, 1) - first_time
		var dt_last := last_time - animation.track_get_key_time(track, count - 2)
		if dt_first > 0.00001:
			endpoint_speed = _key_distance(first, animation.track_get_key_value(track, 1), type) / dt_first
		if dt_last > 0.00001:
			endpoint_speed = maxf(endpoint_speed, _key_distance(last, animation.track_get_key_value(track, count - 2), type) / dt_last)
	var base := deg_to_rad(0.5) if type == Animation.TYPE_ROTATION_3D else 0.002
	var cap := deg_to_rad(12.0) if type == Animation.TYPE_ROTATION_3D else 0.08
	var tolerance := minf(cap, base + endpoint_speed * minf(missing, FRAME_TOLERANCE) * 1.5)
	var gap := _key_distance(first, last, type)
	# Single-key constant tracks are valid even though they cover no time range.
	var time_ok := count == 1 or missing <= FRAME_TOLERANCE
	_check("clip.%s.track.%d.loop_seam" % [clip, track], time_ok and gap <= tolerance,
		{"path": String(animation.track_get_path(track)), "gap": gap, "tolerance": tolerance,
		"missing_end_seconds": missing, "unit": "radians" if type == Animation.TYPE_ROTATION_3D else "metres"})

func _create_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "QA_IsolatedFloor"
	floor_body.position = ORIGIN + Vector3(0.0, -0.5, 0.0)
	floor_body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	collision.shape = box
	floor_body.add_child(collision)
	world.add_child(floor_body)

func _release_actions() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			Input.action_release(action)

func _wait(seconds: float) -> void:
	var frames := maxi(1, ceili(seconds * Engine.physics_ticks_per_second))
	for frame in range(frames):
		await physics_frame
		await process_frame
		if finishing:
			return

func _reset_player(yaw: float) -> void:
	_release_actions()
	player.global_position = ORIGIN + Vector3(0.0, 0.4, 0.0)
	player.velocity = Vector3.ZERO
	player.set("_velocity_y", 0.0)
	player.set("_yaw", yaw)
	await _wait(0.45)

func _test_directions() -> void:
	var directions := {"move_forward": Vector3.FORWARD, "move_back": Vector3.BACK,
		"move_left": Vector3.LEFT, "move_right": Vector3.RIGHT}
	for yaw_degrees in [0, 90, 180, 270]:
		var yaw := deg_to_rad(float(yaw_degrees))
		for action in directions:
			await _reset_player(yaw)
			var origin := player.global_position
			Input.action_press(action)
			await _wait(0.4)
			Input.action_release(action)
			var displacement := player.global_position - origin
			displacement.y = 0.0
			var local: Vector3 = directions[action]
			var expected := local.rotated(Vector3.UP, yaw)
			var dot := displacement.normalized().dot(expected)
			_check("movement.yaw_%d.%s" % [yaw_degrees, action], displacement.length() > 0.25 and dot > 0.985 and player.is_on_floor(),
				{"distance": displacement.length(), "direction_dot": dot, "world_displacement": str(displacement), "expected": str(expected)})

func _pose() -> Array[Quaternion]:
	var result: Array[Quaternion] = []
	for bone in range(skeleton.get_bone_count()):
		result.append(skeleton.get_bone_pose_rotation(bone))
	return result

func _pose_delta(before: Array[Quaternion]) -> float:
	var biggest := 0.0
	for bone in range(mini(before.size(), skeleton.get_bone_count())):
		biggest = maxf(biggest, _key_distance(before[bone], skeleton.get_bone_pose_rotation(bone), Animation.TYPE_ROTATION_3D))
	return biggest

func _test_locomotion() -> void:
	await _reset_player(0.0)
	Input.action_press("move_forward")
	await _wait(0.4)
	_check("animation.walk_selected", anim.current_animation == "WalkArmed" and String(player.get("current_action")) == "WalkArmed")
	var pose := _pose()
	await _wait(0.17)
	var changed := _pose_delta(pose)
	_check("animation.movement_changes_bones", changed > 0.005 and anim.speed_scale > 0.1, {"max_bone_radians": changed, "speed_scale": anim.speed_scale})
	Input.action_press("sprint")
	await _wait(0.4)
	_check("animation.run_selected", anim.current_animation == "RunArmed")
	_release_actions()
	await _wait(0.6)
	_check("animation.stop_returns_idle", anim.current_animation == "IdleArmed" and String(player.get("current_action")) == "IdleArmed" and Vector2(player.velocity.x, player.velocity.z).length() < 0.05)
	Input.action_press("aim")
	await _wait(0.25)
	_check("animation.aim_selected", anim.current_animation == "AimArmed")
	Input.action_release("aim")
	await _wait(0.25)

func _on_started(clip: StringName) -> void:
	var key := String(clip)
	starts[key] = int(starts.get(key, 0)) + 1

func _on_finished(clip: StringName) -> void:
	var key := String(clip)
	finishes[key] = int(finishes.get(key, 0)) + 1

func _observe_one_shot(clip: String, duration: float, before_starts: int, before_finishes: int) -> void:
	var last_position := -1.0
	var maximum_position := 0.0
	var regressions := 0
	var samples := 0
	var frames := ceili((duration + 0.35) * Engine.physics_ticks_per_second)
	for frame in range(frames):
		await physics_frame
		await process_frame
		if anim.current_animation == clip:
			var position := anim.current_animation_position
			if last_position >= 0.0 and position + 0.003 < last_position:
				regressions += 1
			last_position = position
			maximum_position = maxf(maximum_position, position)
			samples += 1
	var start_count := int(starts.get(clip, 0)) - before_starts
	var finish_count := int(finishes.get(clip, 0)) - before_finishes
	_check("oneshot.%s.progress_and_single_completion" % clip,
		start_count == 1 and finish_count == 1 and regressions == 0 and samples >= 2 and maximum_position > duration * 0.5 and anim.current_animation != clip,
		{"starts": start_count, "finishes": finish_count, "position_regressions": regressions, "samples": samples, "max_position": maximum_position})

func _test_combat() -> void:
	await _reset_player(0.0)
	var ammo_before := int(player.get("ammo"))
	var reserve_before := int(player.get("reserve_ammo"))
	_check("combat.fixture_ammunition", ammo_before > 0 and reserve_before > 0)
	var s := int(starts.get("FireArmed", 0))
	var f := int(finishes.get("FireArmed", 0))
	player.call("_start_fire")
	_check("combat.fire_consumes_one", int(player.get("ammo")) == ammo_before - 1 and anim.current_animation == "FireArmed")
	await _observe_one_shot("FireArmed", 0.267, s, f)
	_check("combat.fire_no_extra_consumption", int(player.get("ammo")) == ammo_before - 1)

	s = int(starts.get("ReloadArmed", 0))
	f = int(finishes.get("ReloadArmed", 0))
	player.call("_start_reload")
	_check("combat.reload_started", bool(player.get("is_reloading")) and anim.current_animation == "ReloadArmed")
	var during_ammo := int(player.get("ammo"))
	player.call("_start_reload") # Duplicate requests must not restart the action.
	player.call("_start_fire")
	_check("combat.reload_blocks_fire", int(player.get("ammo")) == during_ammo and anim.current_animation == "ReloadArmed")
	await _observe_one_shot("ReloadArmed", 2.8, s, f)
	var needed := mini(int(player.get("max_ammo")) - during_ammo, reserve_before)
	_check("combat.reload_transfers_once", not bool(player.get("is_reloading")) and int(player.get("ammo")) == during_ammo + needed and int(player.get("reserve_ammo")) == reserve_before - needed,
		{"ammo": player.get("ammo"), "reserve_ammo": player.get("reserve_ammo"), "expected_transfer": needed})
	await _wait(0.4)
	_check("combat.reload_remains_completed", int(finishes.get("ReloadArmed", 0)) - f == 1 and int(player.get("ammo")) == during_ammo + needed and int(player.get("reserve_ammo")) == reserve_before - needed)

	player.call("_start_fire")
	await _wait(0.6)
	var cancel_ammo := int(player.get("ammo"))
	var cancel_reserve := int(player.get("reserve_ammo"))
	var reload_finishes := int(finishes.get("ReloadArmed", 0))
	player.call("_start_reload")
	await _wait(0.25)
	_check("combat.interrupt_precondition", bool(player.get("is_reloading")) and anim.current_animation == "ReloadArmed")
	s = int(starts.get("HitReact", 0))
	f = int(finishes.get("HitReact", 0))
	player.call("receive_hit")
	_check("combat.hit_cancels_reload", not bool(player.get("is_reloading")) and anim.current_animation == "HitReact" and int(player.get("ammo")) == cancel_ammo and int(player.get("reserve_ammo")) == cancel_reserve)
	await _observe_one_shot("HitReact", 0.667, s, f)
	await _wait(2.0) # Beyond the original reload completion deadline.
	_check("combat.cancelled_reload_never_refills", int(player.get("ammo")) == cancel_ammo and int(player.get("reserve_ammo")) == cancel_reserve and int(finishes.get("ReloadArmed", 0)) == reload_finishes and not bool(player.get("is_reloading")))
	_check("combat.returns_to_idle", anim.current_animation == "IdleArmed")

func _test_layered_actions() -> void:
	await _reset_player(0.0)
	player.call("_start_fire")
	await _wait(0.6)
	Input.action_press("move_forward")
	await _wait(0.35)
	player.call("_start_reload")
	await _wait(0.2)
	var leg := skeleton.find_bone("thigh.L")
	_check("layers.leg_sample_bone", leg >= 0)
	var before := Quaternion.IDENTITY
	if leg >= 0:
		before = skeleton.get_bone_pose_rotation(leg)
	var position_before := player.global_position
	await _wait(0.17)
	var leg_change := 0.0
	if leg >= 0:
		leg_change = _key_distance(before, skeleton.get_bone_pose_rotation(leg), Animation.TYPE_ROTATION_3D)
	_check("layers.moving_reload_keeps_legs_animating", bool(player.get("is_reloading")) and anim.current_animation == "ReloadArmed" and lower_anim.current_animation == "WalkArmed" and leg_change > 0.005 and player.global_position.distance_to(position_before) > 0.1,
		{"leg_radians": leg_change, "lower_clip": lower_anim.current_animation, "upper_clip": anim.current_animation})
	player.call("receive_hit")
	var ammo_before := int(player.get("ammo"))
	var reserve_before := int(player.get("reserve_ammo"))
	var hit_starts := int(starts.get("HitReact", 0))
	player.call("_start_reload")
	player.call("receive_hit")
	_check("layers.hit_rejects_reload_and_repeated_hit", anim.current_animation == "HitReact" and not bool(player.get("is_reloading")) and int(starts.get("HitReact", 0)) == hit_starts)
	_release_actions()
	await _wait(0.95)
	_check("layers.hit_preserves_ammo", int(player.get("ammo")) == ammo_before and int(player.get("reserve_ammo")) == reserve_before)

func _test_airborne() -> void:
	await _reset_player(0.0)
	player.global_position = ORIGIN + Vector3(0.0, 4.0, 0.0)
	player.velocity = Vector3.ZERO
	player.set("_velocity_y", 0.0)
	Input.action_press("move_forward")
	await _wait(0.25)
	_check("airborne.independent_locomotion", not player.is_on_floor() and String(player.get("locomotion_state")) == "Airborne" and lower_anim.current_animation == "IdleArmed")
	var lower_time := lower_anim.current_animation_position
	var before_xz := Vector2(player.global_position.x, player.global_position.z)
	await _wait(0.2)
	_check("airborne.pose_held_but_movement_continues", absf(lower_anim.current_animation_position - lower_time) < 0.001 and Vector2(player.global_position.x, player.global_position.z).distance_to(before_xz) > 0.1)
	_release_actions()
	await _wait(1.0)
	_check("airborne.lands_and_recovers_idle", player.is_on_floor() and String(player.get("locomotion_state")) == "IdleArmed")

func _test_missing_reload_clip() -> void:
	await _reset_player(0.0)
	# Remove only the controller's private runtime copy, never the imported asset.
	var library := anim.get_animation_library(&"")
	var saved: Animation = null
	if library.has_animation(&"ReloadArmed"):
		saved = library.get_animation(&"ReloadArmed")
		library.remove_animation(&"ReloadArmed")
	var ammo_before := int(player.get("ammo"))
	var reserve_before := int(player.get("reserve_ammo"))
	_check("fallback.reload_precondition", ammo_before < int(player.get("max_ammo")) and reserve_before > 0)
	player.call("_start_reload")
	await _wait(0.1)
	_check("missing_clip.reload_rejected_without_lock", not bool(player.get("is_reloading")) and not bool(player.get("action_locked")) and int(player.get("ammo")) == ammo_before and int(player.get("reserve_ammo")) == reserve_before)
	await _wait(3.1)
	_check("missing_clip.no_delayed_refill", not bool(player.get("is_reloading")) and not bool(player.get("action_locked")) and int(player.get("ammo")) == ammo_before and int(player.get("reserve_ammo")) == reserve_before)
	if saved != null:
		library.add_animation(&"ReloadArmed", saved)

func _test_mouse_look() -> void:
	_release_actions()
	player.call("_set_look", false)
	var ammo_before := int(player.get("ammo"))
	Input.action_press("fire")
	await _wait(0.1)
	Input.action_release("fire")
	_check("mouse.look_disabled_does_not_fire", int(player.get("ammo")) == ammo_before)
	await _wait(0.6)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await _wait(0.1)
	click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	Input.parse_input_event(click)
	await _wait(0.1)
	_check("mouse.first_click_only_recaptures", bool(player.get("_look_enabled")) and int(player.get("ammo")) == ammo_before)
	await _wait(0.6)
	# A subsequent deliberate click must remain usable after capture suppression.
	click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await _wait(0.1)
	click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	Input.parse_input_event(click)
	await _wait(0.5)
	_check("mouse.subsequent_click_fires_once", int(player.get("ammo")) == ammo_before - 1)
	player.call("_set_look", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Simulate capture failure, not disabled look.
	var old_yaw := float(player.get("_yaw"))
	var old_pitch := float(player.get("_pitch"))
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(80.0, 12.0)
	player.call("_unhandled_input", motion)
	var new_yaw := float(player.get("_yaw"))
	var new_pitch := float(player.get("_pitch"))
	_check("mouse.capture_failure_still_updates_angles", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and absf(new_yaw - old_yaw) > 0.01 and absf(new_pitch - old_pitch) > 0.001,
		{"yaw_delta": new_yaw - old_yaw, "pitch_delta": new_pitch - old_pitch})
	await _wait(0.1)
	var arm := player.get_node("SpringArm3D") as SpringArm3D
	_check("mouse.angles_applied_to_camera_rig", absf(angle_difference(player.rotation.y, new_yaw)) < 0.001 and absf(arm.rotation.x - new_pitch) < 0.001)
	# Test actual input delivery in addition to the direct handler contract.
	Input.parse_input_event(motion)
	await _wait(0.1)
	_check("mouse.capture_failure_input_delivery", absf(float(player.get("_yaw")) - new_yaw) > 0.01)

func _watchdog() -> void:
	if not finishing:
		_check("harness.watchdog", false, {"reason": "120 second timeout; possible runtime error or stalled test"})
		await _finish()

func _finish() -> void:
	if finishing:
		return
	finishing = true
	_release_actions()
	Input.mouse_mode = original_mouse_mode
	var output_dir := ProjectSettings.globalize_path("res://").path_join("../outputs").simplify_path()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	_check("report.directory", mkdir_error == OK or mkdir_error == ERR_ALREADY_EXISTS, {"path": output_dir, "error": mkdir_error})
	var output_path := output_dir.path_join("production_motion_verification.json")
	var report := FileAccess.open(output_path, FileAccess.WRITE)
	_check("report.writable", report != null, {"path": output_path, "error": FileAccess.get_open_error()})
	if report != null:
		report.store_string(JSON.stringify({
			"suite": "production_motion", "status": "PASS" if failures == 0 else "FAIL",
			"engine": Engine.get_version_info(), "timestamp_utc": Time.get_datetime_string_from_system(true),
			"duration_seconds": (Time.get_ticks_msec() - started_msec) / 1000.0,
			"failure_count": failures, "checks": checks,
			"scope": "Functional regression only. Headless timing is not graphical performance evidence.",
			"loop_tolerance": "One missing 30fps frame; local endpoint velocity allowance, capped at 0.08m / 12deg.",
		}, "\t"))
		report.flush()
		var write_error := report.get_error()
		report.close()
		if write_error != OK:
			_check("report.write", false, {"error": write_error})
	if is_instance_valid(world):
		world.queue_free()
	world = null
	player = null
	anim = null
	lower_anim = null
	source_anim = null
	skeleton = null
	await process_frame
	await process_frame
	Engine.max_fps = original_max_fps
	print("PRODUCTION MOTION %s: %d failures; %s" % ["PASS" if failures == 0 else "FAIL", failures, output_path])
	quit(0 if failures == 0 else 1)
