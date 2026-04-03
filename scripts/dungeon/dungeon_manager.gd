class_name DungeonManager
extends Node2D

signal floor_changed(floor_number: int)
signal room_changed(room_index: int, room_data: RoomData)
signal run_ended(run_state: RunState)
signal reward_requested(room_data: RoomData)

# Trap scripts loaded at runtime to avoid parse-time circular dependency
var _TrapTileScript: GDScript
var _ArrowTrapScript: GDScript
var _DartTrapScript: GDScript
var _PoisonGasScript: GDScript
var _CollapsingFloorScript: GDScript
var _FlameJetScript: GDScript
var _SwingingAxeScript: GDScript
var _TrapLeverScript: GDScript
# _DungeonTrapScript not needed — duck-typing used instead

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
var _item_pool: ItemPool

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

# Grid cell size must fit largest room shape (25x23 Arena) + corridor gap
const DEFAULT_GRID_CELL_W = 29
const DEFAULT_GRID_CELL_H = 27
var GRID_CELL_W: int = DEFAULT_GRID_CELL_W
var GRID_CELL_H: int = DEFAULT_GRID_CELL_H
const TILE_SIZE = 8
const CORRIDOR_WIDTH = 3

# Liquid atlas coords per type (source 0, environment tileset)
const LIQUID_TILES = {
	"lava": [Vector2i(0, 17), Vector2i(0, 18)],
	"poison": [Vector2i(1, 17), Vector2i(1, 18)],
	"water": [Vector2i(2, 17), Vector2i(2, 18)],
}

const SPIDER_WEB_FULL = Vector2i(5, 19)

# Level gating for trap types — traps only spawn if recommended_level >= gate
const TRAP_LEVEL_GATES = {
	"spike": 1,
	"arrow": 1,
	"dart": 2,
	"poison_gas": 2,
	"collapsing_floor": 3,
	"swinging_axe": 3,
	"flame_jet": 5,
}

var _corridor_midpoints: Array[Dictionary] = []

var wall_body: StaticBody2D
var nav: DungeonNav  # flow-field navigation for enemies
var events # DungeonEvents - untyped to avoid circular dependency
var _flow_timer: float = 0.0

# Void boundary safety net
var _floor_tile_set: Dictionary = {}  # tile_pos (Vector2i) -> true
var _last_safe_pos: Vector2 = Vector2.ZERO
var _void_check_timer: float = 0.0

func _process(delta: float) -> void:
	# Update flow field every 2 seconds so all enemies know where to go
	_flow_timer -= delta
	if _flow_timer <= 0:
		_flow_timer = 2.0
		if nav and nav.is_ready() and player:
			nav.update_flow_field(player.global_position)

func _physics_process(delta: float) -> void:
	if not player or _floor_tile_set.is_empty():
		return
	_void_check_timer -= delta
	if _void_check_timer > 0:
		return
	_void_check_timer = 0.2
	var player_tile = Vector2i(
		int(floor(player.global_position.x / TILE_SIZE)),
		int(floor(player.global_position.y / TILE_SIZE))
	)
	if _floor_tile_set.has(player_tile):
		_last_safe_pos = player.global_position
	else:
		# Player is in void — teleport back to last safe position
		if _last_safe_pos != Vector2.ZERO:
			player.global_position = _last_safe_pos
			player.velocity = Vector2.ZERO

func _ready() -> void:
	add_to_group("dungeon_manager")
	RenderingServer.set_default_clear_color(Color.BLACK)
	# Load trap scripts at runtime to avoid parse-time circular dependency
	_TrapTileScript = load("res://scripts/dungeon/trap_tile.gd")
	_ArrowTrapScript = load("res://scripts/dungeon/traps/arrow_trap.gd")
	_DartTrapScript = load("res://scripts/dungeon/traps/dart_trap.gd")
	_PoisonGasScript = load("res://scripts/dungeon/traps/poison_gas.gd")
	_CollapsingFloorScript = load("res://scripts/dungeon/traps/collapsing_floor.gd")
	_FlameJetScript = load("res://scripts/dungeon/traps/flame_jet.gd")
	_SwingingAxeScript = load("res://scripts/dungeon/traps/swinging_axe.gd")
	_TrapLeverScript = load("res://scripts/dungeon/traps/trap_lever.gd")
	# Debug: verify trap scripts loaded
	for s_name in ["_TrapTileScript", "_ArrowTrapScript", "_DartTrapScript", "_PoisonGasScript", "_CollapsingFloorScript", "_FlameJetScript", "_SwingingAxeScript", "_TrapLeverScript"]:
		if get(s_name) == null:
			push_error("TRAP SCRIPT FAILED TO LOAD: " + s_name)
		else:
			print("TRAPS: loaded " + s_name)
	var t0 = Time.get_ticks_msec()
	_load_biomes()
	print("TIMING: _load_biomes took %d ms" % (Time.get_ticks_msec() - t0))
	# Create transition container
	transition_container = Node2D.new()
	transition_container.name = "Transitions"
	add_child(transition_container)

func _load_biomes() -> void:
	var t0 = Time.get_ticks_msec()
	for path in ResourceRegistry.biomes_base() + ResourceRegistry.biomes_loy():
		var res = load(path) as DungeonBiome
		if res:
			biomes.append(res)
	biomes.sort_custom(func(a: DungeonBiome, b: DungeonBiome) -> bool: return a.min_floor < b.min_floor)
	print("TIMING: loaded %d biomes in %d ms" % [biomes.size(), Time.get_ticks_msec() - t0])

var _levels_loaded_for: String = ""  # tracks which dungeon we loaded levels for

func _load_level_data_for(level_id: String) -> void:
	# Only load levels matching the level ID prefix (not all 199)
	# e.g. "Aria-Dungeons" → prefix "haven" → matches aria_dungeons, aria_2, aria_3, aria_crypt, etc.
	if _levels_loaded_for == level_id and level_data.size() > 0:
		return
	_levels_loaded_for = level_id
	level_data.clear()
	var t0 = Time.get_ticks_msec()
	# Extract area prefix: "Aria-Dungeons" → "Aria" → "haven"
	# "chidden1" (no dash) → "chidden1"
	var prefix: String
	if "-" in level_id:
		prefix = level_id.substr(0, level_id.find("-")).to_lower()
	else:
		prefix = level_id.to_lower()
	if prefix == "":
		print("WARNING: empty level prefix from level_id='%s', skipping level load" % level_id)
		return
	for path in ResourceRegistry.levels():
		var fbase = path.get_file().get_basename().to_lower()
		if fbase.begins_with(prefix):
			var res = load(path) as DungeonLevelData
			if res and res.id != "":
				level_data.append(res)
	print("TIMING: Loaded %d level definitions for '%s' (prefix='%s') in %d ms" % [level_data.size(), level_id, prefix, Time.get_ticks_msec() - t0])

func start_run() -> void:
	var t0 = Time.get_ticks_msec()
	_item_pool = ItemPool.new()
	run_state = RunState.new()
	run_state.run_id = str(randi())
	run_state.current_floor = 1

	# Create dungeon events system
	if events:
		events.queue_free()
	var _events_script = preload("res://scripts/dungeon/dungeon_events.gd")
	events = _events_script.new()
	events.name = "DungeonEvents"
	add_child(events)
	events.setup(self)

	# Find the biome first so we can use its loy_level_id for the level chain
	current_biome = _find_biome_by_name(starting_biome_name)
	if current_biome:
		print("Dungeon: Biome = '%s', enemy_pool size = %d, loy_level_id = '%s'" % [
			current_biome.biome_name, current_biome.enemy_pool.size(), current_biome.loy_level_id])
	else:
		print("Dungeon: WARNING - No biome found for starting_biome_name='%s'" % starting_biome_name)

	# Use starting_biome_name (zone dungeon_base) for level chain — level files use new names
	var level_id = starting_biome_name
	dungeon_levels = _find_level_chain(level_id)
	print("TIMING: _find_level_chain('%s') found %d levels in %d ms" % [level_id, dungeon_levels.size(), Time.get_ticks_msec() - t0])
	if dungeon_levels.size() > 0:
		current_level = dungeon_levels[0]
	else:
		current_level = null

	_generate_floor(1)
	print("TIMING: TOTAL start_run took %d ms" % (Time.get_ticks_msec() - t0))
	floor_changed.emit(1)

## Remap: renamed zone dungeon_base → original biome loy_level_id
const _DUNGEON_BASE_REMAP: Dictionary = {
	"Ashheim-Dungeons": "Heim-Dungeons",
	"Ashvale-Dungeons": "Vly-Dungeons",
	"Barrows-Crypt": "Aria-Crypt",
	"Bog-Dungeons": "TalMita-Base",
	"Brack-Dungeons": "Naleg-Base",
	"Briar-Dungeons": "Gomb-base",
	"Cenneth-Dungeons": "Cennyn-base",
	"Deep-Dungeons": "Jungle-Dungeons",
	"Dusk-Dungeons": "Ynys-Base",
	"Duskfarm-Dungeons": "Farm-base",
	"Duskwatch-Dungeons": "Nivek-Base",
	"Frostgrave-Dungeons": "Frozen-base",
	"Giant-Dungeons": "Drt-Dungeons",
	"Grim-Dungeons": "Nord-Dungeons",
	"Haven-Dungeons": "Aria-Dungeons",
	"Hollowvale-Dungeons": "Vale-dung",
	"Iron-Dungeons": "Mnt-Dungeons",
	"Kor-Dungeons": "Kor-Base",
	"Mirage-Dungeons": "Sthel-Dungeons",
	"Plains-Dungeons": "Plains-Base",
	"Scorch-Dungeons": "Bad-Dungeons",
	"Shrine-Dungeons": "Shrine-base",
	"Shroud-Dungeons": "Forest-Dungeons",
	"Storm-Dungeons": "Peaks-Base",
	"Thule-Dungeons": "Frozen-base",
	"Waste-Dungeons": "Wild-Dungeons",
	"Wind-Dungeons": "Airlon-Base",
}

func _find_biome_by_name(biome_name: String) -> DungeonBiome:
	if biome_name == "":
		return null
	# Match by display name first
	for b in biomes:
		if b.biome_name == biome_name:
			return b
	# Match by loy_level_id (dungeon_base values are often level IDs like "Aria-Dungeons")
	for b in biomes:
		if b.loy_level_id == biome_name:
			return b
	# Remap renamed zone dungeon_base → original biome loy_level_id
	if _DUNGEON_BASE_REMAP.has(biome_name):
		var remapped = _DUNGEON_BASE_REMAP[biome_name]
		for b in biomes:
			if b.loy_level_id == remapped:
				return b
	print("Dungeon: No biome found for '%s' (even after remap)" % biome_name)
	return null

func _find_level_chain(level_id: String) -> Array[DungeonLevelData]:
	_load_level_data_for(level_id)
	var chain: Array[DungeonLevelData] = []
	if level_id == "":
		return chain
	# Extract chain base: "Aria-Dungeons" → "Aria", "Aria-Crypt" → "Aria-Crypt"
	var chain_base = _get_chain_base(level_id)
	for ld in level_data:
		if _get_chain_base(ld.id) == chain_base:
			chain.append(ld)
	chain.sort_custom(func(a: DungeonLevelData, b: DungeonLevelData) -> bool:
		return a.id.naturalnocasecmp_to(b.id) < 0
	)
	print("Level chain for '%s' (base='%s'): %s" % [level_id, chain_base, chain.map(func(l): return l.id)])
	return chain

## Extract chain base from level ID: strips trailing number or "Dungeons" suffix
## "Aria-Dungeons" → "Aria", "Aria-2" → "Aria", "Aria-Crypt-3" → "Aria-Crypt"
static func _get_chain_base(lid: String) -> String:
	var parts = lid.split("-")
	if parts.size() <= 1:
		return lid
	var last = parts[parts.size() - 1]
	if last.is_valid_int() or last == "Dungeons":
		parts.resize(parts.size() - 1)
		return "-".join(PackedStringArray(parts))
	return lid

func _get_level_for_floor(floor_num: int) -> DungeonLevelData:
	if dungeon_levels.size() > 0:
		var idx = mini(floor_num - 1, dungeon_levels.size() - 1)
		return dungeon_levels[idx]
	return null

func _get_biome_for_floor(floor_num: int) -> DungeonBiome:
	var level = _get_level_for_floor(floor_num)
	if level:
		current_level = level
	# Always use the starting biome for the entire dungeon run
	if current_biome:
		return current_biome
	# Fallback: match by floor range
	for b in biomes:
		if floor_num >= b.min_floor and floor_num <= b.max_floor:
			return b
	if biomes.size() > 0:
		return biomes[(floor_num - 1) % biomes.size()]
	return null

var _add_stairs_down_to_start: bool = false  # set when going up a floor

func _generate_floor(floor_num: int) -> void:
	var t0 = Time.get_ticks_msec()
	if events:
		events.on_floor_changed()
	_clear_floor()
	_corridor_midpoints.clear()

	var level = _get_level_for_floor(floor_num)
	var room_override = -1
	if level:
		room_override = level.rooms

	var t1 = Time.get_ticks_msec()
	var map: Dictionary
	var _is_test_arena = starting_biome_name == "Test-Arena"
	if level and level.fixed_monsters.size() > 0:
		var room_scale = 1  # test arena uses normal room size
		var branch = level.branch_monsters if level.branch_monsters.size() > 0 else []
		map = FloorGenerator.generate_linear_arena(level.fixed_monsters, current_biome, room_scale, branch)
		# Use custom grid cell size from arena if provided
		if map.has("grid_cell_w"):
			GRID_CELL_W = map["grid_cell_w"]
			GRID_CELL_H = map["grid_cell_h"]
		else:
			GRID_CELL_W = DEFAULT_GRID_CELL_W
			GRID_CELL_H = DEFAULT_GRID_CELL_H
	else:
		GRID_CELL_W = DEFAULT_GRID_CELL_W
		GRID_CELL_H = DEFAULT_GRID_CELL_H
		map = FloorGenerator.generate_floor_map(floor_num, room_override, current_biome, get_total_floors())
	print("TIMING: generate_floor_map took %d ms (%d rooms, grid=%dx%d)" % [Time.get_ticks_msec() - t1, map["rooms"].size(), GRID_CELL_W, GRID_CELL_H])
	run_state.floor_map = map["rooms"]
	run_state.current_grid_pos = map["start"]
	run_state.stairs_pos = map["stairs"]

	# When player went upstairs, the start room also needs stairs down
	if _add_stairs_down_to_start:
		var start_room = run_state.floor_map.get(map["start"]) as RoomData
		if start_room:
			start_room.has_stairs_down = true
		_add_stairs_down_to_start = false

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
		var is_start = grid_pos == map["start"]
		_paint_room(grid_pos, room_data, theme_row, is_start)
		_create_room_trigger(grid_pos, room_data)

		# Start room and shop rooms are auto-cleared (no enemies to fight)
		var auto_cleared = room_data.type == RoomData.RoomType.SHOP or room_data.enemy_count == 0
		room_states[grid_pos] = {
			"visited": grid_pos == map["start"],
			"alive": 0,
			"cleared": auto_cleared,
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

	# Corridor traps (swinging axes with levers) — skip in test arena
	if starting_biome_name != "Test-Arena":
		_paint_corridor_traps(theme_row)

	# Create transitions between rooms
	t1 = Time.get_ticks_msec()
	_create_all_transitions(theme_row)
	print("TIMING: transitions took %d ms" % (Time.get_ticks_msec() - t1))

	# Cleanup: erase any wall tile that overlaps a floor tile (prevents blocked corridors)
	for cell in floor_layer.get_used_cells():
		wall_layer.erase_cell(cell)

	# Generate wall collisions (row-merged for performance)
	t1 = Time.get_ticks_msec()
	_generate_wall_collisions()
	_generate_deco_collisions()
	print("TIMING: wall + deco collisions took %d ms" % (Time.get_ticks_msec() - t1))

	# Build flow-field navigation for enemies
	t1 = Time.get_ticks_msec()
	nav = DungeonNav.new()
	nav.build(floor_layer, deco_layer, SOLID_DECO_ROWS)
	print("TIMING: nav grid took %d ms" % (Time.get_ticks_msec() - t1))

	# Place player at start room center
	var start_world = _grid_to_world_center(map["start"])
	player.global_position = start_world

	# Build initial flow field from player spawn
	nav.force_update(start_world)


	# Visit start room (activates traps, etc.)
	_visit_room(map["start"])

	# Pre-spawn enemies in rooms near the start (within 2 grid steps)
	# Other rooms spawn when player gets within 2 rooms
	t1 = Time.get_ticks_msec()
	var start = map["start"]
	for grid_pos in run_state.floor_map:
		var room_data = run_state.floor_map[grid_pos] as RoomData
		var dist_to_start = abs(grid_pos.x - start.x) + abs(grid_pos.y - start.y)
		match room_data.type:
			RoomData.RoomType.COMBAT, RoomData.RoomType.ELITE, RoomData.RoomType.BOSS:
				if dist_to_start > 0 and dist_to_start <= 2:
					room_states[grid_pos]["visited"] = true
					_spawn_room_enemies(grid_pos, room_data)
					# Activate traps in pre-spawned rooms
					for child in hazard_container.get_children():
						if "room_grid_pos" in child and child.has_method("activate") and child.room_grid_pos == grid_pos:
							child.activate()
	print("TIMING: spawn nearby enemies took %d ms" % (Time.get_ticks_msec() - t1))
	print("TIMING: TOTAL _generate_floor took %d ms" % (Time.get_ticks_msec() - t0))

	room_changed.emit(0, run_state.floor_map[map["start"]])

	# Spawn floor-start event objects (elder NPC, etc.)
	if events:
		events.on_floor_ready(map["start"])


func _clear_floor() -> void:
	floor_layer.clear()
	wall_layer.clear()
	deco_layer.clear()
	liquid_layer.clear()
	room_states.clear()
	transitions.clear()
	_floor_tile_set.clear()

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

	_nearby_stairs = null
	_hide_stairs_prompt()
	_nearby_interact_areas.clear()

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

# Decoration atlas rows that are solid objects (not flat floor decor)
const SOLID_DECO_ROWS = [0, 1, 2, 3]  # barrels, furniture, chairs, stone pots

func _generate_deco_collisions() -> void:
	# Add collision shapes for solid decoration tiles (barrels, chairs, tables, etc.)
	for cell in deco_layer.get_used_cells():
		var source_id = deco_layer.get_cell_source_id(cell)
		if source_id != 1:  # only source 1 = dungeon features
			continue
		var atlas = deco_layer.get_cell_atlas_coords(cell)
		if atlas.y in SOLID_DECO_ROWS:
			_add_wall_shape(cell.x, cell.x, cell.y)

## Break a solid decoration tile at a world position (boss/elite smash)
## Sets _deco_dirty flag; collision rebuild happens in smash_area or via flush
var _deco_dirty: bool = false

func break_deco_at(world_pos: Vector2) -> bool:
	var tile_pos = Vector2i(int(floor(world_pos.x / TILE_SIZE)), int(floor(world_pos.y / TILE_SIZE)))
	var source_id = deco_layer.get_cell_source_id(tile_pos)
	if source_id < 0:
		return false  # no deco tile here
	# Break ANY solid deco (source 0 or 1) in SOLID_DECO_ROWS
	var atlas = deco_layer.get_cell_atlas_coords(tile_pos)
	if source_id == 1 and atlas.y not in SOLID_DECO_ROWS:
		return false
	# Source 0 decos that are NOT solid (webs, stairs, etc.) — don't break those
	if source_id == 0 and atlas.y not in SOLID_DECO_ROWS:
		return false
	# Erase deco tile
	deco_layer.erase_cell(tile_pos)
	_deco_dirty = true
	# Update nav — mark cell as walkable so enemies can path through
	if nav:
		nav.mark_walkable(tile_pos)
		nav.invalidate()
	# VFX + SFX
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		var center = Vector2(tile_pos.x * TILE_SIZE + TILE_SIZE / 2.0, tile_pos.y * TILE_SIZE + TILE_SIZE / 2.0)
		vfx.death_burst(center, Color(0.6, 0.4, 0.2), 0)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("impact_b", -5.0, 0.15)
	return true

## Flush pending deco collision rebuilds (called after breaking deco without a wall smash)
func flush_deco_collisions() -> void:
	if _deco_dirty:
		_deco_dirty = false
		_generate_wall_collisions()
		_generate_deco_collisions()
		if nav:
			nav.invalidate()

## Smash an area: convert walls/void to floor, then edge new floors with walls
## This is the main method called by boss/elite obstacle breaking
func smash_area(world_pos: Vector2, radius_tiles: int) -> bool:
	var center_tile = Vector2i(int(world_pos.x) / TILE_SIZE, int(world_pos.y) / TILE_SIZE)

	# Find a nearby floor tile to copy the theme from
	var theme_floor = Vector2i(5, 0)  # fallback
	var theme_wall = Vector2i(4, 0)
	var _found_theme = false
	for dy in range(-4, 5):
		if _found_theme:
			break
		for dx in range(-4, 5):
			var neighbor = center_tile + Vector2i(dx, dy)
			if floor_layer.get_cell_source_id(neighbor) >= 0:
				theme_floor = floor_layer.get_cell_atlas_coords(neighbor)
				theme_wall = Vector2i(4, theme_floor.y)
				_found_theme = true
				break

	# Phase 1: Convert walls and void within radius to floor
	var new_floors: Array[Vector2i] = []
	for dy in range(-radius_tiles, radius_tiles + 1):
		for dx in range(-radius_tiles, radius_tiles + 1):
			if dx * dx + dy * dy > radius_tiles * radius_tiles:
				continue  # circular shape
			var tile = center_tile + Vector2i(dx, dy)
			var has_floor = floor_layer.get_cell_source_id(tile) >= 0
			var has_wall = wall_layer.get_cell_source_id(tile) >= 0
			if has_floor and not has_wall:
				continue  # already walkable floor
			# Erase wall if present
			if has_wall:
				wall_layer.erase_cell(tile)
			# Erase deco if present
			if deco_layer.get_cell_source_id(tile) >= 0:
				deco_layer.erase_cell(tile)
			# Place floor
			floor_layer.set_cell(tile, 0, theme_floor)
			new_floors.append(tile)

	if new_floors.is_empty():
		return false

	# Phase 2: Add wall edges around the newly created floor area
	# For every new floor tile, check cardinal + diagonal neighbors —
	# if the neighbor has no floor tile, place a wall there
	var wall_set: Dictionary = {}
	for tile in new_floors:
		for neighbor_offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
								Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
			var neighbor = tile + neighbor_offset
			if floor_layer.get_cell_source_id(neighbor) >= 0:
				continue
			if wall_set.has(neighbor):
				continue
			# Don't place new wall if there's already one (avoid duplicating tiles)
			if wall_layer.get_cell_source_id(neighbor) < 0:
				wall_layer.set_cell(neighbor, 0, theme_wall)
			wall_set[neighbor] = true

	# Update nav — mark all new floors as walkable
	if nav:
		for tile in new_floors:
			nav.mark_walkable(tile)
		nav.invalidate()

	# Phase 3: Rebuild ALL collision from the tile layers
	# This is the only reliable way — merged row shapes, void barriers, and deco
	# all need to be consistent with the updated tile state.
	# Performance: iterating a few thousand tiles is <1ms, and smash only happens
	# every 0.3s when near walls, so this is fine.
	_generate_wall_collisions()
	_generate_deco_collisions()

	# VFX + SFX
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		var fx_radius = maxf(radius_tiles * TILE_SIZE, 8.0)
		vfx.shockwave(world_pos, fx_radius, Color(0.5, 0.4, 0.3, 0.6))
		vfx.shake(1.5, 0.1)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("explode_b", -5.0, 0.12)
	return true

## Convenience: break a single wall tile (calls smash_area with radius 0)
func break_wall_at(world_pos: Vector2) -> bool:
	return smash_area(world_pos, 0)

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

func _paint_room(grid_pos: Vector2i, room_data: RoomData, theme_row: int, is_start_room: bool = false) -> void:
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
	var stairs_up = Vector2i(7, theme_row)

	# Paint floor and walls using floor mask
	for y in range(h):
		for x in range(w):
			var tile_pos = origin + Vector2i(x, y)
			if mask[y][x]:
				_floor_tile_set[tile_pos] = true
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

	# Stairs up (placed offset from center so they don't overlap stairs down)
	if room_data.has_stairs_up:
		var cx = w / 2 + 2
		var cy = h / 2
		if cx > 0 and cx < w and cy > 0 and cy < h and mask[cy][cx]:
			deco_layer.set_cell(origin + Vector2i(cx, cy), 0, stairs_up)
		else:
			cx = w / 2 - 2
			if cx > 0 and cx < w and mask[cy][cx]:
				deco_layer.set_cell(origin + Vector2i(cx, cy), 0, stairs_up)

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

	# No traps in the start room or test arena
	if not is_start_room and starting_biome_name != "Test-Arena":
		# Spike traps (based on biome trap_density)
		var trap_density = 0.02
		if current_biome:
			trap_density = current_biome.trap_density
		if trap_density > 0:
			_paint_spike_traps(origin, mask, w, h, trap_tile, trap_density, room_data, grid_pos)

		# Advanced traps (level-gated)
		if room_data.type == RoomData.RoomType.COMBAT or room_data.type == RoomData.RoomType.ELITE:
			_paint_advanced_traps(origin, mask, w, h, room_data, grid_pos, theme_row)

	# Room decorations from source 1 (lofi_dungeon_features.png)
	_paint_room_decorations(origin, mask, w, h, room_data)

	# Harvest nodes — 25% chance per room
	if randf() < 0.25:
		_spawn_room_harvest_node(origin, mask, w, h, room_data)

func _spawn_room_harvest_node(origin: Vector2i, mask: Array, w: int, h: int, room_data: RoomData) -> void:
	var pos = _random_interior_floor_tile(mask, w, h, 2)
	if pos == Vector2i(-1, -1):
		return
	# Avoid exits
	for dir_name in room_data.connections:
		var exit_pt = RoomShapeGenerator.get_exit_point(mask, w, h, dir_name)
		if pos.distance_to(exit_pt) < 3:
			return
	# Avoid stairs
	if room_data.has_stairs_down or room_data.has_stairs_up:
		var cx = w / 2
		var cy = h / 2
		if pos.distance_to(Vector2i(cx, cy)) < 3:
			return
	# Skip if deco already placed there
	if deco_layer.get_cell_source_id(origin + pos) != -1:
		return

	# Pick harvest type based on biome
	var harvest_types: Array[String] = ["mushroom", "ore", "herb"]
	var biome_name = ""
	if current_biome:
		biome_name = current_biome.biome_name.to_lower()
	if "cave" in biome_name or "dark" in biome_name or "crypt" in biome_name:
		harvest_types = ["mushroom", "ore"]
	elif "miredeep" in biome_name or "marsh" in biome_name:
		harvest_types = ["mushroom", "herb"]

	var htype = harvest_types[randi() % harvest_types.size()]
	var drop_tables = {
		"mushroom": ["res://resources/items/crafting/wild_mushroom.tres"],
		"ore": ["res://resources/items/crafting/iron_ore.tres", "res://resources/items/crafting/cave_crystal.tres"],
		"herb": ["res://resources/items/crafting/healing_herb.tres", "res://resources/items/crafting/swamp_root.tres"],
	}
	var sprite_tiles = {"mushroom": 124, "ore": 116, "herb": 123}

	var node = HarvestNode.new()
	node.harvest_type = htype
	node.drop_table.assign(drop_tables[htype])
	node.sprite_tile_index = sprite_tiles[htype]
	node.respawn_time = 0.0  # no respawn in dungeons
	node.collision_radius = 6.0  # fits 8px tile world
	node.sprite_scale = 0.22  # 32px * 0.22 ≈ 7px, fits 8px tiles
	node.position = Vector2((origin.x + pos.x) * TILE_SIZE + TILE_SIZE / 2, (origin.y + pos.y) * TILE_SIZE + TILE_SIZE / 2)
	node.z_index = 2
	add_child(node)

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
		if randf() < 0.05:
			return wall_cracked
		return wall_roof
	elif has_floor_right or has_floor_left:
		if randf() < 0.03:
			return wall_candle if has_floor_right else wall_candle_2
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

func _paint_spike_traps(origin: Vector2i, mask: Array, w: int, h: int, trap_tile: Vector2i, density: float, room_data: RoomData, grid_pos: Vector2i = Vector2i.ZERO) -> void:
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
		var trap = _TrapTileScript.new()
		trap.tile_pos = pos
		trap.origin = origin
		trap.deco_layer = deco_layer
		trap.trap_atlas = trap_tile
		trap.floor_number = run_state.current_floor if run_state else 1
		trap.room_grid_pos = grid_pos
		trap.position = Vector2((origin.x + pos.x) * TILE_SIZE + 4, (origin.y + pos.y) * TILE_SIZE + 4)
		hazard_container.add_child(trap)
		placed += 1
	print("TRAPS: placed %d spike traps in room %s" % [placed, str(grid_pos)])

func _get_effective_level() -> int:
	if current_level and current_level.recommended_level > 0:
		return current_level.recommended_level
	return run_state.current_floor if run_state else 1

func _get_allowed_traps() -> Array[String]:
	var level = _get_effective_level()
	var allowed: Array[String] = []
	for trap_type in TRAP_LEVEL_GATES:
		if level >= TRAP_LEVEL_GATES[trap_type]:
			allowed.append(trap_type)
	return allowed

func _paint_advanced_traps(origin: Vector2i, mask: Array, w: int, h: int, room_data: RoomData, grid_pos: Vector2i, theme_row: int) -> void:
	var allowed = _get_allowed_traps()
	var floor_count = 0
	for y in range(h):
		for x in range(w):
			if mask[y][x]:
				floor_count += 1

	var density = 0.01
	if current_biome and "advanced_trap_density" in current_biome:
		density = current_biome.get("advanced_trap_density")

	# Filter to room-only traps
	var room_traps: Array[String] = []
	for t in allowed:
		if t in ["arrow", "dart", "poison_gas", "collapsing_floor", "flame_jet"]:
			room_traps.append(t)

	if room_traps.size() == 0:
		return

	var trap_count = int(floor_count * density)
	if trap_count <= 0:
		return

	var floor_num = run_state.current_floor if run_state else 1
	var placed = 0
	var attempts = 0

	while placed < trap_count and attempts < trap_count * 10:
		attempts += 1
		var trap_type = room_traps[randi() % room_traps.size()]

		# Collapsing floor only in rooms with 40+ floor tiles, max 1-3 per room
		if trap_type == "collapsing_floor" and floor_count < 40:
			continue

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
		# Don't overlap existing deco tiles
		if deco_layer.get_cell_source_id(origin + pos) != -1:
			continue

		var world_pos = Vector2((origin.x + pos.x) * TILE_SIZE + 4, (origin.y + pos.y) * TILE_SIZE + 4)

		match trap_type:
			"arrow":
				# Use spike trap tile with red modulate for arrow traps
				var trap_tile_atlas = Vector2i(13, theme_row)
				deco_layer.set_cell(origin + pos, 0, trap_tile_atlas)
				var trap = _ArrowTrapScript.new()
				trap.tile_pos = pos
				trap.origin = origin
				trap.deco_layer = deco_layer
				trap.trap_atlas = trap_tile_atlas
				trap.floor_number = floor_num
				trap.room_grid_pos = grid_pos
				trap.position = world_pos
				hazard_container.add_child(trap)

			"dart":
				# Find nearest wall in a cardinal direction
				var wall_found = Vector2i(-1, -1)
				var dirs_2d = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
				dirs_2d.shuffle()
				for dir in dirs_2d:
					for dist in range(1, 15):
						var check = pos + dir * dist
						if check.x < 0 or check.x >= w or check.y < 0 or check.y >= h or not mask[check.y][check.x]:
							wall_found = origin + check
							break
					if wall_found != Vector2i(-1, -1):
						break
				if wall_found == Vector2i(-1, -1):
					continue

				# Use crack/rubble tile from features for pressure plate
				var plate_atlas = Vector2i(1, 4)
				deco_layer.set_cell(origin + pos, 1, plate_atlas)
				var trap = _DartTrapScript.new()
				trap.tile_pos = pos
				trap.origin = origin
				trap.deco_layer = deco_layer
				trap.trap_atlas = plate_atlas
				trap.trap_source_id = 1
				trap.wall_pos = wall_found
				trap.floor_number = floor_num
				trap.room_grid_pos = grid_pos
				trap.position = world_pos
				hazard_container.add_child(trap)

			"poison_gas":
				var gas_atlas = Vector2i(4, 19)
				deco_layer.set_cell(origin + pos, 0, gas_atlas)
				var trap = _PoisonGasScript.new()
				trap.tile_pos = pos
				trap.origin = origin
				trap.deco_layer = deco_layer
				trap.trap_atlas = gas_atlas
				trap.floor_number = floor_num
				trap.room_grid_pos = grid_pos
				trap.position = world_pos
				hazard_container.add_child(trap)

			"collapsing_floor":
				# Faint crack overlay
				deco_layer.set_cell(origin + pos, 1, Vector2i(2, 4))
				var trap = _CollapsingFloorScript.new()
				trap.tile_pos = pos
				trap.origin = origin
				trap.deco_layer = deco_layer
				trap.floor_layer = floor_layer
				trap.liquid_layer = liquid_layer
				trap.floor_number = floor_num
				trap.room_grid_pos = grid_pos
				trap.position = world_pos
				# Check if biome has liquid
				if current_biome and current_biome.liquid_type != "":
					trap.has_liquid = true
					var liq_type = current_biome.liquid_type
					if LIQUID_TILES.has(liq_type):
						trap.liquid_tiles.assign(LIQUID_TILES[liq_type])
				hazard_container.add_child(trap)

			"flame_jet":
				# Find a floor tile at the room edge (adjacent to wall)
				var jet_pos = Vector2i(-1, -1)
				var fire_dir = Vector2.ZERO
				for _try in range(30):
					var fx = randi_range(1, w - 2)
					var fy = randi_range(1, h - 2)
					if not mask[fy][fx]:
						continue
					# Check if this floor tile borders a wall
					for check_dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
						var nx = fx + check_dir.x
						var ny = fy + check_dir.y
						if nx >= 0 and nx < w and ny >= 0 and ny < h and not mask[ny][nx]:
							# Wall is at check_dir, fire shoots opposite (into room)
							jet_pos = Vector2i(fx, fy)
							fire_dir = Vector2(-check_dir.x, -check_dir.y)
							break
					if jet_pos != Vector2i(-1, -1):
						break
				if jet_pos == Vector2i(-1, -1):
					continue

				# Torch marker on the floor tile near wall
				deco_layer.set_cell(origin + jet_pos, 1, Vector2i(6, 1))
				var trap = _FlameJetScript.new()
				trap.tile_pos = jet_pos
				trap.origin = origin
				trap.deco_layer = deco_layer
				trap.fire_direction = fire_dir
				trap.floor_number = floor_num
				trap.room_grid_pos = grid_pos
				trap.position = Vector2((origin.x + jet_pos.x) * TILE_SIZE + 4, (origin.y + jet_pos.y) * TILE_SIZE + 4)
				hazard_container.add_child(trap)

		placed += 1
	print("TRAPS: placed %d advanced traps (allowed: %s, level: %d) in room %s" % [placed, str(room_traps), _get_effective_level(), str(grid_pos)])

func _find_wall_adjacent_to_floor(mask: Array, w: int, h: int, min_floor_neighbors: int) -> Vector2i:
	## Find a non-floor tile that borders at least min_floor_neighbors floor tiles.
	for _attempt in range(30):
		var x = randi_range(1, w - 2)
		var y = randi_range(1, h - 2)
		if mask[y][x]:
			continue  # We want a wall tile
		var floor_count = 0
		for dir in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var nx = x + dir.x
			var ny = y + dir.y
			if nx >= 0 and nx < w and ny >= 0 and ny < h and mask[ny][nx]:
				floor_count += 1
		if floor_count >= min_floor_neighbors:
			return Vector2i(x, y)
	return Vector2i(-1, -1)

func _paint_corridor_traps(theme_row: int) -> void:
	var allowed = _get_allowed_traps()
	if "swinging_axe" not in allowed:
		return

	var floor_num = run_state.current_floor if run_state else 1

	for midpoint in _corridor_midpoints:
		if randf() > 0.2:  # 20% chance per corridor
			continue

		var pos = midpoint["position"] as Vector2
		var direction = midpoint["direction"] as String

		# Create swinging axe
		var axe = _SwingingAxeScript.new()
		axe.floor_number = floor_num
		axe.corridor_direction = direction
		axe.position = pos
		hazard_container.add_child(axe)

		# Place lever 3-5 tiles along the corridor from the axe (within walkable area)
		var lever_offset: Vector2
		var lever_dist = randi_range(3, 5) * TILE_SIZE * (1 if randf() > 0.5 else -1)
		if direction == "east":
			lever_offset = Vector2(lever_dist, 0)
		else:
			lever_offset = Vector2(0, lever_dist)

		var lever = _TrapLeverScript.new()
		lever.axe = axe
		lever.position = pos + lever_offset
		hazard_container.add_child(lever)

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
		# Don't place on stairs down
		if room_data.has_stairs_down:
			var cx = w / 2
			var cy = h / 2 - 2
			if pos == Vector2i(cx, cy) or pos == Vector2i(cx, h / 2):
				continue
		# Don't place on stairs up
		if room_data.has_stairs_up:
			var cx2 = w / 2 + 2
			var cy2 = h / 2
			if pos == Vector2i(cx2, cy2) or pos == Vector2i(w / 2 - 2, cy2):
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

	# Boss/Elite corridors are wider (5 tiles instead of 3)
	var is_wide_corridor = (
		from_room.type == RoomData.RoomType.BOSS or to_room.type == RoomData.RoomType.BOSS
		or from_room.type == RoomData.RoomType.ELITE or to_room.type == RoomData.RoomType.ELITE
	)
	var half_w = 2 if is_wide_corridor else 1  # floor extends -half_w to +half_w
	var wall_offset = half_w + 1  # walls just outside floor

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
			for dy in range(-half_w, half_w + 1):
				var ct = Vector2i(x, mid_y + dy)
				floor_layer.set_cell(ct, 0, floor_tile)
				_floor_tile_set[ct] = true
			wall_layer.set_cell(Vector2i(x, mid_y - wall_offset), 0, wall_tile)
			wall_layer.set_cell(Vector2i(x, mid_y + wall_offset), 0, wall_tile)
			if corridor_liquid.size() > 0:
				liquid_layer.set_cell(Vector2i(x, mid_y - 1), 0, corridor_liquid[randi() % corridor_liquid.size()])
				liquid_layer.set_cell(Vector2i(x, mid_y + 1), 0, corridor_liquid[randi() % corridor_liquid.size()])
				deco_layer.set_cell(Vector2i(x, mid_y), 0, SPIDER_WEB_FULL)

		# Open walls at room exits
		_open_exit_wall(from_origin, from_exit, from_room.floor_mask, from_room.shape_width, from_room.shape_height, floor_tile, half_w)
		_open_exit_wall(to_origin, to_exit, to_room.floor_mask, to_room.shape_width, to_room.shape_height, floor_tile, half_w)

		# Record corridor midpoint for trap placement
		if end_x > start_x:
			var mid_x_c = (start_x + end_x) / 2
			var t_mid = 0.5
			var mid_y_c = int(lerp(float(from_mid_y), float(to_mid_y), t_mid))
			_corridor_midpoints.append({
				"position": Vector2(mid_x_c * TILE_SIZE + 4, mid_y_c * TILE_SIZE + 4),
				"direction": "east",
			})

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
			for dx in range(-half_w, half_w + 1):
				var ct = Vector2i(mid_x + dx, y)
				floor_layer.set_cell(ct, 0, floor_tile)
				_floor_tile_set[ct] = true
			wall_layer.set_cell(Vector2i(mid_x - wall_offset, y), 0, wall_tile)
			wall_layer.set_cell(Vector2i(mid_x + wall_offset, y), 0, wall_tile)
			if corridor_liquid.size() > 0:
				liquid_layer.set_cell(Vector2i(mid_x - 1, y), 0, corridor_liquid[randi() % corridor_liquid.size()])
				liquid_layer.set_cell(Vector2i(mid_x + 1, y), 0, corridor_liquid[randi() % corridor_liquid.size()])
				deco_layer.set_cell(Vector2i(mid_x, y), 0, SPIDER_WEB_FULL)

		_open_exit_wall(from_origin, from_exit, from_room.floor_mask, from_room.shape_width, from_room.shape_height, floor_tile, half_w)
		_open_exit_wall(to_origin, to_exit, to_room.floor_mask, to_room.shape_width, to_room.shape_height, floor_tile, half_w)

		# Record corridor midpoint for trap placement
		if end_y > start_y:
			var mid_y_c = (start_y + end_y) / 2
			var t_mid = 0.5
			var mid_x_c = int(lerp(float(from_mid_x), float(to_mid_x), t_mid))
			_corridor_midpoints.append({
				"position": Vector2(mid_x_c * TILE_SIZE + 4, mid_y_c * TILE_SIZE + 4),
				"direction": "south",
			})

func _open_exit_wall(origin: Vector2i, exit_point: Vector2i, mask: Array, w: int, h: int, floor_tile: Vector2i, exit_half_w: int = 1) -> void:
	# Carve opening from the room edge inward to guarantee corridor connectivity.
	# exit_half_w controls width: 1 = 3 tiles, 2 = 5 tiles
	var is_east_west = exit_point.x == 0 or exit_point.x == w - 1
	var inward_dir: int
	if is_east_west:
		inward_dir = 1 if exit_point.x == 0 else -1
	else:
		inward_dir = 1 if exit_point.y == 0 else -1

	# Carve inward (into the room) and outward (into the corridor gap)
	for depth in range(-2, 6):
		for offset in range(-exit_half_w, exit_half_w + 1):
			var tx: int
			var ty: int
			if is_east_west:
				tx = exit_point.x + depth * inward_dir
				ty = exit_point.y + offset
			else:
				tx = exit_point.x + offset
				ty = exit_point.y + depth * inward_dir
			var tile_pos = origin + Vector2i(tx, ty)
			wall_layer.erase_cell(tile_pos)
			floor_layer.set_cell(tile_pos, 0, floor_tile)
			_floor_tile_set[tile_pos] = true

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
	# Use wider barriers for boss/elite corridors
	var to_room = run_state.floor_map[to_grid] as RoomData
	var is_wide = (
		from_room.type == RoomData.RoomType.BOSS or to_room.type == RoomData.RoomType.BOSS
		or from_room.type == RoomData.RoomType.ELITE or to_room.type == RoomData.RoomType.ELITE
	)
	var t_half_w = 2 if is_wide else 1
	var transition_tiles: Array[Vector2i] = []
	if direction == "east":
		var base_x = from_origin.x + from_room.shape_width
		var base_y = from_origin.y + exit_point.y
		for dy in range(-t_half_w, t_half_w + 1):
			transition_tiles.append(Vector2i(base_x, base_y + dy))
	elif direction == "south":
		var base_x = from_origin.x + exit_point.x
		var base_y = from_origin.y + from_room.shape_height
		for dx in range(-t_half_w, t_half_w + 1):
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
	prompt.text = "Tap" if TouchControls.is_mobile() else "[E] Open"
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
var _nearby_stairs: Area2D = null  # stairs trigger player is standing near
var _interact_prompt: Label = null  # "Press E" prompt for stairs

func _on_interact_area_entered(body: Node2D, area: Area2D) -> void:
	if body.is_in_group("player"):
		var prompt = area.get_meta("prompt") as Label
		if prompt:
			prompt.visible = true
		if not area in _nearby_interact_areas:
			_nearby_interact_areas.append(area)
		if TouchControls.is_mobile():
			var tc = get_tree().get_first_node_in_group("touch_controls") as TouchControls
			if tc:
				tc.show_interact_button("Open")

func _on_interact_area_exited(body: Node2D, area: Area2D) -> void:
	if body.is_in_group("player"):
		var prompt = area.get_meta("prompt") as Label
		if prompt:
			prompt.visible = false
		_nearby_interact_areas.erase(area)
		if TouchControls.is_mobile() and _nearby_interact_areas.is_empty():
			var tc = get_tree().get_first_node_in_group("touch_controls") as TouchControls
			if tc:
				tc.hide_interact_button()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		# Stairs take priority
		if _nearby_stairs and is_instance_valid(_nearby_stairs):
			if _nearby_stairs.is_in_group("stairs_down_trigger"):
				var gp = _nearby_stairs.get_meta("grid_pos")
				var st = room_states.get(gp)
				if st and st["cleared"]:
					_go_next_floor()
					get_viewport().set_input_as_handled()
					return
			elif _nearby_stairs.is_in_group("stairs_up_trigger"):
				var gp = _nearby_stairs.get_meta("grid_pos")
				if run_state.current_floor <= 1:
					run_state.end_time = Time.get_ticks_msec()
					run_ended.emit(run_state)
				else:
					_go_prev_floor()
				get_viewport().set_input_as_handled()
				return
		# Check event interactables first (altar, blessing, merchant)
		if events:
			for area in _nearby_interact_areas:
				if is_instance_valid(area) and area.has_meta("event_type"):
					if events.try_interact(area):
						get_viewport().set_input_as_handled()
						return
		# Then check interact transitions
		for area in _nearby_interact_areas:
			if is_instance_valid(area):
				_open_interact_transition(area)
				get_viewport().set_input_as_handled()
				break

func _open_interact_transition(area: Area2D) -> void:
	var sfx_it = get_node_or_null("/root/SFXManager")
	if sfx_it:
		sfx_it.play("bay_door_open", -3.0, 0.1)
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
		stairs_trigger.add_to_group("stairs_down_trigger")
		stairs_trigger.set_meta("grid_pos", grid_pos)
		var origin = _grid_to_tile_origin(grid_pos)
		var cx = room_data.shape_width / 2
		var cy = room_data.shape_height / 2 - 2
		if not (cy > 0 and cy < room_data.shape_height and room_data.floor_mask[cy][cx]):
			cy = room_data.shape_height / 2
		var stair_tile = origin + Vector2i(cx, cy)
		stairs_trigger.position = Vector2(stair_tile.x * TILE_SIZE + 4, stair_tile.y * TILE_SIZE + 4)
		var stair_shape = CollisionShape2D.new()
		var stair_rect = RectangleShape2D.new()
		stair_rect.size = Vector2(TILE_SIZE * 2, TILE_SIZE * 2)
		stair_shape.shape = stair_rect
		stairs_trigger.add_child(stair_shape)
		stairs_trigger.body_entered.connect(_on_stairs_proximity.bind(stairs_trigger, true))
		stairs_trigger.body_exited.connect(_on_stairs_proximity.bind(stairs_trigger, false))
		room_triggers.add_child(stairs_trigger)

	if room_data.has_stairs_up:
		var up_trigger = Area2D.new()
		up_trigger.collision_layer = 0
		up_trigger.collision_mask = 1
		up_trigger.add_to_group("stairs_up_trigger")
		up_trigger.set_meta("grid_pos", grid_pos)
		var up_origin = _grid_to_tile_origin(grid_pos)
		var uw = room_data.shape_width
		var uh = room_data.shape_height
		var ucx = uw / 2 + 2
		var ucy = uh / 2
		var umask = room_data.floor_mask
		if not (ucx > 0 and ucx < uw and ucy > 0 and ucy < uh and umask[ucy][ucx]):
			ucx = uw / 2 - 2
		var stair_tile = up_origin + Vector2i(ucx, ucy)
		up_trigger.position = Vector2(stair_tile.x * TILE_SIZE + 4, stair_tile.y * TILE_SIZE + 4)
		var up_shape = CollisionShape2D.new()
		var up_rect = RectangleShape2D.new()
		up_rect.size = Vector2(TILE_SIZE * 2, TILE_SIZE * 2)
		up_shape.shape = up_rect
		up_trigger.add_child(up_shape)
		up_trigger.body_entered.connect(_on_stairs_proximity.bind(up_trigger, true))
		up_trigger.body_exited.connect(_on_stairs_proximity.bind(up_trigger, false))
		room_triggers.add_child(up_trigger)

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
				# Activate traps in pre-spawned rooms
				for child in hazard_container.get_children():
					if "room_grid_pos" in child and child.has_method("activate") and child.room_grid_pos == neighbor_pos:
						child.activate()

func _visit_room(grid_pos: Vector2i) -> void:
	var state = room_states[grid_pos]
	state["visited"] = true

	# Activate traps in this room
	for child in hazard_container.get_children():
		if "room_grid_pos" in child and child.has_method("activate") and child.room_grid_pos == grid_pos:
			child.activate()

	var room_data = run_state.floor_map[grid_pos] as RoomData

	match room_data.type:
		RoomData.RoomType.COMBAT, RoomData.RoomType.ELITE, RoomData.RoomType.BOSS:
			_spawn_room_enemies(grid_pos, room_data)
		RoomData.RoomType.TREASURE, RoomData.RoomType.SHRINE:
			# Guarded reward rooms — spawn enemies that must be cleared first
			_spawn_room_enemies(grid_pos, room_data)
			_spawn_chest_loot(grid_pos)
			reward_requested.emit(room_data)
		_:
			pass

# --- Enemy Spawning ---

func _spawn_room_enemies(grid_pos: Vector2i, room_data: RoomData) -> void:
	var enemy_scene = preload("res://scenes/enemy.tscn")

	var count = room_data.enemy_count
	if count == 0:
		return  # Room explicitly has no enemies (e.g. start room)
	# Only override count from level data for combat/treasure/shrine rooms
	# Elite and boss rooms use the floor_generator count which scales properly
	if current_level and room_data.type != RoomData.RoomType.ELITE and room_data.type != RoomData.RoomType.BOSS:
		var min_m = current_level.min_monsters
		var max_m = maxi(current_level.max_monsters, 1)
		# Escalate enemy count by Manhattan distance from start room
		var start_gp = _find_start_grid_pos()
		var dist = absi(grid_pos.x - start_gp.x) + absi(grid_pos.y - start_gp.y)
		if dist <= 1:
			count = min_m
		elif dist <= 3:
			count = randi_range(min_m, max_m)
		else:
			count = randi_range(max_m, mini(max_m + 2, max_m + 2))
		count = maxi(count, 1)

	# For HORDE encounters, only spawn first half now; second wave comes after timer
	var horde_wave2_count = 0
	if room_data.encounter_type == RoomData.EncounterType.HORDE:
		horde_wave2_count = count / 2
		count = count - horde_wave2_count

	# Get spawn positions based on encounter formation
	var spawn_positions = _get_formation_positions(grid_pos, room_data, count)

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
		if room_data.fixed_enemy_name != "":
			def = _load_enemy_by_name(room_data.fixed_enemy_name)
			if not def:
				def = fallback_def.duplicate()
		elif room_data.type == RoomData.RoomType.BOSS:
			# Quest boss override — active quest can replace the floor boss
			var _quest_boss_path = ""
			var _qm = get_node_or_null("/root/QuestManager")
			if _qm and _qm.has_method("get_quest_boss_override"):
				_quest_boss_path = _qm.get_quest_boss_override(starting_biome_name)
			if _quest_boss_path != "":
				var _qb = load(_quest_boss_path) as EnemyDefinition
				if _qb:
					def = _qb.duplicate()
			# Try biome boss definition first, then LoY legend, then generate from pool
			elif current_biome and current_biome.boss_definition:
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

		print("  SPAWNED: '%s' (tile=%d, kingdom=%s) from %s" % [
			def.enemy_name, def.loy_tile_index, def.kingdom,
			"loy_pool" if loy_pool.size() > 0 else ("biome_pool" if pool.size() > 0 else "fallback")])

		# Fixed enemies use base stats — skip normal scaling
		# Exception: Test-Arena makes fixed enemies elite with boosted HP
		var _is_fixed = room_data.fixed_enemy_name != ""
		if _is_fixed and starting_biome_name == "Test-Arena":
			# Test arena: flat 500 HP, scaled damage, keep NORMAL size (no random extra attacks)
			def.max_hp = 500
			def.attack_damage = maxi(5, def.attack_damage * 5)
			def.sprite_color = def.sprite_color.lightened(0.2)
		if not _is_fixed:
			# Additive scaling: dungeon base level + player level
			var rec_level = current_level.recommended_level if current_level else 0
			var player_level = player.level_system.level if player and player.level_system else 1
			var effective_level = rec_level + player_level
			var level_scale = 1.0 + effective_level * 0.15
			var dmg_scale = 1.0 + effective_level * 0.08
			# Apply room type mult (boss/elite) + level scaling
			def.max_hp = maxi(1, int(def.max_hp * room_data.enemy_hp_mult * level_scale))
			def.attack_damage = maxi(1, int(def.attack_damage * room_data.enemy_damage_mult * dmg_scale))
			# Armor scales with dungeon depth: ~1 per 5 recommended levels
			if rec_level >= 5:
				def.armor = maxi(def.armor, int(rec_level / 5))

		# Rare elite in normal combat room: promote first enemy to elite
		var _promote_to_elite = (i == 0
			and room_data.type == RoomData.RoomType.COMBAT
			and room_data.has_meta("has_rare_elite")
			and room_data.get_meta("has_rare_elite"))
		if not _is_fixed and _promote_to_elite:
			var is_bomb_rare = _is_bomb_attack_type(def.attack_type)
			def.move_speed *= 1.2
			if is_bomb_rare:
				def.attack_speed *= 1.4
				def.attack_damage = int(def.attack_damage * 2.0)
				def.bomb_aoe_radius *= 1.2
			else:
				def.attack_speed *= 0.85
				def.bullet_count += 2
			def.size_class = EnemyDefinition.SizeClass.LARGE
			def.bullet_speed *= 1.1
			def.boss_phases = 2
			def.max_hp = int(def.max_hp * 2.0)
			def.attack_damage = int(def.attack_damage * 1.2)
			def.armor += 2
			if def.phase_2_attack == EnemyDefinition.AttackType.NONE:
				def.phase_2_attack = _get_boss_phase_attack(def.attack_type, 2)
			def.phase_2_bullet_count = def.bullet_count + 2
			def.sprite_color = def.sprite_color.lightened(0.25)

		if not _is_fixed and room_data.type == RoomData.RoomType.ELITE:
			# Mini-boss: LARGE, 2 phases, escalated attacks, spawns minions
			var is_bomb_elite = _is_bomb_attack_type(def.attack_type)
			def.move_speed *= 1.3
			if is_bomb_elite:
				def.attack_speed *= 1.5  # SLOWER bombs, heavier hits
				def.attack_damage = int(def.attack_damage * 2.5)
				def.bomb_aoe_radius *= 1.3
			else:
				def.attack_speed *= 0.8  # faster attacks
			def.size_class = EnemyDefinition.SizeClass.LARGE
			if not is_bomb_elite:
				def.bullet_count += 3
			def.bullet_speed *= 1.2
			def.boss_phases = 2
			def.summon_on_phase_change = true
			def.summon_phase_count = 2  # 2 minions per phase change
			if not def.summon_definition:
				def.summon_definition = _get_weakest_enemy(loy_pool, pool)
			# Archetype-based phase 2 attack (same system as bosses)
			if def.phase_2_attack == EnemyDefinition.AttackType.NONE:
				def.phase_2_attack = _get_boss_phase_attack(def.attack_type, 2)
			def.phase_2_bullet_count = def.bullet_count + 3
			def.sprite_color = def.sprite_color.lightened(0.3)
			def.armor += 3
		elif not _is_fixed and room_data.type == RoomData.RoomType.BOSS:
			# Full boss: 3 phases, minion summoning (HP already scaled by room_data.enemy_hp_mult)
			var is_bomb_boss = _is_bomb_attack_type(def.attack_type)
			def.move_speed *= 0.85
			if is_bomb_boss:
				def.attack_speed *= 1.8  # MUCH slower bombs, devastating hits
				def.attack_damage = int(def.attack_damage * 3.0)
				def.bomb_aoe_radius *= 1.5
			else:
				def.attack_speed *= 0.7  # faster attacks
				def.bullet_count += 4
			def.bullet_speed *= 1.2
			def.size_class = EnemyDefinition.SizeClass.BOSS
			def.boss_phases = 3
			def.summon_on_phase_change = true
			def.summon_phase_count = 4
			# Assign phase attacks based on enemy archetype for distinct boss fights
			if def.phase_2_attack == EnemyDefinition.AttackType.NONE:
				def.phase_2_attack = _get_boss_phase_attack(def.attack_type, 2)
				def.phase_2_bullet_count = 12
			if def.phase_3_attack == EnemyDefinition.AttackType.NONE:
				def.phase_3_attack = _get_boss_phase_attack(def.attack_type, 3)
				def.phase_3_bullet_count = 16
			# Set summon definition to weakest enemy for minion spawning
			if not def.summon_definition:
				def.summon_definition = _get_weakest_enemy(loy_pool, pool)
			def.sprite_color = def.sprite_color.lightened(0.5)
			def.armor += 5

		if not _is_fixed and room_data.type == RoomData.RoomType.COMBAT:
			def = _try_make_rare(def)

		# Assign runtime loot table based on enemy role
		if _item_pool and not def.drop_table:
			var bd = current_biome.base_difficulty if current_biome else 0
			if room_data.type == RoomData.RoomType.BOSS:
				def.drop_table = _item_pool.create_boss_drop_table(run_state.current_floor, bd)
			elif room_data.type == RoomData.RoomType.ELITE or _promote_to_elite:
				def.drop_table = _item_pool.create_elite_drop_table(run_state.current_floor, bd)
			else:
				def.drop_table = _item_pool.create_drop_table(run_state.current_floor, false, bd)

		var enemy = enemy_scene.instantiate()
		enemy.global_position = spawn_pos
		enemy.setup(def)
		enemy._nav = nav  # give enemy A* navigation
		enemy._dm = self  # give enemy access to dungeon manager for obstacle breaking
		enemy.set_meta("grid_pos", grid_pos)
		enemy.tree_exited.connect(_on_enemy_died.bind(grid_pos))
		enemy_container.add_child(enemy)

		room_states[grid_pos]["alive"] += 1

	# HORDE wave 2: schedule remaining enemies after 5 seconds
	if horde_wave2_count > 0:
		room_states[grid_pos]["horde_wave2_count"] = horde_wave2_count
		var timer = get_tree().create_timer(5.0)
		timer.timeout.connect(_spawn_horde_wave_2.bind(grid_pos))

func _spawn_horde_wave_2(grid_pos: Vector2i) -> void:
	if not room_states.has(grid_pos):
		return
	var state = room_states[grid_pos]
	var wave2_count = state.get("horde_wave2_count", 0)
	if wave2_count <= 0:
		return
	state.erase("horde_wave2_count")

	var room_data = run_state.floor_map.get(grid_pos) as RoomData
	if not room_data:
		return

	var spawn_positions = _get_valid_spawn_positions(grid_pos, room_data, wave2_count)
	var enemy_scene = preload("res://scenes/enemy.tscn")
	var loy_pool = _get_loy_enemy_pool()
	var pool = current_biome.enemy_pool if current_biome and current_biome.enemy_pool.size() > 0 else []
	var fallback_def = EnemyDefinition.new()
	fallback_def.enemy_name = "Default"
	fallback_def.max_hp = 3
	fallback_def.attack_type = EnemyDefinition.AttackType.RANGED

	for i in range(mini(wave2_count, spawn_positions.size())):
		var def: EnemyDefinition
		if loy_pool.size() > 0:
			def = _pick_weighted_enemy(loy_pool)
		elif pool.size() > 0:
			def = pool[randi() % pool.size()].duplicate()
		else:
			def = fallback_def.duplicate()

		# Apply same scaling as wave 1
		var rec_level = current_level.recommended_level if current_level else 0
		var player_level = player.level_system.level if player and player.level_system else 1
		var effective_level = rec_level + player_level
		var level_scale = 1.0 + effective_level * 0.15
		var dmg_scale = 1.0 + effective_level * 0.08
		def.max_hp = maxi(1, int(def.max_hp * room_data.enemy_hp_mult * level_scale))
		def.attack_damage = maxi(1, int(def.attack_damage * room_data.enemy_damage_mult * dmg_scale))

		if _item_pool and not def.drop_table:
			var bd = current_biome.base_difficulty if current_biome else 0
			def.drop_table = _item_pool.create_drop_table(run_state.current_floor, false, bd)

		var enemy = enemy_scene.instantiate()
		enemy.global_position = spawn_positions[i]
		enemy.setup(def)
		enemy._nav = nav
		enemy._dm = self
		enemy.set_meta("grid_pos", grid_pos)
		enemy.tree_exited.connect(_on_enemy_died.bind(grid_pos))
		enemy_container.add_child(enemy)
		# Brief spawn flash
		enemy.modulate = Color(2.0, 2.0, 2.0, 1.0)
		var tween = create_tween()
		tween.tween_property(enemy, "modulate", Color.WHITE, 0.3)
		room_states[grid_pos]["alive"] += 1

func _find_start_grid_pos() -> Vector2i:
	for pos in run_state.floor_map:
		var rd = run_state.floor_map[pos] as RoomData
		if rd and rd.has_stairs_up:
			return pos
	return Vector2i.ZERO

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
	# Elite/boss rooms: enforce minimum distance between spawns for better spread
	var is_elite_room = room_data.type == RoomData.RoomType.ELITE or room_data.type == RoomData.RoomType.BOSS
	var min_dist_sq = (6.0 * TILE_SIZE) * (6.0 * TILE_SIZE) if is_elite_room else 0.0  # 6 tiles apart
	for v in valid:
		if result.size() >= count:
			break
		var world_pos = Vector2((origin.x + v.x) * TILE_SIZE + 4, (origin.y + v.y) * TILE_SIZE + 4)
		if min_dist_sq > 0:
			var too_close = false
			for existing in result:
				if world_pos.distance_squared_to(existing) < min_dist_sq:
					too_close = true
					break
			if too_close:
				continue
		result.append(world_pos)
	# If minimum distance was too strict, relax and fill remaining
	if result.size() < count:
		for v in valid:
			if result.size() >= count:
				break
			var world_pos = Vector2((origin.x + v.x) * TILE_SIZE + 4, (origin.y + v.y) * TILE_SIZE + 4)
			var already_used = false
			for existing in result:
				if world_pos.distance_squared_to(existing) < 4.0:
					already_used = true
					break
			if not already_used:
				result.append(world_pos)

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

func _get_formation_positions(grid_pos: Vector2i, room_data: RoomData, count: int) -> Array[Vector2]:
	match room_data.encounter_type:
		RoomData.EncounterType.AMBUSH:
			return _get_perimeter_positions(grid_pos, room_data, count)
		RoomData.EncounterType.GAUNTLET:
			return _get_row_positions(grid_pos, room_data, count)
		RoomData.EncounterType.ARENA:
			return _get_ring_positions(grid_pos, room_data, count)
		_:
			return _get_valid_spawn_positions(grid_pos, room_data, count)

func _get_perimeter_positions(grid_pos: Vector2i, room_data: RoomData, count: int) -> Array[Vector2]:
	var origin = _grid_to_tile_origin(grid_pos)
	var mask = room_data.floor_mask
	var w = room_data.shape_width
	var h = room_data.shape_height
	var perimeter: Array[Vector2i] = []
	# Collect floor tiles exactly 2 tiles from a wall
	for y in range(h):
		for x in range(w):
			if not mask[y][x]:
				continue
			if not _has_floor_clearance(mask, x, y, w, h, 2):
				if _has_floor_clearance(mask, x, y, w, h, 1):
					perimeter.append(Vector2i(x, y))
	perimeter.shuffle()
	var result: Array[Vector2] = []
	for v in perimeter:
		if result.size() >= count:
			break
		result.append(Vector2((origin.x + v.x) * TILE_SIZE + 4, (origin.y + v.y) * TILE_SIZE + 4))
	# Fill remaining with standard positions if perimeter not large enough
	if result.size() < count:
		var extras = _get_valid_spawn_positions(grid_pos, room_data, count - result.size())
		result.append_array(extras)
	return result

func _get_row_positions(grid_pos: Vector2i, room_data: RoomData, count: int) -> Array[Vector2]:
	var origin = _grid_to_tile_origin(grid_pos)
	var mask = room_data.floor_mask
	var w = room_data.shape_width
	var h = room_data.shape_height
	# Find floor bounds
	var min_x = w
	var max_x = 0
	var min_y = h
	var max_y = 0
	for y in range(h):
		for x in range(w):
			if mask[y][x]:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	# Calculate rows and columns for even distribution
	var cols = clampi(ceili(sqrt(float(count))), 2, 8)
	var rows = ceili(float(count) / float(cols))
	var result: Array[Vector2] = []
	var floor_w = max_x - min_x
	var floor_h = max_y - min_y
	for r in range(rows):
		for c in range(cols):
			if result.size() >= count:
				break
			var tx = min_x + 2 + int(float(c) / float(cols) * float(floor_w - 4))
			var ty = min_y + 2 + int(float(r) / float(rows) * float(floor_h - 4))
			tx = clampi(tx, min_x + 1, max_x - 1)
			ty = clampi(ty, min_y + 1, max_y - 1)
			if ty < h and tx < w and mask[ty][tx]:
				result.append(Vector2((origin.x + tx) * TILE_SIZE + 4, (origin.y + ty) * TILE_SIZE + 4))
	if result.size() < count:
		var extras = _get_valid_spawn_positions(grid_pos, room_data, count - result.size())
		result.append_array(extras)
	return result

func _get_ring_positions(grid_pos: Vector2i, room_data: RoomData, count: int) -> Array[Vector2]:
	var center = _grid_to_world_center(grid_pos)
	var origin = _grid_to_tile_origin(grid_pos)
	var mask = room_data.floor_mask
	var w = room_data.shape_width
	var h = room_data.shape_height
	var radius_x = (w - 4) * TILE_SIZE * 0.35
	var radius_y = (h - 4) * TILE_SIZE * 0.35
	var result: Array[Vector2] = []
	for i in range(count):
		var angle = TAU * float(i) / float(count)
		var pos = center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
		# Verify on floor
		var tile_x = int(pos.x / TILE_SIZE) - origin.x
		var tile_y = int(pos.y / TILE_SIZE) - origin.y
		if tile_x >= 0 and tile_x < w and tile_y >= 0 and tile_y < h and mask[tile_y][tile_x]:
			result.append(pos)
		else:
			result.append(center + Vector2(randf_range(-16, 16), randf_range(-16, 16)))
	return result

func _get_loy_enemy_pool() -> Array:
	if not current_level or current_level.monster_pool.size() == 0:
		return []
	return current_level.monster_pool

## Pick boss phase attacks based on the enemy's base attack type.
## Each archetype gets a unique escalation path so bosses feel distinct.
func _get_boss_phase_attack(base_attack: EnemyDefinition.AttackType, phase: int) -> EnemyDefinition.AttackType:
	match base_attack:
		EnemyDefinition.AttackType.MELEE, EnemyDefinition.AttackType.CHARGE, EnemyDefinition.AttackType.DASH:
			# Melee bosses: slam → charge patterns → nova explosion
			if phase == 2:
				return EnemyDefinition.AttackType.SHOTGUN_BLAST
			return EnemyDefinition.AttackType.NOVA
		EnemyDefinition.AttackType.RANGED:
			# Archer bosses: burst fire → gatling barrage
			if phase == 2:
				return EnemyDefinition.AttackType.BURST
			return EnemyDefinition.AttackType.GATLING
		EnemyDefinition.AttackType.BURST:
			# Burst bosses: cross shot → meteor shower
			if phase == 2:
				return EnemyDefinition.AttackType.CROSS_SHOT
			return EnemyDefinition.AttackType.METEOR_SHOWER
		EnemyDefinition.AttackType.SPIRAL:
			# Spiral bosses: helix → minefield
			if phase == 2:
				return EnemyDefinition.AttackType.HELIX
			return EnemyDefinition.AttackType.MINEFIELD
		EnemyDefinition.AttackType.SUMMON:
			# Summoner bosses: volley → zigzag
			if phase == 2:
				return EnemyDefinition.AttackType.VOLLEY
			return EnemyDefinition.AttackType.ZIGZAG
		EnemyDefinition.AttackType.BEAM:
			# Beam bosses: spiral → boomerang
			if phase == 2:
				return EnemyDefinition.AttackType.SPIRAL
			return EnemyDefinition.AttackType.BOOMERANG_SHOT
		_:
			# Default: nova → spiral
			if phase == 2:
				return EnemyDefinition.AttackType.NOVA
			return EnemyDefinition.AttackType.SPIRAL

func _is_bomb_attack_type(atk: EnemyDefinition.AttackType) -> bool:
	return atk in [
		EnemyDefinition.AttackType.BOMB_TOSS, EnemyDefinition.AttackType.CARPET_BOMB,
		EnemyDefinition.AttackType.FIRE_RAIN, EnemyDefinition.AttackType.CLUSTER_BOMB,
		EnemyDefinition.AttackType.MINE_DROP, EnemyDefinition.AttackType.ARTILLERY,
		EnemyDefinition.AttackType.POISON_CLOUD, EnemyDefinition.AttackType.VOLLEY,
		EnemyDefinition.AttackType.MORTAR, EnemyDefinition.AttackType.METEOR_SHOWER,
	]

func _get_weakest_enemy(loy_pool: Array, biome_pool: Array) -> EnemyDefinition:
	# Find the enemy with lowest max_hp from available pools
	var weakest: EnemyDefinition = null
	# Check loy_pool first (level monster_pool)
	for entry in loy_pool:
		var def = _load_enemy_by_name(str(entry.get("type", "")))
		if def and (not weakest or def.max_hp < weakest.max_hp):
			weakest = def
	# Fallback to biome pool
	if not weakest:
		for def in biome_pool:
			if not weakest or def.max_hp < weakest.max_hp:
				weakest = def
	return weakest

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
	for path in ResourceRegistry.enemies():
		var base = path.get_file().get_basename().to_lower()
		if not _enemy_path_index.has(base):
			_enemy_path_index[base] = path
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
			var gold = int(5 + run_state.current_floor * 2 * randf_range(0.8, 1.2))
			# Apply gold multiplier from events (Lucky blessing)
			if events:
				gold = int(gold * events.get_gold_mult())
			# Spawn visible gold pickups instead of silent add
			var center = _grid_to_world_center(grid_pos)
			var pickup_scene_gold = preload("res://scenes/pickup.tscn")
			var gold_count = randi_range(3, 5)
			var per_gold = gold / gold_count
			var remainder = gold - per_gold * gold_count
			for gi in range(gold_count):
				var gp = pickup_scene_gold.instantiate()
				gp.gold_amount = per_gold + (remainder if gi == gold_count - 1 else 0)
				gp.global_position = center + Vector2(randf_range(-12, 12), randf_range(-12, 12))
				add_child(gp)
			# Room cleared SFX + VFX celebration
			var sfx_rc = get_node_or_null("/root/SFXManager")
			var vfx_rc = get_node_or_null("/root/VFXManager")
			var is_boss = room_data.type == RoomData.RoomType.BOSS
			if sfx_rc:
				if is_boss:
					sfx_rc.play("1up_b", 0.0, 0.0)
				else:
					sfx_rc.play("ding", -3.0, 0.0)
			if vfx_rc:
				vfx_rc.gold_sparkle(center)
				if is_boss:
					vfx_rc.shake(4.0, 0.3)
				else:
					vfx_rc.shake(2.0, 0.15)
			# FloatingText celebration
			if is_boss:
				FloatingText.spawn(self, center, "BOSS DEFEATED!", Color(1.0, 0.85, 0.2))
			else:
				FloatingText.spawn(self, center, "Room Cleared!", Color(1.0, 0.9, 0.4))

			# Trigger dungeon events
			if events:
				events.on_room_cleared(grid_pos, room_data)

			# Spawn key if room has KEY_LOCKED transitions
			if room_data.keys_needed > 0:
				_spawn_key_pickup(grid_pos)

			# Notify quest system of boss kills
			if room_data.type == RoomData.RoomType.BOSS:
				var qm = get_node_or_null("/root/QuestManager")
				if qm and current_level:
					var boss_name = current_level.legend if current_level.legend != "" else starting_biome_name + " Boss"
					qm.on_boss_killed(boss_name)
					print("Dungeon: Boss '%s' defeated on floor %d" % [boss_name, run_state.current_floor])
				# Final boss: spawn a town portal instead of using stairs
				if run_state.current_floor >= get_total_floors():
					_spawn_boss_portal(grid_pos)

func _spawn_boss_portal(grid_pos: Vector2i) -> void:
	var center = _grid_to_world_center(grid_pos)
	var portal_item = load("res://resources/items/loy/town_portal.tres") as EquipmentItem
	if not portal_item:
		print("WARNING: Could not load town_portal.tres")
		return
	var bag = LootBag.new()
	bag.items.append(portal_item.make_copy())
	bag.position = center
	add_child(bag)
	# Portal spawn SFX
	var sfx_p = get_node_or_null("/root/SFXManager")
	if sfx_p:
		sfx_p.play("teleport", -2.0, 0.0)
	var vfx_p = get_node_or_null("/root/VFXManager")
	if vfx_p:
		vfx_p.shockwave(center, 24.0, Color(0.3, 0.5, 1.0, 0.6))
	print("Dungeon: Town Portal dropped at boss room %s" % str(grid_pos))

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
	var sfx_k = get_node_or_null("/root/SFXManager")
	if sfx_k:
		sfx_k.play("unlock", -3.0, 0.0)
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

func _on_stairs_proximity(body: Node2D, trigger: Area2D, entered: bool) -> void:
	if not body.is_in_group("player"):
		return
	if entered:
		_nearby_stairs = trigger
		_show_stairs_prompt(trigger)
		if TouchControls.is_mobile():
			var tc = get_tree().get_first_node_in_group("touch_controls") as TouchControls
			if tc:
				var label = "Ascend" if trigger.is_in_group("stairs_up_trigger") else "Descend"
				tc.show_interact_button(label)
	else:
		if _nearby_stairs == trigger:
			_nearby_stairs = null
			_hide_stairs_prompt()
			if TouchControls.is_mobile():
				var tc = get_tree().get_first_node_in_group("touch_controls") as TouchControls
				if tc:
					tc.hide_interact_button()

func _show_stairs_prompt(trigger: Area2D) -> void:
	_hide_stairs_prompt()
	_interact_prompt = Label.new()
	_interact_prompt.text = "Tap" if TouchControls.is_mobile() else "Press E"
	_interact_prompt.add_theme_font_size_override("font_size", 6)
	_interact_prompt.add_theme_color_override("font_color", Color.WHITE)
	_interact_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_prompt.position = trigger.position + Vector2(-16, -12)
	add_child(_interact_prompt)

func _hide_stairs_prompt() -> void:
	if _interact_prompt and is_instance_valid(_interact_prompt):
		_interact_prompt.queue_free()
		_interact_prompt = null

func _go_prev_floor() -> void:
	var sfx_f = get_node_or_null("/root/SFXManager")
	if sfx_f:
		sfx_f.play("step", -4.0, 0.0)
	run_state.current_floor -= 1
	current_level = _get_level_for_floor(run_state.current_floor)
	current_biome = _get_biome_for_floor(run_state.current_floor)
	# Flag so start room gets stairs down when floor is generated
	_add_stairs_down_to_start = true
	_generate_floor(run_state.current_floor)
	floor_changed.emit(run_state.current_floor)

func get_total_floors() -> int:
	if dungeon_levels.size() > 0:
		return dungeon_levels.size()
	if current_biome and current_biome.floor_count > 1:
		return current_biome.floor_count
	return 5  # default fallback

func _go_next_floor() -> void:
	var sfx_nf = get_node_or_null("/root/SFXManager")
	if sfx_nf:
		sfx_nf.play("step", -4.0, 0.0)
	run_state.current_floor += 1
	run_state.floors_cleared += 1

	# Check if dungeon is complete
	if run_state.current_floor > get_total_floors():
		run_state.end_time = Time.get_ticks_msec()
		if sfx_nf:
			sfx_nf.play("1up_b", 0.0, 0.0)
		run_ended.emit(run_state)
		return

	current_level = _get_level_for_floor(run_state.current_floor)
	current_biome = _get_biome_for_floor(run_state.current_floor)
	_generate_floor(run_state.current_floor)
	floor_changed.emit(run_state.current_floor)

func _spawn_chest_loot(grid_pos: Vector2i) -> void:
	var sfx_ch = get_node_or_null("/root/SFXManager")
	if sfx_ch:
		sfx_ch.play("bay_door_open", -3.0, 0.1)
	var center = _grid_to_world_center(grid_pos)
	var pickup_scene = preload("res://scenes/pickup.tscn")
	var bd = current_biome.base_difficulty if current_biome else 0

	# Use LoY loot table if available
	if current_level and current_level.chest_loot.size() > 0:
		var chest_def = current_level.chest_loot[0]
		var min_items = int(chest_def.get("min_items", 1))
		var max_items = int(chest_def.get("max_items", 2))
		var item_count = randi_range(min_items, max_items)
		var loy_pool = chest_def.get("items", []) as Array

		if loy_pool.size() > 0:
			for i in range(item_count):
				var rolled_item = _roll_chest_item(loy_pool)
				if rolled_item == "":
					continue
				if rolled_item == "Gold":
					var entry = _find_pool_entry(loy_pool, "Gold")
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
				pickup.item = item.make_copy()
				var offset = Vector2(randf_range(-16, 16), randf_range(-16, 16))
				pickup.global_position = center + offset
				add_child(pickup)
			# 40% chance to also drop a crafting material from LoY chests
			if _item_pool and randf() < 0.4:
				var mat = _item_pool.get_crafting_material(run_state.current_floor)
				if mat:
					var mat_pickup = pickup_scene.instantiate()
					mat_pickup.item = mat.make_copy()
					var mat_offset = Vector2(randf_range(-16, 16), randf_range(-16, 16))
					mat_pickup.global_position = center + mat_offset
					add_child(mat_pickup)
			# Bonus equipment on early floors
			_spawn_chest_bonus_equipment(center, pickup_scene, bd)
			return

	# Fallback: generate level-appropriate random items + gold
	var gold_amount = int(8 + (run_state.current_floor + bd) * 3)
	run_state.run_gold += gold_amount

	if _item_pool:
		var item_count = randi_range(1, 2)
		var items = _item_pool.get_random_items(item_count, run_state.current_floor, bd)
		for item in items:
			var pickup = pickup_scene.instantiate()
			pickup.item = item.make_copy()
			var offset = Vector2(randf_range(-16, 16), randf_range(-16, 16))
			pickup.global_position = center + offset
			add_child(pickup)

		# 40% chance to also drop a crafting material
		if randf() < 0.4:
			var mat = _item_pool.get_crafting_material(run_state.current_floor)
			if mat:
				var mat_pickup = pickup_scene.instantiate()
				mat_pickup.item = mat.make_copy()
				var mat_offset = Vector2(randf_range(-16, 16), randf_range(-16, 16))
				mat_pickup.global_position = center + mat_offset
				add_child(mat_pickup)

	# Bonus equipment on early floors
	_spawn_chest_bonus_equipment(center, pickup_scene, bd)

func _spawn_chest_bonus_equipment(center: Vector2, pickup_scene: PackedScene, bd: int) -> void:
	if not _item_pool or run_state.current_floor > 3:
		return
	var bonus = _item_pool.get_random_items(1, run_state.current_floor, bd)
	for item in bonus:
		var pickup = pickup_scene.instantiate()
		pickup.item = item.make_copy()
		pickup.global_position = center + Vector2(randf_range(-16, 16), randf_range(-16, 16))
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
