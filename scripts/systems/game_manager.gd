extends Node

# Autoload singleton: manages game state across scenes

var save_data: SaveData = null
var selected_class: String = "warrior"
var active_slot: int = -1  # -1 = no slot loaded
var pending_biome_name: String = ""  # set before transitioning to dungeon
var overworld_return_position: Vector2 = Vector2.ZERO  # player position to restore when exiting dungeon
var battle_config: Dictionary = {}  # set before transitioning to battle arena
var enemy_armies: Dictionary = {}  # zone_id -> { "name": String, "budget": int }
var _loading_screen: CanvasLayer
var _auto_save_timer: float = 0.0
const AUTO_SAVE_INTERVAL: float = 60.0

signal gold_changed(amount: int)
signal relics_changed(amount: int)
signal tokens_changed(amount: int)
signal character_died
signal slot_loaded(slot: int)
signal battle_ended(result: Dictionary)

func _ready() -> void:
	# Don't auto-load save data; title screen handles slot selection
	save_data = null
	_migrate_legacy_save()

func _process(delta: float) -> void:
	if save_data and active_slot >= 0:
		_auto_save_timer += delta
		if _auto_save_timer >= AUTO_SAVE_INTERVAL:
			_auto_save_timer = 0.0
			auto_save()

func _migrate_legacy_save() -> void:
	# If old save_data.tres exists and no slot 1 exists, migrate it
	if not SaveData.slot_exists(1) and ResourceLoader.exists(SaveData.LEGACY_SAVE_PATH):
		var legacy = ResourceLoader.load(SaveData.LEGACY_SAVE_PATH)
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
	save_data.secondary_weapon_path = ""
	save_data.quickbar_items = ["", "", "", "", "", ""]
	save_data.learned_spells.clear()
	save_data.equipped_spell_slots = ["", "", "", "", "", ""]
	save_data.pet_data.clear()
	selected_class = class_id
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

func start_dungeon_run(biome_name: String) -> void:
	pending_biome_name = biome_name
	# Remember where the player was so we can return them here
	var player = get_tree().get_first_node_in_group("player")
	if player:
		overworld_return_position = player.global_position
	_save_player_level()
	_transition_to_scene("res://scenes/dungeon/dungeon.tscn", "Entering dungeon...")

func respawn_dungeon() -> void:
	# Restart the dungeon run with the same biome (keeps pending_biome_name)
	_transition_to_scene("res://scenes/dungeon/dungeon.tscn", "Respawning...")

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
	var player = get_tree().get_first_node_in_group("player")
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
		if not save_data.has_meta("owned_territories"):
			save_data.set_meta("owned_territories", [])
		var owned: Array = save_data.get_meta("owned_territories")
		if zone_name not in owned:
			owned.append(zone_name)
			save_data.set_meta("owned_territories", owned)
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
		if zone_name != "" and save_data.has_meta("owned_territories"):
			var owned: Array = save_data.get_meta("owned_territories")
			if zone_name in owned:
				owned.erase(zone_name)
				save_data.set_meta("owned_territories", owned)
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

func _save_player_level() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get_node_or_null("LevelSystem"):
		save_level_data(player.get_node("LevelSystem"))
	if player and player.get_node_or_null("EquipmentManager"):
		save_equipment(player.get_node("EquipmentManager"))
	if player and player.get_node_or_null("SpellBook"):
		save_spellbook(player.get_node("SpellBook") as SpellBook)
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
	for item in equip_mgr.inventory:
		if not item:
			continue
		# Use resource_path if available, otherwise source_path (set on duplicated items)
		var path = item.resource_path if item.resource_path != "" else item.source_path
		if path != "":
			save_data.inventory_items.append(path)
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
	for path in save_data.inventory_items:
		var res = load(path) as EquipmentItem
		if res:
			equip_mgr.inventory.append(res.make_copy())
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
