class_name SaveData
extends Resource

# Persistent currencies
var gold: int = 0
var relics: int = 0
var troop_tokens: int = 0

# Lifetime stats
var total_runs: int = 0
var best_floor: int = 0
var total_enemies_killed: int = 0
var total_gold_earned: int = 0

# Unlocks
var discovered_blueprints: Array[String] = []
var owned_territories: Array[String] = []
var permanent_upgrades: Dictionary = {}  # upgrade_id -> level

# Army
var army_divisions: Array[Dictionary] = []

# Quest state
var quest_states: Dictionary = {}  # quest_id -> {active, values}
var completed_quests: Array[String] = []
var npc_states: Dictionary = {}  # npc_name -> {talked, flags}

# Pets
var pet_data: Array = []  # [{type, name, level, xp, active}]

# Player progression
var player_level: int = 1
var player_xp: int = 0
var stat_points_unspent: int = 0
var stat_allocations: Dictionary = {}  # "vitality" -> count

const SAVE_PATH = "user://save_data.tres"

static func load_game() -> SaveData:
	if ResourceLoader.exists(SAVE_PATH):
		var data = ResourceLoader.load(SAVE_PATH)
		if data is SaveData:
			return data
	return SaveData.new()

func save_game() -> void:
	ResourceSaver.save(self, SAVE_PATH)
