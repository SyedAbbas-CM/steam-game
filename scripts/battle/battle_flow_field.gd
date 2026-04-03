class_name BattleFlowField
extends RefCounted

## Precomputed flow fields for battle navigation.
## BFS from a destination tile floods the entire reachable map ONCE.
## Every tile stores a direction vector toward the destination.
## Unit lookup is O(1) — just read the direction for your tile.
##
## Supports multiple named fields (e.g. "red_objective", "blue_objective").
## Recompute a field when the destination changes.

const TILE_SIZE := 32

var _blocked_tiles: Dictionary = {}
var _tile_region: Rect2i

# flow_fields[name] = { "dest": Vector2i, "dirs": Dictionary }
# dirs[Vector2i] = Vector2 (normalized direction toward destination)
var _flow_fields: Dictionary = {}

func setup(blocked_tiles: Dictionary, tile_region: Rect2i) -> void:
	_blocked_tiles = blocked_tiles
	_tile_region = tile_region

func is_valid() -> bool:
	return not _blocked_tiles.is_empty()

func is_blocked(wx: float, wy: float) -> bool:
	return _blocked_tiles.has(Vector2i(int(floor(wx / TILE_SIZE)), int(floor(wy / TILE_SIZE))))

func is_blocked_tile(tx: int, ty: int) -> bool:
	return _blocked_tiles.has(Vector2i(tx, ty))

func has_line_of_sight(x1: float, y1: float, x2: float, y2: float) -> bool:
	## Tile-stepping raycast between two points.
	var dx := x2 - x1
	var dy := y2 - y1
	var dist := sqrt(dx * dx + dy * dy)
	if dist < 1.0:
		return true
	var steps := int(ceil(dist / 16.0))
	var sx := dx / float(steps)
	var sy := dy / float(steps)
	for i in range(1, steps):
		if is_blocked(x1 + sx * float(i), y1 + sy * float(i)):
			return false
	return true

# --- Flow field computation (BFS) ---

func compute_field(field_name: String, dest_world: Vector2) -> void:
	## BFS from dest_world position. Stores a direction vector per tile.
	## Call this once at battle start and whenever the objective moves significantly.
	var dest_tile := Vector2i(int(floor(dest_world.x / TILE_SIZE)), int(floor(dest_world.y / TILE_SIZE)))

	# If destination blocked, find nearest clear tile
	if _blocked_tiles.has(dest_tile):
		dest_tile = _find_nearest_clear_tile(dest_tile)
		if dest_tile == Vector2i(-9999, -9999):
			return

	# Check if this field already exists with same destination
	if _flow_fields.has(field_name):
		var existing: Dictionary = _flow_fields[field_name]
		if existing.get("dest", Vector2i(-9999, -9999)) == dest_tile:
			return  # Already computed for this destination

	var dirs: Dictionary = {}
	var came_from: Dictionary = {}  # tile -> parent tile (for direction computation)

	# BFS queue — use array as deque (append back, pop front)
	var queue: Array[Vector2i] = [dest_tile]
	came_from[dest_tile] = dest_tile  # destination points to itself
	dirs[dest_tile] = Vector2.ZERO  # at destination, no direction needed

	var neighbors := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]

	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1

		for n_off in neighbors:
			var neighbor: Vector2i = current + n_off
			if came_from.has(neighbor) or _blocked_tiles.has(neighbor):
				continue

			# Diagonal: prevent corner cutting
			if n_off.x != 0 and n_off.y != 0:
				if _blocked_tiles.has(Vector2i(neighbor.x - n_off.x, neighbor.y)) or \
				   _blocked_tiles.has(Vector2i(neighbor.x, neighbor.y - n_off.y)):
					continue

			# Skip tiles far outside the battle region (with margin)
			if neighbor.x < _tile_region.position.x - 5 or neighbor.x > _tile_region.end.x + 5 \
				or neighbor.y < _tile_region.position.y - 5 or neighbor.y > _tile_region.end.y + 5:
				continue

			came_from[neighbor] = current
			# Direction: from neighbor TOWARD current (which is closer to dest)
			var dir := Vector2(float(current.x - neighbor.x), float(current.y - neighbor.y)).normalized()
			dirs[neighbor] = dir
			queue.append(neighbor)

	_flow_fields[field_name] = {"dest": dest_tile, "dirs": dirs}
	print("FlowField: computed '%s' dest=(%d,%d) tiles=%d" % [field_name, dest_tile.x, dest_tile.y, dirs.size()])

func get_flow_direction(field_name: String, world_x: float, world_y: float) -> Vector2:
	## O(1) lookup: get the precomputed direction for a unit at (world_x, world_y).
	## Returns Vector2.ZERO if no field or tile not reachable.
	if not _flow_fields.has(field_name):
		return Vector2.ZERO
	var field: Dictionary = _flow_fields[field_name]
	var tile := Vector2i(int(floor(world_x / TILE_SIZE)), int(floor(world_y / TILE_SIZE)))
	var dirs: Dictionary = field["dirs"]
	if dirs.has(tile):
		return dirs[tile]
	return Vector2.ZERO

func has_field(field_name: String) -> bool:
	return _flow_fields.has(field_name)

# --- Local avoidance (for last-mile fine movement) ---

func get_avoidance_dir(unit_x: float, unit_y: float, move_dir: Vector2, _look_ahead: float = 48.0) -> Vector2:
	## Local nudge for last-mile — steers around immediate obstacles.
	if move_dir.length_squared() < 0.001:
		return Vector2.ZERO
	var nd := move_dir.normalized()

	if is_blocked(unit_x, unit_y):
		return _escape_blocked_tile(unit_x, unit_y, nd)

	# Check ahead
	if not is_blocked(unit_x + nd.x * 40.0, unit_y + nd.y * 40.0):
		return nd

	# Blocked ahead — try wider angles
	for angle_deg in [25.0, 45.0, 70.0, 90.0, 120.0, 150.0, 170.0]:
		var rad := deg_to_rad(angle_deg)
		for sign_v in [1.0, -1.0]:
			var test := nd.rotated(rad * sign_v)
			if not is_blocked(unit_x + test.x * 40.0, unit_y + test.y * 40.0):
				if not is_blocked(unit_x + test.x * 20.0, unit_y + test.y * 20.0):
					return test
	return -nd

func _escape_blocked_tile(unit_x: float, unit_y: float, preferred_dir: Vector2) -> Vector2:
	var best_dir := -preferred_dir
	var best_score := 999.0
	for d in [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1),
			  Vector2(0.707,0.707), Vector2(-0.707,0.707), Vector2(0.707,-0.707), Vector2(-0.707,-0.707)]:
		for step in [12.0, 24.0, 36.0, 48.0]:
			var test_x: float = unit_x + d.x * step
			var test_y: float = unit_y + d.y * step
			if not is_blocked(test_x, test_y):
				var alignment: float = d.dot(preferred_dir)
				var score: float = step - alignment * 15.0
				if score < best_score:
					best_score = score
					best_dir = d
				break
	return best_dir.normalized()

func _find_nearest_clear_tile(tile: Vector2i) -> Vector2i:
	for dist in range(1, 10):
		for dx in range(-dist, dist + 1):
			for dy in range(-dist, dist + 1):
				if absi(dx) != dist and absi(dy) != dist:
					continue
				var check := Vector2i(tile.x + dx, tile.y + dy)
				if not _blocked_tiles.has(check):
					return check
	return Vector2i(-9999, -9999)
