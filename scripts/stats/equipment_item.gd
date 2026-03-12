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
	MATERIAL,       # 11 - crafting, arrows, misc
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

@export_group("Ability")
@export var ability_id: String = ""  # e.g., "shield_bash", "arrow_rain", "frost_nova"
@export var ability_mp_cost: float = 0.0
@export var ability_cooldown: float = 5.0

func get_display_name() -> String:
	if enchantment:
		return enchantment.get_prefix() + " " + item_name
	return item_name
