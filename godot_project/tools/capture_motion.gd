extends SceneTree
## Short graphical smoke test and real-renderer screenshot; exits on its own.
var world: Node
func _init() -> void:
	call_deferred("_capture")
func _capture() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var player: CharacterBody3D = world.get_node("Player")
	player.call("_set_look", false)
	for i in range(70):
		await physics_frame
		await process_frame
	var out := ProjectSettings.globalize_path("res://../outputs")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("godot_motion_runtime.png"))
	print("GRAPHICS adapter=", RenderingServer.get_video_adapter_name(), " renderer=", RenderingServer.get_current_rendering_method())
	print("GRAPHICS draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var sk: Skeleton3D = _skeleton(player.get_node("Model"))
	if sk:
		var rifle := _named_mesh(player.get_node("Model"), "AR_AssaultRifle")
		# Mesh geometry is converted Z-up to Y-up; unlike bone-local Y,
		# the rifle mesh's local -Z is its authored forward axis.
		var muzzle_direction := -rifle.global_transform.basis.z.normalized()
		var model_forward: Vector3 = -(player.get_node("Model") as Node3D).global_transform.basis.z.normalized()
		print("MODEL_FORWARD_DOT=", Vector2(muzzle_direction.x,muzzle_direction.z).normalized().dot(Vector2(model_forward.x,model_forward.z).normalized()))
	world.queue_free()
	await process_frame
	await process_frame
	quit()
func _named_mesh(n: Node, wanted: String) -> MeshInstance3D:
	if n is MeshInstance3D and String(n.name).begins_with(wanted): return n
	for c in n.get_children():
		var found := _named_mesh(c, wanted)
		if found: return found
	return null
func _skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D: return n
	for c in n.get_children():
		var found := _skeleton(c)
		if found: return found
	return null
