class_name DungeonNav
extends RefCounted

## A* navigation grid for dungeon enemies.
## Built from floor tiles; enemies query get_next_position() for pathfinding.

var _astar: AStarGrid2D
var _region: Rect2i
var _ready: bool = false

func build(floor_layer: TileMapLayer, deco_layer: TileMapLayer, solid_deco_rows: Array) -> void:
	var floor_cells = floor_layer.get_used_cells()
	if floor_cells.is_empty():
		return

	# Find bounding rect of all floor tiles
	var min_x: int = 999999
	var max_x: int = -999999
	var min_y: int = 999999
	var max_y: int = -999999
	var floor_set: Dictionary = {}
	for cell in floor_cells:
		floor_set[cell] = true
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)

	# Build solid deco set
	var solid_set: Dictionary = {}
	for cell in deco_layer.get_used_cells():
		var data = deco_layer.get_cell_atlas_coords(cell)
		if data.y in solid_deco_rows:
			solid_set[cell] = true

	_region = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

	_astar = AStarGrid2D.new()
	_astar.region = _region
	_astar.cell_size = Vector2(8, 8)  # TILE_SIZE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()

	# Mark all non-floor cells and solid deco cells as solid (unwalkable)
	for y in range(_region.position.y, _region.end.y):
		for x in range(_region.position.x, _region.end.x):
			var cell = Vector2i(x, y)
			if not floor_set.has(cell) or solid_set.has(cell):
				_astar.set_point_solid(cell, true)

	_ready = true

func is_ready() -> bool:
	return _ready

## Convert world position to grid cell
func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / 8.0)), int(floor(world_pos.y / 8.0)))

## Convert grid cell to world center
func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * 8.0 + 4.0, cell.y * 8.0 + 4.0)

## Get the next world position to move toward on the path from `from` to `to`.
## Returns the position of the next cell on the A* path (not final target).
## If no path found, returns `to` as fallback (direct chase).
func get_next_position(from_world: Vector2, to_world: Vector2) -> Vector2:
	if not _ready:
		return to_world

	var from_cell = world_to_cell(from_world)
	var to_cell = world_to_cell(to_world)

	# Clamp to grid bounds
	from_cell = _clamp_cell(from_cell)
	to_cell = _clamp_cell(to_cell)

	# If either cell is solid, find nearest walkable cell
	if _astar.is_point_solid(from_cell):
		from_cell = _find_nearest_walkable(from_cell)
	if _astar.is_point_solid(to_cell):
		to_cell = _find_nearest_walkable(to_cell)

	if from_cell == to_cell:
		return to_world

	var path = _astar.get_point_path(from_cell, to_cell)
	if path.size() < 2:
		return to_world  # no path or already there

	# Return the world position of the next cell (index 1, since 0 is current)
	# Skip ahead a bit if path is long to avoid jittery movement
	var look_ahead = mini(2, path.size() - 1)
	return path[look_ahead]

func _clamp_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(cell.x, _region.position.x, _region.end.x - 1),
		clampi(cell.y, _region.position.y, _region.end.y - 1)
	)

func _find_nearest_walkable(cell: Vector2i) -> Vector2i:
	# Spiral search outward for nearest non-solid cell
	for radius in range(1, 10):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue  # only check perimeter
				var test = cell + Vector2i(dx, dy)
				if _region.has_point(test) and not _astar.is_point_solid(test):
					return test
	return cell  # fallback
