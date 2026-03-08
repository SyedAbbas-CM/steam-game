class_name StartScreen
extends Control

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.color = Color(0.03, 0.03, 0.08)
	add_child(bg)

	var center = VBoxContainer.new()
	center.anchors_preset = Control.PRESET_CENTER
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.custom_minimum_size = Vector2(600, 0)
	center.add_theme_constant_override("separation", 30)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	bg.add_child(center)

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
	spacer.custom_minimum_size = Vector2(0, 60)
	center.add_child(spacer)

	# Start button
	var start_btn = Button.new()
	start_btn.text = "Start Game"
	start_btn.custom_minimum_size = Vector2(300, 70)
	start_btn.add_theme_font_size_override("font_size", 32)
	start_btn.pressed.connect(_on_start)
	center.add_child(start_btn)

	# Stats display
	if GameManager and GameManager.save_data:
		var spacer2 = Control.new()
		spacer2.custom_minimum_size = Vector2(0, 40)
		center.add_child(spacer2)

		var stats = Label.new()
		var sd = GameManager.save_data
		stats.text = "Runs: " + str(sd.total_runs) + "  |  Best Floor: " + str(sd.best_floor) + "  |  Gold: " + str(sd.gold)
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var stats_settings = LabelSettings.new()
		stats_settings.font_size = 22
		stats_settings.font_color = Color(0.5, 0.5, 0.5)
		stats.label_settings = stats_settings
		center.add_child(stats)

func _on_start() -> void:
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
		GameManager.return_to_overworld()
	else:
		get_tree().change_scene_to_file("res://scenes/overworld/overworld.scn")
