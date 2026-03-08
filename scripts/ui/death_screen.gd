class_name DeathScreen
extends CanvasLayer

signal continue_pressed

var title_label: Label
var stats_label: Label
var return_btn: Button
var retry_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()

func _build_ui() -> void:
	# Full screen dark overlay
	var overlay = ColorRect.new()
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.color = Color(0.02, 0.02, 0.05, 0.92)
	add_child(overlay)

	var center = VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.add_theme_constant_override("separation", 6)
	overlay.add_child(center)

	# Death title
	title_label = Label.new()
	title_label.text = "YOU DIED"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_settings = LabelSettings.new()
	title_settings.font_size = 16
	title_settings.font_color = Color(0.9, 0.15, 0.15)
	title_label.label_settings = title_settings
	center.add_child(title_label)

	# Separator
	var sep = HSeparator.new()
	sep.custom_minimum_size = Vector2(180, 4)
	center.add_child(sep)

	# Stats
	stats_label = Label.new()
	stats_label.text = ""
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stat_settings = LabelSettings.new()
	stat_settings.font_size = 8
	stat_settings.font_color = Color(0.8, 0.8, 0.8)
	stats_label.label_settings = stat_settings
	center.add_child(stats_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	center.add_child(spacer)

	# Buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(btn_hbox)

	return_btn = Button.new()
	return_btn.text = "Return to Town"
	return_btn.custom_minimum_size = Vector2(90, 22)
	return_btn.add_theme_font_size_override("font_size", 8)
	return_btn.pressed.connect(_on_return)
	btn_hbox.add_child(return_btn)

	retry_btn = Button.new()
	retry_btn.text = "Try Again"
	retry_btn.custom_minimum_size = Vector2(90, 22)
	retry_btn.add_theme_font_size_override("font_size", 8)
	retry_btn.pressed.connect(_on_retry)
	btn_hbox.add_child(retry_btn)

func show_death(run_state: RunState) -> void:
	get_tree().paused = true
	visible = true

	var text = ""
	text += "Floor Reached: " + str(run_state.current_floor) + "\n"
	text += "Rooms Cleared: " + str(run_state.rooms_cleared) + "\n"
	text += "Enemies Killed: " + str(run_state.enemies_killed) + "\n"
	text += "Gold Earned: " + str(run_state.run_gold) + "\n"
	text += "Relics: " + str(run_state.run_relics) + "\n"
	text += "Time: " + str(int(run_state.get_duration_seconds())) + "s"
	stats_label.text = text

func _on_return() -> void:
	visible = false
	get_tree().paused = false
	continue_pressed.emit()

func _on_retry() -> void:
	visible = false
	get_tree().paused = false
	get_tree().reload_current_scene()
