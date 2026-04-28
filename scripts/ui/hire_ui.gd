class_name HireUI
extends CanvasLayer

## UI for hiring fighters from town elders.
## Shows unit types with gold costs. Hired fighters join your army in battles.

signal closed

const MAX_HIRED := 50
const HIRE_COSTS := {
	"infantry": 50,
	"archer": 80,
	"heavy_infantry": 100,
	"cavalry": 120,
	"mage": 150,
	"heavy_cavalry": 200,
}
const UNIT_NAMES := {
	"infantry": "Infantry",
	"archer": "Archer",
	"heavy_infantry": "Heavy Infantry",
	"cavalry": "Cavalry",
	"mage": "Mage",
	"heavy_cavalry": "Heavy Cavalry",
}

var _panel: PanelContainer
var _rows: Dictionary = {}  # unit_type_name -> {count_label, hire_btn, dismiss_btn}
var _gold_label: Label
var _total_label: Label
var _army_label: Label
var _close_btn: Button

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Panel
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(480, 520)
	_panel.position = Vector2(720, 230)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.14, 0.95)
	style.border_color = Color(0.5, 0.4, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "HIRE FIGHTERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_settings := LabelSettings.new()
	title_settings.font_size = 24
	title_settings.font_color = Color(0.9, 0.8, 0.5)
	title_settings.outline_size = 2
	title_settings.outline_color = Color(0, 0, 0)
	title.label_settings = title_settings
	vbox.add_child(title)

	# Gold display
	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gold_settings := LabelSettings.new()
	gold_settings.font_size = 16
	gold_settings.font_color = Color(1.0, 0.85, 0.3)
	_gold_label.label_settings = gold_settings
	vbox.add_child(_gold_label)

	# Total hired count
	_total_label = Label.new()
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var total_settings := LabelSettings.new()
	total_settings.font_size = 14
	total_settings.font_color = Color(0.7, 0.7, 0.8)
	_total_label.label_settings = total_settings
	vbox.add_child(_total_label)

	# Separator
	vbox.add_child(HSeparator.new())

	# Column headers
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var h_name := Label.new()
	h_name.text = "Unit"
	h_name.custom_minimum_size = Vector2(120, 0)
	h_name.add_theme_font_size_override("font_size", 12)
	h_name.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	header.add_child(h_name)
	var h_cost := Label.new()
	h_cost.text = "Cost"
	h_cost.custom_minimum_size = Vector2(70, 0)
	h_cost.add_theme_font_size_override("font_size", 12)
	h_cost.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	header.add_child(h_cost)
	var h_count := Label.new()
	h_count.text = "Hired"
	h_count.custom_minimum_size = Vector2(50, 0)
	h_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_count.add_theme_font_size_override("font_size", 12)
	h_count.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	header.add_child(h_count)
	vbox.add_child(header)

	# Unit rows
	for type_name in ["infantry", "archer", "heavy_infantry", "cavalry", "mage", "heavy_cavalry"]:
		var row = _create_hire_row(type_name)
		vbox.add_child(row)

	# Separator
	vbox.add_child(HSeparator.new())

	# Army summary
	_army_label = Label.new()
	_army_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_army_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	var army_settings := LabelSettings.new()
	army_settings.font_size = 13
	army_settings.font_color = Color(0.6, 0.8, 0.6)
	_army_label.label_settings = army_settings
	vbox.add_child(_army_label)

	# Close button
	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.focus_mode = Control.FOCUS_NONE
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.3, 0.25, 0.2, 0.9)
	close_style.border_color = Color(0.5, 0.4, 0.3)
	close_style.set_border_width_all(1)
	close_style.set_corner_radius_all(4)
	_close_btn.add_theme_stylebox_override("normal", close_style)
	_close_btn.add_theme_font_size_override("font_size", 16)
	_close_btn.pressed.connect(_on_close)
	vbox.add_child(_close_btn)

	_refresh()

func _create_hire_row(type_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = UNIT_NAMES[type_name]
	name_label.custom_minimum_size = Vector2(120, 0)
	var name_settings := LabelSettings.new()
	name_settings.font_size = 16
	name_settings.font_color = Color(0.85, 0.82, 0.78)
	name_label.label_settings = name_settings
	row.add_child(name_label)

	var cost_label := Label.new()
	cost_label.text = "%d g" % HIRE_COSTS[type_name]
	cost_label.custom_minimum_size = Vector2(70, 0)
	var cost_settings := LabelSettings.new()
	cost_settings.font_size = 14
	cost_settings.font_color = Color(1.0, 0.85, 0.3)
	cost_label.label_settings = cost_settings
	row.add_child(cost_label)

	var count_label := Label.new()
	count_label.text = "x0"
	count_label.custom_minimum_size = Vector2(50, 0)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var count_settings := LabelSettings.new()
	count_settings.font_size = 16
	count_settings.font_color = Color(0.5, 1.0, 0.5)
	count_label.label_settings = count_settings
	row.add_child(count_label)

	# Dismiss button (-)
	var dismiss_btn := Button.new()
	dismiss_btn.text = "-"
	dismiss_btn.focus_mode = Control.FOCUS_NONE
	dismiss_btn.custom_minimum_size = Vector2(36, 32)
	var dim_style := StyleBoxFlat.new()
	dim_style.bg_color = Color(0.5, 0.2, 0.2, 0.9)
	dim_style.border_color = Color(0.7, 0.3, 0.3)
	dim_style.set_border_width_all(1)
	dim_style.set_corner_radius_all(4)
	dismiss_btn.add_theme_stylebox_override("normal", dim_style)
	var dim_hover := dim_style.duplicate() as StyleBoxFlat
	dim_hover.bg_color = Color(0.6, 0.3, 0.3, 0.95)
	dismiss_btn.add_theme_stylebox_override("hover", dim_hover)
	dismiss_btn.add_theme_font_size_override("font_size", 16)
	dismiss_btn.pressed.connect(_on_dismiss.bind(type_name))
	row.add_child(dismiss_btn)

	# Hire button (+)
	var hire_btn := Button.new()
	hire_btn.text = "+"
	hire_btn.focus_mode = Control.FOCUS_NONE
	hire_btn.custom_minimum_size = Vector2(36, 32)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.5, 0.2, 0.9)
	btn_style.border_color = Color(0.3, 0.7, 0.3)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	hire_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.3, 0.6, 0.3, 0.95)
	hire_btn.add_theme_stylebox_override("hover", btn_hover)
	hire_btn.add_theme_font_size_override("font_size", 16)
	hire_btn.pressed.connect(_on_hire.bind(type_name))
	row.add_child(hire_btn)

	_rows[type_name] = {"count_label": count_label, "hire_btn": hire_btn, "dismiss_btn": dismiss_btn}
	return row

func _get_hired_fighters() -> Dictionary:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.save_data:
		if not gm.save_data.army_state.has("hired_fighters"):
			gm.save_data.army_state["hired_fighters"] = {}
		return gm.save_data.army_state["hired_fighters"]
	return {}

func _get_total_hired() -> int:
	var hired = _get_hired_fighters()
	var total := 0
	for type_name in hired:
		total += int(hired[type_name])
	return total

func _refresh() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var gold := 0
	var player_level := 1
	if gm:
		gold = gm.get_gold()
		if gm.save_data:
			player_level = gm.save_data.player_level
	_gold_label.text = "Gold: %d" % gold

	var total := _get_total_hired()
	_total_label.text = "Hired: %d / %d" % [total, MAX_HIRED]
	var hired = _get_hired_fighters()

	for type_name in _rows:
		var count: int = int(hired.get(type_name, 0))
		_rows[type_name]["count_label"].text = "x%d" % count
		var can_afford: bool = gold >= int(HIRE_COSTS[type_name])
		var can_hire: bool = total < MAX_HIRED and can_afford
		_rows[type_name]["hire_btn"].disabled = not can_hire
		_rows[type_name]["dismiss_btn"].disabled = count <= 0

	# Army summary
	var militia := maxi(30, player_level * 5 + 15)
	_army_label.text = "Battle Army: %d militia + %d hired = %d total" % [militia, total, militia + total]

func _on_hire(type_name: String) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return
	var cost: int = HIRE_COSTS[type_name]
	if not gm.spend_gold(cost):
		return
	var hired := _get_hired_fighters()
	hired[type_name] = int(hired.get(type_name, 0)) + 1
	if gm.save_data:
		gm.save_data.army_state["hired_fighters"] = hired
		gm.save_data.save_to_slot()
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("buy", -4.0)
	_refresh()

func _on_dismiss(type_name: String) -> void:
	var hired := _get_hired_fighters()
	var count: int = int(hired.get(type_name, 0))
	if count <= 0:
		return
	hired[type_name] = count - 1
	# Refund 50%
	var refund: int = int(HIRE_COSTS[type_name] * 0.5)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.add_gold(refund)
		if gm.save_data:
			gm.save_data.army_state["hired_fighters"] = hired
			gm.save_data.save_to_slot()
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("sell", -4.0)
	_refresh()

func _on_close() -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("close", -5.0)
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()
