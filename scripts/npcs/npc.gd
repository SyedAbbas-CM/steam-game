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
var _interact_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("npc")
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
	_interact_label.text = "Tap to Talk" if TouchControls.is_mobile() else "[E] Talk"
	_interact_label.position = Vector2(-20, 22)
	_interact_label.add_theme_font_size_override("font_size", 9)
	_interact_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	_interact_label.visible = false
	_interact_label.z_index = 5
	add_child(_interact_label)

	# On mobile, allow tapping the NPC directly to interact
	if TouchControls.is_mobile():
		input_pickable = true
		input_event.connect(_on_touch_interact)

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
		if TouchControls.is_mobile():
			var tc = get_tree().get_first_node_in_group("touch_controls") as TouchControls
			if tc:
				tc.show_interact_button("Talk")

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
		if _player_nearby and _interact_cooldown <= 0 and not _is_dialogue_open():
			interact()
			_interact_cooldown = 0.4

func _process(delta: float) -> void:
	if _interact_cooldown > 0:
		_interact_cooldown -= delta

func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby:
		return
	if _interact_cooldown > 0:
		return
	if event.is_action_pressed("interact") and not _is_dialogue_open():
		interact()
		_interact_cooldown = 0.4
		get_viewport().set_input_as_handled()

func _is_dialogue_open() -> bool:
	var qm = get_node_or_null("/root/QuestManager")
	if not qm or not qm._waiting_for_dialogue:
		return false
	# Safety: if _waiting_for_dialogue is true but dialogue UI is actually closed, reset it
	var dui = get_tree().get_first_node_in_group("dialogue_ui")
	if dui and dui.has_method("is_open") and not dui.is_open():
		qm._waiting_for_dialogue = false
		return false
	return true

func interact() -> void:
	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		return
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("select_b", -4.0)

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
		"blacksmith":
			_open_crafting_station("blacksmith")
		"alchemist":
			_open_crafting_station("alchemist")
		"spellcraft":
			_open_spell_craft()
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
			"blacksmith":
				_open_crafting_station("blacksmith")
				return
			"alchemist":
				_open_crafting_station("alchemist")
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
	var had_active_quest = false
	for quest_id in qm.active_quests:
		if not qm.active_quests[quest_id].get("active", false):
			continue
		var quest = qm.definitions.get(quest_id) as QuestDefinition
		if quest and (quest.target_location == zone_id or quest.location == zone_id):
			had_active_quest = true
			await qm.check_zone_quests(zone_id)
			break
	# If a quest was just completed during check, fall through to offer the next one
	if had_active_quest:
		# Re-check: if the quest was completed, don't return — offer next quest below
		var still_has_active = false
		for quest_id in qm.active_quests:
			if not qm.active_quests[quest_id].get("active", false):
				continue
			var quest = qm.definitions.get(quest_id) as QuestDefinition
			if quest and (quest.target_location == zone_id or quest.location == zone_id):
				still_has_active = true
				break
		if still_has_active:
			return  # quest still active, don't offer a new one

	# Collect all available quests for this zone (prerequisite-filtered)
	var available: Array = []
	for quest_id in qm.definitions:
		var quest = qm.definitions[quest_id] as QuestDefinition
		if quest.location != zone_id:
			continue
		if qm.is_quest_active(quest_id) or qm.is_quest_completed(quest_id):
			continue
		if not qm._prerequisites_met(quest):
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

	# No quests at all — show default elder dialogue with hire option
	var greeting = "The Hollow Tide has not reached %s... yet. Stay sharp." % zone_id if zone_id != "" else "Dark times are upon us. The land needs those who won't look away."
	qm._waiting_for_dialogue = true
	qm.show_dialogue_requested.emit(npc_name, portrait_tile, greeting, ["Hire Fighters", "Ok"])
	var choice = await qm.dialogue_option_chosen
	if choice == 0:
		_open_hire_ui()

func _open_hire_ui() -> void:
	var hire_ui := HireUI.new()
	get_tree().current_scene.add_child(hire_ui)

func _open_shop() -> void:
	var shop_ui = get_tree().get_first_node_in_group("shop_ui") as ShopUI
	if shop_ui:
		shop_ui.open_shop(shop_id)
	else:
		_show_simple_dialogue()

func _open_enchant_station() -> void:
	var enchant_ui = get_tree().get_first_node_in_group("enchant_ui") as EnchantUI
	if not enchant_ui:
		enchant_ui = EnchantUI.new()
		get_tree().current_scene.add_child(enchant_ui)
	enchant_ui.open()

func _open_crafting_station(craft_type: String) -> void:
	var crafting_ui = get_tree().get_first_node_in_group("crafting_ui") as CraftingUI
	if not crafting_ui:
		crafting_ui = CraftingUI.new()
		get_tree().current_scene.add_child(crafting_ui)
	crafting_ui.open(craft_type)

func _open_spell_craft() -> void:
	var spell_ui = get_tree().get_first_node_in_group("spell_craft_ui") as SpellCraftUI
	if not spell_ui:
		spell_ui = SpellCraftUI.new()
		get_tree().current_scene.add_child(spell_ui)
	spell_ui.open()
