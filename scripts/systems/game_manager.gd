extends Node

# Autoload singleton: manages game state across scenes

var save_data: SaveData
var pending_biome_name: String = ""  # set before transitioning to dungeon
var _loading_screen: CanvasLayer

signal gold_changed(amount: int)
signal relics_changed(amount: int)
signal tokens_changed(amount: int)

func _ready() -> void:
	save_data = SaveData.load_game()

func start_dungeon_run(biome_name: String) -> void:
	pending_biome_name = biome_name
	_save_player_level()
	_transition_to_scene("res://scenes/dungeon/dungeon.tscn", "Entering dungeon...")

func return_to_overworld() -> void:
	pending_biome_name = ""
	_save_player_level()
	# Use .scn (binary) for faster parsing than .tscn (text)
	if ResourceLoader.exists("res://scenes/overworld/overworld.scn"):
		_transition_to_scene("res://scenes/overworld/overworld.scn", "Loading world...")
	else:
		_transition_to_scene("res://scenes/overworld/overworld.tscn", "Loading world...")

func go_to_start_screen() -> void:
	pending_biome_name = ""
	get_tree().change_scene_to_file("res://scenes/ui/start_screen.tscn")

func _transition_to_scene(scene_path: String, message: String) -> void:
	# Show loading screen immediately
	_show_loading_screen(message)
	# Wait 2 frames so loading screen renders
	await get_tree().process_frame
	await get_tree().process_frame

	var t0 = Time.get_ticks_msec()
	get_tree().change_scene_to_file(scene_path)
	print("TIMING: change_scene_to_file('%s') took %d ms" % [scene_path, Time.get_ticks_msec() - t0])
	# Loading screen stays visible until the new scene calls _hide_loading_screen()
	# The new scene's deferred/async init will hide it when ready

func _show_loading_screen(message: String) -> void:
	if _loading_screen:
		_loading_screen.queue_free()
	_loading_screen = CanvasLayer.new()
	_loading_screen.layer = 100
	var panel = ColorRect.new()
	panel.color = Color.BLACK
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_screen.add_child(panel)
	var label = Label.new()
	label.text = message
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	_loading_screen.add_child(label)
	add_child(_loading_screen)

func _hide_loading_screen() -> void:
	if _loading_screen:
		_loading_screen.queue_free()
		_loading_screen = null

func add_gold(amount: int) -> void:
	save_data.gold += amount
	save_data.total_gold_earned += amount
	gold_changed.emit(save_data.gold)

func spend_gold(amount: int) -> bool:
	if save_data.gold >= amount:
		save_data.gold -= amount
		gold_changed.emit(save_data.gold)
		return true
	return false

func add_relics(amount: int) -> void:
	save_data.relics += amount
	relics_changed.emit(save_data.relics)

func add_troop_tokens(amount: int) -> void:
	save_data.troop_tokens += amount
	tokens_changed.emit(save_data.troop_tokens)

func on_run_ended(run_state: RunState) -> void:
	save_data.total_runs += 1
	save_data.total_enemies_killed += run_state.enemies_killed

	if run_state.floors_cleared > save_data.best_floor:
		save_data.best_floor = run_state.floors_cleared

	# Transfer run earnings to persistent
	add_gold(run_state.run_gold)
	add_relics(run_state.run_relics)
	add_troop_tokens(run_state.run_troop_tokens)

	# Save player level data from the active player
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get_node_or_null("LevelSystem"):
		save_level_data(player.get_node("LevelSystem"))

	save_data.save_game()

func get_gold() -> int:
	return save_data.gold

func get_relics() -> int:
	return save_data.relics

func get_troop_tokens() -> int:
	return save_data.troop_tokens

func save_level_data(level_system: LevelSystem) -> void:
	if not save_data or not level_system:
		return
	save_data.player_level = level_system.level
	save_data.player_xp = level_system.xp
	save_data.stat_points_unspent = level_system.unspent_stat_points
	save_data.stat_allocations = level_system.allocated.duplicate()
	save_data.save_game()

func _save_player_level() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get_node_or_null("LevelSystem"):
		save_level_data(player.get_node("LevelSystem"))

func load_level_data(level_system: LevelSystem) -> void:
	if not save_data or not level_system:
		return
	level_system.level = save_data.player_level
	level_system.xp = save_data.player_xp
	level_system.unspent_stat_points = save_data.stat_points_unspent
	level_system.allocated = save_data.stat_allocations.duplicate()
