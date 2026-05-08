class_name MineNode
extends HarvestNode

@export var mine_node_type: String = "ore"  # ore, gem, crystal, cache
@export var blueprint_fragment_id: String = ""
@export var blueprint_fragment_amount: int = 0
@export var gem_discovery_ids: PackedStringArray = PackedStringArray()
@export var codex_material_ids: PackedStringArray = PackedStringArray()

func _harvest() -> void:
	if _depleted or drop_table.is_empty():
		return

	var gm = get_node_or_null("/root/GameManager")
	var discovered_materials: Array[String] = []
	for item_path in drop_table:
		var item_res = load(item_path) as EquipmentItem
		if item_res:
			discovered_materials.append(item_res.item_name)

	super._harvest()

	if gm:
		for material_id in codex_material_ids:
			gm.record_material_discovery(material_id, "mined")
		for material_name in discovered_materials:
			gm.record_material_discovery(material_name, "mined")
		for gem_id in gem_discovery_ids:
			gm.discover_gem(gem_id)
		if blueprint_fragment_id != "" and blueprint_fragment_amount > 0:
			var result = gm.add_blueprint_progress(blueprint_fragment_id, blueprint_fragment_amount)
			var scene_root = get_tree().current_scene
			if scene_root:
				var progress: int = int(result.get("progress", 0))
				FloatingText.spawn(scene_root, global_position + Vector2(0, -18), "+%d Blueprint (%d)" % [blueprint_fragment_amount, progress], Color(0.9, 0.8, 0.4))
