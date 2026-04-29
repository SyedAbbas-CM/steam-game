class_name CorridorGenerator
extends RefCounted

enum CorridorType { STRAIGHT, ZIGZAG, L_BEND, WINDING, WIDE_CHAMBER, ALCOVE }
enum LengthClass { SHORT, LONG }

const BUFFER_LEN = 4  # Straight tiles from each room exit before any bends

# Generate corridor tile data between two exit points.
# half_w: 1 = 3 tiles wide (default), 2 = 5 tiles wide (elite)
static func generate_corridor(
	from_exit: Vector2i, to_exit: Vector2i,
	direction: String, half_w: int, floor_number: int
) -> Dictionary:
	var length_class = LengthClass.SHORT if randf() < 0.5 else LengthClass.LONG
	var corridor_type = _roll_corridor_type(floor_number, length_class)

	# Calculate buffer endpoints — straight segments from each exit
	var buf_from: Vector2i
	var buf_to: Vector2i
	if direction == "east":
		buf_from = Vector2i(from_exit.x + BUFFER_LEN, from_exit.y)
		buf_to = Vector2i(to_exit.x - BUFFER_LEN, to_exit.y)
	else:  # south
		buf_from = Vector2i(from_exit.x, from_exit.y + BUFFER_LEN)
		buf_to = Vector2i(to_exit.x, to_exit.y - BUFFER_LEN)

	var result = _empty_result()

	# Paint buffer segments (straight from each room exit)
	var seg_entry = _segment_tiles(from_exit, buf_from, half_w)
	_merge_segment(result, seg_entry)
	var seg_exit = _segment_tiles(buf_to, to_exit, half_w)
	_merge_segment(result, seg_exit)

	# Check if there's enough gap for a shaped corridor between buffers
	var gap: int
	if direction == "east":
		gap = buf_to.x - buf_from.x
	else:
		gap = buf_to.y - buf_from.y

	if gap < 4:
		# Too short for shapes — just connect straight
		var seg_mid = _segment_tiles(buf_from, buf_to, half_w)
		_merge_segment(result, seg_mid)
		corridor_type = CorridorType.STRAIGHT
	else:
		# Generate the shaped middle section between buffer endpoints
		var mid_result: Dictionary
		match corridor_type:
			CorridorType.STRAIGHT:
				mid_result = _gen_straight(buf_from, buf_to, direction, half_w)
			CorridorType.ZIGZAG:
				mid_result = _gen_zigzag(buf_from, buf_to, direction, half_w, length_class)
			CorridorType.L_BEND:
				mid_result = _gen_l_bend(buf_from, buf_to, direction, half_w, length_class)
			CorridorType.WINDING:
				mid_result = _gen_winding(buf_from, buf_to, direction, half_w, length_class)
			CorridorType.WIDE_CHAMBER:
				mid_result = _gen_wide_chamber(buf_from, buf_to, direction, half_w, length_class)
			CorridorType.ALCOVE:
				mid_result = _gen_alcove(buf_from, buf_to, direction, half_w, length_class)
			_:
				mid_result = _gen_straight(buf_from, buf_to, direction, half_w)

		_merge_segment(result, {"floor": mid_result["floor_tiles"], "wall": mid_result["wall_tiles"]})
		for t in mid_result["alcove_tiles"]:
			result["alcove_tiles"].append(t)
		for tp in mid_result["trap_positions"]:
			result["trap_positions"].append(tp)

	# Add pillar positions along the corridor center every 5-7 tiles
	result["pillar_tiles"] = _compute_pillar_positions(from_exit, to_exit, direction, half_w)

	result["type"] = corridor_type
	result["direction"] = direction
	result["length_class"] = length_class
	result["midpoint"] = _midpoint(from_exit, to_exit)
	# Add traps along buffer segments too
	_add_trap_pos(result, _midpoint(from_exit, buf_from), direction)
	_add_trap_pos(result, _midpoint(buf_to, to_exit), direction)
	var lc_name = "LONG" if length_class == LengthClass.LONG else "SHORT"
	print("  Corridor %s: %s %s w=%d (%d floor tiles)" % [direction, lc_name, CorridorType.keys()[corridor_type], half_w * 2 + 1, result["floor_tiles"].size()])
	return result

static func _roll_corridor_type(floor_number: int, length_class: LengthClass) -> CorridorType:
	var roll = randf()
	if length_class == LengthClass.SHORT:
		if roll < 0.40:
			return CorridorType.STRAIGHT
		elif roll < 0.65:
			return CorridorType.L_BEND
		elif roll < 0.80:
			return CorridorType.ZIGZAG
		elif roll < 0.90:
			return CorridorType.WINDING
		else:
			return CorridorType.WIDE_CHAMBER
	else:
		if floor_number <= 1:
			if roll < 0.30:
				return CorridorType.ZIGZAG
			elif roll < 0.55:
				return CorridorType.WINDING
			elif roll < 0.80:
				return CorridorType.L_BEND
			else:
				return CorridorType.WIDE_CHAMBER
		else:
			if roll < 0.20:
				return CorridorType.ZIGZAG
			elif roll < 0.40:
				return CorridorType.WINDING
			elif roll < 0.55:
				return CorridorType.ALCOVE
			elif roll < 0.70:
				return CorridorType.WIDE_CHAMBER
			elif roll < 0.85:
				return CorridorType.L_BEND
			else:
				return CorridorType.STRAIGHT

# --- Shared helpers ---

static func _empty_result() -> Dictionary:
	return {
		"floor_tiles": [] as Array[Vector2i],
		"wall_tiles": [] as Array[Vector2i],
		"alcove_tiles": [] as Array[Vector2i],
		"trap_positions": [] as Array[Dictionary],
		"pillar_tiles": [] as Array[Vector2i],
		"midpoint": Vector2i.ZERO,
	}

# Paint a straight segment from A to B with the given half-width.
# Auto-detects primary axis from displacement.
static func _segment_tiles(from_pt: Vector2i, to_pt: Vector2i, half_w: int) -> Dictionary:
	var floor_tiles: Array[Vector2i] = []
	var wall_tiles: Array[Vector2i] = []
	var wall_offset = half_w + 1

	var abs_dx = absi(to_pt.x - from_pt.x)
	var abs_dy = absi(to_pt.y - from_pt.y)
	var use_horizontal = abs_dx >= abs_dy

	if use_horizontal:
		var start_x = mini(from_pt.x, to_pt.x)
		var end_x = maxi(from_pt.x, to_pt.x)
		var length = end_x - start_x
		if length == 0:
			for dy in range(-half_w, half_w + 1):
				floor_tiles.append(Vector2i(from_pt.x, from_pt.y + dy))
			wall_tiles.append(Vector2i(from_pt.x, from_pt.y - wall_offset))
			wall_tiles.append(Vector2i(from_pt.x, from_pt.y + wall_offset))
		else:
			for x in range(start_x, end_x + 1):
				var t = float(x - start_x) / float(length)
				var mid_y = int(lerp(float(from_pt.y), float(to_pt.y), t))
				for dy in range(-half_w, half_w + 1):
					floor_tiles.append(Vector2i(x, mid_y + dy))
				wall_tiles.append(Vector2i(x, mid_y - wall_offset))
				wall_tiles.append(Vector2i(x, mid_y + wall_offset))
	else:
		var start_y = mini(from_pt.y, to_pt.y)
		var end_y = maxi(from_pt.y, to_pt.y)
		var length = end_y - start_y
		if length == 0:
			for dx in range(-half_w, half_w + 1):
				floor_tiles.append(Vector2i(from_pt.x + dx, from_pt.y))
			wall_tiles.append(Vector2i(from_pt.x - wall_offset, from_pt.y))
			wall_tiles.append(Vector2i(from_pt.x + wall_offset, from_pt.y))
		else:
			for y in range(start_y, end_y + 1):
				var t = float(y - start_y) / float(length)
				var mid_x = int(lerp(float(from_pt.x), float(to_pt.x), t))
				for dx in range(-half_w, half_w + 1):
					floor_tiles.append(Vector2i(mid_x + dx, y))
				wall_tiles.append(Vector2i(mid_x - wall_offset, y))
				wall_tiles.append(Vector2i(mid_x + wall_offset, y))

	return { "floor": floor_tiles, "wall": wall_tiles }

static func _merge_segment(result: Dictionary, seg: Dictionary) -> void:
	for t in seg["floor"]:
		result["floor_tiles"].append(t)
	for t in seg["wall"]:
		result["wall_tiles"].append(t)

static func _midpoint(a: Vector2i, b: Vector2i) -> Vector2i:
	return Vector2i((a.x + b.x) / 2, (a.y + b.y) / 2)

static func _add_trap_pos(result: Dictionary, pos: Vector2i, direction: String, tile_size: int = 8) -> void:
	result["trap_positions"].append({
		"position": Vector2(pos.x * tile_size + 4, pos.y * tile_size + 4),
		"direction": direction,
	})

# Perpendicular offset: for east corridors offset Y, for south offset X
static func _perp_offset(pt: Vector2i, direction: String, amount: int) -> Vector2i:
	if direction == "east":
		return Vector2i(pt.x, pt.y + amount)
	else:
		return Vector2i(pt.x + amount, pt.y)

# Compute pillar positions along corridor center, every 5-7 tiles
static func _compute_pillar_positions(from_exit: Vector2i, to_exit: Vector2i, direction: String, half_w: int) -> Array[Vector2i]:
	var pillars: Array[Vector2i] = []
	var spacing = randi_range(5, 7)
	var total: int
	if direction == "east":
		total = absi(to_exit.x - from_exit.x)
	else:
		total = absi(to_exit.y - from_exit.y)

	if total < 12:
		return pillars  # Too short for pillars

	# Place pillars along both walls at regular intervals
	var num_pillars = total / spacing
	for i in range(1, num_pillars):
		var t = float(i) / float(num_pillars)
		var pos = Vector2i(
			int(lerp(float(from_exit.x), float(to_exit.x), t)),
			int(lerp(float(from_exit.y), float(to_exit.y), t))
		)
		# Place on both sides of the corridor, right at the wall edge
		if direction == "east":
			pillars.append(Vector2i(pos.x, pos.y - half_w))
			pillars.append(Vector2i(pos.x, pos.y + half_w))
		else:
			pillars.append(Vector2i(pos.x - half_w, pos.y))
			pillars.append(Vector2i(pos.x + half_w, pos.y))
	return pillars

# --- Corridor Type Generators ---
# These operate on the INNER section only (between buffer endpoints).
# They should NOT touch the area near room exits.

static func _gen_straight(from_pt: Vector2i, to_pt: Vector2i, direction: String, half_w: int) -> Dictionary:
	var result = _empty_result()
	var seg = _segment_tiles(from_pt, to_pt, half_w)
	_merge_segment(result, seg)
	result["midpoint"] = _midpoint(from_pt, to_pt)
	_add_trap_pos(result, result["midpoint"], direction)
	_add_trap_pos(result, _midpoint(from_pt, result["midpoint"]), direction)
	_add_trap_pos(result, _midpoint(result["midpoint"], to_pt), direction)
	return result

static func _gen_zigzag(from_pt: Vector2i, to_pt: Vector2i, direction: String, half_w: int, length_class: int) -> Dictionary:
	var result = _empty_result()

	var num_bends = 1 if length_class == LengthClass.SHORT else randi_range(2, 3)
	var max_offset = 4 if length_class == LengthClass.SHORT else randi_range(5, 8)

	var points: Array[Vector2i] = [from_pt]
	var sign_val = 1 if randf() > 0.5 else -1

	for b in range(num_bends):
		var t = float(b + 1) / float(num_bends + 1)
		var base = Vector2i(
			int(lerp(float(from_pt.x), float(to_pt.x), t)),
			int(lerp(float(from_pt.y), float(to_pt.y), t))
		)
		var offset = randi_range(maxi(3, max_offset / 2), max_offset) * sign_val
		points.append(_perp_offset(base, direction, offset))
		sign_val *= -1

	points.append(to_pt)

	for i in range(points.size() - 1):
		var seg = _segment_tiles(points[i], points[i + 1], half_w)
		_merge_segment(result, seg)

	result["midpoint"] = points[points.size() / 2]
	for i in range(1, points.size() - 1):
		_add_trap_pos(result, points[i], direction)
	return result

static func _gen_l_bend(from_pt: Vector2i, to_pt: Vector2i, direction: String, half_w: int, length_class: int) -> Dictionary:
	var result = _empty_result()

	if length_class == LengthClass.SHORT:
		# Simple 90-degree turn at a random point
		var horizontal_first = randf() > 0.5
		var corner: Vector2i
		if horizontal_first:
			corner = Vector2i(to_pt.x, from_pt.y)
		else:
			corner = Vector2i(from_pt.x, to_pt.y)
		var seg1 = _segment_tiles(from_pt, corner, half_w)
		var seg2 = _segment_tiles(corner, to_pt, half_w)
		_merge_segment(result, seg1)
		_merge_segment(result, seg2)
		result["midpoint"] = corner
		_add_trap_pos(result, corner, direction)
		_add_trap_pos(result, _midpoint(from_pt, corner), direction)
	else:
		# LONG L-bend: detour perpendicular then come back (U-shape)
		var detour_dist = randi_range(5, 10)
		var detour_sign = 1 if randf() > 0.5 else -1
		var detour_amount = detour_dist * detour_sign

		var waypoint1 = _perp_offset(from_pt, direction, detour_amount)
		var waypoint2: Vector2i
		if direction == "east":
			waypoint2 = Vector2i(to_pt.x, waypoint1.y)
		else:
			waypoint2 = Vector2i(waypoint1.x, to_pt.y)

		var seg1 = _segment_tiles(from_pt, waypoint1, half_w)
		_merge_segment(result, seg1)
		var seg2 = _segment_tiles(waypoint1, waypoint2, half_w)
		_merge_segment(result, seg2)
		var seg3 = _segment_tiles(waypoint2, to_pt, half_w)
		_merge_segment(result, seg3)

		result["midpoint"] = _midpoint(waypoint1, waypoint2)
		_add_trap_pos(result, waypoint1, direction)
		_add_trap_pos(result, result["midpoint"], direction)
		_add_trap_pos(result, waypoint2, direction)

	return result

static func _gen_winding(from_pt: Vector2i, to_pt: Vector2i, direction: String, half_w: int, length_class: int) -> Dictionary:
	var result = _empty_result()

	var num_points: int
	var max_wobble: int
	if length_class == LengthClass.SHORT:
		num_points = randi_range(2, 3)
		max_wobble = randi_range(2, 4)
	else:
		num_points = randi_range(4, 6)
		max_wobble = randi_range(4, 7)

	var points: Array[Vector2i] = [from_pt]
	var prev_offset = 0

	for i in range(1, num_points + 1):
		var t = float(i) / float(num_points + 1)
		var base = Vector2i(
			int(lerp(float(from_pt.x), float(to_pt.x), t)),
			int(lerp(float(from_pt.y), float(to_pt.y), t))
		)
		var offset = randi_range(2, max_wobble)
		if prev_offset > 0:
			offset = -offset
		elif prev_offset < 0:
			offset = absi(offset)
		else:
			offset = offset * (1 if randf() > 0.5 else -1)
		prev_offset = offset
		points.append(_perp_offset(base, direction, offset))

	points.append(to_pt)

	for i in range(points.size() - 1):
		var seg = _segment_tiles(points[i], points[i + 1], half_w)
		_merge_segment(result, seg)

	result["midpoint"] = points[points.size() / 2]
	for i in range(1, points.size() - 1):
		_add_trap_pos(result, points[i], direction)
	return result

static func _gen_wide_chamber(from_pt: Vector2i, to_pt: Vector2i, direction: String, half_w: int, length_class: int) -> Dictionary:
	var result = _empty_result()

	# Corridor leading to chamber
	if length_class == LengthClass.LONG:
		var winding = _gen_winding(from_pt, to_pt, direction, half_w, LengthClass.SHORT)
		_merge_segment(result, {"floor": winding["floor_tiles"], "wall": winding["wall_tiles"]})
		result["midpoint"] = winding["midpoint"]
	else:
		var seg = _segment_tiles(from_pt, to_pt, half_w)
		_merge_segment(result, seg)
		result["midpoint"] = _midpoint(from_pt, to_pt)

	# Chamber at midpoint — SHORT=5x5, LONG=7x7
	var mid = result["midpoint"]
	var chamber_hw = 2 if length_class == LengthClass.SHORT else 3

	for cy in range(-chamber_hw, chamber_hw + 1):
		for cx in range(-chamber_hw, chamber_hw + 1):
			result["floor_tiles"].append(Vector2i(mid.x + cx, mid.y + cy))
	for cx in range(-chamber_hw - 1, chamber_hw + 2):
		result["wall_tiles"].append(Vector2i(mid.x + cx, mid.y - chamber_hw - 1))
		result["wall_tiles"].append(Vector2i(mid.x + cx, mid.y + chamber_hw + 1))
	for cy in range(-chamber_hw, chamber_hw + 1):
		result["wall_tiles"].append(Vector2i(mid.x - chamber_hw - 1, mid.y + cy))
		result["wall_tiles"].append(Vector2i(mid.x + chamber_hw + 1, mid.y + cy))

	_add_trap_pos(result, _midpoint(from_pt, mid), direction)
	_add_trap_pos(result, mid, direction)
	_add_trap_pos(result, _midpoint(mid, to_pt), direction)
	return result

static func _gen_alcove(from_pt: Vector2i, to_pt: Vector2i, direction: String, half_w: int, length_class: int) -> Dictionary:
	var result = _empty_result()

	# Base corridor
	if length_class == LengthClass.LONG:
		var zigzag = _gen_zigzag(from_pt, to_pt, direction, half_w, LengthClass.SHORT)
		_merge_segment(result, {"floor": zigzag["floor_tiles"], "wall": zigzag["wall_tiles"]})
		result["midpoint"] = zigzag["midpoint"]
	else:
		var seg = _segment_tiles(from_pt, to_pt, half_w)
		_merge_segment(result, seg)
		result["midpoint"] = _midpoint(from_pt, to_pt)

	var num_alcoves = randi_range(1, 2) if length_class == LengthClass.SHORT else randi_range(2, 3)
	var min_depth = 3 if length_class == LengthClass.SHORT else 4
	var max_depth = 5 if length_class == LengthClass.SHORT else 7

	for a in range(num_alcoves):
		var t = randf_range(0.2, 0.8)
		var alcove_root = Vector2i(
			int(lerp(float(from_pt.x), float(to_pt.x), t)),
			int(lerp(float(from_pt.y), float(to_pt.y), t))
		)
		var depth = randi_range(min_depth, max_depth)
		var alcove_side = 1 if randf() > 0.5 else -1
		var alcove_hw = 1  # Alcoves always 3 tiles wide

		for d in range(1, depth + 1):
			for w in range(-alcove_hw, alcove_hw + 1):
				var tile: Vector2i
				if direction == "east":
					tile = Vector2i(alcove_root.x + w, alcove_root.y + alcove_side * (half_w + 1 + d))
				else:
					tile = Vector2i(alcove_root.x + alcove_side * (half_w + 1 + d), alcove_root.y + w)
				result["alcove_tiles"].append(tile)

		# End wall
		var end_d = depth + 1
		for w in range(-alcove_hw - 1, alcove_hw + 2):
			var wall_tile: Vector2i
			if direction == "east":
				wall_tile = Vector2i(alcove_root.x + w, alcove_root.y + alcove_side * (half_w + 1 + end_d))
			else:
				wall_tile = Vector2i(alcove_root.x + alcove_side * (half_w + 1 + end_d), alcove_root.y + w)
			result["wall_tiles"].append(wall_tile)
		# Side walls
		for d in range(1, depth + 1):
			for side in [-(alcove_hw + 1), alcove_hw + 1]:
				var side_wall: Vector2i
				if direction == "east":
					side_wall = Vector2i(alcove_root.x + side, alcove_root.y + alcove_side * (half_w + 1 + d))
				else:
					side_wall = Vector2i(alcove_root.x + alcove_side * (half_w + 1 + d), alcove_root.y + side)
				result["wall_tiles"].append(side_wall)

		# Trap inside alcove
		var trap_d = depth / 2 + 1
		var trap_tile: Vector2i
		if direction == "east":
			trap_tile = Vector2i(alcove_root.x, alcove_root.y + alcove_side * (half_w + 1 + trap_d))
		else:
			trap_tile = Vector2i(alcove_root.x + alcove_side * (half_w + 1 + trap_d), alcove_root.y)
		_add_trap_pos(result, trap_tile, direction)

	_add_trap_pos(result, result["midpoint"], direction)
	_add_trap_pos(result, _midpoint(from_pt, result["midpoint"]), direction)
	return result
