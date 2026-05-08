class_name PlayerStats
extends Resource

@export_group("Core")
@export var max_hp: int = 30
@export var move_speed: float = 130.0
@export var attack_damage: int = 0
@export var attack_speed: float = 0.2

@export_group("Ranged")
@export var bullet_speed: float = 600.0
@export var bullet_count: int = 1
@export var spread_angle: float = 0.0
@export var pierce_count: int = 0
@export var bullet_lifetime: float = 3.0

@export_group("Resource")
@export var max_mp: float = 20.0
@export var hp_regen: float = 0.4  # base 0.4 HP/sec = 1 HP per 2.5s
@export var mp_regen: float = 0.0  # bonus from equipment only

@export_group("Combat")
@export var luck: float = 0.0
@export var crit_damage: float = 1.5
@export var armor: float = 0.0

@export_group("Physics")
@export var weight: float = 1.0
@export var acceleration: float = 1.0

@export_group("Utility")
@export var dodge_chance: float = 0.0
@export var xp_mult: float = 1.0
@export var gold_mult: float = 1.0
@export var pickup_radius: float = 24.0
@export var cooldown_reduction: float = 0.0
@export var stealth: float = 0.0  # reduces enemy aggro range by stealth% (0-100)

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_regen: float = 15.0

@export_group("Defense")
@export var tenacity: float = 0.0  # reduces negative status effect duration (0-80%)
@export var thorns: float = 0.0  # flat damage reflected to enemies on contact
