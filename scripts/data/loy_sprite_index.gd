class_name LoySpriteIndex
extends RefCounted

## Legends of Ashenmoor sprite index mapping.
## LoY uses linear tile indices into 512x512 sprite sheets with 32x32 tiles (16 per row).

const TILES_PER_ROW := 16
const TILE_SIZE := 32
const TILES_PER_PAGE := 256  # 16x16 grid

static func get_char_region(tile_index: int) -> Rect2:
	var idx = tile_index % TILES_PER_PAGE
	var col = idx % TILES_PER_ROW
	var row = idx / TILES_PER_ROW
	return Rect2(col * TILE_SIZE, row * TILE_SIZE, TILE_SIZE, TILE_SIZE)

static func get_char_texture_path(tile_index: int) -> String:
	if tile_index < TILES_PER_PAGE:
		return "res://assets/sprites/loy/chars.png"
	else:
		return "res://assets/sprites/loy/chars2.png"

static func get_maptile_region(tile_index: int, tileset_offset: int = 0) -> Rect2:
	var idx = (tile_index + tileset_offset) % TILES_PER_PAGE
	var col = idx % TILES_PER_ROW
	var row = idx / TILES_PER_ROW
	return Rect2(col * TILE_SIZE, row * TILE_SIZE, TILE_SIZE, TILE_SIZE)

static func get_item_region(tile_index: int) -> Rect2:
	var idx = tile_index % TILES_PER_PAGE
	var col = idx % TILES_PER_ROW
	var row = idx / TILES_PER_ROW
	return Rect2(col * TILE_SIZE, row * TILE_SIZE, TILE_SIZE, TILE_SIZE)

static func get_item_texture_path(tile_index: int) -> String:
	if tile_index < TILES_PER_PAGE:
		return "res://assets/sprites/loy/tiles.png"
	else:
		return "res://assets/sprites/loy/tiles2.png"

## Map LoY tileset offset to our theme name
static func tileset_to_theme(tileset_offset: int) -> String:
	match tileset_offset:
		0: return "grey"
		8: return "brown"
		16: return "blue"
		24: return "red"
		40: return "green"
		56: return "purple"
		64: return "dark"
		72: return "grey"  # alternate grey
		112: return "brown"  # town
		144: return "blue"  # ice
		176: return "green"  # jungle
		184: return "red"  # lava
		240: return "dark"  # endgame
		_: return "grey"
