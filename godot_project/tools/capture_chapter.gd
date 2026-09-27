extends SceneTree
## Real-renderer stills for review (run with a display, e.g. Xvfb + Mesa, Compatibility renderer).
## These are scripted camera placements, not a recorded human play-through.
var mission
var directory := ""
var captured: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func settle(count: int = 10) -> void:
	for i in count:
		await process_frame

func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(directory+"/"+label+".png")
	# Small JPEG preview so reviewers without artifact access can still inspect the frame.
	var preview := image.duplicate() as Image
	preview.resize(960,540,Image.INTERPOLATE_LANCZOS)
	preview.save_jpg(directory+"/"+label+".jpg",.74)
	captured.append(label)
	print("captured ", label)

func place_player(at: Vector3, yaw: float, pitch: float = 0.0) -> void:
	var p = mission.player
	p.global_position = at
	p.velocity = Vector3.ZERO
	p._yaw = yaw
	p._pitch = pitch
	p.rotation.y = yaw
	p.arm.rotation.x = pitch

func freeze_enemies() -> void:
	for enemy in mission.enemies:
		enemy.set_physics_process(false)

func restore(stage: int) -> void:
	mission.store.save_checkpoint({"version":1,"stage":stage,"health":88,"ammo":24,"reserve":90,"elapsed":140.0+stage*95,"shots":20,"hits":13,"supplies":[stage >= 1,false],"log":[]})
	mission.restore_checkpoint()
	await settle(3)
	freeze_enemies()
	mission.hud.notice_time = 0
	mission.radio_time = 0

func closeup(from: Vector3, target: Vector3, fov: float = 42.0) -> void:
	mission.hud.visible = false
	mission.player.view.visible = false
	var camera: Camera3D = mission.cinematic_camera
	camera.global_position = from
	camera.look_at(target)
	camera.fov = fov
	camera.make_current()

func end_closeup() -> void:
	mission.hud.visible = true
	mission.player.cam.make_current()

func _run() -> void:
	root.size = Vector2i(1280,720)
	directory = ProjectSettings.globalize_path("res://../outputs/release/screenshots")
	DirAccess.make_dir_recursive_absolute(directory)
	mission = load("res://scenes/urban_operation.tscn").instantiate()
	mission.persistence_enabled = false
	root.add_child(mission)
	await capture("01_briefing")
	mission.start_mission()
	freeze_enemies()
	mission.cinematic_clock = mission.cinematic_duration*.45
	mission._update_cinematic(.45)
	await capture("02_intro_cinematic")
	mission.finish_cinematic()
	freeze_enemies()
	mission.hud.notice_time = 0
	mission.radio_time = 0
	place_player(Vector3(0,.05,50),0.0)
	await capture("03_street_start")
	place_player(Vector3(1.2,.05,31),0.08,-.03)
	await capture("04_checkpoint_contact")
	var enemy = mission.enemies[1]
	closeup(enemy.global_position+Vector3(1.6,1.55,2.6),enemy.global_position+Vector3(0,1.15,0))
	await capture("05_enemy_closeup")
	end_closeup()
	await restore(1)
	place_player(Vector3(-1,.05,-22),-.12,.12)
	await capture("06_warehouse_approach")
	await restore(2)
	place_player(Vector3(0,.05,-40),0.0,-.05)
	await capture("07_warehouse_interior")
	# Kneeling, tied captive faces the warehouse door (+Z); frame the face and bound hands.
	closeup(mission.hostage.global_position+Vector3(.55,.95,1.55),mission.hostage.global_position+Vector3(0,.88,0),42)
	await capture("08_witness_closeup")
	end_closeup()
	await restore(3)
	mission.hostage.global_position = Vector3(-.9,.02,-17.2)
	mission.hostage.rotation.y = 0.35
	mission.escort_hold = true
	place_player(Vector3(0,.05,-20.5),PI,-.12)
	await capture("09_escort")
	mission.escort_hold = false
	mission.pause_menu.open_menu()
	await capture("10_pause_settings")
	mission.pause_menu.close_menu()
	mission.player.health = 0
	mission._finish("lost")
	await capture("11_failure_retry")
	var summary := FileAccess.open(directory+"/index.json",FileAccess.WRITE)
	summary.store_string(JSON.stringify({"captured":captured,"engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name()},"\t"))
	summary.close()
	mission.queue_free()
	await process_frame
	print("CAPTURE: %d frames" % captured.size())
	quit()
