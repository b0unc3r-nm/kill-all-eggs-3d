extends Node

## Persistent user settings: audio, camera shake, fullscreen and aim laser.
## Stored in user://settings.cfg and applied immediately when changed.

signal changed

const CONFIG_PATH := "user://settings.cfg"

const DEFAULT_MASTER_VOLUME := 0.85
const DEFAULT_SCREEN_SHAKE := 1.0
const DEFAULT_FULLSCREEN := false
const DEFAULT_LASER_SIGHT := true

var master_volume := DEFAULT_MASTER_VOLUME
var screen_shake := DEFAULT_SCREEN_SHAKE
var fullscreen := DEFAULT_FULLSCREEN
var laser_sight := DEFAULT_LASER_SIGHT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		master_volume = clampf(float(config.get_value("audio", "master_volume", DEFAULT_MASTER_VOLUME)), 0.0, 1.0)
		screen_shake = clampf(float(config.get_value("game", "screen_shake", DEFAULT_SCREEN_SHAKE)), 0.0, 1.0)
		fullscreen = bool(config.get_value("video", "fullscreen", DEFAULT_FULLSCREEN))
		laser_sight = bool(config.get_value("game", "laser_sight", DEFAULT_LASER_SIGHT))
	_apply_all()
	changed.emit()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("game", "screen_shake", screen_shake)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("game", "laser_sight", laser_sight)
	config.save(CONFIG_PATH)


func set_master_volume(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(clamped, master_volume):
		return
	master_volume = clamped
	_apply_volume()
	save_settings()
	changed.emit()


func set_screen_shake(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(clamped, screen_shake):
		return
	screen_shake = clamped
	save_settings()
	changed.emit()


func set_fullscreen(value: bool) -> void:
	if value == fullscreen:
		return
	fullscreen = value
	_apply_fullscreen()
	save_settings()
	changed.emit()


func set_laser_sight(value: bool) -> void:
	if value == laser_sight:
		return
	laser_sight = value
	save_settings()
	changed.emit()


func reset_defaults() -> void:
	master_volume = DEFAULT_MASTER_VOLUME
	screen_shake = DEFAULT_SCREEN_SHAKE
	fullscreen = DEFAULT_FULLSCREEN
	laser_sight = DEFAULT_LASER_SIGHT
	_apply_all()
	save_settings()
	changed.emit()


func _apply_all() -> void:
	_apply_volume()
	_apply_fullscreen()


func _apply_volume() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master < 0:
		return
	AudioServer.set_bus_mute(master, master_volume <= 0.001)
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(master_volume, 0.001)))


func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
