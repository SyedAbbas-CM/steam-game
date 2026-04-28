class_name LootBag
extends Area2D

## A dropped bag in the game world containing items and gold.
## When the player walks near it, the LootBagUI shows its contents.

var items: Array[EquipmentItem] = []
var gold: int = 0
var _player_nearby: bool = false
var _age: float = 0.0
var _collected: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # detect player
	add_to_group("loot_bag")

	# Collision shape — bigger in overworld for easier pickup
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	var in_ow2 = get_tree() and get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	circle.radius = 24.0 if in_ow2 else 10.0
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
		# Scale up in overworld (32px tiles), smaller in dungeon (8px tiles)
		var in_ow = get_tree() and get_tree().current_scene and get_tree().current_scene.name == "Overworld"
		if in_ow:
			sprite.scale = Vector2(0.7, 0.7)  # 4x bigger than before
		else:
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

func _process(delta: float) -> void:
	_age += delta
	if _age < 0.25 or _collected:
		return
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var dist = global_position.distance_to(player.global_position)
	var pickup_radius := 48.0
	if "equipment_manager" in player and player.equipment_manager:
		pickup_radius = player.equipment_manager.get_pickup_radius()
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	if in_ow:
		pickup_radius *= 4.0
	# Magnet: pull toward player
	if dist < pickup_radius and dist > 4.0:
		var dir = (player.global_position - global_position).normalized()
		var speed = 160.0 if in_ow else 80.0
		global_position += dir * speed * delta
	# Auto-collect when close
	if dist < (16.0 if in_ow else 6.0):
		_collected = true
		_auto_collect(player)

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

	# SFX: bag open
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("open", -3.0)
	# Show bag UI
	_notify_bag_ui(true)

	# If bag is empty after gold collection, destroy
	if items.is_empty():
		queue_free()

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_nearby = false
	# Only hide if this bag is the one currently shown
	var ui = get_tree().get_first_node_in_group("loot_bag_ui")
	if ui and ui.get("_current_bag") == self:
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

func _auto_collect(player: Node2D) -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	# Collect gold
	if gold > 0:
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.add_gold(gold, true)
		gold = 0
		if sfx:
			sfx.play("coin", -4.0, 0.15)
		var vfx = get_node_or_null("/root/VFXManager")
		if vfx:
			vfx.gold_sparkle(global_position)
	# Collect items into inventory
	var em = player.get_node_or_null("EquipmentManager") as EquipmentManager
	if not em and "equipment_manager" in player:
		em = player.equipment_manager
	if em:
		for item in items:
			em.add_to_inventory(item)
		if items.size() > 0 and sfx:
			sfx.play("collect_a", -3.0, 0.1)
	items.clear()
	_notify_bag_ui(false)
	queue_free()

func is_empty() -> bool:
	return items.is_empty() and gold <= 0
