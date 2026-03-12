class_name BoomerangPattern
extends WeaponPattern

## Fires bullets in a wide arc that curves back — like a boomerang throw.
## Uses offset directions that fan out wide then converge.
@export var arc_count: int = 3
@export var arc_spread: float = 0.8  # wide arc angle

func _init() -> void:
	pattern_name = "Boomerang"

func get_fire_data(aim_direction: Vector2, _stats: EquipmentManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if arc_count <= 1:
		result.append({
			"direction": aim_direction,
			"delay": 0.0,
			"offset": Vector2.ZERO,
			"speed_mult": 1.0
		})
		return result

	var start = -arc_spread / 2.0
	var step = arc_spread / (arc_count - 1)
	for i in range(arc_count):
		var angle = start + step * i
		var dir = aim_direction.rotated(angle)
		# Outer bullets are faster, inner slower — creates curving arc
		var t = abs(float(i) - (arc_count - 1) / 2.0) / ((arc_count - 1) / 2.0)
		result.append({
			"direction": dir,
			"delay": 0.0,
			"offset": Vector2.ZERO,
			"speed_mult": 0.7 + t * 0.6
		})
	return result
