extends SceneTree
## Headless check: colliders generated, player stands on the floor.

func _init() -> void:
	print("=== FIX VERIFY ===")

	var ps: PackedScene = load("res://scenes/main.tscn")
	if ps == null:
		print("FAIL: main.tscn did not load")
		quit(1)
		return
	var root: Node = ps.instantiate()
	get_root().add_child(root)

	# let _ready() run so room_collision builds the colliders
	await process_frame
	await process_frame

	# ---- count static colliders ----
	var statics := 0
	var shapes := 0
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is StaticBody3D:
			statics += 1
		if n is CollisionShape3D:
			shapes += 1
		for c in n.get_children():
			stack.append(c)
	print("StaticBody3D: %d   CollisionShape3D: %d" % [statics, shapes])

	# ---- simulate physics and watch the player's Y ----
	var player: CharacterBody3D = root.get_node_or_null("Player")
	if player == null:
		print("FAIL: no Player node")
		quit(1)
		return

	print("spawn Y = %.3f" % player.global_position.y)
	var samples := 0
	for i in range(180):          # ~3 s at 60 Hz
		await physics_frame
		samples += 1
		if i % 30 == 0:
			print("  t=%4d  Y=%.3f  on_floor=%s" % [i, player.global_position.y, player.is_on_floor()])

	var final_y: float = player.global_position.y
	print("final Y = %.3f after %d physics frames" % [final_y, samples])
	if final_y < -5.0:
		print("RESULT: STILL FALLING (collision not working)")
	elif absf(final_y) < 3.0:
		print("RESULT: OK - player is resting on the floor")
	else:
		print("RESULT: unexpected Y")

	quit()
