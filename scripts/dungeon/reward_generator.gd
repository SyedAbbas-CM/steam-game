class_name RewardGenerator
extends RefCounted

static var _mutations: Array[MutationDefinition] = []
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_mutations.append(preload("res://resources/mutations/pierce.tres"))
	_mutations.append(preload("res://resources/mutations/life_steal.tres"))
	_mutations.append(preload("res://resources/mutations/homing.tres"))
	_mutations.append(preload("res://resources/mutations/exploding.tres"))
	_loaded = true

static func generate_treasure_rewards(floor_num: int) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []

	# Option 1: Gold
	var gold_amount = 20 + floor_num * 10
	rewards.append({
		"type": "gold",
		"name": str(gold_amount) + " Gold",
		"description": "Shiny coins",
		"amount": gold_amount,
		"rarity": 0
	})

	# Option 2: Troop tokens
	var tokens = 1 + floor_num / 2
	rewards.append({
		"type": "troop_tokens",
		"name": str(tokens) + " Troop Tokens",
		"description": "Recruit soldiers",
		"amount": tokens,
		"rarity": 0
	})

	# Option 3: Random equipment or companion
	if randf() < 0.4:
		rewards.append({
			"type": "companion",
			"name": "Archer Companion",
			"description": "Shoots nearby enemies",
			"companion_id": "archer",
			"rarity": 1
		})
	else:
		rewards.append({
			"type": "gold",
			"name": str(gold_amount * 2) + " Gold",
			"description": "A big pile",
			"amount": gold_amount * 2,
			"rarity": 1
		})

	return rewards

static func generate_shrine_rewards(_floor_num: int) -> Array[Dictionary]:
	_ensure_loaded()
	var rewards: Array[Dictionary] = []
	var available = _mutations.duplicate()
	available.shuffle()

	for i in range(mini(3, available.size())):
		var mutation = available[i]
		rewards.append({
			"type": "mutation",
			"name": mutation.mutation_name,
			"description": mutation.description,
			"mutation": mutation,
			"rarity": mutation.tier
		})

	return rewards
