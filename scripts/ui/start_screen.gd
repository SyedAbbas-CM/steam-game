class_name StartScreen
extends Control

var _selected_class: String = "warrior"
var _class_buttons: Dictionary = {}  # class_id -> Button

const CLASS_DATA = {
	"warrior": {
		"name": "Warrior",
		"desc": "Sturdy fighter with sword + shield block.\nShift = raise shield, Space = dash.",
		"color": Color(1.0, 0.85, 0.6),
		"hp": 50, "spd": 30, "dmg": "1.5x"
	},
	"mercenary": {
		"name": "Mercenary",
		"desc": "Versatile blade & bow fighter.\nShift = swap sword / short bow.",
		"color": Color(1.0, 0.7, 0.5),
		"hp": 45, "spd": 35, "dmg": "1.2x"
	},
	"ranger": {
		"name": "Ranger",
		"desc": "Swift bow + dagger, distance scaling.\nShift = swap bow / dagger (high crit).",
		"color": Color(0.7, 1.0, 0.7),
		"hp": 40, "spd": 40, "dmg": "1.0x"
	},
	"wizard": {
		"name": "Wizard",
		"desc": "Glass cannon with staff + charged blast.\nSpace = charge blast, high magic.",
		"color": Color(0.7, 0.7, 1.0),
		"hp": 30, "spd": 35, "dmg": "2.0x"
	},
}

func _ready() -> void:
	# Restore last selected class
	if GameManager and GameManager.save_data:
		_selected_class = GameManager.save_data.selected_class
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.08)
	add_child(bg)

	# Center container
	var center = VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("separation", 20)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center)

	# Game title
	var title = Label.new()
	title.text = "DUNGEON CRAWL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_settings = LabelSettings.new()
	title_settings.font_size = 72
	title_settings.font_color = Color(0.9, 0.8, 0.3)
	title_settings.outline_size = 4
	title_settings.outline_color = Color(0.3, 0.2, 0.0)
	title.label_settings = title_settings
	center.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "A Roguelike Adventure"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub_settings = LabelSettings.new()
	sub_settings.font_size = 28
	sub_settings.font_color = Color(0.6, 0.6, 0.7)
	subtitle.label_settings = sub_settings
	center.add_child(subtitle)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	center.add_child(spacer)

	# Class label
	var class_label = Label.new()
	class_label.text = "CHOOSE YOUR CLASS"
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cl_settings = LabelSettings.new()
	cl_settings.font_size = 24
	cl_settings.font_color = Color(0.8, 0.75, 0.6)
	class_label.label_settings = cl_settings
	center.add_child(class_label)

	# Class buttons in a horizontal row
	var class_row = HBoxContainer.new()
	class_row.alignment = BoxContainer.ALIGNMENT_CENTER
	class_row.add_theme_constant_override("separation", 16)
	class_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(class_row)

	for class_id in CLASS_DATA:
		var btn_vbox = _create_class_button(class_id, CLASS_DATA[class_id])
		class_row.add_child(btn_vbox)

	_update_class_selection()

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	center.add_child(spacer2)

	# Start button
	var start_btn = Button.new()
	start_btn.text = "Start Game"
	start_btn.custom_minimum_size = Vector2(300, 70)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.add_theme_font_size_override("font_size", 32)
	start_btn.pressed.connect(_on_start)
	center.add_child(start_btn)

	# Stats display
	if GameManager and GameManager.save_data:
		var spacer3 = Control.new()
		spacer3.custom_minimum_size = Vector2(0, 20)
		center.add_child(spacer3)

		var stats = Label.new()
		var sd = GameManager.save_data
		stats.text = "Runs: " + str(sd.total_runs) + "  |  Best Floor: " + str(sd.best_floor) + "  |  Gold: " + str(sd.gold)
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var stats_settings = LabelSettings.new()
		stats_settings.font_size = 22
		stats_settings.font_color = Color(0.5, 0.5, 0.5)
		stats.label_settings = stats_settings
		center.add_child(stats)

func _create_class_button(class_id: String, data: Dictionary) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(200, 120)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_class_selected.bind(class_id))

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.12, 0.12, 0.2)
	hover_style.border_color = data["color"].darkened(0.2)
	btn.add_theme_stylebox_override("hover", hover_style)

	# Button content
	var content = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 6)

	var name_lbl = Label.new()
	name_lbl.text = data["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", data["color"])
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = data["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(desc_lbl)

	var stats_lbl = Label.new()
	stats_lbl.text = "Health:%d  Move:%d  Attack:%s" % [data["hp"], data["spd"], data["dmg"]]
	stats_lbl.add_theme_font_size_override("font_size", 13)
	stats_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(stats_lbl)

	btn.add_child(content)
	vbox.add_child(btn)
	_class_buttons[class_id] = btn
	return vbox

func _on_class_selected(class_id: String) -> void:
	_selected_class = class_id
	_update_class_selection()
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("select_a", -4.0, 0.0)

func _update_class_selection() -> void:
	for class_id in _class_buttons:
		var btn = _class_buttons[class_id] as Button
		var style = btn.get_theme_stylebox("normal") as StyleBoxFlat
		if not style:
			continue
		if class_id == _selected_class:
			var data = CLASS_DATA[class_id]
			style.bg_color = data["color"].darkened(0.7)
			style.border_color = data["color"]
			style.set_border_width_all(3)
		else:
			style.bg_color = Color(0.08, 0.08, 0.14)
			style.border_color = Color(0.3, 0.3, 0.4)
			style.set_border_width_all(2)

func _on_start() -> void:
	# Store class selection
	if GameManager:
		GameManager.selected_class = _selected_class
		if GameManager.save_data:
			GameManager.save_data.selected_class = _selected_class
			GameManager.save_data.save_game()

	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("select_a", -2.0, 0.0)
	# Show loading feedback
	var loading = Label.new()
	loading.text = "Loading world..."
	loading.set_anchors_preset(Control.PRESET_CENTER)
	loading.add_theme_font_size_override("font_size", 24)
	loading.add_theme_color_override("font_color", Color.WHITE)
	add_child(loading)
	await get_tree().process_frame
	await get_tree().process_frame
	if GameManager:
		# First-time chars run the tutorial dungeon once. Repeat saves skip it.
		if GameManager.save_data and not GameManager.save_data.tutorial_completed:
			GameManager.start_tutorial()
		else:
			GameManager.return_to_overworld()
	else:
		get_tree().change_scene_to_file("res://scenes/overworld/overworld.scn")
