class_name OrbitPattern
extends WeaponPattern

## Fires bullets that orbit outward in a expanding circle — defensive zone control.
@export var orbit_count: int = 4
var orbit_angle: float = 0.0

func _init() -> void:
	pattern_name = "Orbit"
	is_continuous = true

func get_fire_data(aim_direction: Vector2, stats: EquipmentManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(orbit_count):
		var angle = orbit_angle + (TAU / orbit_count) * i
		var dir = Vector2.RIGHT.rotated(angle)
		var offset = dir * 4.0  # spawn slightly outward
		result.append({
			"direction": dir,
			"delay": 0.0,
			"offset": offset,
			"speed_mult": 0.7
		})
	# Spin faster when fire-rate stats are higher. attack_speed_mult >1 = faster.
	orbit_angle += 0.5 * stats.get_attack_speed_mult()
	return result
