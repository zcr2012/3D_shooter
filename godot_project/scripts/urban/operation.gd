extends "res://scripts/urban/chapter.gd"
## Chapter one, "Mercer Street": gate, alarm relay, warehouse nine, witness escort.
## Original single-player story slice. No copyrighted franchise assets or plot.
const SPAWNS := [Vector3(0,.05,52),Vector3(0,.05,13),Vector3(0,.05,-33),Vector3(0,.05,-55)]
var escort_trail: Array[Vector3] = []
var escort_sample: float = 0.0
var witness_anim: AnimationPlayer
var witness_moving := false
var witness_still := 0.0

func _init() -> void:
	chapter_index = 1
	chapter_name = "默瑟街"
	chapter_time = "清晨五时四十分"
	spawns.assign(SPAWNS)
	objectives.assign(["控制默瑟街门禁","切断仓库报警上行","找到并解救调度员陈默","护送陈默返回接应区"])
	objective_points.assign([Vector3(-2,0,13),Vector3(6,0,-30),Vector3(0,0,-58),Vector3(0,0,52)])
	hints.assign(["[ E ] 读取门禁记录并开放通道","[ E ] 切断报警上行","[ E ] 确认身份，接应陈默",""])
	stage_lines.assign(["checkpoint","relay","",""])
	eliminated_at_stage.assign([0,3,6,8])
	intro_line = "intro"
	outro_line = "debrief"
	opening_radio = "指挥中心：行动代号寂静港口，目标是救出证人并保全运输记录。"
	final_interaction_wins = false
	supply_points.assign([Vector3(3,0,48),Vector3(3,0,-32)])
	briefing_title = "寂静港口"
	briefing_subtitle = "突破默瑟街封锁，切断报警上行，把证人带回来。"
	briefing_lines.assign(["清晨五时十二分，北码头发生了选择性停电。","调度员陈默发现“空箱”内有人求救，复制记录后被扣押。","你是先遣警员林舟：查清封锁来源，找到陈默，护送他撤离。"])
	won_title = "证人安全撤离"
	won_subtitle = "运输记录指向今晚的一次转运——集装箱堆场，CN 20437。"
	lost_subtitle = "靠近车辆和路障蹲下隐蔽，进入仓库前记得补给。"
	next_prompt = "进入第二章「堆场」　／　回车"

func _build_chapter() -> void:
	extraction = Vector3(0,0,52)
	_build_hostage()

func _group_positions(group: int) -> Array:
	return [[Vector3(-5,.1,25),Vector3(4,.1,19),Vector3(-3,.1,15)],[Vector3(4,.1,1),Vector3(-4,.1,-13),Vector3(3,.1,-26)],
		[Vector3(-4,.1,-47),Vector3(4,.1,-56)],[Vector3(-4,.1,-5),Vector3(4,.1,22)]][group]

func _chapter_key(event: InputEventKey) -> bool:
	if event.physical_keycode == KEY_H and state == "active" and rescued:
		escort_hold = not escort_hold
		hud.notice = "陈默原地等候，按 H 恢复跟随。" if escort_hold else "陈默开始跟随。"
		hud.notice_time = 4
		return true
	return false

func _stage_completed(previous: int) -> void:
	match previous:
		0:
			city.open_gate(city.checkpoint_gate)
		1:
			city.open_gate(city.warehouse_gate)
		2:
			rescued = true
			evidence_secured = true
			dialogue_queue.assign(["reinforcements"])
			escort_trail.append(hostage.global_position)
			play_witness("Plead",.4)
			if cinematics_enabled:
				_begin_cinematic("rescue","rescue")
			else:
				broadcast("rescue")

func _chapter_tick(delta: float) -> void:
	if not rescued:
		return
	witness_moving = false
	# A small obstacle-inflated grid avoids cutting through cars, walls or corners.
	escort_sample -= delta
	if escort_sample <= 0 and not escort_hold:
		escort_sample = .75
		var path: PackedVector2Array = city.escort_path(hostage.global_position,player.global_position)
		escort_trail.clear()
		escort_waiting = path.is_empty() and hostage.position.distance_to(player.position) > 2
		if path.size() > 1 and Vector2(hostage.position.x,hostage.position.z).distance_to(path[0]) < .4:
			path.remove_at(0)
		for point in path:
			escort_trail.append(Vector3(point.x,.02,point.y))
	if not escort_hold and not escort_trail.is_empty():
		var next: Vector3 = escort_trail.front()
		var travel := next - hostage.global_position
		travel.y = 0
		if travel.length() < .12:
			escort_trail.pop_front()
		elif hostage.global_position.distance_to(player.global_position) > 1.7:
			hostage.position += travel.normalized() * minf(delta*3.1,travel.length())
			hostage.rotation.y = lerp_angle(hostage.rotation.y,atan2(-travel.x,-travel.z),1.0-exp(-12.0*delta))
			witness_moving = true
	witness_still = 0.0 if witness_moving else witness_still + delta
	if witness_still > .6 and hostage.global_position.distance_to(player.global_position) < 6:
		# Standing witness keeps an eye on the officer rather than staring at a wall.
		var look: Vector3 = player.global_position - hostage.global_position
		hostage.rotation.y = lerp_angle(hostage.rotation.y,atan2(-look.x,-look.z),1.0-exp(-3.0*delta))
	play_witness("Jog" if witness_still < .2 else "Idle")

func _check_completion() -> bool:
	return rescued and evidence_secured and remaining == 0 and player.global_position.distance_to(extraction) < 3 and hostage.global_position.distance_to(extraction) < 4.5

func _story_beat() -> String:
	if stage == 3 and player.position.z > -25 and player.position.z < 15:
		return "evidence"
	if stage == 3 and player.position.z > 28:
		return "evac"
	return ""

func _cinematic_frame(kind: String) -> Array:
	match kind:
		"rescue":
			return [Vector3(2,1.7,-54),Vector3(1.3,1.6,-55.3),hostage.global_position + Vector3.UP*1.3]
		"outro":
			return [Vector3(-5,2.7,49),Vector3(-3,2.2,50),hostage.global_position + Vector3.UP]
	return [Vector3(5,3.8,55),Vector3(3,2.3,43),Vector3(0,1.5,19)]

func _restore_world() -> void:
	escort_trail.clear()
	escort_sample = 0
	escort_waiting = false
	escort_hold = false
	rescued = stage == 3
	evidence_secured = rescued
	if rescued:
		dialogue_queue.assign(["reinforcements"])
	hostage.position = Vector3(0,.02,-58)
	hostage.rotation = Vector3(0,PI,0)
	witness_moving = false
	witness_still = 0.0
	play_witness("Idle" if rescued else "Captive",0.0)
	city.set_gate_open(city.checkpoint_gate,stage > 0)
	city.set_gate_open(city.warehouse_gate,stage >= 2)

func _build_hostage() -> void:
	hostage = preload("res://assets/urban/witness.glb").instantiate()
	hostage.name = "Witness"
	hostage.position = Vector3(0,.02,-58)
	hostage.rotation.y = PI
	add_child(hostage)
	_refine_witness(hostage)
	witness_anim = hostage.find_child("AnimationPlayer",true,false)
	if witness_anim:
		for clip in witness_anim.get_animation_list():
			witness_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	play_witness("Captive")

func play_witness(clip: String, blend: float = .25) -> void:
	# Captive (kneeling, tied), Plead (rescue scene), Idle and Jog (escort) from witness.glb.
	if witness_anim and witness_anim.has_animation(clip) and witness_anim.current_animation != clip:
		witness_anim.play(clip,blend)

func _refine_witness(node: Node) -> void:
	# Fabric weave normal on the work shirt and trousers; authored colours are kept.
	# The imported materials belong only to witness.glb, so they are configured in place
	# (idempotent): several surface overrides on one skinned mesh trigger Godot issue
	# #85817 ("Parameter material is null") when the witness is freed.
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var cloth = node.mesh.surface_get_material(i)
			if cloth is StandardMaterial3D and ("uniform" in cloth.resource_name.to_lower() or "denim" in cloth.resource_name.to_lower()):
				cloth.normal_enabled = true
				cloth.normal_texture = preload("res://assets/urban/materials/sleeve_normal.png")
				cloth.normal_scale = .45
				cloth.uv1_triplanar = true
				cloth.uv1_scale = Vector3.ONE*6
				cloth.roughness = .92
	for child in node.get_children():
		_refine_witness(child)
