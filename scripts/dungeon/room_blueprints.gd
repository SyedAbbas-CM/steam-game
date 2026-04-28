class_name RoomBlueprints
extends RefCounted

# 10 themed blueprint paint functions for dungeon room decoration.
# Each paints a themed cluster into a rectangular zone within a room.
# dm param is DungeonManager (untyped to avoid circular dependency).
# Tile constants come from DecoTiles (no circular dependency).

enum Blueprint {
	THRONE_ROOM,
	CHAPEL,
	BLACKSMITH,
	PRISON_BLOCK,
	ALCHEMIST_LAB,
	EXECUTION_PIT,
	WAR_ROOM,
	TREASURE_VAULT,
	BARRACKS,
	TAVERN,
}

const BLUEPRINT_COUNT = 10

static func paint_blueprint(bp: Blueprint, dm, origin: Vector2i,
		mask: Array, zx: int, zy: int, zw: int, zh: int, placed: Dictionary) -> void:
	match bp:
		Blueprint.THRONE_ROOM: _paint_throne_room(dm, origin, mask, zx, zy, zw, zh, placed)
		Blueprint.CHAPEL: _paint_chapel(dm, origin, mask, zx, zy, zw, zh, placed)
		Blueprint.BLACKSMITH: _paint_blacksmith(dm, origin, mask, zx, zy, zw, zh, placed)
		Blueprint.PRISON_BLOCK: _paint_prison_block(dm, origin, mask, zx, zy, zw, zh, placed)
		Blueprint.ALCHEMIST_LAB: _paint_alchemist_lab(dm, origin, mask, zx, zy, zw, zh, placed)
		Blueprint.EXECUTION_PIT: _paint_execution_pit(dm, origin, mask, zx, zy, zw, zh, placed)
		Blueprint.WAR_ROOM: _paint_war_room(dm, origin, mask, zx, zy, zw, zh, placed)
		Blueprint.TREASURE_VAULT: _paint_treasure_vault(dm, origin, mask, zx, zy, zw, zh, placed)
		Blueprint.BARRACKS: _paint_barracks(dm, origin, mask, zx, zy, zw, zh, placed)
		Blueprint.TAVERN: _paint_tavern(dm, origin, mask, zx, zy, zw, zh, placed)

# --- Helpers ---

static func _safe(mask: Array, x: int, y: int, w: int, h: int) -> bool:
	return x >= 1 and x < w - 1 and y >= 1 and y < h - 1 and mask[y][x]

static func _place(dm, origin: Vector2i, mask: Array, w: int, h: int,
		x: int, y: int, tile: Vector2i, placed: Dictionary) -> bool:
	return dm._place_deco_if_free(origin, mask, w, h, x, y, tile, placed)

static func _place_brazier(dm, origin: Vector2i, mask: Array, w: int, h: int,
		x: int, y: int, placed: Dictionary) -> void:
	if not _safe(mask, x, y, w, h) or placed.has(Vector2i(x, y)):
		return
	var abs_pos = origin + Vector2i(x, y)
	if dm.deco_layer.get_cell_source_id(abs_pos) != -1:
		return
	dm.deco_layer.erase_cell(abs_pos)
	dm._register_animated_tile(abs_pos, DecoTiles.ANIM_BRAZIER_A, DecoTiles.ANIM_BRAZIER_B)
	placed[Vector2i(x, y)] = true

static func _place_floor_candle(dm, origin: Vector2i, mask: Array, w: int, h: int,
		x: int, y: int, placed: Dictionary) -> void:
	if not _safe(mask, x, y, w, h) or placed.has(Vector2i(x, y)):
		return
	var abs_pos = origin + Vector2i(x, y)
	if dm.deco_layer.get_cell_source_id(abs_pos) != -1:
		return
	dm._register_animated_tile(abs_pos, DecoTiles.DECO_FLOOR_CANDLE_A, DecoTiles.DECO_FLOOR_CANDLE_B)
	placed[Vector2i(x, y)] = true

static func _random_carpet_color() -> String:
	return ["red", "blue", "green"][randi() % 3]

static func _paint_carpet(dm, origin: Vector2i, mask: Array, w: int, h: int,
		left: int, top: int, right: int, bot: int, color: String) -> void:
	dm._paint_carpet_section(origin, mask, w, h, left, top, right, bot, color)

static func _mirrored() -> bool:
	return randf() < 0.5

static func _scatter_items(dm, origin: Vector2i, mask: Array, w: int, h: int,
		zx: int, zy: int, zw: int, zh: int, tiles: Array, count: int, placed: Dictionary) -> void:
	for _i in range(count):
		for _attempt in range(10):
			var x = randi_range(zx + 1, zx + zw - 2)
			var y = randi_range(zy + 1, zy + zh - 2)
			if _place(dm, origin, mask, w, h, x, y, tiles[randi() % tiles.size()], placed):
				break

# =========================================================================
# 1. THRONE ROOM
# =========================================================================
static func _paint_throne_room(dm, origin: Vector2i, mask: Array,
		zx: int, zy: int, zw: int, zh: int, placed: Dictionary) -> void:
	var w = mask[0].size()
	var h = mask.size()
	var cx = zx + zw / 2
	var color = _random_carpet_color()
	var gold_tiles: Array = [DecoTiles.DECO_GOLD, DecoTiles.DECO_GOLD_LARGE]

	var carpet_left = maxi(cx - 3, zx + 1)
	var carpet_right = mini(cx + 3, zx + zw - 2)
	_paint_carpet(dm, origin, mask, w, h, carpet_left, zy + 1, carpet_right, zy + zh - 2, color)

	var throne_y = zy + 1
	for y in range(zy + 1, zy + 4):
		if _safe(mask, cx, y, w, h) and dm._is_interior(mask, cx, y, w, h):
			throne_y = y
			break
	_place(dm, origin, mask, w, h, cx, throne_y, DecoTiles.DECO_THRONE, placed)
	_place(dm, origin, mask, w, h, cx - 1, throne_y, DecoTiles.DECO_CANDLE_STAND, placed)
	_place(dm, origin, mask, w, h, cx + 1, throne_y, DecoTiles.DECO_CANDLE_STAND, placed)
	_place(dm, origin, mask, w, h, cx - 3, throne_y, DecoTiles.DECO_GOLDEN_STATUE, placed)
	_place(dm, origin, mask, w, h, cx + 3, throne_y, DecoTiles.DECO_GOLDEN_STATUE, placed)

	var display_items = [DecoTiles.DECO_ARMOR_DISPLAY, DecoTiles.DECO_WEAPON_DISPLAY_WALL]
	for x in range(zx + 2, zx + zw - 2, 3):
		if abs(x - cx) < 2:
			continue
		if _safe(mask, x, zy + 1, w, h) and dm._has_wall_neighbor(mask, x, zy + 1, w, h):
			_place(dm, origin, mask, w, h, x, zy + 1, display_items[randi() % display_items.size()], placed)

	_place_brazier(dm, origin, mask, w, h, cx - 4, throne_y + 1, placed)
	_place_brazier(dm, origin, mask, w, h, cx + 4, throne_y + 1, placed)

	_scatter_items(dm, origin, mask, w, h, zx, zy + 3, zw, zh - 4, gold_tiles, randi_range(2, 5), placed)

# =========================================================================
# 2. CHAPEL
# =========================================================================
static func _paint_chapel(dm, origin: Vector2i, mask: Array,
		zx: int, zy: int, zw: int, zh: int, placed: Dictionary) -> void:
	var w = mask[0].size()
	var h = mask.size()
	var cx = zx + zw / 2
	var color = _random_carpet_color()
	var left_x = zx + 2
	var right_x = zx + zw - 2

	_paint_carpet(dm, origin, mask, w, h, cx - 1, zy + 1, cx + 1, zy + zh - 2, color)

	var altar_y = zy + 2
	_place(dm, origin, mask, w, h, cx, altar_y, DecoTiles.DECO_ALTAR, placed)
	_place(dm, origin, mask, w, h, cx - 1, altar_y, DecoTiles.DECO_CANDLE_STAND, placed)
	_place(dm, origin, mask, w, h, cx + 1, altar_y, DecoTiles.DECO_CANDLE_STAND, placed)
	_place(dm, origin, mask, w, h, cx, altar_y + 1, DecoTiles.DECO_BOOK_STAND, placed)

	var pew_rows = randi_range(2, mini(4, (zh - 5) / 2))
	for row_i in range(pew_rows):
		var py = altar_y + 3 + row_i * 2
		if py >= zy + zh - 2:
			break
		_place(dm, origin, mask, w, h, left_x, py, DecoTiles.DECO_CHAIR_RIGHT, placed)
		_place(dm, origin, mask, w, h, left_x + 1, py, DecoTiles.DECO_BENCH, placed)
		_place(dm, origin, mask, w, h, right_x - 1, py, DecoTiles.DECO_BENCH, placed)
		_place(dm, origin, mask, w, h, right_x, py, DecoTiles.DECO_CHAIR_LEFT, placed)

	for x in [zx + 1, zx + zw - 2]:
		_place(dm, origin, mask, w, h, x, altar_y, DecoTiles.DECO_BOOKSHELF, placed)

	for sg in DecoTiles.DECO_STAINED_GLASS:
		var sx = randi_range(zx + 2, zx + zw - 3)
		if _safe(mask, sx, zy + 1, w, h) and dm._has_wall_neighbor(mask, sx, zy + 1, w, h):
			_place(dm, origin, mask, w, h, sx, zy + 1, sg, placed)

	for fy in range(altar_y + 3, zy + zh - 2, 5):
		_place_floor_candle(dm, origin, mask, w, h, cx - 2, fy, placed)
		_place_floor_candle(dm, origin, mask, w, h, cx + 2, fy, placed)

# =========================================================================
# 3. BLACKSMITH
# =========================================================================
static func _paint_blacksmith(dm, origin: Vector2i, mask: Array,
		zx: int, zy: int, zw: int, zh: int, placed: Dictionary) -> void:
	var w = mask[0].size()
	var h = mask.size()
	var mirror = _mirrored()
	var fx = zx + 2 if not mirror else zx + zw - 3

	_place(dm, origin, mask, w, h, fx, zy + 2, DecoTiles.DECO_FURNACE, placed)
	_place(dm, origin, mask, w, h, fx + (1 if not mirror else -1), zy + 2, DecoTiles.DECO_WATER_TROUGH, placed)
	_place(dm, origin, mask, w, h, fx, zy + 3, DecoTiles.DECO_ANVIL, placed)
	_place_brazier(dm, origin, mask, w, h, fx + (2 if not mirror else -2), zy + 2, placed)

	var rack_x = zx + zw - 3 if not mirror else zx + 2
	_place(dm, origin, mask, w, h, rack_x, zy + 2, DecoTiles.DECO_WEAPON_RACK, placed)
	_place(dm, origin, mask, w, h, rack_x, zy + 3, DecoTiles.DECO_WEAPON_RACK_LEFT, placed)
	_place(dm, origin, mask, w, h, rack_x, zy + 4, DecoTiles.DECO_WEAPON_RACK_RIGHT, placed)
	_place(dm, origin, mask, w, h, rack_x, zy + 5, DecoTiles.DECO_ADVANCED_WEAPON_RACK, placed)

	var dummy_x = zx + zw / 2
	_place(dm, origin, mask, w, h, dummy_x, zy + zh - 3, DecoTiles.DECO_TRAINING_DUMMY, placed)

	var barrel_tiles: Array = [DecoTiles.DECO_BARREL, DecoTiles.DECO_BARREL_CLUSTER_2,
		DecoTiles.DECO_BARREL_CLUSTER_3, DecoTiles.DECO_SMALL_BARREL]
	_scatter_items(dm, origin, mask, w, h, zx, zy + zh / 2, zw, zh / 2, barrel_tiles, randi_range(2, 4), placed)

# =========================================================================
# 4. PRISON BLOCK
# =========================================================================
static func _paint_prison_block(dm, origin: Vector2i, mask: Array,
		zx: int, zy: int, zw: int, zh: int, placed: Dictionary) -> void:
	var w = mask[0].size()
	var h = mask.size()

	var num_cells = randi_range(2, mini(3, zw / 5))
	var cell_width = zw / num_cells
	for cell_i in range(num_cells):
		var cell_x = zx + cell_i * cell_width + 1
		var cell_end_x = mini(cell_x + cell_width - 2, zx + zw - 2)

		if cell_i > 0:
			var grate_x = cell_x - 1
			for gy in range(zy + 1, zy + zh - 1):
				_place(dm, origin, mask, w, h, grate_x, gy, DecoTiles.DECO_IRON_GRATE, placed)

		var cot_x = cell_x + 1
		_place(dm, origin, mask, w, h, cot_x, zy + 2, DecoTiles.DECO_BENCH, placed)

		if randf() < 0.5:
			var bed_tiles = [DecoTiles.DECO_BED_RIGHT_RED, DecoTiles.DECO_BED_BLUE_LEFT, DecoTiles.DECO_BED_GREEN_LEFT]
			_place(dm, origin, mask, w, h, cot_x, zy + 3, bed_tiles[randi() % bed_tiles.size()], placed)

		_place(dm, origin, mask, w, h, cell_end_x - 1, zy + zh - 3, DecoTiles.DECO_BUCKET, placed)

	_place(dm, origin, mask, w, h, zx + 1, zy + 1, DecoTiles.DECO_CAGE, placed)
	_place(dm, origin, mask, w, h, zx + zw - 2, zy + zh - 2, DecoTiles.DECO_CAGE, placed)

	var scatter: Array = []
	for t in DecoTiles.DECO_SKULLS:
		scatter.append(t)
	for t in DecoTiles.DECO_BLOOD:
		scatter.append(t)
	_scatter_items(dm, origin, mask, w, h, zx, zy, zw, zh, scatter, randi_range(3, 6), placed)

# =========================================================================
# 5. ALCHEMIST LAB
# =========================================================================
static func _paint_alchemist_lab(dm, origin: Vector2i, mask: Array,
		zx: int, zy: int, zw: int, zh: int, placed: Dictionary) -> void:
	var w = mask[0].size()
	var h = mask.size()
	var cx = zx + zw / 2

	var cauldron_variants: Array = [DecoTiles.DECO_CAULDRON, DecoTiles.DECO_CAULDRON_CLOSED, DecoTiles.DECO_CAULDRON_CRACKED]
	_place(dm, origin, mask, w, h, cx, zy + zh / 2, cauldron_variants[randi() % cauldron_variants.size()], placed)
	_place(dm, origin, mask, w, h, cx + 2, zy + zh / 2, cauldron_variants[randi() % cauldron_variants.size()], placed)

	var cab_count = randi_range(3, mini(5, zw - 4))
	var cab_start = cx - cab_count / 2
	for i in range(cab_count):
		var px = cab_start + i
		if _safe(mask, px, zy + 1, w, h) and dm._has_wall_neighbor(mask, px, zy + 1, w, h):
			_place(dm, origin, mask, w, h, px, zy + 1, DecoTiles.DECO_POTION_CABINET, placed)

	_place(dm, origin, mask, w, h, cx - 2, zy + zh / 2, DecoTiles.DECO_BOOK_STAND, placed)
	_place(dm, origin, mask, w, h, zx + 1, zy + 3, DecoTiles.DECO_BOOKSHELF_LEFT, placed)
	_place(dm, origin, mask, w, h, zx + 2, zy + 3, DecoTiles.DECO_BOOKSHELF_RIGHT, placed)
	_place(dm, origin, mask, w, h, zx + zw - 3, zy + zh - 3, DecoTiles.DECO_EXPLOSIVE_BARREL, placed)

	_place_floor_candle(dm, origin, mask, w, h, cx - 1, zy + zh / 2 - 1, placed)
	_place_floor_candle(dm, origin, mask, w, h, cx + 1, zy + zh / 2 + 1, placed)

	var pots: Array = []
	for t in DecoTiles.DECO_POTS:
		pots.append(t)
	_scatter_items(dm, origin, mask, w, h, zx, zy + zh / 2, zw, zh / 2, pots, randi_range(2, 4), placed)

# =========================================================================
# 6. EXECUTION PIT
# =========================================================================
static func _paint_execution_pit(dm, origin: Vector2i, mask: Array,
		zx: int, zy: int, zw: int, zh: int, placed: Dictionary) -> void:
	var w = mask[0].size()
	var h = mask.size()
	var cx = zx + zw / 2
	var cy = zy + zh / 2

	_place(dm, origin, mask, w, h, cx, cy, DecoTiles.DECO_HEAD_CHOPPING_BLOCK, placed)
	_place(dm, origin, mask, w, h, cx + 2, cy, DecoTiles.DECO_BLOOD_ALTAR, placed)

	_place(dm, origin, mask, w, h, zx + 1, zy + 1, DecoTiles.DECO_CAGE, placed)
	_place(dm, origin, mask, w, h, zx + zw - 2, zy + 1, DecoTiles.DECO_CAGE, placed)
	_place(dm, origin, mask, w, h, zx + 1, zy + zh - 2, DecoTiles.DECO_CAGE, placed)

	_place_brazier(dm, origin, mask, w, h, cx - 3, cy - 2, placed)
	_place_brazier(dm, origin, mask, w, h, cx + 3, cy - 2, placed)
	_place_brazier(dm, origin, mask, w, h, cx - 3, cy + 2, placed)
	_place_brazier(dm, origin, mask, w, h, cx + 3, cy + 2, placed)

	var gore: Array = []
	for t in DecoTiles.DECO_BLOOD:
		gore.append(t)
	for t in DecoTiles.DECO_SKULLS:
		gore.append(t)
	_scatter_items(dm, origin, mask, w, h, zx, zy, zw, zh, gore, randi_range(5, 10), placed)

	var bones: Array = []
	for t in DecoTiles.DECO_BONES:
		bones.append(t)
	_scatter_items(dm, origin, mask, w, h, zx, zy, zw, zh, bones, randi_range(2, 4), placed)

# =========================================================================
# 7. WAR ROOM
# =========================================================================
static func _paint_war_room(dm, origin: Vector2i, mask: Array,
		zx: int, zy: int, zw: int, zh: int, placed: Dictionary) -> void:
	var w = mask[0].size()
	var h = mask.size()
	var cx = zx + zw / 2
	var cy = zy + zh / 2
	var color = _random_carpet_color()

	_paint_carpet(dm, origin, mask, w, h, cx - 3, cy - 2, cx + 3, cy + 2, color)

	var table_tile = DecoTiles.DECO_TABLE_ROUND if randf() < 0.5 else DecoTiles.DECO_TABLE
	_place(dm, origin, mask, w, h, cx, cy, table_tile, placed)
	_place(dm, origin, mask, w, h, cx - 1, cy, DecoTiles.DECO_CHAIR_RIGHT, placed)
	_place(dm, origin, mask, w, h, cx + 1, cy, DecoTiles.DECO_CHAIR_LEFT, placed)
	_place(dm, origin, mask, w, h, cx, cy - 1, DecoTiles.DECO_CHAIR_FRONT, placed)
	_place(dm, origin, mask, w, h, cx, cy + 1, DecoTiles.DECO_CHAIR_FRONT, placed)

	for x in range(zx + 2, zx + zw - 2, 3):
		if _safe(mask, x, zy + 1, w, h) and dm._has_wall_neighbor(mask, x, zy + 1, w, h):
			var display = DecoTiles.DECO_WEAPON_DISPLAY_WALL if randf() < 0.5 else DecoTiles.DECO_ARMOR_DISPLAY
			_place(dm, origin, mask, w, h, x, zy + 1, display, placed)

	_place(dm, origin, mask, w, h, zx + 1, cy + 2, DecoTiles.DECO_ADVANCED_WEAPON_RACK, placed)
	_place(dm, origin, mask, w, h, zx + zw - 2, cy + 2, DecoTiles.DECO_TRAINING_DUMMY, placed)
	_place(dm, origin, mask, w, h, zx + 1, zy + zh - 2, DecoTiles.DECO_LEVER_LEFT, placed)
	_place(dm, origin, mask, w, h, zx + zw - 2, zy + zh - 2, DecoTiles.DECO_LEVER_RIGHT, placed)

	_place_brazier(dm, origin, mask, w, h, zx + 1, zy + 1, placed)
	_place_brazier(dm, origin, mask, w, h, zx + zw - 2, zy + 1, placed)

# =========================================================================
# 8. TREASURE VAULT
# =========================================================================
static func _paint_treasure_vault(dm, origin: Vector2i, mask: Array,
		zx: int, zy: int, zw: int, zh: int, placed: Dictionary) -> void:
	var w = mask[0].size()
	var h = mask.size()
	var cx = zx + zw / 2
	var cy = zy + zh / 2

	_place(dm, origin, mask, w, h, cx, cy, DecoTiles.DECO_GOLD_VERY_LARGE, placed)
	_place(dm, origin, mask, w, h, cx - 1, cy, DecoTiles.DECO_GOLD_LARGE, placed)
	_place(dm, origin, mask, w, h, cx + 1, cy, DecoTiles.DECO_GOLD_LARGE, placed)

	var chest_types: Array = [DecoTiles.DECO_CHEST_OPEN_GOLD, DecoTiles.DECO_CHEST_OPEN_SILVER, DecoTiles.DECO_CHEST_OPEN_BRONZE]
	for i in range(randi_range(2, 4)):
		var cx2 = randi_range(zx + 1, zx + zw - 2)
		var cy2 = randi_range(zy + 1, zy + zh - 2)
		_place(dm, origin, mask, w, h, cx2, cy2, chest_types[randi() % chest_types.size()], placed)

	_place(dm, origin, mask, w, h, cx, zy + 2, DecoTiles.DECO_LARGE_CHEST_CLOSED, placed)
	_place(dm, origin, mask, w, h, zx + 1, cy, DecoTiles.DECO_CLOSED_CHEST, placed)
	_place(dm, origin, mask, w, h, zx + zw - 2, cy, DecoTiles.DECO_CLOSED_CHEST, placed)

	_place(dm, origin, mask, w, h, cx - 3, cy - 2, DecoTiles.DECO_STONE_TABLE, placed)
	_place(dm, origin, mask, w, h, cx + 3, cy - 2, DecoTiles.DECO_STONE_TABLE, placed)

	var gold_tiles: Array = [DecoTiles.DECO_GOLD, DecoTiles.DECO_GOLD_LARGE]
	_scatter_items(dm, origin, mask, w, h, zx, zy, zw, zh, gold_tiles, randi_range(4, 8), placed)

	_place_brazier(dm, origin, mask, w, h, zx + 1, zy + 1, placed)
	_place_brazier(dm, origin, mask, w, h, zx + zw - 2, zy + 1, placed)
	_place_brazier(dm, origin, mask, w, h, zx + 1, zy + zh - 2, placed)
	_place_brazier(dm, origin, mask, w, h, zx + zw - 2, zy + zh - 2, placed)

# =========================================================================
# 9. BARRACKS
# =========================================================================
static func _paint_barracks(dm, origin: Vector2i, mask: Array,
		zx: int, zy: int, zw: int, zh: int, placed: Dictionary) -> void:
	var mirror = _mirrored()
	var w = mask[0].size()
	var h = mask.size()
	var cx = zx + zw / 2
	var color = _random_carpet_color()

	_paint_carpet(dm, origin, mask, w, h, cx - 1, zy + 1, cx + 1, zy + zh - 2, color)

	var num_beds = randi_range(3, mini(6, (zh - 3) / 2))
	var bed_colors_left: Array = [DecoTiles.DECO_BED_LEFT_RED, DecoTiles.DECO_BED_BLUE_LEFT, DecoTiles.DECO_BED_GREEN_LEFT]
	var bed_colors_right: Array = [DecoTiles.DECO_BED_RIGHT_RED, DecoTiles.DECO_BED_BLUE_RIGHT, DecoTiles.DECO_BED_GREEN_RIGHT]
	for i in range(num_beds):
		var by = zy + 2 + i * 2
		if by >= zy + zh - 2:
			break
		var bed_color_idx = randi() % bed_colors_left.size()
		var left_x = zx + 1 if not mirror else zx + 2
		_place(dm, origin, mask, w, h, left_x, by, bed_colors_left[bed_color_idx], placed)
		var right_x = zx + zw - 2 if not mirror else zx + zw - 3
		_place(dm, origin, mask, w, h, right_x, by, bed_colors_right[randi() % bed_colors_right.size()], placed)
		if i % 2 == 0:
			_place(dm, origin, mask, w, h, left_x + 1, by, DecoTiles.DECO_WEAPON_RACK, placed)

	_place(dm, origin, mask, w, h, zx + 1, zy + 1, DecoTiles.DECO_WARDROBE, placed)
	_place(dm, origin, mask, w, h, zx + zw - 2, zy + 1, DecoTiles.DECO_WARDROBE_OPEN, placed)

	_scatter_items(dm, origin, mask, w, h, zx, zy, zw, zh,
		[DecoTiles.DECO_STOOL, DecoTiles.DECO_STOOL_FLIPPED] as Array, randi_range(2, 4), placed)

# =========================================================================
# 10. TAVERN
# =========================================================================
static func _paint_tavern(dm, origin: Vector2i, mask: Array,
		zx: int, zy: int, zw: int, zh: int, placed: Dictionary) -> void:
	var w = mask[0].size()
	var h = mask.size()
	var cx = zx + zw / 2
	var color = _random_carpet_color()

	_paint_carpet(dm, origin, mask, w, h, zx + 2, zy + 2, zx + zw - 3, zy + zh - 3, color)

	var table_tiles: Array = [DecoTiles.DECO_TABLE_GLASSES_RIGHT, DecoTiles.DECO_TABLE_GLASSES_LEFT, DecoTiles.DECO_TABLE_GLASSES]
	var num_tables = randi_range(2, mini(3, zw / 4))
	for i in range(num_tables):
		var tx = zx + 2 + i * (zw / num_tables)
		var ty = zy + zh / 2 + (randi_range(-2, 2))
		ty = clampi(ty, zy + 2, zy + zh - 3)
		_place(dm, origin, mask, w, h, tx, ty, table_tiles[randi() % table_tiles.size()], placed)
		_place(dm, origin, mask, w, h, tx - 1, ty, DecoTiles.DECO_STOOL, placed)
		_place(dm, origin, mask, w, h, tx + 1, ty, DecoTiles.DECO_STOOL_FLIPPED, placed)

	var bar_y = zy + 1
	var barrel_tiles: Array = [DecoTiles.DECO_BARREL, DecoTiles.DECO_BARREL_CLUSTER_2,
		DecoTiles.DECO_BARREL_CLUSTER_3, DecoTiles.DECO_SMALL_BARREL]
	for bx in range(zx + 1, mini(zx + 5, zx + zw - 2)):
		if _safe(mask, bx, bar_y, w, h) and dm._has_wall_neighbor(mask, bx, bar_y, w, h):
			_place(dm, origin, mask, w, h, bx, bar_y, barrel_tiles[randi() % barrel_tiles.size()], placed)

	for bx in range(zx + 2, zx + zw - 2, 2):
		if _safe(mask, bx, zy + zh - 2, w, h):
			_place(dm, origin, mask, w, h, bx, zy + zh - 2, DecoTiles.DECO_BENCH, placed)

	_place(dm, origin, mask, w, h, cx, zy + 2, DecoTiles.DECO_LAMP_ON, placed)
	_place_floor_candle(dm, origin, mask, w, h, cx - 3, zy + zh / 2, placed)
	_place_floor_candle(dm, origin, mask, w, h, cx + 3, zy + zh / 2, placed)
