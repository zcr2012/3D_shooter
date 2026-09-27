extends RefCounted
## Versioned, bounded JSON. Keep the previous good file until replacement succeeds.
const DEFAULTS := {"sensitivity":0.0025,"master":0.85,"voice":1.0,"voice_enabled":true,"shadows":true,"subtitles":true,"subtitle_size":17,"fullscreen":false}
var persistent := true
var directory := "user://"
var checkpoint: Dictionary = {}
var preferences: Dictionary = DEFAULTS.duplicate()
var last_error := ""

func initialize() -> void:
	last_error = ""
	checkpoint = {}
	preferences = DEFAULTS.duplicate()
	if not persistent:
		return
	var settings := _read_valid(directory+"settings.json",false)
	if not settings.is_empty():
		# Merge over defaults so a future setting never leaves a missing key.
		for key in settings["values"]:
			if DEFAULTS.has(key):
				preferences[key] = settings["values"][key]
	# Settings problems are cosmetic; a checkpoint message is more important.
	last_error = ""
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

func _parse_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 65536:
		return null
	var text := file.get_as_text()
	file.close()
	# JSON.parse_string() logs an engine error for damaged files; an instance parse only reports.
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data

func _is_valid(data: Variant, is_checkpoint: bool) -> bool:
	return valid_checkpoint(data) if is_checkpoint else valid_settings(data)

func _read_valid(path: String, is_checkpoint: bool) -> Dictionary:
	var damaged := false
	for candidate: String in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var data: Variant = _parse_file(candidate)
		if _is_valid(data,is_checkpoint):
			if damaged or candidate.ends_with(".bak"):
				last_error = "主存档不可用，已读取上一个有效备份。"
			return data
		damaged = true
	if damaged:
		last_error = "存档损坏或版本不兼容，可以开始新行动。"
	return {}

func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _atomic_write(path: String, data: Dictionary, is_checkpoint: bool) -> bool:
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
	# Read back before touching the live file: a short write must never replace a good save.
	if error != OK or not _is_valid(_parse_file(path+".tmp"),is_checkpoint):
		_remove(path+".tmp")
		last_error = "存档写入失败，旧检查点未被替换。"
		return false
	if FileAccess.file_exists(path):
		if _is_valid(_parse_file(path),is_checkpoint):
			# Only a valid live file may become the backup; never overwrite a good .bak with junk.
			_remove(path+".bak")
			if DirAccess.rename_absolute(absolute,absolute+".bak") != OK:
				_remove(path+".tmp")
				last_error = "无法备份旧存档，已取消替换。"
				return false
		else:
			_remove(path)
	if DirAccess.rename_absolute(absolute+".tmp",absolute) != OK:
		if not FileAccess.file_exists(path) and FileAccess.file_exists(path+".bak"):
			DirAccess.copy_absolute(absolute+".bak",absolute)
		_remove(path+".tmp")
		last_error = "无法替换检查点，保留旧存档。"
		return false
	return true

func save_checkpoint(data: Dictionary) -> bool:
	if not valid_checkpoint(data):
		last_error = "检查点数据无效，未覆盖存档。"
		return false
	if not _atomic_write(directory+"checkpoint.json",data,true):
		return false
	checkpoint = data.duplicate(true)
	return true

func save_preferences() -> bool:
	var data := {"version":1,"values":preferences}
	return valid_settings(data) and _atomic_write(directory+"settings.json",data,false)

func clear_checkpoint() -> void:
	checkpoint.clear()
	if persistent:
		for suffix: String in ["",".bak",".tmp"]:
			_remove(directory + "checkpoint.json" + suffix)
