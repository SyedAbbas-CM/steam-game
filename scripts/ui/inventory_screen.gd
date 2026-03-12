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
var _close_btn: Button

const SLOT_SIZE = 88
const INV_COLS = 8
const INV_ROWS = 7
const ICON_SIZE = 52
const PANEL_BG = Color(0.06, 0.05, 0.1, 0.96)
const BORDER_COLOR = Color(0.45, 0.35, 0.15)
const EQUIPPED_BG = Color(0.08, 0.22, 0.08)
const NORMAL_BG = Color(0.09, 0.08, 0.13)

const RARITY_COLORS = [
	Color(0.65, 0.65, 0.65),  # common
	Color(0.3, 0.9, 0.3),     # uncommon
	Color(0.4, 0.85, 1.0),    # rare
]

var _overlay: ColorRect
var _toggle_cooldown: float = 0.0

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
	main_hbox.add_theme_constant_override("separation", 16)
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root_panel.add_child(main_hbox)

	# ===== LEFT: Inventory grid =====
	var inv_panel = _build_inventory_panel()
	inv_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(inv_panel)

	# ===== RIGHT: Stats + Tooltip =====
	var right_panel = _build_stats_panel()
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
	vbox.add_theme_constant_override("separation", 6)

	var title = Label.new()
	title.text = "INVENTORY"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	_inv_grid = GridContainer.new()
	_inv_grid.columns = INV_COLS
	_inv_grid.add_theme_constant_override("h_separation", 2)
	_inv_grid.add_theme_constant_override("v_separation", 2)
	vbox.add_child(_inv_grid)

	for i in range(INV_COLS * INV_ROWS):
		var btn = _create_inv_slot(i)
		_inv_grid.add_child(btn)
		_inv_buttons.append(btn)

	# Tooltip below inventory
	_tooltip_panel = PanelContainer.new()
	var tstyle = StyleBoxFlat.new()
	tstyle.bg_color = Color(0.08, 0.07, 0.12, 0.95)
	tstyle.border_color = Color(0.5, 0.4, 0.2)
	tstyle.set_border_width_all(1)
	tstyle.set_corner_radius_all(3)
	tstyle.content_margin_left = 8
	tstyle.content_margin_right = 8
	tstyle.content_margin_top = 4
	tstyle.content_margin_bottom = 4
	_tooltip_panel.add_theme_stylebox_override("panel", tstyle)
	_tooltip_panel.custom_minimum_size = Vector2(0, 60)
	_tooltip_panel.visible = false
	vbox.add_child(_tooltip_panel)

	var tip_vbox = VBoxContainer.new()
	tip_vbox.add_theme_constant_override("separation", 2)
	_tooltip_panel.add_child(tip_vbox)

	_tooltip_name = Label.new()
	_tooltip_name.add_theme_font_size_override("font_size", 14)
	_tooltip_name.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	tip_vbox.add_child(_tooltip_name)

	_tooltip_desc = Label.new()
	_tooltip_desc.add_theme_font_size_override("font_size", 11)
	_tooltip_desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_tooltip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip_vbox.add_child(_tooltip_desc)

	_tooltip_stats = Label.new()
	_tooltip_stats.add_theme_font_size_override("font_size", 11)
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

	btn.pressed.connect(_on_inv_slot_pressed.bind(index))
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

# ---- Refresh ----
func _refresh() -> void:
	if not equipment_manager or not _root_panel.visible:
		return
	_refresh_inv_grid()
	_refresh_stats()

func _refresh_inv_grid() -> void:
	for i in range(INV_COLS * INV_ROWS):
		var btn = _inv_buttons[i]
		# Remove old children
		for child in btn.get_children():
			child.queue_free()

		var sty = btn.get_theme_stylebox("normal") as StyleBoxFlat

		if i < equipment_manager.inventory.size():
			var item = equipment_manager.inventory[i]
			var is_eq = equipment_manager.is_equipped(item)

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

# ---- Interactions ----
func _on_inv_slot_pressed(index: int) -> void:
	if not equipment_manager or index >= equipment_manager.inventory.size():
		return
	equipment_manager.toggle_equip(index)

func _on_inv_hovered(index: int) -> void:
	if not equipment_manager or index >= equipment_manager.inventory.size():
		_hide_tooltip()
		return
	_show_item_tooltip(equipment_manager.inventory[index])

func _show_item_tooltip(item: EquipmentItem) -> void:
	_tooltip_panel.visible = true
	_tooltip_name.text = item.get_display_name()
	_tooltip_name.add_theme_color_override("font_color", RARITY_COLORS[clampi(item.rarity, 0, 2)])
	_tooltip_desc.text = item.description
	var stat_lines = []
	for mod in item.modifiers:
		var stat_name = StatModifier.StatType.keys()[mod.stat]
		if mod.flat_bonus != 0:
			stat_lines.append("+" + str(mod.flat_bonus) + " " + stat_name)
		if mod.percent_bonus != 0:
			stat_lines.append("+" + str(int(mod.percent_bonus * 100)) + "% " + stat_name)
	if item.enchantment:
		stat_lines.append("Enchant: " + item.enchantment.get_prefix())
	if item.ability_id != "":
		stat_lines.append("Ability: " + item.ability_id.replace("_", " ").capitalize())
		stat_lines.append("  MP: %.0f  CD: %.1fs" % [item.ability_mp_cost, item.ability_cooldown])
	var equipped_str = ""
	if equipment_manager and equipment_manager.is_equipped(item):
		equipped_str = " [EQUIPPED]"
	_tooltip_name.text = item.get_display_name() + equipped_str
	_tooltip_stats.text = "\n".join(stat_lines)

func _hide_tooltip() -> void:
	_tooltip_panel.visible = false

func _process(delta: float) -> void:
	if _toggle_cooldown > 0:
		_toggle_cooldown -= delta

func toggle() -> void:
	if _toggle_cooldown > 0:
		return
	_toggle_cooldown = 0.2
	var opening = not _root_panel.visible
	_root_panel.visible = opening
	_overlay.visible = opening
	_close_btn.visible = opening
	if opening:
		_refresh()

func is_open() -> bool:
	return _root_panel.visible

func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_I or event.keycode == KEY_TAB or event.keycode == KEY_ESCAPE:
			toggle()
			get_viewport().set_input_as_handled()
