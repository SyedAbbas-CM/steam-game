extends Node

## Manages factions, territory ownership, diplomacy, and enemy attacks.
## Autoload singleton — registered in project.godot.

signal territory_changed(zone_id: String, new_owner: String)
signal faction_attitude_changed(faction_id: String, new_attitude: int)
signal territory_attacked(zone_id: String, attacker_faction: String, attacker_army: Array)
signal ai_battle_resolved(zone_id: String, attacker: String, defender: String, winner: String)

# faction_id -> { "name": String, "color": Color, "home_zones": Array, "attitude": int, "army_size": int, "tier": int }
var factions: Dictionary = {}
# zone_id -> owner string: faction_id, "player", "bandit", or "" (neutral)
var territory_owners: Dictionary = {}
# zone connectivity cache: zone_id -> Array of connected zone_ids
var _zone_connections: Dictionary = {}
# zone_id -> int (BFS distance from haven) for difficulty scaling
var _zone_difficulty: Dictionary = {}

var _attack_timer: float = 0.0
var _ai_sim_timer: float = 0.0
const ATTACK_CHECK_INTERVAL := 180.0  # 3 minutes between attack checks on player
const AI_SIM_INTERVAL := 120.0        # 2 minutes between AI faction wars
const MIN_ATTACK_ATTITUDE := -30      # Only factions more hostile than this attack

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
		"briarvale": {
			"name": "Briarvale",
			"color": Color(0.2, 0.5, 0.8),
			"home_zones": ["briarvale"],
			"attitude": 0,
			"army_size": 120,
			"tier": 3,
		},
		"ashheim": {
			"name": "Ashheim",
			"color": Color(0.6, 0.6, 0.7),
			"home_zones": ["ashheim"],
			"attitude": 0,
			"army_size": 100,
			"tier": 3,
		},
		"cenneth": {
			"name": "Cenneth Citadel",
			"color": Color(0.7, 0.4, 0.2),
			"home_zones": ["cenneth"],
			"attitude": 0,
			"army_size": 110,
			"tier": 3,
		},
		"brackwater": {
			"name": "Brackwater",
			"color": Color(0.3, 0.6, 0.3),
			"home_zones": ["brackwater"],
			"attitude": 0,
			"army_size": 70,
			"tier": 2,
		},
		"duskwatch": {
			"name": "Duskwatch",
			"color": Color(0.5, 0.3, 0.6),
			"home_zones": ["duskwatch"],
			"attitude": 0,
			"army_size": 80,
			"tier": 2,
		},
		"grimhold": {
			"name": "Grimhold",
			"color": Color(0.4, 0.55, 0.65),
			"home_zones": ["grimhold"],
			"attitude": 0,
			"army_size": 60,
			"tier": 2,
		},
		"kor": {
			"name": "Fortress of Kor",
			"color": Color(0.65, 0.5, 0.3),
			"home_zones": ["kor"],
			"attitude": 0,
			"army_size": 50,
			"tier": 1,
		},
		"thule": {
			"name": "Ultima Thule",
			"color": Color(0.3, 0.4, 0.5),
			"home_zones": ["thule"],
			"attitude": 0,
			"army_size": 75,
			"tier": 2,
		},
		"duskport": {
			"name": "Duskport",
			"color": Color(0.2, 0.6, 0.6),
			"home_zones": ["duskport"],
			"attitude": 0,
			"army_size": 65,
			"tier": 2,
		},
		"mirage": {
			"name": "The Mirage",
			"color": Color(0.55, 0.4, 0.4),
			"home_zones": ["mirage"],
			"attitude": 0,
			"army_size": 45,
			"tier": 1,
		},
		"boghollow": {
			"name": "Boghollow",
			"color": Color(0.6, 0.5, 0.2),
			"home_zones": ["boghollow"],
			"attitude": 0,
			"army_size": 40,
			"tier": 1,
		},
		"eldori": {
			"name": "Eldori Ruins",
			"color": Color(0.3, 0.55, 0.25),
			"home_zones": ["eldori"],
			"attitude": 0,
			"army_size": 70,
			"tier": 2,
		},
		"windhold": {
			"name": "Windhold",
			"color": Color(0.45, 0.65, 0.45),
			"home_zones": ["windhold"],
			"attitude": 0,
			"army_size": 65,
			"tier": 2,
		},
		"scorchgate": {
			"name": "Scorchgate",
			"color": Color(0.7, 0.3, 0.2),
			"home_zones": ["scorchgate"],
			"attitude": 0,
			"army_size": 85,
			"tier": 2,
		},
	}
	# Assign home zones to factions
	territory_owners.clear()
	for fac_id in factions:
		for zone_id in factions[fac_id]["home_zones"]:
			territory_owners[zone_id] = fac_id
	# Player starts owning haven (Ravenhollow) + duskfarm (adjacent farmland)
	territory_owners["haven"] = "player"
	territory_owners["duskfarm"] = "player"
	_expand_initial_territories()

func _expand_initial_territories() -> void:
	## Factions expand only 2 rings from home (town + 1-2 nearby zones).
	## Everything unclaimed becomes "bandit" territory.
	const MAX_RINGS := 2

	var frontiers: Dictionary = {}  # faction_id -> Array of zone_ids
	var fac_ids: Array = factions.keys()

	for fac_id in fac_ids:
		frontiers[fac_id] = []
		for zid in territory_owners:
			if territory_owners[zid] == fac_id:
				frontiers[fac_id].append(zid)

	# Limited BFS — each faction expands MAX_RINGS times
	for _ring in MAX_RINGS:
		for fac_id in fac_ids:
			var next_frontier: Array = []
			for zone_id in frontiers[fac_id]:
				for neighbor in _zone_connections.get(zone_id, []):
					var cur_owner: String = territory_owners.get(neighbor, "")
					if cur_owner == "":
						territory_owners[neighbor] = fac_id
						next_frontier.append(neighbor)
			frontiers[fac_id] = next_frontier

	# Mark all remaining unclaimed zones as bandit
	for zid in _zone_connections:
		if not territory_owners.has(zid) or territory_owners[zid] == "":
			territory_owners[zid] = "bandit"

	# Compute zone difficulty via BFS from haven
	_compute_zone_difficulty()

func _compute_zone_difficulty() -> void:
	## BFS from "haven" to assign distance-based difficulty to every zone.
	_zone_difficulty.clear()
	_zone_difficulty["haven"] = 0
	var frontier: Array = ["haven"]
	while not frontier.is_empty():
		var next_frontier: Array = []
		for zid in frontier:
			var d: int = _zone_difficulty[zid]
			for nb in _zone_connections.get(zid, []):
				if not _zone_difficulty.has(nb):
					_zone_difficulty[nb] = d + 1
					next_frontier.append(nb)
		frontier = next_frontier

func get_zone_difficulty(zone_id: String) -> int:
	return _zone_difficulty.get(zone_id, 6)

func build_bandit_army(zone_id: String) -> Array:
	## Generate bandit army scaled by zone difficulty (distance from haven).
	var dist: int = get_zone_difficulty(zone_id)
	var army: Array = []
	if dist <= 2:
		# Easy: 30-50 units, tier 1
		var total := randi_range(30, 50)
		army.append({"type": BattleUnitSystem.UnitType.INFANTRY, "count": int(total * 0.70), "formation": BattleUnitSystem.FormationType.LINE})
		army.append({"type": BattleUnitSystem.UnitType.ARCHER, "count": int(total * 0.20), "formation": BattleUnitSystem.FormationType.LOOSE_LINE})
		army.append({"type": BattleUnitSystem.UnitType.SPEAR, "count": maxi(1, total - int(total * 0.70) - int(total * 0.20)), "formation": BattleUnitSystem.FormationType.LINE})
	elif dist <= 5:
		# Medium: 50-80 units, tier 2
		var total := randi_range(50, 80)
		army.append({"type": BattleUnitSystem.UnitType.INFANTRY, "count": int(total * 0.40), "formation": BattleUnitSystem.FormationType.LINE})
		army.append({"type": BattleUnitSystem.UnitType.ARCHER, "count": int(total * 0.20), "formation": BattleUnitSystem.FormationType.LOOSE_LINE})
		army.append({"type": BattleUnitSystem.UnitType.CAVALRY, "count": int(total * 0.15), "formation": BattleUnitSystem.FormationType.WEDGE})
		army.append({"type": BattleUnitSystem.UnitType.SPEAR, "count": int(total * 0.15), "formation": BattleUnitSystem.FormationType.LINE})
		army.append({"type": BattleUnitSystem.UnitType.MAGE, "count": maxi(1, total - int(total * 0.40) - int(total * 0.20) - int(total * 0.15) - int(total * 0.15)), "formation": BattleUnitSystem.FormationType.LOOSE_LINE})
	else:
		# Hard: 80-120 units, tier 3
		var total := randi_range(80, 120)
		army.append({"type": BattleUnitSystem.UnitType.INFANTRY, "count": int(total * 0.30), "formation": BattleUnitSystem.FormationType.LINE})
		army.append({"type": BattleUnitSystem.UnitType.ARCHER, "count": int(total * 0.15), "formation": BattleUnitSystem.FormationType.LOOSE_LINE})
		army.append({"type": BattleUnitSystem.UnitType.CAVALRY, "count": int(total * 0.15), "formation": BattleUnitSystem.FormationType.WEDGE})
		army.append({"type": BattleUnitSystem.UnitType.HEAVY_INFANTRY, "count": int(total * 0.10), "formation": BattleUnitSystem.FormationType.SHIELD_WALL})
		army.append({"type": BattleUnitSystem.UnitType.HEAVY_CAVALRY, "count": int(total * 0.10), "formation": BattleUnitSystem.FormationType.WEDGE})
		army.append({"type": BattleUnitSystem.UnitType.MAGE, "count": int(total * 0.10), "formation": BattleUnitSystem.FormationType.LOOSE_LINE})
		army.append({"type": BattleUnitSystem.UnitType.SPEAR, "count": maxi(1, total - int(total * 0.30) - int(total * 0.15) - int(total * 0.15) - int(total * 0.10) - int(total * 0.10) - int(total * 0.10)), "formation": BattleUnitSystem.FormationType.LINE})
	return army

func _process(delta: float) -> void:
	_attack_timer += delta
	if _attack_timer >= ATTACK_CHECK_INTERVAL:
		_attack_timer = 0.0
		_check_enemy_attacks()
	_ai_sim_timer += delta
	if _ai_sim_timer >= AI_SIM_INTERVAL:
		_ai_sim_timer = 0.0
		_simulate_ai_wars()

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
	if owner_id == "bandit":
		return "Bandit Territory"
	if owner_id == "":
		return "Neutral"
	if factions.has(owner_id):
		return factions[owner_id]["name"]
	return owner_id

func get_owner_color(owner_id: String) -> Color:
	if owner_id == "player":
		return Color(0.3, 0.8, 0.3)
	if owner_id == "bandit":
		return Color(0.65, 0.5, 0.3)  # brown/tan
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
	## Enemy and bandit zones adjacent to player zones.
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
# survival_ratio = surviving_units / starting_units (0.0 to 1.0)
# Pyrrhic threshold: if winner survives with < 20% troops, land goes neutral instead.

func on_battle_won(zone_id: String, survival_ratio: float = 1.0) -> void:
	## Player won attacking zone_id. survival_ratio = fraction of player army surviving.
	var old_owner := get_zone_owner(zone_id)
	var pyrrhic := survival_ratio < 0.20

	if pyrrhic:
		# Pyrrhic victory — land becomes neutral, nobody gains it
		territory_owners[zone_id] = ""
		territory_changed.emit(zone_id, "")
		print("FactionManager: Pyrrhic victory at %s (%.0f%% survived) — zone neutral" % [zone_id, survival_ratio * 100])
	else:
		# Decisive win — player takes territory
		territory_owners[zone_id] = "player"
		territory_changed.emit(zone_id, "player")
		print("FactionManager: Player conquered %s (%.0f%% survived)" % [zone_id, survival_ratio * 100])

	# Lower attitude with defeated faction
	if old_owner != "" and old_owner != "player" and factions.has(old_owner):
		var att_drop := 20 if not pyrrhic else 10
		factions[old_owner]["attitude"] = maxi(-100, factions[old_owner]["attitude"] - att_drop)
		faction_attitude_changed.emit(old_owner, factions[old_owner]["attitude"])
		# Reduce defeated faction's army_size (they lost troops)
		var loss := int(factions[old_owner]["army_size"] * 0.15)
		factions[old_owner]["army_size"] = maxi(10, factions[old_owner]["army_size"] - loss)

func on_battle_lost(zone_id: String, enemy_survival_ratio: float = 1.0) -> void:
	## Player lost defending/attacking zone_id. enemy_survival_ratio = fraction of enemy surviving.
	var pyrrhic := enemy_survival_ratio < 0.20

	if pyrrhic:
		# Enemy won but barely — zone becomes neutral
		territory_owners[zone_id] = ""
		territory_changed.emit(zone_id, "")
		print("FactionManager: Player lost %s but enemy pyrrhic (%.0f%% enemy survived) — zone neutral" % [zone_id, enemy_survival_ratio * 100])
	else:
		# Decisive enemy win — find adjacent faction to claim it
		var claiming_fac := ""
		for neighbor in get_zone_neighbors(zone_id):
			var n_owner := get_zone_owner(neighbor)
			if n_owner != "player" and n_owner != "" and factions.has(n_owner):
				claiming_fac = n_owner
				break
		if claiming_fac != "":
			territory_owners[zone_id] = claiming_fac
			territory_changed.emit(zone_id, claiming_fac)
			print("FactionManager: %s took %s after player defeat" % [claiming_fac, zone_id])
		else:
			territory_owners[zone_id] = ""
			territory_changed.emit(zone_id, "")

# --- AI Faction Simulation ---

func _get_faction_strength(fac_id: String) -> float:
	## Compute faction power from territory count, army size, and tier.
	if not factions.has(fac_id):
		return 0.0
	var zone_count := 0
	for zid in territory_owners:
		if territory_owners[zid] == fac_id:
			zone_count += 1
	var army: int = factions[fac_id].get("army_size", 40)
	var tier: int = factions[fac_id].get("tier", 1)
	return float(zone_count * 10 + army) * (0.8 + tier * 0.2)

func _simulate_ai_wars() -> void:
	## Each tick, one random faction pair on a border may fight.
	## Resolved by comparing strength + randomness. No full battle needed.

	# Find all faction borders (pairs of different factions with adjacent zones)
	var border_pairs: Array = []  # [{attacker: fac_id, defender: fac_id, zone: zone_id}]
	for zid in territory_owners:
		var owner: String = territory_owners[zid]
		if owner == "" or owner == "player" or owner == "bandit":
			continue
		for nb in _zone_connections.get(zid, []):
			var nb_owner: String = territory_owners.get(nb, "")
			if nb_owner == "" or nb_owner == "player" or nb_owner == owner or nb_owner == "bandit":
				continue
			border_pairs.append({"attacker": owner, "defender": nb_owner, "zone": nb})

	if border_pairs.is_empty():
		return

	# Pick one random border conflict
	var conflict: Dictionary = border_pairs[randi() % border_pairs.size()]
	var atk: String = conflict["attacker"]
	var dfn: String = conflict["defender"]
	var zone: String = conflict["zone"]

	# 50% chance a border conflict actually fires each tick
	if randf() > 0.5:
		return

	var atk_str := _get_faction_strength(atk)
	var dfn_str := _get_faction_strength(dfn)

	# Add randomness (±30%)
	atk_str *= randf_range(0.7, 1.3)
	dfn_str *= randf_range(0.7, 1.3)

	var ratio := atk_str / maxf(dfn_str, 1.0)
	var winner := ""
	var loser := ""

	if ratio > 1.15:
		# Attacker wins
		winner = atk
		loser = dfn
	elif ratio < 0.85:
		# Defender wins — attacker loses one of their border zones instead
		winner = dfn
		loser = atk
		# Find an attacker zone adjacent to defender territory
		for nb in _zone_connections.get(zone, []):
			if territory_owners.get(nb, "") == atk:
				zone = nb
				break
	else:
		# Stalemate — both lose troops, no territory change
		if factions.has(atk):
			factions[atk]["army_size"] = maxi(10, factions[atk]["army_size"] - randi_range(3, 8))
		if factions.has(dfn):
			factions[dfn]["army_size"] = maxi(10, factions[dfn]["army_size"] - randi_range(3, 8))
		return

	# Check for pyrrhic (close fight)
	var pyrrhic := absf(ratio - 1.0) < 0.25

	if pyrrhic:
		territory_owners[zone] = ""
		territory_changed.emit(zone, "")
	else:
		territory_owners[zone] = winner
		territory_changed.emit(zone, winner)

	# Loser shrinks army
	if factions.has(loser):
		var loss := randi_range(5, 15)
		factions[loser]["army_size"] = maxi(10, factions[loser]["army_size"] - loss)
	# Winner loses some troops too
	if factions.has(winner):
		var loss := randi_range(2, 8)
		factions[winner]["army_size"] = maxi(10, factions[winner]["army_size"] - loss)

	# Armies slowly recover over time (growth per tick)
	for fac_id in factions:
		var zone_count := 0
		for zid in territory_owners:
			if territory_owners[zid] == fac_id:
				zone_count += 1
		# More territory = faster recovery
		var recovery := maxi(1, zone_count / 2)
		var max_army: int = 50 + zone_count * 15 + int(factions[fac_id].get("tier", 1)) * 20
		factions[fac_id]["army_size"] = mini(max_army, factions[fac_id]["army_size"] + recovery)

	ai_battle_resolved.emit(zone, atk, dfn, winner if not pyrrhic else "")
	print("FactionManager AI: %s vs %s at %s → %s%s" % [
		factions[atk]["name"] if factions.has(atk) else atk,
		factions[dfn]["name"] if factions.has(dfn) else dfn,
		zone,
		factions[winner]["name"] if factions.has(winner) else "draw",
		" (pyrrhic→neutral)" if pyrrhic else ""
	])

	# Passive troop token income: +1 per owned zone per AI sim tick
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.save_data:
		var player_zone_count := get_player_zones().size()
		if player_zone_count > 0:
			gm.save_data.troop_tokens += player_zone_count
			print("FactionManager: Passive income +%d troop tokens (total: %d)" % [player_zone_count, gm.save_data.troop_tokens])

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
	## Generate an attack army from faction army_size and tier.
	return build_faction_army(faction_id)

func build_faction_army(faction_id: String) -> Array:
	## Build army composition based on faction's tier and army_size.
	if not factions.has(faction_id):
		return [{"type": BattleUnitSystem.UnitType.INFANTRY, "count": 30, "formation": BattleUnitSystem.FormationType.LINE}]
	var total: int = factions[faction_id].get("army_size", 50)
	var tier: int = factions[faction_id].get("tier", 1)
	var army: Array = []
	if tier == 1:
		# Weak: mostly infantry + some archers
		army.append({"type": BattleUnitSystem.UnitType.INFANTRY, "count": int(total * 0.70), "formation": BattleUnitSystem.FormationType.LINE})
		army.append({"type": BattleUnitSystem.UnitType.ARCHER, "count": int(total * 0.20), "formation": BattleUnitSystem.FormationType.LOOSE_LINE})
		army.append({"type": BattleUnitSystem.UnitType.HEAVY_INFANTRY, "count": maxi(1, total - int(total * 0.70) - int(total * 0.20)), "formation": BattleUnitSystem.FormationType.SHIELD_WALL})
	elif tier == 2:
		# Mid: balanced with cavalry
		army.append({"type": BattleUnitSystem.UnitType.INFANTRY, "count": int(total * 0.40), "formation": BattleUnitSystem.FormationType.LINE})
		army.append({"type": BattleUnitSystem.UnitType.ARCHER, "count": int(total * 0.25), "formation": BattleUnitSystem.FormationType.LOOSE_LINE})
		army.append({"type": BattleUnitSystem.UnitType.CAVALRY, "count": int(total * 0.15), "formation": BattleUnitSystem.FormationType.WEDGE})
		army.append({"type": BattleUnitSystem.UnitType.HEAVY_INFANTRY, "count": int(total * 0.10), "formation": BattleUnitSystem.FormationType.SHIELD_WALL})
		army.append({"type": BattleUnitSystem.UnitType.MAGE, "count": maxi(1, total - int(total * 0.40) - int(total * 0.25) - int(total * 0.15) - int(total * 0.10)), "formation": BattleUnitSystem.FormationType.LOOSE_LINE})
	else:
		# Strong (tier 3): full mix with heavy units and mages
		army.append({"type": BattleUnitSystem.UnitType.INFANTRY, "count": int(total * 0.30), "formation": BattleUnitSystem.FormationType.LINE})
		army.append({"type": BattleUnitSystem.UnitType.ARCHER, "count": int(total * 0.20), "formation": BattleUnitSystem.FormationType.LOOSE_LINE})
		army.append({"type": BattleUnitSystem.UnitType.CAVALRY, "count": int(total * 0.15), "formation": BattleUnitSystem.FormationType.WEDGE})
		army.append({"type": BattleUnitSystem.UnitType.HEAVY_INFANTRY, "count": int(total * 0.15), "formation": BattleUnitSystem.FormationType.SHIELD_WALL})
		army.append({"type": BattleUnitSystem.UnitType.HEAVY_CAVALRY, "count": int(total * 0.10), "formation": BattleUnitSystem.FormationType.WEDGE})
		army.append({"type": BattleUnitSystem.UnitType.MAGE, "count": maxi(1, total - int(total * 0.30) - int(total * 0.20) - int(total * 0.15) - int(total * 0.15) - int(total * 0.10)), "formation": BattleUnitSystem.FormationType.LOOSE_LINE})
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
		# Recompute zone difficulty (not persisted)
		_compute_zone_difficulty()
	else:
		_init_factions()

# --- Auto-resolve for undefended attacks ---

func auto_resolve_attack(zone_id: String, attacker_faction: String, garrison_strength: int) -> bool:
	## Returns true if defense succeeds. Garrison strength = total garrison unit count.
	var army_size: int = factions[attacker_faction].get("army_size", 60) if factions.has(attacker_faction) else 60
	if garrison_strength > int(army_size * 0.7):
		# Defense succeeds
		var enemy_survival := 1.0 - float(garrison_strength) / float(army_size)
		if enemy_survival < 0.20:
			# Pyrrhic for attacker — they lose troops but don't gain territory
			if factions.has(attacker_faction):
				factions[attacker_faction]["army_size"] = maxi(10, factions[attacker_faction]["army_size"] - int(army_size * 0.3))
		print("FactionManager: Garrison defended %s (strength %d vs army_size %d)" % [zone_id, garrison_strength, army_size])
		return true
	else:
		# Territory lost
		territory_owners[zone_id] = attacker_faction
		territory_changed.emit(zone_id, attacker_faction)
		if factions.has(attacker_faction):
			factions[attacker_faction]["army_size"] = maxi(10, factions[attacker_faction]["army_size"] - int(army_size * 0.1))
		print("FactionManager: %s lost to %s (garrison %d < army_size %d)" % [zone_id, attacker_faction, garrison_strength, army_size])
		return false
