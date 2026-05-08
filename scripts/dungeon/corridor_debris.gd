class_name CorridorDebris
extends StaticBody2D

## Attackable debris/rubble blocking a corridor. Looks like a darker, semi-transparent wall.
## Player shoots it to clear the path (25 HP).

var hp: int = 25
var tile_positions: Array[Vector2i] = []
var wall_layer_ref: TileMapLayer
var floor_layer_ref: TileMapLayer
var floor_tile: Vector2i = Vector2i(5, 0)
var _sprite: Sprite2D

signal debris_destroyed

func _ready() -> void:
	# Layer 2 (player bullets hit), Layer 16 (blocks movement)
	collision_layer = 2 | 16
	collision_mask = 0

func setup_sprite(tile_size: int) -> void:
	# Create a colored rect as the debris visual — darker, semi-transparent wall look
	if tile_positions.is_empty():
		return
	_sprite = Sprite2D.new()
	# Use a simple white texture tinted to dark brown/grey + transparency
	var img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_sprite.texture = ImageTexture.create_from_image(img)
	# Scale to cover all debris tiles
	var min_pos = tile_positions[0]
	var max_pos = tile_positions[0]
	for pos in tile_positions:
		min_pos.x = mini(min_pos.x, pos.x)
		min_pos.y = mini(min_pos.y, pos.y)
		max_pos.x = maxi(max_pos.x, pos.x)
		max_pos.y = maxi(max_pos.y, pos.y)
	var w = (max_pos.x - min_pos.x + 1) * tile_size
	var h = (max_pos.y - min_pos.y + 1) * tile_size
	_sprite.scale = Vector2(w, h)
	_sprite.position = Vector2(
		(min_pos.x + max_pos.x + 1) * tile_size / 2.0,
		(min_pos.y + max_pos.y + 1) * tile_size / 2.0
	)
	# Dark brownish color, semi-transparent
	_sprite.modulate = Color(0.35, 0.28, 0.2, 0.7)
	add_child(_sprite)

func take_damage(amount: int) -> void:
	hp -= amount
	# Flash red on hit
	if _sprite:
		_sprite.modulate = Color(1.0, 0.3, 0.2, 0.8)
		var tween = create_tween()
		tween.tween_property(_sprite, "modulate", Color(0.35, 0.28, 0.2, 0.7), 0.15)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("impact_b", -4.0)
	if hp <= 0:
		_destroy()

func _destroy() -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("magic_crumble", -2.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.death_burst(global_position, Color(0.5, 0.4, 0.3), 0)
		vfx.shake(1.5, 0.15)
	# Remove wall tiles and restore floor
	for pos in tile_positions:
		if wall_layer_ref:
			wall_layer_ref.erase_cell(pos)
		if floor_layer_ref:
			floor_layer_ref.set_cell(pos, 0, floor_tile)
	debris_destroyed.emit()
	queue_free()
