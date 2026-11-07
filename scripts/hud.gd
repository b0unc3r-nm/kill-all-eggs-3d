extends Control

## All HUD, menu and overlay art is drawn procedurally.

var game: Node
var player: Node

var _panel_style: StyleBoxFlat
var _soft_panel_style: StyleBoxFlat
var _stats_panel_style: StyleBoxFlat

var _banner_text := ""
var _banner_sub := ""
var _banner_timer := 0.0
var _banner_duration := 2.8
var _message_text := ""
var _message_color := Color(0.8, 1.0, 0.8)
var _message_timer := 0.0
var _message_duration := 2.4
var _hitmarker_timer := 0.0
var _hurt_flash := 0.0


func setup(new_game: Node) -> void:
	game = new_game
	player = new_game.player


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_style = _make_panel_style(Color(0.025, 0.042, 0.05, 0.9), Color(0.27, 0.7, 0.55, 0.32), 9)
	_soft_panel_style = _make_panel_style(Color(0.02, 0.035, 0.045, 0.72), Color(0.22, 0.55, 0.46, 0.2), 7)
	_stats_panel_style = _make_panel_style(Color(0.03, 0.04, 0.05, 0.92), Color(0.7, 0.24, 0.24, 0.4), 9)
	queue_redraw()


func _process(delta: float) -> void:
	if game == null:
		return
	if game.state != "paused":
		_banner_timer = maxf(0.0, _banner_timer - delta)
		_message_timer = maxf(0.0, _message_timer - delta)
		_hitmarker_timer = maxf(0.0, _hitmarker_timer - delta)
		_hurt_flash = maxf(0.0, _hurt_flash - delta * 2.8)
	queue_redraw()


func show_wave_banner(wave_number: int, is_final: bool = false, has_facehuggers: bool = false) -> void:
	if is_final:
		_banner_text = "ФИНАЛЬНАЯ ВОЛНА"
		_banner_sub = "УНИЧТОЖЬ ВСЁ И ЭВАКУИРУЙСЯ"
	else:
		_banner_text = "ВОЛНА %02d" % wave_number
		if has_facehuggers:
			_banner_sub = "ЯЙЦА, ЧУЖИЕ И ЛИЦЕХВАТЫ НА АРЕНЕ"
		elif wave_number >= 2:
			_banner_sub = "ЯЙЦА И ЧУЖИЕ НА АРЕНЕ"
		else:
			_banner_sub = "ИНКУБАТОР ПРОБУЖДЁН"
	_banner_duration = 2.8
	_banner_timer = _banner_duration


func show_message(text: String, color: Color = Color(0.78, 1.0, 0.82), duration: float = 2.4) -> void:
	_message_text = text
	_message_color = color
	_message_duration = duration
	_message_timer = duration


func on_hit() -> void:
	_hitmarker_timer = 0.12


func on_hurt() -> void:
	_hurt_flash = 0.48


func clear_events() -> void:
	_banner_timer = 0.0
	_message_timer = 0.0
	_hitmarker_timer = 0.0


func _draw() -> void:
	if game == null or player == null:
		return
	if game.state == "menu":
		return
	var viewport_size := get_viewport_rect().size
	_draw_hud(viewport_size)
	if game.state == "playing" and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		_draw_crosshair(viewport_size)
	if game.state == "playing" and player.hugged:
		_draw_hug(viewport_size)
	if game.state == "paused":
		_draw_pause(viewport_size)
	elif game.state == "gameover":
		_draw_gameover(viewport_size)
	elif game.state == "victory":
		_draw_victory(viewport_size)


func _draw_hud(viewport_size: Vector2) -> void:
	var center_x := viewport_size.x * 0.5
	var health_ratio := clampf(float(player.health) / float(player.max_health), 0.0, 1.0)
	var health_color := Color(0.4, 0.92, 0.6)
	if health_ratio < 0.3:
		health_color = Color(1.0, 0.26, 0.28)
	elif health_ratio < 0.6:
		health_color = Color(1.0, 0.72, 0.28)

	# Health panel.
	var health_rect := Rect2(24.0, 22.0, 338.0, 88.0)
	draw_style_box(_panel_style, health_rect)
	draw_circle(Vector2(56.0, 56.0), 19.0, Color(0.24, 0.9, 0.56, 0.08))
	draw_circle(Vector2(56.0, 56.0), 14.0, Color(0.08, 0.16, 0.13, 0.95))
	draw_rect(Rect2(50.0, 54.0, 12.0, 4.0), health_color)
	draw_rect(Rect2(54.0, 50.0, 4.0, 12.0), health_color)
	_draw_text("ЗДОРОВЬЕ", Vector2(82.0, 49.0), 13, Color(0.6, 0.79, 0.72, 0.9))
	_draw_text_right("%03d" % player.health, 338.0, 49.0, 13, health_color)
	var bar_rect := Rect2(82.0, 61.0, 256.0, 20.0)
	draw_rect(bar_rect, Color(0.01, 0.025, 0.03, 0.95))
	var fill_width := (bar_rect.size.x - 4.0) * health_ratio
	if fill_width > 0.0:
		draw_rect(Rect2(bar_rect.position + Vector2(2.0, 2.0), Vector2(fill_width, bar_rect.size.y - 4.0)), health_color)
		draw_rect(Rect2(bar_rect.position + Vector2(2.0, 2.0), Vector2(fill_width, 3.0)), Color(1.0, 1.0, 1.0, 0.22))
	for tick in [0.25, 0.5, 0.75]:
		var tick_x: float = bar_rect.position.x + 2.0 + (bar_rect.size.x - 4.0) * float(tick)
		draw_line(Vector2(tick_x, bar_rect.position.y + 2.0), Vector2(tick_x, bar_rect.end.y - 2.0), Color(0.0, 0.0, 0.0, 0.45), 1.0)
	draw_rect(bar_rect, Color(0.32, 0.78, 0.6, 0.32), false, 1.0)
	_draw_text("HP", Vector2(82.0, 102.0), 10, Color(0.45, 0.65, 0.58, 0.65))
	_draw_text("СЕКТОР 07", Vector2(120.0, 102.0), 10, Color(0.45, 0.65, 0.58, 0.55))

	# Wave panel.
	var wave_rect := Rect2(center_x - 210.0, 22.0, 420.0, 76.0)
	draw_style_box(_panel_style, wave_rect)
	_draw_text_center("ВОЛНА %02d" % maxi(game.wave, 1), center_x, 49.0, 20, Color(1.0, 0.76, 0.36))
	var eggs := game.get_tree().get_nodes_in_group("eggs").size()
	var crabs := game.get_tree().get_nodes_in_group("headcrabs").size()
	var huggers := game.get_tree().get_nodes_in_group("facehuggers").size()
	var aliens := game.get_tree().get_nodes_in_group("aliens").size()
	var medkits := game.get_tree().get_nodes_in_group("medkits").size()
	var counts := "ЯЙЦА %d   •   ХЕДКРАБЫ %d" % [eggs, crabs]
	if huggers > 0:
		counts += "   •   ЛИЦЕХВАТЫ %d" % huggers
	if aliens > 0:
		counts += "   •   ЧУЖИЕ %d" % aliens
	var counts_color := Color(0.62, 1.0, 0.46, 0.96) if aliens > 0 or huggers > 0 else Color(0.58, 0.84, 0.72, 0.9)
	_draw_text_center(counts, center_x, 70.0, 9, counts_color)
	draw_line(Vector2(center_x - 118.0, 78.0), Vector2(center_x + 118.0, 78.0), Color(0.36, 0.78, 0.62, 0.18), 1.0)
	if medkits > 0:
		_draw_text_center("АПТЕЧКИ %d   •   ПАРЯТ НА АРЕНЕ" % medkits, center_x, 92.0, 9, Color(0.62, 1.0, 0.58, 0.95))
	elif game.medkit_respawn_timer > 0.0:
		_draw_text_center("АПТЕЧКИ ПОЯВЯТСЯ ЧЕРЕЗ %d СЕК" % ceili(game.medkit_respawn_timer), center_x, 92.0, 9, Color(1.0, 0.78, 0.4, 0.9))
	else:
		_draw_text_center("АПТЕЧКИ: ПОИСК НОВОЙ ТОЧКИ", center_x, 92.0, 9, Color(0.58, 0.78, 0.68, 0.7))

	# Score panel.
	var score_rect := Rect2(viewport_size.x - 234.0, 22.0, 210.0, 76.0)
	draw_style_box(_panel_style, score_rect)
	_draw_text("ОЧКИ", Vector2(score_rect.position.x + 16.0, 46.0), 11, Color(0.6, 0.79, 0.72, 0.8))
	_draw_text_right("УБИЙСТВ %d   •   ЧУЖИХ %d" % [game.kills, game.aliens_killed], score_rect.end.x - 16.0, 46.0, 9, Color(0.54, 0.7, 0.64, 0.7))
	_draw_text_right("%06d" % game.score, score_rect.end.x - 16.0, 72.0, 24, Color(1.0, 0.77, 0.36))

	# Weapon panel.
	var weapon_rect := Rect2(viewport_size.x - 304.0, viewport_size.y - 82.0, 280.0, 58.0)
	draw_style_box(_soft_panel_style, weapon_rect)
	_draw_weapon_icon(Vector2(weapon_rect.position.x + 31.0, weapon_rect.position.y + 29.0))
	_draw_text("ИМПУЛЬСНЫЙ ПИСТОЛЕТ", Vector2(weapon_rect.position.x + 55.0, weapon_rect.position.y + 27.0), 11, Color(0.58, 0.78, 0.7, 0.9))
	_draw_text("БЕЗ ПЕРЕЗАРЯДКИ", Vector2(weapon_rect.position.x + 55.0, weapon_rect.position.y + 44.0), 9, Color(0.42, 0.62, 0.55, 0.7))
	_draw_text_right("∞", weapon_rect.end.x - 18.0, weapon_rect.position.y + 37.0, 25, Color(0.5, 1.0, 0.7, 0.9))

	# Controls strip.
	var controls_rect := Rect2(24.0, viewport_size.y - 52.0, 762.0, 30.0)
	draw_style_box(_soft_panel_style, controls_rect)
	_draw_text("WASD — БЕГ     МЫШЬ — ПРИЦЕЛ     ПРОБЕЛ — ПРЫЖОК     ЛКМ — ОГОНЬ     ESC — ПАУЗА", Vector2(controls_rect.position.x + 14.0, controls_rect.position.y + 20.0), 11, Color(0.57, 0.72, 0.66, 0.75))

	# Wave banner.
	if _banner_timer > 0.0:
		var progress := 1.0 - _banner_timer / _banner_duration
		var alpha := smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.72, 1.0, progress))
		draw_rect(Rect2(center_x - 245.0, 144.0, 490.0, 92.0), Color(0.01, 0.025, 0.03, 0.58 * alpha))
		draw_line(Vector2(center_x - 190.0, 149.0), Vector2(center_x + 190.0, 149.0), Color(0.45, 0.95, 0.66, 0.45 * alpha), 1.0)
		draw_line(Vector2(center_x - 190.0, 231.0), Vector2(center_x + 190.0, 231.0), Color(0.45, 0.95, 0.66, 0.45 * alpha), 1.0)
		_draw_text_center(_banner_text, center_x, 196.0, 45, Color(1.0, 0.79, 0.38, alpha), 8, Color(0.01, 0.02, 0.02, 0.9 * alpha))
		_draw_text_center(_banner_sub, center_x, 221.0, 12, Color(0.68, 1.0, 0.8, alpha * 0.9))

	# Temporary event message.
	if _message_timer > 0.0:
		var message_alpha := minf(1.0, _message_timer / 0.3)
		var text_width := _text_width(_message_text, 13)
		var message_rect := Rect2(center_x - text_width * 0.5 - 17.0, 109.0, text_width + 34.0, 28.0)
		draw_rect(message_rect, Color(0.01, 0.025, 0.03, 0.72 * message_alpha))
		draw_rect(message_rect, Color(_message_color, 0.18 * message_alpha), false, 1.0)
		_draw_text_center(_message_text, center_x, 129.0, 13, Color(_message_color, message_alpha))

	# Low health and damage feedback.
	if health_ratio < 0.3 and game.state == "playing":
		var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.008)
		var edge_alpha := (1.0 - health_ratio / 0.3) * (0.08 + 0.07 * pulse)
		draw_rect(Rect2(0.0, 0.0, viewport_size.x, 16.0), Color(1.0, 0.06, 0.08, edge_alpha))
		draw_rect(Rect2(0.0, viewport_size.y - 16.0, viewport_size.x, 16.0), Color(1.0, 0.06, 0.08, edge_alpha))
		draw_rect(Rect2(0.0, 0.0, 12.0, viewport_size.y), Color(1.0, 0.06, 0.08, edge_alpha))
		draw_rect(Rect2(viewport_size.x - 12.0, 0.0, 12.0, viewport_size.y), Color(1.0, 0.06, 0.08, edge_alpha))

	if _hurt_flash > 0.0:
		var flash_alpha := (_hurt_flash / 0.48) * 0.24
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.9, 0.03, 0.04, flash_alpha))


func _draw_crosshair(viewport_size: Vector2) -> void:
	var mouse_position := get_viewport().get_mouse_position()
	var spread: float = 6.0 + float(player.recoil) * 4.0
	var crosshair_color := Color(1.0, 0.91, 0.68, 0.95)
	for direction_variant in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var direction: Vector2 = direction_variant
		var from: Vector2 = mouse_position + direction * spread
		var to: Vector2 = mouse_position + direction * (spread + 8.0)
		draw_line(from, to, Color(0.0, 0.0, 0.0, 0.65), 3.2, true)
		draw_line(from, to, crosshair_color, 1.4, true)
	draw_circle(mouse_position, 1.5, crosshair_color)
	if _hitmarker_timer > 0.0:
		var alpha := _hitmarker_timer / 0.12
		for direction_variant in [Vector2(1.0, 1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(-1.0, -1.0)]:
			var direction: Vector2 = direction_variant
			draw_line(mouse_position + direction * 4.0, mouse_position + direction * 12.0, Color(1.0, 1.0, 1.0, alpha), 2.2, true)


func _draw_pause(viewport_size: Vector2) -> void:
	var center_x := viewport_size.x * 0.5
	var center_y := viewport_size.y * 0.5
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.008, 0.015, 0.02, 0.68))
	draw_rect(Rect2(center_x - 250.0, center_y - 82.0, 500.0, 164.0), Color(0.01, 0.025, 0.03, 0.76))
	draw_rect(Rect2(center_x - 250.0, center_y - 82.0, 500.0, 164.0), Color(0.3, 0.8, 0.6, 0.25), false, 1.0)
	_draw_text_center("ПАУЗА", center_x, center_y - 18.0, 58, Color(0.8, 1.0, 0.86), 8, Color(0.01, 0.02, 0.02, 0.9))
	_draw_text_center("ESC — ПРОДОЛЖИТЬ     M — В ГЛАВНОЕ МЕНЮ", center_x, center_y + 27.0, 15, Color(0.58, 0.9, 0.74, 0.9))
	_draw_text_center("WASD — БЕГ     МЫШЬ — ПРИЦЕЛ     ПРОБЕЛ — ПРЫЖОК     ЛКМ — ОГОНЬ", center_x, center_y + 54.0, 11, Color(0.45, 0.65, 0.58, 0.7))


func _draw_gameover(viewport_size: Vector2) -> void:
	var center_x := viewport_size.x * 0.5
	var center_y := viewport_size.y * 0.5
	var infected: bool = game.ending_id == "infected"
	var background := Color(0.02, 0.05, 0.015, 0.8) if infected else Color(0.035, 0.006, 0.012, 0.76)
	var title_color := Color(0.62, 1.0, 0.3) if infected else Color(1.0, 0.3, 0.31)
	var subtitle_color := Color(0.9, 1.0, 0.45, 0.9) if infected else Color(1.0, 0.6, 0.28, 0.9)
	var ring_color := Color(0.55, 0.95, 0.2, 0.01) if infected else Color(0.8, 0.12, 0.12, 0.008)
	draw_rect(Rect2(Vector2.ZERO, viewport_size), background)
	for i in 7:
		draw_circle(Vector2(center_x, center_y - 20.0), 300.0 - float(i) * 38.0, ring_color)
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.006)
	var title := "ЗАРАЖЁН" if infected else "ВЫ ПОГИБЛИ"
	var subtitle := "ЛИЦЕХВАТ ОТЛОЖИЛ ЯЙЦО — СЕКТОР 07 ПОТЕРЯН" if infected else "СЕКТОР 07 ПОТЕРЯН"
	_draw_text_center(title, center_x, center_y - 104.0, 72, title_color, 10, Color(0.02, 0.01, 0.005, 0.95))
	_draw_text_center(subtitle, center_x, center_y - 68.0, 14, subtitle_color)

	var stats_rect := Rect2(center_x - 250.0, center_y - 30.0, 500.0, 124.0)
	draw_style_box(_stats_panel_style, stats_rect)
	draw_line(Vector2(stats_rect.position.x + 20.0, stats_rect.position.y + 30.0), Vector2(stats_rect.end.x - 20.0, stats_rect.position.y + 30.0), Color(title_color, 0.15), 1.0)
	_draw_stat_column(center_x - 154.0, center_y + 6.0, "ВОЛНА", "%02d" % maxi(game.wave, 1))
	_draw_stat_column(center_x, center_y + 6.0, "УБИЙСТВА", str(game.kills))
	_draw_stat_column(center_x + 154.0, center_y + 6.0, "ОЧКИ", str(game.score))

	_draw_text_center("R — ЗАНОВО     ESC — В ГЛАВНОЕ МЕНЮ", center_x, center_y + 160.0, 17, Color(1.0, 0.78, 0.38, 0.55 + 0.4 * pulse), 4, Color(0.03, 0.005, 0.008, 0.85))
	if infected:
		_draw_text_center("Ты не успел сорвать лицехвата. Теперь внутри тебя растёт нечто иное.", center_x, center_y + 202.0, 12, Color(0.62, 0.82, 0.44, 0.8))
	else:
		_draw_text_center("Разбивай яйца до того, как они вылупятся.", center_x, center_y + 202.0, 12, Color(0.68, 0.46, 0.44, 0.75))


func _draw_hug(viewport_size: Vector2) -> void:
	var center_x := viewport_size.x * 0.5
	var center_y := viewport_size.y * 0.5
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.012)
	var edge_alpha := 0.1 + pulse * 0.08
	draw_rect(Rect2(0.0, 0.0, viewport_size.x, 20.0), Color(0.8, 0.03, 0.05, edge_alpha))
	draw_rect(Rect2(0.0, viewport_size.y - 20.0, viewport_size.x, 20.0), Color(0.8, 0.03, 0.05, edge_alpha))
	draw_rect(Rect2(0.0, 0.0, 20.0, viewport_size.y), Color(0.8, 0.03, 0.05, edge_alpha))
	draw_rect(Rect2(viewport_size.x - 20.0, 0.0, 20.0, viewport_size.y), Color(0.8, 0.03, 0.05, edge_alpha))

	var panel := Rect2(center_x - 290.0, center_y - 100.0, 580.0, 200.0)
	draw_rect(panel, Color(0.03, 0.008, 0.012, 0.84))
	draw_rect(panel, Color(1.0, 0.28, 0.22, 0.45), false, 1.0)
	_draw_text_center("ЛИЦЕХВАТ ВЦЕПИЛСЯ", center_x, center_y - 48.0, 40, Color(1.0, 0.4, 0.32), 7, Color(0.02, 0.005, 0.008, 0.95))
	_draw_text_center("ЖМИ ПРОБЕЛ, ЧТОБЫ СОРВАТЬ ЕГО", center_x, center_y - 18.0, 14, Color(1.0, 0.82, 0.55))

	var ratio := clampf(player.hug_progress, 0.0, 1.0)
	var bar_rect := Rect2(center_x - 220.0, center_y + 8.0, 440.0, 26.0)
	draw_rect(bar_rect, Color(0.015, 0.008, 0.008, 0.96))
	var fill_width := (bar_rect.size.x - 6.0) * ratio
	if fill_width > 0.0:
		draw_rect(Rect2(bar_rect.position + Vector2(3.0, 3.0), Vector2(fill_width, bar_rect.size.y - 6.0)), Color(0.45, 1.0, 0.5))
	draw_rect(bar_rect, Color(0.8, 0.4, 0.3, 0.5), false, 1.0)
	_draw_text_center("СОПРОТИВЛЕНИЕ %d%%" % roundi(ratio * 100.0), center_x, center_y + 55.0, 12, Color(0.7, 1.0, 0.7))
	var remaining := maxf(0.0, player.hug_duration - player.hug_time)
	_draw_text_center("ДО ЗАРАЖЕНИЯ %.1f С" % remaining, center_x, center_y + 78.0, 11, Color(1.0, 0.6, 0.4))


func _draw_victory(viewport_size: Vector2) -> void:
	var center_x := viewport_size.x * 0.5
	var center_y := viewport_size.y * 0.5
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.008, 0.03, 0.02, 0.82))
	for i in 8:
		draw_circle(Vector2(center_x, center_y - 20.0), 320.0 - float(i) * 38.0, Color(0.3, 1.0, 0.55, 0.01))
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.005)
	var title := "ЭВАКУАЦИЯ"
	var subtitle := "СЕКТОР 07 ЗАЧИЩЕН"
	var description := "Последняя волна уничтожена. Ты выбрался из карантинной зоны живым."
	var accent := Color(0.55, 1.0, 0.65)
	match game.ending_id:
		"perfect":
			title = "ИДЕАЛЬНАЯ ЗАЧИСТКА"
			subtitle = "НИ ОДНОГО ЗАРАЖЕНИЯ"
			description = "Ни один лицехват не добрался до твоего лица. Безупречная охота."
			accent = Color(1.0, 0.85, 0.4)
		"pyrrhic":
			title = "НА ГРАНИ"
			subtitle = "ЭВАКУАЦИЯ НА ПОСЛЕДНЕМ ДЫХАНИИ"
			description = "Ты выжил, но едва держишься на ногах. Сектор зачищен ценой почти всего."
			accent = Color(1.0, 0.55, 0.3)
	_draw_text_center(title, center_x, center_y - 112.0, 62, accent, 10, Color(0.01, 0.03, 0.02, 0.95))
	_draw_text_center(subtitle, center_x, center_y - 76.0, 15, Color(0.75, 1.0, 0.8, 0.95))
	_draw_text_center(description, center_x, center_y - 46.0, 12, Color(0.6, 0.82, 0.7, 0.85))

	var stats_rect := Rect2(center_x - 320.0, center_y - 22.0, 640.0, 124.0)
	draw_style_box(_stats_panel_style, stats_rect)
	draw_line(Vector2(stats_rect.position.x + 20.0, stats_rect.position.y + 30.0), Vector2(stats_rect.end.x - 20.0, stats_rect.position.y + 30.0), Color(accent, 0.18), 1.0)
	_draw_stat_column(center_x - 232.0, center_y + 14.0, "ВОЛНА", "%02d" % maxi(game.wave, 1))
	_draw_stat_column(center_x - 77.0, center_y + 14.0, "УБИЙСТВА", str(game.kills))
	_draw_stat_column(center_x + 78.0, center_y + 14.0, "ОЧКИ", str(game.score))
	_draw_stat_column(center_x + 233.0, center_y + 14.0, "ВРЕМЯ", _format_time(game.game_time))

	_draw_text_center("R — СНОВА     ESC — В ГЛАВНОЕ МЕНЮ", center_x, center_y + 158.0, 17, Color(1.0, 0.85, 0.42, 0.55 + 0.4 * pulse), 4, Color(0.01, 0.03, 0.02, 0.9))
	_draw_text_center("Попробуй пройти все %d волн без единого укуса." % maxi(game.final_wave, 1), center_x, center_y + 200.0, 12, Color(0.55, 0.8, 0.66, 0.75))


func _format_time(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	return "%02d:%02d" % [total / 60, total % 60]


func _draw_stat_column(center_x: float, top_y: float, label: String, value: String) -> void:
	_draw_text_center(label, center_x, top_y + 17.0, 10, Color(0.58, 0.7, 0.65, 0.8))
	_draw_text_center(value, center_x, top_y + 64.0, 34, Color(1.0, 0.82, 0.5))


func _draw_weapon_icon(position: Vector2) -> void:
	draw_set_transform(position, -0.16, Vector2.ONE)
	draw_rect(Rect2(-13.0, -4.0, 24.0, 8.0), Color(0.2, 0.28, 0.29, 1.0))
	draw_rect(Rect2(-9.0, -3.0, 17.0, 2.0), Color(0.48, 0.65, 0.6, 0.8))
	draw_rect(Rect2(11.0, -2.0, 8.0, 4.0), Color(0.12, 0.18, 0.19, 1.0))
	draw_rect(Rect2(-7.0, 4.0, 6.0, 8.0), Color(0.12, 0.17, 0.18, 1.0))
	draw_rect(Rect2(-3.0, 0.0, 5.0, 3.0), Color(0.35, 0.95, 0.58, 0.8))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _make_panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
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


func _draw_text_right(text: String, right_x: float, baseline_y: float, font_size: int, color: Color, outline_size: int = 0, outline_color: Color = Color(0.0, 0.0, 0.0, 0.9)) -> void:
	var width := _text_width(text, font_size)
	_draw_text(text, Vector2(right_x - width, baseline_y), font_size, color, outline_size, outline_color)


func _text_width(text: String, font_size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
