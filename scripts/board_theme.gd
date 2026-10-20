class_name BoardTheme
extends RefCounted

## Temas visuales por tramo de nivel.

enum Kind { NEON, EMOJI, CONTRAST }

const EMOJI_MAP := {
	"cyan": "😍",
	"orange": "😎",
	"green": "🤢",
	"pink": "🥰",
	"yellow": "🤩",
	"violet": "😈",
	"red": "😡",
	"blue": "🥶",
	"white": "👻",
	"teal": "🫡",
	"magenta": "😜",
	"brown": "🤠",
	"gray": "😐",
	"navy": "😴",
	"salmon": "😊",
	"olive": "🙂",
}

## Primer nivel de la era Emoji (tras completar el 99 y la cinemática).
const EMOJI_START := 100
## Tamaño del emoji respecto a la casilla (juego, era 100+).
const EMOJI_CELL_FRACTION := 0.90
## Grosor uniforme de caminos en era Emoji (evita tramos finos por uniones).
const EMOJI_PATH_CELL_FRACTION := 0.40
const CONTRAST_START := 201


static func kind_for_level(level_id: int) -> Kind:
	if level_id >= CONTRAST_START:
		return Kind.CONTRAST
	if level_id >= EMOJI_START:
		return Kind.EMOJI
	return Kind.NEON


## Figuras geométricas solo como ayuda visual del modo daltonismo (no en Emoji).
static func shows_shapes(level_id: int) -> bool:
	return SettingsManager.colorblind_enabled and not uses_emoji(level_id)


static func title_for_kind(kind: Kind) -> String:
	match kind:
		Kind.EMOJI:
			return "Emoji"
		Kind.CONTRAST:
			return "Contraste"
		_:
			return "Neon"


static func title_for_level(level_id: int) -> String:
	return title_for_kind(kind_for_level(level_id))


static func uses_emoji(level_id: int) -> bool:
	return kind_for_level(level_id) == Kind.EMOJI


static func emoji_for(color_name: String) -> String:
	if EMOJI_MAP.has(color_name):
		return str(EMOJI_MAP[color_name])
	return "●"


static func display_title(color_name: String, level_id: int) -> String:
	if uses_emoji(level_id):
		return "%s %s" % [emoji_for(color_name), GamePalette.color_title(color_name)]
	return GamePalette.color_title(color_name)


static func board_fill(level_id: int) -> Color:
	match kind_for_level(level_id):
		Kind.EMOJI:
			return Color("0A2A6E")
		Kind.CONTRAST:
			return Color("000000")
		_:
			return GamePalette.BOARD_FILL


static func board_tint(level_id: int) -> Color:
	match kind_for_level(level_id):
		Kind.EMOJI:
			return Color(0.25, 0.55, 1.0, 0.14)
		Kind.CONTRAST:
			return Color(1, 1, 1, 0.04)
		_:
			return Color(0.0, 0.85, 1.0, 0.06)


static func board_border(level_id: int) -> Color:
	match kind_for_level(level_id):
		Kind.EMOJI:
			return Color("4FA3FF")
		Kind.CONTRAST:
			return Color("FFFFFF")
		_:
			return Color(0.0, 0.9, 1.0, 0.7)


static func board_border_secondary(level_id: int) -> Color:
	match kind_for_level(level_id):
		Kind.EMOJI:
			return Color(0.35, 0.85, 1.0, 0.45)
		Kind.CONTRAST:
			return Color(1, 1, 1, 0.35)
		_:
			return Color(1.0, 0.3, 0.7, 0.22)


static func grid_line(level_id: int) -> Color:
	match kind_for_level(level_id):
		Kind.EMOJI:
			return Color(0.55, 0.85, 1.0, 0.28)
		Kind.CONTRAST:
			return Color(1, 1, 1, 0.28)
		_:
			return Color(0.35, 0.85, 1.0, 0.22)


static func cell_fill(level_id: int) -> Color:
	match kind_for_level(level_id):
		Kind.CONTRAST:
			return Color(1, 1, 1, 0.06)
		Kind.EMOJI:
			return Color(0.2, 0.45, 0.95, 0.14)
		_:
			return Color(1, 1, 1, 0.04)
