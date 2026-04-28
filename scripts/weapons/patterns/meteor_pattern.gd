class_name MeteorPattern
extends WeaponPattern

## Fires a cluster of bullets that spread outward from a tight origin — like a meteor shower.
@export var cluster_count: int = 4
@export var initial_spread: float = 0.15  # tight starting cone
@export var speed_range: Vector2 = Vector2(0.5, 1.5)  # min/max speed multiplier

func _init() -> void:
	pattern_name = "Meteor"
	cooldown_override = 0.35

func get_fire_data(aim_direction: Vector2, _stats: EquipmentManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var per_bullet_mult = 1.0 / cluster_count
	for i in range(cluster_count):
		var angle_offset = randf_range(-initial_spread, initial_spread)
		var spd = randf_range(speed_range.x, speed_range.y)
		result.append({
			"direction": aim_direction.rotated(angle_offset),
			"delay": randf_range(0.0, 0.08),
			"offset": Vector2.ZERO,
			"speed_mult": spd,
			"damage_mult": per_bullet_mult
		})
	return result
