class_name DecoTiles
extends RefCounted

# Shared decoration tile constants extracted to avoid circular dependencies.
# Used by RoomBlueprints, RoomDecorator, and DungeonManager.

# Animated tiles (source 0 — lofiEnvironment row 8 for braziers, source 1 row 7 for candles)
const ANIM_BRAZIER_A = Vector2i(10, 8)
const ANIM_BRAZIER_B = Vector2i(11, 8)
const ANIM_FLOOR_CANDLE_A = Vector2i(12, 7)
const ANIM_FLOOR_CANDLE_B = Vector2i(13, 7)

# Carpet tiles (source 1)
const CARPET_VERTICAL = {"red": Vector2i(16, 2), "blue": Vector2i(17, 2), "green": Vector2i(18, 2)}
const CARPET_HORIZONTAL = {"red": Vector2i(12, 3), "blue": Vector2i(13, 3), "green": Vector2i(14, 3)}
const CARPET_CONNECTOR = {"red": Vector2i(15, 3), "blue": Vector2i(16, 3), "green": Vector2i(17, 3)}

# Existing deco constants
const DECO_THRONE = Vector2i(18, 6)
const DECO_BARREL = Vector2i(0, 0)
const DECO_CRATE = Vector2i(1, 0)
const DECO_CHEST = Vector2i(2, 0)
const DECO_SACKS = Vector2i(4, 0)
const DECO_TREASURE = Vector2i(5, 0)
const DECO_BARRICADE = Vector2i(8, 0)
const DECO_CAMPFIRE = Vector2i(10, 0)
const DECO_CANDELABRA = Vector2i(4, 1)
const DECO_BENCH = Vector2i(9, 1)
const DECO_PILLAR = Vector2i(5, 2)
const DECO_STAINED_GLASS = [Vector2i(6, 2), Vector2i(7, 2), Vector2i(8, 2)]
const DECO_CHAIR_LEFT = Vector2i(0, 2)
const DECO_CHAIR_RIGHT = Vector2i(1, 2)
const DECO_CAULDRON = Vector2i(3, 3)
const DECO_POTS = [Vector2i(4, 3), Vector2i(5, 3), Vector2i(9, 3), Vector2i(10, 3)]
const DECO_BOOK_STAND = Vector2i(9, 7)
const DECO_FLOOR_CANDLE_A = Vector2i(12, 7)
const DECO_FLOOR_CANDLE_B = Vector2i(13, 7)
const DECO_LADDER = Vector2i(2, 7)

# Array constants for scatter
const DECO_BARRELS = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
const DECO_BONES = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]
const DECO_BLOOD = [Vector2i(10, 6), Vector2i(11, 6), Vector2i(12, 6), Vector2i(13, 6), Vector2i(14, 6), Vector2i(15, 6)]
const DECO_SKULLS = [Vector2i(0, 6), Vector2i(1, 6), Vector2i(9, 6)]

# Row 0 — Barrels, Blocks, Weapon Racks
const DECO_BARREL_OPEN = Vector2i(1, 0)
const DECO_BARREL_CLUSTER_3 = Vector2i(2, 0)
const DECO_BARREL_CLUSTER_2 = Vector2i(3, 0)
const DECO_BARREL_CLUSTER_2_ALT = Vector2i(4, 0)
const DECO_SMALL_BARREL = Vector2i(5, 0)
const DECO_BLOCK = Vector2i(6, 0)
const DECO_WEAPON_RACK = Vector2i(7, 0)
const DECO_WEAPON_RACK_LEFT = Vector2i(8, 0)
const DECO_WEAPON_RACK_RIGHT = Vector2i(9, 0)

# Row 1 — Grate, Altar, Lamps, Furniture, Gold
const DECO_IRON_GRATE = Vector2i(0, 1)
const DECO_ALTAR = Vector2i(1, 1)
const DECO_LAMP_OFF = Vector2i(2, 1)
const DECO_LAMP_ON = Vector2i(3, 1)
const DECO_LAMP_FLICKER = Vector2i(4, 1)
const DECO_STOOL = Vector2i(5, 1)
const DECO_STOOL_FLIPPED = Vector2i(6, 1)
const DECO_TABLE_GLASSES_RIGHT = Vector2i(8, 1)
const DECO_TABLE_GLASSES_LEFT = Vector2i(9, 1)
const DECO_TABLE_GLASSES = Vector2i(10, 1)
const DECO_GOLD = Vector2i(11, 1)
const DECO_GOLD_LARGE = Vector2i(12, 1)
const DECO_GOLD_VERY_LARGE = Vector2i(13, 1)

# Row 2 — Chairs, Tables, Bookshelves, Wardrobes, Beds
const DECO_CHAIR_FRONT = Vector2i(2, 2)
const DECO_TABLE = Vector2i(3, 2)
const DECO_BOOKSHELF = Vector2i(4, 2)
const DECO_BOOKSHELF_LEFT = Vector2i(5, 2)
const DECO_BOOKSHELF_RIGHT = Vector2i(6, 2)
const DECO_WARDROBE = Vector2i(7, 2)
const DECO_WARDROBE_OPEN = Vector2i(8, 2)
const DECO_BED_RIGHT_RED = Vector2i(10, 2)
const DECO_BED_LEFT_RED = Vector2i(11, 2)
const DECO_BED_BLUE_LEFT = Vector2i(12, 2)
const DECO_BED_BLUE_RIGHT = Vector2i(13, 2)
const DECO_BED_GREEN_LEFT = Vector2i(14, 2)
const DECO_BED_GREEN_RIGHT = Vector2i(15, 2)
const DECO_TABLE_ROUND = Vector2i(19, 2)

# Row 3 — Cauldrons, Stone Tables
const DECO_CAULDRON_CLOSED = Vector2i(1, 3)
const DECO_CAULDRON_CRACKED = Vector2i(2, 3)
const DECO_CAULDRON_BROKEN = Vector2i(3, 3)
const DECO_STONE_TABLE = Vector2i(5, 3)
const DECO_STONE_TABLE_CRACKED = Vector2i(6, 3)
const DECO_FENCE_VERTICAL = Vector2i(9, 3)

# Row 5 — Cage, Bucket
const DECO_CAGE = Vector2i(12, 5)
const DECO_BUCKET = Vector2i(13, 5)

# Row 6 — Furnace, Water Trough, Execution
const DECO_FURNACE = Vector2i(16, 6)
const DECO_WATER_TROUGH = Vector2i(17, 6)
const DECO_HEAD_CHOPPING_BLOCK = Vector2i(19, 6)

# Row 7 — Displays, Crafting, Chests
const DECO_CANDLE_STAND = Vector2i(0, 7)
const DECO_POTION_CABINET = Vector2i(1, 7)
const DECO_ARMOR_DISPLAY = Vector2i(3, 7)
const DECO_WEAPON_DISPLAY_WALL = Vector2i(4, 7)
const DECO_CHEST_OPEN_GOLD = Vector2i(5, 7)
const DECO_CHEST_OPEN_SILVER = Vector2i(6, 7)
const DECO_CHEST_OPEN_BRONZE = Vector2i(7, 7)
const DECO_LARGE_CHEST_CLOSED = Vector2i(10, 7)
const DECO_ADVANCED_WEAPON_RACK = Vector2i(11, 7)
const DECO_ANVIL = Vector2i(14, 7)
const DECO_LEVER_RIGHT = Vector2i(15, 7)
const DECO_LEVER_LEFT = Vector2i(16, 7)
const DECO_TRAINING_DUMMY = Vector2i(17, 7)
const DECO_BLOOD_ALTAR = Vector2i(18, 7)
const DECO_CLOSED_CHEST = Vector2i(19, 7)

# Row 8
const DECO_EXPLOSIVE_BARREL = Vector2i(6, 8)
const DECO_BELL = Vector2i(9, 8)
const DECO_GOLDEN_STATUE = Vector2i(17, 8)
