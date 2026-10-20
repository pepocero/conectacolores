class_name LevelGenerator
extends RefCounted

## Genera niveles Flow resolubles por construcción (serpientes → dots + solution).

const GENERATOR_VERSION := 10
## Fin del primer tramo de la curva (1..99); desde aquí rige stepped_size_and_pairs.
const LEGACY_LAST_LEVEL := 99
## Sandbox conserva sus semillas originales (no depende de la curva de rejilla).
const SANDBOX_SEED_VERSION_LOW := 4
const SANDBOX_SEED_VERSION_HIGH := 7
## Radio normalizado de una roca (más pequeña → más separación útil entre ellas).
const SANDBOX_ROCK_R := 0.038
## Arena libre preferida entre rocas y respecto al borde (surco a mano alzada).
const SANDBOX_GAP_PREF := 0.095
## Holgura mínima si el nivel está muy lleno.
const SANDBOX_GAP_MIN := 0.055
## Intentos / tamaño del pool al elegir el layout Sandbox más difícil.
const SANDBOX_EVAL_ATTEMPTS := 80
const SANDBOX_POOL_TARGET := 8
## Anchura del corredor (norm.) para contar rocas que bloquean el trazo recto.
const SANDBOX_BLOCK_CORRIDOR := 0.048
## Holgura entre surcos / rocas ajenas al buscar rutas planas (norm.).
const SANDBOX_ROUTE_CLEARANCE := 0.032
## Rejilla fina para pathfinding de surcos a mano alzada (curvas / oblicuos).
const SANDBOX_ROUTE_GRID := 28
## Distancia mínima entre extremos de una pareja = esta fracción de la diagonal jugable.
const SANDBOX_PAIR_DIAG_FRAC := 0.42
## Suelo de validación / soft (sigue siendo “lado opuesto”, no dos celdas).
const SANDBOX_PAIR_DIAG_FRAC_MIN := 0.34
## Candidatos de rejilla respecto a 2·parejas (más slots → mates diametrales reales).
const SANDBOX_CANDIDATE_FACTOR := 1.6
const CAMPAIGN_END := 200
const INFINITE_START := 201

## Desde STEPPED_START el tablero crece por bloques de STEP_LEVELS (salto extra en
## THEME_JUMPS), pero solo mientras los colores disponibles mantengan la densidad.
const STEPPED_START := 100
const STEP_LEVELS := 25
const THEME_JUMPS: Array[int] = [100, 201]
const LEGACY_END_SIZE := 8
## Casillas por pareja (cpp): cuanto menor, más parejas compiten por el espacio.
## 1..99 va de START a END; 100+ sigue bajando hasta FLOOR.
const CPP_EASY_START := 12.0
const CPP_EASY_END := 6.5
const CPP_EASY_FLOOR := 5.5
const CPP_HARD_START := 8.5
const CPP_HARD_END := 5.0
const CPP_HARD_FLOOR := 4.2
const CPP_HARDCORE_START := 5.5
const CPP_HARDCORE_END := 3.6
const CPP_HARDCORE_FLOOR := 3.2
## Hardcore +0 equivale al extra +2 antiguo (tablero y parejas).
const HARDCORE_BASE_BONUS := 2
## Modo Crazy: nivel N usa la curva de Difícil N+OFFSET (Crazy 1 → Difícil 90).
const CHRONO_HARD_LEVEL_OFFSET := 89
const LevelSolverScript := preload("res://scripts/level_solver.gd")
## Presupuesto de nodos del solucionador por candidato (acota el tiempo de carga).
const SOLVER_BUDGET := 2500
## Candidatos válidos evaluados con el solucionador por tanda.
const EVAL_CANDIDATES := 6
## Pesos de difficulty_score (ver _score_from).
const SCORE_W_DENSITY := 4.0
const SCORE_W_SIZE := 3.5
const SCORE_W_DETOUR := 1.0
const SCORE_W_INTERFERENCE := 2.0
const SCORE_W_EFFORT := 0.5
const SCORE_W_COVER := 8.0
const SCORE_W_LEVEL := 0.5
const DETOUR_CAP := 3.0
const EFFORT_LOG_CAP := 8.0
## Al elegir candidato, cuánto puede superar como mucho al mínimo exigido.
const MAX_STEP_ABOVE_FLOOR := 6.0
const MAX_SIZE_EASY := 14
const MAX_SIZE_HARD := 15
const MAX_SIZE := MAX_SIZE_HARD
const MAX_PAIRS := 16
const CUSTOM_GRID_MIN := 4
const CUSTOM_GRID_MAX := 15

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

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]


static func params_for(mode_id: String, level_id: int) -> Dictionary:
	var is_chrono := mode_id == "chrono"
	## Crazy 1 ≡ Difícil 90; Crazy N ≡ Difícil N+89.
	var n := maxi(1, level_id + CHRONO_HARD_LEVEL_OFFSET) if is_chrono else maxi(1, level_id)
	var is_hard := mode_id == "hard" or is_chrono
	var is_hardcore := mode_id == "hardcore"
	## Crazy usa curva Difícil (en el nivel equivalente) + techos Hardcore.
	var curve_mode := "hard" if is_chrono else mode_id

	var size := 5
	var colors := 2
	var min_cover := 0.55

	var curve := _curve_size_pairs_mode(curve_mode, n)
	size = curve.x
	colors = curve.y
	if n <= LEGACY_LAST_LEVEL:
		var t := float(n - 1) / float(LEGACY_LAST_LEVEL - 1)
		if is_hardcore or is_chrono:
			min_cover = lerpf(0.95, 0.98, t)
		elif is_hard:
			min_cover = lerpf(0.90, 0.96, t)
		else:
			min_cover = lerpf(0.86, 0.94, t)
	else:
		var t := clampf(float(n - STEPPED_START) / 350.0, 0.0, 1.0)
		if is_hardcore or is_chrono:
			min_cover = lerpf(0.96, 0.98, t)
		elif is_hard:
			min_cover = lerpf(0.91, 0.97, t)
		else:
			min_cover = lerpf(0.87, 0.95, t)

	var diff_bonus := 0
	var custom_grid := 0
	var custom_pairs := 0
	var custom_on := false
	if SettingsManager != null:
		custom_grid = SettingsManager.get_custom_grid_size()
		custom_pairs = SettingsManager.get_custom_pair_count()
		custom_on = custom_grid > 0 or custom_pairs > 0
		if not custom_on:
			diff_bonus = SettingsManager.get_difficulty_bonus(mode_id)

	if (is_hardcore or is_chrono) and not custom_on:
		size += HARDCORE_BASE_BONUS
		colors += HARDCORE_BASE_BONUS

	var min_sz := 6 if is_hardcore or is_chrono else 5
	if custom_grid > 0:
		size = clampi(custom_grid, CUSTOM_GRID_MIN, max_size_for(mode_id))
	else:
		size = clampi(size + diff_bonus, min_sz, max_size_for(mode_id))
		if custom_pairs > 0:
			size = clampi(maxi(size, min_grid_for_pairs(custom_pairs)), min_sz, max_size_for(mode_id))

	if custom_pairs > 0:
		colors = custom_pairs
	else:
		colors = clampi(colors + diff_bonus, 2, mini(MAX_PAIRS, COLOR_NAMES.size()))
	min_cover = clampf(min_cover, 0.45, 0.98 if (is_hardcore or is_chrono) else 0.97)

	# Canjes de pistas: más parejas y tablero más compacto (acumulativo por modo).
	var density_steps := 0
	var applied_density := 0
	if not custom_on and SaveManager != null:
		density_steps = SaveManager.get_skip_density_steps(mode_id)
		for _i in range(density_steps):
			var min_size := 6 if is_hard or is_hardcore else 5
			var next_size := maxi(min_size, size - 1)
			var next_colors := colors + 1
			var area_cap := maxi(2, int((next_size * next_size) / 3))
			if next_colors > mini(MAX_PAIRS, mini(COLOR_NAMES.size(), area_cap)):
				# No cabe bajar tamaño: solo subir parejas hasta el techo del size actual.
				area_cap = maxi(2, int((size * size) / 3))
				var capped := mini(MAX_PAIRS, mini(COLOR_NAMES.size(), area_cap))
				if colors < capped:
					colors += 1
					applied_density += 1
				continue
			size = next_size
			colors = next_colors
			applied_density += 1

	# Difícil: al menos 1 pareja más que la curva fácil del mismo nivel (sin custom).
	if is_hard and not is_chrono and not custom_on and custom_pairs <= 0:
		var easy_pairs := int(_curve_size_pairs_mode("easy", n).y)
		colors = maxi(colors, easy_pairs + 1)

	# Hardcore / Crazy: al menos 2 parejas más que la curva Difícil del nivel (sin custom).
	if (is_hardcore or is_chrono) and not custom_on and custom_pairs <= 0:
		var hard_pairs := int(_curve_size_pairs_mode("hard", n).y)
		colors = maxi(colors, hard_pairs + 2)

	# Cada pareja necesita al menos 2 celdas; el generador usa caminos >= 3.
	var max_pairs := max_pairs_for_grid(size)
	colors = clampi(colors, 2, max_pairs)

	return {
		"size": size,
		"colors": colors,
		"min_cover": min_cover,
		"difficulty_bonus": diff_bonus,
		"size_bonus": diff_bonus if not custom_on else 0,
		"pair_bonus": diff_bonus if not custom_on else 0,
		"custom_grid_size": custom_grid,
		"custom_pair_count": custom_pairs,
		"skip_density_steps": density_steps,
		"applied_density": applied_density,
	}


static func max_size_for(mode_id: String) -> int:
	return (
		MAX_SIZE_HARD
		if mode_id == "hard" or mode_id == "hardcore" or mode_id == "chrono"
		else MAX_SIZE_EASY
	)


static func clamp_custom_grid(value: int) -> int:
	if value <= 0:
		return 0
	return clampi(value, CUSTOM_GRID_MIN, CUSTOM_GRID_MAX)


static func max_pairs_for_grid(size: int) -> int:
	var cells := maxi(1, size * size)
	return clampi(int(cells / 3), 2, mini(MAX_PAIRS, COLOR_NAMES.size()))


static func min_grid_for_pairs(pairs: int) -> int:
	var need := clampi(pairs, 2, mini(MAX_PAIRS, COLOR_NAMES.size()))
	for n in range(CUSTOM_GRID_MIN, CUSTOM_GRID_MAX + 1):
		if int((n * n) / 3) >= need:
			return n
	return CUSTOM_GRID_MAX


static func clamp_custom_pairs(pairs: int, grid: int) -> int:
	if pairs <= 0:
		return 0
	var max_p := mini(MAX_PAIRS, COLOR_NAMES.size())
	if grid > 0:
		max_p = mini(max_p, max_pairs_for_grid(grid))
	return clampi(pairs, 2, max_p)


## Lado y parejas base (sin bonus). Recorre 1..n para que la densidad (casillas
## por pareja) nunca suba al agrandar el tablero.
static func stepped_size_and_pairs(is_hard: bool, level_id: int) -> Vector2i:
	return _curve_size_pairs(is_hard, level_id)


static func _curve_size_pairs(is_hard: bool, level_id: int) -> Vector2i:
	return _curve_size_pairs_mode("hard" if is_hard else "easy", level_id)


static func _curve_size_pairs_mode(mode_id: String, level_id: int) -> Vector2i:
	var n := maxi(1, level_id)
	var is_hardcore := mode_id == "hardcore"
	var is_dense := mode_id == "hard" or is_hardcore
	var max_size := MAX_SIZE_HARD if is_dense else MAX_SIZE_EASY
	var max_pairs := mini(MAX_PAIRS, COLOR_NAMES.size())
	var size := 0
	var pairs := 2
	var last_cpp := 99.0
	for i in range(1, n + 1):
		var next_size := _size_for_curve_mode(mode_id, i, max_size, max_pairs)
		if is_hardcore:
			next_size = maxi(next_size, 7)
		var target_cpp := _cpp_for_curve_mode(mode_id, i)
		var cap_cpp := minf(target_cpp, last_cpp)
		# Al agrandar el tablero, modos densos entran más apretados (Hardcore más que Difícil).
		if is_hardcore and next_size > size:
			cap_cpp *= 0.82
		elif is_dense and next_size > size:
			cap_cpp *= 0.88
		size = next_size
		var need := ceili(float(size * size) / maxf(cap_cpp, 0.1))
		pairs = clampi(maxi(pairs, need), 2, max_pairs)
		last_cpp = float(size * size) / float(pairs)
	return Vector2i(size, pairs)


static func _size_for_curve(is_hard: bool, n: int, max_size: int, max_pairs: int) -> int:
	return _size_for_curve_mode("hard" if is_hard else "easy", n, max_size, max_pairs)


static func _size_for_curve_mode(mode_id: String, n: int, max_size: int, max_pairs: int) -> int:
	var is_hardcore := mode_id == "hardcore"
	var is_hard := mode_id == "hard"
	if n <= LEGACY_LAST_LEVEL:
		if is_hardcore:
			# Por encima de Difícil; tras HARDCORE_BASE_BONUS: 9 / 10 / 11.
			if n <= 7:
				return 7
			if n <= 35:
				return 8
			return 9
		if is_hard:
			# Separar de Fácil (6×6 en L6–20): Difícil pasa a 7×7 desde L8.
			if n <= 7:
				return 6
			if n <= 35:
				return 7
			return 8
		if n <= 5:
			return 5
		if n <= 20:
			return 6
		if n <= 50:
			return 7
		return 8
	var jumps := 0
	for jump_level: int in THEME_JUMPS:
		if n >= jump_level:
			jumps += 1
	var blocks := int((n - STEPPED_START) / STEP_LEVELS)
	var size := mini(LEGACY_END_SIZE + 1 + jumps + int(blocks / 2), max_size)
	var cpp_limit := CPP_EASY_END
	if is_hardcore:
		cpp_limit = CPP_HARDCORE_END
	elif is_hard:
		cpp_limit = CPP_HARD_END
	while size > LEGACY_END_SIZE and float(size * size) / float(max_pairs) > cpp_limit:
		size -= 1
	return size


static func _cpp_for_curve(is_hard: bool, n: int) -> float:
	return _cpp_for_curve_mode("hard" if is_hard else "easy", n)


static func _cpp_for_curve_mode(mode_id: String, n: int) -> float:
	if n <= LEGACY_LAST_LEVEL:
		var t := float(n - 1) / float(LEGACY_LAST_LEVEL - 1)
		if mode_id == "hardcore":
			return lerpf(CPP_HARDCORE_START, CPP_HARDCORE_END, t)
		return lerpf(CPP_HARD_START, CPP_HARD_END, t) if mode_id == "hard" else lerpf(CPP_EASY_START, CPP_EASY_END, t)
	var t := clampf(float(n - STEPPED_START) / 350.0, 0.0, 1.0)
	if mode_id == "hardcore":
		return lerpf(CPP_HARDCORE_END, CPP_HARDCORE_FLOOR, t)
	return lerpf(CPP_HARD_END, CPP_HARD_FLOOR, t) if mode_id == "hard" else lerpf(CPP_EASY_END, CPP_EASY_FLOOR, t)


## Puntuación de dificultad. En rejilla usa métricas del tablero real (ver
## compute_metrics); _min_cover se mantiene por compatibilidad y no se usa.
static func difficulty_score(level: Dictionary, _min_cover: float = -1.0) -> float:
	if str(level.get("mode", "")) == "sandbox" or typeof(level.get("rocks", null)) == TYPE_ARRAY:
		var rocks: Array = level.get("rocks", [])
		return _sandbox_layout_score(rocks, int(level.get("id", 1)))
	var metrics: Dictionary
	if typeof(level.get("metrics", null)) == TYPE_DICTIONARY:
		metrics = level["metrics"]
	else:
		metrics = compute_metrics(level)
	var solution: Dictionary = level.get("solution", {})
	return _score_from(
		int(level.get("size", 5)),
		solution.size(),
		float(metrics.get("cover", 0.0)),
		float(metrics.get("detour", 1.0)),
		float(metrics.get("interference", 0.0)),
		int(metrics.get("solver_nodes", 0)),
		int(level.get("id", 1))
	)


## Combina las métricas en una sola puntuación.
## - Densidad (parejas por cada 100 casillas): el factor principal.
## - Lado del tablero: caminos más largos y más espacio que explorar.
## - Desvío medio de la solución (largo / Manhattan), con tope.
## - Interferencia: fracción de parejas cuyo camino más corto pisa otra solución.
## - Esfuerzo del solucionador: log2(nodos) hasta resolver.
## - Cobertura real del tablero.
static func _score_from(
	size: int,
	pairs: int,
	cover: float,
	detour: float,
	interference: float,
	solver_nodes: int,
	level_id: int = 1
) -> float:
	var cells := float(maxi(1, size * size))
	var pairs_per_100 := float(pairs) * 100.0 / cells
	var effort := minf(log(float(maxi(0, solver_nodes)) + 1.0) / log(2.0), EFFORT_LOG_CAP)
	return (
		pairs_per_100 * SCORE_W_DENSITY
		+ float(size) * SCORE_W_SIZE
		+ clampf(detour - 1.0, 0.0, DETOUR_CAP) * SCORE_W_DETOUR
		+ clampf(interference, 0.0, 1.0) * SCORE_W_INTERFERENCE
		+ effort * SCORE_W_EFFORT
		+ clampf(cover, 0.0, 1.0) * SCORE_W_COVER
		+ float(maxi(1, level_id)) * SCORE_W_LEVEL
	)


## Métricas de un nivel de rejilla: cobertura real, desvío, interferencia y
## esfuerzo del solucionador con backtracking.
static func compute_metrics(level: Dictionary) -> Dictionary:
	var size := int(level.get("size", 0))
	var result := {"cover": 0.0, "detour": 1.0, "interference": 0.0, "solver_nodes": 0, "solver_solved": false}
	var solution_v: Variant = level.get("solution", null)
	if size < 2 or typeof(solution_v) != TYPE_DICTIONARY:
		return result
	var solution: Dictionary = solution_v
	if solution.is_empty():
		return result

	var cells := size * size
	var paths: Array = [] # Array[PackedInt32Array] (índices y * size + x)
	var owner_of := PackedInt32Array()
	owner_of.resize(cells)
	owner_of.fill(-1)
	var endpoint := PackedInt32Array()
	endpoint.resize(cells)
	endpoint.fill(-1)
	var filled := 0
	var detour_sum := 0.0
	var path_i := 0
	for color_v: Variant in solution.keys():
		var raw: Array = solution[color_v]
		var path := PackedInt32Array()
		for point: Variant in raw:
			var arr: Array = point
			var idx := int(arr[1]) * size + int(arr[0])
			path.append(idx)
			owner_of[idx] = path_i
		if path.size() < 2:
			return result
		endpoint[path[0]] = path_i
		endpoint[path[path.size() - 1]] = path_i
		filled += path.size()
		var manhattan := _idx_manhattan(path[0], path[path.size() - 1], size)
		detour_sum += float(path.size() - 1) / float(maxi(1, manhattan))
		paths.append(path)
		path_i += 1

	var interfering := 0
	var blocked := PackedByteArray()
	blocked.resize(cells)
	for p in range(paths.size()):
		var path: PackedInt32Array = paths[p]
		var a := path[0]
		var b := path[path.size() - 1]
		# 1) Solo bloquean las bolas ajenas.
		blocked.fill(0)
		for i in range(cells):
			if endpoint[i] >= 0 and endpoint[i] != p:
				blocked[i] = 1
		var free_dist := _bfs_distance(size, a, b, blocked)
		# 2) Además bloquean las soluciones de las demás parejas.
		for i in range(cells):
			if owner_of[i] >= 0 and owner_of[i] != p:
				blocked[i] = 1
		var solved_dist := _bfs_distance(size, a, b, blocked)
		if solved_dist < 0 or (free_dist >= 0 and free_dist < solved_dist):
			interfering += 1

	var solver = LevelSolverScript.new()
	var solve: Dictionary = solver.run(level, SOLVER_BUDGET)

	result["cover"] = float(filled) / float(cells)
	result["detour"] = detour_sum / float(maxi(1, paths.size()))
	result["interference"] = float(interfering) / float(maxi(1, paths.size()))
	result["solver_nodes"] = int(solve.get("nodes", 0))
	result["solver_solved"] = bool(solve.get("solved", false))
	return result


static func _idx_manhattan(a: int, b: int, size: int) -> int:
	return absi(a % size - b % size) + absi(int(a / size) - int(b / size))


## Distancia en pasos de a a b evitando casillas bloqueadas; -1 si no hay camino.
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


## Estimación sin generar el nivel (sin solucionador). Misma escala que difficulty_score.
static func baseline_score(mode_id: String, level_id: int) -> float:
	if mode_id == "sandbox":
		var sp := sandbox_params_for(level_id)
		# Escala alineada con _sandbox_layout_score (bloqueo/longitud se suman al generar).
		return float(sp.pairs) * 18.0 + float(sp.pairs) * 8.0 + float(level_id) * 0.4
	var p := params_for(mode_id, level_id)
	var size := int(p.size)
	var colors := int(p.colors)
	var pairs_per_100 := float(colors) * 100.0 / float(maxi(1, size * size))
	var est_detour := 1.0 + clampf(0.4 + pairs_per_100 * 0.04, 0.0, DETOUR_CAP)
	var est_interference := clampf(0.15 + pairs_per_100 * 0.025, 0.0, 0.9)
	var est_nodes := int(pow(2.0, clampf(1.5 + pairs_per_100 * 0.3 + float(size) * 0.25, 0.0, 11.3)))
	return _score_from(size, colors, float(p.min_cover), est_detour, est_interference, est_nodes, level_id)


static func make_seed(mode_id: String, level_id: int, attempt: int) -> int:
	var mode_n := 0
	if mode_id == "hard":
		mode_n = 1
	elif mode_id == "sandbox":
		mode_n = 2
	elif mode_id == "hardcore":
		mode_n = 3
	elif mode_id == "chrono":
		mode_n = 4
	var diff_bonus := 0
	var custom_grid := 0
	var custom_pairs := 0
	if SettingsManager != null:
		custom_grid = SettingsManager.get_custom_grid_size()
		custom_pairs = SettingsManager.get_custom_pair_count()
		if custom_grid <= 0 and custom_pairs <= 0:
			diff_bonus = SettingsManager.get_difficulty_bonus(mode_id)
	var version := GENERATOR_VERSION
	if mode_id == "sandbox":
		version = SANDBOX_SEED_VERSION_LOW if level_id <= LEGACY_LAST_LEVEL else SANDBOX_SEED_VERSION_HIGH
	return int(
		hash(
			"%d_%d_%d_%d_%d_%d_%d"
			% [version, mode_n, level_id, attempt, diff_bonus, custom_grid, custom_pairs]
		)
	)


static func level_name(mode_id: String, level_id: int) -> String:
	if mode_id == "hard":
		return "Reto %d" % level_id
	if mode_id == "sandbox":
		return "Arena %d" % level_id
	if mode_id == "hardcore":
		return "Hardcore %d" % level_id
	if mode_id == "chrono":
		return "Crazy %d" % level_id
	return "Nivel %d" % level_id


static func sandbox_params_for(level_id: int) -> Dictionary:
	var n := maxi(1, level_id)
	# Empieza en 5 parejas; sube con el nivel (máx. 8 + bonus de dificultad).
	var pairs := 5
	if n <= 20:
		pairs = 5
	elif n <= 50:
		pairs = 6
	elif n <= 100:
		pairs = 7
	else:
		pairs = mini(8, 7 + int((n - 101) / 50))
	var diff_bonus := 0
	var custom_pairs := 0
	if SettingsManager != null:
		custom_pairs = SettingsManager.get_custom_pair_count()
		if custom_pairs <= 0:
			diff_bonus = SettingsManager.get_difficulty_bonus("sandbox")
	if custom_pairs > 0:
		pairs = custom_pairs
	else:
		pairs = pairs + diff_bonus
	pairs = clampi(pairs, 2, COLOR_NAMES.size())
	var spacing := _sandbox_spacing(pairs)
	return {
		"pairs": pairs,
		"min_sep": float(spacing.min_sep),
		"edge_inset": float(spacing.inset),
		"difficulty_bonus": diff_bonus,
		"custom_pair_count": custom_pairs,
	}


static func generate(
	mode_id: String,
	level_id: int,
	prev_score: float = -1.0,
	other_mode_score: float = -1.0
) -> Dictionary:
	if mode_id == "sandbox":
		return generate_sandbox(level_id, prev_score)

	var params := params_for(mode_id, level_id)
	var name := level_name(mode_id, level_id)
	var min_delta := 0.8
	if mode_id == "hardcore" or mode_id == "chrono":
		min_delta = 2.0
	elif mode_id == "hard":
		min_delta = 1.0
	var floor_score := prev_score + min_delta if prev_score >= 0.0 else -1.0
	var target := baseline_score(mode_id, level_id)
	var size := int(params.size)
	var colors := int(params.colors)
	var min_cover := float(params.min_cover)
	var gen_path := "none"

	# 1) Varias tandas de candidatos con la cobertura pedida.
	var pool: Array[Dictionary] = []
	for batch in range(3):
		_collect_candidates(pool, level_id, name, size, colors, min_cover, mode_id, batch * 100, 100)
		var pick := _pick_candidate(pool, mode_id, floor_score, other_mode_score, target)
		if not pick.is_empty():
			_stamp_params(pick, params)
			gen_path = "full"
			_log_hard_diag(mode_id, level_id, pick, params, gen_path)
			return pick

	# 2) Sin candidato que supere al anterior: cobertura relajada, misma exigencia.
	var relaxed_cover := maxf(0.45, min_cover - 0.2)
	_collect_candidates(pool, level_id, name, size, colors, relaxed_cover, mode_id, 10_000, 120)
	var relaxed_pick := _pick_candidate(pool, mode_id, floor_score, other_mode_score, target)
	if not relaxed_pick.is_empty():
		_stamp_params(relaxed_pick, params)
		gen_path = "relaxed_cover"
		_log_hard_diag(mode_id, level_id, relaxed_pick, params, gen_path)
		return relaxed_pick

	# 3) Ninguno llega al mínimo: el más difícil de todos los válidos.
	# Hard/Hardcore: preferir candidatos por encima del modo inferior del mismo nivel.
	if not pool.is_empty():
		var hardest := _hardest_candidate(pool)
		if (mode_id == "hard" or mode_id == "hardcore" or mode_id == "chrono") and other_mode_score >= 0.0:
			var hard_ok := _hardest_above_other(pool, other_mode_score)
			if not hard_ok.is_empty():
				hardest = hard_ok
		_stamp_params(hardest, params)
		gen_path = "pool_hardest"
		_log_hard_diag(mode_id, level_id, hardest, params, gen_path)
		return hardest

	# 4) Último recurso: reducir parejas / cover (marcar soft; hard/hardcore evita si puede).
	var soft_best: Dictionary = {}
	for reduce in range(1, 4):
		var reduced_colors := maxi(2, colors - reduce)
		var soft_cover := maxf(0.45, min_cover - 0.25)
		for attempt in range(40):
			var seed_value := make_seed(mode_id, level_id, 20_000 + reduce * 100 + attempt)
			var level := _try_build(level_id, name, size, reduced_colors, soft_cover, seed_value)
			if level.is_empty() or not is_solvable(level):
				continue
			_attach_metrics(level)
			if (mode_id == "hard" or mode_id == "hardcore" or mode_id == "chrono") and other_mode_score >= 0.0:
				if float(level.get("difficulty_score", 0.0)) <= other_mode_score:
					if soft_best.is_empty() or float(level.get("difficulty_score", 0.0)) > float(
						soft_best.get("difficulty_score", 0.0)
					):
						soft_best = level
					continue
			level["soft_fallback"] = true
			level["soft_reduced_colors"] = reduced_colors
			_stamp_params(level, params)
			gen_path = "reduced_colors_%d" % reduce
			_log_hard_diag(mode_id, level_id, level, params, gen_path)
			return level

	if not soft_best.is_empty():
		soft_best["soft_fallback"] = true
		_stamp_params(soft_best, params)
		gen_path = "reduced_below_other"
		_log_hard_diag(mode_id, level_id, soft_best, params, gen_path)
		return soft_best

	push_error("LevelGenerator: no se pudo generar %s #%d" % [mode_id, level_id])
	return {}


static func _hardest_above_other(pool: Array[Dictionary], other_score: float) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	for level: Dictionary in pool:
		var score := float(level.get("difficulty_score", 0.0))
		if score <= other_score:
			continue
		if score > best_score:
			best = level
			best_score = score
	return best


static func _log_hard_diag(
	mode_id: String,
	level_id: int,
	level: Dictionary,
	params: Dictionary,
	gen_path: String
) -> void:
	if level_id > 20:
		return
	if mode_id != "hard" and mode_id != "hardcore" and mode_id != "chrono":
		return
	var tag := "[HardcoreGen]" if mode_id == "hardcore" else "[HardGen]"
	var sol: Dictionary = level.get("solution", {})
	print(
		"%s L%d want=%dx%d/%d cover=%.2f got=%dx%d/%d score=%.1f path=%s soft=%s"
		% [
			tag,
			level_id,
			int(params.get("size", 0)),
			int(params.get("size", 0)),
			int(params.get("colors", 0)),
			float(params.get("min_cover", 0.0)),
			int(level.get("size", 0)),
			int(level.get("size", 0)),
			sol.size(),
			float(level.get("difficulty_score", 0.0)),
			gen_path,
			str(bool(level.get("soft_fallback", false))),
		]
	)


## Construye hasta EVAL_CANDIDATES niveles válidos y les añade métricas y puntuación.
static func _collect_candidates(
	pool: Array[Dictionary],
	level_id: int,
	name: String,
	size: int,
	colors: int,
	min_cover: float,
	mode_id: String,
	seed_offset: int,
	max_attempts: int
) -> void:
	var built := 0
	for attempt in range(max_attempts):
		if built >= EVAL_CANDIDATES:
			return
		var seed_value := make_seed(mode_id, level_id, seed_offset + attempt)
		var level := _try_build(level_id, name, size, colors, min_cover, seed_value)
		if level.is_empty() or not is_solvable(level):
			continue
		_attach_metrics(level)
		pool.append(level)
		built += 1


static func _attach_metrics(level: Dictionary) -> void:
	var metrics := compute_metrics(level)
	level["metrics"] = metrics
	level["difficulty_score"] = difficulty_score(level)


## Candidato que supera al nivel anterior (floor_score) y respeta easy < hard.
## Entre los válidos, el más cercano al objetivo, sin pasarse demasiado del mínimo
## para dejar margen de subida a los niveles siguientes.
static func _pick_candidate(
	pool: Array[Dictionary],
	mode_id: String,
	floor_score: float,
	other_mode_score: float,
	target: float
) -> Dictionary:
	var feasible: Array[Dictionary] = []
	for level: Dictionary in pool:
		var score := float(level.get("difficulty_score", 0.0))
		if floor_score >= 0.0 and score + 0.001 < floor_score:
			continue
		if other_mode_score >= 0.0:
			if mode_id == "hardcore" and score <= other_mode_score:
				continue
			if (mode_id == "hard" or mode_id == "chrono") and score <= other_mode_score:
				continue
			if mode_id == "easy" and score >= other_mode_score:
				continue
		feasible.append(level)
	if feasible.is_empty():
		return {}
	# Techo respecto al objetivo (y al suelo si existe), no solo al suelo blando.
	var cap := target + MAX_STEP_ABOVE_FLOOR
	if floor_score >= 0.0:
		cap = maxf(floor_score, target) + MAX_STEP_ABOVE_FLOOR
	var best: Dictionary = feasible[0]
	var best_score := float(best.get("difficulty_score", 0.0))
	for level: Dictionary in feasible:
		var score := float(level.get("difficulty_score", 0.0))
		var best_over := best_score > cap + 0.001
		var score_over := score > cap + 0.001
		if score_over and not best_over:
			continue
		if (not score_over and best_over) or score > best_score:
			best = level
			best_score = score
	return best


static func _hardest_candidate(pool: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = pool[0]
	for level: Dictionary in pool:
		if float(level.get("difficulty_score", 0.0)) > float(best.get("difficulty_score", 0.0)):
			best = level
	return best


static func _stamp_params(level: Dictionary, params: Dictionary) -> void:
	level["difficulty_bonus"] = int(params.get("difficulty_bonus", 0))
	level["size_bonus"] = int(params.get("size_bonus", 0))
	level["pair_bonus"] = int(params.get("pair_bonus", 0))
	level["skip_density_steps"] = int(params.get("skip_density_steps", 0))


static func _sandbox_spacing(pair_count: int) -> Dictionary:
	var n := maxi(2, pair_count * 2)
	var slot_budget := maxi(n, int(ceil(float(n) * SANDBOX_CANDIDATE_FACTOR)))
	var cols := maxi(1, int(ceil(sqrt(float(slot_budget)))))
	var rows := maxi(1, int(ceil(float(slot_budget) / float(cols))))
	var gap := SANDBOX_GAP_PREF
	# Borde más justo que el hueco entre rocas → se usa más el tablero.
	var inset := SANDBOX_ROCK_R + gap * 0.55
	var cell_w := (1.0 - 2.0 * inset) / float(cols)
	var cell_h := (1.0 - 2.0 * inset) / float(rows)
	var need := 2.0 * SANDBOX_ROCK_R + gap
	while (cell_w + 0.0001 < need or cell_h + 0.0001 < need) and gap > SANDBOX_GAP_MIN + 0.0001:
		gap = maxf(SANDBOX_GAP_MIN, gap - 0.004)
		inset = SANDBOX_ROCK_R + gap * 0.55
		cell_w = (1.0 - 2.0 * inset) / float(cols)
		cell_h = (1.0 - 2.0 * inset) / float(rows)
		need = 2.0 * SANDBOX_ROCK_R + gap
	# Separación entre rocas: hueco preferido, acotado por el tamaño de celda.
	var min_sep := minf(need, minf(cell_w, cell_h) * 0.98)
	return {
		"min_sep": min_sep,
		"inset": inset,
		"cols": cols,
		"rows": rows,
		"cell_w": cell_w,
		"cell_h": cell_h,
	}


static func _sandbox_board_diagonal(inset: float) -> float:
	var inner := maxf(0.01, 1.0 - 2.0 * inset)
	return sqrt(inner * inner + inner * inner)


static func _sandbox_pair_floor(inset: float, frac: float = -1.0) -> float:
	var f := SANDBOX_PAIR_DIAG_FRAC if frac < 0.0 else frac
	return _sandbox_board_diagonal(inset) * f


static func _sandbox_rock_min_sep() -> float:
	## Separación física entre rocas (no depende del tamaño de celda).
	return 2.0 * SANDBOX_ROCK_R + SANDBOX_GAP_MIN


## Layout por franjas horizontales (rectas L↔R sin cruce) con jitter.
static func _sandbox_place_planar_lanes(rng: RandomNumberGenerator, pair_count: int, spacing: Dictionary) -> Dictionary:
	var inset := float(spacing.inset)
	var sep := _sandbox_rock_min_sep()
	var inner_h := maxf(0.2, 1.0 - 2.0 * inset)
	if sep * float(maxi(1, pair_count - 1)) > inner_h * 0.98:
		sep = inner_h * 0.98 / float(maxi(1, pair_count - 1))
	var span := sep * float(maxi(1, pair_count - 1))
	var y0 := 0.5 - span * 0.5
	var rocks: Array = []
	var solution: Dictionary = {}
	for i in range(pair_count):
		var color := COLOR_NAMES[i % COLOR_NAMES.size()]
		var y := clampf(y0 + float(i) * sep + rng.randf_range(-sep * 0.12, sep * 0.12), inset, 1.0 - inset)
		var x_l := clampf(inset + SANDBOX_ROCK_R * 0.5 + rng.randf_range(0.0, 0.06), inset, 0.42)
		var x_r := clampf(1.0 - inset - SANDBOX_ROCK_R * 0.5 - rng.randf_range(0.0, 0.06), 0.58, 1.0 - inset)
		# Ligera oblicuidad sin cruzar vecinos (dy acotado).
		var y_l := clampf(y + rng.randf_range(-sep * 0.2, sep * 0.2), inset, 1.0 - inset)
		var y_r := clampf(y + rng.randf_range(-sep * 0.2, sep * 0.2), inset, 1.0 - inset)
		rocks.append({"color": color, "x": x_l, "y": y_l})
		rocks.append({"color": color, "x": x_r, "y": y_r})
		solution[color] = [[x_l, y_l], [x_r, y_r]]
	if not _sandbox_solution_is_planar(rocks, solution):
		return _sandbox_place_planar_lanes_strict(pair_count, spacing)
	return {"rocks": rocks, "solution": solution}


static func _sandbox_place_planar_lanes_strict(pair_count: int, spacing: Dictionary) -> Dictionary:
	var rocks := _sandbox_guaranteed_rocks(pair_count, spacing)
	return {"rocks": rocks, "solution": _sandbox_straight_solution(rocks)}


## Coloca rocas y, a la vez, reserva un surco planar por pareja (curvas/oblicuos si hace falta).
## Devuelve { "rocks": Array, "solution": Dictionary } o {} si no hay layout planar.
static func _sandbox_place_planar(rng: RandomNumberGenerator, pair_count: int, spacing: Dictionary) -> Dictionary:
	var cols := int(spacing.cols)
	var rows := int(spacing.rows)
	var inset := float(spacing.inset)
	var cell_w := float(spacing.cell_w)
	var cell_h := float(spacing.cell_h)
	var pack_sep := maxf(_sandbox_rock_min_sep(), minf(float(spacing.min_sep) * 0.75, _sandbox_rock_min_sep() * 1.25))
	var floor_scale := clampf(
		float(spacing.get("pair_floor_scale", 1.0)),
		SANDBOX_PAIR_DIAG_FRAC_MIN / SANDBOX_PAIR_DIAG_FRAC,
		1.0
	)
	# Un poco más permisivo que el suelo de validación para hallar mates con ruta.
	var pair_floor := _sandbox_pair_floor(inset) * floor_scale * 0.92
	var board_center := Vector2(0.5, 0.5)
	var rock_clear := SANDBOX_ROCK_R * 1.02
	# Holgura baja: el A* evita cruces duros por paso; no hace falta corredor ancho.
	var path_clear := 0.01
	var jx := maxf(0.0, cell_w * 0.12)
	var jy := maxf(0.0, cell_h * 0.12)

	var candidates: Array[Vector2] = []
	for row in range(rows):
		for col in range(cols):
			var c := Vector2(
				inset + (float(col) + 0.5) * cell_w,
				inset + (float(row) + 0.5) * cell_h
			)
			c.x = clampf(c.x + rng.randf_range(-jx, jx), inset, 1.0 - inset)
			c.y = clampf(c.y + rng.randf_range(-jy, jy), inset, 1.0 - inset)
			candidates.append(c)
	var extra := maxi(12, pair_count * 4)
	for _e in range(extra):
		candidates.append(Vector2(
			rng.randf_range(inset, 1.0 - inset),
			rng.randf_range(inset, 1.0 - inset)
		))
	if candidates.size() < pair_count * 2:
		return _sandbox_place_planar_lanes(rng, pair_count, spacing)

	var used := PackedByteArray()
	used.resize(candidates.size())
	used.fill(0)
	var placed_rocks: Array[Vector2] = []
	var placed_paths: Array = []
	var rocks: Array = []
	var solution: Dictionary = {}

	for pi in range(pair_count):
		var color := COLOR_NAMES[pi % COLOR_NAMES.size()]
		# 1ª roca: maximiza separación / borde.
		var a_idx := -1
		var a_score := -1.0
		for i in range(candidates.size()):
			if used[i] != 0:
				continue
			var p: Vector2 = candidates[i]
			var ok := true
			var min_d := INF
			for q: Vector2 in placed_rocks:
				var dq := p.distance_to(q)
				if dq < pack_sep:
					ok = false
					break
				min_d = minf(min_d, dq)
			if not ok:
				continue
			var score: float
			if placed_rocks.is_empty():
				score = _sandbox_edge_factor(p, inset) * 2.0 + rng.randf() * 0.4
			else:
				score = min_d + 0.2 * _sandbox_edge_factor(p, inset)
			if score > a_score:
				a_score = score
				a_idx = i
		if a_idx < 0:
			return _sandbox_place_planar_lanes(rng, pair_count, spacing)

		var a: Vector2 = candidates[a_idx]
		var ideal := board_center * 2.0 - a
		ideal.x = clampf(ideal.x, inset, 1.0 - inset)
		ideal.y = clampf(ideal.y, inset, 1.0 - inset)

		# Candidatos B ordenados por lejanía / diametral; se elige el primero con ruta planar.
		var b_opts: Array[Vector2i] = [] # (idx, unused) packed as Vector2i(idx, score_milli)
		for j in range(candidates.size()):
			if used[j] != 0 or j == a_idx:
				continue
			var b: Vector2 = candidates[j]
			var d := a.distance_to(b)
			if d + 0.0001 < pair_floor:
				continue
			var sep_ok := true
			for q: Vector2 in placed_rocks:
				if b.distance_to(q) < pack_sep:
					sep_ok = false
					break
			if not sep_ok:
				continue
			var toward_ideal := 1.0 - clampf(b.distance_to(ideal) / 1.45, 0.0, 1.0)
			var score_m := int((d * 1000.0) + toward_ideal * 80.0)
			b_opts.append(Vector2i(j, score_m))
		# Ordenar B de mejor a peor score.
		for i in range(b_opts.size()):
			var best_i := i
			for j in range(i + 1, b_opts.size()):
				if b_opts[j].y > b_opts[best_i].y:
					best_i = j
			if best_i != i:
				var tmp: Vector2i = b_opts[i]
				b_opts[i] = b_opts[best_i]
				b_opts[best_i] = tmp

		var chosen_b := -1
		var chosen_path := PackedVector2Array()
		# 1) Mate con segmento que no cruce surcos previos ni atraviese rocas.
		for bi in range(b_opts.size()):
			var b_idx: int = b_opts[bi].x
			var b: Vector2 = candidates[b_idx]
			var straight := PackedVector2Array()
			straight.append(a)
			straight.append(b)
			if _sandbox_segment_hits_obstacles(a, b, placed_rocks, placed_paths, rock_clear, path_clear):
				continue
			var crosses := false
			for prev_v: Variant in placed_paths:
				if _sandbox_polys_cross(straight, prev_v as PackedVector2Array):
					crosses = true
					break
			if crosses:
				continue
			chosen_b = b_idx
			chosen_path = straight
			break
		# Sin recta planar → franjas (rápido y siempre sin cruces). A* queda para repair/reveal.
		if chosen_b < 0:
			return _sandbox_place_planar_lanes(rng, pair_count, spacing)

		used[a_idx] = 1
		used[chosen_b] = 1
		var b_pt: Vector2 = candidates[chosen_b]
		placed_rocks.append(a)
		placed_rocks.append(b_pt)
		placed_paths.append(chosen_path)
		rocks.append({"color": color, "x": a.x, "y": a.y})
		rocks.append({"color": color, "x": b_pt.x, "y": b_pt.y})
		solution[color] = _sandbox_poly_to_solution_array(chosen_path)

	if not _sandbox_solution_is_planar(rocks, solution):
		return _sandbox_place_planar_lanes(rng, pair_count, spacing)
	return {"rocks": rocks, "solution": solution}


## Compat: solo rocas (sin solución). Preferir `_sandbox_place_planar`.
static func _sandbox_place_rocks(rng: RandomNumberGenerator, pair_count: int, spacing: Dictionary) -> Array:
	var built := _sandbox_place_planar(rng, pair_count, spacing)
	if built.is_empty():
		return []
	return built.get("rocks", [])


static func _sandbox_guaranteed_rocks(pair_count: int, spacing: Dictionary) -> Array:
	## Layout seguro: cada pareja une borde izquierdo ↔ derecho (máxima separación horizontal),
	## con Y distintos para no cruzarse ni solaparse.
	var inset := float(spacing.inset)
	var sep := _sandbox_rock_min_sep()
	var inner_h := maxf(0.2, 1.0 - 2.0 * inset)
	var need_h := sep * float(maxi(1, pair_count - 1))
	if need_h > inner_h * 0.98:
		# Demasiadas parejas para el hueco: comprimir sep al máximo posible.
		sep = inner_h * 0.98 / float(maxi(1, pair_count - 1))
	var span := sep * float(maxi(1, pair_count - 1))
	var y0 := 0.5 - span * 0.5
	var x_l := inset + SANDBOX_ROCK_R * 0.5
	var x_r := 1.0 - inset - SANDBOX_ROCK_R * 0.5
	var rocks: Array = []
	for i in range(pair_count):
		var y := clampf(y0 + float(i) * sep, inset, 1.0 - inset)
		var color := COLOR_NAMES[i % COLOR_NAMES.size()]
		rocks.append({"color": color, "x": x_l, "y": y})
		rocks.append({"color": color, "x": x_r, "y": y})
	return rocks


## Prioriza distancia máxima y extremos opuestos del tablero.
static func _sandbox_pair_span_score(a: Vector2, b: Vector2, center: Vector2, inset: float) -> float:
	var d := a.distance_to(b)
	var va := a - center
	var vb := b - center
	var opposite := 1.0
	var la2 := va.length_squared()
	var lb2 := vb.length_squared()
	if la2 > 0.0001 and lb2 > 0.0001:
		opposite = 1.0 + 0.65 * maxf(0.0, -va.normalized().dot(vb.normalized()))
	var edge_a := _sandbox_edge_factor(a, inset)
	var edge_b := _sandbox_edge_factor(b, inset)
	var edge_bonus := 1.0 + 0.35 * (edge_a + edge_b)
	return d * opposite * edge_bonus


## 1 cerca del borde del área jugable, 0 cerca del centro.
static func _sandbox_edge_factor(p: Vector2, inset: float) -> float:
	var inner := 1.0 - 2.0 * inset
	if inner <= 0.001:
		return 0.0
	var nx := (p.x - inset) / inner
	var ny := (p.y - inset) / inner
	var to_edge := minf(minf(nx, 1.0 - nx), minf(ny, 1.0 - ny))
	return clampf(1.0 - to_edge * 2.0, 0.0, 1.0)


static func _sandbox_slots_ortho_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


static func _sandbox_segments_cross(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> bool:
	var r := p2 - p1
	var s := q2 - q1
	var denom := r.x * s.y - r.y * s.x
	if absf(denom) < 0.0000001:
		return false
	var qp := q1 - p1
	var t := (qp.x * s.y - qp.y * s.x) / denom
	var u := (qp.x * r.y - qp.y * r.x) / denom
	return t > 0.02 and t < 0.98 and u > 0.02 and u < 0.98


static func _sandbox_pairs_cross(points: Array[Vector2], pairs: Array[Vector2i]) -> bool:
	for a in range(pairs.size()):
		var pa: Vector2i = pairs[a]
		for b in range(a + 1, pairs.size()):
			var pb: Vector2i = pairs[b]
			if _sandbox_segments_cross(points[pa.x], points[pa.y], points[pb.x], points[pb.y]):
				return true
	return false


static func _sandbox_uncross_pairs(points: Array[Vector2], pairs: Array[Vector2i]) -> bool:
	var changed := true
	var guard := 0
	while changed and guard < 80:
		changed = false
		guard += 1
		for a in range(pairs.size()):
			for b in range(a + 1, pairs.size()):
				var p: Vector2i = pairs[a]
				var q: Vector2i = pairs[b]
				if not _sandbox_segments_cross(points[p.x], points[p.y], points[q.x], points[q.y]):
					continue
				if not _sandbox_segments_cross(points[p.x], points[q.x], points[p.y], points[q.y]):
					pairs[a] = Vector2i(p.x, q.x)
					pairs[b] = Vector2i(p.y, q.y)
				else:
					pairs[a] = Vector2i(p.x, q.y)
					pairs[b] = Vector2i(p.y, q.x)
				changed = true
				break
			if changed:
				break
	return not _sandbox_pairs_cross(points, pairs)


## Agrupa rocas por color → Array[Vector2] (2 extremos).
static func _sandbox_rocks_by_color(rocks: Array) -> Dictionary:
	var by_color: Dictionary = {}
	for rock_v: Variant in rocks:
		if typeof(rock_v) != TYPE_DICTIONARY:
			continue
		var rock: Dictionary = rock_v
		var color := str(rock.get("color", ""))
		if color.is_empty():
			continue
		var pos := Vector2(float(rock.get("x", 0.5)), float(rock.get("y", 0.5)))
		if rock.has("norm") and typeof(rock["norm"]) == TYPE_VECTOR2:
			pos = rock["norm"]
		if not by_color.has(color):
			by_color[color] = []
		(by_color[color] as Array).append(pos)
	return by_color


static func _sandbox_poly_min_dist(p: Vector2, path: PackedVector2Array) -> float:
	if path.is_empty():
		return INF
	if path.size() == 1:
		return p.distance_to(path[0])
	var best := INF
	for i in range(1, path.size()):
		best = minf(best, _sandbox_point_seg_dist(p, path[i - 1], path[i]))
	return best


static func _sandbox_polys_cross(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	## Solo cruce geométrico duro. La holgura de surco la impone la rejilla A*.
	if a.size() < 2 or b.size() < 2:
		return false
	for i in range(1, a.size()):
		for j in range(1, b.size()):
			if _sandbox_segments_cross(a[i - 1], a[i], b[j - 1], b[j]):
				return true
	return false


static func _sandbox_segment_hits_obstacles(
	a: Vector2,
	b: Vector2,
	foreign_rocks: Array[Vector2],
	placed: Array,
	rock_clear: float,
	path_clear: float
) -> bool:
	var steps := maxi(4, int(ceil(a.distance_to(b) / 0.03)))
	for s in range(steps + 1):
		var t := float(s) / float(steps)
		var p := a.lerp(b, t)
		for r: Vector2 in foreign_rocks:
			if p.distance_to(r) < rock_clear:
				return true
		for path_v: Variant in placed:
			var path: PackedVector2Array = path_v
			if _sandbox_poly_min_dist(p, path) < path_clear:
				return true
	return false


static func _sandbox_simplify_polyline(path: PackedVector2Array) -> PackedVector2Array:
	if path.size() <= 2:
		return path
	var out := PackedVector2Array()
	out.append(path[0])
	for i in range(1, path.size() - 1):
		var prev: Vector2 = out[out.size() - 1]
		var cur: Vector2 = path[i]
		var nxt: Vector2 = path[i + 1]
		var v1 := (cur - prev).normalized()
		var v2 := (nxt - cur).normalized()
		# Mantener vértices con giro apreciable (curvas / cuneiformes).
		if v1.dot(v2) < 0.992:
			out.append(cur)
	out.append(path[path.size() - 1])
	return out


static func _sandbox_poly_to_solution_array(path: PackedVector2Array) -> Array:
	var arr: Array = []
	for i in range(path.size()):
		arr.append([path[i].x, path[i].y])
	return arr


static func _sandbox_route_cell_of(p: Vector2, inset: float, span: float, n: int) -> Vector2i:
	var lx := clampf((p.x - inset) / span, 0.0, 0.9999)
	var ly := clampf((p.y - inset) / span, 0.0, 0.9999)
	return Vector2i(int(lx * float(n)), int(ly * float(n)))


static func _sandbox_route_cell_center(c: Vector2i, origin: Vector2, cell: float) -> Vector2:
	return origin + Vector2((float(c.x) + 0.5) * cell, (float(c.y) + 0.5) * cell)


## Pathfind 8-dir en rejilla fina; evita rocas ajenas y surcos ya colocados.
static func _sandbox_route_astar(
	start: Vector2,
	goal: Vector2,
	foreign_rocks: Array[Vector2],
	placed: Array,
	inset: float,
	rock_clear: float = -1.0,
	path_clear: float = -1.0
) -> PackedVector2Array:
	var n := SANDBOX_ROUTE_GRID
	var span := maxf(0.2, 1.0 - 2.0 * inset)
	var cell := span / float(n)
	var origin := Vector2(inset, inset)
	if rock_clear < 0.0:
		rock_clear = SANDBOX_ROCK_R + SANDBOX_ROUTE_CLEARANCE * 0.45
	if path_clear < 0.0:
		path_clear = SANDBOX_ROUTE_CLEARANCE * 0.7

	var blocked := PackedByteArray()
	blocked.resize(n * n)
	blocked.fill(0)
	for gy in range(n):
		for gx in range(n):
			var c := origin + Vector2((float(gx) + 0.5) * cell, (float(gy) + 0.5) * cell)
			var bad := false
			for r: Vector2 in foreign_rocks:
				if c.distance_to(r) < rock_clear:
					bad = true
					break
			if not bad:
				for path_v: Variant in placed:
					var path: PackedVector2Array = path_v
					if _sandbox_poly_min_dist(c, path) < path_clear:
						bad = true
						break
			if bad:
				blocked[gy * n + gx] = 1

	var sc := _sandbox_route_cell_of(start, inset, span, n)
	var gc := _sandbox_route_cell_of(goal, inset, span, n)
	# Extremos siempre transitables (están en las rocas propias).
	blocked[sc.y * n + sc.x] = 0
	blocked[gc.y * n + gc.x] = 0

	if sc == gc:
		var direct := PackedVector2Array()
		direct.append(start)
		direct.append(goal)
		return direct

	var open: Array[Vector2i] = [sc]
	var came_from: Dictionary = {} # int key -> int parent key
	var g_score: Dictionary = {}
	var f_score: Dictionary = {}
	var sc_key := sc.y * n + sc.x
	var gc_key := gc.y * n + gc.x
	g_score[sc_key] = 0.0
	f_score[sc_key] = float(absi(sc.x - gc.x) + absi(sc.y - gc.y))
	var closed: Dictionary = {}
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	var guard := 0
	var max_iters := n * n * 4
	while not open.is_empty() and guard < max_iters:
		guard += 1
		var best_i := 0
		var best_f := INF
		for i in range(open.size()):
			var k: int = open[i].y * n + open[i].x
			var f := float(f_score.get(k, INF))
			if f < best_f:
				best_f = f
				best_i = i
		var cur: Vector2i = open[best_i]
		open.remove_at(best_i)
		var cur_key := cur.y * n + cur.x
		if cur_key == gc_key:
			var cells: Array[Vector2i] = [gc]
			var walk_key := gc_key
			while came_from.has(walk_key):
				walk_key = int(came_from[walk_key])
				@warning_ignore("integer_division")
				cells.append(Vector2i(walk_key % n, walk_key / n))
			cells.reverse()
			var poly := PackedVector2Array()
			poly.append(start)
			for ci in range(1, cells.size() - 1):
				poly.append(_sandbox_route_cell_center(cells[ci], origin, cell))
			poly.append(goal)
			# Simplificar solo si los atajos no rozan rocas/surcos (evita cortes).
			var simple := _sandbox_simplify_polyline(poly)
			if not _sandbox_segment_hits_obstacles(
				simple[0], simple[simple.size() - 1], foreign_rocks, placed, rock_clear, path_clear
			) and simple.size() == 2:
				return simple
			# Comprobar cada segmento del simplificado.
			var simple_ok := true
			for si in range(1, simple.size()):
				if _sandbox_segment_hits_obstacles(
					simple[si - 1], simple[si], foreign_rocks, placed, rock_clear, path_clear
				):
					simple_ok = false
					break
			return simple if simple_ok else poly
		if closed.has(cur_key):
			continue
		closed[cur_key] = true
		var cur_g := float(g_score.get(cur_key, INF))
		for d: Vector2i in dirs:
			var nxt := cur + d
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= n or nxt.y >= n:
				continue
			if blocked[nxt.y * n + nxt.x] != 0:
				continue
			# Evitar cortes diagonales por esquinas bloqueadas.
			if d.x != 0 and d.y != 0:
				if blocked[cur.y * n + nxt.x] != 0 or blocked[nxt.y * n + cur.x] != 0:
					continue
			# No cruzar surcos ya aceptados en este paso de rejilla.
			if not placed.is_empty():
				var c0 := _sandbox_route_cell_center(cur, origin, cell)
				var c1 := _sandbox_route_cell_center(nxt, origin, cell)
				var step_hit := false
				for path_v2: Variant in placed:
					var pth: PackedVector2Array = path_v2
					for pi in range(1, pth.size()):
						if _sandbox_segments_cross(c0, c1, pth[pi - 1], pth[pi]):
							step_hit = true
							break
					if step_hit:
						break
				if step_hit:
					continue
			var nxt_key := nxt.y * n + nxt.x
			if closed.has(nxt_key):
				continue
			var step_cost := 1.414 if (d.x != 0 and d.y != 0) else 1.0
			var tentative := cur_g + step_cost
			if tentative + 0.0001 >= float(g_score.get(nxt_key, INF)):
				continue
			came_from[nxt_key] = cur_key
			g_score[nxt_key] = tentative
			f_score[nxt_key] = tentative + float(absi(nxt.x - gc.x) + absi(nxt.y - gc.y))
			var already := false
			for oi in range(open.size()):
				if open[oi] == nxt:
					already = true
					break
			if not already:
				open.append(nxt)
	return PackedVector2Array()


static func _sandbox_pair_length(by_color: Dictionary, color: String) -> float:
	var pts: Array = by_color.get(color, [])
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


static func _sandbox_sorted_colors(by_color: Dictionary, longest_first: bool) -> Array[String]:
	var order: Array[String] = []
	for color_v: Variant in by_color.keys():
		order.append(str(color_v))
	for i in range(order.size()):
		var best_i := i
		var best_d := _sandbox_pair_length(by_color, order[i])
		for j in range(i + 1, order.size()):
			var dj := _sandbox_pair_length(by_color, order[j])
			if longest_first:
				if dj > best_d:
					best_d = dj
					best_i = j
			else:
				if dj < best_d:
					best_d = dj
					best_i = j
		if best_i != i:
			var tmp := order[i]
			order[i] = order[best_i]
			order[best_i] = tmp
	return order


static func _sandbox_try_planar_order(
	by_color: Dictionary,
	order: Array[String],
	all_rocks: Array[Vector2],
	rock_color: Array[String],
	inset: float,
	rock_clear: float,
	path_clear: float
) -> Dictionary:
	var placed: Array = []
	var solution: Dictionary = {}
	for color in order:
		var pts: Array = by_color[color]
		if pts.size() < 2:
			return {}
		var a: Vector2 = pts[0]
		var b: Vector2 = pts[1]
		var foreign: Array[Vector2] = []
		for i in range(all_rocks.size()):
			if rock_color[i] != color:
				foreign.append(all_rocks[i])

		var path := PackedVector2Array()
		var straight_ok := not _sandbox_segment_hits_obstacles(a, b, foreign, placed, rock_clear, path_clear)
		if straight_ok:
			path.append(a)
			path.append(b)
		else:
			path = _sandbox_route_astar(a, b, foreign, placed, inset, rock_clear, path_clear)
		if path.size() < 2:
			return {}
		var needs_reroute := false
		for prev_v: Variant in placed:
			if _sandbox_polys_cross(path, prev_v as PackedVector2Array):
				needs_reroute = true
				break
		if needs_reroute:
			path = _sandbox_route_astar(a, b, foreign, placed, inset, rock_clear, path_clear)
		if path.size() < 2:
			return {}
		for prev_v: Variant in placed:
			if _sandbox_polys_cross(path, prev_v as PackedVector2Array):
				return {}
		solution[color] = _sandbox_poly_to_solution_array(path)
		placed.append(path)
	return solution


## Solución planar (polilíneas sin cruce). Vacío si el layout no admite rutas.
static func _sandbox_find_planar_solution(rocks: Array) -> Dictionary:
	var by_color := _sandbox_rocks_by_color(rocks)
	if by_color.size() < 2:
		return {}
	var spacing := _sandbox_spacing(by_color.size())
	var inset := float(spacing.inset)
	var all_rocks: Array[Vector2] = []
	var rock_color: Array[String] = []
	for color_v: Variant in by_color.keys():
		var color := str(color_v)
		var pts: Array = by_color[color]
		for p_v: Variant in pts:
			all_rocks.append(p_v as Vector2)
			rock_color.append(color)

	var orders: Array = []
	var short_first := _sandbox_sorted_colors(by_color, false)
	var long_first := _sandbox_sorted_colors(by_color, true)
	orders.append(short_first)
	orders.append(long_first)
	# Rotaciones del orden corto→largo (cambia quién “reclama” el centro).
	for rot in range(1, short_first.size()):
		var rotated: Array[String] = []
		for i in range(short_first.size()):
			rotated.append(short_first[(i + rot) % short_first.size()])
		orders.append(rotated)

	# Holguras: primero permisivo (más éxitos), luego más estricto.
	var clear_levels: Array[Vector2] = [
		Vector2(SANDBOX_ROCK_R * 1.02, 0.012),
		Vector2(SANDBOX_ROCK_R * 1.08, SANDBOX_ROUTE_CLEARANCE * 0.35),
		Vector2(SANDBOX_ROCK_R + SANDBOX_ROUTE_CLEARANCE * 0.35, SANDBOX_ROUTE_CLEARANCE * 0.55),
	]
	for clear_v: Variant in clear_levels:
		var clear: Vector2 = clear_v
		var rock_clear := clear.x
		var path_clear := clear.y
		for order_v: Variant in orders:
			var order: Array[String] = []
			for c_v: Variant in order_v:
				order.append(str(c_v))
			if order.is_empty():
				continue
			var sol := _sandbox_try_planar_order(
				by_color, order, all_rocks, rock_color, inset, rock_clear, path_clear
			)
			if sol.size() == by_color.size():
				return sol
	return {}


## Valida que `solution` una cada pareja sin cruces ni atravesar el núcleo de rocas ajenas.
static func _sandbox_solution_is_planar(rocks: Array, solution: Dictionary) -> bool:
	var by_color := _sandbox_rocks_by_color(rocks)
	if by_color.size() < 2 or solution.is_empty():
		return false
	# Alineado con el nivel más permisivo del pathfinder (núcleo de la roca).
	var rock_clear := SANDBOX_ROCK_R * 0.95
	var paths: Array = []
	var colors: Array[String] = []
	for color_v: Variant in by_color.keys():
		var color := str(color_v)
		if not solution.has(color):
			return false
		var pts: Array = by_color[color]
		if pts.size() != 2:
			return false
		var raw: Variant = solution[color]
		if typeof(raw) != TYPE_ARRAY:
			return false
		var poly := PackedVector2Array()
		for pt_v: Variant in raw:
			if typeof(pt_v) == TYPE_VECTOR2:
				poly.append(pt_v)
			elif typeof(pt_v) == TYPE_ARRAY:
				var arr: Array = pt_v
				if arr.size() >= 2:
					poly.append(Vector2(float(arr[0]), float(arr[1])))
		if poly.size() < 2:
			return false
		var a: Vector2 = pts[0]
		var b: Vector2 = pts[1]
		var end0: Vector2 = poly[0]
		var end1: Vector2 = poly[poly.size() - 1]
		var ends_ok := (
			(end0.distance_to(a) < 0.04 and end1.distance_to(b) < 0.04)
			or (end0.distance_to(b) < 0.04 and end1.distance_to(a) < 0.04)
		)
		if not ends_ok:
			return false
		for other_v: Variant in by_color.keys():
			var other := str(other_v)
			if other == color:
				continue
			var opts: Array = by_color[other]
			for op_v: Variant in opts:
				var op: Vector2 = op_v
				if _sandbox_poly_min_dist(op, poly) < rock_clear:
					return false
		for prev_v: Variant in paths:
			if _sandbox_polys_cross(poly, prev_v as PackedVector2Array):
				return false
		paths.append(poly)
		colors.append(color)
	return colors.size() == by_color.size()


static func generate_sandbox(level_id: int, prev_score: float = -1.0) -> Dictionary:
	var params := sandbox_params_for(level_id)
	var pair_count := int(params.pairs)
	var spacing := _sandbox_spacing(pair_count)
	var best := {}
	var best_score := -1.0
	var pool: Array[Dictionary] = []

	for attempt in range(SANDBOX_EVAL_ATTEMPTS):
		var rng := RandomNumberGenerator.new()
		rng.seed = make_seed("sandbox", level_id, attempt)
		var built: Dictionary = _sandbox_place_planar(rng, pair_count, spacing)
		if built.is_empty():
			continue
		var rocks: Array = built.get("rocks", [])
		var solution: Dictionary = built.get("solution", {})
		if rocks.size() != pair_count * 2 or solution.size() != pair_count:
			continue

		# Óptimo = un surco correcto por pareja (coincide con moves del Sandbox).
		var par := pair_count
		var level := {
			"id": level_id,
			"name": level_name("sandbox", level_id),
			"mode": "sandbox",
			"rocks": rocks,
			"solution": solution,
			"colors": pair_count,
			"par": par,
			"size": 0,
			"difficulty_bonus": int(params.difficulty_bonus),
		}
		if not is_solvable(level):
			continue
		var score := _sandbox_layout_score(rocks, level_id)
		level["difficulty_score"] = score
		if score > best_score:
			best_score = score
			best = level
		if prev_score < 0.0 or score + 0.001 >= prev_score + 0.8:
			pool.append(level)
			if pool.size() >= SANDBOX_POOL_TARGET:
				break

	if not pool.is_empty():
		var pick: Dictionary = pool[0]
		for level: Dictionary in pool:
			if float(level.get("difficulty_score", 0.0)) > float(pick.get("difficulty_score", 0.0)):
				pick = level
		return pick
	if not best.is_empty():
		return best

	# Soft: aflojar packing / suelo diametral.
	for soft_i in range(5):
		var soft := spacing.duplicate()
		var factor := 0.92 - float(soft_i) * 0.05
		soft["min_sep"] = float(spacing.min_sep) * factor
		soft["pair_floor_scale"] = maxf(
			SANDBOX_PAIR_DIAG_FRAC_MIN / SANDBOX_PAIR_DIAG_FRAC,
			1.0 - float(soft_i) * 0.04
		)
		for attempt2 in range(120):
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = make_seed("sandbox", level_id, 10_000 + soft_i * 1000 + attempt2)
			var built2: Dictionary = _sandbox_place_planar(rng2, pair_count, soft)
			if built2.is_empty():
				continue
			var rocks2: Array = built2.get("rocks", [])
			var solution2: Dictionary = built2.get("solution", {})
			if rocks2.size() != pair_count * 2 or solution2.size() != pair_count:
				continue
			var level2 := {
				"id": level_id,
				"name": level_name("sandbox", level_id),
				"mode": "sandbox",
				"rocks": rocks2,
				"solution": solution2,
				"colors": pair_count,
				"par": pair_count,
				"size": 0,
				"difficulty_bonus": int(params.difficulty_bonus),
			}
			if not is_solvable(level2):
				continue
			level2["difficulty_score"] = _sandbox_layout_score(rocks2, level_id)
			return level2

	# Nunca devolver vacío: parejas izquierda↔derecha (siempre válidas y diametrales).
	var rocks_g := _sandbox_guaranteed_rocks(pair_count, spacing)
	var solution_g := _sandbox_find_planar_solution(rocks_g)
	if solution_g.is_empty():
		solution_g = _sandbox_straight_solution(rocks_g)
	var level_g := {
		"id": level_id,
		"name": level_name("sandbox", level_id),
		"mode": "sandbox",
		"rocks": rocks_g,
		"solution": solution_g,
		"colors": pair_count,
		"par": pair_count,
		"size": 0,
		"difficulty_bonus": int(params.difficulty_bonus),
	}
	level_g["difficulty_score"] = _sandbox_layout_score(rocks_g, level_id)
	return level_g


## Distancia punto–segmento (coordenadas normalizadas 0..1).
static func _sandbox_point_seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.0000001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Métricas de layout Sandbox: bloqueo del trazo recto y longitud de parejas.
static func _sandbox_difficulty_metrics(rocks: Array) -> Dictionary:
	var by_color: Dictionary = {}
	for rock_v: Variant in rocks:
		if typeof(rock_v) != TYPE_DICTIONARY:
			continue
		var rock: Dictionary = rock_v
		var color := str(rock.get("color", ""))
		if color.is_empty():
			continue
		if not by_color.has(color):
			by_color[color] = []
		(by_color[color] as Array).append(Vector2(float(rock.get("x", 0.5)), float(rock.get("y", 0.5))))

	var block := 0.0
	var len_sum := 0.0
	var len_min := 999.0
	var pair_n := 0
	for color_v: Variant in by_color.keys():
		var pts: Array = by_color[color_v]
		if pts.size() < 2:
			continue
		var a: Vector2 = pts[0]
		var b: Vector2 = pts[1]
		var d := a.distance_to(b)
		len_sum += d
		len_min = minf(len_min, d)
		pair_n += 1
		for other_v: Variant in by_color.keys():
			if str(other_v) == str(color_v):
				continue
			var others: Array = by_color[other_v]
			for op_v: Variant in others:
				var op: Vector2 = op_v
				if _sandbox_point_seg_dist(op, a, b) < SANDBOX_BLOCK_CORRIDOR:
					block += 1.0

	var len_avg := len_sum / float(maxi(1, pair_n))
	if len_min > 100.0:
		len_min = 0.0
	return {
		"block": block,
		"len_avg": len_avg,
		"len_min": len_min,
		"pairs": pair_n,
	}


## Puntuación de dificultad Sandbox (bloqueo de rectas + longitudes + nº de parejas).
static func _sandbox_layout_score(rocks: Array, level_id: int) -> float:
	var m := _sandbox_difficulty_metrics(rocks)
	var pairs := float(maxi(1, int(m.pairs)))
	return (
		pairs * 18.0
		+ float(m.block) * 6.5
		+ float(m.len_avg) * 40.0
		+ float(m.len_min) * 25.0
		+ float(maxi(1, level_id)) * 0.35
	)


static func is_solvable(level: Dictionary) -> bool:
	if level.is_empty():
		return false

	# Formato Sandbox: rocas normalizadas, 2 por color.
	if str(level.get("mode", "")) == "sandbox" or typeof(level.get("rocks", null)) == TYPE_ARRAY:
		return _is_sandbox_solvable(level)

	var size := int(level.get("size", 0))
	if size < 2:
		return false

	var solution: Variant = level.get("solution", null)
	if typeof(solution) != TYPE_DICTIONARY:
		return false
	var solution_dict: Dictionary = solution
	if solution_dict.is_empty():
		return false

	var dots: Variant = level.get("dots", null)
	if typeof(dots) != TYPE_ARRAY:
		return false
	var dots_array: Array = dots

	var endpoints: Dictionary = {} # color -> Array[Vector2i]
	for dot: Variant in dots_array:
		if typeof(dot) != TYPE_DICTIONARY:
			return false
		var color := str(dot.get("color", ""))
		var pos := Vector2i(int(dot.get("x", -1)), int(dot.get("y", -1)))
		if color.is_empty() or pos.x < 0 or pos.y < 0 or pos.x >= size or pos.y >= size:
			return false
		if not endpoints.has(color):
			endpoints[color] = []
		endpoints[color].append(pos)

	var occupied: Dictionary = {} # Vector2i -> color
	var par_calc := 0

	for color_name: Variant in solution_dict.keys():
		var color := str(color_name)
		var path: Array = solution_dict[color_name]
		# Mínimo 3 casillas: con 2 los extremos serían vecinos ortogonales.
		if path.size() < 3:
			return false
		if not endpoints.has(color) or endpoints[color].size() != 2:
			return false

		var cells: Array[Vector2i] = []
		for point: Variant in path:
			if typeof(point) != TYPE_ARRAY:
				return false
			var arr: Array = point
			if arr.size() < 2:
				return false
			var cell := Vector2i(int(arr[0]), int(arr[1]))
			if cell.x < 0 or cell.y < 0 or cell.x >= size or cell.y >= size:
				return false
			if occupied.has(cell):
				return false
			occupied[cell] = color
			cells.append(cell)

		for i in range(1, cells.size()):
			var delta: Vector2i = cells[i] - cells[i - 1]
			if absi(delta.x) + absi(delta.y) != 1:
				return false

		if not _is_snake_polyomino(cells):
			return false

		var start: Vector2i = cells[0]
		var end: Vector2i = cells[cells.size() - 1]
		var a: Vector2i = endpoints[color][0]
		var b: Vector2i = endpoints[color][1]
		var ends_ok := (start == a and end == b) or (start == b and end == a)
		if not ends_ok:
			return false
		# Ningún par del mismo color en casillas ortogonales vecinas
		# (dots y extremos de la solución; cubre caminos en U de longitud 3+).
		if (
			_grid_cells_ortho_adjacent(a, b)
			or _grid_cells_ortho_adjacent(start, end)
		):
			return false

		par_calc += cells.size() - 1

	if endpoints.size() != solution_dict.size():
		return false

	var par := int(level.get("par", -1))
	if par != par_calc:
		return false

	return true


static func _is_sandbox_solvable(level: Dictionary) -> bool:
	var rocks_v: Variant = level.get("rocks", null)
	if typeof(rocks_v) != TYPE_ARRAY:
		return false
	var rocks: Array = rocks_v
	if rocks.size() < 4 or rocks.size() % 2 != 0:
		return false
	var spacing := _sandbox_spacing(int(rocks.size() / 2))
	var inset_full := float(spacing.inset)
	var inset := inset_full * 0.97
	# Validar con separación física de rocas (no el min_sep de packing de celda).
	var min_sep := _sandbox_rock_min_sep() * 0.92
	var by_color: Dictionary = {}
	var positions: Array[Vector2] = []
	for rock_v: Variant in rocks:
		if typeof(rock_v) != TYPE_DICTIONARY:
			return false
		var rock: Dictionary = rock_v
		var color := str(rock.get("color", ""))
		var x := float(rock.get("x", -1.0))
		var y := float(rock.get("y", -1.0))
		if color.is_empty() or x < inset or x > 1.0 - inset or y < inset or y > 1.0 - inset:
			return false
		var pos := Vector2(x, y)
		for prev: Vector2 in positions:
			if pos.distance_to(prev) < min_sep:
				return false
		positions.append(pos)
		if not by_color.has(color):
			by_color[color] = []
		(by_color[color] as Array).append(pos)
	# Parejas lejos (lado opuesto). Además debe existir solución planar (surcos sin cruce).
	var pair_floor := _sandbox_pair_floor(inset_full, SANDBOX_PAIR_DIAG_FRAC_MIN)
	for color_v: Variant in by_color.keys():
		var pts: Array = by_color[color_v]
		if pts.size() != 2:
			return false
		var pa: Vector2 = pts[0]
		var pb: Vector2 = pts[1]
		if pa.distance_to(pb) < pair_floor:
			return false
	if by_color.size() < 2:
		return false
	var sol_v: Variant = level.get("solution", null)
	if typeof(sol_v) == TYPE_DICTIONARY and not (sol_v as Dictionary).is_empty():
		return _sandbox_solution_is_planar(rocks, sol_v as Dictionary)
	return not _sandbox_find_planar_solution(rocks).is_empty()


static func _sandbox_straight_solution(rocks: Array) -> Dictionary:
	var by_color: Dictionary = {}
	for rock_v: Variant in rocks:
		if typeof(rock_v) != TYPE_DICTIONARY:
			continue
		var rock: Dictionary = rock_v
		var color := str(rock.get("color", ""))
		if color.is_empty():
			continue
		if not by_color.has(color):
			by_color[color] = []
		(by_color[color] as Array).append([
			float(rock.get("x", 0.5)),
			float(rock.get("y", 0.5)),
		])
	var solution: Dictionary = {}
	for color_v: Variant in by_color.keys():
		var pts: Array = by_color[color_v]
		if pts.size() < 2:
			continue
		solution[str(color_v)] = [pts[0], pts[1]]
	return solution


static func _is_snake_polyomino(cells: Array[Vector2i]) -> bool:
	if cells.size() < 2:
		return false
	var cell_set: Dictionary = {}
	for c: Vector2i in cells:
		cell_set[c] = true

	var ends := 0
	for c: Vector2i in cells:
		var deg := 0
		for d: Vector2i in DIRS:
			if cell_set.has(c + d):
				deg += 1
		if deg == 1:
			ends += 1
		elif deg != 2:
			return false

	if ends != 2:
		return false

	# Conexo por BFS.
	var start: Vector2i = cells[0]
	var seen: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d: Vector2i in DIRS:
			var nxt: Vector2i = cur + d
			if cell_set.has(nxt) and not seen.has(nxt):
				seen[nxt] = true
				queue.append(nxt)
	return seen.size() == cells.size()


## Nivel completo nuevo para fallback de chaos (semilla salada, sin usar caché).
static func generate_with_salt(
	mode_id: String,
	level_id: int,
	salt: int,
	prev_score: float = -1.0,
	other_mode_score: float = -1.0
) -> Dictionary:
	var params := params_for(mode_id, level_id)
	var name := level_name(mode_id, level_id)
	var size := int(params.size)
	var colors := int(params.colors)
	var min_cover := float(params.min_cover)
	var base := 250_000 + absi(salt) * 1_009
	for attempt in range(120):
		var seed_value := make_seed(mode_id, level_id, base + attempt)
		var level := _try_build(level_id, name, size, colors, min_cover, seed_value)
		if level.is_empty() or not is_solvable(level):
			continue
		_stamp_params(level, params)
		_attach_metrics(level)
		return level
	var relaxed := maxf(0.45, min_cover - 0.2)
	for attempt in range(80):
		var seed_value := make_seed(mode_id, level_id, base + 10_000 + attempt)
		var level := _try_build(level_id, name, size, colors, relaxed, seed_value)
		if level.is_empty() or not is_solvable(level):
			continue
		_stamp_params(level, params)
		_attach_metrics(level)
		return level
	# Último recurso: generador normal (determinista).
	return generate(mode_id, level_id, prev_score, other_mode_score)


## Regenera parejas solo en celdas libres (blocked = rutas ya completadas).
## Devuelve { dots, solution } o {} si no cabe.
static func rebuild_remaining(
	size: int,
	remaining_pairs: int,
	blocked_cells: Array,
	seed_value: int,
	forbidden_colors: Array = []
) -> Dictionary:
	if size < 2 or remaining_pairs < 1:
		return {}
	var blocked: Dictionary = {}
	for cell_v: Variant in blocked_cells:
		if typeof(cell_v) == TYPE_VECTOR2I:
			blocked[cell_v as Vector2i] = true
		elif typeof(cell_v) == TYPE_ARRAY:
			var arr: Array = cell_v
			if arr.size() >= 2:
				blocked[Vector2i(int(arr[0]), int(arr[1]))] = true

	var forbid: Dictionary = {}
	for c_v: Variant in forbidden_colors:
		forbid[str(c_v)] = true

	var available: Array[String] = []
	for c: String in COLOR_NAMES:
		if not forbid.has(c):
			available.append(c)
	if available.size() < remaining_pairs:
		return {}

	for attempt in range(48):
		var seed_i := seed_value + attempt * 9973
		var built := _try_build_in_free(size, remaining_pairs, blocked, available, seed_i)
		if not built.is_empty():
			return built
	return {}


static func _try_build_in_free(
	size: int,
	num_colors: int,
	blocked: Dictionary,
	available_colors: Array[String],
	seed_value: int
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var colors: Array[String] = available_colors.duplicate()
	_shuffle_strings(colors, rng)
	if colors.size() > num_colors:
		var picked: Array[String] = []
		for i in range(num_colors):
			picked.append(colors[i])
		colors = picked

	var free: Dictionary = {}
	for y in range(size):
		for x in range(size):
			var cell := Vector2i(x, y)
			if blocked.has(cell):
				continue
			free[cell] = true

	var free_start := free.size()
	if free_start < num_colors * 3:
		return {}

	var assignment: Dictionary = {}
	var paths: Dictionary = {}

	for i in range(colors.size()):
		var color: String = colors[i]
		var remaining := colors.size() - i
		var free_count := free.size()
		var ideal := maxi(3, int(free_count / float(remaining)))
		var jitter := rng.randi_range(-1, 2)
		var reserve := 2 * maxi(0, remaining - 1)
		var target := maxi(3, mini(free_count - reserve, ideal + jitter))
		var path := _grow_snake(size, free, target, rng)
		if path.is_empty():
			return {}
		for cell: Vector2i in path:
			assignment[cell] = color
			free.erase(cell)
		paths[color] = path

	_absorb_free_cells(size, free, paths, assignment)

	# Cover relajado solo sobre el área libre inicial (no el tablero entero).
	var covered := free_start - free.size()
	var cover := float(covered) / float(maxi(1, free_start))
	if cover < 0.40:
		return {}

	var level := _level_from_assignment(0, "chaos", size, assignment)
	if level.is_empty() or not is_solvable(level):
		return {}
	return {
		"dots": level.get("dots", []),
		"solution": level.get("solution", {}),
	}


static func _try_build(
	level_id: int,
	name: String,
	size: int,
	num_colors: int,
	min_cover: float,
	seed_value: int
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var colors: Array[String] = []
	for i in range(num_colors):
		colors.append(COLOR_NAMES[i])
	_shuffle_strings(colors, rng)

	var free: Dictionary = {} # Vector2i -> true
	for y in range(size):
		for x in range(size):
			free[Vector2i(x, y)] = true

	var assignment: Dictionary = {} # Vector2i -> color string
	var paths: Dictionary = {} # color -> Array[Vector2i] ordenado
	var total := size * size

	for i in range(colors.size()):
		var color: String = colors[i]
		var remaining := colors.size() - i
		var free_count := free.size()
		var ideal := maxi(3, int(free_count / float(remaining)))
		var jitter := rng.randi_range(-1, 2)
		var reserve := 2 * maxi(0, remaining - 1)
		var target := maxi(3, mini(free_count - reserve, ideal + jitter))
		var path := _grow_snake(size, free, target, rng)
		if path.is_empty():
			return {}
		for cell: Vector2i in path:
			assignment[cell] = color
			free.erase(cell)
		paths[color] = path

	_absorb_free_cells(size, free, paths, assignment)

	var cover := float(total - free.size()) / float(total)
	if cover < min_cover:
		return {}

	return _level_from_assignment(level_id, name, size, assignment)


## Alarga los extremos de cada serpiente hacia celdas libres vecinas mientras
## el camino siga siendo una serpiente simple (sin tocarse a sí mismo).
static func _absorb_free_cells(size: int, free: Dictionary, paths: Dictionary, assignment: Dictionary) -> void:
	var changed := true
	while changed and not free.is_empty():
		changed = false
		for color_name: Variant in paths.keys():
			var color := str(color_name)
			var path: Array[Vector2i] = paths[color]
			for at_head: bool in [false, true]:
				var tip: Vector2i = path[0] if at_head else path[path.size() - 1]
				for d: Vector2i in DIRS:
					var nxt: Vector2i = tip + d
					if not _in_bounds(nxt, size) or not free.has(nxt):
						continue
					if not _extension_keeps_snake(nxt, tip, color, assignment):
						continue
					if at_head:
						path.insert(0, nxt)
					else:
						path.append(nxt)
					assignment[nxt] = color
					free.erase(nxt)
					changed = true
					break


static func _extension_keeps_snake(nxt: Vector2i, tip: Vector2i, color: String, assignment: Dictionary) -> bool:
	for d: Vector2i in DIRS:
		var nb: Vector2i = nxt + d
		if nb == tip:
			continue
		if assignment.has(nb) and str(assignment[nb]) == color:
			return false
	return true


static func _level_from_assignment(
	level_id: int,
	name: String,
	size: int,
	assignment: Dictionary
) -> Dictionary:
	var grouped: Dictionary = {} # color -> Array of Vector2i
	for cell: Variant in assignment.keys():
		var pos: Vector2i = cell
		var color := str(assignment[cell])
		if not grouped.has(color):
			grouped[color] = []
		grouped[color].append(pos)

	var paths: Dictionary = {}
	var dots: Array = []
	var par := 0

	for color_name: Variant in grouped.keys():
		var color := str(color_name)
		var raw: Array = grouped[color]
		var cells: Array[Vector2i] = []
		for item: Variant in raw:
			cells.append(item as Vector2i)
		var path := _trace_path(cells)
		if path.is_empty():
			return {}
		var path_arrays: Array = []
		for p: Vector2i in path:
			path_arrays.append([p.x, p.y])
		# Camino mínimo de 3 casillas ⇒ los extremos nunca son vecinos.
		if path.size() < 3:
			return {}
		if _grid_cells_ortho_adjacent(path[0], path[path.size() - 1]):
			return {}
		paths[color] = path_arrays
		dots.append({"color": color, "x": path[0].x, "y": path[0].y})
		dots.append({"color": color, "x": path[path.size() - 1].x, "y": path[path.size() - 1].y})
		par += path.size() - 1

	return {
		"id": level_id,
		"name": name,
		"size": size,
		"dots": dots,
		"solution": paths,
		"par": par,
	}


static func _grid_cells_ortho_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


static func _trace_path(cells: Array[Vector2i]) -> Array[Vector2i]:
	if cells.size() < 2:
		return []
	var cell_set: Dictionary = {}
	for c: Vector2i in cells:
		if cell_set.has(c):
			return []
		cell_set[c] = true

	var ends: Array[Vector2i] = []
	for c: Vector2i in cells:
		var deg := 0
		for d: Vector2i in DIRS:
			if cell_set.has(c + d):
				deg += 1
		if deg == 1:
			ends.append(c)
		elif deg != 2:
			return []

	if ends.size() != 2:
		return []

	var path: Array[Vector2i] = [ends[0]]
	var prev := Vector2i(-999, -999)
	while path[path.size() - 1] != ends[1]:
		var cur: Vector2i = path[path.size() - 1]
		var opts: Array[Vector2i] = []
		for d: Vector2i in DIRS:
			var nxt: Vector2i = cur + d
			if cell_set.has(nxt) and nxt != prev:
				opts.append(nxt)
		if opts.size() != 1:
			return []
		prev = cur
		path.append(opts[0])
		if path.size() > cells.size() + 2:
			return []

	if path.size() != cells.size():
		return []
	return path


static func _grow_snake(
	size: int,
	free: Dictionary,
	target_len: int,
	rng: RandomNumberGenerator
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for key: Variant in free.keys():
		candidates.append(key as Vector2i)
	_shuffle_vector2i(candidates, rng)

	var best: Array[Vector2i] = []
	var max_starts := mini(12, candidates.size())
	for si in range(max_starts):
		var path: Array[Vector2i] = [candidates[si]]
		while path.size() < target_len:
			var tip: Vector2i = path[path.size() - 1]
			var opts: Array[Vector2i] = []
			for d: Vector2i in DIRS:
				var nxt: Vector2i = tip + d
				if not _in_bounds(nxt, size):
					continue
				if not free.has(nxt):
					continue
				if path.has(nxt):
					continue
				if not _snake_extend_ok(path, nxt):
					continue
				opts.append(nxt)
			if opts.is_empty():
				break
			var chosen := _pick_lowest_exit(opts, size, free, path, rng)
			path.append(chosen)
		if path.size() > best.size():
			best = path
		if best.size() >= target_len:
			break

	# Al menos 3 celdas: los extremos (bolas) no pueden quedar pegados.
	if best.size() < 3:
		return []
	return best


static func _exit_count(
	cell: Vector2i,
	size: int,
	free: Dictionary,
	path: Array[Vector2i]
) -> int:
	var count := 0
	for d: Vector2i in DIRS:
		var nxt: Vector2i = cell + d
		if _in_bounds(nxt, size) and free.has(nxt) and not path.has(nxt):
			count += 1
	return count


static func _pick_lowest_exit(
	opts: Array[Vector2i],
	size: int,
	free: Dictionary,
	path: Array[Vector2i],
	rng: RandomNumberGenerator
) -> Vector2i:
	var best: Vector2i = opts[0]
	var best_exits := _exit_count(best, size, free, path)
	for i in range(1, opts.size()):
		var cand: Vector2i = opts[i]
		var exits := _exit_count(cand, size, free, path)
		if exits < best_exits or (exits == best_exits and rng.randf() < 0.5):
			best = cand
			best_exits = exits
	return best


static func _snake_extend_ok(path: Array[Vector2i], nxt: Vector2i) -> bool:
	var tip: Vector2i = path[path.size() - 1]
	for d: Vector2i in DIRS:
		var nb: Vector2i = nxt + d
		if nb == tip:
			continue
		if path.has(nb):
			return false
	return true


static func _in_bounds(cell: Vector2i, size: int) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size and cell.y < size


static func _shuffle_strings(arr: Array[String], rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


static func _shuffle_vector2i(arr: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
