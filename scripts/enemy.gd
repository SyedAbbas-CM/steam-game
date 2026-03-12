extends CharacterBody2D

enum State { IDLE, CHASE, ATTACK, COOLDOWN, CHARGING, DEAD, STEALTHED }

var definition: EnemyDefinition
var hp: int = 3
var shield_hp: int = 0
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
const CHASE_TIMEOUT = 8.0  # give up after this many seconds
var _wander_timer: float = 0.0  # time until next wander direction change
var _wander_dir: Vector2 = Vector2.ZERO  # current wander direction
var _stuck_timer: float = 0.0  # detect if stuck on wall
var _last_pos: Vector2 = Vector2.ZERO
var _loy_sprite: Sprite2D  # separate sprite for LoY characters
var _current_phase: int = 1
var _max_hp: int = 0
var _animator: SpriteAnimator
var _nav: RefCounted  # DungeonNav A* navigation (set by dungeon manager)
var _path_timer: float = 0.0  # throttle pathfinding queries
var _cached_next_pos: Vector2 = Vector2.ZERO

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
var _weight: float = 1.0  # mass for collision momentum damage

@export var drop_table: DropTable

func _ready() -> void:
	bullet_scene = preload("res://scenes/bullet.tscn")
	pickup_scene = preload("res://scenes/pickup.tscn")
	collision_layer = 2
	collision_mask = 17  # collide with walls (16) + player (1)
	add_to_group("enemy")
	player = get_tree().get_first_node_in_group("player")

func setup(def: EnemyDefinition) -> void:
	definition = def
	hp = def.max_hp
	_max_hp = def.max_hp
	shield_hp = def.shield_hp
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
	match def.size_class:
		EnemyDefinition.SizeClass.NORMAL:
			_weight = 1.0
		EnemyDefinition.SizeClass.LARGE:
			scale = Vector2(2, 2)
			_weight = 2.5
		EnemyDefinition.SizeClass.BOSS:
			scale = Vector2(3, 3)
			_weight = 5.0

	# Ghost enemies phase through walls
	if def.ignores_terrain:
		$Sprite2D.modulate.a = 0.7
		collision_mask = 1  # ghosts phase through walls but still collide with player

	# Boss/Large HP bar
	_is_boss_or_large = def.size_class >= EnemyDefinition.SizeClass.LARGE
	if _is_boss_or_large:
		_create_boss_hp_bar()

	state = State.IDLE

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
	if state == State.DEAD:
		return
	if not is_instance_valid(player):
		return

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
	# Player stealth reduces aggro range
	if is_instance_valid(player) and player.get_node_or_null("EquipmentManager"):
		var stealth_val = player.equipment_manager.get_stealth()
		if stealth_val > 0:
			aggro_range *= (1.0 - clampf(stealth_val / 100.0, 0.0, 0.8))

	# Leash check: overworld enemies must stay near their spawn zone
	if has_meta("spawn_pos") and has_meta("leash_radius"):
		var _sp = get_meta("spawn_pos") as Vector2
		var _lr = get_meta("leash_radius") as float
		if _lr > 0 and global_position.distance_to(_sp) > _lr + 200:
			# Too far from spawn — return home
			state = State.IDLE
			velocity = Vector2.ZERO
			_chase_timer = 0.0
			global_position = global_position.move_toward(_sp, speed * delta * 2)
			move_and_slide()
			return

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
					_wander_timer = 2.0 + randf() * 4.0
					if randf() < 0.6:  # 60% chance to pick a direction, 40% stand still
						_wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
					else:
						_wander_dir = Vector2.ZERO
				velocity = _wander_dir * speed * 0.3
				if _wander_dir.x < 0:
					$Sprite2D.flip_h = true
				elif _wander_dir.x > 0:
					$Sprite2D.flip_h = false
			else:
				velocity = Vector2.ZERO
			# Aggro check (skip if passive)
			if not is_passive:
				_los_check_timer -= delta
				if _los_check_timer <= 0:
					_los_check_timer = 0.3 + randf() * 0.2
					if dist < aggro_range and _has_line_of_sight():
						state = State.CHASE
						_last_pos = global_position
		State.CHASE:
			_chase_timer += delta
			if _chase_timer > CHASE_TIMEOUT:
				state = State.IDLE
				velocity = Vector2.ZERO
				_chase_timer = 0.0
			else:
				_do_chase(dir, dist, delta)
		State.ATTACK:
			_do_attack(dir)
		State.COOLDOWN:
			cooldown_timer -= delta
			var pref = definition.preferred_distance if definition else 0.0
			if pref > 0:
				# Ranged enemy — maintain distance during cooldown
				if dist < pref * 0.5:
					velocity = -dir * speed * 0.5  # back off
				elif dist > pref * 1.5:
					velocity = dir * speed * 0.3  # drift closer
				else:
					# Strafe gently at range
					var cd_strafe = dir.rotated(PI / 2) * (1.0 if fmod(Time.get_ticks_msec() / 800.0, 2.0) < 1.0 else -1.0)
					velocity = cd_strafe * speed * 0.3
			else:
				# Melee enemy — keep advancing
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
				state = State.ATTACK  # backstab

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

func _do_chase(dir: Vector2, dist: float, delta: float) -> void:
	# Lose aggro if player is very far away
	if dist > 200.0:
		velocity = Vector2.ZERO
		state = State.IDLE
		_chase_timer = 0.0
		return

	var pref_dist = definition.preferred_distance if definition else 0.0
	var move_dir = dir

	# Use A* pathfinding if available (dungeon) and not a ghost
	var use_astar = _nav and _nav.is_ready() and not (definition and definition.ignores_terrain)
	if use_astar and dist > 16.0:
		_path_timer -= delta
		if _path_timer <= 0:
			_path_timer = 0.25 + randf() * 0.15  # re-path every ~0.3s, staggered
			_cached_next_pos = _nav.get_next_position(global_position, player.global_position)
		if _cached_next_pos != Vector2.ZERO:
			var to_next = _cached_next_pos - global_position
			if to_next.length_squared() > 1.0:
				move_dir = to_next.normalized()
	else:
		# Fallback: steering-based wall avoidance (overworld or ghosts)
		if not (definition and definition.ignores_terrain):
			move_dir = _steer_around_walls(dir)

	if pref_dist > 0:
		# Ranged enemy — tries to maintain preferred distance
		if dist < pref_dist * 0.5:
			var strafe = dir.rotated(PI / 2) * (1.0 if randf() > 0.5 else -1.0)
			velocity = (-dir * 0.7 + strafe * 0.3).normalized() * speed * 0.8
		elif dist < pref_dist * 1.3:
			var strafe_dir = dir.rotated(PI / 2) * (1.0 if fmod(Time.get_ticks_msec() / 1000.0, 2.0) < 1.0 else -1.0)
			velocity = strafe_dir * speed * 0.5
		else:
			var approach_mult = clampf((dist - pref_dist) / pref_dist, 0.3, 1.0)
			velocity = move_dir * speed * approach_mult
	else:
		# Melee/no-preference enemy — chase with pathfinding
		velocity = move_dir * speed * 1.2

	attack_timer -= delta
	if attack_timer <= 0 and dist < 120:
		var atk = _get_active_attack_type()
		# All enemies shoot bullets as baseline — special types add extra behavior
		match atk:
			EnemyDefinition.AttackType.NONE:
				state = State.ATTACK  # still shoots
			EnemyDefinition.AttackType.MELEE:
				if dist < 30:
					# Lunge + shoot
					_shoot_single(dir)
					charge_dir = dir
					charge_timer = 0.15
					attack_timer = shoot_interval
					state = State.CHARGING
				else:
					state = State.ATTACK  # shoot from range
			EnemyDefinition.AttackType.CHARGE:
				if dist < 60:
					_shoot_single(dir)
					_start_charge(dir)
				else:
					state = State.ATTACK
			EnemyDefinition.AttackType.DASH:
				if dist < 80:
					_shoot_single(dir)
					_start_charge(dir)
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
				state = State.ATTACK

func _do_attack(dir: Vector2) -> void:
	velocity = Vector2.ZERO
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
			_shoot_single(dir)
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

	attack_timer = shoot_interval * 0.25  # very aggressive fire rate
	cooldown_timer = 0.1
	state = State.COOLDOWN

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
		var contact_range = 8.0 * scale.x
		if dist > contact_range:
			return

	_contact_cooldown = 0.5  # half second between contact hits

	# Calculate momentum-based damage
	var my_speed = velocity.length()
	var player_speed = player.velocity.length()
	var relative_speed = (velocity - player.velocity).length()

	# Base contact damage from definition
	var base_dmg = 1
	if definition:
		base_dmg = definition.attack_damage if definition.attack_damage > 0 else 1

	# Momentum bonus: faster collisions hurt more
	var momentum_mult = clampf(relative_speed / 40.0, 0.5, 3.0)
	var weight_mult = _weight

	# Enemy deals damage to player
	var player_dmg = int(ceil(base_dmg * momentum_mult * weight_mult))
	if player.has_method("take_damage"):
		player.take_damage(maxi(player_dmg, 1))

	# Player deals damage back to enemy (lighter enemies take more knockback damage)
	var enemy_dmg = int(ceil(momentum_mult / weight_mult))
	if enemy_dmg > 0:
		take_damage(enemy_dmg)

	# Knockback: both get pushed apart
	var push_dir = (global_position - player.global_position).normalized()
	if push_dir == Vector2.ZERO:
		push_dir = Vector2.RIGHT.rotated(randf() * TAU)

	# Enemy gets knocked back (lighter = more knockback)
	var enemy_knockback = push_dir * 60.0 / weight_mult
	velocity = enemy_knockback

	# Push player in opposite direction (heavier enemies push player more)
	if player is CharacterBody2D:
		player.velocity = -push_dir * 40.0 * weight_mult

func _start_charge(dir: Vector2) -> void:
	charge_dir = dir
	charge_timer = definition.charge_duration if definition else 0.3
	attack_timer = shoot_interval
	state = State.CHARGING

func _do_summon() -> void:
	if not definition or not definition.summon_definition:
		return
	var enemy_scene = preload("res://scenes/enemy.tscn")
	var container = get_parent()
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
			var dm = get_tree().get_first_node_in_group("dungeon_manager")
			if dm and dm.room_states.has(gp):
				dm.room_states[gp]["alive"] += 1
				minion.tree_exited.connect(dm._on_enemy_died.bind(gp))

func _do_slam() -> void:
	var bodies = get_tree().get_nodes_in_group("player")
	var radius = definition.slam_radius if definition else 24.0
	for body in bodies:
		if body.global_position.distance_to(global_position) < radius:
			if body.has_method("take_damage"):
				body.take_damage(definition.attack_damage if definition else 1)
	var tween = create_tween()
	tween.tween_property($Sprite2D, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property($Sprite2D, "scale", Vector2(1, 1), 0.2)

func _do_teleport() -> void:
	if not is_instance_valid(player):
		return
	var angle = randf() * TAU
	var dist = randf_range(20, 40)
	global_position = player.global_position + Vector2(cos(angle), sin(angle)) * dist
	$Sprite2D.modulate.a = 0.3
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate:a", 1.0, 0.3)

func _try_heal_nearby() -> void:
	var heal_amt = definition.heal_amount if definition else 2
	var heal_rng = definition.heal_range if definition else 48.0
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
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	var count = _get_active_bullet_count()
	if count <= 0:
		return
	if count < 4:
		count = 6
	var bspeed = definition.bullet_speed if definition else 60.0
	for i in range(count):
		var angle = dir.angle() + _spiral_angle + (TAU / count) * i
		_spawn_bullet(bullets_container, Vector2.from_angle(angle), bspeed)
	_spiral_angle += 0.4  # offset each volley for spiral effect

func _enter_stealth() -> void:
	_stealth_timer = definition.stealth_duration if definition else 2.0
	$Sprite2D.modulate.a = 0.15
	state = State.STEALTHED

func _start_beam(dir: Vector2) -> void:
	_beam_timer = definition.beam_duration if definition else 1.0
	_beam_angle = dir.angle()

func _shoot_single(dir: Vector2) -> void:
	var bullets_container = get_tree().get_first_node_in_group("bullets")
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
	var bullets_container = get_tree().get_first_node_in_group("bullets")
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

func _spawn_bullet(container: Node, dir: Vector2, spd: float) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = dir
	bullet.is_player_bullet = false
	bullet.speed = spd
	container.add_child(bullet)

func _spawn_bullet_at(container: Node, pos: Vector2, dir: Vector2, spd: float) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.global_position = pos
	bullet.direction = dir
	bullet.is_player_bullet = false
	bullet.speed = spd
	container.add_child(bullet)

func _spawn_behavior_bullet(container: Node, dir: Vector2, spd: float, bhv: int) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = dir
	bullet.is_player_bullet = false
	bullet.speed = spd
	bullet.behavior = bhv
	bullet._origin_pos = global_position
	bullet._origin_entity = self
	container.add_child(bullet)

## VOLLEY: Fires an arc of bullets upward that rain down — delayed spread
func _shoot_volley(dir: Vector2) -> void:
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 4)
	var bspeed = (definition.bullet_speed if definition else 70.0) * 0.8
	var spread = 0.6
	for i in range(count):
		var t = float(i) / (count - 1) - 0.5
		var angle = t * spread
		var spd = bspeed * randf_range(0.7, 1.3)
		# Stagger fire times for volley feel
		get_tree().create_timer(i * 0.06).timeout.connect(
			func():
				if is_instance_valid(self) and hp > 0:
					var bc = get_tree().get_first_node_in_group("bullets")
					if bc:
						_spawn_bullet(bc, dir.rotated(angle), spd)
		)

## CROSS_SHOT: Fires in 4 cardinal directions (+ pattern) with multiple bullets per arm
func _shoot_cross(dir: Vector2) -> void:
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	var bspeed = definition.bullet_speed if definition else 75.0
	var count_per_arm = maxi(_get_active_bullet_count() / 4, 1)
	for arm in range(4):
		var arm_dir = dir.rotated(arm * PI / 2.0)
		for b in range(count_per_arm):
			var spd = bspeed * (1.0 - b * 0.2)
			_spawn_bullet(bullets_container, arm_dir, maxf(spd, 20.0))

## WAVE_SHOT: Sine-wave spread — bullets fan out then converge in a wave pattern
func _shoot_wave(dir: Vector2) -> void:
	var bullets_container = get_tree().get_first_node_in_group("bullets")
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

## GATLING: Rapid stream of bullets with random jitter — suppressive fire
func _shoot_gatling(dir: Vector2) -> void:
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 5)
	var bspeed = (definition.bullet_speed if definition else 90.0) * 1.2
	for i in range(count):
		get_tree().create_timer(i * 0.04).timeout.connect(
			func():
				if is_instance_valid(self) and hp > 0:
					var bc = get_tree().get_first_node_in_group("bullets")
					if bc:
						var jitter = randf_range(-0.12, 0.12)
						_spawn_bullet(bc, dir.rotated(jitter), bspeed * randf_range(0.85, 1.15))
		)

## MORTAR: Lobs slow bullets in high arc that speed up — artillery style
func _shoot_mortar(dir: Vector2) -> void:
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 3)
	var bspeed = (definition.bullet_speed if definition else 50.0) * 0.5
	for i in range(count):
		var spread = randf_range(-0.3, 0.3)
		var spd = bspeed * randf_range(0.8, 1.5)
		_spawn_bullet(bullets_container, dir.rotated(spread), spd)
	# Also fire a burst at player's position after delay
	get_tree().create_timer(0.5).timeout.connect(
		func():
			if is_instance_valid(self) and is_instance_valid(player) and hp > 0:
				var bc = get_tree().get_first_node_in_group("bullets")
				if bc:
					var to_player = (player.global_position - global_position).normalized()
					for j in range(3):
						var jitter = randf_range(-0.15, 0.15)
						_spawn_bullet(bc, to_player.rotated(jitter), bspeed * 2.5)
	)

## NOVA: Double ring burst — inner ring fast, outer ring slow with offset
func _shoot_nova(dir: Vector2) -> void:
	var bullets_container = get_tree().get_first_node_in_group("bullets")
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
				var bc = get_tree().get_first_node_in_group("bullets")
				if bc:
					var outer = count
					var half_step = TAU / outer / 2.0
					for j in range(outer):
						var angle = base_angle + (TAU / outer) * j + half_step
						_spawn_bullet(bc, Vector2.from_angle(angle), bspeed * 0.6)
	)

## ZIGZAG: Alternating left-right angled shots for a weaving bullet wall
func _shoot_zigzag(dir: Vector2) -> void:
	var bullets_container = get_tree().get_first_node_in_group("bullets")
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
					var bc = get_tree().get_first_node_in_group("bullets")
					if bc:
						_spawn_bullet(bc, bullet_dir, bspeed)
		)

## SHOTGUN_BLAST: Wide random cone burst — devastating at close range
func _shoot_shotgun(dir: Vector2) -> void:
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 5)
	var bspeed = definition.bullet_speed if definition else 80.0
	var cone = 0.6  # wide cone
	for i in range(count):
		var angle = randf_range(-cone / 2.0, cone / 2.0)
		var spd = bspeed * randf_range(0.6, 1.4)
		_spawn_bullet(bullets_container, dir.rotated(angle), spd)

## HELIX: Two intertwined spiraling bullet streams
var _helix_angle: float = 0.0
func _shoot_helix(dir: Vector2) -> void:
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	var bspeed = definition.bullet_speed if definition else 70.0
	# Two streams offset by PI
	for stream in range(2):
		var offset_angle = _helix_angle + stream * PI
		var bullet_dir = dir.rotated(sin(offset_angle) * 0.5)
		var perp = dir.rotated(PI / 2.0)
		var spawn_pos = global_position + perp * cos(offset_angle) * 6.0
		_spawn_bullet_at(bullets_container, spawn_pos, bullet_dir, bspeed)
	_helix_angle += 0.8

## METEOR_SHOWER: Cluster of bullets with wildly varying speeds — chaotic rain
func _shoot_meteor_shower(dir: Vector2) -> void:
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 6)
	var bspeed = definition.bullet_speed if definition else 60.0
	for i in range(count):
		var angle = randf_range(-0.2, 0.2)
		var spd = bspeed * randf_range(0.3, 2.0)
		var delay_time = randf_range(0.0, 0.2)
		get_tree().create_timer(delay_time).timeout.connect(
			func():
				if is_instance_valid(self) and hp > 0:
					var bc = get_tree().get_first_node_in_group("bullets")
					if bc:
						_spawn_bullet(bc, dir.rotated(angle), spd)
		)

## BOOMERANG_SHOT: Wide arc of bullets — outer ones faster, creating a curving pincer
func _shoot_boomerang(dir: Vector2) -> void:
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 5)
	var bspeed = definition.bullet_speed if definition else 75.0
	var arc = 0.9  # very wide
	for i in range(count):
		var t = float(i) / maxf(count - 1, 1) - 0.5  # -0.5 to 0.5
		var angle = t * arc
		# Outer bullets are faster — creates pincer effect
		var speed_mult = 0.6 + abs(t) * 1.6
		_spawn_bullet(bullets_container, dir.rotated(angle), bspeed * speed_mult)

## STRAFE_RUN: Fires a spread while moving perpendicular — hit-and-run style
func _shoot_strafe_run(dir: Vector2) -> void:
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 4)
	var bspeed = (definition.bullet_speed if definition else 80.0) * 1.1
	for i in range(count):
		get_tree().create_timer(i * 0.08).timeout.connect(
			func():
				if is_instance_valid(self) and is_instance_valid(player) and hp > 0:
					var bc = get_tree().get_first_node_in_group("bullets")
					if bc:
						# Re-aim at player each shot — tracks during strafe
						var aim = (player.global_position - global_position).normalized()
						var jitter = randf_range(-0.1, 0.1)
						_spawn_bullet(bc, aim.rotated(jitter), bspeed)
		)

## MINEFIELD: Drops slow-moving bullets in all directions around self — area denial
func _shoot_minefield() -> void:
	var bullets_container = get_tree().get_first_node_in_group("bullets")
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
	var bullets_container = get_tree().get_first_node_in_group("bullets")
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
	var bullets_container = get_tree().get_first_node_in_group("bullets")
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
	var bullets_container = get_tree().get_first_node_in_group("bullets")
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

## SPLITTER: Fires bullets that split into multiple sub-bullets after a delay
func _shoot_splitter(dir: Vector2) -> void:
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 2)
	var bspeed = definition.bullet_speed if definition else 65.0
	for i in range(count):
		var spread = float(i) / maxf(count - 1, 1) - 0.5
		var b = bullet_scene.instantiate()
		b.global_position = global_position
		b.direction = dir.rotated(spread * 0.4)
		b.is_player_bullet = false
		b.speed = bspeed
		b.behavior = b.BulletBehavior.SPLITTING
		b._origin_pos = global_position
		b._split_count = randi_range(3, 6)
		b.lifetime = 4.0
		bullets_container.add_child(b)

## SINE_BARRAGE: Fires sine-wave bullets that oscillate while traveling — hard to dodge
func _shoot_sine_barrage(dir: Vector2) -> void:
	var bullets_container = get_tree().get_first_node_in_group("bullets")
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
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	var count = maxi(_get_active_bullet_count(), 3)
	var bspeed = (definition.bullet_speed if definition else 60.0) * 0.7
	for i in range(count):
		get_tree().create_timer(i * 0.1).timeout.connect(
			func():
				if not is_instance_valid(self) or hp <= 0:
					return
				var bc = get_tree().get_first_node_in_group("bullets")
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
	var target_pos = player.global_position
	# Visual telegraph: flash a warning at the target location
	var marker = Sprite2D.new()
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var dx = x - 8.0
			var dy = y - 8.0
			if dx * dx + dy * dy < 64.0:
				img.set_pixel(x, y, Color(1.0, 0.2, 0.0, 0.5))
	marker.texture = ImageTexture.create_from_image(img)
	marker.global_position = target_pos
	marker.z_index = -1
	get_tree().current_scene.add_child(marker)
	# Blink the marker
	var tween = create_tween()
	tween.tween_property(marker, "modulate:a", 0.2, 0.3)
	tween.tween_property(marker, "modulate:a", 1.0, 0.3)
	tween.tween_property(marker, "modulate:a", 0.2, 0.2)
	tween.tween_property(marker, "modulate:a", 1.0, 0.2)
	# Explode after delay
	get_tree().create_timer(1.0).timeout.connect(
		func():
			if is_instance_valid(marker):
				marker.queue_free()
			# Spawn ring of bullets at the telegraph position
			var bc = get_tree().get_first_node_in_group("bullets")
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
						player.take_damage(dmg)
	)

## ORBIT_LAUNCH: Spawns bullets that orbit around the enemy then launch outward
func _shoot_orbit_launch(dir: Vector2) -> void:
	var bullets_container = get_tree().get_first_node_in_group("bullets")
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

func _has_line_of_sight() -> bool:
	if not is_instance_valid(player):
		return false
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position, 16)  # wall layer only
	query.exclude = [get_rid()]
	var result = space.intersect_ray(query)
	return result.is_empty()  # no wall between us = has LOS

func take_damage(amount: int) -> void:
	# Passive enemies become hostile when hit
	if has_meta("passive_until_hit") and get_meta("passive_until_hit"):
		set_meta("passive_until_hit", false)
	# Getting hit always aggros and resets chase timer
	if state == State.IDLE:
		state = State.CHASE
	_chase_timer = 0.0
	hp -= amount
	_time_since_hit = 0.0
	# Floating damage number
	var scene_root = get_tree().current_scene
	if scene_root and amount > 0:
		FloatingText.spawn_damage(scene_root, global_position, amount, Color(1.0, 1.0, 0.3))
	var orig_color = definition.sprite_color if definition else Color.WHITE
	$Sprite2D.modulate = Color.WHITE * 3
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate", orig_color, 0.1)
	_update_boss_hp_bar()
	if hp <= 0:
		_die()
		return
	_check_phase_transition()

func apply_status(status_name: String, duration: float) -> void:
	# Apply visual tint for status effects
	var color = Color.WHITE
	match status_name:
		"BURNING": color = Color(1.0, 0.5, 0.2)
		"SLOWED": color = Color(0.4, 0.6, 1.0)
		"POISONED": color = Color(0.3, 0.8, 0.2)
	$Sprite2D.modulate = color
	# Slow enemies when slowed
	if status_name == "SLOWED":
		speed *= 0.5
	# Damage over time for burning/poison
	if status_name == "BURNING" or status_name == "POISONED":
		var tick_dmg = maxi(1, _max_hp / 20)
		var ticks = int(duration / 0.5)
		for i in range(ticks):
			get_tree().create_timer(0.5 * (i + 1)).timeout.connect(
				func():
					if is_instance_valid(self) and hp > 0:
						take_damage(tick_dmg)
			)
	# Restore after duration
	get_tree().create_timer(duration).timeout.connect(
		func():
			if is_instance_valid(self):
				$Sprite2D.modulate = definition.sprite_color if definition else Color.WHITE
				if status_name == "SLOWED" and definition:
					speed = definition.move_speed
	)

func take_damage_from_front(amount: int, from_dir: Vector2) -> void:
	# Shield enemies block frontal damage
	if shield_hp > 0:
		var facing = Vector2.LEFT if $Sprite2D.flip_h else Vector2.RIGHT
		if from_dir.dot(facing) > 0.3:  # hitting the shield side
			shield_hp -= amount
			if shield_hp <= 0:
				shield_hp = 0
			# Flash blue for shield hit
			$Sprite2D.modulate = Color.CYAN
			var tween = create_tween()
			tween.tween_property($Sprite2D, "modulate", definition.sprite_color if definition else Color.WHITE, 0.1)
			return
	take_damage(amount)

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

	# Spawn minions on phase change
	if definition.summon_on_phase_change and definition.summon_definition:
		var spawn_count = definition.summon_phase_count
		var bullet_container = get_tree().get_first_node_in_group("bullets")
		var enemy_scene = load("res://scenes/enemy.tscn")
		var container = get_parent()
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
				minion.set_meta("grid_pos", get_meta("grid_pos"))
				minion.tree_exited.connect(func():
					var dm = get_tree().get_first_node_in_group("dungeon_manager")
					if dm:
						dm._on_enemy_died(get_meta("grid_pos"))
				)

	# Increase speed slightly each phase
	speed *= 1.15
	shoot_interval *= 0.85  # attack faster

func _die() -> void:
	state = State.DEAD

	# Explode on death
	if definition and definition.explodes_on_death:
		_explode_on_death()

	# Split on death (blob-like)
	if definition and definition.attack_type == EnemyDefinition.AttackType.SPLIT and definition.split_definition:
		_split_on_death()

	# Grant XP to player
	if definition and definition.xp_value > 0 and is_instance_valid(player):
		if player.has_method("gain_xp"):
			player.gain_xp(definition.xp_value)

	# Notify quest system
	if definition:
		var qm = get_node_or_null("/root/QuestManager")
		if qm:
			qm.on_enemy_killed(definition.enemy_name)

	# Floating text for XP/gold
	var xp_val = definition.xp_value if definition else 0
	var gold_val = definition.score_value if definition else 5
	var scene_root = get_tree().current_scene
	if scene_root:
		if xp_val > 0:
			FloatingText.spawn(scene_root, global_position + Vector2(0, -8), "+%d XP" % xp_val, Color(0.5, 1.0, 0.5))
		if gold_val > 0:
			FloatingText.spawn(scene_root, global_position + Vector2(0, 4), "+%d Gold" % gold_val, Color(1.0, 0.85, 0.2))

	# Gold drops as a gold pickup (not in a bag)
	var gold = definition.score_value if definition else 5
	if gold > 0:
		var pickup = pickup_scene.instantiate()
		pickup.gold_amount = gold
		pickup.global_position = global_position + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		get_tree().current_scene.add_child(pickup)

	# Items drop in a loot bag (only if items rolled)
	var bag_items: Array[EquipmentItem] = []
	if drop_table:
		var drop_chance = 0.15
		if definition and definition.size_class == 1:
			drop_chance = 0.40
		elif definition and definition.size_class >= 2:
			drop_chance = 0.70
		if randf() < drop_chance:
			var roll_count = 1
			if definition and definition.xp_value > 20:
				roll_count = 2
			if definition and definition.size_class > 0:
				roll_count = 3
			for i in range(roll_count):
				var dropped = drop_table.roll()
				if dropped:
					bag_items.append(dropped.duplicate())

	if not bag_items.is_empty():
		var bag = LootBag.new()
		bag.items = bag_items
		bag.global_position = global_position + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		get_tree().current_scene.add_child(bag)
	queue_free()

func _explode_on_death() -> void:
	var radius = definition.explode_radius if definition else 20.0
	var bodies = get_tree().get_nodes_in_group("player")
	for body in bodies:
		if body.global_position.distance_to(global_position) < radius:
			if body.has_method("take_damage"):
				body.take_damage(definition.attack_damage if definition else 2)

func _split_on_death() -> void:
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
			var dm = get_tree().get_first_node_in_group("dungeon_manager")
			if dm and dm.room_states.has(gp):
				dm.room_states[gp]["alive"] += 1
				minion.tree_exited.connect(dm._on_enemy_died.bind(gp))
