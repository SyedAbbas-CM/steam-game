class_name LevelSystem
extends Node

const MAX_LEVEL = 99

var level: int = 1
var xp: int = 0
var unspent_stat_points: int = 0
var allocated: Dictionary = {}  # "vitality" -> count, "power" -> count, etc.

signal leveled_up(new_level: int)
signal xp_gained(amount: int, total: int)

# Per-level auto-gains (added per level above 1)
const LEVEL_BONUSES: Dictionary = {
	StatModifier.StatType.MAX_HP: 3.0,
	StatModifier.StatType.MOVE_SPEED: 1.5,
	StatModifier.StatType.ATTACK_DAMAGE: 0.15,
	StatModifier.StatType.ATTACK_SPEED: -0.003,  # negative = faster
	StatModifier.StatType.BULLET_SPEED: 1.0,
	StatModifier.StatType.MAX_MP: 2.0,
	# HP_REGEN removed — only increases via vitality allocation or potions
	StatModifier.StatType.MP_REGEN: 0.03,
	StatModifier.StatType.LUCK: 0.5,
	StatModifier.StatType.CRIT_DAMAGE: 0.02,
	StatModifier.StatType.ARMOR: 0.2,
	StatModifier.StatType.DODGE_CHANCE: 0.15,
	StatModifier.StatType.PICKUP_RADIUS: 0.5,
	StatModifier.StatType.COOLDOWN_REDUCTION: 0.2,
	StatModifier.StatType.MAX_STAMINA: 5.0,     # +5 max stamina per level
	StatModifier.StatType.STAMINA_REGEN: 0.5,   # +0.5 regen/s per level
}

# Stat point allocation categories — each gives a bundle of stat bonuses per point
const ALLOCATION_CATEGORIES: Dictionary = {
	"vitality": {
		StatModifier.StatType.MAX_HP: 10.0,
		StatModifier.StatType.HP_REGEN: 0.3,
		StatModifier.StatType.ARMOR: 1.0,
	},
	"power": {
		StatModifier.StatType.ATTACK_DAMAGE: 1.0,
		StatModifier.StatType.BULLET_SPEED: 5.0,
		StatModifier.StatType.CRIT_DAMAGE: 0.1,
	},
	"agility": {
		StatModifier.StatType.MOVE_SPEED: 3.0,
		StatModifier.StatType.ACCELERATION: 0.3,
		StatModifier.StatType.DODGE_CHANCE: 1.0,
		StatModifier.StatType.MAX_STAMINA: 15.0,
		StatModifier.StatType.STAMINA_REGEN: 2.0,
	},
	"spirit": {
		StatModifier.StatType.MAX_MP: 10.0,
		StatModifier.StatType.MP_REGEN: 0.5,
		StatModifier.StatType.COOLDOWN_REDUCTION: 3.0,
	},
	"fortune": {
		StatModifier.StatType.LUCK: 3.0,
		StatModifier.StatType.XP_MULT: 0.1,
		StatModifier.StatType.GOLD_MULT: 0.1,
	},
	"bulk": {
		StatModifier.StatType.WEIGHT: 0.5,
		StatModifier.StatType.MAX_HP: 5.0,
		StatModifier.StatType.PICKUP_RADIUS: 2.0,
		StatModifier.StatType.TENACITY: 3.0,
		StatModifier.StatType.THORNS: 1.0,
	},
}

func xp_to_next_level() -> int:
	# Early levels are fast, scales up gradually
	return 100 + (level - 1) * 50

func gain_xp(amount: int, xp_mult: float = 1.0) -> void:
	if level >= MAX_LEVEL:
		return
	var gained = int(amount * xp_mult)
	xp += gained
	xp_gained.emit(gained, xp)

	while xp >= xp_to_next_level() and level < MAX_LEVEL:
		xp -= xp_to_next_level()
		level += 1
		unspent_stat_points += 1
		leveled_up.emit(level)
		print("LEVEL UP! Now level %d (next: %d XP)" % [level, xp_to_next_level()])

func get_level_bonus(stat_type: StatModifier.StatType) -> float:
	if not LEVEL_BONUSES.has(stat_type):
		return 0.0
	return LEVEL_BONUSES[stat_type] * (level - 1)

func get_allocation_bonus(stat_type: StatModifier.StatType) -> float:
	var total: float = 0.0
	for category in allocated:
		var count = allocated[category] as int
		if count <= 0:
			continue
		var bonuses = ALLOCATION_CATEGORIES.get(category, {}) as Dictionary
		if bonuses.has(stat_type):
			total += bonuses[stat_type] * count
	return total

func get_total_allocated_points() -> int:
	var total: int = 0
	for cat in allocated:
		total += allocated[cat] as int
	return total

# Power level: represents overall player strength for dungeon scaling comparison
# Formula: level * 10 + allocated_stat_points * 5
# Level 1 naked = 10, Level 5 with 1 point = 55, Level 10 with 2 points = 110
func get_power_level() -> int:
	return level * 10 + get_total_allocated_points() * 5

# Returns the recommended player level for a given dungeon power level
static func power_to_level(power: int) -> int:
	return maxi(1, power / 10)

## Ensure total points match expected (1 per level). Call anytime.
func ensure_retroactive_points() -> void:
	var total_spent = get_total_allocated_points()
	var expected_total = level - 1
	if total_spent + unspent_stat_points < expected_total:
		unspent_stat_points = expected_total - total_spent

func allocate_stat_point(category: String) -> bool:
	ensure_retroactive_points()
	if unspent_stat_points <= 0:
		return false
	if not ALLOCATION_CATEGORIES.has(category):
		return false
	unspent_stat_points -= 1
	allocated[category] = allocated.get(category, 0) + 1
	return true

func get_xp_progress() -> float:
	if level >= MAX_LEVEL:
		return 1.0
	return float(xp) / float(xp_to_next_level())

func save_to_dict() -> Dictionary:
	return {
		"level": level,
		"xp": xp,
		"unspent_stat_points": unspent_stat_points,
		"allocated": allocated.duplicate(),
	}

func load_from_dict(data: Dictionary) -> void:
	level = data.get("level", 1)
	xp = data.get("xp", 0)
	unspent_stat_points = data.get("unspent_stat_points", 0)
	allocated = data.get("allocated", {}).duplicate()
	# Retroactive fix: ensure total points = level - 1 (1 per level after level 1)
	var total_spent = get_total_allocated_points()
	var expected_total = level - 1
	if total_spent + unspent_stat_points < expected_total:
		unspent_stat_points = expected_total - total_spent
