extends Control

## Cinemática al completar el nivel 99:
## fondo → negro → naves destruyen bolas del tablero → nave madre destroza tablero →
## negro → estrellas + NUEVA ERA → tablero 100 (era Emoji).

signal finished
signal ready_for_new_board

const SpaceBackgroundScript := preload("res://scripts/space_background.gd")
const CartoonExplosionFxScript := preload("res://scripts/cartoon_explosion_fx.gd")
const BoardDestroyFxScript := preload("res://scripts/board_destroy_fx.gd")
const MOTHERSHIP_TEX := preload("res://assets/era/nave_nodriza.png")
const BOMB_TEX := preload("res://assets/era/bomba-removebg-preview.png")
const HUNTER_TEX := preload("res://assets/era/nave.png")
const MOTHERSHIP_ASPECT := 350.0 / 1045.0
const BOMB_ASPECT := 350.0 / 250.0
const ERA_BOOM_SEC := 3.0
const ERA_BOOM_SEC_MOBILE := 1.2
const HUNTER_SHIP_PX := 80.0

var _space: Control
var _fx_layer: Control
var _ship_layer: Control
var _ball_layer: Control
var _black: ColorRect
var _title: Label
var _backdrop_black: ColorRect
var _rng := RandomNumberGenerator.new()
var _running: bool = false
var _host_board_ready: bool = false
var _balls: Array[Dictionary] = []
var _board_rect: Rect2 = Rect2()
var _board_ref: Board = null
var _cell_px: float = 36.0
var _hunt_queue: Array[Dictionary] = []
var _hunters_alive: int = 0
## Chrome UI (título, stats, botones) atenuado antes de las naves; se restaura al terminar.
var _faded_chrome: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	_rng.randomize()
	_build()


func _build() -> void:
	_space = SpaceBackgroundScript.new()
	_space.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _space.has_method("set_warp"):
		_space.call("set_warp", 1.45)
	add_child(_space)
	# Tras _ready del SpaceBackground: invisible hasta el beat de estrellas (el tablero debe verse).
	_space.modulate = Color(1, 1, 1, 0)

	_fx_layer = Control.new()
	_fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)

	_ball_layer = Control.new()
	_ball_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ball_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(_ball_layer)

	_ship_layer = Control.new()
	_ship_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ship_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(_ship_layer)

	_black = ColorRect.new()
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.color = Color(0, 0, 0, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)

	_title = Label.new()
	_title.text = "NUEVA ERA"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.add_theme_font_size_override("font_size", 72)
	_title.add_theme_color_override("font_color", Color("FFE45E"))
	_title.add_theme_color_override("font_outline_color", Color("0A0A20"))
	_title.add_theme_constant_override("outline_size", 16)
	UIFactory.apply_title_font(_title)
	_title.modulate = Color(1, 1, 1, 0)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)


func play(board: Board = null, ui_root: Control = null, background: Control = null) -> void:
	if _running:
		return
	_running = true
	visible = true
	await _run(board, ui_root, background)
	_running = false
	finished.emit()


func handoff_space_background() -> Control:
	_clear_backdrop_black()
	if _space == null or not is_instance_valid(_space):
		return null
	if _space.has_method("set_warp"):
		_space.call("set_warp", 0.38)
	_space.modulate = Color(1, 1, 1, 1)
	remove_child(_space)
	var handed := _space
	_space = null
	return handed


## El host (game/preview) llama esto cuando el tablero de la nueva era está listo bajo el negro.
func mark_new_board_ready() -> void:
	_host_board_ready = true


func _clear_backdrop_black() -> void:
	if is_instance_valid(_backdrop_black):
		_backdrop_black.queue_free()
	_backdrop_black = null


func _run(board: Board, ui_root: Control, background: Control) -> void:
	_board_ref = board
	# Capas de cinemática transparentes: el tablero real queda visible debajo.
	if is_instance_valid(_space):
		_space.modulate = Color(1, 1, 1, 0)
	_black.color.a = 0.0
	_prepare_board_balls(board)

	# 1) El fondo animado se funde a negro; el tablero sigue visible.
	await _fade_old_background(background)
	if not is_inside_tree():
		_restore_faded_chrome()
		return

	# 1b) Oscurece título / cartel / botones: solo queda el tablero.
	await _fade_ui_chrome_around_board(board)
	if not is_inside_tree():
		_restore_faded_chrome()
		return

	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		_restore_faded_chrome()
		return

	# 2) Naves destruyen las bolas una a una (dentro del tablero).
	await _destroy_balls_with_ships()
	if not is_inside_tree():
		_restore_faded_chrome()
		return

	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree():
		_restore_faded_chrome()
		return

	# 3) Nave madre destroza el tablero → negro total.
	await _mothership_destroy_board(ui_root)
	if not is_inside_tree():
		_restore_faded_chrome()
		return

	var to_black := create_tween()
	to_black.tween_property(_black, "color:a", 1.0, 0.7)
	await to_black.finished
	if not is_inside_tree():
		_restore_faded_chrome()
		return
	_clear_fx()

	# 4) Estrellas + NUEVA ERA.
	if _space.has_method("set_warp"):
		_space.call("set_warp", 1.55)
	_space.modulate = Color(1, 1, 1, 0)
	var stars_in := create_tween()
	stars_in.tween_property(_space, "modulate:a", 1.0, 1.1)
	stars_in.parallel().tween_property(_black, "color:a", 0.0, 1.0)
	await stars_in.finished
	if not is_inside_tree():
		_restore_faded_chrome()
		return

	_title.scale = Vector2(0.4, 0.4)
	_title.pivot_offset = _title.size * 0.5
	var title_in := create_tween()
	title_in.tween_property(_title, "modulate:a", 1.0, 0.55)
	title_in.parallel().tween_property(_title, "scale", Vector2(1.06, 1.06), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	title_in.tween_property(_title, "scale", Vector2.ONE, 0.22)
	title_in.tween_interval(1.5)
	await title_in.finished
	if not is_inside_tree():
		_restore_faded_chrome()
		return

	# 5) Texto a negro (el negro se mantiene hasta el tablero nuevo).
	var title_out := create_tween()
	title_out.tween_property(_title, "modulate:a", 0.0, 0.75)
	title_out.parallel().tween_property(_black, "color:a", 1.0, 0.9)
	await title_out.finished
	if not is_inside_tree():
		_restore_faded_chrome()
		return

	# 6) Bajo negro: handoff + prep del tablero; un solo reveal (estrellas + tablero).
	_host_board_ready = false
	if is_instance_valid(_space) and _space.has_method("set_warp"):
		_space.call("set_warp", 0.38)
	ready_for_new_board.emit()
	var wait_t := 0.0
	while is_inside_tree() and not _host_board_ready and wait_t < 4.0:
		await get_tree().process_frame
		wait_t += get_process_delta_time()
	if not is_inside_tree():
		_restore_faded_chrome()
		return
	if wait_t < 0.35:
		await get_tree().create_timer(0.35 - wait_t).timeout
		if not is_inside_tree():
			_restore_faded_chrome()
			return
	var reveal := create_tween()
	reveal.tween_property(_black, "color:a", 0.0, 1.0)
	await reveal.finished
	# El host reutiliza el mismo chrome: dejar modulate limpio para el reveal del juego.
	_restore_faded_chrome()


func _fade_ui_chrome_around_board(board: Board) -> void:
	_faded_chrome.clear()
	if board == null or not is_instance_valid(board):
		return
	var parent := board.get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child == board:
			continue
		if child is CanvasItem:
			var ci := child as CanvasItem
			_faded_chrome.append({"node": ci, "mod": ci.modulate})
	if _faded_chrome.is_empty():
		return
	var tw := create_tween()
	tw.set_parallel(true)
	for entry in _faded_chrome:
		var ci: CanvasItem = entry["node"]
		if ci == null or not is_instance_valid(ci):
			continue
		# Oscurece y desvanece a la vez (queda solo el tablero).
		tw.tween_property(ci, "modulate", Color(0.12, 0.12, 0.18, 0.0), 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func _restore_faded_chrome() -> void:
	for entry in _faded_chrome:
		var ci: CanvasItem = entry.get("node")
		if ci != null and is_instance_valid(ci):
			ci.modulate = entry.get("mod", Color(1, 1, 1, 1))
	_faded_chrome.clear()


func _fade_old_background(background: Control) -> void:
	# El velo de la cinemática no debe tapar tablero ni naves.
	_black.color.a = 0.0

	if background != null and is_instance_valid(background):
		var parent := background.get_parent()
		if parent != null:
			# Negro detrás del fondo/tablero (fuera de la cinemática).
			_clear_backdrop_black()
			_backdrop_black = ColorRect.new()
			_backdrop_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_backdrop_black.color = Color(0, 0, 0, 1)
			_backdrop_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_backdrop_black.modulate.a = 0.0
			parent.add_child(_backdrop_black)
			parent.move_child(_backdrop_black, 0)
			# Fondo animado encima del negro; UI/tablero por encima del fondo.
			if background.get_index() < 1:
				parent.move_child(background, 1)

		var tw := create_tween()
		tw.tween_property(background, "modulate:a", 0.0, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if is_instance_valid(_backdrop_black):
			tw.parallel().tween_property(_backdrop_black, "modulate:a", 1.0, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
		return

	# Sin fondo externo: negro solo detrás de las capas de FX (naves/bolas).
	if _black.get_index() > _fx_layer.get_index():
		move_child(_black, _fx_layer.get_index())
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 1.0, 1.0)
	await tw.finished
	# Restaurar orden para los fundidos totales posteriores.
	move_child(_black, _title.get_index())


func _prepare_board_balls(board: Board) -> void:
	_balls.clear()
	_clear_children(_ball_layer)
	if board != null and is_instance_valid(board):
		_board_rect = board.get_global_rect()
		_cell_px = maxf(28.0, board.cell_size)
		# Diámetro visual ≈ bolas neon reales (radio ~0.24 * cell → ~0.48 * cell).
		var proxy_diam := maxf(18.0, _cell_px * 0.48)
		# Sustituir bolas del tablero por proxies (el tablero/grid/caminos siguen).
		var cells: Array = board.endpoints.keys()
		for pos_variant: Variant in cells:
			var cell: Vector2i = pos_variant
			var color_name := str(board.endpoints[cell])
			var center: Vector2 = board.get_cell_center_global(cell)
			_balls.append(_make_ball_proxy(center, color_name, cell, proxy_diam))
		board.endpoints.clear()
		board.queue_redraw()
		return

	var area := get_global_rect()
	_board_rect = Rect2(area.position + area.size * 0.18, area.size * 0.64)
	_cell_px = 40.0
	var proxy_diam := maxf(18.0, _cell_px * 0.48)
	var palette: Array[String] = ["cyan", "orange", "green", "pink", "yellow", "violet", "red", "blue"]
	for i in range(10):
		var center := _board_rect.position + Vector2(
			_rng.randf_range(_board_rect.size.x * 0.18, _board_rect.size.x * 0.82),
			_rng.randf_range(_board_rect.size.y * 0.18, _board_rect.size.y * 0.82)
		)
		_balls.append(_make_ball_proxy(center, palette[i % palette.size()], Vector2i(i, 0), proxy_diam))


func _make_ball_proxy(center: Vector2, color_name: String, cell: Vector2i, diameter: float = -1.0) -> Dictionary:
	var ball := _BallProxy.new()
	ball.ball_color = GamePalette.get_color(color_name)
	var d := diameter if diameter > 0.0 else maxf(18.0, _cell_px * 0.48)
	var sz := Vector2(d, d)
	ball.custom_minimum_size = sz
	ball.size = sz
	ball.pivot_offset = sz * 0.5
	ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ball_layer.add_child(ball)
	ball.global_position = center - ball.pivot_offset
	return {
		"node": ball,
		"center": center,
		"alive": true,
		"color": color_name,
		"cell": cell,
	}


func _destroy_balls_with_ships() -> void:
	_hunt_queue = _alive_balls()
	_hunt_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: Vector2 = a.get("center", Vector2.ZERO)
		var cb: Vector2 = b.get("center", Vector2.ZERO)
		if absf(ca.y - cb.y) > 12.0:
			return ca.y < cb.y
		return ca.x < cb.x
	)
	_hunters_alive = 0
	if _hunt_queue.is_empty():
		return

	var max_hunters := mini(4, _hunt_queue.size())
	# Primera nave al instante; las siguientes van entrando en cascada.
	for i in range(max_hunters):
		if not is_inside_tree() or _hunt_queue.is_empty():
			break
		_start_hunter()
		if i < max_hunters - 1 and not _hunt_queue.is_empty():
			await get_tree().create_timer(0.34).timeout

	# Mientras queden bolas o naves trabajando, mantener el enjambre.
	while is_inside_tree() and (_hunters_alive > 0 or not _hunt_queue.is_empty()):
		if not _hunt_queue.is_empty() and _hunters_alive < max_hunters:
			_start_hunter()
			await get_tree().create_timer(0.3).timeout
		else:
			await get_tree().process_frame


func _alive_balls() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ball in _balls:
		if bool(ball.get("alive", false)):
			var node: Control = ball.get("node")
			if node != null and is_instance_valid(node):
				out.append(ball)
	return out


func _take_hunt_target() -> Dictionary:
	while not _hunt_queue.is_empty():
		var ball: Dictionary = _hunt_queue.pop_front()
		if bool(ball.get("alive", false)):
			var node: Control = ball.get("node")
			if node != null and is_instance_valid(node):
				return ball
	return {}


func _start_hunter() -> void:
	_hunters_alive += 1
	_hunter_run()


func _hunter_run() -> void:
	var ship := _spawn_ship(false)
	var first := true
	while is_inside_tree() and is_instance_valid(ship):
		var ball := _take_hunt_target()
		if ball.is_empty():
			break
		var ok := await _hunter_destroy_one(ship, ball, first)
		first = false
		if not ok or not is_inside_tree() or not is_instance_valid(ship):
			break

	if is_instance_valid(ship) and is_inside_tree():
		var leave := _ship_exit_point(ship.center_global())
		await _fly_ship(ship, ship.center_global(), leave, _rng.randf_range(0.45, 0.7), true)
	if is_instance_valid(ship):
		ship.queue_free()
	_hunters_alive = maxi(0, _hunters_alive - 1)


func _hunter_destroy_one(ship: _ShipView, ball: Dictionary, arriving: bool) -> bool:
	if ship == null or not is_instance_valid(ship):
		return false
	var target: Vector2 = ball.get("center", size * 0.5)
	var hover := _clamp_to_board_approach(target)

	if arriving:
		var enter_from := _ship_enter_point(target)
		ship.global_position = enter_from - ship.pivot_offset
		ship.modulate.a = 0.0
		ship.set_facing((hover - enter_from).angle())
		var fade_in := create_tween()
		fade_in.tween_property(ship, "modulate:a", 1.0, 0.2)
		await _fly_ship(ship, enter_from, hover, _rng.randf_range(0.65, 0.9))
	else:
		# Ya está en combate: se desliza hacia la siguiente bola.
		await _fly_ship(ship, ship.center_global(), hover, _rng.randf_range(0.4, 0.6))

	if not is_inside_tree() or not is_instance_valid(ship):
		return false
	if not bool(ball.get("alive", false)):
		return true

	await _aim_ship(ship, target, 0.16)
	if not is_inside_tree() or not is_instance_valid(ship):
		return false

	AudioManager.play(AudioManager.Sfx.CONNECT)
	await _fire_laser(ship, target, ship.beam_color, 0.22, 4.5)
	if not is_inside_tree():
		return false

	if bool(ball.get("alive", false)):
		await _explode_ball(ball)
	return is_inside_tree() and is_instance_valid(ship)


func _mothership_destroy_board(ui_root: Control) -> void:
	var target := _board_rect.get_center()
	var ship_w := size.x * 0.90
	var ship_h := ship_w * MOTHERSHIP_ASPECT
	var ship_x := global_position.x + (size.x - ship_w) * 0.5
	var peek := ship_h * 0.10
	var start_y := global_position.y - ship_h + peek
	var end_y := global_position.y + 12.0

	var mothership := TextureRect.new()
	mothership.texture = MOTHERSHIP_TEX
	mothership.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mothership.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mothership.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mothership.z_index = 30
	mothership.size = Vector2(ship_w, ship_h)
	mothership.modulate.a = 0.0
	_ship_layer.add_child(mothership)
	mothership.global_position = Vector2(ship_x, start_y)

	var descend := create_tween()
	descend.set_parallel(true)
	descend.tween_property(mothership, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	descend.tween_property(mothership, "global_position:y", end_y, 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await descend.finished
	if not is_inside_tree() or not is_instance_valid(mothership):
		return

	# Bomba sale de debajo de la nodriza (z menor) y cae al centro del tablero.
	var bomb_w := minf(size.x * 0.14, _cell_px * 2.2)
	var bomb_h := bomb_w * BOMB_ASPECT
	var bomb := TextureRect.new()
	bomb.texture = BOMB_TEX
	bomb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bomb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bomb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bomb.z_index = 20
	bomb.size = Vector2(bomb_w, bomb_h)
	bomb.pivot_offset = bomb.size * 0.5
	_ship_layer.add_child(bomb)
	# Bajo la nodriza en el árbol para dibujar detrás.
	_ship_layer.move_child(bomb, mothership.get_index())
	var bomb_start := Vector2(
		ship_x + ship_w * 0.5 - bomb_w * 0.5,
		end_y + ship_h - bomb_h * 0.35
	)
	bomb.global_position = bomb_start
	bomb.modulate.a = 0.0

	var emerge := create_tween()
	emerge.tween_property(bomb, "modulate:a", 1.0, 0.2)
	emerge.parallel().tween_property(
		bomb,
		"global_position",
		Vector2(bomb_start.x, end_y + ship_h - bomb_h * 0.05),
		0.35
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await emerge.finished
	if not is_inside_tree() or not is_instance_valid(bomb):
		return

	AudioManager.play(AudioManager.Sfx.INVALID)
	AudioManager.vibrate(70)
	var bomb_end := target - bomb.pivot_offset
	# Durante la caída: pregenerar textura de rotura (evita hitch CPU al impacto).
	if _board_ref != null and is_instance_valid(_board_ref) \
			and _board_ref.has_method("prepare_era_board_destroy_texture"):
		_board_ref.call("prepare_era_board_destroy_texture")
	var drop := create_tween()
	drop.tween_property(bomb, "global_position", bomb_end, 1.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.parallel().tween_property(bomb, "rotation", deg_to_rad(18.0), 1.05)
	await drop.finished
	if not is_inside_tree():
		return

	AudioManager.play(AudioManager.Sfx.CONNECT)
	AudioManager.vibrate(95)
	var mobile := BoardDestroyFxScript.is_mobile_device()
	var board_min := minf(_board_rect.size.x, _board_rect.size.y)
	# Móvil: grande en pantalla, barato en GPU (undersample 0.35). Escritorio: casi tablero.
	var boom_diam := board_min * (0.70 if mobile else 0.85)
	var boom_draw_scale := 0.35 if mobile else -1.0
	var boom_sec := ERA_BOOM_SEC_MOBILE if mobile else ERA_BOOM_SEC

	# Móvil: menos capas en el impacto (fill-rate). La nodriza queda estática hasta el final.
	var flash: ColorRect = null
	if mobile:
		if is_instance_valid(bomb):
			bomb.queue_free()
			bomb = null
	else:
		# Flash barato (sin shader pesado) para sensación de tamaño.
		flash = ColorRect.new()
		var flash_side := board_min * 0.9
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.z_index = 215
		flash.top_level = true
		flash.size = Vector2(flash_side, flash_side)
		flash.color = Color("FFB347")
		flash.modulate = Color(1, 1, 1, 0.0)
		_fx_layer.add_child(flash)
		flash.global_position = target - Vector2(flash_side, flash_side) * 0.5
		var flash_tw := create_tween()
		flash_tw.tween_property(flash, "modulate:a", 0.45, 0.08)
		flash_tw.tween_property(flash, "modulate:a", 0.0, 0.35)
		var fade_bomb := create_tween()
		fade_bomb.tween_property(bomb, "modulate:a", 0.0, 0.45)
		fade_bomb.parallel().tween_property(bomb, "scale", Vector2(1.35, 1.35), 0.45)

	var boom: CartoonExplosionFx = CartoonExplosionFxScript.new()
	boom.z_index = 220
	boom.top_level = true
	_fx_layer.add_child(boom)
	boom.setup_at(target, boom_diam, Color("FFB347"), boom_draw_scale)
	boom.start_explosion(boom_sec)

	# Cleanup del boom al cumplir su duración (aunque la rotura ya haya empezado).
	var boom_cleanup := get_tree().create_timer(boom_sec)
	boom_cleanup.timeout.connect(func() -> void:
		if is_instance_valid(bomb):
			bomb.queue_free()
		if is_instance_valid(boom):
			boom.queue_free()
		if is_instance_valid(flash):
			flash.queue_free()
	, CONNECT_ONE_SHOT)

	# Rotura al alcanzar el tamaño máximo del boom (explosion_time ≈ 0.25).
	var handoff := CartoonExplosionFxScript.seconds_until_peak_size(boom_sec)
	await get_tree().create_timer(handoff).timeout
	if not is_inside_tree():
		return

	# Tras el pico: atenuar boom para cortar fill-rate concurrente (tamaño visual intacto).
	if is_instance_valid(boom):
		var boom_fade := create_tween()
		boom_fade.tween_property(boom, "modulate:a", 0.0, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	if _board_ref != null and is_instance_valid(_board_ref) and _board_ref.has_method("play_era_board_destroy"):
		await _board_ref.play_era_board_destroy()
	if not is_inside_tree():
		return

	# Tras boom + rotura: la nodriza (estática desde el impacto) se eleva y se desvanece.
	if is_instance_valid(mothership):
		var ascend := create_tween()
		ascend.set_parallel(true)
		ascend.tween_property(mothership, "global_position:y", start_y, 1.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		ascend.tween_property(mothership, "modulate:a", 0.0, 1.15) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await ascend.finished
	if not is_inside_tree():
		return

	if ui_root != null and is_instance_valid(ui_root):
		var hide_ui := create_tween()
		hide_ui.tween_property(ui_root, "modulate:a", 0.0, 0.45)
		await hide_ui.finished
	if is_instance_valid(mothership):
		mothership.queue_free()


func _spawn_ship(_big: bool = false) -> _ShipView:
	var ship := _ShipView.new()
	ship.ship_tex = HUNTER_TEX
	ship.beam_color = Color("6DEFFF")
	var sz := Vector2(HUNTER_SHIP_PX, HUNTER_SHIP_PX)
	ship.custom_minimum_size = sz
	ship.size = sz
	ship.pivot_offset = sz * 0.5
	ship.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ship_layer.add_child(ship)
	return ship


func _ship_enter_point(target: Vector2) -> Vector2:
	var side := _rng.randi_range(0, 2)
	match side:
		0:
			return Vector2(global_position.x - 100.0, target.y + _rng.randf_range(-120, 120))
		1:
			return Vector2(global_position.x + size.x + 100.0, target.y + _rng.randf_range(-120, 120))
		_:
			return Vector2(target.x + _rng.randf_range(-140, 140), global_position.y - 100.0)


func _ship_exit_point(from: Vector2) -> Vector2:
	var side := _rng.randi_range(0, 2)
	match side:
		0:
			return Vector2(global_position.x - 120.0, from.y + _rng.randf_range(-60, 60))
		1:
			return Vector2(global_position.x + size.x + 120.0, from.y + _rng.randf_range(-60, 60))
		_:
			return Vector2(from.x + _rng.randf_range(-80, 80), global_position.y - 140.0)


func _clamp_to_board_approach(target: Vector2) -> Vector2:
	var margin := 36.0
	var rect := _board_rect.grow(margin)
	var dir := Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
	if dir.length_squared() < 0.01:
		dir = Vector2.UP
	dir = dir.normalized()
	var hover := target + dir * _rng.randf_range(_cell_px * 1.1, _cell_px * 1.8)
	hover.x = clampf(hover.x, rect.position.x, rect.end.x)
	hover.y = clampf(hover.y, rect.position.y, rect.end.y)
	return hover


func _fly_ship(ship: _ShipView, from: Vector2, to: Vector2, duration: float, fade_out: bool = false) -> void:
	if ship == null or not is_instance_valid(ship):
		return
	var mid := (from + to) * 0.5
	var perp := (to - from).orthogonal().normalized()
	if perp.length_squared() < 0.001:
		perp = Vector2.UP
	var bend := _rng.randf_range(50.0, 140.0) * (1.0 if _rng.randf() > 0.5 else -1.0)
	var c1 := from.lerp(mid, 0.45) + perp * bend
	var c2 := mid.lerp(to, 0.55) + perp * (-bend * 0.55)
	var elapsed := 0.0
	var start_a := ship.modulate.a
	while elapsed < duration and is_instance_valid(ship) and is_inside_tree():
		var u := clampf(elapsed / duration, 0.0, 1.0)
		var t := _smooth_step(u)
		var pos := _cubic_bezier(from, c1, c2, to, t)
		var look_t := _cubic_bezier(from, c1, c2, to, clampf(t + 0.04, 0.0, 1.0))
		var vel := look_t - pos
		if vel.length_squared() > 0.25:
			# Platillo: giro suave (no caza de perfil).
			ship.set_facing_smooth(vel.angle(), 0.12)
		ship.global_position = pos - ship.pivot_offset
		ship.bank = sin(u * PI * 2.0) * 0.08
		ship.apply_tilt()
		if fade_out and u > 0.55:
			ship.modulate.a = lerpf(start_a, 0.0, (u - 0.55) / 0.45)
		ship.queue_redraw()
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if is_instance_valid(ship):
		ship.global_position = to - ship.pivot_offset
		ship.set_facing((to - from).angle())


func _aim_ship(ship: _ShipView, target: Vector2, duration: float) -> void:
	if ship == null or not is_instance_valid(ship):
		return
	# Platillo: no girar hacia el objetivo; solo carga del haz.
	var elapsed := 0.0
	while elapsed < duration and is_instance_valid(ship) and is_inside_tree():
		var u := _smooth_step(clampf(elapsed / duration, 0.0, 1.0))
		ship.charge = u
		ship.queue_redraw()
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if is_instance_valid(ship):
		ship.charge = 1.0
		ship.queue_redraw()


func _fire_laser(ship: _ShipView, to: Vector2, color: Color, duration: float, width: float) -> void:
	if ship == null or not is_instance_valid(ship):
		return
	var beam := _LaserBeam.new()
	beam.from_pos = ship.muzzle_global()
	beam.to_pos = to
	beam.beam_color = color
	beam.beam_width = width
	beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beam.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_layer.add_child(beam)
	beam.modulate.a = 0.0
	# Retroceso suave.
	var back := ship.center_global() - (to - ship.center_global()).normalized() * 10.0
	var kick := create_tween()
	kick.tween_property(ship, "global_position", back - ship.pivot_offset, 0.08)
	kick.tween_property(ship, "global_position", ship.global_position, 0.12)
	var tw := create_tween()
	tw.tween_property(beam, "modulate:a", 1.0, duration * 0.18)
	tw.tween_interval(duration * 0.5)
	tw.tween_property(beam, "modulate:a", 0.0, duration * 0.32)
	# Actualizar origen del láser si la nave se mueve un poco.
	var elapsed := 0.0
	while elapsed < duration and is_instance_valid(beam) and is_instance_valid(ship):
		beam.from_pos = ship.muzzle_global()
		beam.queue_redraw()
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if is_instance_valid(beam):
		beam.queue_free()
	if is_instance_valid(ship):
		ship.charge = 0.0


func _explode_ball(ball: Dictionary) -> void:
	ball["alive"] = false
	var node: Control = ball.get("node")
	var center: Vector2 = ball.get("center", Vector2.ZERO)
	var color: Color = Color.WHITE
	if node is _BallProxy:
		color = (node as _BallProxy).ball_color
	if node != null and is_instance_valid(node):
		var pop := create_tween()
		pop.tween_property(node, "scale", Vector2(1.55, 1.55), 0.07)
		pop.parallel().tween_property(node, "modulate", Color(1.4, 1.4, 1.4, 1.0), 0.07)
		pop.tween_property(node, "modulate:a", 0.0, 0.14)
		pop.parallel().tween_property(node, "scale", Vector2(0.2, 0.2), 0.14)
		pop.tween_callback(node.queue_free)
	_spawn_burst(center, color, 14, 0.5)
	# Si era el último endpoint de un color, limpiar su camino del tablero.
	if _board_ref != null and is_instance_valid(_board_ref):
		var color_name := str(ball.get("color", ""))
		if _board_ref.connections.has(color_name):
			var still := false
			for other in _balls:
				if other == ball:
					continue
				if bool(other.get("alive", false)) and str(other.get("color", "")) == color_name:
					still = true
					break
			if not still:
				var conn = _board_ref.connections[color_name]
				conn.cells.clear()
				conn.completed = false
		_board_ref.queue_redraw()
	await get_tree().create_timer(0.2).timeout


func _spawn_burst(center: Vector2, color: Color, count: int, life: float) -> void:
	for i in range(count):
		var p := ColorRect.new()
		var sz := _rng.randf_range(4.0, 12.0)
		p.size = Vector2(sz, sz)
		p.color = color.lightened(_rng.randf_range(0.0, 0.4))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.pivot_offset = p.size * 0.5
		_fx_layer.add_child(p)
		p.global_position = center - p.pivot_offset
		var end := center + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(50, 180)
		var tw := create_tween()
		tw.tween_property(p, "global_position", end - p.pivot_offset, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(p, "modulate:a", 0.0, life)
		tw.tween_callback(p.queue_free)


func _clear_fx() -> void:
	_clear_children(_ball_layer)
	_clear_children(_ship_layer)
	for child in _fx_layer.get_children():
		if child != _ball_layer and child != _ship_layer:
			child.queue_free()
	_balls.clear()


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()


func _smooth_step(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return (
		u * u * u * p0
		+ 3.0 * u * u * t * p1
		+ 3.0 * u * t * t * p2
		+ t * t * t * p3
	)


class _BallProxy extends Control:
	var ball_color: Color = Color.WHITE

	func _draw() -> void:
		var c := size * 0.5
		# size ≈ diámetro neon (~0.48 * cell); rellenar casi todo el control.
		var r := mini(size.x, size.y) * 0.5
		draw_circle(c, r * 1.35, Color(ball_color.r, ball_color.g, ball_color.b, 0.3))
		draw_circle(c, r, ball_color)
		draw_circle(c + Vector2(-r * 0.28, -r * 0.28), r * 0.28, Color(1, 1, 1, 0.5))


class _ShipView extends Control:
	var ship_tex: Texture2D = null
	var beam_color: Color = Color("6DEFFF")
	var bank: float = 0.0
	var charge: float = 0.0
	var _facing: float = 0.0

	func center_global() -> Vector2:
		return global_position + pivot_offset

	func set_facing(angle: float) -> void:
		_facing = angle
		apply_tilt()

	func set_facing_smooth(angle: float, weight: float) -> void:
		_facing = lerp_angle(_facing, angle, clampf(weight, 0.0, 1.0))
		apply_tilt()

	func apply_tilt() -> void:
		# Platillo casi upright: bank acotado + leve inclinación según rumbo.
		var bank_clamped := clampf(bank, -0.08, 0.08)
		var tilt := sin(_facing) * 0.12
		rotation = bank_clamped + tilt

	func muzzle_global() -> Vector2:
		# Luces del vientre del platillo.
		var local_muzzle := Vector2(0.0, size.y * 0.38)
		return center_global() + local_muzzle.rotated(rotation)

	func _draw() -> void:
		if ship_tex != null:
			draw_texture_rect(ship_tex, Rect2(Vector2.ZERO, size), false)
		var c := size * 0.5
		if charge > 0.05:
			var glow := Color(beam_color.r, beam_color.g, beam_color.b, 0.22 + charge * 0.5)
			draw_circle(c + Vector2(0.0, size.y * 0.32), size.y * 0.06 + charge * 5.0, glow)
			draw_circle(c + Vector2(0.0, size.y * 0.32), size.y * 0.03 + charge * 2.5, Color(1, 1, 1, 0.55 + charge * 0.35))


class _LaserBeam extends Control:
	var from_pos: Vector2 = Vector2.ZERO
	var to_pos: Vector2 = Vector2.ZERO
	var beam_color: Color = Color("6DEFFF")
	var beam_width: float = 5.0

	func _draw() -> void:
		var a := from_pos - global_position
		var b := to_pos - global_position
		draw_line(a, b, Color(beam_color.r, beam_color.g, beam_color.b, 0.28), beam_width * 2.8, true)
		draw_line(a, b, beam_color, beam_width, true)
		draw_line(a, b, Color(1, 1, 1, 0.9), beam_width * 0.32, true)
		draw_circle(b, beam_width * 2.0, Color(1, 1, 1, 0.8))
		draw_circle(b, beam_width * 3.6, Color(beam_color.r, beam_color.g, beam_color.b, 0.4))
