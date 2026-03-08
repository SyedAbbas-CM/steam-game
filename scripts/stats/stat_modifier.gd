class_name StatModifier
extends Resource

enum StatType {
	MAX_HP,
	MOVE_SPEED,
	ATTACK_DAMAGE,
	ATTACK_SPEED,
	BULLET_SPEED,
	BULLET_COUNT,
	SPREAD_ANGLE,
	PIERCE_COUNT,
	BULLET_LIFETIME
}

@export var stat: StatType
@export var flat_bonus: float = 0.0
@export var percent_bonus: float = 0.0
