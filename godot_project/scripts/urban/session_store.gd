extends RefCounted
## Versioned, bounded JSON. Keep the previous good file until replacement succeeds.
const DEFAULTS := {"sensitivity":0.0025,"master":0.85,"voice":1.0,"voice_enabled":true,"shadows":true,"subtitles":true,"subtitle_size":17,"fullscreen":false}
var persistent := true
var directory := "user://"
var checkpoint: Dictionary = {}
var preferences: Dictionary = DEFAULTS.duplicate()
var last_error := ""

func initialize() -> void:
	if not persistent:
		return
	var settings := _read_valid(directory+"settings.json",false)
	if not settings.is_empty():
		preferences = settings["values"]
	checkpoint = _read_valid(directory+"checkpoint.json",true)

func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

func valid_checkpoint(data: Variant) -> bool:
	if not data is Dictionary or data.get("version",0) != 1:
		return false
	if not _number(data.get("stage"),0,3) or float(data.stage) != int(data.stage):
		return false
	for field in ["health","ammo","reserve","elapsed","shots","hits"]:
		if not _number(data.get(field),0,10000000):
			return false
	for field in ["health","ammo","reserve","shots","hits"]:
		if float(data[field]) != int(data[field]):
			return false
	if data.health < 1 or data.health > 100 or data.ammo > 30 or data.reserve > 10000 or data.hits > data.shots:
		return false
	if not data.get("supplies") is Array or data.supplies.size() != 2:
		return false
	for used in data.supplies:
		if not used is bool:
			return false
	if not data.get("log") is Array or data.log.size() > 16:
		return false
	for line in data.log:
		if not line is String or line.length() > 500:
			return false
	return true

func valid_settings(data: Variant) -> bool:
	if not data is Dictionary or data.get("version",0) != 1 or not data.get("values") is Dictionary:
		return false
	var p: Dictionary = data["values"]
	for field in ["voice_enabled","shadows","subtitles","fullscreen"]:
		if not p.get(field) is bool:
			return false
	return _number(p.get("sensitivity"),.0005,.01) and _number(p.get("master"),0,1) and _number(p.get("voice"),0,1) and _number(p.get("subtitle_size"),14,24)

func _read_valid(path: String, is_checkpoint: bool) -> Dictionary:
	for candidate in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var file := FileAccess.open(candidate,FileAccess.READ)
		if file == null or file.get_length() > 65536:
			continue
		var data: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if valid_checkpoint(data) if is_checkpoint else valid_settings(data):
			if candidate.ends_with(".bak"):
				last_error = "主存档不可用，已读取上一个有效备份。"
			return data
		last_error = "存档损坏或版本不兼容，可以开始新行动。"
	return {}

func _atomic_write(path: String, data: Dictionary) -> bool:
	if not persistent:
		return true
	last_error = ""
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		last_error = "无法写入存档，请检查磁盘空间和目录权限。"
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		last_error = "存档写入失败，旧检查点未被替换。"
		return false
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path+".bak"):
			DirAccess.remove_absolute(absolute+".bak")
		if DirAccess.rename_absolute(absolute,absolute+".bak") != OK:
			last_error = "无法备份旧存档，已取消替换。"
			return false
	if DirAccess.rename_absolute(absolute+".tmp",absolute) != OK:
		if FileAccess.file_exists(path+".bak"):
			DirAccess.rename_absolute(absolute+".bak",absolute)
		last_error = "无法替换检查点，保留旧存档。"
		return false
	return true

func save_checkpoint(data: Dictionary) -> bool:
	if not valid_checkpoint(data):
		last_error = "检查点数据无效，未覆盖存档。"
		return false
	if not _atomic_write(directory+"checkpoint.json",data):
		return false
	checkpoint = data.duplicate(true)
	return true

func save_preferences() -> bool:
	var data := {"version":1,"values":preferences}
	return valid_settings(data) and _atomic_write(directory+"settings.json",data)

func clear_checkpoint() -> void:
	checkpoint.clear()
	if persistent:
		for suffix in ["",".bak",".tmp"]:
			var path: String = directory + "checkpoint.json" + String(suffix)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
