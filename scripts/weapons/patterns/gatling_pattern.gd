class_name GatlingPattern
extends WeaponPattern

## Rapid-fire stream with slight random spread — machine gun style.
@export var bullet_count: int = 6
@export var fire_delay: float = 0.04
@export var jitter: float = 0.08  # random spread per bullet

func _init() -> void:
	pattern_name = "Gatling"
	cooldown_override = 0.5

func get_fire_data(aim_direction: Vector2, _stats: EquipmentManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(bullet_count):
		var spread = randf_range(-jitter, jitter)
		result.append({
			"direction": aim_direction.rotated(spread),
			"delay": i * fire_delay,
			"offset": Vector2.ZERO,
			"speed_mult": randf_range(0.9, 1.1)
		})
	return result
