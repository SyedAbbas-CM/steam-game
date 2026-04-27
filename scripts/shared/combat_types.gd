class_name CombatTypes

enum DamageType { NORMAL, PIERCE, SIEGE, MAGIC, CHAOS, HERO, TRUE }
enum ArmorType { UNARMORED, LIGHT, MEDIUM, HEAVY, FORTIFIED, HERO }

#                    Unarm  Light  Med    Heavy  Fort   Hero
const DAMAGE_MULT = [
	[1.0,   1.0,   1.5,   1.0,   0.7,   1.0],   # NORMAL
	[1.5,   2.0,   0.75,  1.0,   0.35,  1.0],   # PIERCE
	[1.0,   1.0,   1.0,   1.5,   1.5,   1.0],   # SIEGE
	[1.0,   1.25,  0.75,  2.0,   0.35,  1.0],   # MAGIC
	[1.0,   1.0,   1.0,   1.0,   1.0,   1.0],   # CHAOS
	[1.0,   1.0,   1.0,   1.0,   0.5,   1.0],   # HERO
	[1.0,   1.0,   1.0,   1.0,   1.0,   1.0],   # TRUE (bypasses armor)
]

static func apply_combat_damage(raw: int, dmg_type: int, armor_type: int, flat_armor: int, min_dmg: int = 1) -> int:
	if dmg_type == DamageType.TRUE:
		return raw
	var mult: float = DAMAGE_MULT[dmg_type][armor_type]
	var typed: int = int(ceil(float(raw) * mult))
	if flat_armor > 0:
		typed = maxi(min_dmg, typed - flat_armor)
	return typed
