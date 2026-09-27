extends "res://scripts/player.gd"
## Separate FPS adapter: the v09 animation/controller contract remains intact.
const Textures = preload("res://scripts/game/procedural_textures.gd")
const CASING_POOL := 6
# Camera punch is a damped spring on camera rotation. Shots and hits only add
# velocity impulses; the spring always returns to zero, so there is no continuous shake.
const PUNCH_STIFFNESS := 260.0
const PUNCH_DAMPING := 19.4 # critical * 0.6 for sqrt(260)
var view: Node3D
var left_hand: Node3D
var magazine: Node3D
var left_rest := Vector3.ZERO
var mag_rest := Vector3.ZERO
var bob: float = 0.0
var kick: float = 0.0
var obstructed: bool = false
var flash: MeshInstance3D
var flash_light: OmniLight3D
var flash_petals: Array[MeshInstance3D] = []
var smoke: GPUParticles3D
var casings: Array[MeshInstance3D] = []
var casing_velocity: Array[Vector3] = []
var casing_spin: Array[Vector3] = []
var casing_time: Array[float] = []
var casing_cursor := 0
var punch := Vector3.ZERO
var punch_velocity := Vector3.ZERO
# Weapon lag behind quick turns and a lowered sprint carry (both blend in and out).
var look_sway := Vector3.ZERO
var sprint_blend: float = 0.0
var _last_yaw: float = 0.0
var _last_pitch: float = 0.0
var crouched: bool = false
var body_shape: CollisionShape3D
var capsule: CapsuleShape3D

func _ready() -> void:
	combat_enabled = true
	super._ready()
	model.visible = false
	arm.spring_length = 0.0
	arm.position = Vector3(0, 1.58, 0)
	cam.near = 0.025
	body_shape = $CollisionShape3D
	capsule = body_shape.shape.duplicate() as CapsuleShape3D
	body_shape.shape = capsule
	walk_speed = 2.8
	sprint_speed = 4.8
	_pitch = 0.0
	view = preload("res://assets/urban/fps_kit.glb").instantiate()
	cam.add_child(view)
	left_hand = view.find_child("LeftArm", true, false)
	magazine = view.find_child("Magazine", true, false)
	if left_hand:
		left_rest = left_hand.position
	if magazine:
		mag_rest = magazine.position
	flash = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = .025
	sphere.height = .05
	flash.mesh = sphere
	flash.position = Vector3(.18,-.15,-1.02)
	var flash_material := StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color("ffe8a0")
	flash.material_override = flash_material
	flash.visible = false
	view.add_child(flash)
	_build_flash_petals()
	_build_smoke()
	_no_shadows(view)
	_build_casings()
	shot_fired.connect(func(_a: Vector3, _b: Vector3, _hit: bool): kick = 1.0)
	shot_fired.connect(_on_own_shot)
	damaged.connect(_on_hurt)

func _build_flash_petals() -> void:
	# The original core sphere stays; additive petals and a short light make the
	# flash read as a burst instead of a dot. Roll and scale vary per shot.
	var petal_material := StandardMaterial3D.new()
	petal_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	petal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	petal_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	petal_material.albedo_texture = Textures.star_texture(64)
	petal_material.albedo_color = Color(1.0, 0.86, 0.6)
	petal_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	petal_material.disable_receive_shadows = true
	for i in 3:
		var petal := MeshInstance3D.new()
		var quad := QuadMesh.new()
		# Long side of each tongue runs along the barrel after its rotation below.
		quad.size = [Vector2(0.2, 0.2), Vector2(0.26, 0.1), Vector2(0.1, 0.26)][i]
		petal.mesh = quad
		petal.material_override = petal_material
		# Petal 0 faces down the barrel; petals 1-2 are axial tongues at 90 degrees.
		if i == 1:
			petal.rotation = Vector3(0, PI / 2.0, 0)
		elif i == 2:
			petal.rotation = Vector3(PI / 2.0, 0, 0)
		if i > 0:
			petal.position = Vector3(0, 0, -0.1)
		flash.add_child(petal)
		flash_petals.append(petal)
	flash_light = OmniLight3D.new()
	flash_light.light_color = Color(1.0, 0.8, 0.5)
	flash_light.light_energy = 3.0
	flash_light.omni_range = 3.5
	flash_light.shadow_enabled = false
	flash_light.visible = false
	flash.add_child(flash_light)

func _build_smoke() -> void:
	# One-shot muzzle smoke: a handful of grey puffs that rise and thin out. The
	# emitter rides with the weapon but its particles stay in world space.
	smoke = GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 0, -1)
	process.spread = 18.0
	process.initial_velocity_min = 0.5
	process.initial_velocity_max = 1.1
	process.gravity = Vector3(0, 0.35, 0)
	process.damping_min = 1.2
	process.damping_max = 2.0
	process.scale_min = 0.6
	process.scale_max = 1.3
	process.angle_min = 0.0
	process.angle_max = 360.0
	process.color = Color(0.72, 0.7, 0.66)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.3))
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	ramp.width = 16
	process.color_ramp = ramp
	smoke.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = Textures.soft_disc(32)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_receive_shadows = true
	quad.material = material
	smoke.draw_pass_1 = quad
	smoke.amount = 5
	smoke.lifetime = 0.7
	smoke.one_shot = true
	smoke.explosiveness = 0.85
	smoke.emitting = false
	smoke.local_coords = false
	smoke.fixed_fps = 30
	smoke.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	smoke.position = flash.position + Vector3(0, 0.01, -0.03)
	view.add_child(smoke)

func _build_casings() -> void:
	# Ejected brass: a small ring of top-level meshes moved by a CPU arc, no physics bodies.
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.86, 0.66, 0.32)
	material.metallic = 0.8
	material.roughness = 0.35
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0045
	mesh.bottom_radius = 0.0045
	mesh.height = 0.04
	mesh.radial_segments = 6
	mesh.rings = 1
	for i in CASING_POOL:
		var casing := MeshInstance3D.new()
		casing.mesh = mesh
		casing.material_override = material
		casing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		casing.top_level = true
		casing.visible = false
		add_child(casing)
		casings.append(casing)
		casing_velocity.append(Vector3.ZERO)
		casing_spin.append(Vector3.ZERO)
		casing_time.append(0.0)

func _no_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_no_shadows(child)

func add_punch(pitch: float, yaw: float, roll: float) -> void:
	punch_velocity += Vector3(pitch, yaw, roll)

func _on_own_shot(_origin: Vector3, _target: Vector3, _hit: bool) -> void:
	add_punch(1.25, randf_range(-0.35, 0.35), randf_range(-0.25, 0.25))
	flash.rotation.z = randf_range(0.0, TAU)
	flash.scale = Vector3.ONE * randf_range(0.8, 1.3)
	if is_instance_valid(smoke) and not obstructed:
		smoke.restart()
	_eject_casing()

func _on_hurt(_health: int, amount: int, source: Vector3) -> void:
	# Knock the view down and roll it away from the impact side; strength follows damage.
	var strength := clampf(amount / 12.0, 0.6, 1.6)
	var side := 0.0
	if source.is_finite():
		var offset := source - global_position
		var bearing := wrapf(atan2(-offset.x, -offset.z) - _yaw, -PI, PI)
		side = sin(bearing)
	add_punch(-2.4 * strength, 0.5 * side * strength, -1.6 * side * strength)

func _eject_casing() -> void:
	var slot := casing_cursor
	casing_cursor = (casing_cursor + 1) % CASING_POOL
	var casing := casings[slot]
	casing.global_position = view.to_global(Vector3(0.235, -0.13, -0.55))
	casing.global_basis = cam.global_basis.rotated(cam.global_basis.z, randf_range(0.0, TAU))
	casing_velocity[slot] = cam.global_basis * Vector3(randf_range(1.5, 2.3), randf_range(1.3, 1.9), randf_range(-0.2, 0.4)) + velocity
	casing_spin[slot] = Vector3(randf_range(-18.0, 18.0), randf_range(-6.0, 6.0), randf_range(-18.0, 18.0))
	casing_time[slot] = 0.9
	casing.visible = true

func _update_casings(delta: float) -> void:
	var floor_y := global_position.y + 0.012
	for i in CASING_POOL:
		if casing_time[i] <= 0.0:
			continue
		casing_time[i] -= delta
		var casing := casings[i]
		if casing_time[i] <= 0.0:
			casing.visible = false
			continue
		casing_velocity[i].y -= 9.8 * delta
		casing.global_position += casing_velocity[i] * delta
		if casing.global_position.y <= floor_y:
			casing.global_position.y = floor_y
			# One damped bounce, then the case settles flat until the slot is reused.
			casing_velocity[i] = Vector3(casing_velocity[i].x * 0.4, -casing_velocity[i].y * 0.25, casing_velocity[i].z * 0.4)
			if absf(casing_velocity[i].y) < 0.35:
				casing_velocity[i] = Vector3.ZERO
				casing_spin[i] = Vector3.ZERO
				casing.rotation = Vector3(PI / 2.0, casing.rotation.y, 0)
		if casing_spin[i] != Vector3.ZERO:
			casing.rotate_x(casing_spin[i].x * delta)
			casing.rotate_z(casing_spin[i].z * delta)

func _physics_process(delta: float) -> void:
	if controls_enabled:
		var wants_crouch := _look_enabled and Input.is_physical_key_pressed(KEY_CTRL)
		if wants_crouch:
			crouched = true
		elif crouched and _can_stand():
			crouched = false
		arm.position.y = lerpf(arm.position.y, .90 if crouched else 1.58, 1.0-exp(-16*delta))
		capsule.height = arm.position.y + .12
		body_shape.position.y = capsule.height/2
		walk_speed = 1.65 if crouched else 2.8
		sprint_speed = 1.65 if crouched else 4.8
	super._physics_process(delta)
	# Semi-implicit Euler keeps the spring stable at 60 Hz; it settles in ~0.3 s.
	punch_velocity += (-PUNCH_STIFFNESS * punch - PUNCH_DAMPING * punch_velocity) * delta
	punch += punch_velocity * delta
	cam.rotation = punch
	_update_casings(delta)
	if not is_instance_valid(view):
		return
	view.visible = controls_enabled
	var ads := controls_enabled and _look_enabled and Input.is_action_pressed("aim") and not is_reloading
	bob += delta * horizontal_speed * 2.3
	kick = move_toward(kick, 0.0, delta * 8.0)
	var eye := cam.global_position
	var ray := PhysicsRayQueryParameters3D.create(eye, eye - cam.global_basis.z * 1.05, 1, [get_rid()])
	obstructed = not get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
	flash.visible = kick > .65 and controls_enabled and not obstructed
	flash_light.visible = flash.visible
	var rest := Vector3(-0.18, 0.025, 0.12) if ads else Vector3.ZERO
	var sprinting := controls_enabled and locomotion_state == RUN_CLIP and not ads and not is_reloading
	sprint_blend = lerpf(sprint_blend, 1.0 if sprinting else 0.0, 1.0 - exp(-10.0 * delta))
	var sway := 0.001 if ads else 0.008 + 0.012 * sprint_blend
	rest += Vector3(sin(bob) * sway, absf(cos(bob)) * sway, kick * 0.035)
	rest += Vector3(0.03, -0.05, 0.04) * sprint_blend
	# Turn lag: the weapon trails the camera by a few millimetres and settles quickly.
	var yaw_rate := wrapf(_yaw - _last_yaw, -PI, PI) / maxf(delta, 0.001)
	var pitch_rate := (_pitch - _last_pitch) / maxf(delta, 0.001)
	_last_yaw = _yaw
	_last_pitch = _pitch
	var sway_target := Vector3(clampf(-yaw_rate * 0.004, -0.03, 0.03), clampf(-pitch_rate * 0.003, -0.02, 0.02), 0.0)
	look_sway = look_sway.lerp(sway_target * (0.25 if ads else 1.0), 1.0 - exp(-8.0 * delta))
	rest += look_sway
	var reload_phase := clampf(_action_elapsed / maxf(_action_duration, 0.01), 0.0, 1.0) if is_reloading else 0.0
	var tilt := sin(reload_phase * PI)
	view.position = view.position.lerp(rest + Vector3(0, -0.08 * tilt, 0), 1.0 - exp(-16.0 * delta))
	view.rotation = Vector3(kick * 0.025 - (0.65 if obstructed else 0.0) - 0.28 * sprint_blend, 0.38 * sprint_blend + look_sway.x * 1.2, tilt * 0.25 + 0.12 * sprint_blend)
	if left_hand:
		left_hand.position = left_rest + Vector3(0.04 * tilt, -0.17 * tilt, 0.15 * tilt)
	if magazine:
		magazine.position = mag_rest + Vector3(0, -0.28 * tilt, 0.02 * tilt)

func _fire_hitscan() -> void:
	# FPS uses the eye ray. Hits against near cover cannot emerge beyond a wall.
	var eye := cam.global_position
	fire_at(eye, eye - cam.global_basis.z * 100.0)

func _can_stand() -> bool:
	var head := CapsuleShape3D.new()
	head.radius = .32
	head.height = .64
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = head
	query.transform = Transform3D(Basis.IDENTITY,global_position+Vector3.UP*1.4)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
