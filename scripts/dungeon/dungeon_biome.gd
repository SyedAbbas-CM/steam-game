class_name DungeonBiome
extends Resource

@export var biome_name: String = "Unknown"
@export var theme: String = "grey"  # key into THEME_ROWS

@export_group("Enemies")
@export var enemy_pool: Array[EnemyDefinition] = []

@export_group("Environment")
@export var hazard_tiles: Array[Vector2i] = []  # atlas coords for hazard tiles
@export var decoration_tiles: Array[Vector2i] = []  # atlas coords for room decorations
@export var liquid_type: String = ""  # "lava", "poison", "water", etc.
@export var hazard_damage: int = 1
@export var hazard_interval: float = 1.0  # seconds between damage ticks

@export_group("Hazard Configuration")
@export var hazard_intensity: float = 0.0  # 0.0-1.0, fraction of room floor that becomes liquid
@export var trap_density: float = 0.02  # fraction of floor tiles becoming spike traps
@export var web_bridge_density: float = 0.0  # fraction of liquid tiles covered by walkable spider webs
@export var allowed_transitions: Array[int] = [0, 1, 2, 3]  # RoomData.TransitionType values allowed

@export_group("Floor Range")
@export var min_floor: int = 1
@export var max_floor: int = 99

@export_group("Dungeon Layout")
@export var room_count: int = 25
@export var map_width: int = 50
@export var map_height: int = 35
@export var chest_count: int = 3
@export var min_monsters: int = 1
@export var max_monsters: int = 2
@export var has_locked_doors: bool = false

@export_group("Boss")
@export var boss_name: String = ""
@export var boss_definition: EnemyDefinition

@export_group("Difficulty")
@export var difficulty_tier: int = 1  # 1=brown, 2=grey, 3=blue, 4=green, 5=red
@export var base_difficulty: int = 0  # added to floor number for enemy stat scaling

@export_group("LoY Data")
@export var loy_level_id: String = ""
@export var loy_tileset_offset: int = 0
@export var floor_count: int = 1  # total floors in this dungeon zone
