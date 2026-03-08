class_name BurstPattern
extends WeaponPattern

@export var burst_count: int = 3
@export var burst_delay: float = 0.05

func _init() -> void:
	pattern_name = "Burst Fire"

func get_fire_data(aim_direction: Vector2, _stats: EquipmentManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(burst_count):
		result.append({
			"direction": aim_direction,
			"delay": i * burst_delay,
			"offset": Vector2.ZERO,
			"speed_mult": 1.0
		})
	return result
