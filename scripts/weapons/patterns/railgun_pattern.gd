class_name RailgunPattern
extends WeaponPattern

## Single high-speed piercing shot with a charge delay.
@export var charge_time: float = 0.15

func _init() -> void:
	pattern_name = "Railgun"
	cooldown_override = 1.0

func get_fire_data(aim_direction: Vector2, _stats: EquipmentManager) -> Array[Dictionary]:
	return [{
		"direction": aim_direction,
		"delay": charge_time,
		"offset": Vector2.ZERO,
		"speed_mult": 3.0
	}]
