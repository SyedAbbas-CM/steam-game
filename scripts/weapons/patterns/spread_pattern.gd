class_name SpreadPattern
extends WeaponPattern

func _init() -> void:
	pattern_name = "Spread Shot"

func get_fire_data(aim_direction: Vector2, stats: EquipmentManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var count: int = stats.get_bullet_count()
	var total_angle: float = stats.get_spread_angle()

	if total_angle <= 0.0:
		total_angle = 0.6  # default ~35 degree fan

	if count <= 1:
		result.append({"direction": aim_direction, "delay": 0.0,
			"offset": Vector2.ZERO, "speed_mult": 1.0})
		return result

	var start_angle: float = -total_angle / 2.0
	var step: float = total_angle / (count - 1)

	for i in range(count):
		var angle: float = start_angle + step * i
		result.append({
			"direction": aim_direction.rotated(angle),
			"delay": 0.0,
			"offset": Vector2.ZERO,
			"speed_mult": 1.0
		})
	return result
