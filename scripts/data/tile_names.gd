class_name TileNames
extends RefCounted

## Tile name lookup for overworld tile inspection.
## Reads custom_data from external .tres TileSet files at startup.
## Falls back to hardcoded names for tiles without custom data.

static var _names: Dictionary = {}  # Vector3i(overworld_source, ax, ay) → String
static var _initialized: bool = false

static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true

## Load names from a .tres TileSet's source 0, mapped to a given overworld source ID.
## tres_source_id: which source inside the .tres file to read (usually 0)
## overworld_source_id: what source ID this maps to in the overworld (0, 1, or 2)
static func load_from_tileset(tileset: TileSet, tres_source_id: int, overworld_source_id: int) -> void:
	_ensure_init()
	var src = tileset.get_source(tres_source_id) as TileSetAtlasSource
	if not src:
		return
	if tileset.get_custom_data_layers_count() == 0:
		return
	var grid_size = src.get_atlas_grid_size()
	var count = 0
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var coords = Vector2i(x, y)
			if not src.has_tile(coords):
				continue
			var td = src.get_tile_data(coords, 0)
			if not td:
				continue
			var val = td.get_custom_data("name")
			if val is String and val != "":
				_names[Vector3i(overworld_source_id, x, y)] = val
				count += 1
	if count > 0:
		print("TileNames: loaded %d names for source %d" % [count, overworld_source_id])

## Load hardcoded fallbacks (called after tileset loading, won't override)
static func load_fallbacks() -> void:
	# Source 0: maptiles.png
	_add_name(0, 4, 1, "Fence")
	_add_name(0, 4, 7, "Fence")
	_add_name(0, 4, 9, "Fence")
	_add_name(0, 4, 14, "Fence")
	_add_name(0, 4, 15, "Fence")
	_add_name(0, 8, 6, "Wall")
	_add_name(0, 0, 7, "Wall")
	_add_name(0, 6, 7, "Gate")
	_add_name(0, 14, 7, "Tree")
	_add_name(0, 14, 10, "Cactus")
	_add_name(0, 12, 7, "Bush")
	_add_name(0, 14, 9, "Shrub")
	_add_name(0, 5, 7, "Stairs")
	_add_name(0, 0, 2, "Water")
	_add_name(0, 1, 2, "Water")
	# Source 1: lofiEnvironment_32.png
	_add_name(1, 12, 16, "Mushrooms")
	_add_name(1, 14, 16, "Flowers")
	_add_name(1, 15, 16, "Flowers")
	_add_name(1, 13, 16, "Flowers")
	_add_name(1, 0, 0, "Barrel")
	_add_name(1, 1, 0, "Crate")
	_add_name(1, 4, 0, "Chest")
	# Source 2: lofi_dungeon_features_32.png
	_add_name(2, 0, 0, "Pillar")
	_add_name(2, 7, 0, "Tombstone")

static func _add_name(source: int, ax: int, ay: int, tile_name: String) -> void:
	var key = Vector3i(source, ax, ay)
	if not _names.has(key):
		_names[key] = tile_name

static func get_tile_info(layer_name: String, source: int, atlas: Vector2i) -> Dictionary:
	_ensure_init()
	var key = Vector3i(source, atlas.x, atlas.y)
	if _names.has(key):
		return {"name": _names[key], "desc": ""}

	match layer_name:
		"buildings":
			return {"name": "Building", "desc": ""}
		"water":
			return {"name": "Water", "desc": ""}
		"fences":
			return {"name": "Barrier" if source == 0 else "Plants", "desc": ""}
		"decorations":
			return {"name": "Decoration", "desc": ""}
		"paths":
			return {"name": "Path", "desc": ""}
	return {"name": "Object", "desc": ""}
