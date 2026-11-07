extends CharacterBody3D

const MF = preload("res://scripts/mesh_factory.gd")

const GRAVITY := 22.0

var game: Node
var unborn := false
var body_scale := 1.0
var hp := 3
var max_hp := 3
var speed := 4.2
var jump_force := 6.0
var contact_damage := 10
var score_value := 100

var _time := 0.0
var _flash := 0.0
var _attack_cooldown := 0.0
var _attack_anim := 0.0
var _jump_cooldown := 0.0
var _dead := false
var _launch_direction := Vector3.FORWARD

var _model: Node3D
var _body_material: StandardMaterial3D
var _highlight_material: StandardMaterial3D
var _flesh_materials: Array[StandardMaterial3D] = []
var _base_emission := Color(0.0, 0.0, 0.0)
var _legs: Array[Node3D] = []
var _leg_sides: Array[float] = []
var _leg_phases: Array[float] = []
var _claws: Array[Node3D] = []
var _health_bar: Node3D
var _health_fill: MeshInstance3D
var _health_material: StandardMaterial3D
var _ground_ring: MeshInstance3D
var _ground_ring_material: StandardMaterial3D
var _ground_ring_color := Color(1.0, 0.3, 0.24, 0.26)


func setup(new_game: Node, is_unborn: bool, wave_number: int, direction: Vector3) -> void:
	game = new_game
	unborn = is_unborn
	_launch_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector3.FORWARD
	if unborn:
		body_scale = 0.62
		max_hp = 1
		speed = randf_range(5.0, 5.6)
		jump_force = 5.2
		contact_damage = 4
		score_value = 40
	else:
		body_scale = 1.0
		max_hp = clampi(3 + int((wave_number - 1) / 4), 3, 7)
		speed = 4.0 + minf(float(wave_number) * 0.18, 1.6)
		jump_force = 6.0 + minf(float(wave_number) * 0.1, 1.2)
		contact_damage = 10 + mini(wave_number, 5)
		score_value = 100 + wave_number * 10
	hp = max_hp


func _ready() -> void:
	add_to_group("headcrabs")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.25
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.42 * body_scale
	collision.shape = sphere
	collision.position = Vector3(0.0, 0.42 * body_scale, 0.0)
	add_child(collision)
	_build_model()
	_jump_cooldown = randf_range(0.3, 0.9)
	_attack_cooldown = randf_range(0.1, 0.4)
	velocity = _launch_direction * randf_range(1.2, 2.8) + Vector3(0.0, 1.5, 0.0)


func _physics_process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 8.0)
	_attack_anim = maxf(0.0, _attack_anim - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_jump_cooldown -= delta

	if _dead:
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var player = null
	if game != null and is_instance_valid(game.player):
		player = game.player

	if game == null or game.state != "playing" or player == null or player.dead:
		velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
		move_and_slide()
		_update_visuals(delta)
		_update_health_bar()
		return

	var to_player: Vector3 = player.global_position - global_position
	var flat := Vector3(to_player.x, 0.0, to_player.z)
	var distance := flat.length()
	var direction := flat.normalized() if distance > 0.01 else Vector3.FORWARD

	var separation := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("headcrabs"):
		if other == self or not is_instance_valid(other):
			continue
		var away: Vector3 = global_position - other.global_position
		away.y = 0.0
		var away_distance := away.length()
		var minimum := 0.78 * (body_scale + float(other.body_scale))
		if away_distance > 0.01 and away_distance < minimum:
			separation += away / away_distance * (minimum - away_distance) * 2.0

	var desired := direction
	if separation.length_squared() > 0.001:
		desired = (direction + separation).normalized()

	var target_speed := speed
	if distance < 1.5 * body_scale + 0.5:
		target_speed *= 0.45

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(desired * target_speed, 22.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if flat.length_squared() > 0.01:
		var target_yaw := atan2(-direction.x, -direction.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-delta * 12.0))

	if is_on_floor() and _jump_cooldown <= 0.0:
		if distance < 9.0 or randf() < 0.22:
			velocity.y = jump_force
			velocity.x += direction.x * speed * 0.35
			velocity.z += direction.z * speed * 0.35
			_jump_cooldown = randf_range(1.1, 2.2)
			if unborn:
				_jump_cooldown *= 0.8

	var contact_reach := 0.55 * body_scale + 0.5
	if _attack_cooldown <= 0.0 and distance < contact_reach and absf(to_player.y) < 1.3:
		_attack_cooldown = 0.85 if unborn else 1.0
		_attack_anim = 0.22
		player.take_damage(contact_damage, global_position)
		velocity.x += direction.x * 3.0
		velocity.z += direction.z * 3.0

	move_and_slide()
	_update_visuals(delta)
	_update_health_bar()


func _update_visuals(delta: float) -> void:
	if not is_instance_valid(_model):
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var stride := clampf(horizontal_speed / 4.0, 0.0, 1.0)
	if not is_on_floor():
		stride *= 0.4
	var gait_speed := 8.0 + horizontal_speed * 1.2
	for i in _legs.size():
		var leg := _legs[i]
		var phase := _time * gait_speed + _leg_phases[i]
		leg.rotation.x = sin(phase) * 0.45 * stride
		leg.rotation.z = -_leg_sides[i] * 0.18 + maxf(0.0, sin(phase)) * 0.18 * stride

	var attack_progress := 0.0
	if _attack_anim > 0.0:
		attack_progress = sin((1.0 - _attack_anim / 0.22) * PI)
	for claw in _claws:
		claw.rotation.x = -attack_progress * 0.7

	var bob := 0.0
	if is_on_floor():
		bob = sin(_time * 10.0) * 0.018 * stride
	_model.position.y = lerpf(_model.position.y, bob, minf(1.0, delta * 14.0))
	_model.position.z = lerpf(_model.position.z, -attack_progress * 0.14, minf(1.0, delta * 16.0))

	var flash_energy := _flash * 2.6
	for material in _flesh_materials:
		material.emission = Color.WHITE if _flash > 0.0 else _base_emission
		material.emission_energy_multiplier = 0.12 + flash_energy

	if is_instance_valid(_ground_ring):
		var ring_pulse := 0.5 + 0.5 * sin(_time * 4.2 + _leg_phases[0])
		_ground_ring_material.albedo_color = Color(
			_ground_ring_color.r,
			_ground_ring_color.g,
			_ground_ring_color.b,
			_ground_ring_color.a + ring_pulse * 0.1
		)
		_ground_ring_material.emission_energy_multiplier = 0.7 + ring_pulse * 0.5
		var ring_scale := 1.0 + ring_pulse * 0.06
		_ground_ring.scale = Vector3(ring_scale, 1.0, ring_scale)


func _update_health_bar() -> void:
	if not is_instance_valid(_health_bar):
		return
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_health_bar.visible = hp < max_hp and not _dead
	_health_fill.scale.x = maxf(0.001, ratio)
	_health_fill.position.x = -0.42 + 0.42 * ratio
	_health_material.albedo_color = Color(0.62, 1.0, 0.5, 0.95)
	_health_material.emission = Color(0.5, 1.0, 0.4)
	_health_material.emission_energy_multiplier = 1.6


func take_damage(amount: int, direction: Vector3) -> void:
	if _dead:
		return
	hp -= amount
	_flash = 1.0
	var knockback := Vector3(direction.x, 0.0, direction.z)
	if knockback.length_squared() < 0.001:
		knockback = Vector3.FORWARD
	velocity += knockback.normalized() * 2.8 + Vector3(0.0, 1.1, 0.0)
	if hp <= 0:
		_die()
	else:
		if game != null:
			game.hud.on_hit()
			game.effects.burst(global_position + Vector3(0.0, 0.45 * body_scale, 0.0), Color(0.7, 0.2, 0.3, 0.85), 9, 3.4, 0.38, 0.06, 8.0)
		Sfx.play("hit", randf_range(0.92, 1.12), -7.0)
	_update_health_bar()


func _die() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("headcrabs")
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	if is_instance_valid(_health_bar):
		_health_bar.visible = false
	if is_instance_valid(_ground_ring):
		_ground_ring.visible = false
	if game != null:
		game.on_crab_killed(global_position, unborn, score_value)
	Sfx.play("kill", randf_range(0.9, 1.08), -5.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_model, "scale", Vector3(body_scale * 1.25, body_scale * 0.14, body_scale * 1.25), 0.3)
	tween.tween_property(_model, "rotation:z", 0.7, 0.3)
	tween.chain().tween_callback(queue_free)


func _build_model() -> void:
	_model = Node3D.new()
	_model.scale = Vector3.ONE * body_scale
	add_child(_model)

	var body_color := Color(0.42, 0.11, 0.16) if not unborn else Color(0.3, 0.5, 0.22)
	var highlight_color := Color(0.68, 0.2, 0.28) if not unborn else Color(0.52, 0.72, 0.34)
	var leg_color := Color(0.18, 0.055, 0.09) if not unborn else Color(0.14, 0.22, 0.12)
	var eye_color := Color(1.0, 0.66, 0.16) if not unborn else Color(0.7, 1.0, 0.32)
	_base_emission = Color(0.22, 0.02, 0.035) if not unborn else Color(0.09, 0.2, 0.05)
	_ground_ring_color = Color(1.0, 0.3, 0.24, 0.26) if not unborn else Color(0.58, 1.0, 0.36, 0.24)

	_body_material = MF.make_material(body_color, 0.0, 0.62, _base_emission, 0.08)
	_highlight_material = MF.make_material(highlight_color, 0.0, 0.58, _base_emission, 0.08)
	_flesh_materials.append(_body_material)
	_flesh_materials.append(_highlight_material)

	MF.add_sphere(_model, 0.5, Vector3(0.0, 0.44, 0.0), body_color, {
		"scale": Vector3(1.15, 0.55, 0.85),
		"material": _body_material,
		"segments": 22,
		"rings": 12,
	})
	MF.add_sphere(_model, 0.34, Vector3(-0.08, 0.55, 0.08), highlight_color, {
		"scale": Vector3(1.1, 0.5, 0.85),
		"material": _highlight_material,
	})
	MF.add_sphere(_model, 0.27, Vector3(0.0, 0.42, -0.42), highlight_color, {
		"material": _highlight_material,
		"segments": 18,
		"rings": 10,
	})
	MF.add_sphere(_model, 0.13, Vector3(0.0, 0.33, -0.62), Color(0.06, 0.015, 0.02), {"roughness": 0.7})
	MF.add_cone(_model, 0.16, 0.3, Vector3(0.0, 0.34, -0.67), body_color, {
		"rotation": Vector3(-PI * 0.5, 0.0, 0.0),
		"roughness": 0.6,
	})
	for i in 3:
		MF.add_cone(_model, 0.055, 0.12, Vector3(-0.08 + float(i) * 0.08, 0.68, 0.16 - float(i) * 0.1), body_color, {
			"rotation": Vector3(0.35, 0.0, 0.0),
			"roughness": 0.65,
		})

	var eye_material := MF.make_material(eye_color, 0.0, 1.0, eye_color, 2.6, true)
	for side in [-1.0, 1.0]:
		MF.add_sphere(_model, 0.05, Vector3(side * 0.12, 0.51, -0.57), eye_color, {"material": eye_material})
		MF.add_sphere(_model, 0.085, Vector3(side * 0.12, 0.51, -0.56), eye_color, {
			"material": MF.make_material(Color(eye_color.r, eye_color.g, eye_color.b, 0.14), 0.0, 1.0, eye_color, 1.2, true, true),
		})

	var leg_material := MF.make_material(leg_color, 0.0, 0.7)
	for side_variant in [-1.0, 1.0]:
		var side: float = side_variant
		for i in 3:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 0.32, 0.42, -0.22 + float(i) * 0.22)
			_model.add_child(pivot)
			MF.add_box(pivot, Vector3(0.52, 0.06, 0.06), Vector3(side * 0.24, 0.0, 0.0), leg_color, {"material": leg_material})
			MF.add_box(pivot, Vector3(0.06, 0.38, 0.06), Vector3(side * 0.46, -0.19, 0.0), leg_color, {"material": leg_material})
			MF.add_sphere(pivot, 0.045, Vector3(side * 0.46, -0.39, 0.0), leg_color, {"material": leg_material})
			pivot.rotation.z = -side * 0.18
			_legs.append(pivot)
			_leg_sides.append(side)
			_leg_phases.append(float(i) * 2.1 + (0.0 if side < 0.0 else PI))

	var claw_material := MF.make_material(leg_color.lightened(0.06), 0.0, 0.65)
	for side in [-1.0, 1.0]:
		var claw := Node3D.new()
		claw.position = Vector3(side * 0.28, 0.38, -0.42)
		_model.add_child(claw)
		MF.add_box(claw, Vector3(0.075, 0.075, 0.4), Vector3(0.0, 0.0, -0.2), leg_color, {"material": claw_material})
		MF.add_box(claw, Vector3(0.06, 0.06, 0.28), Vector3(side * 0.06, -0.09, -0.48), leg_color, {
			"rotation": Vector3(0.35, 0.0, 0.0),
			"material": claw_material,
		})
		MF.add_cone(claw, 0.045, 0.14, Vector3(side * 0.08, -0.14, -0.63), leg_color, {
			"rotation": Vector3(-PI * 0.5, 0.0, 0.0),
			"material": claw_material,
		})
		_claws.append(claw)

	_ground_ring_material = MF.make_material(
		_ground_ring_color,
		0.0,
		1.0,
		Color(_ground_ring_color.r, _ground_ring_color.g, _ground_ring_color.b),
		0.8,
		true,
		true
	)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.56
	ring_mesh.outer_radius = 0.66
	ring_mesh.rings = 30
	ring_mesh.ring_segments = 5
	ring_mesh.material = _ground_ring_material
	_ground_ring = MeshInstance3D.new()
	_ground_ring.mesh = ring_mesh
	_ground_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground_ring.position = Vector3(0.0, 0.04, 0.0)
	_model.add_child(_ground_ring)

	_health_bar = Node3D.new()
	_health_bar.position = Vector3(0.0, 1.18 * body_scale, 0.0)
	_health_bar.scale = Vector3.ONE * body_scale
	add_child(_health_bar)
	var bg_material := MF.make_material(Color(0.01, 0.02, 0.022, 0.9), 0.0, 1.0, Color(0.0, 0.0, 0.0), 0.0, true, true, true)
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(0.9, 0.11)
	bg_mesh.material = bg_material
	var bg := MeshInstance3D.new()
	bg.mesh = bg_mesh
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_health_bar.add_child(bg)

	_health_material = MF.make_material(Color(0.62, 1.0, 0.5, 0.95), 0.0, 1.0, Color(0.5, 1.0, 0.4), 1.6, true, true, true)
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(0.84, 0.055)
	fill_mesh.material = _health_material
	_health_fill = MeshInstance3D.new()
	_health_fill.mesh = fill_mesh
	_health_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_health_fill.position = Vector3(0.0, 0.0, -0.01)
	_health_bar.add_child(_health_fill)
	_health_bar.visible = false
