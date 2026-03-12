class_name TridentPattern
extends WeaponPattern

## Fires 3 bullets: one straight, two at angles — a classic trident spread.
@export var side_angle: float = 0.25

func _init() -> void:
	pattern_name = "Trident"

func get_fire_data(aim_direction: Vector2, _stats: EquipmentManager) -> Array[Dictionary]:
	return [
		{"direction": aim_direction, "delay": 0.0, "offset": Vector2.ZERO, "speed_mult": 1.0},
		{"direction": aim_direction.rotated(side_angle), "delay": 0.0, "offset": Vector2.ZERO, "speed_mult": 0.9},
		{"direction": aim_direction.rotated(-side_angle), "delay": 0.0, "offset": Vector2.ZERO, "speed_mult": 0.9},
	]
