class_name BattleFogOfWar
extends Node2D

## Circle-based fog of war for battle arena.
## Player faction units and the player hero reveal a radius around them.
## Enemy units outside revealed areas are hidden.
## Fog is drawn as a dark overlay with holes cut for visible areas.

const REVEAL_RADIUS_UNIT := 120.0  # Each friendly unit reveals this radius
const REVEAL_RADIUS_PLAYER := 250.0  # Player hero reveals more
const REVEAL_RADIUS_SCOUT := 200.0  # Cavalry/archers reveal further
const FOG_COLOR := Color(0.05, 0.05, 0.1, 0.75)
const EXPLORED_COLOR := Color(0.05, 0.05, 0.1, 0.4)  # Previously seen areas
const CELL_SIZE := 32  # Fog grid resolution (matches tile size)

var _units: BattleUnitSystem
var _pixel_region: Rect2
var _player_pos: Vector2 = Vector2.ZERO
var _player_alive: bool = true
var enabled: bool = true

# Fog grid: 0=unseen, 1=explored (seen before), 2=visible (currently revealed)
var _fog_grid: PackedByteArray
var _grid_width: int = 0
var _grid_height: int = 0
var _grid_origin: Vector2  # world position of grid (0,0)

# Cached reveal circles for each friendly unit (updated periodically)
var _visible_cells: PackedInt32Array  # flat indices of currently visible cells
var _update_timer: float = 0.0
const UPDATE_INTERVAL := 0.15  # Update fog every 150ms

func setup(units: BattleUnitSystem, pixel_region: Rect2) -> void:
	_units = units
	_pixel_region = pixel_region
	_grid_origin = pixel_region.position
	_grid_width = int(ceil(pixel_region.size.x / CELL_SIZE)) + 2
	_grid_height = int(ceil(pixel_region.size.y / CELL_SIZE)) + 2
	_fog_grid.resize(_grid_width * _grid_height)
	_fog_grid.fill(0)
	z_index = 5  # Above units, below UI

func update_fog(dt: float, player_pos: Vector2, player_alive: bool) -> void:
	_player_pos = player_pos
	_player_alive = player_alive
	if not enabled:
		return
	_update_timer += dt
	if _update_timer < UPDATE_INTERVAL:
		return
	_update_timer = 0.0
	_recompute_visibility()
	queue_redraw()

func _recompute_visibility() -> void:
	# Demote all visible cells to explored
	for idx in _visible_cells:
		if idx >= 0 and idx < _fog_grid.size():
			_fog_grid[idx] = 1  # explored
	_visible_cells.resize(0)

	# Reveal around player
	if _player_alive:
		_reveal_circle(_player_pos.x, _player_pos.y, REVEAL_RADIUS_PLAYER)

	# Reveal around all friendly (BLUE) alive units
	if _units:
		for i in _units.count:
			if _units.alive[i] == 0 or _units.faction[i] != BattleUnitSystem.Faction.BLUE:
				continue
			var t := _units.unit_type[i]
			var reveal_r := REVEAL_RADIUS_UNIT
			# Scouts (cavalry, archers) see further
			if t == BattleUnitSystem.UnitType.CAVALRY or t == BattleUnitSystem.UnitType.HEAVY_CAVALRY or t == BattleUnitSystem.UnitType.ARCHER:
				reveal_r = REVEAL_RADIUS_SCOUT
			_reveal_circle(_units.x[i], _units.y[i], reveal_r)

func _reveal_circle(wx: float, wy: float, radius: float) -> void:
	var cx := int(floor((wx - _grid_origin.x) / CELL_SIZE))
	var cy := int(floor((wy - _grid_origin.y) / CELL_SIZE))
	var cell_radius := int(ceil(radius / CELL_SIZE))
	var r_sq := radius * radius

	for dy in range(-cell_radius, cell_radius + 1):
		var gy := cy + dy
		if gy < 0 or gy >= _grid_height:
			continue
		for dx in range(-cell_radius, cell_radius + 1):
			var gx := cx + dx
			if gx < 0 or gx >= _grid_width:
				continue
			# Distance check (center of cell to reveal center)
			var cell_wx := _grid_origin.x + (gx + 0.5) * CELL_SIZE
			var cell_wy := _grid_origin.y + (gy + 0.5) * CELL_SIZE
			var ddx := cell_wx - wx
			var ddy := cell_wy - wy
			if ddx * ddx + ddy * ddy <= r_sq:
				var idx := gy * _grid_width + gx
				_fog_grid[idx] = 2  # visible
				_visible_cells.append(idx)

func is_cell_visible(wx: float, wy: float) -> bool:
	## Check if a world position is currently visible (not fogged)
	if not enabled:
		return true
	var gx := int(floor((wx - _grid_origin.x) / CELL_SIZE))
	var gy := int(floor((wy - _grid_origin.y) / CELL_SIZE))
	if gx < 0 or gx >= _grid_width or gy < 0 or gy >= _grid_height:
		return false
	return _fog_grid[gy * _grid_width + gx] == 2

func is_cell_explored(wx: float, wy: float) -> bool:
	## Check if position was ever seen
	if not enabled:
		return true
	var gx := int(floor((wx - _grid_origin.x) / CELL_SIZE))
	var gy := int(floor((wy - _grid_origin.y) / CELL_SIZE))
	if gx < 0 or gx >= _grid_width or gy < 0 or gy >= _grid_height:
		return false
	return _fog_grid[gy * _grid_width + gx] >= 1

func _draw() -> void:
	if not enabled:
		return
	# Draw fog cells that are not fully visible
	for gy in _grid_height:
		for gx in _grid_width:
			var state := _fog_grid[gy * _grid_width + gx]
			if state == 2:
				continue  # Fully visible, no fog
			var cell_pos := Vector2(
				_grid_origin.x + gx * CELL_SIZE,
				_grid_origin.y + gy * CELL_SIZE
			)
			if state == 0:
				draw_rect(Rect2(cell_pos, Vector2(CELL_SIZE, CELL_SIZE)), FOG_COLOR)
			else:  # explored
				draw_rect(Rect2(cell_pos, Vector2(CELL_SIZE, CELL_SIZE)), EXPLORED_COLOR)
