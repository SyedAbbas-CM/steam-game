extends CharacterBody2D

enum State { IDLE, CHASE, ATTACK, COOLDOWN, CHARGING, DEAD, STEALTHED, INVESTIGATE }

var definition: EnemyDefinition
var hp: int = 3
var shield_hp: int = 0
var armor: int = 0  # flat damage reduction
var speed: float = 20.0
var shoot_interval: float = 1.5
var state: State = State.IDLE
var attack_timer: float = 0.0
var cooldown_timer: float = 0.0
var charge_timer: float = 0.0
var charge_dir: Vector2 = Vector2.ZERO
var player: Node2D
var _trail_timer: float = 0.0
var _stealth_timer: float = 0.0
var _beam_timer: float = 0.0
var _beam_angle: float = 0.0
var _spiral_angle: float = 0.0
var _los_check_timer: float = 0.0
var _chase_timer: float = 0.0  # how long we've been chasing
var _hit_aggro_timer: float = 0.0  # prevents de-aggro for a few seconds after being hit
const CHASE_TIMEOUT = 8.0  # give up after this many seconds
var _wander_timer: float = 0.0  # time until next wander direction change
var _wander_dir: Vector2 = Vector2.ZERO  # current wander direction
var _stuck_timer: float = 0.0  # detect if stuck on wall
var _hold_timer: float = 0.0  # ranged enemies reposition after holding ground
var _last_pos: Vector2 = Vector2.ZERO
# Melee combat behavior
var _melee_dodge_timer: float = 0.0  # countdown to next side-dodge
var _melee_dodge_dir: float = 1.0  # +1 or -1 for strafe direction
var _melee_flank_timer: float = 0.0  # time spent circling before closing in
var _melee_lunge_cd: float = 0.0  # cooldown for dash-lunge attacks
# INVESTIGATE state
var _investigate_pos: Vector2 = Vector2.ZERO
var _investigate_timer: float = 0.0
var _investigate_look_timer: float = 0.0
var _investigate_dir: Vector2 = Vector2.ZERO  # direction to continue searching past investigate_pos
var _investigate_phase: int = 0  # 0=walk to pos, 1=continue in dir, 2=look around
# Last known player tracking (updated while chasing)
var _last_known_player_pos: Vector2 = Vector2.ZERO
var _last_known_player_dir: Vector2 = Vector2.ZERO
# Wrestling throw
var _thrown_timer: float = 0.0
var _thrown_velocity: Vector2 = Vector2.ZERO
var _thrower_dmg: int = 0
var _loy_sprite: Sprite2D  # separate sprite for LoY characters
# Nudge from dash knockback
var _nudge_timer: float = 0.0
var _nudge_velocity: Vector2 = Vector2.ZERO
# Awareness meter (gradual aggro)
var _awareness: float = 0.0  # 0.0–1.0: unaware → suspicious → alert
var _awareness_indicator: Label  # ? or ! above sprite
var _current_phase: int = 1
var _max_hp: int = 0
var _animator: SpriteAnimator
var _nav: RefCounted  # DungeonNav flow-field navigation (set by dungeon manager)
var _dm: Node  # DungeonManager ref for obstacle breaking (set by dungeon manager)

# Boss/Elite behavior vars
var _enraged: bool = false
var _slam_timer: float = 7.0  # boss ground slam cooldown
var _break_timer: float = 0.0  # obstacle breaking check timer
var _elite_taunt_done: bool = false  # elite aggro taunt animation
var _boss_shadow: Node2D  # pulsing shadow under boss
var _boss_name_label: Label  # name label above boss

# Random attack pool for elites/bosses
var _attack_pool: Array[int] = []  # random attack types assigned on setup
var _attack_pool_idx: int = 0  # cycles through pool

# Behavioral overhaul: Mummy bodyguard / Arch Mage shared vision
var _attached_ally: Node2D           # mummy bodyguard target
var _bodyguard_mode: bool = false    # following ally instead of player
var _shared_vision_has_los: bool = false  # cached: does any nearby ally see player?
var _shared_vision_checked: bool = false  # one-time shared vision performed?

# Boss HP bar
var _hp_bar_bg: ColorRect
var _hp_bar_fill: ColorRect

# Boss HP regen
var _time_since_hit: float = 0.0
var _regen_accum: float = 0.0
var _is_boss_or_large: bool = false

var bullet_scene: PackedScene
var pickup_scene: PackedScene
var _contact_cooldown: float = 0.0  # prevents rapid contact damage ticks
var _knockback_timer: float = 0.0  # prevents movement override during knockback
var _weight: float = 1.0  # mass for collision momentum damage

@export var drop_table: DropTable

func _get_bullets_container() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("bullets")

func _ready() -> void:
	bullet_scene = preload("res://scenes/bullet.tscn")
	pickup_scene = preload("res://scenes/pickup.tscn")
	collision_layer = 2
	collision_mask = 17  # collide with walls (16) + player (1)
	add_to_group("enemy")
	if is_inside_tree():
		player = get_tree().get_first_node_in_group("player")

func setup(def: EnemyDefinition) -> void:
	definition = def
	hp = def.max_hp
	_max_hp = def.max_hp
	shield_hp = def.shield_hp
	armor = def.armor
	speed = def.move_speed
	shoot_interval = def.attack_speed
	drop_table = def.drop_table

	if def.use_loy_sprite and def.loy_tile_index >= 0:
		_setup_loy_sprite(def.loy_tile_index)
	else:
		$Sprite2D.frame = def.sprite_frame
		$Sprite2D.scale = Vector2(1, 1)  # native 8x8 sprites stay 8px (1 tile)

	$Sprite2D.modulate = def.sprite_color

	# Scale and weight for large/boss enemies
	# Only scale the sprite — scaling the whole node makes hitboxes huge in dungeons
	var spr = $Sprite2D
	var loy_spr = get_node_or_null("LoYSprite")
	var size_mult = 1.0
	match def.size_class:
		EnemyDefinition.SizeClass.NORMAL:
			_weight = 1.0
		EnemyDefinition.SizeClass.LARGE:
			size_mult = 2.0
			_weight = 2.5
		EnemyDefinition.SizeClass.BOSS:
			size_mult = 3.0
			_weight = 5.0
	if size_mult > 1.0:
		if spr: spr.scale *= size_mult
		if loy_spr: loy_spr.scale *= size_mult

	# Enlarge hitboxes for overworld enemies (32px tiles, need bigger targets)
	var dm = get_tree().get_first_node_in_group("dungeon_manager") if is_inside_tree() else null
	if not dm:
		var hurtbox_shape = get_node_or_null("Hurtbox/CollisionShape2D")
		if hurtbox_shape and hurtbox_shape.shape is CircleShape2D:
			hurtbox_shape.shape = hurtbox_shape.shape.duplicate()
			hurtbox_shape.shape.radius *= 2.5
		var body_shape = get_node_or_null("CollisionShape2D")
		if body_shape and body_shape.shape is RectangleShape2D:
			body_shape.shape = body_shape.shape.duplicate()
			body_shape.shape.size *= 2.5

	# Ghost enemies phase through walls
	if def.ignores_terrain:
		$Sprite2D.modulate.a = 0.7
		collision_mask = 1  # ghosts phase through walls but still collide with player

	# Boss/Large HP bar
	_is_boss_or_large = def.size_class >= EnemyDefinition.SizeClass.LARGE
	if _is_boss_or_large:
		_create_boss_hp_bar()

	# Boss: name label + pulsing shadow
	if def.size_class >= EnemyDefinition.SizeClass.BOSS:
		_create_boss_name_label(def.enemy_name)
		_create_boss_shadow()

	# Assign random attack pool for elites/bosses
	if _is_boss_or_large:
		_assign_random_attack_pool(def)

	# Awareness indicator (? or !) above sprite
	_awareness_indicator = Label.new()
	_awareness_indicator.text = "?"
	_awareness_indicator.add_theme_font_size_override("font_size", 6)
	_awareness_indicator.add_theme_color_override("font_color", Color.YELLOW)
	_awareness_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_awareness_indicator.position = Vector2(-3, -14)
	_awareness_indicator.visible = false
	_awareness_indicator.z_index = 10
	add_child(_awareness_indicator)

	state = State.IDLE

# Interesting attacks for random pool (excludes basic NONE/MELEE/RANGED/SPLIT/STEALTH/HEAL)
const ATTACK_POOL_CANDIDATES: Array = [
	EnemyDefinition.AttackType.BURST,
	EnemyDefinition.AttackType.SPIRAL,
	EnemyDefinition.AttackType.BEAM,
	EnemyDefinition.AttackType.VOLLEY,
	EnemyDefinition.AttackType.CROSS_SHOT,
	EnemyDefinition.AttackType.WAVE_SHOT,
	EnemyDefinition.AttackType.GATLING,
	EnemyDefinition.AttackType.MORTAR,
	EnemyDefinition.AttackType.NOVA,
	EnemyDefinition.AttackType.ZIGZAG,
	EnemyDefinition.AttackType.SHOTGUN_BLAST,
	EnemyDefinition.AttackType.HELIX,
	EnemyDefinition.AttackType.METEOR_SHOWER,
	EnemyDefinition.AttackType.BOOMERANG_SHOT,
	EnemyDefinition.AttackType.STRAFE_RUN,
	EnemyDefinition.AttackType.MINEFIELD,
	EnemyDefinition.AttackType.RETURNING_VOLLEY,
	EnemyDefinition.AttackType.SEEKING_MINES,
	EnemyDefinition.AttackType.DETONATOR,
	EnemyDefinition.AttackType.SPLITTER,
	EnemyDefinition.AttackType.SINE_BARRAGE,
	EnemyDefinition.AttackType.HOMING_SALVO,
	EnemyDefinition.AttackType.TELEGRAPH_EXPLOSION,
	EnemyDefinition.AttackType.ORBIT_LAUNCH,
	EnemyDefinition.AttackType.WALL_BOUNCE,
	EnemyDefinition.AttackType.LASER_GRID,
	EnemyDefinition.AttackType.GRAVITY_WELL,
	EnemyDefinition.AttackType.CHAIN_LIGHTNING,
	EnemyDefinition.AttackType.DEATH_SPIRAL,
	EnemyDefinition.AttackType.BOMB_TOSS,
	EnemyDefinition.AttackType.CARPET_BOMB,
	EnemyDefinition.AttackType.FIRE_RAIN,
	EnemyDefinition.AttackType.CLUSTER_BOMB,
	EnemyDefinition.AttackType.MINE_DROP,
	EnemyDefinition.AttackType.BARRIER_WALL,
	EnemyDefinition.AttackType.PULL_SHOT,
	EnemyDefinition.AttackType.PUSH_WAVE,
]

func _assign_random_attack_pool(def: EnemyDefinition) -> void:
	var is_boss = def.size_class >= EnemyDefinition.SizeClass.BOSS
	var pool_size = 3 if is_boss else 2
	# Always include the enemy's native attack (if it's interesting)
	_attack_pool.clear()
	var native = def.attack_type
	if native in ATTACK_POOL_CANDIDATES:
		_attack_pool.append(native)
	# Also include phase attacks if they exist
	if def.phase_2_attack != EnemyDefinition.AttackType.NONE and def.phase_2_attack in ATTACK_POOL_CANDIDATES:
		if def.phase_2_attack not in _attack_pool:
			_attack_pool.append(def.phase_2_attack)
	if def.phase_3_attack != EnemyDefinition.AttackType.NONE and def.phase_3_attack in ATTACK_POOL_CANDIDATES:
		if def.phase_3_attack not in _attack_pool:
			_attack_pool.append(def.phase_3_attack)
	# Fill remaining slots with random picks
	var candidates = ATTACK_POOL_CANDIDATES.duplicate()
	candidates.shuffle()
	for c in candidates:
		if _attack_pool.size() >= pool_size:
			break
		if c not in _attack_pool:
			_attack_pool.append(c)
	_attack_pool.shuffle()
	_attack_pool_idx = 0

func _next_pool_attack() -> int:
	if _attack_pool.is_empty():
		return EnemyDefinition.AttackType.BURST
	var atk = _attack_pool[_attack_pool_idx]
	_attack_pool_idx = (_attack_pool_idx + 1) % _attack_pool.size()
	return atk

func _create_boss_hp_bar() -> void:
	# Use a top-level Node2D to avoid inheriting enemy scale
	var bar_anchor = Node2D.new()
	bar_anchor.top_level = true  # ignores parent transform
	bar_anchor.z_index = 10
	add_child(bar_anchor)

	var bar_w = 20.0  # fixed world pixels
	var bar_h = 2.0

	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = Color(0.15, 0.15, 0.15, 0.9)
	_hp_bar_bg.size = Vector2(bar_w, bar_h)
	_hp_bar_bg.position = Vector2(-bar_w / 2, 6)
	bar_anchor.add_child(_hp_bar_bg)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color = Color(0.1, 0.8, 0.15)
	_hp_bar_fill.size = Vector2(bar_w, bar_h)
	_hp_bar_fill.position = Vector2(-bar_w / 2, 6)
	bar_anchor.add_child(_hp_bar_fill)

func _update_boss_hp_bar() -> void:
	if _hp_bar_fill and _max_hp > 0:
		var ratio = clampf(float(hp) / float(_max_hp), 0.0, 1.0)
		var bar_w = 20.0
		_hp_bar_fill.size.x = bar_w * ratio
		# Green when healthy, red when low
		_hp_bar_fill.color = Color(0.1 + 0.8 * (1.0 - ratio), 0.8 * ratio, 0.1)
	# Keep bar following enemy position
	if _hp_bar_bg:
		_hp_bar_bg.get_parent().global_position = global_position

func _create_boss_name_label(boss_name: String) -> void:
	var anchor = Node2D.new()
	anchor.top_level = true
	anchor.z_index = 10
	add_child(anchor)
	_boss_name_label = Label.new()
	_boss_name_label.text = boss_name
	_boss_name_label.add_theme_font_size_override("font_size", 8)
	_boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_boss_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_boss_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_boss_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.position = Vector2(-30, -16)
	_boss_name_label.size = Vector2(60, 12)
	anchor.add_child(_boss_name_label)

func _create_boss_shadow() -> void:
	_boss_shadow = Node2D.new()
	_boss_shadow.z_index = -1
	add_child(_boss_shadow)
	# Draw a dark oval under boss
	var shadow_draw = _BossShadowDraw.new()
	_boss_shadow.add_child(shadow_draw)

class _BossShadowDraw extends Node2D:
	var _elapsed: float = 0.0
	func _process(delta: float) -> void:
		_elapsed += delta
		queue_redraw()
	func _draw() -> void:
		var alpha = 0.2 + 0.1 * sin(_elapsed * 3.0)
		draw_circle(Vector2.ZERO, 10.0, Color(0.1, 0.0, 0.15, alpha))

func _setup_loy_sprite(tile_index: int) -> void:
	var tex_path = LoySpriteIndex.get_char_texture_path(tile_index)
	var region = LoySpriteIndex.get_char_region(tile_index)
	var tex = load(tex_path) as Texture2D
	if not tex:
		return
	var atlas = AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = region
	$Sprite2D.texture = atlas
	# Reset hframes/vframes so the AtlasTexture isn't subdivided
	$Sprite2D.hframes = 1
	$Sprite2D.vframes = 1
	$Sprite2D.frame = 0
	# LoY sprites are 32x32, scale to 8px (1 tile, same as player)
	$Sprite2D.scale = Vector2(0.25, 0.25)

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	if state == State.DEAD:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
		if not player:
			return

	# Tick hit aggro timer (global, not just in chase)
	if _hit_aggro_timer > 0:
		_hit_aggro_timer -= delta

	# Boss HP regen (1% max HP/sec after 3s without taking damage)
	_time_since_hit += delta
	if _is_boss_or_large and _time_since_hit > 3.0 and hp < _max_hp:
		_regen_accum += delta
		if _regen_accum >= 1.0:
			_regen_accum -= 1.0
			hp = mini(hp + maxi(1, _max_hp / 100), _max_hp)
			_update_boss_hp_bar()

	# Keep HP bar following enemy
	if _hp_bar_bg:
		_hp_bar_bg.get_parent().global_position = global_position

	# Keep boss name label following
	if _boss_name_label:
		_boss_name_label.get_parent().global_position = global_position

	# Boss enrage at <30% HP
	if not _enraged and definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS:
		if hp < _max_hp * 0.3 and hp > 0:
			_enraged = true
			$Sprite2D.modulate = Color(1.5, 0.4, 0.4)
			var vfx_en = get_node_or_null("/root/VFXManager")
			if vfx_en:
				vfx_en.shockwave(global_position, 20.0, Color(1.0, 0.2, 0.1, 0.5))
				vfx_en.shake(2.0, 0.15)
			var sfx_en = get_node_or_null("/root/SFXManager")
			if sfx_en:
				sfx_en.play("special_b", -2.0, 0.05)

	# Boss ground slam (periodic AoE)
	if definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS and state == State.CHASE:
		_slam_timer -= delta
		if _slam_timer <= 0:
			_slam_timer = 5.0 if _enraged else 7.0
			_do_ground_slam()

	# Elite yellow glow pulse
	if definition and definition.size_class == EnemyDefinition.SizeClass.LARGE and not _enraged:
		var t = Time.get_ticks_msec() / 1000.0
		var glow = Color(1.0 + 0.15 * sin(t * 3.0), 1.0 + 0.1 * sin(t * 3.0), 0.7)
		$Sprite2D.modulate = glow

	# Boss/Elite obstacle breaking — always active regardless of state
	# Break faster when stuck (velocity near zero while chasing)
	if _is_boss_or_large and _dm:
		var _stuck = state == State.CHASE and velocity.length() < speed * 0.2
		_break_timer -= delta
		if _break_timer <= 0:
			_break_timer = 0.1 if _stuck else 0.3  # break faster when stuck
			_break_nearby_obstacles()

	var to_player = player.global_position - global_position
	var dist = to_player.length()
	var dir = to_player.normalized() if dist > 0 else Vector2.ZERO

	if dir.x < 0:
		$Sprite2D.flip_h = true
	elif dir.x > 0:
		$Sprite2D.flip_h = false

	var aggro_range = 100.0
	if definition:
		aggro_range = definition.aggro_range if definition.aggro_range > 0 else 100.0
	# Player stealth now handled via awareness ramp rate (stealth_factor)

	# Leash check: overworld enemies must stay near their spawn zone
	# Skip leash if recently hit — let them chase for a bit
	if has_meta("spawn_pos") and has_meta("leash_radius") and _hit_aggro_timer <= 0:
		var _sp = get_meta("spawn_pos") as Vector2
		var _lr = get_meta("leash_radius") as float
		if _lr > 0 and global_position.distance_to(_sp) > _lr + 200:
			# Too far from spawn — return home via investigate to spawn
			_investigate_pos = _sp
			_investigate_dir = Vector2.ZERO
			_investigate_phase = 0
			_investigate_timer = 0.0
			state = State.INVESTIGATE
			_chase_timer = 0.0
			global_position = global_position.move_toward(_sp, speed * delta * 2)
			move_and_slide()
			return

	# Knockback separation: skip movement AI during knockback to prevent sticking
	if _knockback_timer > 0:
		_knockback_timer -= delta
		move_and_slide()
		_contact_cooldown -= delta
		return

	# Continuous overlap resolution: if still overlapping player, push apart directly
	var _overlap_player = player if is_instance_valid(player) else null
	if _overlap_player and state != State.DEAD:
		var _sep_dist = global_position.distance_to(_overlap_player.global_position)
		var _min_sep = 6.0 * scale.x  # minimum separation distance
		if _sep_dist < _min_sep:
			var _sep_dir = (global_position - _overlap_player.global_position).normalized()
			if _sep_dir == Vector2.ZERO:
				_sep_dir = Vector2.RIGHT.rotated(randf() * TAU)
			# Teleport apart — velocity-based separation doesn't work for overlapping CharacterBody2D
			global_position += _sep_dir * (_min_sep - _sep_dist + 2.0)

	# Passive-until-hit: don't aggro until damaged
	var is_passive = has_meta("passive_until_hit") and get_meta("passive_until_hit")
	var should_wander = has_meta("behavior") and get_meta("behavior") == "wander"

	match state:
		State.IDLE:
			_chase_timer = 0.0
			# Wander behavior: move randomly within leash radius
			if should_wander or is_passive:
				_wander_timer -= delta
				if _wander_timer <= 0:
					_wander_timer = 1.5 + randf() * 2.5
					if randf() < 0.7:  # 70% chance to pick a direction, 30% stand still
						_wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
					else:
						_wander_dir = Vector2.ZERO
				velocity = _wander_dir * speed * 0.6
				if _wander_dir.x < 0:
					$Sprite2D.flip_h = true
				elif _wander_dir.x > 0:
					$Sprite2D.flip_h = false
			else:
				velocity = Vector2.ZERO
			# Awareness ramp/decay (skip if passive)
			if not is_passive:
				# LOS check is expensive — do it periodically, cache result
				var _player_sneaking = is_instance_valid(player) and player.has_method("is_sneaking") and player.is_sneaking()
				# Sneaking halves effective detection range
				var eff_aggro_range = aggro_range * 0.4 if _player_sneaking else aggro_range
				_los_check_timer -= delta
				if _los_check_timer <= 0:
					_los_check_timer = 0.3 + randf() * 0.2
					var has_los = _has_line_of_sight_or_shared()
					var can_see = has_los and dist < eff_aggro_range
					if not can_see and _is_boss_or_large and dist < eff_aggro_range * 0.3:
						can_see = true
					set_meta("_cached_can_see", can_see)
				# Ramp/decay awareness every frame using cached LOS result
				var can_see_cached = get_meta("_cached_can_see", false) as bool
				if can_see_cached:
					var dist_factor = 1.0 - clampf(dist / eff_aggro_range, 0.0, 0.8)
					var stealth_stat = 0.0
					if is_instance_valid(player) and player.get_node_or_null("EquipmentManager"):
						stealth_stat = player.equipment_manager.get_stealth()
					var stealth_factor = 1.0 / (1.0 + stealth_stat / 15.0)
					# Sneak: 0.1x awareness ramp (very slow detection)
					var sneak_factor = 0.1 if _player_sneaking else 1.0
					_awareness = minf(_awareness + 3.0 * dist_factor * stealth_factor * sneak_factor * delta, 1.0)
				else:
					_awareness = maxf(_awareness - 0.4 * delta, 0.0)
				_update_awareness_indicator()
				# Threshold transitions
				if _awareness >= 0.7:
					_on_awareness_alert()
				elif _awareness >= 0.3 and state == State.IDLE:
					# Suspicious → investigate toward player
					if is_instance_valid(player):
						_investigate_pos = player.global_position
						_investigate_dir = Vector2.ZERO
						_investigate_phase = 0
						_investigate_timer = 0.0
						_investigate_look_timer = 0.0
						state = State.INVESTIGATE
		State.CHASE:
			_chase_timer += delta
			# Track player's position and movement direction while chasing
			if is_instance_valid(player):
				var player_vel = player.velocity if "velocity" in player else Vector2.ZERO
				if player_vel.length() > 5.0:
					_last_known_player_dir = player_vel.normalized()
				_last_known_player_pos = player.global_position
			var chase_limit = CHASE_TIMEOUT
			if _dm:
				chase_limit = 30.0  # dungeon enemies chase much longer
			if _is_boss_or_large:
				chase_limit = 999.0  # bosses/elites never give up
			if _chase_timer > chase_limit:
				_begin_search()
			else:
				_do_chase(dir, dist, delta)
		State.ATTACK:
			_do_attack(dir)
		State.COOLDOWN:
			cooldown_timer -= delta
			var pref = definition.preferred_distance if definition else 0.0
			if pref > 0:
				# Ranged enemy — hold position during cooldown
				velocity = Vector2.ZERO
			else:
				# Melee enemy — keep advancing during cooldown
				if dist > 20.0:
					velocity = dir * speed * 0.4
				else:
					velocity = Vector2.ZERO
			if cooldown_timer <= 0:
				state = State.CHASE
		State.CHARGING:
			charge_timer -= delta
			velocity = charge_dir * (definition.charge_speed if definition else 80.0)
			if charge_timer <= 0:
				velocity = Vector2.ZERO
				cooldown_timer = shoot_interval
				state = State.COOLDOWN
		State.STEALTHED:
			_stealth_timer -= delta
			velocity = dir * speed * 0.5
			if _stealth_timer <= 0:
				$Sprite2D.modulate.a = 1.0
				# Backstab: if close enough, deal 25% max HP from behind
				if player and is_instance_valid(player) and global_position.distance_to(player.global_position) < 30.0:
					if player.has_method("take_damage"):
						var dmg = definition.attack_damage if definition else 2
						player.take_damage(dmg, global_position, false, true)
				state = State.ATTACK
				var sfx_bs = get_node_or_null("/root/SFXManager")
				if sfx_bs:
					sfx_bs.play("attack_a", -3.0, 0.1)

		State.INVESTIGATE:
			_investigate_timer += delta
			# Slow awareness decay while investigating
			_awareness = maxf(_awareness - 0.15 * delta, 0.0)
			_update_awareness_indicator()
			match _investigate_phase:
				0:  # Phase 0: walk to last known position
					var to_inv = _investigate_pos - global_position
					var inv_dist = to_inv.length()
					if inv_dist > 6.0 and _investigate_timer < 5.0:
						velocity = to_inv.normalized() * speed * 0.8
						if to_inv.x < 0:
							$Sprite2D.flip_h = true
						elif to_inv.x > 0:
							$Sprite2D.flip_h = false
					else:
						# Arrived at last known pos — continue in player's direction if known
						if _investigate_dir.length() > 0.1:
							_investigate_phase = 1
							_investigate_timer = 0.0
							_investigate_pos = global_position + _investigate_dir * 30.0  # search ~4 tiles ahead
						else:
							_investigate_phase = 2
							_investigate_timer = 0.0
				1:  # Phase 1: continue in player's last movement direction
					var to_fwd = _investigate_pos - global_position
					var fwd_dist = to_fwd.length()
					if fwd_dist > 6.0 and _investigate_timer < 3.0:
						velocity = to_fwd.normalized() * speed * 0.6
						if to_fwd.x < 0:
							$Sprite2D.flip_h = true
						elif to_fwd.x > 0:
							$Sprite2D.flip_h = false
					else:
						_investigate_phase = 2
						_investigate_timer = 0.0
				2:  # Phase 2: look around at final position
					velocity = Vector2.ZERO
					_investigate_look_timer -= delta
					if _investigate_look_timer <= 0:
						_investigate_look_timer = 0.8
						$Sprite2D.flip_h = randf() > 0.5
					if _investigate_timer > 3.0:
						state = State.IDLE
						_awareness = maxf(_awareness - 0.3, 0.0)
						_update_awareness_indicator()
						_investigate_timer = 0.0
						_investigate_phase = 0
			# If player spotted during any investigation phase → CHASE
			var _inv_player_sneaking = is_instance_valid(player) and player.has_method("is_sneaking") and player.is_sneaking()
			var _inv_eff_range = aggro_range * 0.4 if _inv_player_sneaking else aggro_range
			if not is_passive and dist < _inv_eff_range and _has_line_of_sight_or_shared():
				state = State.CHASE
				_chase_timer = 0.0
				_investigate_phase = 0

	# Thrown by wrestler — override movement
	if _thrown_timer > 0:
		_thrown_timer -= delta
		velocity = _thrown_velocity
		move_and_slide()
		# Check wall collision
		if get_slide_collision_count() > 0:
			if _thrower_dmg > 0:
				take_damage(maxi(1, _thrower_dmg / 4), false)
			_thrown_timer = 0.0
			_thrown_velocity = Vector2.ZERO
			var vfx_t = get_node_or_null("/root/VFXManager")
			if vfx_t:
				vfx_t.hit_spark(global_position)
			var sfx_t = get_node_or_null("/root/SFXManager")
			if sfx_t:
				sfx_t.play("impact_a", -3.0)
		# Check enemy-enemy collision
		for e in get_tree().get_nodes_in_group("enemy"):
			if e == self or not is_instance_valid(e) or e.state == State.DEAD:
				continue
			if global_position.distance_to(e.global_position) < 8.0:
				var col_dmg = maxi(1, _thrower_dmg / 2)
				take_damage(col_dmg, false)
				e.take_damage(col_dmg, false)
				_thrown_timer = 0.0
				_thrown_velocity = Vector2.ZERO
				var vfx_c = get_node_or_null("/root/VFXManager")
				if vfx_c:
					vfx_c.hit_spark(global_position)
				break
		if _thrown_timer <= 0:
			_thrown_velocity = Vector2.ZERO
			_check_hazard_at_position()
		return  # skip normal move_and_slide during throw

	# Nudge from dash knockback
	if _nudge_timer > 0:
		_nudge_timer -= delta
		velocity = _nudge_velocity
		move_and_slide()
		if _nudge_timer <= 0:
			_nudge_velocity = Vector2.ZERO
			_check_hazard_at_position()
		return

	# Beam sweep
	if _beam_timer > 0:
		_beam_timer -= delta
		_beam_angle += (definition.beam_sweep_speed if definition else 1.5) * delta
		_shoot_single(Vector2.RIGHT.rotated(_beam_angle))

	_maybe_leave_trail(delta)
	move_and_slide()

	# Contact damage — check if we collided with the player
	_contact_cooldown -= delta
	if _contact_cooldown <= 0:
		_check_contact_damage()

func _get_active_attack_type() -> EnemyDefinition.AttackType:
	if not definition:
		return EnemyDefinition.AttackType.RANGED
	# Artillery enemies always use their native attack — no pool mixing
	if definition.attack_type == EnemyDefinition.AttackType.ARTILLERY:
		return EnemyDefinition.AttackType.ARTILLERY
	# Elites/bosses cycle through their random attack pool
	if _is_boss_or_large and not _attack_pool.is_empty():
		return _next_pool_attack()
	if _current_phase == 3 and definition.phase_3_attack != EnemyDefinition.AttackType.NONE:
		return definition.phase_3_attack
	if _current_phase == 2 and definition.phase_2_attack != EnemyDefinition.AttackType.NONE:
		return definition.phase_2_attack
	return definition.attack_type

func _get_active_bullet_count() -> int:
	if not definition:
		return 1
	if _current_phase == 3 and definition.phase_3_bullet_count > 0:
		return definition.phase_3_bullet_count
	if _current_phase == 2 and definition.phase_2_bullet_count > 0:
		return definition.phase_2_bullet_count
	return definition.bullet_count

func _steer_around_walls(desired_dir: Vector2) -> Vector2:
	# Cast rays ahead to detect walls and steer around them
	if desired_dir.length_squared() < 0.01:
		return desired_dir
	var space = get_world_2d().direct_space_state
	var look_dist = 12.0  # how far ahead to check

	# Check straight ahead
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + desired_dir * look_dist, 16)
	query.exclude = [get_rid()]
	var result = space.intersect_ray(query)
	if result.is_empty():
		return desired_dir  # no wall ahead, go straight

	# Wall ahead — try left and right rotations to find open path
	for angle in [0.6, -0.6, 1.0, -1.0, 1.4, -1.4]:
		var test_dir = desired_dir.rotated(angle)
		query = PhysicsRayQueryParameters2D.create(global_position, global_position + test_dir * look_dist, 16)
		query.exclude = [get_rid()]
		result = space.intersect_ray(query)
		if result.is_empty():
			return test_dir.normalized()

	# All directions blocked — just try perpendicular
	return desired_dir.rotated(PI / 2)

var _boss_charge_cd: float = 0.0  # cooldown for boss charge attacks
var _boss_summon_cd: float = 0.0  # cooldown for boss periodic summons

func _do_chase(dir: Vector2, dist: float, delta: float) -> void:
	# FEARED: run away from player
	if has_meta("feared") and get_meta("feared"):
		var flee_dir = -dir  # opposite of player direction
		velocity = flee_dir * speed * 1.3
		if flee_dir.x < 0:
			$Sprite2D.flip_h = true
		elif flee_dir.x > 0:
			$Sprite2D.flip_h = false
		return
	# CONFUSED: random movement
	if has_meta("confused") and get_meta("confused"):
		_wander_timer -= delta
		if _wander_timer <= 0:
			_wander_timer = 0.5 + randf() * 1.0
			_wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		velocity = _wander_dir * speed * 0.8
		# Randomly trigger attack in random direction
		if attack_timer <= 0:
			attack_timer = shoot_interval
			state = State.ATTACK
		return
	# STUNNED: don't move
	if has_meta("stunned") and get_meta("stunned"):
		velocity = Vector2.ZERO
		return
	# Lose aggro if player is very far away (but not if recently hit)
	var deaggro_dist = 400.0 if _dm else 200.0
	if _is_boss_or_large:
		deaggro_dist = 9999.0  # bosses/elites never de-aggro
	if dist > deaggro_dist and _hit_aggro_timer <= 0:
		velocity = Vector2.ZERO
		_begin_search()
		return

	var pref_dist = definition.preferred_distance if definition else 0.0
	var move_dir = dir
	var eff_speed = speed

	# Boss enrage at <30% HP: faster movement + attacks
	var enraged = _is_boss_or_large and hp < _max_hp * 0.3
	if enraged:
		eff_speed *= 1.5
		if attack_timer > 0:
			attack_timer -= delta  # double-tick attack timer when enraged

	# Tick boss ability cooldowns
	if _boss_charge_cd > 0:
		_boss_charge_cd -= delta
	if _boss_summon_cd > 0:
		_boss_summon_cd -= delta

	# Use flow-field pathfinding if available (dungeon) and not a ghost
	var use_flow = _nav and _nav.is_ready() and not (definition and definition.ignores_terrain)
	if use_flow and dist > 12.0:
		var flow_dir = _nav.get_flow_direction(global_position)
		if flow_dir != Vector2.ZERO:
			move_dir = flow_dir
	elif not (definition and definition.ignores_terrain):
		# Fallback: steering-based wall avoidance (overworld or ghosts)
		move_dir = _steer_around_walls(dir)

	# Boss/Elite special movement behaviors
	if _is_boss_or_large and definition:
		var base_atk = definition.attack_type
		match base_atk:
			EnemyDefinition.AttackType.MELEE, EnemyDefinition.AttackType.CHARGE, EnemyDefinition.AttackType.DASH:
				# Melee bosses: periodic fast charges at player
				if _boss_charge_cd <= 0 and dist > 20 and dist < 80:
					_boss_charge_cd = 3.0 if not enraged else 1.5
					charge_dir = dir
					charge_timer = 0.4
					state = State.CHARGING
					velocity = dir * eff_speed * 3.0
					var sfx_bc = get_node_or_null("/root/SFXManager")
					if sfx_bc:
						sfx_bc.play("attack_b", -4.0, 0.1)
					return
				# Chase aggressively — always approach
				velocity = move_dir * eff_speed * 1.5
			EnemyDefinition.AttackType.SUMMON:
				# Summoner bosses: hold position, summon periodically
				if _boss_summon_cd <= 0:
					_boss_summon_cd = 5.0 if not enraged else 3.0
					_do_summon()
				# Stand ground and shoot — slight drift toward player
				if dist > 60:
					velocity = move_dir * eff_speed * 0.4
				else:
					velocity = Vector2.ZERO
			EnemyDefinition.AttackType.BEAM:
				# Beam bosses: slow turret, face player
				velocity = move_dir * eff_speed * 0.3
			_:
				# Default boss: approach player, don't flee
				if pref_dist > 0:
					# Ranged boss — slow approach, hold at range, don't flee
					if dist > pref_dist:
						velocity = move_dir * eff_speed * 0.8
					else:
						velocity = Vector2.ZERO  # hold ground and shoot
				else:
					# Melee boss — chase
					velocity = move_dir * eff_speed * 1.2
	elif pref_dist > 0:
		var atk_type = definition.attack_type if definition else EnemyDefinition.AttackType.RANGED

		# --- Mummy Bodyguard (PUSH_WAVE) ---
		if atk_type == EnemyDefinition.AttackType.PUSH_WAVE and _bodyguard_mode and is_instance_valid(_attached_ally):
			var ally_dist = global_position.distance_to(_attached_ally.global_position)
			if ally_dist > 12.0:
				var to_ally = (_attached_ally.global_position - global_position).normalized()
				velocity = _steer_around_walls(to_ally) * eff_speed * 0.8
			else:
				velocity = Vector2.ZERO  # hold position near ally

		# --- All Bombing Enemies: Retreating AI ---
		# Non-boss bomb enemies flee aggressively and lob from afar
		elif atk_type in [EnemyDefinition.AttackType.FIRE_RAIN,
			EnemyDefinition.AttackType.BOMB_TOSS, EnemyDefinition.AttackType.CARPET_BOMB,
			EnemyDefinition.AttackType.CLUSTER_BOMB, EnemyDefinition.AttackType.MINE_DROP,
			EnemyDefinition.AttackType.ARTILLERY, EnemyDefinition.AttackType.POISON_CLOUD]:
			var is_boss = definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS
			if is_boss:
				# Bosses hold ground or slowly approach
				if dist < pref_dist * 0.4:
					velocity = _steer_around_walls(-dir) * eff_speed * 0.4
				elif dist < pref_dist:
					velocity = Vector2.ZERO
				else:
					velocity = move_dir * eff_speed * 0.5
					_hold_timer = 0.0
			else:
				# All other bomb enemies (including elites): flee when close
				if dist < pref_dist:
					var away = -dir
					velocity = _steer_around_walls(away) * eff_speed * 0.9
				elif dist < pref_dist * 1.5:
					# At preferred distance — strafe/hold
					velocity = Vector2.ZERO
				else:
					# Too far — slow approach
					velocity = move_dir * eff_speed * 0.4
					_hold_timer = 0.0

		# --- Evil Guardian Defensive (BARRIER_WALL) ---
		elif atk_type == EnemyDefinition.AttackType.BARRIER_WALL:
			if dist < 20.0:
				# Cornered — aggressive melee chase
				velocity = move_dir * eff_speed * 1.5
			elif dist < pref_dist:
				# Too close — retreat to preferred distance
				var away = -dir
				velocity = _steer_around_walls(away) * eff_speed * 0.7
			else:
				# At preferred distance — hold and place barriers
				velocity = Vector2.ZERO

		# --- Default ranged behavior ---
		else:
			if dist > pref_dist * 1.5:
				velocity = move_dir * eff_speed * 0.8
				_hold_timer = 0.0
			else:
				_hold_timer += delta
				if _hold_timer > 3.0:
					velocity = move_dir * eff_speed * 0.6
					if _hold_timer > 4.5:
						_hold_timer = 0.0
				else:
					velocity = Vector2.ZERO
	else:
		# Melee/no-preference enemy — dynamic combat movement
		var atk_type_m = definition.attack_type if definition else EnemyDefinition.AttackType.MELEE
		_melee_dodge_timer -= delta
		_melee_lunge_cd -= delta

		if atk_type_m == EnemyDefinition.AttackType.CHARGE or atk_type_m == EnemyDefinition.AttackType.DASH:
			# Charge/Dash types: circle strafe then lunge in
			if dist > 50:
				# Far away — approach directly
				velocity = move_dir * eff_speed * 1.3
			elif dist > 20:
				# Mid range — circle strafe to flank, then lunge
				_melee_flank_timer += delta
				var strafe = dir.rotated(PI * 0.5 * _melee_dodge_dir)
				var approach = move_dir * 0.3
				velocity = _steer_around_walls((strafe + approach).normalized()) * eff_speed * 1.1
				# After circling ~1.5s, lunge in
				if _melee_flank_timer > 1.5 and _melee_lunge_cd <= 0:
					_melee_flank_timer = 0.0
					_melee_lunge_cd = 2.5
					charge_dir = dir
					charge_timer = 0.3
					state = State.CHARGING
					velocity = dir * eff_speed * 3.0
					var sfx_l = get_node_or_null("/root/SFXManager")
					if sfx_l:
						sfx_l.play("attack_b", -6.0, 0.1)
			else:
				# Very close — attack
				velocity = move_dir * eff_speed * 1.5
			# Randomly switch strafe direction
			if _melee_dodge_timer <= 0:
				_melee_dodge_timer = randf_range(0.8, 2.0)
				_melee_dodge_dir = -_melee_dodge_dir

		elif atk_type_m == EnemyDefinition.AttackType.NONE:
			# Contact-only enemies: shamble directly toward player, no dodging
			velocity = move_dir * eff_speed

		elif atk_type_m == EnemyDefinition.AttackType.STRAFE_RUN:
			# Strafe runners: always moving sideways, dashing through player
			var strafe = dir.rotated(PI * 0.5 * _melee_dodge_dir)
			var approach = move_dir * 0.5
			velocity = _steer_around_walls((strafe + approach).normalized()) * eff_speed * 1.2
			if _melee_dodge_timer <= 0:
				_melee_dodge_timer = randf_range(0.6, 1.5)
				_melee_dodge_dir = -_melee_dodge_dir

		else:
			# Default melee: approach with periodic side-dodges
			if dist > 30:
				# Approaching — weave slightly
				var weave = dir.rotated(PI * 0.25 * _melee_dodge_dir * sin(_melee_flank_timer * 3.0))
				velocity = _steer_around_walls(weave) * eff_speed * 1.2
				_melee_flank_timer += delta
			elif dist > 12:
				# Close — side-dodge then strike
				if _melee_dodge_timer > 0:
					var dodge = dir.rotated(PI * 0.5 * _melee_dodge_dir)
					velocity = _steer_around_walls(dodge) * eff_speed * 1.4
				else:
					velocity = move_dir * eff_speed * 1.5
			else:
				# Point blank — commit
				velocity = move_dir * eff_speed * 1.5
			if _melee_dodge_timer <= 0:
				_melee_dodge_timer = randf_range(0.5, 1.2)
				_melee_dodge_dir = -_melee_dodge_dir

	attack_timer -= delta
	# Artillery: re-check shared vision every ~1s (allies may die)
	if definition and definition.attack_type == EnemyDefinition.AttackType.ARTILLERY and Engine.get_physics_frames() % 60 == 0:
		_shared_vision_checked = false
		_check_shared_vision_once()
	var _atk_check = _get_active_attack_type() if attack_timer <= 0 else EnemyDefinition.AttackType.NONE
	var _no_los_attacks = [EnemyDefinition.AttackType.HEAL, EnemyDefinition.AttackType.SUMMON,
		EnemyDefinition.AttackType.BOMB_TOSS, EnemyDefinition.AttackType.CARPET_BOMB,
		EnemyDefinition.AttackType.FIRE_RAIN, EnemyDefinition.AttackType.CLUSTER_BOMB,
		EnemyDefinition.AttackType.MINE_DROP, EnemyDefinition.AttackType.ARTILLERY,
		EnemyDefinition.AttackType.POISON_CLOUD]
	var _needs_los = _atk_check not in _no_los_attacks
	# Artillery has extreme range (10-15 rooms ≈ 500px) and uses ally sight
	var _attack_range = 500.0 if _atk_check == EnemyDefinition.AttackType.ARTILLERY else 120.0
	var _has_los = false
	if not _needs_los:
		_has_los = true
	elif _atk_check == EnemyDefinition.AttackType.ARTILLERY:
		_has_los = _has_line_of_sight_or_shared()
	else:
		_has_los = _has_line_of_sight()
	if attack_timer <= 0 and dist < _attack_range and _has_los:
		var atk = _atk_check
		# All enemies shoot bullets as baseline — special types add extra behavior
		match atk:
			EnemyDefinition.AttackType.NONE:
				state = State.ATTACK  # still shoots
			EnemyDefinition.AttackType.MELEE:
				if dist < 30:
					# Lunge + shoot, then dodge back
					_shoot_single(dir)
					charge_dir = dir
					charge_timer = 0.2
					attack_timer = shoot_interval
					state = State.CHARGING
					# Queue a retreat dodge after the lunge
					get_tree().create_timer(0.25).timeout.connect(
						func():
							if is_instance_valid(self) and hp > 0 and state != State.DEAD:
								var retreat = -dir.rotated(randf_range(-0.5, 0.5))
								charge_dir = retreat
								charge_timer = 0.15
								state = State.CHARGING
					)
				else:
					state = State.ATTACK  # shoot from range
			EnemyDefinition.AttackType.CHARGE:
				if dist < 60:
					# Charge with side-dodge after impact
					_shoot_single(dir)
					_start_charge(dir)
					# Side-dodge after charge ends
					get_tree().create_timer(definition.charge_duration + 0.1 if definition else 0.5).timeout.connect(
						func():
							if is_instance_valid(self) and hp > 0 and state != State.DEAD:
								var side = dir.rotated(PI * 0.5 * _melee_dodge_dir)
								charge_dir = side
								charge_timer = 0.2
								state = State.CHARGING
								_melee_dodge_dir = -_melee_dodge_dir
					)
				else:
					state = State.ATTACK
			EnemyDefinition.AttackType.DASH:
				if dist < 80:
					# Dash through player then loop around
					_shoot_single(dir)
					_start_charge(dir)
					# After dash: curve back toward player from behind
					get_tree().create_timer(definition.charge_duration + 0.1 if definition else 0.5).timeout.connect(
						func():
							if is_instance_valid(self) and hp > 0 and state != State.DEAD:
								var loop = dir.rotated(PI * 0.7 * _melee_dodge_dir)
								charge_dir = loop
								charge_timer = 0.25
								state = State.CHARGING
								_melee_dodge_dir = -_melee_dodge_dir
					)
				else:
					state = State.ATTACK
			EnemyDefinition.AttackType.TELEPORT:
				if dist > 60:
					_do_teleport()
					attack_timer = definition.teleport_cooldown
				else:
					state = State.ATTACK
			EnemyDefinition.AttackType.HEAL:
				_try_heal_nearby()
				_shoot_single(dir)  # healers also shoot
				attack_timer = shoot_interval
			EnemyDefinition.AttackType.STEALTH:
				if _stealth_timer <= 0:
					_enter_stealth()
				else:
					state = State.ATTACK
			EnemyDefinition.AttackType.STRAFE_RUN:
				# Charge perpendicular while shooting
				_shoot_strafe_run(dir)
				var strafe_dir = dir.rotated(PI / 2.0 * (1.0 if randf() > 0.5 else -1.0))
				charge_dir = strafe_dir
				charge_timer = 0.4
				attack_timer = shoot_interval * 0.5
				state = State.CHARGING
			_:
				# RANGED, BURST, SUMMON, SLAM, SPIRAL, POISON_SHOT, SHIELD, BEAM, SPLIT
				# VOLLEY, CROSS_SHOT, WAVE_SHOT, GATLING, MORTAR, NOVA, ZIGZAG
				# SHOTGUN_BLAST, HELIX, METEOR_SHOWER, BOOMERANG_SHOT, MINEFIELD
				# WALL_BOUNCE, LASER_GRID, GRAVITY_WELL, CHAIN_LIGHTNING, DEATH_SPIRAL
				# BOMB_TOSS, CARPET_BOMB, FIRE_RAIN, CLUSTER_BOMB, MINE_DROP
				state = State.ATTACK

func _do_attack(dir: Vector2) -> void:
	velocity = Vector2.ZERO
	# STUNNED: can't attack
	if has_meta("stunned") and get_meta("stunned"):
		state = State.CHASE
		return
	# FEARED: can't attack
	if has_meta("feared") and get_meta("feared"):
		state = State.CHASE
		return
	# CONFUSED: randomize attack direction, 30% chance to target nearest enemy
	var atk_dir = dir
	if has_meta("confused") and get_meta("confused"):
		if randf() < 0.3:
			# Friendly fire — aim at nearest ally
			var nearest_ally: Node2D = null
			var nearest_dist: float = INF
			for e in get_tree().get_nodes_in_group("enemy"):
				if e == self or not is_instance_valid(e) or e.state == State.DEAD:
					continue
				var d = global_position.distance_to(e.global_position)
				if d < nearest_dist:
					nearest_dist = d
					nearest_ally = e
			if nearest_ally:
				atk_dir = (nearest_ally.global_position - global_position).normalized()
			else:
				atk_dir = Vector2.from_angle(randf() * TAU)
		else:
			atk_dir = Vector2.from_angle(randf() * TAU)
		dir = atk_dir

	# Boss/Elite combo attacks — phase 2+ fires multiple pool attacks (not artillery)
	var _native_atk = definition.attack_type if definition else EnemyDefinition.AttackType.NONE
	if _is_boss_or_large and _current_phase >= 2 and not _attack_pool.is_empty() and _native_atk != EnemyDefinition.AttackType.ARTILLERY:
		_do_boss_combo_attack(dir)
		attack_timer = shoot_interval * 0.25
		cooldown_timer = 0.1
		state = State.COOLDOWN
		return

	var atk = _get_active_attack_type()

	match atk:
		EnemyDefinition.AttackType.NONE:
			_shoot_single(dir)
		EnemyDefinition.AttackType.MELEE:
			# Lunge + shoot
			_shoot_single(dir)
			charge_dir = dir
			charge_timer = 0.2
			state = State.CHARGING
			attack_timer = shoot_interval * 0.25
			return  # charging handles cooldown
		EnemyDefinition.AttackType.RANGED:
			_shoot_single(dir)
		EnemyDefinition.AttackType.BURST:
			_shoot_ring(dir)
		EnemyDefinition.AttackType.CHARGE:
			_shoot_single(dir)
		EnemyDefinition.AttackType.DASH:
			_shoot_single(dir)
		EnemyDefinition.AttackType.SUMMON:
			_do_summon()
			_shoot_ring(dir)  # summon + ring burst
		EnemyDefinition.AttackType.SLAM:
			_do_slam()
			_shoot_ring(dir)  # slam + ring burst
		EnemyDefinition.AttackType.TELEPORT:
			_shoot_single(dir)
		EnemyDefinition.AttackType.SPIRAL:
			_shoot_spiral(dir)
		EnemyDefinition.AttackType.POISON_SHOT:
			_shoot_single(dir)
		EnemyDefinition.AttackType.STEALTH:
			_shoot_single(dir)
		EnemyDefinition.AttackType.SHIELD:
			_shoot_shield_bash(dir)
		EnemyDefinition.AttackType.BEAM:
			_start_beam(dir)
			_shoot_single(dir)  # also fires bullets during beam
		EnemyDefinition.AttackType.SPLIT:
			_shoot_single(dir)
		EnemyDefinition.AttackType.VOLLEY:
			_shoot_volley(dir)
		EnemyDefinition.AttackType.CROSS_SHOT:
			_shoot_cross(dir)
		EnemyDefinition.AttackType.WAVE_SHOT:
			_shoot_wave(dir)
		EnemyDefinition.AttackType.GATLING:
			_shoot_gatling(dir)
		EnemyDefinition.AttackType.MORTAR:
			_shoot_mortar(dir)
		EnemyDefinition.AttackType.NOVA:
			_shoot_nova(dir)
		EnemyDefinition.AttackType.ZIGZAG:
			_shoot_zigzag(dir)
		EnemyDefinition.AttackType.SHOTGUN_BLAST:
			_shoot_shotgun(dir)
		EnemyDefinition.AttackType.HELIX:
			_shoot_helix(dir)
		EnemyDefinition.AttackType.METEOR_SHOWER:
			_shoot_meteor_shower(dir)
		EnemyDefinition.AttackType.BOOMERANG_SHOT:
			_shoot_boomerang(dir)
		EnemyDefinition.AttackType.STRAFE_RUN:
			_shoot_strafe_run(dir)
		EnemyDefinition.AttackType.MINEFIELD:
			_shoot_minefield()
		EnemyDefinition.AttackType.RETURNING_VOLLEY:
			_shoot_returning(dir)
		EnemyDefinition.AttackType.SEEKING_MINES:
			_shoot_seeking_mines()
		EnemyDefinition.AttackType.DETONATOR:
			_shoot_detonator(dir)
		EnemyDefinition.AttackType.SPLITTER:
			_shoot_splitter(dir)
		EnemyDefinition.AttackType.SINE_BARRAGE:
			_shoot_sine_barrage(dir)
		EnemyDefinition.AttackType.HOMING_SALVO:
			_shoot_homing_salvo(dir)
		EnemyDefinition.AttackType.TELEGRAPH_EXPLOSION:
			_shoot_telegraph_explosion()
		EnemyDefinition.AttackType.ORBIT_LAUNCH:
			_shoot_orbit_launch(dir)
		EnemyDefinition.AttackType.WALL_BOUNCE:
			_shoot_wall_bounce(dir)
		EnemyDefinition.AttackType.LASER_GRID:
			_shoot_laser_grid(dir)
		EnemyDefinition.AttackType.GRAVITY_WELL:
			_shoot_gravity_well(dir)
		EnemyDefinition.AttackType.CHAIN_LIGHTNING:
			_shoot_chain_lightning(dir)
		EnemyDefinition.AttackType.DEATH_SPIRAL:
			_shoot_spiral(dir)  # same as spiral when used as active attack
		EnemyDefinition.AttackType.BOMB_TOSS:
			_shoot_bomb_toss()
		EnemyDefinition.AttackType.CARPET_BOMB:
			_shoot_carpet_bomb(dir)
		EnemyDefinition.AttackType.FIRE_RAIN:
			_shoot_fire_rain()
		EnemyDefinition.AttackType.CLUSTER_BOMB:
			_shoot_cluster_bomb()
		EnemyDefinition.AttackType.MINE_DROP:
			_shoot_mine_drop()
		EnemyDefinition.AttackType.BARRIER_WALL:
			_shoot_barrier_wall(dir)
		EnemyDefinition.AttackType.PULL_SHOT:
			_shoot_pull_shot(dir)
		EnemyDefinition.AttackType.PUSH_WAVE:
			_shoot_push_wave(dir)
		EnemyDefinition.AttackType.VORTEX:
			_shoot_vortex(dir)
		EnemyDefinition.AttackType.RING_PULSE:
			_shoot_ring_pulse(dir)
		EnemyDefinition.AttackType.ARTILLERY:
			_shoot_artillery()
		EnemyDefinition.AttackType.WHIP_LASH:
			_shoot_whip_lash(dir)
		EnemyDefinition.AttackType.POISON_CLOUD:
			_shoot_poison_cloud()
		EnemyDefinition.AttackType.DASH_STRIKE:
			_shoot_dash_strike(dir)
		EnemyDefinition.AttackType.LANCE_THRUST:
			_shoot_lance_thrust(dir)
		EnemyDefinition.AttackType.SHIELD_WALL:
			_shoot_shield_wall(dir)
		EnemyDefinition.AttackType.CURSE_BOLT:
			_shoot_curse_bolt(dir)
		EnemyDefinition.AttackType.SUMMON_WALL:
			_shoot_summon_wall(dir)
		EnemyDefinition.AttackType.LEAPING_SLAM:
			_shoot_leaping_slam(dir)
		EnemyDefinition.AttackType.ARROW_VOLLEY:
			_shoot_arrow_volley()

	# Bomb/heavy attacks get longer cooldowns — they're AOE so shouldn't spam
	var _bomb_attacks = [
		EnemyDefinition.AttackType.BOMB_TOSS, EnemyDefinition.AttackType.CARPET_BOMB,
		EnemyDefinition.AttackType.FIRE_RAIN, EnemyDefinition.AttackType.CLUSTER_BOMB,
		EnemyDefinition.AttackType.MINE_DROP, EnemyDefinition.AttackType.ARTILLERY,
		EnemyDefinition.AttackType.POISON_CLOUD, EnemyDefinition.AttackType.LEAPING_SLAM,
		EnemyDefinition.AttackType.ARROW_VOLLEY]
	if atk in _bomb_attacks:
		attack_timer = shoot_interval * 1.0  # full cooldown for bombs
	else:
		attack_timer = shoot_interval * 0.25  # aggressive fire rate for bullet attacks
	cooldown_timer = 0.1
	state = State.COOLDOWN

func _fire_attack_type(atk: int, dir: Vector2) -> void:
	match atk:
		EnemyDefinition.AttackType.NONE, EnemyDefinition.AttackType.RANGED, \
		EnemyDefinition.AttackType.CHARGE, EnemyDefinition.AttackType.DASH, \
		EnemyDefinition.AttackType.POISON_SHOT, EnemyDefinition.AttackType.STEALTH, \
		EnemyDefinition.AttackType.SPLIT:
			_shoot_single(dir)
		EnemyDefinition.AttackType.MELEE:
			_shoot_single(dir)
		EnemyDefinition.AttackType.BURST:
			_shoot_ring(dir)
		EnemyDefinition.AttackType.SUMMON:
			_do_summon()
			_shoot_ring(dir)
		EnemyDefinition.AttackType.SLAM:
			_do_slam()
			_shoot_ring(dir)
		EnemyDefinition.AttackType.TELEPORT:
			_shoot_single(dir)
		EnemyDefinition.AttackType.SPIRAL, EnemyDefinition.AttackType.DEATH_SPIRAL:
			_shoot_spiral(dir)
		EnemyDefinition.AttackType.SHIELD:
			_shoot_shield_bash(dir)
		EnemyDefinition.AttackType.BEAM:
			_start_beam(dir)
			_shoot_single(dir)
		EnemyDefinition.AttackType.VOLLEY:
			_shoot_volley(dir)
		EnemyDefinition.AttackType.CROSS_SHOT:
			_shoot_cross(dir)
		EnemyDefinition.AttackType.WAVE_SHOT:
			_shoot_wave(dir)
		EnemyDefinition.AttackType.GATLING:
			_shoot_gatling(dir)
		EnemyDefinition.AttackType.MORTAR:
			_shoot_mortar(dir)
		EnemyDefinition.AttackType.NOVA:
			_shoot_nova(dir)
		EnemyDefinition.AttackType.ZIGZAG:
			_shoot_zigzag(dir)
		EnemyDefinition.AttackType.SHOTGUN_BLAST:
			_shoot_shotgun(dir)
		EnemyDefinition.AttackType.HELIX:
			_shoot_helix(dir)
		EnemyDefinition.AttackType.METEOR_SHOWER:
			_shoot_meteor_shower(dir)
		EnemyDefinition.AttackType.BOOMERANG_SHOT:
			_shoot_boomerang(dir)
		EnemyDefinition.AttackType.STRAFE_RUN:
			_shoot_strafe_run(dir)
		EnemyDefinition.AttackType.MINEFIELD:
			_shoot_minefield()
		EnemyDefinition.AttackType.RETURNING_VOLLEY:
			_shoot_returning(dir)
		EnemyDefinition.AttackType.SEEKING_MINES:
			_shoot_seeking_mines()
		EnemyDefinition.AttackType.DETONATOR:
			_shoot_detonator(dir)
		EnemyDefinition.AttackType.SPLITTER:
			_shoot_splitter(dir)
		EnemyDefinition.AttackType.SINE_BARRAGE:
			_shoot_sine_barrage(dir)
		EnemyDefinition.AttackType.HOMING_SALVO:
			_shoot_homing_salvo(dir)
		EnemyDefinition.AttackType.TELEGRAPH_EXPLOSION:
			_shoot_telegraph_explosion()
		EnemyDefinition.AttackType.ORBIT_LAUNCH:
			_shoot_orbit_launch(dir)
		EnemyDefinition.AttackType.WALL_BOUNCE:
			_shoot_wall_bounce(dir)
		EnemyDefinition.AttackType.LASER_GRID:
			_shoot_laser_grid(dir)
		EnemyDefinition.AttackType.GRAVITY_WELL:
			_shoot_gravity_well(dir)
		EnemyDefinition.AttackType.CHAIN_LIGHTNING:
			_shoot_chain_lightning(dir)
		EnemyDefinition.AttackType.BOMB_TOSS:
			_shoot_bomb_toss()
		EnemyDefinition.AttackType.CARPET_BOMB:
			_shoot_carpet_bomb(dir)
		EnemyDefinition.AttackType.FIRE_RAIN:
			_shoot_fire_rain()
		EnemyDefinition.AttackType.CLUSTER_BOMB:
			_shoot_cluster_bomb()
		EnemyDefinition.AttackType.MINE_DROP:
			_shoot_mine_drop()
		EnemyDefinition.AttackType.BARRIER_WALL:
			_shoot_barrier_wall(dir)
		EnemyDefinition.AttackType.PULL_SHOT:
			_shoot_pull_shot(dir)
		EnemyDefinition.AttackType.PUSH_WAVE:
			_shoot_push_wave(dir)
		EnemyDefinition.AttackType.VORTEX:
			_shoot_vortex(dir)
		EnemyDefinition.AttackType.RING_PULSE:
			_shoot_ring_pulse(dir)
		EnemyDefinition.AttackType.ARTILLERY:
			_shoot_artillery()
		EnemyDefinition.AttackType.WHIP_LASH:
			_shoot_whip_lash(dir)
		EnemyDefinition.AttackType.POISON_CLOUD:
			_shoot_poison_cloud()
		EnemyDefinition.AttackType.DASH_STRIKE:
			_shoot_dash_strike(dir)
		EnemyDefinition.AttackType.LANCE_THRUST:
			_shoot_lance_thrust(dir)
		EnemyDefinition.AttackType.SHIELD_WALL:
			_shoot_shield_wall(dir)
		EnemyDefinition.AttackType.CURSE_BOLT:
			_shoot_curse_bolt(dir)
		EnemyDefinition.AttackType.SUMMON_WALL:
			_shoot_summon_wall(dir)
		EnemyDefinition.AttackType.LEAPING_SLAM:
			_shoot_leaping_slam(dir)
		EnemyDefinition.AttackType.ARROW_VOLLEY:
			_shoot_arrow_volley()

func _do_boss_combo_attack(dir: Vector2) -> void:
	velocity = Vector2.ZERO
	var is_boss = definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS

	# Fire multiple attacks from the pool simultaneously
	# Elites (phase 2+): fire 2 pool attacks
	# Bosses (phase 2): fire 2 pool attacks + nova
	# Bosses (phase 3): fire all 3 pool attacks
	# Enraged: fire all pool attacks + nova
	var combo_count = 2
	if is_boss:
		if _current_phase >= 3:
			combo_count = _attack_pool.size()  # all 3
		if _enraged:
			combo_count = _attack_pool.size()  # all attacks when enraged

	for i in range(mini(combo_count, _attack_pool.size())):
		_fire_attack_type(_next_pool_attack(), dir)

	# Bosses add a nova on top in phase 2+, and when enraged
	if is_boss and (_current_phase >= 2 or _enraged):
		_shoot_nova(dir)

func _check_contact_damage() -> void:
	if state == State.DEAD or not is_instance_valid(player):
		return
	# Check physics collisions from move_and_slide first
	var touching_player = false
	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i)
		if col.get_collider() == player:
			touching_player = true
			break
	# Also check distance as fallback
	if not touching_player:
		var dist = global_position.distance_to(player.global_position)
		var in_ow = is_inside_tree() and get_tree().current_scene and get_tree().current_scene.name == "Overworld"
		var contact_range = 8.0 * scale.x * (4.0 if in_ow else 1.0)
		if dist > contact_range:
			return

	_contact_cooldown = 0.5  # half second between contact hits
	var sfx_ct = get_node_or_null("/root/SFXManager")
	if sfx_ct:
		sfx_ct.play("impact_b", -5.0, 0.15)

	# Calculate momentum-based damage
	var my_speed = velocity.length()
	var player_speed = player.velocity.length()
	var relative_speed = (velocity - player.velocity).length()

	# Base contact damage from definition (prefer contact_damage, fall back to attack_damage)
	var base_dmg = 1
	if definition:
		if definition.contact_damage > 0:
			base_dmg = definition.contact_damage
		elif definition.attack_damage > 0:
			base_dmg = definition.attack_damage

	# Momentum bonus: faster collisions hurt more
	var momentum_mult = clampf(relative_speed / 40.0, 0.5, 3.0)
	var weight_mult = _weight

	# Enemy deals damage to player
	var player_dmg = int(ceil(base_dmg * momentum_mult * weight_mult))
	if player.has_method("take_damage"):
		player.take_damage(maxi(player_dmg, 1), global_position, true)

	# Thorns: reflect damage to enemy on contact
	var thorns_em = player.get_node_or_null("EquipmentManager")
	if thorns_em:
		var thorns_dmg = int(thorns_em.get_thorns())
		if thorns_dmg > 0:
			take_damage(thorns_dmg)

	var push_dir = (global_position - player.global_position).normalized()
	if push_dir == Vector2.ZERO:
		push_dir = Vector2.RIGHT.rotated(randf() * TAU)

	var is_heavy = definition and definition.size_class >= 1  # LARGE or BOSS
	if is_heavy:
		# Heavy enemies: immovable, but push player harder
		if definition.size_class >= 2:  # BOSS
			if player is CharacterBody2D:
				player.velocity = -push_dir * 600.0
				player.global_position -= push_dir * 16.0
		else:  # LARGE/elite
			if player is CharacterBody2D:
				player.velocity = -push_dir * 300.0
				player.global_position -= push_dir * 8.0
	else:
		# Normal enemies: mutual knockback (original behavior)
		var enemy_dmg = int(ceil(momentum_mult / weight_mult))
		if enemy_dmg > 0:
			take_damage(enemy_dmg)

		var kb_resist = definition.knockback_resistance if definition else 0.0
		var kb_mult = 1.0 - clampf(kb_resist, 0.0, 1.0)

		var sep_amount = 12.0 / weight_mult * kb_mult
		global_position += push_dir * sep_amount
		velocity = push_dir * 120.0 / weight_mult * kb_mult
		_knockback_timer = 0.3

		if player is CharacterBody2D:
			player.velocity = -push_dir * 60.0 * weight_mult
			player.global_position -= push_dir * 4.0

	# Poise check: heavy enemies can stagger the player
	var stagger_power = weight_mult * momentum_mult
	if player.has_method("get_poise") and stagger_power > player.get_poise():
		if player.has_method("apply_stagger"):
			player.apply_stagger(2.0)

func _start_charge(dir: Vector2) -> void:
	charge_dir = dir
	charge_timer = definition.charge_duration if definition else 0.3
	attack_timer = shoot_interval
	state = State.CHARGING
	var sfx_chg = get_node_or_null("/root/SFXManager")
	if sfx_chg:
		sfx_chg.play("woosh_b", -6.0, 0.15)

const MAX_SUMMONED_ENEMIES: int = 15

func _do_summon() -> void:
	if not definition:
		return
	# Cap total enemies in the room to prevent flooding
	var container = get_parent()
	if container and container.get_child_count() >= MAX_SUMMONED_ENEMIES:
		return
	# Auto-create a weak minion if no summon_definition set
	if not definition.summon_definition:
		var minion_def = EnemyDefinition.new()
		minion_def.enemy_name = "Minion"
		minion_def.max_hp = maxi(1, definition.max_hp / 3)
		minion_def.move_speed = definition.move_speed * 1.2
		minion_def.attack_type = EnemyDefinition.AttackType.MELEE
		minion_def.attack_damage = maxi(1, definition.attack_damage)
		minion_def.attack_speed = 1.5
		minion_def.bullet_speed = 60.0
		minion_def.bullet_count = 1
		minion_def.kingdom = definition.kingdom
		minion_def.use_loy_sprite = definition.use_loy_sprite
		minion_def.loy_tile_index = definition.loy_tile_index
		minion_def.sprite_color = definition.sprite_color.darkened(0.3)
		minion_def.xp_value = 1
		minion_def.score_value = 2
		definition.summon_definition = minion_def
	var sfx_sum = get_node_or_null("/root/SFXManager")
	if sfx_sum:
		sfx_sum.play("summon", -4.0, 0.1)
	var enemy_scene = preload("res://scenes/enemy.tscn")
	container = get_parent()
	for i in range(definition.summon_count):
		var angle = TAU / definition.summon_count * i
		var spawn_pos = global_position + Vector2(cos(angle), sin(angle)) * 16.0
		var minion = enemy_scene.instantiate()
		minion.global_position = spawn_pos
		minion.setup(definition.summon_definition.duplicate())
		container.add_child(minion)
		# Register with room state
		var gp = get_meta("grid_pos", Vector2i(-999, -999))
		if gp != Vector2i(-999, -999):
			minion.set_meta("grid_pos", gp)
			var dm = get_tree().get_first_node_in_group("dungeon_manager") if is_inside_tree() else null
			if dm and dm.room_states.has(gp):
				dm.room_states[gp]["alive"] += 1
				minion.tree_exited.connect(dm._on_enemy_died.bind(gp))

func _do_slam() -> void:
	if not is_inside_tree():
		return
	var bodies = get_tree().get_nodes_in_group("player")
	var radius = definition.slam_radius if definition else 24.0
	for body in bodies:
		if body.global_position.distance_to(global_position) < radius:
			if body.has_method("take_damage"):
				body.take_damage(definition.attack_damage if definition else 1, global_position)
	var tween = create_tween()
	tween.tween_property($Sprite2D, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property($Sprite2D, "scale", Vector2(1, 1), 0.2)
	var sfx_slam = get_node_or_null("/root/SFXManager")
	if sfx_slam:
		sfx_slam.play("boom_a", -2.0, 0.08)
	var vfx_slam = get_node_or_null("/root/VFXManager")
	if vfx_slam:
		vfx_slam.shockwave(global_position, radius, Color(0.8, 0.4, 0.1, 0.5))
		vfx_slam.shake(2.0, 0.15)

func _do_teleport() -> void:
	if not is_instance_valid(player):
		return
	var sfx_tp = get_node_or_null("/root/SFXManager")
	if sfx_tp:
		sfx_tp.play("teleport", -4.0, 0.15)
	var angle = randf() * TAU
	var dist = randf_range(20, 40)
	global_position = player.global_position + Vector2(cos(angle), sin(angle)) * dist
	$Sprite2D.modulate.a = 0.3
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate:a", 1.0, 0.3)

func _try_heal_nearby() -> void:
	var heal_amt = definition.heal_amount if definition else 2
	var heal_rng = definition.heal_range if definition else 48.0
	var sfx_heal = get_node_or_null("/root/SFXManager")
	if sfx_heal:
		sfx_heal.play("heal_b", -4.0, 0.1)
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if e == self:
			continue
		if e.global_position.distance_to(global_position) < heal_rng:
			if e.has_method("heal"):
				e.heal(heal_amt)
	$Sprite2D.modulate = Color.GREEN
	var orig = definition.sprite_color if definition else Color.WHITE
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate", orig, 0.3)

func heal(amount: int) -> void:
	var max_val = definition.max_hp if definition else hp + amount
	hp = mini(hp + amount, max_val)

func _maybe_leave_trail(delta: float) -> void:
	if not definition or not definition.leaves_trail:
		return
	_trail_timer -= delta
	if _trail_timer > 0:
		return
	_trail_timer = 0.5

	var hazard = HazardArea.new()
	hazard.collision_layer = 0
	hazard.collision_mask = 1
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(6, 6)
	shape.shape = rect
	hazard.add_child(shape)
	hazard.position = global_position
	hazard.interval = 0.5

	match definition.trail_type:
		"fire":
			hazard.damage = 1
			hazard.status_effect_type = StatusEffect.Type.BURNING
			hazard.status_duration = 2.0
			hazard.status_strength = 1.0
		"web":
			hazard.damage = 0
			hazard.status_effect_type = StatusEffect.Type.SLOWED
			hazard.status_duration = 2.0
			hazard.status_strength = 0.4
		"poison":
			hazard.damage = 1
			hazard.status_effect_type = StatusEffect.Type.POISONED
			hazard.status_duration = 3.0
			hazard.status_strength = 1.0

	# Auto-destroy after 5s
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	timer.timeout.connect(hazard.queue_free)
	hazard.add_child(timer)
	get_tree().current_scene.add_child(hazard)
	timer.start()

func _shoot_spiral(dir: Vector2) -> void:
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var count = _get_active_bullet_count()
	if count <= 0:
		return
	if count < 4:
		count = 4
	var bspeed = definition.bullet_speed if definition else 60.0
	# Fire 5 rapid volleys for a continuous spiral stream
	var volleys = 5
	for v in range(volleys):
		get_tree().create_timer(v * 0.12).timeout.connect(
			func():
				if not is_instance_valid(self) or hp <= 0:
					return
				var bc = _get_bullets_container()
				if not bc:
					return
				for i in range(count):
					var angle = dir.angle() + _spiral_angle + (TAU / count) * i
					_spawn_bullet(bc, Vector2.from_angle(angle), bspeed)
				_spiral_angle += 0.35
		)

func _enter_stealth() -> void:
	_stealth_timer = definition.stealth_duration if definition else 2.0
	$Sprite2D.modulate.a = 0.15
	state = State.STEALTHED
	var sfx_st = get_node_or_null("/root/SFXManager")
	if sfx_st:
		sfx_st.play("whistle", -6.0, 0.1)

func _start_beam(dir: Vector2) -> void:
	_beam_timer = definition.beam_duration if definition else 1.0
	_beam_angle = dir.angle()
	var sfx_beam = get_node_or_null("/root/SFXManager")
	if sfx_beam:
		sfx_beam.play("laser_a", -4.0, 0.1)

func _shoot_single(dir: Vector2) -> void:
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var count = _get_active_bullet_count()
	if count <= 0:
		return
	var bspeed = definition.bullet_speed if definition else 80.0
	if count == 1:
		_spawn_bullet(bullets_container, dir, bspeed)
	else:
		# Always fire one bullet directly at the player, spread others around it
		var spread = 0.3
		_spawn_bullet(bullets_container, dir, bspeed)  # center shot aimed at player
		for i in range(1, count):
			var angle_offset = (float(i) / count - 0.5) * spread * 2
			_spawn_bullet(bullets_container, dir.rotated(angle_offset), bspeed)

func _shoot_ring(dir: Vector2) -> void:
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var count = _get_active_bullet_count()
	if count <= 0:
		return
	if count < 4:
		count = 8
	var bspeed = definition.bullet_speed if definition else 70.0
	var base_angle = dir.angle()  # center ring on player direction
	for i in range(count):
		var angle = base_angle + (TAU / count) * i
		_spawn_bullet(bullets_container, Vector2.from_angle(angle), bspeed)

func _apply_enemy_bullet_props(bullet, spd: float) -> void:
	bullet.is_player_bullet = false
	bullet.speed = spd
	if definition:
		bullet.damage = definition.attack_damage if definition.attack_damage > 0 else 1
		bullet.enemy_kingdom = definition.kingdom
		if definition.bullet_sprite_index >= 0:
			bullet.bullet_sprite_index = definition.bullet_sprite_index
		# Poison bullets for POISON_SHOT enemies
		if definition.poison_chance > 0 and randf() < definition.poison_chance:
			bullet.poison_on_hit = true
			bullet.bullet_sprite_index = 161  # green venom sprite
		# Generic status effect on bullet hit (e.g. SLOWED for frost archers)
		if definition.bullet_status_effect != "":
			bullet.set_meta("apply_status", definition.bullet_status_effect)
			bullet.set_meta("status_duration", definition.bullet_status_duration)

var _last_fire_sfx_frame: int = 0

func _spawn_bullet(container: Node, dir: Vector2, spd: float) -> Area2D:
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = dir
	_apply_enemy_bullet_props(bullet, spd)
	container.add_child(bullet)
	# SFX: enemy fire (rate-limited to avoid spam from multi-bullet patterns)
	var frame = Engine.get_physics_frames()
	if frame != _last_fire_sfx_frame:
		_last_fire_sfx_frame = frame
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("fire_a", -10.0, 0.2)
	return bullet

func _spawn_bullet_at(container: Node, pos: Vector2, dir: Vector2, spd: float) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.global_position = pos
	bullet.direction = dir
	_apply_enemy_bullet_props(bullet, spd)
	container.add_child(bullet)

func _spawn_behavior_bullet(container: Node, dir: Vector2, spd: float, bhv: int) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = dir
	bullet.behavior = bhv
	bullet._origin_pos = global_position
	bullet._origin_entity = self
	_apply_enemy_bullet_props(bullet, spd)
	container.add_child(bullet)

## SHIELD_BASH: Spawns a frontal barrier arc then charges at player
func _shoot_shield_bash(dir: Vector2) -> void:
	var sfx_sh = get_node_or_null("/root/SFXManager")
	if sfx_sh:
		sfx_sh.play("spell_a", -5.0, 0.1)
	var bc = _get_bullets_container()
	if not bc:
		return
	# Spawn a 3-segment barrier arc in front of the enemy
	var perp = dir.rotated(PI * 0.5)
	var center = global_position + dir * 10.0
	for i in range(3):
		var offset = perp * ((i - 1) * 7.0)
		var b = bullet_scene.instantiate()
		b.global_position = center + offset
		b.direction = Vector2.ZERO
		b.behavior = b.BulletBehavior.BARRIER
		b.barrier_hp = shield_hp if shield_hp > 0 else 3
		b.lifetime = 3.0
		_apply_enemy_bullet_props(b, 0.0)
		bc.add_child(b)
	# Also shoot at player through the shield
	_shoot_single(dir)
	# Brief charge forward
	charge_dir = dir
	charge_timer = 0.25
	state = State.CHARGING

## VOLLEY: Lobs a spread of small bombs toward the player area — area denial
func _shoot_volley(_dir: Vector2) -> void:
	if not is_instance_valid(player):
		return
	var sfx_v = get_node_or_null("/root/SFXManager")
	if sfx_v:
		sfx_v.play("shoot_b", -6.0, 0.1)
	var bc = _get_bullets_container()
	if not bc:
		return
	var count = clampi(_get_active_bullet_count(), 3, 6)
	var target_center = player.global_position
	# Scatter lobbed shots in a pattern around the player
	for i in range(count):
		var angle = (TAU / count) * i
		var offset = Vector2(cos(angle), sin(angle)) * randf_range(8, 18)
		var target = target_center + offset
		get_tree().create_timer(i * 0.1).timeout.connect(
			func():
				if is_instance_valid(self) and hp > 0:
					var bcc = _get_bullets_container()
					if bcc:
						_spawn_lob_at(bcc, target, ObjSpriteIndex.FIREBALL, 8.0, 0.5, 4, 0)
		)

## CROSS_SHOT: Fires + pattern, then delayed X pattern — two interlocked crosses
func _shoot_cross(dir: Vector2) -> void:
	var sfx_cr = get_node_or_null("/root/SFXManager")
	if sfx_cr:
		sfx_cr.play("fire_b", -6.0, 0.1)
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var bspeed = definition.bullet_speed if definition else 75.0
	# First cross: cardinal directions (+ shape)
	for arm in range(4):
		var arm_dir = Vector2.RIGHT.rotated(arm * PI / 2.0)
		_spawn_bullet(bullets_container, arm_dir, bspeed)
		_spawn_bullet(bullets_container, arm_dir, bspeed * 0.6)
	# Delayed second cross: diagonal (X shape)
	get_tree().create_timer(0.3).timeout.connect(
		func():
			if not is_instance_valid(self) or hp <= 0:
				return
			var bc = _get_bullets_container()
			if not bc:
				return
			if sfx_cr:
				sfx_cr.play("fire_b", -8.0, 0.1)
			for arm in range(4):
				var arm_dir = Vector2.RIGHT.rotated(arm * PI / 2.0 + PI / 4.0)
				_spawn_bullet(bc, arm_dir, bspeed * 0.9)
				_spawn_bullet(bc, arm_dir, bspeed * 0.5)
	)

## WAVE_SHOT: Sine-wave spread — bullets fan out then converge in a wave pattern
func _shoot_wave(dir: Vector2) -> void:
	var sfx_wv = get_node_or_null("/root/SFXManager")
	if sfx_wv:
		sfx_wv.play("spell_a", -7.0, 0.15)
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 5)
	var bspeed = definition.bullet_speed if definition else 65.0
	var perp = dir.rotated(PI / 2.0)
	for i in range(count):
		var t = float(i) / (count - 1)
		var wave_offset = sin(t * PI * 2.0) * 8.0
		var spawn_pos = global_position + perp * wave_offset
		_spawn_bullet_at(bullets_container, spawn_pos, dir, bspeed)

## GATLING: Long burst of fast bullets tracking the player — machine gun
func _shoot_gatling(dir: Vector2) -> void:
	var sfx_gt = get_node_or_null("/root/SFXManager")
	if sfx_gt:
		sfx_gt.play("blaster", -6.0, 0.1)
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 8) + 4  # longer burst than other attacks
	var bspeed = (definition.bullet_speed if definition else 90.0) * 1.3
	for i in range(count):
		get_tree().create_timer(i * 0.05).timeout.connect(
			func():
				if not is_instance_valid(self) or hp <= 0:
					return
				var bc = _get_bullets_container()
				if not bc:
					return
				# Re-aim at player each shot for tracking stream
				var aim = dir
				if is_instance_valid(player):
					aim = (player.global_position - global_position).normalized()
				var jitter = randf_range(-0.08, 0.08)
				_spawn_bullet(bc, aim.rotated(jitter), bspeed)
		)

## MORTAR: Lobs bombs in high arc toward player area — artillery barrage
func _shoot_mortar(_dir: Vector2) -> void:
	if not is_instance_valid(player):
		return
	var sfx_mt = get_node_or_null("/root/SFXManager")
	if sfx_mt:
		sfx_mt.play("bazooka", -6.0, 0.12)
	var bc = _get_bullets_container()
	if not bc:
		return
	var count = clampi(_get_active_bullet_count(), 2, 4)
	var radius = definition.bomb_aoe_radius if definition else 12.0
	var flight = (definition.bomb_flight_time if definition else 0.6) * 1.5
	for i in range(count):
		var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		var target = player.global_position + offset
		get_tree().create_timer(i * 0.3).timeout.connect(
			func():
				if is_instance_valid(self) and hp > 0:
					var bcc = _get_bullets_container()
					if bcc:
						_spawn_lob_at(bcc, target, ObjSpriteIndex.FIREBALL, radius, flight, 8, 0)
		)

## NOVA: Double ring burst — inner ring fast, outer ring slow with offset
func _shoot_nova(dir: Vector2) -> void:
	var sfx_nv = get_node_or_null("/root/SFXManager")
	if sfx_nv:
		sfx_nv.play("area_effect_b", -5.0, 0.08)
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 6)
	var bspeed = definition.bullet_speed if definition else 70.0
	var base_angle = dir.angle()  # center on player direction
	# Inner ring: fast, one bullet aimed at player
	var inner = maxi(count / 2, 4)
	for i in range(inner):
		var angle = base_angle + (TAU / inner) * i
		_spawn_bullet(bullets_container, Vector2.from_angle(angle), bspeed * 1.5)
	# Outer ring: slow, offset by half step, delayed
	get_tree().create_timer(0.15).timeout.connect(
		func():
			if is_instance_valid(self) and hp > 0:
				var bc = _get_bullets_container()
				if bc:
					var outer = count
					var half_step = TAU / outer / 2.0
					for j in range(outer):
						var angle = base_angle + (TAU / outer) * j + half_step
						_spawn_bullet(bc, Vector2.from_angle(angle), bspeed * 0.6)
	)

## ZIGZAG: Alternating left-right angled shots for a weaving bullet wall
func _shoot_zigzag(dir: Vector2) -> void:
	var sfx_zz = get_node_or_null("/root/SFXManager")
	if sfx_zz:
		sfx_zz.play("woosh_b", -7.0, 0.12)
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 5)
	var bspeed = definition.bullet_speed if definition else 75.0
	var zigzag_angle = 0.35
	for i in range(count):
		var side = 1.0 if i % 2 == 0 else -1.0
		var bullet_dir = dir.rotated(zigzag_angle * side)
		get_tree().create_timer(i * 0.06).timeout.connect(
			func():
				if is_instance_valid(self) and hp > 0:
					var bc = _get_bullets_container()
					if bc:
						_spawn_bullet(bc, bullet_dir, bspeed)
		)

## SHOTGUN_BLAST: Very wide cone, short-lived bullets — close-range devastation
func _shoot_shotgun(dir: Vector2) -> void:
	var sfx_sg = get_node_or_null("/root/SFXManager")
	if sfx_sg:
		sfx_sg.play("shotgun", -5.0, 0.1)
	var bc = _get_bullets_container()
	if not bc:
		return
	var count = maxi(_get_active_bullet_count(), 7)
	var bspeed = (definition.bullet_speed if definition else 80.0) * 1.4
	var cone = 1.2  # very wide cone
	for i in range(count):
		var angle = randf_range(-cone / 2.0, cone / 2.0)
		var spd = bspeed * randf_range(0.7, 1.3)
		var b = bullet_scene.instantiate()
		b.global_position = global_position
		b.direction = dir.rotated(angle)
		b.lifetime = 0.6  # short range — dies quickly
		_apply_enemy_bullet_props(b, spd)
		bc.add_child(b)

## HELIX: Two intertwined spiraling bullet streams — continuous double helix
var _helix_angle: float = 0.0
func _shoot_helix(dir: Vector2) -> void:
	var sfx_hx = get_node_or_null("/root/SFXManager")
	if sfx_hx:
		sfx_hx.play("spell_b", -7.0, 0.15)
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var bspeed = definition.bullet_speed if definition else 70.0
	# Fire 4 rapid pairs for a visible helix pattern
	for v in range(4):
		get_tree().create_timer(v * 0.1).timeout.connect(
			func():
				if not is_instance_valid(self) or hp <= 0:
					return
				var bc = _get_bullets_container()
				if not bc:
					return
				var angle = _helix_angle + v * 0.6
				for stream in range(2):
					var offset = angle + stream * PI
					var bullet_dir = dir.rotated(sin(offset) * 0.7)
					var perp = dir.rotated(PI / 2.0)
					var spawn_pos = global_position + perp * cos(offset) * 8.0
					_spawn_bullet_at(bc, spawn_pos, bullet_dir, bspeed)
		)
	_helix_angle += 2.4

## METEOR_SHOWER: Rains large lobbed meteors across the area — chaos from above
func _shoot_meteor_shower(_dir: Vector2) -> void:
	if not is_instance_valid(player):
		return
	var sfx_ms = get_node_or_null("/root/SFXManager")
	if sfx_ms:
		sfx_ms.play("scatter", -5.0, 0.1)
	var bc = _get_bullets_container()
	if not bc:
		return
	var count = clampi(_get_active_bullet_count(), 3, 6)
	# Rain meteors in random spots near player
	for i in range(count):
		var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		var target = player.global_position + offset
		get_tree().create_timer(i * 0.25).timeout.connect(
			func():
				if is_instance_valid(self) and hp > 0:
					var bcc = _get_bullets_container()
					if bcc:
						_spawn_lob_at(bcc, target, ObjSpriteIndex.FIREBALL, 14.0, 0.7, 6, 0)
		)

## BOOMERANG_SHOT: Fires bullets that arc out and curve back toward the enemy
func _shoot_boomerang(dir: Vector2) -> void:
	var sfx_bm = get_node_or_null("/root/SFXManager")
	if sfx_bm:
		sfx_bm.play("woosh_b", -6.0, 0.12)
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 3)
	var bspeed = (definition.bullet_speed if definition else 75.0) * 0.8
	var spread = 0.6
	for i in range(count):
		var t = float(i) / maxf(count - 1, 1) - 0.5
		var b = bullet_scene.instantiate()
		b.global_position = global_position
		b.direction = dir.rotated(t * spread)
		b.is_player_bullet = false
		b.speed = bspeed
		b.behavior = b.BulletBehavior.BOOMERANG
		b._origin_pos = global_position
		b._origin_entity = self
		b._max_travel = randf_range(35.0, 55.0)
		b.lifetime = 5.0
		_apply_enemy_bullet_props(b, bspeed)
		bullets_container.add_child(b)

## STRAFE_RUN: Fires a spread while moving perpendicular — hit-and-run style
func _shoot_strafe_run(dir: Vector2) -> void:
	var sfx_sr = get_node_or_null("/root/SFXManager")
	if sfx_sr:
		sfx_sr.play("shoot_b", -7.0, 0.1)
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 4)
	var bspeed = (definition.bullet_speed if definition else 80.0) * 1.1
	for i in range(count):
		get_tree().create_timer(i * 0.08).timeout.connect(
			func():
				if is_instance_valid(self) and is_instance_valid(player) and hp > 0:
					var bc = _get_bullets_container()
					if bc:
						# Re-aim at player each shot — tracks during strafe
						var aim = (player.global_position - global_position).normalized()
						var jitter = randf_range(-0.1, 0.1)
						_spawn_bullet(bc, aim.rotated(jitter), bspeed)
		)

## MINEFIELD: Drops slow-moving bullets in all directions around self — area denial
func _shoot_minefield() -> void:
	var sfx_mf = get_node_or_null("/root/SFXManager")
	if sfx_mf:
		sfx_mf.play("spell_a", -7.0, 0.2)
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 8)
	var bspeed = (definition.bullet_speed if definition else 50.0) * 0.3  # very slow
	for i in range(count):
		var angle = (TAU / count) * i + randf() * 0.3
		var spawn_offset = Vector2.RIGHT.rotated(angle) * randf_range(4.0, 12.0)
		_spawn_bullet_at(bullets_container, global_position + spawn_offset, Vector2.RIGHT.rotated(angle), bspeed)

## RETURNING_VOLLEY: Fires bullets that curve back toward the enemy after traveling a distance
func _shoot_returning(dir: Vector2) -> void:
	var sfx_rv = get_node_or_null("/root/SFXManager")
	if sfx_rv:
		sfx_rv.play("swerve", -6.0, 0.1)
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 4)
	var bspeed = definition.bullet_speed if definition else 70.0
	var spread = 0.5
	for i in range(count):
		var t = float(i) / maxf(count - 1, 1) - 0.5
		var angle = t * spread
		var b = bullet_scene.instantiate()
		b.global_position = global_position
		b.direction = dir.rotated(angle)
		b.is_player_bullet = false
		b.speed = bspeed * randf_range(0.8, 1.2)
		b.behavior = b.BulletBehavior.RETURNING
		b._origin_pos = global_position
		b._origin_entity = self
		b._max_travel = randf_range(40.0, 70.0)
		b.lifetime = 5.0
		bullets_container.add_child(b)

## SEEKING_MINES: Drops slow homing mines that drift toward the player
func _shoot_seeking_mines() -> void:
	var sfx_sm = get_node_or_null("/root/SFXManager")
	if sfx_sm:
		sfx_sm.play("spell_a", -7.0, 0.15)
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 3)
	var bspeed = (definition.bullet_speed if definition else 50.0) * 0.2
	for i in range(count):
		var angle = (TAU / count) * i + randf() * 0.4
		var spawn_offset = Vector2.RIGHT.rotated(angle) * randf_range(6.0, 14.0)
		var b = bullet_scene.instantiate()
		b.global_position = global_position + spawn_offset
		b.direction = Vector2.RIGHT.rotated(angle)
		b.is_player_bullet = false
		b.speed = bspeed
		b.behavior = b.BulletBehavior.SEEKING_MINE
		b._origin_pos = global_position
		b.lifetime = 8.0
		bullets_container.add_child(b)

## DETONATOR: Fires bullets that decelerate and explode into sub-bullets when stopped
func _shoot_detonator(dir: Vector2) -> void:
	var sfx_dt = get_node_or_null("/root/SFXManager")
	if sfx_dt:
		sfx_dt.play("fire_c", -6.0, 0.1)
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 3)
	var bspeed = (definition.bullet_speed if definition else 80.0) * 1.2
	for i in range(count):
		var spread = randf_range(-0.2, 0.2)
		var b = bullet_scene.instantiate()
		b.global_position = global_position
		b.direction = dir.rotated(spread)
		b.is_player_bullet = false
		b.speed = bspeed
		b.behavior = b.BulletBehavior.DECELERATING
		b._origin_pos = global_position
		b._decel_rate = randf_range(60.0, 120.0)
		b.lifetime = 4.0
		bullets_container.add_child(b)

## SPLITTER: Fires bullets aimed at player that split halfway to the target
func _shoot_splitter(dir: Vector2) -> void:
	var sfx_sp = get_node_or_null("/root/SFXManager")
	if sfx_sp:
		sfx_sp.play("spell_b", -6.0, 0.12)
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 2)
	var bspeed = (definition.bullet_speed if definition else 65.0) * 0.6  # slower approach
	var dist_to_player = global_position.distance_to(player.global_position) if is_instance_valid(player) else 60.0
	# Split timer = time to travel half the distance to player
	var split_time = maxf((dist_to_player * 0.5) / maxf(bspeed, 1.0), 0.3)
	for i in range(count):
		var spread = float(i) / maxf(count - 1, 1) - 0.5
		var b = bullet_scene.instantiate()
		b.global_position = global_position
		b.direction = dir.rotated(spread * 0.2)  # tighter aim at player
		b.is_player_bullet = false
		b.speed = bspeed
		b.behavior = b.BulletBehavior.SPLITTING
		b._origin_pos = global_position
		b._split_count = randi_range(3, 5)
		b.set_meta("split_time", split_time)
		b.lifetime = 4.0
		bullets_container.add_child(b)

## SINE_BARRAGE: Fires sine-wave bullets that oscillate while traveling — hard to dodge
func _shoot_sine_barrage(dir: Vector2) -> void:
	var sfx_sb = get_node_or_null("/root/SFXManager")
	if sfx_sb:
		sfx_sb.play("wiggle_a", -6.0, 0.1)
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 4)
	var bspeed = definition.bullet_speed if definition else 70.0
	for i in range(count):
		var spread = float(i) / maxf(count - 1, 1) - 0.5
		var b = bullet_scene.instantiate()
		b.global_position = global_position
		b.direction = dir.rotated(spread * 0.3)
		b.is_player_bullet = false
		b.speed = bspeed * randf_range(0.8, 1.1)
		b.behavior = b.BulletBehavior.SINE_WAVE
		b._origin_pos = global_position
		b._base_direction = b.direction
		b._sine_amplitude = randf_range(4.0, 10.0)
		b._sine_frequency = randf_range(6.0, 12.0)
		b.lifetime = 4.0
		bullets_container.add_child(b)

## HOMING_SALVO: Fires bullets that home toward the player — missile volley
func _shoot_homing_salvo(dir: Vector2) -> void:
	var sfx_hs = get_node_or_null("/root/SFXManager")
	if sfx_hs:
		sfx_hs.play("fire_b", -5.0, 0.1)
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 3)
	var bspeed = (definition.bullet_speed if definition else 60.0) * 0.7
	for i in range(count):
		get_tree().create_timer(i * 0.1).timeout.connect(
			func():
				if not is_instance_valid(self) or hp <= 0:
					return
				var bc = _get_bullets_container()
				if not bc:
					return
				# Fire in a wide arc — homing will correct course
				var spread_angle = randf_range(-0.8, 0.8)
				var b = bullet_scene.instantiate()
				b.global_position = global_position
				b.direction = dir.rotated(spread_angle)
				b.is_player_bullet = false
				b.speed = bspeed * randf_range(0.9, 1.3)
				b.behavior = b.BulletBehavior.HOMING_ENEMY
				b._origin_pos = global_position
				b.lifetime = 5.0
				bc.add_child(b)
		)

## TELEGRAPH_EXPLOSION: Spawns a warning marker at player's position, then explodes after delay
func _shoot_telegraph_explosion() -> void:
	if not is_instance_valid(player):
		return
	var sfx_te = get_node_or_null("/root/SFXManager")
	if sfx_te:
		sfx_te.play("ping", -4.0, 0.0)
	var target_pos = player.global_position
	# Visual telegraph: flash a warning at the target location
	var marker = Sprite2D.new()
	var radius = 24
	var img = Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
	for y in range(radius * 2):
		for x in range(radius * 2):
			var dx = x - float(radius)
			var dy = y - float(radius)
			var dist_sq = dx * dx + dy * dy
			if dist_sq < radius * radius:
				# Red circle with bright edge
				var t = sqrt(dist_sq) / radius
				var alpha = 0.3 + t * 0.4
				img.set_pixel(x, y, Color(1.0, 0.15, 0.0, alpha))
	marker.texture = ImageTexture.create_from_image(img)
	marker.global_position = target_pos
	marker.z_index = 1
	get_tree().current_scene.add_child(marker)
	# Blink the marker
	var tween = create_tween()
	tween.tween_property(marker, "modulate:a", 0.2, 0.3)
	tween.tween_property(marker, "modulate:a", 1.0, 0.3)
	tween.tween_property(marker, "modulate:a", 0.2, 0.2)
	tween.tween_property(marker, "modulate:a", 1.0, 0.2)
	# Explode after delay
	if not is_inside_tree():
		return
	get_tree().create_timer(1.0).timeout.connect(
		func():
			if is_instance_valid(marker):
				marker.queue_free()
			# Spawn ring of bullets at the telegraph position
			var sfx_boom = get_node_or_null("/root/SFXManager")
			if sfx_boom:
				sfx_boom.play("boom_b", -3.0, 0.08)
			var bc = _get_bullets_container()
			if not bc:
				return
			var ring_count = 12
			var bspeed = definition.bullet_speed if definition else 70.0
			for j in range(ring_count):
				var angle = (TAU / ring_count) * j
				var b = bullet_scene.instantiate()
				b.global_position = target_pos
				b.direction = Vector2.RIGHT.rotated(angle)
				b.is_player_bullet = false
				b.speed = bspeed * 0.8
				b.lifetime = 3.0
				bc.add_child(b)
			# Direct damage in radius
			if is_instance_valid(player):
				if player.global_position.distance_to(target_pos) < 20.0:
					if player.has_method("take_damage"):
						var dmg = definition.attack_damage if definition else 2
						player.take_damage(dmg, target_pos)
	)

## ORBIT_LAUNCH: Spawns bullets that orbit around the enemy then launch outward
func _shoot_orbit_launch(dir: Vector2) -> void:
	var sfx_ol = get_node_or_null("/root/SFXManager")
	if sfx_ol:
		sfx_ol.play("sorcery", -6.0, 0.12)
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 4)
	var bspeed = definition.bullet_speed if definition else 70.0
	for i in range(count):
		var angle = (TAU / count) * i
		var orbit_offset = Vector2.RIGHT.rotated(angle) * 12.0
		var b = bullet_scene.instantiate()
		b.global_position = global_position + orbit_offset
		b.direction = dir  # launch direction after orbit completes
		b.is_player_bullet = false
		b.speed = bspeed
		b.behavior = b.BulletBehavior.ORBITING
		b._origin_pos = global_position
		b._origin_entity = self
		b._orbit_center = global_position
		b._orbit_radius = 12.0
		b._orbit_time = randf_range(0.4, 0.8)
		b.lifetime = 5.0
		bullets_container.add_child(b)

## WALL_BOUNCE: Spread of bullets that bounce off walls
func _shoot_wall_bounce(dir: Vector2) -> void:
	var sfx_wb = get_node_or_null("/root/SFXManager")
	if sfx_wb:
		sfx_wb.play("rebound", -6.0, 0.1)
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 3)
	var bspeed = (definition.bullet_speed if definition else 70.0) * 0.9
	var bounces = definition.bounce_count if definition and definition.bounce_count > 0 else 2
	var spread = 0.5
	for i in range(count):
		var t = float(i) / (count - 1) - 0.5 if count > 1 else 0.0
		var b = bullet_scene.instantiate()
		b.global_position = global_position
		b.direction = dir.rotated(t * spread)
		b.behavior = b.BulletBehavior.WALL_BOUNCE
		b.bounce_count = bounces
		b.lifetime = 4.0
		_apply_enemy_bullet_props(b, bspeed)
		bullets_container.add_child(b)

## LASER_GRID: 4 perpendicular beams of tightly-packed bullets
func _shoot_laser_grid(_dir: Vector2) -> void:
	var sfx_lg = get_node_or_null("/root/SFXManager")
	if sfx_lg:
		sfx_lg.play("laser_b", -5.0, 0.08)
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var bspeed = (definition.bullet_speed if definition else 70.0) * 1.2
	# Fire 4 cardinal beams, each with multiple bullets for a laser-line feel
	for arm in range(4):
		var arm_dir = Vector2.RIGHT.rotated(arm * PI / 2.0)
		for j in range(5):
			var delay = j * 0.08
			get_tree().create_timer(delay).timeout.connect(
				func():
					if is_instance_valid(self) and hp > 0:
						var bc = _get_bullets_container()
						if bc:
							var b = bullet_scene.instantiate()
							b.global_position = global_position
							b.direction = arm_dir
							b.lifetime = 1.5
							_apply_enemy_bullet_props(b, bspeed)
							bc.add_child(b)
			)

## GRAVITY_WELL: Slow orb that pulls player toward it, then explodes into a ring
func _shoot_gravity_well(dir: Vector2) -> void:
	var sfx_gw = get_node_or_null("/root/SFXManager")
	if sfx_gw:
		sfx_gw.play("special_a", -5.0, 0.1)
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var bspeed = 25.0  # intentionally slow
	# Spawn the gravity orb (large, slow)
	var orb = bullet_scene.instantiate()
	orb.global_position = global_position
	orb.direction = dir
	orb.lifetime = 3.0
	orb.bullet_sprite_index = 192  # pink_star for visibility
	_apply_enemy_bullet_props(orb, bspeed)
	bullets_container.add_child(orb)
	# After 3 seconds, explode into a ring of bullets at the orb's position
	get_tree().create_timer(2.8).timeout.connect(
		func():
			if is_instance_valid(orb):
				var pos = orb.global_position
				var bc = _get_bullets_container()
				if bc:
					for i in range(12):
						var angle = (TAU / 12.0) * i
						var sub = bullet_scene.instantiate()
						sub.global_position = pos
						sub.direction = Vector2.from_angle(angle)
						sub.is_player_bullet = false
						sub.damage = definition.attack_damage if definition else 2
						sub.speed = 90.0
						sub.lifetime = 2.0
						sub.enemy_kingdom = definition.kingdom if definition else ""
						bc.add_child(sub)
	)
	# Pull effect: periodically nudge player toward orb
	for tick in range(6):
		get_tree().create_timer(0.5 * tick).timeout.connect(
			func():
				if is_instance_valid(orb) and is_instance_valid(player):
					var pull_dir = (orb.global_position - player.global_position)
					if pull_dir.length() < 100.0:
						# Stronger pull closer to orb
						var strength = lerpf(30.0, 10.0, pull_dir.length() / 100.0)
						player.velocity += pull_dir.normalized() * strength
		)

## CHAIN_LIGHTNING: Instant chain of damage areas from enemy to player with visual bolt
func _shoot_chain_lightning(dir: Vector2) -> void:
	if not is_instance_valid(player):
		return
	var sfx_cl = get_node_or_null("/root/SFXManager")
	if sfx_cl:
		sfx_cl.play("lightning_a", -4.0, 0.1)
	var bc = _get_bullets_container()
	if not bc:
		return
	var start = global_position
	var target = player.global_position
	var chain_count = 6
	var step = (target - start) / chain_count
	# Create visual lightning bolt line
	var bolt_line = Line2D.new()
	bolt_line.width = 2.0
	bolt_line.default_color = Color(0.4, 0.7, 1.0, 0.9)
	bolt_line.z_index = 5
	for i in range(chain_count + 1):
		var pt = start + step * i
		# Jitter intermediate points for jagged lightning look
		if i > 0 and i < chain_count:
			pt += Vector2(randf_range(-6, 6), randf_range(-6, 6))
		bolt_line.add_point(pt)
	get_tree().current_scene.add_child(bolt_line)
	# Fade and remove bolt
	var tw = create_tween()
	tw.tween_property(bolt_line, "modulate:a", 0.0, 0.4)
	tw.tween_callback(bolt_line.queue_free)
	# Spawn damage areas along the chain that linger briefly
	for i in range(chain_count):
		var seg_pos = start + step * (i + 0.5) + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		var delay = i * 0.05
		get_tree().create_timer(delay).timeout.connect(
			func():
				if is_instance_valid(self):
					var bcc = _get_bullets_container()
					if bcc:
						var b = bullet_scene.instantiate()
						b.global_position = seg_pos
						b.direction = Vector2.ZERO
						b.lifetime = 0.5
						b.bullet_sprite_index = 176
						_apply_enemy_bullet_props(b, 0.0)
						b.speed = 0.0
						bcc.add_child(b)
						# VFX spark
						var vfx = get_node_or_null("/root/VFXManager")
						if vfx:
							vfx.hit_spark(seg_pos, Color(0.4, 0.7, 1.0))
		)
	# Direct damage if player is in chain path
	if is_instance_valid(player):
		var dist = start.distance_to(target)
		if dist < 80.0:
			# Check if player is roughly along the bolt line
			var to_player = player.global_position - start
			var bolt_dir = (target - start).normalized()
			var proj = to_player.dot(bolt_dir)
			var perp_dist = abs(to_player.cross(bolt_dir))
			if proj > 0 and perp_dist < 15.0 and player.has_method("take_damage"):
				var dmg = definition.attack_damage if definition else 2
				player.take_damage(dmg, start)

## DEATH_SPIRAL: Expanding spiral of bullets fired from a position (used on death)
func _shoot_death_spiral_at(pos: Vector2) -> void:
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	var bspeed = 50.0
	var arms = 3
	var bullets_per_arm = 8
	for i in range(bullets_per_arm):
		var delay = i * 0.12
		get_tree().create_timer(delay).timeout.connect(
			func():
				var bc = _get_bullets_container()
				if bc:
					for arm in range(arms):
						var base_angle = (TAU / arms) * arm
						var spiral_angle = base_angle + i * 0.4
						var b = bullet_scene.instantiate()
						b.global_position = pos
						b.direction = Vector2.from_angle(spiral_angle)
						b.is_player_bullet = false
						b.damage = definition.attack_damage if definition else 2
						b.speed = bspeed + i * 8.0
						b.lifetime = 3.0
						b.enemy_kingdom = definition.kingdom if definition else ""
						bc.add_child(b)
		)

## --- Barrier / Pull / Push Attacks ---

## BARRIER_WALL: Spawns a line of stationary barrier bullets perpendicular to player direction
## Max 1 wall alive at a time — won't spawn if existing barriers are still up
func _shoot_barrier_wall(dir: Vector2) -> void:
	var bc = _get_bullets_container()
	if not bc:
		return
	# Boss/large enemies get 2 walls (6 segments), normal gets 1 wall (3 segments)
	var max_segments = 6 if _is_boss_or_large else 3
	var existing_barriers := 0
	for child in bc.get_children():
		if child is Area2D and child.has_method("queue_free") and child.get("behavior") != null:
			if child.behavior == child.BulletBehavior.BARRIER:
				existing_barriers += 1
	if existing_barriers >= max_segments:
		return  # walls still up, skip
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("spell_a", -5.0, 0.1)
	var perp = dir.rotated(PI * 0.5)
	# Boss/large: 5 segments per wall, wider spacing. Normal: 3 segments.
	var count = 5 if _is_boss_or_large else 3
	var spacing = 10.0 if _is_boss_or_large else 8.0
	var seg_hp = 5 if _is_boss_or_large else 3
	var seg_lifetime = 6.0 if _is_boss_or_large else 4.0
	var center = global_position + dir * 15.0
	for i in range(count):
		var offset = perp * ((i - count / 2.0) * spacing)
		var b = bullet_scene.instantiate()
		b.global_position = center + offset
		b.direction = Vector2.ZERO
		b.behavior = b.BulletBehavior.BARRIER
		b.barrier_hp = seg_hp
		b.lifetime = seg_lifetime
		_apply_enemy_bullet_props(b, 0.0)
		b.bullet_sprite_index = ObjSpriteIndex.STAR_BURST
		bc.add_child(b)

## PULL_SHOT: Fires a slow orb toward player that pulls when nearby — large zone, long-lived
func _shoot_pull_shot(dir: Vector2) -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("special_a", -5.0, 0.1)
	var bc = _get_bullets_container()
	if not bc:
		return
	var bspeed = (definition.bullet_speed if definition else 50.0) * 0.1  # very slow crawl
	var b = bullet_scene.instantiate()
	b.global_position = global_position
	b.direction = dir
	b.behavior = b.BulletBehavior.PULL_ORB
	b._force_radius = 48.0  # large zone of influence
	b._force_strength = 3.0  # firm pull toward orb
	b.lifetime = randf_range(6.0, 10.0)  # persists a long time
	_apply_enemy_bullet_props(b, bspeed)
	b.bullet_sprite_index = ObjSpriteIndex.DARK_ORB
	bc.add_child(b)

## PUSH_WAVE: Fires slow orbs in a cone toward the player — large zones, long-lived
func _shoot_push_wave(dir: Vector2) -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("area_effect_b", -5.0, 0.1)
	var bc = _get_bullets_container()
	if not bc:
		return
	var bspeed = (definition.bullet_speed if definition else 50.0) * 0.1  # very slow
	var count = clampi(_get_active_bullet_count(), 2, 3)
	var cone_angle = PI * 0.4  # ~72 degree cone
	for i in range(count):
		var t = float(i) / max(count - 1, 1) - 0.5  # -0.5 to 0.5
		var d = dir.rotated(t * cone_angle)
		var b = bullet_scene.instantiate()
		b.global_position = global_position
		b.direction = d
		b.behavior = b.BulletBehavior.PUSH_ORB
		b._force_radius = 45.0  # large zone of influence
		b._force_strength = 4.0  # firm push away
		b.lifetime = randf_range(6.0, 10.0)  # persists a long time
		_apply_enemy_bullet_props(b, bspeed)
		b.bullet_sprite_index = ObjSpriteIndex.HOLY_ORB
		bc.add_child(b)

## --- New Pattern Attacks ---

## VORTEX: Spawns a swirling ring of bullets that tighten inward toward the player
func _shoot_vortex(dir: Vector2) -> void:
	var sfx_vx = get_node_or_null("/root/SFXManager")
	if sfx_vx:
		sfx_vx.play("spell_b", -5.0, 0.1)
	var bc = _get_bullets_container()
	if not bc:
		return
	var count = maxi(_get_active_bullet_count(), 6)
	var bspeed = (definition.bullet_speed if definition else 60.0) * 0.5
	# Fire bullets in a wide circle that slowly home toward player
	for i in range(count):
		var angle = (TAU / count) * i
		var spawn_offset = Vector2.from_angle(angle) * 30.0
		var b = bullet_scene.instantiate()
		b.global_position = global_position + spawn_offset
		# Initial direction is tangential (perpendicular to radius) creating a swirl
		b.direction = spawn_offset.normalized().rotated(PI * 0.5)
		b.is_player_bullet = false
		b.speed = bspeed
		b.behavior = b.BulletBehavior.HOMING_ENEMY
		b._origin_pos = global_position
		b.lifetime = 4.0
		_apply_enemy_bullet_props(b, bspeed)
		b.bullet_sprite_index = ObjSpriteIndex.GLOW_PURPLE
		bc.add_child(b)

## RING_PULSE: Multiple timed rings that expand outward with gaps to dodge through
func _shoot_ring_pulse(dir: Vector2) -> void:
	var sfx_rp = get_node_or_null("/root/SFXManager")
	if sfx_rp:
		sfx_rp.play("area_effect_a", -5.0, 0.1)
	var bspeed = (definition.bullet_speed if definition else 60.0) * 0.7
	var ring_count = 3  # 3 waves
	var bullets_per_ring = maxi(_get_active_bullet_count(), 6)
	# Leave a gap in each ring for the player to dodge through
	var gap_size = 1  # 1 bullet-slot gap
	for wave in range(ring_count):
		get_tree().create_timer(wave * 0.5).timeout.connect(
			func():
				if not is_instance_valid(self) or hp <= 0:
					return
				var bc = _get_bullets_container()
				if not bc:
					return
				# Rotate the gap position each wave so player must move
				var gap_start = randi_range(0, bullets_per_ring - 1)
				for i in range(bullets_per_ring):
					if i >= gap_start and i < gap_start + gap_size:
						continue  # gap slot
					var angle = (TAU / bullets_per_ring) * i + wave * 0.3
					_spawn_bullet(bc, Vector2.from_angle(angle), bspeed * (1.0 + wave * 0.15))
				if sfx_rp:
					sfx_rp.play("fire_b", -8.0, 0.1)
		)

## ARTILLERY: Single high-damage lobbed bomb with huge AOE + bullet ring explosion
func _shoot_artillery() -> void:
	if not is_instance_valid(player):
		return
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("bazooka", -3.0, 0.08)
	var bc = _get_bullets_container()
	if not bc:
		return
	var radius = (definition.bomb_aoe_radius if definition else 16.0) * 1.5
	var flight = (definition.bomb_flight_time if definition else 0.8) * 1.5
	# Single big bomb: large AOE, ring of sub-bullets, high damage
	_spawn_lob_at(bc, player.global_position, ObjSpriteIndex.DARK_ORB, radius, flight, 8, 0, 3.0, 3.0)

## WHIP_LASH: Quick sweeping arc of bullets fired in rapid sequence
func _shoot_whip_lash(dir: Vector2) -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("blaster", -5.0, 0.1)
	var bc = _get_bullets_container()
	if not bc:
		return
	var count = maxi(_get_active_bullet_count(), 8)
	var bspeed = (definition.bullet_speed if definition else 80.0) * 1.1
	var sweep_arc = PI * 0.6  # 108 degree sweep
	var start_angle = dir.angle() - sweep_arc * 0.5
	for i in range(count):
		get_tree().create_timer(i * 0.03).timeout.connect(
			func():
				if not is_instance_valid(self) or hp <= 0:
					return
				var bcc = _get_bullets_container()
				if not bcc:
					return
				var t = float(i) / maxf(count - 1, 1)
				var angle = start_angle + sweep_arc * t
				_spawn_bullet(bcc, Vector2.from_angle(angle), bspeed)
		)

## POISON_CLOUD: Lobbed bomb that creates a lingering poison zone on impact
func _shoot_poison_cloud() -> void:
	if not is_instance_valid(player):
		return
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("scatter", -5.0, 0.1)
	var bc = _get_bullets_container()
	if not bc:
		return
	var radius = (definition.bomb_aoe_radius if definition else 16.0) * 1.2
	var flight = definition.bomb_flight_time if definition else 0.8
	# Lob a poison bomb — on landing, create a lingering cloud
	var bomb = bullet_scene.instantiate()
	bomb.global_position = global_position
	bomb.direction = (player.global_position - global_position).normalized()
	bomb.behavior = bomb.BulletBehavior.LOBBED
	bomb._target_pos = player.global_position
	bomb._lob_duration = flight * 2.0
	bomb._lob_aoe_radius = radius
	bomb._lob_ring_count = 0
	bomb._lob_cluster_count = 0
	bomb._lob_is_bomb = true
	bomb.set_meta("poison_cloud", true)  # flag for special landing behavior
	bomb.set_meta("poison_cloud_duration", 4.0)
	bomb.set_meta("poison_cloud_radius", radius)
	_apply_enemy_bullet_props(bomb, 0.0)
	bomb.damage = maxi(1, int(bomb.damage * 1.5))
	bomb.bullet_sprite_index = ObjSpriteIndex.POISON_BALL
	bc.add_child(bomb)
	_spawn_landing_marker(player.global_position, radius, flight * 2.0)

## DASH_STRIKE: Quick dash toward player, firing bouncing bullets behind
func _shoot_dash_strike(dir: Vector2) -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("dash", -4.0, 0.1)
	# Fire a spread of bouncing bullets behind as we charge
	var bc = _get_bullets_container()
	if bc:
		var back_dir = -dir
		var count = maxi(_get_active_bullet_count(), 4)
		var bspeed = (definition.bullet_speed if definition else 60.0) * 0.8
		for i in range(count):
			var spread = (float(i) / maxf(count - 1, 1) - 0.5) * PI * 0.4
			var b = _spawn_bullet(bc, back_dir.rotated(spread), bspeed)
			if b:
				b.behavior = b.BulletBehavior.WALL_BOUNCE
				b.bounce_count = 3
	# Dash toward player
	charge_dir = dir
	charge_timer = 0.35
	state = State.CHARGING

## --- New Attack Types (56-61) ---

## LANCE_THRUST: 3-4 bullets in a line with staggered delay — piercing attack
func _shoot_lance_thrust(dir: Vector2) -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("slash_a", -5.0, 0.1)
	var bc = _get_bullets_container()
	if not bc:
		return
	var count = clampi(_get_active_bullet_count(), 3, 4)
	var bspeed = (definition.bullet_speed if definition else 80.0)
	for i in range(count):
		var delay = i * 0.05
		get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(self) and state != State.DEAD:
				var b = _spawn_bullet(bc, dir, bspeed * (1.0 + i * 0.1))
				if b:
					b.lifetime = 2.5
		)

## SHIELD_WALL: 3-5 barrier bullets in arc facing player — defensive screen
func _shoot_shield_wall(dir: Vector2) -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("spell_a", -5.0, 0.1)
	var bc = _get_bullets_container()
	if not bc:
		return
	var count = clampi(_get_active_bullet_count(), 3, 5)
	var perp = dir.rotated(PI * 0.5)
	var center = global_position + dir * 12.0
	var spacing = 8.0
	for i in range(count):
		var offset = perp * ((float(i) - (count - 1) * 0.5) * spacing)
		var b = bullet_scene.instantiate()
		b.global_position = center + offset
		b.direction = Vector2.ZERO
		b.behavior = b.BulletBehavior.BARRIER
		b.barrier_hp = shield_hp if shield_hp > 0 else 3
		b.lifetime = 4.0
		_apply_enemy_bullet_props(b, 0.0)
		bc.add_child(b)

## CURSE_BOLT: Single slow homing projectile that applies random debuff
func _shoot_curse_bolt(dir: Vector2) -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("mystical", -5.0, 0.1)
	var bc = _get_bullets_container()
	if not bc:
		return
	var bspeed = (definition.bullet_speed if definition else 80.0) * 0.4
	var b = _spawn_bullet(bc, dir, bspeed)
	if b:
		b.behavior = b.BulletBehavior.HOMING_ENEMY
		b.lifetime = 5.0
		b.bullet_sprite_index = ObjSpriteIndex.DARK_ORB
		# Apply random debuff on hit via meta
		var debuffs = ["SLOWED", "POISONED", "BURNING"]
		b.set_meta("apply_status", debuffs[randi() % debuffs.size()])
		b.set_meta("status_duration", 3.0)

## SUMMON_WALL: Summon 2-3 weak minions in a line between self and player
func _shoot_summon_wall(dir: Vector2) -> void:
	if not definition:
		return
	var _container = get_parent()
	if _container and _container.get_child_count() >= MAX_SUMMONED_ENEMIES:
		return
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("summon", -4.0, 0.1)
	# Auto-create minion def if needed
	if not definition.summon_definition:
		var minion_def = EnemyDefinition.new()
		minion_def.enemy_name = "Minion"
		minion_def.max_hp = maxi(1, definition.max_hp / 4)
		minion_def.move_speed = definition.move_speed * 1.2
		minion_def.attack_type = EnemyDefinition.AttackType.MELEE
		minion_def.attack_damage = maxi(1, definition.attack_damage)
		minion_def.attack_speed = 1.5
		minion_def.bullet_speed = 60.0
		minion_def.bullet_count = 1
		minion_def.kingdom = definition.kingdom
		minion_def.use_loy_sprite = definition.use_loy_sprite
		minion_def.loy_tile_index = definition.loy_tile_index
		minion_def.sprite_color = definition.sprite_color.darkened(0.3)
		minion_def.xp_value = 1
		minion_def.score_value = 2
		definition.summon_definition = minion_def
	var enemy_scene = preload("res://scenes/enemy.tscn")
	var container = get_parent()
	var count = clampi(definition.summon_count, 2, 3)
	var perp = dir.rotated(PI * 0.5)
	var mid = global_position + dir * 20.0
	for i in range(count):
		var offset = perp * ((float(i) - (count - 1) * 0.5) * 12.0)
		var spawn_pos = mid + offset
		var minion = enemy_scene.instantiate()
		minion.global_position = spawn_pos
		minion.setup(definition.summon_definition.duplicate())
		container.add_child(minion)
		var gp = get_meta("grid_pos", Vector2i(-999, -999))
		if gp != Vector2i(-999, -999):
			minion.set_meta("grid_pos", gp)
			var dm = get_tree().get_first_node_in_group("dungeon_manager") if is_inside_tree() else null
			if dm and dm.room_states.has(gp):
				dm.room_states[gp]["alive"] += 1
				minion.tree_exited.connect(dm._on_enemy_died.bind(gp))

## LEAPING_SLAM: Jump to player position, AOE shockwave + bullet ring on land
func _shoot_leaping_slam(dir: Vector2) -> void:
	if not is_instance_valid(player):
		return
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("dash", -4.0, 0.1)
	var target = player.global_position
	# Telegraph with landing marker
	var radius = definition.slam_radius if definition else 24.0
	_spawn_landing_marker(target, radius, 0.5)
	# Brief invulnerability during jump
	$CollisionShape2D.set_deferred("disabled", true)
	$Sprite2D.modulate.a = 0.4
	# Jump arc via tween
	var tween = create_tween()
	tween.tween_property(self, "global_position", target, 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		if not is_instance_valid(self) or state == State.DEAD:
			return
		$CollisionShape2D.set_deferred("disabled", false)
		var orig_color = definition.sprite_color if definition else Color.WHITE
		$Sprite2D.modulate = orig_color
		# AOE slam damage
		_do_slam()
		# Bullet ring on landing
		var bc = _get_bullets_container()
		if bc:
			var ring_count = maxi(_get_active_bullet_count(), 8)
			var bspeed = (definition.bullet_speed if definition else 80.0)
			for i in range(ring_count):
				var angle = TAU / ring_count * i
				_spawn_bullet(bc, Vector2(cos(angle), sin(angle)), bspeed)
		var sfx2 = get_node_or_null("/root/SFXManager")
		if sfx2:
			sfx2.play("boom_a", -2.0, 0.08)
	)

## ARROW_VOLLEY: 3-5 lobbed arrows that rain down around player position
func _shoot_arrow_volley() -> void:
	if not is_instance_valid(player):
		return
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("scatter", -5.0, 0.1)
	var bc = _get_bullets_container()
	if not bc:
		return
	var count = clampi(_get_active_bullet_count(), 3, 5)
	var radius = (definition.bomb_aoe_radius if definition else 16.0) * 0.5
	var base_flight = (definition.bomb_flight_time if definition else 0.8) * 0.8
	var center = player.global_position
	for i in range(count):
		var offset = Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
		var flight = base_flight + randf_range(0.0, 0.3)
		_spawn_lob_at(bc, center + offset, ObjSpriteIndex.FIREBALL, radius, flight, 0, 0, -1.0, 1.5)

## --- Lobbed Bomb Attacks ---

## Landing marker: blinking orange circle at target position
class _LandingMarkerDraw extends Node2D:
	var radius: float = 16.0
	var duration: float = 0.6
	var _elapsed: float = 0.0
	func _process(delta: float) -> void:
		_elapsed += delta
		queue_redraw()
		if _elapsed >= duration:
			get_parent().queue_free()
	func _draw() -> void:
		var pulse = 0.08 + 0.07 * abs(sin(_elapsed * 8.0))
		# Subtle transparent fill
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.3, 0.0, pulse * 0.4))
		# Thin pulsing ring outline
		draw_arc(Vector2.ZERO, radius, 0, TAU, 24, Color(1.0, 0.5, 0.0, pulse * 1.5), 0.5, true)

func _spawn_landing_marker(target_pos: Vector2, radius: float, duration: float) -> void:
	var marker = Node2D.new()
	marker.global_position = target_pos
	marker.z_index = 1  # above floor tiles, below enemies
	var draw_node = _LandingMarkerDraw.new()
	draw_node.radius = radius
	draw_node.duration = duration
	marker.add_child(draw_node)
	if is_inside_tree():
		get_tree().current_scene.add_child(marker)

func _spawn_lob_at(container: Node, target: Vector2, sprite_idx: int,
		aoe_radius: float, flight_time: float, ring_count: int, cluster_count: int,
		lob_height: float = -1.0, damage_mult: float = 2.0) -> void:
	var bomb = bullet_scene.instantiate()
	bomb.global_position = global_position
	bomb.direction = (target - global_position).normalized() if global_position.distance_to(target) > 1 else Vector2.RIGHT
	bomb.behavior = bomb.BulletBehavior.LOBBED
	bomb._target_pos = target
	bomb._lob_duration = flight_time * 2.0  # moderate arcs, time to dodge but not too slow
	bomb._lob_aoe_radius = aoe_radius
	bomb._lob_ring_count = ring_count
	bomb._lob_cluster_count = cluster_count
	bomb._lob_is_bomb = true  # flag for smaller sprite
	# Boss enemies get bigger bomb arcs
	if lob_height >= 0:
		bomb._lob_height = lob_height
	elif definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS:
		bomb._lob_height = 2.5
	_apply_enemy_bullet_props(bomb, 0.0)
	bomb.damage = maxi(2, int(bomb.damage * damage_mult))  # bombs hit harder than regular bullets
	bomb.bullet_sprite_index = sprite_idx  # override after apply so bomb sprite is always correct
	container.add_child(bomb)
	_spawn_landing_marker(target, aoe_radius, flight_time * 2.0)

## BOMB_TOSS: Single bomb at player position, explodes into bullet ring
func _shoot_bomb_toss() -> void:
	if not is_instance_valid(player):
		return
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("bazooka", -5.0, 0.12)
	var bc = _get_bullets_container()
	if not bc:
		return
	var radius = definition.bomb_aoe_radius if definition else 16.0
	var flight = definition.bomb_flight_time if definition else 0.6
	_spawn_lob_at(bc, player.global_position, ObjSpriteIndex.FIREBALL, radius, flight, 0, 0)

## CARPET_BOMB: 3-5 bombs in a line from enemy toward player
func _shoot_carpet_bomb(dir: Vector2) -> void:
	if not is_instance_valid(player):
		return
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("bazooka", -5.0, 0.1)
	var bc = _get_bullets_container()
	if not bc:
		return
	var count = clampi(_get_active_bullet_count(), 3, 5)
	var dist_to_player = global_position.distance_to(player.global_position)
	var step = maxf(dist_to_player / count, 10.0)
	var radius = (definition.bomb_aoe_radius if definition else 16.0) * 0.9
	var base_flight = (definition.bomb_flight_time if definition else 0.8)
	for i in range(count):
		var target = global_position + dir * step * (i + 1)
		var flight = base_flight + i * 0.2  # stagger more so carpet rolls out slowly
		_spawn_lob_at(bc, target, ObjSpriteIndex.FIREBALL, radius, flight, 0, 0, -1.0, 1.8)

## FIRE_RAIN: 2-4 bombs scattered randomly around player position
func _shoot_fire_rain() -> void:
	if not is_instance_valid(player):
		return
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("scatter", -5.0, 0.1)
	var bc = _get_bullets_container()
	if not bc:
		return
	var count = clampi(_get_active_bullet_count(), 2, 4)
	var radius = (definition.bomb_aoe_radius if definition else 16.0) * 0.7
	var base_flight = (definition.bomb_flight_time if definition else 0.8)
	var center = player.global_position
	for i in range(count):
		var offset = Vector2(randf_range(-28.0, 28.0), randf_range(-28.0, 28.0))
		var flight = base_flight + randf_range(0.0, 0.4)
		_spawn_lob_at(bc, center + offset, ObjSpriteIndex.FIREBALL, radius, flight, 0, 0, -1.0, 2.0)

## CLUSTER_BOMB: One big bomb that splits into 4 smaller bombs on impact
func _shoot_cluster_bomb() -> void:
	if not is_instance_valid(player):
		return
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("bazooka", -4.0, 0.1)
	var bc = _get_bullets_container()
	if not bc:
		return
	var radius = definition.bomb_aoe_radius if definition else 16.0
	var flight = (definition.bomb_flight_time if definition else 0.8) * 1.2
	_spawn_lob_at(bc, player.global_position, ObjSpriteIndex.DARK_ORB, radius, flight, 0, 4, -1.0, 2.5)

## MINE_DROP: 2-3 short-range lobs near self with bullet ring on landing
func _shoot_mine_drop() -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("ping", -6.0, 0.1)
	var bc = _get_bullets_container()
	if not bc:
		return
	var count = clampi(_get_active_bullet_count(), 2, 3)
	var radius = (definition.bomb_aoe_radius if definition else 16.0) * 0.6
	for i in range(count):
		var offset = Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
		var target = global_position + offset
		_spawn_lob_at(bc, target, ObjSpriteIndex.ENERGY_BALL, radius, 0.3, 6, 0)

## Fire death bullet pattern at death position
func _fire_death_pattern() -> void:
	var pattern = definition.death_bullet_pattern
	var pos = global_position
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	match pattern:
		EnemyDefinition.AttackType.BURST:
			# Death explosion ring
			var count = 12
			var bspeed = definition.bullet_speed if definition else 70.0
			for i in range(count):
				var angle = (TAU / count) * i
				var b = bullet_scene.instantiate()
				b.global_position = pos
				b.direction = Vector2.from_angle(angle)
				b.is_player_bullet = false
				b.damage = maxi(1, definition.attack_damage / 2)
				b.speed = bspeed
				b.lifetime = 2.0
				b.enemy_kingdom = definition.kingdom
				bullets_container.add_child(b)
		EnemyDefinition.AttackType.SPIRAL, EnemyDefinition.AttackType.DEATH_SPIRAL:
			_shoot_death_spiral_at(pos)
		EnemyDefinition.AttackType.NOVA:
			# Double ring
			var bspeed = definition.bullet_speed if definition else 60.0
			for ring in range(2):
				var count = 10 + ring * 4
				for i in range(count):
					var angle = (TAU / count) * i + ring * 0.2
					var b = bullet_scene.instantiate()
					b.global_position = pos
					b.direction = Vector2.from_angle(angle)
					b.is_player_bullet = false
					b.damage = maxi(1, definition.attack_damage / 2)
					b.speed = bspeed + ring * 20.0
					b.lifetime = 2.5
					b.enemy_kingdom = definition.kingdom
					bullets_container.add_child(b)
		_:
			# Fallback: simple burst
			for i in range(8):
				var angle = (TAU / 8.0) * i
				var b = bullet_scene.instantiate()
				b.global_position = pos
				b.direction = Vector2.from_angle(angle)
				b.is_player_bullet = false
				b.damage = maxi(1, (definition.attack_damage if definition else 2) / 2)
				b.speed = 60.0
				b.lifetime = 2.0
				b.enemy_kingdom = definition.kingdom if definition else ""
				bullets_container.add_child(b)

func _has_line_of_sight() -> bool:
	if not is_instance_valid(player):
		return false
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position, 16)  # wall layer only
	query.exclude = [get_rid()]
	var result = space.intersect_ray(query)
	return result.is_empty()  # no wall between us = has LOS

## Shared vision: for Mummy (check attached ally LOS) and Arch Mage (check any nearby ally LOS)
func _has_line_of_sight_or_shared() -> bool:
	if _has_line_of_sight():
		return true
	if not definition:
		return false
	var atk = definition.attack_type
	# Mummy: raycast from attached ally to player
	if atk == EnemyDefinition.AttackType.PUSH_WAVE:
		if is_instance_valid(_attached_ally) and is_instance_valid(player):
			var space = get_world_2d().direct_space_state
			var q = PhysicsRayQueryParameters2D.create(_attached_ally.global_position, player.global_position, 16)
			q.exclude = [_attached_ally.get_rid()]
			return space.intersect_ray(q).is_empty()
	# Arch Mage / Artillery: use cached shared vision result
	if atk in [EnemyDefinition.AttackType.FIRE_RAIN, EnemyDefinition.AttackType.ARTILLERY]:
		return _shared_vision_has_los
	return false

## Mummy: attach to strongest ally in same room on first aggro
func _attach_to_strongest_ally() -> void:
	if _attached_ally != null:
		return  # already attached
	var my_gp = get_meta("grid_pos", Vector2i(-999, -999))
	var best: Node2D = null
	var best_hp: int = 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not is_instance_valid(e):
			continue
		if e.get_meta("grid_pos", Vector2i(-998, -998)) != my_gp:
			continue
		if e.hp > best_hp:
			best_hp = e.hp
			best = e
	if best:
		_attached_ally = best
		_bodyguard_mode = true
		if best.is_inside_tree():
			best.tree_exiting.connect(_on_guarded_ally_died, CONNECT_ONE_SHOT)

func _on_guarded_ally_died() -> void:
	_attached_ally = null
	_bodyguard_mode = false

func _on_guarded_ally_hit() -> void:
	_bodyguard_mode = false
	_chase_timer = 0.0
	_hit_aggro_timer = 5.0

## Called from take_damage — alert attached mummies that this enemy was hit
func _notify_bodyguards_ally_hit() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if e._attached_ally == self and e._bodyguard_mode:
			e._on_guarded_ally_hit()

## Update the awareness indicator (? or !) above sprite
func _update_awareness_indicator() -> void:
	if not _awareness_indicator:
		return
	if _awareness < 0.3:
		_awareness_indicator.visible = false
	elif _awareness < 0.7:
		_awareness_indicator.visible = true
		_awareness_indicator.text = "?"
		_awareness_indicator.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0, 0.5 + _awareness))
	else:
		_awareness_indicator.visible = true
		_awareness_indicator.text = "!"
		_awareness_indicator.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1, 0.7 + _awareness * 0.3))

## Called when awareness reaches ALERT threshold (≥ 0.7) — enter CHASE
func _on_awareness_alert() -> void:
	if state == State.CHASE or state == State.ATTACK or state == State.DEAD:
		return
	state = State.CHASE
	_last_pos = global_position
	if _awareness_indicator:
		_awareness_indicator.visible = false
	_spread_aggro()
	# Mummy: attach to strongest ally on first aggro
	if definition and definition.attack_type == EnemyDefinition.AttackType.PUSH_WAVE:
		_attach_to_strongest_ally()
	# Arch Mage / Artillery: shared vision check
	if definition and definition.attack_type in [EnemyDefinition.AttackType.FIRE_RAIN, EnemyDefinition.AttackType.ARTILLERY]:
		_check_shared_vision_once()
	# Elite aggro taunt: brief pause + scale pulse
	if definition and definition.size_class == EnemyDefinition.SizeClass.LARGE and not _elite_taunt_done:
		_elite_taunt_done = true
		var spr_t = $Sprite2D
		var orig_scale = spr_t.scale
		var tw = create_tween()
		tw.tween_property(spr_t, "scale", orig_scale * 1.3, 0.15)
		tw.tween_property(spr_t, "scale", orig_scale, 0.15)
	# Aggro SFX based on kingdom
	var sfx_ag = get_node_or_null("/root/SFXManager")
	if sfx_ag and definition:
		match definition.kingdom:
			"undead": sfx_ag.play("skeleton", -10.0, 0.2)
			"crawler": sfx_ag.play("beetle", -10.0, 0.2)
			"animal": sfx_ag.play("bird", -10.0, 0.2)
			"demon": sfx_ag.play("shriek", -10.0, 0.2)
			"orc": sfx_ag.play("claw", -10.0, 0.2)

## Transition from CHASE to INVESTIGATE — move to player's last known position then continue in their direction
func _begin_search() -> void:
	_chase_timer = 0.0
	_awareness = 0.5
	if _last_known_player_pos != Vector2.ZERO:
		_investigate_pos = _last_known_player_pos
		_investigate_dir = _last_known_player_dir
	else:
		_investigate_pos = global_position
		_investigate_dir = Vector2.ZERO
	_investigate_phase = 0
	_investigate_timer = 0.0
	_investigate_look_timer = 0.0
	var is_true_boss = definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS
	if is_true_boss:
		state = State.IDLE  # true bosses just reset (they never deaggro anyway)
	else:
		state = State.INVESTIGATE

## Spread aggro to nearby idle/investigating enemies when this one enters combat
func _spread_aggro() -> void:
	if not is_inside_tree():
		return
	var spread_range = 40.0  # ~5 tiles in dungeon
	if not _dm:
		spread_range = 160.0  # larger range in overworld
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not is_instance_valid(e):
			continue
		if e.state == State.DEAD or e.state == State.CHASE or e.state == State.ATTACK:
			continue
		if e.global_position.distance_to(global_position) > spread_range:
			continue
		# Passive enemies don't get alerted by neighbors
		if e.has_meta("passive_until_hit") and e.get_meta("passive_until_hit"):
			continue
		# Confused enemies can't contribute to shared awareness
		if e.has_meta("confused") and e.get_meta("confused"):
			continue
		# Spread awareness — elites get less, normal enemies get more
		var spread_amount = _awareness * 0.5
		if e._is_boss_or_large:
			spread_amount = _awareness * 0.3
		e._awareness = minf(e._awareness + spread_amount, 1.0)
		e._update_awareness_indicator()
		# If awareness crossed alert threshold, enter chase
		if e._awareness >= 0.7:
			e._on_awareness_alert()
		elif e._awareness >= 0.3 and e.state == State.IDLE:
			e._investigate_pos = global_position
			e._investigate_dir = (global_position - e.global_position).normalized()
			e._investigate_phase = 0
			e._investigate_timer = 0.0
			e._investigate_look_timer = 0.0
			e.state = State.INVESTIGATE

## Shared vision: check if any ally has LOS to player
## Arch Mage: one-time check (nearby allies only)
## Artillery: periodic re-check (any ally, unlimited range)
func _check_shared_vision_once() -> void:
	var is_artillery = definition and definition.attack_type == EnemyDefinition.AttackType.ARTILLERY
	if not is_artillery and _shared_vision_checked:
		return
	_shared_vision_checked = true
	_shared_vision_has_los = false
	if not is_instance_valid(player):
		return
	var max_ally_dist = 500.0 if is_artillery else 80.0
	var space = get_world_2d().direct_space_state
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not is_instance_valid(e):
			continue
		if e.global_position.distance_to(global_position) > max_ally_dist:
			continue
		var q = PhysicsRayQueryParameters2D.create(e.global_position, player.global_position, 16)
		q.exclude = [e.get_rid()]
		if space.intersect_ray(q).is_empty():
			_shared_vision_has_los = true
			return

func take_damage(amount: int, from_player: bool = true) -> void:
	if state == State.DEAD:
		return
	if from_player:
		# Passive enemies become hostile when hit by player
		if has_meta("passive_until_hit") and get_meta("passive_until_hit"):
			set_meta("passive_until_hit", false)
		# Instant full awareness on player damage
		_awareness = 1.0
		_update_awareness_indicator()
		# Getting hit by player always aggros and resets chase timer
		if state == State.IDLE or state == State.INVESTIGATE:
			state = State.CHASE
		_chase_timer = 0.0
		_hit_aggro_timer = 5.0  # stay aggro for 5s even if player is far away
		# Alert nearby enemies — combat awareness spread
		_spread_aggro()
	else:
		# Environmental/trap damage — don't reveal player location
		if state == State.IDLE:
			_investigate_pos = global_position
			_investigate_dir = Vector2.ZERO
			_investigate_phase = 0
			_investigate_timer = 0.0
			_investigate_look_timer = 0.0
			var is_true_boss_td = definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS
			if not is_true_boss_td:
				state = State.INVESTIGATE
		# If already CHASE, stay in CHASE (don't de-aggro)
	# Apply armor reduction (minimum 1 damage always gets through)
	if armor > 0:
		amount = maxi(1, amount - armor)
	hp -= amount
	_time_since_hit = 0.0
	# Alert attached mummy bodyguards that this enemy was hit
	_notify_bodyguards_ally_hit()
	# Floating damage number
	var scene_root = get_tree().current_scene if is_inside_tree() else null
	if scene_root and amount > 0:
		FloatingText.spawn_damage(scene_root, global_position, amount, Color(1.0, 1.0, 0.3))
	var orig_color = definition.sprite_color if definition else Color.WHITE
	$Sprite2D.modulate = Color.WHITE * 3
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate", orig_color, 0.1)
	# VFX: blood splatter on hit
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		var hit_dir = Vector2.UP  # default
		var p = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
		if p and is_instance_valid(p):
			hit_dir = (global_position - p.global_position).normalized()
		vfx.blood_splatter(global_position, hit_dir, Color(0.7, 0.0, 0.0))
	# SFX: hit sound
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("hit", -3.0)
	_update_boss_hp_bar()
	if hp <= 0:
		_die()
		return
	_check_phase_transition()

func apply_status(status_name: String, duration: float) -> void:
	# Status immunity check
	if definition:
		if definition.status_immunities.has(status_name):
			var sr = get_tree().current_scene if is_inside_tree() else null
			if sr:
				FloatingText.spawn(sr, global_position + Vector2(0, -6), "IMMUNE", Color(0.8, 0.8, 0.8))
			return
		# Bosses auto-immune to hard CC
		if definition.size_class >= 2 and status_name in ["STUNNED", "FEARED", "CONFUSED"]:
			var sr = get_tree().current_scene if is_inside_tree() else null
			if sr:
				FloatingText.spawn(sr, global_position + Vector2(0, -6), "IMMUNE", Color(0.8, 0.8, 0.8))
			return
		# Elites: half duration on all statuses
		if definition.size_class == 1:
			duration *= 0.5
	# Apply visual tint for status effects
	var color = Color.WHITE
	match status_name:
		"BURNING": color = Color(1.0, 0.5, 0.2)
		"SLOWED": color = Color(0.4, 0.6, 1.0)
		"FROZEN": color = Color(0.3, 0.5, 1.0)
		"POISONED": color = Color(0.3, 0.8, 0.2)
		"STUNNED": color = Color(1.0, 1.0, 0.4)
		"FEARED": color = Color(0.9, 0.9, 0.5)
		"CONFUSED": color = Color(0.6, 0.3, 0.8)
	$Sprite2D.modulate = color
	# VFX + SFX for status applied
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.status_puff(global_position, status_name)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		match status_name:
			"BURNING": sfx.play("burn", -4.0)
			"SLOWED": sfx.play("freeze", -4.0)
			"FROZEN": sfx.play("freeze", -2.0)
			"POISONED": sfx.play("curse", -4.0)
			"STUNNED": sfx.play("impact_a", -4.0)
			"FEARED": sfx.play("shriek", -6.0)
			"CONFUSED": sfx.play("curse", -6.0)
	# Slow enemies when slowed
	if status_name == "SLOWED":
		speed *= 0.3
		shoot_interval *= 2.0
	if status_name == "FROZEN":
		speed *= 0.1
		shoot_interval *= 3.0
	# Stunned — can't move or attack
	if status_name == "STUNNED":
		speed = 0.0
		shoot_interval *= 99.0
		set_meta("stunned", true)
	# Feared — flee from player, can't attack
	if status_name == "FEARED":
		set_meta("feared", true)
		state = State.CHASE  # CHASE with feared flag = flee behavior
	# Confused — random movement, can friendly-fire
	if status_name == "CONFUSED":
		set_meta("confused", true)
		state = State.CHASE
	# Damage over time for burning/poison
	if status_name == "BURNING" or status_name == "POISONED":
		var tick_dmg = maxi(1, _max_hp / 20)
		var ticks = int(duration / 0.5)
		for i in range(ticks):
			get_tree().create_timer(0.5 * (i + 1)).timeout.connect(
				func():
					if is_instance_valid(self) and hp > 0:
						take_damage(tick_dmg, false)
			)
	# Feared: periodic panic noise that alerts other enemies (chain reactions)
	if status_name == "FEARED":
		var fear_noise_ticks = int(duration / 0.5)
		for i in range(fear_noise_ticks):
			get_tree().create_timer(0.5 * (i + 1)).timeout.connect(
				func():
					if is_instance_valid(self) and hp > 0 and has_meta("feared") and get_meta("feared"):
						hear_noise(global_position, 30.0)
			)
	# Confused: sprite wobble
	if status_name == "CONFUSED":
		var wobble_ticks = int(duration / 0.1)
		for i in range(wobble_ticks):
			get_tree().create_timer(0.1 * (i + 1)).timeout.connect(
				func():
					if is_instance_valid(self) and has_meta("confused") and get_meta("confused"):
						$Sprite2D.rotation = sin(float(i) * 2.0) * 0.2
			)
	# Feared: sprite flicker
	if status_name == "FEARED":
		var flicker_ticks = int(duration / 0.1)
		for i in range(flicker_ticks):
			get_tree().create_timer(0.1 * (i + 1)).timeout.connect(
				func():
					if is_instance_valid(self) and has_meta("feared") and get_meta("feared"):
						$Sprite2D.visible = (i % 2 == 0)
			)
	# Restore after duration
	get_tree().create_timer(duration).timeout.connect(
		func():
			if is_instance_valid(self):
				$Sprite2D.modulate = definition.sprite_color if definition else Color.WHITE
				$Sprite2D.visible = true
				$Sprite2D.rotation = 0.0
				if (status_name == "SLOWED" or status_name == "FROZEN") and definition:
					speed = definition.move_speed
					shoot_interval = definition.attack_speed
				if status_name == "STUNNED":
					if definition:
						speed = definition.move_speed
						shoot_interval = definition.attack_speed
					set_meta("stunned", false)
					_awareness = 0.0  # loses track of player after stun
					_update_awareness_indicator()
					if state == State.CHASE or state == State.ATTACK:
						state = State.IDLE
				if status_name == "FEARED":
					set_meta("feared", false)
					_awareness = 0.5
					_update_awareness_indicator()
					if definition:
						speed = definition.move_speed
				if status_name == "CONFUSED":
					set_meta("confused", false)
					_awareness = 0.3
					_update_awareness_indicator()
	)

func take_damage_from_front(amount: int, from_dir: Vector2) -> void:
	# Shield enemies block frontal damage
	if shield_hp > 0:
		var facing = Vector2.LEFT if $Sprite2D.flip_h else Vector2.RIGHT
		if from_dir.dot(facing) > 0.3:  # hitting the shield side
			shield_hp -= amount
			if shield_hp <= 0:
				shield_hp = 0
			# SFX + Flash blue for shield hit
			var sfx_sh = get_node_or_null("/root/SFXManager")
			if sfx_sh:
				sfx_sh.play("clack", -5.0, 0.12)
			$Sprite2D.modulate = Color.CYAN
			var tween = create_tween()
			tween.tween_property($Sprite2D, "modulate", definition.sprite_color if definition else Color.WHITE, 0.1)
			return
	take_damage(amount)

func hear_noise(pos: Vector2, radius: float) -> void:
	if state == State.DEAD:
		return
	# Already in combat — noise doesn't change state
	if state == State.CHASE or state == State.ATTACK:
		return
	# Bosses hear at half range, elites hear normally
	var is_true_boss = definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS
	var eff_radius = radius * 0.5 if is_true_boss else radius
	if global_position.distance_to(pos) > eff_radius:
		return
	# Add awareness instead of instant investigate — noise stacks
	_awareness = minf(_awareness + 0.4, 1.0)
	_update_awareness_indicator()
	# If awareness crossed threshold, transitions happen in next IDLE tick
	# But also set investigate target so INVESTIGATE state knows where to go
	if _awareness >= 0.3:
		_investigate_pos = pos
		_investigate_dir = Vector2.ZERO
		_investigate_phase = 0
		_investigate_timer = 0.0
		_investigate_look_timer = 0.0
		if _awareness >= 0.7:
			_on_awareness_alert()
		elif state == State.IDLE:
			state = State.INVESTIGATE

## Check if enemy landed on a trap or hazard after throw/nudge
func _check_hazard_at_position() -> void:
	if not is_inside_tree():
		return
	for t in get_tree().get_nodes_in_group("trap"):
		if is_instance_valid(t) and t.global_position.distance_to(global_position) < 10.0:
			if t.has_method("trigger_remote"):
				t.trigger_remote()

func apply_throw(dir: Vector2, force: float, thrower_dmg: int) -> void:
	if _is_boss_or_large and definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS:
		return  # bosses immune to throw
	var actual_force = force
	if _is_boss_or_large:
		actual_force *= 0.5  # elites: halved throw distance
	_thrown_velocity = dir * actual_force
	_thrown_timer = 0.4
	_thrower_dmg = thrower_dmg
	# White flash on grabbed enemy
	$Sprite2D.modulate = Color.WHITE * 3
	var tween = create_tween()
	var orig = definition.sprite_color if definition else Color.WHITE
	tween.tween_property($Sprite2D, "modulate", orig, 0.2)

func _check_phase_transition() -> void:
	if not definition or definition.boss_phases <= 1 or _max_hp <= 0:
		return
	var hp_percent = float(hp) / float(_max_hp)
	var new_phase = 1
	if definition.boss_phases >= 3 and hp_percent <= 0.33:
		new_phase = 3
	elif definition.boss_phases >= 2 and hp_percent <= 0.66:
		new_phase = 2
	if new_phase > _current_phase:
		_current_phase = new_phase
		_on_phase_change(new_phase)

func _on_phase_change(phase: int) -> void:
	# Flash white to signal phase change
	$Sprite2D.modulate = Color.WHITE * 4
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate", definition.sprite_color if definition else Color.WHITE, 0.4)
	var sfx_ph = get_node_or_null("/root/SFXManager")
	if sfx_ph:
		sfx_ph.play("special_b", -2.0, 0.05)
	var vfx_ph = get_node_or_null("/root/VFXManager")
	if vfx_ph:
		vfx_ph.shockwave(global_position, 24.0, Color(1.0, 0.3, 0.3, 0.6))
		vfx_ph.shake(2.5, 0.2)

	# Spawn minions on phase change
	if definition.summon_on_phase_change and definition.summon_definition:
		var spawn_count = definition.summon_phase_count
		var bullet_container = _get_bullets_container()
		var enemy_scene = load("res://scenes/enemy.tscn")
		var container = get_parent()
		if container and container.get_child_count() >= MAX_SUMMONED_ENEMIES:
			spawn_count = 0
		for i in range(spawn_count):
			var angle = TAU * float(i) / float(spawn_count)
			var offset = Vector2.RIGHT.rotated(angle) * 20.0
			var minion = enemy_scene.instantiate()
			minion.global_position = global_position + offset
			var minion_def = definition.summon_definition.duplicate()
			minion_def.max_hp = int(minion_def.max_hp * 0.5)  # minions are weaker
			container.add_child(minion)
			minion.setup(minion_def)
			if has_meta("grid_pos"):
				var gp_val = get_meta("grid_pos")
				minion.set_meta("grid_pos", gp_val)
				minion.tree_exited.connect(func():
					if not is_inside_tree():
						return
					var dm = get_tree().get_first_node_in_group("dungeon_manager")
					if dm:
						dm._on_enemy_died(gp_val)
				)

	# Increase speed slightly each phase
	speed *= 1.15
	shoot_interval *= 0.85  # attack faster

## Boss ground slam: AoE damage + destroy nearby obstacles
func _do_ground_slam() -> void:
	if not is_instance_valid(player):
		return
	# Brief pause
	velocity = Vector2.ZERO
	# Flash white
	$Sprite2D.modulate = Color.WHITE * 3
	var tw = create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(func():
		if not is_instance_valid(self):
			return
		# AoE damage
		var slam_radius = 25.0
		if is_instance_valid(player) and global_position.distance_to(player.global_position) < slam_radius:
			if player.has_method("take_damage"):
				var dmg = (definition.attack_damage if definition else 3) * 2
				player.take_damage(dmg, global_position)
		# VFX + SFX
		var vfx = get_node_or_null("/root/VFXManager")
		if vfx:
			vfx.shockwave(global_position, slam_radius, Color(0.8, 0.4, 0.1, 0.7))
			vfx.shake(3.0, 0.2)
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("explode_b", -3.0, 0.1)
		# Break nearby obstacles
		_break_nearby_obstacles()
		# Restore color
		var enrage_color = Color(1.5, 0.4, 0.4) if _enraged else (definition.sprite_color if definition else Color.WHITE)
		$Sprite2D.modulate = enrage_color
	)

## Break decoration and wall tiles near this enemy (boss/elite pathfinding aid)
## Both bosses and elites smash through obstacles and walls, creating new floor + wall edges
func _break_nearby_obstacles() -> void:
	if not _dm:
		return
	var is_boss = definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS
	var break_radius = 24.0 if is_boss else 18.0
	var smash_tile_radius = 2 if is_boss else 1
	var tile_size = 8

	# Directly scan deco_layer cells near the enemy — avoids world↔tile conversion bugs
	var broke_any = false
	for cell in _dm.deco_layer.get_used_cells():
		var cell_world = Vector2(cell.x * tile_size + tile_size * 0.5, cell.y * tile_size + tile_size * 0.5)
		if cell_world.distance_to(global_position) > break_radius:
			continue
		var atlas = _dm.deco_layer.get_cell_atlas_coords(cell)
		# Break any solid deco (rows 0-3 = barrels, furniture, chairs, stone pots)
		if atlas.y in [0, 1, 2, 3]:
			_dm.deco_layer.erase_cell(cell)
			if _dm.nav:
				_dm.nav.mark_walkable(cell)
			broke_any = true
			var vfx = get_node_or_null("/root/VFXManager")
			if vfx:
				vfx.death_burst(cell_world, Color(0.6, 0.4, 0.2), 0)

	# Also check forward (toward player) for obstacles just out of range
	if is_instance_valid(player) and state == State.CHASE:
		var toward = (player.global_position - global_position).normalized()
		var ahead_pos = global_position + toward * (break_radius + 4.0)
		var ahead_tile = Vector2i(int(floor(ahead_pos.x / tile_size)), int(floor(ahead_pos.y / tile_size)))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var t = ahead_tile + Vector2i(dx, dy)
				var src = _dm.deco_layer.get_cell_source_id(t)
				if src < 0:
					continue
				var atlas = _dm.deco_layer.get_cell_atlas_coords(t)
				if atlas.y in [0, 1, 2, 3]:
					_dm.deco_layer.erase_cell(t)
					if _dm.nav:
						_dm.nav.mark_walkable(t)
					broke_any = true

	# Smash walls + void → create new floor with wall edges
	var center_tile = Vector2i(int(floor(global_position.x / tile_size)), int(floor(global_position.y / tile_size)))
	var near_wall = false
	for offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
					Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var neighbor = center_tile + offset
		if _dm.wall_layer.get_cell_source_id(neighbor) >= 0:
			near_wall = true
			break

	# Break standalone physics objects (holes, placed obstacles) in "breakable" group
	for body in get_tree().get_nodes_in_group("breakable"):
		if is_instance_valid(body) and global_position.distance_to(body.global_position) < break_radius:
			if body.has_method("take_damage"):
				body.take_damage(999)
			else:
				body.queue_free()

	if near_wall and _dm.has_method("smash_area"):
		_dm.smash_area(global_position, smash_tile_radius)
	elif broke_any:
		if _dm.nav:
			_dm.nav.invalidate()
		# Directly rebuild collision — flush_deco_collisions() gates on _deco_dirty
		# which isn't set here, causing ghost collisions
		_dm._generate_wall_collisions()
		_dm._generate_deco_collisions()

func _die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	if _awareness_indicator:
		_awareness_indicator.visible = false

	# Explode on death
	if definition and definition.explodes_on_death:
		_explode_on_death()

	# Death bullet pattern
	if definition and definition.death_bullet_pattern != EnemyDefinition.AttackType.NONE:
		_fire_death_pattern()

	# Split on death (blob-like)
	if definition and definition.attack_type == EnemyDefinition.AttackType.SPLIT:
		if not definition.split_definition:
			# Auto-create smaller split copy
			var sd = definition.duplicate()
			sd.enemy_name = definition.enemy_name + " Shard"
			sd.max_hp = maxi(1, definition.max_hp / 3)
			sd.move_speed = definition.move_speed * 1.3
			sd.attack_type = EnemyDefinition.AttackType.MELEE
			sd.attack_damage = maxi(1, definition.attack_damage)
			sd.split_count = 0
			sd.split_definition = null  # no recursive split
			sd.xp_value = 1
			sd.score_value = 2
			sd.sprite_color = definition.sprite_color.lightened(0.2)
			definition.split_definition = sd
		_split_on_death()

	# Grant XP to player (elite 3x, boss 10x)
	if definition and definition.xp_value > 0 and is_instance_valid(player):
		if player.has_method("gain_xp"):
			var xp_mult = 1
			if definition.size_class == EnemyDefinition.SizeClass.BOSS:
				xp_mult = 10
			elif definition.size_class == EnemyDefinition.SizeClass.LARGE:
				xp_mult = 3
			player.gain_xp(definition.xp_value * xp_mult)

	# Massacre kill tracker
	if is_instance_valid(player) and player.has_method("on_enemy_killed_for_massacre"):
		player.on_enemy_killed_for_massacre()

	# Notify quest system
	if definition:
		var qm = get_node_or_null("/root/QuestManager")
		if qm:
			var kill_name = definition.quest_kill_name if definition.quest_kill_name != "" else definition.enemy_name
			qm.on_enemy_killed(kill_name)

	# Floating text for XP/gold (with size class multiplier)
	var xp_val = definition.xp_value if definition else 0
	if definition:
		if definition.size_class == EnemyDefinition.SizeClass.BOSS:
			xp_val *= 10
		elif definition.size_class == EnemyDefinition.SizeClass.LARGE:
			xp_val *= 3
	var gold_val = definition.score_value if definition else 5
	var scene_root = get_tree().current_scene if is_inside_tree() else null
	if scene_root:
		if xp_val > 0:
			FloatingText.spawn(scene_root, global_position + Vector2(0, -8), "+%d XP" % xp_val, Color(0.5, 1.0, 0.5))
		if gold_val > 0:
			FloatingText.spawn(scene_root, global_position + Vector2(0, 4), "+%d Gold" % gold_val, Color(1.0, 0.85, 0.2))

	# Gold drops as a gold pickup (not in a bag) — scaled by size class
	var gold = definition.score_value if definition else 5
	if definition:
		if definition.size_class >= 2:  # BOSS
			gold *= 5
		elif definition.size_class == 1:  # LARGE/elite
			gold *= 2
	if gold > 0:
		var pickup = pickup_scene.instantiate()
		pickup.gold_amount = gold
		pickup.global_position = global_position + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		if is_inside_tree():
			get_tree().current_scene.add_child(pickup)

	# Items drop in a loot bag (only if items rolled)
	var bag_items: Array[EquipmentItem] = []
	var is_boss = definition and definition.size_class >= 2
	var is_elite = definition and definition.size_class == 1

	# Consumable drops: apples and potions from any enemy
	if definition:
		var apple_chance = 0.12  # 12% apple
		var hp_pot_chance = 0.06  # 6% red potion
		var mp_pot_chance = 0.04  # 4% blue potion
		if is_elite:
			apple_chance = 0.20
			hp_pot_chance = 0.10
			mp_pot_chance = 0.08
		if randf() < apple_chance:
			var apple = load("res://resources/items/loy/apple.tres") as EquipmentItem
			if apple:
				bag_items.append(apple.make_copy())
		if randf() < hp_pot_chance:
			var hp_pot = load("res://resources/items/loy/red_potion.tres") as EquipmentItem
			if hp_pot:
				bag_items.append(hp_pot.make_copy())
		if randf() < mp_pot_chance:
			var mp_pot = load("res://resources/items/loy/blue_potion.tres") as EquipmentItem
			if mp_pot:
				bag_items.append(mp_pot.make_copy())

	# Boss guaranteed drops: potions + 2-3 equipment items
	if is_boss:
		var hp_pot = load("res://resources/items/loy/red_potion.tres") as EquipmentItem
		var mp_pot = load("res://resources/items/loy/blue_potion.tres") as EquipmentItem
		if hp_pot:
			for _j in range(randi_range(1, 2)):
				bag_items.append(hp_pot.make_copy())
		if mp_pot:
			for _j in range(randi_range(1, 2)):
				bag_items.append(mp_pot.make_copy())
		if drop_table:
			# Bosses drop 2-3 guaranteed equipment items
			var boss_roll_count = randi_range(2, 3)
			for _k in range(boss_roll_count):
				var boss_item = drop_table.roll()
				if boss_item:
					bag_items.append(boss_item.make_copy())
				else:
					# Guarantee at least something from the pool
					var fallback_items = drop_table.entries
					if fallback_items.size() > 0:
						bag_items.append(fallback_items[randi() % fallback_items.size()].item.make_copy())

	# Elite equipment drops: 1-2 items at 70% chance
	elif drop_table and is_elite:
		if randf() < 0.70:
			var roll_count = randi_range(1, 2)
			for _i in range(roll_count):
				var dropped = drop_table.roll()
				if dropped:
					bag_items.append(dropped.make_copy())

	# Normal enemy equipment drops: 1 item at 20% chance
	elif drop_table:
		if randf() < 0.20:
			var dropped = drop_table.roll()
			if dropped:
				bag_items.append(dropped.make_copy())

	if not bag_items.is_empty():
		var bag = LootBag.new()
		bag.items = bag_items
		bag.global_position = global_position + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		if is_inside_tree():
			get_tree().current_scene.add_child(bag)

	# Crafting material drops
	_try_drop_crafting_material()

	# VFX: death burst
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		var death_color = definition.sprite_color if definition else Color(0.8, 0.1, 0.1)
		var sc = definition.size_class if definition else 0
		vfx.death_burst(global_position, death_color, sc)
		if sc >= 2:
			vfx.shake(3.0, 0.25)  # bosses shake the screen
		elif sc == 1:
			vfx.shake(1.5, 0.15)
	# SFX: creature death cry based on kingdom
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		if definition:
			match definition.kingdom:
				"undead": sfx.play("skeleton", -6.0, 0.15)
				"crawler": sfx.play("beetle", -6.0, 0.15)
				"animal": sfx.play("mouse", -6.0, 0.15)
				"demon": sfx.play("mystical", -6.0, 0.15)
				"orc": sfx.play("claw", -6.0, 0.15)
				"magical": sfx.play("mystical", -6.0, 0.15)
		# Size-based death explosion
		var sc2 = definition.size_class if definition else 0
		if sc2 >= 2:
			sfx.play("explode_b", 0.0, 0.08)
		elif sc2 == 1:
			sfx.play("explode_a", -2.0, 0.08)
		else:
			sfx.play("explode_c", -5.0, 0.1)

	# Delay queue_free if death pattern uses timers (spiral/nova)
	if definition and definition.death_bullet_pattern != EnemyDefinition.AttackType.NONE:
		$Sprite2D.visible = false
		$CollisionShape2D.set_deferred("disabled", true)
		var hurtbox = get_node_or_null("Hurtbox")
		if hurtbox:
			hurtbox.monitoring = false
			hurtbox.monitorable = false
		get_tree().create_timer(2.0).timeout.connect(func(): queue_free())
	else:
		queue_free()

func _explode_on_death() -> void:
	var radius = definition.explode_radius if definition else 20.0
	var sfx_ex = get_node_or_null("/root/SFXManager")
	if sfx_ex:
		sfx_ex.play("boom_a", -2.0, 0.08)
	var vfx_ex = get_node_or_null("/root/VFXManager")
	if vfx_ex:
		vfx_ex.shockwave(global_position, radius, Color(1.0, 0.4, 0.1, 0.7))
	var bodies = get_tree().get_nodes_in_group("player")
	for body in bodies:
		if body.global_position.distance_to(global_position) < radius:
			if body.has_method("take_damage"):
				body.take_damage(definition.attack_damage if definition else 2, global_position)

func _split_on_death() -> void:
	var sfx_split = get_node_or_null("/root/SFXManager")
	if sfx_split:
		sfx_split.play("jelly", -4.0, 0.15)
	var count = definition.split_count if definition else 2
	var enemy_scene = preload("res://scenes/enemy.tscn")
	var container = get_parent()
	for i in range(count):
		var angle = TAU / count * i + randf() * 0.5
		var spawn_pos = global_position + Vector2(cos(angle), sin(angle)) * 8.0
		var minion = enemy_scene.instantiate()
		minion.global_position = spawn_pos
		minion.setup(definition.split_definition.duplicate())
		container.add_child(minion)
		var gp = get_meta("grid_pos", Vector2i(-999, -999))
		if gp != Vector2i(-999, -999):
			minion.set_meta("grid_pos", gp)
			var dm = get_tree().get_first_node_in_group("dungeon_manager") if is_inside_tree() else null
			if dm and dm.room_states.has(gp):
				dm.room_states[gp]["alive"] += 1
				minion.tree_exited.connect(dm._on_enemy_died.bind(gp))

# Material drop tables by kingdom
const KINGDOM_MATERIALS: Dictionary = {
	"undead": ["res://resources/items/crafting/bone_dust.tres"],
	"orc": ["res://resources/items/crafting/iron_ore.tres"],
	"crawler": ["res://resources/items/crafting/leather_scraps.tres", "res://resources/items/crafting/venom_sac.tres"],
	"animal": ["res://resources/items/crafting/leather_scraps.tres", "res://resources/items/crafting/venom_sac.tres"],
	"demon": ["res://resources/items/crafting/demon_shard.tres"],
	"magical": ["res://resources/items/crafting/magic_essence.tres"],
	"human": ["res://resources/items/crafting/iron_ore.tres", "res://resources/items/crafting/leather_scraps.tres"],
}
const RARE_MATERIALS: Array = [
	"res://resources/items/crafting/fire_crystal.tres",
	"res://resources/items/crafting/demon_shard.tres",
	"res://resources/items/crafting/magic_essence.tres",
]

func _try_drop_crafting_material() -> void:
	if not definition:
		return
	var drop_chance = 0.10  # 10% base (down from 25%)
	if definition.size_class == 1:
		drop_chance = 0.50
	elif definition.size_class >= 2:
		drop_chance = 1.0
	if randf() >= drop_chance:
		return

	var kingdom = definition.kingdom
	var possible: Array = KINGDOM_MATERIALS.get(kingdom, []) as Array
	if possible.is_empty():
		possible = ["res://resources/items/crafting/healing_herb.tres"]

	var mat_path: String = possible[randi() % possible.size()]
	var mat_item = load(mat_path) as EquipmentItem
	if not mat_item:
		return

	var mat_bag = LootBag.new()
	mat_bag.items = [mat_item.make_copy()] as Array[EquipmentItem]
	mat_bag.global_position = global_position + Vector2(randf_range(-4, 4), randf_range(-4, 4))
	if is_inside_tree():
		get_tree().current_scene.add_child(mat_bag)

	# Bosses also have a chance for rare materials
	if definition.size_class >= 2 and randf() < 0.5:
		var rare_path: String = RARE_MATERIALS[randi() % RARE_MATERIALS.size()]
		var rare_item = load(rare_path) as EquipmentItem
		if rare_item:
			mat_bag.items.append(rare_item.make_copy())

	# Healing herb has a small chance from any enemy
	if randf() < 0.08 and mat_path != "res://resources/items/crafting/healing_herb.tres":
		var herb = load("res://resources/items/crafting/healing_herb.tres") as EquipmentItem
		if herb:
			mat_bag.items.append(herb.make_copy())
