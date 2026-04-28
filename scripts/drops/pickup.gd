class_name Pickup
extends Area2D

var item: EquipmentItem
var gold_amount: int = 0
var _age: float = 0.0
var _collected: bool = false

func _process(delta: float) -> void:
	_age += delta
	if _age < 0.5 or _collected:
		return
	# After 0.5s, auto-collect if player is nearby (magnet pulled it close)
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var dist = global_position.distance_to(player.global_position)
		var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
		var threshold = 40.0 if in_ow else 10.0
		if dist < threshold:
			_collected = true
			_on_body_entered(player)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # detect player
	add_to_group("pickup")

	var sprite = $Sprite2D as Sprite2D
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	if gold_amount > 0:
		# Gold pickup: gold_pile sprite from dungeon_features_32.png (tile 11,1)
		var feat_tex = load("res://assets/sprites/lofi_dungeon_features_32.png") as Texture2D
		if feat_tex:
			var atlas = AtlasTexture.new()
			atlas.atlas = feat_tex
			atlas.region = Rect2(352, 32, 32, 32)
			sprite.texture = atlas
	elif item:
		# Item pickup: use loy_tile_index from tiles.png
		var icon = ItemIconHelper.get_icon_texture(item)
		if icon:
			sprite.texture = icon
			match item.rarity:
				1: sprite.modulate = Color(0.6, 1.0, 0.6)
				2: sprite.modulate = Color(0.5, 0.8, 1.0)
		else:
			var img = Image.create(6, 6, false, Image.FORMAT_RGBA8)
			img.fill(Color.WHITE)
			sprite.texture = ImageTexture.create_from_image(img)

	# Scale down — sprites are 32x32, we want them small on the ground
	# Overworld uses 32px tiles (4x dungeon), so pickups need to be bigger
	var in_overworld = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var s = 0.3 if in_overworld else 0.15
	sprite.scale = Vector2(s, s)
	# Scale collision shape for overworld too
	if in_overworld:
		var col = $CollisionShape2D
		if col:
			col.scale = Vector2(2, 2)

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	var sfx = get_node_or_null("/root/SFXManager")
	if gold_amount > 0:
		var gm = body.get_node_or_null("/root/GameManager")
		if gm:
			gm.add_gold(gold_amount, true)
		if sfx:
			sfx.play("coin", -4.0, 0.15)
		var vfx = get_node_or_null("/root/VFXManager")
		if vfx:
			vfx.gold_sparkle(global_position)
		queue_free()
		return

	if item:
		var equip_mgr = body.get_node_or_null("EquipmentManager") as EquipmentManager
		if equip_mgr:
			if equip_mgr.add_to_inventory(item):
				if sfx:
					sfx.play("collect_a", -3.0, 0.1)
				queue_free()
