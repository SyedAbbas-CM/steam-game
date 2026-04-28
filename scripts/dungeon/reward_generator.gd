class_name RewardGenerator
extends RefCounted

static func generate_treasure_rewards(floor_num: int) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	var gold_amount = 10 + floor_num * 5
	var potion_count = 2 + floor_num / 2

	# Option 1: Gold
	rewards.append({
		"type": "gold",
		"name": str(gold_amount) + " Gold",
		"description": "Shiny coins",
		"amount": gold_amount,
		"rarity": 0
	})

	# Option 2: Big gold
	var big_gold = gold_amount * 2
	rewards.append({
		"type": "gold",
		"name": str(big_gold) + " Gold",
		"description": "A big pile of gold",
		"amount": big_gold,
		"rarity": 1
	})

	# Option 3: HP Potions
	rewards.append({
		"type": "hp_potion",
		"name": str(potion_count) + " HP Potions",
		"description": "Restores health",
		"amount": potion_count,
		"rarity": 0
	})

	# Option 4: Mana Potions
	var mp_count = 2 + floor_num / 3
	rewards.append({
		"type": "mp_potion",
		"name": str(mp_count) + " Mana Potions",
		"description": "Restores magical energy",
		"amount": mp_count,
		"rarity": 0
	})

	return rewards

static func generate_shrine_rewards(floor_num: int) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []

	# Option 1: Full heal
	rewards.append({
		"type": "heal",
		"name": "Full Heal",
		"description": "Restore all HP",
		"rarity": 1
	})

	# Option 2: Gold
	var gold_amount = 20 + floor_num * 8
	rewards.append({
		"type": "gold",
		"name": str(gold_amount) + " Gold",
		"description": "Blessed offering",
		"amount": gold_amount,
		"rarity": 1
	})

	# Option 3: HP Potions
	var potion_count = 3 + floor_num / 2
	rewards.append({
		"type": "hp_potion",
		"name": str(potion_count) + " HP Potions",
		"description": "Shrine blessing",
		"amount": potion_count,
		"rarity": 1
	})

	return rewards
