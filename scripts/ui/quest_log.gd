class_name QuestLog
extends CanvasLayer

## Quest log overlay — shows active and completed quests

var _panel: PanelContainer
var _title: Label
var _scroll: ScrollContainer
var _quest_list: VBoxContainer
var _close_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()

func _build_ui() -> void:
	var dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.6)
	dimmer.anchors_preset = Control.PRESET_FULL_RECT
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	_panel = PanelContainer.new()
	_panel.anchors_preset = Control.PRESET_CENTER
	_panel.offset_left = -200
	_panel.offset_right = 200
	_panel.offset_top = -150
	_panel.offset_bottom = 150
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.6, 0.5, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	var header = HBoxContainer.new()
	vbox.add_child(header)

	_title = Label.new()
	_title.text = "Quest Log"
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)

	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.pressed.connect(toggle)
	header.add_child(_close_btn)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll)

	_quest_list = VBoxContainer.new()
	_quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_quest_list)

func toggle() -> void:
	visible = !visible
	get_tree().paused = visible
	if visible:
		_refresh()

func _refresh() -> void:
	for child in _quest_list.get_children():
		child.queue_free()

	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		return

	# Active quests
	var has_active = false
	for quest_id in qm.active_quests:
		if not qm.active_quests[quest_id].get("active", false):
			continue
		has_active = true
		var quest = qm.definitions.get(quest_id) as QuestDefinition
		if not quest:
			continue
		_add_quest_entry(quest, qm, true)

	if not has_active:
		var empty = Label.new()
		empty.text = "No active quests"
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_quest_list.add_child(empty)

	# Separator
	var sep = HSeparator.new()
	_quest_list.add_child(sep)

	# Completed quests header
	var completed_header = Label.new()
	completed_header.text = "Completed (" + str(qm.completed_quests.size()) + ")"
	completed_header.add_theme_font_size_override("font_size", 14)
	completed_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_quest_list.add_child(completed_header)

	for quest_id in qm.completed_quests:
		var quest = qm.definitions.get(quest_id) as QuestDefinition
		if quest:
			_add_quest_entry(quest, qm, false)

func _add_quest_entry(quest: QuestDefinition, qm, active: bool) -> void:
	var entry = VBoxContainer.new()
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.15, 0.2) if active else Color(0.1, 0.1, 0.12)
	bg.set_corner_radius_all(2)
	bg.content_margin_left = 6
	bg.content_margin_right = 6
	bg.content_margin_top = 4
	bg.content_margin_bottom = 4

	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", bg)
	_quest_list.add_child(panel)
	panel.add_child(entry)

	var title = Label.new()
	title.text = quest.title + " (Lv." + str(quest.level) + ")"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5) if active else Color(0.5, 0.5, 0.5))
	entry.add_child(title)

	var summary = Label.new()
	summary.text = quest.summary
	summary.add_theme_font_size_override("font_size", 11)
	summary.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8) if active else Color(0.4, 0.4, 0.4))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD
	entry.add_child(summary)

	# Show progress for active quests
	if active:
		for prop in quest.properties:
			var idx = int(prop.get("index", 0))
			var val = qm.get_quest_value(quest.id, idx)
			var progress = Label.new()
			progress.text = "  " + str(prop.get("name", "Progress")) + ": " + str(val)
			progress.add_theme_font_size_override("font_size", 10)
			progress.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			entry.add_child(progress)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("quest_log"):
		toggle()
		get_viewport().set_input_as_handled()
