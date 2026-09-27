extends "res://scripts/game/hud.gd"
## Reuses input, sound and typography; no omniscient enemy radar in the new FPS.
func _draw() -> void:
	if not is_instance_valid(mission) or not _font:
		return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(1280,720))
	if mission.state == "cinematic":
		_draw_cinematic()
		return
	if mission.state == "active" and Input.is_physical_key_pressed(KEY_TAB):
		_draw_journal()
		return
	if mission.state != "active":
		_draw_overlay()
		return
	var p = mission.player
	draw_rect(Rect2(28,28,450,96),BG)
	draw_rect(Rect2(28,28,3,96),TEAL)
	_text("寂静港口　／　第一章",Vector2(48,53),13,TEAL)
	_text(mission.objective,Vector2(48,80),18)
	_text("剩余威胁 %02d　／　目标距离 %03d 米" % [mission.remaining,int(p.global_position.distance_to(mission.objective_position))],Vector2(48,107),13,MUTED)
	_text("%02d:%02d" % [int(mission.elapsed)/60,int(mission.elapsed)%60],Vector2(1160,49),16,TEAL)
	# A bearing pointer points to the objective even when it is off screen.
	var offset: Vector3 = mission.objective_position - p.global_position
	var bearing := wrapf(atan2(-offset.x,-offset.z)-p._yaw,-PI,PI)
	var needle := Vector2(640 + clampf(bearing/PI,-1,1)*180,42)
	draw_line(Vector2(460,35),Vector2(820,35),MUTED,1)
	draw_colored_polygon(PackedVector2Array([needle+Vector2(-5,0),needle+Vector2(5,0),needle+Vector2(0,7)]),TEAL)
	draw_rect(Rect2(28,625,222,64),BG)
	_text("生命　%03d" % p.health,Vector2(48,653),21)
	draw_rect(Rect2(48,670,178*float(p.health)/p.max_health,4),TEAL)
	draw_rect(Rect2(1020,605,232,84),BG)
	_text("卡宾枪　／　单发",Vector2(1040,631),12,MUTED)
	_text("%02d / %03d" % [p.ammo,p.reserve_ammo],Vector2(1040,669),31)
	if p.is_reloading:
		_center("正在换弹",413,13,TEAL)
		var progress: float = p._action_elapsed / maxf(.01,p._action_duration)
		draw_rect(Rect2(1040,680,190*progress,3),TEAL)
	elif p.ammo == 0:
		_center("按 R 换弹",413,14,TEAL)
	var hint: String = mission.interaction_hint()
	if not hint.is_empty():
		_center(hint,505,15,TEAL)
	if not p._look_enabled:
		_center("点击鼠标恢复视角控制",588,14,TEAL)
	if mission.rescued:
		_text("陈默距你 %d 米" % int(p.global_position.distance_to(mission.hostage.global_position)),Vector2(48,149),13,TEAL)
	if mission.evidence_secured:
		_text("证据：运输记录副本",Vector2(48,173),13,TEAL)
	if mission.rescued and (mission.escort_waiting or mission.escort_hold):
		_text("陈默原地等候，按 H 跟随。" if mission.escort_hold else "陈默无法靠近，请回到通道内。",Vector2(48,197),13,TEAL)
	if mission.radio_time > 0 and mission.store.preferences.subtitles:
		var subtitle_size := int(mission.store.preferences.subtitle_size)
		var height := wrap_lines(mission.radio,675,subtitle_size).size()*(subtitle_size+7)+22
		draw_rect(Rect2(290,670-height,710,height),BG)
		_wrapped(mission.radio,Vector2(308,670-height+subtitle_size+8),675,subtitle_size,INK)
	if notice_time > 0:
		_center(notice,185,15,TEAL)
	_text("WASD 移动　Ctrl 蹲下　Shift 冲刺　右键瞄准　左键开火　R 换弹　E 交互　Tab 记录",Vector2(280,701),11,MUTED)
	var center := Vector2(640,360)
	if not Input.is_action_pressed("aim"):
		for dir in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
			draw_line(center+dir*6,center+dir*11,INK,1)
	else:
		draw_circle(center,1,INK)
	if hit_time > 0:
		for dir in [Vector2(1,1),Vector2(1,-1),Vector2(-1,1),Vector2(-1,-1)]:
			draw_line(center+dir*9,center+dir*15,TEAL,2)
	if hurt_time > 0:
		draw_rect(Rect2(0,0,1280,720),Color(.8,.12,.05,hurt_time*.35),false,16)

func wrap_lines(text: String, width: float, font_size: int) -> PackedStringArray:
	var result := PackedStringArray()
	var line := ""
	# Chinese has no word spaces. Iterate Unicode characters, not UTF-8 bytes.
	for character in text:
		if character == "\n":
			result.append(line)
			line = ""
			continue
		if not line.is_empty() and _font.get_string_size(line+character,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > width:
			result.append(line)
			line = ""
		line += character
	if not line.is_empty():
		result.append(line)
	return result

func _wrapped(text: String, at: Vector2, width: float, font_size: int, color: Color) -> void:
	for line in wrap_lines(text,width,font_size):
		_text(line,at,font_size,color)
		at.y += font_size+7

func play_sound(hurt: bool) -> void:
	if not is_instance_valid(mission.sound):
		return
	if hurt:
		mission.sound.effect("hurt",mission.player.cam.global_position,-14)
	else:
		mission.sound.gun(mission.player.cam.global_position)

func _draw_cinematic() -> void:
	draw_rect(Rect2(0,0,1280,70),Color.BLACK)
	draw_rect(Rect2(0,548,1280,172),Color(0,0,0,.90))
	_text("寂静港口　／　现场记录",Vector2(40,43),18,TEAL)
	_text("配音开启" if mission.sound.voice_enabled else "配音静音",Vector2(865,43),16,MUTED)
	_text("空格或回车：跳过过场",Vector2(1010,43),16,MUTED)
	if mission.store.preferences.subtitles:
		_wrapped(mission.radio,Vector2(90,589),1100,int(mission.store.preferences.subtitle_size)+4,INK)
	_text("北码头　／　第九辖区",Vector2(90,700),12,MUTED)

func _draw_journal() -> void:
	draw_rect(Rect2(80,65,1120,590),BG)
	_text("行动记录",Vector2(112,110),30,TEAL)
	_text("松开 Tab 返回；查看记录时战斗不会暂停。",Vector2(112,147),17,MUTED)
	var y := 185.0
	var first := maxi(0,mission.dialogue_log.size()-4)
	for i in range(first,mission.dialogue_log.size()):
		var lines := wrap_lines(mission.dialogue_log[i],1040,18)
		for line in lines:
			_text(line,Vector2(112,y),18)
			y += 25
		y += 17

func _draw_overlay() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(.025,.045,.052,.94))
	_text("第九辖区",Vector2(48,58),18,TEAL)
	_text("第一人称剧情开发版",Vector2(965,58),12,MUTED)
	_center("第一章　／　清晨五时四十分",179,14,TEAL)
	var title := "寂静港口"
	var subtitle := "突破默瑟街封锁，切断报警上行，把证人带回来。"
	if mission.state == "won":
		title = "证人安全撤离"
		subtitle = "运输记录已校验。今晚的转运地点，是下一步调查的起点。"
	elif mission.state == "lost":
		title = "行动失败"
		subtitle = "靠近车辆和路障蹲下隐蔽，进入仓库前记得补给。"
	_center(title,246,46)
	_center(subtitle,292,17,MUTED)
	draw_line(Vector2(370,323),Vector2(910,323),MUTED,1)
	if mission.state == "briefing":
		_center("清晨五时十二分，北码头发生了选择性停电。",364,17)
		_center("调度员陈默发现“空箱”内有人求救，复制记录后被扣押。",396,16,MUTED)
		_center("你是先遣警员林舟：查清封锁来源，找到陈默，护送他撤离。",427,16,MUTED)
		_center("WASD 移动　／　右键瞄准　／　左键开火　／　R 换弹　／　E 交互",470,14,TEAL)
	else:
		_center("用时 %02d:%02d　／　消除威胁 %d　／　命中率 %d%%" % [int(mission.elapsed)/60,int(mission.elapsed)%60,mission.total_eliminated,int(100.0*mission.hits/maxi(1,mission.shots))],402,20)
		_center("回车从检查点重试；Esc 可选择从头开始。" if mission.state == "lost" and not mission.store.checkpoint.is_empty() else "按回车从本章开头重新行动。",451,14,MUTED)
	draw_rect(BUTTON,TEAL)
	_center("开始行动　／　回车" if mission.state == "briefing" else "重新行动　／　回车",538,17,Color("102c30"))
	_center("Esc 暂停与设置　／　F6 切换阴影　／　F7 开关配音",617,12,MUTED)
	if mission.state in ["briefing","lost"] and not mission.store.checkpoint.is_empty():
		_center("按 C 继续最近检查点　／　第 %d 阶段" % (int(mission.store.checkpoint.stage)+1),578,16,TEAL)
	_center("原创剧情开发版　／　合成配音　／　画面与性能仍在迭代",658,11,MUTED)

func _exit_tree() -> void:
	# End playback before freeing the stream owner, including rapid test/restart exits.
	if is_instance_valid(_sound):
		_sound.stop()
