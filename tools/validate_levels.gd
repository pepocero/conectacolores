extends SceneTree

## Uso: godot --headless --path . -s res://tools/validate_levels.gd


func _init() -> void:
	var file := FileAccess.open("res://data/levels.json", FileAccess.READ)
	if file == null:
		printerr("No se pudo abrir levels.json")
		quit(1)
		return

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		printerr("JSON inválido")
		quit(1)
		return

	var data: Dictionary = json.data
	var packs: Dictionary = {}
	if data.has("easy") or data.has("hard"):
		packs = {"easy": data.get("easy", []), "hard": data.get("hard", [])}
	else:
		packs = {"legacy": data.get("levels", [])}

	var failed := 0
	var total := 0
	for pack_name: Variant in packs.keys():
		var levels: Array = packs[pack_name]
		for level: Variant in levels:
			total += 1
			var id := int(level.get("id", -1))
			var size := int(level.get("size", 0))
			var dots: Array = level.get("dots", [])
			var solution: Dictionary = level.get("solution", {})
			var ok := _validate_level(id, size, dots, solution)
			if not ok:
				failed += 1
				printerr("FAIL %s nivel %d" % [pack_name, id])
			else:
				print("OK %s nivel %d" % [pack_name, id])

	print("Resultado: %d fallos de %d niveles" % [failed, total])
	quit(1 if failed > 0 else 0)


func _validate_level(id: int, size: int, dots: Array, solution: Dictionary) -> bool:
	var endpoints: Dictionary = {}
	for dot: Variant in dots:
		var color: String = str(dot.get("color", ""))
		var pos := Vector2i(int(dot.get("x", -1)), int(dot.get("y", -1)))
		if pos.x < 0 or pos.y < 0 or pos.x >= size or pos.y >= size:
			printerr("  endpoint fuera: %s %s" % [color, pos])
			return false
		if not endpoints.has(color):
			endpoints[color] = []
		endpoints[color].append(pos)

	var occupied: Dictionary = {}
	for color: Variant in solution.keys():
		var path: Array = solution[color]
		if path.size() < 2:
			printerr("  path corto: %s" % color)
			return false
		if not endpoints.has(color) or endpoints[color].size() != 2:
			printerr("  endpoints inválidos: %s" % color)
			return false

		var start := _to_v2(path[0])
		var end := _to_v2(path[path.size() - 1])
		var a: Vector2i = endpoints[color][0]
		var b: Vector2i = endpoints[color][1]
		var ends_ok := (start == a and end == b) or (start == b and end == a)
		if not ends_ok:
			printerr("  extremos no coinciden: %s" % color)
			return false

		for i: int in path.size():
			var p := _to_v2(path[i])
			if p.x < 0 or p.y < 0 or p.x >= size or p.y >= size:
				printerr("  celda fuera: %s %s" % [color, p])
				return false
			var key := "%d,%d" % [p.x, p.y]
			if occupied.has(key):
				printerr("  solapamiento en %s" % key)
				return false
			occupied[key] = color
			if i > 0:
				var prev := _to_v2(path[i - 1])
				var dist := absi(p.x - prev.x) + absi(p.y - prev.y)
				if dist != 1:
					printerr("  no adyacente: %s %s -> %s" % [color, prev, p])
					return false

	for color: Variant in endpoints.keys():
		if not solution.has(color):
			printerr("  falta solución para %s" % color)
			return false

	return true


func _to_v2(value: Variant) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))
