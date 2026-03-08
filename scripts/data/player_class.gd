class_name PlayerClass
extends Resource

@export var class_name_str: String = "Warrior"
@export var description: String = ""
@export var base_hp: int = 50
@export var base_speed: float = 30.0
@export var base_damage: float = 1.0

@export_group("Resource")
@export var resource_type: String = "rage"  # "rage", "zen", "charge"
@export var resource_max: int = 10

@export_group("Combat")
@export var starting_weapon_pattern: String = "spread"  # pattern script name
@export var bullet_count: int = 1
@export var bullet_speed: float = 100.0
@export var attack_speed: float = 0.3
@export var preferred_range: float = 0.0  # 0 = no preference

@export_group("Special Ability")
@export var ability_name: String = ""
@export var ability_description: String = ""
@export var ability_cost: int = 0  # resource cost to use

@export_group("Visuals")
@export var loy_tile_index: int = 160  # LoY char sprite index
@export var sprite_color: Color = Color.WHITE
