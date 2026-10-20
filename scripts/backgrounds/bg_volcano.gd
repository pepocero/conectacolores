extends BgPhotoBase

## Foto de volcán + chispas de lava y columnas de humo.

var _sparks: Array[Dictionary] = []
var _smoke: Array[Dictionary] = []


func _ready() -> void:
	photo_path = "res://assets/backgrounds/volcano.jpg"
	super._ready()


func setup_fx() -> void:
	_sparks.clear()
	for i in range(40):
		_sparks.append({
			"x": _rng.randf_range(0.35, 0.65),
			"y": _rng.randf_range(0.35, 0.6),
			"vx": _rng.randf_range(-0.1, 0.1),
			"vy": _rng.randf_range(-0.35, -0.1),
			"life": _rng.randf(),
			"r": _rng.randf_range(2.0, 4.5),
		})
	_smoke.clear()
	for i in range(22):
		_smoke.append(_new_smoke_puff(true))


func _new_smoke_puff(random_life: bool = false) -> Dictionary:
	return {
		"x": _rng.randf_range(0.38, 0.62),
		"y": _rng.randf_range(0.32, 0.48),
		"vx": _rng.randf_range(-0.025, 0.025),
		"vy": _rng.randf_range(-0.08, -0.035),
		"life": _rng.randf() if random_life else 0.0,
		"max_life": _rng.randf_range(2.8, 5.2),
		"r0": _rng.randf_range(10.0, 18.0),
		"grow": _rng.randf_range(28.0, 55.0),
		"wobble": _rng.randf() * TAU,
	}


func process_fx(delta: float) -> void:
	for i in range(_sparks.size()):
		var s: Dictionary = _sparks[i]
		s["x"] = float(s["x"]) + float(s["vx"]) * delta
		s["y"] = float(s["y"]) + float(s["vy"]) * delta
		s["life"] = float(s["life"]) + delta * 0.75
		if float(s["life"]) > 1.0 or float(s["y"]) < 0.08:
			s["x"] = _rng.randf_range(0.4, 0.6)
			s["y"] = _rng.randf_range(0.42, 0.58)
			s["vx"] = _rng.randf_range(-0.12, 0.12)
			s["vy"] = _rng.randf_range(-0.35, -0.12)
			s["life"] = 0.0
		_sparks[i] = s

	for i in range(_smoke.size()):
		var p: Dictionary = _smoke[i]
		var life := float(p["life"]) + delta
		var t := life / float(p["max_life"])
		p["x"] = float(p["x"]) + float(p["vx"]) * delta + sin(_time * 0.9 + float(p["wobble"])) * delta * 0.02
		p["y"] = float(p["y"]) + float(p["vy"]) * delta * (1.0 - t * 0.35)
		p["life"] = life
		if t >= 1.0 or float(p["y"]) < -0.05:
			p = _new_smoke_puff(false)
		_smoke[i] = p


func draw_fx() -> void:
	var w := size.x
	var h := size.y

	for p in _smoke:
		var t := float(p["life"]) / float(p["max_life"])
		if not SettingsManager.fx_enabled:
			t = 0.45
		var a := (1.0 - t) * (1.0 - t) * 0.28
		var r := float(p["r0"]) + float(p["grow"]) * t
		var px := float(p["x"]) * w
		var py := float(p["y"]) * h
		if SettingsManager.fx_enabled:
			px += sin(_time * 0.7 + float(p["wobble"])) * 10.0
		draw_circle(Vector2(px, py), r, Color(0.22, 0.2, 0.2, a))
		draw_circle(Vector2(px + r * 0.2, py - r * 0.1), r * 0.7, Color(0.35, 0.3, 0.28, a * 0.7))
		draw_circle(Vector2(px - r * 0.15, py + r * 0.05), r * 0.55, Color(0.15, 0.14, 0.14, a * 0.55))

	for s in _sparks:
		var a := 1.0 - float(s["life"])
		if not SettingsManager.fx_enabled:
			a = 0.45
		draw_circle(
			Vector2(float(s["x"]) * w, float(s["y"]) * h),
			float(s["r"]),
			Color(1.0, 0.45 + 0.35 * a, 0.12, a * 0.9)
		)
