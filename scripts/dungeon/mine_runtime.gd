class_name MineRuntime
extends RefCounted

const ORE_NODE_SPRITE := 116
const GEM_NODE_SPRITE := 124
const CACHE_NODE_SPRITE := 123

var _dm
var _mine: MineDefinition
var _breakable_cells: Dictionary = {}
var _current_room: Vector2i = Vector2i.ZERO
var _room_elapsed: float = 0.0
var _intrusion_timer: float = 0.0
var _intrusion_count: int = 0

func setup(dm, mine_def: MineDefinition) -> void:
	_dm = dm
	_mine = mine_def
	_breakable_cells.clear()
	_current_room = Vector2i.ZERO
	_room_elapsed = 0.0
	_intrusion_timer = 0.0
	_intrusion_count = 0

func clear_runtime() -> void:
	_breakable_cells.clear()
	_current_room = Vector2i.ZERO
	_room_elapsed = 0.0
	_intrusion_timer = 0.0
	_intrusion_count = 0

func on_floor_generated() -> void:
	_breakable_cells.clear()
	_current_room = Vector2i.ZERO
	_room_elapsed = 0.0
	_intrusion_timer = _get_initial_intrusion_delay()
	_intrusion_count = 0
	if _dm == null or _mine == null or _dm.run_state == null:
		return
	_seed_all_wall_breakables()
	_seed_breakable_cells()
	_spawn_mine_nodes()

func process(delta: float) -> void:
	if _dm == null or _mine == null or _dm.run_state == null:
		return
	var grid_pos: Vector2i = _dm.run_state.current_grid_pos
	if grid_pos != _current_room:
		_current_room = grid_pos
		_room_elapsed = 0.0
		_intrusion_timer = _get_initial_intrusion_delay()
		_intrusion_count = 0
		return
	var target_room := _get_pressure_target_room(grid_pos)
	if target_room == Vector2i(-9999, -9999):
		return
	var room_data = _dm.run_state.floor_map[target_room] as RoomData
	if room_data == null:
		return
	_room_elapsed += delta
	_intrusion_timer -= delta
	if _intrusion_timer > 0.0:
		return
	_intrusion_timer = _mine.intrusion_interval
	_intrusion_count += 1
	_spawn_intrusion_wave(target_room, room_data)

func _get_initial_intrusion_delay() -> float:
	if _mine == null:
		return 0.0
	return minf(_mine.intrusion_interval, 2.5)

func on_room_entered(grid_pos: Vector2i, room_data: RoomData) -> void:
	_current_room = grid_pos
	_room_elapsed = 0.0
	_intrusion_count = 0
	_intrusion_timer = _get_initial_intrusion_delay()

func _is_hostile_room(room_data: RoomData) -> bool:
	if room_data == null:
		return false
	if room_data.type in [RoomData.RoomType.SHOP, RoomData.RoomType.TREASURE, RoomData.RoomType.SHRINE]:
		return false
	if room_data.has_stairs_up:
		return false
	return true

func _get_pressure_target_room(from_grid: Vector2i) -> Vector2i:
	if _dm == null or _dm.run_state == null:
		return Vector2i(-9999, -9999)
	var floor_map: Dictionary = _dm.run_state.floor_map
	if floor_map.has(from_grid):
		var current_room = floor_map[from_grid] as RoomData
		if _is_hostile_room(current_room):
			return from_grid
	var best_room := Vector2i(-9999, -9999)
	var best_dist := 999999
	for grid_pos in floor_map.keys():
		var room_data = floor_map[grid_pos] as RoomData
		if not _is_hostile_room(room_data):
			continue
		var dist := absi(grid_pos.x - from_grid.x) + absi(grid_pos.y - from_grid.y)
		if dist < best_dist:
			best_dist = dist
			best_room = grid_pos
	return best_room

func has_breakable_cell(tile_pos: Vector2i) -> bool:
	return _breakable_cells.has(tile_pos)

func get_breakable_cell_state(tile_pos: Vector2i) -> Dictionary:
	return _breakable_cells.get(tile_pos, {}).duplicate(true)

func damage_breakable_cell_at(world_pos: Vector2, damage: int = 1) -> Dictionary:
	var tile_pos := Vector2i(int(floor(world_pos.x / _dm.TILE_SIZE)), int(floor(world_pos.y / _dm.TILE_SIZE)))
	return damage_breakable_cell(tile_pos, damage)

func damage_breakable_cell(tile_pos: Vector2i, damage: int = 1) -> Dictionary:
	var state: Dictionary = _breakable_cells.get(tile_pos, {})
	if state.is_empty():
		return {"ok": false}

	state["hp"] = maxi(0, int(state.get("hp", 1)) - maxi(1, damage))
	_breakable_cells[tile_pos] = state
	if int(state.get("hp", 0)) > 0:
		return {
			"ok": true,
			"destroyed": false,
			"hp": int(state.get("hp", 0)),
			"kind": str(state.get("kind", "soft")),
		}

	_breakable_cells.erase(tile_pos)
	_destroy_breakable_cell(tile_pos, state)
	return {
		"ok": true,
		"destroyed": true,
		"kind": str(state.get("kind", "soft")),
	}

func get_all_breakable_cells() -> Dictionary:
	return _breakable_cells.duplicate(true)

func _spawn_mine_nodes() -> void:
	var eligible_rooms: Array[Vector2i] = []
	for grid_pos in _dm.run_state.floor_map:
		var room_data = _dm.run_state.floor_map[grid_pos] as RoomData
		if room_data == null:
			continue
		if room_data.type not in [
			RoomData.RoomType.COMBAT,
			RoomData.RoomType.ELITE,
			RoomData.RoomType.SUPER_ELITE,
			RoomData.RoomType.SHOP,
		]:
			continue
		if grid_pos == _dm.run_state.current_grid_pos:
			continue
		eligible_rooms.append(grid_pos)

	if eligible_rooms.is_empty():
		return

	eligible_rooms.shuffle()
	var rooms_to_use := mini(eligible_rooms.size(), randi_range(_mine.node_spawn_rooms_min, _mine.node_spawn_rooms_max))
	for room_idx in range(rooms_to_use):
		var grid_pos = eligible_rooms[room_idx]
		var room_data = _dm.run_state.floor_map[grid_pos] as RoomData
		var node_count := randi_range(_mine.node_count_per_room_min, _mine.node_count_per_room_max)
		var positions = _dm._get_valid_spawn_positions(grid_pos, room_data, node_count)
		for pos in positions:
			var node := _build_mine_node_for_room(room_data)
			node.global_position = pos
			_dm.add_child(node)

func _build_mine_node_for_room(room_data: RoomData) -> MineNode:
	var node := MineNode.new()
	node.harvest_type = "ore"
	node.mine_node_type = "ore"
	node.drop_count_min = 1
	node.drop_count_max = 2 if room_data.type in [RoomData.RoomType.ELITE, RoomData.RoomType.SUPER_ELITE] else 1
	node.respawn_time = 0.0
	node.collision_radius = 6.0
	node.sprite_scale = 0.22
	node.z_index = 2
	node.codex_material_ids = _mine.material_drop_paths

	var roll := randf()
	if roll < _mine.gem_node_chance and _mine.gem_hint_ids.size() > 0:
		node.mine_node_type = "gem"
		node.sprite_tile_index = GEM_NODE_SPRITE
		node.drop_table.assign(_mine.rare_material_drop_paths if _mine.rare_material_drop_paths.size() > 0 else _mine.material_drop_paths)
		node.gem_discovery_ids = _mine.gem_hint_ids
	elif roll < (_mine.gem_node_chance + _mine.blueprint_fragment_chance) and _mine.blueprint_ids.size() > 0:
		node.mine_node_type = "cache"
		node.sprite_tile_index = CACHE_NODE_SPRITE
		node.drop_table.assign(_mine.material_drop_paths)
		node.blueprint_fragment_id = _mine.blueprint_ids[randi() % _mine.blueprint_ids.size()]
		node.blueprint_fragment_amount = 1
	else:
		node.mine_node_type = "ore"
		node.sprite_tile_index = ORE_NODE_SPRITE
		node.drop_table.assign(_mine.material_drop_paths)

	return node

func _seed_breakable_cells() -> void:
	var eligible_rooms: Array[Vector2i] = []
	for grid_pos in _dm.run_state.floor_map:
		var room_data = _dm.run_state.floor_map[grid_pos] as RoomData
		if room_data == null:
			continue
		if room_data.type not in [
			RoomData.RoomType.COMBAT,
			RoomData.RoomType.ELITE,
			RoomData.RoomType.SUPER_ELITE,
			RoomData.RoomType.BOSS,
		]:
			continue
		eligible_rooms.append(grid_pos)

	if eligible_rooms.is_empty():
		return

	var clusters := randi_range(_mine.breakable_clusters_min, _mine.breakable_clusters_max)
	for _i in range(clusters):
		var grid_pos = eligible_rooms[randi() % eligible_rooms.size()]
		var room_data = _dm.run_state.floor_map[grid_pos] as RoomData
		var candidates := _get_room_wall_candidates(grid_pos, room_data)
		if randf() < 0.45:
			candidates.append_array(_get_room_interior_rock_candidates(grid_pos, room_data))
		if candidates.is_empty():
			continue
		var center_tile: Vector2i = candidates[randi() % candidates.size()]
		var radius := randi_range(_mine.breakable_cluster_radius_min, _mine.breakable_cluster_radius_max)
		_seed_breakable_cluster(center_tile, radius)

func _seed_all_wall_breakables() -> void:
	for tile_pos in _dm.wall_layer.get_used_cells():
		if _breakable_cells.has(tile_pos):
			continue
		# Keep a bedrock fraction so the mine still has structural limits.
		if randf() < 0.2:
			continue
		_breakable_cells[tile_pos] = _build_breakable_cell_state(false)
		_mark_breakable_wall(tile_pos)

func _seed_breakable_cluster(center_tile: Vector2i, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var tile_pos := center_tile + Vector2i(dx, dy)
			if _breakable_cells.has(tile_pos):
				continue
			var has_floor = _dm.floor_layer.get_cell_source_id(tile_pos) >= 0
			var has_wall = _dm.wall_layer.get_cell_source_id(tile_pos) >= 0
			if not has_floor and not has_wall:
				continue
			if has_floor and not has_wall:
				_dm.floor_layer.erase_cell(tile_pos)
				_dm._floor_tile_set.erase(tile_pos)
				var theme_row = 0
				var nearby_wall = _find_nearby_wall_theme(tile_pos)
				if nearby_wall != Vector2i(-1, -1):
					theme_row = nearby_wall.y
				_dm.wall_layer.set_cell(tile_pos, 0, Vector2i(4, theme_row))
			var state := _build_breakable_cell_state(dx == 0 and dy == 0)
			_breakable_cells[tile_pos] = state
			_mark_breakable_wall(tile_pos)

func _build_breakable_cell_state(is_cluster_center: bool) -> Dictionary:
	var kind := "soft"
	var hp := _roll_hp(_mine.soft_wall_hp, _mine.soft_wall_hp_max)
	var drop_paths: PackedStringArray = PackedStringArray()
	var blueprint_id := ""
	var gem_ids: PackedStringArray = PackedStringArray()

	var roll := randf()
	var ore_chance := 0.2 if is_cluster_center else 0.06
	var gem_chance := 0.4 if is_cluster_center else 0.09
	var cache_chance := 0.52 if is_cluster_center else 0.12
	if _mine.rare_material_drop_paths.size() > 0 and roll < ore_chance:
		kind = "ore"
		hp = _roll_hp(_mine.ore_wall_hp, _mine.ore_wall_hp_max)
		drop_paths = _mine.rare_material_drop_paths
	elif _mine.gem_hint_ids.size() > 0 and roll < gem_chance:
		kind = "gem"
		hp = _roll_hp(_mine.gem_wall_hp, _mine.gem_wall_hp_max)
		drop_paths = _mine.rare_material_drop_paths if _mine.rare_material_drop_paths.size() > 0 else _mine.material_drop_paths
		gem_ids = _mine.gem_hint_ids
	elif _mine.blueprint_ids.size() > 0 and roll < cache_chance:
		kind = "cache"
		hp = _roll_hp(_mine.ore_wall_hp, _mine.ore_wall_hp_max)
		drop_paths = _mine.material_drop_paths
		blueprint_id = _mine.blueprint_ids[randi() % _mine.blueprint_ids.size()]
	else:
		kind = "soft"
		hp = _roll_hp(_mine.soft_wall_hp, _mine.soft_wall_hp_max)
		drop_paths = PackedStringArray()

	return {
		"kind": kind,
		"hp": hp,
		"drop_paths": drop_paths,
		"blueprint_id": blueprint_id,
		"gem_ids": gem_ids,
	}

func _roll_hp(min_hp: int, max_hp: int) -> int:
	var lo := maxi(1, min_hp)
	var hi := maxi(lo, max_hp)
	return randi_range(lo, hi)

func _mark_breakable_wall(tile_pos: Vector2i) -> void:
	var atlas = _dm.wall_layer.get_cell_atlas_coords(tile_pos)
	if atlas == Vector2i(-1, -1):
		return
	_dm.wall_layer.set_cell(tile_pos, 0, Vector2i(3, atlas.y))

func _destroy_breakable_cell(tile_pos: Vector2i, state: Dictionary) -> void:
	var world_pos := Vector2((tile_pos.x + 0.5) * _dm.TILE_SIZE, (tile_pos.y + 0.5) * _dm.TILE_SIZE)
	_dm.smash_area(world_pos, 0, false, false)
	_expand_breakables_from_opening(tile_pos)
	_spawn_breakable_rewards(world_pos, state)

func _expand_breakables_from_opening(tile_pos: Vector2i) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var probe = tile_pos + Vector2i(dx, dy)
			if _breakable_cells.has(probe):
				continue
			if _dm.wall_layer.get_cell_source_id(probe) < 0:
				continue
			_breakable_cells[probe] = _build_breakable_cell_state(false)
			_mark_breakable_wall(probe)

func _spawn_breakable_rewards(world_pos: Vector2, state: Dictionary) -> void:
	var drop_paths: PackedStringArray = state.get("drop_paths", PackedStringArray())
	var kind := str(state.get("kind", "soft"))
	if drop_paths.size() > 0:
		var bag := LootBag.new()
		match kind:
			"ore":
				var ore_path := str(drop_paths[randi() % drop_paths.size()])
				var ore_res := load(ore_path) as EquipmentItem
				if ore_res:
					bag.items.append(ore_res.make_copy())
				if drop_paths.size() > 1 and randf() < 0.35:
					var extra_path := str(drop_paths[randi() % drop_paths.size()])
					var extra_res := load(extra_path) as EquipmentItem
					if extra_res:
						bag.items.append(extra_res.make_copy())
			"gem":
				var gem_count := 1 + int(randf() < 0.4)
				for _i in range(gem_count):
					var gem_path := str(drop_paths[randi() % drop_paths.size()])
					var gem_res := load(gem_path) as EquipmentItem
					if gem_res:
						bag.items.append(gem_res.make_copy())
			"cache":
				for item_path in drop_paths:
					if randf() >= 0.45:
						continue
					var cache_res := load(str(item_path)) as EquipmentItem
					if cache_res:
						bag.items.append(cache_res.make_copy())
		if bag.items.size() > 0:
			bag.global_position = world_pos
			_dm.add_child(bag)

	var gm = _dm.get_node_or_null("/root/GameManager")
	var blueprint_id := str(state.get("blueprint_id", ""))
	if gm:
		var gem_ids = state.get("gem_ids", PackedStringArray()) as PackedStringArray
		for gem_id in gem_ids:
			gm.discover_gem(gem_id)
		if blueprint_id != "":
			var result = gm.add_blueprint_progress(blueprint_id, 1)
			var progress: int = int(result.get("progress", 0))
			FloatingText.spawn(_dm.get_tree().current_scene, world_pos + Vector2(0, -16), "+1 Blueprint (%d)" % progress, Color(0.9, 0.8, 0.4))

func _get_room_wall_candidates(grid_pos: Vector2i, room_data: RoomData) -> Array[Vector2i]:
	var origin: Vector2i = _dm._grid_to_tile_origin(grid_pos)
	var candidates: Array[Vector2i] = []
	var mask = room_data.floor_mask
	var w = room_data.shape_width
	var h = room_data.shape_height

	for y in range(h):
		for x in range(w):
			if not mask[y][x]:
				continue
			var base_tile = origin + Vector2i(x, y)
			for offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var wall_tile = base_tile + offset
				if _dm.floor_layer.get_cell_source_id(wall_tile) >= 0:
					continue
				if _dm.wall_layer.get_cell_source_id(wall_tile) < 0:
					continue
				if not candidates.has(wall_tile):
					candidates.append(wall_tile)
	return candidates

func _get_room_interior_rock_candidates(grid_pos: Vector2i, room_data: RoomData) -> Array[Vector2i]:
	var origin: Vector2i = _dm._grid_to_tile_origin(grid_pos)
	var candidates: Array[Vector2i] = []
	var mask = room_data.floor_mask
	var w = room_data.shape_width
	var h = room_data.shape_height
	for y in range(3, h - 3):
		for x in range(3, w - 3):
			if not mask[y][x]:
				continue
			if not _dm._has_floor_clearance(mask, x, y, w, h, 2):
				continue
			var tile_pos = origin + Vector2i(x, y)
			if _dm.deco_layer.get_cell_source_id(tile_pos) >= 0:
				continue
			candidates.append(tile_pos)
	return candidates

func _find_nearby_wall_theme(tile_pos: Vector2i) -> Vector2i:
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var probe = tile_pos + Vector2i(dx, dy)
			if _dm.wall_layer.get_cell_source_id(probe) >= 0:
				return _dm.wall_layer.get_cell_atlas_coords(probe)
	return Vector2i(-1, -1)

func _spawn_intrusion_wave(grid_pos: Vector2i, room_data: RoomData) -> void:
	if _dm == null:
		return
	var active_intruders := _get_active_intruder_count()
	if _mine and active_intruders >= _mine.max_active_intruders:
		_intrusion_timer = 4.0
		return
	var wave_size := randi_range(_mine.intrusion_wave_size_min, _mine.intrusion_wave_size_max)
	if _mine:
		wave_size = mini(wave_size, maxi(_mine.max_active_intruders - active_intruders, 0))
	wave_size = maxi(1, wave_size)
	var tier := "normal"
	if _room_elapsed >= _mine.intrusion_super_time:
		tier = "super"
	elif _room_elapsed >= _mine.intrusion_elite_time:
		tier = "elite"
	var result = _dm.spawn_mine_intrusion_wave_global(grid_pos, room_data, wave_size, tier)
	if not bool(result.get("ok", false)):
		# Retry soon instead of making the player wait through a full failed cycle.
		_intrusion_timer = _mine.intrusion_retry_interval if _mine else 3.0
		return
	var label := "BREACH..."
	var color := Color(0.8, 0.8, 0.8)
	match tier:
		"elite":
			label = "Heavy breach"
			color = Color(1.0, 0.75, 0.3)
		"super":
			label = "Deep terror"
			color = Color(1.0, 0.45, 0.45)
	FloatingText.spawn(_dm, _dm._grid_to_world_center(grid_pos), label, color)

func _get_active_intruder_count() -> int:
	if _dm == null:
		return 0
	var count := 0
	for enemy in _dm.get_tree().get_nodes_in_group("mine_intrusion_enemy"):
		if is_instance_valid(enemy):
			count += 1
	return count
