class_name RoomShapeGenerator
extends RefCounted

# Returns { "mask": Array[Array[bool]], "width": int, "height": int }
# mask[y][x] = true means this tile is floor

static func generate_shape(shape: RoomData.RoomShape) -> Dictionary:
	match shape:
		RoomData.RoomShape.RECTANGLE:
			return _rect(randi_range(13, 19), randi_range(11, 17))
		RoomData.RoomShape.WIDE_RECT:
			return _rect(randi_range(19, 25), randi_range(9, 13))
		RoomData.RoomShape.TALL_RECT:
			return _rect(randi_range(11, 15), randi_range(15, 21))
		RoomData.RoomShape.CIRCLE:
			var d = randi_range(13, 19)
			return _circle(d, d)
		RoomData.RoomShape.L_SHAPE_NE:
			return _l_shape(true, true)
		RoomData.RoomShape.L_SHAPE_NW:
			return _l_shape(true, false)
		RoomData.RoomShape.L_SHAPE_SE:
			return _l_shape(false, true)
		RoomData.RoomShape.L_SHAPE_SW:
			return _l_shape(false, false)
		RoomData.RoomShape.IRREGULAR:
			return _irregular()
		_:
			return _rect(randi_range(13, 19), randi_range(11, 17))

# Standard rectangle — floor is interior (1-pixel wall border)
static func _rect(w: int, h: int) -> Dictionary:
	var mask: Array = []
	for y in range(h):
		var row: Array = []
		for x in range(w):
			row.append(x >= 1 and x < w - 1 and y >= 1 and y < h - 1)
		mask.append(row)
	return { "mask": mask, "width": w, "height": h }

# Circle shape — elliptical floor within bounding box
static func _circle(w: int, h: int) -> Dictionary:
	var mask: Array = []
	var cx = w / 2.0
	var cy = h / 2.0
	var rx = (w - 2) / 2.0  # leave 1-tile border
	var ry = (h - 2) / 2.0
	for y in range(h):
		var row: Array = []
		for x in range(w):
			var dx = (x - cx) / rx
			var dy = (y - cy) / ry
			row.append(dx * dx + dy * dy <= 1.0)
		mask.append(row)
	return { "mask": mask, "width": w, "height": h }

# L-shape: two rectangles joined at corner
# top_cut: which vertical half is cut (true=cut top portion, false=cut bottom)
# right_cut: which horizontal half is cut (true=cut right, false=cut left)
static func _l_shape(top_cut: bool, right_cut: bool) -> Dictionary:
	var w = randi_range(17, 23)
	var h = randi_range(15, 21)
	var mask: Array = []
	var cut_w = 10  # half the room width for the cutout
	var cut_h = 9   # half the room height for the cutout

	for y in range(h):
		var row: Array = []
		for x in range(w):
			# Start as regular rectangle interior
			var is_floor = x >= 1 and x < w - 1 and y >= 1 and y < h - 1
			# Cut out the corner
			if is_floor:
				var in_cut_x = (x >= w - cut_w) if right_cut else (x < cut_w)
				var in_cut_y = (y < cut_h) if top_cut else (y >= h - cut_h)
				if in_cut_x and in_cut_y:
					is_floor = false
			row.append(is_floor)
		mask.append(row)
	return { "mask": mask, "width": w, "height": h }

# Irregular cave shape using cellular automata
static func _irregular() -> Dictionary:
	var w = randi_range(15, 21)
	var h = randi_range(13, 19)
	var mask: Array = []

	# Initialize with random fill (55% floor)
	for y in range(h):
		var row: Array = []
		for x in range(w):
			if x <= 1 or x >= w - 2 or y <= 1 or y >= h - 2:
				row.append(false)  # border is always wall
			else:
				row.append(randf() < 0.55)
		mask.append(row)

	# Run 4 smoothing iterations (cellular automata rule B5678/S45678)
	for _iter in range(4):
		var new_mask: Array = []
		for y in range(h):
			var row: Array = []
			for x in range(w):
				if x <= 1 or x >= w - 2 or y <= 1 or y >= h - 2:
					row.append(false)
				else:
					var neighbors = _count_floor_neighbors(mask, x, y)
					if mask[y][x]:
						row.append(neighbors >= 4)  # survive with 4+ neighbors
					else:
						row.append(neighbors >= 5)  # birth with 5+ neighbors
			new_mask.append(row)
		mask = new_mask

	# Ensure center area is always floor (so room is usable)
	var cx = w / 2
	var cy = h / 2
	for y in range(cy - 3, cy + 4):
		for x in range(cx - 3, cx + 4):
			if x > 1 and x < w - 2 and y > 1 and y < h - 2:
				mask[y][x] = true

	# Flood fill from center to remove disconnected islands
	var reachable = _flood_fill(mask, cx, cy, w, h)
	for y in range(h):
		for x in range(w):
			if mask[y][x] and not reachable[y][x]:
				mask[y][x] = false

	return { "mask": mask, "width": w, "height": h }

static func _count_floor_neighbors(mask: Array, x: int, y: int) -> int:
	var count = 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx = x + dx
			var ny = y + dy
			if ny >= 0 and ny < mask.size() and nx >= 0 and nx < mask[0].size():
				if mask[ny][nx]:
					count += 1
	return count

static func _flood_fill(mask: Array, start_x: int, start_y: int, w: int, h: int) -> Array:
	var visited: Array = []
	for y in range(h):
		var row: Array = []
		for _x in range(w):
			row.append(false)
		visited.append(row)

	var stack: Array[Vector2i] = [Vector2i(start_x, start_y)]
	while stack.size() > 0:
		var pos = stack.pop_back()
		if pos.x < 0 or pos.x >= w or pos.y < 0 or pos.y >= h:
			continue
		if visited[pos.y][pos.x] or not mask[pos.y][pos.x]:
			continue
		visited[pos.y][pos.x] = true
		stack.append(Vector2i(pos.x + 1, pos.y))
		stack.append(Vector2i(pos.x - 1, pos.y))
		stack.append(Vector2i(pos.x, pos.y + 1))
		stack.append(Vector2i(pos.x, pos.y - 1))
	return visited

# Get the exit point for a given direction on a room shape
# Returns the local tile coordinate where a corridor should connect
static func get_exit_point(mask: Array, w: int, h: int, direction: String) -> Vector2i:
	match direction:
		"north":
			# Find floor tile nearest to center along top edge (y=1)
			var cx = w / 2
			for offset in range(w):
				for sign in [0, 1, -1]:
					var x = cx + sign * offset
					if x >= 0 and x < w and mask[1][x]:
						return Vector2i(x, 0)
		"south":
			var cx = w / 2
			for offset in range(w):
				for sign in [0, 1, -1]:
					var x = cx + sign * offset
					if x >= 0 and x < w and mask[h - 2][x]:
						return Vector2i(x, h - 1)
		"west":
			var cy = h / 2
			for offset in range(h):
				for sign in [0, 1, -1]:
					var y = cy + sign * offset
					if y >= 0 and y < h and mask[y][1]:
						return Vector2i(0, y)
		"east":
			var cy = h / 2
			for offset in range(h):
				for sign in [0, 1, -1]:
					var y = cy + sign * offset
					if y >= 0 and y < h and mask[y][w - 2]:
						return Vector2i(w - 1, y)
	# Fallback to center of edge
	match direction:
		"north": return Vector2i(w / 2, 0)
		"south": return Vector2i(w / 2, h - 1)
		"west": return Vector2i(0, h / 2)
		"east": return Vector2i(w - 1, h / 2)
	return Vector2i(w / 2, h / 2)
