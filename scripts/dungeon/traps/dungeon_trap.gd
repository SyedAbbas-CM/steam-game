extends Area2D

var tile_pos: Vector2i  # position in tilemap coords (relative to room origin)
var origin: Vector2i    # room origin in tilemap coords
var deco_layer: TileMapLayer
var floor_number: int = 1
var room_grid_pos: Vector2i
var trap_source_id: int = 0  # tileset source (0=environment, 1=dungeon features)

var _active: bool = false
var _triggered: bool = false

const TILE_SIZE = 8

func _ready() -> void:
	collision_layer = 32  # trap layer (bit 6) so bullets can detect us
	collision_mask = 4  # detect player bullets
	monitorable = true
	monitoring = false
	set_physics_process(false)
	add_to_group("trap")

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	add_child(shape)

func activate() -> void:
	if _active:
		return
	_active = true
	monitoring = true
	set_physics_process(true)
	# Player bullets hitting this trap trigger it
	if not area_entered.is_connected(_on_bullet_hit):
		area_entered.connect(_on_bullet_hit)

func _on_bullet_hit(area: Node2D) -> void:
	if _triggered:
		return
	# Only player bullets (collision_layer 4) trigger traps
	if area is Area2D and area.collision_layer & 4:
		trigger_remote()

func get_damage() -> int:
	return 3 + floor_number

func _find_player() -> Node2D:
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		return player
	return null

func _spawn_bullet(pos: Vector2, dir: Vector2, speed: float, damage: int, lifetime: float = 1.5) -> void:
	if not is_inside_tree():
		return
	var bullet_scene = preload("res://scenes/bullet.tscn")
	var bullet = bullet_scene.instantiate()
	bullet.global_position = pos
	bullet.direction = dir
	bullet.speed = speed
	bullet.damage = damage
	bullet.lifetime = lifetime
	bullet.is_player_bullet = false
	bullet.hits_all = true
	bullet.trap_enemy_mult = 2
	get_tree().current_scene.add_child(bullet)

## Trigger this trap remotely (stone toss, bullet impact). Override in subclass.
func trigger_remote() -> void:
	if _triggered:
		return
	_triggered = true
	set_physics_process(false)

func _play_sfx(sfx_name: String, volume: float = -2.0, pitch_variation: float = 0.0) -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play(sfx_name, volume, pitch_variation)
