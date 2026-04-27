class_name UpgradeDefinition
extends Resource

enum Category { COMBAT, SURVIVAL, UTILITY, CLASS }

@export var id: String = ""
@export var upgrade_name: String = ""
@export var description: String = ""
@export var category: Category = Category.COMBAT
@export var max_level: int = 5
@export var base_cost: int = 10
@export var cost_per_level: int = 5
@export var required_class: String = ""
@export var required_upgrade: String = ""
## Each entry: {stat: StatModifier.StatType (int), flat: float, percent: float}
@export var stat_bonuses: Array[Dictionary] = []

func get_cost(current_level: int) -> int:
	return base_cost + cost_per_level * current_level

func get_bonus_at_level(level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for bonus in stat_bonuses:
		result.append({
			"stat": bonus["stat"],
			"flat": bonus.get("flat", 0.0) * level,
			"percent": bonus.get("percent", 0.0) * level,
		})
	return result
