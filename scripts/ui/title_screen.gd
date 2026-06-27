class_name TitleScreen
extends Control

# Two-phase UI: Phase 1 = slot selection, Phase 2 = class selection

enum Phase { SLOT_SELECT, CLASS_SELECT }

var _phase: Phase = Phase.SLOT_SELECT
var _pending_slot: int = -1  # slot waiting for class selection
var _selected_class: String = "warrior"
var _class_buttons: Dictionary = {}
var _container: VBoxContainer

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
	# If we came from death (active slot set, character dead), go straight to class select
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.active_slot >= 0 and gm.save_data and not gm.save_data.character_alive:
		_pending_slot = gm.active_slot
		_phase = Phase.CLASS_SELECT
	_build_ui()

func _build_ui() -> void:
	# Clear previous
	for c in get_children():
		c.queue_free()

	# Background — Ashfields theme bg_deep
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.059, 0.059, 0.102)
	add_child(bg)

	# Faint vignette overlay for depth
	var vignette = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0, 0, 0, 0.35)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	_container = VBoxContainer.new()
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.add_theme_constant_override("separation", 18)
	_container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_container)

	# Title — gold display in Press Start 2P, deep outline
	var title = Label.new()
	title.text = "ETERNAL CONQUESTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_s = LabelSettings.new()
	title_s.font = load("res://assets/fonts/PressStart2P-Regular.ttf")
	title_s.font_size = 48
	title_s.font_color = Color(0.918, 0.702, 0.031)
	title_s.outline_size = 6
	title_s.outline_color = Color(0.075, 0.067, 0.060)
	title_s.shadow_color = Color(0, 0, 0, 0.6)
	title_s.shadow_size = 2
	title_s.shadow_offset = Vector2(3, 4)
	title.label_settings = title_s
	_container.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Refugees of the Sundering"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub_s = LabelSettings.new()
	sub_s.font_size = 22
	sub_s.font_color = Color(0.659, 0.635, 0.616)
	subtitle.label_settings = sub_s
	_container.add_child(subtitle)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	_container.add_child(spacer)

	match _phase:
		Phase.SLOT_SELECT:
			_build_slot_select()
		Phase.CLASS_SELECT:
			_build_class_select()

# ============================================================
#  Phase 1 — Slot Selection
# ============================================================

func _build_slot_select() -> void:
	var header = Label.new()
	header.text = "SELECT WORLD"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hs = LabelSettings.new()
	hs.font_size = 22
	hs.font_color = Color(0.792, 0.541, 0.016)
	hs.outline_size = 2
	hs.outline_color = Color(0, 0, 0, 0.8)
	header.label_settings = hs
	_container.add_child(header)

	var slot_row = HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", 24)
	slot_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_container.add_child(slot_row)

	for slot in range(1, 4):
		var panel = _build_slot_panel(slot)
		slot_row.add_child(panel)

	var coop_panel = PanelContainer.new()
	var coop_style = StyleBoxFlat.new()
	coop_style.bg_color = Color(0.05, 0.08, 0.12)
	coop_style.border_color = Color(0.22, 0.4, 0.55)
	coop_style.set_border_width_all(2)
	coop_style.set_corner_radius_all(8)
	coop_style.content_margin_left = 18
	coop_style.content_margin_right = 18
	coop_style.content_margin_top = 12
	coop_style.content_margin_bottom = 12
	coop_panel.add_theme_stylebox_override("panel", coop_style)
	var coop_box = VBoxContainer.new()
	coop_box.add_theme_constant_override("separation", 6)
	coop_panel.add_child(coop_box)
	var coop_title = Label.new()
	coop_title.text = "Co-op Prototype"
	coop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coop_title.add_theme_font_size_override("font_size", 20)
	coop_title.add_theme_color_override("font_color", Color(0.72, 0.86, 1.0))
	coop_box.add_child(coop_title)
	var coop_desc = Label.new()
	coop_desc.text = "Host-authoritative ENet test path.\nLAN/direct IP now, with optional UPnP host setup for internet-host groundwork."
	coop_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coop_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coop_desc.add_theme_font_size_override("font_size", 14)
	coop_desc.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
	coop_box.add_child(coop_desc)
	_container.add_child(coop_panel)

func _build_slot_panel(slot: int) -> VBoxContainer:
	var gm = get_node_or_null("/root/GameManager")
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.custom_minimum_size = Vector2(320, 0)

	# Panel background — Ashfields theme bg_panel + warm border
	var panel_bg = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.110, 0.098, 0.090, 0.96)
	style.border_color = Color(0.471, 0.443, 0.420)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	panel_bg.add_theme_stylebox_override("panel", style)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	var data = gm.load_slot_preview(slot) if gm else null

	# Slot title — gold accent
	var slot_label = Label.new()
	slot_label.text = "World %d" % slot
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.add_theme_font_size_override("font_size", 22)
	slot_label.add_theme_color_override("font_color", Color(0.918, 0.702, 0.031))
	slot_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	slot_label.add_theme_constant_override("outline_size", 2)
	inner.add_child(slot_label)

	if data:
		# Show slot info
		var info = Label.new()
		if data.character_alive:
			var class_name_str = CLASS_DATA.get(data.selected_class, {}).get("name", data.selected_class)
			info.text = "%s  Lv.%d\nGold: %d  |  Best Floor: %d\nRuns: %d  |  Deaths: %d" % [
				class_name_str, data.player_level,
				data.gold, data.best_floor,
				data.total_runs, data.total_deaths
			]
		else:
			info.text = "Hero has fallen\nGold: %d  |  Best Floor: %d\nRuns: %d  |  Deaths: %d" % [
				data.gold, data.best_floor,
				data.total_runs, data.total_deaths
			]
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.add_theme_font_size_override("font_size", 16)
		info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		inner.add_child(info)

		# Buttons
		var btn_box = VBoxContainer.new()
		btn_box.add_theme_constant_override("separation", 6)

		if data.character_alive:
			var continue_btn = _make_btn("Continue", Color(0.2, 0.5, 0.2))
			continue_btn.pressed.connect(_on_continue.bind(slot))
			btn_box.add_child(continue_btn)

			var host_btn = _make_btn("Host Boss Arena", Color(0.15, 0.35, 0.55))
			host_btn.pressed.connect(_show_host_coop_dialog.bind(slot))
			btn_box.add_child(host_btn)

			var join_btn = _make_btn("Join Boss Arena", Color(0.2, 0.25, 0.45))
			join_btn.pressed.connect(_show_join_coop_dialog.bind(slot))
			btn_box.add_child(join_btn)
		else:
			var new_char_btn = _make_btn("Pick New Class", Color(0.4, 0.3, 0.1))
			new_char_btn.pressed.connect(_on_new_character.bind(slot))
			btn_box.add_child(new_char_btn)

		var delete_btn = _make_btn("Delete", Color(0.5, 0.1, 0.1))
		delete_btn.pressed.connect(_on_delete_slot.bind(slot))
		btn_box.add_child(delete_btn)

		inner.add_child(btn_box)
	else:
		# Empty slot
		var empty_lbl = Label.new()
		empty_lbl.text = "— Empty —"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 18)
		empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		inner.add_child(empty_lbl)

		var new_btn = _make_btn("New Game", Color(0.15, 0.3, 0.5))
		new_btn.pressed.connect(_on_new_game.bind(slot))
		inner.add_child(new_btn)

	panel_bg.add_child(inner)
	vbox.add_child(panel_bg)
	return vbox

func _make_btn(text: String, bg_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 40)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 18)
	btn.focus_mode = Control.FOCUS_NONE
	var sty = StyleBoxFlat.new()
	sty.bg_color = bg_color
	sty.border_color = bg_color.lightened(0.3)
	sty.set_border_width_all(1)
	sty.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", sty)
	var hover = sty.duplicate()
	hover.bg_color = bg_color.lightened(0.15)
	hover.border_color = bg_color.lightened(0.5)
	btn.add_theme_stylebox_override("hover", hover)
	return btn

# --- Slot actions ---

func _on_continue(slot: int) -> void:
	_play_click()
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.load_slot(slot)
		gm.return_to_overworld()

func _on_new_game(slot: int) -> void:
	_play_click()
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.create_new_world(slot)
	_pending_slot = slot
	_phase = Phase.CLASS_SELECT
	_build_ui()

func _on_new_character(slot: int) -> void:
	_play_click()
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.load_slot(slot)
	_pending_slot = slot
	_phase = Phase.CLASS_SELECT
	_build_ui()

func _on_delete_slot(slot: int) -> void:
	_play_click()
	# Show confirmation
	_show_delete_confirm(slot)

func _show_delete_confirm(slot: int) -> void:
	var overlay = ColorRect.new()
	overlay.name = "DeleteConfirm"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center = VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.add_theme_constant_override("separation", 16)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(center)

	var msg = Label.new()
	msg.text = "Delete World %d?\nAll progress will be lost!" % slot
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 24)
	msg.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	center.add_child(msg)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	center.add_child(btn_row)
	var gm = get_node_or_null("/root/GameManager")

	var yes_btn = _make_btn("Delete", Color(0.6, 0.1, 0.1))
	yes_btn.pressed.connect(func():
		if gm:
			gm.delete_slot(slot)
		overlay.queue_free()
		_build_ui()
	)
	btn_row.add_child(yes_btn)

	var no_btn = _make_btn("Cancel", Color(0.3, 0.3, 0.3))
	no_btn.pressed.connect(func():
		overlay.queue_free()
	)
	btn_row.add_child(no_btn)

func _show_join_coop_dialog(slot: int) -> void:
	_play_click()
	var overlay = ColorRect.new()
	overlay.name = "JoinCoopDialog"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.76)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center = VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.custom_minimum_size = Vector2(420, 0)
	center.add_theme_constant_override("separation", 12)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(center)

	var title = Label.new()
	title.text = "Join Boss Arena Prototype"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	center.add_child(title)

	var hint = Label.new()
	hint.text = "Use LAN IP on same Wi-Fi now. Public IP join is possible later if the host opens the port or UPnP succeeds."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.72, 0.74, 0.82))
	center.add_child(hint)

	var ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "Host IP address"
	ip_edit.custom_minimum_size = Vector2(360, 38)
	center.add_child(ip_edit)

	var port_edit = LineEdit.new()
	port_edit.placeholder_text = "Port"
	port_edit.text = "24567"
	port_edit.custom_minimum_size = Vector2(160, 38)
	center.add_child(port_edit)

	var error_label = Label.new()
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	center.add_child(error_label)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	center.add_child(btn_row)

	var join_btn = _make_btn("Join", Color(0.15, 0.35, 0.55))
	join_btn.pressed.connect(func():
		var address: String = ip_edit.text.strip_edges()
		var port: int = int(port_edit.text) if port_edit.text.is_valid_int() else 24567
		if address == "":
			error_label.text = "IP address is required."
			return
		var gm = get_node_or_null("/root/GameManager")
		if gm == null:
			error_label.text = "GameManager not found."
			return
		var err: Error = gm.join_coop_boss_arena(slot, address, port)
		if err != OK:
			error_label.text = "Join failed: %s" % error_string(err)
			return
		overlay.queue_free()
	)
	btn_row.add_child(join_btn)

	var cancel_btn = _make_btn("Cancel", Color(0.3, 0.3, 0.3))
	cancel_btn.pressed.connect(func(): overlay.queue_free())
	btn_row.add_child(cancel_btn)

func _on_host_boss_arena(slot: int) -> void:
	_play_click()
	var gm = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var result: Dictionary = gm.host_coop_boss_arena(slot)
	var err: Error = int(result.get("error", OK))
	if err != OK:
		_show_simple_modal("Host failed: %s" % error_string(err), Color(1.0, 0.45, 0.45))

func _show_host_coop_dialog(slot: int) -> void:
	_play_click()
	var overlay = ColorRect.new()
	overlay.name = "HostCoopDialog"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.76)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center = VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.custom_minimum_size = Vector2(460, 0)
	center.add_theme_constant_override("separation", 12)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(center)

	var title = Label.new()
	title.text = "Host Boss Arena Prototype"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	center.add_child(title)

	var hint = Label.new()
	hint.text = "LAN works first. Enable UPnP to attempt public internet hosting without manual router setup."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.72, 0.74, 0.82))
	center.add_child(hint)

	var port_edit = LineEdit.new()
	port_edit.placeholder_text = "Port"
	port_edit.text = "24567"
	port_edit.custom_minimum_size = Vector2(160, 38)
	center.add_child(port_edit)

	var upnp_toggle = CheckBox.new()
	upnp_toggle.text = "Try UPnP internet hosting"
	upnp_toggle.button_pressed = true
	center.add_child(upnp_toggle)

	var result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.custom_minimum_size = Vector2(400, 0)
	result_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9))
	center.add_child(result_label)

	var error_label = Label.new()
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	center.add_child(error_label)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	center.add_child(btn_row)

	var host_btn = _make_btn("Start Host", Color(0.15, 0.35, 0.55))
	host_btn.pressed.connect(func():
		var port: int = int(port_edit.text) if port_edit.text.is_valid_int() else 24567
		var gm = get_node_or_null("/root/GameManager")
		var coop = get_node_or_null("/root/CoopSession")
		if gm == null or coop == null:
			error_label.text = "Multiplayer systems not found."
			return
		var result: Dictionary = gm.host_coop_boss_arena(slot, port, 4, upnp_toggle.button_pressed)
		var err: Error = int(result.get("error", OK))
		if err != OK:
			error_label.text = "Host failed: %s" % error_string(err)
			return
		var net: Dictionary = coop.get_host_network_summary()
		var locals: PackedStringArray = net.get("local_addresses", PackedStringArray())
		var local_text: String = ", ".join(locals) if not locals.is_empty() else "none found"
		var external_text: String = str(net.get("external_address", ""))
		var upnp_ok: bool = bool(net.get("upnp_ok", false))
		var lines: Array[String] = []
		lines.append("LAN IPs: %s" % local_text)
		lines.append("Port: %d" % int(net.get("port", port)))
		if external_text != "":
			lines.append("Public IP: %s" % external_text)
		lines.append("UPnP: %s" % ("opened" if upnp_ok else "not opened"))
		result_label.text = "\n".join(lines)
		error_label.text = ""
	)
	btn_row.add_child(host_btn)

	var close_btn = _make_btn("Close", Color(0.3, 0.3, 0.3))
	close_btn.pressed.connect(func(): overlay.queue_free())
	btn_row.add_child(close_btn)

func _show_simple_modal(message: String, color: Color) -> void:
	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var center = VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.add_theme_constant_override("separation", 12)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(center)
	var msg = Label.new()
	msg.text = message
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", color)
	center.add_child(msg)
	var ok_btn = _make_btn("OK", Color(0.3, 0.3, 0.3))
	ok_btn.pressed.connect(func(): overlay.queue_free())
	center.add_child(ok_btn)

# ============================================================
#  Phase 2 — Class Selection
# ============================================================

func _build_class_select() -> void:
	var header = Label.new()
	header.text = "CHOOSE YOUR CLASS"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hs = LabelSettings.new()
	hs.font_size = 24
	hs.font_color = Color(0.8, 0.75, 0.6)
	header.label_settings = hs
	_container.add_child(header)

	# Class buttons in a horizontal row
	var class_row = HBoxContainer.new()
	class_row.alignment = BoxContainer.ALIGNMENT_CENTER
	class_row.add_theme_constant_override("separation", 16)
	class_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_container.add_child(class_row)

	_class_buttons.clear()
	for class_id in CLASS_DATA:
		var data = CLASS_DATA[class_id]
		var btn_vbox = _create_class_button(class_id, data)
		class_row.add_child(btn_vbox)

	_update_class_selection()

	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	_container.add_child(spacer2)

	# Button row
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	_container.add_child(btn_row)

	var start_btn = Button.new()
	start_btn.text = "Start Adventure"
	start_btn.custom_minimum_size = Vector2(300, 70)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.add_theme_font_size_override("font_size", 32)
	start_btn.pressed.connect(_on_class_confirmed)
	btn_row.add_child(start_btn)

	var back_btn = _make_btn("Back", Color(0.3, 0.3, 0.3))
	back_btn.custom_minimum_size.y = 70
	back_btn.pressed.connect(func():
		_play_click()
		_phase = Phase.SLOT_SELECT
		_build_ui()
	)
	btn_row.add_child(back_btn)

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
	_play_click()

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

func _on_class_confirmed() -> void:
	_play_click()
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return
	gm.start_new_character(_selected_class)
	# Show loading then route: first-time chars take the tutorial; others go to overworld.
	var loading = Label.new()
	loading.text = "Tutorial..." if (gm.save_data and not gm.save_data.tutorial_completed) else "Loading world..."
	loading.set_anchors_preset(Control.PRESET_CENTER)
	loading.add_theme_font_size_override("font_size", 24)
	loading.add_theme_color_override("font_color", Color.WHITE)
	add_child(loading)
	await get_tree().process_frame
	await get_tree().process_frame
	if gm.save_data and not gm.save_data.tutorial_completed:
		gm.start_tutorial()
	else:
		gm.return_to_overworld()

func _play_click() -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click", -3.0)
