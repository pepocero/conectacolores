extends Control

## Fondo Modo Rubik: gradiente + pequeños cubos de Rubik flotando (estilo burbujas).

const CUBES := [
	{"pos": Vector2(0.29, 0.105), "r": 0.028, "phase": 0.0, "sx": 0.22, "sy": 0.18, "ax": 0.10, "ay": 0.07, "spin": 0.35, "seed": 1},
	{"pos": Vector2(0.90, 0.085), "r": 0.034, "phase": 1.3, "sx": 0.18, "sy": 0.24, "ax": 0.08, "ay": 0.09, "spin": -0.28, "seed": 2},
	{"pos": Vector2(0.13, 0.215), "r": 0.018, "phase": 2.1, "sx": 0.28, "sy": 0.16, "ax": 0.12, "ay": 0.08, "spin": 0.42, "seed": 3},
	{"pos": Vector2(0.80, 0.150), "r": 0.014, "phase": 0.7, "sx": 0.32, "sy": 0.26, "ax": 0.09, "ay": 0.10, "spin": -0.50, "seed": 4},
	{"pos": Vector2(0.06, 0.410), "r": 0.040, "phase": 2.8, "sx": 0.16, "sy": 0.21, "ax": 0.11, "ay": 0.12, "spin": 0.22, "seed": 5},
	{"pos": Vector2(0.92, 0.345), "r": 0.048, "phase": 1.9, "sx": 0.20, "sy": 0.15, "ax": 0.07, "ay": 0.11, "spin": -0.33, "seed": 6},
	{"pos": Vector2(0.09, 0.588), "r": 0.036, "phase": 0.4, "sx": 0.24, "sy": 0.19, "ax": 0.13, "ay": 0.08, "spin": 0.38, "seed": 7},
	{"pos": Vector2(0.97, 0.625), "r": 0.056, "phase": 3.4, "sx": 0.14, "sy": 0.22, "ax": 0.08, "ay": 0.10, "spin": -0.25, "seed": 8},
	{"pos": Vector2(0.07, 0.950), "r": 0.060, "phase": 1.1, "sx": 0.19, "sy": 0.17, "ax": 0.10, "ay": 0.06, "spin": 0.30, "seed": 9},
	{"pos": Vector2(0.84, 0.940), "r": 0.050, "phase": 2.5, "sx": 0.21, "sy": 0.23, "ax": 0.09, "ay": 0.07, "spin": -0.40, "seed": 10},
	{"pos": Vector2(0.48, 0.08), "r": 0.016, "phase": 0.9, "sx": 0.26, "sy": 0.20, "ax": 0.11, "ay": 0.08, "spin": 0.45, "seed": 11},
	{"pos": Vector2(0.62, 0.22), "r": 0.024, "phase": 1.7, "sx": 0.19, "sy": 0.27, "ax": 0.09, "ay": 0.10, "spin": -0.36, "seed": 12},
	{"pos": Vector2(0.38, 0.30), "r": 0.015, "phase": 2.4, "sx": 0.30, "sy": 0.18, "ax": 0.12, "ay": 0.09, "spin": 0.28, "seed": 13},
	{"pos": Vector2(0.55, 0.42), "r": 0.032, "phase": 0.3, "sx": 0.17, "sy": 0.22, "ax": 0.08, "ay": 0.11, "spin": -0.44, "seed": 14},
	{"pos": Vector2(0.22, 0.48), "r": 0.020, "phase": 3.1, "sx": 0.25, "sy": 0.16, "ax": 0.10, "ay": 0.08, "spin": 0.33, "seed": 15},
	{"pos": Vector2(0.72, 0.52), "r": 0.026, "phase": 1.5, "sx": 0.21, "sy": 0.25, "ax": 0.09, "ay": 0.10, "spin": -0.29, "seed": 16},
	{"pos": Vector2(0.42, 0.68), "r": 0.018, "phase": 2.7, "sx": 0.27, "sy": 0.19, "ax": 0.11, "ay": 0.07, "spin": 0.48, "seed": 17},
	{"pos": Vector2(0.18, 0.78), "r": 0.030, "phase": 0.6, "sx": 0.18, "sy": 0.23, "ax": 0.08, "ay": 0.09, "spin": -0.31, "seed": 18},
	{"pos": Vector2(0.65, 0.80), "r": 0.022, "phase": 3.6, "sx": 0.23, "sy": 0.17, "ax": 0.10, "ay": 0.11, "spin": 0.27, "seed": 19},
	{"pos": Vector2(0.50, 0.92), "r": 0.034, "phase": 1.2, "sx": 0.15, "sy": 0.21, "ax": 0.07, "ay": 0.08, "spin": -0.38, "seed": 20},
	{"pos": Vector2(0.33, 0.55), "r": 0.014, "phase": 2.0, "sx": 0.29, "sy": 0.24, "ax": 0.12, "ay": 0.09, "spin": 0.41, "seed": 21},
	{"pos": Vector2(0.88, 0.72), "r": 0.017, "phase": 0.8, "sx": 0.20, "sy": 0.28, "ax": 0.09, "ay": 0.10, "spin": -0.46, "seed": 22},
]

## Colores clásicos de sticker Rubik.
const STICKERS: Array[Color] = [
	Color("C41E3A"), # rojo
	Color("FF5800"), # naranja
	Color("FFD500"), # amarillo
	Color("FFFFFF"), # blanco
	Color("009B48"), # verde
	Color("0051BA"), # azul
]

const BG_TOP := Color("1A2A6E")
const BG_MID := Color("2A4AB0")
const BG_BOTTOM := Color("152050")
const BG_GLOW := Color(0.55, 0.70, 1.00)
const BG_WAVE := Color(0.70, 0.82, 1.00)

var _time: float = 0.0
var _fx_paused: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(SettingsManager.fx_enabled)
	resized.connect(queue_redraw)
	SettingsManager.settings_changed.connect(_on_settings_changed)
	queue_redraw()


func _exit_tree() -> void:
	if SettingsManager != null and SettingsManager.settings_changed.is_connected(_on_settings_changed):
		SettingsManager.settings_changed.disconnect(_on_settings_changed)
	set_process(false)


func is_rubik_background() -> bool:
	return true


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
	queue_redraw()


func _process(delta: float) -> void:
	if _fx_paused:
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return

	var mid_y := h * 0.42
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, mid_y), Vector2(0, mid_y)]),
		PackedColorArray([BG_TOP, BG_TOP, BG_MID, BG_MID])
	)
	draw_polygon(
		PackedVector2Array([Vector2(0, mid_y), Vector2(w, mid_y), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([BG_MID, BG_MID, BG_BOTTOM, BG_BOTTOM])
	)

	var glow_center := Vector2(w * 0.5, h * 0.36)
	for i in range(5):
		var t := float(i) / 4.0
		draw_circle(glow_center, lerpf(w * 0.75, w * 0.18, t), Color(BG_GLOW.r, BG_GLOW.g, BG_GLOW.b, 0.035))

	_draw_dots(w, h)
	_draw_waves(w, h)

	var animate := SettingsManager.fx_enabled
	for cube: Dictionary in CUBES:
		var center := _cube_center(cube, w, h, animate)
		var side := float(cube["r"]) * w
		var angle := 0.0
		if animate:
			angle = _time * float(cube["spin"]) + float(cube["phase"]) * 0.4
		_draw_mini_rubik(center, side, angle, int(cube["seed"]))


func _cube_center(cube: Dictionary, w: float, h: float, animate: bool) -> Vector2:
	var base: Vector2 = cube["pos"]
	if not animate:
		return Vector2(base.x * w, base.y * h)
	var phase: float = cube["phase"]
	var sx: float = cube["sx"]
	var sy: float = cube["sy"]
	var ax: float = cube["ax"]
	var ay: float = cube["ay"]
	var nx := clampf(
		base.x + sin(_time * sx + phase) * ax + cos(_time * sx * 0.55 + phase * 1.3) * ax * 0.35,
		0.02,
		0.98
	)
	var ny := clampf(
		base.y + cos(_time * sy + phase * 0.8) * ay + sin(_time * sy * 0.7 + phase) * ay * 0.4,
		0.02,
		0.98
	)
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
				draw_circle(Vector2(x, y), 1.4, Color(BG_WAVE.r, BG_WAVE.g, BG_WAVE.b, 0.22 * fade))
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
			colors.append(Color(BG_WAVE.r, BG_WAVE.g, BG_WAVE.b, 0.16 * edge * edge))
			x += 12.0
		if points.size() >= 2:
			draw_polyline_colors(points, colors, 1.6, true)


## Cubo isométrico 3×3 con stickers de colores.
func _draw_mini_rubik(center: Vector2, side: float, angle: float, color_seed: int) -> void:
	if side < 4.0:
		return
	# Halo suave (como las burbujas).
	draw_circle(center, side * 1.55, Color(1, 1, 1, 0.06))
	draw_circle(center, side * 1.25, Color(0.2, 0.35, 0.8, 0.10))

	var s := side * 0.92
	var yaw := angle * 0.15
	var right := Vector2(cos(yaw), sin(yaw) * 0.35).normalized() * s
	var up := Vector2(-sin(yaw) * 0.55, -0.85).normalized() * s
	var back := Vector2(-right.x * 0.85, right.y * 0.2 + s * 0.55)

	var o := center - right * 0.35 - up * 0.15 + Vector2(0, s * 0.15)
	var p000 := o
	var p100 := o + right
	var p010 := o + up
	var p110 := o + right + up
	var p001 := o + back
	var p101 := o + right + back
	var p011 := o + up + back
	var p111 := o + right + up + back

	# Orden: izquierda, frontal, superior.
	_fill_face_grid(p000, back, up, color_seed + 20, 0.22)
	_fill_face_grid(p000, right, up, color_seed + 30, 0.08)
	_fill_face_grid(p010, right, back, color_seed + 10, 0.0)

	var outline := Color(0.05, 0.06, 0.12, 0.75)
	var ow := maxf(1.0, s * 0.06)
	draw_line(p000, p100, outline, ow, true)
	draw_line(p000, p010, outline, ow, true)
	draw_line(p000, p001, outline, ow, true)
	draw_line(p100, p110, outline, ow, true)
	draw_line(p010, p110, outline, ow, true)
	draw_line(p010, p011, outline, ow, true)
	draw_line(p110, p111, outline, ow, true)
	draw_line(p001, p101, outline, ow, true)
	draw_line(p001, p011, outline, ow, true)
	draw_line(p100, p101, outline, ow, true)
	draw_line(p011, p111, outline, ow, true)
	draw_circle(center + Vector2(-s * 0.25, -s * 0.35), s * 0.12, Color(1, 1, 1, 0.35))


func _fill_face_grid(origin: Vector2, axis_u: Vector2, axis_v: Vector2, color_seed: int, shade: float) -> void:
	const N := 3
	var gap := 0.06
	for j in range(N):
		for i in range(N):
			var u0 := (float(i) + gap) / float(N)
			var u1 := (float(i) + 1.0 - gap) / float(N)
			var v0 := (float(j) + gap) / float(N)
			var v1 := (float(j) + 1.0 - gap) / float(N)
			var c0 := origin + axis_u * u0 + axis_v * v0
			var c1 := origin + axis_u * u1 + axis_v * v0
			var c2 := origin + axis_u * u1 + axis_v * v1
			var c3 := origin + axis_u * u0 + axis_v * v1
			var idx := posmod(color_seed * 17 + i * 3 + j * 5 + i * j, STICKERS.size())
			var col: Color = STICKERS[idx]
			if shade > 0.0:
				col = col.darkened(shade)
			draw_colored_polygon(PackedVector2Array([c0, c1, c2, c3]), col)
	# Líneas de rejilla oscuras.
	var line := Color(0.08, 0.08, 0.12, 0.55)
	var lw := maxf(0.8, axis_u.length() * 0.04)
	for k in range(N + 1):
		var t := float(k) / float(N)
		draw_line(origin + axis_u * t, origin + axis_u * t + axis_v, line, lw, true)
		draw_line(origin + axis_v * t, origin + axis_v * t + axis_u, line, lw, true)
