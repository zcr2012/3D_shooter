extends "res://scripts/game/mission.gd"
## Original single-player story slice. No copyrighted franchise assets or plot.
const FPS = preload("res://scripts/urban/fps_player.gd")
const City = preload("res://scripts/urban/city_map.gd")
const UrbanEnemy = preload("res://scripts/urban/urban_enemy.gd")
const UrbanHUD = preload("res://scripts/urban/urban_hud.gd")
@export var cinematics_enabled: bool = true
@export var persistence_enabled: bool = true
var store
var pause_menu
var escort_waiting := false
var escort_hold := false
const SPAWNS := [Vector3(0,.05,52),Vector3(0,.05,13),Vector3(0,.05,-33),Vector3(0,.05,-55)]
var sound
var cinematic_camera: Camera3D
var cinematic_kind := ""
var cinematic_clock := 0.0
var cinematic_duration := 1.0
var dialogue_queue: Array[String] = []
var dialogue_log: Array[String] = []
var cover_claims: Dictionary = {}
var city
var stage: int = 0
var objective := "控制默瑟街门禁"
var objective_position := Vector3(-2,0,13)
var radio := "指挥中心：行动代号寂静港口，目标是救出证人并保全运输记录。"
var radio_time: float = 0
var rescued: bool = false
var evidence_secured: bool = false
var hostage: Node3D
var supply_uses: Array[bool] = [false,false]
var supply_points: Array[Vector3] = [Vector3(3,0,48),Vector3(3,0,-32)]
var total_eliminated: int = 0
var escort_trail: Array[Vector3] = []
var escort_sample: float = 0.0
var story_beats: Dictionary = {}
var witness_anim: AnimationPlayer
var witness_moving := false
var witness_still := 0.0

func _ready() -> void:
	store = preload("res://scripts/urban/session_store.gd").new()
	store.persistent = persistence_enabled
	store.initialize()
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
	sound = preload("res://scripts/urban/chapter_audio.gd").new()
	sound.mission = self
	add_child(sound)
	cinematic_camera = Camera3D.new()
	cinematic_camera.current = false
	add_child(cinematic_camera)
	hud = UrbanHUD.new()
	hud.mission = self
	add_child(hud)
	apply_preferences()
	pause_menu = preload("res://scripts/urban/session_menu.gd").new()
	pause_menu.mission = self
	add_child(pause_menu)

func _spawn_group(group: int, locations: Array) -> void:
	for location in locations:
		var enemy := UrbanEnemy.new()
		enemy.position = location
		enemy.player = player
		enemy.patrol_width = .7
		enemy.encounter = group
		enemy.city = city
		enemy.squad = self
		enemy.role = "flanker" if locations.find(location) == 1 else "anchor"
		enemy.spotted.connect(_share_contact.bind(enemy))
		enemy.eliminated.connect(_on_eliminated)
		enemy.fired.connect(_enemy_shot)
		add_child(enemy)
		enemy.active = state == "active" and group == stage
		enemies.append(enemy)

func start_mission() -> void:
	if state != "briefing":
		return
	save_checkpoint()
	if cinematics_enabled:
		_begin_cinematic("intro", "intro")
	else:
		_resume_action()
		broadcast("intro")

func _resume_action() -> void:
	state = "active"
	player.cam.make_current()
	player.controls_enabled = true
	player._await_action_release = true
	player._set_look(true)
	_activate_stage()

func _activate_stage() -> void:
	remaining = 0
	for enemy in enemies:
		enemy.active = enemy.encounter == stage and enemy.health > 0
		if enemy.active:
			remaining += 1

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if state == "cinematic" and event.physical_keycode in [KEY_SPACE,KEY_ENTER]:
			finish_cinematic()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_H and state == "active" and rescued:
			escort_hold = not escort_hold
			hud.notice = "陈默原地等候，按 H 恢复跟随。" if escort_hold else "陈默开始跟随。"
			hud.notice_time = 4
			return
		if event.physical_keycode == KEY_C and state in ["briefing","lost"]:
			restore_checkpoint()
			return
		if event.physical_keycode == KEY_F7:
			store.preferences.voice_enabled = not store.preferences.voice_enabled
			apply_preferences()
			store.save_preferences()
			hud.notice = "配音已开启" if sound.voice_enabled else "配音已静音，字幕继续显示"
			hud.notice_time = 3
			return
		if event.physical_keycode == KEY_ENTER:
			if state == "briefing":
				start_mission()
			elif state in ["won","lost"]:
				restart_mission()
		elif event.physical_keycode == KEY_E and state == "active":
			if not try_interact():
				try_resupply()
		elif event.physical_keycode == KEY_F6:
			store.preferences.shadows = not store.preferences.shadows
			apply_preferences()
			store.save_preferences()
			hud.notice = "太阳阴影已开启" if store.preferences.shadows else "太阳阴影已关闭"
			hud.notice_time = 3

func try_resupply() -> bool:
	if get_tree().paused or state != "active":
		return false
	for i in supply_points.size():
		if not supply_uses[i] and player.global_position.distance_to(supply_points[i]) < 2.3:
			supply_uses[i] = true
			player._reserve_ammo += 60
			player.health = mini(player.max_health,player.health + 40)
			hud.notice = "已补给：备弹增加 60 发，生命恢复最多 40 点"
			hud.notice_time = 4
			return true
	return false

func try_interact() -> bool:
	if get_tree().paused or state != "active" or remaining != 0 or stage >= 3:
		return false
	if player.global_position.distance_to(objective_position) > 2.5:
		return false
	if stage == 0:
		city.open_gate(city.checkpoint_gate)
		stage = 1
		objective = "切断仓库报警上行"
		objective_position = Vector3(6,0,-30)
		broadcast("checkpoint")
	elif stage == 1:
		city.open_gate(city.warehouse_gate)
		stage = 2
		objective = "找到并解救调度员陈默"
		objective_position = Vector3(0,0,-58)
		broadcast("relay")
	elif stage == 2:
		rescued = true
		evidence_secured = true
		stage = 3
		objective = "护送陈默返回接应区"
		objective_position = extraction
		dialogue_queue.assign(["reinforcements"])
		escort_trail.append(hostage.global_position)
		_spawn_group(3,[Vector3(-4,.1,-5),Vector3(4,.1,22)])
	sound.effect("terminal", player.cam.global_position, -15)
	_activate_stage()
	if stage == 3:
		play_witness("Plead",.4)
		if cinematics_enabled:
			_begin_cinematic("rescue","rescue")
		else:
			broadcast("rescue")
	save_checkpoint()
	return true

func interaction_hint() -> String:
	if state != "active":
		return ""
	for i in supply_points.size():
		if not supply_uses[i] and player.global_position.distance_to(supply_points[i]) < 2.3:
			return "[ E ] 领取弹药和医疗补给"
	if stage < 3 and player.global_position.distance_to(objective_position) < 2.5:
		if remaining > 0:
			return "先控制本区域　／　剩余威胁 %d" % remaining
		return ["[ E ] 读取门禁记录并开放通道","[ E ] 切断报警上行","[ E ] 确认身份，接应陈默"][stage]
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
		witness_moving = false
		# A small obstacle-inflated grid avoids cutting through cars, walls or corners.
		escort_sample -= delta
		if escort_sample <= 0 and not escort_hold:
			escort_sample = .75
			var path: PackedVector2Array = city.escort_path(hostage.global_position,player.global_position)
			escort_trail.clear()
			escort_waiting = path.is_empty() and hostage.position.distance_to(player.position) > 2
			if path.size() > 1 and Vector2(hostage.position.x,hostage.position.z).distance_to(path[0]) < .4:
				path.remove_at(0)
			for point in path:
				escort_trail.append(Vector3(point.x,.02,point.y))
		if not escort_hold and not escort_trail.is_empty():
			var next: Vector3 = escort_trail.front()
			var travel := next - hostage.global_position
			travel.y = 0
			if travel.length() < .12:
				escort_trail.pop_front()
			elif hostage.global_position.distance_to(player.global_position) > 1.7:
				hostage.position += travel.normalized() * minf(delta*3.1,travel.length())
				hostage.rotation.y = lerp_angle(hostage.rotation.y,atan2(-travel.x,-travel.z),1.0-exp(-12.0*delta))
				witness_moving = true
		witness_still = 0.0 if witness_moving else witness_still + delta
		if witness_still > .6 and hostage.global_position.distance_to(player.global_position) < 6:
			# Standing witness keeps an eye on the officer rather than staring at a wall.
			var look := player.global_position - hostage.global_position
			hostage.rotation.y = lerp_angle(hostage.rotation.y,atan2(-look.x,-look.z),1.0-exp(-3.0*delta))
		play_witness("Jog" if witness_still < .2 else "Idle")

		if evidence_secured and remaining == 0 and player.global_position.distance_to(extraction) < 3 and hostage.global_position.distance_to(extraction) < 4.5:
			_finish("won")

func _on_eliminated(_enemy: Node3D) -> void:
	total_eliminated += 1
	remaining = maxi(0,remaining-1)
	if remaining == 0:
		hud.notice = "区域已控制，前往标记位置完成目标"
		hud.notice_time = 5

func _build_hostage() -> void:
	hostage = preload("res://assets/urban/witness.glb").instantiate()
	hostage.name = "Witness"
	hostage.position = Vector3(0,.02,-58)
	hostage.rotation.y = PI
	add_child(hostage)
	_refine_witness(hostage)
	witness_anim = hostage.find_child("AnimationPlayer",true,false)
	if witness_anim:
		for clip in witness_anim.get_animation_list():
			witness_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	play_witness("Captive")

func play_witness(clip: String, blend: float = .25) -> void:
	# Captive (kneeling, tied), Plead (rescue scene), Idle and Jog (escort) from witness.glb.
	if witness_anim and witness_anim.has_animation(clip) and witness_anim.current_animation != clip:
		witness_anim.play(clip,blend)

func broadcast(id: String) -> void:
	var line: Dictionary = sound.lines[id]
	radio = String(line.speaker) + "：" + String(line.text)
	radio_time = sound.speak(id)
	if radio not in dialogue_log:
		dialogue_log.append(radio)

func _story_radio() -> void:
	if not dialogue_queue.is_empty():
		broadcast(dialogue_queue.pop_front())
		return
	var beat := ""
	if stage == 3 and player.position.z > -25 and player.position.z < 15:
		beat = "evidence"
	elif stage == 3 and player.position.z > 28:
		beat = "evac"
	if not beat.is_empty() and not story_beats.has(beat):
		story_beats[beat] = true
		broadcast(beat)

func _begin_cinematic(kind: String, line: String) -> void:
	state = "cinematic"
	cinematic_kind = kind
	cinematic_clock = 0
	player.stop_combat()
	for enemy in enemies:
		enemy.active = false
	broadcast(line)
	cinematic_duration = radio_time
	cinematic_camera.make_current()
	_update_cinematic(0)

func _process(delta: float) -> void:
	if state != "cinematic":
		return
	cinematic_clock += delta
	radio_time = maxf(0,radio_time-delta)
	_update_cinematic(clampf(cinematic_clock/cinematic_duration,0,1))
	if cinematic_clock >= cinematic_duration:
		finish_cinematic()

func _update_cinematic(progress: float) -> void:
	var t := smoothstep(0,1,progress)
	var start := Vector3(5,3.8,55)
	var end := Vector3(3,2.3,43)
	var target := Vector3(0,1.5,19)
	if cinematic_kind == "rescue":
		start = Vector3(2,1.7,-54)
		end = Vector3(1.3,1.6,-55.3)
		target = hostage.global_position + Vector3.UP*1.3
	elif cinematic_kind == "outro":
		start = Vector3(-5,2.7,49)
		end = Vector3(-3,2.2,50)
		target = hostage.global_position + Vector3.UP
	cinematic_camera.global_position = start.lerp(end,t)
	cinematic_camera.look_at(target)
	cinematic_camera.fov = 58

func finish_cinematic() -> void:
	if state != "cinematic":
		return
	sound.stop_speech()
	radio_time = 0
	Input.action_release("jump")
	if cinematic_kind == "outro":
		state = "won"
		store.clear_checkpoint()
	else:
		_resume_action()

func _finish(result: String) -> void:
	if state != "active":
		return
	super._finish(result)
	if result == "won":
		if cinematics_enabled:
			_begin_cinematic("outro","debrief")
		else:
			broadcast("debrief")
			store.clear_checkpoint()
	else:
		sound.stop_speech()

func _enemy_shot(origin: Vector3, target: Vector3) -> void:
	super._enemy_shot(origin,target)
	sound.gun(origin)

func cover_available(slot: Vector3, enemy: Node) -> bool:
	return not cover_claims.has(slot) or cover_claims[slot] == enemy.get_instance_id()

func _share_contact(where: Vector3, source: Node3D) -> void:
	for enemy in enemies:
		if enemy != source and enemy.active and enemy.position.distance_to(source.position) < 12:
			enemy.receive_alert(where)

func _on_shot(origin: Vector3, target: Vector3, confirmed: bool) -> void:
	super._on_shot(origin,target,confirmed)
	if state == "active":
		for enemy in enemies:
			enemy.hear_noise(origin)

func _refine_witness(node: Node) -> void:
	# Fabric weave normal on the work shirt and trousers; authored colours are kept.
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var source = node.mesh.surface_get_material(i)
			if source is StandardMaterial3D and ("uniform" in source.resource_name.to_lower() or "denim" in source.resource_name.to_lower()):
				var cloth: StandardMaterial3D = source.duplicate()
				cloth.normal_enabled = true
				cloth.normal_texture = preload("res://assets/urban/materials/sleeve_normal.png")
				cloth.normal_scale = .45
				cloth.uv1_triplanar = true
				cloth.uv1_scale = Vector3.ONE*6
				cloth.roughness = .92
				node.set_surface_override_material(i,cloth)
	for child in node.get_children():
		_refine_witness(child)

func apply_preferences() -> void:
	var p: Dictionary = store.preferences
	player.mouse_sensitivity = p.sensitivity
	sound.voice_enabled = p.voice_enabled
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Dialogue"),not p.voice_enabled)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(.0001,p.master)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Dialogue"),linear_to_db(maxf(.0001,p.voice)))
	for child in city.get_children():
		if child is DirectionalLight3D:
			child.shadow_enabled = p.shadows
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if p.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func save_checkpoint() -> bool:
	var data := {"version":1,"stage":stage,"health":player.health,"ammo":player.ammo,"reserve":player.reserve_ammo,
		"elapsed":elapsed,"shots":shots,"hits":hits,"supplies":supply_uses.duplicate(),"log":dialogue_log.duplicate()}
	var saved: bool = store.save_checkpoint(data)
	hud.notice = "检查点已保存" if saved else store.last_error
	hud.notice_time = 4
	return saved

func restore_checkpoint() -> bool:
	if store.checkpoint.is_empty():
		hud.notice = "没有可用检查点，请开始新行动。"
		hud.notice_time = 4
		return false
	var data: Dictionary = store.checkpoint.duplicate(true)
	if not store.valid_checkpoint(data):
		return false
	if pause_menu.is_open:
		pause_menu.close_menu()
	sound.stop_all()
	state = "briefing"
	player.stop_combat()
	player.queue_free()
	for enemy in enemies:
		enemy.active = false
		enemy.collision_layer = 0
		enemy.queue_free()
	enemies.clear()
	cover_claims.clear()
	player = PlayerScene.instantiate()
	player.set_script(FPS)
	stage = int(data.stage)
	player.position = SPAWNS[stage]
	add_child(player)
	player.shot_fired.connect(_on_shot)
	player.damaged.connect(_on_damage)
	player.died.connect(_on_death)
	player.health = maxi(60,int(data.health))
	player._ammo = int(data.ammo)
	player._reserve_ammo = maxi(30,int(data.reserve))
	elapsed = data.elapsed
	shots = int(data.shots)
	hits = int(data.hits)
	supply_uses.assign(data.supplies)
	dialogue_log.assign(data.log)
	story_beats.clear()
	dialogue_queue.clear()
	escort_trail.clear()
	escort_sample = 0
	escort_waiting = false
	escort_hold = false
	radio_time = 0
	total_eliminated = [0,3,6,8][stage]
	rescued = stage == 3
	evidence_secured = rescued
	hostage.position = Vector3(0,.02,-58)
	hostage.rotation = Vector3(0,PI,0)
	witness_moving = false
	witness_still = 0.0
	play_witness("Idle" if rescued else "Captive",0.0)
	city.checkpoint_gate.visible = stage == 0
	city.checkpoint_gate.collision_layer = 1 if stage == 0 else 0
	city.checkpoint_gate.collision_mask = city.checkpoint_gate.collision_layer
	city.warehouse_gate.visible = stage < 2
	city.warehouse_gate.collision_layer = 1 if stage < 2 else 0
	city.warehouse_gate.collision_mask = city.warehouse_gate.collision_layer
	city.rebuild_navigation()
	_spawn_group(0,[Vector3(-5,.1,25),Vector3(4,.1,19),Vector3(-3,.1,15)])
	_spawn_group(1,[Vector3(4,.1,1),Vector3(-4,.1,-13),Vector3(3,.1,-26)])
	_spawn_group(2,[Vector3(-4,.1,-47),Vector3(4,.1,-56)])
	if stage == 3:
		dialogue_queue.assign(["reinforcements"])
		_spawn_group(3,[Vector3(-4,.1,-5),Vector3(4,.1,22)])
	for enemy in enemies:
		if enemy.encounter < stage:
			enemy.health = 0
			enemy.collision_layer = 0
			enemy.visible = false
	objective = ["控制默瑟街门禁","切断仓库报警上行","找到并解救调度员陈默","护送陈默返回接应区"][stage]
	objective_position = [Vector3(-2,0,13),Vector3(6,0,-30),Vector3(0,0,-58),extraction][stage]
	apply_preferences()
	_resume_action()
	hud.hurt_time = 0
	hud.hit_time = 0
	hud.notice = "已恢复检查点，本阶段敌人重新部署。"
	hud.notice_time = 4
	return true

func restart_mission() -> void:
	if state == "lost" and not store.checkpoint.is_empty():
		restore_checkpoint()
	else:
		new_chapter()

func new_chapter() -> void:
	store.clear_checkpoint()
	get_tree().paused = false
	get_tree().reload_current_scene()
