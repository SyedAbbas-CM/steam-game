class_name AttackModifier
extends Resource

@export_group("Projectile Behavior")
@export var homing_strength: float = 0.0  ## 0=straight, 0.3=gentle curve, 0.8+=aggressive seeking
@export var bounce_count: int = 0  ## extra wall bounces added to bullets
@export var pierce_count: int = 0  ## extra pierces added to bullets
@export var speed_mult: float = 1.0  ## bullet speed multiplier
@export var sine_wave: bool = false  ## bullet oscillates in sine wave pattern
@export var lifetime_mult: float = 1.0  ## multiply bullet lifetime (2.0 = lasts twice as long)
@export var push_force: float = 0.0  ## knockback force on player hit (0=none)

@export_group("Persistence")
@export var persist_as_mine: bool = false  ## bullet stops at end of life and stays as hazard
@export var persist_duration: float = 3.0  ## how long the mine persists

@export_group("Split / Multiply")
@export var split_after: float = 0.0  ## seconds until split (0=no split)
@export var split_count: int = 3  ## bullets per split

@export_group("Status Effects")
@export var apply_burning: bool = false
@export var apply_slowed: bool = false
@export var apply_poisoned: bool = false
@export var apply_stunned: bool = false

@export_group("AoE")
@export var explode_on_hit: bool = false  ## fireball-style AoE on impact
@export var explode_radius: float = 12.0

@export_group("Movement Coupling")
@export var requires_stationary: bool = false  ## enemy stops moving to fire
@export var min_fire_distance: float = 0.0  ## won't fire if closer than this (0=no limit)
@export var max_fire_distance: float = 0.0  ## won't fire if farther (0=no limit)
@export var aim_at_player: bool = true  ## false = fire at self position (mines/traps)
