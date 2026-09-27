extends "res://scripts/urban/chapter.gd"
## Chapter three, "Tide": berth gate, crane zone, port terminal, the stern of the freighter "Tide".
## Original single-player story slice. No copyrighted franchise assets or plot.
const PierMap = preload("res://scripts/urban/pier_map.gd")
const SPAWNS := [Vector3(0,.05,52),Vector3(0,.05,12),Vector3(0,.05,-30),Vector3(0,.05,-44)]

func _init() -> void:
	chapter_index = 3
	chapter_name = "潮汐"
	chapter_time = "深夜二十三时十分"
	spawns.assign(SPAWNS)
	objectives.assign(["突破泊位闸门","穿过岸吊作业区","撤销潮汐号离港许可","在船尾控制沈国栋"])
	objective_points.assign([Vector3(-2,0,18),Vector3(6,0,-14),Vector3(6,0,-40),Vector3(2,0,-60)])
	hints.assign(["[ E ] 打开泊位闸门","[ E ] 确认区域安全，接应组跟进","[ E ] 撤销潮汐号离港许可","[ E ] 控制沈国栋"])
	stage_lines.assign(["pier_gate","pier_hold","",""])
	eliminated_at_stage.assign([0,3,6,9])
	intro_line = "pier_intro"
	outro_line = "pier_arrest"
	opening_radio = "指挥中心：行动代号寂静港口·潮汐。撤销离港许可，控制沈国栋。"
	final_interaction_wins = true
	supply_points.assign([Vector3(3,0,48),Vector3(-6,0,-32)])
	briefing_title = "潮汐"
	briefing_subtitle = "零点涨潮，潮汐号离港。切断许可，把沈国栋留在岸上。"
	briefing_lines.assign(["潮汐号的离港许可只能在舷梯旁的港务终端撤销。","沈国栋和最后一批“货”在船上。","接应组封锁陆侧，泊位由你推进。"])
	won_title = "潮汐号未能离港"
	won_subtitle = "许可已撤销，沈国栋被控制，船上十一人全部找到。"
	lost_subtitle = "系缆桩和岸吊支腿是最好的掩体；上舷梯前先补给。"
	next_prompt = "返回第一章简报　／　回车"
	epilogue.assign(["00:20　六名劳工与船上十一人交由医疗组，全部生还。","港务局保安主管沈国栋及灰岸安保十四人被依法处理；封锁命令的完整链条进入起诉程序。",
		"陈默回到调度室。他把那张存储卡的复印件贴在值班表旁边。","北码头恢复了夜班。潮汐照旧涨落。","第九辖区　／　寂静港口　／　完"])

func _build_city() -> Node3D:
	return PierMap.new()

func _build_chapter() -> void:
	extraction = Vector3(2,0,-60)

func _group_positions(group: int) -> Array:
	return [[Vector3(-4,.1,30),Vector3(5,.1,24),Vector3(-2,.1,19)],[Vector3(4,.1,-2),Vector3(-4,.1,-12),Vector3(3,.1,-24)],
		[Vector3(-4,.1,-43),Vector3(4,.1,-52),Vector3(0,.1,-58)],[Vector3(-4,.1,-22),Vector3(4,.1,-31)]][group]

func _stage_completed(previous: int) -> void:
	match previous:
		0:
			city.open_gate(city.pier_gate)
		1:
			city.open_gate(city.fence_gate)
		2:
			if cinematics_enabled:
				_begin_cinematic("terminal","pier_terminal")
			else:
				broadcast("pier_terminal")

func _restore_world() -> void:
	city.set_gate_open(city.pier_gate,stage > 0)
	city.set_gate_open(city.fence_gate,stage > 1)

func _cinematic_frame(kind: String) -> Array:
	match kind:
		"intro":
			return [Vector3(6,4,58),Vector3(3,2.6,44),Vector3(0,1.6,18)]
		"terminal":
			return [Vector3(3,2,-36),Vector3(6.5,4.8,-42),Vector3(12,6.5,-48)]
		"outro":
			return [Vector3(-2,3,-54),Vector3(0,2.2,-57),Vector3(4,1.1,-60)]
	return super._cinematic_frame(kind)
