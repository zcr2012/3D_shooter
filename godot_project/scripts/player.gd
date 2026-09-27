extends CharacterBody3D
## Camera-relative prototype controller. Lower-body locomotion and upper-body
## actions own disjoint animation tracks: reloading/firing never freezes legs.
## Combat is opt-in: the mission scene enables it; the animation fixture stays isolated.

signal shot_fired(origin: Vector3, target: Vector3, hit: bool)
## Where the round stopped. kind: "miss" (max range), "world" (static geometry),
## "hit", "kill" (confirmed damage / target reached zero), "dead" (target refused: already down).
signal bullet_impact(where: Vector3, normal: Vector3, direction: Vector3, kind: String, headshot: bool)
## source is the attacker's position (Vector3.INF when unknown) for the directional indicator.
signal damaged(health: int, amount: int, source: Vector3)
signal died

@export var combat_enabled: bool = false
@export var max_health: int = 100
var health: int = 100
var controls_enabled: bool = true
var _hurt_cooldown: float = 0.0

@export var walk_speed: float = 1.8
@export var sprint_speed: float = 3.5
@export var accel: float = 12.0
@export var mouse_sensitivity: float = 0.0025
@export var gravity: float = 9.8
@export var jump_velocity: float = 4.2
@export var max_ammo: int = 30
@export var starting_ammo: int = 30
@export var starting_reserve_ammo: int = 90

const BODY_DAMAGE: int = 34
const HEADSHOT_DAMAGE: int = 68
# Operators are 1.69 m tall with the head joint at 1.455 m; enemy colliders are
# single capsules, so "head" is the top band plus a lateral test against the axis.
const HEADSHOT_HEIGHT: float = 1.42
const HEADSHOT_RADIUS: float = 0.17
const WALK_AUTHORED_SPEED: float = 1.0
const RUN_AUTHORED_SPEED: float = 2.6
const ANIMATION_BLEND: float = 0.15
const WALK_CLIP := "WalkArmed"
const RUN_CLIP := "RunArmed"
const IDLE_CLIP := "IdleArmed"
const AIM_CLIP := "AimArmed"
const FIRE_CLIP := "FireArmed"
const RELOAD_CLIP := "ReloadArmed"
const HIT_CLIP := "HitReact"
const AIRBORNE := "Airborne"
const CLIPS := [IDLE_CLIP, WALK_CLIP, RUN_CLIP, AIM_CLIP, FIRE_CLIP, RELOAD_CLIP, HIT_CLIP]
# weapon_root is a child of chest; weapon_mag is its child. Both follow the
# upper-body layer and inherit the same hip motion as the arms.
const UPPER_BONES := ["spine", "chest", "neck", "head", "shoulder.L", "shoulder.R",
	"upperarm.L", "upperarm.R", "forearm.L", "forearm.R", "hand.L", "hand.R",
	"weapon_root", "weapon_mag"]

@onready var model: Node3D = $Model
@onready var arm: SpringArm3D = $SpringArm3D
@onready var cam: Camera3D = $SpringArm3D/Camera3D

var _yaw: float = 0.0
var _pitch: float = -0.12
var _velocity_y: float = 0.0
var _look_enabled: bool = true
# After recapturing the pointer, require all action inputs to be released.
# This consumes the capture click even across multiple physics ticks.
var _await_action_release: bool = false
var _anim: AnimationPlayer = null # Runtime lower-body player (root/hip/legs).
var _upper_anim: AnimationPlayer = null
var _action_state: String = IDLE_CLIP
var _locomotion_state: String = IDLE_CLIP
var _action_locked: bool = false
var _reload_started: bool = false
var _action_elapsed: float = 0.0
var _action_duration: float = 0.0
var _missing_action_clip: bool = false
var _air_pose_time: float = 0.0
var _planar_speed: float = 0.0
var _ammo: int = 30
var _reserve_ammo: int = 90

# Readable state for HUD and external verification; not a writable game-state UI.
var current_action: String:
	get:
		return _action_state
var locomotion_state: String:
	get:
		return _locomotion_state
var ammo: int:
	get:
		return _ammo
var reserve_ammo: int:
	get:
		return _reserve_ammo
var is_reloading: bool:
	get:
		return _reload_started
var action_locked: bool:
	get:
		return _action_locked
var horizontal_speed: float:
	get:
		return _planar_speed

func _ready() -> void:
	max_health = maxi(max_health, 1)
	health = max_health
	add_to_group("player")
	arm.add_excluded_object(get_rid())
	max_ammo = maxi(max_ammo, 1)
	_ammo = clampi(starting_ammo, 0, max_ammo)
	_reserve_ammo = maxi(starting_reserve_ammo, 0)
	_set_look(true)
	call_deferred("_retry_capture")
	var source := _find_anim_player(model)
	if source == null:
		push_warning("No AnimationPlayer under Model; movement and action timers remain usable.")
		return
	# Never mutate shared imported animations. Both runtime libraries are copies.
	source.stop()
	source.active = false
	_anim = _make_layer(source, false)
	_upper_anim = _make_layer(source, true)
	_upper_anim.animation_finished.connect(_on_animation_finished)
	_play_loop(_anim, IDLE_CLIP, 1.0)
	_play_loop(_upper_anim, IDLE_CLIP, 1.0)

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found != null:
			return found
	return null

func _resolve_clip(source: AnimationPlayer, clip: String) -> StringName:
	if source.has_animation(clip):
		return StringName(clip)
	for full_name in source.get_animation_list():
		if String(full_name).get_slice("/", String(full_name).get_slice_count("/") - 1) == clip:
			return full_name
	return &""

func _make_layer(source: AnimationPlayer, upper: bool) -> AnimationPlayer:
	var layer := AnimationPlayer.new()
	layer.name = "UpperActionPlayer" if upper else "LowerLocomotionPlayer"
	add_child(layer)
	layer.root_node = layer.get_path_to(source.get_node(source.root_node))
	# Deterministic ordering: advance lower then upper once per physics tick.
	layer.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library := AnimationLibrary.new()
	for clip in CLIPS:
		var imported_name := _resolve_clip(source, clip)
		if imported_name == &"":
			if upper:
				push_warning("Missing clip %s; reload is refused, other actions use pose/timer fallback." % clip)
			continue
		var animation := source.get_animation(imported_name).duplicate() as Animation
		for track in range(animation.get_track_count() - 1, -1, -1):
			var path := animation.track_get_path(track)
			var bone := String(path.get_subname(0)) if path.get_subname_count() > 0 else ""
			var is_upper: bool = bone in UPPER_BONES
			if is_upper != upper:
				animation.remove_track(track)
		animation.loop_mode = Animation.LOOP_NONE if clip in [FIRE_CLIP, RELOAD_CLIP, HIT_CLIP] else Animation.LOOP_LINEAR
		if animation.get_track_count() > 0:
			library.add_animation(clip, animation)
	layer.add_animation_library(&"", library)
	return layer

func _has_animation(clip: String) -> bool:
	return _upper_anim != null and _upper_anim.has_animation(clip)

func _set_look(on: bool) -> void:
	_look_enabled = on
	if not on:
		_await_action_release = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE

func _retry_capture() -> void:
	if _look_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN and _look_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and _look_enabled:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, deg_to_rad(-55.0), deg_to_rad(35.0))
	elif event.is_action_pressed("ui_cancel"):
		_set_look(false)
	elif event is InputEventMouseButton and event.pressed and not _look_enabled:
		_await_action_release = true
		_set_look(true)
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	_hurt_cooldown = maxf(0.0, _hurt_cooldown - delta)
	if not controls_enabled:
		return
	if combat_enabled:
		var ads := _look_enabled and Input.is_action_pressed("aim")
		cam.fov = lerpf(cam.fov, 55.0 if ads else 72.0, 1.0 - exp(-12.0 * delta))
	if not is_on_floor():
		_velocity_y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		_velocity_y = jump_velocity
	else:
		_velocity_y = 0.0
	rotation.y = _yaw
	arm.rotation.x = _pitch
	# Keep input camera-relative even when platform mouse capture fails.
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, _yaw)
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	var wants_sprint := Input.is_action_pressed("sprint") and dir.length_squared() > 0.01
	var speed := sprint_speed if wants_sprint else walk_speed
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	velocity.y = _velocity_y
	move_and_slide()
	_velocity_y = velocity.y
	# Collision-resolved horizontal travel, rather than desired input speed.
	var actual_velocity := get_real_velocity()
	# move_and_slide() divides the position delta by the frame delta, so a zero
	# time scale (frozen capture stills) would make the real velocity NaN.
	_planar_speed = Vector2(actual_velocity.x, actual_velocity.z).length() if actual_velocity.is_finite() else 0.0
	if combat_enabled and _look_enabled and (Input.is_action_pressed("aim") or Input.is_action_pressed("fire")):
		model.rotation.y = lerp_angle(model.rotation.y, 0.0, 1.0 - exp(-18.0 * delta))
	elif dir.length_squared() > 0.01:
		var want_world := atan2(-dir.x, -dir.z)
		var want_local := wrapf(want_world - rotation.y, -PI, PI)
		model.rotation.y = lerp_angle(model.rotation.y, want_local, 1.0 - exp(-10.0 * delta))
	_handle_input_actions()
	_update_animation(delta, wants_sprint)

func _handle_input_actions() -> void:
	if not _look_enabled:
		return
	if _await_action_release:
		if not Input.is_action_pressed("fire") and not Input.is_action_pressed("aim") and not Input.is_action_pressed("reload"):
			_await_action_release = false
		return
	if Input.is_action_just_pressed("reload"):
		_start_reload()
	if Input.is_action_just_pressed("fire"):
		_start_fire()

func _start_fire() -> void:
	if not controls_enabled or _action_locked or _reload_started or _ammo <= 0:
		return
	_ammo -= 1
	_start_one_shot(FIRE_CLIP)
	if combat_enabled:
		_fire_hitscan()

func _start_reload() -> void:
	if not controls_enabled or _action_locked or _reload_started or _ammo >= max_ammo or _reserve_ammo <= 0:
		return
	# A missing reload clip must never grant ammunition or create a fake reload.
	if not _has_animation(RELOAD_CLIP):
		return
	_reload_started = true
	_start_one_shot(RELOAD_CLIP)

func _start_one_shot(clip: String) -> void:
	_action_state = clip
	_action_locked = true
	_action_elapsed = 0.0
	_action_duration = 2.8 if clip == RELOAD_CLIP else (0.65 if clip == HIT_CLIP else 0.25)
	_missing_action_clip = not _has_animation(clip)
	if _missing_action_clip:
		# Keep the preceding neutral upper pose. Timed fallback still enforces
		# fire/hit locks; missing reload is rejected before entering this method.
		_play_loop(_upper_anim, IDLE_CLIP, 1.0)
		return
	_action_duration = maxf(_upper_anim.get_animation(clip).length, 0.01)
	_upper_anim.speed_scale = 1.0
	_upper_anim.play(clip, ANIMATION_BLEND)

func _finish_reload(interrupted: bool) -> void:
	if not _reload_started:
		return
	_reload_started = false # Clear before applying ammo; duplicate completion is inert.
	if not interrupted:
		var transferred := mini(maxi(max_ammo - _ammo, 0), _reserve_ammo)
		_ammo += transferred
		_reserve_ammo -= transferred
	_action_locked = false
	_restore_loop_state()

func receive_hit() -> void:
	## Cancels reload without spending reserve ammo. Repeated hits do not restart
	## HitReact indefinitely. This is a reaction API, not damage/hit detection.
	if _reload_started:
		_finish_reload(true)
	if _action_locked and _action_state == HIT_CLIP:
		return
	_start_one_shot(HIT_CLIP)

func _on_animation_finished(clip: StringName) -> void:
	if not _action_locked or String(clip) != _action_state:
		return
	if String(clip) == RELOAD_CLIP:
		_finish_reload(false)
	elif String(clip) in [FIRE_CLIP, HIT_CLIP]:
		_action_locked = false
		_restore_loop_state()

func _restore_loop_state() -> void:
	var aiming := _look_enabled and not _await_action_release and Input.is_action_pressed("aim")
	_action_state = AIM_CLIP if aiming else _locomotion_state
	var upper_clip := IDLE_CLIP if _action_state == AIRBORNE else _action_state
	_play_loop(_upper_anim, upper_clip, _loop_rate(upper_clip))

func _loop_rate(clip: String) -> float:
	if clip == WALK_CLIP:
		return _planar_speed / WALK_AUTHORED_SPEED
	if clip == RUN_CLIP:
		return _planar_speed / RUN_AUTHORED_SPEED
	return 1.0 # Idle/Aim breathing always runs at authored speed.

func _play_loop(layer: AnimationPlayer, requested: String, rate: float) -> void:
	if layer == null:
		return
	var clip := requested
	if not layer.has_animation(clip):
		if layer.has_animation(IDLE_CLIP):
			clip = IDLE_CLIP
			rate = 1.0
		elif layer.has_animation(WALK_CLIP):
			clip = WALK_CLIP
			rate = 0.0 # Missing idle: hold a basic pose, never walk in midair.
		else:
			return
	if String(layer.current_animation) != clip:
		var old_clip := String(layer.current_animation)
		var phase := 0.0
		var preserve_phase: bool = old_clip in [WALK_CLIP, RUN_CLIP] and clip in [WALK_CLIP, RUN_CLIP]
		if preserve_phase:
			phase = fposmod(layer.current_animation_position / maxf(layer.current_animation_length, 0.001), 1.0)
		layer.play(clip, ANIMATION_BLEND)
		if preserve_phase:
			layer.seek(phase * layer.get_animation(clip).length, false)
	layer.speed_scale = rate

func _update_animation(delta: float, wants_sprint: bool) -> void:
	var airborne := not is_on_floor()
	if airborne:
		_air_pose_time += delta
		_locomotion_state = AIRBORNE
		_play_loop(_anim, IDLE_CLIP, 1.0)
	else:
		_air_pose_time = 0.0
		# Hysteresis avoids idle/walk chatter during contact and stopping.
		var threshold := 0.06 if _locomotion_state in [WALK_CLIP, RUN_CLIP] else 0.12
		_locomotion_state = IDLE_CLIP
		if _planar_speed > threshold:
			_locomotion_state = RUN_CLIP if wants_sprint else WALK_CLIP
		_play_loop(_anim, _locomotion_state, _loop_rate(_locomotion_state))
	if not _action_locked:
		_restore_loop_state()
	# Blend briefly into the independent air pose, then hold it. Movement stays
	# fully controllable. Upper one-shots continue in air without grounding legs.
	if _anim != null and (not airborne or _air_pose_time <= ANIMATION_BLEND):
		_anim.advance(delta)
	if _upper_anim != null and (_action_locked or not airborne or _air_pose_time <= ANIMATION_BLEND):
		_upper_anim.advance(delta)
	# Normal completion comes from the upper animation_finished signal. The
	# fallback is deterministic and only releases the currently active action.
	if _action_locked:
		_action_elapsed += delta
		var deadline := _action_duration + (0.0 if _missing_action_clip else 0.2)
		if _action_elapsed >= deadline:
			_on_animation_finished(StringName(_action_state))


func _fire_hitscan() -> void:
	# Camera chooses the reticle point; a second ray from the weapon prevents
	# shooting through cover when a third-person camera can peek around it.
	var eye := cam.global_position
	var aim_end := eye - cam.global_basis.z * 80.0
	var camera_query := PhysicsRayQueryParameters3D.create(eye, aim_end, 1 | 4, [get_rid()])
	var camera_hit := get_world_3d().direct_space_state.intersect_ray(camera_query)
	if not camera_hit.is_empty():
		aim_end = camera_hit.position
	var chest := global_position + Vector3(0, 1.25, 0)
	var muzzle := chest - global_basis.z * 0.42
	var clearance := PhysicsRayQueryParameters3D.create(chest, muzzle, 1, [get_rid()])
	var blocked := get_world_3d().direct_space_state.intersect_ray(clearance)
	if not blocked.is_empty():
		fire_at(chest, blocked.position)
	else:
		fire_at(muzzle, aim_end)

func fire_at(origin: Vector3, target: Vector3) -> void:
	if not combat_enabled or not controls_enabled:
		return
	# Shared resolution path also used by the headless occlusion regression.
	var direction := (target - origin).normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, target + direction * 0.1, 1 | 4, [get_rid()])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var end := target
	var confirmed := false
	var kind := "miss"
	var headshot := false
	var normal := -direction
	if not result.is_empty():
		end = result.position
		normal = result.normal
		var collider: Object = result.collider
		if collider.has_method("take_damage"):
			headshot = is_headshot(collider, end, direction)
			confirmed = bool(collider.call("take_damage", HEADSHOT_DAMAGE if headshot else BODY_DAMAGE))
			kind = "dead"
			if confirmed:
				var remaining: Variant = collider.get("health")
				kind = "kill" if (remaining is int or remaining is float) and remaining <= 0 else "hit"
		else:
			kind = "world"
	shot_fired.emit(origin, end, confirmed)
	bullet_impact.emit(end, normal, direction, kind, headshot)

func is_headshot(target: Object, point: Vector3, direction: Vector3) -> bool:
	## Head zone: contact above HEADSHOT_HEIGHT in the target's local space and the
	## bullet path passing within HEADSHOT_RADIUS of the body axis (a capsule's shoulder
	## surface sits 0.25 m out, so the ray-to-axis distance is what separates head from shoulder).
	var body := target as Node3D
	if body == null:
		return false
	var local_point := body.to_local(point)
	if local_point.y < HEADSHOT_HEIGHT:
		return false
	var local_direction := body.global_basis.inverse() * direction
	var offset := Vector2(local_point.x, local_point.z)
	var heading := Vector2(local_direction.x, local_direction.z)
	var lateral := offset.length() if heading.length_squared() < 0.000001 else absf(offset.cross(heading.normalized()))
	return lateral < HEADSHOT_RADIUS

func take_damage(amount: int, source: Vector3 = Vector3.INF) -> void:
	if not combat_enabled or not controls_enabled or health <= 0 or amount <= 0 or _hurt_cooldown > 0.0:
		return
	_hurt_cooldown = 0.5
	health = maxi(0, health - amount)
	damaged.emit(health, amount, source)
	if health == 0:
		stop_combat()
		died.emit()
	else:
		receive_hit()

func stop_combat() -> void:
	if _reload_started:
		_finish_reload(true)
	controls_enabled = false
	velocity = Vector3.ZERO
	_set_look(false)
