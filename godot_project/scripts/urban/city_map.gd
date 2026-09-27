extends Node3D
## Static architecture is batched by material; collisions remain simple boxes.
var batches: Dictionary = {}
var materials: Dictionary = {}
var checkpoint_gate: StaticBody3D
var warehouse_gate: StaticBody3D
var instance_count: int = 0
var navigation := AStarGrid2D.new()
var obstacles: Array[Rect2] = []

func _ready() -> void:
	_environment()
	block(Vector3(0,-0.2,0), Vector3(92,0.4,140), "asphalt", true)
	for side in [-1.0,1.0]:
		block(Vector3(side*10,0.07,0),Vector3(4,0.14,136),"concrete",true)
		for z in [-52.0,-22.0,10.0,42.0]:
			building(Vector3(side*24,0,z),Vector3(24,13 + abs(z)*0.09,25))
		for z in [-57.0,-37.0,-17.0,3.0,23.0,43.0,61.0]:
			block(Vector3(side*9,2.8,z),Vector3(0.11,5.6,0.11),"steel",false)
			block(Vector3(side*8.4,5.6,z),Vector3(1.3,0.1,0.2),"steel",false)
			block(Vector3(side*8,5.5,z),Vector3(0.55,0.06,0.22),"lamp",false)
	for z in range(-64,66,6):
		block(Vector3(0,0.008,z),Vector3(0.13,0.01,2.6),"paint",false)
	for x in [-7.5,7.5]:
		block(Vector3(x,0.009,0),Vector3(0.1,0.01,130),"paint",false)
	for z in [-24,36]:
		for x in range(-6,7,2):
			block(Vector3(x,0.01,z),Vector3(1,0.02,3),"paint",false)
	# Street sightline breaks: offset vehicles and concrete barriers.
	for p in [Vector3(-4,0,40),Vector3(4,0,28),Vector3(-4,0,0),Vector3(4,0,-14)]:
		vehicle(p)
	for p in [Vector3(-3,0,20),Vector3(4,0,5),Vector3(-3,0,-23)]:
		block(p+Vector3(0,.48,0),Vector3(3,.96,.65),"concrete",true)
		block(p+Vector3(0,.85,.34),Vector3(2.8,.1,.02),"hazard",false)
	# Perimeter cannot be bypassed around the buildings.
	for x in [-46,46]:
		block(Vector3(x,3,0),Vector3(.5,6,140),"concrete",true)
	for z in [-70,70]:
		block(Vector3(0,3,z),Vector3(92,6,.5),"concrete",true)
	# Gates span the central street and join the buildings on either side.
	checkpoint_gate = gate(Vector3(0,1.5,11),Vector3(24,3,.3))
	block(Vector3(-2,1.1,13),Vector3(.55,.7,.25),"hazard",true)
	block(Vector3(-2,1.2,13.15),Vector3(.3,.22,.03),"screen",false)
	sign_at("ACCESS  /  E",Vector3(-2,1.85,13.2),24)
	# Warehouse interior, walkable room, real roof and doorway.
	for x in [-9,9]:
		block(Vector3(x,2.4,-49),Vector3(.4,4.8,26),"plaster",true)
	block(Vector3(0,2.4,-62),Vector3(18,4.8,.4),"plaster",true)
	block(Vector3(0,4.9,-49),Vector3(18.4,.25,26.4),"steel",true)
	for x in [-5.6,5.6]:
		block(Vector3(x,2.4,-36),Vector3(6.8,4.8,.35),"concrete",true)
	block(Vector3(0,4,-36),Vector3(4.4,1.6,.35),"concrete",true)
	warehouse_gate = gate(Vector3(0,1.6,-36),Vector3(4.4,3.2,.25))
	# Block exterior bypass to the prisoner; entry remains the authored doorway.
	for x in [-27.5,27.5]:
		block(Vector3(x,2.5,-36),Vector3(36.6,5,.35),"concrete",true)
	for p in [Vector3(-4,0,-43),Vector3(4,0,-50),Vector3(-5,0,-56)]:
		block(p+Vector3(0,.55,0),Vector3(2.6,1.1,1.5),"crate",true)
		for y in [.15,.9]:
			block(p+Vector3(0,y,.77),Vector3(2.65,.06,.03),"steel",false)
	for z in [-40,-49,-58]:
		block(Vector3(0,4.65,z),Vector3(3,.06,.25),"lamp",false)
		var light := OmniLight3D.new()
		light.position = Vector3(0,3.8,z)
		light.omni_range = 11
		light.light_energy = 1.1
		light.light_color = Color("ffdfb2")
		add_child(light)
	block(Vector3(6,1.15,-30),Vector3(.8,.7,.25),"hazard",true)
	block(Vector3(6,1.22,-29.85),Vector3(.43,.25,.04),"screen",false)
	for p in [Vector3(3,0,48),Vector3(3,0,-32)]:
		block(p+Vector3(0,.3,0),Vector3(.9,.6,.7),"crate",true)
		block(p+Vector3(0,.62,0),Vector3(.5,.03,.15),"screen",false)
	block(Vector3(0,.02,52),Vector3(5,.025,5),"extraction",false)
	sign_at("SECTOR NINE  /  QUARANTINE",Vector3(0,4,10.7),44)
	sign_at("NORTH DOCK   09",Vector3(0,4.3,-35.7),55)
	sign_at("RELAY  /  E",Vector3(6,2,-29.7),24)
	sign_at("EVAC",Vector3(-2,1.2,54),42)
	sign_at("MERCER STREET",Vector3(-8,3.2,36),30)
	_flush()
	rebuild_navigation()

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("52677c")
	sky_material.sky_horizon_color = Color("c9c8bb")
	sky_material.ground_horizon_color = Color("a4a59d")
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c3d0d8")
	env.ambient_light_energy = .65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-32,0)
	sun.light_color = Color("ffe5bf")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	add_child(sun)

func material(key: String) -> StandardMaterial3D:
	if materials.has(key):
		return materials[key]
	var m := StandardMaterial3D.new()
	var palette := {"steel":"3c484b","glass":"344f59","paint":"bcb8a5","lamp":"f5dfb3","hazard":"be803c","crate":"4c625d","screen":"73c9ac","extraction":"3c7971","trim":"777d76"}
	m.albedo_color = Color(palette.get(key,"ffffff"))
	m.roughness = .83
	if key in ["concrete","asphalt","plaster"]:
		m.albedo_texture = load("res://assets/urban/materials/" + key + ".png")
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * .4
	if key == "glass":
		m.metallic = .4
		m.roughness = .22
	if key in ["lamp","screen"]:
		m.emission_enabled = true
		m.emission = m.albedo_color
	materials[key] = m
	return m

func block(pos: Vector3, size: Vector3, key: String, solid: bool) -> void:
	if not batches.has(key):
		batches[key] = []
	batches[key].append(Transform3D(Basis.from_scale(size),pos))
	instance_count += 1
	if solid:
		if pos.y + size.y/2 > .3 and pos.y - size.y/2 < 1.6:
			obstacles.append(Rect2(Vector2(pos.x-size.x/2,pos.z-size.z/2),Vector2(size.x,size.z)).grow(.3))
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.position = pos
		body.add_child(shape)
		add_child(body)

func _flush() -> void:
	for key in batches:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		mesh.material = material(key)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = batches[key].size()
		for i in mm.instance_count:
			mm.set_instance_transform(i,batches[key][i])
		var node := MultiMeshInstance3D.new()
		node.name = "CityBatch_" + key
		node.multimesh = mm
		add_child(node)
	batches.clear()

func building(pos: Vector3, size: Vector3) -> void:
	block(pos+Vector3(0,size.y/2,0),size,"plaster",true)
	for y in range(3,int(size.y),3):
		block(pos+Vector3(0,y,0),Vector3(size.x+.18,.14,size.z+.18),"trim",false)
		for z in range(-10,11,4):
			var face := -signf(pos.x)*(size.x/2+.02)
			block(pos+Vector3(face,y-1,z),Vector3(.08,1.6,2.1),"glass",false)
			block(pos+Vector3(face,y-1.85,z),Vector3(.24,.12,2.3),"trim",false)
	block(pos+Vector3(0,size.y+.15,0),Vector3(size.x+.4,.3,size.z+.4),"steel",false)

func vehicle(pos: Vector3) -> void:
	block(pos+Vector3(0,.65,0),Vector3(1.9,.65,4.4),"steel",true)
	block(pos+Vector3(0,1.16,-.3),Vector3(1.65,.65,2.1),"glass",true)
	block(pos+Vector3(0,1.5,-.3),Vector3(1.72,.1,2.15),"steel",false)
	for x in [-.91,.91]:
		for z in [-1.35,1.35]:
			block(pos+Vector3(x,.32,z),Vector3(.22,.57,.67),"steel",false)
	for x in [-.65,.65]:
		block(pos+Vector3(x,.75,2.22),Vector3(.4,.18,.03),"lamp",false)

func gate(pos: Vector3,size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material("steel")
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = size
	shape.shape = collider
	body.add_child(shape)
	add_child(body)
	return body

func open_gate(body: StaticBody3D) -> void:
	body.collision_layer = 0
	body.collision_mask = 0
	body.visible = false
	rebuild_navigation()

func sign_at(text: String, pos: Vector3, size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = size
	label.pixel_size = .013
	label.modulate = Color("e8dbb9")
	add_child(label)

func rebuild_navigation() -> void:
	navigation.clear()
	navigation.region = Rect2i(0,0,41,251)
	navigation.cell_size = Vector2(.5,.5)
	navigation.offset = Vector2(-10,-62)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	var blocked: Array[Rect2] = obstacles.duplicate()
	for door in [checkpoint_gate,warehouse_gate]:
		if door.visible:
			var size: Vector3 = door.get_child(1).shape.size
			blocked.append(Rect2(Vector2(door.position.x-size.x/2,door.position.z-size.z/2),Vector2(size.x,size.z)).grow(.3))
	for rect in blocked:
		var first := grid_cell(Vector3(rect.position.x,0,rect.position.y))
		var last := grid_cell(Vector3(rect.end.x,0,rect.end.y))
		for x in range(first.x,last.x+1):
			for z in range(first.y,last.y+1):
				var world := Vector2(x*.5-10,z*.5-62)
				if rect.has_point(world):
					navigation.set_point_solid(Vector2i(x,z),true)

func grid_cell(pos: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi((pos.x+10)*2),0,40),clampi(roundi((pos.z+62)*2),0,250))

func escort_path(from_position: Vector3,to_position: Vector3) -> PackedVector2Array:
	var start := grid_cell(from_position)
	var end := grid_cell(to_position)
	if navigation.is_point_solid(start) or navigation.is_point_solid(end):
		return PackedVector2Array()
	return navigation.get_point_path(start,end)
