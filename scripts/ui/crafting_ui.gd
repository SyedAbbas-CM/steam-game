class_name CraftingUI
extends CanvasLayer

signal crafting_closed

var _panel: PanelContainer
var _title_label: Label
var _gold_label: Label
var _recipe_list: VBoxContainer
var _detail_container: VBoxContainer
var _status_label: Label
var _close_btn: Button
var _back_btn: Button
var _equipment_manager: EquipmentManager
var _craft_type: String = ""  # "blacksmith" or "alchemist"
var _recipes: Array = []  # Array[CraftingRecipe]
var _selected_recipe: CraftingRecipe = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	add_to_group("crafting_ui")
	_build_ui()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.anchor_left = 0.15
	_panel.anchor_right = 0.85
	_panel.anchor_top = 0.08
	_panel.anchor_bottom = 0.92

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.1, 0.95)
	style.border_color = Color(0.8, 0.5, 0.2)  # default blacksmith orange
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

	_recipe_list = VBoxContainer.new()
	_recipe_list.add_theme_constant_override("separation", 4)
	inner.add_child(_recipe_list)

	_detail_container = VBoxContainer.new()
	_detail_container.add_theme_constant_override("separation", 4)
	inner.add_child(_detail_container)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	_back_btn = Button.new()
	_back_btn.focus_mode = Control.FOCUS_NONE
	_back_btn.text = "Back"
	_back_btn.add_theme_font_size_override("font_size", 12)
	_back_btn.pressed.connect(_show_recipe_list)
	_back_btn.visible = false
	btn_row.add_child(_back_btn)

	_close_btn = Button.new()
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.text = "Close"
	_close_btn.add_theme_font_size_override("font_size", 12)
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
	_show_recipe_list()
	_panel.visible = true

func _apply_theme() -> void:
	var style = _panel.get_theme_stylebox("panel") as StyleBoxFlat
	if _craft_type == "alchemist":
		style.border_color = Color(0.2, 0.7, 0.5)
		_title_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.6))
	else:
		style.border_color = Color(0.8, 0.5, 0.2)
		_title_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))

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
	_selected_recipe = null
	_back_btn.visible = false
	var type_name = "Blacksmith" if _craft_type == "blacksmith" else "Alchemist"
	_title_label.text = type_name + " - Recipes"
	_status_label.text = "Select a recipe to craft"
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	for c in _recipe_list.get_children():
		c.queue_free()
	for c in _detail_container.get_children():
		c.queue_free()

	var player_level = _get_player_level()

	for recipe in _recipes:
		var result_item = load(recipe.result_item_path) as EquipmentItem
		var gm = get_node_or_null("/root/GameManager")
		var blueprint_locked = result_item and result_item.blueprint_id != "" and gm and not gm.has_blueprint(result_item.blueprint_id)
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)

		var name_label = Label.new()
		name_label.text = recipe.recipe_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 11)
		var can_craft = _can_craft(recipe)
		if blueprint_locked:
			name_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
		elif recipe.required_level > player_level:
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
		ing_label.add_theme_font_size_override("font_size", 9)
		ing_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		hbox.add_child(ing_label)

		var cost_label = Label.new()
		cost_label.text = str(recipe.gold_cost) + "g"
		cost_label.add_theme_font_size_override("font_size", 10)
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		hbox.add_child(cost_label)

		var btn = Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 10)
		if blueprint_locked:
			var progress = gm.get_blueprint_progress(result_item.blueprint_id) if gm else 0
			var def = gm.get_blueprint_definition(result_item.blueprint_id) if gm else null
			if def:
				btn.text = "BP %d/%d" % [progress, def.required_fragments]
			else:
				btn.text = "LOCKED"
			btn.disabled = true
		elif recipe.required_level > player_level:
			btn.text = "Lv" + str(recipe.required_level)
			btn.disabled = true
		else:
			btn.text = "View"
			btn.pressed.connect(_select_recipe.bind(recipe))
		hbox.add_child(btn)

		_recipe_list.add_child(hbox)

func _select_recipe(recipe: CraftingRecipe) -> void:
	_selected_recipe = recipe
	_back_btn.visible = true
	_title_label.text = "Craft: " + recipe.recipe_name
	_status_label.text = ""

	for c in _recipe_list.get_children():
		c.queue_free()
	for c in _detail_container.get_children():
		c.queue_free()

	# Result item preview
	var result_item = load(recipe.result_item_path) as EquipmentItem
	if result_item:
		var result_label = Label.new()
		result_label.text = "Result: " + result_item.item_name
		if recipe.result_count > 1:
			result_label.text += " x" + str(recipe.result_count)
		result_label.add_theme_font_size_override("font_size", 12)
		result_label.add_theme_color_override("font_color", _rarity_color(result_item.rarity))
		_detail_container.add_child(result_label)

		if result_item.description != "":
			var desc_label = Label.new()
			desc_label.text = result_item.description
			desc_label.add_theme_font_size_override("font_size", 10)
			desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			_detail_container.add_child(desc_label)

		# Show stat bonuses
		for mod in result_item.modifiers:
			var mod_label = Label.new()
			var stat_name = StatModifier.StatType.keys()[mod.stat]
			mod_label.text = "  +" + str(mod.flat_bonus) + " " + stat_name.replace("_", " ").capitalize()
			mod_label.add_theme_font_size_override("font_size", 10)
			mod_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
			_detail_container.add_child(mod_label)

	var sep = HSeparator.new()
	_detail_container.add_child(sep)

	# Ingredients
	var ing_header = Label.new()
	ing_header.text = "Ingredients:"
	ing_header.add_theme_font_size_override("font_size", 11)
	if _craft_type == "alchemist":
		ing_header.add_theme_color_override("font_color", Color(0.3, 0.9, 0.6))
	else:
		ing_header.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	_detail_container.add_child(ing_header)

	var all_have = true
	for ing in recipe.ingredients:
		var item_name: String = ing.get("item_name", "")
		var needed: int = ing.get("count", 1)
		var owned = _count_item(item_name)
		var has_enough = owned >= needed

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)

		var label = Label.new()
		label.text = "  " + item_name + ": " + str(owned) + "/" + str(needed)
		label.add_theme_font_size_override("font_size", 11)
		if has_enough:
			label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			all_have = false
		hbox.add_child(label)

		_detail_container.add_child(hbox)

	# Gold cost
	var gm = get_node_or_null("/root/GameManager")
	var current_gold = gm.get_gold() if gm else 0
	var gold_label = Label.new()
	gold_label.text = "  Gold: " + str(current_gold) + "/" + str(recipe.gold_cost)
	gold_label.add_theme_font_size_override("font_size", 11)
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
	craft_btn.text = "Craft" if all_have else "Missing Materials"
	craft_btn.add_theme_font_size_override("font_size", 12)
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

func _close() -> void:
	_panel.visible = false
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
