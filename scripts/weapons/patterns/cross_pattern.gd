class_name CrossPattern
extends WeaponPattern

## Fires in 4 cardinal directions (+ shape) relative to aim.
@export var arms: int = 4
@export var bullets_per_arm: int = 2
@export var arm_delay: float = 0.05

func _init() -> void:
	pattern_name = "Cross"

func get_fire_data(aim_direction: Vector2, _stats: EquipmentManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var angle_step = TAU / arms
	for arm in range(arms):
		var arm_dir = aim_direction.rotated(angle_step * arm)
		for b in range(bullets_per_arm):
			result.append({
				"direction": arm_dir,
				"delay": b * arm_delay,
				"offset": Vector2.ZERO,
				"speed_mult": 1.0 - b * 0.15  # inner bullets slightly slower
			})
	return result
