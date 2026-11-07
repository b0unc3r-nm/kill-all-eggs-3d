extends Node3D

## Slow drifting spores and dust motes inside the containment arena.

const MF = preload("res://scripts/mesh_factory.gd")


func _ready() -> void:
	_make_system(72, 0.055, Color(0.5, 1.0, 0.68, 0.5), 16.0)
	_make_system(34, 0.04, Color(1.0, 0.7, 0.34, 0.4), 12.0)


func _make_system(amount: int, size: float, color: Color, lifetime: float) -> void:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(20.5, 3.0, 20.5)
	particles.position = Vector3(0.0, 4.0, 0.0)
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 55.0
	particles.initial_velocity_min = 0.04
	particles.initial_velocity_max = 0.24
	particles.gravity = Vector3(0.0, 0.02, 0.0)
	particles.scale_amount_min = 0.55
	particles.scale_amount_max = 1.5
	particles.color = color

	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var material := MF.make_material(
		Color.WHITE,
		0.0,
		1.0,
		color,
		1.6,
		true,
		true,
		true,
		true
	)
	quad.material = material
	particles.mesh = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
