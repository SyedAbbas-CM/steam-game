class_name HazardArea
extends Area2D

var damage: int = 1
var interval: float = 1.0
var status_effect_type: int = -1  # StatusEffect.Type or -1 for none
var status_duration: float = 3.0
var status_strength: float = 1.0
var _timer: float = 0.0
var _bodies_inside: Array[Node2D] = []

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # detect player
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if _bodies_inside.is_empty():
		return
	_timer -= delta
	if _timer <= 0:
		_timer = interval
		for body in _bodies_inside:
			if not is_instance_valid(body):
				continue
			if damage > 0 and body.has_method("take_damage"):
				body.take_damage(damage)
			if status_effect_type >= 0:
				var sem = body.get_node_or_null("StatusEffectManager")
				if sem:
					sem.apply_effect(status_effect_type as StatusEffect.Type, status_duration, status_strength)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_bodies_inside.append(body)
		_timer = 0.3
		# Apply status effect immediately on contact
		if status_effect_type >= 0:
			var sem = body.get_node_or_null("StatusEffectManager")
			if sem:
				sem.apply_effect(status_effect_type as StatusEffect.Type, status_duration, status_strength)

func _on_body_exited(body: Node2D) -> void:
	_bodies_inside.erase(body)
