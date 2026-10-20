extends Control

const VictoryOverlayScript := preload("res://scripts/victory_overlay.gd")
const LoadingOverlayScript := preload("res://scripts/loading_overlay.gd")
const EraTransitionScript := preload("res://scripts/era_transition.gd")

## Segunda palabra del título (FÁCIL / DIFÍCIL): degradado cálido → frío.
const TITLE_LETTER_COLORS: Array[Color] = [
	Color("FF7A18"),
	Color("FFB020"),
	Color("FFE14A"),
	Color("7BE04A"),
	Color("3DDC97"),
	Color("3CC8F0"),
	Color("4F8BFF"),
]
const STAT_LEVEL_COLOR := Color("FFD84A")
const STAT_PAIRS_COLOR := Color("FF8AD8")
const STAT_SCORE_COLOR := Color("FFB020")
const STAT_TIMER_COLOR := Color("2EB8FF")
const CONTENT_PAD_H := 16
const CONTENT_PAD_TOP := 20
const CONTENT_PAD_BOTTOM := 16
## Cada este intervalo: regenera bolas/caminos no unidos (parejas hechas se congelan).
## El nivel no termina por tiempo: solo al resolver todas las parejas.
const CHRONO_CHAOS_INTERVAL_SEC := 60.0
## Últimos segundos del ciclo: casillas cambian de color cada segundo.
const CHRONO_URGENCY_SEC := 10.0

## Board o SandboxBoard (misma API de señales/métodos de juego).
var _board
var _level_label: Label
var _pairs_label: Label
var _score_label: Label
var _timer_panel: PanelContainer
var _timer_digits: HBoxContainer
var _timer_banner: Control
var _timer_text_cache: String = ""
var _timer_urgent_cache: bool = false
var _hint_btn: Button
var _resolve_btn: Button
var _actions_box: HBoxContainer
var _overlay: Control
var _loading: Control
var _confirm_overlay: Control
var _confirm_message: Label
var _notice_overlay: Control
var _notice_message: Label
var _skip_review_bar: Control
var _bg: Control
var _content_root: Control
var _current_level: Dictionary = {}
var _level_id: int = 1
var _is_loading_level: bool = false
var _is_resolving: bool = false
var _era_transition_playing: bool = false
var _era_board_reveal: bool = false
## True si el nivel 100 ya se cargó durante la cinemática (evitar doble load).
var _era_next_preloaded: bool = false
var _pending_skip_next: int = 0
var _pending_skip_spent: int = 0
var _level_started_msec: int = 0
var _sound_btn: Button
var _chrono_remaining: float = CHRONO_CHAOS_INTERVAL_SEC
var _chrono_running: bool = false
var _chrono_chaos_busy: bool = false
var _chrono_last_urgency_tick: int = -1
var _lose_overlay: Control
var _lose_title: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_level_id = LevelManager.current_level_id
	if not SettingsManager.settings_changed.is_connected(_refresh_sound_button):
		SettingsManager.settings_changed.connect(_refresh_sound_button)
	_build_ui()
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_apply_safe_margins):
		vp.size_changed.connect(_apply_safe_margins)
	call_deferred("_apply_safe_margins")
	_load_level_async()


func _process(delta: float) -> void:
	if LevelManager.current_mode != LevelManager.MODE_CHRONO:
		return
	if not _chrono_running or _chrono_chaos_busy:
		return
	if _is_chrono_paused():
		return
	_chrono_remaining = maxf(0.0, _chrono_remaining - delta)
	_refresh_timer_label()
	_update_chrono_urgency()
	if _chrono_remaining <= 0.0:
		_on_chrono_chaos_tick()


func _build_ui() -> void:
	_bg = UIFactory.attach_level_background(self, _level_id)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_content_root = root
	_apply_safe_margins()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(vbox)

	# Cabecera: título centrado + Home (esquina) + barra de stats estilo mockup.
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(top_row)

	# Espaciador = ancho del bloque derecho (altavoz + home) para centrar el título.
	var top_spacer := Control.new()
	var title_row_h := 250 if LevelManager.current_mode == LevelManager.MODE_CHRONO else 76
	top_spacer.custom_minimum_size = Vector2(160, title_row_h)
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(top_spacer)

	var mode_title := _make_mode_title(LevelManager.get_mode_title(LevelManager.current_mode))
	mode_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if LevelManager.current_mode == LevelManager.MODE_CHRONO:
		mode_title.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_row.add_child(mode_title)

	var right_actions := HBoxContainer.new()
	right_actions.add_theme_constant_override("separation", 8)
	right_actions.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right_actions.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top_row.add_child(right_actions)

	var btn_v_flag := (
		Control.SIZE_SHRINK_CENTER
		if LevelManager.current_mode == LevelManager.MODE_CHRONO
		else Control.SIZE_SHRINK_BEGIN
	)
	_sound_btn = UIFactory.make_button("", 76)
	_sound_btn.custom_minimum_size = Vector2(76, 76)
	_sound_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sound_btn.size_flags_vertical = btn_v_flag
	_sound_btn.pressed.connect(_on_sound_pressed)
	right_actions.add_child(_sound_btn)
	_refresh_sound_button()

	var menu_btn := UIFactory.make_button("", 76)
	UIFactory.set_button_colors(menu_btn, GamePalette.MENU_BLUE, Color.WHITE)
	UIFactory.set_button_icon(menu_btn, UIFactory.ButtonIcon.HOME)
	menu_btn.custom_minimum_size = Vector2(76, 76)
	menu_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_btn.size_flags_vertical = btn_v_flag
	menu_btn.tooltip_text = "Menú"
	menu_btn.pressed.connect(_on_menu)
	right_actions.add_child(menu_btn)
	right_actions.size_flags_vertical = btn_v_flag

	var header := _make_stats_header_panel()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(header)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 0)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(stats)

	var level_stat := _make_stat_item("flag", "NIVEL", STAT_LEVEL_COLOR)
	_level_label = level_stat.get_meta("value_label")
	_level_label.text = "—"
	stats.add_child(level_stat)
	stats.add_child(_make_stat_divider())

	# Crazy: el contador ocupa el hueco de PAREJAS (esa métrica se omite).
	if LevelManager.current_mode == LevelManager.MODE_CHRONO:
		_timer_banner = _make_chrono_timer_banner()
		_timer_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_timer_banner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stats.add_child(_timer_banner)
	else:
		var pairs_stat := _make_stat_item("pairs", "PAREJAS", STAT_PAIRS_COLOR)
		_pairs_label = pairs_stat.get_meta("value_label")
		_pairs_label.text = "0/0"
		stats.add_child(pairs_stat)
	stats.add_child(_make_stat_divider())

	var score_stat := _make_stat_item("score", "PUNTUACIÓN", STAT_SCORE_COLOR)
	_score_label = score_stat.get_meta("value_label")
	_refresh_score_label()
	stats.add_child(score_stat)

	if LevelManager.current_mode == LevelManager.MODE_SANDBOX:
		_board = SandboxBoard.new()
	else:
		_board = Board.new()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.custom_minimum_size = Vector2(200, 200)
	_board.pairs_changed.connect(_on_pairs_changed)
	_board.level_completed.connect(_on_level_completed)
	_board.invalid_move.connect(_on_invalid_move)

	vbox.add_child(_board)

	_actions_box = HBoxContainer.new()
	_actions_box.add_theme_constant_override("separation", 10)
	_actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_actions_box)

	# Reiniciar: solo icono (mismo glossy que el menú).
	var reset_btn := UIFactory.make_button("", 90)
	UIFactory.set_button_colors(reset_btn, GamePalette.MENU_YELLOW, GamePalette.MENU_YELLOW_TEXT)
	UIFactory.set_button_icon(reset_btn, UIFactory.ButtonIcon.RESTART, GamePalette.MENU_YELLOW_TEXT)
	reset_btn.custom_minimum_size = Vector2(90, 90)
	reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset_btn.tooltip_text = "Reiniciar"
	reset_btn.pressed.connect(_on_reset)
	_actions_box.add_child(reset_btn)

	_hint_btn = UIFactory.make_button("PISTA (0)", 90)
	UIFactory.set_button_colors(_hint_btn, GamePalette.BUTTON_CYAN, Color("0A3A52"))
	UIFactory.set_button_icon(_hint_btn, UIFactory.ButtonIcon.BULB, Color("0A3A52"))
	_hint_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_btn.pressed.connect(_on_hint)
	_actions_box.add_child(_hint_btn)

	_resolve_btn = UIFactory.make_button("RESOLVER", 90)
	UIFactory.set_button_colors(_resolve_btn, GamePalette.ACCENT_MAGENTA, Color.WHITE)
	UIFactory.set_button_icon(_resolve_btn, UIFactory.ButtonIcon.SPARKLE, Color.WHITE)
	_resolve_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resolve_btn.tooltip_text = "Gasta todas las pistas (8 o más) para resolver y pasar"
	_resolve_btn.pressed.connect(_on_resolve_pressed)
	_actions_box.add_child(_resolve_btn)
	_refresh_hint_button()

	_overlay = Control.new()
	_overlay.visible = false
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_loading = LoadingOverlayScript.new()
	_loading.visible = false
	add_child(_loading)

	_build_confirm_overlay()
	_build_notice_overlay()
	_build_lose_overlay()


func _apply_safe_margins() -> void:
	if _content_root == null:
		return
	var insets := _compute_safe_insets()
	_content_root.add_theme_constant_override("margin_left", insets.x)
	_content_root.add_theme_constant_override("margin_top", insets.y)
	_content_root.add_theme_constant_override("margin_right", insets.z)
	_content_root.add_theme_constant_override("margin_bottom", insets.w)


## Insets del HUD: cámara / notch arriba y barra de gestos abajo, más el margen de diseño.
func _compute_safe_insets() -> Vector4i:
	var viewport_size := get_viewport().get_visible_rect().size if get_viewport() != null else size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = size
	var window_size := DisplayServer.window_get_size()
	var scale_factor := 1.0
	if window_size.y > 0:
		scale_factor = viewport_size.y / float(window_size.y)
		if is_nan(scale_factor) or is_inf(scale_factor) or scale_factor <= 0.0:
			scale_factor = 1.0

	var extra_left := 0
	var extra_top := 0
	var extra_right := 0
	var extra_bottom := 0

	var platform := OS.get_name()
	if platform == "Android" or platform == "iOS":
		var safe := DisplayServer.get_display_safe_area()
		if window_size.x > 0 and window_size.y > 0 and safe.size.x > 0 and safe.size.y > 0:
			extra_left = maxi(extra_left, int(round(float(safe.position.x) * scale_factor)))
			extra_top = maxi(extra_top, int(round(float(safe.position.y) * scale_factor)))
			extra_right = maxi(
				extra_right,
				int(round(float(window_size.x - (safe.position.x + safe.size.x)) * scale_factor))
			)
			extra_bottom = maxi(
				extra_bottom,
				int(round(float(window_size.y - (safe.position.y + safe.size.y)) * scale_factor))
			)
		# En inmersivo el área segura a veces llega a 0; el recorte de la cámara sí se informa.
		var cutouts: Array = DisplayServer.get_display_cutouts()
		for item in cutouts:
			var cutout := Rect2(item)
			if cutout.size.x <= 0.0 or cutout.size.y <= 0.0:
				continue
			if cutout.position.y <= float(window_size.y) * 0.35:
				extra_top = maxi(extra_top, int(round(cutout.end.y * scale_factor)))
			if cutout.end.y >= float(window_size.y) * 0.65:
				extra_bottom = maxi(
					extra_bottom,
					int(round((float(window_size.y) - cutout.position.y) * scale_factor))
				)
			if cutout.position.x <= float(window_size.x) * 0.25:
				extra_left = maxi(extra_left, int(round(cutout.end.x * scale_factor)))
			if cutout.end.x >= float(window_size.x) * 0.75:
				extra_right = maxi(
					extra_right,
					int(round((float(window_size.x) - cutout.position.x) * scale_factor))
				)

	return Vector4i(
		CONTENT_PAD_H + extra_left,
		CONTENT_PAD_TOP + extra_top,
		CONTENT_PAD_H + extra_right,
		CONTENT_PAD_BOTTOM + extra_bottom
	)


func _show_loading(message: String = "Generando nivel…") -> void:
	if _loading == null:
		return
	_loading.visible = true
	_loading.modulate = Color(1, 1, 1, 1)
	if _loading.has_method("set_message"):
		_loading.set_message(message)
	_loading.mouse_filter = Control.MOUSE_FILTER_STOP


func _hide_loading() -> void:
	if _loading == null:
		return
	var tween := create_tween()
	tween.tween_property(_loading, "modulate:a", 0.0, 0.22)
	tween.tween_callback(_finish_hide_loading)


func _finish_hide_loading() -> void:
	if _loading == null:
		return
	_loading.visible = false
	_loading.modulate = Color(1, 1, 1, 1)
	_loading.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _load_level_async() -> void:
	if _is_loading_level:
		return
	_is_loading_level = true

	# Si se entra ya en era Emoji sin haber visto la intro, reproducirla.
	if _should_play_emoji_era_intro(_level_id) and not _era_transition_playing:
		await _play_emoji_era_transition(false)

	_show_loading("Generando nivel %d…" % _level_id)

	# Deja pintar el spinner; la generación corre en segundo plano.
	await get_tree().process_frame
	await get_tree().process_frame

	_current_level = await LevelManager.get_level_async(_level_id)
	if _current_level.is_empty():
		_level_id = 1
		LevelManager.set_current_level(_level_id)
		_current_level = await LevelManager.get_level_async(1)

	if _current_level.is_empty():
		_level_label.text = "—"
		push_error("Game: nivel vacío en modo %s" % LevelManager.current_mode)
		_is_loading_level = false
		_hide_loading()
		return

	_level_label.text = str(_level_id)
	_refresh_score_label()
	_apply_background_for_level(_level_id)
	_board.modulate = Color(1, 1, 1, 1)
	_board.setup_level(_current_level)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in _overlay.get_children():
		child.queue_free()

	_is_loading_level = false
	_level_started_msec = Time.get_ticks_msec()
	_reset_chrono_timer()
	_hide_loading()
	if _era_board_reveal and _content_root != null:
		# Listo bajo el negro de la cinemática: visible al levantar el velo (sin fade solo-estrellas).
		_era_board_reveal = false
		_content_root.modulate = Color(1, 1, 1, 1)
	elif _content_root != null:
		_content_root.modulate = Color(1, 1, 1, 1)


func _on_pairs_changed(remaining: int, total: int) -> void:
	if _pairs_label == null:
		return
	_pairs_label.text = "%d/%d" % [total - remaining, total]


func _refresh_score_label() -> void:
	if _score_label == null:
		return
	_score_label.text = str(SaveManager.get_score())


func _is_chrono_mode() -> bool:
	return LevelManager.current_mode == LevelManager.MODE_CHRONO


func _is_chrono_paused() -> bool:
	if _chrono_chaos_busy:
		return true
	if _lose_overlay != null and _lose_overlay.visible:
		return true
	if _is_loading_level or _is_resolving or _era_transition_playing:
		return true
	if _board != null and _board.is_celebrating():
		return true
	if _board != null and bool(_board.get("just_completed")):
		return true
	if _overlay != null and _overlay.visible:
		return true
	if _confirm_overlay != null and _confirm_overlay.visible:
		return true
	if _notice_overlay != null and _notice_overlay.visible:
		return true
	if _loading != null and _loading.visible:
		return true
	return false


func _reset_chrono_timer() -> void:
	if not _is_chrono_mode():
		_chrono_running = false
		return
	_chrono_remaining = CHRONO_CHAOS_INTERVAL_SEC
	_chrono_running = true
	_chrono_last_urgency_tick = -1
	_timer_text_cache = ""
	_timer_urgent_cache = false
	if _board != null and _board.has_method("clear_urgency_recolor"):
		_board.clear_urgency_recolor()
	_refresh_timer_label()


func _make_chrono_timer_banner() -> Control:
	var wrap := CenterContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_panel = null

	_timer_digits = HBoxContainer.new()
	_timer_digits.alignment = BoxContainer.ALIGNMENT_CENTER
	_timer_digits.add_theme_constant_override("separation", 8)
	_timer_digits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(_timer_digits)

	_chrono_remaining = CHRONO_CHAOS_INTERVAL_SEC
	_refresh_timer_label()
	return wrap


func _refresh_timer_label() -> void:
	if _timer_digits == null:
		return
	var total := int(ceil(_chrono_remaining))
	@warning_ignore("integer_division")
	var mins := total / 60
	var secs := total % 60
	var text := "%d:%02d" % [mins, secs]
	var urgent := _chrono_remaining <= CHRONO_URGENCY_SEC and _chrono_remaining > 0.0
	if text == _timer_text_cache and urgent == _timer_urgent_cache:
		return
	_timer_text_cache = text
	_timer_urgent_cache = urgent
	var font_size := 50 if urgent else 46

	while _timer_digits.get_child_count() > 0:
		var old: Node = _timer_digits.get_child(0)
		_timer_digits.remove_child(old)
		old.queue_free()

	for i in range(text.length()):
		var ch := text[i]
		var color: Color = TITLE_LETTER_COLORS[i % TITLE_LETTER_COLORS.size()]
		if urgent:
			color = color.lerp(Color("FF3B5C"), 0.35)
		var digit := Label.new()
		digit.text = ch
		digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		digit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		digit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		digit.add_theme_constant_override("letter_spacing", 2)
		digit.add_theme_font_size_override("font_size", font_size)
		UIFactory.apply_title_font(digit)
		digit.add_theme_color_override("font_color", color)
		digit.add_theme_color_override("font_outline_color", Color("0A1848"))
		digit.add_theme_constant_override("outline_size", 7)
		digit.add_theme_color_override("font_shadow_color", Color(0.05, 0.08, 0.25, 0.55))
		digit.add_theme_constant_override("shadow_offset_x", 0)
		digit.add_theme_constant_override("shadow_offset_y", 2)
		digit.add_theme_constant_override("shadow_outline_size", 3)
		_timer_digits.add_child(digit)


## Regenera parejas no completadas; las ya unidas se mantienen.
func _run_chrono_chaos() -> void:
	if _board == null or not _board.has_method("chaos_recolor"):
		return
	_chrono_chaos_busy = true
	var result: Dictionary = _board.chaos_recolor()
	AudioManager.play(AudioManager.Sfx.INVALID)
	AudioManager.vibrate(55)
	if bool(result.get("need_full_regen", false)):
		push_warning("Crazy chaos: no se pudo regenerar el resto; se mantiene el tablero.")
	_chrono_chaos_busy = false


func _update_chrono_urgency() -> void:
	if _board == null or not _board.has_method("urgency_recolor_tick"):
		return
	if _chrono_remaining > CHRONO_URGENCY_SEC or _chrono_remaining <= 0.0:
		if _chrono_last_urgency_tick >= 0 and _chrono_remaining > CHRONO_URGENCY_SEC:
			_chrono_last_urgency_tick = -1
			if _board.has_method("clear_urgency_recolor"):
				_board.clear_urgency_recolor()
		return
	# ceil: en 10.0→10, 9.01→10… al bajar de 10 a 9 dispara el tick 9, etc.
	var tick := int(ceil(_chrono_remaining))
	tick = clampi(tick, 1, int(CHRONO_URGENCY_SEC))
	if tick == _chrono_last_urgency_tick:
		return
	_chrono_last_urgency_tick = tick
	_board.urgency_recolor_tick(tick)


## Fin de ciclo: caos + reinicio del contador. No hay derrota por tiempo.
func _on_chrono_chaos_tick() -> void:
	if _chrono_chaos_busy:
		return
	if _lose_overlay != null and _lose_overlay.visible:
		return
	if _board != null and _board.has_method("clear_urgency_recolor"):
		_board.clear_urgency_recolor()
	_chrono_last_urgency_tick = -1
	_run_chrono_chaos()
	_chrono_remaining = CHRONO_CHAOS_INTERVAL_SEC
	_chrono_running = true
	_timer_text_cache = ""
	_timer_urgent_cache = false
	_refresh_timer_label()


func _build_lose_overlay() -> void:
	_lose_overlay = Control.new()
	_lose_overlay.visible = false
	_lose_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lose_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_lose_overlay.z_index = 45
	add_child(_lose_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.12, 0.02, 0.18, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_lose_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lose_overlay.add_child(center)

	var panel := UIFactory.make_glass_panel()
	panel.custom_minimum_size = Vector2(440, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.04, 0.22, 0.97)
	style.border_color = Color("FF3B5C")
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_left = 28
	style.corner_radius_bottom_right = 28
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(360, 0)
	panel.add_child(box)

	_lose_title = UIFactory.make_neon_title("¡Tiempo agotado!", 36)
	_lose_title.add_theme_color_override("font_color", Color("FF3B5C"))
	box.add_child(_lose_title)

	var msg := UIFactory.make_light_subtitle(
		"No has unido todas las parejas a tiempo.\n¿Quieres volver a intentarlo?",
		26
	)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.custom_minimum_size = Vector2(320, 0)
	box.add_child(msg)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(buttons)

	var retry_btn := UIFactory.make_accent_button("VOLVER A INTENTAR", 90)
	UIFactory.set_button_icon(retry_btn, UIFactory.ButtonIcon.RESTART)
	retry_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry_btn.pressed.connect(_on_lose_retry)
	buttons.add_child(retry_btn)

	var exit_btn := UIFactory.make_button("SALIR", 84)
	UIFactory.set_button_colors(exit_btn, GamePalette.MENU_BLUE, Color.WHITE)
	UIFactory.set_button_icon(exit_btn, UIFactory.ButtonIcon.BACK, Color.WHITE)
	exit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_btn.pressed.connect(_on_lose_exit)
	buttons.add_child(exit_btn)


func _show_lose_overlay() -> void:
	if _lose_overlay == null:
		return
	_lose_overlay.visible = true
	_lose_overlay.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_lose_overlay, "modulate:a", 1.0, 0.2)


func _hide_lose_overlay() -> void:
	if _lose_overlay == null:
		return
	_lose_overlay.visible = false


func _on_lose_retry() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	_hide_lose_overlay()
	if _board != null and not _current_level.is_empty():
		_board.setup_level(_current_level)
	_reset_chrono_timer()


func _on_lose_exit() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	get_tree().change_scene_to_file.call_deferred("res://scenes/mode_hub.tscn")


func _make_mode_title(mode_title: String) -> Control:
	if LevelManager.current_mode == LevelManager.MODE_CHRONO:
		return UIFactory.make_crazy_logo_title(240.0)

	var words := mode_title.split(" ", false)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -20)

	var word_index := 0
	for word_variant: Variant in words:
		var word := str(word_variant).to_upper()
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", -4)
		for i in range(word.length()):
			row.add_child(
				_make_title_letter(word[i], word_index == 0, i % TITLE_LETTER_COLORS.size(), 58)
			)
		box.add_child(row)
		word_index += 1

	var underline := Control.new()
	underline.custom_minimum_size = Vector2(0, 28)
	underline.draw.connect(_draw_title_underline.bind(underline))
	box.add_child(underline)
	return box


func _make_title_letter(letter: String, white: bool, color_index: int, font_size: int = 58) -> Label:
	var label := Label.new()
	label.text = letter
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	UIFactory.apply_title_font(label)
	if white:
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color("1A3A8E"))
		label.add_theme_constant_override("outline_size", 14)
		label.add_theme_color_override("font_shadow_color", Color("0A1848"))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 6)
		label.add_theme_constant_override("shadow_outline_size", 12)
	else:
		var color: Color = TITLE_LETTER_COLORS[color_index]
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_outline_color", Color("1A1F6E"))
		label.add_theme_constant_override("outline_size", 12)
		label.add_theme_color_override("font_shadow_color", Color(0.05, 0.08, 0.28, 0.75))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 5)
		label.add_theme_constant_override("shadow_outline_size", 10)
	return label


func _draw_title_underline(control: Control) -> void:
	var w := control.size.x
	if w < 8.0:
		return
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var steps := 32
	var y := 14.0
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		points.append(Vector2(lerpf(w * 0.18, w * 0.82, t), y + sin(t * PI) * 3.5))
		if t < 0.33:
			colors.append(Color("FF4FB0").lerp(Color("FFB23D"), t / 0.33))
		elif t < 0.66:
			colors.append(Color("FFB23D").lerp(Color("7BE04A"), (t - 0.33) / 0.33))
		else:
			colors.append(Color("7BE04A").lerp(Color("3CC8F0"), (t - 0.66) / 0.34))
	control.draw_polyline_colors(points, colors, 3.2, true)
	var dots := [[0.0, Color("FF4FB0")], [0.5, Color("FFB23D")], [1.0, Color("3CC8F0")]]
	for dot: Array in dots:
		var index := clampi(int(float(dot[0]) * float(steps)), 0, points.size() - 1)
		var color: Color = dot[1]
		control.draw_circle(points[index], 7.5, Color(color.r, color.g, color.b, 0.28))
		control.draw_circle(points[index], 4.2, color)
		control.draw_circle(points[index] + Vector2(-1.2, -1.2), 1.5, Color(1, 1, 1, 0.85))


func _make_stats_header_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.10, 0.36, 0.82)
	style.border_color = Color(0.40, 0.58, 1.0, 0.45)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_left = 28
	style.corner_radius_bottom_right = 28
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0.15, 0.4)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_stat_divider() -> Control:
	var divider := Control.new()
	divider.custom_minimum_size = Vector2(14, 56)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.draw.connect(func() -> void:
		var x := divider.size.x * 0.5
		divider.draw_line(Vector2(x, 8.0), Vector2(x, divider.size.y - 8.0), Color(0.55, 0.68, 1.0, 0.28), 2.0, true)
	)
	return divider


func _make_stat_item(kind: String, caption: String, value_color: Color) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon := Control.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(_draw_stat_icon.bind(icon, kind))
	box.add_child(icon)

	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", -2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(texts)

	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.add_theme_font_size_override("font_size", 22)
	caption_label.add_theme_color_override("font_color", Color.WHITE)
	caption_label.add_theme_color_override("font_outline_color", Color("0A1848"))
	caption_label.add_theme_constant_override("outline_size", 4)
	UIFactory.apply_font(caption_label, true)
	texts.add_child(caption_label)

	var value_row := HBoxContainer.new()
	value_row.add_theme_constant_override("separation", 4)
	texts.add_child(value_row)

	var value := Label.new()
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 34)
	value.add_theme_color_override("font_color", value_color)
	value.add_theme_color_override("font_outline_color", Color("1A1F6E"))
	value.add_theme_constant_override("outline_size", 8)
	value.add_theme_color_override("font_shadow_color", Color(0.05, 0.08, 0.25, 0.55))
	value.add_theme_constant_override("shadow_offset_x", 0)
	value.add_theme_constant_override("shadow_offset_y", 2)
	value.add_theme_constant_override("shadow_outline_size", 4)
	UIFactory.apply_title_font(value)
	value_row.add_child(value)

	var spark := Control.new()
	spark.custom_minimum_size = Vector2(14, 28)
	spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spark.draw.connect(_draw_stat_sparkles.bind(spark, value_color))
	value_row.add_child(spark)

	box.set_meta("value_label", value)
	return box


func _draw_stat_sparkles(node: Control, color: Color) -> void:
	var c := color.lightened(0.15)
	node.draw_line(Vector2(3, 8), Vector2(10, 5), c, 2.0, true)
	node.draw_line(Vector2(4, 14), Vector2(12, 12), c, 2.0, true)
	node.draw_line(Vector2(3, 20), Vector2(9, 22), c, 2.0, true)


func _draw_stat_icon(icon: Control, kind: String) -> void:
	var c := icon.size * 0.5
	var ring := Color.WHITE
	var fill := Color.WHITE
	match kind:
		"flag":
			ring = Color("FFD84A")
			fill = Color("FFE45E")
		"moves":
			ring = Color("7BE04A")
			fill = Color("9AF06A")
		"timer":
			ring = Color("2EB8FF")
			fill = Color("5AD0FF")
		"pairs":
			ring = Color("FF8AD8")
			fill = Color("FFA0E0")
		"score":
			ring = Color("FFB020")
			fill = Color("FFD84A")
		_:
			ring = Color("FFE45E")
			fill = ring

	# Halo + disco glossy.
	icon.draw_circle(c, 22.0, Color(ring.r, ring.g, ring.b, 0.22))
	icon.draw_circle(c, 18.0, Color(ring.r, ring.g, ring.b, 0.55))
	icon.draw_circle(c, 15.5, Color("12225A"))
	icon.draw_circle(c, 14.0, Color("1A3078"))
	icon.draw_arc(c, 15.0, 0.0, TAU, 36, Color(ring.r, ring.g, ring.b, 0.95), 2.4, true)
	icon.draw_circle(c + Vector2(-4.5, -5.0), 3.2, Color(1, 1, 1, 0.28))

	match kind:
		"flag":
			var pole_a := c + Vector2(-5, -8)
			var pole_b := c + Vector2(-5, 8)
			icon.draw_line(pole_a, pole_b, Color("E8C040"), 2.6, true)
			icon.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-3.5, -8),
				c + Vector2(9, -4),
				c + Vector2(-3.5, 0.5),
			]), fill)
			icon.draw_circle(pole_b, 1.8, Color("C49A20"))
		"moves", "timer":
			icon.draw_arc(c, 7.5, deg_to_rad(-30.0), deg_to_rad(230.0), 28, fill, 3.0, true)
			var tip := c + Vector2(cos(deg_to_rad(-30.0)), sin(deg_to_rad(-30.0))) * 7.5
			icon.draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-5, -2),
				tip + Vector2(4, -5),
				tip + Vector2(1, 5),
			]), fill)
		"pairs":
			icon.draw_circle(c + Vector2(-4, 1), 6.2, Color("9A52E6"))
			icon.draw_circle(c + Vector2(4, -1), 6.2, Color("3CC8F0"))
			icon.draw_circle(c + Vector2(-5.5, -1), 1.8, Color(1, 1, 1, 0.45))
			icon.draw_circle(c + Vector2(2.5, -3), 1.6, Color(1, 1, 1, 0.45))
		"score":
			var star := PackedVector2Array()
			for i in range(5):
				var a_out := deg_to_rad(-90.0 + float(i) * 72.0)
				var a_in := deg_to_rad(-90.0 + 36.0 + float(i) * 72.0)
				star.append(c + Vector2(cos(a_out), sin(a_out)) * 8.5)
				star.append(c + Vector2(cos(a_in), sin(a_in)) * 3.6)
			icon.draw_colored_polygon(star, fill)
			icon.draw_circle(c + Vector2(-2.0, -1.5), 1.4, Color(1, 1, 1, 0.4))
		_:
			icon.draw_circle(c, 6.0, fill)


func _on_invalid_move() -> void:
	pass


func _on_reset() -> void:
	if _is_loading_level or _is_resolving or (_board != null and _board.is_celebrating()):
		return
	_board.reset_level()
	_reset_chrono_timer()


func _on_hint() -> void:
	if _is_loading_level or _is_resolving or (_board != null and _board.is_celebrating()):
		return
	if SaveManager.get_hints() <= 0:
		AudioManager.play(AudioManager.Sfx.INVALID)
		_refresh_hint_button()
		return
	if not _board.show_hint():
		AudioManager.play(AudioManager.Sfx.INVALID)
		return
	SaveManager.consume_hint()
	_refresh_hint_button()


func _refresh_hint_button() -> void:
	var hints := SaveManager.get_hints()
	if _hint_btn != null:
		_hint_btn.text = "PISTA (%d)" % hints
		_hint_btn.disabled = hints <= 0 or _is_resolving
	if _resolve_btn != null:
		# Siempre clicable (salvo resolviendo/cargando): si faltan pistas, se muestra aviso.
		_resolve_btn.disabled = _is_resolving or _is_loading_level
		_resolve_btn.tooltip_text = (
			"Gasta todas las pistas (8 o más) para resolver y pasar"
			if SaveManager.can_redeem_hints()
			else "Necesitas 8 o más pistas (tienes %d). Pulsa para más info." % hints
		)


func _build_confirm_overlay() -> void:
	_confirm_overlay = Control.new()
	_confirm_overlay.visible = false
	_confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_overlay.z_index = 40
	add_child(_confirm_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.08, 0.28, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_overlay.add_child(center)

	var panel := UIFactory.make_glass_panel()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Cartel azul más sólido + borde amarillo de la paleta.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(GamePalette.MENU_DARKEST.r, GamePalette.MENU_DARKEST.g, GamePalette.MENU_DARKEST.b, 0.96)
	style.border_color = GamePalette.MENU_YELLOW
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_left = 28
	style.corner_radius_bottom_right = 28
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(360, 0)
	panel.add_child(box)

	var title := UIFactory.make_neon_title("Resolver nivel", 36)
	title.add_theme_color_override("font_color", GamePalette.MENU_YELLOW)
	box.add_child(title)

	_confirm_message = UIFactory.make_light_subtitle("", 26)
	_confirm_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_message.custom_minimum_size = Vector2(320, 0)
	box.add_child(_confirm_message)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(buttons)

	var cancel_btn := UIFactory.make_button("CANCELAR", 84)
	UIFactory.set_button_colors(cancel_btn, GamePalette.MENU_YELLOW, GamePalette.MENU_YELLOW_TEXT)
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(_hide_confirm_overlay)
	buttons.add_child(cancel_btn)

	var ok_btn := UIFactory.make_button("RESOLVER", 84)
	UIFactory.set_button_colors(ok_btn, GamePalette.ACCENT_MAGENTA, Color.WHITE)
	UIFactory.set_button_icon(ok_btn, UIFactory.ButtonIcon.SPARKLE, Color.WHITE)
	ok_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok_btn.pressed.connect(_on_resolve_confirmed)
	buttons.add_child(ok_btn)


func _show_confirm_overlay(message: String) -> void:
	if _confirm_overlay == null or _confirm_message == null:
		return
	_confirm_message.text = message
	_confirm_overlay.visible = true
	_confirm_overlay.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_confirm_overlay, "modulate:a", 1.0, 0.18)


func _hide_confirm_overlay() -> void:
	if _confirm_overlay == null:
		return
	_confirm_overlay.visible = false


func _on_resolve_pressed() -> void:
	if _is_loading_level or _is_resolving or (_board != null and _board.is_celebrating()):
		return
	var n := SaveManager.get_hints()
	if not SaveManager.can_redeem_hints():
		AudioManager.play(AudioManager.Sfx.INVALID)
		_show_notice_overlay(
			"No puedes intercambiar pistas para resolver el nivel.\n\nNecesitas al menos 8 pistas y ahora tienes %d.\n\nConsigue más pistas completando niveles (sobre todo con 3 estrellas) e inténtalo de nuevo."
			% n
		)
		return
	_show_confirm_overlay(
		"Se gastarán todas tus pistas (%d).\n\nEl nivel se resolverá sin estrellas ni recompensas, y el siguiente será más denso.\n\n¿Continuar?"
		% n
	)


func _build_notice_overlay() -> void:
	_notice_overlay = Control.new()
	_notice_overlay.visible = false
	_notice_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_notice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_notice_overlay.z_index = 41
	add_child(_notice_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.08, 0.28, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_notice_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_overlay.add_child(center)

	var panel := UIFactory.make_glass_panel()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color(GamePalette.MENU_DARKEST.r, GamePalette.MENU_DARKEST.g, GamePalette.MENU_DARKEST.b, 0.96)
	style.border_color = GamePalette.MENU_YELLOW
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_left = 28
	style.corner_radius_bottom_right = 28
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(360, 0)
	panel.add_child(box)

	var title := UIFactory.make_neon_title("Pistas insuficientes", 34)
	title.add_theme_color_override("font_color", GamePalette.MENU_YELLOW)
	box.add_child(title)

	_notice_message = UIFactory.make_light_subtitle("", 26)
	_notice_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_message.custom_minimum_size = Vector2(320, 0)
	box.add_child(_notice_message)

	var ok_btn := UIFactory.make_button("ENTENDIDO", 84)
	UIFactory.set_button_colors(ok_btn, GamePalette.MENU_YELLOW, GamePalette.MENU_YELLOW_TEXT)
	ok_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok_btn.pressed.connect(_hide_notice_overlay)
	box.add_child(ok_btn)


func _show_notice_overlay(message: String) -> void:
	if _notice_overlay == null or _notice_message == null:
		return
	_notice_message.text = message
	_notice_overlay.visible = true
	_notice_overlay.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_notice_overlay, "modulate:a", 1.0, 0.18)


func _hide_notice_overlay() -> void:
	if _notice_overlay == null:
		return
	_notice_overlay.visible = false
	AudioManager.play(AudioManager.Sfx.SELECT)


func _on_resolve_confirmed() -> void:
	_hide_confirm_overlay()
	if _is_loading_level or _is_resolving:
		return
	if not SaveManager.can_redeem_hints():
		_refresh_hint_button()
		return
	_is_resolving = true
	_refresh_hint_button()
	var result: Dictionary = SaveManager.redeem_hints_to_skip(_level_id)
	if not bool(result.get("ok", false)):
		_is_resolving = false
		_refresh_hint_button()
		return
	_pending_skip_spent = int(result.get("spent", 0))
	_pending_skip_next = int(result.get("next_level_id", _level_id + 1))
	AudioManager.play(AudioManager.Sfx.CONNECT)
	_board.solution_revealed.connect(_on_solution_revealed_for_skip, CONNECT_ONE_SHOT)
	_board.reveal_solution(true)


func _on_solution_revealed_for_skip() -> void:
	_show_skip_overlay(_pending_skip_next, _pending_skip_spent)


func _on_menu() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/main_menu.tscn")


func _on_sound_pressed() -> void:
	SettingsManager.toggle_sound()


func _refresh_sound_button(_arg: Variant = null) -> void:
	if _sound_btn == null or not is_instance_valid(_sound_btn):
		return
	var on := SettingsManager.sound_enabled
	if on:
		UIFactory.set_button_colors(_sound_btn, GamePalette.MENU_BLUE, Color.WHITE)
		UIFactory.set_button_icon(_sound_btn, UIFactory.ButtonIcon.SOUND)
		_sound_btn.tooltip_text = "Sonido: activado"
	else:
		UIFactory.set_button_colors(_sound_btn, Color("5A6A90"), Color("D0D8F0"))
		UIFactory.set_button_icon(_sound_btn, UIFactory.ButtonIcon.SOUND_MUTE)
		_sound_btn.tooltip_text = "Sonido: desactivado"


func _on_level_completed(moves: int) -> void:
	if _is_resolving:
		return
	var stars := LevelManager.calculate_stars(_current_level, moves)
	var elapsed_sec := 0.0
	if _level_started_msec > 0:
		elapsed_sec = float(Time.get_ticks_msec() - _level_started_msec) / 1000.0
	var reward: Dictionary = SaveManager.register_level_complete(
		_level_id,
		moves,
		stars,
		"",
		elapsed_sec,
		_current_level
	)
	var hint_reward := int(reward.get("hint_reward", 0))
	_refresh_hint_button()
	_refresh_score_label()

	# Completar el 99: cinemática de era siempre (sin overlay de victoria).
	if (
		LevelManager.current_mode != LevelManager.MODE_SANDBOX
		and _level_id == BoardTheme.EMOJI_START - 1
	):
		await _play_emoji_era_transition(true)
		# El nivel 100 se carga en ready_for_new_board; fallback si no.
		if not _era_next_preloaded:
			var next_id := LevelManager.get_next_level_id(_level_id)
			if next_id > 0:
				LevelManager.set_current_level(next_id)
				_level_id = next_id
				_load_level_async()
		_era_next_preloaded = false
		return

	_show_complete_overlay(moves, stars, hint_reward, reward)


func _show_complete_overlay(
	moves: int,
	stars: int,
	hint_reward: int = 0,
	reward_meta: Dictionary = {}
) -> void:
	for child in _overlay.get_children():
		child.queue_free()

	_overlay.visible = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var victory = VictoryOverlayScript.new()
	victory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(victory)

	var next_id := LevelManager.get_next_level_id(_level_id)
	victory.next_pressed.connect(_on_victory_next.bind(next_id))
	victory.retry_pressed.connect(_on_victory_retry)
	victory.menu_pressed.connect(_on_menu)

	victory.present(
		moves,
		stars,
		_board.get_completed_color_stats(),
		next_id > 0,
		_level_id,
		hint_reward,
		reward_meta
	)


func _show_skip_overlay(next_id: int, spent: int) -> void:
	## Deja la solución visible en el tablero; solo muestra Continuar abajo.
	_hide_skip_review_bar()
	for child in _overlay.get_children():
		child.queue_free()
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _actions_box != null:
		_actions_box.visible = false

	_skip_review_bar = PanelContainer.new()
	_skip_review_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.12, 0.42, 0.94)
	style.border_color = Color(0.45, 0.65, 1.0, 0.55)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_skip_review_bar.add_theme_stylebox_override("panel", style)

	# Insertar la barra donde estaban las acciones (bajo el tablero).
	var parent := _actions_box.get_parent() if _actions_box != null else null
	if parent != null:
		var idx := _actions_box.get_index()
		parent.add_child(_skip_review_bar)
		parent.move_child(_skip_review_bar, idx)
	else:
		add_child(_skip_review_bar)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_skip_review_bar.add_child(col)

	var msg := UIFactory.make_light_subtitle(
		"Solución revelada · Gastaste %d pistas · Sin estrellas ni recompensas"
		% maxi(0, spent),
		22
	)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(msg)

	var continue_btn := UIFactory.make_accent_button("CONTINUAR", 90)
	continue_btn.disabled = next_id <= 0
	continue_btn.pressed.connect(_on_skip_continue.bind(next_id))
	col.add_child(continue_btn)


func _hide_skip_review_bar() -> void:
	if is_instance_valid(_skip_review_bar):
		_skip_review_bar.queue_free()
	_skip_review_bar = null
	if _actions_box != null:
		_actions_box.visible = true


func _on_skip_continue(next_id: int) -> void:
	_hide_skip_review_bar()
	_is_resolving = false
	_on_victory_next(next_id)


func _on_victory_next(next_id: int) -> void:
	if next_id <= 0 or _is_loading_level or _era_transition_playing:
		return
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in _overlay.get_children():
		child.queue_free()
	_refresh_hint_button()

	LevelManager.set_current_level(next_id)
	_level_id = next_id
	_load_level_async()


func _crosses_into_emoji_era(from_id: int, to_id: int) -> bool:
	return from_id < BoardTheme.EMOJI_START and to_id >= BoardTheme.EMOJI_START


func _should_play_emoji_era_intro(level_id: int) -> bool:
	if LevelManager.current_mode == LevelManager.MODE_SANDBOX:
		return false
	return level_id >= BoardTheme.EMOJI_START and not SaveManager.emoji_era_intro_done


func _play_emoji_era_transition(use_board_debris: bool) -> void:
	if _era_transition_playing:
		return
	_era_transition_playing = true
	_era_board_reveal = true
	_era_next_preloaded = false
	_hide_loading()
	var cinematic = EraTransitionScript.new()
	cinematic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cinematic)
	var board_ref: Board = null
	if use_board_debris and _board != null and is_instance_valid(_board):
		if _board is Board:
			board_ref = _board as Board
		elif _board.has_method("get_cell_center_global") and _board.has_method("play_era_board_destroy"):
			board_ref = _board as Board
	if cinematic.has_signal("ready_for_new_board"):
		cinematic.ready_for_new_board.connect(
			_on_era_ready_for_new_board.bind(cinematic), CONNECT_ONE_SHOT
		)
	await cinematic.play(board_ref, _content_root, _bg)
	if is_instance_valid(cinematic):
		cinematic.queue_free()
	SaveManager.mark_emoji_era_intro_done()
	# Space ya viene del handoff; no recrear fondo.
	if _bg == null or not is_instance_valid(_bg) or not _bg.has_method("set_warp"):
		_apply_background_for_level(maxi(_level_id, BoardTheme.EMOJI_START))
	_era_transition_playing = false


func _on_era_ready_for_new_board(cinematic: Control) -> void:
	if cinematic != null and is_instance_valid(cinematic) and cinematic.has_method("handoff_space_background"):
		var space: Control = cinematic.call("handoff_space_background")
		if space != null and is_instance_valid(space):
			if is_instance_valid(_bg):
				_bg.queue_free()
			_bg = space
			add_child(_bg)
			move_child(_bg, 0)
			if _bg.has_method("set_warp"):
				_bg.call("set_warp", 0.38)
	if _content_root != null:
		_content_root.modulate = Color(1, 1, 1, 0)

	# Intro al entrar ya en emoji: el _load_level_async exterior terminará el tablero.
	if _level_id >= BoardTheme.EMOJI_START or _is_loading_level:
		if cinematic != null and is_instance_valid(cinematic) and cinematic.has_method("mark_new_board_ready"):
			cinematic.call("mark_new_board_ready")
		return

	# Desde el 99: cargar nivel 100 bajo el negro de la cinemática.
	var next_id := LevelManager.get_next_level_id(_level_id)
	if next_id <= 0:
		next_id = BoardTheme.EMOJI_START
	LevelManager.set_current_level(next_id)
	_level_id = next_id
	_era_next_preloaded = true
	await _load_level_async()
	if cinematic != null and is_instance_valid(cinematic) and cinematic.has_method("mark_new_board_ready"):
		cinematic.call("mark_new_board_ready")


func _apply_background_for_level(level_id: int) -> void:
	# Modo Crazy: foto psicodélica fija (sin FX).
	if LevelManager.current_mode == LevelManager.MODE_CHRONO:
		if (
			_bg != null
			and is_instance_valid(_bg)
			and str(_bg.get("photo_path")) == "res://assets/backgrounds/crazy.jpg"
		):
			return
		if is_instance_valid(_bg):
			_bg.queue_free()
			_bg = null
		_bg = UIFactory.attach_level_background(self, level_id)
		return

	# Hardcore: burbujas rojas en 1–99; espacio en era Emoji.
	if LevelManager.current_mode == LevelManager.MODE_HARDCORE:
		var hardcore_space := (
			BoardTheme.uses_emoji(level_id)
			or BoardTheme.kind_for_level(level_id) == BoardTheme.Kind.CONTRAST
		)
		if not hardcore_space:
			if _bg != null and is_instance_valid(_bg) and _bg.has_method("set_palette_band"):
				if (
					_bg.has_method("get_palette_band")
					and int(_bg.call("get_palette_band")) == UIFactory.HARDCORE_PALETTE_BAND
				):
					return
				_bg.call("set_palette_band", UIFactory.HARDCORE_PALETTE_BAND)
				return
			if is_instance_valid(_bg):
				_bg.queue_free()
				_bg = null
			_bg = UIFactory.attach_level_background(self, level_id)
			return

	# Sandbox: siempre burbujas; solo cambia el color de fondo cada 10 niveles.
	if LevelManager.current_mode == LevelManager.MODE_SANDBOX:
		var band := LevelBackdrop.sandbox_palette_band(level_id)
		if _bg != null and is_instance_valid(_bg) and _bg.has_method("set_palette_band"):
			if _bg.has_method("get_palette_band") and int(_bg.call("get_palette_band")) == band:
				return
			_bg.call("set_palette_band", band)
			return
		if is_instance_valid(_bg):
			_bg.queue_free()
			_bg = null
		_bg = UIFactory.attach_level_background(self, level_id)
		return

	var want_space := (
		BoardTheme.uses_emoji(level_id)
		or BoardTheme.kind_for_level(level_id) == BoardTheme.Kind.CONTRAST
	)
	var is_space := _bg != null and is_instance_valid(_bg) and _bg.has_method("set_warp")
	if want_space:
		var space_band := LevelBackdrop.emoji_space_palette_band(level_id)
		if is_space and _bg != null and is_instance_valid(_bg):
			if _bg.has_method("set_palette_band"):
				if (
					not _bg.has_method("get_palette_band")
					or int(_bg.call("get_palette_band")) != space_band
				):
					_bg.call("set_palette_band", space_band)
			if _bg.has_method("set_warp"):
				_bg.call("set_warp", 0.38)
			return
		if is_instance_valid(_bg):
			_bg.queue_free()
			_bg = null
		_bg = UIFactory.attach_level_background(self, level_id)
		if _bg != null and _bg.has_method("set_palette_band"):
			_bg.call("set_palette_band", space_band)
		if _bg != null and _bg.has_method("set_warp"):
			_bg.call("set_warp", 0.38)
		return

	# Niveles 1–99: motivos animados con fundido al cambiar de banda.
	var want_motif := LevelBackdrop.motif_for_level(level_id)
	if _bg != null and is_instance_valid(_bg) and not is_space:
		if LevelBackdrop.motif_of(_bg) == want_motif:
			return

	var old_bg: Control = _bg if is_instance_valid(_bg) else null
	var new_bg := LevelBackdrop.create_for_level(level_id)
	new_bg.modulate = Color(1, 1, 1, 0)
	add_child(new_bg)
	move_child(new_bg, 0)
	_bg = new_bg

	if old_bg != null and is_instance_valid(old_bg):
		if old_bg.get_parent() == self:
			move_child(old_bg, 1)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(new_bg, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(old_bg, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(old_bg.queue_free)
	else:
		var tw := create_tween()
		tw.tween_property(new_bg, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_victory_retry() -> void:
	if _is_loading_level or _is_resolving:
		return
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in _overlay.get_children():
		child.queue_free()
	_refresh_hint_button()
	_level_started_msec = Time.get_ticks_msec()
	_board.reset_level()
