extends Area2D

const TILE_SIZE := 8
const FIRE_ATLAS := Vector2i(9, 6)
const FIRE_FLICKER_ATLAS := Vector2i(10, 6)

var floor_layer: TileMapLayer = null
var wall_layer: TileMapLayer = null
var liquid_layer: TileMapLayer = null
var origin_tile: Vector2i = Vector2i.ZERO
var duration: float = 3.0
var damage: int = 2
var spread_generations: int = 1
var can_damage_player: bool = true
var can_damage_enemies: bool = true

var _elapsed: float = 0.0
var _damage_timer: float = 0.0
var _spread_done: bool = false
var _anim_timer: float = 0.0
var _sprite: Sprite2D
var _particles: CPUParticles2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	add_to_group("fire_patch")
	_create_visuals()
	set_physics_process(true)

func _create_visuals() -> void:
	_sprite = Sprite2D.new()
	var tex: Texture2D = load("res://assets/sprites/lofi_obj.png")
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(FIRE_ATLAS.x * TILE_SIZE, FIRE_ATLAS.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	_sprite.texture = atlas
	_sprite.centered = true
	_sprite.scale = Vector2(0.85, 0.85)
	add_child(_sprite)

	_particles = CPUParticles2D.new()
	_particles.emitting = true
	_particles.amount = 8
	_particles.lifetime = 0.45
	_particles.one_shot = false
	_particles.direction = Vector2.UP
	_particles.spread = 24.0
	_particles.gravity = Vector2(0, -6)
	_particles.initial_velocity_min = 2.0
	_particles.initial_velocity_max = 8.0
	_particles.scale_amount_min = 0.35
	_particles.scale_amount_max = 0.8
	_particles.color = Color(1.0, 0.55, 0.18, 0.8)
	add_child(_particles)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	_damage_timer += delta
	_anim_timer += delta

	if _anim_timer >= 0.12:
		_anim_timer = 0.0
		_toggle_fire_frame()

	if not _spread_done and spread_generations > 0 and _elapsed >= 0.65:
		_spread_done = true
		_spread_once()

	if _damage_timer >= 0.4:
		_damage_timer -= 0.4
		_damage_nearby()

	if _elapsed >= maxf(duration - 0.8, 0.0):
		var fade = clampf((duration - _elapsed) / 0.8, 0.0, 1.0)
		modulate.a = fade

	if _elapsed >= duration:
		queue_free()

func _toggle_fire_frame() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var atlas := _sprite.texture as AtlasTexture
	if atlas == null:
		return
	var current_tile := Vector2i(int(atlas.region.position.x / TILE_SIZE), int(atlas.region.position.y / TILE_SIZE))
	var next_tile := FIRE_FLICKER_ATLAS if current_tile == FIRE_ATLAS else FIRE_ATLAS
	atlas = atlas.duplicate()
	atlas.region = Rect2(next_tile.x * TILE_SIZE, next_tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	_sprite.texture = atlas
	_sprite.scale = Vector2.ONE * randf_range(0.82, 0.96)

func _damage_nearby() -> void:
	var radius := 11.0
	if can_damage_player:
		var player = get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player) and global_position.distance_to(player.global_position) <= radius:
			if player.has_method("take_damage"):
				player.take_damage(damage, Vector2.INF, false, false, CombatTypes.DamageType.TRUE)
			if "status_effects" in player and player.status_effects:
				player.status_effects.apply_status("BURNING", 2.0)
	if can_damage_enemies:
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= radius:
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage, false, CombatTypes.DamageType.TRUE)
				if enemy.has_method("apply_status"):
					enemy.apply_status("BURNING", 2.0)

func _spread_once() -> void:
	if floor_layer == null or wall_layer == null or liquid_layer == null:
		return
	var candidates: Array[Vector2i] = []
	for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var cell: Vector2i = origin_tile + dir
		if floor_layer.get_cell_source_id(cell) < 0:
			continue
		if wall_layer.get_cell_source_id(cell) >= 0:
			continue
		if liquid_layer.get_cell_source_id(cell) >= 0:
			continue
		candidates.append(cell)
	candidates.shuffle()
	var spread_count := mini(2, candidates.size())
	for i in range(spread_count):
		var patch: Area2D = load("res://scripts/dungeon/traps/fire_patch.gd").new()
		patch.floor_layer = floor_layer
		patch.wall_layer = wall_layer
		patch.liquid_layer = liquid_layer
		patch.origin_tile = candidates[i]
		patch.duration = maxf(duration - 0.9, 1.2)
		patch.damage = damage
		patch.spread_generations = spread_generations - 1
		patch.global_position = Vector2(candidates[i].x * TILE_SIZE + 4, candidates[i].y * TILE_SIZE + 4)
		get_parent().add_child(patch)
