extends SceneTree
var mission
func _init() -> void:
	call_deferred("_run")
func capture(label: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://../outputs/release/screenshots")
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory+"/"+label+".png")
func _run() -> void:
	root.size = Vector2i(1280,720)
	mission = load("res://scenes/urban_operation.tscn").instantiate()
	mission.persistence_enabled = false
	mission.cinematics_enabled = false
	root.add_child(mission)
	await capture("01_briefing")
	if mission.pause_menu.is_open:
		mission.pause_menu.close_menu()
	mission.start_mission()
	for enemy in mission.enemies:
		enemy.set_physics_process(false)
	await capture("02_street")
	mission.pause_menu.open_menu()
	await capture("03_settings")
	mission.pause_menu.close_menu()
	mission.queue_free()
	await process_frame
	quit()
