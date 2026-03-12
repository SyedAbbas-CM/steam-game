class_name ScatterPattern
extends WeaponPattern

## Chaotic spray — random directions biased toward aim. High bullet count, unpredictable.
@export var scatter_count: int = 8
@export var scatter_bias: float = 0.7  # 0 = fully random, 1 = fully aimed

func _init() -> void:
	pattern_name = "Scatter"
	cooldown_override = 0.7

func get_fire_data(aim_direction: Vector2, _stats: EquipmentManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(scatter_count):
		var random_dir = Vector2.RIGHT.rotated(randf() * TAU)
		var dir = aim_direction.lerp(random_dir, 1.0 - scatter_bias).normalized()
		result.append({
			"direction": dir,
			"delay": randf_range(0.0, 0.1),
			"offset": Vector2.ZERO,
			"speed_mult": randf_range(0.5, 1.5)
		})
	return result
