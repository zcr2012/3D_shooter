extends SceneTree
## Pause, checkpoint, retry, disk-recovery, door/stage and full escort regression.
## Uses persistence_enabled = false for the mission and an isolated user://qa_session/ folder for disk tests.
var failures := 0
var checks: Array[Dictionary] = []
var mission
const STAGE_REMAINING := [3,3,2,2]
func _init() -> void:
	call_deferred("_run")
func check(id: String, condition: bool) -> void:
	checks.append({"id":id,"passed":condition})
	if not condition:
		failures += 1
	print("[%s] %s" % ["PASS" if condition else "FAIL",id])
func frames(count: int = 3) -> void:
	for i in count:
		await process_frame
		await physics_frame
func freeze_enemies() -> void:
	for enemy in mission.enemies:
		enemy.set_physics_process(false)
func sample_checkpoint(stage: int) -> Dictionary:
	return {"version":1,"stage":stage,"health":77,"ammo":7,"reserve":43,"elapsed":12.5,"shots":9,"hits":4,"supplies":[true,false],"log":["测试记录"]}
func write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text)
	file.close()
func read_stage(path: String) -> int:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return -1
	return int(json.data.get("stage",-1))
func gate_blocks(gate: StaticBody3D) -> bool:
	# A physical ray through the doorway at chest height: what the player and bullets actually meet.
	var space: PhysicsDirectSpaceState3D = mission.city.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(gate.global_position+Vector3(0,0,2),gate.global_position+Vector3(0,0,-2),1)
	var hit := space.intersect_ray(ray)
	return not hit.is_empty() and hit.collider == gate
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	mission._unhandled_key_input(event)

func _run() -> void:
	Engine.max_fps = 120
	create_timer(150,true,false,true).timeout.connect(func():
		push_error("Session suite watchdog expired")
		quit(1))
	mission = load("res://scenes/urban_operation.tscn").instantiate()
	mission.persistence_enabled = false
	mission.cinematics_enabled = false
	root.add_child(mission)
	await frames()
	mission.start_mission()
	check("checkpoint.first_deployment",not mission.store.checkpoint.is_empty() and mission.store.checkpoint.stage == 0)
	freeze_enemies()
	var p = mission.player
	p._ammo = 5
	p._start_reload()
	await frames(5)
	mission.pause_menu.open_menu()
	var elapsed: float = mission.elapsed
	var reload_elapsed: float = p._action_elapsed
	var voice_time: float = mission.sound.voice.get_playback_position()
	check("pause.real_tree_pause",paused and mission.pause_menu.is_open)
	check("pause.audio_paused",mission.sound.voice.stream_paused and mission.sound.ambience.stream_paused)
	check("pause.blocks_interaction",not mission.try_interact() and not mission.try_resupply())
	await create_timer(.25,true).timeout
	check("pause.mission_clock_frozen",is_equal_approx(mission.elapsed,elapsed))
	check("pause.reload_frozen",is_equal_approx(p._action_elapsed,reload_elapsed) and p.ammo == 5)
	check("pause.dialogue_position_frozen",absf(mission.sound.voice.get_playback_position()-voice_time) < .08)
	mission.pause_menu.close_menu()
	check("pause.release_guard",not paused and p._await_action_release)
	await frames(5)
	check("pause.reload_resumes",p._action_elapsed > reload_elapsed)
	# An engaged enemy with a clear shot must not fire while the tree is paused.
	var shooter = mission.enemies[0]
	shooter.global_position = p.global_position + Vector3(0,0,-6)
	shooter.look_at(Vector3(p.global_position.x,shooter.global_position.y,p.global_position.z))
	shooter.tactical_state = "engage"
	shooter._alert_time = 5
	shooter._shot_timer = 0
	shooter._react_time = 0
	shooter.last_seen = p.global_position
	shooter.set_physics_process(true)
	var health_before: int = p.health
	var clock_before: float = shooter._clock
	mission.pause_menu.open_menu()
	await create_timer(.4,true).timeout
	check("pause.enemy_fire_frozen",p.health == health_before and is_equal_approx(shooter._clock,clock_before))
	mission.pause_menu.close_menu()
	shooter.set_physics_process(false)
	p.health = p.max_health
	# Losing window focus during play opens the same pause menu.
	mission.pause_menu._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check("pause.focus_loss_pauses",mission.pause_menu.is_open and paused)
	mission.pause_menu.close_menu()
	mission.pause_menu._set_preference(.004,"sensitivity")
	check("settings.sensitivity_applies",is_equal_approx(p.mouse_sensitivity,.004))
	mission.pause_menu._set_preference(false,"shadows")
	var shadows_off := true
	for child in mission.city.get_children():
		if child is DirectionalLight3D:
			shadows_off = shadows_off and not child.shadow_enabled
	check("settings.shadows_apply",shadows_off)
	mission.pause_menu._set_preference(true,"shadows")
	var sample := sample_checkpoint(2)
	check("checkpoint.schema_accepts_valid",mission.store.valid_checkpoint(sample))
	var bad := sample.duplicate(true)
	bad.stage = 9
	check("checkpoint.rejects_invalid_stage",not mission.store.valid_checkpoint(bad))
	bad = sample.duplicate(true)
	bad.ammo = 31
	check("checkpoint.rejects_invalid_ammo",not mission.store.valid_checkpoint(bad))
	bad = sample.duplicate(true)
	bad.supplies = ["yes",false]
	check("checkpoint.rejects_invalid_supplies",not mission.store.valid_checkpoint(bad))
	bad = sample.duplicate(true)
	bad.hits = 99
	check("checkpoint.rejects_hits_over_shots",not mission.store.valid_checkpoint(bad))
	bad = sample.duplicate(true)
	bad.stage = 1.5
	check("checkpoint.rejects_fractional_stage",not mission.store.valid_checkpoint(bad))

	# Every stage: gates (visual, collision, physics ray, navigation) and only the current enemy group.
	for stage in 4:
		mission.store.save_checkpoint(sample_checkpoint(stage))
		var restored: bool = mission.restore_checkpoint()
		await frames()
		freeze_enemies()
		var city = mission.city
		var gates_ok: bool = city.checkpoint_gate.visible == (stage == 0) and city.warehouse_gate.visible == (stage < 2)
		gates_ok = gates_ok and gate_blocks(city.checkpoint_gate) == (stage == 0) and gate_blocks(city.warehouse_gate) == (stage < 2)
		check("stage%d.gate_collision_matches" % stage,restored and gates_ok)
		var through_checkpoint: bool = not city.escort_path(Vector3(0,0,8),Vector3(0,0,15)).is_empty()
		var through_warehouse: bool = not city.escort_path(Vector3(0,0,-40),Vector3(0,0,-31)).is_empty()
		check("stage%d.navigation_matches_gates" % stage,through_checkpoint == (stage > 0) and through_warehouse == (stage >= 2))
		var groups_ok := true
		var active_count := 0
		for enemy in mission.enemies:
			if enemy.active:
				active_count += 1
				groups_ok = groups_ok and enemy.encounter == stage
			if enemy.encounter < stage:
				groups_ok = groups_ok and enemy.health == 0 and enemy.collision_layer == 0 and not enemy.visible
			elif enemy.encounter > stage:
				groups_ok = groups_ok and not enemy.active
		check("stage%d.only_current_enemy_group" % stage,groups_ok and active_count == STAGE_REMAINING[stage] and mission.remaining == STAGE_REMAINING[stage])
		check("stage%d.spawn_and_objective" % stage,mission.player.global_position.distance_to(mission.SPAWNS[stage]) < 1.0 and mission.stage == stage and mission.state == "active")

	mission.store.save_checkpoint(sample)
	check("checkpoint.restore_success",mission.restore_checkpoint())
	await frames()
	p = mission.player
	check("checkpoint.stage_and_gate",mission.stage == 2 and mission.remaining == 2 and not mission.city.warehouse_gate.visible)
	check("checkpoint.inventory_exact",p.health == 77 and p.ammo == 7 and p.reserve_ammo == 43 and not p.is_reloading)
	check("checkpoint.supplies_not_duplicated",mission.supply_uses == [true,false])
	check("checkpoint.cleared_groups_disabled",mission.enemies[0].health == 0 and mission.enemies[0].collision_layer == 0 and not mission.enemies[0].active)
	check("checkpoint.input_and_camera",mission.state == "active" and p.controls_enabled and p.cam.current)
	check("checkpoint.single_player_instance",mission.get_children().filter(func(n): return n.has_signal("shot_fired") and not n.is_queued_for_deletion()).size() == 1)
	freeze_enemies()
	# The street supply (index 0) was used before the checkpoint and must stay used after a retry;
	# the unused warehouse supply (index 1) can be collected exactly once.
	p.global_position = Vector3(3,.05,47)
	check("checkpoint.used_supply_stays_used",not mission.try_resupply())
	p.global_position = Vector3(3,.05,-33)
	var reserve_before: int = p.reserve_ammo
	check("checkpoint.unused_supply_collects_once",mission.try_resupply() and p.reserve_ammo == reserve_before + 60 and not mission.try_resupply())
	mission.store.save_checkpoint(sample)
	# Death -> lost -> Enter retries from the latest checkpoint with minimum resources.
	p.take_damage(500)
	await frames()
	check("retry.death_marks_lost",mission.state == "lost" and not mission.player.controls_enabled)
	mission.restart_mission()
	await frames()
	freeze_enemies()
	check("retry.enter_restores_checkpoint",mission.state == "active" and mission.stage == 2 and mission.player.health >= 60 and mission.remaining == 2)
	p = mission.player
	p.global_position = Vector3(0,.05,-58)
	for enemy in mission.enemies:
		if enemy.encounter == 2:
			enemy.take_damage(100)
	check("checkpoint.rescue_progression",mission.try_interact() and mission.stage == 3 and mission.store.checkpoint.stage == 3)
	freeze_enemies()
	mission.store.checkpoint.health = 1
	mission.store.checkpoint.ammo = 0
	mission.store.checkpoint.reserve = 0
	mission.restore_checkpoint()
	await frames()
	freeze_enemies()
	check("checkpoint.minimum_retry_resources",mission.player.health == 60 and mission.player.ammo == 0 and mission.player.reserve_ammo == 30)
	check("checkpoint.escort_restored",mission.rescued and mission.evidence_secured and mission.remaining == 2 and not mission.escort_hold)
	key(KEY_H)
	check("escort.h_key_toggles_hold",mission.escort_hold)
	mission.player.global_position = Vector3(0,.05,-48)
	var witness_position: Vector3 = mission.hostage.position
	await frames(30)
	check("escort.hold_is_stationary",mission.hostage.position.is_equal_approx(witness_position))
	key(KEY_H)
	check("escort.h_key_resumes",not mission.escort_hold)
	await frames(60)
	check("escort.follow_resumes",mission.hostage.position.distance_to(witness_position) > .5)
	check("escort.outside_nav_rejected",mission.city.escort_path(mission.hostage.position,Vector3(30,0,0)).is_empty())
	check("escort.corner_goal_recovers",not mission.city.escort_path(Vector3(0,0,-55),Vector3(8.4,0,-54)).is_empty())

	# Full escort: the player walks the authored route (including a detour behind a car);
	# the witness must follow through the warehouse door, past cover and the open gate.
	for enemy in mission.enemies:
		if enemy.encounter == 3 and enemy.health > 0:
			enemy.take_damage(100)
	check("escort.reinforcements_cleared",mission.remaining == 0)
	var route: Array[Vector3] = [Vector3(0,.05,-50),Vector3(0,.05,-38),Vector3(0,.05,-30),Vector3(1.5,.05,-20),Vector3(1.5,.05,-10),
		Vector3(6.5,.05,-9),Vector3(0,.05,-3),Vector3(0,.05,11),Vector3(-1,.05,30),Vector3(0,.05,51.5)]
	Engine.time_scale = 4.0
	var step := 1.0/Engine.physics_ticks_per_second*Engine.time_scale
	var waypoint := 0
	var stall := 0.0
	var worst_stall := 0.0
	var last_witness: Vector3 = mission.hostage.global_position
	var max_gap := 0.0
	for tick in 5200:
		if mission.state != "active":
			break
		p = mission.player
		var gap: float = p.global_position.distance_to(mission.hostage.global_position)
		max_gap = maxf(max_gap,gap)
		if waypoint < route.size() and gap < 4.5:
			var target: Vector3 = route[waypoint]
			var offset: Vector3 = target - p.global_position
			offset.y = 0
			if offset.length() < .2:
				waypoint += 1
			else:
				p.global_position += offset.normalized()*minf(offset.length(),2.6*step)
				p.velocity = Vector3.ZERO
		var moved: float = mission.hostage.global_position.distance_to(last_witness)
		last_witness = mission.hostage.global_position
		stall = stall + step if gap > 2.5 and moved < .002 else 0.0
		worst_stall = maxf(worst_stall,stall)
		await physics_frame
	Engine.time_scale = 1.0
	check("escort.route_completed",waypoint >= route.size() - 1)
	check("escort.never_stuck",worst_stall < 2.0)
	check("escort.witness_kept_close",max_gap < 8.0)
	check("evac.mission_won",mission.state == "won")
	check("evac.witness_at_extraction",mission.hostage.global_position.distance_to(mission.extraction) < 4.5)
	check("evac.checkpoint_cleared_after_win",mission.store.checkpoint.is_empty())
	print("escort metrics: waypoint=%d/%d worst_stall=%.2f max_gap=%.2f state=%s" % [waypoint,route.size(),worst_stall,max_gap,mission.state])

	# Isolated on-disk fixtures: never overwrite a player's real files.
	var dir := "user://qa_session/"
	var disk = load("res://scripts/urban/session_store.gd").new()
	disk.directory = dir
	disk.clear_checkpoint()
	check("disk.atomic_checkpoint_write",disk.save_checkpoint(sample))
	check("disk.no_tmp_left",not FileAccess.file_exists(dir+"checkpoint.json.tmp"))
	var again = load("res://scripts/urban/session_store.gd").new()
	again.directory = dir
	again.initialize()
	check("disk.roundtrip",again.checkpoint.stage == 2 and again.checkpoint.ammo == 7 and again.last_error.is_empty())
	var second := sample.duplicate(true)
	second.stage = 3
	disk.save_checkpoint(second)
	check("disk.previous_becomes_backup",read_stage(dir+"checkpoint.json") == 3 and read_stage(dir+"checkpoint.json.bak") == 2)
	write_text(dir+"checkpoint.json","not valid json")
	again.initialize()
	check("disk.backup_recovery",again.checkpoint.stage == 2 and not again.last_error.is_empty())
	# Saving over a damaged live file must keep the good backup rather than rotating junk into it.
	var third := sample.duplicate(true)
	third.stage = 1
	check("disk.save_over_damaged_main",disk.save_checkpoint(third))
	check("disk.good_backup_preserved",read_stage(dir+"checkpoint.json") == 1 and read_stage(dir+"checkpoint.json.bak") == 2)
	var tampered := sample.duplicate(true)
	tampered.health = 500
	write_text(dir+"checkpoint.json",JSON.stringify(tampered))
	again.initialize()
	check("disk.invalid_values_fall_back",again.checkpoint.stage == 2 and not again.last_error.is_empty())
	write_text(dir+"checkpoint.json","x".repeat(70000))
	again.initialize()
	check("disk.oversized_rejected",again.checkpoint.stage == 2)
	write_text(dir+"checkpoint.json.bak","{\"version\":1")
	write_text(dir+"checkpoint.json","[]")
	again.initialize()
	check("disk.both_damaged_start_fresh",again.checkpoint.is_empty() and not again.last_error.is_empty())
	disk.save_checkpoint(sample)
	write_text(dir+"checkpoint.json.tmp","half-written")
	again.initialize()
	check("disk.stale_tmp_ignored",again.checkpoint.stage == 2 and again.last_error.is_empty())
	disk.preferences.sensitivity = .003
	check("disk.settings_write",disk.save_preferences())
	again.initialize()
	check("disk.settings_roundtrip",is_equal_approx(again.preferences.sensitivity,.003))
	write_text(dir+"settings.json","{broken")
	write_text(dir+"settings.json.bak","{broken")
	again.initialize()
	check("disk.damaged_settings_use_defaults",is_equal_approx(again.preferences.sensitivity,again.DEFAULTS.sensitivity) and again.preferences.size() == again.DEFAULTS.size())
	disk.preferences.subtitle_size = 99
	check("disk.invalid_settings_not_written",not disk.save_preferences())
	disk.clear_checkpoint()
	check("disk.clear_removes_all",not FileAccess.file_exists(dir+"checkpoint.json") and not FileAccess.file_exists(dir+"checkpoint.json.bak") and not FileAccess.file_exists(dir+"checkpoint.json.tmp"))
	for suffix: String in ["",".bak",".tmp"]:
		var file_path: String = dir+"settings.json"+suffix
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))

	# A fresh scene with cinematics: pause must also freeze the cutscene clock.
	mission.queue_free()
	await frames(3)
	mission = load("res://scenes/urban_operation.tscn").instantiate()
	mission.persistence_enabled = false
	root.add_child(mission)
	await frames()
	mission.start_mission()
	await frames(3)
	var cinematic_clock: float = mission.cinematic_clock
	mission.pause_menu.open_menu()
	await create_timer(.25,true).timeout
	check("pause.cinematic_frozen",mission.state == "cinematic" and is_equal_approx(mission.cinematic_clock,cinematic_clock))
	mission.pause_menu.close_menu()
	await frames(3)
	check("pause.cinematic_resumes",mission.cinematic_clock > cinematic_clock)
	mission.pause_menu.open_menu()
	mission.queue_free()
	await process_frame
	await frames(25)
	check("pause.scene_cleanup_unpauses",not paused)
	var path := ProjectSettings.globalize_path("res://../outputs/release/session_verification.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failure_count":failures,"status":"PASS" if failures == 0 else "FAIL","engine":Engine.get_version_info()},"\t"))
	file.close()
	print("SESSION: %d checks, %d failures" % [checks.size(),failures])
	call_deferred("quit",0 if failures == 0 else 1)
