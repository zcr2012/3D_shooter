extends "res://scripts/game/mission.gd"
## Original single-player story slice. No copyrighted franchise assets or plot.
const FPS = preload("res://scripts/urban/fps_player.gd")
const City = preload("res://scripts/urban/city_map.gd")
const UrbanEnemy = preload("res://scripts/urban/urban_enemy.gd")
const UrbanHUD = preload("res://scripts/urban/urban_hud.gd")
var city
var stage: int = 0
var objective := "SECURE MERCER CHECKPOINT"
var objective_position := Vector3(-2,0,13)
var radio := "CONTROL: A dock worker has evidence linking the blackout to a private militia. Bring him home."
var radio_time: float = 0
var rescued: bool = false
var hostage: Node3D
var supply_uses: Array[bool] = [false,false]
var supply_points: Array[Vector3] = [Vector3(3,0,48),Vector3(3,0,-32)]
var total_eliminated: int = 0
var escort_trail: Array[Vector3] = []
var escort_sample: float = 0.0
var story_beats: Dictionary = {}

func _ready() -> void:
	city = City.new()
	add_child(city)
	player = PlayerScene.instantiate()
	player.set_script(FPS)
	player.position = Vector3(0,.12,52)
	add_child(player)
	player.shot_fired.connect(_on_shot)
	player.damaged.connect(_on_damage)
	player.died.connect(_on_death)
	player.stop_combat()
	extraction = Vector3(0,0,52)
	_spawn_group(0,[Vector3(-5,.1,25),Vector3(4,.1,19),Vector3(-3,.1,15)])
	_spawn_group(1,[Vector3(4,.1,1),Vector3(-4,.1,-13),Vector3(3,.1,-26)])
	_spawn_group(2,[Vector3(-4,.1,-47),Vector3(4,.1,-56)])
	remaining = 3
	_build_hostage()
	hud = UrbanHUD.new()
	hud.mission = self
	add_child(hud)

func _spawn_group(group: int, locations: Array) -> void:
	for location in locations:
		var enemy := UrbanEnemy.new()
		enemy.position = location
		enemy.player = player
		enemy.patrol_width = .7
		enemy.encounter = group
		enemy.eliminated.connect(_on_eliminated)
		enemy.fired.connect(_enemy_shot)
		add_child(enemy)
		enemy.active = state == "active" and group == stage
		enemies.append(enemy)

func start_mission() -> void:
	if state != "briefing":
		return
	state = "active"
	player.controls_enabled = true
	player._await_action_release = true
	player._set_look(true)
	_activate_stage()
	radio_time = 12

func _activate_stage() -> void:
	remaining = 0
	for enemy in enemies:
		enemy.active = enemy.encounter == stage and enemy.health > 0
		if enemy.active:
			remaining += 1

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ENTER:
			if state == "briefing":
				start_mission()
			elif state in ["won","lost"]:
				restart_mission()
		elif event.physical_keycode == KEY_E and state == "active":
			if not try_interact():
				try_resupply()
		elif event.physical_keycode == KEY_F6:
			# Low preset: no dynamic sun shadows. Safe to toggle at any time.
			for child in city.get_children():
				if child is DirectionalLight3D:
					child.shadow_enabled = not child.shadow_enabled
			hud.notice = "SUN SHADOWS TOGGLED  /  LOW-END PRESET"
			hud.notice_time = 3

func try_resupply() -> bool:
	if state != "active":
		return false
	for i in supply_points.size():
		if not supply_uses[i] and player.global_position.distance_to(supply_points[i]) < 2.3:
			supply_uses[i] = true
			player._reserve_ammo += 60
			player.health = mini(player.max_health,player.health + 40)
			hud.notice = "SUPPLIES  /  +60 RESERVE  /  +40 HEALTH"
			hud.notice_time = 4
			return true
	return false

func try_interact() -> bool:
	if state != "active" or remaining != 0 or stage >= 3:
		return false
	if player.global_position.distance_to(objective_position) > 2.5:
		return false
	if stage == 0:
		city.open_gate(city.checkpoint_gate)
		stage = 1
		objective = "DISABLE THE WAREHOUSE RELAY"
		objective_position = Vector3(6,0,-30)
		radio = "CONTROL: The checkpoint terminal links to Dock Nine. Disable the relay before entering; the worker is still inside."
	elif stage == 1:
		city.open_gate(city.warehouse_gate)
		stage = 2
		objective = "LOCATE AND RELEASE THE WITNESS"
		objective_position = Vector3(0,0,-58)
		radio = "CONTROL: Relay offline. Loading door released. Two guards remain inside. Keep your fire away from the witness."
	elif stage == 2:
		rescued = true
		stage = 3
		objective = "ESCORT THE WITNESS TO EVAC"
		objective_position = extraction
		radio = "WITNESS: The outage was a cover. I copied the shipping records. / CONTROL: Two contacts are moving onto Mercer. Return to the van."
		escort_trail.append(hostage.global_position)
		_spawn_group(3,[Vector3(-4,.1,-5),Vector3(4,.1,22)])
	radio_time = 12
	_activate_stage()
	return true

func interaction_hint() -> String:
	if state != "active":
		return ""
	for i in supply_points.size():
		if not supply_uses[i] and player.global_position.distance_to(supply_points[i]) < 2.3:
			return "[ E ]  TAKE AMMUNITION AND MEDICAL SUPPLIES"
	if stage < 3 and player.global_position.distance_to(objective_position) < 2.5:
		if remaining > 0:
			return "SECURE THIS AREA FIRST  /  %d CONTACTS" % remaining
		return ["[ E ]  OPEN CHECKPOINT","[ E ]  DISABLE RELAY","[ E ]  RELEASE WITNESS"][stage]
	return ""

func _physics_process(delta: float) -> void:
	if state != "active":
		return
	elapsed += delta
	radio_time = maxf(0,radio_time-delta)
	if radio_time <= 0:
		_story_radio()
	if player.position.y < -5:
		_finish("lost")
	if rescued:
		hostage.find_child("LegLeft",true,false).rotation.x = 0
		hostage.find_child("LegRight",true,false).rotation.x = 0
		# A small obstacle-inflated grid avoids cutting through cars, walls or corners.
		escort_sample -= delta
		if escort_sample <= 0:
			escort_sample = .75
			var path: PackedVector2Array = city.escort_path(hostage.global_position,player.global_position)
			escort_trail.clear()
			for point in path:
				escort_trail.append(Vector3(point.x,.02,point.y))
		if not escort_trail.is_empty():
			var next: Vector3 = escort_trail.front()
			var travel := next - hostage.global_position
			travel.y = 0
			if travel.length() < .12:
				escort_trail.pop_front()
			elif hostage.global_position.distance_to(player.global_position) > 1.7:
				hostage.position += travel.normalized() * minf(delta*3.1,travel.length())
				hostage.rotation.y = atan2(-travel.x,-travel.z)
				var swing := sin(elapsed*8)*.22
				hostage.find_child("LegLeft",true,false).rotation.x = swing
				hostage.find_child("LegRight",true,false).rotation.x = -swing

		if remaining == 0 and player.global_position.distance_to(extraction) < 3 and hostage.global_position.distance_to(extraction) < 4.5:
			_finish("won")

func _on_eliminated(_enemy: Node3D) -> void:
	total_eliminated += 1
	remaining = maxi(0,remaining-1)
	if remaining == 0:
		hud.notice = "AREA SECURE  /  PROCEED TO YOUR OBJECTIVE"
		hud.notice_time = 5

func _build_hostage() -> void:
	hostage = preload("res://assets/urban/witness.glb").instantiate()
	hostage.name = "Witness"
	hostage.position = Vector3(0,.02,-58)
	add_child(hostage)

func _story_radio() -> void:
	var beat := ""
	var line := ""
	if stage == 0 and player.position.z < 38:
		beat = "cordon"
		line = "CONTROL: Mercer went dark at 05:12. These roadblocks were already in place when patrol arrived. Someone planned the outage."
	elif stage == 1 and player.position.z < -8:
		beat = "contractors"
		line = "CONTROL: Those uniforms belong to a dock security contractor. Their dispatch stopped answering an hour before the blackout."
	elif stage == 2 and player.position.z < -39:
		beat = "generator"
		line = "OPERATOR: The warehouse still has power. / CONTROL: Then the blackout was selective. Find the worker before they move him."
	elif stage == 3 and player.position.z > -25 and player.position.z < 15:
		beat = "manifest"
		line = "WITNESS: The manifests listed empty containers. I heard people inside. I copied everything before they took my radio."
	elif stage == 3 and player.position.z > 28:
		beat = "evac"
		line = "CONTROL: Evac is holding at your insertion point. Keep the witness with you. Those records are our way into the next shipment."
	if not beat.is_empty() and not story_beats.has(beat):
		story_beats[beat] = true
		radio = line
		radio_time = 11
