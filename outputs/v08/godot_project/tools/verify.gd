extends SceneTree
## Verify the main scene loads with all expected nodes.

func _init() -> void:
	print("=== SCENE VERIFY ===")
	var ps: PackedScene = load("res://scenes/main.tscn")
	if ps == null:
		print("FAILED to load main.tscn")
		quit(1)
		return
	var root: Node = ps.instantiate()
	print("root: %s (%s)" % [root.name, root.get_class()])

	for c in root.get_children():
		var extra := ""
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			var surf := mi.mesh.get_surface_count() if mi.mesh else 0
			extra = "  surfaces=%d" % surf
		if c is CharacterBody3D:
			extra = "  children=%d" % c.get_child_count()
		print("  - %-18s %-18s%s" % [c.name, c.get_class(), extra])

	# dig into the player
	var player := root.get_node_or_null("Player")
	if player:
		print("PLAYER children:")
		for c in player.get_children():
			var extra := ""
			if c is MeshInstance3D and c.mesh:
				extra = "  surfaces=%d" % c.mesh.get_surface_count()
			print("    - %-18s %-18s%s" % [c.name, c.get_class(), extra])
		print("    script: %s" % ("OK" if player.get_script() else "MISSING"))
		# count skinned meshes / skeletons in the imported character
		var skels := 0
		var skinned := 0
		var stack: Array = [player]
		while stack.size() > 0:
			var n: Node = stack.pop_back()
			if n is Skeleton3D:
				skels += 1
			if n is MeshInstance3D and n.skeleton:
				skinned += 1
			for ch in n.get_children():
				stack.append(ch)
		print("    skeletons=%d  skinned_meshes=%d" % [skels, skinned])

	# room
	var room := root.get_node_or_null("Room")
	if room:
		var mesh_count := 0
		var stack: Array = [room]
		while stack.size() > 0:
			var n: Node = stack.pop_back()
			if n is MeshInstance3D:
				mesh_count += 1
			for ch in n.get_children():
				stack.append(ch)
		print("ROOM meshes: %d" % mesh_count)

	print("=== OK ===")
	quit()
