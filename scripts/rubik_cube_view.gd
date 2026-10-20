extends Control
## Vista 3D del cubo Rubik: girar libremente y elegir cara (tablero plano aparte).
## Las caras muestran preview del puzzle; el picking es geométrico (sin PhysicsServer).

signal face_selected(face_index: int)
signal face_already_done(face_index: int)

const FACE_COUNT := 6
const FACE_COLORS: Array[Color] = [
	Color("C41E3A"), # F
	Color("FF5800"), # B
	Color("FFFFFF"), # U
	Color("FFD500"), # D
	Color("009B48"), # L
	Color("0051BA"), # R
]
const DONE_TINT := Color("2ECC71")
const CUBE_HALF := 0.52
const FACE_SIZE := CUBE_HALF * 1.86
const DRAG_SENS := 0.012
const TAP_SLOP_PX := 14.0
const PREVIEW_PX := 160

var _viewport: SubViewport
var _container: SubViewportContainer
var _world: Node3D
var _pivot: Node3D
var _camera: Camera3D
var _face_bodies: Array[Node3D] = []
var _face_meshes: Array[MeshInstance3D] = []
var _face_levels: Array = []
var _done_mask: int = 0
var _dragging: bool = false
var _drag_moved: bool = false
var _press_pos := Vector2.ZERO
var _press_start := Vector2.ZERO
var _yaw: float = 0.55
var _pitch: float = -0.35
var _hint_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_apply_rotation()
	set_process(false)
	call_deferred("_sync_viewport_size")


func setup(done_mask: int, faces: Array = []) -> void:
	_done_mask = clampi(done_mask, 0, (1 << FACE_COUNT) - 1)
	_face_levels = faces.duplicate()
	_refresh_face_materials()
	_update_hint()


func celebrate_face(face_index: int) -> void:
	if face_index < 0 or face_index >= FACE_COUNT:
		return
	_done_mask |= 1 << face_index
	_refresh_face_materials()
	_update_hint()
	var target_yaw := _yaw
	var target_pitch := _pitch
	match face_index:
		0:
			target_yaw = 0.0
			target_pitch = 0.0
		1:
			target_yaw = PI
			target_pitch = 0.0
		2:
			target_yaw = _yaw
			target_pitch = -PI * 0.45
		3:
			target_yaw = _yaw
			target_pitch = PI * 0.45
		4:
			target_yaw = -PI * 0.5
			target_pitch = 0.0
		5:
			target_yaw = PI * 0.5
			target_pitch = 0.0
	# Elegir el ángulo equivalente más cercano (órbita vertical infinita).
	target_yaw = _yaw + wrapf(target_yaw - _yaw, -PI, PI)
	target_pitch = _pitch + wrapf(target_pitch - _pitch, -PI, PI)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_orbit, Vector2(_yaw, _pitch), Vector2(target_yaw, target_pitch), 0.55)


func _set_orbit(v: Vector2) -> void:
	_yaw = v.x
	_pitch = v.y
	_apply_rotation()


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 22)
	_hint_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 0.95))
	_hint_label.text = "Gira el cubo · Toca una cara libre"
	root.add_child(_hint_label)

	_container = SubViewportContainer.new()
	_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_container.gui_input.connect(_on_viewport_gui_input)
	root.add_child(_container)

	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	# Godot 4.2 / Compatibility: asegurar World3D propio (evita world_3d null).
	_viewport.world_3d = World3D.new()
	_viewport.handle_input_locally = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_viewport.size = Vector2i(512, 512)
	_container.add_child(_viewport)

	_world = Node3D.new()
	_viewport.add_child(_world)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.07, 0.14)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.7)
	environment.ambient_light_energy = 0.85
	env.environment = environment
	_world.add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 35, 0)
	light.light_energy = 1.2
	_world.add_child(light)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.2, 1.4, 1.6)
	fill.light_energy = 0.6
	_world.add_child(fill)

	_pivot = Node3D.new()
	_world.add_child(_pivot)

	_camera = Camera3D.new()
	_camera.position = Vector3(0, 0, 3.35)
	_camera.fov = 38.0
	_camera.current = true
	_world.add_child(_camera)

	_face_bodies.clear()
	_face_meshes.clear()
	for i in range(FACE_COUNT):
		_add_face(i)

	var core := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(CUBE_HALF * 1.92, CUBE_HALF * 1.92, CUBE_HALF * 1.92)
	core.mesh = box
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.08, 0.08, 0.1)
	core_mat.roughness = 0.85
	core.material_override = core_mat
	_pivot.add_child(core)


func _add_face(index: int) -> void:
	var body := Node3D.new()
	body.set_meta("face_index", index)

	var mesh_i := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(FACE_SIZE, FACE_SIZE)
	mesh_i.mesh = quad
	body.add_child(mesh_i)

	match index:
		0: # F +Z
			body.position = Vector3(0, 0, CUBE_HALF)
		1: # B -Z
			body.position = Vector3(0, 0, -CUBE_HALF)
			body.rotation_degrees = Vector3(0, 180, 0)
		2: # U +Y
			body.position = Vector3(0, CUBE_HALF, 0)
			body.rotation_degrees = Vector3(-90, 0, 0)
		3: # D -Y
			body.position = Vector3(0, -CUBE_HALF, 0)
			body.rotation_degrees = Vector3(90, 0, 0)
		4: # L -X
			body.position = Vector3(-CUBE_HALF, 0, 0)
			body.rotation_degrees = Vector3(0, -90, 0)
		5: # R +X
			body.position = Vector3(CUBE_HALF, 0, 0)
			body.rotation_degrees = Vector3(0, 90, 0)

	_pivot.add_child(body)
	_face_bodies.append(body)
	_face_meshes.append(mesh_i)


func _refresh_face_materials() -> void:
	for i in range(_face_meshes.size()):
		var done := (_done_mask & (1 << i)) != 0
		var face: Dictionary = {}
		if i < _face_levels.size() and typeof(_face_levels[i]) == TYPE_DICTIONARY:
			face = _face_levels[i]
		var tex := _build_board_preview_texture(face, i, done)
		var mat := StandardMaterial3D.new()
		mat.roughness = 0.55
		mat.metallic = 0.02
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if tex != null:
			mat.albedo_texture = tex
			mat.albedo_color = Color.WHITE
		else:
			mat.albedo_color = FACE_COLORS[i]
		if done:
			mat.albedo_color = mat.albedo_color.lerp(DONE_TINT, 0.28)
			mat.emission_enabled = true
			mat.emission = DONE_TINT * 0.3
			mat.emission_energy_multiplier = 0.7
		else:
			mat.emission_enabled = false
		_face_meshes[i].material_override = mat


func _build_board_preview_texture(face: Dictionary, face_index: int, done: bool) -> Texture2D:
	var grid := int(face.get("size", 0))
	var img := Image.create(PREVIEW_PX, PREVIEW_PX, false, Image.FORMAT_RGBA8)
	var rim: Color = FACE_COLORS[face_index % FACE_COLORS.size()]
	var board_bg := Color(0.12, 0.16, 0.28)
	var cell_col := Color(0.18, 0.24, 0.4)
	var line_col := Color(0.08, 0.1, 0.18, 0.95)
	img.fill(rim.darkened(0.35))

	var pad := 10
	var board_rect := Rect2i(pad, pad, PREVIEW_PX - pad * 2, PREVIEW_PX - pad * 2)
	_fill_rect(img, board_rect, board_bg)

	if grid < 2:
		# Placeholder mientras no hay datos de cara.
		_fill_rect(img, board_rect.grow(-6), cell_col)
		_stroke_rect(img, board_rect, rim, 4)
		return ImageTexture.create_from_image(img)

	var cell := float(board_rect.size.x) / float(grid)
	for y in range(grid):
		for x in range(grid):
			var r := Rect2i(
				board_rect.position.x + int(x * cell) + 1,
				board_rect.position.y + int(y * cell) + 1,
				maxi(1, int(cell) - 2),
				maxi(1, int(cell) - 2)
			)
			_fill_rect(img, r, cell_col)

	# Rejilla.
	for i in range(grid + 1):
		var px := board_rect.position.x + int(round(float(i) * cell))
		var py := board_rect.position.y + int(round(float(i) * cell))
		_fill_rect(img, Rect2i(px, board_rect.position.y, 1, board_rect.size.y), line_col)
		_fill_rect(img, Rect2i(board_rect.position.x, py, board_rect.size.x, 1), line_col)

	var dots: Array = face.get("dots", [])
	for dot_v: Variant in dots:
		if typeof(dot_v) != TYPE_DICTIONARY:
			continue
		var dot: Dictionary = dot_v
		var cx := int(dot.get("x", -1))
		var cy := int(dot.get("y", -1))
		if cx < 0 or cy < 0 or cx >= grid or cy >= grid:
			continue
		var color_name := str(dot.get("color", ""))
		var ball := GamePalette.get_color(color_name)
		var center := Vector2(
			float(board_rect.position.x) + (float(cx) + 0.5) * cell,
			float(board_rect.position.y) + (float(cy) + 0.5) * cell
		)
		var radius := maxf(2.0, cell * 0.32)
		_fill_circle(img, center, radius, ball)
		_fill_circle(img, center + Vector2(-radius * 0.25, -radius * 0.25), radius * 0.28, ball.lightened(0.35))

	_stroke_rect(img, board_rect, rim.lightened(0.1), 3)
	if done:
		# Marca de resuelto (esquina).
		_fill_circle(img, Vector2(PREVIEW_PX - 22, 22), 14.0, DONE_TINT)
		_fill_circle(img, Vector2(PREVIEW_PX - 22, 22), 8.0, Color.WHITE)

	return ImageTexture.create_from_image(img)


func _fill_rect(img: Image, rect: Rect2i, color: Color) -> void:
	var r := rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x <= 0 or r.size.y <= 0:
		return
	img.fill_rect(r, color)


func _stroke_rect(img: Image, rect: Rect2i, color: Color, width: int) -> void:
	var w := maxi(1, width)
	_fill_rect(img, Rect2i(rect.position.x, rect.position.y, rect.size.x, w), color)
	_fill_rect(img, Rect2i(rect.position.x, rect.end.y - w, rect.size.x, w), color)
	_fill_rect(img, Rect2i(rect.position.x, rect.position.y, w, rect.size.y), color)
	_fill_rect(img, Rect2i(rect.end.x - w, rect.position.y, w, rect.size.y), color)


func _fill_circle(img: Image, center: Vector2, radius: float, color: Color) -> void:
	var r2 := radius * radius
	var min_x := maxi(0, int(floor(center.x - radius)))
	var max_x := mini(img.get_width() - 1, int(ceil(center.x + radius)))
	var min_y := maxi(0, int(floor(center.y - radius)))
	var max_y := mini(img.get_height() - 1, int(ceil(center.y + radius)))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var dx := float(x) + 0.5 - center.x
			var dy := float(y) + 0.5 - center.y
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, color)


func _update_hint() -> void:
	if _hint_label == null:
		return
	var done := 0
	for i in range(FACE_COUNT):
		if (_done_mask & (1 << i)) != 0:
			done += 1
	_hint_label.text = "Gira el cubo · Toca una cara libre · %d/%d" % [done, FACE_COUNT]


func _apply_rotation() -> void:
	if _pivot == null:
		return
	_pivot.rotation = Vector3(_pitch, _yaw, 0.0)


func _on_viewport_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_begin_drag(st.position)
		else:
			_end_drag(st.position)
		accept_event()
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if not _dragging:
			_begin_drag(sd.position)
		_apply_drag_delta(sd.relative)
		_press_pos = sd.position
		accept_event()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_begin_drag(mb.position)
		else:
			_end_drag(mb.position)
		accept_event()
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_apply_drag_delta(mm.relative)
			_press_pos = mm.position
			accept_event()


func _begin_drag(pos: Vector2) -> void:
	_dragging = true
	_drag_moved = false
	_press_pos = pos
	_press_start = pos


## rel: movimiento del dedo/ratón en píxeles (Y+ = hacia abajo en pantalla).
## REGLA: arrastrar abajo → el cubo gira abajo; arrastrar arriba → gira arriba.
## Con rotation.x = pitch: pitch += rel.y (confirmado en juego; no usar -=).
func _apply_drag_delta(rel: Vector2) -> void:
	if not _dragging:
		return
	if rel.length() > TAP_SLOP_PX * 0.35:
		_drag_moved = true
	_yaw += rel.x * DRAG_SENS
	# Vertical libre (sin tope), misma dirección que el dedo.
	_pitch += rel.y * DRAG_SENS
	_apply_rotation()


func _end_drag(pos: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	if _drag_moved or pos.distance_to(_press_start) > TAP_SLOP_PX:
		return
	_try_select_face(pos)


func _try_select_face(screen_pos: Vector2) -> void:
	if _camera == null or _viewport == null or _container == null:
		return
	var vp_pos := screen_pos
	var cs := _container.size
	if cs.x > 1.0 and cs.y > 1.0:
		vp_pos = Vector2(
			screen_pos.x * float(_viewport.size.x) / cs.x,
			screen_pos.y * float(_viewport.size.y) / cs.y
		)
	var from := _camera.project_ray_origin(vp_pos)
	var dir := _camera.project_ray_normal(vp_pos)
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()

	# Picking geométrico: no depende de PhysicsServer / world_3d.
	var best_face := -1
	var best_dist := INF
	var half := FACE_SIZE * 0.5
	for i in range(_face_bodies.size()):
		var body: Node3D = _face_bodies[i]
		if body == null or not is_instance_valid(body):
			continue
		var xf := body.global_transform
		var origin := xf.origin
		var normal := xf.basis.z.normalized()
		var denom := dir.dot(normal)
		if absf(denom) < 0.0001:
			continue
		# Solo caras orientadas hacia la cámara.
		var to_cam := (from - origin).normalized()
		if normal.dot(to_cam) <= 0.05:
			continue
		var t := (origin - from).dot(normal) / denom
		if t <= 0.0 or t >= best_dist:
			continue
		var hit := from + dir * t
		var local := xf.affine_inverse() * hit
		if absf(local.x) <= half and absf(local.y) <= half and absf(local.z) <= 0.08:
			best_dist = t
			best_face = i

	if best_face < 0:
		return
	if (_done_mask & (1 << best_face)) != 0:
		face_already_done.emit(best_face)
		return
	face_selected.emit(best_face)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_viewport_size()


func _sync_viewport_size() -> void:
	if _viewport == null or _container == null:
		return
	var s := _container.size
	if s.x < 8.0 or s.y < 8.0:
		return
	_viewport.size = Vector2i(maxi(64, int(s.x)), maxi(64, int(s.y)))
