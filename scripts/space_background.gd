class_name SpaceBackground
extends Control

## Fondo de espacio exterior (shader starfield). Perfil ligero en móvil.

const BoardDestroyFxScript := preload("res://scripts/board_destroy_fx.gd")
const STARFIELD_SHADER := preload("res://shaders/space_starfield.gdshader")

const PALETTES: Array[Dictionary] = [
	{
		"nebula": [
			Color(0.12, 0.05, 0.28, 1.0),
			Color(0.04, 0.08, 0.22, 1.0),
			Color(0.02, 0.02, 0.08, 1.0),
		],
		"veil": Color(0.01, 0.01, 0.05, 0.55),
		"haze_a": Color(0.35, 0.1, 0.55, 0.08),
		"haze_b": Color(0.1, 0.25, 0.55, 0.07),
	},
	{
		"nebula": [
			Color(0.10, 0.32, 0.38, 1.0),
			Color(0.05, 0.18, 0.26, 1.0),
			Color(0.02, 0.08, 0.14, 1.0),
		],
		"veil": Color(0.02, 0.08, 0.10, 0.28),
		"haze_a": Color(0.20, 0.70, 0.65, 0.16),
		"haze_b": Color(0.12, 0.45, 0.75, 0.14),
	},
	{
		"nebula": [
			Color(0.38, 0.10, 0.16, 1.0),
			Color(0.22, 0.05, 0.10, 1.0),
			Color(0.10, 0.02, 0.05, 1.0),
		],
		"veil": Color(0.10, 0.02, 0.04, 0.28),
		"haze_a": Color(0.75, 0.18, 0.28, 0.16),
		"haze_b": Color(0.55, 0.12, 0.40, 0.14),
	},
	{
		"nebula": [
			Color(0.18, 0.14, 0.42, 1.0),
			Color(0.10, 0.08, 0.28, 1.0),
			Color(0.04, 0.03, 0.14, 1.0),
		],
		"veil": Color(0.04, 0.03, 0.12, 0.28),
		"haze_a": Color(0.40, 0.28, 0.85, 0.16),
		"haze_b": Color(0.22, 0.40, 0.80, 0.14),
	},
	{
		"nebula": [
			Color(0.10, 0.34, 0.18, 1.0),
			Color(0.05, 0.20, 0.12, 1.0),
			Color(0.02, 0.09, 0.05, 1.0),
		],
		"veil": Color(0.02, 0.08, 0.04, 0.28),
		"haze_a": Color(0.25, 0.75, 0.35, 0.16),
		"haze_b": Color(0.15, 0.55, 0.45, 0.14),
	},
	{
		"nebula": [
			Color(0.36, 0.22, 0.08, 1.0),
			Color(0.22, 0.12, 0.04, 1.0),
			Color(0.10, 0.05, 0.02, 1.0),
		],
		"veil": Color(0.10, 0.05, 0.02, 0.28),
		"haze_a": Color(0.80, 0.45, 0.12, 0.16),
		"haze_b": Color(0.60, 0.28, 0.10, 0.14),
	},
	{
		"nebula": [
			Color(0.34, 0.10, 0.36, 1.0),
			Color(0.20, 0.05, 0.24, 1.0),
			Color(0.09, 0.02, 0.12, 1.0),
		],
		"veil": Color(0.08, 0.02, 0.10, 0.28),
		"haze_a": Color(0.75, 0.20, 0.80, 0.16),
		"haze_b": Color(0.45, 0.15, 0.70, 0.14),
	},
	{
		"nebula": [
			Color(0.12, 0.22, 0.40, 1.0),
			Color(0.06, 0.12, 0.26, 1.0),
			Color(0.02, 0.05, 0.12, 1.0),
		],
		"veil": Color(0.02, 0.05, 0.10, 0.28),
		"haze_a": Color(0.25, 0.50, 0.85, 0.16),
		"haze_b": Color(0.15, 0.60, 0.70, 0.14),
	},
]

var _warp: float = 0.35
var _palette_band: int = 0
var _mat: ShaderMaterial
var _fx_rect: ColorRect
var _mobile: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# No forzar modulate aquí: la cinemática de era lo deja en alpha 0 hasta el reveal.
	_mobile = BoardDestroyFxScript.is_mobile_device()
	_build_fx_layer()
	set_palette_band(_palette_band)
	set_warp(_warp)
	_apply_fx_enabled()
	resized.connect(_on_resized)
	if SettingsManager != null and not SettingsManager.settings_changed.is_connected(_on_settings_changed):
		SettingsManager.settings_changed.connect(_on_settings_changed)
	call_deferred("_sync_viewport_size")


func _exit_tree() -> void:
	if SettingsManager != null and SettingsManager.settings_changed.is_connected(_on_settings_changed):
		SettingsManager.settings_changed.disconnect(_on_settings_changed)


func _build_fx_layer() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = STARFIELD_SHADER
	_mat.set_shader_parameter("layers", 2 if _mobile else 4)
	_mat.set_shader_parameter("use_rays", not _mobile)
	_mat.set_shader_parameter("use_neighbors", not _mobile)
	_mat.set_shader_parameter("time_scale", 1.0)

	_fx_rect = ColorRect.new()
	_fx_rect.name = "StarfieldRect"
	_fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_rect.material = _mat
	# Si el material no pinta, al menos no queda blanco puro.
	_fx_rect.color = Color(0.04, 0.04, 0.12, 1.0)
	_fx_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fx_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_fx_rect)


func set_warp(intensity: float) -> void:
	_warp = clampf(intensity, 0.05, 3.5)
	if _mat != null:
		_mat.set_shader_parameter("warp", _warp)


func boost_warp(to_intensity: float = 2.4) -> void:
	set_warp(to_intensity)


func set_palette_band(band: int) -> void:
	_palette_band = posmod(band, PALETTES.size())
	var p: Dictionary = PALETTES[_palette_band]
	var nebula_v: Variant = p.get("nebula", [])
	var n0 := Color(0.12, 0.05, 0.28)
	var n1 := Color(0.04, 0.08, 0.22)
	var n2 := Color(0.02, 0.02, 0.08)
	if typeof(nebula_v) == TYPE_ARRAY:
		var arr: Array = nebula_v
		if arr.size() > 0:
			n0 = arr[0] as Color
		if arr.size() > 1:
			n1 = arr[1] as Color
		if arr.size() > 2:
			n2 = arr[2] as Color
	if _mat == null:
		return
	_mat.set_shader_parameter("nebula_top", Vector3(n0.r, n0.g, n0.b))
	_mat.set_shader_parameter("nebula_mid", Vector3(n1.r, n1.g, n1.b))
	_mat.set_shader_parameter("nebula_bot", Vector3(n2.r, n2.g, n2.b))
	_mat.set_shader_parameter("veil_color", p.get("veil", Color(0.01, 0.01, 0.05, 0.55)) as Color)
	_mat.set_shader_parameter("haze_a", p.get("haze_a", Color(0.35, 0.1, 0.55, 0.08)) as Color)
	_mat.set_shader_parameter("haze_b", p.get("haze_b", Color(0.1, 0.25, 0.55, 0.07)) as Color)


func get_palette_band() -> int:
	return _palette_band


func _on_settings_changed() -> void:
	_apply_fx_enabled()


func _apply_fx_enabled() -> void:
	if _mat == null:
		return
	var on := SettingsManager == null or SettingsManager.fx_enabled
	_mat.set_shader_parameter("animate", on)


func _on_resized() -> void:
	_sync_viewport_size()


func _sync_viewport_size() -> void:
	if _mat == null or _fx_rect == null:
		return
	var s := size
	if s.x < 4.0 or s.y < 4.0:
		return
	_fx_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# En móvil se informa resolución a mitad para abaratar el coste por píxel del UV
	# (el ColorRect sigue a pantalla completa; el coste real baja con layers/neighbors).
	var report := s * (0.5 if _mobile else 1.0)
	_mat.set_shader_parameter("viewport_size", report)
