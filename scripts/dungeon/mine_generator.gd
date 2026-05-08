class_name MineGenerator
extends RefCounted

static func generate_excavation_map(floor_number: int, mine_def: MineDefinition, total_floors: int = 5) -> Dictionary:
	var room_count := randi_range(mine_def.room_count_min, mine_def.room_count_max)
	room_count = clampi(room_count, 4, 16)

	var bounds_w := maxi(4, mine_def.bounds_cells_w)
	var bounds_h := maxi(4, mine_def.bounds_cells_h)
	var start_pos := Vector2i.ZERO
	var candidate_cells := _build_candidate_cells(bounds_w, bounds_h)
	var carved_cells := _carve_excavation_cells(candidate_cells, room_count, start_pos, mine_def.carve_density_bias)
	if not carved_cells.has(start_pos):
		carved_cells[start_pos] = true

	var positions := carved_cells.keys()
	var stairs_pos := _pick_farthest_cell(start_pos, carved_cells)
	var rooms: Dictionary = {}

	for pos in positions:
		var room := RoomData.new()
		room.grid_pos = pos

		if pos == start_pos:
			room.type = RoomData.RoomType.COMBAT
			room.enemy_count = 0
			room.has_stairs_up = true
		elif pos == stairs_pos:
			room.has_stairs_down = true
			if floor_number >= total_floors:
				room.type = RoomData.RoomType.BOSS
				room.enemy_count = 1
			else:
				room.type = RoomData.RoomType.ELITE
				room.enemy_count = clampi(3 + floor_number / 3, 3, 6)
		else:
			room.type = _roll_mine_room_type(floor_number)
			match room.type:
				RoomData.RoomType.COMBAT:
					room.enemy_count = 4 + floor_number + randi_range(0, 2)
				RoomData.RoomType.ELITE:
					room.enemy_count = clampi(3 + floor_number / 3, 3, 6)
				RoomData.RoomType.SUPER_ELITE:
					room.enemy_count = clampi(2 + floor_number / 4, 2, 4)
				RoomData.RoomType.TREASURE, RoomData.RoomType.SHRINE:
					room.enemy_count = 2 + floor_number
				RoomData.RoomType.SHOP:
					room.enemy_count = 0

		room.difficulty_tier = floor_number
		room.encounter_type = RoomData.EncounterType.STANDARD
		_apply_room_scaling(room)
		_apply_room_shape(room, mine_def, pos == start_pos)
		rooms[pos] = room

	for pos in positions:
		var room := rooms[pos] as RoomData
		var degree := 0
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor = pos + dir
			if not carved_cells.has(neighbor):
				continue
			var dir_name := _dir_to_name(dir)
			room.connections[dir_name] = neighbor
			room.transition_types[dir_name] = RoomData.TransitionType.OPEN
			degree += 1
		room.set_meta("mine_degree", degree)

	_apply_mine_blockages(rooms, start_pos, stairs_pos, mine_def)
	return {
		"rooms": rooms,
		"start": start_pos,
		"stairs": stairs_pos,
		"grid_cell_w": 65,
		"grid_cell_h": 53,
		"solid_mass_mode": true,
	}

static func _build_candidate_cells(bounds_w: int, bounds_h: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(-bounds_h, bounds_h + 1):
		for x in range(-bounds_w, bounds_w + 1):
			var nx := float(x) / float(bounds_w)
			var ny := float(y) / float(bounds_h)
			if nx * nx + ny * ny <= 1.0:
				cells.append(Vector2i(x, y))
	return cells

static func _carve_excavation_cells(candidate_cells: Array[Vector2i], target_count: int, start_pos: Vector2i, density_bias: float) -> Dictionary:
	var candidate_set: Dictionary = {}
	for pos in candidate_cells:
		candidate_set[pos] = true
	var carved: Dictionary = {start_pos: true}
	var frontier: Array[Vector2i] = []
	_collect_frontier(frontier, carved, candidate_set, start_pos)

	while carved.size() < target_count and not frontier.is_empty():
		var pick_idx := _pick_frontier_index(frontier, carved, density_bias)
		var pick: Vector2i = frontier[pick_idx]
		frontier.remove_at(pick_idx)
		if carved.has(pick):
			continue
		carved[pick] = true
		_collect_frontier(frontier, carved, candidate_set, pick)

	return carved

static func _collect_frontier(frontier: Array[Vector2i], carved: Dictionary, candidate_set: Dictionary, origin: Vector2i) -> void:
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var next = origin + dir
		if carved.has(next) or not candidate_set.has(next):
			continue
		if not frontier.has(next):
			frontier.append(next)

static func _pick_frontier_index(frontier: Array[Vector2i], carved: Dictionary, density_bias: float) -> int:
	var best_idx: int = 0
	var best_score: float = -999999.0
	for i in range(frontier.size()):
		var pos: Vector2i = frontier[i]
		var neighbors: int = _count_adjacent_carved(pos, carved)
		var center_pull: float = -float(absi(pos.x) + absi(pos.y)) * 0.08
		var density_pull: float = float(neighbors) * lerpf(0.55, 1.25, clampf(density_bias, 0.0, 1.0))
		var noise: float = randf_range(-0.25, 0.25)
		var score: float = density_pull + center_pull + noise
		if score > best_score:
			best_score = score
			best_idx = i
	return best_idx

static func _count_adjacent_carved(pos: Vector2i, carved: Dictionary) -> int:
	var count := 0
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if carved.has(pos + dir):
			count += 1
	return count

static func _pick_farthest_cell(start_pos: Vector2i, carved: Dictionary) -> Vector2i:
	var farthest := start_pos
	var best_dist := -1
	for pos in carved.keys():
		var dist := absi(pos.x - start_pos.x) + absi(pos.y - start_pos.y)
		if dist > best_dist:
			best_dist = dist
			farthest = pos
	return farthest

static func _apply_room_scaling(room: RoomData) -> void:
	var hp_mult := 1.0
	var dmg_mult := 1.0
	if room.type == RoomData.RoomType.BOSS:
		hp_mult = 5.0
		dmg_mult = 1.5
	elif room.type == RoomData.RoomType.SUPER_ELITE:
		hp_mult = 6.0
		dmg_mult = 1.8
	elif room.type == RoomData.RoomType.ELITE:
		hp_mult = 4.0
		dmg_mult = 1.3
	room.enemy_hp_mult = hp_mult
	room.enemy_damage_mult = dmg_mult

static func _apply_room_shape(room: RoomData, mine_def: MineDefinition, is_start: bool) -> void:
	var grand := (
		room.type in [RoomData.RoomType.BOSS, RoomData.RoomType.SUPER_ELITE]
		or (not is_start and randf() < mine_def.grand_cavern_chance)
	)
	var shape_data = RoomShapeGenerator.generate_mine_cavern(grand)
	room.shape = RoomData.RoomShape.ARENA if not grand else RoomData.RoomShape.GRAND_HALL
	room.shape_width = shape_data["width"]
	room.shape_height = shape_data["height"]
	room.floor_mask = shape_data["mask"]

static func _apply_mine_blockages(rooms: Dictionary, start_pos: Vector2i, stairs_pos: Vector2i, mine_def: MineDefinition) -> void:
	for pos in rooms.keys():
		var room := rooms[pos] as RoomData
		var degree := int(room.get_meta("mine_degree", room.connections.size()))
		if pos == start_pos or pos == stairs_pos:
			continue
		for dir_name in room.connections.keys():
			var neighbor = room.connections[dir_name] as Vector2i
			if not rooms.has(neighbor):
				continue
			if _should_skip_blockage(pos, neighbor, start_pos, stairs_pos):
				continue
			if room.transition_types.get(dir_name, RoomData.TransitionType.OPEN) != RoomData.TransitionType.OPEN:
				continue
			var blockage_chance := mine_def.blocked_connection_chance
			if degree <= 1:
				blockage_chance = maxf(blockage_chance, mine_def.secret_pocket_chance)
			if randf() >= blockage_chance:
				continue
			room.transition_types[dir_name] = RoomData.TransitionType.BREAKABLE_WALL
			var reverse_name := _dir_to_name(pos - neighbor)
			var other := rooms[neighbor] as RoomData
			if reverse_name != "":
				other.transition_types[reverse_name] = RoomData.TransitionType.BREAKABLE_WALL

static func _should_skip_blockage(pos: Vector2i, neighbor: Vector2i, start_pos: Vector2i, stairs_pos: Vector2i) -> bool:
	if pos == start_pos or neighbor == start_pos:
		return true
	if pos == stairs_pos or neighbor == stairs_pos:
		return true
	if absi(pos.x - start_pos.x) + absi(pos.y - start_pos.y) <= 1:
		return true
	if absi(neighbor.x - start_pos.x) + absi(neighbor.y - start_pos.y) <= 1:
		return true
	return false

static func _roll_mine_room_type(floor_number: int) -> RoomData.RoomType:
	var roll = randf()
	if roll < 0.7:
		return RoomData.RoomType.COMBAT
	if roll < 0.79:
		return RoomData.RoomType.TREASURE
	if roll < 0.86:
		return RoomData.RoomType.SHRINE
	if roll < 0.92:
		return RoomData.RoomType.SHOP
	if floor_number >= 5 and randf() < 0.35:
		return RoomData.RoomType.SUPER_ELITE
	return RoomData.RoomType.ELITE

static func _dir_to_name(dir: Vector2i) -> String:
	if dir == Vector2i(0, -1):
		return "north"
	if dir == Vector2i(0, 1):
		return "south"
	if dir == Vector2i(-1, 0):
		return "west"
	if dir == Vector2i(1, 0):
		return "east"
	return ""
