## Bake overworld tiles into the .tscn file.
## Run: godot --headless --path . --script res://scripts/tools/bake_overworld.gd
extends SceneTree

func _init() -> void:
	# Load scene resource WITHOUT instantiating (avoids _ready and autoloads)
	var packed = load("res://scenes/overworld/overworld.tscn") as PackedScene
	var scene = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)

	# Get TileMapLayer children by name
	var ground = scene.get_node("Ground") as TileMapLayer
	var paths = scene.get_node("Paths") as TileMapLayer
	var water = scene.get_node("Water") as TileMapLayer
	var decorations = scene.get_node("Decorations") as TileMapLayer
	var buildings = scene.get_node("Buildings") as TileMapLayer
	var fences = scene.get_node("Fences") as TileMapLayer

	if not ground:
		print("ERROR: Could not find Ground TileMapLayer")
		quit()
		return

	# Generate tiles directly (copied from overworld.gd _generate_starter_world)
	_generate(ground, paths, water, decorations, buildings, fences)

	# Pack and save back
	var new_packed = PackedScene.new()
	new_packed.pack(scene)
	ResourceSaver.save(new_packed, "res://scenes/overworld/overworld.tscn")
	print("Overworld baked! " + str(ground.get_used_cells().size()) + " ground tiles.")
	quit()

func _generate(ground: TileMapLayer, paths: TileMapLayer, water: TileMapLayer,
		decorations: TileMapLayer, buildings: TileMapLayer, fences: TileMapLayer) -> void:
	var size = 30
	seed(42)

	# Grass
	for x in range(-size, size + 1):
		for y in range(-size, size + 1):
			var grass_tile = Vector2i(6, 14)
			if randf() < 0.2:
				grass_tile = Vector2i(7, 14)
			elif randf() < 0.05:
				grass_tile = Vector2i(8, 14)
			ground.set_cell(Vector2i(x, y), 0, grass_tile)

	# Trees at edges
	for x in range(-size, size + 1):
		for y in range(-size, size + 1):
			var dist = max(abs(x), abs(y))
			if dist > size - 5 and randf() < 0.3:
				var tree = Vector2i(9, 14)
				if randf() < 0.2:
					tree = Vector2i(10, 14)
				elif randf() < 0.1:
					tree = Vector2i(15, 14)
				decorations.set_cell(Vector2i(x, y), 0, tree)
			elif dist > size - 3 and randf() < 0.15:
				decorations.set_cell(Vector2i(x, y), 0, Vector2i(14, 14))

	# Water pool
	for x in range(5, 9):
		for y in range(3, 7):
			water.set_cell(Vector2i(x, y), 0, Vector2i(2, 17))

	# Horizontal path
	for x in range(-3, 15):
		for i in range(-1, 2):
			paths.set_cell(Vector2i(x, i), 0, Vector2i(13, 21))

	# Vertical path north
	for y in range(-13, 0):
		for i in range(-1, 2):
			paths.set_cell(Vector2i(i, y), 0, Vector2i(13, 21))

	# West path
	for x in range(-10, -2):
		for i in range(-1, 2):
			paths.set_cell(Vector2i(x, i - 3), 0, Vector2i(13, 21))

	# Stone Crypt entrance
	buildings.set_cell(Vector2i(14, -1), 0, Vector2i(13, 15))
	buildings.set_cell(Vector2i(14, 0), 0, Vector2i(0, 23))
	buildings.set_cell(Vector2i(15, -1), 0, Vector2i(14, 15))
	buildings.set_cell(Vector2i(15, 0), 0, Vector2i(14, 15))

	# Flooded Cavern entrance
	buildings.set_cell(Vector2i(-8, -4), 0, Vector2i(12, 15))
	buildings.set_cell(Vector2i(-8, -3), 0, Vector2i(2, 23))
	buildings.set_cell(Vector2i(-7, -4), 0, Vector2i(14, 15))
	buildings.set_cell(Vector2i(-7, -3), 0, Vector2i(14, 15))

	# Burning Hall entrance
	buildings.set_cell(Vector2i(-1, -13), 0, Vector2i(13, 15))
	buildings.set_cell(Vector2i(-1, -12), 0, Vector2i(8, 23))
	buildings.set_cell(Vector2i(0, -13), 0, Vector2i(14, 15))
	buildings.set_cell(Vector2i(0, -12), 0, Vector2i(14, 15))

	# Fences around Stone Crypt
	for x in range(13, 17):
		fences.set_cell(Vector2i(x, -2), 0, Vector2i(2, 24))
		fences.set_cell(Vector2i(x, 1), 0, Vector2i(2, 24))

	# Signposts
	buildings.set_cell(Vector2i(12, 0), 0, Vector2i(11, 23))
	buildings.set_cell(Vector2i(-10, -3), 0, Vector2i(12, 23))
	buildings.set_cell(Vector2i(-2, -12), 0, Vector2i(12, 23))

	# Flowers
	for i in range(8):
		var fx = randi_range(-15, 15)
		var fy = randi_range(-15, 15)
		if decorations.get_cell_source_id(Vector2i(fx, fy)) == -1:
			var flower = Vector2i(14, 16) if randf() > 0.5 else Vector2i(15, 16)
			decorations.set_cell(Vector2i(fx, fy), 0, flower)

	# Mushrooms
	for i in range(4):
		var mx = randi_range(-20, 20)
		var my = randi_range(-20, 20)
		if decorations.get_cell_source_id(Vector2i(mx, my)) == -1:
			var mush = Vector2i(12, 16) if randf() > 0.5 else Vector2i(13, 16)
			decorations.set_cell(Vector2i(mx, my), 0, mush)

	# Rocks
	for i in range(6):
		var rx = randi_range(-20, 20)
		var ry = randi_range(-20, 20)
		if decorations.get_cell_source_id(Vector2i(rx, ry)) == -1:
			decorations.set_cell(Vector2i(rx, ry), 0, Vector2i(9, 16))
