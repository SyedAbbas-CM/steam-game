class_name WebBridgeGenerator
extends RefCounted

# Returns Array of Vector2i positions (local to room) where spider webs go
static func generate_bridges(floor_mask: Array, liquid_mask: Array, bridge_density: float, connections: Dictionary, w: int, h: int) -> Array:
	if bridge_density <= 0.0:
		return []

	var web_positions: Array = []
	var web_set: Dictionary = {}
	var cx = w / 2
	var cy = h / 2

	# Find exit points for each connection
	var exit_points: Array[Vector2i] = []
	for dir_name in connections:
		var ep = RoomShapeGenerator.get_exit_point(floor_mask, w, h, dir_name)
		# Move exit point 2 tiles inward so bridge starts inside the room
		match dir_name:
			"north": ep.y += 2
			"south": ep.y -= 2
			"west": ep.x += 2
			"east": ep.x -= 2
		exit_points.append(ep)

	# Trace paths from each exit to center (1 tile wide)
	for ep in exit_points:
		var path = _bresenham_line(ep.x, ep.y, cx, cy)
		for pos in path:
			if pos.x < 0 or pos.x >= w or pos.y < 0 or pos.y >= h:
				continue
			if not liquid_mask[pos.y][pos.x]:
				continue
			if not web_set.has(pos):
				web_set[pos] = true
				web_positions.append(pos)

	# Add random extra web tiles near existing webs
	var liquid_count = 0
	for y in range(h):
		for x in range(w):
			if liquid_mask[y][x]:
				liquid_count += 1

	var extra_count = int(liquid_count * bridge_density * 0.15)
	var attempts = 0
	while extra_count > 0 and attempts < extra_count * 3:
		attempts += 1
		var x = randi_range(1, w - 2)
		var y = randi_range(1, h - 2)
		if not liquid_mask[y][x]:
			continue
		var v = Vector2i(x, y)
		if web_set.has(v):
			continue
		# Only add if near an existing web
		var near_web = false
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			if web_set.has(v + d):
				near_web = true
				break
		if near_web:
			web_set[v] = true
			web_positions.append(v)
			extra_count -= 1

	return web_positions

static func _bresenham_line(x0: int, y0: int, x1: int, y1: int) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy

	var x = x0
	var y = y0
	while true:
		points.append(Vector2i(x, y))
		if x == x1 and y == y1:
			break
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
	return points
