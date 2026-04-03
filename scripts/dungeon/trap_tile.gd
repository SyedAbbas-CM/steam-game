class_name TrapTile
extends "res://scripts/dungeon/traps/dungeon_trap.gd"

var trap_atlas: Vector2i  # atlas coords for the trap tile

var _blink_count: int = 0
const BLINK_TOTAL = 6
const BLINK_INTERVAL = 0.15
const BULLET_COUNT = 8
const PROXIMITY_RANGE_SQ = 256.0  # 16px = 2 tiles, squared for fast check

func _ready() -> void:
	super._ready()
	area_entered.connect(_on_area_entered)

func activate() -> void:
	super.activate()

func _physics_process(_delta: float) -> void:
	if _triggered or not is_inside_tree():
		return
	var player = _find_player()
	if player:
		if global_position.distance_squared_to(player.global_position) <= PROXIMITY_RANGE_SQ:
			_triggered = true
			set_physics_process(false)
			_start_blink()

func _on_area_entered(area: Area2D) -> void:
	if _triggered:
		return
	if area.collision_layer & 4:
		_triggered = true
		set_physics_process(false)
		area.queue_free()
		_explode()

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
	_blink_count += 1
	var abs_pos = origin + tile_pos
	if _blink_count % 2 == 1:
		deco_layer.erase_cell(abs_pos)
	else:
		deco_layer.set_cell(abs_pos, 0, trap_atlas)
	_play_sfx("click", -10.0 + _blink_count * 1.5, 0.05)
	if _blink_count >= BLINK_TOTAL:
		timer.stop()
		timer.queue_free()
		_explode()

func _explode() -> void:
	_play_sfx("boom_b", -2.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position, 16.0, Color(1.0, 0.5, 0.2, 0.6))
		vfx.shake(2.0, 0.2)
	deco_layer.erase_cell(origin + tile_pos)

	var damage = get_damage()

	if not is_inside_tree():
		queue_free()
		return

	for i in range(BULLET_COUNT):
		var angle = (TAU / BULLET_COUNT) * i
		_spawn_bullet(global_position, Vector2.from_angle(angle), 60.0, damage, 1.5)

	queue_free()
