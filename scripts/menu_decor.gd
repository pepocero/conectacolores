extends Control

## Fondo glossy casual — lavanda, ondas suaves, orbes suaves.

var _time: float = 0.0
var _intensity: float = 1.0
var _orbs: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_rebuild()
	resized.connect(_rebuild)
	if not SettingsManager.settings_changed.is_connected(_rebuild):
		SettingsManager.settings_changed.connect(_rebuild)


func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.4, 1.6)


func _rebuild() -> void:
	_orbs.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var colors: Array[Color] = [
		GamePalette.ACCENT,
		GamePalette.BUTTON_CYAN,
		GamePalette.BUTTON_ORANGE,
		Color("FFFFFF"),
		GamePalette.ACCENT_MAGENTA,
	]
	var count := 12 if SettingsManager.fx_enabled else 6
	for i in range(count):
		_orbs.append({
			"pos": Vector2(rng.randf_range(0.06, 0.94), rng.randf_range(0.08, 0.92)),
			"color": colors[i % colors.size()],
			"radius": rng.randf_range(18.0, 42.0),
			"phase": rng.randf_range(0.0, TAU),
			"speed": rng.randf_range(0.25, 0.7),
			"drift": rng.randf_range(6.0, 16.0),
		})


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return

	draw_rect(Rect2(Vector2.ZERO, size), GamePalette.BACKGROUND, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.5)), GamePalette.BACKGROUND_ALT, true)
	draw_rect(
		Rect2(Vector2(0.0, size.y * 0.4), Vector2(size.x, size.y * 0.6)),
		GamePalette.with_alpha(GamePalette.BACKGROUND_VIOLET, 0.45),
		true
	)

	var wave_color := Color(1, 1, 1, 0.06 * _intensity)
	for band in range(4):
		var y_base := size.y * (0.2 + float(band) * 0.18)
		var points := PackedVector2Array()
		var x := 0.0
		while x <= size.x + 8.0:
			var y := y_base + sin(_time * 0.6 + x * 0.012 + float(band)) * (10.0 + float(band) * 3.0)
			points.append(Vector2(x, y))
			x += 16.0
		if points.size() >= 2:
			draw_polyline(points, wave_color, 3.0, true)

	for orb: Dictionary in _orbs:
		var center := _orb_pos(orb)
		var color: Color = orb["color"]
		var radius: float = orb["radius"]
		var pulse := 1.0 + sin(_time * 1.2 + float(orb["phase"])) * 0.06
		draw_circle(center, radius * 1.6 * pulse, Color(color.r, color.g, color.b, 0.10 * _intensity))
		draw_circle(center, radius * pulse, Color(color.r, color.g, color.b, 0.22 * _intensity))
		draw_circle(center + Vector2(-radius * 0.22, -radius * 0.25), radius * 0.2, Color(1, 1, 1, 0.35))


func _orb_pos(orb: Dictionary) -> Vector2:
	var base: Vector2 = orb["pos"]
	var phase: float = orb["phase"]
	var speed: float = orb["speed"]
	var drift: float = orb["drift"]
	var offset := Vector2(
		sin(_time * speed + phase) * drift,
		cos(_time * speed * 0.85 + phase) * drift * 0.7
	)
	return Vector2(base.x * size.x, base.y * size.y) + offset
