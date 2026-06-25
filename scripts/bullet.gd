extends Area2D

const PlayerQuery = preload("res://scripts/systems/player_query.gd")
const PROJECTILE_FX_SHADER = preload("res://shaders/combat/projectile_fx.gdshader")

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
var is_melee: bool = false  # melee/swing bullet — blocked by cliff walls (layer 64)

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
var _lob_is_bomb: bool = false
var _lob_shadow: Sprite2D = null
# BARRIER / PULL / PUSH
var barrier_hp: int = 3                      # hits barrier can absorb
var _force_radius: float = 40.0             # pull/push effect radius
var _force_strength: float = 20.0           # pull/push force per tick
var _force_ring_drawn: bool = false         # whether the radius indicator has been created
var _base_sprite_scale: Vector2 = Vector2(0.6, 0.6)  # stored after _ready() for animated behaviors
var movement_pattern: MovementPattern = null
var movement_anchor_entity: Node2D = null
var movement_anchor_point: Vector2 = Vector2.ZERO
var _movement_orbit_angle: float = 0.0
var _movement_base_speed: float = 0.0
var _projectile_scale_mult: float = 1.0
var _projectile_fx_material: ShaderMaterial = null
var _movement_dash_state: int = 0
var _movement_dash_timer: float = 0.0
var _movement_dash_cd: float = 0.0
var _movement_elastic_state: int = 0
var _movement_elastic_vel: Vector2 = Vector2.ZERO
var _movement_elastic_bounces: int = 0
var _movement_bait_state: int = 0
var _movement_bait_timer: float = 0.0
var _movement_bait_prev_dist: float = 0.0
var _movement_wall_dir: Vector2 = Vector2.ZERO
var _movement_edge_dir: Vector2 = Vector2.ZERO
var _movement_edge_wall_timer: float = 0.0
var _movement_mirror_prev_player: Vector2 = Vector2.ZERO
var _movement_intercept_state: int = 0
var _movement_intercept_timer: float = 0.0
var _movement_intercept_target: Vector2 = Vector2.ZERO
var _movement_orbit_radius: float = -1.0
var _movement_orbit_radial_speed: float = 0.0
var _movement_orbit_radial_accel: float = 0.0
var _movement_orbit_reverse_time: float = -1.0
var _movement_orbit_reversed: bool = false

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
	# Render above terrain height layers (max terrain z = 4)
	z_index = 5

	var sprite = $Sprite2D as Sprite2D
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Oryx FX overlay: callers set meta "fx_overlay" to a tile name from the
	# 16-bit FX tilesets. We add a child Sprite2D on top of the regular bullet
	# sprite (named "FxOverlay") so fireball / firebolt / icebolt projectiles
	# read as themselves at travel time instead of the default lofi pellet.
	# The base sprite still gets set up below so enchant tint + tinting logic
	# stays in one place; the overlay just covers it visually.
	if has_meta("fx_overlay"):
		var fx_name := String(get_meta("fx_overlay"))
		var fx_tex = FXAtlasLookup.get_texture(fx_name)
		if fx_tex:
			var overlay := Sprite2D.new()
			overlay.name = "FxOverlay"
			overlay.texture = fx_tex
			overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			overlay.z_index = 1
			# Native FX sprite is ~32px; bullets sit on 8px tiles in dungeons.
			# Default scale of 0.4 → ~13px on-screen, which matches the lofi
			# pellet footprint. Caller can override via "fx_overlay_scale".
			var fx_scale := float(get_meta("fx_overlay_scale", 0.4))
			overlay.scale = Vector2.ONE * fx_scale
			# Rotate the overlay so the sprite (which is drawn facing right on
			# the sheet) aligns with the bullet's travel direction. Without
			# this, every projectile always points east regardless of aim.
			if direction.length() > 0.001:
				overlay.rotation = direction.angle()
			add_child(overlay)
			# Hide the lofi pellet sprite — the overlay replaces it visually.
			sprite.visible = false

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
	var sprite_scale_mult := float(get_meta("sprite_scale_mult", 1.0))
	if sprite_scale_mult != 1.0:
		apply_projectile_scale(sprite_scale_mult)
	_apply_projectile_fx(sprite)
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

	# Melee/swing bullets are blocked by cliff walls (layer 64). Ranged bullets pass through.
	if is_melee:
		collision_mask |= 64

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

func _apply_projectile_fx(sprite: Sprite2D) -> void:
	if sprite == null:
		return
	var fx_kind := _resolve_projectile_fx_kind()
	if fx_kind == 0:
		return
	_projectile_fx_material = ShaderMaterial.new()
	_projectile_fx_material.shader = PROJECTILE_FX_SHADER
	_projectile_fx_material.set_shader_parameter("fx_kind", fx_kind)
	_projectile_fx_material.set_shader_parameter("fx_energy", _resolve_projectile_fx_energy())
	_projectile_fx_material.set_shader_parameter("travel_dir", direction)
	sprite.material = _projectile_fx_material

func _resolve_projectile_fx_kind() -> int:
	if has_meta("projectile_fx_kind"):
		match String(get_meta("projectile_fx_kind")):
			"fire":
				return 1
			"poison":
				return 2
			"frost":
				return 3
			"lightning":
				return 4
			"arcane":
				return 5
	if has_meta("apply_burning") or has_meta("fireball_aoe"):
		return 1
	if has_meta("apply_poison") or has_meta("poison_stackable"):
		return 2
	if has_meta("apply_frozen") or has_meta("apply_slowed"):
		return 3
	if has_meta("chain_lightning_arrow") or has_meta("longshot_paralyze"):
		return 4
	if is_crit:
		return 5
	return 0

func _resolve_projectile_fx_energy() -> float:
	if has_meta("projectile_fx_energy"):
		return float(get_meta("projectile_fx_energy"))
	var energy := 0.65
	if is_crit:
		energy += 0.25
	if has_meta("sprite_scale_mult"):
		energy += clampf((float(get_meta("sprite_scale_mult")) - 1.0) * 0.35, 0.0, 0.5)
	return clampf(energy, 0.3, 1.6)

func apply_projectile_scale(mult: float) -> void:
	if mult <= 0.0:
		return
	if is_equal_approx(mult, _projectile_scale_mult):
		return
	var ratio := mult / _projectile_scale_mult
	_projectile_scale_mult = mult
	var sprite = get_node_or_null("Sprite2D")
	if sprite and sprite is Sprite2D:
		sprite.scale *= ratio
		_base_sprite_scale = sprite.scale
	var hit_shape = get_node_or_null("CollisionShape2D")
	if hit_shape and hit_shape is CollisionShape2D:
		hit_shape.scale *= ratio
		if hit_shape.shape:
			hit_shape.shape = hit_shape.shape.duplicate()
			var shape = hit_shape.shape
			if shape is CircleShape2D:
				shape.radius *= ratio
			elif shape is RectangleShape2D:
				shape.size *= ratio
			elif shape is CapsuleShape2D:
				shape.radius *= ratio
				shape.height *= ratio
			elif shape is SegmentShape2D:
				shape.a *= ratio
				shape.b *= ratio

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	_behavior_timer += delta
	if _movement_base_speed <= 0.0:
		_movement_base_speed = speed

	# Player bullet homing (equipment-based)
	if homing_strength > 0.0 and is_player_bullet:
		var nearest = _find_nearest_enemy()
		if nearest:
			var desired = (nearest.global_position - global_position).normalized()
			var current_angle = direction.angle()
			var target_angle = desired.angle()
			var new_angle = lerp_angle(current_angle, target_angle, homing_strength * delta)
			direction = Vector2.from_angle(new_angle)

	var pattern_handled_movement := false
	if movement_pattern != null:
		pattern_handled_movement = _apply_movement_pattern(delta)
	if _projectile_fx_material != null:
		_projectile_fx_material.set_shader_parameter("travel_dir", direction)

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
			var player_node = PlayerQuery.get_nearest_player(get_tree(), global_position) if is_inside_tree() else null
			if player_node and is_instance_valid(player_node):
				var desired = (player_node.global_position - global_position).normalized()
				var cur_angle = direction.angle()
				var tgt_angle = desired.angle()
				direction = Vector2.from_angle(lerp_angle(cur_angle, tgt_angle, 2.5 * delta))

		BulletBehavior.SEEKING_MINE:
			# Very slow, persistent homing
			var player_node = PlayerQuery.get_nearest_player(get_tree(), global_position) if is_inside_tree() else null
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
			var p = PlayerQuery.get_nearest_player(get_tree(), global_position) if is_inside_tree() else null
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
			var p2 = PlayerQuery.get_nearest_player(get_tree(), global_position) if is_inside_tree() else null
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

	if not pattern_handled_movement:
		position += direction * speed * delta
	# Rotate sprite to match direction (sprites point downward, offset -PI/2)
	var s = get_node_or_null("Sprite2D")
	if s:
		s.rotation = direction.angle() - PI / 2.0

func _apply_movement_pattern(delta: float) -> bool:
	if movement_pattern == null:
		return false
	var target_player = PlayerQuery.get_nearest_player(get_tree(), global_position) if is_inside_tree() else null
	var target_player_velocity := Vector2.ZERO
	if target_player and is_instance_valid(target_player):
		var vel_prop = target_player.get("velocity")
		if vel_prop is Vector2:
			target_player_velocity = vel_prop
	var to_player := Vector2.ZERO
	var dist_to_player := 0.0
	var dir_to_player := direction
	if target_player and is_instance_valid(target_player):
		to_player = target_player.global_position - global_position
		dist_to_player = to_player.length()
		if dist_to_player > 0.01:
			dir_to_player = to_player / dist_to_player
	var speed_scale = maxf(movement_pattern.speed_mult, 0.01)
	match movement_pattern.move_type:
		MovementPattern.MoveType.WEIGHTED:
			if target_player and is_instance_valid(target_player):
				var desired = Vector2.ZERO
				desired += dir_to_player * movement_pattern.approach_weight
				desired -= dir_to_player * movement_pattern.retreat_weight
				var perp_dir = Vector2(-dir_to_player.y, dir_to_player.x)
				desired += perp_dir * movement_pattern.strafe_weight
				if desired.length() > 0.01:
					direction = direction.slerp(desired.normalized(), clampf(delta * 4.0, 0.0, 1.0)).normalized()
				speed = _movement_base_speed * speed_scale
			return false
		MovementPattern.MoveType.ORBIT_POINT:
			_movement_orbit_angle += movement_pattern.orbit_speed * delta
			_tick_orbit_radius(delta)
			var offset = Vector2.RIGHT.rotated(_movement_orbit_angle) * _get_effective_orbit_radius()
			global_position = movement_anchor_point + offset
			direction = offset.orthogonal().normalized() * signf(movement_pattern.orbit_speed)
			return true
		MovementPattern.MoveType.ORBIT_ALLY:
			if movement_anchor_entity and is_instance_valid(movement_anchor_entity):
				_movement_orbit_angle += movement_pattern.orbit_speed * delta
				_tick_orbit_radius(delta)
				var offset = Vector2.RIGHT.rotated(_movement_orbit_angle) * _get_effective_orbit_radius()
				global_position = movement_anchor_entity.global_position + offset
				direction = offset.orthogonal().normalized() * signf(movement_pattern.orbit_speed)
				return true
		MovementPattern.MoveType.ORBIT_PLAYER:
			if target_player and is_instance_valid(target_player):
				_movement_orbit_angle += movement_pattern.orbit_speed * delta
				_tick_orbit_radius(delta)
				var offset = Vector2.RIGHT.rotated(_movement_orbit_angle) * _get_effective_orbit_radius()
				global_position = target_player.global_position + offset
				direction = offset.orthogonal().normalized() * signf(movement_pattern.orbit_speed)
				return true
		MovementPattern.MoveType.PATROL_H:
			var phase_h = sin(_behavior_timer * maxf(movement_pattern.orbit_speed, 0.01))
			var desired_h = movement_anchor_point + Vector2(phase_h * movement_pattern.patrol_length, 0.0)
			var move_h = desired_h - global_position
			if move_h.length() > 0.5:
				direction = move_h.normalized()
				speed = _movement_base_speed * speed_scale
				position += direction * speed * delta
			return true
		MovementPattern.MoveType.PATROL_V:
			var phase_v = sin(_behavior_timer * maxf(movement_pattern.orbit_speed, 0.01))
			var desired_v = movement_anchor_point + Vector2(0.0, phase_v * movement_pattern.patrol_length)
			var move_v = desired_v - global_position
			if move_v.length() > 0.5:
				direction = move_v.normalized()
				speed = _movement_base_speed * speed_scale
				position += direction * speed * delta
			return true
		MovementPattern.MoveType.ZIGZAG:
			var perp = direction.rotated(PI * 0.5)
			var amplitude = maxf(movement_pattern.weave_amplitude, 8.0)
			var wave = sin(_behavior_timer * 8.0) * amplitude
			speed = _movement_base_speed * speed_scale
			position += (direction * speed + perp * wave * 10.0) * delta
			return true
		MovementPattern.MoveType.WALL_BOUNCE:
			speed = _movement_base_speed * speed_scale
			if behavior != BulletBehavior.WALL_BOUNCE:
				behavior = BulletBehavior.WALL_BOUNCE
			if bounce_count <= 0:
				bounce_count = 12
			return false
		MovementPattern.MoveType.DASH_IN_OUT:
			_movement_dash_cd -= delta
			_movement_dash_timer -= delta
			match _movement_dash_state:
				0:
					var to_anchor = movement_anchor_point - global_position
					if to_anchor.length() > 4.0:
						direction = to_anchor.normalized()
						speed = _movement_base_speed * speed_scale * 0.6
						position += direction * speed * delta
						return true
					if _movement_dash_cd <= 0.0:
						_movement_dash_state = 1
						_movement_dash_timer = 1.5
					return true
				1:
					if target_player and is_instance_valid(target_player):
						direction = dir_to_player
					speed = movement_pattern.dash_in_speed
					position += direction * speed * delta
					if dist_to_player < 15.0 or _movement_dash_timer <= 0.0:
						_movement_dash_state = 2
						_movement_dash_timer = movement_pattern.dash_pause
					return true
				2:
					if _movement_dash_timer <= 0.0:
						_movement_dash_state = 3
						_movement_dash_timer = 1.5
					return true
				3:
					var retreat = movement_anchor_point - global_position
					if retreat.length() > 8.0 and _movement_dash_timer > 0.0:
						direction = retreat.normalized()
						speed = movement_pattern.dash_in_speed
						position += direction * speed * delta
					else:
						_movement_dash_state = 0
						_movement_dash_cd = movement_pattern.dash_cooldown
					return true
		MovementPattern.MoveType.KITE:
			if target_player and is_instance_valid(target_player):
				var perp_dir = Vector2(-dir_to_player.y, dir_to_player.x)
				var ideal = movement_pattern.kite_distance
				var margin = 10.0
				if dist_to_player < ideal - margin:
					direction = -dir_to_player
				elif dist_to_player > ideal + margin:
					direction = dir_to_player
				else:
					direction = perp_dir.normalized()
				speed = _movement_base_speed * speed_scale
			return false
		MovementPattern.MoveType.SWOOP:
			if target_player and is_instance_valid(target_player):
				var side_sign = 1.0 if sin(_behavior_timer * 1.4) >= 0.0 else -1.0
				var perp_dir = Vector2(-dir_to_player.y, dir_to_player.x) * side_sign
				direction = (dir_to_player + perp_dir * 2.5).normalized()
				speed = movement_pattern.swoop_speed
			return false
		MovementPattern.MoveType.TELEPORT:
			var tp_timer = float(get_meta("bullet_tp_timer", movement_pattern.teleport_interval))
			tp_timer -= delta
			if tp_timer <= 0.0:
				var target_center = movement_anchor_entity.global_position if movement_anchor_entity and is_instance_valid(movement_anchor_entity) else movement_anchor_point
				var angle = randf() * TAU
				var radius = randf_range(12.0, movement_pattern.teleport_range)
				global_position = target_center + Vector2.from_angle(angle) * radius
				set_meta("bullet_tp_timer", movement_pattern.teleport_interval)
				return true
			set_meta("bullet_tp_timer", tp_timer)
			return false
		MovementPattern.MoveType.MIRROR:
			if target_player and is_instance_valid(target_player):
				if _movement_mirror_prev_player == Vector2.ZERO:
					_movement_mirror_prev_player = target_player.global_position
				var player_delta = target_player.global_position - _movement_mirror_prev_player
				_movement_mirror_prev_player = target_player.global_position
				if player_delta.length() > 0.1:
					global_position += player_delta
					direction = player_delta.normalized()
					return true
			return false
		MovementPattern.MoveType.INTERCEPT:
			if target_player and is_instance_valid(target_player):
				if _movement_intercept_state == 0:
					_movement_intercept_timer += delta
					var orbit_dir = (Vector2(-dir_to_player.y, dir_to_player.x) * 0.8 + dir_to_player * 0.2).normalized()
					direction = orbit_dir
					speed = _movement_base_speed * speed_scale * 0.5
					if _movement_intercept_timer >= 1.0:
						_movement_intercept_target = target_player.global_position + target_player_velocity * movement_pattern.intercept_predict_time
						_movement_intercept_state = 1
						_movement_intercept_timer = movement_pattern.intercept_commit_time
				else:
					_movement_intercept_timer -= delta
					var to_target = _movement_intercept_target - global_position
					if to_target.length() > 5.0 and _movement_intercept_timer > 0.0:
						direction = to_target.normalized()
						speed = _movement_base_speed * speed_scale * 5.0
					else:
						_movement_intercept_state = 0
						_movement_intercept_timer = 0.0
				return false
		MovementPattern.MoveType.ELASTIC:
			var to_anchor = movement_anchor_point - global_position
			var anchor_dist = to_anchor.length()
			var to_anchor_dir = to_anchor.normalized() if anchor_dist > 1.0 else Vector2.ZERO
			match _movement_elastic_state:
				0:
					var tension = clampf(anchor_dist / maxf(movement_pattern.elastic_max_stretch, 1.0), 0.0, 1.0)
					var accel = direction * _movement_base_speed * speed_scale * 3.0 * (1.0 - tension * 0.9)
					var spring_pull = to_anchor_dir * tension * _movement_base_speed * speed_scale * 4.0
					_movement_elastic_vel = (_movement_elastic_vel + (accel + spring_pull) * delta).limit_length(_movement_base_speed * speed_scale * 2.0)
					direction = _movement_elastic_vel.normalized() if _movement_elastic_vel.length() > 0.01 else direction
					position += _movement_elastic_vel * delta
					if anchor_dist >= movement_pattern.elastic_max_stretch:
						_movement_elastic_state = 1
						_movement_elastic_vel = to_anchor_dir * movement_pattern.elastic_whip_speed
						_movement_elastic_bounces = 0
					return true
				1:
					_movement_elastic_vel += to_anchor_dir * movement_pattern.elastic_whip_speed * 3.0 * delta
					_movement_elastic_vel = _movement_elastic_vel.limit_length(movement_pattern.elastic_whip_speed)
					direction = _movement_elastic_vel.normalized() if _movement_elastic_vel.length() > 0.01 else direction
					position += _movement_elastic_vel * delta
					if anchor_dist < 10.0:
						_movement_elastic_state = 2
						_movement_elastic_vel *= 0.6
						_movement_elastic_bounces += 1
					return true
				_:
					_movement_elastic_vel += to_anchor_dir * _movement_base_speed * speed_scale * 6.0 * delta
					_movement_elastic_vel *= (1.0 - 1.5 * delta)
					direction = _movement_elastic_vel.normalized() if _movement_elastic_vel.length() > 0.01 else direction
					position += _movement_elastic_vel * delta
					if anchor_dist < 10.0 and _movement_elastic_vel.length() < _movement_base_speed * speed_scale * 0.3:
						_movement_elastic_state = 0
						_movement_elastic_vel = Vector2.ZERO
					elif anchor_dist < 10.0 and _movement_elastic_bounces < 3:
						_movement_elastic_state = 1
						_movement_elastic_vel *= 0.5
						_movement_elastic_bounces += 1
					return true
		MovementPattern.MoveType.EDGE_SKATER:
			if _movement_edge_dir == Vector2.ZERO:
				var dirs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
				_movement_edge_dir = dirs[randi() % dirs.size()]
			speed = _movement_base_speed * maxf(movement_pattern.edge_skate_speed, 0.01)
			direction = _movement_edge_dir
			_movement_edge_wall_timer += delta
			return false
		MovementPattern.MoveType.BAIT_PUNISH:
			match _movement_bait_state:
				0:
					if target_player and is_instance_valid(target_player):
						direction = -dir_to_player
						speed = _movement_base_speed * speed_scale * 1.2
					_movement_bait_timer += delta
					if _movement_bait_timer >= movement_pattern.bait_flee_time:
						_movement_bait_state = 1
						_movement_bait_timer = 0.0
						_movement_bait_prev_dist = dist_to_player
					return false
				1:
					_movement_bait_timer += delta
					if dist_to_player < _movement_bait_prev_dist - 5.0 or _movement_bait_timer > 0.5:
						_movement_bait_state = 2
						_movement_bait_timer = 1.0
					elif _movement_bait_timer > 1.0:
						_movement_bait_state = 0
						_movement_bait_timer = 0.0
					return true
				_:
					if target_player and is_instance_valid(target_player):
						direction = dir_to_player
						speed = movement_pattern.punish_speed
					_movement_bait_timer -= delta
					if _movement_bait_timer <= 0.0 or dist_to_player < 10.0:
						_movement_bait_state = 0
						_movement_bait_timer = 0.0
					return false
		MovementPattern.MoveType.AMBUSH:
			if target_player and is_instance_valid(target_player):
				if dist_to_player > 40.0:
					direction = dir_to_player
					speed = _movement_base_speed * speed_scale * 0.3
				else:
					speed = 0.0
			return false
		MovementPattern.MoveType.FLEE:
			if target_player and is_instance_valid(target_player):
				direction = -dir_to_player
				speed = _movement_base_speed * speed_scale
	return false

func _get_effective_orbit_radius() -> float:
	if _movement_orbit_radius >= 0.0:
		return _movement_orbit_radius
	return movement_pattern.orbit_radius if movement_pattern != null else 0.0

func _tick_orbit_radius(delta: float) -> void:
	if _movement_orbit_radius < 0.0 and movement_pattern != null:
		_movement_orbit_radius = movement_pattern.orbit_radius
	if _movement_orbit_reverse_time >= 0.0 and not _movement_orbit_reversed and _behavior_timer >= _movement_orbit_reverse_time:
		_movement_orbit_reversed = true
		_movement_orbit_radial_speed = -absf(_movement_orbit_radial_speed)
		if _movement_orbit_radial_accel > 0.0:
			_movement_orbit_radial_accel = -_movement_orbit_radial_accel
	_movement_orbit_radial_speed += _movement_orbit_radial_accel * delta
	_movement_orbit_radius = maxf(0.0, _movement_orbit_radius + _movement_orbit_radial_speed * delta)

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
		# ── Mine breakable wall damage (player bullets only) ──
		if is_player_bullet:
			var tree = get_tree()
			var dm: Node = null
			if tree and tree.current_scene:
				dm = tree.current_scene.get_node_or_null("DungeonManager")
				if dm == null:
					dm = tree.current_scene.get_node_or_null("MineManager")
			if dm and dm.has_method("has_breakable_mine_cell"):
				var tile_pos := Vector2i(int(floor(global_position.x / 8.0)), int(floor(global_position.y / 8.0)))
				# Check the tile we hit + neighbors in bullet direction
				var tiles_to_check: Array[Vector2i] = [tile_pos]
				var dir_tile := Vector2i(roundi(direction.x), roundi(direction.y))
				if dir_tile != Vector2i.ZERO:
					tiles_to_check.append(tile_pos + dir_tile)
				for check_tile in tiles_to_check:
					if dm.has_breakable_mine_cell(check_tile):
						var world_pos := Vector2((check_tile.x + 0.5) * 8.0, (check_tile.y + 0.5) * 8.0)
						var wall_dmg: int = maxi(1, _get_scaled_damage())
						var result: Dictionary = dm.damage_breakable_mine_cell_at(world_pos, wall_dmg)
						if result.get("ok", false):
							var destroyed: bool = result.get("destroyed", false)
							var sfx_mgr = get_node_or_null("/root/SFXManager")
							if sfx_mgr:
								sfx_mgr.play("impact_b" if destroyed else "clack", -6.0, 0.0)
							var vfx_mgr = get_node_or_null("/root/VFXManager")
							if vfx_mgr:
								vfx_mgr.hit_spark(global_position)
							var scene_root = get_tree().current_scene
							if scene_root:
								if destroyed:
									FloatingText.spawn(scene_root, world_pos + Vector2(0, -10), "Mined!", Color(0.9, 0.8, 0.4))
								else:
									var hp_left: int = result.get("hp", 0)
									var kind: String = result.get("kind", "soft")
									var label := kind.capitalize() + " [%d]" % hp_left
									FloatingText.spawn(scene_root, world_pos + Vector2(0, -10), label, Color(0.75, 0.75, 0.75))
						break
		# AoE projectiles (fireball / inferno_lance) detonate on wall hit too —
		# without this the bullet just disappears against a wall with no boom.
		if has_meta("fireball_aoe"):
			_fireball_explode()
		queue_free()
		return
	if _spent:
		return
	if (is_player_bullet or hits_all) and body.has_method("take_damage"):
		if body.is_in_group("enemy"):
			var aggro_player_b = is_player_bullet and not hits_all
			var dmg_b = _get_scaled_damage()
			var is_true_b: bool = has_meta("trap_true_damage") and get_meta("trap_true_damage")
			# Coop: if this enemy is a host-owned proxy on our peer, route damage to host.
			if _coop_route_enemy_damage(body, dmg_b, is_true_b):
				pass
			elif is_true_b:
				body.take_damage(dmg_b, aggro_player_b, CombatTypes.DamageType.TRUE)
			else:
				body.take_damage(dmg_b, aggro_player_b)
		else:
			if has_meta("trap_true_damage") and get_meta("trap_true_damage"):
				body.take_damage(_get_scaled_damage(), global_position, false, false, CombatTypes.DamageType.TRUE)
			else:
				body.take_damage(_get_scaled_damage())
		_hits_remaining -= 1
		if _hits_remaining <= 0:
			_spent = true
			queue_free()

func _on_area_entered(area: Node2D) -> void:
	if _spent:
		return
	# Off-hand throw: passes through enemy bullets, deletes them (up to N total).
	# After the limit runs out, the throw still flies, but stops killing bullets.
	if is_player_bullet and has_meta("offhand_throw"):
		if area is Area2D and area.get("is_player_bullet") != null and not area.is_player_bullet:
			var left = int(get_meta("destroys_bullets_left", 0))
			if left > 0:
				set_meta("destroys_bullets_left", left - 1)
				var vfx_p = get_node_or_null("/root/VFXManager")
				if vfx_p:
					vfx_p.hit_spark(area.global_position, Color(1.0, 1.0, 1.0))
				area.queue_free()
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
			# Parry-marked vulnerability: enemies stunned by a player-parried bullet
			# take 2× damage for 3 seconds. Mercenary identity: hits on a parry-
			# marked enemy use an EXTRA 2× (4× total) and force-crit so crit perks
			# (Lucky Strike, etc.) and crit-damage multiplier all layer on top.
			if is_player_bullet and enemy.has_meta("parry_marked_until"):
				var pm_until = float(enemy.get_meta("parry_marked_until"))
				if Time.get_ticks_msec() / 1000.0 < pm_until:
					var sr_pm = get_tree().current_scene if is_inside_tree() else null
					var _p_pm = PlayerQuery.get_nearest_player(get_tree(), global_position) if is_inside_tree() else null
					var merc_bonus = false
					if _p_pm and _p_pm.has_method("_get_player_class") and _p_pm._get_player_class() == "mercenary":
						total_dmg = int(total_dmg * 3.0)  # 3× base for merc + force crit
						is_crit = true
						merc_bonus = true
					else:
						total_dmg = int(total_dmg * 2.0)  # 2× for other classes
					if sr_pm:
						var label = "PARRY MARK!" if not merc_bonus else "PARRY CRIT!"
						var col = Color(0.85, 0.4, 1.0) if not merc_bonus else Color(1.0, 0.55, 1.0)
						FloatingText.spawn(sr_pm, enemy.global_position + Vector2(0, -10), label, col)
				else:
					enemy.remove_meta("parry_marked_until")
			var aggro_player = is_player_bullet and not hits_all
			var is_true_a: bool = has_meta("trap_true_damage") and get_meta("trap_true_damage")
			# Coop: route through host if this is a proxy enemy on our peer.
			if _coop_route_enemy_damage(enemy, total_dmg, is_true_a):
				pass
			elif is_true_a:
				enemy.take_damage(total_dmg, aggro_player, CombatTypes.DamageType.TRUE)
			else:
				enemy.take_damage(total_dmg, aggro_player)
			# Warrior Blood Dream: vampiric drain on every player-bullet hit.
			# Mercenary Reckless Strike: 5% stun-on-hit while the buff window is open.
			if is_player_bullet and is_inside_tree():
				var _p_bd = PlayerQuery.get_nearest_player(get_tree(), global_position)
				if _p_bd:
					if _p_bd.has_method("apply_blood_dream_lifesteal"):
						_p_bd.apply_blood_dream_lifesteal(total_dmg)
					# Reckless Strike on-hit stun proc.
					if "_reckless_strike_until" in _p_bd \
							and Time.get_ticks_msec() / 1000.0 < _p_bd._reckless_strike_until \
							and _p_bd.has_method("_get_player_class") and _p_bd._get_player_class() == "mercenary" \
							and randf() < 0.05 and enemy.has_method("apply_status"):
						enemy.apply_status("STUNNED", 0.5)
			if not hits_all:
				_apply_enchant_effect(enemy)
			# Ability buff on-hit: Fire Fists → BURNING, Venom Coat → POISONED
			if has_meta("apply_burning") and enemy.has_method("apply_status"):
				enemy.apply_status("BURNING", get_meta("apply_burning"))
			if has_meta("apply_poison") and enemy.has_method("apply_status"):
				enemy.apply_status("POISONED", get_meta("apply_poison"))
			# Parried bullets carry parry_stun_on_hit — mini-stun any enemy they
			# hit (0.7s) and mark them as "parry-vulnerable" for 3 seconds so the
			# player's NEXT attacks against them deal 2× damage.
			if has_meta("parry_stun_on_hit") and enemy.has_method("apply_status"):
				enemy.apply_status("STUNNED", 0.7)
				enemy.set_meta("parry_marked_until", Time.get_ticks_msec() / 1000.0 + 3.0)
			# Off-hand throws weaken enemies on hit
			if has_meta("apply_weaken") and enemy.has_method("apply_status"):
				enemy.apply_status("WEAKENED", get_meta("apply_weaken"))
			# Perk/Item passives: lifesteal, hemorrhage, pyromancer
			if is_player_bullet:
				_apply_player_passive_effects(enemy, total_dmg)
			# Archer Focus meter: build by repeat hits on the same enemy
			if is_player_bullet:
				var _p_focus = PlayerQuery.get_nearest_player(get_tree(), global_position) if is_inside_tree() else null
				if _p_focus and _p_focus.has_method("_get_player_class") and _p_focus._get_player_class() in ["ranger", "archer"]:
					if _p_focus.get("_last_focus_target") == enemy:
						_p_focus.class_meter = minf(_p_focus.class_meter + 8.0, _p_focus.class_meter_max)
					else:
						_p_focus.set("_last_focus_target", enemy)
						# Switching targets caps the meter at half — encourage staying on target
						_p_focus.class_meter = minf(_p_focus.class_meter + 4.0, _p_focus.class_meter_max * 0.5)
					_p_focus.set("_rage_decay_grace", 2.0)
					_p_focus.class_meter_changed.emit(_p_focus.class_meter, _p_focus.class_meter_max)
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
			if has_meta("trap_true_damage") and get_meta("trap_true_damage"):
				player.take_damage(damage, global_position, false, false, CombatTypes.DamageType.TRUE)
			else:
				player.take_damage(damage, global_position)
		# If the player parried us mid-call, take_damage flipped us into a
		# player_bullet via reflect(). Survive — fly back at the source.
		if is_player_bullet:
			return
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
			var player = PlayerQuery.get_nearest_player(get_tree(), global_position) if is_inside_tree() else null
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
	if has_meta("poison_cloud") and bool(get_meta("poison_cloud")):
		var cloud_duration = float(get_meta("poison_cloud_duration", 4.0))
		var cloud_radius = float(get_meta("poison_cloud_radius", _lob_aoe_radius))
		_spawn_poison_cloud(global_position, cloud_radius, cloud_duration)
	# AOE damage
	if not is_player_bullet:
		var p = PlayerQuery.get_nearest_player(get_tree(), global_position) if is_inside_tree() else null
		if p and is_instance_valid(p) and p.global_position.distance_to(global_position) < _lob_aoe_radius:
			if p.has_method("take_damage"):
				p.take_damage(maxi(1, damage), global_position)
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
			sub._lob_duration = 0.55
			sub._lob_height = 1.5
			sub._lob_aoe_radius = _lob_aoe_radius * 0.6
			sub._lob_ring_count = 0
			sub._lob_cluster_count = 0  # prevent infinite recursion
			sub.lifetime = 1.0
			container.add_child(sub)
	queue_free()

func _spawn_poison_cloud(pos: Vector2, radius: float, duration: float) -> void:
	var scene_root = get_tree().current_scene if is_inside_tree() else get_parent()
	if not scene_root:
		return

	var cloud := Node2D.new()
	cloud.global_position = pos

	var hazard := HazardArea.new()
	hazard.damage = 1
	hazard.interval = 0.5
	hazard.status_effect_type = StatusEffect.Type.POISONED
	hazard.status_duration = 4.0
	hazard.status_strength = 1.0

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	hazard.add_child(shape)
	cloud.add_child(hazard)

	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 1.5
	particles.one_shot = false
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = radius
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 5.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 3.0
	particles.color = Color(0.2, 0.8, 0.2, 0.4)
	cloud.add_child(particles)

	scene_root.add_child(cloud)

	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.status_puff(pos, "POISONED")

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = duration
	timer.timeout.connect(cloud.queue_free)
	cloud.add_child(timer)
	timer.start()

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

## Reflect this bullet back (parry). Reverses direction by default, but callers
## can override both the new travel direction and launch speed to match shield
## facing / movement-driven parry logic.
func reflect(new_direction: Vector2 = Vector2.ZERO, speed_mult: float = 1.0, min_speed: float = -1.0) -> void:
	direction = new_direction.normalized() if new_direction.length() > 0.0 else -direction
	is_player_bullet = true
	# Parry-reflected shots fly back at least as fast as a typical player bullet
	# (enemy projectiles are slow on purpose; bouncing one shouldn't feel limp).
	var speed_floor = min_speed if min_speed > 0.0 else 480.0
	var reflect_speed = maxf(speed * 1.5, speed_floor)
	speed = reflect_speed * maxf(speed_mult, 0.1)
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
	# Oryx impact burst — 2-frame flipbook (impact → explosion). Caller can
	# pass either a single string ("fire_explosion") for back-compat or an
	# Array of frame names (["fire_impact", "fire_explosion"]) for the proper
	# 2-frame burst. Footprint ≈ AoE radius × 1.2 so the sprite tracks the
	# real damage zone instead of doubling over it.
	if has_meta("fx_impact"):
		var impact_data = get_meta("fx_impact")
		var frames: Array = []
		if impact_data is Array:
			frames = impact_data
		else:
			frames = [String(impact_data)]
		FXAtlasLookup.spawn_anim(self, frames, global_position, 0.08, aoe_radius * 1.2, 9)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("boom_b", 0.0)

# Coop: route player-bullet damage through host when the hit enemy is a proxy on our
# peer (i.e. host owns the authoritative copy). Returns true if routed — caller must
# skip the local take_damage in that case. Returns false offline or for host-owned hits.
func _coop_route_enemy_damage(enemy: Node, dmg: int, _is_true: bool) -> bool:
	if not is_player_bullet:
		return false
	if enemy == null:
		return false
	var is_proxy: bool = bool(enemy.get("_is_remote_proxy")) if "_is_remote_proxy" in enemy else false
	if not is_proxy:
		return false
	var nid: int = int(enemy.get("network_id")) if "network_id" in enemy else 0
	if nid <= 0:
		return false
	var coop_rt = get_node_or_null("/root/CoopRuntime")
	if coop_rt == null or not coop_rt.has_method("request_enemy_damage"):
		return false
	coop_rt.request_enemy_damage(nid, dmg)
	return true

## Lifesteal / Hemorrhage / Pyromancer triggers (perk OR enchant grants any of these).
func _apply_player_passive_effects(enemy: Node2D, dmg_dealt: int) -> void:
	var player = PlayerQuery.get_nearest_player(get_tree(), global_position) if is_inside_tree() else null
	if not player or not player.has_method("_has_effect"):
		return
	var vfx = get_node_or_null("/root/VFXManager")
	# Warrior Bloodthirst (meter-full move): heal 4% max HP per hit during window
	if player.has_meta("bloodthirst_until"):
		var bt_until = float(player.get_meta("bloodthirst_until"))
		var now_bt = Time.get_ticks_msec() / 1000.0
		if now_bt < bt_until:
			if "max_hp" in player and player.has_method("heal"):
				var heal_amt = maxi(1, int(player.max_hp * 0.04))
				player.heal(heal_amt)
		else:
			player.remove_meta("bloodthirst_until")
	# Lifesteal — heal 5% of damage dealt
	if player._has_effect("lifesteal") and dmg_dealt > 0:
		var heal = maxi(1, int(dmg_dealt * 0.05))
		if player.has_method("heal"):
			player.heal(heal)
		if vfx and vfx.has_method("blood_splatter"):
			vfx.blood_splatter(enemy.global_position, Vector2.ZERO, Color(0.8, 0.1, 0.3))
	# Hemorrhage — 30% chance to apply BLEED (POISONED status with red splash)
	if player._has_effect("hemorrhage") and randf() < 0.30:
		if enemy.has_method("apply_status"):
			enemy.apply_status("POISONED", 4.0)
		if vfx and vfx.has_method("blood_splatter"):
			vfx.blood_splatter(enemy.global_position, Vector2.ZERO, Color(1.0, 0.1, 0.1))
	# Pyromancer — 30% chance to ignite (BURNING)
	if player._has_effect("pyromancer") and randf() < 0.30:
		if enemy.has_method("apply_status"):
			enemy.apply_status("BURNING", 3.0)
		if vfx and vfx.has_method("status_puff"):
			vfx.status_puff(enemy.global_position, "BURNING")
