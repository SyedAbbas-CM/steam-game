class_name EliteAffixDefinition
extends Resource

@export_group("Identity")
@export var affix_id: String = ""
@export var display_prefix: String = ""
@export var display_suffix: String = ""
@export var min_tier: int = 0  # 0=elite, 1=hyper, 2=boss
@export var allowed_roles: Array[String] = ["any"]  # melee, ranged, support, any
@export var requires_projectiles: bool = false
@export var requires_melee: bool = false

@export_group("Behavior")
@export var movement_override: MovementPattern
@export var add_attack_types: Array[int] = []
@export var phase_2_attack: int = 0
@export var phase_3_attack: int = 0

@export_group("Scaling")
@export var hp_mult: float = 1.0
@export var damage_mult: float = 1.0
@export var move_speed_mult: float = 1.0
@export var attack_speed_mult: float = 1.0
@export var bullet_speed_mult: float = 1.0
@export var bullet_count_bonus: int = 0
@export var armor_bonus: int = 0
@export var color_tint: Color = Color.WHITE
@export var bullet_status_effect: String = ""
@export var bullet_status_duration: float = 3.0

@export_group("Projectile Modifier")
@export var homing_strength: float = 0.0
@export var bounce_count: int = 0
@export var pierce_count: int = 0
@export var speed_mult: float = 1.0
@export var sine_wave: bool = false
@export var lifetime_mult: float = 1.0
@export var push_force: float = 0.0
@export var persist_as_mine: bool = false
@export var persist_duration: float = 3.0
@export var split_after: float = 0.0
@export var split_count: int = 2
@export var apply_burning: bool = false
@export var apply_slowed: bool = false
@export var apply_poisoned: bool = false
@export var apply_stunned: bool = false
@export var explode_on_hit: bool = false
@export var explode_radius: float = 12.0
