@tool
extends Node2D
## Open scenes/samples/sample_overworld.tscn to see overworld tile examples.
## Shows: grass variants, paths, water, lava, poison, buildings, fences, decorations.
## Edit freely and save to bake changes.

@onready var ground: TileMapLayer = $Ground
@onready var paths: TileMapLayer = $Paths
@onready var water: TileMapLayer = $Water
@onready var decorations: TileMapLayer = $Decorations
@onready var buildings: TileMapLayer = $Buildings
@onready var fences: TileMapLayer = $Fences

func _ready() -> void:
	if ground and ground.get_used_cells().size() == 0:
		_generate_samples()
		print("Sample overworld generated! Save (Ctrl+S) to bake.")

func _generate_samples() -> void:
	seed(99)

	# === Grass base (20x20 area) ===
	for x in range(-10, 10):
		for y in range(-10, 10):
			var grass = Vector2i(6, 14)
			if randf() < 0.2:
				grass = Vector2i(7, 14)
			elif randf() < 0.05:
				grass = Vector2i(8, 14)
			ground.set_cell(Vector2i(x, y), 0, grass)

	# === Water pool (top-right) ===
	for x in range(4, 8):
		for y in range(-8, -4):
			water.set_cell(Vector2i(x, y), 0, Vector2i(2, 17))

	# === Lava pool (top-left) ===
	for x in range(-8, -4):
		for y in range(-8, -4):
			water.set_cell(Vector2i(x, y), 0, Vector2i(0, 17))

	# === Poison pool (bottom-left) ===
	for x in range(-8, -4):
		for y in range(4, 8):
			water.set_cell(Vector2i(x, y), 0, Vector2i(2, 17))
	# Poison variant
	for x in range(-7, -5):
		for y in range(5, 7):
			water.set_cell(Vector2i(x, y), 0, Vector2i(3, 17))

	# === Path (horizontal center) ===
	for x in range(-8, 8):
		for i in range(-1, 2):
			paths.set_cell(Vector2i(x, i), 0, Vector2i(13, 21))

	# === Path (vertical) ===
	for y in range(-8, 8):
		for i in range(-1, 2):
			paths.set_cell(Vector2i(i, y), 0, Vector2i(13, 21))

	# === Building: dungeon entrance (stone crypt style) ===
	buildings.set_cell(Vector2i(5, 0), 0, Vector2i(13, 15))  # Building top
	buildings.set_cell(Vector2i(5, 1), 0, Vector2i(0, 23))   # Door (brown closed)
	buildings.set_cell(Vector2i(6, 0), 0, Vector2i(14, 15))  # Building top right
	buildings.set_cell(Vector2i(6, 1), 0, Vector2i(14, 15))

	# === Building: another entrance ===
	buildings.set_cell(Vector2i(-5, -1), 0, Vector2i(12, 15))
	buildings.set_cell(Vector2i(-5, 0), 0, Vector2i(2, 23))   # Door (grey closed)
	buildings.set_cell(Vector2i(-4, -1), 0, Vector2i(14, 15))
	buildings.set_cell(Vector2i(-4, 0), 0, Vector2i(14, 15))

	# === Signposts ===
	buildings.set_cell(Vector2i(3, 1), 0, Vector2i(11, 23))   # Sign
	buildings.set_cell(Vector2i(-3, 1), 0, Vector2i(12, 23))  # Sign variant

	# === Fences ===
	for x in range(4, 8):
		fences.set_cell(Vector2i(x, -1), 0, Vector2i(2, 24))
		fences.set_cell(Vector2i(x, 2), 0, Vector2i(2, 24))

	# === Trees (border) ===
	for x in range(-10, 10):
		for y in [-10, -9, 8, 9]:
			if randf() < 0.4:
				var tree = Vector2i(9, 14) if randf() > 0.3 else Vector2i(10, 14)
				decorations.set_cell(Vector2i(x, y), 0, tree)
	for y in range(-10, 10):
		for x in [-10, -9, 8, 9]:
			if randf() < 0.4:
				var tree = Vector2i(9, 14) if randf() > 0.3 else Vector2i(10, 14)
				decorations.set_cell(Vector2i(x, y), 0, tree)

	# === Flowers, mushrooms, rocks ===
	for i in range(6):
		var fx = randi_range(-6, 6)
		var fy = randi_range(-6, 6)
		if decorations.get_cell_source_id(Vector2i(fx, fy)) == -1:
			decorations.set_cell(Vector2i(fx, fy), 0, Vector2i(14, 16) if randf() > 0.5 else Vector2i(15, 16))

	for i in range(3):
		var mx = randi_range(-6, 6)
		var my = randi_range(-6, 6)
		if decorations.get_cell_source_id(Vector2i(mx, my)) == -1:
			decorations.set_cell(Vector2i(mx, my), 0, Vector2i(12, 16) if randf() > 0.5 else Vector2i(13, 16))

	for i in range(4):
		var rx = randi_range(-6, 6)
		var ry = randi_range(-6, 6)
		if decorations.get_cell_source_id(Vector2i(rx, ry)) == -1:
			decorations.set_cell(Vector2i(rx, ry), 0, Vector2i(9, 16))
