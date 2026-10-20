extends BgPhotoBase

## Foto de playa + brillo de olas.

var _glints: Array[Dictionary] = []


func _ready() -> void:
	photo_path = "res://assets/backgrounds/beach.jpg"
	super._ready()


func setup_fx() -> void:
	_glints.clear()
	for i in range(18):
		_glints.append({
			"x": _rng.randf_range(0.05, 0.95),
			"y": _rng.randf_range(0.45, 0.72),
			"phase": _rng.randf() * TAU,
			"r": _rng.randf_range(2.0, 5.0),
		})


func draw_fx() -> void:
	if not SettingsManager.fx_enabled:
		return
	var w := size.x
	var h := size.y
	var wave_y := h * 0.58 + sin(_time * 1.2) * h * 0.012
	draw_rect(Rect2(0, wave_y, w, 3.0), Color(1, 1, 1, 0.12), true)
	for g in _glints:
		var a := 0.15 + 0.55 * absf(sin(_time * 2.2 + float(g["phase"])))
		draw_circle(
			Vector2(float(g["x"]) * w, float(g["y"]) * h + sin(_time + float(g["phase"])) * 4.0),
			float(g["r"]),
			Color(1, 1, 0.9, a)
		)
