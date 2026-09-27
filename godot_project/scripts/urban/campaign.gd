extends RefCounted
## Chapter routing for the three-chapter campaign. Scenes are loaded one at a time.
const SCENES := ["res://scenes/urban_operation.tscn","res://scenes/yard_operation.tscn","res://scenes/pier_operation.tscn"]
const NAMES := ["默瑟街","堆场","潮汐"]
## Set before a scene change so the target chapter restores the saved checkpoint once it is ready.
static var pending_restore := false

static func open_chapter(tree: SceneTree, index: int, restore: bool = false) -> void:
	pending_restore = restore
	tree.paused = false
	tree.change_scene_to_file(SCENES[clampi(index,1,SCENES.size())-1])
