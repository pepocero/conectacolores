extends RefCounted

## Figuras geométricas que acompañan a cada color (ver GamePalette.SHAPES).
## Se dibujan sobre la bola con relleno y contorno contrastados según su luminosidad.


static func draw_on_ball(canvas: CanvasItem, center: Vector2, ball_radius: float, shape: String, ball_color: Color) -> void:
	# Icono centrado con margen: no llena la roca/bola (~mitad del radio).
	var r := maxf(ball_radius * 0.52, 5.0)
	if ball_radius < 4.0:
		return
	var luminance := ball_color.r * 0.299 + ball_color.g * 0.587 + ball_color.b * 0.114
	var a := clampf(ball_color.a, 0.0, 1.0)
	var fill := Color(0.06, 0.08, 0.18, 0.92 * a) if luminance > 0.55 else Color(1, 1, 1, 0.97 * a)
	var outline := Color(1, 1, 1, 0.7 * a) if luminance > 0.55 else Color(0, 0, 0, 0.55 * a)
	var grow := maxf(1.4, r * 0.16)
	_draw_shape(canvas, center, r, shape, outline, grow)
	_draw_shape(canvas, center, r, shape, fill, 0.0)


static func _draw_shape(canvas: CanvasItem, c: Vector2, r: float, shape: String, color: Color, grow: float) -> void:
	match shape:
		"circle":
			canvas.draw_circle(c, r * 0.62 + grow, color)
		"ring":
			canvas.draw_arc(c, r * 0.58, 0.0, TAU, 36, color, maxf(3.0, r * 0.38 + grow * 2.0), true)
		"plus":
			_draw_bar(canvas, c, r, 0.0, color, grow)
			_draw_bar(canvas, c, r, PI * 0.5, color, grow)
		"cross":
			_draw_bar(canvas, c, r, PI * 0.25, color, grow)
			_draw_bar(canvas, c, r, -PI * 0.25, color, grow)
		"bars":
			for i in range(3):
				var x := (float(i) - 1.0) * r * 0.58
				var half := Vector2(r * 0.2 + grow, r * 0.82 + grow)
				canvas.draw_rect(Rect2(c + Vector2(x, 0) - half, half * 2.0), color, true)
		_:
			var points := _polygon_for(shape, c, r)
			if points.size() < 3:
				canvas.draw_circle(c, r * 0.62 + grow, color)
				return
			if grow > 0.0:
				points = _scaled(points, c, (r + grow) / r)
			canvas.draw_colored_polygon(points, color)


static func _draw_bar(canvas: CanvasItem, c: Vector2, r: float, angle: float, color: Color, grow: float) -> void:
	var half_len := r * 0.92 + grow
	var half_w := maxf(2.2, r * 0.28 + grow)
	var axis := Vector2(cos(angle), sin(angle))
	var normal := Vector2(-axis.y, axis.x)
	canvas.draw_colored_polygon(PackedVector2Array([
		c + axis * half_len + normal * half_w,
		c - axis * half_len + normal * half_w,
		c - axis * half_len - normal * half_w,
		c + axis * half_len - normal * half_w,
	]), color)


static func _polygon_for(shape: String, c: Vector2, r: float) -> PackedVector2Array:
	match shape:
		"square":
			# Más grande y angular que el círculo (0.62·r) para no confundirse.
			var s := r * 0.78
			return PackedVector2Array([c + Vector2(-s, -s), c + Vector2(s, -s), c + Vector2(s, s), c + Vector2(-s, s)])
		"triangle":
			return _regular(c + Vector2(0, r * 0.1), r * 0.98, 3, -PI * 0.5)
		"triangle_down":
			return _regular(c - Vector2(0, r * 0.1), r * 0.98, 3, PI * 0.5)
		"diamond":
			return _regular(c, r * 0.98, 4, -PI * 0.5)
		"pentagon":
			return _regular(c, r * 0.94, 5, -PI * 0.5)
		"hexagon":
			return _regular(c, r * 0.92, 6, 0.0)
		"octagon":
			return _regular(c, r * 0.9, 8, PI / 8.0)
		"star":
			var pts := PackedVector2Array()
			for i in range(10):
				var a := -PI * 0.5 + float(i) * PI / 5.0
				var rad := r if i % 2 == 0 else r * 0.45
				pts.append(c + Vector2(cos(a), sin(a)) * rad)
			return pts
		"heart":
			var heart := PackedVector2Array()
			for i in range(32):
				var t := TAU * float(i) / 32.0
				var x := 16.0 * pow(sin(t), 3)
				var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
				heart.append(c + Vector2(x, -y - 2.0) * (r / 16.0))
			return heart
		"moon":
			return _crescent(c, r * 0.85)
		"hourglass":
			var a := r * 0.78
			return PackedVector2Array([
				c + Vector2(-a, -a), c + Vector2(a, -a), c + Vector2(a * 0.18, 0),
				c + Vector2(a, a), c + Vector2(-a, a), c + Vector2(-a * 0.18, 0),
			])
	return PackedVector2Array()


static func _regular(c: Vector2, r: float, sides: int, start: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var a := start + TAU * float(i) / float(sides)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## Media luna: círculo exterior menos otro igual desplazado a la derecha.
static func _crescent(c: Vector2, radius: float) -> PackedVector2Array:
	var d := radius * 0.62
	var half_chord := sqrt(maxf(0.0, radius * radius - d * d * 0.25))
	var phi := atan2(half_chord, d * 0.5)
	var pts := PackedVector2Array()
	var steps := 20
	for i in range(steps + 1):
		var a := lerpf(phi, TAU - phi, float(i) / float(steps))
		pts.append(c + Vector2(cos(a), sin(a)) * radius)
	var inner_center := c + Vector2(d, 0)
	for i in range(1, steps):
		var a := lerpf(PI + phi, PI - phi, float(i) / float(steps))
		pts.append(inner_center + Vector2(cos(a), sin(a)) * radius)
	return pts


static func _scaled(points: PackedVector2Array, c: Vector2, factor: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(c + (p - c) * factor)
	return out
