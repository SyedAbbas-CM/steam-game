class_name ShopUI
extends CanvasLayer

## Simple shop overlay for buying items from NPCs

signal shop_closed

var _panel: PanelContainer
var _title_label: Label
var _items_container: VBoxContainer
var _close_btn: Button
var _gold_label: Label
var _shop_data: ShopDefinition
var _all_shops: Dictionary = {}  # shop_id -> ShopDefinition

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_load_shops()
	_build_ui()

func _load_shops() -> void:
	var dir = DirAccess.open("res://resources/shops/")
	if not dir:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var shop = load("res://resources/shops/" + fname) as ShopDefinition
			if shop and shop.id != "":
				_all_shops[shop.id] = shop
		fname = dir.get_next()

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
	_close_btn.text = "Close Shop"
	_close_btn.add_theme_font_size_override("font_size", 12)
	_close_btn.pressed.connect(_close)
	vbox.add_child(_close_btn)

func open_shop(shop_id: String) -> void:
	if not _all_shops.has(shop_id):
		return
	_shop_data = _all_shops[shop_id]
	_title_label.text = _shop_data.title
	_update_gold()
	_populate_items()
	_panel.visible = true

func _update_gold() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var gold = gm.get_gold() if gm else 0
	_gold_label.text = "Gold: " + str(gold)

func _populate_items() -> void:
	for child in _items_container.get_children():
		child.queue_free()

	var qm = get_node_or_null("/root/QuestManager")

	for stock_entry in _shop_data.stock:
		var item_name = str(stock_entry.get("item_name", ""))
		var req_quest = str(stock_entry.get("required_quest", ""))

		# Check quest requirement
		if req_quest != "" and qm and not qm.is_quest_completed(req_quest):
			continue

		# Find item resource
		var item = _find_item(item_name)
		var price = _get_item_price(item, item_name)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)

		var name_label = Label.new()
		name_label.text = item_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 11)
		hbox.add_child(name_label)

		var price_label = Label.new()
		price_label.text = str(price) + "g"
		price_label.add_theme_font_size_override("font_size", 11)
		price_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		hbox.add_child(price_label)

		var buy_btn = Button.new()
		buy_btn.text = "Buy"
		buy_btn.add_theme_font_size_override("font_size", 10)
		buy_btn.pressed.connect(_on_buy.bind(item_name, price))
		hbox.add_child(buy_btn)

		_items_container.add_child(hbox)

func _find_item(item_name: String) -> Resource:
	var safe = item_name.to_lower().replace(" ", "_")
	var path = "res://resources/items/loy/" + safe + ".tres"
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _get_item_price(item: Resource, item_name: String) -> int:
	if item and item.get("buy_price"):
		return int(item.buy_price)
	if item and item.get("value"):
		return int(item.value)
	# Fallback prices for common items
	var prices = {
		"Apple": 10, "Meat": 25, "Red Potion": 50, "Blue Potion": 100,
		"Green Potion": 75, "Town Portal": 150, "Trap": 30, "Powder Keg": 80,
		"Fishing Pole": 200, "Spade": 100, "Pet Food": 50,
	}
	return prices.get(item_name, 100)

func _on_buy(item_name: String, price: int) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return
	if gm.spend_gold(price):
		_update_gold()
		# TODO: Add item to player inventory
		print("Bought: " + item_name)
	else:
		# Show "not enough gold" via dialogue
		var qm = get_node_or_null("/root/QuestManager")
		if qm and _shop_data:
			qm.show_dialogue_requested.emit(_shop_data.shop_name, _shop_data.portrait, _shop_data.nomoney, ["Ok"])

func _close() -> void:
	_panel.visible = false
	shop_closed.emit()

func is_open() -> bool:
	return _panel.visible

func _input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if event.is_action_pressed("inventory"):
		_close()
