class_name RingPattern
extends WeaponPattern

@export var bullet_count: int = 8

func _init() -> void:
	pattern_name = "Ring Shot"

func get_fire_data(aim_direction: Vector2, _stats: EquipmentManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var step: float = TAU / bullet_count
	var per_bullet_mult = 1.0 / bullet_count
	for i in range(bullet_count):
		result.append({
			"direction": Vector2.RIGHT.rotated(step * i),
			"delay": 0.0,
			"offset": Vector2.ZERO,
			"speed_mult": 1.0,
			"damage_mult": per_bullet_mult
		})
	return result
