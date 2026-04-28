@tool
extends Node2D
## Open scenes/samples/sample_rooms.tscn in the editor to see example rooms.
## Edit tiles freely — they bake into the .tscn on save.

@onready var floor_layer: TileMapLayer = $Floor
@onready var walls_layer: TileMapLayer = $Walls
@onready var deco_layer: TileMapLayer = $Decorations
@onready var door_layer: TileMapLayer = $Doors
@export var auto_generate_in_editor: bool = false

const ROOM_W = 17
const ROOM_H = 15
const ELITE_W = 37
const ELITE_H = 31
const GAP = 3  # tiles between rooms

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	if not auto_generate_in_editor:
		return
	if floor_layer and floor_layer.get_used_cells().size() == 0:
		_generate_samples()
		print("Sample rooms generated! Save (Ctrl+S) to bake.")

func _generate_samples() -> void:
	seed(123)
	# Paint 4 rooms in a row — one per biome theme
	var themes = [
		{ "name": "Stone Crypt", "row": 0, "hazards": [Vector2i(9, 0), Vector2i(10, 0)], "decos": [Vector2i(9, 16), Vector2i(10, 16)], "door": "grey" },
		{ "name": "Flooded Cavern", "row": 2, "hazards": [Vector2i(4, 17), Vector2i(5, 17)], "decos": [Vector2i(10, 16), Vector2i(12, 16), Vector2i(13, 16)], "door": "steel" },
		{ "name": "Burning Hall", "row": 3, "hazards": [Vector2i(0, 17), Vector2i(1, 17)], "decos": [Vector2i(11, 16), Vector2i(9, 16)], "door": "orange" },
		{ "name": "Shadow Keep", "row": 11, "hazards": [Vector2i(2, 17), Vector2i(3, 17)], "decos": [Vector2i(6, 19), Vector2i(7, 19), Vector2i(8, 19)], "door": "grey" },
	]

	for i in range(themes.size()):
		var t = themes[i]
		var ox = i * (ROOM_W + GAP)
		_paint_sample_room(Vector2i(ox, 0), t["row"], t["hazards"], t["decos"], t["door"],
			i == 0, i == 1, i == 2, i == 3)  # different connection combos

	# Super Elite sample room — big empty room for manual decoration painting
	var elite_ox = themes.size() * (ROOM_W + GAP)
	_paint_super_elite_room(Vector2i(elite_ox, 0), 0)  # theme row 0 = grey stone

	# AI-generated decorated super elite room — next to the manual one for comparison
	var gen_ox = elite_ox + ELITE_W + GAP
	_paint_super_elite_room(Vector2i(gen_ox, 0), 0)
	_decorate_super_elite(Vector2i(gen_ox, 0), ELITE_W, ELITE_H)

func _paint_sample_room(origin: Vector2i, theme_row: int, hazards: Array, decos: Array, door_style: String,
		has_north: bool, has_south: bool, has_east: bool, has_west: bool) -> void:
	var floor_tile = Vector2i(1, theme_row)
	var floor_tile_2 = Vector2i(2, theme_row)
	var wall_tile = Vector2i(0, theme_row)
	var wall_candle = Vector2i(4, theme_row)
	var wall_candle_2 = Vector2i(5, theme_row)
	var wall_roof = Vector2i(6, theme_row)
	var wall_cracked = Vector2i(3, theme_row)
	var dirt_tile = Vector2i(12, theme_row)
	var trap_tile = Vector2i(13, theme_row)
	var stairs_down = Vector2i(8, theme_row)
	var mid_x = origin.x + ROOM_W / 2
	var mid_y = origin.y + ROOM_H / 2

	var DOOR_TILES = {
		"brown": { "closed": Vector2i(0, 23), "open": Vector2i(1, 23) },
		"grey": { "closed": Vector2i(2, 23), "open": Vector2i(3, 23) },
		"steel": { "closed": Vector2i(4, 23), "open": Vector2i(5, 23) },
		"gold": { "closed": Vector2i(6, 23), "open": Vector2i(7, 23) },
		"orange": { "closed": Vector2i(8, 23), "open": Vector2i(9, 23) },
	}

	# Floor
	for x in range(1, ROOM_W - 1):
		for y in range(1, ROOM_H - 1):
			var tile_pos = origin + Vector2i(x, y)
			if randf() < 0.15:
				floor_layer.set_cell(tile_pos, 0, floor_tile_2)
			elif randf() < 0.05:
				floor_layer.set_cell(tile_pos, 0, dirt_tile)
			elif randf() < 0.02:
				deco_layer.set_cell(tile_pos, 0, trap_tile)
				floor_layer.set_cell(tile_pos, 0, floor_tile)
			else:
				floor_layer.set_cell(tile_pos, 0, floor_tile)

	# Stairs in center
	deco_layer.set_cell(origin + Vector2i(mid_x, mid_y - 2), 0, stairs_down)

	# Top wall
	for x in range(ROOM_W):
		if has_north and abs(x - mid_x) <= 1:
			floor_layer.set_cell(origin + Vector2i(x, 0), 0, floor_tile)
			door_layer.set_cell(origin + Vector2i(x, 0), 0, DOOR_TILES[door_style]["closed"])
			continue
		var tile_pos = origin + Vector2i(x, 0)
		if randf() < 0.15:
			walls_layer.set_cell(tile_pos, 0, wall_cracked)
		else:
			walls_layer.set_cell(tile_pos, 0, wall_roof)

	# Bottom wall
	for x in range(ROOM_W):
		if has_south and abs(x - mid_x) <= 1:
			floor_layer.set_cell(origin + Vector2i(x, ROOM_H - 1), 0, floor_tile)
			door_layer.set_cell(origin + Vector2i(x, ROOM_H - 1), 0, DOOR_TILES[door_style]["open"])
			continue
		walls_layer.set_cell(origin + Vector2i(x, ROOM_H - 1), 0, wall_tile)

	# Left wall
	for y in range(ROOM_H):
		if has_west and abs(y - mid_y) <= 1:
			floor_layer.set_cell(origin + Vector2i(0, y), 0, floor_tile)
			door_layer.set_cell(origin + Vector2i(0, y), 0, DOOR_TILES[door_style]["closed"])
			continue
		if randf() < 0.2:
			walls_layer.set_cell(origin + Vector2i(0, y), 0, wall_candle)
		else:
			walls_layer.set_cell(origin + Vector2i(0, y), 0, wall_tile)

	# Right wall
	for y in range(ROOM_H):
		if has_east and abs(y - mid_y) <= 1:
			floor_layer.set_cell(origin + Vector2i(ROOM_W - 1, y), 0, floor_tile)
			door_layer.set_cell(origin + Vector2i(ROOM_W - 1, y), 0, DOOR_TILES[door_style]["open"])
			continue
		if randf() < 0.2:
			walls_layer.set_cell(origin + Vector2i(ROOM_W - 1, y), 0, wall_candle_2)
		else:
			walls_layer.set_cell(origin + Vector2i(ROOM_W - 1, y), 0, wall_tile)

	# Decorations
	for _i in range(4):
		var dx = randi_range(2, ROOM_W - 3)
		var dy = randi_range(2, ROOM_H - 3)
		var tile = decos[randi() % decos.size()]
		deco_layer.set_cell(origin + Vector2i(dx, dy), 0, tile)

	# Hazard tiles
	for _i in range(2):
		var hx = randi_range(3, ROOM_W - 4)
		var hy = randi_range(3, ROOM_H - 4)
		var tile = hazards[randi() % hazards.size()]
		floor_layer.set_cell(origin + Vector2i(hx, hy), 0, tile)

func _paint_super_elite_room(origin: Vector2i, theme_row: int) -> void:
	## Paints a big 37x31 empty room — floor + walls only.
	## Open in editor, select the Decorations layer (source 1 = dungeon features),
	## and paint furniture/carpets however you want to show me.
	var ew = ELITE_W
	var eh = ELITE_H
	var floor_tile = Vector2i(5, theme_row)
	var floor_tile_2 = Vector2i(6, theme_row)
	var wall_tile = Vector2i(4, theme_row)
	var wall_roof = Vector2i(0, theme_row)
	var wall_candle = Vector2i(1, theme_row)
	var wall_candle_2 = Vector2i(2, theme_row)
	var mid_x = ew / 2
	var mid_y = eh / 2

	# Floor
	for x in range(1, ew - 1):
		for y in range(1, eh - 1):
			var tile_pos = origin + Vector2i(x, y)
			if randf() < 0.1:
				floor_layer.set_cell(tile_pos, 0, floor_tile_2)
			else:
				floor_layer.set_cell(tile_pos, 0, floor_tile)

	# Top wall (solid, no door — dead end room)
	for x in range(ew):
		var tile_pos = origin + Vector2i(x, 0)
		if randf() < 0.15:
			walls_layer.set_cell(tile_pos, 0, wall_candle)
		else:
			walls_layer.set_cell(tile_pos, 0, wall_roof)

	# Bottom wall — single entrance in the center
	for x in range(ew):
		if abs(x - mid_x) <= 1:
			# Entrance opening
			floor_layer.set_cell(origin + Vector2i(x, eh - 1), 0, floor_tile)
			continue
		walls_layer.set_cell(origin + Vector2i(x, eh - 1), 0, wall_tile)

	# Left wall (solid)
	for y in range(eh):
		if randf() < 0.15:
			walls_layer.set_cell(origin + Vector2i(0, y), 0, wall_candle)
		else:
			walls_layer.set_cell(origin + Vector2i(0, y), 0, wall_tile)

	# Right wall (solid)
	for y in range(eh):
		if randf() < 0.15:
			walls_layer.set_cell(origin + Vector2i(ew - 1, y), 0, wall_candle_2)
		else:
			walls_layer.set_cell(origin + Vector2i(ew - 1, y), 0, wall_tile)

func _decorate_super_elite(origin: Vector2i, w: int, h: int) -> void:
	## See docs/DECORATION_RULES.md for VERIFIED sprite coordinates.
	## CARPET on FLOOR LAYER (source 1) → shows UNDER furniture.
	## FURNITURE on DECO LAYER (source 1) → on top.
	## Sprites verified against bake_aria_dungeon.gd + labeled spritesheet grid.
	var cx = w / 2

	# Helper lambdas
	var carpet = func(x: int, y: int, tile: Vector2i) -> void:
		floor_layer.set_cell(origin + Vector2i(x, y), 1, tile)
	var deco = func(x: int, y: int, tile: Vector2i) -> void:
		deco_layer.set_cell(origin + Vector2i(x, y), 1, tile)

	# Carpet tiles (verified)
	var C_H_RED = Vector2i(12, 3)    # horizontal red
	var C_V_BLUE = Vector2i(17, 2)   # vertical blue
	var C_CONN_RED = Vector2i(15, 3) # connector red

	# ============================================================
	# SECTION A: Throne area — RED horizontal carpet (rows 2..8)
	# Wide section → horizontal tiles
	# ============================================================
	for y in range(2, 9):
		for x in range(4, w - 4):
			carpet.call(x, y, C_H_RED)

	# Throne (18,6) row 3 with breathing room from wall
	deco.call(cx, 3, Vector2i(18, 6))        # throne — centered
	deco.call(cx - 1, 3, Vector2i(4, 1))     # candelabra flanking left
	deco.call(cx + 1, 3, Vector2i(4, 1))     # candelabra flanking right
	deco.call(cx - 3, 3, Vector2i(10, 8))    # brazier left
	deco.call(cx + 3, 3, Vector2i(10, 8))    # brazier right

	# North wall displays (row 2) — FRONT-FACING items only, spaced 3+ tiles
	deco.call(5, 2, Vector2i(0, 7))           # weapon display (swords)
	deco.call(8, 2, Vector2i(6, 2))           # stained glass
	deco.call(11, 2, Vector2i(3, 7))          # golden trophy
	deco.call(cx + 4, 2, Vector2i(7, 2))      # stained glass variant
	deco.call(cx + 7, 2, Vector2i(4, 7))      # skull mount
	deco.call(cx + 10, 2, Vector2i(8, 2))     # stained glass variant
	deco.call(w - 5, 2, Vector2i(1, 7))       # colored banner

	# Treasure (5,0) scattered in front of throne
	deco.call(cx - 2, 5, Vector2i(5, 0))      # treasure pile
	deco.call(cx + 1, 5, Vector2i(5, 0))      # treasure pile
	deco.call(cx, 6, Vector2i(5, 0))           # treasure pile

	# ============================================================
	# SECTION B: Library cluster (top-left on carpet)
	# Large furniture (7,1)(8,1) as bookshelves against wall area
	# ============================================================
	deco.call(5, 4, Vector2i(7, 1))           # bookcase/desk left
	deco.call(6, 4, Vector2i(8, 1))           # bookcase/desk right
	deco.call(7, 4, Vector2i(4, 1))           # candelabra for light
	# Reading area: bench + chairs
	deco.call(6, 6, Vector2i(9, 1))           # bench
	deco.call(5, 6, Vector2i(1, 2))           # chair RIGHT (sits left of bench, faces right toward it)
	deco.call(7, 6, Vector2i(0, 2))           # chair LEFT (sits right of bench, faces left toward it)
	deco.call(8, 5, Vector2i(9, 7))           # book stand

	# ============================================================
	# SECTION C: Bedroom (top-right on carpet)
	# Wardrobe direction: LEFT (16,6) near RIGHT wall, RIGHT (17,6) near LEFT wall
	# ============================================================
	deco.call(w - 5, 4, Vector2i(9, 0))       # bed frame
	deco.call(w - 6, 4, Vector2i(2, 0))       # chest next to bed
	deco.call(w - 4, 5, Vector2i(16, 6))      # wardrobe LEFT → near right wall (faces into room)
	deco.call(w - 7, 5, Vector2i(4, 1))       # candelabra
	deco.call(w - 5, 6, Vector2i(4, 3))       # pot/urn

	# ============================================================
	# SECTION D: Dining area (center-left) — RED horizontal carpet
	# Wide section → horizontal carpet
	# ============================================================
	for y in range(11, 19):
		for x in range(3, 15):
			carpet.call(x, y, C_H_RED)

	# Main dining table with chairs facing correct directions
	deco.call(7, 14, Vector2i(7, 0))           # large table centerpiece
	deco.call(6, 14, Vector2i(1, 2))           # chair RIGHT → left of table (faces right toward table)
	deco.call(8, 14, Vector2i(0, 2))           # chair LEFT → right of table (faces left toward table)
	deco.call(7, 13, Vector2i(1, 2))           # chair RIGHT → above table
	deco.call(7, 15, Vector2i(0, 2))           # chair LEFT → below table
	deco.call(9, 14, Vector2i(4, 1))           # candelabra near table
	deco.call(5, 12, Vector2i(4, 3))           # pot
	deco.call(11, 12, Vector2i(5, 3))          # pot variant
	# Second small table with bench
	deco.call(10, 16, Vector2i(9, 1))          # bench
	deco.call(11, 16, Vector2i(0, 2))          # chair LEFT next to bench
	# Barrel + crate in corner of dining
	deco.call(4, 17, Vector2i(0, 0))           # barrel
	deco.call(5, 17, Vector2i(1, 0))           # crate

	# ============================================================
	# SECTION E: Forge/workshop (center-right) — BLUE vertical carpet
	# Tall section → vertical carpet. Forge cluster = cauldron + barrels + sacks
	# ============================================================
	for y in range(11, 21):
		for x in range(cx + 4, w - 2):
			carpet.call(x, y, C_V_BLUE)

	# Forge cluster — cauldron + barrels + supplies GROUPED together
	deco.call(cx + 6, 13, Vector2i(3, 3))     # cauldron (centerpiece)
	deco.call(cx + 7, 13, Vector2i(0, 0))     # barrel (supplies)
	deco.call(cx + 8, 13, Vector2i(1, 0))     # crate (supplies)
	deco.call(cx + 6, 14, Vector2i(4, 0))     # sacks
	deco.call(cx + 5, 13, Vector2i(4, 3))     # pot
	deco.call(cx + 9, 14, Vector2i(10, 0))    # campfire nearby

	# Bookcase cluster along right side
	deco.call(w - 3, 16, Vector2i(7, 1))      # bookcase
	deco.call(w - 3, 17, Vector2i(8, 1))      # bookcase
	deco.call(w - 4, 17, Vector2i(9, 7))      # book stand in front
	deco.call(w - 3, 19, Vector2i(4, 1))      # candelabra

	# Storage area lower in section
	deco.call(cx + 7, 18, Vector2i(2, 0))     # chest
	deco.call(cx + 8, 18, Vector2i(4, 0))     # sacks
	deco.call(cx + 6, 19, Vector2i(0, 0))     # barrel
	deco.call(cx + 7, 19, Vector2i(1, 0))     # crate

	# ============================================================
	# SECTION F: Altar cluster (center room) — small RED connector carpet
	# ============================================================
	var altar_y = h / 2
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			carpet.call(cx + dx, altar_y + dy, C_CONN_RED)
	deco.call(cx, altar_y, Vector2i(3, 3))     # cauldron (altar centerpiece)
	deco.call(cx - 1, altar_y, Vector2i(4, 3)) # pot
	deco.call(cx + 1, altar_y, Vector2i(5, 3)) # pot variant
	deco.call(cx, altar_y - 1, Vector2i(4, 1)) # candelabra
	deco.call(cx, altar_y + 1, Vector2i(4, 1)) # candelabra
	deco.call(cx - 2, altar_y - 2, Vector2i(10, 8)) # brazier corner
	deco.call(cx + 2, altar_y - 2, Vector2i(10, 8)) # brazier corner

	# ============================================================
	# SECTION G: Barrel storage (bottom-left) — NO carpet, utilitarian
	# ============================================================
	deco.call(3, 23, Vector2i(0, 0))           # barrel
	deco.call(4, 23, Vector2i(0, 0))           # barrel
	deco.call(3, 24, Vector2i(1, 0))           # crate
	deco.call(4, 24, Vector2i(1, 0))           # crate
	deco.call(5, 23, Vector2i(4, 0))           # sacks
	deco.call(6, 24, Vector2i(4, 3))           # pot

	# ============================================================
	# SECTION H: Barrel storage (bottom-right) — NO carpet
	# ============================================================
	deco.call(w - 5, 23, Vector2i(0, 0))       # barrel
	deco.call(w - 4, 23, Vector2i(1, 0))       # crate
	deco.call(w - 5, 24, Vector2i(0, 0))       # barrel
	deco.call(w - 4, 24, Vector2i(4, 0))       # sacks

	# ============================================================
	# LEFT WALL items — RIGHT-facing wardrobe (17,6) faces into room
	# ============================================================
	deco.call(1, 10, Vector2i(17, 6))          # wardrobe RIGHT → near left wall (faces right into room)
	deco.call(1, 14, Vector2i(0, 0))           # barrel
	deco.call(1, 18, Vector2i(2, 0))           # chest
	deco.call(1, 21, Vector2i(1, 0))           # crate

	# ============================================================
	# RIGHT WALL items — LEFT-facing wardrobe (16,6) faces into room
	# ============================================================
	deco.call(w - 2, 10, Vector2i(16, 6))      # wardrobe LEFT → near right wall (faces left into room)
	deco.call(w - 2, 14, Vector2i(2, 0))       # chest
	deco.call(w - 2, 22, Vector2i(0, 0))       # barrel

	# ============================================================
	# BRAZIERS at section boundaries (between carpet areas and bare stone)
	# ============================================================
	deco.call(2, 9, Vector2i(10, 8))
	deco.call(w - 3, 9, Vector2i(10, 8))
	deco.call(2, 21, Vector2i(10, 8))
	deco.call(w - 3, 21, Vector2i(10, 8))
	deco.call(14, 9, Vector2i(10, 8))

	# ============================================================
	# FLOOR CANDLES inside carpet sections
	# ============================================================
	deco.call(6, 10, Vector2i(12, 7))
	deco.call(cx, 9, Vector2i(12, 7))
	deco.call(w - 6, 11, Vector2i(12, 7))
	deco.call(cx, 20, Vector2i(12, 7))
	deco.call(10, 22, Vector2i(12, 7))

	# ============================================================
	# FLOOR SCATTER: bones, moss (non-collideable overlay, rows 4-5)
	# ============================================================
	deco.call(15, 22, Vector2i(0, 4))          # bones/cobweb
	deco.call(cx - 4, 25, Vector2i(1, 4))      # bones variant
	deco.call(12, 26, Vector2i(4, 4))           # rubble
	deco.call(9, 27, Vector2i(0, 5))            # moss
	deco.call(w - 8, 26, Vector2i(1, 5))        # moss variant
	# Blood near forge (industrial area)
	deco.call(cx + 5, 15, Vector2i(10, 6))
	# Skull near barrel storage
	deco.call(8, 25, Vector2i(0, 6))
