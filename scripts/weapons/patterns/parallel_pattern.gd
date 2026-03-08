class_name ParallelPattern
extends WeaponPattern

@export var stream_count: int = 2
@export var spacing: float = 6.0

func _init() -> void:
	pattern_name = "Parallel"

func get_fire_data(aim_direction: Vector2, _stats: EquipmentManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var perp: Vector2 = aim_direction.rotated(PI / 2.0)
	var start_offset: float = -(stream_count - 1) * spacing / 2.0

	for i in range(stream_count):
		var offset = perp * (start_offset + i * spacing)
		result.append({
			"direction": aim_direction,
			"delay": 0.0,
			"offset": offset,
			"speed_mult": 1.0
		})
	return result
