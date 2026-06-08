class_name PerkTreeScreen
extends CanvasLayer

## Full-screen perk tree UI. Opened with P key.
## Shows class-specific perks in a tiered layout with connection lines.

var _panel: Panel
var _title_label: Label
var _tokens_label: Label
var _close_btn: Button
var _perk_nodes: Dictionary = {}  # perk_id -> Button
var _connection_lines: Array[Line2D] = []
var _description_panel: Panel
var _desc_label: Label
var _confirm_btn: Button
var _selected_perk_id: String = ""

# Tabs
var _tab_class_btn: Button
var _tab_general_btn: Button
var _current_tab: String = "class"  # "class" or "general"

# Stat allocation panel
var _stat_panel: Panel
var _stat_points_label: Label
var _stat_rows: Dictionary = {}  # category_key -> {label, plus_btn}
var _passives_label: Label

var _perk_manager: Node  # PerkManager ref
var _allow_unlocks: bool = false  # true only when opened by a trainer NPC

var _trainer_notice_label: Label

const TIER_Y = [180, 340, 500, 660]  # Y positions for tiers 1-4 (perk area)
const PERK_AREA_X_MIN = 420.0
const PERK_AREA_X_MAX = 1500.0
const STAT_CATEGORIES = ["health", "defense", "strength", "speed", "movement", "intellect", "luck", "endurance"]
const PERK_SIZE = Vector2(140, 50)
const BG_COLOR = Color(0.05, 0.05, 0.1, 0.95)
const LOCKED_COLOR = Color(0.3, 0.3, 0.3)
const STAT_LOCKED_COLOR = Color(0.55, 0.35, 0.55)  # stat req not met
const AVAILABLE_COLOR = Color(0.9, 0.8, 0.2)
const UNLOCKED_COLOR = Color(0.2, 0.9, 0.3)
const LINE_LOCKED = Color(0.2, 0.2, 0.2)
const LINE_UNLOCKED = Color(0.3, 0.8, 0.3)

func _ready() -> void:
	layer = 110
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _build_ui() -> void:
	# Background panel
	_panel = Panel.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb = StyleBoxFlat.new()
	sb.bg_color = BG_COLOR
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	# Title
	_title_label = Label.new()
	_title_label.text = "PERK TREE"
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.position = Vector2(0, 20)
	_title_label.size = Vector2(1920, 40)
	_panel.add_child(_title_label)

	# Token count
	_tokens_label = Label.new()
	_tokens_label.text = "Tokens: 0"
	_tokens_label.add_theme_font_size_override("font_size", 20)
	_tokens_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_tokens_label.position = Vector2(1920 - 200, 25)
	_panel.add_child(_tokens_label)

	# Close button
	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.position = Vector2(1920 - 50, 10)
	_close_btn.custom_minimum_size = Vector2(36, 36)
	_close_btn.pressed.connect(close)
	_panel.add_child(_close_btn)

	# Tab buttons (Class / General)
	_tab_class_btn = Button.new()
	_tab_class_btn.text = "CLASS PERKS"
	_tab_class_btn.position = Vector2(PERK_AREA_X_MIN + 50, 90)
	_tab_class_btn.custom_minimum_size = Vector2(220, 40)
	_tab_class_btn.add_theme_font_size_override("font_size", 16)
	_tab_class_btn.pressed.connect(_on_tab_pressed.bind("class"))
	_panel.add_child(_tab_class_btn)

	_tab_general_btn = Button.new()
	_tab_general_btn.text = "GENERAL PERKS"
	_tab_general_btn.position = Vector2(PERK_AREA_X_MIN + 290, 90)
	_tab_general_btn.custom_minimum_size = Vector2(220, 40)
	_tab_general_btn.add_theme_font_size_override("font_size", 16)
	_tab_general_btn.pressed.connect(_on_tab_pressed.bind("general"))
	_panel.add_child(_tab_general_btn)

	_build_stat_panel()

	# Description panel (bottom)
	_description_panel = Panel.new()
	_description_panel.position = Vector2(600, 880)
	_description_panel.size = Vector2(720, 130)
	var desc_sb = StyleBoxFlat.new()
	desc_sb.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	desc_sb.border_color = Color(0.4, 0.4, 0.5)
	desc_sb.border_width_top = 1
	desc_sb.border_width_bottom = 1
	desc_sb.border_width_left = 1
	desc_sb.border_width_right = 1
	_description_panel.add_theme_stylebox_override("panel", desc_sb)
	_description_panel.visible = false
	_panel.add_child(_description_panel)

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 16)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc_label.position = Vector2(10, 10)
	_desc_label.size = Vector2(580, 80)
	_description_panel.add_child(_desc_label)

	_confirm_btn = Button.new()
	_confirm_btn.text = "UNLOCK (1 Token)"
	_confirm_btn.position = Vector2(600, 30)
	_confirm_btn.custom_minimum_size = Vector2(110, 40)
	_confirm_btn.pressed.connect(_on_confirm_unlock)
	_confirm_btn.visible = false
	_description_panel.add_child(_confirm_btn)

func _build_stat_panel() -> void:
	_stat_panel = Panel.new()
	_stat_panel.position = Vector2(40, 90)
	_stat_panel.size = Vector2(360, 900)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	sb.border_color = Color(0.4, 0.4, 0.5)
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	_stat_panel.add_theme_stylebox_override("panel", sb)
	_panel.add_child(_stat_panel)

	var header = Label.new()
	header.text = "ATTRIBUTES"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	header.position = Vector2(20, 12)
	_stat_panel.add_child(header)

	_stat_points_label = Label.new()
	_stat_points_label.add_theme_font_size_override("font_size", 14)
	_stat_points_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_stat_points_label.position = Vector2(20, 38)
	_stat_panel.add_child(_stat_points_label)

	# 6 stat rows
	var y = 70
	for cat in STAT_CATEGORIES:
		var row_label = Label.new()
		row_label.add_theme_font_size_override("font_size", 15)
		row_label.position = Vector2(20, y)
		row_label.size = Vector2(240, 28)
		_stat_panel.add_child(row_label)

		var plus_btn = Button.new()
		plus_btn.text = "+"
		plus_btn.add_theme_font_size_override("font_size", 18)
		plus_btn.position = Vector2(280, y - 2)
		plus_btn.custom_minimum_size = Vector2(40, 32)
		plus_btn.pressed.connect(_on_alloc_pressed.bind(cat))
		_stat_panel.add_child(plus_btn)
		_stat_rows[cat] = {"label": row_label, "plus": plus_btn}
		y += 38

	# Threshold passives summary
	var passives_header = Label.new()
	passives_header.text = "ACTIVE PASSIVES"
	passives_header.add_theme_font_size_override("font_size", 14)
	passives_header.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	passives_header.position = Vector2(20, y + 10)
	_stat_panel.add_child(passives_header)

	_passives_label = Label.new()
	_passives_label.add_theme_font_size_override("font_size", 12)
	_passives_label.position = Vector2(20, y + 36)
	_passives_label.size = Vector2(320, 460)
	_passives_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_stat_panel.add_child(_passives_label)

func _on_tab_pressed(tab: String) -> void:
	_current_tab = tab
	_refresh()

func _on_alloc_pressed(category: String) -> void:
	var ls = _get_level_system()
	if not ls:
		return
	if ls.allocate_stat_point(category):
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("click", -3.0)
		_refresh()

func _get_level_system() -> Node:
	var p = get_tree().get_first_node_in_group("player") if get_tree() else null
	if p and "level_system" in p:
		return p.level_system
	return null

func _refresh_stat_panel() -> void:
	var ls = _get_level_system()
	if not ls:
		_stat_points_label.text = "(player not found)"
		return
	ls.ensure_retroactive_points()
	var free_pts = ls.unspent_stat_points
	if free_pts > 0:
		_stat_points_label.text = "Unspent Points: %d" % free_pts
	else:
		_stat_points_label.text = "All points spent"
	for cat in STAT_CATEGORIES:
		var pts = int(ls.allocated.get(cat, 0))
		var row = _stat_rows[cat]
		row["label"].text = "%s: %d" % [LevelSystem.display_name(cat), pts]
		row["plus"].disabled = free_pts <= 0
		row["plus"].modulate = Color(1, 1, 1) if free_pts > 0 else Color(0.5, 0.5, 0.5)
	# Active passives
	var passives = StatThresholds.get_all_passives(ls.allocated)
	var active_lines: Array[String] = []
	var next_line = ""
	for p in passives:
		if p["active"]:
			active_lines.append("• %s (%s): %s" % [p["name"], LevelSystem.display_name(p["category"]), p["desc"]])
		elif next_line == "":
			next_line = "Next → %s %d/%d (%s)" % [LevelSystem.display_name(p["category"]), p["current"], p["threshold"], p["name"]]
	var passives_text = "\n".join(active_lines) if active_lines.size() > 0 else "(none yet — allocate points)"
	if next_line != "":
		passives_text += "\n\n" + next_line
	_passives_label.text = passives_text

func open(allow_unlocks: bool = false) -> void:
	_perk_manager = get_node_or_null("/root/PerkManager")
	if not _perk_manager:
		# Create PerkManager if not autoloaded yet
		return
	_allow_unlocks = allow_unlocks
	visible = true
	get_tree().paused = true
	_refresh()

func close() -> void:
	visible = false
	get_tree().paused = false
	_description_panel.visible = false
	_selected_perk_id = ""

func _refresh() -> void:
	# Clear old nodes
	for btn in _perk_nodes.values():
		btn.queue_free()
	_perk_nodes.clear()
	for line in _connection_lines:
		line.queue_free()
	_connection_lines.clear()

	if not _perk_manager:
		return

	# Get class
	var gm = get_node_or_null("/root/GameManager")
	var class_id = gm.selected_class if gm else "warrior"
	if _allow_unlocks:
		_title_label.text = "TRAINING  —  %s  (unlock perks here)" % class_id.to_upper()
	else:
		_title_label.text = "CHARACTER  —  %s  (allocate stats; visit a trainer for perks)" % class_id.to_upper()
	_tokens_label.text = "Tokens: %d" % _perk_manager.perk_tokens

	# Highlight active tab
	_tab_class_btn.modulate = AVAILABLE_COLOR if _current_tab == "class" else Color(0.7, 0.7, 0.7)
	_tab_general_btn.modulate = AVAILABLE_COLOR if _current_tab == "general" else Color(0.7, 0.7, 0.7)

	# Refresh stat allocation panel
	_refresh_stat_panel()

	# Pick perk pool based on tab
	var perks: Array
	if _current_tab == "general":
		perks = _perk_manager.get_general_perks() as Array
	else:
		perks = _perk_manager.get_class_perks(class_id) as Array
	if perks.is_empty():
		return

	# Group by tier
	var tiers: Dictionary = {}  # tier -> Array[PerkDefinition]
	for perk in perks:
		if not tiers.has(perk.tier):
			tiers[perk.tier] = []
		tiers[perk.tier].append(perk)

	# Layout perks within perk area
	var perk_area_width = PERK_AREA_X_MAX - PERK_AREA_X_MIN
	for tier in tiers:
		var tier_perks = tiers[tier] as Array
		var count = tier_perks.size()
		var total_width = count * PERK_SIZE.x + (count - 1) * 30
		var start_x = PERK_AREA_X_MIN + (perk_area_width - total_width) / 2.0
		var y = TIER_Y[mini(tier - 1, 3)]

		for i in range(count):
			var perk = tier_perks[i] as PerkDefinition
			var x = start_x + i * (PERK_SIZE.x + 30)
			var btn = Button.new()
			btn.text = perk.perk_name
			btn.position = Vector2(x, y)
			btn.custom_minimum_size = PERK_SIZE
			btn.size = PERK_SIZE
			btn.add_theme_font_size_override("font_size", 13)
			btn.focus_mode = Control.FOCUS_NONE

			# Color based on state
			if _perk_manager.has_perk(perk.perk_id):
				btn.modulate = UNLOCKED_COLOR
			elif _perk_manager.can_unlock(perk.perk_id):
				btn.modulate = AVAILABLE_COLOR
			else:
				var why = _perk_manager.unlock_blocker(perk.perk_id)
				btn.modulate = STAT_LOCKED_COLOR if why.begins_with("Requires ") and not why.begins_with("Requires perk") else LOCKED_COLOR

			btn.pressed.connect(_on_perk_clicked.bind(perk.perk_id))
			_panel.add_child(btn)
			_perk_nodes[perk.perk_id] = btn

	# Draw connection lines (prerequisites)
	for perk in perks:
		if not _perk_nodes.has(perk.perk_id):
			continue
		var child_btn = _perk_nodes[perk.perk_id]
		for prereq_id in perk.prerequisites:
			if not _perk_nodes.has(prereq_id):
				continue
			var parent_btn = _perk_nodes[prereq_id]
			var line = Line2D.new()
			line.width = 2.0
			var from_pos = parent_btn.position + Vector2(PERK_SIZE.x / 2, PERK_SIZE.y)
			var to_pos = child_btn.position + Vector2(PERK_SIZE.x / 2, 0)
			line.add_point(from_pos)
			line.add_point(to_pos)
			if _perk_manager.has_perk(prereq_id):
				line.default_color = LINE_UNLOCKED
			else:
				line.default_color = LINE_LOCKED
			_panel.add_child(line)
			# Move line behind buttons
			_panel.move_child(line, 1)
			_connection_lines.append(line)

func _on_perk_clicked(perk_id: String) -> void:
	_selected_perk_id = perk_id
	var perk = _perk_manager._all_perks.get(perk_id) as PerkDefinition
	if not perk:
		return
	_description_panel.visible = true
	var lines: Array[String] = []
	var status = ""
	if _perk_manager.has_perk(perk_id):
		status = " [UNLOCKED]"
	lines.append("%s%s" % [perk.perk_name, status])
	lines.append(perk.description)
	# Stat requirements line
	if perk.stat_requirements.size() > 0:
		var parts: Array[String] = []
		for cat in perk.stat_requirements:
			var need = int(perk.stat_requirements[cat])
			var disp = LevelSystem.display_name(cat)
			parts.append("%d %s" % [need, disp])
		lines.append("Requires: " + ", ".join(parts))
	# Prerequisites line
	if perk.prerequisites.size() > 0:
		var pnames: Array[String] = []
		for pid in perk.prerequisites:
			var prereq = _perk_manager._all_perks.get(pid) as PerkDefinition
			pnames.append(prereq.perk_name if prereq else pid)
		lines.append("After: " + ", ".join(pnames))
	# Blocker reason (if not unlockable and not already owned)
	if not _perk_manager.has_perk(perk_id):
		if not _allow_unlocks:
			lines.append("[Visit a trainer NPC (e.g. the Elder) to unlock perks]")
		else:
			var why = _perk_manager.unlock_blocker(perk_id)
			if why != "":
				lines.append("[" + why + "]")
	_desc_label.text = "\n".join(lines)

	# Show confirm button only when at a trainer and unlock is valid
	_confirm_btn.visible = _allow_unlocks and _perk_manager.can_unlock(perk_id)

func _on_confirm_unlock() -> void:
	if _selected_perk_id == "" or not _perk_manager:
		return
	if _perk_manager.unlock_perk(_selected_perk_id):
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("level_up", -3.0)
		_refresh()
		# Re-select to update description
		_on_perk_clicked(_selected_perk_id)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("perk_tree"):
		close()
		get_viewport().set_input_as_handled()
	elif not visible and event.is_action_pressed("perk_tree"):
		open()
		get_viewport().set_input_as_handled()
