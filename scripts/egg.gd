extends CharacterBody3D

const MF = preload("res://scripts/mesh_factory.gd")

const MAX_HP := 3
const GRAVITY := 22.0

var game: Node
var hatch_delay := 16.0
var egg_type := "headcrab"
var hp := MAX_HP
var _age := 0.0
var _time := 0.0
var _landed := false
var _dead := false
var _flash := 0.0
var _hit_wobble := 0.0
var _wobble_seed := 0.0

var _visual: Node3D
var _body_material: StandardMaterial3D
var _ring_instance: MeshInstance3D
var _ring_material: StandardMaterial3D
var _progress_border: MeshInstance3D
var _progress_bg: MeshInstance3D
var _progress_fill: MeshInstance3D
var _progress_border_material: StandardMaterial3D
var _progress_bg_material: StandardMaterial3D
var _progress_material: StandardMaterial3D
var _crack_1: Node3D
var _crack_2: Node3D


func setup(new_game: Node, new_hatch_delay: float, new_type: String = "headcrab") -> void:
	game = new_game
	hatch_delay = new_hatch_delay
	egg_type = new_type
	_wobble_seed = randf_range(0.0, TAU)


func _ready() -> void:
	add_to_group("eggs")
	collision_layer = 0
	collision_mask = 1
	floor_snap_length = 0.2
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.4
	collision.shape = capsule
	collision.position = Vector3(0.0, 0.7, 0.0)
	add_child(collision)
	_build_visuals()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if game != null and game.state != "playing":
		return
	_time += delta
	_flash = maxf(0.0, _flash - delta * 7.0)
	_hit_wobble = maxf(0.0, _hit_wobble - delta * 5.0)

	if not _landed:
		velocity.y -= GRAVITY * delta
		move_and_slide()
		if is_on_floor():
			_land()
		_update_ground_ring()
		return

	_age += delta
	_update_visuals()
	if _age >= hatch_delay:
		_hatch_naturally()


func _land() -> void:
	velocity = Vector3.ZERO
	_landed = true
	collision_layer = 2
	if game != null:
		game.effects.burst(global_position + Vector3(0.0, 0.1, 0.0), Color(0.58, 0.65, 0.46, 0.6), 10, 2.5, 0.45, 0.06, 5.0)
		game.effects.ring(global_position, Color(0.52, 0.9, 0.56, 0.35), 0.4, 1.5, 0.35, 0.06, 0.6)
		game.add_shake(1.4)
	Sfx.play("egg_land", randf_range(0.92, 1.08), -6.0)
	var tween := create_tween()
	_visual.scale = Vector3(1.12, 0.82, 1.12)
	tween.tween_property(_visual, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_progress_border.visible = true
	_progress_bg.visible = true
	_progress_fill.visible = true


func _update_ground_ring() -> void:
	if is_instance_valid(_ring_instance):
		_ring_instance.global_position = Vector3(global_position.x, 0.025, global_position.z)


func _update_visuals() -> void:
	var progress := clampf(_age / maxf(hatch_delay, 0.01), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_time * lerpf(3.0, 13.0, progress))
	var wobble := sin(_time * (2.4 + progress * 6.0) + _wobble_seed) * (0.012 + progress * 0.022)
	wobble += sin(_time * 24.0) * _hit_wobble * 0.06
	_visual.rotation.z = wobble
	_visual.rotation.x = wobble * 0.5

	var heat_cold := Color(1.0, 0.62, 0.2) if egg_type == "facehugger" else Color(0.32, 0.95, 0.42)
	var heat_hot := Color(1.0, 0.24, 0.42) if egg_type == "facehugger" else Color(1.0, 0.42, 0.12)
	var heat := heat_cold.lerp(heat_hot, progress)
	var flash_mix := clampf(_flash, 0.0, 1.0)
	_body_material.emission = heat.lerp(Color.WHITE, flash_mix * 0.75)
	_body_material.emission_energy_multiplier = 0.22 + progress * 1.25 + pulse * 0.12 + flash_mix * 2.2

	_ring_material.albedo_color = Color(heat.r, heat.g, heat.b, 0.28 + pulse * 0.22)
	_ring_material.emission = heat
	_ring_material.emission_energy_multiplier = 1.5 + progress * 1.5 + pulse * 0.5
	if is_instance_valid(_ring_instance):
		var ring_scale := 1.0 + pulse * 0.08
		_ring_instance.scale = Vector3(ring_scale, 1.0, ring_scale)

	_progress_border_material.albedo_color = Color(heat.r, heat.g, heat.b, 0.5 + pulse * 0.3)
	_progress_border_material.emission = heat
	_progress_border_material.emission_energy_multiplier = 1.0 + pulse * 0.9
	_progress_bg_material.emission_energy_multiplier = 0.3 + pulse * 0.15
	_progress_material.albedo_color = heat
	_progress_material.emission = heat
	_progress_material.emission_energy_multiplier = 2.0
	_progress_fill.scale.x = maxf(0.001, progress)
	_progress_fill.position.x = -0.56 + 0.56 * progress
	_crack_1.visible = hp <= 2
	_crack_2.visible = hp <= 1


func take_damage(amount: int, direction: Vector3) -> void:
	if _dead or not _landed:
		return
	hp -= amount
	_flash = 1.0
	_hit_wobble = 1.0
	_crack_1.visible = hp <= 2
	_crack_2.visible = hp <= 1
	if game != null:
		game.hud.on_hit()
		game.effects.burst(global_position + Vector3(0.0, 0.85, 0.0), Color(0.64, 1.0, 0.52, 0.9), 8, 3.0, 0.4, 0.06, 6.0)
		game.effects.directional_burst(global_position + Vector3(0.0, 0.85, 0.0), -direction, Color(0.72, 0.92, 0.42, 0.9), 6, 4.0, 0.28, 0.05, 7.0, false)
	Sfx.play("egg_hit", randf_range(0.9, 1.12), -8.0)
	if hp <= 0:
		_break_open()


func _break_open() -> void:
	if _dead:
		return
	_dead = true
	var burst_position := global_position + Vector3(0.0, 0.8, 0.0)
	if game != null:
		if egg_type == "facehugger":
			game.effects.burst(burst_position, Color(1.0, 0.62, 0.24, 0.95), 26, 5.5, 0.65, 0.1, 10.0)
			game.effects.burst(burst_position, Color(0.36, 0.22, 0.1, 0.9), 12, 3.2, 0.5, 0.13, 8.0)
			game.effects.ring(global_position, Color(1.0, 0.5, 0.2, 0.65), 0.4, 2.6, 0.45, 0.1, 0.8)
		else:
			game.effects.burst(burst_position, Color(0.56, 0.94, 0.4, 0.95), 26, 5.5, 0.65, 0.1, 10.0)
			game.effects.burst(burst_position, Color(0.16, 0.34, 0.16, 0.9), 12, 3.2, 0.5, 0.13, 8.0)
			game.effects.ring(global_position, Color(0.66, 1.0, 0.52, 0.65), 0.4, 2.6, 0.45, 0.1, 0.8)
		game.add_shake(4.2)
		game.on_egg_broken(global_position, egg_type)
		if egg_type == "facehugger":
			var hugger_angle := _wobble_seed + randf_range(-0.3, 0.3)
			var hugger_outward := Vector3(cos(hugger_angle), 0.0, sin(hugger_angle))
			var hugger_position := global_position + hugger_outward * 0.62 + Vector3(0.0, 0.3, 0.0)
			game.spawn_facehugger(hugger_position, hugger_outward)
		else:
			for i in 2:
				var angle := _wobble_seed + PI * float(i) + randf_range(-0.35, 0.35)
				var outward := Vector3(cos(angle), 0.0, sin(angle))
				var spawn_position := global_position + outward * 0.62 + Vector3(0.0, 0.3, 0.0)
				game.spawn_headcrab(spawn_position, true, outward)
	Sfx.play("egg_break", randf_range(0.9, 1.08), -2.0)
	queue_free()


func _hatch_naturally() -> void:
	if _dead:
		return
	_dead = true
	var burst_position := global_position + Vector3(0.0, 0.8, 0.0)
	if game != null:
		if egg_type == "facehugger":
			game.effects.burst(burst_position, Color(1.0, 0.68, 0.28, 0.9), 20, 4.4, 0.55, 0.09, 7.0)
			game.effects.ring(burst_position, Color(1.0, 0.42, 0.18, 0.65), 0.4, 2.0, 0.38, 0.09, 0.8)
			game.add_shake(2.8)
			for i in 2:
				var angle := _wobble_seed + PI * float(i) + randf_range(-0.35, 0.35)
				var outward := Vector3(cos(angle), 0.0, sin(angle))
				var spawn_position := global_position + outward * 0.62 + Vector3(0.0, 0.3, 0.0)
				game.spawn_facehugger(spawn_position, outward)
		else:
			game.effects.burst(burst_position, Color(0.86, 0.76, 0.4, 0.85), 18, 4.2, 0.5, 0.09, 7.0)
			game.effects.ring(burst_position, Color(1.0, 0.58, 0.28, 0.65), 0.4, 2.0, 0.38, 0.09, 0.8)
			game.add_shake(2.4)
			for i in 2:
				var angle := _wobble_seed + PI * float(i) + randf_range(-0.35, 0.35)
				var outward := Vector3(cos(angle), 0.0, sin(angle))
				var spawn_position := global_position + outward * 0.58 + Vector3(0.0, 0.3, 0.0)
				game.spawn_headcrab(spawn_position, false, outward)
		game.on_egg_hatched(global_position, egg_type)
	Sfx.play("hatch", randf_range(0.9, 1.08), -1.0)
	queue_free()


func _build_visuals() -> void:
	_visual = Node3D.new()
	add_child(_visual)

	var shell_color := Color(0.2, 0.32, 0.18)
	var shell_emission := Color(0.3, 0.9, 0.35)
	var pale := Color(0.66, 0.82, 0.46)
	var pale_emission := Color(0.5, 0.9, 0.4)
	var vein_color := Color(0.12, 0.2, 0.1)
	if egg_type == "facehugger":
		shell_color = Color(0.34, 0.27, 0.15)
		shell_emission = Color(1.0, 0.55, 0.2)
		pale = Color(0.82, 0.72, 0.48)
		pale_emission = Color(1.0, 0.6, 0.24)
		vein_color = Color(0.2, 0.13, 0.06)

	_body_material = MF.make_material(
		shell_color,
		0.05,
		0.55,
		shell_emission,
		0.3
	)
	MF.add_sphere(_visual, 0.5, Vector3(0.0, 0.7, 0.0), shell_color, {
		"scale": Vector3(1.0, 1.35, 1.0),
		"material": _body_material,
		"segments": 24,
		"rings": 14,
	})

	var pale_material := MF.make_material(pale, 0.0, 0.6, pale_emission, 0.35)
	MF.add_sphere(_visual, 0.14, Vector3(-0.18, 0.98, -0.28), pale, {"scale": Vector3(1.2, 0.7, 0.6), "material": pale_material})
	MF.add_sphere(_visual, 0.1, Vector3(0.2, 0.8, -0.31), pale, {"scale": Vector3(1.0, 0.8, 0.5), "material": pale_material})
	MF.add_sphere(_visual, 0.08, Vector3(0.03, 1.2, -0.2), pale, {"material": pale_material})

	for crown in [
		{"position": Vector3(-0.1, 1.39, -0.04), "radius": 0.085},
		{"position": Vector3(0.09, 1.42, 0.03), "radius": 0.07},
		{"position": Vector3(0.0, 1.35, 0.14), "radius": 0.06},
	]:
		MF.add_sphere(_visual, crown["radius"], crown["position"], pale, {"material": pale_material})

	if egg_type == "facehugger":
		for i in 5:
			var spike_angle := TAU * float(i) / 5.0
			MF.add_cone(_visual, 0.055, 0.32, Vector3(cos(spike_angle) * 0.36, 0.7, sin(spike_angle) * 0.36), pale, {
				"rotation": Vector3(PI * 0.5, spike_angle, 0.0),
				"material": pale_material,
			})

	var vein_material := MF.make_material(vein_color, 0.0, 0.8)
	for vein in [
		{"position": Vector3(-0.26, 0.55, -0.4), "rotation": Vector3(0.0, 0.0, 0.35), "size": Vector3(0.025, 0.34, 0.025)},
		{"position": Vector3(0.24, 0.62, -0.4), "rotation": Vector3(0.0, 0.0, -0.28), "size": Vector3(0.025, 0.3, 0.025)},
		{"position": Vector3(-0.05, 0.5, -0.46), "rotation": Vector3(0.0, 0.0, 0.1), "size": Vector3(0.022, 0.4, 0.022)},
	]:
		MF.add_box(_visual, vein["size"], vein["position"], vein_color, {"rotation": vein["rotation"], "material": vein_material})

	_crack_1 = Node3D.new()
	_visual.add_child(_crack_1)
	var crack_material := MF.make_material(Color(0.03, 0.055, 0.03), 0.0, 0.9)
	MF.add_box(_crack_1, Vector3(0.035, 0.42, 0.02), Vector3(-0.06, 0.86, -0.48), Color(0.03, 0.055, 0.03), {
		"rotation": Vector3(0.0, 0.0, 0.35),
		"material": crack_material,
	})
	MF.add_box(_crack_1, Vector3(0.03, 0.24, 0.02), Vector3(0.06, 0.6, -0.49), Color(0.03, 0.055, 0.03), {
		"rotation": Vector3(0.0, 0.0, -0.5),
		"material": crack_material,
	})
	_crack_1.visible = false

	_crack_2 = Node3D.new()
	_visual.add_child(_crack_2)
	MF.add_box(_crack_2, Vector3(0.03, 0.34, 0.02), Vector3(0.24, 1.05, -0.41), Color(0.03, 0.055, 0.03), {
		"rotation": Vector3(0.0, 0.0, -0.45),
		"material": crack_material,
	})
	MF.add_box(_crack_2, Vector3(0.03, 0.28, 0.02), Vector3(-0.2, 1.12, -0.42), Color(0.03, 0.055, 0.03), {
		"rotation": Vector3(0.0, 0.0, 0.55),
		"material": crack_material,
	})
	MF.add_box(_crack_2, Vector3(0.03, 0.22, 0.02), Vector3(0.0, 0.4, -0.5), Color(0.03, 0.055, 0.03), {
		"rotation": Vector3(0.0, 0.0, 0.2),
		"material": crack_material,
	})
	_crack_2.visible = false

	_ring_material = MF.make_material(
		Color(0.4, 1.0, 0.5, 0.4),
		0.0,
		1.0,
		Color(0.35, 1.0, 0.45),
		2.0,
		true,
		true
	)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.62
	ring_mesh.outer_radius = 0.74
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 5
	ring_mesh.material = _ring_material
	_ring_instance = MeshInstance3D.new()
	_ring_instance.mesh = ring_mesh
	_ring_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_instance.top_level = true
	add_child(_ring_instance)
	_update_ground_ring()

	_progress_border_material = MF.make_material(
		Color(0.55, 1.0, 0.65, 0.75),
		0.0,
		1.0,
		Color(0.4, 1.0, 0.5),
		1.3,
		true,
		true,
		true
	)
	var border_mesh := QuadMesh.new()
	border_mesh.size = Vector2(1.32, 0.24)
	border_mesh.material = _progress_border_material
	_progress_border = MeshInstance3D.new()
	_progress_border.mesh = border_mesh
	_progress_border.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_progress_border.position = Vector3(0.0, 1.72, -0.012)
	_progress_border.visible = false
	add_child(_progress_border)

	_progress_bg_material = MF.make_material(
		Color(0.015, 0.055, 0.03, 0.96),
		0.0,
		1.0,
		Color(0.1, 0.4, 0.2),
		0.3,
		true,
		true,
		true
	)
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(1.2, 0.15)
	bg_mesh.material = _progress_bg_material
	_progress_bg = MeshInstance3D.new()
	_progress_bg.mesh = bg_mesh
	_progress_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_progress_bg.position = Vector3(0.0, 1.72, 0.0)
	_progress_bg.visible = false
	add_child(_progress_bg)

	_progress_material = MF.make_material(
		Color(0.45, 1.0, 0.5, 1.0),
		0.0,
		1.0,
		Color(0.45, 1.0, 0.5),
		2.0,
		true,
		true,
		true
	)
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(1.12, 0.09)
	fill_mesh.material = _progress_material
	_progress_fill = MeshInstance3D.new()
	_progress_fill.mesh = fill_mesh
	_progress_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_progress_fill.position = Vector3(-0.56, 1.72, 0.012)
	_progress_fill.scale.x = 0.001
	_progress_fill.visible = false
	add_child(_progress_fill)
