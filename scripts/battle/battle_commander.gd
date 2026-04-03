class_name BattleCommander
extends RefCounted

enum CommandType { MOVE, ATTACK, HOLD, CHARGE, RETREAT, FOLLOW, SCATTER, DEFENSIVE }

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
