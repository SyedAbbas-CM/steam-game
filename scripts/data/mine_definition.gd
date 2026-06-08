class_name MineDefinition
extends Resource

@export var mine_id: String = ""
@export var mine_name: String = "Unknown Mine"
@export_multiline var description: String = ""
@export var darkness_level: float = 0.35
@export var danger_tier: int = 1
@export var base_difficulty: int = 0
@export var biome_theme: String = "grey"
@export var liquid_type: String = "water"  # water, lava, poison
@export var floor_count: int = 5  # number of floors in this mine
@export var prefer_cave_rooms: bool = true  # use IRREGULAR room shapes
@export var room_count_min: int = 6
@export var room_count_max: int = 9
@export var grand_cavern_chance: float = 0.22

@export_group("Structure")
@export var bounds_cells_w: int = 8
@export var bounds_cells_h: int = 7
@export var carve_density_bias: float = 0.72
@export var blocked_connection_chance: float = 0.34
@export var secret_pocket_chance: float = 0.18

@export_group("Activation")
@export var biome_aliases: PackedStringArray = PackedStringArray()
@export var force_when_biome_matches: bool = true

@export_group("Enemy Content")
@export var enemy_pool: Array[EnemyDefinition] = []
@export var elite_enemy_pool: Array[EnemyDefinition] = []

@export_group("Resource Content")
@export var material_drop_paths: PackedStringArray = PackedStringArray()
@export var rare_material_drop_paths: PackedStringArray = PackedStringArray()
@export var blueprint_ids: PackedStringArray = PackedStringArray()
@export var gem_hint_ids: PackedStringArray = PackedStringArray()

@export_group("Node Spawning")
@export var node_spawn_rooms_min: int = 3
@export var node_spawn_rooms_max: int = 5
@export var node_count_per_room_min: int = 1
@export var node_count_per_room_max: int = 2
@export var gem_node_chance: float = 0.2
@export var blueprint_fragment_chance: float = 0.15

@export_group("Terrain")
# Wall HP is rolled per-tile in [min, max]. Values are tuned for ~10 weapon damage.
@export var soft_wall_hp: int = 5
@export var soft_wall_hp_max: int = 20
@export var ore_wall_hp: int = 15
@export var ore_wall_hp_max: int = 35
@export var gem_wall_hp: int = 25
@export var gem_wall_hp_max: int = 50
@export var gas_pocket_chance: float = 0.05
@export var cave_in_chance: float = 0.03
@export var breakable_clusters_min: int = 4
@export var breakable_clusters_max: int = 8
@export var breakable_cluster_radius_min: int = 1
@export var breakable_cluster_radius_max: int = 2

@export_group("Intrusion Pressure")
@export var intrusion_interval: float = 28.0
@export var intrusion_wave_size_min: int = 1
@export var intrusion_wave_size_max: int = 3
@export var intrusion_elite_time: float = 55.0
@export var intrusion_super_time: float = 90.0
@export var max_active_intruders: int = 3
@export var intrusion_retry_interval: float = 6.0
