extends Node

const EggScript = preload("res://scripts/egg.gd")

var main: Node
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	await _run_tests()
	await get_tree().create_timer(0.6).timeout
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	Sfx.stop_all()
	await get_tree().create_timer(1.2).timeout
	print("TEST_FAILURES: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		print("FAIL: ", label)


func _run_tests() -> void:
	Settings.reset_defaults()
	_check(main.main_menu != null and main.main_menu.visible, "main menu is visible in menu state")
	_check(main.main_menu.get_page() == "main", "main menu opens on the main page")
	main.main_menu.show_page("settings")
	_check(main.main_menu.get_page() == "settings" and main.main_menu._settings_page.visible, "settings page opens")
	main.main_menu.show_page("controls")
	_check(main.main_menu.get_page() == "controls" and main.main_menu._controls_page.visible, "controls page opens")
	main.main_menu.show_page("main")
	_check(main.main_menu.get_page() == "main", "main menu returns to the main page")

	main.main_menu._on_play_pressed()
	await get_tree().physics_frame
	_check(main.state == "playing", "play button starts the game")
	_check(not main.main_menu.visible, "main menu hides when the game starts")

	var starting_medkits := get_tree().get_nodes_in_group("medkits")
	_check(starting_medkits.size() == 3, "three medkits spawn at game start")
	var medkits_inside := true
	for medkit in starting_medkits:
		var medkit_position: Vector3 = medkit.global_position
		if medkit_position.y < 1.0 or absf(medkit_position.x) > 18.5 or absf(medkit_position.z) > 18.5:
			medkits_inside = false
	_check(medkits_inside, "medkits float inside the arena")
	main.medkit_respawn_timer = 9999.0
	for medkit in starting_medkits:
		medkit.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	for group_name in ["eggs", "headcrabs", "aliens", "facehuggers"]:
		for node in get_tree().get_nodes_in_group(group_name):
			node.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame

	main.wave_active = false
	main.pending_eggs = 0
	main.pending_aliens = 0
	main.alien_spawn_timer = 999.0
	main.wave_clear_timer = 0.0
	var player = main.player

	var start_x: float = player.global_position.x
	Input.action_press("move_right")
	for i in 25:
		await get_tree().physics_frame
	Input.action_release("move_right")
	_check(player.global_position.x > start_x + 0.5, "player runs right")

	Settings.set_master_volume(2.0)
	_check(is_equal_approx(Settings.master_volume, 1.0), "volume setting clamps to 100 percent")
	Settings.set_master_volume(0.5)
	_check(is_equal_approx(Settings.master_volume, 0.5), "volume setting applies")
	Settings.reset_defaults()

	Settings.set_screen_shake(0.0)
	main.shake = 0.0
	main.add_shake(10.0)
	_check(main.shake == 0.0, "screen shake setting can disable camera shake")
	Settings.set_screen_shake(1.0)
	main.add_shake(10.0)
	_check(main.shake > 0.0, "camera shake works at full strength")
	main.shake = 0.0

	Settings.set_laser_sight(false)
	player._update_laser(player.global_position + Vector3(4.0, 0.8, 0.0))
	_check(not player._laser.visible, "laser sight setting hides the aim laser")
	Settings.set_laser_sight(true)
	player._update_laser(player.global_position + Vector3(4.0, 0.8, 0.0))
	_check(player._laser.visible, "laser sight setting shows the aim laser")
	Settings.reset_defaults()

	await get_tree().create_timer(0.4).timeout
	_check(player.is_on_floor(), "player is on floor before jump")
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	_check(not player.is_on_floor() and player.velocity.y > 0.0, "player jumps")
	await get_tree().create_timer(0.9).timeout

	var health_before: int = player.health
	player.take_damage(10, player.global_position + Vector3(2.0, 0.0, 0.0))
	_check(player.health == health_before - 10, "player takes damage")
	player.take_damage(10, player.global_position + Vector3(2.0, 0.0, 0.0))
	_check(player.health == health_before - 10, "invulnerability prevents instant second hit")
	await get_tree().create_timer(0.85).timeout
	player.take_damage(10, player.global_position + Vector3(2.0, 0.0, 0.0))
	_check(player.health == health_before - 20, "damage works after invulnerability ends")

	var egg = EggScript.new()
	egg.setup(main, 30.0)
	egg.position = player.global_position + Vector3(4.0, 8.0, 0.0)
	main.add_child(egg)
	await get_tree().create_timer(1.3).timeout
	_check(egg._landed and egg.hp == 3, "egg falls and lands")

	for shot in 3:
		player.shoot_at(egg.global_position + Vector3(0.0, 0.8, 0.0))
		await get_tree().physics_frame
		if shot < 2:
			_check(egg.hp == 2 - shot, "shot %d damages egg" % (shot + 1))
	await get_tree().create_timer(0.2).timeout
	_check(not is_instance_valid(egg), "third shot breaks egg")

	var unborn_count := 0
	var adult_count := 0
	for crab in get_tree().get_nodes_in_group("headcrabs"):
		if crab.unborn:
			unborn_count += 1
			_check(crab.body_scale < 0.8, "unborn crab is smaller")
			_check(crab.contact_damage < 10, "unborn crab deals less damage")
			_check(crab.max_hp == 1, "unborn crab has 1 hp")
		else:
			adult_count += 1
	_check(unborn_count >= 2, "breaking egg spawns two unborn crabs")

	var hatch_egg = EggScript.new()
	hatch_egg.setup(main, 0.3)
	hatch_egg.position = player.global_position + Vector3(-5.0, 0.2, 0.0)
	main.add_child(hatch_egg)
	await get_tree().create_timer(1.0).timeout
	adult_count = 0
	for crab in get_tree().get_nodes_in_group("headcrabs"):
		if not crab.unborn:
			adult_count += 1
	_check(adult_count == 2, "ignored egg hatches into two adult crabs")

	var unborn_to_kill = null
	for crab in get_tree().get_nodes_in_group("headcrabs"):
		if crab.unborn:
			unborn_to_kill = crab
			break
	if unborn_to_kill != null:
		unborn_to_kill.take_damage(1, Vector3.RIGHT)
		await get_tree().physics_frame
		_check(unborn_to_kill._dead, "one shot kills an unborn crab")
	else:
		_check(false, "found unborn crab to kill")

	for crab in get_tree().get_nodes_in_group("headcrabs"):
		crab.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame

	main.score = 0
	main.kills = 0
	var target_crab = main.spawn_headcrab(player.global_position + Vector3(4.0, 0.2, 0.0), false, Vector3.LEFT)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var crab_hp_before: int = target_crab.hp
	player.shoot_at(target_crab.global_position + Vector3(0.0, 0.45, 0.0))
	await get_tree().create_timer(0.12).timeout
	_check(target_crab.hp < crab_hp_before, "shot hits an adult crab")

	target_crab.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame

	# Downloaded alien models and combat.
	var alien = main.spawn_alien(player.global_position + Vector3(6.0, 0.15, 0.0), "xeno")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(is_instance_valid(alien) and alien.variant == "xeno", "xenomorph alien spawns")
	_check(alien._asset != null and alien._asset.find_children("*", "MeshInstance3D", true, false).size() > 10, "xenomorph model has detailed meshes")
	_check(alien.max_hp >= 6, "xenomorph has alien health")

	var alien_hp_before: int = alien.hp
	player.shoot_at(alien.global_position + Vector3(0.0, 1.1, 0.0))
	await get_tree().create_timer(0.12).timeout
	_check(alien.hp < alien_hp_before, "shot hits a xenomorph")

	var alien_score_before: int = main.score
	for i in alien.max_hp + 2:
		alien.take_damage(1, Vector3.RIGHT)
	await get_tree().physics_frame
	_check(alien._dead, "xenomorph dies from damage")
	_check(main.aliens_killed >= 1 and main.score > alien_score_before, "alien kill awards score")

	var runner = main.spawn_alien(player.global_position + Vector3(-6.0, 0.15, 0.0), "runner")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(is_instance_valid(runner) and runner.variant == "runner", "runner alien spawns")
	_check(runner._anim_player != null and runner._anim_player.has_animation("Run") and runner._anim_player.has_animation("Death"), "runner model has downloaded animations")

	main._set_paused(true)
	_check(main.state == "paused" and get_tree().paused, "pause freezes the game")
	main._set_paused(false)
	_check(main.state == "playing" and not get_tree().paused, "unpause resumes the game")

	for crab in get_tree().get_nodes_in_group("headcrabs"):
		crab.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame

	await get_tree().create_timer(0.8).timeout
	var health_before_contact: int = player.health
	var contact_crab = main.spawn_headcrab(player.global_position + Vector3(0.9, 0.2, 0.0), false, Vector3.LEFT)
	await get_tree().create_timer(1.2).timeout
	_check(player.health < health_before_contact, "headcrab contact damages the player")
	contact_crab.queue_free()

	await get_tree().create_timer(0.8).timeout
	var health_before_alien: int = player.health
	var contact_alien = main.spawn_alien(player.global_position + Vector3(1.0, 0.15, 0.0), "xeno")
	contact_alien._attack_cooldown = 0.0
	await get_tree().create_timer(1.0).timeout
	_check(player.health < health_before_alien, "alien contact damages the player")
	contact_alien.queue_free()

	# Medkits: pickup, lifetime and 20 second respawn cycle.
	for group_name in ["headcrabs", "aliens"]:
		for node in get_tree().get_nodes_in_group(group_name):
			node.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	main.set_process(false)
	for medkit in get_tree().get_nodes_in_group("medkits"):
		medkit.queue_free()
	await get_tree().process_frame
	main.medkit_respawn_timer = 0.0
	player.health = 40
	var pickup_medkit = main.spawn_medkit(player.global_position + Vector3(0.0, 1.2, 0.0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(player.health == 70, "medkit pickup heals the player")
	_check(not is_instance_valid(pickup_medkit), "medkit is consumed on pickup")
	_check(main.medkit_respawn_timer >= 19.0, "last medkit starts 20 second respawn timer")

	var expiring_medkit = main.spawn_medkit(Vector3(10.0, 1.55, 10.0))
	expiring_medkit.lifetime = 0.2
	await get_tree().create_timer(0.6).timeout
	_check(not is_instance_valid(expiring_medkit), "medkit expires when its lifetime ends")
	_check(main.medkit_respawn_timer >= 19.0, "expired medkit restarts the 20 second timer")
	_check(get_tree().get_nodes_in_group("medkits").is_empty(), "no medkits remain before respawn")
	main._update_medkits(19.0)
	_check(get_tree().get_nodes_in_group("medkits").is_empty(), "medkits do not respawn before 20 seconds")
	main._update_medkits(1.2)
	var respawned_medkits := get_tree().get_nodes_in_group("medkits")
	_check(respawned_medkits.size() == 3, "three medkits respawn after 20 seconds")
	main.set_process(true)

	# A wave is only cleared after the last alien is dead.
	for group_name in ["eggs", "headcrabs", "aliens"]:
		for node in get_tree().get_nodes_in_group(group_name):
			node.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	main.wave_active = true
	main.pending_eggs = 0
	main.pending_aliens = 1
	main.alien_spawn_timer = 0.0
	main.wave_clear_timer = 0.0
	main._update_wave(0.016)
	var wave_aliens := get_tree().get_nodes_in_group("aliens")
	_check(not wave_aliens.is_empty(), "queued alien spawns during a wave")
	_check(main.pending_aliens == 0, "queued alien is consumed")
	_check(main.wave_active, "wave stays active while an alien is alive")
	var wave_alien = wave_aliens[0]
	wave_alien.take_damage(999, Vector3.RIGHT)
	await get_tree().physics_frame
	main._update_wave(0.016)
	_check(not main.wave_active, "wave completes after the last alien dies")

	main.wave = 0
	main._start_wave()
	_check(main.wave == 1 and main.pending_aliens == 0, "wave 1 has no aliens")
	main._start_wave()
	_check(main.wave == 2 and main.pending_aliens == 1, "wave 2 queues the first alien")

	# Facehuggers: egg type, spawn counts, combat and capture.
	main.set_process(false)
	main.state = "playing"
	main.wave_active = false
	main.pending_eggs = 0
	main.pending_aliens = 0
	main.wave_clear_timer = 0.0
	main.score = 0
	main.kills = 0
	main._times_hugged = 0
	main.ending_id = ""
	player.dead = false
	player.hugged = false
	player.health = 100
	for group_name in ["eggs", "headcrabs", "aliens", "facehuggers"]:
		for node in get_tree().get_nodes_in_group(group_name):
			node.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame

	main.wave = 1
	_check(main._pick_egg_type() == "headcrab", "facehugger eggs do not appear before wave 3")
	main.wave = 3
	var picked_hugger_eggs := 0
	var picked_crab_eggs := 0
	for i in 120:
		if main._pick_egg_type() == "facehugger":
			picked_hugger_eggs += 1
		else:
			picked_crab_eggs += 1
	_check(picked_hugger_eggs > 0 and picked_crab_eggs > 0, "facehugger eggs start appearing from wave 3")
	main.wave = 1

	var hugger_egg = EggScript.new()
	hugger_egg.setup(main, 30.0, "facehugger")
	hugger_egg.position = player.global_position + Vector3(-4.0, 8.0, 0.0)
	main.add_child(hugger_egg)
	await get_tree().create_timer(1.3).timeout
	_check(hugger_egg._landed and hugger_egg.egg_type == "facehugger" and hugger_egg.hp == 3, "facehugger egg falls and lands with 3 hp")

	for shot in 3:
		player.shoot_at(hugger_egg.global_position + Vector3(0.0, 0.8, 0.0))
		await get_tree().physics_frame
		if shot < 2:
			_check(hugger_egg.hp == 2 - shot, "shot %d damages facehugger egg" % (shot + 1))
	await get_tree().create_timer(0.2).timeout
	_check(not is_instance_valid(hugger_egg), "third shot breaks facehugger egg")
	_check(get_tree().get_nodes_in_group("facehuggers").size() == 1, "broken facehugger egg spawns one facehugger")

	for hugger in get_tree().get_nodes_in_group("facehuggers"):
		hugger.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame

	var hatch_hugger_egg = EggScript.new()
	hatch_hugger_egg.setup(main, 0.3, "facehugger")
	hatch_hugger_egg.position = player.global_position + Vector3(-13.0, 0.2, 0.0)
	main.add_child(hatch_hugger_egg)
	await get_tree().create_timer(1.0).timeout
	_check(get_tree().get_nodes_in_group("facehuggers").size() == 2, "ignored facehugger egg hatches into two facehuggers")

	for hugger in get_tree().get_nodes_in_group("facehuggers"):
		hugger.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame

	var target_hugger = main.spawn_facehugger(player.global_position + Vector3(7.0, 0.2, 0.0), Vector3.LEFT)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hugger_hp_before: int = target_hugger.hp
	target_hugger.take_damage(1, Vector3.RIGHT)
	_check(target_hugger.hp == hugger_hp_before - 1, "shot damages a facehugger")
	var hugger_score_before: int = main.score
	target_hugger.take_damage(99, Vector3.RIGHT)
	await get_tree().physics_frame
	_check(target_hugger._dead, "facehugger dies from damage")
	_check(main.score > hugger_score_before and main.kills >= 1, "facehugger kill awards score")

	for hugger in get_tree().get_nodes_in_group("facehuggers"):
		hugger.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame

	main.state = "playing"
	main.ending_id = ""
	main._times_hugged = 0
	player.dead = false
	player.hugged = false
	player.health = 100
	var attach_hugger = main.spawn_facehugger(player.global_position + Vector3(0.55, 0.1, 0.0), Vector3.LEFT)
	attach_hugger._attach_cooldown = 0.0
	var attached := false
	for i in 60:
		await get_tree().physics_frame
		if player.hugged:
			attached = true
			break
	_check(attached and attach_hugger.attached, "facehugger attaches to the player")
	_check(main._times_hugged == 1, "capture is counted for the endings")

	var attached_hp: int = attach_hugger.hp
	attach_hugger.take_damage(5, Vector3.RIGHT)
	_check(attach_hugger.hp == attached_hp and not attach_hugger._dead, "attached facehugger cannot be shot off")
	var attached_hit: Dictionary = player.shoot_at(attach_hugger.global_position)
	_check(attached_hit.is_empty() or attached_hit["collider"] != attach_hugger, "gunfire cannot hit an attached facehugger")

	var escape_score_before: int = main.score
	for i in 12:
		if not player.hugged:
			break
		Input.action_press("jump")
		await get_tree().physics_frame
		Input.action_release("jump")
		await get_tree().physics_frame
	_check(not player.hugged, "mashing jump tears the facehugger off")
	_check(attach_hugger._dead, "deflected facehugger dies")
	_check(main.score >= escape_score_before + attach_hugger.score_value + 50, "escaping the hug awards bonus score")

	await get_tree().create_timer(1.2).timeout
	player.velocity = Vector3.ZERO

	# The last facehugger also has to die before a wave is cleared.
	for group_name in ["eggs", "headcrabs", "aliens", "facehuggers"]:
		for node in get_tree().get_nodes_in_group(group_name):
			node.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	main.wave = 2
	main.wave_active = true
	main.pending_eggs = 0
	main.pending_aliens = 0
	main.wave_clear_timer = 0.0
	var wave_hugger = main.spawn_facehugger(player.global_position + Vector3(10.0, 0.2, 0.0), Vector3.LEFT)
	await get_tree().physics_frame
	main._update_wave(0.016)
	_check(main.wave_active, "wave stays active while a facehugger is alive")
	wave_hugger.take_damage(999, Vector3.RIGHT)
	await get_tree().physics_frame
	main._update_wave(0.016)
	_check(not main.wave_active, "wave completes after the last facehugger dies")

	# Boss: heavy headcrab that scales with the wave and hits like a big headcrab.
	main.wave = 3
	main.wave_active = false
	main.pending_eggs = 0
	main.pending_aliens = 0
	main.wave_clear_timer = 0.0
	for group_name in ["eggs", "headcrabs", "aliens", "facehuggers"]:
		for node in get_tree().get_nodes_in_group(group_name):
			node.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	var boss_wave: CharacterBody3D = main.spawn_headcrab(main.player.global_position + Vector3(8.0, 0.6, 0.0), false, Vector3.LEFT, true)
	_check(boss_wave.boss, "boss headcrab is marked as a boss")
	_check(boss_wave.body_scale > 1.0, "boss headcrab is bigger than a normal adult")
	_check(boss_wave.max_hp > 7, "boss headcrab is tougher than a normal adult")
	_check(boss_wave.contact_damage > 10, "boss headcrab deals heavy contact damage")
	_check(boss_wave.jump_force > 6.0, "boss headcrab jumps like a heavy body")
	main.wave = 10
	var boss_final: CharacterBody3D = main.spawn_headcrab(main.player.global_position + Vector3(-8.0, 0.6, 0.0), false, Vector3.RIGHT, true)
	_check(boss_final.max_hp > boss_wave.max_hp, "boss difficulty grows between waves")
	_check(boss_final.contact_damage > boss_wave.contact_damage, "boss contact damage grows between waves")
	boss_wave.queue_free()
	boss_final.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	main.wave = 4
	main._start_wave()
	var wave4_boss: CharacterBody3D = null
	for crab in get_tree().get_nodes_in_group("headcrabs"):
		if crab.boss:
			wave4_boss = crab
			break
	_check(wave4_boss != null, "boss spawns on every wave")
	if wave4_boss != null:
		wave4_boss.queue_free()
		await get_tree().process_frame
		await get_tree().physics_frame
	for crab in get_tree().get_nodes_in_group("headcrabs"):
		crab.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame

	# Final wave and victory endings.
	_check(main.final_wave == 10, "the final wave is wave 10")
	main.wave = main.final_wave
	main.wave_active = false
	main.pending_eggs = 0
	main.pending_aliens = 0
	main.wave_clear_timer = 0.0
	main.state = "playing"
	main.ending_id = ""
	main._times_hugged = 0
	player.dead = false
	player.hugged = false
	player.health = 100
	main._complete_wave()
	_check(main.state == "victory" and main.ending_id == "perfect", "full health with no hugs gives the perfect ending")

	main.state = "playing"
	main.ending_id = ""
	main._times_hugged = 1
	player.health = 100
	main._complete_wave()
	_check(main.state == "victory" and main.ending_id == "evac", "a previous hug blocks the perfect ending")

	main.state = "playing"
	main.ending_id = ""
	main._times_hugged = 0
	player.health = 50
	main._complete_wave()
	_check(main.state == "victory" and main.ending_id == "evac" and player.health == 65, "moderate health gives the evacuation ending")

	main.state = "playing"
	main.ending_id = ""
	main._times_hugged = 0
	player.health = 10
	main._complete_wave()
	_check(main.state == "victory" and main.ending_id == "pyrrhic" and player.health == 25, "surviving at 25 hp or less gives the pyrrhic ending")

	# Infection ending: a second capture that is not resisted.
	main.state = "playing"
	main.ending_id = ""
	player.dead = false
	player.hugged = false
	player.health = 100
	player.velocity = Vector3.ZERO
	var infect_hugger = main.spawn_facehugger(player.global_position + Vector3(0.55, 0.1, 0.0), Vector3.LEFT)
	infect_hugger._attach_cooldown = 0.0
	var infected_attach := false
	for i in 60:
		await get_tree().physics_frame
		if player.hugged:
			infected_attach = true
			break
	_check(infected_attach, "a second facehugger can attach after an escape")
	await get_tree().create_timer(4.4).timeout
	_check(player.dead and main.state == "gameover" and main.ending_id == "infected", "unresisted facehugger infection ends the game")

	player.dead = false
	player.hugged = false
	player.health = 100
	player._invulnerable = 0.0
	main.state = "playing"
	main.ending_id = ""
	player.take_damage(999, player.global_position + Vector3(1.0, 0.0, 0.0))
	_check(main.state == "gameover" and main.ending_id == "dead", "normal death sets the dead ending")
