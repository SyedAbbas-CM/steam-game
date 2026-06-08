class_name SigilHUD
extends CanvasLayer

## Ashfields "Sigil" HUD.
##
## - HP orb top-left, with stamina ring around it.
## - MP orb top-right.
## - Spell rune column mid-left, 6 carved runes (cooldown sweep, gold glow when ready).
## - Quickbar dock bottom-center (sits above the touch joysticks on mobile).
## - Small minimap top-right, below the MP orb.
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
const SPELL_SLOTS := 6
const SPELL_KEYS := ["F", "G", "H", "J", "K", "L"]
const QUICKBAR_SLOTS := 6
const QUICKBAR_SLOT_SIZE := 80.0
const QUICKBAR_ICON_SIZE := 56.0

# ── Player ref ──
var _player: CharacterBody2D

# ── Quickbar state (mirrors GameHUD) ──
var _quickbar_items: Array[String] = ["", "", "", "", "", ""]
var _quickbar_buttons: Array[Button] = []

# ── Orb nodes ──
var _hp_orb: _Orb
var _mp_orb: _Orb
var _level_label: Label

# ── Spell rune column ──
var _spell_runes: Array[_SpellRune] = []

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
	# write into _hp_orb / _mp_orb without hitting Nil.
	_build_orbs()
	_build_quickbar()
	_build_zone_banner()
	_build_minimap_panel()
	_build_quest_arrow()
	_build_flash_label()
	_build_class_meter()
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
	if _mp_orb:
		_mp_orb.position = Vector2(vp_size.x - ORB_MARGIN - orb_d - 16, safe_y)
	if _level_label:
		# Level sits ABOVE the HP orb (room is tighter at the bottom now)
		_level_label.position = Vector2(_hp_orb.position.x + ORB_RADIUS - 24, safe_y - 32)

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
	if _meter_panel:
		# Sit directly above the quickbar with a comfortable gap. Quickbar top
		# edge ≈ vp_size.y - 128 (slot top), so meter at vp_size.y - 200 keeps
		# ~50px of gap between the bar and the slots — easier to read while
		# playing, away from the top-center gold/zone text.
		_meter_panel.position = Vector2(vp_size.x * 0.5 - _METER_W * 0.5, vp_size.y - 200)

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
		# Show the meter immediately so it's visible at 0% — no need to wait for the
		# first build event.
		if _meter_panel:
			_meter_panel.visible = true
		# Seed initial value so the fill bar renders even at 0%
		var init_val = float(player.get("class_meter")) if "class_meter" in player else 0.0
		var init_max = float(player.get("class_meter_max")) if "class_meter_max" in player else 100.0
		_on_class_meter_changed(init_val, init_max)

	_hp_orb.set_value(player.hp, player.max_hp)
	_hp_orb.set_ring(player.stamina, player.max_stamina)
	_mp_orb.set_value(player.mp, player.max_mp)
	_set_level(player.level_system.level)

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

	_mp_orb = _Orb.new()
	_mp_orb.orb_size = ORB_RADIUS * 2
	_mp_orb.fill_color = MP_FILL
	_mp_orb.bg_color = MP_BG
	_mp_orb.has_ring = false
	_mp_orb.position = Vector2(vp_size.x - ORB_MARGIN - ORB_RADIUS * 2, ORB_MARGIN)
	add_child(_mp_orb)

	# Level badge — small pill below HP orb
	_level_label = Label.new()
	_level_label.text = "Lv 1"
	_level_label.add_theme_font_size_override("font_size", 22)
	_level_label.add_theme_color_override("font_color", GOLD)
	_level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_level_label.add_theme_constant_override("outline_size", 3)
	_level_label.position = Vector2(ORB_MARGIN + ORB_RADIUS - 24, ORB_MARGIN + ORB_RADIUS * 2 + 6)
	add_child(_level_label)


func _on_hp_changed(hp: float) -> void:
	if _player and _hp_orb:
		_hp_orb.set_value(hp, _player.max_hp)


func _on_mp_changed(mp: float) -> void:
	if _player and _mp_orb:
		_mp_orb.set_value(mp, _player.max_mp)


func _on_stamina_changed(stam: float) -> void:
	if _player and _hp_orb:
		_hp_orb.set_ring(stam, _player.max_stamina)


func _on_xp_changed(_xp: float) -> void:
	pass  # XP not shown permanently in sigil HUD


func _on_level_up(lvl: int) -> void:
	_set_level(lvl)


func _set_level(lvl: int) -> void:
	_level_label.text = "Lv %d" % lvl


# ──────────────────────────────────────────────────────────────
# Spell rune column (left side, mid-screen)
# ──────────────────────────────────────────────────────────────

func _build_spell_column() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var start_y: float = vp_size.y * 0.5 - (SPELL_SLOTS * SPELL_RUNE_GAP) * 0.5
	for i in SPELL_SLOTS:
		var rune := _SpellRune.new()
		rune.rune_size = SPELL_RUNE_SIZE
		rune.key_label_text = SPELL_KEYS[i]
		rune.position = Vector2(ORB_MARGIN, start_y + i * SPELL_RUNE_GAP)
		add_child(rune)
		_spell_runes.append(rune)


func _refresh_spell_slots() -> void:
	if not _player or not _player.has_method("get_equipped_spells"):
		return
	# spell_book.equipped_spells holds SpellDefinition refs in order
	var sb = _player.get("spell_book")
	if sb == null or not sb.has_method("get_equipped"):
		return
	var spells = sb.get_equipped() if sb.has_method("get_equipped") else null
	for i in _spell_runes.size():
		var rune := _spell_runes[i]
		if spells and i < spells.size() and spells[i] != null:
			rune.set_spell(spells[i])
		else:
			rune.clear_spell()


# ──────────────────────────────────────────────────────────────
# Quickbar dock (bottom-center)
# ──────────────────────────────────────────────────────────────

func _build_quickbar() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var total_w: float = QUICKBAR_SLOTS * QUICKBAR_SLOT_SIZE + (QUICKBAR_SLOTS - 1) * 8.0
	var start_x: float = vp_size.x * 0.5 - total_w * 0.5
	var y: float = vp_size.y - QUICKBAR_SLOT_SIZE - 32.0

	for i in QUICKBAR_SLOTS:
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(QUICKBAR_SLOT_SIZE, QUICKBAR_SLOT_SIZE)
		btn.size = btn.custom_minimum_size
		btn.position = Vector2(start_x + i * (QUICKBAR_SLOT_SIZE + 8.0), y)

		# Normal — dark panel, subtle warm border
		var sty := StyleBoxFlat.new()
		sty.bg_color = PANEL_BG
		sty.border_color = BORDER
		sty.set_border_width_all(2)
		sty.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sty)

		# Hover — bright gold border, slight bg lift
		var hover := sty.duplicate() as StyleBoxFlat
		hover.bg_color = PANEL_BG.lightened(0.10)
		hover.border_color = GOLD
		hover.set_border_width_all(3)
		btn.add_theme_stylebox_override("hover", hover)

		# Pressed — darker bg, full gold border
		var pressed_sty := sty.duplicate() as StyleBoxFlat
		pressed_sty.bg_color = Color(0.075, 0.067, 0.060, 0.95)
		pressed_sty.border_color = GOLD
		pressed_sty.set_border_width_all(3)
		btn.add_theme_stylebox_override("pressed", pressed_sty)

		# Focus — bright gold (keyboard navigation)
		var focus_sty := sty.duplicate() as StyleBoxFlat
		focus_sty.border_color = GOLD
		focus_sty.set_border_width_all(3)
		btn.add_theme_stylebox_override("focus", focus_sty)

		# Number badge
		var num := Label.new()
		num.text = str(i + 1)
		num.add_theme_font_size_override("font_size", 18)
		num.add_theme_color_override("font_color", GOLD)
		num.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		num.add_theme_constant_override("outline_size", 2)
		num.position = Vector2(6, 4)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(num)

		var slot_idx = i
		btn.pressed.connect(func(): _on_quickbar_pressed(slot_idx))
		add_child(btn)
		_quickbar_buttons.append(btn)


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
		# the currently equipped item. Hover and pressed states are unchanged.
		var sty := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		if equipped:
			sty.bg_color = Color(0.094, 0.137, 0.075, 0.92)
			sty.border_color = EQUIPPED_GREEN
			sty.set_border_width_all(3)
		else:
			sty.bg_color = PANEL_BG
			sty.border_color = BORDER
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
		lbl.add_theme_color_override("font_color", Color(0.918, 0.702, 0.031))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		lbl.add_theme_constant_override("outline_size", 2)
		lbl.position = Vector2(rune_size - 18, rune_size - 22)
		add_child(lbl)

	func set_spell(s: Object) -> void:
		spell_def = s
		queue_redraw()

	func clear_spell() -> void:
		spell_def = null
		queue_redraw()

	func _draw() -> void:
		var has_spell := spell_def != null
		var center := Vector2(rune_size * 0.5, rune_size * 0.5)
		var r := rune_size * 0.5 - 2.0
		# Stone base (always shown)
		draw_rect(Rect2(2, 2, rune_size - 4, rune_size - 4), Color(0.110, 0.098, 0.090, 0.92), true)
		draw_rect(Rect2(2, 2, rune_size - 4, rune_size - 4), Color(0.471, 0.443, 0.420), false, 1.0)
		if not has_spell:
			# Scratched empty rune
			draw_line(Vector2(rune_size * 0.3, rune_size * 0.3), Vector2(rune_size * 0.7, rune_size * 0.7), Color(0.4, 0.4, 0.4), 1.0)
			return
		# Glow when ready
		if cooldown_ratio <= 0.001:
			draw_circle(center, r * 0.6, Color(0.918, 0.702, 0.031, 0.18))
		# Center sigil — placeholder filled circle in gold
		draw_circle(center, r * 0.4, Color(0.792, 0.541, 0.016, 0.85))
		draw_arc(center, r * 0.4, 0.0, TAU, 32, Color(0.918, 0.702, 0.031), 2.0)
		# Cooldown sweep — a dark mask covering the bottom portion
		if cooldown_ratio > 0.0:
			var height := (rune_size - 4) * cooldown_ratio
			draw_rect(Rect2(2, 2 + (rune_size - 4) - height, rune_size - 4, height), Color(0, 0, 0, 0.55), true)


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

var _meter_panel: Panel
var _meter_fill: ColorRect
var _meter_label: Label
var _meter_name: String = ""
const _METER_W := 540.0  # wider so the % readout has room
const _METER_H := 22.0   # taller so it reads from the corner of your eye

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

func _build_class_meter() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	_meter_panel = Panel.new()
	_meter_panel.position = Vector2(vp_size.x * 0.5 - _METER_W * 0.5, vp_size.y - 200)
	_meter_panel.size = Vector2(_METER_W, _METER_H + 28)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.07, 0.92)
	sb.border_color = Color(0.42, 0.40, 0.36, 0.95)
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
	_meter_panel.add_theme_stylebox_override("panel", sb)
	add_child(_meter_panel)

	_meter_label = Label.new()
	_meter_label.add_theme_font_size_override("font_size", 16)
	_meter_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	_meter_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_meter_label.add_theme_constant_override("outline_size", 2)
	_meter_label.position = Vector2(10, 2)
	_meter_label.size = Vector2(_METER_W - 20, 22)
	_meter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meter_label.text = ""
	_meter_panel.add_child(_meter_label)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.10, 0.10, 0.13, 0.95)
	bar_bg.position = Vector2(6, 22)
	bar_bg.size = Vector2(_METER_W - 12, _METER_H)
	_meter_panel.add_child(bar_bg)

	_meter_fill = ColorRect.new()
	_meter_fill.position = Vector2(6, 22)
	_meter_fill.size = Vector2(0, _METER_H)
	_meter_fill.color = Color(1, 1, 1)
	_meter_panel.add_child(_meter_fill)

	_meter_panel.visible = false  # only shows once a class is set up

func _on_class_meter_changed(value: float, max_value: float) -> void:
	if not _meter_panel:
		return
	var ratio = clampf(value / maxf(max_value, 0.001), 0.0, 1.0)
	if _meter_fill:
		_meter_fill.size = Vector2((_METER_W - 12) * ratio, _METER_H)
	_meter_panel.visible = true
	if _meter_label:
		var disp_name: String = _meter_name if _meter_name != "" else "METER"
		_meter_label.text = disp_name + "  %d%%" % int(ratio * 100.0)

func _update_class_meter_label_for_class(class_id: String) -> void:
	if not _meter_panel:
		return
	_meter_name = String(_METER_NAMES.get(class_id, "METER"))
	var col: Color = _METER_COLORS.get(class_id, Color(0.7, 0.7, 0.7))
	if _meter_label:
		_meter_label.text = _meter_name + "  0%"
		_meter_label.add_theme_color_override("font_color", col)
	if _meter_fill:
		_meter_fill.color = col
