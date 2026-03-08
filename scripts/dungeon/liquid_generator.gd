class_name LiquidGenerator
extends RefCounted

# Returns 2D bool array same dimensions as floor_mask
# true = this tile should be liquid
static func generate_liquid_fill(floor_mask: Array, intensity: float, seed_val: int) -> Array:
	if intensity <= 0.0:
		return _empty_mask(floor_mask)

	var h = floor_mask.size()
	if h == 0:
		return []
	var w = floor_mask[0].size()

	var noise = FastNoiseLite.new()
	noise.seed = seed_val
	noise.frequency = 0.15
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

	var liquid_mask: Array = []
	for y in range(h):
		var row: Array = []
		for x in range(w):
			if not floor_mask[y][x]:
				row.append(false)
				continue
			var noise_val = (noise.get_noise_2d(float(x), float(y)) + 1.0) / 2.0
			row.append(noise_val < intensity)
		liquid_mask.append(row)

	return liquid_mask

# Directional flow: creates a river/channel pattern flowing in a direction
# flow_direction: Vector2 indicating flow axis (e.g. Vector2(1,0) = east, Vector2(0,1) = south)
static func generate_directional_flow(floor_mask: Array, intensity: float, seed_val: int, flow_direction: Vector2) -> Array:
	if intensity <= 0.0:
		return _empty_mask(floor_mask)

	var h = floor_mask.size()
	if h == 0:
		return []
	var w = floor_mask[0].size()

	var noise = FastNoiseLite.new()
	noise.seed = seed_val
	noise.frequency = 0.12
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

	# Perpendicular direction for computing distance from flow center-line
	var perp = Vector2(-flow_direction.y, flow_direction.x)
	var cx = w / 2.0
	var cy = h / 2.0
	# Max perpendicular distance from center
	var max_perp = max(w, h) / 2.0

	var liquid_mask: Array = []
	for y in range(h):
		var row: Array = []
		for x in range(w):
			if not floor_mask[y][x]:
				row.append(false)
				continue
			# Perpendicular distance from center-line through room center
			var rel = Vector2(x - cx, y - cy)
			var perp_dist = abs(rel.dot(perp))
			# Gradient: higher probability near center-line
			var gradient = 1.0 - (perp_dist / max_perp) * 0.7
			var noise_val = (noise.get_noise_2d(float(x), float(y)) + 1.0) / 2.0
			var threshold = intensity * gradient + noise_val * 0.25
			row.append(threshold > 0.55)
		liquid_mask.append(row)

	# Ensure a continuous 2-tile-wide channel along the flow center
	var flow_norm = flow_direction.normalized()
	for i in range(max(w, h)):
		var t = float(i) / float(max(w, h))
		# Walk along flow direction through the room
		var px = int(cx + flow_norm.x * (t - 0.5) * w)
		var py = int(cy + flow_norm.y * (t - 0.5) * h)
		for offset in range(-1, 2):
			var nx = px + int(perp.x) * offset
			var ny = py + int(perp.y) * offset
			if nx >= 0 and nx < w and ny >= 0 and ny < h and floor_mask[ny][nx]:
				liquid_mask[ny][nx] = true

	return liquid_mask

static func _empty_mask(floor_mask: Array) -> Array:
	var result: Array = []
	for y in range(floor_mask.size()):
		var row: Array = []
		for _x in range(floor_mask[y].size()):
			row.append(false)
		result.append(row)
	return result
