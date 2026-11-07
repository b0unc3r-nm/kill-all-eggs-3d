extends Node3D

## Lightweight 3D particle bursts, tracers, shockwave rings and floating score text.

const MF = preload("res://scripts/mesh_factory.gd")

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func burst(
	position: Vector3,
	color: Color,
	count: int = 10,
	speed: float = 4.0,
	lifetime: float = 0.45,
	size: float = 0.08,
	gravity: float = 8.0,
	direction: Vector3 = Vector3.ZERO,
	spread: float = 180.0,
	spark: bool = false
) -> void:
	if count <= 0:
		return
	var particles := CPUParticles3D.new()
	particles.amount = count
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.45
	particles.direction = direction.normalized() if direction.length_squared() > 0.001 else Vector3.UP
	particles.spread = spread
	particles.initial_velocity_min = speed * 0.3
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0.0, -gravity, 0.0)
	particles.scale_amount_min = 0.55
	particles.scale_amount_max = 1.35
	particles.color = Color.WHITE

	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	particles.color_ramp = gradient

	var mesh: Mesh
	if spark:
		var box := BoxMesh.new()
		box.size = Vector3(size * 0.45, size * 2.4, size * 0.45)
		mesh = box
	else:
		var sphere := SphereMesh.new()
		sphere.radius = size
		sphere.height = size * 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
		mesh = sphere

	var material := MF.make_material(
		Color.WHITE,
		0.0,
		1.0,
		Color(0.0, 0.0, 0.0),
		0.0,
		true,
		true,
		false,
		true
	)
	mesh.material = material
	particles.mesh = mesh
	particles.position = position
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(lifetime + 0.3).timeout.connect(particles.queue_free)


func directional_burst(
	position: Vector3,
	direction: Vector3,
	color: Color,
	count: int = 8,
	speed: float = 4.5,
	lifetime: float = 0.35,
	size: float = 0.07,
	gravity: float = 6.0,
	spark: bool = true
) -> void:
	burst(position, color, count, speed, lifetime, size, gravity, direction, 38.0, spark)


func impact(position: Vector3, normal: Vector3) -> void:
	directional_burst(position, -normal, Color(1.0, 0.82, 0.34), 7, 5.0, 0.26, 0.055, 9.0, true)
	burst(position, Color(0.55, 0.45, 0.24, 0.7), 3, 1.6, 0.35, 0.12, 2.0)


func ring(
	position: Vector3,
	color: Color,
	start_radius: float = 0.3,
	end_radius: float = 1.6,
	duration: float = 0.35,
	width: float = 0.08,
	alpha: float = 0.7
) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.9
	mesh.outer_radius = 1.0
	mesh.rings = 36
	mesh.ring_segments = 6
	var material := MF.make_material(
		Color(color.r, color.g, color.b, alpha),
		0.0,
		1.0,
		color,
		2.2,
		true,
		true
	)
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.position = position + Vector3(0.0, 0.03, 0.0)
	instance.scale = Vector3.ONE * maxf(start_radius, 0.05)
	add_child(instance)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(instance, "scale", Vector3.ONE * maxf(end_radius, 0.06), duration)
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.tween_property(material, "emission_energy_multiplier", 0.0, duration)
	tween.chain().tween_callback(instance.queue_free)


func tracer(from: Vector3, to: Vector3) -> void:
	var offset := to - from
	var length := offset.length()
	if length < 0.05:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, length)
	var material := MF.make_material(
		Color(1.0, 0.76, 0.32, 0.9),
		0.0,
		1.0,
		Color(1.0, 0.72, 0.28),
		3.0,
		true,
		true
	)
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	instance.global_position = (from + to) * 0.5
	var up := Vector3.UP
	if absf(offset.normalized().dot(Vector3.UP)) > 0.97:
		up = Vector3.RIGHT
	instance.look_at(to, up)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.09)
	tween.tween_property(instance, "scale:x", 0.2, 0.09)
	tween.tween_property(instance, "scale:y", 0.2, 0.09)
	tween.chain().tween_callback(instance.queue_free)


func popup(position: Vector3, text: String, color: Color, font_size: int = 42) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.0045
	label.outline_size = 10
	label.outline_modulate = Color(0.01, 0.015, 0.02, 0.95)
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 3
	label.position = position
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.85, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.18)
	tween.chain().tween_callback(label.queue_free)
