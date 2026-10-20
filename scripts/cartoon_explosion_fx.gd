class_name CartoonExplosionFx
extends ColorRect

## Explosión cartoon en el centro de una casilla (una bola).
## Origen: https://godotshaders.com/shader/cartoon-explosion-effect/
## Móvil: shader lite (sin worley/grad) + half-res (fill-rate).

const SHADER := preload("res://shaders/cartoon_explosion.gdshader")
const SHADER_LITE := preload("res://shaders/cartoon_explosion_lite.gdshader")
const BoardDestroyFxScript := preload("res://scripts/board_destroy_fx.gd")
const MOBILE_DRAW_SCALE := 0.5
## Tween de start_explosion: explosion_time 0 → este valor.
const EXPLOSION_TIME_END := 1.95
## Con boom_repeat=1, el radio del fuego es máximo en explosion_time=0.25
## (máx. de r*(1-2r) en el shader boom()).
const PEAK_SIZE_EXPLOSION_TIME := 0.25

var _mat: ShaderMaterial


## Segundos desde el inicio del boom hasta el tamaño máximo del fuego.
static func seconds_until_peak_size(duration_sec: float) -> float:
	var dur := maxf(0.35, duration_sec)
	return dur * (PEAK_SIZE_EXPLOSION_TIME / EXPLOSION_TIME_END)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	visible = false


## draw_scale_override > 0: fuerza undersample (p. ej. cinemática era en móvil).
func setup_at(
	center: Vector2,
	diameter: float,
	tint: Color = Color.WHITE,
	draw_scale_override: float = -1.0
) -> void:
	var visual_side := maxf(diameter, 20.0)
	var mobile := BoardDestroyFxScript.is_mobile_device()
	var draw_scale := 1.0
	if draw_scale_override > 0.0:
		draw_scale = clampf(draw_scale_override, 0.2, 1.0)
	elif mobile:
		draw_scale = MOBILE_DRAW_SCALE
	var side := visual_side * draw_scale
	size = Vector2(side, side)
	custom_minimum_size = size
	scale = Vector2(1.0 / draw_scale, 1.0 / draw_scale) if draw_scale < 0.999 else Vector2.ONE
	# Esquina superior-izquierda del rectángulo visual (tras scale).
	position = center - Vector2(visual_side, visual_side) * 0.5
	color = Color(1, 1, 1, 1)
	modulate = Color(1, 1, 1, 1)
	if mobile and SHADER_LITE != null:
		_mat.shader = SHADER_LITE
	else:
		_mat.shader = SHADER
	_mat.set_shader_parameter("aspect", 1.0)
	_mat.set_shader_parameter("size", 3.6)
	_mat.set_shader_parameter("explosion_time", 0.0)
	_mat.set_shader_parameter("boom_pal1", Vector3(tint.r * 0.35, tint.g * 0.25, tint.b * 0.4))
	_mat.set_shader_parameter("boom_pal2", Vector3(tint.r, tint.g * 0.25, tint.b * 0.15))
	_mat.set_shader_parameter("boom_pal3", Vector3(minf(1.0, tint.r * 1.1), minf(1.0, tint.g * 0.75 + 0.2), tint.b * 0.25))
	_mat.set_shader_parameter("boom_pal4", Vector3(0.98, 0.95, 0.55))
	_mat.set_shader_parameter("smoke_pal1", Vector3(tint.r * 0.3, tint.g * 0.25, tint.b * 0.35))
	_mat.set_shader_parameter("smoke_pal2", Vector3(tint.r * 0.45, tint.g * 0.4, tint.b * 0.5))
	_mat.set_shader_parameter("smoke_pal3", Vector3(tint.r * 0.6, tint.g * 0.55, tint.b * 0.65))


## Arranca la animación (no hace falta await: el tablero espera el mismo tiempo).
func start_explosion(duration_sec: float) -> void:
	if _mat == null:
		return
	visible = true
	_mat.set_shader_parameter("explosion_time", 0.0)
	var dur := maxf(0.35, duration_sec)
	var tw := create_tween()
	tw.tween_method(_set_explosion_time, 0.0, 1.95, dur).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(func() -> void:
		if is_instance_valid(self):
			visible = false
	)


func _set_explosion_time(t: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("explosion_time", t)
