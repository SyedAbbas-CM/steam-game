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
var _loy_sprite: Sprite2D  # separate sprite for LoY characters
var _current_phase: int = 1
var _max_hp: int = 0

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

	state = State.IDLE

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

	var to_player = player.global_position - global_position
	var dist = to_player.length()
	var dir = to_player.normalized() if dist > 0 else Vector2.ZERO

	if dir.x < 0:
		$Sprite2D.flip_h = true
	elif dir.x > 0:
		$Sprite2D.flip_h = false

	var aggro_range = 60.0
	if definition:
		aggro_range = definition.aggro_range if definition.aggro_range > 0 else 60.0

	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			# Throttle aggro check (not every frame)
			_los_check_timer -= delta
			if _los_check_timer <= 0:
				_los_check_timer = 0.3 + randf() * 0.2  # stagger checks
				if dist < aggro_range and _has_line_of_sight():
					state = State.CHASE
		State.CHASE:
			_do_chase(dir, dist, delta)
		State.ATTACK:
			_do_attack(dir)
		State.COOLDOWN:
			cooldown_timer -= delta
			if definition and definition.preferred_distance > 0 and dist < definition.preferred_distance * 0.7:
				velocity = -dir * speed * 0.5
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

func _do_chase(dir: Vector2, dist: float, delta: float) -> void:
	# Lose aggro if player is far away
	if dist > 120.0:
		velocity = Vector2.ZERO
		state = State.IDLE
		return

	var pref_dist = definition.preferred_distance if definition else 0.0

	if pref_dist > 0 and dist < pref_dist * 0.8:
		velocity = -dir * speed * 0.6
	elif pref_dist > 0 and dist < pref_dist * 1.2:
		velocity = dir.rotated(PI / 2) * speed * 0.3
	else:
		velocity = dir * speed

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
			_:
				# RANGED, BURST, SUMMON, SLAM, SPIRAL, POISON_SHOT, SHIELD, BEAM, SPLIT
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
			attack_timer = shoot_interval * 0.4
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
			_shoot_spiral()
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

	attack_timer = shoot_interval * 0.4  # aggressive fire rate
	cooldown_timer = 0.15
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

func _shoot_spiral() -> void:
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
		var angle = _spiral_angle + (TAU / count) * i
		_spawn_bullet(bullets_container, Vector2.RIGHT.rotated(angle), bspeed)
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
		var spread = 0.3
		for i in range(count):
			var angle_offset = (float(i) / (count - 1) - 0.5) * spread * 2
			_spawn_bullet(bullets_container, dir.rotated(angle_offset), bspeed)

func _shoot_ring(_dir: Vector2) -> void:
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	var count = _get_active_bullet_count()
	if count <= 0:
		return
	if count < 4:
		count = 8  # ring needs at least 8 for good coverage
	var bspeed = definition.bullet_speed if definition else 70.0
	for i in range(count):
		var angle = (TAU / count) * i
		var ring_dir = Vector2.RIGHT.rotated(angle)
		_spawn_bullet(bullets_container, ring_dir, bspeed)

func _spawn_bullet(container: Node, dir: Vector2, spd: float) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = dir
	bullet.is_player_bullet = false
	bullet.speed = spd
	container.add_child(bullet)

func _has_line_of_sight() -> bool:
	if not is_instance_valid(player):
		return false
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position, 16)  # wall layer only
	query.exclude = [get_rid()]
	var result = space.intersect_ray(query)
	return result.is_empty()  # no wall between us = has LOS

func take_damage(amount: int) -> void:
	# Getting hit always aggros
	if state == State.IDLE:
		state = State.CHASE
	hp -= amount
	var orig_color = definition.sprite_color if definition else Color.WHITE
	$Sprite2D.modulate = Color.WHITE * 3
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate", orig_color, 0.1)
	if hp <= 0:
		_die()
		return
	_check_phase_transition()

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

	if drop_table:
		var dropped_item = drop_table.roll()
		if dropped_item:
			var pickup = pickup_scene.instantiate()
			pickup.item = dropped_item
			pickup.global_position = global_position
			get_tree().current_scene.add_child(pickup)
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
