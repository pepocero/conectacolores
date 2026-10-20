extends SceneTree

## Prueba lógica básica del tablero sin interfaz.
## Uso: godot --headless --path . -s res://tools/smoke_test.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var file := FileAccess.open("res://data/levels.json", FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var level: Dictionary = json.data["levels"][0]

	var board := Board.new()
	board.size = Vector2(720, 720)
	board.setup_level(level)

	if board.get_total_pairs() != 2:
		printerr("FAIL pairs total")
		quit(1)
		return

	var cyan_path: Array = level["solution"]["cyan"]
	var start := Vector2i(int(cyan_path[0][0]), int(cyan_path[0][1]))
	board._start_from_endpoint("cyan", start)
	for i: int in range(1, cyan_path.size()):
		var cell := Vector2i(int(cyan_path[i][0]), int(cyan_path[i][1]))
		board._on_drag(board._cell_center(cell))

	if not board.connections["cyan"].completed:
		printerr("FAIL cyan incomplete")
		quit(1)
		return

	var orange_path: Array = level["solution"]["orange"]
	var o_start := Vector2i(int(orange_path[0][0]), int(orange_path[0][1]))
	board._start_from_endpoint("orange", o_start)
	for i: int in range(1, orange_path.size()):
		var cell := Vector2i(int(orange_path[i][0]), int(orange_path[i][1]))
		board._on_drag(board._cell_center(cell))

	if not board.just_completed or board.get_remaining_pairs() != 0:
		printerr("FAIL level not completed")
		quit(1)
		return

	print("SMOKE OK: nivel 1 resoluble por lógica de tablero")
	quit(0)
