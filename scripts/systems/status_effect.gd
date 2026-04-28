class_name StatusEffect
extends RefCounted

enum Type { BURNING, SLOWED, POISONED, STUNNED, FROZEN, CONFUSED, FEARED, WEAKENED, STRENGTHENED }

var type: Type
var duration: float
var strength: float  # DOT damage per tick, speed mult for SLOWED, or misc per type
var tick_interval: float = 1.0
var _tick_timer: float = 0.0
var source_pos: Vector2 = Vector2.INF  # used by FEARED to know which direction to flee

static func create(effect_type: Type, dur: float, str_val: float) -> StatusEffect:
	var e = StatusEffect.new()
	e.type = effect_type
	e.duration = dur
	e.strength = str_val
	match effect_type:
		Type.BURNING:
			e.tick_interval = 0.5
		Type.POISONED:
			e.tick_interval = 1.0
		Type.CONFUSED:
			e.tick_interval = 0.5  # re-randomize direction every 0.5s
		Type.SLOWED, Type.STUNNED, Type.FROZEN, Type.FEARED, Type.WEAKENED, Type.STRENGTHENED:
			e.tick_interval = 0.0  # continuous, no tick
	e._tick_timer = e.tick_interval
	return e
