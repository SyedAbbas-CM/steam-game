class_name BurstPattern
extends WeaponPattern

@export var burst_count: int = 3
@export var burst_delay: float = 0.06

func _init() -> void:
	pattern_name = "Burst Fire"
	cooldown_override = 0.5  # 0.5s gap between bursts (prevents machine gun spam)

func get_fire_data(aim_direction: Vector2, _stats: EquipmentManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var per_bullet_mult = 1.0 / burst_count
	for i in range(burst_count):
		result.append({
			"direction": aim_direction,
			"delay": i * burst_delay,
			"offset": Vector2.ZERO,
			"speed_mult": 1.0,
			"damage_mult": per_bullet_mult
		})
	return result
