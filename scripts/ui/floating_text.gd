class_name FloatingText
extends Node2D

## Small label that floats up and fades out. Used for damage numbers, XP, gold, etc.

var _label: Label

## Spawn reward text (XP, gold) — small and subtle
static func spawn(parent: Node, pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	_create(parent, pos, text, color, 5, -12, 0.9)

## Spawn damage number — always red, punchier with slight random X offset
static func spawn_damage(parent: Node, pos: Vector2, amount: int, _color: Color = Color.RED) -> void:
	var offset_x = randf_range(-3, 3)
	var ft = _create(parent, pos + Vector2(offset_x, -4), str(amount), Color(1.0, 0.2, 0.15), 6, -14, 0.7)
	if ft:
		ft._label.scale = Vector2(1.2, 1.2)
		var shrink = ft.create_tween()
		shrink.tween_property(ft._label, "scale", Vector2(1.0, 1.0), 0.12)

static func _create(parent: Node, pos: Vector2, text: String, color: Color, font_size: int, float_dist: float, duration: float) -> FloatingText:
	var ft = FloatingText.new()
	ft.global_position = pos

	ft._label = Label.new()
	ft._label.text = text

	# Use LabelSettings for clean outline rendering
	var settings = LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_size = 2
	settings.outline_color = Color(0, 0, 0, 0.9)
	ft._label.label_settings = settings

	ft._label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var char_width = font_size * 0.55
	var est_width = text.length() * char_width
	ft._label.custom_minimum_size.x = est_width + 10
	ft._label.position = Vector2(-est_width / 2 - 5, -font_size)
	ft._label.z_index = 100
	ft.add_child(ft._label)
	parent.add_child(ft)

	var tween = ft.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ft, "position:y", ft.position.y + float_dist, duration)
	tween.tween_property(ft._label, "modulate:a", 0.0, duration).set_delay(duration * 0.4)
	tween.set_parallel(false)
	tween.tween_callback(ft.queue_free)
	return ft
