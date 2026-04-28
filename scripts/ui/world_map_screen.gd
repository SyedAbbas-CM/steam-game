class_name WorldMapScreen
extends CanvasLayer

## Node-graph world map — zones as dots, exits as lines, clickable for details.
## Side panel: zone info (top) + territory list + faction attitudes (always visible).

const SCREEN_W := 1920
const SCREEN_H := 1080
const MARGIN := 40          # screen edge margin
const SIDE_W := 340         # wider side panel
const MAP_W := SCREEN_W - SIDE_W - MARGIN * 3  # ~1480
const MAP_H := SCREEN_H - MARGIN * 2           # ~1000
const NODE_R := 10.0
const EDGE_W := 2.5
const WORLD_SPREAD := 2200.0  # world-space size for node layout

# Top-level
var _overlay: ColorRect
var _map_container: Control
var _graph_display: Control

# Side panel
var _side_panel: Control
var _zone_info_box: VBoxContainer      # top: selected zone details
var _territory_scroll: ScrollContainer  # middle: territory list (always visible)
var _territory_list: VBoxContainer
var _faction_box: VBoxContainer         # bottom: faction attitudes (always visible)
var _engage_btn: Button
var _diplomacy_btn: Button  # contextual — only for faction zones

# Graph data
var _zone_data_map: Dictionary = {}
var _graph_nodes: Dictionary = {}  # zone_id -> {pos: Vector2, color: Color}
var _graph_edges: Array = []
var _selected_zone: String = ""
var _hovered_zone: String = ""
var _player_zone: String = ""

# Camera
var _cam_offset: Vector2 = Vector2.ZERO
var _cam_zoom: float = 0.55
const ZOOM_MIN := 0.25
const ZOOM_MAX := 3.0
const ZOOM_STEP := 0.12
var _dragging: bool = false
var _drag_prev: Vector2 = Vector2.ZERO

var _toggle_cd: float = 0.0
var _pulse_t: float = 0.0

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("world_map")

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.85)
	_overlay.size = Vector2(SCREEN_W, SCREEN_H)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	var map_x := float(MARGIN)
	var map_y := float(MARGIN)

	_map_container = Control.new()
	_map_container.position = Vector2(map_x, map_y)
	_map_container.size = Vector2(MAP_W, MAP_H)
	_map_container.clip_contents = true
	_map_container.visible = false
	add_child(_map_container)

	# Map bg
	var bg := ColorRect.new()
	bg.size = Vector2(MAP_W, MAP_H)
	bg.color = Color(0.03, 0.03, 0.07, 0.98)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_container.add_child(bg)

	# Graph draw node
	_graph_display = Control.new()
	_graph_display.size = Vector2(MAP_W, MAP_H)
	_graph_display.mouse_filter = Control.MOUSE_FILTER_STOP
	var gscript = load("res://scripts/ui/graph_map_display.gd")
	if gscript:
		_graph_display.set_script(gscript)
		_graph_display.map_screen = self
	_map_container.add_child(_graph_display)

	_build_side_panel(map_x, map_y)

	# Title
	var title := Label.new()
	title.text = "WORLD MAP"
	var ts := LabelSettings.new()
	ts.font_size = 26
	ts.font_color = Color(0.9, 0.8, 0.5)
	ts.outline_size = 3
	ts.outline_color = Color(0, 0, 0)
	title.label_settings = ts
	title.position = Vector2(map_x + MAP_W / 2.0 - 70, map_y - 34)
	title.visible = false
	title.name = "TitleLabel"
	add_child(title)

	var hint := Label.new()
	hint.text = "Scroll to zoom  |  Drag to pan  |  Press M/ESC to close"
	var hs := LabelSettings.new()
	hs.font_size = 12
	hs.font_color = Color(0.5, 0.5, 0.5)
	hint.label_settings = hs
	hint.position = Vector2(map_x + MAP_W / 2.0 - 160, map_y + MAP_H + 4)
	hint.visible = false
	hint.name = "HintLabel"
	add_child(hint)

func _build_side_panel(map_x: float, map_y: float) -> void:
	_side_panel = Control.new()
	_side_panel.position = Vector2(map_x + MAP_W + MARGIN, map_y)
	_side_panel.size = Vector2(SIDE_W, MAP_H)
	_side_panel.visible = false
	add_child(_side_panel)

	var sbg := ColorRect.new()
	sbg.size = Vector2(SIDE_W, MAP_H)
	sbg.color = Color(0.05, 0.04, 0.10, 0.96)
	_side_panel.add_child(sbg)

	# --- Top: zone info (compact, ~200px) ---
	_zone_info_box = VBoxContainer.new()
	_zone_info_box.position = Vector2(10, 8)
	_zone_info_box.size = Vector2(SIDE_W - 20, 200)
	_zone_info_box.add_theme_constant_override("separation", 2)
	_side_panel.add_child(_zone_info_box)

	# --- Separator ---
	var sep1 := ColorRect.new()
	sep1.position = Vector2(10, 210)
	sep1.size = Vector2(SIDE_W - 20, 1)
	sep1.color = Color(0.3, 0.25, 0.2, 0.4)
	_side_panel.add_child(sep1)

	# --- Middle: territory list (scrollable) ---
	var terr_header := Label.new()
	terr_header.text = "TERRITORIES"
	terr_header.position = Vector2(10, 216)
	var th_s := LabelSettings.new()
	th_s.font_size = 13
	th_s.font_color = Color(0.7, 0.65, 0.5)
	terr_header.label_settings = th_s
	_side_panel.add_child(terr_header)

	_territory_scroll = ScrollContainer.new()
	_territory_scroll.position = Vector2(10, 236)
	_territory_scroll.size = Vector2(SIDE_W - 20, MAP_H - 480)
	_side_panel.add_child(_territory_scroll)

	_territory_list = VBoxContainer.new()
	_territory_list.add_theme_constant_override("separation", 1)
	_territory_scroll.add_child(_territory_list)

	# --- Separator ---
	var sep2 := ColorRect.new()
	sep2.position = Vector2(10, MAP_H - 240)
	sep2.size = Vector2(SIDE_W - 20, 1)
	sep2.color = Color(0.3, 0.25, 0.2, 0.4)
	_side_panel.add_child(sep2)

	# --- Bottom: faction attitudes ---
	var fac_header := Label.new()
	fac_header.text = "FACTIONS"
	fac_header.position = Vector2(10, MAP_H - 234)
	var fh_s := LabelSettings.new()
	fh_s.font_size = 13
	fh_s.font_color = Color(0.7, 0.65, 0.5)
	fac_header.label_settings = fh_s
	_side_panel.add_child(fac_header)

	_faction_box = VBoxContainer.new()
	_faction_box.position = Vector2(10, MAP_H - 216)
	_faction_box.size = Vector2(SIDE_W - 20, 150)
	_faction_box.add_theme_constant_override("separation", 1)
	_side_panel.add_child(_faction_box)

	# --- Buttons at very bottom ---
	_engage_btn = Button.new()
	_engage_btn.text = "ATTACK"
	_engage_btn.position = Vector2(10, MAP_H - 56)
	_engage_btn.size = Vector2((SIDE_W - 28) / 2.0, 44)
	_engage_btn.focus_mode = Control.FOCUS_NONE
	_engage_btn.visible = false
	var es := StyleBoxFlat.new()
	es.bg_color = Color(0.6, 0.12, 0.08, 0.9)
	es.border_color = Color(0.9, 0.3, 0.2)
	es.set_border_width_all(2)
	es.set_corner_radius_all(5)
	_engage_btn.add_theme_stylebox_override("normal", es)
	var eh := es.duplicate() as StyleBoxFlat
	eh.bg_color = Color(0.8, 0.2, 0.12)
	_engage_btn.add_theme_stylebox_override("hover", eh)
	_engage_btn.add_theme_font_size_override("font_size", 14)
	_engage_btn.pressed.connect(_on_engage_pressed)
	_side_panel.add_child(_engage_btn)

	_diplomacy_btn = Button.new()
	_diplomacy_btn.text = "DIPLOMACY"
	_diplomacy_btn.position = Vector2(10 + (SIDE_W - 28) / 2.0 + 8, MAP_H - 56)
	_diplomacy_btn.size = Vector2((SIDE_W - 28) / 2.0, 44)
	_diplomacy_btn.focus_mode = Control.FOCUS_NONE
	_diplomacy_btn.visible = false
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.1, 0.15, 0.4, 0.9)
	ds.border_color = Color(0.3, 0.4, 0.7)
	ds.set_border_width_all(2)
	ds.set_corner_radius_all(5)
	_diplomacy_btn.add_theme_stylebox_override("normal", ds)
	var dh := ds.duplicate() as StyleBoxFlat
	dh.bg_color = Color(0.15, 0.22, 0.55)
	_diplomacy_btn.add_theme_stylebox_override("hover", dh)
	_diplomacy_btn.add_theme_font_size_override("font_size", 14)
	_diplomacy_btn.pressed.connect(_on_diplomacy_pressed)
	_side_panel.add_child(_diplomacy_btn)

# --- Camera ---

func _force_directed_relax() -> void:
	## Run force-directed relaxation to separate overlapping nodes and reduce edge crossings.
	## Nodes repel each other; connected nodes attract to an ideal distance.
	var ids: Array = _graph_nodes.keys()
	var count := ids.size()
	if count < 2:
		return

	const ITERATIONS := 80
	const REPULSION := 8000.0   # repel force strength
	const ATTRACTION := 0.008   # spring constant for edges
	const IDEAL_DIST := 120.0   # ideal edge length
	const MAX_MOVE := 25.0      # max displacement per iteration
	const DAMPING := 0.92

	var positions: Dictionary = {}
	for zid in ids:
		positions[zid] = _graph_nodes[zid]["pos"]

	var velocities: Dictionary = {}
	for zid in ids:
		velocities[zid] = Vector2.ZERO

	for _iter in range(ITERATIONS):
		var forces: Dictionary = {}
		for zid in ids:
			forces[zid] = Vector2.ZERO

		# Repulsion between all pairs
		for i in range(count):
			for j in range(i + 1, count):
				var a: String = ids[i]
				var b: String = ids[j]
				var pa: Vector2 = positions[a]
				var pb: Vector2 = positions[b]
				var delta := pb - pa
				var dist := delta.length()
				if dist < 1.0:
					delta = Vector2(randf_range(-1, 1), randf_range(-1, 1))
					dist = 1.0
				var force := REPULSION / (dist * dist)
				var f := delta.normalized() * force
				forces[a] -= f
				forces[b] += f

		# Attraction along edges
		for edge in _graph_edges:
			var ea: String = edge[0]
			var eb: String = edge[1]
			if not forces.has(ea) or not forces.has(eb):
				continue
			var epa: Vector2 = positions[ea]
			var epb: Vector2 = positions[eb]
			var edelta := epb - epa
			var edist := edelta.length()
			if edist < 1.0:
				continue
			var displacement := edist - IDEAL_DIST
			var ef := edelta.normalized() * displacement * ATTRACTION
			forces[ea] += ef
			forces[eb] -= ef

		# Apply forces with velocity damping
		for zid in ids:
			velocities[zid] = (velocities[zid] + forces[zid]) * DAMPING
			var move: Vector2 = velocities[zid]
			if move.length() > MAX_MOVE:
				move = move.normalized() * MAX_MOVE
			_graph_nodes[zid]["pos"] += move

func _zoom_at(screen_pos: Vector2, new_zoom: float) -> void:
	var old_w := _screen_to_world(screen_pos)
	_cam_zoom = clampf(new_zoom, ZOOM_MIN, ZOOM_MAX)
	var new_w := _screen_to_world(screen_pos)
	_cam_offset += old_w - new_w

# --- Camera helpers ---

func _world_to_screen(world_pos: Vector2) -> Vector2:
	## Convert graph world position to screen pixel position within the map area.
	var center = Vector2(MAP_W / 2.0, MAP_H / 2.0)
	return (world_pos - _cam_offset) * _cam_zoom + center

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	## Convert screen pixel position to graph world position.
	var center := Vector2(MAP_W / 2.0, MAP_H / 2.0)
	return (screen_pos - center) / _cam_zoom + _cam_offset

func _center_on_zone(zone_id: String) -> void:
	if _graph_nodes.has(zone_id):
		_cam_offset = _graph_nodes[zone_id]["pos"]

# --- Drawing ---

func _draw_graph(canvas: Control) -> void:
	var font := ThemeDB.fallback_font
	if not font:
		return

	var sr := NODE_R * _cam_zoom
	var sew := maxf(EDGE_W * _cam_zoom, 1.0)
	var sf := maxi(int(10 * _cam_zoom), 6)
	var show_lbl := _cam_zoom >= 0.45

	# Edges
	for edge in _graph_edges:
		var za: String = edge[0]
		var zb: String = edge[1]
		if not _graph_nodes.has(za) or not _graph_nodes.has(zb):
			continue
		var pa := _world_to_screen(_graph_nodes[za]["pos"])
		var pb := _world_to_screen(_graph_nodes[zb]["pos"])
		if (pa.x < -60 and pb.x < -60) or (pa.x > MAP_W + 60 and pb.x > MAP_W + 60):
			continue
		if (pa.y < -60 and pb.y < -60) or (pa.y > MAP_H + 60 and pb.y > MAP_H + 60):
			continue
		var ec := Color(0.22, 0.22, 0.28, 0.45)
		if _selected_zone == za or _selected_zone == zb:
			ec = Color(0.45, 0.45, 0.55, 0.7)
		canvas.draw_line(pa, pb, ec, sew, true)

	# Nodes
	for zid in _graph_nodes:
		var nd: Dictionary = _graph_nodes[zid]
		var pos := _world_to_screen(nd["pos"])
		if pos.x < -40 or pos.x > MAP_W + 40 or pos.y < -40 or pos.y > MAP_H + 40:
			continue
		var fill: Color = nd["color"]
		var r := sr
		var bc := Color(fill.r * 0.6 + 0.4, fill.g * 0.6 + 0.4, fill.b * 0.6 + 0.4, 0.85)

		if zid == _hovered_zone:
			r = sr * 1.4
			bc = Color(1, 1, 1, 0.8)
		if zid == _selected_zone:
			canvas.draw_circle(pos, r + 4 * _cam_zoom, Color(1, 1, 1, 0.2))
			bc = Color(1, 1, 1, 0.95)
		if zid == _player_zone:
			var pa := 0.3 + 0.3 * sin(_pulse_t)
			canvas.draw_circle(pos, r + 7 * _cam_zoom, Color(1.0, 0.9, 0.2, pa))

		canvas.draw_circle(pos, r, fill)
		canvas.draw_arc(pos, r + 1, 0, TAU, 32, bc, maxf(1.5 * _cam_zoom, 1.0))

		if show_lbl:
			var zd = _zone_data_map.get(zid, null)
			var dn: String = zid
			if zd and zd.zone_name != "":
				dn = zd.zone_name
			if dn.length() > 14:
				dn = dn.substr(0, 13) + "."
			var tw := font.get_string_size(dn, HORIZONTAL_ALIGNMENT_LEFT, -1, sf).x
			var lp := Vector2(pos.x - tw / 2.0, pos.y + r + 13 * _cam_zoom)
			var lc := Color(0.55, 0.55, 0.6, 0.75)
			if zid == _selected_zone or zid == _hovered_zone:
				lc = Color(0.9, 0.9, 0.9)
			canvas.draw_string(font, lp, dn, HORIZONTAL_ALIGNMENT_LEFT, -1, sf, lc)

	# Zoom %
	canvas.draw_string(font, Vector2(8, MAP_H - 8), "%d%%" % int(_cam_zoom * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.4, 0.4, 0.5))

# --- Input ---

func _on_graph_input(event: InputEvent, canvas: Control) -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	# Mac trackpad scroll (two-finger) → pan
	if event is InputEventPanGesture:
		_cam_offset += Vector2(event.delta.x, event.delta.y) * 40.0 / _cam_zoom
		canvas.queue_redraw()
		canvas.accept_event()
		return

	# Mac pinch-to-zoom
	if event is InputEventMagnifyGesture:
		_zoom_at(event.position, _cam_zoom * event.factor)
		canvas.queue_redraw()
		canvas.accept_event()
		return

	if event is InputEventMouseMotion:
		if _dragging:
			_cam_offset -= event.relative / _cam_zoom
			canvas.queue_redraw()
			return
		# Hover
		var wp := _screen_to_world(event.position)
		var near := ""
		var near_d := 18.0 / _cam_zoom
		for zid in _graph_nodes:
			var d := wp.distance_to(_graph_nodes[zid]["pos"])
			if d < near_d:
				near_d = d
				near = zid
		if near != _hovered_zone:
			_hovered_zone = near
			canvas.queue_redraw()

	elif event is InputEventMouseButton:
		# Scroll wheel zoom
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, _cam_zoom + ZOOM_STEP)
			canvas.queue_redraw()
			canvas.accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, _cam_zoom - ZOOM_STEP)
			canvas.queue_redraw()
			canvas.accept_event()
		# Right/middle drag → pan
		elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
			canvas.accept_event()
		# Left click
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _hovered_zone != "":
					if sfx:
						sfx.play("click", -5.0)
					_selected_zone = _hovered_zone
					canvas.queue_redraw()
					_update_zone_info()
					_update_buttons()
				else:
					# Start drag on empty space
					_dragging = true
					_drag_prev = event.position
			else:
				_dragging = false

# --- Process ---

func _process(delta: float) -> void:
	if _toggle_cd > 0:
		_toggle_cd -= delta
	if not _overlay.visible:
		return
	_pulse_t += delta * 3.0
	if _graph_display:
		_graph_display.queue_redraw()

func _input(event: InputEvent) -> void:
	if not _overlay.visible:
		return
	if event.is_action_pressed("world_map") or event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()

# --- Toggle ---

func toggle() -> void:
	if _toggle_cd > 0:
		return
	_toggle_cd = 0.2
	var opening := not _overlay.visible
	_overlay.visible = opening
	_map_container.visible = opening
	_side_panel.visible = opening
	for n in ["TitleLabel", "HintLabel"]:
		var lbl = get_node_or_null(n)
		if lbl:
			lbl.visible = opening

	if opening:
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("paper", -5.0)
		_refresh_map()
	else:
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("close", -5.0)
		_selected_zone = ""
		_hovered_zone = ""
		_dragging = false

func is_open() -> bool:
	return _overlay.visible

# --- Refresh ---

func _refresh_map() -> void:
	var cnt := 0
	var fm = get_node_or_null("/root/FactionManager")
	var pairs: Dictionary = {}
	_zone_data_map.clear()
	_graph_nodes.clear()
	_graph_edges.clear()

	var ow = get_tree().get_first_node_in_group("overworld")
	var zones: Array = []
	if ow and "zone_data" in ow:
		zones = ow.zone_data
	for z in zones:
		if z is LoyZoneData:
			_zone_data_map[z.id] = z

	_player_zone = ""
	if ow and "_current_zone" in ow and ow._current_zone:
		_player_zone = ow._current_zone.id

	# Build positions from baked_offset → spread into world space
	var min_v := Vector2(999999, 999999)
	var max_v := Vector2(-999999, -999999)
	var offsets: Dictionary = {}

	for zid in _zone_data_map:
		var zd = _zone_data_map[zid]
		if zd.baked_offset == Vector2i(-99999, -99999):
			continue
		var s: int = maxi(zd.baked_scale, 1)
		var w: int = maxi(zd.width, 25) * s
		var h: int = maxi(zd.height, 25) * s
		var c := Vector2(float(zd.baked_offset.x) + w / 2.0, float(zd.baked_offset.y) + h / 2.0)
		offsets[zid] = c
		min_v.x = minf(min_v.x, c.x)
		min_v.y = minf(min_v.y, c.y)
		max_v.x = maxf(max_v.x, c.x)
		max_v.y = maxf(max_v.y, c.y)

	var rng := max_v - min_v
	rng.x = maxf(rng.x, 1.0)
	rng.y = maxf(rng.y, 1.0)

	for zid in offsets:
		var raw: Vector2 = offsets[zid]
		var nx := (raw.x - min_v.x) / rng.x * WORLD_SPREAD
		var ny := (raw.y - min_v.y) / rng.y * WORLD_SPREAD * (float(MAP_H) / float(MAP_W))
		var col := Color(0.4, 0.4, 0.5, 0.8)
		if fm:
			var zone_owner: String = fm.get_zone_owner(zid) if fm.has_method("get_zone_owner") else ""
			if zone_owner == "player":
				col = Color(0.2, 0.75, 0.3, 0.9)
			elif zone_owner != "":
				col = fm.get_owner_color(zone_owner)
				col.a = 0.85
		_graph_nodes[zid] = {"pos": Vector2(nx, ny), "color": col}

	# Edges
	if fm:
		for zid in _graph_nodes:
			for nb in fm.get_zone_neighbors(zid):
				if not _graph_nodes.has(nb):
					continue
				var k: String = zid + "|" + nb if zid < nb else nb + "|" + zid
				if pairs.has(k):
					continue
				pairs[k] = true
				_graph_edges.append([zid, nb])

	# Force-directed layout pass to untangle overlapping nodes
	_force_directed_relax()

	# Camera: center on player, zoom to see neighbours
	_cam_zoom = 0.7
	if _player_zone != "" and _graph_nodes.has(_player_zone):
		_cam_offset = _graph_nodes[_player_zone]["pos"]
		_selected_zone = _player_zone
	else:
		var avg := Vector2.ZERO
		for zid in _graph_nodes:
			avg += _graph_nodes[zid]["pos"]
			cnt += 1
		if cnt > 0:
			_cam_offset = avg / float(cnt)
		_selected_zone = ""

	_refresh_territory_list()
	_refresh_faction_list()
	_update_zone_info()
	_update_buttons()
	if _graph_display:
		_graph_display.queue_redraw()

# --- Zone info (top of side panel) ---

func _update_zone_info() -> void:
	var fm = get_node_or_null("/root/FactionManager")
	# Clear
	for c in _zone_info_box.get_children():
		c.queue_free()

	if _selected_zone == "" or not _zone_data_map.has(_selected_zone):
		var lbl := Label.new()
		lbl.text = "Click a zone to view details"
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		_zone_info_box.add_child(lbl)
		return

	var zd = _zone_data_map[_selected_zone]
	var dn: String = zd.zone_name if zd.zone_name != "" else _selected_zone

	# Name
	var name_lbl := Label.new()
	name_lbl.text = dn
	var ns := LabelSettings.new()
	ns.font_size = 18
	ns.font_color = Color(0.95, 0.85, 0.5)
	ns.outline_size = 2
	ns.outline_color = Color(0, 0, 0)
	name_lbl.label_settings = ns
	_zone_info_box.add_child(name_lbl)

	# Description
	var desc: String = zd.description if zd.description != "" else "A region in the world."
	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.58, 0.54))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.custom_minimum_size = Vector2(SIDE_W - 24, 0)
	_zone_info_box.add_child(desc_lbl)

	# Owner
	var zone_owner := ""
	if fm:
		zone_owner = fm.get_zone_owner(_selected_zone)
	var owner_lbl := Label.new()
	if zone_owner == "player":
		owner_lbl.text = "Owner: You"
		owner_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	elif zone_owner != "":
		owner_lbl.text = "Owner: %s" % (fm.get_owner_display_name(zone_owner) if fm else zone_owner)
		owner_lbl.add_theme_color_override("font_color", fm.get_owner_color(zone_owner) if fm else Color(0.8, 0.5, 0.3))
	else:
		owner_lbl.text = "Unclaimed"
		owner_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	owner_lbl.add_theme_font_size_override("font_size", 13)
	_zone_info_box.add_child(owner_lbl)

	# Army strength
	if fm and zone_owner != "" and zone_owner != "player" and fm.factions.has(zone_owner):
		var fac = fm.factions[zone_owner]
		var tier: int = fac.get("tier", 1)
		var army_size: int = fac.get("army_size", 40)
		var tl: String = ["Weak", "Moderate", "Strong"][clampi(tier - 1, 0, 2)]
		var army_lbl := Label.new()
		army_lbl.text = "Army: ~%d troops (%s)" % [army_size, tl]
		army_lbl.add_theme_font_size_override("font_size", 12)
		army_lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
		_zone_info_box.add_child(army_lbl)

	# Connections
	if fm:
		var nbs: Array = fm.get_zone_neighbors(_selected_zone)
		if nbs.size() > 0:
			var names: Array = []
			for nb in nbs:
				if _zone_data_map.has(nb):
					var nd: LoyZoneData = _zone_data_map[nb]
					names.append(nd.zone_name if nd.zone_name != "" else nb)
				else:
					names.append(nb)
			var conn_lbl := Label.new()
			conn_lbl.text = "Connects: " + ", ".join(names)
			conn_lbl.add_theme_font_size_override("font_size", 10)
			conn_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
			conn_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			conn_lbl.custom_minimum_size = Vector2(SIDE_W - 24, 0)
			_zone_info_box.add_child(conn_lbl)

# --- Buttons ---

func _update_buttons() -> void:
	var fm = get_node_or_null("/root/FactionManager")
	var can_attack := false
	var can_diplomacy := false

	if _selected_zone != "" and fm:
		# Can attack: enemy faction zone adjacent to player territory
		var zone_owner_2: String = fm.get_zone_owner(_selected_zone)
		if zone_owner_2 != "" and zone_owner_2 != "player":
			for pz in fm.get_player_zones():
				if _selected_zone in fm.get_zone_neighbors(pz):
					can_attack = true
					break
			# Can diplomacy: any faction-owned zone
			if fm.factions.has(zone_owner_2):
				can_diplomacy = true

	_engage_btn.visible = can_attack
	_diplomacy_btn.visible = can_diplomacy

	# Layout: if both visible, side by side. If only one, full width.
	if can_attack and can_diplomacy:
		var hw := (SIDE_W - 28) / 2.0
		_engage_btn.position = Vector2(10, MAP_H - 56)
		_engage_btn.size = Vector2(hw, 44)
		_diplomacy_btn.position = Vector2(10 + hw + 8, MAP_H - 56)
		_diplomacy_btn.size = Vector2(hw, 44)
	elif can_attack:
		_engage_btn.position = Vector2(10, MAP_H - 56)
		_engage_btn.size = Vector2(SIDE_W - 20, 44)
	elif can_diplomacy:
		_diplomacy_btn.position = Vector2(10, MAP_H - 56)
		_diplomacy_btn.size = Vector2(SIDE_W - 20, 44)

# --- Territory list (always visible) ---

func _refresh_territory_list() -> void:
	var fm = get_node_or_null("/root/FactionManager")
	for c in _territory_list.get_children():
		c.queue_free()
	if not fm:
		return

	# Group by owner, player first
	var grouped: Dictionary = {}  # owner -> [zone_ids]
	for zid in _zone_data_map:
		var zo: String = fm.get_zone_owner(zid)
		if not grouped.has(zo):
			grouped[zo] = []
		grouped[zo].append(zid)

	# Player zones
	if grouped.has("player"):
		for zid in grouped["player"]:
			_add_terr_row(zid, "player", fm)
	# Faction zones
	for fid in fm.factions:
		if grouped.has(fid):
			for zid in grouped[fid]:
				_add_terr_row(zid, fid, fm)
	# Neutral
	if grouped.has(""):
		for zid in grouped[""]:
			_add_terr_row(zid, "", fm)

func _add_terr_row(zid: String, owner: String, fm) -> void:
	var zname := zid
	if _zone_data_map.has(zid):
		var zd = _zone_data_map[zid]
		if zd.zone_name != "":
			zname = zd.zone_name

	var btn := Button.new()
	btn.text = zname
	btn.custom_minimum_size = Vector2(SIDE_W - 30, 26)
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 11)

	var col: Color = fm.get_owner_color(owner)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(col.r, col.g, col.b, 0.15)
	style.set_border_width_all(0)
	style.border_color = col
	style.set_content_margin_all(4)
	style.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(col.r, col.g, col.b, 0.35)
	hover.set_border_width_all(1)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))

	btn.pressed.connect(_on_terr_row_clicked.bind(zid))
	_territory_list.add_child(btn)

func _on_terr_row_clicked(zid: String) -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click", -5.0)
	_selected_zone = zid
	# Pan camera to it
	if _graph_nodes.has(zid):
		_cam_offset = _graph_nodes[zid]["pos"]
	_update_zone_info()
	_update_buttons()
	if _graph_display:
		_graph_display.queue_redraw()

# --- Faction list (always visible) ---

func _refresh_faction_list() -> void:
	var fm = get_node_or_null("/root/FactionManager")
	for c in _faction_box.get_children():
		c.queue_free()
	if not fm:
		return
	for fid in fm.factions:
		var fac: Dictionary = fm.factions[fid]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_faction_box.add_child(row)

		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 12)
		dot.color = fac["color"]
		row.add_child(dot)

		var nl := Label.new()
		nl.text = fac["name"].substr(0, 14)
		nl.custom_minimum_size = Vector2(110, 0)
		nl.add_theme_font_size_override("font_size", 10)
		nl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		row.add_child(nl)

		var att: int = fac["attitude"]
		var al := Label.new()
		al.text = fm.get_attitude_label(att)
		al.add_theme_font_size_override("font_size", 10)
		al.add_theme_color_override("font_color", fm.get_attitude_color(att))
		row.add_child(al)

# --- Engage ---

func _on_engage_pressed() -> void:
	if _selected_zone == "":
		return
	_start_battle(_selected_zone)

func _on_diplomacy_pressed() -> void:
	var fm = get_node_or_null("/root/FactionManager")
	# TODO: Open diplomacy/relationship popup for the selected faction
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click", -5.0)
	if not fm:
		return
	var zone_owner_d: String = fm.get_zone_owner(_selected_zone)
	if zone_owner_d == "" or zone_owner_d == "player":
		return
	print("Diplomacy: opening relations with %s (placeholder)" % zone_owner_d)
	# Placeholder — will be expanded into a Spore-like diplomacy popup

func _start_battle(zone_id: String) -> void:
	var gm = get_node_or_null("/root/GameManager")
	var fm = get_node_or_null("/root/FactionManager")
	if not gm or not fm:
		return

	var zone_name := zone_id
	if _zone_data_map.has(zone_id):
		var zd = _zone_data_map[zone_id]
		if zd.zone_name != "":
			zone_name = zd.zone_name

	var player_level: int = 1
	if gm.save_data:
		player_level = gm.save_data.player_level

	var hired: Dictionary = {}
	if gm.save_data and gm.save_data.army_state.has("hired_fighters"):
		hired = gm.save_data.army_state["hired_fighters"]
	var player_army := _build_player_army(player_level, hired)

	var owner: String = fm.get_zone_owner(zone_id)
	var enemy_army: Array = []
	var army_source := "none"
	if owner != "" and owner != "player" and owner != "bandit" and fm.factions.has(owner):
		enemy_army = fm.build_faction_army(owner)
		army_source = "faction:%s" % owner
	else:
		enemy_army = fm.build_bandit_army(zone_id)
		army_source = "bandit(owner='%s')" % owner
	if enemy_army.is_empty():
		push_warning("Enemy army empty for zone %s (world map)" % zone_id)
		enemy_army = _build_fallback_enemy_army(80)
		army_source = "FALLBACK_BUDGET"
	var _total := 0
	var _parts := PackedStringArray()
	for _e in enemy_army:
		var _c: int = int(_e.get("count", 0))
		_total += _c
		var _t: int = int(_e.get("type", 0))
		var _tname: String = BattleUnitSystem.UnitType.keys()[_t] if _t >= 0 and _t < BattleUnitSystem.UnitType.size() else str(_t)
		_parts.append("%s=%d" % [_tname, _c])
	print("Battle start zone=%s source=%s total=%d [%s]" % [zone_id, army_source, _total, ", ".join(_parts)])

	var tile_x := 276
	var tile_y := -1
	if _zone_data_map.has(zone_id):
		var zd: LoyZoneData = _zone_data_map[zone_id]
		if zd.baked_offset != Vector2i(-99999, -99999):
			tile_x = zd.baked_offset.x + zd.width / 2
			tile_y = zd.baked_offset.y + zd.height / 2
	var ri := _get_battle_region_for_zone(zone_id, tile_x, tile_y)

	var divisions: Array = []
	if gm.save_data:
		divisions = gm.save_data.army_divisions.duplicate(true)

	var config := {
		"zone_name": zone_id,
		"player_army": player_army,
		"enemy_army": enemy_army,
		"battle_region": ri["battle_region"],
		"player_spawn_rect": ri["player_spawn_rect"],
		"enemy_spawn_rect": ri["enemy_spawn_rect"],
		"divisions": divisions,
	}

	toggle()
	print("World Map: Attack %s (owner=%s)" % [zone_name, owner])
	gm.start_battle(config)

# --- Army builders ---

func _build_player_army(player_level: int, hired: Dictionary) -> Array:
	var tm := {
		"infantry": [BattleUnitSystem.UnitType.INFANTRY, BattleUnitSystem.FormationType.LINE],
		"archer": [BattleUnitSystem.UnitType.ARCHER, BattleUnitSystem.FormationType.LOOSE_LINE],
		"cavalry": [BattleUnitSystem.UnitType.CAVALRY, BattleUnitSystem.FormationType.WEDGE],
		"heavy_infantry": [BattleUnitSystem.UnitType.HEAVY_INFANTRY, BattleUnitSystem.FormationType.SHIELD_WALL],
		"heavy_cavalry": [BattleUnitSystem.UnitType.HEAVY_CAVALRY, BattleUnitSystem.FormationType.WEDGE],
		"mage": [BattleUnitSystem.UnitType.MAGE, BattleUnitSystem.FormationType.LOOSE_LINE],
		"spear": [BattleUnitSystem.UnitType.SPEAR, BattleUnitSystem.FormationType.LINE],
		"horse_archer": [BattleUnitSystem.UnitType.HORSE_ARCHER, BattleUnitSystem.FormationType.LOOSE_LINE],
		"ranged_infantry": [BattleUnitSystem.UnitType.RANGED_INFANTRY, BattleUnitSystem.FormationType.LOOSE_LINE],
	}
	var army: Array = []
	# Only hired fighters — minimum 5 militia if nothing hired
	var hired_inf := int(hired.get("infantry", 0))
	army.append({"type": BattleUnitSystem.UnitType.INFANTRY, "count": maxi(5, hired_inf), "formation": BattleUnitSystem.FormationType.LINE})
	for tn in hired:
		if tn == "infantry":
			continue
		var cnt: int = int(hired[tn])
		if cnt > 0 and tm.has(tn):
			army.append({"type": tm[tn][0], "count": cnt, "formation": tm[tn][1]})
	return army

func _build_fallback_enemy_army(budget: int) -> Array:
	var t := maxi(30, budget)
	return [
		{"type": BattleUnitSystem.UnitType.INFANTRY, "count": int(t * 0.5), "formation": BattleUnitSystem.FormationType.LINE},
		{"type": BattleUnitSystem.UnitType.ARCHER, "count": int(t * 0.3), "formation": BattleUnitSystem.FormationType.LOOSE_LINE},
		{"type": BattleUnitSystem.UnitType.HEAVY_INFANTRY, "count": maxi(1, t - int(t * 0.5) - int(t * 0.3)), "formation": BattleUnitSystem.FormationType.SHIELD_WALL},
	]

# --- Battle regions ---

const ZONE_BATTLE_REGIONS := {
	"wastes": [Vector2i(276, -1), Vector2i(406, -47)],
	"rotgrove": [Vector2i(276, -1), Vector2i(406, -47)],
	"witchglade": [Vector2i(276, -1), Vector2i(406, -47)],
	"darlwood": [Vector2i(276, -1), Vector2i(406, -47)],
	"gallows": [Vector2i(265, 37), Vector2i(321, 39)],
	"wardens": [Vector2i(265, 37), Vector2i(321, 39)],
	"duskfarm": [Vector2i(124, 64), Vector2i(224, 45)],
	"dreadbridge": [Vector2i(137, -58), Vector2i(254, -70)],
	"cutthroat": [Vector2i(106, -47), Vector2i(-24, -53)],
	"frostpass": [Vector2i(-15, -206), Vector2i(-57, -135)],
	"barrows": [Vector2i(32, 125), Vector2i(32, 217)],
}

func _get_battle_region_for_zone(zone_id: String, tx: int, ty: int) -> Dictionary:
	if ZONE_BATTLE_REGIONS.has(zone_id):
		var p: Array = ZONE_BATTLE_REGIONS[zone_id]
		return _mk_region(p[0], p[1])
	return _nearest_region(tx, ty)

func _mk_region(ps: Vector2i, es: Vector2i) -> Dictionary:
	var pp := Vector2(ps.x * 32.0, ps.y * 32.0)
	var ep := Vector2(es.x * 32.0, es.y * 32.0)
	return {
		"battle_region": Rect2i(mini(ps.x, es.x) - 20, mini(ps.y, es.y) - 20, absi(ps.x - es.x) + 40, absi(ps.y - es.y) + 40),
		"player_spawn_rect": Rect2(pp.x - 400, pp.y - 200, 800, 400),
		"enemy_spawn_rect": Rect2(ep.x - 400, ep.y - 200, 800, 400),
	}

func _nearest_region(tx: int, ty: int) -> Dictionary:
	var pairs := [
		[Vector2i(276, -1), Vector2i(406, -47)],
		[Vector2i(265, 37), Vector2i(321, 39)],
		[Vector2i(124, 64), Vector2i(224, 45)],
		[Vector2i(137, -58), Vector2i(254, -70)],
		[Vector2i(106, -47), Vector2i(-24, -53)],
		[Vector2i(-15, -206), Vector2i(-57, -135)],
		[Vector2i(32, 125), Vector2i(32, 217)],
	]
	var ap := Vector2(tx, ty)
	var bd := INF
	var bp: Array = pairs[0]
	for p in pairs:
		var d := ap.distance_squared_to(Vector2(p[0] + p[1]) * 0.5)
		if d < bd:
			bd = d
			bp = p
	return _mk_region(bp[0], bp[1])
