class_name LootBagUI
extends CanvasLayer

## Small panel in the bottom-right that shows a nearby LootBag's contents.
## Items are clickable to pick up and move to inventory.

var _panel: PanelContainer
var _grid: GridContainer
var _title_label: Label
var _take_all_btn: Button
var _current_bag: LootBag
var _equipment_manager: EquipmentManager
var _slot_buttons: Array[Button] = []

const SLOT_SIZE = 80
const GRID_COLS = 4
const PANEL_MARGIN = 16
const RARITY_COLORS = [
	Color(0.7, 0.7, 0.7),   # common
	Color(0.3, 0.9, 0.3),   # uncommon
	Color(0.3, 0.8, 1.0),   # rare
]

func _ready() -> void:
	layer = 99
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("loot_bag_ui")
	_build_ui()

func setup(equip_mgr: EquipmentManager) -> void:
	_equipment_manager = equip_mgr

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.08, 0.92)
	style.border_color = Color(0.6, 0.45, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.content_margin_left = PANEL_MARGIN
	style.content_margin_right = PANEL_MARGIN
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)

	# Position in bottom-right, above where the BAG button will be
	# Panel width: GRID_COLS * SLOT_SIZE + margins = ~200px
	var panel_w = GRID_COLS * SLOT_SIZE + PANEL_MARGIN * 2 + 16
	_panel.position = Vector2(1920 - panel_w - 14, 1080 - 14)  # will adjust y after content
	_panel.size = Vector2(panel_w, 0)  # auto-height

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "Loot Bag"
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	vbox.add_child(_title_label)

	# Item grid
	_grid = GridContainer.new()
	_grid.columns = GRID_COLS
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	vbox.add_child(_grid)

	# Take All button
	_take_all_btn = Button.new()
	_take_all_btn.focus_mode = Control.FOCUS_NONE
	_take_all_btn.text = "Take All"
	_take_all_btn.add_theme_font_size_override("font_size", 14)
	_take_all_btn.pressed.connect(_on_take_all)
	vbox.add_child(_take_all_btn)

	add_child(_panel)

func show_bag(bag: LootBag) -> void:
	_current_bag = bag
	if not _equipment_manager:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			_equipment_manager = player.get_node_or_null("EquipmentManager") as EquipmentManager
	_refresh()
	_panel.visible = true
	_reposition_panel()

func hide_bag(bag: LootBag) -> void:
	if _current_bag == bag:
		_current_bag = null
		_panel.visible = false
		# Check if player is near another loot bag and show it
		_show_next_nearby_bag()

func _show_next_nearby_bag() -> void:
	var player = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if not player:
		return
	for bag in get_tree().get_nodes_in_group("loot_bag"):
		if not is_instance_valid(bag) or bag.is_queued_for_deletion():
			continue
		if bag._player_nearby and not bag.items.is_empty():
			show_bag(bag)
			return

func is_open() -> bool:
	return _panel.visible

func _refresh() -> void:
	# Clear old slots
	for child in _grid.get_children():
		child.queue_free()
	_slot_buttons.clear()

	if not _current_bag:
		return

	_title_label.text = "Loot Bag (" + str(_current_bag.items.size()) + " items)"

	for i in range(_current_bag.items.size()):
		var item = _current_bag.items[i]
		var btn = Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		btn.tooltip_text = item.get_display_name() + "\n" + item.description

		# Style based on rarity
		var btn_style = StyleBoxFlat.new()
		var rarity_col = RARITY_COLORS[clampi(item.rarity, 0, 2)]
		btn_style.bg_color = Color(0.12, 0.1, 0.16)
		btn_style.border_color = rarity_col.darkened(0.3)
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(2)
		btn.add_theme_stylebox_override("normal", btn_style)

		var hover_style = btn_style.duplicate()
		hover_style.bg_color = Color(0.2, 0.18, 0.25)
		hover_style.border_color = rarity_col
		hover_style.set_border_width_all(2)
		btn.add_theme_stylebox_override("hover", hover_style)

		# Item icon from tiles.png via loy_tile_index
		var icon_tex = ItemIconHelper.get_icon_texture(item)
		if icon_tex:
			var icon = TextureRect.new()
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.texture = icon_tex
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.position = Vector2(SLOT_SIZE / 2 - 16, 2)
			icon.size = Vector2(32, 32)
			btn.add_child(icon)

		# Item name below icon
		var display = _short_name(item.item_name)
		btn.text = ""  # no button text, use label instead
		var name_label = Label.new()
		name_label.text = display
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.add_theme_color_override("font_color", rarity_col)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.position = Vector2(0, SLOT_SIZE - 20)
		name_label.size = Vector2(SLOT_SIZE, 18)
		btn.add_child(name_label)

		# Slot type icon in corner
		var slot_char = _slot_icon(item.slot_type)
		if slot_char != "":
			var slot_label = Label.new()
			slot_label.text = slot_char
			slot_label.add_theme_font_size_override("font_size", 9)
			slot_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			slot_label.position = Vector2(2, 2)
			btn.add_child(slot_label)

		btn.pressed.connect(_on_item_clicked.bind(i))
		_grid.add_child(btn)
		_slot_buttons.append(btn)

	# Adjust panel position to grow upward from bottom
	_reposition_panel()

func _reposition_panel() -> void:
	# Let the panel auto-size, then position so bottom-right is anchored
	await get_tree().process_frame
	var panel_w = GRID_COLS * SLOT_SIZE + PANEL_MARGIN * 2 + 20
	var row_count = ceili(float(_current_bag.items.size()) / GRID_COLS) if _current_bag else 0
	var panel_h = 30 + row_count * (SLOT_SIZE + 2) + 40  # title + grid + take all btn
	# Position: bottom-right, growing upward. Leave space for BAG button above
	var bottom_y = 1080 - 14
	_panel.position = Vector2(1920 - panel_w - 14, bottom_y - panel_h)

func _on_item_clicked(bag_index: int) -> void:
	if not _current_bag or not _equipment_manager:
		return
	if bag_index >= _current_bag.items.size():
		return

	var item = _current_bag.items[bag_index]
	if _equipment_manager.add_to_inventory(item):
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("collect_b", -4.0)
		_current_bag.items.remove_at(bag_index)
		if _current_bag.items.is_empty():
			_current_bag.queue_free()
			_current_bag = null
			_panel.visible = false
			_show_next_nearby_bag()
		else:
			_refresh()

func _on_take_all() -> void:
	if not _current_bag or not _equipment_manager:
		return

	var taken = 0
	# Take items from end to avoid index shifting
	var i = _current_bag.items.size() - 1
	while i >= 0:
		if _equipment_manager.add_to_inventory(_current_bag.items[i]):
			_current_bag.items.remove_at(i)
			taken += 1
		i -= 1
	if taken > 0:
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("collect_a", -3.0)

	if _current_bag.items.is_empty():
		_current_bag.queue_free()
		_current_bag = null
		_panel.visible = false
		_show_next_nearby_bag()
	else:
		_refresh()

func _short_name(name: String) -> String:
	if name.length() <= 8:
		return name
	return name.substr(0, 7) + "."

func _slot_icon(slot_type: EquipmentItem.SlotType) -> String:
	return ItemIconHelper.get_slot_name(slot_type).substr(0, 1)

func _get_item_sprite(eq_item: EquipmentItem) -> int:
	return ItemIconHelper.get_sprite_index(eq_item)
