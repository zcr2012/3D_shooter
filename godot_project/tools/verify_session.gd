extends SceneTree
var failures := 0
var checks: Array[Dictionary] = []
var mission
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
func _run() -> void:
	Engine.max_fps = 120
	create_timer(60,true).timeout.connect(func(): quit(1))
	mission = load("res://scenes/urban_operation.tscn").instantiate()
	mission.persistence_enabled = false
	mission.cinematics_enabled = false
	root.add_child(mission)
	await frames()
	mission.start_mission()
	check("checkpoint.first_deployment",not mission.store.checkpoint.is_empty() and mission.store.checkpoint.stage == 0)
	for enemy in mission.enemies:
		enemy.set_physics_process(false)
	var p = mission.player
	p._ammo = 5
	p._start_reload()
	await frames(5)
	mission.pause_menu.open_menu()
	var elapsed: float = mission.elapsed
	var reload_elapsed: float = p._action_elapsed
	var voice_time: float = mission.sound.voice.get_playback_position()
	check("pause.real_tree_pause",paused and mission.pause_menu.is_open)
	check("pause.audio_paused",mission.sound.voice.stream_paused)
	check("pause.blocks_interaction",not mission.try_interact() and not mission.try_resupply())
	await create_timer(.25,true).timeout
	check("pause.mission_clock_frozen",is_equal_approx(mission.elapsed,elapsed))
	check("pause.reload_frozen",is_equal_approx(p._action_elapsed,reload_elapsed) and p.ammo == 5)
	check("pause.dialogue_position_frozen",absf(mission.sound.voice.get_playback_position()-voice_time) < .08)
	mission.pause_menu.close_menu()
	check("pause.release_guard",not paused and p._await_action_release)
	await frames(5)
	check("pause.reload_resumes",p._action_elapsed > reload_elapsed)
	mission.pause_menu._set_preference(.004,"sensitivity")
	check("settings.sensitivity_applies",is_equal_approx(p.mouse_sensitivity,.004))
	mission.pause_menu._set_preference(false,"shadows")
	var shadows_off := true
	for child in mission.city.get_children():
		if child is DirectionalLight3D:
			shadows_off = shadows_off and not child.shadow_enabled
	check("settings.shadows_apply",shadows_off)
	var sample := {"version":1,"stage":2,"health":77,"ammo":7,"reserve":43,"elapsed":12.5,"shots":9,"hits":4,"supplies":[true,false],"log":["测试记录"]}
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
	mission.store.save_checkpoint(sample)
	check("checkpoint.restore_success",mission.restore_checkpoint())
	await frames()
	p = mission.player
	check("checkpoint.stage_and_gate",mission.stage == 2 and mission.remaining == 2 and not mission.city.warehouse_gate.visible)
	check("checkpoint.inventory_exact",p.health == 77 and p.ammo == 7 and p.reserve_ammo == 43 and not p.is_reloading)
	check("checkpoint.supplies_not_duplicated",mission.supply_uses == [true,false])
	check("checkpoint.cleared_groups_disabled",mission.enemies[0].health == 0 and mission.enemies[0].collision_layer == 0 and not mission.enemies[0].active)
	check("checkpoint.input_and_camera",mission.state == "active" and p.controls_enabled and p.cam.current)
	for enemy in mission.enemies:
		enemy.set_physics_process(false)
	p.position = Vector3(0,.05,-58)
	for enemy in mission.enemies:
		if enemy.encounter == 2:
			enemy.take_damage(100)
	check("checkpoint.rescue_progression",mission.try_interact() and mission.stage == 3 and mission.store.checkpoint.stage == 3)
	for enemy in mission.enemies:
		enemy.set_physics_process(false)
	mission.store.checkpoint.health = 1
	mission.store.checkpoint.ammo = 0
	mission.store.checkpoint.reserve = 0
	mission.restore_checkpoint()
	await frames()
	for enemy in mission.enemies:
		enemy.set_physics_process(false)
	check("checkpoint.minimum_retry_resources",mission.player.health == 60 and mission.player.ammo == 0 and mission.player.reserve_ammo == 30)
	check("checkpoint.escort_restored",mission.rescued and mission.evidence_secured and mission.remaining == 2 and not mission.escort_hold)
	mission.escort_hold = true
	mission.player.position = Vector3(0,.05,-48)
	var witness_position: Vector3 = mission.hostage.position
	await frames(30)
	check("escort.hold_is_stationary",mission.hostage.position.is_equal_approx(witness_position))
	mission.escort_hold = false
	await frames(60)
	check("escort.follow_resumes",mission.hostage.position.distance_to(witness_position) > .5)
	check("escort.outside_nav_rejected",mission.city.escort_path(mission.hostage.position,Vector3(30,0,0)).is_empty())
	check("escort.corner_goal_recovers",not mission.city.escort_path(Vector3(0,0,-55),Vector3(8.4,0,-54)).is_empty())
	# Isolated on-disk fixtures: never overwrite a player's real files.
	var disk = load("res://scripts/urban/session_store.gd").new()
	disk.directory = "user://qa_session/"
	check("disk.atomic_checkpoint_write",disk.save_checkpoint(sample))
	var again = load("res://scripts/urban/session_store.gd").new()
	again.directory = disk.directory
	again.initialize()
	check("disk.roundtrip",again.checkpoint.stage == 2 and again.checkpoint.ammo == 7)
	var second := sample.duplicate(true)
	second.stage = 3
	disk.save_checkpoint(second)
	var broken := FileAccess.open(disk.directory+"checkpoint.json",FileAccess.WRITE)
	broken.store_string("not valid json")
	broken.close()
	again.initialize()
	check("disk.backup_recovery",again.checkpoint.stage == 2 and not again.last_error.is_empty())
	disk.preferences.sensitivity = .003
	check("disk.settings_write",disk.save_preferences())
	again.initialize()
	check("disk.settings_roundtrip",is_equal_approx(again.preferences.sensitivity,.003))
	disk.clear_checkpoint()
	check("disk.clear_removes_backup",not FileAccess.file_exists(disk.directory+"checkpoint.json.bak"))
	for suffix in ["",".bak",".tmp"]:
		var file_path: String = disk.directory+"settings.json"+suffix
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
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
