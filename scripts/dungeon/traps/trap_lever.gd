extends Area2D

## Interactable lever that toggles an associated SwingingAxe.
## Follows altar/shrine interaction pattern from dungeon_events.gd.

var axe # SwingingAxe - untyped to avoid class_name dependency
var _toggled: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # detect player body
	monitorable = false
	monitoring = true

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	add_child(shape)

	# Prompt label
	var prompt = Label.new()
	prompt.text = "Lever"
	prompt.add_theme_font_size_override("font_size", 6)
	prompt.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(-12, -14)
	prompt.visible = false
	add_child(prompt)
	set_meta("prompt_label", prompt)
	set_meta("event_type", "trap_lever")

	# Simple lever visual using a sprite from dungeon features
	var sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/sprites/lofi_dungeon_features.png")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(8 * 7, 8 * 1, 8, 8)  # lever/switch tile
	add_child(sprite)
	set_meta("lever_sprite", sprite)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var prompt = get_meta("prompt_label") as Label
	if prompt:
		prompt.visible = true
	# Register with dungeon manager interact system
	var dm = get_tree().get_first_node_in_group("dungeon_manager")
	if dm and "_nearby_interact_areas" in dm:
		if not self in dm._nearby_interact_areas:
			dm._nearby_interact_areas.append(self)
	if TouchControls.is_mobile():
		var tc = get_tree().get_first_node_in_group("touch_controls") as TouchControls
		if tc:
			tc.show_interact_button("Lever")

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var prompt = get_meta("prompt_label") as Label
	if prompt:
		prompt.visible = false
	var dm = get_tree().get_first_node_in_group("dungeon_manager")
	if dm and "_nearby_interact_areas" in dm:
		dm._nearby_interact_areas.erase(self)
	if TouchControls.is_mobile():
		var tc = get_tree().get_first_node_in_group("touch_controls") as TouchControls
		if tc and dm and dm._nearby_interact_areas.is_empty():
			tc.hide_interact_button()

func toggle() -> void:
	_toggled = !_toggled
	if axe and is_instance_valid(axe):
		axe.set_active(!_toggled)

	# Flip sprite to indicate toggled state
	var sprite = get_meta("lever_sprite") as Sprite2D
	if sprite:
		sprite.flip_h = _toggled

	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click", -3.0, 0.0)
