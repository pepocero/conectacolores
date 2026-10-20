extends BgPhotoBase

## Foto de paisaje nevado + nubes 2D (NoiseTexture2D) y destellos fríos.

const Sky3DCloudsLayer := preload("res://scripts/backgrounds/sky3d_clouds_layer.gd")

var _clouds_layer: ColorRect
var _sparks: Array[Dictionary] = []


func _ready() -> void:
	photo_path = "res://assets/backgrounds/sunset.jpg"
	super._ready()


func setup_fx() -> void:
	_clouds_layer = Sky3DCloudsLayer.new()
	add_child(_clouds_layer)
	_clouds_layer.configure(
		Color(0.95, 0.97, 1.0, 0.9),
		Color(0.7, 0.78, 0.88, 1.0),
		0.42,
		0.8,
		0.5,
		1.8,
		-0.4,
		1.1
	)

	_sparks.clear()
	for i in range(20):
		_sparks.append({
			"x": _rng.randf(),
			"y": _rng.randf_range(0.1, 0.55),
			"r": _rng.randf_range(1.2, 3.0),
			"phase": _rng.randf() * TAU,
		})


func draw_fx() -> void:
	if not SettingsManager.fx_enabled:
		return
	var w := size.x
	var h := size.y
	for s in _sparks:
		var a := 0.15 + 0.45 * absf(sin(_time * 1.5 + float(s["phase"])))
		draw_circle(
			Vector2(float(s["x"]) * w, float(s["y"]) * h),
			float(s["r"]),
			Color(0.9, 0.95, 1.0, a)
		)
