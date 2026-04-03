extends "res://scripts/dungeon/traps/dungeon_trap.gd"

## Crumbling floor tile — player steps on it, blink warning, then floor erased creating a hazard.

var floor_layer: TileMapLayer
var liquid_layer: TileMapLayer
var has_liquid: bool = false
var liquid_tiles: Array[Vector2i] = []

const PROXIMITY_RANGE_SQ = 100.0  # 10px ~1.25 tiles
const BLINK_TOTAL = 8
const BLINK_INTERVAL = 0.15

var _blink_count: int = 0
var _floor_atlas: Vector2i  # original floor tile to restore during blink

func _ready() -> void:
	super._ready()

func get_damage() -> int:
	return 0

func trigger_remote() -> void:
	if _triggered:
		return
	_triggered = true
	set_physics_process(false)
	var abs_pos = origin + tile_pos
	var atlas = floor_layer.get_cell_atlas_coords(abs_pos)
	_floor_atlas = atlas if atlas != Vector2i(-1, -1) else Vector2i(5, 0)
	_start_blink()

func _physics_process(_delta: float) -> void:
	if _triggered or not is_inside_tree():
		return
	var player = _find_player()
	if player:
		if global_position.distance_squared_to(player.global_position) <= PROXIMITY_RANGE_SQ:
			_triggered = true
			set_physics_process(false)
			# Remember the original floor tile for blinking
			var abs_pos = origin + tile_pos
			var atlas = floor_layer.get_cell_atlas_coords(abs_pos)
			_floor_atlas = atlas if atlas != Vector2i(-1, -1) else Vector2i(5, 0)
			_start_blink()

func _start_blink() -> void:
	_blink_count = 0
	_play_sfx("ping", -4.0, 0.1)
	var timer = Timer.new()
	timer.wait_time = BLINK_INTERVAL
	timer.one_shot = false
	timer.timeout.connect(_on_blink_tick.bind(timer))
	add_child(timer)
	timer.start()

func _on_blink_tick(timer: Timer) -> void:
	_blink_count += 1
	var abs_pos = origin + tile_pos
	if _blink_count % 2 == 1:
		# Show cracked/warning look: erase floor, show red-tinted deco
		floor_layer.erase_cell(abs_pos)
		deco_layer.set_cell(abs_pos, 1, Vector2i(2, 4))  # crack rubble
	else:
		# Restore floor
		floor_layer.set_cell(abs_pos, 0, _floor_atlas)
		deco_layer.erase_cell(abs_pos)
	_play_sfx("click", -10.0 + _blink_count * 1.5, 0.05)
	if _blink_count >= BLINK_TOTAL:
		timer.stop()
		timer.queue_free()
		_collapse()

func _collapse() -> void:
	_play_sfx("boom_b", -4.0, 0.1)

	var abs_pos = origin + tile_pos
	deco_layer.erase_cell(abs_pos)
	floor_layer.erase_cell(abs_pos)

	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.death_burst(global_position, Color(0.5, 0.4, 0.3))
		vfx.shake(1.5, 0.15)

	# Deal 40% max HP damage to player if they're on/near the tile
	var player = _find_player()
	if player and global_position.distance_to(player.global_position) < TILE_SIZE * 1.5:
		var max_hp = player.get("max_hp")
		if max_hp and max_hp > 0:
			var collapse_damage = int(max_hp * 0.4)
			if player.has_method("take_damage"):
				player.take_damage(collapse_damage)

	if has_liquid and liquid_tiles.size() > 0:
		var liq_tile = liquid_tiles[randi() % liquid_tiles.size()]
		liquid_layer.set_cell(abs_pos, 0, liq_tile)
	# else: just leave the hole as empty space — walkable, no collision

	queue_free()
