extends Control

## Cartel de victoria: título → estrellas (una a una) → puntuación → pistas/botones.

signal next_pressed
signal retry_pressed
signal menu_pressed

const HINTS_BADGE_DEPTH := 7.0
const TITLE_FONT_SIZE := 74
const TITLE_FLYER_FONT_SIZE := 86
const ColorShapesScript := preload("res://scripts/color_shapes.gd")
## Márgenes mínimos además del safe area (notch / barra de navegación).
const SAFE_PAD_H := 20
const SAFE_PAD_TOP := 24
const SAFE_PAD_BOTTOM := 28

const TITLE_LETTER_COLORS: Array[Color] = [
	Color("FFD43B"),
	Color("FF8A3D"),
	Color("FF4FB0"),
	Color("9A52E6"),
	Color("4F8BFF"),
	Color("3CC8F0"),
	Color("7BE04A"),
	Color("3DDC97"),
]

const CONFETTI_COLORS: Array[Color] = [
	Color("FFD43B"),
	Color("FF4FB0"),
	Color("7BE04A"),
	Color("3CC8F0"),
	Color("FF8A3D"),
	Color("9A52E6"),
]

var _panel: PanelContainer
var _safe_margin: MarginContainer
var _root_col: VBoxContainer
var _box: VBoxContainer
var _top_box: VBoxContainer
var _mid_area: VBoxContainer
var _mid_host: VBoxContainer
var _title: Control
var _moves_capsule: PanelContainer
var _moves_label: Label
var _bars_title: Label
var _bars_box: VBoxContainer
var _stars_row: HBoxContainer
var _star_labels: Array[Label] = []
var _score_capsule: PanelContainer
var _score_label: Label
var _score_hint_panel: PanelContainer
var _score_hint: Label
var _hints_badge: Control
var _hints_label: Label
var _hints_count_label: Label
var _fx_layer: Control
var _buttons_box: VBoxContainer
var _next_button: Button
var _sunburst: Control
var _tween: Tween
var _title_flyer: Control
var _confetti_seed: int = 1
var _layout_scale: float = 1.0

var _anim_star: Label
var _score_target: float = 0.0
var _hint_flyer: Control
var _pending_hint_count: int = 0
var _hint_reward: int = 0
var _first_perfect: bool = false
var _streak_reward: bool = false
var _hint_reveal_left: int = 0
var _level_id: int = 1
var _earned_stars: int = 0
var _presenting: bool = false
var _skip_mode: bool = false
var _retry_button: Button
var _menu_button: Button
var _pending_color_stats: Array = []
var _star_fill_progress: float = 0.0
var _color_seq_id: int = 0
var _flying_star: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_shell()


func present(
	moves: int,
	stars: int,
	color_stats: Array,
	has_next: bool,
	level_id: int = 1,
	hint_reward: int = 0,
	reward_meta: Dictionary = {}
) -> void:
	_kill_tween()
	_presenting = true
	_skip_mode = false
	visible = true
	_level_id = maxi(1, level_id)
	_earned_stars = clampi(stars, 0, 3)
	_hint_reward = maxi(0, hint_reward)
	_first_perfect = bool(reward_meta.get("first_perfect", false))
	_streak_reward = bool(reward_meta.get("streak_reward", false))
	_hint_reveal_left = _hint_reward
	_set_skip_layout(false)
	_rebuild_title_text(_completed_title_text())
	_moves_label.text = "Movimientos: %d" % moves
	_moves_label.modulate = Color(1, 1, 1, 1)
	if _moves_capsule != null:
		_moves_capsule.modulate = Color(1, 1, 1, 0)
	_title.visible = false
	_title.modulate = Color(1, 1, 1, 0)
	_title.scale = Vector2.ZERO
	_reset_star_labels()
	_star_fill_progress = 0.0
	_stars_row.modulate = Color(1, 1, 1, 0)
	_stars_row.visible = true
	_score_label.text = "Puntuación: 0"
	_score_label.modulate = Color(1, 1, 1, 0)
	if _score_capsule != null:
		_score_capsule.modulate = Color(1, 1, 1, 0)
	_score_hint.text = ""
	if _score_hint_panel != null:
		_score_hint_panel.modulate = Color(1, 1, 1, 0)
		_score_hint_panel.visible = false
	# La pista ya está guardada; durante la animación mostramos el total anterior.
	_pending_hint_count = maxi(0, SaveManager.get_hints() - _hint_reward)
	_set_hint_count_display(float(_pending_hint_count))
	if _hints_badge != null:
		_hints_badge.modulate = Color(1, 1, 1, 0)
		_hints_badge.scale = Vector2.ONE
	if _bars_title != null:
		_bars_title.visible = false
	if _bars_box != null:
		_bars_box.visible = false
		_bars_box.custom_minimum_size = Vector2.ZERO
	_buttons_box.modulate = Color(1, 1, 1, 0)
	_buttons_box.visible = true
	_next_button.visible = has_next
	_next_button.text = "SIGUIENTE"
	_set_buttons_disabled(true)
	_clear_fx_layer()
	_clear_flying_star()

	_pending_color_stats = color_stats.duplicate(true)
	_clear_bars_box()
	_confetti_seed = maxi(1, _level_id * 9176 + moves * 13 + stars)
	if _sunburst != null:
		_sunburst.queue_redraw()
	modulate = Color(1, 1, 1, 1)
	_panel.scale = Vector2.ONE
	call_deferred("_begin_presentation", _earned_stars)


func _build_shell() -> void:
	_sunburst = Control.new()
	_sunburst.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sunburst.mouse_filter = Control.MOUSE_FILTER_STOP
	_sunburst.draw.connect(_on_sunburst_draw)
	_sunburst.resized.connect(_sunburst.queue_redraw)
	add_child(_sunburst)

	_safe_margin = MarginContainer.new()
	_safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_safe_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_safe_margin)

	_panel = UIFactory.make_panel()
	var panel_style := StyleBoxFlat.new()
	# Transparente: el fondo y confeti los pinta _sunburst.
	panel_style.bg_color = Color(0, 0, 0, 0)
	panel_style.border_width_left = 0
	panel_style.border_width_top = 0
	panel_style.border_width_right = 0
	panel_style.border_width_bottom = 0
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	panel_style.shadow_size = 0
	_panel.add_theme_stylebox_override("panel", panel_style)
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_safe_margin.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(margin)

	# Columna a pantalla completa (sin scroll): título arriba, contenido al centro, botones abajo.
	_root_col = VBoxContainer.new()
	_root_col.add_theme_constant_override("separation", 10)
	_root_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_root_col)

	_top_box = VBoxContainer.new()
	_top_box.add_theme_constant_override("separation", 10)
	_top_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_root_col.add_child(_top_box)

	_title = _make_victory_title(TITLE_FONT_SIZE)
	_title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_top_box.add_child(_title)

	_moves_capsule = PanelContainer.new()
	_moves_capsule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_moves_capsule()
	_top_box.add_child(_moves_capsule)

	_moves_label = UIFactory.make_subtitle("Movimientos: 0", 32)
	UIFactory.apply_font(_moves_label, true)
	_moves_label.add_theme_color_override("font_color", Color("FFFFFF"))
	_moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_moves_capsule.add_child(_moves_label)

	_mid_area = VBoxContainer.new()
	_mid_area.add_theme_constant_override("separation", 0)
	_mid_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mid_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mid_area.size_flags_stretch_ratio = 1.0
	_root_col.add_child(_mid_area)

	_mid_host = VBoxContainer.new()
	_mid_host.add_theme_constant_override("separation", 0)
	_mid_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mid_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mid_area.add_child(_mid_host)

	var mid_spacer_top := Control.new()
	mid_spacer_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_spacer_top.size_flags_stretch_ratio = 1.0
	mid_spacer_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mid_host.add_child(mid_spacer_top)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 16)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mid_host.add_child(_box)

	var mid_spacer_bottom := Control.new()
	mid_spacer_bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_spacer_bottom.size_flags_stretch_ratio = 1.0
	mid_spacer_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mid_host.add_child(mid_spacer_bottom)

	_bars_title = UIFactory.make_light_subtitle("", 22)
	_bars_title.visible = false
	_box.add_child(_bars_title)

	# Cuadro de racha: entre título/movimientos y las estrellas.
	_score_hint_panel = PanelContainer.new()
	_score_hint_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_score_hint_panel.visible = false
	_style_score_hint_panel(GamePalette.SUCCESS)
	_box.add_child(_score_hint_panel)

	_score_hint = UIFactory.make_subtitle("", 26)
	UIFactory.apply_font(_score_hint, true)
	_score_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_hint.add_theme_color_override("font_color", Color("145A28"))
	_score_hint_panel.add_child(_score_hint)

	# Destino de la puntuación: encima de la fila activa para no saltar al ocultarla.
	_stars_row = HBoxContainer.new()
	_stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_stars_row.add_theme_constant_override("separation", 16)
	_box.add_child(_stars_row)
	_star_labels.clear()
	for i in range(3):
		var wrap := MarginContainer.new()
		if i != 1:
			wrap.add_theme_constant_override("margin_top", 22)
		var star := Label.new()
		star.text = "☆"
		star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		star.custom_minimum_size = Vector2(132, 132)
		star.add_theme_font_size_override("font_size", 120)
		star.add_theme_color_override("font_color", Color("FFD84A"))
		star.add_theme_color_override("font_outline_color", Color("C47A00"))
		star.add_theme_constant_override("outline_size", 10)
		star.add_theme_color_override("font_shadow_color", Color(1.0, 0.85, 0.2, 0.55))
		star.add_theme_constant_override("shadow_offset_x", 0)
		star.add_theme_constant_override("shadow_offset_y", 0)
		star.add_theme_constant_override("shadow_outline_size", 16)
		star.modulate = Color(1, 1, 1, 0)
		UIFactory.apply_font(star, true)
		wrap.add_child(star)
		_stars_row.add_child(wrap)
		_star_labels.append(star)

	_bars_box = VBoxContainer.new()
	_bars_box.add_theme_constant_override("separation", 14)
	_bars_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bars_box.custom_minimum_size = Vector2(0, 52)
	_box.add_child(_bars_box)

	_score_capsule = PanelContainer.new()
	_score_capsule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_score_capsule()
	_box.add_child(_score_capsule)

	_score_label = UIFactory.make_title("Puntuación: 0", 36)
	_score_label.add_theme_color_override("font_color", Color("FFFFFF"))
	_score_capsule.add_child(_score_label)

	_hints_badge = Control.new()
	_hints_badge.custom_minimum_size = Vector2(260, 82)
	_hints_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hints_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints_badge.draw.connect(_on_hints_badge_draw)
	_box.add_child(_hints_badge)

	var hints_row := HBoxContainer.new()
	hints_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hints_row.offset_bottom = -HINTS_BADGE_DEPTH
	hints_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hints_row.add_theme_constant_override("separation", 6)
	hints_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints_badge.add_child(hints_row)

	_hints_label = Label.new()
	_hints_label.text = "Pistas:"
	_hints_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hints_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hints_label.add_theme_font_size_override("font_size", 28)
	_hints_label.add_theme_color_override("font_color", GamePalette.MENU_YELLOW_TEXT)
	_hints_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIFactory.apply_font(_hints_label, true)
	hints_row.add_child(_hints_label)

	_hints_count_label = Label.new()
	_hints_count_label.text = "0"
	_hints_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hints_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hints_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_hints_count_label(34)
	hints_row.add_child(_hints_count_label)

	_buttons_box = VBoxContainer.new()
	_buttons_box.add_theme_constant_override("separation", 16)
	_buttons_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons_box.size_flags_vertical = Control.SIZE_SHRINK_END
	_root_col.add_child(_buttons_box)

	# Mismo formato que el menú principal: mayúsculas, altura ~90, Comic Neue Bold 30.
	_retry_button = UIFactory.make_cyan_button("REINTENTAR", 90)
	UIFactory.set_button_icon(_retry_button, UIFactory.ButtonIcon.RESTART, Color.WHITE)
	_retry_button.pressed.connect(_emit_retry)
	_buttons_box.add_child(_retry_button)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons_box.add_child(nav)

	_menu_button = UIFactory.make_button("MENÚ", 90)
	UIFactory.set_button_colors(_menu_button, GamePalette.MENU_YELLOW, GamePalette.MENU_YELLOW_TEXT)
	UIFactory.set_button_icon(_menu_button, UIFactory.ButtonIcon.HOME, GamePalette.MENU_YELLOW_TEXT)
	_menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_button.pressed.connect(_emit_menu)
	nav.add_child(_menu_button)

	_next_button = UIFactory.make_button("SIGUIENTE", 90)
	UIFactory.set_button_colors(_next_button, Color("FF1A3C"), Color.WHITE)
	UIFactory.set_button_icon(_next_button, UIFactory.ButtonIcon.PLAY, Color.WHITE)
	_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_button.pressed.connect(_emit_next)
	nav.add_child(_next_button)

	_fx_layer = Control.new()
	_fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.z_index = 80
	_fx_layer.z_as_relative = false
	clip_contents = false
	add_child(_fx_layer)

	resized.connect(_fit_panel)
	_apply_safe_margins()
	call_deferred("_fit_panel")


func _apply_safe_margins() -> void:
	if _safe_margin == null:
		return
	var insets := _compute_safe_insets()
	_safe_margin.add_theme_constant_override("margin_left", insets.x)
	_safe_margin.add_theme_constant_override("margin_top", insets.y)
	_safe_margin.add_theme_constant_override("margin_right", insets.z)
	_safe_margin.add_theme_constant_override("margin_bottom", insets.w)


## Insets en píxeles de viewport: notch / status bar arriba y barra de navegación abajo.
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

	var left := SAFE_PAD_H
	var top := SAFE_PAD_TOP
	var right := SAFE_PAD_H
	var bottom := SAFE_PAD_BOTTOM

	var platform := OS.get_name()
	if platform == "Android" or platform == "iOS":
		var safe := DisplayServer.get_display_safe_area()
		if window_size.x > 0 and window_size.y > 0 and safe.size.x > 0 and safe.size.y > 0:
			left = maxi(SAFE_PAD_H, int(round(float(safe.position.x) * scale_factor)))
			top = maxi(SAFE_PAD_TOP, int(round(float(safe.position.y) * scale_factor)))
			right = maxi(
				SAFE_PAD_H,
				int(round(float(window_size.x - (safe.position.x + safe.size.x)) * scale_factor))
			)
			bottom = maxi(
				SAFE_PAD_BOTTOM,
				int(round(float(window_size.y - (safe.position.y + safe.size.y)) * scale_factor))
			)

	return Vector4i(left, top, right, bottom)


func _fit_panel() -> void:
	if _panel == null or _box == null:
		return
	_apply_safe_margins()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.pivot_offset = _panel.size * 0.5
	_fit_content_to_screen()


## Escala tipografías y tamaños para que título + contenido + botones entren sin scroll.
func _fit_content_to_screen() -> void:
	if _root_col == null or _box == null or _buttons_box == null:
		return
	if _mid_host != null:
		_mid_host.custom_minimum_size = Vector2.ZERO
	var avail_h := _root_col.size.y
	if avail_h < 8.0:
		avail_h = size.y
	if avail_h < 8.0:
		return

	# Medimos con escala 1 y luego comprimimos si hace falta.
	_apply_layout_scale(1.0)
	var top_h := _top_box.get_combined_minimum_size().y if _top_box != null else 0.0
	var mid_h := _box.get_combined_minimum_size().y
	var btn_h := _buttons_box.get_combined_minimum_size().y
	var sep := float(_root_col.get_theme_constant("separation"))
	var needed := top_h + mid_h + btn_h + sep * 2.0 + 8.0
	var fit_scale := 1.0
	if needed > avail_h and needed > 1.0:
		fit_scale = clampf(avail_h / needed, 0.62, 1.0)
	_layout_scale = fit_scale
	_apply_layout_scale(fit_scale)


func _apply_layout_scale(factor: float) -> void:
	var s := clampf(factor, 0.55, 1.0)
	var root_sep := maxi(4, int(round(10.0 * s)))
	var top_sep := maxi(4, int(round(10.0 * s)))
	var box_sep := maxi(6, int(round(16.0 * s)))
	var btn_sep := maxi(6, int(round(14.0 * s)))
	if _root_col != null:
		_root_col.add_theme_constant_override("separation", root_sep)
	if _top_box != null:
		_top_box.add_theme_constant_override("separation", top_sep)
	if _box != null:
		_box.add_theme_constant_override("separation", box_sep)
	if _buttons_box != null:
		_buttons_box.add_theme_constant_override("separation", btn_sep)

	var title_size := maxi(44, int(round(float(TITLE_FONT_SIZE) * s)))
	if _title != null and is_instance_valid(_title):
		_restyle_title_letters(_title, title_size)

	if _moves_label != null:
		_moves_label.add_theme_font_size_override("font_size", maxi(22, int(round(32.0 * s))))

	if _bars_title != null:
		_bars_title.add_theme_font_size_override("font_size", maxi(14, int(round(22.0 * s))))

	var star_box := maxf(96.0, 132.0 * s)
	var star_font := maxi(86, int(round(120.0 * s)))
	for star in _star_labels:
		if not is_instance_valid(star):
			continue
		star.custom_minimum_size = Vector2(star_box, star_box)
		star.add_theme_font_size_override("font_size", star_font)
		star.pivot_offset = Vector2(star_box, star_box) * 0.5

	if _score_label != null:
		_score_label.add_theme_font_size_override("font_size", maxi(22, int(round(36.0 * s))))
	if _score_hint != null:
		_score_hint.add_theme_font_size_override("font_size", maxi(14, int(round(22.0 * s))))

	if _hints_badge != null:
		_hints_badge.custom_minimum_size = Vector2(maxf(200.0, 260.0 * s), maxf(56.0, 82.0 * s))
		_hints_badge.queue_redraw()
		var hints_row := _hints_badge.get_child(0) as Control
		if hints_row != null:
			hints_row.offset_bottom = -HINTS_BADGE_DEPTH * s
	if _hints_label != null:
		_hints_label.add_theme_font_size_override("font_size", maxi(18, int(round(28.0 * s))))
	if _hints_count_label != null:
		_style_hints_count_label(maxi(22, int(round(34.0 * s))))

	var btn_h := maxi(84, int(round(90.0 * s)))
	for btn in [_retry_button, _menu_button, _next_button]:
		if btn != null and is_instance_valid(btn):
			btn.custom_minimum_size.y = btn_h
			btn.add_theme_font_size_override("font_size", 30)
			UIFactory.apply_font(btn, true)

	if _bars_box != null and _bars_box.visible:
		_bars_box.custom_minimum_size = Vector2(0, maxf(56.0, 72.0 * s))


func _restyle_title_letters(title: Control, font_size: int) -> void:
	if title == null or not is_instance_valid(title):
		return
	for child in title.get_children():
		if child is HBoxContainer:
			_restyle_title_letters(child as Control, font_size)
			continue
		var label := child as Label
		if label == null:
			if child is Control:
				(child as Control).custom_minimum_size = Vector2(
					maxf(10.0, float(font_size) * 0.28), float(font_size)
				)
			continue
		label.add_theme_font_size_override("font_size", font_size)


func _emit_next() -> void:
	next_pressed.emit()


func _emit_retry() -> void:
	retry_pressed.emit()


func _emit_menu() -> void:
	menu_pressed.emit()


func _clear_bars_box() -> void:
	if _bars_box == null:
		return
	for child in _bars_box.get_children():
		child.queue_free()


func _clear_flying_star() -> void:
	if is_instance_valid(_flying_star):
		_flying_star.queue_free()
	_flying_star = null


func _make_color_row(color_name: String, connections: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.set_meta("color_name", color_name)
	row.set_meta("connections", connections)

	if BoardTheme.uses_emoji(_level_id):
		var emoji_swatch := Label.new()
		emoji_swatch.text = BoardTheme.emoji_for(color_name)
		emoji_swatch.custom_minimum_size = Vector2(72, 72)
		emoji_swatch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_swatch.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emoji_swatch.add_theme_font_size_override("font_size", 52)
		row.add_child(emoji_swatch)
	else:
		var swatch := Control.new()
		swatch.custom_minimum_size = Vector2(72, 72)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.draw.connect(_draw_color_swatch.bind(swatch, color_name))
		row.add_child(swatch)

	var star := Label.new()
	star.text = "★"
	star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	star.custom_minimum_size = Vector2(48, 48)
	star.add_theme_font_size_override("font_size", 40)
	star.add_theme_color_override("font_color", Color("FFD84A"))
	star.modulate = Color(1, 1, 1, 0)
	star.scale = Vector2(0.2, 0.2)
	star.pivot_offset = Vector2(24, 24)
	UIFactory.apply_font(star, true)
	row.add_child(star)
	row.set_meta("star", star)

	return row


func _reset_star_labels() -> void:
	for i in range(_star_labels.size()):
		var star := _star_labels[i]
		star.text = "☆"
		star.modulate = Color(1, 1, 1, 0)
		star.scale = Vector2.ONE
		star.pivot_offset = star.custom_minimum_size * 0.5


func _begin_presentation(stars: int) -> void:
	if not is_inside_tree():
		return
	_fit_panel()
	_panel.pivot_offset = _panel.size * 0.5
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_fit_panel()
	_play_title_rise_then_continue(stars)


func _play_title_rise_then_continue(stars: int) -> void:
	if not is_inside_tree() or _fx_layer == null or _title == null:
		_continue_after_title(stars)
		return

	# El título definitivo queda oculto arriba; solo anima el flyer en el centro.
	_title.visible = false
	_title.modulate = Color(1, 1, 1, 0)
	_title.scale = Vector2.ZERO

	if is_instance_valid(_title_flyer):
		_title_flyer.queue_free()
		_title_flyer = null

	var title_text := _completed_title_text()
	if _title != null and _title.has_meta("title_text"):
		title_text = str(_title.get_meta("title_text"))
	var flyer := _make_victory_title(TITLE_FLYER_FONT_SIZE, title_text)
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flyer.z_index = 40
	flyer.top_level = true
	# Invisible hasta medir y centrar (sin tamaño forzado que recorte el texto).
	flyer.visible = false
	flyer.scale = Vector2.ONE
	flyer.modulate = Color(1, 1, 1, 0)
	_fx_layer.add_child(flyer)
	_title_flyer = flyer

	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(flyer) or not is_instance_valid(_title):
		_continue_after_title(stars)
		return

	_center_title_flyer(flyer)
	flyer.scale = Vector2.ZERO
	flyer.modulate = Color(1, 1, 1, 1)
	flyer.visible = true

	var center := _overlay_center_global()
	_spawn_soft_bubble(center, GamePalette.ACCENT, 1.15)

	_kill_tween()
	_tween = create_tween()
	# 1) Infla SOLO en el centro: 0 → un poco más grande → tamaño normal.
	_tween.tween_property(flyer, "scale", Vector2(1.16, 1.16), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(flyer, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(0.45)
	# 2) Se deshincha a 0 en el centro.
	_tween.tween_property(flyer, "scale", Vector2.ZERO, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# 3) Recién entonces aparece arriba con el mismo inflado.
	_tween.tween_callback(_settle_title_from_flyer.bind(stars))


func _overlay_center_global() -> Vector2:
	return get_global_rect().get_center()


func _center_title_flyer(flyer: Control) -> void:
	if flyer == null or not is_instance_valid(flyer):
		return
	flyer.reset_size()
	var flyer_size := flyer.get_combined_minimum_size()
	if flyer_size.x < 8.0 or flyer_size.y < 8.0:
		flyer_size = Vector2(520, 180)
	flyer.size = flyer_size
	flyer.pivot_offset = flyer_size * 0.5
	_place_control_center(flyer, _overlay_center_global())


func _place_control_center(control: Control, center_global: Vector2) -> void:
	if control == null:
		return
	var pivot := control.pivot_offset
	if pivot.length_squared() < 1.0:
		var sz := control.size
		if sz.x < 4.0 or sz.y < 4.0:
			sz = control.get_combined_minimum_size()
		pivot = sz * 0.5
		control.pivot_offset = pivot
	control.global_position = center_global - pivot


func _settle_title_from_flyer(stars: int) -> void:
	if is_instance_valid(_title_flyer):
		_title_flyer.queue_free()
		_title_flyer = null
	if is_instance_valid(_title):
		# Aparece arriba solo ahora (nunca antes del centro).
		var title_size := _title.size
		if title_size.x < 4.0 or title_size.y < 4.0:
			title_size = _title.get_combined_minimum_size()
		_title.pivot_offset = title_size * 0.5
		_title.scale = Vector2.ZERO
		_title.modulate = Color(1, 1, 1, 1)
		_title.visible = true
		var settle := create_tween()
		settle.tween_property(_title, "scale", Vector2(1.16, 1.16), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		settle.tween_property(_title, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if not _skip_mode and is_instance_valid(_moves_capsule):
		var moves_tw := create_tween()
		moves_tw.tween_property(_moves_capsule, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _skip_mode:
		_finish_skip_title_presentation()
		return
	_continue_after_title(stars)


func _completed_title_text() -> String:
	return "NIVEL %d\nCOMPLETADO" % maxi(1, _level_id)


func _resolved_title_text() -> String:
	return "NIVEL %d\nRESUELTO" % maxi(1, _level_id)


func _make_victory_title(font_size: int, text: String = "") -> Control:
	if text.is_empty():
		text = _completed_title_text()
	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", maxi(-10, int(round(float(font_size) * -0.18))))
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.set_meta("title_text", text)

	var lines := text.replace("¡", "").replace("!", "").strip_edges().split("\n")
	if lines.size() == 1 and " " in lines[0]:
		# Compat: "NIVEL COMPLETADO" → dos líneas.
		lines = lines[0].split(" ", false, 1)

	var color_i := 0
	for line_text in lines:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", -3)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		for i in range(line_text.length()):
			var ch := line_text[i]
			if ch == " ":
				var space := Control.new()
				space.custom_minimum_size = Vector2(maxf(14.0, float(font_size) * 0.28), float(font_size))
				space.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(space)
				continue
			row.add_child(_make_title_letter(ch, color_i % TITLE_LETTER_COLORS.size(), font_size))
			color_i += 1
		root.add_child(row)
	return root


func _rebuild_title_text(text: String) -> void:
	if _top_box == null:
		return
	var idx := _title.get_index() if _title != null else 0
	if _title != null:
		_title.queue_free()
	var title_size := maxi(44, int(round(float(TITLE_FONT_SIZE) * _layout_scale)))
	_title = _make_victory_title(title_size, text)
	_title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_top_box.add_child(_title)
	_top_box.move_child(_title, idx)


func _set_skip_layout(skip: bool) -> void:
	_skip_mode = skip
	if _moves_capsule != null:
		_moves_capsule.visible = not skip
	elif _moves_label != null:
		_moves_label.visible = not skip
	if _bars_title != null:
		_bars_title.visible = false
	if _bars_box != null:
		_bars_box.visible = false
	if _stars_row != null:
		_stars_row.visible = not skip
	if _score_capsule != null:
		_score_capsule.visible = not skip
	if _score_hint_panel != null:
		_score_hint_panel.visible = not skip
	if _hints_badge != null:
		_hints_badge.visible = not skip
	if _retry_button != null:
		_retry_button.visible = not skip
	if _menu_button != null:
		_menu_button.visible = not skip


## Overlay tras canjear pistas: solo título + continuar (sin score ni recompensas).
func present_skip_continue(has_next: bool, spent_hints: int = 0) -> void:
	_kill_tween()
	_presenting = true
	_skip_mode = true
	_hint_reward = 0
	_earned_stars = 0
	visible = true
	_set_skip_layout(true)
	_rebuild_title_text(_resolved_title_text())
	_title.visible = false
	_title.modulate = Color(1, 1, 1, 0)
	_score_hint.text = "Gastaste %d pistas para pasar" % maxi(0, spent_hints)
	_style_score_hint_panel(GamePalette.BUTTON)
	if _score_hint_panel != null:
		_score_hint_panel.visible = true
		_score_hint_panel.modulate = Color(1, 1, 1, 0)
	_buttons_box.modulate = Color(1, 1, 1, 0)
	_buttons_box.visible = true
	_next_button.visible = has_next
	_next_button.text = "CONTINUAR"
	_set_buttons_disabled(true)
	_clear_fx_layer()
	modulate = Color(1, 1, 1, 1)
	_panel.scale = Vector2.ONE
	call_deferred("_begin_skip_presentation", spent_hints)


func _begin_skip_presentation(spent_hints: int) -> void:
	if not is_inside_tree():
		return
	_fit_panel()
	_pending_hint_count = spent_hints
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_fit_panel()
	# Reutiliza la subida del título; stars=-1 indica modo skip.
	_play_title_rise_then_continue(-1)


func _finish_skip_title_presentation() -> void:
	if not _skip_mode:
		return
	if _score_hint_panel != null:
		_score_hint.text = "Gastaste %d pistas · Sin estrellas ni recompensas" % maxi(0, _pending_hint_count)
		_score_hint_panel.visible = true
		var tw := create_tween()
		tw.tween_property(_score_hint_panel, "modulate:a", 1.0, 0.28)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_interval(0.12)
	_tween.tween_property(_buttons_box, "modulate:a", 1.0, 0.28)
	_tween.tween_callback(_finish_presentation)


func _make_title_letter(letter: String, color_index: int, font_size: int) -> Label:
	var label := Label.new()
	label.text = letter
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	UIFactory.apply_title_font(label)
	var color: Color = TITLE_LETTER_COLORS[color_index]
	label.add_theme_color_override("font_color", color.lightened(0.12))
	label.add_theme_color_override("font_outline_color", Color("1A1F6E"))
	label.add_theme_constant_override("outline_size", 14)
	label.add_theme_color_override("font_shadow_color", Color(0.08, 0.16, 0.45, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 5)
	label.add_theme_constant_override("shadow_outline_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _continue_after_title(stars: int) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_callback(_prepare_score_stars_for_harvest)
	_tween.tween_property(_stars_row, "modulate:a", 1.0, 0.22)
	_tween.tween_callback(_animate_bars_then_score.bind(stars))


func _prepare_score_stars_for_harvest() -> void:
	_star_fill_progress = float(_earned_stars)
	_stars_row.visible = true
	_stars_row.modulate = Color(1, 1, 1, 1)
	for i in range(_star_labels.size()):
		var star := _star_labels[i]
		star.text = "☆"
		star.modulate = Color(1, 1, 1, 0)
		star.scale = Vector2.ONE
		star.pivot_offset = star.custom_minimum_size * 0.5


func _animate_bars_then_score(stars: int) -> void:
	_run_stars_then_score(stars)


func _run_stars_then_score(stars: int) -> void:
	_color_seq_id += 1
	var seq := _color_seq_id
	_hide_color_row_slot()
	var earned := clampi(_earned_stars if stars < 0 else stars, 0, 3)
	await _reveal_stars_one_by_one(earned, seq)
	if seq != _color_seq_id or not is_inside_tree() or not _presenting:
		return
	_reveal_score(earned)


func _reveal_stars_one_by_one(earned: int, seq: int) -> void:
	const STEP_PAUSE := 0.38
	for i in range(_star_labels.size()):
		if seq != _color_seq_id or not is_inside_tree() or not _presenting:
			return
		var star := _star_labels[i]
		var filled := i < earned
		star.pivot_offset = star.custom_minimum_size * 0.5
		star.text = "★" if filled else "☆"
		if filled:
			star.modulate = Color(1, 1, 1, 0)
			star.scale = Vector2(0.35, 0.35)
			var tw := create_tween()
			tw.tween_property(star, "modulate:a", 1.0, 0.14)
			tw.parallel().tween_property(star, "scale", Vector2(1.22, 1.22), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(star, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			AudioManager.play(AudioManager.Sfx.SELECT)
		else:
			star.modulate = Color(1, 1, 1, 0)
			star.scale = Vector2.ONE
			var tw := create_tween()
			tw.tween_property(star, "modulate:a", 0.42, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(STEP_PAUSE).timeout
	_star_fill_progress = float(earned)


func _hide_color_row_slot() -> void:
	_clear_bars_box()
	if _bars_title != null:
		_bars_title.visible = false
	if _bars_box != null:
		_bars_box.visible = false
		_bars_box.custom_minimum_size = Vector2.ZERO
	_fit_panel()


func _play_one_color_cycle(entry: Dictionary, total_colors: int, seq: int) -> void:
	_clear_bars_box()
	await get_tree().process_frame
	if seq != _color_seq_id or not is_inside_tree():
		return

	var color_name := str(entry.get("color", ""))
	var connections := int(entry.get("connections", 0))
	var row := _make_color_row(color_name, connections)
	row.modulate = Color(1, 1, 1, 0)
	_bars_box.add_child(row)
	await get_tree().process_frame
	await get_tree().process_frame
	if seq != _color_seq_id or not is_instance_valid(row):
		return

	_reveal_color_row(row, color_name)
	await get_tree().create_timer(0.05).timeout
	if seq != _color_seq_id or not is_instance_valid(row):
		return

	var star: Label = row.get_meta("star")
	_pop_row_star(star)
	await get_tree().create_timer(0.08).timeout
	if seq != _color_seq_id or not is_instance_valid(row):
		return

	await _fly_row_star_to_score(row, total_colors, seq)


func _reveal_color_row(row: Control, color_name: String) -> void:
	if row == null or not is_instance_valid(row):
		return
	row.modulate = Color(1, 1, 1, 0)
	var center := row.global_position + row.size * Vector2(0.5, 0.5)
	if row.get_child_count() > 0:
		var swatch := row.get_child(0) as Control
		if swatch != null:
			center = swatch.global_position + swatch.size * 0.5
	_spawn_soft_bubble(center, GamePalette.get_color(color_name), 1.15)
	AudioManager.play(AudioManager.Sfx.CONNECT)
	var tw := create_tween()
	tw.tween_property(row, "modulate:a", 1.0, 0.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _pop_row_star(star: Label) -> void:
	_anim_star = star
	if is_instance_valid(_anim_star):
		var center := _anim_star.global_position + _anim_star.size * 0.5
		_spawn_soft_bubble(center, GamePalette.WARNING, 0.85)
	_explode_star(_anim_star)
	AudioManager.play(AudioManager.Sfx.CONNECT)


func _fly_row_star_to_score(row: Control, total_colors: int, seq: int) -> void:
	if row == null or not is_instance_valid(row) or _fx_layer == null:
		return
	var row_star: Label = row.get_meta("star")
	if row_star == null or not is_instance_valid(row_star):
		row.queue_free()
		return

	var start_center := row_star.global_position + row_star.size * 0.5
	_clear_flying_star()
	var flyer := _make_flying_score_star()
	_fx_layer.add_child(flyer)
	_flying_star = flyer
	flyer.reset_size()
	var flyer_size := flyer.get_combined_minimum_size()
	if flyer_size.x < 8.0:
		flyer_size = Vector2(88, 88)
	flyer.size = flyer_size
	flyer.pivot_offset = flyer_size * 0.5
	_place_control_center(flyer, start_center)
	flyer.scale = Vector2.ONE
	row_star.visible = false

	# Borra la fila mientras la estrella va al centro.
	var mid_center := Vector2(size.x * 0.5, start_center.y)
	var clear_tw := create_tween()
	for child in row.get_children():
		if child != row_star and child is CanvasItem:
			clear_tw.parallel().tween_property(child, "modulate:a", 0.0, 0.1)
	clear_tw.parallel().tween_property(flyer, "global_position", mid_center - flyer.pivot_offset, 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	clear_tw.parallel().tween_property(flyer, "scale", Vector2(1.85, 1.85), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await clear_tw.finished
	if seq != _color_seq_id:
		_clear_flying_star()
		return

	row.modulate = Color(1, 1, 1, 0)

	var contrib := float(_earned_stars) / float(maxi(total_colors, 1))
	var end_progress := clampf(_star_fill_progress + contrib, 0.0, 3.0)
	var slot := _star_slot_for_fill_end(end_progress)
	var target_star := _star_labels[slot] if slot >= 0 and slot < _star_labels.size() else null
	var end_center := mid_center
	if target_star != null and is_instance_valid(target_star):
		end_center = target_star.global_position + target_star.size * 0.5

	var fly_tw := create_tween()
	fly_tw.tween_property(flyer, "global_position", end_center - flyer.pivot_offset, 0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly_tw.parallel().tween_property(flyer, "scale", Vector2(1.05, 1.05), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fly_tw.finished
	if seq != _color_seq_id:
		_clear_flying_star()
		return

	_spawn_soft_bubble(end_center, GamePalette.WARNING, 0.75)
	_clear_flying_star()
	_apply_star_fill(end_progress, slot, true)
	AudioManager.play(AudioManager.Sfx.SELECT)

	if is_instance_valid(row):
		row.queue_free()
	await get_tree().process_frame


func _make_flying_score_star() -> Label:
	var star := Label.new()
	star.text = "★"
	star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	star.custom_minimum_size = Vector2(88, 88)
	star.add_theme_font_size_override("font_size", 78)
	star.add_theme_color_override("font_color", Color("FFD84A"))
	star.add_theme_color_override("font_outline_color", Color("C47A00"))
	star.add_theme_constant_override("outline_size", 8)
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.z_index = 50
	UIFactory.apply_font(star, true)
	return star


func _star_slot_for_fill_end(end_progress: float) -> int:
	if end_progress <= 0.001:
		return 0
	return clampi(int(floor(end_progress - 0.0001)), 0, 2)


func _apply_star_fill(progress: float, pop_slot: int = -1, animate_pop: bool = false) -> void:
	var prev_progress := _star_fill_progress
	_star_fill_progress = clampf(progress, 0.0, 3.0)
	for i in range(_star_labels.size()):
		var star := _star_labels[i]
		var prev_amount := clampf(prev_progress - float(i), 0.0, 1.0)
		var amount := clampf(_star_fill_progress - float(i), 0.0, 1.0)
		star.pivot_offset = star.custom_minimum_size * 0.5
		if amount <= 0.001:
			star.text = "☆"
			star.modulate = Color(1, 1, 1, 0.4)
			star.scale = Vector2.ONE
		elif amount >= 0.999:
			star.text = "★"
			star.modulate = Color(1, 1, 1, 1)
			star.scale = Vector2.ONE
		else:
			star.text = "★"
			star.modulate = Color(1, 1, 1, lerpf(0.55, 1.0, amount))
			star.scale = Vector2.ONE * lerpf(0.55, 1.0, amount)
		var should_pop := animate_pop and amount > prev_amount + 0.001
		if should_pop and (pop_slot < 0 or i == pop_slot or amount >= 0.999):
			var settle := Vector2.ONE if amount >= 0.999 else star.scale
			var peak := Vector2(1.35, 1.35) if amount >= 0.999 else settle * 1.25
			star.scale = settle * 0.7
			var pop := create_tween()
			pop.tween_property(star, "scale", peak, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pop.tween_property(star, "scale", settle, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _inflate_score_star(index: int) -> void:
	if index < 0 or index >= _star_labels.size():
		return
	var star := _star_labels[index]
	var filled := index < _earned_stars
	star.text = "★" if filled else "☆"
	star.modulate = Color(1, 1, 1, 1) if filled else Color(1, 1, 1, 0.45)
	star.scale = Vector2(0.2, 0.2)
	star.pivot_offset = star.size * 0.5
	if star.pivot_offset.length_squared() < 1.0:
		star.pivot_offset = star.custom_minimum_size * 0.5
	AudioManager.play(AudioManager.Sfx.SELECT)
	var pop := create_tween()
	pop.tween_property(star, "scale", Vector2(2.4, 2.4), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(star, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


func _explode_star(star: Label) -> void:
	if star == null:
		return
	star.modulate = Color(1, 1, 1, 1)
	star.scale = Vector2(0.15, 0.15)
	star.pivot_offset = star.size * 0.5
	var pop := create_tween()
	pop.tween_property(star, "scale", Vector2(1.7, 1.7), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.parallel().tween_property(star, "modulate", Color(1.2, 1.15, 0.7, 1.0), 0.08)
	pop.tween_property(star, "scale", Vector2.ONE, 0.08)
	pop.parallel().tween_property(star, "modulate", Color.WHITE, 0.08)


func _reveal_score(stars: int) -> void:
	_kill_tween()
	# Estrellas ya mostradas una a una; sincronizar estado sin reanimar.
	_apply_star_fill(float(clampi(stars, 0, 3)), -1, false)
	if _stars_row != null:
		_stars_row.visible = true
		_stars_row.modulate = Color(1, 1, 1, 1)
	_fit_panel()

	var score := score_for_stars(stars)
	_score_target = float(score)
	# Animamos el +N de pistas ganadas en esta victoria (si hay).
	var animate_hints := stars >= 3 and _hint_reward > 0
	if animate_hints:
		_hint_reveal_left = _hint_reward
		_pending_hint_count = maxi(0, SaveManager.get_hints() - _hint_reward)
	else:
		_hint_reveal_left = 0
		_pending_hint_count = SaveManager.get_hints()
	_set_hint_count_display(float(_pending_hint_count))
	if _score_hint_panel != null:
		_score_hint_panel.visible = false

	_tween = create_tween()
	_tween.tween_interval(0.08)
	_tween.tween_callback(_show_score_block)
	_tween.tween_callback(_fit_panel)
	_tween.tween_method(_on_score_tween, 0.0, _score_target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if animate_hints:
		# Tras 1000: (mensaje de racha si aplica) + badge + "+N" al lado → baja a pistas.
		_tween.tween_interval(0.12)
		_tween.tween_callback(_prepare_hint_reward_ui)
		_tween.tween_interval(0.25)
		_tween.tween_callback(_start_plus_one_to_hints_animation)
	else:
		_set_hint_count_display(float(SaveManager.get_hints()))
		_tween.tween_callback(_show_hints_badge)
		_tween.tween_property(_buttons_box, "modulate:a", 1.0, 0.28)
		_tween.tween_callback(_finish_presentation)


func _show_score_block() -> void:
	if _score_capsule != null:
		_score_capsule.modulate = Color(1, 1, 1, 1)
	_score_label.modulate = Color(1, 1, 1, 1)
	_fit_panel()


func _show_score_hint(hint: String, stars: int) -> void:
	_score_hint.text = hint
	_style_score_hint_panel(_score_hint_color_for_stars(stars))
	if _score_hint_panel != null:
		_score_hint_panel.visible = not hint.is_empty()
		_score_hint_panel.modulate = Color(1, 1, 1, 0)
		if not hint.is_empty():
			var tw := create_tween()
			tw.tween_property(_score_hint_panel, "modulate:a", 1.0, 0.22)
	_fit_panel()


func _prepare_hint_reward_ui() -> void:
	# Solo el mensaje de racha; el primer 3★ no muestra texto extra.
	if _streak_reward:
		_show_score_hint("Racha de 3 aciertos seguidos", 3)
	elif _score_hint_panel != null:
		_score_hint_panel.visible = false
	_set_hint_count_display(float(maxi(0, SaveManager.get_hints() - _hint_reward)))
	_show_hints_badge()


func _show_hints_badge() -> void:
	if _hints_badge == null:
		return
	_hints_badge.modulate = Color(1, 1, 1, 0)
	_hints_badge.queue_redraw()
	var tw := create_tween()
	tw.tween_property(_hints_badge, "modulate:a", 1.0, 0.22)
	_fit_panel()


func _finish_presentation() -> void:
	_presenting = false
	_enable_buttons()


func _spawn_soft_bubble(center_global: Vector2, color: Color, strength: float = 1.0) -> void:
	if _fx_layer == null or not is_inside_tree():
		return
	var local_center := center_global - _fx_layer.global_position
	var base := 40.0 * strength
	var bubble := Control.new()
	bubble.size = Vector2(base, base)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.pivot_offset = bubble.size * 0.5
	bubble.set_meta("bubble_color", Color(color.r, color.g, color.b, 0.65))
	bubble.draw.connect(_draw_fx_bubble.bind(bubble))
	_fx_layer.add_child(bubble)
	bubble.position = local_center - bubble.size * 0.5
	bubble.scale = Vector2(0.15, 0.15)
	var tw := create_tween()
	tw.tween_property(bubble, "scale", Vector2(2.4, 2.4) * strength, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(bubble, "modulate:a", 0.0, 0.32)
	tw.tween_callback(bubble.queue_free)

	if SettingsManager.fx_enabled:
		for i in range(6):
			var spark := ColorRect.new()
			spark.color = Color(color.r, color.g, color.b, 0.9)
			spark.size = Vector2(8, 8)
			spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			spark.pivot_offset = spark.size * 0.5
			_fx_layer.add_child(spark)
			spark.position = local_center - spark.size * 0.5
			var angle := TAU * float(i) / 6.0 + randf() * 0.2
			var end_pos := local_center + Vector2(cos(angle), sin(angle)) * randf_range(28.0, 54.0) * strength - spark.size * 0.5
			var pop := create_tween()
			pop.tween_property(spark, "position", end_pos, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			pop.parallel().tween_property(spark, "modulate:a", 0.0, 0.32)
			pop.tween_callback(spark.queue_free)


func _draw_fx_bubble(bubble: Control) -> void:
	if bubble == null:
		return
	var color: Color = bubble.get_meta("bubble_color", Color(1, 1, 1, 0.5))
	var center := bubble.size * 0.5
	var radius := minf(bubble.size.x, bubble.size.y) * 0.48
	bubble.draw_circle(center, radius, color)
	bubble.draw_arc(center, radius, 0.0, TAU, 28, Color(1, 1, 1, 0.45), 2.0, true)
	bubble.draw_circle(center + Vector2(-radius * 0.28, -radius * 0.28), radius * 0.18, Color(1, 1, 1, 0.35))


func _on_score_tween(value: float) -> void:
	_score_label.text = "Puntuación: %d" % int(round(value))


func _enable_buttons() -> void:
	_set_buttons_disabled(false)


func _set_buttons_disabled(disabled: bool) -> void:
	if _buttons_box == null:
		return
	for child in _buttons_box.get_children():
		if child is Button:
			(child as Button).disabled = disabled
		elif child is Container:
			for nested in child.get_children():
				if nested is Button:
					(nested as Button).disabled = disabled


## Tras puntuación 1000: burbuja +N al lado → baja → explota → infla badge y suma.
func _start_plus_one_to_hints_animation() -> void:
	if not is_inside_tree() or _fx_layer == null or _hints_label == null or _hints_badge == null:
		_finish_hint_reward_fallback()
		return

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

	var gained := maxi(1, _hint_reward)
	_hint_reveal_left = gained
	_pending_hint_count = maxi(0, SaveManager.get_hints() - gained)
	_set_hint_count_display(float(_pending_hint_count))
	_hints_badge.visible = true
	_hints_badge.modulate = Color(1, 1, 1, 1)
	_hints_badge.scale = Vector2.ONE
	_hints_badge.queue_redraw()
	if _fx_layer != null:
		_fx_layer.visible = true
		_fx_layer.z_index = 80
	_fit_panel()

	if is_instance_valid(_hint_flyer):
		_hint_flyer.queue_free()
	_hint_flyer = _make_plus_bubble(gained)
	_hint_flyer.top_level = true
	_fx_layer.add_child(_hint_flyer)

	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(_hint_flyer) or not is_instance_valid(_hints_badge):
		_finish_hint_reward_fallback()
		return

	var start_center := _plus_one_start_beside_score()
	var end_center := _hints_badge.global_position + _hints_badge.size * 0.5
	if start_center.x < 8.0 or start_center.y < 8.0:
		start_center = Vector2(size.x * 0.5, size.y * 0.45)
	if end_center.x < 8.0 or end_center.y < 8.0:
		end_center = Vector2(size.x * 0.5, size.y * 0.72)

	var flyer_size := Vector2(112, 112)
	_hint_flyer.size = flyer_size
	_hint_flyer.custom_minimum_size = flyer_size
	_hint_flyer.pivot_offset = flyer_size * 0.5
	_hint_flyer.visible = true
	_place_control_center(_hint_flyer, start_center)
	_hint_flyer.scale = Vector2(0.12, 0.12)
	_hint_flyer.modulate = Color(1, 1, 1, 1)
	_hint_flyer.queue_redraw()

	_tween = create_tween()
	# 1) Burbuja crece al lado de la puntuación.
	_tween.tween_property(_hint_flyer, "scale", Vector2(1.2, 1.2), 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_hint_flyer, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 2) Se queda un momento.
	_tween.tween_interval(0.55)
	# 3) Baja hacia el badge (sin encogerse demasiado; explota al llegar).
	_tween.tween_method(
		_move_plus_one_descent.bind(_hint_flyer, start_center, end_center),
		0.0,
		1.0,
		0.75
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_hint_flyer, "scale", Vector2(0.85, 0.85), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# 4) Explota la burbuja y luego infla el badge + suma.
	_tween.tween_callback(_on_plus_bubble_exploded)


func _plus_one_start_beside_score() -> Vector2:
	var mid_y := size.y * 0.45
	var right_x := size.x * 0.78
	var left_x := size.x * 0.22
	if _score_capsule != null and is_instance_valid(_score_capsule):
		var gp := _score_capsule.global_position
		var sz := _score_capsule.size
		if sz.x < 8.0:
			sz = _score_capsule.get_combined_minimum_size()
		if sz.x >= 8.0:
			mid_y = gp.y + sz.y * 0.5
			right_x = gp.x + sz.x + 64.0
			left_x = gp.x - 64.0
	elif _score_label != null and is_instance_valid(_score_label):
		var gp2 := _score_label.global_position
		var sz2 := _score_label.size
		if sz2.x >= 8.0:
			mid_y = gp2.y + sz2.y * 0.5
			right_x = gp2.x + sz2.x + 64.0
			left_x = gp2.x - 64.0
	var side_x := right_x if right_x < size.x - 56.0 else left_x
	return Vector2(side_x, mid_y)


func _make_plus_bubble(amount: int = 1) -> Control:
	var bubble := Control.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.z_index = 100
	bubble.z_as_relative = false
	bubble.set_meta("bubble_color", Color("FFD84A"))
	bubble.draw.connect(_draw_plus_bubble.bind(bubble))

	var plus := Label.new()
	plus.text = "+%d" % maxi(1, amount)
	plus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.add_theme_font_size_override("font_size", 42)
	plus.add_theme_color_override("font_color", Color("5A3200"))
	plus.add_theme_color_override("font_outline_color", Color("FFF3A8"))
	plus.add_theme_constant_override("outline_size", 4)
	UIFactory.apply_font(plus, true)
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(plus)
	return bubble


func _draw_plus_bubble(bubble: Control) -> void:
	if bubble == null or not is_instance_valid(bubble):
		return
	var center := bubble.size * 0.5
	var radius := minf(bubble.size.x, bubble.size.y) * 0.46
	var base: Color = bubble.get_meta("bubble_color", Color("FFD84A"))
	bubble.draw_circle(center + Vector2(0, 3), radius, Color(base.darkened(0.35), 0.35))
	bubble.draw_circle(center, radius, Color(base.r, base.g, base.b, 0.92))
	bubble.draw_circle(center, radius * 0.86, Color(base.lightened(0.22), 0.95))
	bubble.draw_arc(center, radius * 0.96, 0.0, TAU, 36, Color(1, 1, 1, 0.55), 2.4, true)
	bubble.draw_circle(center + Vector2(-radius * 0.28, -radius * 0.3), radius * 0.18, Color(1, 1, 1, 0.55))


func _move_plus_one_descent(flyer: Control, start_center: Vector2, end_center: Vector2, t: float) -> void:
	if not is_instance_valid(flyer):
		return
	var tt := clampf(t, 0.0, 1.0)
	var p := start_center.lerp(end_center, tt)
	_place_control_center(flyer, p)


func _style_hints_count_label(font_size: int) -> void:
	if _hints_count_label == null or not is_instance_valid(_hints_count_label):
		return
	_hints_count_label.add_theme_font_size_override("font_size", font_size)
	UIFactory.apply_title_font(_hints_count_label)
	# Número destacado: blanco grueso sobre el badge amarillo.
	_hints_count_label.add_theme_color_override("font_color", Color("FFFFFF"))
	_hints_count_label.add_theme_color_override("font_outline_color", Color("5A3410"))
	_hints_count_label.add_theme_constant_override("outline_size", 8)
	_hints_count_label.add_theme_color_override("font_shadow_color", Color(0.2, 0.1, 0.02, 0.45))
	_hints_count_label.add_theme_constant_override("shadow_offset_x", 0)
	_hints_count_label.add_theme_constant_override("shadow_offset_y", 2)
	_hints_count_label.add_theme_constant_override("shadow_outline_size", 4)


func _set_hint_count_display(value: float) -> void:
	_pending_hint_count = maxi(0, int(round(value)))
	if is_instance_valid(_hints_label):
		_hints_label.text = "Pistas:"
		_hints_label.add_theme_color_override("font_color", GamePalette.MENU_YELLOW_TEXT)
	if is_instance_valid(_hints_count_label):
		_hints_count_label.text = str(_pending_hint_count)
	if is_instance_valid(_hints_badge):
		_hints_badge.queue_redraw()


func _on_plus_bubble_exploded() -> void:
	var impact_center := Vector2.ZERO
	if is_instance_valid(_hint_flyer):
		impact_center = _hint_flyer.global_position + _hint_flyer.pivot_offset
		_hint_flyer.visible = false
		_hint_flyer.queue_free()
		_hint_flyer = null
	elif is_instance_valid(_hints_badge):
		impact_center = _hints_badge.global_position + _hints_badge.size * 0.5

	_spawn_bubble_pop_burst(impact_center)
	AudioManager.play(AudioManager.Sfx.CONNECT)

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	# Espera a que la burbuja +1 desaparezca y luego explota el número.
	_tween.tween_interval(0.14)
	_tween.tween_callback(_inflate_hints_badge_and_add)


func _inflate_hints_badge_and_add() -> void:
	_hint_reveal_left = 0
	var to_count := float(SaveManager.get_hints())
	if not is_instance_valid(_hints_badge):
		_set_hint_count_display(to_count)
		_finish_hint_reward_fallback()
		return

	_hints_badge.visible = true
	_hints_badge.modulate = Color(1, 1, 1, 1)
	_hints_badge.pivot_offset = _hints_badge.size * 0.5
	_hints_badge.scale = Vector2.ONE

	# Cambia el número con explosión de burbuja (no un simple swap).
	_pop_hints_count_like_bubble(int(to_count))

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_hints_badge, "scale", Vector2(1.12, 1.12), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_hints_badge, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_interval(0.12)
	_tween.tween_property(_buttons_box, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_finish_presentation)


func _pop_hints_count_like_bubble(new_count: int) -> void:
	_pending_hint_count = maxi(0, new_count)
	if not is_instance_valid(_hints_count_label):
		_set_hint_count_display(float(_pending_hint_count))
		return

	var count_center := _hints_count_label.global_position + _hints_count_label.size * 0.5
	if count_center.x < 4.0 or count_center.y < 4.0:
		count_center = _hints_badge.global_position + _hints_badge.size * 0.5
	_spawn_bubble_pop_burst(count_center)
	_spawn_soft_bubble(count_center, Color("FFFFFF"), 0.85)

	_hints_count_label.text = str(_pending_hint_count)
	_style_hints_count_label(maxi(22, int(round(34.0 * _layout_scale))))
	var pivot := _hints_count_label.size * 0.5
	if pivot.length_squared() < 1.0:
		pivot = _hints_count_label.get_combined_minimum_size() * 0.5
	_hints_count_label.pivot_offset = pivot
	_hints_count_label.scale = Vector2.ZERO
	_hints_count_label.modulate = Color(1, 1, 1, 1)

	var pop := create_tween()
	# Infla como burbuja: 0 → un poco más grande → tamaño normal.
	pop.tween_property(_hints_count_label, "scale", Vector2(1.35, 1.35), 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pop.tween_property(_hints_count_label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if is_instance_valid(_hints_badge):
		_hints_badge.queue_redraw()


## Explosión circular de la burbuja (sin cuadrados ColorRect).
func _spawn_bubble_pop_burst(center_global: Vector2) -> void:
	if _fx_layer == null or not is_inside_tree():
		return
	var local_center := center_global - _fx_layer.global_position

	# Anillo que se expande y se desvanece.
	var ring := Control.new()
	ring.size = Vector2(36, 36)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.pivot_offset = ring.size * 0.5
	ring.set_meta("bubble_color", Color("FFD84A", 0.7))
	ring.draw.connect(_draw_fx_bubble.bind(ring))
	_fx_layer.add_child(ring)
	ring.position = local_center - ring.size * 0.5
	var ring_tw := create_tween()
	ring_tw.tween_property(ring, "scale", Vector2(3.6, 3.6), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.4)
	ring_tw.tween_callback(ring.queue_free)

	var droplet_count := 10 if SettingsManager.fx_enabled else 6
	for i in range(droplet_count):
		var drop := Control.new()
		var drop_size := randf_range(10.0, 18.0)
		drop.size = Vector2(drop_size, drop_size)
		drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drop.pivot_offset = drop.size * 0.5
		drop.set_meta("bubble_color", Color("FFD84A") if i % 2 == 0 else Color("FFE45E"))
		drop.draw.connect(_draw_fx_bubble.bind(drop))
		_fx_layer.add_child(drop)
		drop.position = local_center - drop.size * 0.5
		var angle := TAU * float(i) / float(droplet_count) + randf() * 0.2
		var dist := randf_range(34.0, 72.0)
		var end_pos := local_center + Vector2(cos(angle), sin(angle)) * dist - drop.size * 0.5
		var pop := create_tween()
		pop.tween_property(drop, "position", end_pos, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pop.parallel().tween_property(drop, "scale", Vector2(0.2, 0.2), 0.42)
		pop.parallel().tween_property(drop, "modulate:a", 0.0, 0.42)
		pop.tween_callback(drop.queue_free)


func _finish_hint_reward_fallback() -> void:
	_set_hint_count_display(float(SaveManager.get_hints()))
	if is_instance_valid(_hints_count_label):
		_hints_count_label.scale = Vector2.ONE
	if is_instance_valid(_hints_badge):
		_hints_badge.modulate = Color(1, 1, 1, 1)
		_hints_badge.queue_redraw()
	_buttons_box.modulate = Color(1, 1, 1, 1)
	_finish_presentation()


func _style_moves_capsule() -> void:
	if _moves_capsule == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1A2A5A")
	style.border_color = Color("FFD84A")
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0.1, 0.15, 0.35, 0.45)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	_moves_capsule.add_theme_stylebox_override("panel", style)


func _style_score_capsule() -> void:
	if _score_capsule == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = GamePalette.SCORE_NAVY
	style.border_color = Color("7FD9F5")
	style.border_width_left = 5
	style.border_width_top = 5
	style.border_width_right = 5
	style.border_width_bottom = 5
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_left = 28
	style.corner_radius_bottom_right = 28
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0.2, 0.75, 1.0, 0.45)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 0)
	_score_capsule.add_theme_stylebox_override("panel", style)


func _style_score_hint_panel(bg: Color) -> void:
	if _score_hint_panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(bg.r, bg.g, bg.b, 0.98)
	style.border_color = Color("FFFFFF")
	style.border_width_left = 5
	style.border_width_top = 5
	style.border_width_right = 5
	style.border_width_bottom = 5
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_color = Color(0.1, 0.35, 0.15, 0.35)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 3)
	_score_hint_panel.add_theme_stylebox_override("panel", style)
	if _score_hint != null:
		_score_hint.add_theme_font_size_override("font_size", 26)
		if bg.is_equal_approx(GamePalette.SUCCESS) or bg.g > 0.55:
			_score_hint.add_theme_color_override("font_color", Color("145A28"))
		else:
			_score_hint.add_theme_color_override("font_color", GamePalette.BUTTON_TEXT)


func _score_hint_color_for_stars(stars: int) -> Color:
	var s := clampi(stars, 0, 3)
	if s >= 3:
		return GamePalette.SUCCESS
	if s == 2:
		return GamePalette.BUTTON
	if s == 1:
		return GamePalette.BUTTON_CYAN
	return GamePalette.PANEL_LIGHT


func _on_sunburst_draw() -> void:
	if _sunburst == null or _sunburst.size.x < 2.0:
		return
	var center := _sunburst.size * 0.5
	_sunburst.draw_rect(Rect2(Vector2.ZERO, _sunburst.size), GamePalette.MENU_DARKEST, true)
	var rays := 28
	for i in range(rays):
		var a0 := float(i) / float(rays) * TAU
		var a1 := float(i + 1) / float(rays) * TAU
		var outer := maxf(_sunburst.size.x, _sunburst.size.y)
		var p0 := center
		var p1 := center + Vector2(cos(a0), sin(a0)) * outer
		var p2 := center + Vector2(cos(a1), sin(a1)) * outer
		var col := Color(0.25, 0.45, 0.95, 0.55) if i % 2 == 0 else Color(0.2, 0.38, 0.85, 0.4)
		_sunburst.draw_colored_polygon(PackedVector2Array([p0, p1, p2]), col)
	_sunburst.draw_circle(center, mini(center.x, center.y) * 0.28, Color(0.45, 0.7, 1.0, 0.14))
	_draw_confetti()


func _draw_confetti() -> void:
	if _sunburst == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _confetti_seed
	var w := _sunburst.size.x
	var h := _sunburst.size.y
	for i in range(28):
		var color: Color = CONFETTI_COLORS[i % CONFETTI_COLORS.size()]
		var pos := Vector2(rng.randf_range(w * 0.05, w * 0.95), rng.randf_range(h * 0.02, h * 0.42))
		var piece := Rect2(pos, Vector2(rng.randf_range(8.0, 16.0), rng.randf_range(5.0, 10.0)))
		_sunburst.draw_rect(piece, Color(color.r, color.g, color.b, 0.85), true)


func _on_hints_badge_draw() -> void:
	if _hints_badge == null:
		return
	var w := _hints_badge.size.x
	var h := _hints_badge.size.y
	if w < 40.0 or h < 24.0 or w > 4096.0 or h > 4096.0:
		return
	var ci := _hints_badge.get_canvas_item()
	var base := GamePalette.MENU_YELLOW
	var radius := 22
	var body_h := h - HINTS_BADGE_DEPTH
	var base_rect := Rect2(0.0, HINTS_BADGE_DEPTH, w, body_h)
	var body := Rect2(0.0, 0.0, w, body_h)

	var glow := _badge_box(Color(0, 0, 0, 0), radius)
	glow.shadow_color = Color(base.r, base.g, base.b, 0.45)
	glow.shadow_size = 12
	glow.shadow_offset = Vector2(0, 5)
	glow.draw(ci, base_rect)

	_badge_box(base.darkened(0.38), radius).draw(ci, base_rect)

	var main := _badge_box(base, radius)
	main.border_color = base.lightened(0.5)
	main.border_width_left = 3
	main.border_width_top = 3
	main.border_width_right = 3
	main.border_width_bottom = 3
	main.draw(ci, body)

	var shade := _badge_box(Color(base.darkened(0.16), 0.6), radius)
	shade.corner_radius_top_left = 0
	shade.corner_radius_top_right = 0
	shade.corner_radius_bottom_left = radius - 3
	shade.corner_radius_bottom_right = radius - 3
	shade.draw(ci, Rect2(3.0, body_h * 0.52, w - 6.0, body_h * 0.48 - 3.0))

	var highlight := _badge_box(Color(1, 1, 1, 0.3), radius - 8)
	highlight.corner_radius_bottom_left = 10
	highlight.corner_radius_bottom_right = 10
	highlight.draw(ci, Rect2(8.0, 5.0, w - 16.0, body_h * 0.38))

	_hints_badge.draw_circle(Vector2(24.0, 14.0), 3.0, Color(1, 1, 1, 0.7))


func _draw_color_swatch(swatch: Control, color_name: String) -> void:
	var color := GamePalette.get_color(color_name)
	var center := swatch.size * 0.5
	var radius := minf(swatch.size.x, swatch.size.y) * 0.46
	swatch.draw_circle(center, radius, color)
	swatch.draw_arc(center, radius, 0.0, TAU, 28, Color(1, 1, 1, 0.55), 1.5, true)
	if BoardTheme.shows_shapes(_level_id):
		ColorShapesScript.draw_on_ball(swatch, center, radius, GamePalette.shape_for(color_name), color)


func _badge_box(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.anti_aliasing = true
	return sb


func _clear_fx_layer() -> void:
	if _fx_layer == null:
		return
	for child in _fx_layer.get_children():
		child.queue_free()
	_hint_flyer = null
	_title_flyer = null


static func score_for_stars(stars: int) -> int:
	var s := clampi(stars, 0, 3)
	if s == 3:
		return 1000
	if s == 2:
		return 600
	if s == 1:
		return 300
	return 0


static func score_hint_for_stars(stars: int) -> String:
	var s := clampi(stars, 0, 3)
	if s == 3:
		return "¡3★!"
	if s == 2:
		return "Muy bien"
	if s == 1:
		return "Completado"
	return ""


func _kill_tween() -> void:
	_color_seq_id += 1
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_clear_flying_star()
	if is_instance_valid(_hint_flyer):
		_hint_flyer.queue_free()
	_hint_flyer = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _title != null and is_instance_valid(_title):
		_title.pivot_offset = _title.size * 0.5
