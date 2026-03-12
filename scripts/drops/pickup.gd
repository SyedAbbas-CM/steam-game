class_name Pickup
extends Area2D

var item: EquipmentItem
var gold_amount: int = 0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # detect player

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
	sprite.scale = Vector2(0.15, 0.15)

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	if gold_amount > 0:
		var gm = body.get_node_or_null("/root/GameManager")
		if gm:
			gm.add_gold(gold_amount)
		queue_free()
		return

	if item:
		var equip_mgr = body.get_node_or_null("EquipmentManager") as EquipmentManager
		if equip_mgr:
			if equip_mgr.add_to_inventory(item):
				queue_free()
