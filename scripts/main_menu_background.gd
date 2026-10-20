extends Control

## Fondo: gradiente + ondas + burbujas glossy que se conectan y explotan.
## En Sandbox el color del fondo rota por bandas (set_palette_band).

## Cada burbuja: pos base, radio relativo, color, fase y velocidades/amplitudes de recorrido.
const BUBBLES := [
	{"pos": Vector2(0.29, 0.105), "r": 0.030, "color": Color("4FA3FF"), "phase": 0.0, "sx": 0.22, "sy": 0.18, "ax": 0.10, "ay": 0.07},
	{"pos": Vector2(0.90, 0.085), "r": 0.036, "color": Color("4FA3FF"), "phase": 1.3, "sx": 0.18, "sy": 0.24, "ax": 0.08, "ay": 0.09},
	{"pos": Vector2(0.13, 0.215), "r": 0.020, "color": Color("5FB4FF"), "phase": 2.1, "sx": 0.28, "sy": 0.16, "ax": 0.12, "ay": 0.08},
	{"pos": Vector2(0.80, 0.150), "r": 0.012, "color": Color("8FD8FF"), "phase": 0.7, "sx": 0.32, "sy": 0.26, "ax": 0.09, "ay": 0.10},
	{"pos": Vector2(0.06, 0.410), "r": 0.044, "color": Color("FF4F9A"), "phase": 2.8, "sx": 0.16, "sy": 0.21, "ax": 0.11, "ay": 0.12},
	{"pos": Vector2(0.92, 0.345), "r": 0.056, "color": Color("3F9BFF"), "phase": 1.9, "sx": 0.20, "sy": 0.15, "ax": 0.07, "ay": 0.11},
	{"pos": Vector2(0.09, 0.588), "r": 0.040, "color": Color("4FE08A"), "phase": 0.4, "sx": 0.24, "sy": 0.19, "ax": 0.13, "ay": 0.08},
	{"pos": Vector2(0.97, 0.625), "r": 0.078, "color": Color("3F9BFF"), "phase": 3.4, "sx": 0.14, "sy": 0.22, "ax": 0.08, "ay": 0.10},
	{"pos": Vector2(0.07, 0.950), "r": 0.082, "color": Color("FF4A5E"), "phase": 1.1, "sx": 0.19, "sy": 0.17, "ax": 0.10, "ay": 0.06},
	{"pos": Vector2(0.84, 0.940), "r": 0.066, "color": Color("5FE05A"), "phase": 2.5, "sx": 0.21, "sy": 0.23, "ax": 0.09, "ay": 0.07},
	# Extra — más densidad en el fondo.
	{"pos": Vector2(0.48, 0.08), "r": 0.018, "color": Color("FFD43B"), "phase": 0.9, "sx": 0.26, "sy": 0.20, "ax": 0.11, "ay": 0.08},
	{"pos": Vector2(0.62, 0.22), "r": 0.026, "color": Color("FF8A3D"), "phase": 1.7, "sx": 0.19, "sy": 0.27, "ax": 0.09, "ay": 0.10},
	{"pos": Vector2(0.38, 0.30), "r": 0.015, "color": Color("9A52E6"), "phase": 2.4, "sx": 0.30, "sy": 0.18, "ax": 0.12, "ay": 0.09},
	{"pos": Vector2(0.55, 0.42), "r": 0.034, "color": Color("3CC8F0"), "phase": 0.3, "sx": 0.17, "sy": 0.22, "ax": 0.08, "ay": 0.11},
	{"pos": Vector2(0.22, 0.48), "r": 0.022, "color": Color("FF4FB0"), "phase": 3.1, "sx": 0.25, "sy": 0.16, "ax": 0.10, "ay": 0.08},
	{"pos": Vector2(0.72, 0.52), "r": 0.028, "color": Color("7BE04A"), "phase": 1.5, "sx": 0.21, "sy": 0.25, "ax": 0.09, "ay": 0.10},
	{"pos": Vector2(0.42, 0.68), "r": 0.019, "color": Color("5FB4FF"), "phase": 2.7, "sx": 0.27, "sy": 0.19, "ax": 0.11, "ay": 0.07},
	{"pos": Vector2(0.18, 0.78), "r": 0.032, "color": Color("FFC52E"), "phase": 0.6, "sx": 0.18, "sy": 0.23, "ax": 0.08, "ay": 0.09},
	{"pos": Vector2(0.65, 0.80), "r": 0.024, "color": Color("FF6B9A"), "phase": 3.6, "sx": 0.23, "sy": 0.17, "ax": 0.10, "ay": 0.11},
	{"pos": Vector2(0.50, 0.92), "r": 0.038, "color": Color("4F8BFF"), "phase": 1.2, "sx": 0.15, "sy": 0.21, "ax": 0.07, "ay": 0.08},
	{"pos": Vector2(0.33, 0.55), "r": 0.014, "color": Color("A78BFA"), "phase": 2.0, "sx": 0.29, "sy": 0.24, "ax": 0.12, "ay": 0.09},
	{"pos": Vector2(0.88, 0.72), "r": 0.017, "color": Color("34D399"), "phase": 0.8, "sx": 0.20, "sy": 0.28, "ax": 0.09, "ay": 0.10},
]

## Paletas de fondo (top / mid / bottom / glow / wave). Índice = banda Sandbox.
const PALETTES := [
	{"top": Color("1A3AA6"), "mid": Color("2A5CD8"), "bottom": Color("1E44B6"), "glow": Color(0.45, 0.70, 1.00), "wave": Color(0.65, 0.85, 1.00)}, # azul
	{"top": Color("8B1528"), "mid": Color("D32F2F"), "bottom": Color("6A101C"), "glow": Color(1.00, 0.45, 0.42), "wave": Color(1.00, 0.70, 0.68)}, # rojo
	{"top": Color("0F5C2E"), "mid": Color("2E9B57"), "bottom": Color("0A4522"), "glow": Color(0.45, 1.00, 0.60), "wave": Color(0.65, 0.95, 0.75)}, # verde
	{"top": Color("4A1A8A"), "mid": Color("7B3FE8"), "bottom": Color("351265"), "glow": Color(0.75, 0.55, 1.00), "wave": Color(0.85, 0.72, 1.00)}, # violeta
	{"top": Color("8A3A0A"), "mid": Color("E67A22"), "bottom": Color("6A2C08"), "glow": Color(1.00, 0.72, 0.35), "wave": Color(1.00, 0.85, 0.55)}, # naranja
	{"top": Color("0A5C5C"), "mid": Color("1AA8A0"), "bottom": Color("084545"), "glow": Color(0.40, 0.95, 0.90), "wave": Color(0.60, 0.95, 0.92)}, # turquesa
	{"top": Color("8A1458"), "mid": Color("E03A8A"), "bottom": Color("5E0E3C"), "glow": Color(1.00, 0.50, 0.78), "wave": Color(1.00, 0.72, 0.88)}, # magenta
	{"top": Color("1A3F6E"), "mid": Color("3D7ECC"), "bottom": Color("122E52"), "glow": Color(0.55, 0.75, 1.00), "wave": Color(0.70, 0.85, 1.00)}, # índigo
	{"top": Color("5A5C12"), "mid": Color("A8B02A"), "bottom": Color("3E400C"), "glow": Color(0.90, 0.95, 0.40), "wave": Color(0.92, 0.95, 0.65)}, # lima
	{"top": Color("5C2E14"), "mid": Color("A85A2A"), "bottom": Color("3E1E0C"), "glow": Color(1.00, 0.70, 0.45), "wave": Color(0.95, 0.80, 0.60)}, # cobrizo
]

const LINK_GROW_DURATION := 1.05
const LINK_HOLD_DURATION := 0.12
const POP_OUT_DURATION := 0.28
const POP_IN_DURATION := 0.45
const LINK_COOLDOWN_MIN := 1.6
const LINK_COOLDOWN_MAX := 3.2

var _time: float = 0.0
var _rng := RandomNumberGenerator.new()
var _palette_band: int = 0
var _top: Color = PALETTES[0]["top"]
var _mid: Color = PALETTES[0]["mid"]
var _bottom: Color = PALETTES[0]["bottom"]
var _glow: Color = PALETTES[0]["glow"]
var _wave: Color = PALETTES[0]["wave"]

## Enlace activo: from, to, t (0..1 grow), phase ("grow"|"burst"), burst_t
var _link: Dictionary = {}
var _next_link_in: float = 1.2
## Por burbuja: scale (1 = normal), pop_phase (""|"out"|"in"), pop_t
var _bubble_fx: Array[Dictionary] = []
## Partículas de explosión tipo burbuja de agua.
var _particles: Array[Dictionary] = []
var _fx_paused: bool = false


func set_palette_band(band: int) -> void:
	_palette_band = posmod(band, PALETTES.size())
	var p: Dictionary = PALETTES[_palette_band]
	_top = p["top"]
	_mid = p["mid"]
	_bottom = p["bottom"]
	_glow = p["glow"]
	_wave = p["wave"]
	queue_redraw()


func get_palette_band() -> int:
	return _palette_band


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	_reset_bubble_fx()
	set_palette_band(_palette_band)
	set_process(SettingsManager.fx_enabled)
	resized.connect(queue_redraw)
	SettingsManager.settings_changed.connect(_on_settings_changed)


func _exit_tree() -> void:
	if SettingsManager != null and SettingsManager.settings_changed.is_connected(_on_settings_changed):
		SettingsManager.settings_changed.disconnect(_on_settings_changed)
	set_process(false)


func _reset_bubble_fx() -> void:
	_bubble_fx.clear()
	for i in range(BUBBLES.size()):
		_bubble_fx.append({"scale": 1.0, "phase": "", "t": 0.0})


func set_fx_paused(paused: bool) -> void:
	if _fx_paused == paused:
		return
	_fx_paused = paused
	set_process(not paused and SettingsManager.fx_enabled)
	if not paused:
		queue_redraw()


func _on_settings_changed() -> void:
	if _fx_paused:
		return
	set_process(SettingsManager.fx_enabled)
	if not SettingsManager.fx_enabled:
		_time = 0.0
		_link.clear()
		_particles.clear()
		_reset_bubble_fx()
		_next_link_in = 1.2
	queue_redraw()


func _process(delta: float) -> void:
	if _fx_paused:
		return
	_time += delta
	if SettingsManager.fx_enabled:
		_update_link(delta)
		_update_bubble_fx(delta)
		_update_particles(delta)
	queue_redraw()


func _update_link(delta: float) -> void:
	if _link.is_empty():
		_next_link_in -= delta
		if _next_link_in <= 0.0:
			_try_start_link()
		return

	var phase: String = _link.get("phase", "grow")
	if phase == "grow":
		_link["t"] = float(_link.get("t", 0.0)) + delta / LINK_GROW_DURATION
		if float(_link["t"]) >= 1.0:
			_link["t"] = 1.0
			_link["phase"] = "hold"
			_link["hold_t"] = 0.0
	elif phase == "hold":
		_link["hold_t"] = float(_link.get("hold_t", 0.0)) + delta
		if float(_link["hold_t"]) >= LINK_HOLD_DURATION:
			_trigger_connection_burst()
			_link.clear()
			_next_link_in = _rng.randf_range(LINK_COOLDOWN_MIN, LINK_COOLDOWN_MAX)


func _try_start_link() -> void:
	var pair := _pick_link_pair()
	if pair.x < 0:
		_next_link_in = 0.8
		return
	_link = {
		"from": int(pair.x),
		"to": int(pair.y),
		"t": 0.0,
		"phase": "grow",
		"hold_t": 0.0,
	}


func _pick_link_pair() -> Vector2i:
	var available: Array[int] = []
	for i in range(BUBBLES.size()):
		if i >= _bubble_fx.size():
			continue
		var fx: Dictionary = _bubble_fx[i]
		if str(fx.get("phase", "")) == "":
			available.append(i)
	if available.size() < 2:
		return Vector2i(-1, -1)

	# Preferir pares cercanos en espacio normalizado.
	var best_a := -1
	var best_b := -1
	var best_score := 999.0
	for attempt in range(12):
		var a: int = available[_rng.randi_range(0, available.size() - 1)]
		var b: int = available[_rng.randi_range(0, available.size() - 1)]
		if a == b:
			continue
		var pa: Vector2 = BUBBLES[a]["pos"]
		var pb: Vector2 = BUBBLES[b]["pos"]
		var dist := pa.distance_to(pb)
		if dist < 0.12 or dist > 0.62:
			continue
		var score := dist + _rng.randf() * 0.08
		if score < best_score:
			best_score = score
			best_a = a
			best_b = b
	if best_a < 0:
		best_a = available[0]
		best_b = available[1]
	return Vector2i(best_a, best_b)


func _trigger_connection_burst() -> void:
	if size.x < 2.0 or size.y < 2.0 or _link.is_empty():
		return
	var from_i: int = int(_link["from"])
	var to_i: int = int(_link["to"])
	var animate := true
	var a := _bubble_center(BUBBLES[from_i], size.x, size.y, animate)
	var b := _bubble_center(BUBBLES[to_i], size.x, size.y, animate)
	var mid := a.lerp(b, 0.5)
	var color_a: Color = BUBBLES[from_i]["color"]
	var color_b: Color = BUBBLES[to_i]["color"]
	var mix := color_a.lerp(color_b, 0.5)

	_spawn_water_burst(mid, mix, 16)
	_spawn_water_burst(a, color_a, 10)
	_spawn_water_burst(b, color_b, 10)
	_start_bubble_pop(from_i)
	_start_bubble_pop(to_i)


func _start_bubble_pop(index: int) -> void:
	if index < 0 or index >= _bubble_fx.size():
		return
	_bubble_fx[index] = {"scale": 1.0, "phase": "out", "t": 0.0}


func _spawn_water_burst(center: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		var angle := TAU * float(i) / float(count) + _rng.randf() * 0.4
		var speed := _rng.randf_range(40.0, 140.0)
		_particles.append({
			"pos": center,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"r": _rng.randf_range(3.0, 9.0),
			"color": color.lightened(_rng.randf_range(0.0, 0.35)),
			"life": 0.0,
			"max_life": _rng.randf_range(0.35, 0.75),
			"rise": _rng.randf_range(18.0, 55.0),
		})


func _update_bubble_fx(delta: float) -> void:
	for i in range(_bubble_fx.size()):
		var fx: Dictionary = _bubble_fx[i]
		var phase: String = str(fx.get("phase", ""))
		if phase == "":
			continue
		fx["t"] = float(fx.get("t", 0.0)) + delta
		var t: float = float(fx["t"])
		if phase == "out":
			var u := clampf(t / POP_OUT_DURATION, 0.0, 1.0)
			fx["scale"] = 1.0 - u * u
			if u >= 1.0:
				fx["phase"] = "in"
				fx["t"] = 0.0
				fx["scale"] = 0.0
		elif phase == "in":
			var u2 := clampf(t / POP_IN_DURATION, 0.0, 1.0)
			# Ease-out bounce suave.
			fx["scale"] = 1.0 - pow(1.0 - u2, 3.0)
			if u2 >= 1.0:
				fx["phase"] = ""
				fx["t"] = 0.0
				fx["scale"] = 1.0
		_bubble_fx[i] = fx


func _update_particles(delta: float) -> void:
	var i := 0
	while i < _particles.size():
		var p: Dictionary = _particles[i]
		p["life"] = float(p["life"]) + delta
		var life: float = float(p["life"])
		var max_life: float = float(p["max_life"])
		if life >= max_life:
			_particles.remove_at(i)
			continue
		var vel: Vector2 = p["vel"]
		vel *= 0.96
		vel.y -= float(p["rise"]) * delta
		p["vel"] = vel
		p["pos"] = Vector2(p["pos"]) + vel * delta
		_particles[i] = p
		i += 1


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return

	var mid_y := h * 0.42
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, mid_y), Vector2(0, mid_y)]),
		PackedColorArray([_top, _top, _mid, _mid])
	)
	draw_polygon(
		PackedVector2Array([Vector2(0, mid_y), Vector2(w, mid_y), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([_mid, _mid, _bottom, _bottom])
	)

	var glow_center := Vector2(w * 0.5, h * 0.36)
	for i in range(5):
		var t := float(i) / 4.0
		draw_circle(glow_center, lerpf(w * 0.75, w * 0.18, t), Color(_glow.r, _glow.g, _glow.b, 0.035))

	_draw_dots(w, h)
	_draw_waves(w, h)

	var animate := SettingsManager.fx_enabled
	_draw_link(w, h, animate)

	for i in range(BUBBLES.size()):
		var bubble: Dictionary = BUBBLES[i]
		var center := _bubble_center(bubble, w, h, animate)
		var bubble_scale := 1.0
		if i < _bubble_fx.size():
			bubble_scale = float(_bubble_fx[i].get("scale", 1.0))
		if bubble_scale <= 0.02:
			continue
		_draw_bubble(center, float(bubble["r"]) * w * bubble_scale, bubble["color"])

	_draw_particles()


func _draw_link(w: float, h: float, animate: bool) -> void:
	if _link.is_empty() or not animate:
		return
	var from_i: int = int(_link["from"])
	var to_i: int = int(_link["to"])
	if from_i < 0 or to_i < 0 or from_i >= BUBBLES.size() or to_i >= BUBBLES.size():
		return
	var a := _bubble_center(BUBBLES[from_i], w, h, animate)
	var b := _bubble_center(BUBBLES[to_i], w, h, animate)
	var progress := clampf(float(_link.get("t", 0.0)), 0.0, 1.0)
	var eased := progress * progress * (3.0 - 2.0 * progress)
	var tip := a.lerp(b, eased)
	var color_a: Color = BUBBLES[from_i]["color"]
	var color_b: Color = BUBBLES[to_i]["color"]
	var line_col := color_a.lerp(color_b, eased)

	# Halo suave detrás de la línea.
	draw_line(a, tip, Color(line_col.r, line_col.g, line_col.b, 0.22), 10.0, true)
	draw_line(a, tip, Color(line_col.r, line_col.g, line_col.b, 0.55), 4.5, true)
	draw_line(a, tip, Color(1, 1, 1, 0.35), 1.8, true)

	# Punta brillante que avanza.
	draw_circle(tip, 7.0, Color(line_col.r, line_col.g, line_col.b, 0.35))
	draw_circle(tip, 4.0, line_col.lightened(0.25))
	draw_circle(tip + Vector2(-1.2, -1.2), 1.4, Color(1, 1, 1, 0.8))

	if progress >= 0.98:
		var mid := a.lerp(b, 0.5)
		draw_circle(mid, 18.0, Color(1, 1, 1, 0.18))
		draw_circle(mid, 10.0, Color(line_col.r, line_col.g, line_col.b, 0.45))
		draw_circle(mid, 5.0, Color(1, 1, 1, 0.75))


func _draw_particles() -> void:
	for p_variant: Variant in _particles:
		var p: Dictionary = p_variant
		var life: float = float(p["life"])
		var max_life: float = float(p["max_life"])
		var u := clampf(life / max_life, 0.0, 1.0)
		var fade := 1.0 - u * u
		var r: float = float(p["r"]) * (1.0 + u * 0.8)
		var color: Color = p["color"]
		var pos: Vector2 = p["pos"]
		# Burbuja de agua: anillo + brillo.
		draw_circle(pos, r * 1.15, Color(color.r, color.g, color.b, 0.12 * fade))
		draw_arc(pos, r, 0.0, TAU, 20, Color(1, 1, 1, 0.55 * fade), maxf(1.2, r * 0.22), true)
		draw_circle(pos + Vector2(-r * 0.28, -r * 0.3), r * 0.22, Color(1, 1, 1, 0.65 * fade))


func _bubble_center(bubble: Dictionary, w: float, h: float, animate: bool) -> Vector2:
	var base: Vector2 = bubble["pos"]
	if not animate:
		return Vector2(base.x * w, base.y * h)
	var phase: float = bubble["phase"]
	var sx: float = bubble["sx"]
	var sy: float = bubble["sy"]
	var ax: float = bubble["ax"]
	var ay: float = bubble["ay"]
	var nx := clampf(base.x + sin(_time * sx + phase) * ax + cos(_time * sx * 0.55 + phase * 1.3) * ax * 0.35, 0.02, 0.98)
	var ny := clampf(base.y + cos(_time * sy + phase * 0.8) * ay + sin(_time * sy * 0.7 + phase) * ay * 0.4, 0.02, 0.98)
	return Vector2(nx * w, ny * h)


func _draw_dots(w: float, h: float) -> void:
	var step := 14.0
	var max_x := w * 0.34
	var max_y := h * 0.13
	var y := 10.0
	while y < max_y:
		var x := 10.0
		while x < max_x:
			var fade := 1.0 - clampf(Vector2(x / max_x, y / max_y).length() / 1.2, 0.0, 1.0)
			if fade > 0.02:
				draw_circle(Vector2(x, y), 1.4, Color(_wave.r, _wave.g, _wave.b, 0.22 * fade))
			x += step
		y += step


func _draw_waves(w: float, h: float) -> void:
	var wave_time := _time if SettingsManager.fx_enabled else 0.0
	var bands := [0.255, 0.275, 0.295, 0.735, 0.755, 0.775]
	for i in range(bands.size()):
		var base_y: float = h * float(bands[i])
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		var x := 0.0
		while x <= w + 10.0:
			var t := x / w
			var y := base_y + sin(t * PI * 2.0 + float(i) * 0.6 + wave_time * 0.25) * h * 0.012
			points.append(Vector2(x, y))
			var edge := absf(t - 0.5) * 2.0
			colors.append(Color(_wave.r, _wave.g, _wave.b, 0.16 * edge * edge))
			x += 12.0
		if points.size() >= 2:
			draw_polyline_colors(points, colors, 1.6, true)


func _draw_bubble(center: Vector2, r: float, color: Color) -> void:
	if r < 1.0:
		return
	draw_circle(center, r * 1.35, Color(color.r, color.g, color.b, 0.10))
	draw_circle(center, r * 1.12, Color(color.r, color.g, color.b, 0.20))
	var steps := 7
	for i in range(steps):
		var t := float(i) / float(steps - 1)
		var rr := r * (1.0 - t * 0.58)
		var offset := Vector2(-r, -r) * 0.24 * t
		draw_circle(center + offset, rr, color.darkened(0.32).lerp(color.lightened(0.38), t))
	draw_arc(center, r * 0.97, 0.0, TAU, 48, Color(1, 1, 1, 0.32), maxf(1.5, r * 0.06), true)
	draw_arc(center, r * 0.72, PI * 0.18, PI * 0.82, 24, Color(1, 1, 1, 0.22), maxf(1.2, r * 0.08), true)
	draw_circle(center + Vector2(-r * 0.38, -r * 0.42), r * 0.22, Color(1, 1, 1, 0.78))
	draw_circle(center + Vector2(-r * 0.12, -r * 0.6), r * 0.09, Color(1, 1, 1, 0.5))
