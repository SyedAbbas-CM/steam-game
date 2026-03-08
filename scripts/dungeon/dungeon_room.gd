class_name DungeonRoom
extends Node2D

signal room_cleared
signal exit_requested  # kept for compatibility

var room_data: RoomData
var enemy_pool: Array = []  # Array of EnemyDefinition resources
var enemies_alive: int = 0
var is_cleared: bool = false

@onready var walls: TileMapLayer = $Walls
@onready var floor_tiles: TileMapLayer = $Floor
@onready var enemy_container: Node2D = $Enemies

func _ready() -> void:
	# Hide legacy portal
	var portal = get_node_or_null("ExitPortal")
	if portal:
		portal.visible = false
		portal.monitoring = false

func setup(data: RoomData) -> void:
	room_data = data

	# Non-combat rooms are auto-cleared (no enemies to fight)
	match data.type:
		RoomData.RoomType.COMBAT, RoomData.RoomType.ELITE, RoomData.RoomType.BOSS:
			_spawn_enemies()
		RoomData.RoomType.TREASURE:
			is_cleared = false
		RoomData.RoomType.SHRINE:
			is_cleared = false
		RoomData.RoomType.SHOP:
			is_cleared = true
			room_data.cleared = true

func _spawn_enemies() -> void:
	var enemy_scene = preload("res://scenes/enemy.tscn")
	var spawn_positions = _get_spawn_positions(room_data.enemy_count)

	var fallback_def = EnemyDefinition.new()
	fallback_def.enemy_name = "Default"
	fallback_def.max_hp = 3
	fallback_def.attack_type = EnemyDefinition.AttackType.RANGED
	fallback_def.bullet_count = 3
	fallback_def.bullet_speed = 80.0

	for i in range(room_data.enemy_count):
		var enemy = enemy_scene.instantiate()
		enemy.global_position = spawn_positions[i]

		var def: EnemyDefinition
		if enemy_pool.size() > 0:
			def = enemy_pool[randi() % enemy_pool.size()].duplicate()
		else:
			def = fallback_def.duplicate()

		def.max_hp = int(def.max_hp * room_data.enemy_hp_mult)

		if room_data.type == RoomData.RoomType.ELITE:
			def.max_hp = int(def.max_hp * 3)
			def.move_speed *= 1.2
			def.sprite_color = def.sprite_color.lightened(0.3)
		elif room_data.type == RoomData.RoomType.BOSS:
			def.max_hp = int(def.max_hp * 6)
			def.move_speed *= 0.8
			def.attack_speed *= 0.6
			def.bullet_count += 4
			def.sprite_color = def.sprite_color.lightened(0.5)

		enemy.setup(def)
		enemy.tree_exited.connect(_on_enemy_died)
		enemy_container.add_child(enemy)
		enemies_alive += 1

func _get_spawn_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var radius = 32.0  # 4 tiles at 8px each
	for i in range(count):
		var angle = (TAU / count) * i
		positions.append(Vector2(cos(angle), sin(angle)) * radius)
	return positions

func _on_enemy_died() -> void:
	enemies_alive -= 1
	if enemies_alive <= 0 and not is_cleared:
		_clear_room()

func _clear_room() -> void:
	is_cleared = true
	room_data.cleared = true
	room_cleared.emit()

func mark_cleared() -> void:
	if not is_cleared:
		_clear_room()
