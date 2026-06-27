extends Node

const PlayerQuery = preload("res://scripts/systems/player_query.gd")

# Autoload singleton: manages game state across scenes

var save_data: SaveData = null
var selected_class: String = "warrior"
var active_slot: int = -1  # -1 = no slot loaded
var pending_biome_name: String = ""  # set before transitioning to dungeon
var pending_mine_id: String = ""  # optional explicit mine override for dungeon runs
var overworld_return_position: Vector2 = Vector2.ZERO  # player position to restore when exiting dungeon
var battle_config: Dictionary = {}  # set before transitioning to battle arena
var enemy_armies: Dictionary = {}  # zone_id -> { "name": String, "budget": int }
var _loading_screen: CanvasLayer
var _auto_save_timer: float = 0.0
var _pending_coop_join_biome: String = ""
const AUTO_SAVE_INTERVAL: float = 60.0
const COOP_BOSS_ARENA_BIOME: String = "Test-Arena-Boss"
const HALL_OF_ANCESTORS_SCENE := "res://scenes/ui/hall_of_ancestors.tscn"
const MAX_ANCESTOR_RECORDS: int = 10
const LEGACY_ITEM_LIMIT: int = 3

## Demo build gate. When true, any code that rolls random loot or pulls from
## the generated item pool must filter to items where EquipmentItem.demo_approved
## is true. Defaults true while the project is in the post-playtest demo polish
## phase; flip to false once the wider loot pool gets audited.
var demo_mode: bool = true

signal gold_changed(amount: int)
signal relics_changed(amount: int)
signal tokens_changed(amount: int)
signal character_died
signal slot_loaded(slot: int)
signal battle_ended(result: Dictionary)

func _clear_character_run_transients() -> void:
	pending_biome_name = ""
	pending_mine_id = ""
	overworld_return_position = Vector2.ZERO
	battle_config.clear()
	_pending_coop_join_biome = ""
	if has_meta("spawn_overworld_portal"):
		remove_meta("spawn_overworld_portal")

func queue_dungeon_run(biome_name: String, mine_id: String = "") -> void:
	pending_biome_name = biome_name
	pending_mine_id = mine_id

func _get_blueprint_definitions() -> Dictionary:
	var defs: Dictionary = {}
	for path in ResourceRegistry.blueprints():
		var def = load(path) as BlueprintDefinition
		if def and def.blueprint_id != "":
			defs[def.blueprint_id] = def
	return defs

func get_blueprint_definition(blueprint_id: String) -> BlueprintDefinition:
	if blueprint_id == "":
		return null
	return _get_blueprint_definitions().get(blueprint_id, null) as BlueprintDefinition

func has_blueprint(blueprint_id: String) -> bool:
	return save_data != null and blueprint_id in save_data.discovered_blueprints

func get_blueprint_progress(blueprint_id: String) -> int:
	if not save_data or blueprint_id == "":
		return 0
	return int(save_data.blueprint_progress.get(blueprint_id, 0))

func discover_blueprint(blueprint_id: String) -> bool:
	if not save_data or blueprint_id == "":
		return false
	if blueprint_id in save_data.discovered_blueprints:
		return false
	save_data.discovered_blueprints.append(blueprint_id)
	save_data.save_to_slot()
	return true

func _try_unlock_blueprint(blueprint_id: String) -> bool:
	if not save_data or blueprint_id == "" or blueprint_id in save_data.discovered_blueprints:
		return false
	var def = get_blueprint_definition(blueprint_id)
	if not def:
		return false
	var progress := int(save_data.blueprint_progress.get(blueprint_id, 0))
	if not def.can_unlock(progress, save_data.salvage_points):
		return false
	save_data.discovered_blueprints.append(blueprint_id)
	save_data.save_to_slot()
	return true

func add_blueprint_progress(blueprint_id: String, amount: int = 1) -> Dictionary:
	if not save_data or blueprint_id == "" or amount <= 0:
		return {"progress": 0, "unlocked": false}
	if blueprint_id in save_data.discovered_blueprints:
		return {"progress": get_blueprint_progress(blueprint_id), "unlocked": false}
	var current := int(save_data.blueprint_progress.get(blueprint_id, 0))
	current += amount
	save_data.blueprint_progress[blueprint_id] = current
	var unlocked := _try_unlock_blueprint(blueprint_id)
	save_data.save_to_slot()
	return {"progress": current, "unlocked": unlocked}

# --- Gem Bag ---

func add_gem_to_bag(gem_path: String) -> void:
	if not save_data or gem_path == "":
		return
	save_data.gem_bag.append(gem_path)
	save_data.save_to_slot()

func remove_gem_from_bag(gem_path: String) -> bool:
	if not save_data or gem_path == "":
		return false
	var idx = save_data.gem_bag.find(gem_path)
	if idx < 0:
		return false
	save_data.gem_bag.remove_at(idx)
	save_data.save_to_slot()
	return true

func get_gem_bag() -> Array[String]:
	if not save_data:
		return []
	return save_data.gem_bag

# --- Salvage Points ---

func add_salvage_points(amount: int) -> void:
	if save_data and amount > 0:
		save_data.salvage_points += amount
		for blueprint_id in save_data.blueprint_progress.keys():
			_try_unlock_blueprint(str(blueprint_id))
		save_data.save_to_slot()

func get_salvage_points() -> int:
	return save_data.salvage_points if save_data else 0

func discover_gem(gem_id: String) -> bool:
	if not save_data or gem_id == "":
		return false
	if gem_id in save_data.discovered_gems:
		return false
	save_data.discovered_gems.append(gem_id)
	save_data.save_to_slot()
	return true

func record_crafted_item(item_key: String, amount: int = 1) -> void:
	if not save_data or item_key == "" or amount <= 0:
		return
	save_data.crafted_item_counts[item_key] = int(save_data.crafted_item_counts.get(item_key, 0)) + amount
	save_data.save_to_slot()

func record_material_discovery(material_id: String, source: String = "seen") -> void:
	if not save_data or material_id == "":
		return
	var entry: Dictionary = save_data.material_codex.get(material_id, {})
	entry["seen"] = true
	if source == "mined":
		entry["mined"] = int(entry.get("mined", 0)) + 1
	elif source == "crafted_with":
		entry["crafted_with"] = int(entry.get("crafted_with", 0)) + 1
	save_data.material_codex[material_id] = entry
	save_data.save_to_slot()

func _ready() -> void:
	_normalize_macos_input_bindings()
	# Don't auto-load save data; title screen handles slot selection
	save_data = null
	_migrate_legacy_save()
	var coop = get_node_or_null("/root/CoopSession")
	if coop:
		if not coop.joined_server.is_connected(_on_coop_joined_server):
			coop.joined_server.connect(_on_coop_joined_server)
		if not coop.connection_failed.is_connected(_on_coop_connection_failed):
			coop.connection_failed.connect(_on_coop_connection_failed)
		if not coop.session_closed.is_connected(_on_coop_session_closed):
			coop.session_closed.connect(_on_coop_session_closed)

func _normalize_macos_input_bindings() -> void:
	if not OS.has_feature("macos"):
		return
	_replace_action_key_events("sprint", KEY_SHIFT)

func _replace_action_key_events(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var input_event := InputEventKey.new()
	input_event.keycode = keycode
	InputMap.action_add_event(action, input_event)

func _process(delta: float) -> void:
	if save_data and active_slot >= 0:
		_auto_save_timer += delta
		if _auto_save_timer >= AUTO_SAVE_INTERVAL:
			_auto_save_timer = 0.0
			auto_save()

func _migrate_legacy_save() -> void:
	# If old save_data.tres exists and no slot 1 exists, migrate it
	if not SaveData.slot_exists(1) and ResourceLoader.exists(SaveData.LEGACY_SAVE_PATH):
		var legacy = load(SaveData.LEGACY_SAVE_PATH)
		if legacy is SaveData:
			legacy.slot_index = 1
			legacy.character_alive = true
			legacy.created_at = Time.get_datetime_string_from_system()
			legacy.last_played = legacy.created_at
			legacy.save_to_slot()
			print("GameManager: Migrated legacy save to slot 1")

# --- Slot lifecycle ---

func load_slot(slot: int) -> bool:
	var data = SaveData.load_slot(slot)
	if not data:
		return false
	save_data = data
	active_slot = slot
	selected_class = save_data.selected_class
	_auto_save_timer = 0.0
	# Migrate legacy meta-based territories to proper field
	if save_data.has_meta("owned_territories"):
		var legacy: Array = save_data.get_meta("owned_territories")
		for t in legacy:
			if t is String and t not in save_data.owned_territories:
				save_data.owned_territories.append(t)
		save_data.remove_meta("owned_territories")
		save_data.save_to_slot()
	# Reload quest state from this slot
	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("reload_from_save"):
		qm.reload_from_save()
	_load_enemy_armies()
	slot_loaded.emit(slot)
	print("GameManager: Loaded slot %d (class=%s, alive=%s)" % [slot, selected_class, save_data.character_alive])
	return true

func create_new_world(slot: int) -> SaveData:
	var data = SaveData.create_new(slot)
	data.save_to_slot()
	save_data = data
	active_slot = slot
	_auto_save_timer = 0.0
	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("reload_from_save"):
		qm.reload_from_save()
	init_enemy_armies()
	slot_loaded.emit(slot)
	print("GameManager: Created new world in slot %d" % slot)
	return data

func delete_slot(slot: int) -> void:
	var path = SaveData.slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if active_slot == slot:
		save_data = null
		active_slot = -1
	print("GameManager: Deleted slot %d" % slot)

func load_slot_preview(slot: int) -> SaveData:
	return SaveData.load_slot(slot)

func has_living_character() -> bool:
	return save_data != null and save_data.character_alive

func is_war_unlocked() -> bool:
	# Gate placeholder — always unlocked for now. Swap condition later.
	return true

func start_new_character(class_id: String) -> void:
	if not save_data:
		return
	_clear_character_run_transients()
	save_data.selected_class = class_id
	save_data.character_alive = true
	save_data.player_level = 1
	save_data.player_xp = 0
	save_data.stat_points_unspent = 0
	save_data.stat_allocations.clear()
	save_data.equipped_items.clear()
	save_data.inventory_items.clear()
	save_data.inventory_item_states.clear()
	save_data.secondary_weapon_path = ""
	save_data.quickbar_items = ["", "", "", "", "", "", "", "", "", ""]
	save_data.learned_spells.clear()
	save_data.equipped_spell_slots = ["", "", "", "", "", "", "", "", "", ""]
	save_data.pet_data.clear()
	selected_class = class_id
	# Give starter gems for testing
	save_data.gem_bag = [
		"res://resources/gems/chipped_ruby.tres",
		"res://resources/gems/chipped_sapphire.tres",
		"res://resources/gems/chipped_emerald.tres",
	] as Array[String]
	save_data.save_to_slot()
	print("GameManager: Started new character as %s in slot %d" % [class_id, active_slot])

func on_character_death(run_state = null) -> void:
	if not save_data:
		return
	_snapshot_death_legacy(run_state)
	# Record run stats before wiping
	if run_state:
		on_run_ended(run_state)
	_clear_character_run_transients()
	# Wipe character data, keep world
	save_data.wipe_character()
	character_died.emit()
	print("GameManager: Character died (death #%d)" % save_data.total_deaths)

func get_hall_upgrade_level(upgrade_id: String) -> int:
	if not save_data or upgrade_id == "":
		return 0
	return int(save_data.permanent_upgrades.get(upgrade_id, 0))

func get_hall_upgrade_cost(upgrade_id: String) -> int:
	var level := get_hall_upgrade_level(upgrade_id)
	match upgrade_id:
		"gold_retention":
			return 25 + level * 20
		"legacy_capacity":
			return 40 + level * 30
		"starting_health":
			return 30 + level * 25
		"starting_damage":
			return 40 + level * 30
		"starting_gold":
			return 20 + level * 15
		"heart_of_embers":
			return 35 + level * 25
		"gold_find":
			return 50 + level * 35
		"xp_find":
			return 50 + level * 35
		"starting_potions":
			return 30 + level * 20
		"free_stat_points":
			return 60 + level * 40
		"perk_token_carryover":
			return 100 + level * 80
		"soul_anchor":
			return 80 + level * 60
		_:
			return 999999

const HALL_UPGRADE_CAPS = {
	"gold_retention": 5,
	"legacy_capacity": 3,
	"starting_health": 10,
	"starting_damage": 10,
	"starting_gold": 5,
	"heart_of_embers": 5,
	"gold_find": 5,
	"xp_find": 5,
	"starting_potions": 3,
	"free_stat_points": 5,
	"perk_token_carryover": 3,
	"soul_anchor": 3,
}

func get_legacy_vault_capacity() -> int:
	return 6 + get_hall_upgrade_level("legacy_capacity") * 2

func can_buy_hall_upgrade(upgrade_id: String) -> bool:
	if not save_data:
		return false
	var cap = HALL_UPGRADE_CAPS.get(upgrade_id, 0)
	if cap > 0 and get_hall_upgrade_level(upgrade_id) >= cap:
		return false
	return save_data.soul_points >= get_hall_upgrade_cost(upgrade_id)

func buy_hall_upgrade(upgrade_id: String) -> bool:
	if not can_buy_hall_upgrade(upgrade_id):
		return false
	save_data.soul_points -= get_hall_upgrade_cost(upgrade_id)
	save_data.permanent_upgrades[upgrade_id] = get_hall_upgrade_level(upgrade_id) + 1
	save_data.save_to_slot()
	return true

func finalize_hall_legacy_selection(selected_indices: Array[int]) -> void:
	if not save_data:
		return
	save_data.pending_legacy_items.clear()
	save_data.pending_legacy_item_states.clear()
	var picked: int = 0
	for idx in selected_indices:
		if picked >= LEGACY_ITEM_LIMIT:
			break
		if idx < 0 or idx >= save_data.last_death_inventory_items.size():
			continue
		var item_path := str(save_data.last_death_inventory_items[idx])
		if item_path == "":
			continue
		save_data.pending_legacy_items.append(item_path)
		if save_data.last_death_item_states.has(idx):
			save_data.pending_legacy_item_states[picked] = save_data.last_death_item_states[idx]
		if save_data.legacy_vault_items.size() < get_legacy_vault_capacity():
			save_data.legacy_vault_items.append(item_path)
			var vault_idx := save_data.legacy_vault_items.size() - 1
			if save_data.last_death_item_states.has(idx):
				save_data.legacy_vault_item_states[vault_idx] = save_data.last_death_item_states[idx]
		picked += 1
	var transfer_ratio := 0.20 + 0.10 * float(get_hall_upgrade_level("gold_retention"))
	var transferred_gold := int(round(float(save_data.last_death_gold) * transfer_ratio))
	save_data.gold += max(transferred_gold, 0)
	save_data.last_death_inventory_items.clear()
	save_data.last_death_item_states.clear()
	save_data.last_death_gold = 0
	save_data.last_death_run_summary.clear()
	save_data.save_to_slot()

func go_to_hall_of_ancestors() -> void:
	pending_biome_name = ""
	pending_mine_id = ""
	get_tree().paused = false
	_hide_loading_screen()
	get_tree().change_scene_to_file(HALL_OF_ANCESTORS_SCENE)

func auto_save() -> void:
	if save_data:
		_save_player_level()
		save_data.save_to_slot()

# --- Scene transitions ---

func start_dungeon_run(biome_name: String, mine_id: String = "") -> void:
	pending_biome_name = biome_name
	pending_mine_id = mine_id
	# Remember where the player was so we can return them here
	var player = PlayerQuery.get_primary_player(get_tree())
	if player:
		overworld_return_position = player.global_position
	_save_player_level()
	var scene_path := "res://scenes/dungeon/mine.tscn" if mine_id != "" else "res://scenes/dungeon/dungeon.tscn"
	_transition_to_scene(scene_path, "Entering dungeon...")

func host_coop_boss_arena(slot: int, port: int = 24567, desired_max_players: int = 4, use_upnp: bool = false) -> Dictionary:
	var coop = get_node_or_null("/root/CoopSession")
	if coop == null:
		return {"error": ERR_UNAVAILABLE}
	if not load_slot(slot):
		return {"error": ERR_CANT_OPEN}
	_pending_coop_join_biome = ""
	var result: Dictionary = coop.host_with_optional_upnp(port, desired_max_players, use_upnp)
	var err: Error = int(result.get("error", OK))
	if err != OK:
		return result
	# Host picks the deterministic seed for this coop run. Non-zero guard so DungeonManager
	# can distinguish "coop seeded run" from "single-player random run".
	var seed_val: int = int(Time.get_unix_time_from_system() * 1000.0) ^ randi()
	if seed_val == 0:
		seed_val = 1
	coop.set_pending_seed(seed_val)
	print("GameManager: hosting coop boss arena with seed=%d" % seed_val)
	start_dungeon_run(COOP_BOSS_ARENA_BIOME)
	return result

func join_coop_boss_arena(slot: int, address: String, port: int = 24567) -> Error:
	var coop = get_node_or_null("/root/CoopSession")
	if coop == null:
		return ERR_UNAVAILABLE
	if not load_slot(slot):
		return ERR_CANT_OPEN
	_pending_coop_join_biome = COOP_BOSS_ARENA_BIOME
	var err: Error = coop.join_direct(address, port)
	if err != OK:
		_pending_coop_join_biome = ""
		return err
	return OK

func respawn_dungeon() -> void:
	# Restart the dungeon run with the same biome (keeps pending_biome_name)
	var scene_path := "res://scenes/dungeon/mine.tscn" if pending_mine_id != "" else "res://scenes/dungeon/dungeon.tscn"
	_transition_to_scene(scene_path, "Respawning...")

func return_to_overworld() -> void:
	pending_biome_name = ""
	pending_mine_id = ""
	_save_player_level()
	# Use .scn (binary) for faster parsing than .tscn (text)
	if ResourceLoader.exists("res://scenes/overworld/overworld.scn"):
		_transition_to_scene("res://scenes/overworld/overworld.scn", "Loading world...")
	else:
		_transition_to_scene("res://scenes/overworld/overworld.tscn", "Loading world...")

func _on_coop_joined_server(_address: String, _port: int) -> void:
	if _pending_coop_join_biome == "":
		return
	var coop = get_node_or_null("/root/CoopSession")
	# Wait for host's seed RPC before generating the dungeon, otherwise the client
	# will roll its own layout and desync. If seed already arrived, transition now.
	if coop and coop.pending_dungeon_seed == 0:
		print("GameManager: connected, waiting for host seed before entering arena")
		await coop.dungeon_seed_ready
	var biome := _pending_coop_join_biome
	_pending_coop_join_biome = ""
	start_dungeon_run(biome)

func _on_coop_connection_failed() -> void:
	_pending_coop_join_biome = ""

func _on_coop_session_closed() -> void:
	_pending_coop_join_biome = ""

func start_tutorial() -> void:
	pending_biome_name = ""
	pending_mine_id = ""
	_transition_to_scene("res://scenes/dungeon/tutorial.tscn", "Tutorial...")

func go_to_start_screen() -> void:
	pending_biome_name = ""
	pending_mine_id = ""
	# Ensure tree is unpaused and any stale loading screen is cleared
	get_tree().paused = false
	_hide_loading_screen()
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")

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

# --- Battle ---

func start_battle(config: Dictionary) -> void:
	# config = { "zone_name": String, "player_army": [...], "enemy_army": [...] }
	battle_config = config
	var player = PlayerQuery.get_primary_player(get_tree())
	if player:
		overworld_return_position = player.global_position
	_save_player_level()
	_transition_to_scene("res://scenes/battle/battle_arena.tscn", "Preparing battle...")

func on_battle_ended(result: Dictionary) -> void:
	var victory: bool = result.get("victory", false)
	var zone_name: String = result.get("zone_name", "")
	var army_id: String = result.get("army_id", zone_name)  # army marker key for removal
	var fm = get_node_or_null("/root/FactionManager")
	if victory and zone_name != "" and save_data:
		if zone_name not in save_data.owned_territories:
			save_data.owned_territories.append(zone_name)
		# Remove the army marker (may differ from zone_name)
		remove_enemy_army(army_id)
		if fm:
			var blue_surv: float = result.get("blue_survival", 1.0)
			fm.on_battle_won(zone_name, blue_surv)
			fm.save_to(save_data)
		save_data.save_to_slot()
		var display_name: String = battle_config.get("zone_display_name", zone_name)
		set_meta("last_battle_victory_zone", display_name)
		print("GameManager: Victory in %s (army=%s)" % [zone_name, army_id])
	elif not victory and save_data:
		# Defeat: lose territory to the enemy and kill the player
		if zone_name != "" and zone_name in save_data.owned_territories:
			save_data.owned_territories.erase(zone_name)
			print("GameManager: Lost territory '%s' after battle defeat" % zone_name)
		if fm:
			var red_surv: float = result.get("red_survival", 1.0)
			fm.on_battle_lost(zone_name, red_surv)
			fm.save_to(save_data)
		# Player dies on battle defeat
		save_data.total_deaths += 1
		save_data.save_to_slot()
		character_died.emit()
		print("GameManager: Player died in battle (death #%d)" % save_data.total_deaths)
	battle_ended.emit(result)
	battle_config = {}

# --- Enemy Armies ---

func init_enemy_armies() -> void:
	enemy_armies.clear()
	# Load waypoints from imported data
	var wp_res = load("res://resources/world/waypoints.tres")
	if not wp_res or not wp_res.has_meta("waypoints"):
		print("GameManager: No waypoints.tres found, using fallback armies")
		enemy_armies["fallback_1"] = {"name": "Goblin Scouts", "budget": 30, "tile_x": 106, "tile_y": -47}
		_save_enemy_armies()
		return

	var waypoints: Array = wp_res.get_meta("waypoints")
	# Army name/budget mapping by region prefix
	var army_defs := {
		"Darl_woods": {"name": "Dark Wood Raiders", "budget": 50},
		"StagingGround": {"name": "Staging Ground Garrison", "budget": 70},
		"Farm": {"name": "Farm Marauders", "budget": 35},
		"HighWay": {"name": "Highway Bandits", "budget": 45},
		"Wilderness": {"name": "Wilderness Warband", "budget": 40},
		"Graveyard": {"name": "Undead Legion", "budget": 60},
	}
	for wp in waypoints:
		var wp_name: String = wp.get("name", "")
		if "ArmySpawn" not in wp_name and "army_spawn" not in wp_name.to_lower():
			continue
		# Find matching army def by prefix
		var army_name := "Enemy Army"
		var budget := 40
		for prefix in army_defs:
			if wp_name.begins_with(prefix):
				army_name = army_defs[prefix]["name"]
				budget = army_defs[prefix]["budget"]
				break
		# Add some variance per spawn point
		var idx_str := wp_name.get_slice("Spawn", 1).replace("_", "")
		if idx_str.is_valid_int() and idx_str.to_int() > 1:
			budget += (idx_str.to_int() - 1) * 15
		enemy_armies[wp_name] = {
			"name": army_name,
			"budget": budget,
			"tile_x": int(wp.get("x", 0)),
			"tile_y": int(wp.get("y", 0)),
		}
	print("GameManager: Initialized %d enemy armies from waypoints" % enemy_armies.size())
	_save_enemy_armies()

func remove_enemy_army(army_id: String) -> void:
	enemy_armies.erase(army_id)
	_save_enemy_armies()

func _save_enemy_armies() -> void:
	if save_data:
		save_data.set_meta("enemy_armies_data", enemy_armies.duplicate(true))

func _load_enemy_armies() -> void:
	if save_data and save_data.has_meta("enemy_armies_data"):
		enemy_armies = save_data.get_meta("enemy_armies_data")
		# If all armies were defeated, respawn them
		if enemy_armies.is_empty():
			print("GameManager: All enemy armies defeated — respawning")
			init_enemy_armies()
	else:
		init_enemy_armies()

# --- Currency ---

func add_gold(amount: int, apply_mult: bool = false) -> void:
	if apply_mult:
		var player = PlayerQuery.get_primary_player(get_tree())
		if player and player.get("equipment_manager"):
			amount = int(amount * player.equipment_manager.get_gold_mult())
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
	add_gold(run_state.run_gold, true)
	add_relics(run_state.run_relics)
	add_troop_tokens(run_state.run_troop_tokens)

	# Save player level + equipment + quickbar
	_save_player_level()

	save_data.save_to_slot()

func get_gold() -> int:
	return save_data.gold if save_data else 0

func get_relics() -> int:
	return save_data.relics if save_data else 0

func get_troop_tokens() -> int:
	return save_data.troop_tokens if save_data else 0

# --- Player data persistence ---

func save_level_data(level_system: LevelSystem) -> void:
	if not save_data or not level_system:
		return
	save_data.player_level = level_system.level
	save_data.player_xp = level_system.xp
	save_data.stat_points_unspent = level_system.unspent_stat_points
	save_data.stat_allocations = level_system.allocated.duplicate()
	save_data.save_to_slot()

func save_perk_data() -> void:
	if not save_data:
		return
	var pm = get_node_or_null("/root/PerkManager")
	if pm:
		save_data.perk_tokens = pm.perk_tokens
		save_data.unlocked_perks = pm.unlocked_perks.duplicate()
		save_data.save_to_slot()

func load_perk_data() -> void:
	if not save_data:
		return
	var pm = get_node_or_null("/root/PerkManager")
	if pm:
		pm.perk_tokens = save_data.perk_tokens
		pm.unlocked_perks.clear()
		for pid in save_data.unlocked_perks:
			pm.unlocked_perks.append(pid)

func _save_player_level() -> void:
	var player = PlayerQuery.get_primary_player(get_tree())
	if player and player.get_node_or_null("LevelSystem"):
		save_level_data(player.get_node("LevelSystem"))
	if player and player.get_node_or_null("EquipmentManager"):
		save_equipment(player.get_node("EquipmentManager"))
	if player and player.get_node_or_null("SpellBook"):
		save_spellbook(player.get_node("SpellBook") as SpellBook)
	save_perk_data()
	# Save secondary weapon (mercenary/ranger weapon swap)
	if player and player.get("_secondary_weapon"):
		var sec = player._secondary_weapon as EquipmentItem
		var path = sec.resource_path if sec.resource_path != "" else sec.source_path
		save_data.secondary_weapon_path = path
	else:
		if save_data:
			save_data.secondary_weapon_path = ""
	# Save class selection
	if save_data:
		save_data.selected_class = selected_class
	# Save quickbar
	var hud = get_tree().get_first_node_in_group("game_hud") as CanvasLayer
	if hud:
		save_quickbar(hud)

func load_level_data(level_system: LevelSystem) -> void:
	if not save_data or not level_system:
		return
	level_system.level = save_data.player_level
	level_system.xp = save_data.player_xp
	level_system.unspent_stat_points = save_data.stat_points_unspent
	level_system.allocated = save_data.stat_allocations.duplicate()

func apply_pending_legacy_equipment(equip_mgr: EquipmentManager) -> void:
	if not save_data or not equip_mgr or save_data.pending_legacy_items.is_empty():
		return
	for i in range(save_data.pending_legacy_items.size()):
		var path := str(save_data.pending_legacy_items[i])
		if not ResourceLoader.exists(path):
			continue
		var res := load(path) as EquipmentItem
		if not res:
			continue
		var copy := res.make_copy()
		if save_data.pending_legacy_item_states.has(i):
			copy.apply_item_instance_state(save_data.pending_legacy_item_states[i])
		equip_mgr.inventory.append(copy)
	save_data.pending_legacy_items.clear()
	save_data.pending_legacy_item_states.clear()
	save_equipment(equip_mgr)

func _snapshot_death_legacy(run_state = null) -> void:
	if not save_data:
		return
	var player = PlayerQuery.get_primary_player(get_tree())
	if player and player.has_node("EquipmentManager"):
		var equip_mgr = player.get_node("EquipmentManager") as EquipmentManager
		if equip_mgr:
			save_equipment(equip_mgr)
	var hud = get_tree().get_first_node_in_group("game_hud") as GameHUD
	if hud:
		save_quickbar(hud)
	save_data.last_death_inventory_items = save_data.inventory_items.duplicate()
	save_data.last_death_item_states = save_data.inventory_item_states.duplicate(true)
	save_data.last_death_gold = save_data.gold
	var soul_gain := _calculate_soul_points_gain(run_state)
	save_data.soul_points += soul_gain
	save_data.last_death_run_summary = {
		"class_id": selected_class,
		"level": save_data.player_level,
		"floor": int(run_state.current_floor) if run_state else 0,
		"rooms_cleared": int(run_state.rooms_cleared) if run_state else 0,
		"enemies_killed": int(run_state.enemies_killed) if run_state else 0,
		"gold_earned": int(run_state.run_gold) if run_state else 0,
		"soul_gain": soul_gain,
		"time_seconds": int(run_state.get_duration_seconds()) if run_state else 0,
		"died_at": Time.get_datetime_string_from_system(),
	}
	# Merge the death-recap meta written by player.gd right before player_died.
	# Keys: source (enemy name), attack (Projectile/Contact/attack id), damage.
	if save_data.has_meta("last_death_recap"):
		var recap: Dictionary = save_data.get_meta("last_death_recap")
		save_data.last_death_run_summary["recap_source"] = str(recap.get("source", "the dark"))
		save_data.last_death_run_summary["recap_attack"] = str(recap.get("attack", "Unknown"))
		save_data.last_death_run_summary["recap_damage"] = int(recap.get("damage", 0))
		save_data.remove_meta("last_death_recap")
	var ancestor_entry := save_data.last_death_run_summary.duplicate(true)
	ancestor_entry["class_name"] = selected_class.capitalize()
	save_data.ancestor_records.insert(0, ancestor_entry)
	while save_data.ancestor_records.size() > MAX_ANCESTOR_RECORDS:
		save_data.ancestor_records.pop_back()
	save_data.save_to_slot()

func _calculate_soul_points_gain(run_state = null) -> int:
	var soul_gain := 10
	soul_gain += maxi(save_data.player_level - 1, 0) * 3
	if run_state:
		soul_gain += maxi(run_state.current_floor, 0) * 4
		soul_gain += int(run_state.enemies_killed / 10)
		soul_gain += int(run_state.rooms_cleared / 2)
	return maxi(soul_gain, 10)

func save_equipment(equip_mgr: EquipmentManager) -> void:
	if not save_data or not equip_mgr:
		return
	# Save all inventory items (equipped ones live in inventory too)
	save_data.inventory_items.clear()
	save_data.inventory_quantities.clear()
	save_data.inventory_item_states.clear()
	var inv_idx := 0
	for item in equip_mgr.inventory:
		if not item:
			continue
		# Use resource_path if available, otherwise source_path (set on duplicated items)
		var path = item.resource_path if item.resource_path != "" else item.source_path
		if path != "":
			save_data.inventory_items.append(path)
			# Persist ammo quantity so arrow stacks survive scene transitions
			if item.slot_type == EquipmentItem.SlotType.AMMO and item.quantity > 0:
				save_data.inventory_quantities[inv_idx] = item.quantity
			var item_state = item.get_item_instance_state()
			if not item_state.is_empty():
				save_data.inventory_item_states[inv_idx] = item_state
			inv_idx += 1
	# Save which inventory indices are equipped (inv_index -> slot_type)
	save_data.equipped_items.clear()
	for slot_type in equip_mgr.equipped:
		var eq_item = equip_mgr.equipped[slot_type] as EquipmentItem
		if eq_item:
			var idx = equip_mgr.inventory.find(eq_item)
			if idx >= 0:
				save_data.equipped_items[idx] = int(slot_type)
	save_data.save_to_slot()

func save_quickbar(hud: CanvasLayer) -> void:
	# Accepts either GameHUD or SigilHUD — both have a `_quickbar_items` array.
	if not save_data or not hud:
		return
	save_data.quickbar_items = hud.get("_quickbar_items").duplicate()
	save_data.save_to_slot()

func load_quickbar(hud: CanvasLayer) -> void:
	# Accepts either GameHUD or SigilHUD — both have a `_quickbar_items` array.
	if not save_data or not hud:
		return
	# Resize-tolerant: old saves had length 6, the unified bar wants 10.
	# _migrate_action_bar() on load_slot already normalises persisted saves,
	# but in-memory SaveData from a fresh run won't have gone through it.
	if save_data.quickbar_items.size() < 10:
		save_data._migrate_action_bar()
	hud.set("_quickbar_items", save_data.quickbar_items.duplicate())

func load_equipment(equip_mgr: EquipmentManager) -> bool:
	if not save_data or not equip_mgr:
		return false
	if save_data.inventory_items.is_empty():
		return false
	# Restore inventory first
	var load_idx = 0
	for path in save_data.inventory_items:
		var res = load(path) as EquipmentItem
		if res:
			var copy = res.make_copy()
			# Restore saved ammo quantity (arrows survive scene transitions)
			if save_data.inventory_quantities.has(load_idx):
				copy.quantity = save_data.inventory_quantities[load_idx]
			if save_data.inventory_item_states.has(load_idx):
				copy.apply_item_instance_state(save_data.inventory_item_states[load_idx])
			equip_mgr.inventory.append(copy)
		load_idx += 1
	# Mark equipped items by index
	for idx_key in save_data.equipped_items:
		var inv_idx = int(idx_key)
		var slot_type = int(save_data.equipped_items[idx_key]) as EquipmentItem.SlotType
		if inv_idx >= 0 and inv_idx < equip_mgr.inventory.size():
			equip_mgr.equipped[slot_type] = equip_mgr.inventory[inv_idx]
	equip_mgr.stats_changed.emit()
	equip_mgr.inventory_changed.emit()
	return true

func save_spellbook(sb: SpellBook) -> void:
	if not save_data or not sb:
		return
	save_data.learned_spells.clear()
	for spell in sb.learned_spells:
		save_data.learned_spells.append(spell.to_dict())
	save_data.equipped_spell_slots = ["", "", "", "", "", "", "", "", "", ""]
	for i in range(SpellBook.MAX_SPELL_SLOTS):
		if sb.spell_slots[i]:
			save_data.equipped_spell_slots[i] = sb.spell_slots[i].id
	save_data.save_to_slot()

func load_spellbook(sb: SpellBook) -> bool:
	if not save_data or not sb:
		return false
	if save_data.learned_spells.is_empty():
		return false
	# Restore learned spells
	for d in save_data.learned_spells:
		var spell = SpellDefinition.from_dict(d)
		# For starters, load from .tres to keep resource_path
		if spell.is_starter and ResourceLoader.exists("res://resources/spells/%s.tres" % spell.id):
			spell = load("res://resources/spells/%s.tres" % spell.id) as SpellDefinition
		sb.learn_spell(spell)
	# Restore equipped slots — accept any prior size (e.g. 6-slot saves from
	# before the bar expanded to 7) and only iterate as far as the save has.
	var saved_count: int = save_data.equipped_spell_slots.size()
	if saved_count > 0:
		for i in range(mini(saved_count, SpellBook.MAX_SPELL_SLOTS)):
			var spell_id = save_data.equipped_spell_slots[i]
			if spell_id == "":
				continue
			for spell in sb.learned_spells:
				if spell.id == spell_id:
					sb.spell_slots[i] = spell
					break
	return true
