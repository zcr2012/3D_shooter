extends "res://scripts/urban/city_map.gd"
## Chapter two: the North Bay Intermodal container yard at 21:40. Same 0.5 m planning corridor as
## Mercer Street (x -10..10, z 63..-62) so the tactical AI, cover slots and checkpoints behave identically.
const BOX_TINTS := [Color("6e6a55"),Color("5f7a6e"),Color("8a4b3c"),Color("3f5a78"),Color("7a7f6a"),Color("a0522d"),Color("4f6f8f"),Color("6b6b6b")]
var yard_gate: StaticBody3D
var lane_gate: StaticBody3D
var door_hinges: Array[Node3D] = []
var boom_pivot: Node3D
var door_body: StaticBody3D
var container_light: OmniLight3D
var tint_index := 0

func _init() -> void:
	sky_top = Color("0b1220")
	sky_horizon = Color("2a3345")
	ground_horizon = Color("1a1f28")
	ambient_color = Color("6f7f9a")
	ambient_energy = .34
	sun_rotation = Vector3(-55,140,0)
	sun_color = Color("9fb4d8")
	sun_energy = .3

func build() -> void:
	block(Vector3(0,-.2,0),Vector3(92,.4,140),"asphalt",true)
	block(Vector3(0,.006,-49),Vector3(24.8,.012,26),"concrete",false)
	for x in [-7.5,7.5]:
		block(Vector3(x,.009,12),Vector3(.12,.01,100),"hazard",false)
	for z in range(-30,64,8):
		block(Vector3(0,.008,z),Vector3(.12,.01,3),"paint",false)
	for x in [-46,46]:
		block(Vector3(x,3,0),Vector3(.5,6,140),"concrete",true)
	for z in [-70,70]:
		block(Vector3(0,3,z),Vector3(92,6,.5),"concrete",true)
	_stacks()
	_entrance()
	_office()
	_lane_d()
	_yard_furniture()
	for i in 5:
		var side := 1.0 if i%2 == 1 else -1.0
		lamp_post(Vector3(side*9.2,0,50-i*24),side)

func _next_tint() -> Color:
	tint_index += 1
	return BOX_TINTS[(tint_index*3)%BOX_TINTS.size()]

func container(pos: Vector3, length: float, tint: Color, solid: bool, along_x: bool = false) -> void:
	## One ISO box: body, four corner posts, two top rails. Ground-level front-row boxes are solid walls.
	var size := Vector3(length,2.6,2.44) if along_x else Vector3(2.44,2.6,length)
	block(pos+Vector3(0,1.3,0),size,"crate",solid,tint)
	for a in [-1.0,1.0]:
		for b in [-1.0,1.0]:
			var corner := Vector3(a*(size.x/2-.08),1.3,b*(size.z/2-.08))
			block(pos+corner,Vector3(.2,2.64,.2),"steel",false)
	for a in [-1.0,1.0]:
		var rail := Vector3(0,2.58,a*(size.z/2-.02)) if along_x else Vector3(a*(size.x/2-.02),2.58,0)
		var rail_size := Vector3(size.x,.08,.08) if along_x else Vector3(.08,.08,size.z)
		block(pos+rail,rail_size,"steel",false)

func _stacks() -> void:
	# Two rows per side, 40 ft boxes end to end (0.3 m gaps: narrower than the player capsule), stacked up to three high.
	for side in [-1.0,1.0]:
		for row in [13.7,16.5]:
			for k in 10:
				var z := -56.25 + k*12.5
				var front: bool = row < 14
				container(Vector3(side*row,0,z),12.2,_next_tint(),front)
				if (k+int(row))%3 != 0:
					container(Vector3(side*row,2.6,z),12.2,_next_tint(),false)
				if k%4 == 1 and not front:
					container(Vector3(side*row,5.2,z),12.2,_next_tint(),false)
	var lanes := ["A","B","C"]
	for side in [-1.0,1.0]:
		for i in lanes.size():
			var label := sign_at("%s 巷" % lanes[i],Vector3(side*12.4,3.1,[40,4,-28][i]),40)
			label.rotation.y = -side*PI/2
		# Fence off the strip behind the stacks at both ends so the yard has no back way around.
		for z in [-64.0,64.0]:
			block(Vector3(side*29,1.5,z),Vector3(34,3,.2),"steel",true)

func _entrance() -> void:
	# Inner gate: chain-link leaf across the full lane plus the boom the player raises at stage 0.
	yard_gate = gate(Vector3(0,1.5,11),Vector3(24.8,3,.25))
	block(Vector3(-1.2,1.1,10.2),Vector3(9,.12,.12),"hazard",false)
	for x in [-4.5,4.5]:
		block(Vector3(x,1.4,13.6),Vector3(2.2,2.8,2.2),"plaster",true,Color("d8d2c0"))
		block(Vector3(x,1.7,12.48),Vector3(1.5,.8,.04),"glass",false)
		block(Vector3(x,2.9,13.6),Vector3(2.6,.16,2.6),"steel",false)
	block(Vector3(-2,1.1,13),Vector3(.55,.7,.25),"hazard",true)
	block(Vector3(-2,1.28,12.86),Vector3(.32,.2,.02),"screen",false)
	sign_at("闸口控制　／　E",Vector3(-2,1.85,13.2),24)
	var banner := sign_at("北湾联运　集装箱堆场",Vector3(0,4,10.6),44)
	banner.modulate = Color("f0d9a8")
	# Outer boom at the truck exit: raised when the chapter starts, lowered by the final interaction.
	block(Vector3(-4.6,1.4,49.2),Vector3(2.2,2.8,2.2),"plaster",true,Color("d8d2c0"))
	block(Vector3(-4.6,1.7,48.08),Vector3(1.5,.8,.04),"glass",false)
	block(Vector3(-4.6,2.9,49.2),Vector3(2.6,.16,2.6),"steel",false)
	block(Vector3(-2,1.1,47),Vector3(.55,.7,.25),"hazard",true)
	block(Vector3(-2,1.28,46.86),Vector3(.32,.2,.02),"screen",false)
	sign_at("出口闸控制　／　E",Vector3(-2,1.85,47.2),24)
	boom_pivot = Node3D.new()
	boom_pivot.position = Vector3(-3.3,1,47)
	var bar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(.12,3.8,.12)
	bar.mesh = box
	bar.material_override = material("hazard")
	bar.position = Vector3(0,1.9,0)
	boom_pivot.add_child(bar)
	add_child(boom_pivot)
	block(Vector3(-3.3,.5,47),Vector3(.5,1,.5),"steel",true)
	# Loaded truck waiting for the exit: the box the syndicate meant to move tonight.
	_truck(Vector3(4.2,0,37),"CN 20438")

func _truck(pos: Vector3, placard: String) -> void:
	block(pos+Vector3(0,.95,0),Vector3(2.5,.5,9.2),"steel",true)
	block(pos+Vector3(0,2.2,3.7),Vector3(2.4,2.2,2),"plaster",true,Color("b8412f"))
	block(pos+Vector3(0,2.5,4.72),Vector3(2.1,.9,.04),"glass",false)
	container(pos+Vector3(0,1.2,-1.3),6.06,Color("5f7a6e"),true)
	var label := sign_at(placard,pos+Vector3(0,3,-4.35),16)
	label.rotation.y = PI
	for x in [-1.15,1.15]:
		for z in [-3.2,-1.9,3.4]:
			wheel_positions.append(pos+Vector3(x,.45,z))

func _office() -> void:
	# Portable dispatch office on the east side; the terminal faces the lane at the stage-1 objective.
	block(Vector3(9.3,1.45,-12),Vector3(3.4,2.9,6.6),"plaster",true,Color("d8d2c0"))
	block(Vector3(7.55,1.7,-13.6),Vector3(.04,.9,1.6),"glass",false)
	block(Vector3(7.55,1.7,-10.4),Vector3(.04,.9,1.6),"glass",false)
	block(Vector3(7.55,1.05,-12),Vector3(.04,2.1,.9),"trim",false)
	block(Vector3(9.3,2.98,-12),Vector3(3.8,.16,7),"steel",false)
	block(Vector3(7.62,2.4,-12),Vector3(.15,.6,.7),"trim",false)
	var name_plate := sign_at("堆场调度　／　夜班值班室",Vector3(7.5,2.55,-12),22)
	name_plate.rotation.y = -PI/2
	block(Vector3(6.4,1.1,-12),Vector3(.25,.7,.55),"hazard",true)
	block(Vector3(6.26,1.28,-12),Vector3(.02,.2,.32),"screen",false)
	var terminal_sign := sign_at("调度终端　／　E",Vector3(6.2,1.85,-12),24)
	terminal_sign.rotation.y = -PI/2
	var board := sign_at("装车窗口：22:50\n出口闸：值班放行",Vector3(7.5,1.9,-16.2),18)
	board.rotation.y = -PI/2
	board.modulate = Color("e5c28b")

func _lane_d() -> void:
	# Reefer lane behind a locked chain-link leaf; crosswise boxes seal the rest of the width.
	lane_gate = gate(Vector3(0,1.6,-36),Vector3(4.4,3.2,.25))
	for side in [-1.0,1.0]:
		container(Vector3(side*7.4,0,-36),10,_next_tint(),true,true)
		container(Vector3(side*7.4,2.6,-36),10,_next_tint(),false,true)
	var lane_sign := sign_at("冷藏箱区　／　D 巷",Vector3(0,3.6,-35.7),40)
	lane_sign.modulate = Color("f0d9a8")
	for side in [-1.0,1.0]:
		for z in [-42,-54.5]:
			block(Vector3(side*12.3,1.2,z),Vector3(.3,1.9,.9),"steel",false,Color("c9ccc4"))
			block(Vector3(side*12.12,1.9,z+.25),Vector3(.02,.06,.06),"screen",false,Color("7cff9a"))
	# CN 20437: five thin walls, two hinged doors facing south, a light that comes on when it opens.
	var c := Vector3(0,0,-58)
	block(c+Vector3(0,.06,0),Vector3(2.44,.12,6.06),"crate",true,Color("5a5f66"))
	block(c+Vector3(0,2.57,0),Vector3(2.44,.06,6.06),"crate",false,Color("5a5f66"))
	for x in [-1.19,1.19]:
		block(c+Vector3(x,1.3,0),Vector3(.06,2.6,6.06),"crate",true,Color("5a5f66"))
	block(c+Vector3(0,1.3,-3),Vector3(2.44,2.6,.06),"crate",true,Color("5a5f66"))
	for k in 6:
		var seat := Vector3(-.75+(k%2)*1.5,.45,-2.3+float(int(k/2.0))*1.1)
		block(c+seat,Vector3(.5,.8,.4),"plaster",false,Color("3a3d44"))
		block(c+seat+Vector3(0,.55,0),Vector3(.24,.28,.24),"plaster",false,Color("c8a888"))
	for x in [-.61,.61]:
		var hinge := Node3D.new()
		hinge.position = c+Vector3(signf(x)*1.22,1.3,3.03)
		var door := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.2,2.5,.06)
		door.mesh = box
		door.material_override = material("crate")
		door.position = Vector3(-signf(x)*.6,0,0)
		hinge.add_child(door)
		add_child(hinge)
		door_hinges.append(hinge)
	door_body = solid_box(c+Vector3(0,1.3,3.03),Vector3(2.44,2.6,.08))
	door_body.name = "ContainerDoors"
	sign_at("北湾联运　／　CN 20437",c+Vector3(0,2.05,3.1),18)
	container_light = OmniLight3D.new()
	container_light.position = c+Vector3(0,2.2,.5)
	container_light.omni_range = 7
	container_light.light_energy = 0
	container_light.light_color = Color("ffd2a6")
	container_light.shadow_enabled = false
	add_child(container_light)

func set_container_open(open: bool) -> void:
	## Doors fold back against the box sides (144 degrees); the collision leaf goes with them.
	for hinge in door_hinges:
		hinge.rotation.y = (PI*.8 if hinge.position.x > 0 else -PI*.8) if open else 0.0
	if container_light != null:
		container_light.light_energy = 1.4 if open else 0.0
	if door_body != null:
		door_body.collision_layer = 0 if open else 1
		door_body.collision_mask = door_body.collision_layer

func set_exit_boom_down(down: bool) -> void:
	if boom_pivot != null:
		boom_pivot.rotation.z = -PI/2 if down else 0.0

func _yard_furniture() -> void:
	for point in [Vector3(-6,0,17),Vector3(6,0,-2),Vector3(-6,0,-19),Vector3(5,0,-30),Vector3(-5,0,-44),Vector3(5,0,-53)]:
		block(point+Vector3(0,1.05,0),Vector3(1.1,2.1,.9),"crate",true)
		block(point+Vector3(0,1.02,.46),Vector3(.015,1.8,.035),"steel",false)
		for offset in [Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,1.2),Vector3(0,0,-1.2)]:
			cover_slots.append(point+offset)
	for point in [Vector3(3,0,24),Vector3(-4,0,4),Vector3(-3,0,-23)]:
		block(point+Vector3(0,.4,0),Vector3(2.4,.8,.5),"concrete",true)
		block(point+Vector3(0,.82,0),Vector3(2.4,.04,.5),"hazard",false)
		for offset in [Vector3(0,0,1),Vector3(0,0,-1)]:
			cover_slots.append(point+offset)
	_truck(Vector3(-4.4,0,-4),"空箱")
	for point in [Vector3(-7,0,32),Vector3(7,0,-46)]:
		for k in 3:
			block(point+Vector3(0,.07+k*.15,0),Vector3(1.2,.12,1),"wood",false)
	for offset in [Vector3(1.2,0,0),Vector3(-1.2,0,0)]:
		cover_slots.append(Vector3(-4.4,0,-4)+offset*2.2)
