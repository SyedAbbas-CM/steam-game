class_name WarTable
extends Area2D

## Interactable War Table object — opens Army Management Screen when player presses E.
## Placed near the elder/leader NPC in town zones.

var _label: Label
var _sprite: Sprite2D
var _player_nearby: bool = false

func _ready() -> void:
	add_to_group("war_table")
	collision_layer = 0
	collision_mask = 1  # detect player (layer 1)
	monitoring = true
	monitorable = false

	# Collision shape
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 64.0
	shape.shape = circle
	add_child(shape)

	# Sprite — dungeon features table (32px, normal size)
	_sprite = Sprite2D.new()
	var tex = load("res://assets/sprites/lofi_dungeon_features_32.png") as Texture2D
	if tex:
		_sprite.texture = tex
		_sprite.hframes = 12
		_sprite.vframes = 9
		_sprite.frame = 13  # small wooden table (row 1, col 1)
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		var fallback := ColorRect.new()
		fallback.color = Color(0.6, 0.4, 0.2)
		fallback.size = Vector2(32, 32)
		fallback.position = Vector2(-16, -16)
		add_child(fallback)
	add_child(_sprite)

	# Name label
	var name_label := Label.new()
	name_label.text = "War Table"
	name_label.position = Vector2(-28, -28)
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	name_label.z_index = 5
	add_child(name_label)

	# Interaction label (shown when player nearby)
	_label = Label.new()
	_label.text = "[E] Army  [M] Map"
	_label.position = Vector2(-36, 16)
	_label.add_theme_font_size_override("font_size", 9)
	_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	_label.visible = false
	_label.z_index = 5
	add_child(_label)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby:
		return
	if event.is_action_pressed("interact"):
		_open_army_management()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("world_map"):
		_open_world_map()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("world_map"):
		_open_world_map()
		get_viewport().set_input_as_handled()

func _open_army_management() -> void:
	# Check if already open
	var existing = get_tree().get_first_node_in_group("army_management")
	if existing:
		return
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("open", -5.0)
	var screen = load("res://scripts/ui/army_management_screen.gd")
	if screen:
		var ui = screen.new()
		get_tree().root.add_child(ui)

func _open_world_map() -> void:
	var existing = get_tree().get_first_node_in_group("world_map")
	if existing:
		if existing.has_method("toggle"):
			existing.toggle()
		return
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("open", -5.0)
	var WorldMapScreen = load("res://scripts/ui/world_map_screen.gd")
	if WorldMapScreen:
		var map = WorldMapScreen.new()
		get_tree().root.add_child(map)
		map.toggle()
