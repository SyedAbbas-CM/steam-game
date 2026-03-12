extends Node

## Autoload singleton managing quests, dialogue execution, and NPC scripts

signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal quest_progressed(quest_id: String, property_name: String, value: int)
signal show_dialogue_requested(name: String, portrait: int, text: String, options: Array)
signal dialogue_option_chosen(index: int)

var definitions: Dictionary = {}  # quest_id -> QuestDefinition
var active_quests: Dictionary = {}  # quest_id -> {active, values: Dictionary}
var completed_quests: Array[String] = []
var npc_scripts: Dictionary = {}  # script_name -> Array[Dictionary] (commands)
var current_zone: String = ""
var _item_cache: Dictionary = {}  # item_name -> resource_path

# Script execution state
var _script_queue: Array = []
var _waiting_for_dialogue: bool = false
var _pending_option_scripts: Array = []  # scripts for each dialogue option

func _ready() -> void:
	_load_quest_definitions()
	_load_npc_scripts()
	_load_item_cache()
	_load_state()

func _load_quest_definitions() -> void:
	var dir = DirAccess.open("res://resources/quests/")
	if not dir:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var quest = load("res://resources/quests/" + fname) as QuestDefinition
			if quest and quest.id != "":
				definitions[quest.id] = quest
		fname = dir.get_next()
	print("QuestManager: Loaded " + str(definitions.size()) + " quest definitions")

func _load_npc_scripts() -> void:
	var dir = DirAccess.open("res://resources/npcs/scripts/")
	if not dir:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res = load("res://resources/npcs/scripts/" + fname)
			if res and res is Resource:
				var script_name = fname.get_basename()
				npc_scripts[script_name] = res.get("commands") if res.get("commands") else []
		fname = dir.get_next()
	print("QuestManager: Loaded " + str(npc_scripts.size()) + " NPC scripts")

func _load_item_cache() -> void:
	var dir = DirAccess.open("res://resources/items/loy/")
	if not dir:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var path = "res://resources/items/loy/" + fname
			var item = load(path) as EquipmentItem
			if item:
				_item_cache[item.item_name] = path
		fname = dir.get_next()
	print("QuestManager: Cached " + str(_item_cache.size()) + " item names")

func _get_player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _get_equipment_manager() -> EquipmentManager:
	var p = _get_player()
	if p:
		return p.get_node_or_null("EquipmentManager") as EquipmentManager
	return null

func _count_item_in_inventory(item_name: String) -> int:
	var em = _get_equipment_manager()
	if not em:
		return 0
	var count = 0
	for item in em.inventory:
		if item and item.item_name == item_name:
			count += 1
	return count

func _remove_item_from_inventory(item_name: String, amount: int) -> int:
	var em = _get_equipment_manager()
	if not em:
		return 0
	var removed = 0
	# Iterate backwards to safely remove
	for i in range(em.inventory.size() - 1, -1, -1):
		if removed >= amount:
			break
		if em.inventory[i] and em.inventory[i].item_name == item_name:
			em.inventory.remove_at(i)
			removed += 1
	if removed > 0:
		em.inventory_changed.emit()
	return removed

func _add_item_to_inventory(item_name: String, amount: int) -> int:
	var em = _get_equipment_manager()
	if not em:
		return 0
	if not _item_cache.has(item_name):
		print("QuestManager: Unknown item '%s'" % item_name)
		return 0
	var path = _item_cache[item_name]
	var base = load(path) as EquipmentItem
	if not base:
		return 0
	var added = 0
	for _i in range(amount):
		if em.add_to_inventory(base.duplicate()):
			added += 1
		else:
			break  # inventory full
	return added

func _load_state() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.save_data:
		if gm.save_data.get("quest_states"):
			active_quests = gm.save_data.quest_states.duplicate(true)
		if gm.save_data.get("completed_quests"):
			completed_quests = gm.save_data.completed_quests.duplicate()

func save_state() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.save_data:
		gm.save_data.quest_states = active_quests.duplicate(true)
		gm.save_data.completed_quests = completed_quests.duplicate()
		gm.save_data.save_game()

# --- Quest API ---

func is_quest_active(quest_id: String) -> bool:
	return active_quests.has(quest_id) and active_quests[quest_id].get("active", false)

func is_quest_completed(quest_id: String) -> bool:
	return quest_id in completed_quests

func start_quest(quest_id: String) -> void:
	if is_quest_active(quest_id) or is_quest_completed(quest_id):
		return
	active_quests[quest_id] = {"active": true, "values": {}}
	quest_started.emit(quest_id)
	save_state()
	print("Quest started: " + quest_id)

func complete_quest(quest_id: String) -> void:
	if active_quests.has(quest_id):
		active_quests[quest_id]["active"] = false
	if quest_id not in completed_quests:
		completed_quests.append(quest_id)
	quest_completed.emit(quest_id)
	save_state()
	print("Quest completed: " + quest_id)

func get_quest_value(quest_id: String, index: int) -> int:
	if not active_quests.has(quest_id):
		return 0
	return active_quests[quest_id]["values"].get(str(index), 0)

func set_quest_value(quest_id: String, index: int, value: int) -> void:
	if not active_quests.has(quest_id):
		active_quests[quest_id] = {"active": false, "values": {}}
	active_quests[quest_id]["values"][str(index)] = value

func increment_quest_value(quest_id: String, index: int) -> void:
	var current = get_quest_value(quest_id, index)
	set_quest_value(quest_id, index, current + 1)

# --- Event Handling ---

func on_enemy_killed(enemy_name: String) -> void:
	for quest_id in active_quests:
		if not active_quests[quest_id].get("active", false):
			continue
		if not definitions.has(quest_id):
			continue
		var quest = definitions[quest_id]
		for event in quest.events:
			if event.get("type") == "kill" and event.get("param") == enemy_name:
				_execute_script(event.get("script", []), quest_id)

func on_zone_entered(zone_id: String) -> void:
	current_zone = zone_id
	for quest_id in active_quests:
		if not active_quests[quest_id].get("active", false):
			continue
		if not definitions.has(quest_id):
			continue
		var quest = definitions[quest_id]
		for event in quest.events:
			if event.get("type") == "quest" and event.get("param") == zone_id:
				_execute_script(event.get("script", []), quest_id)

func on_npc_activated(npc_name: String) -> void:
	for quest_id in active_quests:
		if not active_quests[quest_id].get("active", false):
			continue
		if not definitions.has(quest_id):
			continue
		var quest = definitions[quest_id]
		for event in quest.events:
			if event.get("type") == "activate" and event.get("param") == npc_name:
				_execute_script(event.get("script", []), quest_id)

func offer_quest(quest_id: String) -> void:
	if not definitions.has(quest_id):
		return
	if is_quest_active(quest_id) or is_quest_completed(quest_id):
		return
	var quest = definitions[quest_id]
	_execute_script(quest.start_script, quest_id)

func run_npc_script(script_name: String) -> void:
	if npc_scripts.has(script_name):
		_execute_script(npc_scripts[script_name], "")

# --- Script Executor ---

func _execute_script(commands: Array, context_quest_id: String) -> void:
	var i = 0
	while i < commands.size():
		var cmd = commands[i]
		var cmd_type = cmd.get("cmd", "")

		match cmd_type:
			"showDialog":
				var options = cmd.get("options", [])
				var option_names: Array = []
				_pending_option_scripts = []
				for opt in options:
					option_names.append(opt.get("name", "Ok"))
					_pending_option_scripts.append(opt.get("script", []))

				_waiting_for_dialogue = true
				show_dialogue_requested.emit(
					cmd.get("name", ""),
					cmd.get("portrait", 0),
					cmd.get("text", ""),
					option_names
				)
				# Wait for dialogue choice
				var chosen = await dialogue_option_chosen
				_waiting_for_dialogue = false
				# Execute the chosen option's script
				if chosen >= 0 and chosen < _pending_option_scripts.size():
					var sub_script = _pending_option_scripts[chosen]
					if sub_script.size() > 0:
						await _execute_script(sub_script, context_quest_id)

			"if":
				var attr = cmd.get("attribute", "")
				var compare = int(cmd.get("compare", "0"))
				var op = cmd.get("operation", "gt")
				var sub_script = cmd.get("script", [])
				if _check_condition(attr, compare, op, context_quest_id):
					await _execute_script(sub_script, context_quest_id)

			"ifNot":
				var attr = cmd.get("attribute", "")
				var compare = int(cmd.get("compare", "0"))
				var op = cmd.get("operation", "gt")
				var sub_script = cmd.get("script", [])
				if not _check_condition(attr, compare, op, context_quest_id):
					await _execute_script(sub_script, context_quest_id)

			"startQuest":
				var qid = cmd.get("id", context_quest_id)
				start_quest(qid)

			"completeQuest":
				var qid = cmd.get("id", context_quest_id)
				if qid != "":
					complete_quest(qid)

			"set":
				var qid = cmd.get("id", context_quest_id)
				if qid == "":
					qid = context_quest_id
				var idx = int(cmd.get("index", "0"))
				var val = int(cmd.get("value", "0"))
				set_quest_value(qid, idx, val)

			"increment", "inc":
				var idx = int(cmd.get("index", "0"))
				if context_quest_id != "":
					increment_quest_value(context_quest_id, idx)
					var prop_name = "property_" + str(idx)
					var quest = definitions.get(context_quest_id)
					if quest:
						for prop in quest.properties:
							if int(prop.get("index", -1)) == idx:
								prop_name = prop.get("name", prop_name)
					var new_val = get_quest_value(context_quest_id, idx)
					quest_progressed.emit(context_quest_id, prop_name, new_val)

			"getItem":
				var item_name = cmd.get("name", "")
				var count = int(cmd.get("count", "1"))
				if count <= 0:
					count = 1
				if item_name == "Gold":
					var gm = get_node_or_null("/root/GameManager")
					if gm:
						gm.add_gold(count)
				else:
					var added = _add_item_to_inventory(item_name, count)
					if added > 0:
						print("QuestManager: Gave %d x %s" % [added, item_name])

			"takeItem":
				var item_name = cmd.get("name", "")
				var count = int(cmd.get("count", "1"))
				if count <= 0:
					count = 1
				var removed = _remove_item_from_inventory(item_name, count)
				if removed > 0:
					print("QuestManager: Took %d x %s" % [removed, item_name])

			"getExp":
				var value = int(cmd.get("value", "0"))
				if value > 0:
					var p = _get_player()
					if p and p.has_method("gain_xp"):
						p.gain_xp(value)
						print("QuestManager: Awarded %d XP" % value)

			"giveGold":
				var amount = int(cmd.get("count", "0"))
				var gm = get_node_or_null("/root/GameManager")
				if gm:
					gm.add_gold(amount)

			"moveToMap":
				var _map = cmd.get("map", "")
				var _x = int(cmd.get("x", "0"))
				var _y = int(cmd.get("y", "0"))
				# TODO: teleport player

			"spawn":
				pass  # TODO: spawn enemy

			"offerZoneQuests":
				var zone = cmd.get("zone", current_zone)
				_offer_zone_quests_for(zone)

			"openShop":
				var sid = cmd.get("shop", "")
				if sid != "":
					var shop_ui: ShopUI = null
					for child in get_tree().root.get_children():
						for sub in child.get_children():
							if sub is ShopUI:
								shop_ui = sub
								break
					if shop_ui:
						shop_ui.open_shop(sid)

		i += 1

func _check_condition(attribute: String, compare: int, operation: String, quest_id: String) -> bool:
	var value = _resolve_attribute(attribute, quest_id)
	match operation:
		"gt":
			return value > compare
		"lt":
			return value < compare
		"eq":
			return value == compare
		"neq":
			return value != compare
		"gte":
			return value >= compare
		"lte":
			return value <= compare
	return false

func _resolve_attribute(attribute: String, quest_id: String) -> int:
	# session-QUESTID-INDEX format
	if attribute.begins_with("session-"):
		var parts = attribute.split("-")
		if parts.size() >= 3:
			var qid = parts[1]
			var idx = int(parts[2])
			return get_quest_value(qid, idx)

	# count-ITEMNAME format (count items in inventory)
	if attribute.begins_with("count-"):
		var item_name = attribute.substr(6)
		return _count_item_in_inventory(item_name)

	# hasFreeSlot - check if inventory has space
	if attribute == "hasFreeSlot":
		var em = _get_equipment_manager()
		if em:
			return 1 if em.inventory.size() < em.MAX_INVENTORY else 0
		return 0

	# stat-level format
	if attribute.begins_with("stat-"):
		var stat_name = attribute.substr(5)
		if stat_name == "level":
			var p = _get_player()
			if p:
				var ls = p.get_node_or_null("LevelSystem") as LevelSystem
				if ls:
					return ls.level
			return 1
		return 0

	# quest-QUESTID-active
	if attribute.begins_with("quest-") and attribute.ends_with("-active"):
		var qid = attribute.substr(6, attribute.length() - 13)
		return 1 if is_quest_active(qid) else 0

	# quest-QUESTID-complete
	if attribute.begins_with("quest-") and attribute.ends_with("-complete"):
		var qid = attribute.substr(6, attribute.length() - 15)
		return 1 if is_quest_completed(qid) else 0

	return 0

# --- Dialogue response ---

func on_dialogue_choice(index: int) -> void:
	dialogue_option_chosen.emit(index)

func _offer_zone_quests_for(zone: String) -> void:
	var player_level = 1
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var ls = player.get_node_or_null("LevelSystem") as LevelSystem
		if ls:
			player_level = ls.level

	# Check active quests in this zone first
	for quest_id in active_quests:
		if not active_quests[quest_id].get("active", false):
			continue
		var quest = definitions.get(quest_id) as QuestDefinition
		if quest and (quest.target_location == zone or quest.location == zone):
			on_zone_entered(zone)
			return

	# Collect available quests
	var available: Array = []
	for quest_id in definitions:
		var quest = definitions[quest_id] as QuestDefinition
		if quest.location != zone:
			continue
		if is_quest_active(quest_id) or is_quest_completed(quest_id):
			continue
		available.append(quest)

	available.sort_custom(func(a: QuestDefinition, b: QuestDefinition) -> bool:
		return a.level < b.level
	)

	for quest in available:
		if quest.level <= player_level + 5:
			offer_quest(quest.id)
			return

	if available.size() > 0:
		offer_quest(available[0].id)
		return

	# No quests available
	_waiting_for_dialogue = true
	show_dialogue_requested.emit("Elder", 147, "All is well in the village. You've done great work, adventurer!", ["Ok"])
