extends Node

## Comprueba la curva de dificultad procedural de Fácil y Difícil:
## solvabilidad, puntuación creciente, easy < hard y tiempo de generación.
## Se ejecuta como escena para que los autoloads (SettingsManager...) existan:
## godot --headless --path . res://tools/smoke_procedural.tscn

const FIRST_LEVEL := 1
const LAST_LEVEL := 120
const STEP := 3
## Muestras sueltas de la era infinita.
const EXTRA_SAMPLES: Array[int] = [150, 201, 250, 300]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_reset_curve_modifiers()
	var samples: Array[int] = []
	var lvl := FIRST_LEVEL
	while lvl <= LAST_LEVEL:
		samples.append(lvl)
		lvl += STEP
	for extra: int in EXTRA_SAMPLES:
		samples.append(extra)

	var prev_easy := -1.0
	var prev_hard := -1.0
	var failed := 0
	var slowest_ms := 0

	for level_id: int in samples:
		var t0 := Time.get_ticks_msec()
		var hard := LevelGenerator.generate("hard", level_id, prev_hard, -1.0)
		var t1 := Time.get_ticks_msec()
		var hard_score := float(hard.get("difficulty_score", -1.0))
		var easy := LevelGenerator.generate("easy", level_id, prev_easy, hard_score)
		var t2 := Time.get_ticks_msec()
		slowest_ms = maxi(slowest_ms, maxi(t1 - t0, t2 - t1))

		if easy.is_empty() or not LevelGenerator.is_solvable(easy):
			printerr("FAIL easy #%d no resoluble" % level_id)
			failed += 1
			continue
		if hard.is_empty() or not LevelGenerator.is_solvable(hard):
			printerr("FAIL hard #%d no resoluble" % level_id)
			failed += 1
			continue

		var se := float(easy.get("difficulty_score", LevelGenerator.difficulty_score(easy)))
		var sh := float(hard.get("difficulty_score", LevelGenerator.difficulty_score(hard)))

		if se >= sh:
			printerr("FAIL #%d easy score(%.1f) >= hard score(%.1f)" % [level_id, se, sh])
			failed += 1
		if prev_easy >= 0.0 and se + 0.001 < prev_easy:
			printerr("FAIL easy score bajó en #%d: %.1f -> %.1f" % [level_id, prev_easy, se])
			failed += 1
		if prev_hard >= 0.0 and sh + 0.001 < prev_hard:
			printerr("FAIL hard score bajó en #%d: %.1f -> %.1f" % [level_id, prev_hard, sh])
			failed += 1

		print("#%-4d EASY %s  %dms" % [level_id, _describe(easy), t2 - t1])
		print("      HARD %s  %dms" % [_describe(hard), t1 - t0])
		prev_easy = se
		prev_hard = sh

	print("Generación más lenta: %d ms" % slowest_ms)
	if failed > 0:
		printerr("SMOKE PROCEDURAL: %d fallos" % failed)
		get_tree().quit(1)
		return

	print("SMOKE PROCEDURAL OK")
	get_tree().quit(0)


func _describe(level: Dictionary) -> String:
	var size := int(level.get("size", 0))
	var solution: Dictionary = level.get("solution", {})
	var pairs := solution.size()
	var metrics: Dictionary = level.get("metrics", {})
	var cpp := float(size * size) / float(maxi(1, pairs))
	return "%dx%d parejas=%-2d cpp=%.1f cover=%.2f desvio=%.2f interf=%.2f nodos=%-5d score=%.1f" % [
		size,
		size,
		pairs,
		cpp,
		float(metrics.get("cover", 0.0)),
		float(metrics.get("detour", 0.0)),
		float(metrics.get("interference", 0.0)),
		int(metrics.get("solver_nodes", 0)),
		float(level.get("difficulty_score", 0.0)),
	]


func _reset_curve_modifiers() -> void:
	if SettingsManager != null:
		SettingsManager.difficulty_bonus_easy = 0
		SettingsManager.difficulty_bonus_hard = 0
		SettingsManager.difficulty_bonus_sandbox = 0
		SettingsManager.difficulty_bonus_hardcore = 0
		SettingsManager.custom_grid_size = 0
		SettingsManager.custom_pair_count = 0
	if SaveManager == null:
		return
	for mode_id in ["easy", "hard", "hardcore", "sandbox"]:
		if typeof(SaveManager.modes_progress.get(mode_id, null)) == TYPE_DICTIONARY:
			SaveManager.modes_progress[mode_id]["skip_density_steps"] = 0
