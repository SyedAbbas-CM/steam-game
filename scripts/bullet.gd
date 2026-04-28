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
var trap_enemy_mult: int = 1  # multiplier for trap damage vs enemies
var distance_scaling: bool = false  # ranger bows: damage scales with distance traveled
var _hits_remaining: int = 1
var _spent: bool = false  # true once hits are used up or absorbed by barrier
var bounce_count: int = 0  # wall bounces remaining (WALL_BOUNCE behavior)
var poison_on_hit: bool = false  # enemy bullet applies POISONED to player

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
	WALL_BOUNCE,     # reflects off walls N times instead of dying
	LOBBED,          # arcs over walls to target position, AOE on landing
	BARRIER,         # stationary, blocks player bullets, has HP
	PULL_ORB,        # slow orb that pulls player toward it
	PUSH_ORB,        # slow orb that pushes player away
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
# LOBBED behavior
var _target_pos: Vector2 = Vector2.ZERO
var _lob_start_pos: Vector2 = Vector2.ZERO
var _lob_duration: float = 0.6
var _lob_height: float = 1.2
var _lob_aoe_radius: float = 16.0
var _lob_ring_count: int = 0
var _lob_cluster_count: int = 0
var _lob_shadow: Sprite2D = null
# BARRIER / PULL / PUSH
var barrier_hp: int = 3                      # hits barrier can absorb
var _force_radius: float = 40.0             # pull/push effect radius
var _force_strength: float = 20.0           # pull/push force per tick
var _force_ring_drawn: bool = false         # whether the radius indicator has been created
var _base_sprite_scale: Vector2 = Vector2(0.6, 0.6)  # stored after _ready() for animated behaviors

# Sprite sheet: lofi_obj.png, 128x128, 8x8 tiles (16 cols x 16 rows)
const TILE_SIZE = 8
const SHEET_COLS = 16
# Default projectile indices (into lofi_obj.png, 16 cols × 16 rows)
const DEFAULT_PLAYER_SPRITE = 224  # blue_magic_basic (0,14)
const DEFAULT_ENEMY_SPRITE = 144   # red_star (0,9)
# Kingdom-colored enemy projectiles
# Each kingdom gets a distinct projectile color/row from lofi_obj.png
const KINGDOM_SPRITES: Dictionary = {
	"undead": 208,   # row 13 — dark/shadow bolt
	"orc": 144,      # row 9 — red fireball
	"demon": 192,    # row 12 — purple/pink
	"animal": 149,   # row 9 col 5 — orange fang
	"magical": 176,  # row 11 — blue magic
	"human": 128,    # row 8 — white arrow
	"crawler": 161,  # row 10 col 1 — green venom
	"mecha": 131,    # row 8 col 3 — grey bolt
}
var enemy_kingdom: String = ""

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
		if is_player_bullet:
			idx = DEFAULT_PLAYER_SPRITE
		elif enemy_kingdom != "" and KINGDOM_SPRITES.has(enemy_kingdom):
			idx = KINGDOM_SPRITES[enemy_kingdom]
		else:
			idx = DEFAULT_ENEMY_SPRITE

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
	if in_overworld:
		if is_crit:
			tint = tint.lightened(0.4)
			sprite.scale = Vector2(5.0, 5.0)
		elif is_player_bullet:
			sprite.scale = Vector2(4.0, 4.0)
		else:
			sprite.scale = Vector2(3.0, 3.0)
		# Shorter lifetime for enemy bullets in overworld so they don't fly forever
		if not is_player_bullet:
			lifetime = minf(lifetime, 1.5)
	else:
		if is_crit:
			tint = tint.lightened(0.4)
			sprite.scale = Vector2(0.7, 0.7)
		elif is_player_bullet:
			sprite.scale = Vector2(0.5, 0.5)
		else:
			sprite.scale = Vector2(0.6, 0.6)
	sprite.modulate = tint
	_base_sprite_scale = sprite.scale

	# Rotate sprite to face travel direction
	# Sprites in lofi_obj.png point downward (PI/2), offset so they aim at target
	sprite.rotation = direction.angle() - PI / 2.0

	# Auto-destroy
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(_on_bullet_expire)
	add_child(timer)
	timer.start()

	if hits_all:
		collision_layer = 8  # enemy bullet layer only (won't trigger traps on layer 4)
		collision_mask = 1 | 2 | 16  # player + enemies + walls
	elif is_player_bullet:
		collision_layer = 4
		collision_mask = 2 | 8 | 16 | 32  # enemies + enemy bullets (barriers) + walls + traps
	else:
		collision_layer = 8
		collision_mask = 1 | 16  # player + walls

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# BARRIER: stationary, blocks player bullets by adding layer 4 to its mask
	if behavior == BulletBehavior.BARRIER:
		collision_mask |= 4  # also collide with player bullets
		speed = 0.0
		lifetime = 5.0

	# PULL/PUSH orbs: slow-moving, longer lifetime
	if behavior == BulletBehavior.PULL_ORB or behavior == BulletBehavior.PUSH_ORB:
		lifetime = maxf(lifetime, 4.0)

	# LOBBED: disable collisions during flight (arc over walls)
	if behavior == BulletBehavior.LOBBED:
		collision_mask = 0
		_lob_start_pos = global_position
		lifetime = _lob_duration + 1.0
		# Ground shadow
		_lob_shadow = Sprite2D.new()
		_lob_shadow.texture = sprite.texture
		_lob_shadow.region_enabled = sprite.region_enabled
		_lob_shadow.region_rect = sprite.region_rect
		_lob_shadow.scale = sprite.scale * 0.6
		_lob_shadow.modulate = Color(0, 0, 0, 0.3)
		_lob_shadow.z_index = 1  # above floor (0) but below walls (2)
		if get_parent():
			get_parent().add_child.call_deferred(_lob_shadow)
		# Bomb trail VFX: orange sparks falling during flight arc
		var trail = CPUParticles2D.new()
		trail.emitting = true
		trail.amount = 8
		trail.lifetime = 0.4
		trail.speed_scale = 1.5
		trail.direction = Vector2(0, 1)  # sparks fall downward
		trail.spread = 30.0
		trail.initial_velocity_min = 5.0
		trail.initial_velocity_max = 15.0
		trail.gravity = Vector2(0, 40)
		trail.scale_amount_min = 0.3
		trail.scale_amount_max = 0.6
		trail.color = Color(1.0, 0.6, 0.1, 0.8)
		trail.color_ramp = Gradient.new()
		trail.color_ramp.set_color(0, Color(1.0, 0.7, 0.2, 0.9))
		trail.color_ramp.set_color(1, Color(1.0, 0.3, 0.0, 0.0))
		add_child(trail)

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
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
			var split_at = get_meta("split_time", 0.4) as float
			if _behavior_timer > split_at and not _has_split:
				_has_split = true
				# VFX: burst on split point
				var vfx = get_node_or_null("/root/VFXManager")
				if vfx:
					vfx.hit_spark(global_position, Color(1.0, 0.4, 0.8))
				var sfx = get_node_or_null("/root/SFXManager")
				if sfx:
					sfx.play("impact_a", -6.0, 0.15)
				_split_into_bullets()
				queue_free()
				return

		BulletBehavior.HOMING_ENEMY:
			# Enemy bullet that homes toward player
			var player_node = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
			if player_node and is_instance_valid(player_node):
				var desired = (player_node.global_position - global_position).normalized()
				var cur_angle = direction.angle()
				var tgt_angle = desired.angle()
				direction = Vector2.from_angle(lerp_angle(cur_angle, tgt_angle, 2.5 * delta))

		BulletBehavior.SEEKING_MINE:
			# Very slow, persistent homing
			var player_node = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
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

		BulletBehavior.LOBBED:
			var t = clampf(_behavior_timer / maxf(_lob_duration, 0.01), 0.0, 1.0)
			global_position = _lob_start_pos.lerp(_target_pos, t)
			var height_factor = 1.0 + _lob_height * 4.0 * t * (1.0 - t)
			var spr = get_node_or_null("Sprite2D")
			if spr:
				spr.scale = _base_sprite_scale * height_factor
			if is_instance_valid(_lob_shadow):
				_lob_shadow.global_position = _lob_start_pos.lerp(_target_pos, t)
			if t >= 1.0:
				_lob_land()
			return

		BulletBehavior.BARRIER:
			# Stationary — pulsate sprite to look alive
			var spr2 = get_node_or_null("Sprite2D")
			if spr2:
				var pulse = 1.0 + 0.15 * sin(_behavior_timer * 4.0)
				spr2.scale = _base_sprite_scale * pulse
			return  # no movement

		BulletBehavior.PULL_ORB:
			# Slow-moving, gently pulls player toward it when in range
			var p = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
			if p and is_instance_valid(p):
				var dist = p.global_position.distance_to(global_position)
				if dist < _force_radius and dist > 4.0:
					var pull_dir = (global_position - p.global_position).normalized()
					var falloff = 1.0 - (dist / _force_radius)
					p.velocity += pull_dir * _force_strength * falloff * delta * 60.0
			# Pulsate purple + radius ring indicator
			var spr3 = get_node_or_null("Sprite2D")
			if spr3:
				var pulse = 1.0 + 0.25 * sin(_behavior_timer * 5.0)
				spr3.scale = _base_sprite_scale * pulse
				spr3.modulate = Color(0.6, 0.3, 1.0, 0.8 + 0.2 * sin(_behavior_timer * 4.0))
			# Draw radius ring
			if not _force_ring_drawn:
				_force_ring_drawn = true
				_create_force_ring(Color(0.5, 0.2, 1.0, 0.25), true)

		BulletBehavior.PUSH_ORB:
			# Slow-moving, pushes player away when in range
			var p2 = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
			if p2 and is_instance_valid(p2):
				var dist2 = p2.global_position.distance_to(global_position)
				if dist2 < _force_radius and dist2 > 4.0:
					var push_dir = (p2.global_position - global_position).normalized()
					var falloff2 = 1.0 - (dist2 / _force_radius)
					p2.velocity += push_dir * _force_strength * falloff2 * delta * 60.0
			var spr4 = get_node_or_null("Sprite2D")
			if spr4:
				var pulse2 = 1.0 + 0.25 * sin(_behavior_timer * 5.0)
				spr4.scale = _base_sprite_scale * pulse2
				spr4.modulate = Color(1.0, 0.9, 0.3, 0.8 + 0.2 * sin(_behavior_timer * 4.0))
			if not _force_ring_drawn:
				_force_ring_drawn = true
				_create_force_ring(Color(1.0, 0.8, 0.2, 0.25), false)

	position += direction * speed * delta
	# Rotate sprite to match direction (sprites point downward, offset -PI/2)
	var s = get_node_or_null("Sprite2D")
	if s:
		s.rotation = direction.angle() - PI / 2.0

func _on_body_entered(body: Node2D) -> void:
	# Wall collision
	if body is StaticBody2D and body.collision_layer & 16:
		if behavior == BulletBehavior.WALL_BOUNCE and bounce_count > 0:
			bounce_count -= 1
			# Use raycast to find actual wall normal for proper reflection
			var space = get_world_2d().direct_space_state
			var ray_len = 6.0
			# Test horizontal and vertical rays to find which wall we hit
			var h_ray = PhysicsRayQueryParameters2D.create(
				global_position, global_position + Vector2(direction.x, 0).normalized() * ray_len, 16)
			var v_ray = PhysicsRayQueryParameters2D.create(
				global_position, global_position + Vector2(0, direction.y).normalized() * ray_len, 16)
			h_ray.exclude = [get_rid()]
			v_ray.exclude = [get_rid()]
			var h_hit = space.intersect_ray(h_ray)
			var v_hit = space.intersect_ray(v_ray)
			if h_hit and (not v_hit or h_hit.get("position", global_position).distance_to(global_position) <= v_hit.get("position", global_position).distance_to(global_position)):
				direction.x = -direction.x
			elif v_hit:
				direction.y = -direction.y
			else:
				# Fallback: reflect the dominant travel axis
				if absf(direction.x) > absf(direction.y):
					direction.x = -direction.x
				else:
					direction.y = -direction.y
			# Nudge away from wall to prevent double-collision
			global_position += direction * 3.0
			var s = get_node_or_null("Sprite2D")
			if s:
				s.rotation = direction.angle() - PI / 2.0
			return
		queue_free()
		return
	if _spent:
		return
	if (is_player_bullet or hits_all) and body.has_method("take_damage"):
		if body.is_in_group("enemy"):
			var aggro_player_b = is_player_bullet and not hits_all
			body.take_damage(_get_scaled_damage(), aggro_player_b)
		else:
			body.take_damage(_get_scaled_damage())
		_hits_remaining -= 1
		if _hits_remaining <= 0:
			_spent = true
			queue_free()

func _on_area_entered(area: Node2D) -> void:
	if _spent:
		return
	# Player bullets are absorbed by barrier bullets
	if is_player_bullet and area.get("behavior") != null and area.behavior == BulletBehavior.BARRIER:
		area.barrier_hp -= 1
		if area.barrier_hp <= 0:
			var vfx = get_node_or_null("/root/VFXManager")
			if vfx:
				vfx.hit_spark(area.global_position, Color.RED)
			area.queue_free()
		else:
			var spr = area.get_node_or_null("Sprite2D")
			if spr:
				spr.modulate = Color.WHITE
				var tw = area.create_tween()
				tw.tween_property(spr, "modulate", Color(0.8, 0.2, 0.2, 0.8), 0.15)
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("impact_b", -6.0, 0.1)
		_spent = true
		queue_free()
		return
	# Player bullets trigger traps on contact
	if is_player_bullet and area.is_in_group("trap") and area.has_method("trigger_remote"):
		area.trigger_remote()
		return

	# Barrier bullets absorb player bullets (fallback — player bullet also handles this)
	if behavior == BulletBehavior.BARRIER and not is_player_bullet:
		if area is Area2D and area.collision_layer & 4:  # player bullet layer
			if area.get("_spent") != null and not area._spent:
				area._spent = true
				area.queue_free()
				barrier_hp -= 1
				var spr = get_node_or_null("Sprite2D")
				if spr:
					spr.modulate = Color.WHITE
					var tw = create_tween()
					tw.tween_property(spr, "modulate", Color(0.8, 0.2, 0.2, 0.8), 0.15)
				var sfx = get_node_or_null("/root/SFXManager")
				if sfx:
					sfx.play("impact_b", -6.0, 0.1)
				if barrier_hp <= 0:
					var vfx = get_node_or_null("/root/VFXManager")
					if vfx:
						vfx.hit_spark(global_position, Color.RED)
					queue_free()
			return

	if _spent:
		return
	if (is_player_bullet or hits_all) and area.name == "Hurtbox":
		var enemy = area.get_parent()
		if enemy.has_method("take_damage"):
			var total_dmg = _get_scaled_damage() + int(enchant_bonus_damage)
			if trap_enemy_mult > 1:
				total_dmg *= trap_enemy_mult
			var aggro_player = is_player_bullet and not hits_all
			enemy.take_damage(total_dmg, aggro_player)
			if not hits_all:
				_apply_enchant_effect(enemy)
			# Ability buff on-hit: Fire Fists → BURNING, Venom Coat → POISONED
			if has_meta("apply_burning") and enemy.has_method("apply_status"):
				enemy.apply_status("BURNING", get_meta("apply_burning"))
			if has_meta("apply_poison") and enemy.has_method("apply_status"):
				enemy.apply_status("POISONED", get_meta("apply_poison"))
			# Longshot paralyze — brief stun
			if has_meta("longshot_paralyze") and enemy.has_method("apply_status"):
				var stun_min = get_meta("longshot_stun_min") if has_meta("longshot_stun_min") else 1.0
				var stun_max = get_meta("longshot_stun_max") if has_meta("longshot_stun_max") else 1.5
				enemy.apply_status("STUNNED", randf_range(stun_min, stun_max))
			# VFX: hit spark (crit gets special spark)
			var vfx = get_node_or_null("/root/VFXManager")
			if vfx:
				if is_crit:
					vfx.crit_spark(global_position)
				else:
					vfx.hit_spark(global_position)
			_hits_remaining -= 1
			if _hits_remaining <= 0:
				if has_meta("fireball_aoe"):
					_fireball_explode()
				_spent = true
				queue_free()
	if _spent:
		return
	if (not is_player_bullet or hits_all) and area.name == "Hitbox":
		var player = area.get_parent()
		if player.has_method("take_damage"):
			player.take_damage(damage, global_position)
		# Poison on hit from enemy bullets
		if poison_on_hit and "status_effects" in player and player.status_effects:
			player.status_effects.apply_status("POISONED", 4.0)
		if not hits_all:
			_spent = true
			queue_free()
		else:
			_hits_remaining -= 1
			if _hits_remaining <= 0:
				_spent = true
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
			var player = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
			if player and player.has_method("heal"):
				player.heal(maxi(1, damage / 10))
		7:  # EXPLOSIVE → AoE
			if not is_inside_tree():
				return
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

func _lob_land() -> void:
	# Clean up shadow
	if is_instance_valid(_lob_shadow):
		_lob_shadow.queue_free()
	# Stone toss: zero damage = noise distraction instead of AOE
	if damage == 0 and is_player_bullet:
		var vfx_s = get_node_or_null("/root/VFXManager")
		if vfx_s:
			vfx_s.hit_spark(global_position, Color(0.6, 0.6, 0.6))
		var sfx_s = get_node_or_null("/root/SFXManager")
		if sfx_s:
			sfx_s.play("click", -4.0)
		# Alert nearby enemies + direct hit = CONFUSED
		if is_inside_tree():
			for e in get_tree().get_nodes_in_group("enemy"):
				if not is_instance_valid(e):
					continue
				var d = e.global_position.distance_to(global_position)
				# Direct hit: very close to landing point → confuse
				if d < 6.0 and e.has_method("apply_status"):
					e.apply_status("CONFUSED", 3.0)
				elif e.has_method("hear_noise"):
					e.hear_noise(global_position, 40.0)
			# Trigger nearby traps (burst, poison, etc.)
			for t in get_tree().get_nodes_in_group("trap"):
				if is_instance_valid(t) and t.global_position.distance_to(global_position) < 16.0:
					if t.has_method("trigger_remote"):
						t.trigger_remote()
		queue_free()
		return
	# VFX
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position, _lob_aoe_radius, Color(1.0, 0.6, 0.1, 0.7))
		vfx.shake(1.5, 0.12)
	# AOE damage
	if not is_player_bullet:
		var p = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
		if p and is_instance_valid(p) and p.global_position.distance_to(global_position) < _lob_aoe_radius:
			if p.has_method("take_damage"):
				p.take_damage(damage, global_position)
	else:
		for e in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(e) and e.global_position.distance_to(global_position) < _lob_aoe_radius:
				if e.has_method("take_damage"):
					e.take_damage(damage)
	# Optional bullet ring on impact
	var container = get_parent()
	if _lob_ring_count > 0 and container:
		for i in range(_lob_ring_count):
			var angle = (TAU / _lob_ring_count) * i
			var sub = _create_sub_bullet(container, Vector2.from_angle(angle), 70.0)
			if sub:
				sub.damage = maxi(1, damage / 3)
				sub.lifetime = 1.2
	# Optional cluster sub-bombs
	if _lob_cluster_count > 0 and container:
		var scene = load("res://scenes/bullet.tscn")
		for i in range(_lob_cluster_count):
			var offset = Vector2.from_angle(TAU / _lob_cluster_count * i) * randf_range(10.0, 18.0)
			var sub = scene.instantiate()
			sub.global_position = global_position
			sub.direction = offset.normalized()
			sub.is_player_bullet = is_player_bullet
			sub.damage = maxi(1, damage / 2)
			sub.bullet_sprite_index = bullet_sprite_index
			sub.behavior = BulletBehavior.LOBBED
			sub._target_pos = global_position + offset
			sub._lob_duration = 0.35
			sub._lob_height = 1.5
			sub._lob_aoe_radius = _lob_aoe_radius * 0.6
			sub._lob_ring_count = 0
			sub._lob_cluster_count = 0  # prevent infinite recursion
			sub.lifetime = 1.0
			container.add_child(sub)
	queue_free()

## Visual ring indicator for pull/push orbs showing their effect radius
class _ForceRingDraw extends Node2D:
	var ring_color: Color = Color.WHITE
	var ring_radius: float = 40.0
	var is_pull: bool = true
	var _elapsed: float = 0.0
	func _process(delta: float) -> void:
		_elapsed += delta
		queue_redraw()
	func _draw() -> void:
		# Pulsing ring that contracts (pull) or expands (push)
		var pulse = 0.85 + 0.15 * sin(_elapsed * 3.0)
		var r = ring_radius * pulse
		var alpha = ring_color.a * (0.6 + 0.4 * sin(_elapsed * 4.0))
		var c = Color(ring_color.r, ring_color.g, ring_color.b, alpha)
		# Draw dashed circle
		var segments = 24
		for i in range(segments):
			if i % 2 == 0:
				var a1 = TAU / segments * i
				var a2 = TAU / segments * (i + 1)
				draw_line(Vector2.from_angle(a1) * r, Vector2.from_angle(a2) * r, c, 0.5)
		# Draw arrows pointing inward (pull) or outward (push)
		var arrow_count = 4
		for i in range(arrow_count):
			var angle = TAU / arrow_count * i + _elapsed * (1.5 if is_pull else -1.5)
			var tip_r = r * (0.7 if is_pull else 1.0)
			var base_r = r * (1.0 if is_pull else 0.7)
			var tip = Vector2.from_angle(angle) * tip_r
			var base_pt = Vector2.from_angle(angle) * base_r
			draw_line(base_pt, tip, c, 0.6)

func _create_force_ring(color: Color, is_pull: bool) -> void:
	var ring = _ForceRingDraw.new()
	ring.ring_color = color
	ring.ring_radius = _force_radius
	ring.is_pull = is_pull
	add_child(ring)

## Reflect this bullet back (parry). Reverses direction, makes it a player bullet.
func reflect() -> void:
	direction = -direction
	is_player_bullet = true
	# Reset collision layers for player bullet
	collision_layer = 4
	collision_mask = 2 | 8 | 16 | 32  # enemies + enemy bullets + walls + traps
	# Visual feedback: bright tint
	var spr = get_node_or_null("Sprite2D")
	if spr:
		spr.modulate = Color(2.0, 2.0, 2.0)
		spr.rotation = direction.angle() - PI / 2.0

func _get_scaled_damage() -> int:
	if not distance_scaling:
		return damage
	var dist_traveled = global_position.distance_to(_origin_pos)
	var max_dist = speed * lifetime
	if max_dist <= 0:
		return damage
	var range_ratio = dist_traveled / max_dist
	# Below 50% range: half damage (min 1). At 50%+ range: full damage.
	if range_ratio < 0.5:
		return maxi(1, damage / 2)
	return damage

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

func _on_bullet_expire() -> void:
	if has_meta("fireball_aoe"):
		_fireball_explode()
	queue_free()

func _fireball_explode() -> void:
	var aoe_radius = get_meta("fireball_aoe_radius", 20.0)
	var dmg_pct = get_meta("fireball_aoe_dmg_pct", 0.6)
	var aoe_dmg = int(damage * dmg_pct)
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if global_position.distance_to(e.global_position) > aoe_radius:
			continue
		if e.has_method("take_damage"):
			e.take_damage(aoe_dmg)
		if e.has_method("apply_status"):
			e.apply_status("BURNING", 3.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position, aoe_radius, Color(1.0, 0.4, 0.1, 0.7))
		vfx.shake(2.0, 0.15)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("boom_b", 0.0)
