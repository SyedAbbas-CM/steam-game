class_name SpellCraftUI
extends CanvasLayer

var _panel: PanelContainer
var _is_open: bool = false

# Pickers
var _effect_buttons: Array[Button] = []
var _delivery_buttons: Array[Button] = []
var _magnitude_slider: HSlider
var _duration_slider: HSlider
var _bullet_slider: HSlider
var _behavior_option: OptionButton
var _name_edit: LineEdit

# Preview labels
var _cost_label: Label
var _mp_label: Label
var _cd_label: Label
var _desc_label: Label

# State
var _selected_effect: SpellDefinition.EffectType = SpellDefinition.EffectType.FIRE_DAMAGE
var _selected_delivery: SpellDefinition.DeliveryType = SpellDefinition.DeliveryType.PROJECTILE

# Bullet row references for visibility toggling
var _bullet_row: HBoxContainer
var _behavior_row: HBoxContainer

const DELIVERY_MULTS = {
	SpellDefinition.DeliveryType.PROJECTILE: 1.0,
	SpellDefinition.DeliveryType.NOVA: 1.3,
	SpellDefinition.DeliveryType.SELF: 0.8,
	SpellDefinition.DeliveryType.TOUCH: 1.1,
}

func _ready() -> void:
	layer = 100
	add_to_group("spell_craft_ui")
	visible = false

	# Dimmer
	var dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.7)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(700, 500)
	_panel.position = Vector2(-350, -250)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.18)
	style.border_color = Color(0.6, 0.3, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(main_vbox)

	# Title
	var title = Label.new()
	title.text = "Spell Crafting"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	var content = HBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	main_vbox.add_child(content)

	# LEFT side: pickers
	var left = VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.custom_minimum_size.x = 380
	content.add_child(left)

	# Effect type
	var effect_label = Label.new()
	effect_label.text = "Effect:"
	effect_label.add_theme_color_override("font_color", Color(0.7, 0.5, 0.9))
	left.add_child(effect_label)

	var effect_grid = GridContainer.new()
	effect_grid.columns = 5
	effect_grid.add_theme_constant_override("h_separation", 4)
	effect_grid.add_theme_constant_override("v_separation", 4)
	left.add_child(effect_grid)

	for i in range(10):
		var btn = Button.new()
		btn.text = SpellDefinition.effect_name(i as SpellDefinition.EffectType)
		btn.custom_minimum_size = Vector2(70, 28)
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_on_effect_selected.bind(i))
		effect_grid.add_child(btn)
		_effect_buttons.append(btn)

	# Delivery type
	var delivery_label = Label.new()
	delivery_label.text = "Delivery:"
	delivery_label.add_theme_color_override("font_color", Color(0.7, 0.5, 0.9))
	left.add_child(delivery_label)

	var delivery_row = HBoxContainer.new()
	delivery_row.add_theme_constant_override("separation", 4)
	left.add_child(delivery_row)

	for i in range(4):
		var btn = Button.new()
		btn.text = SpellDefinition.delivery_name(i as SpellDefinition.DeliveryType)
		btn.custom_minimum_size = Vector2(80, 28)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_delivery_selected.bind(i))
		delivery_row.add_child(btn)
		_delivery_buttons.append(btn)

	# Magnitude slider
	var mag_row = HBoxContainer.new()
	var mag_label = Label.new()
	mag_label.text = "Magnitude:"
	mag_label.custom_minimum_size.x = 80
	mag_row.add_child(mag_label)
	_magnitude_slider = HSlider.new()
	_magnitude_slider.min_value = 1
	_magnitude_slider.max_value = 50
	_magnitude_slider.value = 10
	_magnitude_slider.custom_minimum_size.x = 200
	_magnitude_slider.value_changed.connect(_on_slider_changed)
	mag_row.add_child(_magnitude_slider)
	var mag_val = Label.new()
	mag_val.name = "MagValue"
	mag_val.text = "10"
	mag_row.add_child(mag_val)
	left.add_child(mag_row)

	# Duration slider
	var dur_row = HBoxContainer.new()
	var dur_label = Label.new()
	dur_label.text = "Duration:"
	dur_label.custom_minimum_size.x = 80
	dur_row.add_child(dur_label)
	_duration_slider = HSlider.new()
	_duration_slider.min_value = 0
	_duration_slider.max_value = 10
	_duration_slider.step = 0.5
	_duration_slider.value = 0
	_duration_slider.custom_minimum_size.x = 200
	_duration_slider.value_changed.connect(_on_slider_changed)
	dur_row.add_child(_duration_slider)
	var dur_val = Label.new()
	dur_val.name = "DurValue"
	dur_val.text = "0.0"
	dur_row.add_child(dur_val)
	left.add_child(dur_row)

	# Bullet count (PROJECTILE only)
	_bullet_row = HBoxContainer.new()
	var bul_label = Label.new()
	bul_label.text = "Bullets:"
	bul_label.custom_minimum_size.x = 80
	_bullet_row.add_child(bul_label)
	_bullet_slider = HSlider.new()
	_bullet_slider.min_value = 1
	_bullet_slider.max_value = 12
	_bullet_slider.value = 1
	_bullet_slider.custom_minimum_size.x = 200
	_bullet_slider.value_changed.connect(_on_slider_changed)
	_bullet_row.add_child(_bullet_slider)
	var bul_val = Label.new()
	bul_val.name = "BulValue"
	bul_val.text = "1"
	_bullet_row.add_child(bul_val)
	left.add_child(_bullet_row)

	# Behavior (PROJECTILE only)
	_behavior_row = HBoxContainer.new()
	var beh_label = Label.new()
	beh_label.text = "Behavior:"
	beh_label.custom_minimum_size.x = 80
	_behavior_row.add_child(beh_label)
	_behavior_option = OptionButton.new()
	_behavior_option.add_item("Straight", 0)
	_behavior_option.add_item("Homing", 1)
	_behavior_option.add_item("Spread", 2)
	_behavior_option.item_selected.connect(func(_i): _update_preview())
	_behavior_row.add_child(_behavior_option)
	left.add_child(_behavior_row)

	# RIGHT side: preview
	var right = VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size.x = 250
	content.add_child(right)

	var preview_title = Label.new()
	preview_title.text = "Spell Preview"
	preview_title.add_theme_font_size_override("font_size", 16)
	preview_title.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
	right.add_child(preview_title)

	# Name edit
	var name_row = HBoxContainer.new()
	var name_label = Label.new()
	name_label.text = "Name: "
	name_row.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.text = "Fire Bolt"
	_name_edit.custom_minimum_size.x = 160
	name_row.add_child(_name_edit)
	right.add_child(name_row)

	_desc_label = Label.new()
	_desc_label.text = ""
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	right.add_child(_desc_label)

	_mp_label = Label.new()
	_mp_label.text = "MP Cost: 10"
	_mp_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	right.add_child(_mp_label)

	_cd_label = Label.new()
	_cd_label.text = "Cooldown: 5.0s"
	_cd_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	right.add_child(_cd_label)

	_cost_label = Label.new()
	_cost_label.text = "Gold: 50"
	_cost_label.add_theme_font_size_override("font_size", 18)
	_cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	right.add_child(_cost_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 10
	right.add_child(spacer)

	# Create button
	var create_btn = Button.new()
	create_btn.text = "Create Spell"
	create_btn.custom_minimum_size = Vector2(180, 40)
	create_btn.add_theme_font_size_override("font_size", 16)
	create_btn.pressed.connect(_on_create_pressed)
	right.add_child(create_btn)

	# Bottom row: Manage Spells (opens inventory SPELLS tab) + Close
	var bottom = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 10)
	main_vbox.add_child(bottom)

	var manage_btn = Button.new()
	manage_btn.text = "Manage Spells"
	manage_btn.custom_minimum_size = Vector2(180, 40)
	manage_btn.add_theme_font_size_override("font_size", 18)
	manage_btn.pressed.connect(_open_spell_management)
	bottom.add_child(manage_btn)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 40)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(close)
	bottom.add_child(close_btn)

	_update_effect_highlights()
	_update_delivery_highlights()
	_update_preview()

func open() -> void:
	visible = true
	_is_open = true
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("open", -3.0, 0.0)

func close() -> void:
	visible = false
	_is_open = false
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("close", -4.0, 0.0)

func is_open() -> bool:
	return _is_open

## Open the player's SPELLS inventory tab (spell-equipping flow lives there).
## Closes this UI so the two screens don't stack on top of each other.
func _open_spell_management() -> void:
	close()
	var inv = get_tree().get_first_node_in_group("inventory_screen") as InventoryScreen
	if not inv:
		var inv_scene = load("res://scenes/ui/inventory_screen.tscn") as PackedScene
		if inv_scene:
			inv = inv_scene.instantiate() as InventoryScreen
			get_tree().current_scene.add_child(inv)
	# Spells appear inline in the items grid now, so just open the inventory.
	if inv:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var em = player.get_node_or_null("EquipmentManager") as EquipmentManager
			if em:
				inv.setup(em)
		if inv.has_method("toggle"):
			if inv.has_method("is_open") and not inv.is_open():
				inv.toggle()

func _on_effect_selected(idx: int) -> void:
	_selected_effect = idx as SpellDefinition.EffectType
	# If self-only effect selected, force SELF delivery
	if SpellDefinition.is_self_only_effect(_selected_effect):
		_selected_delivery = SpellDefinition.DeliveryType.SELF
		_update_delivery_highlights()
	_update_effect_highlights()
	_update_preview()

func _on_delivery_selected(idx: int) -> void:
	# Block non-SELF delivery for self-only effects
	if SpellDefinition.is_self_only_effect(_selected_effect) and idx != SpellDefinition.DeliveryType.SELF:
		return
	_selected_delivery = idx as SpellDefinition.DeliveryType
	_update_delivery_highlights()
	_update_preview()

func _on_slider_changed(_val: float) -> void:
	# Update value labels
	var mag_val = _magnitude_slider.get_parent().get_node("MagValue") as Label
	if mag_val:
		mag_val.text = str(int(_magnitude_slider.value))
	var dur_val = _duration_slider.get_parent().get_node("DurValue") as Label
	if dur_val:
		dur_val.text = "%.1f" % _duration_slider.value
	var bul_val = _bullet_slider.get_parent().get_node("BulValue") as Label
	if bul_val:
		bul_val.text = str(int(_bullet_slider.value))
	_update_preview()

func _update_effect_highlights() -> void:
	for i in range(_effect_buttons.size()):
		var btn = _effect_buttons[i]
		if i == int(_selected_effect):
			btn.modulate = Color(1.2, 0.8, 1.5)
		else:
			btn.modulate = Color.WHITE

func _update_delivery_highlights() -> void:
	for i in range(_delivery_buttons.size()):
		var btn = _delivery_buttons[i]
		if i == int(_selected_delivery):
			btn.modulate = Color(1.2, 0.8, 1.5)
		else:
			btn.modulate = Color.WHITE
	# Show/hide projectile-only rows
	var is_proj = _selected_delivery == SpellDefinition.DeliveryType.PROJECTILE
	_bullet_row.visible = is_proj
	_behavior_row.visible = is_proj

func _update_preview() -> void:
	var mag = int(_magnitude_slider.value)
	var dur = _duration_slider.value
	var bullets = int(_bullet_slider.value) if _selected_delivery == SpellDefinition.DeliveryType.PROJECTILE else 1
	var delivery_mult = DELIVERY_MULTS.get(_selected_delivery, 1.0)
	var behavior_name = ["Straight", "Homing", "Spread"][_behavior_option.selected]

	# Gold cost
	var gold = 50.0 * (1.0 + (mag - 1) * 0.15) * (1.0 + dur * 0.3) * delivery_mult * (1.0 + (bullets - 1) * 0.3)

	# MP cost
	var mp = (3.0 + mag * 0.2 + dur * 0.5 + (bullets - 1) * 0.8) * delivery_mult

	# Cooldown
	var cd = clampf((3.0 + mag * 0.06 + dur * 0.2) * delivery_mult, 2.0, 15.0)

	_cost_label.text = "Gold: %d" % int(gold)
	_mp_label.text = "MP Cost: %.1f" % mp
	_cd_label.text = "Cooldown: %.1fs" % cd

	var effect_name = SpellDefinition.effect_name(_selected_effect)
	var delivery_name = SpellDefinition.delivery_name(_selected_delivery)
	var desc = "%s %s — Magnitude %d" % [effect_name, delivery_name, mag]
	if dur > 0:
		var status_name = _get_status_name(_selected_effect)
		if status_name != "":
			desc += ", %s %.1fs" % [status_name, dur]
		else:
			desc += ", Duration %.1fs" % dur
	if bullets > 1:
		desc += ", %d %s projectiles" % [bullets, behavior_name]
	elif _selected_delivery == SpellDefinition.DeliveryType.PROJECTILE:
		if behavior_name != "Straight":
			desc += ", %s" % behavior_name
	_desc_label.text = desc

func _on_create_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return

	var mag = int(_magnitude_slider.value)
	var dur = _duration_slider.value
	var bullets = int(_bullet_slider.value) if _selected_delivery == SpellDefinition.DeliveryType.PROJECTILE else 1
	var delivery_mult = DELIVERY_MULTS.get(_selected_delivery, 1.0)

	var gold_cost = int(50.0 * (1.0 + (mag - 1) * 0.15) * (1.0 + dur * 0.3) * delivery_mult * (1.0 + (bullets - 1) * 0.3))

	if not gm.spend_gold(gold_cost):
		# Not enough gold — flash cost label red
		_cost_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		var tween = create_tween()
		tween.tween_callback(func(): _cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))).set_delay(0.5)
		return

	# Build spell
	var spell = SpellDefinition.new()
	var spell_name = _name_edit.text.strip_edges()
	if spell_name == "":
		spell_name = "%s %s" % [SpellDefinition.effect_name(_selected_effect), SpellDefinition.delivery_name(_selected_delivery)]
	spell.spell_name = spell_name
	spell.id = spell_name.to_lower().replace(" ", "_") + "_" + str(randi() % 10000)
	spell.effect_type = _selected_effect
	spell.delivery = _selected_delivery
	spell.magnitude = mag
	spell.duration = dur
	spell.mp_cost = (3.0 + mag * 0.2 + dur * 0.5 + (bullets - 1) * 0.8) * delivery_mult
	spell.cooldown = clampf((3.0 + mag * 0.06 + dur * 0.2) * delivery_mult, 2.0, 15.0)
	spell.bullet_count = bullets
	spell.bullet_behavior = _behavior_option.selected if _selected_delivery == SpellDefinition.DeliveryType.PROJECTILE else 0
	spell.is_starter = false
	spell.description = _desc_label.text

	# Learn the spell
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var sb = player.get_node_or_null("SpellBook") as SpellBook
		if sb:
			sb.learn_spell(spell)

	# Flash green to confirm + SFX
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("spell_b", -2.0)
	_cost_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	_cost_label.text = "Spell Learned!"
	var tween = create_tween()
	tween.tween_callback(func():
		_cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		_update_preview()
	).set_delay(1.0)

func _get_status_name(effect: SpellDefinition.EffectType) -> String:
	match effect:
		SpellDefinition.EffectType.FIRE_DAMAGE: return "Burns"
		SpellDefinition.EffectType.ICE_DAMAGE: return "Slows"
		SpellDefinition.EffectType.POISON_DAMAGE: return "Poisons"
		SpellDefinition.EffectType.LIGHTNING_DAMAGE: return "Stuns"
		SpellDefinition.EffectType.HOLY_DAMAGE: return "Weakens"
		SpellDefinition.EffectType.DARK_DAMAGE: return "Fears"
	return ""

func _unhandled_input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
