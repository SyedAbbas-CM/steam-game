class_name WeaponPattern
extends Resource

@export var pattern_name: String = "Single Shot"
@export var cooldown_override: float = 0.0
@export var is_continuous: bool = false

## Override this in subclasses to define bullet spawn geometry.
## Returns array of dicts: {direction: Vector2, delay: float, offset: Vector2, speed_mult: float}
func get_fire_data(aim_direction: Vector2, stats: EquipmentManager) -> Array[Dictionary]:
	return [{
		"direction": aim_direction,
		"delay": 0.0,
		"offset": Vector2.ZERO,
		"speed_mult": 1.0
	}]
