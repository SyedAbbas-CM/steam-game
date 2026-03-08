class_name TrapTile
extends Area2D

var tile_pos: Vector2i  # position in tilemap coords
var origin: Vector2i    # room origin in tilemap coords
var deco_layer: TileMapLayer
var trap_atlas: Vector2i  # atlas coords for the trap tile
var floor_number: int = 1

var _triggered: bool = false
var _blink_count: int = 0
const BLINK_TOTAL = 6
const BLINK_INTERVAL = 0.2  # 6 blinks * 0.2s = 1.2s total
const BULLET_COUNT = 8
const TILE_SIZE = 8

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # detect player
	monitoring = true

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	shape.shape = rect
	add_child(shape)

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if body.collision_layer & 1:  # player
		_triggered = true
		_start_blink()

func _start_blink() -> void:
	_blink_count = 0
	var timer = Timer.new()
	timer.wait_time = BLINK_INTERVAL
	timer.one_shot = false
	timer.timeout.connect(_on_blink_tick.bind(timer))
	add_child(timer)
	timer.start()

func _on_blink_tick(timer: Timer) -> void:
	_blink_count += 1

	# Toggle tile visibility
	var abs_pos = origin + tile_pos
	if _blink_count % 2 == 1:
		deco_layer.erase_cell(abs_pos)
	else:
		deco_layer.set_cell(abs_pos, 0, trap_atlas)

	if _blink_count >= BLINK_TOTAL:
		timer.stop()
		timer.queue_free()
		_explode()

func _explode() -> void:
	# Erase the trap tile permanently
	deco_layer.erase_cell(origin + tile_pos)

	# Spawn bullet ring
	var bullet_scene = preload("res://scenes/bullet.tscn")
	var damage = 1 + floor_number / 3

	for i in range(BULLET_COUNT):
		var angle = (TAU / BULLET_COUNT) * i
		var bullet = bullet_scene.instantiate()
		bullet.global_position = global_position
		bullet.direction = Vector2.from_angle(angle)
		bullet.speed = 60.0
		bullet.is_player_bullet = false
		bullet.damage = damage
		bullet.lifetime = 2.0
		get_tree().current_scene.add_child(bullet)

	queue_free()
