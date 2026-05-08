class_name GemDefinition
extends Resource

enum GemFamily { RUBY, SAPPHIRE, EMERALD, TOPAZ, AMETHYST, DIAMOND, PRISM }

@export var gem_id: String = ""
@export var gem_name: String = "Unknown Gem"
@export_multiline var description: String = ""
@export var family: GemFamily = GemFamily.RUBY
@export var tier: int = 1
@export var icon: Texture2D
@export var color_hint: Color = Color.WHITE
@export var modifiers: Array[StatModifier] = []
@export var tags: PackedStringArray = PackedStringArray()
@export var buy_price: int = 0
@export var sell_value: int = 0

func get_display_name() -> String:
	return gem_name
