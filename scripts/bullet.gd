extends Area2D

var speed: float = 150.0
var direction: Vector2 = Vector2.RIGHT
var is_player_bullet: bool = true
var damage: int = 1
var pierce_count: int = 0
var homing_strength: float = 0.0
var lifetime: float = 3.0
var is_crit: bool = false
var _hits_remaining: int = 1

func _ready() -> void:
	_hits_remaining = pierce_count + 1

	# Set bullet color and size
	var sprite = $Sprite2D as Sprite2D
	if is_player_bullet:
		var img = Image.create(3, 3, false, Image.FORMAT_RGBA8)
		if is_crit:
			img.fill(Color(1.0, 1.0, 0.3))  # bright white-yellow for crits
			sprite.texture = ImageTexture.create_from_image(img)
			sprite.scale = Vector2(1.5, 1.5)
		else:
			img.fill(Color.YELLOW)
			sprite.texture = ImageTexture.create_from_image(img)
			sprite.scale = Vector2(1, 1)
	else:
		var img = Image.create(3, 3, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 0.2, 0.2))  # bright red
		sprite.texture = ImageTexture.create_from_image(img)
		sprite.scale = Vector2(1.2, 1.2)

	# Auto-destroy
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()

	if is_player_bullet:
		collision_layer = 4
		collision_mask = 2 | 16  # enemies + walls
	else:
		collision_layer = 8
		collision_mask = 1 | 16  # player + walls

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	# Homing
	if homing_strength > 0.0 and is_player_bullet:
		var nearest = _find_nearest_enemy()
		if nearest:
			var desired = (nearest.global_position - global_position).normalized()
			var current_angle = direction.angle()
			var target_angle = desired.angle()
			var new_angle = lerp_angle(current_angle, target_angle, homing_strength * delta)
			direction = Vector2.from_angle(new_angle)

	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# Wall collision — destroy bullet
	if body is StaticBody2D and body.collision_layer & 16:
		queue_free()
		return
	if is_player_bullet and body.has_method("take_damage"):
		body.take_damage(damage)
		_hits_remaining -= 1
		if _hits_remaining <= 0:
			queue_free()

func _on_area_entered(area: Node2D) -> void:
	if is_player_bullet and area.name == "Hurtbox":
		var enemy = area.get_parent()
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)
			_hits_remaining -= 1
			if _hits_remaining <= 0:
				queue_free()
	elif not is_player_bullet and area.name == "Hitbox":
		var player = area.get_parent()
		if player.has_method("take_damage"):
			player.take_damage(damage)
		queue_free()

func _find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemy")
	var best: Node2D = null
	var best_dist: float = INF
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var d = global_position.distance_squared_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best
