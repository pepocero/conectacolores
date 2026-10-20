class_name BgPhotoBase
extends Control

## Foto a pantalla completa + capa FX animada encima.

var photo_path: String = ""
var _tex: Texture2D
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()
var _fx_paused: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	_tex = load_photo(photo_path)
	resized.connect(queue_redraw)
	set_process(true)
	if not SettingsManager.settings_changed.is_connected(_on_settings):
		SettingsManager.settings_changed.connect(_on_settings)
	setup_fx()


func _exit_tree() -> void:
	if SettingsManager.settings_changed.is_connected(_on_settings):
		SettingsManager.settings_changed.disconnect(_on_settings)


func _on_settings() -> void:
	if _fx_paused:
		return
	queue_redraw()


func setup_fx() -> void:
	pass


## Congela lluvia/nubes/FX del fondo (p. ej. durante celebración de booms).
func set_fx_paused(paused: bool) -> void:
	if _fx_paused == paused:
		return
	_fx_paused = paused
	set_process(not paused)
	for child in get_children():
		if child.has_method("set_fx_paused"):
			child.call("set_fx_paused", paused)
		elif child is CanvasItem:
			(child as CanvasItem).set_process(not paused and SettingsManager.fx_enabled)
	if not paused:
		queue_redraw()


func _process(delta: float) -> void:
	if _fx_paused:
		return
	if SettingsManager.fx_enabled:
		_time += delta
		process_fx(delta)
	queue_redraw()


func process_fx(_delta: float) -> void:
	pass


func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	draw_photo_cover()
	draw_fx()


func draw_photo_cover() -> void:
	if _tex == null:
		draw_rect(Rect2(Vector2.ZERO, size), Color("1A2748"), true)
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
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.16), true)


func draw_fx() -> void:
	pass


func draw_soft_cloud(rel_x: float, rel_y: float, rel_w: float, col: Color) -> void:
	var w := size.x
	var h := size.y
	var cx := rel_x * w
	var cy := rel_y * h
	var rw := rel_w * w
	var rh := rw * 0.38
	draw_circle(Vector2(cx - rw * 0.28, cy + rh * 0.1), rw * 0.28, col)
	draw_circle(Vector2(cx + rw * 0.22, cy + rh * 0.12), rw * 0.32, col)
	draw_circle(Vector2(cx, cy - rh * 0.15), rw * 0.36, col)
	draw_circle(Vector2(cx - rw * 0.08, cy + rh * 0.05), rw * 0.3, col)
	draw_circle(Vector2(cx + rw * 0.08, cy - rh * 0.05), rw * 0.26, col)


static func load_photo(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res as Texture2D
	var img := Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	return null
