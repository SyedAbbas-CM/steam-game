class_name PerkDefinition
extends Resource

@export var perk_id: String = ""
@export var perk_name: String = ""
@export var description: String = ""
@export var icon_index: int = 0  # LoY sprite index for icon
@export var class_required: String = ""  # "warrior", "archer", "wizard", "mercenary"
@export var tier: int = 1  # 1-3 (capstone = tier 4)
@export var prerequisites: Array[String] = []  # perk_ids that must be unlocked first

# Stat bonuses: key = StatModifier.StatType enum value (int), value = bonus amount
@export var stat_bonuses: Dictionary = {}

# Special effect hook name (for non-stat perks like "undying", "ghost", etc.)
@export var special_effect: String = ""

# For percent-based bonuses vs flat
@export var is_percent: bool = false
