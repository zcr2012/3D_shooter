extends SceneTree
## Real-engine regression for chapters two and three plus campaign routing, progress and save rules.
## Run: godot --path godot_project --headless --script res://tools/verify_campaign.gd
const Campaign = preload("res://scripts/urban/campaign.gd")
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
func open_chapter(scene: String) -> void:
	mission = load(scene).instantiate()
	mission.cinematics_enabled = false
	mission.persistence_enabled = false
	root.add_child(mission)
	await frames()
func walkable(point: Vector3) -> bool:
	return mission.city.inside_corridor(point) and not mission.city.navigation.is_point_solid(mission.city.grid_cell(point))
func route_clear(from_point: Vector3, to_point: Vector3) -> bool:
	## The planning grid and the physical world must agree: rays at shin, hip and eye height along the
	## grid route must not hit any collider (thin rotated bodies, un-registered props, closed gates).
	var route: PackedVector2Array = mission.city.escort_path(from_point,to_point)
	if route.size() < 2:
		return false
	var space: PhysicsDirectSpaceState3D = mission.city.get_world_3d().direct_space_state
	for i in route.size()-1:
		for height in [.3,.9,1.5]:
			var a := Vector3(route[i].x,height,route[i].y)
			var b := Vector3(route[i+1].x,height,route[i+1].y)
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1)).is_empty():
				print("  blocked near ",a)
				return false
	return true

func write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text)
	file.close()

func layout_checks(prefix: String) -> void:
	var batches := 0
	for node in mission.city.get_children():
		if node is MultiMeshInstance3D:
			batches += 1
	check(prefix+".static_batch_budget",batches > 0 and batches <= 16)
	check(prefix+".large_geometry",mission.city.instance_count > 300)
	check(prefix+".two_gates_registered",mission.city.gates.size() == 2 and mission.city.gates[0].collision_layer == 1 and mission.city.gates[1].collision_layer == 1)
	var placed := true
	for group in mission.objectives.size():
		for point in mission._group_positions(group):
			placed = placed and walkable(point)
	for point in mission.spawns:
		placed = placed and walkable(point)
	for point in mission.supply_points:
		placed = placed and walkable(point)
	check(prefix+".spawns_and_supplies_on_walkable_cells",placed)
	var reachable := true
	for point in mission.objective_points:
		reachable = reachable and mission.city._near_walkable(point) != Vector2i(-1,-1)
	check(prefix+".objectives_next_to_walkable_cells",reachable)
	var route: PackedVector2Array = mission.city.escort_path(mission.spawns[0],mission.objective_points[0])
	check(prefix+".first_objective_reachable_from_spawn",route.size() > 40)
	check(prefix+".corridor_bounds",mission.city.inside_corridor(Vector3(9.9,0,-61.9)) and not mission.city.inside_corridor(Vector3(10.6,0,0)) and not mission.city.inside_corridor(Vector3(0,0,64)))
	check(prefix+".night_lighting",mission.city.sun_energy < .5 and mission.city.get_children().filter(func(n): return n is OmniLight3D).size() >= 4)
	var texts: Array = [mission.briefing_title,mission.briefing_subtitle,mission.won_title,mission.won_subtitle,mission.lost_subtitle,mission.next_prompt,mission.opening_radio]
	texts.append_array(mission.objectives)
	texts.append_array(mission.hints)
	texts.append_array(mission.briefing_lines)
	var populated := true
	for text in texts:
		populated = populated and String(text).length() > 0 and not String(text).contains("TODO")
	check(prefix+".text_fields_populated",populated and mission.objectives.size() == 4 and mission.hints.size() == 4 and mission.stage_lines.size() == 4 and mission.eliminated_at_stage.size() == 4 and mission.briefing_lines.size() == 3)
	var voiced := true
	var ids: Array = [mission.intro_line,mission.outro_line]
	for id in mission.stage_lines:
		if not String(id).is_empty():
			ids.append(id)
	for id in ids:
		voiced = voiced and mission.has_line(id)
	check(prefix+".dialogue_ids_exist",voiced)

func _run() -> void:
	Engine.max_fps = 120
	create_timer(80).timeout.connect(func():
		push_error("Campaign suite watchdog expired")
		quit(1))
	# ---- Routing table ----
	check("campaign.three_scenes",Campaign.SCENES.size() == 3 and Campaign.NAMES.size() == 3)
	var indices := true
	for i in Campaign.SCENES.size():
		var probe = load(Campaign.SCENES[i]).instantiate()
		indices = indices and probe.chapter_index == i+1 and probe.chapter_name == Campaign.NAMES[i]
		probe.free()
	check("campaign.scene_chapter_indices",indices)

	# ---- Chapter two: the yard ----
	await open_chapter("res://scenes/yard_operation.tscn")
	var p = mission.player
	check("yard.briefing_state",mission.state == "briefing" and mission.chapter_index == 2 and not p.controls_enabled)
	check("yard.rescue_flags_unused",not mission.rescued and mission.hostage == null)
	layout_checks("yard")
	check("yard.container_closed",mission.city.door_hinges.size() == 2 and is_zero_approx(mission.city.door_hinges[0].rotation.y) and mission.city.container_light.light_energy == 0 and mission.city.door_body.collision_layer == 1)
	check("yard.boom_raised",is_zero_approx(mission.city.boom_pivot.rotation.z))
	check("yard.briefing_blocks_interaction",not mission.try_interact() and not mission.try_resupply())
	mission.start_mission()
	freeze()
	check("yard.first_group_only",mission.state == "active" and mission.enemies.size() == 8 and mission.remaining == 3 and mission.enemies[0].active and not mission.enemies[3].active)
	check("yard.opening_radio_is_intro",mission.radio.begins_with("指挥中心") and mission.radio_time > 5)
	check("yard.cannot_skip_remote",not mission.try_interact())
	p.global_position = mission.objective_position
	check("yard.cannot_skip_contacts",not mission.try_interact() and mission.interaction_hint().begins_with("先控制本区域"))
	clear_group()
	await frames()
	check("yard.hint_after_clear",mission.interaction_hint() == "[ E ] 抬起闸口道闸")
	check("yard.gate_opens",mission.try_interact() and mission.stage == 1 and mission.city.yard_gate.collision_layer == 0 and not mission.city.yard_gate.visible)
	check("yard.gate_line_from_chen_mo",mission.radio.begins_with("陈默"))
	check("yard.second_group_active",mission.remaining == 3 and mission.enemies[3].active)
	var route: PackedVector2Array = mission.city.escort_path(mission.spawns[1],mission.objective_points[1])
	check("yard.office_reachable_after_gate",route.size() > 20)
	check("yard.routes_physically_clear_to_office",route_clear(mission.spawns[0],mission.objective_points[0]) and route_clear(mission.objective_points[0],mission.objective_points[1]))
	p.global_position = mission.objective_position
	clear_group()
	await frames()
	check("yard.office_opens_lane_d",mission.try_interact() and mission.stage == 2 and mission.city.lane_gate.collision_layer == 0 and mission.radio.contains("沈国栋"))
	check("yard.lane_d_two_contacts",mission.remaining == 2)
	route = mission.city.escort_path(mission.spawns[2],mission.objective_points[2])
	check("yard.container_reachable_after_lane_gate",route.size() > 20)
	check("yard.route_physically_clear_to_container",route_clear(mission.objective_points[1],mission.objective_points[2]))
	p.global_position = mission.objective_position
	clear_group()
	await frames()
	check("yard.container_opens",mission.try_interact() and mission.stage == 3 and not is_zero_approx(mission.city.door_hinges[0].rotation.y) and mission.city.container_light.light_energy > 1 and mission.city.door_body.collision_layer == 0)
	check("yard.container_line_from_chen_mo",mission.radio.begins_with("陈默") and mission.radio.contains("六个人"))
	check("yard.reinforcements_spawned",mission.enemies.size() == 10 and mission.remaining == 2)
	check("yard.route_physically_clear_to_exit",route_clear(mission.objective_points[2],mission.objective_points[3]))
	# Intercepted radio: fires once, only in the middle lanes, once the previous line has ended.
	mission.radio_time = 0
	p.global_position = Vector3(0,.05,-50)
	mission._physics_process(.01)
	check("yard.intercept_not_in_lane_d",not mission.story_beats.has("yard_intercept"))
	p.global_position = Vector3(0,.05,0)
	mission._physics_process(.01)
	check("yard.intercept_in_middle_lanes",mission.story_beats.has("yard_intercept") and mission.radio.begins_with("沈国栋") and mission.dialogue_log.size() >= 4)
	p.global_position = mission.objective_position
	check("yard.exit_needs_area_clear",not mission.try_interact())
	clear_group()
	await frames()
	check("yard.final_hint",mission.interaction_hint() == "[ E ] 落下出口闸，封锁装车通道")
	var ammo_before: int = p.ammo
	check("yard.exit_boom_wins",mission.try_interact() and mission.state == "won" and not p.controls_enabled and not is_zero_approx(mission.city.boom_pivot.rotation.z))
	check("yard.ten_contacts",mission.total_eliminated == 10 and mission.enemies.filter(func(e): return e.health > 0).is_empty())
	check("yard.debrief_line",mission.radio.begins_with("指挥中心") and mission.radio.contains("三号泊位"))
	check("yard.unlocks_chapter_three",int(mission.store.progress.unlocked) == 3 and not mission.store.progress.completed and mission.store.checkpoint.is_empty())
	p._start_fire()
	check("yard.completion_blocks_shooting",p.ammo == ammo_before)
	check("yard.result_text",mission.won_title == "六人获救" and mission.next_prompt.contains("第三章"))
	# Checkpoint restore inside the chapter and refusal of a foreign chapter's save.
	mission.store.checkpoint = {"version":1,"chapter":2,"stage":2,"health":70,"ammo":12,"reserve":40,"elapsed":30.0,"shots":10,"hits":5,"headshots":1,"supplies":[true,false],"log":[]}
	check("yard.restore_own_checkpoint",mission.restore_checkpoint() and mission.stage == 2 and mission.state == "active" and mission.remaining == 2 and mission.enemies.size() == 8)
	check("yard.restore_world_state",mission.city.yard_gate.collision_layer == 0 and mission.city.lane_gate.collision_layer == 0 and is_zero_approx(mission.city.door_hinges[0].rotation.y) and mission.city.door_body.collision_layer == 1)
	check("yard.restore_counts",mission.total_eliminated == 6 and mission.player.position.distance_to(mission.spawns[2]) < .5 and mission.supply_uses[0] and not mission.supply_uses[1])
	mission.store.checkpoint = {"version":1,"stage":1,"health":70,"ammo":12,"reserve":40,"elapsed":30.0,"shots":10,"hits":5,"supplies":[false,false],"log":[]}
	check("yard.refuses_chapter_one_checkpoint",not mission.restore_checkpoint() and mission.stage == 2)
	check("store.chapter_field_validation",mission.store.valid_checkpoint({"version":1,"chapter":3,"stage":0,"health":100,"ammo":30,"reserve":90,"elapsed":0,"shots":0,"hits":0,"supplies":[false,false],"log":[]})
		and not mission.store.valid_checkpoint({"version":1,"chapter":4,"stage":0,"health":100,"ammo":30,"reserve":90,"elapsed":0,"shots":0,"hits":0,"supplies":[false,false],"log":[]})
		and not mission.store.valid_checkpoint({"version":1,"chapter":"2","stage":0,"health":100,"ammo":30,"reserve":90,"elapsed":0,"shots":0,"hits":0,"supplies":[false,false],"log":[]})
		and not mission.store.valid_checkpoint({"version":1,"chapter":1.5,"stage":0,"health":100,"ammo":30,"reserve":90,"elapsed":0,"shots":0,"hits":0,"supplies":[false,false],"log":[]}))
	check("store.progress_validation",mission.store.valid_progress({"version":1,"unlocked":2,"completed":false}) and not mission.store.valid_progress({"version":1,"unlocked":4,"completed":false})
		and not mission.store.valid_progress({"version":1,"unlocked":"2","completed":false}) and not mission.store.valid_progress({"version":1,"unlocked":2,"completed":1})
		and not mission.store.valid_progress({"version":2,"unlocked":2,"completed":false}) and not mission.store.valid_progress([]))
	check("store.progress_never_regresses",mission.store.unlock_chapter(1) and int(mission.store.progress.unlocked) == 3)
	# Isolated on-disk progress fixture (never the player's real files): write, reload, damage, recover.
	var dir := "user://qa_campaign/"
	var disk = load("res://scripts/urban/session_store.gd").new()
	disk.directory = dir
	disk.initialize()
	check("disk.progress_defaults",int(disk.progress.unlocked) == 1 and disk.progress.completed == false)
	check("disk.progress_unlock_writes",disk.unlock_chapter(2) and FileAccess.file_exists(dir+"campaign.json") and not FileAccess.file_exists(dir+"campaign.json.tmp"))
	var again = load("res://scripts/urban/session_store.gd").new()
	again.directory = dir
	again.initialize()
	check("disk.progress_roundtrip",int(again.progress.unlocked) == 2 and again.progress.completed == false and again.last_error.is_empty())
	check("disk.progress_completed_writes",disk.mark_completed() and disk.unlock_chapter(3))
	again.initialize()
	check("disk.progress_completed_roundtrip",int(again.progress.unlocked) == 3 and again.progress.completed == true)
	write_text(dir+"campaign.json","{\"version\":1,\"unlocked\":9,\"completed\":false}")
	again.initialize()
	check("disk.progress_tampered_falls_back_to_backup",int(again.progress.unlocked) == 2)
	write_text(dir+"campaign.json","not json")
	write_text(dir+"campaign.json.bak","[]")
	again.initialize()
	check("disk.progress_both_damaged_start_fresh",int(again.progress.unlocked) == 1 and again.progress.completed == false)
	# A checkpoint from chapter three must survive a store reload with its chapter intact.
	disk.clear_checkpoint()
	check("disk.checkpoint_keeps_chapter",disk.save_checkpoint({"version":1,"chapter":3,"stage":2,"health":70,"ammo":12,"reserve":40,"elapsed":30.0,"shots":10,"hits":5,"headshots":1,"supplies":[true,false],"log":[]}))
	again.initialize()
	check("disk.checkpoint_chapter_roundtrip",int(again.checkpoint.get("chapter",0)) == 3 and int(again.checkpoint.stage) == 2)
	disk.clear_checkpoint()
	for name in ["campaign.json","campaign.json.bak","campaign.json.tmp"]:
		if FileAccess.file_exists(dir+name):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir+name))
	mission.queue_free()
	await frames()

	# ---- Chapter three: the pier ----
	await open_chapter("res://scenes/pier_operation.tscn")
	p = mission.player
	check("pier.briefing_state",mission.state == "briefing" and mission.chapter_index == 3 and mission.epilogue.size() == 5)
	layout_checks("pier")
	check("pier.gangway_is_walkable_slope",mission.city.gangway_basis.z.y < -.4 and mission.city.gangway_basis.z.y > -.6)
	mission.start_mission()
	freeze()
	check("pier.first_group_only",mission.enemies.size() == 9 and mission.remaining == 3 and not mission.enemies[3].active)
	p.global_position = mission.objective_position
	clear_group()
	await frames()
	check("pier.gate_opens",mission.try_interact() and mission.stage == 1 and mission.city.pier_gate.collision_layer == 0 and mission.radio.begins_with("陈默"))
	p.global_position = mission.objective_position
	clear_group()
	await frames()
	var log_before: int = mission.dialogue_log.size()
	check("pier.crane_zone_opens_fence",mission.try_interact() and mission.stage == 2 and mission.city.fence_gate.collision_layer == 0 and mission.remaining == 3)
	check("pier.missing_clip_is_text_or_skipped",mission.dialogue_log.size() >= log_before and mission.state == "active")
	route = mission.city.escort_path(mission.spawns[2],mission.objective_points[2])
	check("pier.terminal_reachable_after_fence",route.size() > 10)
	check("pier.routes_physically_clear",route_clear(mission.spawns[0],mission.objective_points[0]) and route_clear(mission.objective_points[0],mission.objective_points[1]) and route_clear(mission.objective_points[1],mission.objective_points[2]) and route_clear(mission.objective_points[2],mission.objective_points[3]))
	p.global_position = mission.objective_position
	clear_group()
	await frames()
	check("pier.terminal_revokes_permit",mission.try_interact() and mission.stage == 3 and mission.radio.begins_with("沈国栋") and mission.remaining == 2 and mission.enemies.size() == 11)
	p.global_position = mission.objective_position
	check("pier.stern_needs_area_clear",not mission.try_interact())
	clear_group()
	await frames()
	check("pier.final_hint",mission.interaction_hint() == "[ E ] 控制沈国栋")
	check("pier.arrest_wins",mission.try_interact() and mission.state == "won" and mission.total_eliminated == 11)
	check("pier.arrest_line",mission.radio.begins_with("指挥中心") and mission.radio.contains("沈国栋"))
	check("pier.campaign_completed",mission.store.progress.completed == true and int(mission.store.progress.unlocked) == 3 and mission.store.checkpoint.is_empty())
	check("pier.epilogue_ends_with_title",mission.epilogue.back().contains("寂静港口") and mission.next_prompt.contains("第一章"))
	check("pier.hud_draws_without_error",is_instance_valid(mission.hud) and mission.hud.chapter_label() == "第三章")
	mission.hud.queue_redraw()
	await frames()
	mission.queue_free()
	await frames()

	var path := ProjectSettings.globalize_path("res://../outputs/urban/campaign_verification.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"status":"PASS" if failures == 0 else "FAIL","engine":Engine.get_version_info(),"checks":checks,"failure_count":failures},"\t"))
		file.close()
	else:
		failures += 1
	await frames(20) # Allow the audio thread to release its last playback reference.
	print("CAMPAIGN: %d checks, %d failures" % [checks.size(),failures])
	call_deferred("quit",0 if failures == 0 else 1)
