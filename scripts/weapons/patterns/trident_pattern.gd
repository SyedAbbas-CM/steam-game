class_name TridentPattern
extends WeaponPattern

## Fires 3 piercing bullets: one straight, two at angles — a classic trident spread.
## Center bullet pierces 2 enemies, side bullets pierce 1.
@export var side_angle: float = 0.2
@export var center_pierce: int = 2
@export var side_pierce: int = 1

func _init() -> void:
	pattern_name = "Trident"

func get_fire_data(aim_direction: Vector2, _stats: EquipmentManager) -> Array[Dictionary]:
	return [
		{"direction": aim_direction, "delay": 0.0, "offset": Vector2.ZERO, "speed_mult": 1.1, "pierce": center_pierce, "damage_mult": 1.0 / 3.0},
		{"direction": aim_direction.rotated(side_angle), "delay": 0.0, "offset": Vector2.ZERO, "speed_mult": 0.95, "pierce": side_pierce, "damage_mult": 1.0 / 3.0},
		{"direction": aim_direction.rotated(-side_angle), "delay": 0.0, "offset": Vector2.ZERO, "speed_mult": 0.95, "pierce": side_pierce, "damage_mult": 1.0 / 3.0},
	]
