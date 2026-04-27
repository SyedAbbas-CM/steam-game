extends SceneTree
## Run: godot --headless --script res://scripts/tools/paint_imitation.gd

func _init() -> void:
	var scene = load("res://scenes/samples/sample_rooms.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var floor_layer: TileMapLayer = scene.get_node("Floor")
	var deco_layer: TileMapLayer = scene.get_node("Decorations")

	var ox = 80
	var w = 37
	var h = 31

	# Clear existing source-1 tiles
	for cell in deco_layer.get_used_cells():
		if cell.x >= ox and cell.x < ox + w and cell.y >= 0 and cell.y < h:
			if deco_layer.get_cell_source_id(cell) == 1:
				deco_layer.erase_cell(cell)
	for cell in floor_layer.get_used_cells():
		if cell.x >= ox and cell.x < ox + w and cell.y >= 0 and cell.y < h:
			if floor_layer.get_cell_source_id(cell) == 1:
				floor_layer.erase_cell(cell)

	var cpt = func(x: int, y: int, tile: Vector2i) -> void:
		floor_layer.set_cell(Vector2i(ox + x, y), 1, tile)
	var d = func(x: int, y: int, tile: Vector2i) -> void:
		deco_layer.set_cell(Vector2i(ox + x, y), 1, tile)

	# === NAMED SPRITE CONSTANTS (from tileset custom_data_0) ===
	# Row 0
	var BARREL = Vector2i(0, 0)
	var BARREL_OPEN = Vector2i(1, 0)
	var BARREL_CLUSTER_3 = Vector2i(2, 0)
	var BARREL_CLUSTER_2 = Vector2i(3, 0)
	var SMALL_BARREL = Vector2i(5, 0)
	var BLOCK = Vector2i(6, 0)
	var WEAPON_RACK = Vector2i(7, 0)
	var WEAPON_RACK_LEFT = Vector2i(8, 0)
	var WEAPON_RACK_RIGHT = Vector2i(9, 0)
	var ARROW_TRAP_FRONT = Vector2i(10, 0)
	# Row 1
	var IRON_GRATE = Vector2i(0, 1)
	var ALTAR = Vector2i(1, 1)
	var LAMP_ON = Vector2i(3, 1)
	var LAMP_FLICKER = Vector2i(4, 1)
	var STOOL = Vector2i(5, 1)
	var TABLE_GLASSES_R = Vector2i(8, 1)
	var TABLE_GLASSES_L = Vector2i(9, 1)
	var TABLE_GLASSES = Vector2i(10, 1)
	var GOLD = Vector2i(11, 1)
	var GOLD_LARGE = Vector2i(12, 1)
	var GOLD_VERY_LARGE = Vector2i(13, 1)
	# Row 2
	var CHAIR_RIGHT = Vector2i(0, 2)
	var CHAIR_LEFT = Vector2i(1, 2)
	var CHAIR_FRONT = Vector2i(2, 2)
	var TABLE = Vector2i(3, 2)
	var BOOKSHELF = Vector2i(4, 2)
	var BOOKSHELF_LEFT = Vector2i(5, 2)
	var BOOKSHELF_RIGHT = Vector2i(6, 2)
	var WARDROBE = Vector2i(7, 2)
	var WARDROBE_OPEN = Vector2i(8, 2)
	var BED_RIGHT_RED = Vector2i(10, 2)
	var BED_LEFT_RED = Vector2i(11, 2)
	var BED_BLUE_LEFT = Vector2i(12, 2)
	var BED_BLUE_RIGHT = Vector2i(13, 2)
	var BED_GREEN_LEFT = Vector2i(14, 2)
	var BED_GREEN_RIGHT = Vector2i(15, 2)
	var TABLE_ROUND = Vector2i(19, 2)
	# Row 3
	var CAULDRON = Vector2i(0, 3)
	var CAULDRON_CLOSED = Vector2i(1, 3)
	var CAULDRON_CRACKED = Vector2i(2, 3)
	var STONE_TABLE = Vector2i(5, 3)
	var FENCE_VERTICAL = Vector2i(9, 3)
	var BENCH = Vector2i(18, 3)
	# Row 5
	var CAGE = Vector2i(12, 5)
	var BUCKET = Vector2i(13, 5)
	# Row 6
	var SKULL = Vector2i(0, 6)
	var BONES = Vector2i(2, 6)
	var BLOOD_SMALL = Vector2i(12, 6)
	var BLOOD_DROPS = Vector2i(13, 6)
	var BLOOD_MEDIUM = Vector2i(14, 6)
	var BLOOD_LARGE = Vector2i(15, 6)
	var FURNACE = Vector2i(16, 6)
	var WATER_TROUGH = Vector2i(17, 6)
	var THRONE = Vector2i(18, 6)
	var HEAD_CHOPPING_BLOCK = Vector2i(19, 6)
	# Row 7
	var CANDLE_STAND = Vector2i(0, 7)
	var POTION_CABINET = Vector2i(1, 7)
	var LADDER = Vector2i(2, 7)
	var ARMOR_DISPLAY = Vector2i(3, 7)
	var WEAPON_DISPLAY = Vector2i(4, 7)
	var CHEST_OPEN_GOLD = Vector2i(5, 7)
	var CHEST_OPEN_SILVER = Vector2i(6, 7)
	var BOOK_STAND = Vector2i(9, 7)
	var LARGE_CHEST = Vector2i(10, 7)
	var ADV_WEAPON_RACK = Vector2i(11, 7)
	var FLOOR_CANDLE = Vector2i(12, 7)
	var ANVIL = Vector2i(14, 7)
	var LEVER_RIGHT = Vector2i(15, 7)
	var LEVER_LEFT = Vector2i(16, 7)
	var TRAINING_DUMMY = Vector2i(17, 7)
	var BLOOD_ALTAR = Vector2i(18, 7)
	var CLOSED_CHEST = Vector2i(19, 7)
	# Row 8
	var TRAP_H = Vector2i(0, 8)
	var TRAP_V = Vector2i(1, 8)
	var TRAP_CONN = Vector2i(2, 8)
	var SAW_BLADE = Vector2i(3, 8)
	var ELECTRIC_PULSE = Vector2i(4, 8)
	var EXPLOSIVE_BARREL = Vector2i(6, 8)
	var FLAME_TRAP = Vector2i(8, 8)
	var BELL = Vector2i(9, 8)
	var BRAZIER = Vector2i(10, 8)
	var GOLDEN_STATUE = Vector2i(17, 8)
	# Carpets
	var CH_BLUE = Vector2i(13, 3)
	var CH_RED = Vector2i(12, 3)
	var CH_GREEN = Vector2i(14, 3)
	var CV_GREEN = Vector2i(18, 2)
	var CV_RED = Vector2i(16, 2)
	var CV_BLUE = Vector2i(17, 2)
	var CC_RED = Vector2i(15, 3)
	var CC_BLUE = Vector2i(16, 3)
	var CC_GREEN = Vector2i(17, 3)
	# Debris/moss
	var DEBRIS1 = Vector2i(0, 4)
	var DEBRIS2 = Vector2i(1, 4)
	var MOSS1 = Vector2i(0, 5)
	var MOSS2 = Vector2i(1, 5)

	# ================================================================
	# ZONE A: BARRACKS / DORMITORY — blue horizontal y=2-9, x=2-18
	# Rows of REAL beds, iron grates as partitions, cages, buckets
	# ================================================================
	for y in range(2, 10):
		for x in range(2, 19):
			cpt.call(x, y, CH_BLUE)

	# North wall — weapon racks (armory wall for soldiers)
	d.call(3, 2, WEAPON_RACK_LEFT)
	d.call(5, 2, WEAPON_RACK)
	d.call(7, 2, WEAPON_RACK_RIGHT)
	d.call(10, 2, ADV_WEAPON_RACK)
	d.call(12, 2, ARMOR_DISPLAY)
	d.call(14, 2, WEAPON_DISPLAY)
	d.call(16, 2, ARMOR_DISPLAY)

	# Bed row 1 (y=3-4): red beds facing each other across aisle
	d.call(3, 3, BED_RIGHT_RED)      # faces right
	d.call(4, 3, CLOSED_CHEST)       # footlocker
	d.call(3, 4, BED_RIGHT_RED)
	d.call(4, 4, BUCKET)             # wash bucket

	d.call(7, 3, BED_LEFT_RED)       # faces left (across aisle from right beds)
	d.call(6, 3, CLOSED_CHEST)
	d.call(7, 4, BED_LEFT_RED)
	d.call(6, 4, BUCKET)

	# Iron grate partition
	d.call(9, 3, IRON_GRATE)
	d.call(9, 4, IRON_GRATE)

	# Bed row 2: blue beds
	d.call(11, 3, BED_BLUE_RIGHT)
	d.call(12, 3, CLOSED_CHEST)
	d.call(11, 4, BED_BLUE_RIGHT)
	d.call(12, 4, BUCKET)

	d.call(15, 3, BED_BLUE_LEFT)
	d.call(14, 3, CLOSED_CHEST)
	d.call(15, 4, BED_BLUE_LEFT)
	d.call(14, 4, BUCKET)

	# Iron grate partition
	d.call(17, 3, IRON_GRATE)
	d.call(17, 4, IRON_GRATE)

	# Bed row 3 (y=6-7): green beds
	d.call(3, 6, BED_GREEN_RIGHT)
	d.call(4, 6, CLOSED_CHEST)
	d.call(3, 7, BED_GREEN_RIGHT)

	d.call(7, 6, BED_GREEN_LEFT)
	d.call(6, 6, CLOSED_CHEST)
	d.call(7, 7, BED_GREEN_LEFT)

	d.call(9, 6, IRON_GRATE)
	d.call(9, 7, IRON_GRATE)

	d.call(11, 6, BED_RIGHT_RED)
	d.call(12, 6, CLOSED_CHEST)
	d.call(11, 7, BED_RIGHT_RED)

	d.call(15, 6, BED_LEFT_RED)
	d.call(14, 6, CLOSED_CHEST)
	d.call(15, 7, BED_LEFT_RED)

	# Common area (y=8): tables + stools
	d.call(5, 8, TABLE_GLASSES)
	d.call(4, 8, STOOL)
	d.call(6, 8, STOOL)
	d.call(12, 8, TABLE_GLASSES_R)
	d.call(11, 8, STOOL)
	d.call(13, 8, STOOL)
	d.call(16, 8, BARREL)
	d.call(17, 8, BARREL_OPEN)

	# Lamps
	d.call(5, 5, LAMP_FLICKER)
	d.call(13, 5, LAMP_FLICKER)
	d.call(2, 8, FLOOR_CANDLE)

	# ================================================================
	# ZONE B: BLACKSMITH — green vertical y=2-12, x=22-34
	# Furnace, anvil, water trough, weapon racks, training dummy
	# ================================================================
	for y in range(2, 13):
		for x in range(22, 35):
			cpt.call(x, y, CV_GREEN)

	# North wall — finished weapons on display
	d.call(23, 2, WEAPON_RACK_LEFT)
	d.call(25, 2, WEAPON_RACK)
	d.call(27, 2, ADV_WEAPON_RACK)
	d.call(29, 2, WEAPON_RACK_RIGHT)
	d.call(31, 2, ARMOR_DISPLAY)
	d.call(33, 2, WEAPON_DISPLAY)

	# FORGE CLUSTER (y=4-6): furnace + anvil + water trough
	d.call(25, 4, FURNACE)           # the forge!
	d.call(27, 4, ANVIL)             # for hammering
	d.call(29, 4, WATER_TROUGH)      # quench hot metal
	d.call(25, 5, BARREL)            # coal supply
	d.call(26, 5, BARREL_CLUSTER_2)  # materials
	d.call(30, 4, SMALL_BARREL)      # oil
	d.call(28, 5, LAMP_FLICKER)      # light

	# Work table with tools (y=7)
	d.call(25, 7, TABLE)
	d.call(24, 7, CHAIR_RIGHT)       # smith sits here
	d.call(26, 7, STOOL)
	d.call(28, 7, BOOK_STAND)        # blueprint/recipe

	# Training area (y=9-10)
	d.call(25, 9, TRAINING_DUMMY)
	d.call(27, 9, TRAINING_DUMMY)
	d.call(26, 10, WEAPON_RACK)      # practice weapons

	# Material storage (y=11-12)
	d.call(31, 10, BARREL)
	d.call(32, 10, BARREL_CLUSTER_3)
	d.call(33, 10, SMALL_BARREL)
	d.call(31, 11, LARGE_CHEST)
	d.call(32, 11, CLOSED_CHEST)
	d.call(30, 11, LEVER_RIGHT)      # bellows lever

	# Braziers
	d.call(22, 4, BRAZIER)
	d.call(34, 4, BRAZIER)
	d.call(22, 10, BRAZIER)

	# ================================================================
	# ZONE C: ALCHEMIST — red horizontal y=13-19, x=3-14
	# Potion cabinets, cauldrons, bookshelves, experiments
	# ================================================================
	for y in range(13, 20):
		for x in range(3, 15):
			cpt.call(x, y, CH_RED)

	# Potion cabinet wall (y=13) — THE potion rack sprite!
	d.call(3, 13, POTION_CABINET)
	d.call(4, 13, POTION_CABINET)
	d.call(5, 13, POTION_CABINET)
	d.call(7, 13, BOOKSHELF)
	d.call(8, 13, BOOKSHELF_LEFT)
	d.call(9, 13, BOOKSHELF_RIGHT)
	d.call(11, 13, POTION_CABINET)
	d.call(12, 13, POTION_CABINET)
	d.call(13, 13, LAMP_FLICKER)

	# Brewing station (y=15-16)
	d.call(6, 15, CAULDRON)          # main brew
	d.call(5, 15, STOOL)             # alchemist's seat
	d.call(7, 15, LAMP_FLICKER)
	d.call(8, 15, CAULDRON_CLOSED)   # sealed experiment
	d.call(10, 15, CAULDRON_CRACKED) # failed experiment!

	# Recipe area (y=16-17)
	d.call(5, 17, BOOK_STAND)        # recipe lectern
	d.call(4, 17, CHAIR_RIGHT)
	d.call(6, 17, CHAIR_LEFT)
	d.call(8, 17, TABLE)             # mixing table
	d.call(9, 17, STOOL)

	# Volatile corner (y=18-19)
	d.call(11, 18, EXPLOSIVE_BARREL)
	d.call(12, 18, EXPLOSIVE_BARREL)
	d.call(11, 19, EXPLOSIVE_BARREL)
	d.call(12, 19, BARREL)           # buffer barrel
	d.call(13, 18, SMALL_BARREL)

	# Left wall — wardrobe for robes
	d.call(1, 15, WARDROBE)
	d.call(1, 18, WARDROBE_OPEN)

	# ================================================================
	# ZONE D: EXECUTION PIT — red connector y=13-20, x=16-22
	# Blood altar, head chopping block, cages, ritual
	# ================================================================
	for y in range(13, 21):
		for x in range(16, 23):
			cpt.call(x, y, CC_RED)

	# HEAD CHOPPING BLOCK (y=14): the actual sprite + blood
	d.call(19, 14, HEAD_CHOPPING_BLOCK)  # the block itself!
	d.call(18, 14, BLOOD_MEDIUM)
	d.call(20, 14, BLOOD_DROPS)
	d.call(19, 15, BLOOD_LARGE)      # pool below

	# BLOOD ALTAR (y=17): the actual sprite!
	d.call(19, 17, BLOOD_ALTAR)      # ritual altar
	d.call(18, 17, CANDLE_STAND)     # flanking candle
	d.call(20, 17, CANDLE_STAND)     # flanking candle
	d.call(19, 18, BLOOD_LARGE)      # blood pool below altar
	d.call(18, 18, SKULL)            # skull offering
	d.call(20, 18, SKULL)            # skull offering

	# Weapon display between block and altar (executioner's axe)
	d.call(19, 16, WEAPON_DISPLAY)
	d.call(17, 16, CANDLE_STAND)
	d.call(21, 16, CANDLE_STAND)

	# More blood + bones
	d.call(17, 14, BLOOD_SMALL)
	d.call(21, 15, BLOOD_DROPS)
	d.call(16, 17, Vector2i(3, 6))   # bones_6
	d.call(22, 18, Vector2i(5, 6))   # bones_4

	# Braziers at corners
	d.call(16, 13, BRAZIER)
	d.call(22, 13, BRAZIER)
	d.call(16, 20, BRAZIER)
	d.call(22, 20, BRAZIER)

	# Cages for condemned
	d.call(17, 13, CAGE)
	d.call(21, 13, CAGE)
	d.call(17, 19, CAGE)
	d.call(21, 19, CAGE)

	# ================================================================
	# ZONE E: TREASURE VAULT — green horizontal y=14-20, x=24-34
	# Gold piles, open chests, stone pedestals, golden statue
	# ================================================================
	for y in range(14, 21):
		for x in range(24, 35):
			cpt.call(x, y, CH_GREEN)

	# Golden statue centerpiece
	d.call(29, 15, GOLDEN_STATUE)

	# Gold piles around the statue
	d.call(28, 15, GOLD_VERY_LARGE)
	d.call(30, 15, GOLD_VERY_LARGE)
	d.call(29, 16, GOLD_LARGE)
	d.call(28, 16, GOLD)
	d.call(30, 16, GOLD)

	# Open treasure chests lining the walls
	d.call(25, 14, CHEST_OPEN_GOLD)
	d.call(27, 14, CHEST_OPEN_SILVER)
	d.call(31, 14, CHEST_OPEN_GOLD)
	d.call(33, 14, CHEST_OPEN_SILVER)

	# Closed chests (still locked)
	d.call(25, 18, LARGE_CHEST)
	d.call(27, 18, CLOSED_CHEST)
	d.call(31, 18, LARGE_CHEST)
	d.call(33, 18, CLOSED_CHEST)

	# Stone table pedestals for display
	d.call(26, 16, STONE_TABLE)
	d.call(32, 16, STONE_TABLE)

	# Bell (alarm if vault is breached)
	d.call(29, 14, BELL)

	# Candle stands for dramatic lighting
	d.call(25, 16, CANDLE_STAND)
	d.call(33, 16, CANDLE_STAND)
	d.call(29, 18, CANDLE_STAND)

	# Braziers
	d.call(24, 14, BRAZIER)
	d.call(34, 14, BRAZIER)
	d.call(24, 20, BRAZIER)
	d.call(34, 20, BRAZIER)

	# Right wall wardrobe (vault keeper's gear)
	d.call(35, 17, WARDROBE)

	# ================================================================
	# BOTTOM: TRAP TRACK EXAMPLES — bare stone y=23-28
	# Two example circuits showing the roller-coaster system
	# ================================================================

	# Circuit 1: Rectangular loop (left)
	for tx in range(4, 13):
		d.call(tx, 23, TRAP_H)
	for ty in range(24, 27):
		d.call(13, ty, TRAP_V)
	for tx in range(4, 13):
		d.call(tx, 27, TRAP_H)
	for ty in range(24, 27):
		d.call(3, ty, TRAP_V)
	d.call(3, 23, TRAP_CONN)
	d.call(13, 23, TRAP_CONN)
	d.call(3, 27, TRAP_CONN)
	d.call(13, 27, TRAP_CONN)
	# Entities riding the tracks
	d.call(8, 23, SAW_BLADE)
	d.call(3, 25, ELECTRIC_PULSE)

	# Circuit 2: L-shaped (right)
	for ty in range(23, 27):
		d.call(24, ty, TRAP_V)
	d.call(24, 27, TRAP_CONN)
	for tx in range(25, 34):
		d.call(tx, 27, TRAP_H)
	d.call(34, 27, TRAP_CONN)
	for ty in range(24, 27):
		d.call(34, ty, TRAP_V)
	d.call(34, 23, TRAP_CONN)
	for tx in range(25, 34):
		d.call(tx, 23, TRAP_H)
	d.call(24, 23, TRAP_CONN)
	# Entities
	d.call(29, 27, SAW_BLADE)
	d.call(34, 25, ELECTRIC_PULSE)
	d.call(29, 23, FLAME_TRAP)

	# ================================================================
	# FLOOR SCATTER + BOUNDARIES
	# ================================================================
	d.call(10, 10, DEBRIS1)
	d.call(14, 11, DEBRIS2)
	d.call(19, 10, MOSS1)
	d.call(7, 11, MOSS2)
	d.call(9, 24, SKULL)
	d.call(20, 25, BLOOD_SMALL)
	d.call(15, 25, DEBRIS1)

	# Braziers between zones
	d.call(2, 10, BRAZIER)
	d.call(20, 10, BRAZIER)
	d.call(34, 12, BRAZIER)
	d.call(2, 22, BRAZIER)
	d.call(16, 22, BRAZIER)
	d.call(34, 22, BRAZIER)
	# Floor candles
	d.call(11, 12, FLOOR_CANDLE)
	d.call(18, 11, FLOOR_CANDLE)
	d.call(9, 22, FLOOR_CANDLE)
	d.call(28, 22, FLOOR_CANDLE)

	print("Room painted with CORRECT sprite names at x=%d!" % ox)
	var packed = PackedScene.new()
	packed.pack(scene)
	var err = ResourceSaver.save(packed, "res://scenes/samples/sample_rooms.tscn")
	print("Save: %s" % ("OK" if err == OK else str(err)))
	scene.queue_free()
	quit()
