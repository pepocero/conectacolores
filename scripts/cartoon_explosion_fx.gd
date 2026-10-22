class_name CartoonExplosionFx
extends Node2D

## Explosión 2D liviana: flipbook 8×8 (sprite sheet).
## Misma API que el boom anterior (setup_at / start_explosion / seconds_until_peak_size).

const SHEET := preload("res://assets/fx/ball_explosion_sheet.png")
const COLS := 8
const ROWS := 8
const FRAME_COUNT := COLS * ROWS
## Pico visual ≈ segundo flash (hacia la fila 5 del sheet).
const PEAK_FRAC := 0.55
const ANIM_NAME := &"boom"
## FPS base del SpriteFrames; start_explosion ajusta speed_scale.
const BASE_FPS := 24.0
## Fracción del frame que ocupa el fuego (el resto es margen negro).
## Así `diameter` ≈ tamaño visual real en pantalla.
const SHEET_CONTENT_FRAC := 0.52

static var _shared_frames: SpriteFrames

var _sprite: AnimatedSprite2D
var _mat: CanvasItemMaterial


## Segundos desde el inicio hasta el tamaño máximo (handoff era / rotura).
static func seconds_until_peak_size(duration_sec: float) -> float:
	return maxf(0.35, duration_sec) * PEAK_FRAC


static func _get_shared_frames() -> SpriteFrames:
	if _shared_frames != null:
		return _shared_frames
	var frames := SpriteFrames.new()
	frames.add_animation(ANIM_NAME)
	frames.set_animation_loop(ANIM_NAME, false)
	frames.set_animation_speed(ANIM_NAME, BASE_FPS)
	var tex: Texture2D = SHEET
	var fw := float(tex.get_width()) / float(COLS)
	var fh := float(tex.get_height()) / float(ROWS)
	for i in range(FRAME_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(float(i % COLS) * fw, float(int(i / COLS)) * fh, fw, fh)
		frames.add_frame(ANIM_NAME, atlas)
	_shared_frames = frames
	return _shared_frames


func _init() -> void:
	z_as_relative = false
	_mat = CanvasItemMaterial.new()
	_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sprite = AnimatedSprite2D.new()
	_sprite.centered = true
	_sprite.material = _mat
	_sprite.sprite_frames = _get_shared_frames()
	_sprite.visible = false
	_sprite.animation_finished.connect(_on_anim_finished)
	add_child(_sprite)
	visible = false


## draw_scale_override > 0: escala extra (era / muchas bolas). force_lite se ignora.
func setup_at(
	center: Vector2,
	diameter: float,
	tint: Color = Color.WHITE,
	draw_scale_override: float = -1.0,
	_force_lite_override: int = -1
) -> void:
	if top_level:
		global_position = center
	else:
		position = center

	var frames := _get_shared_frames()
	_sprite.sprite_frames = frames
	var tex0: Texture2D = frames.get_frame_texture(ANIM_NAME, 0)
	var frame_side := 64.0
	if tex0 != null:
		frame_side = float(maxi(tex0.get_width(), tex0.get_height()))

	var visual_side := maxf(diameter, 20.0)
	# Compensar margen negro del sheet para que el fuego ≈ `diameter`.
	var s := visual_side / maxf(frame_side * SHEET_CONTENT_FRAC, 1.0)
	# draw_scale_override ya no reduce el tamaño (era undersample del shader).
	if draw_scale_override > 0.0 and draw_scale_override < 0.999:
		s *= clampf(lerpf(0.85, 1.0, draw_scale_override), 0.85, 1.0)
	_sprite.scale = Vector2(s, s)

	# Tint suave: no apagar el amarillo/naranja del sheet.
	var m := Color(
		lerpf(1.0, tint.r, 0.35),
		lerpf(1.0, tint.g, 0.35),
		lerpf(1.0, tint.b, 0.35),
		1.0
	)
	modulate = m
	_sprite.modulate = Color.WHITE
	_sprite.visible = false
	visible = true


func start_explosion(duration_sec: float) -> void:
	if _sprite == null:
		return
	var dur := maxf(0.35, duration_sec)
	_sprite.sprite_frames = _get_shared_frames()
	_sprite.visible = true
	visible = true
	# Reproducir los 64 frames en `dur` segundos.
	_sprite.speed_scale = (float(FRAME_COUNT) / dur) / BASE_FPS
	_sprite.frame = 0
	_sprite.play(ANIM_NAME)


func _on_anim_finished() -> void:
	if is_instance_valid(_sprite):
		_sprite.visible = false
	visible = false
