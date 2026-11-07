extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const EggScript = preload("res://scripts/egg.gd")
const HeadcrabScript = preload("res://scripts/headcrab.gd")
const FacehuggerScript = preload("res://scripts/facehugger.gd")
const AlienScript = preload("res://scripts/alien.gd")
const MedkitScript = preload("res://scripts/medkit.gd")
const EffectsScript = preload("res://scripts/effects.gd")
const AmbientScript = preload("res://scripts/ambient.gd")
const HudScript = preload("res://scripts/hud.gd")
const MainMenuScript = preload("res://scripts/main_menu.gd")
const MF = preload("res://scripts/mesh_factory.gd")

const ARENA_SIZE := 44.0
const ARENA_HALF := ARENA_SIZE * 0.5
const SPAWN_HALF := 18.5
const EGG_SPAWN_HEIGHT := 10.0
const CAMERA_OFFSET := Vector3(0.0, 9.2, 7.2)
const MEDKIT_BATCH := 3
const MEDKIT_HEIGHT := 1.55
const MEDKIT_LIFETIME := 120.0
const MEDKIT_RESPAWN_DELAY := 20.0
const FINAL_WAVE := 10
const FACEHUGGER_FROM_WAVE := 3

var state := "menu"
var player: CharacterBody3D
var camera: Camera3D
var hud: Control
var main_menu: Control
var effects: Node3D
var ambient: Node3D

var wave := 0
var score := 0
var kills := 0
var eggs_broken := 0
var wave_active := false
var pending_eggs := 0
var max_eggs := 4
var spawn_timer := 0.0
var pending_aliens := 0
var alien_spawn_timer := 0.0
var max_aliens := 3
var aliens_killed := 0
var wave_clear_timer := 0.0
var medkit_respawn_timer := 0.0
var game_time := 0.0
var shake := 0.0
var final_wave := FINAL_WAVE
var ending_id := ""

var _rng := RandomNumberGenerator.new()
var _first_egg_broken_message := false
var _first_adult_message := false
var _first_facehugger_message := false
var _first_alien_kill_message := false
var _alien_warning_shown := false
var _low_health_message := false
var _times_hugged := 0
var _time := 0.0
var _center_light: OmniLight3D
var _flicker_lights: Array[OmniLight3D] = []
var _flicker_base: Array[float] = []


func _enter_tree() -> void:
	_setup_input_actions()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_environment()
	_build_world()
	_build_effects()
	_build_ambient()
	_build_player()
	_build_camera()
	_build_overlay()
	_build_hud()
	_build_main_menu()


func _process(delta: float) -> void:
	_time += delta
	if state == "playing":
		game_time += delta
		_update_wave(delta)
		_update_medkits(delta)
	_update_camera(delta)
	_update_lights(delta)


func _unhandled_input(event: InputEvent) -> void:
	if state == "paused" and event.is_action_pressed("menu"):
		_return_to_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and (state == "playing" or state == "paused"):
		_set_paused(state != "paused")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("restart") and (state == "gameover" or state == "victory"):
		get_tree().paused = false
		get_tree().reload_current_scene()
		return
	if (state == "gameover" or state == "victory") and (event.is_action_pressed("pause") or event.is_action_pressed("menu")):
		_return_to_menu()
		get_viewport().set_input_as_handled()
		return


func _start_game() -> void:
	if state != "menu":
		return
	state = "playing"
	wave = 0
	score = 0
	kills = 0
	eggs_broken = 0
	aliens_killed = 0
	game_time = 0.0
	shake = 0.0
	ending_id = ""
	_times_hugged = 0
	pending_eggs = 0
	pending_aliens = 0
	alien_spawn_timer = 0.0
	medkit_respawn_timer = 0.0
	wave_active = false
	wave_clear_timer = 0.0
	_first_egg_broken_message = false
	_first_adult_message = false
	_first_facehugger_message = false
	_first_alien_kill_message = false
	_alien_warning_shown = false
	_low_health_message = false
	player.suppress_fire = 0.25
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	if is_instance_valid(main_menu):
		main_menu.visible = false
		main_menu.release_focus()
	hud.show_message("СТРЕЛЯЙ ПО ЯЙЦАМ — НА АРЕНЕ 3 АПТЕЧКИ", Color(0.72, 1.0, 0.8), 3.2)
	Sfx.play("click", 1.0, -8.0)
	_start_wave()
	_spawn_medkit_batch(false)


func _start_wave() -> void:
	wave += 1
	pending_eggs = mini(2 + wave * 2, 24 if wave < final_wave else 28)
	max_eggs = mini(3 + wave, 9)
	pending_aliens = 0 if wave < 2 else mini(1 + int((wave - 2) / 2), 6)
	alien_spawn_timer = 5.0
	_alien_warning_shown = false
	spawn_timer = 0.9
	wave_active = true
	wave_clear_timer = 0.0
	var is_final := wave >= final_wave
	hud.show_wave_banner(wave, is_final, wave >= FACEHUGGER_FROM_WAVE)
	if is_final:
		Sfx.play("final_wave", 1.0, -3.0)
		hud.show_message("ФИНАЛЬНАЯ ВОЛНА — УНИЧТОЖЬ ВСЁ И ЭВАКУИРУЙСЯ", Color(1.0, 0.82, 0.38), 4.0)
	else:
		Sfx.play("wave", 1.0, -5.0)


func _update_wave(delta: float) -> void:
	if wave_active:
		if pending_eggs > 0:
			spawn_timer -= delta
			if spawn_timer <= 0.0 and get_tree().get_nodes_in_group("eggs").size() < max_eggs:
				_spawn_egg()
				pending_eggs -= 1
				var min_interval := maxf(0.55, 1.55 - float(wave) * 0.07)
				var max_interval := maxf(0.85, 2.05 - float(wave) * 0.07)
				spawn_timer = _rng.randf_range(min_interval, max_interval)
		if pending_aliens > 0:
			alien_spawn_timer -= delta
			if alien_spawn_timer <= 0.0 and get_tree().get_nodes_in_group("aliens").size() < max_aliens:
				_spawn_queued_alien()
				pending_aliens -= 1
				alien_spawn_timer = _rng.randf_range(11.0, 16.0)
		if pending_eggs == 0 and pending_aliens == 0 and get_tree().get_nodes_in_group("eggs").is_empty() and get_tree().get_nodes_in_group("headcrabs").is_empty() and get_tree().get_nodes_in_group("aliens").is_empty() and get_tree().get_nodes_in_group("facehuggers").is_empty():
			_complete_wave()
	elif wave_clear_timer > 0.0:
		wave_clear_timer -= delta
		if wave_clear_timer <= 0.0:
			_start_wave()


func _complete_wave() -> void:
	wave_active = false
	var bonus := 100 * wave
	score += bonus
	var health_before: int = player.health
	player.heal(15)
	var healed: int = player.health - health_before
	var message := "ВОЛНА %02d ЗАЧИЩЕНА   +%d ОЧКОВ" % [wave, bonus]
	if healed > 0:
		message += "   +%d HP" % healed
	hud.show_message(message, Color(0.58, 1.0, 0.68), 3.4)
	Sfx.play("clear", 1.0, -4.0)
	add_shake(2.5)
	if wave >= final_wave:
		_trigger_victory()
		return
	wave_clear_timer = 3.5


func _spawn_egg() -> void:
	var egg := EggScript.new()
	var hatch_time := maxf(8.5, 17.0 - float(wave) * 0.55) + _rng.randf_range(-1.2, 1.6)
	egg.setup(self, hatch_time, _pick_egg_type())
	egg.position = _pick_egg_position()
	add_child(egg)


func _pick_egg_type() -> String:
	if wave < FACEHUGGER_FROM_WAVE:
		return "headcrab"
	var chance := minf(0.22 + 0.04 * float(wave - FACEHUGGER_FROM_WAVE), 0.5)
	return "facehugger" if _rng.randf() < chance else "headcrab"


func _pick_egg_position() -> Vector3:
	var player_position := player.global_position if is_instance_valid(player) else Vector3.ZERO
	var existing_eggs := get_tree().get_nodes_in_group("eggs")
	for attempt in 26:
		var candidate := Vector3(
			_rng.randf_range(-SPAWN_HALF, SPAWN_HALF),
			EGG_SPAWN_HEIGHT,
			_rng.randf_range(-SPAWN_HALF, SPAWN_HALF)
		)
		if Vector2(candidate.x - player_position.x, candidate.z - player_position.z).length() < 5.2:
			continue
		var too_close := false
		for egg in existing_eggs:
			if Vector2(candidate.x - egg.global_position.x, candidate.z - egg.global_position.z).length() < 2.6:
				too_close = true
				break
		if not too_close:
			return candidate
	return Vector3(
		_rng.randf_range(-SPAWN_HALF, SPAWN_HALF),
		EGG_SPAWN_HEIGHT,
		_rng.randf_range(-SPAWN_HALF, SPAWN_HALF)
	)


func spawn_headcrab(position: Vector3, unborn: bool, direction: Vector3 = Vector3.ZERO) -> CharacterBody3D:
	var crab := HeadcrabScript.new()
	crab.setup(self, unborn, wave, direction)
	crab.position = position
	add_child(crab)
	return crab


func spawn_alien(position: Vector3, variant: String = "xeno") -> CharacterBody3D:
	var alien := AlienScript.new()
	alien.setup(self, wave, variant)
	alien.position = position
	add_child(alien)
	return alien


func spawn_facehugger(position: Vector3, direction: Vector3 = Vector3.ZERO) -> CharacterBody3D:
	var hugger := FacehuggerScript.new()
	hugger.setup(self, wave, direction)
	hugger.position = position
	add_child(hugger)
	return hugger


func _spawn_queued_alien() -> void:
	var variant := _pick_alien_variant()
	var spawn_position := _pick_alien_position()
	spawn_alien(spawn_position, variant)
	effects.ring(spawn_position, Color(0.45, 1.0, 0.3, 0.7), 0.5, 3.4, 0.55, 0.13, 0.9)
	effects.burst(spawn_position + Vector3(0.0, 1.2, 0.0), Color(0.42, 1.0, 0.28, 0.9), 24, 5.0, 0.7, 0.1, 7.0)
	add_shake(3.0)
	Sfx.play("alien", randf_range(0.82, 0.95), -3.0)
	if not _alien_warning_shown:
		_alien_warning_shown = true
		var warning_text := "ЧУЖОЙ НА АРЕНЕ — ОН БЫСТРЕЕ И ОПАСНЕЕ ХЕДКРАБОВ"
		if variant == "runner":
			warning_text = "БЕГУН НА АРЕНЕ — ОН ОЧЕНЬ БЫСТРЫЙ И ОПАСНЫЙ"
		hud.show_message(warning_text, Color(0.6, 1.0, 0.4), 3.2)


func _pick_alien_variant() -> String:
	if wave >= 4 and _rng.randf() < 0.35:
		return "runner"
	return "xeno"


func _pick_alien_position() -> Vector3:
	var player_position := player.global_position if is_instance_valid(player) else Vector3.ZERO
	var existing_aliens := get_tree().get_nodes_in_group("aliens")
	for attempt in 30:
		var candidate := Vector3(
			_rng.randf_range(-SPAWN_HALF, SPAWN_HALF),
			0.15,
			_rng.randf_range(-SPAWN_HALF, SPAWN_HALF)
		)
		if Vector2(candidate.x - player_position.x, candidate.z - player_position.z).length() < 10.0:
			continue
		var too_close := false
		for alien in existing_aliens:
			if Vector2(candidate.x - alien.global_position.x, candidate.z - alien.global_position.z).length() < 4.0:
				too_close = true
				break
		if not too_close:
			return candidate
	return Vector3(SPAWN_HALF - 2.0, 0.15, SPAWN_HALF - 2.0)


func _update_medkits(delta: float) -> void:
	if not get_tree().get_nodes_in_group("medkits").is_empty():
		return
	if medkit_respawn_timer > 0.0:
		medkit_respawn_timer = maxf(0.0, medkit_respawn_timer - delta)
		if medkit_respawn_timer > 0.0:
			return
	_spawn_medkit_batch(true)


func _spawn_medkit_batch(announce: bool = true) -> void:
	for i in MEDKIT_BATCH:
		spawn_medkit(_pick_medkit_position())
	Sfx.play("medkit_spawn", 1.0, -6.0)
	if announce:
		hud.show_message("НОВАЯ ПАРТИЯ АПТЕЧЕК — 3 ШТУКИ НА АРЕНЕ", Color(0.6, 1.0, 0.72), 2.8)


func spawn_medkit(position: Vector3) -> Area3D:
	var medkit := MedkitScript.new()
	medkit.setup(self)
	medkit.lifetime = MEDKIT_LIFETIME
	medkit.position = position
	add_child(medkit)
	effects.ring(Vector3(position.x, 0.0, position.z), Color(0.4, 1.0, 0.6, 0.7), 0.4, 2.4, 0.5, 0.09, 0.8)
	effects.burst(position, Color(0.45, 1.0, 0.6, 0.9), 16, 2.6, 0.6, 0.07, 2.5)
	return medkit


func _pick_medkit_position() -> Vector3:
	var player_position := player.global_position if is_instance_valid(player) else Vector3.ZERO
	var existing_medkits := get_tree().get_nodes_in_group("medkits")
	for attempt in 32:
		var candidate := Vector3(
			_rng.randf_range(-SPAWN_HALF, SPAWN_HALF),
			MEDKIT_HEIGHT,
			_rng.randf_range(-SPAWN_HALF, SPAWN_HALF)
		)
		if Vector2(candidate.x - player_position.x, candidate.z - player_position.z).length() < 4.5:
			continue
		var too_close := false
		for medkit in existing_medkits:
			if Vector2(candidate.x - medkit.global_position.x, candidate.z - medkit.global_position.z).length() < 3.2:
				too_close = true
				break
		if not too_close:
			return candidate
	return Vector3(
		_rng.randf_range(-SPAWN_HALF, SPAWN_HALF),
		MEDKIT_HEIGHT,
		_rng.randf_range(-SPAWN_HALF, SPAWN_HALF)
	)


func on_medkit_collected(position: Vector3, healed: int) -> void:
	var text: String = "+%d HP" % healed if healed > 0 else "HP ПОЛНО"
	var color := Color(0.5, 1.0, 0.62) if healed > 0 else Color(0.72, 0.9, 0.76)
	effects.popup(position + Vector3(0.0, 0.55, 0.0), text, color, 38)
	effects.burst(position, Color(0.4, 1.0, 0.58, 0.95), 22, 4.0, 0.65, 0.09, 5.0)
	effects.burst(position, Color(1.0, 0.35, 0.35, 0.9), 10, 2.6, 0.5, 0.07, 4.0)
	effects.ring(Vector3(position.x, 0.0, position.z), Color(0.4, 1.0, 0.6, 0.7), 0.4, 2.6, 0.45, 0.09, 0.8)
	Sfx.play("heal", randf_range(0.96, 1.04), -4.0)
	if healed > 0:
		hud.show_message("АПТЕЧКА ПОДОБРАНА   +%d HP" % healed, Color(0.55, 1.0, 0.68), 1.8)
	else:
		hud.show_message("АПТЕЧКА ПОДОБРАНА — ЗДОРОВЬЕ УЖЕ ПОЛНОЕ", Color(0.62, 0.9, 0.72), 1.8)


func on_medkit_expired(position: Vector3) -> void:
	effects.burst(position, Color(0.4, 1.0, 0.55, 0.8), 14, 2.0, 0.5, 0.07, 4.0)
	effects.ring(Vector3(position.x, 0.0, position.z), Color(0.4, 1.0, 0.55, 0.5), 0.3, 1.8, 0.4, 0.07, 0.6)
	Sfx.play("medkit_expire", randf_range(0.9, 1.0), -8.0)


func on_medkit_removed() -> void:
	for medkit in get_tree().get_nodes_in_group("medkits"):
		if is_instance_valid(medkit) and not medkit.is_queued_for_deletion():
			return
	medkit_respawn_timer = MEDKIT_RESPAWN_DELAY
	hud.show_message("ПОСЛЕДНЯЯ АПТЕЧКА ИСЧЕЗЛА — НОВАЯ ПАРТИЯ ЧЕРЕЗ 20 СЕК", Color(0.72, 0.95, 0.78), 2.6)


func get_aim_point() -> Vector3:
	if not is_instance_valid(camera) or not is_instance_valid(player):
		return Vector3.ZERO
	var mouse_position := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + ray_direction * 120.0, 3)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit["position"]
	var plane := Plane(Vector3.UP, 0.0)
	var ground_point: Variant = plane.intersects_ray(origin, ray_direction)
	if ground_point is Vector3:
		return ground_point
	return player.global_position + Vector3(0.0, 0.0, -8.0)


func on_egg_broken(position: Vector3, egg_type: String = "headcrab") -> void:
	eggs_broken += 1
	if egg_type == "facehugger":
		score += 40
		effects.popup(position + Vector3(0.0, 2.0, 0.0), "ЛИЦЕХВАТ", Color(1.0, 0.7, 0.3), 34)
		if not _first_facehugger_message:
			_first_facehugger_message = true
			hud.show_message("ИЗ ЯЙЦА ВЫРВАЛСЯ ЛИЦЕХВАТ — ОН ПРЫГАЕТ НА ЛИЦО", Color(1.0, 0.55, 0.3), 3.2)
	else:
		score += 25
		effects.popup(position + Vector3(0.0, 2.0, 0.0), "НЕДОКРАБЫ", Color(0.7, 1.0, 0.48), 34)
		if not _first_egg_broken_message:
			_first_egg_broken_message = true
			hud.show_message("ЯЙЦО РАЗБИТО: НЕДОКРАБЫ МЕНЬШЕ И НАНОСЯТ МЕНЬШЕ УРОНА", Color(0.72, 1.0, 0.55), 3.0)


func on_egg_hatched(position: Vector3, egg_type: String = "headcrab") -> void:
	if egg_type == "facehugger":
		if not _first_facehugger_message:
			_first_facehugger_message = true
			hud.show_message("ЯЙЦО ВЫЛУПИЛОСЬ — ДВА ЛИЦЕХВАТА ИЩУТ ЛИЦО", Color(1.0, 0.5, 0.3), 3.0)
		return
	if not _first_adult_message:
		_first_adult_message = true
		hud.show_message("ЯЙЦО ВЫЛУПИЛОСЬ — ДВА ВЗРОСЛЫХ ХЕДКРАБА ИДУТ ЗА ТОБОЙ", Color(1.0, 0.52, 0.32), 2.8)


func on_facehugger_killed(position: Vector3, points: int) -> void:
	kills += 1
	score += points
	effects.popup(position + Vector3(0.0, 1.0, 0.0), "+%d" % points, Color(1.0, 0.78, 0.3), 34)
	effects.burst(position + Vector3(0.0, 0.3, 0.0), Color(0.85, 0.7, 0.35, 0.9), 16, 4.0, 0.5, 0.08, 8.0)
	effects.ring(position, Color(1.0, 0.7, 0.3, 0.55), 0.35, 2.0, 0.3, 0.08, 0.7)
	add_shake(1.5)


func on_facehugger_deflected(position: Vector3, points: int) -> void:
	kills += 1
	score += points
	effects.popup(position + Vector3(0.0, 1.4, 0.0), "СОРВАН +%d" % points, Color(0.6, 1.0, 0.6), 38)
	effects.burst(position + Vector3(0.0, 1.3, 0.0), Color(0.55, 1.0, 0.55, 0.9), 22, 4.5, 0.6, 0.09, 6.0)
	effects.ring(Vector3(position.x, 0.0, position.z), Color(0.5, 1.0, 0.6, 0.65), 0.4, 2.8, 0.45, 0.09, 0.8)
	add_shake(4.0)


func on_player_hugged(_hugger: Node) -> void:
	_times_hugged += 1
	hud.show_message("ЛИЦЕХВАТ ВЦЕПИЛСЯ — ЖМИ ПРОБЕЛ, ЧТОБЫ СОРВАТЬ", Color(1.0, 0.45, 0.35), 4.0)
	add_shake(10.0)
	effects.burst(player.global_position + Vector3(0.0, 1.55, 0.0), Color(1.0, 0.7, 0.3, 0.9), 20, 3.5, 0.6, 0.08, 8.0)
	Sfx.play("hug_attach", 1.0, -2.0)


func on_hug_escaped() -> void:
	hud.show_message("ТЫ СОРВАЛ ЛИЦЕХВАТА — ОН МЁРТВ", Color(0.55, 1.0, 0.65), 2.6)


func on_crab_killed(position: Vector3, unborn: bool, points: int) -> void:
	kills += 1
	score += points
	var color := Color(0.62, 1.0, 0.5) if unborn else Color(1.0, 0.72, 0.34)
	effects.popup(position + Vector3(0.0, 1.1, 0.0), "+%d" % points, color, 34)
	effects.burst(position + Vector3(0.0, 0.35, 0.0), Color(0.55, 0.16, 0.22, 0.9), 18, 5.2, 0.6, 0.1, 11.0)
	effects.ring(position, Color(0.95, 0.32, 0.3, 0.5), 0.4, 2.2, 0.32, 0.08, 0.7)
	add_shake(1.8)


func on_alien_killed(position: Vector3, variant: String, points: int) -> void:
	kills += 1
	aliens_killed += 1
	score += points
	var color := Color(0.62, 1.0, 0.4) if variant == "xeno" else Color(0.86, 0.92, 0.4)
	effects.popup(position + Vector3(0.0, 2.5, 0.0), "+%d" % points, color, 40)
	effects.burst(position + Vector3(0.0, 1.0, 0.0), Color(0.35, 0.95, 0.2, 0.95), 30, 6.5, 0.8, 0.12, 11.0)
	effects.burst(position + Vector3(0.0, 0.6, 0.0), Color(0.12, 0.35, 0.08, 0.9), 16, 3.5, 0.6, 0.16, 8.0)
	effects.ring(position, Color(0.55, 1.0, 0.3, 0.65), 0.5, 3.2, 0.5, 0.1, 0.8)
	add_shake(3.2)
	if not _first_alien_kill_message:
		_first_alien_kill_message = true
		hud.show_message("ЧУЖОЙ УНИЧТОЖЕН — АРЕНА СТАЛА ЧИЩЕ", Color(0.65, 1.0, 0.45), 2.6)


func on_player_hurt(amount: int) -> void:
	hud.on_hurt()
	add_shake(8.0)
	effects.burst(player.global_position + Vector3(0.0, 1.0, 0.0), Color(0.8, 0.08, 0.1, 0.85), 15, 4.0, 0.5, 0.08, 9.0)
	Sfx.play("hurt", randf_range(0.92, 1.05), -3.0)
	if player.health <= 25 and not _low_health_message:
		_low_health_message = true
		hud.show_message("КРИТИЧЕСКОЕ СОСТОЯНИЕ — ДОЖИВИ ДО КОНЦА ВОЛНЫ", Color(1.0, 0.3, 0.3), 3.0)


func on_player_died() -> void:
	state = "gameover"
	ending_id = "dead"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	hud.clear_events()
	add_shake(15.0)
	effects.burst(player.global_position + Vector3(0.0, 0.9, 0.0), Color(0.85, 0.06, 0.08, 0.95), 38, 6.5, 0.9, 0.12, 10.0)
	effects.ring(player.global_position, Color(1.0, 0.18, 0.2, 0.65), 0.5, 4.5, 0.6, 0.12, 0.9)
	Sfx.play("gameover", 1.0, -2.0)


func on_player_infected() -> void:
	state = "gameover"
	ending_id = "infected"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	hud.clear_events()
	add_shake(15.0)
	effects.burst(player.global_position + Vector3(0.0, 1.2, 0.0), Color(0.55, 0.9, 0.25, 0.95), 42, 5.5, 0.9, 0.12, 8.0)
	effects.ring(player.global_position, Color(0.7, 1.0, 0.35, 0.7), 0.5, 4.0, 0.6, 0.12, 0.9)
	Sfx.play("infected", 1.0, -2.0)


func _trigger_victory() -> void:
	if state != "playing":
		return
	state = "victory"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	hud.clear_events()
	var health_ratio := float(player.health) / float(maxf(1.0, float(player.max_health)))
	if health_ratio >= 0.8 and _times_hugged == 0:
		ending_id = "perfect"
	elif health_ratio <= 0.25:
		ending_id = "pyrrhic"
	else:
		ending_id = "evac"
	add_shake(6.0)
	effects.burst(player.global_position + Vector3(0.0, 1.0, 0.0), Color(1.0, 0.85, 0.4, 0.95), 40, 7.0, 1.0, 0.1, 7.0)
	effects.ring(player.global_position, Color(0.55, 1.0, 0.65, 0.8), 0.5, 5.0, 0.8, 0.12, 1.2)
	Sfx.play("victory", 1.0, -2.0)


func _set_paused(paused: bool) -> void:
	if paused:
		if state != "playing":
			return
		state = "paused"
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		if state != "paused":
			return
		state = "playing"
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func add_shake(amount: float) -> void:
	shake = minf(22.0, maxf(shake, amount * Settings.screen_shake))


func _update_camera(delta: float) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(player):
		return
	var target_position := player.global_position + CAMERA_OFFSET
	var smooth := 1.0 - exp(-delta * 6.5)
	camera.global_position = camera.global_position.lerp(target_position, smooth)
	shake = move_toward(shake, 0.0, delta * 28.0)
	var shake_offset := Vector3.ZERO
	if shake > 0.01:
		shake_offset = Vector3(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-0.55, 0.55),
			_rng.randf_range(-1.0, 1.0)
		) * shake * 0.012
	var look_target := player.global_position + Vector3(0.0, 0.8, 0.0) + shake_offset * 0.45
	camera.look_at(look_target, Vector3.UP)
	camera.h_offset = shake_offset.x
	camera.v_offset = shake_offset.y


func _update_lights(delta: float) -> void:
	if is_instance_valid(_center_light):
		_center_light.light_energy = 2.1 + sin(_time * 1.7) * 0.18
	for i in _flicker_lights.size():
		var light := _flicker_lights[i]
		if not is_instance_valid(light):
			continue
		var base: float = _flicker_base[i]
		var flicker := 0.82 + 0.18 * sin(_time * 13.0 + float(i) * 2.4)
		if fmod(_time + float(i) * 0.7, 4.8) < 0.16:
			flicker *= 0.35
		light.light_energy = base * flicker


func _setup_input_actions() -> void:
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("move_forward", [KEY_W, KEY_UP])
	_add_key_action("move_back", [KEY_S, KEY_DOWN])
	_add_key_action("jump", [KEY_SPACE])
	_add_key_action("pause", [KEY_ESCAPE])
	_add_key_action("restart", [KEY_R])
	_add_key_action("menu", [KEY_M])
	_add_mouse_action("shoot", MOUSE_BUTTON_LEFT)


func _add_key_action(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func _add_mouse_action(action: StringName, button: MouseButton) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.006, 0.012, 0.018, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.2, 0.4, 0.36, 1.0)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.05
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.05, 0.16, 0.14, 1.0)
	environment.fog_light_energy = 0.55
	environment.fog_density = 0.012
	environment.fog_sky_affect = 0.0
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.04
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 1.05
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -38.0, 0.0)
	sun.light_color = Color(0.72, 0.88, 0.84, 1.0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

	_center_light = OmniLight3D.new()
	_center_light.position = Vector3(0.0, 7.0, 0.0)
	_center_light.light_color = Color(0.25, 1.0, 0.65, 1.0)
	_center_light.light_energy = 2.1
	_center_light.omni_range = 30.0
	_center_light.shadow_enabled = false
	add_child(_center_light)

	var warm_fill := OmniLight3D.new()
	warm_fill.position = Vector3(-8.0, 5.0, -7.0)
	warm_fill.light_color = Color(1.0, 0.52, 0.24, 1.0)
	warm_fill.light_energy = 1.0
	warm_fill.omni_range = 15.0
	add_child(warm_fill)

	for corner in [Vector3(-17.0, 3.4, -17.0), Vector3(17.0, 3.4, -17.0), Vector3(-17.0, 3.4, 17.0), Vector3(17.0, 3.4, 17.0)]:
		var emergency := OmniLight3D.new()
		emergency.position = corner
		emergency.light_color = Color(1.0, 0.16, 0.12, 1.0)
		emergency.light_energy = 1.4
		emergency.omni_range = 10.0
		add_child(emergency)
		_flicker_lights.append(emergency)
		_flicker_base.append(1.4)


func _build_world() -> void:
	var outer_floor := PlaneMesh.new()
	outer_floor.size = Vector2(110.0, 110.0)
	MF.add_mesh(self, outer_floor, Vector3(0.0, -0.05, 0.0), Color(0.012, 0.02, 0.022), {"roughness": 0.95, "metallic": 0.0})

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(ARENA_SIZE, ARENA_SIZE)
	var floor_material := ShaderMaterial.new()
	floor_material.shader = load("res://shaders/floor.gdshader")
	floor_mesh.material = floor_material
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	floor_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_instance)

	_add_static_box(Vector3(0.0, -0.3, 0.0), Vector3(ARENA_SIZE, 0.6, ARENA_SIZE))

	var wall_color := Color(0.045, 0.07, 0.075)
	_add_wall(Vector3(0.0, 2.0, -ARENA_HALF), Vector3(ARENA_SIZE, 4.0, 0.8), wall_color)
	_add_wall(Vector3(0.0, 2.0, ARENA_HALF), Vector3(ARENA_SIZE, 4.0, 0.8), wall_color)
	_add_wall(Vector3(-ARENA_HALF, 2.0, 0.0), Vector3(0.8, 4.0, ARENA_SIZE), wall_color)
	_add_wall(Vector3(ARENA_HALF, 2.0, 0.0), Vector3(0.8, 4.0, ARENA_SIZE), wall_color)

	var teal := Color(0.22, 1.0, 0.62)
	var amber := Color(1.0, 0.5, 0.16)
	for y in [1.1, 3.0]:
		_add_glow_strip(Vector3(0.0, y, -ARENA_HALF + 0.44), Vector3(40.0, 0.07, 0.05), teal)
		_add_glow_strip(Vector3(0.0, y, ARENA_HALF - 0.44), Vector3(40.0, 0.07, 0.05), teal)
		_add_glow_strip(Vector3(-ARENA_HALF + 0.44, y, 0.0), Vector3(0.05, 0.07, 40.0), teal)
		_add_glow_strip(Vector3(ARENA_HALF - 0.44, y, 0.0), Vector3(0.05, 0.07, 40.0), teal)

	for x in range(-18, 19, 6):
		_add_glow_strip(Vector3(float(x), 2.1, -ARENA_HALF + 0.45), Vector3(0.05, 1.9, 0.04), teal, 1.1)
		_add_glow_strip(Vector3(float(x), 2.1, ARENA_HALF - 0.45), Vector3(0.05, 1.9, 0.04), teal, 1.1)
	for z in range(-18, 19, 6):
		_add_glow_strip(Vector3(-ARENA_HALF + 0.45, 2.1, float(z)), Vector3(0.04, 1.9, 0.05), teal, 1.1)
		_add_glow_strip(Vector3(ARENA_HALF - 0.45, 2.1, float(z)), Vector3(0.04, 1.9, 0.05), teal, 1.1)

	for panel in [
		{"position": Vector3(-11.0, 2.35, -ARENA_HALF + 0.43), "size": Vector3(4.0, 0.9, 0.04), "color": amber},
		{"position": Vector3(10.0, 2.35, -ARENA_HALF + 0.43), "size": Vector3(4.0, 0.9, 0.04), "color": teal},
		{"position": Vector3(-10.0, 2.35, ARENA_HALF - 0.43), "size": Vector3(4.0, 0.9, 0.04), "color": teal},
		{"position": Vector3(11.0, 2.35, ARENA_HALF - 0.43), "size": Vector3(4.0, 0.9, 0.04), "color": amber},
		{"position": Vector3(-ARENA_HALF + 0.43, 2.35, -10.0), "size": Vector3(0.04, 0.9, 4.0), "color": teal},
		{"position": Vector3(ARENA_HALF - 0.43, 2.35, 10.0), "size": Vector3(0.04, 0.9, 4.0), "color": amber},
	]:
		MF.add_box(self, panel["size"], panel["position"], panel["color"], {
			"emission": panel["color"],
			"energy": 1.5,
			"unshaded": true,
			"cast_shadow": GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		})

	for corner in [Vector3(-21.15, 2.4, -21.15), Vector3(21.15, 2.4, -21.15), Vector3(-21.15, 2.4, 21.15), Vector3(21.15, 2.4, 21.15)]:
		MF.add_box(self, Vector3(1.5, 4.8, 1.5), corner, Color(0.035, 0.055, 0.06), {"metallic": 0.45, "roughness": 0.55})
		MF.add_box(self, Vector3(1.62, 0.12, 1.62), Vector3(corner.x, 2.75, corner.z), amber, {
			"emission": amber,
			"energy": 2.0,
			"unshaded": true,
			"cast_shadow": GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		})

	for pipe in [
		{"position": Vector3(0.0, 3.85, -20.6), "rotation": Vector3(0.0, 0.0, PI * 0.5), "radius": 0.14},
		{"position": Vector3(0.0, 3.85, 20.6), "rotation": Vector3(0.0, 0.0, PI * 0.5), "radius": 0.14},
		{"position": Vector3(-20.6, 3.85, 0.0), "rotation": Vector3(PI * 0.5, 0.0, 0.0), "radius": 0.14},
		{"position": Vector3(20.6, 3.85, 0.0), "rotation": Vector3(PI * 0.5, 0.0, 0.0), "radius": 0.14},
		{"position": Vector3(0.0, 3.55, -20.2), "rotation": Vector3(0.0, 0.0, PI * 0.5), "radius": 0.07},
		{"position": Vector3(0.0, 3.55, 20.2), "rotation": Vector3(0.0, 0.0, PI * 0.5), "radius": 0.07},
	]:
		MF.add_cylinder(self, pipe["radius"], 41.0, pipe["position"], Color(0.07, 0.1, 0.1), {
			"rotation": pipe["rotation"],
			"metallic": 0.5,
			"roughness": 0.45,
		})

	_add_glow_strip(Vector3(0.0, 0.025, -20.8), Vector3(39.0, 0.02, 0.08), amber, 0.8)
	_add_glow_strip(Vector3(0.0, 0.025, 20.8), Vector3(39.0, 0.02, 0.08), amber, 0.8)

	var emblem := TorusMesh.new()
	emblem.inner_radius = 2.38
	emblem.outer_radius = 2.52
	emblem.rings = 48
	emblem.ring_segments = 6
	MF.add_mesh(self, emblem, Vector3(0.0, 0.025, 0.0), teal, {
		"emission": teal,
		"energy": 1.15,
		"unshaded": true,
		"cast_shadow": GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
	})
	var emblem_inner := TorusMesh.new()
	emblem_inner.inner_radius = 0.92
	emblem_inner.outer_radius = 1.0
	emblem_inner.rings = 40
	emblem_inner.ring_segments = 6
	MF.add_mesh(self, emblem_inner, Vector3(0.0, 0.025, 0.0), teal, {
		"emission": teal,
		"energy": 0.8,
		"unshaded": true,
		"cast_shadow": GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
	})
	MF.add_cylinder(self, 0.34, 0.03, Vector3(0.0, 0.015, 0.0), teal, {
		"emission": teal,
		"energy": 0.7,
		"unshaded": true,
		"cast_shadow": GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
	})
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var marker_position := Vector3(cos(angle) * 1.68, 0.02, sin(angle) * 1.68)
		MF.add_box(self, Vector3(0.24, 0.02, 0.06), marker_position, amber, {
			"rotation": Vector3(0.0, -angle, 0.0),
			"emission": amber,
			"energy": 0.8,
			"unshaded": true,
			"cast_shadow": GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		})

	for pad_position in [Vector3(-12.0, 0.02, -12.0), Vector3(12.0, 0.02, -12.0), Vector3(-12.0, 0.02, 12.0), Vector3(12.0, 0.02, 12.0)]:
		MF.add_cylinder(self, 1.25, 0.04, pad_position, Color(0.035, 0.055, 0.055), {"metallic": 0.4, "roughness": 0.6})
		var pad_ring := TorusMesh.new()
		pad_ring.inner_radius = 1.18
		pad_ring.outer_radius = 1.28
		pad_ring.rings = 28
		pad_ring.ring_segments = 5
		MF.add_mesh(self, pad_ring, pad_position + Vector3(0.0, 0.025, 0.0), teal, {
			"emission": teal,
			"energy": 0.75,
			"unshaded": true,
			"cast_shadow": GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		})

	for crate in [
		{"position": Vector3(-20.5, 0.65, -7.0), "size": Vector3(1.4, 1.3, 1.4)},
		{"position": Vector3(20.5, 0.55, -9.5), "size": Vector3(1.2, 1.1, 1.2)},
		{"position": Vector3(-20.5, 0.55, 8.5), "size": Vector3(1.2, 1.1, 1.2)},
		{"position": Vector3(20.5, 0.65, 6.5), "size": Vector3(1.4, 1.3, 1.4)},
		{"position": Vector3(-10.5, 0.6, 20.5), "size": Vector3(1.3, 1.2, 1.3)},
		{"position": Vector3(11.5, 0.5, 20.5), "size": Vector3(1.1, 1.0, 1.1)},
	]:
		_add_crate(crate["position"], crate["size"])

	# Distant silhouettes outside the arena.
	for i in 14:
		var angle := TAU * float(i) / 14.0
		var distance := _rng.randf_range(30.0, 42.0)
		var height := _rng.randf_range(7.0, 17.0)
		var width := _rng.randf_range(2.5, 6.0)
		var tower_position := Vector3(cos(angle) * distance, height * 0.5 - 0.5, sin(angle) * distance)
		MF.add_box(self, Vector3(width, height, width), tower_position, Color(0.014, 0.024, 0.027), {"roughness": 0.9})
		if i % 2 == 0:
			var light_color := teal if i % 4 == 0 else amber
			MF.add_box(self, Vector3(width * 0.7, 0.08, 0.05), tower_position + Vector3(0.0, height * 0.28, -width * 0.51), light_color, {
				"emission": light_color,
				"energy": 1.2,
				"unshaded": true,
				"cast_shadow": GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			})


func _add_wall(center: Vector3, size: Vector3, color: Color) -> void:
	var body := _add_static_box(center, size)
	MF.add_box(body, size, Vector3.ZERO, color, {"metallic": 0.4, "roughness": 0.62})


func _add_static_box(position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body


func _add_glow_strip(position: Vector3, size: Vector3, color: Color, energy: float = 2.2) -> void:
	MF.add_box(self, size, position, color, {
		"emission": color,
		"energy": energy,
		"unshaded": true,
		"cast_shadow": GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
	})


func _add_crate(position: Vector3, size: Vector3) -> void:
	var body := _add_static_box(position, size)
	MF.add_box(body, size, Vector3.ZERO, Color(0.12, 0.14, 0.11), {"metallic": 0.25, "roughness": 0.8})
	MF.add_box(body, Vector3(size.x * 0.84, 0.035, size.z * 0.84), Vector3(0.0, size.y * 0.5 + 0.018, 0.0), Color(0.75, 0.45, 0.14), {
		"emission": Color(0.9, 0.45, 0.12),
		"energy": 0.9,
		"unshaded": true,
		"cast_shadow": GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
	})
	MF.add_box(body, Vector3(size.x * 0.7, size.y * 0.12, 0.03), Vector3(0.0, 0.0, -size.z * 0.5 - 0.016), Color(0.45, 0.6, 0.4), {
		"emission": Color(0.3, 0.8, 0.45),
		"energy": 0.6,
		"unshaded": true,
		"cast_shadow": GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
	})


func _build_effects() -> void:
	effects = EffectsScript.new()
	add_child(effects)


func _build_ambient() -> void:
	ambient = AmbientScript.new()
	add_child(ambient)


func _build_player() -> void:
	player = PlayerScript.new()
	player.setup(self)
	player.position = Vector3(0.0, 0.15, 4.0)
	add_child(player)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.near = 0.1
	camera.far = 120.0
	camera.position = player.global_position + CAMERA_OFFSET
	add_child(camera)
	camera.look_at(player.global_position + Vector3(0.0, 0.8, 0.0), Vector3.UP)
	camera.current = true


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(1.0, 1.0, 1.0, 1.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/vignette.gdshader")
	rect.material = material
	layer.add_child(rect)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	hud = HudScript.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(hud)
	hud.setup(self)


func _build_main_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 110
	add_child(layer)
	main_menu = MainMenuScript.new()
	main_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(main_menu)
	main_menu.setup(self)


func _return_to_menu() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().reload_current_scene()
