extends Node3D
## Pooled, allocate-once hit feedback: blood mist, dust puffs, sparks, bullet holes
## and floor blood splats. Nothing is instantiated per shot (integrated-GPU budget):
## each cue reuses the next slot of a fixed ring, so node count and VRAM stay flat no
## matter how many rounds are fired. Particle systems are GPUParticles3D one-shots with
## small counts (<=16 per burst) and no trails, which the Compatibility renderer supports.
const Textures = preload("res://scripts/game/procedural_textures.gd")
const BLOOD_POOL := 6
const IMPACT_POOL := 6
const HOLE_POOL := 24
const SPLAT_POOL := 12
const BLOOD_AMOUNT := 16
const DUST_AMOUNT := 10
const SPARK_AMOUNT := 6

var blood: Array[GPUParticles3D] = []
var dust: Array[GPUParticles3D] = []
var sparks: Array[GPUParticles3D] = []
var holes: Array[MeshInstance3D] = []
var splats: Array[MeshInstance3D] = []
var blood_cursor := 0
var impact_cursor := 0
var hole_cursor := 0
var splat_cursor := 0
# Counters for the engine regression: proves reuse instead of growth.
var blood_bursts := 0
var impact_bursts := 0
var decals_placed := 0
var puff_texture: Texture2D
var spark_texture: Texture2D
var hole_texture: Texture2D
var splat_texture: Texture2D

func _ready() -> void:
	name = "HitEffects"
	puff_texture = Textures.soft_disc(48)
	spark_texture = Textures.soft_disc(16)
	hole_texture = Textures.blob(32, 71, 0.55, 0.22, 0.35)
	splat_texture = Textures.blob(64, 1207, 0.4, 0.38, 0.3)
	# Tint comes from each process material; the sprite materials stay white so
	# vertex colour (colour ramp) is the only multiplier.
	var blood_material := _sprite_material(puff_texture, false)
	var dust_material := _sprite_material(puff_texture, false)
	var spark_material := _sprite_material(spark_texture, true)
	for i in BLOOD_POOL:
		blood.append(_particles(_blood_process(), blood_material, 0.16, BLOOD_AMOUNT, 0.42))
	for i in IMPACT_POOL:
		dust.append(_particles(_dust_process(), dust_material, 0.24, DUST_AMOUNT, 0.55))
		sparks.append(_particles(_spark_process(), spark_material, 0.06, SPARK_AMOUNT, 0.28))
	var hole_material := _decal_material(hole_texture, Color(0.08, 0.07, 0.065, 0.92))
	var splat_material := _decal_material(splat_texture, Color(0.3, 0.02, 0.015, 0.85))
	for i in HOLE_POOL:
		holes.append(_decal(hole_material, 0.085))
	for i in SPLAT_POOL:
		splats.append(_decal(splat_material, 0.7))

func spawn_blood(where: Vector3, direction: Vector3) -> void:
	## Mist leaves the body along the bullet path (exit side), never toward the shooter.
	var system := blood[blood_cursor]
	blood_cursor = (blood_cursor + 1) % BLOOD_POOL
	_aim(system, where, direction)
	system.restart()
	blood_bursts += 1

func spawn_impact(where: Vector3, normal: Vector3) -> void:
	## Dust and sparks leave the surface along its normal; a bullet hole marks the point.
	var slot := impact_cursor
	impact_cursor = (impact_cursor + 1) % IMPACT_POOL
	var facing := normal if normal.length_squared() > 0.5 else Vector3.UP
	_aim(dust[slot], where, facing)
	_aim(sparks[slot], where, facing)
	dust[slot].restart()
	sparks[slot].restart()
	impact_bursts += 1
	_place(holes[hole_cursor], where + facing * 0.012, facing, randf_range(0.8, 1.25))
	hole_cursor = (hole_cursor + 1) % HOLE_POOL

func spawn_splat(where: Vector3, normal: Vector3 = Vector3.UP) -> void:
	_place(splats[splat_cursor], where + normal * 0.02, normal, randf_range(0.7, 1.4))
	splat_cursor = (splat_cursor + 1) % SPLAT_POOL

func floor_under(point: Vector3, space: PhysicsDirectSpaceState3D, exclude: Array[RID] = []) -> Dictionary:
	## Cheap downward probe (static layer only) used to drop a splat beneath a hit enemy.
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.3, point + Vector3.DOWN * 2.5, 1, exclude)
	return space.intersect_ray(query)

func clear() -> void:
	## Checkpoint restore: hide leftover decals so the retried stage starts clean.
	for decal in holes:
		decal.visible = false
	for decal in splats:
		decal.visible = false
	for system in blood:
		system.emitting = false
	for system in dust:
		system.emitting = false
	for system in sparks:
		system.emitting = false

func _aim(node: Node3D, where: Vector3, direction: Vector3) -> void:
	node.global_position = where
	var facing := direction.normalized() if direction.length_squared() > 0.000001 else Vector3.FORWARD
	var up := Vector3.UP if absf(facing.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	node.look_at(where + facing, up)

func _place(decal: MeshInstance3D, where: Vector3, normal: Vector3, scale_factor: float) -> void:
	_aim(decal, where, -normal)
	decal.rotate_object_local(Vector3.FORWARD, randf_range(0.0, TAU))
	decal.scale = Vector3.ONE * scale_factor
	decal.visible = true
	decals_placed += 1

func _particles(process: ParticleProcessMaterial, material: StandardMaterial3D, size: float, amount: int, lifetime: float) -> GPUParticles3D:
	var system := GPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = material
	system.draw_pass_1 = quad
	system.process_material = process
	system.amount = amount
	system.lifetime = lifetime
	system.one_shot = true
	system.explosiveness = 1.0
	system.emitting = false
	system.local_coords = false
	system.fixed_fps = 30
	system.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	system.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(system)
	return system

func _blood_process() -> ParticleProcessMaterial:
	var p := ParticleProcessMaterial.new()
	p.direction = Vector3(0, 0, -1)
	p.spread = 28.0
	p.initial_velocity_min = 1.8
	p.initial_velocity_max = 4.2
	p.gravity = Vector3(0, -5.0, 0)
	p.damping_min = 3.0
	p.damping_max = 6.0
	p.scale_min = 0.45
	p.scale_max = 1.1
	p.color = Color(0.62, 0.06, 0.04)
	p.color_ramp = _fade_ramp(0.95, 0.55)
	return p

func _dust_process() -> ParticleProcessMaterial:
	var p := ParticleProcessMaterial.new()
	p.direction = Vector3(0, 0, -1)
	p.spread = 55.0
	p.initial_velocity_min = 0.7
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, -1.2, 0)
	p.damping_min = 2.5
	p.damping_max = 5.0
	p.scale_min = 0.4
	p.scale_max = 1.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.color = Color(0.7, 0.64, 0.54)
	p.color_ramp = _fade_ramp(0.65, 0.35)
	return p

func _spark_process() -> ParticleProcessMaterial:
	var p := ParticleProcessMaterial.new()
	p.direction = Vector3(0, 0, -1)
	p.spread = 65.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.5
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_min = 0.5
	p.scale_max = 1.0
	p.color = Color(1.0, 0.8, 0.45)
	p.color_ramp = _fade_ramp(1.0, 0.7)
	return p

func _fade_ramp(start_alpha: float, mid_alpha: float) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, start_alpha))
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	gradient.add_point(0.55, Color(1, 1, 1, mid_alpha))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	ramp.width = 32
	return ramp

func _sprite_material(texture: Texture2D, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = texture
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	return m

func _decal_material(texture: Texture2D, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = tint
	m.albedo_texture = texture
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	return m

func _decal(material: StandardMaterial3D, size: float) -> MeshInstance3D:
	var decal := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	decal.mesh = quad
	decal.material_override = material
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decal.visible = false
	add_child(decal)
	return decal
