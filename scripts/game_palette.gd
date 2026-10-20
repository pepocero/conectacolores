class_name GamePalette
extends RefCounted

## UI glossy casual — COLORS del puzle no dependen de estos.

const BACKGROUND := Color("4A9FE0")
const BACKGROUND_ALT := Color("3B8AD0")
const BACKGROUND_VIOLET := Color("2F6FB8")
const PANEL := Color(0.98, 0.95, 0.90, 0.96)
const PANEL_SOLID := Color("121A38")
const PANEL_LIGHT := Color("FFE8C8")
const BOARD_FILL := Color("121A38")
const TEXT_PRIMARY := Color("3D2A1A")
const TEXT_SECONDARY := Color("5C4636")
const ACCENT := Color("F5C542")
const ACCENT_BLUE := Color("5EC8F0")
const ACCENT_MAGENTA := Color("E85A7A")
const BUTTON := Color("F6C84C")
const BUTTON_HOVER := Color("FFD86A")
const BUTTON_BORDER := Color("FFFFFF")
const BUTTON_TEXT := Color("4A2C14")
const BUTTON_ORANGE := Color("F07830")
const BUTTON_ORANGE_HOVER := Color("FF8C42")
const BUTTON_CYAN := Color("7ED6F5")
const BUTTON_CYAN_HOVER := Color("A0E4FF")
const SCORE_NAVY := Color("2A3A6E")
const CREAM := Color("FFF8EE")
const CREAM_BORDER := Color("D4B896")
const SUNBURST := Color("7FD9F5")
const SUNBURST_ALT := Color("B8ECFF")
const SUCCESS := Color("5FCF6A")
const WARNING := Color("FFE45E")
const DANGER := Color("E85A5A")

# Botones y textos del estilo del menú principal (fondo azul profundo).
const MENU_ORANGE := Color("FF8A1F")
const MENU_YELLOW := Color("FFC52E")
const MENU_YELLOW_TEXT := Color("5A3410")
const MENU_PURPLE := Color("9A52E6")
const MENU_BLUE := Color("2F8CF0")
const MENU_GREEN := Color("3FC65E")
const MENU_TEXT_LIGHT := Color("D6E6FF")
const MENU_VALUE := Color("B4F03A")
const MENU_TITLE_OUTLINE := Color("2F6EEA")
const MENU_TITLE_SHADOW := Color("0D1E66")
const MENU_DEEP_BLUE := Color("1E44B6")
const MENU_DARKEST := Color("1A3AA6")

const COLORS := {
	"cyan": Color("00F5FF"),
	"orange": Color("FF9F1C"),
	"green": Color("B8FF35"),
	"pink": Color("FF4D8D"),
	"yellow": Color("FFE45E"),
	"violet": Color("A855F7"),
	"red": Color("FF3B30"),
	"blue": Color("4DA3FF"),
	"white": Color("F5F7FA"),
	"teal": Color("2EE6A6"),
	"magenta": Color("FF2BD6"),
	"brown": Color("B0703A"),
	"gray": Color("8C96A8"),
	"navy": Color("3046C8"),
	"salmon": Color("FF8A7A"),
	"olive": Color("8FA02B"),
}

## Daltonismo: pares de tonos opuestos (complementarios) + contraste claro/oscuro.
## Cada color queda lejos en matiz y luminosidad de los vecinos habituales del nivel.
const COLORS_DEUTERANOPIA := {
	"cyan": Color("00E5FF"),      # cian ↔ naranja
	"orange": Color("FF5A00"),
	"green": Color("00C853"),     # verde ↔ magenta
	"pink": Color("FF1493"),
	"yellow": Color("FFD600"),    # amarillo ↔ azul marino
	"violet": Color("7C4DFF"),    # violeta ↔ oliva limón
	"red": Color("FF1744"),       # rojo ↔ turquesa
	"blue": Color("2979FF"),      # azul ↔ marrón ámbar
	"white": Color("FAFAFA"),     # blanco ↔ gris pizarra
	"teal": Color("00BFA5"),
	"magenta": Color("D500F9"),
	"brown": Color("8D6E63"),
	"gray": Color("455A64"),
	"navy": Color("1A237E"),
	"salmon": Color("FF6E40"),    # coral ↔ oliva
	"olive": Color("C6FF00"),
}

## Figura geométrica que acompaña a cada color (se dibuja dentro de la bola).
const SHAPES := {
	"cyan": "circle",
	"orange": "square",
	"green": "triangle",
	"pink": "diamond",
	"yellow": "star",
	"violet": "hexagon",
	"red": "plus",
	"blue": "cross",
	"white": "pentagon",
	"teal": "ring",
	"magenta": "triangle_down",
	"brown": "octagon",
	"gray": "heart",
	"navy": "moon",
	"salmon": "hourglass",
	"olive": "bars",
}

const COLOR_TITLES := {
	"cyan": "Cian",
	"orange": "Naranja",
	"green": "Verde",
	"pink": "Rosa",
	"yellow": "Amarillo",
	"violet": "Violeta",
	"red": "Rojo",
	"blue": "Azul",
	"white": "Blanco",
	"teal": "Turquesa",
	"magenta": "Magenta",
	"brown": "Marrón",
	"gray": "Gris",
	"navy": "Azul marino",
	"salmon": "Salmón",
	"olive": "Oliva",
}

const COLOR_TITLES_DEUTERANOPIA := {
	"cyan": "Cian",
	"orange": "Naranja",
	"green": "Verde",
	"pink": "Rosa",
	"yellow": "Amarillo",
	"violet": "Violeta",
	"red": "Rojo",
	"blue": "Azul",
	"white": "Blanco",
	"teal": "Turquesa",
	"magenta": "Magenta",
	"brown": "Marrón",
	"gray": "Gris",
	"navy": "Azul oscuro",
	"salmon": "Coral",
	"olive": "Lima",
}


static func is_colorblind_mode() -> bool:
	return SettingsManager.colorblind_enabled


static func active_colors() -> Dictionary:
	return COLORS_DEUTERANOPIA if is_colorblind_mode() else COLORS


static func get_color(color_name: String) -> Color:
	var palette := active_colors()
	if palette.has(color_name):
		return palette[color_name]
	return Color.WHITE


static func color_title(color_name: String) -> String:
	var titles := COLOR_TITLES_DEUTERANOPIA if is_colorblind_mode() else COLOR_TITLES
	if titles.has(color_name):
		return str(titles[color_name])
	return color_name


static func color_names() -> Array[String]:
	var names: Array[String] = []
	for key: Variant in COLORS.keys():
		names.append(str(key))
	return names


static func shape_for(color_name: String) -> String:
	return str(SHAPES.get(color_name, "circle"))


static func max_color_count() -> int:
	return COLORS.size()


static func with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
