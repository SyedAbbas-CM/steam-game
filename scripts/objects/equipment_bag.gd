class_name EquipmentBag
extends Area2D
## Physical bag in the game world. Walk near it and press interact to open inventory.

var player_nearby: bool = false
var prompt_label: Label

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # detect player
	add_to_group("equipment_bag")

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Visual: small bag sprite (code-built)
	var sprite = Sprite2D.new()
	var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	# Brown bag shape
	for x in range(1, 7):
		for y in range(2, 7):
			img.set_pixel(x, y, Color(0.55, 0.35, 0.15))
	# Bag top / tie
	for x in range(2, 6):
		img.set_pixel(x, 1, Color(0.65, 0.45, 0.2))
	img.set_pixel(3, 0, Color(0.7, 0.5, 0.25))
	img.set_pixel(4, 0, Color(0.7, 0.5, 0.25))
	# Highlight
	for y in range(3, 6):
		img.set_pixel(2, y, Color(0.65, 0.45, 0.2))
	sprite.texture = ImageTexture.create_from_image(img)
	add_child(sprite)

	# Collision shape
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)

	# "Press [I]" prompt
	prompt_label = Label.new()
	prompt_label.text = "[I] Bag"
	prompt_label.position = Vector2(-14, -14)
	var settings = LabelSettings.new()
	settings.font_size = 6
	settings.font_color = Color(1, 1, 0.7)
	settings.outline_size = 1
	settings.outline_color = Color(0, 0, 0)
	prompt_label.label_settings = settings
	prompt_label.visible = false
	add_child(prompt_label)

	# Idle bob
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -2.0, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_SINE)

func _process(_delta: float) -> void:
	if player_nearby and Input.is_action_just_pressed("inventory"):
		_open_inventory()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = true
		prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		prompt_label.visible = false

func _open_inventory() -> void:
	var inv_screen = get_tree().get_first_node_in_group("inventory_screen")
	if inv_screen:
		inv_screen.toggle()
