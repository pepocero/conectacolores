extends Control

const _RESET_RED := Color("FF3B30")
const _RESET_RED_DARK := Color("5A1010")

var _confirm_overlay: Control
var _confirm_panel: PanelContainer
var _confirm_title: Label
var _confirm_message: Label
var _confirm_cancel_btn: Button
var _confirm_ok_btn: Button
var _confirm_step: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_build_confirm_overlay()


func _build_ui() -> void:
	var mode_id := LevelManager.current_mode
	var mode_title := LevelManager.get_mode_title(mode_id)

	var bg: Control
	if mode_id == LevelManager.MODE_CHRONO:
		bg = UIFactory.attach_crazy_background(self)
	else:
		bg = UIFactory.attach_neon_background(self, false)
		if mode_id == LevelManager.MODE_HARDCORE:
			UIFactory.apply_hardcore_background(bg)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 36)
	root.add_theme_constant_override("margin_right", 36)
	root.add_theme_constant_override("margin_top", 56)
	root.add_theme_constant_override("margin_bottom", 40)
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	root.add_child(vbox)

	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_top)

	var title := _make_mode_title(mode_title)
	vbox.add_child(title)

	var subtitle_text := "Dificultad progresiva: cada nivel un poco más exigente."
	if mode_id == LevelManager.MODE_HARD:
		subtitle_text = "Misma progresión, con tableros y enredos más difíciles."
	elif mode_id == LevelManager.MODE_HARDCORE:
		subtitle_text = "Más parejas por casilla, tablero más lleno y caminos más enredados."
	elif mode_id == LevelManager.MODE_CHRONO:
		subtitle_text = "Sin límite de tiempo: cada minuto cambian las bolas no unidas. Ganas solo al resolver el nivel."
	elif mode_id == LevelManager.MODE_SANDBOX:
		subtitle_text = "Une las rocas del mismo color con surcos. No se pueden cruzar."
	var unlocked := SaveManager.get_last_unlocked_level(mode_id)
	var current := maxi(1, unlocked)
	var info_card := _make_info_card(subtitle_text, current)
	vbox.add_child(info_card)

	var mid := Control.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(mid)

	var buttons_center := CenterContainer.new()
	vbox.add_child(buttons_center)

	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(480, 0)
	buttons.add_theme_constant_override("separation", 26)
	buttons_center.add_child(buttons)

	var continue_btn := UIFactory.make_accent_button("CONTINUAR", 100)
	UIFactory.set_button_icon(continue_btn, UIFactory.ButtonIcon.PLAY)
	continue_btn.add_theme_font_size_override("font_size", 30)
	continue_btn.pressed.connect(_on_continue)
	buttons.add_child(continue_btn)

	var select_btn := UIFactory.make_button("SELECCIONAR NIVEL", 94)
	UIFactory.set_button_icon(select_btn, UIFactory.ButtonIcon.GRID)
	select_btn.add_theme_font_size_override("font_size", 28)
	select_btn.pressed.connect(_on_select)
	buttons.add_child(select_btn)

	var reset_btn := UIFactory.make_button("RESETEAR TODO", 90)
	UIFactory.set_button_colors(reset_btn, GamePalette.ACCENT_MAGENTA, Color.WHITE)
	UIFactory.set_button_icon(reset_btn, UIFactory.ButtonIcon.RESTART, Color.WHITE)
	reset_btn.add_theme_font_size_override("font_size", 28)
	reset_btn.pressed.connect(_on_reset_pressed)
	buttons.add_child(reset_btn)

	var back_btn := UIFactory.make_button("VOLVER", 90)
	UIFactory.set_button_colors(back_btn, GamePalette.MENU_BLUE, Color.WHITE)
	UIFactory.set_button_icon(back_btn, UIFactory.ButtonIcon.BACK)
	back_btn.add_theme_font_size_override("font_size", 30)
	back_btn.pressed.connect(_on_back)
	buttons.add_child(back_btn)

	var spacer_bottom := Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_bottom)

	call_deferred("_play_intro", [title, info_card, continue_btn, select_btn, reset_btn, back_btn])


const TITLE_LETTER_COLORS: Array[Color] = [
	Color("FF4FB0"),
	Color("FF8A3D"),
	Color("FFD43B"),
	Color("7BE04A"),
	Color("3DDC97"),
	Color("3CC8F0"),
	Color("4F8BFF"),
]


func _make_mode_title(mode_title: String) -> Control:
	if LevelManager.current_mode == LevelManager.MODE_CHRONO:
		return UIFactory.make_crazy_logo_title(300.0)

	var words := mode_title.split(" ", false)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -20)

	var word_index := 0
	for word_variant: Variant in words:
		var word := str(word_variant).to_upper()
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", -2)
		for i in range(word.length()):
			var letter := _make_title_letter(word[i], word_index == 0, (word_index + i) % TITLE_LETTER_COLORS.size())
			row.add_child(letter)
		box.add_child(row)
		word_index += 1

	var underline := Control.new()
	underline.custom_minimum_size = Vector2(0, 34)
	underline.draw.connect(_draw_title_underline.bind(underline))
	box.add_child(underline)
	return box


func _make_title_letter(letter: String, white: bool, color_index: int) -> Label:
	var label := Label.new()
	label.text = letter
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 84)
	UIFactory.apply_title_font(label)
	if white:
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color("2F6EEA"))
		label.add_theme_constant_override("outline_size", 14)
		label.add_theme_color_override("font_shadow_color", Color("0D1E66"))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 6)
		label.add_theme_constant_override("shadow_outline_size", 14)
	else:
		var color: Color = TITLE_LETTER_COLORS[color_index]
		label.add_theme_color_override("font_color", color.lightened(0.15))
		label.add_theme_color_override("font_outline_color", Color("1A1F6E"))
		label.add_theme_constant_override("outline_size", 10)
		label.add_theme_color_override("font_shadow_color", Color(color.r, color.g, color.b, 0.55))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
		label.add_theme_constant_override("shadow_outline_size", 20)
	return label


func _draw_title_underline(control: Control) -> void:
	var w := control.size.x
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var steps := 32
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		points.append(Vector2(lerpf(w * 0.3, w * 0.7, t), 20.0 + sin(t * PI) * 5.0))
		if t < 0.5:
			colors.append(Color("FF4FB0").lerp(Color("FFB23D"), t * 2.0))
		else:
			colors.append(Color("FFB23D").lerp(Color("3CC8F0"), (t - 0.5) * 2.0))
	control.draw_polyline_colors(points, colors, 3.0, true)
	var dots := [[0.0, Color("FF4FB0")], [0.5, Color("FFB23D")], [1.0, Color("3CC8F0")]]
	for dot: Array in dots:
		var index := int(float(dot[0]) * float(steps))
		var color: Color = dot[1]
		control.draw_circle(points[index], 8.0, Color(color.r, color.g, color.b, 0.3))
		control.draw_circle(points[index], 4.5, color)
		control.draw_circle(points[index] + Vector2(-1.5, -1.5), 1.6, Color(1, 1, 1, 0.8))


func _make_info_card(subtitle_text: String, level_id: int) -> Control:
	var center := CenterContainer.new()
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.14, 0.45, 0.75)
	style.border_color = Color(0.45, 0.65, 1.0, 0.5)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.shadow_color = Color(0, 0, 0.2, 0.35)
	style.shadow_size = 8
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	var subtitle := UIFactory.make_light_subtitle(subtitle_text, 28)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size = Vector2(520, 0)
	box.add_child(subtitle)

	var continue_row := HBoxContainer.new()
	continue_row.alignment = BoxContainer.ALIGNMENT_CENTER
	continue_row.add_theme_constant_override("separation", 12)
	box.add_child(continue_row)

	var icon := Control.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(_draw_continue_icon.bind(icon))
	continue_row.add_child(icon)

	var info := UIFactory.make_subtitle("Continuar: Nivel %d" % level_id, 30)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", GamePalette.MENU_VALUE)
	UIFactory.apply_font(info, true)
	continue_row.add_child(info)
	return center


func _draw_continue_icon(icon: Control) -> void:
	var c := icon.size * 0.5
	var yellow := Color("FFE45E")
	var dark := Color("C48A00")
	icon.draw_line(c + Vector2(-8, -14), c + Vector2(-8, 14), dark, 3.2, true)
	icon.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-6, -14),
		c + Vector2(16, -7),
		c + Vector2(-6, 0),
	]), yellow)
	icon.draw_circle(c + Vector2(-8, 14), 2.8, dark)


func _play_intro(nodes: Array) -> void:
	UIFactory.play_enter_animation(nodes, 0.05)


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

	_confirm_panel = UIFactory.make_glass_panel()
	_confirm_panel.custom_minimum_size = Vector2(440, 0)
	_confirm_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(_confirm_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(380, 0)
	_confirm_panel.add_child(box)

	_confirm_title = UIFactory.make_neon_title("¿Resetear modo?", 34)
	box.add_child(_confirm_title)

	_confirm_message = UIFactory.make_light_subtitle("", 26)
	_confirm_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_message.custom_minimum_size = Vector2(340, 0)
	box.add_child(_confirm_message)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(buttons)

	_confirm_cancel_btn = UIFactory.make_button("CANCELAR", 84)
	_confirm_cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_cancel_btn.pressed.connect(_hide_confirm_overlay)
	buttons.add_child(_confirm_cancel_btn)

	_confirm_ok_btn = UIFactory.make_button("RESETEAR", 84)
	UIFactory.set_button_icon(_confirm_ok_btn, UIFactory.ButtonIcon.RESTART, Color.WHITE)
	_confirm_ok_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_ok_btn.pressed.connect(_on_reset_ok_pressed)
	buttons.add_child(_confirm_ok_btn)

	_apply_confirm_style(false)


func _apply_confirm_style(danger: bool) -> void:
	if _confirm_panel == null:
		return
	var style := StyleBoxFlat.new()
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
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)
	if danger:
		style.bg_color = Color(_RESET_RED_DARK.r, _RESET_RED_DARK.g, _RESET_RED_DARK.b, 0.97)
		style.border_color = _RESET_RED
		style.shadow_color = Color(_RESET_RED.r, _RESET_RED.g, _RESET_RED.b, 0.35)
		if _confirm_title != null:
			_confirm_title.add_theme_color_override("font_color", _RESET_RED)
			_confirm_title.add_theme_color_override("font_outline_color", Color(0.25, 0.02, 0.02, 1.0))
		if _confirm_message != null:
			_confirm_message.add_theme_color_override("font_color", _RESET_RED)
		if _confirm_cancel_btn != null:
			UIFactory.set_button_colors(_confirm_cancel_btn, Color("8A1A1A"), _RESET_RED)
		if _confirm_ok_btn != null:
			UIFactory.set_button_colors(_confirm_ok_btn, _RESET_RED, Color.WHITE)
			UIFactory.set_button_icon(_confirm_ok_btn, UIFactory.ButtonIcon.RESTART, Color.WHITE)
	else:
		style.bg_color = Color(GamePalette.MENU_DARKEST.r, GamePalette.MENU_DARKEST.g, GamePalette.MENU_DARKEST.b, 0.96)
		style.border_color = GamePalette.MENU_YELLOW
		style.shadow_color = Color(0, 0, 0, 0.4)
		if _confirm_title != null:
			_confirm_title.add_theme_color_override("font_color", GamePalette.MENU_YELLOW)
			_confirm_title.add_theme_color_override("font_outline_color", GamePalette.MENU_TITLE_OUTLINE)
		if _confirm_message != null:
			_confirm_message.add_theme_color_override("font_color", GamePalette.MENU_TEXT_LIGHT)
		if _confirm_cancel_btn != null:
			UIFactory.set_button_colors(_confirm_cancel_btn, GamePalette.MENU_YELLOW, GamePalette.MENU_YELLOW_TEXT)
		if _confirm_ok_btn != null:
			UIFactory.set_button_colors(_confirm_ok_btn, GamePalette.ACCENT_MAGENTA, Color.WHITE)
			UIFactory.set_button_icon(_confirm_ok_btn, UIFactory.ButtonIcon.RESTART, Color.WHITE)
	_confirm_panel.add_theme_stylebox_override("panel", style)


func _show_confirm_overlay(message: String, title: String, danger: bool) -> void:
	if _confirm_overlay == null or _confirm_message == null or _confirm_title == null:
		return
	_confirm_title.text = title
	_confirm_message.text = message
	_apply_confirm_style(danger)
	_confirm_overlay.visible = true
	_confirm_overlay.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_confirm_overlay, "modulate:a", 1.0, 0.18)


func _hide_confirm_overlay() -> void:
	_confirm_step = 0
	if _confirm_overlay == null:
		return
	_confirm_overlay.visible = false


func _on_reset_pressed() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	_confirm_step = 1
	var mode_title := LevelManager.get_mode_title(LevelManager.current_mode)
	_show_confirm_overlay(
		"Esto es irreversible.\n\nSe borrará TODO de %s: progreso, estrellas, pistas, puntuación y densidad.\n\nEmpezarás de cero desde el nivel 1."
		% mode_title,
		"¿Resetear modo?",
		false
	)


func _on_reset_ok_pressed() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	if _confirm_step < 2:
		_confirm_step = 2
		_show_confirm_overlay(
			"¿Estás seguro?\n\nNo se puede deshacer. Se perderá todo el progreso de este modo.",
			"¿Estás seguro?",
			true
		)
		return
	_hide_confirm_overlay()
	var mode_id := LevelManager.current_mode
	SaveManager.reset_mode_progress(mode_id)
	LevelManager.clear_mode_cache(mode_id)
	LevelManager.set_current_level(1)
	var err := get_tree().reload_current_scene()
	if err != OK:
		push_error("ModeHub: no se pudo recargar tras reset (%s)" % error_string(err))


func _on_continue() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	var mode_id := LevelManager.current_mode
	var unlocked := SaveManager.get_last_unlocked_level(mode_id)
	var target := maxi(1, unlocked)
	LevelManager.set_mode(mode_id)
	LevelManager.set_current_level(target)
	var err := get_tree().change_scene_to_file("res://scenes/game.tscn")
	if err != OK:
		push_error("ModeHub: no se pudo abrir game.tscn (%s)" % error_string(err))


func _on_select() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")


func _on_back() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
