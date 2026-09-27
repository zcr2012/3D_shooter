extends SceneTree
## Real-engine regression, with geometry queries and complete objective progression.
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
		await physics_frame
		await process_frame
func clear_group() -> void:
	for enemy in mission.enemies:
		if enemy.encounter == mission.stage and enemy.health > 0:
			enemy.take_damage(100)
func freeze() -> void:
	mission.player.set_physics_process(false)
	for enemy in mission.enemies:
		enemy.set_physics_process(false)
func _run() -> void:
	Engine.max_fps = 120
	create_timer(50).timeout.connect(func():
		push_error("Urban suite watchdog expired")
		quit(1))
	mission = load("res://scenes/urban_operation.tscn").instantiate()
	root.add_child(mission)
	await frames()
	var p = mission.player
	check("briefing.safe",mission.state == "briefing" and not p.controls_enabled)
	check("fps.camera_at_eye",p.arm.spring_length == 0 and p.arm.position.is_equal_approx(Vector3(0,1.58,0)))
	check("fps.third_person_body_hidden",not p.model.visible)
	check("fps.authored_viewmodel",is_instance_valid(p.view) and is_instance_valid(p.magazine) and is_instance_valid(p.left_hand))
	check("city.large_geometry",mission.city.instance_count > 300)
	var batches := 0
	for node in mission.city.get_children():
		if node is MultiMeshInstance3D:
			batches += 1
	check("city.static_batch_budget",batches > 0 and batches <= 16)
	check("city.warehouse_locked",mission.city.warehouse_gate.collision_layer == 1)
	check("briefing.interaction_blocked",not mission.try_interact() and not mission.try_resupply())
	mission.start_mission()
	freeze()
	check("deployment.first_group_only",mission.enemies[0].active and not mission.enemies[3].active)
	check("objectives.cannot_skip_remote",not mission.try_interact())
	p.global_position = mission.objective_position
	check("objectives.cannot_skip_contacts",not mission.try_interact())
	check("enemy.new_fall_clip",not mission.enemies[0]._animation.get_animation_list().is_empty())
	var fall_found := false
	for key in mission.enemies[0]._animation.get_animation_list():
		fall_found = fall_found or String(key).get_file() == "FallArmed"
	check("enemy.fall_animation_imported",fall_found)
	clear_group()
	await frames()
	check("enemy.death_removes_collision",mission.enemies[0].collision_layer == 0)
	check("checkpoint.unlocked_by_terminal",mission.try_interact() and mission.stage == 1 and mission.city.checkpoint_gate.collision_layer == 0)
	check("checkpoint.next_group_active",mission.remaining == 3 and mission.enemies[3].active)
	# Drive the adapter in real physics ticks: ADS, crouch and independent reload parts.
	p.global_position = Vector3(0,.05,38)
	p.set_physics_process(true)
	Input.action_press("aim")
	await frames(30)
	check("fps.ads_changes_fov",p.cam.fov < 58)
	check("fps.ads_aligns_weapon",p.view.position.x < -.15)
	Input.action_release("aim")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_CTRL
	key.keycode = KEY_CTRL
	key.pressed = true
	Input.parse_input_event(key)
	await frames(25)
	check("crouch.lowers_camera_and_capsule",p.crouched and p.arm.position.y < 1.02 and p.capsule.height < 1.15)
	key = InputEventKey.new()
	key.physical_keycode = KEY_CTRL
	key.keycode = KEY_CTRL
	key.pressed = false
	Input.parse_input_event(key)
	await frames(25)
	check("crouch.restores_standing",not p.crouched and p.arm.position.y > 1.5)
	p._ammo = 5
	p._start_reload()
	await frames(45)
	check("fps.reload_moves_magazine",p.is_reloading and p.magazine.position.y < p.mag_rest.y-.05)
	check("fps.reload_moves_support_hand",p.left_hand.position.distance_to(p.left_rest) > .03)
	check("fps.reload_does_not_grant_early_ammo",p.ammo == 5)
	await frames(150)
	check("fps.reload_completes_atomically",not p.is_reloading and p.ammo == 30 and p.reserve_ammo == 65)
	p._ammo = 30
	p._reserve_ammo = 90
	p.set_physics_process(false)
	# An isolated real-world ray fixture tests first-person cover, not a mocked ray.
	var target = mission.enemies[3]
	p.global_position = Vector3(1000,0,1000)
	p._yaw = 0
	p.rotation = Vector3.ZERO
	p.arm.rotation = Vector3.ZERO
	p.cam.position = Vector3.ZERO
	target.global_position = Vector3(1000,0,996)
	await frames()
	p._fire_hitscan()
	check("fps.eye_ray_damage",target.health == 66)
	var wall := StaticBody3D.new()
	wall.position = Vector3(1000,1,999.8)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2,3,.05)
	shape.shape = box
	wall.add_child(shape)
	mission.add_child(wall)
	await frames()
	p._fire_hitscan()
	check("fps.near_wall_blocks_bullet",target.health == 66)
	check("enemy.wall_blocks_vision",not target.can_see_player())
	check("crouch.stand_checks_obstruction",not p._can_stand())
	wall.queue_free()
	await frames()
	check("enemy.clear_los",target.can_see_player())
	check("crouch.clear_space_can_stand",p._can_stand())
	# Supplies heal but never fill a magazine or bypass reload.
	p.global_position = mission.supply_points[0]
	p.health = 40
	p._ammo = 5
	check("supplies.one_use",mission.try_resupply() and not mission.try_resupply())
	check("supplies.reserve_and_health_only",p.ammo == 5 and p.reserve_ammo == 150 and p.health == 80)
	clear_group()
	p.global_position = mission.objective_position
	check("relay.opens_interior",mission.try_interact() and mission.stage == 2 and not mission.city.warehouse_gate.visible)
	check("interior.two_contacts",mission.remaining == 2)
	clear_group()
	p.global_position = mission.objective_position
	check("witness.rescue_starts_escort",mission.try_interact() and mission.rescued and mission.stage == 3)
	freeze()
	check("reinforcements.two_telegraphed_contacts",mission.remaining == 2)
	var route: PackedVector2Array = mission.city.escort_path(mission.hostage.position,mission.extraction)
	check("escort.route_reaches_extraction",route.size() > 100)
	var safe := not route.is_empty()
	for point in route:
		for obstacle in mission.city.obstacles:
			safe = safe and not obstacle.has_point(point)
	check("escort.route_avoids_inflated_obstacles",safe)
	var before: Vector3 = mission.hostage.position
	p.global_position = Vector3(0,0,-53)
	for i in 80:
		mission._physics_process(1.0/60.0)
	check("escort.actually_moves",mission.hostage.position.distance_to(before) > 1)
	clear_group()
	p.global_position = mission.extraction
	mission._physics_process(.01)
	check("extraction.waits_for_witness",mission.state == "active")
	mission.hostage.global_position = mission.extraction + Vector3(1,0,0)
	mission._physics_process(.01)
	check("extraction.wins_with_witness",mission.state == "won" and not p.controls_enabled)
	check("story.ten_contacts_total",mission.total_eliminated == 10)
	var ammo_before: int = p.ammo
	p._start_fire()
	check("completion.blocks_shooting",p.ammo == ammo_before)
	mission.queue_free()
	await frames()
	mission = load("res://scenes/urban_operation.tscn").instantiate()
	root.add_child(mission)
	await frames()
	check("restart.fresh_story",mission.stage == 0 and not mission.rescued and mission.remaining == 3)
	mission.start_mission()
	freeze()
	var floor_body := StaticBody3D.new()
	floor_body.position = Vector3(1000,-.1,998)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(20,.2,20)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	mission.add_child(floor_body)
	mission.player.global_position = Vector3(1000,.1,1000)
	mission.player.set_physics_process(true)
	var live_enemy = mission.enemies[0]
	live_enemy.global_position = Vector3(1000,.1,996)
	live_enemy.home = live_enemy.global_position
	live_enemy.set_physics_process(true)
	await frames(50)
	check("urban_ai.acquisition_delay",mission.player.health == 100)
	await frames(65)
	check("urban_ai.autonomous_fire",mission.player.health == 90)
	await frames(20)
	mission.player.take_damage(100)
	check("death.fails_and_stops_ai",mission.state == "lost" and not mission.enemies[0].active)
	var path := ProjectSettings.globalize_path("res://../outputs/urban/engine_verification.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"status":"PASS" if failures == 0 else "FAIL","engine":Engine.get_version_info(),"checks":checks,"failure_count":failures,"static_instances":mission.city.instance_count,"static_batches":batches},"\t"))
		file.close()
	else:
		failures += 1
	mission.queue_free()
	await frames(20) # Allow the audio thread to release its last playback reference.
	print("URBAN: %d checks, %d failures" % [checks.size(),failures])
	call_deferred("quit",0 if failures == 0 else 1)
