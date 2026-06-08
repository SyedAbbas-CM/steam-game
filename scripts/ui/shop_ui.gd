class_name ShopUI
extends CanvasLayer

signal shop_closed

const DEBUG_TEN_LEVELS_NAME := "Debug: +10 Levels"
const DEBUG_TEN_LEVELS_PRICE := 1
const DEBUG_PERK_TOKEN_NAME := "Perk Token"
const DEBUG_PERK_TOKEN_PRICE := 500

var _panel: PanelContainer
var _title_label: Label
var _items_container: VBoxContainer
var _close_btn: Button
var _gold_label: Label
var _tab_buy: Button
var _tab_sell: Button
var _status_label: Label
var _shop_data: ShopDefinition
var _all_shops: Dictionary = {}
var _equipment_manager: EquipmentManager
var _mode: String = "buy"  # "buy" or "sell"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	add_to_group("shop_ui")
	_load_shops()
	_build_ui()

func _load_shops() -> void:
	for path in ResourceRegistry.shops():
		var shop = load(path) as ShopDefinition
		if shop and shop.id != "":
			_all_shops[shop.id] = shop

func _build_ui() -> void:
	# Backdrop dimmer
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	overlay.name = "Overlay"
	add_child(overlay)

	# Main panel (ornate framed)
	_panel = AshfieldsUI.ornate_panel(20)
	_panel.visible = false
	_panel.anchor_left = 0.15
	_panel.anchor_right = 0.85
	_panel.anchor_top = 0.08
	_panel.anchor_bottom = 0.92
	_panel.theme = load("res://assets/themes/ashfields_theme.tres") as Theme
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	# Header row: section title (left) + close X (right)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	vbox.add_child(header_row)

	var title_block := AshfieldsUI.section_title("SHOP", 20)
	title_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label = title_block.get_child(0) as Label  # so existing open_shop assignment still works
	header_row.add_child(title_block)

	var close_x := AshfieldsUI.pill_button("✕", AshfieldsUI.BLOOD)
	close_x.custom_minimum_size = Vector2(46, 38)
	close_x.pressed.connect(_close)
	header_row.add_child(close_x)

	# Sub-row: BUY / SELL pills + gold counter
	var sub_row := HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 10)
	vbox.add_child(sub_row)

	_tab_buy = AshfieldsUI.pill_button("BUY", AshfieldsUI.GOLD_DARK)
	_tab_buy.pressed.connect(_switch_to_buy)
	sub_row.add_child(_tab_buy)

	_tab_sell = AshfieldsUI.pill_button("SELL", AshfieldsUI.GOLD_DARK)
	_tab_sell.pressed.connect(_switch_to_sell)
	sub_row.add_child(_tab_sell)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_row.add_child(sp)

	_gold_label = Label.new()
	_gold_label.add_theme_color_override("font_color", AshfieldsUI.GOLD)
	_gold_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_gold_label.add_theme_constant_override("outline_size", 2)
	_gold_label.add_theme_font_size_override("font_size", 38)
	sub_row.add_child(_gold_label)

	# Status message (success / failure)
	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_status_label.add_theme_font_size_override("font_size", 26)
	vbox.add_child(_status_label)

	vbox.add_child(AshfieldsUI.divider())

	# Scrollable items
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_items_container = VBoxContainer.new()
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_items_container)

	# Footer
	vbox.add_child(AshfieldsUI.divider())

	var footer_row := HBoxContainer.new()
	footer_row.add_theme_constant_override("separation", 10)
	footer_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(footer_row)

	_close_btn = AshfieldsUI.pill_button("LEAVE", AshfieldsUI.GOLD_DARK)
	_close_btn.custom_minimum_size = Vector2(160, 42)
	_close_btn.pressed.connect(_close)
	footer_row.add_child(_close_btn)

func setup(equip_mgr: EquipmentManager) -> void:
	_equipment_manager = equip_mgr

func open_shop(shop_id: String) -> void:
	if not _all_shops.has(shop_id):
		return
	_shop_data = _all_shops[shop_id]
	_title_label.text = _shop_data.title
	_status_label.text = ""

	# Find player's equipment manager if not set
	if not _equipment_manager:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			_equipment_manager = player.get_node_or_null("EquipmentManager") as EquipmentManager

	_mode = "buy"
	_update_gold()
	_populate_buy()
	_panel.visible = true
	var overlay = get_node_or_null("Overlay")
	if overlay:
		overlay.visible = true
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("open", -3.0, 0.0)

func _update_gold() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var gold = gm.get_gold() if gm else 0
	_gold_label.text = "Gold: " + str(gold)

func _switch_to_buy() -> void:
	_mode = "buy"
	_status_label.text = ""
	_populate_buy()
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click", -5.0)

func _switch_to_sell() -> void:
	_mode = "sell"
	_status_label.text = ""
	_populate_sell()
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click", -5.0)

func _populate_buy() -> void:
	_clear_items()
	var qm = get_node_or_null("/root/QuestManager")

	# Static LoY stock
	for stock_entry in _shop_data.stock:
		var item_name = str(stock_entry.get("item_name", ""))
		var req_quest = str(stock_entry.get("required_quest", ""))

		if req_quest != "" and qm and not qm.is_quest_completed(req_quest):
			continue

		var item = _find_item(item_name) as EquipmentItem
		var price = _get_item_price(item, item_name)
		_add_buy_row(item, item_name, price)
	# Perk Token always available (any shop). Bought tokens grant 1 perk token directly.
	_add_buy_row(null, DEBUG_PERK_TOKEN_NAME, DEBUG_PERK_TOKEN_PRICE)
	if OS.is_debug_build():
		_add_buy_row(null, DEBUG_TEN_LEVELS_NAME, DEBUG_TEN_LEVELS_PRICE)



func _add_buy_row(item: EquipmentItem, item_name: String, price: int) -> void:
	var display_name: String = item.get_display_name() if item else item_name
	var rarity: int = item.rarity if item else 0
	var icon: Texture2D = null
	if item and item.loy_tile_index >= 0:
		icon = ItemIconHelper.get_icon_texture(item)

	# Row container — card on the left, Buy pill on the right
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var card := AshfieldsUI.item_card(display_name, price, rarity, icon, Vector2(0, 60))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 100)
	# Tooltip slot hint via Godot's built-in tooltip
	if item and EquipmentItem.is_equippable(item.slot_type):
		card.tooltip_text = "Slot: " + _slot_name(item.slot_type)
	card.pressed.connect(_on_buy.bind(item, item_name, price))
	row.add_child(card)

	var buy_btn := AshfieldsUI.pill_button("BUY", AshfieldsUI.GOLD_DARK)
	buy_btn.custom_minimum_size = Vector2(160, 100)
	buy_btn.pressed.connect(_on_buy.bind(item, item_name, price))
	row.add_child(buy_btn)

	_items_container.add_child(row)

func _populate_sell() -> void:
	_clear_items()
	if not _equipment_manager:
		return

	for i in range(_equipment_manager.inventory.size()):
		var item = _equipment_manager.inventory[i]
		var sell_price = item.sell_value if item.sell_value > 0 else maxi(1, item.buy_price / 4)
		var is_equipped = _equipment_manager.is_equipped(item)
		var icon: Texture2D = null
		if item.loy_tile_index >= 0:
			icon = ItemIconHelper.get_icon_texture(item)
		var label_text: String = item.get_display_name()
		if is_equipped:
			label_text += "  •  EQUIPPED"

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var card := AshfieldsUI.item_card(label_text, sell_price, item.rarity, icon, Vector2(0, 82))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 100)
		card.disabled = is_equipped
		row.add_child(card)

		var sell_btn := AshfieldsUI.pill_button("SELL", AshfieldsUI.GOLD_DARK)
		sell_btn.custom_minimum_size = Vector2(160, 100)
		if is_equipped:
			sell_btn.disabled = true
		else:
			sell_btn.pressed.connect(_on_sell.bind(i, sell_price))
		row.add_child(sell_btn)

		_items_container.add_child(row)

func _clear_items() -> void:
	for child in _items_container.get_children():
		child.queue_free()

func _find_item(item_name: String) -> Resource:
	var safe = item_name.to_lower().replace(" ", "_")
	for dir in ["res://resources/items/loy/", "res://resources/items/crafting/", "res://resources/items/crafted/"]:
		var path = dir + safe + ".tres"
		if ResourceLoader.exists(path):
			return load(path)
	return null

func _get_item_price(item: Resource, item_name: String) -> int:
	if item and item.get("buy_price") and int(item.buy_price) > 0:
		return int(item.buy_price * 4.0)  # Mark-up: items cost 4x base price in shops
	var prices = {
		"Apple": 40, "Meat": 100, "Red Potion": 200, "Blue Potion": 420,
		"Green Potion": 300, "Town Portal": 600, "Trap": 120, "Powder Keg": 350,
		"Fishing Pole": 800, "Spade": 400, "Pet Food": 200,
	}
	return prices.get(item_name, 400)

func _on_buy(item: EquipmentItem, item_name: String, price: int) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return

	if item_name == DEBUG_TEN_LEVELS_NAME:
		_buy_debug_levels(gm, price)
		return
	if item_name == DEBUG_PERK_TOKEN_NAME:
		_buy_perk_token(gm, price)
		return

	if not _equipment_manager or _equipment_manager.inventory.size() >= _equipment_manager.MAX_INVENTORY:
		_status_label.text = "Inventory full!"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		return

	var sfx = get_node_or_null("/root/SFXManager")
	if gm.spend_gold(price):
		if item:
			_equipment_manager.add_to_inventory(item.make_copy())
			_status_label.text = "Bought " + item.get_display_name()
		else:
			_status_label.text = "Bought " + item_name
		_status_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		_update_gold()
		if sfx:
			sfx.play("gold", -3.0)
	else:
		_status_label.text = _shop_data.nomoney if _shop_data.nomoney != "" else "Not enough gold!"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		if sfx:
			sfx.play("error", -3.0)

func _buy_debug_levels(gm, price: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or player.level_system == null:
		_status_label.text = "No player to level."
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		return
	var level_system: LevelSystem = player.level_system
	if level_system.level >= LevelSystem.MAX_LEVEL:
		_status_label.text = "Already max level."
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		return
	if not gm.spend_gold(price):
		_status_label.text = _shop_data.nomoney if _shop_data.nomoney != "" else "Not enough gold!"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		var no_money_sfx = get_node_or_null("/root/SFXManager")
		if no_money_sfx:
			no_money_sfx.play("error", -3.0)
		return
	var levels_to_grant := mini(10, LevelSystem.MAX_LEVEL - level_system.level)
	var total_xp := 0
	var preview_level := level_system.level
	for _i in range(levels_to_grant):
		total_xp += 100 + (preview_level - 1) * 50
		preview_level += 1
	player.gain_xp(total_xp)
	_status_label.text = "Bought +%d levels" % levels_to_grant
	_status_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_update_gold()
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("gold", -3.0)

func _buy_perk_token(gm, price: int) -> void:
	var pm = get_node_or_null("/root/PerkManager")
	if not pm:
		_status_label.text = "PerkManager unavailable."
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		return
	if not gm.spend_gold(price):
		_status_label.text = _shop_data.nomoney if _shop_data.nomoney != "" else "Not enough gold!"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		var err_sfx = get_node_or_null("/root/SFXManager")
		if err_sfx:
			err_sfx.play("error", -3.0)
		return
	pm.add_token(1)
	_status_label.text = "Bought 1 Perk Token (now have %d)" % pm.perk_tokens
	_status_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_update_gold()
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("gold", -3.0)

func _on_sell(inv_index: int, sell_price: int) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not _equipment_manager:
		return

	if inv_index < 0 or inv_index >= _equipment_manager.inventory.size():
		return

	var item = _equipment_manager.inventory[inv_index]

	# Double-check: don't sell equipped items
	if _equipment_manager.is_equipped(item):
		_status_label.text = "Unequip first!"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		return

	var item_name = item.get_display_name()
	_equipment_manager.remove_from_inventory(inv_index)
	gm.add_gold(sell_price)
	_status_label.text = "Sold " + item_name + " for " + str(sell_price) + "g"
	_status_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_update_gold()
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("coin", -3.0)
	# Refresh sell list (indices shifted)
	_populate_sell()

func _slot_name(slot: EquipmentItem.SlotType) -> String:
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
	return ""

func _rarity_color(rarity: int) -> Color:
	match rarity:
		0: return Color(0.8, 0.8, 0.8)  # common grey
		1: return Color(0.3, 0.9, 0.3)  # uncommon green
		2: return Color(0.3, 0.8, 1.0)  # rare cyan
	return Color.WHITE

func _close() -> void:
	_panel.visible = false
	var overlay = get_node_or_null("Overlay")
	if overlay:
		overlay.visible = false
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("close", -4.0, 0.0)
	shop_closed.emit()

func is_open() -> bool:
	return _panel.visible

func _input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if event.is_action_pressed("inventory"):
		_close()
