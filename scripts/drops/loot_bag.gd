class_name LootBag
extends Area2D

## A dropped bag in the game world containing items and gold.
## When the player walks near it, the LootBagUI shows its contents.

var items: Array[EquipmentItem] = []
var gold: int = 0
var _player_nearby: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # detect player
	add_to_group("loot_bag")

	# Collision shape
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	add_child(shape)

	# Bag sprite from chars.png (tile 2,5 = "Bag")
	var sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex = load("res://assets/sprites/loy/chars.png") as Texture2D
	if tex:
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(64, 160, 32, 32)
		sprite.texture = atlas
		sprite.scale = Vector2(0.18, 0.18)
	else:
		var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.55, 0.35, 0.15))
		sprite.texture = ImageTexture.create_from_image(img)
	add_child(sprite)

	# Glow based on best item rarity
	var best_rarity = 0
	for item in items:
		best_rarity = maxi(best_rarity, item.rarity)
	match best_rarity:
		1: sprite.modulate = Color(0.6, 1.0, 0.6)  # uncommon green
		2: sprite.modulate = Color(0.5, 0.8, 1.0)  # rare blue

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_nearby = true

	# Auto-collect gold
	if gold > 0:
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.add_gold(gold)
		gold = 0

	# Show bag UI
	_notify_bag_ui(true)

	# If bag is empty after gold collection, destroy
	if items.is_empty():
		queue_free()

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_nearby = false
	_notify_bag_ui(false)

func _notify_bag_ui(opened: bool) -> void:
	var ui = get_tree().get_first_node_in_group("loot_bag_ui")
	if ui and ui.has_method("show_bag"):
		if opened:
			ui.show_bag(self)
		else:
			ui.hide_bag(self)

func remove_item(index: int) -> EquipmentItem:
	if index < 0 or index >= items.size():
		return null
	var item = items[index]
	items.remove_at(index)
	# If bag is now empty, destroy it
	if items.is_empty():
		_notify_bag_ui(false)
		queue_free()
	return item

func is_empty() -> bool:
	return items.is_empty() and gold <= 0
