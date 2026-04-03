extends CanvasLayer

## Territory and diplomacy panel — Spore-style RTS overview.
## Shows zone ownership, faction relations, attack/defend options.
## Opened with M key from overworld.

signal attack_zone(zone_id: String)
signal travel_to_zone(zone_id: String)
signal closed

var _overlay: ColorRect
var _panel: PanelContainer
var _zone_list: VBoxContainer
var _detail_panel: VBoxContainer
var _faction_list: VBoxContainer
var _selected_zone: String = ""
var _close_btn: Button

# Detail panel labels
var _detail_name: Label
var _detail_owner: Label
var _detail_neighbors: Label
var _detail_action_btn: Button
var _detail_action_btn2: Button

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Dark overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# Main panel — centered on 1920x1080
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(900, 600)
	_panel.position = Vector2((1920 - 900) / 2.0, (1080 - 600) / 2.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.1, 0.95)
	style.border_color = Color(0.5, 0.4, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(main_vbox)

	# Title bar
	var title_row := HBoxContainer.new()
	main_vbox.add_child(title_row)
	var title := Label.new()
	title.text = "TERRITORY & DIPLOMACY"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ts := LabelSettings.new()
	ts.font_size = 22
	ts.font_color = Color(0.9, 0.8, 0.5)
	ts.outline_size = 2
	ts.outline_color = Color(0, 0, 0)
	title.label_settings = ts
	title_row.add_child(title)

	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.custom_minimum_size = Vector2(36, 36)
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.add_theme_font_size_override("font_size", 18)
	_close_btn.pressed.connect(_on_close)
	title_row.add_child(_close_btn)

	# Content: left zone list + right detail
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content)

	# Left: zone list in scroll container
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(400, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color(0.08, 0.07, 0.12, 0.8)
	left_style.set_corner_radius_all(4)
	left_style.set_content_margin_all(4)
	left_panel.add_theme_stylebox_override("panel", left_style)
	content.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_panel.add_child(left_vbox)

	var zone_header := Label.new()
	zone_header.text = "Territories"
	zone_header.add_theme_font_size_override("font_size", 16)
	zone_header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	zone_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(zone_header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(380, 350)
	left_vbox.add_child(scroll)

	_zone_list = VBoxContainer.new()
	_zone_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_zone_list)

	# Right: detail panel
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var right_style := StyleBoxFlat.new()
	right_style.bg_color = Color(0.08, 0.07, 0.12, 0.8)
	right_style.set_corner_radius_all(4)
	right_style.set_content_margin_all(8)
	right_panel.add_theme_stylebox_override("panel", right_style)
	content.add_child(right_panel)

	_detail_panel = VBoxContainer.new()
	_detail_panel.add_theme_constant_override("separation", 8)
	right_panel.add_child(_detail_panel)

	_detail_name = Label.new()
	_detail_name.text = "Select a zone"
	var dn_s := LabelSettings.new()
	dn_s.font_size = 20
	dn_s.font_color = Color(0.9, 0.85, 0.7)
	_detail_name.label_settings = dn_s
	_detail_panel.add_child(_detail_name)

	_detail_owner = Label.new()
	_detail_owner.text = ""
	_detail_owner.add_theme_font_size_override("font_size", 15)
	_detail_panel.add_child(_detail_owner)

	_detail_neighbors = Label.new()
	_detail_neighbors.text = ""
	_detail_neighbors.add_theme_font_size_override("font_size", 13)
	_detail_neighbors.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_detail_neighbors.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_panel.add_child(_detail_neighbors)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(spacer)

	# Action buttons
	_detail_action_btn = Button.new()
	_detail_action_btn.text = ""
	_detail_action_btn.visible = false
	_detail_action_btn.focus_mode = Control.FOCUS_NONE
	_detail_action_btn.add_theme_font_size_override("font_size", 16)
	var atk_style := StyleBoxFlat.new()
	atk_style.bg_color = Color(0.5, 0.2, 0.2, 0.9)
	atk_style.border_color = Color(0.7, 0.3, 0.3)
	atk_style.set_border_width_all(1)
	atk_style.set_corner_radius_all(4)
	_detail_action_btn.add_theme_stylebox_override("normal", atk_style)
	_detail_action_btn.pressed.connect(_on_action_btn)
	_detail_panel.add_child(_detail_action_btn)

	_detail_action_btn2 = Button.new()
	_detail_action_btn2.text = ""
	_detail_action_btn2.visible = false
	_detail_action_btn2.focus_mode = Control.FOCUS_NONE
	_detail_action_btn2.add_theme_font_size_override("font_size", 14)
	_detail_panel.add_child(_detail_action_btn2)

	# Bottom: faction relations
	main_vbox.add_child(HSeparator.new())
	var fac_header := Label.new()
	fac_header.text = "Faction Relations"
	fac_header.add_theme_font_size_override("font_size", 14)
	fac_header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	fac_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(fac_header)

	_faction_list = VBoxContainer.new()
	_faction_list.add_theme_constant_override("separation", 2)
	main_vbox.add_child(_faction_list)

	_refresh()

func _refresh() -> void:
	_build_zone_list()
	_build_faction_list()
	_update_detail()

func _build_zone_list() -> void:
	for child in _zone_list.get_children():
		child.queue_free()

	var fm = get_node_or_null("/root/FactionManager")
	if not fm:
		return

	# Gather all zones from territory_owners + connections
	var all_zones: Dictionary = {}  # zone_id -> true
	for z in fm.territory_owners:
		all_zones[z] = true
	for z in fm.territory_owners:
		for n in fm.get_zone_neighbors(z):
			all_zones[n] = true

	# Sort zones: player first, then enemy, then neutral
	var player_zones := []
	var enemy_zones := []
	var neutral_zones := []
	for z in all_zones:
		var owner: String = fm.get_zone_owner(z)
		if owner == "player":
			player_zones.append(z)
		elif owner != "":
			enemy_zones.append(z)
		else:
			neutral_zones.append(z)
	player_zones.sort()
	enemy_zones.sort()
	neutral_zones.sort()

	# Section: Player
	if not player_zones.is_empty():
		_add_section_header("YOUR TERRITORIES", Color(0.3, 0.8, 0.3))
		for z in player_zones:
			_add_zone_row(z, fm)

	# Section: Enemy
	if not enemy_zones.is_empty():
		_add_section_header("ENEMY TERRITORIES", Color(0.8, 0.3, 0.3))
		for z in enemy_zones:
			_add_zone_row(z, fm)

	# Section: Neutral (limit to relevant ones)
	if not neutral_zones.is_empty():
		_add_section_header("NEUTRAL ZONES", Color(0.5, 0.5, 0.5))
		for z in neutral_zones:
			_add_zone_row(z, fm)

func _add_section_header(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
	_zone_list.add_child(lbl)

func _add_zone_row(zone_id: String, fm) -> void:
	var btn := Button.new()
	var owner: String = fm.get_zone_owner(zone_id)
	var owner_name: String = fm.get_owner_display_name(owner)
	var color: Color = fm.get_owner_color(owner)

	# Try to get zone display name
	var display_name := zone_id.capitalize()
	var zone_path := "res://resources/world/zones/%s.tres" % zone_id
	if ResourceLoader.exists(zone_path):
		var zd = load(zone_path)
		if zd and zd is LoyZoneData and zd.zone_name != "":
			display_name = zd.zone_name

	btn.text = "%s  —  %s" % [display_name, owner_name]
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", color)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if zone_id == _selected_zone:
		var sel_style := StyleBoxFlat.new()
		sel_style.bg_color = Color(0.2, 0.2, 0.35, 0.8)
		sel_style.set_corner_radius_all(2)
		btn.add_theme_stylebox_override("normal", sel_style)

	btn.pressed.connect(_on_zone_selected.bind(zone_id))
	_zone_list.add_child(btn)

func _build_faction_list() -> void:
	for child in _faction_list.get_children():
		child.queue_free()

	var fm = get_node_or_null("/root/FactionManager")
	if not fm:
		return

	for fac_id in fm.factions:
		var fac: Dictionary = fm.factions[fac_id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		# Color dot
		var dot := ColorRect.new()
		dot.color = fac.get("color", Color.WHITE)
		dot.custom_minimum_size = Vector2(12, 12)
		row.add_child(dot)

		# Name
		var name_lbl := Label.new()
		name_lbl.text = str(fac.get("name", fac_id))
		name_lbl.custom_minimum_size = Vector2(200, 0)
		name_lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(name_lbl)

		# Attitude bar background
		var bar_bg := ColorRect.new()
		bar_bg.color = Color(0.15, 0.15, 0.2)
		bar_bg.custom_minimum_size = Vector2(200, 16)
		row.add_child(bar_bg)

		# Attitude bar fill
		var att: int = int(fac.get("attitude", 0))
		var bar_fill := ColorRect.new()
		var att_color: Color = fm.get_attitude_color(att)
		bar_fill.color = att_color
		# Map -100..100 to 0..200 width
		var fill_w := maxf(2.0, (float(att + 100) / 200.0) * 200.0)
		bar_fill.custom_minimum_size = Vector2(fill_w, 16)
		bar_fill.position = Vector2.ZERO
		bar_bg.add_child(bar_fill)

		# Attitude label
		var att_lbl := Label.new()
		att_lbl.text = "%s (%d)" % [fm.get_attitude_label(att), att]
		att_lbl.add_theme_font_size_override("font_size", 12)
		att_lbl.add_theme_color_override("font_color", att_color)
		row.add_child(att_lbl)

		_faction_list.add_child(row)

func _on_zone_selected(zone_id: String) -> void:
	_selected_zone = zone_id
	_build_zone_list()
	_update_detail()

func _update_detail() -> void:
	if _selected_zone == "":
		_detail_name.text = "Select a zone"
		_detail_owner.text = ""
		_detail_neighbors.text = ""
		_detail_action_btn.visible = false
		_detail_action_btn2.visible = false
		return

	var fm = get_node_or_null("/root/FactionManager")
	if not fm:
		return

	# Zone name
	var display_name := _selected_zone.capitalize()
	var zone_path := "res://resources/world/zones/%s.tres" % _selected_zone
	if ResourceLoader.exists(zone_path):
		var zd = load(zone_path)
		if zd and zd is LoyZoneData and zd.zone_name != "":
			display_name = zd.zone_name

	_detail_name.text = display_name

	# Owner
	var owner: String = fm.get_zone_owner(_selected_zone)
	var owner_name: String = fm.get_owner_display_name(owner)
	var owner_color: Color = fm.get_owner_color(owner)
	_detail_owner.text = "Owner: %s" % owner_name
	_detail_owner.add_theme_color_override("font_color", owner_color)

	# Neighbors
	var neighbors: Array = fm.get_zone_neighbors(_selected_zone)
	var neighbor_strs := []
	for n in neighbors:
		var n_owner: String = fm.get_zone_owner(n)
		var n_name: String = fm.get_owner_display_name(n_owner)
		neighbor_strs.append("%s (%s)" % [n.capitalize(), n_name])
	_detail_neighbors.text = "Neighbors: %s" % (", ".join(neighbor_strs) if not neighbor_strs.is_empty() else "None")

	# Action buttons — reset state
	_detail_action_btn.visible = false
	_detail_action_btn2.visible = false
	if _detail_action_btn2.pressed.is_connected(_on_travel_btn):
		_detail_action_btn2.pressed.disconnect(_on_travel_btn)

	if owner == "player":
		# Player zone — travel button (can't travel to zone you're already in)
		var ow = get_node_or_null("/root/Overworld")
		if not ow:
			# Get current zone from overworld node in tree
			ow = get_tree().get_first_node_in_group("overworld")
		var current_zone_id := ""
		if ow and ow.has_method("get_current_zone_id"):
			current_zone_id = ow.get_current_zone_id()
		if _selected_zone != current_zone_id:
			_detail_action_btn2.text = "TRAVEL TO %s" % display_name.to_upper()
			_detail_action_btn2.visible = true
			# Restyle as travel button (blue)
			var travel_style := StyleBoxFlat.new()
			travel_style.bg_color = Color(0.15, 0.25, 0.5, 0.9)
			travel_style.border_color = Color(0.3, 0.5, 0.8)
			travel_style.set_border_width_all(1)
			travel_style.set_corner_radius_all(4)
			_detail_action_btn2.add_theme_stylebox_override("normal", travel_style)
			if not _detail_action_btn2.pressed.is_connected(_on_travel_btn):
				_detail_action_btn2.pressed.connect(_on_travel_btn)
	elif owner != "":
		# Enemy zone — can attack if adjacent to player zone
		var player_zones: Array = fm.get_player_zones()
		var can_attack := false
		for n in neighbors:
			if n in player_zones:
				can_attack = true
				break
		if can_attack:
			_detail_action_btn.text = "ATTACK %s" % display_name.to_upper()
			_detail_action_btn.visible = true

func _on_action_btn() -> void:
	if _selected_zone != "":
		attack_zone.emit(_selected_zone)
		_on_close()

func _on_travel_btn() -> void:
	if _selected_zone != "":
		travel_to_zone.emit(_selected_zone)
		_on_close()

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
