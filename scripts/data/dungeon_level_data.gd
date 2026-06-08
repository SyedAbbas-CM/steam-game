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
@export var west_branch: Array = []  # [{type, room_type}] — west branch from start room
@export var south_branch: Array = []  # [{trap}] — south branch showcase rooms (one trap each)
@export var arena_room_scale: int = 1  # Test/showcase arenas can override room size explicitly

## Single knob controlling corridor look across the floor.
## 0.0 = straight short narrow (early game, beginner-friendly)
## 1.0 = mixed                  (default — current behavior)
## 2.0 = bendy long wide        (late game, hostile)
## Drives: bend chance, length class, half-width, and trap density.
@export_range(0.0, 2.0, 0.1) var corridor_complexity: float = 1.0
@export var chest_loot: Array = []  # [{min_items, max_items, trap_chance, items: [{name, chance, min, max}]}]
@export var has_rail_traps: bool = false
