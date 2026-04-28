class_name NovaPattern
extends WeaponPattern

## Fires two rings — inner fast, outer slow — for a nova explosion effect.
@export var inner_count: int = 6
@export var outer_count: int = 12

func _init() -> void:
	pattern_name = "Nova"
	cooldown_override = 0.8

func get_fire_data(aim_direction: Vector2, _stats: EquipmentManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var total = inner_count + outer_count
	var per_bullet_mult = 1.0 / maxf(total, 1.0)
	# Inner ring: fast, fires immediately
	for i in range(inner_count):
		var angle = (TAU / inner_count) * i
		result.append({
			"direction": Vector2.RIGHT.rotated(angle),
			"delay": 0.0,
			"offset": Vector2.ZERO,
			"speed_mult": 1.5,
			"damage_mult": per_bullet_mult
		})
	# Outer ring: slow, delayed
	for i in range(outer_count):
		var angle = (TAU / outer_count) * i + (TAU / outer_count / 2.0)  # offset from inner
		result.append({
			"direction": Vector2.RIGHT.rotated(angle),
			"delay": 0.15,
			"offset": Vector2.ZERO,
			"speed_mult": 0.6,
			"damage_mult": per_bullet_mult
		})
	return result
