class_name ItemIconHelper
extends RefCounted

## Maps EquipmentItem → AtlasTexture from items_master.png using loy_tile_index.
##
## items_master.png is the single consolidated 16-wide sprite sheet built by
## tools/migrate_to_master_sheet.py. tiles.png + tiles2.png are no longer
## referenced for item icons — every item's loy_tile_index points into this
## master sheet, grouped by slot type (see tools/items_master_layout.md).

const COLS := 16
const TILE_PX := 32

static var _master_tex: Texture2D

static func _ensure_textures() -> void:
	if not _master_tex:
		_master_tex = load("res://assets/sprites/items_master.png") as Texture2D

## Get an AtlasTexture for the item's icon from the master sheet.
static func get_icon_texture(item: EquipmentItem) -> Texture2D:
	if not item or item.loy_tile_index < 0:
		return null
	_ensure_textures()
	if not _master_tex:
		return null
	var idx: int = item.loy_tile_index
	var col: int = idx % COLS
	var row: int = idx / COLS
	var atlas := AtlasTexture.new()
	atlas.atlas = _master_tex
	atlas.region = Rect2(col * TILE_PX, row * TILE_PX, TILE_PX, TILE_PX)
	return atlas

## Get the loy_tile_index (for compatibility)
static func get_sprite_index(item: EquipmentItem) -> int:
	if not item:
		return -1
	return item.loy_tile_index

## Get a default icon texture for an empty equip slot. Indices are now the
## first cell of each slot's section in the master sheet (see migration tool).
static func get_slot_icon_texture(slot: EquipmentItem.SlotType) -> Texture2D:
	_ensure_textures()
	var idx: int = _slot_default_tile(slot)
	if idx < 0 or not _master_tex:
		return null
	var col: int = idx % COLS
	var row: int = idx / COLS
	var atlas := AtlasTexture.new()
	atlas.atlas = _master_tex
	atlas.region = Rect2(col * TILE_PX, row * TILE_PX, TILE_PX, TILE_PX)
	return atlas

static func _slot_default_tile(slot: EquipmentItem.SlotType) -> int:
	match slot:
		EquipmentItem.SlotType.WEAPON_MELEE: return 0
		EquipmentItem.SlotType.WEAPON_RANGED: return 256
		EquipmentItem.SlotType.WEAPON_MAGIC: return 400
		EquipmentItem.SlotType.HELM: return 544
		EquipmentItem.SlotType.BODY: return 672
		EquipmentItem.SlotType.SHIELD: return 816
		EquipmentItem.SlotType.BOOTS: return 928
		EquipmentItem.SlotType.GLOVES: return 1040
		EquipmentItem.SlotType.RING: return 1152
		EquipmentItem.SlotType.CLOAK: return 1264
		EquipmentItem.SlotType.CONSUMABLE: return 1376
		EquipmentItem.SlotType.MATERIAL: return 1520
		EquipmentItem.SlotType.AMMO: return 1632
	return -1

static func get_slot_name(slot: EquipmentItem.SlotType) -> String:
	match slot:
		EquipmentItem.SlotType.WEAPON_MELEE: return "Melee"
		EquipmentItem.SlotType.WEAPON_RANGED: return "Ranged"
		EquipmentItem.SlotType.WEAPON_MAGIC: return "Magic"
		EquipmentItem.SlotType.HELM: return "Helm"
		EquipmentItem.SlotType.BODY: return "Body"
		EquipmentItem.SlotType.SHIELD: return "Shield"
		EquipmentItem.SlotType.BOOTS: return "Boots"
		EquipmentItem.SlotType.GLOVES: return "Gloves"
		EquipmentItem.SlotType.RING: return "Ring"
		EquipmentItem.SlotType.CLOAK: return "Cloak"
		EquipmentItem.SlotType.CONSUMABLE: return "Use"
		EquipmentItem.SlotType.MATERIAL: return "Mat"
	return "?"
