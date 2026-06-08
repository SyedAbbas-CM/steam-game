class_name EliteArchetypeDefinition
extends Resource

@export_group("Identity")
@export var archetype_id: String = ""
@export var display_prefix: String = ""
@export var display_suffix: String = ""
@export var allowed_roles: Array[String] = ["any"]  # melee, ranged, support, any

@export_group("Behavior")
@export var movement_pattern: MovementPattern
@export var forced_attack_type: int = 0  # EnemyDefinition.AttackType.NONE = 0
@export var attack_pool: Array[int] = []
@export var phase_2_attack: int = 0
@export var phase_3_attack: int = 0
@export var summon_on_phase_change: bool = false
@export var summon_phase_count: int = 0

@export_group("Scaling")
@export var hp_mult: float = 1.0
@export var damage_mult: float = 1.0
@export var move_speed_mult: float = 1.0
@export var attack_speed_mult: float = 1.0
@export var bullet_speed_mult: float = 1.0
@export var bullet_count_bonus: int = 0
@export var armor_bonus: int = 0
@export var color_tint: Color = Color.WHITE
