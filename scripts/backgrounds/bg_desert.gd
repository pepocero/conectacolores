extends BgPhotoBase

## Foto de desierto + nubes 2D (NoiseTexture2D) y calor.

const Sky3DCloudsLayer := preload("res://scripts/backgrounds/sky3d_clouds_layer.gd")

var _clouds_layer: ColorRect
var _heat: Array[Dictionary] = []


func _ready() -> void:
	photo_path = "res://assets/backgrounds/desert.jpg"
	super._ready()


func setup_fx() -> void:
	_clouds_layer = Sky3DCloudsLayer.new()
	add_child(_clouds_layer)
	_clouds_layer.configure(
		Color(1.0, 1.0, 0.98, 0.9),
		Color(0.9, 0.88, 0.82, 1.0),
		0.32,
		0.7,
		0.38,
		1.1,
		-0.55,
		1.25
	)

	_heat.clear()
	for i in range(14):
		_heat.append({
			"x": _rng.randf(),
			"y": _rng.randf_range(0.4, 0.75),
			"phase": _rng.randf() * TAU,
		})


func draw_fx() -> void:
	if not SettingsManager.fx_enabled:
		return
	var w := size.x
	var h := size.y
	for ht in _heat:
		var hx := float(ht["x"]) * w + sin(_time * 1.3 + float(ht["phase"])) * 20.0
		var hy := float(ht["y"]) * h + sin(_time * 1.9 + float(ht["phase"])) * 12.0
		draw_circle(Vector2(hx, hy), 26.0, Color(1, 0.95, 0.7, 0.06))
