extends Control

## Fondo glossy (estilo menú principal) dibujado detrás de un Button.
## El Button conserva su texto, señales y estado; este nodo solo pinta.

var base_color: Color = Color("FFC52E")
var icon: int = 0
var icon_color: Color = Color.WHITE
var icon_centered: bool = false


static func depth_for(height: float) -> float:
	return clampf(height * 0.08, 5.0, 8.0)


static func radius_for(height: float) -> int:
	return int(clampf(height * 0.27, 14.0, 26.0))


func _ready() -> void:
	show_behind_parent = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parent := get_parent() as CanvasItem
	if parent != null:
		parent.draw.connect(queue_redraw)


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.anti_aliasing = true
	return sb


func _draw() -> void:
	if not is_finite(size.x) or not is_finite(size.y) or size.x < 40.0 or size.y < 24.0 or size.x > 8192.0 or size.y > 8192.0:
		return
	var button := get_parent() as BaseButton
	var mode := button.get_draw_mode() if button != null else BaseButton.DRAW_NORMAL
	var hover := mode == BaseButton.DRAW_HOVER or mode == BaseButton.DRAW_HOVER_PRESSED
	var down := mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED
	var disabled := mode == BaseButton.DRAW_DISABLED

	var base := base_color
	if disabled:
		base = base.lerp(Color(0.55, 0.6, 0.72), 0.6)
	elif hover:
		base = base.lightened(0.07)

	var ci := get_canvas_item()
	var depth := depth_for(size.y)
	var radius := mini(radius_for(size.y), int(minf(size.x, size.y - depth_for(size.y)) * 0.5) - 1)
	var w := size.x
	var body_h := size.y - depth
	var press := depth * 0.4 if down else 0.0
	var base_rect := Rect2(0.0, depth, w, body_h)
	var body := Rect2(0.0, press, w, body_h)

	if not disabled:
		var glow := _box(Color(0, 0, 0, 0), radius)
		glow.shadow_color = Color(base.r, base.g, base.b, 0.4)
		glow.shadow_size = int(clampf(size.y * 0.15, 6.0, 16.0))
		glow.shadow_offset = Vector2(0, 5)
		glow.draw(ci, base_rect)

	_box(base.darkened(0.38), radius).draw(ci, base_rect)

	var main := _box(base, radius)
	main.border_color = base.lightened(0.5)
	main.border_width_left = 3
	main.border_width_top = 3
	main.border_width_right = 3
	main.border_width_bottom = 3
	main.draw(ci, body)

	var shade := _box(Color(base.darkened(0.16), 0.6), radius)
	shade.corner_radius_top_left = 0
	shade.corner_radius_top_right = 0
	shade.corner_radius_bottom_left = maxi(radius - 3, 0)
	shade.corner_radius_bottom_right = maxi(radius - 3, 0)
	shade.draw(ci, Rect2(body.position.x + 3.0, body.position.y + body_h * 0.52, w - 6.0, body_h * 0.48 - 3.0))

	var highlight := _box(Color(1, 1, 1, 0.24), maxi(radius - 8, 4))
	highlight.corner_radius_bottom_left = mini(12, radius)
	highlight.corner_radius_bottom_right = mini(12, radius)
	highlight.draw(ci, Rect2(body.position.x + 8.0, body.position.y + 5.0, w - 16.0, body_h * 0.38))

	draw_circle(body.position + Vector2(minf(26.0, radius + 4.0), minf(16.0, body_h * 0.2)), 3.0, Color(1, 1, 1, 0.6))

	if icon != UIFactory.ButtonIcon.NONE:
		var s := clampf(body_h / 90.0, 0.55, 1.15 if icon_centered else 1.0)
		var tint := icon_color
		if disabled:
			tint = Color(tint, 0.55)
		var icon_pos := Vector2(w * 0.5, body.position.y + body_h * 0.5) if icon_centered \
			else Vector2(body_h * 0.62, body.position.y + body_h * 0.5)
		_draw_icon(icon_pos, s, tint, base)


func _draw_icon(c: Vector2, s: float, col: Color, base: Color) -> void:
	var width := 4.0 * s
	match icon:
		UIFactory.ButtonIcon.PLAY:
			var tri := PackedVector2Array([c + Vector2(-12, -18) * s, c + Vector2(-12, 18) * s, c + Vector2(19, 0) * s])
			draw_colored_polygon(tri, col)
			draw_polyline(tri + PackedVector2Array([tri[0]]), col, width, true)
		UIFactory.ButtonIcon.MOUNTAIN:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-28, 15) * s, c + Vector2(-9, -14) * s, c + Vector2(1, -1) * s,
				c + Vector2(10, -17) * s, c + Vector2(29, 15) * s,
			]), col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-9, -14) * s, c + Vector2(-3, 4) * s, c + Vector2(1, -1) * s,
			]), col.lightened(0.25))
		UIFactory.ButtonIcon.GEAR:
			var pts := PackedVector2Array()
			for i in range(32):
				var a := TAU * float(i) / 32.0
				var r := 20.0 if (i % 4 == 1 or i % 4 == 2) else 14.5
				pts.append(c + Vector2(cos(a), sin(a)) * r * s)
			draw_colored_polygon(pts, col)
			draw_circle(c, 7.0 * s, base)
		UIFactory.ButtonIcon.EXIT:
			draw_polyline(PackedVector2Array([
				c + Vector2(2, -9) * s, c + Vector2(2, -17) * s, c + Vector2(-18, -17) * s,
				c + Vector2(-18, 17) * s, c + Vector2(2, 17) * s, c + Vector2(2, 9) * s,
			]), col, width, true)
			draw_line(c + Vector2(-7, 0) * s, c + Vector2(14, 0) * s, col, width, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(23, 0) * s, c + Vector2(12, -9) * s, c + Vector2(12, 9) * s]), col)
		UIFactory.ButtonIcon.BACK:
			draw_line(c + Vector2(18, 0) * s, c + Vector2(-8, 0) * s, col, width * 1.2, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-20, 0) * s, c + Vector2(-4, -14) * s, c + Vector2(-4, 14) * s]), col)
		UIFactory.ButtonIcon.GRID:
			for row in range(3):
				for column in range(3):
					var cell := Rect2(c + Vector2(-17 + column * 12, -17 + row * 12) * s, Vector2(10, 10) * s)
					draw_rect(cell, col, true)
		UIFactory.ButtonIcon.RESTART:
			draw_arc(c, 15.0 * s, deg_to_rad(-60.0), deg_to_rad(250.0), 32, col, width, true)
			var tip := c + Vector2(cos(deg_to_rad(-60.0)), sin(deg_to_rad(-60.0))) * 15.0 * s
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-9, -4) * s, tip + Vector2(6, -8) * s, tip + Vector2(3, 8) * s]), col)
		UIFactory.ButtonIcon.BULB:
			draw_circle(c + Vector2(0, -5) * s, 13.0 * s, col)
			draw_rect(Rect2(c + Vector2(-7, 6) * s, Vector2(14, 6) * s), col, true)
			draw_rect(Rect2(c + Vector2(-6, 14) * s, Vector2(12, 4) * s), col, true)
			draw_circle(c + Vector2(-4, -9) * s, 3.5 * s, Color(1, 1, 1, 0.75))
		UIFactory.ButtonIcon.HOME:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-20, -1) * s, c + Vector2(0, -19) * s, c + Vector2(20, -1) * s]), col)
			draw_rect(Rect2(c + Vector2(-14, -2) * s, Vector2(28, 19) * s), col, true)
			draw_rect(Rect2(c + Vector2(-4, 5) * s, Vector2(8, 12) * s), base, true)
		UIFactory.ButtonIcon.SOUND:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-18, -6) * s, c + Vector2(-10, -6) * s, c + Vector2(0, -15) * s,
				c + Vector2(0, 15) * s, c + Vector2(-10, 6) * s, c + Vector2(-18, 6) * s,
			]), col)
			draw_arc(c + Vector2(2, 0) * s, 8.0 * s, -PI * 0.35, PI * 0.35, 12, col, width * 0.8, true)
			draw_arc(c + Vector2(2, 0) * s, 15.0 * s, -PI * 0.35, PI * 0.35, 16, col, width * 0.8, true)
		UIFactory.ButtonIcon.SOUND_MUTE:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-18, -6) * s, c + Vector2(-10, -6) * s, c + Vector2(0, -15) * s,
				c + Vector2(0, 15) * s, c + Vector2(-10, 6) * s, c + Vector2(-18, 6) * s,
			]), col)
			draw_line(c + Vector2(6, -12) * s, c + Vector2(20, 12) * s, col, width * 1.15, true)
			draw_line(c + Vector2(20, -12) * s, c + Vector2(6, 12) * s, col, width * 1.15, true)
		UIFactory.ButtonIcon.VIBRATION:
			var phone := _box(col, int(4.0 * s))
			phone.draw(get_canvas_item(), Rect2(c + Vector2(-8, -16) * s, Vector2(16, 32) * s))
			draw_rect(Rect2(c + Vector2(-5, -12) * s, Vector2(10, 21) * s), base, true)
			for side: float in [-1.0, 1.0]:
				draw_line(c + Vector2(13 * side, -8) * s, c + Vector2(13 * side, 8) * s, col, width * 0.8, true)
				draw_line(c + Vector2(19 * side, -5) * s, c + Vector2(19 * side, 5) * s, col, width * 0.8, true)
		UIFactory.ButtonIcon.SPARKLE:
			_draw_sparkle(c + Vector2(-3, 2) * s, 15.0 * s, col)
			_draw_sparkle(c + Vector2(13, -11) * s, 7.0 * s, col)
		UIFactory.ButtonIcon.EYE:
			var outline := PackedVector2Array()
			for i in range(33):
				var t := float(i) / 32.0
				var x := lerpf(-21.0, 21.0, t)
				outline.append(c + Vector2(x, -sin(t * PI) * 12.0) * s)
			for i in range(1, 32):
				var t := 1.0 - float(i) / 32.0
				var x := lerpf(-21.0, 21.0, t)
				outline.append(c + Vector2(x, sin(t * PI) * 12.0) * s)
			draw_colored_polygon(outline, col)
			draw_circle(c, 7.5 * s, base)
			draw_circle(c, 3.5 * s, col)


func _draw_sparkle(center: Vector2, r: float, col: Color) -> void:
	var inner := r * 0.28
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -r), center + Vector2(inner, -inner), center + Vector2(r, 0), center + Vector2(inner, inner),
		center + Vector2(0, r), center + Vector2(-inner, inner), center + Vector2(-r, 0), center + Vector2(-inner, -inner),
	]), col)
