class_name GameHUD
extends CanvasLayer

var _player: CharacterBody2D

# Bar references
var _hp_bar_fill: ColorRect
var _hp_bar_label: Label
var _mp_bar_fill: ColorRect
var _mp_bar_label: Label
var _xp_bar_fill: ColorRect
var _level_label: Label

# Info panel (top-right)
var _info_line1: Label  # Floor / Zone
var _info_line2: Label  # Room type
var _info_line3: Label  # Gold

# Action buttons
var _btn_inventory: Button
var _btn_quest: Button

# Minimap
var _minimap_panel: Control
var _minimap_rects: Dictionary = {}  # Vector2i -> ColorRect
var _minimap_data: Dictionary = {}  # floor_map reference
var _minimap_current: Vector2i = Vector2i.ZERO

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
const XP_FILL = Color(0.8, 0.67, 0.2)
const XP_BG = Color(0.2, 0.13, 0.07)
const BADGE_BG = Color(0.2, 0.2, 0.2)
const BADGE_TEXT = Color(1.0, 0.8, 0.0)
const INFO_BG = Color(0.0, 0.0, 0.0, 0.6)

func _ready() -> void:
	layer = 100
	_build_vitals_panel()
	_build_info_panel()
	_build_action_buttons()

func setup(player: CharacterBody2D) -> void:
	_player = player
	player.hp_changed.connect(_on_hp_changed)
	player.mp_changed.connect(_on_mp_changed)
	player.xp_changed.connect(_on_xp_changed)
	player.level_system.leveled_up.connect(_on_level_up)

	_update_hp(player.hp, player.max_hp)
	_update_mp(player.mp, player.max_mp)
	_update_xp(player.level_system.xp, player.level_system.xp_to_next_level())
	_update_level(player.level_system.level)

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

	var tiles_tex = load("res://assets/sprites/loy/tiles.png") as Texture2D

	# Inventory button with bag icon (tile 99 = sack)
	_btn_inventory = _create_icon_button(tiles_tex, 99, "BAG")
	_btn_inventory.position = Vector2(1920 - 200 - MARGIN, 1080 - 56 - MARGIN)
	_btn_inventory.pressed.connect(_on_bag_pressed)
	panel.add_child(_btn_inventory)

	# Quest button with scroll icon (tile 100 = scroll)
	_btn_quest = _create_icon_button(tiles_tex, 100, "LOG")
	_btn_quest.position = Vector2(1920 - 200 - MARGIN + 80, 1080 - 56 - MARGIN)
	_btn_quest.pressed.connect(_on_log_pressed)
	panel.add_child(_btn_quest)

func _create_icon_button(sheet: Texture2D, sprite_index: int, label_text: String) -> Button:
	var btn = Button.new()
	btn.size = Vector2(72, 52)
	btn.focus_mode = Control.FOCUS_NONE  # prevent spacebar activating focused button

	# Dark styled background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.14, 0.85)
	style.border_color = Color(0.5, 0.4, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = Color(0.15, 0.12, 0.25, 0.9)
	hover.border_color = Color(0.8, 0.6, 0.3)
	btn.add_theme_stylebox_override("hover", hover)

	# Icon sprite from tiles.png (32x32 grid)
	if sheet:
		var icon_sprite = TextureRect.new()
		icon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var atlas = AtlasTexture.new()
		atlas.atlas = sheet
		var col = sprite_index % 16
		var row = sprite_index / 16
		atlas.region = Rect2(col * 32, row * 32, 32, 32)
		icon_sprite.texture = atlas
		icon_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_sprite.custom_minimum_size = Vector2(32, 32)
		icon_sprite.position = Vector2(20, 2)
		icon_sprite.size = Vector2(32, 32)
		btn.add_child(icon_sprite)

	# Text label below icon
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, 36)
	lbl.size = Vector2(72, 14)
	btn.add_child(lbl)

	return btn

func _on_bag_pressed() -> void:
	var inv = get_tree().get_first_node_in_group("inventory_screen")
	if inv and inv.has_method("toggle"):
		inv.toggle()

func _on_log_pressed() -> void:
	# Simulate Q key press
	var ev = InputEventAction.new()
	ev.action = "quest_log"
	ev.pressed = true
	Input.parse_input_event(ev)

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
		rect.color = Color(0.2, 0.2, 0.2)  # unvisited = dark

		if room.has_stairs_down:
			rect.color = Color(0.6, 0.5, 0.1)  # stairs = yellow-ish

		_minimap_panel.add_child(rect)
		_minimap_rects[pos] = rect

	update_minimap_room(start_pos)

func update_minimap_room(grid_pos: Vector2i) -> void:
	# Dim previous current room
	if _minimap_rects.has(_minimap_current):
		_minimap_rects[_minimap_current].color = Color(0.5, 0.5, 0.5)  # visited = grey

	_minimap_current = grid_pos
	if _minimap_rects.has(grid_pos):
		_minimap_rects[grid_pos].color = Color.WHITE  # current = white

# --- Public API ---

func set_floor_info(floor_num: int) -> void:
	_info_line1.text = "Floor " + str(floor_num)

func set_room_info(room_text: String) -> void:
	_info_line2.text = room_text

func set_zone_info(zone_name: String) -> void:
	_info_line1.text = zone_name

func set_gold(amount: int) -> void:
	_info_line3.text = "Gold: " + str(amount)

# --- Signal handlers ---

func _on_hp_changed(new_hp: int) -> void:
	if _player:
		_update_hp(new_hp, _player.max_hp)

func _on_mp_changed(new_mp: float) -> void:
	if _player:
		_update_mp(new_mp, _player.max_mp)

func _on_xp_changed(xp: int, xp_needed: int) -> void:
	_update_xp(xp, xp_needed)

func _on_level_up(new_level: int) -> void:
	_update_level(new_level)
	if _player:
		_update_xp(_player.level_system.xp, _player.level_system.xp_to_next_level())
		_update_hp(_player.hp, _player.max_hp)
		_update_mp(_player.mp, _player.max_mp)

# --- Internal ---

func _update_hp(current: int, maximum: int) -> void:
	var ratio = float(current) / maxi(maximum, 1)
	_hp_bar_fill.size.x = BAR_WIDTH * ratio
	_hp_bar_label.text = str(current) + "/" + str(maximum)

func _update_mp(current: float, maximum: float) -> void:
	var ratio = current / maxf(maximum, 1.0)
	_mp_bar_fill.size.x = BAR_WIDTH * ratio
	_mp_bar_label.text = str(int(current)) + "/" + str(int(maximum))

func _update_xp(current: int, needed: int) -> void:
	var ratio = float(current) / maxi(needed, 1)
	_xp_bar_fill.size.x = BAR_WIDTH * ratio

func _update_level(level: int) -> void:
	_level_label.text = "Lv." + str(level)
