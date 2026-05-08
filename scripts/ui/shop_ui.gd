class_name ShopUI
extends CanvasLayer

signal shop_closed

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
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.anchor_left = 0.15
	_panel.anchor_right = 0.85
	_panel.anchor_top = 0.1
	_panel.anchor_bottom = 0.9

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.92)
	style.border_color = Color(0.6, 0.5, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title_label)

	# Gold display
	_gold_label = Label.new()
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_gold_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_gold_label)

	# Buy / Sell tabs
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	vbox.add_child(tab_row)

	_tab_buy = Button.new()
	_tab_buy.focus_mode = Control.FOCUS_NONE
	_tab_buy.text = "Buy"
	_tab_buy.add_theme_font_size_override("font_size", 12)
	_tab_buy.pressed.connect(_switch_to_buy)
	tab_row.add_child(_tab_buy)

	_tab_sell = Button.new()
	_tab_sell.focus_mode = Control.FOCUS_NONE
	_tab_sell.text = "Sell"
	_tab_sell.add_theme_font_size_override("font_size", 12)
	_tab_sell.pressed.connect(_switch_to_sell)
	tab_row.add_child(_tab_sell)

	# Status message
	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_status_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(_status_label)

	# Scrollable items
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_items_container = VBoxContainer.new()
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_items_container)

	# Close button
	_close_btn = Button.new()
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.text = "Close Shop"
	_close_btn.add_theme_font_size_override("font_size", 12)
	_close_btn.pressed.connect(_close)
	vbox.add_child(_close_btn)

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



func _add_buy_row(item: EquipmentItem, item_name: String, price: int) -> void:
	var row_panel = PanelContainer.new()
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0, 0, 0, 0)
	row_style.set_content_margin_all(4)
	row_panel.add_theme_stylebox_override("panel", row_style)
	row_panel.mouse_entered.connect(func(): row_style.bg_color = Color(0.2, 0.18, 0.1, 0.6))
	row_panel.mouse_exited.connect(func(): row_style.bg_color = Color(0, 0, 0, 0))

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row_panel.add_child(hbox)

	# Item icon
	if item and item.loy_tile_index >= 0:
		var icon_rect = TextureRect.new()
		icon_rect.texture = ItemIconHelper.get_icon_texture(item)
		icon_rect.custom_minimum_size = Vector2(20, 20)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hbox.add_child(icon_rect)

	var name_label = Label.new()
	name_label.text = item.get_display_name() if item else item_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 11)
	if item:
		name_label.add_theme_color_override("font_color", _rarity_color(item.rarity))
	hbox.add_child(name_label)

	# Slot type hint
	if item and EquipmentItem.is_equippable(item.slot_type):
		var slot_label = Label.new()
		slot_label.text = _slot_name(item.slot_type)
		slot_label.add_theme_font_size_override("font_size", 9)
		slot_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		hbox.add_child(slot_label)

	var price_label = Label.new()
	price_label.text = str(price) + "g"
	price_label.add_theme_font_size_override("font_size", 11)
	price_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	hbox.add_child(price_label)

	var buy_btn = Button.new()
	buy_btn.focus_mode = Control.FOCUS_NONE
	buy_btn.text = "Buy"
	buy_btn.add_theme_font_size_override("font_size", 10)
	buy_btn.pressed.connect(_on_buy.bind(item, item_name, price))
	hbox.add_child(buy_btn)

	_items_container.add_child(row_panel)

func _populate_sell() -> void:
	_clear_items()
	if not _equipment_manager:
		return

	for i in range(_equipment_manager.inventory.size()):
		var item = _equipment_manager.inventory[i]
		var sell_price = item.sell_value if item.sell_value > 0 else maxi(1, item.buy_price / 4)
		var is_equipped = _equipment_manager.is_equipped(item)

		var row_panel = PanelContainer.new()
		var row_style = StyleBoxFlat.new()
		row_style.bg_color = Color(0, 0, 0, 0)
		row_style.set_content_margin_all(4)
		row_panel.add_theme_stylebox_override("panel", row_style)
		row_panel.mouse_entered.connect(func(): row_style.bg_color = Color(0.2, 0.18, 0.1, 0.6))
		row_panel.mouse_exited.connect(func(): row_style.bg_color = Color(0, 0, 0, 0))

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		row_panel.add_child(hbox)

		# Item icon
		if item.loy_tile_index >= 0:
			var icon_rect = TextureRect.new()
			icon_rect.texture = ItemIconHelper.get_icon_texture(item)
			icon_rect.custom_minimum_size = Vector2(20, 20)
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			hbox.add_child(icon_rect)

		var name_label = Label.new()
		var display = item.get_display_name()
		if is_equipped:
			display += " [E]"
		name_label.text = display
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", _rarity_color(item.rarity))
		hbox.add_child(name_label)

		var price_label = Label.new()
		price_label.text = str(sell_price) + "g"
		price_label.add_theme_font_size_override("font_size", 11)
		price_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		hbox.add_child(price_label)

		var sell_btn = Button.new()
		sell_btn.focus_mode = Control.FOCUS_NONE
		sell_btn.add_theme_font_size_override("font_size", 10)
		if is_equipped:
			sell_btn.text = "Equipped"
			sell_btn.disabled = true
		else:
			sell_btn.text = "Sell"
			sell_btn.pressed.connect(_on_sell.bind(i, sell_price))
		hbox.add_child(sell_btn)

		_items_container.add_child(row_panel)

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
