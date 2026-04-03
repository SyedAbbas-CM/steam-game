class_name QuestLog
extends CanvasLayer

## Quest log overlay — Skyrim-style quest journal with detail panel

var _panel: PanelContainer
var _title: Label
var _close_btn: Button
var _quest_list_scroll: ScrollContainer
var _quest_list: VBoxContainer
var _detail_scroll: ScrollContainer
var _detail_panel: VBoxContainer
var _selected_quest_id: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()

func _build_ui() -> void:
	var dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.7)
	dimmer.anchors_preset = Control.PRESET_FULL_RECT
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.08
	_panel.anchor_right = 0.92
	_panel.anchor_top = 0.05
	_panel.anchor_bottom = 0.95
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.97)
	style.border_color = Color(0.6, 0.5, 0.3)
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(main_vbox)

	# Header
	var header = HBoxContainer.new()
	main_vbox.add_child(header)

	_title = Label.new()
	_title.text = "QUEST LOG"
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)

	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.add_theme_font_size_override("font_size", 20)
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.pressed.connect(toggle)
	header.add_child(_close_btn)

	# Split: quest list on left, detail on right
	var split = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = -400
	main_vbox.add_child(split)

	# Left panel — quest list
	var left_panel = PanelContainer.new()
	var left_style = StyleBoxFlat.new()
	left_style.bg_color = Color(0.1, 0.1, 0.14, 0.8)
	left_style.set_corner_radius_all(4)
	left_style.content_margin_left = 8
	left_style.content_margin_right = 8
	left_style.content_margin_top = 8
	left_style.content_margin_bottom = 8
	left_panel.add_theme_stylebox_override("panel", left_style)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.custom_minimum_size = Vector2(300, 0)
	split.add_child(left_panel)

	_quest_list_scroll = ScrollContainer.new()
	_quest_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quest_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_child(_quest_list_scroll)

	_quest_list = VBoxContainer.new()
	_quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_list.add_theme_constant_override("separation", 4)
	_quest_list_scroll.add_child(_quest_list)

	# Right panel — detail view
	var right_panel = PanelContainer.new()
	var right_style = StyleBoxFlat.new()
	right_style.bg_color = Color(0.12, 0.11, 0.16, 0.8)
	right_style.set_corner_radius_all(4)
	right_style.content_margin_left = 16
	right_style.content_margin_right = 16
	right_style.content_margin_top = 12
	right_style.content_margin_bottom = 12
	right_panel.add_theme_stylebox_override("panel", right_style)
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.custom_minimum_size = Vector2(500, 0)
	split.add_child(right_panel)

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_child(_detail_scroll)

	_detail_panel = VBoxContainer.new()
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.add_theme_constant_override("separation", 10)
	_detail_scroll.add_child(_detail_panel)

func toggle() -> void:
	visible = !visible
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("paper" if visible else "close", -4.0, 0.0)
	if visible:
		_refresh()

func _refresh() -> void:
	for child in _quest_list.get_children():
		child.queue_free()

	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		return

	# Section: Active Quests
	_add_section_header("ACTIVE QUESTS", Color(1.0, 0.85, 0.4))

	var has_active = false
	var first_active_id = ""
	for quest_id in qm.active_quests:
		if not qm.active_quests[quest_id].get("active", false):
			continue
		has_active = true
		var quest = qm.definitions.get(quest_id) as QuestDefinition
		if not quest:
			continue
		if first_active_id == "":
			first_active_id = quest_id
		_add_quest_list_item(quest, qm, true)

	if not has_active:
		var empty = Label.new()
		empty.text = "  No active quests. Talk to NPCs to find work."
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD
		_quest_list.add_child(empty)

	# Section: Completed Quests
	if qm.completed_quests.size() > 0:
		_add_section_header("COMPLETED (%d)" % qm.completed_quests.size(), Color(0.5, 0.5, 0.5))
		for quest_id in qm.completed_quests:
			var quest = qm.definitions.get(quest_id) as QuestDefinition
			if quest:
				_add_quest_list_item(quest, qm, false)

	# Auto-select first active quest
	if first_active_id != "":
		_show_detail(first_active_id)
	elif _selected_quest_id != "":
		_show_detail(_selected_quest_id)
	else:
		_show_empty_detail()

func _add_section_header(text: String, color: Color) -> void:
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	_quest_list.add_child(sep)

	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", color)
	_quest_list.add_child(lbl)

func _add_quest_list_item(quest: QuestDefinition, qm, active: bool) -> void:
	var btn = Button.new()
	btn.text = quest.title + "  (Lv." + str(quest.level) + ")"
	btn.add_theme_font_size_override("font_size", 18)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 40)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.14, 0.2, 0.6) if active else Color(0.1, 0.1, 0.12, 0.4)
	btn_style.set_corner_radius_all(3)
	btn_style.content_margin_left = 12
	btn_style.content_margin_top = 4
	btn_style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", btn_style)

	var hover_style = btn_style.duplicate()
	hover_style.bg_color = Color(0.2, 0.18, 0.28, 0.8)
	hover_style.border_color = Color(0.6, 0.5, 0.3)
	hover_style.set_border_width_all(1)
	btn.add_theme_stylebox_override("hover", hover_style)

	if active:
		btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.7))
		# Show progress indicator inline
		for prop in quest.properties:
			var idx = int(prop.get("index", 0))
			var val = qm.get_quest_value(quest.id, idx)
			var target = _get_target_for_quest(quest)
			if target > 0:
				btn.text += "  [%d/%d]" % [val, target]
			elif val > 0:
				btn.text += "  [%d]" % val
	else:
		btn.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
		btn.add_theme_color_override("font_hover_color", Color(0.6, 0.6, 0.6))

	btn.pressed.connect(_show_detail.bind(quest.id))
	_quest_list.add_child(btn)

func _show_detail(quest_id: String) -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("blip", -8.0, 0.0)
	_selected_quest_id = quest_id
	for child in _detail_panel.get_children():
		child.queue_free()

	var qm = get_node_or_null("/root/QuestManager")
	if not qm or not qm.definitions.has(quest_id):
		_show_empty_detail()
		return

	var quest = qm.definitions[quest_id] as QuestDefinition
	var active = qm.is_quest_active(quest_id)
	var completed = qm.is_quest_completed(quest_id)

	# Quest title
	var title = Label.new()
	title.text = quest.title
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if active else Color(0.6, 0.6, 0.6))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_panel.add_child(title)

	# Level + Location
	var meta_line = Label.new()
	var location_name = _zone_display_name(quest.location)
	var status_text = "ACTIVE" if active else ("COMPLETED" if completed else "AVAILABLE")
	var status_color = Color(0.4, 1.0, 0.4) if active else (Color(0.6, 0.6, 0.6) if completed else Color(0.8, 0.8, 0.5))
	meta_line.text = "Level %d  |  %s  |  %s" % [quest.level, location_name, status_text]
	meta_line.add_theme_font_size_override("font_size", 16)
	meta_line.add_theme_color_override("font_color", status_color)
	_detail_panel.add_child(meta_line)

	# Separator
	var sep1 = HSeparator.new()
	_detail_panel.add_child(sep1)

	# Description / Journal entry
	var desc_header = Label.new()
	desc_header.text = "JOURNAL"
	desc_header.add_theme_font_size_override("font_size", 16)
	desc_header.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	_detail_panel.add_child(desc_header)

	var desc = Label.new()
	desc.text = _get_journal_text(quest, qm, active, completed)
	desc.add_theme_font_size_override("font_size", 18)
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(desc)

	# Objectives
	if active:
		var sep2 = HSeparator.new()
		_detail_panel.add_child(sep2)

		var obj_header = Label.new()
		obj_header.text = "OBJECTIVES"
		obj_header.add_theme_font_size_override("font_size", 16)
		obj_header.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
		_detail_panel.add_child(obj_header)

		for prop in quest.properties:
			var idx = int(prop.get("index", 0))
			var val = qm.get_quest_value(quest.id, idx)
			var prop_name = str(prop.get("name", "Progress"))
			var target = _get_target_for_quest(quest)

			var obj_line = HBoxContainer.new()
			_detail_panel.add_child(obj_line)

			# Checkbox
			var check = Label.new()
			var is_done = (target > 0 and val >= target) or (prop.get("type") == "yesno" and val > 0)
			check.text = "[X] " if is_done else "[ ] "
			check.add_theme_font_size_override("font_size", 18)
			check.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4) if is_done else Color(0.6, 0.6, 0.6))
			obj_line.add_child(check)

			var obj_text = Label.new()
			if target > 0:
				obj_text.text = "%s: %d / %d" % [prop_name, val, target]
			elif prop.get("type") == "yesno":
				obj_text.text = prop_name + (": Done" if val > 0 else ": Not yet")
			else:
				obj_text.text = "%s: %d" % [prop_name, val]
			obj_text.add_theme_font_size_override("font_size", 18)
			obj_text.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9) if not is_done else Color(0.5, 0.8, 0.5))
			obj_line.add_child(obj_text)

	# Rewards section
	var sep3 = HSeparator.new()
	_detail_panel.add_child(sep3)

	var reward_header = Label.new()
	reward_header.text = "REWARDS" if active else "REWARDS RECEIVED"
	reward_header.add_theme_font_size_override("font_size", 16)
	reward_header.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	_detail_panel.add_child(reward_header)

	var rewards = _extract_rewards(quest)
	if rewards != "":
		var reward_text = Label.new()
		reward_text.text = rewards
		reward_text.add_theme_font_size_override("font_size", 18)
		reward_text.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		reward_text.autowrap_mode = TextServer.AUTOWRAP_WORD
		_detail_panel.add_child(reward_text)

func _show_empty_detail() -> void:
	for child in _detail_panel.get_children():
		child.queue_free()
	var lbl = Label.new()
	lbl.text = "Select a quest to view details."
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	_detail_panel.add_child(lbl)

func _get_journal_text(quest: QuestDefinition, qm, active: bool, completed: bool) -> String:
	# Build a Skyrim-style journal entry from the quest summary + context
	var text = quest.summary
	if text == "":
		text = quest.title

	# Add contextual flavor
	if active:
		var target = _get_target_for_quest(quest)
		if target > 0:
			for prop in quest.properties:
				var idx = int(prop.get("index", 0))
				var val = qm.get_quest_value(quest.id, idx)
				if val >= target:
					text += "\n\nI've completed the objective. I should report back."
				elif val > 0:
					text += "\n\nI'm making progress. I need to keep going."
		# Check for delivery quests
		for event in quest.events:
			if event.get("type") == "activate":
				var npc = str(event.get("param", ""))
				if npc != "":
					text += "\n\nI should speak with %s when I'm ready." % npc
			if event.get("type") == "quest":
				var zone = str(event.get("param", ""))
				if zone != "" and zone != quest.location:
					text += "\n\nI need to travel to %s to continue." % _zone_display_name(zone)
	elif completed:
		text += "\n\nThis quest has been completed."

	return text

func _get_target_for_quest(quest: QuestDefinition) -> int:
	# Parse quest events to find the target count (from the >= compare value)
	for event in quest.events:
		if event.get("type") == "quest" or event.get("type") == "activate":
			var script = event.get("script", [])
			var target = _find_target_in_script(script)
			if target > 0:
				return target
	return 0

func _find_target_in_script(commands: Array) -> int:
	for cmd in commands:
		if cmd.get("cmd") == "if":
			var attr = str(cmd.get("attribute", ""))
			var op = str(cmd.get("operation", ""))
			var compare = int(cmd.get("compare", "0"))
			# Look for "session-xxx-0 gt N" pattern (means target is N+1)
			if attr.begins_with("session-") and (op == "gt" or op == "gte"):
				if op == "gt":
					return compare + 1
				else:
					return compare
			# Recurse into sub-scripts
			var sub = cmd.get("script", [])
			var found = _find_target_in_script(sub)
			if found > 0:
				return found
		if cmd.get("cmd") == "ifNot":
			var sub = cmd.get("script", [])
			var found = _find_target_in_script(sub)
			if found > 0:
				return found
	return 0

func _extract_rewards(quest: QuestDefinition) -> String:
	# Scan quest event scripts for reward commands
	var rewards: Array[String] = []
	for event in quest.events:
		var script = event.get("script", [])
		_scan_rewards(script, rewards)
	if rewards.size() == 0:
		return "Unknown"
	return "\n".join(rewards)

func _scan_rewards(commands: Array, rewards: Array[String]) -> void:
	for cmd in commands:
		var c = str(cmd.get("cmd", ""))
		if c == "getItem":
			var name = str(cmd.get("name", ""))
			var count = int(cmd.get("count", "1"))
			if name == "Gold":
				if not _has_reward(rewards, "Gold"):
					rewards.append("%d Gold" % count)
			else:
				rewards.append("%s x%d" % [name, count])
		elif c == "getExp":
			var val = int(cmd.get("value", "0"))
			if val > 0 and not _has_reward(rewards, "XP"):
				rewards.append("%d XP" % val)
		elif c == "giveGold":
			var amount = int(cmd.get("count", "0"))
			if amount > 0 and not _has_reward(rewards, "Gold"):
				rewards.append("%d Gold" % amount)
		# Recurse into sub-scripts
		if cmd.has("script"):
			_scan_rewards(cmd.get("script", []), rewards)
		if cmd.has("options"):
			for opt in cmd.get("options", []):
				_scan_rewards(opt.get("script", []), rewards)

func _has_reward(rewards: Array[String], keyword: String) -> bool:
	for r in rewards:
		if keyword in r:
			return true
	return false

func _zone_display_name(zone_id: String) -> String:
	var names = {
		"haven": "Ravenhollow",
		"barrows": "Graveyard",
		"duskfarm": "Hollow Fields Farm",
		"wastes": "The Wilds",
		"mirage": "S'thel",
		"ashheim": "Dondheim",
		"briarvale": "Gomb",
		"ashvale": "Valley of Bones",
		"ironspine": "Mountain Pass",
	}
	return names.get(zone_id, zone_id.capitalize())

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("quest_log"):
		toggle()
		get_viewport().set_input_as_handled()
