extends Area2D
class_name TutorialBarrel

## Self-contained barrel for the tutorial dungeon's stone-toss room.
## Throw a stone at it; it explodes; nearby enemies die. No dungeon_trap
## infrastructure required — keeps the tutorial scene free of dependencies.

const BARREL_TEX := preload("res://assets/sprites/lofi_dungeon_features.png")
const FUSE_TIME := 0.45
const EXPLOSION_RADIUS := 32.0  # 4 tiles at 8 px
const EXPLOSION_DAMAGE := 100   # over-kills tutorial dummies

var _fuse_active: bool = false
var _fuse_timer: float = 0.0
var _exploded: bool = false
var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 32          # trap layer
	collision_mask = 4            # player bullets
	monitoring = true
	monitorable = true

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 8)
	shape.shape = rect
	add_child(shape)

	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var atlas := AtlasTexture.new()
	atlas.atlas = BARREL_TEX
	# (6, 8) on lofi_dungeon_features (12x9 grid, 8px tiles) = explosive barrel
	atlas.region = Rect2(6 * 8, 8 * 8, 8, 8)
	_sprite.texture = atlas
	_sprite.z_index = 4
	add_child(_sprite)

	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if not _fuse_active or _exploded:
		return
	_fuse_timer -= delta
	# Blink red as the fuse burns
	_sprite.modulate = Color(1.0, 0.4, 0.4) if (int(_fuse_timer * 10) % 2 == 0) else Color.WHITE
	if _fuse_timer <= 0:
		_explode()


func _on_area_entered(area: Area2D) -> void:
	if _fuse_active or _exploded:
		return
	# Player bullets sit on layer 4; the stone toss bullet is one of those.
	if area.collision_layer & 4:
		_light_fuse()


func _light_fuse() -> void:
	_fuse_active = true
	_fuse_timer = FUSE_TIME
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("fuse", -4.0, 0.1)


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	_fuse_active = false

	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		if vfx.has_method("death_burst"):
			vfx.death_burst(global_position, Color(1.0, 0.5, 0.1), 0)
		if vfx.has_method("shockwave"):
			vfx.shockwave(global_position, EXPLOSION_RADIUS, Color(1.0, 0.3, 0.0, 0.7))
		if vfx.has_method("shake"):
			vfx.shake(3.0, 0.15)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("boom_b", 0.0, 0.1)

	# Hit every enemy body in the radius
	var space := get_world_2d().direct_space_state
	if space:
		var query := PhysicsShapeQueryParameters2D.new()
		var shape := CircleShape2D.new()
		shape.radius = EXPLOSION_RADIUS
		query.shape = shape
		query.transform = Transform2D(0.0, global_position)
		query.collision_mask = 2  # enemies
		query.collide_with_bodies = true
		query.collide_with_areas = false
		for hit in space.intersect_shape(query, 32):
			var body = hit.get("collider")
			if body and is_instance_valid(body) and body.has_method("take_damage"):
				body.take_damage(EXPLOSION_DAMAGE, false, CombatTypes.DamageType.TRUE)

	queue_free()
