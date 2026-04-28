extends Node

## Manages factions, territory ownership, diplomacy, and enemy attacks.
## Autoload singleton — registered in project.godot.

signal territory_changed(zone_id: String, new_owner: String)
signal faction_attitude_changed(faction_id: String, new_attitude: int)
signal territory_attacked(zone_id: String, attacker_faction: String, attacker_army: Array)

# faction_id -> { "name": String, "color": Color, "home_zones": Array, "attitude": int, "army_budget": int }
var factions: Dictionary = {}
# zone_id -> owner string: faction_id, "player", or "" (neutral)
var territory_owners: Dictionary = {}
# zone connectivity cache: zone_id -> Array of connected zone_ids
var _zone_connections: Dictionary = {}

var _attack_timer: float = 0.0
const ATTACK_CHECK_INTERVAL := 180.0  # 3 minutes between attack checks
const MIN_ATTACK_ATTITUDE := -30  # Only factions more hostile than this attack

func _ready() -> void:
	_load_zone_connections()
	# Defer init until GameManager is ready
	call_deferred("_deferred_init")

func _deferred_init() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.save_data:
		load_from(gm.save_data)
	else:
		_init_factions()

func _init_factions() -> void:
	factions = {
		"raiders": {
			"name": "Dark Wood Raiders",
			"color": Color(0.7, 0.25, 0.2),
			"home_zones": ["wild1", "for1", "clearing"],
			"attitude": -50,
			"army_budget": 80,
		},
		"garrison": {
			"name": "Staging Garrison",
			"color": Color(0.4, 0.4, 0.7),
			"home_zones": ["crossroads"],
			"attitude": -20,
			"army_budget": 100,
		},
		"marauders": {
			"name": "Farm Marauders",
			"color": Color(0.6, 0.55, 0.2),
			"home_zones": ["farm"],
			"attitude": -60,
			"army_budget": 60,
		},
		"bandits": {
			"name": "Highway Bandits",
			"color": Color(0.4, 0.4, 0.4),
			"home_zones": ["brg1", "banditwood"],
			"attitude": -40,
			"army_budget": 70,
		},
		"warband": {
			"name": "Wilderness Warband",
			"color": Color(0.2, 0.55, 0.25),
			"home_zones": ["cold1"],
			"attitude": -30,
			"army_budget": 65,
		},
		"undead": {
			"name": "Undead Legion",
			"color": Color(0.5, 0.2, 0.6),
			"home_zones": ["aria-g"],
			"attitude": -80,
			"army_budget": 90,
		},
	}
	# Assign home zones to factions
	territory_owners.clear()
	for fac_id in factions:
		for zone_id in factions[fac_id]["home_zones"]:
			territory_owners[zone_id] = fac_id
	# Player starts owning aria (safe town)
	territory_owners["aria"] = "player"
	_expand_initial_territories()

func _expand_initial_territories() -> void:
	## BFS from each faction's home zones to capture up to 3 adjacent neutral zones.
	for fac_id in factions:
		var frontier: Array = factions[fac_id]["home_zones"].duplicate()
		var captured := 0
		var visited: Dictionary = {}
		for hz in frontier:
			visited[hz] = true
		while not frontier.is_empty() and captured < 3:
			var next_frontier: Array = []
			for zone_id in frontier:
				for neighbor in _zone_connections.get(zone_id, []):
					if visited.has(neighbor):
						continue
					visited[neighbor] = true
					var owner: String = territory_owners.get(neighbor, "")
					if owner == "":
						territory_owners[neighbor] = fac_id
						captured += 1
						next_frontier.append(neighbor)
						if captured >= 3:
							break
				if captured >= 3:
					break
			frontier = next_frontier

func _process(delta: float) -> void:
	_attack_timer += delta
	if _attack_timer >= ATTACK_CHECK_INTERVAL:
		_attack_timer = 0.0
		_check_enemy_attacks()

func _load_zone_connections() -> void:
	## Build zone connectivity graph from zone .tres exit data.
	_zone_connections.clear()
	var zones_dir := "res://resources/world/zones/"
	var dir := DirAccess.open(zones_dir)
	if not dir:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var zone = load(zones_dir + fname)
			if zone and zone is LoyZoneData:
				var zid: String = zone.id
				if not _zone_connections.has(zid):
					_zone_connections[zid] = []
				for exit_data in zone.exits:
					var target: String = exit_data.get("target", "")
					if target != "" and target not in _zone_connections[zid]:
						_zone_connections[zid].append(target)
					# Bidirectional
					if not _zone_connections.has(target):
						_zone_connections[target] = []
					if zid not in _zone_connections[target]:
						_zone_connections[target].append(zid)
		fname = dir.get_next()
	dir.list_dir_end()

func get_zone_neighbors(zone_id: String) -> Array:
	return _zone_connections.get(zone_id, [])

func get_zone_owner(zone_id: String) -> String:
	var owner = territory_owners.get(zone_id, "")
	return str(owner)

func get_owner_display_name(owner_id: String) -> String:
	if owner_id == "player":
		return "Your Territory"
	if owner_id == "":
		return "Neutral"
	if factions.has(owner_id):
		return factions[owner_id]["name"]
	return owner_id

func get_owner_color(owner_id: String) -> Color:
	if owner_id == "player":
		return Color(0.3, 0.8, 0.3)
	if owner_id == "":
		return Color(0.5, 0.5, 0.5)
	if factions.has(owner_id):
		return factions[owner_id]["color"]
	return Color.WHITE

func get_attitude_label(attitude: int) -> String:
	if attitude >= 50:
		return "Allied"
	if attitude >= 10:
		return "Friendly"
	if attitude >= -30:
		return "Neutral"
	if attitude >= -60:
		return "Hostile"
	return "At War"

func get_attitude_color(attitude: int) -> Color:
	if attitude >= 50:
		return Color(0.3, 0.8, 0.3)
	if attitude >= 10:
		return Color(0.5, 0.7, 0.3)
	if attitude >= -30:
		return Color(0.7, 0.7, 0.3)
	if attitude >= -60:
		return Color(0.8, 0.4, 0.2)
	return Color(0.9, 0.2, 0.2)

func get_player_zones() -> Array:
	var result := []
	for zone_id in territory_owners:
		if territory_owners[zone_id] == "player":
			result.append(zone_id)
	return result

func get_attackable_zones() -> Array:
	## Enemy zones adjacent to player zones.
	var player_zones := get_player_zones()
	var result := []
	for pz in player_zones:
		for neighbor in get_zone_neighbors(pz):
			var owner := get_zone_owner(neighbor)
			if owner != "player" and owner != "" and neighbor not in result:
				result.append(neighbor)
	return result

func get_defendable_zones() -> Array:
	## Player zones adjacent to hostile faction zones.
	var player_zones := get_player_zones()
	var result := []
	for pz in player_zones:
		for neighbor in get_zone_neighbors(pz):
			var owner := get_zone_owner(neighbor)
			if owner != "player" and owner != "":
				if factions.has(owner) and factions[owner]["attitude"] < MIN_ATTACK_ATTITUDE:
					if pz not in result:
						result.append(pz)
	return result

# --- Battle Integration ---

func on_battle_won(zone_id: String) -> void:
	var old_owner := get_zone_owner(zone_id)
	territory_owners[zone_id] = "player"
	# Lower attitude with defeated faction
	if old_owner != "" and old_owner != "player" and factions.has(old_owner):
		factions[old_owner]["attitude"] = maxi(-100, factions[old_owner]["attitude"] - 20)
		faction_attitude_changed.emit(old_owner, factions[old_owner]["attitude"])
	territory_changed.emit(zone_id, "player")
	print("FactionManager: Player conquered %s (was %s)" % [zone_id, old_owner])

func on_battle_lost(zone_id: String) -> void:
	var old_owner: String = territory_owners.get(zone_id, "")
	if old_owner == "player":
		# Find which faction is adjacent to reclaim
		for neighbor in get_zone_neighbors(zone_id):
			var n_owner := get_zone_owner(neighbor)
			if n_owner != "player" and n_owner != "" and factions.has(n_owner):
				territory_owners[zone_id] = n_owner
				territory_changed.emit(zone_id, n_owner)
				print("FactionManager: %s reclaimed %s after player defeat" % [n_owner, zone_id])
				return
		# No adjacent faction — becomes neutral
		territory_owners[zone_id] = ""
		territory_changed.emit(zone_id, "")

# --- Enemy Attacks ---

func _check_enemy_attacks() -> void:
	## Hostile factions may attack player territories adjacent to their zones.
	var player_zones := get_player_zones()
	if player_zones.is_empty():
		return
	for fac_id in factions:
		var att: int = factions[fac_id]["attitude"]
		if att >= MIN_ATTACK_ATTITUDE:
			continue
		# Check if this faction has a zone adjacent to a player zone
		var fac_zones := []
		for zone_id in territory_owners:
			if territory_owners[zone_id] == fac_id:
				fac_zones.append(zone_id)
		for fz in fac_zones:
			for neighbor in get_zone_neighbors(fz):
				if neighbor in player_zones:
					# Attack chance based on hostility
					var chance := absf(float(att)) / 300.0
					if randf() < chance:
						var army := _build_attack_army(fac_id)
						territory_attacked.emit(neighbor, fac_id, army)
						print("FactionManager: %s attacks %s! (attitude=%d)" % [factions[fac_id]["name"], neighbor, att])
						return  # Only one attack per check

func _build_attack_army(faction_id: String) -> Array:
	## Generate an attack army from faction budget.
	var budget: int = factions[faction_id].get("army_budget", 60)
	# Simple composition: mostly infantry + some support
	var army := []
	var remaining := budget
	var inf := maxi(5, int(remaining * 0.4))
	remaining -= inf
	army.append({"type": BattleUnitSystem.UnitType.INFANTRY, "count": inf, "formation": BattleUnitSystem.FormationType.LINE})
	if remaining >= 6:
		var arch := mini(int(remaining * 0.4) / 2, 20)
		remaining -= arch * 2
		army.append({"type": BattleUnitSystem.UnitType.ARCHER, "count": arch, "formation": BattleUnitSystem.FormationType.LOOSE_LINE})
	if remaining >= 12:
		var cav := mini(remaining / 4, 15)
		remaining -= cav * 4
		army.append({"type": BattleUnitSystem.UnitType.CAVALRY, "count": cav, "formation": BattleUnitSystem.FormationType.WEDGE})
	if remaining >= 6:
		var hi := mini(remaining / 3, 10)
		army.append({"type": BattleUnitSystem.UnitType.HEAVY_INFANTRY, "count": hi, "formation": BattleUnitSystem.FormationType.SHIELD_WALL})
	return army

# --- Diplomacy Actions ---

func improve_relations(faction_id: String, amount: int) -> void:
	if factions.has(faction_id):
		factions[faction_id]["attitude"] = mini(100, factions[faction_id]["attitude"] + amount)
		faction_attitude_changed.emit(faction_id, factions[faction_id]["attitude"])

func worsen_relations(faction_id: String, amount: int) -> void:
	if factions.has(faction_id):
		factions[faction_id]["attitude"] = maxi(-100, factions[faction_id]["attitude"] - amount)
		faction_attitude_changed.emit(faction_id, factions[faction_id]["attitude"])

# --- Persistence ---

func save_to(save_data) -> void:
	save_data.city_states = {
		"factions": factions.duplicate(true),
		"territory_owners": territory_owners.duplicate(true),
	}

func load_from(save_data) -> void:
	if save_data.city_states.has("factions"):
		factions = save_data.city_states["factions"]
		territory_owners = save_data.city_states.get("territory_owners", {})
		# Ensure colors are proper Color objects (may deserialize as strings)
		for fac_id in factions:
			if factions[fac_id]["color"] is String:
				factions[fac_id]["color"] = Color(factions[fac_id]["color"])
	else:
		_init_factions()

# --- Auto-resolve for undefended attacks ---

func auto_resolve_attack(zone_id: String, attacker_faction: String, garrison_strength: int) -> bool:
	## Returns true if defense succeeds. Garrison strength = total garrison unit count.
	var budget: int = factions[attacker_faction].get("army_budget", 60) if factions.has(attacker_faction) else 60
	# Defense succeeds if garrison can hold off > 70% of attacker
	if garrison_strength > int(budget * 0.7):
		print("FactionManager: Garrison defended %s (strength %d vs budget %d)" % [zone_id, garrison_strength, budget])
		return true
	else:
		# Territory lost
		territory_owners[zone_id] = attacker_faction
		territory_changed.emit(zone_id, attacker_faction)
		print("FactionManager: %s lost to %s (garrison %d < budget %d)" % [zone_id, attacker_faction, garrison_strength, budget])
		return false
