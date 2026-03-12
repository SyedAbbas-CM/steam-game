extends Area2D

var speed: float = 150.0
var direction: Vector2 = Vector2.RIGHT
var is_player_bullet: bool = true
var damage: int = 1
var pierce_count: int = 0
var homing_strength: float = 0.0
var lifetime: float = 3.0
var is_crit: bool = false
var enchant_type: int = -1  # ItemEnchantment.EnchantType, -1 = none
var enchant_proc_chance: float = 0.0
var enchant_bonus_damage: float = 0.0
var bullet_sprite_index: int = -1  # index into lofi_obj.png, -1 = default
var hits_all: bool = false  # trap bullets: damage both player and enemies
var _hits_remaining: int = 1

## --- Advanced Bullet Behaviors ---
enum BulletBehavior {
	NORMAL,          # straight line
	RETURNING,       # curves back to origin after reaching max distance
	ACCELERATING,    # starts slow, speeds up over time
	DECELERATING,    # starts fast, slows down then detonates into sub-bullets
	SINE_WAVE,       # oscillates perpendicular to travel direction
	ORBITING,        # orbits around a point before launching
	SPLITTING,       # splits into sub-bullets after a delay
	HOMING_ENEMY,    # enemy bullet that homes toward player
	SEEKING_MINE,    # very slow homing toward player
	BOOMERANG,       # arcs out then curves back toward origin entity
}

var behavior: BulletBehavior = BulletBehavior.NORMAL
var _origin_pos: Vector2 = Vector2.ZERO       # spawn position (for RETURNING)
var _origin_entity: Node2D = null              # entity that fired this bullet (for BOOMERANG)
var _behavior_timer: float = 0.0              # internal timer for behaviors
var _max_travel: float = 60.0                 # max distance before returning
var _sine_amplitude: float = 6.0             # wave height for SINE_WAVE
var _sine_frequency: float = 8.0             # wave speed for SINE_WAVE
var _base_direction: Vector2 = Vector2.RIGHT  # original direction for wave calc
var _split_count: int = 4                     # bullets to spawn on split
var _has_split: bool = false                  # prevent multiple splits
var _accel_rate: float = 200.0               # acceleration per second
var _decel_rate: float = 100.0               # deceleration per second
var _detonated: bool = false                  # prevent multiple detonations
var _orbit_center: Vector2 = Vector2.ZERO     # center point for orbiting
var _orbit_radius: float = 12.0
var _orbit_time: float = 0.6                 # how long to orbit before launching

# Sprite sheet: lofi_obj.png, 128x128, 8x8 tiles (16 cols x 16 rows)
const TILE_SIZE = 8
const SHEET_COLS = 16
# Default projectile indices (into lofi_obj.png)
const DEFAULT_PLAYER_SPRITE = 113  # yellow energy bolt (row 7, col 1)
const DEFAULT_ENEMY_SPRITE = 96   # red fireball (row 6, col 0)

var _obj_texture: Texture2D

func _get_obj_texture() -> Texture2D:
	if not _obj_texture:
		_obj_texture = load("res://assets/sprites/lofi_obj.png") as Texture2D
	return _obj_texture

func _ready() -> void:
	_hits_remaining = pierce_count + 1
	_origin_pos = global_position
	_base_direction = direction

	var sprite = $Sprite2D as Sprite2D
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Determine which sprite to use
	var idx = bullet_sprite_index
	if idx < 0:
		idx = DEFAULT_PLAYER_SPRITE if is_player_bullet else DEFAULT_ENEMY_SPRITE

	# Create atlas texture from lofi_obj.png
	var tex = _get_obj_texture()
	if tex:
		var col = idx % SHEET_COLS
		var row = idx / SHEET_COLS
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(col * TILE_SIZE, row * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		sprite.texture = atlas
	else:
		# Fallback: colored square
		var img = Image.create(3, 3, false, Image.FORMAT_RGBA8)
		img.fill(Color.YELLOW if is_player_bullet else Color(1.0, 0.2, 0.2))
		sprite.texture = ImageTexture.create_from_image(img)

	# Apply enchantment tint
	var tint = Color.WHITE
	if enchant_type >= 0:
		var ench = ItemEnchantment.new()
		ench.type = enchant_type as ItemEnchantment.EnchantType
		tint = ench.get_color().lightened(0.3)
	# Determine scale — larger in overworld to match 4x player/tile scale
	var in_overworld = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var world_mult = 4.0 if in_overworld else 1.0
	if is_crit:
		tint = tint.lightened(0.4)
		sprite.scale = Vector2(0.7, 0.7) * world_mult
	elif is_player_bullet:
		sprite.scale = Vector2(0.5, 0.5) * world_mult
	else:
		sprite.scale = Vector2(0.6, 0.6) * world_mult
	sprite.modulate = tint

	# Rotate sprite to face travel direction
	sprite.rotation = direction.angle()

	# Auto-destroy
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()

	if hits_all:
		collision_layer = 4 | 8  # acts as both player and enemy bullet
		collision_mask = 1 | 2 | 16  # player + enemies + walls
	elif is_player_bullet:
		collision_layer = 4
		collision_mask = 2 | 16  # enemies + walls
	else:
		collision_layer = 8
		collision_mask = 1 | 16  # player + walls

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	_behavior_timer += delta

	# Player bullet homing (equipment-based)
	if homing_strength > 0.0 and is_player_bullet:
		var nearest = _find_nearest_enemy()
		if nearest:
			var desired = (nearest.global_position - global_position).normalized()
			var current_angle = direction.angle()
			var target_angle = desired.angle()
			var new_angle = lerp_angle(current_angle, target_angle, homing_strength * delta)
			direction = Vector2.from_angle(new_angle)

	# Advanced bullet behaviors
	match behavior:
		BulletBehavior.RETURNING:
			var traveled = global_position.distance_to(_origin_pos)
			if traveled > _max_travel:
				# Curve back toward origin
				var to_origin = (_origin_pos - global_position).normalized()
				var cur_angle = direction.angle()
				var tgt_angle = to_origin.angle()
				direction = Vector2.from_angle(lerp_angle(cur_angle, tgt_angle, 5.0 * delta))

		BulletBehavior.ACCELERATING:
			speed += _accel_rate * delta

		BulletBehavior.DECELERATING:
			speed = maxf(speed - _decel_rate * delta, 0.0)
			if speed <= 0.0 and not _detonated:
				_detonated = true
				_detonate_into_bullets()
				queue_free()
				return

		BulletBehavior.SINE_WAVE:
			var perp = _base_direction.rotated(PI / 2.0)
			var wave_offset = sin(_behavior_timer * _sine_frequency) * _sine_amplitude
			position += perp * wave_offset * delta * _sine_frequency

		BulletBehavior.ORBITING:
			if _behavior_timer < _orbit_time:
				# Orbit around center point
				var angle = _behavior_timer * TAU * 2.0  # 2 full rotations during orbit time
				position = _orbit_center + Vector2.RIGHT.rotated(angle) * _orbit_radius
				# Don't apply normal movement
				var s = get_node_or_null("Sprite2D")
				if s:
					s.rotation = (angle + PI / 2.0)
				return  # skip normal movement
			# After orbit time, launch in current direction

		BulletBehavior.SPLITTING:
			if _behavior_timer > 0.4 and not _has_split:
				_has_split = true
				_split_into_bullets()
				queue_free()
				return

		BulletBehavior.HOMING_ENEMY:
			# Enemy bullet that homes toward player
			var player_node = get_tree().get_first_node_in_group("player")
			if player_node and is_instance_valid(player_node):
				var desired = (player_node.global_position - global_position).normalized()
				var cur_angle = direction.angle()
				var tgt_angle = desired.angle()
				direction = Vector2.from_angle(lerp_angle(cur_angle, tgt_angle, 2.5 * delta))

		BulletBehavior.SEEKING_MINE:
			# Very slow, persistent homing
			var player_node = get_tree().get_first_node_in_group("player")
			if player_node and is_instance_valid(player_node):
				var desired = (player_node.global_position - global_position).normalized()
				var cur_angle = direction.angle()
				var tgt_angle = desired.angle()
				direction = Vector2.from_angle(lerp_angle(cur_angle, tgt_angle, 1.0 * delta))

		BulletBehavior.BOOMERANG:
			if _behavior_timer > 0.5 and is_instance_valid(_origin_entity):
				# Curve back toward the entity that fired it
				var to_owner = (_origin_entity.global_position - global_position).normalized()
				var cur_angle = direction.angle()
				var tgt_angle = to_owner.angle()
				direction = Vector2.from_angle(lerp_angle(cur_angle, tgt_angle, 4.0 * delta))
				# Destroy when it gets back near origin entity
				if global_position.distance_to(_origin_entity.global_position) < 6.0 and _behavior_timer > 0.8:
					queue_free()
					return

	position += direction * speed * delta
	# Rotate sprite to match direction
	var s = get_node_or_null("Sprite2D")
	if s:
		s.rotation = direction.angle()

func _on_body_entered(body: Node2D) -> void:
	# Wall collision — destroy bullet
	if body is StaticBody2D and body.collision_layer & 16:
		queue_free()
		return
	if (is_player_bullet or hits_all) and body.has_method("take_damage"):
		body.take_damage(damage)
		_hits_remaining -= 1
		if _hits_remaining <= 0:
			queue_free()

func _on_area_entered(area: Node2D) -> void:
	if (is_player_bullet or hits_all) and area.name == "Hurtbox":
		var enemy = area.get_parent()
		if enemy.has_method("take_damage"):
			var total_dmg = damage + int(enchant_bonus_damage)
			enemy.take_damage(total_dmg)
			if not hits_all:
				_apply_enchant_effect(enemy)
			_hits_remaining -= 1
			if _hits_remaining <= 0:
				queue_free()
	if (not is_player_bullet or hits_all) and area.name == "Hitbox":
		var player = area.get_parent()
		if player.has_method("take_damage"):
			player.take_damage(damage)
		if not hits_all:
			queue_free()
		else:
			_hits_remaining -= 1
			if _hits_remaining <= 0:
				queue_free()

func _apply_enchant_effect(target: Node2D) -> void:
	if enchant_type < 0 or enchant_proc_chance <= 0:
		return
	if randf() * 100.0 >= enchant_proc_chance:
		return

	match enchant_type:
		0:  # FIRE → BURNING
			if target.has_method("apply_status"):
				target.apply_status("BURNING", 3.0)
		1:  # ICE → SLOWED
			if target.has_method("apply_status"):
				target.apply_status("SLOWED", 2.0)
		2:  # POISON → POISONED
			if target.has_method("apply_status"):
				target.apply_status("POISONED", 4.0)
		3:  # LIGHTNING → chain damage to nearby
			var enemies = get_tree().get_nodes_in_group("enemy")
			for e in enemies:
				if e == target or not is_instance_valid(e):
					continue
				if e.global_position.distance_to(target.global_position) < 30.0:
					if e.has_method("take_damage"):
						e.take_damage(maxi(1, damage / 2))
					break
		4:  # HOLY → +50% to undead
			if target.get("definition") and target.definition.get("kingdom") == "undead":
				if target.has_method("take_damage"):
					target.take_damage(maxi(1, damage / 2))
		5:  # DARK → +50% to magical
			if target.get("definition") and target.definition.get("kingdom") == "magical":
				if target.has_method("take_damage"):
					target.take_damage(maxi(1, damage / 2))
		6:  # VAMPIRIC → heal player
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_method("heal"):
				player.heal(maxi(1, damage / 10))
		7:  # EXPLOSIVE → AoE
			var enemies = get_tree().get_nodes_in_group("enemy")
			for e in enemies:
				if e == target or not is_instance_valid(e):
					continue
				if e.global_position.distance_to(global_position) < 20.0:
					if e.has_method("take_damage"):
						e.take_damage(maxi(1, damage / 3))

## Spawn sub-bullets in a ring when this bullet detonates (DECELERATING)
func _detonate_into_bullets() -> void:
	var container = get_parent()
	if not container:
		return
	var count = 6
	for i in range(count):
		var angle = (TAU / count) * i
		var sub = _create_sub_bullet(container, Vector2.RIGHT.rotated(angle), speed + 60.0)
		if sub:
			sub.damage = maxi(1, damage / 2)

## Spawn sub-bullets splitting outward (SPLITTING)
func _split_into_bullets() -> void:
	var container = get_parent()
	if not container:
		return
	for i in range(_split_count):
		var angle = direction.angle() + (float(i) / _split_count - 0.5) * 1.2
		var sub = _create_sub_bullet(container, Vector2.from_angle(angle), speed * 0.8)
		if sub:
			sub.damage = maxi(1, damage / 2)

## Helper: create a sub-bullet from this bullet
func _create_sub_bullet(container: Node, dir: Vector2, spd: float) -> Node2D:
	var scene = load("res://scenes/bullet.tscn")
	if not scene:
		return null
	var sub = scene.instantiate()
	sub.global_position = global_position
	sub.direction = dir
	sub.speed = spd
	sub.is_player_bullet = is_player_bullet
	sub.damage = damage
	sub.lifetime = 2.0
	sub.bullet_sprite_index = bullet_sprite_index
	# Sub-bullets are always NORMAL to prevent infinite recursion
	container.add_child(sub)
	return sub

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
