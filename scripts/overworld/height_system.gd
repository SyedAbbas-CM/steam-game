class_name HeightSystem
extends Node2D

const PlayerQuery = preload("res://scripts/systems/player_query.gd")

## 2.5D terrain height system.
## Raised terrain is visually shifted upward. Inner lips mark edges.
## South cliffs show dirt face. East/west are thin. North is a crease.
## Supports GRASS (outdoor) and STONE (mine/dungeon) themes.

enum HeightTheme { GRASS, STONE }

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
	height_map[cell] = clampi(level, 0, 3)

func set_ramp(cell: Vector2i) -> void:
	ramp_cells[cell] = true

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

	for cell in height_map:
		var h = height_map[cell]
		if h == 0:
			continue
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
	if dir == Vector2i(0, 1):
		rect.size = Vector2(ts, 2)
		shape.position = Vector2(cell.x * ts + ts / 2, (cell.y + 1) * ts + 1 + y_off)
	elif dir == Vector2i(0, -1):
		rect.size = Vector2(ts, 2)
		shape.position = Vector2(cell.x * ts + ts / 2, cell.y * ts - 1 + y_off)
	elif dir == Vector2i(1, 0):
		rect.size = Vector2(2, ts)
		shape.position = Vector2((cell.x + 1) * ts + 1, cell.y * ts + ts / 2 + y_off)
	elif dir == Vector2i(-1, 0):
		rect.size = Vector2(2, ts)
		shape.position = Vector2(cell.x * ts - 1, cell.y * ts + ts / 2 + y_off)
	shape.shape = rect
	_wall_body.add_child(shape)
	_collision_shapes.append(shape)

# ── Visual layers ──

func _build_visual_layers() -> void:
	var tileset = _source_ground.tile_set
	for level in range(4):
		var layer = TileMapLayer.new()
		layer.name = "Height_%d" % level
		layer.tile_set = tileset
		layer.position.y = -level * height_px
		layer.z_index = level
		add_child(layer)
		_visual_layers.append(layer)

	for cell in height_map:
		var h = height_map[cell]
		var src = _source_ground.get_cell_source_id(cell)
		var atlas = _source_ground.get_cell_atlas_coords(cell)
		if src < 0:
			continue
		if is_ramp(cell):
			# Ramp: use the NORMAL tile on both layers — the gap in the cliff IS the ramp
			_visual_layers[h].set_cell(cell, src, atlas)
			if h + 1 < _visual_layers.size():
				_visual_layers[h + 1].set_cell(cell, src, atlas)
		else:
			_visual_layers[h].set_cell(cell, src, atlas)

# ── Overlays ──

func _build_overlays() -> void:
	for cell in height_map:
		var h = height_map[cell]
		if h == 0:
			continue

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
			_draw_inner_lip(cell, h, Vector2i(0, 1))
			_draw_south_face(cell, diff_s, h)
			_draw_contact_shadow(s_nb, get_height(s_nb), diff_s)

		if diff_e > 0 and not ramp_self and not is_ramp(e_nb):
			_draw_inner_lip(cell, h, Vector2i(1, 0))
			_draw_side_face(cell, diff_e, h, true)
			_draw_side_shadow(e_nb, get_height(e_nb), true)

		if diff_w > 0 and not ramp_self and not is_ramp(w_nb):
			_draw_inner_lip(cell, h, Vector2i(-1, 0))
			_draw_side_face(cell, diff_w, h, false)
			_draw_side_shadow(w_nb, get_height(w_nb), false)

		if diff_n > 0 and not ramp_self and not is_ramp(n_nb):
			_draw_inner_lip(cell, h, Vector2i(0, -1))
			_draw_north_crease(cell, h)

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

func _draw_south_face(cell: Vector2i, diff: int, h: int) -> void:
	var face_h = diff * cliff_px
	if face_h < 1:
		return
	var ts = tile_size
	var img = Image.create(ts, face_h, false, Image.FORMAT_RGBA8)
	var nh = h - diff

	if nh == 0 and diff == 1:
		# Soft hill
		for y in range(face_h):
			for x in range(ts):
				if y < maxi(face_h / 3, 1):
					img.set_pixel(x, y, _px(_soft_hill_rim(), 0.02))
				else:
					var a = lerpf(0.25, 0.0, float(y) / float(face_h))
					img.set_pixel(x, y, Color(_soft_hill_shadow().r, _soft_hill_shadow().g, _soft_hill_shadow().b, a))
	else:
		# Cliff: lip + rock/dirt
		var lip_h = clampi(diff, 1, 2)
		var dirt_h = face_h - lip_h
		for y in range(face_h):
			for x in range(ts):
				if y < lip_h:
					img.set_pixel(x, y, _px(_cliff_lip(), 0.02))
				else:
					var t = float(y - lip_h) / float(maxi(dirt_h, 1))
					var base = _cliff_dirt_top().lerp(_cliff_dirt_bot(), t)
					if randi() % 10 == 0:
						base = _cliff_dirt_speckle()
					img.set_pixel(x, y, _px(base, 0.03))

	_add_overlay(img, Vector2(cell.x * ts, (cell.y + 1) * ts - h * height_px), h)

func _draw_side_face(cell: Vector2i, diff: int, h: int, is_east: bool) -> void:
	# Side faces: 2-3px wide, extends full tile + cliff height, vertical gradient
	var face_w = 2 if diff == 1 else 3
	var face_h = diff * cliff_px
	var ts = tile_size
	var img = Image.create(face_w, ts + face_h, false, Image.FORMAT_RGBA8)
	var top_col = _side_face_east() if is_east else _side_face_west()
	var bot_col = top_col.darkened(0.4)

	for y in range(ts + face_h):
		var t = float(y) / float(ts + face_h)
		var col = top_col.lerp(bot_col, t)
		for x in range(face_w):
			# Inner pixel slightly lighter for depth
			var c = col.lightened(0.08) if x == 0 and is_east else col
			c = col.lightened(0.08) if x == face_w - 1 and not is_east else c
			img.set_pixel(x, y, _px(c, 0.025))

	var px: float
	if is_east:
		px = (cell.x + 1) * ts
	else:
		px = cell.x * ts - face_w
	_add_overlay(img, Vector2(px, cell.y * ts - h * height_px), h)

func _draw_north_crease(cell: Vector2i, h: int) -> void:
	# North edge: gradient shadow fading downward, scales with cliff_px
	var ts = tile_size
	var crease_h = clampi(cliff_px, 3, 8)
	var img = Image.create(ts, crease_h, false, Image.FORMAT_RGBA8)
	var a_top: float = 0.30 * _shadow_alpha_mult
	for y in range(crease_h):
		var a = lerpf(a_top, 0.0, float(y) / float(crease_h))
		for x in range(ts):
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, a))
	_add_overlay(img, Vector2(cell.x * ts, cell.y * ts - h * height_px), h)

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
	# Determine ramp direction: find which adjacent cell is higher
	var ts = tile_size
	var up_dir = Vector2i.ZERO
	for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if get_height(cell + dir) > h:
			up_dir = dir
			break
	if up_dir == Vector2i.ZERO:
		return

	# Smooth gradient: darken the low side, transparent on the high side
	# This makes the tile look like it transitions from shadow (low) to lit (high)
	var img = Image.create(ts, ts, false, Image.FORMAT_RGBA8)
	for y in range(ts):
		for x in range(ts):
			var t: float = 0.0
			if up_dir == Vector2i(0, -1):    # slope goes north (up)
				t = float(ts - 1 - y) / float(ts)  # dark at south, light at north
			elif up_dir == Vector2i(0, 1):   # slope goes south (up)
				t = float(y) / float(ts)
			elif up_dir == Vector2i(1, 0):   # slope goes east (up)
				t = float(ts - 1 - x) / float(ts)
			elif up_dir == Vector2i(-1, 0):  # slope goes west (up)
				t = float(x) / float(ts)
			var a = lerpf(0.0, 0.20 * _shadow_alpha_mult, t)
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, a))

	_add_overlay(img, Vector2(cell.x * ts, cell.y * ts - h * height_px), h + 1)

func _draw_contact_shadow(cell: Vector2i, nh: int, diff: int) -> void:
	# In dark moods the shadow extends further onto lower terrain — cliff casts a real ground shadow
	var base_h = clampi(diff * 2 + 1, 3, 6)
	var shadow_h = base_h
	if _is_dark_mood:
		shadow_h = clampi(int(base_h * 1.6) + diff, base_h, tile_size)
	var ts = tile_size
	var img = Image.create(ts, shadow_h, false, Image.FORMAT_RGBA8)
	var a_top: float = 0.30 * _shadow_alpha_mult
	for y in range(shadow_h):
		for x in range(ts):
			var a = lerpf(a_top, 0.0, float(y) / float(shadow_h))
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
