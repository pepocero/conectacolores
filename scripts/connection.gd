class_name Connection
extends RefCounted

var color_name: String = ""
var cells: Array[Vector2i] = []
var completed: bool = false


func _init(p_color: String = "", start: Vector2i = Vector2i(-1, -1)) -> void:
	color_name = p_color
	cells.clear()
	if start.x >= 0:
		cells.append(start)
	completed = false


func get_start() -> Vector2i:
	if cells.is_empty():
		return Vector2i(-1, -1)
	return cells[0]


func get_end() -> Vector2i:
	if cells.is_empty():
		return Vector2i(-1, -1)
	return cells[cells.size() - 1]


func contains(cell: Vector2i) -> bool:
	return cells.has(cell)


func index_of(cell: Vector2i) -> int:
	return cells.find(cell)


func truncate_to(cell: Vector2i) -> void:
	var idx := index_of(cell)
	if idx < 0:
		return
	cells = cells.slice(0, idx + 1)
	completed = false


func append_cell(cell: Vector2i) -> void:
	cells.append(cell)


func clear_path() -> void:
	cells.clear()
	completed = false


func cell_count() -> int:
	return cells.size()


func to_array() -> Array:
	var result: Array = []
	for cell: Vector2i in cells:
		result.append([cell.x, cell.y])
	return result
