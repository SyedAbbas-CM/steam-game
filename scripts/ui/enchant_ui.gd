class_name EnchantUI
extends CanvasLayer

signal enchant_closed

var _panel: PanelContainer
var _title_label: Label
var _gold_label: Label
var _items_container: VBoxContainer
var _enchant_options: VBoxContainer
var _status_label: Label
var _close_btn: Button
var _back_btn: Button
var _equipment_manager: EquipmentManager
var _selected_item_index: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_ui()

func setup(equip_mgr: EquipmentManager) -> void:
	_equipment_manager = equip_mgr

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.anchor_left = 0.2
	_panel.anchor_right = 0.8
	_panel.anchor_top = 0.1
	_panel.anchor_bottom = 0.9

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.14, 0.94)
	style.border_color = Color(0.5, 0.3, 0.8)
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

	_title_label = Label.new()
	_title_label.text = "Enchanting Station"
	_title_label.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0))
	_title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title_label)

	_gold_label = Label.new()
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_gold_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_gold_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_status_label)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var inner = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)

	_items_container = VBoxContainer.new()
	_items_container.add_theme_constant_override("separation", 4)
	inner.add_child(_items_container)

	_enchant_options = VBoxContainer.new()
	_enchant_options.add_theme_constant_override("separation", 4)
	inner.add_child(_enchant_options)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	_back_btn = Button.new()
	_back_btn.focus_mode = Control.FOCUS_NONE
	_back_btn.text = "Back"
	_back_btn.add_theme_font_size_override("font_size", 12)
	_back_btn.pressed.connect(_show_item_list)
	_back_btn.visible = false
	btn_row.add_child(_back_btn)

	_close_btn = Button.new()
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.text = "Close"
	_close_btn.add_theme_font_size_override("font_size", 12)
	_close_btn.pressed.connect(_close)
	btn_row.add_child(_close_btn)

func open() -> void:
	if not _equipment_manager:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			_equipment_manager = player.get_node_or_null("EquipmentManager") as EquipmentManager
	_update_gold()
	_show_item_list()
	_panel.visible = true

func _update_gold() -> void:
	var gm = get_node_or_null("/root/GameManager")
	_gold_label.text = "Gold: " + str(gm.get_gold() if gm else 0)

func _show_item_list() -> void:
	_selected_item_index = -1
	_back_btn.visible = false
	_title_label.text = "Enchanting Station — Select Item"
	_status_label.text = "Choose an item to enchant or upgrade"
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	for c in _items_container.get_children():
		c.queue_free()
	for c in _enchant_options.get_children():
		c.queue_free()

	if not _equipment_manager:
		return

	for i in range(_equipment_manager.inventory.size()):
		var item = _equipment_manager.inventory[i]
		if item.slot_type == EquipmentItem.SlotType.CONSUMABLE or item.slot_type == EquipmentItem.SlotType.MATERIAL:
			continue

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)

		var name_label = Label.new()
		name_label.text = item.get_display_name()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", _rarity_color(item.rarity))
		hbox.add_child(name_label)

		if item.enchantment:
			var ench_label = Label.new()
			ench_label.text = "[" + item.enchantment.get_prefix() + " T" + str(item.enchantment.tier) + "]"
			ench_label.add_theme_font_size_override("font_size", 10)
			ench_label.add_theme_color_override("font_color", item.enchantment.get_color())
			hbox.add_child(ench_label)

		var select_btn = Button.new()
		select_btn.focus_mode = Control.FOCUS_NONE
		select_btn.text = "Select"
		select_btn.add_theme_font_size_override("font_size", 10)
		select_btn.pressed.connect(_select_item.bind(i))
		hbox.add_child(select_btn)

		_items_container.add_child(hbox)

func _select_item(inv_index: int) -> void:
	_selected_item_index = inv_index
	_back_btn.visible = true
	var item = _equipment_manager.inventory[inv_index]
	_title_label.text = "Enchant: " + item.get_display_name()
	_status_label.text = ""

	for c in _items_container.get_children():
		c.queue_free()
	for c in _enchant_options.get_children():
		c.queue_free()

	# Enchantment options
	var enchant_header = Label.new()
	enchant_header.text = "Apply Enchantment:"
	enchant_header.add_theme_font_size_override("font_size", 12)
	enchant_header.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0))
	_enchant_options.add_child(enchant_header)

	var current_tier = item.enchantment.tier if item.enchantment else 0
	var next_tier = mini(current_tier + 1, 3)
	if current_tier >= 3:
		next_tier = 3

	for etype in ItemEnchantment.EnchantType.values():
		var enchant = ItemEnchantment.create(etype, next_tier)
		var cost = enchant.get_enchant_cost()

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)

		var name_label = Label.new()
		name_label.text = enchant.get_prefix() + " (T" + str(next_tier) + ")"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", enchant.get_color())
		hbox.add_child(name_label)

		var info_label = Label.new()
		info_label.text = "+" + str(enchant.bonus_damage) + " dmg, " + str(int(enchant.proc_chance)) + "% proc"
		info_label.add_theme_font_size_override("font_size", 10)
		info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		hbox.add_child(info_label)

		var cost_label = Label.new()
		cost_label.text = str(cost) + "g"
		cost_label.add_theme_font_size_override("font_size", 10)
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		hbox.add_child(cost_label)

		var btn = Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = "Enchant"
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(_apply_enchant.bind(inv_index, etype, next_tier, cost))
		hbox.add_child(btn)

		_enchant_options.add_child(hbox)

	# Rarity upgrade option
	if item.rarity < 2:
		var sep = HSeparator.new()
		_enchant_options.add_child(sep)

		var rarity_names = ["Common", "Uncommon", "Rare"]
		var upgrade_cost = 200 if item.rarity == 0 else 1000

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)

		var label = Label.new()
		label.text = "Upgrade to " + rarity_names[item.rarity + 1]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", _rarity_color(item.rarity + 1))
		hbox.add_child(label)

		var info = Label.new()
		info.text = "+20% all modifiers"
		info.add_theme_font_size_override("font_size", 10)
		info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		hbox.add_child(info)

		var cost_label = Label.new()
		cost_label.text = str(upgrade_cost) + "g"
		cost_label.add_theme_font_size_override("font_size", 10)
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		hbox.add_child(cost_label)

		var btn = Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = "Upgrade"
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(_upgrade_rarity.bind(inv_index, upgrade_cost))
		hbox.add_child(btn)

		_enchant_options.add_child(hbox)

func _apply_enchant(inv_index: int, etype: ItemEnchantment.EnchantType, tier: int, cost: int) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not _equipment_manager:
		return
	if inv_index >= _equipment_manager.inventory.size():
		return

	if not gm.spend_gold(cost):
		_status_label.text = "Not enough gold!"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		return

	var item = _equipment_manager.inventory[inv_index]
	item.enchantment = ItemEnchantment.create(etype, tier)
	_equipment_manager.stats_changed.emit()

	_status_label.text = "Enchanted! → " + item.get_display_name()
	_status_label.add_theme_color_override("font_color", item.enchantment.get_color())
	_update_gold()
	_select_item(inv_index)  # refresh

func _upgrade_rarity(inv_index: int, cost: int) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not _equipment_manager:
		return
	if inv_index >= _equipment_manager.inventory.size():
		return

	var item = _equipment_manager.inventory[inv_index]
	if item.rarity >= 2:
		return

	if not gm.spend_gold(cost):
		_status_label.text = "Not enough gold!"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		return

	item.rarity += 1
	# Boost all modifiers by 20%
	for mod in item.modifiers:
		mod.flat_bonus *= 1.2
		mod.percent_bonus *= 1.2
	_equipment_manager.stats_changed.emit()

	var rarity_names = ["Common", "Uncommon", "Rare"]
	_status_label.text = "Upgraded to " + rarity_names[item.rarity] + "!"
	_status_label.add_theme_color_override("font_color", _rarity_color(item.rarity))
	_update_gold()
	_select_item(inv_index)

func _rarity_color(rarity: int) -> Color:
	match rarity:
		0: return Color(0.8, 0.8, 0.8)
		1: return Color(0.3, 0.9, 0.3)
		2: return Color(0.3, 0.8, 1.0)
	return Color.WHITE

func _close() -> void:
	_panel.visible = false
	enchant_closed.emit()

func is_open() -> bool:
	return _panel.visible

func _input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if event.is_action_pressed("inventory"):
		_close()
