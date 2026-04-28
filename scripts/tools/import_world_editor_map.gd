extends SceneTree

## Imports a world editor JSON export into an overworld2 scene.
## Editor uses a global sprite index (SHEETS) across multiple spritesheets.
## All textures pre-scaled to 16px/tile for uniform rendering.
##
## Run: Editor → File → Run (or Godot --headless --script ...)

const JSON_PATH = "/Users/developer-cloudprimero/Downloads/Latestmap12march.json"
const SCENE_PATH = "res://scenes/overworld/overworld2.tscn"
const TILESET_PATH = "res://assets/tilesets/world_editor_tileset.tres"

# Layer names in JSON → TileMapLayer node names
const LAYER_MAP = {
	"ground": "Ground",
	"paths": "Paths",
	"buildings": "Buildings",
	"objects": "Objects",
	"decor": "Decorations",
}

# SHEETS: [offset, tile_count, cols_in_atlas, texture_path_16px]
# All textures are 16px per tile (pre-scaled from 32px or 8px originals)
const SHEETS = [
	[0,    256, 16, "res://assets/sprites/loy/world_editor_16px/maptiles_16.png"],
	[256,  256, 16, "res://assets/sprites/loy/world_editor_16px/tiles_16.png"],
	[512,  256, 16, "res://assets/sprites/loy/world_editor_16px/tiles2_16.png"],
	[768,  416, 16, "res://assets/sprites/loy/world_editor_16px/lofiEnv_16.png"],
	[1184, 108, 12, "res://assets/sprites/loy/world_editor_16px/dungeonFeat_16.png"],
	[1292, 256, 16, "res://assets/sprites/loy/world_editor_16px/lofiObj_16.png"],
	[1548, 256, 16, "res://assets/sprites/loy/world_editor_16px/lofiChar_16.png"],
]

func _init() -> void:
	print("=== World Editor Map Import ===")

	# 1. Always recreate tileset
	var tileset = _create_tileset()
	if not tileset:
		print("ERROR: Failed to create tileset")
		return

	# 2. Read JSON
	var json_text = FileAccess.get_file_as_string(JSON_PATH)
	if json_text.is_empty():
		print("ERROR: Could not read JSON at " + JSON_PATH)
		return

	var json = JSON.new()
	var err = json.parse(json_text)
	if err != OK:
		print("ERROR: JSON parse error: " + json.get_error_message())
		return
	var data = json.data as Dictionary
	print("JSON loaded. Version: %s, Author: %s" % [str(data.get("version")), str(data.get("author"))])

	# 3. Create scene tree
	var root = Node2D.new()
	root.name = "Overworld2"

	# Create TileMapLayers
	var layers: Dictionary = {}
	var layer_order = ["Ground", "Paths", "Buildings", "Objects", "Decorations"]
	for layer_name in layer_order:
		layer.name = layer_name
		layer.tile_set = tileset
		root.add_child(layer)
		layer.owner = root
		layers[layer_name] = layer
	print("Created %d TileMapLayers" % layers.size())

	# 4. Place tiles from layer_paints
	var layer_paints = data.get("layer_paints", {}) as Dictionary
	var total_placed = 0
	var total_skipped = 0

	for json_layer in layer_paints:
		var node_name = LAYER_MAP.get(json_layer, "")
		if node_name.is_empty():
			print("WARNING: Unknown layer '%s', skipping" % json_layer)
			continue
		var layer = layers.get(node_name) as TileMapLayer
		if not layer:
			continue

		var tiles = layer_paints[json_layer] as Array
		var placed = 0
		var skipped = 0
		for tile_entry in tiles:

			if tile_id < 0:
				layer.erase_cell(Vector2i(tx, ty))
				continue

			if result.x < 0:
				skipped += 1
				continue

			layer.set_cell(Vector2i(tx, ty), result.x, Vector2i(result.y, result.z))
			placed += 1

		total_placed += placed
		total_skipped += skipped
		print("  %s: %d tiles placed, %d skipped" % [node_name, placed, skipped])

	# 5. Also apply terrain_paints to Ground if present
	var terrain_paints = data.get("terrain_paints", []) as Array
	if terrain_paints.size() > 0:
		var ground_layer = layers["Ground"]
		var tp_placed = 0
		for entry in terrain_paints:
			var tx = int(entry[0])
			var ty = int(entry[1])
			var tile_id = int(entry[2])
			if tile_id < 0:
				continue
			var result = _resolve_tile_id(tile_id)
			if result.x < 0:
				continue
			if ground_layer.get_cell_source_id(Vector2i(tx, ty)) == -1:
				ground_layer.set_cell(Vector2i(tx, ty), result.x, Vector2i(result.y, result.z))
				tp_placed += 1
		print("  terrain_paints: %d additional ground tiles" % tp_placed)

	print("Total: %d placed, %d skipped" % [total_placed, total_skipped])

	# 6. Store metadata on root
	var spawn = data.get("player_spawn", {})
	if spawn:
		root.set_meta("player_spawn_x", spawn.get("x", 0))
		root.set_meta("player_spawn_y", spawn.get("y", 0))

	var custom_areas = data.get("custom_areas", [])
	if custom_areas.size() > 0:
		root.set_meta("custom_areas", str(custom_areas))

	# 7. Save scene
	var packed = PackedScene.new()
	packed.pack(root)
	var save_err = ResourceSaver.save(packed, SCENE_PATH)
	if save_err != OK:
		print("ERROR: Failed to save scene: " + str(save_err))
	else:
		print("Scene saved to: " + SCENE_PATH)

	root.free()
	print("=== Import Complete ===")
	quit()

# Convert global tile ID → Vector3i(source_id, atlas_x, atlas_y)
func _resolve_tile_id(tile_id: int) -> Vector3i:
	for i in range(SHEETS.size()):
		var offset = sheet[0] as int
		var count = sheet[1] as int
		if tile_id >= offset and tile_id < offset + count:
			var local = tile_id - offset
			var atlas_x = local % cols
			var atlas_y = local / cols
			return Vector3i(i, atlas_x, atlas_y)
	return Vector3i(-1, 0, 0)

func _create_tileset() -> TileSet:
	var ts = TileSet.new()
	ts.tile_size = Vector2i(16, 16)

	for i in range(SHEETS.size()):
		var sheet = SHEETS[i]
		var cols = sheet[2] as int
		var tex_path = sheet[3] as String

		var tex = load(tex_path) as Texture2D
		if not tex:
			print("  WARNING: Could not load texture: " + tex_path)
			continue

		var src = TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(16, 16)  # All pre-scaled to 16px
		ts.add_source(src, i)

		var tex_w = tex.get_width()
		var tex_h = tex.get_height()
		var rows = tex_h / 16

		for y in range(rows):
			for x in range(cols):
				if x * 16 < tex_w and y * 16 < tex_h:
					src.create_tile(Vector2i(x, y))

		print("  Source %d: %s (%dx%d tiles)" % [i, tex_path.get_file(), cols, rows])

	ResourceSaver.save(ts, TILESET_PATH)
	print("Tileset saved to: " + TILESET_PATH)
	return ts
