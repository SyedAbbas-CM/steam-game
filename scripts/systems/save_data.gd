class_name SaveData
extends Resource

# --- Slot metadata ---
@export var slot_index: int = 0
@export var character_alive: bool = true
@export var created_at: String = ""  # ISO timestamp
@export var last_played: String = ""  # ISO timestamp
@export var total_deaths: int = 0

# --- Character data (wiped on death) ---
@export var selected_class: String = "warrior"
@export var player_level: int = 1
@export var player_xp: int = 0
@export var stat_points_unspent: int = 0
@export var stat_allocations: Dictionary = {}  # "vitality" -> count
@export var equipped_items: Dictionary = {}  # slot_type(int) -> item_path(String)
@export var inventory_items: Array[String] = []  # array of item resource paths
@export var inventory_quantities: Dictionary = {}  # inv_index(int) -> quantity(int) for ammo items
@export var inventory_item_states: Dictionary = {}  # inv_index(int) -> per-instance state (sockets, gems, future craft state)
@export var secondary_weapon_path: String = ""  # weapon swap secondary (mercenary/ranger)
@export var quickbar_items: Array[String] = ["", "", "", "", "", ""]  # item_name per slot
@export var learned_spells: Array[Dictionary] = []  # spell data as dicts
@export var equipped_spell_slots: Array[String] = ["", "", "", "", "", ""]  # spell ids per slot
@export var pet_data: Array = []  # [{type, name, level, xp, active}]

# --- World data (persists through death) ---
@export var gold: int = 10000
@export var relics: int = 0
@export var troop_tokens: int = 0
@export var total_runs: int = 0
@export var best_floor: int = 0
@export var total_enemies_killed: int = 0
@export var total_gold_earned: int = 0
@export var quest_states: Dictionary = {}  # quest_id -> {active, values}
@export var completed_quests: Array[String] = []
@export var npc_states: Dictionary = {}  # npc_name -> {talked, flags}
@export var harvested_nodes: Dictionary = {}  # "zone_id:index" -> depleted_timestamp (float)
@export var gem_bag: Array[String] = []  # resource paths of held gems
@export var discovered_blueprints: Array[String] = []
@export var discovered_gems: Array[String] = []
@export var blueprint_progress: Dictionary = {}  # blueprint_id -> research/fragments count
@export var salvage_points: int = 0  # universal crafting currency from salvaging
@export var crafted_item_counts: Dictionary = {}  # item_path or item_id -> craft count
@export var material_codex: Dictionary = {}  # material_id -> {seen, mined, crafted_with}
@export var enemy_codex: Dictionary = {}  # enemy_id -> {seen, kills, drops_seen}
@export var owned_territories: Array[String] = []
@export var permanent_upgrades: Dictionary = {}  # upgrade_id -> level
@export var army_divisions: Array[Dictionary] = []
@export var perk_tokens: int = 0
@export var unlocked_perks: Array[String] = []

# --- Future-proof (empty until implemented) ---
@export var city_states: Dictionary = {}
@export var army_state: Dictionary = {}
@export var world_flags: Dictionary = {}

# --- Legacy path (kept for migration check) ---
const LEGACY_SAVE_PATH = "user://save_data.tres"

static func slot_path(slot: int) -> String:
	return "user://slot_%d.tres" % slot

static func slot_exists(slot: int) -> bool:
	return ResourceLoader.exists(slot_path(slot))

static func load_slot(slot: int) -> SaveData:
	var path = slot_path(slot)
	if ResourceLoader.exists(path):
		var data = ResourceLoader.load(path)
		if data is SaveData:
			data.slot_index = slot
			return data
	return null

static func create_new(slot: int) -> SaveData:
	var data = SaveData.new()
	data.slot_index = slot
	data.character_alive = false  # no character yet, need class selection
	data.created_at = Time.get_datetime_string_from_system()
	data.last_played = data.created_at
	return data

func save_to_slot() -> void:
	last_played = Time.get_datetime_string_from_system()
	ResourceSaver.save(self, slot_path(slot_index))

func wipe_character() -> void:
	character_alive = false
	total_deaths += 1
	# Clear all character fields
	selected_class = "warrior"
	player_level = 1
	player_xp = 0
	stat_points_unspent = 0
	stat_allocations.clear()
	equipped_items.clear()
	inventory_items.clear()
	inventory_quantities.clear()
	inventory_item_states.clear()
	secondary_weapon_path = ""
	quickbar_items = ["", "", "", "", "", ""]
	learned_spells.clear()
	equipped_spell_slots = ["", "", "", "", "", ""]
	pet_data.clear()
	save_to_slot()

# Backward compat wrapper — existing code calls save_game()
func save_game() -> void:
	save_to_slot()

# Legacy loader (used only for migration)
static func load_game() -> SaveData:
	if ResourceLoader.exists(LEGACY_SAVE_PATH):
		var data = ResourceLoader.load(LEGACY_SAVE_PATH)
		if data is SaveData:
			return data
	return SaveData.new()
