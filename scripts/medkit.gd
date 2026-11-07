extends Area3D

## Floating medkit. Spawned in batches by main.gd.
## Touch it to restore health; it disappears after two minutes.

const MF = preload("res://scripts/mesh_factory.gd")

const DEFAULT_LIFETIME := 120.0
const DEFAULT_HEAL := 30
const PICKUP_RADIUS := 1.3

var game: Node
var lifetime := DEFAULT_LIFETIME
var heal_amount := DEFAULT_HEAL

var _time := 0.0
var _age := 0.0
var _collected := false
var _expired := false
var _visual: Node3D
var _cross_material: StandardMaterial3D
var _ring_material: StandardMaterial3D
var _beam_material: StandardMaterial3D
var _glow_light: OmniLight3D
var _base_ring_color := Color(0.35, 1.0, 0.55, 0.34)


func setup(new_game: Node) -> void:
	game = new_game


func _ready() -> void:
	add_to_group("medkits")
	collision_layer = 0
	collision_mask = 4
	monitoring = true
	monitorable = false
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = PICKUP_RADIUS
	collision.shape = sphere
	add_child(collision)
	body_entered.connect(_on_body_entered)
	_build_visual()


func _process(delta: float) -> void:
	if game == null or game.state != "playing":
		return
	_time += delta
	_age += delta
	if _age >= lifetime:
		_expire()
		return

	var bob := sin(_time * 2.2) * 0.14
	_visual.position.y = bob
	_visual.rotation.y += delta * 1.35
	_visual.rotation.z = sin(_time * 1.7) * 0.07

	var remaining := lifetime - _age
	var pulse := 0.5 + 0.5 * sin(_time * 3.4)
	if remaining < 10.0:
		var blink := 0.5 + 0.5 * sin(_time * 12.0)
		_cross_material.emission_energy_multiplier = 2.0 + blink * 2.4
		_ring_material.albedo_color = Color(1.0, 0.55, 0.2, 0.22 + blink * 0.26)
		_ring_material.emission = Color(1.0, 0.45, 0.12)
		_ring_material.emission_energy_multiplier = 1.4 + blink * 1.2
	else:
		_cross_material.emission_energy_multiplier = 1.7 + pulse * 0.5
		_ring_material.albedo_color = Color(
			_base_ring_color.r,
			_base_ring_color.g,
			_base_ring_color.b,
			0.22 + pulse * 0.16
		)
		_ring_material.emission = Color(0.35, 1.0, 0.55)
		_ring_material.emission_energy_multiplier = 1.2 + pulse * 0.6

	if is_instance_valid(_beam_material):
		var beam_color := _beam_material.albedo_color
		beam_color.a = 0.05 + 0.018 * pulse
		_beam_material.albedo_color = beam_color
	if is_instance_valid(_glow_light):
		_glow_light.light_energy = 1.0 + pulse * 0.35


func _on_body_entered(body: Node3D) -> void:
	if _collected or _expired:
		return
	if body == null or not body.is_in_group("player"):
		return
	if game == null or game.state != "playing":
		return
	_collect()


func _collect() -> void:
	if _collected or _expired:
		return
	_collected = true
	set_process(false)
	var healed := 0
	if game != null and is_instance_valid(game.player) and not game.player.dead:
		var before: int = game.player.health
		game.player.heal(heal_amount)
		healed = game.player.health - before
	remove_from_group("medkits")
	if game != null:
		game.on_medkit_removed()
		game.on_medkit_collected(global_position, healed)
	queue_free()


func _expire() -> void:
	if _expired or _collected:
		return
	_expired = true
	set_process(false)
	remove_from_group("medkits")
	if game != null:
		game.on_medkit_expired(global_position)
		game.on_medkit_removed()
	queue_free()


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.scale = Vector3.ONE * 1.12
	add_child(_visual)

	var shell := Color(0.9, 0.93, 0.9)
	var trim := Color(0.23, 0.3, 0.29)
	var red := Color(1.0, 0.16, 0.16)

	MF.add_box(_visual, Vector3(0.72, 0.48, 0.5), Vector3.ZERO, shell, {
		"metallic": 0.18,
		"roughness": 0.48,
	})
	MF.add_box(_visual, Vector3(0.78, 0.06, 0.56), Vector3(0.0, -0.25, 0.0), trim, {
		"metallic": 0.45,
		"roughness": 0.42,
	})
	MF.add_box(_visual, Vector3(0.26, 0.06, 0.09), Vector3(0.0, 0.32, 0.0), trim, {
		"metallic": 0.55,
		"roughness": 0.35,
	})
	MF.add_box(_visual, Vector3(0.05, 0.09, 0.07), Vector3(-0.12, 0.27, 0.0), trim, {
		"metallic": 0.5,
		"roughness": 0.4,
	})
	MF.add_box(_visual, Vector3(0.05, 0.09, 0.07), Vector3(0.12, 0.27, 0.0), trim, {
		"metallic": 0.5,
		"roughness": 0.4,
	})
	MF.add_box(_visual, Vector3(0.1, 0.1, 0.03), Vector3(-0.25, 0.04, -0.26), trim, {
		"metallic": 0.55,
		"roughness": 0.35,
	})
	MF.add_box(_visual, Vector3(0.1, 0.1, 0.03), Vector3(0.25, 0.04, -0.26), trim, {
		"metallic": 0.55,
		"roughness": 0.35,
	})

	_cross_material = MF.make_material(red, 0.0, 1.0, red, 1.8, true)
	for side in [-1.0, 1.0]:
		var z: float = side * 0.258
		MF.add_box(_visual, Vector3(0.38, 0.13, 0.024), Vector3(0.0, 0.01, z), red, {
			"material": _cross_material,
		})
		MF.add_box(_visual, Vector3(0.13, 0.38, 0.024), Vector3(0.0, 0.01, z), red, {
			"material": _cross_material,
		})
		var x: float = side * 0.358
		MF.add_box(_visual, Vector3(0.024, 0.13, 0.38), Vector3(x, 0.01, 0.0), red, {
			"material": _cross_material,
		})
		MF.add_box(_visual, Vector3(0.024, 0.38, 0.13), Vector3(x, 0.01, 0.0), red, {
			"material": _cross_material,
		})
	MF.add_box(_visual, Vector3(0.38, 0.024, 0.13), Vector3(0.0, 0.252, 0.0), red, {
		"material": _cross_material,
	})
	MF.add_box(_visual, Vector3(0.13, 0.024, 0.38), Vector3(0.0, 0.252, 0.0), red, {
		"material": _cross_material,
	})

	var floor_height := maxf(global_position.y, 0.1)
	_ring_material = MF.make_material(
		_base_ring_color,
		0.0,
		1.0,
		Color(0.35, 1.0, 0.55),
		1.6,
		true,
		true
	)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.58
	ring_mesh.outer_radius = 0.7
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 5
	ring_mesh.material = _ring_material
	var ground_ring := MeshInstance3D.new()
	ground_ring.mesh = ring_mesh
	ground_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_ring.position = Vector3(0.0, -floor_height + 0.04, 0.0)
	add_child(ground_ring)

	_beam_material = MF.make_material(
		Color(0.35, 1.0, 0.55, 0.06),
		0.0,
		1.0,
		Color(0.35, 1.0, 0.55),
		1.0,
		true,
		true
	)
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.14
	beam_mesh.bottom_radius = 0.4
	beam_mesh.height = floor_height
	beam_mesh.radial_segments = 18
	beam_mesh.material = _beam_material
	var beam := MeshInstance3D.new()
	beam.mesh = beam_mesh
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = Vector3(0.0, -floor_height * 0.5, 0.0)
	add_child(beam)

	_glow_light = OmniLight3D.new()
	_glow_light.light_color = Color(0.35, 1.0, 0.55)
	_glow_light.light_energy = 1.15
	_glow_light.omni_range = 4.5
	_glow_light.shadow_enabled = false
	add_child(_glow_light)
