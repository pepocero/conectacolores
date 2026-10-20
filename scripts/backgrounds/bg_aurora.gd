extends BgPhotoBase

## Foto de aurora + cortinas verticales ondulantes.

var _stars: Array[Dictionary] = []
var _curtains: Array[Dictionary] = []


func _ready() -> void:
	photo_path = "res://assets/backgrounds/aurora.jpg"
	super._ready()


func setup_fx() -> void:
	_stars.clear()
	for i in range(40):
		_stars.append({
			"x": _rng.randf(),
			"y": _rng.randf_range(0.02, 0.4),
			"r": _rng.randf_range(0.8, 2.0),
			"phase": _rng.randf() * TAU,
		})
	_curtains.clear()
	var palette := [
		Color(0.15, 0.95, 0.45),
		Color(0.25, 0.85, 0.7),
		Color(0.35, 0.55, 1.0),
		Color(0.55, 0.35, 0.95),
		Color(0.2, 1.0, 0.55),
	]
	for i in range(9):
		_curtains.append({
			"x": 0.05 + float(i) * 0.11 + _rng.randf_range(-0.03, 0.03),
			"w": _rng.randf_range(0.045, 0.095),
			"top": _rng.randf_range(0.02, 0.12),
			"bot": _rng.randf_range(0.48, 0.68),
			"phase": _rng.randf() * TAU,
			"speed": _rng.randf_range(0.4, 0.9),
			"color": palette[i % palette.size()],
			"drift": _rng.randf_range(-0.01, 0.01),
		})


func process_fx(delta: float) -> void:
	for i in range(_curtains.size()):
		var c: Dictionary = _curtains[i]
		c["x"] = float(c["x"]) + float(c["drift"]) * delta
		if float(c["x"]) < -0.1:
			c["x"] = 1.05
		elif float(c["x"]) > 1.1:
			c["x"] = -0.05
		_curtains[i] = c


func draw_fx() -> void:
	var w := size.x
	var h := size.y
	for s in _stars:
		var a := 0.3
		if SettingsManager.fx_enabled:
			a = 0.2 + 0.55 * absf(sin(_time * 1.4 + float(s["phase"])))
		draw_circle(Vector2(float(s["x"]) * w, float(s["y"]) * h), float(s["r"]), Color(1, 1, 1, a))

	if SettingsManager.fx_enabled:
		draw_circle(Vector2(w * 0.5, h * 0.22), w * 0.42, Color(0.2, 0.7, 0.55, 0.06))

	for c in _curtains:
		_draw_curtain(c, w, h)


func _draw_curtain(c: Dictionary, w: float, h: float) -> void:
	var base_col: Color = c["color"]
	var cx := float(c["x"]) * w
	var half_w := float(c["w"]) * w * 0.5
	var y0 := float(c["top"]) * h
	var y1 := float(c["bot"]) * h
	var phase := float(c["phase"])
	var speed := float(c["speed"])
	var steps := 24
	var animate := SettingsManager.fx_enabled

	for layer in range(3):
		var layer_a := 0.13 - float(layer) * 0.03
		if not animate:
			layer_a *= 0.55
		var layer_w := half_w * (1.0 + float(layer) * 0.55)
		for i in range(1, steps + 1):
			var t := float(i) / float(steps)
			var prev_t := float(i - 1) / float(steps)
			var y := lerpf(y0, y1, t)
			var prev_y := lerpf(y0, y1, prev_t)
			var wave := 0.0
			var prev_wave := 0.0
			if animate:
				wave = sin(_time * speed + phase + t * 6.5 + float(layer)) * (8.0 + float(layer) * 4.0)
				wave += sin(_time * speed * 1.7 + phase * 1.3 + t * 11.0) * 3.5
				prev_wave = sin(_time * speed + phase + prev_t * 6.5 + float(layer)) * (8.0 + float(layer) * 4.0)
				prev_wave += sin(_time * speed * 1.7 + phase * 1.3 + prev_t * 11.0) * 3.5
			var taper := lerpf(1.0, 0.35, t * t)
			var prev_taper := lerpf(1.0, 0.35, prev_t * prev_t)
			var fade := sin(t * PI)
			var col := Color(base_col.r, base_col.g, base_col.b, layer_a * fade)
			var poly := PackedVector2Array([
				Vector2(cx + prev_wave - layer_w * prev_taper, prev_y),
				Vector2(cx + prev_wave + layer_w * prev_taper, prev_y),
				Vector2(cx + wave + layer_w * taper, y),
				Vector2(cx + wave - layer_w * taper, y),
			])
			draw_colored_polygon(poly, col)

		if layer == 0 and animate:
			var core_a := 0.2 * (0.55 + 0.45 * absf(sin(_time * speed * 1.2 + phase)))
			for i in range(0, steps, 2):
				var t := float(i) / float(steps)
				var y := lerpf(y0, y1, t)
				var wave := sin(_time * speed + phase + t * 6.5) * 8.0
				var fade := sin(t * PI)
				var seg := (y1 - y0) / float(steps) * 2.2
				draw_line(
					Vector2(cx + wave, y),
					Vector2(cx + wave, y + seg),
					Color(0.85, 1.0, 0.9, core_a * fade),
					2.2,
					true
				)
