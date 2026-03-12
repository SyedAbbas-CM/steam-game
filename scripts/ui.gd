extends CanvasLayer

@onready var hp_label: Label = $HPLabel
@onready var items_label: Label = $ItemsLabel
var player: Node2D
var equipment_manager: EquipmentManager

func _ready() -> void:
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.hp_changed.connect(_on_hp_changed)
		_on_hp_changed(player.hp)

		equipment_manager = player.get_node_or_null("EquipmentManager")
		if equipment_manager:
			equipment_manager.stats_changed.connect(_on_stats_changed)

func _on_hp_changed(new_hp: int) -> void:
	var max_hp = player.max_hp if player else 5
	hp_label.text = "HP: " + str(new_hp) + "/" + str(max_hp)

func _on_stats_changed() -> void:
	if not equipment_manager:
		return
	var items = equipment_manager.get_equipped_items()
	var count = items.size()
	if count == 0:
		items_label.text = ""
		return

	var last_item = items[-1]
	items_label.text = "+" + last_item.item_name + " (" + str(count) + " items)"

	# Flash the text briefly
	var tween = create_tween()
	items_label.modulate = Color.GREEN
	tween.tween_property(items_label, "modulate", Color.WHITE, 0.5)
