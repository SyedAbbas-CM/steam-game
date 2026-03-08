extends SceneTree

# Bakes the FULL Legends of Yore world into overworld.tscn
# Uses world_pos (mx, my) from zone data for placement
# Reads map text files + zone XMLs for terrain/buildings

var MAPS_DIR = "/Users/developer-cloudprimero/Downloads/legends-of-yore-export/data/maps/"
var ZONES_DIR = "/Users/developer-cloudprimero/Downloads/legends-of-yore-export/data/world/zones/"

# Char → tile ID mapping (from LoadedMap.java)
var CHAR_TO_TILE: Dictionary = {
	' ': 1,    # FLOOR
	'!': 0,    # NOTHING
	'#': 5,    # WALL
	'|': 8,    # SIDE_WALL
	'D': 3,    # CLOSED_DOOR
	'W': 10,   # WATER
	'L': 11,   # LAVA
	'T': 62,   # TREE
	'o': 9,    # TILED_FLOOR
	'*': 9,    # TILED_FLOOR (path)
	'R': 67,   # WELL
	'b': 15,   # BRIDGE
	'B': 14,   # BRIDGE2
	'@': 64,   # ROUGH_STONE
	'F': 7,    # FENCE
	'S': 7,    # FENCE + start
	'U': 22,   # STAIRS_UP + start
	's': 6,    # STAIRS_DOWN
	'X': 13,   # EXIT
	'E': 23,   # GATE_H
	'e': 24,   # GATE_V
	'^': 25,   # SHIP_TILE1
	'_': 26,   # SHIP_TILE2
	'+': 27,   # SHIP_TILE3
	'=': 28,   # SHIP_TILE4
	'&': 29,   # SHIP_TILE5
	'n': 30,   # PLOWED
	'a': 68,   # SNOW_TREE
	'd': 66,   # JUNGLE_TREE
	'f': 70,   # PALM
	'c': 51,   # CACTUS/GRAVE
	'P': 1,    # Portal → floor
	'C': 1,    # Chest → floor
}

# Tile ID → sprite index (from TileMapping.java)
var TILE_SPRITE: Dictionary = {
	0: 0,      # NOTHING → 0 (wall sprite)
	1: 1,      # FLOOR
	3: 2,      # CLOSED_DOOR
	4: 3,      # OPEN_DOOR
	5: 0,      # WALL → same as nothing (wall sprite 0)
	6: 5,      # STAIRS_DOWN
	7: 4,      # FENCE
	8: 6,      # SIDE_WALL
	9: 7,      # TILED_FLOOR
	10: 32,    # WATER
	11: 33,    # LAVA
	12: 34,    # POISON
	13: 0,     # EXIT → wall
	14: 128,   # BRIDGE2
	15: 129,   # BRIDGE
	20: 9,     # ?
	21: 8,     # ?
	22: 136,   # STAIRS_UP
	23: 4,     # GATE_H
	24: 5,     # GATE_V
	25: 160,   # SHIP1
	26: 161,   # SHIP2
	27: 169,   # SHIP3
	28: 171,   # SHIP4
	29: 166,   # SHIP5
	30: 139,   # PLOWED
	51: 99,    # CACTUS
	62: 126,   # TREE
	63: 123,   # ROUGH
	64: 124,   # ROUGH_STONE
	65: 125,   # PILLAR
	66: 142,   # JUNGLE_TREE
	67: 131,   # WELL
	68: 158,   # SNOW_TREE
	69: 126,   # FLOWER
	70: 174,   # PALM
	71: 132,   # MUSHROOM
}

# Tile name lookup for debug
var TILE_NAMES: Dictionary = {
	0: "NOTHING", 1: "FLOOR", 3: "CLOSED_DOOR", 5: "WALL",
	6: "STAIRS_DOWN", 7: "FENCE", 8: "SIDE_WALL", 9: "TILED_FLOOR",
	10: "WATER", 11: "LAVA", 13: "EXIT", 62: "TREE",
	22: "STAIRS_UP", 64: "ROUGH_STONE", 67: "WELL",
}

# Scale factor: each LoY tile becomes SCALE x SCALE tiles
var SCALE = 4

# Zone-specific tree density overrides (0.0 = no trees, used for towns/camps)
var ZONE_TREE_OVERRIDES = {
	"aria": 0.0,       # Town — trees placed manually in post-process
	"aria-g": 0.0,     # Graveyard — sparse dead trees in post-process
	"camp": 0.01,      # Military camp — mostly clear
	"farm": 0.02,      # Farmland — open fields with scattered trees
}

# Only bake original LoY zones (no custom zones)
var LOY_ONLY = true
var CUSTOM_ZONE_IDS = ["riverside", "millford", "quarry", "thornfield",
	"harbormouth", "oldcapital", "crossroads", "banditwood",
	"lakeshore", "highroad", "marshgate"]

var ZONE_MAP_FILES: Dictionary = {
	"airlon": "airlon", "bch1": "beach", "blf1": "bluff", "brg1": "bridge",
	"camp": "camp", "cel1": "cellar", "cennyn": "cennyn", "clearing": "clearing",
	"crt1": "courtyard", "end1": "end1", "farm": "farm", "for1": "forest",
	"for2": "forest2", "for3": "forest3", "for4": "forest4", "frozen": "frozen",
	"gomb": "gombard", "island": "island", "jungle1": "jungle1", "jungle2": "jungle2",
	"kor": "kor", "llecudd": "llecudd", "moors": "moors", "naleg": "naleg",
	"nord1": "nordolk", "paititi": "paititi", "peaks": "peaks", "plains": "plains",
	"shrine": "shrine", "swamp": "swamp", "talmita": "talmita", "talnivek": "talnivek",
	"thicket": "thicket", "thicket2": "thicket2", "thule": "thule",
	"tor1": "tor1", "tor2": "tor2", "tor3": "tor3", "tor4": "tor4",
	"tor5": "tor5", "tor6": "tor6", "tundra": "tundra", "und1": "under1",
	"vale": "vale", "willows": "willows", "ynys": "ynys",
	"riverside": "riverside", "millford": "millford", "quarry": "quarry",
	"thornfield": "thornfield", "harbormouth": "harbormouth", "oldcapital": "oldcapital",
	"crossroads": "crossroads", "banditwood": "banditwood", "lakeshore": "lakeshore",
	"highroad": "highroad", "marshgate": "marshgate",
}

# Layers
var ground: TileMapLayer
var paths_layer: TileMapLayer
var water_layer: TileMapLayer
var decorations: TileMapLayer
var buildings: TileMapLayer
var fences_layer: TileMapLayer

func _init():
	seed(42)
	_bake()
	quit()

func sa(idx: int) -> Vector2i:
	return Vector2i(idx % 16, idx / 16)

func _get_sprite(tile_id: int, tileset: int) -> Vector2i:
	var sprite_idx: int
	# Graves 52-61
	if tile_id >= 52 and tile_id <= 61:
		sprite_idx = 48 + (tile_id - 52)
	elif TILE_SPRITE.has(tile_id):
		sprite_idx = TILE_SPRITE[tile_id]
	else:
		sprite_idx = 1  # default to floor

	# Apply tileset offset for themed tiles (sprite < 30)
	if sprite_idx < 30:
		sprite_idx += tileset

	return sa(sprite_idx)

## Zone placement offsets (tile coordinates where each zone starts on our map)
## Computed by graph layout algorithm based on exit connections
var zone_offsets: Dictionary = {}  # zone_id -> Vector2i

# Binary .scn = much faster loading than text .tscn
var OUTPUT_SCENE = "res://scenes/overworld/overworld.scn"

func _bake():
	# Always load from the text template, save to OUTPUT_SCENE (may be binary .scn)
	var template_path = "res://scenes/overworld/overworld.tscn"
	var packed = load(template_path) as PackedScene
	if not packed:
		print("ERROR: Cannot load overworld template scene")
		return

	var scene = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var loy_tileset = _create_loy_tileset()

	ground = scene.get_node("Ground") as TileMapLayer
	paths_layer = scene.get_node("Paths") as TileMapLayer
	water_layer = scene.get_node("Water") as TileMapLayer
	decorations = scene.get_node("Decorations") as TileMapLayer
	buildings = scene.get_node("Buildings") as TileMapLayer
	fences_layer = scene.get_node("Fences") as TileMapLayer

	for layer in [ground, paths_layer, water_layer, decorations, buildings, fences_layer]:
		layer.clear()
		layer.tile_set = loy_tileset

	# Load all zone data from our .tres files
	var zones = _load_all_zones()
	print("Loaded " + str(zones.size()) + " zones")

	# Build zone lookup
	var zone_map: Dictionary = {}
	for z in zones:
		zone_map[z.id] = z

	# Layout zones using BFS from aria as root
	_layout_zones(zone_map)
	print("Placed " + str(zone_offsets.size()) + " zones")

	# Save baked offsets back into zone .tres files
	for zone in zones:
		if zone_offsets.has(zone.id):
			zone.baked_offset = zone_offsets[zone.id]
			zone.baked_scale = SCALE
			ResourceSaver.save(zone, "res://resources/world/zones/" + zone.id + ".tres")

	# First paint all grass/floor for each zone area
	for zone in zones:
		if not zone_offsets.has(zone.id):
			print("  SKIP (unconnected): " + zone.id)
			continue
		var offset = zone_offsets[zone.id]
		var tileset = zone.tileset
		var w = zone.width
		var h = zone.height
		var floor_tile = _get_sprite(1, tileset)

		for x in range(w):
			for y in range(h):
				ground.set_cell(Vector2i(offset.x + x, offset.y + y), 0, floor_tile)

		print("Zone: " + zone.id + " at (" + str(offset.x) + "," + str(offset.y) + ") " + str(w) + "x" + str(h) + " ts=" + str(tileset))

	# Apply map text files
	for zone in zones:
		if not zone_offsets.has(zone.id):
			continue
		if ZONE_MAP_FILES.has(zone.id):
			_apply_map_file(zone)

	# Apply zone XML data (setTile, houses, closeEdge, trees, graves)
	for zone in zones:
		if not zone_offsets.has(zone.id):
			continue
		_apply_zone_xml(zone)

	# Apply tile_overrides from web editor (hand-painted tile changes)
	for zone in zones:
		if not zone_offsets.has(zone.id):
			continue
		if zone.tile_overrides.size() > 0:
			_apply_tile_overrides(zone)

	# Draw connections between zones based on exits
	for zone in zones:
		if not zone_offsets.has(zone.id):
			continue
		_draw_zone_connections(zone, zone_map)

	# Fill empty void regions between zones with dark tiles
	_fill_void_regions()

	# Post-process specific zones (clear trees, add town features, etc.)
	_post_process_zones(zone_map)

	print("Ground: " + str(ground.get_used_cells().size()))
	print("Buildings: " + str(buildings.get_used_cells().size()))
	print("Decorations: " + str(decorations.get_used_cells().size()))
	print("Water: " + str(water_layer.get_used_cells().size()))
	print("Fences: " + str(fences_layer.get_used_cells().size()))

	var new_packed = PackedScene.new()
	new_packed.pack(scene)
	var err = ResourceSaver.save(new_packed, OUTPUT_SCENE)
	if err == OK:
		print("SUCCESS: Full world baked!")
	else:
		print("ERROR: " + str(err))
	scene.queue_free()

func _layout_zones(zone_map: Dictionary) -> void:
	# BFS from aria, placing connected zones adjacent with a 3-tile gap
	# Exit edges define which direction to place the target zone

	var GAP = 3 if SCALE == 1 else 20  # Small gap at 1x, large at 4x
	var queue: Array = []
	var placed: Dictionary = {}  # zone_id -> true

	# Build reverse connection map: for each zone, who connects TO it
	var reverse_connections: Dictionary = {}  # target_id -> [{source_id, exit_data}]
	for zone_id in zone_map:
		var zone = zone_map[zone_id]
		for exit_data in zone.exits:
			var target_id = str(exit_data["target"])
			if not reverse_connections.has(target_id):
				reverse_connections[target_id] = []
			reverse_connections[target_id].append({
				"source_id": zone_id,
				"exit_data": exit_data
			})

	# Start with aria at origin
	if not zone_map.has("aria"):
		print("ERROR: No aria zone")
		return

	zone_offsets["aria"] = Vector2i(-12, -12)  # Center aria around origin
	placed["aria"] = true
	queue.append("aria")

	# Seed disconnected clusters that aren't reachable from aria
	# These connect via portals in LoY but we place them in empty space
	# moors cluster (moors, airlon, clearing, ynys)
	var cluster_x = -200 * SCALE
	if zone_map.has("moors"):
		zone_offsets["moors"] = Vector2i(cluster_x, -180 * SCALE)
		placed["moors"] = true
		queue.append("moors")
	if zone_map.has("talnivek"):
		zone_offsets["talnivek"] = Vector2i(cluster_x, -120 * SCALE)
		placed["talnivek"] = true
		queue.append("talnivek")
	if zone_map.has("pst1"):
		zone_offsets["pst1"] = Vector2i(cluster_x, -60 * SCALE)
		placed["pst1"] = true
		queue.append("pst1")

	while queue.size() > 0:
		var current_id = queue.pop_front()
		var current = zone_map[current_id]
		var cur_offset = zone_offsets[current_id]

		# Collect all connections: forward exits + reverse connections
		var connections: Array = []

		# Forward exits from current zone (scale exit positions)
		for exit_data in current.exits:
			var target_id = str(exit_data["target"])
			connections.append({
				"target_id": target_id,
				"ex": int(exit_data["x"]) * SCALE,
				"ey": int(exit_data["y"]) * SCALE,
				"tx": int(exit_data["tx"]) * SCALE,
				"ty": int(exit_data["ty"]) * SCALE,
			})

		# Reverse connections: zones that exit TO current zone
		if reverse_connections.has(current_id):
			for rc in reverse_connections[current_id]:
				var src_id = rc["source_id"]
				var ed = rc["exit_data"]
				connections.append({
					"target_id": src_id,
					"ex": int(ed["tx"]) * SCALE,
					"ey": int(ed["ty"]) * SCALE,
					"tx": int(ed["x"]) * SCALE,
					"ty": int(ed["y"]) * SCALE,
				})

		for conn in connections:
			var target_id = conn["target_id"]
			if not zone_map.has(target_id):
				continue

			if placed.has(target_id):
				continue

			var target = zone_map[target_id]
			var ex = conn["ex"]
			var ey = conn["ey"]
			var tx = conn["tx"]
			var ty = conn["ty"]

			# Determine placement direction based on exit position on current zone edge
			var target_offset = Vector2i.ZERO
			var cur_w = current.width * SCALE
			var cur_h = current.height * SCALE
			var tgt_w = target.width * SCALE
			var tgt_h = target.height * SCALE

			# Exit on top edge (y=0) → target goes above
			if ey == 0:
				target_offset = Vector2i(
					cur_offset.x + ex - tx,
					cur_offset.y - tgt_h - GAP
				)
			# Exit on bottom edge (y=height-1 or close)
			elif ey >= cur_h - 2 * SCALE:
				target_offset = Vector2i(
					cur_offset.x + ex - tx,
					cur_offset.y + cur_h + GAP
				)
			# Exit on left edge (x=0)
			elif ex == 0:
				target_offset = Vector2i(
					cur_offset.x - tgt_w - GAP,
					cur_offset.y + ey - ty
				)
			# Exit on right edge (x=width-1 or close)
			elif ex >= cur_w - 2 * SCALE:
				target_offset = Vector2i(
					cur_offset.x + cur_w + GAP,
					cur_offset.y + ey - ty
				)
			else:
				# Interior exit - place based on relative world_pos
				var dx = target.world_pos.x - current.world_pos.x
				var dy = target.world_pos.y - current.world_pos.y
				if abs(dx) > abs(dy):
					if dx > 0:
						target_offset = Vector2i(cur_offset.x + cur_w + GAP, cur_offset.y + ey - ty)
					else:
						target_offset = Vector2i(cur_offset.x - tgt_w - GAP, cur_offset.y + ey - ty)
				else:
					if dy > 0:
						target_offset = Vector2i(cur_offset.x + ex - tx, cur_offset.y + cur_h + GAP)
					else:
						target_offset = Vector2i(cur_offset.x + ex - tx, cur_offset.y - tgt_h - GAP)

			# Check for overlap with already placed zones
			var overlaps = false
			for pid in placed:
				var pzone = zone_map[pid]
				var poff = zone_offsets[pid]
				if _rects_overlap(target_offset, tgt_w, tgt_h,
						poff, pzone.width * SCALE, pzone.height * SCALE, GAP - 1):
					overlaps = true
					break

			if overlaps:
				# Try to nudge it to avoid overlap
				var nudged = _nudge_placement(target_offset, target, zone_map, placed, GAP)
				if nudged != Vector2i(-99999, -99999):
					target_offset = nudged
				else:
					print("  WARNING: Could not place " + target_id + " without overlap, forcing")

			zone_offsets[target_id] = target_offset
			placed[target_id] = true
			queue.append(target_id)

func _rects_overlap(a_pos: Vector2i, a_w: int, a_h: int,
		b_pos: Vector2i, b_w: int, b_h: int, margin: int = 0) -> bool:
	return not (a_pos.x + a_w + margin <= b_pos.x or
				b_pos.x + b_w + margin <= a_pos.x or
				a_pos.y + a_h + margin <= b_pos.y or
				b_pos.y + b_h + margin <= a_pos.y)

func _nudge_placement(base: Vector2i, target, zone_map: Dictionary,
		placed: Dictionary, gap: int) -> Vector2i:
	# Try nudging in various directions to find non-overlapping position
	var tgt_w = target.width * SCALE
	var tgt_h = target.height * SCALE
	for nudge_dist in [20, 40, 60, 80, 120, 160, 200]:
		for dir in [Vector2i(nudge_dist, 0), Vector2i(-nudge_dist, 0),
					Vector2i(0, nudge_dist), Vector2i(0, -nudge_dist),
					Vector2i(nudge_dist, nudge_dist), Vector2i(-nudge_dist, -nudge_dist)]:
			var test = base + dir
			var ok = true
			for pid in placed:
				var pzone = zone_map[pid]
				var poff = zone_offsets[pid]
				if _rects_overlap(test, tgt_w, tgt_h,
						poff, pzone.width * SCALE, pzone.height * SCALE, gap - 1):
					ok = false
					break
			if ok:
				return test
	return Vector2i(-99999, -99999)

func _load_all_zones() -> Array:
	var zones = []
	var zone_dir = "res://resources/world/zones/"
	var dir = DirAccess.open(zone_dir)
	if not dir:
		print("ERROR: Cannot open zones directory")
		return zones
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var zone = load(zone_dir + fname)
			if zone and zone.id != "" and zone.id != "test":
				# Skip custom zones when LOY_ONLY mode
				if LOY_ONLY and zone.id in CUSTOM_ZONE_IDS:
					fname = dir.get_next()
					continue
				zones.append(zone)
		fname = dir.get_next()
	return zones

func _apply_map_file(zone) -> void:
	var map_name = ZONE_MAP_FILES[zone.id]
	var path = MAPS_DIR + map_name + ".txt"
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("  No map file: " + path)
		return

	var content = file.get_as_text()
	file.close()

	var lines = content.split(";")
	# Clean lines
	var clean_lines: Array[String] = []
	for line in lines:
		clean_lines.append(line.strip_edges(true, false).replace("\n", "").replace("\r", ""))

	# Find "end" marker to skip header definitions
	var data_start = 0
	for i in range(clean_lines.size()):
		if clean_lines[i].begins_with("end"):
			data_start = i + 1
			break

	var offset = zone_offsets[zone.id]
	var ox = offset.x
	var oy = offset.y
	var tileset = zone.tileset

	var tiles_placed = 0
	for row_idx in range(data_start, clean_lines.size()):
		var y = row_idx - data_start
		if y >= zone.height:
			break
		var line = clean_lines[row_idx]
		for x in range(mini(line.length(), zone.width)):
			var c = line[x]
			if not CHAR_TO_TILE.has(c):
				continue
			var tile_id = CHAR_TO_TILE[c]
			if tile_id == 0:  # NOTHING
				continue

			var sprite = _get_sprite(tile_id, tileset)

			# Place SCALE x SCALE block for each source tile
			for sx in range(SCALE):
				for sy in range(SCALE):
					var pos = Vector2i(ox + x * SCALE + sx, oy + y * SCALE + sy)
					_place_tile(pos, tile_id, sprite, tileset)
			tiles_placed += 1

	print("  Map " + zone.id + ": " + str(tiles_placed) + " tiles (" + str(tiles_placed * SCALE * SCALE) + " placed) from " + map_name + ".txt")

func _place_tile(pos: Vector2i, tile_id: int, sprite: Vector2i, _tileset: int) -> void:
	# Route tiles to appropriate layers
	match tile_id:
		10:  # WATER
			water_layer.set_cell(pos, 0, sprite)
		11:  # LAVA
			water_layer.set_cell(pos, 0, sprite)
		12:  # POISON
			water_layer.set_cell(pos, 0, sprite)
		62, 65, 66, 68, 70:  # Trees (TREE, DEAD_TREE, JUNGLE_TREE, SNOW_TREE, PALM)
			decorations.set_cell(pos, 0, sprite)
		64, 63:  # ROUGH_STONE, ROUGH
			decorations.set_cell(pos, 0, sprite)
		51:  # CACTUS
			decorations.set_cell(pos, 0, sprite)
		67:  # WELL
			decorations.set_cell(pos, 0, sprite)
		5, 8, 13:  # WALL, SIDE_WALL, EXIT
			buildings.set_cell(pos, 0, sprite)
		3, 4:  # CLOSED_DOOR, OPEN_DOOR
			buildings.set_cell(pos, 0, sprite)
		7:  # FENCE
			fences_layer.set_cell(pos, 0, sprite)
		6:  # STAIRS_DOWN
			buildings.set_cell(pos, 0, sprite)
		9:  # TILED_FLOOR
			ground.set_cell(pos, 0, sprite)
		15, 14:  # BRIDGE tiles
			paths_layer.set_cell(pos, 0, sprite)
		22:  # STAIRS_UP
			buildings.set_cell(pos, 0, sprite)
		23, 24:  # GATE_H, GATE_V
			fences_layer.set_cell(pos, 0, sprite)
		25, 26, 27, 28, 29:  # Ship tiles
			buildings.set_cell(pos, 0, sprite)
		30:  # PLOWED
			ground.set_cell(pos, 0, sprite)
		_:
			if tile_id >= 52 and tile_id <= 61:  # Graves
				decorations.set_cell(pos, 0, sprite)

func _apply_zone_xml(zone) -> void:
	# Read the XML for this zone to get setTile, houses, closeEdge, trees, graves
	var xml_path = ZONES_DIR + zone.id + ".xml"
	var file = FileAccess.open(xml_path, FileAccess.READ)
	if not file:
		print("  No XML: " + xml_path)
		return
	var content = file.get_as_text()
	file.close()

	var offset = zone_offsets[zone.id]
	var ox = offset.x
	var oy = offset.y
	var tileset = zone.tileset

	# closeEdge: add fence border
	if content.find('closeEdge="true"') >= 0:
		_apply_close_edge(zone)

	# Parse setTile elements
	_parse_set_tiles(content, ox, oy, tileset)

	# Parse houses
	_parse_houses(content, ox, oy, tileset)

	# Parse trees (pass zone_id for overrides)
	_parse_trees(content, ox, oy, tileset, zone.id)

	# Parse graves
	_parse_graves(content, ox, oy, tileset)

	# Parse center (dungeon entrance)
	_parse_centers(content, ox, oy, tileset)

func _apply_close_edge(zone) -> void:
	var offset = zone_offsets[zone.id]
	var ox = offset.x
	var oy = offset.y
	var w = zone.width * SCALE
	var h = zone.height * SCALE
	var tileset = zone.tileset
	var fence_sprite = _get_sprite(7, tileset)
	var wall_sprite = _get_sprite(5, tileset)

	# Get exit positions (scaled) to leave wider gaps for transition corridors
	var exit_rects: Array = []
	for exit_data in zone.exits:
		var ex = int(exit_data["x"]) * SCALE
		var ey = int(exit_data["y"]) * SCALE
		# Leave a gap wider than 1 tile so the corridor connects smoothly
		exit_rects.append(Rect2i(ex - 2, ey - 2, SCALE + 4, SCALE + 4))

	for x in range(w):
		for y in range(h):
			if x > 0 and x < w-1 and y > 0 and y < h-1:
				continue  # Not edge

			var pos = Vector2i(ox + x, oy + y)

			# Check if this is within an exit gap
			var is_exit = false
			for er in exit_rects:
				if er.has_point(Vector2i(x, y)):
					is_exit = true
					break
			if is_exit:
				continue

			# Just fences around the border (1 tile, not scaled thick)
			if (x == 0 or x == w-1) and (y == 0 or y == h-1):
				buildings.set_cell(pos, 0, wall_sprite)
			else:
				fences_layer.set_cell(pos, 0, fence_sprite)

func _parse_set_tiles(content: String, ox: int, oy: int, tileset: int) -> void:
	# Parse <setTile tile="NAME" x="N" y="N" /> and area versions with width/height
	var idx = 0
	while true:
		var start = content.find("<setTile", idx)
		if start < 0:
			break
		var end = content.find(">", start) + 1
		if end <= 0:
			break
		var tag = content.substr(start, end - start)
		idx = end

		var tile_name = _get_attr(tag, "tile")
		var x = _get_attr_int(tag, "x")
		var y = _get_attr_int(tag, "y")
		var w = _get_attr_int(tag, "width", 1)
		var h = _get_attr_int(tag, "height", 1)

		if not TILE_NAMES.has(tile_name):
			continue

		var tile_id = TILE_NAMES[tile_name]
		var sprite = _get_sprite(tile_id, tileset)

		for dx in range(w):
			for dy in range(h):
				# Structural tiles (walls, fences, doors, stairs) stay 1x
				if tile_id in [3, 4, 5, 6, 7, 8, 13, 22, 23, 24]:
					var pos = Vector2i(ox + (x + dx) * SCALE, oy + (y + dy) * SCALE)
					_place_tile(pos, tile_id, sprite, tileset)
				else:
					# Terrain tiles get scaled
					for sx in range(SCALE):
						for sy in range(SCALE):
							var pos = Vector2i(ox + (x + dx) * SCALE + sx, oy + (y + dy) * SCALE + sy)
							_place_tile(pos, tile_id, sprite, tileset)

func _parse_houses(content: String, ox: int, oy: int, tileset: int) -> void:
	var idx = 0
	while true:
		var start = content.find("<house", idx)
		if start < 0:
			break
		var end = content.find(">", start) + 1
		if end <= 0:
			break
		var tag = content.substr(start, end - start)
		idx = end

		var hx = _get_attr_int(tag, "x")
		var hy = _get_attr_int(tag, "y")
		var hw = _get_attr_int(tag, "width")
		var hh = _get_attr_int(tag, "height")
		var dx_dir = _get_attr_int(tag, "dx", 0)
		var dy_dir = _get_attr_int(tag, "dy", 0)

		var wall_sprite = _get_sprite(5, tileset)
		var side_wall_sprite = _get_sprite(8, tileset)
		var tiled_sprite = _get_sprite(9, tileset)
		var door_sprite = _get_sprite(3, tileset)

		# Paint house at 1x size but at scaled position
		# Center the 1x building within the scaled area
		var shx = hx * SCALE + (SCALE - 1) * hw / 2
		var shy = hy * SCALE + (SCALE - 1) * hh / 2

		# Tiled floor under and around the house (scaled area)
		for x in range(hw * SCALE):
			for y in range(hh * SCALE):
				ground.set_cell(Vector2i(ox + hx * SCALE + x, oy + hy * SCALE + y), 0, tiled_sprite)

		# Build house at original 1x size
		# Left and right walls
		for y in range(hh):
			buildings.set_cell(Vector2i(ox + shx, oy + shy + y), 0, side_wall_sprite)
			buildings.set_cell(Vector2i(ox + shx + hw - 1, oy + shy + y), 0, side_wall_sprite)

		# Top and bottom walls
		for x in range(1, hw - 1):
			buildings.set_cell(Vector2i(ox + shx + x, oy + shy), 0, wall_sprite)
			buildings.set_cell(Vector2i(ox + shx + x, oy + shy + hh - 1), 0, wall_sprite)

		# Door
		if dx_dir == 1:
			buildings.set_cell(Vector2i(ox + shx + hw - 1, oy + shy + hh / 2), 0, door_sprite)
		elif dx_dir == -1:
			buildings.set_cell(Vector2i(ox + shx, oy + shy + hh / 2), 0, door_sprite)
		elif dy_dir == 1:
			buildings.set_cell(Vector2i(ox + shx + hw / 2, oy + shy + hh - 1), 0, door_sprite)
		elif dy_dir == -1:
			buildings.set_cell(Vector2i(ox + shx + hw / 2, oy + shy), 0, door_sprite)

func _parse_trees(content: String, ox: int, oy: int, tileset: int, zone_id: String = "") -> void:
	# Check zone override — skip entirely if density is 0
	if ZONE_TREE_OVERRIDES.has(zone_id) and ZONE_TREE_OVERRIDES[zone_id] <= 0.0:
		return

	var override_density = -1.0
	if ZONE_TREE_OVERRIDES.has(zone_id):
		override_density = ZONE_TREE_OVERRIDES[zone_id]

	var idx = 0
	while true:
		var start = content.find("<trees", idx)
		if start < 0:
			break
		var end = content.find(">", start) + 1
		if end <= 0:
			break
		var tag = content.substr(start, end - start)
		idx = end

		if tag.find("</") >= 0 or tag.find("setTile") >= 0:
			continue

		var tx = _get_attr_int(tag, "x")
		var ty = _get_attr_int(tag, "y")
		var tw = _get_attr_int(tag, "width")
		var th = _get_attr_int(tag, "height")
		var tile_attr = _get_attr(tag, "tile")

		var tree_tile_id = 62  # Default TREE
		if tile_attr != "" and TILE_NAMES.has(tile_attr):
			tree_tile_id = TILE_NAMES[tile_attr]

		var tree_sprite = _get_sprite(tree_tile_id, tileset)

		# Use override density if available, otherwise reduced base density
		var tree_density = override_density if override_density >= 0 else 0.15 / SCALE
		for x in range(tx * SCALE, (tx + tw) * SCALE):
			for y in range(ty * SCALE, (ty + th) * SCALE):
				if randf() > tree_density:
					continue
				var pos = Vector2i(ox + x, oy + y)
				if buildings.get_cell_source_id(pos) == -1 and decorations.get_cell_source_id(pos) == -1:
					decorations.set_cell(pos, 0, tree_sprite)

func _parse_graves(content: String, ox: int, oy: int, _tileset: int) -> void:
	var idx = 0
	while true:
		var start = content.find("<graves", idx)
		if start < 0:
			break
		var end = content.find(">", start) + 1
		if end <= 0:
			break
		var tag = content.substr(start, end - start)
		idx = end

		var gx = _get_attr_int(tag, "x")
		var gy = _get_attr_int(tag, "y")
		var gw = _get_attr_int(tag, "width")
		var gh = _get_attr_int(tag, "height")

		# Graves at every 2nd x, every 3rd y — 1x at scaled positions
		for x in range(gx, gx + gw, 2):
			for y in range(gy, gy + gh, 3):
				var grave_idx = 52 + ((x + y) % 10)
				if grave_idx > 61:
					grave_idx = 52
				var sprite = _get_sprite(grave_idx, 0)  # Graves are non-themed
				decorations.set_cell(Vector2i(ox + x * SCALE, oy + y * SCALE), 0, sprite)

func _parse_centers(content: String, ox: int, oy: int, tileset: int) -> void:
	var idx = 0
	while true:
		var start = content.find("<center", idx)
		if start < 0:
			break
		var end = content.find(">", start) + 1
		if end <= 0:
			break
		var tag = content.substr(start, end - start)
		idx = end

		if tag.find("/center") >= 0 or tag.find("center>") < 0:
			# Might be just opening tag, that's ok
			pass

		var cx = _get_attr_int(tag, "x")
		var cy = _get_attr_int(tag, "y")

		# Center = dungeon entrance. Build a small structure around the stairs.
		var tiled_sprite = _get_sprite(9, tileset)
		var stairs_sprite = _get_sprite(6, tileset)
		var wall_sprite = _get_sprite(5, tileset)
		var fence_sprite = _get_sprite(7, tileset)

		var scx = ox + cx * SCALE
		var scy = oy + cy * SCALE

		# Tiled floor platform around the stairs
		var pad = SCALE + 1
		for dx in range(-pad, pad + 1):
			for dy in range(-pad, pad + 1):
				var pos = Vector2i(scx + dx, scy + dy)
				ground.set_cell(pos, 0, tiled_sprite)
				decorations.erase_cell(pos)

		# Fence border around the platform (with gap at south for entry)
		for dx in range(-pad - 1, pad + 2):
			for dy in range(-pad - 1, pad + 2):
				if dx > -pad - 1 and dx < pad + 1 and dy > -pad - 1 and dy < pad + 1:
					continue  # Interior
				# Leave south entry gap
				if dy == pad + 1 and abs(dx) <= 1:
					continue
				var pos = Vector2i(scx + dx, scy + dy)
				if buildings.get_cell_source_id(pos) == -1:
					fences_layer.set_cell(pos, 0, fence_sprite)

		# Stairs at center
		buildings.set_cell(Vector2i(scx, scy), 0, stairs_sprite)

func _fill_void_regions() -> void:
	# Find bounding box of all ground tiles
	var cells = ground.get_used_cells()
	if cells.is_empty():
		return

	var min_x = 999999
	var min_y = 999999
	var max_x = -999999
	var max_y = -999999
	for cell in cells:
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_x = maxi(max_x, cell.x)
		max_y = maxi(max_y, cell.y)

	# Build zone bounding boxes for "inside world" check
	var zone_rects: Array = []
	for zone_id in zone_offsets:
		var off = zone_offsets[zone_id]
		# We need zone dimensions — estimate from offset spread
		zone_rects.append(Rect2i(off.x, off.y, 200 * SCALE, 200 * SCALE))

	# Default grass/tree sprites (tileset 112 = town theme)
	var grass_sprite = _get_sprite(1, 112)  # floor/grass
	var tree_sprite = _get_sprite(62, 112)  # tree

	# Expand bounds for outer void border
	var pad = 10
	min_x -= pad
	min_y -= pad
	max_x += pad
	max_y += pad

	var void_source_id = 1
	var void_black = Vector2i(15, 0)
	var stars_1 = Vector2i(3, 17)
	var stars_2 = Vector2i(3, 18)

	var grass_filled = 0
	var void_filled = 0
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var pos = Vector2i(x, y)
			if ground.get_cell_source_id(pos) != -1:
				continue  # Already has ground

			# Check if this tile is BETWEEN zones (inside the world)
			# Simple heuristic: check if nearby tiles have ground
			var near_ground = false
			for check_dist in [5, 15, 30]:
				for check_dir in [Vector2i(check_dist, 0), Vector2i(-check_dist, 0),
								  Vector2i(0, check_dist), Vector2i(0, -check_dist)]:
					if ground.get_cell_source_id(pos + check_dir) == 0:  # source 0 = LoY tileset
						near_ground = true
						break
				if near_ground:
					break

			if near_ground:
				# Fill with grass + scattered trees using proper pseudo-random
				ground.set_cell(pos, 0, grass_sprite)
				# Use bit-mixing hash to avoid diagonal patterns
				var h = ((x * 374761393) ^ (y * 668265263)) & 0x7FFFFFFF
				if (h % 100) < 3:
					decorations.set_cell(pos, 0, tree_sprite)
				grass_filled += 1
			else:
				# Outer void
				var tile = void_black
				var hash_val = (x * 7 + y * 13) % 100
				if hash_val < 8:
					tile = stars_1
				elif hash_val < 14:
					tile = stars_2
				ground.set_cell(pos, void_source_id, tile)
				void_filled += 1

	print("Gap fill: " + str(grass_filled) + " grass tiles, " + str(void_filled) + " void tiles")

func _apply_tile_overrides(zone) -> void:
	var offset = zone_offsets[zone.id]
	var count = 0
	for key in zone.tile_overrides:
		var sprite_idx = int(zone.tile_overrides[key])
		var parts = key.split(",")
		if parts.size() != 2:
			continue
		var lx = int(parts[0])
		var ly = int(parts[1])
		# Each LoY tile maps to SCALE x SCALE output tiles
		var atlas = sa(sprite_idx)
		for dx in range(SCALE):
			for dy in range(SCALE):
				var pos = Vector2i(offset.x + lx * SCALE + dx, offset.y + ly * SCALE + dy)
				# Place on ground layer (overrides whatever was there)
				ground.set_cell(pos, 0, atlas)
				# Clear upper layers so override is visible
				decorations.erase_cell(pos)
				buildings.erase_cell(pos)
				fences_layer.erase_cell(pos)
		count += 1
	if count > 0:
		print("  tile_overrides: " + zone.id + " → " + str(count) + " tiles")

func _draw_zone_connections(zone, zone_map: Dictionary) -> void:
	# Draw wide natural transition corridors between connected zones
	if not zone_offsets.has(zone.id):
		return
	var src_offset = zone_offsets[zone.id]

	for exit_data in zone.exits:
		var target_id = str(exit_data["target"])
		if not zone_offsets.has(target_id):
			continue
		if not zone_map.has(target_id):
			continue

		var tgt_offset = zone_offsets[target_id]

		# Exit/target positions in scaled coordinates
		var src_x = src_offset.x + int(exit_data["x"]) * SCALE
		var src_y = src_offset.y + int(exit_data["y"]) * SCALE
		var dst_x = tgt_offset.x + int(exit_data["tx"]) * SCALE
		var dst_y = tgt_offset.y + int(exit_data["ty"]) * SCALE

		var dist = abs(src_x - dst_x) + abs(src_y - dst_y)
		if dist <= SCALE:
			continue

		var floor_sprite = _get_sprite(1, zone.tileset)
		var path_sprite = _get_sprite(9, zone.tileset)
		var tree_sprite = _get_sprite(62, zone.tileset)

		# Wide corridor: 8 tiles wide path with tree borders
		var PATH_HALF = 4  # 4 tiles each side of center = 9 wide walkable area

		# Build L-shaped center path
		var path_points: Array[Vector2i] = []
		var cx = src_x
		var cy = src_y
		var step_x = 0 if cx == dst_x else (1 if dst_x > cx else -1)
		var step_y = 0 if cy == dst_y else (1 if dst_y > cy else -1)

		path_points.append(Vector2i(cx, cy))
		while cx != dst_x:
			cx += step_x
			path_points.append(Vector2i(cx, cy))
		while cy != dst_y:
			cy += step_y
			path_points.append(Vector2i(cx, cy))

		for i in range(path_points.size()):
			var pt = path_points[i]
			var is_horizontal = true
			if i > 0 and path_points[i - 1].x == pt.x:
				is_horizontal = false
			elif i < path_points.size() - 1 and path_points[i + 1].x == pt.x:
				is_horizontal = false

			# Paint wide walkable area
			for offset in range(-PATH_HALF, PATH_HALF + 1):
				var road_pos: Vector2i
				if is_horizontal:
					road_pos = Vector2i(pt.x, pt.y + offset)
				else:
					road_pos = Vector2i(pt.x + offset, pt.y)

				# Center 2 tiles = tiled road, rest = grass floor
				if abs(offset) <= 1:
					ground.set_cell(road_pos, 0, path_sprite)
				else:
					ground.set_cell(road_pos, 0, floor_sprite)
				decorations.erase_cell(road_pos)
				fences_layer.erase_cell(road_pos)
				buildings.erase_cell(road_pos)

			# Scatter trees in the border zone (3 tiles beyond path edge)
			for side in [-1, 1]:
				for b in range(1, 4):
					var border_offset = (PATH_HALF + b) * side
					var border_pos: Vector2i
					if is_horizontal:
						border_pos = Vector2i(pt.x, pt.y + border_offset)
					else:
						border_pos = Vector2i(pt.x + border_offset, pt.y)

					if ground.get_cell_source_id(border_pos) == -1:
						ground.set_cell(border_pos, 0, floor_sprite)
						var h = ((border_pos.x * 374761393) ^ (border_pos.y * 668265263)) & 0x7FFFFFFF
						var tree_chance = 8 + 8 * b
						if (h % 100) < tree_chance:
							decorations.set_cell(border_pos, 0, tree_sprite)

func _get_attr(tag: String, attr_name: String) -> String:
	# Search for ' attr="value"' with space prefix to avoid matching substrings
	# e.g. searching for "x" should NOT match "dx" or "targetX"
	var search = " " + attr_name + '="'
	var start = tag.find(search)
	if start < 0:
		return ""
	start += search.length()
	var end = tag.find('"', start)
	if end < 0:
		return ""
	return tag.substr(start, end - start)

func _get_attr_int(tag: String, attr_name: String, default_val: int = 0) -> int:
	var val = _get_attr(tag, attr_name)
	if val == "":
		return default_val
	return int(val)

func _create_loy_tileset() -> TileSet:
	var ts = TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_SQUARE
	ts.tile_size = Vector2i(32, 32)

	# Source 0: LoY maptiles (32x32, 16x16 grid)
	var source = TileSetAtlasSource.new()
	source.texture = load("res://assets/sprites/loy/maptiles.png") as Texture2D
	source.texture_region_size = Vector2i(32, 32)
	for col in range(16):
		for row in range(16):
			source.create_tile(Vector2i(col, row))
	ts.add_source(source)  # source_id = 0

	# Source 1: Upscaled environment tileset (32x32, 16x26 grid)
	# Contains void_black at (15,0), stars_1 at (3,17), stars_2 at (3,18)
	var env_source = TileSetAtlasSource.new()
	var env_tex = load("res://assets/sprites/lofiEnvironment_32.png") as Texture2D
	if env_tex:
		env_source.texture = env_tex
		env_source.texture_region_size = Vector2i(32, 32)
		var tex_size = env_tex.get_size()
		var cols = int(tex_size.x) / 32
		var rows = int(tex_size.y) / 32
		for col in range(cols):
			for row in range(rows):
				env_source.create_tile(Vector2i(col, row))
		ts.add_source(env_source)  # source_id = 1
		print("Added environment tileset (32x32): " + str(cols) + "x" + str(rows))

	return ts

# ─── Post-process specific zones ───────────────────────────────────────────

func _post_process_zones(zone_map: Dictionary) -> void:
	if zone_offsets.has("aria"):
		_enhance_aria(zone_map.get("aria"))
	if zone_offsets.has("aria-g"):
		_enhance_graveyard(zone_map.get("aria-g"))
	if zone_offsets.has("farm"):
		_enhance_farm(zone_map.get("farm"))
	if zone_offsets.has("camp"):
		_enhance_camp(zone_map.get("camp"))

func _clear_interior_trees(zone, edge_keep: int = 3) -> int:
	# Remove gap-fill trees from zone INTERIOR only, preserving edge border trees
	# edge_keep: how many SCALE-units from edge to preserve (map file border trees)
	var off = zone_offsets[zone.id]
	var w = zone.width * SCALE
	var h = zone.height * SCALE
	var border = edge_keep * SCALE
	var cleared = 0
	var tree_sprites = [
		_get_sprite(62, zone.tileset),   # TREE
		_get_sprite(66, zone.tileset),   # JUNGLE_TREE
		_get_sprite(68, zone.tileset),   # SNOW_TREE
		_get_sprite(70, zone.tileset),   # PALM
		_get_sprite(62, 112),            # Town tree (gap fill)
	]
	for x in range(border, w - border):
		for y in range(border, h - border):
			var pos = Vector2i(off.x + x, off.y + y)
			if decorations.get_cell_source_id(pos) == 0:
				var atlas = decorations.get_cell_atlas_coords(pos)
				if atlas in tree_sprites:
					decorations.erase_cell(pos)
					cleared += 1
	return cleared

func _clear_all_trees(zone, margin: int = 0) -> int:
	# Remove ALL trees including border (for zones that draw their own walls)
	var off = zone_offsets[zone.id]
	var w = zone.width * SCALE
	var h = zone.height * SCALE
	var cleared = 0
	var tree_sprites = [
		_get_sprite(62, zone.tileset), _get_sprite(66, zone.tileset),
		_get_sprite(68, zone.tileset), _get_sprite(70, zone.tileset),
		_get_sprite(62, 112),
	]
	for x in range(-margin, w + margin):
		for y in range(-margin, h + margin):
			var pos = Vector2i(off.x + x, off.y + y)
			if decorations.get_cell_source_id(pos) == 0:
				var atlas = decorations.get_cell_atlas_coords(pos)
				if atlas in tree_sprites:
					decorations.erase_cell(pos)
					cleared += 1
	return cleared

func _draw_path(x1: int, y1: int, x2: int, y2: int, tileset: int, width: int = 3) -> void:
	var tiled = _get_sprite(9, tileset)
	var half = width / 2
	var cx = x1
	var cy = y1
	var step_x = 0 if cx == x2 else (1 if x2 > cx else -1)
	var step_y = 0 if cy == y2 else (1 if y2 > cy else -1)
	while cx != x2:
		for w in range(-half, half + 1):
			var pos = Vector2i(cx, cy + w)
			if buildings.get_cell_source_id(pos) == -1:
				ground.set_cell(pos, 0, tiled)
				decorations.erase_cell(pos)
		cx += step_x
	while cy != y2:
		for w in range(-half, half + 1):
			var pos = Vector2i(cx + w, cy)
			if buildings.get_cell_source_id(pos) == -1:
				ground.set_cell(pos, 0, tiled)
				decorations.erase_cell(pos)
		cy += step_y

func _build_house(bx: int, by: int, bw: int, bh: int, door_side: String, tileset: int) -> void:
	# Build a proper wall-and-door house at absolute tile coords
	var wall = _get_sprite(5, tileset)
	var side_wall = _get_sprite(8, tileset)
	var door = _get_sprite(3, tileset)
	var tiled = _get_sprite(9, tileset)

	# Tiled floor under and around the house
	for x in range(-1, bw + 1):
		for y in range(-1, bh + 1):
			var pos = Vector2i(bx + x, by + y)
			ground.set_cell(pos, 0, tiled)
			decorations.erase_cell(pos)

	# Side walls (left and right)
	for y in range(bh):
		buildings.set_cell(Vector2i(bx, by + y), 0, side_wall)
		buildings.set_cell(Vector2i(bx + bw - 1, by + y), 0, side_wall)
	# Top and bottom walls
	for x in range(1, bw - 1):
		buildings.set_cell(Vector2i(bx + x, by), 0, wall)
		buildings.set_cell(Vector2i(bx + x, by + bh - 1), 0, wall)
	# Door
	match door_side:
		"south":
			buildings.set_cell(Vector2i(bx + bw / 2, by + bh - 1), 0, door)
		"north":
			buildings.set_cell(Vector2i(bx + bw / 2, by), 0, door)
		"east":
			buildings.set_cell(Vector2i(bx + bw - 1, by + bh / 2), 0, door)
		"west":
			buildings.set_cell(Vector2i(bx, by + bh / 2), 0, door)

func _enhance_aria(zone) -> void:
	if not zone:
		return
	var off = zone_offsets["aria"]
	var ox = off.x
	var oy = off.y
	var w = zone.width * SCALE   # 100 at 4x
	var h = zone.height * SCALE  # 100 at 4x
	var ts = zone.tileset  # 112

	# Aria has closeEdge=true so it gets fence border already. Clear interior trees only.
	var cleared = _clear_all_trees(zone, 3)
	print("  Aria: cleared " + str(cleared) + " trees")

	var tiled = _get_sprite(9, ts)
	var wall = _get_sprite(5, ts)
	var fence = _get_sprite(7, ts)
	var floor_s = _get_sprite(1, ts)
	var well_s = _get_sprite(67, ts)
	var tree_s = _get_sprite(62, ts)

	# --- Town walls (thick, with exit gaps) ---
	var exit_gaps: Array = []
	for exit_data in zone.exits:
		var ex = int(exit_data["x"]) * SCALE
		var ey = int(exit_data["y"]) * SCALE
		exit_gaps.append(Rect2i(ex - 4, ey - 4, SCALE + 8, SCALE + 8))

	for x in range(w):
		for y in range(h):
			if x > 2 and x < w - 3 and y > 2 and y < h - 3:
				continue
			var pos = Vector2i(ox + x, oy + y)
			var in_gap = false
			for er in exit_gaps:
				if er.has_point(Vector2i(x, y)):
					in_gap = true
					break
			if in_gap:
				continue
			if x <= 1 or x >= w - 2 or y <= 1 or y >= h - 2:
				buildings.set_cell(pos, 0, wall)
			else:
				fences_layer.set_cell(pos, 0, fence)

	# --- Paved town center (large plaza) ---
	var cx = w / 2
	var cy = h / 2
	var plaza_r = 14
	for x in range(cx - plaza_r, cx + plaza_r):
		for y in range(cy - plaza_r, cy + plaza_r):
			var pos = Vector2i(ox + x, oy + y)
			if buildings.get_cell_source_id(pos) == -1:
				ground.set_cell(pos, 0, tiled)

	# Well in center
	decorations.set_cell(Vector2i(ox + cx, oy + cy), 0, well_s)

	# --- Paths connecting exits to plaza ---
	_draw_path(ox + 11 * SCALE, oy + 3, ox + cx, oy + cy - plaza_r, ts)
	_draw_path(ox + 11 * SCALE, oy + h - 4, ox + cx, oy + cy + plaza_r, ts)
	_draw_path(ox + w - 4, oy + 21 * SCALE, ox + cx + plaza_r, oy + cy, ts)

	# --- NEW BUILDINGS (actual wall structures, not empty plots) ---
	# LoY original 4 buildings are placed by _parse_houses already:
	# Arnie's (2,2) 7x7, Town Hall (15,3) 9x8, Crooked Beak (3,13) 7x6, Shrowded Orb (17,15) 6x6
	# We add new buildings in the open spaces at 4x scale.

	# Militia Barracks — southwest area (below the inn)
	_build_house(ox + 4 * SCALE, oy + 20 * SCALE, 8, 6, "north", ts)

	# Market Hall — between Arnie's and Town Hall
	_build_house(ox + 10 * SCALE, oy + 3 * SCALE, 7, 5, "south", ts)

	# Herbalist Hut — east side, south of the east exit
	_build_house(ox + 20 * SCALE, oy + 16 * SCALE, 5, 5, "west", ts)

	# Guard Tower — near north exit
	_build_house(ox + 8 * SCALE, oy + 2 * SCALE, 4, 4, "south", ts)

	# Stables — southeast corner
	_build_house(ox + 19 * SCALE, oy + 21 * SCALE, 6, 5, "north", ts)

	# --- Shade trees (intentional landscaping) ---
	var tree_spots = [
		Vector2i(ox + cx - 16, oy + cy - 16),
		Vector2i(ox + cx + 15, oy + cy - 16),
		Vector2i(ox + cx - 16, oy + cy + 15),
		Vector2i(ox + cx + 15, oy + cy + 15),
		Vector2i(ox + 3 * SCALE, oy + 11 * SCALE),
		Vector2i(ox + 14 * SCALE, oy + 11 * SCALE),
		Vector2i(ox + 3 * SCALE, oy + 20 * SCALE - 2),
		Vector2i(ox + 14 * SCALE, oy + 20 * SCALE - 2),
	]
	for tpos in tree_spots:
		if buildings.get_cell_source_id(tpos) == -1:
			decorations.set_cell(tpos, 0, tree_s)

	# --- Gardens near buildings ---
	var flower_s = _get_sprite(69, ts)
	var garden_centers = [
		Vector2i(ox + 10 * SCALE, oy + 9 * SCALE),   # Between shops
		Vector2i(ox + 14 * SCALE, oy + 14 * SCALE),   # Central area
		Vector2i(ox + 6 * SCALE, oy + 19 * SCALE),    # Near barracks
	]
	for gc in garden_centers:
		for gx in range(4):
			for gy in range(4):
				var p = Vector2i(gc.x + gx, gc.y + gy)
				if buildings.get_cell_source_id(p) == -1 and decorations.get_cell_source_id(p) == -1:
					decorations.set_cell(p, 0, flower_s)

	print("  Aria: enhanced with walls, plaza, 5 new buildings, gardens")

func _enhance_graveyard(zone) -> void:
	if not zone:
		return
	var off = zone_offsets["aria-g"]
	var ox = off.x
	var oy = off.y
	var w = zone.width * SCALE   # 80 at 4x
	var h = zone.height * SCALE  # 120 at 4x
	var ts = zone.tileset  # 112

	# Graveyard has closeEdge=true. Clear all trees — we rebuild atmosphere.
	var cleared = _clear_all_trees(zone, 3)
	print("  Graveyard: cleared " + str(cleared) + " trees")

	var tiled = _get_sprite(9, ts)
	var fence = _get_sprite(7, ts)
	var tree_s = _get_sprite(62, ts)

	# --- Dense grave field in the south half (LoY y=16..29 was all trees, now empty) ---
	# Fill with grave rows + paths between sections
	for gy in range(16, 28):
		for gx in range(2, 18):
			# Skip path column down the middle (x=9..11)
			if gx >= 9 and gx <= 11:
				continue
			# Place grave every other tile in a staggered pattern
			if (gx + gy) % 2 == 0:
				var grave_id = 52 + ((gx * 3 + gy * 7) % 10)
				var grave_sprite = _get_sprite(grave_id, ts)
				# Place at center of each scaled cell
				for sx in range(SCALE):
					for sy in range(SCALE):
						var px = gx * SCALE + sx
						var py = gy * SCALE + sy
						var pos = Vector2i(ox + px, oy + py)
						if sx == SCALE / 2 and sy == SCALE / 2:
							if buildings.get_cell_source_id(pos) == -1:
								decorations.set_cell(pos, 0, grave_sprite)

	# --- Central path from entrance to crypt (wide cobblestone) ---
	_draw_path(ox + 10 * SCALE, oy + 2, ox + 10 * SCALE, oy + 24 * SCALE, ts, 5)

	# --- Cross paths between grave sections ---
	_draw_path(ox + 2 * SCALE, oy + 14 * SCALE, ox + 18 * SCALE, oy + 14 * SCALE, ts, 3)
	_draw_path(ox + 2 * SCALE, oy + 22 * SCALE, ox + 18 * SCALE, oy + 22 * SCALE, ts, 3)

	# --- Iron fence rows separating grave sections ---
	for fy in [15, 23]:
		for fx in range(2, 18):
			if fx >= 9 and fx <= 11:
				continue  # Gap for path
			for sx in range(SCALE):
				var pos = Vector2i(ox + fx * SCALE + sx, oy + fy * SCALE)
				if buildings.get_cell_source_id(pos) == -1:
					fences_layer.set_cell(pos, 0, fence)

	# --- Atmospheric dead trees along the edges ---
	var edge_trees = [
		# West edge
		Vector2i(ox + 1 * SCALE + 1, oy + 16 * SCALE),
		Vector2i(ox + 1 * SCALE + 1, oy + 20 * SCALE),
		Vector2i(ox + 1 * SCALE + 1, oy + 24 * SCALE),
		Vector2i(ox + 1 * SCALE + 1, oy + 27 * SCALE),
		# East edge
		Vector2i(ox + 18 * SCALE + 1, oy + 17 * SCALE),
		Vector2i(ox + 18 * SCALE + 1, oy + 21 * SCALE),
		Vector2i(ox + 18 * SCALE + 1, oy + 25 * SCALE),
		Vector2i(ox + 18 * SCALE + 1, oy + 28 * SCALE),
		# Scattered interior
		Vector2i(ox + 5 * SCALE, oy + 18 * SCALE),
		Vector2i(ox + 14 * SCALE, oy + 19 * SCALE),
		Vector2i(ox + 7 * SCALE, oy + 26 * SCALE),
		Vector2i(ox + 13 * SCALE, oy + 25 * SCALE),
	]
	for tpos in edge_trees:
		if buildings.get_cell_source_id(tpos) == -1:
			decorations.set_cell(tpos, 0, tree_s)

	# --- Small crypt building around the dungeon entrance (center at 10,24) ---
	_build_house(ox + 9 * SCALE - 1, oy + 23 * SCALE - 1, 6, 5, "north", ts)

	print("  Graveyard: dense graves, paths, fences, crypt building")

func _enhance_farm(zone) -> void:
	if not zone:
		return
	var off = zone_offsets["farm"]
	var ox = off.x
	var oy = off.y
	var w = zone.width * SCALE
	var h = zone.height * SCALE
	var ts = zone.tileset

	# Farm has closeEdge=false, relies on map file 'T' chars for tree border.
	# Only clear INTERIOR trees, keeping the border intact.
	var cleared = _clear_interior_trees(zone, 2)
	print("  Farm: cleared " + str(cleared) + " interior trees")

	var fence = _get_sprite(7, ts)
	var plowed = _get_sprite(30, ts)

	# --- Fenced animal pen near Mabion (pet handler at x=22, y=12) ---
	var pen_x = ox + 19 * SCALE
	var pen_y = ox + 10 * SCALE
	for x in range(5 * SCALE):
		for y in range(4 * SCALE):
			var pos = Vector2i(pen_x + x, off.y + 10 * SCALE + y)
			if buildings.get_cell_source_id(pos) != -1:
				continue
			if x == 0 or x == 5 * SCALE - 1 or y == 0 or y == 4 * SCALE - 1:
				fences_layer.set_cell(pos, 0, fence)

	# --- Extra plowed field patches in open south area ---
	for fy in range(20, 24):
		for fx in range(3, 12):
			for sx in range(SCALE):
				for sy in range(SCALE):
					var pos = Vector2i(ox + fx * SCALE + sx, off.y + fy * SCALE + sy)
					if buildings.get_cell_source_id(pos) == -1 and decorations.get_cell_source_id(pos) == -1:
						ground.set_cell(pos, 0, plowed)

	print("  Farm: enhanced with pen and fields")

func _enhance_camp(zone) -> void:
	if not zone:
		return
	var off = zone_offsets["camp"]
	var ox = off.x
	var oy = off.y
	var w = zone.width * SCALE
	var h = zone.height * SCALE
	var ts = zone.tileset

	# Camp has closeEdge=false, relies on map file 'T' borders.
	# Only clear interior trees.
	var cleared = _clear_interior_trees(zone, 2)
	print("  Camp: cleared " + str(cleared) + " interior trees")

	# --- Training yard (tiled floor) south of the building ---
	var tiled = _get_sprite(9, ts)
	var fence = _get_sprite(7, ts)
	var ty_x = 7 * SCALE
	var ty_y = 14 * SCALE
	var ty_w = 7 * SCALE
	var ty_h = 4 * SCALE

	# Tiled floor
	for x in range(ty_w):
		for y in range(ty_h):
			var pos = Vector2i(ox + ty_x + x, oy + ty_y + y)
			if buildings.get_cell_source_id(pos) == -1:
				ground.set_cell(pos, 0, tiled)
				decorations.erase_cell(pos)

	# Fence border
	for x in range(ty_w + 2):
		for y in range(ty_h + 2):
			if x > 0 and x < ty_w + 1 and y > 0 and y < ty_h + 1:
				continue
			var pos = Vector2i(ox + ty_x - 1 + x, oy + ty_y - 1 + y)
			if buildings.get_cell_source_id(pos) == -1:
				fences_layer.set_cell(pos, 0, fence)

	print("  Camp: enhanced with training yard")
