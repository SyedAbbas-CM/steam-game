class_name DungeonNav
extends RefCounted

## Flow-field navigation for dungeon enemies.
## One BFS from the player position, all enemies look up their move direction.
## Recomputed when player moves significantly (every few seconds).

var _region: Rect2i
var _ready: bool = false
var _walkable: Dictionary = {}  # Vector2i -> true for walkable cells

# Optional height-system reference. When set, neighbor transitions across cliff
# boundaries (height differs and neither cell is a ramp) are blocked so enemies
# path around plateaus instead of through them.
var _height_system: Node = null

# Flow field: each cell stores the direction toward the player
var _flow: Dictionary = {}  # Vector2i -> Vector2 (normalized direction)
var _last_target_cell: Vector2i = Vector2i(-99999, -99999)

const TILE_SIZE := 8.0
const REBUILD_DIST := 3  # rebuild flow field when player moves 3+ cells

# Neighbors: 8 directions (cardinal + diagonal)
const DIRS = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]

func set_height_system(hs: Node) -> void:
	_height_system = hs

func _can_traverse(a: Vector2i, b: Vector2i) -> bool:
	if _height_system == null or not is_instance_valid(_height_system):
		return true
	var ha: int = int(_height_system.get_height(a))
	var hb: int = int(_height_system.get_height(b))
	if ha == hb:
		return true
	# Height differs — only passable if either side is a ramp tile.
	return bool(_height_system.is_ramp(a)) or bool(_height_system.is_ramp(b))

func build(floor_layer: TileMapLayer, deco_layer: TileMapLayer, solid_deco_rows: Array) -> void:
	var floor_cells = floor_layer.get_used_cells()
	if floor_cells.is_empty():
		return

	var min_x: int = 999999
	var max_x: int = -999999
	var min_y: int = 999999
	var max_y: int = -999999

	for cell in floor_cells:
		_walkable[cell] = true
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)

	# Remove solid decorations from walkable set
	for cell in deco_layer.get_used_cells():
		var data = deco_layer.get_cell_atlas_coords(cell)
		if data.y in solid_deco_rows:
			_walkable.erase(cell)

	_region = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	_ready = true

func is_ready() -> bool:
	return _ready

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / TILE_SIZE)), int(floor(world_pos.y / TILE_SIZE)))

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE * 0.5, cell.y * TILE_SIZE + TILE_SIZE * 0.5)

## Update flow field if player moved enough. Call this periodically (e.g. every 2-3s).
func update_flow_field(player_world_pos: Vector2) -> void:
	if not _ready:
		return
	var target = world_to_cell(player_world_pos)
	# Only rebuild if player moved significantly
	if abs(target.x - _last_target_cell.x) < REBUILD_DIST and abs(target.y - _last_target_cell.y) < REBUILD_DIST:
		return
	_rebuild_flow(target)

## Force rebuild (e.g. on floor enter)
func force_update(player_world_pos: Vector2) -> void:
	if not _ready:
		return
	_rebuild_flow(world_to_cell(player_world_pos))

## BFS from target cell, fill _flow with directions pointing toward target
func _rebuild_flow(target: Vector2i) -> void:
	_last_target_cell = target
	_flow.clear()

	# If target is not walkable, find nearest walkable
	if not _walkable.has(target):
		target = _find_nearest_walkable(target)

	# BFS
	var dist: Dictionary = {}  # Vector2i -> int (distance from target)
	var queue: Array = []
	dist[target] = 0
	queue.push_back(target)
	_flow[target] = Vector2.ZERO  # at the target, no direction needed

	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		var d: int = dist[cell]

		for dir in DIRS:
			var nb: Vector2i = cell + dir
			if dist.has(nb):
				continue
			if not _walkable.has(nb):
				continue
			# Diagonal check: both adjacent orthogonals must be walkable AND traversable
			if dir.x != 0 and dir.y != 0:
				var ortho_a := Vector2i(cell.x + dir.x, cell.y)
				var ortho_b := Vector2i(cell.x, cell.y + dir.y)
				if not _walkable.has(ortho_a) or not _walkable.has(ortho_b):
					continue
				if not _can_traverse(cell, ortho_a) or not _can_traverse(cell, ortho_b):
					continue
			# Cliff walls block the cardinal step too
			if not _can_traverse(cell, nb):
				continue
			dist[nb] = d + 1
			# Flow points from nb TOWARD target (i.e. toward cell)
			_flow[nb] = Vector2(cell.x - nb.x, cell.y - nb.y).normalized()
			queue.push_back(nb)

## Mark a cell as walkable (e.g. after breaking a deco obstacle)
func mark_walkable(cell: Vector2i) -> void:
	_walkable[cell] = true

## Force flow field rebuild at current target (after terrain changes)
func invalidate() -> void:
	_last_target_cell = Vector2i(-99999, -99999)

## Get the flow direction at a world position. Returns normalized dir toward player.
## Returns Vector2.ZERO if no flow data (enemy is at player or unreachable).
func get_flow_direction(world_pos: Vector2) -> Vector2:
	if not _ready or _flow.is_empty():
		return Vector2.ZERO
	var cell = world_to_cell(world_pos)
	if _flow.has(cell):
		return _flow[cell]
	# Try nearby cells if slightly off-grid
	for dir in DIRS:
		var nb = cell + dir
		if _flow.has(nb):
			return _flow[nb]
	return Vector2.ZERO

## Legacy: per-enemy A* query (kept as fallback for rare cases)
func get_next_position(from_world: Vector2, to_world: Vector2) -> Vector2:
	var flow_dir = get_flow_direction(from_world)
	if flow_dir != Vector2.ZERO:
		# Return a point 2 tiles ahead in the flow direction
		return from_world + flow_dir * TILE_SIZE * 2.0
	return to_world  # fallback: direct chase

func _find_nearest_walkable(cell: Vector2i) -> Vector2i:
	for radius in range(1, 15):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var test = cell + Vector2i(dx, dy)
				if _walkable.has(test):
					return test
	return cell
