class_name AshfieldsUI
extends RefCounted

## Reusable UI widget builders for the Ashfields theme.
## Static helpers — call like `AshfieldsUI.section_title("INVENTORY")`.
##
## Conventions:
## - Returns ready-to-add Control nodes.
## - All callers should attach the Ashfields Theme upstream; widgets won't load it.
## - Pixel font (Press Start 2P) for section titles; VT323 default for body via theme.

const GOLD := Color(0.918, 0.702, 0.031)
const GOLD_DARK := Color(0.792, 0.541, 0.016)
const BG_PANEL := Color(0.110, 0.098, 0.090, 0.96)
const BG_DEEP := Color(0.059, 0.059, 0.102, 0.97)
const BORDER := Color(0.471, 0.443, 0.420)
const BORDER_DIM := Color(0.267, 0.251, 0.235)
const TEXT := Color(0.973, 0.980, 0.984)
const TEXT_MUTED := Color(0.659, 0.635, 0.616)
const BLOOD := Color(0.604, 0.106, 0.106)
const ARCANE := Color(0.486, 0.227, 0.929)

# Rarity tier → fill border colour (matches inventory_screen.gd RARITY_COLORS)
const RARITY_BORDER := [
	Color(0.471, 0.443, 0.420), # 0 common — bone border
	Color(0.918, 0.702, 0.031), # 1 uncommon — gold border
	Color(0.640, 0.421, 0.998), # 2 rare — bright arcane border
]

const PIXEL_FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"


## A section title rendered in the pixel font with a gold underline.
## Use for screen and section headers (e.g. "INVENTORY", "BUY", "RECIPES").
## Default size 24 — Press Start 2P is very wide, keep titles short.
static func section_title(text: String, size: int = 32) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = text
	lbl.label_settings = LabelSettings.new()
	lbl.label_settings.font = load(PIXEL_FONT_PATH)
	lbl.label_settings.font_size = size
	lbl.label_settings.font_color = GOLD
	lbl.label_settings.outline_size = 2
	lbl.label_settings.outline_color = Color(0, 0, 0, 0.7)
	vbox.add_child(lbl)

	var rule := ColorRect.new()
	rule.color = GOLD_DARK
	rule.custom_minimum_size = Vector2(0, 2)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(rule)

	return vbox


## Ornate framed panel: dark warm fill, thin border, gold corner brackets.
## Pass desired margins. Returns a PanelContainer with an inner Control reserved
## for content (use `panel.add_child(content)` directly).
static func ornate_panel(margin: int = 16, fill: Color = BG_PANEL) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = BORDER_DIM
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	pc.add_theme_stylebox_override("panel", sb)

	# Corner ornaments — child overlay that paints gold L-brackets
	var orn := _CornerOrnaments.new()
	orn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	orn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(orn)
	# Ensure ornaments draw on top of content — call_deferred so order is set after children
	pc.child_entered_tree.connect(func(_n): orn.move_to_front())

	return pc


## Pill button. Soft rounded, gold border on hover. Pass a colour `tint` to vary
## (red for danger, gold for primary, blue for info).
static func pill_button(text: String, tint: Color = GOLD_DARK) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(160, 56)
	btn.add_theme_font_size_override("font_size", 28)

	var normal := StyleBoxFlat.new()
	normal.bg_color = BG_PANEL.lerp(tint, 0.06)
	normal.border_color = tint.darkened(0.4)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(18)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = BG_PANEL.lerp(tint, 0.18)
	hover.border_color = tint
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = tint.darkened(0.5)
	pressed.border_color = tint.lightened(0.2)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = BG_PANEL.darkened(0.2)
	disabled.border_color = BORDER_DIM
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", GOLD)
	btn.add_theme_color_override("font_pressed_color", GOLD)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	btn.add_theme_constant_override("outline_size", 2)
	return btn


## Item card. Visual representation of an inventory item with rarity-coloured
## border, icon, name, price. Returns a Button (whole card is clickable).
static func item_card(item_name: String, price: int = -1, rarity: int = 0,
		icon: Texture2D = null, size: Vector2 = Vector2(240, 82)) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = size
	btn.clip_text = true

	var rarity_col: Color = RARITY_BORDER[clampi(rarity, 0, RARITY_BORDER.size() - 1)]

	var normal := StyleBoxFlat.new()
	normal.bg_color = BG_PANEL
	normal.border_color = rarity_col
	normal.set_border_width_all(1)
	normal.border_width_left = 3
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = BG_PANEL.lightened(0.06)
	hover.border_color = rarity_col.lightened(0.25)
	hover.border_width_left = 4
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = BG_DEEP
	btn.add_theme_stylebox_override("pressed", pressed)

	# Hide built-in button text (so we can lay out our own content)
	btn.text = ""

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)

	if icon:
		var tex := TextureRect.new()
		tex.texture = icon
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(64, 64)
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(tex)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = item_name
	name_lbl.add_theme_font_size_override("font_size", 32)
	name_lbl.add_theme_color_override("font_color", rarity_col.lightened(0.2))
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	name_lbl.add_theme_constant_override("outline_size", 2)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_lbl)

	if price >= 0:
		var price_lbl := Label.new()
		price_lbl.text = "%d  gold" % price
		price_lbl.add_theme_font_size_override("font_size", 26)
		price_lbl.add_theme_color_override("font_color", GOLD)
		price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(price_lbl)

	return btn


## Thin gold horizontal divider (decorative, not interactive).
static func divider() -> Control:
	var line := ColorRect.new()
	line.color = GOLD_DARK
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line


## Stat row: "STR" left, value right, with subtle muted style.
static func stat_row(label: String, value: String, value_color: Color = TEXT) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", TEXT_MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 26)
	v.add_theme_color_override("font_color", value_color)
	row.add_child(v)
	return row


## Inner class — Control overlay that paints gold L-brackets at the four corners
## of its parent panel. Mouse-transparent; sits on top of content.
class _CornerOrnaments extends Control:
	var bracket_len: float = 10.0
	var bracket_thick: float = 2.0
	var col: Color = Color(0.918, 0.702, 0.031, 0.85)

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		# Top-left
		draw_line(Vector2(0, 0), Vector2(bracket_len, 0), col, bracket_thick)
		draw_line(Vector2(0, 0), Vector2(0, bracket_len), col, bracket_thick)
		# Top-right
		draw_line(Vector2(w, 0), Vector2(w - bracket_len, 0), col, bracket_thick)
		draw_line(Vector2(w, 0), Vector2(w, bracket_len), col, bracket_thick)
		# Bottom-left
		draw_line(Vector2(0, h), Vector2(bracket_len, h), col, bracket_thick)
		draw_line(Vector2(0, h), Vector2(0, h - bracket_len), col, bracket_thick)
		# Bottom-right
		draw_line(Vector2(w, h), Vector2(w - bracket_len, h), col, bracket_thick)
		draw_line(Vector2(w, h), Vector2(w, h - bracket_len), col, bracket_thick)
