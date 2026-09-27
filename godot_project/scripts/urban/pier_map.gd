extends "res://scripts/urban/city_map.gd"
## Chapter three: berth three of the North Wharf at 23:10 — quay, gantry crane, gangway and the
## moored freighter "Tide". The planning corridor is unchanged (x -10..10, z 63..-62).
const BOX_TINT := [Color("5f7a6e"),Color("8a4b3c"),Color("3f5a78")]
var pier_gate: StaticBody3D
var fence_gate: StaticBody3D
var gangway_basis := Basis.IDENTITY

func _init() -> void:
	sky_top = Color("0a1018")
	sky_horizon = Color("1f2a38")
	ground_horizon = Color("141a22")
	ambient_color = Color("5f7290")
	ambient_energy = .3
	sun_rotation = Vector3(-50,120,0)
	sun_color = Color("8fa7cc")
	sun_energy = .24

func build() -> void:
	block(Vector3(0,-.2,0),Vector3(92,.4,140),"concrete",true)
	block(Vector3(0,-1.6,-104),Vector3(240,.2,80),"glass",false,Color("0f1c26"))
	block(Vector3(0,3,70),Vector3(92,6,.5),"concrete",true)
	for x in [-46,46]:
		block(Vector3(x,3,0),Vector3(.5,6,140),"concrete",true)
	_quay_edge()
	_ship()
	_sheds()
	_berth_gate()
	_crane()
	_gangway_and_terminal()
	_stern()
	_quay_furniture()
	for i in 5:
		lamp_post(Vector3(-9.2,0,45-i*25),-1.0,Color("ffe2b0"),1.4,20)

func _quay_edge() -> void:
	# Fender kerb along the berth, bollards every ten metres, mooring lines up to the hull.
	block(Vector3(11.2,.2,-16),Vector3(1.4,.4,100),"trim",true)
	for k in 9:
		var z := -58.0 + k*10.0
		block(Vector3(9.4,.45,z),Vector3(.55,.9,.55),"steel",true,Color("2a2f33"))
		block(Vector3(9.4,.95,z),Vector3(.7,.12,.7),"steel",false,Color("2a2f33"))
		for offset in [Vector3(-1.1,0,0),Vector3(0,0,1.1),Vector3(0,0,-1.1)]:
			cover_slots.append(Vector3(9.4,0,z)+offset)
		if k%2 == 0:
			var from := Vector3(9.4,.9,z)
			var to := Vector3(12.1,8.4,z+4)
			var basis := Basis.looking_at((to-from).normalized(),Vector3.UP)
			block_rotated((from+to)/2,Vector3(.05,.05,from.distance_to(to)),"steel",basis,Color("6a5a3a"))
	# Water-side railing at the quay head so the corridor ends at the sea, not at a concrete wall.
	block(Vector3(0,.45,-63.5),Vector3(24,.9,.12),"steel",true,Color("3c484b"))
	block(Vector3(0,1.3,-63.5),Vector3(24,.06,.06),"steel",true,Color("3c484b"))
	for x in range(-12,13,3):
		block(Vector3(x,.75,-63.5),Vector3(.08,1.5,.08),"steel",false)
	block(Vector3(-29,3,-64),Vector3(34,6,.3),"concrete",true)
	block(Vector3(-29,3,64),Vector3(34,6,.3),"concrete",true)

func _ship() -> void:
	# Hull, deck, stern superstructure with lit windows, a funnel and deck boxes. All above the quay.
	block(Vector3(24,4.5,-16),Vector3(24,9,100),"steel",true,Color("1b2128"))
	block(Vector3(12.05,8.2,-16),Vector3(.12,.5,100),"paint",false,Color("e8e4d8"))
	block(Vector3(12.05,2.6,-16),Vector3(.12,.35,100),"paint",false,Color("8a3b2f"))
	block(Vector3(24,9.2,-16),Vector3(24,.4,100),"steel",false,Color("3a4046"))
	block(Vector3(24,14,-52),Vector3(16,10,14),"plaster",false,Color("d9d9d4"))
	for y in [11.0,13.2,15.4,17.6]:
		block(Vector3(15.95,y,-52),Vector3(.1,.6,11),"screen",false,Color("ffd894"))
	block(Vector3(28,21,-56),Vector3(3,4,3),"steel",false,Color("8a3b2f"))
	block(Vector3(28,23.2,-56),Vector3(3.4,.4,3.4),"steel",false,Color("1b2128"))
	block(Vector3(24,24,-52),Vector3(.2,10,.2),"steel",false)
	for k in 6:
		block(Vector3(20+(k%2)*4,10.7,-30+int(k/2.0)*13),Vector3(2.44,2.6,12.2),"crate",false,BOX_TINT[k%3])
	for z in [-40,-10,20]:
		block(Vector3(12.4,9.9,z),Vector3(.5,.06,.9),"lamp",false)
	var name_plate := sign_at("潮汐号　／　TIDE",Vector3(11.9,6.4,-8),56)
	name_plate.rotation.y = -PI/2
	name_plate.modulate = Color("e8e4d8")
	var berth_sign := sign_at("三号泊位　／　00:00 离港",Vector3(11.9,3.6,26),34)
	berth_sign.rotation.y = -PI/2
	berth_sign.modulate = Color("f0d9a8")

func _sheds() -> void:
	# Transit sheds close the land side of the quay; the offset keeps their doors 12 m from the centreline.
	for z in [-50,-24,2,28,54]:
		building(Vector3(-24,0,z),Vector3(24,9,26))
		block(Vector3(-11.88,2.2,z-8),Vector3(.1,4.4,1.6),"steel",false,Color("5a6166"))
		block(Vector3(-11.88,2.2,z+8),Vector3(.1,4.4,1.6),"steel",false,Color("5a6166"))
	var shed_sign := sign_at("北码头　中转仓库",Vector3(-11.8,6.5,28),40)
	shed_sign.rotation.y = PI/2

func _berth_gate() -> void:
	pier_gate = gate(Vector3(0,1.5,16),Vector3(24,3,.25))
	block(Vector3(-5,1.4,18.6),Vector3(2.2,2.8,2.2),"plaster",true,Color("d8d2c0"))
	block(Vector3(-5,1.7,17.48),Vector3(1.5,.8,.04),"glass",false)
	block(Vector3(-5,2.9,18.6),Vector3(2.6,.16,2.6),"steel",false)
	block(Vector3(-2.6,1.1,18),Vector3(.25,.7,.55),"hazard",true)
	block(Vector3(-2.46,1.28,18),Vector3(.02,.2,.32),"screen",false)
	var terminal_sign := sign_at("泊位闸门　／　E",Vector3(-2.4,1.85,18),24)
	terminal_sign.rotation.y = PI/2
	var banner := sign_at("三号泊位　／　港务局管制区",Vector3(0,3.9,15.6),40)
	banner.modulate = Color("f0d9a8")
	var notice := sign_at("停电应急预案　沈国栋 签发\n泊位夜间封闭　05:06",Vector3(-5,1.9,19.75),16)
	notice.modulate = Color("e5c28b")

func _crane() -> void:
	# Ship-to-shore gantry: four legs the player and AI use as cover, portal beam and boom over the ship.
	for x in [-8.3,8.3]:
		for z in [-8.0,-20.0]:
			block(Vector3(x,11,z),Vector3(1.6,22,1.6),"steel",true,Color("c9443a"))
			block(Vector3(x,.2,z),Vector3(2.2,.4,2.2),"concrete",true)
			for offset in [Vector3(-1.6,0,0),Vector3(1.6,0,0),Vector3(0,0,1.6),Vector3(0,0,-1.6)]:
				cover_slots.append(Vector3(x,0,z)+offset)
	block(Vector3(0,22.4,-14),Vector3(20,1.4,14),"steel",false,Color("c9443a"))
	block(Vector3(20,23.5,-14),Vector3(44,1,3),"steel",false,Color("c9443a"))
	block(Vector3(6,20.4,-14),Vector3(2.6,2.6,2.6),"steel",false,Color("8a8f94"))
	block(Vector3(0,12,-14),Vector3(.12,.12,.12),"lamp",false)
	block(Vector3(6,.02,-14),Vector3(3,.025,3),"extraction",false)
	block(Vector3(7.7,.9,-14),Vector3(.3,1.8,.3),"steel",true)
	block(Vector3(7.7,1.9,-14),Vector3(.5,.25,.5),"screen",false,Color("f0a04a"))
	var marker := sign_at("岸吊作业区　／　接应点",Vector3(7.55,2.4,-14),20)
	marker.rotation.y = -PI/2
	var light := OmniLight3D.new()
	light.position = Vector3(0,12,-14)
	light.omni_range = 30
	light.light_energy = 1.2
	light.light_color = Color("ffd9a0")
	light.shadow_enabled = false
	add_child(light)
	# Security fence at the head of the crane zone; the leaf opens once the area is called clear.
	fence_gate = gate(Vector3(-2,1.5,-36),Vector3(4.4,3,.2))
	block(Vector3(-8.2,1.5,-36),Vector3(8,3,.15),"steel",true)
	block(Vector3(6.2,1.5,-36),Vector3(12,3,.15),"steel",true)
	for x in range(-12,13,2):
		block(Vector3(x,1.5,-36),Vector3(.1,3.1,.1),"steel",false)
	var fence_sign := sign_at("舷梯区　／　仅限船务人员",Vector3(-2,3.4,-35.7),34)
	fence_sign.modulate = Color("f0d9a8")

func _gangway_and_terminal() -> void:
	# Gangway from the quay to the deck edge, port terminal at its foot.
	# The gangway ends at a closed hatch 1.4 m below the deck edge: a lookout, not a way onto the ship.
	var foot := Vector3(7,0,-34)
	var head := Vector3(11.6,7.6,-46)
	var direction := (head-foot).normalized()
	gangway_basis = Basis.looking_at(direction,Vector3.UP)
	var length := foot.distance_to(head)
	var centre := (foot+head)/2 + Vector3(0,.05,0)
	block_rotated(centre,Vector3(1.3,.1,length),"steel",gangway_basis,Color("5a6166"))
	for side in [-1.0,1.0]:
		block_rotated(centre+gangway_basis.x*side*.62+gangway_basis.y*.55,Vector3(.05,1.1,length),"steel",gangway_basis,Color("8a8f94"))
		block_rotated(centre+gangway_basis.x*side*.62+gangway_basis.y*1.05,Vector3(.06,.06,length),"steel",gangway_basis,Color("8a8f94"))
	solid_box(centre,Vector3(1.3,.1,length),gangway_basis)
	solid_box(centre+gangway_basis.x*.62+gangway_basis.y*.55,Vector3(.05,1.1,length),gangway_basis)
	solid_box(centre-gangway_basis.x*.62+gangway_basis.y*.55,Vector3(.05,1.1,length),gangway_basis)
	block(Vector3(9.5,1.9,-40.5),Vector3(.25,3.8,.25),"steel",true)
	block(Vector3(12.0,7.9,-46.6),Vector3(.12,2.4,1.6),"steel",false,Color("4a5058"))
	var hatch := sign_at("舷梯口　／　已封闭",Vector3(11.9,8.9,-46.6),18)
	hatch.rotation.y = -PI/2
	block(Vector3(7.5,1.1,-40),Vector3(.25,.7,.55),"hazard",true)
	block(Vector3(7.36,1.28,-40),Vector3(.02,.2,.32),"screen",false)
	var terminal_sign := sign_at("港务终端　／　离港许可",Vector3(7.3,1.85,-40),22)
	terminal_sign.rotation.y = -PI/2
	var schedule := sign_at("潮汐号　离港 00:00\n引航员：已确认",Vector3(7.3,2.35,-38.6),14)
	schedule.rotation.y = -PI/2
	schedule.modulate = Color("e5c28b")
	var ramp_light := OmniLight3D.new()
	ramp_light.position = Vector3(8,3.5,-38)
	ramp_light.omni_range = 12
	ramp_light.light_energy = 1.1
	ramp_light.light_color = Color("ffd9a0")
	ramp_light.shadow_enabled = false
	add_child(ramp_light)

func _stern() -> void:
	# Stern plank: a low steel platform against the hull where the chapter ends.
	block(Vector3(8.6,.4,-60),Vector3(3.2,.8,3.2),"steel",true,Color("3a4046"))
	block(Vector3(8.6,.84,-60),Vector3(3.2,.06,3.2),"hazard",false)
	block(Vector3(6.9,.6,-60),Vector3(.6,.12,1.2),"steel",false)
	block(Vector3(6.6,.3,-60),Vector3(.6,.12,1.2),"steel",false)
	block(Vector3(8.6,1.6,-61.4),Vector3(3.2,.06,.06),"steel",false)
	var plate := sign_at("船尾　／　跳板",Vector3(6.4,1.9,-60),22)
	plate.rotation.y = -PI/2
	plate.modulate = Color("f0d9a8")
	var stern_light := OmniLight3D.new()
	stern_light.position = Vector3(6,4,-58)
	stern_light.omni_range = 12
	stern_light.light_energy = 1.0
	stern_light.light_color = Color("ffd9a0")
	stern_light.shadow_enabled = false
	add_child(stern_light)

func _quay_furniture() -> void:
	for point in [Vector3(-6,0,22),Vector3(5,0,4),Vector3(-6,0,-26),Vector3(5,0,-44),Vector3(-5,0,-56)]:
		block(point+Vector3(0,1.05,0),Vector3(1.1,2.1,.9),"crate",true)
		block(point+Vector3(0,1.02,.46),Vector3(.015,1.8,.035),"steel",false)
		for offset in [Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,1.2),Vector3(0,0,-1.2)]:
			cover_slots.append(point+offset)
	for point in [Vector3(3,0,30),Vector3(-4,0,-4),Vector3(-3,0,-49)]:
		block(point+Vector3(0,.4,0),Vector3(2.4,.8,.5),"concrete",true)
		block(point+Vector3(0,.82,0),Vector3(2.4,.04,.5),"hazard",false)
		for offset in [Vector3(0,0,1),Vector3(0,0,-1)]:
			cover_slots.append(point+offset)
	vehicle(Vector3(-4,0,38))
	vehicle(Vector3(4,0,-27))
	for offset in [Vector3(2.2,0,0),Vector3(-2.2,0,0)]:
		cover_slots.append(Vector3(-4,0,38)+offset)
		cover_slots.append(Vector3(4,0,-27)+offset)
	for point in [Vector3(-7,0,10),Vector3(7,0,-52)]:
		for k in 3:
			block(point+Vector3(0,.07+k*.15,0),Vector3(1.2,.12,1),"wood",false)
