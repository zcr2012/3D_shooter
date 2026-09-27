extends "res://scripts/game/mission.gd"
## Campaign chapter base: player, procedural city, enemy groups, radio dialogue, cinematics,
## supplies and checkpoints. Each chapter script fills the stage tables and a few hooks.
## Original single-player story. No copyrighted franchise assets or plot.
const FPS = preload("res://scripts/urban/fps_player.gd")
const City = preload("res://scripts/urban/city_map.gd")
const UrbanEnemy = preload("res://scripts/urban/urban_enemy.gd")
const UrbanHUD = preload("res://scripts/urban/urban_hud.gd")
const Campaign = preload("res://scripts/urban/campaign.gd")
@export var cinematics_enabled: bool = true
@export var persistence_enabled: bool = true
var store
var pause_menu
var sound
var city
var cinematic_camera: Camera3D
var cinematic_kind := ""
var cinematic_clock := 0.0
var cinematic_duration := 1.0
var dialogue_queue: Array[String] = []
var dialogue_log: Array[String] = []
var cover_claims: Dictionary = {}
var stage: int = 0
var objective := ""
var objective_position := Vector3.ZERO
var radio := ""
var radio_time: float = 0
var supply_uses: Array[bool] = [false,false]
var supply_points: Array[Vector3] = []
var total_eliminated: int = 0
var story_beats: Dictionary = {}
# Escort state lives here so the shared HUD can read it in every chapter; only chapter one uses it.
var rescued: bool = false
var evidence_secured: bool = false
var hostage: Node3D
var escort_waiting := false
var escort_hold := false

# ---- Chapter definition (filled in by subclasses in _init) ----
var chapter_index := 1
var chapter_name := "默瑟街"
var chapter_time := "清晨五时四十分"
var spawns: Array[Vector3] = []
var objectives: Array[String] = []
var objective_points: Array[Vector3] = []
var hints: Array[String] = []
## Dialogue id broadcast after completing stage i ("" for none, or when the hook starts a cinematic).
var stage_lines: Array[String] = []
var eliminated_at_stage: Array[int] = []
var intro_line := "intro"
var outro_line := "debrief"
var opening_radio := ""
## The last stage ends by interacting with its objective (chapters two and three).
var final_interaction_wins := true
var briefing_title := ""
var briefing_subtitle := ""
var briefing_lines: Array[String] = []
var won_title := ""
var won_subtitle := ""
var lost_subtitle := ""
var next_prompt := ""
var epilogue: Array[String] = []

func _ready() -> void:
	store = preload("res://scripts/urban/session_store.gd").new()
	store.persistent = persistence_enabled
	store.initialize()
	city = _build_city()
	add_child(city)
	player = PlayerScene.instantiate()
	player.set_script(FPS)
	player.position = spawns[0] + Vector3(0,.07,0)
	add_child(player)
	_connect_player()
	player.stop_combat()
	effects = HitEffects.new()
	add_child(effects)
	radio = opening_radio
	objective = objectives[0]
	objective_position = objective_points[0]
	for group in _last_stage():
		_spawn_group(group,_group_positions(group))
	remaining = _group_positions(0).size()
	_build_chapter()
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
	if Campaign.pending_restore:
		Campaign.pending_restore = false
		if int(store.checkpoint.get("chapter",1)) == chapter_index:
			call_deferred("restore_checkpoint")

# ---- Hooks ----
func _build_city() -> Node3D:
	return City.new()

func _build_chapter() -> void:
	pass

func _group_positions(_group: int) -> Array:
	return []

func _stage_completed(_previous: int) -> void:
	pass

func _restore_world() -> void:
	pass

func _chapter_tick(_delta: float) -> void:
	pass

func _check_completion() -> bool:
	return false

func _story_beat() -> String:
	return ""

func _chapter_key(_event: InputEventKey) -> bool:
	return false

func _cinematic_frame(kind: String) -> Array:
	## [start, end, look target] for the moving cinematic camera.
	match kind:
		"outro":
			return [player.global_position+Vector3(-3,2.6,3),player.global_position+Vector3(-2,2.1,2),player.global_position+Vector3.UP]
	return [player.global_position+Vector3(4,3.5,3),player.global_position+Vector3(2,2.3,-6),objective_position+Vector3.UP*1.5]

# ---- Shared flow ----
func _last_stage() -> int:
	return objectives.size()-1

func _connect_player() -> void:
	player.shot_fired.connect(_on_shot)
	player.bullet_impact.connect(_on_impact)
	player.damaged.connect(_on_damage)
	player.died.connect(_on_death)

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
		_begin_cinematic("intro", intro_line)
	else:
		_resume_action()
		broadcast(intro_line)

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
		if _chapter_key(event):
			return
		if event.physical_keycode == KEY_C and state in ["briefing","lost"]:
			continue_checkpoint()
			return
		if event.physical_keycode in [KEY_1,KEY_2,KEY_3] and state == "briefing":
			var wanted: int = event.physical_keycode-KEY_1+1
			if wanted != chapter_index and wanted <= int(store.progress.unlocked):
				Campaign.open_chapter(get_tree(),wanted)
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
			elif state == "won":
				next_chapter()
			elif state == "lost":
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

func continue_checkpoint() -> bool:
	if store.checkpoint.is_empty():
		hud.notice = "没有可用检查点，请开始新行动。"
		hud.notice_time = 4
		return false
	var saved_chapter := int(store.checkpoint.get("chapter",1))
	if saved_chapter != chapter_index:
		Campaign.open_chapter(get_tree(),saved_chapter,true)
		return true
	return restore_checkpoint()

func next_chapter() -> void:
	## Results screen: the next chapter, or back to the first briefing after the finale.
	Campaign.open_chapter(get_tree(),chapter_index+1 if chapter_index < Campaign.SCENES.size() else 1)

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
	if get_tree().paused or state != "active" or remaining != 0:
		return false
	if stage >= _last_stage() and not final_interaction_wins:
		return false
	if player.global_position.distance_to(objective_position) > 2.5:
		return false
	sound.effect("terminal", player.cam.global_position, -15)
	if stage >= _last_stage():
		_finish("won")
		return true
	var previous := stage
	stage += 1
	objective = objectives[stage]
	objective_position = objective_points[stage]
	if stage == _last_stage():
		_spawn_group(stage,_group_positions(stage))
	_stage_completed(previous)
	# A hook may have started a cinematic; _resume_action() activates the stage afterwards.
	if state == "active":
		_activate_stage()
		if not stage_lines[previous].is_empty():
			broadcast(stage_lines[previous])
	save_checkpoint()
	return true

func interaction_hint() -> String:
	if state != "active":
		return ""
	for i in supply_points.size():
		if not supply_uses[i] and player.global_position.distance_to(supply_points[i]) < 2.3:
			return "[ E ] 领取弹药和医疗补给"
	if (stage < _last_stage() or final_interaction_wins) and player.global_position.distance_to(objective_position) < 2.5:
		if remaining > 0:
			return "先控制本区域　／　剩余威胁 %d" % remaining
		return hints[stage]
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
		return
	_chapter_tick(delta)
	if state == "active" and _check_completion():
		_finish("won")

func _on_eliminated(_enemy: Node3D) -> void:
	total_eliminated += 1
	remaining = maxi(0,remaining-1)
	if remaining == 0:
		hud.notice = "区域已控制，前往标记位置完成目标"
		hud.notice_time = 5

func has_line(id: String) -> bool:
	return is_instance_valid(sound) and sound.lines.has(id)

func broadcast(id: String) -> void:
	if not has_line(id):
		return
	var line: Dictionary = sound.lines[id]
	radio = String(line.speaker) + "：" + String(line.text)
	radio_time = sound.speak(id)
	if radio not in dialogue_log:
		dialogue_log.append(radio)

func _story_radio() -> void:
	if not dialogue_queue.is_empty():
		broadcast(dialogue_queue.pop_front())
		return
	var beat := _story_beat()
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
	cinematic_duration = maxf(radio_time,4.0)
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
	var frame := _cinematic_frame(cinematic_kind)
	var start: Vector3 = frame[0]
	var end: Vector3 = frame[1]
	var target: Vector3 = frame[2]
	cinematic_camera.global_position = start.lerp(end,t)
	if cinematic_camera.global_position.distance_to(target) > .05:
		cinematic_camera.look_at(target)
	cinematic_camera.fov = 58

func finish_cinematic() -> void:
	if state != "cinematic":
		return
	sound.stop_speech()
	radio_time = 0
	Input.action_release("jump")
	if cinematic_kind == "outro":
		_complete_chapter()
	else:
		_resume_action()

func _complete_chapter() -> void:
	state = "won"
	store.clear_checkpoint()
	store.unlock_chapter(chapter_index+1)
	if chapter_index >= Campaign.SCENES.size():
		store.mark_completed()

func _finish(result: String) -> void:
	if state != "active":
		return
	super._finish(result)
	if result == "won":
		if cinematics_enabled:
			_begin_cinematic("outro",outro_line)
		else:
			broadcast(outro_line)
			_complete_chapter()
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

func _on_impact(where: Vector3, normal: Vector3, direction: Vector3, kind: String, headshot: bool) -> void:
	super._on_impact(where,normal,direction,kind,headshot)
	if state != "active" or not is_instance_valid(sound):
		return
	# Surface and body impacts play at the point of impact; confirm ticks play at the ear.
	var ear: Vector3 = player.cam.global_position
	match kind:
		"world":
			sound.effect("bullet_impact",where,-9)
		"hit":
			sound.effect("flesh_impact",where,-6)
			sound.effect("headshot" if headshot else "hit_confirm",ear,-13 if headshot else -17)
		"kill":
			sound.effect("flesh_impact",where,-6)
			sound.effect("kill_confirm",ear,-11)

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
	var data := {"version":1,"chapter":chapter_index,"stage":stage,"health":player.health,"ammo":player.ammo,"reserve":player.reserve_ammo,
		"elapsed":elapsed,"shots":shots,"hits":hits,"headshots":headshots,"supplies":supply_uses.duplicate(),"log":dialogue_log.duplicate()}
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
	if not store.valid_checkpoint(data) or int(data.get("chapter",1)) != chapter_index:
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
	player.position = spawns[stage]
	add_child(player)
	_connect_player()
	player.health = maxi(60,int(data.health))
	player._ammo = int(data.ammo)
	player._reserve_ammo = maxi(30,int(data.reserve))
	elapsed = data.elapsed
	shots = int(data.shots)
	hits = int(data.hits)
	# Older checkpoints predate the headshot counter; treat a missing key as zero.
	headshots = int(data.get("headshots",0))
	effects.clear()
	supply_uses.assign(data.supplies)
	dialogue_log.assign(data.log)
	story_beats.clear()
	dialogue_queue.clear()
	radio_time = 0
	total_eliminated = eliminated_at_stage[stage]
	_restore_world()
	city.rebuild_navigation()
	for group in _last_stage():
		_spawn_group(group,_group_positions(group))
	if stage == _last_stage():
		_spawn_group(stage,_group_positions(stage))
	for enemy in enemies:
		if enemy.encounter < stage:
			enemy.health = 0
			enemy.collision_layer = 0
			enemy.visible = false
	objective = objectives[stage]
	objective_position = objective_points[stage]
	apply_preferences()
	_resume_action()
	hud.hurt_time = 0
	hud.hit_time = 0
	hud.clear_feedback()
	hud.notice = "已恢复检查点，本阶段敌人重新部署。"
	hud.notice_time = 4
	return true

func restart_mission() -> void:
	if state == "lost" and not store.checkpoint.is_empty() and int(store.checkpoint.get("chapter",1)) == chapter_index:
		restore_checkpoint()
	else:
		new_chapter()

func new_chapter() -> void:
	store.clear_checkpoint()
	get_tree().paused = false
	get_tree().reload_current_scene()
