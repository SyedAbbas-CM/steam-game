class_name ItemPool
extends RefCounted

# All loaded items grouped by rarity
var _items_by_rarity: Dictionary = {}  # rarity int -> Array[EquipmentItem]
var _all_items: Array[EquipmentItem] = []
var _loaded: bool = false

# Price tiers for area-based filtering
# Items with buy_price in [min, max] are eligible for that tier
const PRICE_TIERS = {
	0: [0, 100],      # starter areas (Aria)
	5: [0, 200],      # mid-low (Aria Crypt)
	8: [0, 300],      # mid (Graveyard)
	15: [50, 500],    # mid-high
	25: [100, 716],   # endgame
}

func _init() -> void:
	_load_all_items()

func _load_all_items() -> void:
	if _loaded:
		return
	_loaded = true

	var dir = DirAccess.open("res://resources/items/loy/")
	if not dir:
		push_warning("ItemPool: cannot open items directory")
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var item = load("res://resources/items/loy/" + file_name) as EquipmentItem
			if item:
				_all_items.append(item)
				if not _items_by_rarity.has(item.rarity):
					_items_by_rarity[item.rarity] = []
				_items_by_rarity[item.rarity].append(item)
		file_name = dir.get_next()

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
	var range_arr = PRICE_TIERS[best_tier]
	return Vector2i(range_arr[0], range_arr[1])

func _filter_by_price(items: Array, price_range: Vector2i) -> Array:
	var filtered: Array = []
	for item in items:
		var ei = item as EquipmentItem
		if not ei:
			continue
		var price = ei.buy_price if ei.buy_price > 0 else 15
		if price >= price_range.x and price <= price_range.y:
			filtered.append(ei)
	# Always return at least the original list if filter is too aggressive
	if filtered.size() == 0:
		return items
	return filtered

func get_random_items(count: int, floor_num: int, base_difficulty: int = 0) -> Array[EquipmentItem]:
	var result: Array[EquipmentItem] = []
	if _all_items.size() == 0:
		return result

	var price_range = _get_price_range(base_difficulty)
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

		var pool = _items_by_rarity.get(target_rarity, []) as Array
		if pool.size() == 0:
			pool = _all_items
		# Filter pool by area price tier
		pool = _filter_by_price(pool, price_range)
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

func create_drop_table(floor_num: int, is_elite: bool, base_difficulty: int = 0) -> DropTable:
	var dt = DropTable.new()
	dt.drop_chance = clampf(0.15 + floor_num * 0.01, 0.15, 0.40)
	if is_elite:
		dt.drop_chance = 0.50

	var items = get_random_items(4, floor_num, base_difficulty)
	for item in items:
		var entry = DropEntry.new()
		entry.item = item
		match item.rarity:
			0: entry.weight = 10.0
			1: entry.weight = 3.0
			2: entry.weight = 1.0
		dt.entries.append(entry)

	return dt
