extends Node2D

@onready var dungeon_manager: DungeonManager = $DungeonManager
@onready var reward_screen: RewardScreen = $RewardScreen
@onready var death_screen: DeathScreen = $DeathScreen
@onready var inventory_screen: InventoryScreen = $InventoryScreen

var game_hud: GameHUD

var companion_scene: PackedScene

func _ready() -> void:
	var fpv = null
	var player = get_tree().get_first_node_in_group("player")
	var t_start = Time.get_ticks_msec()
	print("TIMING: dungeon_scene _ready START")
	companion_scene = preload("res://scenes/companions/companion.tscn")
	$Bullets.add_to_group("bullets")

	dungeon_manager.floor_changed.connect(_on_floor_changed)
	dungeon_manager.room_changed.connect(_on_room_changed)
	dungeon_manager.reward_requested.connect(_on_reward_requested)
	dungeon_manager.run_ended.connect(_on_dungeon_complete)

	player.in_dungeon = true
	player.player_died.connect(_on_player_died)
	reward_screen.reward_chosen.connect(_on_reward_chosen)
	inventory_screen.setup(player.equipment_manager)
	player.equipment_manager.use_effect_triggered.connect(_on_use_effect)

	game_hud = GameHUD.new()
	add_child(game_hud)
	game_hud.setup(player)
	# Show current gold and listen for changes
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		game_hud.set_gold(gm.save_data.gold if gm.save_data else 0)
		gm.gold_changed.connect(_on_gold_changed)
	else:
		game_hud.set_gold(0)

	# Loot bag UI for item pickup
	var loot_ui = LootBagUI.new()
	add_child(loot_ui)
	loot_ui.setup(player.equipment_manager)

	# Quest log (Q key)
	var quest_log = QuestLog.new()
	add_child(quest_log)

	# 3D first-person view
	fpv = FirstPersonView.new()
	fpv.name = "FirstPersonView"
	fpv.visible = false
	add_child(fpv)
	fpv.setup(8.0)
	# Dungeon tile sources: 0=lofiEnvironment (16x26), 1=lofi_dungeon_features (12x9)
	fpv.add_source(0, "res://assets/sprites/lofiEnvironment.png", 16, 26)
	fpv.add_source(1, "res://assets/sprites/lofi_dungeon_features.png", 12, 9)
	fpv.set_layers(dungeon_manager.floor_layer, dungeon_manager.wall_layer)
	fpv.add_object_layer(dungeon_manager.deco_layer, "decorations")
	fpv.add_floor_overlay_layer(dungeon_manager.liquid_layer, "liquids")
	player._first_person_view = fpv

	if has_node("TouchControls"):
		player.touch_controls = $TouchControls

	# Scale player for dungeon (8px tiles vs 32px overworld = 0.25 ratio)
	player.equipment_manager.base_stats.move_speed *= 0.25
	player.equipment_manager.base_stats.bullet_speed *= 0.25

	if GameManager and GameManager.pending_biome_name != "":
		dungeon_manager.starting_biome_name = GameManager.pending_biome_name

	print("TIMING: dungeon_scene setup took %d ms, calling start_run..." % (Time.get_ticks_msec() - t_start))
	dungeon_manager.start_run()

	# Test Arena: add chest UI + spawn test chests in start room
	if GameManager and (GameManager.pending_biome_name.begins_with("Test-Arena") or GameManager.pending_biome_name == "TestCombo" or GameManager.pending_biome_name == "TestMovement"):
		var chest_ui = ChestUI.new()
		add_child(chest_ui)
		chest_ui.setup(player.equipment_manager)
		# Spawn test chests near player start position after a short delay
		# (player position is set by dungeon_manager.start_run)
		_spawn_test_arena_chests.call_deferred()

	# Add DialogueUI so quest boss_killed dialogues work in dungeon
	var _dui = DialogueUI.new()
	add_child(_dui)

	# Wire dungeon events signals
	var ev = dungeon_manager.get("events")
	if ev:
		ev.blessing_choices_requested.connect(_on_blessing_choices)
		ev.merchant_opened.connect(_on_merchant_opened)
	print("TIMING: dungeon_scene _ready TOTAL %d ms" % (Time.get_ticks_msec() - t_start))

	# Hide loading screen from GameManager
	if GameManager and GameManager.has_method("_hide_loading_screen"):
		GameManager._hide_loading_screen()

func _on_floor_changed(floor_num: int) -> void:
	var rec_level = dungeon_manager.current_level.recommended_level if dungeon_manager.current_level else 0
	var player_level = dungeon_manager.player.level_system.level if dungeon_manager.player and dungeon_manager.player.level_system else 1
	var effective = rec_level + player_level
	game_hud.set_floor_info(floor_num, effective)
	# Setup minimap for this floor
	if dungeon_manager.run_state and dungeon_manager.run_state.floor_map:
		game_hud.setup_minimap(
			dungeon_manager.run_state.floor_map,
			dungeon_manager.run_state.current_grid_pos
		)
	# Rebuild 3D geometry for new floor
	var fpv = get_node_or_null("FirstPersonView")
	if fpv and dungeon_manager.nav:
		fpv.wall_layer = dungeon_manager.wall_layer
		fpv.floor_layer = dungeon_manager.floor_layer
		fpv.set_walkable(dungeon_manager.nav)

func _on_room_changed(room_index: int, room_data: RoomData) -> void:
	var type_name = ""
	match room_data.type:
		RoomData.RoomType.COMBAT: type_name = "Combat"
		RoomData.RoomType.TREASURE: type_name = "Treasure"
		RoomData.RoomType.SHRINE: type_name = "Shrine"
		RoomData.RoomType.ELITE: type_name = "ELITE"
		RoomData.RoomType.SUPER_ELITE: type_name = "SUPER ELITE"
		RoomData.RoomType.BOSS: type_name = "BOSS"
		RoomData.RoomType.SHOP: type_name = "Shop"
	var suffix = " [Stairs]" if room_data.has_stairs_down else ""
	game_hud.set_room_info(type_name + " Room" + suffix)
	game_hud.update_minimap_room(room_data.grid_pos)

func _on_reward_requested(room_data: RoomData) -> void:
	var rewards: Array[Dictionary]
	var title: String

	match room_data.type:
		RoomData.RoomType.TREASURE:
			rewards = RewardGenerator.generate_treasure_rewards(
				dungeon_manager.run_state.current_floor)
			title = "Treasure!"
		RoomData.RoomType.SHRINE:
			rewards = RewardGenerator.generate_shrine_rewards(
				dungeon_manager.run_state.current_floor)
			title = "Shrine Blessing"
		_:
			return

	reward_screen.show_rewards(rewards, title)

func _on_reward_chosen(reward: Dictionary) -> void:
	var player = get_tree().get_first_node_in_group("player")

	var sfx_rw = get_node_or_null("/root/SFXManager")
	match reward["type"]:
		"gold":
			dungeon_manager.run_state.run_gold += reward["amount"]
			game_hud.set_gold(dungeon_manager.run_state.run_gold)
			if sfx_rw:
				sfx_rw.play("coin", -4.0, 0.1)
		"hp_potion":
			# Give HP potions as inventory items
			var potion_res = load("res://resources/items/loy/red_potion.tres") as EquipmentItem
			if potion_res:
				for i in range(reward["amount"]):
					var copy = potion_res.make_copy()
					player.equipment_manager.add_to_inventory(copy)
			game_hud.set_room_info("+" + str(reward["amount"]) + " HP Potions")
			if sfx_rw:
				sfx_rw.play("collect_a", -3.0, 0.0)
		"heal":
			player.hp = player.max_hp
			player.hp_changed.emit(player.hp)
			game_hud.set_room_info("Full Heal!")
			if sfx_rw:
				sfx_rw.play("heal_a", -3.0, 0.0)
		"mp_potion":
			var mp_res = load("res://resources/items/loy/mana_potion.tres") as EquipmentItem
			if mp_res:
				for i in range(reward["amount"]):
					var copy = mp_res.make_copy()
					player.equipment_manager.add_to_inventory(copy)
			game_hud.set_room_info("+" + str(reward["amount"]) + " Mana Potions")
			if sfx_rw:
				sfx_rw.play("collect_a", -3.0, 0.0)
		"companion":
			_spawn_companion(reward["companion_id"])
			if sfx_rw:
				sfx_rw.play("select_b", -3.0, 0.0)
		"blessing":
			var ev_b = dungeon_manager.get("events")
			if ev_b:
				ev_b.apply_blessing(reward)
			if sfx_rw:
				sfx_rw.play("heal_a", -2.0, 0.0)

	# Mark room cleared
	var grid_pos = dungeon_manager.run_state.current_grid_pos
	var state = dungeon_manager.room_states.get(grid_pos)
	if state and not state["cleared"]:
		state["cleared"] = true
		var room_data = dungeon_manager.run_state.floor_map.get(grid_pos)
		if room_data:
			room_data.cleared = true

func _spawn_companion(companion_id: String) -> void:
	var player = get_tree().get_first_node_in_group("player")
	var existing = get_tree().get_nodes_in_group("companion")
	if existing.size() >= 3:
		return

	var def = preload("res://resources/companions/archer.tres")
	var companion = companion_scene.instantiate()
	companion.global_position = player.global_position + Vector2(20, 20)
	dungeon_manager.add_child(companion)
	companion.setup(def, existing.size())

func _on_dungeon_complete(_run_state: RunState) -> void:
	print("Dungeon complete! Floors cleared: %d" % _run_state.floors_cleared)
	if GameManager:
		GameManager.on_run_ended(_run_state)
		GameManager.return_to_overworld()
	else:
		get_tree().reload_current_scene()

func _on_player_died() -> void:
	dungeon_manager.run_state.end_time = Time.get_ticks_msec()

	# Character death: wipe character data, keep world progress
	if GameManager:
		GameManager.on_character_death(dungeon_manager.run_state)

	death_screen.show_death(dungeon_manager.run_state)

func _on_gold_changed(amount: int) -> void:
	game_hud.set_gold(amount)

func _on_use_effect(effect: String) -> void:
	if effect == "town_portal":
		var sfx_tp = get_node_or_null("/root/SFXManager")
		if sfx_tp:
			sfx_tp.play("teleport", -2.0, 0.0)
		print("Town Portal used! Returning to overworld...")
		if GameManager:
			GameManager.set_meta("spawn_overworld_portal", true)
			GameManager.on_run_ended(dungeon_manager.run_state)
			GameManager.return_to_overworld()

func _on_blessing_choices(rewards: Array, title: String) -> void:
	# Convert to typed array for RewardScreen
	var typed: Array[Dictionary] = []
	for r in rewards:
		typed.append(r)
	reward_screen.show_rewards(typed, title)

func _spawn_test_arena_chests() -> void:
	# Place test chests in the start room of the test arena
	var player = dungeon_manager.get_node_or_null("Player")
	if not player:
		return
	var start_pos = player.global_position
	var all_paths = ResourceRegistry.items_loy()

	var weapons: Array[EquipmentItem] = []
	var armor: Array[EquipmentItem] = []
	var other: Array[EquipmentItem] = []
	for path in all_paths:
		var item = load(path) as EquipmentItem
		if not item:
			continue
		var copy = item.make_copy()
		if EquipmentItem.is_weapon_slot(copy.slot_type):
			weapons.append(copy)
		elif EquipmentItem.is_equippable(copy.slot_type):
			armor.append(copy)
		else:
			other.append(copy)

	var categories = [
		[weapons, "Weapons"],
		[armor, "Armor"],
		[other, "Items"],
	]
	for i in range(categories.size()):
		var cat_items = categories[i][0] as Array
		var cat_name = categories[i][1] as String
		if cat_items.is_empty():
			continue
		var chest = TestChest.new()
		chest.chest_label = cat_name
		chest.set_meta("dungeon_scale", true)  # signal to use smaller scale
		for item in cat_items:
			chest.items.append(item)
		# Dungeon tiles are 8px — space chests 12px apart below player
		chest.position = start_pos + Vector2(-12 + i * 12, 16)
		dungeon_manager.add_child(chest)
	print("TEST ARENA: spawned %d weapons, %d armor, %d other items in chests" % [weapons.size(), armor.size(), other.size()])

func _on_merchant_opened(items: Array, grid_pos: Vector2i) -> void:
	# Show merchant items as loot pickups at the merchant's location
	var center = dungeon_manager._grid_to_world_center(grid_pos)
	var pickup_scene = preload("res://scenes/pickup.tscn")
	for i in range(items.size()):
		var item = items[i] as EquipmentItem
		if not item:
			continue
		var pickup = pickup_scene.instantiate()
		pickup.item = item.make_copy()
		var angle = TAU * i / items.size()
		pickup.global_position = center + Vector2(cos(angle), sin(angle)) * 12.0
		dungeon_manager.add_child(pickup)
