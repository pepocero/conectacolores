class_name BoardDestroyFx
extends TextureRect

## Una sola instancia: destruye la textura completa del tablero con board_destroy.gdshader.
## Valores afinados desde la pantalla de prueba (baseline aprobado).
## Móvil: shader lite + menos trozos + draw a media resolución (fill-rate).

const SHADER := preload("res://shaders/board_destroy.gdshader")
const SHADER_LITE := preload("res://shaders/board_destroy_lite.gdshader")

const DEFAULT_DURATION := 3.75
const HOLD_BEFORE_FALL_SEC := 0.0
const DEFAULT_END_FALL := 1.0
const DEFAULT_END_ROTATION := 3.40
const DEFAULT_END_SCATTER := 1.27
const DEFAULT_END_FADE := 1.0
const DEFAULT_FADE_DELAY := 0.0
const DEFAULT_MESH_SCALE := 1.60
const DEFAULT_GRAVITY := 4.0
const DEFAULT_GROUND := 1.0
const DEFAULT_STACK := 0.03
const DEFAULT_SLIDE := 0.20
## Trozos por eje (escritorio / baseline).
const DEFAULT_PIECES := 35.0
## Móvil + shader lite (25: validado en preview, fluido).
const MOBILE_PIECES := 25.0
const MOBILE_DRAW_SCALE := 0.5

## Forzar perfil móvil en editor (simulación).
static var force_mobile_profile: bool = false

var _mat: ShaderMaterial
var _use_mobile_profile: bool = false


static func is_mobile_device() -> bool:
	if force_mobile_profile:
		return true
	return (
		OS.has_feature("mobile")
		or OS.has_feature("android")
		or OS.has_feature("ios")
	)


static func pieces_for_device() -> float:
	if FxQuality != null:
		return FxQuality.destroy_pieces()
	return MOBILE_PIECES if is_mobile_device() else DEFAULT_PIECES


static func _use_lite_shader() -> bool:
	if FxQuality != null:
		return FxQuality.use_lite_shader()
	return is_mobile_device()


static func _default_draw_scale() -> float:
	if FxQuality != null:
		return FxQuality.destroy_draw_scale()
	return MOBILE_DRAW_SCALE if is_mobile_device() else 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	_use_mobile_profile = _use_lite_shader()
	_mat = ShaderMaterial.new()
	if _use_mobile_profile:
		_mat.shader = SHADER_LITE if SHADER_LITE != null else SHADER
	else:
		_mat.shader = SHADER
	if _mat.shader == null:
		_mat.shader = SHADER
	material = _mat
	visible = false


## board_rect en coordenadas globales (el nodo usa top_level).
## draw_scale_override > 0: fuerza undersample (p. ej. cinemática era en móvil).
func setup(
	tex: Texture2D,
	board_rect: Rect2,
	shatter_grid: Vector2 = Vector2.ZERO,
	draw_scale_override: float = -1.0
) -> void:
	texture = tex
	_use_mobile_profile = _use_lite_shader()
	if _use_mobile_profile:
		_mat.shader = SHADER_LITE if SHADER_LITE != null else SHADER
	else:
		_mat.shader = SHADER

	var pieces := shatter_grid
	if pieces.x < 1.0 or pieces.y < 1.0:
		pieces = Vector2(pieces_for_device(), pieces_for_device())

	var draw_scale := 1.0
	if draw_scale_override > 0.0:
		draw_scale = clampf(draw_scale_override, 0.2, 1.0)
	else:
		draw_scale = _default_draw_scale()
	var local_size := board_rect.size * draw_scale
	scale = Vector2(1.0 / draw_scale, 1.0 / draw_scale) if draw_scale < 0.999 else Vector2.ONE
	# Con scale>1 el origin del control es la esquina; position = global top-left del tablero.
	position = board_rect.position
	size = local_size
	custom_minimum_size = local_size

	_mat.set_shader_parameter("rect_size", local_size)
	_mat.set_shader_parameter("grid_size", pieces)
	_mat.set_shader_parameter("mesh_scale", DEFAULT_MESH_SCALE)
	_mat.set_shader_parameter("gravity", DEFAULT_GRAVITY)
	_mat.set_shader_parameter("ground_level", DEFAULT_GROUND)
	_mat.set_shader_parameter("stack_variation", DEFAULT_STACK)
	_mat.set_shader_parameter("slide_on_ground", DEFAULT_SLIDE)
	_mat.set_shader_parameter("progress_fall", 0.0)
	_mat.set_shader_parameter("progress_rotation", 0.0)
	_mat.set_shader_parameter("progress_scatter", 0.0)
	_mat.set_shader_parameter("progress_fade", 0.0)
	visible = true


func play(duration_sec: float = DEFAULT_DURATION) -> void:
	if _mat == null or texture == null:
		return
	visible = true
	await get_tree().process_frame
	if HOLD_BEFORE_FALL_SEC > 0.0:
		await get_tree().create_timer(HOLD_BEFORE_FALL_SEC).timeout
	if not is_instance_valid(self):
		return
	var dur := maxf(0.5, duration_sec)
	var fade_delay_ratio := clampf(DEFAULT_FADE_DELAY, 0.0, 0.9)
	var fade_dur := maxf(0.15, dur * (1.0 - fade_delay_ratio))
	var measure := FxQuality != null and not FxQuality.calibrated
	if measure:
		FxQuality.begin_measure()
	var log_fps := measure or _use_mobile_profile or force_mobile_profile
	var fps_acc := 0.0
	var fps_samples := 0
	var fps_tick := 0.0
	if log_fps:
		print(
			"[BoardDestroyFx] profile=%s pieces=%.0f size=%s scale=%s shader_lite=%s"
			% [
				FxQuality.profile if FxQuality != null else "?",
				pieces_for_device(),
				str(size),
				str(scale),
				str(_mat.shader == SHADER_LITE),
			]
		)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(_set_fall, 0.0, DEFAULT_END_FALL, dur * 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_method(_set_rotation, 0.0, DEFAULT_END_ROTATION, dur).set_trans(Tween.TRANS_LINEAR)
	tw.tween_method(_set_scatter, 0.0, DEFAULT_END_SCATTER, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_fade, 0.0, DEFAULT_END_FADE, fade_dur).set_delay(dur * fade_delay_ratio).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if log_fps:
		while tw.is_running() and is_instance_valid(self):
			await get_tree().process_frame
			fps_tick += get_process_delta_time()
			if fps_tick >= 0.25:
				var fps := Engine.get_frames_per_second()
				fps_acc += fps
				fps_samples += 1
				if FxQuality != null:
					FxQuality.sample_fps(fps)
				print("[BoardDestroyFx] fps=%.1f" % fps)
				fps_tick = 0.0
		if fps_samples > 0:
			print("[BoardDestroyFx] fps_avg=%.1f" % (fps_acc / float(fps_samples)))
		if measure and FxQuality != null:
			FxQuality.end_measure()
	else:
		await tw.finished
	if is_instance_valid(self):
		visible = false


func _set_fall(v: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("progress_fall", v)


func _set_rotation(v: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("progress_rotation", v)


func _set_scatter(v: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("progress_scatter", v)


func _set_fade(v: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("progress_fade", v)
