class_name StatusEffectManager
extends Node

var active_effects: Array[StatusEffect] = []
var _player: CharacterBody2D
var _buffs: Dictionary = {}  # "damage" -> {mult, timer}, "speed" -> {mult, timer}

# CONFUSED: randomized direction, changes every tick
var confused_direction: Vector2 = Vector2.ZERO

# FEARED: source position to flee from
var fear_source_pos: Vector2 = Vector2.INF

func setup(player: CharacterBody2D) -> void:
	_player = player

func apply_buff(buff_name: String, duration: float, multiplier: float) -> void:
	_buffs[buff_name] = {"mult": multiplier, "timer": duration}

func get_buff_multiplier(buff_name: String) -> float:
	if _buffs.has(buff_name):
		return 1.0 + _buffs[buff_name]["mult"]
	return 1.0

func has_buff(buff_name: String) -> bool:
	return _buffs.has(buff_name)

func get_buff_value(buff_name: String) -> float:
	if _buffs.has(buff_name):
		return _buffs[buff_name]["mult"]
	return 0.0

func get_all_buffs() -> Dictionary:
	return _buffs

## Convenience wrapper: apply status by name string (e.g. "BURNING", "POISONED")
func apply_status(status_name: String, duration: float, strength: float = 1.0) -> void:
	var type_map := {
		"BURNING": StatusEffect.Type.BURNING,
		"SLOWED": StatusEffect.Type.SLOWED,
		"POISONED": StatusEffect.Type.POISONED,
		"STUNNED": StatusEffect.Type.STUNNED,
		"FROZEN": StatusEffect.Type.FROZEN,
		"CONFUSED": StatusEffect.Type.CONFUSED,
		"FEARED": StatusEffect.Type.FEARED,
		"WEAKENED": StatusEffect.Type.WEAKENED,
		"STRENGTHENED": StatusEffect.Type.STRENGTHENED,
	}
	if type_map.has(status_name):
		apply_effect(type_map[status_name], duration, strength)

func apply_effect(type: StatusEffect.Type, duration: float, strength: float, source: Vector2 = Vector2.INF) -> void:
	# Tenacity reduces negative status duration (not for buffs like STRENGTHENED)
	if type != StatusEffect.Type.STRENGTHENED:
		var em = _player.get_node_or_null("EquipmentManager") if _player else null
		if em:
			# Tenacity is 0-1 (0.15 = 15% shorter negative statuses).
			# Capped at 0.95 so debuffs always have at least a tiny duration.
			var tenacity = em.get_tenacity()
			if tenacity > 0.0:
				duration *= (1.0 - clampf(tenacity, 0.0, 0.95))
	for e in active_effects:
		if e.type == type:
			e.duration = maxf(e.duration, duration)
			if type == StatusEffect.Type.FEARED and source != Vector2.INF:
				e.source_pos = source
				fear_source_pos = source
			return
	var effect = StatusEffect.create(type, duration, strength)
	if type == StatusEffect.Type.FEARED and source != Vector2.INF:
		effect.source_pos = source
		fear_source_pos = source
	if type == StatusEffect.Type.CONFUSED:
		confused_direction = Vector2.from_angle(randf() * TAU)
	active_effects.append(effect)
	_update_tint()

func remove_all_of_type(type: StatusEffect.Type) -> void:
	var removed := false
	for i in range(active_effects.size() - 1, -1, -1):
		if active_effects[i].type == type:
			active_effects.remove_at(i)
			removed = true
	if removed:
		_update_tint()

func remove_all_negative() -> void:
	var had_effects := active_effects.size() > 0
	var kept: Array[StatusEffect] = []
	for e in active_effects:
		if e.type == StatusEffect.Type.STRENGTHENED:
			kept.append(e)
	active_effects = kept
	if had_effects:
		_update_tint()

# --- Query helpers ---

func is_stunned() -> bool:
	for e in active_effects:
		if e.type == StatusEffect.Type.STUNNED:
			return true
	return false

func is_frozen() -> bool:
	for e in active_effects:
		if e.type == StatusEffect.Type.FROZEN:
			return true
	return false

func is_confused() -> bool:
	for e in active_effects:
		if e.type == StatusEffect.Type.CONFUSED:
			return true
	return false

func is_feared() -> bool:
	for e in active_effects:
		if e.type == StatusEffect.Type.FEARED:
			return true
	return false

func get_speed_multiplier() -> float:
	for e in active_effects:
		if e.type == StatusEffect.Type.STUNNED or e.type == StatusEffect.Type.FROZEN:
			return 0.0
		if e.type == StatusEffect.Type.SLOWED:
			return e.strength
		if e.type == StatusEffect.Type.FEARED:
			return 1.5  # faster flee
	return 1.0

func get_damage_multiplier() -> float:
	var mult := 1.0
	for e in active_effects:
		if e.type == StatusEffect.Type.WEAKENED:
			mult *= 0.5
		elif e.type == StatusEffect.Type.STRENGTHENED:
			mult *= 1.5
	return mult

func get_incoming_damage_multiplier() -> float:
	for e in active_effects:
		if e.type == StatusEffect.Type.FROZEN:
			return 1.5  # +50% damage taken while frozen
	return 1.0

func _process(delta: float) -> void:
	# Tick buff timers
	var expired_buffs: Array[String] = []
	for bname in _buffs:
		_buffs[bname]["timer"] -= delta
		if _buffs[bname]["timer"] <= 0:
			expired_buffs.append(bname)
	for bname in expired_buffs:
		_buffs.erase(bname)

	if active_effects.is_empty():
		return

	for e in active_effects:
		e.duration -= delta
		if e.tick_interval > 0:
			e._tick_timer -= delta
			if e._tick_timer <= 0:
				e._tick_timer = e.tick_interval
				_apply_tick(e)

	var removed := false
	for i in range(active_effects.size() - 1, -1, -1):
		if active_effects[i].duration <= 0:
			active_effects.remove_at(i)
			removed = true
	if removed:
		_update_tint()

func _apply_tick(effect: StatusEffect) -> void:
	match effect.type:
		StatusEffect.Type.BURNING, StatusEffect.Type.POISONED:
			if _player and _player.has_method("take_damage"):
				_player.take_damage(int(effect.strength), Vector2.INF, false, false, CombatTypes.DamageType.TRUE)
		StatusEffect.Type.CONFUSED:
			confused_direction = Vector2.from_angle(randf() * TAU)

func _update_tint() -> void:
	if not _player:
		return
	var sprite = _player.get_node_or_null("Sprite2D")
	if not sprite:
		return
	if active_effects.is_empty():
		sprite.modulate = Color.WHITE
		return
	# Priority order: STUNNED > FROZEN > BURNING > POISONED > FEARED > CONFUSED > SLOWED > WEAKENED > STRENGTHENED
	for e in active_effects:
		match e.type:
			StatusEffect.Type.STUNNED:
				sprite.modulate = Color(1.0, 1.0, 0.4)
				return
			StatusEffect.Type.FROZEN:
				sprite.modulate = Color(0.5, 0.9, 1.0)
				return
	for e in active_effects:
		match e.type:
			StatusEffect.Type.BURNING:
				sprite.modulate = Color(1.0, 0.5, 0.2)
				return
			StatusEffect.Type.POISONED:
				sprite.modulate = Color(0.5, 1.0, 0.3)
				return
			StatusEffect.Type.FEARED:
				sprite.modulate = Color(0.6, 0.2, 0.8)
				return
			StatusEffect.Type.CONFUSED:
				sprite.modulate = Color(0.8, 0.4, 1.0)
				return
			StatusEffect.Type.SLOWED:
				sprite.modulate = Color(0.4, 0.6, 1.0)
				return
			StatusEffect.Type.WEAKENED:
				sprite.modulate = Color(0.6, 0.6, 0.6)
				return
			StatusEffect.Type.STRENGTHENED:
				sprite.modulate = Color(1.0, 0.8, 0.3)
				return
