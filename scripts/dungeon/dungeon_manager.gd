class_name DungeonManager
extends Node2D

signal floor_changed(floor_number: int)
signal room_changed(room_index: int, room_data: RoomData)
signal run_ended(run_state: RunState)
signal reward_requested(room_data: RoomData)

var run_state: RunState
var current_biome: DungeonBiome
var starting_biome_name: String = ""

# Persistent tilemap layers (children in scene tree)
@onready var floor_layer: TileMapLayer = $Floor
@onready var wall_layer: TileMapLayer = $Walls
@onready var deco_layer: TileMapLayer = $Decorations
@onready var liquid_layer: TileMapLayer = $Liquids
@onready var room_triggers: Node2D = $RoomTriggers
@onready var enemy_container: Node2D = $EnemyContainer
@onready var hazard_container: Node2D = $HazardContainer
@onready var player: CharacterBody2D = $Player

var biomes: Array[DungeonBiome] = []
var level_data: Array[DungeonLevelData] = []
var dungeon_levels: Array[DungeonLevelData] = []
var current_level: DungeonLevelData

# Room state: grid_pos -> { "visited", "alive", "cleared", "liquid_mask", "web_positions" }
var room_states: Dictionary = {}

# Transition tracking
var transitions: Array = []  # Array of RoomTransition nodes
var transition_container: Node2D

const THEME_ROWS = {
	"grey": 0, "brown": 1, "blue": 2, "red": 3,
	"green": 4, "yellow": 5, "purple": 6, "white": 7,
	"cyan": 8, "orange": 9, "pink": 10, "black": 11,
	"gold": 12, "crimson": 13,
}

# Grid cell size must fit largest room shape (21x19 L-shape) + corridor gap
const GRID_CELL_W = 25
const GRID_CELL_H = 23
const TILE_SIZE = 8
const CORRIDOR_WIDTH = 3

# Liquid atlas coords per type (source 0, environment tileset)
const LIQUID_TILES = {
	"lava": [Vector2i(0, 17), Vector2i(0, 18)],
	"poison": [Vector2i(1, 17), Vector2i(1, 18)],
	"water": [Vector2i(2, 17), Vector2i(2, 18)],
}

const SPIDER_WEB_FULL = Vector2i(5, 19)

var wall_body: StaticBody2D

func _ready() -> void:
	add_to_group("dungeon_manager")
	RenderingServer.set_default_clear_color(Color.BLACK)
	var t0 = Time.get_ticks_msec()
	_load_biomes()
	print("TIMING: _load_biomes took %d ms" % (Time.get_ticks_msec() - t0))
	# Create transition container
	transition_container = Node2D.new()
	transition_container.name = "Transitions"
	add_child(transition_container)

func _load_biomes() -> void:
	var t0 = Time.get_ticks_msec()
	var dir = DirAccess.open("res://resources/biomes/")
	if not dir:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres") and not fname.begins_with("."):
			var res = load("res://resources/biomes/" + fname) as DungeonBiome
			if res:
				biomes.append(res)
		fname = dir.get_next()
	biomes.sort_custom(func(a: DungeonBiome, b: DungeonBiome) -> bool: return a.min_floor < b.min_floor)
	print("TIMING: loaded %d biomes in %d ms" % [biomes.size(), Time.get_ticks_msec() - t0])

var _levels_loaded_for: String = ""  # tracks which dungeon we loaded levels for

func _load_level_data_for(dungeon_name: String) -> void:
	# Only load levels matching the dungeon name (not all 199)
	if _levels_loaded_for == dungeon_name and level_data.size() > 0:
		return
	_levels_loaded_for = dungeon_name
	level_data.clear()
	var t0 = Time.get_ticks_msec()
	var dir = DirAccess.open("res://resources/levels/")
	if not dir:
		return
	# Normalize: "Aria-Dungeons" → "aria_dungeons"
	var dname = dungeon_name.to_lower().replace(" ", "_").replace("-", "_")
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var fbase = fname.get_basename().to_lower()
			if dname == "" or fbase.begins_with(dname) or fbase == dname:
				var res = load("res://resources/levels/" + fname) as DungeonLevelData
				if res and res.id != "":
					level_data.append(res)
		fname = dir.get_next()
	print("TIMING: Loaded %d level definitions for '%s' (slug='%s') in %d ms" % [level_data.size(), dungeon_name, dname, Time.get_ticks_msec() - t0])

func start_run() -> void:
	var t0 = Time.get_ticks_msec()
	run_state = RunState.new()
	run_state.run_id = str(randi())
	run_state.current_floor = 1

	dungeon_levels = _find_level_chain(starting_biome_name)
	print("TIMING: _find_level_chain took %d ms" % (Time.get_ticks_msec() - t0))
	if dungeon_levels.size() > 0:
		current_level = dungeon_levels[0]
	else:
		current_level = null

	current_biome = _get_biome_for_floor(1)
	if current_biome:
		print("Dungeon: Biome = '%s', enemy_pool size = %d" % [current_biome.biome_name, current_biome.enemy_pool.size()])
	else:
		print("Dungeon: WARNING - No biome found for starting_biome_name='%s'" % starting_biome_name)
	_generate_floor(1)
	print("TIMING: TOTAL start_run took %d ms" % (Time.get_ticks_msec() - t0))
	floor_changed.emit(1)

func _find_level_chain(dungeon_name: String) -> Array[DungeonLevelData]:
	_load_level_data_for(dungeon_name)  # lazy load only matching levels
	var chain: Array[DungeonLevelData] = []
	if dungeon_name == "":
		return chain
	for ld in level_data:
		chain.append(ld)  # already filtered during load
	chain.sort_custom(func(a: DungeonLevelData, b: DungeonLevelData) -> bool:
		return a.id.naturalnocasecmp_to(b.id) < 0
	)
	return chain

func _get_level_for_floor(floor_num: int) -> DungeonLevelData:
	if dungeon_levels.size() > 0:
		var idx = mini(floor_num - 1, dungeon_levels.size() - 1)
		return dungeon_levels[idx]
	return null

func _get_biome_for_floor(floor_num: int) -> DungeonBiome:
	var level = _get_level_for_floor(floor_num)
	if level:
		current_level = level
	if floor_num == 1 and starting_biome_name != "":
		for b in biomes:
			if b.biome_name == starting_biome_name:
				return b
	for b in biomes:
		if floor_num >= b.min_floor and floor_num <= b.max_floor:
			return b
	if biomes.size() > 0:
		return biomes[(floor_num - 1) % biomes.size()]
	return null

func _generate_floor(floor_num: int) -> void:
	var t0 = Time.get_ticks_msec()
	_clear_floor()

	var level = _get_level_for_floor(floor_num)
	var room_override = -1
	if level:
		room_override = level.rooms

	var t1 = Time.get_ticks_msec()
	var map = FloorGenerator.generate_floor_map(floor_num, room_override, current_biome)
	print("TIMING: generate_floor_map took %d ms (%d rooms)" % [Time.get_ticks_msec() - t1, map["rooms"].size()])
	run_state.floor_map = map["rooms"]
	run_state.current_grid_pos = map["start"]
	run_state.stairs_pos = map["stairs"]

	# Determine theme row
	var theme_row = 0
	if level:
		theme_row = level.tileset / 8
		if theme_row >= 14:
			theme_row = theme_row % 14
	elif current_biome:
		theme_row = THEME_ROWS.get(current_biome.theme, 0)

	# Paint all rooms
	t1 = Time.get_ticks_msec()
	for grid_pos in run_state.floor_map:
		var room_data = run_state.floor_map[grid_pos] as RoomData
		_paint_room(grid_pos, room_data, theme_row)
		_create_room_trigger(grid_pos, room_data)

		room_states[grid_pos] = {
			"visited": grid_pos == map["start"],
			"alive": 0,
			"cleared": room_data.type == RoomData.RoomType.SHOP,
			"enemies": [],
			"liquid_mask": [],
			"web_positions": [],
		}
	print("TIMING: paint rooms took %d ms" % (Time.get_ticks_msec() - t1))

	# Paint corridors
	t1 = Time.get_ticks_msec()
	for grid_pos in run_state.floor_map:
		var room_data = run_state.floor_map[grid_pos] as RoomData
		for dir_name in room_data.connections:
			var neighbor_pos = room_data.connections[dir_name]
			if dir_name == "east" or dir_name == "south":
				_paint_corridor(grid_pos, neighbor_pos, dir_name, theme_row)
	print("TIMING: paint corridors took %d ms" % (Time.get_ticks_msec() - t1))

	# Create transitions between rooms
	t1 = Time.get_ticks_msec()
	_create_all_transitions(theme_row)
	print("TIMING: transitions took %d ms" % (Time.get_ticks_msec() - t1))

	# Generate wall collisions (row-merged for performance)
	t1 = Time.get_ticks_msec()
	_generate_wall_collisions()
	print("TIMING: wall collisions took %d ms" % (Time.get_ticks_msec() - t1))

	# Place player at start room center
	var start_world = _grid_to_world_center(map["start"])
	player.global_position = start_world

	# Place equipment bag near player
	_spawn_dungeon_bag(start_world + Vector2(16, 16))

	# Pre-spawn enemies in rooms near the start (within 2 grid steps)
	# Other rooms spawn when player gets within 2 rooms
	t1 = Time.get_ticks_msec()
	var start = map["start"]
	for grid_pos in run_state.floor_map:
		var room_data = run_state.floor_map[grid_pos] as RoomData
		var dist_to_start = abs(grid_pos.x - start.x) + abs(grid_pos.y - start.y)
		match room_data.type:
			RoomData.RoomType.COMBAT, RoomData.RoomType.ELITE, RoomData.RoomType.BOSS:
				if dist_to_start <= 2:
					room_states[grid_pos]["visited"] = true
					_spawn_room_enemies(grid_pos, room_data)
	print("TIMING: spawn nearby enemies took %d ms" % (Time.get_ticks_msec() - t1))
	print("TIMING: TOTAL _generate_floor took %d ms" % (Time.get_ticks_msec() - t0))

	room_changed.emit(0, run_state.floor_map[map["start"]])

var _dungeon_bag: Node2D

func _spawn_dungeon_bag(pos: Vector2) -> void:
	if _dungeon_bag:
		_dungeon_bag.queue_free()
	var bag_scene = preload("res://scenes/objects/equipment_bag.tscn")
	_dungeon_bag = bag_scene.instantiate()
	_dungeon_bag.global_position = pos
	add_child(_dungeon_bag)

func _clear_floor() -> void:
	floor_layer.clear()
	wall_layer.clear()
	deco_layer.clear()
	liquid_layer.clear()
	room_states.clear()
	transitions.clear()

	if wall_body:
		wall_body.queue_free()
		wall_body = null

	for child in transition_container.get_children():
		child.queue_free()
	for child in room_triggers.get_children():
		child.queue_free()
	for child in enemy_container.get_children():
		child.queue_free()
	for child in hazard_container.get_children():
		child.queue_free()

func _generate_wall_collisions() -> void:
	if wall_body:
		wall_body.queue_free()
	wall_body = StaticBody2D.new()
	wall_body.collision_layer = 16
	wall_body.collision_mask = 0
	add_child(wall_body)

	# Build set of ALL walkable tiles (floor + corridor floor)
	var floor_set: Dictionary = {}
	for cell in floor_layer.get_used_cells():
		floor_set[cell] = true

	# Build collision set: wall tiles + void tiles adjacent to floor
	var collision_set: Dictionary = {}

	# Add all wall tiles
	for cell in wall_layer.get_used_cells():
		collision_set[cell] = true

	# Add void barrier: for every floor tile, check all 8 neighbors —
	# if a neighbor has no floor AND no wall tile, it's void that needs a barrier
	for cell in floor_set:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var neighbor = cell + Vector2i(dx, dy)
				if not floor_set.has(neighbor) and not collision_set.has(neighbor):
					collision_set[neighbor] = true

	# Row-merged collision shapes for performance
	var rows: Dictionary = {}
	for cell in collision_set:
		if not rows.has(cell.y):
			rows[cell.y] = []
		rows[cell.y].append(cell.x)

	for y in rows:
		var xs: Array = rows[y]
		xs.sort()
		var run_start = xs[0]
		var run_end = xs[0]
		for i in range(1, xs.size()):
			if xs[i] == run_end + 1:
				run_end = xs[i]
			else:
				_add_wall_shape(run_start, run_end, y)
				run_start = xs[i]
				run_end = xs[i]
		_add_wall_shape(run_start, run_end, y)

func _add_wall_shape(x_start: int, x_end: int, y: int) -> void:
	var run_len = x_end - x_start + 1
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(TILE_SIZE * run_len, TILE_SIZE)
	shape.shape = rect
	shape.position = Vector2(
		x_start * TILE_SIZE + (TILE_SIZE * run_len) / 2.0,
		y * TILE_SIZE + TILE_SIZE / 2.0
	)
	wall_body.add_child(shape)

func _grid_to_tile_origin(grid_pos: Vector2i) -> Vector2i:
	return Vector2i(
		grid_pos.x * GRID_CELL_W,
		grid_pos.y * GRID_CELL_H
	)

func _grid_to_world_center(grid_pos: Vector2i) -> Vector2:
	var origin = _grid_to_tile_origin(grid_pos)
	var room_data = run_state.floor_map.get(grid_pos) as RoomData
	var rw = 17
	var rh = 15
	if room_data:
		rw = room_data.shape_width
		rh = room_data.shape_height
	return Vector2(
		(origin.x + rw / 2) * TILE_SIZE,
		(origin.y + rh / 2) * TILE_SIZE
	)

func _paint_room(grid_pos: Vector2i, room_data: RoomData, theme_row: int) -> void:
	var origin = _grid_to_tile_origin(grid_pos)
	var mask = room_data.floor_mask
	var w = room_data.shape_width
	var h = room_data.shape_height

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

	# Paint floor and walls using floor mask
	for y in range(h):
		for x in range(w):
			var tile_pos = origin + Vector2i(x, y)
			if mask[y][x]:
				# Floor tile with variation
				if room_data.is_dirt_room:
					# Dirt rooms use dirt as primary floor
					if randf() < 0.15:
						floor_layer.set_cell(tile_pos, 0, floor_tile_2)
					else:
						floor_layer.set_cell(tile_pos, 0, dirt_tile)
				else:
					if randf() < 0.15:
						floor_layer.set_cell(tile_pos, 0, floor_tile_2)
					else:
						floor_layer.set_cell(tile_pos, 0, floor_tile)
			elif _is_wall_adjacent(mask, x, y, w, h):
				# Wall tile — pick variant based on position
				var wall = _pick_wall_tile(mask, x, y, w, h, wall_roof, wall_tile, wall_candle, wall_candle_2, wall_cracked)
				wall_layer.set_cell(tile_pos, 0, wall)

	# Stairs down
	if room_data.has_stairs_down:
		var cx = w / 2
		var cy = h / 2 - 2
		# Find nearest floor tile to preferred stair position
		if cx > 0 and cx < w and cy > 0 and cy < h and mask[cy][cx]:
			deco_layer.set_cell(origin + Vector2i(cx, cy), 0, stairs_down)
		else:
			# Fallback: place at center
			cy = h / 2
			if mask[cy][cx]:
				deco_layer.set_cell(origin + Vector2i(cx, cy), 0, stairs_down)

	# Biome-driven liquid flows
	if current_biome and current_biome.liquid_type != "" and current_biome.hazard_intensity > 0:
		var liquid_mask: Array
		# Use directional flow for combat rooms, pool fill for shrines/others
		if room_data.type == RoomData.RoomType.COMBAT and room_data.connections.size() > 0:
			var dir_names = room_data.connections.keys()
			var flow_dir_name = dir_names[randi() % dir_names.size()]
			var flow_dir = Vector2.ZERO
			match flow_dir_name:
				"north": flow_dir = Vector2(0, -1)
				"south": flow_dir = Vector2(0, 1)
				"east": flow_dir = Vector2(1, 0)
				"west": flow_dir = Vector2(-1, 0)
			liquid_mask = LiquidGenerator.generate_directional_flow(mask, current_biome.hazard_intensity, grid_pos.x * 1000 + grid_pos.y, flow_dir)
		else:
			liquid_mask = LiquidGenerator.generate_liquid_fill(mask, current_biome.hazard_intensity, grid_pos.x * 1000 + grid_pos.y)
		var web_positions = WebBridgeGenerator.generate_bridges(mask, liquid_mask, current_biome.web_bridge_density, room_data.connections, w, h)

		_paint_liquid_tiles(origin, liquid_mask, current_biome.liquid_type, w, h)
		_paint_web_bridges(origin, web_positions)
		_create_liquid_hazards(origin, liquid_mask, web_positions, w, h)

		# Store for enemy spawn avoidance
		room_states[grid_pos] = room_states.get(grid_pos, {})
		room_states[grid_pos]["liquid_mask"] = liquid_mask
		room_states[grid_pos]["web_positions"] = web_positions

	# Spike traps (based on biome trap_density)
	var trap_density = 0.02
	if current_biome:
		trap_density = current_biome.trap_density
	if trap_density > 0:
		_paint_spike_traps(origin, mask, w, h, trap_tile, trap_density, room_data)

	# Room decorations from source 1 (lofi_dungeon_features.png)
	_paint_room_decorations(origin, mask, w, h, room_data)

func _is_wall_adjacent(mask: Array, x: int, y: int, w: int, h: int) -> bool:
	# A non-floor tile that has at least one floor neighbor (including diagonals) becomes a wall
	if x < 0 or x >= w or y < 0 or y >= h:
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < w and ny >= 0 and ny < h and mask[ny][nx]:
				return true
	return false

func _pick_wall_tile(mask: Array, x: int, y: int, w: int, h: int,
		wall_roof: Vector2i, wall_tile: Vector2i, wall_candle: Vector2i,
		wall_candle_2: Vector2i, wall_cracked: Vector2i) -> Vector2i:
	# Top walls (floor below) get roof style
	var has_floor_below = (y + 1 < h and mask[y + 1][x])
	var has_floor_right = (x + 1 < w and mask[y][x + 1])
	var has_floor_left = (x - 1 >= 0 and mask[y][x - 1])

	if has_floor_below:
		if randf() < 0.15:
			return wall_cracked
		return wall_roof
	elif has_floor_right:
		if randf() < 0.2:
			return wall_candle
		return wall_tile
	elif has_floor_left:
		if randf() < 0.2:
			return wall_candle_2
		return wall_tile
	else:
		return wall_tile

func _paint_liquid_tiles(origin: Vector2i, liquid_mask: Array, liquid_type: String, w: int, h: int) -> void:
	var tiles = LIQUID_TILES.get(liquid_type, [])
	if tiles.size() == 0:
		return
	for y in range(h):
		for x in range(w):
			if liquid_mask[y][x]:
				var tile = tiles[randi() % tiles.size()]
				liquid_layer.set_cell(origin + Vector2i(x, y), 0, tile)

func _paint_web_bridges(origin: Vector2i, web_positions: Array) -> void:
	for pos in web_positions:
		deco_layer.set_cell(origin + pos, 0, SPIDER_WEB_FULL)

func _create_liquid_hazards(origin: Vector2i, liquid_mask: Array, web_positions: Array, w: int, h: int) -> void:
	# Create one HazardArea per contiguous liquid blob (excluding web positions)
	var web_set: Dictionary = {}
	for pos in web_positions:
		web_set[pos] = true

	var visited: Array = []
	for y in range(h):
		var row: Array = []
		for x in range(w):
			row.append(false)
		visited.append(row)

	for y in range(h):
		for x in range(w):
			if visited[y][x] or not liquid_mask[y][x] or web_set.has(Vector2i(x, y)):
				continue
			# Flood fill to find contiguous liquid blob
			var blob: Array[Vector2i] = []
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			while stack.size() > 0:
				var pos = stack.pop_back()
				if pos.x < 0 or pos.x >= w or pos.y < 0 or pos.y >= h:
					continue
				if visited[pos.y][pos.x] or not liquid_mask[pos.y][pos.x] or web_set.has(pos):
					continue
				visited[pos.y][pos.x] = true
				blob.append(pos)
				stack.append(Vector2i(pos.x + 1, pos.y))
				stack.append(Vector2i(pos.x - 1, pos.y))
				stack.append(Vector2i(pos.x, pos.y + 1))
				stack.append(Vector2i(pos.x, pos.y - 1))

			if blob.size() == 0:
				continue

			# Create one HazardArea for this blob
			var hazard_scene = preload("res://scenes/dungeon/hazard_area.tscn")
			var hazard = hazard_scene.instantiate() as HazardArea
			if current_biome:
				hazard.damage = current_biome.hazard_damage
				hazard.interval = current_biome.hazard_interval
				_apply_hazard_status(hazard, current_biome.liquid_type)

			# Position at blob center, add collision shapes for each tile
			var center = Vector2.ZERO
			for pos in blob:
				center += Vector2(pos.x, pos.y)
			center /= blob.size()
			var world_center = Vector2((origin.x + center.x) * TILE_SIZE + 4, (origin.y + center.y) * TILE_SIZE + 4)
			hazard.position = world_center

			# Remove default collision shape before adding to tree
			var children_to_remove: Array = []
			for child in hazard.get_children():
				if child is CollisionShape2D:
					children_to_remove.append(child)
			for child in children_to_remove:
				hazard.remove_child(child)
				child.free()

			for pos in blob:
				var shape = CollisionShape2D.new()
				var rect = RectangleShape2D.new()
				rect.size = Vector2(TILE_SIZE, TILE_SIZE)
				shape.shape = rect
				shape.position = Vector2((origin.x + pos.x) * TILE_SIZE + 4, (origin.y + pos.y) * TILE_SIZE + 4) - world_center
				hazard.add_child(shape)

			hazard_container.add_child(hazard)

func _apply_hazard_status(hazard: HazardArea, liquid_type: String) -> void:
	match liquid_type:
		"lava":
			hazard.status_effect_type = StatusEffect.Type.BURNING
			hazard.status_strength = 1.0
			hazard.status_duration = 3.0
		"water":
			hazard.damage = 0
			hazard.status_effect_type = StatusEffect.Type.SLOWED
			hazard.status_strength = 0.5
			hazard.status_duration = 1.5
		"poison":
			hazard.status_effect_type = StatusEffect.Type.POISONED
			hazard.status_strength = 1.0
			hazard.status_duration = 4.0

func _paint_spike_traps(origin: Vector2i, mask: Array, w: int, h: int, trap_tile: Vector2i, density: float, room_data: RoomData) -> void:
	var floor_count = 0
	for y in range(h):
		for x in range(w):
			if mask[y][x]:
				floor_count += 1
	var trap_count = int(floor_count * density)
	var placed = 0
	var attempts = 0
	while placed < trap_count and attempts < trap_count * 5:
		attempts += 1
		var pos = _random_interior_floor_tile(mask, w, h, 2)
		if pos == Vector2i(-1, -1):
			continue
		# Don't place traps near exits
		var too_close = false
		for dir_name in room_data.connections:
			var exit_pt = RoomShapeGenerator.get_exit_point(mask, w, h, dir_name)
			if abs(pos.x - exit_pt.x) <= 2 and abs(pos.y - exit_pt.y) <= 2:
				too_close = true
				break
		if too_close:
			continue
		deco_layer.set_cell(origin + pos, 0, trap_tile)
		# Create blink-then-explode trap
		var trap = TrapTile.new()
		trap.tile_pos = pos
		trap.origin = origin
		trap.deco_layer = deco_layer
		trap.trap_atlas = trap_tile
		trap.floor_number = run_state.current_floor if run_state else 1
		trap.position = Vector2((origin.x + pos.x) * TILE_SIZE + 4, (origin.y + pos.y) * TILE_SIZE + 4)
		hazard_container.add_child(trap)
		placed += 1

func _random_interior_floor_tile(mask: Array, w: int, h: int, border: int) -> Vector2i:
	for _attempt in range(20):
		var x = randi_range(border, w - border - 1)
		var y = randi_range(border, h - border - 1)
		if x >= 0 and x < w and y >= 0 and y < h and mask[y][x]:
			return Vector2i(x, y)
	return Vector2i(-1, -1)

# Source 1 decoration tiles (lofi_dungeon_features.png, 12x9 grid)
const DECO_BARRELS = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
const DECO_PILLARS = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
const DECO_BONES = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]
const DECO_RUBBLE = [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4)]
const DECO_MOSS = [Vector2i(0, 5), Vector2i(1, 5)]

func _paint_room_decorations(origin: Vector2i, mask: Array, w: int, h: int, room_data: RoomData) -> void:
	# Use biome-specific decorations if available, otherwise default set
	var tiles: Array[Vector2i] = []
	if current_biome and current_biome.decoration_tiles.size() > 0:
		tiles.assign(current_biome.decoration_tiles)
	else:
		# Default: mix of barrels, bones, rubble
		for t in DECO_BARRELS:
			tiles.append(t)
		for t in DECO_BONES:
			tiles.append(t)
		for t in DECO_RUBBLE:
			tiles.append(t)

	if tiles.size() == 0:
		return

	# Place 3-8 decorations per room (more in larger rooms)
	var floor_count = 0
	for y in range(h):
		for x in range(w):
			if mask[y][x]:
				floor_count += 1
	var deco_count = clampi(floor_count / 30, 3, 8)

	# Track placed positions to avoid overlaps with exits, stairs, traps
	var placed_positions: Dictionary = {}
	var exit_positions: Dictionary = {}
	for dir_name in room_data.connections:
		var exit_pt = RoomShapeGenerator.get_exit_point(mask, w, h, dir_name)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				exit_positions[exit_pt + Vector2i(dx, dy)] = true

	for i in range(deco_count):
		var pos = _random_interior_floor_tile(mask, w, h, 2)
		if pos == Vector2i(-1, -1):
			continue
		if exit_positions.has(pos) or placed_positions.has(pos):
			continue
		# Don't place on stairs
		if room_data.has_stairs_down:
			var cx = w / 2
			var cy = h / 2 - 2
			if pos == Vector2i(cx, cy) or pos == Vector2i(cx, h / 2):
				continue
		# Don't overlap existing deco tiles
		if deco_layer.get_cell_source_id(origin + pos) != -1:
			continue
		var tile = tiles[randi() % tiles.size()]
		deco_layer.set_cell(origin + pos, 1, tile)
		placed_positions[pos] = true

func _paint_corridor(from_grid: Vector2i, to_grid: Vector2i, direction: String, theme_row: int) -> void:
	var floor_tile = Vector2i(5, theme_row)
	var wall_tile = Vector2i(4, theme_row)

	var from_room = run_state.floor_map[from_grid] as RoomData
	var to_room = run_state.floor_map[to_grid] as RoomData
	var from_origin = _grid_to_tile_origin(from_grid)
	var to_origin = _grid_to_tile_origin(to_grid)

	if direction == "east":
		var from_exit = RoomShapeGenerator.get_exit_point(from_room.floor_mask, from_room.shape_width, from_room.shape_height, "east")
		var to_exit = RoomShapeGenerator.get_exit_point(to_room.floor_mask, to_room.shape_width, to_room.shape_height, "west")

		var start_x = from_origin.x + from_room.shape_width
		var end_x = to_origin.x
		var from_mid_y = from_origin.y + from_exit.y
		var to_mid_y = to_origin.y + to_exit.y

		# Check for corridor liquid (both rooms have liquid)
		var corridor_liquid = _get_corridor_liquid(from_grid, to_grid)

		# Paint corridor — handle y offset between rooms
		for x in range(start_x, end_x):
			var t = 0.0
			if end_x > start_x:
				t = float(x - start_x) / float(end_x - start_x)
			var mid_y = int(lerp(float(from_mid_y), float(to_mid_y), t))
			for dy in range(-1, 2):
				floor_layer.set_cell(Vector2i(x, mid_y + dy), 0, floor_tile)
			wall_layer.set_cell(Vector2i(x, mid_y - 2), 0, wall_tile)
			wall_layer.set_cell(Vector2i(x, mid_y + 2), 0, wall_tile)
			if corridor_liquid.size() > 0:
				liquid_layer.set_cell(Vector2i(x, mid_y - 1), 0, corridor_liquid[randi() % corridor_liquid.size()])
				liquid_layer.set_cell(Vector2i(x, mid_y + 1), 0, corridor_liquid[randi() % corridor_liquid.size()])
				deco_layer.set_cell(Vector2i(x, mid_y), 0, SPIDER_WEB_FULL)

		# Open walls at room exits
		_open_exit_wall(from_origin, from_exit, from_room.floor_mask, from_room.shape_width, from_room.shape_height, floor_tile)
		_open_exit_wall(to_origin, to_exit, to_room.floor_mask, to_room.shape_width, to_room.shape_height, floor_tile)

	elif direction == "south":
		var from_exit = RoomShapeGenerator.get_exit_point(from_room.floor_mask, from_room.shape_width, from_room.shape_height, "south")
		var to_exit = RoomShapeGenerator.get_exit_point(to_room.floor_mask, to_room.shape_width, to_room.shape_height, "north")

		var start_y = from_origin.y + from_room.shape_height
		var end_y = to_origin.y
		var from_mid_x = from_origin.x + from_exit.x
		var to_mid_x = to_origin.x + to_exit.x

		var corridor_liquid = _get_corridor_liquid(from_grid, to_grid)

		for y in range(start_y, end_y):
			var t = 0.0
			if end_y > start_y:
				t = float(y - start_y) / float(end_y - start_y)
			var mid_x = int(lerp(float(from_mid_x), float(to_mid_x), t))
			for dx in range(-1, 2):
				floor_layer.set_cell(Vector2i(mid_x + dx, y), 0, floor_tile)
			wall_layer.set_cell(Vector2i(mid_x - 2, y), 0, wall_tile)
			wall_layer.set_cell(Vector2i(mid_x + 2, y), 0, wall_tile)
			if corridor_liquid.size() > 0:
				liquid_layer.set_cell(Vector2i(mid_x - 1, y), 0, corridor_liquid[randi() % corridor_liquid.size()])
				liquid_layer.set_cell(Vector2i(mid_x + 1, y), 0, corridor_liquid[randi() % corridor_liquid.size()])
				deco_layer.set_cell(Vector2i(mid_x, y), 0, SPIDER_WEB_FULL)

		_open_exit_wall(from_origin, from_exit, from_room.floor_mask, from_room.shape_width, from_room.shape_height, floor_tile)
		_open_exit_wall(to_origin, to_exit, to_room.floor_mask, to_room.shape_width, to_room.shape_height, floor_tile)

func _open_exit_wall(origin: Vector2i, exit_point: Vector2i, mask: Array, w: int, h: int, floor_tile: Vector2i) -> void:
	# Clear wall tiles and paint floor at the exit opening (3 tiles wide, 3 tiles deep)
	# This ensures circle/irregular rooms don't have multi-layer walls blocking corridors
	var is_vertical = exit_point.x == 0 or exit_point.x == w - 1
	var depth_dir: int  # direction to carve inward
	if is_vertical:
		depth_dir = 1 if exit_point.x == 0 else -1
	else:
		depth_dir = 1 if exit_point.y == 0 else -1

	for depth in range(3):  # carve 3 tiles deep from the edge
		for offset in range(-1, 2):  # 3 tiles wide
			var tx: int
			var ty: int
			if is_vertical:
				tx = exit_point.x + depth * depth_dir
				ty = exit_point.y + offset
			else:
				tx = exit_point.x + offset
				ty = exit_point.y + depth * depth_dir
			if tx >= 0 and tx < w and ty >= 0 and ty < h:
				var tile_pos = origin + Vector2i(tx, ty)
				wall_layer.erase_cell(tile_pos)
				floor_layer.set_cell(tile_pos, 0, floor_tile)

func _get_corridor_liquid(from_grid: Vector2i, to_grid: Vector2i) -> Array:
	# Returns liquid tile array if both rooms have liquid, else empty
	if not current_biome or current_biome.liquid_type == "":
		return []
	var from_state = room_states.get(from_grid, {})
	var to_state = room_states.get(to_grid, {})
	if from_state.get("liquid_mask") != null and to_state.get("liquid_mask") != null:
		return LIQUID_TILES.get(current_biome.liquid_type, [])
	return []

# --- Transition System ---

func _create_all_transitions(theme_row: int) -> void:
	for grid_pos in run_state.floor_map:
		var room_data = run_state.floor_map[grid_pos] as RoomData
		for dir_name in room_data.connections:
			var neighbor_pos = room_data.connections[dir_name]
			# Only create transition once per pair
			if dir_name == "east" or dir_name == "south":
				var t_type = room_data.transition_types.get(dir_name, RoomData.TransitionType.OPEN)
				# Check neighbor's side too — use the harder transition
				var opp_dir = "west" if dir_name == "east" else "north"
				var neighbor_data = run_state.floor_map[neighbor_pos] as RoomData
				var neighbor_type = neighbor_data.transition_types.get(opp_dir, RoomData.TransitionType.OPEN)
				if neighbor_type > t_type:
					t_type = neighbor_type

				_create_single_transition(grid_pos, neighbor_pos, dir_name, t_type, theme_row)

func _create_single_transition(from_grid: Vector2i, to_grid: Vector2i, direction: String, t_type: int, theme_row: int) -> void:
	if t_type == RoomData.TransitionType.OPEN:
		return  # No barrier needed

	var from_room = run_state.floor_map[from_grid] as RoomData
	var from_origin = _grid_to_tile_origin(from_grid)
	var exit_dir = direction
	var exit_point = RoomShapeGenerator.get_exit_point(from_room.floor_mask, from_room.shape_width, from_room.shape_height, exit_dir)

	# Calculate transition tile positions (in the corridor, just outside the room)
	var transition_tiles: Array[Vector2i] = []
	if direction == "east":
		var base_x = from_origin.x + from_room.shape_width
		var base_y = from_origin.y + exit_point.y
		for dy in range(-1, 2):
			transition_tiles.append(Vector2i(base_x, base_y + dy))
	elif direction == "south":
		var base_x = from_origin.x + exit_point.x
		var base_y = from_origin.y + from_room.shape_height
		for dx in range(-1, 2):
			transition_tiles.append(Vector2i(base_x + dx, base_y))

	var wall_tile = Vector2i(4, theme_row)

	match t_type:
		RoomData.TransitionType.BREAKABLE_WALL:
			_create_breakable_wall_transition(transition_tiles, wall_tile, from_grid, to_grid, direction)
		RoomData.TransitionType.KEY_LOCKED:
			_create_key_locked_transition(transition_tiles, wall_tile, from_grid, to_grid, direction)
		RoomData.TransitionType.INTERACT_OPEN:
			_create_interact_transition(transition_tiles, wall_tile, from_grid, to_grid, direction)

func _create_breakable_wall_transition(tiles: Array[Vector2i], wall_tile: Vector2i, from_grid: Vector2i, to_grid: Vector2i, direction: String) -> void:
	# Paint cracked wall tiles
	var cracked_tile = Vector2i(3, wall_tile.y)  # cracked variant
	for tile_pos in tiles:
		wall_layer.set_cell(tile_pos, 0, cracked_tile)
		floor_layer.erase_cell(tile_pos)

	# Create breakable wall body
	var bwall = BreakableWall.new()
	bwall.hp = 5
	bwall.tile_positions = tiles
	bwall.wall_layer_ref = wall_layer
	bwall.floor_tile = Vector2i(5, wall_tile.y)
	bwall.wall_destroyed.connect(_on_transition_opened.bind(from_grid, to_grid, direction))
	transition_container.add_child(bwall)

	# Add collision shapes for each tile
	for tile_pos in tiles:
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(TILE_SIZE, TILE_SIZE)
		shape.shape = rect
		shape.position = Vector2(tile_pos.x * TILE_SIZE + 4, tile_pos.y * TILE_SIZE + 4)
		bwall.add_child(shape)

func _create_key_locked_transition(tiles: Array[Vector2i], wall_tile: Vector2i, from_grid: Vector2i, to_grid: Vector2i, direction: String) -> void:
	# Paint gold/locked wall tiles
	var lock_tile = Vector2i(1, wall_tile.y)  # candle variant as "locked" visual
	for tile_pos in tiles:
		wall_layer.set_cell(tile_pos, 0, lock_tile)
		floor_layer.erase_cell(tile_pos)

	# Track that this room needs a key drop
	var room_data = run_state.floor_map[from_grid] as RoomData
	room_data.keys_needed += 1

	# Create blocking body
	var blocker = StaticBody2D.new()
	blocker.collision_layer = 16
	blocker.collision_mask = 0
	blocker.set_meta("transition_tiles", tiles)
	blocker.set_meta("from_grid", from_grid)
	blocker.set_meta("to_grid", to_grid)
	blocker.set_meta("direction", direction)
	blocker.set_meta("floor_tile", Vector2i(5, wall_tile.y))

	for tile_pos in tiles:
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(TILE_SIZE, TILE_SIZE)
		shape.shape = rect
		shape.position = Vector2(tile_pos.x * TILE_SIZE + 4, tile_pos.y * TILE_SIZE + 4)
		blocker.add_child(shape)

	blocker.add_to_group("key_locked_transitions")
	transition_container.add_child(blocker)

func _create_interact_transition(tiles: Array[Vector2i], wall_tile: Vector2i, from_grid: Vector2i, to_grid: Vector2i, direction: String) -> void:
	# Paint distinct wall tiles
	for tile_pos in tiles:
		wall_layer.set_cell(tile_pos, 0, wall_tile)
		floor_layer.erase_cell(tile_pos)

	# Create blocking body
	var blocker = StaticBody2D.new()
	blocker.collision_layer = 16
	blocker.collision_mask = 0
	blocker.set_meta("transition_tiles", tiles)
	blocker.set_meta("floor_tile", Vector2i(5, wall_tile.y))

	for tile_pos in tiles:
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(TILE_SIZE, TILE_SIZE)
		shape.shape = rect
		shape.position = Vector2(tile_pos.x * TILE_SIZE + 4, tile_pos.y * TILE_SIZE + 4)
		blocker.add_child(shape)

	# Create interact area (slightly larger for detection)
	var interact_area = Area2D.new()
	interact_area.collision_layer = 0
	interact_area.collision_mask = 1
	var detect_shape = CollisionShape2D.new()
	var detect_rect = RectangleShape2D.new()
	detect_rect.size = Vector2(TILE_SIZE * 4, TILE_SIZE * 4)
	detect_shape.shape = detect_rect
	# Center on the transition tiles
	var center = Vector2.ZERO
	for tile_pos in tiles:
		center += Vector2(tile_pos.x * TILE_SIZE + 4, tile_pos.y * TILE_SIZE + 4)
	center /= tiles.size()
	detect_shape.position = center
	interact_area.add_child(detect_shape)

	# Prompt label
	var prompt = Label.new()
	prompt.text = "[E] Open"
	prompt.position = center + Vector2(-20, -16)
	prompt.add_theme_font_size_override("font_size", 9)
	prompt.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	prompt.visible = false
	prompt.z_index = 5

	interact_area.set_meta("prompt", prompt)
	interact_area.set_meta("blocker", blocker)
	interact_area.body_entered.connect(_on_interact_area_entered.bind(interact_area))
	interact_area.body_exited.connect(_on_interact_area_exited.bind(interact_area))

	blocker.add_to_group("interact_transitions")
	transition_container.add_child(blocker)
	transition_container.add_child(interact_area)
	transition_container.add_child(prompt)

var _nearby_interact_areas: Array = []

func _on_interact_area_entered(body: Node2D, area: Area2D) -> void:
	if body.is_in_group("player"):
		var prompt = area.get_meta("prompt") as Label
		if prompt:
			prompt.visible = true
		if not area in _nearby_interact_areas:
			_nearby_interact_areas.append(area)

func _on_interact_area_exited(body: Node2D, area: Area2D) -> void:
	if body.is_in_group("player"):
		var prompt = area.get_meta("prompt") as Label
		if prompt:
			prompt.visible = false
		_nearby_interact_areas.erase(area)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		for area in _nearby_interact_areas:
			if is_instance_valid(area):
				_open_interact_transition(area)
				get_viewport().set_input_as_handled()
				break

func _open_interact_transition(area: Area2D) -> void:
	var blocker = area.get_meta("blocker") as StaticBody2D
	var prompt = area.get_meta("prompt") as Label
	if blocker:
		var tiles = blocker.get_meta("transition_tiles") as Array
		var floor_tile = blocker.get_meta("floor_tile") as Vector2i
		for tile_pos in tiles:
			wall_layer.erase_cell(tile_pos)
			floor_layer.set_cell(tile_pos, 0, floor_tile)
		blocker.queue_free()
	if prompt:
		prompt.queue_free()
	_nearby_interact_areas.erase(area)
	area.queue_free()

func _on_transition_opened(from_grid: Vector2i, to_grid: Vector2i, direction: String) -> void:
	# Transition wall was destroyed, regenerate wall collisions to remove it
	_generate_wall_collisions()

# --- Room Triggers ---

func _create_room_trigger(grid_pos: Vector2i, room_data: RoomData) -> void:
	var trigger = Area2D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = 1
	trigger.set_meta("grid_pos", grid_pos)

	var center = _grid_to_world_center(grid_pos)
	trigger.position = center

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2((room_data.shape_width - 4) * TILE_SIZE, (room_data.shape_height - 4) * TILE_SIZE)
	shape.shape = rect
	trigger.add_child(shape)

	trigger.body_entered.connect(_on_room_trigger_entered.bind(grid_pos))
	room_triggers.add_child(trigger)

	if room_data.has_stairs_down:
		var stairs_trigger = Area2D.new()
		stairs_trigger.collision_layer = 0
		stairs_trigger.collision_mask = 1
		var origin = _grid_to_tile_origin(grid_pos)
		var cx = room_data.shape_width / 2
		var cy = room_data.shape_height / 2 - 2
		if not (cy > 0 and cy < room_data.shape_height and room_data.floor_mask[cy][cx]):
			cy = room_data.shape_height / 2
		var stair_tile = origin + Vector2i(cx, cy)
		stairs_trigger.position = Vector2(stair_tile.x * TILE_SIZE + 4, stair_tile.y * TILE_SIZE + 4)
		var stair_shape = CollisionShape2D.new()
		var stair_rect = RectangleShape2D.new()
		stair_rect.size = Vector2(TILE_SIZE, TILE_SIZE)
		stair_shape.shape = stair_rect
		stairs_trigger.add_child(stair_shape)
		stairs_trigger.body_entered.connect(_on_stairs_entered.bind(grid_pos))
		room_triggers.add_child(stairs_trigger)

func _on_room_trigger_entered(body: Node2D, grid_pos: Vector2i) -> void:
	if not body.is_in_group("player"):
		return

	var state = room_states.get(grid_pos)
	if not state:
		return

	run_state.current_grid_pos = grid_pos
	var room_data = run_state.floor_map[grid_pos] as RoomData
	room_changed.emit(0, room_data)

	if state["visited"]:
		# Still pre-spawn adjacent rooms even if this room is already visited
		_prespawn_adjacent_rooms(grid_pos)
		return

	_visit_room(grid_pos)
	# Pre-spawn enemies in adjacent rooms so they exist before player arrives
	_prespawn_adjacent_rooms(grid_pos)

func _prespawn_adjacent_rooms(grid_pos: Vector2i) -> void:
	var room_data = run_state.floor_map.get(grid_pos) as RoomData
	if not room_data:
		return
	for dir_name in room_data.connections:
		var neighbor_pos = room_data.connections[dir_name]
		var neighbor_state = room_states.get(neighbor_pos)
		if not neighbor_state or neighbor_state["visited"]:
			continue
		var neighbor_data = run_state.floor_map.get(neighbor_pos) as RoomData
		if not neighbor_data:
			continue
		match neighbor_data.type:
			RoomData.RoomType.COMBAT, RoomData.RoomType.ELITE, RoomData.RoomType.BOSS:
				neighbor_state["visited"] = true
				_spawn_room_enemies(neighbor_pos, neighbor_data)

func _visit_room(grid_pos: Vector2i) -> void:
	var state = room_states[grid_pos]
	state["visited"] = true

	var room_data = run_state.floor_map[grid_pos] as RoomData

	match room_data.type:
		RoomData.RoomType.COMBAT, RoomData.RoomType.ELITE, RoomData.RoomType.BOSS:
			_spawn_room_enemies(grid_pos, room_data)
		RoomData.RoomType.TREASURE, RoomData.RoomType.SHRINE:
			_spawn_chest_loot(grid_pos)
			reward_requested.emit(room_data)
		_:
			pass

# --- Enemy Spawning ---

func _spawn_room_enemies(grid_pos: Vector2i, room_data: RoomData) -> void:
	var enemy_scene = preload("res://scenes/enemy.tscn")

	var count = room_data.enemy_count
	if current_level:
		count = randi_range(current_level.min_monsters, maxi(current_level.max_monsters, 1))
		count = maxi(count, 1)

	# Get valid spawn positions
	var spawn_positions = _get_valid_spawn_positions(grid_pos, room_data, count)

	var fallback_def = EnemyDefinition.new()
	fallback_def.enemy_name = "Default"
	fallback_def.max_hp = 3
	fallback_def.attack_type = EnemyDefinition.AttackType.RANGED
	fallback_def.bullet_count = 3
	fallback_def.bullet_speed = 80.0

	var loy_pool = _get_loy_enemy_pool()
	var pool = current_biome.enemy_pool if current_biome and current_biome.enemy_pool.size() > 0 else []

	print("Spawning %d enemies in room %s (type=%d, loy_pool=%d, biome_pool=%d, positions=%d)" % [
		count, str(grid_pos), room_data.type, loy_pool.size(), pool.size(), spawn_positions.size()])

	if room_data.type == RoomData.RoomType.BOSS:
		count = 1

	for i in range(mini(count, spawn_positions.size())):
		var spawn_pos = spawn_positions[i]

		var def: EnemyDefinition
		if room_data.type == RoomData.RoomType.BOSS:
			# Try biome boss definition first, then LoY legend, then generate from pool
			if current_biome and current_biome.boss_definition:
				def = current_biome.boss_definition.duplicate()
			elif current_level and current_level.legend != "":
				def = _load_enemy_by_name(current_level.legend)
				if not def:
					def = fallback_def.duplicate()
			elif pool.size() > 0:
				def = pool[0].duplicate()  # use strongest enemy as boss base
			else:
				def = fallback_def.duplicate()
		elif loy_pool.size() > 0:
			def = _pick_weighted_enemy(loy_pool)
		elif pool.size() > 0:
			def = pool[randi() % pool.size()].duplicate()
		else:
			def = fallback_def.duplicate()

		def.max_hp = int(def.max_hp * room_data.enemy_hp_mult)

		if room_data.type == RoomData.RoomType.ELITE:
			# Mini-boss: LARGE, 2 phases, escalated attacks
			def.max_hp = int(def.max_hp * 3)
			def.move_speed *= 1.2
			def.size_class = EnemyDefinition.SizeClass.LARGE
			def.bullet_count += 2
			def.boss_phases = 2
			if def.attack_type == EnemyDefinition.AttackType.RANGED:
				def.phase_2_attack = EnemyDefinition.AttackType.BURST
			elif def.attack_type == EnemyDefinition.AttackType.BURST:
				def.phase_2_attack = EnemyDefinition.AttackType.SPIRAL
			else:
				def.phase_2_attack = EnemyDefinition.AttackType.BURST
			def.phase_2_bullet_count = def.bullet_count + 2
			def.sprite_color = def.sprite_color.lightened(0.3)
		elif room_data.type == RoomData.RoomType.BOSS:
			# Full boss: 3 phases, minion summoning, huge HP
			def.max_hp = int(def.max_hp * 8)
			def.move_speed *= 0.8
			def.attack_speed *= 0.6
			def.bullet_count += 4
			def.size_class = EnemyDefinition.SizeClass.BOSS
			def.boss_phases = 3
			def.summon_on_phase_change = true
			def.summon_phase_count = 3
			# Set phase attacks if not already configured
			if def.phase_2_attack == EnemyDefinition.AttackType.NONE:
				def.phase_2_attack = EnemyDefinition.AttackType.BURST
				def.phase_2_bullet_count = 10
			if def.phase_3_attack == EnemyDefinition.AttackType.NONE:
				def.phase_3_attack = EnemyDefinition.AttackType.SPIRAL
				def.phase_3_bullet_count = 12
			# Set summon definition to random biome enemy for minion spawning
			if not def.summon_definition and pool.size() > 0:
				def.summon_definition = pool[randi() % pool.size()]
			def.sprite_color = def.sprite_color.lightened(0.5)

		if room_data.type == RoomData.RoomType.COMBAT:
			def = _try_make_rare(def)

		var enemy = enemy_scene.instantiate()
		enemy.global_position = spawn_pos
		enemy.setup(def)
		enemy.set_meta("grid_pos", grid_pos)
		enemy.tree_exited.connect(_on_enemy_died.bind(grid_pos))
		enemy_container.add_child(enemy)

		room_states[grid_pos]["alive"] += 1

func _get_valid_spawn_positions(grid_pos: Vector2i, room_data: RoomData, count: int) -> Array[Vector2]:
	var origin = _grid_to_tile_origin(grid_pos)
	var mask = room_data.floor_mask
	var w = room_data.shape_width
	var h = room_data.shape_height
	var state = room_states.get(grid_pos, {})
	var liquid_mask = state.get("liquid_mask", [])
	var web_positions = state.get("web_positions", [])
	var web_set: Dictionary = {}
	for pos in web_positions:
		web_set[pos] = true

	var valid: Array[Vector2i] = []
	for y in range(h):
		for x in range(w):
			if not mask[y][x]:
				continue
			# Skip liquid tiles (unless web-covered)
			if liquid_mask.size() > 0 and y < liquid_mask.size() and x < liquid_mask[0].size():
				if liquid_mask[y][x] and not web_set.has(Vector2i(x, y)):
					continue
			# Stay 2 tiles from walls
			if not _has_floor_clearance(mask, x, y, w, h, 2):
				continue
			valid.append(Vector2i(x, y))

	valid.shuffle()
	var result: Array[Vector2] = []
	for i in range(mini(count, valid.size())):
		var v = valid[i]
		result.append(Vector2((origin.x + v.x) * TILE_SIZE + 4, (origin.y + v.y) * TILE_SIZE + 4))

	# Fallback: if not enough valid positions, use room center
	if result.size() < count:
		var center = _grid_to_world_center(grid_pos)
		while result.size() < count:
			var offset = Vector2(randf_range(-16, 16), randf_range(-16, 16))
			result.append(center + offset)

	return result

func _has_floor_clearance(mask: Array, x: int, y: int, w: int, h: int, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var nx = x + dx
			var ny = y + dy
			if nx < 0 or nx >= w or ny < 0 or ny >= h or not mask[ny][nx]:
				return false
	return true

func _get_loy_enemy_pool() -> Array:
	if not current_level or current_level.monster_pool.size() == 0:
		return []
	return current_level.monster_pool

func _pick_weighted_enemy(pool: Array) -> EnemyDefinition:
	var total_weight = 0
	for entry in pool:
		total_weight += int(entry.get("chance", 1))

	var roll = randi() % maxi(total_weight, 1)
	var cumulative = 0
	for entry in pool:
		cumulative += int(entry.get("chance", 1))
		if roll < cumulative:
			var def = _load_enemy_by_name(str(entry.get("type", "")))
			if def:
				return def

	if pool.size() > 0:
		var def = _load_enemy_by_name(str(pool[0].get("type", "")))
		if def:
			return def

	var fb = EnemyDefinition.new()
	fb.enemy_name = "Skeleton"
	fb.max_hp = 3
	return fb

const RARE_VARIANTS: Dictionary = {
	"Goblin": {"name": "Golden Goblin", "chance": 550},
	"Skeleton": {"name": "Golden Skeleton", "chance": 500},
	"Orc": {"name": "Golden Orc", "chance": 650},
	"Imp": {"name": "Golden Imp", "chance": 700},
	"Scorpion": {"name": "Golden Scorpion", "chance": 750},
	"Creeper": {"name": "Golden Creeper", "chance": 800},
	"Kobold": {"name": "Golden Kobold", "chance": 600},
	"Widow": {"name": "Golden Widow", "chance": 900},
	"Spider": {"name": "Golden Spider", "chance": 650},
	"Mummy": {"name": "Golden Mummy", "chance": 750},
	"Vampire": {"name": "Golden Vampire", "chance": 850},
	"Dragon": {"name": "Golden Dragon", "chance": 950},
}

var _enemy_cache: Dictionary = {}
var _enemy_path_index: Dictionary = {}  # name -> path lookup

func _build_enemy_index() -> void:
	if _enemy_path_index.size() > 0:
		return
	var search_dirs = [
		"res://resources/enemies/loy/undead/",
		"res://resources/enemies/loy/orc/",
		"res://resources/enemies/loy/crawler/",
		"res://resources/enemies/loy/animal/",
		"res://resources/enemies/loy/demon/",
		"res://resources/enemies/loy/human/",
		"res://resources/enemies/loy/magical/",
		"res://resources/enemies/",
	]
	for dir_path in search_dirs:
		var dir = DirAccess.open(dir_path)
		if not dir:
			continue
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.ends_with(".tres"):
				var base = fname.get_basename().to_lower()
				if not _enemy_path_index.has(base):
					_enemy_path_index[base] = dir_path + fname
			fname = dir.get_next()
	print("DungeonManager: Indexed %d enemy definitions" % _enemy_path_index.size())

func _load_enemy_by_name(monster_name: String) -> EnemyDefinition:
	if _enemy_cache.has(monster_name):
		var cached = _enemy_cache[monster_name]
		return cached.duplicate() if cached else null

	_build_enemy_index()
	var safe_name = monster_name.to_lower().replace(" ", "_")
	var path = _enemy_path_index.get(safe_name, "") as String
	if path != "":
		var def = load(path) as EnemyDefinition
		_enemy_cache[monster_name] = def
		return def.duplicate() if def else null

	_enemy_cache[monster_name] = null
	return null

func _try_make_rare(def: EnemyDefinition) -> EnemyDefinition:
	var variant = RARE_VARIANTS.get(def.enemy_name)
	if not variant:
		return def
	if randi() % int(variant["chance"]) == 0:
		var rare_def = def.duplicate()
		rare_def.enemy_name = str(variant["name"])
		rare_def.max_hp *= 5
		rare_def.move_speed *= 0.8
		rare_def.sprite_color = Color.GOLD
		rare_def.bullet_count += 2
		return rare_def
	return def

func _on_enemy_died(grid_pos: Vector2i) -> void:
	var state = room_states.get(grid_pos)
	if not state:
		return

	state["alive"] -= 1
	run_state.enemies_killed += 1

	if state["alive"] <= 0 and not state["cleared"]:
		state["cleared"] = true
		var room_data = run_state.floor_map.get(grid_pos) as RoomData
		if room_data:
			room_data.cleared = true
			run_state.rooms_cleared += 1
			var gold = int(10 + run_state.current_floor * 5 * randf_range(0.8, 1.2))
			run_state.run_gold += gold

			# Spawn key if room has KEY_LOCKED transitions
			if room_data.keys_needed > 0:
				_spawn_key_pickup(grid_pos)

			var qm = get_node_or_null("/root/QuestManager")
			if qm:
				qm.on_enemy_killed("")

func _spawn_key_pickup(grid_pos: Vector2i) -> void:
	var center = _grid_to_world_center(grid_pos)
	var pickup = DungeonKeyPickup.new()
	pickup.position = center
	pickup.key_collected.connect(_on_key_collected.bind(grid_pos))
	add_child(pickup)

func _on_key_collected(key_id: String, grid_pos: Vector2i) -> void:
	var room_data = run_state.floor_map.get(grid_pos) as RoomData
	if not room_data:
		return
	room_data.keys_collected += 1
	if room_data.keys_collected >= room_data.keys_needed:
		_open_key_locked_transitions(grid_pos)

func _open_key_locked_transitions(grid_pos: Vector2i) -> void:
	for child in transition_container.get_children():
		if child.is_in_group("key_locked_transitions"):
			var from = child.get_meta("from_grid", Vector2i(-999, -999))
			if from == grid_pos:
				var tiles = child.get_meta("transition_tiles") as Array
				var floor_tile = child.get_meta("floor_tile") as Vector2i
				for tile_pos in tiles:
					wall_layer.erase_cell(tile_pos)
					floor_layer.set_cell(tile_pos, 0, floor_tile)
				child.queue_free()
	_generate_wall_collisions()

func _on_stairs_entered(body: Node2D, grid_pos: Vector2i) -> void:
	if not body.is_in_group("player"):
		return
	var state = room_states.get(grid_pos)
	if state and not state["cleared"]:
		return
	_go_next_floor()

func _go_next_floor() -> void:
	run_state.current_floor += 1
	run_state.floors_cleared += 1
	current_level = _get_level_for_floor(run_state.current_floor)
	current_biome = _get_biome_for_floor(run_state.current_floor)
	_generate_floor(run_state.current_floor)
	floor_changed.emit(run_state.current_floor)

func _spawn_chest_loot(grid_pos: Vector2i) -> void:
	if not current_level or current_level.chest_loot.size() == 0:
		run_state.run_gold += int(20 + run_state.current_floor * 10)
		return

	var center = _grid_to_world_center(grid_pos)
	var pickup_scene = preload("res://scenes/pickup.tscn")
	var chest_def = current_level.chest_loot[0]
	var min_items = int(chest_def.get("min_items", 1))
	var max_items = int(chest_def.get("max_items", 2))
	var item_count = randi_range(min_items, max_items)
	var item_pool = chest_def.get("items", []) as Array

	if item_pool.size() == 0:
		run_state.run_gold += int(20 + run_state.current_floor * 10)
		return

	for i in range(item_count):
		var rolled_item = _roll_chest_item(item_pool)
		if rolled_item == "":
			continue

		if rolled_item == "Gold":
			var entry = _find_pool_entry(item_pool, "Gold")
			var gold_min = int(entry.get("min", 5))
			var gold_max = int(entry.get("max", 20))
			run_state.run_gold += randi_range(gold_min, gold_max)
			continue

		var safe_name = rolled_item.to_lower().replace(" ", "_")
		var item_path = "res://resources/items/loy/" + safe_name + ".tres"
		if not ResourceLoader.exists(item_path):
			continue
		var item = load(item_path) as EquipmentItem
		if not item:
			continue

		var pickup = pickup_scene.instantiate()
		pickup.item = item.duplicate()
		var offset = Vector2(randf_range(-16, 16), randf_range(-16, 16))
		pickup.global_position = center + offset
		add_child(pickup)

func _roll_chest_item(pool: Array) -> String:
	var total_weight = 0
	for entry in pool:
		total_weight += int(entry.get("chance", 1))
	var roll = randi() % maxi(total_weight, 1)
	var cumulative = 0
	for entry in pool:
		cumulative += int(entry.get("chance", 1))
		if roll < cumulative:
			return str(entry.get("name", ""))
	return ""

func _find_pool_entry(pool: Array, item_name: String) -> Dictionary:
	for entry in pool:
		if str(entry.get("name", "")) == item_name:
			return entry
	return {}

func on_player_died() -> void:
	run_state.end_time = Time.get_ticks_msec()
	run_ended.emit(run_state)
