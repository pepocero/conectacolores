extends BgPhotoBase

## Foto de ciudad + luces, estrellas fugaces y aviones aleatorios.

var _blinks: Array[Dictionary] = []
var _meteors: Array[Dictionary] = []
var _planes: Array[Dictionary] = []
var _meteor_cooldown: float = 0.0
var _plane_cooldown: float = 0.0


func _ready() -> void:
	photo_path = "res://assets/backgrounds/city.jpg"
	super._ready()


func setup_fx() -> void:
	_blinks.clear()
	for i in range(36):
		_blinks.append({
			"x": _rng.randf_range(0.05, 0.95),
			"y": _rng.randf_range(0.35, 0.85),
			"phase": _rng.randf() * TAU,
			"r": _rng.randf_range(1.2, 2.6),
		})
	_meteors.clear()
	_planes.clear()
	_meteor_cooldown = _rng.randf_range(1.5, 4.0)
	_plane_cooldown = _rng.randf_range(4.0, 9.0)


func process_fx(delta: float) -> void:
	_meteor_cooldown -= delta
	if _meteor_cooldown <= 0.0 and _meteors.size() < 3:
		_spawn_meteor()
		_meteor_cooldown = _rng.randf_range(2.5, 7.0)

	_plane_cooldown -= delta
	if _plane_cooldown <= 0.0 and _planes.size() < 2:
		_spawn_plane()
		_plane_cooldown = _rng.randf_range(8.0, 18.0)

	var alive_meteors: Array[Dictionary] = []
	for m in _meteors:
		m["x"] = float(m["x"]) + float(m["vx"]) * delta
		m["y"] = float(m["y"]) + float(m["vy"]) * delta
		m["life"] = float(m["life"]) - delta
		if float(m["life"]) > 0.0 and float(m["x"]) < 1.2 and float(m["y"]) < 1.1:
			alive_meteors.append(m)
	_meteors = alive_meteors

	var alive_planes: Array[Dictionary] = []
	for p in _planes:
		p["x"] = float(p["x"]) + float(p["vx"]) * delta
		p["y"] = float(p["y"]) + sin(_time * 1.2 + float(p["phase"])) * 0.0008
		p["blink"] = float(p["blink"]) + delta
		if float(p["x"]) > -0.15 and float(p["x"]) < 1.15:
			alive_planes.append(p)
	_planes = alive_planes


func _spawn_meteor() -> void:
	var from_left := _rng.randf() > 0.5
	var x := _rng.randf_range(0.05, 0.7) if from_left else _rng.randf_range(0.3, 0.95)
	var y := _rng.randf_range(0.02, 0.28)
	var speed := _rng.randf_range(0.45, 0.85)
	var angle := _rng.randf_range(0.35, 0.85) if from_left else _rng.randf_range(PI - 0.85, PI - 0.35)
	_meteors.append({
		"x": x,
		"y": y,
		"vx": cos(angle) * speed,
		"vy": sin(angle) * speed * 0.85,
		"life": _rng.randf_range(0.55, 1.1),
		"len": _rng.randf_range(0.06, 0.14),
		"bright": _rng.randf_range(0.7, 1.0),
	})


func _spawn_plane() -> void:
	var left_to_right := _rng.randf() > 0.5
	var y := _rng.randf_range(0.08, 0.32)
	var speed := _rng.randf_range(0.04, 0.08)
	_planes.append({
		"x": -0.08 if left_to_right else 1.08,
		"y": y,
		"vx": speed if left_to_right else -speed,
		"phase": _rng.randf() * TAU,
		"blink": 0.0,
		"dir": 1.0 if left_to_right else -1.0,
	})


func draw_fx() -> void:
	if not SettingsManager.fx_enabled:
		return
	var w := size.x
	var h := size.y

	for b in _blinks:
		var pulse := sin(_time * 2.2 + float(b["phase"]))
		if pulse < 0.4:
			continue
		var a := (pulse - 0.4) * 0.65
		draw_circle(
			Vector2(float(b["x"]) * w, float(b["y"]) * h),
			float(b["r"]),
			Color(1.0, 0.92, 0.55, a)
		)

	for m in _meteors:
		_draw_meteor(m, w, h)

	for p in _planes:
		_draw_plane(p, w, h)


func _draw_meteor(m: Dictionary, w: float, h: float) -> void:
	var pos := Vector2(float(m["x"]) * w, float(m["y"]) * h)
	var vel := Vector2(float(m["vx"]) * w, float(m["vy"]) * h)
	if vel.length_squared() < 0.001:
		return
	var dir := vel.normalized()
	var trail_len := float(m["len"]) * w
	var life_f := clampf(float(m["life"]), 0.0, 1.0)
	var bright := float(m["bright"]) * life_f
	var tip := pos
	var tail := pos - dir * trail_len
	for i in range(5):
		var t := float(i) / 4.0
		var a := bright * (1.0 - t) * 0.55
		var p0 := tip.lerp(tail, t)
		var p1 := tip.lerp(tail, minf(t + 0.25, 1.0))
		draw_line(p0, p1, Color(0.9, 0.95, 1.0, a), lerpf(2.8, 0.8, t), true)
	draw_circle(tip, 2.4, Color(1, 1, 1, bright))


func _draw_plane(p: Dictionary, w: float, h: float) -> void:
	var pos := Vector2(float(p["x"]) * w, float(p["y"]) * h)
	var dir := float(p["dir"])
	var body := 10.0
	var wing := 7.0
	draw_line(
		pos + Vector2(-body * dir, 0),
		pos + Vector2(body * dir, 0),
		Color(0.85, 0.88, 0.92, 0.85),
		2.2,
		true
	)
	draw_line(
		pos + Vector2(-2.0 * dir, 0),
		pos + Vector2(2.0 * dir, -wing),
		Color(0.8, 0.84, 0.9, 0.75),
		1.6,
		true
	)
	draw_line(
		pos + Vector2(-2.0 * dir, 0),
		pos + Vector2(2.0 * dir, wing * 0.6),
		Color(0.8, 0.84, 0.9, 0.55),
		1.4,
		true
	)
	var blink_on := fmod(float(p["blink"]), 1.1) < 0.55
	var nose := pos + Vector2(body * dir, 0)
	var wing_tip := pos + Vector2(2.0 * dir, -wing)
	draw_circle(nose, 2.0, Color(1, 1, 0.85, 0.9 if blink_on else 0.25))
	draw_circle(wing_tip, 1.8, Color(1, 0.25, 0.2, 0.95 if blink_on else 0.2))
	draw_circle(pos + Vector2(2.0 * dir, wing * 0.55), 1.6, Color(0.2, 1.0, 0.35, 0.9 if not blink_on else 0.25))
