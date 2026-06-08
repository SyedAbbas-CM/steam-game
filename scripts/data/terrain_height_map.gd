class_name TerrainHeightMap
extends Resource

## Authored height data for a single map. Save as .tres to ship hand-designed
## elevation layouts (HeightTest showcases, special boss arenas, etc.).
## Loaded by HeightSystem via apply_resource() to seed its runtime dictionaries.

## Packed cell coordinates → height level. Stored as a Dictionary[Vector2i, int]
## but Godot serializes it as a regular Dictionary; keys round-trip as Vector2i.
@export var heights: Dictionary = {}

## Set of cells flagged as ramp tiles. Stored as Dictionary[Vector2i, bool] for
## O(1) lookup; bool values are always true.
@export var ramps: Dictionary = {}

## Optional metadata so a level designer can label what this map represents.
@export var label: String = ""

func set_cell(cell: Vector2i, level: int) -> void:
	heights[cell] = clampi(level, -3, 3)

func get_cell(cell: Vector2i) -> int:
	return int(heights.get(cell, 0))

func set_ramp_cell(cell: Vector2i, on: bool = true) -> void:
	if on:
		ramps[cell] = true
	else:
		ramps.erase(cell)

func is_ramp_cell(cell: Vector2i) -> bool:
	return ramps.has(cell)

func clear() -> void:
	heights.clear()
	ramps.clear()

func bounds() -> Rect2i:
	if heights.is_empty():
		return Rect2i(Vector2i.ZERO, Vector2i.ZERO)
	var min_p := Vector2i(2147483647, 2147483647)
	var max_p := Vector2i(-2147483647, -2147483647)
	for k in heights.keys():
		var c: Vector2i = k
		min_p.x = mini(min_p.x, c.x)
		min_p.y = mini(min_p.y, c.y)
		max_p.x = maxi(max_p.x, c.x)
		max_p.y = maxi(max_p.y, c.y)
	return Rect2i(min_p, max_p - min_p + Vector2i.ONE)
