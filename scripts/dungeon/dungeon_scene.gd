extends Node2D

@onready var dungeon_manager: DungeonManager = $DungeonManager
@onready var reward_screen: RewardScreen = $RewardScreen
@onready var death_screen: DeathScreen = $DeathScreen
@onready var inventory_screen: InventoryScreen = $InventoryScreen
@onready var hud: CanvasLayer = $HUD
@onready var hp_label: Label = $HUD/HPLabel
@onready var floor_label: Label = $HUD/FloorLabel
@onready var gold_label: Label = $HUD/GoldLabel
@onready var items_label: Label = $HUD/ItemsLabel

var companion_scene: PackedScene

func _ready() -> void:
	var t_start = Time.get_ticks_msec()
	print("TIMING: dungeon_scene _ready START")
	companion_scene = preload("res://scenes/companions/companion.tscn")
	$Bullets.add_to_group("bullets")

	dungeon_manager.floor_changed.connect(_on_floor_changed)
	dungeon_manager.room_changed.connect(_on_room_changed)
	dungeon_manager.reward_requested.connect(_on_reward_requested)

	var player = dungeon_manager.get_node("Player")
	player.hp_changed.connect(_on_hp_changed)
	player.player_died.connect(_on_player_died)
	_on_hp_changed(player.hp)
	reward_screen.reward_chosen.connect(_on_reward_chosen)
	death_screen.continue_pressed.connect(_on_death_continue)
	inventory_screen.setup(player.equipment_manager)

	if has_node("TouchControls"):
		player.touch_controls = $TouchControls

	# Scale player for dungeon (8px tiles vs 32px overworld)
	player.equipment_manager.base_stats.move_speed = 70.0
	player.equipment_manager.base_stats.bullet_speed = 150.0

	if GameManager and GameManager.pending_biome_name != "":
		dungeon_manager.starting_biome_name = GameManager.pending_biome_name

	print("TIMING: dungeon_scene setup took %d ms, calling start_run..." % (Time.get_ticks_msec() - t_start))
	dungeon_manager.start_run()
	print("TIMING: dungeon_scene _ready TOTAL %d ms" % (Time.get_ticks_msec() - t_start))

	# Hide loading screen from GameManager
	if GameManager and GameManager.has_method("_hide_loading_screen"):
		GameManager._hide_loading_screen()

func _on_floor_changed(floor_num: int) -> void:
	floor_label.text = "Floor " + str(floor_num)

func _on_room_changed(room_index: int, room_data: RoomData) -> void:
	var type_name = ""
	match room_data.type:
		RoomData.RoomType.COMBAT: type_name = "Combat"
		RoomData.RoomType.TREASURE: type_name = "Treasure"
		RoomData.RoomType.SHRINE: type_name = "Shrine"
		RoomData.RoomType.ELITE: type_name = "ELITE"
		RoomData.RoomType.BOSS: type_name = "BOSS"
		RoomData.RoomType.SHOP: type_name = "Shop"
	var suffix = " [Stairs]" if room_data.has_stairs_down else ""
	items_label.text = type_name + " Room" + suffix

func _on_hp_changed(new_hp: int) -> void:
	var player = dungeon_manager.get_node("Player")
	hp_label.text = "HP: " + str(new_hp) + "/" + str(player.max_hp)

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
			title = "Mutation Shrine"
		_:
			return

	reward_screen.show_rewards(rewards, title)

func _on_reward_chosen(reward: Dictionary) -> void:
	var player = dungeon_manager.get_node("Player")

	match reward["type"]:
		"gold":
			dungeon_manager.run_state.run_gold += reward["amount"]
			gold_label.text = "Gold: " + str(dungeon_manager.run_state.run_gold)
		"troop_tokens":
			dungeon_manager.run_state.run_troop_tokens += reward["amount"]
		"mutation":
			var mutation = reward["mutation"] as MutationDefinition
			player.mutation_processor.add_mutation(mutation)
			items_label.text = "+" + mutation.mutation_name
		"companion":
			_spawn_companion(reward["companion_id"])

	# Mark room cleared
	var grid_pos = dungeon_manager.run_state.current_grid_pos
	var state = dungeon_manager.room_states.get(grid_pos)
	if state and not state["cleared"]:
		state["cleared"] = true
		var room_data = dungeon_manager.run_state.floor_map.get(grid_pos)
		if room_data:
			room_data.cleared = true

func _spawn_companion(companion_id: String) -> void:
	var player = dungeon_manager.get_node("Player")
	var existing = get_tree().get_nodes_in_group("companion")
	if existing.size() >= 3:
		return

	var def = preload("res://resources/companions/archer.tres")
	var companion = companion_scene.instantiate()
	companion.global_position = player.global_position + Vector2(20, 20)
	dungeon_manager.add_child(companion)
	companion.setup(def, existing.size())

func _on_player_died() -> void:
	dungeon_manager.run_state.end_time = Time.get_ticks_msec()

	if GameManager:
		GameManager.on_run_ended(dungeon_manager.run_state)

	death_screen.show_death(dungeon_manager.run_state)

func _on_death_continue() -> void:
	if GameManager:
		GameManager.return_to_overworld()
	else:
		get_tree().reload_current_scene()
