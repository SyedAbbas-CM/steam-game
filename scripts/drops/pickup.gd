class_name Pickup
extends Area2D

var item: EquipmentItem

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # detect player

	# Create visual
	var sprite = $Sprite2D as Sprite2D
	var img = Image.create(6, 6, false, Image.FORMAT_RGBA8)
	match item.rarity if item else 0:
		0: img.fill(Color.WHITE)
		1: img.fill(Color.GREEN)
		2: img.fill(Color.CYAN)
		_: img.fill(Color.WHITE)
	sprite.texture = ImageTexture.create_from_image(img)

	body_entered.connect(_on_body_entered)

	# Bob animation
	var base_y = position.y
	var tween = create_tween().set_loops()
	tween.tween_property(self, "position:y", base_y - 3, 0.4)
	tween.tween_property(self, "position:y", base_y + 3, 0.4)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var equip_mgr = body.get_node_or_null("EquipmentManager") as EquipmentManager
		if equip_mgr:
			if equip_mgr.add_to_inventory(item):
				queue_free()
			# If inventory full, don't pick up
