class_name BossShotPattern
extends Resource

enum AimMode {
	AT_PLAYER,
	FIXED_ANGLE,
	SPINNING
}

enum PatternFamily {
	BASIC,
	ROSE,
	LISSAJOUS,
	CYCLOID,
	LOG_SPIRAL,
	FRACTAL_FAN,
	RECURSIVE_FAN
}

@export_group("Shape")
@export var shot_count: int = 1
@export var spread_degrees: float = 0.0
@export var symmetric_spread: bool = true
@export var base_angle_offset_degrees: float = 0.0
@export var ring_pattern: bool = false
@export var pattern_family: PatternFamily = PatternFamily.BASIC

@export_group("Burst")
@export var burst_count: int = 1
@export var burst_interval: float = 0.12
@export var rotate_per_burst_degrees: float = 0.0

@export_group("Aim")
@export var aim_mode: AimMode = AimMode.AT_PLAYER
@export var fixed_angle_degrees: float = 0.0
@export var spinning_speed_degrees: float = 90.0

@export_group("Projectile")
@export var bullet_speed_mult: float = 1.0
@export var damage_override: int = -1
@export var sprite_scale_mult: float = 1.0
@export var movement_pattern: MovementPattern
@export var orbit_radius_override: float = -1.0
@export var orbit_radial_speed: float = 0.0
@export var orbit_radial_accel: float = 0.0
@export var orbit_reverse_time: float = -1.0
@export var bounce_count_override: int = -1
@export var bullet_behavior_override: int = -1
@export var modifier_override: AttackModifier

@export_group("Status")
@export var status_effect: String = ""
@export var status_duration: float = 3.0

@export_group("Math Pattern")
@export var use_seed_variation: bool = false
@export var seed_value: int = 1
@export var seed_step_per_burst: int = 97
@export var angle_jitter_degrees: float = 0.0
@export var param_jitter: float = 0.0
@export var rose_petals: int = 3
@export var lissajous_a: float = 3.0
@export var lissajous_b: float = 2.0
@export var lissajous_delta_degrees: float = 90.0
@export var cycloid_ratio: float = 3.0
@export var cycloid_inner: bool = false
@export var logarithmic_growth: float = 0.18
@export var recursive_depth: int = 2
@export var recursive_branch_angle_degrees: float = 18.0
@export var recursive_branch_scale: float = 0.7
@export var recursive_spawn_scale_jitter: float = 0.0
