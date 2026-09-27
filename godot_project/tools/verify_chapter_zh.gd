extends SceneTree
var checks: Array[Dictionary] = []
var failures := 0
var mission
func _init() -> void:
	call_deferred("_run")
func check(id: String, condition: bool) -> void:
	checks.append({"id":id,"passed":condition})
	if not condition:
		failures += 1
	print("[%s] %s" % ["PASS" if condition else "FAIL",id])
func frames(count: int = 3) -> void:
	for i in count:
		await physics_frame
		await process_frame
func _run() -> void:
	Engine.max_fps = 120
	create_timer(70).timeout.connect(func():
		push_error("Chinese chapter watchdog expired")
		quit(1))
	mission = load("res://scenes/urban_operation.tscn").instantiate()
	mission.persistence_enabled = false
	root.add_child(mission)
	await frames()
	check("zh.bundled_font",mission.hud._font.resource_path.ends_with("NotoSansCJKsc-Regular.otf"))
	var supported := true
	for character in "寂静港口林舟陈默警务接应运输记录":
		supported = supported and mission.hud._font.has_char(character.unicode_at(0))
	check("zh.cjk_glyphs",supported)
	var sample := "没有空格的中文对白也必须自动换行，不能超出画面或丢失标点。".repeat(5)
	var lines: PackedStringArray = mission.hud.wrap_lines(sample,260,20)
	check("zh.wrap_preserves_text","".join(lines) == sample and lines.size() > 3)
	var fits := true
	for line in lines:
		fits = fits and mission.hud._font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x <= 260.1
	check("zh.wrap_fits_box",fits)
	check("voice.nineteen_dialogues",mission.sound.lines.size() == 19)
	# Every synthesized clip decodes; a line the manifest marks pending has no file and plays as timed text.
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/zh/manifest.json"))
	var pending: Array[String] = []
	for clip in manifest.clips:
		if clip.file == null:
			pending.append(String(clip.id))
	var playable := true
	var decoded := 0
	for id: String in mission.sound.lines:
		var path: String = "res://assets/audio/zh/"+id+".mp3"
		if id in pending:
			playable = playable and not ResourceLoader.exists(path) and mission.sound.speak(id) >= 6.0
			continue
		var stream: AudioStream = load(path)
		playable = playable and stream != null and stream.get_length() > 5
		decoded += 1
	mission.sound.stop_speech()
	check("voice.clips_decode",playable and decoded == 19-pending.size() and decoded >= 18)
	mission.start_mission()
	check("cinematic.intro_started",mission.state == "cinematic" and mission.cinematic_camera.current)
	check("cinematic.controls_blocked",not mission.player.controls_enabled and not mission.enemies[0].active)
	check("cinematic.interaction_blocked",not mission.try_interact() and not mission.try_resupply())
	check("voice.duration_drives_subtitles",mission.sound.voice.stream != null and mission.radio_time >= mission.sound.voice.stream.get_length())
	var position: Vector3 = mission.cinematic_camera.position
	mission._update_cinematic(.5)
	check("cinematic.camera_moves",mission.cinematic_camera.position.distance_to(position) > 1)
	mission.sound.toggle_voice()
	check("voice.mute_retains_subtitles",AudioServer.is_bus_mute(AudioServer.get_bus_index("Dialogue")) and not mission.radio.is_empty())
	mission.sound.toggle_voice()
	mission.sound.effect("terminal",mission.player.position)
	check("voice.effects_do_not_replace_speech",mission.sound.voice.stream != null and mission.sound.voice.stream.resource_path.ends_with("intro.mp3"))
	mission.finish_cinematic()
	check("cinematic.skip_restores_camera",mission.state == "active" and mission.player.cam.current and mission.player.controls_enabled)
	check("story.transcript_retained",mission.dialogue_log.size() == 1 and "林舟" in mission.dialogue_log[0])
	mission.player.set_physics_process(false)
	for actor in mission.enemies:
		actor.set_physics_process(false)
	check("art.cover_slots_present",mission.city.cover_slots.size() == 24)
	var enemy = mission.enemies[0]
	var other = mission.enemies[1]
	mission.player.position = Vector3(-6,.05,30)
	enemy.position = Vector3(-6,.05,17.5)
	enemy.last_seen = mission.player.position
	await frames()
	enemy._choose_cover()
	check("tactics.selects_reachable_cover",enemy.tactical_state == "relocate" and enemy.cover_slot != Vector3.INF and not enemy.move_path.is_empty())
	var slot: Vector3 = enemy.cover_slot
	check("tactics.cover_occludes_threat",slot != Vector3.INF and not enemy._clear_line(slot,enemy.last_seen+Vector3.UP*1.4))
	check("tactics.reserves_cover",not mission.cover_available(slot,other))
	enemy.release_cover()
	check("tactics.releases_cover",mission.cover_available(slot,other))
	# A separate world fixture isolates perception from authored scenery.
	var floor_body := StaticBody3D.new()
	floor_body.position = Vector3(1000,-.1,998)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(30,.2,30)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	mission.add_child(floor_body)
	mission.player.position = Vector3(1000,.1,1000)
	enemy.position = Vector3(1000,.1,996)
	enemy.rotation.y = 0
	await frames()
	check("tactics.rear_outside_view",not enemy.in_view_cone())
	enemy.rotation.y = PI
	check("tactics.front_inside_view",enemy.in_view_cone())
	other.position = Vector3(1000,.1,998)
	await frames()
	check("tactics.no_fire_through_ally",not enemy.clear_fire_lane())
	other.position.x = 1007
	await frames()
	check("tactics.clear_fire_lane",enemy.clear_fire_lane())
	enemy.tactical_state = "patrol"
	enemy.hear_noise(mission.player.position)
	check("tactics.gunshot_investigation",enemy.tactical_state == "investigate" and enemy.search_time > 0)
	other.tactical_state = "patrol"
	mission._share_contact(mission.player.position,enemy)
	check("tactics.nearby_squad_alert",other.tactical_state == "investigate")
	enemy.tactical_state = "engage"
	enemy.rounds = 0
	enemy._react_time = 0
	enemy.set_physics_process(true)
	await frames(3)
	check("tactics.reload_is_timed",enemy.tactical_state == "reload" and enemy.reload_time > 2.5 and enemy.rounds == 0)
	enemy.reload_time = .02
	await frames(3)
	check("tactics.reload_refills",enemy.rounds == 5)
	var wall := StaticBody3D.new()
	wall.position = Vector3(1000,1.5,998)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5,3,.3)
	collision.shape = box
	wall.add_child(collision)
	mission.add_child(wall)
	enemy.last_seen = mission.player.position
	var remembered: Vector3 = enemy.last_seen
	mission.player.position.x += .5
	var health: int = mission.player.health
	await frames(120)
	check("tactics.no_damage_through_wall",mission.player.health == health)
	check("tactics.memory_not_wallhack",enemy.last_seen.is_equal_approx(remembered))
	enemy.set_physics_process(false)
	mission._begin_cinematic("rescue","rescue")
	mission.cinematic_duration = .03
	await frames(5)
	check("cinematic.automatic_return",mission.state == "active" and mission.player.cam.current)
	mission._finish("won")
	check("cinematic.outro_before_results",mission.state == "cinematic" and mission.cinematic_kind == "outro")
	mission.finish_cinematic()
	check("cinematic.outro_ends_won",mission.state == "won" and not mission.player.controls_enabled)
	var path := ProjectSettings.globalize_path("res://../outputs/zh_chapter/verification.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"checks":checks,"failure_count":failures,"status":"PASS" if failures == 0 else "FAIL","engine":Engine.get_version_info()},"\t"))
		file.close()
	else:
		failures += 1
	mission.queue_free()
	await frames(25)
	print("ZH CHAPTER: %d checks, %d failures" % [checks.size(),failures])
	call_deferred("quit",0 if failures == 0 else 1)
