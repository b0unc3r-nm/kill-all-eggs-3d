extends CharacterBody3D

## Facehugger: a fast skittering enemy that leaps at the player's face.
## While attached it must be torn off by mashing jump before the infection completes.

const MF = preload("res://scripts/mesh_factory.gd")

const GRAVITY := 24.0
const ATTACH_REACH := 0.95
const ATTACH_DURATION := 4.0

var game: Node
var hp := 2
var max_hp := 2
var speed := 6.2
var contact_damage := 6
var score_value := 80
var attached := false

var _time := 0.0
var _flash := 0.0
var _dead := false
var _launch_direction := Vector3.FORWARD
var _attach_cooldown := 1.0
var _leap_cooldown := 0.0
var _leap_anim := 0.0

var _model: Node3D
var _body_material: StandardMaterial3D
var _flesh_materials: Array[StandardMaterial3D] = []
var _base_emission := Color(0.0, 0.0, 0.0)
var _legs: Array[Node3D] = []
var _leg_sides: Array[float] = []
var _leg_phases: Array[float] = []
var _tail: Array[Node3D] = []
var _health_bar: Node3D
var _health_fill: MeshInstance3D
var _health_material: StandardMaterial3D
var _ground_ring: MeshInstance3D
var _ground_ring_material: StandardMaterial3D
var _ground_ring_color := Color(1.0, 0.62, 0.2, 0.26)


func setup(new_game: Node, wave_number: int, direction: Vector3) -> void:
	game = new_game
	_launch_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector3.FORWARD
	max_hp = clampi(2 + int((wave_number - 1) / 4), 2, 4)
	hp = max_hp
	speed = 5.8 + minf(float(wave_number) * 0.16, 1.8)
	contact_damage = 5 + mini(wave_number, 4)
	score_value = 80 + wave_number * 10


func _ready() -> void:
	add_to_group("facehuggers")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.2
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	collision.shape = sphere
	collision.position = Vector3(0.0, 0.3, 0.0)
	add_child(collision)
	_build_model()
	_attach_cooldown = randf_range(0.45, 0.9)
	velocity = _launch_direction * randf_range(1.4, 2.4) + Vector3(0.0, 2.0, 0.0)


func _physics_process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 8.0)
	_attach_cooldown = maxf(0.0, _attach_cooldown - delta)
	_leap_cooldown = maxf(0.0, _leap_cooldown - delta)
	_leap_anim = maxf(0.0, _leap_anim - delta)

	if _dead:
		return
	if attached:
		_update_attached(delta)
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var player = null
	if game != null and is_instance_valid(game.player):
		player = game.player

	if game == null or game.state != "playing" or player == null or player.dead or player.hugged:
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
		move_and_slide()
		_update_visuals(delta)
		_update_health_bar()
		return

	var to_player: Vector3 = player.global_position - global_position
	var flat := Vector3(to_player.x, 0.0, to_player.z)
	var distance := flat.length()
	var direction := flat.normalized() if distance > 0.01 else Vector3.FORWARD

	var separation := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("facehuggers"):
		if other == self or not is_instance_valid(other) or other.attached:
			continue
		var away: Vector3 = global_position - other.global_position
		away.y = 0.0
		var away_distance := away.length()
		if away_distance > 0.01 and away_distance < 0.72:
			separation += away / away_distance * (0.72 - away_distance) * 2.2

	var desired := direction
	if separation.length_squared() > 0.001:
		desired = (direction + separation).normalized()

	var target_speed := speed
	if distance < 1.2:
		target_speed *= 0.8

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(desired * target_speed, 30.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if flat.length_squared() > 0.01:
		var target_yaw := atan2(-direction.x, -direction.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-delta * 16.0))

	if is_on_floor() and _leap_cooldown <= 0.0 and distance < 7.5:
		velocity.y = 7.6
		velocity.x += direction.x * speed * 0.85
		velocity.z += direction.z * speed * 0.85
		_leap_cooldown = randf_range(1.1, 1.9)
		_leap_anim = 0.3
		Sfx.play("hug_screech", randf_range(0.9, 1.12), -10.0)

	if _attach_cooldown <= 0.0 and distance < ATTACH_REACH and absf(to_player.y) < 1.7:
		if player.attach_facehugger(self):
			_attach()
			return
		_attach_cooldown = 1.5

	move_and_slide()
	_update_visuals(delta)
	_update_health_bar()


func _attach() -> void:
	attached = true
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	_attach_cooldown = 999.0
	if is_instance_valid(_health_bar):
		_health_bar.visible = false
	if is_instance_valid(_ground_ring):
		_ground_ring.visible = false
	if game != null:
		game.add_shake(4.0)
	Sfx.play("hug_screech", randf_range(0.82, 0.94), -6.0)


func _update_attached(delta: float) -> void:
	var player = null
	if game != null and is_instance_valid(game.player):
		player = game.player
	if player == null or not player.hugged:
		_knocked_off()
		return

	var head: Vector3 = player.global_position + Vector3(0.0, 1.58, 0.0)
	var forward: Vector3 = player.aim_direction
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	var target := head + forward * 0.24
	global_position = global_position.lerp(target, 1.0 - exp(-delta * 30.0))
	var target_yaw := atan2(-forward.x, -forward.z) + PI
	_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-delta * 20.0))
	_update_visuals(delta)
	_model.position.y += sin(_time * 24.0) * 0.035
	_model.rotation.z = sin(_time * 17.0) * 0.14


func _knocked_off() -> void:
	attached = false
	if _dead:
		return
	_dead = true
	remove_from_group("facehuggers")
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	queue_free()


func on_host_died() -> void:
	attached = false
	if _dead:
		return
	_dead = true
	remove_from_group("facehuggers")
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	queue_free()


func on_host_infected() -> void:
	on_host_died()


func deflect() -> void:
	if _dead:
		return
	_dead = true
	attached = false
	remove_from_group("facehuggers")
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	if is_instance_valid(_health_bar):
		_health_bar.visible = false
	if is_instance_valid(_ground_ring):
		_ground_ring.visible = false
	if game != null:
		game.on_facehugger_deflected(global_position, score_value + 50)
	Sfx.play("hug_escape", 1.0, -4.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_model, "position", Vector3(0.0, 2.2, 1.4), 0.4)
	tween.tween_property(_model, "rotation:z", 2.4, 0.4)
	tween.chain().tween_callback(queue_free)


func _update_visuals(delta: float) -> void:
	if not is_instance_valid(_model):
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var stride := clampf(horizontal_speed / 5.0, 0.0, 1.0)
	if not is_on_floor():
		stride *= 0.5
	var gait_speed := 14.0 + horizontal_speed * 1.8
	for i in _legs.size():
		var leg := _legs[i]
		var phase := _time * gait_speed + _leg_phases[i]
		leg.rotation.x = sin(phase) * 0.55 * stride
		leg.rotation.z = -_leg_sides[i] * 0.3 + maxf(0.0, sin(phase)) * 0.16 * stride

	for i in _tail.size():
		var segment := _tail[i]
		segment.rotation.y = sin(_time * 7.0 - float(i) * 0.7) * 0.22
		segment.rotation.x = 0.06 + sin(_time * 5.0 - float(i) * 0.5) * 0.1

	var bob := 0.0
	if is_on_floor():
		bob = sin(_time * 16.0) * 0.02 * stride
	_model.position.y = lerpf(_model.position.y, bob, minf(1.0, delta * 16.0))

	if _leap_anim > 0.0:
		var stretch := sin((1.0 - _leap_anim / 0.3) * PI)
		_model.scale = Vector3(1.0 + stretch * 0.12, 1.0 - stretch * 0.16, 1.0 + stretch * 0.22)
	else:
		_model.scale = _model.scale.lerp(Vector3.ONE, minf(1.0, delta * 10.0))

	for material in _flesh_materials:
		material.emission = Color.WHITE if _flash > 0.0 else _base_emission
		material.emission_energy_multiplier = 0.1 + _flash * 2.4

	if is_instance_valid(_ground_ring):
		var ring_pulse := 0.5 + 0.5 * sin(_time * 6.0 + _leg_phases[0])
		_ground_ring_material.albedo_color = Color(
			_ground_ring_color.r,
			_ground_ring_color.g,
			_ground_ring_color.b,
			_ground_ring_color.a + ring_pulse * 0.1
		)
		_ground_ring_material.emission_energy_multiplier = 0.7 + ring_pulse * 0.6
		var ring_scale := 1.0 + ring_pulse * 0.07
		_ground_ring.scale = Vector3(ring_scale, 1.0, ring_scale)


func _update_health_bar() -> void:
	if not is_instance_valid(_health_bar):
		return
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_health_bar.visible = hp < max_hp and not _dead and not attached
	_health_fill.scale.x = maxf(0.001, ratio)
	_health_fill.position.x = -0.32 + 0.32 * ratio
	_health_material.albedo_color = Color(1.0, 0.8, 0.4, 0.95)
	_health_material.emission = Color(1.0, 0.65, 0.25)
	_health_material.emission_energy_multiplier = 1.6


func take_damage(amount: int, direction: Vector3) -> void:
	if _dead or attached:
		return
	hp -= amount
	_flash = 1.0
	var knockback := Vector3(direction.x, 0.0, direction.z)
	if knockback.length_squared() < 0.001:
		knockback = Vector3.FORWARD
	velocity += knockback.normalized() * 2.4 + Vector3(0.0, 1.0, 0.0)
	if hp <= 0:
		_die()
	else:
		if game != null:
			game.hud.on_hit()
			game.effects.burst(global_position + Vector3(0.0, 0.32, 0.0), Color(0.95, 0.75, 0.35, 0.85), 9, 3.4, 0.38, 0.06, 8.0)
		Sfx.play("hit", randf_range(0.95, 1.15), -7.0)
	_update_health_bar()


func _die() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("facehuggers")
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	if is_instance_valid(_health_bar):
		_health_bar.visible = false
	if is_instance_valid(_ground_ring):
		_ground_ring.visible = false
	if game != null:
		game.on_facehugger_killed(global_position, score_value)
	Sfx.play("kill", randf_range(0.98, 1.15), -5.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_model, "scale", Vector3(1.25, 0.14, 1.25), 0.3)
	tween.tween_property(_model, "rotation:z", 0.8, 0.3)
	tween.chain().tween_callback(queue_free)


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)

	var body_color := Color(0.62, 0.52, 0.34)
	var highlight_color := Color(0.78, 0.68, 0.45)
	var leg_color := Color(0.34, 0.26, 0.15)
	var eye_color := Color(1.0, 0.55, 0.15)
	_base_emission = Color(0.16, 0.1, 0.03)

	_body_material = MF.make_material(body_color, 0.0, 0.68, _base_emission, 0.1)
	var highlight_material := MF.make_material(highlight_color, 0.0, 0.6, _base_emission, 0.1)
	_flesh_materials.append(_body_material)
	_flesh_materials.append(highlight_material)

	MF.add_sphere(_model, 0.3, Vector3(0.0, 0.34, 0.0), body_color, {
		"scale": Vector3(1.25, 0.6, 1.0),
		"material": _body_material,
		"segments": 20,
		"rings": 10,
	})
	MF.add_sphere(_model, 0.2, Vector3(0.0, 0.42, 0.14), highlight_color, {
		"scale": Vector3(1.1, 0.65, 1.1),
		"material": highlight_material,
	})
	MF.add_sphere(_model, 0.17, Vector3(0.0, 0.3, -0.3), highlight_color, {
		"scale": Vector3(1.1, 0.75, 1.0),
		"material": highlight_material,
	})
	MF.add_sphere(_model, 0.1, Vector3(0.0, 0.27, -0.42), body_color, {
		"scale": Vector3(1.2, 0.7, 0.8),
		"material": _body_material,
	})

	var eye_material := MF.make_material(eye_color, 0.0, 1.0, eye_color, 2.4, true)
	for side in [-1.0, 1.0]:
		MF.add_sphere(_model, 0.045, Vector3(side * 0.075, 0.33, -0.47), eye_color, {"material": eye_material})
		MF.add_sphere(_model, 0.07, Vector3(side * 0.075, 0.33, -0.46), eye_color, {
			"material": MF.make_material(Color(eye_color.r, eye_color.g, eye_color.b, 0.14), 0.0, 1.0, eye_color, 1.0, true, true),
		})

	# Curled finger-like appendages around the mouth.
	for side in [-1.0, 1.0]:
		for i in 2:
			var finger := Node3D.new()
			finger.position = Vector3(side * (0.08 + float(i) * 0.07), 0.28, -0.42)
			_model.add_child(finger)
			MF.add_box(finger, Vector3(0.035, 0.035, 0.26), Vector3(0.0, -0.02, -0.12), leg_color, {
				"rotation": Vector3(-0.35 - float(i) * 0.25, 0.0, 0.0),
			})
			MF.add_cone(finger, 0.028, 0.1, Vector3(0.0, -0.08, -0.25), leg_color, {
				"rotation": Vector3(-PI * 0.5 - 0.35, 0.0, 0.0),
			})

	var leg_material := MF.make_material(leg_color, 0.0, 0.72)
	for side_variant in [-1.0, 1.0]:
		var side: float = side_variant
		for i in 3:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 0.2, 0.34, -0.14 + float(i) * 0.16)
			_model.add_child(pivot)
			MF.add_box(pivot, Vector3(0.38, 0.05, 0.05), Vector3(side * 0.19, 0.0, 0.0), leg_color, {"material": leg_material})
			MF.add_box(pivot, Vector3(0.05, 0.36, 0.05), Vector3(side * 0.37, -0.17, 0.0), leg_color, {"material": leg_material})
			MF.add_sphere(pivot, 0.04, Vector3(side * 0.37, -0.35, 0.0), leg_color, {"material": leg_material})
			pivot.rotation.z = -side * 0.3
			_legs.append(pivot)
			_leg_sides.append(side)
			_leg_phases.append(float(i) * 2.1 + (0.0 if side < 0.0 else PI))

	# Long segmented tail.
	var tail_material := MF.make_material(leg_color.lightened(0.05), 0.0, 0.7)
	var tail_segments: Array[Node3D] = []
	var parent: Node3D = _model
	for i in 4:
		var segment := Node3D.new()
		segment.position = Vector3(0.0, 0.38 if i == 0 else 0.0, 0.22 if i == 0 else 0.25)
		parent.add_child(segment)
		tail_segments.append(segment)
		parent = segment
		var width := 0.08 - float(i) * 0.012
		MF.add_box(segment, Vector3(width, width, 0.28), Vector3(0.0, 0.0, 0.14), leg_color, {"material": tail_material})
		if i == 3:
			MF.add_cone(segment, 0.045, 0.18, Vector3(0.0, 0.0, 0.36), leg_color, {
				"rotation": Vector3(PI * 0.5, 0.0, 0.0),
				"material": tail_material,
			})
	_tail = tail_segments

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
	ring_mesh.inner_radius = 0.4
	ring_mesh.outer_radius = 0.5
	ring_mesh.rings = 28
	ring_mesh.ring_segments = 5
	ring_mesh.material = _ground_ring_material
	_ground_ring = MeshInstance3D.new()
	_ground_ring.mesh = ring_mesh
	_ground_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground_ring.position = Vector3(0.0, 0.04, 0.0)
	_model.add_child(_ground_ring)

	_health_bar = Node3D.new()
	_health_bar.position = Vector3(0.0, 0.95, 0.0)
	add_child(_health_bar)
	var bg_material := MF.make_material(Color(0.01, 0.02, 0.022, 0.9), 0.0, 1.0, Color(0.0, 0.0, 0.0), 0.0, true, true, true)
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(0.7, 0.1)
	bg_mesh.material = bg_material
	var bg := MeshInstance3D.new()
	bg.mesh = bg_mesh
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_health_bar.add_child(bg)

	_health_material = MF.make_material(Color(1.0, 0.8, 0.4, 0.95), 0.0, 1.0, Color(1.0, 0.65, 0.25), 1.6, true, true, true)
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(0.64, 0.05)
	fill_mesh.material = _health_material
	_health_fill = MeshInstance3D.new()
	_health_fill.mesh = fill_mesh
	_health_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_health_fill.position = Vector3(0.0, 0.0, -0.01)
	_health_bar.add_child(_health_fill)
	_health_bar.visible = false
