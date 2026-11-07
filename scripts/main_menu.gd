extends Control

## Procedurally drawn main menu with play, settings and controls pages.
## The 3D arena stays visible behind the translucent overlay.

const BUTTON_WIDTH := 340.0
const BUTTON_HEIGHT := 52.0
const BUTTON_GAP := 12.0

var game: Node

var _page := "main"
var _time := 0.0

var _panel_style: StyleBoxFlat
var _key_style: StyleBoxFlat
var _key_accent_style: StyleBoxFlat

var _menu_box: VBoxContainer
var _settings_page: Control
var _controls_page: Control
var _main_buttons: Array[Button] = []

var _settings_panel_rect := Rect2()
var _controls_panel_rect := Rect2()

var _volume_slider: HSlider
var _volume_value: Label
var _shake_slider: HSlider
var _shake_value: Label
var _fullscreen_toggle: Button
var _laser_toggle: Button
var _settings_reset_button: Button
var _settings_back_button: Button
var _controls_back_button: Button


func setup(new_game: Node) -> void:
	game = new_game


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_style = _make_style(Color(0.012, 0.026, 0.032, 0.95), Color(0.3, 0.78, 0.6, 0.36), 12, 1)
	_key_style = _make_style(Color(0.05, 0.085, 0.09, 0.96), Color(0.42, 0.86, 0.68, 0.45), 6, 1)
	_key_accent_style = _make_style(Color(0.34, 0.18, 0.07, 0.96), Color(1.0, 0.66, 0.28, 0.75), 6, 1)
	_build_main_page()
	_build_settings_page()
	_build_controls_page()
	show_page("main")
	resized.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	queue_redraw()


func get_page() -> String:
	return _page


func show_page(page: String) -> void:
	_page = page
	_menu_box.visible = page == "main"
	_settings_page.visible = page == "settings"
	_controls_page.visible = page == "controls"
	if page == "settings":
		_refresh_settings()
		_volume_slider.call_deferred("grab_focus")
	elif page == "controls":
		_controls_back_button.call_deferred("grab_focus")
	else:
		if not _main_buttons.is_empty():
			_main_buttons[0].call_deferred("grab_focus")
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") and _page != "main":
		show_page("main")
		Sfx.play("click", 0.9, -12.0)
		get_viewport().set_input_as_handled()


func _build_main_page() -> void:
	_menu_box = VBoxContainer.new()
	_menu_box.name = "MainPage"
	_menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu_box.add_theme_constant_override("separation", int(BUTTON_GAP))
	add_child(_menu_box)

	var play_button := _make_button("ИГРАТЬ", _on_play_pressed, true)
	play_button.add_theme_font_size_override("font_size", 20)
	var settings_button := _make_button("НАСТРОЙКИ", _on_settings_pressed)
	var controls_button := _make_button("УПРАВЛЕНИЕ", _on_controls_pressed)
	var quit_button := _make_button("ВЫХОД", _on_quit_pressed)
	for button in [play_button, settings_button, controls_button, quit_button]:
		_menu_box.add_child(button)
		_main_buttons.append(button)


func _build_settings_page() -> void:
	_settings_page = Control.new()
	_settings_page.name = "SettingsPage"
	add_child(_settings_page)
	_settings_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_page.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_volume_slider = _make_slider()
	_volume_slider.value_changed.connect(_on_volume_changed)
	_settings_page.add_child(_volume_slider)
	_volume_value = _make_value_label()
	_settings_page.add_child(_volume_value)

	_shake_slider = _make_slider()
	_shake_slider.value_changed.connect(_on_shake_changed)
	_settings_page.add_child(_shake_slider)
	_shake_value = _make_value_label()
	_settings_page.add_child(_shake_value)

	_fullscreen_toggle = _make_toggle(_on_fullscreen_toggled)
	_settings_page.add_child(_fullscreen_toggle)
	_laser_toggle = _make_toggle(_on_laser_toggled)
	_settings_page.add_child(_laser_toggle)

	_settings_reset_button = _make_button("СБРОСИТЬ", _on_reset_pressed)
	_settings_reset_button.custom_minimum_size = Vector2(210.0, 46.0)
	_settings_page.add_child(_settings_reset_button)
	_settings_back_button = _make_button("НАЗАД", _on_back_pressed)
	_settings_back_button.custom_minimum_size = Vector2(210.0, 46.0)
	_settings_page.add_child(_settings_back_button)


func _build_controls_page() -> void:
	_controls_page = Control.new()
	_controls_page.name = "ControlsPage"
	add_child(_controls_page)
	_controls_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_controls_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls_back_button = _make_button("НАЗАД", _on_back_pressed)
	_controls_back_button.custom_minimum_size = Vector2(220.0, 46.0)
	_controls_page.add_child(_controls_back_button)


func _layout() -> void:
	var viewport_size := get_viewport_rect().size
	if is_instance_valid(_menu_box):
		var top := clampf(viewport_size.y * 0.40, 268.0, 340.0)
		_menu_box.position = Vector2(viewport_size.x * 0.5 - BUTTON_WIDTH * 0.5, top)
		_menu_box.size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT * 4.0 + BUTTON_GAP * 3.0)

	var settings_size := Vector2(minf(700.0, viewport_size.x - 80.0), 460.0)
	_settings_panel_rect = Rect2(
		(viewport_size.x - settings_size.x) * 0.5,
		(viewport_size.y - settings_size.y) * 0.5 - 8.0,
		settings_size.x,
		settings_size.y
	)
	_layout_settings()

	var controls_size := Vector2(minf(700.0, viewport_size.x - 80.0), 480.0)
	_controls_panel_rect = Rect2(
		(viewport_size.x - controls_size.x) * 0.5,
		(viewport_size.y - controls_size.y) * 0.5 - 8.0,
		controls_size.x,
		controls_size.y
	)
	_layout_controls()
	queue_redraw()


func _layout_settings() -> void:
	var panel := _settings_panel_rect
	if panel.size.x <= 0.0:
		return
	var slider_x := panel.position.x + 260.0
	var slider_width := panel.size.x - 400.0
	_volume_slider.position = Vector2(slider_x, panel.position.y + 116.0)
	_volume_slider.size = Vector2(slider_width, 24.0)
	_volume_value.position = Vector2(panel.end.x - 132.0, panel.position.y + 112.0)
	_volume_value.size = Vector2(88.0, 24.0)

	_shake_slider.position = Vector2(slider_x, panel.position.y + 180.0)
	_shake_slider.size = Vector2(slider_width, 24.0)
	_shake_value.position = Vector2(panel.end.x - 132.0, panel.position.y + 176.0)
	_shake_value.size = Vector2(88.0, 24.0)

	_fullscreen_toggle.position = Vector2(panel.end.x - 160.0, panel.position.y + 243.0)
	_fullscreen_toggle.size = Vector2(116.0, 38.0)
	_laser_toggle.position = Vector2(panel.end.x - 160.0, panel.position.y + 307.0)
	_laser_toggle.size = Vector2(116.0, 38.0)

	_settings_reset_button.position = Vector2(panel.position.x + 44.0, panel.position.y + 372.0)
	_settings_reset_button.size = Vector2(210.0, 46.0)
	_settings_back_button.position = Vector2(panel.end.x - 254.0, panel.position.y + 372.0)
	_settings_back_button.size = Vector2(210.0, 46.0)


func _layout_controls() -> void:
	var panel := _controls_panel_rect
	if panel.size.x <= 0.0:
		return
	_controls_back_button.position = Vector2(panel.position.x + panel.size.x * 0.5 - 110.0, panel.position.y + 400.0)
	_controls_back_button.size = Vector2(220.0, 46.0)


func _refresh_settings() -> void:
	_volume_slider.set_value_no_signal(Settings.master_volume)
	_volume_value.text = "%d%%" % roundi(Settings.master_volume * 100.0)
	_shake_slider.set_value_no_signal(Settings.screen_shake)
	_shake_value.text = "%d%%" % roundi(Settings.screen_shake * 100.0)
	_update_toggle(_fullscreen_toggle, Settings.fullscreen)
	_update_toggle(_laser_toggle, Settings.laser_sight)


func _make_button(text: String, callback: Callable, accent: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 18)
	var normal_background := Color(0.02, 0.045, 0.05, 0.94)
	var normal_border := Color(0.3, 0.78, 0.6, 0.4)
	if accent:
		normal_background = Color(0.18, 0.1, 0.035, 0.95)
		normal_border = Color(1.0, 0.68, 0.3, 0.75)
	button.add_theme_stylebox_override("normal", _make_style(normal_background, normal_border, 8, 1))
	button.add_theme_stylebox_override("hover", _make_style(Color(0.07, 0.15, 0.12, 0.97), Color(0.55, 1.0, 0.74, 0.9), 8, 2))
	button.add_theme_stylebox_override("pressed", _make_style(Color(0.22, 0.13, 0.05, 0.97), Color(1.0, 0.7, 0.3, 0.95), 8, 2))
	var focus_style := _make_style(Color(0.07, 0.15, 0.12, 0.0), Color(0.55, 1.0, 0.74, 0.9), 8, 2)
	focus_style.draw_center = false
	button.add_theme_stylebox_override("focus", focus_style)
	button.add_theme_color_override("font_color", Color(0.84, 0.97, 0.9, 0.96))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.75, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.95, 0.75, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.9, 0.6, 1.0))
	button.pressed.connect(callback)
	return button


func _make_slider() -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(300.0, 24.0)
	slider.focus_mode = Control.FOCUS_ALL
	var track := _make_style(Color(0.015, 0.035, 0.04, 0.96), Color(0.3, 0.75, 0.58, 0.35), 4, 1)
	track.content_margin_top = 8.0
	track.content_margin_bottom = 8.0
	var fill := _make_style(Color(0.3, 0.95, 0.62, 0.85), Color(0.45, 1.0, 0.7, 0.7), 4, 1)
	fill.content_margin_top = 8.0
	fill.content_margin_bottom = 8.0
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	return slider


func _make_toggle(callback: Callable) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(116.0, 38.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _make_style(Color(0.05, 0.07, 0.075, 0.95), Color(0.35, 0.5, 0.45, 0.5), 7, 1))
	button.add_theme_stylebox_override("hover", _make_style(Color(0.07, 0.13, 0.11, 0.97), Color(0.5, 0.9, 0.68, 0.8), 7, 2))
	button.add_theme_stylebox_override("pressed", _make_style(Color(0.08, 0.24, 0.14, 0.98), Color(0.5, 1.0, 0.68, 0.9), 7, 2))
	var focus_style := _make_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.55, 1.0, 0.74, 0.9), 7, 2)
	focus_style.draw_center = false
	button.add_theme_stylebox_override("focus", focus_style)
	button.add_theme_color_override("font_color", Color(0.78, 0.92, 0.85, 0.95))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.75, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.72, 1.0, 0.82, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.95, 0.75, 1.0))
	button.toggled.connect(callback)
	return button


func _make_value_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(88.0, 24.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.62, 1.0, 0.72, 0.95))
	return label


func _update_toggle(button: Button, value: bool) -> void:
	button.set_pressed_no_signal(value)
	button.text = "ВКЛ" if value else "ВЫКЛ"


func _on_play_pressed() -> void:
	Sfx.play("click", 1.0, -6.0)
	if game != null:
		game._start_game()


func _on_settings_pressed() -> void:
	Sfx.play("click", 1.0, -8.0)
	show_page("settings")


func _on_controls_pressed() -> void:
	Sfx.play("click", 1.0, -8.0)
	show_page("controls")


func _on_quit_pressed() -> void:
	Sfx.play("click", 0.9, -8.0)
	get_tree().quit()


func _on_back_pressed() -> void:
	Sfx.play("click", 0.9, -12.0)
	show_page("main")


func _on_reset_pressed() -> void:
	Settings.reset_defaults()
	_refresh_settings()
	Sfx.play("click", 0.9, -6.0)


func _on_volume_changed(value: float) -> void:
	Settings.set_master_volume(value)
	_volume_value.text = "%d%%" % roundi(value * 100.0)


func _on_shake_changed(value: float) -> void:
	Settings.set_screen_shake(value)
	_shake_value.text = "%d%%" % roundi(value * 100.0)


func _on_fullscreen_toggled(value: bool) -> void:
	Settings.set_fullscreen(value)
	_update_toggle(_fullscreen_toggle, value)


func _on_laser_toggled(value: bool) -> void:
	Settings.set_laser_sight(value)
	_update_toggle(_laser_toggle, value)


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	_draw_background(viewport_size)
	if _page == "main":
		_draw_main_page(viewport_size)
	elif _page == "settings":
		_draw_panel(_settings_panel_rect, "НАСТРОЙКИ", "ЗВУК, КАМЕРА И УПРАВЛЕНИЕ")
		_draw_settings_labels()
	elif _page == "controls":
		_draw_panel(_controls_panel_rect, "УПРАВЛЕНИЕ", "КЛАВИШИ И МЫШЬ")
		_draw_controls_rows()


func _draw_background(viewport_size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.004, 0.01, 0.014, 0.86))
	for i in 8:
		draw_circle(
			Vector2(viewport_size.x * 0.5, viewport_size.y * 0.28),
			380.0 - float(i) * 46.0,
			Color(0.18, 0.85, 0.5, 0.009)
		)
	for y in range(0, int(viewport_size.y), 48):
		draw_line(Vector2(0.0, float(y)), Vector2(viewport_size.x, float(y)), Color(0.25, 0.6, 0.48, 0.016), 1.0)
	for i in 26:
		var phase := float(i) * 1.7 + _time * (0.08 + float(i % 5) * 0.02)
		var particle_x := fmod(float(i) * 173.0 + _time * (8.0 + float(i % 7) * 2.0), viewport_size.x)
		var particle_y := viewport_size.y * 0.5 + sin(phase) * (120.0 + float(i % 6) * 34.0)
		var alpha := 0.045 + 0.025 * sin(phase * 1.7)
		draw_circle(Vector2(particle_x, particle_y), 1.2 + float(i % 3) * 0.5, Color(0.45, 1.0, 0.62, alpha))
	draw_rect(Rect2(0.0, 0.0, viewport_size.x, 4.0), Color(0.3, 0.85, 0.58, 0.22))
	draw_rect(Rect2(0.0, viewport_size.y - 4.0, viewport_size.x, 4.0), Color(0.3, 0.85, 0.58, 0.14))


func _draw_main_page(viewport_size: Vector2) -> void:
	var center_x := viewport_size.x * 0.5
	var pulse := 0.5 + 0.5 * sin(_time * 3.4)
	_draw_egg(Vector2(center_x - 430.0, viewport_size.y * 0.54), 1.1, 0.55)
	_draw_crab(Vector2(center_x + 430.0, viewport_size.y * 0.52), 1.0, 0.5)

	_draw_text_center("СЕКТОР 07  //  КАРАНТИННАЯ ЗОНА  //  3D", center_x, 62.0, 13, Color(1.0, 0.62, 0.28, 0.85))
	draw_line(Vector2(center_x - 215.0, 78.0), Vector2(center_x - 20.0, 78.0), Color(0.95, 0.55, 0.24, 0.35), 1.0)
	draw_line(Vector2(center_x + 20.0, 78.0), Vector2(center_x + 215.0, 78.0), Color(0.95, 0.55, 0.24, 0.35), 1.0)
	_draw_diamond(Vector2(center_x, 78.0), 4.0, Color(0.95, 0.6, 0.26, 0.65))

	_draw_text_center("УБЕЙ ВСЕ ЯЙЦА", center_x, 166.0, 68, Color(1.0, 0.72, 0.3), 11, Color(0.035, 0.025, 0.015, 0.95))
	_draw_text_center("И ВЫЖИВИ", center_x, 226.0, 45, Color(0.56, 1.0, 0.68), 8, Color(0.01, 0.03, 0.02, 0.95))
	draw_line(Vector2(center_x - 250.0, 248.0), Vector2(center_x + 250.0, 248.0), Color(0.45, 1.0, 0.66, 0.35), 1.0)
	_draw_diamond(Vector2(center_x - 260.0, 248.0), 3.0, Color(0.55, 1.0, 0.7, 0.6))
	_draw_diamond(Vector2(center_x + 260.0, 248.0), 3.0, Color(0.55, 1.0, 0.7, 0.6))
	_draw_text_center("ЯЙЦА ПАДАЮТ. ХЕДКРАБЫ ОХОТЯТСЯ. ЛИЦЕХВАТЫ ЖДУТ ЛИЦА.", center_x, 274.0, 11, Color(0.62, 0.82, 0.72, 0.78))

	_draw_text_center("WASD — БЕГ     МЫШЬ — ПРИЦЕЛ     ПРОБЕЛ — ПРЫЖОК     ЛКМ — ОГОНЬ", center_x, 592.0, 11, Color(0.57, 0.72, 0.66, 0.72))
	_draw_text_center("СТРЕЛКИ / TAB — ВЫБОР ПУНКТА     ENTER / ПРОБЕЛ — ПОДТВЕРДИТЬ", center_x, 618.0, 10, Color(0.45, 0.62, 0.55, 0.6 + 0.2 * pulse))
	_draw_text_center("ЗДОРОВЬЕ  •  АПТЕЧКИ  •  ХЕДКРАБЫ  •  ЧУЖИЕ  •  ЛИЦЕХВАТЫ  •  5 КОНЦОВОК", center_x, viewport_size.y - 36.0, 10, Color(0.42, 0.6, 0.54, 0.5))


func _draw_panel(rect: Rect2, title: String, subtitle: String) -> void:
	if rect.size.x <= 0.0:
		return
	draw_style_box(_panel_style, rect)
	var accent := Color(0.4, 1.0, 0.62, 0.45)
	draw_line(rect.position + Vector2(24.0, 0.0), rect.position + Vector2(rect.size.x * 0.5 - 36.0, 0.0), accent, 1.0)
	draw_line(rect.position + Vector2(rect.size.x * 0.5 + 36.0, 0.0), rect.position + Vector2(rect.size.x - 24.0, 0.0), accent, 1.0)
	_draw_diamond(Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y), 4.0, accent)
	_draw_text_center(title, rect.position.x + rect.size.x * 0.5, rect.position.y + 52.0, 30, Color(1.0, 0.8, 0.4), 6, Color(0.02, 0.015, 0.01, 0.9))
	_draw_text_center(subtitle, rect.position.x + rect.size.x * 0.5, rect.position.y + 76.0, 10, Color(0.55, 0.8, 0.68, 0.8))


func _draw_settings_labels() -> void:
	var panel := _settings_panel_rect
	if panel.size.x <= 0.0:
		return
	var row_x := panel.position.x + 44.0
	var separator := Color(0.36, 0.78, 0.62, 0.16)
	_draw_setting_label("ГРОМКОСТЬ", "ОБЩИЙ УРОВЕНЬ ЗВУКА", Vector2(row_x, panel.position.y + 128.0))
	_draw_setting_label("ТРЯСКА КАМЕРЫ", "СИЛА ДРОЖАНИЯ ПРИ ПОПАДАНИЯХ", Vector2(row_x, panel.position.y + 192.0))
	draw_line(Vector2(row_x, panel.position.y + 228.0), Vector2(panel.end.x - 44.0, panel.position.y + 228.0), separator, 1.0)
	_draw_setting_label("ПОЛНОЭКРАННЫЙ РЕЖИМ", "РАЗВЕРНУТЬ ИГРУ НА ВЕСЬ ЭКРАН", Vector2(row_x, panel.position.y + 262.0))
	_draw_setting_label("ЛАЗЕРНЫЙ ПРИЦЕЛ", "ПОКАЗЫВАТЬ ЛУЧ И МАРКЕР ПРИЦЕЛА", Vector2(row_x, panel.position.y + 326.0))
	_draw_text_center(
		"ИЗМЕНЕНИЯ СОХРАНЯЮТСЯ АВТОМАТИЧЕСКИ",
		panel.position.x + panel.size.x * 0.5,
		panel.position.y + 438.0,
		10,
		Color(0.48, 0.66, 0.58, 0.6)
	)


func _draw_setting_label(title: String, description: String, position: Vector2) -> void:
	_draw_text(title, position + Vector2(0.0, 5.0), 15, Color(0.82, 0.95, 0.88, 0.95))
	_draw_text(description, position + Vector2(0.0, 22.0), 9, Color(0.45, 0.64, 0.56, 0.7))


func _draw_controls_rows() -> void:
	var panel := _controls_panel_rect
	if panel.size.x <= 0.0:
		return
	var rows := [
		["WASD", "БЕГ ПО АРЕНЕ", false],
		["МЫШЬ", "ПРИЦЕЛИВАНИЕ", false],
		["ЛКМ", "ОГОНЬ", true],
		["ПРОБЕЛ", "ПРЫЖОК / СОРВАТЬ ЛИЦЕХВАТА", false],
		["ESC", "ПАУЗА", false],
		["M", "В ГЛАВНОЕ МЕНЮ ИЗ ПАУЗЫ", false],
		["R", "ЗАНОВО ПОСЛЕ СМЕРТИ", false],
		["ESC", "В ГЛАВНОЕ МЕНЮ ПОСЛЕ СМЕРТИ", false],
	]
	var row_y := panel.position.y + 120.0
	for row in rows:
		var key_text: String = row[0]
		var action_text: String = row[1]
		var accent: bool = row[2]
		var key_width := maxf(74.0, _text_width(key_text, 12) + 26.0)
		var key_x := panel.position.x + 60.0
		draw_style_box(_key_accent_style if accent else _key_style, Rect2(key_x, row_y - 22.0, key_width, 30.0))
		_draw_text_center(key_text, key_x + key_width * 0.5, row_y - 2.0, 12, Color(0.92, 1.0, 0.94, 0.96))
		_draw_text(action_text, Vector2(key_x + key_width + 34.0, row_y), 13, Color(0.72, 0.9, 0.8, 0.9))
		row_y += 36.0


func _draw_egg(center: Vector2, scale_value: float, alpha: float) -> void:
	for i in 4:
		draw_circle(center + Vector2(0.0, -42.0 * scale_value), (90.0 - float(i) * 14.0) * scale_value, Color(0.4, 1.0, 0.56, 0.012 * alpha))
	var points := PackedVector2Array()
	for i in 40:
		var angle := TAU * float(i) / 40.0
		var x := cos(angle) * 38.0 * scale_value
		var y := sin(angle) * 58.0 * scale_value
		if sin(angle) < 0.0:
			x *= 1.0 - 0.35 * -sin(angle)
		points.append(center + Vector2(x, y))
	draw_colored_polygon(points, Color(0.16, 0.3, 0.18, 0.72 * alpha))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(0.42, 0.78, 0.48, 0.5 * alpha), 2.0, true)
	draw_circle(center + Vector2(-13.0, -30.0) * scale_value, 15.0 * scale_value, Color(0.6, 0.9, 0.55, 0.08 * alpha))
	draw_polyline(PackedVector2Array([
		center + Vector2(-5.0, -56.0) * scale_value,
		center + Vector2(5.0, -29.0) * scale_value,
		center + Vector2(-7.0, -8.0) * scale_value,
	]), Color(0.02, 0.06, 0.035, 0.7 * alpha), 2.0, true)
	draw_circle(center + Vector2(13.0, -52.0) * scale_value, 3.0 * scale_value, Color(0.8, 1.0, 0.55, 0.35 * alpha))


func _draw_crab(center: Vector2, scale_value: float, alpha: float) -> void:
	for i in 4:
		draw_circle(center, (80.0 - float(i) * 12.0) * scale_value, Color(1.0, 0.3, 0.3, 0.01 * alpha))
	for side in [-1.0, 1.0]:
		for i in 3:
			var root := center + Vector2((-18.0 + float(i) * 14.0) * scale_value, 8.0 * scale_value)
			var knee := root + Vector2((-8.0 + side * 10.0) * scale_value, 20.0 * scale_value)
			var foot := knee + Vector2((side * 14.0 + float(i) * 3.0) * scale_value, 15.0 * scale_value)
			draw_line(root, knee, Color(0.12, 0.04, 0.06, 0.65 * alpha), 3.0 * scale_value, true)
			draw_line(knee, foot, Color(0.12, 0.04, 0.06, 0.65 * alpha), 2.5 * scale_value, true)
	_draw_ellipse(center, Vector2(42.0, 25.0) * scale_value, Color(0.26, 0.07, 0.1, 0.8 * alpha))
	_draw_ellipse(center + Vector2(-7.0, -10.0) * scale_value, Vector2(28.0, 14.0) * scale_value, Color(0.48, 0.13, 0.2, 0.75 * alpha))
	draw_circle(center + Vector2(25.0, 1.0) * scale_value, 12.0 * scale_value, Color(0.07, 0.02, 0.03, 0.9 * alpha))
	draw_circle(center + Vector2(29.0, 1.0) * scale_value, 5.0 * scale_value, Color(0.7, 0.12, 0.16, 0.8 * alpha))
	draw_circle(center + Vector2(17.0, -12.0) * scale_value, 5.0 * scale_value, Color(1.0, 0.55, 0.16, 0.5 * alpha))
	draw_circle(center + Vector2(27.0, -8.0) * scale_value, 3.2 * scale_value, Color(1.0, 0.55, 0.16, 0.45 * alpha))


func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)


func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	]), color)


func _make_style(background: Color, border: Color, radius: int, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _draw_text(text: String, position: Vector2, font_size: int, color: Color, outline_size: int = 0, outline_color: Color = Color(0.0, 0.0, 0.0, 0.9)) -> void:
	var font := ThemeDB.fallback_font
	if outline_size > 0:
		draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, outline_size, outline_color)
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_text_center(text: String, center_x: float, baseline_y: float, font_size: int, color: Color, outline_size: int = 0, outline_color: Color = Color(0.0, 0.0, 0.0, 0.9)) -> void:
	var width := _text_width(text, font_size)
	_draw_text(text, Vector2(center_x - width * 0.5, baseline_y), font_size, color, outline_size, outline_color)


func _text_width(text: String, font_size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
