class_name NPC
extends Area2D

@export var npc_name: String = ""
@export var loy_tile: int = 0
@export var npc_type: String = ""
@export var script_file: String = ""
@export var dialogue_text: String = ""
@export var portrait_tile: int = 0
@export var shop_id: String = ""
@export var zone_id: String = ""

var _sprite: Sprite2D
var _label: Label
var _interact_label: Label
var _player_nearby: bool = false
var _chars_texture: Texture2D
var _chars2_texture: Texture2D
var _animator: SpriteAnimator

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	_chars_texture = load("res://assets/sprites/loy/chars.png") as Texture2D
	_chars2_texture = load("res://assets/sprites/loy/chars2.png") as Texture2D

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 48
	shape.shape = circle
	add_child(shape)

	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_setup_sprite()
	add_child(_sprite)

	_label = Label.new()
	_label.text = npc_name
	_label.position = Vector2(-30, -30)
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_label.z_index = 5
	add_child(_label)

	_interact_label = Label.new()
	_interact_label.text = "[E] Talk"
	_interact_label.position = Vector2(-20, 22)
	_interact_label.add_theme_font_size_override("font_size", 9)
	_interact_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	_interact_label.visible = false
	_interact_label.z_index = 5
	add_child(_interact_label)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _setup_sprite() -> void:
	if loy_tile <= 0:
		return
	var tex = _chars_texture if loy_tile < 256 else _chars2_texture
	if not tex:
		return
	var idx = loy_tile % 256
	var col = idx % 16
	var row = idx / 16
	var atlas = AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(col * 32, row * 32, 32, 32)
	_sprite.texture = atlas

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_interact_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_interact_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby:
		return
	if event.is_action_pressed("interact") and not _is_dialogue_open():
		interact()
		get_viewport().set_input_as_handled()

func _is_dialogue_open() -> bool:
	var qm = get_node_or_null("/root/QuestManager")
	return qm and qm._waiting_for_dialogue

func interact() -> void:
	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		return

	# Notify quest system of NPC activation (for delivery quests)
	if npc_name != "":
		qm.on_npc_activated(npc_name)

	match npc_type:
		"scriptfile":
			if script_file != "":
				var clean_name = script_file.replace("scripts/", "").replace(".xml", "")
				qm.run_npc_script(clean_name)
			else:
				_show_simple_dialogue()
		"elder":
			_offer_zone_quests()
		"shop":
			if shop_id != "":
				_open_shop()
			else:
				_show_simple_dialogue()
		"tips":
			# Tips NPCs have script-based dialogues
			if npc_name == "Hawkeye":
				qm.run_npc_script("tips2")
			elif qm.npc_scripts.has("tips"):
				qm.run_npc_script("tips")
			else:
				_show_simple_dialogue()
		"message":
			_show_simple_dialogue()
		_:
			_show_simple_dialogue()

func _show_simple_dialogue() -> void:
	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		return
	var text = dialogue_text
	if text == "":
		# Generate fallback dialogue based on NPC type
		match npc_type:
			"shop":
				text = "Welcome! Take a look at my wares."
			"elder":
				text = "Greetings, adventurer. Seek me out when you're ready for a quest."
			"scriptfile":
				text = "I have much to tell you, but not right now."
			"trainer":
				text = "Train hard, adventurer. Strength comes from practice."
			"craft":
				_open_enchant_station()
				return
			"pets":
				text = "Looking for a loyal companion? I might be able to help."
			"maps":
				text = "I sell maps of the surrounding lands."
			"tips":
				text = "Let me give you some advice, adventurer."
			_:
				text = "Greetings, traveler."
	qm._waiting_for_dialogue = true
	qm.show_dialogue_requested.emit(npc_name, portrait_tile, text, ["Ok"])

func _offer_zone_quests() -> void:
	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		return

	# Get player level for filtering
	var player_level = 1
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var ls = player.get_node_or_null("LevelSystem") as LevelSystem
		if ls:
			player_level = ls.level

	# First: check if player has any active quests to report on in this zone
	for quest_id in qm.active_quests:
		if not qm.active_quests[quest_id].get("active", false):
			continue
		var quest = qm.definitions.get(quest_id) as QuestDefinition
		if quest and (quest.target_location == zone_id or quest.location == zone_id):
			qm.on_zone_entered(zone_id)
			return

	# Collect all available quests for this zone
	var available: Array = []
	for quest_id in qm.definitions:
		var quest = qm.definitions[quest_id] as QuestDefinition
		if quest.location != zone_id:
			continue
		if qm.is_quest_active(quest_id) or qm.is_quest_completed(quest_id):
			continue
		available.append(quest)

	# Sort by level (lowest first) so starter quests come before endgame ones
	available.sort_custom(func(a: QuestDefinition, b: QuestDefinition) -> bool:
		return a.level < b.level
	)

	# Offer the first quest the player is high enough level for
	# Allow quests up to 5 levels above player to give something to work toward
	for quest in available:
		if quest.level <= player_level + 5:
			qm.offer_quest(quest.id)
			return

	# If nothing matches level, just offer the lowest-level one available
	if available.size() > 0:
		qm.offer_quest(available[0].id)
		return

	# No quests at all — show default elder dialogue
	var greeting = "All is well in %s. You've done great work, adventurer!" % zone_id if zone_id != "" else "Welcome, adventurer. The land needs heroes."
	qm._waiting_for_dialogue = true
	qm.show_dialogue_requested.emit(npc_name, portrait_tile, greeting, ["Ok"])

func _open_shop() -> void:
	var shop_ui: ShopUI = null
	for child in get_tree().root.get_children():
		for sub in child.get_children():
			if sub is ShopUI:
				shop_ui = sub
				break
	if shop_ui:
		shop_ui.open_shop(shop_id)
	else:
		_show_simple_dialogue()

func _open_enchant_station() -> void:
	var enchant_ui: EnchantUI = null
	for child in get_tree().root.get_children():
		for sub in child.get_children():
			if sub is EnchantUI:
				enchant_ui = sub
				break
	if enchant_ui:
		enchant_ui.open()
	else:
		# Create one dynamically if not in scene
		enchant_ui = EnchantUI.new()
		get_tree().current_scene.add_child(enchant_ui)
		enchant_ui.open()
