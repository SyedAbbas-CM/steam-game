class_name ChestUI
extends CanvasLayer

## Full-screen scrollable chest inventory UI (like Skyrim containers).
## Shows all items in a chest with search/filter, scrollable grid, take/take all.

var _panel: PanelContainer
var _scroll: ScrollContainer
var _grid: GridContainer
var _title_label: Label
var _count_label: Label
var _take_all_btn: Button
var _close_btn: Button
var _filter_buttons: Dictionary = {}  # filter_name -> Button
var _current_chest: TestChest
var _equipment_manager: EquipmentManager
var _slot_buttons: Array[Button] = []
var _current_filter: String = "all"

const SLOT_SIZE = 100
const GRID_COLS = 8
const PANEL_W = 920
const PANEL_H = 720
const RARITY_COLORS = [
	Color(0.7, 0.7, 0.7),   # common
	Color(0.3, 0.9, 0.3),   # uncommon
	Color(0.3, 0.8, 1.0),   # rare
]
const RARITY_NAMES = ["Common", "Uncommon", "Rare"]
const TIER_COLORS = [
	Color(0.6, 0.6, 0.6),   # T0 grey
	Color(0.5, 0.8, 0.4),   # T1 green
	Color(0.3, 0.7, 1.0),   # T2 blue
	Color(0.7, 0.4, 1.0),   # T3 purple
	Color(1.0, 0.6, 0.2),   # T4 orange
	Color(1.0, 0.85, 0.2),  # T5 gold
]

## Compute item rating (total flat_bonus across all modifiers)
static func _get_item_rating(item: EquipmentItem) -> float:
	var rating: float = 0.0
	for mod in item.modifiers:
		rating += absf(mod.flat_bonus)
		rating += absf(mod.percent_bonus) * 20.0  # weight % bonuses
	if item.heal_hp > 0:
		rating += item.heal_hp * 0.5
	if item.heal_mp > 0:
		rating += item.heal_mp * 0.3
	return rating

## Compute tier from weapon damage or total item rating
static func _get_item_tier(item: EquipmentItem) -> int:
	# For weapons: tier based on attack damage flat_bonus
	if EquipmentItem.is_weapon_slot(item.slot_type):
		var dmg: float = 0.0
		for mod in item.modifiers:
			if mod.stat == StatModifier.StatType.ATTACK_DAMAGE:
				dmg += mod.flat_bonus
		if dmg >= 30: return 5
		if dmg >= 20: return 4
		if dmg >= 14: return 3
		if dmg >= 7: return 2
		if dmg >= 3: return 1
		return 0
	# For armor/accessories: tier based on total item rating
	var rating = _get_item_rating(item)
	if rating >= 25: return 5
	if rating >= 16: return 4
	if rating >= 10: return 3
	if rating >= 5: return 2
	if rating >= 2: return 1
	return 0

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("chest_ui")
	_build_ui()

func setup(equip_mgr: EquipmentManager) -> void:
	_equipment_manager = equip_mgr

func _build_ui() -> void:
	# Dimmer background
	var dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.5)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.size = Vector2(1920, 1080)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_close()
	)
	dimmer.name = "Dimmer"
	add_child(dimmer)

	# Main panel — centered
	_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.1, 0.95)
	style.border_color = Color(0.6, 0.45, 0.2)
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)
	_panel.position = Vector2((1920 - PANEL_W) / 2, (1080 - PANEL_H) / 2)
	_panel.size = Vector2(PANEL_W, PANEL_H)
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	# Header row: title + count + close button
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.text = "Chest"
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	header.add_child(_title_label)

	_count_label = Label.new()
	_count_label.text = ""
	_count_label.add_theme_font_size_override("font_size", 18)
	_count_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_count_label)

	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.add_theme_font_size_override("font_size", 16)
	_close_btn.custom_minimum_size = Vector2(30, 30)
	_close_btn.pressed.connect(_close)
	header.add_child(_close_btn)

	# Filter bar
	var filter_bar = HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", 4)
	vbox.add_child(filter_bar)

	var filters = ["all", "weapons", "armor", "consumables"]
	for f in filters:
		var btn = Button.new()
		btn.text = f.capitalize()
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 12)
		btn.toggle_mode = true
		btn.button_pressed = (f == "all")
		btn.pressed.connect(_set_filter.bind(f))
		filter_bar.add_child(btn)
		_filter_buttons[f] = btn

	# Scroll container with item grid
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = GRID_COLS
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 3)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)

	# Bottom: Take All button
	var bottom = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	vbox.add_child(bottom)

	_take_all_btn = Button.new()
	_take_all_btn.text = "Take All (Filtered)"
	_take_all_btn.focus_mode = Control.FOCUS_NONE
	_take_all_btn.add_theme_font_size_override("font_size", 14)
	_take_all_btn.pressed.connect(_on_take_all)
	bottom.add_child(_take_all_btn)

	# Start hidden
	_set_visible(false)

func show_chest(chest: TestChest) -> void:
	_current_chest = chest
	if not _equipment_manager:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			_equipment_manager = player.get_node_or_null("EquipmentManager") as EquipmentManager
	_current_filter = "all"
	_update_filter_buttons()
	_refresh()
	_set_visible(true)

func _close() -> void:
	_current_chest = null
	_set_visible(false)

func _set_visible(vis: bool) -> void:
	for child in get_children():
		if child is Control:
			child.visible = vis

func is_open() -> bool:
	return _panel.visible if _panel else false

func _set_filter(f: String) -> void:
	_current_filter = f
	_update_filter_buttons()
	_refresh()

func _update_filter_buttons() -> void:
	for key in _filter_buttons:
		_filter_buttons[key].button_pressed = (key == _current_filter)

func _get_filtered_items() -> Array:
	if not _current_chest:
		return []
	var result: Array = []
	for item in _current_chest.items:
		match _current_filter:
			"weapons":
				if EquipmentItem.is_weapon_slot(item.slot_type):
					result.append(item)
			"armor":
				if EquipmentItem.is_equippable(item.slot_type) and not EquipmentItem.is_weapon_slot(item.slot_type):
					result.append(item)
			"consumables":
				if item.slot_type == EquipmentItem.SlotType.CONSUMABLE or item.slot_type == EquipmentItem.SlotType.MATERIAL:
					result.append(item)
			_:
				result.append(item)
	return result

func _refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_slot_buttons.clear()

	if not _current_chest:
		return

	var filtered = _get_filtered_items()
	# Sort by tier (highest first), then by name
	filtered.sort_custom(func(a, b):
		var ta = _get_item_tier(a)
		var tb = _get_item_tier(b)
		if ta != tb: return ta > tb
		return a.item_name < b.item_name
	)
	_title_label.text = _current_chest.chest_label if _current_chest.chest_label != "" else "Chest"
	_count_label.text = "%d / %d items" % [filtered.size(), _current_chest.items.size()]

	for i in range(filtered.size()):
		var item = filtered[i]
		var btn = Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		btn.tooltip_text = _build_tooltip(item)

		var btn_style = StyleBoxFlat.new()
		var rarity_col = RARITY_COLORS[clampi(item.rarity, 0, 2)]
		btn_style.bg_color = Color(0.12, 0.1, 0.16)
		btn_style.border_color = rarity_col.darkened(0.3)
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(3)
		btn.add_theme_stylebox_override("normal", btn_style)

		var hover_style = btn_style.duplicate()
		hover_style.bg_color = Color(0.2, 0.18, 0.25)
		hover_style.border_color = rarity_col
		hover_style.set_border_width_all(2)
		btn.add_theme_stylebox_override("hover", hover_style)

		# Item icon — larger
		var icon_tex = ItemIconHelper.get_icon_texture(item)
		if icon_tex:
			var icon = TextureRect.new()
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.texture = icon_tex
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.position = Vector2(SLOT_SIZE / 2 - 24, 14)
			icon.size = Vector2(48, 48)
			btn.add_child(icon)

		# Item name
		var name_label = Label.new()
		name_label.text = _short_name(item.item_name)
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", rarity_col)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.position = Vector2(0, SLOT_SIZE - 32)
		name_label.size = Vector2(SLOT_SIZE, 16)
		btn.add_child(name_label)

		# Price label
		var price_label = Label.new()
		price_label.text = str(item.buy_price) + "g"
		price_label.add_theme_font_size_override("font_size", 10)
		price_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3))
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.position = Vector2(0, SLOT_SIZE - 18)
		price_label.size = Vector2(SLOT_SIZE, 14)
		btn.add_child(price_label)

		# Tier label in top-left corner
		var tier = _get_item_tier(item)
		var tier_label = Label.new()
		tier_label.text = "T" + str(tier)
		tier_label.add_theme_font_size_override("font_size", 12)
		tier_label.add_theme_color_override("font_color", TIER_COLORS[clampi(tier, 0, 5)])
		tier_label.position = Vector2(3, 1)
		btn.add_child(tier_label)

		# Item rating label in top-right corner
		var rating = _get_item_rating(item)
		if rating > 0:
			var pow_label = Label.new()
			pow_label.text = str(int(rating))
			pow_label.add_theme_font_size_override("font_size", 10)
			pow_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
			pow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			pow_label.position = Vector2(SLOT_SIZE - 28, 1)
			pow_label.size = Vector2(26, 14)
			btn.add_child(pow_label)

		btn.pressed.connect(_on_item_clicked.bind(item))
		_grid.add_child(btn)
		_slot_buttons.append(btn)

func _build_tooltip(item: EquipmentItem) -> String:
	var tier = _get_item_tier(item)
	var rating = _get_item_rating(item)
	var rarity_name = RARITY_NAMES[clampi(item.rarity, 0, 2)]
	var tip = item.get_display_name()
	tip += "\nTier " + str(tier) + " | " + rarity_name + " | Item Rating: " + str(int(rating))
	if item.description != "":
		tip += "\n" + item.description
	if item.buy_price > 0:
		tip += "\nBuy: " + str(item.buy_price) + "g"
	if item.weapon_type != "":
		tip += "\nType: " + item.weapon_type
	if item.socket_count > 0:
		tip += "\nSockets: %d/%d filled" % [item.get_socketed_gem_count(), item.socket_count]
	if item.archetype_tags.size() > 0:
		tip += "\nTags: " + ", ".join(Array(item.archetype_tags))
	for mod in item.modifiers:
		var stat_name = StatModifier.StatType.keys()[mod.stat] if mod.stat < StatModifier.StatType.size() else "?"
		if mod.flat_bonus != 0:
			tip += "\n+" + str(mod.flat_bonus) + " " + stat_name
		if mod.percent_bonus != 0:
			tip += "\n+" + str(mod.percent_bonus * 100) + "% " + stat_name
	if item.heal_hp > 0:
		tip += "\nHeals " + str(item.heal_hp) + " HP"
	if item.heal_mp > 0:
		tip += "\nRestores " + str(item.heal_mp) + " MP"
	if item.use_effect != "":
		tip += "\nEffect: " + item.use_effect
	if item.socket_count > 0:
		for socket_idx in range(item.socket_count):
			var socket_type = item.socket_types[socket_idx] if socket_idx < item.socket_types.size() else "open"
			var gem_path = item.socketed_gem_paths[socket_idx] if socket_idx < item.socketed_gem_paths.size() else ""
			var socket_label = "Socket %d [%s]" % [socket_idx + 1, socket_type.capitalize()]
			if gem_path != "":
				var gem = load(gem_path) as GemDefinition
				socket_label += ": " + (gem.gem_name if gem else "Filled")
			else:
				socket_label += ": Empty"
			tip += "\n" + socket_label
	return tip

func _on_item_clicked(item: EquipmentItem) -> void:
	if not _current_chest or not _equipment_manager:
		return
	var idx = _current_chest.items.find(item)
	if idx < 0:
		return
	if _equipment_manager.add_to_inventory(item):
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("collect_b", -4.0)
		_current_chest.items.remove_at(idx)
		_refresh()

func _on_take_all() -> void:
	if not _current_chest or not _equipment_manager:
		return
	var filtered = _get_filtered_items()
	var taken = 0
	for item in filtered:
		var idx = _current_chest.items.find(item)
		if idx >= 0 and _equipment_manager.add_to_inventory(item):
			_current_chest.items.remove_at(idx)
			taken += 1
	if taken > 0:
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("collect_a", -3.0)
	_refresh()

func _short_name(n: String) -> String:
	if n.length() <= 12:
		return n
	return n.substr(0, 11) + "."

func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		_close()
		get_viewport().set_input_as_handled()
