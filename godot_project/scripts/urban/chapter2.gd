extends "res://scripts/urban/chapter.gd"
## Chapter two, "The Yard": gate, dispatch office, container CN 20437, exit boom before loading.
## Original single-player story slice. No copyrighted franchise assets or plot.
const YardMap = preload("res://scripts/urban/yard_map.gd")
const SPAWNS := [Vector3(0,.05,52),Vector3(0,.05,8),Vector3(0,.05,-33),Vector3(0,.05,-50)]

func _init() -> void:
	chapter_index = 2
	chapter_name = "堆场"
	chapter_time = "夜间二十一时四十分"
	spawns.assign(SPAWNS)
	objectives.assign(["控制堆场闸口","调取堆场调度记录","打开 CN 20437","在装车前封锁出口闸"])
	objective_points.assign([Vector3(-2,0,13),Vector3(5,0,-12),Vector3(0,0,-53),Vector3(-2,0,47)])
	hints.assign(["[ E ] 抬起闸口道闸","[ E ] 调取调度记录","[ E ] 剪断箱门封条","[ E ] 落下出口闸，封锁装车通道"])
	stage_lines.assign(["yard_gate","yard_office","",""])
	eliminated_at_stage.assign([0,3,6,8])
	intro_line = "yard_intro"
	outro_line = "yard_debrief"
	opening_radio = "指挥中心：行动代号寂静港口·第二夜。找到 CN 20437，救出箱内人员。"
	final_interaction_wins = true
	supply_points.assign([Vector3(3,0,48),Vector3(-6,0,-31)])
	briefing_title = "堆场"
	briefing_subtitle = "陈默的记录指向今晚的转运。找到 CN 20437，别让那扇门再被关上。"
	briefing_lines.assign(["记录里的“空箱”今晚将在北湾联运堆场装车。","沈国栋以“例行安保”为由清空了堆场夜班。","你要在装车前找到那只箱子，救出里面的人。"])
	won_title = "六人获救"
	won_subtitle = "潮汐号零点离港——还有一个多小时。"
	lost_subtitle = "巷道狭窄，利用冷藏机组和箱角掩护，逐段推进。"
	next_prompt = "进入第三章「潮汐」　／　回车"

func _build_city() -> Node3D:
	return YardMap.new()

func _build_chapter() -> void:
	extraction = Vector3(-2,0,47)

func _group_positions(group: int) -> Array:
	return [[Vector3(-4,.1,27),Vector3(5,.1,20),Vector3(-1,.1,15)],[Vector3(4,.1,0),Vector3(-4,.1,-14),Vector3(3,.1,-26)],
		[Vector3(-3,.1,-46),Vector3(4,.1,-55)],[Vector3(-1,.1,-6),Vector3(4,.1,22)]][group]

func _stage_completed(previous: int) -> void:
	match previous:
		0:
			city.open_gate(city.yard_gate)
		1:
			city.open_gate(city.lane_gate)
		2:
			city.set_container_open(true)
			if cinematics_enabled:
				_begin_cinematic("container","yard_container")
			else:
				broadcast("yard_container")

func _story_beat() -> String:
	# The exit run: command calls the loading window as the player crosses back through the B lane.
	if stage == 3 and player.global_position.z > -30 and player.global_position.z < 20:
		return "yard_intercept"
	return ""

func _restore_world() -> void:
	city.set_gate_open(city.yard_gate,stage > 0)
	city.set_gate_open(city.lane_gate,stage > 1)
	city.set_container_open(stage > 2)

func _finish(result: String) -> void:
	if state == "active" and result == "won":
		city.set_exit_boom_down(true)
	super._finish(result)

func _cinematic_frame(kind: String) -> Array:
	match kind:
		"intro":
			return [Vector3(6,4,58),Vector3(3,2.4,44),Vector3(0,1.6,13)]
		"container":
			return [Vector3(1.5,1.7,-46),Vector3(.6,1.5,-49.5),Vector3(0,1.2,-55)]
		"outro":
			return [Vector3(-6,3,53),Vector3(-4,2.2,50),Vector3(-2.4,1.1,47)]
	return super._cinematic_frame(kind)
