@tool
extends EditorScript
## Run via Editor > Run Script to dump tile positions from sample_rooms.tscn

func _run() -> void:
	var scene = load("res://scenes/samples/sample_rooms.tscn").instantiate()

	var floor_layer: TileMapLayer = scene.get_node("Floor")
	var walls_layer: TileMapLayer = scene.get_node("Walls")
	var deco_layer: TileMapLayer = scene.get_node("Decorations")
	var door_layer: TileMapLayer = scene.get_node("Doors")

	# Find the decorated super elite room (6th room = gen_ox)
	# From sample_rooms.gd: gen_ox = 4 * (17+3) + 37 + 3 = 80 + 40 = 120
	# Actually: elite_ox = 4 * (17+3) = 80, gen_ox = 80 + 37 + 3 = 120
	var gen_ox = 120
	var elite_ox = 80  # The manual/user-painted room

	print("=== USER PAINTED ROOM (origin x=80, 37x31) ===")
	_dump_layer_region(deco_layer, "DECO", elite_ox, 0, 37, 31)
	_dump_layer_region(floor_layer, "FLOOR_SOURCE1", elite_ox, 0, 37, 31, true)

	print("\n=== AI GENERATED ROOM (origin x=120, 37x31) ===")
	_dump_layer_region(deco_layer, "DECO", gen_ox, 0, 37, 31)
	_dump_layer_region(floor_layer, "FLOOR_SOURCE1", gen_ox, 0, 37, 31, true)

	scene.queue_free()

func _dump_layer_region(layer: TileMapLayer, label: String, ox: int, oy: int, w: int, h: int, source1_only: bool = false) -> void:
	print("\n--- %s layer ---" % label)
	var cells = layer.get_used_cells()
	var relevant: Array[Dictionary] = []
	for cell in cells:
		if cell.x >= ox and cell.x < ox + w and cell.y >= oy and cell.y < oy + h:
			var src = layer.get_cell_source_id(cell)
			var atlas = layer.get_cell_atlas_coords(cell)
			if source1_only and src != 1:
				continue
			if not source1_only and src == 0:
				continue  # Skip base floor/wall tiles for deco dump
			var local_x = cell.x - ox
			var local_y = cell.y - oy
			relevant.append({"lx": local_x, "ly": local_y, "src": src, "ax": atlas.x, "ay": atlas.y})

	# Sort by y then x for readability
	relevant.sort_custom(func(a, b):
		if a.ly != b.ly: return a.ly < b.ly
		return a.lx < b.lx
	)

	for r in relevant:
		print("  pos(%d,%d) -> source %d, atlas(%d,%d)" % [r.lx, r.ly, r.src, r.ax, r.ay])

	if relevant.is_empty():
		print("  (no tiles)")
