class_name CorridorGenerator
extends RefCounted

enum CorridorType { STRAIGHT, ZIGZAG, L_BEND, WINDING, WIDE_CHAMBER, ALCOVE }
enum LengthClass { SHORT, LONG }

# Generate corridor between two exit points.
# Uses axis-aligned segments (never diagonal) to guarantee connectivity.
static func generate_corridor(
	from_exit: Vector2i, to_exit: Vector2i,
	direction: String, half_w: int, floor_number: int,
	complexity: float = 1.0
) -> Dictionary:
	# Complexity 0..2 biases the SHORT/LONG roll and the bend type roll.
	# 0.0 → always SHORT + STRAIGHT, 1.0 → 50/50 default, 2.0 → almost always LONG + bendy.
	var c: float = clampf(complexity, 0.0, 2.0)
	var long_chance: float = clampf(c * 0.5, 0.0, 1.0)
	var length_class = LengthClass.LONG if randf() < long_chance else LengthClass.SHORT
	var corridor_type = _roll_type_complex(floor_number, length_class, c)

	var result = _empty_result()
	var waypoints: Array[Vector2i] = _build_waypoints(from_exit, to_exit, direction, corridor_type, length_class)

	# Paint axis-aligned L-segments between each consecutive pair of waypoints
	for i in range(waypoints.size() - 1):
		_paint_l_connection(result, waypoints[i], waypoints[i + 1], direction, half_w)

	# Add alcove branches for ALCOVE type
	if corridor_type == CorridorType.ALCOVE:
		_add_alcove_branches(result, waypoints, direction, half_w, length_class)

	# Add chamber for WIDE_CHAMBER type
	if corridor_type == CorridorType.WIDE_CHAMBER:
		_add_chamber(result, from_exit, to_exit, length_class)

	result["type"] = corridor_type
	result["direction"] = direction
	result["length_class"] = length_class
	result["midpoint"] = _midpoint(from_exit, to_exit)

	# Trap positions at waypoints and segment midpoints
	for i in range(waypoints.size()):
		_add_trap_pos(result, waypoints[i], direction)
	for i in range(waypoints.size() - 1):
		_add_trap_pos(result, _midpoint(waypoints[i], waypoints[i + 1]), direction)

	var lc_name = "LONG" if length_class == LengthClass.LONG else "SHORT"
	print("  Corridor %s: %s %s w=%d (%d floor)" % [direction, lc_name, CorridorType.keys()[corridor_type], half_w * 2 + 1, result["floor_tiles"].size()])
	return result

## Complexity-aware roll. Low c → STRAIGHT bias; high c → more WINDING / ZIGZAG.
static func _roll_type_complex(floor_number: int, length_class: LengthClass, c: float) -> CorridorType:
	# At c=0, force STRAIGHT 80% / L_BEND 20% — beginner dungeons stay readable.
	if c < 0.35:
		return CorridorType.STRAIGHT if randf() < 0.8 else CorridorType.L_BEND
	# Otherwise fall back to the existing weighted table.
	return _roll_type(floor_number, length_class)


static func _roll_type(floor_number: int, length_class: LengthClass) -> CorridorType:
	var roll = randf()
	if length_class == LengthClass.SHORT:
		if roll < 0.30:
			return CorridorType.STRAIGHT
		elif roll < 0.55:
			return CorridorType.L_BEND
		elif roll < 0.75:
			return CorridorType.ZIGZAG
		elif roll < 0.90:
			return CorridorType.WIDE_CHAMBER
		else:
			return CorridorType.WINDING
	else:  # LONG
		if floor_number <= 1:
			if roll < 0.15:
				return CorridorType.STRAIGHT
			elif roll < 0.35:
				return CorridorType.ZIGZAG
			elif roll < 0.55:
				return CorridorType.WINDING
			elif roll < 0.75:
				return CorridorType.L_BEND
			else:
				return CorridorType.WIDE_CHAMBER
		else:
			if roll < 0.10:
				return CorridorType.STRAIGHT
			elif roll < 0.25:
				return CorridorType.ZIGZAG
			elif roll < 0.45:
				return CorridorType.WINDING
			elif roll < 0.60:
				return CorridorType.L_BEND
			elif roll < 0.80:
				return CorridorType.ALCOVE
			else:
				return CorridorType.WIDE_CHAMBER

# Build the waypoint list. All waypoints are connected with axis-aligned L-segments.
static func _build_waypoints(from_exit: Vector2i, to_exit: Vector2i, direction: String, ctype: CorridorType, length_class: LengthClass) -> Array[Vector2i]:
	var points: Array[Vector2i] = [from_exit]

	match ctype:
		CorridorType.STRAIGHT:
			pass  # Direct L-connection

		CorridorType.L_BEND:
			if length_class == LengthClass.SHORT:
				# Single bend
				var mid = _midpoint(from_exit, to_exit)
				var offset = randi_range(4, 8) * (1 if randf() > 0.5 else -1)
				points.append(_perp_offset(mid, direction, offset))
			else:
				# U-shape detour: go perpendicular, run parallel, come back
				var detour = randi_range(6, 12) * (1 if randf() > 0.5 else -1)
				var t1_pt = _lerp_along(from_exit, to_exit, 0.25)
				var t2_pt = _lerp_along(from_exit, to_exit, 0.75)
				points.append(_perp_offset(t1_pt, direction, detour))
				points.append(_perp_offset(t2_pt, direction, detour))

		CorridorType.ZIGZAG:
			var num_bends = 2 if length_class == LengthClass.SHORT else randi_range(3, 5)
			var max_offset = 6 if length_class == LengthClass.SHORT else randi_range(7, 12)
			var sign_val = 1 if randf() > 0.5 else -1
			for b in range(num_bends):
				var t = float(b + 1) / float(num_bends + 1)
				var base = _lerp_along(from_exit, to_exit, t)
				var offset = randi_range(maxi(3, max_offset / 2), max_offset) * sign_val
				points.append(_perp_offset(base, direction, offset))
				sign_val *= -1

		CorridorType.WINDING:
			var num_pts = randi_range(3, 4) if length_class == LengthClass.SHORT else randi_range(5, 8)
			var max_wobble = 5 if length_class == LengthClass.SHORT else randi_range(6, 10)
			var sign_val = 1 if randf() > 0.5 else -1
			for i in range(1, num_pts + 1):
				var t = float(i) / float(num_pts + 1)
				var base = _lerp_along(from_exit, to_exit, t)
				var offset = randi_range(2, max_wobble) * sign_val
				points.append(_perp_offset(base, direction, offset))
				sign_val *= -1

		CorridorType.WIDE_CHAMBER:
			# Base path: slight winding leading to chamber area
			var num_pts = 2 if length_class == LengthClass.SHORT else randi_range(3, 4)
			var sign_val = 1 if randf() > 0.5 else -1
			for i in range(1, num_pts + 1):
				var t = float(i) / float(num_pts + 1)
				# Skip waypoints near the center where chamber will go
				if t > 0.35 and t < 0.65:
					continue
				var base = _lerp_along(from_exit, to_exit, t)
				var offset = randi_range(2, 4) * sign_val
				points.append(_perp_offset(base, direction, offset))
				sign_val *= -1

		CorridorType.ALCOVE:
			# Base path: zigzag-like with branches added separately
			var num_bends = 1 if length_class == LengthClass.SHORT else randi_range(2, 3)
			var sign_val = 1 if randf() > 0.5 else -1
			for b in range(num_bends):
				var t = float(b + 1) / float(num_bends + 1)
				var base = _lerp_along(from_exit, to_exit, t)
				var offset = randi_range(3, 6) * sign_val
				points.append(_perp_offset(base, direction, offset))
				sign_val *= -1

	points.append(to_exit)
	return points

# --- Alcove branches ---

static func _add_alcove_branches(result: Dictionary, waypoints: Array[Vector2i], direction: String, half_w: int, length_class: int) -> void:
	var num_alcoves = randi_range(1, 2) if length_class == LengthClass.SHORT else randi_range(2, 4)

	for a in range(num_alcoves):
		# Pick a point along the corridor path
		var wp_idx = randi_range(0, waypoints.size() - 2)
		var t = randf_range(0.2, 0.8)
		var branch_root = _midpoint(waypoints[wp_idx], waypoints[wp_idx + 1])
		if t < 0.5:
			branch_root = _midpoint(waypoints[wp_idx], branch_root)
		else:
			branch_root = _midpoint(branch_root, waypoints[wp_idx + 1])

		var depth = randi_range(4, 8) if length_class == LengthClass.LONG else randi_range(3, 5)
		var alcove_side = 1 if randf() > 0.5 else -1
		var alcove_hw = 1  # Always 3 tiles wide

		# Branch endpoint
		var branch_end: Vector2i
		if direction == "east":
			branch_end = Vector2i(branch_root.x, branch_root.y + alcove_side * (half_w + depth))
		else:
			branch_end = Vector2i(branch_root.x + alcove_side * (half_w + depth), branch_root.y)

		# Paint the branch as axis-aligned segment
		_paint_axis_segment(result, branch_root, branch_end, alcove_hw)
		_paint_junction(result, branch_root, alcove_hw)

		# End cap walls
		var cap_offset = 1
		if direction == "east":
			var end_y = branch_end.y + alcove_side * cap_offset
			for w in range(-alcove_hw - 1, alcove_hw + 2):
				result["wall_tiles"].append(Vector2i(branch_end.x + w, end_y))
		else:
			var end_x = branch_end.x + alcove_side * cap_offset
			for w in range(-alcove_hw - 1, alcove_hw + 2):
				result["wall_tiles"].append(Vector2i(end_x, branch_end.y + w))

		# Side walls along branch
		if direction == "east":
			var start_y = mini(branch_root.y, branch_end.y)
			var end_y_wall = maxi(branch_root.y, branch_end.y)
			for y in range(start_y, end_y_wall + 1):
				result["wall_tiles"].append(Vector2i(branch_root.x - alcove_hw - 1, y))
				result["wall_tiles"].append(Vector2i(branch_root.x + alcove_hw + 1, y))
		else:
			var start_x = mini(branch_root.x, branch_end.x)
			var end_x_wall = maxi(branch_root.x, branch_end.x)
			for x in range(start_x, end_x_wall + 1):
				result["wall_tiles"].append(Vector2i(x, branch_root.y - alcove_hw - 1))
				result["wall_tiles"].append(Vector2i(x, branch_root.y + alcove_hw + 1))

		# Trap inside alcove
		var trap_pt = _midpoint(branch_root, branch_end)
		_add_trap_pos(result, trap_pt, direction)

# --- Wide chamber ---

static func _add_chamber(result: Dictionary, from_exit: Vector2i, to_exit: Vector2i, length_class: int) -> void:
	var mid = _midpoint(from_exit, to_exit)
	var chamber_hw = 3 if length_class == LengthClass.SHORT else randi_range(4, 5)

	# Floor
	for cy in range(-chamber_hw, chamber_hw + 1):
		for cx in range(-chamber_hw, chamber_hw + 1):
			result["floor_tiles"].append(Vector2i(mid.x + cx, mid.y + cy))

	# Perimeter walls
	for cx in range(-chamber_hw - 1, chamber_hw + 2):
		result["wall_tiles"].append(Vector2i(mid.x + cx, mid.y - chamber_hw - 1))
		result["wall_tiles"].append(Vector2i(mid.x + cx, mid.y + chamber_hw + 1))
	for cy in range(-chamber_hw, chamber_hw + 1):
		result["wall_tiles"].append(Vector2i(mid.x - chamber_hw - 1, mid.y + cy))
		result["wall_tiles"].append(Vector2i(mid.x + chamber_hw + 1, mid.y + cy))

	_add_trap_pos(result, mid, "east")

# --- Core painting (axis-aligned only) ---

static func _paint_l_connection(result: Dictionary, a: Vector2i, b: Vector2i, direction: String, half_w: int) -> void:
	var corner: Vector2i
	if direction == "east":
		corner = Vector2i(b.x, a.y)
	else:
		corner = Vector2i(a.x, b.y)

	if a != corner:
		_paint_axis_segment(result, a, corner, half_w)
	if corner != b:
		_paint_axis_segment(result, corner, b, half_w)
	_paint_junction(result, corner, half_w)

static func _paint_axis_segment(result: Dictionary, from_pt: Vector2i, to_pt: Vector2i, half_w: int) -> void:
	var wall_offset = half_w + 1
	var dx = to_pt.x - from_pt.x
	var dy = to_pt.y - from_pt.y

	if absi(dx) >= absi(dy):
		var start_x = mini(from_pt.x, to_pt.x)
		var end_x = maxi(from_pt.x, to_pt.x)
		var y = from_pt.y
		for x in range(start_x, end_x + 1):
			for w in range(-half_w, half_w + 1):
				result["floor_tiles"].append(Vector2i(x, y + w))
			result["wall_tiles"].append(Vector2i(x, y - wall_offset))
			result["wall_tiles"].append(Vector2i(x, y + wall_offset))
	else:
		var start_y = mini(from_pt.y, to_pt.y)
		var end_y = maxi(from_pt.y, to_pt.y)
		var x = from_pt.x
		for y in range(start_y, end_y + 1):
			for w in range(-half_w, half_w + 1):
				result["floor_tiles"].append(Vector2i(x + w, y))
			result["wall_tiles"].append(Vector2i(x - wall_offset, y))
			result["wall_tiles"].append(Vector2i(x + wall_offset, y))

static func _paint_junction(result: Dictionary, center: Vector2i, half_w: int) -> void:
	for dy in range(-half_w, half_w + 1):
		for dx in range(-half_w, half_w + 1):
			result["floor_tiles"].append(Vector2i(center.x + dx, center.y + dy))

# --- Helpers ---

static func _empty_result() -> Dictionary:
	return {
		"floor_tiles": [] as Array[Vector2i],
		"wall_tiles": [] as Array[Vector2i],
		"alcove_tiles": [] as Array[Vector2i],
		"trap_positions": [] as Array[Dictionary],
		"midpoint": Vector2i.ZERO,
	}

static func _midpoint(a: Vector2i, b: Vector2i) -> Vector2i:
	return Vector2i((a.x + b.x) / 2, (a.y + b.y) / 2)

static func _lerp_along(a: Vector2i, b: Vector2i, t: float) -> Vector2i:
	return Vector2i(
		int(lerp(float(a.x), float(b.x), t)),
		int(lerp(float(a.y), float(b.y), t))
	)

static func _add_trap_pos(result: Dictionary, pos: Vector2i, direction: String, tile_size: int = 8) -> void:
	result["trap_positions"].append({
		"position": Vector2(pos.x * tile_size + 4, pos.y * tile_size + 4),
		"direction": direction,
	})

static func _perp_offset(pt: Vector2i, direction: String, amount: int) -> Vector2i:
	if direction == "east":
		return Vector2i(pt.x, pt.y + amount)
	else:
		return Vector2i(pt.x + amount, pt.y)
