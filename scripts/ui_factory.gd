class_name UIFactory
extends RefCounted

const FONT_REGULAR_PATH := "res://fonts/ComicNeue-Regular.ttf"
const FONT_BOLD_PATH := "res://fonts/ComicNeue-Bold.ttf"
const FONT_TITLE_PATH := "res://fonts/TitanOne-Regular.ttf"
const GlossySkin := preload("res://scripts/glossy_button_skin.gd")
const MenuBackground := preload("res://scripts/main_menu_background.gd")
const SpaceBackground := preload("res://scripts/space_background.gd")
const CrazyBackground := preload("res://scripts/backgrounds/bg_crazy.gd")
const RubikBackground := preload("res://scripts/backgrounds/bg_rubik.gd")
const MODO_CRAZY_LOGO := preload("res://assets/ui/modo_crazy_logo.png")
const SKIN_NODE_NAME := "GlossySkin"
const BUTTON_STATES: Array[String] = ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]
## Paleta roja de burbujas (índice 1 de MenuBackground.PALETTES).
const HARDCORE_PALETTE_BAND := 1

enum ButtonIcon { NONE, PLAY, MOUNTAIN, GEAR, EXIT, BACK, GRID, RESTART, BULB, HOME, SOUND, SOUND_MUTE, VIBRATION, SPARKLE, EYE }

static var _font_regular: Font
static var _font_bold: Font
static var _font_title: Font


static func font_regular() -> Font:
	if _font_regular == null:
		_font_regular = load(FONT_REGULAR_PATH) as Font
	return _font_regular


static func font_bold() -> Font:
	if _font_bold == null:
		_font_bold = load(FONT_BOLD_PATH) as Font
	return _font_bold


static func font_title() -> Font:
	if _font_title == null and ResourceLoader.exists(FONT_TITLE_PATH):
		_font_title = load(FONT_TITLE_PATH) as Font
	return _font_title


static func apply_font(control: Control, bold: bool = false) -> void:
	var font := font_bold() if bold else font_regular()
	if font == null or control == null:
		return
	control.add_theme_font_override("font", font)


## Fuente de títulos (Titan One). Si no está disponible, usa negrita.
static func apply_title_font(control: Control) -> void:
	if control == null:
		return
	var font := font_title()
	if font != null:
		control.add_theme_font_override("font", font)
	else:
		apply_font(control, true)


static func make_button(text: String, min_height: float = 64.0, accent: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, min_height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(button, accent)
	button.pressed.connect(_on_button_pressed.bind(button))
	return button


static func make_accent_button(text: String, min_height: float = 76.0) -> Button:
	return make_button(text, min_height, true)


static func make_cyan_button(text: String, min_height: float = 68.0) -> Button:
	var button := make_button(text, min_height, false)
	_style_button_variant(button, GamePalette.MENU_BLUE, GamePalette.MENU_BLUE, Color.WHITE)
	return button


static func make_orange_button(text: String, min_height: float = 72.0) -> Button:
	var button := make_button(text, min_height, true)
	_style_button_variant(button, GamePalette.MENU_ORANGE, GamePalette.MENU_ORANGE, Color.WHITE)
	return button


## Cambia el color glossy (y el del texto) de un botón creado con UIFactory.
static func set_button_colors(button: Button, base: Color, text_color: Color) -> void:
	_style_button_variant(button, base, base, text_color)
	var skin := _ensure_skin(button)
	if skin.icon != ButtonIcon.NONE:
		skin.icon_color = text_color


## Añade un icono dibujado a la izquierda del texto (como en el menú principal).
## Si el botón no tiene texto, el icono se centra (botón solo-icono).
static func set_button_icon(button: Button, icon: int, icon_color: Color = Color(-1, -1, -1)) -> void:
	var skin := _ensure_skin(button)
	skin.icon = icon
	skin.icon_color = button.get_theme_color("font_color") if icon_color.r < 0.0 else icon_color
	var icon_only := button.text.is_empty()
	skin.icon_centered = icon_only
	var body_h := maxf(button.custom_minimum_size.y, 48.0) - GlossySkin.depth_for(maxf(button.custom_minimum_size.y, 48.0))
	var left := 8.0 if icon_only else (body_h * 1.15 if icon != ButtonIcon.NONE else 22.0)
	var right := 8.0 if icon_only else 22.0
	button.set_meta("glossy_left_margin", left)
	button.set_meta("glossy_right_margin", right)
	for state: String in BUTTON_STATES:
		var sb := button.get_theme_stylebox(state) as StyleBoxFlat
		if sb != null:
			sb.content_margin_left = left
			sb.content_margin_right = right
	skin.queue_redraw()


static func _ensure_skin(button: Button) -> Control:
	var existing := button.get_node_or_null(SKIN_NODE_NAME) as Control
	if existing != null:
		return existing
	var skin := GlossySkin.new()
	skin.name = SKIN_NODE_NAME
	button.add_child(skin)
	return skin


static func _on_button_pressed(button: Button) -> void:
	if not is_instance_valid(button):
		return
	var tween := button.create_tween()
	button.pivot_offset = button.size * 0.5
	tween.tween_property(button, "scale", Vector2(0.96, 0.96), 0.06)
	tween.tween_property(button, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _style_button(button: Button, accent: bool = false) -> void:
	if accent:
		_style_button_variant(button, GamePalette.MENU_ORANGE, GamePalette.MENU_ORANGE, Color.WHITE)
	else:
		_style_button_variant(button, GamePalette.MENU_YELLOW, GamePalette.MENU_YELLOW, GamePalette.MENU_YELLOW_TEXT)


## El dibujo glossy lo hace GlossySkin (detrás del texto); los StyleBox quedan
## transparentes y solo aportan márgenes, para que el Button conserve su API.
static func _style_button_variant(button: Button, bg: Color, _hover_bg: Color, font_color: Color) -> void:
	var height := maxf(button.custom_minimum_size.y, 48.0)
	var depth := GlossySkin.depth_for(height)
	var skin := _ensure_skin(button)
	var left: float = button.get_meta("glossy_left_margin", 22.0)
	var right: float = button.get_meta("glossy_right_margin", 22.0)

	for state: String in BUTTON_STATES:
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.bg_color = Color(0, 0, 0, 0)
		sb.content_margin_left = left
		sb.content_margin_right = right
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6 + depth
		button.add_theme_stylebox_override(state, sb)

	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, font_color)
	button.add_theme_color_override("font_disabled_color", Color(font_color, 0.6))
	# Misma tipografía/tamaño que los botones del menú principal.
	button.add_theme_font_size_override("font_size", 30)
	apply_font(button, true)

	skin.base_color = bg
	skin.queue_redraw()


static func make_title(text: String, size: int = 48) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", GamePalette.TEXT_PRIMARY)
	apply_title_font(label)
	return label


static func make_neon_title(text: String, size: int = 52) -> Label:
	var label := make_title(text, size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", GamePalette.MENU_TITLE_OUTLINE)
	label.add_theme_constant_override("outline_size", maxi(6, int(size / 6.0)))
	label.add_theme_color_override("font_shadow_color", GamePalette.MENU_TITLE_SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", maxi(3, int(size / 14.0)))
	label.add_theme_constant_override("shadow_outline_size", maxi(6, int(size / 6.0)))
	return label


## Logotipo PNG de Modo Crazy (hub + partida).
static func make_crazy_logo_title(height_px: float = 160.0) -> Control:
	var wrap := CenterContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var logo := TextureRect.new()
	logo.texture = MODO_CRAZY_LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := maxf(72.0, height_px)
	var tex_w := float(MODO_CRAZY_LOGO.get_width()) if MODO_CRAZY_LOGO != null else 700.0
	var tex_h := float(MODO_CRAZY_LOGO.get_height()) if MODO_CRAZY_LOGO != null else 549.0
	var aspect := tex_w / maxf(1.0, tex_h)
	logo.custom_minimum_size = Vector2(h * aspect, h)
	wrap.add_child(logo)
	return wrap


## Subtítulo legible sobre el fondo azul profundo del menú.
static func make_light_subtitle(text: String, size: int = 20) -> Label:
	var label := make_subtitle(text, size)
	label.add_theme_color_override("font_color", GamePalette.MENU_TEXT_LIGHT)
	return label


static func make_subtitle(text: String, size: int = 20) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", GamePalette.TEXT_SECONDARY)
	apply_font(label, false)
	return label


static func make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = GamePalette.CREAM
	style.border_color = GamePalette.CREAM_BORDER
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_left = 28
	style.corner_radius_bottom_right = 28
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	style.shadow_color = Color(0.2, 0.1, 0.05, 0.28)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 5)
	panel.add_theme_stylebox_override("panel", style)
	return panel


## Panel translúcido azul oscuro (como el panel de progreso del menú principal).
static func make_glass_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.14, 0.45, 0.75)
	style.border_color = Color(0.45, 0.65, 1.0, 0.5)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_color = Color(0, 0, 0.2, 0.35)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	return panel


static func attach_neon_background(parent: Control, _intense: bool = false) -> Control:
	var decor := MenuBackground.new()
	decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(decor)
	parent.move_child(decor, 0)
	return decor


static func apply_hardcore_background(bg: Control) -> void:
	if bg != null and bg.has_method("set_palette_band"):
		bg.call("set_palette_band", HARDCORE_PALETTE_BAND)


static func attach_rubik_background(parent: Control) -> Control:
	var decor := RubikBackground.new()
	decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	decor.add_to_group("level_bg_fx")
	parent.add_child(decor)
	parent.move_child(decor, 0)
	return decor


static func attach_crazy_background(parent: Control) -> Control:
	var decor := CrazyBackground.new()
	decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(decor)
	parent.move_child(decor, 0)
	return decor


static func attach_space_background(parent: Control, level_id: int = 100) -> Control:
	var decor := SpaceBackground.new()
	decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if decor.has_method("set_palette_band"):
		decor.call("set_palette_band", LevelBackdrop.emoji_space_palette_band(level_id))
	parent.add_child(decor)
	parent.move_child(decor, 0)
	return decor


## Fondo según era del nivel: motivos 1–99; espacio desde era Emoji (100+).
## Sandbox: siempre burbujas, color de fondo por banda de 10 niveles.
## Hardcore: burbujas rojas (salvo era Emoji/espacio).
static func attach_level_background(parent: Control, level_id: int) -> Control:
	if LevelManager != null and LevelManager.current_mode == LevelManager.MODE_CHRONO:
		return attach_crazy_background(parent)
	if LevelManager != null and LevelManager.current_mode == LevelManager.MODE_SANDBOX:
		var sand := MenuBackground.new()
		sand.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sand.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sand.set_palette_band(LevelBackdrop.sandbox_palette_band(level_id))
		sand.add_to_group("level_bg_fx")
		parent.add_child(sand)
		parent.move_child(sand, 0)
		return sand
	if LevelManager != null and LevelManager.current_mode == LevelManager.MODE_RUBIK:
		return attach_rubik_background(parent)
	if LevelManager != null and LevelManager.current_mode == LevelManager.MODE_HARDCORE:
		if BoardTheme.uses_emoji(level_id) or BoardTheme.kind_for_level(level_id) == BoardTheme.Kind.CONTRAST:
			return attach_space_background(parent, level_id)
		var hardcore_bg := MenuBackground.new()
		hardcore_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hardcore_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hardcore_bg.set_palette_band(HARDCORE_PALETTE_BAND)
		hardcore_bg.add_to_group("level_bg_fx")
		parent.add_child(hardcore_bg)
		parent.move_child(hardcore_bg, 0)
		return hardcore_bg
	if BoardTheme.uses_emoji(level_id) or BoardTheme.kind_for_level(level_id) == BoardTheme.Kind.CONTRAST:
		return attach_space_background(parent, level_id)
	var decor := LevelBackdrop.create_for_level(level_id)
	parent.add_child(decor)
	parent.move_child(decor, 0)
	return decor


static func play_enter_animation(nodes: Array, delay_step: float = 0.06) -> void:
	var i := 0
	for node_variant: Variant in nodes:
		var node := node_variant as CanvasItem
		if node == null:
			continue
		node.modulate = Color(1, 1, 1, 0)
		if node is Control:
			(node as Control).scale = Vector2(0.94, 0.94)
			(node as Control).pivot_offset = (node as Control).size * 0.5
		var tween := node.create_tween()
		tween.tween_interval(delay_step * float(i))
		tween.tween_property(node, "modulate:a", 1.0, 0.28)
		if node is Control:
			tween.parallel().tween_property(node, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1
