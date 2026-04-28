class_name BattleCommander
extends RefCounted

enum CommandType { MOVE, ATTACK, HOLD, CHARGE, RETREAT, FOLLOW, SCATTER, DEFENSIVE, FIGHTING_WITHDRAWAL }

## Tactical roles assigned by AI doctrine plays
enum TacticalRole {
	NONE,
	VANGUARD,     ## Front-line attacker
	ANVIL,        ## Holds enemy in place
	HAMMER,       ## Flanks while anvil engages
	BAIT,         ## Engages briefly then retreats to lure enemy out of position
	FLANKER,      ## Attacks enemy side/rear while bait holds front
	SCREEN,       ## Protects ranged units from melee
	SKIRMISHER,   ## Harasses from range, avoids melee
	RESERVE,      ## Held back for opportunity strikes
}

var _groups: Dictionary = {}  # id -> BattleGroup
var _next_id: int = 0

## Cavalry charge lifecycle states
enum ChargeState { IDLE, CHARGING, IN_MELEE, WITHDRAWING }

class BattleGroup:
	var id: int
	var name: String
	var faction: int
	var unit_type: int  # BattleUnitSystem.UnitType or -1 for mixed
	var command: int = CommandType.ATTACK
	var target_group_id: int = -1
	var formation_type: int = BattleUnitSystem.FormationType.LINE
	var target_x: float = 0.0
	var target_y: float = 0.0
	var permanent: bool = false  # Type groups are permanent, can't be disbanded
	# Cavalry charge lifecycle
	var charge_state: int = ChargeState.IDLE
	var charge_timer: float = 0.0
	# Track initial size for casualty calculations
	var initial_size: int = 0
	# Withdraw position (where cavalry retreats to after charge)
	var withdraw_pos: Vector2 = Vector2.ZERO
	## Playbook system
	var tactical_role: int = TacticalRole.NONE
	var parent_group_id: int = -1  # For detachments: parent group ID
	var rally_point: Vector2 = Vector2.ZERO  ## Fallback position for withdraw cycles
	var engage_timer: float = 0.0  ## For FIGHTING_WITHDRAWAL cycle tracking
	var engage_phase: int = 0  ## 0 = advancing/engaging, 1 = backing off

func create_group(group_name: String, fac: int, u_type: int = -1, formation: int = BattleUnitSystem.FormationType.LINE, is_permanent: bool = false) -> BattleGroup:
	var g := BattleGroup.new()
	g.id = _next_id
	g.name = group_name
	g.faction = fac
	g.unit_type = u_type
	g.formation_type = formation
	g.permanent = is_permanent
	_next_id += 1
	_groups[g.id] = g
	return g

func get_group(id: int) -> BattleGroup:
	return _groups.get(id)

func remove_group(id: int) -> void:
	_groups.erase(id)

func get_faction_groups(fac: int) -> Array:
	var result := []
	for g in _groups.values():
		if g.faction == fac:
			result.append(g)
	return result

func get_all_groups() -> Array:
	return _groups.values()

func set_command(group_id: int, cmd: int, target_gid: int = -1) -> void:
	var g := get_group(group_id)
	if g:
		g.command = cmd
		g.target_group_id = target_gid

func get_permanent_group_for_type(fac: int, u_type: int) -> BattleGroup:
	## Find the permanent group matching this faction + unit type.
	for g in _groups.values():
		if g.faction == fac and g.unit_type == u_type and g.permanent:
			return g
	return null

func is_group_alive(group_id: int, units: BattleUnitSystem) -> bool:
	return units.get_group_alive_count(group_id) > 0

func split_group(original_id: int, fraction: float, new_name: String, units: BattleUnitSystem) -> BattleGroup:
	## Split a fraction (0.0-1.0) of a group's units into a new detachment.
	## Returns the new detachment group, or null if split failed.
	## The new group inherits faction/unit_type/formation from the parent.
	var parent := get_group(original_id)
	if not parent:
		return null
	# Collect alive units in parent group
	var parent_units: Array[int] = []
	for i in range(units.count):
		if units.alive[i] == 1 and units.group_id[i] == original_id:
			parent_units.append(i)
	var total := parent_units.size()
	if total < 4:  # Need at least 4 to split meaningfully
		return null
	var to_move: int = int(float(total) * clampf(fraction, 0.1, 0.9))
	if to_move < 2:
		return null
	# Create detachment group
	var detach := create_group(new_name, parent.faction, parent.unit_type, parent.formation_type)
	detach.parent_group_id = original_id
	detach.target_group_id = parent.target_group_id
	detach.command = parent.command
	# Reassign the first 'to_move' units to the new group
	for k in range(to_move):
		units.group_id[parent_units[k]] = detach.id
	detach.initial_size = to_move
	parent.initial_size = maxi(1, parent.initial_size - to_move)
	return detach

func merge_detachment(detach_id: int, units: BattleUnitSystem) -> void:
	## Merge a detachment back into its parent group. Used when the play is over.
	var detach := get_group(detach_id)
	if not detach or detach.parent_group_id < 0:
		return
	var parent_id := detach.parent_group_id
	for i in range(units.count):
		if units.alive[i] == 1 and units.group_id[i] == detach_id:
			units.group_id[i] = parent_id
	remove_group(detach_id)
