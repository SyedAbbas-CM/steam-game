class_name DropTable
extends Resource

@export var entries: Array[DropEntry] = []
@export var drop_chance: float = 0.3

func roll() -> EquipmentItem:
	if randf() > drop_chance:
		return null

	var total_weight: float = 0.0
	for entry in entries:
		total_weight += entry.weight

	if total_weight <= 0.0:
		return null

	var roll_value = randf() * total_weight
	var cumulative: float = 0.0
	for entry in entries:
		cumulative += entry.weight
		if roll_value <= cumulative:
			return entry.item
	return null
