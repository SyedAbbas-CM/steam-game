extends CharacterBody2D

enum State { IDLE, FOLLOWING, ATTACKING, RETREATING }

var definition: CompanionDefinition
var current_state: State = State.FOLLOWING
var hp: int = 10
var max_hp: int = 10
var target: Node2D = null
var player: Node2D = null
var companion_index: int = 0
var bullet_scene: PackedScene
var can_shoot: bool = true
var _animator: SpriteAnimator

@onready var sprite: Sprite2D = $Sprite2D
@onready var shoot_timer: Timer = $ShootTimer

func _ready() -> void:
	bullet_scene = preload("res://scenes/bullet.tscn")
	add_to_group("companion")
	collision_layer = 1
	collision_mask = 0

	player = get_tree().get_first_node_in_group("player")

	shoot_timer.one_shot = true
	shoot_timer.timeout.connect(func(): can_shoot = true)

func setup(def: CompanionDefinition, index: int) -> void:
	definition = def
	companion_index = index
	hp = def.hp
	max_hp = def.hp
	sprite.frame = def.sprite_frame
	shoot_timer.wait_time = def.attack_speed

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return

	match current_state:
		State.FOLLOWING:
			_do_follow()
			_check_for_targets()
		State.ATTACKING:
			_do_attack()
		State.RETREATING:
			_do_retreat()
		State.IDLE:
			_check_for_targets()
			if player.velocity.length() > 5:
				current_state = State.FOLLOWING

	move_and_slide()

func _do_follow() -> void:
	var target_pos = _get_follow_position()
	var dir = (target_pos - global_position)

	if dir.length() > 3.0:
		velocity = dir.normalized() * definition.move_speed
	else:
		velocity = Vector2.ZERO
		current_state = State.IDLE

	# Flip sprite
	if dir.x < 0:
		sprite.flip_h = true
	elif dir.x > 0:
		sprite.flip_h = false

func _get_follow_position() -> Vector2:
	var behind = -player.velocity.normalized() if player.velocity.length() > 5 else Vector2.DOWN
	var perp = behind.rotated(PI / 2.0)
	var base = player.global_position + behind * definition.follow_distance

	match companion_index:
		0: return base + perp * -12
		1: return base
		2: return base + perp * 12
	return base

func _check_for_targets() -> void:
	var nearest = _find_nearest_enemy()
	if nearest:
		target = nearest
		current_state = State.ATTACKING

func _do_attack() -> void:
	if not is_instance_valid(target):
		target = null
		current_state = State.FOLLOWING
		return

	var dist = global_position.distance_to(target.global_position)

	if dist > definition.attack_range * 1.5:
		target = null
		current_state = State.FOLLOWING
		return

	# Move to attack range
	if dist > definition.attack_range * 0.8:
		var dir = (target.global_position - global_position).normalized()
		velocity = dir * definition.move_speed * 0.7
	else:
		velocity = Vector2.ZERO

	# Shoot
	if can_shoot and dist <= definition.attack_range:
		_shoot_at(target)

	# Flip toward target
	if target.global_position.x < global_position.x:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

func _do_retreat() -> void:
	var dir = (player.global_position - global_position).normalized()
	velocity = dir * definition.move_speed
	if global_position.distance_to(player.global_position) < definition.follow_distance:
		current_state = State.FOLLOWING

func _shoot_at(enemy: Node2D) -> void:
	can_shoot = false
	shoot_timer.start()

	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return

	var dir = (enemy.global_position - global_position).normalized()
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = dir
	bullet.is_player_bullet = true
	bullet.speed = 120.0
	bullet.damage = definition.damage
	bullets_container.add_child(bullet)

func _find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemy")
	var best: Node2D = null
	var best_dist: float = definition.attack_range * definition.attack_range

	for e in enemies:
		if not is_instance_valid(e):
			continue
		var d = global_position.distance_squared_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best

func take_damage(amount: int) -> void:
	hp -= amount
	sprite.modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if hp <= 0:
		queue_free()
