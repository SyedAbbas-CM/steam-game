class_name RelicShopUI
extends CanvasLayer

signal shop_closed

var _panel: PanelContainer
var _title_label: Label
var _relics_label: Label
var _items_container: VBoxContainer
var _close_btn: Button
var _status_label: Label
var _definitions: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_load_definitions()
	_build_ui()

func _load_definitions() -> void:
	_definitions.clear()
	var dir = DirAccess.open("res://resources/upgrades/")
	if not dir:
		return
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var def = load("res://resources/upgrades/" + file) as UpgradeDefinition
			if def:
				_definitions.append(def)
		file = dir.get_next()
	_definitions.sort_custom(func(a, b): return a.category < b.category or (a.category == b.category and a.id < b.id))

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.anchor_left = 0.1
	_panel.anchor_right = 0.9
	_panel.anchor_top = 0.05
	_panel.anchor_bottom = 0.95

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.1, 0.95)
	style.border_color = Color(0.7, 0.5, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(main_vbox)

	# Header row
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	main_vbox.add_child(header)

	_title_label = Label.new()
	_title_label.text = "Relic Upgrades"
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	header.add_child(_title_label)

	_relics_label = Label.new()
	_relics_label.add_theme_font_size_override("font_size", 22)
	_relics_label.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
	_relics_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_relics_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_relics_label)

	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.add_theme_font_size_override("font_size", 22)
	_close_btn.custom_minimum_size = Vector2(44, 44)
	_close_btn.pressed.connect(close)
	header.add_child(_close_btn)

	# Scrollable upgrade list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	_items_container = VBoxContainer.new()
	_items_container.add_theme_constant_override("separation", 4)
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_items_container)

	# Status message
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_status_label)

func open() -> void:
	_panel.visible = true
	get_tree().paused = true
	_refresh()

func close() -> void:
	_panel.visible = false
	get_tree().paused = false
	shop_closed.emit()
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("close", -4.0)

func is_open() -> bool:
	return _panel and _panel.visible

func _refresh() -> void:
	# Update relics display
	var gm = get_node_or_null("/root/GameManager")
	var relics = gm.get_relics() if gm else 0
	_relics_label.text = "Relics: %d" % relics

	# Get player class for filtering
	var player_class = gm.selected_class if gm and gm.get("selected_class") else "warrior"

	# Clear and rebuild
	for child in _items_container.get_children():
		child.queue_free()

	var last_category = -1
	var category_names = ["COMBAT", "SURVIVAL", "UTILITY", "CLASS"]

	for def in _definitions:
		# Skip class upgrades for other classes
		if def.required_class != "" and def.required_class != player_class:
			continue

		# Category header
		if def.category != last_category:
			last_category = def.category
			var cat_label = Label.new()
			cat_label.text = category_names[def.category]
			cat_label.add_theme_font_size_override("font_size", 20)
			cat_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
			_items_container.add_child(cat_label)

		_add_upgrade_row(def, relics)

func _add_upgrade_row(def: UpgradeDefinition, relics: int) -> void:
	var gm = get_node_or_null("/root/GameManager")
	var current_level = gm.save_data.permanent_upgrades.get(def.id, 0) if gm and gm.save_data else 0
	var maxed = current_level >= def.max_level
	var cost = def.get_cost(current_level) if not maxed else 0
	var can_afford = relics >= cost and not maxed

	# Check prerequisite
	var prereq_met = true
	if def.required_upgrade != "":
		var prereq_lv = gm.save_data.permanent_upgrades.get(def.required_upgrade, 0) if gm and gm.save_data else 0
		if prereq_lv <= 0:
			prereq_met = false

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size.y = 48
	_items_container.add_child(row)

	# Name + level
	var name_label = Label.new()
	name_label.text = "%s  Lv %d/%d" % [def.upgrade_name, current_level, def.max_level]
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8) if not maxed else Color(0.5, 0.9, 0.5))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = def.description
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(desc_label)

	# Buy button
	var buy_btn = Button.new()
	if maxed:
		buy_btn.text = "MAXED"
		buy_btn.disabled = true
	elif not prereq_met:
		buy_btn.text = "LOCKED"
		buy_btn.disabled = true
	else:
		buy_btn.text = "%d Relics" % cost
		buy_btn.disabled = not can_afford
	buy_btn.custom_minimum_size = Vector2(140, 40)
	buy_btn.add_theme_font_size_override("font_size", 16)
	buy_btn.pressed.connect(_on_buy.bind(def.id))
	row.add_child(buy_btn)

func _on_buy(upgrade_id: String) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.save_data:
		return
	# Find definition
	var def: UpgradeDefinition = null
	for d in _definitions:
		if d.id == upgrade_id:
			def = d
			break
	if not def:
		return

	var current_level = gm.save_data.permanent_upgrades.get(upgrade_id, 0)
	if current_level >= def.max_level:
		return
	var cost = def.get_cost(current_level)
	if gm.get_relics() < cost:
		return

	# Purchase
	gm.save_data.relics -= cost
	gm.save_data.permanent_upgrades[upgrade_id] = current_level + 1
	gm.save_data.save_to_slot()

	# Reload bonuses on player
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("equipment_manager"):
		player.equipment_manager.load_permanent_upgrades()
		player.equipment_manager.stats_changed.emit()

	_status_label.text = "Upgraded %s to Lv %d!" % [def.upgrade_name, current_level + 1]

	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("mystical", -2.0)

	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
