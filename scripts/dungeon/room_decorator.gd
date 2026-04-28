class_name RoomDecorator
extends RefCounted

# Divides a room into 2-4 rectangular zones and assigns a themed blueprint to each.
# Used for SUPER_ELITE, ELITE, and DECORATED combat rooms.
# dm param is DungeonManager (untyped to avoid circular dependency).
# Tile constants come from DecoTiles (no circular dependency).

static var _used_combos_this_floor: Dictionary = {}  # combo_key -> true

static func reset_floor_tracking() -> void:
	_used_combos_this_floor.clear()

static func decorate_room(dm, origin: Vector2i, mask: Array,
		w: int, h: int, room_data: RoomData, placed: Dictionary) -> void:
	var zones = _divide_into_zones(mask, w, h)
	var blueprints = _assign_blueprints(zones.size(), room_data)

	# Dedup: generate combo key and reroll if exact same combo already used this floor
	var combo_key = _combo_key(blueprints)
	var reroll_attempts = 0
	while _used_combos_this_floor.has(combo_key) and reroll_attempts < 5:
		blueprints = _assign_blueprints(zones.size(), room_data)
		combo_key = _combo_key(blueprints)
		reroll_attempts += 1
	_used_combos_this_floor[combo_key] = true

	# Density multiplier: more enemies = denser decoration
	var enemy_count = room_data.enemy_count
	var density = 1.0
	if enemy_count >= 6:
		density = 1.5
	if enemy_count >= 10:
		density = 2.0
	if room_data.type == RoomData.RoomType.SUPER_ELITE:
		density = maxf(density, 2.0)

	# Paint each zone with its assigned blueprint
	for i in range(zones.size()):
		if i < blueprints.size():
			var zone = zones[i]
			RoomBlueprints.paint_blueprint(blueprints[i], dm, origin, mask,
				zone.x, zone.y, zone.w, zone.h, placed)

	# Extra blueprints for high-density rooms: paint additional overlapping zones
	if density >= 1.5:
		var extra_passes = 1 if density < 2.0 else 2
		for _p in range(extra_passes):
			# Pick a random zone and paint a second blueprint into it
			var zi = randi() % zones.size()
			var zone = zones[zi]
			var extra_bp = randi() % RoomBlueprints.BLUEPRINT_COUNT
			# Shrink zone slightly to avoid overwriting edges
			var sub_x = zone.x + randi_range(0, maxi(0, zone.w / 4))
			var sub_y = zone.y + randi_range(0, maxi(0, zone.h / 4))
			var sub_w = maxi(6, zone.w * 3 / 4)
			var sub_h = maxi(6, zone.h * 3 / 4)
			RoomBlueprints.paint_blueprint(extra_bp, dm, origin, mask,
				sub_x, sub_y, sub_w, sub_h, placed)

	# Braziers at zone boundaries (bare stone gaps)
	_paint_boundary_braziers(dm, origin, mask, w, h, zones, placed)

	# Wall decorations along room perimeter
	_paint_wall_decorations(dm, origin, mask, w, h, placed, density)

	# Floor candles scatter — just a few accent lights
	_paint_scatter_candles(dm, origin, mask, w, h, placed, randi_range(1, 3))

	# Misc scatter (pots, bones) in gaps — more with density
	_paint_gap_scatter(dm, origin, mask, w, h, placed, density)

# --- Zone Division ---

static func _divide_into_zones(mask: Array, w: int, h: int) -> Array:
	var min_x = w
	var max_x = 0
	var min_y = h
	var max_y = 0
	for y in range(h):
		for x in range(w):
			if mask[y][x]:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)

	var fw = max_x - min_x + 1
	var fh = max_y - min_y + 1
	var ix = min_x + 2
	var iy = min_y + 2
	var iw = fw - 4
	var ih = fh - 4

	if iw < 8 or ih < 8:
		return [{"x": ix, "y": iy, "w": iw, "h": ih}]

	var zone_count: int
	if iw < 16 or ih < 12:
		zone_count = 2
	elif iw > 24 and ih > 20:
		zone_count = 4
	else:
		zone_count = 3

	var gap = 2

	match zone_count:
		2: return _split_two(ix, iy, iw, ih, gap)
		3: return _split_three(ix, iy, iw, ih, gap)
		4: return _split_four(ix, iy, iw, ih, gap)
		_: return [{"x": ix, "y": iy, "w": iw, "h": ih}]

static func _split_two(ix: int, iy: int, iw: int, ih: int, gap: int) -> Array:
	if iw >= ih:
		var half = (iw - gap) / 2
		return [
			{"x": ix, "y": iy, "w": half, "h": ih},
			{"x": ix + half + gap, "y": iy, "w": iw - half - gap, "h": ih},
		]
	else:
		var half = (ih - gap) / 2
		return [
			{"x": ix, "y": iy, "w": iw, "h": half},
			{"x": ix, "y": iy + half + gap, "w": iw, "h": ih - half - gap},
		]

static func _split_three(ix: int, iy: int, iw: int, ih: int, gap: int) -> Array:
	if randf() < 0.5:
		var left_w = (iw * 2 / 3) - gap
		var right_x = ix + left_w + gap
		var right_w = iw - left_w - gap
		var top_h = (ih - gap) / 2
		return [
			{"x": ix, "y": iy, "w": left_w, "h": ih},
			{"x": right_x, "y": iy, "w": right_w, "h": top_h},
			{"x": right_x, "y": iy + top_h + gap, "w": right_w, "h": ih - top_h - gap},
		]
	else:
		var top_h = (ih * 2 / 3) - gap
		var left_w = (iw - gap) / 2
		var bot_y = iy + top_h + gap
		var bot_h = ih - top_h - gap
		return [
			{"x": ix, "y": iy, "w": iw, "h": top_h},
			{"x": ix, "y": bot_y, "w": left_w, "h": bot_h},
			{"x": ix + left_w + gap, "y": bot_y, "w": iw - left_w - gap, "h": bot_h},
		]

static func _split_four(ix: int, iy: int, iw: int, ih: int, gap: int) -> Array:
	var half_w = (iw - gap) / 2
	var half_h = (ih - gap) / 2
	var right_x = ix + half_w + gap
	var right_w = iw - half_w - gap
	var bot_y = iy + half_h + gap
	var bot_h = ih - half_h - gap
	return [
		{"x": ix, "y": iy, "w": half_w, "h": half_h},
		{"x": right_x, "y": iy, "w": right_w, "h": half_h},
		{"x": ix, "y": bot_y, "w": half_w, "h": bot_h},
		{"x": right_x, "y": bot_y, "w": right_w, "h": bot_h},
	]

# --- Blueprint Assignment ---

static func _assign_blueprints(zone_count: int, room_data: RoomData) -> Array:
	var all_bps: Array = []
	for i in range(RoomBlueprints.BLUEPRINT_COUNT):
		all_bps.append(i)

	var result: Array = []
	var used: Dictionary = {}

	if room_data.type == RoomData.RoomType.SUPER_ELITE:
		result.append(RoomBlueprints.Blueprint.THRONE_ROOM)
		used[RoomBlueprints.Blueprint.THRONE_ROOM] = true

	while result.size() < zone_count:
		var available: Array = []
		for bp in all_bps:
			if not used.has(bp) or (zone_count >= 4 and available.size() == 0):
				available.append(bp)
		if available.size() == 0:
			available = all_bps.duplicate()
		var pick = available[randi() % available.size()]
		result.append(pick)
		used[pick] = true

	return result

static func _combo_key(blueprints: Array) -> String:
	var sorted = blueprints.duplicate()
	sorted.sort()
	var parts: Array = []
	for bp in sorted:
		parts.append(str(bp))
	return ",".join(parts)

# --- Boundary & Gap Decoration ---

static func _paint_boundary_braziers(dm, origin: Vector2i, mask: Array,
		w: int, h: int, zones: Array, placed: Dictionary) -> void:
	if zones.size() < 2:
		return
	for i in range(zones.size()):
		var z = zones[i]
		var corners = [
			Vector2i(z.x, z.y),
			Vector2i(z.x + z.w - 1, z.y),
			Vector2i(z.x, z.y + z.h - 1),
			Vector2i(z.x + z.w - 1, z.y + z.h - 1),
		]
		for c in corners:
			if randf() < 0.3:
				RoomBlueprints._place_brazier(dm, origin, mask, w, h, c.x, c.y, placed)

static func _paint_scatter_candles(dm, origin: Vector2i, mask: Array,
		w: int, h: int, placed: Dictionary, count: int) -> void:
	for _i in range(count):
		for _attempt in range(15):
			var x = randi_range(1, w - 2)
			var y = randi_range(1, h - 2)
			if x >= 0 and x < w and y >= 0 and y < h and mask[y][x] and not placed.has(Vector2i(x, y)):
				var abs_pos = origin + Vector2i(x, y)
				if dm.deco_layer.get_cell_source_id(abs_pos) == -1:
					dm._register_animated_tile(abs_pos, DecoTiles.DECO_FLOOR_CANDLE_A, DecoTiles.DECO_FLOOR_CANDLE_B)
					placed[Vector2i(x, y)] = true
					break

static func _paint_wall_decorations(dm, origin: Vector2i, mask: Array,
		w: int, h: int, placed: Dictionary, density: float) -> void:
	# Place decorations along walls (tiles adjacent to non-floor)
	var wall_decos: Array = [
		DecoTiles.DECO_ARMOR_DISPLAY, DecoTiles.DECO_WEAPON_DISPLAY_WALL,
		DecoTiles.DECO_BOOKSHELF, DecoTiles.DECO_BOOKSHELF_LEFT,
		DecoTiles.DECO_POTION_CABINET, DecoTiles.DECO_CANDLE_STAND,
		DecoTiles.DECO_WEAPON_RACK, DecoTiles.DECO_WEAPON_RACK_LEFT,
	]
	var spacing = 4 if density < 1.5 else 3
	# Scan north and south walls
	for x in range(3, w - 3, spacing):
		for wall_y in [1, 2]:  # top rows near walls
			if wall_y < h and mask[wall_y][x] and dm._has_wall_neighbor(mask, x, wall_y, w, h):
				if not placed.has(Vector2i(x, wall_y)):
					if randf() < 0.4 * density:
						RoomBlueprints._place(dm, origin, mask, w, h, x, wall_y,
							wall_decos[randi() % wall_decos.size()], placed)
		var bot_y = h - 2
		if bot_y > 0 and mask[bot_y][x] and dm._has_wall_neighbor(mask, x, bot_y, w, h):
			if not placed.has(Vector2i(x, bot_y)):
				if randf() < 0.3 * density:
					RoomBlueprints._place(dm, origin, mask, w, h, x, bot_y,
						wall_decos[randi() % wall_decos.size()], placed)

static func _paint_gap_scatter(dm, origin: Vector2i, mask: Array,
		w: int, h: int, placed: Dictionary, density: float = 1.0) -> void:
	var scatter_tiles: Array = []
	for t in DecoTiles.DECO_POTS:
		scatter_tiles.append(t)
	scatter_tiles.append(Vector2i(0, 4))  # bones
	scatter_tiles.append(Vector2i(1, 4))  # cobweb
	scatter_tiles.append(DecoTiles.DECO_IRON_GRATE)
	scatter_tiles.append(DecoTiles.DECO_BUCKET)

	var count = randi_range(3, 5 + int(density * 4))
	for _i in range(count):
		for _attempt in range(15):
			var x = randi_range(2, w - 3)
			var y = randi_range(2, h - 3)
			if mask[y][x] and not placed.has(Vector2i(x, y)):
				var abs_pos = origin + Vector2i(x, y)
				if dm.deco_layer.get_cell_source_id(abs_pos) == -1:
					dm.deco_layer.set_cell(abs_pos, 1, scatter_tiles[randi() % scatter_tiles.size()])
					placed[Vector2i(x, y)] = true
					break
