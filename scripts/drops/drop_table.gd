class_name DropTable
extends Resource

@export var entries: Array[DropEntry] = []
@export var drop_chance: float = 0.3

func roll() -> EquipmentItem:
	if randf() > drop_chance:
		return null

	# Demo allowlist: when GameManager.demo_mode is true, restrict the roll to
	# entries whose item.demo_approved is true. Lets us share the same drop
	# tables between demo and full builds — designers just flip the flag per
	# item instead of maintaining parallel tables. Quest items always pass.
	var active_entries: Array[DropEntry] = entries
	var gm = Engine.get_main_loop().root.get_node_or_null("GameManager") if Engine.get_main_loop() else null
	if gm and gm.get("demo_mode"):
		var filtered: Array[DropEntry] = []
		for entry in entries:
			if entry == null or entry.item == null:
				continue
			if entry.item.get("demo_approved") or entry.item.get("is_quest_item"):
				filtered.append(entry)
		# If filtering would empty the pool, drop nothing rather than fall back
		# to unreviewed items — better to leave a chest empty than break trust.
		if filtered.is_empty():
			return null
		active_entries = filtered

	var total_weight: float = 0.0
	for entry in active_entries:
		total_weight += entry.weight

	if total_weight <= 0.0:
		return null

	var roll_value = randf() * total_weight
	var cumulative: float = 0.0
	for entry in active_entries:
		cumulative += entry.weight
		if roll_value <= cumulative:
			return entry.item
	return null
