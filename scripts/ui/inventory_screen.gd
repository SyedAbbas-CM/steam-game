class_name InventoryScreen
extends CanvasLayer

var equipment_manager: EquipmentManager
var selected_inv_index: int = -1

# UI refs (built in _ready)
var grid_container: GridContainer
var equip_slots: Dictionary = {}  # SlotType -> TextureRect
var tooltip_label: Label
var stats_label: Label
var hp_bar: ColorRect
var hp_bar_bg: ColorRect

const SLOT_SIZE = 28
const SLOT_MARGIN = 2
const GRID_COLS = 8
const GRID_ROWS = 7

const RARITY_COLORS = {
	0: Color(0.6, 0.6, 0.6),    # common: grey
	1: Color(0.3, 0.9, 0.3),    # uncommon: green
	2: Color(0.3, 0.8, 1.0),    # rare: cyan
}

const SLOT_NAMES = {
	EquipmentItem.SlotType.WEAPON: "WPN",
	EquipmentItem.SlotType.ARMOR: "ARM",
	EquipmentItem.SlotType.ACCESSORY: "ACC",
	EquipmentItem.SlotType.CONSUMABLE: "USE",
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("inventory_screen")
	visible = false
	_build_ui()

func setup(equip_mgr: EquipmentManager) -> void:
	equipment_manager = equip_mgr
	equipment_manager.inventory_changed.connect(_refresh)
	equipment_manager.stats_changed.connect(_refresh)

func _build_ui() -> void:
	# Background panel
	var panel = PanelContainer.new()
	panel.anchors_preset = Control.PRESET_FULL_RECT
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.5)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 10)
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.add_child(main_hbox)

	# Left: Equipment slots
	var equip_vbox = VBoxContainer.new()
	equip_vbox.add_theme_constant_override("separation", 4)
	main_hbox.add_child(equip_vbox)

	var equip_title = Label.new()
	equip_title.text = "EQUIP"
	equip_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_settings = LabelSettings.new()
	title_settings.font_size = 8
	title_settings.font_color = Color(0.8, 0.8, 0.3)
	equip_title.label_settings = title_settings
	equip_vbox.add_child(equip_title)

	for slot_type in [EquipmentItem.SlotType.WEAPON, EquipmentItem.SlotType.ARMOR,
						EquipmentItem.SlotType.ACCESSORY, EquipmentItem.SlotType.CONSUMABLE]:
		var slot_btn = _create_slot_button(SLOT_NAMES[slot_type], slot_type)
		equip_vbox.add_child(slot_btn)
		equip_slots[slot_type] = slot_btn

	# Center: Inventory grid
	var center_vbox = VBoxContainer.new()
	center_vbox.add_theme_constant_override("separation", 4)
	main_hbox.add_child(center_vbox)

	var inv_title = Label.new()
	inv_title.text = "INVENTORY"
	inv_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var inv_settings = LabelSettings.new()
	inv_settings.font_size = 8
	inv_settings.font_color = Color(0.7, 0.7, 0.7)
	inv_title.label_settings = inv_settings
	center_vbox.add_child(inv_title)

	grid_container = GridContainer.new()
	grid_container.columns = GRID_COLS
	grid_container.add_theme_constant_override("h_separation", SLOT_MARGIN)
	grid_container.add_theme_constant_override("v_separation", SLOT_MARGIN)
	center_vbox.add_child(grid_container)

	# Create empty grid slots
	for i in range(GRID_COLS * GRID_ROWS):
		var slot = _create_inv_slot(i)
		grid_container.add_child(slot)

	# Bottom: tooltip
	tooltip_label = Label.new()
	tooltip_label.text = ""
	var tip_settings = LabelSettings.new()
	tip_settings.font_size = 7
	tip_settings.font_color = Color(0.9, 0.9, 0.9)
	tooltip_label.label_settings = tip_settings
	center_vbox.add_child(tooltip_label)

	# Right: stats
	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 4)
	main_hbox.add_child(right_vbox)

	# HP bar
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.custom_minimum_size = Vector2(40, 12)
	hp_bar_bg.color = Color(0.3, 0.1, 0.1)
	right_vbox.add_child(hp_bar_bg)

	hp_bar = ColorRect.new()
	hp_bar.custom_minimum_size = Vector2(40, 12)
	hp_bar.color = Color(0.8, 0.15, 0.15)
	hp_bar_bg.add_child(hp_bar)

	var hp_label = Label.new()
	hp_label.text = "HP"
	var hp_settings = LabelSettings.new()
	hp_settings.font_size = 7
	hp_settings.font_color = Color.WHITE
	hp_label.label_settings = hp_settings
	hp_bar.add_child(hp_label)

	stats_label = Label.new()
	stats_label.text = ""
	var stat_settings = LabelSettings.new()
	stat_settings.font_size = 6
	stat_settings.font_color = Color(0.7, 0.7, 0.7)
	stats_label.label_settings = stat_settings
	right_vbox.add_child(stats_label)

func _create_slot_button(label_text: String, slot_type: EquipmentItem.SlotType) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(SLOT_SIZE + 8, SLOT_SIZE + 8)
	btn.text = label_text

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.15, 0.2)
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = Color(0.5, 0.5, 0.2)
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_font_size_override("font_size", 7)

	btn.pressed.connect(_on_equip_slot_pressed.bind(slot_type))
	return btn

func _create_inv_slot(index: int) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	btn.text = ""

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.1, 0.15)
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = Color(0.3, 0.3, 0.35)
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_font_size_override("font_size", 6)

	btn.pressed.connect(_on_inv_slot_pressed.bind(index))
	btn.mouse_entered.connect(_on_inv_slot_hovered.bind(index))
	btn.mouse_exited.connect(_on_slot_unhovered)
	return btn

func _on_inv_slot_pressed(index: int) -> void:
	if not equipment_manager:
		return
	if index < equipment_manager.inventory.size():
		equipment_manager.equip_from_inventory(index)

func _on_equip_slot_pressed(slot_type: EquipmentItem.SlotType) -> void:
	if not equipment_manager:
		return
	equipment_manager.unequip_to_inventory(slot_type)

func _on_inv_slot_hovered(index: int) -> void:
	if not equipment_manager or index >= equipment_manager.inventory.size():
		tooltip_label.text = ""
		return
	var item = equipment_manager.inventory[index]
	tooltip_label.text = item.item_name + " - " + item.description

func _on_slot_unhovered() -> void:
	tooltip_label.text = ""

func _refresh() -> void:
	if not equipment_manager or not visible:
		return

	# Update inventory grid
	for i in range(GRID_COLS * GRID_ROWS):
		var btn = grid_container.get_child(i) as Button
		if i < equipment_manager.inventory.size():
			var item = equipment_manager.inventory[i]
			btn.text = item.item_name.left(3)
			var style = btn.get_theme_stylebox("normal") as StyleBoxFlat
			if style:
				style.border_color = RARITY_COLORS.get(item.rarity, Color(0.3, 0.3, 0.35))
		else:
			btn.text = ""
			var style = btn.get_theme_stylebox("normal") as StyleBoxFlat
			if style:
				style.border_color = Color(0.3, 0.3, 0.35)

	# Update equipped slots
	for slot_type in equip_slots:
		var btn = equip_slots[slot_type] as Button
		if equipment_manager.equipped.has(slot_type):
			var item = equipment_manager.equipped[slot_type]
			btn.text = item.item_name.left(4)
			var style = btn.get_theme_stylebox("normal") as StyleBoxFlat
			if style:
				style.border_color = RARITY_COLORS.get(item.rarity, Color(0.5, 0.5, 0.2))
		else:
			btn.text = SLOT_NAMES[slot_type]
			var style = btn.get_theme_stylebox("normal") as StyleBoxFlat
			if style:
				style.border_color = Color(0.5, 0.5, 0.2)

	# Update stats
	var stat_text = ""
	stat_text += "ATK: " + str(equipment_manager.get_damage()) + "\n"
	stat_text += "SPD: " + str(int(equipment_manager.get_move_speed())) + "\n"
	stat_text += "AS: " + str(snapped(equipment_manager.get_attack_speed(), 0.01)) + "\n"
	stats_label.text = stat_text

	# Update HP bar
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var ratio = float(player.hp) / float(player.max_hp) if player.max_hp > 0 else 1.0
		hp_bar.custom_minimum_size.x = 40 * ratio

func toggle() -> void:
	visible = not visible
	if visible:
		get_tree().paused = true
		_refresh()
	else:
		get_tree().paused = false
