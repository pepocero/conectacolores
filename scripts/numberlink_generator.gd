class_name NumberlinkGenerator
extends RefCounted

## Generador estilo Numberlink (tile → shuffle → merge de flujos) para Modo Difícil.
## Algoritmo inspirado en el generador Go de Thomas Ahle / Numberlink
## (https://github.com/thomasahle/numberlink) — reimplementación propia, no copia AGPL.
## Independiente de LevelGenerator (sin preload circular; seguro en hilo de generación).
##
## La tabla usa Array de filas Array (no PackedInt32Array) para que las mutaciones
## persistan: Packed* se copia al leer desde Array y el shuffle/fill no escribían.

const DX: Array[int] = [0, 1, 0, -1]
const DY: Array[int] = [-1, 0, 1, 0]
const MAX_ATTEMPTS := 48
## Holgura amplia de parejas: priorizar tablero válido sobre exactitud de count.
const PAIR_SLACK_LO := 4
const PAIR_SLACK_HI := 6
## Extremos de cada pareja: Manhattan mínima.
const MIN_ENDPOINT_MANHATTAN := 4
const COLOR_NAMES: Array[String] = [
	"cyan",
	"orange",
	"green",
	"pink",
	"yellow",
	"violet",
	"red",
	"blue",
	"white",
	"teal",
	"magenta",
	"brown",
	"gray",
	"navy",
	"salmon",
	"olive",
]


## Genera un nivel compatible (dots/solution/par) o {} si falla.
static func generate_level(
	level_id: int,
	name: String,
	size: int,
	target_pairs: int,
	seed_value: int
) -> Dictionary:
	if size < 4 or target_pairs < 2:
		return {}
	var max_pairs := mini(COLOR_NAMES.size(), maxi(2, int((size * size) / 3)))
	var want := clampi(target_pairs, 2, max_pairs)
	var min_pairs := maxi(2, want - PAIR_SLACK_LO)
	var max_ok := mini(max_pairs, want + PAIR_SLACK_HI)

	var rng := RandomNumberGenerator.new()
	var best: Dictionary = {}
	var best_pair_delta := 999
	for attempt in range(MAX_ATTEMPTS):
		rng.seed = int(seed_value) + attempt * 9973
		var table := _generate_table(size, size, rng)
		if table.is_empty():
			continue
		var level := _table_to_level(table, level_id, name, size)
		if level.is_empty():
			continue
		if not _passes_quality(level):
			continue
		var pairs := 0
		var sol_v: Variant = level.get("solution", null)
		if typeof(sol_v) == TYPE_DICTIONARY:
			pairs = (sol_v as Dictionary).size()
		if pairs < 2 or pairs > max_pairs:
			continue
		var delta := absi(pairs - want)
		if pairs >= min_pairs and pairs <= max_ok:
			level["generator"] = "numberlink"
			return level
		if delta < best_pair_delta:
			best_pair_delta = delta
			best = level

	if not best.is_empty():
		best["generator"] = "numberlink"
		return best
	return {}


static func _generate_table(width: int, height: int, rng: RandomNumberGenerator) -> Array:
	if width < 2 or height < 2:
		return []
	var table := _tile(width, height)
	_shuffle(table, rng)
	_odd_corner(table)
	_find_flows(table, rng)
	_flatten(table)
	return table


## Tabla: Array de filas; cada fila es Array de int (mutación in-place).
static func _tile(width: int, height: int) -> Array:
	var table: Array = []
	for _y in range(height):
		var row: Array = []
		row.resize(width)
		for x in range(width):
			row[x] = 0
		table.append(row)
	var alpha := 0
	var y := 0
	while y < height - 1:
		for x in range(width):
			table[y][x] = alpha
			table[y + 1][x] = alpha
			alpha += 1
		y += 2
	if height % 2 == 1:
		var x := 0
		while x < width - 1:
			table[height - 1][x] = alpha
			table[height - 1][x + 1] = alpha
			alpha += 1
			x += 2
		if width % 2 == 1:
			table[height - 1][width - 1] = alpha
	return table


static func _shuffle(table: Array, rng: RandomNumberGenerator) -> void:
	var width: int = table[0].size()
	var height: int = table.size()
	if width < 2 or height < 2:
		return
	var iters := width * height * width * height
	for _i in range(iters):
		var x := rng.randi_range(0, width - 2)
		var y := rng.randi_range(0, height - 2)
		var a: int = table[y][x]
		var b: int = table[y][x + 1]
		var c: int = table[y + 1][x]
		var d: int = table[y + 1][x + 1]
		if a == b and c == d:
			table[y + 1][x] = a
			table[y][x + 1] = d
		elif a == c and b == d:
			table[y][x + 1] = a
			table[y + 1][x] = d


static func _odd_corner(table: Array) -> void:
	var width: int = table[0].size()
	var height: int = table.size()
	if width % 2 != 1 or height % 2 != 1:
		return
	if width > 2 and table[height - 1][width - 3] == table[height - 1][width - 2]:
		table[height - 1][width - 1] = table[height - 1][width - 2]
		return
	if height > 2:
		if table[height - 3][width - 1] == table[height - 2][width - 1]:
			table[height - 1][width - 1] = table[height - 2][width - 1]


static func _find_flows(table: Array, rng: RandomNumberGenerator) -> void:
	var width: int = table[0].size()
	var height: int = table.size()
	var order: Array[int] = []
	for i in range(width * height):
		order.append(i)
	_shuffle_ints(order, rng)
	for p: int in order:
		var x := p % width
		var y := int(p / width)
		if _is_flow_head(x, y, table):
			_lay_flow(x, y, table, rng)


static func _is_flow_head(x: int, y: int, table: Array) -> bool:
	var width: int = table[0].size()
	var height: int = table.size()
	var color: int = table[y][x]
	var degree := 0
	for i in range(4):
		var x1 := x + DX[i]
		var y1 := y + DY[i]
		if _inside(x1, y1, width, height) and int(table[y1][x1]) == color:
			degree += 1
	return degree < 2


static func _inside(x: int, y: int, width: int, height: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


static func _lay_flow(x: int, y: int, table: Array, rng: RandomNumberGenerator) -> void:
	var width: int = table[0].size()
	var height: int = table.size()
	var stack: Array[Vector2i] = [Vector2i(x, y)]
	var guard := 0
	var max_guard := width * height * 4
	while not stack.is_empty() and guard < max_guard:
		guard += 1
		var cur: Vector2i = stack.pop_back()
		if not _is_flow_head(cur.x, cur.y, table):
			continue
		var dirs: Array[int] = [0, 1, 2, 3]
		_shuffle_ints(dirs, rng)
		for i: int in dirs:
			var x1 := cur.x + DX[i]
			var y1 := cur.y + DY[i]
			if not _inside(x1, y1, width, height):
				continue
			if not _can_connect(cur.x, cur.y, x1, y1, table):
				continue
			var alpha: int = table[cur.y][cur.x]
			_fill(x1, y1, alpha, table)
			var tip := _follow(x1, y1, cur.x, cur.y, table)
			stack.append(tip)
			break


static func _can_connect(x1: int, y1: int, x2: int, y2: int, table: Array) -> bool:
	var width: int = table[0].size()
	var height: int = table.size()
	var c1: int = table[y1][x1]
	var c2: int = table[y2][x2]
	if c1 == c2:
		return false
	if not _is_flow_head(x1, y1, table) or not _is_flow_head(x2, y2, table):
		return false
	for y3 in range(height):
		for x3 in range(width):
			if int(table[y3][x3]) != c1:
				continue
			for i in range(4):
				var x4 := x3 + DX[i]
				var y4 := y3 + DY[i]
				if not _inside(x4, y4, width, height):
					continue
				if x3 == x1 and y3 == y1 and x4 == x2 and y4 == y2:
					continue
				if int(table[y4][x4]) == c2:
					return false
	return true


static func _fill(x: int, y: int, alpha: int, table: Array) -> void:
	var width: int = table[0].size()
	var height: int = table.size()
	var orig: int = table[y][x]
	if orig == alpha:
		return
	var stack: Array[Vector2i] = [Vector2i(x, y)]
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		if int(table[cur.y][cur.x]) != orig:
			continue
		table[cur.y][cur.x] = alpha
		for i in range(4):
			var nx := cur.x + DX[i]
			var ny := cur.y + DY[i]
			if _inside(nx, ny, width, height) and int(table[ny][nx]) == orig:
				stack.append(Vector2i(nx, ny))


static func _follow(x: int, y: int, x0: int, y0: int, table: Array) -> Vector2i:
	var width: int = table[0].size()
	var height: int = table.size()
	var color: int = table[y][x]
	var cx := x
	var cy := y
	var px := x0
	var py := y0
	var guard := 0
	var max_guard := width * height + 2
	while guard < max_guard:
		guard += 1
		var advanced := false
		for i in range(4):
			var nx := cx + DX[i]
			var ny := cy + DY[i]
			if not _inside(nx, ny, width, height):
				continue
			if nx == px and ny == py:
				continue
			if int(table[ny][nx]) != color:
				continue
			px = cx
			py = cy
			cx = nx
			cy = ny
			advanced = true
			break
		if not advanced:
			return Vector2i(cx, cy)
	return Vector2i(cx, cy)


static func _flatten(table: Array) -> int:
	var width: int = table[0].size()
	var height: int = table.size()
	var alpha := -1
	for y in range(height):
		for x in range(width):
			if int(table[y][x]) >= 0:
				_fill(x, y, alpha, table)
				alpha -= 1
	for y in range(height):
		for x in range(width):
			table[y][x] = -int(table[y][x]) - 1
	return -alpha - 1


static func _table_to_level(table: Array, level_id: int, name: String, size: int) -> Dictionary:
	var width: int = table[0].size()
	var height: int = table.size()
	if width != size or height != size:
		return {}

	var by_color: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var cid: int = table[y][x]
			if not by_color.has(cid):
				by_color[cid] = []
			(by_color[cid] as Array).append(Vector2i(x, y))

	var color_ids: Array = by_color.keys()
	color_ids.sort()
	if color_ids.size() > COLOR_NAMES.size():
		return {}

	var assignment: Dictionary = {}
	var dots: Array = []
	var solution: Dictionary = {}
	var par := 0
	var ci := 0

	for cid_v: Variant in color_ids:
		var cid := int(cid_v)
		var cells_raw: Array = by_color[cid]
		var cells: Array[Vector2i] = []
		for c_v: Variant in cells_raw:
			cells.append(c_v as Vector2i)
		# Flujos demasiado cortos o extremos cercanos → tablero inválido.
		if cells.size() < MIN_ENDPOINT_MANHATTAN + 1:
			return {}
		var path := _trace_path_from_cells(cells)
		if path.is_empty() or path.size() < MIN_ENDPOINT_MANHATTAN + 1:
			return {}
		var a: Vector2i = path[0]
		var b: Vector2i = path[path.size() - 1]
		if absi(a.x - b.x) + absi(a.y - b.y) < MIN_ENDPOINT_MANHATTAN:
			return {}
		var color_name: String = COLOR_NAMES[ci]
		ci += 1
		var path_arrays: Array = []
		for p: Vector2i in path:
			assignment[p] = color_name
			path_arrays.append([p.x, p.y])
		solution[color_name] = path_arrays
		dots.append({"color": color_name, "x": a.x, "y": a.y})
		dots.append({"color": color_name, "x": b.x, "y": b.y})
		par += path.size() - 1

	if assignment.size() != size * size:
		return {}

	return {
		"id": level_id,
		"name": name,
		"size": size,
		"dots": dots,
		"solution": solution,
		"par": par,
	}


static func _trace_path_from_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var cell_set: Dictionary = {}
	for c: Vector2i in cells:
		cell_set[c] = true
	var ends: Array[Vector2i] = []
	for c: Vector2i in cells:
		var deg := 0
		for i in range(4):
			var nb := Vector2i(c.x + DX[i], c.y + DY[i])
			if cell_set.has(nb):
				deg += 1
		if deg == 1:
			ends.append(c)
		elif deg != 2:
			return []
	if ends.size() != 2:
		return []
	var path: Array[Vector2i] = [ends[0]]
	var prev := Vector2i(-999, -999)
	var cur := ends[0]
	while path.size() < cells.size():
		var advanced := false
		for i in range(4):
			var nb := Vector2i(cur.x + DX[i], cur.y + DY[i])
			if nb == prev or not cell_set.has(nb):
				continue
			if path.has(nb):
				continue
			prev = cur
			cur = nb
			path.append(cur)
			advanced = true
			break
		if not advanced:
			return []
	if path[path.size() - 1] != ends[1]:
		return []
	return path


static func _passes_quality(level: Dictionary) -> bool:
	var sol: Dictionary = level.get("solution", {})
	if sol.is_empty():
		return false
	for color_v: Variant in sol.keys():
		var path: Array = sol[color_v]
		if path.size() < MIN_ENDPOINT_MANHATTAN + 1:
			return false
		var a := Vector2i(int(path[0][0]), int(path[0][1]))
		var b := Vector2i(int(path[path.size() - 1][0]), int(path[path.size() - 1][1]))
		if absi(a.x - b.x) + absi(a.y - b.y) < MIN_ENDPOINT_MANHATTAN:
			return false
	return true


static func _shuffle_ints(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
