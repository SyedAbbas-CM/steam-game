class_name BreakableWall
extends StaticBody2D

var hp: int = 5
var tile_positions: Array[Vector2i] = []
var wall_layer_ref: TileMapLayer
var floor_tile: Vector2i = Vector2i(5, 0)

signal wall_destroyed

func _ready() -> void:
	# Layer 2 so player bullets hit it (bullets mask 2)
	# Layer 16 so it blocks movement
	collision_layer = 2 | 16
	collision_mask = 0

func take_damage(amount: int) -> void:
	hp -= amount
	# Visual feedback: flash
	modulate = Color(1.5, 0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
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
	for pos in tile_positions:
		if wall_layer_ref:
			wall_layer_ref.erase_cell(pos)
	wall_destroyed.emit()
	queue_free()
