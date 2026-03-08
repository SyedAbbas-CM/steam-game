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
	if hp <= 0:
		_destroy()

func _destroy() -> void:
	for pos in tile_positions:
		if wall_layer_ref:
			wall_layer_ref.erase_cell(pos)
	wall_destroyed.emit()
	queue_free()
