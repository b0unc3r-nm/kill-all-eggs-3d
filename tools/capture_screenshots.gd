extends Node

## Dev utility: renders the main game in several states and saves PNG screenshots.
## Run with:
##   godot --path . --resolution 1280x720 res://tools/capture_screenshots.tscn

const MainScene = preload("res://scenes/main.tscn")
const EggScript = preload("res://scripts/egg.gd")
const OUT_DIR := "res://docs/screenshots"

var main: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await _shot_gameplay()
	await _shot_hug()
	await _shot_infected()
	await _shot_victory("perfect")
	await _shot_victory("evac")
	await _shot_victory("pyrrhic")
	print("SCREENSHOTS_DONE")
	get_tree().quit()


func _spawn_main() -> Node:
	main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	main.main_menu._on_play_pressed()
	await get_tree().physics_frame
	main.set_process(false)
	main.wave_active = false
	main.pending_eggs = 0
	main.pending_aliens = 0
	main.wave_clear_timer = 0.0
	for group_name in ["eggs", "headcrabs", "aliens", "facehuggers"]:
		for node in get_tree().get_nodes_in_group(group_name):
			node.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	# Let the wave banner fade before taking the screenshot.
	await get_tree().create_timer(3.0).timeout
	return main


func _clear_main() -> void:
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s" % [OUT_DIR, file_name])


func _force_hug() -> Node:
	var player = main.player
	var hugger = main.spawn_facehugger(player.global_position + Vector3(0.0, 0.0, 0.45), Vector3.FORWARD)
	hugger._attach_cooldown = 0.0
	if player.attach_facehugger(hugger):
		hugger._attach()
	return hugger


func _shot_gameplay() -> void:
	await _spawn_main()
	var player = main.player
	player._invulnerable = 999.0
	var egg = EggScript.new()
	egg.setup(main, 30.0, "facehugger")
	egg.position = player.global_position + Vector3(3.2, 7.0, -4.0)
	main.add_child(egg)
	var crab = main.spawn_headcrab(player.global_position + Vector3(-3.0, 0.2, -4.2), false, Vector3.RIGHT)
	crab.set_physics_process(false)
	var alien = main.spawn_alien(player.global_position + Vector3(4.6, 0.15, -6.0), "xeno")
	alien.set_physics_process(false)
	await get_tree().create_timer(1.5).timeout
	await _capture("gameplay.png")
	await _clear_main()


func _shot_hug() -> void:
	await _spawn_main()
	var player = main.player
	_force_hug()
	player.hug_progress = 0.45
	player.hug_time = 1.2
	await get_tree().create_timer(0.5).timeout
	await _capture("hug.png")
	await _clear_main()


func _shot_infected() -> void:
	await _spawn_main()
	var player = main.player
	_force_hug()
	await get_tree().physics_frame
	player._die_infected()
	await get_tree().create_timer(0.8).timeout
	await _capture("infected.png")
	await _clear_main()


func _shot_victory(kind: String) -> void:
	await _spawn_main()
	var player = main.player
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
	match kind:
		"perfect":
			player.health = 100
		"evac":
			player.health = 50
		"pyrrhic":
			player.health = 10
	main._complete_wave()
	await get_tree().create_timer(0.6).timeout
	await _capture("victory-%s.png" % kind)
	await _clear_main()
