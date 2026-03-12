class_name ZigzagPattern
extends WeaponPattern

## Fires alternating left-right angled bullets for a zigzag wall of projectiles.
@export var zigzag_count: int = 5
@export var zigzag_angle: float = 0.35  # radians offset from center
@export var zigzag_delay: float = 0.06

func _init() -> void:
	pattern_name = "Zigzag"

func get_fire_data(aim_direction: Vector2, _stats: EquipmentManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(zigzag_count):
		var side = 1.0 if i % 2 == 0 else -1.0
		var dir = aim_direction.rotated(zigzag_angle * side)
		result.append({
			"direction": dir,
			"delay": i * zigzag_delay,
			"offset": Vector2.ZERO,
			"speed_mult": 1.0
		})
	return result
