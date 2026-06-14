class_name LootContainer
extends TestChest

## Searchable environmental container — uses the actual dungeon-features atlas
## sprites so it reads as a normal decoration barrel/crate/sack/chest/wardrobe.
## Subclasses TestChest so it works with the existing chest UI, and
## pre-populates with a small random loot pool per type.

const FEATURES_TEX := preload("res://assets/sprites/lofi_dungeon_features.png")

enum ContainerType { BARREL, CRATE, SACK, CHEST, WARDROBE }

# Atlas coords on lofi_dungeon_features.png (12x9 grid, 8 px tiles) — matches
# the existing DECO_BARREL / DECO_CRATE / DECO_SACKS / DECO_CHEST / DECO_WARDROBE
# constants in deco_tiles.gd so spawned containers look identical to scenery.
const ATLAS_BY_TYPE := {
	ContainerType.BARREL: Vector2i(0, 0),
	ContainerType.CRATE: Vector2i(1, 0),
	ContainerType.SACK: Vector2i(4, 0),
	ContainerType.CHEST: Vector2i(2, 0),
	ContainerType.WARDROBE: Vector2i(7, 2),
}

@export var container_type: ContainerType = ContainerType.BARREL

# Loot tables per container type. Picked at spawn time before _ready overrides
# the sprite. Each entry: [item_name, weight, min_qty, max_qty].
const BARREL_LOOT := [
	["Red Potion", 4, 1, 2],
	["Blue Potion", 3, 1, 1],
	["Apple", 4, 1, 3],
	["Gold", 7, 12, 35],
	["Stamina Potion", 2, 1, 2],
	["Throwing Knives", 2, 1, 1],
]
const CRATE_LOOT := [
	["Dagger", 2, 1, 1],
	["Wooden Buckler", 1, 1, 1],
	["Leather Helmet", 2, 1, 1],
	["Boots", 1, 1, 1],
	["Short Sword", 2, 1, 1],
	["Red Potion", 3, 1, 2],
	["Gold", 5, 25, 60],
	["Scroll of Heal", 2, 1, 1],
	["Attack Elixir", 1, 1, 1],
	["Defence Elixir", 1, 1, 1],
]
const SACK_LOOT := [
	["Gold", 8, 25, 80],
	["Apple", 3, 1, 4],
	["Red Potion", 3, 1, 2],
	["Blue Potion", 2, 1, 2],
	["Mana Potion", 1, 1, 1],
	["Stamina Potion", 1, 1, 1],
]
const CHEST_LOOT := [
	["Gold", 4, 60, 180],
	["Red Potion", 2, 1, 2],
	["Blue Potion", 2, 1, 2],
	["Mana Potion", 1, 1, 1],
	["Scroll of Heal", 2, 1, 1],
	["Wooden Buckler", 1, 1, 1],
	["Leather Helmet", 1, 1, 1],
	["Short Sword", 2, 1, 1],
	["Dagger", 2, 1, 1],
	["Attack Elixir", 1, 1, 1],
]
const WARDROBE_LOOT := [
	["Leather Helmet", 3, 1, 1],
	["Boots", 2, 1, 1],
	["Apple", 2, 1, 2],
	["Gold", 4, 20, 50],
	["Wooden Buckler", 1, 1, 1],
]

## Per-container in-world quick popup state. Replaces the modal ChestUI.
const POPUP_CLOSE_DISTANCE_DUNGEON := 24.0
const POPUP_CLOSE_DISTANCE_OVERWORLD := 96.0
const MAX_SLOTS := 8
var _popup: Node2D = null


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


func _process(_delta: float) -> void:
	# Walk-away auto-close + open-on-E. Skips TestChest._process so we don't
	# trigger the old modal ChestUI alongside ours.
	if _popup:
		_update_popup_close()
		_poll_slot_click()
	if _player_nearby and Input.is_action_just_pressed("interact") and not _popup:
		_open_world_popup()


func _poll_slot_click() -> void:
	# Viewport physics_object_picking is off by default in Godot 4, so the
	# Area2D.input_event signal never fires for our slots. We hit-test the
	# mouse against each slot's local rect ourselves — far more reliable.
	if not is_instance_valid(_popup):
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_set_meta_safe("_mouse_was_down", false)
		return
	if get_meta("_mouse_was_down", false):
		return  # rising-edge only — one click = one take
	set_meta("_mouse_was_down", true)
	var mouse_world := get_global_mouse_position()
	for slot in _popup.get_children():
		if not (slot is Area2D) or not slot.has_meta("data"):
			continue
		var slot_pos: Vector2 = slot.global_position
		var slot_size: float = slot.get_meta("size", 10.0)
		var half: float = slot_size * 0.5
		if abs(mouse_world.x - slot_pos.x) <= half and abs(mouse_world.y - slot_pos.y) <= half:
			_take_slot(slot)
			# Eat the same-frame shoot/dash action so we don't fire/dash through the popup.
			get_viewport().set_input_as_handled()
			return


func _set_meta_safe(name: String, value) -> void:
	set_meta(name, value)


func _open_chest() -> void:
	# TestChest base would have shown the modal here. We swap to the world popup.
	if not _popup:
		_open_world_popup()


func _open_world_popup() -> void:
	var has_gold := int(get_meta("gold_reward", 0)) > 0
	if items.is_empty() and not has_gold:
		# Nothing to show — flash + die.
		var sfx_empty = get_node_or_null("/root/SFXManager")
		if sfx_empty:
			sfx_empty.play("error", -8.0, 0.05)
		return
	_popup = Node2D.new()
	_popup.name = "ContainerPopup"
	_popup.z_index = 50
	# Sit above the container's sprite. Dungeon sprites are ~8 px; overworld 32.
	var offset_y: float = -18.0 if has_meta("dungeon_scale") else -56.0
	_popup.position = Vector2(0, offset_y)
	add_child(_popup)
	_rebuild_slots()
	var sfx_open = get_node_or_null("/root/SFXManager")
	if sfx_open:
		sfx_open.play("open", -4.0, 0.05)


func _close_popup() -> void:
	if _popup and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null


func _update_popup_close() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		_close_popup()
		return
	var max_dist = POPUP_CLOSE_DISTANCE_DUNGEON if has_meta("dungeon_scale") else POPUP_CLOSE_DISTANCE_OVERWORLD
	if global_position.distance_to(player.global_position) > max_dist:
		_close_popup()


func _rebuild_slots() -> void:
	if not is_instance_valid(_popup):
		return
	for child in _popup.get_children():
		child.queue_free()

	# Collect entries: gold first (if any), then items.
	var entries: Array = []
	var gold = int(get_meta("gold_reward", 0))
	if gold > 0:
		entries.append({"kind": "gold", "amount": gold})
	for item in items:
		if item != null:
			entries.append({"kind": "item", "item": item})

	if entries.is_empty():
		_close_popup()
		return

	var dungeon := has_meta("dungeon_scale")
	var slot_size: float = 10.0 if dungeon else 36.0
	var slot_pad: float = 2.0 if dungeon else 6.0
	var n := mini(entries.size(), MAX_SLOTS)
	var row_w: float = n * (slot_size + slot_pad) - slot_pad
	var start_x: float = -row_w / 2.0 + slot_size / 2.0

	# Background bar behind the slots
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.09, 0.92)
	bg.size = Vector2(row_w + slot_pad * 2.0, slot_size + slot_pad * 2.0)
	bg.position = Vector2(-bg.size.x / 2.0, -bg.size.y / 2.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -1
	_popup.add_child(bg)

	for i in n:
		var entry = entries[i]
		var slot := _make_slot(entry, slot_size)
		slot.position = Vector2(start_x + i * (slot_size + slot_pad), 0.0)
		_popup.add_child(slot)


func _make_slot(data: Dictionary, slot_size: float) -> Area2D:
	var slot := Area2D.new()
	slot.collision_layer = 0
	slot.collision_mask = 0
	slot.input_pickable = false  # we hit-test manually in _poll_slot_click
	slot.set_meta("data", data)
	slot.set_meta("size", slot_size)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(slot_size, slot_size)
	shape.shape = rect
	slot.add_child(shape)

	# Slot frame
	var frame := ColorRect.new()
	frame.color = Color(0.55, 0.45, 0.2, 0.9)
	frame.size = Vector2(slot_size, slot_size)
	frame.position = -frame.size * 0.5
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.z_index = 0
	slot.add_child(frame)
	var inner := ColorRect.new()
	inner.color = Color(0.10, 0.08, 0.16, 1.0)
	inner.size = frame.size - Vector2(2.0, 2.0)
	inner.position = -inner.size * 0.5
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.z_index = 1
	slot.add_child(inner)

	if data.get("kind") == "gold":
		# Gold = bright yellow square + amount label
		var coin := ColorRect.new()
		coin.color = Color(1.0, 0.85, 0.2, 1.0)
		coin.size = inner.size * 0.6
		coin.position = -coin.size * 0.5
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.z_index = 2
		slot.add_child(coin)
		var lbl := Label.new()
		lbl.text = str(int(data.get("amount", 0)))
		lbl.add_theme_font_size_override("font_size", 6 if slot_size <= 12.0 else 14)
		lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.8))
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 1)
		lbl.position = Vector2(-slot_size * 0.4, slot_size * 0.15)
		lbl.z_index = 3
		slot.add_child(lbl)
	else:
		var item = data.get("item") as EquipmentItem
		if item:
			var icon_tex = ItemIconHelper.get_icon_texture(item)
			if icon_tex:
				var sprite := Sprite2D.new()
				sprite.texture = icon_tex
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				var icon_size: float = inner.size.x * 0.9
				var tex_size = icon_tex.get_size()
				if tex_size.x > 0:
					sprite.scale = Vector2(icon_size / tex_size.x, icon_size / tex_size.y)
				sprite.z_index = 2
				slot.add_child(sprite)

	return slot


func _take_slot(slot: Area2D) -> void:
	var data: Dictionary = slot.get_meta("data", {})
	if data.is_empty():
		return
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return

	var sfx = get_node_or_null("/root/SFXManager")

	if data.get("kind") == "gold":
		var amount = int(data.get("amount", 0))
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("add_gold"):
			gm.add_gold(amount, false)
		set_meta("gold_reward", 0)
		if sfx: sfx.play("coin", -4.0, 0.1)
	elif data.get("kind") == "item":
		var item = data.get("item") as EquipmentItem
		if item:
			var em = player.get("equipment_manager") if "equipment_manager" in player else null
			var added := false
			if em and em.has_method("add_to_inventory"):
				added = em.add_to_inventory(item)
			if added:
				items.erase(item)
				if sfx: sfx.play("pickup", -4.0, 0.1)
			else:
				if sfx: sfx.play("error", -6.0, 0.05)
				return  # inventory full — keep slot

	# Close out when nothing's left, otherwise redraw with one fewer slot.
	if items.is_empty() and int(get_meta("gold_reward", 0)) <= 0:
		_close_popup()
		# Also fade the container sprite to indicate it's emptied
		for child in get_children():
			if child is Sprite2D:
				child.modulate = Color(1, 1, 1, 0.4)
				break
	else:
		_rebuild_slots()

func _replace_chest_sprite() -> void:
	# Wipe the procedural sprite the parent built and swap in the real atlas tile.
	for child in get_children():
		if child is Sprite2D:
			child.queue_free()
			break
	var sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var atlas := AtlasTexture.new()
	atlas.atlas = FEATURES_TEX
	var coords: Vector2i = ATLAS_BY_TYPE.get(container_type, Vector2i(0, 0))
	atlas.region = Rect2(coords.x * 8, coords.y * 8, 8, 8)
	sprite.texture = atlas
	# Tiles are already 8 px — no scaling needed in dungeon. Overworld bumps them up.
	sprite.scale = Vector2(1.0, 1.0) if has_meta("dungeon_scale") else Vector2(4.0, 4.0)
	add_child(sprite)
	# Expand the interaction area so the player doesn't have to stand perfectly
	# centered to get the [E] prompt.
	for child in get_children():
		if child is CollisionShape2D:
			var rect := child.shape as RectangleShape2D
			if rect:
				rect.size = Vector2(12, 10) if has_meta("dungeon_scale") else Vector2(40, 32)
			break

func _set_container_label() -> void:
	match container_type:
		ContainerType.BARREL: chest_label = "Barrel"
		ContainerType.CRATE: chest_label = "Crate"
		ContainerType.SACK: chest_label = "Sack"
		ContainerType.CHEST: chest_label = "Chest"
		ContainerType.WARDROBE: chest_label = "Wardrobe"
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
## Optionally augments with a dungeon-pool equipment piece (sword / bow / staff / armor etc.)
## scaled to the current floor.
static func create_loot_container(c_type: ContainerType, dungeon_scale: bool = true,
		floor_num: int = 1, item_pool: ItemPool = null, base_difficulty: int = 0) -> LootContainer:
	var container = LootContainer.new()
	container.container_type = c_type
	if dungeon_scale:
		container.set_meta("dungeon_scale", true)
	# Roll basic loot from the type's table
	var table = BARREL_LOOT
	match c_type:
		ContainerType.CRATE: table = CRATE_LOOT
		ContainerType.SACK: table = SACK_LOOT
		ContainerType.CHEST: table = CHEST_LOOT
		ContainerType.WARDROBE: table = WARDROBE_LOOT
	var item_count = randi_range(2, 4) if (c_type == ContainerType.CHEST or c_type == ContainerType.WARDROBE) else randi_range(1, 3)
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

	# Dungeon-pool augmentation — real weapons / armor from the actual floor pool.
	# Chests are loud about it; barrels/sacks chip in sometimes; wardrobes lean
	# armor; crates split the difference. This is what gives "every other chest
	# has a better-than-starting item" feel without overshadowing enemy drops.
	if item_pool:
		var aug_chance: float = 0.25
		var aug_count: int = 1
		match c_type:
			ContainerType.CHEST:
				aug_chance = 0.95
				aug_count = randi_range(1, 2)
			ContainerType.CRATE:
				aug_chance = 0.55
			ContainerType.WARDROBE:
				aug_chance = 0.45
			ContainerType.BARREL:
				aug_chance = 0.20
			ContainerType.SACK:
				aug_chance = 0.20
		if randf() < aug_chance:
			var dungeon_items = item_pool.get_random_equipment(aug_count, floor_num, base_difficulty)
			for di in dungeon_items:
				if di and container.items.size() < MAX_SLOTS:
					container.items.append(di.make_copy())
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
