class_name ItemPool
extends RefCounted

# All loaded items grouped by rarity
var _items_by_rarity: Dictionary = {}  # rarity int -> Array[EquipmentItem]
var _all_items: Array[EquipmentItem] = []
var _loaded: bool = false

# Price tiers for area-based filtering (updated for 2.5x price scale)
# Items with buy_price in [min, max] are eligible for that tier
# These map to base_difficulty from biome definitions
const PRICE_TIERS = {
	0: [0, 100],       # starter areas (Aria floors 1-3) — tightened from 250
	5: [0, 500],       # mid-low (Aria Crypt, upper Aria)
	8: [50, 800],      # mid (Graveyard Dungeon)
	15: [100, 1500],   # mid-high (Farm Dungeon)
	25: [200, 3500],   # endgame (Wilderness, Hidden Forest)
}

# Max ATTACK_DAMAGE flat_bonus allowed per difficulty tier
const DAMAGE_CAPS = {
	0: 4,
	5: 8,
	8: 12,
	15: 20,
	25: 999,
}

func _init() -> void:
	_load_all_items()

func _load_all_items() -> void:
	if _loaded:
		return
	_loaded = true

	for path in ResourceRegistry.items_loy():
		var item = load(path) as EquipmentItem
		if item:
			_all_items.append(item)
			if not _items_by_rarity.has(item.rarity):
				_items_by_rarity[item.rarity] = []
			_items_by_rarity[item.rarity].append(item)

	print("ItemPool: loaded %d items (%d common, %d uncommon, %d rare)" % [
		_all_items.size(),
		_items_by_rarity.get(0, []).size(),
		_items_by_rarity.get(1, []).size(),
		_items_by_rarity.get(2, []).size(),
	])

func _get_price_range(base_difficulty: int) -> Vector2i:
	# Find the closest tier at or below the given difficulty
	var best_tier = 0
	for tier in PRICE_TIERS:
		if tier <= base_difficulty and tier >= best_tier:
			best_tier = tier
	var range_arr: Array = PRICE_TIERS[best_tier]
	return Vector2i(range_arr[0], range_arr[1])

func _filter_by_price(items: Array, price_range: Vector2i) -> Array:
	var filtered: Array = []
	for item in items:
		var ei := item as EquipmentItem
		if not ei:
			continue
		var price := ei.buy_price if ei.buy_price > 0 else 15
		if price >= price_range.x and price <= price_range.y:
			filtered.append(ei)
	# Always return at least the original list if filter is too aggressive
	if filtered.size() == 0:
		return items
	return filtered

func _get_damage_cap(base_difficulty: int) -> int:
	var best_tier = 0
	for tier in DAMAGE_CAPS:
		if tier <= base_difficulty and tier >= best_tier:
			best_tier = tier
	return DAMAGE_CAPS[best_tier]

func _filter_by_damage_cap(items: Array, cap: int) -> Array:
	if cap >= 999:
		return items
	var filtered: Array = []
	for item in items:
		var ei := item as EquipmentItem
		if not ei:
			continue
		var dominated = false
		for mod in ei.modifiers:
			if mod.stat == StatModifier.StatType.ATTACK_DAMAGE and mod.flat_bonus > cap:
				dominated = true
				break
		if not dominated:
			filtered.append(ei)
	if filtered.size() == 0:
		return items
	return filtered

func _filter_equipment_only(items: Array) -> Array:
	var filtered: Array = []
	for item in items:
		var ei := item as EquipmentItem
		if not ei:
			continue
		# Only weapons, armor, accessories — not consumables/materials
		if ei.slot_type <= EquipmentItem.SlotType.CLOAK:
			filtered.append(ei)
	if filtered.size() == 0:
		return items
	return filtered

func get_random_items(count: int, floor_num: int, base_difficulty: int = 0) -> Array[EquipmentItem]:
	if _all_items.size() == 0:
		return []

	var result: Array[EquipmentItem] = []
	var price_range = _get_price_range(base_difficulty)
	var dmg_cap = _get_damage_cap(base_difficulty)
	var effective = floor_num + base_difficulty

	for _i in range(count):
		var rarity_roll = randf()
		var target_rarity: int
		if rarity_roll < 0.02 + effective * 0.005:
			target_rarity = 2
		elif rarity_roll < 0.15 + effective * 0.02:
			target_rarity = 1
		else:
			target_rarity = 0

		var pool: Array = _items_by_rarity.get(target_rarity, [])
		if pool.size() == 0:
			pool = _all_items
		# Filter pool by area price tier and damage cap
		pool = _filter_by_price(pool, price_range)
		pool = _filter_by_damage_cap(pool, dmg_cap)
		result.append(pool[randi() % pool.size()])

	return result

func get_random_equipment(count: int, floor_num: int, base_difficulty: int = 0) -> Array[EquipmentItem]:
	"""Like get_random_items but only returns equipment (no consumables/materials)."""
	if _all_items.size() == 0:
		return []

	var result: Array[EquipmentItem] = []
	var price_range = _get_price_range(base_difficulty)
	var dmg_cap = _get_damage_cap(base_difficulty)
	var effective = floor_num + base_difficulty

	for _i in range(count):
		var rarity_roll = randf()
		var target_rarity: int
		if rarity_roll < 0.03 + effective * 0.008:
			target_rarity = 2
		elif rarity_roll < 0.20 + effective * 0.025:
			target_rarity = 1
		else:
			target_rarity = 0

		var pool: Array = _items_by_rarity.get(target_rarity, [])
		if pool.size() == 0:
			pool = _all_items
		pool = _filter_by_price(pool, price_range)
		pool = _filter_by_damage_cap(pool, dmg_cap)
		pool = _filter_equipment_only(pool)
		result.append(pool[randi() % pool.size()])

	return result

func get_boss_items(count: int, floor_num: int, base_difficulty: int = 0) -> Array[EquipmentItem]:
	"""Boss drops: higher rarity, equipment only, can reach 1-2 tiers above current area."""
	if _all_items.size() == 0:
		return []

	# Boss loot extends price range upward by 80% (can drop next-tier gear)
	var result: Array[EquipmentItem] = []
	var price_range = _get_price_range(base_difficulty)
	price_range.y = int(price_range.y * 1.8)
	var dmg_cap = _get_damage_cap(base_difficulty)
	var effective = floor_num + base_difficulty

	for _i in range(count):
		var rarity_roll = randf()
		var target_rarity: int
		# Bosses have much better rarity: ~15-25% rare, ~40-50% uncommon
		if rarity_roll < 0.10 + effective * 0.01:
			target_rarity = 2
		elif rarity_roll < 0.50 + effective * 0.02:
			target_rarity = 1
		else:
			target_rarity = 0

		var pool: Array = _items_by_rarity.get(target_rarity, [])
		if pool.size() == 0:
			pool = _all_items
		pool = _filter_by_price(pool, price_range)
		pool = _filter_by_damage_cap(pool, dmg_cap)
		pool = _filter_equipment_only(pool)
		result.append(pool[randi() % pool.size()])

	return result

func get_shop_items(count: int, base_difficulty: int, shop_type: String = "") -> Array[EquipmentItem]:
	var result: Array[EquipmentItem] = []
	if _all_items.size() == 0:
		return result

	var price_range = _get_price_range(base_difficulty)
	# Shops get slightly better items — extend range up by 50%
	price_range.y = int(price_range.y * 1.5)

	# Filter by slot type based on shop_type
	var allowed_slots: Array = []
	match shop_type:
		"weapon":
			allowed_slots = [
				EquipmentItem.SlotType.WEAPON_MELEE,
				EquipmentItem.SlotType.WEAPON_RANGED,
				EquipmentItem.SlotType.WEAPON_MAGIC,
				EquipmentItem.SlotType.HELM,
				EquipmentItem.SlotType.BODY,
				EquipmentItem.SlotType.SHIELD,
				EquipmentItem.SlotType.BOOTS,
				EquipmentItem.SlotType.GLOVES,
				EquipmentItem.SlotType.CLOAK,
			]
		"magic":
			allowed_slots = [
				EquipmentItem.SlotType.WEAPON_MAGIC,
				EquipmentItem.SlotType.RING,
				EquipmentItem.SlotType.CLOAK,
				EquipmentItem.SlotType.CONSUMABLE,
			]
		"inn":
			allowed_slots = [
				EquipmentItem.SlotType.CONSUMABLE,
				EquipmentItem.SlotType.MATERIAL,
			]
		_:
			allowed_slots = []

	var candidates: Array = []
	for item in _all_items:
		var ei = item as EquipmentItem
		if not ei:
			continue
		var price = ei.buy_price if ei.buy_price > 0 else 15
		if price < price_range.x or price > price_range.y:
			continue
		if allowed_slots.size() > 0 and ei.slot_type not in allowed_slots:
			continue
		candidates.append(ei)

	if candidates.size() == 0:
		candidates = _filter_by_price(_all_items, price_range)

	candidates.shuffle()
	for i in range(mini(count, candidates.size())):
		result.append(candidates[i])

	return result

const CRAFTING_TIERS = {
	# floor_min -> array of crafting material item_names
	0: ["Healing Herb", "Swamp Root", "Leather Scraps"],
	4: ["Iron Ore", "Wild Mushroom", "Bone Dust", "Feather"],
	8: ["Fire Crystal", "Magic Essence", "Venom Sac", "Cave Crystal", "Demon Shard", "Ancient Bark"],
}

func get_crafting_material(floor_num: int) -> EquipmentItem:
	# Build pool from all unlocked tiers
	var pool: Array[String] = []
	for tier_floor in CRAFTING_TIERS:
		if floor_num >= tier_floor:
			pool.append_array(CRAFTING_TIERS[tier_floor])
	if pool.size() == 0:
		pool = CRAFTING_TIERS[0]
	var mat_name = pool[randi() % pool.size()]
	var safe = mat_name.to_lower().replace(" ", "_")
	var path = "res://resources/items/crafting/" + safe + ".tres"
	if ResourceLoader.exists(path):
		return load(path) as EquipmentItem
	return null

func create_drop_table(floor_num: int, is_elite: bool, base_difficulty: int = 0) -> DropTable:
	var dt = DropTable.new()
	dt.drop_chance = clampf(0.20 + floor_num * 0.015, 0.20, 0.50)
	if is_elite:
		dt.drop_chance = 0.60

	# Normal enemies get 6 random items in their pool (mix of equipment + consumables)
	var items = get_random_items(6, floor_num, base_difficulty)
	for item in items:
		var entry = DropEntry.new()
		entry.item = item
		match item.rarity:
			0: entry.weight = 10.0
			1: entry.weight = 3.0
			2: entry.weight = 1.0
		dt.entries.append(entry)

	return dt

func create_boss_drop_table(floor_num: int, base_difficulty: int = 0) -> DropTable:
	"""Create a rich drop table for boss enemies — guaranteed drops, better rarity."""
	var dt = DropTable.new()
	dt.drop_chance = 1.0  # Bosses always drop

	# Boss gets 8 equipment items with boosted rarity and next-tier access
	var items = get_boss_items(8, floor_num, base_difficulty)
	for item in items:
		var entry = DropEntry.new()
		entry.item = item
		# Flip weights: rare items MORE likely from bosses
		match item.rarity:
			0: entry.weight = 3.0
			1: entry.weight = 6.0
			2: entry.weight = 4.0
		dt.entries.append(entry)

	return dt

func create_elite_drop_table(floor_num: int, base_difficulty: int = 0) -> DropTable:
	"""Create a better drop table for elite enemies — better items than normals."""
	var dt = DropTable.new()
	dt.drop_chance = 0.70  # 70% drop chance

	# Elites get 6 equipment-only items with slightly boosted rarity
	var items = get_random_equipment(6, floor_num, base_difficulty)
	for item in items:
		var entry = DropEntry.new()
		entry.item = item
		match item.rarity:
			0: entry.weight = 6.0
			1: entry.weight = 5.0
			2: entry.weight = 2.0
		dt.entries.append(entry)

	return dt
