class_name ShopDefinition
extends Resource

@export var id: String = ""
@export var shop_type: String = ""  # weapon, magic, inn, necro
@export var shop_name: String = ""
@export var portrait: int = 0
@export var title: String = ""
@export var welcome: String = ""
@export var nomoney: String = ""
@export var buy_text: String = ""
@export var sell_text: String = ""
@export var stock: Array = []  # [{item_name, required_quest}]
