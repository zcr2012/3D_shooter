extends SceneTree
## Drive the player programmatically and confirm the walk clip animates.

func _init() -> void:
	print("=== MOTION + ANIM VERIFY ===")

	var ps: PackedScene = load("res://scenes/main.tscn")
	var root: Node = ps.instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame

	var player: CharacterBody3D = root.get_node_or_null("Player")
	if player == null:
		print("FAIL: no Player")
		quit(1)
		return

	# find the AnimationPlayer under the model
	var ap: AnimationPlayer = null
	var stack: Array = [player.get_node("Model")]
	while stack.size() > 0 and ap == null:
		var n: Node = stack.pop_back()
		if n is AnimationPlayer:
			ap = n
		for c in n.get_children():
			stack.append(c)
	if ap == null:
		print("FAIL: no AnimationPlayer in Model")
		quit(1)
		return
	print("AnimationPlayer found; current='%s' speed=%.2f" % [ap.current_animation, ap.speed_scale])

	# --- simulate holding "back" (open floor toward +Z) ---
	Input.action_press("move_back")

	var start := player.global_position
	var poses: Array = []
	for i in range(120):                 # 2 s
		await physics_frame
		if i % 20 == 0:
			var skel: Skeleton3D = _find_skeleton(player)
			# the clip animates ROTATION, so sample that (not position)
			var rot := Vector3.ZERO
			if skel:
				var b := skel.find_bone("thigh.L")
				rot = skel.get_bone_pose_rotation(b).get_euler()
			poses.append(rot)
			print("  t=%3d  pos=(%.2f,%.2f,%.2f)  anim_speed=%.2f  thighL_rot=(%.3f,%.3f,%.3f)" % [
				i, player.global_position.x, player.global_position.y,
				player.global_position.z, ap.speed_scale, rot.x, rot.y, rot.z])

	Input.action_release("move_back")

	var moved := (player.global_position - start).length()
	print("moved %.2f m in 2 s" % moved)

	# did the bone actually change between samples?
	var varied := false
	for i in range(1, poses.size()):
		if poses[i].distance_to(poses[0]) > 0.001:
			varied = true
			break
	print("bone pose changed over time: %s" % str(varied))

	if moved > 0.5 and varied:
		print("RESULT: OK - character walks and the skeleton animates")
	elif moved > 0.5:
		print("RESULT: PARTIAL - moves but skeleton is static")
	else:
		print("RESULT: FAIL - did not move")
	quit()

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var f := _find_skeleton(c)
		if f:
			return f
	return null
