class_name StatThresholds
extends RefCounted

## Passive bonuses unlocked at stat allocation milestones (5, 10, 15 points)
## Returns {StatType(int): {flat: float, percent: float}}

const THRESHOLDS = {
	"vitality": {
		5: {"name": "Thick Skin", "desc": "+10% Armor", "bonuses": {14: {"flat": 0.0, "percent": 0.1}}},
		10: {"name": "Undying", "desc": "+15% Max HP", "bonuses": {0: {"flat": 0.0, "percent": 0.15}}},
		15: {"name": "Regenerator", "desc": "+2 HP Regen", "bonuses": {10: {"flat": 2.0, "percent": 0.0}}},
	},
	"power": {
		5: {"name": "Heavy Hitter", "desc": "+15% Crit Damage", "bonuses": {13: {"flat": 0.15, "percent": 0.0}}},
		10: {"name": "Crusher", "desc": "+20% ATK", "bonuses": {2: {"flat": 0.0, "percent": 0.2}}},
		15: {"name": "Executioner", "desc": "+1 Pierce", "bonuses": {7: {"flat": 1.0, "percent": 0.0}}},
	},
	"agility": {
		5: {"name": "Fleet Foot", "desc": "+10% Speed", "bonuses": {1: {"flat": 0.0, "percent": 0.1}}},
		10: {"name": "Evasion Master", "desc": "+10% Dodge", "bonuses": {17: {"flat": 10.0, "percent": 0.0}}},
		15: {"name": "Shadow Step", "desc": "+15 Stealth", "bonuses": {22: {"flat": 15.0, "percent": 0.0}}},
	},
	"spirit": {
		5: {"name": "Mana Font", "desc": "+20% Max MP", "bonuses": {9: {"flat": 0.0, "percent": 0.2}}},
		10: {"name": "Spell Weaver", "desc": "+15% CDR", "bonuses": {21: {"flat": 15.0, "percent": 0.0}}},
		15: {"name": "Archmage", "desc": "+2 MP Regen", "bonuses": {11: {"flat": 2.0, "percent": 0.0}}},
	},
	"fortune": {
		5: {"name": "Lucky", "desc": "+20% Gold", "bonuses": {19: {"flat": 0.2, "percent": 0.0}}},
		10: {"name": "Treasure Sense", "desc": "+30 Pickup", "bonuses": {20: {"flat": 30.0, "percent": 0.0}}},
		15: {"name": "Fortune's Child", "desc": "+25% XP", "bonuses": {18: {"flat": 0.25, "percent": 0.0}}},
	},
	"bulk": {
		5: {"name": "Immovable", "desc": "+15 Tenacity", "bonuses": {25: {"flat": 15.0, "percent": 0.0}}},
		10: {"name": "Thorny Hide", "desc": "+5 Thorns", "bonuses": {26: {"flat": 5.0, "percent": 0.0}}},
		15: {"name": "Juggernaut", "desc": "+25% HP & Armor", "bonuses": {0: {"flat": 0.0, "percent": 0.25}, 14: {"flat": 0.0, "percent": 0.25}}},
	},
}

static func get_active_bonuses(allocated: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for category in allocated:
		var points = allocated[category] as int
		if not THRESHOLDS.has(category):
			continue
		var thresholds = THRESHOLDS[category]
		for threshold_points in thresholds:
			if points >= threshold_points:
				var data = thresholds[threshold_points]
				for stat in data["bonuses"]:
					if not result.has(stat):
						result[stat] = {"flat": 0.0, "percent": 0.0}
					var bonus = data["bonuses"][stat]
					result[stat]["flat"] += bonus.get("flat", 0.0)
					result[stat]["percent"] += bonus.get("percent", 0.0)
	return result

## Returns array of {name, desc, category, threshold, active} for UI display
static func get_all_passives(allocated: Dictionary) -> Array[Dictionary]:
	var passives: Array[Dictionary] = []
	for category in THRESHOLDS:
		var points = allocated.get(category, 0) as int
		var thresholds = THRESHOLDS[category]
		for threshold_points in thresholds:
			var data = thresholds[threshold_points]
			passives.append({
				"name": data["name"],
				"desc": data["desc"],
				"category": category,
				"threshold": threshold_points,
				"active": points >= threshold_points,
				"current": points,
			})
	return passives
