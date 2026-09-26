extends SceneTree
## Verify the camera-relative movement fix.

func _init() -> void:
	print("=== MOVEMENT FIX VERIFY ===")
	var ps: PackedScene = load("res://scenes/main.tscn")
	var root: Node = ps.instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame

	var player: CharacterBody3D = root.get_node("Player")
	var model: Node3D = player.get_node("Model")

	# ---------- 1. movement follows yaw ----------
	print("--- 1. movement direction vs yaw ---")
	for yaw_deg in [0, 90, 180, 270]:
		player.set("_yaw", deg_to_rad(yaw_deg))
		player.global_position = Vector3(0, 0.5, 0)
		player.velocity = Vector3.ZERO
		Input.action_press("move_forward")
		for i in range(25):
			await physics_frame
		Input.action_release("move_forward")
		var v: Vector3 = player.velocity
		# where does the model actually face, in world space?
		var facing: Vector3 = -model.global_transform.basis.z
		var facing_deg: float = rad_to_deg(atan2(facing.x, facing.z))
		var move_deg: float = rad_to_deg(atan2(v.x, v.z))
		var diff: float = absf(angle_difference(atan2(v.x, v.z), atan2(facing.x, facing.z)))
		print("  yaw=%3d  move=(%+.2f,%+.2f)  facing=(%+.2f,%+.2f)  mismatch=%.1fdeg" % [
			yaw_deg, v.x, v.z, facing.x, facing.z, rad_to_deg(diff)])
		for i in range(6):
			await physics_frame

	# ---------- 2. mouse look works even when capture is unavailable ----------
	print("--- 2. mouse look independent of capture state ---")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE     # simulate a failed capture
	var y0: float = player.get("_yaw")
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(250, 0)
	player._unhandled_input(ev)
	var y1: float = player.get("_yaw")
	print("  capture=%d  _yaw %.4f -> %.4f  delta=%.4f" % [
		Input.mouse_mode, y0, y1, y1 - y0])
	if not is_equal_approx(y0, y1):
		print("  >>> look still works when capture is unavailable")
	else:
		print("  >>> look is STILL gated on capture")

	# ---------- 3. does the input event arrive through the normal path? ----------
	print("--- 3. event delivery ---")
	var y2: float = player.get("_yaw")
	Input.parse_input_event(ev)
	for i in range(3):
		await process_frame
	var y3: float = player.get("_yaw")
	print("  via parse_input_event: %.4f -> %.4f" % [y2, y3])

	print("=== DONE ===")
	quit()
