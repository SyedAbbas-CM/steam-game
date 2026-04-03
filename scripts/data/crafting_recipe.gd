class_name CraftingRecipe
extends Resource

@export var id: String = ""
@export var recipe_name: String = ""
@export var recipe_type: String = ""  # "blacksmith" or "alchemist"
@export var ingredients: Array[Dictionary] = []  # [{item_name: String, count: int}]
@export var gold_cost: int = 0
@export var result_item_path: String = ""  # res:// path to result EquipmentItem .tres
@export var result_count: int = 1
@export var required_level: int = 1
