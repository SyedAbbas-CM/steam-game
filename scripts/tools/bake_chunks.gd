extends SceneTree

## Bake overworld tile data into chunk files + regenerate lightweight .scn
## Run: Godot --headless --script scripts/tools/bake_chunks.gd
##
## Flow:
##   1. Load overworld.tscn (the editable scene with all tiles)
##   2. Extract tiles into chunk .tres files
##   3. Strip tile data and save as overworld_light.tscn
##   4. Convert to overworld.scn (binary, tiny — used at runtime)
##
## After editing tiles in overworld.tscn, just run this one script.

const CHUNK_SIZE = 64

func _init() -> void:
	print("=== Baking overworld chunks ===")
	var t0 = Time.get_ticks_msec()

	# Always load from .tscn (the editable scene with all tile data)
	var scene_path = "res://scenes/overworld/overworld.tscn"
	if not ResourceLoader.exists(scene_path):
		print("ERROR: Could not find %s" % scene_path)
		quit()
		return
	print("Loading scene: %s" % scene_path)
	var t1 = Time.get_ticks_msec()
	var scene = load(scene_path) as PackedScene
	if not scene:
		print("ERROR: Could not load scene")
		quit()
		return
	print("Scene loaded in %d ms" % (Time.get_ticks_msec() - t1))

	t1 = Time.get_ticks_msec()
	var root = scene.instantiate()
	print("Scene instantiated in %d ms" % (Time.get_ticks_msec() - t1))

	# ── Step 1: Extract tiles into chunks ──
	var layer_names = ["Ground", "Paths", "Water", "Decorations", "Buildings", "Fences"]
	var chunks: Dictionary = {}  # chunk_key_str -> { layer_name -> PackedInt32Array }
	var total_tiles = 0

	for layer_name in layer_names:
		var layer = root.get_node_or_null(layer_name) as TileMapLayer
		if not layer:
			print("WARNING: Layer '%s' not found" % layer_name)
			continue
		t1 = Time.get_ticks_msec()
		var cells = layer.get_used_cells()
		print("Layer '%s': %d cells (got_used_cells in %d ms)" % [layer_name, cells.size(), Time.get_ticks_msec() - t1])

		var lname = layer_name.to_lower()
		for cell in cells:
			var cx = int(floor(float(cell.x) / CHUNK_SIZE))
			var cy = int(floor(float(cell.y) / CHUNK_SIZE))
			var key = "%d_%d" % [cx, cy]
			if not chunks.has(key):
				chunks[key] = {"cx": cx, "cy": cy}
			if not chunks[key].has(lname):
				chunks[key][lname] = PackedInt32Array()
			var source = layer.get_cell_source_id(cell)
			var atlas = layer.get_cell_atlas_coords(cell)
			chunks[key][lname].append(cell.x)
			chunks[key][lname].append(cell.y)
			chunks[key][lname].append(source)
			chunks[key][lname].append(atlas.x)
			chunks[key][lname].append(atlas.y)
			total_tiles += 1

	# ── Step 2: Save chunk files ──
	var chunk_dir = "res://resources/world/chunks/"
	DirAccess.make_dir_recursive_absolute(chunk_dir)

	# Delete old chunk files first
	var old_dir = DirAccess.open(chunk_dir)
	if old_dir:
		old_dir.list_dir_begin()
		var fname = old_dir.get_next()
		while fname != "":
			if fname.begins_with("chunk_") and fname.ends_with(".tres"):
				old_dir.remove(fname)
			fname = old_dir.get_next()

	t1 = Time.get_ticks_msec()
	for key in chunks:
		var data = chunks[key]
		var res = Resource.new()
		for prop in data:
			res.set_meta(prop, data[prop])
		var fname = "chunk_%s.tres" % key
		ResourceSaver.save(res, chunk_dir + fname)
	print("Saved %d chunk files in %d ms" % [chunks.size(), Time.get_ticks_msec() - t1])

	# Save index with timestamp
	var index = Resource.new()
	var keys: PackedStringArray = []
	for key in chunks:
		keys.append(key)
	index.set_meta("keys", keys)
	index.set_meta("chunk_size", CHUNK_SIZE)
	index.set_meta("bake_time", Time.get_unix_time_from_system())
	ResourceSaver.save(index, chunk_dir + "index.tres")

	root.free()

	# ── Step 3: Create lightweight .scn by stripping tile_map_data via text manipulation ──
	t1 = Time.get_ticks_msec()
	var tscn_path = ProjectSettings.globalize_path("res://scenes/overworld/overworld.tscn")
	var light_path = ProjectSettings.globalize_path("res://scenes/overworld/overworld_light.tscn")
	var f = FileAccess.open(tscn_path, FileAccess.READ)
	var fw = FileAccess.open(light_path, FileAccess.WRITE)
	if f and fw:
		while not f.eof_reached():
			var line = f.get_line()
			if line.begins_with("tile_map_data"):
				fw.store_line("tile_map_data = PackedByteArray()")
			else:
				fw.store_line(line)
		f.close()
		fw.close()
		print("Created lightweight .tscn in %d ms" % (Time.get_ticks_msec() - t1))

		# Convert to binary .scn
		t1 = Time.get_ticks_msec()
		var light_scene = load("res://scenes/overworld/overworld_light.tscn") as PackedScene
		if light_scene:
			ResourceSaver.save(light_scene, "res://scenes/overworld/overworld.scn")
			print("Saved binary .scn in %d ms" % (Time.get_ticks_msec() - t1))
		else:
			print("WARNING: Could not load light scene for .scn conversion")
	else:
		print("ERROR: Could not read/write scene files")

	print("=== DONE: Baked %d chunks (%d total tiles) in %d ms ===" % [chunks.size(), total_tiles, Time.get_ticks_msec() - t0])
	print("Runtime scene: scenes/overworld/overworld.scn")
	print("Edit scene:    scenes/overworld/overworld.tscn")
	quit()
