extends RefCounted

## Solucionador con backtracking para niveles de rejilla (Fácil / Difícil).
## Reglas del juego: unir cada pareja con un camino ortogonal sin cruzar otros
## caminos ni pasar por bolas ajenas; no es obligatorio rellenar el tablero.
## Prueba primero la ruta más directa (como un jugador) y cuenta los nodos
## explorados hasta resolver: ese esfuerzo estima la dificultad real del nivel.

const DEFAULT_BUDGET := 2500
const FREE := -1

var _size := 0
var _grid := PackedInt32Array()
var _comp := PackedInt32Array()
var _queue := PackedInt32Array()
## Por pareja: x = índice de la bola A, y = índice de la bola B.
var _ends: Array[Vector2i] = []
var _order: Array[int] = []
var _nodes := 0
var _budget := DEFAULT_BUDGET
var _aborted := false


## Devuelve { solved, nodes, aborted }. Si se agota el presupuesto, aborted = true
## y nodes = presupuesto + 1 (esfuerzo máximo medible).
func run(level: Dictionary, budget: int = DEFAULT_BUDGET) -> Dictionary:
	_size = int(level.get("size", 0))
	_budget = maxi(1, budget)
	_nodes = 0
	_aborted = false
	if _size < 2:
		return {"solved": false, "nodes": 0, "aborted": false}

	var cells := _size * _size
	_grid.resize(cells)
	_grid.fill(FREE)
	_comp.resize(cells)
	_queue.resize(cells)

	var by_color: Dictionary = {}
	var dots: Variant = level.get("dots", [])
	if typeof(dots) != TYPE_ARRAY:
		return {"solved": false, "nodes": 0, "aborted": false}
	for dot_v: Variant in dots:
		if typeof(dot_v) != TYPE_DICTIONARY:
			return {"solved": false, "nodes": 0, "aborted": false}
		var dot: Dictionary = dot_v
		var x := int(dot.get("x", -1))
		var y := int(dot.get("y", -1))
		if x < 0 or y < 0 or x >= _size or y >= _size:
			return {"solved": false, "nodes": 0, "aborted": false}
		var color := str(dot.get("color", ""))
		if not by_color.has(color):
			by_color[color] = []
		(by_color[color] as Array).append(y * _size + x)

	_ends.clear()
	var color_index := 0
	for color_v: Variant in by_color.keys():
		var pts: Array = by_color[color_v]
		if pts.size() != 2:
			return {"solved": false, "nodes": 0, "aborted": false}
		var a := int(pts[0])
		var b := int(pts[1])
		_ends.append(Vector2i(a, b))
		_grid[a] = color_index
		_grid[b] = color_index
		color_index += 1

	# Primero las parejas más cercanas: es lo que suele intentar un jugador.
	_order.clear()
	for i in range(_ends.size()):
		_order.append(i)
	_order.sort_custom(_closer_pair_first)

	var solved := _solve_pair(0)
	var nodes := _budget + 1 if _aborted else _nodes
	return {"solved": solved and not _aborted, "nodes": nodes, "aborted": _aborted}


func _closer_pair_first(a: int, b: int) -> bool:
	return _manhattan(_ends[a].x, _ends[a].y) < _manhattan(_ends[b].x, _ends[b].y)


func _solve_pair(k: int) -> bool:
	if k >= _order.size():
		return true
	var c := _order[k]
	var a := _ends[c].x
	var b := _ends[c].y
	if _adjacent(a, b):
		return _solve_pair(k + 1)
	return _extend(k, c, a, b)


func _extend(k: int, c: int, head: int, target: int) -> bool:
	_nodes += 1
	if _nodes > _budget:
		_aborted = true
		return false
	var opts := _neighbors_toward(head, target)
	for nb: int in opts:
		if nb == target:
			if _solve_pair(k + 1):
				return true
			if _aborted:
				return false
			continue
		if _grid[nb] != FREE:
			continue
		_grid[nb] = c
		if _feasible(k, nb, target) and _extend(k, c, nb, target):
			return true
		_grid[nb] = FREE
		if _aborted:
			return false
	return false


## Poda: la pareja en curso y todas las pendientes deben seguir pudiendo unirse.
func _feasible(k: int, head: int, target: int) -> bool:
	_label_components()
	if not _can_link(head, target):
		return false
	for j in range(k + 1, _order.size()):
		var e := _ends[_order[j]]
		if not _can_link(e.x, e.y):
			return false
	return true


func _label_components() -> void:
	_comp.fill(-1)
	var label := 0
	var cells := _size * _size
	for start in range(cells):
		if _grid[start] != FREE or _comp[start] != -1:
			continue
		var head := 0
		var tail := 0
		_queue[tail] = start
		tail += 1
		_comp[start] = label
		while head < tail:
			var cur := _queue[head]
			head += 1
			var cx := cur % _size
			var cy := int(cur / _size)
			if cx > 0:
				tail = _visit(cur - 1, label, tail)
			if cx < _size - 1:
				tail = _visit(cur + 1, label, tail)
			if cy > 0:
				tail = _visit(cur - _size, label, tail)
			if cy < _size - 1:
				tail = _visit(cur + _size, label, tail)
		label += 1


func _visit(idx: int, label: int, tail: int) -> int:
	if _grid[idx] == FREE and _comp[idx] == -1:
		_comp[idx] = label
		_queue[tail] = idx
		return tail + 1
	return tail


## p y q pueden unirse si son vecinas o si tocan una misma región libre.
func _can_link(p: int, q: int) -> bool:
	if _adjacent(p, q):
		return true
	var comps_p: Array[int] = []
	for nb: int in _neighbors(p):
		if _grid[nb] == FREE:
			comps_p.append(_comp[nb])
	if comps_p.is_empty():
		return false
	for nb: int in _neighbors(q):
		if _grid[nb] == FREE and comps_p.has(_comp[nb]):
			return true
	return false


func _neighbors(idx: int) -> Array[int]:
	var out: Array[int] = []
	var x := idx % _size
	var y := int(idx / _size)
	if x > 0:
		out.append(idx - 1)
	if x < _size - 1:
		out.append(idx + 1)
	if y > 0:
		out.append(idx - _size)
	if y < _size - 1:
		out.append(idx + _size)
	return out


func _neighbors_toward(idx: int, target: int) -> Array[int]:
	var out := _neighbors(idx)
	# Inserción: como mucho 4 elementos.
	for i in range(1, out.size()):
		var item := out[i]
		var d := _manhattan(item, target)
		var j := i - 1
		while j >= 0 and _manhattan(out[j], target) > d:
			out[j + 1] = out[j]
			j -= 1
		out[j + 1] = item
	return out


func _manhattan(a: int, b: int) -> int:
	return absi(a % _size - b % _size) + absi(int(a / _size) - int(b / _size))


func _adjacent(a: int, b: int) -> bool:
	return _manhattan(a, b) == 1
