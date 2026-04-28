extends "res://scripts/dungeon/traps/dungeon_trap.gd"

## Periodic fire burst from wall edge. Fires every 3s, damages in a 3-tile line.
## Distinct orange/red fire visual with drawn flame indicator when idle.

var fire_direction: Vector2 = Vector2.DOWN
var _fire_timer: float = 0.0
var _burst_timer: float = 0.0
var _is_bursting: bool = false
var _particles: CPUParticles2D

const FIRE_INTERVAL = 3.0
const BURST_DURATION = 0.8
const DAMAGE_INTERVAL = 0.1
const BURST_RANGE = 32.0  # 4 tiles
const ENEMY_DAMAGE_MULT = 2
const SFX_RANGE_SQ = 2500.0  # only play SFX within ~50px of player
var _damage_tick: float = 0.0
var _idle_flicker: float = 0.0

func _ready() -> void:
	super._ready()
	_fire_timer = randf() * FIRE_INTERVAL

func get_damage() -> int:
	return 2

func _physics_process(delta: float) -> void:
	if not _active or not is_inside_tree():
		return

	_idle_flicker += delta

	if _is_bursting:
		_burst_timer += delta
		_damage_tick += delta

		if _damage_tick >= DAMAGE_INTERVAL:
			_damage_tick -= DAMAGE_INTERVAL
			var damage = get_damage()
			var player = _find_player()
			if player:
				_try_flame_hit(player, damage)
			for enemy in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(enemy):
					_try_flame_hit(enemy, damage)

		if _burst_timer >= BURST_DURATION:
			_is_bursting = false
			_burst_timer = 0.0
			_damage_tick = 0.0
			if _particles:
				_particles.emitting = false
	else:
		_fire_timer += delta
		if _fire_timer >= FIRE_INTERVAL:
			_fire_timer -= FIRE_INTERVAL
			_start_burst()

	queue_redraw()

func _try_flame_hit(target: Node2D, damage: int) -> void:
	var to_target = target.global_position - global_position
	var dot = to_target.dot(fire_direction)
	var perp_dist = abs(to_target.cross(fire_direction))
	if dot > 0 and dot <= BURST_RANGE and perp_dist <= 12.0:
		var actual_damage = damage * ENEMY_DAMAGE_MULT if target.is_in_group("enemy") else damage
		if target.has_method("take_damage"):
			var is_enemy = target.is_in_group("enemy")
			if is_enemy:
				target.take_damage(actual_damage, false, CombatTypes.DamageType.TRUE)
			else:
				target.take_damage(actual_damage, Vector2.INF, false, false, CombatTypes.DamageType.TRUE)
		if target.is_in_group("player") and "status_effects" in target and target.status_effects:
			target.status_effects.apply_status("BURNING", 2.0)

func _start_burst() -> void:
	_is_bursting = true
	# Only play SFX if player is nearby
	var player = _find_player()
	if player and global_position.distance_squared_to(player.global_position) <= SFX_RANGE_SQ:
		_play_sfx("boom_b", -6.0, 0.15)

	if not _particles:
		_particles = CPUParticles2D.new()
		_particles.amount = 25
		_particles.lifetime = 0.3
		_particles.one_shot = false
		_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
		_particles.direction = fire_direction
		_particles.spread = 20.0
		_particles.gravity = Vector2.ZERO
		_particles.initial_velocity_min = 40.0
		_particles.initial_velocity_max = 80.0
		_particles.scale_amount_min = 0.8
		_particles.scale_amount_max = 2.0
		# Yellow to red gradient
		var gradient = Gradient.new()
		gradient.set_color(0, Color(1.0, 1.0, 0.3, 1.0))  # bright yellow
		gradient.set_color(1, Color(1.0, 0.2, 0.0, 0.0))  # red, fading out
		_particles.color_ramp = gradient
		_particles.color = Color(1.0, 0.6, 0.1, 0.9)
		add_child(_particles)

	_particles.emitting = true

func _draw() -> void:
	if not _active:
		return
	# Draw small flickering flame indicator when idle
	var flicker = sin(_idle_flicker * 8.0) * 0.3 + 0.7
	var flame_color = Color(1.0, 0.4, 0.0, flicker)
	# Small flame triangle pointing in fire_direction
	var perp = fire_direction.orthogonal()
	var base1 = perp * 2.0
	var base2 = -perp * 2.0
	var tip = fire_direction * 4.0
	draw_colored_polygon(PackedVector2Array([base1, base2, tip]), flame_color)
	# Inner bright core
	var inner_tip = fire_direction * 2.5
	draw_colored_polygon(PackedVector2Array([perp * 1.0, -perp * 1.0, inner_tip]), Color(1.0, 0.8, 0.2, flicker))

	# During burst, draw the fire line
	if _is_bursting:
		var line_end = fire_direction * BURST_RANGE
		draw_line(Vector2.ZERO, line_end, Color(1.0, 0.4, 0.0, 0.4), 3.0)
