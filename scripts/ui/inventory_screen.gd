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
var _tooltip_req: Label
var _stats_label: Label
var _show_combat_stats: bool = false
var _combat_stats_toggle: Button
var _close_btn: Button
var _menu_btn: Button
var _inv_scroll: ScrollContainer
var _stat_alloc_container: VBoxContainer
var _stat_points_label: Label
var _quickslot_container: VBoxContainer
var _quickslot_buttons: Array[Button] = []
const QS_SIZE = 64
const QS_ICON_SIZE = 44
const QS_SLOTS = 6

# Spell slots + drag
var _spell_slot_buttons: Array[Button] = []
var _spell_grid_buttons: Array[Button] = []
var _spell_drag_active: bool = false
var _spell_drag_idx: int = -1
var _spell_drag_ghost: TextureRect = null
var _spell_drag_start: Vector2 = Vector2.ZERO
var _spell_drag_mouse_down: bool = false
const SPELL_SLOT_KEYS = ["F", "G", "H", "J", "K", "L"]
const SS_SIZE = 56
const SS_ICON_SIZE = 36

# Tab system
var _current_tab: String = "items"
var _items_content: VBoxContainer
var _spells_content: VBoxContainer
var _socket_content: VBoxContainer
var _salvage_content: VBoxContainer
var _tab_items_btn: Button
var _tab_spells_btn: Button
var _tab_socket_btn: Button
var _tab_salvage_btn: Button
var _spell_inv_grid: GridContainer
const SPELL_INV_COLS = 8

# Socket tab state
var _socket_selected_item: EquipmentItem = null
var _socket_selected_idx: int = -1
var _socket_active_socket: int = -1  # which socket is waiting for a gem
var _socket_item_grid: HBoxContainer
var _socket_detail_panel: VBoxContainer
var _socket_gem_grid: GridContainer

# Salvage tab state
var _salvage_selected_item: EquipmentItem = null
var _salvage_selected_idx: int = -1
var _salvage_item_grid: GridContainer
var _salvage_preview: VBoxContainer
var _salvage_bp_list: VBoxContainer
var _salvage_points_label: Label

const SLOT_SIZE = 108
const INV_COLS = 8
const INV_ROWS = 6
const ICON_SIZE = 64
## Ashfields palette — keep in sync with assets/themes/ashfields_theme.tres
const PANEL_BG = Color(0.110, 0.098, 0.090, 0.97)   # bg_panel
const BORDER_COLOR = Color(0.471, 0.443, 0.420)     # border_lit
const EQUIPPED_BG = Color(0.094, 0.137, 0.075, 1.0) # warm green tint
const NORMAL_BG = Color(0.075, 0.067, 0.060, 1.0)   # bg_deep warm

## Rarity colors keyed to gold/blood/arcane palette
const RARITY_COLORS = [
	Color(0.659, 0.635, 0.616),   # 0 common — muted bone
	Color(0.792, 0.541, 0.016),   # 1 uncommon — gold
	Color(0.486, 0.227, 0.929),   # 2 rare — arcane purple
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
	_menu_btn.visible = false

func setup(equip_mgr: EquipmentManager) -> void:
	equipment_manager = equip_mgr
	equipment_manager.inventory_changed.connect(_refresh)
	equipment_manager.stats_changed.connect(_refresh)
	equipment_manager.equip_failed.connect(_on_equip_failed)

func _build_ui() -> void:
	var ashfields_theme = load("res://assets/themes/ashfields_theme.tres") as Theme

	# Full-screen dark overlay — blocks game input when inventory is open
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# Main centered panel
	_root_panel = PanelContainer.new()
	if ashfields_theme:
		_root_panel.theme = ashfields_theme
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

	# Root layout: a vertical column with the main HBox on top and the tooltip
	# pinned to the bottom. This way the tooltip has its OWN dedicated space
	# and showing it never shrinks the inventory grid.
	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root_panel.add_child(root_vbox)

	# Main horizontal layout: [Center (tabs) | Stats]
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 24)
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(main_hbox)

	# ===== CENTER: Tabbed content (Items / Spells) =====
	var center_vbox = VBoxContainer.new()
	center_vbox.add_theme_constant_override("separation", 6)
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(center_vbox)

	# Tab bar
	var tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 8)
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_child(tab_bar)

	_tab_items_btn = _create_tab_button("ITEMS", true)
	_tab_items_btn.pressed.connect(_switch_tab.bind("items"))
	tab_bar.add_child(_tab_items_btn)

	_tab_spells_btn = _create_tab_button("SPELLS", false)
	_tab_spells_btn.pressed.connect(_switch_tab.bind("spells"))
	tab_bar.add_child(_tab_spells_btn)

	_tab_socket_btn = _create_tab_button("SOCKET", false)
	_tab_socket_btn.pressed.connect(_switch_tab.bind("socket"))
	tab_bar.add_child(_tab_socket_btn)

	_tab_salvage_btn = _create_tab_button("SALVAGE", false)
	_tab_salvage_btn.pressed.connect(_switch_tab.bind("salvage"))
	tab_bar.add_child(_tab_salvage_btn)

	# Items tab content — gets all of the center column vertical space now.
	_items_content = _build_inventory_panel()
	_items_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_vbox.add_child(_items_content)

	# Spells panel still built (so refresh code keeps working) but never added
	# to the layout. Spells now appear as tiles INSIDE the inventory grid —
	# they're listed alongside items so the big inventory area can hold everything.
	_spells_content = _build_spells_tab()
	_spells_content.visible = false

	# Socket tab content
	_socket_content = _build_socket_tab()
	_socket_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_socket_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_socket_content.visible = false
	center_vbox.add_child(_socket_content)

	# Salvage tab content
	_salvage_content = _build_salvage_tab()
	_salvage_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_salvage_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_salvage_content.visible = false
	center_vbox.add_child(_salvage_content)

	# Quickslot sidebar removed — the HUD quickbar (bottom of screen) stays
	# visible while inventory is open, and number keys 1-6 / clicks on it
	# handle equip + use. We still build the panel for `_refresh_quickslots`
	# to update internally; just don't add it to the layout.
	_build_quickslot_panel()

	# ===== RIGHT: Stats =====
	var right_panel = _build_stats_panel()
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(right_panel)

	# Tooltip lives at the bottom of root_vbox, OUTSIDE the inventory column.
	# It has dedicated reserved height so showing the description never resizes
	# the inventory grid above (which was scrolling itself off-screen).
	var tooltip_panel := _build_tooltip_panel()
	tooltip_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(tooltip_panel)

	# Close button
	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.add_theme_font_size_override("font_size", 34)
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

	# Main Menu button — sits next to the X, saves and returns to title
	_menu_btn = Button.new()
	_menu_btn.text = "Main Menu"
	_menu_btn.focus_mode = Control.FOCUS_NONE
	_menu_btn.add_theme_font_size_override("font_size", 18)
	_menu_btn.add_theme_color_override("font_color", Color(0.85, 0.75, 0.4))
	_menu_btn.flat = true
	_menu_btn.anchor_left = 0.99
	_menu_btn.anchor_right = 0.99
	_menu_btn.anchor_top = 0.01
	_menu_btn.anchor_bottom = 0.01
	_menu_btn.offset_left = -188
	_menu_btn.offset_right = -50
	_menu_btn.offset_top = 12
	_menu_btn.offset_bottom = 40
	_menu_btn.pressed.connect(_on_main_menu_pressed)
	add_child(_menu_btn)

func _on_main_menu_pressed() -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("select_a", -4.0)
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.save_data and gm.active_slot >= 0:
		gm.save_data.save_to_slot()
	if gm and gm.has_method("go_to_start_screen"):
		gm.go_to_start_screen()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")

func _create_tab_button(text: String, active: bool) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(120, 36)
	btn.add_theme_font_size_override("font_size", 34)
	var sty = StyleBoxFlat.new()
	sty.set_corner_radius_all(4)
	sty.content_margin_left = 16
	sty.content_margin_right = 16
	sty.content_margin_top = 4
	sty.content_margin_bottom = 4
	if active:
		sty.bg_color = Color(0.15, 0.12, 0.25)
		sty.border_color = Color(0.6, 0.5, 0.2)
		sty.set_border_width_all(2)
		btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	else:
		sty.bg_color = Color(0.08, 0.07, 0.12)
		sty.border_color = Color(0.3, 0.3, 0.4)
		sty.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	btn.add_theme_stylebox_override("normal", sty)
	var hover = sty.duplicate()
	hover.bg_color = Color(0.18, 0.15, 0.28)
	hover.border_color = Color(0.7, 0.6, 0.3)
	hover.set_border_width_all(2)
	btn.add_theme_stylebox_override("hover", hover)
	return btn

func _switch_tab(tab_name: String) -> void:
	_current_tab = tab_name
	# Spells live on the inventory tab now — show both together. Socket/salvage
	# stay isolated because the blacksmith opens them in a focused mode.
	var show_items_and_spells := tab_name == "items" or tab_name == "spells"
	_items_content.visible = show_items_and_spells
	_spells_content.visible = show_items_and_spells
	_socket_content.visible = tab_name == "socket"
	_salvage_content.visible = tab_name == "salvage"
	_update_tab_style(_tab_items_btn, tab_name == "items")
	_update_tab_style(_tab_spells_btn, tab_name == "spells")
	_update_tab_style(_tab_socket_btn, tab_name == "socket")
	_update_tab_style(_tab_salvage_btn, tab_name == "salvage")
	if tab_name == "spells":
		_refresh_spells_tab()
	elif tab_name == "socket":
		_refresh_socket_tab()
	elif tab_name == "salvage":
		_refresh_salvage_tab()
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click", -4.0)

func open_to_tab(tab_name: String) -> void:
	if not _root_panel.visible:
		_root_panel.visible = true
		_overlay.visible = true
		_close_btn.visible = true
		_menu_btn.visible = true
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("paper", -4.0, 0.0)
		_refresh()
		var hud = _get_hud()
		if hud:
			hud.set_non_quickbar_visible(false)
	_apply_tab_visibility(tab_name)
	_switch_tab(tab_name)

## Tab visibility:
## - "items" → ITEMS tab only (spells now embedded inside the items view, not a tab)
## - "socket"  → ITEMS + SOCKET (opened from blacksmith only)
## - "salvage" → ITEMS + SALVAGE (opened from blacksmith only)
func _apply_tab_visibility(mode_tab: String) -> void:
	_tab_items_btn.visible = true
	_tab_spells_btn.visible = false  # spells are inline on the items tab
	_tab_socket_btn.visible = mode_tab == "socket"
	_tab_salvage_btn.visible = mode_tab == "salvage"

func _update_tab_style(btn: Button, active: bool) -> void:
	var sty = btn.get_theme_stylebox("normal") as StyleBoxFlat
	if sty:
		if active:
			sty.bg_color = Color(0.15, 0.12, 0.25)
			sty.border_color = Color(0.6, 0.5, 0.2)
			sty.set_border_width_all(2)
			btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		else:
			sty.bg_color = Color(0.08, 0.07, 0.12)
			sty.border_color = Color(0.3, 0.3, 0.4)
			sty.set_border_width_all(1)
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))

func _build_inventory_panel() -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var title = Label.new()
	title.text = "INVENTORY"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	vbox.add_child(sep)

	# Scrollable grid area
	_inv_scroll = ScrollContainer.new()
	_inv_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inv_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_inv_scroll)
	var grid_scroll = _inv_scroll

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
	_drop_zone.add_theme_font_size_override("font_size", 32)
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

	# Tooltip is built separately and anchored to the bottom of _root_panel so
	# it has dedicated space and doesn't push the inventory grid around.
	return vbox


## Build the item-details tooltip. The caller (_build_ui) anchors it to
## the bottom of _root_panel so showing/hiding the tooltip never reflows
## the inventory grid above it.
func _build_tooltip_panel() -> Control:
	_tooltip_panel = AshfieldsUI.ornate_panel(14)
	_tooltip_panel.custom_minimum_size = Vector2(0, 180)
	_tooltip_panel.modulate.a = 0.0
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tip_vbox = VBoxContainer.new()
	tip_vbox.add_theme_constant_override("separation", 8)
	_tooltip_panel.add_child(tip_vbox)

	_tooltip_name = Label.new()
	_tooltip_name.add_theme_font_size_override("font_size", 36)
	_tooltip_name.add_theme_color_override("font_color", AshfieldsUI.GOLD)
	_tooltip_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_tooltip_name.add_theme_constant_override("outline_size", 2)
	tip_vbox.add_child(_tooltip_name)

	var under := ColorRect.new()
	under.color = AshfieldsUI.GOLD_DARK
	under.custom_minimum_size = Vector2(0, 1)
	under.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_vbox.add_child(under)

	_tooltip_desc = Label.new()
	_tooltip_desc.add_theme_font_size_override("font_size", 30)
	_tooltip_desc.add_theme_color_override("font_color", AshfieldsUI.TEXT_MUTED)
	_tooltip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip_vbox.add_child(_tooltip_desc)

	_tooltip_stats = Label.new()
	_tooltip_stats.add_theme_font_size_override("font_size", 30)
	_tooltip_stats.add_theme_color_override("font_color", Color(0.6, 0.95, 0.55))
	tip_vbox.add_child(_tooltip_stats)

	_tooltip_req = Label.new()
	_tooltip_req.add_theme_font_size_override("font_size", 26)
	_tooltip_req.add_theme_color_override("font_color", AshfieldsUI.BLOOD.lightened(0.25))
	tip_vbox.add_child(_tooltip_req)

	return _tooltip_panel

func _build_spells_tab() -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	# Spell equip slots — horizontal row at top
	var slots_label = Label.new()
	slots_label.text = "EQUIPPED SPELLS  (click to unequip)"
	slots_label.add_theme_font_size_override("font_size", 32)
	slots_label.add_theme_color_override("font_color", Color(0.6, 0.7, 1.0))
	slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(slots_label)

	var slots_hbox = HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 8)
	slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(slots_hbox)

	_spell_slot_buttons.clear()
	for i in range(7):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		btn.focus_mode = Control.FOCUS_NONE
		var sty = StyleBoxFlat.new()
		sty.bg_color = Color(0.06, 0.06, 0.16, 0.85)
		sty.border_color = Color(0.3, 0.25, 0.5)
		sty.set_border_width_all(1)
		sty.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sty)
		var hover = sty.duplicate()
		hover.bg_color = Color(0.12, 0.1, 0.25, 0.9)
		hover.border_color = Color(0.6, 0.4, 0.8)
		hover.set_border_width_all(2)
		btn.add_theme_stylebox_override("hover", hover)
		btn.pressed.connect(_on_spell_slot_clicked.bind(i))
		slots_hbox.add_child(btn)
		_spell_slot_buttons.append(btn)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	vbox.add_child(sep)

	var learned_label = Label.new()
	learned_label.text = "LEARNED SPELLS  (drag to equip)"
	learned_label.add_theme_font_size_override("font_size", 28)
	learned_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7))
	learned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(learned_label)

	# Scrollable grid of learned spells (same size as item inventory)
	var spell_scroll = ScrollContainer.new()
	spell_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spell_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(spell_scroll)

	var grid_center = CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spell_scroll.add_child(grid_center)

	_spell_inv_grid = GridContainer.new()
	_spell_inv_grid.columns = SPELL_INV_COLS
	_spell_inv_grid.add_theme_constant_override("h_separation", 4)
	_spell_inv_grid.add_theme_constant_override("v_separation", 4)
	grid_center.add_child(_spell_inv_grid)

	return vbox

func _refresh_spells_tab() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.get("spell_book"):
		return
	var sb: SpellBook = player.spell_book

	# Refresh equipped spell slots (top row). Walks all 7 buttons; the unified
	# action bar has 10 spell slots, but only 7 fit in this top-row chrome.
	for i in range(_spell_slot_buttons.size()):
		var btn = _spell_slot_buttons[i]
		for child in btn.get_children():
			child.queue_free()

		var spell = sb.spell_slots[i] if i < sb.spell_slots.size() else null

		if spell:
			var color = _get_spell_color(spell)
			var icon_rect = ColorRect.new()
			icon_rect.color = color
			icon_rect.size = Vector2(ICON_SIZE, ICON_SIZE)
			icon_rect.position = Vector2((SLOT_SIZE - ICON_SIZE) / 2, 2)
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(icon_rect)

			var name_lbl = Label.new()
			name_lbl.text = spell.spell_name.substr(0, 8) if spell.spell_name.length() > 8 else spell.spell_name
			name_lbl.add_theme_font_size_override("font_size", 24)
			name_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.position = Vector2(0, SLOT_SIZE - 20)
			name_lbl.size = Vector2(SLOT_SIZE, 18)
			name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(name_lbl)

			var mp_lbl = Label.new()
			mp_lbl.text = "MP:%.0f" % spell.mp_cost
			mp_lbl.add_theme_font_size_override("font_size", 20)
			mp_lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
			mp_lbl.position = Vector2(SLOT_SIZE - 42, 2)
			mp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(mp_lbl)

		# Hotkey number labels (FGHJKL → 1-0) removed: the action-bar tile in the
		# main HUD already shows the hotkey number, and these tiles map to the
		# same slot index, so doubling the badge here only added visual noise.

	# Refresh learned spells grid (big inventory-style)
	for child in _spell_inv_grid.get_children():
		child.queue_free()
	_spell_grid_buttons.clear()

	for j in range(sb.learned_spells.size()):
		var spell = sb.learned_spells[j]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		btn.focus_mode = Control.FOCUS_NONE
		var sty = StyleBoxFlat.new()
		sty.bg_color = Color(0.07, 0.07, 0.12, 0.85)
		sty.border_color = Color(0.25, 0.25, 0.4)
		sty.set_border_width_all(1)
		sty.set_corner_radius_all(3)
		btn.add_theme_stylebox_override("normal", sty)
		var hover = sty.duplicate()
		hover.bg_color = Color(0.12, 0.1, 0.22, 0.9)
		hover.border_color = Color(0.5, 0.4, 0.8)
		hover.set_border_width_all(2)
		btn.add_theme_stylebox_override("hover", hover)

		# Check if equipped — highlight. Walks all 10 unified spell slots so
		# spells bound to any of the new high-index slots also show as equipped.
		var equipped_slot = -1
		for si in range(sb.spell_slots.size()):
			if sb.spell_slots[si] and sb.spell_slots[si].id == spell.id:
				equipped_slot = si
				break
		if equipped_slot >= 0:
			sty.bg_color = Color(0.08, 0.08, 0.22, 0.9)
			sty.border_color = Color(0.4, 0.3, 0.8)
			sty.set_border_width_all(2)

		var color = _get_spell_color(spell)
		var icon_rect = ColorRect.new()
		icon_rect.color = color
		icon_rect.size = Vector2(ICON_SIZE, ICON_SIZE)
		icon_rect.position = Vector2((SLOT_SIZE - ICON_SIZE) / 2, 2)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon_rect)

		var name_lbl = Label.new()
		name_lbl.text = spell.spell_name.substr(0, 8) if spell.spell_name.length() > 8 else spell.spell_name
		name_lbl.add_theme_font_size_override("font_size", 24)
		var name_color = Color(0.5, 1.0, 0.5) if equipped_slot >= 0 else Color(0.75, 0.75, 0.9)
		name_lbl.add_theme_color_override("font_color", name_color)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.position = Vector2(0, SLOT_SIZE - 20)
		name_lbl.size = Vector2(SLOT_SIZE, 18)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(name_lbl)

		# Equipped-slot letter badge ("[F]"/"[G]"/...) removed — equipped spells
		# now show via the slot's green border + the action-bar tile's hotkey
		# number, so the redundant letter label is gone.

		var mp_lbl = Label.new()
		mp_lbl.text = "MP:%.0f" % spell.mp_cost
		mp_lbl.add_theme_font_size_override("font_size", 20)
		mp_lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
		mp_lbl.position = Vector2(SLOT_SIZE - 42, 2)
		mp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(mp_lbl)

		btn.gui_input.connect(_on_spell_gui_input.bind(j))
		_spell_inv_grid.add_child(btn)
		_spell_grid_buttons.append(btn)

func _get_spell_color(spell: SpellDefinition) -> Color:
	match spell.delivery:
		0: return Color(0.8, 0.3, 0.2)  # PROJECTILE - red
		1: return Color(0.3, 0.5, 1.0)  # NOVA - blue
		2: return Color(0.3, 0.9, 0.4)  # SELF - green
		3: return Color(0.9, 0.7, 0.2)  # TOUCH - yellow
	return Color(0.6, 0.6, 0.6)

func _on_spell_slot_clicked(slot_index: int) -> void:
	# Unequip spell from slot
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.get("spell_book"):
		return
	player.spell_book.unequip_spell(slot_index)
	_refresh_spells_tab()
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click", -4.0)

func _on_spell_gui_input(event: InputEvent, spell_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_spell_drag_mouse_down = true
			_spell_drag_idx = spell_idx
			_spell_drag_start = event.global_position
		else:
			if _spell_drag_active:
				_end_spell_drag(event.global_position)
			_spell_drag_mouse_down = false
			_spell_drag_active = false
			_spell_drag_idx = -1
	elif event is InputEventMouseMotion and _spell_drag_mouse_down and not _spell_drag_active:
		if event.global_position.distance_to(_spell_drag_start) > DRAG_THRESHOLD:
			_start_spell_drag(_spell_drag_idx)

func _start_spell_drag(spell_idx: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.get("spell_book"):
		return
	if spell_idx >= player.spell_book.learned_spells.size():
		return
	_spell_drag_active = true
	var spell = player.spell_book.learned_spells[spell_idx]
	_spell_drag_ghost = TextureRect.new()
	# Use a colored rect as ghost
	var img = Image.create(SS_ICON_SIZE, SS_ICON_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(_get_spell_color(spell))
	_spell_drag_ghost.texture = ImageTexture.create_from_image(img)
	_spell_drag_ghost.size = Vector2(SS_ICON_SIZE, SS_ICON_SIZE)
	_spell_drag_ghost.modulate = Color(1, 1, 1, 0.7)
	_spell_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spell_drag_ghost.position = _spell_drag_start - Vector2(SS_ICON_SIZE / 2, SS_ICON_SIZE / 2)
	add_child(_spell_drag_ghost)

func _end_spell_drag(drop_pos: Vector2) -> void:
	if _spell_drag_ghost:
		_spell_drag_ghost.queue_free()
		_spell_drag_ghost = null
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.get("spell_book"):
		return
	if _spell_drag_idx < 0 or _spell_drag_idx >= player.spell_book.learned_spells.size():
		return
	# Check if dropped on a spell slot
	var slot = _get_spell_slot_at_pos(drop_pos)
	if slot >= 0:
		var spell = player.spell_book.learned_spells[_spell_drag_idx]
		player.spell_book.equip_spell(spell, slot)
		_refresh_spells_tab()
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("click", -4.0)

func _build_quickslot_panel() -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.custom_minimum_size = Vector2(QS_SIZE + 8, 0)

	var title = Label.new()
	title.text = "ITEMS"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_quickslot_container = VBoxContainer.new()
	_quickslot_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_quickslot_container)

	_quickslot_buttons.clear()
	for i in range(QS_SLOTS):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(QS_SIZE, QS_SIZE)
		btn.focus_mode = Control.FOCUS_NONE
		var sty = StyleBoxFlat.new()
		sty.bg_color = Color(0.08, 0.06, 0.14, 0.85)
		sty.border_color = Color(0.4, 0.35, 0.25)
		sty.set_border_width_all(1)
		sty.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sty)
		var hover = sty.duplicate()
		hover.bg_color = Color(0.15, 0.12, 0.25, 0.9)
		hover.border_color = Color(0.8, 0.6, 0.3)
		hover.set_border_width_all(2)
		btn.add_theme_stylebox_override("hover", hover)
		btn.pressed.connect(_on_quickslot_pressed.bind(i))
		_quickslot_container.add_child(btn)
		_quickslot_buttons.append(btn)

	return vbox

func _refresh_quickslots() -> void:
	var hud = _get_hud()
	if not hud or not equipment_manager:
		return
	for i in range(QS_SLOTS):
		var btn = _quickslot_buttons[i]
		for child in btn.get_children():
			child.queue_free()

		var item_name = hud._quickbar_items[i] if i < hud._quickbar_items.size() else ""
		if item_name == "":
			var num_lbl = Label.new()
			num_lbl.text = str(i + 1)
			num_lbl.add_theme_font_size_override("font_size", 24)
			num_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
			num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			num_lbl.anchors_preset = Control.PRESET_FULL_RECT
			num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(num_lbl)
			continue

		var item: EquipmentItem = null
		var count = 0
		for j in range(equipment_manager.inventory.size()):
			if equipment_manager.inventory[j].item_name == item_name:
				if not item:
					item = equipment_manager.inventory[j]
				count += 1
		if not item:
			var ghost = Label.new()
			ghost.text = item_name.substr(0, 5)
			ghost.add_theme_font_size_override("font_size", 20)
			ghost.add_theme_color_override("font_color", Color(0.35, 0.3, 0.3))
			ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ghost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			ghost.anchors_preset = Control.PRESET_FULL_RECT
			ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(ghost)
			continue

		var icon = TextureRect.new()
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(QS_ICON_SIZE, QS_ICON_SIZE)
		icon.position = Vector2((QS_SIZE - QS_ICON_SIZE) / 2, 1)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex = ItemIconHelper.get_icon_texture(item)
		if tex:
			icon.texture = tex
		btn.add_child(icon)

		var name_lbl = Label.new()
		name_lbl.text = item_name.substr(0, 6) if item_name.length() > 6 else item_name
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.position = Vector2(0, QS_SIZE - 14)
		name_lbl.size = Vector2(QS_SIZE, 12)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(name_lbl)

		if count > 1:
			var cnt_lbl = Label.new()
			cnt_lbl.text = "x%d" % count
			cnt_lbl.add_theme_font_size_override("font_size", 20)
			cnt_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
			cnt_lbl.position = Vector2(QS_SIZE - 22, 0)
			cnt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(cnt_lbl)

func _on_quickslot_pressed(slot_index: int) -> void:
	# Use the quickslot item (same as HUD quickbar)
	var hud = _get_hud()
	if hud:
		hud._on_quickbar_pressed(slot_index)
		_refresh()

func _build_stats_panel() -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.custom_minimum_size = Vector2(220, 0)

	var title = Label.new()
	title.text = "STATS"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 26)
	_stats_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(_stats_label)

	# Combat-stats toggle — hides 12+ lines of detail by default
	_combat_stats_toggle = Button.new()
	_combat_stats_toggle.text = "Show Combat Stats"
	_combat_stats_toggle.add_theme_font_size_override("font_size", 22)
	_combat_stats_toggle.focus_mode = Control.FOCUS_NONE
	_combat_stats_toggle.pressed.connect(_on_toggle_combat_stats)
	vbox.add_child(_combat_stats_toggle)

	# Stat allocation section
	var alloc_sep = HSeparator.new()
	alloc_sep.add_theme_constant_override("separation", 4)
	vbox.add_child(alloc_sep)

	_stat_points_label = Label.new()
	_stat_points_label.add_theme_font_size_override("font_size", 30)
	_stat_points_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_stat_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_stat_points_label)

	_stat_alloc_container = VBoxContainer.new()
	_stat_alloc_container.add_theme_constant_override("separation", 2)
	vbox.add_child(_stat_alloc_container)

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
	# Append spells as inline tiles so the inventory grid holds everything.
	# Spells are tagged is_spell=true; they can be dragged onto the action bar
	# (see _start_drag / _end_drag) but not dropped on the ground or sold.
	var sb := _get_spell_book()
	if sb:
		for spell in sb.learned_spells:
			if spell == null:
				continue
			var slot_idx := -1
			for s_i in range(sb.spell_slots.size()):
				if sb.spell_slots[s_i] == spell:
					slot_idx = s_i
					break
			_display_list.append({
				"item": null,
				"is_spell": true,
				"spell": spell,
				"spell_slot": slot_idx,
				"count": 1,
				"inv_index": -1,
				"is_equipped": slot_idx >= 0,
			})
	# Append gems from save_data.gem_bag as inline tiles. They keep their
	# separate storage (the bag) — this just surfaces them inside the main grid
	# so players can SEE their gems without opening the socket NPC. Stackable
	# by path so dupes show as "x N".
	var gm_disp = get_node_or_null("/root/GameManager")
	if gm_disp and gm_disp.has_method("get_gem_bag"):
		var bag: Array = gm_disp.get_gem_bag()
		var gem_stacks: Dictionary = {}  # path → display list index
		for gem_path in bag:
			if gem_path == "":
				continue
			if gem_stacks.has(gem_path):
				_display_list[gem_stacks[gem_path]]["count"] += 1
				continue
			var gem_def = load(gem_path) as GemDefinition
			if not gem_def:
				continue
			gem_stacks[gem_path] = _display_list.size()
			_display_list.append({
				"item": null,
				"is_gem": true,
				"gem": gem_def,
				"gem_path": gem_path,
				"count": 1,
				"inv_index": -1,
				"is_equipped": false,
			})


## Returns the player's SpellBook node or null when none exists.
func _get_spell_book() -> SpellBook:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	return player.get_node_or_null("SpellBook") as SpellBook

# ---- Refresh ----
func _refresh() -> void:
	if not equipment_manager or not _root_panel.visible:
		return
	# Preserve scroll position across refreshes
	var saved_scroll = _inv_scroll.scroll_vertical if _inv_scroll else 0
	_build_display_list()
	_refresh_inv_grid()
	_refresh_stats()
	_refresh_quickslots()
	if _current_tab == "spells":
		_refresh_spells_tab()
	elif _current_tab == "socket":
		_refresh_socket_tab()
	elif _current_tab == "salvage":
		_refresh_salvage_tab()
	# Restore scroll position after grid rebuild
	if _inv_scroll:
		_inv_scroll.scroll_vertical = saved_scroll

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
			var is_spell_entry := bool(entry.get("is_spell", false))
			var is_gem_entry := bool(entry.get("is_gem", false))

			# Gem tile: shows the gem's icon (or a colored gem shape if no icon
			# is set), name, stack count. Click opens the SOCKET tab focused on
			# this gem so the player can drop it into an item's socket.
			if is_gem_entry:
				var gem := entry.get("gem") as GemDefinition
				if gem == null:
					continue
				if sty:
					sty.bg_color = Color(0.07, 0.10, 0.13, 0.88)
					sty.border_color = gem.color_hint
					sty.set_border_width_all(2)
				var gem_icon := TextureRect.new() if gem.icon else null
				if gem_icon:
					gem_icon.texture = gem.icon
					gem_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					gem_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
					gem_icon.position = Vector2(SLOT_SIZE * 0.5 - ICON_SIZE * 0.5, 2)
					gem_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
					btn.add_child(gem_icon)
				else:
					# Fallback: tinted diamond in the gem's colour.
					var shape := ColorRect.new()
					shape.color = gem.color_hint
					shape.position = Vector2(SLOT_SIZE * 0.5 - ICON_SIZE * 0.3, SLOT_SIZE * 0.2)
					shape.size = Vector2(ICON_SIZE * 0.6, ICON_SIZE * 0.6)
					shape.rotation = PI * 0.25
					shape.pivot_offset = shape.size * 0.5
					shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
					btn.add_child(shape)
				var gem_lbl := Label.new()
				var gn: String = gem.gem_name if gem.gem_name != "" else "Gem"
				gem_lbl.text = gn.substr(0, 9) if gn.length() > 9 else gn
				gem_lbl.add_theme_font_size_override("font_size", 22)
				gem_lbl.add_theme_color_override("font_color", gem.color_hint.lightened(0.4))
				gem_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				gem_lbl.position = Vector2(0, SLOT_SIZE - 20)
				gem_lbl.size = Vector2(SLOT_SIZE, 18)
				gem_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn.add_child(gem_lbl)
				var gem_count: int = entry.get("count", 1)
				if gem_count > 1:
					var cnt_lbl := Label.new()
					cnt_lbl.text = "x%d" % gem_count
					cnt_lbl.add_theme_font_size_override("font_size", 20)
					cnt_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
					cnt_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
					cnt_lbl.add_theme_constant_override("outline_size", 2)
					cnt_lbl.position = Vector2(SLOT_SIZE - 28, 2)
					cnt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
					btn.add_child(cnt_lbl)
				continue

			# Spell tile: purple frame, sigil-style icon, treated as locked content
			# (no drag, no drop, no salvage). Click toggles equip into a slot.
			if is_spell_entry:
				var spell := entry.get("spell") as SpellDefinition
				if spell == null:
					continue
				var equipped_spell := bool(entry.get("is_equipped", false))
				if sty:
					if equipped_spell:
						sty.bg_color = Color(0.094, 0.067, 0.137, 0.95)
						sty.border_color = AshfieldsUI.ARCANE.lightened(0.3)
						sty.set_border_width_all(2)
					else:
						sty.bg_color = Color(0.075, 0.067, 0.090, 0.85)
						sty.border_color = AshfieldsUI.ARCANE.darkened(0.2)
						sty.set_border_width_all(1)
				# Sigil placeholder — diamond in arcane purple. Future: per-spell icon.
				var sigil := ColorRect.new()
				sigil.color = AshfieldsUI.ARCANE
				sigil.position = Vector2(SLOT_SIZE * 0.5 - ICON_SIZE * 0.3, SLOT_SIZE * 0.2)
				sigil.size = Vector2(ICON_SIZE * 0.6, ICON_SIZE * 0.6)
				sigil.rotation = PI * 0.25
				sigil.pivot_offset = sigil.size * 0.5
				sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn.add_child(sigil)
				# Spell name
				var name_lbl := Label.new()
				name_lbl.text = spell.spell_name.substr(0, 8) if spell.spell_name.length() > 8 else spell.spell_name
				name_lbl.add_theme_font_size_override("font_size", 24)
				name_lbl.add_theme_color_override("font_color", AshfieldsUI.ARCANE.lightened(0.4))
				name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				name_lbl.position = Vector2(0, SLOT_SIZE - 20)
				name_lbl.size = Vector2(SLOT_SIZE, 18)
				name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn.add_child(name_lbl)
				# Equipped-slot letter badge ("[F]"/"[G]"/...) removed — the
				# action-bar tile in the HUD already shows the hotkey number for
				# this spell, so duplicating it here only added clutter.
				continue

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
			name_lbl.add_theme_font_size_override("font_size", 24)
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
				eq_lbl.add_theme_font_size_override("font_size", 20)
				eq_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
				eq_lbl.position = Vector2(2, 0)
				eq_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn.add_child(eq_lbl)

			# Stack count badge for consumables
			# Show stack count for consumables/materials, or ammo quantity
			var show_count = count if count > 1 else 0
			if item.slot_type == EquipmentItem.SlotType.AMMO and item.quantity > 0:
				show_count = item.quantity
			if show_count > 0:
				var count_lbl = Label.new()
				count_lbl.text = "x" + str(show_count)
				count_lbl.add_theme_font_size_override("font_size", 24)
				count_lbl.add_theme_color_override("font_color", Color(1, 1, 0.6))
				count_lbl.position = Vector2(SLOT_SIZE - 36, 2)
				count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn.add_child(count_lbl)

			# Tier badge (top-left, after E marker if equipped)
			var tier = ChestUI._get_item_tier(item)
			var tier_lbl = Label.new()
			tier_lbl.text = "T" + str(tier)
			tier_lbl.add_theme_font_size_override("font_size", 22)
			tier_lbl.add_theme_color_override("font_color", TIER_COLORS[clampi(tier, 0, 5)])
			tier_lbl.position = Vector2(SLOT_SIZE - 28, SLOT_SIZE - 34) if not is_eq else Vector2(14, 0)
			tier_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(tier_lbl)

			# Item rating number (top-right)
			var rating = ChestUI._get_item_rating(item)
			if rating > 0 and count <= 1:
				var pow_lbl = Label.new()
				pow_lbl.text = str(int(rating))
				pow_lbl.add_theme_font_size_override("font_size", 20)
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

func _on_toggle_combat_stats() -> void:
	_show_combat_stats = not _show_combat_stats
	_combat_stats_toggle.text = "Hide Combat Stats" if _show_combat_stats else "Show Combat Stats"
	_refresh_stats()

func _refresh_stats() -> void:
	if not equipment_manager:
		return
	var lines = []
	var player = get_tree().get_first_node_in_group("player")
	var level_system = equipment_manager.level_system

	# Attributes are already shown by the allocation buttons below — don't duplicate.
	if player:
		lines.append("Health: %d / %d" % [player.hp, player.max_hp])
	if _show_combat_stats:
		lines.append("--- Combat Stats ---")
		var atk_line = "Attack: %d" % equipment_manager.get_damage()
		if equipment_manager.has_method("get_proficiency_mult"):
			var prof = equipment_manager.get_proficiency_mult()
			if prof < 1.0:
				atk_line += "  (proficiency %d%%)" % int(prof * 100)
		lines.append(atk_line)
		lines.append("Move Speed: %d" % int(equipment_manager.get_move_speed()))
		lines.append("Attack Interval: %.2f s" % equipment_manager.get_attack_speed())
		lines.append("Projectile Speed: %d" % int(equipment_manager.get_bullet_speed()))
		lines.append("Pierce: %d" % equipment_manager.get_pierce_count())
		lines.append("Crit Damage: %.0f%%" % (equipment_manager.get_crit_damage() * 100))
		lines.append("Armor: %.0f" % equipment_manager.get_armor())
		lines.append("Dodge: %.0f%%" % equipment_manager.get_dodge_chance())
		lines.append("Luck: %.0f" % equipment_manager.get_luck())
		lines.append("XP Gain: %.0f%%" % (equipment_manager.get_xp_mult() * 100))
		lines.append("Gold Gain: %.0f%%" % (equipment_manager.get_gold_mult() * 100))
		lines.append("Pickup Radius: %.0f" % equipment_manager.get_pickup_radius())
	# Show active stat threshold passives
	if level_system:
		var passives = StatThresholds.get_all_passives(level_system.allocated)
		var active_lines: Array[String] = []
		var next_line = ""
		for p in passives:
			if p["active"]:
				active_lines.append("  %s: %s" % [p["name"], p["desc"]])
			elif next_line == "":
				next_line = "%s %d/%d -> %s" % [p["category"].capitalize(), p["current"], p["threshold"], p["name"]]
		if active_lines.size() > 0:
			lines.append("--- Passives ---")
			lines.append_array(active_lines)
		if next_line != "":
			lines.append("Next: " + next_line)
	_stats_label.text = "\n".join(lines)
	# Refresh stat allocation UI
	_refresh_stat_allocation()

const STAT_DESCRIPTIONS = {
	"health": "+4 Max HP, +0.12 HP Regen",
	"defense": "+0.7 Armor, +0.8 Tenacity",
	"strength": "+0.4 Attack, +0.03 Crit Damage",
	"speed": "-0.002 Attack Interval, +2 Bullet Speed",
	"movement": "+1.2 Move Speed, +0.4 Dodge",
	"intellect": "+2.5 Max MP, +0.12 MP Regen, +0.7% CDR",
	"luck": "+0.8 Luck, +2.5% Gold, +2.5% XP",
	"endurance": "+2.5 Max Stamina, +0.25 Stam Regen, +1 Pickup",
}

func _refresh_stat_allocation() -> void:
	if not _stat_alloc_container or not equipment_manager or not equipment_manager.level_system:
		return
	var ls = equipment_manager.level_system
	ls.ensure_retroactive_points()
	var alloc = ls.allocated
	var free_pts = ls.unspent_stat_points

	# Update points label
	if free_pts > 0:
		_stat_points_label.text = "Stat Points: %d" % free_pts
		_stat_points_label.visible = true
	else:
		_stat_points_label.text = ""
		_stat_points_label.visible = false

	# Rebuild allocation rows
	for child in _stat_alloc_container.get_children():
		child.queue_free()

	for cat in LevelSystem.ALLOCATION_CATEGORIES.keys():
		var pts = alloc.get(cat, 0)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_stat_alloc_container.add_child(row)

		var name_lbl = Label.new()
		name_lbl.text = "%s: %d" % [cat.capitalize(), pts]
		name_lbl.add_theme_font_size_override("font_size", 28)
		name_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.tooltip_text = STAT_DESCRIPTIONS.get(cat, "")
		row.add_child(name_lbl)

		if free_pts > 0:
			var plus_btn = Button.new()
			plus_btn.text = "+"
			plus_btn.custom_minimum_size = Vector2(28, 28)
			plus_btn.add_theme_font_size_override("font_size", 28)
			plus_btn.focus_mode = Control.FOCUS_NONE
			plus_btn.pressed.connect(_on_allocate_stat.bind(cat))
			row.add_child(plus_btn)

func _on_allocate_stat(category: String) -> void:
	if not equipment_manager or not equipment_manager.level_system:
		return
	if equipment_manager.level_system.allocate_stat_point(category):
		# Invalidate threshold cache
		if equipment_manager.has_method("invalidate_threshold_cache"):
			equipment_manager.invalidate_threshold_cache()
		equipment_manager.stats_changed.emit()
		_refresh()
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("click", -4.0)
		# Update player HP/MP/stamina caps
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.max_hp = equipment_manager.get_max_hp()
			player.max_mp = equipment_manager.get_max_mp()
			player.max_stamina = equipment_manager.get_max_stamina()

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
	# Spell tiles: clicking toggles equip-to-spell-slot instead of any item action.
	if bool(entry.get("is_spell", false)):
		_toggle_spell_equip(entry)
		return
	# Gem tiles: clicking does nothing here. Socketing is only available at the
	# Blacksmith NPC; opening the SOCKET tab remotely would bypass that gate.
	# Tooltip on hover still surfaces the gem's stats so players can inspect.
	if bool(entry.get("is_gem", false)):
		return
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
	var preview_entry = _display_list[display_idx]
	# Gems can't be dragged out of the bag — there's no drop target that knows
	# how to ingest a gem yet (sockets are handled by the socket tab UI), so a
	# drag here would just visually fail. Click to jump to the SOCKET tab.
	if bool(preview_entry.get("is_gem", false)):
		_drag_mouse_down = false
		_drag_active = false
		_drag_display_idx = -1
		return
	_drag_active = true
	_drop_zone.visible = true
	var entry = preview_entry
	_drag_ghost = TextureRect.new()
	_drag_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_drag_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_ghost.size = Vector2(ICON_SIZE, ICON_SIZE)
	_drag_ghost.modulate = Color(1, 1, 1, 0.7)
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bool(entry.get("is_spell", false)):
		# Spell ghost: a flat tinted square in the spell's school colour. Same
		# size as the item ghost so the drop-target rect math matches.
		var spell := entry.get("spell") as SpellDefinition
		var img := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
		img.fill(_get_spell_color(spell) if spell else Color(0.55, 0.55, 0.9))
		_drag_ghost.texture = ImageTexture.create_from_image(img)
	else:
		var item = entry["item"] as EquipmentItem
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
	var is_spell := bool(entry.get("is_spell", false))

	# Spell-entry branch: only HUD action-bar drop is meaningful. Dropping a
	# spell on the world drop zone or onto an inventory grid slot would do
	# nothing the player wants, so we bail silently in those cases.
	if is_spell:
		var spell := entry.get("spell") as SpellDefinition
		var sb := _get_spell_book()
		if not spell or not sb:
			return
		var hud_s = _get_hud()
		if not hud_s:
			return
		var qb_slot_s: int = hud_s.get_quickbar_slot_at_pos(drop_pos) if hud_s.has_method("get_quickbar_slot_at_pos") else -1
		if qb_slot_s < 0:
			return
		# Clear any item that was occupying the slot — without this the unified
		# router's item-wins rule would keep the spell invisible and uncastable.
		if "_quickbar_items" in hud_s and qb_slot_s < hud_s._quickbar_items.size():
			hud_s._quickbar_items[qb_slot_s] = ""
		sb.equip_spell(spell, qb_slot_s)
		# Refresh both faces (HUD bar + inventory tile state).
		if hud_s.has_method("_refresh_quickbar"):
			hud_s._refresh_quickbar()
		_refresh()
		var sfx_s = get_node_or_null("/root/SFXManager")
		if sfx_s:
			sfx_s.play("click", -4.0)
		return

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

	# Check if dropped on an inventory quickslot
	var qs_slot = _get_quickslot_at_pos(drop_pos)
	if qs_slot >= 0:
		var hud = _get_hud()
		if hud:
			hud.assign_to_quickbar(qs_slot, item.item_name)
			_refresh_quickslots()
			return

	# Check if dropped on a HUD quickbar slot
	var hud2 = _get_hud()
	if hud2:
		var qb_slot = hud2.get_quickbar_slot_at_pos(drop_pos)
		if qb_slot >= 0:
			# Item takes priority — unequip any spell at that slot so the bar
			# row reads "item lives here" without a ghost spell behind it.
			var sb2 := _get_spell_book()
			if sb2 and qb_slot < sb2.MAX_SPELL_SLOTS and sb2.spell_slots[qb_slot] != null:
				sb2.unequip_spell(qb_slot)
			hud2.assign_to_quickbar(qb_slot, item.item_name)
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

func _get_quickslot_at_pos(screen_pos: Vector2) -> int:
	for i in range(_quickslot_buttons.size()):
		var btn = _quickslot_buttons[i]
		var rect = Rect2(btn.global_position, btn.size)
		if rect.has_point(screen_pos):
			return i
	return -1

func _get_spell_slot_at_pos(screen_pos: Vector2) -> int:
	for i in range(_spell_slot_buttons.size()):
		var btn = _spell_slot_buttons[i]
		var rect = Rect2(btn.global_position, btn.size)
		if rect.has_point(screen_pos):
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

func _get_hud() -> CanvasLayer:
	# Accepts GameHUD or SigilHUD — both live in the "game_hud" group.
	var hud = get_tree().get_first_node_in_group("game_hud")
	if not hud:
		for node in get_tree().root.get_children():
			if node is GameHUD or node is SigilHUD:
				return node
	return hud

func _on_inv_hovered(index: int) -> void:
	if not equipment_manager or index >= _display_list.size():
		_hide_tooltip()
		return
	var entry = _display_list[index]
	if bool(entry.get("is_spell", false)):
		_show_spell_tooltip(entry.get("spell") as SpellDefinition, bool(entry.get("is_equipped", false)))
		return
	if bool(entry.get("is_gem", false)):
		_show_gem_tooltip(entry.get("gem") as GemDefinition)
		return
	_show_item_tooltip(_display_list[index]["item"] as EquipmentItem)

func _show_gem_tooltip(gem: GemDefinition) -> void:
	if gem == null or _tooltip_panel == null:
		return
	if _tooltip_name:
		_tooltip_name.text = gem.gem_name
		_tooltip_name.add_theme_color_override("font_color", gem.color_hint.lightened(0.3))
	if _tooltip_desc:
		_tooltip_desc.text = gem.description if gem.description != "" else "Slot into an item socket at the Blacksmith."
	if _tooltip_stats:
		var lines: Array[String] = []
		for mod in gem.modifiers:
			if mod:
				lines.append(mod.get_description() if mod.has_method("get_description") else "+stat")
		_tooltip_stats.text = "\n".join(lines)
	if _tooltip_req:
		_tooltip_req.text = "Tier %d" % gem.tier
	_tooltip_panel.visible = true


## Toggle a spell between unequipped and equipped (in the first empty slot).
## If already equipped, unequip it. If all 6 slots are full, swap into slot 0.
func _toggle_spell_equip(entry: Dictionary) -> void:
	var sb := _get_spell_book()
	var spell := entry.get("spell") as SpellDefinition
	if sb == null or spell == null:
		return
	var current_slot := int(entry.get("spell_slot", -1))
	if current_slot >= 0:
		sb.unequip_spell(current_slot)
	else:
		var target_slot := -1
		for i in range(sb.spell_slots.size()):
			if sb.spell_slots[i] == null:
				target_slot = i
				break
		if target_slot < 0:
			target_slot = 0  # all full → overwrite first slot
		sb.equip_spell(spell, target_slot)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click", -5.0)
	_refresh()


func _show_spell_tooltip(spell: SpellDefinition, equipped: bool) -> void:
	if spell == null:
		return
	_tooltip_panel.modulate.a = 1.0
	var status := " [EQUIPPED]" if equipped else ""
	_tooltip_name.text = spell.spell_name + status
	_tooltip_name.add_theme_color_override("font_color", AshfieldsUI.ARCANE.lightened(0.4))
	_tooltip_desc.text = "Spell | MP %d | Cooldown %.1fs" % [int(spell.mp_cost), spell.cooldown]
	if spell.description != "":
		_tooltip_desc.text += "\n" + spell.description
	var lines: Array[String] = []
	lines.append("Magnitude: %d" % spell.magnitude)
	if spell.duration > 0.0:
		lines.append("Duration: %.1fs" % spell.duration)
	lines.append("Click to %s" % ("unequip" if equipped else "equip"))
	_tooltip_stats.text = "\n".join(lines)
	_tooltip_req.text = ""

func _show_item_tooltip(item: EquipmentItem) -> void:
	# Tooltip stays in the layout permanently — just fade alpha. No scroll jump.
	_tooltip_panel.modulate.a = 1.0
	var tier = ChestUI._get_item_tier(item)
	var rating = ChestUI._get_item_rating(item)
	var rarity_name = RARITY_NAMES[clampi(item.rarity, 0, 2)]
	var equipped_str = ""
	if equipment_manager and equipment_manager.is_equipped(item):
		equipped_str = " [EQUIPPED]"
	_tooltip_name.text = item.get_display_name() + equipped_str
	_tooltip_name.add_theme_color_override("font_color", RARITY_COLORS[clampi(item.rarity, 0, 2)])
	_tooltip_desc.text = "Tier " + str(tier) + " | " + rarity_name + " | Item Rating: " + str(int(rating))
	if item.description != "":
		_tooltip_desc.text += "\n" + item.description
	if item.weapon_type != "":
		var scaling = item.get_scaling_stat()
		_tooltip_desc.text += "\nType: " + item.weapon_type
		if scaling != "":
			_tooltip_desc.text += "  (scales with " + scaling.capitalize() + ")"
		# Show weapon SPACE and SHIFT abilities
		var _wa = _get_weapon_abilities(item.weapon_type)
		if _wa.space != "":
			_tooltip_desc.text += "\n[SPACE] " + _wa.space
		if _wa.shift != "":
			_tooltip_desc.text += "\n[SHIFT] " + _wa.shift
	if item.buy_price > 0:
		_tooltip_desc.text += "\nValue: " + str(item.buy_price) + "g"
	if item.socket_count > 0:
		_tooltip_desc.text += "\nSockets: %d/%d filled" % [item.get_socketed_gem_count(), item.socket_count]
	if item.archetype_tags.size() > 0:
		_tooltip_desc.text += "\nTags: " + ", ".join(Array(item.archetype_tags))
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
	if item.socket_count > 0:
		for socket_idx in range(item.socket_count):
			var socket_type = item.socket_types[socket_idx] if socket_idx < item.socket_types.size() else "open"
			var gem_path = item.socketed_gem_paths[socket_idx] if socket_idx < item.socketed_gem_paths.size() else ""
			var socket_label = "Socket %d [%s]" % [socket_idx + 1, socket_type.capitalize()]
			if gem_path != "":
				var gem = load(gem_path) as GemDefinition
				if gem:
					socket_label += ": " + gem.gem_name
				else:
					socket_label += ": Filled"
			else:
				socket_label += ": Empty"
			stat_lines.append(socket_label)
	_tooltip_stats.text = "\n".join(stat_lines)
	# Show equipment requirements (unmet in red, met in dim green)
	var req_text = ""
	if EquipmentItem.is_equippable(item.slot_type):
		var gm = get_node_or_null("/root/GameManager")
		var pc = gm.selected_class if gm and gm.get("selected_class") else "warrior"
		var player = get_tree().get_first_node_in_group("player")
		var lvl = 1
		var alloc = {}
		if player and player.get("equipment_manager") and player.equipment_manager.level_system:
			lvl = player.equipment_manager.level_system.level
			alloc = player.equipment_manager.level_system.allocated
		# Show all stat requirements (met or not)
		var reqs = item.get_effective_stat_requirements()
		if item.required_level > 0:
			reqs["level"] = item.required_level
		if reqs.size() > 0:
			var lines: Array[String] = []
			for stat_name in reqs:
				var needed = reqs[stat_name] as int
				if stat_name == "level":
					var met = lvl >= needed
					lines.append("%sRequires Level %d" % ["" if not met else "", needed])
				else:
					var have = alloc.get(stat_name, 0) as int
					var met = have >= needed
					if met:
						lines.append("%s %d/%d" % [stat_name.capitalize(), have, needed])
					else:
						lines.append("%s %d/%d (need %d more)" % [stat_name.capitalize(), have, needed, needed - have])
			req_text = "\n".join(lines)
		# Color: red if any unmet, green if all met
		var unmet = item.get_unmet_requirements(pc, lvl, alloc)
		if unmet.size() > 0:
			_tooltip_req.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		else:
			_tooltip_req.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	_tooltip_req.text = req_text

func _hide_tooltip() -> void:
	# Fade only — keep the tooltip in the layout so the scroll container above
	# never reflows on hover-out.
	if _tooltip_panel:
		_tooltip_panel.modulate.a = 0.0

func _on_equip_failed(_item: EquipmentItem) -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("error", -3.0)
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var ft = get_node_or_null("/root/FloatingText")
		if ft:
			ft.spawn(get_tree().current_scene, player.global_position + Vector2(0, -12), "Cannot equip!", Color(1, 0.3, 0.3))

func _process(delta: float) -> void:
	if _toggle_cooldown > 0:
		_toggle_cooldown -= delta
	if _drag_active and _drag_ghost:
		_drag_ghost.position = get_viewport().get_mouse_position() - Vector2(ICON_SIZE / 2, ICON_SIZE / 2)
	if _spell_drag_active and _spell_drag_ghost:
		_spell_drag_ghost.position = get_viewport().get_mouse_position() - Vector2(SS_ICON_SIZE / 2, SS_ICON_SIZE / 2)

func toggle() -> void:
	if _toggle_cooldown > 0:
		return
	_toggle_cooldown = 0.2
	var opening = not _root_panel.visible
	_root_panel.visible = opening
	_overlay.visible = opening
	_close_btn.visible = opening
	_menu_btn.visible = opening
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("paper" if opening else "close", -4.0, 0.0)
	if opening:
		# Plain-inventory mode — hide SPELLS / SOCKET / SALVAGE tabs (NPC-only).
		_apply_tab_visibility("items")
		_switch_tab("items")
		_refresh()
	else:
		_cancel_drag()
	# Hide/show all HUD panels
	var hud = _get_hud()
	if hud:
		hud.set_non_quickbar_visible(not opening)

func is_open() -> bool:
	return _root_panel.visible

func _input(event: InputEvent) -> void:
	# B is the sole inventory bind. Tab was moved to lock_on, I was dropped
	# because other UIs use the "inventory" action for their own close behavior.
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_B:
			toggle()
			get_viewport().set_input_as_handled()
			return
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

# ===== SOCKET TAB =====

func _build_socket_tab() -> VBoxContainer:
	# Ashfields-themed socketing layout: header / item strip / detail focus / gem bag.
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)

	# === Header: pixel-font title + gold underline ===
	var title_block = AshfieldsUI.section_title("GEM SOCKETING", 30)
	vbox.add_child(title_block)

	# === Section 1: item picker ===
	var pick_header = Label.new()
	pick_header.text = "1. SELECT A SOCKETED ITEM"
	pick_header.add_theme_font_size_override("font_size", 26)
	pick_header.add_theme_color_override("font_color", AshfieldsUI.GOLD_DARK)
	pick_header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	pick_header.add_theme_constant_override("outline_size", 2)
	vbox.add_child(pick_header)

	var item_scroll = ScrollContainer.new()
	item_scroll.custom_minimum_size = Vector2(0, SLOT_SIZE + 24)
	item_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(item_scroll)

	_socket_item_grid = HBoxContainer.new()
	_socket_item_grid.add_theme_constant_override("separation", 8)
	item_scroll.add_child(_socket_item_grid)

	vbox.add_child(AshfieldsUI.divider())

	# === Section 2: selected-item detail (the focal point) ===
	var detail_header = Label.new()
	detail_header.text = "2. PLACE A GEM IN A SOCKET"
	detail_header.add_theme_font_size_override("font_size", 26)
	detail_header.add_theme_color_override("font_color", AshfieldsUI.GOLD_DARK)
	detail_header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	detail_header.add_theme_constant_override("outline_size", 2)
	vbox.add_child(detail_header)

	var detail_frame = AshfieldsUI.ornate_panel(14)
	detail_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(detail_frame)

	_socket_detail_panel = VBoxContainer.new()
	_socket_detail_panel.add_theme_constant_override("separation", 8)
	_socket_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_frame.add_child(_socket_detail_panel)

	vbox.add_child(AshfieldsUI.divider())

	# === Section 3: gem bag ===
	var gem_header = Label.new()
	gem_header.text = "3. YOUR GEMS"
	gem_header.add_theme_font_size_override("font_size", 26)
	gem_header.add_theme_color_override("font_color", AshfieldsUI.GOLD_DARK)
	gem_header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	gem_header.add_theme_constant_override("outline_size", 2)
	vbox.add_child(gem_header)

	var gem_scroll = ScrollContainer.new()
	gem_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gem_scroll.custom_minimum_size = Vector2(0, SLOT_SIZE + 24)
	vbox.add_child(gem_scroll)

	var gem_center = CenterContainer.new()
	gem_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gem_scroll.add_child(gem_center)

	_socket_gem_grid = GridContainer.new()
	_socket_gem_grid.columns = INV_COLS
	_socket_gem_grid.add_theme_constant_override("h_separation", 6)
	_socket_gem_grid.add_theme_constant_override("v_separation", 6)
	gem_center.add_child(_socket_gem_grid)

	return vbox

func _refresh_socket_tab() -> void:
	if not equipment_manager:
		return
	# Refresh item selection row
	for child in _socket_item_grid.get_children():
		child.queue_free()

	var socketed_items: Array[Dictionary] = []
	for i in range(equipment_manager.inventory.size()):
		var item = equipment_manager.inventory[i]
		if item and item.socket_count > 0:
			socketed_items.append({"item": item, "inv_index": i})

	for entry in socketed_items:
		var item = entry["item"] as EquipmentItem
		var inv_idx = entry["inv_index"] as int
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		btn.focus_mode = Control.FOCUS_NONE
		var sty = StyleBoxFlat.new()
		var is_selected = (_socket_selected_item == item)
		sty.bg_color = Color(0.12, 0.1, 0.25) if is_selected else NORMAL_BG
		sty.border_color = Color(0.6, 0.5, 0.2) if is_selected else Color(0.3, 0.3, 0.4)
		sty.set_border_width_all(2 if is_selected else 1)
		sty.set_corner_radius_all(3)
		btn.add_theme_stylebox_override("normal", sty)
		var hover = sty.duplicate()
		hover.bg_color = Color(0.16, 0.14, 0.28)
		hover.border_color = Color(0.7, 0.6, 0.3)
		hover.set_border_width_all(2)
		btn.add_theme_stylebox_override("hover", hover)

		var icon = _make_icon_rect_for_item(item)
		icon.position = Vector2(SLOT_SIZE / 2 - ICON_SIZE / 2, 2)
		btn.add_child(icon)

		var name_lbl = Label.new()
		name_lbl.text = item.item_name.substr(0, 8) if item.item_name.length() > 8 else item.item_name
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.add_theme_color_override("font_color", RARITY_COLORS[clampi(item.rarity, 0, 2)])
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.position = Vector2(0, SLOT_SIZE - 20)
		name_lbl.size = Vector2(SLOT_SIZE, 18)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(name_lbl)

		# Socket count badge
		var sc_lbl = Label.new()
		sc_lbl.text = "%d/%d" % [item.get_socketed_gem_count(), item.socket_count]
		sc_lbl.add_theme_font_size_override("font_size", 22)
		sc_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
		sc_lbl.position = Vector2(SLOT_SIZE - 30, 2)
		sc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(sc_lbl)

		btn.pressed.connect(_on_socket_item_selected.bind(item, inv_idx))
		_socket_item_grid.add_child(btn)

	if socketed_items.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No items with sockets in inventory"
		empty_lbl.add_theme_font_size_override("font_size", 28)
		empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		_socket_item_grid.add_child(empty_lbl)

	# Refresh socket detail
	_refresh_socket_detail()
	# Refresh gem bag
	_refresh_gem_bag()

func _on_socket_item_selected(item: EquipmentItem, inv_idx: int) -> void:
	_socket_selected_item = item
	_socket_selected_idx = inv_idx
	_socket_active_socket = -1
	_refresh_socket_tab()
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click", -4.0)

func _refresh_socket_detail() -> void:
	for child in _socket_detail_panel.get_children():
		child.queue_free()

	if not _socket_selected_item:
		var hint = Label.new()
		hint.text = "Select an item above to manage its sockets"
		hint.add_theme_font_size_override("font_size", 28)
		hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_socket_detail_panel.add_child(hint)
		return

	var item = _socket_selected_item
	var header = Label.new()
	header.text = item.item_name + " - Sockets"
	header.add_theme_font_size_override("font_size", 34)
	header.add_theme_color_override("font_color", RARITY_COLORS[clampi(item.rarity, 0, 2)])
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_socket_detail_panel.add_child(header)

	for si in range(item.socket_count):
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		_socket_detail_panel.add_child(row)

		var socket_type = item.socket_types[si] if si < item.socket_types.size() else "open"
		var gem_path = item.socketed_gem_paths[si] if si < item.socketed_gem_paths.size() else ""

		var slot_label = Label.new()
		slot_label.add_theme_font_size_override("font_size", 28)
		slot_label.custom_minimum_size = Vector2(140, 0)

		if gem_path != "":
			var gem = load(gem_path) as GemDefinition
			var gem_name = gem.gem_name if gem else "Unknown Gem"
			var gem_stat = ""
			if gem:
				for mod in gem.modifiers:
					var stat_name = StatModifier.StatType.keys()[mod.stat]
					if mod.flat_bonus != 0:
						gem_stat += " +%d %s" % [mod.flat_bonus, stat_name]
					if mod.percent_bonus != 0:
						gem_stat += " +%d%% %s" % [int(mod.percent_bonus * 100), stat_name]
			slot_label.text = "Socket #%d: %s%s" % [si + 1, gem_name, gem_stat]
			slot_label.add_theme_color_override("font_color", gem.color_hint if gem else Color(0.8, 0.8, 0.8))
			row.add_child(slot_label)

			# Unsocket button
			var unsocket_btn = Button.new()
			unsocket_btn.text = "Unsocket"
			unsocket_btn.focus_mode = Control.FOCUS_NONE
			unsocket_btn.custom_minimum_size = Vector2(90, 30)
			unsocket_btn.add_theme_font_size_override("font_size", 26)
			var us_sty = StyleBoxFlat.new()
			us_sty.bg_color = Color(0.25, 0.1, 0.1)
			us_sty.border_color = Color(0.6, 0.25, 0.25)
			us_sty.set_border_width_all(1)
			us_sty.set_corner_radius_all(3)
			unsocket_btn.add_theme_stylebox_override("normal", us_sty)
			unsocket_btn.pressed.connect(_on_unsocket_gem.bind(si))
			row.add_child(unsocket_btn)
		else:
			var is_active = (_socket_active_socket == si)
			slot_label.text = "Socket #%d [%s]: %s" % [si + 1, socket_type.capitalize(), "Click gem below..." if is_active else "Empty"]
			slot_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4) if is_active else Color(0.5, 0.5, 0.6))
			row.add_child(slot_label)

			# Select socket button
			var select_btn = Button.new()
			select_btn.text = "Select" if not is_active else "..."
			select_btn.focus_mode = Control.FOCUS_NONE
			select_btn.custom_minimum_size = Vector2(70, 30)
			select_btn.add_theme_font_size_override("font_size", 26)
			var sel_sty = StyleBoxFlat.new()
			sel_sty.bg_color = Color(0.1, 0.15, 0.25) if not is_active else Color(0.15, 0.2, 0.35)
			sel_sty.border_color = Color(0.3, 0.4, 0.6) if not is_active else Color(0.5, 0.7, 1.0)
			sel_sty.set_border_width_all(1)
			sel_sty.set_corner_radius_all(3)
			select_btn.add_theme_stylebox_override("normal", sel_sty)
			select_btn.pressed.connect(_on_select_socket.bind(si))
			row.add_child(select_btn)

func _on_select_socket(socket_index: int) -> void:
	_socket_active_socket = socket_index
	_refresh_socket_detail()
	_refresh_gem_bag()

func _on_unsocket_gem(socket_index: int) -> void:
	if not _socket_selected_item or not equipment_manager:
		return
	var gem_path = equipment_manager.unsocket_gem(_socket_selected_item, socket_index)
	if gem_path != "":
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.add_gem_to_bag(gem_path)
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("click", -4.0)
	_refresh_socket_tab()

func _refresh_gem_bag() -> void:
	for child in _socket_gem_grid.get_children():
		child.queue_free()

	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return
	var bag: Array = gm.get_gem_bag()
	if bag.is_empty():
		var empty = Label.new()
		empty.text = "No gems in bag"
		empty.add_theme_font_size_override("font_size", 28)
		empty.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		_socket_gem_grid.add_child(empty)
		return

	for i in range(bag.size()):
		var gem_path = bag[i] as String
		var gem = load(gem_path) as GemDefinition
		if not gem:
			continue
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		btn.focus_mode = Control.FOCUS_NONE
		var sty = StyleBoxFlat.new()
		sty.bg_color = Color(0.08, 0.06, 0.14)
		sty.border_color = gem.color_hint.darkened(0.3)
		sty.set_border_width_all(1)
		sty.set_corner_radius_all(3)
		btn.add_theme_stylebox_override("normal", sty)
		var hover = sty.duplicate()
		hover.bg_color = Color(0.14, 0.1, 0.22)
		hover.border_color = gem.color_hint
		hover.set_border_width_all(2)
		btn.add_theme_stylebox_override("hover", hover)

		# Gem color swatch as icon
		var gem_icon = ColorRect.new()
		gem_icon.color = gem.color_hint
		gem_icon.size = Vector2(ICON_SIZE * 0.6, ICON_SIZE * 0.6)
		gem_icon.position = Vector2(SLOT_SIZE / 2 - ICON_SIZE * 0.3, 8)
		gem_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(gem_icon)

		var name_lbl = Label.new()
		name_lbl.text = gem.gem_name.substr(0, 10) if gem.gem_name.length() > 10 else gem.gem_name
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.add_theme_color_override("font_color", gem.color_hint)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.position = Vector2(0, SLOT_SIZE - 20)
		name_lbl.size = Vector2(SLOT_SIZE, 18)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(name_lbl)

		# Stat preview
		var stat_text = ""
		for mod in gem.modifiers:
			var stat_name = StatModifier.StatType.keys()[mod.stat]
			if mod.flat_bonus != 0:
				stat_text += "+%d %s" % [mod.flat_bonus, stat_name.substr(0, 3)]
		if stat_text != "":
			var stat_lbl = Label.new()
			stat_lbl.text = stat_text
			stat_lbl.add_theme_font_size_override("font_size", 20)
			stat_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
			stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stat_lbl.position = Vector2(0, SLOT_SIZE - 34)
			stat_lbl.size = Vector2(SLOT_SIZE, 14)
			stat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(stat_lbl)

		btn.pressed.connect(_on_gem_selected.bind(i, gem_path))
		_socket_gem_grid.add_child(btn)

func _on_gem_selected(bag_index: int, gem_path: String) -> void:
	if not _socket_selected_item or _socket_active_socket < 0 or not equipment_manager:
		return
	if equipment_manager.socket_gem(_socket_selected_item, _socket_active_socket, gem_path):
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.remove_gem_from_bag(gem_path)
		_socket_active_socket = -1
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("click", -4.0)
	_refresh_socket_tab()

# ===== SALVAGE TAB =====

func _build_salvage_tab() -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 16)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(title_row)

	var title = Label.new()
	title.text = "SALVAGE"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	title_row.add_child(title)

	_salvage_points_label = Label.new()
	_salvage_points_label.add_theme_font_size_override("font_size", 32)
	_salvage_points_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	title_row.add_child(_salvage_points_label)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	# Main layout: items grid left, preview right
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 16)
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(main_hbox)

	# Left: item grid
	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 4)
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(left_vbox)

	var grid_label = Label.new()
	grid_label.text = "ITEMS (click to select)"
	grid_label.add_theme_font_size_override("font_size", 28)
	grid_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	grid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(grid_label)

	var grid_scroll = ScrollContainer.new()
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(grid_scroll)

	var grid_center = CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.add_child(grid_center)

	_salvage_item_grid = GridContainer.new()
	_salvage_item_grid.columns = 6
	_salvage_item_grid.add_theme_constant_override("h_separation", 4)
	_salvage_item_grid.add_theme_constant_override("v_separation", 4)
	grid_center.add_child(_salvage_item_grid)

	# Right: preview + salvage button
	_salvage_preview = VBoxContainer.new()
	_salvage_preview.add_theme_constant_override("separation", 8)
	_salvage_preview.custom_minimum_size = Vector2(280, 0)
	main_hbox.add_child(_salvage_preview)

	# Bottom: blueprint progress list
	var bp_sep = HSeparator.new()
	bp_sep.add_theme_constant_override("separation", 4)
	vbox.add_child(bp_sep)

	var bp_label = Label.new()
	bp_label.text = "BLUEPRINT PROGRESS"
	bp_label.add_theme_font_size_override("font_size", 28)
	bp_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	bp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(bp_label)

	var bp_scroll = ScrollContainer.new()
	bp_scroll.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(bp_scroll)

	_salvage_bp_list = VBoxContainer.new()
	_salvage_bp_list.add_theme_constant_override("separation", 4)
	bp_scroll.add_child(_salvage_bp_list)

	return vbox

func _refresh_salvage_tab() -> void:
	if not equipment_manager:
		return
	# Update salvage points display
	var gm = get_node_or_null("/root/GameManager")
	if gm and _salvage_points_label:
		_salvage_points_label.text = "Salvage Points: %d" % gm.get_salvage_points()
	# Refresh item grid (non-equipped items only)
	for child in _salvage_item_grid.get_children():
		child.queue_free()

	var salvageable: Array[Dictionary] = []
	for i in range(equipment_manager.inventory.size()):
		var item = equipment_manager.inventory[i]
		if item and not equipment_manager.is_equipped(item):
			salvageable.append({"item": item, "inv_index": i})

	for entry in salvageable:
		var item = entry["item"] as EquipmentItem
		var inv_idx = entry["inv_index"] as int
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		btn.focus_mode = Control.FOCUS_NONE
		var sty = StyleBoxFlat.new()
		var is_selected = (_salvage_selected_item == item)
		sty.bg_color = Color(0.18, 0.08, 0.08) if is_selected else NORMAL_BG
		sty.border_color = Color(0.8, 0.3, 0.3) if is_selected else RARITY_COLORS[clampi(item.rarity, 0, 2)].darkened(0.3)
		sty.set_border_width_all(2 if is_selected else 1)
		sty.set_corner_radius_all(3)
		btn.add_theme_stylebox_override("normal", sty)
		var hover = sty.duplicate()
		hover.bg_color = Color(0.22, 0.1, 0.1)
		hover.border_color = Color(0.9, 0.4, 0.4)
		hover.set_border_width_all(2)
		btn.add_theme_stylebox_override("hover", hover)

		var icon = _make_icon_rect_for_item(item)
		icon.position = Vector2(SLOT_SIZE / 2 - ICON_SIZE / 2, 2)
		btn.add_child(icon)

		var name_lbl = Label.new()
		name_lbl.text = item.item_name.substr(0, 8) if item.item_name.length() > 8 else item.item_name
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.add_theme_color_override("font_color", RARITY_COLORS[clampi(item.rarity, 0, 2)])
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.position = Vector2(0, SLOT_SIZE - 20)
		name_lbl.size = Vector2(SLOT_SIZE, 18)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(name_lbl)

		btn.pressed.connect(_on_salvage_item_selected.bind(item, inv_idx))
		_salvage_item_grid.add_child(btn)

	if salvageable.is_empty():
		var empty = Label.new()
		empty.text = "No items to salvage"
		empty.add_theme_font_size_override("font_size", 28)
		empty.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		_salvage_item_grid.add_child(empty)

	# Refresh preview
	_refresh_salvage_preview()
	# Refresh blueprint progress
	_refresh_blueprint_list()

func _on_salvage_item_selected(item: EquipmentItem, inv_idx: int) -> void:
	_salvage_selected_item = item
	_salvage_selected_idx = inv_idx
	_refresh_salvage_tab()
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click", -4.0)

func _refresh_salvage_preview() -> void:
	for child in _salvage_preview.get_children():
		child.queue_free()

	if not _salvage_selected_item:
		var hint = Label.new()
		hint.text = "Select an item to see\nsalvage preview"
		hint.add_theme_font_size_override("font_size", 28)
		hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_salvage_preview.add_child(hint)
		return

	var item = _salvage_selected_item

	# Item header
	var name_lbl = Label.new()
	name_lbl.text = item.item_name
	name_lbl.add_theme_font_size_override("font_size", 34)
	name_lbl.add_theme_color_override("font_color", RARITY_COLORS[clampi(item.rarity, 0, 2)])
	_salvage_preview.add_child(name_lbl)

	# Stats summary
	var stat_lines: Array[String] = []
	for mod in item.modifiers:
		var stat_name = StatModifier.StatType.keys()[mod.stat]
		if mod.flat_bonus != 0:
			stat_lines.append("+%d %s" % [mod.flat_bonus, stat_name])
		if mod.percent_bonus != 0:
			stat_lines.append("+%d%% %s" % [int(mod.percent_bonus * 100), stat_name])
	if stat_lines.size() > 0:
		var stats_lbl = Label.new()
		stats_lbl.text = "\n".join(stat_lines)
		stats_lbl.add_theme_font_size_override("font_size", 26)
		stats_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
		_salvage_preview.add_child(stats_lbl)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	_salvage_preview.add_child(sep)

	# Salvage yields (computed from calculate_salvage_yield)
	var yields = EquipmentManager.calculate_salvage_yield(item)

	var yield_title = Label.new()
	yield_title.text = "Salvage yields:"
	yield_title.add_theme_font_size_override("font_size", 28)
	yield_title.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
	_salvage_preview.add_child(yield_title)

	var gold_lbl = Label.new()
	gold_lbl.text = "Gold: %d" % yields["gold"]
	gold_lbl.add_theme_font_size_override("font_size", 28)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_salvage_preview.add_child(gold_lbl)

	if yields["salvage_points"] > 0:
		var sp_lbl = Label.new()
		sp_lbl.text = "Salvage Points: +%d" % yields["salvage_points"]
		sp_lbl.add_theme_font_size_override("font_size", 28)
		sp_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
		_salvage_preview.add_child(sp_lbl)

	for mat_path in yields["materials"]:
		var mat = load(mat_path) as EquipmentItem
		if mat:
			var mat_lbl = Label.new()
			mat_lbl.text = "  + %s" % mat.item_name
			mat_lbl.add_theme_font_size_override("font_size", 26)
			mat_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
			_salvage_preview.add_child(mat_lbl)

	if item.blueprint_id != "":
		var bp_lbl = Label.new()
		var gm = get_node_or_null("/root/GameManager")
		var progress = gm.get_blueprint_progress(item.blueprint_id) if gm else 0
		var bp_def = gm.get_blueprint_definition(item.blueprint_id) if gm else null
		var needed = bp_def.required_fragments if bp_def else 1
		var bp_name = bp_def.blueprint_name if bp_def else item.blueprint_id
		var salvage_needed = bp_def.required_salvage_points if bp_def else 0
		var salvage_have = gm.get_salvage_points() if gm else 0
		bp_lbl.text = "Blueprint: %s (%d/%d fragments, %d/%d SP)" % [bp_name, progress, needed, salvage_have, salvage_needed]
		bp_lbl.add_theme_font_size_override("font_size", 26)
		bp_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 1.0))
		_salvage_preview.add_child(bp_lbl)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	_salvage_preview.add_child(spacer)

	# SALVAGE button
	var salvage_btn = Button.new()
	salvage_btn.text = "SALVAGE"
	salvage_btn.focus_mode = Control.FOCUS_NONE
	salvage_btn.custom_minimum_size = Vector2(200, 44)
	salvage_btn.add_theme_font_size_override("font_size", 34)
	salvage_btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	var sal_sty = StyleBoxFlat.new()
	sal_sty.bg_color = Color(0.3, 0.08, 0.08)
	sal_sty.border_color = Color(0.7, 0.2, 0.2)
	sal_sty.set_border_width_all(2)
	sal_sty.set_corner_radius_all(4)
	salvage_btn.add_theme_stylebox_override("normal", sal_sty)
	var sal_hover = sal_sty.duplicate()
	sal_hover.bg_color = Color(0.45, 0.1, 0.1)
	sal_hover.border_color = Color(1.0, 0.3, 0.3)
	salvage_btn.add_theme_stylebox_override("hover", sal_hover)
	salvage_btn.pressed.connect(_on_salvage_confirmed)
	_salvage_preview.add_child(salvage_btn)

func _on_salvage_confirmed() -> void:
	if not equipment_manager or _salvage_selected_idx < 0:
		return
	var result = equipment_manager.salvage_inventory_item(_salvage_selected_idx)
	if result.get("ok", false):
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("click", -4.0)
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var ft = get_node_or_null("/root/FloatingText")
			if ft:
				var msg = "Salvaged: %s" % result.get("item_name", "")
				var gold_amt = result.get("gold", 0)
				var sp_amt = result.get("salvage_points", 0)
				if gold_amt > 0:
					msg += " (+%dg" % gold_amt
					if sp_amt > 0:
						msg += ", +%d SP" % sp_amt
					msg += ")"
				ft.spawn(get_tree().current_scene, player.global_position + Vector2(0, -12), msg, Color(1.0, 0.6, 0.3))
				var mats: Array = result.get("materials", [])
				if mats.size() > 0:
					ft.spawn(get_tree().current_scene, player.global_position + Vector2(0, -28), "+ " + ", ".join(mats), Color(0.7, 0.85, 0.7))
				if result.get("unlocked", false):
					ft.spawn(get_tree().current_scene, player.global_position + Vector2(0, -44), "Blueprint Unlocked!", Color(0.3, 1.0, 0.3))
	_salvage_selected_item = null
	_salvage_selected_idx = -1
	_refresh_salvage_tab()

func _refresh_blueprint_list() -> void:
	for child in _salvage_bp_list.get_children():
		child.queue_free()

	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.save_data:
		return

	var bp_progress: Dictionary = gm.save_data.blueprint_progress
	var discovered: Array = gm.save_data.discovered_blueprints
	if bp_progress.is_empty() and discovered.is_empty():
		var empty = Label.new()
		empty.text = "No blueprints discovered yet"
		empty.add_theme_font_size_override("font_size", 26)
		empty.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		_salvage_bp_list.add_child(empty)
		return

	var seen_blueprints: Dictionary = {}
	for bp_id in bp_progress:
		seen_blueprints[bp_id] = true
		var progress = int(bp_progress[bp_id])
		var bp_def = gm.get_blueprint_definition(bp_id)
		var needed = bp_def.required_fragments if bp_def else 1
		var bp_name = bp_def.blueprint_name if bp_def else bp_id
		var complete = bp_id in discovered
		var salvage_needed = bp_def.required_salvage_points if bp_def else 0
		var salvage_have = gm.get_salvage_points()

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_salvage_bp_list.add_child(row)

		var name_lbl = Label.new()
		name_lbl.text = bp_name
		name_lbl.add_theme_font_size_override("font_size", 26)
		name_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3) if complete else Color(0.7, 0.7, 0.8))
		name_lbl.custom_minimum_size = Vector2(180, 0)
		row.add_child(name_lbl)

		# Progress bar
		var bar_bg = ColorRect.new()
		bar_bg.color = Color(0.15, 0.15, 0.2)
		bar_bg.custom_minimum_size = Vector2(120, 16)
		row.add_child(bar_bg)

		var fill_width = 120.0 * minf(float(progress) / float(needed), 1.0)
		var bar_fill = ColorRect.new()
		bar_fill.color = Color(0.3, 0.8, 0.3) if complete else Color(0.4, 0.5, 0.8)
		bar_fill.custom_minimum_size = Vector2(fill_width, 16)
		bar_fill.size = Vector2(fill_width, 16)
		bar_fill.position = Vector2.ZERO
		bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_bg.add_child(bar_fill)

		var detail_lbl = Label.new()
		detail_lbl.text = "%d/%d fragments | %d/%d SP" % [progress, needed, salvage_have, salvage_needed]
		detail_lbl.add_theme_font_size_override("font_size", 24)
		detail_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6) if not complete else Color(0.4, 0.8, 0.4))
		row.add_child(detail_lbl)

	for bp_id in discovered:
		if seen_blueprints.has(bp_id):
			continue
		var bp_def = gm.get_blueprint_definition(String(bp_id))
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_salvage_bp_list.add_child(row)

		var name_lbl = Label.new()
		name_lbl.text = bp_def.blueprint_name if bp_def else String(bp_id)
		name_lbl.add_theme_font_size_override("font_size", 26)
		name_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		name_lbl.custom_minimum_size = Vector2(180, 0)
		row.add_child(name_lbl)

		var unlocked_lbl = Label.new()
		unlocked_lbl.text = "Unlocked"
		unlocked_lbl.add_theme_font_size_override("font_size", 24)
		unlocked_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		row.add_child(unlocked_lbl)

func _get_weapon_abilities(wtype: String) -> Dictionary:
	match wtype:
		"sword": return {space = "Dash — quick dodge roll", shift = "Blade Dance — spinning slash aura"}
		"dagger": return {space = "Dash — quick dodge roll", shift = "Rapid Strike — doubled attack speed"}
		"axe": return {space = "Dash Cleave — dash + AoE on landing", shift = "Whirlwind — ring of axes"}
		"club": return {space = "Ground Pound — AoE stun", shift = "Berserk Swing — wide arcs, slow move"}
		"hammer": return {space = "Hammer Throw — boomerang toss", shift = "Earthquake — tremor pulses"}
		"spear": return {space = "Lunge — extended dash piercing foes", shift = "Phalanx — immobile rapid-fire"}
		"flail": return {space = "Chain Lash — extended range strike", shift = "Whip Spin — boomerang multishot"}
		"throwing": return {space = "Fan of Knives — scatter burst", shift = "Barrage — rapid scatter volley"}
		"bow": return {space = "Dash — quick dodge roll", shift = "Multishot — triple arrow spread"}
		"short_bow": return {space = "Evasive Shot — backflip + fire", shift = "Sprint — move faster"}
		"crossbow": return {space = "Power Shot — 4x damage, pierces all", shift = "Aimed Mode — slow move, 2x damage"}
		"staff": return {space = "Powershot — charged blast", shift = "Teleport — short-range blink"}
		"wand": return {space = "Blink — instant dodge", shift = "Magic Barrage — rapid bolts"}
		"tome": return {space = "Nova Burst — magic explosion", shift = "Arcane Shield — absorb damage"}
		"javelin": return {space = "Javelin Throw — long-range pierce", shift = "Javelin Rain — area bombardment"}
		"sling": return {space = "Scatter Volley — wide spray", shift = "Rapid Sling — faster fire rate"}
		"halberd": return {space = "Sweep — wide arc cleave", shift = "Guard Stance — immobile, auto-counter"}
		"greatsword": return {space = "Overhead Slam — heavy AoE hit", shift = "Berserker Rage — faster, stronger"}
		"great_axe": return {space = "Whirlwind Cleave — spinning dash", shift = "Executioner — bonus vs low HP"}
		"whip": return {space = "Lasso Pull — grab + drag enemy", shift = "Crack — extended range stun"}
		"scythe": return {space = "Reap — dash through enemies", shift = "Soul Harvest — drain on kill"}
		"claws": return {space = "Dash — quick dodge roll", shift = "Frenzy — rapid claw swipes"}
		"sceptre": return {space = "Dash — quick dodge roll", shift = "Sprint — move faster"}
		_: return {space = "Dash — quick dodge roll", shift = "Sprint — move faster"}
