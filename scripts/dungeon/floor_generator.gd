class_name FloorGenerator
extends RefCounted

# Generate a floor as a dictionary of grid_pos -> RoomData
# Returns: { "rooms": Dictionary (Vector2i -> RoomData), "start": Vector2i, "stairs": Vector2i }
static func generate_floor_map(floor_number: int, room_override: int = -1, biome: DungeonBiome = null, total_floors: int = 5) -> Dictionary:
	var room_count: int
	if room_override > 0:
		room_count = mini(room_override, 40)
	else:
		room_count = 12 + floor_number * 2 + randi() % 5
		room_count = mini(room_count, 35)

	var directions = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

	# Generate layout using branching random walk
	var positions: Array[Vector2i] = []
	var position_set: Dictionary = {}  # fast lookup
	var start_pos = Vector2i.ZERO
	positions.append(start_pos)
	position_set[start_pos] = true

	# Phase 1: Main path (60% of rooms) — creates the critical path
	var main_path_count = int(room_count * 0.6)
	var current = start_pos
	for _i in range(main_path_count - 1):
		var placed = false
		for _attempt in range(10):
			var dir = directions[randi() % 4]
			var next = current + dir
			if not position_set.has(next):
				positions.append(next)
				position_set[next] = true
				current = next
				placed = true
				break
		if not placed:
			# Stuck — jump to a random existing position and branch from there
			current = positions[randi() % positions.size()]

	# Phase 2: Branch paths (remaining rooms) — creates dead ends and alternate routes
	var branches_remaining = room_count - positions.size()
	var branch_starts: Array[Vector2i] = []
	# Pick 3-5 branch points along the existing layout
	var num_branches = clampi(branches_remaining / 3, 2, 5)
	for _b in range(num_branches):
		branch_starts.append(positions[randi() % positions.size()])

	for branch_root in branch_starts:
		if positions.size() >= room_count:
			break
		current = branch_root
		var branch_len = randi_range(2, maxi(2, branches_remaining / num_branches + 1))
		for _step in range(branch_len):
			if positions.size() >= room_count:
				break
			var placed = false
			for _attempt in range(10):
				var dir = directions[randi() % 4]
				var next = current + dir
				if not position_set.has(next):
					positions.append(next)
					position_set[next] = true
					current = next
					placed = true
					break
			if not placed:
				break  # dead end, stop this branch

	# Phase 3: Fill remaining rooms by sprouting off random positions
	while positions.size() < room_count:
		var root = positions[randi() % positions.size()]
		var placed = false
		for _attempt in range(10):
			var dir = directions[randi() % 4]
			var next = root + dir
			if not position_set.has(next):
				positions.append(next)
				position_set[next] = true
				placed = true
				break
		if not placed:
			break  # can't place more

	# Phase 4: Add loop connections (15% chance for adjacent non-connected rooms)
	# This creates alternate routes so the player isn't stuck on one path

	# Find stairs — farthest room from start using BFS distance
	var stairs_pos = start_pos
	var bfs_dist: Dictionary = {}
	bfs_dist[start_pos] = 0
	var bfs_queue: Array[Vector2i] = [start_pos]
	var bfs_idx = 0
	while bfs_idx < bfs_queue.size():
		var pos = bfs_queue[bfs_idx]
		bfs_idx += 1
		for dir in directions:
			var neighbor = pos + dir
			if position_set.has(neighbor) and not bfs_dist.has(neighbor):
				bfs_dist[neighbor] = bfs_dist[pos] + 1
				bfs_queue.append(neighbor)
				if bfs_dist[neighbor] > bfs_dist.get(stairs_pos, 0):
					stairs_pos = neighbor

	# Build rooms
	var rooms: Dictionary = {}
	for i in range(positions.size()):
		var pos = positions[i]
		var room = RoomData.new()
		room.grid_pos = pos

		if pos == start_pos:
			room.type = RoomData.RoomType.COMBAT
			room.enemy_count = 0  # entrance room is safe — no enemies
			room.has_stairs_up = true  # start room always has stairs up
		elif pos == stairs_pos:
			room.has_stairs_down = true
			if floor_number >= total_floors:
				# Final floor: true area boss
				room.type = RoomData.RoomType.BOSS
				room.enemy_count = 1
			else:
				room.type = RoomData.RoomType.ELITE
				room.enemy_count = 2
		else:
			room.type = _roll_room_type(floor_number)
			match room.type:
				RoomData.RoomType.COMBAT:
					room.enemy_count = 5 + floor_number * 2
				RoomData.RoomType.ELITE:
					room.enemy_count = 3
				RoomData.RoomType.TREASURE, RoomData.RoomType.SHRINE:
					room.enemy_count = 3 + floor_number  # guarded reward rooms
				_:
					room.enemy_count = 0

		room.difficulty_tier = floor_number
		var base_diff = biome.base_difficulty if biome else 0
		var effective_floor = floor_number + base_diff
		var hp_mult = 1.0 + (effective_floor - 1) * 0.15
		var dmg_mult = 1.0 + (effective_floor - 1) * 0.1
		if room.type == RoomData.RoomType.BOSS:
			hp_mult *= 5.0
			dmg_mult *= 2.0
		elif room.type == RoomData.RoomType.ELITE:
			hp_mult *= 3.0
			dmg_mult *= 1.5
		room.enemy_hp_mult = hp_mult
		room.enemy_damage_mult = dmg_mult

		# Assign room shape
		room.shape = _roll_room_shape(room.type, pos == start_pos)
		var shape_data = RoomShapeGenerator.generate_shape(room.shape)
		room.shape_width = shape_data["width"]
		room.shape_height = shape_data["height"]
		room.floor_mask = shape_data["mask"]

		# Build connections to ALL adjacent rooms (including loop connections)
		for dir in directions:
			var neighbor = pos + dir
			if position_set.has(neighbor):
				var dir_name = _dir_to_name(dir)
				room.connections[dir_name] = neighbor

		# Assign transition types per connection
		# POC: Force all transitions OPEN — KEY_LOCKED/BREAKABLE systems need polish
		for dir_name in room.connections:
			room.transition_types[dir_name] = RoomData.TransitionType.OPEN

		# 10% of combat rooms become dirt rooms
		if room.type == RoomData.RoomType.COMBAT and pos != start_pos and randf() < 0.10:
			room.is_dirt_room = true

		rooms[pos] = room

	# Ensure start→stairs path is fully reachable (all OPEN transitions)
	_ensure_reachable_path(rooms, start_pos, stairs_pos, directions)

	return { "rooms": rooms, "start": start_pos, "stairs": stairs_pos }

# Legacy function for backwards compatibility
static func generate_floor(floor_number: int) -> Array[RoomData]:
	var map = generate_floor_map(floor_number)
	var rooms_dict = map["rooms"] as Dictionary
	var result: Array[RoomData] = []
	for pos in rooms_dict:
		result.append(rooms_dict[pos])
	return result

static func _dir_to_name(dir: Vector2i) -> String:
	if dir == Vector2i(0, -1): return "north"
	if dir == Vector2i(0, 1): return "south"
	if dir == Vector2i(-1, 0): return "west"
	if dir == Vector2i(1, 0): return "east"
	return ""

static func _roll_room_type(floor_number: int) -> RoomData.RoomType:
	var roll = randf()
	# Higher floors = more combat, less free loot
	var combat_chance = 0.60 + floor_number * 0.02  # 60% base, grows per floor
	combat_chance = minf(combat_chance, 0.80)
	var elite_chance = 0.05 + floor_number * 0.01  # elites more common deeper
	elite_chance = minf(elite_chance, 0.12)
	if roll < combat_chance:
		return RoomData.RoomType.COMBAT
	elif roll < combat_chance + 0.10:
		return RoomData.RoomType.TREASURE
	elif roll < combat_chance + 0.18:
		return RoomData.RoomType.SHRINE
	elif roll < combat_chance + 0.22:
		return RoomData.RoomType.SHOP
	else:
		return RoomData.RoomType.ELITE

static func _roll_room_shape(room_type: RoomData.RoomType, is_start: bool) -> RoomData.RoomShape:
	if is_start:
		return RoomData.RoomShape.RECTANGLE
	match room_type:
		RoomData.RoomType.SHOP:
			return RoomData.RoomShape.RECTANGLE
		RoomData.RoomType.BOSS:
			var shapes = [
				RoomData.RoomShape.CIRCLE,
				RoomData.RoomShape.WIDE_RECT,
				RoomData.RoomShape.RECTANGLE,
			]
			return shapes[randi() % shapes.size()]
		RoomData.RoomType.TREASURE, RoomData.RoomType.SHRINE:
			var shapes = [
				RoomData.RoomShape.CIRCLE,
				RoomData.RoomShape.RECTANGLE,
			]
			return shapes[randi() % shapes.size()]
		_:
			var all_shapes = [
				RoomData.RoomShape.RECTANGLE,
				RoomData.RoomShape.WIDE_RECT,
				RoomData.RoomShape.TALL_RECT,
				RoomData.RoomShape.CIRCLE,
				RoomData.RoomShape.L_SHAPE_NE,
				RoomData.RoomShape.L_SHAPE_NW,
				RoomData.RoomShape.L_SHAPE_SE,
				RoomData.RoomShape.L_SHAPE_SW,
				RoomData.RoomShape.IRREGULAR,
			]
			return all_shapes[randi() % all_shapes.size()]

static func _roll_transition_type(room_type: RoomData.RoomType, is_start: bool, biome: DungeonBiome) -> RoomData.TransitionType:
	if is_start:
		return RoomData.TransitionType.OPEN
	match room_type:
		RoomData.RoomType.TREASURE, RoomData.RoomType.SHRINE, RoomData.RoomType.SHOP:
			return RoomData.TransitionType.OPEN
		_:
			pass

	# 75% chance OPEN, 25% chance non-open transition
	if randf() < 0.75:
		return RoomData.TransitionType.OPEN

	var allowed: Array[int] = [1, 2, 3]  # non-open types
	if biome and biome.allowed_transitions.size() > 0:
		allowed = []
		for t in biome.allowed_transitions:
			if t != 0:  # skip OPEN, already handled above
				allowed.append(t)

	if allowed.size() == 0:
		return RoomData.TransitionType.OPEN

	var pick = allowed[randi() % allowed.size()]
	return pick as RoomData.TransitionType

static func _ensure_reachable_path(rooms: Dictionary, start: Vector2i, stairs: Vector2i, directions: Array) -> void:
	# BFS from start to stairs — find shortest path through room connections
	var came_from: Dictionary = {}
	came_from[start] = start
	var queue: Array[Vector2i] = [start]
	var idx = 0
	while idx < queue.size():
		var pos = queue[idx]
		idx += 1
		if pos == stairs:
			break
		var room = rooms[pos] as RoomData
		for dir_name in room.connections:
			var neighbor = room.connections[dir_name]
			if not came_from.has(neighbor):
				came_from[neighbor] = pos
				queue.append(neighbor)

	if not came_from.has(stairs):
		# Shouldn't happen with a connected grid, but bail safely
		return

	# Trace path back from stairs to start and force all transitions OPEN
	var current = stairs
	while current != start:
		var prev = came_from[current]
		# Force transition from prev→current to OPEN
		var room_prev = rooms[prev] as RoomData
		for dir_name in room_prev.connections:
			if room_prev.connections[dir_name] == current:
				room_prev.transition_types[dir_name] = RoomData.TransitionType.OPEN
		# Force reverse transition current→prev to OPEN
		var room_curr = rooms[current] as RoomData
		for dir_name in room_curr.connections:
			if room_curr.connections[dir_name] == prev:
				room_curr.transition_types[dir_name] = RoomData.TransitionType.OPEN
		current = prev
