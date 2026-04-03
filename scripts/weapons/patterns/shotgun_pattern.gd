class_name ShotgunPattern
extends WeaponPattern

@export var pellet_count: int = 3
@export var cone_angle: float = 0.4
@export var speed_variance: float = 0.3

func _init() -> void:
	pattern_name = "Shotgun"

func get_fire_data(aim_direction: Vector2, _stats: EquipmentManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	# Each pellet does 1/pellet_count of total damage (min 1 per pellet)
	var per_pellet_mult = 1.0 / pellet_count
	for i in range(pellet_count):
		var angle_offset = randf_range(-cone_angle / 2.0, cone_angle / 2.0)
		var spd = 1.0 + randf_range(-speed_variance, speed_variance)
		result.append({
			"direction": aim_direction.rotated(angle_offset),
			"delay": 0.0,
			"offset": Vector2.ZERO,
			"speed_mult": spd,
			"damage_mult": per_pellet_mult
		})
	return result
