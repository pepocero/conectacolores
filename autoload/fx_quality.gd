extends Node

## Perfiles de calidad FX (low / mid / high) según FPS medidos.
## Escritorio parte en high; móvil en mid; se recalibra tras el primer destroy/victory.

const PROFILE_LOW := "low"
const PROFILE_MID := "mid"
const PROFILE_HIGH := "high"

const FPS_LOW_MAX := 28.0
const FPS_MID_MAX := 45.0

var profile: String = PROFILE_HIGH
var calibrated: bool = false

var _measuring: bool = false
var _fps_acc: float = 0.0
var _fps_n: int = 0


func _ready() -> void:
	sync_from_save()
	if not calibrated:
		profile = PROFILE_MID if _is_mobile() else PROFILE_HIGH


func sync_from_save() -> void:
	if SaveManager == null:
		return
	var p := str(SaveManager.fx_quality_profile)
	if p == PROFILE_LOW or p == PROFILE_MID or p == PROFILE_HIGH:
		profile = p
	calibrated = bool(SaveManager.fx_quality_calibrated)


func persist() -> void:
	if SaveManager == null:
		return
	SaveManager.set_fx_quality_profile(profile, calibrated)


## Al cambiar «Efectos visuales», permitir recalibrar en el próximo FX.
func request_recalibrate() -> void:
	calibrated = false
	_measuring = false
	_fps_acc = 0.0
	_fps_n = 0
	if not _is_mobile():
		profile = PROFILE_HIGH
	elif profile == PROFILE_HIGH:
		profile = PROFILE_MID
	persist()


func _is_mobile() -> bool:
	return (
		OS.has_feature("mobile")
		or OS.has_feature("android")
		or OS.has_feature("ios")
	)


func is_low() -> bool:
	return profile == PROFILE_LOW


func is_high() -> bool:
	return profile == PROFILE_HIGH


func use_lite_shader() -> bool:
	# High en escritorio: shader completo. Resto: lite.
	if profile == PROFILE_HIGH and not _is_mobile():
		return false
	return true


func destroy_pieces() -> float:
	match profile:
		PROFILE_LOW:
			return 14.0
		PROFILE_MID:
			return 25.0
		_:
			return 35.0


func destroy_draw_scale() -> float:
	match profile:
		PROFILE_LOW:
			return 0.38
		PROFILE_MID:
			return 0.5
		_:
			return 1.0 if not _is_mobile() else 0.5


## Escala por boom según nº de explosiones simultáneas (todas las bolas).
func boom_draw_scale(boom_count: int) -> float:
	var base := destroy_draw_scale()
	var n := maxi(0, boom_count)
	if n <= 6:
		return base
	if n <= 12:
		return minf(base, 0.32 if profile == PROFILE_LOW else 0.4)
	return minf(base, 0.25 if profile != PROFILE_HIGH else 0.32)


func boom_force_lite(boom_count: int) -> bool:
	return boom_count > 6 or use_lite_shader()


func boom_duration_scale(boom_count: int) -> float:
	if boom_count > 12 and profile == PROFILE_LOW:
		return 0.85
	return 1.0


func victory_confetti_count() -> int:
	match profile:
		PROFILE_LOW:
			return 12
		PROFILE_MID:
			return 20
		_:
			return 28


func victory_droplet_count() -> int:
	match profile:
		PROFILE_LOW:
			return 4
		PROFILE_MID:
			return 8
		_:
			return 10


func victory_spark_count() -> int:
	match profile:
		PROFILE_LOW:
			return 0
		PROFILE_MID:
			return 4
		_:
			return 8


func begin_measure() -> void:
	if calibrated:
		return
	_measuring = true
	_fps_acc = 0.0
	_fps_n = 0


func sample_fps(fps: float = -1.0) -> void:
	if not _measuring:
		return
	var v := fps if fps > 0.0 else Engine.get_frames_per_second()
	_fps_acc += v
	_fps_n += 1


func end_measure() -> void:
	if not _measuring:
		return
	_measuring = false
	if _fps_n <= 0:
		return
	var avg := _fps_acc / float(_fps_n)
	var next := PROFILE_HIGH
	if avg < FPS_LOW_MAX:
		next = PROFILE_LOW
	elif avg < FPS_MID_MAX:
		next = PROFILE_MID
	profile = next
	calibrated = true
	persist()
	print("[FxQuality] calibrated avg_fps=%.1f → %s" % [avg, profile])
