extends "res://scripts/dungeon/traps/dungeon_trap.gd"

## Wall-mounted dart launcher with floor pressure plate.
## When player steps on the plate, a fast dart fires from the wall toward the plate.

var trap_atlas: Vector2i
var wall_pos: Vector2i  # wall tile position (tilemap coords, absolute)

const PROXIMITY_RANGE_SQ = 100.0  # 10px ~1.25 tiles
const BLINK_TOTAL = 4
const BLINK_INTERVAL = 0.1

var _blink_count: int = 0

func _ready() -> void:
	super._ready()

func get_damage() -> int:
	return 5 + floor_number * 2

func _physics_process(_delta: float) -> void:
	if _triggered or not is_inside_tree():
		return
	var player = _find_player()
	if player:
		if global_position.distance_squared_to(player.global_position) <= PROXIMITY_RANGE_SQ:
			_triggered = true
			set_physics_process(false)
			_start_blink()

func _start_blink() -> void:
	_blink_count = 0
	_play_sfx("click", -4.0, 0.1)
	var timer = Timer.new()
	timer.wait_time = BLINK_INTERVAL
	timer.one_shot = false
	timer.timeout.connect(_on_blink_tick.bind(timer))
	add_child(timer)
	timer.start()

func _on_blink_tick(timer: Timer) -> void:
	if not _has_deco_layer():
		timer.stop()
		timer.queue_free()
		queue_free()
		return
	_blink_count += 1
	var abs_pos = origin + tile_pos
	if _blink_count % 2 == 1:
		deco_layer.erase_cell(abs_pos)
	else:
		deco_layer.set_cell(abs_pos, trap_source_id, trap_atlas)
	if _blink_count >= BLINK_TOTAL:
		timer.stop()
		timer.queue_free()
		_fire()

func _fire() -> void:
	_play_sfx("arrow", -3.0, 0.2)
	if _has_deco_layer():
		deco_layer.erase_cell(origin + tile_pos)

	if not is_inside_tree():
		queue_free()
		return

	# Dart fires from wall position toward plate position
	var plate_world = Vector2((origin.x + tile_pos.x) * TILE_SIZE + 4, (origin.y + tile_pos.y) * TILE_SIZE + 4)
	var wall_world = Vector2(wall_pos.x * TILE_SIZE + 4, wall_pos.y * TILE_SIZE + 4)
	var dir = (plate_world - wall_world).normalized()

	_spawn_bullet(wall_world, dir, 100.0, get_damage(), 3.0)

	queue_free()
