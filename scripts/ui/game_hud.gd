class_name GameHUD
extends CanvasLayer

var _player: CharacterBody2D

# Bar references
var _hp_bar_fill: ColorRect
var _hp_bar_label: Label
var _mp_bar_fill: ColorRect
var _mp_bar_label: Label
var _stamina_bar_fill: ColorRect
var _stamina_bar_label: Label
var _shield_bar_fill: ColorRect
var _shield_bar_label: Label
var _shield_bar_bg: ColorRect
var _xp_bar_fill: ColorRect
var _level_label: Label

# Info panel (top-right)
var _info_line1: Label  # Floor / Zone
var _info_line2: Label  # Room type
var _info_line3: Label  # Gold

# Action buttons
var _btn_inventory: Button
var _btn_quest: Button
var _btn_map: Button

# Quickbar
var _quickbar_slots: Array[Button] = []
var _quickbar_panel: Control
const QUICKBAR_SLOT_SIZE = 80
const QUICKBAR_ICON_SIZE = 52
const QUICKBAR_SLOTS = 6
const QUICKBAR_GAP = 84

# Spell slots (left side)
var _spell_slots: Array[Button] = []
var _spell_panel: Control
var _stone_toss_btn: Button
const SPELL_SLOT_SIZE = 72
const SPELL_ICON_SIZE = 44
const SPELL_SLOTS = 6
const SPELL_GAP = 76
const SPELL_KEYS = ["F", "G", "H", "J", "K", "L"]

# Minimap
var _minimap_panel: Control
var _minimap_rects: Dictionary = {}  # Vector2i -> ColorRect
var _minimap_data: Dictionary = {}  # floor_map reference
var _minimap_current: Vector2i = Vector2i.ZERO

# Quest arrow
var _quest_arrow: Control
var _quest_arrow_label: Label
var _quest_objective_pos: Vector2 = Vector2.ZERO
var _quest_arrow_visible: bool = false

# Stealth indicator
var _stealth_indicator: Label
var _stealth_kill_prompt: Label

const BAR_WIDTH = 360.0
const BAR_HEIGHT = 20.0
const MP_BAR_HEIGHT = 16.0
const XP_BAR_HEIGHT = 10.0
const MARGIN = 14.0

# Colors
const HP_FILL = Color(0.8, 0.2, 0.2)
const HP_BG = Color(0.27, 0.07, 0.07)
const MP_FILL = Color(0.2, 0.4, 0.8)
const MP_BG = Color(0.07, 0.07, 0.27)
const STAMINA_FILL = Color(0.85, 0.75, 0.15)
const STAMINA_BG = Color(0.25, 0.2, 0.05)
const STAMINA_BAR_HEIGHT = 14.0
const SHIELD_FILL = Color(0.3, 0.5, 0.9)
const SHIELD_BG = Color(0.08, 0.1, 0.25)
const SHIELD_BAR_HEIGHT = 14.0
const XP_FILL = Color(0.8, 0.67, 0.2)
const XP_BG = Color(0.2, 0.13, 0.07)
const BADGE_BG = Color(0.2, 0.2, 0.2)
const BADGE_TEXT = Color(1.0, 0.8, 0.0)
const INFO_BG = Color(0.0, 0.0, 0.0, 0.6)

func _ready() -> void:
	layer = 100
	add_to_group("game_hud")
	_build_vitals_panel()
	_build_info_panel()
	_build_action_buttons()
	_build_quickbar()
	_build_spell_slots()
	_build_quest_arrow()
	_build_stealth_indicator()

func setup(player: CharacterBody2D) -> void:
	_player = player
	player.hp_changed.connect(_on_hp_changed)
	player.mp_changed.connect(_on_mp_changed)
	player.stamina_changed.connect(_on_stamina_changed)
	player.xp_changed.connect(_on_xp_changed)
	player.level_system.leveled_up.connect(_on_level_up)
	player.equipment_manager.inventory_changed.connect(_refresh_quickbar)
	player.equipment_manager.stats_changed.connect(_refresh_quickbar)
	player.shield_changed.connect(_on_shield_changed)
	# Show shield bar if player has a shield equipped
	_check_shield_visibility()

	# Load quickbar from save data
	var gm = get_node_or_null("/root/GameManager")

	_update_hp(player.hp, player.max_hp)
	_update_mp(player.mp, player.max_mp)
	_update_stamina(player.stamina, player.max_stamina)
	_update_xp(player.level_system.xp, player.level_system.xp_to_next_level())
	_update_level(player.level_system.level)
	if gm and gm.has_method("load_quickbar"):
		gm.load_quickbar(self)
	# Pre-populate quickbar if all slots empty (first run)
	var all_empty = true
	for s in _quickbar_items:
		if s != "":
			all_empty = false
			break
	if all_empty:
		_quickbar_items[0] = "Red Potion"
		_quickbar_items[1] = "Apple"
	_refresh_quickbar()
	_refresh_spell_slots()

func _build_vitals_panel() -> void:
	var panel = Control.new()
	panel.name = "VitalsPanel"
	add_child(panel)

	var y = MARGIN

	# Level badge
	var badge_bg = ColorRect.new()
	badge_bg.color = BADGE_BG
	badge_bg.position = Vector2(MARGIN, y)
	badge_bg.size = Vector2(70, 28)
	panel.add_child(badge_bg)

	_level_label = Label.new()
	_level_label.text = "Lv.1"
	var badge_settings = LabelSettings.new()
	badge_settings.font_size = 18
	badge_settings.font_color = BADGE_TEXT
	badge_settings.outline_size = 2
	badge_settings.outline_color = Color.BLACK
	_level_label.label_settings = badge_settings
	_level_label.position = Vector2(MARGIN + 8, y + 3)
	panel.add_child(_level_label)

	y += 34

	# HP bar
	_hp_bar_fill = _create_bar(panel, Vector2(MARGIN, y), HP_BG, HP_FILL, BAR_HEIGHT)
	_hp_bar_label = _create_bar_label(panel, Vector2(MARGIN, y), BAR_HEIGHT, 14)
	y += BAR_HEIGHT + 4

	# MP bar
	_mp_bar_fill = _create_bar(panel, Vector2(MARGIN, y), MP_BG, MP_FILL, MP_BAR_HEIGHT)
	_mp_bar_label = _create_bar_label(panel, Vector2(MARGIN, y), MP_BAR_HEIGHT, 12)
	y += MP_BAR_HEIGHT + 4

	# Stamina bar
	_stamina_bar_fill = _create_bar(panel, Vector2(MARGIN, y), STAMINA_BG, STAMINA_FILL, STAMINA_BAR_HEIGHT)
	_stamina_bar_label = _create_bar_label(panel, Vector2(MARGIN, y), STAMINA_BAR_HEIGHT, 11)
	y += STAMINA_BAR_HEIGHT + 4

	# Shield bar (hidden by default, shown for warrior with shield)
	_shield_bar_bg = ColorRect.new()
	_shield_bar_bg.color = SHIELD_BG
	_shield_bar_bg.position = Vector2(MARGIN, y)
	_shield_bar_bg.size = Vector2(BAR_WIDTH, SHIELD_BAR_HEIGHT)
	_shield_bar_bg.visible = false
	panel.add_child(_shield_bar_bg)
	_shield_bar_fill = ColorRect.new()
	_shield_bar_fill.color = SHIELD_FILL
	_shield_bar_fill.position = Vector2(MARGIN, y)
	_shield_bar_fill.size = Vector2(BAR_WIDTH, SHIELD_BAR_HEIGHT)
	_shield_bar_fill.visible = false
	panel.add_child(_shield_bar_fill)
	_shield_bar_label = _create_bar_label(panel, Vector2(MARGIN, y), SHIELD_BAR_HEIGHT, 11)
	_shield_bar_label.visible = false
	y += SHIELD_BAR_HEIGHT + 4

	# XP bar (thinner, no label)
	_xp_bar_fill = _create_bar(panel, Vector2(MARGIN, y), XP_BG, XP_FILL, XP_BAR_HEIGHT)

func _create_bar(parent: Control, pos: Vector2, bg_color: Color, fill_color: Color, height: float) -> ColorRect:
	var bg = ColorRect.new()
	bg.color = bg_color
	bg.position = pos
	bg.size = Vector2(BAR_WIDTH, height)
	parent.add_child(bg)

	var fill = ColorRect.new()
	fill.color = fill_color
	fill.position = pos
	fill.size = Vector2(BAR_WIDTH, height)
	parent.add_child(fill)
	return fill

func _create_bar_label(parent: Control, pos: Vector2, height: float, font_size: int) -> Label:
	var lbl = Label.new()
	var settings = LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = Color.WHITE
	settings.outline_size = 2
	settings.outline_color = Color.BLACK
	lbl.label_settings = settings
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(pos.x, pos.y)
	lbl.size = Vector2(BAR_WIDTH, height)
	parent.add_child(lbl)
	return lbl

func _build_info_panel() -> void:
	var panel = Control.new()
	panel.name = "InfoPanel"
	add_child(panel)

	var bg = ColorRect.new()
	bg.color = INFO_BG
	bg.size = Vector2(200, 80)
	bg.position = Vector2(1920 - 200 - MARGIN, MARGIN)
	panel.add_child(bg)

	var settings = LabelSettings.new()
	settings.font_size = 14
	settings.font_color = Color.WHITE
	settings.outline_size = 2
	settings.outline_color = Color.BLACK

	var x = 1920 - 200 - MARGIN + 10
	var y = MARGIN + 6

	_info_line1 = Label.new()
	_info_line1.label_settings = settings
	_info_line1.position = Vector2(x, y)
	_info_line1.size = Vector2(180, 20)
	panel.add_child(_info_line1)

	_info_line2 = Label.new()
	_info_line2.label_settings = settings
	_info_line2.position = Vector2(x, y + 22)
	_info_line2.size = Vector2(180, 20)
	panel.add_child(_info_line2)

	_info_line3 = Label.new()
	_info_line3.label_settings = settings
	_info_line3.position = Vector2(x, y + 44)
	_info_line3.size = Vector2(180, 20)
	panel.add_child(_info_line3)

func _build_action_buttons() -> void:
	var panel = Control.new()
	panel.name = "ActionButtons"
	add_child(panel)

	var obj_tex = load("res://assets/sprites/lofi_obj_32.png") as Texture2D
	var tiles_tex = load("res://assets/sprites/loy/tiles.png") as Texture2D

	# Inventory button — bag sprite from lofi_obj_32 (BAG_BROWN = index 30)
	_btn_inventory = _create_icon_button(obj_tex, 30, "BAG", 32)
	_btn_inventory.position = Vector2(1920 - 120 - MARGIN, 1080 - 220 - MARGIN)
	_btn_inventory.pressed.connect(_on_bag_pressed)
	panel.add_child(_btn_inventory)

	# Quest button — scroll icon from tiles.png (tile 100)
	_btn_quest = _create_icon_button(tiles_tex, 100, "LOG", 32)
	_btn_quest.position = Vector2(1920 - 120 - MARGIN, 1080 - 110 - MARGIN)
	_btn_quest.pressed.connect(_on_log_pressed)
	panel.add_child(_btn_quest)

	# Debug gold button — gives 20k gold for testing
	var dbg_btn := Button.new()
	dbg_btn.text = "+20k G"
	dbg_btn.size = Vector2(100, 36)
	dbg_btn.position = Vector2(1920 - 120 - MARGIN, 1080 - 260 - MARGIN)
	dbg_btn.focus_mode = Control.FOCUS_NONE
	dbg_btn.add_theme_font_size_override("font_size", 14)
	var dbg_style := StyleBoxFlat.new()
	dbg_style.bg_color = Color(0.25, 0.2, 0.05, 0.9)
	dbg_style.border_color = Color(1.0, 0.8, 0.2)
	dbg_style.set_border_width_all(2)
	dbg_style.set_corner_radius_all(4)
	dbg_btn.add_theme_stylebox_override("normal", dbg_style)
	dbg_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	dbg_btn.pressed.connect(_on_debug_gold_pressed)
	panel.add_child(dbg_btn)

	# Map button removed — world map now only accessible from War Table

func _on_debug_gold_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.save_data:
		gm.save_data.gold += 20000
		gm.save_data.save_to_slot()
		set_gold(gm.save_data.gold)
		flash_text("+20,000 Gold (DEBUG)", Color(1.0, 0.85, 0.2), 2.0)
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("buy", -4.0)
		print("DEBUG: Added 20000 gold (total: %d)" % gm.save_data.gold)

func _unhandled_input(event: InputEvent) -> void:
	# Debug: press G to grant 20k gold
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			_on_debug_gold_pressed()
			get_viewport().set_input_as_handled()

func _create_icon_button(sheet: Texture2D, sprite_index: int, label_text: String, tile_size: int = 32) -> Button:
	var btn = Button.new()
	var btn_w = 100
	var btn_h = 90
	btn.size = Vector2(btn_w, btn_h)
	btn.focus_mode = Control.FOCUS_NONE

	# Dark styled background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.14, 0.85)
	style.border_color = Color(0.5, 0.4, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = Color(0.15, 0.12, 0.25, 0.9)
	hover.border_color = Color(0.8, 0.6, 0.3)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed_style = style.duplicate()
	pressed_style.bg_color = Color(0.2, 0.15, 0.3, 0.95)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	# Icon sprite — displayed at 64x64 (2x)
	if sheet:
		var icon_sprite = TextureRect.new()
		icon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var atlas = AtlasTexture.new()
		atlas.atlas = sheet
		var col = sprite_index % 16
		var row = sprite_index / 16
		atlas.region = Rect2(col * tile_size, row * tile_size, tile_size, tile_size)
		icon_sprite.texture = atlas
		icon_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_sprite.custom_minimum_size = Vector2(64, 64)
		icon_sprite.position = Vector2((btn_w - 64) / 2, 2)
		icon_sprite.size = Vector2(64, 64)
		btn.add_child(icon_sprite)

	# Text label below icon
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, 68)
	lbl.size = Vector2(btn_w, 18)
	btn.add_child(lbl)

	return btn

func _on_bag_pressed() -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click", -5.0)
	var inv = get_tree().get_first_node_in_group("inventory_screen")
	if inv and inv.has_method("toggle"):
		inv.toggle()

func _on_log_pressed() -> void:
	# Simulate Q key press
	var ev = InputEventAction.new()
	ev.action = "quest_log"
	ev.pressed = true
	Input.parse_input_event(ev)

func _on_map_pressed() -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click", -5.0)
	var map = get_tree().get_first_node_in_group("world_map")
	if map and map.has_method("toggle"):
		map.toggle()

# --- Quest Arrow ---

func _build_quest_arrow() -> void:
	_quest_arrow = Control.new()
	_quest_arrow.name = "QuestArrow"
	_quest_arrow.visible = false
	add_child(_quest_arrow)

	# Arrow triangle (drawn as a Polygon2D child)
	var arrow = Polygon2D.new()
	arrow.name = "Arrow"
	arrow.polygon = PackedVector2Array([
		Vector2(0, -12), Vector2(20, 0), Vector2(0, 12)
	])
	arrow.color = Color(1.0, 0.85, 0.2, 0.9)  # golden
	_quest_arrow.add_child(arrow)

	# Label next to arrow
	_quest_arrow_label = Label.new()
	var settings = LabelSettings.new()
	settings.font_size = 14
	settings.font_color = Color(1.0, 0.9, 0.5)
	settings.outline_size = 2
	settings.outline_color = Color(0, 0, 0)
	_quest_arrow_label.label_settings = settings
	_quest_arrow_label.position = Vector2(24, -10)
	_quest_arrow.add_child(_quest_arrow_label)

func set_quest_objective(world_pos: Vector2, label_text: String = "") -> void:
	_quest_objective_pos = world_pos
	_quest_arrow_visible = world_pos != Vector2.ZERO
	if _quest_arrow_label:
		_quest_arrow_label.text = label_text
	if _quest_arrow:
		_quest_arrow.visible = _quest_arrow_visible

func clear_quest_objective() -> void:
	_quest_arrow_visible = false
	_quest_objective_pos = Vector2.ZERO
	if _quest_arrow:
		_quest_arrow.visible = false

var _spell_refresh_timer: float = 0.0

func _process(_delta: float) -> void:
	# Refresh spell slot icons every 0.5s (for cooldown display)
	_spell_refresh_timer += _delta
	if _spell_refresh_timer >= 0.5:
		_spell_refresh_timer = 0.0
		_refresh_spell_slots()
	# Stealth indicator (every frame for responsiveness)
	_update_stealth_indicator()

	# Update shield bar cooldown display
	if _player and _shield_bar_bg.visible:
		if _player._shield_broken:
			_shield_bar_fill.color = Color(0.4, 0.2, 0.2)
			_shield_bar_label.text = "BROKEN %.0fs" % _player._shield_regen_delay
			_shield_bar_fill.size.x = BAR_WIDTH * (1.0 - _player._shield_regen_delay / _player.SHIELD_BROKEN_COOLDOWN)
		elif _player._shield_raise_cooldown > 0:
			_shield_bar_fill.color = Color(0.5, 0.5, 0.3)
			_shield_bar_label.text = "R: %.1fs" % _player._shield_raise_cooldown

	if not _quest_arrow_visible or not _player or _quest_objective_pos == Vector2.ZERO:
		if _quest_arrow:
			_quest_arrow.visible = false
		return

	var player_pos = _player.global_position
	var dir = (_quest_objective_pos - player_pos).normalized()
	var dist = player_pos.distance_to(_quest_objective_pos)

	# Hide if very close (within ~3 tiles on overworld = 96px)
	if dist < 96.0:
		_quest_arrow.visible = false
		return

	_quest_arrow.visible = true

	# Position arrow at edge of screen
	var screen_center = Vector2(960, 540)  # 1920x1080 / 2
	var margin = 60.0
	var angle = dir.angle()

	# Calculate intersection with screen edge
	var half_w = screen_center.x - margin
	var half_h = screen_center.y - margin
	var arrow_pos = screen_center

	# Use parametric line from center in direction of angle
	var dx = cos(angle)
	var dy = sin(angle)
	if abs(dx) > 0.001:
		var t_x = half_w / abs(dx)
		var t_y = half_h / abs(dy) if abs(dy) > 0.001 else 99999.0
		var t = minf(t_x, t_y)
		arrow_pos = screen_center + Vector2(dx, dy) * t
	elif abs(dy) > 0.001:
		arrow_pos = screen_center + Vector2(0, dy) * half_h

	_quest_arrow.position = arrow_pos
	# Rotate the arrow polygon
	var arrow_poly = _quest_arrow.get_node("Arrow") as Polygon2D
	if arrow_poly:
		arrow_poly.rotation = angle

	# Show distance
	if _quest_arrow_label:
		var dist_tiles = int(dist / 32.0)
		_quest_arrow_label.text = _quest_arrow_label.text.split(" (")[0]  # strip old distance
		if dist_tiles > 10:
			_quest_arrow_label.rotation = 0
			# Position label on the inside of the arrow
			var label_offset = -dir * 30.0
			_quest_arrow_label.position = label_offset + Vector2(-20, -10)

# --- Minimap ---

func setup_minimap(floor_map: Dictionary, start_pos: Vector2i) -> void:
	_minimap_data = floor_map
	if _minimap_panel:
		_minimap_panel.queue_free()

	_minimap_panel = Control.new()
	_minimap_panel.name = "Minimap"
	add_child(_minimap_panel)

	# Background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.position = Vector2(1920 - 200 - MARGIN, MARGIN + 90)
	bg.size = Vector2(200, 120)
	_minimap_panel.add_child(bg)

	# Find bounds of map
	var min_pos = Vector2i(999, 999)
	var max_pos = Vector2i(-999, -999)
	for pos in floor_map:
		min_pos.x = mini(min_pos.x, pos.x)
		min_pos.y = mini(min_pos.y, pos.y)
		max_pos.x = maxi(max_pos.x, pos.x)
		max_pos.y = maxi(max_pos.y, pos.y)

	var map_w = max_pos.x - min_pos.x + 1
	var map_h = max_pos.y - min_pos.y + 1
	var cell_w = mini(int(190.0 / map_w), 12)
	var cell_h = mini(int(110.0 / map_h), 12)
	var cell_size = mini(cell_w, cell_h)
	cell_size = maxi(cell_size, 3)

	var offset_x = 1920 - 200 - MARGIN + 5 + (190 - map_w * cell_size) / 2
	var offset_y = MARGIN + 95 + (110 - map_h * cell_size) / 2

	_minimap_rects.clear()
	for pos in floor_map:
		var room = floor_map[pos] as RoomData
		var rect = ColorRect.new()
		rect.size = Vector2(cell_size - 1, cell_size - 1)
		rect.position = Vector2(
			offset_x + (pos.x - min_pos.x) * cell_size,
			offset_y + (pos.y - min_pos.y) * cell_size
		)
		if room and room.has_stairs_down:
			rect.color = Color(0.5, 0.4, 0.08, 0.95)  # stairs = dim gold (visible before visiting)
		else:
			rect.color = Color(0.02, 0.02, 0.02, 0.95)  # unvisited = effectively black

		_minimap_panel.add_child(rect)
		_minimap_rects[pos] = rect

	update_minimap_room(start_pos)

func hide_minimap() -> void:
	_minimap_data.clear()
	_minimap_rects.clear()
	if _minimap_panel:
		_minimap_panel.queue_free()
		_minimap_panel = null

func update_minimap_room(grid_pos: Vector2i) -> void:
	# Dim previous current room to visited color
	if _minimap_rects.has(_minimap_current):
		var prev_room = _minimap_data.get(_minimap_current) as RoomData
		if prev_room and prev_room.has_stairs_down:
			_minimap_rects[_minimap_current].color = Color(0.6, 0.5, 0.1)  # stairs = gold
		else:
			_minimap_rects[_minimap_current].color = Color(0.22, 0.22, 0.22, 1.0)  # visited = dark grey

	_minimap_current = grid_pos
	if _minimap_rects.has(grid_pos):
		_minimap_rects[grid_pos].color = Color.WHITE  # current = bright white

# --- Public API ---

func set_floor_info(floor_num: int, recommended_level: int = 0, area_name: String = "") -> void:
	var floor_text: String
	if recommended_level > 0:
		floor_text = "Floor %d  (Lv.%d)" % [floor_num, recommended_level]
	else:
		floor_text = "Floor " + str(floor_num)
	if area_name != "":
		_info_line1.text = "%s  %s" % [area_name, floor_text]
	else:
		_info_line1.text = floor_text

func set_room_info(room_text: String) -> void:
	_info_line2.text = room_text

func set_zone_info(zone_name: String) -> void:
	_info_line1.text = zone_name

func set_gold(amount: int) -> void:
	_info_line3.text = "Gold: " + str(amount)

var _flash_label: Label = null

func flash_text(text: String, color: Color = Color.RED, duration: float = 1.5) -> void:
	if _flash_label and is_instance_valid(_flash_label):
		_flash_label.queue_free()
	_flash_label = Label.new()
	_flash_label.text = text
	_flash_label.add_theme_font_size_override("font_size", 48)
	_flash_label.add_theme_color_override("font_color", color)
	_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_flash_label.anchors_preset = Control.PRESET_CENTER
	_flash_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_flash_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_flash_label.size = Vector2(600, 80)
	_flash_label.position = Vector2(-300, -40)
	add_child(_flash_label)
	var tween = create_tween()
	tween.tween_interval(duration * 0.6)
	tween.tween_property(_flash_label, "modulate:a", 0.0, duration * 0.4)
	tween.tween_callback(_flash_label.queue_free)

func set_non_quickbar_visible(vis: bool) -> void:
	## Hide/show all HUD elements when inventory opens
	for child in get_children():
		if child is Control:
			child.visible = vis

# --- Signal handlers ---

func _on_hp_changed(new_hp: int) -> void:
	if _player:
		_update_hp(new_hp, _player.max_hp)

func _on_mp_changed(new_mp: float) -> void:
	if _player:
		_update_mp(new_mp, _player.max_mp)

func _on_stamina_changed(new_stamina: float) -> void:
	if _player:
		_update_stamina(new_stamina, _player.max_stamina)

func _on_xp_changed(xp: int, xp_needed: int) -> void:
	_update_xp(xp, xp_needed)

func _on_level_up(new_level: int) -> void:
	_update_level(new_level)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("1up_a", -2.0, 0.0)
	if _player:
		_update_xp(_player.level_system.xp, _player.level_system.xp_to_next_level())
		_update_hp(_player.hp, _player.max_hp)
		_update_mp(_player.mp, _player.max_mp)
		_update_stamina(_player.stamina, _player.max_stamina)

# --- Internal ---

func _update_hp(current: int, maximum: int) -> void:
	var ratio = float(current) / maxi(maximum, 1)
	_hp_bar_fill.size.x = BAR_WIDTH * ratio
	_hp_bar_label.text = str(current) + "/" + str(maximum)

func _update_mp(current: float, maximum: float) -> void:
	var ratio = current / maxf(maximum, 1.0)
	_mp_bar_fill.size.x = BAR_WIDTH * ratio
	_mp_bar_label.text = str(int(current)) + "/" + str(int(maximum))

func _update_stamina(current: float, maximum: float) -> void:
	var ratio = current / maxf(maximum, 1.0)
	_stamina_bar_fill.size.x = BAR_WIDTH * ratio
	_stamina_bar_label.text = str(int(current)) + "/" + str(int(maximum))
	# Flash red when low
	if current < 25.0:
		_stamina_bar_fill.color = Color(0.9, 0.3, 0.1)
	else:
		_stamina_bar_fill.color = STAMINA_FILL

func _on_shield_changed(charges: int) -> void:
	if not _player:
		return
	_check_shield_visibility()
	var ratio = float(charges) / maxi(_player._shield_max_charges, 1)
	_shield_bar_fill.size.x = BAR_WIDTH * ratio
	if _player._shield_broken:
		_shield_bar_fill.color = Color(0.4, 0.2, 0.2)  # red when broken
		var cd_left = _player._shield_regen_delay
		_shield_bar_label.text = "BROKEN %.0fs" % cd_left
	elif charges < _player._shield_max_charges:
		_shield_bar_fill.color = SHIELD_FILL
		_shield_bar_label.text = str(charges) + "/" + str(_player._shield_max_charges)
	else:
		_shield_bar_fill.color = SHIELD_FILL
		_shield_bar_label.text = str(charges) + "/" + str(_player._shield_max_charges)

func _check_shield_visibility() -> void:
	if not _player:
		return
	var has_shield = _player.equipment_manager.equipped.has(EquipmentItem.SlotType.SHIELD) and _player.equipment_manager.equipped[EquipmentItem.SlotType.SHIELD] != null
	_shield_bar_bg.visible = has_shield
	_shield_bar_fill.visible = has_shield
	_shield_bar_label.visible = has_shield
	if has_shield:
		var ratio = float(_player._shield_charges) / maxi(_player._shield_max_charges, 1)
		_shield_bar_fill.size.x = BAR_WIDTH * ratio
		_shield_bar_label.text = str(_player._shield_charges) + "/" + str(_player._shield_max_charges)

func _update_xp(current: int, needed: int) -> void:
	var ratio = float(current) / maxi(needed, 1)
	_xp_bar_fill.size.x = BAR_WIDTH * ratio

func _update_level(level: int) -> void:
	var power = _player.level_system.get_power_level() if _player and _player.level_system else level * 10
	_level_label.text = "Lv.%d  Rating:%d" % [level, power]

# --- Quickbar ---

# Quickbar assignments stored by item_name (persists across inventory reshuffling)
var _quickbar_items: Array[String] = ["", "", "", "", "", ""]  # item_name per slot

func get_quickbar_slot_at_pos(screen_pos: Vector2) -> int:
	for i in range(QUICKBAR_SLOTS):
		var btn = _quickbar_slots[i]
		var rect = Rect2(btn.position, btn.size)
		if rect.has_point(screen_pos):
			return i
	return -1

func _build_quickbar() -> void:
	_quickbar_panel = Control.new()
	_quickbar_panel.name = "Quickbar"
	add_child(_quickbar_panel)

	# BAG button is at y = 1080 - 220 - MARGIN = 846
	# Stack 6 slots above it, offset up to avoid overlap with BAG/LOG
	var base_x = 1920 - 94 - MARGIN
	var bag_top_y = 1080 - 220 - MARGIN - 100
	_quickbar_slots.clear()

	for i in range(QUICKBAR_SLOTS):
		var slot_y = bag_top_y - (QUICKBAR_SLOTS - i) * QUICKBAR_GAP
		var btn = Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.size = Vector2(QUICKBAR_SLOT_SIZE, QUICKBAR_SLOT_SIZE)
		btn.position = Vector2(base_x, slot_y)

		var sty = StyleBoxFlat.new()
		sty.bg_color = Color(0.08, 0.06, 0.14, 0.85)
		sty.border_color = Color(0.4, 0.35, 0.25)
		sty.set_border_width_all(1)
		sty.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sty)

		var hover_sty = sty.duplicate()
		hover_sty.bg_color = Color(0.15, 0.12, 0.25, 0.9)
		hover_sty.border_color = Color(0.8, 0.6, 0.3)
		hover_sty.set_border_width_all(2)
		btn.add_theme_stylebox_override("hover", hover_sty)

		var pressed_sty = sty.duplicate()
		pressed_sty.bg_color = Color(0.2, 0.15, 0.3, 0.95)
		btn.add_theme_stylebox_override("pressed", pressed_sty)

		btn.pressed.connect(_on_quickbar_pressed.bind(i))
		_quickbar_panel.add_child(btn)
		_quickbar_slots.append(btn)

func _build_spell_slots() -> void:
	_spell_panel = Control.new()
	_spell_panel.name = "SpellSlots"
	add_child(_spell_panel)

	# Stack 6 slots on the LEFT side, matching quickbar positioning on right
	var base_x = MARGIN
	var bag_top_y = 1080 - 220 - MARGIN - 100
	_spell_slots.clear()

	for i in range(SPELL_SLOTS):
		var slot_y = bag_top_y - (SPELL_SLOTS - i) * SPELL_GAP
		var btn = Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.size = Vector2(SPELL_SLOT_SIZE, SPELL_SLOT_SIZE)
		btn.position = Vector2(base_x, slot_y)

		var sty = StyleBoxFlat.new()
		sty.bg_color = Color(0.06, 0.06, 0.16, 0.85)
		sty.border_color = Color(0.3, 0.25, 0.5)
		sty.set_border_width_all(1)
		sty.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sty)

		var hover_sty = sty.duplicate()
		hover_sty.bg_color = Color(0.12, 0.1, 0.25, 0.9)
		hover_sty.border_color = Color(0.6, 0.4, 0.8)
		hover_sty.set_border_width_all(2)
		btn.add_theme_stylebox_override("hover", hover_sty)

		btn.pressed.connect(_on_spell_slot_pressed.bind(i))
		_spell_panel.add_child(btn)
		_spell_slots.append(btn)

	# Stone toss indicator (below spell slots, T key)
	var stone_y = bag_top_y + SPELL_GAP * 0.15
	_stone_toss_btn = Button.new()
	_stone_toss_btn.focus_mode = Control.FOCUS_NONE
	_stone_toss_btn.size = Vector2(SPELL_SLOT_SIZE, SPELL_SLOT_SIZE)
	_stone_toss_btn.position = Vector2(base_x, stone_y)
	var stone_sty = StyleBoxFlat.new()
	stone_sty.bg_color = Color(0.1, 0.08, 0.04, 0.85)
	stone_sty.border_color = Color(0.6, 0.5, 0.3)
	stone_sty.set_border_width_all(2)
	stone_sty.set_corner_radius_all(4)
	_stone_toss_btn.add_theme_stylebox_override("normal", stone_sty)
	_stone_toss_btn.add_theme_stylebox_override("hover", stone_sty)
	_spell_panel.add_child(_stone_toss_btn)

func _refresh_spell_slots() -> void:
	if not _player or not _player.spell_book:
		return
	var sb = _player.spell_book
	# Get spirit stat for slot unlocks
	var spirit = _player.level_system.allocated.get("spirit", 0) if _player.level_system else 0
	var max_slots = sb.get_max_slots(_player.level_system.level if _player.level_system else 1, spirit)
	for i in range(SPELL_SLOTS):
		var btn = _spell_slots[i]
		for child in btn.get_children():
			child.queue_free()

		var sty = btn.get_theme_stylebox("normal") as StyleBoxFlat

		# Locked slot
		if i >= max_slots:
			var lock_lbl = Label.new()
			lock_lbl.text = "Spr%d" % SpellBook.SPIRIT_THRESHOLDS[i] if i < SpellBook.SPIRIT_THRESHOLDS.size() else "?"
			lock_lbl.add_theme_font_size_override("font_size", 10)
			lock_lbl.add_theme_color_override("font_color", Color(0.25, 0.2, 0.3))
			lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lock_lbl.position = Vector2(0, 0)
			lock_lbl.size = Vector2(SPELL_SLOT_SIZE, SPELL_SLOT_SIZE)
			lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(lock_lbl)
			if sty:
				sty.bg_color = Color(0.04, 0.04, 0.08, 0.7)
				sty.border_color = Color(0.15, 0.12, 0.2)
				sty.set_border_width_all(1)
			continue

		var spell = sb.spell_slots[i] as SpellDefinition if i < sb.spell_slots.size() else null

		if not spell:
			# Empty slot — show key label (big)
			var key_lbl = Label.new()
			key_lbl.text = SPELL_KEYS[i]
			key_lbl.add_theme_font_size_override("font_size", 28)
			key_lbl.add_theme_color_override("font_color", Color(0.4, 0.35, 0.55))
			key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			key_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			key_lbl.position = Vector2(0, 0)
			key_lbl.size = Vector2(SPELL_SLOT_SIZE, SPELL_SLOT_SIZE)
			key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(key_lbl)
			if sty:
				sty.border_color = Color(0.3, 0.25, 0.5)
				sty.set_border_width_all(1)
			continue

		# Spell icon (colored circle based on effect type)
		var icon_color = _spell_effect_color(spell.effect_type)
		var icon_rect = ColorRect.new()
		icon_rect.color = icon_color
		icon_rect.size = Vector2(SPELL_ICON_SIZE, SPELL_ICON_SIZE)
		icon_rect.position = Vector2((SPELL_SLOT_SIZE - SPELL_ICON_SIZE) / 2, 2)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon_rect)

		# Spell name (abbreviated)
		var name_lbl = Label.new()
		var short = spell.spell_name.substr(0, 6) if spell.spell_name.length() > 6 else spell.spell_name
		name_lbl.text = short
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.9))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.position = Vector2(0, SPELL_SLOT_SIZE - 14)
		name_lbl.size = Vector2(SPELL_SLOT_SIZE, 12)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(name_lbl)

		# Key label (top-left corner, prominent)
		var key_lbl2 = Label.new()
		key_lbl2.text = SPELL_KEYS[i]
		key_lbl2.add_theme_font_size_override("font_size", 18)
		key_lbl2.add_theme_color_override("font_color", Color(0.7, 0.65, 0.8))
		key_lbl2.position = Vector2(2, 0)
		key_lbl2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(key_lbl2)

		# Cooldown overlay
		if sb.slot_cooldowns[i] > 0:
			var cd_lbl = Label.new()
			cd_lbl.text = str(int(ceil(sb.slot_cooldowns[i])))
			cd_lbl.add_theme_font_size_override("font_size", 20)
			cd_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
			cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cd_lbl.position = Vector2(0, 0)
			cd_lbl.size = Vector2(SPELL_SLOT_SIZE, SPELL_SLOT_SIZE)
			cd_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(cd_lbl)

		if sty:
			sty.border_color = icon_color.darkened(0.3)
			sty.set_border_width_all(2)

	# Refresh stone toss indicator
	if _stone_toss_btn and _player:
		# Clear old children
		for c in _stone_toss_btn.get_children():
			c.queue_free()
		# Icon
		var st_icon = ColorRect.new()
		st_icon.color = Color(0.7, 0.6, 0.35)  # rocky brown
		st_icon.size = Vector2(SPELL_ICON_SIZE, SPELL_ICON_SIZE)
		st_icon.position = Vector2((SPELL_SLOT_SIZE - SPELL_ICON_SIZE) / 2, 2)
		st_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stone_toss_btn.add_child(st_icon)
		# Name
		var st_name = Label.new()
		st_name.text = "Stone"
		st_name.add_theme_font_size_override("font_size", 9)
		st_name.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
		st_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st_name.position = Vector2(0, SPELL_SLOT_SIZE - 14)
		st_name.size = Vector2(SPELL_SLOT_SIZE, 12)
		st_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stone_toss_btn.add_child(st_name)
		# Key label
		var st_key = Label.new()
		st_key.text = "T"
		st_key.add_theme_font_size_override("font_size", 18)
		st_key.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
		st_key.position = Vector2(2, 0)
		st_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stone_toss_btn.add_child(st_key)
		# Charge counter
		var charges = _player._stone_toss_charges if "_stone_toss_charges" in _player else 0
		var max_ch = _player.STONE_TOSS_MAX_CHARGES if "STONE_TOSS_MAX_CHARGES" in _player else 2
		var ch_lbl = Label.new()
		ch_lbl.text = str(charges) + "/" + str(max_ch)
		ch_lbl.add_theme_font_size_override("font_size", 16)
		ch_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6) if charges > 0 else Color(0.5, 0.4, 0.4))
		ch_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ch_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ch_lbl.position = Vector2(0, 0)
		ch_lbl.size = Vector2(SPELL_SLOT_SIZE, SPELL_SLOT_SIZE)
		ch_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stone_toss_btn.add_child(ch_lbl)

func _spell_effect_color(effect_type: SpellDefinition.EffectType) -> Color:
	match effect_type:
		SpellDefinition.EffectType.FIRE_DAMAGE: return Color(0.9, 0.3, 0.1)
		SpellDefinition.EffectType.ICE_DAMAGE: return Color(0.3, 0.6, 1.0)
		SpellDefinition.EffectType.LIGHTNING_DAMAGE: return Color(1.0, 1.0, 0.2)
		SpellDefinition.EffectType.POISON_DAMAGE: return Color(0.3, 0.9, 0.3)
		SpellDefinition.EffectType.HOLY_DAMAGE: return Color(1.0, 1.0, 0.8)
		SpellDefinition.EffectType.DARK_DAMAGE: return Color(0.5, 0.2, 0.8)
		SpellDefinition.EffectType.HEAL_SELF: return Color(0.4, 1.0, 0.4)
		SpellDefinition.EffectType.SHIELD_BUFF: return Color(0.4, 0.6, 1.0)
		SpellDefinition.EffectType.SPEED_BUFF: return Color(1.0, 0.9, 0.4)
		SpellDefinition.EffectType.DAMAGE_BUFF: return Color(1.0, 0.4, 0.3)
	return Color(0.5, 0.5, 0.6)

func _on_spell_slot_pressed(slot_index: int) -> void:
	if not _player:
		return
	_player._use_spell_slot(slot_index)

func assign_to_quickbar(slot_index: int, item_name: String) -> void:
	if slot_index < 0 or slot_index >= QUICKBAR_SLOTS:
		return
	_quickbar_items[slot_index] = item_name
	_refresh_quickbar()

func clear_quickbar_slot(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < QUICKBAR_SLOTS:
		_quickbar_items[slot_index] = ""
		_refresh_quickbar()

func _refresh_quickbar() -> void:
	if not _player:
		return
	var em = _player.equipment_manager

	for i in range(QUICKBAR_SLOTS):
		var btn = _quickbar_slots[i]
		# Clear old children
		for child in btn.get_children():
			child.queue_free()

		var item_name = _quickbar_items[i]
		var sty = btn.get_theme_stylebox("normal") as StyleBoxFlat

		if sty:
			sty.border_color = Color(0.4, 0.35, 0.25)
			sty.set_border_width_all(1)

		if item_name == "":
			# Empty slot — show slot number
			var num_lbl = Label.new()
			num_lbl.text = str(i + 1)
			num_lbl.add_theme_font_size_override("font_size", 14)
			num_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
			num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			num_lbl.position = Vector2(0, 0)
			num_lbl.size = Vector2(QUICKBAR_SLOT_SIZE, QUICKBAR_SLOT_SIZE)
			num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(num_lbl)
			continue

		# Find item in inventory by name
		var item: EquipmentItem = null
		var count = 0
		for j in range(em.inventory.size()):
			if em.inventory[j].item_name == item_name:
				if not item:
					item = em.inventory[j]
				count += 1

		if not item:
			# Item no longer in inventory — show greyed out name
			var ghost_lbl = Label.new()
			ghost_lbl.text = item_name.substr(0, 7)
			ghost_lbl.add_theme_font_size_override("font_size", 10)
			ghost_lbl.add_theme_color_override("font_color", Color(0.35, 0.3, 0.3))
			ghost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ghost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			ghost_lbl.position = Vector2(0, 0)
			ghost_lbl.size = Vector2(QUICKBAR_SLOT_SIZE, QUICKBAR_SLOT_SIZE)
			ghost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(ghost_lbl)
			continue

		# Icon
		var icon = TextureRect.new()
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(QUICKBAR_ICON_SIZE, QUICKBAR_ICON_SIZE)
		icon.position = Vector2((QUICKBAR_SLOT_SIZE - QUICKBAR_ICON_SIZE) / 2, 2)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex = ItemIconHelper.get_icon_texture(item)
		if tex:
			icon.texture = tex
		btn.add_child(icon)

		# Name label
		var name_lbl = Label.new()
		var short_name = item_name.substr(0, 7) if item_name.length() > 7 else item_name
		name_lbl.text = short_name
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.position = Vector2(0, QUICKBAR_SLOT_SIZE - 16)
		name_lbl.size = Vector2(QUICKBAR_SLOT_SIZE, 14)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(name_lbl)

		# Count badge
		if count > 1:
			var count_lbl = Label.new()
			count_lbl.text = "x" + str(count)
			count_lbl.add_theme_font_size_override("font_size", 11)
			count_lbl.add_theme_color_override("font_color", Color(1, 1, 0.6))
			count_lbl.position = Vector2(QUICKBAR_SLOT_SIZE - 28, 0)
			count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(count_lbl)

		# Equipped badge + green border for equippable items
		if em.is_equipped(item):
			var eq_lbl = Label.new()
			eq_lbl.text = "E"
			eq_lbl.add_theme_font_size_override("font_size", 10)
			eq_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
			eq_lbl.position = Vector2(2, 0)
			eq_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(eq_lbl)
			if sty:
				sty.border_color = Color(0.2, 0.6, 0.2)
				sty.set_border_width_all(2)

		# "R" key hint for shields and items with special abilities
		if item.slot_type == EquipmentItem.SlotType.SHIELD or (item.ability_id != "" and item.ability_id != null):
			var r_lbl = Label.new()
			r_lbl.text = "R"
			r_lbl.add_theme_font_size_override("font_size", 18)
			r_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			r_lbl.position = Vector2(QUICKBAR_SLOT_SIZE - 16, 0)
			r_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(r_lbl)

func _on_quickbar_pressed(slot_index: int) -> void:
	if not _player:
		return
	var item_name = _quickbar_items[slot_index]
	if item_name == "":
		return
	var em = _player.equipment_manager
	for i in range(em.inventory.size()):
		var item = em.inventory[i]
		if item.item_name == item_name:
			var sfx = get_node_or_null("/root/SFXManager")
			if item.slot_type == EquipmentItem.SlotType.CONSUMABLE:
				em.use_consumable(i)
			else:
				em.toggle_equip(i)
				if sfx:
					sfx.play("click", -5.0)
			return

func _build_stealth_indicator() -> void:
	_stealth_indicator = Label.new()
	_stealth_indicator.text = ""
	_stealth_indicator.add_theme_font_size_override("font_size", 14)
	_stealth_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_stealth_indicator.position = Vector2(MARGIN, MARGIN + BAR_HEIGHT + MP_BAR_HEIGHT + STAMINA_BAR_HEIGHT + XP_BAR_HEIGHT + 30)
	_stealth_indicator.visible = false
	add_child(_stealth_indicator)
	_stealth_kill_prompt = Label.new()
	_stealth_kill_prompt.text = "[E] KILL"
	_stealth_kill_prompt.add_theme_font_size_override("font_size", 12)
	_stealth_kill_prompt.add_theme_color_override("font_color", Color(0.9, 0.2, 0.9))
	_stealth_kill_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stealth_kill_prompt.visible = false
	add_child(_stealth_kill_prompt)

func _update_stealth_indicator() -> void:
	if not _player or not _stealth_indicator:
		return
	if not _player.is_sneaking():
		_stealth_indicator.visible = false
		_stealth_kill_prompt.visible = false
		return
	_stealth_indicator.visible = true
	# Find highest awareness of nearby enemies
	var max_awareness: float = 0.0
	for enemy in _player.get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.state == enemy.State.DEAD:
			continue
		if _player.global_position.distance_to(enemy.global_position) > 120.0:
			continue
		if enemy.has_method("get_awareness"):
			max_awareness = maxf(max_awareness, enemy.get_awareness())
	# Set indicator state
	if max_awareness < 0.3:
		_stealth_indicator.text = "(-) HIDDEN"
		_stealth_indicator.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	elif max_awareness < 0.7:
		_stealth_indicator.text = "(?) DETECTED"
		_stealth_indicator.add_theme_color_override("font_color", Color(0.9, 0.9, 0.2))
	else:
		_stealth_indicator.text = "(!) ALERT"
		_stealth_indicator.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	# Stealth kill prompt
	if _player.has_method("get_stealth_kill_target"):
		var target = _player.get_stealth_kill_target()
		if target:
			_stealth_kill_prompt.visible = true
			var vp = _player.get_viewport()
			if vp and vp.get_camera_2d():
				var cam = vp.get_camera_2d()
				var screen_pos = target.global_position - cam.global_position + Vector2(vp.get_visible_rect().size) / 2.0
				_stealth_kill_prompt.position = screen_pos + Vector2(-20, -20)
		else:
			_stealth_kill_prompt.visible = false
	else:
		_stealth_kill_prompt.visible = false
