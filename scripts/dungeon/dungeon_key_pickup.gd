class_name DungeonKeyPickup
extends Area2D

signal key_collected(key_id: String)

var key_id: String = ""

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # detect player
	body_entered.connect(_on_body_entered)

	# Visual: simple key sprite using a label for now
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8
	shape.shape = circle
	add_child(shape)

	var label = Label.new()
	label.text = "KEY"
	label.position = Vector2(-12, -8)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color.GOLD)
	label.z_index = 5
	add_child(label)

	# Bobbing animation
	var tween = create_tween().set_loops()
	tween.tween_property(self, "position:y", position.y - 4, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:y", position.y + 4, 0.5).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("collect_b", -2.0, 0.0)
		key_collected.emit(key_id)
		queue_free()
