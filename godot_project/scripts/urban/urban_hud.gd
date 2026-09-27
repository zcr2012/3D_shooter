extends "res://scripts/game/hud.gd"
## Reuses input, sound and typography; no omniscient enemy radar in the new FPS.
func _draw() -> void:
	if not is_instance_valid(mission) or not _font:
		return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(1280,720))
	if mission.state != "active":
		_draw_overlay()
		return
	var p = mission.player
	draw_rect(Rect2(28,28,450,96),BG)
	draw_rect(Rect2(28,28,3,96),TEAL)
	_text("SILENT HARBOR   /   CHAPTER 01",Vector2(48,53),13,TEAL)
	_text(mission.objective,Vector2(48,80),18)
	_text("%02d CONTACTS   /   OBJECTIVE %03dm" % [mission.remaining,int(p.global_position.distance_to(mission.objective_position))],Vector2(48,107),13,MUTED)
	_text("%02d:%02d" % [int(mission.elapsed)/60,int(mission.elapsed)%60],Vector2(1160,49),16,TEAL)
	# A bearing pointer points to the objective even when it is off screen.
	var offset: Vector3 = mission.objective_position - p.global_position
	var bearing := wrapf(atan2(-offset.x,-offset.z)-p._yaw,-PI,PI)
	var needle := Vector2(640 + clampf(bearing/PI,-1,1)*180,42)
	draw_line(Vector2(460,35),Vector2(820,35),MUTED,1)
	draw_colored_polygon(PackedVector2Array([needle+Vector2(-5,0),needle+Vector2(5,0),needle+Vector2(0,7)]),TEAL)
	draw_rect(Rect2(28,625,222,64),BG)
	_text("HEALTH  %03d" % p.health,Vector2(48,653),21)
	draw_rect(Rect2(48,670,178*float(p.health)/p.max_health,4),TEAL)
	draw_rect(Rect2(1020,605,232,84),BG)
	_text("CARBINE  /  SEMI",Vector2(1040,631),12,MUTED)
	_text("%02d / %03d" % [p.ammo,p.reserve_ammo],Vector2(1040,669),31)
	if p.is_reloading:
		_center("RELOADING",413,13,TEAL)
		var progress: float = p._action_elapsed / maxf(.01,p._action_duration)
		draw_rect(Rect2(1040,680,190*progress,3),TEAL)
	elif p.ammo == 0:
		_center("R  /  RELOAD",413,14,TEAL)
	var hint: String = mission.interaction_hint()
	if not hint.is_empty():
		_center(hint,560,15,TEAL)
	if not p._look_enabled:
		_center("CLICK TO RESUME MOUSE LOOK",588,14,TEAL)
	if mission.rescued:
		_text("WITNESS  %dm" % int(p.global_position.distance_to(mission.hostage.global_position)),Vector2(48,149),13,TEAL)
	if mission.radio_time > 0:
		draw_rect(Rect2(290,584,700,73),BG)
		_wrapped(mission.radio,Vector2(308,607),665,15,INK)
	if notice_time > 0:
		_center(notice,185,15,TEAL)
	_text("WASD MOVE   CTRL CROUCH   SHIFT RUN   RMB AIM   LMB FIRE   R RELOAD   E USE   F6 SHADOWS",Vector2(330,701),11,MUTED)
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

func _wrapped(text: String, at: Vector2, width: float, font_size: int, color: Color) -> void:
	var line := ""
	for word in text.split(" "):
		if _font.get_string_size(line+word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > width:
			_text(line,at,font_size,color)
			at.y += font_size+5
			line = ""
		line += word + " "
	_text(line,at,font_size,color)

func _draw_overlay() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(.025,.045,.052,.94))
	_text("SECTOR NINE",Vector2(48,58),18,TEAL)
	_text("FIRST-PERSON STORY SLICE",Vector2(965,58),12,MUTED)
	_center("CHAPTER 01  /  05:40 AM",179,14,TEAL)
	var title := "SILENT HARBOR"
	var subtitle := "Enter Mercer Street. Cut the relay. Bring the witness home."
	if mission.state == "won":
		title = "WITNESS EXTRACTED"
		subtitle = "The shipping records are secure. The investigation has only begun."
	elif mission.state == "lost":
		title = "OPERATOR DOWN"
		subtitle = "Use the parked vehicles as cover. Resupply before entering the warehouse."
	_center(title,246,46)
	_center(subtitle,292,17,MUTED)
	draw_line(Vector2(370,323),Vector2(910,323),MUTED,1)
	if mission.state == "briefing":
		_center("An engineered blackout has sealed off the north dock.",364,17)
		_center("A dock worker copied the manifest before armed contractors detained him.",396,16,MUTED)
		_center("You are the first unit through the cordon. No backup is inside the perimeter.",427,16,MUTED)
		_center("WASD  move   /   RMB  aim   /   LMB  fire   /   R  reload   /   E  interact",470,14,TEAL)
	else:
		_center("TIME %02d:%02d   /   CONTACTS %d   /   HIT RATE %d%%" % [int(mission.elapsed)/60,int(mission.elapsed)%60,mission.total_eliminated,int(100.0*mission.hits/maxi(1,mission.shots))],402,20)
		_center("Enter restarts the chapter from the beginning.",451,14,MUTED)
	draw_rect(BUTTON,TEAL)
	_center("DEPLOY  /  ENTER" if mission.state == "briefing" else "RETRY  /  ENTER",538,17,Color("102c30"))
	_center("ESC RELEASES THE POINTER, NOT PAUSE   /   F6 TOGGLES SHADOWS FOR LOW-END GPUS",617,12,MUTED)
	_center("DEVELOPMENT BUILD  /  ORIGINAL SETTING  /  COMMERCIAL QUALITY NOT YET VALIDATED",658,11,MUTED)

func _exit_tree() -> void:
	# End playback before freeing the stream owner, including rapid test/restart exits.
	if is_instance_valid(_sound):
		_sound.stop()
