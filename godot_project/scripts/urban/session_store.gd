extends RefCounted
## Versioned, bounded JSON. Keep the previous good file until replacement succeeds.
const DEFAULTS := {"sensitivity":0.0025,"master":0.85,"voice":1.0,"voice_enabled":true,"shadows":true,"subtitles":true,"subtitle_size":17,"fullscreen":false}
var persistent := true
var directory := "user://"
const CHAPTERS := 3
const PROGRESS_DEFAULTS := {"version":1,"unlocked":1,"completed":false}
var checkpoint: Dictionary = {}
var preferences: Dictionary = DEFAULTS.duplicate()
## Campaign progress (which chapters may be selected from a briefing screen).
var progress: Dictionary = PROGRESS_DEFAULTS.duplicate()
var last_error := ""

func initialize() -> void:
	last_error = ""
	checkpoint = {}
	preferences = DEFAULTS.duplicate()
	progress = PROGRESS_DEFAULTS.duplicate()
	if not persistent:
		return
	var settings := _read_valid(directory+"settings.json","settings")
	if not settings.is_empty():
		# Merge over defaults so a future setting never leaves a missing key.
		for key in settings["values"]:
			if DEFAULTS.has(key):
				preferences[key] = settings["values"][key]
	# Settings problems are cosmetic; a checkpoint message is more important.
	last_error = ""
	var saved_progress := _read_valid(directory+"campaign.json","progress")
	if not saved_progress.is_empty():
		progress = saved_progress
	checkpoint = _read_valid(directory+"checkpoint.json","checkpoint")

func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

func valid_checkpoint(data: Variant) -> bool:
	if not data is Dictionary or data.get("version",0) != 1:
		return false
	if not _number(data.get("stage"),0,3) or float(data.stage) != int(data.stage):
		return false
	# Optional since the campaign update; chapter-one saves without it stay valid.
	if data.has("chapter") and (not _number(data.chapter,1,CHAPTERS) or float(data.chapter) != int(data.chapter)):
		return false
	for field in ["health","ammo","reserve","elapsed","shots","hits"]:
		if not _number(data.get(field),0,10000000):
			return false
	for field in ["health","ammo","reserve","shots","hits"]:
		if float(data[field]) != int(data[field]):
			return false
	if data.health < 1 or data.health > 100 or data.ammo > 30 or data.reserve > 10000 or data.hits > data.shots:
		return false
	# Optional since the hit-feedback update; older saves without it stay valid.
	if data.has("headshots"):
		if not _number(data.headshots,0,10000000) or float(data.headshots) != int(data.headshots) or data.headshots > data.hits:
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

func valid_progress(data: Variant) -> bool:
	if not data is Dictionary or data.get("version",0) != 1:
		return false
	return _number(data.get("unlocked"),1,CHAPTERS) and float(data.unlocked) == int(data.unlocked) and data.get("completed") is bool

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

func _is_valid(data: Variant, kind: String) -> bool:
	match kind:
		"checkpoint":
			return valid_checkpoint(data)
		"progress":
			return valid_progress(data)
	return valid_settings(data)

func _read_valid(path: String, kind: String) -> Dictionary:
	var damaged := false
	for candidate: String in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var data: Variant = _parse_file(candidate)
		if _is_valid(data,kind):
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

func _atomic_write(path: String, data: Dictionary, kind: String) -> bool:
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
	if error != OK or not _is_valid(_parse_file(path+".tmp"),kind):
		_remove(path+".tmp")
		last_error = "存档写入失败，旧检查点未被替换。"
		return false
	if FileAccess.file_exists(path):
		if _is_valid(_parse_file(path),kind):
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
	if not _atomic_write(directory+"checkpoint.json",data,"checkpoint"):
		return false
	checkpoint = data.duplicate(true)
	return true

func save_preferences() -> bool:
	var data := {"version":1,"values":preferences}
	return valid_settings(data) and _atomic_write(directory+"settings.json",data,"settings")

func save_progress() -> bool:
	return valid_progress(progress) and _atomic_write(directory+"campaign.json",progress,"progress")

func unlock_chapter(index: int) -> bool:
	## Finishing a chapter unlocks the next one; progress never moves backwards.
	var wanted := clampi(index,1,CHAPTERS)
	if wanted <= int(progress.unlocked):
		return true
	progress.unlocked = wanted
	return save_progress()

func mark_completed() -> bool:
	progress.completed = true
	return save_progress()

func clear_checkpoint() -> void:
	checkpoint.clear()
	if persistent:
		for suffix: String in ["",".bak",".tmp"]:
			_remove(directory + "checkpoint.json" + suffix)
