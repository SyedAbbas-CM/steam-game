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

	# Background
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.08)
	add_child(bg)

	_container = VBoxContainer.new()
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.add_theme_constant_override("separation", 20)
	_container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_container)

	# Title
	var title = Label.new()
	title.text = "DUNGEON CRAWL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_s = LabelSettings.new()
	title_s.font_size = 72
	title_s.font_color = Color(0.9, 0.8, 0.3)
	title_s.outline_size = 4
	title_s.outline_color = Color(0.3, 0.2, 0.0)
	title.label_settings = title_s
	_container.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "A Roguelike Adventure"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub_s = LabelSettings.new()
	sub_s.font_size = 28
	sub_s.font_color = Color(0.6, 0.6, 0.7)
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
	hs.font_size = 24
	hs.font_color = Color(0.8, 0.75, 0.6)
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

func _build_slot_panel(slot: int) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.custom_minimum_size = Vector2(320, 0)

	# Panel background
	var panel_bg = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.12)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel_bg.add_theme_stylebox_override("panel", style)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)

	# Slot title
	var slot_label = Label.new()
	slot_label.text = "World %d" % slot
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.add_theme_font_size_override("font_size", 22)
	slot_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	inner.add_child(slot_label)

	var data = SaveData.load_slot(slot)

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

	var yes_btn = _make_btn("Delete", Color(0.6, 0.1, 0.1))
	yes_btn.pressed.connect(func():
		var gm = get_node_or_null("/root/GameManager")
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
	stats_lbl.text = "HP:%d SPD:%d DMG:%s" % [data["hp"], data["spd"], data["dmg"]]
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
	# Show loading then go to overworld
	var loading = Label.new()
	loading.text = "Loading world..."
	loading.set_anchors_preset(Control.PRESET_CENTER)
	loading.add_theme_font_size_override("font_size", 24)
	loading.add_theme_color_override("font_color", Color.WHITE)
	add_child(loading)
	await get_tree().process_frame
	await get_tree().process_frame
	gm.return_to_overworld()

func _play_click() -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click", -3.0)
