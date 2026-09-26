extends SceneTree
## Isolated, deterministic gameplay regression. Must exit nonzero on failure.
var failures := 0
var checks: Array[Dictionary] = []
var mission

func _init() -> void:
	call_deferred("_run")

func check(id: String, condition: bool) -> void:
	checks.append({"id": id, "passed": condition})
	if not condition:
		failures += 1
	print("[%s] %s" % ["PASS" if condition else "FAIL", id])

func frames(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _run() -> void:
	Engine.max_fps = 120
	create_timer(40).timeout.connect(func():
		push_error("Gameplay suite watchdog expired")
		quit(1))
	mission = load("res://scenes/mission.tscn").instantiate()
	root.add_child(mission)
	await frames()
	var player = mission.player
	check("briefing.blocks_controls", mission.state == "briefing" and not player.controls_enabled)
	player._start_fire()
	check("briefing.blocks_direct_fire", player.ammo == 30)
	check("mission.four_contacts", mission.remaining == 4 and mission.enemies.size() == 4)
	mission.start_mission()
	check("deployment.enables_controls_and_ai", mission.state == "active" and player.controls_enabled and mission.enemies[0].active)
	# Freeze movement/AI only within this suite; raycasts still use the physics world.
	player.set_physics_process(false)
	for enemy in mission.enemies:
		enemy.set_physics_process(false)
	player.global_position = Vector3(1000, 0, 1000)
	var target = mission.enemies[0]
	target.global_position = Vector3(1000, 0, 995)
	await frames()
	var start: Vector3 = player.global_position + Vector3.UP
	var end: Vector3 = target.global_position + Vector3.UP
	player.fire_at(start, end)
	check("hitscan.applies_damage", target.health == 66)
	check("hitscan.emits_confirmed_hit", mission.hits == 1)
	# Real geometry blocks both weapon hits and enemy vision.
	var wall := StaticBody3D.new()
	wall.position = Vector3(1000, 1, 997.5)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 3, 0.3)
	collision.shape = box
	wall.add_child(collision)
	mission.add_child(wall)
	await frames()
	player.fire_at(start, end)
	check("hitscan.cover_blocks_damage", target.health == 66)
	check("ai.cover_blocks_los", not target.can_see_player())
	wall.queue_free()
	await frames()
	check("ai.clear_los_acquires_player", target.can_see_player())
	# Camera can see past a narrow post, but the muzzle would protrude through it.
	var post := StaticBody3D.new()
	post.position = Vector3(1000, 1, 999.62)
	var post_collision := CollisionShape3D.new()
	var post_shape := BoxShape3D.new()
	post_shape.size = Vector3(0.24, 2, 0.04)
	post_collision.shape = post_shape
	post.add_child(post_collision)
	mission.add_child(post)
	await frames()
	player.cam.look_at(end)
	var camera_query := PhysicsRayQueryParameters3D.create(player.cam.global_position, end, 1 | 4, [player.get_rid()])
	var camera_result: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(camera_query)
	check("camera.peek_fixture_sees_enemy", not camera_result.is_empty() and camera_result.collider == target)
	player._fire_hitscan()
	check("muzzle.clearance_prevents_cover_exploit", target.health == 66)
	post.queue_free()
	await frames()
	player.cam.rotation = Vector3.ZERO
	player.fire_at(start, end)
	player.fire_at(start, end)
	check("enemy.three_hits_eliminate", target.health == 0 and not target.active)
	check("objective.counted_once", mission.remaining == 3)
	target.take_damage(100)
	check("enemy.dead_ignores_repeat_damage", mission.remaining == 3)
	await frames()
	check("enemy.dead_collision_disabled", target.collision_layer == 0)
	# Ammo contracts are still owned by the existing player controller.
	player._start_fire()
	player._start_fire()
	check("weapon.one_round_per_action", player.ammo == 29)
	player._on_animation_finished(&"FireArmed")
	player._start_reload()
	check("reload.starts", player.is_reloading)
	player.take_damage(12)
	check("damage.interrupts_reload_without_refill", player.health == 88 and not player.is_reloading and player.ammo == 29 and player.reserve_ammo == 90)
	player.take_damage(12)
	check("damage.grace_period", player.health == 88)
	# Resupply requires proximity and can only be collected once.
	check("supply.rejects_remote_use", not mission.try_resupply())
	player.global_position = mission.supply_position
	check("supply.collects_once", mission.try_resupply() and player.reserve_ammo == 150)
	check("supply.no_duplicates", not mission.try_resupply() and player.reserve_ammo == 150)
	player.global_position = mission.extraction
	await frames()
	check("objective.cannot_extract_early", mission.state == "active")
	for enemy in mission.enemies:
		if enemy.health > 0:
			enemy.take_damage(100)
	await frames()
	check("objective.clear_then_extract_wins", mission.state == "won" and mission.remaining == 0)
	check("victory.freezes_controls", not player.controls_enabled)
	var ammo_before: int = player.ammo
	player._start_fire()
	check("victory.cannot_fire", player.ammo == ammo_before)
	mission.queue_free()
	await frames()
	# Fresh scene proves restart initialization without resetting fields manually.
	mission = load("res://scenes/mission.tscn").instantiate()
	root.add_child(mission)
	await frames()
	check("restart.fresh_state", mission.remaining == 4 and mission.player.health == 100 and mission.player.ammo == 30 and not mission.supplies_used)
	mission.start_mission()
	for enemy in mission.enemies:
		enemy.set_physics_process(false)
	# Exercise autonomous AI in real physics ticks, rather than only invoking damage.
	var floor_body := StaticBody3D.new()
	floor_body.position = Vector3(1000, -0.1, 998)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(20, 0.2, 20)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	mission.add_child(floor_body)
	mission.player.global_position = Vector3(1000, 0.1, 1000)
	var live_enemy = mission.enemies[0]
	live_enemy.global_position = Vector3(1000, 0.1, 996)
	live_enemy.home = live_enemy.global_position
	live_enemy.set_physics_process(true)
	await frames(30)
	check("ai.acquisition_delay_gives_warning", mission.player.health == 100)
	await frames(70)
	check("ai.autonomous_shot_damages_player", mission.player.health == 88)
	await frames(35)
	mission.player.take_damage(100)
	check("death.ends_mission", mission.state == "lost" and mission.player.health == 0)
	check("death.disables_all_ai", not mission.enemies[0].active)
	var report_path := ProjectSettings.globalize_path("res://../outputs/v09/gameplay_verification.json")
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"status": "PASS" if failures == 0 else "FAIL", "engine": Engine.get_version_info(), "checks": checks, "failure_count": failures}, "\t"))
		file.close()
	else:
		failures += 1
	mission.queue_free()
	await frames()
	print("GAMEPLAY: %d checks, %d failures" % [checks.size(), failures])
	# Let the awaiting coroutine release its local RefCounted shape/query resources.
	call_deferred("quit", 0 if failures == 0 else 1)
