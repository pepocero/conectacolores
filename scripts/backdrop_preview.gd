extends Control

## TEMPORAL: vista previa de fondos animados (1–99). Quitar cuando ya no haga falta.

const MOTIFS: Array[Dictionary] = [
	{"id": LevelBackdrop.Motif.BUBBLES, "name": "Burbujas", "levels": "1–9"},
	{"id": LevelBackdrop.Motif.RAIN, "name": "Lluvia", "levels": "10–19"},
	{"id": LevelBackdrop.Motif.BEACH, "name": "Playa", "levels": "20–29"},
	{"id": LevelBackdrop.Motif.MOUNTAIN, "name": "Montaña", "levels": "30–39"},
	{"id": LevelBackdrop.Motif.SUNSET, "name": "Nieve", "levels": "40–49"},
	{"id": LevelBackdrop.Motif.FOREST, "name": "Bosque", "levels": "50–59"},
	{"id": LevelBackdrop.Motif.DESERT, "name": "Desierto", "levels": "60–69"},
	{"id": LevelBackdrop.Motif.AURORA, "name": "Aurora", "levels": "70–79"},
	{"id": LevelBackdrop.Motif.CITY, "name": "Ciudad", "levels": "80–89"},
	{"id": LevelBackdrop.Motif.VOLCANO, "name": "Volcán", "levels": "90–99"},
]

var _index: int = 0
var _bg: Control
var _title: Label
var _counter: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_chrome()
	_show_motif(_index)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_RIGHT):
		_go(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_LEFT):
		_go(-1)
		get_viewport().set_input_as_handled()


func _build_chrome() -> void:
	var chrome := MarginContainer.new()
	chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrome.add_theme_constant_override("margin_left", 16)
	chrome.add_theme_constant_override("margin_right", 16)
	chrome.add_theme_constant_override("margin_top", 20)
	chrome.add_theme_constant_override("margin_bottom", 20)
	chrome.z_index = 400
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chrome)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.add_child(vbox)

	_title = UIFactory.make_neon_title("Fondo", 36)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_title)

	_counter = UIFactory.make_light_subtitle("1 / 10", 22)
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_counter)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(row)

	var prev_btn := UIFactory.make_button("Anterior", 64)
	UIFactory.set_button_colors(prev_btn, GamePalette.MENU_YELLOW, GamePalette.MENU_YELLOW_TEXT)
	prev_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev_btn.pressed.connect(func() -> void: _go(-1))
	row.add_child(prev_btn)

	var next_btn := UIFactory.make_orange_button("Siguiente", 64)
	next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_btn.pressed.connect(func() -> void: _go(1))
	row.add_child(next_btn)

	var menu := UIFactory.make_cyan_button("Menú", 56)
	menu.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	vbox.add_child(menu)


func _go(delta: int) -> void:
	_index = posmod(_index + delta, MOTIFS.size())
	_show_motif(_index)


func _show_motif(index: int) -> void:
	var info: Dictionary = MOTIFS[index]
	if is_instance_valid(_bg):
		_bg.queue_free()
		_bg = null
	_bg = LevelBackdrop.create(int(info["id"]))
	add_child(_bg)
	move_child(_bg, 0)
	_title.text = str(info["name"])
	_counter.text = "%d / %d  ·  Niveles %s" % [index + 1, MOTIFS.size(), str(info["levels"])]
