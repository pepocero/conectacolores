extends Control

const MenuBackground := preload("res://scripts/main_menu_background.gd")
const GlossyButton := preload("res://scripts/glossy_menu_button.gd")
const TITLE_LETTER_COLORS: Array[Color] = [
	Color("FF4FB0"),
	Color("FF8A3D"),
	Color("FFD43B"),
	Color("7BE04A"),
	Color("3DDC97"),
	Color("3CC8F0"),
	Color("4F8BFF"),
]
## Misma combinación que la palabra FÁCIL en el modo fácil (game.gd).
const FACIL_LETTER_COLORS: Array[Color] = [
	Color("FF7A18"),
	Color("FFB020"),
	Color("FFE14A"),
	Color("7BE04A"),
	Color("3DDC97"),
	Color("3CC8F0"),
	Color("4F8BFF"),
]

var _title_block: Control
var _pill: Control
var _hardcore_btn: GlossyButton
var _modes_modal: Control
var _modes_scroll: ScrollContainer
var _notice_overlay: Control
var _notice_message: Label
var _intro_nodes: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	if not _intro_nodes.is_empty():
		call_deferred("_play_intro", _intro_nodes)


func _build_ui() -> void:
	var background := MenuBackground.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	margin.add_child(vbox)

	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer_top.size_flags_stretch_ratio = 0.7
	vbox.add_child(spacer_top)

	_title_block = _make_title_block()
	vbox.add_child(_title_block)
	vbox.add_child(_gap(20))

	_pill = _make_pill("CarliniTools")
	vbox.add_child(_pill)
	vbox.add_child(_gap(36))

	var buttons_center := CenterContainer.new()
	vbox.add_child(buttons_center)

	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(480, 0)
	buttons.add_theme_constant_override("separation", 26)
	buttons_center.add_child(buttons)

	var modes_btn := _make_menu_button("MODOS", Color("FF8A1F"), Color.WHITE, GlossyButton.Icon.PLAY, Color.WHITE, 108.0)
	modes_btn.pressed.connect(_open_modes_modal)
	buttons.add_child(modes_btn)

	var settings_btn := _make_menu_button("AJUSTES", Color("9A52E6"), Color.WHITE, GlossyButton.Icon.GEAR, Color.WHITE, 92.0)
	settings_btn.pressed.connect(_open_settings)
	buttons.add_child(settings_btn)

	var exit_btn := _make_menu_button("SALIR", Color("2F8CF0"), Color.WHITE, GlossyButton.Icon.EXIT, Color.WHITE, 92.0)
	exit_btn.pressed.connect(_on_exit)
	buttons.add_child(exit_btn)

	var spacer_bottom := Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_bottom)

	_build_modes_modal()
	_build_notice_overlay()
	_refresh_progress()
	_intro_nodes = [_title_block, _pill, modes_btn, settings_btn, exit_btn]


func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	return gap


func _make_menu_button(text: String, base: Color, text_color: Color, icon: int, icon_color: Color, height: float) -> GlossyButton:
	var button := GlossyButton.new()
	button.setup(text, base, text_color, icon, icon_color, height)
	return button


func _make_title_block() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -24)

	var conecta := _make_title_label("CONECTA", 96, Color.WHITE, Color("2F6EEA"), 16)
	conecta.add_theme_color_override("font_shadow_color", Color("0D1E66"))
	conecta.add_theme_constant_override("shadow_offset_x", 0)
	conecta.add_theme_constant_override("shadow_offset_y", 7)
	conecta.add_theme_constant_override("shadow_outline_size", 16)
	box.add_child(conecta)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", -2)
	var word := "COLORES"
	for i in range(word.length()):
		var color: Color = TITLE_LETTER_COLORS[i % TITLE_LETTER_COLORS.size()]
		var letter := _make_title_label(word[i], 96, color.lightened(0.15), Color("1A1F6E"), 12)
		letter.add_theme_color_override("font_shadow_color", Color(color.r, color.g, color.b, 0.55))
		letter.add_theme_constant_override("shadow_offset_x", 0)
		letter.add_theme_constant_override("shadow_offset_y", 0)
		letter.add_theme_constant_override("shadow_outline_size", 24)
		row.add_child(letter)
	box.add_child(row)

	var underline := Control.new()
	underline.custom_minimum_size = Vector2(0, 40)
	underline.draw.connect(_draw_title_underline.bind(underline))
	box.add_child(underline)
	return box


func _make_title_label(text: String, font_size: int, color: Color, outline_color: Color, outline: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline)
	UIFactory.apply_title_font(label)
	return label


func _draw_title_underline(control: Control) -> void:
	var w := control.size.x
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var steps := 32
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		points.append(Vector2(lerpf(w * 0.3, w * 0.7, t), 24.0 + sin(t * PI) * 6.0))
		if t < 0.5:
			colors.append(Color("FF4FB0").lerp(Color("FFB23D"), t * 2.0))
		else:
			colors.append(Color("FFB23D").lerp(Color("3CC8F0"), (t - 0.5) * 2.0))
	control.draw_polyline_colors(points, colors, 3.0, true)
	var dots := [[0.0, Color("FF4FB0")], [0.5, Color("FFB23D")], [1.0, Color("3CC8F0")]]
	for dot: Array in dots:
		var index := int(float(dot[0]) * float(steps))
		var color: Color = dot[1]
		control.draw_circle(points[index], 9.0, Color(color.r, color.g, color.b, 0.3))
		control.draw_circle(points[index], 5.0, color)
		control.draw_circle(points[index] + Vector2(-1.5, -1.5), 1.8, Color(1, 1, 1, 0.8))


func _make_pill(text: String) -> Control:
	var center := CenterContainer.new()
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.16, 0.5, 0.85)
	style.border_color = Color("FF3FD0")
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 30
	style.corner_radius_top_right = 30
	style.corner_radius_bottom_left = 30
	style.corner_radius_bottom_right = 30
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(1.0, 0.25, 0.8, 0.45)
	style.shadow_size = 10
	pill.add_theme_stylebox_override("panel", style)
	center.add_child(pill)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color("FF8BEA"))
	label.add_theme_color_override("font_shadow_color", Color(1.0, 0.3, 0.85, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("shadow_outline_size", 10)
	UIFactory.apply_font(label, true)
	pill.add_child(label)
	return center


func _play_intro(nodes: Array) -> void:
	UIFactory.play_enter_animation(nodes, 0.05)


func _refresh_progress() -> void:
	if _hardcore_btn != null:
		_hardcore_btn.set_locked(not SaveManager.is_hardcore_unlocked())


func _open_modes_modal() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	_refresh_progress()
	if _modes_scroll != null:
		_modes_scroll.scroll_vertical = 0
	if _modes_modal != null:
		_modes_modal.visible = true
		_modes_modal.modulate = Color(1, 1, 1, 0)
		var tw := create_tween()
		tw.tween_property(_modes_modal, "modulate:a", 1.0, 0.18)


func _close_modes_modal() -> void:
	if _modes_modal == null or not _modes_modal.visible:
		return
	_modes_modal.visible = false
	AudioManager.play(AudioManager.Sfx.SELECT)


func _open_easy() -> void:
	_open_mode(LevelManager.MODE_EASY)


func _open_hard() -> void:
	_open_mode(LevelManager.MODE_HARD)


func _open_hardcore() -> void:
	if not SaveManager.is_hardcore_unlocked():
		AudioManager.play(AudioManager.Sfx.INVALID)
		_show_notice_overlay("Completa el nivel 20 de Difícil para desbloquear Hardcore.")
		return
	_open_mode(LevelManager.MODE_HARDCORE)


func _open_sandbox() -> void:
	_open_mode(LevelManager.MODE_SANDBOX)


func _open_chrono() -> void:
	_open_mode(LevelManager.MODE_CHRONO)


func _open_mode(mode_id: String) -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	LevelManager.set_mode(mode_id)
	SaveManager.set_last_mode(mode_id)
	get_tree().change_scene_to_file.call_deferred("res://scenes/mode_hub.tscn")


func _open_settings() -> void:
	AudioManager.play(AudioManager.Sfx.SELECT)
	# Deferred: evita crash al liberar el menú durante el callback del botón (Godot 4.2+).
	get_tree().change_scene_to_file.call_deferred("res://scenes/settings.tscn")


func _on_exit() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _close_open_overlay():
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_close_open_overlay()


func _close_open_overlay() -> bool:
	if _notice_overlay != null and _notice_overlay.visible:
		_hide_notice_overlay()
		return true
	if _modes_modal != null and _modes_modal.visible:
		_close_modes_modal()
		return true
	return false


func _build_modes_modal() -> void:
	_modes_modal = Control.new()
	_modes_modal.visible = false
	_modes_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modes_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modes_modal.z_index = 40
	add_child(_modes_modal)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.08, 0.22, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modes_modal.add_child(dim)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 40)
	root.add_theme_constant_override("margin_right", 40)
	root.add_theme_constant_override("margin_top", 36)
	root.add_theme_constant_override("margin_bottom", 40)
	_modes_modal.add_child(root)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(outer)

	# Título arriba; botones centrados en el espacio restante.
	outer.add_child(_make_modes_title())

	var mid := VBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(mid)

	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 18)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(block)

	var buttons := VBoxContainer.new()
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.custom_minimum_size = Vector2(480, 0)
	buttons.add_theme_constant_override("separation", 18)
	block.add_child(buttons)

	var easy_btn := _make_menu_button("FÁCIL", Color("FF8A1F"), Color.WHITE, GlossyButton.Icon.PLAY, Color.WHITE, 96.0)
	easy_btn.pressed.connect(_open_easy)
	buttons.add_child(easy_btn)

	var hard_btn := _make_menu_button("DIFÍCIL", Color("FFC52E"), Color("5A3410"), GlossyButton.Icon.MOUNTAIN, Color("6B3E14"), 88.0)
	hard_btn.pressed.connect(_open_hard)
	buttons.add_child(hard_btn)

	_hardcore_btn = _make_menu_button("HARDCORE", Color("8E1C2A"), Color.WHITE, GlossyButton.Icon.FLAME, Color("FFD4A8"), 88.0)
	_hardcore_btn.pressed.connect(_open_hardcore)
	buttons.add_child(_hardcore_btn)

	var sandbox_btn := _make_menu_button("SANDBOX", Color("E8B86D"), Color("4A3010"), GlossyButton.Icon.PLAY, Color("5A3818"), 88.0)
	sandbox_btn.pressed.connect(_open_sandbox)
	buttons.add_child(sandbox_btn)

	var chrono_btn := _make_menu_button("MODO CRAZY", Color("2EB8FF"), Color.WHITE, GlossyButton.Icon.PLAY, Color.WHITE, 88.0)
	var crazy_tex: Texture2D = load("res://assets/backgrounds/crazy.jpg") as Texture2D
	if crazy_tex != null:
		chrono_btn.set_fill_texture(crazy_tex)
	chrono_btn.pressed.connect(_open_chrono)
	buttons.add_child(chrono_btn)

	var close_btn := UIFactory.make_button("CERRAR", 90)
	UIFactory.set_button_colors(close_btn, GamePalette.MENU_BLUE, Color.WHITE)
	UIFactory.set_button_icon(close_btn, UIFactory.ButtonIcon.BACK, Color.WHITE)
	close_btn.pressed.connect(_close_modes_modal)
	block.add_child(close_btn)


func _make_modes_title() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", -4)
	var word := "MODOS"
	for i in range(word.length()):
		var color: Color = FACIL_LETTER_COLORS[i % FACIL_LETTER_COLORS.size()]
		var letter := _make_title_label(word[i], 78, color, Color("1A1F6E"), 12)
		letter.add_theme_color_override("font_shadow_color", Color(0.05, 0.08, 0.28, 0.75))
		letter.add_theme_constant_override("shadow_offset_x", 0)
		letter.add_theme_constant_override("shadow_offset_y", 5)
		letter.add_theme_constant_override("shadow_outline_size", 10)
		row.add_child(letter)
	box.add_child(row)

	var underline := Control.new()
	underline.custom_minimum_size = Vector2(0, 28)
	underline.draw.connect(_draw_title_underline.bind(underline))
	box.add_child(underline)
	return box


func _build_notice_overlay() -> void:
	_notice_overlay = Control.new()
	_notice_overlay.visible = false
	_notice_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_notice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_notice_overlay.z_index = 50
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
	style.bg_color = Color(0.06, 0.1, 0.28, 0.96)
	style.border_color = Color("FFC52E")
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

	var title := UIFactory.make_neon_title("Modo bloqueado", 34)
	title.add_theme_color_override("font_color", Color("FFC52E"))
	box.add_child(title)

	_notice_message = UIFactory.make_light_subtitle("", 26)
	_notice_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_message.custom_minimum_size = Vector2(320, 0)
	box.add_child(_notice_message)

	var ok_btn := UIFactory.make_button("ENTENDIDO", 84)
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
