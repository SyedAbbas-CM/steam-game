class_name LoyZoneData
extends Resource

@export var id: String = ""
@export var zone_name: String = ""
@export var tileset: int = 0
@export var width: int = 25
@export var height: int = 25
@export var world_pos: Vector2i = Vector2i.ZERO  # mx, my from zone XML
@export var dungeon_base: String = ""
@export var dungeon_count: int = 0
@export var description: String = ""
@export var baked_offset: Vector2i = Vector2i(-99999, -99999)  # Tile offset on overworld map
@export var baked_scale: int = 1  # Scale factor used during bake (each LoY tile = NxN output tiles)

@export_group("Exits")
@export var exits: Array[Dictionary] = []  # [{target, x, y, tx, ty}]

@export_group("NPCs")
@export var npcs: Array[Dictionary] = []  # [{name, tile, type, x, y, portrait}]

@export_group("Signs")
@export var signs: Array[Dictionary] = []  # [{message, x, y}]

@export_group("Spawns")
@export var spawns: Array[Dictionary] = []  # [{type, x, y, width, height, chance}]

@export_group("Buildings")
@export var houses: Array[Dictionary] = []  # [{sign, width, height, x, y, dx, dy}]

@export_group("Overrides")
@export var tile_overrides: Dictionary = {}  # {"x,y": sprite_idx} — hand-painted tile changes from web editor
