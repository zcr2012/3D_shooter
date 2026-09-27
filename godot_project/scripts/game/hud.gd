extends Control
## Resolution-independent Chinese HUD with a bundled OFL CJK font.
const Textures = preload("res://scripts/game/procedural_textures.gd")
var mission
var hit_time: float = 0.0
var hurt_time: float = 0.0
var notice: String = ""
var notice_time: float = 0.0
# Combat feedback state (shared by both HUDs). hit_kind selects the marker style;
# hurt_peak scales the vignette by how badly the last hit landed and how low health is;
# damage_marks hold world yaw angles toward attackers so the arcs stay anchored while turning.
var hit_kind: String = "hit"
var hurt_peak: float = 0.0
var damage_marks: Array[Dictionary] = []
var splats: Array[Dictionary] = []
var clock: float = 0.0
var low_health: float = 0.0
var _font: Font
var _sound: AudioStreamPlayer
var _shot_sound: AudioStreamWAV
var _hurt_sound: AudioStreamWAV
var _vignette: GradientTexture2D
var _splat_textures: Array[Texture2D] = []
var _desaturate: ColorRect
var _desaturate_material: ShaderMaterial
const INK := Color("e0eceb")
const MUTED := Color("8ca4ab")
const TEAL := Color("7be0c4")
const BG := Color(0.025, 0.052, 0.068, 0.94)
const BUTTON := Rect2(490, 505, 300, 52)
const HIT_COLOR := Color("7be0c4")
const HEADSHOT_COLOR := Color("fff2b0")
const KILL_COLOR := Color("f4503c")
const BLOOD := Color(0.62, 0.06, 0.04)
const LOW_HEALTH := 30.0
const DESATURATE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 screen = texture(screen_texture, SCREEN_UV);
	float grey = dot(screen.rgb, vec3(0.3, 0.59, 0.11));
	COLOR = vec4(mix(screen.rgb, vec3(grey) * vec3(1.0, 0.9, 0.88), amount), 1.0);
}
"""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	_sound = AudioStreamPlayer.new()
	_sound.volume_db = -15
	add_child(_sound)
	_shot_sound = _make_sound(false)
	_hurt_sound = _make_sound(true)
	_vignette = Textures.vignette(256, 144, BLOOD)
	for seed_value in [311, 977, 1531]:
		_splat_textures.append(Textures.blob(64, seed_value, 0.32, 0.4, 0.28))
	# The low-health desaturation is a screen-reading shader, so it must draw before
	# this HUD (a sibling inserted in front) rather than on top of the panels. The
	# parent is still adding children while _ready runs, hence the deferred insert.
	call_deferred("_attach_desaturation")

func _attach_desaturation() -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	_desaturate = ColorRect.new()
	_desaturate.name = "LowHealthDesaturate"
	_desaturate.color = Color(1, 1, 1, 0)
	_desaturate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desaturate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = DESATURATE_SHADER
	_desaturate_material = ShaderMaterial.new()
	_desaturate_material.shader = shader
	_desaturate.material = _desaturate_material
	_desaturate.visible = false
	get_parent().add_child(_desaturate)
	get_parent().move_child(_desaturate, get_index())

func register_hit(kind: String) -> void:
	## kind: "hit", "headshot" or "kill" - larger, longer and red for a confirmed kill.
	hit_kind = kind
	hit_time = 0.42 if kind == "kill" else (0.28 if kind == "headshot" else 0.2)

func register_damage(amount: int, source: Vector3) -> void:
	## Vignette strength follows the wound and remaining health; the arc remembers
	## the attacker's world bearing; a splat lands away from the reticle.
	var player = mission.player if is_instance_valid(mission) else null
	var health_fraction := 1.0
	if player != null:
		health_fraction = clampf(float(player.health) / maxf(1.0, float(player.max_health)), 0.0, 1.0)
	hurt_peak = clampf(0.28 + 0.35 * clampf(amount / 25.0, 0.0, 1.0) + 0.4 * (1.0 - health_fraction), 0.0, 0.95)
	hurt_time = 0.35 + 0.25 * (1.0 - health_fraction)
	if source.is_finite() and player != null:
		var offset: Vector3 = source - player.global_position
		damage_marks.append({"yaw": atan2(-offset.x, -offset.z), "time": 1.3})
		if damage_marks.size() > 6:
			damage_marks.pop_front()
	var angle := randf_range(0.0, TAU)
	var radius := randf_range(190.0, 330.0)
	splats.append({"pos": Vector2(640, 360) + Vector2(cos(angle), sin(angle)) * radius, "rot": randf_range(0.0, TAU),
		"scale": randf_range(2.6, 4.2), "time": 1.6, "tex": randi() % _splat_textures.size()})
	if splats.size() > 4:
		splats.pop_front()

func clear_feedback() -> void:
	hit_time = 0.0
	hurt_time = 0.0
	hurt_peak = 0.0
	damage_marks.clear()
	splats.clear()

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
	clock += delta
	for i in range(damage_marks.size() - 1, -1, -1):
		damage_marks[i].time -= delta
		if damage_marks[i].time <= 0.0:
			damage_marks.remove_at(i)
	for i in range(splats.size() - 1, -1, -1):
		splats[i].time -= delta
		if splats[i].time <= 0.0:
			splats.remove_at(i)
	low_health = 0.0
	if is_instance_valid(mission) and mission.state == "active" and is_instance_valid(mission.player):
		var health: int = mission.player.health
		if health > 0:
			low_health = clampf((LOW_HEALTH - health) / LOW_HEALTH, 0.0, 1.0)
	if is_instance_valid(_desaturate):
		_desaturate.visible = low_health > 0.0
		if _desaturate.visible:
			_desaturate_material.set_shader_parameter("amount", 0.55 * low_health + 0.1 * low_health * sin(clock * 5.0))
	mouse_filter = Control.MOUSE_FILTER_IGNORE if mission.state == "active" else Control.MOUSE_FILTER_STOP
	queue_redraw()

func _draw_damage_feedback(player) -> void:
	## Drawn first (under the panels): vignette, blood splats and attacker arcs.
	var flash := hurt_peak * clampf(hurt_time / 0.35, 0.0, 1.0)
	var pulse := low_health * (0.3 + 0.12 * sin(clock * 5.0))
	var alpha := clampf(flash + pulse, 0.0, 0.9)
	if alpha > 0.002:
		draw_texture_rect(_vignette, Rect2(0, 0, 1280, 720), false, Color(1, 1, 1, alpha))
	if low_health > 0.0:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.05, 0.01, 0.01, 0.28 * low_health))
	if hurt_time > 0.2:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.8, 0.12, 0.05, (hurt_time - 0.2) * 0.5 * hurt_peak))
	var base := Transform2D(0.0, size / Vector2(1280, 720), 0.0, Vector2.ZERO)
	for splat in splats:
		var texture: Texture2D = _splat_textures[int(splat.tex)]
		draw_set_transform_matrix(base * Transform2D(float(splat.rot), Vector2.ONE * float(splat.scale), 0.0, Vector2(splat.pos)))
		draw_texture(texture, -texture.get_size() / 2.0, Color(0.42, 0.03, 0.02, 0.7 * clampf(float(splat.time) / 0.6, 0.0, 1.0)))
	draw_set_transform_matrix(base)
	var center := Vector2(640, 360)
	for mark in damage_marks:
		# Screen up is forward; positive bearing is an attacker on the left.
		var bearing := wrapf(float(mark.yaw) - float(player._yaw), -PI, PI)
		var angle := -PI / 2.0 - bearing
		var fade := clampf(float(mark.time) / 0.5, 0.0, 1.0)
		draw_arc(center, 118, angle - 0.3, angle + 0.3, 16, Color(1.0, 0.45, 0.3, 0.3 * fade), 4, true)
		draw_arc(center, 110, angle - 0.42, angle + 0.42, 20, Color(0.92, 0.16, 0.08, 0.88 * fade), 9, true)

func _draw_hit_marker(center: Vector2) -> void:
	if hit_time <= 0:
		return
	var color := HIT_COLOR
	var inner := 9.0
	var outer := 15.0
	var width := 2.0
	if hit_kind == "kill":
		color = KILL_COLOR
		inner = 11.0
		outer = 22.0
		width = 3.0
	elif hit_kind == "headshot":
		color = HEADSHOT_COLOR
		outer = 18.0
		width = 2.5
	color.a = clampf(hit_time / 0.12, 0.0, 1.0)
	for direction in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		draw_line(center + direction * inner, center + direction * outer, color, width)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = event.position * Vector2(1280, 720) / size
		if BUTTON.has_point(point):
			accept_event()
			if mission.state == "briefing":
				mission.start_mission()
			elif mission.state == "won" and mission.has_method("next_chapter"):
				mission.next_chapter()
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
	_draw_damage_feedback(player)
	draw_rect(Rect2(28, 26, 348, 100), BG)
	draw_rect(Rect2(28, 26, 3, 100), TEAL)
	_text("第九辖区　／　现场行动", Vector2(48, 53), 13, TEAL)
	_text("控制仓库区域", Vector2(48, 82), 21)
	var objective := "剩余威胁 %02d" % mission.remaining if mission.remaining > 0 else "前往北侧撤离区"
	_text(objective, Vector2(48, 108), 12, MUTED)
	_text("行动　%02d:%02d" % [int(mission.elapsed) / 60, int(mission.elapsed) % 60], Vector2(1090, 46), 16, TEAL)
	_draw_radar()
	draw_rect(Rect2(28, 616, 262, 76), BG)
	_text("行动员", Vector2(48, 641), 12, MUTED)
	_text("%03d" % player.health, Vector2(48, 676), 30)
	draw_rect(Rect2(124, 655, 142, 5), Color("293d44"))
	draw_rect(Rect2(124, 655, 142 * float(player.health) / player.max_health, 5), TEAL if player.health > 30 else Color("f47a69"))
	draw_rect(Rect2(1000, 602, 252, 90), BG)
	_text("卡宾枪　／　单发", Vector2(1020, 629), 12, MUTED)
	_text("%02d" % player.ammo, Vector2(1020, 674), 38, INK if player.ammo > 0 else Color("f47a69"))
	_text("/  %03d" % player.reserve_ammo, Vector2(1090, 673), 20, MUTED)
	_text("R 换弹", Vector2(1160, 627), 11, TEAL)
	if player.is_reloading:
		var progress: float = clampf(player._action_elapsed / maxf(player._action_duration, 0.01), 0, 1)
		draw_rect(Rect2(1020, 684, 210 * progress, 2), TEAL)
		_center("正在换弹", 409, 13, TEAL)
	elif player.ammo == 0:
		_center("弹匣已空　／　按 R 换弹", 409, 13, Color("f47a69"))
	_text("WASD 移动　Shift 冲刺　右键瞄准　左键开火　Esc 释放鼠标", Vector2(344, 688), 12, MUTED)
	if not player._look_enabled:
		_center("点击鼠标恢复视角控制", 580, 14, TEAL)
	if not mission.supplies_used and player.global_position.distance_to(mission.supply_position) < 2.2:
		_center("[ E ] 领取 60 发备弹", 548, 16, TEAL)
	if notice_time > 0:
		_center(notice, 161, 16, TEAL)
	# Actual raycast reticle is the viewport center at every aspect ratio.
	var center := Vector2(640, 360)
	var gap := 4.0 if Input.is_action_pressed("aim") else 8.0
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(center + direction * gap, center + direction * (gap + 7), INK, 1.5)
	_draw_hit_marker(center)

func _draw_radar() -> void:
	var rect := Rect2(1120, 68, 132, 176)
	draw_rect(rect, BG)
	draw_rect(rect.grow(-8), Color("365059"), false, 1)
	_text("北", Vector2(1182, 87), 11, TEAL)
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
	_text("特警　／　训练场", Vector2(48, 53), 15, TEAL)
	_text("第九版　·　训练关", Vector2(964, 53), 12, MUTED)
	_center("行动简报", 198, 15, TEAL)
	var title := "第九辖区"
	var subtitle := "控制四名武装人员占据的区域，前往北侧撤离点。"
	if mission.state == "won":
		title = "区域已控制"
		subtitle = "全部威胁已解除，撤离确认。"
	elif mission.state == "lost":
		title = "行动失败"
		subtitle = "先脱离敌人视线，利用掩体安全换弹。"
	_center(title, 263, 52)
	_center(subtitle, 308, 17, MUTED)
	draw_line(Vector2(420, 345), Vector2(860, 345), Color("38545c"))
	if mission.state == "briefing":
		_center("第一步：WASD 移动　第二步：右键瞄准　第三步：左键开火", 390, 14)
		_center("R 换弹　／　Shift 冲刺　／　E 补给　／　Esc 释放鼠标", 425, 14, MUTED)
		_center("弹药有限，请留意雷达与警戒提示。", 460, 14, MUTED)
	else:
		_center("用时 %02d:%02d　／　已解除威胁 %d / 4" % [int(mission.elapsed) / 60, int(mission.elapsed) % 60, 4 - mission.remaining], 395, 20)
		var accuracy := int(float(mission.hits) / maxi(mission.shots, 1) * 100)
		_center("射击 %d 次　／　命中率 %d%%" % [mission.shots, accuracy], 435, 16, MUTED)
	draw_rect(BUTTON, TEAL)
	_center("开始行动　／　回车" if mission.state == "briefing" else "重新行动　／　回车", 538, 17, Color("102c30"))
	_center("原创资产　／　本地单人　／　游戏无需联网", 662, 11, MUTED)
