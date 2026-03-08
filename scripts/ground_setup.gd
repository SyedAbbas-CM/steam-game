extends TileMapLayer

func _ready() -> void:
	# Environment spritesheet is 8x8 grid of 16x16 tiles
	# Top-left tiles are grass/ground variants
	var grass_tiles = [
		Vector2i(0, 0),  # grass 1
		Vector2i(1, 0),  # grass 2
		Vector2i(0, 0),  # repeat grass 1 more often
		Vector2i(0, 0),
	]

	# Fill a large ground area
	for x in range(-25, 25):
		for y in range(-15, 15):
			var tile = grass_tiles[(x * 3 + y * 7) % grass_tiles.size()]
			# Ensure positive index
			if tile == grass_tiles[0]:
				set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
			else:
				set_cell(Vector2i(x, y), 0, Vector2i(1, 0))
