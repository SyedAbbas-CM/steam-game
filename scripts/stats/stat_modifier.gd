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
	BULLET_LIFETIME,
	MAX_MP,
	HP_REGEN,
	MP_REGEN,
	LUCK,
	CRIT_DAMAGE,
	ARMOR,
	WEIGHT,
	ACCELERATION,
	DODGE_CHANCE,
	XP_MULT,
	GOLD_MULT,
	PICKUP_RADIUS,
	COOLDOWN_REDUCTION,
	STEALTH,
}

@export var stat: StatType
@export var flat_bonus: float = 0.0
@export var percent_bonus: float = 0.0
