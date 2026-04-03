class_name HarvestNode
extends Area2D

@export var harvest_type: String = "herb"  # "herb", "ore", "tree", "mushroom", "bug_nest"
@export var drop_table: Array[String] = []  # Array of item .tres paths
@export var drop_count_min: int = 1
@export var drop_count_max: int = 1
@export var respawn_time: float = 90.0
@export var sprite_tile_index: int = -1  # loy_tile_index for visual (from tiles.png)
@export var collision_radius: float = 20.0
@export var sprite_scale: float = 1.0  # scale the sprite independently

var _player_nearby: bool = false
var _depleted: bool = false
var _respawn_timer: float = 0.0
var _interact_cooldown: float = 0.0
var _sprite: Sprite2D
var _interact_label: Label
var _glow_time: float = 0.0
var _base_modulate: Color = Color(1, 1, 1)
var persist_key: String = ""  # "zone_id:index" for overworld persistence

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # detect player
	monitoring = true
	monitorable = false

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = collision_radius
	shape.shape = circle
	add_child(shape)

	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	_setup_sprite()
	add_child(_sprite)

	_interact_label = Label.new()
	_interact_label.text = "Tap to Gather" if TouchControls.is_mobile() else "[E] Gather"
	_interact_label.position = Vector2(-24, 22)
	_interact_label.add_theme_font_size_override("font_size", 9)
	_interact_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	_interact_label.visible = false
	_interact_label.z_index = 5
	add_child(_interact_label)

	if TouchControls.is_mobile():
		input_pickable = true
		input_event.connect(_on_touch_interact)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Check persistence for overworld nodes
	if persist_key != "":
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.save_data and gm.save_data.get("harvested_nodes") is Dictionary:
			var harvested: Dictionary = gm.save_data.harvested_nodes
			if harvested.has(persist_key):
				var depleted_time = harvested[persist_key] as float
				var now = Time.get_unix_time_from_system()
				var elapsed = now - depleted_time
				if elapsed < respawn_time:
					_depleted = true
					_respawn_timer = respawn_time - elapsed
					_sprite.visible = false
					monitoring = false

func _setup_sprite() -> void:
	if sprite_tile_index < 0:
		return
	var tex = load("res://assets/sprites/loy/tiles.png") as Texture2D
	if not tex:
		return
	var col = sprite_tile_index % 16
	var row = sprite_tile_index / 16
	var atlas = AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(col * 32, row * 32, 32, 32)
	_sprite.texture = atlas

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _depleted:
		_player_nearby = true
		_interact_label.visible = true
		if TouchControls.is_mobile():
			var tc = get_tree().get_first_node_in_group("touch_controls") as TouchControls
			if tc:
				tc.show_interact_button("Gather")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_interact_label.visible = false
		if TouchControls.is_mobile():
			var tc = get_tree().get_first_node_in_group("touch_controls") as TouchControls
			if tc:
				tc.hide_interact_button()

func _on_touch_interact(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if _player_nearby and _interact_cooldown <= 0 and not _depleted:
			_harvest()
			_interact_cooldown = 0.5

func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby or _depleted or _interact_cooldown > 0:
		return
	if event.is_action_pressed("interact"):
		_harvest()
		_interact_cooldown = 0.5
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _interact_cooldown > 0:
		_interact_cooldown -= delta

	# Glow pulse when not depleted
	if not _depleted:
		_glow_time += delta * 2.0
		var pulse = 0.05 * sin(_glow_time)
		_sprite.modulate = Color(1.0 + pulse, 1.0 + pulse, 0.9 + pulse)

	# Respawn timer
	if _depleted and respawn_time > 0:
		_respawn_timer -= delta
		if _respawn_timer <= 0:
			_respawn()

func _harvest() -> void:
	if _depleted or drop_table.is_empty():
		return

	var sfx = get_node_or_null("/root/SFXManager")
	var vfx = get_node_or_null("/root/VFXManager")

	var drop_count = randi_range(drop_count_min, drop_count_max)
	for _i in range(drop_count):
		var item_path = drop_table[randi() % drop_table.size()]
		var item_res = load(item_path) as EquipmentItem
		if not item_res:
			continue
		var item = item_res.make_copy() as EquipmentItem

		# Try add to inventory
		var player = get_tree().get_first_node_in_group("player")
		var em = player.get_node_or_null("EquipmentManager") if player else null
		if em and em.add_to_inventory(item):
			# Floating text
			var scene_root = get_tree().current_scene
			if scene_root:
				FloatingText.spawn(scene_root, global_position + Vector2(0, -12), "+1 %s" % item.item_name, Color(0.3, 1.0, 0.4))
		else:
			# Inventory full — spawn loot bag
			var bag = LootBag.new()
			bag.items.append(item)
			bag.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
			get_tree().current_scene.add_child(bag)

	# VFX + SFX
	if vfx:
		vfx.gold_sparkle(global_position)
	if sfx:
		sfx.play("collect_a", -4.0)

	# Deplete
	_depleted = true
	_sprite.visible = false
	_interact_label.visible = false
	monitoring = false
	_player_nearby = false
	if TouchControls.is_mobile():
		var tc = get_tree().get_first_node_in_group("touch_controls") as TouchControls
		if tc:
			tc.hide_interact_button()

	# Persist for overworld
	if persist_key != "" and respawn_time > 0:
		_respawn_timer = respawn_time
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.save_data:
			if not gm.save_data.get("harvested_nodes") is Dictionary:
				gm.save_data.harvested_nodes = {}
			gm.save_data.harvested_nodes[persist_key] = Time.get_unix_time_from_system()
	elif respawn_time <= 0:
		# No respawn (dungeon nodes) — stays depleted
		pass
	else:
		_respawn_timer = respawn_time

func _respawn() -> void:
	_depleted = false
	_sprite.visible = true
	_sprite.modulate = Color(1, 1, 1, 0)
	monitoring = true

	# Remove persist key
	if persist_key != "":
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.save_data and gm.save_data.get("harvested_nodes") is Dictionary:
			gm.save_data.harvested_nodes.erase(persist_key)

	# Fade in
	var tween = create_tween()
	tween.tween_property(_sprite, "modulate", Color(1, 1, 1, 1), 0.8)
