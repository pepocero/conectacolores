extends Node2D
class_name SandBoard

@export_group("Tablero")
@export var board_size: Vector2 = Vector2(720, 720)
@export_range(256, 1024, 128) var texture_resolution: int = 512
@export var board_margin: float = 18.0
@export var background_color: Color = Color("#49301e")

@export_group("Surco")
@export_range(8.0, 64.0, 1.0) var brush_size: float = 30.0
@export_range(0.5, 1.0, 0.05) var groove_depth: float = 0.9
@export_range(0.0, 1.0, 0.05) var edge_irregularity: float = 0.55

@export_group("Particulas")
@export_range(0, 12, 1) var particles_per_stamp: int = 4
@export_range(0.2, 1.5, 0.1) var particle_lifetime: float = 0.55
@export_range(10.0, 180.0, 5.0) var particle_speed: float = 78.0

var sand_image: Image
var sand_texture: ImageTexture
var groove_image: Image
var groove_texture: ImageTexture

var noise := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var drawing := false
var last_pos := Vector2.ZERO
var particles: Array[Dictionary] = []


func _ready() -> void:
	rng.randomize()

	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.025

	create_textures()
	queue_redraw()


func create_textures() -> void:
	var res := texture_resolution

	sand_image = Image.create(
		res, res, false, Image.FORMAT_RGBA8
	)
	groove_image = Image.create(
		res, res, false, Image.FORMAT_RGBA8
	)

	# Arena con variaciones de color y pequeñas motas.
	for y in range(res):
		for x in range(res):
			var broad := noise.get_noise_2d(
				float(x), float(y)
			)

			var fine := noise.get_noise_2d(
				float(x) * 4.0 + 71.0,
				float(y) * 4.0 - 29.0
			)

			var n := (
				broad * 0.09
				+ fine * 0.035
				+ rng.randf_range(-0.025, 0.025)
			)

			var c := Color(
				clampf(0.77 + n, 0.0, 1.0),
				clampf(0.53 + n * 0.8, 0.0, 1.0),
				clampf(0.30 + n * 0.5, 0.0, 1.0),
				1.0
			)

			if rng.randf() < 0.02:
				var variation := rng.randf_range(-0.12, 0.08)
				c.r = clampf(c.r + variation, 0.0, 1.0)
				c.g = clampf(c.g + variation * 0.8, 0.0, 1.0)
				c.b = clampf(c.b + variation * 0.5, 0.0, 1.0)

			sand_image.set_pixel(x, y, c)

	sand_texture = ImageTexture.create_from_image(sand_image)
	groove_texture = ImageTexture.create_from_image(groove_image)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var p := to_local(event.position)

		if event.pressed and inside_board(p):
			drawing = true
			last_pos = p
			carve_line(p, p)
			get_viewport().set_input_as_handled()
		elif not event.pressed:
			drawing = false

	elif event is InputEventScreenDrag and drawing:
		var p := to_local(event.position)

		if inside_board(p):
			carve_line(last_pos, p)
			last_pos = p
			get_viewport().set_input_as_handled()

	# Control con ratón para probar en PC.
	elif event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		var p := to_local(event.position)

		if event.pressed and inside_board(p):
			drawing = true
			last_pos = p
			carve_line(p, p)
			get_viewport().set_input_as_handled()
		else:
			drawing = false

	elif (
		event is InputEventMouseMotion
		and drawing
		and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	):
		var p := to_local(event.position)

		if inside_board(p):
			carve_line(last_pos, p)
			last_pos = p
			get_viewport().set_input_as_handled()


func inside_board(p: Vector2) -> bool:
	return Rect2(Vector2.ZERO, board_size).has_point(p)


func carve_line(a: Vector2, b: Vector2) -> void:
	var distance := a.distance_to(b)
	var step := maxf(brush_size * 0.15, 1.5)
	var count := maxi(1, int(ceil(distance / step)))

	for i in range(count + 1):
		var p := a.lerp(b, float(i) / float(count))
		stamp_groove(p)

	spawn_particles(b, a.direction_to(b))

	groove_texture.update(groove_image)
	queue_redraw()


func stamp_groove(p: Vector2) -> void:
	var res := texture_resolution

	var center := Vector2(
		p.x / board_size.x * float(res - 1),
		p.y / board_size.y * float(res - 1)
	)

	var radius_x := brush_size * 0.5 * res / board_size.x
	var radius_y := brush_size * 0.5 * res / board_size.y
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

			# Borde irregular, evitando un círculo perfecto.
			var wobble := noise.get_noise_2d(
				float(x) * 0.18,
				float(y) * 0.18
			) * edge_irregularity * 0.13

			d += wobble

			if d > 1.55:
				continue

			var alpha := 0.0
			var color := Color("#5b391d")

			# 1. Centro hundido y oscuro.
			if d < 0.48:
				alpha = groove_depth

				var variation := noise.get_noise_2d(
					float(x) * 0.3,
					float(y) * 0.3
				) * 0.035

				color = Color(
					0.22 + variation,
					0.12 + variation * 0.5,
					0.055 + variation * 0.3
				)

			# 2. Pared interior: transición hacia la luz.
			elif d < 0.82:
				var t := (d - 0.48) / 0.34

				alpha = groove_depth * 0.92

				color = Color(
					0.25 + t * 0.13,
					0.135 + t * 0.075,
					0.06 + t * 0.035
				)

			# 3. Labio de arena desplazada.
			elif d < 1.08:
				var t := (d - 0.82) / 0.26

				var irregular_light := noise.get_noise_2d(
					float(x) * 0.12,
					float(y) * 0.12
				)

				alpha = clampf(
					(1.0 - t) * 0.72
					+ irregular_light * 0.10,
					0.0,
					0.78
				)

				color = Color("#e3b573")

			# 4. Sombra exterior suave.
			elif d < 1.55:
				var t := (d - 1.08) / 0.47
				alpha = (1.0 - t) * 0.22
				color = Color("#59371b")

			var old := groove_image.get_pixel(x, y)

			# Composición alfa para unir sellos sin círculos visibles.
			var out_alpha := alpha + old.a * (1.0 - alpha)

			if out_alpha <= 0.001:
				continue

			var out_color := Color(
				(
					color.r * alpha
					+ old.r * old.a * (1.0 - alpha)
				) / out_alpha,
				(
					color.g * alpha
					+ old.g * old.a * (1.0 - alpha)
				) / out_alpha,
				(
					color.b * alpha
					+ old.b * old.a * (1.0 - alpha)
				) / out_alpha,
				out_alpha
			)

			groove_image.set_pixel(x, y, out_color)


func spawn_particles(pos: Vector2, direction: Vector2) -> void:
	if particles_per_stamp <= 0:
		return
	if direction.length_squared() < 0.0001:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()

	var side := Vector2(-direction.y, direction.x)

	for _i in range(particles_per_stamp):
		var sign_side := -1.0 if rng.randf() < 0.5 else 1.0

		var velocity := side * sign_side * rng.randf_range(
			15.0, particle_speed * 0.55
		)

		velocity += Vector2(
			rng.randf_range(-22.0, 22.0),
			rng.randf_range(-22.0, 22.0)
		)

		particles.append({
			"pos": pos + side * sign_side * brush_size * 0.4,
			"vel": velocity,
			"life": rng.randf_range(
				particle_lifetime * 0.5,
				particle_lifetime
			),
			"max_life": particle_lifetime,
			"radius": rng.randf_range(1.0, 2.8),
			"color": [
				Color("#e6bd7e"),
				Color("#c18a4a"),
				Color("#f2d6a0")
			][rng.randi_range(0, 2)]
		})


func _process(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[i]

		particle["life"] = float(particle["life"]) - delta
		particle["pos"] = (particle["pos"] as Vector2) + (particle["vel"] as Vector2) * delta
		particle["vel"] = (particle["vel"] as Vector2) * (1.0 - minf(delta * 2.0, 0.8))

		particles[i] = particle

		if float(particle["life"]) <= 0.0:
			particles.remove_at(i)

	if not particles.is_empty():
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, board_size)

	# Marco del tablero.
	draw_rect(rect.grow(board_margin), background_color)
	draw_rect(rect.grow(5.0), Color("#986338"))
	draw_rect(rect, Color("#d6a05e"))

	# Arena y surco persistente.
	draw_texture_rect(sand_texture, rect, false)
	draw_texture_rect(groove_texture, rect, false)

	# Granos desplazados durante el gesto.
	for particle in particles:
		var life_ratio := clampf(
			float(particle["life"]) / maxf(float(particle["max_life"]), 0.001),
			0.0,
			1.0
		)

		var c: Color = particle["color"]
		c.a = life_ratio

		draw_circle(
			particle["pos"],
			float(particle["radius"]) * (0.4 + life_ratio * 0.6),
			c
		)


func clear_grooves() -> void:
	groove_image.fill(Color(0, 0, 0, 0))
	groove_texture.update(groove_image)
	particles.clear()
	queue_redraw()


func set_brush_size(value: float) -> void:
	brush_size = clampf(value, 8.0, 64.0)


func get_groove_texture() -> Texture2D:
	return groove_texture
