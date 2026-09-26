extends SceneTree
## Check that the exported GLB carries an animation clip into Godot.

func _init() -> void:
	print("=== ANIMATION VERIFY ===")

	var ps: PackedScene = load("res://assets/swat_operator.glb")
	if ps == null:
		print("FAIL: glb did not load")
		quit(1)
		return
	var root: Node = ps.instantiate()

	var anims := 0
	var names: Array = []
	var players := 0
	var skels := 0
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is AnimationPlayer:
			players += 1
			var ap := n as AnimationPlayer
			for a in ap.get_animation_list():
				anims += 1
				names.append(a)
				var anim := ap.get_animation(a)
				print("  clip '%s'  length=%.2fs  tracks=%d  loop=%s" % [
					a, anim.length, anim.get_track_count(),
					str(anim.loop_mode)])
		if n is Skeleton3D:
			skels += 1
		for c in n.get_children():
			stack.append(c)

	print("AnimationPlayer nodes: %d" % players)
	print("skeletons: %d" % skels)
	print("clips: %d  %s" % [anims, str(names)])
	if anims == 0:
		print("RESULT: NO ANIMATION - export did not carry the action")
	else:
		print("RESULT: OK - animation present")
	quit()
