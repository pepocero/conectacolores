extends Node

signal settings_changed

var sound_enabled: bool = true
var vibration_enabled: bool = true
var fx_enabled: bool = true
var colorblind_enabled: bool = false
var visual_help_enabled: bool = false
var colored_board_enabled: bool = false
var board_destroy_enabled: bool = false
var ball_boom_enabled: bool = false
var difficulty_bonus_easy: int = 0
var difficulty_bonus_hard: int = 0
var difficulty_bonus_sandbox: int = 0
var difficulty_bonus_hardcore: int = 0
var custom_grid_size: int = 0
var custom_pair_count: int = 0


func _ready() -> void:
	sync_from_save()


func sync_from_save() -> void:
	sound_enabled = SaveManager.sound_enabled
	vibration_enabled = SaveManager.vibration_enabled
	fx_enabled = SaveManager.fx_enabled
	colorblind_enabled = SaveManager.colorblind_enabled
	visual_help_enabled = SaveManager.visual_help_enabled
	colored_board_enabled = SaveManager.colored_board_enabled
	board_destroy_enabled = SaveManager.board_destroy_enabled
	ball_boom_enabled = SaveManager.ball_boom_enabled
	difficulty_bonus_easy = SaveManager.get_difficulty_bonus("easy")
	difficulty_bonus_hard = SaveManager.get_difficulty_bonus("hard")
	difficulty_bonus_sandbox = SaveManager.get_difficulty_bonus("sandbox")
	difficulty_bonus_hardcore = SaveManager.get_difficulty_bonus("hardcore")
	custom_grid_size = SaveManager.get_custom_grid_size()
	custom_pair_count = SaveManager.get_custom_pair_count()
	settings_changed.emit()


func set_sound(enabled: bool) -> void:
	sound_enabled = enabled
	SaveManager.set_sound_enabled(enabled)
	settings_changed.emit()


func set_vibration(enabled: bool) -> void:
	vibration_enabled = enabled
	SaveManager.set_vibration_enabled(enabled)
	settings_changed.emit()


func set_fx(enabled: bool) -> void:
	fx_enabled = enabled
	SaveManager.set_fx_enabled(enabled)
	settings_changed.emit()


func set_colorblind(enabled: bool) -> void:
	colorblind_enabled = enabled
	SaveManager.set_colorblind_enabled(enabled)
	settings_changed.emit()


func set_visual_help(enabled: bool) -> void:
	visual_help_enabled = enabled
	SaveManager.set_visual_help_enabled(enabled)
	settings_changed.emit()


func set_colored_board(enabled: bool) -> void:
	colored_board_enabled = enabled
	SaveManager.set_colored_board_enabled(enabled)
	settings_changed.emit()


func set_board_destroy(enabled: bool) -> void:
	board_destroy_enabled = enabled
	SaveManager.set_board_destroy_enabled(enabled)
	settings_changed.emit()


func set_ball_boom(enabled: bool) -> void:
	ball_boom_enabled = enabled
	SaveManager.set_ball_boom_enabled(enabled)
	settings_changed.emit()


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


func set_difficulty_bonus(mode_id: String, value: int) -> void:
	if is_custom_active() and value > 0:
		return
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
	if v > 0:
		custom_grid_size = 0
		custom_pair_count = 0
	_persist_difficulty()
	settings_changed.emit()


func cycle_difficulty_bonus(mode_id: String) -> void:
	var current := get_difficulty_bonus(mode_id)
	set_difficulty_bonus(mode_id, (current + 1) % 3)


func is_custom_active() -> bool:
	return get_custom_grid_size() > 0 or get_custom_pair_count() > 0


func has_mode_multiplier() -> bool:
	return (
		get_difficulty_bonus("easy") > 0
		or get_difficulty_bonus("hard") > 0
		or get_difficulty_bonus("sandbox") > 0
		or get_difficulty_bonus("hardcore") > 0
	)


func get_custom_grid_size() -> int:
	return LevelGenerator.clamp_custom_grid(custom_grid_size)


func set_custom_grid_size(value: int) -> void:
	if has_mode_multiplier() and value > 0:
		return
	var v := LevelGenerator.clamp_custom_grid(value)
	if v > 0:
		difficulty_bonus_easy = 0
		difficulty_bonus_hard = 0
		difficulty_bonus_sandbox = 0
		difficulty_bonus_hardcore = 0
		if custom_pair_count > 0:
			custom_pair_count = LevelGenerator.clamp_custom_pairs(custom_pair_count, v)
	custom_grid_size = v
	_persist_difficulty()
	settings_changed.emit()


func get_custom_pair_count() -> int:
	return LevelGenerator.clamp_custom_pairs(custom_pair_count, get_custom_grid_size())


func set_custom_pair_count(value: int) -> void:
	if has_mode_multiplier() and value > 0:
		return
	var grid := get_custom_grid_size()
	var v := value
	if v > 0:
		difficulty_bonus_easy = 0
		difficulty_bonus_hard = 0
		difficulty_bonus_sandbox = 0
		difficulty_bonus_hardcore = 0
		if grid > 0:
			var max_p := LevelGenerator.max_pairs_for_grid(grid)
			if v > max_p:
				var need := LevelGenerator.min_grid_for_pairs(v)
				custom_grid_size = need
				grid = need
		v = LevelGenerator.clamp_custom_pairs(v, grid)
	custom_pair_count = v
	_persist_difficulty()
	settings_changed.emit()


func _persist_difficulty() -> void:
	SaveManager.write_difficulty_state(
		difficulty_bonus_easy,
		difficulty_bonus_hard,
		difficulty_bonus_sandbox,
		difficulty_bonus_hardcore,
		custom_grid_size,
		custom_pair_count
	)


func toggle_sound() -> void:
	set_sound(not sound_enabled)


func toggle_vibration() -> void:
	set_vibration(not vibration_enabled)


func toggle_fx() -> void:
	set_fx(not fx_enabled)


func toggle_colorblind() -> void:
	set_colorblind(not colorblind_enabled)


func toggle_visual_help() -> void:
	set_visual_help(not visual_help_enabled)


func toggle_colored_board() -> void:
	set_colored_board(not colored_board_enabled)


func toggle_board_destroy() -> void:
	set_board_destroy(not board_destroy_enabled)


func toggle_ball_boom() -> void:
	set_ball_boom(not ball_boom_enabled)
