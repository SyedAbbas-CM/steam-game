class_name HeightSystem
extends Node2D

const PlayerQuery = preload("res://scripts/systems/player_query.gd")

## 2.5D terrain height system.
## Raised terrain is visually shifted upward. Inner lips mark edges.
## South cliffs show dirt face. East/west are thin. North is a crease.
## Supports GRASS (outdoor) and STONE (mine/dungeon) themes.

enum HeightTheme { GRASS, STONE }

const MIN_LEVEL := -3
const MAX_LEVEL := 3
const LEVEL_COUNT := MAX_LEVEL - MIN_LEVEL + 1  # 7

var tile_size: int = 8
var height_px: int = 5    # visual y-offset per height level
var cliff_px: int = 5     # south cliff face px per height diff level
var theme: int = HeightTheme.GRASS

# Configurable ramp tile — defaults to grass_dark, mines override with dirt tile
var ramp_atlas: Vector2i = Vector2i(8, 14)

var height_map: Dictionary = {}
var ramp_cells: Dictionary = {}

var _wall_body: StaticBody2D = null
var _collision_shapes: Array[CollisionShape2D] = []
var _visual_layers: Array[TileMapLayer] = []
var _overlays: Array[Node2D] = []
var _source_ground: TileMapLayer = null

# Coupling with LightingManager — populated in build()
var _shadow_alpha_mult: float = 1.0
var _is_dark_mood: bool = false

func set_height(cell: Vector2i, level: int) -> void:
	height_map[cell] = clampi(level, MIN_LEVEL, MAX_LEVEL)

func _layer_index(level: int) -> int:
	return clampi(level - MIN_LEVEL, 0, LEVEL_COUNT - 1)

var _debug_overlay: Node2D = null
var _debug_visible: bool = false

func toggle_debug_overlay() -> void:
	_debug_visible = not _debug_visible
	if _debug_visible:
		_build_debug_overlay()
	elif _debug_overlay and is_instance_valid(_debug_overlay):
		_debug_overlay.queue_free()
		_debug_overlay = null

func _build_debug_overlay() -> void:
	if _debug_overlay and is_instance_valid(_debug_overlay):
		_debug_overlay.queue_free()
	_debug_overlay = Node2D.new()
	_debug_overlay.name = "HeightDebugOverlay"
	_debug_overlay.z_index = 100
	add_child(_debug_overlay)
	var ts = tile_size
	for cell in height_map:
		var h: int = height_map[cell]
		# Number label
		var lbl := Label.new()
		lbl.text = ("+%d" % h) if h > 0 else str(h)
		lbl.add_theme_font_size_override("font_size", 6)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0) if h > 0 else (Color(0.5, 0.8, 1.0) if h < 0 else Color(0.8, 0.8, 0.8)))
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 2)
		lbl.position = Vector2(cell.x * ts + 1, cell.y * ts - h * height_px - 1)
		_debug_overlay.add_child(lbl)
		# Ramp marker (small blue dot in corner)
		if is_ramp(cell):
			var dot := ColorRect.new()
			dot.color = Color(0.2, 0.5, 1.0, 0.9)
			dot.position = Vector2(cell.x * ts + ts - 2, cell.y * ts - h * height_px + 1)
			dot.size = Vector2(2, 2)
			_debug_overlay.add_child(dot)

func _cell_hash(x: int, y: int, salt: int = 0) -> int:
	## Deterministic per-cell hash so procedural noise stays stable between rebuilds.
	## Replaces raw randi() in draw functions to stop overlays from shimmering.
	var h: int = (x * 374761393 + y * 668265263 + salt * 2147483647) ^ 0x9E3779B1
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))

func _level_tint(level: int) -> Color:
	## Stronger range so the floor itself communicates elevation. Pits are now
	## noticeably darker and cooler; peaks brighter and warmer. The tint does the
	## work that overlay outlines were trying (and failing) to do.
	match level:
		-3: return Color(0.55, 0.60, 0.68)
		-2: return Color(0.68, 0.72, 0.78)
		-1: return Color(0.82, 0.85, 0.88)
		0:  return Color(1.00, 1.00, 1.00)
		1:  return Color(1.10, 1.08, 1.02)
		2:  return Color(1.18, 1.15, 1.04)
		3:  return Color(1.26, 1.21, 1.06)
	return Color.WHITE

func get_actor_y_offset(world_pos: Vector2) -> float:
	## Visual y-offset an actor should apply to its sprite so it appears to stand on
	## the tile at world_pos. Negative = raised, positive = sunken (pit).
	## On a ramp, lerps between low/high level based on position within the tile.
	if tile_size <= 0:
		return 0.0
	var ts := tile_size
	var tile := Vector2i(int(floor(world_pos.x / float(ts))), int(floor(world_pos.y / float(ts))))
	var h := get_height(tile)
	if is_ramp(tile):
		# Find the higher adjacent tile — the ramp interpolates between h and that height.
		var top := h
		var up_dir := Vector2i.ZERO
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var nh := get_height(tile + d)
			if nh > top:
				top = nh
				up_dir = d
		if up_dir != Vector2i.ZERO and top != h:
			var local_x := (world_pos.x - float(tile.x * ts)) / float(ts)
			var local_y := (world_pos.y - float(tile.y * ts)) / float(ts)
			var t := 0.0
			if up_dir == Vector2i(0, -1):
				t = 1.0 - local_y
			elif up_dir == Vector2i(0, 1):
				t = local_y
			elif up_dir == Vector2i(1, 0):
				t = local_x
			elif up_dir == Vector2i(-1, 0):
				t = 1.0 - local_x
			t = clampf(t, 0.0, 1.0)
			return -lerpf(float(h), float(top), t) * float(height_px)
	return -float(h) * float(height_px)

func set_ramp(cell: Vector2i) -> void:
	ramp_cells[cell] = true

func apply_resource(data: TerrainHeightMap) -> void:
	## Loads heights + ramps from an authored TerrainHeightMap resource. Call before build().
	if data == null:
		return
	height_map.clear()
	ramp_cells.clear()
	for key in data.heights.keys():
		height_map[key] = clampi(int(data.heights[key]), MIN_LEVEL, MAX_LEVEL)
	for key in data.ramps.keys():
		ramp_cells[key] = true

func set_ramp_chain(start_cell: Vector2i, dir: Vector2i, length: int, low_h: int = 0) -> void:
	## Marks `length` consecutive cells starting at `start_cell` and walking in `dir` as ramp tiles
	## at the lower level. Each tile renders its own chevron, so a 3-tile chain reads as a long slope.
	## Caller still has to set the higher plateau in the direction the chain points toward.
	for i in range(length):
		var cell := start_cell + dir * i
		set_height(cell, low_h)
		set_ramp(cell)

func get_height(cell: Vector2i) -> int:
	return height_map.get(cell, 0)

func is_ramp(cell: Vector2i) -> bool:
	return ramp_cells.has(cell)

func build(ground_layer: TileMapLayer) -> void:
	_clear()
	_source_ground = ground_layer
	_sync_lighting_state()
	_build_collision()
	_build_visual_layers()
	_build_overlays()
	ground_layer.visible = false

	# Combat actors must render above terrain layers (max overlay z = 4)
	# Bullets/enemies at z=5, player at z=6 so player draws on top of enemies
	var p = PlayerQuery.get_primary_player(get_tree())
	if p:
		p.z_index = 6
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e is Node2D:
			e.z_index = 5

func refresh_from_ground() -> void:
	if _source_ground == null:
		return
	build(_source_ground)

func reveal_ground_cell(cell: Vector2i, source_id: int, atlas: Vector2i, level: int = 0) -> void:
	height_map[cell] = clampi(level, MIN_LEVEL, MAX_LEVEL)
	if _visual_layers.is_empty():
		return
	_visual_layers[_layer_index(level)].set_cell(cell, source_id, atlas)

func _clear() -> void:
	for n in _overlays:
		if is_instance_valid(n):
			n.queue_free()
	_overlays.clear()
	for layer in _visual_layers:
		if is_instance_valid(layer):
			layer.queue_free()
	_visual_layers.clear()
	for shape in _collision_shapes:
		if is_instance_valid(shape):
			shape.queue_free()
	_collision_shapes.clear()
	if _wall_body and is_instance_valid(_wall_body):
		_wall_body.queue_free()
		_wall_body = null

# ── Lighting coupling ──

func _sync_lighting_state() -> void:
	var lm = get_node_or_null("/root/LightingManager")
	if lm == null:
		_shadow_alpha_mult = 1.0
		_is_dark_mood = false
		return
	if lm.has_method("get_shadow_alpha_mult"):
		_shadow_alpha_mult = float(lm.get_shadow_alpha_mult())
	if lm.has_method("get_current_mood"):
		var mood = lm.get_current_mood()
		_is_dark_mood = mood != null and bool(mood.is_dark)

# ── Theme colors ──

func _lip_color_south() -> Color:
	if theme == HeightTheme.STONE:
		return Color(0.22, 0.20, 0.18)
	return Color(0.10, 0.25, 0.06)

func _lip_color_east() -> Color:
	if theme == HeightTheme.STONE:
		return Color(0.24, 0.22, 0.19)
	return Color(0.11, 0.27, 0.07)

func _lip_color_west() -> Color:
	if theme == HeightTheme.STONE:
		return Color(0.18, 0.16, 0.14)
	return Color(0.08, 0.20, 0.05)

func _soft_hill_rim() -> Color:
	if theme == HeightTheme.STONE:
		return Color(0.28, 0.26, 0.22)
	return Color(0.14, 0.32, 0.08)

func _soft_hill_shadow() -> Color:
	if theme == HeightTheme.STONE:
		return Color(0.08, 0.07, 0.06)
	return Color(0.05, 0.08, 0.02)

func _cliff_lip() -> Color:
	if theme == HeightTheme.STONE:
		return Color(0.30, 0.28, 0.24)
	return Color(0.14, 0.32, 0.08)

func _cliff_dirt_top() -> Color:
	if theme == HeightTheme.STONE:
		return Color(0.38, 0.34, 0.28)
	return Color(0.45, 0.32, 0.18)

func _cliff_dirt_bot() -> Color:
	if theme == HeightTheme.STONE:
		return Color(0.22, 0.18, 0.14)
	return Color(0.28, 0.18, 0.09)

func _cliff_dirt_speckle() -> Color:
	if theme == HeightTheme.STONE:
		return Color(0.32, 0.30, 0.28)
	return Color(0.38, 0.35, 0.30)

func _side_face_west() -> Color:
	if theme == HeightTheme.STONE:
		return Color(0.28, 0.24, 0.20)
	return Color(0.35, 0.25, 0.12)

func _side_face_east() -> Color:
	if theme == HeightTheme.STONE:
		return Color(0.32, 0.28, 0.22)
	return Color(0.38, 0.28, 0.14)

# ── Collision ──

func _build_collision() -> void:
	_wall_body = StaticBody2D.new()
	_wall_body.name = "CliffWalls"
	# Layer 7 (bit 64) — distinct from regular walls (layer 5/bit 16)
	# so ranged bullets can pass through while melee/swing bullets are blocked.
	_wall_body.collision_layer = 64
	_wall_body.collision_mask = 0
	add_child(_wall_body)

	# Wall the side of any cell whose neighbor is lower (works for pits too — h=0 next to h=-1).
	# Each pair only places a wall on the higher side, since the loop visits both cells but only
	# the one with the strictly greater height satisfies nh < h.
	for cell in height_map:
		var h = height_map[cell]
		for dir in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var nb = cell + dir
			var nh = get_height(nb)
			if nh < h and not is_ramp(cell) and not is_ramp(nb):
				_add_wall(cell, dir)

func _add_wall(cell: Vector2i, dir: Vector2i) -> void:
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	var ts = tile_size
	var h = get_height(cell)
	var y_off = -h * height_px  # match visual displacement
	# 4px-thick walls (was 2). Player tunnels through 2px walls at twin-stick speeds.
	const WALL_THICK := 4
	if dir == Vector2i(0, 1):
		rect.size = Vector2(ts, WALL_THICK)
		shape.position = Vector2(cell.x * ts + ts / 2.0, (cell.y + 1) * ts + WALL_THICK / 2.0 + y_off)
	elif dir == Vector2i(0, -1):
		rect.size = Vector2(ts, WALL_THICK)
		shape.position = Vector2(cell.x * ts + ts / 2.0, cell.y * ts - WALL_THICK / 2.0 + y_off)
	elif dir == Vector2i(1, 0):
		rect.size = Vector2(WALL_THICK, ts)
		shape.position = Vector2((cell.x + 1) * ts + WALL_THICK / 2.0, cell.y * ts + ts / 2.0 + y_off)
	elif dir == Vector2i(-1, 0):
		rect.size = Vector2(WALL_THICK, ts)
		shape.position = Vector2(cell.x * ts - WALL_THICK / 2.0, cell.y * ts + ts / 2.0 + y_off)
	shape.shape = rect
	_wall_body.add_child(shape)
	_collision_shapes.append(shape)

# ── Visual layers ──

func _build_visual_layers() -> void:
	var tileset = _source_ground.tile_set
	for i in range(LEVEL_COUNT):
		var level := MIN_LEVEL + i
		var layer = TileMapLayer.new()
		layer.name = "Height_%d" % level
		layer.tile_set = tileset
		# Negative level → positive y offset → drawn lower (pit floor sinks below baseline)
		layer.position.y = -level * height_px
		layer.z_index = level
		# Distinct ground tint per level so the player can instantly read elevation:
		# pits darker (in shadow), peaks lighter (more sunlight).
		layer.modulate = _level_tint(level)
		add_child(layer)
		_visual_layers.append(layer)

	# Cache a fallback grass tile from the first valid source cell — used when a
	# ramp ends up on an unpainted slot so it never renders black.
	var fallback_src: int = -1
	var fallback_atlas: Vector2i = Vector2i.ZERO
	for any_cell in _source_ground.get_used_cells():
		var any_src: int = _source_ground.get_cell_source_id(any_cell)
		if any_src >= 0:
			fallback_src = any_src
			fallback_atlas = _source_ground.get_cell_atlas_coords(any_cell)
			break

	for cell in height_map:
		var h = height_map[cell]
		var src = _source_ground.get_cell_source_id(cell)
		var atlas = _source_ground.get_cell_atlas_coords(cell)
		# Ramps use the grass base tile + a dirt overlay. If the cell has no source
		# tile (e.g. a ramp placed outside painted floor), borrow from a neighbor or
		# fall back to the cached tile. The overlay carries the "dirt ramp" look,
		# the grass tile carries the natural blend into surrounding green.
		if src < 0:
			if is_ramp(cell):
				for nb_dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
					var nb = cell + nb_dir
					var nb_src = _source_ground.get_cell_source_id(nb)
					if nb_src >= 0:
						src = nb_src
						atlas = _source_ground.get_cell_atlas_coords(nb)
						break
				if src < 0 and fallback_src >= 0:
					src = fallback_src
					atlas = fallback_atlas
		if src < 0:
			continue
		var idx := _layer_index(h)
		_visual_layers[idx].set_cell(cell, src, atlas)

# ── Overlays ──

func _build_overlays() -> void:
	# Any cell with a strictly-lower neighbor draws cliff features on that edge,
	# regardless of whether the cell itself is raised or just at baseline above a pit.
	for cell in height_map:
		var h = height_map[cell]

		var s_nb = cell + Vector2i(0, 1)
		var n_nb = cell + Vector2i(0, -1)
		var e_nb = cell + Vector2i(1, 0)
		var w_nb = cell + Vector2i(-1, 0)

		var diff_s = h - get_height(s_nb)
		var diff_n = h - get_height(n_nb)
		var diff_e = h - get_height(e_nb)
		var diff_w = h - get_height(w_nb)

		var ramp_self = is_ramp(cell)

		if diff_s > 0 and not ramp_self and not is_ramp(s_nb):
			if h > 0:
				_draw_raised_inner_seam(cell, h, Vector2i(0, 1))
			_draw_top_rim(cell, h, Vector2i(0, 1))
			_draw_south_face(cell, diff_s, h)
			_draw_contact_shadow(s_nb, get_height(s_nb), diff_s)

		# Sides: thin dirt strip (1-2 px) so the platform silhouette is visible,
		# plus a soft dark seam so they don't read as posts. Both together = thin
		# but present cliff side, no fence-post look.
		if diff_e > 0 and not ramp_self and not is_ramp(e_nb):
			_draw_side_strip(cell, diff_e, h, true)
			_draw_side_seam(cell, h, true)
		if diff_w > 0 and not ramp_self and not is_ramp(w_nb):
			_draw_side_strip(cell, diff_w, h, false)
			_draw_side_seam(cell, h, false)

		# North edge: crease only for grass (avoids boxed-room look). STONE theme
		# or pit-step boundaries with diff>=2 get the full face — they need wall
		# mass to read as carved/recessed.
		if diff_n > 0 and not ramp_self and not is_ramp(n_nb):
			if theme == HeightTheme.STONE or diff_n >= 2:
				_draw_north_face(cell, h)
			else:
				_draw_north_crease(cell, h)

		# Pit edge darkening — extra shadow on pit-floor cells with a higher neighbor.
		# Lower-layer modulate alone doesn't sell "I'm in a pit"; a darker rim does.
		if h < 0:
			_maybe_draw_pit_edge_dark(cell, h, diff_s, diff_n, diff_e, diff_w)

		# Only south-side corner caps. North corners were adding boxed-room clutter
		# without helping readability — disabled until south corners are clean.
		if diff_s > 0 and diff_e > 0 and not ramp_self:
			_draw_south_side_corner(cell, h, true)
		if diff_s > 0 and diff_w > 0 and not ramp_self:
			_draw_south_side_corner(cell, h, false)

		# Inner-corner 2×2 black dots disabled — added more visual noise than they fixed.
		# _maybe_draw_inner_corner(cell, h)

		# Ramp slope indicators
		if ramp_self:
			_draw_ramp_slope(cell, h)

func _draw_inner_lip(cell: Vector2i, h: int, dir: Vector2i) -> void:
	var ts = tile_size
	var img: Image
	var pos: Vector2

	if dir == Vector2i(0, 1):  # south edge
		img = Image.create(ts, 1, false, Image.FORMAT_RGBA8)
		for x in range(ts):
			img.set_pixel(x, 0, _px(_lip_color_south(), 0.015))
		pos = Vector2(cell.x * ts, (cell.y + 1) * ts - h * height_px - 1)
	elif dir == Vector2i(0, -1):  # north edge
		img = Image.create(ts, 1, false, Image.FORMAT_RGBA8)
		var a_n: float = clampf(0.08 * _shadow_alpha_mult, 0.0, 1.0)
		for x in range(ts):
			img.set_pixel(x, 0, Color(0, 0, 0, a_n))
		pos = Vector2(cell.x * ts, cell.y * ts - h * height_px)
	elif dir == Vector2i(1, 0):  # east edge
		img = Image.create(1, ts, false, Image.FORMAT_RGBA8)
		for y in range(ts):
			img.set_pixel(0, y, _px(_lip_color_east(), 0.015))
		pos = Vector2((cell.x + 1) * ts - 1, cell.y * ts - h * height_px)
	else:  # west edge
		img = Image.create(1, ts, false, Image.FORMAT_RGBA8)
		for y in range(ts):
			img.set_pixel(0, y, _px(_lip_color_west(), 0.015))
		pos = Vector2(cell.x * ts, cell.y * ts - h * height_px)

	_add_overlay(img, pos, h + 1)

const SHORT_WALL_PX := 3

func _draw_south_face(cell: Vector2i, diff: int, h: int) -> void:
	# Single opaque cliff face. Total height = diff × height_px so it bridges the
	# exact visual gap to the lower neighbor — no transparency, no black bleed.
	# Top SHORT_WALL_PX = bright dirt lip; remainder = dark gradient (depth).
	var ts = tile_size
	var total_h: int = diff * height_px
	var img := Image.create(ts, total_h, false, Image.FORMAT_RGBA8)
	var lip_top := _cliff_dirt_top()
	var dark_top := _cliff_dirt_bot()
	var dark_bot := _cliff_dirt_bot().darkened(0.45)
	var grass_root := _cliff_lip().lightened(0.10)  # for irregular grass-root tufts
	# Stable bottom contact line color — darkest pixel anchors the cliff's bottom edge.
	var bottom_line: Color = dark_bot.darkened(0.30)
	for y in range(total_h):
		for x in range(ts):
			var col: Color
			var hsh: int = _cell_hash(cell.x * ts + x, cell.y * height_px + y, 1)
			if y < SHORT_WALL_PX:
				var t = float(y) / float(maxi(SHORT_WALL_PX - 1, 1))
				col = lip_top.lerp(dark_top, t)
				if y == SHORT_WALL_PX - 1 and hsh % 6 == 0:
					col = grass_root
			elif y == total_h - 1:
				# Bottom contact line — uniform, anchors the cliff base
				col = bottom_line
			else:
				var t = float(y - SHORT_WALL_PX) / float(maxi(total_h - SHORT_WALL_PX - 1, 1))
				col = dark_top.lerp(dark_bot, t)
				var r = hsh % 22
				if r == 0:
					col = _cliff_dirt_speckle().darkened(0.25)
				elif r == 1:
					col = dark_bot.darkened(0.20)
				elif r == 2:
					col = dark_top.lightened(0.05)
			# Tiny stable RGB jitter (skip on the bottom contact line so it stays clean)
			if y != total_h - 1:
				var jitter: float = (float((hsh >> 4) % 100) / 100.0 - 0.5) * 0.06
				col = Color(clampf(col.r + jitter, 0, 1), clampf(col.g + jitter, 0, 1), clampf(col.b + jitter, 0, 1), col.a)
			img.set_pixel(x, y, col)
	# Tuck 1 px under the upper tile so the cliff lip overlaps the grass edge
	# instead of butting against it (eliminates the "cut strip" look).
	var py: float = (cell.y + 1) * ts - h * height_px - 1
	_add_overlay(img, Vector2(cell.x * ts, py), h)

func _draw_side_face(cell: Vector2i, diff: int, h: int, is_east: bool) -> void:
	# Side seam, not a wall: thin 1-2 px trim that lives exactly inside the cell
	# tile bounds. The south face is the main visible cliff — sides only support it
	# as dark seams. The SHORT_WALL_PX downward extension is removed; corner welds
	# handle the bridge into the south face explicitly.
	var face_w: int = clampi(diff, 1, 2)
	var ts: int = tile_size
	var trim_h: int = ts
	var trim_img := Image.create(face_w, trim_h, false, Image.FORMAT_RGBA8)
	var top_col = (_side_face_east() if is_east else _side_face_west()).darkened(0.15)
	var bot_col = top_col.darkened(0.25)
	var inner_dark: Color = top_col.darkened(0.45)
	for y in range(trim_h):
		var t: float = float(y) / float(maxi(trim_h - 1, 1))
		var base: Color = top_col.lerp(bot_col, t)
		for x in range(face_w):
			var col: Color = base
			# Outer edge (away from cliff) occasionally eroded — breaks the perfect-post silhouette
			var outer_x: int = (face_w - 1) if is_east else 0
			if x == outer_x and randi() % 4 == 0:
				trim_img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			# Inner edge (touching cliff) reads darker for relief
			var inner_x: int = 0 if is_east else (face_w - 1)
			if x == inner_x:
				col = inner_dark
			if randi() % 16 == 0:
				col = _cliff_dirt_speckle().darkened(0.20)
			trim_img.set_pixel(x, y, _px(col, 0.03))
	var px: float
	if is_east:
		px = (cell.x + 1) * ts
	else:
		px = cell.x * ts - face_w
	var py: float = cell.y * ts - h * height_px
	_add_overlay(trim_img, Vector2(px, py), h)

func _draw_south_side_corner(cell: Vector2i, h: int, is_east: bool) -> void:
	# Tiny south corner cap — 3 wide × height_px tall. Just enough mass to "close"
	# the front face where it turns. Outer corner pixel transparent so it doesn't
	# read as a square dirt block.
	var ts = tile_size
	var w := 3
	var ph: int = height_px
	var img := Image.create(w, ph, false, Image.FORMAT_RGBA8)
	var top: Color = _cliff_dirt_top().darkened(0.05)
	var bot: Color = _cliff_dirt_bot().darkened(0.15)
	for y in range(ph):
		for x in range(w):
			# Diagonal cutout at the outer corner
			var outer_x: int = (w - 1) if is_east else 0
			if y == ph - 1 and x == outer_x:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var t: float = float(y) / float(maxi(ph - 1, 1))
			var col: Color = top.lerp(bot, t)
			img.set_pixel(x, y, _px(col, 0.02))
	var px: float = (cell.x + 1) * ts - 1 if is_east else cell.x * ts - (w - 1)
	var py: float = (cell.y + 1) * ts - h * height_px - 1
	_add_overlay(img, Vector2(px, py), h + 2)

func _draw_north_side_corner(cell: Vector2i, h: int, is_east: bool) -> void:
	# Mirror of south corner. Same 5×(height_px+3) compact L, lip at the bottom
	# of the patch (touches upper tile edge above on screen), diagonal cutout at
	# the OUTER TOP corner.
	var ts = tile_size
	var w := 5
	var ph: int = height_px + 3
	var arm_w := 2
	var img := Image.create(w, ph, false, Image.FORMAT_RGBA8)
	var lip: Color = _cliff_lip()
	var top: Color = _cliff_dirt_top()
	var bot: Color = _cliff_dirt_bot().darkened(0.25)
	for y in range(ph):
		for x in range(w):
			var side_band: bool = (x >= w - arm_w) if is_east else (x < arm_w)
			var face_band: bool = y < ph - 2
			if not side_band and not face_band:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			# Outer diagonal cutout at the top-outer pixel
			var outer_x: int = (w - 1) if is_east else 0
			if y == 0 and x == outer_x:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var col: Color
			if y == ph - 3 or y == ph - 4:
				col = lip
			else:
				var t: float = float(ph - 5 - y) / float(maxi(ph - 4, 1))
				col = top.lerp(bot, clampf(t, 0.0, 1.0))
			if randi() % 11 == 0 and y < ph - 4:
				col = _cliff_dirt_speckle().darkened(0.20)
			img.set_pixel(x, y, _px(col, 0.025))
	var px: float = (cell.x + 1) * ts - arm_w if is_east else cell.x * ts - (w - arm_w)
	var py: float = cell.y * ts - h * height_px - (ph - 2)
	_add_overlay(img, Vector2(px, py), h + 2)

func _draw_outer_corner(cell: Vector2i, h: int, is_southeast: bool) -> void:
	# L-shaped bridge patch that grabs both the bottom of the side trim and the
	# top of the south face. Starts BEFORE the south face's y so it overlaps with
	# the side trim's lower extension and fills the corner gap that two separate
	# rectangles can't cover.
	var ts = tile_size
	var w := 4
	var patch_h := SHORT_WALL_PX + 3
	var img := Image.create(w, patch_h, false, Image.FORMAT_RGBA8)
	var lip := _cliff_lip()
	var top := _cliff_dirt_top().darkened(0.05)
	var bot := _cliff_dirt_bot().darkened(0.20)
	for y in range(patch_h):
		for x in range(w):
			var in_vertical: bool = (x >= w - 2) if is_southeast else (x < 2)
			var in_horizontal: bool = y >= 2
			if not in_vertical and not in_horizontal:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var col: Color
			if y == 2:
				col = lip
			else:
				var t := float(y) / float(maxi(patch_h - 1, 1))
				col = top.lerp(bot, t)
			img.set_pixel(x, y, _px(col, 0.02))
	var px: float = (cell.x + 1) * ts - 2 if is_southeast else cell.x * ts - 2
	# Start ABOVE the south face so it overlaps the bottom of the side trim.
	var py: float = (cell.y + 1) * ts - h * height_px - 3
	_add_overlay(img, Vector2(px, py), h + 1)

func _maybe_draw_inner_corner(cell: Vector2i, h: int) -> void:
	# An "inner corner" forms when this cell is part of a higher plateau and the
	# diagonal neighbor is ALSO at this height, but one of the cardinal neighbors
	# is lower — creating a concave bend. We darken the inside-of-the-bend corner
	# pixel so the L-shape doesn't read as two disjointed strips.
	var ts = tile_size
	var directions := [
		{"diag": Vector2i(1, 1),  "card_a": Vector2i(1, 0),  "card_b": Vector2i(0, 1),  "corner": Vector2(ts - 2, ts - 2)},
		{"diag": Vector2i(-1, 1), "card_a": Vector2i(-1, 0), "card_b": Vector2i(0, 1),  "corner": Vector2(0, ts - 2)},
		{"diag": Vector2i(1, -1), "card_a": Vector2i(1, 0),  "card_b": Vector2i(0, -1), "corner": Vector2(ts - 2, 0)},
		{"diag": Vector2i(-1, -1),"card_a": Vector2i(-1, 0), "card_b": Vector2i(0, -1), "corner": Vector2(0, 0)},
	]
	for d in directions:
		var diag_h = get_height(cell + d["diag"])
		var card_a_h = get_height(cell + d["card_a"])
		var card_b_h = get_height(cell + d["card_b"])
		# Concave: both cardinals match my height, but the diagonal is lower
		# (i.e. the plateau wraps around three sides of the diagonal cell).
		if card_a_h == h and card_b_h == h and diag_h < h:
			var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
			var col := Color(0.0, 0.0, 0.0, 0.20 * _shadow_alpha_mult)
			img.fill(col)
			_add_overlay(img, Vector2(cell.x * ts + d["corner"].x, cell.y * ts - h * height_px + d["corner"].y), h + 1)

func _draw_north_crease(cell: Vector2i, h: int) -> void:
	# Compressed 2-row back edge: 1 px dark grass crease + 1 px broken dirt rim.
	# Stronger than a single fade so the back edge actually shows, but still light
	# enough that the plateau doesn't read as an outlined rectangle.
	var ts = tile_size
	var img = Image.create(ts, 2, false, Image.FORMAT_RGBA8)
	var crease := Color(0.0, 0.0, 0.0, 0.25 * _shadow_alpha_mult)
	var dirt: Color = _cliff_dirt_top().darkened(0.25)
	var dirt_a := Color(dirt.r, dirt.g, dirt.b, 0.50)
	for x in range(ts):
		img.set_pixel(x, 0, crease)
		# Broken dirt rim — skip ~1 in 4 for natural erosion
		if _cell_hash(cell.x * ts + x, cell.y, 7) % 4 == 0:
			img.set_pixel(x, 1, Color(0, 0, 0, 0))
		else:
			img.set_pixel(x, 1, dirt_a)
	_add_overlay(img, Vector2(cell.x * ts, cell.y * ts - h * height_px), h)

func _draw_north_face(cell: Vector2i, h: int) -> void:
	# Back wall — ALWAYS one row tall. A tall north face for big drops would extend
	# into the visible lower-neighbor terrain north of the cliff and look like the
	# wall is "growing into normal terrain". One row is enough to read the edge;
	# the drop magnitude is conveyed by the lower layer's modulate.
	var ts = tile_size
	var total_h: int = height_px
	var img := Image.create(ts, total_h, false, Image.FORMAT_RGBA8)
	var lip_top := _cliff_dirt_top()
	var dark_top := _cliff_dirt_bot()
	var grass_root := _cliff_lip().lightened(0.10)
	for y in range(total_h):
		for x in range(ts):
			var col: Color
			if y >= total_h - SHORT_WALL_PX:
				var t = float(total_h - 1 - y) / float(maxi(SHORT_WALL_PX - 1, 1))
				col = lip_top.lerp(dark_top, t)
				# Grass-root tufts at the lip
				if y == total_h - SHORT_WALL_PX and randi() % 6 == 0:
					col = grass_root
			else:
				col = dark_top
				var r = randi() % 18
				if r == 0:
					col = _cliff_dirt_speckle().darkened(0.25)
				elif r == 1:
					col = dark_top.darkened(0.15)
			img.set_pixel(x, y, _px(col, 0.03))
	var py: float = cell.y * ts - h * height_px - total_h
	_add_overlay(img, Vector2(cell.x * ts, py), h)

func _draw_side_shadow(cell: Vector2i, nh: int, from_east: bool) -> void:
	# Vertical contact shadow on the lower tile adjacent to a side cliff
	var ts = tile_size
	var shadow_w = 2
	var img = Image.create(shadow_w, ts, false, Image.FORMAT_RGBA8)
	var a_max: float = 0.15 * _shadow_alpha_mult
	for y in range(ts):
		for x in range(shadow_w):
			var a: float
			if from_east:
				# Shadow on west side of the lower tile (cliff is to the west)
				a = lerpf(a_max, 0.0, float(x) / float(shadow_w))
			else:
				# Shadow on east side of the lower tile (cliff is to the east)
				a = lerpf(0.0, a_max, float(x) / float(shadow_w))
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, a))
	var px: float
	if from_east:
		# Cliff is to the west of this cell, shadow on left edge
		px = cell.x * ts
	else:
		# Cliff is to the east of this cell, shadow on right edge
		px = (cell.x + 1) * ts - shadow_w
	_add_overlay(img, Vector2(px, cell.y * ts - nh * height_px), nh + 1)

func _draw_ramp_slope(cell: Vector2i, h: int) -> void:
	# Direction: prefer a higher neighbor (up-ramp); fall back to a lower neighbor
	# (down-ramp into a pit). Chevrons always point UPHILL.
	var ts = tile_size
	var ramp_dir = Vector2i.ZERO
	for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if get_height(cell + dir) > h:
			ramp_dir = dir
			break
	if ramp_dir == Vector2i.ZERO:
		for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
			if get_height(cell + dir) < h:
				ramp_dir = -dir
				break
	if ramp_dir == Vector2i.ZERO:
		return

	# Opaque dirt gradient that goes from the LOW level's tint at one end to the
	# HIGH level's tint at the other. Perpendicular edges feather into transparency
	# so the dirt blends seamlessly into the surrounding grass instead of butting
	# against it with a hard line.
	#
	# Find the high-neighbor level so we know the upper tint to blend toward.
	var high_h := h
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var nh = get_height(cell + d)
		if nh > high_h:
			high_h = nh
	var low_tint: Color = _level_tint(h)
	var high_tint: Color = _level_tint(high_h)
	var dirt_low: Color = _cliff_dirt_top().darkened(0.10)
	var dirt_high: Color = _cliff_dirt_top().lightened(0.05)
	# Apply the level tints so the dirt visually matches surrounding floor brightness.
	dirt_low = Color(dirt_low.r * low_tint.r, dirt_low.g * low_tint.g, dirt_low.b * low_tint.b)
	dirt_high = Color(dirt_high.r * high_tint.r, dirt_high.g * high_tint.g, dirt_high.b * high_tint.b)
	var img := Image.create(ts, ts, false, Image.FORMAT_RGBA8)
	for y in range(ts):
		for x in range(ts):
			# t = 0 at low end, 1 at high end of the slope
			var t: float = 0.0
			# perp = 0 at center, 1 at the two perpendicular edges (used to feather)
			var perp: float = 0.0
			if ramp_dir == Vector2i(0, -1):
				t = float(ts - 1 - y) / float(maxi(ts - 1, 1))
				perp = abs(float(x) - float(ts - 1) * 0.5) / float(maxi(ts - 1, 1) * 0.5)
			elif ramp_dir == Vector2i(0, 1):
				t = float(y) / float(maxi(ts - 1, 1))
				perp = abs(float(x) - float(ts - 1) * 0.5) / float(maxi(ts - 1, 1) * 0.5)
			elif ramp_dir == Vector2i(1, 0):
				t = float(ts - 1 - x) / float(maxi(ts - 1, 1))
				perp = abs(float(y) - float(ts - 1) * 0.5) / float(maxi(ts - 1, 1) * 0.5)
			elif ramp_dir == Vector2i(-1, 0):
				t = float(x) / float(maxi(ts - 1, 1))
				perp = abs(float(y) - float(ts - 1) * 0.5) / float(maxi(ts - 1, 1) * 0.5)
			# Dirt color blends from low_tint dirt to high_tint dirt along the slope
			var col: Color = dirt_low.lerp(dirt_high, t)
			# Feather perpendicular edges into transparency — clamp so center stays opaque
			var feather: float = clampf(1.0 - smoothstep(0.55, 1.0, perp), 0.0, 1.0)
			# Texture jitter
			var jr: float = randf_range(-0.025, 0.025)
			col = Color(clampf(col.r + jr, 0, 1), clampf(col.g + jr, 0, 1), clampf(col.b + jr, 0, 1), feather)
			img.set_pixel(x, y, col)

	# Dirt streaks/stair marks (already tuned low alpha)
	_stamp_ramp_marks(img, ramp_dir, ts)

	_add_overlay(img, Vector2(cell.x * ts, cell.y * ts - h * height_px), h + 1)

	# Cap / rails / mouth-welds disabled — the dirt ramp_atlas base tile carries
	# the "ramp here" read on its own. Adding overlay patches on top was creating
	# muddy clutter without communicating slope direction better.
	# _draw_ramp_cap(cell, h, ramp_dir)
	# _draw_ramp_side_rails(cell, h, ramp_dir)
	# _draw_ramp_mouth_welds(cell, h, ramp_dir)

func _draw_ramp_mouth_welds(cell: Vector2i, h: int, ramp_dir: Vector2i) -> void:
	# Cheek pieces at the two mouth corners — connect cliff face into the ramp cap.
	# Each cheek is 2 px wide × height_px tall (north/south ramps) or 2 px tall ×
	# height_px wide (east/west). Opaque dirt — never translucent shadow.
	var ts = tile_size
	var cheek_thick := 2
	var dirt_top: Color = _cliff_dirt_top().darkened(0.05)
	var dirt_bot: Color = _cliff_dirt_bot().darkened(0.10)
	if ramp_dir == Vector2i(0, -1):
		# North-up ramp: cheeks are 2 px wide, height_px tall, at the LEFT and RIGHT
		# of the cap area just above the ramp tile. They flank the cap horizontally.
		var img_l := Image.create(cheek_thick, height_px, false, Image.FORMAT_RGBA8)
		var img_r := Image.create(cheek_thick, height_px, false, Image.FORMAT_RGBA8)
		for y in range(height_px):
			var t: float = float(y) / float(maxi(height_px - 1, 1))
			var col: Color = dirt_top.lerp(dirt_bot, t)
			for x in range(cheek_thick):
				img_l.set_pixel(x, y, _px(col, 0.02))
				img_r.set_pixel(x, y, _px(col, 0.02))
		var base_y: float = cell.y * ts - h * height_px - height_px
		_add_overlay(img_l, Vector2(cell.x * ts, base_y), h + 1)
		_add_overlay(img_r, Vector2((cell.x + 1) * ts - cheek_thick, base_y), h + 1)
	elif ramp_dir == Vector2i(0, 1):
		var img_l := Image.create(cheek_thick, height_px, false, Image.FORMAT_RGBA8)
		var img_r := Image.create(cheek_thick, height_px, false, Image.FORMAT_RGBA8)
		for y in range(height_px):
			var t: float = float(y) / float(maxi(height_px - 1, 1))
			var col: Color = dirt_bot.lerp(dirt_top, t)
			for x in range(cheek_thick):
				img_l.set_pixel(x, y, _px(col, 0.02))
				img_r.set_pixel(x, y, _px(col, 0.02))
		var base_y: float = (cell.y + 1) * ts - h * height_px
		_add_overlay(img_l, Vector2(cell.x * ts, base_y), h + 1)
		_add_overlay(img_r, Vector2((cell.x + 1) * ts - cheek_thick, base_y), h + 1)
	# East/west ramp cheeks could go here later if/when side ramps are used.

func _draw_ramp_cap(cell: Vector2i, h: int, ramp_dir: Vector2i) -> void:
	# Dirt-only ramp extension. The cap should read as a slope cut INTO the cliff —
	# not a grass-to-dirt translucent stain. All opaque dirt colors, slight highlight
	# at the lip end so the slope direction is implied.
	var ts = tile_size
	var cap_h: int = height_px
	var img: Image
	var pos := Vector2(cell.x * ts, cell.y * ts - h * height_px)
	var dirt_light: Color = _cliff_dirt_top().lightened(0.05)
	var dirt_mid: Color = _cliff_dirt_top().darkened(0.10)
	var dirt_dark: Color = _cliff_dirt_bot().darkened(0.05)
	if ramp_dir == Vector2i(0, -1):
		# Cap on the north side (above the ramp tile). Lip (light dirt) at the top
		# where it meets the plateau, gradient down to darker dirt at the ramp tile edge.
		img = Image.create(ts, cap_h, false, Image.FORMAT_RGBA8)
		for y in range(cap_h):
			for x in range(ts):
				var col: Color
				if y == 0:
					col = dirt_light
				else:
					var t: float = float(y - 1) / float(maxi(cap_h - 2, 1))
					col = dirt_mid.lerp(dirt_dark, t)
				if randi() % 12 == 0 and y > 0:
					col = _cliff_dirt_speckle().darkened(0.15)
				img.set_pixel(x, y, _px(col, 0.025))
		pos.y -= cap_h
	elif ramp_dir == Vector2i(0, 1):
		# Cap on the south side. Lip at the bottom, gradient up to dirt at the top.
		img = Image.create(ts, cap_h, false, Image.FORMAT_RGBA8)
		for y in range(cap_h):
			for x in range(ts):
				var col: Color
				if y == cap_h - 1:
					col = dirt_light
				else:
					var t: float = float(cap_h - 2 - y) / float(maxi(cap_h - 2, 1))
					col = dirt_mid.lerp(dirt_dark, t)
				if randi() % 12 == 0 and y < cap_h - 1:
					col = _cliff_dirt_speckle().darkened(0.15)
				img.set_pixel(x, y, _px(col, 0.025))
		pos.y += ts
	else:
		return
	_add_overlay(img, pos, h + 1)

func _draw_side_strip(cell: Vector2i, diff: int, h: int, is_east: bool) -> void:
	# Thin dirt strip — 1-2 px wide, full tile height. Restores side cliff presence
	# WITHOUT the fence-post look (kept narrow + outer edge broken).
	var ts = tile_size
	var w: int = clampi(diff, 1, 2)
	var img := Image.create(w, ts, false, Image.FORMAT_RGBA8)
	var top_col: Color = _cliff_dirt_top().darkened(0.10)
	var bot_col: Color = _cliff_dirt_bot().darkened(0.20)
	for y in range(ts):
		var t: float = float(y) / float(maxi(ts - 1, 1))
		var col: Color = top_col.lerp(bot_col, t)
		for x in range(w):
			# Outer edge broken so the strip doesn't read as a fence
			var outer_x: int = (w - 1) if is_east else 0
			if x == outer_x and _cell_hash(cell.x, cell.y * 7 + y, 3) % 5 == 0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			img.set_pixel(x, y, _px(col, 0.025))
	var px: float = (cell.x + 1) * ts if is_east else cell.x * ts - w
	var py: float = cell.y * ts - h * height_px
	_add_overlay(img, Vector2(px, py), h + 1)

func _draw_side_seam(cell: Vector2i, h: int, is_east: bool) -> void:
	# Subtle 1 px dark seam along the side cliff edge — broken pixels so it doesn't
	# look like a uniform line. Replaces the brown vertical strip; sides should not
	# compete with the south face for visual weight.
	var ts = tile_size
	var seam := Color(0.0, 0.0, 0.0, 0.06)
	var img := Image.create(1, ts, false, Image.FORMAT_RGBA8)
	for y in range(ts):
		# Skip about 1 in 4 pixels for natural break
		if randi() % 4 != 0:
			img.set_pixel(0, y, seam)
	var x: float = (cell.x + 1) * ts - 1 if is_east else cell.x * ts
	var y: float = cell.y * ts - h * height_px
	_add_overlay(img, Vector2(x, y), h + 1)

func _draw_raised_inner_seam(cell: Vector2i, h: int, dir: Vector2i) -> void:
	# Thin darker grass seam INSIDE the upper tile, just before the cliff lip.
	# Makes the top surface read as a ledge — the eye sees: grass → darker grass
	# → bright cliff lip → cliff face → contact shadow.
	var ts = tile_size
	var seam := Color(0.0, 0.0, 0.0, 0.18)
	var img: Image
	var pos: Vector2
	if dir == Vector2i(0, 1):
		img = Image.create(ts, 1, false, Image.FORMAT_RGBA8)
		for x in range(ts):
			img.set_pixel(x, 0, seam)
		pos = Vector2(cell.x * ts, (cell.y + 1) * ts - h * height_px - 2)
	elif dir == Vector2i(0, -1):
		img = Image.create(ts, 1, false, Image.FORMAT_RGBA8)
		for x in range(ts):
			img.set_pixel(x, 0, seam)
		pos = Vector2(cell.x * ts, cell.y * ts - h * height_px + 1)
	elif dir == Vector2i(1, 0):
		img = Image.create(1, ts, false, Image.FORMAT_RGBA8)
		for y in range(ts):
			img.set_pixel(0, y, seam)
		pos = Vector2((cell.x + 1) * ts - 2, cell.y * ts - h * height_px)
	else:
		img = Image.create(1, ts, false, Image.FORMAT_RGBA8)
		for y in range(ts):
			img.set_pixel(0, y, seam)
		pos = Vector2(cell.x * ts + 1, cell.y * ts - h * height_px)
	_add_overlay(img, pos, h + 1)

func _draw_top_rim(cell: Vector2i, h: int, dir: Vector2i) -> void:
	# Broken terrain-colored rim along the cliff edge — reads as grass overhanging
	# dirt, not a UI/lighting outline. Skip every ~5th pixel for natural erosion.
	var ts = tile_size
	var lip: Color = _cliff_lip().lightened(0.15)
	var rim := Color(lip.r, lip.g, lip.b, 0.22)
	var transp := Color(0, 0, 0, 0)
	var img: Image
	var pos: Vector2
	if dir == Vector2i(0, 1):
		img = Image.create(ts, 1, false, Image.FORMAT_RGBA8)
		for x in range(ts):
			img.set_pixel(x, 0, transp if randi() % 5 == 0 else rim)
		pos = Vector2(cell.x * ts, (cell.y + 1) * ts - h * height_px - 1)
	elif dir == Vector2i(0, -1):
		img = Image.create(ts, 1, false, Image.FORMAT_RGBA8)
		for x in range(ts):
			img.set_pixel(x, 0, transp if randi() % 5 == 0 else rim)
		pos = Vector2(cell.x * ts, cell.y * ts - h * height_px)
	elif dir == Vector2i(1, 0):
		img = Image.create(1, ts, false, Image.FORMAT_RGBA8)
		for y in range(ts):
			img.set_pixel(0, y, transp if randi() % 5 == 0 else rim)
		pos = Vector2((cell.x + 1) * ts - 1, cell.y * ts - h * height_px)
	else:
		img = Image.create(1, ts, false, Image.FORMAT_RGBA8)
		for y in range(ts):
			img.set_pixel(0, y, transp if randi() % 5 == 0 else rim)
		pos = Vector2(cell.x * ts, cell.y * ts - h * height_px)
	_add_overlay(img, pos, h + 1)

func _draw_ramp_side_rails(cell: Vector2i, h: int, ramp_dir: Vector2i) -> void:
	# Dark rails on the two perpendicular sides of the ramp. Reads as a carved
	# slope instead of "just a shaded grass tile".
	var ts = tile_size
	# Dirt-dark, not pure black, and at low alpha. Pure black rails read as burnt/blocked.
	var rail := Color(0.08, 0.05, 0.02, 0.18)
	var perps: Array[Vector2i] = []
	if ramp_dir.x != 0:
		perps = [Vector2i(0, -1), Vector2i(0, 1)]
	else:
		perps = [Vector2i(-1, 0), Vector2i(1, 0)]
	for p in perps:
		var img: Image
		var pos: Vector2
		if p == Vector2i(0, -1):
			img = Image.create(ts, 1, false, Image.FORMAT_RGBA8)
			for x in range(ts):
				img.set_pixel(x, 0, rail)
			pos = Vector2(cell.x * ts, cell.y * ts - h * height_px)
		elif p == Vector2i(0, 1):
			img = Image.create(ts, 1, false, Image.FORMAT_RGBA8)
			for x in range(ts):
				img.set_pixel(x, 0, rail)
			pos = Vector2(cell.x * ts, (cell.y + 1) * ts - h * height_px - 1)
		elif p == Vector2i(1, 0):
			img = Image.create(1, ts, false, Image.FORMAT_RGBA8)
			for y in range(ts):
				img.set_pixel(0, y, rail)
			pos = Vector2((cell.x + 1) * ts - 1, cell.y * ts - h * height_px)
		else:
			img = Image.create(1, ts, false, Image.FORMAT_RGBA8)
			for y in range(ts):
				img.set_pixel(0, y, rail)
			pos = Vector2(cell.x * ts, cell.y * ts - h * height_px)
		_add_overlay(img, pos, h + 2)

func _maybe_draw_pit_edge_dark(cell: Vector2i, h: int, diff_s: int, diff_n: int, diff_e: int, diff_w: int) -> void:
	# Pit-rim shadow: inward fade, width scales with depth (-1 = 1 px, -2 = 2 px,
	# -3 = 3 px). Darkest pixel at the cliff edge, fading toward the center so the
	# pit floor stays readable. Don't darken the center.
	var ts = tile_size
	var depth: int = clampi(-h, 1, 3)
	var rim_w: int = depth
	var a_max: float = clampf(0.10 + float(depth) * 0.06, 0.10, 0.28)
	# Horizontal strip helper — `rim_w` tall, fades from a_max at edge_y to 0 at far_y.
	var make_h = func(edge_at_top: bool) -> Image:
		var img := Image.create(ts, rim_w, false, Image.FORMAT_RGBA8)
		for y in range(rim_w):
			var t: float = float(y) / float(maxi(rim_w - 1, 1)) if rim_w > 1 else 0.0
			var a: float
			if edge_at_top:
				a = lerpf(a_max, 0.0, t)
			else:
				a = lerpf(0.0, a_max, t)
			for x in range(ts):
				img.set_pixel(x, y, Color(0, 0, 0, a))
		return img
	var make_v = func(edge_at_left: bool) -> Image:
		var img := Image.create(rim_w, ts, false, Image.FORMAT_RGBA8)
		for x in range(rim_w):
			var t: float = float(x) / float(maxi(rim_w - 1, 1)) if rim_w > 1 else 0.0
			var a: float
			if edge_at_left:
				a = lerpf(a_max, 0.0, t)
			else:
				a = lerpf(0.0, a_max, t)
			for y in range(ts):
				img.set_pixel(x, y, Color(0, 0, 0, a))
		return img
	# South edge (higher south neighbor) — rim sits on south edge of cell, fades inward (north).
	if diff_s < 0:
		_add_overlay(make_h.call(false), Vector2(cell.x * ts, (cell.y + 1) * ts - h * height_px - rim_w), h + 1)
	if diff_n < 0:
		_add_overlay(make_h.call(true), Vector2(cell.x * ts, cell.y * ts - h * height_px), h + 1)
	if diff_e < 0:
		_add_overlay(make_v.call(false), Vector2((cell.x + 1) * ts - rim_w, cell.y * ts - h * height_px), h + 1)
	if diff_w < 0:
		_add_overlay(make_v.call(true), Vector2(cell.x * ts, cell.y * ts - h * height_px), h + 1)

func _stamp_ramp_marks(img: Image, up_dir: Vector2i, ts: int) -> void:
	# Short dirt streaks across the ramp — reads as worn ground/stair tread instead
	# of a debug arrow. Density follows a checkerboard so it looks weathered, not stamped.
	var col: Color = _cliff_dirt_top().darkened(0.25)
	var a: float = 0.22
	if up_dir.y != 0:
		for y in [2, 4, 6]:
			for x in range(2, 6):
				if (x + y) % 2 == 0:
					img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	else:
		for x in [2, 4, 6]:
			for y in range(2, 6):
				if (x + y) % 2 == 0:
					img.set_pixel(x, y, Color(col.r, col.g, col.b, a))

func _stamp_chevron(img: Image, line_offset: int, up_dir: Vector2i, col: Color, ts: int) -> void:
	# Stamps a small chevron arrow (>) pointing in up_dir, centered along the perpendicular axis.
	var center := ts / 2
	for k in range(3):
		# chevron arm length 3; tip at line_offset toward up_dir
		var arm_a := Vector2i.ZERO
		var arm_b := Vector2i.ZERO
		if up_dir == Vector2i(0, -1):
			# pointing up (north): tip at top
			arm_a = Vector2i(center - k, line_offset + k)
			arm_b = Vector2i(center + k, line_offset + k)
		elif up_dir == Vector2i(0, 1):
			# pointing down (south): tip at bottom
			arm_a = Vector2i(center - k, ts - 1 - line_offset - k)
			arm_b = Vector2i(center + k, ts - 1 - line_offset - k)
		elif up_dir == Vector2i(1, 0):
			# pointing right (east)
			arm_a = Vector2i(ts - 1 - line_offset - k, center - k)
			arm_b = Vector2i(ts - 1 - line_offset - k, center + k)
		elif up_dir == Vector2i(-1, 0):
			# pointing left (west)
			arm_a = Vector2i(line_offset + k, center - k)
			arm_b = Vector2i(line_offset + k, center + k)
		for pt in [arm_a, arm_b]:
			if pt.x >= 0 and pt.x < ts and pt.y >= 0 and pt.y < ts:
				img.set_pixel(pt.x, pt.y, col)

func _draw_contact_shadow(cell: Vector2i, nh: int, diff: int) -> void:
	# 1-2 px contact shadow for diff=1 (just a soft contact). Bigger drops get
	# proportionally bigger shadow. Deterministic break pattern based on cell coord.
	var ts = tile_size
	var shadow_h: int = clampi(diff, 1, 2)
	if _is_dark_mood:
		shadow_h = clampi(shadow_h + 1, 1, 3)
	var img = Image.create(ts, shadow_h, false, Image.FORMAT_RGBA8)
	var a_top: float = 0.12 * _shadow_alpha_mult
	for y in range(shadow_h):
		var a = lerpf(a_top, 0.0, float(y) / float(maxi(shadow_h - 1, 1)))
		for x in range(ts):
			# Deterministic break so the shadow doesn't shimmer between rebuilds
			if _cell_hash(cell.x, cell.y, x * 19 + y) % 7 == 0:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, a * 0.55))
			else:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, a))
	_add_overlay(img, Vector2(cell.x * ts, cell.y * ts - nh * height_px), nh + 1)

func _add_overlay(img: Image, pos: Vector2, z: int) -> void:
	var spr = Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	spr.centered = false
	spr.position = pos
	spr.z_index = z
	add_child(spr)
	_overlays.append(spr)

func _px(base: Color, v: float) -> Color:
	return Color(
		clampf(base.r + randf_range(-v, v), 0, 1),
		clampf(base.g + randf_range(-v, v), 0, 1),
		clampf(base.b + randf_range(-v, v), 0, 1),
		base.a
	)
