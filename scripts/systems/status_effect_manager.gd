class_name StatusEffectManager
extends Node

var active_effects: Array[StatusEffect] = []
var _player: CharacterBody2D
var _buffs: Dictionary = {}  # "damage" -> {mult, timer}, "speed" -> {mult, timer}

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

func apply_effect(type: StatusEffect.Type, duration: float, strength: float) -> void:
	# Tenacity reduces negative status duration
	var em = _player.get_node_or_null("EquipmentManager") if _player else null
	if em:
		var tenacity = em.get_tenacity()
		if tenacity > 0.0:
			duration *= (1.0 - tenacity / 100.0)
	for e in active_effects:
		if e.type == type:
			e.duration = maxf(e.duration, duration)
			return
	active_effects.append(StatusEffect.create(type, duration, strength))
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
	# Remove all negative status effects (BURNING, POISONED, SLOWED)
	var had_effects := active_effects.size() > 0
	active_effects.clear()
	if had_effects:
		_update_tint()

func get_speed_multiplier() -> float:
	for e in active_effects:
		if e.type == StatusEffect.Type.SLOWED:
			return e.strength
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
	if _player and _player.has_method("take_damage"):
		_player.take_damage(int(effect.strength))

func _update_tint() -> void:
	if not _player:
		return
	var sprite = _player.get_node_or_null("Sprite2D")
	if not sprite:
		return
	if active_effects.is_empty():
		sprite.modulate = Color.WHITE
		return
	for e in active_effects:
		match e.type:
			StatusEffect.Type.BURNING:
				sprite.modulate = Color(1.0, 0.5, 0.2)
				return
			StatusEffect.Type.POISONED:
				sprite.modulate = Color(0.5, 1.0, 0.3)
				return
			StatusEffect.Type.SLOWED:
				sprite.modulate = Color(0.4, 0.6, 1.0)
				return
