class_name SpiralPattern
extends WeaponPattern

@export var rotation_speed: float = 3.0
var accumulated_angle: float = 0.0

func _init() -> void:
	pattern_name = "Spiral"
	is_continuous = true

func get_fire_data(aim_direction: Vector2, stats: EquipmentManager) -> Array[Dictionary]:
	var dir = Vector2.RIGHT.rotated(accumulated_angle)
	accumulated_angle += rotation_speed * stats.get_attack_speed()
	return [{
		"direction": dir,
		"delay": 0.0,
		"offset": Vector2.ZERO,
		"speed_mult": 1.0
	}]
