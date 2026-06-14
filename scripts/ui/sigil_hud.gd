class_name SigilHUD
extends CanvasLayer

## Ashfields "Sigil" HUD.
##
## - HP orb bottom-left, with stamina ring around it.
## - Class-meter orb bottom-right (fills with current class color: Rage/Adrenaline/Focus/Mana Flow),
##   with MP shown as a ring around it.
## - Level + XP panel top-left.
## - Spell rune column mid-left, 6 carved runes (cooldown sweep, gold glow when ready).
## - Quickbar dock bottom-center (sits above the touch joysticks on mobile).
## - Small minimap top-right.
## - Quest objective arrow on screen edge when target is off-screen.
##
## Public API mirrors GameHUD so callers can use either:
##   setup(player), set_gold(), set_floor_info(), set_room_info(), setup_minimap(),
##   update_minimap_room(), hide_minimap(), flash_text(), set_quest_objective(),
##   clear_quest_objective(), _quickbar_items, _refresh_quickbar()

# ── Palette (mirrors AshfieldsUI) ──
const HP_FILL := Color(0.604, 0.106, 0.106)
const HP_BG := Color(0.149, 0.055, 0.055, 0.95)
const MP_FILL := Color(0.486, 0.227, 0.929)
const MP_BG := Color(0.118, 0.067, 0.227, 0.95)
const STAM_FILL := Color(0.918, 0.702, 0.031)
const STAM_BG := Color(0.149, 0.114, 0.024, 0.85)
const GOLD := Color(0.918, 0.702, 0.031)
const GOLD_DARK := Color(0.792, 0.541, 0.016)
const TEXT := Color(0.973, 0.980, 0.984)
const TEXT_MUTED := Color(0.659, 0.635, 0.616)
const ARCANE := Color(0.486, 0.227, 0.929)
const PANEL_BG := Color(0.110, 0.098, 0.090, 0.92)
const BORDER := Color(0.471, 0.443, 0.420)

# ── Layout constants ──
const ORB_RADIUS := 60.0
const ORB_MARGIN := 24.0
const SPELL_RUNE_SIZE := 64.0
const SPELL_RUNE_GAP := 76.0
const SPELL_SLOTS := 7  # was 6 — 7th slot for the key-0 spell
const SPELL_KEYS := ["4", "5", "6", "7", "8", "9", "0"]
const QUICKBAR_SLOTS := 6  # data slots stay 6; only first 3 have hotkeys (1/2/3)
const QUICKBAR_SLOT_SIZE := 80.0
const QUICKBAR_ICON_SIZE := 56.0

# ── Player ref ──
var _player: CharacterBody2D

# ── Quickbar state (mirrors GameHUD) ──
var _quickbar_items: Array[String] = ["", "", "", "", "", ""]
var _quickbar_buttons: Array[Button] = []

# ── Orb nodes ──
var _hp_orb: _Orb
var _class_orb: _Orb  # Right orb: class meter fill + MP ring around it
var _class_meter_label: Label  # "RAGE 50%" floating above the class orb
var _level_label: Label  # Small "Lv N" pill near the HP orb

# ── Top-left XP / level panel ──
var _xp_panel: Panel
var _xp_bar_bg: ColorRect
var _xp_bar_fill: ColorRect
var _xp_level_label: Label  # Big "LEVEL 5" headline
var _xp_amount_label: Label  # "1200 / 3500" overlay on the bar
const _XP_PANEL_W := 220.0
const _XP_PANEL_H := 56.0
const _XP_BAR_H := 10.0

# ── Spell rune column ──
var _spell_runes: Array = []  # holds the action-bar spell Buttons (was _SpellRune)

# ── Top zone / floor banner ──
var _zone_label: Label
var _floor_label: Label
var _gold_pill: Label
var _gold_anim: Tween

# ── Minimap ──
var _minimap_panel: Control
var _minimap_floor_map: Dictionary = {}
var _minimap_rects: Dictionary = {}
var _minimap_current: Vector2i = Vector2i.ZERO
var _minimap_size := Vector2(180, 140)

# ── Quest arrow ──
var _quest_arrow: Control
var _quest_arrow_label: Label
var _quest_pos: Vector2 = Vector2.ZERO
var _quest_visible: bool = false

# ── Flash text ──
var _flash_label: Label
var _flash_tween: Tween


func _ready() -> void:
	layer = 100
	add_to_group("game_hud")
	# Build synchronously so setup(player) (called right after add_child) can
	# write into _hp_orb / _class_orb without hitting Nil.
	_build_orbs()
	_build_action_bar()  # one function, all 10 slots, no panels, no anchors
	_build_zone_banner()
	_build_minimap_panel()
	_build_quest_arrow()
	_build_flash_label()
	_build_xp_panel()
	# Reposition once after first viewport size is locked in.
	call_deferred("_reposition_for_viewport")
	set_process(true)
	get_viewport().size_changed.connect(_reposition_for_viewport)


## Bottom-anchored layout (Diablo / Genshin pattern). Orbs flank the quickbar,
## all on the same bottom row, above the touch joysticks on mobile.
## - HP orb: bottom-left of action area
## - Quickbar: bottom-center
## - MP orb: bottom-right of action area
## - Level badge: stacked above HP orb
## - Minimap: top-right (small)
## - Zone fade banner: top-center (transient)
func _reposition_for_viewport() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var orb_d: float = ORB_RADIUS * 2.0

	# Stamina ring extends ~10px outside the orb, keep margin generous
	var safe_y: float = vp_size.y - orb_d - 28.0  # bottom row top edge
	if _hp_orb:
		_hp_orb.position = Vector2(ORB_MARGIN + 16, safe_y)
	if _class_orb:
		_class_orb.position = Vector2(vp_size.x - ORB_MARGIN - orb_d - 16, safe_y)
	# Level label is removed. Class meter label sits centered INSIDE the orb.
	if _class_meter_label and _class_orb:
		_class_meter_label.position = _class_orb.position
		_class_meter_label.size = Vector2(ORB_RADIUS * 2, ORB_RADIUS * 2)

	# Banner + minimap + flash live at the top (free of action congestion)
	if _zone_label:
		_zone_label.position = Vector2(vp_size.x * 0.5 - 300, 20)
	if _floor_label:
		_floor_label.position = Vector2(vp_size.x * 0.5 - 300, 56)
	if _gold_pill:
		_gold_pill.position = Vector2(vp_size.x * 0.5 - 100, 96)
	if _minimap_panel:
		_minimap_panel.position = Vector2(vp_size.x - _minimap_size.x - 8, 8)
	if _flash_label:
		_flash_label.position = Vector2(vp_size.x * 0.5 - 450, vp_size.y * 0.4)
	if _xp_panel:
		_xp_panel.position = Vector2(8, 8)

	_reposition_quickbar()


func _reposition_quickbar() -> void:
	if _quickbar_buttons.is_empty():
		return
	var vp_size := get_viewport().get_visible_rect().size
	var total_w: float = QUICKBAR_SLOTS * QUICKBAR_SLOT_SIZE + (QUICKBAR_SLOTS - 1) * 8.0
	var start_x: float = vp_size.x * 0.5 - total_w * 0.5
	# Quickbar sits at the same vertical centre as the orbs so they form one row.
	var orb_centre_y: float = vp_size.y - ORB_RADIUS - 28.0
	var y: float = orb_centre_y - QUICKBAR_SLOT_SIZE * 0.5
	for i in _quickbar_buttons.size():
		_quickbar_buttons[i].position = Vector2(start_x + i * (QUICKBAR_SLOT_SIZE + 8.0), y)


func setup(player: CharacterBody2D) -> void:
	_player = player
	player.hp_changed.connect(_on_hp_changed)
	player.mp_changed.connect(_on_mp_changed)
	player.stamina_changed.connect(_on_stamina_changed)
	player.xp_changed.connect(_on_xp_changed)
	player.level_system.leveled_up.connect(_on_level_up)
	player.equipment_manager.inventory_changed.connect(_refresh_quickbar)
	player.equipment_manager.stats_changed.connect(_refresh_quickbar)
	if player.has_signal("class_meter_changed"):
		player.class_meter_changed.connect(_on_class_meter_changed)
		var pc_id = player._get_player_class() if player.has_method("_get_player_class") else ""
		_update_class_meter_label_for_class(pc_id)
		# Seed initial value so the orb fill renders even at 0%
		var init_val = float(player.get("class_meter")) if "class_meter" in player else 0.0
		var init_max = float(player.get("class_meter_max")) if "class_meter_max" in player else 100.0
		_on_class_meter_changed(init_val, init_max)

	_hp_orb.set_value(player.hp, player.max_hp)
	_hp_orb.set_ring(player.stamina, player.max_stamina)
	_class_orb.set_ring(player.mp, player.max_mp)  # MP is the ring now
	_set_level(player.level_system.level)
	_update_xp_bar(float(player.level_system.xp), float(player.level_system.xp_to_next_level()))

	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("load_quickbar"):
		gm.load_quickbar(self)
	# Auto-pop quickbar starter items if completely empty
	var any := false
	for s in _quickbar_items:
		if s != "":
			any = true
			break
	if not any:
		_quickbar_items[0] = "Red Potion"
		_quickbar_items[1] = "Apple"
	_refresh_quickbar()


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	# Quest arrow follow
	if _quest_visible and _quest_arrow:
		_update_quest_arrow()


# ──────────────────────────────────────────────────────────────
# Orbs
# ──────────────────────────────────────────────────────────────

func _build_orbs() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	_hp_orb = _Orb.new()
	_hp_orb.orb_size = ORB_RADIUS * 2
	_hp_orb.fill_color = HP_FILL
	_hp_orb.bg_color = HP_BG
	_hp_orb.ring_color = STAM_FILL
	_hp_orb.ring_bg = STAM_BG
	_hp_orb.has_ring = true
	_hp_orb.position = Vector2(ORB_MARGIN, ORB_MARGIN)
	add_child(_hp_orb)

	# Right orb: class meter fill (color per class) + MP ring around it.
	# Fill colour is overwritten by _update_class_meter_label_for_class() once
	# the player class is known; the neutral grey is just a startup placeholder.
	_class_orb = _Orb.new()
	_class_orb.orb_size = ORB_RADIUS * 2
	_class_orb.fill_color = Color(0.55, 0.55, 0.55)
	_class_orb.bg_color = Color(0.10, 0.10, 0.13, 0.95)
	_class_orb.has_ring = true
	_class_orb.ring_color = MP_FILL
	_class_orb.ring_bg = MP_BG
	_class_orb.fill_ratio = 0.0  # meter starts empty
	_class_orb.position = Vector2(vp_size.x - ORB_MARGIN - ORB_RADIUS * 2, ORB_MARGIN)
	add_child(_class_orb)

	# Class meter label — sits above the orb like the level label sits above HP.
	# Starts hidden; populated when the player class is known.
	_class_meter_label = Label.new()
	_class_meter_label.text = ""
	_class_meter_label.add_theme_font_size_override("font_size", 18)
	_class_meter_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	_class_meter_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_class_meter_label.add_theme_constant_override("outline_size", 3)
	add_child(_class_meter_label)

	# Level badge removed by request — the HP orb no longer shows "Lv N".
	# Mana Flow / Rage / Focus percentage moves to a label CENTERED INSIDE the
	# class orb instead of floating above it.
	if _class_meter_label and is_instance_valid(_class_meter_label):
		_class_meter_label.queue_free()
	_class_meter_label = Label.new()
	_class_meter_label.text = ""
	_class_meter_label.add_theme_font_size_override("font_size", 22)
	_class_meter_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_class_meter_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_class_meter_label.add_theme_constant_override("outline_size", 3)
	_class_meter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_class_meter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_class_meter_label.size = Vector2(ORB_RADIUS * 2, ORB_RADIUS * 2)
	_class_meter_label.position = _class_orb.position
	_class_meter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_class_meter_label.z_index = 5
	add_child(_class_meter_label)


func _on_hp_changed(hp: float) -> void:
	if _player and _hp_orb:
		_hp_orb.set_value(hp, _player.max_hp)


func _on_mp_changed(mp: float) -> void:
	# MP is now displayed as the ring around the class-meter orb.
	if _player and _class_orb:
		_class_orb.set_ring(mp, _player.max_mp)


func _on_stamina_changed(stam: float) -> void:
	if _player and _hp_orb:
		_hp_orb.set_ring(stam, _player.max_stamina)


func _on_xp_changed(xp: float, xp_needed: float) -> void:
	_update_xp_bar(xp, xp_needed)


func _on_level_up(lvl: int) -> void:
	_set_level(lvl)
	# Re-pull XP-to-next so the bar shows the new level's curve immediately.
	if _player and _player.level_system:
		var needed = float(_player.level_system.xp_to_next_level())
		_update_xp_bar(float(_player.level_system.xp), needed)


func _set_level(lvl: int) -> void:
	# Level label removed from the HUD; only update the big XP screen if present.
	if _xp_level_label:
		_xp_level_label.text = "LEVEL %d" % lvl


func _build_xp_panel() -> void:
	_xp_panel = Panel.new()
	_xp_panel.size = Vector2(_XP_PANEL_W, _XP_PANEL_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.07, 0.92)
	sb.border_color = GOLD_DARK
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 4
	_xp_panel.add_theme_stylebox_override("panel", sb)
	add_child(_xp_panel)

	_xp_level_label = Label.new()
	_xp_level_label.text = "LEVEL 1"
	_xp_level_label.add_theme_font_size_override("font_size", 18)
	_xp_level_label.add_theme_color_override("font_color", GOLD)
	_xp_level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_xp_level_label.add_theme_constant_override("outline_size", 2)
	_xp_level_label.position = Vector2(10, 4)
	_xp_panel.add_child(_xp_level_label)

	# XP bar background
	_xp_bar_bg = ColorRect.new()
	_xp_bar_bg.color = Color(0.10, 0.10, 0.13, 0.95)
	_xp_bar_bg.position = Vector2(10, _XP_PANEL_H - _XP_BAR_H - 8)
	_xp_bar_bg.size = Vector2(_XP_PANEL_W - 20, _XP_BAR_H)
	_xp_panel.add_child(_xp_bar_bg)

	# XP bar fill — gold, grows left → right
	_xp_bar_fill = ColorRect.new()
	_xp_bar_fill.color = GOLD
	_xp_bar_fill.position = Vector2(10, _XP_PANEL_H - _XP_BAR_H - 8)
	_xp_bar_fill.size = Vector2(0, _XP_BAR_H)
	_xp_panel.add_child(_xp_bar_fill)

	# XP amount overlay ("1200 / 3500"), centred on the bar
	_xp_amount_label = Label.new()
	_xp_amount_label.text = "0 / 0"
	_xp_amount_label.add_theme_font_size_override("font_size", 11)
	_xp_amount_label.add_theme_color_override("font_color", Color(0.97, 0.97, 0.97))
	_xp_amount_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_xp_amount_label.add_theme_constant_override("outline_size", 2)
	_xp_amount_label.position = Vector2(10, _XP_PANEL_H - _XP_BAR_H - 10)
	_xp_amount_label.size = Vector2(_XP_PANEL_W - 20, _XP_BAR_H + 4)
	_xp_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_xp_panel.add_child(_xp_amount_label)


func _update_xp_bar(xp: float, xp_needed: float) -> void:
	if not _xp_bar_fill:
		return
	var ratio = 0.0 if xp_needed <= 0.0 else clampf(xp / xp_needed, 0.0, 1.0)
	_xp_bar_fill.size = Vector2((_XP_PANEL_W - 20) * ratio, _XP_BAR_H)
	if _xp_amount_label:
		_xp_amount_label.text = "%d / %d" % [int(xp), int(xp_needed)]


# ──────────────────────────────────────────────────────────────
# Unified bottom action bar — 3 quickbar items + 7 spells = 10 buttons
# ──────────────────────────────────────────────────────────────

const ACTION_BAR_SIZE := 80.0
const ACTION_BAR_GAP := 8.0
const ACTION_BAR_TOTAL := 10
const ACTION_BAR_BOTTOM_MARGIN := 24.0
const ACTION_BAR_LABELS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
const ACTION_BAR_WIDTH := ACTION_BAR_TOTAL * ACTION_BAR_SIZE + (ACTION_BAR_TOTAL - 1) * ACTION_BAR_GAP
var _action_bar_panel: Control  # legacy ref — kept for save/migration code paths


# Project is locked to 1920×1080 viewport (project.godot). Hardcode so we never
# get a 0×0 viewport at build time.
const _HUD_WIDTH := 1920.0
const _HUD_HEIGHT := 1080.0


func _action_bar_slot_world_pos(index: int) -> Vector2:
	var start_x := _HUD_WIDTH * 0.5 - ACTION_BAR_WIDTH * 0.5
	var y := _HUD_HEIGHT - ACTION_BAR_SIZE - ACTION_BAR_BOTTOM_MARGIN
	return Vector2(start_x + index * (ACTION_BAR_SIZE + ACTION_BAR_GAP), y)


# Single builder for ALL 10 slots. No parent container, no anchors. Direct
# children of the HUD CanvasLayer. Quickbar refs land in _quickbar_buttons
# (first 3 visible + 3 hidden off-screen for the inventory data slots);
# spell refs land in _spell_runes.
func _build_action_bar() -> void:
	# Visible quickbar slots 0, 1, 2 (hotkeys 1, 2, 3).
	for i in 3:
		var btn := _make_action_bar_slot(i)
		btn.position = _action_bar_slot_world_pos(i)
		var slot_idx = i
		btn.pressed.connect(func(): _on_quickbar_pressed(slot_idx))
		add_child(btn)
		_quickbar_buttons.append(btn)
	# Hidden quickbar data slots 3, 4, 5 (inventory drag/drop still references them).
	for i in range(3, QUICKBAR_SLOTS):
		var hidden_btn := Button.new()
		hidden_btn.focus_mode = Control.FOCUS_NONE
		hidden_btn.custom_minimum_size = Vector2(ACTION_BAR_SIZE, ACTION_BAR_SIZE)
		hidden_btn.size = hidden_btn.custom_minimum_size
		hidden_btn.position = Vector2(-1000, -1000)
		hidden_btn.visible = false
		var hidden_idx = i
		hidden_btn.pressed.connect(func(): _on_quickbar_pressed(hidden_idx))
		add_child(hidden_btn)
		_quickbar_buttons.append(hidden_btn)
	# Visible spell slots 3..9 of the action bar (hotkeys 4-0).
	for s in SPELL_SLOTS:
		var bar_index := 3 + s
		var btn2 := _make_action_bar_slot(bar_index)
		btn2.position = _action_bar_slot_world_pos(bar_index)
		add_child(btn2)
		_spell_runes.append(btn2)


func _make_action_bar_slot(bar_index: int) -> Button:
	# One shared chrome for all 10 slots — items, spells, anything.
	# Caller is responsible for setting btn.position (world coords) and parenting.
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(ACTION_BAR_SIZE, ACTION_BAR_SIZE)
	btn.size = btn.custom_minimum_size

	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.085, 0.072, 0.060, 0.92)
	sty.border_color = Color(0.55, 0.45, 0.22)
	sty.set_border_width_all(2)
	sty.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", sty)

	var hover := sty.duplicate()
	hover.bg_color = Color(0.15, 0.13, 0.10, 0.96)
	hover.border_color = Color(0.918, 0.702, 0.031)
	hover.set_border_width_all(3)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := sty.duplicate()
	pressed.bg_color = Color(0.06, 0.05, 0.04, 0.98)
	btn.add_theme_stylebox_override("pressed", pressed)

	# Hotkey badge in the top-left corner.
	var lbl := Label.new()
	lbl.text = ACTION_BAR_LABELS[bar_index]
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.position = Vector2(6, 4)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 10
	btn.add_child(lbl)
	return btn


# Kept as a no-op for older code paths that may reference it. Real building
# happens in _build_action_bar().
func _build_spell_column() -> void:
	pass


func _refresh_spell_slots() -> void:
	# Action-bar buttons just show a label for now; spell icons can be wired in
	# next pass via ItemIconHelper / a TextureRect child.
	if not _player:
		return
	var sb = _player.get("spell_book")
	if sb == null:
		return
	for i in _spell_runes.size():
		var btn := _spell_runes[i] as Button
		if not btn:
			continue
		var spell = null
		if i < sb.spell_slots.size():
			spell = sb.spell_slots[i]
		btn.tooltip_text = spell.spell_name if spell and "spell_name" in spell else ""


# ──────────────────────────────────────────────────────────────
# Quickbar dock (bottom-center)
# ──────────────────────────────────────────────────────────────

func _build_quickbar() -> void:
	# No-op — all action-bar building now happens in _build_action_bar().
	pass


const EQUIPPED_GREEN := Color(0.353, 0.918, 0.502)

func _refresh_quickbar() -> void:
	if not _player:
		return
	var em = _player.get("equipment_manager") as EquipmentManager
	for i in _quickbar_buttons.size():
		var btn := _quickbar_buttons[i]
		# Clear icon + count children
		for c in btn.get_children():
			if c is TextureRect:
				c.queue_free()
			elif c is Label and c.name == "CountLabel":
				c.queue_free()
		var item_name: String = _quickbar_items[i] if i < _quickbar_items.size() else ""
		var equipped := false
		if item_name != "" and em != null:
			var item: EquipmentItem = null
			var count := 0
			for inv_item in em.inventory:
				if inv_item and inv_item.item_name == item_name:
					if item == null:
						item = inv_item
					count += 1
			if item != null:
				if em.is_equipped(item):
					equipped = true
				var icon_tex := ItemIconHelper.get_icon_texture(item)
				if icon_tex:
					var tr := TextureRect.new()
					tr.texture = icon_tex
					tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					tr.size = Vector2(QUICKBAR_ICON_SIZE, QUICKBAR_ICON_SIZE)
					tr.position = Vector2(
						(QUICKBAR_SLOT_SIZE - QUICKBAR_ICON_SIZE) * 0.5,
						(QUICKBAR_SLOT_SIZE - QUICKBAR_ICON_SIZE) * 0.5
					)
					tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
					btn.add_child(tr)
				if count > 1:
					var cnt := Label.new()
					cnt.name = "CountLabel"
					cnt.text = "x%d" % count
					cnt.add_theme_font_size_override("font_size", 16)
					cnt.add_theme_color_override("font_color", TEXT)
					cnt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
					cnt.add_theme_constant_override("outline_size", 2)
					cnt.position = Vector2(QUICKBAR_SLOT_SIZE - 30, QUICKBAR_SLOT_SIZE - 24)
					cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
					btn.add_child(cnt)
		# Apply equipped highlight — green border + bg tint when this slot holds
		# the currently equipped item; otherwise the universal amber slot chrome.
		# Hover and pressed states are unchanged.
		var sty := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		if equipped:
			sty.bg_color = Color(0.094, 0.137, 0.075, 0.92)
			sty.border_color = EQUIPPED_GREEN
			sty.set_border_width_all(3)
		else:
			sty.bg_color = Color(0.085, 0.072, 0.060, 0.92)
			sty.border_color = Color(0.55, 0.45, 0.22)
			sty.set_border_width_all(2)
		btn.add_theme_stylebox_override("normal", sty)


## Called by both the quickbar button press and player.gd's number-key handler
## (Input.is_action_just_pressed("quickbar_N") → hud._on_quickbar_pressed(N-1)).
## Mirrors GameHUD: consumables get used, equippables get toggled.
func _on_quickbar_pressed(slot: int) -> void:
	if not _player:
		return
	if slot < 0 or slot >= _quickbar_items.size():
		return
	var item_name: String = _quickbar_items[slot]
	if item_name == "":
		return
	var em = _player.equipment_manager
	if em == null:
		return
	for i in em.inventory.size():
		var item = em.inventory[i]
		if item and item.item_name == item_name:
			if item.slot_type == EquipmentItem.SlotType.CONSUMABLE:
				em.use_consumable(i)
			else:
				em.toggle_equip(i)
			var sfx = get_node_or_null("/root/SFXManager")
			if sfx:
				sfx.play("click", -5.0)
			return


## Assign an item name to a quickbar slot (called by player.gd starter setup
## and by inventory_screen drag-to-quickbar). Mirrors GameHUD.
func assign_to_quickbar(slot_index: int, item_name: String) -> void:
	if slot_index < 0 or slot_index >= QUICKBAR_SLOTS:
		return
	_quickbar_items[slot_index] = item_name
	_refresh_quickbar()


func clear_quickbar_slot(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < QUICKBAR_SLOTS:
		_quickbar_items[slot_index] = ""
		_refresh_quickbar()


# ──────────────────────────────────────────────────────────────
# Top zone / floor / gold strip
# ──────────────────────────────────────────────────────────────

func _build_zone_banner() -> void:
	var vp_size := get_viewport().get_visible_rect().size

	_zone_label = Label.new()
	_zone_label.add_theme_font_size_override("font_size", 28)
	_zone_label.add_theme_color_override("font_color", GOLD)
	_zone_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_zone_label.add_theme_constant_override("outline_size", 3)
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_label.size = Vector2(600, 36)
	_zone_label.position = Vector2(vp_size.x * 0.5 - 300, 20)
	_zone_label.modulate.a = 0.0
	add_child(_zone_label)

	_floor_label = Label.new()
	_floor_label.add_theme_font_size_override("font_size", 20)
	_floor_label.add_theme_color_override("font_color", TEXT_MUTED)
	_floor_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_floor_label.add_theme_constant_override("outline_size", 2)
	_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_label.size = Vector2(600, 28)
	_floor_label.position = Vector2(vp_size.x * 0.5 - 300, 56)
	_floor_label.modulate.a = 0.0
	add_child(_floor_label)

	# Gold pill — only visible when gold changes
	_gold_pill = Label.new()
	_gold_pill.add_theme_font_size_override("font_size", 22)
	_gold_pill.add_theme_color_override("font_color", GOLD)
	_gold_pill.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_gold_pill.add_theme_constant_override("outline_size", 3)
	_gold_pill.size = Vector2(200, 30)
	_gold_pill.position = Vector2(vp_size.x * 0.5 - 100, 96)
	_gold_pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_pill.modulate.a = 0.0
	add_child(_gold_pill)


func set_gold(amount: int) -> void:
	_gold_pill.text = "%d gold" % amount
	if _gold_anim and _gold_anim.is_valid():
		_gold_anim.kill()
	_gold_anim = create_tween()
	_gold_anim.tween_property(_gold_pill, "modulate:a", 1.0, 0.18)
	_gold_anim.tween_interval(2.0)
	_gold_anim.tween_property(_gold_pill, "modulate:a", 0.0, 0.6)


func set_floor_info(floor_num: int, effective_floor: int = -1, area_name: String = "") -> void:
	var eff = effective_floor if effective_floor > 0 else floor_num
	var text := ""
	if area_name != "":
		text = "%s — Floor %d" % [area_name, eff]
	else:
		text = "Floor %d" % eff
	_show_banner(area_name if area_name != "" else "Floor %d" % eff, text)


func set_room_info(_text: String) -> void:
	# Room type info was part of the old HUD's clutter — dropped on purpose.
	pass


func _show_banner(zone: String, floor_text: String) -> void:
	_zone_label.text = zone
	_floor_label.text = floor_text
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_zone_label, "modulate:a", 1.0, 0.3)
	t.tween_property(_floor_label, "modulate:a", 0.85, 0.3)
	t.chain().tween_interval(2.5)
	t.tween_property(_zone_label, "modulate:a", 0.0, 0.7)
	t.tween_property(_floor_label, "modulate:a", 0.0, 0.7)


# ──────────────────────────────────────────────────────────────
# Minimap (small, top-right under MP orb)
# ──────────────────────────────────────────────────────────────

func _build_minimap_panel() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	_minimap_panel = Control.new()
	# Top-right corner flush — small 8px margin so it's not bleeding off-screen.
	_minimap_panel.position = Vector2(vp_size.x - _minimap_size.x - 8, 8)
	_minimap_panel.size = _minimap_size
	_minimap_panel.visible = false
	var bg := ColorRect.new()
	bg.color = PANEL_BG
	bg.size = _minimap_size
	_minimap_panel.add_child(bg)
	# Hint label beneath the minimap with first-step arrow + distance
	var hint := Label.new()
	hint.name = "MinimapHint"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hint.position = Vector2(0, _minimap_size.y + 2)
	hint.size = Vector2(_minimap_size.x, 18)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = ""
	_minimap_panel.add_child(hint)
	add_child(_minimap_panel)


func setup_minimap(floor_map: Dictionary, current: Vector2i, cell_size: float = 12.0) -> void:
	_minimap_panel.visible = true
	for c in _minimap_panel.get_children():
		if c is ColorRect and c.size != _minimap_size:
			c.queue_free()
	_minimap_rects.clear()
	_minimap_floor_map = floor_map
	for pos in floor_map.keys():
		var rect := ColorRect.new()
		rect.size = Vector2(cell_size - 2, cell_size - 2)
		rect.position = Vector2((pos.x - current.x) * cell_size + _minimap_size.x * 0.5, (pos.y - current.y) * cell_size + _minimap_size.y * 0.5)
		# Unvisited (incl. stairs) = uniform dark — no spoiler.
		rect.color = Color(0.10, 0.10, 0.12, 0.85)
		_minimap_panel.add_child(rect)
		_minimap_rects[pos] = rect
	_minimap_current = current
	update_minimap_room(current)
	# One-time path-to-stairs flash on floor entry.
	_flash_path_to_stairs_sigil(current)


func update_minimap_room(current: Vector2i) -> void:
	# Promote the just-left room to "visited" (grey), then set current room.
	if _minimap_rects.has(_minimap_current) and _minimap_current != current:
		var prev := _minimap_rects[_minimap_current] as ColorRect
		var prev_rd = _minimap_floor_map.get(_minimap_current) as RoomData
		if prev_rd and prev_rd.has_stairs_down:
			prev.color = Color(0.6, 0.5, 0.1)
		else:
			prev.color = Color(0.45, 0.45, 0.50, 0.95)  # visited
	_minimap_current = current
	if _minimap_rects.has(current):
		_minimap_rects[current].color = GOLD  # current = bright

func _flash_path_to_stairs_sigil(start_pos: Vector2i) -> void:
	if not _minimap_panel:
		return
	# Find the stairs room
	var goal = Vector2i.ZERO
	var has_goal := false
	for pos in _minimap_floor_map:
		var room = _minimap_floor_map[pos] as RoomData
		if room and room.has_stairs_down:
			goal = pos
			has_goal = true
			break
	if not has_goal:
		return
	# BFS over actual room connections (rooms are NOT at adjacent grid cells)
	var queue: Array = [start_pos]
	var came_from: Dictionary = {start_pos: start_pos}
	while queue.size() > 0:
		var p = queue.pop_front() as Vector2i
		if p == goal:
			break
		var rd = _minimap_floor_map.get(p) as RoomData
		if not rd:
			continue
		for dir_name in rd.connections:
			var n = rd.connections[dir_name] as Vector2i
			if came_from.has(n) or not _minimap_floor_map.has(n):
				continue
			came_from[n] = p
			queue.append(n)
	if not came_from.has(goal):
		return
	# Reconstruct path
	var path: Array = []
	var step = goal
	while step != start_pos:
		path.push_front(step)
		step = came_from[step]
	# Direction arrow from named connections
	var hint = _minimap_panel.get_node_or_null("MinimapHint") as Label
	if hint and path.size() > 0:
		var first_step = path[0] as Vector2i
		var start_rd = _minimap_floor_map.get(start_pos) as RoomData
		var arrow := "?"
		if start_rd:
			for dname in start_rd.connections:
				if start_rd.connections[dname] == first_step:
					match dname:
						"north": arrow = "↑"
						"south": arrow = "↓"
						"east": arrow = "→"
						"west": arrow = "←"
					break
		hint.text = "Stairs: %s  %d rooms" % [arrow, path.size()]
	# Light up each room on the path with a blue glow, staggered. Hold briefly then fade.
	for i in range(path.size()):
		var pos = path[i] as Vector2i
		if not _minimap_rects.has(pos):
			continue
		var rect = _minimap_rects[pos] as ColorRect
		var stagger = float(i) * 0.06  # snappier reveal
		var tw = create_tween()
		tw.tween_interval(stagger)
		tw.tween_callback(func():
			if is_instance_valid(rect):
				rect.color = Color(0.35, 0.75, 1.0, 1.0))
		tw.tween_interval(1.2)  # was 3.0 — hold is faster
		tw.tween_property(rect, "color", Color(0.10, 0.10, 0.12, 0.85), 0.6)
	if hint:
		var clear_tween = create_tween()
		clear_tween.tween_interval(1.8 + float(path.size()) * 0.06)
		clear_tween.tween_callback(func():
			if is_instance_valid(hint):
				hint.text = "")


func hide_minimap() -> void:
	_minimap_panel.visible = false


## Hide HUD chrome when a fullscreen panel opens (inventory, shop, etc.).
## Keep the quickbar visible — the inventory uses it for equip/use interactions
## via number keys + clicks instead of having its own duplicate sidebar.
func set_non_quickbar_visible(vis: bool) -> void:
	for child in get_children():
		if not (child is Control):
			continue
		if child in _quickbar_buttons:
			continue
		child.visible = vis


## Used by inventory drag-drop to find which quickbar slot a screen position is over.
func get_quickbar_slot_at_pos(screen_pos: Vector2) -> int:
	for i in _quickbar_buttons.size():
		var btn := _quickbar_buttons[i]
		var rect := Rect2(btn.position, btn.size)
		if rect.has_point(screen_pos):
			return i
	return -1


# ──────────────────────────────────────────────────────────────
# Quest arrow
# ──────────────────────────────────────────────────────────────

func _build_quest_arrow() -> void:
	_quest_arrow = Control.new()
	_quest_arrow.visible = false
	_quest_arrow.size = Vector2(48, 48)
	add_child(_quest_arrow)

	# Painted triangle via custom Control
	var painter := _QuestArrowPainter.new()
	painter.size = Vector2(48, 48)
	_quest_arrow.add_child(painter)

	_quest_arrow_label = Label.new()
	_quest_arrow_label.add_theme_font_size_override("font_size", 16)
	_quest_arrow_label.add_theme_color_override("font_color", GOLD)
	_quest_arrow_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_quest_arrow_label.add_theme_constant_override("outline_size", 2)
	_quest_arrow_label.position = Vector2(-30, 52)
	_quest_arrow_label.size = Vector2(120, 20)
	_quest_arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quest_arrow.add_child(_quest_arrow_label)


func set_quest_objective(pos: Vector2, label: String = "") -> void:
	_quest_pos = pos
	_quest_arrow_label.text = label
	_quest_visible = true
	_quest_arrow.visible = true


func clear_quest_objective() -> void:
	_quest_visible = false
	_quest_arrow.visible = false


func _update_quest_arrow() -> void:
	if not _player:
		return
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var screen_size := get_viewport().get_visible_rect().size
	var world_to_screen: Vector2 = (_quest_pos - cam.global_position) * cam.zoom + screen_size * 0.5
	var margin := 80.0
	var clamped := Vector2(
		clampf(world_to_screen.x, margin, screen_size.x - margin),
		clampf(world_to_screen.y, margin, screen_size.y - margin),
	)
	_quest_arrow.position = clamped - Vector2(24, 24)


# ──────────────────────────────────────────────────────────────
# Flash text
# ──────────────────────────────────────────────────────────────

func _build_flash_label() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	_flash_label = Label.new()
	_flash_label.add_theme_font_size_override("font_size", 26)
	_flash_label.add_theme_color_override("font_color", TEXT)
	_flash_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_flash_label.add_theme_constant_override("outline_size", 3)
	_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash_label.size = Vector2(900, 40)
	_flash_label.position = Vector2(vp_size.x * 0.5 - 450, vp_size.y * 0.35)
	_flash_label.modulate.a = 0.0
	add_child(_flash_label)


func flash_text(text: String, color: Color = Color.WHITE, duration: float = 2.0) -> void:
	_flash_label.text = text
	_flash_label.add_theme_color_override("font_color", color)
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_label, "modulate:a", 1.0, 0.2)
	_flash_tween.tween_interval(duration)
	_flash_tween.tween_property(_flash_label, "modulate:a", 0.0, 0.6)


# ──────────────────────────────────────────────────────────────
# Inner classes
# ──────────────────────────────────────────────────────────────

class _Orb extends Control:
	var orb_size: float = 120.0
	var bg_color: Color = Color(0.1, 0.0, 0.0, 0.95)
	var fill_color: Color = Color(0.8, 0.1, 0.1)
	var border_color: Color = Color(0.792, 0.541, 0.016)
	var has_ring: bool = false
	var ring_color: Color = Color(0.918, 0.702, 0.031)
	var ring_bg: Color = Color(0.15, 0.1, 0.0, 0.85)
	var ring_thick: float = 6.0
	var fill_ratio: float = 1.0
	var ring_ratio: float = 1.0

	func _ready() -> void:
		size = Vector2(orb_size, orb_size)
		queue_redraw()

	func set_value(cur: float, mx: float) -> void:
		fill_ratio = 0.0 if mx <= 0 else clampf(cur / mx, 0.0, 1.0)
		queue_redraw()

	func set_ring(cur: float, mx: float) -> void:
		ring_ratio = 0.0 if mx <= 0 else clampf(cur / mx, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var center := Vector2(orb_size * 0.5, orb_size * 0.5)
		var orb_r := orb_size * 0.5 - 2.0
		# Background circle
		draw_circle(center, orb_r, bg_color)
		# Liquid fill — bottom-up
		if fill_ratio > 0.0:
			var fh := orb_r * 2.0 * fill_ratio
			var clip_top := center.y + orb_r - fh
			# Approximate fill by drawing chunky rects clipped to circle
			var steps := 40
			for i in steps:
				var t := float(i) / float(steps)
				var y := center.y - orb_r + t * orb_r * 2.0
				if y < clip_top:
					continue
				var dy := y - center.y
				var half_w := sqrt(maxf(orb_r * orb_r - dy * dy, 0.0))
				draw_rect(Rect2(center.x - half_w, y, half_w * 2.0, orb_r * 2.0 / steps + 1.0), fill_color)
		# Specular highlight (small white arc upper-left)
		draw_arc(center + Vector2(-orb_r * 0.35, -orb_r * 0.35), orb_r * 0.35, PI * 0.9, PI * 1.4, 16, Color(1, 1, 1, 0.18), 2.0)
		# Border ring
		draw_arc(center, orb_r, 0.0, TAU, 64, border_color, 2.0)
		# Stamina ring outside the orb (if enabled)
		if has_ring:
			var ring_r := orb_r + ring_thick * 1.6
			# Background full ring
			draw_arc(center, ring_r, 0.0, TAU, 64, ring_bg, ring_thick)
			# Foreground arc — starts at top, clockwise, length = ring_ratio
			var start_angle := -PI * 0.5
			var end_angle := start_angle + TAU * ring_ratio
			draw_arc(center, ring_r, start_angle, end_angle, 64, ring_color, ring_thick)


class _SpellRune extends Control:
	var rune_size: float = 64.0
	var key_label_text: String = "F"
	var spell_def: Object = null
	var cooldown_ratio: float = 0.0  # 0=ready 1=full cooldown
	var glow_strength: float = 0.0

	func _ready() -> void:
		size = Vector2(rune_size, rune_size)
		queue_redraw()
		var lbl := Label.new()
		lbl.text = key_label_text
		lbl.add_theme_font_size_override("font_size", 16)
		# Match the quickbar slot label exactly: top-left corner, bright amber.
		lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		lbl.add_theme_constant_override("outline_size", 2)
		lbl.position = Vector2(6, 4)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.z_index = 10
		add_child(lbl)

	func set_spell(s: Object) -> void:
		spell_def = s
		queue_redraw()

	func clear_spell() -> void:
		spell_def = null
		queue_redraw()

	func _draw() -> void:
		# Match the quickbar slot chrome exactly: 80×80 filled, 2 px amber border,
		# rounded corners. No more sunken-inside-the-frame look.
		var has_spell := spell_def != null
		var center := Vector2(rune_size * 0.5, rune_size * 0.5)
		var r := rune_size * 0.5 - 2.0
		# Full-size base
		draw_rect(Rect2(0, 0, rune_size, rune_size), Color(0.085, 0.072, 0.060, 0.92), true)
		# 2 px amber border
		var border_col := Color(0.55, 0.45, 0.22)
		draw_rect(Rect2(0, 0, rune_size, rune_size), border_col, false, 2.0)
		if not has_spell:
			# Empty slot — thin diagonal scratch like a chalked-off rune
			draw_line(Vector2(rune_size * 0.3, rune_size * 0.3), Vector2(rune_size * 0.7, rune_size * 0.7), Color(0.4, 0.4, 0.4, 0.6), 1.0)
			return
		# Glow when ready (no cooldown)
		if cooldown_ratio <= 0.001:
			draw_circle(center, r * 0.6, Color(0.918, 0.702, 0.031, 0.18))
		# Center sigil placeholder — gold circle. (Replaced by an item icon
		# once we wire spell icons into the renderer.)
		draw_circle(center, r * 0.4, Color(0.792, 0.541, 0.016, 0.85))
		draw_arc(center, r * 0.4, 0.0, TAU, 32, Color(0.918, 0.702, 0.031), 2.0)
		# Cooldown sweep
		if cooldown_ratio > 0.0:
			var height := rune_size * cooldown_ratio
			draw_rect(Rect2(0, rune_size - height, rune_size, height), Color(0, 0, 0, 0.55), true)


class _QuestArrowPainter extends Control:
	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		# Gold diamond + base — points to objective
		var c := size * 0.5
		var col := Color(0.918, 0.702, 0.031)
		var dark := Color(0.792, 0.541, 0.016)
		var pts := PackedVector2Array([
			c + Vector2(0, -18),
			c + Vector2(12, 0),
			c + Vector2(0, 18),
			c + Vector2(-12, 0),
		])
		draw_colored_polygon(pts, col)
		# Outline
		for i in 4:
			draw_line(pts[i], pts[(i + 1) % 4], dark, 2.0)
		# Pin base — small circle below
		draw_circle(c + Vector2(0, 30), 6, col)
		draw_arc(c + Vector2(0, 30), 6, 0.0, TAU, 16, dark, 1.5)

# ── Class Meter (Rage / Mana Flow / Focus / Adrenaline) ────────────────────

var _meter_name: String = ""

const _METER_COLORS := {
	"warrior": Color(0.95, 0.25, 0.18),
	"wizard": Color(0.45, 0.55, 1.0),
	"ranger": Color(0.55, 1.0, 0.55),
	"archer": Color(0.55, 1.0, 0.55),
	"mercenary": Color(1.0, 0.75, 0.20),
}

const _METER_NAMES := {
	"warrior": "RAGE",
	"wizard": "MANA FLOW",
	"ranger": "FOCUS",
	"archer": "FOCUS",
	"mercenary": "ADRENALINE",
}

func _on_class_meter_changed(value: float, max_value: float) -> void:
	# Drives the right orb's fill + the small label above it.
	var ratio = clampf(value / maxf(max_value, 0.001), 0.0, 1.0)
	if _class_orb:
		_class_orb.set_value(value, max_value)
	if _class_meter_label:
		var disp_name: String = _meter_name if _meter_name != "" else "METER"
		_class_meter_label.text = "%s  %d%%" % [disp_name, int(ratio * 100.0)]

func _update_class_meter_label_for_class(class_id: String) -> void:
	_meter_name = String(_METER_NAMES.get(class_id, "METER"))
	var col: Color = _METER_COLORS.get(class_id, Color(0.7, 0.7, 0.7))
	if _class_meter_label:
		_class_meter_label.text = _meter_name + "  0%"
		_class_meter_label.add_theme_color_override("font_color", col)
	if _class_orb:
		_class_orb.fill_color = col
		_class_orb.queue_redraw()
