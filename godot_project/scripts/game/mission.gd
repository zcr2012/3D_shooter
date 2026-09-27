extends Node3D
## One deliberately small, replayable encounter. Old main.tscn remains the
## isolated animation regression fixture; this scene owns all gameplay state.
const Enemy = preload("res://scripts/game/enemy.gd")
const HUD = preload("res://scripts/game/hud.gd")
const PlayerScene = preload("res://scenes/player.tscn")

var player
var enemies: Array = []
var hud
var state: String = "briefing"
var remaining: int = 0
var elapsed: float = 0.0
var shots: int = 0
var hits: int = 0
var supplies_used: bool = false
var extraction := Vector3(0, 0, -12)
var supply_position := Vector3(7, 0, 7)
var _materials: Dictionary = {}
var _exit_light: OmniLight3D

func _ready() -> void:
	_build_environment()
	player = PlayerScene.instantiate()
	player.position = Vector3(0, 0.2, 10)
	add_child(player)
	player.shot_fired.connect(_on_shot)
	player.damaged.connect(_on_damage)
	player.died.connect(_on_death)
	player.stop_combat()
	for location in [Vector3(-5, 0.1, 0), Vector3(5, 0.1, -3), Vector3(-5, 0.1, -8), Vector3(3, 0.1, -10)]:
		var enemy := Enemy.new()
		enemy.position = location
		enemy.player = player
		enemy.patrol_width = 0.8
		enemy.eliminated.connect(_on_eliminated)
		enemy.fired.connect(_enemy_shot)
		add_child(enemy)
		enemies.append(enemy)
	remaining = enemies.size()
	hud = HUD.new()
	hud.mission = self
	add_child(hud)

func start_mission() -> void:
	if state != "briefing":
		return
	state = "active"
	player.controls_enabled = true
	player._await_action_release = true
	player._set_look(true)
	for enemy in enemies:
		enemy.active = true

func restart_mission() -> void:
	get_tree().reload_current_scene()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ENTER:
			if state == "briefing":
				start_mission()
			elif state in ["won", "lost"]:
				restart_mission()
		elif event.physical_keycode == KEY_E and state == "active":
			try_resupply()

func try_resupply() -> bool:
	if state != "active" or supplies_used or player.global_position.distance_to(supply_position) > 2.2:
		return false
	supplies_used = true
	# Reserve only: never bypass the existing reload completion contract.
	player._reserve_ammo += 60
	hud.notice = "已领取补给　／　备弹增加 60 发"
	hud.notice_time = 3.0
	return true

func _physics_process(delta: float) -> void:
	if state != "active":
		return
	elapsed += delta
	if remaining == 0 and player.global_position.distance_to(extraction) < 1.8:
		_finish("won")

func _on_shot(origin: Vector3, target: Vector3, confirmed: bool) -> void:
	if state != "active":
		return
	shots += 1
	if confirmed:
		hits += 1
		hud.hit_time = 0.16
	_tracer(origin, target, Color("ffe4ab"))
	hud.play_sound(false)

func _enemy_shot(origin: Vector3, target: Vector3) -> void:
	_tracer(origin, target, Color("ed8060"))

func _on_damage(_health: int) -> void:
	if hud:
		hud.hurt_time = 0.35
		hud.play_sound(true)

func _on_death() -> void:
	_finish("lost")

func _on_eliminated(_enemy: Node3D) -> void:
	remaining = maxi(0, remaining - 1)
	if remaining == 0:
		_exit_light.light_color = Color("72ffd7")
		hud.notice = "区域已控制　／　前往撤离区"
		hud.notice_time = 5.0

func _finish(result: String) -> void:
	if state != "active":
		return
	state = result
	player.stop_combat()
	for enemy in enemies:
		enemy.active = false

func _tracer(origin: Vector3, target: Vector3, color: Color) -> void:
	if origin.distance_to(target) < 0.001:
		return
	var line := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, 0.012, origin.distance_to(target))
	line.mesh = mesh
	line.material_override = _mat("tracer" + color.to_html(), color, true)
	add_child(line)
	line.global_position = (origin + target) * 0.5
	var up := Vector3.RIGHT if absf((target - origin).normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP
	line.look_at(target, up)
	get_tree().create_timer(0.07).timeout.connect(line.queue_free)
	var impact := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	impact.mesh = sphere
	impact.material_override = line.material_override
	add_child(impact)
	impact.global_position = target
	get_tree().create_timer(0.12).timeout.connect(impact.queue_free)

func _mat(key: String, color: Color, luminous: bool = false) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	if luminous:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[key] = material
	return material

func _box(label: String, center: Vector3, size: Vector3, color: Color, solid: bool = true, luminous: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(color.to_html() + str(luminous), color, luminous)
	mesh.position = center
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
		mesh.add_child(body)
	return mesh

func _sign(text: String, position_at: Vector3, size: int = 64) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	label.position = position_at
	label.font_size = size
	label.pixel_size = 0.012
	label.modulate = Color("bacccf")
	add_child(label)

func _cover(center: Vector3, size: Vector3) -> void:
	_box("EquipmentCase", center, size, Color("39464a"))
	# Raised edge profiles, reinforced corners and inset handles model real
	# silhouettes rather than a single uniformly shaded placeholder cube.
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_box("CornerGuard", center + Vector3(x * (size.x / 2 - 0.045), 0, z * (size.z / 2 - 0.045)), Vector3(0.09, size.y + 0.04, 0.09), Color("65716d"), false)
	for y in [-1.0, 1.0]:
		_box("CaseRim", center + Vector3(0, y * (size.y / 2 - 0.06), size.z / 2 + 0.01), Vector3(size.x, 0.06, 0.045), Color("7d8880"), false)
	_box("Handle", center + Vector3(0, 0.12, size.z / 2 + 0.03), Vector3(0.24, 0.065, 0.055), Color("151e23"), false)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("111c29")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a8bec9")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-65, -25, 0)
	sun.light_color = Color("c4dce4")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	_box("Floor", Vector3(0, -0.15, 0), Vector3(20, 0.3, 28), Color("3a4549"))
	_box("BackWall", Vector3(0, 2.2, -14), Vector3(20, 4.4, 0.3), Color("526168"))
	_box("FrontWall", Vector3(0, 2.2, 14), Vector3(20, 4.4, 0.3), Color("526168"))
	for side in [-1.0, 1.0]:
		_box("SideWall", Vector3(side * 10, 2.2, 0), Vector3(0.3, 4.4, 28), Color("45575e"))
		for z in [-12, -6, 0, 6, 12]:
			_box("WallRib", Vector3(side * 9.8, 2.2, z), Vector3(0.3, 4.4, 0.22), Color("26373d"))
			_box("WallInset", Vector3(side * 9.62, 1.65, z + 1), Vector3(0.08, 1.1, 1.2), Color("26333a"), false)
	for z in range(-12, 14, 2):
		_box("FloorJoint", Vector3(0, 0.003, z), Vector3(20, 0.004, 0.018), Color("2f3b40"), false)
	for x in range(-8, 10, 2):
		_box("FloorJoint", Vector3(x, 0.003, 0), Vector3(0.018, 0.004, 28), Color("2f3b40"), false)
	for z in [-10, -2, 6]:
		_box("RoofTruss", Vector3(0, 4.2, z), Vector3(20, 0.22, 0.18), Color("283940"), false)
		_box("StripLight", Vector3(0, 4.06, z), Vector3(5, 0.045, 0.15), Color("c6e4de"), false, true)
		var light := OmniLight3D.new()
		light.position = Vector3(0, 3.7, z)
		light.omni_range = 10
		light.light_energy = 1.4
		light.light_color = Color("b4d2d1")
		add_child(light)
	# Low cover and tall partitions create sightline breaks with side routes.
	_cover(Vector3(-2, 0.6, 5), Vector3(2.5, 1.2, 1.1))
	_cover(Vector3(3, 0.65, 1), Vector3(2.2, 1.3, 1.2))
	_cover(Vector3(-3, 0.6, -5), Vector3(2.4, 1.2, 1.1))
	_cover(Vector3(6.7, 0.6, -7), Vector3(1.8, 1.2, 1.3))
	_box("Partition", Vector3(0, 1.5, -2.5), Vector3(2.2, 3, 0.22), Color("576766"))
	_box("PartitionTop", Vector3(0, 3.03, -2.5), Vector3(2.3, 0.1, 0.3), Color("9b8c65"), false)
	_box("ExtractionPad", extraction + Vector3(0, 0.012, 0), Vector3(3, 0.018, 2.5), Color("285b56"), false)
	for x in [-1.5, 1.5]:
		_box("ExitEdge", extraction + Vector3(x, 0.03, 0), Vector3(0.04, 0.025, 2.5), Color("70ddc4"), false, true)
	_exit_light = OmniLight3D.new()
	_exit_light.position = extraction + Vector3.UP * 1.8
	_exit_light.light_color = Color("4f929b")
	_exit_light.omni_range = 4
	add_child(_exit_light)
	_sign("第九辖区", Vector3(0, 3, -13.8), 110)
	_sign("撤离区　／　先解除全部威胁", Vector3(0, 1.8, -13.8), 28)
	_cover(supply_position + Vector3.UP * 0.35, Vector3(1, 0.7, 0.7))
	_sign("补给\n[E] 备弹 60 发", supply_position + Vector3(0, 1.3, 0), 32)
	for z in [8, 4, 0, -4, -8]:
		_box("LaneMark", Vector3(-8, 0.012, z), Vector3(0.08, 0.015, 1.2), Color("b9a16e"), false)
