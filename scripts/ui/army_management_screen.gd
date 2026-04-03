class_name ArmyManagementScreen
extends CanvasLayer

## Army management UI with 4 tabs: ARMY overview, DIVISIONS, RECRUIT, UPGRADES.
## Opened from the War Table interactable in Aria.

signal closed

const HIRE_COSTS := {
	"infantry": 80,
	"archer": 120,
	"heavy_infantry": 180,
	"cavalry": 250,
	"mage": 220,
	"heavy_cavalry": 400,
	"spear": 130,
	"horse_archer": 300,
	"ranged_infantry": 160,
}
const UNIT_NAMES := {
	"infantry": "Infantry",
	"archer": "Archer",
	"heavy_infantry": "Heavy Infantry",
	"cavalry": "Cavalry",
	"mage": "Mage",
	"heavy_cavalry": "Heavy Cavalry",
	"spear": "Spear Infantry",
	"horse_archer": "Horse Archer",
	"ranged_infantry": "Ranged Infantry",
}
const UNIT_ORDER := ["infantry", "heavy_infantry", "spear", "archer", "ranged_infantry", "cavalry", "heavy_cavalry", "horse_archer", "mage"]
const MAX_HIRED := 300

var _panel: PanelContainer
var _tab_container: Control
var _tab_buttons: Array[Button] = []
var _tab_pages: Array[Control] = []
var _current_tab: int = 0

# Recruit tab widgets
var _recruit_rows: Dictionary = {}
var _gold_label: Label
var _recruit_total_label: Label

# Upgrade tab widgets
var _upgrade_rows: Dictionary = {}
var _tokens_label: Label

# Army tab widgets
var _army_info_label: Label

# Division tab widgets
var _div_list_container: VBoxContainer
var _div_edit_panel: Control
var _div_name_edit: LineEdit
var _div_unit_rows: Dictionary = {}
var _div_available_label: Label
var _editing_div_index: int = -1  # -1 = creating new

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("army_management")

	# Overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Main panel
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(800, 600)
	_panel.position = Vector2((1920 - 800) / 2.0, (1080 - 600) / 2.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.14, 0.95)
	style.border_color = Color(0.5, 0.4, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "WAR TABLE"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Tab bar
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	vbox.add_child(tab_bar)
	var tab_names: Array[String] = ["ARMY", "DIVISIONS", "RECRUIT", "UPGRADES"]
	for i in 4:
		var tab_name: String = tab_names[i]
		var btn := Button.new()
		btn.text = tab_name
		btn.add_theme_font_size_override("font_size", 16)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_switch_tab.bind(i))
		tab_bar.add_child(btn)
		_tab_buttons.append(btn)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Tab container
	_tab_container = Control.new()
	_tab_container.custom_minimum_size = Vector2(760, 460)
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tab_container)

	_build_army_tab()
	_build_divisions_tab()
	_build_recruit_tab()
	_build_upgrades_tab()

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close [ESC]"
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(_close)
	vbox.add_child(close_btn)

	_switch_tab(0)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("close", -5.0)
	closed.emit()
	queue_free()

func _switch_tab(index: int) -> void:
	_current_tab = index
	for i in _tab_pages.size():
		_tab_pages[i].visible = (i == index)
	for i in _tab_buttons.size():
		_tab_buttons[i].modulate = Color.WHITE if i == index else Color(0.6, 0.6, 0.6)
	if index == 0:
		_refresh_army_tab()
	elif index == 1:
		_refresh_divisions_tab()
	elif index == 2:
		_refresh_recruit_tab()
	elif index == 3:
		_refresh_upgrades_tab()

# ==================== ARMY TAB ====================

func _build_army_tab() -> void:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)
	_tab_container.add_child(page)
	_tab_pages.append(page)

	_army_info_label = Label.new()
	_army_info_label.add_theme_font_size_override("font_size", 15)
	_army_info_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_army_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_army_info_label.custom_minimum_size = Vector2(740, 0)
	_army_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_army_info_label)

func _refresh_army_tab() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.save_data:
		_army_info_label.text = "No save data."
		return

	var level: int = gm.save_data.player_level
	var militia := maxi(30, level * 5 + 15)
	var hired := _get_hired()
	var total_hired := 0
	var lines := "=== YOUR ARMY ===\n\n"
	lines += "Militia (Infantry): %d  (level %d)\n\n" % [militia, level]
	lines += "--- Hired Fighters ---\n"
	for type_name in UNIT_ORDER:
		var count: int = int(hired.get(type_name, 0))
		total_hired += count
		if count > 0:
			lines += "  %s: %d\n" % [UNIT_NAMES[type_name], count]
	if total_hired == 0:
		lines += "  (none)\n"
	lines += "\nTotal Army Strength: %d" % (militia + total_hired)
	lines += "\nTroop Tokens: %d" % gm.save_data.troop_tokens

	# Veteran summary
	var veterans: Dictionary = gm.save_data.army_state.get("veterans", {})
	if not veterans.is_empty():
		lines += "\n\n--- Veterans ---"
		for type_name in UNIT_ORDER:
			if veterans.has(type_name):
				var vet_data: Dictionary = veterans[type_name]
				var parts: Array[String] = []
				for rank in ["elite", "veteran", "trained"]:
					var n: int = vet_data.get(rank, 0)
					if n > 0:
						parts.append("%d %s" % [n, rank])
				if not parts.is_empty():
					lines += "\n  %s: %s" % [UNIT_NAMES[type_name], ", ".join(parts)]

	# Division summary
	var divs: Array = gm.save_data.army_divisions
	if not divs.is_empty():
		lines += "\n\n--- Divisions ---\n"
		for div in divs:
			var div_total := 0
			for u in div.get("units", []):
				div_total += int(u.get("count", 0))
			lines += "  %s: %d units\n" % [div.get("name", "?"), div_total]

	_army_info_label.text = lines

# ==================== DIVISIONS TAB ====================

func _build_divisions_tab() -> void:
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	_tab_container.add_child(page)
	_tab_pages.append(page)

	# Left: division list
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(200, 0)
	left.add_theme_constant_override("separation", 4)
	page.add_child(left)

	var list_title := Label.new()
	list_title.text = "Divisions"
	list_title.add_theme_font_size_override("font_size", 18)
	list_title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	left.add_child(list_title)

	_div_list_container = VBoxContainer.new()
	_div_list_container.add_theme_constant_override("separation", 2)
	left.add_child(_div_list_container)

	var create_btn := Button.new()
	create_btn.text = "+ Create Division"
	create_btn.add_theme_font_size_override("font_size", 14)
	create_btn.focus_mode = Control.FOCUS_NONE
	create_btn.pressed.connect(_on_create_division)
	left.add_child(create_btn)

	# Right: edit panel
	_div_edit_panel = VBoxContainer.new()
	_div_edit_panel.custom_minimum_size = Vector2(320, 0)
	_div_edit_panel.add_theme_constant_override("separation", 6)
	_div_edit_panel.visible = false
	page.add_child(_div_edit_panel)

	# Division name
	var name_row := HBoxContainer.new()
	_div_edit_panel.add_child(name_row)
	var name_lbl := Label.new()
	name_lbl.text = "Name: "
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_row.add_child(name_lbl)
	_div_name_edit = LineEdit.new()
	_div_name_edit.custom_minimum_size = Vector2(200, 0)
	_div_name_edit.placeholder_text = "Division name"
	name_row.add_child(_div_name_edit)

	# Unit type rows with +/- buttons and bulk buttons
	for type_name in UNIT_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_div_edit_panel.add_child(row)

		var lbl := Label.new()
		lbl.text = UNIT_NAMES[type_name]
		lbl.custom_minimum_size = Vector2(110, 0)
		lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(lbl)

		var minus_btn := Button.new()
		minus_btn.text = "-"
		minus_btn.custom_minimum_size = Vector2(28, 28)
		minus_btn.focus_mode = Control.FOCUS_NONE
		minus_btn.pressed.connect(_div_adjust.bind(type_name, -1))
		row.add_child(minus_btn)

		var count_lbl := Label.new()
		count_lbl.text = "0"
		count_lbl.custom_minimum_size = Vector2(30, 0)
		count_lbl.add_theme_font_size_override("font_size", 14)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(count_lbl)

		var plus_btn := Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(28, 28)
		plus_btn.focus_mode = Control.FOCUS_NONE
		plus_btn.pressed.connect(_div_adjust.bind(type_name, 1))
		row.add_child(plus_btn)

		var p5_btn := Button.new()
		p5_btn.text = "+5"
		p5_btn.custom_minimum_size = Vector2(34, 28)
		p5_btn.add_theme_font_size_override("font_size", 12)
		p5_btn.focus_mode = Control.FOCUS_NONE
		p5_btn.pressed.connect(_div_adjust.bind(type_name, 5))
		row.add_child(p5_btn)

		var p10_btn := Button.new()
		p10_btn.text = "+10"
		p10_btn.custom_minimum_size = Vector2(38, 28)
		p10_btn.add_theme_font_size_override("font_size", 12)
		p10_btn.focus_mode = Control.FOCUS_NONE
		p10_btn.pressed.connect(_div_adjust.bind(type_name, 10))
		row.add_child(p10_btn)

		var all_btn := Button.new()
		all_btn.text = "ALL"
		all_btn.custom_minimum_size = Vector2(38, 28)
		all_btn.add_theme_font_size_override("font_size", 12)
		all_btn.focus_mode = Control.FOCUS_NONE
		all_btn.pressed.connect(_div_adjust_all.bind(type_name))
		row.add_child(all_btn)

		_div_unit_rows[type_name] = {"count_label": count_lbl}

	_div_available_label = Label.new()
	_div_available_label.add_theme_font_size_override("font_size", 13)
	_div_available_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
	_div_edit_panel.add_child(_div_available_label)

	# Save / Delete buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	_div_edit_panel.add_child(btn_row)
	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.add_theme_font_size_override("font_size", 14)
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.pressed.connect(_on_save_division)
	btn_row.add_child(save_btn)
	var del_btn := Button.new()
	del_btn.text = "Delete"
	del_btn.add_theme_font_size_override("font_size", 14)
	del_btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	del_btn.focus_mode = Control.FOCUS_NONE
	del_btn.pressed.connect(_on_delete_division)
	btn_row.add_child(del_btn)

func _refresh_divisions_tab() -> void:
	# Clear list
	for child in _div_list_container.get_children():
		child.queue_free()

	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.save_data:
		return

	var divs: Array = gm.save_data.army_divisions
	for i in divs.size():
		var div: Dictionary = divs[i]
		var btn := Button.new()
		var div_total := 0
		for u in div.get("units", []):
			div_total += int(u.get("count", 0))
		btn.text = "%s (%d)" % [div.get("name", "?"), div_total]
		btn.add_theme_font_size_override("font_size", 14)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_edit_division.bind(i))
		_div_list_container.add_child(btn)

func _on_create_division() -> void:
	_editing_div_index = -1
	_div_name_edit.text = "Division %d" % (_get_divisions().size() + 1)
	for type_name in UNIT_ORDER:
		_div_unit_rows[type_name]["count_label"].text = "0"
	_div_edit_panel.visible = true
	_refresh_div_available()

func _on_edit_division(index: int) -> void:
	var divs := _get_divisions()
	if index >= divs.size():
		return
	_editing_div_index = index
	var div: Dictionary = divs[index]
	_div_name_edit.text = div.get("name", "")
	# Reset all to 0
	for type_name in UNIT_ORDER:
		_div_unit_rows[type_name]["count_label"].text = "0"
	# Fill from div data
	for u in div.get("units", []):
		var tn: String = u.get("type", "")
		if _div_unit_rows.has(tn):
			_div_unit_rows[tn]["count_label"].text = str(int(u.get("count", 0)))
	_div_edit_panel.visible = true
	_refresh_div_available()

func _div_adjust(type_name: String, delta: int) -> void:
	var lbl: Label = _div_unit_rows[type_name]["count_label"]
	var current := int(lbl.text)
	var new_val := maxi(0, current + delta)
	if delta > 0:
		var avail := _get_available_for_type(type_name) - current
		if avail <= 0:
			return
		new_val = mini(new_val, current + avail)
	lbl.text = str(new_val)
	_refresh_div_available()

func _div_adjust_all(type_name: String) -> void:
	var lbl: Label = _div_unit_rows[type_name]["count_label"]
	var current := int(lbl.text)
	var avail := _get_available_for_type(type_name) - current
	if avail <= 0:
		return
	lbl.text = str(current + avail)
	_refresh_div_available()

func _get_available_for_type(type_name: String) -> int:
	## Available = hired count - already assigned in OTHER divisions (not the one being edited)
	var hired := _get_hired()
	var total_hired: int = int(hired.get(type_name, 0))
	var assigned := 0
	var divs := _get_divisions()
	for i in divs.size():
		if i == _editing_div_index:
			continue
		for u in divs[i].get("units", []):
			if u.get("type", "") == type_name:
				assigned += int(u.get("count", 0))
	return maxi(0, total_hired - assigned)

func _refresh_div_available() -> void:
	var lines := "Available: "
	for type_name in UNIT_ORDER:
		var avail := _get_available_for_type(type_name)
		# Subtract what's currently set in the editor
		var current := int(_div_unit_rows[type_name]["count_label"].text)
		avail = maxi(0, avail - current)
		if avail > 0:
			lines += "%s:%d  " % [UNIT_NAMES[type_name].substr(0, 3), avail]
	_div_available_label.text = lines

func _on_save_division() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.save_data:
		return
	var div := {
		"name": _div_name_edit.text if _div_name_edit.text != "" else "Division",
		"units": [],
		"formation": "line",
	}
	for type_name in UNIT_ORDER:
		var count := int(_div_unit_rows[type_name]["count_label"].text)
		if count > 0:
			div["units"].append({"type": type_name, "count": count})

	if _editing_div_index >= 0 and _editing_div_index < gm.save_data.army_divisions.size():
		gm.save_data.army_divisions[_editing_div_index] = div
	else:
		gm.save_data.army_divisions.append(div)

	_div_edit_panel.visible = false
	_refresh_divisions_tab()
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click", -5.0)

func _on_delete_division() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.save_data:
		return
	if _editing_div_index >= 0 and _editing_div_index < gm.save_data.army_divisions.size():
		gm.save_data.army_divisions.remove_at(_editing_div_index)
	_editing_div_index = -1
	_div_edit_panel.visible = false
	_refresh_divisions_tab()

# ==================== RECRUIT TAB ====================

func _build_recruit_tab() -> void:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)
	_tab_container.add_child(page)
	_tab_pages.append(page)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	page.add_child(_gold_label)

	_recruit_total_label = Label.new()
	_recruit_total_label.add_theme_font_size_override("font_size", 14)
	_recruit_total_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	page.add_child(_recruit_total_label)

	for type_name in UNIT_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		page.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = "%s (%dg)" % [UNIT_NAMES[type_name], HIRE_COSTS[type_name]]
		name_lbl.custom_minimum_size = Vector2(180, 0)
		name_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(name_lbl)

		var dismiss_btn := Button.new()
		dismiss_btn.text = "-"
		dismiss_btn.custom_minimum_size = Vector2(28, 28)
		dismiss_btn.focus_mode = Control.FOCUS_NONE
		dismiss_btn.pressed.connect(_on_recruit_adjust.bind(type_name, -1))
		row.add_child(dismiss_btn)

		var count_lbl := Label.new()
		count_lbl.text = "0"
		count_lbl.custom_minimum_size = Vector2(30, 0)
		count_lbl.add_theme_font_size_override("font_size", 14)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(count_lbl)

		var hire_btn := Button.new()
		hire_btn.text = "+"
		hire_btn.custom_minimum_size = Vector2(28, 28)
		hire_btn.focus_mode = Control.FOCUS_NONE
		hire_btn.pressed.connect(_on_recruit_adjust.bind(type_name, 1))
		row.add_child(hire_btn)

		var p5_btn := Button.new()
		p5_btn.text = "+5"
		p5_btn.custom_minimum_size = Vector2(34, 28)
		p5_btn.add_theme_font_size_override("font_size", 12)
		p5_btn.focus_mode = Control.FOCUS_NONE
		p5_btn.pressed.connect(_on_recruit_adjust.bind(type_name, 5))
		row.add_child(p5_btn)

		var p10_btn := Button.new()
		p10_btn.text = "+10"
		p10_btn.custom_minimum_size = Vector2(38, 28)
		p10_btn.add_theme_font_size_override("font_size", 12)
		p10_btn.focus_mode = Control.FOCUS_NONE
		p10_btn.pressed.connect(_on_recruit_adjust.bind(type_name, 10))
		row.add_child(p10_btn)

		var all_btn := Button.new()
		all_btn.text = "ALL"
		all_btn.custom_minimum_size = Vector2(38, 28)
		all_btn.add_theme_font_size_override("font_size", 12)
		all_btn.focus_mode = Control.FOCUS_NONE
		all_btn.pressed.connect(_on_recruit_max.bind(type_name))
		row.add_child(all_btn)

		_recruit_rows[type_name] = {"count_label": count_lbl}

func _refresh_recruit_tab() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.save_data:
		return
	var gold: int = gm.save_data.gold
	_gold_label.text = "Gold: %d" % gold

	var hired := _get_hired()
	var total := 0
	for type_name in UNIT_ORDER:
		var count: int = int(hired.get(type_name, 0))
		total += count
		_recruit_rows[type_name]["count_label"].text = str(count)
	_recruit_total_label.text = "Hired: %d / %d" % [total, MAX_HIRED]

func _on_recruit_adjust(type_name: String, delta: int) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.save_data:
		return

	var hired := _get_hired()
	var current: int = int(hired.get(type_name, 0))
	var cost: int = HIRE_COSTS[type_name]
	var bought := 0

	if delta > 0:
		var total := 0
		for tn in hired:
			total += int(hired[tn])
		for _i in delta:
			if total >= MAX_HIRED:
				break
			if gm.save_data.gold < cost:
				break
			gm.save_data.gold -= cost
			current += 1
			total += 1
			bought += 1
		if bought == 0:
			return
		hired[type_name] = current
	else:
		var to_dismiss := mini(current, absi(delta))
		if to_dismiss <= 0:
			return
		hired[type_name] = current - to_dismiss
		gm.save_data.gold += (cost / 2) * to_dismiss

	if not gm.save_data.army_state.has("hired_fighters"):
		gm.save_data.army_state["hired_fighters"] = {}
	gm.save_data.army_state["hired_fighters"] = hired

	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click", -5.0)
	_refresh_recruit_tab()

func _on_recruit_max(type_name: String) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.save_data:
		return

	var hired := _get_hired()
	var current: int = int(hired.get(type_name, 0))
	var cost: int = HIRE_COSTS[type_name]
	var total := 0
	for tn in hired:
		total += int(hired[tn])
	var bought := 0
	while total < MAX_HIRED and gm.save_data.gold >= cost:
		gm.save_data.gold -= cost
		current += 1
		total += 1
		bought += 1
	if bought == 0:
		return
	hired[type_name] = current

	if not gm.save_data.army_state.has("hired_fighters"):
		gm.save_data.army_state["hired_fighters"] = {}
	gm.save_data.army_state["hired_fighters"] = hired

	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click", -5.0)
	_refresh_recruit_tab()

# ==================== UPGRADES TAB ====================

const UPGRADE_COSTS := [5, 10, 20, 35, 50]  # Cost for levels 1→5
const UPGRADE_TYPES := ["atk", "def", "hp"]
const UPGRADE_LABELS := {"atk": "ATK (+12%/lvl)", "def": "DEF (+15%/lvl)", "hp": "HP (+15%/lvl)"}
const MAX_UPGRADE_LEVEL := 5

func _build_upgrades_tab() -> void:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 4)
	_tab_container.add_child(page)
	_tab_pages.append(page)

	_tokens_label = Label.new()
	_tokens_label.add_theme_font_size_override("font_size", 16)
	_tokens_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	page.add_child(_tokens_label)

	var desc := Label.new()
	desc.text = "Spend Troop Tokens to upgrade unit types."
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	page.add_child(desc)

	var sep := HSeparator.new()
	page.add_child(sep)

	# Scrollable area for upgrade rows
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 350)
	page.add_child(scroll)

	var scroll_vbox := VBoxContainer.new()
	scroll_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(scroll_vbox)

	for type_name in UNIT_ORDER:
		# Unit type header
		var header := Label.new()
		header.text = UNIT_NAMES[type_name]
		header.add_theme_font_size_override("font_size", 15)
		header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
		scroll_vbox.add_child(header)

		_upgrade_rows[type_name] = {}

		for stat in UPGRADE_TYPES:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			scroll_vbox.add_child(row)

			var stat_lbl := Label.new()
			stat_lbl.text = "  " + UPGRADE_LABELS[stat]
			stat_lbl.custom_minimum_size = Vector2(160, 0)
			stat_lbl.add_theme_font_size_override("font_size", 13)
			row.add_child(stat_lbl)

			var level_lbl := Label.new()
			level_lbl.text = "Lv 0"
			level_lbl.custom_minimum_size = Vector2(50, 0)
			level_lbl.add_theme_font_size_override("font_size", 13)
			level_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			row.add_child(level_lbl)

			var cost_lbl := Label.new()
			cost_lbl.text = ""
			cost_lbl.custom_minimum_size = Vector2(60, 0)
			cost_lbl.add_theme_font_size_override("font_size", 12)
			cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			row.add_child(cost_lbl)

			var upgrade_btn := Button.new()
			upgrade_btn.text = "Upgrade"
			upgrade_btn.custom_minimum_size = Vector2(70, 26)
			upgrade_btn.add_theme_font_size_override("font_size", 12)
			upgrade_btn.focus_mode = Control.FOCUS_NONE
			upgrade_btn.pressed.connect(_on_upgrade.bind(type_name, stat))
			row.add_child(upgrade_btn)

			_upgrade_rows[type_name][stat] = {
				"level_label": level_lbl,
				"cost_label": cost_lbl,
				"button": upgrade_btn,
			}

		# Small spacer between unit types
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 2)
		scroll_vbox.add_child(spacer)

func _refresh_upgrades_tab() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.save_data:
		return
	var tokens: int = gm.save_data.troop_tokens
	_tokens_label.text = "Troop Tokens: %d" % tokens

	var upgrades: Dictionary = gm.save_data.army_state.get("unit_upgrades", {})

	for type_name in UNIT_ORDER:
		for stat in UPGRADE_TYPES:
			var key: String = type_name + "_" + stat
			var level: int = upgrades.get(key, 0)
			var widgets: Dictionary = _upgrade_rows[type_name][stat]
			widgets["level_label"].text = "Lv %d" % level
			if level >= MAX_UPGRADE_LEVEL:
				widgets["cost_label"].text = "MAX"
				widgets["button"].disabled = true
			else:
				var cost: int = UPGRADE_COSTS[level]
				widgets["cost_label"].text = "(%d)" % cost
				widgets["button"].disabled = tokens < cost

func _on_upgrade(type_name: String, stat: String) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.save_data:
		return

	if not gm.save_data.army_state.has("unit_upgrades"):
		gm.save_data.army_state["unit_upgrades"] = {}
	var upgrades: Dictionary = gm.save_data.army_state["unit_upgrades"]
	var key := type_name + "_" + stat
	var level: int = upgrades.get(key, 0)
	if level >= MAX_UPGRADE_LEVEL:
		return
	var cost: int = UPGRADE_COSTS[level]
	if gm.save_data.troop_tokens < cost:
		return

	gm.save_data.troop_tokens -= cost
	upgrades[key] = level + 1
	gm.save_data.army_state["unit_upgrades"] = upgrades

	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("level_up", -3.0)
	_refresh_upgrades_tab()

# ==================== HELPERS ====================

func _get_hired() -> Dictionary:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.save_data and gm.save_data.army_state.has("hired_fighters"):
		return gm.save_data.army_state["hired_fighters"]
	return {}

func _get_divisions() -> Array:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.save_data:
		return gm.save_data.army_divisions
	return []
