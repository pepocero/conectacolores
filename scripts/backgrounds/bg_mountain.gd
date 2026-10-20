extends BgPhotoBase

## Foto de montañas + niebla en movimiento.

var _mist: Array[Dictionary] = []


func _ready() -> void:
	photo_path = "res://assets/backgrounds/mountain.jpg"
	super._ready()


func setup_fx() -> void:
	_mist.clear()
	for i in range(6):
		_mist.append({
			"x": _rng.randf(),
			"y": _rng.randf_range(0.45, 0.75),
			"w": _rng.randf_range(0.25, 0.45),
			"phase": _rng.randf() * TAU,
			"speed": _rng.randf_range(0.02, 0.05),
		})


func process_fx(delta: float) -> void:
	for i in range(_mist.size()):
		var m: Dictionary = _mist[i]
		m["x"] = fmod(float(m["x"]) + delta * float(m["speed"]) + 1.0, 1.0)
		_mist[i] = m


func draw_fx() -> void:
	var w := size.x
	var h := size.y
	for m in _mist:
		var cx := float(m["x"]) * w
		var cy := float(m["y"]) * h
		if SettingsManager.fx_enabled:
			cy += sin(_time * 0.6 + float(m["phase"])) * 8.0
		var rw := float(m["w"]) * w
		draw_circle(Vector2(cx, cy), rw * 0.55, Color(1, 1, 1, 0.08))
		draw_circle(Vector2(cx + rw * 0.25, cy + 6.0), rw * 0.4, Color(1, 1, 1, 0.06))
