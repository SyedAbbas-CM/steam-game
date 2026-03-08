@tool
extends Node2D
## Open scenes/samples/sample_rooms.tscn in the editor to see example rooms.
## Edit tiles freely — they bake into the .tscn on save.

@onready var floor_layer: TileMapLayer = $Floor
@onready var walls_layer: TileMapLayer = $Walls
@onready var deco_layer: TileMapLayer = $Decorations
@onready var door_layer: TileMapLayer = $Doors

const ROOM_W = 17
const ROOM_H = 15
const GAP = 3  # tiles between rooms

func _ready() -> void:
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

func _paint_sample_room(origin: Vector2i, theme_row: int, hazards: Array, decos: Array, door_style: String,
		has_north: bool, has_south: bool, has_east: bool, has_west: bool) -> void:
	var floor_tile = Vector2i(5, theme_row)
	var floor_tile_2 = Vector2i(6, theme_row)
	var wall_tile = Vector2i(4, theme_row)
	var wall_roof = Vector2i(0, theme_row)
	var wall_candle = Vector2i(1, theme_row)
	var wall_candle_2 = Vector2i(2, theme_row)
	var wall_cracked = Vector2i(3, theme_row)
	var dirt_tile = Vector2i(12, theme_row)
	var trap_tile = Vector2i(13, theme_row)
	var stairs_down = Vector2i(8, theme_row)

	var mid_x = ROOM_W / 2
	var mid_y = ROOM_H / 2

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
