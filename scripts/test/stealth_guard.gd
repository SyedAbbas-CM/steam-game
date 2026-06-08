extends CharacterBody2D

## Standalone patrolling guard for the stealth test arena.
## Mimics the parts of enemy.gd that player stealth code calls:
##   - state / State.DEAD, definition (null), hp, shield_hp, _max_hp
##   - take_damage(), is_back_exposed(), get_awareness(), _on_noise_heard()
## Adds a visible vision cone drawn in _draw().

enum State { PATROL, INVESTIGATE, ALERT, DEAD }

const VISION_RANGE := 140.0
const VISION_HALF_ANGLE := deg_to_rad(45.0)  # 90° cone total
const PATROL_SPEED := 50.0
const ALERT_SPEED := 110.0
const AWARENESS_GAIN := 1.2  # per second when in front cone, full LoS
const AWARENESS_DECAY := 0.4  # per second when player not visible
const ALERT_THRESHOLD := 0.7
const INVESTIGATE_THRESHOLD := 0.3
const STOP_AT_WAYPOINT := 0.8  # seconds to pause at each waypoint

@export var waypoints: Array[Vector2] = []
@export var max_hp: int = 30
@export var damage_per_shot: int = 6
@export var fire_cooldown: float = 1.0

var state: int = State.PATROL
var _awareness: float = 0.0
var _facing_dir: Vector2 = Vector2.RIGHT
var _hp: int
var _waypoint_index: int = 0
var _stop_timer: float = 0.0
var _fire_timer: float = 0.0
var _last_seen_player_pos: Vector2 = Vector2.ZERO
var _player: Node2D

# fields the player stealth code reads
var definition = null
var hp: int :
	get: return _hp
var shield_hp: int = 0
var _max_hp: int

const BULLET_SCENE := preload("res://scenes/bullet.tscn")

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("stealth_guard")
	collision_layer = 2
	collision_mask = 1 | 16  # walls + player
	_max_hp = max_hp
	_hp = max_hp
	if waypoints.size() == 0:
		waypoints.append(global_position)
	# Find player
	var p = get_tree().get_first_node_in_group("player")
	if p:
		_player = p
	# Build small body sprite
	var body = ColorRect.new()
	body.color = Color(0.7, 0.2, 0.2)
	body.size = Vector2(14, 14)
	body.position = -body.size * 0.5
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	# Collision shape
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	shape.shape = rect
	add_child(shape)
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_fire_timer = maxf(_fire_timer - delta, 0.0)
	_update_vision(delta)
	match state:
		State.PATROL:
			_do_patrol(delta)
		State.INVESTIGATE:
			_do_investigate(delta)
		State.ALERT:
			_do_alert(delta)
	move_and_slide()
	queue_redraw()

func _update_vision(delta: float) -> void:
	if not is_instance_valid(_player):
		_awareness = maxf(_awareness - AWARENESS_DECAY * delta, 0.0)
		return
	var to_player = _player.global_position - global_position
	var dist = to_player.length()
	var visible := false
	if dist <= VISION_RANGE and to_player.length() > 0.1:
		var dir = to_player.normalized()
		var dot_v = _facing_dir.dot(dir)
		# Cone check (front 90°)
		var in_cone = dot_v > cos(VISION_HALF_ANGLE)
		# Side awareness: half range, half gain
		var in_side = (not in_cone) and dot_v > -0.25 and dist < VISION_RANGE * 0.5
		if in_cone or in_side:
			# LoS raycast
			var space = get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.create(global_position, _player.global_position, 16)  # wall layer 5 mask=16
			query.exclude = [self]
			var hit = space.intersect_ray(query)
			if hit.is_empty():
				visible = true
				var gain = AWARENESS_GAIN
				if in_side:
					gain *= 0.4
				# Sneaking player slows detection
				if _player.has_method("get") and _player.get("_sneaking"):
					gain *= 0.3
				_awareness = minf(_awareness + gain * delta, 1.0)
				_last_seen_player_pos = _player.global_position
	if not visible:
		_awareness = maxf(_awareness - AWARENESS_DECAY * delta, 0.0)
	# State transitions
	if _awareness >= ALERT_THRESHOLD:
		state = State.ALERT
	elif _awareness >= INVESTIGATE_THRESHOLD and state == State.PATROL:
		state = State.INVESTIGATE
	elif _awareness < INVESTIGATE_THRESHOLD * 0.5 and state != State.PATROL:
		state = State.PATROL

func _do_patrol(delta: float) -> void:
	if waypoints.size() == 0:
		velocity = Vector2.ZERO
		return
	var target = waypoints[_waypoint_index]
	var to_target = target - global_position
	if to_target.length() < 6.0:
		_stop_timer += delta
		velocity = Vector2.ZERO
		if _stop_timer >= STOP_AT_WAYPOINT:
			_stop_timer = 0.0
			_waypoint_index = (_waypoint_index + 1) % waypoints.size()
	else:
		var dir = to_target.normalized()
		velocity = dir * PATROL_SPEED
		_facing_dir = dir

func _do_investigate(delta: float) -> void:
	var target = _last_seen_player_pos
	var to_target = target - global_position
	if to_target.length() < 8.0:
		velocity = Vector2.ZERO
		# Look around: slowly rotate facing
		var t = Time.get_ticks_msec() / 500.0
		_facing_dir = Vector2(cos(t), sin(t))
	else:
		var dir = to_target.normalized()
		velocity = dir * PATROL_SPEED * 1.3
		_facing_dir = dir

func _do_alert(delta: float) -> void:
	if not is_instance_valid(_player):
		state = State.PATROL
		return
	var to_player = _player.global_position - global_position
	var dist = to_player.length()
	var dir = to_player.normalized() if dist > 0.1 else _facing_dir
	_facing_dir = dir
	if dist > 60.0:
		velocity = dir * ALERT_SPEED
	else:
		velocity = Vector2.ZERO
	if _fire_timer <= 0.0 and dist < VISION_RANGE:
		_fire_at_player()
		_fire_timer = fire_cooldown

func _fire_at_player() -> void:
	if not is_instance_valid(_player) or not BULLET_SCENE:
		return
	var b = BULLET_SCENE.instantiate()
	get_parent().add_child(b)
	b.global_position = global_position + _facing_dir * 10
	# Bullet API: setup(direction, speed, damage, owner_is_player, pierce, lifetime)
	if b.has_method("setup"):
		b.setup(_facing_dir, 220.0, damage_per_shot, false, 0, 2.0)
	else:
		b.set("velocity", _facing_dir * 220.0)
		b.set("damage", damage_per_shot)

# ===== API consumed by player stealth code =====

func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	_hp -= amount
	# Damage immediately raises awareness
	_awareness = minf(_awareness + 0.5, 1.0)
	if _hp <= 0:
		_die()

func _die() -> void:
	state = State.DEAD
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.death_burst(global_position)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("death")
	queue_free()

func is_back_exposed(from_pos: Vector2) -> bool:
	var to_attacker = (from_pos - global_position).normalized()
	return _facing_dir.dot(to_attacker) < -0.3

func get_awareness() -> float:
	return _awareness

func _on_noise_heard(intensity: float) -> void:
	_awareness = minf(_awareness + intensity, 1.0)
	if intensity > 0.3:
		_last_seen_player_pos = _player.global_position if is_instance_valid(_player) else global_position

# ===== Vision cone rendering =====

func _draw() -> void:
	if state == State.DEAD:
		return
	# Cone color from awareness
	var col: Color
	if state == State.ALERT or _awareness >= ALERT_THRESHOLD:
		col = Color(1.0, 0.1, 0.1, 0.30)
	elif _awareness >= INVESTIGATE_THRESHOLD:
		col = Color(1.0, 0.7, 0.1, 0.25)
	else:
		col = Color(0.9, 0.9, 0.9, 0.18)
	# Build cone polygon
	var pts: PackedVector2Array = [Vector2.ZERO]
	var steps := 18
	var start_angle = _facing_dir.angle() - VISION_HALF_ANGLE
	var end_angle = _facing_dir.angle() + VISION_HALF_ANGLE
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var a = lerp(start_angle, end_angle, t)
		pts.append(Vector2(cos(a), sin(a)) * VISION_RANGE)
	var cols: PackedColorArray = []
	for _i in range(pts.size()):
		cols.append(col)
	draw_polygon(pts, cols)
	# Outline
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], Color(col.r, col.g, col.b, 0.5), 1.0)
	if pts.size() > 1:
		draw_line(pts[0], pts[1], Color(col.r, col.g, col.b, 0.5), 1.0)
		draw_line(pts[0], pts[pts.size() - 1], Color(col.r, col.g, col.b, 0.5), 1.0)
	# Awareness indicator above sprite
	if _awareness >= ALERT_THRESHOLD:
		draw_string(ThemeDB.fallback_font, Vector2(-4, -16), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.1, 0.1))
	elif _awareness >= INVESTIGATE_THRESHOLD:
		draw_string(ThemeDB.fallback_font, Vector2(-4, -16), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.8, 0.2))
