extends Node2D

var enemy_scene: PackedScene
var spawn_interval: float = 3.0
var default_drop_table: DropTable

func _ready() -> void:
	enemy_scene = preload("res://scenes/enemy.tscn")
	default_drop_table = preload("res://resources/default_drop_table.tres")

	var timer = $SpawnTimer as Timer
	timer.wait_time = spawn_interval
	timer.timeout.connect(_spawn_enemy)
	timer.start()

func _spawn_enemy() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var enemies_container = get_tree().get_first_node_in_group("enemies")
	if not enemies_container:
		return

	if enemies_container.get_child_count() >= 10:
		return

	var player_pos = player.global_position
	var spawn_pos = Vector2.ZERO
	var side = randi() % 4
	var offset = 160.0

	match side:
		0: spawn_pos = player_pos + Vector2(randf_range(-200, 200), -offset)
		1: spawn_pos = player_pos + Vector2(randf_range(-200, 200), offset)
		2: spawn_pos = player_pos + Vector2(-offset, randf_range(-120, 120))
		3: spawn_pos = player_pos + Vector2(offset, randf_range(-120, 120))

	var enemy = enemy_scene.instantiate()
	enemy.global_position = spawn_pos
	enemy.drop_table = default_drop_table
	enemies_container.add_child(enemy)
