extends Control

## Selección de nivel — mismo formato visual que el menú principal.

const TITLE_LETTER_COLORS: Array[Color] = [
	Color("FF4FB0"),
	Color("FF8A3D"),
	Color("FFD43B"),
	Color("7BE04A"),
	Color("3DDC97"),
	Color("3CC8F0"),
	Color("4F8BFF"),
]

## Colores oscuros de alto contraste.
const COLOR_LOCKED := Color("0B142C")
const COLOR_LOCKED_TEXT := Color("C5D4F5")
const COLOR_TO_PLAY := Color("102448")
const COLOR_TO_PLAY_TEXT := Color("F2F6FF")
const COLOR_CURRENT := Color("8A3A00")
const COLOR_CURRENT_TEXT := Color("FFF3D6")
const COLOR_PLAYED := Color("0A2E48")
const COLOR_PLAYED_TEXT := Color("E8F7FF")
const COLOR_PERFECT := Color("0A2F1A")
const COLOR_PERFECT_TEXT := Color("E8FFE8")
const STAR_ON := Color("FFD23F")
const STAR_OFF := Color("3A4A6E")
## Fricción del fling tras soltar el dedo (mayor = para antes).
const SCROLL_FRICTION := 9.0
## Velocidad mínima (px/s) para seguir el fling.
const SCROLL_STOP_SPEED := 48.0

var _grid: GridContainer
var _scroll: ScrollContainer
var _scroll_velocity := 0.0
var _scroll_flinging := false
var _scroll_touch_index := -1
var _scroll_accum := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	_build_ui()
	resized.connect(_on_resized)
	call_deferred("_apply_responsive_layout")


func _process(delta: float) -> void:
	if not _scroll_flinging or _scroll == null or not is_instance_valid(_scroll):
		_stop_scroll_fling()
		return
	if absf(_scroll_velocity) < SCROLL_STOP_SPEED:
		_stop_scroll_fling()
		return
	_scroll_by(_scroll_velocity * delta)
	var max_v := _scroll_max_v()
	# Si chocó con el tope/fondo, corta la inercia.
	if (_scroll_velocity < 0.0 and _scroll.scroll_vertical <= 0) \
			or (_scroll_velocity > 0.0 and _scroll.scroll_vertical >= max_v):
		_stop_scroll_fling()
		return
	_scroll_velocity *= exp(-SCROLL_FRICTION * delta)


func _build_ui() -> void:
	var bg: Control
	if LevelManager.current_mode == LevelManager.MODE_CHRONO:
		bg = UIFactory.attach_crazy_background(self)
	else:
		bg = UIFactory.attach_neon_background(self, false)
		if LevelManager.current_mode == LevelManager.MODE_HARDCORE:
			UIFactory.apply_hardcore_background(bg)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 28)
	root.add_theme_constant_override("margin_right", 28)
	root.add_theme_constant_override("margin_top", 48)
	root.add_theme_constant_override("margin_bottom", 28)
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(vbox)

	var title := _make_screen_title()
	vbox.add_child(title)

	var mode_title := LevelManager.get_mode_title(LevelManager.current_mode)
	var unlocked := SaveManager.get_last_unlocked_level()
	var theme_title := BoardTheme.title_for_level(unlocked)
	var subtitle := UIFactory.make_light_subtitle(
		"%s · Tema: %s · Completa para desbloquear" % [mode_title, theme_title],
		22
	)
	vbox.add_child(subtitle)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# En móvil los botones de nivel se tragan el arrastre; el umbral ayuda al ScrollContainer.
	_scroll.scroll_deadzone = 16
	vbox.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)

	var levels := LevelManager.get_levels_for_select()
	var current := unlocked
	for level: Variant in levels:
		if typeof(level) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = level
		var id := int(entry.get("id", 1))
		_grid.add_child(_make_level_tile(id, entry, id == current))

	var back := UIFactory.make_button("VOLVER", 90)
	UIFactory.set_button_colors(back, GamePalette.MENU_BLUE, Color.WHITE)
	UIFactory.set_button_icon(back, UIFactory.ButtonIcon.BACK, Color.WHITE)
	back.pressed.connect(_on_back)
	vbox.add_child(back)

	call_deferred("_play_intro", [title, subtitle, back])


func _on_resized() -> void:
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	if _grid == null or not is_instance_valid(_grid):
		return
	var vp := get_viewport_rect().size
	var cols := 3
	if vp.x < 420.0:
		cols = 2
	elif vp.x >= 900.0:
		cols = 4
	_grid.columns = cols

	var h_sep := 14.0
	var margin := 56.0
	var usable_w := maxf(200.0, vp.x - margin - h_sep * float(cols - 1))
	var cell_w := usable_w / float(cols)
	# Altura generosa para número + estrellas / candado.
	var cell_h := clampf(cell_w * 0.92, 110.0, 168.0)
	var num_size := clampi(int(cell_h * 0.38), 36, 56)
	var lock_size := clampf(cell_h * 0.42, 40.0, 64.0)
	var star_size := clampf(cell_h * 0.28, 28.0, 44.0)

	for child in _grid.get_children():
		if child is Button:
			var btn := child as Button
			btn.custom_minimum_size = Vector2(0, cell_h)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if btn.has_meta("num_label"):
				var num: Label = btn.get_meta("num_label")
				num.add_theme_font_size_override("font_size", num_size)
			if btn.has_meta("lock_icon"):
				var lock: Control = btn.get_meta("lock_icon")
				lock.custom_minimum_size = Vector2(lock_size, lock_size)
				lock.queue_redraw()
			if btn.has_meta("star_icons"):
				var stars: Array = btn.get_meta("star_icons")
				for star_variant in stars:
					var star: Control = star_variant
					if is_instance_valid(star):
						star.custom_minimum_size = Vector2(star_size, star_size)
						star.queue_redraw()


func _make_screen_title() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -18)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for word: String in ["SELECCIONAR", "NIVEL"]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", -2)
		var white_line := word == "SELECCIONAR"
		for i in range(word.length()):
			row.add_child(_make_title_letter(word[i], white_line, i % TITLE_LETTER_COLORS.size()))
		box.add_child(row)

	var underline := Control.new()
	underline.custom_minimum_size = Vector2(0, 30)
	underline.draw.connect(_draw_title_underline.bind(underline))
	box.add_child(underline)
	return box


func _make_title_letter(letter: String, white: bool, color_index: int) -> Label:
	var label := Label.new()
	label.text = letter
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 72)
	UIFactory.apply_title_font(label)
	if white:
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color("2F6EEA"))
		label.add_theme_constant_override("outline_size", 12)
		label.add_theme_color_override("font_shadow_color", Color("0D1E66"))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 5)
		label.add_theme_constant_override("shadow_outline_size", 12)
	else:
		var color: Color = TITLE_LETTER_COLORS[color_index]
		label.add_theme_color_override("font_color", color.lightened(0.12))
		label.add_theme_color_override("font_outline_color", Color("1A1F6E"))
		label.add_theme_constant_override("outline_size", 10)
		label.add_theme_color_override("font_shadow_color", Color(color.r, color.g, color.b, 0.55))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
		label.add_theme_constant_override("shadow_outline_size", 18)
	return label


func _draw_title_underline(control: Control) -> void:
	var w := control.size.x
	if w < 8.0:
		return
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var steps := 32
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		points.append(Vector2(lerpf(w * 0.22, w * 0.78, t), 16.0 + sin(t * PI) * 5.0))
		if t < 0.5:
			colors.append(Color("FF4FB0").lerp(Color("FFB23D"), t * 2.0))
		else:
			colors.append(Color("FFB23D").lerp(Color("3CC8F0"), (t - 0.5) * 2.0))
	control.draw_polyline_colors(points, colors, 5.0, true)


func _make_level_tile(level_id: int, level: Dictionary, is_current: bool) -> Button:
	var unlocked := SaveManager.is_level_unlocked(level_id)
	var stars := SaveManager.get_level_stars(level_id)
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 128)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = not unlocked
	button.clip_contents = true

	var bg: Color
	var fg: Color
	if not unlocked:
		bg = COLOR_LOCKED
		fg = COLOR_LOCKED_TEXT
	elif is_current:
		bg = COLOR_CURRENT
		fg = COLOR_CURRENT_TEXT
	elif stars >= 3:
		bg = COLOR_PERFECT
		fg = COLOR_PERFECT_TEXT
	elif stars > 0:
		bg = COLOR_PLAYED
		fg = COLOR_PLAYED_TEXT
	else:
		bg = COLOR_TO_PLAY
		fg = COLOR_TO_PLAY_TEXT

	UIFactory._style_button(button, false)
	UIFactory.set_button_colors(button, bg, fg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 14)
	button.add_child(margin)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	# Fila: número (+ candado si bloqueado), estilo valor de pistas/stats.
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 10)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top_row)

	var num := Label.new()
	num.text = str(level_id)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 44)
	num.add_theme_color_override("font_color", fg)
	num.add_theme_color_override("font_outline_color", Color("0A1240"))
	num.add_theme_constant_override("outline_size", 8)
	num.add_theme_color_override("font_shadow_color", Color(0.02, 0.05, 0.18, 0.75))
	num.add_theme_constant_override("shadow_offset_x", 0)
	num.add_theme_constant_override("shadow_offset_y", 2)
	num.add_theme_constant_override("shadow_outline_size", 4)
	UIFactory.apply_title_font(num)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(num)
	button.set_meta("num_label", num)

	if not unlocked:
		var lock := Control.new()
		lock.custom_minimum_size = Vector2(52, 52)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.draw.connect(_draw_lock.bind(lock, fg))
		top_row.add_child(lock)
		button.set_meta("lock_icon", lock)
	else:
		var stars_row := HBoxContainer.new()
		stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
		stars_row.add_theme_constant_override("separation", 4)
		stars_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(stars_row)
		var star_icons: Array = []
		for i in range(3):
			var star := Control.new()
			star.custom_minimum_size = Vector2(34, 34)
			star.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var filled := i < stars
			star.draw.connect(_draw_star.bind(star, filled))
			stars_row.add_child(star)
			star_icons.append(star)
		button.set_meta("star_icons", star_icons)

	button.gui_input.connect(_on_tile_gui_input.bind(button))
	if unlocked:
		button.pressed.connect(_on_level_pressed.bind(button, level_id))
	button.tooltip_text = "%s · %s" % [
		str(level.get("name", "Nivel %d" % level_id)),
		str(level.get("theme", BoardTheme.title_for_level(level_id))),
	]
	return button


func _draw_lock(node: Control, tint: Color) -> void:
	var s := mini(node.size.x, node.size.y)
	if s < 8.0:
		return
	var c := node.size * 0.5
	var u := s / 52.0
	var body := Color(tint.r, tint.g, tint.b, 0.95)
	var dark := body.darkened(0.35)
	# Aro del candado (más grande).
	node.draw_arc(c + Vector2(0, -8.0 * u), 12.0 * u, PI, TAU, 24, body, 4.5 * u, true)
	# Cuerpo.
	var rect := Rect2(c + Vector2(-14.0 * u, -2.0 * u), Vector2(28.0 * u, 22.0 * u))
	var box := StyleBoxFlat.new()
	box.bg_color = body
	box.corner_radius_top_left = int(5.0 * u)
	box.corner_radius_top_right = int(5.0 * u)
	box.corner_radius_bottom_left = int(5.0 * u)
	box.corner_radius_bottom_right = int(5.0 * u)
	box.draw(node.get_canvas_item(), rect)
	node.draw_circle(c + Vector2(0, 8.0 * u), 3.2 * u, dark)
	node.draw_rect(Rect2(c + Vector2(-1.4 * u, 8.0 * u), Vector2(2.8 * u, 7.0 * u)), dark, true)


func _draw_star(node: Control, filled: bool) -> void:
	var s := mini(node.size.x, node.size.y)
	if s < 6.0:
		return
	var c := node.size * 0.5
	var outer := s * 0.48
	var inner := outer * 0.42
	var points := PackedVector2Array()
	for i in range(10):
		var angle := -PI * 0.5 + float(i) * PI / 5.0
		var radius := outer if i % 2 == 0 else inner
		points.append(c + Vector2(cos(angle), sin(angle)) * radius)
	var col := STAR_ON if filled else STAR_OFF
	node.draw_colored_polygon(points, col)
	if filled:
		node.draw_polyline(points + PackedVector2Array([points[0]]), Color("E39500"), 2.0, true)
		node.draw_circle(c + Vector2(-outer * 0.18, -outer * 0.2), outer * 0.12, Color(1, 1, 1, 0.55))


func _play_intro(nodes: Array) -> void:
	UIFactory.play_enter_animation(nodes, 0.05)


func _on_tile_gui_input(event: InputEvent, button: Button) -> void:
	if _scroll == null or not is_instance_valid(_scroll):
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			button.set_meta("did_scroll", false)
			_scroll_touch_index = touch.index
			_stop_scroll_fling()
		elif touch.index == _scroll_touch_index:
			# Al soltar: si hubo arrastre, lanza la inercia con la última velocidad.
			if bool(button.get_meta("did_scroll", false)) and absf(_scroll_velocity) >= SCROLL_STOP_SPEED:
				_scroll_flinging = true
				set_process(true)
			else:
				_scroll_velocity = 0.0
			_scroll_touch_index = -1
		return
	if not (event is InputEventScreenDrag):
		return
	var drag := event as InputEventScreenDrag
	if _scroll_touch_index >= 0 and drag.index != _scroll_touch_index:
		return
	if absf(drag.relative.y) < 0.5 and absf(drag.relative.x) < 0.5:
		return
	button.set_meta("did_scroll", true)
	_scroll_flinging = false
	set_process(false)
	# velocity viene en px/s; el scroll manual usa relative (px este frame).
	_scroll_velocity = -drag.velocity.y
	_scroll_by(-drag.relative.y)
	# Evita que el botón se quede "pulsado" al soltar tras un arrastre.
	button.set_pressed_no_signal(false)
	button.release_focus()
	button.accept_event()


func _scroll_max_v() -> int:
	var bar := _scroll.get_v_scroll_bar()
	if bar == null:
		return 0
	return maxi(0, int(bar.max_value - bar.page))


func _scroll_by(delta_y: float) -> void:
	_scroll_accum += delta_y
	# Godot 4.2: no hay trunc() global; int() trunca hacia cero.
	var whole := int(_scroll_accum)
	if whole == 0:
		return
	_scroll_accum -= float(whole)
	var max_v := _scroll_max_v()
	var next := clampi(_scroll.scroll_vertical + whole, 0, max_v)
	if next == _scroll.scroll_vertical:
		# Tope: descarta el resto acumulado.
		_scroll_accum = 0.0
	_scroll.scroll_vertical = next


func _stop_scroll_fling() -> void:
	_scroll_flinging = false
	_scroll_velocity = 0.0
	_scroll_accum = 0.0
	set_process(false)


func _on_level_pressed(button: Button, level_id: int) -> void:
	if button != null and bool(button.get_meta("did_scroll", false)):
		button.set_meta("did_scroll", false)
		return
	AudioManager.play(AudioManager.Sfx.SELECT)
	LevelManager.set_current_level(level_id)
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_back() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	get_tree().change_scene_to_file("res://scenes/mode_hub.tscn")
