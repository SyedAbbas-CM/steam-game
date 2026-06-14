class_name GatlingPattern
extends WeaponPattern

## Rapid-fire stream with slight random spread — machine gun style.
## Per-bullet damage is reduced so total burst DPS stays in line with sword.
## Was: 6 bullets × 1.0 = 6× sword per burst (broken).
## Now: 6 bullets × 0.3 = 1.8× per burst at 0.65 s cooldown → ~1.4× sword DPS.
@export var bullet_count: int = 6
@export var fire_delay: float = 0.05
@export var jitter: float = 0.08  # random spread per bullet
const PER_BULLET_DAMAGE := 0.3

func _init() -> void:
	pattern_name = "Gatling"
	cooldown_override = 0.65

func get_fire_data(aim_direction: Vector2, _stats: EquipmentManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(bullet_count):
		var spread = randf_range(-jitter, jitter)
		result.append({
			"direction": aim_direction.rotated(spread),
			"delay": i * fire_delay,
			"offset": Vector2.ZERO,
			"speed_mult": randf_range(0.9, 1.1),
			"damage_mult": PER_BULLET_DAMAGE,
		})
	return result
