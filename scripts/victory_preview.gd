extends Control

## Vista previa de la animación de victoria (+ pista) sin jugar un nivel.

const VictoryOverlayScript := preload("res://scripts/victory_overlay.gd")

var _victory: Control
var _hint_before: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_chrome()
	call_deferred("_play_preview")


func _build_chrome() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_top = 12
	bar.offset_bottom = 64
	bar.offset_left = 16
	bar.offset_right = -16
	bar.add_theme_constant_override("separation", 12)
	bar.z_index = 200
	add_child(bar)

	var replay := UIFactory.make_orange_button("Repetir animación", 52)
	replay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay.pressed.connect(_play_preview)
	bar.add_child(replay)

	var back := UIFactory.make_button("Menú", 52)
	UIFactory.set_button_colors(back, GamePalette.MENU_YELLOW, GamePalette.MENU_YELLOW_TEXT)
	back.custom_minimum_size.x = 140
	back.pressed.connect(_go_menu)
	bar.add_child(back)


func _play_preview() -> void:
	if is_instance_valid(_victory):
		_victory.queue_free()
		_victory = null

	# Restaura pistas tras una preview anterior para poder repetir el +1.
	if _hint_before > 0:
		SaveManager.set_hints(_hint_before)

	_hint_before = SaveManager.get_hints()
	# Simula ganar 1 pista (como en racha) sin tocar progreso de niveles.
	SaveManager.set_hints(_hint_before + 1)

	_victory = VictoryOverlayScript.new()
	_victory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_victory)
	move_child(_victory, 0)

	var color_stats: Array = _preview_color_stats()
	_victory.present(
		10,
		3,
		color_stats,
		true,
		1,
		1,
		{
			"first_perfect": false,
			"streak_reward": true,
		}
	)


func _preview_color_stats() -> Array:
	## Colores reales de la paleta; cantidades solo para la secuencia visual.
	var picks: Array[String] = ["cyan", "orange", "green", "pink"]
	var stats: Array = []
	for i in range(picks.size()):
		var key := picks[i]
		if not GamePalette.COLORS.has(key):
			continue
		var connections := 3 + i
		stats.append({
			"color": key,
			"connections": connections,
			"cells": connections + 1,
		})
	return stats


func _go_menu() -> void:
	if _hint_before > 0:
		SaveManager.set_hints(_hint_before)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
