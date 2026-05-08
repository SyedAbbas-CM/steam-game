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
@export var archetype_tags: PackedStringArray = PackedStringArray()
@export var blueprint_id: String = ""
@export var salvage_research_family: String = ""
@export var socket_count: int = 0
@export var socket_types: PackedStringArray = PackedStringArray()
@export var socketed_gem_paths: PackedStringArray = PackedStringArray()

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
	copy._randomize_sockets()
	return copy

static func _roll_random_socket_count() -> int:
	# 80% chance of 0 sockets
	if randf() < 0.80:
		return 0
	# Geometric distribution: 60% stop, 40% add another
	# 1 socket: ~12% overall, 2: ~4.8%, 3: ~1.9%, 4+: <1%
	var count := 1
	while randf() < 0.4:
		count += 1
	return count

func _randomize_sockets() -> void:
	# Only equippable gear gets random sockets (not consumables, materials, ammo)
	if not EquipmentItem.is_equippable(slot_type) or slot_type == SlotType.AMMO:
		socket_count = 0
		_normalize_sockets()
		return
	socket_count = EquipmentItem._roll_random_socket_count()
	socket_types = PackedStringArray()
	socketed_gem_paths = PackedStringArray()
	_normalize_sockets()

func _normalize_sockets() -> void:
	socket_count = maxi(socket_count, 0)
	while socket_types.size() < socket_count:
		socket_types.append("open")
	if socket_types.size() > socket_count:
		socket_types = PackedStringArray(Array(socket_types).slice(0, socket_count))
	while socketed_gem_paths.size() < socket_count:
		socketed_gem_paths.append("")
	if socketed_gem_paths.size() > socket_count:
		socketed_gem_paths = PackedStringArray(Array(socketed_gem_paths).slice(0, socket_count))

func get_effective_tags() -> PackedStringArray:
	return archetype_tags

func get_item_instance_state() -> Dictionary:
	_normalize_sockets()
	return {
		"socket_count": socket_count,
		"socket_types": Array(socket_types),
		"socketed_gem_paths": Array(socketed_gem_paths),
	}

func apply_item_instance_state(state: Dictionary) -> void:
	if state.has("socket_count"):
		socket_count = maxi(int(state["socket_count"]), 0)
	if state.has("socket_types"):
		socket_types = PackedStringArray(state["socket_types"])
	if state.has("socketed_gem_paths"):
		socketed_gem_paths = PackedStringArray(state["socketed_gem_paths"])
	_normalize_sockets()

func has_socketed_gems() -> bool:
	for gem_path in socketed_gem_paths:
		if gem_path != "":
			return true
	return false

func get_socketed_gem_count() -> int:
	var total := 0
	for gem_path in socketed_gem_paths:
		if gem_path != "":
			total += 1
	return total

func get_socketed_gems() -> Array[GemDefinition]:
	var gems: Array[GemDefinition] = []
	for gem_path in socketed_gem_paths:
		if gem_path == "":
			continue
		var gem = load(gem_path) as GemDefinition
		if gem:
			gems.append(gem)
	return gems

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
