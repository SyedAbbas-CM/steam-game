extends "res://scripts/dungeon/traps/dungeon_trap.gd"

## Moving trap that travels along painted track tiles. SAW = continuous damage, ELECTRIC = pulse bullets + stun.

enum RailType { SAW, ELECTRIC }

var rail_type: RailType = RailType.SAW
var track_tiles: Array[Vector2i] = []  # ordered world tile positions
var move_speed: float = 30.0  # px/s
var is_circuit: bool = false
var room_grid_positions: Array[Vector2i] = []  # all rooms this track passes through
var start_track_index: int = 0  # where this trap starts on shared track

var _track_index: int = 0
var _direction: int = 1  # 1 = forward, -1 = reverse
var _hit_cooldowns: Dictionary = {}  # node_id -> float
var _sprite: Sprite2D
var _electric_cooldown: float = 0.0
var _electric_anim_timer: float = 0.0  # when > 0, showing fire frame

const HIT_COOLDOWN_SAW = 0.5
const ELECTRIC_FIRE_INTERVAL = 1.5  # fires bullets every 1.5s
const ELECTRIC_BULLET_COUNT = 4

# Sprite atlas coords (source 1, dungeon features)
const SPRITE_SAW = Vector2i(3, 8)
const SPRITE_ELECTRIC = Vector2i(4, 8)
const SPRITE_ELECTRIC_FIRE = Vector2i(5, 8)  # attack animation frame

func _ready() -> void:
	super._ready()
	monitoring = true
	collision_mask = 1  # detect player only — rail traps don't hurt enemies

	# Visible sprite on the trap entity
	_sprite = Sprite2D.new()
	_sprite.texture = preload("res://assets/sprites/lofi_dungeon_features.png")
	_sprite.region_enabled = true
	var atlas = SPRITE_SAW if rail_type == RailType.SAW else SPRITE_ELECTRIC
	_sprite.region_rect = Rect2(atlas.x * 8, atlas.y * 8, 8, 8)
	_sprite.z_index = 2  # render above floor
	add_child(_sprite)

func activate() -> void:
	if _active:
		return
	_active = true
	set_physics_process(true)
	_track_index = start_track_index
	if track_tiles.size() > 0:
		if _track_index >= track_tiles.size():
			_track_index = 0
		position = Vector2(track_tiles[_track_index].x * TILE_SIZE + 4, track_tiles[_track_index].y * TILE_SIZE + 4)

func get_damage() -> int:
	if rail_type == RailType.SAW:
		return 5 + floor_number * 3  # heavy TRUE damage
	else:
		return 6 + floor_number * 3

func _physics_process(delta: float) -> void:
	if not _active or track_tiles.size() < 2:
		return

	# Move toward next track tile
	var target_tile = track_tiles[_track_index]
	var target_pos = Vector2(target_tile.x * TILE_SIZE + 4, target_tile.y * TILE_SIZE + 4)
	var dist = position.distance_to(target_pos)

	if dist < 1.0:
		# Reached waypoint — advance
		_track_index += _direction
		if is_circuit:
			if _track_index >= track_tiles.size():
				_track_index = 0
			elif _track_index < 0:
				_track_index = track_tiles.size() - 1
		else:
			if _track_index >= track_tiles.size():
				_direction = -1
				_track_index = track_tiles.size() - 2
			elif _track_index < 0:
				_direction = 1
				_track_index = 1
	else:
		var dir = (target_pos - position).normalized()
		position += dir * move_speed * delta

	# Rotate saw sprite for visual effect
	if rail_type == RailType.SAW and _sprite:
		_sprite.rotation += delta * 10.0

	# Electric attack animation timer
	if _electric_anim_timer > 0 and _sprite:
		_electric_anim_timer -= delta
		if _electric_anim_timer <= 0:
			# Restore normal electric sprite
			_sprite.region_rect = Rect2(SPRITE_ELECTRIC.x * 8, SPRITE_ELECTRIC.y * 8, 8, 8)

	# SAW: contact damage with cooldown
	if rail_type == RailType.SAW:
		# Tick down hit cooldowns
		var expired: Array = []
		for nid in _hit_cooldowns:
			_hit_cooldowns[nid] -= delta
			if _hit_cooldowns[nid] <= 0:
				expired.append(nid)
		for nid in expired:
			_hit_cooldowns.erase(nid)

		var dmg = get_damage()
		var vfx = get_node_or_null("/root/VFXManager")
		for body in get_overlapping_bodies():
			if not body.is_in_group("player"):
				continue
			var nid = body.get_instance_id()
			if _hit_cooldowns.has(nid):
				continue
			_hit_cooldowns[nid] = HIT_COOLDOWN_SAW
			if body.has_method("take_damage"):
				body.take_damage(dmg, Vector2.INF, false, false, CombatTypes.DamageType.TRUE)
			if vfx:
				vfx.hit_spark(position, Color(0.9, 0.5, 0.2))
			_play_sfx("impact_a", -6.0, 0.15)

	# ELECTRIC: periodic bullet burst
	elif rail_type == RailType.ELECTRIC:
		_electric_cooldown -= delta
		if _electric_cooldown <= 0:
			_electric_cooldown = ELECTRIC_FIRE_INTERVAL
			_fire_electric_pulse()

func _fire_electric_pulse() -> void:
	_play_sfx("zap", -4.0, 0.15)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.hit_spark(position, Color(0.3, 0.6, 1.0))

	# Switch to attack animation frame
	if _sprite:
		_sprite.region_rect = Rect2(SPRITE_ELECTRIC_FIRE.x * 8, SPRITE_ELECTRIC_FIRE.y * 8, 8, 8)
		_electric_anim_timer = 0.3

	# Fire bullets in cardinal directions — player only, no enemy damage
	var dmg = get_damage()
	var dirs = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	if not is_inside_tree():
		return
	var bullet_scene = preload("res://scenes/bullet.tscn")
	for dir in dirs:
		var b = bullet_scene.instantiate()
		b.global_position = position
		b.direction = dir
		b.speed = 60.0
		b.damage = dmg
		b.lifetime = 2.0
		b.is_player_bullet = false
		b.hits_all = false  # only hits player, not enemies
		b.combat_damage_type = CombatTypes.DamageType.TRUE
		# Stun player on hit (paralysis)
		b.set_meta("apply_stunned_player", 1.0)
		get_tree().current_scene.add_child(b)
