class_name HelixPattern
extends WeaponPattern

## Two interleaved spiraling streams that twist around each other.
@export var rotation_speed: float = 4.0
@export var bullets_per_shot: int = 2
var accumulated_angle: float = 0.0

func _init() -> void:
	pattern_name = "Helix"
	is_continuous = true

func get_fire_data(aim_direction: Vector2, stats: EquipmentManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(bullets_per_shot):
		var offset_angle = accumulated_angle + (TAU / bullets_per_shot) * i
		var dir = aim_direction.rotated(sin(offset_angle) * 0.4)
		var perp = aim_direction.rotated(PI / 2.0)
		var offset = perp * cos(offset_angle) * 5.0
		result.append({
			"direction": dir,
			"delay": 0.0,
			"offset": offset,
			"speed_mult": 1.0
		})
	# attack_speed_mult >1 = faster fire/rotate. See equipment_manager.gd.
	accumulated_angle += rotation_speed * stats.get_attack_speed_mult()
	return result
