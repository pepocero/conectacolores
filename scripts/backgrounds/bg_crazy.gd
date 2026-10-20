extends BgPhotoBase

## Fondo psicodélico estático del Modo Crazy (sin FX animados).


func _ready() -> void:
	photo_path = "res://assets/backgrounds/crazy.jpg"
	super._ready()
	set_process(false)


func setup_fx() -> void:
	pass


func draw_fx() -> void:
	pass


func draw_photo_cover() -> void:
	if _tex == null:
		draw_rect(Rect2(Vector2.ZERO, size), Color("2A1050"), true)
		return
	var tw := float(_tex.get_width())
	var th := float(_tex.get_height())
	if tw < 1.0 or th < 1.0:
		return
	var sc := maxf(size.x / tw, size.y / th)
	var dw := tw * sc
	var dh := th * sc
	var ox := (size.x - dw) * 0.5
	var oy := (size.y - dh) * 0.5
	draw_texture_rect(_tex, Rect2(ox, oy, dw, dh), false)
	# Ligero velo para legibilidad de UI; sin oscurecer el color.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.0, 0.12, 0.10), true)
