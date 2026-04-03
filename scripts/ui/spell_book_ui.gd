class_name SpellBookUI
extends CanvasLayer

var _panel: PanelContainer
var _is_open: bool = false
var _slot_panels: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _spell_list_container: VBoxContainer
var _keybind_names = ["RMB", "R", "F", "T", "G", "V"]

func _ready() -> void:
	layer = 100
	add_to_group("spellbook_ui")
	visible = false

	# Dimmer
	var dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.7)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(600, 450)
	_panel.position = Vector2(-300, -225)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.15)
	style.border_color = Color(0.3, 0.4, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(main_vbox)

	# Title
	var title = Label.new()
	title.text = "Spell Book"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.6, 0.7, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	# Slots row
	var slots_label = Label.new()
	slots_label.text = "Spell Slots:"
	slots_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.9))
	main_vbox.add_child(slots_label)

	var slots_row = HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 8)
	main_vbox.add_child(slots_row)

	for i in range(SpellBook.MAX_SPELL_SLOTS):
		var slot_panel = PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(130, 70)
		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.12, 0.12, 0.2)
		slot_style.border_color = Color(0.4, 0.4, 0.6)
		slot_style.set_border_width_all(1)
		slot_style.set_corner_radius_all(4)
		slot_panel.add_theme_stylebox_override("panel", slot_style)
		slots_row.add_child(slot_panel)
		_slot_panels.append(slot_panel)

		var slot_vbox = VBoxContainer.new()
		slot_vbox.add_theme_constant_override("separation", 2)
		slot_panel.add_child(slot_vbox)

		var keybind = Label.new()
		keybind.text = "[%s]" % _keybind_names[i]
		keybind.add_theme_font_size_override("font_size", 10)
		keybind.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7))
		keybind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_vbox.add_child(keybind)

		var spell_label = Label.new()
		spell_label.text = "Empty"
		spell_label.add_theme_font_size_override("font_size", 12)
		spell_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		spell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_vbox.add_child(spell_label)
		_slot_labels.append(spell_label)

		var unequip_btn = Button.new()
		unequip_btn.text = "Unequip"
		unequip_btn.add_theme_font_size_override("font_size", 10)
		unequip_btn.pressed.connect(_on_unequip.bind(i))
		slot_vbox.add_child(unequip_btn)

	# Learned spells section
	var learned_label = Label.new()
	learned_label.text = "Learned Spells:"
	learned_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.9))
	main_vbox.add_child(learned_label)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.y = 200
	main_vbox.add_child(scroll)

	_spell_list_container = VBoxContainer.new()
	_spell_list_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_spell_list_container)

	# Close
	var bottom = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	main_vbox.add_child(bottom)
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(80, 30)
	close_btn.pressed.connect(close)
	bottom.add_child(close_btn)

func open() -> void:
	visible = true
	_is_open = true
	_refresh()
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("paper", -4.0, 0.0)

func close() -> void:
	visible = false
	_is_open = false
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("close", -4.0, 0.0)

func is_open() -> bool:
	return _is_open

func _refresh() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var sb = player.get_node_or_null("SpellBook") as SpellBook
	if not sb:
		return

	var level = 1
	var spirit = 0
	var ls = player.get_node_or_null("LevelSystem") as LevelSystem
	if ls:
		level = ls.level
		spirit = ls.allocated.get("spirit", 0)
	var max_slots = sb.get_max_slots(level, spirit)

	# Update slot displays
	for i in range(SpellBook.MAX_SPELL_SLOTS):
		if i >= max_slots:
			_slot_labels[i].text = _get_unlock_text(i)
			_slot_labels[i].add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		elif sb.spell_slots[i]:
			_slot_labels[i].text = sb.spell_slots[i].spell_name
			_slot_labels[i].add_theme_color_override("font_color", Color(0.9, 0.8, 1.0))
		else:
			_slot_labels[i].text = "Empty"
			_slot_labels[i].add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

	# Rebuild learned spells list
	for child in _spell_list_container.get_children():
		child.queue_free()

	for spell in sb.learned_spells:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var name_label = Label.new()
		name_label.text = spell.spell_name
		name_label.custom_minimum_size.x = 150
		name_label.add_theme_font_size_override("font_size", 12)
		row.add_child(name_label)

		var info_label = Label.new()
		var eff = SpellDefinition.effect_name(spell.effect_type)
		var del = SpellDefinition.delivery_name(spell.delivery)
		info_label.text = "%s %s | MP:%.0f CD:%.1fs" % [eff, del, spell.mp_cost, spell.cooldown]
		info_label.add_theme_font_size_override("font_size", 11)
		info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		row.add_child(info_label)

		# Equip buttons for each available slot
		for slot_i in range(max_slots):
			var equip_btn = Button.new()
			equip_btn.text = "Slot %d" % (slot_i + 1)
			equip_btn.add_theme_font_size_override("font_size", 10)
			equip_btn.custom_minimum_size = Vector2(50, 24)
			equip_btn.pressed.connect(_on_equip.bind(spell, slot_i))
			row.add_child(equip_btn)

		_spell_list_container.add_child(row)

func _get_unlock_text(slot: int) -> String:
	if slot < SpellBook.SPIRIT_THRESHOLDS.size():
		return "Locked (Spirit %d)" % SpellBook.SPIRIT_THRESHOLDS[slot]
	return "Locked"

func _on_equip(spell: SpellDefinition, slot: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var sb = player.get_node_or_null("SpellBook") as SpellBook
	if sb:
		sb.equip_spell(spell, slot)
		_refresh()
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("select_a", -4.0)

func _on_unequip(slot: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var sb = player.get_node_or_null("SpellBook") as SpellBook
	if sb:
		sb.unequip_spell(slot)
		_refresh()
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("click", -5.0)

func _unhandled_input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
