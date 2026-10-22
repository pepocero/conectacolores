class_name HardLevelGenerator
extends RefCounted

## Generador exclusivo de Modo Difícil.
## Construye con serpientes (fiable) + extremos lejos, y elige el layout más duro
## según solucionador e interferencia (no cover/densidad).

const DX: Array[int] = [1, -1, 0, 0]
const DY: Array[int] = [0, 0, 1, -1]
const MIN_ENDPOINT_MANHATTAN := 4
const MAX_ATTEMPTS := 18
const MAX_METRIC_EVALS := 28
const EASY_MARGIN := 1.0
const MIN_INTERFERENCE_SOFT := 0.20

const W_NODES := 3.5
const W_INTERF := 10.0
const W_DETOUR := 2.5
const W_SHORTCUT_PENALTY := 7.0

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


## Genera un nivel Difícil. prioriza gates duros; si no, el más duro solvable.
static func generate_level(
	level_id: int,
	name: String,
	size: int,
	target_pairs: int,
	seed_value: int,
	other_mode_score: float = -1.0,
	floor_score: float = -1.0
) -> Dictionary:
	if size < 5 or target_pairs < 2:
		return {}
	var max_pairs := mini(COLOR_NAMES.size(), maxi(2, int((size * size) / 3)))
	var want := clampi(target_pairs, 2, max_pairs)

	var pool_gated: Array[Dictionary] = []
	var best_any: Dictionary = {}
	var best_hs := -INF
	var evals := 0

	# Reducir parejas solo si hace falta para obtener candidatos válidos.
	for reduce in range(0, mini(4, maxi(1, want - 1))):
		var n_pairs := maxi(2, want - reduce)
		var covers: Array[float] = [0.85, 0.65, 0.45]
		for cover: float in covers:
			for attempt in range(MAX_ATTEMPTS):
				if evals >= MAX_METRIC_EVALS and not best_any.is_empty():
					break
				var seed_i := int(seed_value) + reduce * 100_000 + int(cover * 1000.0) * 97 + attempt * 7919
				var built := _try_build_snakes(level_id, name, size, n_pairs, cover, seed_i)
				if built.is_empty():
					continue
				if not LevelGenerator.is_solvable(built):
					continue
				_attach_hard_metrics(built)
				evals += 1
				var hs := float(built.get("hard_solve_score", 0.0))
				if hs > best_hs:
					best_hs = hs
					best_any = built
				if _passes_hard_gates(built, other_mode_score, floor_score, true):
					pool_gated.append(built)
			if not pool_gated.is_empty() or (evals >= MAX_METRIC_EVALS and not best_any.is_empty()):
				break
		if not pool_gated.is_empty() or (evals >= MAX_METRIC_EVALS and not best_any.is_empty()):
			break

	if not pool_gated.is_empty():
		var pick := _pick_hardest(pool_gated)
		pick["generator"] = "hard_snakes"
		return pick

	if not best_any.is_empty():
		best_any["generator"] = "hard_snakes"
		best_any["soft_fallback"] = true
		return best_any

	# Absolutamente último: serpiente mínima garantizada (manh 4, 2+ parejas).
	for attempt in range(120):
		var seed_i := int(seed_value) + 900_000 + attempt
		var n_pairs := maxi(2, mini(want, maxi(2, int((size * size) / 8))))
		var built2 := _try_build_snakes(level_id, name, size, n_pairs, 0.40, seed_i)
		if built2.is_empty() or not LevelGenerator.is_solvable(built2):
			continue
		_attach_hard_metrics(built2)
		built2["generator"] = "hard_snakes"
		built2["soft_fallback"] = true
		return built2

	for attempt in range(80):
		var seed_i := int(seed_value) + 950_000 + attempt
		var built3 := _try_build_snakes(level_id, name, size, 2, 0.0, seed_i)
		if built3.is_empty() or not LevelGenerator.is_solvable(built3):
			continue
		_attach_hard_metrics(built3)
		built3["generator"] = "hard_snakes"
		built3["soft_fallback"] = true
		return built3

	return {}


static func _passes_hard_gates(
	level: Dictionary,
	other_mode_score: float,
	floor_score: float,
	strict: bool
) -> bool:
	var score := float(level.get("difficulty_score", 0.0))
	var metrics: Dictionary = level.get("metrics", {})
	var interf := float(metrics.get("interference", 0.0))
	var nodes := int(metrics.get("solver_nodes", 0))
	var size := int(level.get("size", 5))
	var shortcut := float(level.get("shortcut_ratio", 1.0))
	if interf < MIN_INTERFERENCE_SOFT:
		return false
	if nodes < _min_nodes_for_size(size):
		return false
	if shortcut > 0.65:
		return false
	if strict:
		if other_mode_score >= 0.0 and score < other_mode_score + EASY_MARGIN:
			return false
		if floor_score >= 0.0 and score + 0.001 < floor_score:
			return false
	return true


static func _min_nodes_for_size(size: int) -> int:
	return clampi(24 + size * size, 40, 600)


static func _pick_hardest(pool: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = pool[0]
	var best_hs := float(best.get("hard_solve_score", 0.0))
	for level: Dictionary in pool:
		var hs := float(level.get("hard_solve_score", 0.0))
		if hs > best_hs + 0.001:
			best = level
			best_hs = hs
	return best


static func _attach_hard_metrics(level: Dictionary) -> void:
	var metrics := LevelGenerator.compute_metrics(level)
	level["metrics"] = metrics
	level["difficulty_score"] = LevelGenerator.difficulty_score(level)
	var shortcut := _shortcut_ratio(level)
	level["shortcut_ratio"] = shortcut
	var nodes := int(metrics.get("solver_nodes", 0))
	var interf := float(metrics.get("interference", 0.0))
	var detour := float(metrics.get("detour", 1.0))
	var effort := minf(log(float(maxi(0, nodes)) + 1.0) / log(2.0), 12.0)
	level["hard_solve_score"] = (
		effort * W_NODES
		+ interf * W_INTERF
		+ clampf(detour - 1.0, 0.0, 4.0) * W_DETOUR
		- shortcut * W_SHORTCUT_PENALTY
	)


static func _shortcut_ratio(level: Dictionary) -> float:
	var size := int(level.get("size", 0))
	var sol_v: Variant = level.get("solution", null)
	if size < 2 or typeof(sol_v) != TYPE_DICTIONARY:
		return 1.0
	var solution: Dictionary = sol_v
	if solution.is_empty():
		return 1.0
	var cells := size * size
	var endpoint := PackedInt32Array()
	endpoint.resize(cells)
	endpoint.fill(-1)
	var paths: Array = []
	var pi := 0
	for color_v: Variant in solution.keys():
		var raw: Array = solution[color_v]
		var path := PackedInt32Array()
		for point: Variant in raw:
			var arr: Array = point
			path.append(int(arr[1]) * size + int(arr[0]))
		if path.size() < 2:
			return 1.0
		endpoint[path[0]] = pi
		endpoint[path[path.size() - 1]] = pi
		paths.append(path)
		pi += 1
	var easy_count := 0
	var blocked := PackedByteArray()
	blocked.resize(cells)
	for p in range(paths.size()):
		var path: PackedInt32Array = paths[p]
		blocked.fill(0)
		for i in range(cells):
			if endpoint[i] >= 0 and endpoint[i] != p:
				blocked[i] = 1
		var free_dist := _bfs_distance(size, path[0], path[path.size() - 1], blocked)
		var sol_len := path.size() - 1
		if free_dist >= 0 and free_dist <= int(ceil(float(sol_len) * 0.55 + 0.5)):
			easy_count += 1
	return float(easy_count) / float(maxi(1, paths.size()))


## Serpientes con Manhattan mínima en extremos (construcción fiable).
static func _try_build_snakes(
	level_id: int,
	name: String,
	size: int,
	num_colors: int,
	min_cover: float,
	seed_value: int
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var min_manh := MIN_ENDPOINT_MANHATTAN
	var min_path_len := maxi(3, min_manh + 1)

	var colors: Array[String] = []
	for i in range(num_colors):
		colors.append(COLOR_NAMES[i])
	_shuffle_strings(colors, rng)

	var free: Dictionary = {}
	for y in range(size):
		for x in range(size):
			free[Vector2i(x, y)] = true

	var assignment: Dictionary = {}
	var paths: Dictionary = {}
	var total := size * size

	for i in range(colors.size()):
		var color: String = colors[i]
		var remaining := colors.size() - i
		var free_count := free.size()
		var ideal := maxi(min_path_len, int(free_count / float(remaining)))
		var jitter := rng.randi_range(-1, 2)
		var reserve := 2 * maxi(0, remaining - 1)
		var target := maxi(min_path_len, mini(free_count - reserve, ideal + jitter))
		# Sesgo: preferir serpientes más largas / sinuosas (más difíciles).
		if rng.randf() < 0.55:
			target = maxi(target, mini(free_count - reserve, target + rng.randi_range(1, 3)))
		var path := _grow_snake(size, free, target, rng, min_manh)
		if path.is_empty():
			return {}
		for cell: Vector2i in path:
			assignment[cell] = color
			free.erase(cell)
		paths[color] = path

	_absorb_free(size, free, paths, assignment, min_manh)

	for color_v: Variant in paths.keys():
		var p: Array = paths[color_v]
		if p.size() < min_path_len:
			return {}
		var a: Vector2i = p[0]
		var b: Vector2i = p[p.size() - 1]
		if absi(a.x - b.x) + absi(a.y - b.y) < min_manh:
			return {}

	var cover := float(total - free.size()) / float(total)
	if cover < min_cover:
		return {}

	return _level_from_assignment(level_id, name, size, assignment, min_manh)


static func _absorb_free(
	size: int,
	free: Dictionary,
	paths: Dictionary,
	assignment: Dictionary,
	min_manh: int
) -> void:
	var changed := true
	var guard := 0
	while changed and not free.is_empty() and guard < size * size * 4:
		guard += 1
		changed = false
		for color_name: Variant in paths.keys():
			var color := str(color_name)
			var path: Array = paths[color]
			for at_head in [true, false]:
				var tip: Vector2i = path[0] if at_head else path[path.size() - 1]
				for i in range(4):
					var nxt := Vector2i(tip.x + DX[i], tip.y + DY[i])
					if not _in_bounds(nxt, size) or not free.has(nxt):
						continue
					if not _extension_ok(nxt, tip, color, assignment):
						continue
					var new_a: Vector2i = nxt if at_head else path[0]
					var new_b: Vector2i = path[path.size() - 1] if at_head else nxt
					if absi(new_a.x - new_b.x) + absi(new_a.y - new_b.y) < min_manh:
						continue
					if at_head:
						path.insert(0, nxt)
					else:
						path.append(nxt)
					assignment[nxt] = color
					free.erase(nxt)
					paths[color] = path
					changed = true
					break


static func _extension_ok(nxt: Vector2i, tip: Vector2i, color: String, assignment: Dictionary) -> bool:
	for i in range(4):
		var nb := Vector2i(nxt.x + DX[i], nxt.y + DY[i])
		if nb == tip:
			continue
		if assignment.has(nb) and str(assignment[nb]) == color:
			return false
	return true


static func _grow_snake(
	size: int,
	free: Dictionary,
	target_len: int,
	rng: RandomNumberGenerator,
	min_manh: int
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for key: Variant in free.keys():
		candidates.append(key as Vector2i)
	_shuffle_vec(candidates, rng)

	var min_len := maxi(3, min_manh + 1)
	var best: Array[Vector2i] = []
	var max_starts := mini(20, candidates.size())
	for si in range(max_starts):
		var path: Array[Vector2i] = [candidates[si]]
		while path.size() < target_len:
			var tip: Vector2i = path[path.size() - 1]
			var opts: Array[Vector2i] = []
			for i in range(4):
				var nxt := Vector2i(tip.x + DX[i], tip.y + DY[i])
				if not _in_bounds(nxt, size) or not free.has(nxt):
					continue
				if path.has(nxt):
					continue
				if not _snake_extend_ok(path, nxt):
					continue
				opts.append(nxt)
			if opts.is_empty():
				break
			# Preferir pasos que alejen el extremo del inicio (más Manhattan final).
			opts.sort_custom(func(p: Vector2i, q: Vector2i) -> bool:
				var ap := absi(p.x - path[0].x) + absi(p.y - path[0].y)
				var aq := absi(q.x - path[0].x) + absi(q.y - path[0].y)
				if ap != aq:
					return ap > aq
				if p.y != q.y:
					return p.y < q.y
				return p.x < q.x
			)
			var chosen: Vector2i = opts[0]
			if opts.size() > 1 and rng.randf() < 0.35:
				chosen = opts[rng.randi_range(0, mini(2, opts.size() - 1))]
			path.append(chosen)
		if path.size() < min_len:
			continue
		if absi(path[0].x - path[path.size() - 1].x) + absi(path[0].y - path[path.size() - 1].y) < min_manh:
			continue
		if path.size() > best.size():
			best = path
		if best.size() >= target_len:
			break

	if best.size() < min_len:
		return []
	if absi(best[0].x - best[best.size() - 1].x) + absi(best[0].y - best[best.size() - 1].y) < min_manh:
		return []
	return best


static func _snake_extend_ok(path: Array[Vector2i], nxt: Vector2i) -> bool:
	var tip: Vector2i = path[path.size() - 1]
	for i in range(4):
		var nb := Vector2i(nxt.x + DX[i], nxt.y + DY[i])
		if nb == tip:
			continue
		if path.has(nb):
			return false
	return true


static func _level_from_assignment(
	level_id: int,
	name: String,
	size: int,
	assignment: Dictionary,
	min_manh: int
) -> Dictionary:
	var grouped: Dictionary = {}
	for cell_v: Variant in assignment.keys():
		var pos: Vector2i = cell_v
		var color := str(assignment[cell_v])
		if not grouped.has(color):
			grouped[color] = []
		grouped[color].append(pos)

	var dots: Array = []
	var solution: Dictionary = {}
	var par := 0
	for color_name: Variant in grouped.keys():
		var color := str(color_name)
		var cells: Array[Vector2i] = []
		for item: Variant in grouped[color]:
			cells.append(item as Vector2i)
		var path := _trace_path(cells)
		if path.is_empty() or path.size() < 3:
			return {}
		if absi(path[0].x - path[path.size() - 1].x) + absi(path[0].y - path[path.size() - 1].y) < min_manh:
			return {}
		var path_arrays: Array = []
		for p: Vector2i in path:
			path_arrays.append([p.x, p.y])
		solution[color] = path_arrays
		dots.append({"color": color, "x": path[0].x, "y": path[0].y})
		dots.append({"color": color, "x": path[path.size() - 1].x, "y": path[path.size() - 1].y})
		par += path.size() - 1

	return {
		"id": level_id,
		"name": name,
		"size": size,
		"dots": dots,
		"solution": solution,
		"par": par,
	}


static func _trace_path(cells: Array[Vector2i]) -> Array[Vector2i]:
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
			if nb == prev or not cell_set.has(nb) or path.has(nb):
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


static func _bfs_distance(size: int, a: int, b: int, blocked: PackedByteArray) -> int:
	if a == b:
		return 0
	var cells := size * size
	var dist := PackedInt32Array()
	dist.resize(cells)
	dist.fill(-1)
	var queue := PackedInt32Array()
	queue.resize(cells)
	var head := 0
	var tail := 0
	queue[tail] = a
	tail += 1
	dist[a] = 0
	while head < tail:
		var cur := queue[head]
		head += 1
		var cx := cur % size
		var cy := int(cur / size)
		var nbs: Array[int] = []
		if cx > 0:
			nbs.append(cur - 1)
		if cx < size - 1:
			nbs.append(cur + 1)
		if cy > 0:
			nbs.append(cur - size)
		if cy < size - 1:
			nbs.append(cur + size)
		for nb: int in nbs:
			if dist[nb] != -1:
				continue
			if nb == b:
				return dist[cur] + 1
			if blocked[nb] != 0:
				continue
			dist[nb] = dist[cur] + 1
			queue[tail] = nb
			tail += 1
	return -1


static func _in_bounds(c: Vector2i, size: int) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size and c.y < size


static func _shuffle_vec(arr: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


static func _shuffle_strings(arr: Array[String], rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
