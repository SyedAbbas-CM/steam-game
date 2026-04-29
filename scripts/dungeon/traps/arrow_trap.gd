extends "res://scripts/dungeon/traps/dungeon_trap.gd"

## Chess-like pressure tile — fires 4 arrows in cardinal directions when player steps near.

var trap_atlas: Vector2i

const PROXIMITY_RANGE_SQ = 144.0  # 12px = 1.5 tiles, squared
const BLINK_TOTAL = 6
const BLINK_INTERVAL = 0.12

var _blink_count: int = 0

func _ready() -> void:
	super._ready()

func get_damage() -> int:
	return 2 + floor_number

func trigger_remote() -> void:
	if _triggered:
		return
	_triggered = true
	set_physics_process(false)
	_start_blink()

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
	_play_sfx("ping", -6.0, 0.1)
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
	_play_sfx("click", -10.0 + _blink_count * 1.5, 0.05)
	if _blink_count >= BLINK_TOTAL:
		timer.stop()
		timer.queue_free()
		_fire()

func _fire() -> void:
	_play_sfx("arrow", -3.0, 0.1)
	if _has_deco_layer():
		deco_layer.erase_cell(origin + tile_pos)

	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.hit_spark(global_position, Color(0.8, 0.6, 0.3))

	if not is_inside_tree():
		queue_free()
		return

	var damage = get_damage()
	var dirs = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	for dir in dirs:
		_spawn_bullet(global_position, dir, 80.0, damage, 3.0)

	queue_free()
