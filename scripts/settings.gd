extends Control

## Pantalla de Ajustes (estética casual del mockup, patrones UI seguros del menú).

const TITLE_LETTER_COLORS: Array[Color] = [
	Color("1E6BFF"), # A
	Color("008CBA"), # J
	Color("E8A200"), # U
	Color("2E9B22"), # S
	Color("D01878"), # T
	Color("6B22C9"), # E
	Color("C43A12"), # S
]

const STATUS_ON := Color("B4F03A")
const STATUS_OFF := Color("A8C0E0")

var _sound_check: CheckButton
var _sound_status: Label
var _vib_check: CheckButton
var _vib_status: Label
var _fx_check: CheckButton
var _fx_status: Label
var _cb_check: CheckButton
var _cb_status: Label
var _visual_help_check: CheckButton
var _visual_help_status: Label
var _colored_board_check: CheckButton
var _colored_board_status: Label
var _board_destroy_check: CheckButton
var _board_destroy_status: Label
var _ball_boom_check: CheckButton
var _ball_boom_status: Label
var _easy_diff_value: Label
var _hard_diff_value: Label
var _sandbox_diff_value: Label
var _hardcore_diff_value: Label
var _easy_minus_btn: Button
var _easy_plus_btn: Button
var _hard_minus_btn: Button
var _hard_plus_btn: Button
var _sandbox_minus_btn: Button
var _sandbox_plus_btn: Button
var _hardcore_minus_btn: Button
var _hardcore_plus_btn: Button
var _custom_size_value: Label
var _custom_pair_value: Label
var _custom_size_minus_btn: Button
var _custom_size_plus_btn: Button
var _custom_pair_minus_btn: Button
var _custom_pair_plus_btn: Button
var _mode_mutex_hint: Label
var _custom_mutex_hint: Label
var _diff_modal: Control
var _diff_scroll: ScrollContainer
var _help_modal: Control
var _help_scroll: ScrollContainer
var _sound_modal: Control
var _effects_modal: Control
var _effects_scroll: ScrollContainer
var _progress_modal: Control
var _file_dialog: FileDialog
var _notice_overlay: Control
var _notice_message: Label
var _confirm_overlay: Control
var _confirm_message: Label
var _confirm_yes_cb: Callable


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh()


func _build_ui() -> void:
	UIFactory.attach_neon_background(self, false)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 28)
	root.add_theme_constant_override("margin_right", 28)
	root.add_theme_constant_override("margin_top", 40)
	root.add_theme_constant_override("margin_bottom", 28)
	add_child(root)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(outer)

	# Scroll solo cuando el contenido no cabe (pantallas pequeñas / tipografía grande).
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	outer.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	vbox.add_child(_make_header())

	var sound_btn := UIFactory.make_button("SONIDO", 90)
	UIFactory.set_button_colors(sound_btn, GamePalette.MENU_BLUE, Color.WHITE)
	UIFactory.set_button_icon(sound_btn, UIFactory.ButtonIcon.SOUND, Color.WHITE)
	sound_btn.pressed.connect(_open_sound_modal)
	vbox.add_child(sound_btn)

	var effects_btn := UIFactory.make_button("EFECTOS", 90)
	UIFactory.set_button_colors(effects_btn, GamePalette.ACCENT_MAGENTA, Color.WHITE)
	UIFactory.set_button_icon(effects_btn, UIFactory.ButtonIcon.SPARKLE, Color.WHITE)
	effects_btn.pressed.connect(_open_effects_modal)
	vbox.add_child(effects_btn)

	var diff_btn := UIFactory.make_button("DIFICULTAD", 90)
	UIFactory.set_button_colors(diff_btn, GamePalette.MENU_ORANGE, Color.WHITE)
	UIFactory.set_button_icon(diff_btn, UIFactory.ButtonIcon.MOUNTAIN, Color.WHITE)
	diff_btn.pressed.connect(_open_difficulty_modal)
	vbox.add_child(diff_btn)

	var help_btn := UIFactory.make_button("AYUDA", 90)
	UIFactory.set_button_colors(help_btn, GamePalette.MENU_YELLOW, GamePalette.MENU_YELLOW_TEXT)
	UIFactory.set_button_icon(help_btn, UIFactory.ButtonIcon.BULB, GamePalette.MENU_YELLOW_TEXT)
	help_btn.pressed.connect(_open_help_modal)
	vbox.add_child(help_btn)

	var progress_btn := UIFactory.make_button("BACKUP", 90)
	UIFactory.set_button_colors(progress_btn, GamePalette.MENU_PURPLE, Color.WHITE)
	UIFactory.set_button_icon(progress_btn, UIFactory.ButtonIcon.GRID, Color.WHITE)
	progress_btn.pressed.connect(_open_progress_modal)
	vbox.add_child(progress_btn)

	var back := UIFactory.make_button("VOLVER", 90)
	UIFactory.set_button_colors(back, GamePalette.MENU_BLUE, Color.WHITE)
	UIFactory.set_button_icon(back, UIFactory.ButtonIcon.BACK, Color.WHITE)
	back.pressed.connect(_on_back)
	outer.add_child(back)

	_sound_modal = _make_sound_modal()
	add_child(_sound_modal)
	_effects_modal = _make_effects_modal()
	add_child(_effects_modal)
	_diff_modal = _make_difficulty_modal()
	add_child(_diff_modal)
	_help_modal = _make_help_modal()
	add_child(_help_modal)
	_progress_modal = _make_progress_modal()
	add_child(_progress_modal)
	_build_file_dialog()
	_build_notice_overlay()
	_build_confirm_overlay()


func _make_header() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", -2)
	var text := "AJUSTES"
	for i in range(text.length()):
		row.add_child(_make_title_letter(text[i], i % TITLE_LETTER_COLORS.size()))
	box.add_child(row)

	var underline := Control.new()
	underline.custom_minimum_size = Vector2(0, 28)
	underline.draw.connect(_draw_title_underline.bind(underline))
	box.add_child(underline)

	var subtitle := UIFactory.make_light_subtitle("Personaliza tu experiencia", 28)
	box.add_child(subtitle)
	return box


func _make_title_letter(letter: String, color_index: int) -> Label:
	var label := Label.new()
	label.text = letter
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 78)

	UIFactory.apply_title_font(label)
	var color: Color = TITLE_LETTER_COLORS[color_index]
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("0A1240"))
	label.add_theme_constant_override("outline_size", 12)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.05, 0.18, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 4)
	label.add_theme_constant_override("shadow_outline_size", 8)
	return label


func _draw_title_underline(control: Control) -> void:
	var w := control.size.x
	if w < 8.0:
		return
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var steps := 28
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		points.append(Vector2(lerpf(w * 0.28, w * 0.72, t), 14.0 + sin(t * PI) * 3.5))
		if t < 0.5:
			colors.append(Color("FF4FB0").lerp(Color("FFB23D"), t * 2.0))
		else:
			colors.append(Color("FFB23D").lerp(Color("3CC8F0"), (t - 0.5) * 2.0))
	control.draw_polyline_colors(points, colors, 3.0, true)
	var dots := [0.0, 0.5, 1.0]
	var dot_colors := [Color("FF4FB0"), Color("FFB23D"), Color("3CC8F0")]
	for i in range(dots.size()):
		var index := int(dots[i] * float(steps))
		var color: Color = dot_colors[i]
		control.draw_circle(points[index], 7.0, Color(color.r, color.g, color.b, 0.3))
		control.draw_circle(points[index], 4.0, color)
		control.draw_circle(points[index] + Vector2(-1.2, -1.2), 1.4, Color(1, 1, 1, 0.85))


func _make_toggle_row(title: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 96)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	# Texto a la izquierda (título + estado); interruptor fijo a la derecha.
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 2)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)

	var name_label := Label.new()
	name_label.text = title
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	UIFactory.apply_font(name_label, true)
	texts.add_child(name_label)

	var status := Label.new()
	status.text = "DESACTIVADO"
	# Ancho fijo para el estado más largo; no empuja el layout al togglear.
	status.custom_minimum_size = Vector2(180, 0)
	status.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	status.add_theme_font_size_override("font_size", 22)
	status.add_theme_color_override("font_color", STATUS_OFF)
	UIFactory.apply_font(status, true)
	texts.add_child(status)

	# Host con tamaño reservado para el CheckButton ampliado (scale no afecta al layout).
	var check_host := Control.new()
	check_host.custom_minimum_size = Vector2(120, 68)
	check_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	check_host.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(check_host)

	var check := CheckButton.new()
	check.scale = Vector2(2.2, 2.2)
	check.position = Vector2(2, 2)
	check_host.add_child(check)

	return {"root": row, "status": status, "check": check}


func _make_diff_stepper_row(title: String, value_width: float = 56.0) -> Dictionary:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 96)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_label := Label.new()
	name_label.text = title
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIFactory.apply_font(name_label, true)
	row.add_child(name_label)

	var stepper := HBoxContainer.new()
	stepper.alignment = BoxContainer.ALIGNMENT_CENTER
	stepper.add_theme_constant_override("separation", 8)
	stepper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stepper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stepper)

	var minus := _make_stepper_button("−")
	minus.gui_input.connect(_on_diff_stepper_gui_input.bind(minus))
	stepper.add_child(minus)

	var value := Label.new()
	value.text = "0"
	value.custom_minimum_size = Vector2(value_width, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 34)
	value.add_theme_color_override("font_color", STATUS_ON)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIFactory.apply_font(value, true)
	stepper.add_child(value)

	var plus := _make_stepper_button("+")
	plus.gui_input.connect(_on_diff_stepper_gui_input.bind(plus))
	stepper.add_child(plus)

	return {"root": row, "value": value, "minus": minus, "plus": plus}


func _make_stepper_button(symbol: String) -> Button:
	var button := Button.new()
	button.text = symbol
	button.custom_minimum_size = Vector2(60, 60)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 40)
	UIFactory.apply_font(button, true)
	UIFactory.set_button_colors(button, GamePalette.MENU_YELLOW, GamePalette.MENU_YELLOW_TEXT)
	return button


func _make_section_modal_shell(title_text: String, z: int) -> Dictionary:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	overlay.z_index = z

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.08, 0.22, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 28)
	root.add_theme_constant_override("margin_right", 28)
	root.add_theme_constant_override("margin_top", 40)
	root.add_theme_constant_override("margin_bottom", 28)
	overlay.add_child(root)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 16)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(outer)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color("0A1240"))
	title.add_theme_constant_override("outline_size", 10)
	UIFactory.apply_title_font(title)
	outer.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.scroll_deadzone = 16
	outer.add_child(scroll)

	var panel := UIFactory.make_glass_panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	# ScrollContainer no estira al hijo: forzar ancho completo del modal.
	var sync_panel_width := func() -> void:
		if is_instance_valid(panel) and is_instance_valid(scroll):
			panel.custom_minimum_size.x = scroll.size.x
	scroll.resized.connect(sync_panel_width)
	panel.ready.connect(sync_panel_width)

	return {"overlay": overlay, "outer": outer, "scroll": scroll, "box": box}


func _make_sound_modal() -> Control:
	var shell := _make_section_modal_shell("SONIDO", 78)
	var overlay: Control = shell["overlay"]
	var outer: VBoxContainer = shell["outer"]
	var box: VBoxContainer = shell["box"]

	var sound := _make_toggle_row("Sonido")
	_sound_status = sound["status"]
	_sound_check = sound["check"]
	_sound_check.toggled.connect(_on_sound_toggled)
	box.add_child(sound["root"])

	var vib := _make_toggle_row("Vibración")
	_vib_status = vib["status"]
	_vib_check = vib["check"]
	_vib_check.toggled.connect(_on_vibration_toggled)
	box.add_child(vib["root"])

	var close_btn := UIFactory.make_button("CERRAR", 90)
	UIFactory.set_button_colors(close_btn, GamePalette.MENU_BLUE, Color.WHITE)
	UIFactory.set_button_icon(close_btn, UIFactory.ButtonIcon.BACK, Color.WHITE)
	close_btn.pressed.connect(_close_sound_modal)
	outer.add_child(close_btn)
	return overlay


func _make_effects_modal() -> Control:
	var shell := _make_section_modal_shell("EFECTOS", 79)
	var overlay: Control = shell["overlay"]
	var outer: VBoxContainer = shell["outer"]
	var box: VBoxContainer = shell["box"]
	_effects_scroll = shell["scroll"]

	var fx := _make_toggle_row("Efectos visuales")
	_fx_status = fx["status"]
	_fx_check = fx["check"]
	_fx_check.toggled.connect(_on_fx_toggled)
	box.add_child(fx["root"])

	var cb := _make_toggle_row("Modo Daltonismo")
	_cb_status = cb["status"]
	_cb_check = cb["check"]
	_cb_check.toggled.connect(_on_colorblind_toggled)
	box.add_child(cb["root"])

	var visual_help := _make_toggle_row("Ayuda visual")
	_visual_help_status = visual_help["status"]
	_visual_help_check = visual_help["check"]
	_visual_help_check.toggled.connect(_on_visual_help_toggled)
	box.add_child(visual_help["root"])

	var colored_board := _make_toggle_row("Tablero con colores")
	_colored_board_status = colored_board["status"]
	_colored_board_check = colored_board["check"]
	_colored_board_check.toggled.connect(_on_colored_board_toggled)
	box.add_child(colored_board["root"])

	var board_destroy := _make_toggle_row("Explotar tablero")
	_board_destroy_status = board_destroy["status"]
	_board_destroy_check = board_destroy["check"]
	_board_destroy_check.toggled.connect(_on_board_destroy_toggled)
	box.add_child(board_destroy["root"])

	var ball_boom := _make_toggle_row("Explosión de bolas")
	_ball_boom_status = ball_boom["status"]
	_ball_boom_check = ball_boom["check"]
	_ball_boom_check.toggled.connect(_on_ball_boom_toggled)
	box.add_child(ball_boom["root"])

	var close_btn := UIFactory.make_button("CERRAR", 90)
	UIFactory.set_button_colors(close_btn, GamePalette.MENU_BLUE, Color.WHITE)
	UIFactory.set_button_icon(close_btn, UIFactory.ButtonIcon.BACK, Color.WHITE)
	close_btn.pressed.connect(_close_effects_modal)
	outer.add_child(close_btn)
	return overlay


func _make_progress_modal() -> Control:
	var shell := _make_section_modal_shell("BACKUP", 80)
	var overlay: Control = shell["overlay"]
	var outer: VBoxContainer = shell["outer"]
	var box: VBoxContainer = shell["box"]

	var hint := UIFactory.make_light_subtitle(
		"Guarda una copia del progreso en un archivo JSON. Tras reinstalar, impórtala para recuperarlo.",
		24
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	var export_btn := UIFactory.make_button("EXPORTAR COPIA", 90)
	UIFactory.set_button_colors(export_btn, GamePalette.MENU_ORANGE, Color.WHITE)
	export_btn.pressed.connect(_on_export_backup_pressed)
	box.add_child(export_btn)

	var import_btn := UIFactory.make_button("IMPORTAR COPIA", 90)
	UIFactory.set_button_colors(import_btn, GamePalette.MENU_BLUE, Color.WHITE)
	import_btn.pressed.connect(_on_import_backup_pressed)
	box.add_child(import_btn)

	var close_btn := UIFactory.make_button("CERRAR", 90)
	UIFactory.set_button_colors(close_btn, GamePalette.MENU_BLUE, Color.WHITE)
	UIFactory.set_button_icon(close_btn, UIFactory.ButtonIcon.BACK, Color.WHITE)
	close_btn.pressed.connect(_close_progress_modal)
	outer.add_child(close_btn)
	return overlay


func _build_file_dialog() -> void:
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = true
	_file_dialog.filters = PackedStringArray(["*.json ; JSON"])
	_file_dialog.visible = false
	_file_dialog.file_selected.connect(_on_backup_file_selected)
	add_child(_file_dialog)


func _build_notice_overlay() -> void:
	var built := _make_simple_dialog_shell("Aviso", false)
	_notice_overlay = built["overlay"]
	_notice_message = built["message"]
	var ok_btn: Button = built["ok_btn"]
	ok_btn.text = "ENTENDIDO"
	ok_btn.pressed.connect(_hide_notice_overlay)
	add_child(_notice_overlay)


func _build_confirm_overlay() -> void:
	var built := _make_simple_dialog_shell("Confirmar", true)
	_confirm_overlay = built["overlay"]
	_confirm_message = built["message"]
	var yes_btn: Button = built["yes_btn"]
	var no_btn: Button = built["no_btn"]
	yes_btn.pressed.connect(_on_confirm_yes)
	no_btn.pressed.connect(_hide_confirm_overlay)
	add_child(_confirm_overlay)


func _make_simple_dialog_shell(title_text: String, with_confirm: bool) -> Dictionary:
	var overlay := Control.new()
	overlay.visible = false
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 110

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.08, 0.28, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.1, 0.28, 0.96)
	style.border_color = Color("FFC52E")
	style.set_border_width_all(4)
	style.set_corner_radius_all(28)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var title := UIFactory.make_neon_title(title_text, 34)
	title.add_theme_color_override("font_color", Color("FFC52E"))
	box.add_child(title)

	var message := UIFactory.make_light_subtitle("", 26)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.custom_minimum_size = Vector2(320, 0)
	box.add_child(message)

	var out := {"overlay": overlay, "message": message, "ok_btn": null, "yes_btn": null, "no_btn": null}
	if with_confirm:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		var no_btn := UIFactory.make_button("CANCELAR", 84)
		UIFactory.set_button_colors(no_btn, GamePalette.MENU_BLUE, Color.WHITE)
		no_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(no_btn)
		var yes_btn := UIFactory.make_orange_button("IMPORTAR", 84)
		yes_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(yes_btn)
		out["no_btn"] = no_btn
		out["yes_btn"] = yes_btn
	else:
		var ok_btn := UIFactory.make_button("ENTENDIDO", 84)
		ok_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(ok_btn)
		out["ok_btn"] = ok_btn
	return out


func _open_progress_modal() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	if _progress_modal != null:
		_progress_modal.visible = true


func _close_progress_modal() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	if _progress_modal != null:
		_progress_modal.visible = false


func _on_export_backup_pressed() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	if _file_dialog == null:
		return
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.title = "Exportar copia de progreso"
	_file_dialog.current_file = "conecta_colores_backup.json"
	_file_dialog.popup_centered_ratio(0.7)


func _on_import_backup_pressed() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	_show_confirm_overlay(
		"Se reemplazará el progreso actual por el del archivo. ¿Continuar?",
		_open_import_file_dialog
	)


func _open_import_file_dialog() -> void:
	if _file_dialog == null:
		return
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.title = "Importar copia de progreso"
	_file_dialog.current_file = ""
	_file_dialog.popup_centered_ratio(0.7)


func _on_backup_file_selected(path: String) -> void:
	if _file_dialog == null:
		return
	if _file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		var err := SaveManager.export_backup_to_path(path)
		if err.is_empty():
			_show_notice_overlay("Copia guardada correctamente.")
		else:
			_show_notice_overlay(err)
	else:
		var err := SaveManager.import_backup_from_path(path)
		if err.is_empty():
			_show_notice_overlay("Progreso restaurado correctamente.")
			_refresh()
		else:
			_show_notice_overlay(err)


func _show_notice_overlay(message: String) -> void:
	if _notice_overlay == null or _notice_message == null:
		return
	_notice_message.text = message
	_notice_overlay.visible = true


func _hide_notice_overlay() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	if _notice_overlay != null:
		_notice_overlay.visible = false


func _show_confirm_overlay(message: String, on_yes: Callable) -> void:
	if _confirm_overlay == null or _confirm_message == null:
		return
	_confirm_message.text = message
	_confirm_yes_cb = on_yes
	_confirm_overlay.visible = true


func _hide_confirm_overlay() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	_confirm_yes_cb = Callable()
	if _confirm_overlay != null:
		_confirm_overlay.visible = false


func _on_confirm_yes() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	var cb := _confirm_yes_cb
	_hide_confirm_overlay()
	if cb.is_valid():
		cb.call()


func _open_sound_modal() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	if _sound_modal != null:
		_sound_modal.visible = true
	_refresh()


func _close_sound_modal() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	if _sound_modal != null:
		_sound_modal.visible = false


func _open_effects_modal() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	if _effects_modal != null:
		_effects_modal.visible = true
	if _effects_scroll != null:
		_effects_scroll.scroll_vertical = 0
	_refresh()


func _close_effects_modal() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	if _effects_modal != null:
		_effects_modal.visible = false


func _make_difficulty_modal() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	overlay.z_index = 80

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.08, 0.22, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 28)
	root.add_theme_constant_override("margin_right", 28)
	root.add_theme_constant_override("margin_top", 40)
	root.add_theme_constant_override("margin_bottom", 28)
	overlay.add_child(root)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 16)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(outer)

	var title := Label.new()
	title.text = "DIFICULTAD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color("0A1240"))
	title.add_theme_constant_override("outline_size", 10)
	UIFactory.apply_title_font(title)
	outer.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.scroll_deadzone = 16
	outer.add_child(scroll)
	_diff_scroll = scroll

	var panel := UIFactory.make_glass_panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_diff_content_gui_input)
	scroll.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	var easy_diff := _make_diff_stepper_row("Modo Fácil")
	_easy_diff_value = easy_diff["value"]
	_easy_minus_btn = easy_diff["minus"]
	_easy_plus_btn = easy_diff["plus"]
	_easy_minus_btn.pressed.connect(_on_easy_diff_delta.bind(-1))
	_easy_plus_btn.pressed.connect(_on_easy_diff_delta.bind(1))
	box.add_child(easy_diff["root"])

	var hard_diff := _make_diff_stepper_row("Modo Difícil")
	_hard_diff_value = hard_diff["value"]
	_hard_minus_btn = hard_diff["minus"]
	_hard_plus_btn = hard_diff["plus"]
	_hard_minus_btn.pressed.connect(_on_hard_diff_delta.bind(-1))
	_hard_plus_btn.pressed.connect(_on_hard_diff_delta.bind(1))
	box.add_child(hard_diff["root"])

	var hardcore_diff := _make_diff_stepper_row("Modo Hardcore")
	_hardcore_diff_value = hardcore_diff["value"]
	_hardcore_minus_btn = hardcore_diff["minus"]
	_hardcore_plus_btn = hardcore_diff["plus"]
	_hardcore_minus_btn.pressed.connect(_on_hardcore_diff_delta.bind(-1))
	_hardcore_plus_btn.pressed.connect(_on_hardcore_diff_delta.bind(1))
	box.add_child(hardcore_diff["root"])

	var sandbox_diff := _make_diff_stepper_row("Sandbox")
	_sandbox_diff_value = sandbox_diff["value"]
	_sandbox_minus_btn = sandbox_diff["minus"]
	_sandbox_plus_btn = sandbox_diff["plus"]
	_sandbox_minus_btn.pressed.connect(_on_sandbox_diff_delta.bind(-1))
	_sandbox_plus_btn.pressed.connect(_on_sandbox_diff_delta.bind(1))
	box.add_child(sandbox_diff["root"])

	_mode_mutex_hint = _make_mutex_hint("Vuelve a Auto para usar el extra por modo.")
	box.add_child(_mode_mutex_hint)

	var custom_title := Label.new()
	custom_title.text = "Personalizar"
	custom_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	custom_title.add_theme_font_size_override("font_size", 30)
	custom_title.add_theme_color_override("font_color", GamePalette.MENU_YELLOW)
	custom_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIFactory.apply_font(custom_title, true)
	box.add_child(custom_title)

	_custom_mutex_hint = _make_mutex_hint("Quita el extra de modo para personalizar.")
	box.add_child(_custom_mutex_hint)

	var size_diff := _make_diff_stepper_row("Tablero", 120.0)
	_custom_size_value = size_diff["value"]
	_custom_size_minus_btn = size_diff["minus"]
	_custom_size_plus_btn = size_diff["plus"]
	_custom_size_minus_btn.pressed.connect(_on_custom_size_delta.bind(-1))
	_custom_size_plus_btn.pressed.connect(_on_custom_size_delta.bind(1))
	box.add_child(size_diff["root"])

	var pair_diff := _make_diff_stepper_row("Parejas", 120.0)
	_custom_pair_value = pair_diff["value"]
	_custom_pair_minus_btn = pair_diff["minus"]
	_custom_pair_plus_btn = pair_diff["plus"]
	_custom_pair_minus_btn.pressed.connect(_on_custom_pair_delta.bind(-1))
	_custom_pair_plus_btn.pressed.connect(_on_custom_pair_delta.bind(1))
	box.add_child(pair_diff["root"])

	var close_btn := UIFactory.make_button("CERRAR", 90)
	UIFactory.set_button_colors(close_btn, GamePalette.MENU_BLUE, Color.WHITE)
	UIFactory.set_button_icon(close_btn, UIFactory.ButtonIcon.BACK, Color.WHITE)
	close_btn.pressed.connect(_close_difficulty_modal)
	outer.add_child(close_btn)
	return overlay


func _open_difficulty_modal() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	if _diff_modal != null:
		_diff_modal.visible = true
	if _diff_scroll != null:
		_diff_scroll.scroll_vertical = 0
	_refresh()


func _close_difficulty_modal() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	if _diff_modal != null:
		_diff_modal.visible = false


func _make_help_modal() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	overlay.z_index = 81

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.08, 0.22, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 28)
	root.add_theme_constant_override("margin_right", 28)
	root.add_theme_constant_override("margin_top", 40)
	root.add_theme_constant_override("margin_bottom", 28)
	overlay.add_child(root)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 16)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(outer)

	var title := Label.new()
	title.text = "AYUDA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color("0A1240"))
	title.add_theme_constant_override("outline_size", 10)
	UIFactory.apply_title_font(title)
	outer.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# En móvil el PanelContainer se traga el arrastre; el umbral ayuda al ScrollContainer.
	scroll.scroll_deadzone = 16
	outer.add_child(scroll)
	_help_scroll = scroll

	var panel := UIFactory.make_glass_panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# STOP + reenvío de ScreenDrag: si el panel es IGNORE, el toque cae al overlay y no hay scroll.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_help_content_gui_input)
	scroll.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	_add_help_block(box, "Sonido", "Activa o silencia la música y los efectos de sonido.")
	_add_help_block(box, "Vibración", "Si está activa, el teléfono vibra al conectar una pareja o al fallar un movimiento.")
	_add_help_block(box, "Efectos visuales", "Son las animaciones de fondo (burbujas, destellos, etc.). Si el juego va lento, desactívalos.")
	_add_help_block(
		box,
		"Modo Daltonismo",
		"Cambia los colores para que se distingan mejor y dibuja una figura distinta en cada color (círculo, cuadrado, estrella…)."
	)
	_add_help_block(
		box,
		"Ayuda visual",
		"Al tocar una bola, su pareja del mismo color parpadea para que la encuentres antes de trazar el camino."
	)
	_add_help_block(
		box,
		"Dificultad",
		"Hay dos formas de subir la dificultad, y no se pueden usar a la vez.\n\nExtra por modo (Fácil, Difícil, Hardcore y Sandbox): cada uno tiene su propio 0/+1/+2 encima de la curva. El 10 sigue siendo el 10, pero más exigente. +1 agranda el tablero y añade una pareja (en Sandbox, una pareja de piedras). +2 lo hace otra vez.\n\nPersonalizar: eliges el tamaño exacto de la rejilla (Auto o N×N) y cuántas parejas de bolas quieres (Auto o un número; 4 parejas son 8 bolas). Si lo dejas en Auto, el nivel sigue la curva. Si eliges un tamaño o unas parejas, todos los niveles usan eso. En Sandbox el tablero no aplica; las parejas sí.\n\nSi un modo está en +1 o +2, Personalizar se bloquea. Si personalizas el tablero o las parejas, los extras de modo vuelven a 0 y se bloquean."
	)
	_add_help_block(
		box,
		"Modo Hardcore",
		"Es otro modo de campaña, aparte de Fácil y Difícil. No se cruza con Personalizar: si usas el extra +1/+2 de Hardcore, Personalizar se bloquea, y al revés. Se desbloquea al completar el nivel 20 de Difícil. Tiene más parejas por casilla y el tablero más lleno, pero los niveles siguen siendo resolubles."
	)
	_add_help_block(
		box,
		"Sandbox",
		"Une cada pareja de rocas del mismo color con un surco a mano alzada, sin rejilla. Los surcos no pueden cruzarse. Cada nivel tiene una solución sin cruces."
	)
	_add_help_block(box, "Progreso", "Se guarda solo en este dispositivo. No hace falta cuenta ni internet.")

	var close_btn := UIFactory.make_button("CERRAR", 90)
	UIFactory.set_button_colors(close_btn, GamePalette.MENU_BLUE, Color.WHITE)
	UIFactory.set_button_icon(close_btn, UIFactory.ButtonIcon.BACK, Color.WHITE)
	close_btn.pressed.connect(_close_help_modal)
	outer.add_child(close_btn)
	return overlay


func _add_help_block(parent: Control, heading: String, body: String) -> void:
	var head := Label.new()
	head.text = heading
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_theme_font_size_override("font_size", 30)
	head.add_theme_color_override("font_color", GamePalette.MENU_YELLOW)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIFactory.apply_font(head, true)
	parent.add_child(head)

	var text := Label.new()
	text.text = body
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_size_override("font_size", 26)
	text.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 0.95))
	UIFactory.apply_font(text, false)
	parent.add_child(text)


func _on_diff_stepper_gui_input(event: InputEvent, button: Button) -> void:
	if _diff_scroll == null or not is_instance_valid(_diff_scroll):
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			button.set_meta("did_scroll", false)
		elif bool(button.get_meta("did_scroll", false)):
			button.set_meta("did_scroll", false)
			button.set_pressed_no_signal(false)
			button.release_focus()
			accept_event()
		return
	if not (event is InputEventScreenDrag):
		return
	var drag := event as InputEventScreenDrag
	if absf(drag.relative.y) < 0.5 and absf(drag.relative.x) < 0.5:
		return
	button.set_meta("did_scroll", true)
	_scroll_container_by(_diff_scroll, -drag.relative.y)
	button.set_pressed_no_signal(false)
	button.release_focus()
	accept_event()


func _on_diff_content_gui_input(event: InputEvent) -> void:
	_handle_modal_scroll_input(event, _diff_scroll)


func _on_help_content_gui_input(event: InputEvent) -> void:
	_handle_modal_scroll_input(event, _help_scroll)


func _handle_modal_scroll_input(event: InputEvent, scroll: ScrollContainer) -> void:
	if scroll == null or not is_instance_valid(scroll):
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed:
			return
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_container_by(scroll, -56)
			accept_event()
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_container_by(scroll, 56)
			accept_event()
		return
	if not (event is InputEventScreenDrag):
		return
	var drag := event as InputEventScreenDrag
	if absf(drag.relative.y) < 0.5 and absf(drag.relative.x) < 0.5:
		return
	_scroll_container_by(scroll, -drag.relative.y)
	accept_event()


func _scroll_container_by(scroll: ScrollContainer, delta_y: float) -> void:
	var bar := scroll.get_v_scroll_bar()
	var max_v := 0
	if bar != null:
		max_v = int(bar.max_value - bar.page)
	scroll.scroll_vertical = clampi(scroll.scroll_vertical + int(delta_y), 0, maxi(0, max_v))


func _open_help_modal() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	if _help_modal != null:
		_help_modal.visible = true
	if _help_scroll != null:
		_help_scroll.scroll_vertical = 0


func _close_help_modal() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	if _help_modal != null:
		_help_modal.visible = false


func _set_toggle_visual(status: Label, check: CheckButton, enabled: bool, on_text: String, off_text: String) -> void:
	if status != null:
		status.text = on_text if enabled else off_text
		status.add_theme_color_override("font_color", STATUS_ON if enabled else STATUS_OFF)
	if check != null and check.button_pressed != enabled:
		check.set_pressed_no_signal(enabled)


func _on_sound_toggled(on: bool) -> void:
	SettingsManager.set_sound(on)
	_refresh()
	if on:
		AudioManager.play(AudioManager.Sfx.SELECT)


func _on_vibration_toggled(on: bool) -> void:
	SettingsManager.set_vibration(on)
	_refresh()
	if on:
		AudioManager.vibrate(30)


func _on_fx_toggled(on: bool) -> void:
	SettingsManager.set_fx(on)
	_refresh()
	AudioManager.play(AudioManager.Sfx.SELECT)


func _on_colorblind_toggled(on: bool) -> void:
	SettingsManager.set_colorblind(on)
	_refresh()
	AudioManager.play(AudioManager.Sfx.SELECT)


func _on_visual_help_toggled(on: bool) -> void:
	SettingsManager.set_visual_help(on)
	_refresh()
	AudioManager.play(AudioManager.Sfx.SELECT)


func _on_colored_board_toggled(on: bool) -> void:
	SettingsManager.set_colored_board(on)
	_refresh()
	AudioManager.play(AudioManager.Sfx.SELECT)


func _on_board_destroy_toggled(on: bool) -> void:
	SettingsManager.set_board_destroy(on)
	_refresh()
	AudioManager.play(AudioManager.Sfx.SELECT)


func _on_ball_boom_toggled(on: bool) -> void:
	SettingsManager.set_ball_boom(on)
	_refresh()
	AudioManager.play(AudioManager.Sfx.SELECT)


func _on_easy_diff_delta(delta: int) -> void:
	_change_diff_bonus("easy", delta)


func _on_hard_diff_delta(delta: int) -> void:
	_change_diff_bonus("hard", delta)


func _on_sandbox_diff_delta(delta: int) -> void:
	_change_diff_bonus("sandbox", delta)


func _on_hardcore_diff_delta(delta: int) -> void:
	_change_diff_bonus("hardcore", delta)


func _change_diff_bonus(mode_id: String, delta: int) -> void:
	if SettingsManager.is_custom_active() and delta > 0:
		return
	var current := SettingsManager.get_difficulty_bonus(mode_id)
	var next := clampi(current + delta, 0, 2)
	if next == current:
		return
	SettingsManager.set_difficulty_bonus(mode_id, next)
	_refresh()
	AudioManager.play(AudioManager.Sfx.SELECT)


func _on_custom_size_delta(delta: int) -> void:
	if SettingsManager.has_mode_multiplier() and delta > 0:
		return
	var current := SettingsManager.get_custom_grid_size()
	var next := current
	if delta > 0:
		if current <= 0:
			var pairs := SettingsManager.get_custom_pair_count()
			next = LevelGenerator.CUSTOM_GRID_MIN
			if pairs > 0:
				next = maxi(next, LevelGenerator.min_grid_for_pairs(pairs))
		else:
			next = current + 1
	else:
		if current <= LevelGenerator.CUSTOM_GRID_MIN:
			next = 0
		else:
			next = current - 1
	next = LevelGenerator.clamp_custom_grid(next)
	if next == current:
		return
	SettingsManager.set_custom_grid_size(next)
	_refresh()
	AudioManager.play(AudioManager.Sfx.SELECT)


func _on_custom_pair_delta(delta: int) -> void:
	if SettingsManager.has_mode_multiplier() and delta > 0:
		return
	var current := SettingsManager.get_custom_pair_count()
	var next := current
	if delta > 0:
		next = 2 if current <= 0 else current + 1
	else:
		next = 0 if current <= 2 else current - 1
	var after := LevelGenerator.clamp_custom_pairs(next, SettingsManager.get_custom_grid_size())
	if next > 0 and after != next and delta > 0:
		# Si no cabe, el setter agranda el tablero.
		after = next
	if after == current:
		return
	SettingsManager.set_custom_pair_count(after)
	_refresh()
	AudioManager.play(AudioManager.Sfx.SELECT)


func _on_back() -> void:
	if _close_open_modal():
		return
	AudioManager.play(AudioManager.Sfx.SELECT)
	get_tree().change_scene_to_file.call_deferred("res://scenes/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _close_open_modal():
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_close_open_modal()


func _close_open_modal() -> bool:
	if _help_modal != null and _help_modal.visible:
		_close_help_modal()
		return true
	if _diff_modal != null and _diff_modal.visible:
		_close_difficulty_modal()
		return true
	if _confirm_overlay != null and _confirm_overlay.visible:
		_hide_confirm_overlay()
		return true
	if _notice_overlay != null and _notice_overlay.visible:
		_hide_notice_overlay()
		return true
	if _progress_modal != null and _progress_modal.visible:
		_close_progress_modal()
		return true
	if _effects_modal != null and _effects_modal.visible:
		_close_effects_modal()
		return true
	if _sound_modal != null and _sound_modal.visible:
		_close_sound_modal()
		return true
	return false


func _refresh() -> void:
	if _sound_check != null:
		_set_toggle_visual(_sound_status, _sound_check, SettingsManager.sound_enabled, "ACTIVADO", "DESACTIVADO")
	if _vib_check != null:
		_set_toggle_visual(_vib_status, _vib_check, SettingsManager.vibration_enabled, "ACTIVADA", "DESACTIVADA")
	if _fx_check != null:
		_set_toggle_visual(_fx_status, _fx_check, SettingsManager.fx_enabled, "ACTIVADOS", "DESACTIVADOS")
	if _cb_check != null:
		_set_toggle_visual(_cb_status, _cb_check, SettingsManager.colorblind_enabled, "ACTIVADO", "DESACTIVADO")
	if _visual_help_check != null:
		_set_toggle_visual(
			_visual_help_status,
			_visual_help_check,
			SettingsManager.visual_help_enabled,
			"ACTIVADA",
			"DESACTIVADA"
		)
	if _colored_board_check != null:
		_set_toggle_visual(
			_colored_board_status,
			_colored_board_check,
			SettingsManager.colored_board_enabled,
			"ACTIVADO",
			"DESACTIVADO"
		)
	if _board_destroy_check != null:
		_set_toggle_visual(
			_board_destroy_status,
			_board_destroy_check,
			SettingsManager.board_destroy_enabled,
			"ACTIVADO",
			"DESACTIVADO"
		)
	if _ball_boom_check != null:
		_set_toggle_visual(
			_ball_boom_status,
			_ball_boom_check,
			SettingsManager.ball_boom_enabled,
			"ACTIVADA",
			"DESACTIVADA"
		)
	_refresh_diff_stepper("easy", _easy_diff_value, _easy_minus_btn, _easy_plus_btn)
	_refresh_diff_stepper("hard", _hard_diff_value, _hard_minus_btn, _hard_plus_btn)
	_refresh_diff_stepper("sandbox", _sandbox_diff_value, _sandbox_minus_btn, _sandbox_plus_btn)
	_refresh_diff_stepper("hardcore", _hardcore_diff_value, _hardcore_minus_btn, _hardcore_plus_btn)
	_refresh_custom_grid_stepper()
	_refresh_custom_pair_stepper()
	_refresh_mutex_hints()


func _refresh_diff_stepper(mode_id: String, value_label: Label, minus_btn: Button, plus_btn: Button) -> void:
	var value := SettingsManager.get_difficulty_bonus(mode_id)
	var custom_lock := SettingsManager.is_custom_active()
	if value_label != null:
		value_label.text = str(value) if value == 0 else "+%d" % value
		value_label.add_theme_color_override("font_color", STATUS_ON if value > 0 else STATUS_OFF)
	if minus_btn != null:
		minus_btn.disabled = value <= 0 or custom_lock
	if plus_btn != null:
		plus_btn.disabled = value >= 2 or custom_lock


func _refresh_custom_grid_stepper() -> void:
	var value := SettingsManager.get_custom_grid_size()
	var mode_lock := SettingsManager.has_mode_multiplier()
	if _custom_size_value != null:
		_custom_size_value.text = "Auto" if value <= 0 else "%d×%d" % [value, value]
		_custom_size_value.add_theme_color_override("font_color", STATUS_ON if value > 0 else STATUS_OFF)
	if _custom_size_minus_btn != null:
		_custom_size_minus_btn.disabled = value <= 0 or mode_lock
	if _custom_size_plus_btn != null:
		_custom_size_plus_btn.disabled = value >= LevelGenerator.CUSTOM_GRID_MAX or mode_lock


func _refresh_custom_pair_stepper() -> void:
	var value := SettingsManager.get_custom_pair_count()
	var grid := SettingsManager.get_custom_grid_size()
	var mode_lock := SettingsManager.has_mode_multiplier()
	if _custom_pair_value != null:
		_custom_pair_value.text = "Auto" if value <= 0 else str(value)
		_custom_pair_value.add_theme_color_override("font_color", STATUS_ON if value > 0 else STATUS_OFF)
	if _custom_pair_minus_btn != null:
		_custom_pair_minus_btn.disabled = value <= 0 or mode_lock
	if _custom_pair_plus_btn != null:
		var at_cap := value >= LevelGenerator.MAX_PAIRS
		if grid >= LevelGenerator.CUSTOM_GRID_MAX:
			at_cap = value >= LevelGenerator.max_pairs_for_grid(grid)
		_custom_pair_plus_btn.disabled = at_cap or mode_lock


func _refresh_mutex_hints() -> void:
	if _mode_mutex_hint != null:
		_mode_mutex_hint.visible = SettingsManager.is_custom_active()
	if _custom_mutex_hint != null:
		_custom_mutex_hint.visible = SettingsManager.has_mode_multiplier()


func _make_mutex_hint(text: String) -> Label:
	var hint := Label.new()
	hint.text = text
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 0.78))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.visible = false
	UIFactory.apply_font(hint, false)
	return hint
