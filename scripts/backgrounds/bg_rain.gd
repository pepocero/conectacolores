extends BgPhotoBase

## Foto de tormenta + lluvia animada.

var _drops: Array[Dictionary] = []


func _ready() -> void:
	photo_path = "res://assets/backgrounds/rain.jpg"
	super._ready()


func setup_fx() -> void:
	_rebuild_drops()
	if not resized.is_connected(_rebuild_drops):
		resized.connect(_rebuild_drops)


func _rebuild_drops() -> void:
	_drops.clear()
	for i in range(110):
		_drops.append({
			"x": _rng.randf(),
			"y": _rng.randf(),
			"len": _rng.randf_range(0.025, 0.06),
			"speed": _rng.randf_range(0.7, 1.4),
			"alpha": _rng.randf_range(0.3, 0.75),
		})


func process_fx(delta: float) -> void:
	for i in range(_drops.size()):
		var d: Dictionary = _drops[i]
		d["y"] = float(d["y"]) + delta * float(d["speed"]) * 0.95
		if float(d["y"]) > 1.15:
			d["y"] = _rng.randf_range(-0.15, 0.0)
			d["x"] = _rng.randf()
		_drops[i] = d


func draw_fx() -> void:
	var w := size.x
	var h := size.y
	var animate := SettingsManager.fx_enabled
	for d in _drops:
		var x := float(d["x"]) * w
		var y := float(d["y"]) * h
		if not animate:
			y = fmod(y + float(d["x"]) * h * 0.3, h)
		var tip := Vector2(x + 5.0, y + float(d["len"]) * h)
		draw_line(Vector2(x, y), tip, Color(0.85, 0.92, 1.0, float(d["alpha"])), 1.8, true)
