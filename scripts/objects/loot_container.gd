class_name LootContainer
extends TestChest

## Searchable environmental container — barrels, crates, sacks.
## Subclasses TestChest so it works with the existing chest UI, but draws
## a different sprite per type and pre-populates with a small random loot pool.

enum ContainerType { BARREL, CRATE, SACK }

@export var container_type: ContainerType = ContainerType.BARREL

# Loot tables per container type. Picked at spawn time before _ready overrides
# the sprite. Each entry: [item_name, weight, min_qty, max_qty].
const BARREL_LOOT := [
	["Red Potion", 5, 1, 1],
	["Blue Potion", 3, 1, 1],
	["Apple", 4, 1, 2],
	["Gold", 6, 3, 12],
	["Stamina Potion", 2, 1, 1],
	["Throwing Knives", 1, 1, 1],
]
const CRATE_LOOT := [
	["Dagger", 2, 1, 1],
	["Wooden Buckler", 1, 1, 1],
	["Leather Helmet", 2, 1, 1],
	["Boots", 1, 1, 1],
	["Red Potion", 3, 1, 1],
	["Gold", 4, 5, 20],
	["Scroll of Heal", 1, 1, 1],
	["Attack Elixir", 1, 1, 1],
	["Defence Elixir", 1, 1, 1],
]
const SACK_LOOT := [
	["Gold", 8, 5, 30],
	["Apple", 3, 1, 3],
	["Red Potion", 3, 1, 2],
	["Blue Potion", 2, 1, 1],
	["Mana Potion", 1, 1, 1],
]

func _ready() -> void:
	# Force the dungeon scale meta if our parent set it (or auto-detect via _dm).
	if not has_meta("dungeon_scale"):
		set_meta("dungeon_scale", true)
	# Skip the base chest sprite — we'll draw our own — by clearing the parent ready,
	# but Godot doesn't allow that. Instead let TestChest._ready() run, then immediately
	# replace its sprite below.
	super()
	_replace_chest_sprite()
	_set_container_label()

func _replace_chest_sprite() -> void:
	# Find and remove the TestChest sprite
	for child in get_children():
		if child is Sprite2D:
			child.queue_free()
			break
	# Draw our own per-type sprite
	var sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var img: Image
	match container_type:
		ContainerType.BARREL:
			img = _make_barrel_image()
		ContainerType.CRATE:
			img = _make_crate_image()
		ContainerType.SACK:
			img = _make_sack_image()
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.scale = Vector2(0.75, 0.75)  # dungeon scale (8px tiles)
	add_child(sprite)

func _set_container_label() -> void:
	match container_type:
		ContainerType.BARREL: chest_label = "Barrel"
		ContainerType.CRATE: chest_label = "Crate"
		ContainerType.SACK: chest_label = "Sack"
	if _prompt:
		_prompt.text = "[E] " + chest_label

func _make_barrel_image() -> Image:
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	# Wood body (rounded barrel)
	for x in range(2, 12):
		for y in range(1, 13):
			# Round the corners
			if (x <= 3 or x >= 10) and (y <= 1 or y >= 12):
				continue
			img.set_pixel(x, y, Color(0.55, 0.32, 0.12))
	# Wood plank vertical lines
	for y in range(2, 12):
		img.set_pixel(5, y, Color(0.45, 0.24, 0.08))
		img.set_pixel(8, y, Color(0.45, 0.24, 0.08))
	# Metal rings (top and bottom)
	for x in range(2, 12):
		img.set_pixel(x, 3, Color(0.55, 0.55, 0.55))
		img.set_pixel(x, 10, Color(0.55, 0.55, 0.55))
	# Top lid
	for x in range(3, 11):
		img.set_pixel(x, 1, Color(0.4, 0.22, 0.08))
	return img

func _make_crate_image() -> Image:
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	# Box body
	for x in range(1, 13):
		for y in range(2, 13):
			img.set_pixel(x, y, Color(0.55, 0.38, 0.18))
	# Outer border
	for x in range(1, 13):
		img.set_pixel(x, 2, Color(0.32, 0.20, 0.08))
		img.set_pixel(x, 12, Color(0.32, 0.20, 0.08))
	for y in range(2, 13):
		img.set_pixel(1, y, Color(0.32, 0.20, 0.08))
		img.set_pixel(12, y, Color(0.32, 0.20, 0.08))
	# X-cross brace
	for i in range(3, 11):
		img.set_pixel(i, i - 1, Color(0.38, 0.24, 0.10))
		img.set_pixel(13 - i, i - 1, Color(0.38, 0.24, 0.10))
	return img

func _make_sack_image() -> Image:
	var img := Image.create(12, 14, false, Image.FORMAT_RGBA8)
	# Sack body (rounded burlap)
	for x in range(1, 11):
		for y in range(4, 13):
			# Bottom round
			if y >= 12 and (x <= 1 or x >= 10):
				continue
			img.set_pixel(x, y, Color(0.65, 0.55, 0.35))
	# Neck (narrow top)
	for x in range(4, 8):
		for y in range(1, 4):
			img.set_pixel(x, y, Color(0.55, 0.45, 0.28))
	# Drawstring
	for x in range(3, 9):
		img.set_pixel(x, 4, Color(0.38, 0.30, 0.18))
	# Texture dots
	for i in range(3, 10, 2):
		img.set_pixel(i, 8, Color(0.50, 0.42, 0.25))
		img.set_pixel(i, 10, Color(0.50, 0.42, 0.25))
	return img

## Static factory: builds a LootContainer with random items rolled from its loot table.
static func create_loot_container(c_type: ContainerType, dungeon_scale: bool = true) -> LootContainer:
	var container = LootContainer.new()
	container.container_type = c_type
	if dungeon_scale:
		container.set_meta("dungeon_scale", true)
	# Roll 1-3 items from the type's loot table
	var table = BARREL_LOOT
	match c_type:
		ContainerType.CRATE: table = CRATE_LOOT
		ContainerType.SACK: table = SACK_LOOT
	var item_count = randi_range(1, 3)
	var total_weight := 0
	for entry in table:
		total_weight += int(entry[1])
	for _i in range(item_count):
		var roll = randi() % total_weight
		var acc := 0
		for entry in table:
			acc += int(entry[1])
			if roll < acc:
				var item_name: String = String(entry[0])
				var qty = randi_range(int(entry[2]), int(entry[3]))
				_grant_item(container, item_name, qty)
				break
	return container

static func _grant_item(container: LootContainer, item_name: String, qty: int) -> void:
	if item_name == "Gold":
		var current_gold = int(container.get_meta("gold_reward", 0))
		container.set_meta("gold_reward", current_gold + qty)
		return
	# Lookup priority: QuestManager item-name cache → slug-based path search in
	# loy/ and scrolls/ (scrolls aren't in the QuestManager cache).
	var path: String = ""
	var qm = container.get_node_or_null("/root/QuestManager")
	if qm and "_item_cache" in qm and qm._item_cache.has(item_name):
		path = String(qm._item_cache[item_name])
	else:
		var slug = item_name.to_lower().replace(" ", "_")
		var candidates = [
			"res://resources/items/loy/" + slug + ".tres",
			"res://resources/items/scrolls/" + slug + ".tres",
			"res://resources/items/loy/" + slug.replace("_of_", "_") + ".tres",
			"res://resources/items/scrolls/" + slug.replace("_of_", "_") + ".tres",
		]
		for cand in candidates:
			if ResourceLoader.exists(cand):
				path = cand
				break
	if path == "":
		return
	var base = load(path) as EquipmentItem
	if not base:
		return
	for _i in range(qty):
		container.items.append(base.make_copy())
