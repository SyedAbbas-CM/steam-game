class_name EquipmentItem
extends Resource

enum SlotType {
	WEAPON_MELEE,   # 0 - swords, axes, daggers, spears, clubs
	WEAPON_RANGED,  # 1 - bows, crossbows
	WEAPON_MAGIC,   # 2 - staves, wands, books, sceptres
	HELM,           # 3 - helmets, hoods, crowns
	BODY,           # 4 - armor, robes, chainmail
	SHIELD,         # 5 - shields, bucklers
	BOOTS,          # 6 - boots, sandals, slippers
	GLOVES,         # 7 - gloves, gauntlets, bracers
	RING,           # 8 - rings, bands, amulets
	CLOAK,          # 9 - cloaks, capes
	CONSUMABLE,     # 10 - potions, food
	MATERIAL,       # 11 - crafting, misc
	AMMO,           # 12 - arrows with limited quantity
}

# Helpers
static func is_weapon_slot(slot: SlotType) -> bool:
	return slot == SlotType.WEAPON_MELEE or slot == SlotType.WEAPON_RANGED or slot == SlotType.WEAPON_MAGIC

static func is_equippable(slot: SlotType) -> bool:
	return slot != SlotType.CONSUMABLE and slot != SlotType.MATERIAL

@export var item_name: String = "Unknown Item"
@export var description: String = ""
@export var icon: Texture2D
@export var slot_type: SlotType = SlotType.MATERIAL
@export var modifiers: Array[StatModifier] = []
@export var bullet_modifiers: Array[BulletModifier] = []
@export var rarity: int = 0  # 0=common, 1=uncommon, 2=rare
@export var buy_price: int = 0
@export var sell_value: int = 0
@export var enchantment: ItemEnchantment
@export var loy_tile_index: int = -1  # index into tiles.png (32x32 tiles, 16x16 grid) for item icon
@export var bullet_sprite_index: int = -1  # index into lofi_obj.png (8x8 tiles, 16x16 grid). -1 = default
@export var weapon_range: float = 0.0  # effective range override (0 = use default bullet_lifetime)
@export var weapon_type: String = ""  # sword, dagger, axe, club, hammer, flail, spear, throwing, bow, short_bow, crossbow, staff

# Tracks original .tres path for save/load (set when duplicating)
var source_path: String = ""

@export_group("Ability")
@export var ability_id: String = ""  # e.g., "shield_bash", "arrow_rain", "frost_nova"
@export var ability_mp_cost: float = 0.0
@export var ability_cooldown: float = 5.0

@export_group("Spell")
@export var grants_spell: String = ""  # spell_id granted while this item is equipped

@export_group("Consumable")
@export var heal_hp: int = 0
@export var heal_mp: int = 0
@export var use_effect: String = ""  # special effect: "town_portal", etc.

@export_group("Requirements")
@export var required_level: int = 0
@export var required_classes: Array[String] = []
@export var required_stats: Dictionary = {}

@export_group("Ammo")
@export var quantity: int = 0  # current ammo count (0 = not ammo / infinite)
@export var max_quantity: int = 0  # max stack size
@export var arrow_effect: String = ""  # "fire", "freeze", "explosion", "poison", "lightning", "slow"

## Create a copy that remembers its original .tres path for save/load
func make_copy() -> EquipmentItem:
	var copy = duplicate() as EquipmentItem
	copy.source_path = resource_path if resource_path != "" else source_path
	return copy

func get_weapon_type() -> String:
	if weapon_type != "":
		return weapon_type
	match slot_type:
		SlotType.WEAPON_MELEE: return "sword"
		SlotType.WEAPON_RANGED: return "bow"
		SlotType.WEAPON_MAGIC: return "staff"
	return ""

func get_scaling_stat() -> String:
	match weapon_type:
		"sword", "axe", "hammer", "club", "flail", "spear", "dagger", "halberd", "greatsword", "great_axe", "scythe":
			return "power"
		"bow", "short_bow", "crossbow", "throwing", "javelin", "sling", "whip", "claws":
			return "agility"
		"staff", "wand", "tome":
			return "spirit"
	return ""

func get_display_name() -> String:
	if enchantment:
		return enchantment.get_prefix() + " " + item_name
	return item_name

## Auto-generate stat requirements based on rarity + weapon scaling stat
## Common (0): no req. Uncommon (1): 3. Rare (2): 7. Epic/Legendary (3+): 12.

func get_effective_stat_requirements() -> Dictionary:
	# Explicit required_stats always take priority
	if required_stats.size() > 0:
		return required_stats
	# Auto-generate from rarity + weapon scaling stat
	var scaling = get_scaling_stat()
	if scaling == "" or rarity <= 0:
		return {}
	var needed := 0
	match rarity:
		1: needed = 3
		2: needed = 7
		_: needed = 12  # rarity 3+
	return {scaling: needed}

func can_equip(_player_class: String, player_level: int, allocated: Dictionary) -> bool:
	if required_level > 0 and player_level < required_level:
		return false
	var reqs = get_effective_stat_requirements()
	for stat_name in reqs:
		var needed = reqs[stat_name] as int
		var have = allocated.get(stat_name, 0) as int
		if have < needed:
			return false
	return true

func get_unmet_requirements(_player_class: String, player_level: int, allocated: Dictionary) -> Array[String]:
	var unmet: Array[String] = []
	if required_level > 0 and player_level < required_level:
		unmet.append("Requires Level %d" % required_level)
	var reqs = get_effective_stat_requirements()
	for stat_name in reqs:
		var needed = reqs[stat_name] as int
		var have = allocated.get(stat_name, 0) as int
		if have < needed:
			unmet.append("Requires %d %s (%d)" % [needed, stat_name.capitalize(), have])
	return unmet
