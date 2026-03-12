extends SceneTree

## Rebuild overworld2.tscn tile data FROM chunks2/ .tres files.
## This is the overworld2 variant of chunks_to_tscn.gd — it reads chunks2/
## and writes tiles into overworld2.tscn so the Godot editor shows the current state.
##
## Also creates overworld2.scn (no tile data) for fast runtime loading.
##
## Run: Godot --headless --script scripts/tools/chunks2_to_tscn.gd

func _init() -> void:
	print("=== Rebuilding overworld2.tscn from chunks2 ===")
	var t0 = Time.get_ticks_msec()

	# Load the scene
	var scene_path = "res://scenes/overworld/overworld2.tscn"
	print("Loading scene: %s" % scene_path)
	var scene = load(scene_path) as PackedScene
	if not scene:
		print("ERROR: Could not load scene")
		quit()
		return

	var root = scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	print("Scene loaded and instantiated in %d ms" % (Time.get_ticks_msec() - t0))

	# Remove any programmatically-added nodes from a prior _ready() run
	var to_remove: Array = []
	for child in root.get_children():
		if child is StaticBody2D or child is Area2D:
			to_remove.append(child)
		elif child.name == "EnemyContainer":
			for grandchild in child.get_children():
				grandchild.free()
	for node in to_remove:
		print("Removing stale node: %s (%s)" % [node.name, node.get_class()])
		root.remove_child(node)
		node.free()

	# Get layers
	var layer_names = ["Ground", "Paths", "Water", "Decorations", "Buildings", "Fences"]
	var layers: Dictionary = {}
	for layer_name in layer_names:
		var layer = root.get_node_or_null(layer_name) as TileMapLayer
		if layer:
			layers[layer_name.to_lower()] = layer
		else:
			print("WARNING: Layer '%s' not found" % layer_name)

	# Clear all layers first
	print("Clearing existing tile data...")
	for layer in layers.values():
		layer.clear()

	# Load chunk index
	var index_path = "res://resources/world/chunks2/index.tres"
	var index = load(index_path) as Resource
	if not index:
		print("ERROR: Could not load chunk index at %s" % index_path)
		root.free()
		quit()
		return

	var keys = index.get_meta("keys", PackedStringArray())
	print("Loading %d chunks..." % keys.size())

	var total_tiles = 0
	var t1 = Time.get_ticks_msec()

	for key_str in keys:
		var chunk_path = "res://resources/world/chunks2/chunk_%s.tres" % key_str
		var chunk_res = load(chunk_path) as Resource
		if not chunk_res:
			continue

		for layer_name in layers:
			var arr = chunk_res.get_meta(layer_name, PackedInt32Array()) as PackedInt32Array
			if arr.size() == 0:
				continue
			var layer = layers[layer_name] as TileMapLayer
			for i in range(0, arr.size(), 5):
				var cell = Vector2i(arr[i], arr[i + 1])
				layer.set_cell(cell, arr[i + 2], Vector2i(arr[i + 3], arr[i + 4]))
				total_tiles += 1

	print("Loaded %d tiles from chunks2 in %d ms" % [total_tiles, Time.get_ticks_msec() - t1])

	# Pack and save as .tscn (WITH tile data — for editor visibility)
	t1 = Time.get_ticks_msec()
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, scene_path)
	print("Saved .tscn in %d ms" % (Time.get_ticks_msec() - t1))

	root.free()

	# Create lightweight .scn by stripping tile_map_data from the .tscn text
	t1 = Time.get_ticks_msec()
	var tscn_path = ProjectSettings.globalize_path(scene_path)
	var light_path = ProjectSettings.globalize_path("res://scenes/overworld/overworld2_light.tscn")
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

		# Convert lightweight .tscn to binary .scn
		t1 = Time.get_ticks_msec()
		var light_scene = load("res://scenes/overworld/overworld2_light.tscn") as PackedScene
		if light_scene:
			ResourceSaver.save(light_scene, "res://scenes/overworld/overworld2.scn")
			print("Saved binary .scn in %d ms" % (Time.get_ticks_msec() - t1))
		else:
			print("ERROR: Could not load light scene for .scn conversion")
	else:
		print("ERROR: Could not read/write scene files")

	print("=== DONE: Rebuilt overworld2.tscn with %d tiles in %d ms ===" % [total_tiles, Time.get_ticks_msec() - t0])
	quit()
