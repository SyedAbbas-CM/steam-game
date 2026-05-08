extends Node2D

## Wall-mounted spear trap — thrusts out periodically with a brief warning flash.
## Reaction time scales from 1.0s (floor 1) down to 0.25s (floor 8+).
## Spear extends along corridor_direction perpendicular, jutting from wall side.

var floor_number: int = 1
var corridor_direction: String = "east"
var thrust_direction: Vector2 = Vector2.ZERO
var sync_offset: float = 0.0
var _active: bool = true
var _time: float = 0.0
var _state: int = 0  # 0 = idle, 1 = warning, 2 = thrust_out, 3 = retracting
var _state_timer: float = 0.0
var _hit_targets: Dictionary = {}  # instance_id -> true (one hit per thrust)

const IDLE_TIME_MIN = 1.5
const IDLE_TIME_MAX = 3.0
const THRUST_DURATION = 0.4
const RETRACT_DURATION = 0.3
const SPEAR_LENGTH = 14.0
const SPEAR_WIDTH = 1.5
const DAMAGE_RANGE_SQ = 196.0  # 14px squared
const ENEMY_DAMAGE_MULT = 2
const MAX_ENEMY_DAMAGE = 30
const ACTIVE_RANGE_SQ = 36864.0  # 192px; sleep when far from player

var _thrust_progress: float = 0.0  # 0 = retracted, 1 = fully extended
var _warning_time: float = 1.0
var _idle_duration: float = 2.0
var _thrust_dir: Vector2 = Vector2.RIGHT  # perpendicular to corridor
var _enemy_damage_dealt: Dictionary = {}
var _redraw_timer: float = 0.0
const REDRAW_INTERVAL = 0.06

func _ready() -> void:
	# Corridor spear lanes should be readable and learnable, so use deterministic timing.
	_time = 0.0
	_idle_duration = lerpf(IDLE_TIME_MIN, IDLE_TIME_MAX, 0.35)
	_state_timer = maxf(sync_offset, 0.0)

	# Warning/reaction time scales with floor: 1.0s at floor 1, down to 0.25s at floor 8+
	_warning_time = maxf(0.25, 1.0 - (floor_number - 1) * 0.107)

	# Prefer the generator-provided wall-side direction so traps always thrust into the dungeon.
	if thrust_direction != Vector2.ZERO:
		_thrust_dir = thrust_direction.normalized()
	else:
		var side = 1 if randf() > 0.5 else -1
		if corridor_direction == "east":
			_thrust_dir = Vector2(0, side)
		else:
			_thrust_dir = Vector2(side, 0)

	set_physics_process(true)

func get_damage() -> int:
	return 4 + floor_number * 2

func set_active(active: bool) -> void:
	_active = active
	modulate.a = 1.0 if active else 0.3
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not _active:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return
	if global_position.distance_squared_to(player.global_position) > ACTIVE_RANGE_SQ:
		return

	_state_timer -= delta
	_redraw_timer -= delta

	match _state:
		0:  # Idle
			_thrust_progress = 0.0
			if _state_timer <= 0:
				_state = 1
				_state_timer = _warning_time
		1:  # Warning flash
			_thrust_progress = 0.0
			if _state_timer <= 0:
				_state = 2
				_state_timer = THRUST_DURATION
				_hit_targets.clear()
		2:  # Thrust out
			_thrust_progress = 1.0 - (_state_timer / THRUST_DURATION)
			_thrust_progress = clampf(_thrust_progress, 0.0, 1.0)
			_check_hits()
			if _state_timer <= 0:
				_state = 3
				_state_timer = RETRACT_DURATION
		3:  # Retracting
			_thrust_progress = _state_timer / RETRACT_DURATION
			_thrust_progress = clampf(_thrust_progress, 0.0, 1.0)
			if _state_timer <= 0:
				_state = 0
				_state_timer = _idle_duration

	if _redraw_timer <= 0.0:
		_redraw_timer = REDRAW_INTERVAL
		queue_redraw()

func _check_hits() -> void:
	var tip_pos = global_position + _thrust_dir * SPEAR_LENGTH * _thrust_progress
	var targets: Array[Node2D] = []
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		targets.append(player)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy):
			targets.append(enemy)

	for target in targets:
		var nid = target.get_instance_id()
		if _hit_targets.has(nid):
			continue
		# Check against spear line (tip and midpoint)
		var mid_pos = global_position + _thrust_dir * SPEAR_LENGTH * _thrust_progress * 0.5
		if target.global_position.distance_squared_to(tip_pos) < DAMAGE_RANGE_SQ or \
		   target.global_position.distance_squared_to(mid_pos) < DAMAGE_RANGE_SQ:
			_hit_targets[nid] = true
			_deal_damage(target)

func _deal_damage(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	var nid = target.get_instance_id()
	var dmg = get_damage()

	if target.is_in_group("enemy"):
		dmg *= ENEMY_DAMAGE_MULT
		var dealt = _enemy_damage_dealt.get(nid, 0)
		if dealt >= MAX_ENEMY_DAMAGE:
			return
		_enemy_damage_dealt[nid] = dealt + dmg

	if target.has_method("take_damage"):
		if target.is_in_group("enemy"):
			target.take_damage(dmg, false, CombatTypes.DamageType.TRUE)
		else:
			target.take_damage(dmg, Vector2.INF, false, false, CombatTypes.DamageType.TRUE)

	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("hit_a", -6.0, 0.05)

	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.hit_spark(target.global_position, Color(0.6, 0.6, 0.7))

func _draw() -> void:
	if not _active:
		draw_circle(Vector2.ZERO, 2.0, Color(0.4, 0.4, 0.4, 0.3))
		return

	# Wall mount base
	draw_circle(Vector2.ZERO, 2.5, Color(0.45, 0.4, 0.35))

	# Warning flash during warning state
	if _state == 1:
		var flash = fmod(_state_timer * 8.0, 1.0)
		if flash > 0.5:
			draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.3, 0.1, 0.6))

	# Spear shaft + tip
	if _thrust_progress > 0.01:
		var extent = _thrust_dir * SPEAR_LENGTH * _thrust_progress
		var perp = _thrust_dir.orthogonal() * SPEAR_WIDTH

		# Shaft
		var shaft_color = Color(0.55, 0.5, 0.4)
		draw_colored_polygon(PackedVector2Array([
			perp * 0.6,
			extent - _thrust_dir * 3.0 + perp * 0.6,
			extent - _thrust_dir * 3.0 - perp * 0.6,
			-perp * 0.6,
		]), shaft_color)

		# Spearhead (triangle tip)
		var head_color = Color(0.75, 0.75, 0.8)
		var tip = extent
		var head_base = extent - _thrust_dir * 3.0
		draw_colored_polygon(PackedVector2Array([
			head_base + perp * 1.2,
			tip,
			head_base - perp * 1.2,
		]), head_color)
