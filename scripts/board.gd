class_name Board
extends Control

signal moves_changed(moves: int)
signal pairs_changed(remaining: int, total: int)
signal level_completed(moves: int)
signal solution_revealed
signal invalid_move
signal pair_connected(color_name: String)
signal path_started(color_name: String)

const ColorShapesScript := preload("res://scripts/color_shapes.gd")
const CartoonExplosionFxScript := preload("res://scripts/cartoon_explosion_fx.gd")
const BoardDestroyFxScript := preload("res://scripts/board_destroy_fx.gd")

## Duración de la explosión cartoon al completar el nivel (todas las bolas a la vez).
## La rotura del tablero espera a que termine por completo (sin solape).
const LEVEL_COMPLETE_EXPLOSION_SEC := 3.0
## Vida máxima de las burbujas de celebración (coincide con max_life en _spawn_rising_bubbles).
const BUBBLE_CELEBRATION_SEC := 1.8
const BOARD_DESTROY_SEC := 3.75
const HINT_DURATION := 20.0
const HINT_PATH_FRACTION := 0.7

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

var grid_size: int = 5
var level_id: int = 1
var endpoints: Dictionary = {} # Vector2i -> String color
var connections: Dictionary = {} # String color -> Connection
var solution: Dictionary = {} # String color -> Array[Vector2i]
var occupied: Dictionary = {} # Vector2i -> String color

var moves: int = 0
var active_color: String = ""
var is_dragging: bool = false
var hint_color: String = ""
var hint_timer: float = 0.0
## Parejas que ya recibieron pista de camino en este nivel (una pista = un color).
var _hinted_colors: Array[String] = []
var pulse_time: float = 0.0
var just_completed: bool = false
var complete_flash: float = 0.0
var invalid_flash: float = 0.0
var connect_flash_color: String = ""
var connect_flash: float = 0.0

var cell_size: float = 64.0
var board_origin: Vector2 = Vector2.ZERO
var padding: float = 16.0
var _emoji_font: Font

## Partículas ligeras dibujadas en el propio tablero (sin nodos extra).
var _particles: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []
var _celebrating: bool = false
var _revealing_solution: bool = false
var _inflate_color: String = ""
var _inflate_all: bool = false
var _inflate_amount: float = 1.0
var _inflate_hidden: bool = false
## Opacidad de bolas/caminos en la celebración (1 = visibles, 0 = desaparecidas).
var _ball_fade: float = 1.0
var _cartoon_booms: Array[Node] = []
## True mientras el shader destruye el tablero completo (oculta el _draw normal).
var _board_destroy_active: bool = false
var _board_destroy_fx: Node = null
## Textura de rotura pregenerada (cinemática era: evitar hitch CPU al impacto).
var _era_destroy_tex_cache: Texture2D = null
## Sal en la seed de tintes del tablero (Modo Crazy / chaos).
var _chaos_tint_salt: int = 0
## Tick de urgencia (últimos segundos): desplaza el color de cada casilla.
var _urgency_tick: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	pair_connected.connect(_on_pair_connected_fx)
	invalid_move.connect(_on_invalid_fx)
	path_started.connect(_on_path_started_fx)


func _process(delta: float) -> void:
	pulse_time += delta
	if hint_timer > 0.0:
		hint_timer = maxf(0.0, hint_timer - delta)
		if hint_timer <= 0.0:
			hint_color = ""
	if complete_flash > 0.0:
		complete_flash = maxf(0.0, complete_flash - delta)
	if invalid_flash > 0.0:
		invalid_flash = maxf(0.0, invalid_flash - delta)
	if connect_flash > 0.0:
		connect_flash = maxf(0.0, connect_flash - delta)
	_update_fx(delta)
	# Durante la rotura el tablero real no se pinta; evitar redraw inútil.
	if not _board_destroy_active:
		queue_redraw()


func setup_level(level_data: Dictionary) -> void:
	grid_size = int(level_data.get("size", 5))
	level_id = int(level_data.get("id", LevelManager.current_level_id))
	endpoints.clear()
	connections.clear()
	occupied.clear()
	solution.clear()
	moves = 0
	active_color = ""
	is_dragging = false
	hint_color = ""
	hint_timer = 0.0
	_hinted_colors.clear()
	just_completed = false
	_celebrating = false
	_revealing_solution = false
	_inflate_color = ""
	_inflate_all = false
	_inflate_amount = 1.0
	_inflate_hidden = false
	_ball_fade = 1.0
	_board_destroy_active = false
	_clear_board_destroy_fx()
	_chaos_tint_salt = 0
	_urgency_tick = 0
	complete_flash = 0.0
	invalid_flash = 0.0
	connect_flash = 0.0
	connect_flash_color = ""
	_particles.clear()
	_ripples.clear()
	_clear_cartoon_booms()
	_set_level_bg_fx_paused(false)

	var dots: Array = level_data.get("dots", [])
	for dot: Variant in dots:
		var color_name := str(dot.get("color", ""))
		var pos := Vector2i(int(dot.get("x", 0)), int(dot.get("y", 0)))
		endpoints[pos] = color_name
		if not connections.has(color_name):
			connections[color_name] = Connection.new(color_name)

	var raw_solution: Dictionary = level_data.get("solution", {})
	for color_name: Variant in raw_solution.keys():
		var path: Array = raw_solution[color_name]
		var cells: Array[Vector2i] = []
		for point: Variant in path:
			cells.append(Vector2i(int(point[0]), int(point[1])))
		solution[str(color_name)] = cells

	_recalculate_layout()
	_emit_status()
	queue_redraw()


func reset_level() -> void:
	for color_name: Variant in connections.keys():
		var conn: Connection = connections[color_name]
		conn.clear_path()
		conn.completed = false
	occupied.clear()
	moves = 0
	active_color = ""
	is_dragging = false
	hint_color = ""
	hint_timer = 0.0
	_hinted_colors.clear()
	just_completed = false
	_celebrating = false
	_revealing_solution = false
	_inflate_color = ""
	_inflate_all = false
	_inflate_amount = 1.0
	_inflate_hidden = false
	_ball_fade = 1.0
	_board_destroy_active = false
	_clear_board_destroy_fx()
	complete_flash = 0.0
	invalid_flash = 0.0
	connect_flash = 0.0
	connect_flash_color = ""
	_particles.clear()
	_ripples.clear()
	_clear_cartoon_booms()
	_set_level_bg_fx_paused(false)
	_emit_status()
	queue_redraw()


func is_celebrating() -> bool:
	return _celebrating or _revealing_solution


## Aplica la solución del nivel (canje de pistas). No emite level_completed.
func reveal_solution(animated: bool = true) -> void:
	if _revealing_solution or just_completed:
		return
	_revealing_solution = true
	just_completed = true
	is_dragging = false
	active_color = ""
	hint_color = ""
	hint_timer = 0.0

	# Limpiar caminos parciales del jugador.
	for color_name: Variant in connections.keys():
		var conn: Connection = connections[color_name]
		conn.clear_path()
		conn.completed = false
	occupied.clear()

	var color_keys: Array = solution.keys()
	color_keys.sort()
	for color_variant: Variant in color_keys:
		var color_name := str(color_variant)
		if not connections.has(color_name) or not solution.has(color_name):
			continue
		var path: Array[Vector2i] = solution[color_name]
		var conn: Connection = connections[color_name]
		conn.cells.clear()
		for cell: Vector2i in path:
			conn.append_cell(cell)
			occupied[cell] = color_name
		conn.completed = path.size() >= 2
		connect_flash_color = color_name
		connect_flash = 0.35
		_play_sfx("CONNECT")
		_emit_status()
		queue_redraw()
		if animated and is_inside_tree():
			await get_tree().create_timer(0.22).timeout
			if not is_instance_valid(self):
				return

	_revealing_solution = false
	complete_flash = 0.8
	_emit_status()
	queue_redraw()
	solution_revealed.emit()


func get_remaining_pairs() -> int:
	var remaining := 0
	for color_name: Variant in connections.keys():
		var conn: Connection = connections[color_name]
		if not conn.completed:
			remaining += 1
	return remaining


func get_total_pairs() -> int:
	return connections.size()


## Chaos Crazy: congela parejas completadas, regenera el resto en celdas libres.
## Devuelve { ok, need_full_regen, dots, solution }.
func chaos_recolor(rng: RandomNumberGenerator = null) -> Dictionary:
	if just_completed or _celebrating or _revealing_solution:
		var done := _export_dots_and_solution()
		done["ok"] = true
		done["need_full_regen"] = false
		return done

	is_dragging = false
	active_color = ""
	hint_color = ""
	hint_timer = 0.0
	_hinted_colors.clear()
	connect_flash = 0.0
	connect_flash_color = ""

	var local_rng := rng
	if local_rng == null:
		local_rng = RandomNumberGenerator.new()
		local_rng.randomize()

	var completed_paths: Array[Dictionary] = [] # { cells: Array[Vector2i] }
	var remaining := 0
	for color_variant: Variant in connections.keys():
		var color_name := str(color_variant)
		var conn: Connection = connections[color_name]
		if conn.completed and conn.cells.size() >= 2:
			var cells_copy: Array[Vector2i] = []
			for c: Vector2i in conn.cells:
				cells_copy.append(c)
			completed_paths.append({"cells": cells_copy})
		else:
			remaining += 1

	# Sin nada pendiente: solo recolor visual de las ya hechas.
	if remaining <= 0:
		_chaos_recolor_completed_only(completed_paths, local_rng)
		var only := _export_dots_and_solution()
		only["ok"] = true
		only["need_full_regen"] = false
		return only

	var blocked: Array = []
	for entry: Dictionary in completed_paths:
		for c: Vector2i in entry["cells"]:
			blocked.append(c)

	# Reservar colores para completadas antes de regenerar el resto.
	var palette: Array[String] = LevelGenerator.COLOR_NAMES.duplicate()
	_chaos_shuffle_strings(palette, local_rng)
	var frozen_colors: Array[String] = []
	var forbidden: Array = []
	var used_colors: Dictionary = {}
	for _i in range(completed_paths.size()):
		var pick := _chaos_pick_unused_color(palette, used_colors)
		if pick.is_empty():
			return {
				"ok": false,
				"need_full_regen": true,
				"dots": [],
				"solution": {},
			}
		used_colors[pick] = true
		frozen_colors.append(pick)
		forbidden.append(pick)

	var rebuilt: Dictionary = LevelGenerator.rebuild_remaining(
		grid_size,
		remaining,
		blocked,
		local_rng.randi(),
		forbidden
	)

	if rebuilt.is_empty():
		return {
			"ok": false,
			"need_full_regen": true,
			"dots": [],
			"solution": {},
		}

	var new_dots: Array = rebuilt.get("dots", [])
	var new_solution: Dictionary = rebuilt.get("solution", {})

	endpoints.clear()
	connections.clear()
	solution.clear()
	occupied.clear()

	# Parejas congeladas con color reservado + solution = su camino actual.
	for i in range(completed_paths.size()):
		var entry: Dictionary = completed_paths[i]
		var cells: Array[Vector2i] = entry["cells"]
		var new_c: String = frozen_colors[i]
		var conn := Connection.new(new_c)
		for cell: Vector2i in cells:
			conn.append_cell(cell)
			occupied[cell] = new_c
		conn.completed = true
		connections[new_c] = conn
		if cells.size() >= 2:
			endpoints[cells[0]] = new_c
			endpoints[cells[cells.size() - 1]] = new_c
		var sol_cells: Array[Vector2i] = []
		for cell: Vector2i in cells:
			sol_cells.append(cell)
		solution[new_c] = sol_cells

	# Parejas nuevas regeneradas.
	for color_v: Variant in new_solution.keys():
		var color_name := str(color_v)
		var path_raw: Array = new_solution[color_name]
		var path_cells: Array[Vector2i] = []
		for point: Variant in path_raw:
			path_cells.append(Vector2i(int(point[0]), int(point[1])))
		solution[color_name] = path_cells
		if not connections.has(color_name):
			connections[color_name] = Connection.new(color_name)

	for dot_v: Variant in new_dots:
		if typeof(dot_v) != TYPE_DICTIONARY:
			continue
		var dot: Dictionary = dot_v
		var color_name := str(dot.get("color", ""))
		var pos := Vector2i(int(dot.get("x", 0)), int(dot.get("y", 0)))
		endpoints[pos] = color_name
		if not connections.has(color_name):
			connections[color_name] = Connection.new(color_name)

	_chaos_tint_salt = local_rng.randi()
	_emit_status()
	queue_redraw()
	var out := _export_dots_and_solution()
	out["ok"] = true
	out["need_full_regen"] = false
	return out


func _chaos_recolor_completed_only(completed_paths: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	var palette: Array[String] = LevelGenerator.COLOR_NAMES.duplicate()
	_chaos_shuffle_strings(palette, rng)
	var used: Dictionary = {}
	endpoints.clear()
	connections.clear()
	solution.clear()
	occupied.clear()
	for entry: Dictionary in completed_paths:
		var cells: Array[Vector2i] = entry["cells"]
		var new_c := _chaos_pick_unused_color(palette, used)
		if new_c.is_empty():
			break
		used[new_c] = true
		var conn := Connection.new(new_c)
		for cell: Vector2i in cells:
			conn.append_cell(cell)
			occupied[cell] = new_c
		conn.completed = true
		connections[new_c] = conn
		if cells.size() >= 2:
			endpoints[cells[0]] = new_c
			endpoints[cells[cells.size() - 1]] = new_c
		var sol_cells: Array[Vector2i] = []
		for cell: Vector2i in cells:
			sol_cells.append(cell)
		solution[new_c] = sol_cells
	_chaos_tint_salt = rng.randi()
	_emit_status()
	queue_redraw()


func _chaos_pick_unused_color(palette: Array[String], used: Dictionary) -> String:
	for c: String in palette:
		if not used.has(c):
			return c
	return ""


func _chaos_shuffle_strings(arr: Array[String], rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _export_dots_and_solution() -> Dictionary:
	var dots: Array = []
	for cell_v: Variant in endpoints.keys():
		var cell: Vector2i = cell_v
		dots.append({"color": str(endpoints[cell]), "x": cell.x, "y": cell.y})
	var sol: Dictionary = {}
	for color_v: Variant in solution.keys():
		var color_name := str(color_v)
		var path: Array = []
		for cell: Vector2i in solution[color_name]:
			path.append([cell.x, cell.y])
		sol[color_name] = path
	return {"dots": dots, "solution": sol}


func show_hint() -> bool:
	if just_completed:
		return false
	var color_name := _next_hint_color()
	if color_name.is_empty():
		return false
	if not solution.has(color_name):
		return false
	var sol: Array = solution[color_name]
	if sol.size() < 2:
		return false
	hint_color = color_name
	hint_timer = HINT_DURATION
	if not _hinted_colors.has(color_name):
		_hinted_colors.append(color_name)
	_play_sfx("HINT")
	queue_redraw()
	return true


func _next_hint_color() -> String:
	for color_variant: Variant in connections.keys():
		var color_name := str(color_variant)
		var conn: Connection = connections[color_name]
		if conn.completed:
			continue
		if _hinted_colors.has(color_name):
			continue
		return color_name
	return ""


func _hint_path_centers() -> PackedVector2Array:
	if hint_color.is_empty() or hint_timer <= 0.0 or not solution.has(hint_color):
		return PackedVector2Array()
	var sol: Array = solution[hint_color]
	if sol.size() < 2:
		return PackedVector2Array()
	var count := maxi(2, int(ceil(float(sol.size()) * HINT_PATH_FRACTION)))
	count = mini(count, sol.size())
	var pts := PackedVector2Array()
	pts.resize(count)
	for i in range(count):
		pts[i] = _cell_center(sol[i] as Vector2i)
	return pts


func _matches_prefix(path: Array[Vector2i], reference: Array[Vector2i]) -> int:
	if path.is_empty() or reference.is_empty():
		return -1
	if path[0] != reference[0]:
		return -1
	var matched := 0
	for i: int in mini(path.size(), reference.size()):
		if path[i] != reference[i]:
			return matched - 1
		matched = i
	return matched


func _get_endpoint_positions(color_name: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for pos: Vector2i in endpoints.keys():
		if endpoints[pos] == color_name:
			result.append(pos)
	return result


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_recalculate_layout()
		queue_redraw()


func _recalculate_layout() -> void:
	if grid_size <= 0:
		return
	var available := size - Vector2(padding * 2.0, padding * 2.0)
	var side := minf(available.x, available.y)
	cell_size = side / float(grid_size)
	var board_side := cell_size * float(grid_size)
	board_origin = (size - Vector2(board_side, board_side)) * 0.5


func _gui_input(event: InputEvent) -> void:
	if just_completed:
		return

	# Con emulate_touch_from_mouse activado, el ratón genera eventos táctiles.
	# Se prioriza touch/drag para evitar procesar la misma pulsación dos veces.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_press(touch.position)
		else:
			_on_release()
		accept_event()
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_on_drag(drag.position)
		accept_event()
		return

	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				_on_press(mouse.position)
			else:
				_on_release()
			accept_event()
		return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if is_dragging and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_on_drag(motion.position)
			accept_event()


func _on_press(local_pos: Vector2) -> void:
	var cell := _pos_to_cell(local_pos)
	if not _in_bounds(cell):
		return

	if endpoints.has(cell):
		var color_name: String = endpoints[cell]
		_start_from_endpoint(color_name, cell)
		return

	if occupied.has(cell):
		var color_name: String = occupied[cell]
		var conn: Connection = connections[color_name]
		if conn.contains(cell):
			_resume_from_path(color_name, cell)


func _start_from_endpoint(color_name: String, cell: Vector2i) -> void:
	var conn: Connection = connections[color_name]
	_clear_color_occupation(color_name)
	conn.clear_path()
	conn.append_cell(cell)
	conn.completed = false
	_mark_occupation(color_name)
	active_color = color_name
	is_dragging = true
	path_started.emit(color_name)
	_play_sfx("SELECT")
	_vibrate(12)
	_emit_status()
	queue_redraw()


func _resume_from_path(color_name: String, cell: Vector2i) -> void:
	var conn: Connection = connections[color_name]
	_clear_color_occupation(color_name)
	conn.truncate_to(cell)
	conn.completed = false
	_mark_occupation(color_name)
	active_color = color_name
	is_dragging = true
	path_started.emit(color_name)
	_play_sfx("SELECT")
	_emit_status()
	queue_redraw()


func _on_drag(local_pos: Vector2) -> void:
	if not is_dragging or active_color == "":
		return

	var cell := _pos_to_cell(local_pos)
	if not _in_bounds(cell):
		return

	var conn: Connection = connections[active_color]
	if conn.cells.is_empty():
		return

	if conn.contains(cell):
		var idx := conn.index_of(cell)
		if idx == conn.cells.size() - 1:
			return
		# Retroceder sobre el propio camino.
		_clear_color_occupation(active_color)
		conn.truncate_to(cell)
		conn.completed = false
		_mark_occupation(active_color)
		_emit_status()
		queue_redraw()
		return

	# Interpola celdas intermedias para no saltar en arrastres rápidos.
	var path_cells := _cells_between(conn.get_end(), cell)
	for next_cell: Vector2i in path_cells:
		if not _try_step_to(next_cell):
			break


func _cells_between(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var current := from
	# Primero alinear en eje dominante paso a paso (manhattan greedy).
	while current != to and result.size() < grid_size * grid_size:
		var step := Vector2i.ZERO
		if current.x != to.x:
			step.x = 1 if to.x > current.x else -1
		elif current.y != to.y:
			step.y = 1 if to.y > current.y else -1
		current += step
		result.append(current)
	return result


func _try_step_to(cell: Vector2i) -> bool:
	if not is_dragging or active_color == "":
		return false

	var conn: Connection = connections[active_color]
	if conn.cells.is_empty():
		return false

	if conn.contains(cell):
		_clear_color_occupation(active_color)
		conn.truncate_to(cell)
		conn.completed = false
		_mark_occupation(active_color)
		_emit_status()
		queue_redraw()
		return true

	var last := conn.get_end()
	if absi(cell.x - last.x) + absi(cell.y - last.y) != 1:
		return false

	if not _can_enter(cell, active_color):
		invalid_move.emit()
		_play_sfx("INVALID")
		_vibrate(25)
		return false

	conn.append_cell(cell)
	occupied[cell] = active_color
	moves += 1
	moves_changed.emit(moves)

	if endpoints.has(cell) and endpoints[cell] == active_color and cell != conn.get_start():
		conn.completed = true
		is_dragging = false
		# Si se completa la pareja de la pista, limpiar para la siguiente pista.
		if hint_color == active_color:
			hint_color = ""
			hint_timer = 0.0
		pair_connected.emit(active_color)
		_play_sfx("CONNECT")
		_vibrate(18)
		_emit_status()
		_check_completion()
		queue_redraw()
		return false

	_emit_status()
	queue_redraw()
	return true


func _on_release() -> void:
	is_dragging = false
	active_color = ""
	queue_redraw()


func _can_enter(cell: Vector2i, color_name: String) -> bool:
	if occupied.has(cell):
		return false
	if endpoints.has(cell):
		return endpoints[cell] == color_name
	return true


func _clear_color_occupation(color_name: String) -> void:
	var to_remove: Array[Vector2i] = []
	for cell: Vector2i in occupied.keys():
		if occupied[cell] == color_name:
			to_remove.append(cell)
	for cell: Vector2i in to_remove:
		occupied.erase(cell)


func _mark_occupation(color_name: String) -> void:
	var conn: Connection = connections[color_name]
	for cell: Vector2i in conn.cells:
		occupied[cell] = color_name


func get_completed_color_stats() -> Array:
	## Estadísticas reales por color al completar: enlaces (= celdas - 1).
	var stats: Array = []
	for color_name: Variant in GamePalette.COLORS.keys():
		var key := str(color_name)
		if not connections.has(key):
			continue
		var conn: Connection = connections[key]
		var cells := conn.cell_count()
		stats.append({
			"color": key,
			"connections": maxi(0, cells - 1),
			"cells": cells,
		})
	return stats


func get_level_id() -> int:
	return level_id


func _check_completion() -> void:
	if get_remaining_pairs() > 0 or _celebrating:
		return
	just_completed = true
	_celebrating = true
	var final_moves := moves
	# Último nivel neon (99): sin celebración de inflado; la cinemática de era toma el relevo.
	if level_id == BoardTheme.EMOJI_START - 1:
		await get_tree().create_timer(0.4).timeout
		if not is_instance_valid(self):
			return
		level_completed.emit(final_moves)
		return
	var last_color := connect_flash_color if not connect_flash_color.is_empty() else active_color
	_play_completion_celebration(last_color, final_moves)


func _play_completion_celebration(_last_color: String, final_moves: int) -> void:
	_play_sfx("COMPLETE")
	_vibrate(40)
	# Fondo ya pausado al quedar la última pareja.
	var fx_on := SettingsManager != null and SettingsManager.fx_enabled
	var use_boom := fx_on and SettingsManager.ball_boom_enabled
	var use_destroy := fx_on and SettingsManager.board_destroy_enabled

	if use_boom:
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(self) or not _celebrating:
			_set_level_bg_fx_paused(false)
			return
		await _explode_all_endpoint_balls()
		if not is_instance_valid(self) or not _celebrating:
			_set_level_bg_fx_paused(false)
			return
	elif fx_on:
		_inflate_all = true
		_inflate_amount = 1.0
		_inflate_hidden = false
		_ball_fade = 1.0
		queue_redraw()
		var inflate_tw := create_tween()
		inflate_tw.tween_property(self, "_inflate_amount", 1.35, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await inflate_tw.finished
		if not is_instance_valid(self) or not _celebrating:
			_set_level_bg_fx_paused(false)
			return
		var fade_tw := create_tween()
		fade_tw.tween_property(self, "_ball_fade", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fade_tw.tween_callback(func() -> void:
			_inflate_hidden = true
		)
		var pair_count := maxi(1, connections.size())
		var per_end := clampi(int(200.0 / float(pair_count * 2)), 10, 36)
		var per_mid := clampi(int(per_end * 0.55), 6, 20)
		for color_name_variant in connections.keys():
			var color_name := str(color_name_variant)
			var conn: Connection = connections[color_name]
			if conn.cells.is_empty():
				continue
			var color := GamePalette.get_color(color_name)
			_spawn_rising_bubbles(_cell_center(conn.get_start()), color, per_end)
			_spawn_rising_bubbles(_cell_center(conn.get_end()), color, per_end)
			if conn.cells.size() >= 3:
				_spawn_rising_bubbles(
					_cell_center(conn.cells[floori(conn.cells.size() / 2.0)]),
					color,
					per_mid
				)
		await get_tree().create_timer(BUBBLE_CELEBRATION_SEC).timeout
		if not is_instance_valid(self) or not _celebrating:
			_set_level_bg_fx_paused(false)
			return
	else:
		var fade_tw2 := create_tween()
		fade_tw2.tween_property(self, "_ball_fade", 0.0, 0.15)
		fade_tw2.tween_callback(func() -> void:
			_inflate_hidden = true
		)
		await get_tree().create_timer(0.25).timeout
		if not is_instance_valid(self) or not _celebrating:
			_set_level_bg_fx_paused(false)
			return

	if use_destroy:
		await _play_board_destroy_fx()
		if not is_instance_valid(self) or not _celebrating:
			_set_level_bg_fx_paused(false)
			return

	_celebrating = false
	_inflate_color = ""
	_inflate_all = false
	_inflate_hidden = false
	_ball_fade = 1.0
	_set_level_bg_fx_paused(false)
	level_completed.emit(final_moves)


func _explode_all_endpoint_balls() -> void:
	_vibrate(55)
	var prev_clip := clip_contents
	clip_contents = false

	# Quitar bolas y trazos al instante; solo queda la explosión en cada casilla.
	_inflate_color = ""
	_inflate_all = false
	_inflate_amount = 1.0
	_inflate_hidden = true
	_ball_fade = 0.0
	queue_redraw()

	_clear_cartoon_booms()
	# Flipbook 2D: el fuego visible ≈ 95% de la casilla (FX compensa margen del sheet).
	var diameter := cell_size * 0.95
	var cells: Array[Vector2i] = []
	for cell_v: Variant in endpoints.keys():
		cells.append(cell_v as Vector2i)
	var boom_n := cells.size()
	var draw_scale := -1.0
	var dur := LEVEL_COMPLETE_EXPLOSION_SEC
	if FxQuality != null:
		draw_scale = FxQuality.boom_draw_scale(boom_n)
		dur = LEVEL_COMPLETE_EXPLOSION_SEC * FxQuality.boom_duration_scale(boom_n)
	elif BoardDestroyFx.is_mobile_device():
		draw_scale = 0.5 if boom_n <= 6 else (0.35 if boom_n <= 12 else 0.25)
	else:
		draw_scale = 1.0 if boom_n <= 12 else 0.45
	for cell: Vector2i in cells:
		var color_name := str(endpoints[cell])
		var tint := GamePalette.get_color(color_name)
		var fx: CartoonExplosionFx = CartoonExplosionFxScript.new()
		fx.z_index = 50
		add_child(fx)
		fx.setup_at(_cell_center(cell), diameter, tint, draw_scale)
		_cartoon_booms.append(fx)
		fx.start_explosion(dur)

	# Esperar a que termine por completo el boom; luego rotura (sin solape GPU).
	await get_tree().create_timer(dur).timeout
	if not is_instance_valid(self):
		return

	_clear_cartoon_booms()
	clip_contents = prev_clip


## Pregenera la textura de rotura (llamar durante la caída de la bomba en era).
func prepare_era_board_destroy_texture() -> void:
	if not is_instance_valid(self):
		return
	_era_destroy_tex_cache = _build_empty_board_texture()


func clear_era_board_destroy_texture_cache() -> void:
	_era_destroy_tex_cache = null


## Cinemática era (99→100): solo BoardDestroyFx (el boom lo hace EraTransition).
func play_era_board_destroy() -> void:
	if not is_instance_valid(self):
		return
	_celebrating = true
	_vibrate(70)
	_inflate_color = ""
	_inflate_all = false
	_inflate_amount = 1.0
	_inflate_hidden = true
	_ball_fade = 0.0
	queue_redraw()
	await _play_board_destroy_fx(true)


## Tras el boom: textura del tablero (celdas teñidas) + shader de destrucción (una sola vez).
## force: cinemática de era — ignora SettingsManager.fx_enabled.
func _play_board_destroy_fx(force: bool = false) -> void:
	if not force and not SettingsManager.fx_enabled:
		return

	var margin := 6.0
	var board_side := cell_size * float(grid_size)
	var local_rect := Rect2(
		board_origin - Vector2(margin, margin),
		Vector2(board_side + margin * 2.0, board_side + margin * 2.0)
	)
	# Coordenadas globales para que el FX no lo recorte ningún ancestro.
	var global_rect := Rect2(global_position + local_rect.position, local_rect.size)

	var prev_clip := clip_contents
	clip_contents = false
	# Ocultar el tablero real ya, mientras se genera la textura del FX.
	_board_destroy_active = true
	queue_redraw()

	var tex: Texture2D = null
	if force and _era_destroy_tex_cache != null:
		tex = _era_destroy_tex_cache
		_era_destroy_tex_cache = null
	else:
		tex = _build_empty_board_texture()
	if not is_instance_valid(self) or not _celebrating or tex == null:
		_board_destroy_active = false
		_era_destroy_tex_cache = null
		clip_contents = prev_clip
		queue_redraw()
		return

	_clear_board_destroy_fx()
	var fx: BoardDestroyFx = BoardDestroyFxScript.new()
	# Cinemática de era vive a z≈200; forzar por encima para ver la rotura.
	fx.z_index = 220 if force else 80
	fx.top_level = true
	# Hijo del árbol de juego (no del Board) para evitar clip_contents de padres.
	var host: Node = get_parent()
	if host == null:
		host = self
	host.add_child(fx)
	_board_destroy_fx = fx
	# Era + móvil: rotura más barata al solapar con el boom (victoria normal intacta).
	var pieces := BoardDestroyFx.pieces_for_device()
	var draw_scale_override := -1.0
	if force and BoardDestroyFx.is_mobile_device():
		pieces = 16.0
		draw_scale_override = 0.33
	fx.setup(tex, global_rect, Vector2(pieces, pieces), draw_scale_override)
	await fx.play(BOARD_DESTROY_SEC)

	if not is_instance_valid(self):
		return
	_clear_board_destroy_fx()
	# Seguir sin _draw del tablero: si se reactiva aquí, hay 1–2 frames del grid intacto
	# antes del overlay / fundido (cinemática era y victoria normal).
	_board_destroy_active = true
	clip_contents = prev_clip


## Pinta el tablero en una Image para el shatter (más fiable que SubViewport anidado).
## Casillas con bola → color del endpoint; vacías → color aleatorio de paleta (seed estable).
## Overlays semi-transparentes se compositan a opaco y luego fill_rect (rápido).
func _build_empty_board_texture() -> Texture2D:
	var margin := 6
	var board_side_f := cell_size * float(grid_size)
	var side := maxi(8, int(ceili(board_side_f + float(margin) * 2.0)))
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var ox := margin
	var oy := margin
	var bs := maxi(1, int(round(board_side_f)))
	var lid := level_id

	# Sombra (anillo) + fondo del tablero.
	_img_paint_opaque(img, Rect2i(ox - 6, oy - 6, bs + 12, bs + 12), Color(0.05, 0.05, 0.08, 1.0))
	var fill := BoardTheme.board_fill(lid)
	var board_col := _composite_over(Color(fill.r, fill.g, fill.b, 1.0), BoardTheme.board_tint(lid))
	_img_paint_opaque(img, Rect2i(ox, oy, bs, bs), board_col)

	var inset := maxi(1, int(round(cell_size * 0.08)))
	var cell_px := maxi(1, int(round(cell_size)))
	var cell_col := _composite_over(board_col, BoardTheme.cell_fill(lid))
	# Tablero con colores: casilla ≠ bola. Off: mismo color de casilla del tema.
	for y: int in range(grid_size):
		for x: int in range(grid_size):
			var cx := ox + x * cell_px + inset
			var cy := oy + y * cell_px + inset
			var cw := maxi(1, cell_px - inset * 2)
			var cell := Vector2i(x, y)
			var painted: Color
			if _uses_colored_board():
				painted = _cell_display_color(cell, cell_col)
			else:
				painted = cell_col
			_img_paint_opaque(img, Rect2i(cx, cy, cw, cw), painted)

	var line_col := _composite_over(cell_col, BoardTheme.grid_line(lid))
	var lw := 2
	for i: int in range(grid_size + 1):
		var px := ox + i * cell_px
		var py := oy + i * cell_px
		_img_paint_opaque(img, Rect2i(px, oy, lw, bs), line_col)
		_img_paint_opaque(img, Rect2i(ox, py, bs, lw), line_col)

	var border := BoardTheme.board_border(lid)
	var bw := 3 if BoardTheme.kind_for_level(lid) == BoardTheme.Kind.CONTRAST else 2
	_img_stroke_rect(img, Rect2i(ox - 2, oy - 2, bs + 4, bs + 4), border, bw)
	_img_stroke_rect(img, Rect2i(ox - 5, oy - 5, bs + 10, bs + 10), BoardTheme.board_border_secondary(lid), 1)

	return ImageTexture.create_from_image(img)


func _uses_colored_board() -> bool:
	if LevelManager != null and LevelManager.current_mode == LevelManager.MODE_CHRONO:
		return true
	return SettingsManager != null and SettingsManager.colored_board_enabled


## Color de casilla (ajuste activo): nunca igual al de la bola; seed por nivel+celda.
func _cell_display_color(cell: Vector2i, base_cell: Color) -> Color:
	var tint := _pick_cell_palette_color(cell, true)
	return _composite_over(base_cell, Color(tint.r, tint.g, tint.b, 0.62))


## Tint del shatter con ajuste off (endpoint = bola; vacía = aleatorio).
func _shatter_cell_tint(cell: Vector2i, fallback: Color) -> Color:
	if endpoints.has(cell):
		return GamePalette.get_color(str(endpoints[cell]))
	return _pick_cell_palette_color(cell, false) if GamePalette.color_names().size() > 0 else fallback


func _pick_cell_palette_color(cell: Vector2i, avoid_ball: bool) -> Color:
	var names: Array[String] = GamePalette.color_names()
	if names.is_empty():
		return Color.WHITE
	var forbid := ""
	if avoid_ball and endpoints.has(cell):
		forbid = str(endpoints[cell])
	var pool: Array[String] = []
	for n: String in names:
		if n != forbid:
			pool.append(n)
	if pool.is_empty():
		pool = names
	var seed_i := (
		level_id * 73856093
		+ cell.x * 19349663
		+ cell.y * 83492791
		+ _chaos_tint_salt * 2654435761
		+ _urgency_tick * 97
	)
	# Cada segundo de urgencia rota el color de cada casilla.
	var idx := posmod(seed_i + _urgency_tick * (cell.x * 3 + cell.y * 5 + 1), pool.size())
	return GamePalette.get_color(pool[idx])


## Crazy: cambia el color de todas las casillas (un tick = un segundo de cuenta atrás).
func urgency_recolor_tick(seconds_left: int) -> void:
	_urgency_tick = maxi(0, seconds_left)
	_chaos_tint_salt = int(Time.get_ticks_msec()) ^ (_urgency_tick * 2654435761)
	queue_redraw()


func clear_urgency_recolor() -> void:
	if _urgency_tick == 0:
		return
	_urgency_tick = 0
	queue_redraw()


## Aplica overlay (con su alpha) sobre base opaca → color opaco final.
func _composite_over(base: Color, overlay: Color) -> Color:
	var a := clampf(overlay.a, 0.0, 1.0)
	if a <= 0.001:
		return Color(base.r, base.g, base.b, 1.0)
	var out := Color(base.r, base.g, base.b, 1.0).lerp(Color(overlay.r, overlay.g, overlay.b, 1.0), a)
	return Color(out.r, out.g, out.b, 1.0)


func _img_paint_opaque(img: Image, rect: Rect2i, color: Color) -> void:
	var clipped := rect.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	img.fill_rect(clipped, Color(color.r, color.g, color.b, 1.0))


## Pinta en la Image mezclando alpha (como draw_rect en el canvas).
func _img_paint(img: Image, rect: Rect2i, color: Color) -> void:
	var clipped := rect.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	var a := clampf(color.a, 0.0, 1.0)
	if a <= 0.001:
		return
	if a >= 0.999:
		img.fill_rect(clipped, Color(color.r, color.g, color.b, 1.0))
		return
	var src := Color(color.r, color.g, color.b, 1.0)
	for y: int in range(clipped.position.y, clipped.position.y + clipped.size.y):
		for x: int in range(clipped.position.x, clipped.position.x + clipped.size.x):
			var base := img.get_pixel(x, y)
			var out := base.lerp(src, a)
			out.a = clampf(base.a + a * (1.0 - base.a), 0.0, 1.0)
			# Mantener RGB opaco del tablero: no dejar alpha bajo en el trozo.
			if out.a > 0.01:
				out = Color(out.r, out.g, out.b, 1.0)
			img.set_pixel(x, y, out)


func _img_stroke_rect(img: Image, rect: Rect2i, color: Color, width: int) -> void:
	var w := maxi(1, width)
	var opaque := Color(color.r, color.g, color.b, 1.0)
	_img_paint_opaque(img, Rect2i(rect.position.x, rect.position.y, rect.size.x, w), opaque)
	_img_paint_opaque(img, Rect2i(rect.position.x, rect.position.y + rect.size.y - w, rect.size.x, w), opaque)
	_img_paint_opaque(img, Rect2i(rect.position.x, rect.position.y, w, rect.size.y), opaque)
	_img_paint_opaque(img, Rect2i(rect.position.x + rect.size.x - w, rect.position.y, w, rect.size.y), opaque)


func _clear_board_destroy_fx() -> void:
	if _board_destroy_fx != null and is_instance_valid(_board_destroy_fx):
		_board_destroy_fx.queue_free()
	_board_destroy_fx = null
	_era_destroy_tex_cache = null


func _set_level_bg_fx_paused(paused: bool) -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group("level_bg_fx"):
		if is_instance_valid(node) and node.has_method("set_fx_paused"):
			node.call("set_fx_paused", paused)


func _clear_cartoon_booms() -> void:
	for node: Node in _cartoon_booms:
		if is_instance_valid(node):
			node.queue_free()
	_cartoon_booms.clear()


func _spawn_rising_bubbles(origin: Vector2, color: Color, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in range(count):
		if _particles.size() > 480:
			break
		var drift := rng.randf_range(-55.0, 55.0)
		var up := rng.randf_range(90.0, 220.0)
		_particles.append({
			"kind": "bubble",
			"pos": origin + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-8.0, 8.0)),
			"vel": Vector2(drift, -up),
			"phase": rng.randf_range(0.0, TAU),
			"life": rng.randf_range(1.1, 1.8),
			"max_life": 1.8,
			"color": color if rng.randf() > 0.3 else color.lightened(0.25),
			"size": rng.randf_range(cell_size * 0.12, cell_size * 0.28),
		})


func _audio() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("AudioManager")


func _play_sfx(sfx_name: String) -> void:
	var audio := _audio()
	if audio == null:
		return
	match sfx_name:
		"SELECT":
			audio.play(audio.Sfx.SELECT)
		"CONNECT":
			audio.play(audio.Sfx.CONNECT)
		"COMPLETE":
			audio.play(audio.Sfx.COMPLETE)
		"INVALID":
			audio.play(audio.Sfx.INVALID)
		"HINT":
			audio.play(audio.Sfx.HINT)


func _vibrate(duration_ms: int) -> void:
	var audio := _audio()
	if audio == null:
		return
	audio.vibrate(duration_ms)


func _emit_status() -> void:
	moves_changed.emit(moves)
	var remaining := get_remaining_pairs()
	pairs_changed.emit(remaining, get_total_pairs())
	# Congela el fondo al quedar 1 pareja; si el jugador deshace y vuelven a quedar más, reanuda.
	if remaining == 1:
		_set_level_bg_fx_paused(true)
	elif remaining > 1 and not _celebrating:
		_set_level_bg_fx_paused(false)


func _pos_to_cell(local_pos: Vector2) -> Vector2i:
	var relative := local_pos - board_origin
	if relative.x < 0.0 or relative.y < 0.0:
		return Vector2i(-1, -1)
	return Vector2i(int(relative.x / cell_size), int(relative.y / cell_size))


func _cell_center(cell: Vector2i) -> Vector2:
	return board_origin + Vector2((float(cell.x) + 0.5) * cell_size, (float(cell.y) + 0.5) * cell_size)


func get_cell_center_global(cell: Vector2i) -> Vector2:
	return get_global_transform() * _cell_center(cell)


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size and cell.y < grid_size


func _draw() -> void:
	if _board_destroy_active:
		return
	_draw_background()
	_draw_grid()
	_draw_paths()
	_draw_endpoints()
	_draw_hint()
	_draw_fx()
	if complete_flash > 0.0:
		_draw_completion_flash()
	if invalid_flash > 0.0:
		_draw_invalid_flash()


func _draw_background() -> void:
	var board_side := cell_size * float(grid_size)
	var rect := Rect2(board_origin, Vector2(board_side, board_side))
	draw_rect(rect.grow(6.0), Color(0, 0, 0, 0.35), true)
	draw_rect(rect, BoardTheme.board_fill(level_id), true)
	draw_rect(rect, BoardTheme.board_tint(level_id), true)
	var border := BoardTheme.board_border(level_id)
	var border_w := 3.0 if BoardTheme.kind_for_level(level_id) == BoardTheme.Kind.CONTRAST else 2.5
	draw_rect(rect.grow(2.0), border, false, border_w)
	draw_rect(rect.grow(5.0), BoardTheme.board_border_secondary(level_id), false, 1.5)


func _draw_grid() -> void:
	var board_side := cell_size * float(grid_size)
	var line_color := BoardTheme.grid_line(level_id)
	var inset := cell_size * 0.08
	var cell_color := BoardTheme.cell_fill(level_id)
	for y: int in range(grid_size):
		for x: int in range(grid_size):
			var cell_rect := Rect2(
				board_origin + Vector2(float(x) * cell_size + inset, float(y) * cell_size + inset),
				Vector2(cell_size - inset * 2.0, cell_size - inset * 2.0)
			)
			var fill := (
				_cell_display_color(Vector2i(x, y), cell_color)
				if _uses_colored_board()
				else cell_color
			)
			draw_rect(cell_rect, fill, true)
	var line_w := 2.0 if BoardTheme.kind_for_level(level_id) == BoardTheme.Kind.CONTRAST else 1.6
	# Ligero inset para que el borde del tablero no tape las primeras/últimas líneas.
	var edge := line_w * 0.5 + 1.0
	var x0 := board_origin.x + edge
	var y0 := board_origin.y + edge
	var x1 := board_origin.x + board_side - edge
	var y1 := board_origin.y + board_side - edge
	for i: int in range(grid_size + 1):
		var x := clampf(board_origin.x + float(i) * cell_size, x0, x1)
		var y := clampf(board_origin.y + float(i) * cell_size, y0, y1)
		draw_line(Vector2(x, y0), Vector2(x, y1), line_color, line_w, true)
		draw_line(Vector2(x0, y), Vector2(x1, y), line_color, line_w, true)


func _draw_paths() -> void:
	# Al ocultar las bolas en la celebración, también se ocultan los caminos.
	if _inflate_hidden or _ball_fade <= 0.001:
		return
	var fade := clampf(_ball_fade, 0.0, 1.0)
	var emoji_mode := BoardTheme.uses_emoji(level_id)
	for color_name: Variant in connections.keys():
		var key := str(color_name)
		var conn: Connection = connections[key]
		if conn.cells.size() < 2:
			continue
		var color := GamePalette.get_color(key)
		var width := cell_size * (
			BoardTheme.EMOJI_PATH_CELL_FRACTION if emoji_mode else 0.30
		)
		var boost := 1.0
		if connect_flash > 0.0 and key == connect_flash_color:
			boost = 1.0 + connect_flash * 0.8

		if emoji_mode:
			_draw_emoji_era_path(conn, color, width, boost, fade)
			if is_dragging and key == active_color:
				var tip := _cell_center(conn.get_end())
				draw_circle(tip, width * 0.52, Color(1, 1, 1, 0.5 * fade))
			continue

		# Halo exterior.
		var halo := Color(color.r, color.g, color.b, 0.22 * boost * fade)
		var body := Color(color.r, color.g, color.b, color.a * fade)
		# Borde fino oscuro: el trazo se lee sobre cualquier color de casilla.
		var outline_w := width + maxf(1.5, cell_size * 0.045)
		var outline := Color(0.04, 0.05, 0.12, 0.82 * fade)
		for i: int in range(1, conn.cells.size()):
			var a := _cell_center(conn.cells[i - 1])
			var b := _cell_center(conn.cells[i])
			draw_line(a, b, outline, outline_w, true)
			draw_circle(a, outline_w * 0.5, outline)
			draw_circle(b, outline_w * 0.5, outline)

		for i: int in range(1, conn.cells.size()):
			var a := _cell_center(conn.cells[i - 1])
			var b := _cell_center(conn.cells[i])
			draw_line(a, b, halo, width * 1.55, true)
			draw_circle(a, width * 0.72, halo)
			draw_circle(b, width * 0.72, halo)

		# Núcleo.
		for i: int in range(1, conn.cells.size()):
			var a := _cell_center(conn.cells[i - 1])
			var b := _cell_center(conn.cells[i])
			draw_line(a, b, body, width, true)
			draw_circle(a, width * 0.5, body)
			draw_circle(b, width * 0.5, body)

		# Brillo central.
		var core := Color(1, 1, 1, 0.28 * boost * fade)
		for i: int in range(1, conn.cells.size()):
			var a := _cell_center(conn.cells[i - 1])
			var b := _cell_center(conn.cells[i])
			draw_line(a, b, core, width * 0.28, true)

		# Extremo activo más brillante.
		if is_dragging and key == active_color:
			var tip := _cell_center(conn.get_end())
			draw_circle(tip, width * 0.85, Color(color.r, color.g, color.b, 0.35))
			draw_circle(tip, width * 0.42, Color(1, 1, 1, 0.55))


func _draw_emoji_era_path(conn: Connection, color: Color, width: float, boost: float, fade: float) -> void:
	if conn.cells.size() < 2:
		return
	# Un solo grosor opaco (sin halo semitransparente: hacía que unos colores
	# se vieran más anchos que otros). Rectángulos en rejilla = esquinas llenas.
	var body := Color(color.r, color.g, color.b, fade)
	if boost > 1.0:
		body = body.lightened(clampf((boost - 1.0) * 0.25, 0.0, 0.35))
	var core := Color(1, 1, 1, 0.22 * fade)
	var outline_w := width + maxf(1.5, cell_size * 0.045)
	var outline := Color(0.04, 0.05, 0.12, 0.82 * fade)
	var half := width * 0.5
	var half_out := outline_w * 0.5
	var core_w := width * 0.34
	var half_core := core_w * 0.5
	for i in range(conn.cells.size()):
		var p := _cell_center(conn.cells[i])
		draw_rect(Rect2(p.x - half_out, p.y - half_out, outline_w, outline_w), outline, true)
		draw_rect(Rect2(p.x - half, p.y - half, width, width), body, true)
		draw_rect(Rect2(p.x - half_core, p.y - half_core, core_w, core_w), core, true)
	for i in range(1, conn.cells.size()):
		var a := _cell_center(conn.cells[i - 1])
		var b := _cell_center(conn.cells[i])
		_draw_grid_path_segment(a, b, outline_w, outline)
		_draw_grid_path_segment(a, b, width, body)
		_draw_grid_path_segment(a, b, core_w, core)


func _draw_grid_path_segment(a: Vector2, b: Vector2, thickness: float, color: Color) -> void:
	var half := thickness * 0.5
	if absf(a.y - b.y) < 0.5:
		var x0 := minf(a.x, b.x)
		var x1 := maxf(a.x, b.x)
		draw_rect(Rect2(x0, a.y - half, x1 - x0, thickness), color, true)
	elif absf(a.x - b.x) < 0.5:
		var y0 := minf(a.y, b.y)
		var y1 := maxf(a.y, b.y)
		draw_rect(Rect2(a.x - half, y0, thickness, y1 - y0), color, true)
	else:
		draw_line(a, b, color, thickness, true)


func _draw_endpoints() -> void:
	if _inflate_hidden or _ball_fade <= 0.001:
		return
	var fade := clampf(_ball_fade, 0.0, 1.0)
	var emoji_mode := BoardTheme.uses_emoji(level_id)
	var contrast := BoardTheme.kind_for_level(level_id) == BoardTheme.Kind.CONTRAST
	for pos: Vector2i in endpoints.keys():
		var color_name: String = endpoints[pos]
		var inflating := _inflate_all or color_name == _inflate_color
		var color := GamePalette.get_color(color_name)
		color.a *= fade
		var center := _cell_center(pos)
		# Radio sólido ~22–26% de cell_size (diámetro ~44–52%).
		# Modo Crazy: 95% del pad de color (mismo inset 0.08 que _draw_grid), no del pitch completo.
		var crazy := LevelManager != null and LevelManager.current_mode == LevelManager.MODE_CHRONO
		var radius: float
		if crazy:
			var pad := cell_size * (1.0 - 0.08 * 2.0)
			radius = pad * 0.95 * 0.5
		else:
			radius = cell_size * (
				0.26 if BoardTheme.shows_shapes(level_id) else (0.24 if contrast else 0.22)
			)
		var conn: Connection = connections[color_name]
		var pulse_amp := 0.02 if crazy else (0.05 if not conn.completed else 0.02)
		if crazy and conn.completed:
			pulse_amp = 0.01
		var pulse := 1.0 + sin(pulse_time * 2.8) * pulse_amp
		# Ayuda visual: al seleccionar una bola, resalta también su pareja.
		if (
			SettingsManager.visual_help_enabled
			and color_name == active_color
			and is_dragging
		):
			pulse *= 1.04 if crazy else 1.08
		if connect_flash > 0.0 and color_name == connect_flash_color:
			pulse *= 1.0 + connect_flash * (0.12 if crazy else 0.28)
		if inflating:
			pulse *= _inflate_amount

		if emoji_mode:
			# Emoji dentro de la casilla, no a tamaño completo de celda.
			_draw_endpoint_emoji(center, color_name, pulse, fade)
		elif crazy:
			# Sin halo: el cuerpo ya llena el 95% del pad; anillo fino dentro.
			draw_circle(center, radius * pulse, color)
			var ring_w := 2.2
			draw_arc(center, radius * pulse, 0.0, TAU, 40, Color(1, 1, 1, 0.45 * fade), ring_w, true)
			if BoardTheme.shows_shapes(level_id):
				ColorShapesScript.draw_on_ball(self, center, radius * pulse, GamePalette.shape_for(color_name), color)
		else:
			# Halo contenido: no debe llegar al borde de la casilla en juego normal.
			draw_circle(center, radius * 1.45 * pulse, Color(color.r, color.g, color.b, (0.12 if not contrast else 0.2) * fade))
			draw_circle(center, radius * 1.2 * pulse, Color(color.r, color.g, color.b, (0.28 if not contrast else 0.4) * fade))
			draw_circle(center, radius * pulse, color)
			var ring_w := 3.0 if contrast else 2.2
			draw_arc(center, radius * 1.04 * pulse, 0.0, TAU, 40, Color(1, 1, 1, (0.55 if contrast else 0.45) * fade), ring_w, true)
			# Sin brillo si hay figura: ese punto se ve detrás del icono.
			if not contrast and not BoardTheme.shows_shapes(level_id):
				var highlight := center + Vector2(-radius * 0.28, -radius * 0.28)
				draw_circle(highlight, radius * 0.24, Color(1, 1, 1, 0.42 * fade))
			if BoardTheme.shows_shapes(level_id):
				ColorShapesScript.draw_on_ball(self, center, radius * pulse, GamePalette.shape_for(color_name), color)

		if conn.completed and not emoji_mode:
			if crazy:
				draw_arc(center, radius * pulse, 0.0, TAU, 36, Color(1, 1, 1, 0.7 * fade), 2.5, true)
			else:
				draw_arc(center, radius * 1.18 * pulse, 0.0, TAU, 36, Color(1, 1, 1, 0.7 * fade), 3.0, true)


func _get_emoji_font() -> Font:
	if _emoji_font != null:
		return _emoji_font
	var system := SystemFont.new()
	system.font_names = PackedStringArray([
		"Segoe UI Emoji",
		"Apple Color Emoji",
		"Noto Color Emoji",
		"Segoe UI Symbol",
	])
	system.allow_system_fallback = true
	_emoji_font = system
	return _emoji_font


func _draw_endpoint_emoji(center: Vector2, color_name: String, pulse: float, fade: float = 1.0) -> void:
	var font := _get_emoji_font()
	if font == null:
		return
	var emoji := BoardTheme.emoji_for(color_name)
	# Medir a tamaño fijo y escalar (margen con la rejilla).
	var base_size := 128
	var measured := font.get_string_size(emoji, HORIZONTAL_ALIGNMENT_LEFT, -1, base_size)
	if measured.x < 1.0:
		measured.x = float(base_size)
	if measured.y < 1.0:
		measured.y = float(base_size)
	var target := cell_size * BoardTheme.EMOJI_CELL_FRACTION * pulse
	var scale_f := target / maxf(measured.x, measured.y)
	draw_set_transform(center, 0.0, Vector2(scale_f, scale_f))
	var local := Vector2(
		-measured.x * 0.5,
		-measured.y * 0.5 + font.get_ascent(base_size)
	)
	draw_string(font, local, emoji, HORIZONTAL_ALIGNMENT_LEFT, -1, base_size, Color(1, 1, 1, fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_hint() -> void:
	if hint_color.is_empty() or hint_timer <= 0.0:
		return
	var pts := _hint_path_centers()
	if pts.size() < 2:
		return
	var color := GamePalette.get_color(hint_color)
	var fade := clampf(hint_timer / HINT_DURATION, 0.0, 1.0)
	var breathe := 0.88 + 0.12 * sin(pulse_time * 1.4)
	var base_a := 0.22 * breathe * (0.35 + 0.65 * fade)
	var emoji_mode := BoardTheme.uses_emoji(level_id)
	var w_body := cell_size * (
		BoardTheme.EMOJI_PATH_CELL_FRACTION if emoji_mode else 0.30
	)
	var body := Color(color.r, color.g, color.b, base_a)
	# Con tablero de colores: borde oscuro para que la pista se lea.
	var outline_on := _uses_colored_board()
	var outline_w := w_body + maxf(1.5, cell_size * 0.045)
	var outline := Color(0.04, 0.05, 0.12, clampf(base_a * 2.4, 0.35, 0.75))
	if emoji_mode:
		var half := w_body * 0.5
		var half_out := outline_w * 0.5
		if outline_on:
			for p in pts:
				draw_rect(Rect2(p.x - half_out, p.y - half_out, outline_w, outline_w), outline, true)
			for i in range(1, pts.size()):
				_draw_grid_path_segment(pts[i - 1], pts[i], outline_w, outline)
		for p in pts:
			draw_rect(Rect2(p.x - half, p.y - half, w_body, w_body), body, true)
		for i in range(1, pts.size()):
			_draw_grid_path_segment(pts[i - 1], pts[i], w_body, body)
		return
	var w_halo := w_body * 1.26
	var w_core := w_body * 0.34
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		if outline_on:
			draw_line(a, b, outline, outline_w, true)
			draw_circle(a, outline_w * 0.5, outline)
			draw_circle(b, outline_w * 0.5, outline)
		draw_line(a, b, Color(1, 1, 1, base_a * 0.28), w_halo, true)
		draw_line(a, b, Color(color.r, color.g, color.b, base_a * 0.55), w_body, true)
		draw_line(a, b, Color(1, 0.98, 0.92, base_a * 0.45), w_core, true)


func _draw_completion_flash() -> void:
	var alpha := complete_flash / 1.8 * 0.22
	var board_side := cell_size * float(grid_size)
	draw_rect(Rect2(board_origin, Vector2(board_side, board_side)), Color(GamePalette.ACCENT.r, GamePalette.ACCENT.g, GamePalette.ACCENT.b, alpha), true)


func _draw_invalid_flash() -> void:
	var alpha := invalid_flash * 0.2
	var board_side := cell_size * float(grid_size)
	draw_rect(Rect2(board_origin, Vector2(board_side, board_side)), Color(GamePalette.DANGER.r, GamePalette.DANGER.g, GamePalette.DANGER.b, alpha), true)


func _on_pair_connected_fx(color_name: String) -> void:
	connect_flash_color = color_name
	connect_flash = 1.0
	if not SettingsManager.fx_enabled:
		return
	var conn: Connection = connections[color_name]
	if conn.cells.is_empty():
		return
	var mid := _cell_center(conn.cells[floori(conn.cells.size() / 2.0)])
	_spawn_burst(mid, GamePalette.get_color(color_name), 14)
	_spawn_ripple(mid, GamePalette.get_color(color_name))
	var a := _cell_center(conn.get_start())
	var b := _cell_center(conn.get_end())
	_spawn_burst(a, GamePalette.get_color(color_name), 8)
	_spawn_burst(b, GamePalette.get_color(color_name), 8)


func _on_invalid_fx() -> void:
	invalid_flash = 1.0


func _on_path_started_fx(color_name: String) -> void:
	if not SettingsManager.fx_enabled:
		return
	var conn: Connection = connections[color_name]
	if conn.cells.is_empty():
		return
	_spawn_ripple(_cell_center(conn.get_start()), GamePalette.get_color(color_name))


func _spawn_burst(origin: Vector2, color: Color, count: int) -> void:
	if _particles.size() > 160:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in range(count):
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(40.0, 140.0)
		_particles.append({
			"pos": origin,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": rng.randf_range(0.25, 0.55),
			"max_life": 0.55,
			"color": color,
			"size": rng.randf_range(2.5, 5.5),
		})


func _spawn_ripple(origin: Vector2, color: Color) -> void:
	_ripples.append({
		"pos": origin,
		"life": 0.45,
		"max_life": 0.45,
		"color": color,
	})


func _update_fx(delta: float) -> void:
	var next_p: Array[Dictionary] = []
	for p: Dictionary in _particles:
		var life: float = p["life"] - delta
		if life <= 0.0:
			continue
		var pos: Vector2 = p["pos"]
		var vel: Vector2 = p["vel"]
		if str(p.get("kind", "")) == "bubble":
			var phase: float = float(p.get("phase", 0.0))
			pos.x += sin(pulse_time * 4.0 + phase) * 28.0 * delta
			pos += vel * delta
			vel.y *= 0.995
			vel.x *= 0.98
		else:
			pos += vel * delta
			vel *= 0.92
		p["pos"] = pos
		p["vel"] = vel
		p["life"] = life
		next_p.append(p)
	_particles = next_p

	var next_r: Array[Dictionary] = []
	for r: Dictionary in _ripples:
		var life: float = r["life"] - delta
		if life <= 0.0:
			continue
		r["life"] = life
		next_r.append(r)
	_ripples = next_r


func _draw_fx() -> void:
	for r: Dictionary in _ripples:
		var t := 1.0 - float(r["life"]) / float(r["max_life"])
		var color: Color = r["color"]
		var radius := lerpf(cell_size * 0.15, cell_size * 0.9, t)
		var alpha := (1.0 - t) * 0.45
		draw_arc(r["pos"], radius, 0.0, TAU, 36, Color(color.r, color.g, color.b, alpha), 2.5, true)

	for p: Dictionary in _particles:
		var t := float(p["life"]) / float(p["max_life"])
		var color: Color = p["color"]
		var radius := float(p["size"]) * (0.55 + 0.45 * t)
		if str(p.get("kind", "")) == "bubble":
			var alpha := 0.75 * t
			draw_circle(p["pos"], radius * 1.15, Color(color.r, color.g, color.b, alpha * 0.25))
			draw_circle(p["pos"], radius, Color(color.r, color.g, color.b, alpha))
			draw_circle(p["pos"] + Vector2(-radius * 0.28, -radius * 0.3), radius * 0.28, Color(1, 1, 1, 0.55 * t))
			draw_arc(p["pos"], radius * 0.92, 0.0, TAU, 24, Color(1, 1, 1, 0.35 * t), maxf(1.2, radius * 0.12), true)
		else:
			draw_circle(p["pos"], radius, Color(color.r, color.g, color.b, 0.85 * t))
