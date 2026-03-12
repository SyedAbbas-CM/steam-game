class_name ItemIconHelper
extends RefCounted

## Maps EquipmentItem → AtlasTexture from tiles.png/tiles2.png using loy_tile_index

static var _tiles_tex: Texture2D
static var _tiles2_tex: Texture2D

static func _ensure_textures() -> void:
	if not _tiles_tex:
		_tiles_tex = load("res://assets/sprites/loy/tiles.png") as Texture2D
	if not _tiles2_tex:
		_tiles2_tex = load("res://assets/sprites/loy/tiles2.png") as Texture2D

## Get an AtlasTexture for the item's icon from tiles.png
static func get_icon_texture(item: EquipmentItem) -> Texture2D:
	if not item or item.loy_tile_index < 0:
		return null
	_ensure_textures()
	var idx = item.loy_tile_index
	var tex = _tiles_tex if idx < 256 else _tiles2_tex
	if not tex:
		return null
	idx = idx % 256
	var col = idx % 16
	var row = idx / 16
	var atlas = AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(col * 32, row * 32, 32, 32)
	return atlas

## Get the loy_tile_index (for compatibility)
static func get_sprite_index(item: EquipmentItem) -> int:
	if not item:
		return -1
	return item.loy_tile_index

## Get a default icon texture for an empty equip slot
static func get_slot_icon_texture(slot: EquipmentItem.SlotType) -> Texture2D:
	_ensure_textures()
	var idx = _slot_default_tile(slot)
	if idx < 0 or not _tiles_tex:
		return null
	var col = idx % 16
	var row = idx / 16
	var atlas = AtlasTexture.new()
	atlas.atlas = _tiles_tex
	atlas.region = Rect2(col * 32, row * 32, 32, 32)
	return atlas

static func _slot_default_tile(slot: EquipmentItem.SlotType) -> int:
	match slot:
		EquipmentItem.SlotType.WEAPON_MELEE: return 86   # sword
		EquipmentItem.SlotType.WEAPON_RANGED: return 90   # bow
		EquipmentItem.SlotType.WEAPON_MAGIC: return 94    # staff
		EquipmentItem.SlotType.HELM: return 140            # leather helmet
		EquipmentItem.SlotType.BODY: return 165            # leather armor
		EquipmentItem.SlotType.SHIELD: return 128          # shield
		EquipmentItem.SlotType.BOOTS: return 176           # boots
		EquipmentItem.SlotType.GLOVES: return 181          # gloves
		EquipmentItem.SlotType.RING: return 145            # ring
		EquipmentItem.SlotType.CLOAK: return 129           # cloak
		EquipmentItem.SlotType.CONSUMABLE: return 80       # potion
		EquipmentItem.SlotType.MATERIAL: return 160        # gem
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
