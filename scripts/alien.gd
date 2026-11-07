extends CharacterBody3D

## Alien enemy. Uses downloaded models:
## - "xeno": Xenomorph by Slaan (CC-BY 3.0), detailed static mesh with procedural motion.
## - "runner": Quaternius Big Alien (CC0), skinned model with 14 animations.

const MF = preload("res://scripts/mesh_factory.gd")
const XENOMORPH_SCENE := preload("res://assets/models/xenomorph.glb")
const RUNNER_SCENE := preload("res://assets/models/quaternius/alien_big.gltf")

const GRAVITY := 24.0
const XENO_MODEL_SCALE := 0.65
const XENO_MODEL_HEIGHT := 0.73
const RUNNER_MODEL_SCALE := 0.64

var game: Node
var variant := "xeno"
var variant_name := "ЧУЖОЙ"
var wave_number := 1
var hp := 6
var max_hp := 6
var speed := 3.2
var contact_damage := 18
var score_value := 300
var body_scale := XENO_MODEL_SCALE

var _time := 0.0
var _flash := 0.0
var _attack_cooldown := 0.0
var _attack_anim := 0.0
var _hit_anim_timer := 0.0
var _dead := false

var _model: Node3D
var _anim_root: Node3D
var _asset: Node3D
var _anim_player: AnimationPlayer
var _materials: Array[StandardMaterial3D] = []
var _base_emissions: Array[Color] = []
var _base_energies: Array[float] = []

var _health_bar: Node3D
var _health_fill: MeshInstance3D
var _health_material: StandardMaterial3D
var _ground_ring: MeshInstance3D
var _ground_ring_material: StandardMaterial3D


func setup(new_game: Node, wave: int, new_variant: String = "xeno") -> void:
	game = new_game
	wave_number = maxi(1, wave)
	variant = new_variant if new_variant == "runner" else "xeno"
	if variant == "runner":
		variant_name = "БЕГУН"
		body_scale = RUNNER_MODEL_SCALE
		max_hp = clampi(4 + int(wave_number / 3), 4, 9)
		speed = 4.9 + minf(float(wave_number) * 0.12, 1.4)
		contact_damage = 12 + mini(wave_number, 5)
		score_value = 220 + wave_number * 15
	else:
		variant_name = "ЧУЖОЙ"
		body_scale = XENO_MODEL_SCALE
		max_hp = clampi(6 + int(wave_number / 2), 6, 14)
		speed = 2.8 + minf(float(wave_number) * 0.14, 1.8)
		contact_damage = 16 + mini(wave_number, 6)
		score_value = 300 + wave_number * 20
	hp = max_hp


func _ready() -> void:
	add_to_group("aliens")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	floor_stop_on_slope = true
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55 if variant == "runner" else 0.42
	capsule.height = 2.3 if variant == "runner" else 2.05
	collision.shape = capsule
	collision.position = Vector3(0.0, capsule.height * 0.5, 0.0)
	add_child(collision)
	_build_model()
	_build_health_bar()
	_attack_cooldown = randf_range(0.35, 0.9)


func _physics_process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 6.0)
	_attack_anim = maxf(0.0, _attack_anim - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_hit_anim_timer = maxf(0.0, _hit_anim_timer - delta)

	if _dead:
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var player = null
	if game != null and is_instance_valid(game.player):
		player = game.player

	if game == null or game.state != "playing" or player == null or player.dead:
		velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
		move_and_slide()
		_update_visuals(delta)
		_update_health_bar()
		return

	var to_player: Vector3 = player.global_position - global_position
	var flat := Vector3(to_player.x, 0.0, to_player.z)
	var distance := flat.length()
	var direction := flat.normalized() if distance > 0.01 else Vector3.FORWARD

	var separation := Vector3.ZERO
	for group_name in ["aliens", "headcrabs"]:
		for other in get_tree().get_nodes_in_group(group_name):
			if other == self or not is_instance_valid(other):
				continue
			var away: Vector3 = global_position - other.global_position
			away.y = 0.0
			var away_distance := away.length()
			var minimum := 1.45 if group_name == "aliens" else 1.15
			if away_distance > 0.01 and away_distance < minimum:
				separation += away / away_distance * (minimum - away_distance) * 2.2

	var desired := direction
	if separation.length_squared() > 0.001:
		desired = (direction + separation).normalized()

	var attack_reach := 1.9 if variant == "runner" else 1.8
	var target_speed := speed
	if distance < attack_reach + 0.9:
		target_speed *= 0.55

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(desired * target_speed, 20.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if flat.length_squared() > 0.01:
		var target_yaw := atan2(-direction.x, -direction.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-delta * 9.0))

	if _attack_cooldown <= 0.0 and distance < attack_reach and absf(to_player.y) < 2.2:
		_attack_cooldown = 0.95 if variant == "runner" else 1.3
		_attack_anim = 0.75 if variant == "runner" else 0.34
		player.take_damage(contact_damage, global_position)
		velocity.x += direction.x * 2.8
		velocity.z += direction.z * 2.8
		Sfx.play("flesh", randf_range(0.68, 0.8), -2.0)

	move_and_slide()
	_update_visuals(delta)
	_update_health_bar()


func _update_visuals(delta: float) -> void:
	if not is_instance_valid(_model) or not is_instance_valid(_anim_root):
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var stride := clampf(horizontal_speed / maxf(speed, 0.1), 0.0, 1.0)
	var attack_progress := 0.0
	if _attack_anim > 0.0:
		attack_progress = sin((1.0 - _attack_anim / 0.34) * PI)

	if variant == "runner":
		_update_runner_animation(horizontal_speed)
	else:
		var gait_bob := sin(_time * 8.5) * 0.05 * stride + sin(_time * 2.1) * 0.014
		_anim_root.position.y = lerpf(_anim_root.position.y, gait_bob, minf(1.0, delta * 12.0))
		_anim_root.position.z = lerpf(_anim_root.position.z, -attack_progress * 0.55, minf(1.0, delta * 16.0))
		var lean := -0.11 * stride - attack_progress * 0.16
		_anim_root.rotation.x = lerpf(_anim_root.rotation.x, lean, minf(1.0, delta * 9.0))
		_anim_root.rotation.z = lerpf(_anim_root.rotation.z, sin(_time * 4.6) * 0.04 * stride, minf(1.0, delta * 8.0))

	var flash_energy := _flash * 3.2
	for i in _materials.size():
		var material := _materials[i]
		material.emission = Color.WHITE if _flash > 0.0 else _base_emissions[i]
		material.emission_energy_multiplier = _base_energies[i] + flash_energy

	if is_instance_valid(_ground_ring):
		var pulse := 0.5 + 0.5 * sin(_time * 4.8)
		_ground_ring_material.albedo_color = Color(0.42, 1.0, 0.3, 0.26 + pulse * 0.12)
		_ground_ring_material.emission_energy_multiplier = 1.2 + pulse * 0.7
		var ring_scale := 1.0 + pulse * 0.05
		_ground_ring.scale = Vector3(ring_scale, 1.0, ring_scale)


func _update_runner_animation(horizontal_speed: float) -> void:
	if not is_instance_valid(_anim_player):
		return
	if _hit_anim_timer > 0.0:
		_play_anim("HitReact")
		return
	if _attack_anim > 0.0:
		_play_anim("Punch", 1.15)
		return
	if horizontal_speed > 0.35:
		_play_anim("Run", clampf(horizontal_speed / 4.2, 0.85, 1.45))
	else:
		_play_anim("Idle")


func _play_anim(anim_name: String, speed_scale: float = 1.0) -> void:
	if not is_instance_valid(_anim_player):
		return
	if not _anim_player.has_animation(anim_name):
		return
	if _anim_player.current_animation == anim_name and _anim_player.is_playing():
		_anim_player.speed_scale = speed_scale
		return
	_anim_player.play(anim_name, 0.15, speed_scale)


func _update_health_bar() -> void:
	if not is_instance_valid(_health_bar):
		return
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_health_bar.visible = hp < max_hp and not _dead
	_health_fill.scale.x = maxf(0.001, ratio)
	_health_fill.position.x = -0.56 + 0.56 * ratio
	_health_material.albedo_color = Color(0.52, 1.0, 0.34, 0.95)
	_health_material.emission = Color(0.4, 1.0, 0.24)
	_health_material.emission_energy_multiplier = 1.7


func take_damage(amount: int, direction: Vector3) -> void:
	if _dead:
		return
	hp -= amount
	_flash = 1.0
	var knockback := Vector3(direction.x, 0.0, direction.z)
	if knockback.length_squared() < 0.001:
		knockback = Vector3.FORWARD
	velocity += knockback.normalized() * 2.2 + Vector3(0.0, 0.9, 0.0)
	if variant == "runner" and is_instance_valid(_anim_player) and _anim_player.has_animation("HitReact"):
		_hit_anim_timer = 0.45
	if hp <= 0:
		_die()
	else:
		if game != null:
			game.hud.on_hit()
			game.effects.burst(global_position + Vector3(0.0, 1.1, 0.0), Color(0.36, 0.95, 0.22, 0.9), 12, 3.8, 0.45, 0.08, 8.0)
			game.effects.burst(global_position + Vector3(0.0, 1.1, 0.0), Color(0.08, 0.3, 0.05, 0.85), 6, 2.2, 0.4, 0.1, 6.0)
		Sfx.play("hit", randf_range(0.72, 0.88), -6.0)
	_update_health_bar()


func _die() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("aliens")
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	if is_instance_valid(_health_bar):
		_health_bar.visible = false
	if is_instance_valid(_ground_ring):
		_ground_ring.visible = false
	if game != null:
		game.on_alien_killed(global_position, variant, score_value)
	Sfx.play("alien_die", randf_range(0.86, 1.02), -3.0)

	if variant == "runner" and is_instance_valid(_anim_player):
		_play_anim("Death", 1.0)
		var runner_tween := create_tween()
		runner_tween.tween_interval(1.25)
		runner_tween.tween_callback(queue_free)
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_anim_root, "scale", Vector3(1.2, 0.08, 1.2), 0.35)
	tween.tween_property(_anim_root, "rotation:z", 0.65, 0.35)
	tween.chain().tween_callback(queue_free)


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	_anim_root = Node3D.new()
	_anim_root.name = "AnimationRoot"
	_model.add_child(_anim_root)

	var scene: PackedScene = RUNNER_SCENE if variant == "runner" else XENOMORPH_SCENE
	_asset = scene.instantiate()
	_asset.name = "AlienModel"
	_asset.scale = Vector3.ONE * body_scale
	if variant == "runner":
		_asset.rotation.y = PI
		_asset.position.y = 0.0
	else:
		_asset.position.y = XENO_MODEL_HEIGHT
	_anim_root.add_child(_asset)
	_apply_model_materials()

	if variant == "runner":
		_anim_player = _asset.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if is_instance_valid(_anim_player):
			_play_anim("Idle")

	_ground_ring_material = MF.make_material(
		Color(0.42, 1.0, 0.3, 0.34),
		0.0,
		1.0,
		Color(0.4, 1.0, 0.25),
		1.6,
		true,
		true
	)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.7
	ring_mesh.outer_radius = 0.83
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 5
	ring_mesh.material = _ground_ring_material
	_ground_ring = MeshInstance3D.new()
	_ground_ring.mesh = ring_mesh
	_ground_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground_ring.position = Vector3(0.0, 0.045, 0.0)
	add_child(_ground_ring)


func _apply_model_materials() -> void:
	var seen: Dictionary = {}
	for mesh_node in _asset.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		if mesh == null:
			continue
		var source: Material = mesh.get_active_material(0)
		if source == null:
			continue
		var material: StandardMaterial3D = seen.get(source) as StandardMaterial3D
		if material == null:
			if source is StandardMaterial3D:
				material = source.duplicate() as StandardMaterial3D
			else:
				continue
			material.emission_enabled = true
			if variant == "xeno":
				material.emission = Color(0.03, 0.2, 0.08)
				material.emission_energy_multiplier = 0.9
			else:
				material.emission = Color.BLACK
				material.emission_energy_multiplier = 0.0
			seen[source] = material
			_materials.append(material)
			_base_emissions.append(material.emission)
			_base_energies.append(material.emission_energy_multiplier)
		mesh.material_override = material


func _build_health_bar() -> void:
	var bar_height := 2.62 if variant == "runner" else 2.3
	_health_bar = Node3D.new()
	_health_bar.position = Vector3(0.0, bar_height, 0.0)
	add_child(_health_bar)

	var bg_material := MF.make_material(Color(0.01, 0.02, 0.018, 0.9), 0.0, 1.0, Color(0.0, 0.0, 0.0), 0.0, true, true, true)
	bg_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(1.22, 0.13)
	bg_mesh.material = bg_material
	var bg := MeshInstance3D.new()
	bg.mesh = bg_mesh
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_health_bar.add_child(bg)

	_health_material = MF.make_material(Color(0.52, 1.0, 0.34, 0.95), 0.0, 1.0, Color(0.4, 1.0, 0.24), 1.7, true, true, true)
	_health_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(1.14, 0.07)
	fill_mesh.material = _health_material
	_health_fill = MeshInstance3D.new()
	_health_fill.mesh = fill_mesh
	_health_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_health_fill.position = Vector3(0.0, 0.0, -0.01)
	_health_bar.add_child(_health_fill)
	_health_bar.visible = false
