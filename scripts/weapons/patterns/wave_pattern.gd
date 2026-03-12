class_name WavePattern
extends WeaponPattern

## Fires bullets in a sine-wave pattern. Bullets oscillate perpendicular to aim direction.
@export var wave_count: int = 3
@export var wave_spacing: float = 0.08
@export var wave_amplitude: float = 8.0

func _init() -> void:
	pattern_name = "Wave Shot"

func get_fire_data(aim_direction: Vector2, _stats: EquipmentManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var perp = aim_direction.rotated(PI / 2.0)
	for i in range(wave_count):
		var t = float(i) / maxf(wave_count - 1, 1)
		var offset_amount = sin(t * PI * 2.0) * wave_amplitude
		result.append({
			"direction": aim_direction,
			"delay": i * wave_spacing,
			"offset": perp * offset_amount,
			"speed_mult": 1.0
		})
	return result
