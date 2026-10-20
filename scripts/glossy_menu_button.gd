extends Control

## Botón glossy del menú principal con icono dibujado a la izquierda.

signal pressed

enum Icon { NONE, PLAY, MOUNTAIN, GEAR, EXIT, FLAME }

const DEPTH := 8.0
const RADIUS := 26

var _text: String = ""
var _base: Color = Color("FF8A1F")
var _text_color: Color = Color.WHITE
var _icon: int = Icon.NONE
var _icon_color: Color = Color.WHITE
var _button: Button
var _hover: bool = false
var _down: bool = false
var _locked: bool = false
## Textura de relleno opcional (p. ej. fondo psicodélico del Modo Crazy).
var _fill_tex: Texture2D = null


func setup(text: String, base: Color, text_color: Color, icon: int, icon_color: Color, height: float = 96.0) -> void:
	_text = text
	_base = base
	_text_color = text_color
	_icon = icon
	_icon_color = icon_color
	custom_minimum_size = Vector2(0, height)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _button != null:
		_apply_button_style()
	queue_redraw()


func set_fill_texture(tex: Texture2D) -> void:
	_fill_tex = tex
	queue_redraw()


func set_locked(locked: bool) -> void:
	_locked = locked
	if _button != null:
		_apply_button_style()
	queue_redraw()


func _ready() -> void:
	_button = Button.new()
	_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_button)
	_apply_button_style()
	_button.pressed.connect(_on_pressed)
	_button.mouse_entered.connect(_on_hover.bind(true))
	_button.mouse_exited.connect(_on_hover.bind(false))
	_button.button_down.connect(_on_down.bind(true))
	_button.button_up.connect(_on_down.bind(false))
	resized.connect(queue_redraw)


func _apply_button_style() -> void:
	_button.text = _text
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = 64.0 if _icon != Icon.NONE else 0.0
		sb.content_margin_right = 40.0 if _locked else 0.0
		sb.content_margin_bottom = DEPTH
		_button.add_theme_stylebox_override(state, sb)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		_button.add_theme_color_override(key, _text_color)
	_button.add_theme_font_size_override("font_size", 30)
	UIFactory.apply_font(_button, true)


func _on_hover(value: bool) -> void:
	_hover = value
	queue_redraw()


func _on_down(value: bool) -> void:
	_down = value
	queue_redraw()


func _on_pressed() -> void:
	pivot_offset = size * 0.5
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.96, 0.96), 0.06)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pressed.emit()


func _box(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = RADIUS
	sb.corner_radius_top_right = RADIUS
	sb.corner_radius_bottom_left = RADIUS
	sb.corner_radius_bottom_right = RADIUS
	sb.anti_aliasing = true
	return sb


func _draw() -> void:
	if size.x < 4.0:
		return
	var ci := get_canvas_item()
	var w := size.x
	var body_h := size.y - DEPTH
	var press := 3.0 if _down else 0.0
	var base_rect := Rect2(0.0, DEPTH, w, body_h)
	var body := Rect2(0.0, press, w, body_h)

	var glow := _box(Color(0, 0, 0, 0))
	glow.shadow_color = Color(_base.r, _base.g, _base.b, 0.45)
	glow.shadow_size = 16
	glow.shadow_offset = Vector2(0, 6)
	glow.draw(ci, base_rect)

	_box(_base.darkened(0.38)).draw(ci, base_rect)

	var fill := _base.darkened(0.28) if _locked else _base
	if _hover and not _locked:
		fill = _base.lightened(0.07)
	var main := _box(fill)
	main.border_color = _base.lightened(0.5)
	main.border_width_left = 3
	main.border_width_top = 3
	main.border_width_right = 3
	main.border_width_bottom = 3

	if _fill_tex != null:
		# Placa redondeada (esquinas) + foto psicodélica + borde.
		_box(Color("3A1058")).draw(ci, body)
		_draw_fill_texture(body)
		var veil_a := 0.28 if _locked else (0.12 if _hover else 0.18)
		_box(Color(0.08, 0.0, 0.18, veil_a)).draw(ci, body)
		main.bg_color = Color(0, 0, 0, 0)
		main.draw(ci, body)
	else:
		main.draw(ci, body)

	var shade_a := 0.35 if _fill_tex != null else 0.6
	var shade := _box(Color(_base.darkened(0.16), shade_a))
	shade.corner_radius_top_left = 0
	shade.corner_radius_top_right = 0
	shade.corner_radius_bottom_left = RADIUS - 3
	shade.corner_radius_bottom_right = RADIUS - 3
	shade.draw(ci, Rect2(body.position.x + 3.0, body.position.y + body_h * 0.52, w - 6.0, body_h * 0.48 - 3.0))

	var hi_a := 0.14 if _fill_tex != null else 0.24
	var highlight := _box(Color(1, 1, 1, hi_a))
	highlight.corner_radius_top_left = RADIUS - 8
	highlight.corner_radius_top_right = RADIUS - 8
	highlight.corner_radius_bottom_left = 12
	highlight.corner_radius_bottom_right = 12
	highlight.draw(ci, Rect2(body.position.x + 10.0, body.position.y + 6.0, w - 20.0, body_h * 0.38))

	draw_circle(body.position + Vector2(26.0, 16.0), 3.5, Color(1, 1, 1, 0.6))

	_draw_icon(Vector2(58.0, body.position.y + body_h * 0.5), body_h / 90.0)
	if _locked:
		_draw_lock(Vector2(w - 42.0, body.position.y + body_h * 0.5), body_h / 90.0)


func _draw_fill_texture(body: Rect2) -> void:
	if _fill_tex == null:
		return
	var tw := float(_fill_tex.get_width())
	var th := float(_fill_tex.get_height())
	if tw < 1.0 or th < 1.0 or body.size.x < 4.0 or body.size.y < 4.0:
		return
	# Solo dentro del botón (sin desbordar al modal). Cover + recorte.
	var inset := 4.0
	var area := Rect2(
		body.position.x + inset,
		body.position.y + inset,
		maxi(2.0, body.size.x - inset * 2.0),
		maxi(2.0, body.size.y - inset * 2.0)
	)
	var area_aspect := area.size.x / area.size.y
	var tex_aspect := tw / th
	var src: Rect2
	if area_aspect > tex_aspect:
		var src_h := tw / area_aspect
		src = Rect2(0.0, (th - src_h) * 0.5, tw, src_h)
	else:
		var src_w := th * area_aspect
		src = Rect2((tw - src_w) * 0.5, 0.0, src_w, th)
	draw_texture_rect_region(_fill_tex, area, src)


func _draw_lock(c: Vector2, s: float) -> void:
	var metal := Color(0.93, 0.93, 0.97)
	var dark := Color(0.18, 0.14, 0.22, 0.9)
	draw_arc(c + Vector2(0, -7) * s, 9.0 * s, PI, TAU, 18, metal, 3.6 * s, true)
	draw_rect(Rect2(c + Vector2(-12, -4) * s, Vector2(24, 18) * s), metal, true)
	draw_rect(Rect2(c + Vector2(-12, -4) * s, Vector2(24, 18) * s), dark, false, 1.6 * s)
	draw_circle(c + Vector2(0, 4) * s, 3.2 * s, dark)


func _draw_icon(c: Vector2, s: float) -> void:
	match _icon:
		Icon.PLAY:
			var tri := PackedVector2Array([
				c + Vector2(-12, -18) * s,
				c + Vector2(-12, 18) * s,
				c + Vector2(19, 0) * s,
			])
			var shadow := PackedVector2Array()
			for p: Vector2 in tri:
				shadow.append(p + Vector2(0, 2.5 * s))
			draw_colored_polygon(shadow, Color(0, 0, 0, 0.18))
			draw_colored_polygon(tri, _icon_color)
			draw_polyline(tri + PackedVector2Array([tri[0]]), _icon_color, 4.0 * s, true)
		Icon.MOUNTAIN:
			var mountain := PackedVector2Array([
				c + Vector2(-28, 15) * s,
				c + Vector2(-9, -14) * s,
				c + Vector2(1, -1) * s,
				c + Vector2(10, -17) * s,
				c + Vector2(29, 15) * s,
			])
			draw_colored_polygon(mountain, _icon_color)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-9, -14) * s,
				c + Vector2(-3, 4) * s,
				c + Vector2(1, -1) * s,
			]), _icon_color.lightened(0.25))
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(10, -17) * s,
				c + Vector2(15, 4) * s,
				c + Vector2(29, 15) * s,
			]), _icon_color.lightened(0.18))
		Icon.GEAR:
			var teeth := 8
			var pts := PackedVector2Array()
			for i in range(teeth * 4):
				var a := TAU * float(i) / float(teeth * 4)
				var r := 20.0 if (i % 4 == 1 or i % 4 == 2) else 14.5
				pts.append(c + Vector2(cos(a), sin(a)) * r * s)
			draw_colored_polygon(pts, _icon_color)
			draw_circle(c, 7.0 * s, _base)
		Icon.EXIT:
			var width := 4.0 * s
			draw_polyline(PackedVector2Array([
				c + Vector2(2, -9) * s,
				c + Vector2(2, -17) * s,
				c + Vector2(-18, -17) * s,
				c + Vector2(-18, 17) * s,
				c + Vector2(2, 17) * s,
				c + Vector2(2, 9) * s,
			]), _icon_color, width, true)
			draw_line(c + Vector2(-7, 0) * s, c + Vector2(14, 0) * s, _icon_color, width, true)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(23, 0) * s,
				c + Vector2(12, -9) * s,
				c + Vector2(12, 9) * s,
			]), _icon_color)
		Icon.FLAME:
			var flame := PackedVector2Array([
				c + Vector2(0, -20) * s,
				c + Vector2(10, -6) * s,
				c + Vector2(12, 6) * s,
				c + Vector2(6, 16) * s,
				c + Vector2(-6, 16) * s,
				c + Vector2(-12, 6) * s,
				c + Vector2(-8, -8) * s,
			])
			draw_colored_polygon(flame, _icon_color)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -4) * s,
				c + Vector2(5, 8) * s,
				c + Vector2(-5, 8) * s,
			]), _icon_color.lightened(0.35))
