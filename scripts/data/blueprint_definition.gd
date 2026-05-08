class_name BlueprintDefinition
extends Resource

@export var blueprint_id: String = ""
@export var blueprint_name: String = "Unknown Blueprint"
@export_multiline var description: String = ""
@export var result_item_path: String = ""
@export var station_type: String = "forge"
@export var required_fragments: int = 1
@export var required_salvage_points: int = 0
@export var unlock_tags: PackedStringArray = PackedStringArray()
@export var recipe_paths: PackedStringArray = PackedStringArray()

func is_complete(progress: int) -> bool:
	return progress >= required_fragments

func can_unlock(progress: int, salvage_points: int) -> bool:
	return progress >= required_fragments and salvage_points >= required_salvage_points
