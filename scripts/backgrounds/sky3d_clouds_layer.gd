extends ColorRect

## Capa de nubes 2D con NoiseTexture2D nativo de Godot (sin addon Sky3D).

const CumulusTex: Texture2D = preload("res://assets/fx/cumulus_noise.tres")
const CirrusTex: Texture2D = preload("res://assets/fx/cirrus_noise.tres")
const CloudShader: Shader = preload("res://scripts/backgrounds/sky3d_clouds_overlay.gdshader")

const WIND_SPEED_FACTOR := 0.01

var wind_speed_ms: float = 1.6
var wind_direction_rad: float = -0.4
var _cumulus_pos := Vector2.ZERO
var _cirrus1 := Vector2.ZERO
var _cirrus2 := Vector2.ZERO
var _mat: ShaderMaterial
var _fx_paused: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ensure_material()
	set_process(true)
	if not SettingsManager.settings_changed.is_connected(_on_settings):
		SettingsManager.settings_changed.connect(_on_settings)
	_on_settings()


func _exit_tree() -> void:
	if SettingsManager.settings_changed.is_connected(_on_settings):
		SettingsManager.settings_changed.disconnect(_on_settings)


func set_fx_paused(paused: bool) -> void:
	_fx_paused = paused
	set_process(not paused and SettingsManager.fx_enabled)


func configure(
	tint: Color,
	shadow: Color,
	coverage: float,
	intensity: float,
	sky_bottom: float,
	speed_ms: float = 1.6,
	direction_rad: float = -0.4,
	scale: float = 1.15
) -> void:
	_ensure_material()
	wind_speed_ms = speed_ms
	wind_direction_rad = direction_rad
	_mat.set_shader_parameter("cloud_tint", tint)
	_mat.set_shader_parameter("cloud_shadow", shadow)
	_mat.set_shader_parameter("coverage", coverage)
	_mat.set_shader_parameter("intensity", intensity)
	_mat.set_shader_parameter("sky_bottom", sky_bottom)
	_mat.set_shader_parameter("cloud_scale", scale)


func _ensure_material() -> void:
	if _mat != null:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = CloudShader
	_mat.set_shader_parameter("cumulus_texture", CumulusTex)
	_mat.set_shader_parameter("cirrus_texture", CirrusTex)
	material = _mat
	color = Color(1, 1, 1, 1)


func _on_settings() -> void:
	visible = true
	set_process(not _fx_paused and SettingsManager.fx_enabled)


func _process(delta: float) -> void:
	if _fx_paused or _mat == null:
		return
	var dir := Vector2.from_angle(wind_direction_rad)
	var vel := dir * (wind_speed_ms * WIND_SPEED_FACTOR)
	_cumulus_pos += vel * delta
	_cirrus1 += vel * 0.55 * delta
	_cirrus2 += vel * 0.32 * delta + Vector2(vel.y, -vel.x) * 0.08 * delta
	_mat.set_shader_parameter("cumulus_position", _cumulus_pos)
	_mat.set_shader_parameter("cirrus_position1", _cirrus1)
	_mat.set_shader_parameter("cirrus_position2", _cirrus2)
