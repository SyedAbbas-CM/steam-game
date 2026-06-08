extends Node

## Manages unlocked perks, token currency, and perk effect queries.

var unlocked_perks: Array[String] = []  # perk_ids
var perk_tokens: int = 0

# Cache all loaded perk definitions
var _all_perks: Dictionary = {}  # perk_id -> PerkDefinition

signal perk_unlocked(perk_id: String)
signal tokens_changed(new_count: int)

func _ready() -> void:
	_load_all_perks()

func _load_all_perks() -> void:
	var dirs = ["res://resources/perks/warrior", "res://resources/perks/archer",
				"res://resources/perks/wizard", "res://resources/perks/mercenary",
				"res://resources/perks/general"]
	for dir_path in dirs:
		var dir = DirAccess.open(dir_path)
		if not dir:
			continue
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.ends_with(".tres"):
				var perk = load(dir_path + "/" + fname) as PerkDefinition
				if perk:
					_all_perks[perk.perk_id] = perk
			fname = dir.get_next()
		dir.list_dir_end()

func add_token(amount: int = 1) -> void:
	perk_tokens += amount
	tokens_changed.emit(perk_tokens)

func spend_token() -> bool:
	if perk_tokens <= 0:
		return false
	perk_tokens -= 1
	tokens_changed.emit(perk_tokens)
	return true

func can_unlock(perk_id: String) -> bool:
	var why = unlock_blocker(perk_id)
	return why == ""

## Returns "" if can unlock, otherwise a human-readable reason.
func unlock_blocker(perk_id: String) -> String:
	if perk_id in unlocked_perks:
		return "Already unlocked"
	var perk = _all_perks.get(perk_id) as PerkDefinition
	if not perk:
		return "Unknown perk"
	# Class requirement (empty = cross-class, anyone can take). "archer" and "ranger" alias.
	var gm = get_node_or_null("/root/GameManager")
	if gm and perk.class_required != "":
		var sel = gm.selected_class
		var req = perk.class_required
		var same = (sel == req) \
			or (sel == "ranger" and req == "archer") \
			or (sel == "archer" and req == "ranger")
		if not same:
			return "Wrong class (%s only)" % req
	# Prerequisites
	for prereq in perk.prerequisites:
		if prereq not in unlocked_perks:
			var pname = _all_perks[prereq].perk_name if _all_perks.has(prereq) else prereq
			return "Requires perk: %s" % pname
	# Stat requirements
	var ls = _get_level_system()
	if ls and perk.stat_requirements.size() > 0:
		for cat in perk.stat_requirements:
			var need = int(perk.stat_requirements[cat])
			var have = ls.get_allocation_points(cat) if ls.has_method("get_allocation_points") else ls.allocated.get(cat, 0)
			if have < need:
				var disp = LevelSystem.display_name(cat) if ls else cat.to_upper()
				return "Requires %d %s (have %d)" % [need, disp, have]
	# Token cost
	if perk_tokens <= 0:
		return "Need a perk token (kill a boss)"
	return ""

func _get_level_system() -> Node:
	var p = get_tree().get_first_node_in_group("player") if get_tree() else null
	if p and "level_system" in p:
		return p.level_system
	return null

func unlock_perk(perk_id: String) -> bool:
	if not can_unlock(perk_id):
		return false
	if not spend_token():
		return false
	unlocked_perks.append(perk_id)
	perk_unlocked.emit(perk_id)
	return true

func has_perk(perk_id: String) -> bool:
	return perk_id in unlocked_perks

## Check if player has a specific special effect from any unlocked perk
func has_special(effect_name: String) -> bool:
	for pid in unlocked_perks:
		var perk = _all_perks.get(pid) as PerkDefinition
		if perk and perk.special_effect == effect_name:
			return true
	return false

## Get total flat stat bonus from all unlocked perks
func get_stat_bonus(stat_type: int) -> float:
	var total: float = 0.0
	for pid in unlocked_perks:
		var perk = _all_perks.get(pid) as PerkDefinition
		if perk and not perk.is_percent and perk.stat_bonuses.has(stat_type):
			total += perk.stat_bonuses[stat_type]
	return total

## Get total percent stat bonus from all unlocked perks
func get_stat_percent_bonus(stat_type: int) -> float:
	var total: float = 0.0
	for pid in unlocked_perks:
		var perk = _all_perks.get(pid) as PerkDefinition
		if perk and perk.is_percent and perk.stat_bonuses.has(stat_type):
			total += perk.stat_bonuses[stat_type]
	return total

## Get all perks for a given class
func get_class_perks(class_id: String) -> Array[PerkDefinition]:
	var result: Array[PerkDefinition] = []
	for perk in _all_perks.values():
		if perk.class_required == class_id:
			result.append(perk)
	result.sort_custom(func(a, b): return a.tier < b.tier if a.tier != b.tier else a.perk_id < b.perk_id)
	return result

## Get cross-class general perks (class_required == "")
func get_general_perks() -> Array[PerkDefinition]:
	var result: Array[PerkDefinition] = []
	for perk in _all_perks.values():
		if perk.class_required == "":
			result.append(perk)
	result.sort_custom(func(a, b): return a.tier < b.tier if a.tier != b.tier else a.perk_id < b.perk_id)
	return result

func save_to_dict() -> Dictionary:
	return {
		"unlocked_perks": unlocked_perks.duplicate(),
		"perk_tokens": perk_tokens,
	}

func load_from_dict(data: Dictionary) -> void:
	unlocked_perks.clear()
	var saved = data.get("unlocked_perks", [])
	for pid in saved:
		unlocked_perks.append(pid as String)
	perk_tokens = data.get("perk_tokens", 0)
