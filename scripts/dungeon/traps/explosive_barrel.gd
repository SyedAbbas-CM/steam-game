extends "res://scripts/dungeon/traps/dungeon_trap.gd"

## Shootable barrel that detonates with AoE damage, applies BURNING, and chain reacts.
## Also pushable (slow walk / C key) and throwable (normal walk into it).

const BARREL_SPRITE = Vector2i(6, 8)  # source 1
const FUSE_TIME = 0.5
const EXPLOSION_RADIUS_TILES = 3
const CHAIN_DELAY = 0.15

const PUSH_SPEED = 30.0
const THROW_SPEED = 160.0
const PUSH_MAX_TILES = 1
const THROW_MAX_TILES = 6
const CONTACT_COOLDOWN = 0.25

var floor_layer: TileMapLayer  # passed from dungeon_manager for walkability checks

var _fuse_active: bool = false
var _fuse_timer: float = 0.0
var _blink_timer: float = 0.0
var _exploded: bool = false

var _moving: bool = false
var _is_thrown: bool = false
var _move_dir: Vector2 = Vector2.ZERO
var _move_speed: float = 0.0
var _move_traveled: float = 0.0
var _move_max_dist: float = 0.0
var _contact_cooldown: float = 0.0
var _sprite: Sprite2D

func _ready() -> void:
	super._ready()
	collision_layer = 32  # trap layer
	collision_mask = 4 | 1  # player bullets + player body
	monitoring = false
	monitorable = true

func activate() -> void:
	if _active:
		return
	_active = true
	monitoring = true
	set_physics_process(true)
	if not area_entered.is_connected(_on_bullet_hit):
		area_entered.connect(_on_bullet_hit)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_bullet_hit(area: Node2D) -> void:
	if _fuse_active or _exploded:
		return
	if area is Area2D and area.collision_layer & 4:
		_light_fuse()

func _on_body_entered(body: Node2D) -> void:
	if _fuse_active or _exploded or _moving:
		return
	if _contact_cooldown > 0.0:
		return
	if body.is_in_group("player"):
		_try_player_push(body)

func _try_player_push(player: Node2D) -> void:
	var player_vel := Vector2.ZERO
	if "velocity" in player:
		player_vel = player.velocity
	if player_vel.length() < 5.0:
		return
	# Snap to cardinal direction
	var dir: Vector2
	if absf(player_vel.x) > absf(player_vel.y):
		dir = Vector2(signf(player_vel.x), 0.0)
	else:
		dir = Vector2(0.0, signf(player_vel.y))
	if dir == Vector2.ZERO:
		return

	var is_slow: bool = player.has_method("is_sneaking") and player.is_sneaking()
	_is_thrown = not is_slow
	_move_dir = dir
	_move_speed = THROW_SPEED if _is_thrown else PUSH_SPEED
	_move_max_dist = float(THROW_MAX_TILES * TILE_SIZE) if _is_thrown else float(PUSH_MAX_TILES * TILE_SIZE)
	_move_traveled = 0.0
	_contact_cooldown = CONTACT_COOLDOWN
	_start_motion()

func _start_motion() -> void:
	_moving = true
	# Swap the tilemap tile for a sprite child so we can animate position smoothly
	var abs_pos := origin + tile_pos
	deco_layer.erase_cell(abs_pos)
	if not _sprite:
		_sprite = Sprite2D.new()
		var tex: Texture2D = load("res://assets/sprites/lofi_dungeon_features.png")
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(BARREL_SPRITE.x * TILE_SIZE, BARREL_SPRITE.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		_sprite.texture = atlas
		_sprite.centered = true
		add_child(_sprite)
	_sprite.visible = true
	_play_sfx("push", -6.0, 0.1)

func _stop_motion(impact: bool) -> void:
	_moving = false
	if impact and _is_thrown:
		_explode()
		return
	# Snap to nearest tile and repaint on deco_layer
	var world_tile := Vector2i(
		int(floor(global_position.x / TILE_SIZE)),
		int(floor(global_position.y / TILE_SIZE))
	)
	# If destination is not walkable, try to stay at current tile_pos instead
	if not _is_tile_walkable(world_tile):
		world_tile = origin + tile_pos
	tile_pos = world_tile - origin
	deco_layer.set_cell(world_tile, 1, BARREL_SPRITE)
	global_position = Vector2(world_tile.x * TILE_SIZE + 4, world_tile.y * TILE_SIZE + 4)
	if _sprite:
		_sprite.visible = false

func _is_tile_walkable(world_tile: Vector2i) -> bool:
	if floor_layer == null:
		return true
	if floor_layer.get_cell_source_id(world_tile) < 0:
		return false
	# Don't stop inside another deco tile
	if deco_layer.get_cell_source_id(world_tile) != -1:
		return false
	return true

## Chain reaction entry point — called by other barrels exploding nearby
func chain_explode() -> void:
	if _fuse_active or _exploded:
		return
	_fuse_active = true
	_fuse_timer = CHAIN_DELAY
	_blink_timer = 0.0
	set_physics_process(true)

func _light_fuse() -> void:
	if _fuse_active or _exploded:
		return
	_fuse_active = true
	_fuse_timer = FUSE_TIME
	_blink_timer = 0.0
	set_physics_process(true)
	_play_sfx("fuse", -4.0, 0.1)

func _physics_process(delta: float) -> void:
	if _exploded:
		return

	if _contact_cooldown > 0.0:
		_contact_cooldown -= delta

	if _moving:
		_process_motion(delta)

	if _fuse_active:
		_process_fuse(delta)

func _process_motion(delta: float) -> void:
	var step := _move_speed * delta
	var next_pos := global_position + _move_dir * step
	_move_traveled += step

	# Check destination tile walkability
	var next_tile := Vector2i(
		int(floor(next_pos.x / TILE_SIZE)),
		int(floor(next_pos.y / TILE_SIZE))
	)
	var cur_tile := Vector2i(
		int(floor(global_position.x / TILE_SIZE)),
		int(floor(global_position.y / TILE_SIZE))
	)
	if next_tile != cur_tile:
		# Crossing into new tile — check walkable
		if floor_layer != null and floor_layer.get_cell_source_id(next_tile) < 0:
			_stop_motion(true)
			return
		if deco_layer.get_cell_source_id(next_tile) != -1:
			_stop_motion(true)
			return

	# Enemy collision (thrown only): detonate if overlapping any enemy
	if _is_thrown:
		var enemy_hit := _check_enemy_at(next_pos)
		if enemy_hit:
			global_position = next_pos
			_explode()
			return

	global_position = next_pos

	if _move_traveled >= _move_max_dist:
		_stop_motion(false)

func _check_enemy_at(pos: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	if not space:
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	query.shape = shape
	query.transform = Transform2D(0.0, pos)
	query.collision_mask = 2  # enemies
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return space.intersect_shape(query, 1).size() > 0

func _process_fuse(delta: float) -> void:
	_fuse_timer -= delta
	_blink_timer += delta

	# Red blink effect — toggle sprite visibility if in motion, else tile
	if _blink_timer > 0.08:
		_blink_timer = 0.0
		if _sprite and _sprite.visible:
			_sprite.modulate = Color(1.0, 0.4, 0.4) if _sprite.modulate == Color.WHITE else Color.WHITE
		else:
			var abs_pos := origin + tile_pos
			var current := deco_layer.get_cell_source_id(abs_pos)
			if current >= 0:
				deco_layer.erase_cell(abs_pos)
			else:
				deco_layer.set_cell(abs_pos, 1, BARREL_SPRITE)

	if _fuse_timer <= 0:
		_explode()

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	set_physics_process(false)

	var explosion_radius := EXPLOSION_RADIUS_TILES * TILE_SIZE
	var damage := 10 + floor_number * 3

	# Erase barrel tile (wherever it currently sits)
	var cur_tile := Vector2i(
		int(floor(global_position.x / TILE_SIZE)),
		int(floor(global_position.y / TILE_SIZE))
	)
	deco_layer.erase_cell(cur_tile)
	if _sprite:
		_sprite.visible = false

	# VFX
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.death_burst(global_position, Color(1.0, 0.5, 0.1), 0)
		vfx.shockwave(global_position, float(explosion_radius), Color(1.0, 0.3, 0.0, 0.7))
		vfx.shake(3.0, 0.15)
	_play_sfx("boom_b", 0.0, 0.1)

	# Damage all bodies in radius (player AND enemies)
	for body in _get_bodies_in_radius(explosion_radius):
		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage(damage, Vector2.INF, false, false, CombatTypes.DamageType.TRUE)
			if "status_effects" in body and body.status_effects:
				body.status_effects.apply_effect(StatusEffect.Type.BURNING, 3.0, 1.0)
		elif body.is_in_group("enemy"):
			var enemy_dmg := damage * 2  # 2x to enemies
			if body.has_method("take_damage"):
				body.take_damage(enemy_dmg, false, CombatTypes.DamageType.TRUE)

	# Chain reaction — trigger other explosive barrels in radius
	for trap in get_tree().get_nodes_in_group("trap"):
		if trap == self or not is_instance_valid(trap):
			continue
		if trap.has_method("chain_explode"):
			if global_position.distance_to(trap.global_position) <= explosion_radius:
				trap.chain_explode()

	queue_free()

func _get_bodies_in_radius(radius: float) -> Array:
	var result: Array = []
	var space := get_world_2d().direct_space_state
	if not space:
		return result
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 1 | 2  # player + enemies
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hits := space.intersect_shape(query, 32)
	for hit in hits:
		if hit.has("collider") and is_instance_valid(hit["collider"]):
			var body = hit["collider"]
			if body not in result:
				result.append(body)
	return result
