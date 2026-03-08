class_name PetDefinition
extends Resource

@export var id: int = 0
@export var pet_type: String = ""
@export var search_distance: float = 10.0
@export var wander_distance: float = 8.0
@export var max_level: int = 30
@export var owner_level: int = 1
@export var cost: int = 0
@export var recover_rate: float = 0.1

# Base stats
@export var base_attack: float = 1.0
@export var base_defense: float = 1.0
@export var base_hp: int = 10
@export var base_charge: int = 0

# Stat gains per level
@export var hp_gain: float = 1.0
@export var attack_gain: float = 0.5
@export var defense_gain: float = 0.5
@export var charge_gain: float = 0.0

# Abilities unlocked at certain levels
@export var abilities: Array = []  # [{level, name, desc}]

# Evolution
@export var evolve_level: int = 0
@export var evolve_name: String = ""

# Possible names
@export var possible_names: Array[String] = []

func get_stats_at_level(level: int) -> Dictionary:
	return {
		"hp": int(base_hp + hp_gain * (level - 1)),
		"attack": base_attack + attack_gain * (level - 1),
		"defense": base_defense + defense_gain * (level - 1),
		"charge": int(base_charge + charge_gain * (level - 1)),
	}

func get_abilities_at_level(level: int) -> Array:
	var result: Array = []
	for ability in abilities:
		if int(ability.get("level", 999)) <= level:
			result.append(ability)
	return result
