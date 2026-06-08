class_name StatThresholds
extends RefCounted

## Passive bonuses unlocked at stat allocation milestones (5, 10, 15 points)
## Returns {StatType(int): {flat: float, percent: float}}

const THRESHOLDS = {
	"health": {
		5: {"name": "Vigorous", "desc": "+10% Max HP", "bonuses": {0: {"flat": 0.0, "percent": 0.10}}},
		10: {"name": "Hardy", "desc": "+1 HP Regen", "bonuses": {10: {"flat": 1.0, "percent": 0.0}}},
		15: {"name": "Undying", "desc": "+20% Max HP", "bonuses": {0: {"flat": 0.0, "percent": 0.20}}},
	},
	"defense": {
		5: {"name": "Thick Skin", "desc": "+15% Armor", "bonuses": {14: {"flat": 0.0, "percent": 0.15}}},
		10: {"name": "Spiked", "desc": "+2 Thorns", "bonuses": {26: {"flat": 2.0, "percent": 0.0}}},
		15: {"name": "Unyielding", "desc": "+15 Tenacity", "bonuses": {25: {"flat": 15.0, "percent": 0.0}}},
	},
	"strength": {
		5: {"name": "Heavy Hitter", "desc": "+0.15 Crit Damage", "bonuses": {13: {"flat": 0.15, "percent": 0.0}}},
		10: {"name": "Strong Arm", "desc": "+10% Damage", "bonuses": {2: {"flat": 0.0, "percent": 0.10}}},
		15: {"name": "Crusher", "desc": "+20% Damage", "bonuses": {2: {"flat": 0.0, "percent": 0.20}}},
	},
	"speed": {
		5: {"name": "Whip Crack", "desc": "+10% Bullet Speed", "bonuses": {4: {"flat": 0.0, "percent": 0.10}}},
		10: {"name": "Rapid Fire", "desc": "-8% Attack Interval", "bonuses": {3: {"flat": 0.0, "percent": -0.08}}},
		15: {"name": "Penetrator", "desc": "+1 Pierce", "bonuses": {7: {"flat": 1.0, "percent": 0.0}}},
	},
	"movement": {
		5: {"name": "Fleet Foot", "desc": "+8% Move Speed", "bonuses": {1: {"flat": 0.0, "percent": 0.08}}},
		10: {"name": "Evasion Master", "desc": "+8 Dodge", "bonuses": {17: {"flat": 8.0, "percent": 0.0}}},
		15: {"name": "Shadow Step", "desc": "+15 Stealth", "bonuses": {22: {"flat": 15.0, "percent": 0.0}}},
	},
	"intellect": {
		5: {"name": "Mana Font", "desc": "+15% Max MP", "bonuses": {9: {"flat": 0.0, "percent": 0.15}}},
		10: {"name": "Spell Weaver", "desc": "+10% CDR", "bonuses": {21: {"flat": 10.0, "percent": 0.0}}},
		15: {"name": "Archmage", "desc": "+1.5 MP Regen", "bonuses": {11: {"flat": 1.5, "percent": 0.0}}},
	},
	"luck": {
		5: {"name": "Lucky", "desc": "+15% Gold", "bonuses": {19: {"flat": 0.15, "percent": 0.0}}},
		10: {"name": "Treasure Sense", "desc": "+25 Pickup Radius", "bonuses": {20: {"flat": 25.0, "percent": 0.0}}},
		15: {"name": "Fortune's Child", "desc": "+20% XP", "bonuses": {18: {"flat": 0.20, "percent": 0.0}}},
	},
	"endurance": {
		5: {"name": "Stout", "desc": "+25 Max Stamina", "bonuses": {23: {"flat": 25.0, "percent": 0.0}}},
		10: {"name": "Tireless", "desc": "+1 Stamina Regen", "bonuses": {24: {"flat": 1.0, "percent": 0.0}}},
		15: {"name": "Stalwart", "desc": "+10% HP & Armor", "bonuses": {0: {"flat": 0.0, "percent": 0.10}, 14: {"flat": 0.0, "percent": 0.10}}},
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
