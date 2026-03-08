class_name StatusEffectManager
extends Node

var active_effects: Array[StatusEffect] = []
var _player: CharacterBody2D

func setup(player: CharacterBody2D) -> void:
	_player = player

func apply_effect(type: StatusEffect.Type, duration: float, strength: float) -> void:
	for e in active_effects:
		if e.type == type:
			e.duration = maxf(e.duration, duration)
			return
	active_effects.append(StatusEffect.create(type, duration, strength))
	_update_tint()

func get_speed_multiplier() -> float:
	for e in active_effects:
		if e.type == StatusEffect.Type.SLOWED:
			return e.strength
	return 1.0

func _process(delta: float) -> void:
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
