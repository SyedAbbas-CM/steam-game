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

var _perk_manager: Node  # PerkManager ref

const TIER_Y = [120, 280, 440, 600]  # Y positions for tiers 1-4
const PERK_SIZE = Vector2(140, 50)
const BG_COLOR = Color(0.05, 0.05, 0.1, 0.95)
const LOCKED_COLOR = Color(0.3, 0.3, 0.3)
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

	# Description panel (bottom)
	_description_panel = Panel.new()
	_description_panel.position = Vector2(600, 680)
	_description_panel.size = Vector2(720, 100)
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

func open() -> void:
	_perk_manager = get_node_or_null("/root/PerkManager")
	if not _perk_manager:
		# Create PerkManager if not autoloaded yet
		return
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
	_title_label.text = "%s PERK TREE" % class_id.to_upper()
	_tokens_label.text = "Tokens: %d" % _perk_manager.perk_tokens

	# Get perks for this class
	var perks = _perk_manager.get_class_perks(class_id) as Array
	if perks.is_empty():
		return

	# Group by tier
	var tiers: Dictionary = {}  # tier -> Array[PerkDefinition]
	for perk in perks:
		if not tiers.has(perk.tier):
			tiers[perk.tier] = []
		tiers[perk.tier].append(perk)

	# Layout perks
	for tier in tiers:
		var tier_perks = tiers[tier] as Array
		var count = tier_perks.size()
		var total_width = count * PERK_SIZE.x + (count - 1) * 40
		var start_x = (1920 - total_width) / 2.0
		var y = TIER_Y[mini(tier - 1, 3)]

		for i in range(count):
			var perk = tier_perks[i] as PerkDefinition
			var x = start_x + i * (PERK_SIZE.x + 40)
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
				btn.modulate = LOCKED_COLOR

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
	var status = ""
	if _perk_manager.has_perk(perk_id):
		status = " [UNLOCKED]"
	_desc_label.text = "%s%s\n%s" % [perk.perk_name, status, perk.description]

	# Show confirm button if can unlock
	_confirm_btn.visible = _perk_manager.can_unlock(perk_id)

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
