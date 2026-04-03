class_name DungeonLevelData
extends Resource

@export var id: String = ""
@export var tileset: int = 0
@export var chests: int = 0
@export var width: int = 50
@export var height: int = 35
@export var rooms: int = 25
@export var min_monsters: int = 1
@export var max_monsters: int = 2
@export var aggro_chance: int = 0
@export var requires_key: bool = false
@export var recommended_level: int = 1  # Suggested player level for this floor
@export var legend: String = ""  # Boss name for this level
@export var monster_pool: Array = []  # [{type, chance}]
@export var fixed_monsters: Array = []  # [{type, count}]
@export var branch_monsters: Array = []  # [{type}] — second branch going north from start room
@export var chest_loot: Array = []  # [{min_items, max_items, trap_chance, items: [{name, chance, min, max}]}]
