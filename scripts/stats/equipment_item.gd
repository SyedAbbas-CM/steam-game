class_name EquipmentItem
extends Resource

enum SlotType { WEAPON, ARMOR, ACCESSORY, CONSUMABLE, MATERIAL }

@export var item_name: String = "Unknown Item"
@export var description: String = ""
@export var icon: Texture2D
@export var slot_type: SlotType = SlotType.MATERIAL
@export var modifiers: Array[StatModifier] = []
@export var bullet_modifiers: Array[BulletModifier] = []
@export var rarity: int = 0  # 0=common, 1=uncommon, 2=rare
