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

signal gold_changed(amount: int)
signal relics_changed(amount: int)
signal tokens_changed(amount: int)
signal character_died
signal slot_loaded(slot: int)
signal battle_ended(result: Dictionary)

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
			_try_unlock_blueprint(String(blueprint_id))
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
	save_data.quickbar_items = ["", "", "", "", "", ""]
	save_data.learned_spells.clear()
	save_data.equipped_spell_slots = ["", "", "", "", "", ""]
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

func on_character_death(run_state: RunState) -> void:
	if not save_data:
		return
	# Record run stats before wiping
	on_run_ended(run_state)
	# Wipe character data, keep world
	save_data.wipe_character()
	character_died.emit()
	print("GameManager: Character died (death #%d)" % save_data.total_deaths)

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
	var biome := _pending_coop_join_biome
	_pending_coop_join_biome = ""
	start_dungeon_run(biome)

func _on_coop_connection_failed() -> void:
	_pending_coop_join_biome = ""

func _on_coop_session_closed() -> void:
	_pending_coop_join_biome = ""

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
	var hud = get_tree().get_first_node_in_group("game_hud") as GameHUD
	if hud:
		save_quickbar(hud)

func load_level_data(level_system: LevelSystem) -> void:
	if not save_data or not level_system:
		return
	level_system.level = save_data.player_level
	level_system.xp = save_data.player_xp
	level_system.unspent_stat_points = save_data.stat_points_unspent
	level_system.allocated = save_data.stat_allocations.duplicate()

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

func save_quickbar(hud: GameHUD) -> void:
	if not save_data or not hud:
		return
	save_data.quickbar_items = hud._quickbar_items.duplicate()
	save_data.save_to_slot()

func load_quickbar(hud: GameHUD) -> void:
	if not save_data or not hud:
		return
	if save_data.quickbar_items.size() == 6:
		hud._quickbar_items = save_data.quickbar_items.duplicate()

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
	save_data.equipped_spell_slots = ["", "", "", "", "", ""]
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
	# Restore equipped slots
	if save_data.equipped_spell_slots.size() >= SpellBook.MAX_SPELL_SLOTS:
		for i in range(SpellBook.MAX_SPELL_SLOTS):
			var spell_id = save_data.equipped_spell_slots[i]
			if spell_id == "":
				continue
			for spell in sb.learned_spells:
				if spell.id == spell_id:
					sb.spell_slots[i] = spell
					break
	return true
