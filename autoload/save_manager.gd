extends Node

const SAVE_PATH := "user://save_data.json"
const SAVE_VERSION := 3
const BACKUP_APP_ID := "conecta_colores"
const STARTING_HINTS := 2
const HINT_REDEEM_MIN := 8 ## Hace falta más de 7 pistas (8+).
const PERFECT_STREAK_REWARD := 3
const MODE_IDS: Array[String] = ["easy", "hard", "hardcore", "sandbox", "chrono"]

## mode_id -> { last_unlocked_level, completed_levels, perfect_streak, skip_density_steps,
## hints_remaining, total_score, streak_reward_next }
var modes_progress: Dictionary = {}
var last_mode: String = "easy"
var sound_enabled: bool = true
var vibration_enabled: bool = true
var fx_enabled: bool = true
var colorblind_enabled: bool = false
var visual_help_enabled: bool = false
## Casillas teñidas (≠ color de bola); off = tema de tablero habitual.
var colored_board_enabled: bool = false
## Rotura del tablero al completar (off por defecto).
var board_destroy_enabled: bool = false
## Boom cartoon de bolas al completar (off → burbujas).
var ball_boom_enabled: bool = false
## Intro cinemática al entrar en la era Emoji (nivel 101+).
var emoji_era_intro_done: bool = false
var difficulty_bonus_easy: int = 0
var difficulty_bonus_hard: int = 0
var difficulty_bonus_sandbox: int = 0
var difficulty_bonus_hardcore: int = 0
var custom_grid_size: int = 0
var custom_pair_count: int = 0
## La curva Hardcore ya incluye el antiguo extra +2; no volver a plegar el bonus.
var hardcore_base_plus2: bool = false


func _ready() -> void:
	load_data()


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_apply_defaults()
		save_data()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: no se pudo abrir el guardado. Usando valores por defecto.")
		_apply_defaults()
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("SaveManager: guardado dañado. Usando valores por defecto.")
		_apply_defaults()
		return

	var data: Dictionary = json.data
	if _apply_parsed_save_data(data):
		save_data()


func build_save_dictionary() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"modes": modes_progress,
		"last_mode": last_mode,
		"sound_enabled": sound_enabled,
		"vibration_enabled": vibration_enabled,
		"fx_enabled": fx_enabled,
		"colorblind_enabled": colorblind_enabled,
		"visual_help_enabled": visual_help_enabled,
		"colored_board_enabled": colored_board_enabled,
		"board_destroy_enabled": board_destroy_enabled,
		"ball_boom_enabled": ball_boom_enabled,
		"emoji_era_intro_done": emoji_era_intro_done,
		"difficulty_bonus_easy": difficulty_bonus_easy,
		"difficulty_bonus_hard": difficulty_bonus_hard,
		"difficulty_bonus_sandbox": difficulty_bonus_sandbox,
		"difficulty_bonus_hardcore": difficulty_bonus_hardcore,
		"hardcore_base_plus2": hardcore_base_plus2,
		"custom_grid_size": custom_grid_size,
		"custom_pair_count": custom_pair_count,
	}


func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: no se pudo escribir el guardado.")
		return

	file.store_string(JSON.stringify(build_save_dictionary(), "\t"))
	file.close()


## Escribe una copia portable. Devuelve "" si OK, o mensaje de error.
func export_backup_to_path(path: String) -> String:
	if path.is_empty():
		return "Ruta no válida."
	var data := build_save_dictionary()
	data["backup_app"] = BACKUP_APP_ID
	data["backup_exported_at"] = int(Time.get_unix_time_from_system())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "No se pudo escribir el archivo."
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return ""


## Restaura progreso desde un JSON de copia. Devuelve "" si OK, o mensaje de error.
func import_backup_from_path(path: String) -> String:
	if path.is_empty() or not FileAccess.file_exists(path):
		return "No se encontró el archivo."
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "No se pudo leer el archivo."
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		return "El archivo no es un JSON válido."
	var data: Dictionary = json.data
	var app_id := str(data.get("backup_app", ""))
	var version := int(data.get("version", 0))
	var has_modes := typeof(data.get("modes", null)) == TYPE_DICTIONARY
	var looks_legacy := data.has("last_unlocked_level") or data.has("completed_levels")
	if app_id != BACKUP_APP_ID and not (version >= 1 and (has_modes or looks_legacy)):
		return "El archivo no es una copia de Conecta Colores."
	_apply_parsed_save_data(data)
	save_data()
	return ""


## Aplica un diccionario de guardado. Devuelve true si conviene persistir (migración).
func _apply_parsed_save_data(data: Dictionary) -> bool:
	sound_enabled = bool(data.get("sound_enabled", true))
	vibration_enabled = bool(data.get("vibration_enabled", true))
	fx_enabled = bool(data.get("fx_enabled", true))
	colorblind_enabled = bool(data.get("colorblind_enabled", false))
	visual_help_enabled = bool(data.get("visual_help_enabled", false))
	colored_board_enabled = bool(data.get("colored_board_enabled", false))
	board_destroy_enabled = bool(data.get("board_destroy_enabled", false))
	ball_boom_enabled = bool(data.get("ball_boom_enabled", false))
	emoji_era_intro_done = bool(data.get("emoji_era_intro_done", false))
	# v2 y anteriores: pistas/score globales → se copian a cada modo sin ellos.
	var legacy_hints := maxi(0, int(data.get("hints_remaining", STARTING_HINTS)))
	var legacy_score := maxi(0, int(data.get("total_score", 0)))
	# Migración: antiguos bonuses globales → dificultad por modo.
	var legacy := maxi(
		clampi(int(data.get("board_size_bonus", 0)), 0, 2),
		clampi(int(data.get("pair_count_bonus", 0)), 0, 2)
	)
	difficulty_bonus_easy = clampi(int(data.get("difficulty_bonus_easy", legacy)), 0, 2)
	difficulty_bonus_hard = clampi(int(data.get("difficulty_bonus_hard", legacy)), 0, 2)
	difficulty_bonus_sandbox = clampi(int(data.get("difficulty_bonus_sandbox", 0)), 0, 2)
	difficulty_bonus_hardcore = clampi(int(data.get("difficulty_bonus_hardcore", 0)), 0, 2)
	hardcore_base_plus2 = bool(data.get("hardcore_base_plus2", false))
	custom_grid_size = _clamp_saved_grid(int(data.get("custom_grid_size", 0)))
	custom_pair_count = _clamp_saved_pairs(int(data.get("custom_pair_count", 0)))
	if custom_grid_size > 0 or custom_pair_count > 0:
		difficulty_bonus_easy = 0
		difficulty_bonus_hard = 0
		difficulty_bonus_sandbox = 0
		difficulty_bonus_hardcore = 0
	last_mode = str(data.get("last_mode", "easy"))

	var version := int(data.get("version", 1))
	if version >= 2 and typeof(data.get("modes", null)) == TYPE_DICTIONARY:
		modes_progress = data["modes"]
	else:
		# Migración v1 → v2: el progreso antiguo pasa a modo fácil.
		modes_progress = {
			"easy": {
				"last_unlocked_level": int(data.get("last_unlocked_level", 1)),
				"completed_levels": data.get("completed_levels", {}),
				"perfect_streak": 0,
				"skip_density_steps": 0,
				"streak_reward_next": true,
				"hints_remaining": legacy_hints,
				"total_score": legacy_score,
			},
			"hard": _default_mode_entry(),
			"hardcore": _default_mode_entry(),
			"chrono": _default_mode_entry(),
			"sandbox": _default_mode_entry(),
		}
		last_mode = "easy"

	for mode_id in MODE_IDS:
		_ensure_mode(mode_id)

	# v2→v3: pistas/score globales pasan a cada modo (no se pierden al actualizar).
	var need_save := version < SAVE_VERSION
	if version < 3:
		for mode_id in MODE_IDS:
			var entry: Dictionary = modes_progress[mode_id]
			entry["hints_remaining"] = legacy_hints
			entry["total_score"] = legacy_score
			modes_progress[mode_id] = entry
		need_save = true
	if not hardcore_base_plus2:
		difficulty_bonus_hardcore = 0
		hardcore_base_plus2 = true
		need_save = true
	return need_save


func _apply_defaults() -> void:
	modes_progress = {
		"easy": _default_mode_entry(),
		"hard": _default_mode_entry(),
		"hardcore": _default_mode_entry(),
		"chrono": _default_mode_entry(),
		"sandbox": _default_mode_entry(),
	}
	last_mode = "easy"
	sound_enabled = true
	vibration_enabled = true
	fx_enabled = true
	colorblind_enabled = false
	visual_help_enabled = false
	colored_board_enabled = false
	board_destroy_enabled = false
	ball_boom_enabled = false
	emoji_era_intro_done = false
	difficulty_bonus_easy = 0
	difficulty_bonus_hard = 0
	difficulty_bonus_sandbox = 0
	difficulty_bonus_hardcore = 0
	hardcore_base_plus2 = true
	custom_grid_size = 0
	custom_pair_count = 0


func _default_mode_entry() -> Dictionary:
	return {
		"last_unlocked_level": 1,
		"completed_levels": {},
		"perfect_streak": 0,
		"skip_density_steps": 0,
		## true = la próxima racha de 3 da pista; luego alterna a false, etc.
		"streak_reward_next": true,
		"hints_remaining": STARTING_HINTS,
		"total_score": 0,
	}


func _ensure_mode(mode_id: String) -> void:
	if not modes_progress.has(mode_id) or typeof(modes_progress[mode_id]) != TYPE_DICTIONARY:
		modes_progress[mode_id] = _default_mode_entry()
		return

	var entry: Dictionary = modes_progress[mode_id]
	if not entry.has("last_unlocked_level"):
		entry["last_unlocked_level"] = 1
	if typeof(entry.get("completed_levels", null)) != TYPE_DICTIONARY:
		entry["completed_levels"] = {}
	if not entry.has("perfect_streak"):
		entry["perfect_streak"] = 0
	if not entry.has("skip_density_steps"):
		entry["skip_density_steps"] = 0
	if not entry.has("streak_reward_next"):
		entry["streak_reward_next"] = true
	if not entry.has("hints_remaining"):
		entry["hints_remaining"] = STARTING_HINTS
	if not entry.has("total_score"):
		entry["total_score"] = 0
	entry["last_unlocked_level"] = maxi(1, int(entry["last_unlocked_level"]))
	entry["perfect_streak"] = maxi(0, int(entry["perfect_streak"]))
	entry["skip_density_steps"] = maxi(0, int(entry["skip_density_steps"]))
	entry["streak_reward_next"] = bool(entry["streak_reward_next"])
	entry["hints_remaining"] = maxi(0, int(entry["hints_remaining"]))
	entry["total_score"] = maxi(0, int(entry["total_score"]))
	modes_progress[mode_id] = entry


func _mode_key(mode_id: String = "") -> String:
	if mode_id.is_empty():
		return LevelManager.current_mode if LevelManager != null else last_mode
	return mode_id


func _mode_data(mode_id: String = "") -> Dictionary:
	var key := _mode_key(mode_id)
	_ensure_mode(key)
	return modes_progress[key]


## Reinicia progreso, pistas y puntuación de un modo (irreversible).
func reset_mode_progress(mode_id: String) -> void:
	var key := _mode_key(mode_id)
	modes_progress[key] = _default_mode_entry()
	save_data()


func set_last_mode(mode_id: String) -> void:
	last_mode = mode_id
	save_data()


func get_last_unlocked_level(mode_id: String = "") -> int:
	return int(_mode_data(mode_id).get("last_unlocked_level", 1))


## Compatibilidad con código que aún lea la propiedad antigua.
var last_unlocked_level: int:
	get:
		return get_last_unlocked_level()
	set(value):
		var data := _mode_data()
		data["last_unlocked_level"] = maxi(1, value)
		modes_progress[LevelManager.current_mode] = data


func is_level_unlocked(level_id: int, mode_id: String = "") -> bool:
	return level_id <= get_last_unlocked_level(mode_id)


func is_level_completed(level_id: int, mode_id: String = "") -> bool:
	var completed: Dictionary = _mode_data(mode_id).get("completed_levels", {})
	return completed.has(str(level_id))


func get_level_stars(level_id: int, mode_id: String = "") -> int:
	var completed: Dictionary = _mode_data(mode_id).get("completed_levels", {})
	if not completed.has(str(level_id)):
		return 0
	var entry: Variant = completed[str(level_id)]
	if typeof(entry) != TYPE_DICTIONARY:
		return 0
	return int(entry.get("stars", 0))


func get_best_moves(level_id: int, mode_id: String = "") -> int:
	var completed: Dictionary = _mode_data(mode_id).get("completed_levels", {})
	if not completed.has(str(level_id)):
		return -1
	var entry: Variant = completed[str(level_id)]
	if typeof(entry) != TYPE_DICTIONARY:
		return -1
	return int(entry.get("best_moves", -1))


## Completa un nivel y aplica economía de pistas.
## elapsed_sec: tiempo de resolución; level: datos del nivel (para el tope de racha).
## Devuelve { hint_reward, first_perfect, streak_reward, perfect_streak, streak_counted, streak_time_limit }.
func register_level_complete(
	level_id: int,
	moves: int,
	stars: int,
	mode_id: String = "",
	elapsed_sec: float = -1.0,
	level: Dictionary = {}
) -> Dictionary:
	var key_mode := _mode_key(mode_id)
	var data := _mode_data(key_mode)
	var completed: Dictionary = data.get("completed_levels", {})
	var level_key := str(level_id)

	var previous_best := get_best_moves(level_id, key_mode)
	var previous_stars := get_level_stars(level_id, key_mode)
	var clamped_stars := clampi(stars, 0, 3)

	var best_moves := moves
	if previous_best >= 0:
		best_moves = mini(previous_best, moves)

	completed[level_key] = {
		"stars": maxi(previous_stars, clamped_stars),
		"best_moves": best_moves,
	}
	data["completed_levels"] = completed

	var unlocked := int(data.get("last_unlocked_level", 1))
	if level_id >= unlocked:
		data["last_unlocked_level"] = level_id + 1

	var hint_reward := 0
	var first_perfect := false
	var streak_reward := false
	var streak := int(data.get("perfect_streak", 0))
	var time_limit := LevelManager.streak_qualify_seconds(level) if not level.is_empty() else 45.0
	var streak_counted := false

	if clamped_stars >= 3:
		if previous_stars < 3:
			first_perfect = true
			hint_reward += 1
		# Solo cuenta para la racha si se resolvió a tiempo (jugador rápido).
		var within_time := elapsed_sec < 0.0 or elapsed_sec <= time_limit
		if within_time:
			streak_counted = true
			streak += 1
			if streak >= PERFECT_STREAK_REWARD:
				# Alterna: una racha premiada y la siguiente no.
				var reward_next := bool(data.get("streak_reward_next", true))
				if reward_next:
					streak_reward = true
					hint_reward += 1
				data["streak_reward_next"] = not reward_next
				streak = 0
			data["perfect_streak"] = streak
		# 3★ lento: no suma a la racha ni la rompe.
	else:
		data["perfect_streak"] = 0

	if hint_reward > 0:
		data["hints_remaining"] = maxi(0, int(data.get("hints_remaining", STARTING_HINTS)) + hint_reward)

	var score_gained := _points_for_stars(clamped_stars)
	if score_gained > 0:
		data["total_score"] = maxi(0, int(data.get("total_score", 0)) + score_gained)

	modes_progress[key_mode] = data
	last_mode = key_mode
	save_data()
	return {
		"hint_reward": hint_reward,
		"first_perfect": first_perfect,
		"streak_reward": streak_reward,
		"perfect_streak": int(data.get("perfect_streak", 0)),
		"streak_counted": streak_counted,
		"streak_time_limit": time_limit,
		"score_gained": score_gained,
		"total_score": int(data.get("total_score", 0)),
	}


## Canje: gasta todas las pistas, rompe racha, desbloquea siguiente sin subir estrellas,
## y suma un paso de densidad para niveles futuros del modo.
func redeem_hints_to_skip(level_id: int, mode_id: String = "") -> Dictionary:
	var key_mode := _mode_key(mode_id)
	var data := _mode_data(key_mode)
	var hints_now := maxi(0, int(data.get("hints_remaining", STARTING_HINTS)))
	if hints_now < HINT_REDEEM_MIN:
		return {"ok": false, "spent": 0}

	var spent := hints_now
	data["hints_remaining"] = 0
	data["perfect_streak"] = 0
	data["skip_density_steps"] = int(data.get("skip_density_steps", 0)) + 1

	var completed: Dictionary = data.get("completed_levels", {})
	var level_key := str(level_id)
	var previous_stars := get_level_stars(level_id, key_mode)
	var previous_best := get_best_moves(level_id, key_mode)
	var entry: Dictionary = {}
	if completed.has(level_key) and typeof(completed[level_key]) == TYPE_DICTIONARY:
		entry = (completed[level_key] as Dictionary).duplicate()
	entry["stars"] = previous_stars
	if previous_best >= 0:
		entry["best_moves"] = previous_best
	elif not entry.has("best_moves"):
		entry["best_moves"] = -1
	entry["skipped"] = true
	completed[level_key] = entry
	data["completed_levels"] = completed

	var unlocked := int(data.get("last_unlocked_level", 1))
	if level_id >= unlocked:
		data["last_unlocked_level"] = level_id + 1

	modes_progress[key_mode] = data
	last_mode = key_mode
	save_data()
	return {
		"ok": true,
		"spent": spent,
		"skip_density_steps": int(data.get("skip_density_steps", 0)),
		"next_level_id": level_id + 1,
	}


func can_redeem_hints(mode_id: String = "") -> bool:
	return get_hints(mode_id) >= HINT_REDEEM_MIN


func get_perfect_streak(mode_id: String = "") -> int:
	return maxi(0, int(_mode_data(mode_id).get("perfect_streak", 0)))


func get_skip_density_steps(mode_id: String = "") -> int:
	return maxi(0, int(_mode_data(mode_id).get("skip_density_steps", 0)))


func break_perfect_streak(mode_id: String = "") -> void:
	var key_mode := _mode_key(mode_id)
	var data := _mode_data(key_mode)
	data["perfect_streak"] = 0
	modes_progress[key_mode] = data
	save_data()


func set_sound_enabled(enabled: bool) -> void:
	sound_enabled = enabled
	save_data()


func set_vibration_enabled(enabled: bool) -> void:
	vibration_enabled = enabled
	save_data()


func set_fx_enabled(enabled: bool) -> void:
	fx_enabled = enabled
	save_data()


func set_colorblind_enabled(enabled: bool) -> void:
	colorblind_enabled = enabled
	save_data()


func set_visual_help_enabled(enabled: bool) -> void:
	visual_help_enabled = enabled
	save_data()


func set_colored_board_enabled(enabled: bool) -> void:
	colored_board_enabled = enabled
	save_data()


func set_board_destroy_enabled(enabled: bool) -> void:
	board_destroy_enabled = enabled
	save_data()


func set_ball_boom_enabled(enabled: bool) -> void:
	ball_boom_enabled = enabled
	save_data()


func mark_emoji_era_intro_done() -> void:
	emoji_era_intro_done = true
	save_data()


func set_difficulty_bonus(mode_id: String, value: int) -> void:
	var v := clampi(value, 0, 2)
	match mode_id:
		"hard":
			difficulty_bonus_hard = v
		"sandbox":
			difficulty_bonus_sandbox = v
		"hardcore":
			difficulty_bonus_hardcore = v
		_:
			difficulty_bonus_easy = v
	save_data()


func get_difficulty_bonus(mode_id: String) -> int:
	match mode_id:
		"hard", "chrono":
			return clampi(difficulty_bonus_hard, 0, 2)
		"sandbox":
			return clampi(difficulty_bonus_sandbox, 0, 2)
		"hardcore":
			return clampi(difficulty_bonus_hardcore, 0, 2)
		_:
			return clampi(difficulty_bonus_easy, 0, 2)


func is_hardcore_unlocked() -> bool:
	return is_level_completed(20, "hard")


func write_difficulty_state(
	easy_bonus: int,
	hard_bonus: int,
	sandbox_bonus: int,
	hardcore_bonus: int,
	grid_size: int,
	pair_count: int
) -> void:
	difficulty_bonus_easy = clampi(easy_bonus, 0, 2)
	difficulty_bonus_hard = clampi(hard_bonus, 0, 2)
	difficulty_bonus_sandbox = clampi(sandbox_bonus, 0, 2)
	difficulty_bonus_hardcore = clampi(hardcore_bonus, 0, 2)
	custom_grid_size = _clamp_saved_grid(grid_size)
	custom_pair_count = _clamp_saved_pairs(pair_count)
	if custom_grid_size > 0 or custom_pair_count > 0:
		difficulty_bonus_easy = 0
		difficulty_bonus_hard = 0
		difficulty_bonus_sandbox = 0
		difficulty_bonus_hardcore = 0
	save_data()


func get_custom_grid_size() -> int:
	return _clamp_saved_grid(custom_grid_size)


func get_custom_pair_count() -> int:
	return _clamp_saved_pairs(custom_pair_count)


func _clamp_saved_grid(value: int) -> int:
	if value <= 0:
		return 0
	return clampi(value, 4, 15)


func _clamp_saved_pairs(value: int) -> int:
	if value <= 0:
		return 0
	return clampi(value, 2, 16)


func get_hints(mode_id: String = "") -> int:
	return maxi(0, int(_mode_data(mode_id).get("hints_remaining", STARTING_HINTS)))


func get_score(mode_id: String = "") -> int:
	return maxi(0, int(_mode_data(mode_id).get("total_score", 0)))


func set_hints(amount: int, mode_id: String = "") -> void:
	var key := _mode_key(mode_id)
	var data := _mode_data(key)
	data["hints_remaining"] = maxi(0, amount)
	modes_progress[key] = data
	save_data()


## Misma tabla que la puntuación de victoria por estrellas.
func _points_for_stars(stars: int) -> int:
	match clampi(stars, 0, 3):
		3:
			return 1000
		2:
			return 600
		1:
			return 300
		_:
			return 0


func consume_hint(mode_id: String = "") -> bool:
	var key := _mode_key(mode_id)
	var data := _mode_data(key)
	var hints_now := maxi(0, int(data.get("hints_remaining", STARTING_HINTS)))
	if hints_now <= 0:
		return false
	data["hints_remaining"] = hints_now - 1
	modes_progress[key] = data
	save_data()
	return true


func add_hint(amount: int = 1, mode_id: String = "") -> int:
	var key := _mode_key(mode_id)
	var data := _mode_data(key)
	var hints_now := maxi(0, int(data.get("hints_remaining", STARTING_HINTS)) + amount)
	data["hints_remaining"] = hints_now
	modes_progress[key] = data
	save_data()
	return hints_now


func spend_all_hints(mode_id: String = "") -> int:
	var key := _mode_key(mode_id)
	var data := _mode_data(key)
	var spent := maxi(0, int(data.get("hints_remaining", STARTING_HINTS)))
	data["hints_remaining"] = 0
	modes_progress[key] = data
	save_data()
	return spent
