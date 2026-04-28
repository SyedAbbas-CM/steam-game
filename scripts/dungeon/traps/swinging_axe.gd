extends Node2D

## Corridor sawblade hazard — spins with speed-up/slow-down cycle.
## Slow phase: bump damage with cooldown.
## Fast phase: damage per second while in range.
## Limited damage to enemies to prevent abuse.

var floor_number: int = 1
var corridor_direction: String = "east"
var _active: bool = true
var _time: float = 0.0
var _hit_cooldowns: Dictionary = {}  # node_id -> cooldown remaining
var _enemy_damage_dealt: Dictionary = {}  # node_id -> total damage dealt
var _fast_damage_timers: Dictionary = {}  # node_id -> accumulated time

const BASE_SPEED = 0.4
const MAX_SPEED = 2.0
const SPEED_CYCLE = 6.0
const FAST_THRESHOLD = 0.6
const SLOW_HIT_COOLDOWN = 1.5
const FAST_DAMAGE_INTERVAL = 0.25  # damage every 0.25s when fast
const BLADE_RADIUS = 8.0
const BLADE_WIDTH = 2.0
const DAMAGE_RANGE_SQ = 144.0  # 12px squared
const MAX_ENEMY_DAMAGE = 40
const ENEMY_DAMAGE_MULT = 2

var _speed_t: float = 0.0

func _ready() -> void:
	_time = randf() * SPEED_CYCLE
	set_physics_process(true)

func get_damage() -> int:
	return 1 + floor_number

func set_active(active: bool) -> void:
	_active = active
	modulate.a = 1.0 if active else 0.3
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not _active:
		return

	_time += delta
	_speed_t = (sin(_time * TAU / SPEED_CYCLE) + 1.0) * 0.5
	var current_speed = lerpf(BASE_SPEED, MAX_SPEED, _speed_t)
	rotation += current_speed * TAU * delta

	# Tick cooldowns
	var to_erase: Array = []
	for nid in _hit_cooldowns:
		_hit_cooldowns[nid] -= delta
		if _hit_cooldowns[nid] <= 0:
			to_erase.append(nid)
	for nid in to_erase:
		_hit_cooldowns.erase(nid)

	# Direct proximity check every frame for player + enemies
	var is_fast = _speed_t >= FAST_THRESHOLD
	var targets: Array[Node2D] = []

	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		targets.append(player)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy):
			targets.append(enemy)

	for target in targets:
		if global_position.distance_squared_to(target.global_position) > DAMAGE_RANGE_SQ:
			# Out of range — clear fast timer
			_fast_damage_timers.erase(target.get_instance_id())
			continue

		var nid = target.get_instance_id()
		if is_fast:
			# Fast phase: damage per interval
			_fast_damage_timers[nid] = _fast_damage_timers.get(nid, 0.0) + delta
			if _fast_damage_timers[nid] >= FAST_DAMAGE_INTERVAL:
				_fast_damage_timers[nid] -= FAST_DAMAGE_INTERVAL
				_deal_damage(target)
		else:
			# Slow phase: bump damage with cooldown
			_fast_damage_timers.erase(nid)
			if not _hit_cooldowns.has(nid):
				_hit_cooldowns[nid] = SLOW_HIT_COOLDOWN
				_deal_damage(target)

	queue_redraw()

func _deal_damage(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	var nid = target.get_instance_id()

	var dmg = get_damage()
	# Enemy damage cap + 2x multiplier
	if target.is_in_group("enemy"):
		dmg *= ENEMY_DAMAGE_MULT
		var dealt = _enemy_damage_dealt.get(nid, 0)
		if dealt >= MAX_ENEMY_DAMAGE:
			return
		_enemy_damage_dealt[nid] = dealt + dmg
	if target.has_method("take_damage"):
		var from_player = not target.is_in_group("enemy")
		if target.is_in_group("enemy"):
			target.take_damage(dmg, false, CombatTypes.DamageType.TRUE)
		else:
			target.take_damage(dmg, Vector2.INF, false, false, CombatTypes.DamageType.TRUE)

	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("hit_a", -4.0, 0.1)

	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.hit_spark(target.global_position, Color(0.8, 0.2, 0.2))

func _draw() -> void:
	if not _active:
		draw_circle(Vector2.ZERO, 3.0, Color(0.5, 0.5, 0.5, 0.3))
		return

	var blade_color = Color(0.7, 0.7, 0.75).lerp(Color(1.0, 0.5, 0.2), _speed_t * 0.5)
	draw_circle(Vector2.ZERO, 2.5, Color(0.5, 0.5, 0.55))

	for i in range(4):
		var angle = i * PI / 2.0
		var dir = Vector2.from_angle(angle)
		var tip = dir * BLADE_RADIUS
		var perp = dir.orthogonal() * BLADE_WIDTH
		var pts = PackedVector2Array([
			dir * 3.0 + perp,
			tip + perp * 0.5,
			tip - perp * 0.5,
			dir * 3.0 - perp,
		])
		draw_colored_polygon(pts, blade_color)
		draw_line(tip + perp * 0.5, tip - perp * 0.5, Color(0.9, 0.9, 0.95), 0.5)
