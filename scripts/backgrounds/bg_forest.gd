extends BgPhotoBase

## Foto de bosque + luciérnagas.

var _bugs: Array[Dictionary] = []


func _ready() -> void:
	photo_path = "res://assets/backgrounds/forest.jpg"
	super._ready()


func setup_fx() -> void:
	_bugs.clear()
	for i in range(32):
		_bugs.append({
			"x": _rng.randf(),
			"y": _rng.randf_range(0.35, 0.92),
			"phase": _rng.randf() * TAU,
			"speed": _rng.randf_range(0.4, 1.2),
		})


func process_fx(delta: float) -> void:
	for i in range(_bugs.size()):
		var b: Dictionary = _bugs[i]
		b["x"] = fmod(float(b["x"]) + delta * 0.035 * float(b["speed"]) + 1.0, 1.0)
		b["y"] = clampf(
			float(b["y"]) + sin(_time * float(b["speed"]) + float(b["phase"])) * delta * 0.045,
			0.3,
			0.95
		)
		_bugs[i] = b


func draw_fx() -> void:
	var w := size.x
	var h := size.y
	for b in _bugs:
		var a := 0.25
		if SettingsManager.fx_enabled:
			a = 0.2 + 0.75 * absf(sin(_time * 3.0 * float(b["speed"]) + float(b["phase"])))
		draw_circle(Vector2(float(b["x"]) * w, float(b["y"]) * h), 3.2, Color(0.75, 1.0, 0.4, a))
