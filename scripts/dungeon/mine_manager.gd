extends "res://scripts/dungeon/dungeon_manager.gd"

func start_run() -> void:
	super.start_run()

func _prespawn_adjacent_rooms(_grid_pos: Vector2i) -> void:
	return

func _on_room_trigger_entered(body: Node2D, grid_pos: Vector2i) -> void:
	if not body.is_in_group("player"):
		return
	var state = room_states.get(grid_pos)
	if not state:
		return
	var room_data = run_state.floor_map.get(grid_pos) as RoomData
	run_state.current_grid_pos = grid_pos
	room_changed.emit(0, room_data)
	if state.get("visited", false):
		return
	_visit_room(grid_pos)

func _visit_room(grid_pos: Vector2i) -> void:
	var state = room_states.get(grid_pos)
	var room_data = run_state.floor_map.get(grid_pos) as RoomData
	if state == null or room_data == null:
		return
	state["visited"] = true
	room_data.cleared = true
	state["cleared"] = true

func _spawn_room_enemies(_grid_pos: Vector2i, _room_data: RoomData) -> void:
	return

func _paint_corridor(from_grid: Vector2i, to_grid: Vector2i, direction: String, theme_row: int) -> void:
	super._paint_corridor(from_grid, to_grid, direction, theme_row)
	if _corridor_midpoints.is_empty():
		return
	var corridor = _corridor_midpoints[_corridor_midpoints.size() - 1] as Dictionary
	var floor_tiles = corridor.get("floor_tiles", []) as Array
	if floor_tiles.is_empty():
		return
	var step := maxi(1, floor_tiles.size() / 8)
	for i in range(0, floor_tiles.size(), step):
		var tile_pos = floor_tiles[i] as Vector2i
		smash_area(Vector2((tile_pos.x + 0.5) * TILE_SIZE, (tile_pos.y + 0.5) * TILE_SIZE), 1)
		if mine_runtime != null:
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var probe = tile_pos + Vector2i(dx, dy)
					if wall_layer.get_cell_source_id(probe) < 0:
						continue
					if mine_runtime.has_breakable_cell(probe):
						continue
					mine_runtime._breakable_cells[probe] = mine_runtime._build_breakable_cell_state(false)
					mine_runtime._mark_breakable_wall(probe)
