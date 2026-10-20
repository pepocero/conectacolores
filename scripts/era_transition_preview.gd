extends Control

## Vista previa: al completar el nivel 99 → cinemática → era Emoji (nivel 100).

const EraTransitionScript := preload("res://scripts/era_transition.gd")

var _cinematic: Control
var _stage: Control
var _space_bg: Control
var _neon_bg: Control
var _new_era_stage: Control
var _play_token: int = 0
var _chrome: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_neon_bg = UIFactory.attach_neon_background(self, false)
	_build_chrome()
	call_deferred("_play")


func _build_chrome() -> void:
	_chrome = HBoxContainer.new()
	_chrome.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_chrome.offset_top = 12
	_chrome.offset_bottom = 64
	_chrome.offset_left = 16
	_chrome.offset_right = -16
	_chrome.add_theme_constant_override("separation", 12)
	_chrome.z_index = 400
	_chrome.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_chrome)

	var replay := UIFactory.make_orange_button("Repetir animación", 52)
	replay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay.pressed.connect(_on_replay_pressed)
	_chrome.add_child(replay)

	var back := UIFactory.make_button("Menú", 52)
	UIFactory.set_button_colors(back, GamePalette.MENU_YELLOW, GamePalette.MENU_YELLOW_TEXT)
	back.custom_minimum_size.x = 140
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	_chrome.add_child(back)


func _on_replay_pressed() -> void:
	_play()


func _play() -> void:
	_play_token += 1
	var token := _play_token
	_cleanup_playback()

	if not is_instance_valid(_neon_bg):
		_neon_bg = UIFactory.attach_neon_background(self, false)
	else:
		_neon_bg.visible = true
		_neon_bg.modulate = Color(1, 1, 1, 1)

	_stage = _make_fake_board_stage(BoardTheme.EMOJI_START - 1)
	add_child(_stage)
	_ensure_chrome_on_top()

	await get_tree().process_frame
	await get_tree().process_frame
	if token != _play_token or not is_inside_tree() or not is_instance_valid(_stage):
		return

	var board: Board = _stage.get_meta("board")
	_cinematic = EraTransitionScript.new()
	_cinematic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cinematic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cinematic)
	_ensure_chrome_on_top()
	if _cinematic.has_signal("ready_for_new_board"):
		_cinematic.ready_for_new_board.connect(
			_on_ready_for_new_board.bind(_cinematic, token),
			CONNECT_ONE_SHOT
		)
	await _cinematic.play(board, _stage, _neon_bg)
	if token != _play_token:
		return
	if is_instance_valid(_cinematic):
		_cinematic.queue_free()
		_cinematic = null
	# El stage emoji ya queda visible al levantar el negro (sin segundo fade).


func _cleanup_playback() -> void:
	if is_instance_valid(_cinematic):
		_cinematic.queue_free()
		_cinematic = null
	if is_instance_valid(_stage):
		_stage.queue_free()
		_stage = null
	if is_instance_valid(_new_era_stage):
		_new_era_stage.queue_free()
		_new_era_stage = null
	if is_instance_valid(_space_bg):
		_space_bg.queue_free()
		_space_bg = null


func _ensure_chrome_on_top() -> void:
	if is_instance_valid(_chrome):
		move_child(_chrome, get_child_count() - 1)


func _on_ready_for_new_board(cinematic: Control, token: int) -> void:
	if token != _play_token:
		return
	if cinematic != null and is_instance_valid(cinematic) and cinematic.has_method("handoff_space_background"):
		var space: Control = cinematic.call("handoff_space_background")
		if space != null and is_instance_valid(space):
			_space_bg = space
			add_child(_space_bg)
			move_child(_space_bg, 0)
			if _space_bg.has_method("set_warp"):
				_space_bg.call("set_warp", 0.38)
			if is_instance_valid(_neon_bg):
				_neon_bg.visible = false

	if is_instance_valid(_stage):
		_stage.queue_free()
		_stage = null

	# Opaco bajo el negro de la cinemática: aparece junto a las estrellas al revelar.
	_new_era_stage = _make_fake_board_stage(BoardTheme.EMOJI_START)
	_new_era_stage.modulate = Color(1, 1, 1, 1)
	_new_era_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_new_era_stage)
	_ensure_chrome_on_top()
	if cinematic != null and is_instance_valid(cinematic) and cinematic.has_method("mark_new_board_ready"):
		cinematic.call("mark_new_board_ready")


func _make_fake_board_stage(level_id: int) -> Control:
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_top", 80)
	root.add_theme_constant_override("margin_bottom", 24)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 12)
	root.add_child(box)

	# Título de modo (se oscurece antes de las naves).
	var title := UIFactory.make_neon_title(
		"Era Emoji" if level_id >= BoardTheme.EMOJI_START else "Clásico",
		44
	)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)

	# Cartel azul de stats (mismo rol que en partida).
	var header := _make_preview_stats_panel(level_id)
	box.add_child(header)

	var board := Board.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(280, 280)
	box.add_child(board)
	root.set_meta("board", board)

	# Botones inferiores decorativos (también se oscurecen).
	var actions := HBoxContainer.new()
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_theme_constant_override("separation", 10)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(actions)

	var reset_btn := UIFactory.make_button("", 84)
	UIFactory.set_button_colors(reset_btn, GamePalette.MENU_YELLOW, GamePalette.MENU_YELLOW_TEXT)
	UIFactory.set_button_icon(reset_btn, UIFactory.ButtonIcon.RESTART, GamePalette.MENU_YELLOW_TEXT)
	reset_btn.custom_minimum_size = Vector2(84, 84)
	reset_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_child(reset_btn)

	var hint_btn := UIFactory.make_button("PISTA (3)", 84)
	UIFactory.set_button_colors(hint_btn, GamePalette.BUTTON_CYAN, Color("0A3A52"))
	UIFactory.set_button_icon(hint_btn, UIFactory.ButtonIcon.BULB, Color("0A3A52"))
	hint_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_child(hint_btn)

	var resolve_btn := UIFactory.make_button("RESOLVER", 84)
	UIFactory.set_button_colors(resolve_btn, GamePalette.ACCENT_MAGENTA, Color.WHITE)
	UIFactory.set_button_icon(resolve_btn, UIFactory.ButtonIcon.SPARKLE, Color.WHITE)
	resolve_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resolve_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_child(resolve_btn)

	var level: Dictionary = LevelManager.get_level(level_id)
	if level.is_empty():
		level = LevelManager.get_level(1)
	if not level.is_empty():
		level = level.duplicate(true)
		level["id"] = level_id
		board.setup_level(level)

	return root


func _make_preview_stats_panel(level_id: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	var stats := HBoxContainer.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_theme_constant_override("separation", 8)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(stats)

	stats.add_child(_make_preview_stat("NIVEL", str(level_id), Color("7BE0FF")))
	stats.add_child(_make_preview_stat("PAREJAS", "12/12", Color("FFD43B")))
	stats.add_child(_make_preview_stat("PUNTUACIÓN", "9.850", Color("A8FF7A")))
	return panel


func _make_preview_stat(caption: String, value: String, value_color: Color) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	var cap := Label.new()
	cap.text = caption
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 14)
	cap.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0, 0.85))
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(cap)
	var val := Label.new()
	val.text = value
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 26)
	val.add_theme_color_override("font_color", value_color)
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIFactory.apply_title_font(val)
	col.add_child(val)
	return col
