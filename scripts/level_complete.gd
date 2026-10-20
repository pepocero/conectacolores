extends Control

## Pantalla reutilizable de victoria (mismo cartel animado que en partida).

const VictoryOverlayScript := preload("res://scripts/victory_overlay.gd")

signal next_pressed
signal retry_pressed
signal menu_pressed

var _victory


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory = VictoryOverlayScript.new()
	_victory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_victory)
	_victory.next_pressed.connect(_on_next)
	_victory.retry_pressed.connect(_on_retry)
	_victory.menu_pressed.connect(_on_menu)


func setup(
	moves: int,
	stars: int,
	has_next: bool,
	color_stats: Array = [],
	level_id: int = 1,
	hint_reward: int = 0,
	reward_meta: Dictionary = {}
) -> void:
	if _victory == null:
		return
	_victory.present(moves, stars, color_stats, has_next, level_id, hint_reward, reward_meta)


func _on_next() -> void:
	next_pressed.emit()


func _on_retry() -> void:
	retry_pressed.emit()


func _on_menu() -> void:
	menu_pressed.emit()
