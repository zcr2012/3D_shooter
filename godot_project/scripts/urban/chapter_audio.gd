extends Node
## Independent speech/effects paths: effects cannot interrupt dialogue.
var mission
var voice: AudioStreamPlayer
var ambience: AudioStreamPlayer
var effects: Array[AudioStreamPlayer3D] = []
var effect_cursor := 0
var heartbeat: AudioStreamPlayer
var voice_enabled := true
var step_clock := 0.0
var was_reloading := false
var lines: Dictionary = {}

func _ready() -> void:
	lines = JSON.parse_string(FileAccess.get_file_as_string("res://data/zh_dialogue.json"))
	for bus in ["Dialogue", "Effects"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
	var has_limiter := false
	for i in AudioServer.get_bus_effect_count(0):
		has_limiter = has_limiter or AudioServer.get_bus_effect(0,i).resource_name == "ChapterPeakLimiter"
	if not has_limiter:
		var limiter := AudioEffectHardLimiter.new()
		limiter.resource_name = "ChapterPeakLimiter"
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(0,limiter)
	voice = AudioStreamPlayer.new()
	voice.bus = "Dialogue"
	voice.volume_db = -3
	add_child(voice)
	voice_enabled = not AudioServer.is_bus_mute(AudioServer.get_bus_index("Dialogue"))
	ambience = AudioStreamPlayer.new()
	ambience.bus = "Effects"
	ambience.volume_db = -32
	var bed: AudioStreamWAV = load("res://assets/audio/sfx/dock_ambience.wav")
	bed.loop_mode = AudioStreamWAV.LOOP_FORWARD
	bed.loop_end = 12 * bed.mix_rate
	ambience.stream = bed
	add_child(ambience)
	# Low-health heartbeat: a dedicated looping player so it never steals an effect slot.
	heartbeat = AudioStreamPlayer.new()
	heartbeat.bus = "Effects"
	heartbeat.volume_db = -60
	var pulse: AudioStreamWAV = load("res://assets/audio/sfx/heartbeat.wav")
	pulse.loop_mode = AudioStreamWAV.LOOP_FORWARD
	pulse.loop_end = int(1.15 * pulse.mix_rate)
	heartbeat.stream = pulse
	add_child(heartbeat)
	# Twelve pooled emitters: gunfire, footsteps and now impact/confirm cues share them.
	for i in 12:
		var sound := AudioStreamPlayer3D.new()
		sound.bus = "Effects"
		sound.max_distance = 45
		sound.unit_size = 4
		sound.volume_db = -10
		add_child(sound)
		effects.append(sound)

func speak(id: String) -> float:
	voice.stop()
	var path := "res://assets/audio/zh/"+id+".mp3"
	voice.stream = load(path) if ResourceLoader.exists(path) else null
	if voice.stream:
		voice.play()
		return voice.stream.get_length() + .7
	# A damaged/missing optional recording must not prevent the mission from starting.
	return maxf(6.0,String(lines[id].text).length()/4.5)

func stop_speech() -> void:
	voice.stop()

func toggle_voice() -> void:
	voice_enabled = not voice_enabled
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Dialogue"),not voice_enabled)

func effect(id: String, where: Vector3, volume: float = -10) -> void:
	var sound := effects[effect_cursor]
	effect_cursor = (effect_cursor+1)%effects.size()
	sound.stop()
	sound.global_position = where
	sound.stream = load("res://assets/audio/sfx/"+id+".wav")
	sound.volume_db = volume
	sound.pitch_scale = randf_range(.97,1.03)
	sound.play()

func gun(where: Vector3) -> void:
	effect("carbine_room" if where.z < -36 else "carbine_dry",where)

func _process(delta: float) -> void:
	if mission.state in ["active","cinematic"]:
		if not ambience.playing:
			ambience.play()
	elif ambience.playing:
		ambience.stop()
	var bus := AudioServer.get_bus_index("Effects")
	var target := -7.0 if voice.playing and voice_enabled else 0.0
	AudioServer.set_bus_volume_db(bus,lerpf(AudioServer.get_bus_volume_db(bus),target,1-exp(-6*delta)))
	if not is_instance_valid(mission.player) or mission.state != "active":
		if heartbeat.playing:
			heartbeat.stop()
		return
	var p = mission.player
	_update_heartbeat(int(p.health),delta)
	step_clock -= delta
	if p.is_on_floor() and p.horizontal_speed > .4 and step_clock <= 0:
		step_clock = .34 if p.horizontal_speed > 3 else .52
		effect("footstep",p.global_position,-22 if p.crouched else -16)
	if p.is_reloading and not was_reloading:
		effect("magazine",p.cam.global_position,-13)
	was_reloading = p.is_reloading

func _update_heartbeat(health: int, delta: float) -> void:
	# Below 30 health the pulse fades in and gets louder as health drops; silent otherwise.
	var low := clampf((30.0-health)/30.0,0.0,1.0) if health > 0 else 0.0
	if low <= 0.0:
		if heartbeat.playing:
			heartbeat.stop()
		return
	if not heartbeat.playing:
		heartbeat.volume_db = -40
		heartbeat.play()
	heartbeat.volume_db = lerpf(heartbeat.volume_db,lerpf(-24.0,-10.0,low),1-exp(-4*delta))

func _exit_tree() -> void:
	if is_instance_valid(voice):
		voice.stop()
	if is_instance_valid(ambience):
		ambience.stop()
	if is_instance_valid(heartbeat):
		heartbeat.stop()
	for sound in effects:
		sound.stop()
	var bus := AudioServer.get_bus_index("Effects")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus,0)

func pause_audio(paused: bool) -> void:
	voice.stream_paused = paused
	ambience.stream_paused = paused
	heartbeat.stream_paused = paused
	for effect_player in effects:
		effect_player.stream_paused = paused

func stop_all() -> void:
	voice.stop()
	ambience.stop()
	heartbeat.stop()
	for effect_player in effects:
		effect_player.stop()
	was_reloading = false
	pause_audio(false)
