class_name MutationDefinition
extends Resource

enum MutationType {
	BULLET_PIERCE,
	LIFE_STEAL,
	HOMING_SHOTS,
	EXPLODING_BULLETS,
	CHAIN_LIGHTNING,
	PROJECTILE_SPLIT,
	FIRE_TRAIL,
	DASH_SHOCKWAVE,
	RICOCHET,
	FREEZE_AURA,
	VAMPIRIC_BURST,
	SHIELD_ON_KILL
}

@export var mutation_id: String = ""
@export var mutation_name: String = ""
@export var description: String = ""
@export var type: MutationType = MutationType.BULLET_PIERCE
@export var icon: Texture2D
@export var tier: int = 1
@export var strength: float = 1.0
@export var max_stacks: int = 3
@export var tags: Array[String] = []
