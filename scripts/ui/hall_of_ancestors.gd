class_name HallOfAncestors
extends Node2D

const ItemIconHelper = preload("res://scripts/ui/item_icon_helper.gd")

const CLASS_COLORS := {
	"warrior": Color(1.0, 0.85, 0.6),
	"mercenary": Color(1.0, 0.7, 0.5),
	"ranger": Color(0.7, 1.0, 0.7),
	"wizard": Color(0.7, 0.7, 1.0),
}

const ROOM_RECT := Rect2(-480.0, -300.0, 960.0, 600.0)
const INTERACT_RANGE := 84.0
const STATION_COLOR := Color(0.28, 0.24, 0.20, 1.0)
const STATION_HIGHLIGHT := Color(0.44, 0.37, 0.24, 1.0)
const FLOOR_DARK := Color(0.24, 0.21, 0.20)
const FLOOR_MID := Color(0.34, 0.30, 0.27)
const FLOOR_LIGHT := Color(0.48, 0.42, 0.37)
const WALL_COLOR := Color(0.58, 0.52, 0.47)
const COLUMN_COLOR := Color(0.68, 0.62, 0.56)
const SOUL_GLOW := Color(0.48, 0.74, 1.0, 0.90)

var _player: CharacterBody2D = null
var _camera: Camera2D = null
var _prompt_label: Label = null
var _panel_layer: CanvasLayer = null
var _panel: PanelContainer = null
var _panel_title: Label = null
var _panel_content: VBoxContainer = null
var _panel_status: Label = null
var _panel_close: Button = null
var _stations: Array[Area2D] = []
var _current_station: Area2D = null
var _selected_legacy_indices: Dictionary = {}

func _ready() -> void:
	var lm = get_node_or_null("/root/LightingManager")
	if lm and lm.has_method("reset"):
		lm.reset()
	if lm and lm.has_method("apply_scene_lighting_policy"):
		lm.apply_scene_lighting_policy(2, 1.34, 0.68)
	_build_world()
	_build_ui()
	_spawn_player()
	_spawn_stations()
	_spawn_ancestor_ghosts()

func _process(_delta: float) -> void:
	_update_nearest_station()

func _unhandled_input(event: InputEvent) -> void:
	if _panel and _panel.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_panel()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and _current_station:
		_open_station(_current_station)
		get_viewport().set_input_as_handled()

func _build_world() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.18, 0.16, 0.19)
	bg.position = Vector2(-1400, -900)
	bg.size = Vector2(2800, 1800)
	add_child(bg)

	# Outer shell and main nave.
	_build_floor_rect(Rect2(-450, -250, 900, 500), FLOOR_DARK)
	_build_floor_rect(Rect2(-128, -255, 256, 520), FLOOR_MID)
	_build_floor_rect(Rect2(-360, -164, 232, 200), FLOOR_MID)
	_build_floor_rect(Rect2(128, -164, 232, 200), FLOOR_MID)
	_build_floor_rect(Rect2(-360, 36, 232, 184), FLOOR_MID)
	_build_floor_rect(Rect2(128, 36, 232, 184), FLOOR_MID)
	_build_floor_rect(Rect2(-210, -214, 420, 108), FLOOR_LIGHT)
	_build_floor_rect(Rect2(-140, 82, 280, 130), FLOOR_LIGHT)

	# Main aisle tiles.
	for y in range(-216, 241, 48):
		_build_floor_rect(Rect2(-38, float(y), 76, 30), FLOOR_LIGHT)
	for y in range(-192, 241, 48):
		_build_floor_rect(Rect2(-94, float(y), 40, 18), FLOOR_MID)
		_build_floor_rect(Rect2(54, float(y), 40, 18), FLOOR_MID)

	# Structural walls.
	_build_wall_segment(Rect2(-500, -320, 1000, 24), WALL_COLOR)
	_build_wall_segment(Rect2(-500, 296, 1000, 24), WALL_COLOR)
	_build_wall_segment(Rect2(-504, -320, 24, 640), WALL_COLOR)
	_build_wall_segment(Rect2(480, -320, 24, 640), WALL_COLOR)
	_build_wall_segment(Rect2(-372, -182, 20, 130), WALL_COLOR)
	_build_wall_segment(Rect2(-372, 36, 20, 198), WALL_COLOR)
	_build_wall_segment(Rect2(352, -182, 20, 130), WALL_COLOR)
	_build_wall_segment(Rect2(352, 36, 20, 198), WALL_COLOR)
	_build_wall_segment(Rect2(-138, -250, 20, 104), WALL_COLOR)
	_build_wall_segment(Rect2(118, -250, 20, 104), WALL_COLOR)

	# Columns for the nave.
	for x in [-172.0, -116.0, 116.0, 172.0]:
		_build_column(Vector2(x, -112))
		_build_column(Vector2(x, -16))
		_build_column(Vector2(x, 82))
		_build_column(Vector2(x, 178))

	# Raised apse and the central well altar.
	_build_dais(Rect2(-156, -244, 312, 76))
	var center_well := Polygon2D.new()
	center_well.polygon = PackedVector2Array([
		Vector2(-58, -44),
		Vector2(58, -44),
		Vector2(78, 0),
		Vector2(58, 44),
		Vector2(-58, 44),
		Vector2(-78, 0),
	])
	center_well.color = Color(0.11, 0.18, 0.23)
	center_well.position = Vector2(0, -206)
	add_child(center_well)

	var inner_well := Polygon2D.new()
	inner_well.polygon = PackedVector2Array([
		Vector2(-34, -26),
		Vector2(34, -26),
		Vector2(44, 0),
		Vector2(34, 26),
		Vector2(-34, 26),
		Vector2(-44, 0),
	])
	inner_well.color = SOUL_GLOW
	inner_well.position = center_well.position
	add_child(inner_well)

	# Alcove framing.
	_build_alcove(Vector2(-244, -106), Vector2(136, 98))
	_build_alcove(Vector2(244, -106), Vector2(136, 98))
	_build_alcove(Vector2(-244, 122), Vector2(136, 106))
	_build_alcove(Vector2(244, 122), Vector2(136, 106))

	var well_label := Label.new()
	well_label.text = "Well of Souls"
	well_label.position = Vector2(-58, -212)
	well_label.add_theme_font_size_override("font_size", 16)
	well_label.add_theme_color_override("font_color", Color(0.84, 0.93, 1.0))
	add_child(well_label)

func _build_wall_segment(rect: Rect2, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	poly.color = color
	add_child(poly)

	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.position = rect.position + rect.size * 0.5
	body.add_child(shape)
	add_child(body)

func _build_floor_rect(rect: Rect2, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	poly.color = color
	add_child(poly)

func _build_column(pos: Vector2) -> void:
	var column := Polygon2D.new()
	column.position = pos
	column.polygon = PackedVector2Array([
		Vector2(-14, -14),
		Vector2(14, -14),
		Vector2(14, 14),
		Vector2(-14, 14),
	])
	column.color = COLUMN_COLOR
	add_child(column)

	var cap := Polygon2D.new()
	cap.position = pos + Vector2(0, -16)
	cap.polygon = PackedVector2Array([
		Vector2(-20, -5),
		Vector2(20, -5),
		Vector2(20, 5),
		Vector2(-20, 5),
	])
	cap.color = FLOOR_LIGHT
	add_child(cap)

func _build_dais(rect: Rect2) -> void:
	_build_floor_rect(rect, FLOOR_LIGHT)
	_build_floor_rect(Rect2(rect.position.x, rect.position.y + rect.size.y - 14.0, rect.size.x, 14.0), COLUMN_COLOR)

func _build_alcove(center: Vector2, size: Vector2) -> void:
	_build_floor_rect(Rect2(center.x - size.x * 0.5, center.y - size.y * 0.5, size.x, size.y), Color(0.12, 0.10, 0.11))
	_build_floor_rect(Rect2(center.x - size.x * 0.5 + 10.0, center.y - size.y * 0.5 + 10.0, size.x - 20.0, size.y - 20.0), FLOOR_DARK)

func _build_ui() -> void:
	_panel_layer = CanvasLayer.new()
	_panel_layer.layer = 20
	add_child(_panel_layer)

	_prompt_label = Label.new()
	_prompt_label.text = ""
	_prompt_label.visible = false
	_prompt_label.anchor_left = 0.5
	_prompt_label.anchor_right = 0.5
	_prompt_label.anchor_top = 1.0
	_prompt_label.anchor_bottom = 1.0
	_prompt_label.offset_left = -140
	_prompt_label.offset_top = -52
	_prompt_label.offset_right = 140
	_prompt_label.offset_bottom = -16
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.add_theme_color_override("font_color", Color(0.82, 1.0, 0.82))
	_panel_layer.add_child(_prompt_label)

	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.20)
	dimmer.visible = false
	_panel_layer.add_child(dimmer)

	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.anchor_left = 0.17
	_panel.anchor_right = 0.83
	_panel.anchor_top = 0.10
	_panel.anchor_bottom = 0.90
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.16, 0.18, 0.96)
	style.border_color = Color(0.64, 0.56, 0.44)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", style)
	_panel_layer.add_child(_panel)

	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 10)
	_panel.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	outer.add_child(header)

	_panel_title = Label.new()
	_panel_title.add_theme_font_size_override("font_size", 26)
	_panel_title.add_theme_color_override("font_color", Color(0.94, 0.86, 0.70))
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_panel_title)

	_panel_close = Button.new()
	_panel_close.text = "Close"
	_panel_close.pressed.connect(_close_panel)
	header.add_child(_panel_close)

	_panel_status = Label.new()
	_panel_status.add_theme_font_size_override("font_size", 14)
	_panel_status.add_theme_color_override("font_color", Color(0.74, 0.78, 0.82))
	outer.add_child(_panel_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	_panel_content = VBoxContainer.new()
	_panel_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_panel_content)

func _spawn_player() -> void:
	var player_scene = load("res://scenes/player.tscn") as PackedScene
	if not player_scene:
		return
	_player = player_scene.instantiate() as CharacterBody2D
	_player.position = Vector2(0, 236)
	_player.invincible = true
	add_child(_player)

	_camera = Camera2D.new()
	_camera.enabled = true
	# Was 0.85 (player invisible). Bumped to 8.5 (too tight), now 4.25 — close
	# enough to read the character clearly, still see the closest station.
	# Camera is parented to _player so it follows movement automatically.
	_camera.zoom = Vector2(4.25, 4.25)
	_player.add_child(_camera)

func _spawn_stations() -> void:
	_create_station("memorial", "Memorial", Vector2(-244, -108))
	_create_station("vault", "Legacy Vault", Vector2(244, -108))
	_create_station("audience", "Ghostly Audience", Vector2(-244, 126))
	_create_station("shrine", "Shrine of Souls", Vector2(244, 126))
	_create_station("barracks", "Barracks", Vector2(0, 176))

func _create_station(station_id: String, title: String, pos: Vector2) -> void:
	var area := Area2D.new()
	area.set_meta("station_id", station_id)
	area.set_meta("station_title", title)
	area.position = pos
	add_child(area)
	_stations.append(area)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 52.0
	shape.shape = circle
	area.add_child(shape)

	var base := Polygon2D.new()
	base.polygon = PackedVector2Array([
		Vector2(-40, -24), Vector2(40, -24), Vector2(52, 0), Vector2(40, 24), Vector2(-40, 24), Vector2(-52, 0)
	])
	base.color = STATION_COLOR
	area.add_child(base)
	area.set_meta("base_poly", base)

	var orb := Polygon2D.new()
	orb.polygon = PackedVector2Array([
		Vector2(-12, -12), Vector2(12, -12), Vector2(12, 12), Vector2(-12, 12)
	])
	orb.color = Color(0.78, 0.74, 0.62)
	area.add_child(orb)

	var label := Label.new()
	label.text = title
	label.position = Vector2(-48, 34)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.92, 0.84, 0.66))
	area.add_child(label)

func _spawn_ancestor_ghosts() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var sd: SaveData = gm.save_data if gm else null
	if not sd:
		return
	var ghost_positions := [
		Vector2(-412, -196),
		Vector2(-356, -196),
		Vector2(356, -196),
		Vector2(412, -196),
		Vector2(-412, 214),
		Vector2(412, 214),
	]
	var count := mini(ghost_positions.size(), sd.ancestor_records.size())
	for i in range(count):
		var entry: Dictionary = sd.ancestor_records[i]
		var ghost := Polygon2D.new()
		ghost.polygon = PackedVector2Array([
			Vector2(-10, -18), Vector2(10, -18), Vector2(14, 6), Vector2(0, 22), Vector2(-14, 6)
		])
		var class_id := str(entry.get("class_id", "warrior"))
		var color: Color = CLASS_COLORS.get(class_id, Color(0.8, 0.8, 0.9))
		ghost.color = Color(color.r, color.g, color.b, 0.45)
		ghost.position = ghost_positions[i]
		add_child(ghost)

func _update_nearest_station() -> void:
	if not is_instance_valid(_player):
		return
	var best: Area2D = null
	var best_dist := INF
	for station in _stations:
		var base: Polygon2D = station.get_meta("base_poly", null) as Polygon2D
		if base:
			base.color = STATION_COLOR
		var dist := _player.global_position.distance_to(station.global_position)
		if dist < INTERACT_RANGE and dist < best_dist:
			best = station
			best_dist = dist
	_current_station = best
	if _current_station:
		var poly: Polygon2D = _current_station.get_meta("base_poly", null) as Polygon2D
		if poly:
			poly.color = STATION_HIGHLIGHT
		_prompt_label.text = "[E] " + str(_current_station.get_meta("station_title", "Interact"))
		_prompt_label.visible = true
	else:
		_prompt_label.visible = false

func _open_station(station: Area2D) -> void:
	if station == null:
		return
	var station_id := str(station.get_meta("station_id", ""))
	_show_panel(str(station.get_meta("station_title", "Station")))
	match station_id:
		"memorial":
			_build_memorial_panel()
		"vault":
			_build_vault_panel()
		"audience":
			_build_audience_panel()
		"shrine":
			_build_shrine_panel()
		"barracks":
			_build_barracks_panel()

func _show_panel(title: String) -> void:
	for child in _panel_content.get_children():
		child.queue_free()
	_panel_title.text = title
	_panel_status.text = ""
	_panel.visible = true
	var dimmer = _panel_layer.get_node("Dimmer") as ColorRect
	if dimmer:
		dimmer.visible = true
	if _player:
		_player.process_mode = Node.PROCESS_MODE_DISABLED

func _close_panel() -> void:
	_panel.visible = false
	var dimmer = _panel_layer.get_node("Dimmer") as ColorRect
	if dimmer:
		dimmer.visible = false
	if _player:
		_player.process_mode = Node.PROCESS_MODE_INHERIT

func _build_memorial_panel() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var sd: SaveData = gm.save_data if gm else null
	if not sd:
		return
	var summary := Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 16)
	summary.add_theme_color_override("font_color", Color(0.82, 0.82, 0.86))
	if not sd.last_death_run_summary.is_empty():
		var s: Dictionary = sd.last_death_run_summary
		summary.text = "The latest fallen hero yielded %d Soul Points.\nClass: %s  Lv.%d  Floor: %d  Kills: %d  Gold Lost: %d" % [
			int(s.get("soul_gain", 0)),
			str(s.get("class_id", "unknown")).capitalize(),
			int(s.get("level", 1)),
			int(s.get("floor", 0)),
			int(s.get("enemies_killed", 0)),
			int(sd.last_death_gold),
		]
	else:
		summary.text = "No recent death ledger remains."
	_panel_content.add_child(summary)

	var hint := Label.new()
	hint.text = "Choose up to 3 items to pass forward to the next heir."
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.68, 0.74, 0.78))
	_panel_content.add_child(hint)

	if sd.last_death_inventory_items.is_empty():
		var empty := Label.new()
		empty.text = "Nothing remains of the last hero."
		_panel_content.add_child(empty)
		return

	for i in range(sd.last_death_inventory_items.size()):
		var path := str(sd.last_death_inventory_items[i])
		var item := load(path) as EquipmentItem
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var check := CheckBox.new()
		check.button_pressed = bool(_selected_legacy_indices.get(i, false))
		check.toggled.connect(_on_memorial_item_toggled.bind(i))
		row.add_child(check)
		var icon = _make_item_icon(item)
		row.add_child(icon)
		var label := Label.new()
		label.text = _format_legacy_item(item, path) + "  [" + _legacy_tag_for_item(item) + "]"
		label.add_theme_color_override("font_color", Color(0.88, 0.86, 0.80))
		row.add_child(label)
		_panel_content.add_child(row)

	_panel_status.text = "Selected: %d / 3" % _selected_legacy_count()

func _build_vault_panel() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var sd: SaveData = gm.save_data if gm else null
	if not sd:
		return
	_panel_status.text = "Vault capacity: %d / %d" % [sd.legacy_vault_items.size(), gm.get_legacy_vault_capacity()]
	if sd.legacy_vault_items.is_empty():
		var empty := Label.new()
		empty.text = "The vault is still empty."
		_panel_content.add_child(empty)
		return
	for i in range(sd.legacy_vault_items.size()):
		var path := str(sd.legacy_vault_items[i])
		var item := load(path) as EquipmentItem
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_make_item_icon(item))
		var label := Label.new()
		label.text = _format_legacy_item(item, path) + "  [" + _legacy_tag_for_item(item) + "]"
		row.add_child(label)
		_panel_content.add_child(row)

func _build_audience_panel() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var sd: SaveData = gm.save_data if gm else null
	if not sd or sd.ancestor_records.is_empty():
		var empty := Label.new()
		empty.text = "No fallen heroes stand in the alcoves yet."
		_panel_content.add_child(empty)
		return
	for entry in sd.ancestor_records:
		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.10, 0.14, 0.94)
		style.border_color = Color(0.30, 0.28, 0.34)
		style.set_border_width_all(1)
		card.add_theme_stylebox_override("panel", style)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		card.add_child(box)
		var class_id := str(entry.get("class_id", "warrior"))
		var header := Label.new()
		header.text = "%s  Lv.%d" % [class_id.capitalize(), int(entry.get("level", 1))]
		header.add_theme_color_override("font_color", CLASS_COLORS.get(class_id, Color.WHITE))
		box.add_child(header)
		var body := Label.new()
		body.text = "Floor %d  |  Kills %d  |  Soul %d" % [
			int(entry.get("floor", 0)),
			int(entry.get("enemies_killed", 0)),
			int(entry.get("soul_gain", 0)),
		]
		box.add_child(body)
		_panel_content.add_child(card)

func _build_shrine_panel() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var sd: SaveData = gm.save_data if gm else null
	if not gm or not sd:
		return
	_panel_status.text = "Soul Points: %d" % sd.soul_points
	# Death-meta carry-overs
	_panel_content.add_child(_upgrade_row("Gold Retention", "Keeps more of a dead hero's gold (+10% per level, max 5).", "gold_retention"))
	_panel_content.add_child(_upgrade_row("Legacy Vault", "Expands the permanent vault capacity ceiling (+2 per level, max 3).", "legacy_capacity"))
	_panel_content.add_child(_upgrade_row("Soul Anchor", "Each new heir starts with retained levels from your last death (+1 level per rank, max 3).", "soul_anchor"))
	# Starter bonuses
	_panel_content.add_child(_upgrade_row("Heroic Vigor", "Each new heir starts with +5 max HP per rank (max 10).", "starting_health"))
	_panel_content.add_child(_upgrade_row("Heroic Might", "Each new heir starts with +1 attack damage per rank (max 10).", "starting_damage"))
	_panel_content.add_child(_upgrade_row("Veteran's Stipend", "Each new heir starts with +50 gold per rank (max 5).", "starting_gold"))
	_panel_content.add_child(_upgrade_row("Heart of Embers", "Permanent +0.1 HP regen per rank (max 5).", "heart_of_embers"))
	_panel_content.add_child(_upgrade_row("Apothecary's Gift", "Each heir starts with +1 Red Potion per rank (max 3).", "starting_potions"))
	_panel_content.add_child(_upgrade_row("Free Stat Points", "Each heir starts with +2 unspent stat points per rank (max 5).", "free_stat_points"))
	_panel_content.add_child(_upgrade_row("Perk Token Carryover", "Each heir starts with +1 perk token per rank (max 3).", "perk_token_carryover"))
	# Permanent multipliers
	_panel_content.add_child(_upgrade_row("Avarice", "Permanent +5% gold gain per rank (max 5).", "gold_find"))
	_panel_content.add_child(_upgrade_row("Ancestral Wisdom", "Permanent +5% XP gain per rank (max 5).", "xp_find"))

func _build_barracks_panel() -> void:
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "When you are ready, send the next heir into the world.\nThe selected legacy items will travel with them."
	_panel_content.add_child(info)

	var selected := Label.new()
	selected.text = "Legacy selected: %d / 3" % _selected_legacy_count()
	_panel_content.add_child(selected)

	var btn := Button.new()
	btn.text = "Choose New Heir"
	btn.custom_minimum_size = Vector2(260, 48)
	btn.pressed.connect(_commit_and_leave_hall)
	_panel_content.add_child(btn)

func _upgrade_row(title: String, desc: String, upgrade_id: String) -> Control:
	var gm = get_node_or_null("/root/GameManager")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 18)
	box.add_child(header)
	var sub := Label.new()
	sub.text = desc
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_color_override("font_color", Color(0.68, 0.74, 0.78))
	box.add_child(sub)
	row.add_child(box)
	var cost: int = gm.get_hall_upgrade_cost(upgrade_id) if gm else 999
	var btn := Button.new()
	btn.text = "Buy (%d SP)" % cost
	btn.custom_minimum_size = Vector2(130, 42)
	btn.pressed.connect(func():
		if gm and gm.buy_hall_upgrade(upgrade_id):
			_build_shrine_panel_refresh()
		else:
			_panel_status.text = "Insufficient soul points or upgrade capped."
	)
	row.add_child(btn)
	return row

func _build_shrine_panel_refresh() -> void:
	_show_panel("Shrine of Souls")
	_build_shrine_panel()

func _make_item_icon(item: EquipmentItem) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(40, 40)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if item:
		icon.texture = ItemIconHelper.get_icon_texture(item)
	holder.add_child(icon)
	return holder

func _on_memorial_item_toggled(pressed: bool, item_idx: int) -> void:
	if pressed and _selected_legacy_count() >= 3:
		_selected_legacy_indices.erase(item_idx)
		_panel_status.text = "Legacy selection is capped at 3 items."
		_show_panel("Memorial")
		_build_memorial_panel()
		return
	if pressed:
		_selected_legacy_indices[item_idx] = true
	else:
		_selected_legacy_indices.erase(item_idx)
	_panel_status.text = "Selected: %d / 3" % _selected_legacy_count()

func _commit_and_leave_hall() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return
	var chosen: Array[int] = []
	for idx in _selected_legacy_indices.keys():
		chosen.append(int(idx))
	chosen.sort()
	gm.finalize_hall_legacy_selection(chosen)
	gm.go_to_start_screen()

func _selected_legacy_count() -> int:
	return _selected_legacy_indices.size()

func _format_legacy_item(item: EquipmentItem, fallback_path: String) -> String:
	if item:
		return item.item_name
	return fallback_path.get_file().get_basename().replace("_", " ").capitalize()

func _legacy_tag_for_item(item: EquipmentItem) -> String:
	if not item:
		return "Unknown"
	return ItemIconHelper.get_slot_name(item.slot_type)
