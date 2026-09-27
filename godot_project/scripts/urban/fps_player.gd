extends "res://scripts/player.gd"
## Separate FPS adapter: the v09 animation/controller contract remains intact.
var view: Node3D
var left_hand: Node3D
var magazine: Node3D
var left_rest := Vector3.ZERO
var mag_rest := Vector3.ZERO
var bob: float = 0.0
var kick: float = 0.0
var obstructed: bool = false
var flash: MeshInstance3D
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
	_no_shadows(view)
	shot_fired.connect(func(_a: Vector3, _b: Vector3, _hit: bool): kick = 1.0)

func _no_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_no_shadows(child)

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
	var rest := Vector3(-0.18, 0.025, 0.12) if ads else Vector3.ZERO
	var sway := 0.001 if ads else 0.008
	rest += Vector3(sin(bob) * sway, absf(cos(bob)) * sway, kick * 0.035)
	var reload_phase := clampf(_action_elapsed / maxf(_action_duration, 0.01), 0.0, 1.0) if is_reloading else 0.0
	var tilt := sin(reload_phase * PI)
	view.position = view.position.lerp(rest + Vector3(0, -0.08 * tilt, 0), 1.0 - exp(-16.0 * delta))
	view.rotation = Vector3(kick * 0.025 - (0.65 if obstructed else 0.0), 0, tilt * 0.25)
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
