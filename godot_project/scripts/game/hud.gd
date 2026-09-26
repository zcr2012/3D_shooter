extends Control
## Resolution-independent, asset-free HUD. English UI avoids system-font
## differences; Chinese controls and build instructions live in docs/PLAY.md.
var mission
var hit_time: float = 0.0
var hurt_time: float = 0.0
var notice: String = ""
var notice_time: float = 0.0
var _font: Font
var _sound: AudioStreamPlayer
var _shot_sound: AudioStreamWAV
var _hurt_sound: AudioStreamWAV
const INK := Color("e0eceb")
const MUTED := Color("8ca4ab")
const TEAL := Color("7be0c4")
const BG := Color(0.025, 0.052, 0.068, 0.94)
const BUTTON := Rect2(490, 505, 300, 52)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	_sound = AudioStreamPlayer.new()
	_sound.volume_db = -15
	add_child(_sound)
	_shot_sound = _make_sound(false)
	_hurt_sound = _make_sound(true)

func _make_sound(hurt: bool) -> AudioStreamWAV:
	# Short original synthesized cues; no external sound licensing dependency.
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count := 3307 if hurt else 1984
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9042
	for i in range(count):
		var t := float(i) / 22050.0
		var envelope := exp(-t * (24.0 if hurt else 55.0))
		var sample := sin(t * TAU * (110.0 if hurt else 65.0)) * 0.4
		sample += rng.randf_range(-1, 1) * (0.15 if hurt else 0.5)
		data.encode_s16(i * 2, int(sample * envelope * 24000))
	stream.data = data
	return stream

func play_sound(hurt: bool) -> void:
	_sound.stream = _hurt_sound if hurt else _shot_sound
	_sound.play()

func _process(delta: float) -> void:
	hit_time = maxf(0, hit_time - delta)
	hurt_time = maxf(0, hurt_time - delta)
	notice_time = maxf(0, notice_time - delta)
	mouse_filter = Control.MOUSE_FILTER_IGNORE if mission.state == "active" else Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = event.position * Vector2(1280, 720) / size
		if BUTTON.has_point(point):
			accept_event()
			if mission.state == "briefing":
				mission.start_mission()
			elif mission.state in ["won", "lost"]:
				mission.restart_mission()

func _text(text: String, at: Vector2, font_size: int = 16, color: Color = INK) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _center(text: String, y: float, font_size: int, color: Color = INK) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(text, Vector2((1280 - width) / 2, y), font_size, color)

func _draw() -> void:
	if not is_instance_valid(mission) or not _font:
		return
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(1280, 720))
	if mission.state != "active":
		_draw_overlay()
		return
	var player = mission.player
	draw_rect(Rect2(28, 26, 348, 100), BG)
	draw_rect(Rect2(28, 26, 3, 100), TEAL)
	_text("FIELD OPERATIONS   /   09", Vector2(48, 53), 13, TEAL)
	_text("CLEAR THE WAREHOUSE", Vector2(48, 82), 21)
	var objective := "%02d CONTACTS REMAIN" % mission.remaining if mission.remaining > 0 else "REACH THE NORTH EXTRACTION ZONE"
	_text(objective, Vector2(48, 108), 12, MUTED)
	_text("LIVE  /  %02d:%02d" % [int(mission.elapsed) / 60, int(mission.elapsed) % 60], Vector2(1090, 46), 16, TEAL)
	_draw_radar()
	draw_rect(Rect2(28, 616, 262, 76), BG)
	_text("OPERATOR", Vector2(48, 641), 12, MUTED)
	_text("%03d" % player.health, Vector2(48, 676), 30)
	draw_rect(Rect2(124, 655, 142, 5), Color("293d44"))
	draw_rect(Rect2(124, 655, 142 * float(player.health) / player.max_health, 5), TEAL if player.health > 30 else Color("f47a69"))
	draw_rect(Rect2(1000, 602, 252, 90), BG)
	_text("CARBINE  /  SEMI", Vector2(1020, 629), 12, MUTED)
	_text("%02d" % player.ammo, Vector2(1020, 674), 38, INK if player.ammo > 0 else Color("f47a69"))
	_text("/  %03d" % player.reserve_ammo, Vector2(1090, 673), 20, MUTED)
	_text("R  RELOAD", Vector2(1160, 627), 11, TEAL)
	if player.is_reloading:
		var progress: float = clampf(player._action_elapsed / maxf(player._action_duration, 0.01), 0, 1)
		draw_rect(Rect2(1020, 684, 210 * progress, 2), TEAL)
		_center("RELOADING", 409, 13, TEAL)
	elif player.ammo == 0:
		_center("MAGAZINE EMPTY  /  PRESS R", 409, 13, Color("f47a69"))
	_text("WASD  MOVE    SHIFT  RUN    RMB  AIM    LMB  FIRE    ESC  CURSOR", Vector2(344, 688), 12, MUTED)
	if not player._look_enabled:
		_center("CLICK TO RECAPTURE THE POINTER", 580, 14, TEAL)
	if not mission.supplies_used and player.global_position.distance_to(mission.supply_position) < 2.2:
		_center("[ E ]  COLLECT 60 RESERVE ROUNDS", 548, 16, TEAL)
	if notice_time > 0:
		_center(notice, 161, 16, TEAL)
	# Actual raycast reticle is the viewport center at every aspect ratio.
	var center := Vector2(640, 360)
	var gap := 4.0 if Input.is_action_pressed("aim") else 8.0
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(center + direction * gap, center + direction * (gap + 7), INK, 1.5)
	if hit_time > 0:
		for direction in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(center + direction * 11, center + direction * 17, TEAL, 2)
	if hurt_time > 0:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.8, 0.13, 0.07, hurt_time * 0.3), false, 15)

func _draw_radar() -> void:
	var rect := Rect2(1120, 68, 132, 176)
	draw_rect(rect, BG)
	draw_rect(rect.grow(-8), Color("365059"), false, 1)
	_text("N", Vector2(1182, 87), 11, TEAL)
	var p: Vector3 = mission.player.global_position
	var dot_at := Vector2(1186 + p.x * 5.0, 156 + p.z * 5.0)
	draw_circle(dot_at, 3.0, TEAL)
	var facing := Vector2(-sin(mission.player._yaw), -cos(mission.player._yaw))
	draw_line(dot_at, dot_at + facing * 10, TEAL, 2)
	for enemy in mission.enemies:
		if enemy.health > 0:
			var location: Vector3 = enemy.global_position
			draw_circle(Vector2(1186 + location.x * 5.0, 156 + location.z * 5.0), 2.5, Color("e8a575"))
	if mission.remaining == 0:
		draw_rect(Rect2(1180, 90, 12, 7), TEAL)

func _draw_overlay() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.025, 0.052, 0.068, 0.91))
	for x in range(0, 1280, 40):
		draw_line(Vector2(x, 0), Vector2(x, 720), Color(0.3, 0.6, 0.65, 0.035))
	_text("SWAT   /   TACTICAL LAB", Vector2(48, 53), 15, TEAL)
	_text("V09   ·   PLAYABLE PROTOTYPE", Vector2(964, 53), 12, MUTED)
	_center("OPERATION", 198, 15, TEAL)
	var title := "SECTOR NINE"
	var subtitle := "Clear four hostile contacts. Reach the north extraction zone."
	if mission.state == "won":
		title = "SECTOR SECURED"
		subtitle = "All contacts neutralized. Extraction confirmed."
	elif mission.state == "lost":
		title = "OPERATOR DOWN"
		subtitle = "Break line of sight. Use cover before reloading."
	_center(title, 263, 52)
	_center(subtitle, 308, 17, MUTED)
	draw_line(Vector2(420, 345), Vector2(860, 345), Color("38545c"))
	if mission.state == "briefing":
		_center("01  MOVE WITH WASD     02  AIM WITH RMB     03  FIRE WITH LMB", 390, 14)
		_center("R  reload    /    SHIFT  sprint    /    E  collect supply    /    ESC  release cursor", 425, 14, MUTED)
		_center("Ammunition is limited. Watch the radar and the contact warning.", 460, 14, MUTED)
	else:
		_center("TIME  %02d:%02d     /     CONTACTS  %d / 4" % [int(mission.elapsed) / 60, int(mission.elapsed) % 60, 4 - mission.remaining], 395, 20)
		var accuracy := int(float(mission.hits) / maxi(mission.shots, 1) * 100)
		_center("SHOTS  %d     /     HIT RATE  %d%%" % [mission.shots, accuracy], 435, 16, MUTED)
	draw_rect(BUTTON, TEAL)
	_center("DEPLOY  /  ENTER" if mission.state == "briefing" else "RETRY  /  ENTER", 538, 17, Color("102c30"))
	_center("PROCEDURAL ASSETS  /  LOCAL SINGLE-PLAYER  /  NO NETWORK REQUIRED", 662, 11, MUTED)
