extends CharacterBody3D

const MF = preload("res://scripts/mesh_factory.gd")

const RUN_SPEED := 7.2
const GROUND_ACCEL := 58.0
const AIR_ACCEL := 32.0
const GROUND_FRICTION := 64.0
const AIR_FRICTION := 5.0
const GRAVITY := 24.0
const JUMP_VELOCITY := 8.4
const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.12
const FIRE_RATE := 0.15
const MAX_HEALTH := 100
const RAY_LENGTH := 80.0
const HUG_DURATION := 4.0
const HUG_MASH_GAIN := 0.11
const HUG_DRAIN := 0.02

var game: Node
var health := MAX_HEALTH
var max_health := MAX_HEALTH
var dead := false
var suppress_fire := 0.0
var recoil := 0.0
var aim_direction := Vector3.FORWARD
var hugged := false
var hug_progress := 0.0
var hug_time := 0.0
var hug_duration := HUG_DURATION

var _hugger: Node

var _invulnerable := 0.0
var _fire_cooldown := 0.0
var _muzzle_timer := 0.0
var _flash := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _run_phase := 0.0
var _time := 0.0
var _was_on_floor := false

var _model: Node3D
var _leg_left: Node3D
var _leg_right: Node3D
var _arm_left: Node3D
var _arm_right: Node3D
var _gun: Node3D
var _muzzle: Marker3D
var _muzzle_flash: MeshInstance3D
var _muzzle_light: OmniLight3D
var _hurt_light: OmniLight3D
var _laser: MeshInstance3D
var _aim_marker: MeshInstance3D
var _laser_material: StandardMaterial3D
var _marker_material: StandardMaterial3D


func setup(new_game: Node) -> void:
	game = new_game


func _ready() -> void:
	add_to_group("player")
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.25
	floor_stop_on_slope = true
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.9
	collision.shape = capsule
	collision.position = Vector3(0.0, 0.95, 0.0)
	add_child(collision)
	_build_model()
	_build_aim_helpers()


func _exit_tree() -> void:
	if is_instance_valid(_laser):
		_laser.queue_free()
	if is_instance_valid(_aim_marker):
		_aim_marker.queue_free()


func _physics_process(delta: float) -> void:
	_time += delta
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_muzzle_timer = maxf(0.0, _muzzle_timer - delta)
	_invulnerable = maxf(0.0, _invulnerable - delta)
	_flash = maxf(0.0, _flash - delta * 5.0)
	suppress_fire = maxf(0.0, suppress_fire - delta)
	recoil = move_toward(recoil, 0.0, delta * 12.0)

	if hugged:
		_update_hug(delta)

	var can_control: bool = game != null and game.state == "playing" and not dead and not hugged
	var fall_speed := velocity.y

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		_coyote = maxf(0.0, _coyote - delta)
	else:
		_coyote = COYOTE_TIME

	var input_vector := Vector2.ZERO
	if can_control:
		input_vector = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_forward", "move_back")
		)
		if input_vector.length_squared() > 1.0:
			input_vector = input_vector.normalized()
	var move_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)

	if move_direction.length_squared() > 0.01:
		var acceleration := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
		horizontal = horizontal.move_toward(move_direction * RUN_SPEED, acceleration * delta)
	else:
		var friction := GROUND_FRICTION if is_on_floor() else AIR_FRICTION
		horizontal = horizontal.move_toward(Vector3.ZERO, friction * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if can_control:
		if Input.is_action_just_pressed("jump"):
			_jump_buffer = JUMP_BUFFER_TIME
		else:
			_jump_buffer = maxf(0.0, _jump_buffer - delta)

		if _jump_buffer > 0.0 and _coyote > 0.0:
			velocity.y = JUMP_VELOCITY
			_jump_buffer = 0.0
			_coyote = 0.0
			Sfx.play("jump", randf_range(0.96, 1.06), -11.0)
			if game != null:
				game.effects.burst(global_position + Vector3(0.0, 0.08, 0.0), Color(0.62, 0.68, 0.53, 0.45), 7, 2.2, 0.4, 0.055, 4.0)

		if Input.is_action_just_released("jump") and velocity.y > 4.0:
			velocity.y = 4.0

		if suppress_fire <= 0.0 and _fire_cooldown <= 0.0 and Input.is_action_pressed("shoot"):
			_shoot()
	else:
		_jump_buffer = 0.0

	move_and_slide()

	if is_on_floor() and not _was_on_floor and fall_speed < -4.0:
		if game != null:
			game.effects.burst(global_position + Vector3(0.0, 0.06, 0.0), Color(0.6, 0.65, 0.52, 0.55), 10, 2.8, 0.42, 0.06, 5.0)
			game.add_shake(1.0)
	_was_on_floor = is_on_floor()

	if can_control:
		_update_aim(delta)
	else:
		_set_aim_helpers_visible(false)

	_animate(delta)
	_update_feedback()


func _update_hug(delta: float) -> void:
	if game == null or game.state != "playing":
		return
	hug_time += delta
	hug_progress = maxf(0.0, hug_progress - HUG_DRAIN * delta)
	if Input.is_action_just_pressed("jump"):
		hug_progress = minf(1.0, hug_progress + HUG_MASH_GAIN)
		Sfx.play("struggle", randf_range(0.9, 1.1), -10.0)
		if game != null:
			game.effects.burst(global_position + Vector3(0.0, 1.5, 0.0), Color(1.0, 0.7, 0.3, 0.8), 6, 2.0, 0.3, 0.05, 4.0)
	if hug_progress >= 1.0:
		_escape_hug()
	elif hug_time >= hug_duration:
		_die_infected()


func attach_facehugger(hugger: Node) -> bool:
	if dead or hugged or game == null or game.state != "playing":
		return false
	hugged = true
	hug_progress = 0.0
	hug_time = 0.0
	_hugger = hugger
	velocity = Vector3.ZERO
	_jump_buffer = 0.0
	_set_aim_helpers_visible(false)
	game.on_player_hugged(hugger)
	return true


func _escape_hug() -> void:
	if not hugged:
		return
	hugged = false
	hug_progress = 0.0
	hug_time = 0.0
	_jump_buffer = 0.0
	var hugger := _hugger
	_hugger = null
	if is_instance_valid(hugger) and hugger.has_method("deflect"):
		hugger.deflect()
	if game != null:
		game.on_hug_escaped()


func _die_infected() -> void:
	if dead:
		return
	dead = true
	hugged = false
	health = 0
	_invulnerable = 0.0
	_flash = 0.0
	collision_layer = 0
	collision_mask = 0
	_set_aim_helpers_visible(false)
	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = false
	if is_instance_valid(_muzzle_light):
		_muzzle_light.light_energy = 0.0
	if is_instance_valid(_hugger) and _hugger.has_method("on_host_infected"):
		_hugger.on_host_infected()
	_hugger = null
	if game != null:
		game.on_player_infected()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_model, "rotation:z", 1.2, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_model, "position:y", -0.2, 0.7)


func _update_aim(delta: float) -> void:
	if game == null:
		return
	var aim_point: Vector3 = game.get_aim_point()
	var to_aim := aim_point - global_position
	to_aim.y = 0.0
	if to_aim.length_squared() > 0.01:
		aim_direction = to_aim.normalized()
		var target_yaw := atan2(-aim_direction.x, -aim_direction.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-delta * 20.0))
	_update_laser(aim_point)


func _update_laser(aim_point: Vector3) -> void:
	if game == null or game.state != "playing" or dead or not Settings.laser_sight:
		_set_aim_helpers_visible(false)
		return
	var muzzle := get_muzzle_global()
	var offset := aim_point - muzzle
	var distance := offset.length()
	if distance < 0.7:
		_set_aim_helpers_visible(false)
		return
	_laser.visible = true
	_laser.global_position = (muzzle + aim_point) * 0.5
	_laser.scale = Vector3(1.0, 1.0, distance)
	var up := Vector3.UP
	if absf(offset.normalized().dot(Vector3.UP)) > 0.97:
		up = Vector3.RIGHT
	_laser.look_at(aim_point, up)

	_aim_marker.visible = true
	_aim_marker.global_position = Vector3(aim_point.x, 0.035, aim_point.z)
	_aim_marker.rotation.y = _time * 1.4
	var pulse := 1.0 + sin(_time * 6.0) * 0.08
	_aim_marker.scale = Vector3(pulse, 1.0, pulse)


func _set_aim_helpers_visible(value: bool) -> void:
	if is_instance_valid(_laser):
		_laser.visible = value
	if is_instance_valid(_aim_marker):
		_aim_marker.visible = value


func _shoot() -> void:
	_fire_cooldown = FIRE_RATE
	_muzzle_timer = 0.06
	recoil = 1.0
	if game != null:
		shoot_at(game.get_aim_point())


func shoot_at(aim_point: Vector3) -> Dictionary:
	var muzzle := get_muzzle_global()
	var direction := aim_point - muzzle
	if direction.length_squared() < 0.25:
		direction = -_model.global_transform.basis.z
	direction = direction.normalized()
	return _fire_ray(muzzle, direction)


func _fire_ray(muzzle: Vector3, direction: Vector3) -> Dictionary:
	_muzzle_timer = 0.06
	var to := muzzle + direction * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(muzzle, to, 3)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end := to
	if not hit.is_empty():
		end = hit["position"]
		var collider: Object = hit["collider"]
		if collider != null and collider.has_method("take_damage"):
			collider.take_damage(1, direction)
		if game != null:
			game.effects.impact(end, hit["normal"])
	if game != null:
		game.effects.tracer(muzzle, end)
		game.effects.directional_burst(muzzle, direction, Color(1.0, 0.78, 0.3, 0.95), 4, 5.5, 0.18, 0.05, 3.5, true)
		game.add_shake(1.15)
	Sfx.play("shoot", randf_range(0.95, 1.07), -8.0)
	return hit


func _update_feedback() -> void:
	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = _muzzle_timer > 0.0
		if _muzzle_timer > 0.0:
			var ratio := _muzzle_timer / 0.06
			_muzzle_flash.scale = Vector3.ONE * (0.7 + ratio * 0.8)
	if is_instance_valid(_muzzle_light):
		_muzzle_light.light_energy = 3.6 if _muzzle_timer > 0.0 else 0.0
	if is_instance_valid(_hurt_light):
		_hurt_light.light_energy = _flash * 2.6


func _animate(delta: float) -> void:
	if not is_instance_valid(_model) or dead:
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var running := is_on_floor() and horizontal_speed > 0.4
	if running:
		_run_phase += horizontal_speed * delta * 2.1
	var swing := sin(_run_phase) if running else 0.0
	var airborne := not is_on_floor()

	if airborne:
		_leg_left.rotation.x = lerp_angle(_leg_left.rotation.x, 0.55, minf(1.0, delta * 9.0))
		_leg_right.rotation.x = lerp_angle(_leg_right.rotation.x, -0.35, minf(1.0, delta * 9.0))
		_arm_left.rotation.x = lerp_angle(_arm_left.rotation.x, -0.4, minf(1.0, delta * 9.0))
	else:
		_leg_left.rotation.x = swing * 0.78
		_leg_right.rotation.x = -swing * 0.78
		_arm_left.rotation.x = -swing * 0.58

	_arm_right.rotation.x = 1.25 + recoil * 0.14
	_gun.position.z = -0.42 + recoil * 0.11
	var bob_target := 0.0
	if running:
		bob_target = absf(sin(_run_phase * 2.0)) * 0.03
	_model.position.y = lerpf(_model.position.y, bob_target, minf(1.0, delta * 12.0))
	if hugged:
		_model.rotation.z = sin(_time * 32.0) * 0.06
	else:
		_model.rotation.z = lerpf(_model.rotation.z, 0.0, minf(1.0, delta * 12.0))


func take_damage(amount: int, source_position: Vector3) -> void:
	if dead or _invulnerable > 0.0 or game == null or game.state != "playing":
		return
	health = maxi(0, health - amount)
	_invulnerable = 0.7
	_flash = 1.0
	var away := global_position - source_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3(1.0, 0.0, 0.0)
	velocity = away.normalized() * 6.0 + Vector3(0.0, 3.2, 0.0)
	game.on_player_hurt(amount)
	if health <= 0:
		_die()


func heal(amount: int) -> void:
	if dead:
		return
	health = mini(max_health, health + amount)


func _die() -> void:
	if dead:
		return
	dead = true
	hugged = false
	health = 0
	_invulnerable = 0.0
	_flash = 0.0
	collision_layer = 0
	collision_mask = 0
	_set_aim_helpers_visible(false)
	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = false
	if is_instance_valid(_muzzle_light):
		_muzzle_light.light_energy = 0.0
	if is_instance_valid(_hugger) and _hugger.has_method("on_host_died"):
		_hugger.on_host_died()
	_hugger = null
	game.on_player_died()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_model, "rotation:z", 1.45, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_model, "position:y", -0.35, 0.5)


func get_muzzle_global() -> Vector3:
	return _muzzle.global_position


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)

	var suit := Color(0.88, 0.52, 0.18)
	var suit_dark := Color(0.55, 0.29, 0.1)
	var armor := Color(0.11, 0.15, 0.16)
	var metal := Color(0.19, 0.24, 0.25)
	var metal_light := Color(0.4, 0.5, 0.48)
	var boot := Color(0.32, 0.18, 0.09)
	var visor := Color(0.3, 0.95, 0.95)

	MF.add_box(_model, Vector3(0.46, 0.22, 0.32), Vector3(0.0, 0.92, 0.0), suit_dark, {"metallic": 0.1, "roughness": 0.8})
	MF.add_capsule(_model, 0.28, 0.98, Vector3(0.0, 1.24, 0.0), suit, {"metallic": 0.05, "roughness": 0.7})
	MF.add_box(_model, Vector3(0.48, 0.36, 0.14), Vector3(0.0, 1.23, -0.2), armor, {"metallic": 0.35, "roughness": 0.55})
	MF.add_box(_model, Vector3(0.32, 0.1, 0.05), Vector3(0.0, 1.3, -0.285), metal_light, {"metallic": 0.6, "roughness": 0.35})
	MF.add_box(_model, Vector3(0.44, 0.08, 0.34), Vector3(0.0, 0.97, 0.0), boot, {"roughness": 0.85})
	MF.add_box(_model, Vector3(0.12, 0.07, 0.04), Vector3(0.08, 0.97, -0.18), Color(1.0, 0.72, 0.28), {
		"emission": Color(1.0, 0.6, 0.2),
		"energy": 1.3,
		"unshaded": true,
	})

	# Backpack and glowing coolant canister.
	MF.add_box(_model, Vector3(0.38, 0.5, 0.2), Vector3(0.0, 1.2, 0.26), armor, {"metallic": 0.3, "roughness": 0.6})
	MF.add_cylinder(_model, 0.075, 0.34, Vector3(0.12, 1.2, 0.39), Color(0.3, 1.0, 0.55), {
		"emission": Color(0.25, 1.0, 0.55),
		"energy": 1.8,
		"unshaded": true,
	})
	MF.add_box(_model, Vector3(0.07, 0.05, 0.05), Vector3(-0.13, 1.36, 0.38), Color(1.0, 0.45, 0.18), {
		"emission": Color(1.0, 0.4, 0.14),
		"energy": 1.5,
		"unshaded": true,
	})

	# Head and helmet.
	MF.add_sphere(_model, 0.23, Vector3(0.0, 1.68, 0.0), armor, {"metallic": 0.2, "roughness": 0.55})
	MF.add_box(_model, Vector3(0.27, 0.11, 0.07), Vector3(0.0, 1.7, -0.2), visor, {
		"emission": visor,
		"energy": 1.8,
		"unshaded": true,
	})
	MF.add_box(_model, Vector3(0.06, 0.06, 0.2), Vector3(-0.19, 1.78, 0.02), metal, {"metallic": 0.5, "roughness": 0.4})
	MF.add_sphere(_model, 0.035, Vector3(-0.19, 1.81, 0.12), Color(1.0, 0.45, 0.18), {
		"emission": Color(1.0, 0.4, 0.14),
		"energy": 1.8,
		"unshaded": true,
	})

	# Shoulder pads.
	MF.add_sphere(_model, 0.13, Vector3(-0.36, 1.42, 0.0), suit_dark, {"scale": Vector3(1.2, 0.8, 1.0)})
	MF.add_sphere(_model, 0.13, Vector3(0.36, 1.42, 0.0), suit_dark, {"scale": Vector3(1.2, 0.8, 1.0)})

	_leg_left = Node3D.new()
	_leg_left.position = Vector3(-0.16, 0.92, 0.0)
	_model.add_child(_leg_left)
	_build_leg(_leg_left, boot)
	_leg_right = Node3D.new()
	_leg_right.position = Vector3(0.16, 0.92, 0.0)
	_model.add_child(_leg_right)
	_build_leg(_leg_right, boot)

	_arm_left = Node3D.new()
	_arm_left.position = Vector3(-0.37, 1.4, 0.0)
	_model.add_child(_arm_left)
	_build_arm(_arm_left, suit, armor)

	_arm_right = Node3D.new()
	_arm_right.position = Vector3(0.37, 1.4, 0.0)
	_arm_right.rotation.x = 1.25
	_model.add_child(_arm_right)
	_build_arm(_arm_right, suit, armor)

	_gun = Node3D.new()
	_gun.position = Vector3(0.32, 1.16, -0.42)
	_model.add_child(_gun)
	MF.add_box(_gun, Vector3(0.13, 0.15, 0.5), Vector3(0.0, 0.0, -0.04), metal, {"metallic": 0.55, "roughness": 0.4})
	MF.add_box(_gun, Vector3(0.1, 0.05, 0.34), Vector3(0.0, 0.09, -0.1), metal_light, {"metallic": 0.6, "roughness": 0.35})
	MF.add_cylinder(_gun, 0.038, 0.3, Vector3(0.0, 0.02, -0.38), Color(0.1, 0.13, 0.14), {"rotation": Vector3(PI * 0.5, 0.0, 0.0), "metallic": 0.6, "roughness": 0.3})
	MF.add_box(_gun, Vector3(0.09, 0.19, 0.12), Vector3(0.0, -0.14, -0.08), armor, {"rotation": Vector3(-0.2, 0.0, 0.0)})
	MF.add_box(_gun, Vector3(0.06, 0.08, 0.06), Vector3(0.0, 0.06, 0.1), Color(0.3, 1.0, 0.55), {
		"emission": Color(0.25, 1.0, 0.55),
		"energy": 1.7,
		"unshaded": true,
	})

	_muzzle = Marker3D.new()
	_muzzle.position = Vector3(0.0, 0.02, -0.56)
	_gun.add_child(_muzzle)

	_muzzle_flash = MF.add_sphere(_gun, 0.09, Vector3(0.0, 0.02, -0.58), Color(1.0, 0.9, 0.5), {
		"emission": Color(1.0, 0.8, 0.3),
		"energy": 4.0,
		"unshaded": true,
		"cast_shadow": GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
	})
	_muzzle_flash.visible = false

	_muzzle_light = OmniLight3D.new()
	_muzzle_light.position = Vector3(0.0, 0.02, -0.6)
	_muzzle_light.light_color = Color(1.0, 0.78, 0.35)
	_muzzle_light.light_energy = 0.0
	_muzzle_light.omni_range = 4.0
	_muzzle_light.shadow_enabled = false
	_gun.add_child(_muzzle_light)

	_hurt_light = OmniLight3D.new()
	_hurt_light.position = Vector3(0.0, 1.1, 0.0)
	_hurt_light.light_color = Color(1.0, 0.08, 0.06)
	_hurt_light.light_energy = 0.0
	_hurt_light.omni_range = 5.0
	_hurt_light.shadow_enabled = false
	add_child(_hurt_light)


func _build_leg(parent: Node3D, boot_color: Color) -> void:
	MF.add_box(parent, Vector3(0.16, 0.4, 0.18), Vector3(0.0, -0.2, 0.0), Color(0.14, 0.18, 0.19), {"metallic": 0.2, "roughness": 0.65})
	MF.add_box(parent, Vector3(0.14, 0.4, 0.16), Vector3(0.0, -0.56, 0.0), Color(0.12, 0.16, 0.17), {"metallic": 0.25, "roughness": 0.6})
	MF.add_box(parent, Vector3(0.17, 0.14, 0.3), Vector3(0.0, -0.82, -0.04), boot_color, {"metallic": 0.15, "roughness": 0.75})


func _build_arm(parent: Node3D, suit_color: Color, armor_color: Color) -> void:
	MF.add_box(parent, Vector3(0.13, 0.36, 0.15), Vector3(0.0, -0.18, 0.0), suit_color, {"roughness": 0.7})
	MF.add_box(parent, Vector3(0.12, 0.32, 0.14), Vector3(0.0, -0.46, 0.0), armor_color, {"metallic": 0.2, "roughness": 0.6})
	MF.add_sphere(parent, 0.075, Vector3(0.0, -0.64, 0.0), armor_color, {"metallic": 0.2, "roughness": 0.6})


func _build_aim_helpers() -> void:
	_laser_material = MF.make_material(
		Color(1.0, 0.66, 0.24, 0.45),
		0.0,
		1.0,
		Color(1.0, 0.6, 0.2),
		2.4,
		true,
		true
	)
	var laser_mesh := BoxMesh.new()
	laser_mesh.size = Vector3(0.025, 0.025, 1.0)
	laser_mesh.material = _laser_material
	_laser = MeshInstance3D.new()
	_laser.mesh = laser_mesh
	_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_laser.visible = false
	game.add_child(_laser)

	_marker_material = MF.make_material(
		Color(1.0, 0.66, 0.24, 0.6),
		0.0,
		1.0,
		Color(1.0, 0.58, 0.18),
		2.8,
		true,
		true
	)
	var marker_mesh := TorusMesh.new()
	marker_mesh.inner_radius = 0.23
	marker_mesh.outer_radius = 0.32
	marker_mesh.rings = 28
	marker_mesh.ring_segments = 5
	marker_mesh.material = _marker_material
	_aim_marker = MeshInstance3D.new()
	_aim_marker.mesh = marker_mesh
	_aim_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aim_marker.visible = false
	game.add_child(_aim_marker)
