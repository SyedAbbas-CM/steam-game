class_name InventoryScreen
extends CanvasLayer

var equipment_manager: EquipmentManager

# UI refs
var _root_panel: PanelContainer
var _inv_grid: GridContainer
var _inv_buttons: Array[Button] = []
var _tooltip_panel: PanelContainer
var _tooltip_name: Label
var _tooltip_desc: Label
var _tooltip_stats: Label
var _stats_label: Label
var _spells_label: Label
var _spells_container: VBoxContainer
var _close_btn: Button

const SLOT_SIZE = 108
const INV_COLS = 8
const INV_ROWS = 6
const ICON_SIZE = 64
const PANEL_BG = Color(0.06, 0.05, 0.1, 0.96)
const BORDER_COLOR = Color(0.45, 0.35, 0.15)
const EQUIPPED_BG = Color(0.08, 0.22, 0.08)
const NORMAL_BG = Color(0.09, 0.08, 0.13)

const RARITY_COLORS = [
	Color(0.65, 0.65, 0.65),  # common
	Color(0.3, 0.9, 0.3),     # uncommon
	Color(0.4, 0.85, 1.0),    # rare
]
const RARITY_NAMES = ["Common", "Uncommon", "Rare"]
const TIER_COLORS = [
	Color(0.6, 0.6, 0.6),   # T0
	Color(0.5, 0.8, 0.4),   # T1
	Color(0.3, 0.7, 1.0),   # T2
	Color(0.7, 0.4, 1.0),   # T3
	Color(1.0, 0.6, 0.2),   # T4
	Color(1.0, 0.85, 0.2),  # T5
]

var _overlay: ColorRect
var _toggle_cooldown: float = 0.0
var _drop_zone: Button

# Drag state
var _drag_active: bool = false
var _drag_display_idx: int = -1
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_mouse_down: bool = false
var _drag_ghost: TextureRect = null
const DRAG_THRESHOLD = 10.0

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("inventory_screen")
	_build_ui()
	# Start hidden
	_overlay.visible = false
	_root_panel.visible = false
	_close_btn.visible = false

func setup(equip_mgr: EquipmentManager) -> void:
	equipment_manager = equip_mgr
	equipment_manager.inventory_changed.connect(_refresh)
	equipment_manager.stats_changed.connect(_refresh)

func _build_ui() -> void:
	# Full-screen dark overlay — blocks game input when inventory is open
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# Main centered panel
	_root_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_root_panel.add_theme_stylebox_override("panel", style)

	# Fill the screen
	_root_panel.anchor_left = 0.01
	_root_panel.anchor_right = 0.99
	_root_panel.anchor_top = 0.01
	_root_panel.anchor_bottom = 0.99
	_root_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_root_panel)

	# Main horizontal layout: [Inventory | Stats]
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 24)
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_root_panel.add_child(main_hbox)

	# ===== LEFT: Inventory grid =====
	var inv_panel = _build_inventory_panel()
	inv_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(inv_panel)

	# ===== RIGHT: Stats + Tooltip =====
	var right_panel = _build_stats_panel()
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(right_panel)

	# Close button
	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.add_theme_font_size_override("font_size", 20)
	_close_btn.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	_close_btn.flat = true
	_close_btn.custom_minimum_size = Vector2(36, 36)
	_close_btn.anchor_left = 0.99
	_close_btn.anchor_right = 0.99
	_close_btn.anchor_top = 0.01
	_close_btn.anchor_bottom = 0.01
	_close_btn.offset_left = -44
	_close_btn.offset_right = -8
	_close_btn.offset_top = 8
	_close_btn.offset_bottom = 44
	_close_btn.pressed.connect(toggle)
	add_child(_close_btn)

func _build_inventory_panel() -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var title = Label.new()
	title.text = "INVENTORY"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	vbox.add_child(sep)

	# Scrollable grid area
	var grid_scroll = ScrollContainer.new()
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid_scroll)

	var grid_center = CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.add_child(grid_center)

	_inv_grid = GridContainer.new()
	_inv_grid.columns = INV_COLS
	_inv_grid.add_theme_constant_override("h_separation", 4)
	_inv_grid.add_theme_constant_override("v_separation", 4)
	grid_center.add_child(_inv_grid)

	for i in range(INV_COLS * INV_ROWS):
		var btn = _create_inv_slot(i)
		_inv_grid.add_child(btn)
		_inv_buttons.append(btn)

	# Drop zone — drag items here to drop them as loot bags
	_drop_zone = Button.new()
	_drop_zone.text = "DROP"
	_drop_zone.focus_mode = Control.FOCUS_NONE
	_drop_zone.custom_minimum_size = Vector2(0, 50)
	_drop_zone.add_theme_font_size_override("font_size", 18)
	_drop_zone.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	var drop_style = StyleBoxFlat.new()
	drop_style.bg_color = Color(0.2, 0.05, 0.05)
	drop_style.border_color = Color(0.6, 0.2, 0.2)
	drop_style.set_border_width_all(2)
	drop_style.set_corner_radius_all(4)
	_drop_zone.add_theme_stylebox_override("normal", drop_style)
	var drop_hover = drop_style.duplicate()
	drop_hover.bg_color = Color(0.35, 0.08, 0.08)
	drop_hover.border_color = Color(1.0, 0.3, 0.3)
	_drop_zone.add_theme_stylebox_override("hover", drop_hover)
	_drop_zone.visible = false
	vbox.add_child(_drop_zone)

	# Tooltip below inventory — larger fonts
	_tooltip_panel = PanelContainer.new()
	var tstyle = StyleBoxFlat.new()
	tstyle.bg_color = Color(0.08, 0.07, 0.12, 0.97)
	tstyle.border_color = Color(0.6, 0.5, 0.25)
	tstyle.set_border_width_all(2)
	tstyle.set_corner_radius_all(4)
	tstyle.content_margin_left = 14
	tstyle.content_margin_right = 14
	tstyle.content_margin_top = 10
	tstyle.content_margin_bottom = 10
	_tooltip_panel.add_theme_stylebox_override("panel", tstyle)
	_tooltip_panel.custom_minimum_size = Vector2(0, 100)
	_tooltip_panel.visible = false
	vbox.add_child(_tooltip_panel)

	var tip_vbox = VBoxContainer.new()
	tip_vbox.add_theme_constant_override("separation", 6)
	_tooltip_panel.add_child(tip_vbox)

	_tooltip_name = Label.new()
	_tooltip_name.add_theme_font_size_override("font_size", 22)
	_tooltip_name.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	tip_vbox.add_child(_tooltip_name)

	_tooltip_desc = Label.new()
	_tooltip_desc.add_theme_font_size_override("font_size", 17)
	_tooltip_desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_tooltip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip_vbox.add_child(_tooltip_desc)

	_tooltip_stats = Label.new()
	_tooltip_stats.add_theme_font_size_override("font_size", 17)
	_tooltip_stats.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	tip_vbox.add_child(_tooltip_stats)

	return vbox

func _build_stats_panel() -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.custom_minimum_size = Vector2(220, 0)

	var title = Label.new()
	title.text = "STATS"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 18)
	_stats_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(_stats_label)

	# Spells section
	var spell_sep = HSeparator.new()
	spell_sep.add_theme_constant_override("separation", 8)
	vbox.add_child(spell_sep)

	var spell_title = Label.new()
	spell_title.text = "SPELLS"
	spell_title.add_theme_font_size_override("font_size", 20)
	spell_title.add_theme_color_override("font_color", Color(0.6, 0.7, 1.0))
	spell_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(spell_title)

	# Scrollable spell list with equip buttons
	var spell_scroll = ScrollContainer.new()
	spell_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spell_scroll.custom_minimum_size.y = 150
	vbox.add_child(spell_scroll)

	_spells_container = VBoxContainer.new()
	_spells_container.add_theme_constant_override("separation", 4)
	spell_scroll.add_child(_spells_container)

	_spells_label = Label.new()
	_spells_label.add_theme_font_size_override("font_size", 15)
	_spells_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
	_spells_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_spells_container.add_child(_spells_label)

	return vbox

func _create_inv_slot(index: int) -> Button:
	var btn = Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	btn.text = ""
	btn.clip_text = true

	var sty = StyleBoxFlat.new()
	sty.bg_color = NORMAL_BG
	sty.border_color = Color(0.25, 0.25, 0.3)
	sty.set_border_width_all(1)
	sty.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("normal", sty)

	var hover_sty = sty.duplicate()
	hover_sty.bg_color = Color(0.16, 0.14, 0.22)
	hover_sty.border_color = Color(0.6, 0.5, 0.2)
	hover_sty.set_border_width_all(2)
	btn.add_theme_stylebox_override("hover", hover_sty)

	btn.gui_input.connect(_on_slot_gui_input.bind(index))
	btn.mouse_entered.connect(_on_inv_hovered.bind(index))
	btn.mouse_exited.connect(_hide_tooltip)
	return btn

func _make_icon_rect_for_item(item: EquipmentItem) -> TextureRect:
	var icon = TextureRect.new()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex = ItemIconHelper.get_icon_texture(item)
	if tex:
		icon.texture = tex
	return icon

# ---- Display list (stacks consumables + materials) ----
# Each entry: {item: EquipmentItem, count: int, inv_index: int, is_equipped: bool}
var _display_list: Array[Dictionary] = []

func _build_display_list() -> void:
	_display_list.clear()
	var stackable_groups: Dictionary = {}  # item_name -> index in _display_list
	for i in range(equipment_manager.inventory.size()):
		var item = equipment_manager.inventory[i]
		if item.slot_type == EquipmentItem.SlotType.CONSUMABLE or item.slot_type == EquipmentItem.SlotType.MATERIAL:
			if stackable_groups.has(item.item_name):
				_display_list[stackable_groups[item.item_name]]["count"] += 1
			else:
				stackable_groups[item.item_name] = _display_list.size()
				var is_eq = equipment_manager.is_equipped(item)
				_display_list.append({"item": item, "count": 1, "inv_index": i, "is_equipped": is_eq})
		else:
			var is_eq = equipment_manager.is_equipped(item)
			_display_list.append({"item": item, "count": 1, "inv_index": i, "is_equipped": is_eq})

# ---- Refresh ----
func _refresh() -> void:
	if not equipment_manager or not _root_panel.visible:
		return
	_build_display_list()
	_refresh_inv_grid()
	_refresh_stats()
	_refresh_spells()

func _refresh_inv_grid() -> void:
	# Dynamically adjust slot count to fit all items (minimum INV_COLS slots)
	var needed_slots = maxi(_display_list.size(), INV_COLS)
	# Round up to full row
	needed_slots = ceili(float(needed_slots) / INV_COLS) * INV_COLS
	while _inv_buttons.size() < needed_slots:
		var btn = _create_inv_slot(_inv_buttons.size())
		_inv_grid.add_child(btn)
		_inv_buttons.append(btn)
	# Hide excess buttons
	for i in range(_inv_buttons.size()):
		_inv_buttons[i].visible = i < needed_slots

	for i in range(needed_slots):
		var btn = _inv_buttons[i]
		# Remove old children
		for child in btn.get_children():
			child.queue_free()

		var sty = btn.get_theme_stylebox("normal") as StyleBoxFlat

		if i < _display_list.size():
			var entry = _display_list[i]
			var item = entry["item"] as EquipmentItem
			var is_eq = entry["is_equipped"] as bool
			var count = entry["count"] as int

			# Green background for equipped items
			if sty:
				if is_eq:
					sty.bg_color = EQUIPPED_BG
					sty.border_color = Color(0.2, 0.6, 0.2)
					sty.set_border_width_all(2)
				else:
					sty.bg_color = NORMAL_BG
					sty.border_color = RARITY_COLORS[clampi(item.rarity, 0, 2)].darkened(0.3)
					sty.set_border_width_all(1)

			# Icon
			var icon = _make_icon_rect_for_item(item)
			icon.position = Vector2(SLOT_SIZE / 2 - ICON_SIZE / 2, 2)
			btn.add_child(icon)

			# Item name below icon
			var name_lbl = Label.new()
			name_lbl.text = item.item_name.substr(0, 8) if item.item_name.length() > 8 else item.item_name
			name_lbl.add_theme_font_size_override("font_size", 12)
			var name_color = Color(0.4, 1.0, 0.4) if is_eq else RARITY_COLORS[clampi(item.rarity, 0, 2)]
			name_lbl.add_theme_color_override("font_color", name_color)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.position = Vector2(0, SLOT_SIZE - 20)
			name_lbl.size = Vector2(SLOT_SIZE, 18)
			name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(name_lbl)

			# "E" marker for equipped items
			if is_eq:
				var eq_lbl = Label.new()
				eq_lbl.text = "E"
				eq_lbl.add_theme_font_size_override("font_size", 10)
				eq_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
				eq_lbl.position = Vector2(2, 0)
				eq_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn.add_child(eq_lbl)

			# Stack count badge for consumables
			if count > 1:
				var count_lbl = Label.new()
				count_lbl.text = "x" + str(count)
				count_lbl.add_theme_font_size_override("font_size", 13)
				count_lbl.add_theme_color_override("font_color", Color(1, 1, 0.6))
				count_lbl.position = Vector2(SLOT_SIZE - 36, 2)
				count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn.add_child(count_lbl)

			# Tier badge (top-left, after E marker if equipped)
			var tier = ChestUI._get_item_tier(item)
			var tier_lbl = Label.new()
			tier_lbl.text = "T" + str(tier)
			tier_lbl.add_theme_font_size_override("font_size", 11)
			tier_lbl.add_theme_color_override("font_color", TIER_COLORS[clampi(tier, 0, 5)])
			tier_lbl.position = Vector2(SLOT_SIZE - 28, SLOT_SIZE - 34) if not is_eq else Vector2(14, 0)
			tier_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(tier_lbl)

			# Power number (top-right)
			var power = ChestUI._get_item_power(item)
			if power > 0 and count <= 1:
				var pow_lbl = Label.new()
				pow_lbl.text = str(int(power))
				pow_lbl.add_theme_font_size_override("font_size", 10)
				pow_lbl.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
				pow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				pow_lbl.position = Vector2(SLOT_SIZE - 28, 2)
				pow_lbl.size = Vector2(26, 14)
				pow_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn.add_child(pow_lbl)
		else:
			# Empty slot
			if sty:
				sty.bg_color = NORMAL_BG
				sty.border_color = Color(0.25, 0.25, 0.3)
				sty.set_border_width_all(1)

func _refresh_stats() -> void:
	if not equipment_manager:
		return
	var lines = []
	var player = get_tree().get_first_node_in_group("player")

	if player:
		lines.append("HP: %d / %d" % [player.hp, player.max_hp])
	lines.append("ATK: %d" % equipment_manager.get_damage())
	lines.append("SPD: %d" % int(equipment_manager.get_move_speed()))
	lines.append("AS: %.2f s" % equipment_manager.get_attack_speed())
	lines.append("Bullet SPD: %d" % int(equipment_manager.get_bullet_speed()))
	lines.append("Pierce: %d" % equipment_manager.get_pierce_count())
	lines.append("Crit DMG: %.0f%%" % (equipment_manager.get_crit_damage() * 100))
	lines.append("Luck: %.0f" % equipment_manager.get_luck())
	lines.append("Armor: %.0f" % equipment_manager.get_armor())
	lines.append("Dodge: %.0f%%" % equipment_manager.get_dodge_chance())
	lines.append("XP Mult: %.0f%%" % (equipment_manager.get_xp_mult() * 100))
	lines.append("Gold Mult: %.0f%%" % (equipment_manager.get_gold_mult() * 100))
	lines.append("Pickup: %.0f" % equipment_manager.get_pickup_radius())
	_stats_label.text = "\n".join(lines)

const SPELL_KEY_NAMES = ["F", "G", "H", "J", "K", "L"]

func _refresh_spells() -> void:
	if not _spells_container:
		return
	# Clear old spell rows (keep _spells_label)
	for child in _spells_container.get_children():
		if child != _spells_label:
			child.queue_free()

	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.get("spell_book"):
		_spells_label.text = "No spells learned"
		return
	var sb = player.spell_book as SpellBook
	if not sb or sb.learned_spells.is_empty():
		_spells_label.text = "No spells learned"
		return

	_spells_label.text = ""  # Clear default text

	var ls = player.get_node_or_null("LevelSystem") as LevelSystem
	var spirit = 0
	if ls:
		spirit = ls.allocated.get("spirit", 0)
	var max_slots = sb.get_max_slots(1, spirit)

	for spell in sb.learned_spells:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		# Spell name + info
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lbl = Label.new()
		# Find current slot
		var cur_slot = -1
		for i in range(SpellBook.MAX_SPELL_SLOTS):
			if sb.spell_slots[i] and sb.spell_slots[i].id == spell.id:
				cur_slot = i
				break
		var slot_str = " [%s]" % SPELL_KEY_NAMES[cur_slot] if cur_slot >= 0 else ""
		name_lbl.text = spell.spell_name + slot_str
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0) if cur_slot >= 0 else Color(0.7, 0.7, 0.8))
		info.add_child(name_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = "MP:%.0f CD:%.1fs" % [spell.mp_cost, spell.cooldown]
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		info.add_child(desc_lbl)
		row.add_child(info)

		# Slot assignment buttons
		for si in range(max_slots):
			var btn = Button.new()
			btn.text = SPELL_KEY_NAMES[si]
			btn.add_theme_font_size_override("font_size", 11)
			btn.custom_minimum_size = Vector2(28, 28)
			btn.focus_mode = Control.FOCUS_NONE
			if cur_slot == si:
				btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
			btn.pressed.connect(_on_spell_slot_assign.bind(spell, si))
			row.add_child(btn)

		_spells_container.add_child(row)

func _on_spell_slot_assign(spell: SpellDefinition, slot: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.get("spell_book"):
		return
	var sb = player.spell_book as SpellBook
	sb.equip_spell(spell, slot)
	_refresh_spells()
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("select_a", -4.0)

# ---- Drag & Drop ----
func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if slot_index < _display_list.size():
				_drag_mouse_down = true
				_drag_display_idx = slot_index
				_drag_start_pos = event.global_position
		else:
			if _drag_active:
				_end_drag(event.global_position)
			elif _drag_mouse_down and _drag_display_idx == slot_index:
				# Short click — equip or use
				_on_inv_slot_clicked(slot_index)
			_drag_mouse_down = false
			_drag_active = false
			_drag_display_idx = -1
	elif event is InputEventMouseMotion and _drag_mouse_down and not _drag_active:
		if event.global_position.distance_to(_drag_start_pos) > DRAG_THRESHOLD:
			_start_drag(_drag_display_idx)

func _on_inv_slot_clicked(index: int) -> void:
	if not equipment_manager or index >= _display_list.size():
		return
	var entry = _display_list[index]
	var item = entry["item"] as EquipmentItem
	var inv_index = entry["inv_index"] as int
	var sfx = get_node_or_null("/root/SFXManager")
	if item.slot_type == EquipmentItem.SlotType.CONSUMABLE:
		equipment_manager.use_consumable(inv_index)
	else:
		equipment_manager.toggle_equip(inv_index)
		if sfx:
			sfx.play("click", -4.0)

func _start_drag(display_idx: int) -> void:
	if display_idx < 0 or display_idx >= _display_list.size():
		return
	_drag_active = true
	_drop_zone.visible = true
	var item = _display_list[display_idx]["item"] as EquipmentItem
	# Create ghost icon following mouse
	_drag_ghost = TextureRect.new()
	_drag_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_drag_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_ghost.size = Vector2(ICON_SIZE, ICON_SIZE)
	_drag_ghost.modulate = Color(1, 1, 1, 0.7)
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex = ItemIconHelper.get_icon_texture(item)
	if tex:
		_drag_ghost.texture = tex
	_drag_ghost.position = _drag_start_pos - Vector2(ICON_SIZE / 2, ICON_SIZE / 2)
	add_child(_drag_ghost)

func _end_drag(drop_pos: Vector2) -> void:
	if _drag_ghost:
		_drag_ghost.queue_free()
		_drag_ghost = null
	_drop_zone.visible = false
	if _drag_display_idx < 0 or _drag_display_idx >= _display_list.size():
		return
	var entry = _display_list[_drag_display_idx]
	var item = entry["item"] as EquipmentItem
	var inv_index = entry["inv_index"] as int

	# Check if dropped on the DROP zone
	var drop_rect = Rect2(_drop_zone.global_position, _drop_zone.size)
	if drop_rect.has_point(drop_pos):
		# Don't drop equipped items — unequip first
		if equipment_manager.is_equipped(item):
			return
		_drop_item_to_world(inv_index)
		return

	# Check if dropped on a quickbar slot
	var hud = _get_hud()
	if hud:
		var qb_slot = hud.get_quickbar_slot_at_pos(drop_pos)
		if qb_slot >= 0:
			hud.assign_to_quickbar(qb_slot, item.item_name)
			return

	# Check if dropped on another inventory slot (swap)
	var target_slot = _get_inv_slot_at_pos(drop_pos)
	if target_slot >= 0 and target_slot != _drag_display_idx:
		_swap_display_items(_drag_display_idx, target_slot)

func _get_inv_slot_at_pos(screen_pos: Vector2) -> int:
	for i in range(_inv_buttons.size()):
		var btn = _inv_buttons[i]
		var global_rect = Rect2(btn.global_position, btn.size)
		if global_rect.has_point(screen_pos):
			return i
	return -1

func _swap_display_items(from_display: int, to_display: int) -> void:
	if from_display >= _display_list.size():
		return
	var from_inv = _display_list[from_display]["inv_index"] as int
	if to_display < _display_list.size():
		# Swap two items in actual inventory
		var to_inv = _display_list[to_display]["inv_index"] as int
		var temp = equipment_manager.inventory[from_inv]
		equipment_manager.inventory[from_inv] = equipment_manager.inventory[to_inv]
		equipment_manager.inventory[to_inv] = temp
	else:
		# Move item to empty slot — move to end of inventory
		var item = equipment_manager.inventory[from_inv]
		equipment_manager.inventory.remove_at(from_inv)
		equipment_manager.inventory.append(item)
	equipment_manager.inventory_changed.emit()

func _get_hud() -> GameHUD:
	var hud = get_tree().get_first_node_in_group("game_hud")
	if not hud:
		for node in get_tree().root.get_children():
			if node is GameHUD:
				return node
	return hud

func _on_inv_hovered(index: int) -> void:
	if not equipment_manager or index >= _display_list.size():
		_hide_tooltip()
		return
	_show_item_tooltip(_display_list[index]["item"] as EquipmentItem)

func _show_item_tooltip(item: EquipmentItem) -> void:
	_tooltip_panel.visible = true
	var tier = ChestUI._get_item_tier(item)
	var power = ChestUI._get_item_power(item)
	var rarity_name = RARITY_NAMES[clampi(item.rarity, 0, 2)]
	var equipped_str = ""
	if equipment_manager and equipment_manager.is_equipped(item):
		equipped_str = " [EQUIPPED]"
	_tooltip_name.text = item.get_display_name() + equipped_str
	_tooltip_name.add_theme_color_override("font_color", RARITY_COLORS[clampi(item.rarity, 0, 2)])
	_tooltip_desc.text = "Tier " + str(tier) + " | " + rarity_name + " | Power: " + str(int(power))
	if item.description != "":
		_tooltip_desc.text += "\n" + item.description
	if item.weapon_type != "":
		_tooltip_desc.text += "\nType: " + item.weapon_type
	if item.buy_price > 0:
		_tooltip_desc.text += "\nValue: " + str(item.buy_price) + "g"
	var stat_lines = []
	for mod in item.modifiers:
		var stat_name = StatModifier.StatType.keys()[mod.stat]
		if mod.flat_bonus != 0:
			stat_lines.append("+" + str(mod.flat_bonus) + " " + stat_name)
		if mod.percent_bonus != 0:
			stat_lines.append("+" + str(int(mod.percent_bonus * 100)) + "% " + stat_name)
	if item.heal_hp > 0:
		stat_lines.append("Heals +" + str(item.heal_hp) + " HP")
	if item.heal_mp > 0:
		stat_lines.append("Restores +" + str(item.heal_mp) + " MP")
	if item.use_effect != "":
		stat_lines.append("Effect: " + item.use_effect)
	if item.enchantment:
		stat_lines.append("Enchant: " + item.enchantment.get_prefix())
	if item.ability_id != "":
		stat_lines.append("Ability: " + item.ability_id.replace("_", " ").capitalize())
		stat_lines.append("  MP: %.0f  CD: %.1fs" % [item.ability_mp_cost, item.ability_cooldown])
	_tooltip_stats.text = "\n".join(stat_lines)

func _hide_tooltip() -> void:
	_tooltip_panel.visible = false

func _process(delta: float) -> void:
	if _toggle_cooldown > 0:
		_toggle_cooldown -= delta
	if _drag_active and _drag_ghost:
		_drag_ghost.position = get_viewport().get_mouse_position() - Vector2(ICON_SIZE / 2, ICON_SIZE / 2)

func toggle() -> void:
	if _toggle_cooldown > 0:
		return
	_toggle_cooldown = 0.2
	var opening = not _root_panel.visible
	_root_panel.visible = opening
	_overlay.visible = opening
	_close_btn.visible = opening
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("paper" if opening else "close", -4.0, 0.0)
	if opening:
		_refresh()
	else:
		_cancel_drag()
	# Hide/show HUD panels but keep quickbar visible for assignment
	var hud = _get_hud()
	if hud:
		hud.set_non_quickbar_visible(not opening)

func is_open() -> bool:
	return _root_panel.visible

func _input(event: InputEvent) -> void:
	if not is_open():
		return
	# Cancel drag on right-click or escape
	if _drag_active:
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_end_drag(event.global_position)
			_drag_mouse_down = false
			_drag_active = false
			_drag_display_idx = -1
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_drag()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _drag_active:
				_cancel_drag()
			else:
				toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_I or event.keycode == KEY_TAB:
			toggle()
			get_viewport().set_input_as_handled()

func _drop_item_to_world(inv_index: int) -> void:
	var item = equipment_manager.inventory[inv_index] if inv_index < equipment_manager.inventory.size() else null
	if not item:
		return
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Collect all items in the stack (same name, consumable/material)
	var items_to_drop: Array[EquipmentItem] = []
	if item.slot_type == EquipmentItem.SlotType.CONSUMABLE or item.slot_type == EquipmentItem.SlotType.MATERIAL:
		var drop_name = item.item_name
		# Collect indices in reverse to safely remove
		var indices: Array[int] = []
		for i in range(equipment_manager.inventory.size()):
			if equipment_manager.inventory[i].item_name == drop_name:
				indices.append(i)
		# Remove in reverse order
		indices.reverse()
		for idx in indices:
			items_to_drop.append(equipment_manager.remove_from_inventory(idx))
	else:
		items_to_drop.append(equipment_manager.remove_from_inventory(inv_index))

	if items_to_drop.is_empty():
		return

	var bag = LootBag.new()
	for dropped in items_to_drop:
		bag.items.append(dropped)
	bag.position = player.global_position + Vector2(randf_range(-12, 12), randf_range(8, 16))
	player.get_parent().add_child(bag)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("fall", -5.0, 0.1)

func _cancel_drag() -> void:
	if _drag_ghost:
		_drag_ghost.queue_free()
		_drag_ghost = null
	_drag_active = false
	_drag_mouse_down = false
	_drag_display_idx = -1
	_drop_zone.visible = false
