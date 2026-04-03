class_name SpellDefinition
extends Resource

enum EffectType {
	FIRE_DAMAGE,
	ICE_DAMAGE,
	LIGHTNING_DAMAGE,
	POISON_DAMAGE,
	HOLY_DAMAGE,
	DARK_DAMAGE,
	HEAL_SELF,
	SHIELD_BUFF,
	SPEED_BUFF,
	DAMAGE_BUFF,
}

enum DeliveryType {
	PROJECTILE,
	NOVA,
	SELF,
	TOUCH,
}

@export var id: String = ""
@export var spell_name: String = ""
@export var description: String = ""
@export var effect_type: EffectType = EffectType.FIRE_DAMAGE
@export var delivery: DeliveryType = DeliveryType.PROJECTILE
@export var magnitude: int = 10
@export var duration: float = 0.0
@export var mp_cost: float = 10.0
@export var cooldown: float = 5.0
@export var bullet_count: int = 1
@export var bullet_behavior: int = 0  # 0=straight, 1=homing, 2=spread
@export var is_starter: bool = false

static func effect_name(t: EffectType) -> String:
	match t:
		EffectType.FIRE_DAMAGE: return "Fire"
		EffectType.ICE_DAMAGE: return "Ice"
		EffectType.LIGHTNING_DAMAGE: return "Lightning"
		EffectType.POISON_DAMAGE: return "Poison"
		EffectType.HOLY_DAMAGE: return "Holy"
		EffectType.DARK_DAMAGE: return "Dark"
		EffectType.HEAL_SELF: return "Heal"
		EffectType.SHIELD_BUFF: return "Shield"
		EffectType.SPEED_BUFF: return "Speed"
		EffectType.DAMAGE_BUFF: return "Damage"
	return "Unknown"

static func delivery_name(d: DeliveryType) -> String:
	match d:
		DeliveryType.PROJECTILE: return "Projectile"
		DeliveryType.NOVA: return "Nova"
		DeliveryType.SELF: return "Self"
		DeliveryType.TOUCH: return "Touch"
	return "Unknown"

static func is_self_only_effect(t: EffectType) -> bool:
	return t in [EffectType.HEAL_SELF, EffectType.SHIELD_BUFF, EffectType.SPEED_BUFF, EffectType.DAMAGE_BUFF]

static func is_damage_effect(t: EffectType) -> bool:
	return t in [EffectType.FIRE_DAMAGE, EffectType.ICE_DAMAGE, EffectType.LIGHTNING_DAMAGE, EffectType.POISON_DAMAGE, EffectType.HOLY_DAMAGE, EffectType.DARK_DAMAGE]

func to_dict() -> Dictionary:
	return {
		"id": id,
		"spell_name": spell_name,
		"description": description,
		"effect_type": int(effect_type),
		"delivery": int(delivery),
		"magnitude": magnitude,
		"duration": duration,
		"mp_cost": mp_cost,
		"cooldown": cooldown,
		"bullet_count": bullet_count,
		"bullet_behavior": bullet_behavior,
		"is_starter": is_starter,
	}

static func from_dict(d: Dictionary) -> SpellDefinition:
	var spell = SpellDefinition.new()
	spell.id = d.get("id", "")
	spell.spell_name = d.get("spell_name", "")
	spell.description = d.get("description", "")
	spell.effect_type = d.get("effect_type", 0) as EffectType
	spell.delivery = d.get("delivery", 0) as DeliveryType
	spell.magnitude = d.get("magnitude", 10)
	spell.duration = d.get("duration", 0.0)
	spell.mp_cost = d.get("mp_cost", 10.0)
	spell.cooldown = d.get("cooldown", 5.0)
	spell.bullet_count = d.get("bullet_count", 1)
	spell.bullet_behavior = d.get("bullet_behavior", 0)
	spell.is_starter = d.get("is_starter", false)
	return spell
