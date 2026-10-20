class_name LevelBackdrop
extends RefCounted

## Motivos de fondo para niveles 1–99 (cada 10 niveles). El 100+ no usa esto.

enum Motif {
	BUBBLES,
	RAIN,
	BEACH,
	MOUNTAIN,
	SUNSET,
	FOREST,
	DESERT,
	AURORA,
	CITY,
	VOLCANO,
}

const META_MOTIF := "backdrop_motif"

const MenuBackgroundScript := preload("res://scripts/main_menu_background.gd")
const BgRainScript := preload("res://scripts/backgrounds/bg_rain.gd")
const BgBeachScript := preload("res://scripts/backgrounds/bg_beach.gd")
const BgMountainScript := preload("res://scripts/backgrounds/bg_mountain.gd")
const BgSunsetScript := preload("res://scripts/backgrounds/bg_sunset.gd")
const BgForestScript := preload("res://scripts/backgrounds/bg_forest.gd")
const BgDesertScript := preload("res://scripts/backgrounds/bg_desert.gd")
const BgAuroraScript := preload("res://scripts/backgrounds/bg_aurora.gd")
const BgCityScript := preload("res://scripts/backgrounds/bg_city.gd")
const BgVolcanoScript := preload("res://scripts/backgrounds/bg_volcano.gd")


static func motif_for_level(level_id: int) -> int:
	var n := maxi(1, level_id)
	if n >= 90:
		return Motif.VOLCANO
	if n >= 80:
		return Motif.CITY
	if n >= 70:
		return Motif.AURORA
	if n >= 60:
		return Motif.DESERT
	if n >= 50:
		return Motif.FOREST
	if n >= 40:
		return Motif.SUNSET
	if n >= 30:
		return Motif.MOUNTAIN
	if n >= 20:
		return Motif.BEACH
	if n >= 10:
		return Motif.RAIN
	return Motif.BUBBLES


## Sandbox: misma animación de burbujas; el color de fondo cambia cada 10 niveles.
static func sandbox_palette_band(level_id: int) -> int:
	return int(floor(float(maxi(1, level_id) - 1) / 10.0))


## Era emoji (espacio): 100–109 paleta original; desde 110 cambia cada 10 niveles.
static func emoji_space_palette_band(level_id: int) -> int:
	var n := maxi(1, level_id)
	if n < 110:
		return 0
	return 1 + int(floor(float(n - 110) / 10.0))


static func create(motif: int) -> Control:
	var node: Control
	match motif:
		Motif.RAIN:
			node = BgRainScript.new()
		Motif.BEACH:
			node = BgBeachScript.new()
		Motif.MOUNTAIN:
			node = BgMountainScript.new()
		Motif.SUNSET:
			node = BgSunsetScript.new()
		Motif.FOREST:
			node = BgForestScript.new()
		Motif.DESERT:
			node = BgDesertScript.new()
		Motif.AURORA:
			node = BgAuroraScript.new()
		Motif.CITY:
			node = BgCityScript.new()
		Motif.VOLCANO:
			node = BgVolcanoScript.new()
		_:
			node = MenuBackgroundScript.new()
	node.set_meta(META_MOTIF, motif)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_to_group("level_bg_fx")
	return node


static func create_for_level(level_id: int) -> Control:
	return create(motif_for_level(level_id))


static func motif_of(node: Control) -> int:
	if node == null or not is_instance_valid(node):
		return -1
	if not node.has_meta(META_MOTIF):
		return -1
	return int(node.get_meta(META_MOTIF))
