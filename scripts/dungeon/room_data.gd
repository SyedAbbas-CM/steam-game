class_name RoomData
extends Resource

enum RoomType { COMBAT, TREASURE, SHRINE, ELITE, BOSS, SHOP, SUPER_ELITE }
enum RoomShape { RECTANGLE, WIDE_RECT, TALL_RECT, CIRCLE, L_SHAPE_NE, L_SHAPE_NW, L_SHAPE_SE, L_SHAPE_SW, IRREGULAR, TINY, ARENA, GRAND_HALL }
enum TransitionType { OPEN, BREAKABLE_WALL, KEY_LOCKED, INTERACT_OPEN }
enum EncounterType { STANDARD, AMBUSH, HORDE, GAUNTLET, REST, ARENA }

@export var type: RoomType = RoomType.COMBAT
var encounter_type: EncounterType = EncounterType.STANDARD
@export var enemy_count: int = 3
@export var enemy_hp_mult: float = 1.0
@export var enemy_damage_mult: float = 1.0
@export var difficulty_tier: int = 1
var cleared: bool = false

# Grid position on the floor map
var grid_pos: Vector2i = Vector2i.ZERO
# Connected directions (keys present = open doorway)
var connections: Dictionary = {}  # "north"/"south"/"east"/"west" -> neighbor grid_pos
# Whether this room has stairs down to next floor
var has_stairs_down: bool = false
# Whether this room has stairs up to previous floor (or overworld)
var has_stairs_up: bool = false

# Room shape
var shape: RoomShape = RoomShape.RECTANGLE
var shape_width: int = 17
var shape_height: int = 15
var floor_mask: Array = []  # 2D bool array: floor_mask[y][x] = true means floor

# Transition types per connection direction
var transition_types: Dictionary = {}  # "north"/"south"/"east"/"west" -> TransitionType

# Key tracking for KEY_LOCKED transitions
var keys_collected: int = 0
var keys_needed: int = 0

# Dirt room: entire floor uses dirt tiles instead of normal floor
var is_dirt_room: bool = false

# Fixed enemy for test arenas — overrides pool selection
var fixed_enemy_name: String = ""
