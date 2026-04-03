class_name BattleCommandOverlay
extends CanvasLayer

# Command mode overlay: group selection, move/attack orders
# Shown when Tab is pressed, camera zooms out
#
# Controls:
#   Left-click on map  = ATK MOVE (attack-move to position)
#   Right-click on map = pure MOVE (move to position, no attack)
#   Box drag           = select units inside box
#   Double-click unit  = select nearby same-type units
#   Click group button = select that group
#   Delete / X button  = disband selected group (units return to default groups)
#   Selection persists until you select something else

signal command_issued(group_id: int, command: int, target_x: float, target_y: float)
signal exit_command_mode
signal focus_group(center_x: float, center_y: float)
signal zoom_requested(zoom_level: float)

var _panel: Panel
var _group_buttons: Array[Button] = []
var _selected_group_id: int = -1
var _instruction_label: Label
var _group_list: VBoxContainer
var _close_button: Button

var _units: BattleUnitSystem
var _commander: BattleCommander

# Group banner markers (world-space, added to parent scene not overlay)
var _banner_markers: Array[Node2D] = []
var _selection_circles: Array[Node2D] = []
var _banner_parent: Node2D  # set by battle_arena

# Command buttons
var _hold_button: Button
var _follow_button: Button
var _scatter_button: Button
var _defensive_button: Button

# Box/individual selection
var _selected_units: PackedInt32Array = PackedInt32Array()
var _drag_start: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_rect: Rect2 = Rect2()
var _selection_draw: Control
var _last_click_time: float = 0.0
var _last_click_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	layer = 11
	visible = false
	_build_ui()
	# Selection rectangle overlay drawn on screen
	_selection_draw = Control.new()
	_selection_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_selection_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_draw.draw.connect(_on_selection_draw)
	add_child(_selection_draw)

func _build_ui() -> void:
	# Semi-transparent background
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.3)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Left panel for group list — positioned below player HP/MP bars
	_panel = Panel.new()
	_panel.position = Vector2(10, 120)
	_panel.size = Vector2(220, 480)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.2, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "UNITS"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# ALL button — select every blue unit
	var all_btn := Button.new()
	all_btn.text = ">> SELECT ALL <<"
	all_btn.add_theme_font_size_override("font_size", 13)
	all_btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	all_btn.pressed.connect(_on_select_all)
	vbox.add_child(all_btn)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	_group_list = VBoxContainer.new()
	vbox.add_child(_group_list)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# --- COMMANDS section ---
	var cmd_sep := HSeparator.new()
	vbox.add_child(cmd_sep)

	var cmd_label := Label.new()
	cmd_label.text = "ORDERS"
	cmd_label.add_theme_font_size_override("font_size", 13)
	cmd_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	cmd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cmd_label)

	# Row 1: HOLD + FOLLOW
	var cmd_row := HBoxContainer.new()
	vbox.add_child(cmd_row)

	_hold_button = Button.new()
	_hold_button.text = "HOLD"
	_hold_button.add_theme_font_size_override("font_size", 13)
	_hold_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hold_button.pressed.connect(_on_instant_command.bind(BattleCommander.CommandType.HOLD))
	cmd_row.add_child(_hold_button)

	_follow_button = Button.new()
	_follow_button.text = "FOLLOW"
	_follow_button.add_theme_font_size_override("font_size", 13)
	_follow_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_follow_button.pressed.connect(_on_instant_command.bind(BattleCommander.CommandType.FOLLOW))
	cmd_row.add_child(_follow_button)

	# Row 2: SCATTER + DEFEND
	var cmd_row2 := HBoxContainer.new()
	vbox.add_child(cmd_row2)

	_scatter_button = Button.new()
	_scatter_button.text = "SCATTER"
	_scatter_button.add_theme_font_size_override("font_size", 13)
	_scatter_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scatter_button.pressed.connect(_on_instant_command.bind(BattleCommander.CommandType.SCATTER))
	cmd_row2.add_child(_scatter_button)

	_defensive_button = Button.new()
	_defensive_button.text = "DEFEND"
	_defensive_button.add_theme_font_size_override("font_size", 13)
	_defensive_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_defensive_button.pressed.connect(_on_instant_command.bind(BattleCommander.CommandType.DEFENSIVE))
	cmd_row2.add_child(_defensive_button)

	# --- FORMATIONS section ---
	var form_sep := HSeparator.new()
	vbox.add_child(form_sep)

	var form_label := Label.new()
	form_label.text = "FORMATION"
	form_label.add_theme_font_size_override("font_size", 13)
	form_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	form_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(form_label)

	var form_row := HBoxContainer.new()
	vbox.add_child(form_row)

	for fm_data in [
		["LINE", BattleUnitSystem.FormationType.LINE],
		["SHIELD", BattleUnitSystem.FormationType.SHIELD_WALL],
		["WEDGE", BattleUnitSystem.FormationType.WEDGE],
		["LOOSE", BattleUnitSystem.FormationType.LOOSE_LINE],
	]:
		var fm_btn := Button.new()
		fm_btn.text = fm_data[0]
		fm_btn.add_theme_font_size_override("font_size", 11)
		fm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fm_btn.pressed.connect(_on_formation_change.bind(fm_data[1]))
		form_row.add_child(fm_btn)

	# Instruction label
	_instruction_label = Label.new()
	_instruction_label.text = "Select a group above"
	_instruction_label.add_theme_font_size_override("font_size", 12)
	_instruction_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_instruction_label)

	# --- ZOOM section ---
	var zoom_sep := HSeparator.new()
	vbox.add_child(zoom_sep)

	var zoom_label := Label.new()
	zoom_label.text = "ZOOM"
	zoom_label.add_theme_font_size_override("font_size", 13)
	zoom_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(zoom_label)

	var zoom_row := HBoxContainer.new()
	vbox.add_child(zoom_row)
	for z_data in [["1x", 1.0], ["2x", 0.5], ["4x", 0.25]]:
		var z_btn := Button.new()
		z_btn.text = z_data[0]
		z_btn.add_theme_font_size_override("font_size", 11)
		z_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		z_btn.pressed.connect(_on_zoom_pressed.bind(z_data[1]))
		zoom_row.add_child(z_btn)

	# Close hint
	var hint := Label.new()
	hint.text = "L-click: Select | R-click: Atk Move\nShift+R-click: Move | Drag: Box select\nDbl-click: same type | [Tab] exit"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

func initialize(units: BattleUnitSystem, commander: BattleCommander, banner_parent: Node2D) -> void:
	_units = units
	_commander = commander
	_banner_parent = banner_parent

func show_overlay() -> void:
	visible = true
	_refresh_group_list()
	_update_banners()

func hide_overlay() -> void:
	visible = false
	_selected_group_id = -1
	_selected_units.clear()
	_clear_banners()

func _refresh_group_list() -> void:
	for child in _group_list.get_children():
		child.queue_free()
	_group_buttons.clear()

	var player_groups := _commander.get_faction_groups(BattleUnitSystem.Faction.BLUE)
	for g in player_groups:
		var alive_count := _units.get_group_alive_count(g.id)
		if alive_count == 0:
			continue

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)

		var btn := Button.new()
		var type_name: String = BattleUnitSystem.UnitType.keys()[g.unit_type] if g.unit_type >= 0 else "Custom"
		var cmd_name := _get_command_display(g.command)
		btn.text = "%s (%d) %s" % [type_name.capitalize(), alive_count, cmd_name]
		btn.add_theme_font_size_override("font_size", 13)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if g.id == _selected_group_id:
			btn.add_theme_color_override("font_color", Color.GOLD)
		btn.pressed.connect(_on_group_selected.bind(g.id))
		row.add_child(btn)
		_group_buttons.append(btn)

		# X button to disband group (only for custom groups)
		if not g.permanent:
			var x_btn := Button.new()
			x_btn.text = "X"
			x_btn.add_theme_font_size_override("font_size", 11)
			x_btn.custom_minimum_size = Vector2(24, 0)
			x_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			x_btn.pressed.connect(_on_disband_group.bind(g.id))
			row.add_child(x_btn)

		_group_list.add_child(row)

func _get_command_display(cmd: int) -> String:
	match cmd:
		BattleCommander.CommandType.HOLD: return "[HOLD]"
		BattleCommander.CommandType.FOLLOW: return "[FOLLOW]"
		BattleCommander.CommandType.SCATTER: return "[SCATTER]"
		BattleCommander.CommandType.DEFENSIVE: return "[DEFEND]"
		BattleCommander.CommandType.MOVE: return "[MOVE]"
		BattleCommander.CommandType.ATTACK: return "[ATK]"
		_: return ""

func _on_group_selected(group_id: int) -> void:
	_selected_group_id = group_id
	_selected_units.clear()
	_instruction_label.text = "L-click: Atk Move | R-click: Move"
	_refresh_group_list()
	_update_banners()
	if _units:
		var center := _units.get_group_center(group_id)
		if center != Vector2.ZERO:
			focus_group.emit(center.x, center.y)

func _on_disband_group(group_id: int) -> void:
	var grp = _commander.get_group(group_id)
	if grp and grp.permanent:
		_instruction_label.text = "Can't disband unit type groups"
		return
	_commander.remove_group(group_id)
	# Return units to their permanent type group (not -1)
	for i in _units.count:
		if _units.group_id[i] == group_id:
			var perm := _commander.get_permanent_group_for_type(_units.faction[i], _units.unit_type[i])
			_units.group_id[i] = perm.id if perm else -1
	if _selected_group_id == group_id:
		_selected_group_id = -1
	_instruction_label.text = "Group disbanded — units returned"
	_refresh_group_list()
	_update_banners()

func _on_select_all() -> void:
	## Select ALL alive blue units as a loose selection
	var all_units := PackedInt32Array()
	for i in _units.count:
		if _units.alive[i] == 1 and _units.faction[i] == BattleUnitSystem.Faction.BLUE:
			all_units.append(i)
	if all_units.size() > 0:
		_selected_units = all_units
		_selected_group_id = -1
		_instruction_label.text = "ALL %d units selected" % all_units.size()
		_refresh_group_list()
		_update_banners()

func _on_instant_command(cmd: int) -> void:
	if _selected_group_id < 0 and _selected_units.is_empty():
		_instruction_label.text = "Select a group first!"
		return
	if _selected_group_id >= 0:
		command_issued.emit(_selected_group_id, cmd, 0.0, 0.0)
	elif not _selected_units.is_empty():
		_issue_command_to_selection(cmd, Vector2.ZERO)
	var cmd_name := _get_command_display(cmd).trim_prefix("[").trim_suffix("]")
	_instruction_label.text = "%s issued!" % cmd_name
	_highlight_active_command(cmd)
	_refresh_group_list()

func _on_formation_change(formation_type: int) -> void:
	if _selected_group_id < 0:
		_instruction_label.text = "Select a group first!"
		return
	var grp = _commander.get_group(_selected_group_id)
	if grp:
		grp.formation_type = formation_type
		var fm_keys := BattleUnitSystem.FormationType.keys()
		var fm_name: String = fm_keys[formation_type] if formation_type >= 0 and formation_type < fm_keys.size() else "UNKNOWN"
		_instruction_label.text = "Formation: %s" % fm_name
		_refresh_group_list()

func _highlight_active_command(cmd: int) -> void:
	var cmd_buttons := {
		BattleCommander.CommandType.HOLD: _hold_button,
		BattleCommander.CommandType.FOLLOW: _follow_button,
		BattleCommander.CommandType.SCATTER: _scatter_button,
		BattleCommander.CommandType.DEFENSIVE: _defensive_button,
	}
	for c in cmd_buttons:
		var btn: Button = cmd_buttons[c]
		if c == cmd:
			btn.add_theme_color_override("font_color", Color.GREEN)
		else:
			btn.remove_theme_color_override("font_color")

func _update_banners() -> void:
	_clear_banners()
	if not _banner_parent or not _units or not _commander:
		return
	var player_groups := _commander.get_faction_groups(BattleUnitSystem.Faction.BLUE)
	for g in player_groups:
		var alive_count := _units.get_group_alive_count(g.id)
		if alive_count == 0:
			continue
		var center := _units.get_group_center(g.id)
		var marker := _create_banner(g, center, g.id == _selected_group_id)
		_banner_parent.add_child(marker)
		_banner_markers.append(marker)
	var enemy_groups := _commander.get_faction_groups(BattleUnitSystem.Faction.RED)
	for g in enemy_groups:
		var alive_count := _units.get_group_alive_count(g.id)
		if alive_count == 0:
			continue
		var center := _units.get_group_center(g.id)
		var marker := _create_banner(g, center, false, true)
		_banner_parent.add_child(marker)
		_banner_markers.append(marker)

	# Draw selection circles on selected units
	_update_selection_circles()

func _create_banner(group: BattleCommander.BattleGroup, pos: Vector2, selected: bool, is_enemy: bool = false) -> Node2D:
	var node := Node2D.new()
	node.position = pos + Vector2(0, -30)
	node.z_index = 10
	var poly := Polygon2D.new()
	var base_color := Color.RED if is_enemy else Color(0.3, 0.6, 1.0)
	if selected:
		base_color = Color.GOLD
	poly.color = base_color
	poly.polygon = PackedVector2Array([
		Vector2(-8, -16), Vector2(8, -8), Vector2(-8, 0)
	])
	node.add_child(poly)
	var pole := Line2D.new()
	pole.points = PackedVector2Array([Vector2(-8, -16), Vector2(-8, 8)])
	pole.width = 2.0
	pole.default_color = Color(0.6, 0.4, 0.2)
	node.add_child(pole)
	var label := Label.new()
	label.text = str(_units.get_group_alive_count(group.id))
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(-12, -30)
	node.add_child(label)
	return node

func _create_selection_circle(unit_radius: float) -> Node2D:
	var node := Node2D.new()
	node.z_index = 5
	var circle_r := maxf(12.0, unit_radius + 4.0)
	var points := PackedVector2Array()
	var segments := 16
	for s in range(segments + 1):
		var angle := float(s) / segments * TAU
		points.append(Vector2(cos(angle) * circle_r, sin(angle) * circle_r))
	var line := Line2D.new()
	line.points = points
	line.width = 1.5
	line.default_color = Color(0.3, 1.0, 0.3, 0.8)
	node.add_child(line)
	return node

func _clear_selection_circles() -> void:
	for c in _selection_circles:
		if is_instance_valid(c):
			c.queue_free()
	_selection_circles.clear()

func _update_selection_circles() -> void:
	## Create/update green circles on all selected units.
	if not _banner_parent or not _units:
		_clear_selection_circles()
		return
	# Gather selected unit indices
	var selected_ids := PackedInt32Array()
	if _selected_group_id >= 0:
		for i in _units.count:
			if _units.alive[i] == 1 and _units.group_id[i] == _selected_group_id:
				selected_ids.append(i)
	elif not _selected_units.is_empty():
		for idx in _selected_units:
			if idx < _units.count and _units.alive[idx] == 1:
				selected_ids.append(idx)

	# Reuse existing circle nodes where possible, create/remove as needed
	while _selection_circles.size() > selected_ids.size():
		var c = _selection_circles.pop_back()
		if is_instance_valid(c):
			c.queue_free()
	while _selection_circles.size() < selected_ids.size():
		var circle := _create_selection_circle(16.0)
		_banner_parent.add_child(circle)
		_selection_circles.append(circle)
	# Update positions
	for k in selected_ids.size():
		var idx := selected_ids[k]
		var c: Node2D = _selection_circles[k]
		if is_instance_valid(c):
			c.position = Vector2(_units.x[idx], _units.y[idx])

func _clear_banners() -> void:
	for marker in _banner_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_banner_markers.clear()
	_clear_selection_circles()

func _is_on_panel(screen_pos: Vector2) -> bool:
	return screen_pos.x >= _panel.position.x and screen_pos.x <= _panel.position.x + _panel.size.x \
		and screen_pos.y >= _panel.position.y and screen_pos.y <= _panel.position.y + _panel.size.y

# ==========================================================================
# INPUT — Standard RTS controls
#   Left-click         = SELECT (click unit, double-click = same type nearby)
#   Left-drag          = BOX SELECT
#   Right-click        = ATK MOVE to position
#   Shift+Right-click  = pure MOVE to position
#   Delete key         = disband selected custom group
#   Selection NEVER clears unless you select something new
# ==========================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return

	var viewport := get_viewport()
	var camera := viewport.get_camera_2d()
	if not camera:
		return

	var has_selection := _selected_group_id >= 0 or not _selected_units.is_empty()

	# --- DELETE key: disband selected custom group ---
	if event is InputEventKey and event.pressed and event.keycode == KEY_DELETE:
		if _selected_group_id >= 0:
			_on_disband_group(_selected_group_id)
			get_viewport().set_input_as_handled()
		return

	# --- RIGHT-CLICK: command (ATK MOVE or MOVE with shift) ---
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if has_selection and not _is_on_panel(event.position):
			var world_pos := _screen_to_world(event.position, camera, viewport)
			var cmd := BattleCommander.CommandType.MOVE if event.shift_pressed else BattleCommander.CommandType.ATTACK
			_issue_command_to_selection(cmd, world_pos)
			get_viewport().set_input_as_handled()
		return

	# --- CTRL+LEFT-CLICK: add clicked unit to currently selected group ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.ctrl_pressed:
		if _selected_group_id >= 0 and not _is_on_panel(event.position):
			var world_pos := _screen_to_world(event.position, camera, viewport)
			var clicked := _find_unit_at(world_pos, camera)
			if clicked >= 0:
				_units.group_id[clicked] = _selected_group_id
				_instruction_label.text = "Unit added to group"
				_refresh_group_list()
				_update_banners()
				get_viewport().set_input_as_handled()
			return

	# --- LEFT-CLICK: selection only (never issues commands) ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_on_panel(event.position):
			_drag_start = Vector2.ZERO
			_dragging = false
			_selection_draw.queue_redraw()
			return

		if event.pressed:
			_drag_start = event.position
			_dragging = false
		else:
			# Mouse release
			if _dragging:
				_finish_box_selection(camera, viewport)
			elif _drag_start != Vector2.ZERO:
				# Single click — always try to select, never command
				var world_pos := _screen_to_world(event.position, camera, viewport)
				var clicking_unit := _find_unit_at(world_pos, camera)
				if clicking_unit >= 0:
					var now := Time.get_ticks_msec() / 1000.0
					if (now - _last_click_time) < 0.4 and event.position.distance_to(_last_click_pos) < 40.0:
						_select_nearby_same_type(clicking_unit)
						_last_click_time = 0.0
					else:
						_try_select_unit_at(event.position, camera, viewport)
						_last_click_time = now
						_last_click_pos = event.position
				# Clicking empty space does nothing — no accidental commands
			_dragging = false
			_drag_rect = Rect2()
			_drag_start = Vector2.ZERO
			_selection_draw.queue_redraw()
			get_viewport().set_input_as_handled()

	# --- MOUSE MOTION: drag selection box ---
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if _drag_start != Vector2.ZERO and not _is_on_panel(event.position):
			if _drag_start.distance_to(event.position) > 5.0:
				_dragging = true
				_drag_rect = Rect2(_drag_start, event.position - _drag_start).abs()
				_selection_draw.queue_redraw()

func _find_unit_at(world_pos: Vector2, camera: Camera2D) -> int:
	## Returns nearest BLUE unit index at world_pos, or -1 if none.
	## Generous threshold so units are easy to click when zoomed out.
	var threshold := 40.0 / camera.zoom.x
	var best_dist := threshold
	var best_idx := -1
	for idx in _units.count:
		if _units.alive[idx] == 0 or _units.faction[idx] != BattleUnitSystem.Faction.BLUE:
			continue
		var d := Vector2(_units.x[idx], _units.y[idx]).distance_to(world_pos)
		if d < best_dist:
			best_dist = d
			best_idx = idx
	return best_idx

func _try_select_unit_at(screen_pos: Vector2, camera: Camera2D, viewport: Viewport) -> void:
	## Single-click select: find nearest friendly unit. If found, select its GROUP.
	## If nothing found, do NOT deselect — selection persists.
	var world_pos := _screen_to_world(screen_pos, camera, viewport)
	var best_idx := _find_unit_at(world_pos, camera)
	if best_idx >= 0:
		# Found a unit — select its group (if it has one), otherwise select just this unit
		var gid := _units.group_id[best_idx]
		if gid >= 0 and _commander.get_group(gid):
			_on_group_selected(gid)
		else:
			_selected_units = PackedInt32Array([best_idx])
			_selected_group_id = -1
			_instruction_label.text = "1 unit selected"
			_refresh_group_list()
	# If nothing found: do nothing — keep current selection

func _select_nearby_same_type(unit_idx: int) -> void:
	## Double-click: select all nearby units of the same type within 300px.
	## Does NOT reassign group_id — just selects them as loose selection.
	var ux := _units.x[unit_idx]
	var uy := _units.y[unit_idx]
	var utype := _units.unit_type[unit_idx]
	var radius := 300.0
	var nearby := PackedInt32Array()
	for i in _units.count:
		if _units.alive[i] == 0 or _units.faction[i] != BattleUnitSystem.Faction.BLUE:
			continue
		if _units.unit_type[i] != utype:
			continue
		var dx := _units.x[i] - ux
		var dy := _units.y[i] - uy
		if dx * dx + dy * dy <= radius * radius:
			nearby.append(i)
	if nearby.size() > 0:
		# Check if they all share one group
		var common_gid := _units.group_id[nearby[0]]
		var all_same := common_gid >= 0
		for idx in nearby:
			if _units.group_id[idx] != common_gid:
				all_same = false
				break
		if all_same and _commander.get_group(common_gid):
			# All in same group — just select that group
			_selected_group_id = common_gid
			_selected_units.clear()
		else:
			# Mixed groups — store as loose selection (preserve original group_ids)
			_selected_units = nearby
			_selected_group_id = -1
		var type_name: String = BattleUnitSystem.UnitType.keys()[utype].capitalize()
		_instruction_label.text = "%d %s selected nearby" % [nearby.size(), type_name]
		_refresh_group_list()
		_update_banners()

func _issue_command_to_selection(cmd: int, world_pos: Vector2) -> void:
	if _selected_units.size() > 0:
		# Loose selection — issue command to EACH existing group that has selected units.
		# Do NOT create new groups or reassign group_ids — preserve permanent groups.
		var group_ids_seen: Dictionary = {}
		for idx in _selected_units:
			if idx < _units.count and _units.alive[idx] == 1:
				var gid := _units.group_id[idx]
				if gid >= 0 and not group_ids_seen.has(gid):
					group_ids_seen[gid] = true
					command_issued.emit(gid, cmd, world_pos.x, world_pos.y)
	elif _selected_group_id >= 0:
		command_issued.emit(_selected_group_id, cmd, world_pos.x, world_pos.y)

	var cmd_names := {
		BattleCommander.CommandType.ATTACK: "ATK MOVE",
		BattleCommander.CommandType.MOVE: "MOVE",
		BattleCommander.CommandType.HOLD: "HOLD",
		BattleCommander.CommandType.FOLLOW: "FOLLOW",
		BattleCommander.CommandType.SCATTER: "SCATTER",
		BattleCommander.CommandType.DEFENSIVE: "DEFEND",
		BattleCommander.CommandType.CHARGE: "CHARGE",
		BattleCommander.CommandType.RETREAT: "RETREAT",
	}
	var cmd_name: String = cmd_names.get(cmd, "CMD")
	var target_str := ""
	if world_pos != Vector2.ZERO:
		target_str = " -> (%d, %d)" % [int(world_pos.x), int(world_pos.y)]
	_instruction_label.text = "%s sent!%s" % [cmd_name, target_str]
	_refresh_group_list()

func _finish_box_selection(camera: Camera2D, viewport: Viewport) -> void:
	var world_tl := _screen_to_world(Vector2(_drag_rect.position.x, _drag_rect.position.y), camera, viewport)
	var world_br := _screen_to_world(Vector2(_drag_rect.end.x, _drag_rect.end.y), camera, viewport)
	var world_rect := Rect2(world_tl, world_br - world_tl).abs()
	var new_selection := PackedInt32Array()
	for i in _units.count:
		if _units.alive[i] == 0 or _units.faction[i] != BattleUnitSystem.Faction.BLUE:
			continue
		if world_rect.has_point(Vector2(_units.x[i], _units.y[i])):
			new_selection.append(i)
	if new_selection.size() > 0:
		# Check if all selected units share the same group
		var common_group := _units.group_id[new_selection[0]]
		var all_same := common_group >= 0
		for idx in new_selection:
			if _units.group_id[idx] != common_group:
				all_same = false
				break
		if all_same and _commander.get_group(common_group):
			# All in same group — just select that group, don't create new
			_selected_group_id = common_group
			_selected_units.clear()
			_instruction_label.text = "%d units (existing group)" % new_selection.size()
		else:
			# Mixed or ungrouped — store as loose selection, preserve original groups
			_selected_units = new_selection
			_selected_group_id = -1
			_instruction_label.text = "%d units selected. L-click: Atk Move" % new_selection.size()
		_refresh_group_list()
		_update_banners()
	# If nothing selected in box: keep current selection

func _screen_to_world(screen_pos: Vector2, camera: Camera2D, viewport: Viewport) -> Vector2:
	var viewport_size := viewport.get_visible_rect().size
	var cam_pos := camera.global_position
	var zoom := camera.zoom
	return cam_pos + (screen_pos - viewport_size * 0.5) / zoom

func _on_selection_draw() -> void:
	if _dragging and _drag_rect.size.length() > 0:
		_selection_draw.draw_rect(_drag_rect, Color(0.3, 1.0, 0.3, 0.3), true)
		_selection_draw.draw_rect(_drag_rect, Color(0.3, 1.0, 0.3, 0.8), false, 2.0)

func get_selected_units() -> PackedInt32Array:
	return _selected_units

func _on_zoom_pressed(zoom_level: float) -> void:
	zoom_requested.emit(zoom_level)

func update_banners() -> void:
	if not visible:
		return
	_update_banners()

func update_circles() -> void:
	## Call every frame to keep selection circles tracking unit positions.
	if not visible:
		return
	_update_selection_circles()
