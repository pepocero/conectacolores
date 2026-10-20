extends Control

## Pantalla de carga a pantalla completa mientras se genera un nivel.

var _label: Label
var _spinner: Control
var _spin_angle: float = 0.0
var _pulse: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	_build()
	set_process(true)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(GamePalette.MENU_DEEP_BLUE, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var glow := ColorRect.new()
	glow.color = Color(GamePalette.ACCENT.r, GamePalette.ACCENT.g, GamePalette.ACCENT.b, 0.08)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(glow)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	_spinner = Control.new()
	_spinner.custom_minimum_size = Vector2(96, 96)
	_spinner.draw.connect(_on_spinner_draw)
	box.add_child(_spinner)

	_label = UIFactory.make_neon_title("Generando nivel…", 30)
	box.add_child(_label)

	var hint := UIFactory.make_light_subtitle("Preparando un puzle resoluble", 18)
	box.add_child(hint)


func set_message(text: String) -> void:
	if _label != null:
		_label.text = text


func _process(_delta: float) -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	_spin_angle = t * 2.6
	_pulse = t * 3.2
	if _spinner != null:
		_spinner.queue_redraw()


func _on_spinner_draw() -> void:
	if _spinner == null:
		return
	var names := GamePalette.color_names()
	var level_id := LevelManager.current_level_id
	var emoji_mode := BoardTheme.uses_emoji(level_id)
	var center := _spinner.size * 0.5
	var radius := minf(_spinner.size.x, _spinner.size.y) * 0.34
	var count := mini(8, maxi(3, names.size()))
	var font := ThemeDB.fallback_font
	for i in range(count):
		var t := _spin_angle + TAU * float(i) / float(count)
		var bounce := 0.75 + 0.25 * sin(_pulse + float(i) * 0.7)
		var pos := center + Vector2(cos(t), sin(t)) * radius * bounce
		var key := names[i % names.size()]
		if emoji_mode and font != null:
			var emoji := BoardTheme.emoji_for(key)
			var font_size := int(16.0 * bounce)
			var text_size := font.get_string_size(emoji, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			_spinner.draw_string(
				font,
				pos - text_size * 0.5 + Vector2(0.0, text_size.y * 0.35),
				emoji,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size
			)
		else:
			var color := GamePalette.get_color(key)
			color.a = 0.55 + 0.45 * ((sin(_pulse + float(i)) + 1.0) * 0.5)
			_spinner.draw_circle(pos, 8.0 * bounce, color)
