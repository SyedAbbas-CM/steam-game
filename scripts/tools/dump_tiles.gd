extends SceneTree
## Run: godot --headless --script res://scripts/tools/dump_tiles.gd

func _init() -> void:
	var scene = load("res://scenes/samples/sample_rooms.tscn").instantiate()
	root.add_child(scene)

	# Wait one frame for @tool _ready to fire
	await process_frame
	await process_frame

	var floor_layer: TileMapLayer = scene.get_node("Floor")
	var deco_layer: TileMapLayer = scene.get_node("Decorations")

	# User painted room starts at x=120 (gen_ox from sample_rooms.gd)
	# elite_ox = 4*(17+3) = 80 (empty room for user to paint)
	# gen_ox = 80 + 37 + 3 = 120 (AI generated room that user painted OVER)
	var user_ox = 120
	var w = 37
	var h = 31

	var output = ""
	output += "=== USER PAINTED ROOM (local coords, origin subtracted) ===\n"
	output += _dump_region(deco_layer, "DECO", user_ox, 0, w, h, false)
	output += _dump_region(floor_layer, "FLOOR_SRC1", user_ox, 0, w, h, true)

	# Also check if user painted on the empty room (elite_ox=80)
	var empty_ox = 80
	output += "\n=== EMPTY ROOM CHECK (elite_ox=80) ===\n"
	output += _dump_region(deco_layer, "DECO", empty_ox, 0, w, h, false)
	output += _dump_region(floor_layer, "FLOOR_SRC1", empty_ox, 0, w, h, true)

	var file = FileAccess.open("res://dump_tiles_output.txt", FileAccess.WRITE)
	file.store_string(output)
	file.close()
	print(output)
	print("Output saved to res://dump_tiles_output.txt")
	quit()

func _dump_region(layer: TileMapLayer, label: String, ox: int, oy: int, w: int, h: int, source1_only: bool) -> String:
	var result = "\n--- %s layer ---\n" % label
	var cells = layer.get_used_cells()
	var relevant: Array[Dictionary] = []
	for cell in cells:
		if cell.x >= ox and cell.x < ox + w and cell.y >= oy and cell.y < oy + h:
			var src = layer.get_cell_source_id(cell)
			var atlas = layer.get_cell_atlas_coords(cell)
			if source1_only and src != 1:
				continue
			if not source1_only and src == 0:
				continue
			var local_x = cell.x - ox
			var local_y = cell.y - oy
			relevant.append({"lx": local_x, "ly": local_y, "src": src, "ax": atlas.x, "ay": atlas.y})

	relevant.sort_custom(func(a, b):
		if a.ly != b.ly: return a.ly < b.ly
		return a.lx < b.lx
	)

	for r in relevant:
		result += "  pos(%d,%d) -> source %d, atlas(%d,%d)\n" % [r.lx, r.ly, r.src, r.ax, r.ay]

	if relevant.is_empty():
		result += "  (no tiles)\n"
	return result
