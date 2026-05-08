extends Node2D

const PlayerQuery = preload("res://scripts/systems/player_query.gd")

@onready var mine_manager = $MineManager
@onready var death_screen: DeathScreen = $DeathScreen
@onready var inventory_screen: InventoryScreen = $InventoryScreen

var game_hud: GameHUD
var companion_scene: PackedScene
var _mine_help_shown: bool = false

func _ready() -> void:
	var player = PlayerQuery.get_primary_player(get_tree())
	companion_scene = preload("res://scenes/companions/companion.tscn")
	$Bullets.add_to_group("bullets")

	mine_manager.floor_changed.connect(_on_floor_changed)
	mine_manager.room_changed.connect(_on_room_changed)
	mine_manager.run_ended.connect(_on_mine_complete)

	for p in PlayerQuery.get_active_players(get_tree()):
		p.in_dungeon = true
		if not p.player_died.is_connected(_on_player_died):
			p.player_died.connect(_on_player_died)
	inventory_screen.setup(player.equipment_manager)
	player.equipment_manager.use_effect_triggered.connect(_on_use_effect)

	game_hud = GameHUD.new()
	add_child(game_hud)
	game_hud.setup(player)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		var current_gold: int = gm.save_data.gold if gm.save_data else 0
		game_hud.set_gold(current_gold)
		gm.gold_changed.connect(_on_gold_changed)
	else:
		game_hud.set_gold(0)

	var loot_ui = LootBagUI.new()
	add_child(loot_ui)
	loot_ui.setup(player.equipment_manager)

	var quest_log = QuestLog.new()
	add_child(quest_log)

	var fpv = FirstPersonView.new()
	fpv.name = "FirstPersonView"
	fpv.visible = false
	add_child(fpv)
	fpv.setup(8.0)
	fpv.add_source(0, "res://assets/sprites/lofiEnvironment.png", 16, 26)
	fpv.add_source(1, "res://assets/sprites/lofi_dungeon_features.png", 12, 9)
	fpv.set_layers(mine_manager.floor_layer, mine_manager.wall_layer)
	fpv.add_object_layer(mine_manager.deco_layer, "decorations")
	fpv.add_floor_overlay_layer(mine_manager.liquid_layer, "liquids")
	player._first_person_view = fpv

	if has_node("TouchControls"):
		player.touch_controls = $TouchControls

	var lm = get_node_or_null("/root/LightingManager")
	if lm and lm.has_method("apply_outline_to_subtree"):
		lm.apply_outline_to_subtree(self)

	player.equipment_manager.base_stats.move_speed *= 0.25
	player.equipment_manager.base_stats.bullet_speed *= 0.25

	if GameManager and GameManager.pending_biome_name != "":
		mine_manager.starting_biome_name = GameManager.pending_biome_name
	if GameManager and GameManager.pending_mine_id != "":
		mine_manager.preferred_mine_id = GameManager.pending_mine_id

	mine_manager.start_run()
	if GameManager:
		GameManager.pending_mine_id = ""

	var _dui = DialogueUI.new()
	add_child(_dui)

	if GameManager and GameManager.has_method("_hide_loading_screen"):
		GameManager._hide_loading_screen()

func _on_floor_changed(floor_num: int) -> void:
	var rec_level: int = mine_manager.current_level.recommended_level if mine_manager.current_level else 0
	var player_level: int = mine_manager.player.level_system.level if mine_manager.player and mine_manager.player.level_system else 1
	var effective: int = rec_level + player_level
	var area_name: String = mine_manager.current_mine.mine_name if mine_manager.current_mine else "Mine"
	game_hud.set_floor_info(floor_num, effective, area_name)
	game_hud.hide_minimap()
	if floor_num == 1 and not _mine_help_shown and mine_manager.current_mine:
		_mine_help_shown = true
		game_hud.flash_text("%s: mine walls, gather nodes, survive pressure" % mine_manager.current_mine.mine_name, Color(0.8, 0.9, 1.0), 2.8)
	var fpv = get_node_or_null("FirstPersonView")
	if fpv and mine_manager.nav:
		fpv.wall_layer = mine_manager.wall_layer
		fpv.floor_layer = mine_manager.floor_layer
		fpv.set_walkable(mine_manager.nav)

func _on_room_changed(_room_index: int, _room_data: RoomData) -> void:
	game_hud.set_room_info("Mine Depth")

func _on_mine_complete(run_state: RunState) -> void:
	if GameManager:
		GameManager.on_run_ended(run_state)
		GameManager.return_to_overworld()
	else:
		get_tree().reload_current_scene()

func _on_player_died() -> void:
	mine_manager.run_state.end_time = Time.get_ticks_msec()
	var alive_players = PlayerQuery.get_alive_players(get_tree())
	if not alive_players.is_empty():
		return
	if GameManager:
		GameManager.on_character_death(mine_manager.run_state)
	death_screen.show_death(mine_manager.run_state)

func _on_gold_changed(amount: int) -> void:
	game_hud.set_gold(amount)

func _on_use_effect(effect: String) -> void:
	if effect == "town_portal":
		var sfx_tp = get_node_or_null("/root/SFXManager")
		if sfx_tp:
			sfx_tp.play("teleport", -2.0, 0.0)
		if GameManager:
			GameManager.return_to_overworld()
