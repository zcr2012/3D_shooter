extends "res://scripts/game/enemy.gd"
## Bounded, observable tactics. Only LOS can authorize damage; memory is not sight.
signal spotted(where: Vector3)
var encounter: int = 0
var role := "anchor"
var city
var squad
var tactical_state := "patrol"
var last_seen := Vector3.ZERO
var search_time := 0.0
var rounds := 5
var reload_time := 0.0
var move_path := PackedVector2Array()
var cover_slot := Vector3.INF
var cover_wait := 0.0
var decision_time := 0.0
var has_visual := false
var _clock := 0.0
var stuck_time := 0.0
var search_yaw := 0.0

func _ready() -> void:
	super._ready()
	_model.free()
	_model = preload("res://assets/urban/contractor.glb").instantiate()
	add_child(_model)
	_animation = _find_animation(_model)
	_flash_meshes.clear()
	_collect_flash_meshes(_model)
	_play("IdleArmed")
	_status.visible = false
	rotation.y = 0 if encounter == 3 else PI
	for child in get_children():
		if child is MeshInstance3D:
			child.material_override.emission_enabled = false

func can_see_player() -> bool:
	if not is_instance_valid(player) or not player.controls_enabled:
		return false
	return global_position.distance_to(player.global_position) < 30 and _clear_line(global_position,player.cam.global_position)

func _clear_line(from_position: Vector3,target: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from_position+Vector3.UP*1.45,target,1,[get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func in_view_cone() -> bool:
	var direction: Vector3 = player.global_position-global_position
	direction.y = 0
	return direction.length() < 2 or (-global_basis.z).dot(direction.normalized()) > .25

func hear_noise(where: Vector3) -> void:
	if not active or health <= 0 or global_position.distance_to(where) > 20:
		return
	if tactical_state == "patrol" or tactical_state == "search":
		receive_alert(where)

func receive_alert(where: Vector3) -> void:
	if not active or health <= 0 or tactical_state in ["engage","relocate","cover","peek"]:
		return
	last_seen = where.snapped(Vector3(.5,1,.5))
	search_time = 5
	tactical_state = "investigate"
	_face(last_seen)
	_plan_to(last_seen)

func _physics_process(delta: float) -> void:
	if health <= 0 or not is_instance_valid(player):
		return
	if not active:
		velocity.x = 0
		velocity.z = 0
		_settle(delta)
		return
	_clock += delta
	_shot_timer = maxf(0,_shot_timer-delta)
	_react_time = maxf(0,_react_time-delta)
	decision_time = maxf(0,decision_time-delta)
	reload_time = maxf(0,reload_time-delta)
	search_time = maxf(0,search_time-delta)
	has_visual = can_see_player() and in_view_cone()
	if has_visual:
		if search_time <= 0:
			spotted.emit(player.global_position)
		last_seen = player.global_position
		search_time = 5
		_alert_time += delta
		if tactical_state in ["patrol","investigate","search"]:
			tactical_state = "engage"
			move_path.clear()
	else:
		_alert_time = 0
		if tactical_state == "engage":
			_enter_search()
	velocity.x = 0
	velocity.z = 0
	if _react_time > 0:
		_settle(delta)
		return
	if rounds == 0:
		if reload_time <= 0 and tactical_state != "reload":
			tactical_state = "reload"
			reload_time = 2.8
			_play("ReloadArmed")
		elif reload_time <= 0:
			rounds = 5
			if has_visual:
				tactical_state = "engage"
			else:
				_enter_search()
		_settle(delta)
		return
	match tactical_state:
		"patrol":
			_phase += delta*.6
			velocity.x = clampf((home.x+sin(_phase)*patrol_width-global_position.x)*2,-.55,.55)
			_play("StrafeArmed" if absf(velocity.x) > .1 else "IdleArmed")
		"investigate", "relocate", "peek":
			if _follow_path():
				_play("WalkArmed")
			else:
				if tactical_state == "relocate":
					tactical_state = "cover"
					cover_wait = .85
				elif has_visual:
					tactical_state = "engage"
				else:
					_enter_search()
		"cover":
			_face(last_seen)
			_play("AimArmed")
			cover_wait -= delta
			if cover_wait <= 0:
				_plan_peek()
		"engage":
			_face(last_seen)
			_play("AimArmed")
			if has_visual and _alert_time >= 1.6 and _shot_timer <= 0 and clear_fire_lane():
				rounds -= 1
				_shot_timer = 2.1
				_react_time = .28
				_play("FireArmed")
				fired.emit(global_position+Vector3.UP*1.4,player.cam.global_position)
				player.take_damage(10,global_position+Vector3.UP*1.4)
			if decision_time <= 0 and (health <= 66 or (role == "flanker" and rounds < 4)):
				decision_time = 4
				_choose_cover()
		"search":
			# Lost contact: walk to the last confirmed position if it is reachable,
			# then sweep the sector instead of freezing; last_seen is never updated
			# by memory so wall-hack shots stay impossible.
			if not move_path.is_empty():
				if _follow_path():
					_play("WalkArmed")
				else:
					move_path.clear()
			if move_path.is_empty():
				_play("AimArmed")
				rotation.y = search_yaw+sin(_clock*1.15)*.42
			if search_time <= 0:
				tactical_state = "patrol"
				home = global_position
				release_cover()
	_settle(delta)

func _settle(delta: float) -> void:
	var before := global_position
	var desired := Vector2(velocity.x,velocity.z).length()
	velocity.y -= 9.8*delta
	move_and_slide()
	var travelled := Vector2(global_position.x-before.x,global_position.z-before.z).length()
	if tactical_state in ["relocate","peek","investigate","search"] and desired > .1 and travelled < desired*delta*.15:
		stuck_time += delta
	else:
		stuck_time = 0
	if stuck_time > 1.2:
		move_path.clear()
		release_cover()
		_enter_search(false)
		stuck_time = 0

func _enter_search(plan_path := true) -> void:
	tactical_state = "search"
	search_yaw = rotation.y
	if plan_path:
		_plan_to(last_seen)

func _face(where: Vector3) -> void:
	var point := Vector3(where.x,global_position.y,where.z)
	if point.distance_to(global_position) > .05:
		look_at(point)

func _plan_to(where: Vector3) -> bool:
	move_path.clear()
	if not is_instance_valid(city) or not city.inside_corridor(global_position) or global_position.distance_to(where) > 18:
		return false
	move_path = city.escort_path(global_position,where)
	return not move_path.is_empty()

func _follow_path() -> bool:
	while not move_path.is_empty():
		var next := Vector3(move_path[0].x,global_position.y,move_path[0].y)
		if next.distance_to(global_position) < .15:
			move_path.remove_at(0)
		else:
			_face(next)
			var direction := (next-global_position).normalized()
			velocity.x = direction.x*1.2
			velocity.z = direction.z*1.2
			return true
	return false

func _choose_cover() -> void:
	if not is_instance_valid(city) or not is_instance_valid(squad):
		return
	var best := Vector3.INF
	var score := INF
	for candidate in city.cover_slots:
		var distance: float = global_position.distance_to(candidate)
		if distance < .6 or distance > 12 or not squad.cover_available(candidate,self):
			continue
		if _clear_line(candidate,last_seen+Vector3.UP*1.4):
			continue
		var path: PackedVector2Array = city.escort_path(global_position,candidate)
		if path.is_empty():
			continue
		var cost: float = distance - (minf(absf(candidate.x-global_position.x),4)*.45 if role == "flanker" else 0.0)
		if cost < score:
			score = cost
			best = candidate
	if best != Vector3.INF and _plan_to(best):
		release_cover()
		cover_slot = best
		squad.cover_claims[best] = get_instance_id()
		tactical_state = "relocate"

func _plan_peek() -> void:
	for side in [-1.0,1.0]:
		var destination := global_position+Vector3(side*1.4,0,0)
		if _clear_line(destination,last_seen+Vector3.UP*1.4) and _plan_to(destination):
			tactical_state = "peek"
			return
	release_cover()
	_enter_search()

func release_cover() -> void:
	if is_instance_valid(squad) and squad.cover_claims.get(cover_slot,0) == get_instance_id():
		squad.cover_claims.erase(cover_slot)
	cover_slot = Vector3.INF

func take_damage(amount: int) -> bool:
	if health <= 0 or not active or amount <= 0:
		return false
	health = maxi(0,health-amount)
	_react_time = .5
	flash_hit()
	reload_time = 0
	tactical_state = "engage"
	last_seen = player.global_position
	search_time = 5
	_play("HitReact")
	if health == 0:
		active = false
		tactical_state = "dead"
		release_cover()
		set_deferred("collision_layer",0)
		set_deferred("collision_mask",0)
		_play("FallArmed")
		eliminated.emit(self)
	return true

func clear_fire_lane() -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*1.45,player.cam.global_position,1|4,[get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
