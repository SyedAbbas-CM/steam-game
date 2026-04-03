class_name TestChest
extends Area2D

## A large chest in the overworld containing items. Opens a scrollable chest UI.

var items: Array[EquipmentItem] = []
var chest_label: String = "Chest"
var _player_nearby: bool = false
var _prompt: Label

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	add_to_group("test_chest")

	# Collision shape — scale for dungeon vs overworld
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	if has_meta("dungeon_scale"):
		rect.size = Vector2(8, 6)
	else:
		rect.size = Vector2(28, 20)
	shape.shape = rect
	add_child(shape)

	# Chest sprite from lofiEnvironment (chest tile) — use code-built 16x12 chest
	var sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var img = Image.create(16, 12, false, Image.FORMAT_RGBA8)
	# Brown box body
	for x in range(1, 15):
		for y in range(3, 11):
			img.set_pixel(x, y, Color(0.5, 0.3, 0.1))
	# Lid (darker)
	for x in range(0, 16):
		for y in range(0, 4):
			img.set_pixel(x, y, Color(0.4, 0.22, 0.08))
	# Metal bands
	for x in range(0, 16):
		img.set_pixel(x, 4, Color(0.6, 0.6, 0.4))
		img.set_pixel(x, 11, Color(0.6, 0.6, 0.4))
	# Lock/latch
	for x in range(6, 10):
		for y in range(1, 3):
			img.set_pixel(x, y, Color(0.8, 0.7, 0.2))
	# Highlights
	for y in range(5, 10):
		img.set_pixel(2, y, Color(0.6, 0.38, 0.15))
	sprite.texture = ImageTexture.create_from_image(img)
	# Scale down in dungeon (8px tiles) vs overworld (32px tiles)
	if has_meta("dungeon_scale"):
		sprite.scale = Vector2(0.75, 0.75)
	else:
		sprite.scale = Vector2(4, 4)
	add_child(sprite)

	# Prompt label
	_prompt = Label.new()
	_prompt.text = "[E] " + chest_label
	var is_dungeon = has_meta("dungeon_scale")
	_prompt.position = Vector2(-20, -14) if is_dungeon else Vector2(-30, -40)
	var settings = LabelSettings.new()
	settings.font_size = 6 if is_dungeon else 8
	settings.font_color = Color(1, 1, 0.7)
	settings.outline_size = 1 if is_dungeon else 2
	settings.outline_color = Color(0, 0, 0)
	_prompt.label_settings = settings
	_prompt.visible = false
	add_child(_prompt)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if _player_nearby and Input.is_action_just_pressed("interact"):
		_open_chest()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_prompt.visible = false

func _open_chest() -> void:
	var chest_ui = get_tree().get_first_node_in_group("chest_ui")
	if chest_ui and chest_ui.has_method("show_chest"):
		chest_ui.show_chest(self)
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("open", -3.0)
