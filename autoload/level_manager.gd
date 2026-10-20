extends Node

const MODE_EASY := "easy"
const MODE_HARD := "hard"
const MODE_HARDCORE := "hardcore"
const MODE_CHRONO := "chrono"
const MODE_SANDBOX := "sandbox"
## Subir al cambiar curva de parejas/layout Sandbox (no invalida fácil/difícil).
const SANDBOX_CACHE_REV := 13
## Subir al cambiar la curva base de Hardcore (no invalida fácil/difícil).
const HARDCORE_CACHE_REV := 2
## Subir al endurecer curva/picking de Difícil (invalida caché hard).
const HARD_CACHE_REV := 1
## Subir al cambiar curva/picking de Modo Crazy (invalida caché chrono).
const CHRONO_CACHE_REV := 2
## Si el score cacheado de hard/hardcore queda muy por debajo del baseline, no contagiar al siguiente.
const HARD_PREV_SCORE_MARGIN := 4.0
const CACHE_PATH := "user://generated_levels.json"
## Fin de campaña fija en selector; a partir de INFINITE_START la progresión no tiene tope.
const CAMPAIGN_END := LevelGenerator.CAMPAIGN_END
const INFINITE_START := LevelGenerator.INFINITE_START
const LEVEL_SELECT_MARGIN := 12
const INFINITE_WINDOW := 20

var current_mode: String = MODE_EASY
var current_level_id: int = 1

## Cache en memoria: mode -> { cache_key -> level_dict }
var _cache: Dictionary = {}
var _cache_loaded: bool = false


func _ready() -> void:
	_load_cache()


func get_mode_ids() -> Array[String]:
	return [MODE_EASY, MODE_HARD, MODE_HARDCORE, MODE_SANDBOX, MODE_CHRONO]


func get_mode_title(mode_id: String) -> String:
	match mode_id:
		MODE_EASY:
			return "Modo Fácil"
		MODE_HARD:
			return "Modo Difícil"
		MODE_HARDCORE:
			return "Modo Hardcore"
		MODE_CHRONO:
			return "Modo Crazy"
		MODE_SANDBOX:
			return "Sandbox"
		_:
			return mode_id


func set_mode(mode_id: String) -> void:
	if (
		mode_id != MODE_EASY
		and mode_id != MODE_HARD
		and mode_id != MODE_HARDCORE
		and mode_id != MODE_CHRONO
		and mode_id != MODE_SANDBOX
	):
		push_warning("LevelManager: modo desconocido %s" % mode_id)
		return
	current_mode = mode_id


## Tope nominal de campaña (para UI tipo N/200). La progresión real puede superar esto.
func get_level_count(_mode_id: String = "") -> int:
	return CAMPAIGN_END


func is_infinite_level(level_id: int) -> bool:
	return level_id >= INFINITE_START


func format_progress(unlocked: int) -> String:
	if unlocked >= INFINITE_START:
		return "Nivel %d" % unlocked
	return "%d/%d" % [mini(unlocked, CAMPAIGN_END), CAMPAIGN_END]


func get_levels() -> Array:
	return get_levels_for_select(current_mode)


func get_levels_for_select(mode_id: String = "") -> Array:
	var key := current_mode if mode_id.is_empty() else mode_id
	var unlocked := SaveManager.get_last_unlocked_level(key)
	var ids: Array[int] = []

	if unlocked < INFINITE_START:
		var max_id := mini(CAMPAIGN_END, unlocked + LEVEL_SELECT_MARGIN)
		max_id = maxi(max_id, mini(unlocked, CAMPAIGN_END))
		for i in range(1, max_id + 1):
			ids.append(i)
	else:
		for i in range(1, CAMPAIGN_END + 1):
			ids.append(i)
		var start_inf := maxi(INFINITE_START, unlocked - INFINITE_WINDOW)
		var end_inf := unlocked + 1
		for i in range(start_inf, end_inf + 1):
			if not ids.has(i):
				ids.append(i)

	var result: Array = []
	for id in ids:
		result.append({
			"id": id,
			"name": LevelGenerator.level_name(key, id),
			"theme": BoardTheme.title_for_level(id),
		})
	return result


func get_level_by_index(index: int, mode_id: String = "") -> Dictionary:
	var levels := get_levels_for_select(mode_id)
	if index < 0 or index >= levels.size():
		return {}
	return levels[index]


func _cache_key(level_id: int, mode_id: String = "") -> String:
	var key := current_mode if mode_id.is_empty() else mode_id
	var diff_bonus := 0
	var custom_grid := 0
	var custom_pairs := 0
	if SettingsManager != null:
		custom_grid = SettingsManager.get_custom_grid_size()
		custom_pairs = SettingsManager.get_custom_pair_count()
		if custom_grid <= 0 and custom_pairs <= 0:
			diff_bonus = SettingsManager.get_difficulty_bonus(key)
	var density := 0
	if SaveManager != null and custom_grid <= 0 and custom_pairs <= 0:
		density = SaveManager.get_skip_density_steps(key)
	if key == MODE_SANDBOX:
		return "%d_d%d_z%d_p%d_s%d_r%d" % [level_id, diff_bonus, custom_grid, custom_pairs, density, SANDBOX_CACHE_REV]
	if key == MODE_HARDCORE:
		return "%d_d%d_z%d_p%d_s%d_h%d" % [level_id, diff_bonus, custom_grid, custom_pairs, density, HARDCORE_CACHE_REV]
	if key == MODE_HARD:
		return "%d_d%d_z%d_p%d_s%d_k%d" % [level_id, diff_bonus, custom_grid, custom_pairs, density, HARD_CACHE_REV]
	if key == MODE_CHRONO:
		return "%d_d%d_z%d_p%d_s%d_c%d" % [level_id, diff_bonus, custom_grid, custom_pairs, density, CHRONO_CACHE_REV]
	return "%d_d%d_z%d_p%d_s%d" % [level_id, diff_bonus, custom_grid, custom_pairs, density]


func get_level(level_id: int, mode_id: String = "") -> Dictionary:
	var ctx := _prepare_generate(level_id, mode_id)
	if ctx.is_empty():
		return {}
	if ctx.has("cached"):
		return ctx["cached"]
	var level := LevelGenerator.generate(
		str(ctx.mode_id),
		int(ctx.level_id),
		float(ctx.prev_score),
		float(ctx.other_score)
	)
	return _store_generated(str(ctx.mode_id), str(ctx.id_key), level)


## Igual que get_level, pero genera en segundo plano para no congelar el spinner.
func get_level_async(level_id: int, mode_id: String = "") -> Dictionary:
	var ctx := _prepare_generate(level_id, mode_id)
	if ctx.is_empty():
		return {}
	if ctx.has("cached"):
		return ctx["cached"]
	var box: Array = [{}]
	var task := WorkerThreadPool.add_task(
		_generate_on_thread.bind(
			str(ctx.mode_id),
			int(ctx.level_id),
			float(ctx.prev_score),
			float(ctx.other_score),
			box
		),
		true,
		"generate_level"
	)
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	var err := WorkerThreadPool.wait_for_task_completion(task)
	var level: Dictionary = {}
	if err == OK and typeof(box[0]) == TYPE_DICTIONARY:
		level = box[0]
	else:
		push_warning("LevelManager: hilo de generación no disponible, se genera en primer plano")
		level = LevelGenerator.generate(
			str(ctx.mode_id),
			int(ctx.level_id),
			float(ctx.prev_score),
			float(ctx.other_score)
		)
	return _store_generated(str(ctx.mode_id), str(ctx.id_key), level)


func _prepare_generate(level_id: int, mode_id: String) -> Dictionary:
	var key := current_mode if mode_id.is_empty() else mode_id
	if level_id < 1:
		return {}
	if (
		key != MODE_EASY
		and key != MODE_HARD
		and key != MODE_HARDCORE
		and key != MODE_CHRONO
		and key != MODE_SANDBOX
	):
		return {}

	_ensure_cache_mode(key)
	var id_key := _cache_key(level_id, key)
	var mode_cache: Dictionary = _cache[key]
	if mode_cache.has(id_key):
		var cached: Dictionary = mode_cache[id_key]
		if LevelGenerator.is_solvable(cached):
			return {"cached": cached.duplicate(true)}
		mode_cache.erase(id_key)

	var prev_score := -1.0
	if level_id > 1:
		prev_score = _cached_score_or_baseline(key, level_id - 1)

	var other_score := -1.0
	if key == MODE_SANDBOX:
		other_score = -1.0
	elif key == MODE_HARDCORE:
		other_score = _cached_score_or_baseline(MODE_HARD, level_id)
	elif key == MODE_HARD:
		other_score = _cached_score_or_baseline(MODE_EASY, level_id)
	elif key == MODE_CHRONO:
		# Debe superar Difícil en el nivel equivalente (Crazy 1 → Difícil 90).
		other_score = _cached_score_or_baseline(
			MODE_HARD, level_id + LevelGenerator.CHRONO_HARD_LEVEL_OFFSET
		)
	else:
		other_score = _cached_score_or_baseline(MODE_HARD, level_id)

	return {
		"mode_id": key,
		"level_id": level_id,
		"id_key": id_key,
		"prev_score": prev_score,
		"other_score": other_score,
	}


func _generate_on_thread(
	mode_id: String,
	level_id: int,
	prev_score: float,
	other_score: float,
	out: Array
) -> void:
	out[0] = LevelGenerator.generate(mode_id, level_id, prev_score, other_score)


func _store_generated(mode_id: String, id_key: String, level: Dictionary) -> Dictionary:
	if level.is_empty() or not LevelGenerator.is_solvable(level):
		push_error("LevelManager: nivel inválido %s" % mode_id)
		return {}
	_ensure_cache_mode(mode_id)
	var mode_cache: Dictionary = _cache[mode_id]
	mode_cache[id_key] = level
	_cache[mode_id] = mode_cache
	_save_cache()
	return level.duplicate(true)


func set_current_level(level_id: int) -> void:
	current_level_id = maxi(1, level_id)


func get_next_level_id(level_id: int) -> int:
	return level_id + 1


func calculate_stars(level: Dictionary, moves: int) -> int:
	var par := int(level.get("par", 20))
	if moves <= par:
		return 3
	if moves <= int(ceil(float(par) * 1.5)):
		return 2
	return 1


## Tiempo máximo (segundos) para que un 3★ cuente en la racha de pistas.
## Basado en un jugador inteligente y rápido: planear + trazar cerca del óptimo.
## Ej.: 5×5 / 3 parejas / par 15 ≈ 33s; 7×7 / 6 parejas / par 35 ≈ 58s; tope 110s.
func streak_qualify_seconds(level: Dictionary) -> float:
	var size := int(level.get("size", 5))
	var par := int(level.get("par", 20))
	var pairs := _pair_count_from_level(level)
	var seconds := 8.0 + float(pairs) * 2.5 + float(par) * 0.75 + float(maxi(0, size - 5)) * 1.5
	return clampf(seconds, 20.0, 110.0)


func _pair_count_from_level(level: Dictionary) -> int:
	if level.has("rocks") and typeof(level["rocks"]) == TYPE_ARRAY:
		return maxi(2, int(ceil(float((level["rocks"] as Array).size()) * 0.5)))
	if level.has("solution") and typeof(level["solution"]) == TYPE_DICTIONARY:
		return maxi(2, (level["solution"] as Dictionary).size())
	if level.has("dots") and typeof(level["dots"]) == TYPE_ARRAY:
		return maxi(2, int(ceil(float((level["dots"] as Array).size()) * 0.5)))
	return maxi(2, int(level.get("colors", 3)))


func _cached_score_or_baseline(mode_id: String, level_id: int) -> float:
	_ensure_cache_mode(mode_id)
	var id_key := _cache_key(level_id, mode_id)
	var mode_cache: Dictionary = _cache[mode_id]
	var baseline := LevelGenerator.baseline_score(mode_id, level_id)
	if mode_cache.has(id_key) and LevelGenerator.is_solvable(mode_cache[id_key]):
		var cached: Dictionary = mode_cache[id_key]
		var score := float(cached.get("difficulty_score", LevelGenerator.difficulty_score(cached)))
		# Difícil/Hardcore: no contagiar una secuencia blanda (fallback) a los niveles siguientes.
		if (
			(mode_id == MODE_HARD or mode_id == MODE_HARDCORE or mode_id == MODE_CHRONO)
			and score < baseline - HARD_PREV_SCORE_MARGIN
		):
			return baseline
		return score
	return baseline


func _ensure_cache_mode(mode_id: String) -> void:
	if not _cache.has(mode_id) or typeof(_cache[mode_id]) != TYPE_DICTIONARY:
		_cache[mode_id] = {}


## Vacía la caché de niveles generados de un modo (tras reset de progreso).
func clear_mode_cache(mode_id: String) -> void:
	if mode_id.is_empty():
		return
	_ensure_cache_mode(mode_id)
	_cache[mode_id] = {}
	_save_cache()


func _load_cache() -> void:
	_cache = {
		MODE_EASY: {},
		MODE_HARD: {},
		MODE_HARDCORE: {},
		MODE_CHRONO: {},
		MODE_SANDBOX: {},
	}
	_cache_loaded = true

	if not FileAccess.file_exists(CACHE_PATH):
		return

	var file := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if file == null:
		return

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		return

	var data: Dictionary = json.data
	var version := int(data.get("generator_version", 0))
	var same_version := version == LevelGenerator.GENERATOR_VERSION
	# Otra versión del generador: Fácil/Difícil se regeneran con la curva nueva;
	# Sandbox no depende de ella y conserva sus niveles.
	var modes_to_load: Array = (
		[MODE_EASY, MODE_HARD, MODE_HARDCORE, MODE_CHRONO, MODE_SANDBOX]
		if same_version
		else [MODE_SANDBOX]
	)

	for mode_id in modes_to_load:
		if typeof(data.get(mode_id, null)) != TYPE_DICTIONARY:
			continue
		var src: Dictionary = data[mode_id]
		var dst: Dictionary = {}
		for id_key: Variant in src.keys():
			var level: Variant = src[id_key]
			if typeof(level) != TYPE_DICTIONARY:
				continue
			var level_dict: Dictionary = level
			if LevelGenerator.is_solvable(level_dict):
				dst[str(id_key)] = level_dict
		_cache[mode_id] = dst

	if not same_version:
		_save_cache()


func _save_cache() -> void:
	var payload := {
		"generator_version": LevelGenerator.GENERATOR_VERSION,
		MODE_EASY: _cache.get(MODE_EASY, {}),
		MODE_HARD: _cache.get(MODE_HARD, {}),
		MODE_HARDCORE: _cache.get(MODE_HARDCORE, {}),
		MODE_CHRONO: _cache.get(MODE_CHRONO, {}),
		MODE_SANDBOX: _cache.get(MODE_SANDBOX, {}),
	}
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("LevelManager: no se pudo guardar cache de niveles")
		return
	file.store_string(JSON.stringify(payload))
	file.close()
