extends Node3D
## Generates static collision for every mesh under this node.
## The room arrives from glTF as visual-only geometry, so without this the
## player has nothing to stand on and falls forever.
##
## Boxes sized to each mesh's AABB are a good fit here because the room is
## built entirely from axis-aligned slabs.

@export var skip_prefixes: PackedStringArray = PackedStringArray(["win_glass"])

var _count: int = 0

func _ready() -> void:
	_build(self)
	print("[room_collision] generated %d colliders" % _count)

func _build(n: Node) -> void:
	for child in n.get_children():
		if child is MeshInstance3D and child.mesh != null:
			var skip := false
			for p in skip_prefixes:
				if child.name.begins_with(p):
					skip = true
					break
			if not skip:
				_add_box(child)
		_build(child)

func _add_box(mi: MeshInstance3D) -> void:
	var aabb: AABB = mi.mesh.get_aabb()

	var body := StaticBody3D.new()
	body.name = String(mi.name) + "_col"

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# grow thin slabs slightly so walls block reliably
	box.size = Vector3(
		maxf(aabb.size.x, 0.02),
		maxf(aabb.size.y, 0.02),
		maxf(aabb.size.z, 0.02)
	)
	col.shape = box
	# the body is parented to the mesh, so the shape sits at the AABB centre
	# in the mesh's own local space
	col.position = aabb.get_center()
	body.add_child(col)
	mi.add_child(body)
	_count += 1
