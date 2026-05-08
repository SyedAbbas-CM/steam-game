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
				body.take_damage(damage, global_position, false, false, CombatTypes.DamageType.TRUE)
				_spawn_damage_text(body)
			if status_effect_type >= 0:
				var sem = body.get_node_or_null("StatusEffectManager")
				if sem:
					sem.apply_effect(status_effect_type as StatusEffect.Type, status_duration, status_strength)

func _spawn_damage_text(body: Node2D) -> void:
	var scene_root = get_tree().current_scene if is_inside_tree() else null
	if scene_root == null:
		return
	var color := Color(1.0, 0.45, 0.2)  # default lava/burn orange
	if status_effect_type == StatusEffect.Type.POISONED:
		color = Color(0.55, 0.95, 0.4)
	elif status_effect_type == StatusEffect.Type.SLOWED:
		color = Color(0.6, 0.85, 1.0)
	FloatingText.spawn(scene_root, body.global_position + Vector2(0, -8), str(damage), color)

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
