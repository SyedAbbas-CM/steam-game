class_name LevelSystem
extends Node

const MAX_LEVEL = 100

# Display names for the 8 pure stats. Internal keys are full words.
const CATEGORY_DISPLAY_NAMES: Dictionary = {
	"health": "HP",
	"defense": "DEF",
	"strength": "STR",
	"speed": "SPD",
	"movement": "MOV",
	"intellect": "INT",
	"luck": "LCK",
	"endurance": "END",
}

# Map old bundled-stat keys to the closest new pure-stat for save migration.
const LEGACY_CATEGORY_MAP: Dictionary = {
	"vitality": "health",
	"power": "strength",
	"agility": "movement",
	"spirit": "intellect",
	"fortune": "luck",
	"bulk": "endurance",
}

var level: int = 1
var xp: int = 0
var unspent_stat_points: int = 0
var allocated: Dictionary = {}  # "vitality" -> count, "power" -> count, etc.

signal leveled_up(new_level: int)
signal xp_gained(amount: int, total: int)

# Per-level auto-gains (added per level above 1).
# Rebalanced for the 1-100 curve: lvl 30 ≈ early game power, lvl 100 = capped.
# Most progression is meant to come from allocated stat points + perks, not auto-gains.
const LEVEL_BONUSES: Dictionary = {
	StatModifier.StatType.MAX_HP: 1.0,
	StatModifier.StatType.MOVE_SPEED: 0.5,
	StatModifier.StatType.ATTACK_DAMAGE: 0.06,
	StatModifier.StatType.ATTACK_SPEED: -0.0012,
	StatModifier.StatType.BULLET_SPEED: 0.4,
	StatModifier.StatType.MAX_MP: 0.8,
	StatModifier.StatType.MP_REGEN: 0.012,
	StatModifier.StatType.LUCK: 0.2,
	StatModifier.StatType.CRIT_DAMAGE: 0.008,
	StatModifier.StatType.ARMOR: 0.08,
	StatModifier.StatType.DODGE_CHANCE: 0.06,
	StatModifier.StatType.PICKUP_RADIUS: 0.2,
	StatModifier.StatType.COOLDOWN_REDUCTION: 0.08,
	StatModifier.StatType.MAX_STAMINA: 2.0,
	StatModifier.StatType.STAMINA_REGEN: 0.2,
}

# Stat point allocation categories — 8 pure stats, each governs 1-3 closely related things.
# Per-point values tuned for the 1-100 cap so end-game (99 points) stays manageable.
const ALLOCATION_CATEGORIES: Dictionary = {
	"health": {
		StatModifier.StatType.MAX_HP: 4.0,
		StatModifier.StatType.HP_REGEN: 0.12,
	},
	"defense": {
		StatModifier.StatType.ARMOR: 0.7,
		StatModifier.StatType.TENACITY: 0.8,
	},
	"strength": {
		StatModifier.StatType.ATTACK_DAMAGE: 0.4,
		StatModifier.StatType.CRIT_DAMAGE: 0.03,
	},
	"speed": {
		StatModifier.StatType.ATTACK_SPEED: -0.002,  # negative = faster
		StatModifier.StatType.BULLET_SPEED: 2.0,
	},
	"movement": {
		StatModifier.StatType.MOVE_SPEED: 1.2,
		StatModifier.StatType.DODGE_CHANCE: 0.4,
	},
	"intellect": {
		StatModifier.StatType.MAX_MP: 2.5,
		StatModifier.StatType.MP_REGEN: 0.12,
		StatModifier.StatType.COOLDOWN_REDUCTION: 0.7,
		StatModifier.StatType.ATTACK_DAMAGE: 0.3,  # scales staff/wand/tome damage
	},
	"luck": {
		StatModifier.StatType.LUCK: 0.8,
		StatModifier.StatType.GOLD_MULT: 0.025,
		StatModifier.StatType.XP_MULT: 0.025,
	},
	"endurance": {
		StatModifier.StatType.MAX_STAMINA: 2.5,
		StatModifier.StatType.STAMINA_REGEN: 0.25,
		StatModifier.StatType.PICKUP_RADIUS: 1.0,
	},
}

func xp_to_next_level() -> int:
	# Stretched curve for 1-100: early levels fast, late levels meaningful grind.
	# Lvl 1→2: 150 XP. Lvl 30→31: ~2500 XP. Lvl 100→cap: ~30000 XP.
	# Cumulative to 100 ≈ 1M XP.
	var lv = level - 1
	return 150 + lv * 80 + int(lv * lv * 2.4)

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

## Returns points allocated to a category by either internal key or display name.
## "vitality" or "VIT" both return vitality points.
func get_allocation_points(name_or_key: String) -> int:
	if allocated.has(name_or_key):
		return allocated[name_or_key] as int
	for key in CATEGORY_DISPLAY_NAMES:
		if CATEGORY_DISPLAY_NAMES[key] == name_or_key:
			return allocated.get(key, 0) as int
	return 0

## Display name for an internal category key ("vitality" -> "VIT")
static func display_name(key: String) -> String:
	return CATEGORY_DISPLAY_NAMES.get(key, key.to_upper())

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
	# Migrate legacy 6-bundle keys to new 8-stat keys (refund points if old keys exist).
	var migrated_points = 0
	var clean_allocated: Dictionary = {}
	for key in allocated:
		if ALLOCATION_CATEGORIES.has(key):
			clean_allocated[key] = allocated[key]
		else:
			# Legacy or unknown key — refund the points
			migrated_points += int(allocated[key])
	if migrated_points > 0:
		allocated = clean_allocated
		unspent_stat_points += migrated_points
		print("LevelSystem: migrated %d legacy stat points to refund pool" % migrated_points)
	# Retroactive fix: ensure total points = level - 1 (1 per level after level 1)
	var total_spent = get_total_allocated_points()
	var expected_total = level - 1
	if total_spent + unspent_stat_points < expected_total:
		unspent_stat_points = expected_total - total_spent
