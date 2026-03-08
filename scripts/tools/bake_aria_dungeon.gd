extends SceneTree

# Bakes an Aria dungeon floor into a static, editable scene
# Run: godot --headless --script scripts/tools/bake_aria_dungeon.gd
#
# Source 0 = lofiEnvironment.png (16x26 grid, 8x8 tiles)
# Source 1 = lofi_dungeon_features.png (12x9 grid, 8x8 tiles)

# Grid cell size matches runtime dungeon_manager.gd
const GRID_CELL_W = 25
const GRID_CELL_H = 23
const TILE_SIZE = 8

const SRC_ENV = 0   # environment tileset source
const SRC_DNG = 1   # dungeon features source

const THEME_ROWS = {
	"grey": 0, "brown": 1, "blue": 2, "red": 3,
	"green": 4, "yellow": 5, "purple": 6, "white": 7,
	"cyan": 8, "orange": 9, "pink": 10, "black": 11, "gold": 12, "crimson": 13
}

var BIOME_PATH = "res://resources/biomes/dusty_cellar.tres"
var THEME_ROW = 1  # brown (default, overridden by biome)

func _init():
	_bake()
	quit()

func _bake():
	var scene_path = "res://scenes/dungeon/aria_dungeon_v3.tscn"
	var tileset_path = "res://assets/tilesets/environment_tileset.tres"

	var tileset = load(tileset_path) as TileSet
	if not tileset:
		print("ERROR: Cannot load tileset")
		return

	# Load biome and set theme
	var biome = load(BIOME_PATH) as DungeonBiome
	if biome:
		THEME_ROW = THEME_ROWS.get(biome.theme, 1)
		print("Biome: %s, Theme: %s (row %d), Tier: %d" % [biome.biome_name, biome.theme, THEME_ROW, biome.difficulty_tier])
	else:
		print("WARNING: Could not load biome at %s, using default brown theme" % BIOME_PATH)

	var root = Node2D.new()
	root.name = "AriaDungeon"

	# Create TileMapLayers (same as runtime dungeon scene, no Doors layer)
	var floor_layer = _add_layer(root, "Floor", tileset, 0)
	var liquid_layer = _add_layer(root, "Liquids", tileset, 1)
	var wall_layer = _add_layer(root, "Walls", tileset, 2)
	var deco_layer = _add_layer(root, "Decorations", tileset, 3)

	# Generate room layout (8 rooms for Aria)
	seed(42)
	var rooms = _generate_rooms(8)
	var start_pos = rooms[0]["pos"]
	var stairs_pos = rooms[rooms.size() - 1]["pos"]

	print("Generated %d rooms" % rooms.size())
	print("Start: %s, Stairs: %s" % [str(start_pos), str(stairs_pos)])

	# Paint rooms with decorations based on type
	for room in rooms:
		_paint_room(floor_layer, wall_layer, deco_layer, liquid_layer, room)

	# Paint corridors
	for room in rooms:
		for connection in room.get("connections", []):
			var target = connection["target"]
			var direction = connection["direction"]
			if direction == "east" or direction == "south":
				var target_room = _find_room(rooms, target)
				_paint_corridor(floor_layer, wall_layer, liquid_layer, deco_layer, room, target_room, direction)

	# Place stairs in last room
	var stairs_room = rooms[rooms.size() - 1]
	var stairs_mask = stairs_room["mask"]
	var sw = stairs_room["width"]
	var sh = stairs_room["height"]
	var stairs_origin = _grid_to_tile_origin(stairs_pos)
	var cx = sw / 2
	var cy = sh / 2 - 2
	if cy > 0 and cy < sh and stairs_mask[cy][cx]:
		deco_layer.set_cell(stairs_origin + Vector2i(cx, cy), SRC_ENV, Vector2i(8, THEME_ROW))
	else:
		cy = sh / 2
		deco_layer.set_cell(stairs_origin + Vector2i(cx, cy), SRC_ENV, Vector2i(8, THEME_ROW))

	# Add room type labels
	for room in rooms:
		var label = Label.new()
		label.name = "RoomLabel_%d_%d" % [room["pos"].x, room["pos"].y]
		var origin = _grid_to_tile_origin(room["pos"])
		label.position = Vector2(origin.x * TILE_SIZE + 4, origin.y * TILE_SIZE + 4)
		label.text = room.get("type_name", "combat")
		label.add_theme_font_size_override("font_size", 6)
		label.add_theme_color_override("font_color", Color(1, 1, 0, 0.6))
		label.z_index = 10
		root.add_child(label)
		label.owner = root

	# Placeholder containers
	for container_name in ["RoomTriggers", "EnemyContainer", "HazardContainer"]:
		var c = Node2D.new()
		c.name = container_name
		if container_name == "EnemyContainer":
			c.z_index = 1
		root.add_child(c)
		c.owner = root

	# Stats
	print("Floor: %d, Liquids: %d, Walls: %d, Deco: %d" % [
		floor_layer.get_used_cells().size(),
		liquid_layer.get_used_cells().size(),
		wall_layer.get_used_cells().size(),
		deco_layer.get_used_cells().size()
	])

	var packed = PackedScene.new()
	packed.pack(root)
	var err = ResourceSaver.save(packed, scene_path)
	if err == OK:
		print("SUCCESS: Aria dungeon baked to " + scene_path)
	else:
		print("ERROR saving: " + str(err))
	root.queue_free()

func _add_layer(root: Node2D, layer_name: String, tileset: TileSet, z: int) -> TileMapLayer:
	var layer = TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tileset
	layer.z_index = z
	root.add_child(layer)
	layer.owner = root
	return layer

func _find_room(rooms: Array, pos: Vector2i) -> Dictionary:
	for room in rooms:
		if room["pos"] == pos:
			return room
	return rooms[0]

func _generate_rooms(count: int) -> Array:
	var rooms = []
	var positions: Array[Vector2i] = []
	var current = Vector2i.ZERO
	var directions = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

	positions.append(current)
	while positions.size() < count:
		var dir = directions[randi() % 4]
		var next_pos = current + dir
		if not next_pos in positions:
			positions.append(next_pos)
		current = next_pos

	var type_names = ["start", "combat", "combat", "treasure", "combat", "shrine", "combat", "stairs"]

	# Room shapes for variety
	var shapes = [
		RoomData.RoomShape.RECTANGLE,  # start
		RoomData.RoomShape.WIDE_RECT,  # combat
		RoomData.RoomShape.CIRCLE,     # combat
		RoomData.RoomShape.RECTANGLE,  # treasure
		RoomData.RoomShape.L_SHAPE_NE, # combat
		RoomData.RoomShape.CIRCLE,     # shrine
		RoomData.RoomShape.TALL_RECT,  # combat
		RoomData.RoomShape.RECTANGLE,  # stairs
	]

	for i in range(positions.size()):
		var shape_enum = shapes[mini(i, shapes.size() - 1)]
		var shape_data = RoomShapeGenerator.generate_shape(shape_enum)

		var room = {
			"pos": positions[i],
			"type_name": type_names[mini(i, type_names.size() - 1)],
			"connections": [],
			"mask": shape_data["mask"],
			"width": shape_data["width"],
			"height": shape_data["height"],
		}
		for dir in directions:
			var neighbor = positions[i] + dir
			if neighbor in positions:
				var dir_name = ""
				if dir == Vector2i(0, -1): dir_name = "north"
				elif dir == Vector2i(0, 1): dir_name = "south"
				elif dir == Vector2i(-1, 0): dir_name = "west"
				elif dir == Vector2i(1, 0): dir_name = "east"
				room["connections"].append({"direction": dir_name, "target": neighbor})
		rooms.append(room)
	return rooms

func _grid_to_tile_origin(grid_pos: Vector2i) -> Vector2i:
	return Vector2i(
		grid_pos.x * GRID_CELL_W,
		grid_pos.y * GRID_CELL_H
	)

# ---- Room painting ----

func _paint_room(floor_l: TileMapLayer, wall_l: TileMapLayer, deco_l: TileMapLayer, liquid_l: TileMapLayer, room: Dictionary) -> void:
	var origin = _grid_to_tile_origin(room["pos"])
	var type_name = room.get("type_name", "combat")
	var mask = room["mask"]
	var w = room["width"] as int
	var h = room["height"] as int

	var floor_tile = Vector2i(5, THEME_ROW)
	var floor_tile_2 = Vector2i(6, THEME_ROW)
	var wall_tile = Vector2i(4, THEME_ROW)
	var wall_cracked = Vector2i(3, THEME_ROW)
	var wall_candle = Vector2i(1, THEME_ROW)
	var wall_candle2 = Vector2i(2, THEME_ROW)
	var wall_roof = Vector2i(0, THEME_ROW)

	# Paint floor and walls using mask
	for y in range(h):
		for x in range(w):
			var tile_pos = origin + Vector2i(x, y)
			if mask[y][x]:
				var tile = floor_tile if randf() > 0.15 else floor_tile_2
				floor_l.set_cell(tile_pos, SRC_ENV, tile)
			elif _is_wall_adjacent(mask, x, y, w, h):
				var wt = _pick_wall_tile(mask, x, y, w, h, wall_roof, wall_tile, wall_candle, wall_candle2, wall_cracked)
				wall_l.set_cell(tile_pos, SRC_ENV, wt)

	# Room-type-specific decorations
	match type_name:
		"start":
			_deco_start_room(deco_l, origin, mask, w, h)
		"combat":
			_deco_combat_room(deco_l, liquid_l, floor_l, origin, mask, w, h, room)
		"treasure":
			_deco_treasure_room(deco_l, origin, mask, w, h)
		"shrine":
			_deco_shrine_room(deco_l, liquid_l, floor_l, origin, mask, w, h, room)
		"stairs":
			_deco_stairs_room(deco_l, origin, mask, w, h)

	# Scatter floor details
	_scatter_floor_details(deco_l, origin, mask, w, h)

func _is_wall_adjacent(mask: Array, x: int, y: int, w: int, h: int) -> bool:
	var dirs = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for d in dirs:
		var nx = x + d.x
		var ny = y + d.y
		if nx >= 0 and nx < w and ny >= 0 and ny < h and mask[ny][nx]:
			return true
	return false

func _pick_wall_tile(mask: Array, x: int, y: int, w: int, h: int,
		wall_roof: Vector2i, wall_tile: Vector2i, wall_candle: Vector2i,
		wall_candle2: Vector2i, wall_cracked: Vector2i) -> Vector2i:
	var has_floor_below = (y + 1 < h and mask[y + 1][x])
	var has_floor_right = (x + 1 < w and mask[y][x + 1])
	var has_floor_left = (x - 1 >= 0 and mask[y][x - 1])
	if has_floor_below:
		if randf() < 0.15: return wall_cracked
		return wall_roof
	elif has_floor_right:
		if randf() < 0.2: return wall_candle
		return wall_tile
	elif has_floor_left:
		if randf() < 0.2: return wall_candle2
		return wall_tile
	return wall_tile

func _random_interior(mask: Array, w: int, h: int, border: int) -> Vector2i:
	for _a in range(20):
		var x = randi_range(border, w - border - 1)
		var y = randi_range(border, h - border - 1)
		if x >= 0 and x < w and y >= 0 and y < h and mask[y][x]:
			return Vector2i(x, y)
	return Vector2i(w / 2, h / 2)

# ---- Decorations ----

func _deco_start_room(deco_l: TileMapLayer, origin: Vector2i, mask: Array, w: int, h: int) -> void:
	var cx = w / 2
	var cy = h / 2
	deco_l.set_cell(origin + Vector2i(cx, cy), SRC_DNG, Vector2i(10, 0))  # campfire
	deco_l.set_cell(origin + Vector2i(cx - 2, cy), SRC_DNG, Vector2i(9, 1))  # bench
	deco_l.set_cell(origin + Vector2i(cx + 2, cy), SRC_DNG, Vector2i(9, 1))  # bench
	# Sacks and crates near walls
	var p1 = _random_interior(mask, w, h, 1)
	deco_l.set_cell(origin + p1, SRC_DNG, Vector2i(4, 0))  # sacks
	var p2 = _random_interior(mask, w, h, 1)
	deco_l.set_cell(origin + p2, SRC_DNG, Vector2i(1, 0))  # crate
	var p3 = _random_interior(mask, w, h, 1)
	deco_l.set_cell(origin + p3, SRC_DNG, Vector2i(0, 0))  # barrel

func _deco_combat_room(deco_l: TileMapLayer, liquid_l: TileMapLayer, floor_l: TileMapLayer, origin: Vector2i, mask: Array, w: int, h: int, room: Dictionary) -> void:
	var variant = randi() % 6
	var cx = w / 2
	var cy = h / 2
	match variant:
		0:  # Lava flow room
			_paint_liquid_flow(liquid_l, floor_l, deco_l, origin, mask, w, h, "lava", 0.4, room)
		1:  # Poison swamp room
			_paint_liquid_flow(liquid_l, floor_l, deco_l, origin, mask, w, h, "poison", 0.35, room)
		2:  # Pillared room
			for px in [cx - 4, cx, cx + 4]:
				for py in [cy - 3, cy + 3]:
					if px > 0 and px < w and py > 0 and py < h and mask[py][px]:
						deco_l.set_cell(origin + Vector2i(px, py), SRC_DNG, Vector2i(5, 2))
		3:  # Barricade room
			for x in range(cx - 3, cx + 4):
				if x > 0 and x < w:
					if cy - 2 > 0 and mask[cy - 2][x]:
						deco_l.set_cell(origin + Vector2i(x, cy - 2), SRC_DNG, Vector2i(8, 0))
					if cy + 2 < h and mask[cy + 2][x]:
						deco_l.set_cell(origin + Vector2i(x, cy + 2), SRC_DNG, Vector2i(8, 0))
		4:  # Water pool room
			_paint_liquid_flow(liquid_l, floor_l, deco_l, origin, mask, w, h, "water", 0.3, room, false)
			# Scatter moss around water
			for _i in range(6):
				var p = _random_interior(mask, w, h, 2)
				var cell = origin + p
				if deco_l.get_cell_source_id(cell) == -1:
					var moss_tiles = [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5)]
					deco_l.set_cell(cell, SRC_DNG, moss_tiles[randi() % moss_tiles.size()])
		5:  # Bone/rubble room
			for _i in range(5):
				var p = _random_interior(mask, w, h, 2)
				var cell = origin + p
				if deco_l.get_cell_source_id(cell) == -1:
					var bone_tiles = [Vector2i(0, 4), Vector2i(1, 4), Vector2i(4, 4), Vector2i(5, 4)]
					deco_l.set_cell(cell, SRC_DNG, bone_tiles[randi() % bone_tiles.size()])
			# Add barrels/crates near walls
			for _i in range(3):
				var p = _random_interior(mask, w, h, 1)
				var cell = origin + p
				if deco_l.get_cell_source_id(cell) == -1:
					var prop_tiles = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(4, 0)]
					deco_l.set_cell(cell, SRC_DNG, prop_tiles[randi() % prop_tiles.size()])

func _deco_treasure_room(deco_l: TileMapLayer, origin: Vector2i, mask: Array, w: int, h: int) -> void:
	var cx = w / 2
	var cy = h / 2
	deco_l.set_cell(origin + Vector2i(cx - 1, cy), SRC_DNG, Vector2i(2, 0))  # chest
	deco_l.set_cell(origin + Vector2i(cx, cy), SRC_DNG, Vector2i(5, 0))      # treasure
	deco_l.set_cell(origin + Vector2i(cx + 1, cy), SRC_DNG, Vector2i(2, 0))  # chest
	# Scatter pots/urns
	for _i in range(4):
		var p = _random_interior(mask, w, h, 2)
		var pot_tiles = [Vector2i(4, 3), Vector2i(5, 3), Vector2i(10, 3), Vector2i(9, 3)]
		deco_l.set_cell(origin + p, SRC_DNG, pot_tiles[randi() % pot_tiles.size()])
	# Gold orbs
	deco_l.set_cell(origin + Vector2i(cx - 2, cy - 2), SRC_ENV, Vector2i(3, 19))
	deco_l.set_cell(origin + Vector2i(cx + 2, cy - 2), SRC_ENV, Vector2i(3, 19))

func _deco_shrine_room(deco_l: TileMapLayer, liquid_l: TileMapLayer, floor_l: TileMapLayer, origin: Vector2i, mask: Array, w: int, h: int, room: Dictionary) -> void:
	var cx = w / 2
	var cy = h / 2
	# Central water pool (non-directional, pool style)
	_paint_liquid_flow(liquid_l, floor_l, deco_l, origin, mask, w, h, "water", 0.3, room, false)
	# Pillars around center
	for dx in [-3, 3]:
		for dy in [-3, 3]:
			var px = cx + dx
			var py = cy + dy
			if px > 0 and px < w and py > 0 and py < h and mask[py][px]:
				deco_l.set_cell(origin + Vector2i(px, py), SRC_DNG, Vector2i(5, 2))
	# Blue orbs
	if cx - 3 > 0 and cy - 4 > 0 and cy - 4 < h and mask[cy - 4][cx - 3]:
		deco_l.set_cell(origin + Vector2i(cx - 3, cy - 4), SRC_ENV, Vector2i(1, 19))
	if cx + 3 < w and cy - 4 > 0 and cy - 4 < h and mask[cy - 4][cx + 3]:
		deco_l.set_cell(origin + Vector2i(cx + 3, cy - 4), SRC_ENV, Vector2i(1, 19))
	# Cauldron
	deco_l.set_cell(origin + Vector2i(cx, cy - 3), SRC_DNG, Vector2i(3, 3))
	# Stained glass along top wall
	for dx in [-2, -1, 0, 1, 2]:
		var gx = cx + dx
		var gy = 2
		if gx > 0 and gx < w and gy < h and not mask[gy][gx]:
			var glass_tiles = [Vector2i(6, 2), Vector2i(7, 2), Vector2i(8, 2)]
			deco_l.set_cell(origin + Vector2i(gx, gy), SRC_DNG, glass_tiles[randi() % glass_tiles.size()])
	# Candelabras flanking entrance
	for dx in [-5, 5]:
		var tx = cx + dx
		if tx > 0 and tx < w and cy > 0 and cy < h and mask[cy][tx]:
			deco_l.set_cell(origin + Vector2i(tx, cy), SRC_DNG, Vector2i(4, 1))

func _deco_stairs_room(deco_l: TileMapLayer, origin: Vector2i, mask: Array, w: int, h: int) -> void:
	var cx = w / 2
	var cy = h / 2
	# Torches
	for dx in [-2, 2]:
		for dy in [-3, 3]:
			var px = cx + dx
			var py = cy + dy
			if px > 0 and px < w and py > 0 and py < h and mask[py][px]:
				deco_l.set_cell(origin + Vector2i(px, py), SRC_DNG, Vector2i(4, 1))
	# Bones, skulls, and cobwebs
	for _i in range(5):
		var p = _random_interior(mask, w, h, 1)
		var cell = origin + p
		if deco_l.get_cell_source_id(cell) == -1:
			var deco_tiles = [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)]
			deco_l.set_cell(cell, SRC_DNG, deco_tiles[randi() % deco_tiles.size()])
	# Moss near walls
	for _i in range(3):
		var p = _random_interior(mask, w, h, 1)
		var cell = origin + p
		if deco_l.get_cell_source_id(cell) == -1:
			var moss_tiles = [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5)]
			deco_l.set_cell(cell, SRC_DNG, moss_tiles[randi() % moss_tiles.size()])

# ---- Liquid flows ----

func _paint_liquid_flow(liquid_l: TileMapLayer, floor_l: TileMapLayer, deco_l: TileMapLayer, origin: Vector2i, mask: Array, w: int, h: int, liquid_type: String, intensity: float, room: Dictionary, directional: bool = true) -> void:
	var seed_val = origin.x * 1000 + origin.y

	# Build connection dict for WebBridgeGenerator
	var conn_dict: Dictionary = {}
	for conn in room.get("connections", []):
		conn_dict[conn["direction"]] = conn["target"]

	# Generate liquid: directional river or pool-style fill
	var liquid_mask: Array
	if directional and conn_dict.size() > 0:
		# Pick a flow direction from a random connection
		var dir_names = conn_dict.keys()
		var flow_dir_name = dir_names[randi() % dir_names.size()]
		var flow_dir = Vector2.ZERO
		match flow_dir_name:
			"north": flow_dir = Vector2(0, -1)
			"south": flow_dir = Vector2(0, 1)
			"east": flow_dir = Vector2(1, 0)
			"west": flow_dir = Vector2(-1, 0)
		liquid_mask = LiquidGenerator.generate_directional_flow(mask, intensity, seed_val, flow_dir)
		room["has_liquid"] = true
		room["liquid_type"] = liquid_type
	else:
		liquid_mask = LiquidGenerator.generate_liquid_fill(mask, intensity, seed_val)
		room["has_liquid"] = true
		room["liquid_type"] = liquid_type

	# Get liquid tiles
	var liquid_tiles: Array = []
	match liquid_type:
		"lava": liquid_tiles = [Vector2i(0, 17), Vector2i(0, 18)]
		"poison": liquid_tiles = [Vector2i(1, 17), Vector2i(1, 18)]
		"water": liquid_tiles = [Vector2i(2, 17), Vector2i(2, 18)]

	if liquid_tiles.is_empty():
		return

	# Paint liquid tiles
	for y in range(h):
		for x in range(w):
			if liquid_mask[y][x]:
				var tile = liquid_tiles[randi() % liquid_tiles.size()]
				liquid_l.set_cell(origin + Vector2i(x, y), SRC_ENV, tile)

	# Generate spider web bridges using actual connections
	var web_positions = WebBridgeGenerator.generate_bridges(mask, liquid_mask, 0.25, conn_dict, w, h)
	for pos in web_positions:
		deco_l.set_cell(origin + pos, SRC_ENV, Vector2i(5, 19))

# ---- Floor detail scatter ----

func _scatter_floor_details(deco_l: TileMapLayer, origin: Vector2i, mask: Array, w: int, h: int) -> void:
	for _i in range(10):
		var p = _random_interior(mask, w, h, 2)
		var cell = origin + p
		if deco_l.get_cell_source_id(cell) != -1:
			continue
		var detail_tiles = [
			# Cracks, gravel, dust (Source 1 Row 6)
			Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6),
			Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6), Vector2i(7, 6),
			# Mossy tiles (Source 1 Row 5)
			Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5),
			# Cobwebs (Source 1 Row 4)
			Vector2i(2, 4), Vector2i(3, 4),
			# Rubble (Source 1 Row 4)
			Vector2i(4, 4), Vector2i(5, 4),
		]
		deco_l.set_cell(cell, SRC_DNG, detail_tiles[randi() % detail_tiles.size()])

# ---- Corridors ----

func _paint_corridor(floor_l: TileMapLayer, wall_l: TileMapLayer, liquid_l: TileMapLayer, deco_l: TileMapLayer, from_room: Dictionary, to_room: Dictionary, direction: String) -> void:
	var floor_tile = Vector2i(5, THEME_ROW)
	var wall_tile = Vector2i(4, THEME_ROW)
	var from_origin = _grid_to_tile_origin(from_room["pos"])
	var to_origin = _grid_to_tile_origin(to_room["pos"])
	var from_mask = from_room["mask"]
	var to_mask = to_room["mask"]
	var fw = from_room["width"] as int
	var fh = from_room["height"] as int
	var tw = to_room["width"] as int
	var th = to_room["height"] as int

	# Check if corridor should have liquid (both rooms have liquid)
	var has_liquid = from_room.get("has_liquid", false) and to_room.get("has_liquid", false)
	var liquid_type = from_room.get("liquid_type", "lava") if has_liquid else ""
	var liquid_tiles: Array = []
	if has_liquid:
		match liquid_type:
			"lava": liquid_tiles = [Vector2i(0, 17), Vector2i(0, 18)]
			"poison": liquid_tiles = [Vector2i(1, 17), Vector2i(1, 18)]
			"water": liquid_tiles = [Vector2i(2, 17), Vector2i(2, 18)]

	if direction == "east":
		var from_exit = RoomShapeGenerator.get_exit_point(from_mask, fw, fh, "east")
		var to_exit = RoomShapeGenerator.get_exit_point(to_mask, tw, th, "west")
		var start_x = from_origin.x + fw
		var end_x = to_origin.x
		var from_mid_y = from_origin.y + from_exit.y
		var to_mid_y = to_origin.y + to_exit.y

		for x in range(start_x, end_x):
			var t = 0.0
			if end_x > start_x:
				t = float(x - start_x) / float(end_x - start_x)
			var mid_y = int(lerp(float(from_mid_y), float(to_mid_y), t))
			for dy in range(-1, 2):
				floor_l.set_cell(Vector2i(x, mid_y + dy), SRC_ENV, floor_tile)
			wall_l.set_cell(Vector2i(x, mid_y - 2), SRC_ENV, wall_tile)
			wall_l.set_cell(Vector2i(x, mid_y + 2), SRC_ENV, wall_tile)
			# Corridor liquid: outer tiles get liquid, center gets web bridge
			if has_liquid and liquid_tiles.size() > 0:
				liquid_l.set_cell(Vector2i(x, mid_y - 1), SRC_ENV, liquid_tiles[randi() % liquid_tiles.size()])
				liquid_l.set_cell(Vector2i(x, mid_y + 1), SRC_ENV, liquid_tiles[randi() % liquid_tiles.size()])
				deco_l.set_cell(Vector2i(x, mid_y), SRC_ENV, Vector2i(5, 19))  # web bridge center

		_open_exit_wall(floor_l, wall_l, from_origin, from_exit, from_mask, fw, fh, floor_tile)
		_open_exit_wall(floor_l, wall_l, to_origin, to_exit, to_mask, tw, th, floor_tile)

	elif direction == "south":
		var from_exit = RoomShapeGenerator.get_exit_point(from_mask, fw, fh, "south")
		var to_exit = RoomShapeGenerator.get_exit_point(to_mask, tw, th, "north")
		var start_y = from_origin.y + fh
		var end_y = to_origin.y
		var from_mid_x = from_origin.x + from_exit.x
		var to_mid_x = to_origin.x + to_exit.x

		for y in range(start_y, end_y):
			var t = 0.0
			if end_y > start_y:
				t = float(y - start_y) / float(end_y - start_y)
			var mid_x = int(lerp(float(from_mid_x), float(to_mid_x), t))
			for dx in range(-1, 2):
				floor_l.set_cell(Vector2i(mid_x + dx, y), SRC_ENV, floor_tile)
			wall_l.set_cell(Vector2i(mid_x - 2, y), SRC_ENV, wall_tile)
			wall_l.set_cell(Vector2i(mid_x + 2, y), SRC_ENV, wall_tile)
			# Corridor liquid
			if has_liquid and liquid_tiles.size() > 0:
				liquid_l.set_cell(Vector2i(mid_x - 1, y), SRC_ENV, liquid_tiles[randi() % liquid_tiles.size()])
				liquid_l.set_cell(Vector2i(mid_x + 1, y), SRC_ENV, liquid_tiles[randi() % liquid_tiles.size()])
				deco_l.set_cell(Vector2i(mid_x, y), SRC_ENV, Vector2i(5, 19))  # web bridge center

		_open_exit_wall(floor_l, wall_l, from_origin, from_exit, from_mask, fw, fh, floor_tile)
		_open_exit_wall(floor_l, wall_l, to_origin, to_exit, to_mask, tw, th, floor_tile)

func _open_exit_wall(floor_l: TileMapLayer, wall_l: TileMapLayer, origin: Vector2i, exit_point: Vector2i, mask: Array, w: int, h: int, floor_tile: Vector2i) -> void:
	for offset in range(-1, 2):
		var tx: int
		var ty: int
		if exit_point.x == 0 or exit_point.x == w - 1:
			tx = exit_point.x
			ty = exit_point.y + offset
		else:
			tx = exit_point.x + offset
			ty = exit_point.y
		if tx >= 0 and tx < w and ty >= 0 and ty < h:
			var tile_pos = origin + Vector2i(tx, ty)
			wall_l.erase_cell(tile_pos)
			floor_l.set_cell(tile_pos, SRC_ENV, floor_tile)
