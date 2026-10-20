class_name SandboxBoard
extends Control

## Tablero Sandbox: arena sin rejilla, rocas y surcos grabados (estilo SandBoard).

const ColorShapesScript := preload("res://scripts/color_shapes.gd")
const CartoonExplosionFxScript := preload("res://scripts/cartoon_explosion_fx.gd")

const LEVEL_COMPLETE_EXPLOSION_SEC := 3.0
const HINT_DURATION := 20.0
const HINT_PATH_FRACTION := 0.7

signal moves_changed(moves: int)
signal pairs_changed(remaining: int, total: int)
signal level_completed(moves: int)
signal solution_revealed
signal invalid_move
signal pair_connected(color_name: String)
signal path_started(color_name: String)

const SAMPLE_DIST := 4.0
const ROCK_RADIUS_RATIO := 0.032
const HIT_RADIUS_RATIO := 0.042
const GROOVE_WIDTH := 9.0
const MARGIN := 18.0
const SAND_TEX_SIZE := 256
## Tamaño en pantalla de cada baldosa de arena (grano estable al redimensionar).
const SAND_TILE_PX := 160.0
## Surco en textura (estilo SandBoard, un poco más estrecho).
const GROOVE_TEX_MIN := 256
const GROOVE_TEX_MAX := 512
const GROOVE_BRUSH_SIZE := 22.0
const GROOVE_DEPTH := 0.9
const GROOVE_EDGE_IRREG := 0.55
const GROOVE_PARTICLES_PER_STAMP := 4
const GROOVE_PARTICLE_LIFE := 0.55
const GROOVE_PARTICLE_SPEED := 78.0

var level_id: int = 1
var moves: int = 0
var just_completed: bool = false

var _rocks: Array[Dictionary] = [] # {color, norm: Vector2}
var _solution: Dictionary = {} # color -> PackedVector2Array (coords normalizadas)
var _grooves: Dictionary = {} # color -> PackedVector2Array (coords normalizadas 0-1)
var _completed: Dictionary = {} # color -> bool
var _active_color: String = ""
var _active_start_idx: int = -1
var _stroke_norm: PackedVector2Array = PackedVector2Array() # trazo activo normalizado
var _drawing: bool = false
var _error_flash: float = 0.0
var _error_stroke_norm: PackedVector2Array = PackedVector2Array()
var _hint_color: String = ""
var _hint_timer: float = 0.0
var _hinted_colors: Array[String] = []
var _pulse_time: float = 0.0
var _celebrating: bool = false
var _revealing: bool = false
var _play_rect: Rect2 = Rect2()
var _rng := RandomNumberGenerator.new()
var _sand_tex: ImageTexture
var _sand_tex_level: int = -1
var _groove_image: Image
var _groove_texture: ImageTexture
var _groove_tex_side: int = 0
var _groove_noise := FastNoiseLite.new()
var _sand_particles: Array[Dictionary] = []
var _cartoon_booms: Array[Node] = []
var _hide_rocks: bool = false
var _hide_grooves: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_rng.randomize()
	_groove_noise.seed = _rng.randi()
	_groove_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_groove_noise.frequency = 0.025
	resized.connect(_relayout)
	set_process(true)


func _process(delta: float) -> void:
	var dirty := false
	_pulse_time += delta
	if _error_flash > 0.0:
		_error_flash = maxf(0.0, _error_flash - delta)
		if _error_flash <= 0.0:
			_error_stroke_norm.clear()
		dirty = true
	if _hint_timer > 0.0:
		_hint_timer = maxf(0.0, _hint_timer - delta)
		if _hint_timer <= 0.0:
			_hint_color = ""
		dirty = true
	if _drawing and SettingsManager.visual_help_enabled:
		dirty = true
	for i in range(_sand_particles.size() - 1, -1, -1):
		var p: Dictionary = _sand_particles[i]
		p["life"] = float(p["life"]) - delta
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		var vel: Vector2 = p["vel"]
		vel = vel * (1.0 - minf(delta * 2.0, 0.8))
		p["vel"] = vel
		_sand_particles[i] = p
		if float(p["life"]) <= 0.0:
			_sand_particles.remove_at(i)
		dirty = true
	if dirty:
		queue_redraw()


func setup_level(level_data: Dictionary) -> void:
	level_id = int(level_data.get("id", 1))
	moves = 0
	just_completed = false
	_celebrating = false
	_revealing = false
	_grooves.clear()
	_completed.clear()
	_rocks.clear()
	_solution.clear()
	_clear_stroke()
	_error_flash = 0.0
	_error_stroke_norm.clear()
	_hint_color = ""
	_hint_timer = 0.0
	_hinted_colors.clear()

	var raw: Array = level_data.get("rocks", [])
	for rock_v: Variant in raw:
		if typeof(rock_v) != TYPE_DICTIONARY:
			continue
		var rock: Dictionary = rock_v
		var color := str(rock.get("color", ""))
		if color.is_empty():
			continue
		_rocks.append({
			"color": color,
			"norm": Vector2(float(rock.get("x", 0.5)), float(rock.get("y", 0.5))),
		})
		_completed[color] = false

	_load_solution(level_data)

	_rebuild_sand_texture()
	_clear_groove_texture()
	_hide_rocks = false
	_hide_grooves = false
	_clear_cartoon_booms()
	_relayout()
	_emit_status()
	queue_redraw()


func reset_level() -> void:
	for color_v: Variant in _completed.keys():
		_completed[str(color_v)] = false
	_grooves.clear()
	moves = 0
	just_completed = false
	_celebrating = false
	_clear_groove_texture()
	_hide_rocks = false
	_hide_grooves = false
	_clear_cartoon_booms()
	_clear_stroke()
	_error_flash = 0.0
	_error_stroke_norm.clear()
	_hint_color = ""
	_hint_timer = 0.0
	_hinted_colors.clear()
	_emit_status()
	queue_redraw()


func is_celebrating() -> bool:
	return _celebrating or _revealing


func show_hint() -> bool:
	if just_completed:
		return false
	var color := _next_hint_color()
	if color.is_empty():
		return false
	var path: PackedVector2Array = _solution.get(color, PackedVector2Array())
	if path.size() < 2:
		return false
	_hint_color = color
	_hint_timer = HINT_DURATION
	if not _hinted_colors.has(color):
		_hinted_colors.append(color)
	_play_sfx("HINT")
	queue_redraw()
	return true


func _next_hint_color() -> String:
	for color_v: Variant in _completed.keys():
		var color := str(color_v)
		if bool(_completed.get(color, false)):
			continue
		if _hinted_colors.has(color):
			continue
		return color
	return ""


func _hint_path_screen_points() -> PackedVector2Array:
	if _hint_color.is_empty() or _hint_timer <= 0.0:
		return PackedVector2Array()
	var path: PackedVector2Array = _solution.get(_hint_color, PackedVector2Array())
	if path.size() < 2:
		return PackedVector2Array()
	var count := maxi(2, int(ceil(float(path.size()) * HINT_PATH_FRACTION)))
	count = mini(count, path.size())
	var pts := PackedVector2Array()
	pts.resize(count)
	for i in range(count):
		pts[i] = _to_screen(path[i])
	return pts


func _draw_hint_path() -> void:
	if _hint_color.is_empty() or _hint_timer <= 0.0:
		return
	var pts := _hint_path_screen_points()
	if pts.size() < 2:
		return
	var color := GamePalette.get_color(_hint_color)
	var fade := clampf(_hint_timer / HINT_DURATION, 0.0, 1.0)
	var breathe := 0.88 + 0.12 * sin(_pulse_time * 1.4)
	var base_a := 0.16 * breathe * (0.35 + 0.65 * fade)
	var w_outer := GROOVE_WIDTH * 1.35
	var w_mid := GROOVE_WIDTH * 0.72
	var w_core := GROOVE_WIDTH * 0.28
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		draw_line(a, b, Color(1, 1, 1, base_a * 0.28), w_outer, true)
		draw_line(a, b, Color(color.r, color.g, color.b, base_a * 0.48), w_mid, true)
		draw_line(a, b, Color(1, 0.98, 0.92, base_a * 0.62), w_core, true)
	draw_circle(pts[0], w_outer * 0.42, Color(1, 1, 1, base_a * 0.22))
	draw_circle(pts[pts.size() - 1], w_mid * 0.55, Color(color.r, color.g, color.b, base_a * 0.38))


func reveal_solution(animated: bool = true) -> void:
	_revealing = true
	_clear_stroke()
	var planned := _planar_reveal_paths()
	for color_v: Variant in planned.keys():
		var color := str(color_v)
		_grooves[color] = planned[color]
		_completed[color] = true
		if animated and is_inside_tree():
			queue_redraw()
			await get_tree().create_timer(0.12).timeout
			if not is_instance_valid(self):
				return
	_revealing = false
	_rebuild_groove_carves()
	_emit_status()
	queue_redraw()
	solution_revealed.emit()


func _load_solution(level_data: Dictionary) -> void:
	var sol_v: Variant = level_data.get("solution", null)
	if typeof(sol_v) != TYPE_DICTIONARY:
		return
	var sol: Dictionary = sol_v
	for color_v: Variant in sol.keys():
		var raw: Variant = sol[color_v]
		if typeof(raw) != TYPE_ARRAY:
			continue
		var poly := PackedVector2Array()
		for pt_v: Variant in raw:
			if typeof(pt_v) == TYPE_VECTOR2:
				poly.append(pt_v)
			elif typeof(pt_v) == TYPE_ARRAY:
				var arr: Array = pt_v
				if arr.size() >= 2:
					poly.append(Vector2(float(arr[0]), float(arr[1])))
		if poly.size() >= 2:
			_solution[str(color_v)] = poly


func _planar_reveal_paths() -> Dictionary:
	var by_color: Dictionary = {}
	for rock: Dictionary in _rocks:
		var color := str(rock["color"])
		if not by_color.has(color):
			by_color[color] = []
		(by_color[color] as Array).append(rock["norm"])

	# Preferir solución planar generada (polilíneas sin cruce).
	var planned := _solution_paths_if_planar(by_color)
	if not planned.is_empty():
		return planned

	# Reparación: pathfinder del generador sobre las rocas actuales.
	var rocks_payload: Array = []
	for rock: Dictionary in _rocks:
		var n: Vector2 = rock["norm"]
		rocks_payload.append({"color": str(rock["color"]), "x": n.x, "y": n.y})
	var found: Dictionary = LevelGenerator._sandbox_find_planar_solution(rocks_payload)
	if not found.is_empty():
		var result := {}
		for color_v: Variant in found.keys():
			var color := str(color_v)
			var raw: Variant = found[color]
			if typeof(raw) != TYPE_ARRAY:
				continue
			var poly := PackedVector2Array()
			for pt_v: Variant in raw:
				if typeof(pt_v) == TYPE_VECTOR2:
					poly.append(pt_v)
				elif typeof(pt_v) == TYPE_ARRAY:
					var arr: Array = pt_v
					if arr.size() >= 2:
						poly.append(Vector2(float(arr[0]), float(arr[1])))
			if poly.size() >= 2:
				result[color] = poly
		if result.size() == by_color.size():
			return result

	# Último recurso: desvíos locales (nunca rectas que se cruzan).
	var colors: Array = []
	for color_v: Variant in _solution.keys():
		var color := str(color_v)
		if by_color.has(color) and not colors.has(color):
			colors.append(color)
	for color_v: Variant in by_color.keys():
		var color := str(color_v)
		if not colors.has(color):
			colors.append(color)
	var placed: Array = []
	var result2: Dictionary = {}
	for color_v: Variant in colors:
		var color := str(color_v)
		var pts: Array = by_color.get(color, [])
		if pts.size() < 2:
			continue
		var path := PackedVector2Array()
		if _solution.has(color):
			path = _solution[color]
		else:
			path.append(pts[0])
			path.append(pts[1])
		if _path_crosses_any(path, placed):
			path = _detour_path(pts[0], pts[1], placed)
		result2[color] = path
		placed.append(path)
	return result2


func _solution_paths_if_planar(by_color: Dictionary) -> Dictionary:
	if _solution.is_empty():
		return {}
	var placed: Array = []
	var result: Dictionary = {}
	for color_v: Variant in by_color.keys():
		var color := str(color_v)
		if not _solution.has(color):
			return {}
		var path: PackedVector2Array = _solution[color]
		if path.size() < 2:
			return {}
		if _path_crosses_any(path, placed):
			return {}
		result[color] = path
		placed.append(path)
	if result.size() != by_color.size():
		return {}
	return result


func _path_crosses_any(path: PackedVector2Array, others: Array) -> bool:
	for other_v: Variant in others:
		var other: PackedVector2Array = other_v
		for i in range(1, path.size()):
			for j in range(1, other.size()):
				if _segments_intersect(path[i - 1], path[i], other[j - 1], other[j]):
					return true
	return false


func _detour_path(a: Vector2, b: Vector2, others: Array) -> PackedVector2Array:
	var mid := (a + b) * 0.5
	var delta := b - a
	var perp := Vector2(-delta.y, delta.x)
	if perp.length_squared() < 0.0000001:
		perp = Vector2(0, 1)
	else:
		perp = perp.normalized()
	var offsets: Array[float] = [0.12, 0.22, 0.34, 0.48, 0.62]
	var signs: Array[float] = [1.0, -1.0]
	for dist in offsets:
		for sign in signs:
			var w := mid + perp * (sign * dist)
			w.x = clampf(w.x, 0.06, 0.94)
			w.y = clampf(w.y, 0.06, 0.94)
			var bent := PackedVector2Array()
			bent.append(a)
			bent.append(w)
			bent.append(b)
			if not _path_crosses_any(bent, others):
				return bent
	var corners: Array[Vector2] = [
		Vector2(0.06, 0.06),
		Vector2(0.94, 0.06),
		Vector2(0.06, 0.94),
		Vector2(0.94, 0.94),
		Vector2(0.06, 0.5),
		Vector2(0.94, 0.5),
		Vector2(0.5, 0.06),
		Vector2(0.5, 0.94),
	]
	for w in corners:
		var bent := PackedVector2Array()
		bent.append(a)
		bent.append(w)
		bent.append(b)
		if not _path_crosses_any(bent, others):
			return bent
	# Dos waypoints por borde (ruta en L / C) antes de aceptar cruce.
	for w1 in corners:
		for w2 in corners:
			if w1.is_equal_approx(w2):
				continue
			var bent2 := PackedVector2Array()
			bent2.append(a)
			bent2.append(w1)
			bent2.append(w2)
			bent2.append(b)
			if not _path_crosses_any(bent2, others):
				return bent2
	# No devolver recta cruzada: mantener el camino más corto no cruzado vía borde.
	var safest := PackedVector2Array()
	safest.append(a)
	safest.append(Vector2(0.5, 0.06))
	safest.append(b)
	if not _path_crosses_any(safest, others):
		return safest
	safest = PackedVector2Array()
	safest.append(a)
	safest.append(Vector2(0.5, 0.94))
	safest.append(b)
	if not _path_crosses_any(safest, others):
		return safest
	# Si todo falla, ruta por el perímetro superior (mejor que cruzar).
	var perimeter := PackedVector2Array()
	perimeter.append(a)
	perimeter.append(Vector2(a.x, 0.04))
	perimeter.append(Vector2(b.x, 0.04))
	perimeter.append(b)
	return perimeter


func get_completed_color_stats() -> Array:
	var stats: Array = []
	for color_name: Variant in GamePalette.COLORS.keys():
		var key := str(color_name)
		if not _completed.has(key):
			continue
		if not bool(_completed[key]):
			continue
		var groove: PackedVector2Array = _grooves.get(key, PackedVector2Array())
		var segs := maxi(0, groove.size() - 1)
		stats.append({
			"color": key,
			"connections": segs,
			"cells": groove.size(),
		})
	return stats


func get_level_id() -> int:
	return level_id


func _gui_input(event: InputEvent) -> void:
	if just_completed or _celebrating or _revealing:
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_press(touch.position)
		else:
			_on_release()
		accept_event()
		return

	if event is InputEventScreenDrag:
		_on_drag((event as InputEventScreenDrag).position)
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
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_on_drag(motion.position)
			accept_event()


func _on_press(pos: Vector2) -> void:
	var idx := _hit_rock(pos)
	if idx < 0:
		return
	var rock: Dictionary = _rocks[idx]
	var color := str(rock["color"])

	# Rehacer: borrar surco completado de ese color.
	if bool(_completed.get(color, false)):
		_completed[color] = false
		_grooves.erase(color)
		_rebuild_groove_carves()
		_emit_status()

	_drawing = true
	_active_color = color
	_active_start_idx = idx
	_stroke_norm = PackedVector2Array()
	_stroke_norm.append(rock["norm"])
	_ensure_groove_texture()
	var start_screen := _rock_screen(rock)
	_stamp_groove_at_screen(start_screen)
	if _groove_texture != null and _groove_image != null:
		_groove_texture.update(_groove_image)
	path_started.emit(color)
	_play_sfx("SELECT")
	queue_redraw()


func _on_drag(pos: Vector2) -> void:
	if not _drawing or _stroke_norm.is_empty():
		return
	var clamped := _clamp_to_play(pos)
	var n := _to_norm(clamped)
	var prev_n := _stroke_norm[_stroke_norm.size() - 1]
	var prev_screen := _to_screen(prev_n)
	var moved := prev_screen.distance_to(clamped)

	# Colisión siempre sobre el segmento actual (no solo al muestrear).
	if _stroke_hits_fixed_groove(prev_n, n):
		_stroke_norm.append(n)
		_fail_stroke()
		return

	var rock_hit := _first_rock_on_segment(prev_screen, clamped)
	if int(rock_hit.get("idx", -1)) >= 0:
		var hit_idx := int(rock_hit["idx"])
		var rock: Dictionary = _rocks[hit_idx]
		if not bool(rock_hit.get("mate", false)):
			_stroke_norm.append(n)
			_fail_stroke()
			return
		# Pareja correcta: grabar hasta el dedo y cerrar en la roca.
		if moved >= 0.5:
			_stroke_norm.append(n)
			_carve_groove_segment(prev_screen, clamped)
		_stroke_norm.append(rock["norm"])
		_carve_groove_segment(_to_screen(_stroke_norm[_stroke_norm.size() - 2]), _rock_screen(rock))
		_complete_stroke()
		return

	if moved >= SAMPLE_DIST:
		_stroke_norm.append(n)
		_carve_groove_segment(prev_screen, clamped)
	queue_redraw()


func _on_release() -> void:
	if not _drawing:
		return
	_clear_stroke()
	_rebuild_groove_carves()
	queue_redraw()


func _complete_stroke() -> void:
	_grooves[_active_color] = _stroke_norm.duplicate()
	_completed[_active_color] = true
	if _hint_color == _active_color:
		_hint_color = ""
		_hint_timer = 0.0
	moves += 1
	pair_connected.emit(_active_color)
	_play_sfx("CONNECT")
	_clear_stroke()
	_emit_status()
	queue_redraw()
	_check_completion()


func _fail_stroke() -> void:
	_error_stroke_norm = _stroke_norm.duplicate()
	_error_flash = 0.35
	_clear_stroke()
	_rebuild_groove_carves()
	invalid_move.emit()
	_play_sfx("INVALID")
	queue_redraw()


func _clear_stroke() -> void:
	_drawing = false
	_active_color = ""
	_active_start_idx = -1
	_stroke_norm = PackedVector2Array()


func _check_completion() -> void:
	if get_remaining_pairs() > 0 or _celebrating:
		return
	just_completed = true
	_celebrating = true
	var final_moves := moves
	_play_completion_celebration(final_moves)


func _play_completion_celebration(final_moves: int) -> void:
	_play_sfx("COMPLETE")
	_vibrate(40)
	if SettingsManager.fx_enabled:
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(self) or not _celebrating:
			_set_level_bg_fx_paused(false)
			return
		await _explode_all_rocks()
	else:
		_hide_grooves_for_celebration()
		await get_tree().create_timer(0.45).timeout
	if not is_instance_valid(self) or not _celebrating:
		_set_level_bg_fx_paused(false)
		return
	_celebrating = false
	_hide_rocks = false
	_hide_grooves = false
	_set_level_bg_fx_paused(false)
	level_completed.emit(final_moves)


func _hide_grooves_for_celebration() -> void:
	_hide_grooves = true
	if _groove_image != null:
		_groove_image.fill(Color(0, 0, 0, 0))
		if _groove_texture != null:
			_groove_texture.update(_groove_image)
	_sand_particles.clear()
	queue_redraw()


func _explode_all_rocks() -> void:
	_vibrate(55)
	var prev_clip := clip_contents
	clip_contents = false
	_hide_rocks = true
	_hide_grooves_for_celebration()
	queue_redraw()
	_clear_cartoon_booms()
	var diameter := _rock_radius() * 2.05
	for rock: Dictionary in _rocks:
		var color_name := str(rock["color"])
		var tint := GamePalette.get_color(color_name)
		var center := _rock_screen(rock)
		var fx: CartoonExplosionFx = CartoonExplosionFxScript.new()
		fx.z_index = 50
		add_child(fx)
		fx.setup_at(center, diameter, tint)
		_cartoon_booms.append(fx)
		fx.start_explosion(LEVEL_COMPLETE_EXPLOSION_SEC)
	await get_tree().create_timer(LEVEL_COMPLETE_EXPLOSION_SEC).timeout
	if not is_instance_valid(self):
		return
	_clear_cartoon_booms()
	clip_contents = prev_clip


func _clear_cartoon_booms() -> void:
	for node: Node in _cartoon_booms:
		if is_instance_valid(node):
			node.queue_free()
	_cartoon_booms.clear()


func _set_level_bg_fx_paused(paused: bool) -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group("level_bg_fx"):
		if is_instance_valid(node) and node.has_method("set_fx_paused"):
			node.call("set_fx_paused", paused)


func _vibrate(duration_ms: int) -> void:
	if AudioManager == null:
		return
	AudioManager.vibrate(duration_ms)


func get_remaining_pairs() -> int:
	var remaining := 0
	for color_v: Variant in _completed.keys():
		if not bool(_completed[str(color_v)]):
			remaining += 1
	return remaining


func get_total_pairs() -> int:
	return _completed.size()


func _emit_status() -> void:
	moves_changed.emit(moves)
	var remaining := get_remaining_pairs()
	pairs_changed.emit(remaining, get_total_pairs())
	if remaining == 1:
		_set_level_bg_fx_paused(true)
	elif remaining > 1 and not _celebrating:
		_set_level_bg_fx_paused(false)


func _relayout() -> void:
	var side := minf(size.x, size.y) - MARGIN * 2.0
	side = maxf(side, 64.0)
	var origin := (size - Vector2(side, side)) * 0.5
	var prev_side := _play_rect.size.x
	_play_rect = Rect2(origin, Vector2(side, side))
	if absf(prev_side - side) > 1.0:
		_groove_tex_side = 0
		_rebuild_groove_carves()
	queue_redraw()


func _clamp_to_play(pos: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, _play_rect.position.x, _play_rect.end.x),
		clampf(pos.y, _play_rect.position.y, _play_rect.end.y)
	)


func _to_norm(screen: Vector2) -> Vector2:
	if _play_rect.size.x < 1.0 or _play_rect.size.y < 1.0:
		return Vector2(0.5, 0.5)
	return Vector2(
		(screen.x - _play_rect.position.x) / _play_rect.size.x,
		(screen.y - _play_rect.position.y) / _play_rect.size.y
	)


func _to_screen(norm: Vector2) -> Vector2:
	return Vector2(
		_play_rect.position.x + norm.x * _play_rect.size.x,
		_play_rect.position.y + norm.y * _play_rect.size.y
	)


func _norm_poly_to_screen(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(_to_screen(p))
	return out


func _rock_screen(rock: Dictionary) -> Vector2:
	return _to_screen(rock["norm"])


func _rock_radius() -> float:
	var ratio := ROCK_RADIUS_RATIO * (1.35 if SettingsManager.colorblind_enabled else 1.0)
	return maxf(12.0 if SettingsManager.colorblind_enabled else 10.0, minf(_play_rect.size.x, _play_rect.size.y) * ratio)


func _hit_radius() -> float:
	return maxf(_rock_radius() * 1.25, minf(_play_rect.size.x, _play_rect.size.y) * HIT_RADIUS_RATIO)


func _hit_rock(pos: Vector2, ignore_idx: int = -1) -> int:
	var best := -1
	var best_d := _hit_radius()
	for i in range(_rocks.size()):
		if i == ignore_idx:
			continue
		var d: float = pos.distance_to(_rock_screen(_rocks[i]))
		if d <= best_d:
			best_d = d
			best = i
	return best


## Primera roca tocada a lo largo del segmento (por parámetro t). mate = pareja del color activo.
func _first_rock_on_segment(from_screen: Vector2, to_screen: Vector2) -> Dictionary:
	var body_r := _rock_radius() * 1.08
	var mate_r := _hit_radius()
	var best_t := 2.0
	var best := {"idx": -1, "mate": false}
	for i in range(_rocks.size()):
		if i == _active_start_idx:
			continue
		var rock: Dictionary = _rocks[i]
		var center := _rock_screen(rock)
		var is_mate := str(rock.get("color", "")) == _active_color
		var radius := mate_r if is_mate else body_r
		var hit := _segment_circle_hit(from_screen, to_screen, center, radius)
		if not bool(hit.get("hit", false)):
			continue
		var t := float(hit.get("t", 1.0))
		if t < best_t:
			best_t = t
			best = {"idx": i, "mate": is_mate}
	return best


func _segment_circle_hit(a: Vector2, b: Vector2, center: Vector2, radius: float) -> Dictionary:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.0000001:
		var d0 := a.distance_to(center)
		return {"hit": d0 <= radius, "t": 0.0}
	var t := clampf((center - a).dot(ab) / len2, 0.0, 1.0)
	var closest := a + ab * t
	if closest.distance_to(center) > radius:
		return {"hit": false, "t": t}
	return {"hit": true, "t": t}


func _point_segment_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.0000001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _stroke_hits_fixed_groove(a_n: Vector2, b_n: Vector2) -> bool:
	# Grosor del surco en coords normalizadas (aprox. radio del pincel).
	var side := maxf(1.0, minf(_play_rect.size.x, _play_rect.size.y))
	var thick := (_groove_brush_size() * 0.42) / side
	for color_v: Variant in _grooves.keys():
		var color := str(color_v)
		if color == _active_color:
			continue
		var groove: PackedVector2Array = _grooves[color]
		for i in range(1, groove.size()):
			var g0: Vector2 = groove[i - 1]
			var g1: Vector2 = groove[i]
			if _segments_intersect(a_n, b_n, g0, g1):
				return true
			# Roce lateral: distancia entre segmentos < grosor.
			if _segments_min_dist(a_n, b_n, g0, g1) <= thick:
				return true
	return false


func _segments_min_dist(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> float:
	if _segments_intersect(p1, p2, q1, q2):
		return 0.0
	return minf(
		minf(_point_segment_dist(p1, q1, q2), _point_segment_dist(p2, q1, q2)),
		minf(_point_segment_dist(q1, p1, p2), _point_segment_dist(q2, p1, p2))
	)


func _segments_intersect(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> bool:
	var r := p2 - p1
	var s := q2 - q1
	var denom := r.x * s.y - r.y * s.x
	if absf(denom) < 0.0001:
		return false
	var qp := q1 - p1
	var t := (qp.x * s.y - qp.y * s.x) / denom
	var u := (qp.x * r.y - qp.y * r.x) / denom
	return t > 0.001 and t < 0.999 and u > 0.001 and u < 0.999


func _rebuild_sand_texture() -> void:
	if _sand_tex != null and _sand_tex_level == level_id:
		return
	_sand_tex_level = level_id
	var img := Image.create(SAND_TEX_SIZE, SAND_TEX_SIZE, false, Image.FORMAT_RGB8)
	var seed_off := level_id * 97
	for y in range(SAND_TEX_SIZE):
		for x in range(SAND_TEX_SIZE):
			img.set_pixel(x, y, _sand_pixel(x, y, seed_off))
	if _sand_tex == null:
		_sand_tex = ImageTexture.create_from_image(img)
	else:
		_sand_tex.update(img)


func _sand_pixel(x: int, y: int, seed_off: int) -> Color:
	var fx := float(x + seed_off)
	var fy := float(y + seed_off * 3)
	# Ondas suaves tipo duna / manchas de humedad.
	var dune := _fbm(fx * 0.018, fy * 0.018, 3)
	var ripples := _value_noise(fx * 0.07, fy * 0.07) * 0.35 + _value_noise(fx * 0.13, fy * 0.05) * 0.2
	var tone := clampf(dune * 0.55 + ripples * 0.45, 0.0, 1.0)
	# Base: beige → ocre → arena más oscura.
	var c := Color(
		lerpf(0.72, 0.90, tone),
		lerpf(0.56, 0.74, tone * 0.92),
		lerpf(0.36, 0.52, tone * 0.75)
	)
	# Granos individuales (speckle denso).
	var g := _hash2(x + seed_off * 13, y + seed_off * 7)
	if g > 0.93:
		c = c.lightened(0.18 + (g - 0.93) * 1.2)
	elif g < 0.07:
		c = c.darkened(0.16 + (0.07 - g) * 1.4)
	elif g > 0.48 and g < 0.505:
		# Micropiedrecitas más oscuras.
		c = c.darkened(0.22)
		c.b *= 0.92
	# Matiz cálido irregular (algo de óxido / cuarzo).
	var warm := _hash2(x * 3 + 11, y * 5 + 19)
	if warm > 0.82:
		c.r = minf(1.0, c.r + 0.04)
		c.g = minf(1.0, c.g + 0.015)
	elif warm < 0.12:
		c.b = minf(1.0, c.b + 0.03)
		c.g = minf(1.0, c.g + 0.01)
	return c


func _hash2(x: int, y: int) -> float:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return float(n & 0x7fffffff) / float(0x7fffffff)


func _value_noise(x: float, y: float) -> float:
	var x0 := int(floor(x))
	var y0 := int(floor(y))
	var xf := x - float(x0)
	var yf := y - float(y0)
	var u := xf * xf * (3.0 - 2.0 * xf)
	var v := yf * yf * (3.0 - 2.0 * yf)
	var a := _hash2(x0, y0)
	var b := _hash2(x0 + 1, y0)
	var c := _hash2(x0, y0 + 1)
	var d := _hash2(x0 + 1, y0 + 1)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)


func _fbm(x: float, y: float, octaves: int) -> float:
	var amp := 0.5
	var freq := 1.0
	var sum := 0.0
	var norm := 0.0
	for _i in range(octaves):
		sum += _value_noise(x * freq, y * freq) * amp
		norm += amp
		amp *= 0.5
		freq *= 2.05
	return sum / maxf(norm, 0.001)


func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	_draw_sand()
	_draw_groove_texture()
	# Trazo activo: refuerzo visual por si el carve va un frame retrasado.
	if _drawing and _stroke_norm.size() >= 2:
		_draw_polyline_groove(
			_norm_poly_to_screen(_stroke_norm),
			Color(0.72, 0.48, 0.28, 0.55),
			GROOVE_WIDTH,
			false
		)
	_draw_sand_particles()
	_draw_hint_path()
	if _error_flash > 0.0 and not _error_stroke_norm.is_empty():
		_draw_polyline_groove(
			_norm_poly_to_screen(_error_stroke_norm),
			Color(0.95, 0.25, 0.18, clampf(_error_flash, 0.0, 1.0)),
			GROOVE_WIDTH + 1.0,
			true
		)
	_draw_rocks()


func _draw_sand() -> void:
	var r := _play_rect
	if r.size.x < 2.0 or r.size.y < 2.0:
		return
	if _sand_tex == null:
		_rebuild_sand_texture()
	# Baldosas: grano fino a tamaño constante.
	var tile := SAND_TILE_PX
	var cols := int(ceili(r.size.x / tile))
	var rows := int(ceili(r.size.y / tile))
	for iy in range(rows):
		for ix in range(cols):
			var dest := Rect2(r.position + Vector2(float(ix) * tile, float(iy) * tile), Vector2(tile, tile))
			var clipped := dest.intersection(r)
			if clipped.size.x < 1.0 or clipped.size.y < 1.0:
				continue
			var uv_off := clipped.position - dest.position
			var src := Rect2(
				uv_off.x / tile * float(SAND_TEX_SIZE),
				uv_off.y / tile * float(SAND_TEX_SIZE),
				clipped.size.x / tile * float(SAND_TEX_SIZE),
				clipped.size.y / tile * float(SAND_TEX_SIZE)
			)
			draw_texture_rect_region(_sand_tex, clipped, src)
	# Relieve de bandeja: sombra suave + borde.
	draw_rect(Rect2(r.position, Vector2(r.size.x, 14)), Color(0.35, 0.25, 0.12, 0.12), true)
	draw_rect(Rect2(r.position, Vector2(12, r.size.y)), Color(0.3, 0.22, 0.1, 0.1), true)
	draw_rect(Rect2(Vector2(r.position.x, r.end.y - 16), Vector2(r.size.x, 16)), Color(1, 0.95, 0.8, 0.06), true)
	draw_rect(Rect2(Vector2(r.end.x - 14, r.position.y), Vector2(14, r.size.y)), Color(1, 0.95, 0.85, 0.05), true)
	draw_rect(r.grow(1.0), Color(0.45, 0.34, 0.2, 0.55), false, 3.0)
	draw_rect(r.grow(-2.0), Color(0.85, 0.72, 0.48, 0.35), false, 1.5)


func _draw_groove_texture() -> void:
	if _hide_grooves:
		return
	if _groove_texture == null or _play_rect.size.x < 2.0:
		return
	draw_texture_rect(_groove_texture, _play_rect, false)


func _draw_sand_particles() -> void:
	for p in _sand_particles:
		var life_ratio := clampf(float(p["life"]) / maxf(float(p["max_life"]), 0.001), 0.0, 1.0)
		var c: Color = p["color"]
		c.a = life_ratio
		draw_circle(p["pos"], float(p["radius"]) * (0.4 + life_ratio * 0.6), c)


func _clear_groove_texture() -> void:
	_groove_tex_side = 0
	_groove_image = null
	_groove_texture = null
	_sand_particles.clear()


func _ensure_groove_texture() -> void:
	if _play_rect.size.x < 8.0:
		return
	var side := clampi(int(_play_rect.size.x), GROOVE_TEX_MIN, GROOVE_TEX_MAX)
	if _groove_image != null and _groove_tex_side == side:
		return
	_groove_tex_side = side
	_groove_image = Image.create(side, side, false, Image.FORMAT_RGBA8)
	_groove_image.fill(Color(0, 0, 0, 0))
	if _groove_texture == null:
		_groove_texture = ImageTexture.create_from_image(_groove_image)
	else:
		_groove_texture.update(_groove_image)


func _rebuild_groove_carves() -> void:
	if _hide_grooves:
		return
	_ensure_groove_texture()
	if _groove_image == null:
		return
	_groove_image.fill(Color(0, 0, 0, 0))
	for color_v: Variant in _grooves.keys():
		var groove: PackedVector2Array = _grooves[color_v]
		for i in range(1, groove.size()):
			_carve_groove_segment(_to_screen(groove[i - 1]), _to_screen(groove[i]), false)
	if _groove_texture != null:
		_groove_texture.update(_groove_image)


func _groove_brush_size() -> float:
	return GROOVE_BRUSH_SIZE


func _carve_groove_segment(from_screen: Vector2, to_screen: Vector2, spawn_particles: bool = true) -> void:
	if _groove_image == null:
		_ensure_groove_texture()
	if _groove_image == null:
		return
	var brush := _groove_brush_size()
	var distance := from_screen.distance_to(to_screen)
	var step := maxf(brush * 0.15, 1.5)
	var count := maxi(1, int(ceil(distance / step)))
	for i in range(count + 1):
		var p := from_screen.lerp(to_screen, float(i) / float(count))
		_stamp_groove_at_screen(p)
	if spawn_particles and distance > 0.5:
		var dir := from_screen.direction_to(to_screen)
		_spawn_groove_particles(to_screen, dir)
	if _groove_texture != null:
		_groove_texture.update(_groove_image)


func _stamp_groove_at_screen(screen_pos: Vector2) -> void:
	if _groove_image == null:
		return
	if _play_rect.size.x < 2.0 or _play_rect.size.y < 2.0:
		return
	# has_point excluye el borde der/inf; clampear al interior para no perder stamps.
	var sp := Vector2(
		clampf(screen_pos.x, _play_rect.position.x, _play_rect.end.x - 0.001),
		clampf(screen_pos.y, _play_rect.position.y, _play_rect.end.y - 0.001)
	)
	var res := _groove_tex_side
	var board_size := _play_rect.size
	var p := sp - _play_rect.position
	var brush := _groove_brush_size()
	var center := Vector2(
		p.x / board_size.x * float(res - 1),
		p.y / board_size.y * float(res - 1)
	)
	var radius_x := brush * 0.5 * res / board_size.x
	var radius_y := brush * 0.5 * res / board_size.y
	var radius := maxf(radius_x, radius_y)
	var margin := radius * 1.6
	var x0 := maxi(0, int(center.x - margin))
	var x1 := mini(res - 1, int(center.x + margin))
	var y0 := maxi(0, int(center.y - margin))
	var y1 := mini(res - 1, int(center.y + margin))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := (float(x) - center.x) / maxf(radius_x, 0.001)
			var dy := (float(y) - center.y) / maxf(radius_y, 0.001)
			var d := Vector2(dx, dy).length()
			var wobble := _groove_noise.get_noise_2d(
				float(x) * 0.18,
				float(y) * 0.18
			) * GROOVE_EDGE_IRREG * 0.13
			d += wobble
			if d > 1.55:
				continue
			var alpha := 0.0
			var color := Color("#5b391d")
			if d < 0.48:
				alpha = GROOVE_DEPTH
				var variation := _groove_noise.get_noise_2d(float(x) * 0.3, float(y) * 0.3) * 0.035
				color = Color(
					0.22 + variation,
					0.12 + variation * 0.5,
					0.055 + variation * 0.3
				)
			elif d < 0.82:
				var t := (d - 0.48) / 0.34
				alpha = GROOVE_DEPTH * 0.92
				color = Color(
					0.25 + t * 0.13,
					0.135 + t * 0.075,
					0.06 + t * 0.035
				)
			elif d < 1.08:
				var t := (d - 0.82) / 0.26
				var irregular_light := _groove_noise.get_noise_2d(float(x) * 0.12, float(y) * 0.12)
				alpha = clampf((1.0 - t) * 0.72 + irregular_light * 0.10, 0.0, 0.78)
				color = Color("#e3b573")
			elif d < 1.55:
				var t := (d - 1.08) / 0.47
				alpha = (1.0 - t) * 0.22
				color = Color("#59371b")
			var old := _groove_image.get_pixel(x, y)
			var out_alpha := alpha + old.a * (1.0 - alpha)
			if out_alpha <= 0.001:
				continue
			var out_color := Color(
				(color.r * alpha + old.r * old.a * (1.0 - alpha)) / out_alpha,
				(color.g * alpha + old.g * old.a * (1.0 - alpha)) / out_alpha,
				(color.b * alpha + old.b * old.a * (1.0 - alpha)) / out_alpha,
				out_alpha
			)
			_groove_image.set_pixel(x, y, out_color)


func _spawn_groove_particles(pos: Vector2, direction: Vector2) -> void:
	if GROOVE_PARTICLES_PER_STAMP <= 0:
		return
	if direction.length_squared() < 0.0001:
		direction = Vector2(1, 0)
	else:
		direction = direction.normalized()
	var side := Vector2(-direction.y, direction.x)
	var brush := _groove_brush_size()
	for _i in range(GROOVE_PARTICLES_PER_STAMP):
		var side_sign := -1.0 if _rng.randf() < 0.5 else 1.0
		var velocity := side * side_sign * _rng.randf_range(15.0, GROOVE_PARTICLE_SPEED * 0.55)
		velocity += Vector2(_rng.randf_range(-22.0, 22.0), _rng.randf_range(-22.0, 22.0))
		_sand_particles.append({
			"pos": pos + side * side_sign * brush * 0.4,
			"vel": velocity,
			"life": _rng.randf_range(GROOVE_PARTICLE_LIFE * 0.5, GROOVE_PARTICLE_LIFE),
			"max_life": GROOVE_PARTICLE_LIFE,
			"radius": _rng.randf_range(1.0, 2.8),
			"color": [
				Color("#e6bd7e"),
				Color("#c18a4a"),
				Color("#f2d6a0"),
			][_rng.randi_range(0, 2)],
		})


func _draw_polyline_groove(
	pts: PackedVector2Array,
	tint: Color,
	width: float,
	is_error: bool = false,
	is_draft: bool = false
) -> void:
	if pts.size() < 2:
		return
	var a := tint.a if is_error else 1.0
	var depth := 0.72 if is_draft else 1.0
	# 1) Arena removida / bordes suaves (montículo claro).
	draw_polyline(pts, Color(0.93, 0.84, 0.64, 0.5 * a * depth), width + 8.0, true)
	# 2) Sombra proyectada (luz arriba-izquierda → surco hundido).
	var shadow_pts := _offset_polyline(pts, Vector2(1.8, 2.4))
	draw_polyline(shadow_pts, Color(0.28, 0.18, 0.08, 0.32 * a * depth), width + 3.0, true)
	# 3) Cuerpo del surco: arena oscura con tinte del color (identidad de pareja).
	var trench: Color
	if is_error:
		trench = Color(0.72, 0.22, 0.14, 0.9 * a)
	else:
		trench = Color(
			lerpf(0.40, tint.r * 0.55, 0.42),
			lerpf(0.30, tint.g * 0.48, 0.42),
			lerpf(0.16, tint.b * 0.42, 0.42),
			0.9 * depth
		)
	draw_polyline(pts, trench, width + 1.2, true)
	# 4) Fondo del surco (más profundo / húmedo).
	var deep := Color(0.18, 0.12, 0.06, 0.78 * a * depth) if not is_error else Color(0.35, 0.08, 0.05, 0.7 * a)
	draw_polyline(pts, deep, width * 0.38, true)
	# 5) Cresta iluminada (borde superior del surco).
	var rim_pts := _offset_polyline(pts, Vector2(-1.0, -1.2))
	draw_polyline(rim_pts, Color(0.97, 0.90, 0.72, 0.4 * a * depth), width * 0.5, true)
	# 6) Granos removidos a lo largo del borde.
	_draw_groove_grains(pts, width, a * depth)


func _offset_polyline(pts: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in range(pts.size()):
		out[i] = pts[i] + offset
	return out


func _draw_groove_grains(pts: PackedVector2Array, width: float, alpha: float) -> void:
	if pts.size() < 2 or alpha < 0.05:
		return
	var spacing := 7.0
	var carry := 0.0
	var side := 1.0
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var delta := b - a
		var seg_len := delta.length()
		if seg_len < 0.001:
			continue
		var dir := delta / seg_len
		var normal := Vector2(-dir.y, dir.x)
		var t := spacing - carry
		while t <= seg_len:
			var p := a + dir * t
			var ridge := p + normal * side * (width * 0.55 + 1.5)
			var grain_r := 1.1 + fmod(absf(p.x + p.y), 1.4)
			draw_circle(ridge, grain_r, Color(0.88, 0.76, 0.52, 0.35 * alpha))
			draw_circle(ridge + Vector2(0.6, 0.8), grain_r * 0.55, Color(0.45, 0.32, 0.16, 0.28 * alpha))
			side = -side
			t += spacing
		carry = seg_len - (t - spacing)
		if carry < 0.0:
			carry = 0.0


func _draw_rocks() -> void:
	if _hide_rocks:
		return
	var radius := _rock_radius()
	for i in range(_rocks.size()):
		var rock: Dictionary = _rocks[i]
		var color := str(rock["color"])
		var pos := _rock_screen(rock)
		var base := GamePalette.get_color(color)
		var draw_radius := radius
		var hint_boost := 0.0
		# Ayuda visual: al tocar una roca, su pareja del mismo color parpadea.
		if (
			SettingsManager.visual_help_enabled
			and _drawing
			and color == _active_color
		):
			draw_radius *= 1.12 + 0.06 * sin(_pulse_time * 2.8)
			if i != _active_start_idx:
				hint_boost = 0.45 + 0.4 * absf(sin(_pulse_time * 7.0))
		var seed_i := _rock_shape_seed(rock, i)
		var blob := _irregular_rock_points(pos, draw_radius, seed_i)
		var shadow := _irregular_rock_points(pos + Vector2(2.5, 3.5), draw_radius * 1.04, seed_i)
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.28))
		draw_colored_polygon(blob, base.darkened(0.18))
		# Capas internas irregulares (relieve de piedra).
		var mid := _irregular_rock_points(pos + Vector2(-draw_radius * 0.08, -draw_radius * 0.06), draw_radius * 0.72, seed_i + 17)
		draw_colored_polygon(mid, base)
		var shine := _irregular_rock_points(pos + Vector2(-draw_radius * 0.18, -draw_radius * 0.2), draw_radius * 0.32, seed_i + 31)
		var shine_col := base.lightened(0.35)
		shine_col.a = 0.9
		draw_colored_polygon(shine, shine_col)
		draw_polyline(blob, base.darkened(0.35), 1.6, true)
		if hint_boost > 0.0:
			draw_arc(pos, draw_radius + 6.0, 0.0, TAU, 32, Color(1, 1, 1, hint_boost), 3.0, true)
		if SettingsManager.colorblind_enabled:
			ColorShapesScript.draw_on_ball(self, pos, draw_radius, GamePalette.shape_for(color), base)


func _rock_shape_seed(rock: Dictionary, index: int) -> int:
	var n: Vector2 = rock["norm"]
	return int(absf(n.x * 73856093.0 + n.y * 19349663.0 + float(index) * 83492791.0)) & 0x7fffffff


func _irregular_rock_points(center: Vector2, radius: float, seed_i: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i if seed_i > 0 else 1
	var sides := 9 + rng.randi_range(0, 3)
	var pts := PackedVector2Array()
	var rot := rng.randf() * TAU
	for i in range(sides):
		var t := float(i) / float(sides)
		var a := rot + t * TAU
		# Radio variable: círculo “roto”, sin puntas agresivas.
		var wobble := rng.randf_range(0.78, 1.12)
		# Suaviza un poco el salto entre vértices vecinos.
		var soft := 1.0 + 0.06 * sin(a * 3.0 + float(seed_i % 7))
		pts.append(center + Vector2(cos(a), sin(a)) * (radius * wobble * soft))
	return pts


func _play_sfx(kind: String) -> void:
	match kind:
		"SELECT":
			AudioManager.play(AudioManager.Sfx.SELECT)
		"CONNECT":
			AudioManager.play(AudioManager.Sfx.CONNECT)
		"INVALID":
			AudioManager.play(AudioManager.Sfx.INVALID)
		"HINT":
			AudioManager.play(AudioManager.Sfx.HINT)
		"COMPLETE":
			AudioManager.play(AudioManager.Sfx.COMPLETE)
