class_name CompanionDefinition
extends Resource

enum CompanionType { ARCHER, SHIELD_GUARD, HEALER_DRONE, BOMB_GOBLIN }
enum BehaviorMode { FOLLOW_BEHIND, FOLLOW_FRONT, ORBIT, RUSH_ENEMIES }

@export var companion_id: String = ""
@export var companion_name: String = ""
@export var type: CompanionType = CompanionType.ARCHER
@export var sprite_frame: int = 16
@export var hp: int = 10
@export var damage: int = 1
@export var attack_speed: float = 1.0
@export var move_speed: float = 50.0
@export var attack_range: float = 60.0
@export var behavior: BehaviorMode = BehaviorMode.FOLLOW_BEHIND
@export var follow_distance: float = 20.0
