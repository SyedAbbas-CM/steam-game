class_name CraftingUI
extends CanvasLayer

signal crafting_closed

const SOCKET_SLOT_SIZE := 84
const INVENTORY_SCREEN_SCENE := preload("res://scenes/ui/inventory_screen.tscn")
const ITEM_ICON_HELPER := preload("res://scripts/ui/item_icon_helper.gd")

var _panel: PanelContainer
var _title_label: Label
var _gold_label: Label
var _recipe_list: VBoxContainer
var _detail_container: VBoxContainer
var _status_label: Label
var _close_btn: Button
var _back_btn: Button
var _socket_btn: Button
var _salvage_btn: Button
var _equipment_manager: EquipmentManager
var _craft_type: String = ""  # "blacksmith" or "alchemist"
var _recipes: Array = []  # Array[CraftingRecipe]
var _selected_recipe: CraftingRecipe = null
var _mode: String = "recipes"
var _socket_selected_item: EquipmentItem = null
var _socket_active_socket: int = -1
var _recipe_header: Label
var _detail_header: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	add_to_group("crafting_ui")
	_build_ui()

func _build_ui() -> void:
	# Backdrop overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	overlay.name = "Overlay"
	add_child(overlay)

	# Ornate framed panel with gold corner brackets
	_panel = AshfieldsUI.ornate_panel(20)
	_panel.visible = false
	_panel.anchor_left = 0.1
	_panel.anchor_right = 0.9
	_panel.anchor_top = 0.08
	_panel.anchor_bottom = 0.92
	_panel.theme = load("res://assets/themes/ashfields_theme.tres") as Theme
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	# Section header in pixel font + gold underline
	var title_block = AshfieldsUI.section_title("FORGE", 18)
	vbox.add_child(title_block)
	_title_label = title_block.get_child(0) as Label  # back-compat: existing setter writes here

	var meta_row = HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 16)
	vbox.add_child(meta_row)

	_gold_label = Label.new()
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_gold_label.add_theme_font_size_override("font_size", 32)
	meta_row.add_child(_gold_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 30)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_row.add_child(_status_label)

	var split = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 380
	vbox.add_child(split)

	var left_panel = PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left_style = StyleBoxFlat.new()
	left_style.bg_color = Color(0.08, 0.06, 0.13, 0.96)
	left_style.border_color = Color(0.24, 0.2, 0.32)
	left_style.set_border_width_all(2)
	left_style.set_corner_radius_all(5)
	left_style.content_margin_left = 10
	left_style.content_margin_right = 10
	left_style.content_margin_top = 10
	left_style.content_margin_bottom = 10
	left_panel.add_theme_stylebox_override("panel", left_style)
	split.add_child(left_panel)

	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_vbox)

	_recipe_header = Label.new()
	_recipe_header.text = "Recipes"
	_recipe_header.add_theme_font_size_override("font_size", 34)
	_recipe_header.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
	left_vbox.add_child(_recipe_header)

	var recipe_scroll = ScrollContainer.new()
	recipe_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(recipe_scroll)

	_recipe_list = VBoxContainer.new()
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_list.add_theme_constant_override("separation", 4)
	recipe_scroll.add_child(_recipe_list)

	var right_panel = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var right_style = StyleBoxFlat.new()
	right_style.bg_color = Color(0.05, 0.04, 0.09, 0.98)
	right_style.border_color = Color(0.24, 0.2, 0.32)
	right_style.set_border_width_all(2)
	right_style.set_corner_radius_all(5)
	right_style.content_margin_left = 12
	right_style.content_margin_right = 12
	right_style.content_margin_top = 10
	right_style.content_margin_bottom = 10
	right_panel.add_theme_stylebox_override("panel", right_style)
	split.add_child(right_panel)

	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_vbox)

	_detail_header = Label.new()
	_detail_header.text = "Recipe Details"
	_detail_header.add_theme_font_size_override("font_size", 34)
	_detail_header.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
	right_vbox.add_child(_detail_header)

	var detail_scroll = ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(detail_scroll)

	_detail_container = VBoxContainer.new()
	_detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_container.add_theme_constant_override("separation", 4)
	detail_scroll.add_child(_detail_container)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	_back_btn = Button.new()
	_back_btn.focus_mode = Control.FOCUS_NONE
	_back_btn.text = "Back"
	_back_btn.add_theme_font_size_override("font_size", 30)
	_back_btn.pressed.connect(_show_recipe_list)
	_back_btn.visible = false
	btn_row.add_child(_back_btn)

	_socket_btn = Button.new()
	_socket_btn.focus_mode = Control.FOCUS_NONE
	_socket_btn.text = "Socketing"
	_socket_btn.add_theme_font_size_override("font_size", 30)
	_socket_btn.pressed.connect(_show_socketing)
	_socket_btn.visible = false
	btn_row.add_child(_socket_btn)

	_salvage_btn = Button.new()
	_salvage_btn.focus_mode = Control.FOCUS_NONE
	_salvage_btn.text = "Salvage"
	_salvage_btn.add_theme_font_size_override("font_size", 30)
	_salvage_btn.pressed.connect(_open_inventory_station_tab.bind("salvage"))
	_salvage_btn.visible = false
	btn_row.add_child(_salvage_btn)

	_close_btn = Button.new()
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.text = "Close"
	_close_btn.add_theme_font_size_override("font_size", 30)
	_close_btn.pressed.connect(_close)
	btn_row.add_child(_close_btn)

func open(craft_type: String) -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("open", -3.0, 0.0)
	_craft_type = craft_type
	if not _equipment_manager:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			_equipment_manager = player.get_node_or_null("EquipmentManager") as EquipmentManager
	_load_recipes()
	_apply_theme()
	_update_gold()
	_mode = "recipes"
	_socket_selected_item = null
	_socket_active_socket = -1
	_socket_btn.visible = _craft_type == "blacksmith"
	_salvage_btn.visible = _craft_type == "blacksmith"
	_show_recipe_list()
	_panel.visible = true
	var overlay = get_node_or_null("Overlay")
	if overlay:
		overlay.visible = true

func _apply_theme() -> void:
	# Tint corner ornaments + title for blacksmith (warm gold) vs alchemist (cool green)
	var orn_color := AshfieldsUI.GOLD
	var title_color := AshfieldsUI.GOLD
	if _craft_type == "alchemist":
		orn_color = Color(0.275, 0.804, 0.502)
		title_color = Color(0.353, 0.918, 0.612)
	if _title_label and _title_label.label_settings:
		var ls := _title_label.label_settings as LabelSettings
		ls.font_color = title_color
	# Find the corner ornaments overlay we attached in ornate_panel
	for child in _panel.get_children():
		if child.has_method("set"):
			var col_prop = child.get("col")
			if col_prop is Color:
				child.col = orn_color
				child.queue_redraw()

func _load_recipes() -> void:
	_recipes.clear()
	var paths = ResourceRegistry.crafting_recipes()
	for path in paths:
		var recipe = load(path) as CraftingRecipe
		if recipe and recipe.recipe_type == _craft_type:
			_recipes.append(recipe)
	# Sort by level
	_recipes.sort_custom(func(a: CraftingRecipe, b: CraftingRecipe) -> bool:
		return a.required_level < b.required_level
	)

func _update_gold() -> void:
	var gm = get_node_or_null("/root/GameManager")
	_gold_label.text = "Gold: " + str(gm.get_gold() if gm else 0)

func _show_recipe_list() -> void:
	_mode = "recipes"
	_selected_recipe = null
	_back_btn.visible = false
	var type_name = "Blacksmith" if _craft_type == "blacksmith" else "Alchemist"
	_title_label.text = type_name + " - Recipes"
	_recipe_header.text = type_name + " Recipes"
	_detail_header.text = "Recipe Details"
	_status_label.text = "Inspect any recipe to see materials, level gates, and blueprint progress."
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	for c in _recipe_list.get_children():
		c.queue_free()
	for c in _detail_container.get_children():
		c.queue_free()

	var player_level = _get_player_level()
	var visible_count := 0

	for recipe in _recipes:
		var result_item = load(recipe.result_item_path) as EquipmentItem
		if result_item == null:
			continue
		visible_count += 1
		var gm = get_node_or_null("/root/GameManager")
		var blueprint_locked: bool = result_item != null and result_item.blueprint_id != "" and gm != null and not gm.has_blueprint(result_item.blueprint_id)
		var level_locked: bool = recipe.required_level > player_level
		var row_panel = PanelContainer.new()
		var row_style = StyleBoxFlat.new()
		row_style.bg_color = Color(0.12, 0.09, 0.17, 0.96)
		row_style.border_color = Color(0.22, 0.18, 0.28)
		row_style.set_border_width_all(1)
		row_style.set_corner_radius_all(4)
		row_style.content_margin_left = 8
		row_style.content_margin_right = 8
		row_style.content_margin_top = 6
		row_style.content_margin_bottom = 6
		row_panel.add_theme_stylebox_override("panel", row_style)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		row_panel.add_child(hbox)

		var icon = _make_recipe_icon(result_item, 32)
		hbox.add_child(icon)

		var name_label = Label.new()
		var lock_tag: String = ""
		if blueprint_locked:
			lock_tag = " [Locked Blueprint]"
		elif level_locked:
			lock_tag = " [Level %d]" % recipe.required_level
		name_label.text = recipe.recipe_name + lock_tag
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 28)
		var can_craft = _can_craft(recipe)
		if blueprint_locked:
			name_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
		elif level_locked:
			name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		elif can_craft:
			name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		else:
			name_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
		hbox.add_child(name_label)

		# Brief ingredient summary
		var ing_text = ""
		for ing in recipe.ingredients:
			if ing_text != "":
				ing_text += ", "
			ing_text += str(ing.get("count", 1)) + "x " + str(ing.get("item_name", "?"))
		var ing_label = Label.new()
		ing_label.text = ing_text
		ing_label.add_theme_font_size_override("font_size", 26)
		ing_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		hbox.add_child(ing_label)

		var cost_label = Label.new()
		cost_label.text = str(recipe.gold_cost) + "g"
		cost_label.add_theme_font_size_override("font_size", 28)
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		hbox.add_child(cost_label)

		var state_label = Label.new()
		state_label.add_theme_font_size_override("font_size", 28)
		if blueprint_locked:
			state_label.text = "Blueprint"
			state_label.add_theme_color_override("font_color", Color(0.8, 0.65, 1.0))
		elif level_locked:
			state_label.text = "Locked"
			state_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		elif can_craft:
			state_label.text = "Ready"
			state_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.45))
		else:
			state_label.text = "Missing Mats"
			state_label.add_theme_color_override("font_color", Color(0.95, 0.7, 0.35))
		hbox.add_child(state_label)

		var btn = Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 28)
		btn.text = "Inspect"
		btn.pressed.connect(_select_recipe.bind(recipe))
		hbox.add_child(btn)

		_recipe_list.add_child(row_panel)

	if visible_count == 0:
		var empty_label = Label.new()
		empty_label.text = "No recipes are available here yet."
		empty_label.add_theme_font_size_override("font_size", 32)
		empty_label.add_theme_color_override("font_color", Color(0.8, 0.45, 0.45))
		_recipe_list.add_child(empty_label)

func _show_socketing() -> void:
	_open_inventory_station_tab("socket")

func _open_inventory_station_tab(tab_name: String) -> void:
	var inventory_screen = get_tree().get_first_node_in_group("inventory_screen") as InventoryScreen
	if not inventory_screen:
		var inventory_scene = INVENTORY_SCREEN_SCENE.instantiate()
		inventory_screen = inventory_scene as InventoryScreen
		if inventory_screen == null:
			return
		get_tree().current_scene.add_child(inventory_screen)
		if _equipment_manager:
			inventory_screen.setup(_equipment_manager)
	inventory_screen.open_to_tab(tab_name)
	_close()

func _select_recipe(recipe: CraftingRecipe) -> void:
	# Stay on the same screen — only the right-hand detail panel updates.
	# Recipe list on the left stays visible so the player can keep browsing.
	_selected_recipe = recipe
	_back_btn.visible = false
	_detail_header.text = recipe.recipe_name
	_status_label.text = ""

	for c in _detail_container.get_children():
		c.queue_free()

	# Result item preview
	var result_item = load(recipe.result_item_path) as EquipmentItem
	var gm = get_node_or_null("/root/GameManager")
	var blueprint_locked: bool = result_item != null and result_item.blueprint_id != "" and gm != null and not gm.has_blueprint(result_item.blueprint_id)
	var level_locked: bool = recipe.required_level > _get_player_level()
	if result_item:
		var result_row = HBoxContainer.new()
		result_row.add_theme_constant_override("separation", 10)
		_detail_container.add_child(result_row)

		var icon = _make_recipe_icon(result_item, 40)
		result_row.add_child(icon)

		var result_text = VBoxContainer.new()
		result_text.add_theme_constant_override("separation", 3)
		result_row.add_child(result_text)

		var result_label = Label.new()
		result_label.text = "Result: " + result_item.item_name
		if recipe.result_count > 1:
			result_label.text += " x" + str(recipe.result_count)
		result_label.add_theme_font_size_override("font_size", 30)
		result_label.add_theme_color_override("font_color", _rarity_color(result_item.rarity))
		result_text.add_child(result_label)

		if result_item.description != "":
			var desc_label = Label.new()
			desc_label.text = result_item.description
			desc_label.add_theme_font_size_override("font_size", 28)
			desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			result_text.add_child(desc_label)

		# Show stat bonuses
		for mod in result_item.modifiers:
			var mod_label = Label.new()
			var stat_name = StatModifier.StatType.keys()[mod.stat]
			mod_label.text = "  +" + str(mod.flat_bonus) + " " + stat_name.replace("_", " ").capitalize()
			mod_label.add_theme_font_size_override("font_size", 28)
			mod_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
			_detail_container.add_child(mod_label)

	var sep = HSeparator.new()
	_detail_container.add_child(sep)

	# Ingredients
	var ing_header = Label.new()
	ing_header.text = "Ingredients:"
	ing_header.add_theme_font_size_override("font_size", 28)
	if _craft_type == "alchemist":
		ing_header.add_theme_color_override("font_color", Color(0.3, 0.9, 0.6))
	else:
		ing_header.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	_detail_container.add_child(ing_header)

	var all_have = true
	if blueprint_locked:
		all_have = false
		var bp_label = Label.new()
		var progress = gm.get_blueprint_progress(result_item.blueprint_id) if gm else 0
		var bp_def = gm.get_blueprint_definition(result_item.blueprint_id) if gm else null
		var needed = bp_def.required_fragments if bp_def else 1
		bp_label.text = "  Locked Blueprint: %d/%d fragments" % [progress, needed]
		bp_label.add_theme_font_size_override("font_size", 28)
		bp_label.add_theme_color_override("font_color", Color(0.8, 0.65, 1.0))
		_detail_container.add_child(bp_label)
	if level_locked:
		all_have = false
		var level_label = Label.new()
		level_label.text = "  Requires Level %d" % recipe.required_level
		level_label.add_theme_font_size_override("font_size", 28)
		level_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		_detail_container.add_child(level_label)
	for ing in recipe.ingredients:
		var item_name: String = ing.get("item_name", "")
		var needed: int = ing.get("count", 1)
		var owned = _count_item(item_name)
		var has_enough = owned >= needed

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)

		var label = Label.new()
		label.text = "  " + item_name + ": " + str(owned) + "/" + str(needed)
		label.add_theme_font_size_override("font_size", 28)
		if has_enough:
			label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			all_have = false
		hbox.add_child(label)

		_detail_container.add_child(hbox)

	# Gold cost
	var current_gold = gm.get_gold() if gm else 0
	var gold_label = Label.new()
	gold_label.text = "  Gold: " + str(current_gold) + "/" + str(recipe.gold_cost)
	gold_label.add_theme_font_size_override("font_size", 28)
	if current_gold >= recipe.gold_cost:
		gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	else:
		gold_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		all_have = false
	_detail_container.add_child(gold_label)

	var sep2 = HSeparator.new()
	_detail_container.add_child(sep2)

	# Craft button
	var craft_btn = Button.new()
	craft_btn.focus_mode = Control.FOCUS_NONE
	if blueprint_locked:
		craft_btn.text = "Blueprint Locked"
	elif level_locked:
		craft_btn.text = "Level Locked"
	else:
		craft_btn.text = "Craft" if all_have else "Missing Materials"
	craft_btn.add_theme_font_size_override("font_size", 30)
	craft_btn.disabled = not all_have
	if all_have:
		craft_btn.pressed.connect(_do_craft.bind(recipe))
	_detail_container.add_child(craft_btn)

func _do_craft(recipe: CraftingRecipe) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not _equipment_manager:
		return

	# Verify we can still craft
	if not _can_craft(recipe):
		_status_label.text = "Missing materials!"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		return

	# Spend gold
	if not gm.spend_gold(recipe.gold_cost):
		_status_label.text = "Not enough gold!"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		return

	# Remove ingredients
	for ing in recipe.ingredients:
		var item_name: String = ing.get("item_name", "")
		var count: int = ing.get("count", 1)
		_remove_items(item_name, count)

	# Add result item(s)
	var result_item = load(recipe.result_item_path) as EquipmentItem
	if result_item:
		for i in range(recipe.result_count):
			var copy = result_item.make_copy()
			_equipment_manager.add_to_inventory(copy)
		if gm:
			gm.record_crafted_item(recipe.result_item_path, recipe.result_count)
			for ing in recipe.ingredients:
				gm.record_material_discovery(str(ing.get("item_name", "")), "crafted_with")

	_status_label.text = "Crafted: " + recipe.recipe_name + "!"
	if _craft_type == "alchemist":
		_status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.6))
	else:
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("bonus", -2.0, 0.0)
	_update_gold()
	_equipment_manager.inventory_changed.emit()
	_equipment_manager.stats_changed.emit()

	# Refresh the detail view
	_select_recipe(recipe)

func _can_craft(recipe: CraftingRecipe) -> bool:
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not _equipment_manager:
		return false
	if gm.get_gold() < recipe.gold_cost:
		return false
	var result_item = load(recipe.result_item_path) as EquipmentItem
	if result_item and result_item.blueprint_id != "" and not gm.has_blueprint(result_item.blueprint_id):
		return false
	if recipe.required_level > _get_player_level():
		return false
	for ing in recipe.ingredients:
		var item_name: String = ing.get("item_name", "")
		var needed: int = ing.get("count", 1)
		if _count_item(item_name) < needed:
			return false
	return true

func _count_item(item_name: String) -> int:
	if not _equipment_manager:
		return 0
	var count = 0
	for item in _equipment_manager.inventory:
		if item.item_name == item_name:
			count += 1
	return count

func _remove_items(item_name: String, count: int) -> void:
	if not _equipment_manager:
		return
	var removed = 0
	# Remove from end to avoid index shifting issues
	for i in range(_equipment_manager.inventory.size() - 1, -1, -1):
		if removed >= count:
			break
		if _equipment_manager.inventory[i].item_name == item_name:
			_equipment_manager.inventory.remove_at(i)
			removed += 1

func _get_player_level() -> int:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var ls = player.get_node_or_null("LevelSystem") as LevelSystem
		if ls:
			return ls.level
	return 1

func _rarity_color(rarity: int) -> Color:
	match rarity:
		0: return Color(0.8, 0.8, 0.8)
		1: return Color(0.3, 0.9, 0.3)
		2: return Color(0.3, 0.8, 1.0)
	return Color.WHITE

func _make_recipe_icon(item: EquipmentItem, size: int) -> Control:
	var holder = CenterContainer.new()
	holder.custom_minimum_size = Vector2(size, size)
	var icon = TextureRect.new()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(size, size)
	var tex = ITEM_ICON_HELPER.get_icon_texture(item)
	if tex:
		icon.texture = tex
	holder.add_child(icon)
	return holder

func _close() -> void:
	_panel.visible = false
	var overlay = get_node_or_null("Overlay")
	if overlay:
		overlay.visible = false
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("close", -4.0, 0.0)
	crafting_closed.emit()

func is_open() -> bool:
	return _panel.visible

func _input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if event.is_action_pressed("inventory"):
		_close()
