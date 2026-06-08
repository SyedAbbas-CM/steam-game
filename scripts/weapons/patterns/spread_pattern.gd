class_name SpreadPattern
extends WeaponPattern

func _init() -> void:
	pattern_name = "Spread Shot"

func get_fire_data(aim_direction: Vector2, stats: EquipmentManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var count: int = stats.get_bullet_count()
	var total_angle: float = stats.get_spread_angle()

	if total_angle <= 0.0:
		# Default spread scales with bullet count so 2-bullet weapons (wizard staff)
		# stay nearly parallel, while 4+ bullet weapons get a real fan.
		total_angle = 0.07 * float(count - 1)
		total_angle = clampf(total_angle, 0.04, 0.30)

	if count <= 1:
		result.append({"direction": aim_direction, "delay": 0.0,
			"offset": Vector2.ZERO, "speed_mult": 1.0})
		return result

	var start_angle: float = -total_angle / 2.0
	var step: float = total_angle / (count - 1)
	var per_bullet_mult = 1.0 / count

	for i in range(count):
		var angle: float = start_angle + step * i
		result.append({
			"direction": aim_direction.rotated(angle),
			"delay": 0.0,
			"offset": Vector2.ZERO,
			"speed_mult": 1.0,
			"damage_mult": per_bullet_mult
		})
	return result
