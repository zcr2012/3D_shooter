extends CharacterBody3D
## Small encounter AI: patrol a clear lane, acquire by LOS, telegraph, then fire.
## No navmesh pathfinding: patrol lanes are authored not to cross cover.
signal eliminated(enemy: Node3D)
signal fired(origin: Vector3, target: Vector3)

const MODEL = preload("res://assets/swat_operator.glb")
var health: int = 100
var active: bool = false
var player
var home: Vector3
var patrol_width: float = 1.0
var _phase: float = 0.0
var _alert_time: float = 0.0
var _shot_timer: float = 0.0
var _react_time: float = 0.0
var _model: Node3D
var _animation: AnimationPlayer
var _status: Label3D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	add_to_group("enemies")
	home = position
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	_model = MODEL.instantiate()
	add_child(_model)
	_animation = _find_animation(_model)
	# Distinct armband/marker rather than reusing the player's identification.
	var band := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.30, 0.055, 0.018)
	band.mesh = mesh
	band.position = Vector3(0, 1.16, -0.21)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("d8a05b")
	mat.emission_enabled = true
	mat.emission = Color("c56538")
	band.material_override = mat
	add_child(band)
	_status = Label3D.new()
	_status.position.y = 2.0
	_status.font_size = 28
	_status.pixel_size = 0.006
	_status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status.modulate = Color("eeb47b")
	_status.text = "SENTRY"
	add_child(_status)
	_play("IdleArmed")

func _find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation(child)
		if found:
			return found
	return null

func _play(clip: String) -> void:
	if not _animation:
		return
	for key in _animation.get_animation_list():
		if String(key).get_file() == clip:
			_animation.speed_scale = 0.7 if clip == "WalkArmed" else 1.0
			if _animation.current_animation != key or not _animation.is_playing():
				_animation.play(key, 0.12)
			return

func can_see_player() -> bool:
	if not is_instance_valid(player) or not player.controls_enabled:
		return false
	var origin := global_position + Vector3.UP * 1.35
	var target: Vector3 = player.global_position + Vector3.UP * 1.05
	if origin.distance_to(target) > 18.0:
		return false
	var query := PhysicsRayQueryParameters3D.create(origin, target, 1 | 2, [get_rid()])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.collider == player

func _physics_process(delta: float) -> void:
	if not active or health <= 0 or not is_instance_valid(player):
		return
	_shot_timer = maxf(0, _shot_timer - delta)
	_react_time = maxf(0, _react_time - delta)
	if can_see_player():
		_alert_time += delta
		velocity.x = 0
		velocity.z = 0
		var target: Vector3 = player.global_position
		target.y = global_position.y
		if target.distance_squared_to(global_position) > 0.01:
			look_at(target)
		_status.text = "!  CONTACT"
		_status.modulate = Color("f87564")
		if _react_time <= 0.0:
			_play("AimArmed")
			# A visible acquisition delay and predictable cadence give time to use cover.
			if _alert_time >= 1.4 and _shot_timer <= 0:
				_shot_timer = 1.8
				_react_time = 0.28
				_play("FireArmed")
				fired.emit(global_position + Vector3.UP * 1.3, player.global_position + Vector3.UP)
				player.take_damage(12)
	else:
		_alert_time = 0
		_status.text = "SENTRY"
		_status.modulate = Color("eeb47b")
		_phase += delta * 0.65
		var target := home + Vector3(sin(_phase) * patrol_width, 0, 0)
		var travel := target - global_position
		travel.y = 0
		velocity.x = clampf(travel.x * 2.0, -0.7, 0.7)
		velocity.z = clampf(travel.z * 2.0, -0.7, 0.7)
		if travel.length() > 0.1 and _react_time <= 0:
			look_at(global_position + travel)
			_play("WalkArmed")
		elif _react_time <= 0:
			_play("IdleArmed")
	velocity.y -= 9.8 * delta
	move_and_slide()

func take_damage(amount: int) -> bool:
	if health <= 0 or not active or amount <= 0:
		return false
	health = maxi(0, health - amount)
	_react_time = 0.5
	_play("HitReact")
	if health == 0:
		active = false
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
		_status.text = "CLEAR"
		_status.modulate = Color("79cabc")
		eliminated.emit(self)
		var tween := create_tween()
		tween.tween_property(_model, "rotation:x", -PI / 2.0, 0.45)
	return true
