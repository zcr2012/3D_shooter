extends "res://scripts/game/enemy.gd"
## Authored lane movement, LOS and strafe reactions; deliberately no fake navmesh.
var encounter: int = 0
var strafe_clock: float = 0.0
var last_seen := Vector3.ZERO
var search_time: float = 0.0

func _ready() -> void:
	super._ready()
	_model.free()
	_model = preload("res://assets/urban/contractor.glb").instantiate()
	add_child(_model)
	_animation = _find_animation(_model)
	_play("IdleArmed")
	_status.visible = false
	# A distinct, non-emissive rust identification patch; avoid floating enemy labels.
	for child in get_children():
		if child is MeshInstance3D:
			child.material_override.emission_enabled = false

func _play(clip: String) -> void:
	super._play(clip)
	if _animation and clip == "StrafeArmed":
		_animation.speed_scale = clampf(absf(velocity.x)/.6,.4,1.3)

func can_see_player() -> bool:
	if not is_instance_valid(player) or not player.controls_enabled:
		return false
	var origin := global_position + Vector3.UP * 1.45
	var target: Vector3 = player.cam.global_position
	if origin.distance_to(target) > 30.0:
		return false
	var ray := PhysicsRayQueryParameters3D.create(origin, target, 1, [get_rid()])
	var result := get_world_3d().direct_space_state.intersect_ray(ray)
	return result.is_empty()

func _physics_process(delta: float) -> void:
	if not active or health <= 0 or not is_instance_valid(player):
		return
	_shot_timer = maxf(0, _shot_timer - delta)
	_react_time = maxf(0, _react_time - delta)
	strafe_clock += delta
	if can_see_player():
		_alert_time += delta
		last_seen = player.global_position
		search_time = 4.0
		var flat := Vector3(last_seen.x, global_position.y, last_seen.z)
		if global_position.distance_to(flat) > 0.05:
			look_at(flat)
		# Keep strafing within a known clear, authored lane; collisions still resolve.
		var offset := sin(strafe_clock * 0.9) * patrol_width
		velocity.x = clampf((home.x + offset - global_position.x) * 1.5, -0.8, 0.8)
		velocity.z = 0
		if _react_time <= 0:
			_play("StrafeArmed" if absf(velocity.x) > .15 else "AimArmed")
			if _alert_time > 1.6 and _shot_timer <= 0:
				_shot_timer = 2.1
				_react_time = 0.28
				_play("FireArmed")
				fired.emit(global_position + Vector3.UP * 1.4, player.cam.global_position)
				player.take_damage(10)
	else:
		_alert_time = 0
		search_time = maxf(0, search_time - delta)
		_phase += delta * 0.65
		var target := home + Vector3(sin(_phase) * patrol_width, 0, 0)
		var travel := target - global_position
		travel.y = 0
		velocity.x = clampf(travel.x * 2, -0.7, 0.7)
		velocity.z = clampf(travel.z * 2, -0.7, 0.7)
		if _react_time <= 0:
			if search_time > 0:
				var flat := Vector3(last_seen.x, global_position.y, last_seen.z)
				if flat.distance_to(global_position) > 0.1:
					look_at(flat)
				_play("AimArmed")
			elif travel.length() > 0.1:
				look_at(global_position + travel)
				_play("WalkArmed")
			else:
				_play("IdleArmed")
	velocity.y -= 9.8 * delta
	move_and_slide()

func take_damage(amount: int) -> bool:
	if health <= 0 or not active or amount <= 0:
		return false
	health = maxi(0,health-amount)
	_react_time = .5
	_play("HitReact")
	if health == 0:
		active = false
		set_deferred("collision_layer",0)
		set_deferred("collision_mask",0)
		_play("FallArmed")
		eliminated.emit(self)
	return true
