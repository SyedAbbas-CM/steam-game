class_name BattleSimpleAI
extends RefCounted

# AI Difficulty Tiers — determines how smart the enemy is
enum AITier {
	MILITIA = 0,    # Bandits, wildlife — just charges forward, no tactics
	TRAINED = 1,    # Town guards, minor factions — basic formation use, some focus fire
	VETERAN = 2,    # Established factions — reads player formations, uses counters, flanks
	ELITE = 3,      # Powerful factions — full tactical suite, pincer, bait, commander hunting
}

var ai_tier: int = AITier.ELITE  # All AI uses full tactics

var _units: BattleUnitSystem
var _projectiles: BattleProjectileSystem
var _commander: BattleCommander
var _battle_time: float = 0.0
var _retarget_timer: float = 0.0
const RETARGET_INTERVAL := 0.5
const MORALE_ROUT_THRESHOLD := 20.0
const MORALE_RECOVERY_TIMER := 0.1
var _morale_timer: float = 0.0
var _strategy_timer: float = 0.0
const STRATEGY_INTERVAL := 3.0

# Smart AI tactic cooldowns
var _pincer_cooldown: float = 0.0
var _focus_fire_target_group: int = -1

# Battle-level strategy (planned at start, adapted over time)
var _blue_has_cavalry: bool = false
var _blue_has_ranged: bool = false
var _blue_heavy_ratio: float = 0.0   # fraction of heavy units
var _blue_cavalry_ratio: float = 0.0
var _strategy_planned: bool = false

# Objective positions — RED advances toward player area, BLUE holds
var red_objective: Vector2 = Vector2.ZERO
var blue_objective: Vector2 = Vector2.ZERO
var _advance_speed_mult: float = 0.4  # RED advances at 40% speed

# Flow field navigation — precomputed BFS, O(1) per-unit lookup
var _flow: BattleFlowField = null
var _blocked_tiles: Dictionary = {}
var _flow_recompute_timer: float = 0.0
const FLOW_RECOMPUTE_INTERVAL := 5.0  # Recompute flow fields every 5s (objectives may shift)

# Player tracking — enemy units can target the player character
var player_position: Vector2 = Vector2.ZERO
var player_alive: bool = true
const PLAYER_TARGET_ID := -2  # special target_unit value meaning "target the player"
const PLAYER_ENGAGE_RANGE := 500.0  # RED units within this range engage player

# Army-level battle coordination — phase state machine for RED
enum ArmyPhase { STAGING, ADVANCE, APPROACH, ENGAGED, CLEANUP }
var _army_phase: int = ArmyPhase.STAGING
var _phase_timer: float = 0.0
var _battle_line_x: float = 0.0
var _battle_line_y_center: float = 0.0
var _staging_line_x: float = 0.0
var _infantry_speed: float = 1.8
var _melee_engaged_count: int = 0
var _cavalry_charge_triggered: bool = false


func _is_wide_unit(i: int) -> bool:
	var t := _units.unit_type[i]
	return t == BattleUnitSystem.UnitType.CAVALRY or t == BattleUnitSystem.UnitType.HEAVY_CAVALRY or t == BattleUnitSystem.UnitType.HORSE_ARCHER

func initialize(units: BattleUnitSystem, projectiles: BattleProjectileSystem, commander: BattleCommander) -> void:
	_units = units
	_projectiles = projectiles
	_commander = commander
	_assign_initial_targets()
	# Plan strategy immediately so army coordinates from frame 1 (not after 3s delay)
	_plan_battle_strategy()

func setup_flow_fields(blocked_tiles: Dictionary, tile_region: Rect2i) -> void:
	_blocked_tiles = blocked_tiles
	_flow = BattleFlowField.new()
	_flow.setup(blocked_tiles, tile_region)

func compute_initial_flow_fields() -> void:
	## Precompute flow fields for both objectives. Called once at battle init.
	if not _flow:
		return
	if red_objective != Vector2.ZERO:
		_flow.compute_field("red_obj", red_objective)
	if blue_objective != Vector2.ZERO:
		_flow.compute_field("blue_obj", blue_objective)

func _plan_battle_strategy() -> void:
	## Analyze BLUE army composition at battle start and plan RED strategy.
	## Called once after all units spawned.
	if _strategy_planned:
		return
	_strategy_planned = true

	var blue_groups := _commander.get_faction_groups(BattleUnitSystem.Faction.BLUE)
	var red_groups := _commander.get_faction_groups(BattleUnitSystem.Faction.RED)

	# Analyze BLUE composition
	var blue_total := 0
	var blue_cav := 0
	var blue_ranged := 0
	var blue_heavy := 0
	for bg in blue_groups:
		var c := _units.get_group_alive_count(bg.id)
		blue_total += c
		match bg.unit_type:
			BattleUnitSystem.UnitType.CAVALRY, BattleUnitSystem.UnitType.HEAVY_CAVALRY:
				blue_cav += c
			BattleUnitSystem.UnitType.ARCHER, BattleUnitSystem.UnitType.MAGE:
				blue_ranged += c
			BattleUnitSystem.UnitType.HEAVY_INFANTRY:
				blue_heavy += c

	if blue_total > 0:
		_blue_cavalry_ratio = float(blue_cav) / float(blue_total)
		_blue_heavy_ratio = float(blue_heavy) / float(blue_total)
	_blue_has_cavalry = blue_cav >= 3
	_blue_has_ranged = blue_ranged >= 3

	# Read BLUE formations
	var blue_formations: Dictionary = {}  # FormationType -> count
	for bg in blue_groups:
		var f: int = bg.formation_type
		blue_formations[f] = blue_formations.get(f, 0) + _units.get_group_alive_count(bg.id)

	# Plan RED initial strategy based on AI tier and BLUE composition
	if ai_tier >= AITier.VETERAN:
		# Veteran+ AI: counter-pick formations at battle start
		for rg in red_groups:
			if _units.get_group_alive_count(rg.id) == 0:
				continue
			# Find the largest BLUE formation and counter it
			var biggest_blue_form := BattleUnitSystem.FormationType.LINE
			var biggest_count := 0
			for f in blue_formations:
				if blue_formations[f] > biggest_count:
					biggest_count = blue_formations[f]
					biggest_blue_form = f
			# Set counter-formation for melee groups
			if rg.unit_type == BattleUnitSystem.UnitType.INFANTRY or rg.unit_type == BattleUnitSystem.UnitType.HEAVY_INFANTRY:
				rg.formation_type = _get_best_counter_formation(biggest_blue_form)

		# If BLUE has lots of cavalry, RED heavy infantry should brace
		if _blue_cavalry_ratio > 0.25:
			for rg in red_groups:
				if rg.unit_type == BattleUnitSystem.UnitType.HEAVY_INFANTRY:
					rg.command = BattleCommander.CommandType.DEFENSIVE
					rg.formation_type = BattleUnitSystem.FormationType.SHIELD_WALL

	# (Army phase system handles ranged hold + cavalry timing, replacing old ELITE hold logic)

	# Initialize army coordination phase
	_army_phase = ArmyPhase.STAGING
	_phase_timer = 0.0
	_cavalry_charge_triggered = false

	# Compute infantry speed from slowest melee type in RED army
	var has_melee := false
	var slowest_melee_speed := 999.0
	for rg in red_groups:
		if _units.get_group_alive_count(rg.id) == 0:
			continue
		match rg.unit_type:
			BattleUnitSystem.UnitType.INFANTRY, BattleUnitSystem.UnitType.HEAVY_INFANTRY, BattleUnitSystem.UnitType.SPEAR:
				has_melee = true
				# Sample first alive unit in group to get max_speed
				for i in _units.count:
					if _units.group_id[i] == rg.id and _units.alive[i] == 1:
						if _units.max_speed[i] < slowest_melee_speed:
							slowest_melee_speed = _units.max_speed[i]
						break
	if has_melee:
		_infantry_speed = slowest_melee_speed
	else:
		# No melee — skip straight to ENGAGED
		_army_phase = ArmyPhase.ENGAGED

	# Compute initial battle line from RED spawn positions
	var red_sum_x := 0.0
	var red_sum_y := 0.0
	var red_count := 0
	var red_min_x := 99999.0
	for rg in red_groups:
		var gc := _units.get_group_center(rg.id)
		if gc != Vector2.ZERO:
			red_sum_x += gc.x
			red_sum_y += gc.y
			red_count += 1
			if gc.x < red_min_x:
				red_min_x = gc.x
	if red_count > 0:
		_staging_line_x = red_min_x
		_battle_line_x = _staging_line_x
		_battle_line_y_center = red_sum_y / float(red_count)

	# Assign formation positions immediately so units form up from frame 1
	# Use ATTACK (not MOVE) so units fight back while forming up
	if _army_phase == ArmyPhase.STAGING and ai_tier >= AITier.TRAINED:
		_compute_battle_line_positions(_staging_line_x, red_groups, true)

	print("AI Strategy planned (tier=%d): BLUE has cav=%d%% heavy=%d%% ranged=%s, army_phase=%d" % [
		ai_tier, int(_blue_cavalry_ratio * 100), int(_blue_heavy_ratio * 100), _blue_has_ranged, _army_phase])

func _assign_initial_targets() -> void:
	for fac in [BattleUnitSystem.Faction.BLUE, BattleUnitSystem.Faction.RED]:
		var enemy_fac := BattleUnitSystem.Faction.RED if fac == BattleUnitSystem.Faction.BLUE else BattleUnitSystem.Faction.BLUE
		var my_groups := _commander.get_faction_groups(fac)
		var enemy_groups := _commander.get_faction_groups(enemy_fac)
		if enemy_groups.is_empty():
			continue
		for g in my_groups:
			g.initial_size = _get_group_total_count(g)
			var best_target := _find_priority_target(g.unit_type, enemy_groups)
			if best_target:
				g.target_group_id = best_target.id
			# ALL groups start with ATTACK — advance toward enemy
			# Tactical AI (_reassess_strategy) adjusts once contact is made
			g.command = BattleCommander.CommandType.ATTACK
			match g.unit_type:
				BattleUnitSystem.UnitType.CAVALRY, BattleUnitSystem.UnitType.HEAVY_CAVALRY:
					g.charge_state = BattleCommander.ChargeState.IDLE
					g.formation_type = BattleUnitSystem.FormationType.WEDGE
				BattleUnitSystem.UnitType.HORSE_ARCHER:
					g.charge_state = BattleCommander.ChargeState.IDLE
					g.formation_type = BattleUnitSystem.FormationType.LOOSE_LINE
				BattleUnitSystem.UnitType.HEAVY_INFANTRY:
					g.formation_type = BattleUnitSystem.FormationType.BLOCK
				BattleUnitSystem.UnitType.ARCHER, BattleUnitSystem.UnitType.MAGE, BattleUnitSystem.UnitType.RANGED_INFANTRY:
					g.formation_type = BattleUnitSystem.FormationType.LOOSE_LINE
				BattleUnitSystem.UnitType.SPEAR:
					g.formation_type = BattleUnitSystem.FormationType.LINE
				_:
					g.formation_type = BattleUnitSystem.FormationType.LINE

func _find_priority_target(my_type: int, enemy_groups: Array) -> BattleCommander.BattleGroup:
	# Preferred targets based on counter relationships
	var preferred_list: Array[int] = []
	match my_type:
		BattleUnitSystem.UnitType.CAVALRY, BattleUnitSystem.UnitType.HEAVY_CAVALRY:
			preferred_list = [BattleUnitSystem.UnitType.ARCHER, BattleUnitSystem.UnitType.MAGE, BattleUnitSystem.UnitType.RANGED_INFANTRY]
		BattleUnitSystem.UnitType.ARCHER:
			preferred_list = [BattleUnitSystem.UnitType.INFANTRY, BattleUnitSystem.UnitType.HEAVY_INFANTRY, BattleUnitSystem.UnitType.SPEAR]
		BattleUnitSystem.UnitType.HEAVY_INFANTRY:
			preferred_list = [BattleUnitSystem.UnitType.CAVALRY, BattleUnitSystem.UnitType.HEAVY_CAVALRY, BattleUnitSystem.UnitType.HORSE_ARCHER]
		BattleUnitSystem.UnitType.MAGE:
			preferred_list = [BattleUnitSystem.UnitType.INFANTRY, BattleUnitSystem.UnitType.HEAVY_INFANTRY, BattleUnitSystem.UnitType.SPEAR]
		BattleUnitSystem.UnitType.SPEAR:
			preferred_list = [BattleUnitSystem.UnitType.CAVALRY, BattleUnitSystem.UnitType.HEAVY_CAVALRY, BattleUnitSystem.UnitType.HORSE_ARCHER]
		BattleUnitSystem.UnitType.HORSE_ARCHER:
			preferred_list = [BattleUnitSystem.UnitType.ARCHER, BattleUnitSystem.UnitType.RANGED_INFANTRY, BattleUnitSystem.UnitType.MAGE]
		BattleUnitSystem.UnitType.RANGED_INFANTRY:
			preferred_list = [BattleUnitSystem.UnitType.INFANTRY, BattleUnitSystem.UnitType.SPEAR]
		_:
			preferred_list = [BattleUnitSystem.UnitType.INFANTRY]
	for preferred in preferred_list:
		for g in enemy_groups:
			if g.unit_type == preferred:
				return g
	if not enemy_groups.is_empty():
		return enemy_groups[0]
	return null

func update(dt: float) -> void:
	_battle_time += dt
	_retarget_timer += dt
	_morale_timer += dt

	# Periodically recompute flow fields (objectives may shift)
	_flow_recompute_timer += dt
	if _flow_recompute_timer >= FLOW_RECOMPUTE_INTERVAL:
		_flow_recompute_timer = 0.0
		_recompute_flow_fields()

	# Check for dead commanders and apply debuffs
	_check_commander_deaths()

	# Retarget dead groups periodically
	if _retarget_timer >= RETARGET_INTERVAL:
		_retarget_timer = 0.0
		_retarget_dead_groups()

	# Update formation bonuses every retarget cycle
	if _retarget_timer == 0.0:  # Just fired retarget
		_update_formation_bonuses()

	# Strategic reassessment for RED faction
	_strategy_timer += dt
	if _strategy_timer >= STRATEGY_INTERVAL:
		_strategy_timer = 0.0
		_reassess_strategy()

	# Per-unit AI
	for i in _units.count:
		if _units.alive[i] == 0:
			continue

		# Burn tick
		if _units.burn_time[i] > 0.0:
			_units.hp[i] -= _units.burn_dps[i] * dt
			_units.burn_time[i] -= dt
			if _units.hp[i] <= 0.0:
				_units.alive[i] = 0
				continue

		# Commander debuff timer tick
		if _units.commander_debuff_timer[i] > 0.0:
			_units.commander_debuff_timer[i] -= dt

		# Stagger check
		if _units.stagger_time[i] > 0.0:
			_units.stagger_time[i] -= dt
			continue

		# Scatter check (cavalry fear/panic)
		if _units.scatter_time[i] > 0.0:
			_units.scatter_time[i] -= dt
			var flee_speed: float = _units.max_speed[i] * 1.2
			_units.vx[i] = _units.scatter_dir_x[i] * flee_speed
			_units.vy[i] = _units.scatter_dir_y[i] * flee_speed
			if _units.scatter_time[i] <= 0.0:
				# Recover: restore group
				_units.group_id[i] = _units.saved_group_id[i]
				_units.saved_group_id[i] = -1
			continue  # Can't attack while scattered

		# Morale tier: hesitation (Wavering 15%, Shaken 30%)
		var _morale := _units.morale[i]
		if _morale < 30.0 and _morale >= 15.0:
			# Shaken: 30% chance to hesitate each AI tick
			if randf() < 0.005:  # ~30% per second at 60fps
				_units.stagger_time[i] = 0.3
				continue
		elif _morale < 50.0 and _morale >= 30.0:
			# Wavering: 15% chance to hesitate
			if randf() < 0.0025:  # ~15% per second at 60fps
				_units.stagger_time[i] = 0.3
				continue

		if _units.charge_impact_time[i] > 0.0:
			_units.charge_impact_time[i] -= dt
		if _units.post_charge_bogged_time[i] > 0.0:
			_units.post_charge_bogged_time[i] -= dt

		# Track cavalry charge time for momentum bonus
		var ut := _units.unit_type[i]
		if ut == BattleUnitSystem.UnitType.CAVALRY or ut == BattleUnitSystem.UnitType.HEAVY_CAVALRY or ut == BattleUnitSystem.UnitType.HORSE_ARCHER:
			var spd := sqrt(_units.vx[i] * _units.vx[i] + _units.vy[i] * _units.vy[i])
			if spd > _units.max_speed[i] * 0.5:
				_units.charge_time[i] += dt
			else:
				_units.charge_time[i] = 0.0

		# Ability system
		_update_ability(i, dt)

		# Routing — flee when low HP + low morale + outnumbered
		# High morale units never rout regardless of HP
		var hp_ratio: float = _units.hp[i] / maxf(1.0, BattleUnitSystem.UNIT_STATS["hp"][_units.unit_type[i]])
		if hp_ratio < 0.3 and _units.morale[i] < 40.0:
			var nearby_all := _units.get_nearby(_units.x[i], _units.y[i], 120.0)
			var friends := 0
			var enemies := 0
			for j in nearby_all:
				if _units.alive[j] == 0 or j == i:
					continue
				if _units.faction[j] == _units.faction[i]:
					friends += 1
				else:
					enemies += 1
			if enemies > friends:
				_do_rout(i, dt)
				continue

		var gid := _units.group_id[i]
		var cmd := BattleCommander.CommandType.ATTACK
		if gid >= 0 and _commander:
			var grp = _commander.get_group(gid)
			if grp:
				cmd = grp.command

		# Group cohesion — all units gently drift toward group center to stay together
		# Skip during MOVE — cohesion pulls toward combat blob, fighting the move order
		if gid >= 0 and cmd != BattleCommander.CommandType.SCATTER and cmd != BattleCommander.CommandType.RETREAT and cmd != BattleCommander.CommandType.MOVE:
			_apply_group_cohesion(i, gid, dt)

		match cmd:
			BattleCommander.CommandType.MOVE:
				# Pure MOVE — go to location, do NOT attack
				# Clear combat target so unit disengages
				_units.target_unit[i] = -1
				var grp = _commander.get_group(gid)
				if grp and (grp.target_x != 0.0 or grp.target_y != 0.0):
					var mdx: float = grp.target_x - _units.x[i]
					var mdy: float = grp.target_y - _units.y[i]
					var mdist := sqrt(mdx * mdx + mdy * mdy)
					if mdist > 30.0:
						# Brake perpendicular velocity to help disengage from melee
						var nx := mdx / mdist
						var ny := mdy / mdist
						var dot_v := _units.vx[i] * nx + _units.vy[i] * ny
						var perp_vx := _units.vx[i] - dot_v * nx
						var perp_vy := _units.vy[i] - dot_v * ny
						_units.vx[i] -= perp_vx * 0.3 * dt * 60.0
						_units.vy[i] -= perp_vy * 0.3 * dt * 60.0
						_do_movement_toward_pos(i, Vector2(grp.target_x, grp.target_y), dt, true)
					else:
						# This unit arrived — just brake, don't change group command
						_units.vx[i] *= 0.8
						_units.vy[i] *= 0.8
				else:
					# No destination — just hold position
					_units.vx[i] *= 0.85
					_units.vy[i] *= 0.85
			BattleCommander.CommandType.ATTACK:
				# ATTACK MOVE — go to location AND fight enemies on the way
				var grp = _commander.get_group(gid)
				if grp and (grp.target_x != 0.0 or grp.target_y != 0.0):
					# Has a destination — move there but engage enemies
					var mdx: float = grp.target_x - _units.x[i]
					var mdy: float = grp.target_y - _units.y[i]
					var mdist := sqrt(mdx * mdx + mdy * mdy)
					if mdist < 50.0:
						# This unit arrived — just fight here, don't clear group target
						_do_combat(i, dt)
					else:
						_update_target(i)
						var target_idx := _units.target_unit[i]
						if target_idx >= 0 and target_idx < _units.count and _units.alive[target_idx] == 1:
							var tdx := _units.x[target_idx] - _units.x[i]
							var tdy := _units.y[target_idx] - _units.y[i]
							var tdist := sqrt(tdx * tdx + tdy * tdy)
							if tdist < 300.0:
								_do_movement(i, dt)
								_do_attack(i)
							else:
								_do_movement_toward_pos(i, Vector2(grp.target_x, grp.target_y), dt, true)
								_do_attack(i)
						elif target_idx == PLAYER_TARGET_ID:
							_do_movement_toward_pos(i, player_position, dt, false, false)
							_do_attack_player(i)
						else:
							_do_movement_toward_pos(i, Vector2(grp.target_x, grp.target_y), dt, true)
				else:
					# No destination — normal free combat
					_do_combat(i, dt)
			BattleCommander.CommandType.HOLD:
				# HOLD — stop moving, attack enemies in range only
				_units.vx[i] *= 0.85
				_units.vy[i] *= 0.85
				_update_target(i)
				_do_attack_any(i)
			BattleCommander.CommandType.DEFENSIVE:
				# DEFEND — cluster together, fight nearby enemies
				_do_cluster(i, dt)
				_update_target(i)
				var def_target := _units.target_unit[i]
				if def_target >= 0 and def_target < _units.count and _units.alive[def_target] == 1:
					var ddx := _units.x[def_target] - _units.x[i]
					var ddy := _units.y[def_target] - _units.y[i]
					if sqrt(ddx * ddx + ddy * ddy) < 150.0:
						_do_movement(i, dt)
				_do_attack_any(i)
			BattleCommander.CommandType.SCATTER:
				# SCATTER — spread out, fight individually
				_do_scatter(i, dt)
				_update_target(i)
				_do_combat(i, dt)
			BattleCommander.CommandType.FOLLOW:
				# FOLLOW — follow player, attack nearby threats
				_do_follow_player(i, dt)
			BattleCommander.CommandType.CHARGE:
				# CHARGE — rush toward target at max speed, attack on contact
				var grp = _commander.get_group(gid)
				if grp and (grp.target_x != 0.0 or grp.target_y != 0.0):
					_do_movement_toward_pos(i, Vector2(grp.target_x, grp.target_y), dt, true, true)
					# Boost speed for charge
					var charge_spd: float = _units.max_speed[i] * 1.5
					var cur := sqrt(_units.vx[i] * _units.vx[i] + _units.vy[i] * _units.vy[i])
					if cur > 0.01 and cur < charge_spd:
						var s := charge_spd / cur
						_units.vx[i] *= s
						_units.vy[i] *= s
					_update_target(i)
					_do_attack_any(i)
				else:
					_do_combat(i, dt)
			BattleCommander.CommandType.RETREAT:
				# RETREAT — move away from nearest enemy, reduced combat
				var grp = _commander.get_group(gid)
				if grp and (grp.target_x != 0.0 or grp.target_y != 0.0):
					_do_movement_toward_pos(i, Vector2(grp.target_x, grp.target_y), dt, true, true)
				else:
					_do_rout_retreat(i, dt)
				# Only fight if enemy is very close
				_update_target(i)
				var target_idx := _units.target_unit[i]
				if target_idx >= 0 and target_idx < _units.count and _units.alive[target_idx] == 1:
					var rdx := _units.x[target_idx] - _units.x[i]
					var rdy := _units.y[target_idx] - _units.y[i]
					if sqrt(rdx * rdx + rdy * rdy) < 60.0:
						_do_attack(i)
			_:
				_do_combat(i, dt)

	# Morale recovery — units recover morale when not in immediate danger
	# Bonus recovery near the player character and commanders
	if _morale_timer >= MORALE_RECOVERY_TIMER:
		_morale_timer = 0.0
		for mi in _units.count:
			if _units.alive[mi] == 0:
				continue
			var recovery := 0.5
			var nearest := _units.find_nearest_enemy(mi, 200.0)
			if nearest < 0:
				recovery = 2.0
			elif _units.neighbor_count[mi] > 3:
				recovery = 1.0
			# Player proximity buff — BLUE units near the player get extra morale
			if player_alive and _units.faction[mi] == BattleUnitSystem.Faction.BLUE:
				var pdx := player_position.x - _units.x[mi]
				var pdy := player_position.y - _units.y[mi]
				var pdist := sqrt(pdx * pdx + pdy * pdy)
				if pdist < 150.0:
					recovery += 3.0
				elif pdist < 300.0:
					recovery += 1.5
			# Commander aura: +2 morale/sec to allies within 150px
			if _units.is_commander[mi] == 0:
				var nearby_cmdr := _units.get_nearby(_units.x[mi], _units.y[mi], 150.0)
				for ci in nearby_cmdr:
					if ci != mi and _units.alive[ci] == 1 and _units.faction[ci] == _units.faction[mi] and _units.is_commander[ci] == 1:
						recovery += 2.0
						break
			# Elite veteran aura: +1 morale/sec
			if _units.veteran_rank[mi] < 3:
				var nearby_elite := _units.get_nearby(_units.x[mi], _units.y[mi], 100.0)
				for ei in nearby_elite:
					if ei != mi and _units.alive[ei] == 1 and _units.faction[ei] == _units.faction[mi] and _units.veteran_rank[ei] >= 3:
						recovery += 1.0
						break
			_units.morale[mi] = minf(100.0, _units.morale[mi] + recovery)

# --- Ability System ---

const ABILITY_COOLDOWNS := [6.0, 8.0, 12.0, 15.0, 10.0, 12.0, 10.0, 8.0, 12.0]  # per unit type
#                           INF  H.INF CAV  H.CAV ARCH  MAGE  SPEAR H.ARC R.INF
const ABILITY_DURATIONS := [5.0, 4.0, 2.0, 1.5, 0.0, 0.0, 6.0, 4.0, 8.0]  # 0 = instant

func _update_ability(i: int, dt: float) -> void:
	# Tick cooldowns and durations
	_units.ability_cooldown[i] = maxf(0.0, _units.ability_cooldown[i] - dt)
	if _units.ability_timer[i] > 0.0:
		_units.ability_timer[i] -= dt
		if _units.ability_timer[i] <= 0.0:
			_units.ability_active[i] = 0
			_deactivate_ability(i)

	if _units.ability_cooldown[i] > 0.0:
		return

	var t := _units.unit_type[i]
	var target := _units.target_unit[i]
	var target_dist := 99999.0
	if target >= 0 and target < _units.count and _units.alive[target] == 1:
		var dx := _units.x[target] - _units.x[i]
		var dy := _units.y[target] - _units.y[i]
		target_dist = sqrt(dx * dx + dy * dy)

	match t:
		BattleUnitSystem.UnitType.INFANTRY:
			# Shield Wall: 2+ neighbors and enemy within 150px (scales with neighbor count)
			if _units.neighbor_count[i] >= 2 and target_dist < 150.0:
				_activate_ability(i, t)
		BattleUnitSystem.UnitType.HEAVY_INFANTRY:
			# Brace: enemy within 120px OR cavalry charging nearby
			if target_dist < 120.0 or _is_cavalry_charging_nearby(i, 150.0):
				_activate_ability(i, t)
		BattleUnitSystem.UnitType.CAVALRY:
			# Lance Charge: target 80-300px away with clear run
			if target_dist > 80.0 and target_dist < 300.0:
				_activate_ability(i, t)
		BattleUnitSystem.UnitType.HEAVY_CAVALRY:
			# Trample: close to enemy and moving fast
			var spd := sqrt(_units.vx[i] * _units.vx[i] + _units.vy[i] * _units.vy[i])
			if target_dist < 60.0 and spd > _units.max_speed[i] * 0.6:
				_activate_ability(i, t)
		BattleUnitSystem.UnitType.ARCHER:
			# Volley: target in preferred range
			var pref: float = BattleUnitSystem.UNIT_STATS["preferred_range"][t]
			if target_dist < pref * 1.1 and target_dist > 80.0:
				_activate_ability(i, t)
				_fire_volley(i)
		BattleUnitSystem.UnitType.MAGE:
			# Fireball: 2+ enemies clustered within 50px of each other
			if target >= 0 and target < _units.count and _units.alive[target] == 1:
				var cluster := _units.get_nearby(_units.x[target], _units.y[target], 50.0)
				var enemy_count := 0
				for j in cluster:
					if _units.alive[j] == 1 and _units.faction[j] != _units.faction[i]:
						enemy_count += 1
				if enemy_count >= 2:
					_activate_ability(i, t)
					_fire_fireball(i, target)
		BattleUnitSystem.UnitType.SPEAR:
			# Spear Brace: cavalry charging nearby (or enemy cavalry within 180px)
			if _is_cavalry_charging_nearby(i, 180.0) or (target_dist < 120.0 and _is_target_cavalry(i)):
				_activate_ability(i, t)
		BattleUnitSystem.UnitType.HORSE_ARCHER:
			# Parthian Shot: enemy too close, retreat + shoot
			if target_dist < 200.0 and target_dist > 40.0:
				_activate_ability(i, t)
		BattleUnitSystem.UnitType.RANGED_INFANTRY:
			# Pavise: deploy shield when under ranged pressure or enemies approaching
			if _units.neighbor_count[i] >= 2 and target_dist < 350.0:
				_activate_ability(i, t)

func _activate_ability(i: int, t: int) -> void:
	_units.ability_cooldown[i] = ABILITY_COOLDOWNS[t]
	_units.ability_timer[i] = ABILITY_DURATIONS[t]
	_units.ability_active[i] = 1
	# Apply stat modifications for duration-based abilities
	match t:
		BattleUnitSystem.UnitType.INFANTRY:
			# Shield Wall: defense scales with nearby infantry (2-8 neighbors → 1.5x-3.0x def)
			var neighbors := mini(_units.neighbor_count[i], 8)
			var wall_mult := 1.5 + float(neighbors - 2) * 0.25  # 1.5x at 2, 3.0x at 8
			_units.current_defense[i] *= wall_mult
			_units.max_speed[i] *= 0.5  # -50% speed (not -60%)
			_units.knockback_resist[i] = minf(1.0, _units.knockback_resist[i] + 0.7)
			_units.stagger_time[i] = 0.0  # Shield wall blocks stagger
		BattleUnitSystem.UnitType.HEAVY_INFANTRY:
			# Brace: massive defense, scales with neighbors (1-5 → 1.8x-2.8x), immobile
			var h_neighbors := mini(_units.neighbor_count[i], 5)
			var brace_mult := 1.8 + float(h_neighbors) * 0.2
			_units.current_defense[i] *= brace_mult
			_units.max_speed[i] = 0.0
		BattleUnitSystem.UnitType.CAVALRY:
			# Lance Charge: +30% speed, charge_bonus applied in attack
			_units.max_speed[i] *= 1.3
		BattleUnitSystem.UnitType.HEAVY_CAVALRY:
			# Trample: charge bonus applied in collision
			pass
		BattleUnitSystem.UnitType.SPEAR:
			# Spear Brace: plant pike, immobile, massive anti-cav defense
			_units.current_defense[i] *= 1.5
			_units.max_speed[i] = 0.0
			_units.knockback_resist[i] = minf(1.0, _units.knockback_resist[i] + 0.4)
		BattleUnitSystem.UnitType.HORSE_ARCHER:
			# Parthian Shot: speed boost while kiting
			_units.max_speed[i] *= 1.15
		BattleUnitSystem.UnitType.RANGED_INFANTRY:
			# Pavise: deploy shield, immobile, massive defense
			_units.current_defense[i] *= 2.0
			_units.max_speed[i] = 0.0

func _deactivate_ability(i: int) -> void:
	# Restore base stats from type
	var t := _units.unit_type[i]
	_units.max_speed[i] = BattleUnitSystem.UNIT_STATS["max_speed"][t]
	_units.knockback_resist[i] = BattleUnitSystem.UNIT_STATS["knockback_resist"][t]
	# Defense will be recalculated by update_formation_bonuses next frame

func _is_cavalry_charging_nearby(i: int, search_range: float) -> bool:
	var nearby := _units.get_nearby(_units.x[i], _units.y[i], search_range)
	for j in nearby:
		if _units.alive[j] == 0 or _units.faction[j] == _units.faction[i]:
			continue
		var jt := _units.unit_type[j]
		if jt != BattleUnitSystem.UnitType.CAVALRY and jt != BattleUnitSystem.UnitType.HEAVY_CAVALRY and jt != BattleUnitSystem.UnitType.HORSE_ARCHER:
			continue
		var spd := sqrt(_units.vx[j] * _units.vx[j] + _units.vy[j] * _units.vy[j])
		if spd > _units.max_speed[j] * 0.5:
			return true
	return false

func _is_target_cavalry(i: int) -> bool:
	var target := _units.target_unit[i]
	if target < 0 or target >= _units.count or _units.alive[target] == 0:
		return false
	var tt := _units.unit_type[target]
	return tt == BattleUnitSystem.UnitType.CAVALRY or tt == BattleUnitSystem.UnitType.HEAVY_CAVALRY or tt == BattleUnitSystem.UnitType.HORSE_ARCHER

func _fire_volley(i: int) -> void:
	## Archer volley: fire 2 extra arrows at ±15° spread with +30% damage
	var target := _units.target_unit[i]
	if target < 0 or target >= _units.count or _units.alive[target] == 0:
		return
	var dx := _units.x[target] - _units.x[i]
	var dy := _units.y[target] - _units.y[i]
	var dist := maxf(1.0, sqrt(dx * dx + dy * dy))
	var nx := dx / dist
	var ny := dy / dist
	var base_angle := atan2(ny, nx)
	var t := _units.unit_type[i]
	var bullet_spd: float = BattleUnitSystem.UNIT_STATS["bullet_speed"][t]
	var bullet_dmg: float = BattleUnitSystem.UNIT_STATS["attack_damage"][t] * 1.3
	var bullet_mass: float = BattleUnitSystem.UNIT_STATS["bullet_mass"][t]
	for offset: float in [-0.26, 0.26]:  # ±15° in radians
		var angle: float = base_angle + offset
		_projectiles.spawn(
			_units.x[i], _units.y[i],
			cos(angle) * bullet_spd, sin(angle) * bullet_spd,
			bullet_dmg, bullet_mass,
			_units.faction[i], t, _units.group_formation[i]
		)

func _fire_fireball(i: int, target: int) -> void:
	## Mage fireball: splash projectile with burn
	var dx := _units.x[target] - _units.x[i]
	var dy := _units.y[target] - _units.y[i]
	var dist := maxf(1.0, sqrt(dx * dx + dy * dy))
	var nx := dx / dist
	var ny := dy / dist
	var t := _units.unit_type[i]
	var bullet_spd: float = BattleUnitSystem.UNIT_STATS["bullet_speed"][t]
	var bullet_dmg: float = BattleUnitSystem.UNIT_STATS["attack_damage"][t] * 2.0
	var bullet_mass: float = BattleUnitSystem.UNIT_STATS["bullet_mass"][t]
	var idx := _projectiles.spawn(
		_units.x[i], _units.y[i],
		nx * bullet_spd, ny * bullet_spd,
		bullet_dmg, bullet_mass,
		_units.faction[i], t, _units.group_formation[i]
	)
	if idx >= 0:
		_projectiles.is_splash[idx] = 1
		_projectiles.splash_radius[idx] = 50.0
		_projectiles.is_burning[idx] = 1

func _do_combat(i: int, dt: float) -> void:
	## Standard combat: find target, move toward, attack
	_update_target(i)
	var target_idx := _units.target_unit[i]
	if target_idx == PLAYER_TARGET_ID:
		_do_movement_toward_pos(i, player_position, dt, false, false)  # Direct to player, no flow
		_do_attack_player(i)
	elif target_idx >= 0:
		_do_movement(i, dt)
		_do_attack(i)
	else:
		_do_advance(i, dt)

func _do_attack_any(i: int) -> void:
	## Attack using either SoA target or player target
	var target_idx := _units.target_unit[i]
	if target_idx == PLAYER_TARGET_ID:
		_do_attack_player(i)
	elif target_idx >= 0:
		_do_attack(i)

func _apply_group_cohesion(i: int, gid: int, dt: float) -> void:
	## Pull units toward their formation position within the group.
	## Formation shapes: LINE (horizontal), SHIELD_WALL (tight rows), WEDGE (V-shape),
	## LOOSE_LINE (spread out), BLOCK (square grid).
	var grp = _commander.get_group(gid)
	if not grp:
		return
	var center := _units.get_group_center(gid)
	if center == Vector2.ZERO:
		return

	# Find this unit's index within its group (for formation offset)
	var unit_index := 0
	var group_size := 0
	for j in _units.count:
		if _units.alive[j] == 1 and _units.group_id[j] == gid:
			if j == i:
				unit_index = group_size
			group_size += 1

	if group_size <= 1:
		return

	# Calculate formation target position
	var target := _get_formation_pos(center, grp.formation_type, unit_index, group_size, grp)

	var dx := target.x - _units.x[i]
	var dy := target.y - _units.y[i]
	var dist := sqrt(dx * dx + dy * dy)

	# Don't pull if close enough to formation slot
	if dist < 20.0:
		return

	# Strength: gentle when close, stronger when far
	var strength: float
	if dist < 60.0:
		strength = 0.12
	elif dist < 150.0:
		strength = 0.25
	else:
		strength = 0.45
	var nx := dx / dist
	var ny := dy / dist
	var acc: float = _units.acceleration[i] * strength
	_units.vx[i] += nx * acc * dt * 60.0
	_units.vy[i] += ny * acc * dt * 60.0

func _get_formation_pos(center: Vector2, formation: int, idx: int, total: int, grp) -> Vector2:
	## Returns world position for unit at index 'idx' in a formation of 'total' units.
	var spacing := 22.0  # pixels between units

	# Get facing direction (toward target or nearest enemy)
	var face_x := 0.0
	var face_y := -1.0  # Default: face up
	if grp.target_x != 0.0 or grp.target_y != 0.0:
		var tdx: float = grp.target_x - center.x
		var tdy: float = grp.target_y - center.y
		var td: float = sqrt(tdx * tdx + tdy * tdy)
		if td > 1.0:
			face_x = tdx / td
			face_y = tdy / td
	# Perpendicular (left of facing)
	var perp_x := -face_y
	var perp_y := face_x

	match formation:
		BattleUnitSystem.FormationType.LINE:
			# Single row perpendicular to facing
			var half := (total - 1) * 0.5
			var offset := (idx - half) * spacing
			return center + Vector2(perp_x * offset, perp_y * offset)

		BattleUnitSystem.FormationType.SHIELD_WALL:
			# Tight rows (wider, 2-3 rows deep)
			spacing = 18.0
			var cols := maxi(5, ceili(sqrt(float(total) * 2.5)))
			var row := idx / cols
			var col := idx % cols
			var half_col := (cols - 1) * 0.5
			var col_off := (col - half_col) * spacing
			var row_off := row * spacing * 1.2
			return center + Vector2(perp_x * col_off - face_x * row_off, perp_y * col_off - face_y * row_off)

		BattleUnitSystem.FormationType.BLOCK:
			# Square grid
			var side := maxi(2, ceili(sqrt(float(total))))
			var row := idx / side
			var col := idx % side
			var half_col := (side - 1) * 0.5
			var half_row := (ceili(float(total) / side) - 1) * 0.5
			var col_off := (col - half_col) * spacing
			var row_off := (row - half_row) * spacing
			return center + Vector2(perp_x * col_off + face_x * row_off, perp_y * col_off + face_y * row_off)

		BattleUnitSystem.FormationType.WEDGE:
			# V-shape pointing forward
			if idx == 0:
				return center + Vector2(face_x * spacing, face_y * spacing)
			var row := ceili(float(idx) / 2.0)
			var side := 1 if (idx % 2 == 1) else -1
			var forward_off := -row * spacing * 0.8
			var lateral_off := side * row * spacing
			return center + Vector2(face_x * forward_off + perp_x * lateral_off, face_y * forward_off + perp_y * lateral_off)

		BattleUnitSystem.FormationType.LOOSE_LINE:
			# Single row, extra spacing
			spacing = 35.0
			var half := (total - 1) * 0.5
			var offset := (idx - half) * spacing
			return center + Vector2(perp_x * offset, perp_y * offset)

	# Fallback: blob
	return center

func _do_cluster(i: int, dt: float) -> void:
	## Move toward group center to cluster up
	var gid := _units.group_id[i]
	if gid < 0:
		return
	var center := _units.get_group_center(gid)
	var dx := center.x - _units.x[i]
	var dy := center.y - _units.y[i]
	var dist := sqrt(dx * dx + dy * dy)
	if dist < 40.0:
		return  # Close enough
	var nx := dx / dist
	var ny := dy / dist
	# Local obstacle avoidance
	if _flow and _flow.is_valid():
		var avoid_dir := _flow.get_avoidance_dir(_units.x[i], _units.y[i], Vector2(nx, ny), 48.0)
		nx = avoid_dir.x
		ny = avoid_dir.y
	var acc: float = _units.acceleration[i] * 0.5
	_units.vx[i] += nx * acc * dt * 60.0
	_units.vy[i] += ny * acc * dt * 60.0
	var spd: float = _units.max_speed[i] * 0.5
	var cur := sqrt(_units.vx[i] * _units.vx[i] + _units.vy[i] * _units.vy[i])
	if cur > spd:
		var s := spd / cur
		_units.vx[i] *= s
		_units.vy[i] *= s

func _do_scatter(i: int, dt: float) -> void:
	## Push away from nearby allies to spread out
	var nearby := _units.get_nearby(_units.x[i], _units.y[i], 80.0)
	var push_x := 0.0
	var push_y := 0.0
	for j in nearby:
		if j == i or _units.alive[j] == 0 or _units.faction[j] != _units.faction[i]:
			continue
		var dx := _units.x[i] - _units.x[j]
		var dy := _units.y[i] - _units.y[j]
		var dist := sqrt(dx * dx + dy * dy)
		if dist > 0.1 and dist < 60.0:
			push_x += dx / dist
			push_y += dy / dist
	if absf(push_x) > 0.01 or absf(push_y) > 0.01:
		var acc: float = _units.acceleration[i] * 0.3
		_units.vx[i] += push_x * acc * dt * 60.0
		_units.vy[i] += push_y * acc * dt * 60.0

func _do_follow_player(i: int, dt: float) -> void:
	## Follow the player character and attack whatever is nearby
	if not player_alive:
		_do_combat(i, dt)
		return
	var dx := player_position.x - _units.x[i]
	var dy := player_position.y - _units.y[i]
	var dist := sqrt(dx * dx + dy * dy)
	# Stay within 80-200px of player
	if dist > 100.0:
		_do_movement_toward_pos(i, player_position, dt, true, false)
	elif dist < 50.0:
		# Too close, back off slightly
		var nx := -dx / maxf(dist, 0.1)
		var ny := -dy / maxf(dist, 0.1)
		_units.vx[i] += nx * _units.acceleration[i] * 0.3 * dt * 60.0
		_units.vy[i] += ny * _units.acceleration[i] * 0.3 * dt * 60.0
	# Attack nearby enemies
	_update_target(i)
	_do_attack_any(i)

func _update_formation_bonuses() -> void:
	## Check if each unit meets its formation's bonus condition.
	## SHIELD_WALL: adjacent unit ≤40px → block 50% frontal ranged (checked in damage)
	## WEDGE: lead unit or follower (checked in attack)
	## LINE: units 30-50px apart → +20% attack speed
	## LOOSE_LINE: -30% AoE, 3+ on same target = +15% dmg
	## BLOCK: -25% flank damage taken
	for i in _units.count:
		if _units.alive[i] == 0:
			continue
		_units.formation_bonus_active[i] = 0
		var gid := _units.group_id[i]
		if gid < 0 or not _commander:
			continue
		var grp = _commander.get_group(gid)
		if not grp:
			continue
		match grp.formation_type:
			BattleUnitSystem.FormationType.SHIELD_WALL:
				# Active if adjacent ally within 40px
				var nearby := _units.get_nearby(_units.x[i], _units.y[i], 40.0)
				for j in nearby:
					if j != i and _units.alive[j] == 1 and _units.faction[j] == _units.faction[i]:
						_units.formation_bonus_active[i] = 1
						break
			BattleUnitSystem.FormationType.LINE:
				# Active if nearest ally is 25-55px away (proper line spacing)
				var nearby := _units.get_nearby(_units.x[i], _units.y[i], 55.0)
				for j in nearby:
					if j != i and _units.alive[j] == 1 and _units.faction[j] == _units.faction[i]:
						var dx := _units.x[j] - _units.x[i]
						var dy := _units.y[j] - _units.y[i]
						var d := sqrt(dx * dx + dy * dy)
						if d >= 25.0:
							_units.formation_bonus_active[i] = 1
							break
			BattleUnitSystem.FormationType.LOOSE_LINE:
				# Always active if in loose line formation
				_units.formation_bonus_active[i] = 1
			BattleUnitSystem.FormationType.BLOCK:
				# Active if 2+ allies within 50px (tight block)
				var nearby := _units.get_nearby(_units.x[i], _units.y[i], 50.0)
				var ally_count := 0
				for j in nearby:
					if j != i and _units.alive[j] == 1 and _units.faction[j] == _units.faction[i]:
						ally_count += 1
				if ally_count >= 2:
					_units.formation_bonus_active[i] = 1
			BattleUnitSystem.FormationType.WEDGE:
				# Active for all units in wedge formation
				_units.formation_bonus_active[i] = 1

var _dead_commanders: Dictionary = {}  # unit index -> true (already processed)

func _check_commander_deaths() -> void:
	## When a commander dies: -30 morale to group, debuff timer on group members.
	for i in _units.count:
		if _units.is_commander[i] == 1 and _units.alive[i] == 0 and not _dead_commanders.has(i):
			_dead_commanders[i] = true
			var gid := _units.group_id[i]
			# Apply -30 morale and 10s debuff to all group members
			for j in _units.count:
				if _units.alive[j] == 1 and _units.group_id[j] == gid:
					_units.morale[j] = maxf(0.0, _units.morale[j] - 30.0)
					_units.commander_debuff_timer[j] = 10.0
			# Also apply morale cascade to nearby allies (150px)
			_apply_morale_cascade(
				Vector2(_units.x[i], _units.y[i]),
				_units.faction[i], -15.0, 150.0, gid
			)
			# Promote next highest-HP unit in group to commander
			var best_j := -1
			var best_hp := 0.0
			for j in _units.count:
				if _units.alive[j] == 1 and _units.group_id[j] == gid and _units.is_commander[j] == 0:
					if _units.hp[j] > best_hp:
						best_hp = _units.hp[j]
						best_j = j
			if best_j >= 0:
				_units.is_commander[best_j] = 1
				# Boost the new commander's HP
				var bonus := _units.max_hp[best_j] * 0.3
				_units.hp[best_j] = minf(_units.hp[best_j] + bonus, _units.max_hp[best_j] * 1.3)
				_units.max_hp[best_j] *= 1.3

func _retarget_dead_groups() -> void:
	for g in _commander.get_all_groups():
		if g.target_group_id >= 0:
			if not _commander.is_group_alive(g.target_group_id, _units):
				var enemy_fac := BattleUnitSystem.Faction.RED if g.faction == BattleUnitSystem.Faction.BLUE else BattleUnitSystem.Faction.BLUE
				var enemy_groups := _commander.get_faction_groups(enemy_fac)
				var live_groups := []
				for eg in enemy_groups:
					if _commander.is_group_alive(eg.id, _units):
						live_groups.append(eg)
				if not live_groups.is_empty():
					var new_target := _find_priority_target(g.unit_type, live_groups)
					if new_target:
						g.target_group_id = new_target.id

func _get_best_counter_formation(enemy_formation: int) -> int:
	## Return the formation that best counters the given enemy formation.
	## Uses FORMATION_COUNTER matrix: find which attacker row has highest mult vs defender col.
	var best_form := 0
	var best_mult := 0.0
	for f in BattleUnitSystem.FORMATION_COUNTER.size():
		var mult: float = BattleUnitSystem.FORMATION_COUNTER[f][enemy_formation]
		if mult > best_mult:
			best_mult = mult
			best_form = f
	return best_form

func _find_best_target_by_counter(g: BattleCommander.BattleGroup, enemy_groups: Array) -> BattleCommander.BattleGroup:
	## Find the enemy group this group's formation counters the most.
	var best_target: BattleCommander.BattleGroup = null
	var best_advantage := 0.0
	var my_form := g.formation_type
	for eg in enemy_groups:
		var eg_alive := _units.get_group_alive_count(eg.id)
		if eg_alive == 0:
			continue
		var ef: int = eg.formation_type
		if my_form >= 0 and my_form < BattleUnitSystem.FORMATION_COUNTER.size() and ef >= 0 and ef < BattleUnitSystem.FORMATION_COUNTER[my_form].size():
			var advantage: float = BattleUnitSystem.FORMATION_COUNTER[my_form][ef]
			if advantage > best_advantage:
				best_advantage = advantage
				best_target = eg
	return best_target

func _reassess_strategy() -> void:
	## Every 3s, reassess group commands for RED faction using tactical AI.
	## Reads enemy formations and adapts. Coordinates multi-group attacks.
	var red_groups := _commander.get_faction_groups(BattleUnitSystem.Faction.RED)
	var blue_groups := _commander.get_faction_groups(BattleUnitSystem.Faction.BLUE)

	# Tick tactic cooldowns
	_pincer_cooldown = maxf(0.0, _pincer_cooldown - STRATEGY_INTERVAL)

	# Plan battle strategy on first reassessment (all units spawned by now)
	if not _strategy_planned:
		_plan_battle_strategy()

	# Army-level coordination for non-MILITIA RED AI
	if ai_tier >= AITier.TRAINED:
		_update_army_phase(red_groups, blue_groups)
		# During STAGING and ADVANCE, army controls all groups — skip per-group tactics
		if _army_phase == ArmyPhase.STAGING or _army_phase == ArmyPhase.ADVANCE:
			return

	# === GLOBAL TACTICS (gated by AI tier) ===

	# MILITIA (tier 0): No global tactics at all — just attack-move
	# TRAINED (tier 1): Focus fire on weak groups
	# VETERAN (tier 2): + Formation counters, pincer attacks
	# ELITE (tier 3): + Commander hunting, bait & retreat, hold ranged back

	# A. Focus Fire — TRAINED+ AI piles on weakened groups
	_focus_fire_target_group = -1
	if ai_tier >= AITier.TRAINED:
		var weakest_ratio := 1.0
		for bg in blue_groups:
			var bg_alive := _units.get_group_alive_count(bg.id)
			if bg.initial_size > 0 and bg_alive > 0:
				var bg_ratio := float(bg_alive) / float(bg.initial_size)
				if bg_ratio < 0.5 and bg_alive >= 2 and bg_ratio < weakest_ratio:
					weakest_ratio = bg_ratio
					_focus_fire_target_group = bg.id

	# B. Pincer Attack — VETERAN+ AI, 2+ melee RED groups, battle_time > 15s
	if ai_tier >= AITier.VETERAN and _battle_time > 15.0 and _pincer_cooldown <= 0.0:
		_try_pincer_attack(red_groups, blue_groups)

	# C. Commander Hunting — ELITE AI only
	if ai_tier >= AITier.ELITE:
		_try_commander_hunting(red_groups, blue_groups)

	# D. Formation Counter-Reading — VETERAN+ AI adapts formations
	if ai_tier >= AITier.VETERAN:
		_adapt_formations_to_counter(red_groups, blue_groups)

	for g in red_groups:
		var alive_count := _units.get_group_alive_count(g.id)
		if alive_count == 0:
			continue

		# Record initial size on first assessment
		if g.initial_size == 0:
			g.initial_size = _get_group_total_count(g)

		var center := _units.get_group_center(g.id)
		var strength_ratio := _get_local_strength_ratio(g, center)
		var casualty_ratio := 1.0 - float(alive_count) / maxf(1.0, float(g.initial_size))

		# MILITIA AI: just attack-move, no formation changes or tactics
		if ai_tier == AITier.MILITIA:
			g.command = BattleCommander.CommandType.ATTACK
			continue

		# APPROACH phase: melee attacks, ranged/cavalry hold position
		if _army_phase == ArmyPhase.APPROACH:
			match g.unit_type:
				BattleUnitSystem.UnitType.INFANTRY, BattleUnitSystem.UnitType.HEAVY_INFANTRY, BattleUnitSystem.UnitType.SPEAR:
					g.command = BattleCommander.CommandType.ATTACK
				BattleUnitSystem.UnitType.ARCHER, BattleUnitSystem.UnitType.MAGE, BattleUnitSystem.UnitType.RANGED_INFANTRY:
					_assess_ranged(g, center, blue_groups)
				BattleUnitSystem.UnitType.CAVALRY, BattleUnitSystem.UnitType.HEAVY_CAVALRY, BattleUnitSystem.UnitType.HORSE_ARCHER:
					g.command = BattleCommander.CommandType.HOLD
			continue

		# Focus fire override — TRAINED+ AI piles on weakened target
		if _focus_fire_target_group >= 0 and ai_tier >= AITier.TRAINED:
			var tc := _units.get_group_center(_focus_fire_target_group)
			if tc != Vector2.ZERO and center.distance_to(tc) < 500.0:
				if g.unit_type == BattleUnitSystem.UnitType.ARCHER or g.unit_type == BattleUnitSystem.UnitType.MAGE:
					g.target_group_id = _focus_fire_target_group
					g.target_x = tc.x
					g.target_y = tc.y
					g.command = BattleCommander.CommandType.ATTACK
					continue
				# VETERAN+ AI: melee groups also pile on
				elif ai_tier >= AITier.VETERAN and center.distance_to(tc) < 300.0:
					g.target_group_id = _focus_fire_target_group
					g.target_x = tc.x
					g.target_y = tc.y
					g.command = BattleCommander.CommandType.CHARGE
					continue

		# VETERAN+ AI: Smart target selection based on formation counters
		if ai_tier >= AITier.VETERAN:
			var counter_target := _find_best_target_by_counter(g, blue_groups)
			if counter_target and counter_target.id != g.target_group_id:
				var ct_center := _units.get_group_center(counter_target.id)
				if ct_center != Vector2.ZERO and center.distance_to(ct_center) < 600.0:
					g.target_group_id = counter_target.id


		match g.unit_type:
			BattleUnitSystem.UnitType.INFANTRY:
				_assess_infantry(g, center, strength_ratio, casualty_ratio, blue_groups)
			BattleUnitSystem.UnitType.HEAVY_INFANTRY:
				_assess_heavy_infantry(g, center, strength_ratio, blue_groups)
			BattleUnitSystem.UnitType.CAVALRY:
				_assess_cavalry(g, center, blue_groups)
			BattleUnitSystem.UnitType.HEAVY_CAVALRY:
				_assess_heavy_cavalry(g, center, blue_groups)
			BattleUnitSystem.UnitType.ARCHER, BattleUnitSystem.UnitType.MAGE, BattleUnitSystem.UnitType.RANGED_INFANTRY:
				_assess_ranged(g, center, blue_groups)
			BattleUnitSystem.UnitType.SPEAR:
				_assess_spear(g, center, strength_ratio, blue_groups)
			BattleUnitSystem.UnitType.HORSE_ARCHER:
				_assess_horse_archer(g, center, blue_groups)

func _adapt_formations_to_counter(red_groups: Array, blue_groups: Array) -> void:
	## Read BLUE formations and switch RED formations to counter them.
	## Only for melee groups (infantry/heavy_inf). Ranged stay in loose line.
	for g in red_groups:
		if _units.get_group_alive_count(g.id) == 0:
			continue
		# Only adapt infantry/heavy infantry/spear formations
		if g.unit_type != BattleUnitSystem.UnitType.INFANTRY and g.unit_type != BattleUnitSystem.UnitType.HEAVY_INFANTRY and g.unit_type != BattleUnitSystem.UnitType.SPEAR:
			continue
		# Find the nearest enemy group and counter its formation
		var center := _units.get_group_center(g.id)
		var nearest_enemy: BattleCommander.BattleGroup = null
		var nearest_dist := 99999.0
		for bg in blue_groups:
			if _units.get_group_alive_count(bg.id) == 0:
				continue
			var bc := _units.get_group_center(bg.id)
			if bc == Vector2.ZERO:
				continue
			var d := center.distance_to(bc)
			if d < nearest_dist:
				nearest_dist = d
				nearest_enemy = bg
		if nearest_enemy and nearest_dist < 400.0:
			# Switch to counter-formation
			var counter := _get_best_counter_formation(nearest_enemy.formation_type)
			# Only switch if meaningfully different (avoid constant switching)
			if counter != g.formation_type:
				var advantage: float = BattleUnitSystem.FORMATION_COUNTER[counter][nearest_enemy.formation_type]
				var current_advantage: float = BattleUnitSystem.FORMATION_COUNTER[g.formation_type][nearest_enemy.formation_type]
				if advantage > current_advantage + 0.1:
					g.formation_type = counter

func _assess_infantry(g: BattleCommander.BattleGroup, center: Vector2, strength: float, casualties: float, enemy_groups: Array) -> void:
	var cav_nearby := _count_nearby_type(center, 300.0, BattleUnitSystem.Faction.BLUE,
		[BattleUnitSystem.UnitType.CAVALRY, BattleUnitSystem.UnitType.HEAVY_CAVALRY, BattleUnitSystem.UnitType.HORSE_ARCHER])

	# Cavalry incoming — shield wall (best counter to cavalry charge)
	if cav_nearby >= 3:
		g.command = BattleCommander.CommandType.DEFENSIVE
		g.formation_type = BattleUnitSystem.FormationType.SHIELD_WALL
		return

	# Heavy casualties and outnumbered — retreat but in formation
	if casualties > 0.5 and strength < 0.5:
		g.command = BattleCommander.CommandType.RETREAT
		g.formation_type = BattleUnitSystem.FormationType.BLOCK  # Retreat in block to reduce casualties
		return

	# Outnumbered locally but not yet taking heavy casualties — defensive formation
	if strength < 0.7 and casualties < 0.3:
		g.command = BattleCommander.CommandType.DEFENSIVE
		g.formation_type = BattleUnitSystem.FormationType.SHIELD_WALL
		return

	# Bait & Retreat: after friendly cavalry withdraws, pull back 100px to create gap
	var red_cav_groups := _commander.get_faction_groups(BattleUnitSystem.Faction.RED)
	for cg in red_cav_groups:
		if (cg.unit_type == BattleUnitSystem.UnitType.CAVALRY or cg.unit_type == BattleUnitSystem.UnitType.HEAVY_CAVALRY):
			if cg.charge_state == BattleCommander.ChargeState.WITHDRAWING:
				var nearest_enemy := _find_nearest_enemy_group_center(center, enemy_groups)
				if nearest_enemy != Vector2.ZERO:
					var away := (center - nearest_enemy).normalized()
					g.target_x = center.x + away.x * 100.0
					g.target_y = center.y + away.y * 100.0
					g.command = BattleCommander.CommandType.MOVE
					return

	# Winning — press attack aggressively with wedge
	if strength > 1.5:
		g.command = BattleCommander.CommandType.CHARGE
		g.formation_type = BattleUnitSystem.FormationType.WEDGE
		# Target weakest nearby enemy
		var weakest := _find_weakest_enemy_group(center, enemy_groups, 500.0)
		if weakest:
			var wc := _units.get_group_center(weakest.id)
			g.target_group_id = weakest.id
			g.target_x = wc.x
			g.target_y = wc.y
		return

	# Default — advance and attack (formation set by _adapt_formations_to_counter)
	g.command = BattleCommander.CommandType.ATTACK

func _assess_heavy_infantry(g: BattleCommander.BattleGroup, center: Vector2, strength: float, enemy_groups: Array) -> void:
	var cav_nearby := _count_nearby_type(center, 300.0, BattleUnitSystem.Faction.BLUE,
		[BattleUnitSystem.UnitType.CAVALRY, BattleUnitSystem.UnitType.HEAVY_CAVALRY, BattleUnitSystem.UnitType.HORSE_ARCHER])

	# Cavalry threat — defensive stance but keep fighting
	if cav_nearby >= 2:
		g.command = BattleCommander.CommandType.DEFENSIVE
		g.formation_type = BattleUnitSystem.FormationType.BLOCK
		return

	# Default — attack
	g.command = BattleCommander.CommandType.ATTACK
	g.formation_type = BattleUnitSystem.FormationType.BLOCK

func _assess_cavalry(g: BattleCommander.BattleGroup, center: Vector2, enemy_groups: Array) -> void:
	## Cavalry: fast, aggressive, hit-and-run. Targets exposed flanks and ranged units.
	## Charge lifecycle: IDLE → CHARGING → IN_MELEE → WITHDRAWING → IDLE
	var alive_count := _units.get_group_alive_count(g.id)

	# Depleted cavalry — desperate attack
	if g.initial_size > 0 and alive_count < g.initial_size * 0.3:
		g.charge_state = BattleCommander.ChargeState.IDLE
		g.command = BattleCommander.CommandType.ATTACK
		g.formation_type = BattleUnitSystem.FormationType.WEDGE
		return

	match g.charge_state:
		BattleCommander.ChargeState.IDLE:
			g.formation_type = BattleUnitSystem.FormationType.WEDGE
			# Priority 1: exposed ranged units (archers/mages without infantry screen)
			var ranged_target := _find_exposed_ranged_group(center, enemy_groups)
			if ranged_target:
				var tc := _units.get_group_center(ranged_target.id)
				g.target_x = tc.x
				g.target_y = tc.y
				g.target_group_id = ranged_target.id
				g.charge_state = BattleCommander.ChargeState.CHARGING
				g.charge_timer = 0.0
				g.command = BattleCommander.CommandType.CHARGE
				var retreat_dir := (center - tc).normalized()
				g.withdraw_pos = center + retreat_dir * 300.0
				return
			# Priority 2: weakened group (below 50% strength) — finish them off (avoid spear!)
			var weak_target := _find_weakest_enemy_group(center, enemy_groups, 500.0)
			if weak_target and weak_target.unit_type != BattleUnitSystem.UnitType.SPEAR:
				var wc := _units.get_group_center(weak_target.id)
				if wc != Vector2.ZERO:
					var w_ratio := 1.0
					if weak_target.initial_size > 0:
						w_ratio = float(_units.get_group_alive_count(weak_target.id)) / float(weak_target.initial_size)
					if w_ratio < 0.5:
						g.target_x = wc.x
						g.target_y = wc.y
						g.target_group_id = weak_target.id
						g.charge_state = BattleCommander.ChargeState.CHARGING
						g.charge_timer = 0.0
						g.command = BattleCommander.CommandType.CHARGE
						g.withdraw_pos = center + (center - wc).normalized() * 300.0
						return
			# Priority 3: flank attack — find an enemy group engaged with our infantry
			# and charge their flank/rear
			var flank_target := _find_flank_target(g, center, enemy_groups)
			if flank_target:
				var ftc := _units.get_group_center(flank_target.id)
				if ftc != Vector2.ZERO:
					# Attack from the side, not head-on
					var to_target := (ftc - center).normalized()
					var perp := Vector2(-to_target.y, to_target.x)
					var flank_pos := ftc + perp * 200.0
					g.target_x = flank_pos.x
					g.target_y = flank_pos.y
					g.target_group_id = flank_target.id
					g.charge_state = BattleCommander.ChargeState.CHARGING
					g.charge_timer = 0.0
					g.command = BattleCommander.CommandType.CHARGE
					g.withdraw_pos = center + (center - ftc).normalized() * 300.0
					return
			# Default: roam looking for opportunities
			g.command = BattleCommander.CommandType.ATTACK

		BattleCommander.ChargeState.CHARGING:
			g.command = BattleCommander.CommandType.CHARGE
			g.formation_type = BattleUnitSystem.FormationType.WEDGE
			var target_center := Vector2(g.target_x, g.target_y)
			if g.target_group_id >= 0:
				var tc := _units.get_group_center(g.target_group_id)
				if tc != Vector2.ZERO:
					target_center = tc
			if center.distance_to(target_center) < 80.0:
				g.charge_state = BattleCommander.ChargeState.IN_MELEE
				g.charge_timer = 0.0
				g.command = BattleCommander.CommandType.ATTACK
			g.charge_timer += STRATEGY_INTERVAL
			if g.charge_timer > 6.0:
				g.charge_state = BattleCommander.ChargeState.WITHDRAWING
				g.charge_timer = 0.0

		BattleCommander.ChargeState.IN_MELEE:
			g.command = BattleCommander.CommandType.ATTACK
			g.charge_timer += STRATEGY_INTERVAL
			if g.charge_timer > 3.0:
				g.charge_state = BattleCommander.ChargeState.WITHDRAWING
				g.charge_timer = 0.0
				g.command = BattleCommander.CommandType.MOVE
				g.target_x = g.withdraw_pos.x
				g.target_y = g.withdraw_pos.y

		BattleCommander.ChargeState.WITHDRAWING:
			g.command = BattleCommander.CommandType.MOVE
			g.target_x = g.withdraw_pos.x
			g.target_y = g.withdraw_pos.y
			g.charge_timer += STRATEGY_INTERVAL
			if g.charge_timer > 5.0:
				g.charge_state = BattleCommander.ChargeState.IDLE
				g.charge_timer = 0.0

func _assess_heavy_cavalry(g: BattleCommander.BattleGroup, center: Vector2, enemy_groups: Array) -> void:
	## Heavy cavalry: attack by default. Charge heavy infantry when outnumbering.
	var alive_count := _units.get_group_alive_count(g.id)

	if g.charge_state == BattleCommander.ChargeState.IDLE:
		for eg in enemy_groups:
			if eg.unit_type == BattleUnitSystem.UnitType.HEAVY_INFANTRY:
				var enemy_alive := _units.get_group_alive_count(eg.id)
				if enemy_alive > 0 and alive_count > enemy_alive * 1.5:
					var tc := _units.get_group_center(eg.id)
					g.target_x = tc.x
					g.target_y = tc.y
					g.target_group_id = eg.id
					g.charge_state = BattleCommander.ChargeState.CHARGING
					g.charge_timer = 0.0
					g.command = BattleCommander.CommandType.CHARGE
					g.formation_type = BattleUnitSystem.FormationType.WEDGE
					var retreat_dir := (center - tc).normalized()
					g.withdraw_pos = center + retreat_dir * 300.0
					return

	# Fall back to standard cavalry assessment
	_assess_cavalry(g, center, enemy_groups)

func _assess_spear(g: BattleCommander.BattleGroup, center: Vector2, strength: float, enemy_groups: Array) -> void:
	## Spear infantry: anti-cavalry specialist. Holds position vs cavalry, attacks infantry otherwise.
	var cav_nearby := _count_nearby_type(center, 350.0, BattleUnitSystem.Faction.BLUE,
		[BattleUnitSystem.UnitType.CAVALRY, BattleUnitSystem.UnitType.HEAVY_CAVALRY, BattleUnitSystem.UnitType.HORSE_ARCHER])
	# Cavalry incoming — hold ground in line, activate brace
	if cav_nearby >= 2:
		g.command = BattleCommander.CommandType.DEFENSIVE
		g.formation_type = BattleUnitSystem.FormationType.LINE
		return
	# Seek out enemy cavalry groups to intercept
	for eg in enemy_groups:
		if eg.unit_type == BattleUnitSystem.UnitType.CAVALRY or eg.unit_type == BattleUnitSystem.UnitType.HEAVY_CAVALRY or eg.unit_type == BattleUnitSystem.UnitType.HORSE_ARCHER:
			var ea := _units.get_group_alive_count(eg.id)
			if ea > 0:
				var tc := _units.get_group_center(eg.id)
				if tc != Vector2.ZERO and center.distance_to(tc) < 500.0:
					g.target_x = tc.x
					g.target_y = tc.y
					g.target_group_id = eg.id
					g.command = BattleCommander.CommandType.ATTACK
					g.formation_type = BattleUnitSystem.FormationType.LINE
					return
	# No cavalry threat — fight like infantry
	if strength > 1.5:
		g.command = BattleCommander.CommandType.CHARGE
		g.formation_type = BattleUnitSystem.FormationType.LINE
		var weakest := _find_weakest_enemy_group(center, enemy_groups, 500.0)
		if weakest:
			var wc := _units.get_group_center(weakest.id)
			g.target_group_id = weakest.id
			g.target_x = wc.x
			g.target_y = wc.y
		return
	g.command = BattleCommander.CommandType.ATTACK
	g.formation_type = BattleUnitSystem.FormationType.LINE

func _assess_horse_archer(g: BattleCommander.BattleGroup, center: Vector2, enemy_groups: Array) -> void:
	## Horse archer: fast kiting ranged cavalry. Harass and retreat, never stay in melee.
	g.formation_type = BattleUnitSystem.FormationType.LOOSE_LINE
	var melee_threats := _count_nearby_type(center, 200.0, BattleUnitSystem.Faction.BLUE,
		[BattleUnitSystem.UnitType.INFANTRY, BattleUnitSystem.UnitType.HEAVY_INFANTRY,
		 BattleUnitSystem.UnitType.CAVALRY, BattleUnitSystem.UnitType.SPEAR])
	# Melee too close — kite away
	if melee_threats >= 3:
		var away := Vector2.ZERO
		for eg in enemy_groups:
			var ec := _units.get_group_center(eg.id)
			if ec != Vector2.ZERO and center.distance_to(ec) < 250.0:
				away += (center - ec).normalized()
		if away.length() > 0.01:
			away = away.normalized()
			g.target_x = center.x + away.x * 300.0
			g.target_y = center.y + away.y * 300.0
			g.command = BattleCommander.CommandType.MOVE
			return
	# Priority: harass exposed ranged or weak groups
	var ranged_target := _find_exposed_ranged_group(center, enemy_groups)
	if ranged_target:
		var tc := _units.get_group_center(ranged_target.id)
		if tc != Vector2.ZERO:
			g.target_x = tc.x
			g.target_y = tc.y
			g.target_group_id = ranged_target.id
			g.command = BattleCommander.CommandType.ATTACK
			return
	# Default: attack move
	g.command = BattleCommander.CommandType.ATTACK

func _assess_ranged(g: BattleCommander.BattleGroup, center: Vector2, enemy_groups: Array) -> void:
	## Archers/mages: smart positioning, focus fire, and self-preservation.
	g.formation_type = BattleUnitSystem.FormationType.LOOSE_LINE

	var melee_threats := _count_nearby_type(center, 150.0, BattleUnitSystem.Faction.BLUE,
		[BattleUnitSystem.UnitType.INFANTRY, BattleUnitSystem.UnitType.HEAVY_INFANTRY,
		 BattleUnitSystem.UnitType.CAVALRY, BattleUnitSystem.UnitType.HEAVY_CAVALRY,
		 BattleUnitSystem.UnitType.SPEAR])
	var cav_threats := _count_nearby_type(center, 250.0, BattleUnitSystem.Faction.BLUE,
		[BattleUnitSystem.UnitType.CAVALRY, BattleUnitSystem.UnitType.HEAVY_CAVALRY,
		 BattleUnitSystem.UnitType.HORSE_ARCHER])

	# Cavalry charging us — emergency scatter! (cavalry counters ranged hard)
	if cav_threats >= 2:
		g.command = BattleCommander.CommandType.SCATTER
		return

	# Melee enemies too close — retreat laterally (not straight back)
	if melee_threats >= 3:
		g.command = BattleCommander.CommandType.RETREAT
		var retreat_dir := (red_objective - center).normalized() * -1.0
		if retreat_dir == Vector2.ZERO:
			retreat_dir = Vector2(1, 0)
		var perp := Vector2(-retreat_dir.y, retreat_dir.x)
		var side := 1.0 if randf() > 0.5 else -1.0
		var strafe_dir := (retreat_dir + perp * side * 0.8).normalized()
		g.target_x = center.x + strafe_dir.x * 200.0
		g.target_y = center.y + strafe_dir.y * 200.0
		return

	# Priority: focus fire on weakest enemy group (finish them off)
	var weak := _find_weakest_enemy_group(center, enemy_groups, 600.0)
	if weak:
		var wc := _units.get_group_center(weak.id)
		if wc != Vector2.ZERO:
			g.target_group_id = weak.id
			g.target_x = wc.x
			g.target_y = wc.y

	# Always try to stay behind friendly infantry screen
	if not _is_group_screened_by_infantry(g, center, enemy_groups):
		var friendly_inf_center := _find_friendly_infantry_center(g.faction)
		if friendly_inf_center != Vector2.ZERO:
			var nearest_enemy := _find_nearest_enemy_group_center(center, enemy_groups)
			if nearest_enemy != Vector2.ZERO:
				var to_enemy := (nearest_enemy - friendly_inf_center).normalized()
				var safe_pos := friendly_inf_center - to_enemy * 180.0
				g.target_x = safe_pos.x
				g.target_y = safe_pos.y
				g.command = BattleCommander.CommandType.ATTACK
				return

	# Default — attack from range
	g.command = BattleCommander.CommandType.ATTACK

# --- Smart AI Tactics ---

func _try_pincer_attack(red_groups: Array, blue_groups: Array) -> void:
	## When RED has 2+ melee groups, send one on wide arc to enemy rear.
	var melee_groups: Array = []
	for g in red_groups:
		if g.unit_type == BattleUnitSystem.UnitType.INFANTRY or g.unit_type == BattleUnitSystem.UnitType.HEAVY_INFANTRY:
			if _units.get_group_alive_count(g.id) >= 5:
				melee_groups.append(g)

	if melee_groups.size() < 2:
		return

	# Find enemy center
	var enemy_center := Vector2.ZERO
	var enemy_count := 0
	for bg in blue_groups:
		var bc := _units.get_group_center(bg.id)
		if bc != Vector2.ZERO:
			enemy_center += bc
			enemy_count += 1
	if enemy_count == 0:
		return
	enemy_center /= float(enemy_count)

	# First group advances slowly to pin
	var pin_group: BattleCommander.BattleGroup = melee_groups[0]
	pin_group.command = BattleCommander.CommandType.ATTACK
	pin_group.target_x = enemy_center.x
	pin_group.target_y = enemy_center.y

	# Second group flanks wide
	var flank_group: BattleCommander.BattleGroup = melee_groups[1]
	var our_center := _units.get_group_center(pin_group.id)
	var to_enemy := (enemy_center - our_center).normalized()
	var perp := Vector2(-to_enemy.y, to_enemy.x)
	var flank_target := enemy_center + perp * 300.0  # Wide arc
	flank_group.command = BattleCommander.CommandType.ATTACK
	flank_group.target_x = flank_target.x
	flank_group.target_y = flank_target.y

	_pincer_cooldown = 30.0  # 30 second cooldown

func _try_commander_hunting(red_groups: Array, blue_groups: Array) -> void:
	## RED cavalry/mages prioritize BLUE commanders as targets.
	# Find BLUE commanders
	var commander_positions: Array[Vector2] = []
	for i in _units.count:
		if _units.alive[i] == 1 and _units.faction[i] == BattleUnitSystem.Faction.BLUE and _units.is_commander[i] == 1:
			commander_positions.append(Vector2(_units.x[i], _units.y[i]))
	if commander_positions.is_empty():
		return

	# Direct cavalry/mage groups toward nearest commander
	for g in red_groups:
		if g.unit_type != BattleUnitSystem.UnitType.CAVALRY and g.unit_type != BattleUnitSystem.UnitType.MAGE:
			continue
		if _units.get_group_alive_count(g.id) == 0:
			continue
		var gc := _units.get_group_center(g.id)
		var best_dist := 99999.0
		var best_pos := Vector2.ZERO
		for cp in commander_positions:
			var d := gc.distance_to(cp)
			if d < best_dist:
				best_dist = d
				best_pos = cp
		if best_pos != Vector2.ZERO and best_dist < 600.0:
			# Set individual unit targets to the commander
			for i in _units.count:
				if _units.alive[i] == 1 and _units.group_id[i] == g.id:
					# Find the actual commander unit index
					var best_ci := -1
					var best_cd := 99999.0
					for ci in _units.count:
						if _units.alive[ci] == 1 and _units.faction[ci] == BattleUnitSystem.Faction.BLUE and _units.is_commander[ci] == 1:
							var dx := _units.x[ci] - _units.x[i]
							var dy := _units.y[ci] - _units.y[i]
							var cd := sqrt(dx * dx + dy * dy)
							if cd < best_cd:
								best_cd = cd
								best_ci = ci
					if best_ci >= 0:
						_units.target_unit[i] = best_ci

# === ARMY-LEVEL BATTLE COORDINATION ===

const _MELEE_TYPES := [BattleUnitSystem.UnitType.INFANTRY, BattleUnitSystem.UnitType.HEAVY_INFANTRY, BattleUnitSystem.UnitType.SPEAR]
const _RANGED_TYPES := [BattleUnitSystem.UnitType.ARCHER, BattleUnitSystem.UnitType.MAGE, BattleUnitSystem.UnitType.RANGED_INFANTRY]
const _CAV_TYPES := [BattleUnitSystem.UnitType.CAVALRY, BattleUnitSystem.UnitType.HEAVY_CAVALRY]
const _PHASE_NAMES := ["STAGING", "ADVANCE", "APPROACH", "ENGAGED", "CLEANUP"]

func _update_army_phase(red_groups: Array, blue_groups: Array) -> void:
	## Phase state machine dispatcher. Called from _reassess_strategy() every 3s.
	_phase_timer += STRATEGY_INTERVAL

	# Count total alive for cleanup check
	var red_alive := 0
	var blue_alive := 0
	for i in _units.count:
		if _units.alive[i] == 0:
			continue
		if _units.faction[i] == BattleUnitSystem.Faction.RED:
			red_alive += 1
		else:
			blue_alive += 1

	# CLEANUP transition: either side < 10 units
	if _army_phase >= ArmyPhase.APPROACH and (red_alive < 10 or blue_alive < 10):
		if _army_phase != ArmyPhase.CLEANUP:
			print("AI Army: %s -> CLEANUP" % _PHASE_NAMES[_army_phase])
			_army_phase = ArmyPhase.CLEANUP
			for g in red_groups:
				if _units.get_group_alive_count(g.id) > 0:
					g.command = BattleCommander.CommandType.ATTACK
		return

	match _army_phase:
		ArmyPhase.STAGING:
			_do_staging_phase(red_groups)
		ArmyPhase.ADVANCE:
			_do_advance_phase(red_groups, blue_groups)
		ArmyPhase.APPROACH:
			_do_approach_phase(red_groups, blue_groups)
		ArmyPhase.ENGAGED:
			_do_engaged_phase(red_groups, blue_groups)

func _do_staging_phase(red_groups: Array) -> void:
	## Form up: infantry front, archers behind, cavalry on flanks.
	## Use ATTACK so units fight back while forming up.
	_compute_battle_line_positions(_staging_line_x, red_groups, true)

	# Check if groups are in position (within 80px) or timeout at 5s
	var total_groups := 0
	var in_position := 0
	for g in red_groups:
		if _units.get_group_alive_count(g.id) == 0:
			continue
		total_groups += 1
		var center := _units.get_group_center(g.id)
		var target := Vector2(g.target_x, g.target_y)
		if center.distance_to(target) < 80.0:
			in_position += 1

	if (total_groups > 0 and in_position >= total_groups) or _phase_timer >= 3.0:
		print("AI Army: STAGING -> ADVANCE (%.1fs, %d/%d in position)" % [_phase_timer, in_position, total_groups])
		_army_phase = ArmyPhase.ADVANCE
		_phase_timer = 0.0

func _do_advance_phase(red_groups: Array, blue_groups: Array) -> void:
	## March toward enemy at infantry speed. Transition at 600px from nearest BLUE.
	# Advance the battle line
	_battle_line_x -= _infantry_speed * _advance_speed_mult * STRATEGY_INTERVAL * 60.0  # ~130px per 3s tick

	_compute_battle_line_positions(_battle_line_x, red_groups, true)

	# Check distance to nearest BLUE group
	var front_x := _battle_line_x
	var min_dist := 99999.0
	for bg in blue_groups:
		var bc := _units.get_group_center(bg.id)
		if bc == Vector2.ZERO:
			continue
		var dx := front_x - bc.x
		if dx < 0:
			dx = -dx
		if dx < min_dist:
			min_dist = dx

	if min_dist < 600.0:
		print("AI Army: ADVANCE -> APPROACH (dist=%.0f)" % min_dist)
		_army_phase = ArmyPhase.APPROACH
		_phase_timer = 0.0

func _do_approach_phase(red_groups: Array, blue_groups: Array) -> void:
	## Melee engages, ranged fires, cavalry holds. Transition when 3+ melee in contact or 8s timeout.
	_melee_engaged_count = _count_melee_in_contact()

	if _melee_engaged_count >= 3 or _phase_timer >= 8.0:
		print("AI Army: APPROACH -> ENGAGED (melee_contact=%d, %.1fs)" % [_melee_engaged_count, _phase_timer])
		_army_phase = ArmyPhase.ENGAGED
		_phase_timer = 0.0
		_cavalry_charge_triggered = false

func _do_engaged_phase(red_groups: Array, blue_groups: Array) -> void:
	## Trigger cavalry charge on first tick, then hand off to per-group AI.
	if not _cavalry_charge_triggered:
		_cavalry_charge_triggered = true
		_trigger_cavalry_charge(red_groups, blue_groups)
	# Per-group tactical AI runs normally (no early return from _reassess_strategy)

func _compute_battle_line_positions(line_x: float, red_groups: Array, attack_move: bool = false) -> void:
	## Assign target positions for each group based on role.
	## Melee at line_x, ranged 120px behind (higher X for RED facing left), cavalry ±200px on Y flanks.
	## When attack_move=true (ADVANCE phase), groups use ATTACK so they fight while marching.
	var move_cmd: int = BattleCommander.CommandType.ATTACK if attack_move else BattleCommander.CommandType.MOVE
	var melee_groups: Array = []
	var ranged_groups: Array = []
	var cav_groups: Array = []
	var harass_groups: Array = []  # horse archers

	for g in red_groups:
		if _units.get_group_alive_count(g.id) == 0:
			continue
		if g.unit_type in _MELEE_TYPES:
			melee_groups.append(g)
		elif g.unit_type in _RANGED_TYPES:
			ranged_groups.append(g)
		elif g.unit_type in _CAV_TYPES:
			cav_groups.append(g)
		elif g.unit_type == BattleUnitSystem.UnitType.HORSE_ARCHER:
			harass_groups.append(g)

	# Spread melee groups along Y axis at line_x
	var melee_count := melee_groups.size()
	var spacing := 80.0
	var melee_start_y := _battle_line_y_center - (melee_count - 1) * spacing * 0.5
	for idx in melee_count:
		var g: BattleCommander.BattleGroup = melee_groups[idx]
		g.target_x = line_x
		g.target_y = melee_start_y + idx * spacing
		g.command = move_cmd

	# Ranged groups 120px behind melee line
	var ranged_x := line_x + 120.0  # higher X = further from BLUE (RED faces left)
	var ranged_count := ranged_groups.size()
	var ranged_start_y := _battle_line_y_center - (ranged_count - 1) * spacing * 0.5
	for idx in ranged_count:
		var g: BattleCommander.BattleGroup = ranged_groups[idx]
		g.target_x = ranged_x
		g.target_y = ranged_start_y + idx * spacing
		g.command = move_cmd

	# Cavalry on Y flanks, 200px outside melee spread
	var melee_top_y := melee_start_y - 200.0
	var melee_bot_y := melee_start_y + (melee_count - 1) * spacing + 200.0
	for idx in cav_groups.size():
		var g: BattleCommander.BattleGroup = cav_groups[idx]
		g.target_x = line_x
		if idx % 2 == 0:
			g.target_y = melee_top_y - idx / 2 * spacing
		else:
			g.target_y = melee_bot_y + idx / 2 * spacing
		g.command = move_cmd

	# Horse archers on wide flanks for skirmishing
	for idx in harass_groups.size():
		var g: BattleCommander.BattleGroup = harass_groups[idx]
		g.target_x = line_x - 50.0  # slightly ahead
		if idx % 2 == 0:
			g.target_y = melee_top_y - 100.0 - idx / 2 * spacing
		else:
			g.target_y = melee_bot_y + 100.0 + idx / 2 * spacing
		g.command = move_cmd

func _count_melee_in_contact() -> int:
	## Count RED melee units within 100px of any BLUE unit. Early out at 5.
	var contact := 0
	for i in _units.count:
		if _units.alive[i] == 0 or _units.faction[i] != BattleUnitSystem.Faction.RED:
			continue
		if not (_units.unit_type[i] in _MELEE_TYPES):
			continue
		var nearest := _units.find_nearest_enemy(i, 100.0)
		if nearest >= 0:
			contact += 1
			if contact >= 5:
				return contact
	return contact

func _trigger_cavalry_charge(red_groups: Array, blue_groups: Array) -> void:
	## Order cavalry groups to charge priority targets.
	for g in red_groups:
		if _units.get_group_alive_count(g.id) == 0:
			continue
		if not (g.unit_type in _CAV_TYPES):
			continue
		var center := _units.get_group_center(g.id)

		# Priority 1: exposed ranged
		var ranged_target := _find_exposed_ranged_group(center, blue_groups)
		if ranged_target:
			var tc := _units.get_group_center(ranged_target.id)
			if tc != Vector2.ZERO:
				g.target_x = tc.x
				g.target_y = tc.y
				g.target_group_id = ranged_target.id
				g.charge_state = BattleCommander.ChargeState.CHARGING
				g.charge_timer = 0.0
				g.command = BattleCommander.CommandType.CHARGE
				g.formation_type = BattleUnitSystem.FormationType.WEDGE
				g.withdraw_pos = center + (center - tc).normalized() * 300.0
				print("AI Army: Cavalry charge -> exposed ranged")
				continue

		# Priority 2: engaged flank target
		var flank_target := _find_flank_target(g, center, blue_groups)
		if flank_target:
			var ftc := _units.get_group_center(flank_target.id)
			if ftc != Vector2.ZERO:
				var to_target := (ftc - center).normalized()
				var perp := Vector2(-to_target.y, to_target.x)
				var flank_pos := ftc + perp * 200.0
				g.target_x = flank_pos.x
				g.target_y = flank_pos.y
				g.target_group_id = flank_target.id
				g.charge_state = BattleCommander.ChargeState.CHARGING
				g.charge_timer = 0.0
				g.command = BattleCommander.CommandType.CHARGE
				g.formation_type = BattleUnitSystem.FormationType.WEDGE
				g.withdraw_pos = center + (center - ftc).normalized() * 300.0
				print("AI Army: Cavalry charge -> flank")
				continue

		# Priority 3: weakest group
		var weak_target := _find_weakest_enemy_group(center, blue_groups, 800.0)
		if weak_target:
			var wc := _units.get_group_center(weak_target.id)
			if wc != Vector2.ZERO:
				g.target_x = wc.x
				g.target_y = wc.y
				g.target_group_id = weak_target.id
				g.charge_state = BattleCommander.ChargeState.CHARGING
				g.charge_timer = 0.0
				g.command = BattleCommander.CommandType.CHARGE
				g.formation_type = BattleUnitSystem.FormationType.WEDGE
				g.withdraw_pos = center + (center - wc).normalized() * 300.0
				print("AI Army: Cavalry charge -> weakest group")
				continue

		# Fallback: just attack
		g.command = BattleCommander.CommandType.ATTACK

func _find_friendly_infantry_center(faction: int) -> Vector2:
	## Find the center of friendly infantry groups.
	var groups := _commander.get_faction_groups(faction)
	var center := Vector2.ZERO
	var count := 0
	for g in groups:
		if g.unit_type == BattleUnitSystem.UnitType.INFANTRY or g.unit_type == BattleUnitSystem.UnitType.HEAVY_INFANTRY:
			var gc := _units.get_group_center(g.id)
			if gc != Vector2.ZERO:
				center += gc
				count += 1
	if count == 0:
		return Vector2.ZERO
	return center / float(count)

func _find_weakest_enemy_group(from: Vector2, enemy_groups: Array, max_range: float) -> BattleCommander.BattleGroup:
	## Find the enemy group with the worst strength ratio within range.
	var best: BattleCommander.BattleGroup = null
	var worst_ratio := 1.0
	for eg in enemy_groups:
		var eg_alive := _units.get_group_alive_count(eg.id)
		if eg_alive == 0:
			continue
		var ec := _units.get_group_center(eg.id)
		if ec == Vector2.ZERO or from.distance_to(ec) > max_range:
			continue
		var ratio := 1.0
		if eg.initial_size > 0:
			ratio = float(eg_alive) / float(eg.initial_size)
		if ratio < worst_ratio:
			worst_ratio = ratio
			best = eg
	return best

func _find_nearest_enemy_group_center(from: Vector2, enemy_groups: Array) -> Vector2:
	var best_dist := 99999.0
	var best_center := Vector2.ZERO
	for eg in enemy_groups:
		var ec := _units.get_group_center(eg.id)
		if ec == Vector2.ZERO:
			continue
		var d := from.distance_to(ec)
		if d < best_dist:
			best_dist = d
			best_center = ec
	return best_center

# --- Tactical Helper Functions ---

func _get_group_total_count(g: BattleCommander.BattleGroup) -> int:
	var total := 0
	for i in _units.count:
		if _units.group_id[i] == g.id:
			total += 1
	return total

func _get_local_strength_ratio(g: BattleCommander.BattleGroup, center: Vector2) -> float:
	## Ratio of friendly vs enemy units within 200px of group center. >1 = we're stronger.
	var nearby := _units.get_nearby(center.x, center.y, 200.0)
	var friendly := 0
	var enemy := 0
	for j in nearby:
		if _units.alive[j] == 0:
			continue
		if _units.faction[j] == g.faction:
			friendly += 1
		else:
			enemy += 1
	if enemy == 0:
		return 10.0
	return float(friendly) / float(enemy)

func _count_nearby_type(center: Vector2, search_range: float, faction: int, types: Array) -> int:
	## Count alive units of given faction and types within range
	var nearby := _units.get_nearby(center.x, center.y, search_range)
	var count := 0
	for j in nearby:
		if _units.alive[j] == 0 or _units.faction[j] != faction:
			continue
		if _units.unit_type[j] in types:
			count += 1
	return count

func _find_flank_target(cav_group: BattleCommander.BattleGroup, cav_center: Vector2, enemy_groups: Array) -> BattleCommander.BattleGroup:
	## Find an enemy group currently engaged with friendly infantry (good flank target).
	var friendly_groups := _commander.get_faction_groups(cav_group.faction)
	var best: BattleCommander.BattleGroup = null
	var best_dist := 99999.0
	for eg in enemy_groups:
		if _units.get_group_alive_count(eg.id) == 0:
			continue
		var ec := _units.get_group_center(eg.id)
		if ec == Vector2.ZERO:
			continue
		# Check if any friendly infantry is fighting this group (within 150px)
		var engaged := false
		for fg in friendly_groups:
			if fg.unit_type != BattleUnitSystem.UnitType.INFANTRY and fg.unit_type != BattleUnitSystem.UnitType.HEAVY_INFANTRY and fg.unit_type != BattleUnitSystem.UnitType.SPEAR:
				continue
			if _units.get_group_alive_count(fg.id) == 0:
				continue
			var fc := _units.get_group_center(fg.id)
			if fc.distance_to(ec) < 200.0:
				engaged = true
				break
		if engaged:
			var d := cav_center.distance_to(ec)
			if d < best_dist and d < 600.0:
				best_dist = d
				best = eg
	return best

func _find_exposed_ranged_group(from: Vector2, enemy_groups: Array) -> BattleCommander.BattleGroup:
	## Find an enemy archer/mage/ranged_inf group that isn't screened by infantry/spear
	var best: BattleCommander.BattleGroup = null
	var best_dist := 99999.0
	for eg in enemy_groups:
		if eg.unit_type != BattleUnitSystem.UnitType.ARCHER and eg.unit_type != BattleUnitSystem.UnitType.MAGE and eg.unit_type != BattleUnitSystem.UnitType.RANGED_INFANTRY:
			continue
		if _units.get_group_alive_count(eg.id) == 0:
			continue
		var ec := _units.get_group_center(eg.id)
		# Check if infantry/spear is screening this ranged group
		var has_screen := false
		for fg in enemy_groups:
			if fg.unit_type == BattleUnitSystem.UnitType.INFANTRY or fg.unit_type == BattleUnitSystem.UnitType.HEAVY_INFANTRY or fg.unit_type == BattleUnitSystem.UnitType.SPEAR:
				if _units.get_group_alive_count(fg.id) == 0:
					continue
				var fc := _units.get_group_center(fg.id)
				var to_ranged := ec - from
				var to_infantry := fc - from
				var dot := to_ranged.normalized().dot(to_infantry.normalized())
				if dot > 0.5 and to_infantry.length() < to_ranged.length():
					has_screen = true
					break
		if not has_screen:
			var d := from.distance_to(ec)
			if d < best_dist:
				best_dist = d
				best = eg
	return best

func _is_group_screened_by_infantry(g: BattleCommander.BattleGroup, center: Vector2, enemy_groups: Array) -> bool:
	## Check if friendly infantry is between this group and the nearest enemy
	var nearest_enemy_center := Vector2.ZERO
	var nearest_dist := 99999.0
	for eg in enemy_groups:
		if _units.get_group_alive_count(eg.id) == 0:
			continue
		var ec := _units.get_group_center(eg.id)
		var d := center.distance_to(ec)
		if d < nearest_dist:
			nearest_dist = d
			nearest_enemy_center = ec
	if nearest_enemy_center == Vector2.ZERO:
		return true  # No enemies, consider screened

	# Check if any friendly infantry group is between us and the enemy
	var red_groups := _commander.get_faction_groups(g.faction)
	for fg in red_groups:
		if fg.unit_type != BattleUnitSystem.UnitType.INFANTRY and fg.unit_type != BattleUnitSystem.UnitType.HEAVY_INFANTRY:
			continue
		if _units.get_group_alive_count(fg.id) == 0:
			continue
		var fc := _units.get_group_center(fg.id)
		var to_enemy := nearest_enemy_center - center
		var to_friendly := fc - center
		var dot := to_enemy.normalized().dot(to_friendly.normalized())
		if dot > 0.3 and to_friendly.length() < to_enemy.length():
			return true
	return false

func _update_target(i: int) -> void:
	var target := _units.target_unit[i]

	# If current target is still alive and valid, KEEP it (reduces jittering)
	if target == PLAYER_TARGET_ID:
		if not player_alive:
			_units.target_unit[i] = -1
		else:
			return  # Keep targeting player
	elif target >= 0 and target < _units.count and _units.alive[target] == 1 and _units.faction[target] != _units.faction[i]:
		return  # Current target still alive — stick with it

	# Need a new target — find nearest enemy (simple distance, no expensive LOS every frame)
	var search_range := 500.0
	var nearest_soa := _units.find_nearest_enemy(i, search_range)
	var nearest_soa_dist := 99999.0
	if nearest_soa >= 0:
		var sdx := _units.x[nearest_soa] - _units.x[i]
		var sdy := _units.y[nearest_soa] - _units.y[i]
		nearest_soa_dist = sqrt(sdx * sdx + sdy * sdy)

	# RED units also consider the player
	var player_dist := 99999.0
	if _units.faction[i] == BattleUnitSystem.Faction.RED and player_alive:
		var pdx := player_position.x - _units.x[i]
		var pdy := player_position.y - _units.y[i]
		player_dist = sqrt(pdx * pdx + pdy * pdy)

	# Pick the closest target
	if nearest_soa >= 0 and nearest_soa_dist <= player_dist:
		_units.target_unit[i] = nearest_soa
	elif player_dist < PLAYER_ENGAGE_RANGE:
		_units.target_unit[i] = PLAYER_TARGET_ID
	elif nearest_soa >= 0:
		_units.target_unit[i] = nearest_soa
	else:
		_units.target_unit[i] = _units.find_nearest_enemy(i, 5000.0)

func _get_unit_destination(i: int) -> Vector2:
	## Get where this unit should be heading based on command + target.
	var gid := _units.group_id[i]
	if gid >= 0 and _commander:
		var grp = _commander.get_group(gid)
		if grp and grp.command == BattleCommander.CommandType.MOVE:
			return Vector2(grp.target_x, grp.target_y)
	var target_idx := _units.target_unit[i]
	if target_idx == PLAYER_TARGET_ID:
		return player_position
	elif target_idx >= 0 and target_idx < _units.count and _units.alive[target_idx] == 1:
		return Vector2(_units.x[target_idx], _units.y[target_idx])
	# Use faction objective
	if _units.faction[i] == BattleUnitSystem.Faction.RED:
		return red_objective
	return blue_objective

func force_initial_paths() -> void:
	## Compute flow fields at battle start (replaces old per-unit A*).
	compute_initial_flow_fields()

func clear_paths_for_group(_group_id: int) -> void:
	## Flow fields are global, no per-group paths to clear.
	pass

func _recompute_flow_fields() -> void:
	## Recompute flow fields toward objectives.
	## RED flows toward red_objective (player spawn area), BLUE toward blue_objective (enemy spawn).
	## These are used ONLY for advancing/marching — combat targeting uses direct movement.
	if not _flow:
		return
	if red_objective != Vector2.ZERO:
		_flow.compute_field("red_obj", red_objective)
	if blue_objective != Vector2.ZERO:
		_flow.compute_field("blue_obj", blue_objective)
	# Flow toward player for RED units that target player
	if player_alive and player_position != Vector2.ZERO:
		_flow.compute_field("player", player_position)

func _get_flow_field_for_unit(i: int) -> String:
	## Determine which flow field this unit should follow.
	var target_idx := _units.target_unit[i]
	if target_idx == PLAYER_TARGET_ID and _flow.has_field("player"):
		return "player"
	if _units.faction[i] == BattleUnitSystem.Faction.RED:
		return "red_obj"
	return "blue_obj"

func _do_movement(i: int, dt: float) -> void:
	## Move toward combat target — direct movement, NO flow field (fight, don't march past)
	var target := _units.target_unit[i]
	if target < 0 or target >= _units.count:
		return
	_do_movement_toward_pos(i, Vector2(_units.x[target], _units.y[target]), dt, false, false)

func _do_movement_toward_pos(i: int, target_pos: Vector2, dt: float, force_move: bool = false, use_flow: bool = true) -> void:
	var dx := target_pos.x - _units.x[i]
	var dy := target_pos.y - _units.y[i]
	var dist := sqrt(dx * dx + dy * dy)
	if dist < 4.0:
		return

	var nx := dx / dist
	var ny := dy / dist

	# Flow field navigation — ONLY for AI auto-advance (not player commands).
	# Player commands have a specific target_pos that is NOT the objective,
	# so the flow field (which points to objectives) would override the player's command.
	# Use flow field only when the unit is advancing toward its faction objective autonomously.
	var is_player_command := false
	var grp_id := _units.group_id[i]
	if grp_id >= 0 and _commander:
		var grp = _commander.get_group(grp_id)
		if grp and _units.faction[i] == BattleUnitSystem.Faction.BLUE:
			# BLUE units with explicit target position = player gave a command
			if grp.target_x != 0.0 or grp.target_y != 0.0:
				is_player_command = true

	if use_flow and not is_player_command and _flow and _flow.is_valid() and dist > 80.0:
		var field_name := _get_flow_field_for_unit(i)
		var flow_dir := _flow.get_flow_direction(field_name, _units.x[i], _units.y[i])
		if flow_dir != Vector2.ZERO:
			# Blend flow field (wall-aware pathfinding) with direct heading
			nx = flow_dir.x * 0.7 + nx * 0.3
			ny = flow_dir.y * 0.7 + ny * 0.3
			var len := sqrt(nx * nx + ny * ny)
			if len > 0.01:
				nx /= len
				ny /= len
	# Local avoidance — steer around immediate walls
	if _flow and _flow.is_valid():
		var move_dir := Vector2(nx, ny)
		var avoid_dir := _flow.get_avoidance_dir(_units.x[i], _units.y[i], move_dir, 48.0)
		nx = avoid_dir.x
		ny = avoid_dir.y

	var t := _units.unit_type[i]
	var acc: float = _units.acceleration[i]
	var spd: float = _units.max_speed[i]

	if grp_id >= 0:
		var group := _commander.get_group(grp_id)
		if group:
			var mods: Dictionary = BattleUnitSystem.FORMATION_MODS[group.formation_type]
			spd *= mods["speed_mult"]

	if _units.post_charge_bogged_time[i] > 0.0:
		acc *= 0.3
		spd *= 0.4  # Cavalry stuck in melee after charge — much slower

	# Morale tier speed effects
	var unit_morale := _units.morale[i]
	if unit_morale >= 80.0:
		spd *= 1.1   # Inspired: +10% speed
	elif unit_morale < 15.0:
		spd *= 0.6   # Broken: -40% speed (fleeing)
	elif unit_morale < 30.0:
		spd *= 0.85  # Shaken: -15% speed
	elif unit_morale < 50.0:
		spd *= 0.95  # Wavering: -5% speed

	# Commander debuff: -15% speed
	if _units.commander_debuff_timer[i] > 0.0:
		spd *= 0.85

	var move_x := nx
	var move_y := ny
	# Only apply range-keeping if NOT force_move (i.e. not a MOVE command)
	if not force_move:
		var pref_range: float = BattleUnitSystem.UNIT_STATS["preferred_range"][t]
		var is_ranged := t == BattleUnitSystem.UnitType.ARCHER or t == BattleUnitSystem.UnitType.MAGE or t == BattleUnitSystem.UnitType.HORSE_ARCHER or t == BattleUnitSystem.UnitType.RANGED_INFANTRY
		if is_ranged:
			var min_safe: float = BattleUnitSystem.UNIT_STATS["min_safe_distance"][t]
			if dist < min_safe:
				move_x = -nx
				move_y = -ny
				# Horse Archer kiting: faster retreat when ability active
				if t == BattleUnitSystem.UnitType.HORSE_ARCHER and _units.ability_active[i] == 1:
					acc *= 1.0  # Full acceleration while Parthian Shot active
				else:
					acc *= 0.5
			elif dist < pref_range:
				move_x = 0.0
				move_y = 0.0
		elif dist < pref_range * 0.5:
			move_x *= 0.3
			move_y *= 0.3

	_units.vx[i] += move_x * acc * dt * 60.0
	_units.vy[i] += move_y * acc * dt * 60.0

	var cur_speed := sqrt(_units.vx[i] * _units.vx[i] + _units.vy[i] * _units.vy[i])
	if cur_speed > spd:
		var s := spd / cur_speed
		_units.vx[i] *= s
		_units.vy[i] *= s

	_units.facing[i] = atan2(ny, nx)

func _do_attack(i: int) -> void:
	var target := _units.target_unit[i]
	if target < 0 or target >= _units.count:
		return

	var dx := _units.x[target] - _units.x[i]
	var dy := _units.y[target] - _units.y[i]
	var dist := sqrt(dx * dx + dy * dy)
	var t := _units.unit_type[i]
	var atk_range: float = BattleUnitSystem.UNIT_STATS["attack_range"][t]

	if dist > atk_range:
		return

	# Line-of-sight check — don't attack through walls (but keep moving toward target)
	if _flow and not _flow.has_line_of_sight(_units.x[i], _units.y[i], _units.x[target], _units.y[target]):
		return  # Can't shoot but keep pursuing — A* will go around

	# Morale tier attack cooldown modifier
	var cooldown: float = BattleUnitSystem.UNIT_STATS["attack_cooldown"][t]
	var atk_morale := _units.morale[i]
	if atk_morale < 15.0:
		return  # Broken: won't fight
	elif atk_morale < 30.0:
		cooldown *= 1.25  # Shaken: -25% attack speed
	elif atk_morale < 50.0:
		cooldown *= 1.10  # Wavering: -10% attack speed
	# Commander debuff: slower attacks
	if _units.commander_debuff_timer[i] > 0.0:
		cooldown *= 1.15
	# LINE formation bonus: +20% attack speed when properly spaced
	var gid := _units.group_id[i]
	if gid >= 0 and _commander:
		var grp = _commander.get_group(gid)
		if grp and grp.formation_type == BattleUnitSystem.FormationType.LINE and _units.formation_bonus_active[i] == 1:
			cooldown *= 0.8

	if _battle_time - _units.last_attack_time[i] < cooldown:
		return

	_units.last_attack_time[i] = _battle_time

	var nx := dx / maxf(dist, 0.01)
	var ny := dy / maxf(dist, 0.01)
	var bullet_spd: float = BattleUnitSystem.UNIT_STATS["bullet_speed"][t]
	var bullet_dmg: float = BattleUnitSystem.UNIT_STATS["attack_damage"][t]
	var bullet_mass: float = BattleUnitSystem.UNIT_STATS["bullet_mass"][t]

	# Morale tier damage modifier
	if atk_morale >= 80.0:
		bullet_dmg *= 1.1  # Inspired: +10% damage

	# Commander aura: +10% damage, or +20% if IS the commander
	if _units.is_commander[i] == 1:
		bullet_dmg *= 1.2
	else:
		var nearby_cmdr := _units.get_nearby(_units.x[i], _units.y[i], 150.0)
		for ci in nearby_cmdr:
			if ci != i and _units.alive[ci] == 1 and _units.faction[ci] == _units.faction[i] and _units.is_commander[ci] == 1:
				bullet_dmg *= 1.1
				break

	if t == BattleUnitSystem.UnitType.CAVALRY or t == BattleUnitSystem.UnitType.HEAVY_CAVALRY:
		var speed := sqrt(_units.vx[i] * _units.vx[i] + _units.vy[i] * _units.vy[i])
		var speed_ratio := speed / maxf(0.01, _units.max_speed[i])
		if speed_ratio > 0.4:
			var charge_mult: float = BattleUnitSystem.UNIT_STATS["charge_bonus"][t]
			# Lance Charge ability: 1.5x charge bonus
			if _units.ability_active[i] == 1 and t == BattleUnitSystem.UnitType.CAVALRY:
				charge_mult *= 1.5
			# Momentum bonus: charging >2s = +40% damage on first hit
			if _units.charge_time[i] > 2.0:
				charge_mult *= 1.4
				_units.charge_time[i] = 0.0  # Reset after momentum hit
			bullet_dmg *= charge_mult * speed_ratio

	_projectiles.spawn(
		_units.x[i], _units.y[i],
		nx * bullet_spd, ny * bullet_spd,
		bullet_dmg, bullet_mass,
		_units.faction[i], t, _units.group_formation[i]
	)

func _do_attack_player(i: int) -> void:
	## RED unit fires at the player character
	if not player_alive:
		return
	var dx := player_position.x - _units.x[i]
	var dy := player_position.y - _units.y[i]
	var dist := sqrt(dx * dx + dy * dy)
	var t := _units.unit_type[i]
	var atk_range: float = BattleUnitSystem.UNIT_STATS["attack_range"][t]

	if dist > atk_range:
		return

	# Line-of-sight check — don't shoot through walls (but keep pursuing)
	if _flow and not _flow.has_line_of_sight(_units.x[i], _units.y[i], player_position.x, player_position.y):
		return  # Can't shoot but keep pursuing

	var cooldown: float = BattleUnitSystem.UNIT_STATS["attack_cooldown"][t]
	if _battle_time - _units.last_attack_time[i] < cooldown:
		return

	_units.last_attack_time[i] = _battle_time

	var nx := dx / maxf(dist, 0.01)
	var ny := dy / maxf(dist, 0.01)
	var bullet_spd: float = BattleUnitSystem.UNIT_STATS["bullet_speed"][t]
	var bullet_dmg: float = BattleUnitSystem.UNIT_STATS["attack_damage"][t]
	var bullet_mass: float = BattleUnitSystem.UNIT_STATS["bullet_mass"][t]

	_projectiles.spawn(
		_units.x[i], _units.y[i],
		nx * bullet_spd, ny * bullet_spd,
		bullet_dmg, bullet_mass,
		_units.faction[i], t, _units.group_formation[i]
	)

func _do_flow_move(i: int, dest: Vector2, dt: float) -> void:
	## Move toward destination with local obstacle avoidance
	_do_movement_toward_pos(i, dest, dt)
	# Still attack enemies in range while moving
	_update_target(i)
	if _units.target_unit[i] == PLAYER_TARGET_ID:
		_do_attack_player(i)
	else:
		_do_attack(i)

func _do_advance(i: int, dt: float) -> void:
	# No target found — advance toward faction objective using A* path
	var objective: Vector2
	if _units.faction[i] == BattleUnitSystem.Faction.RED:
		objective = red_objective
	else:
		objective = blue_objective
	if objective == Vector2.ZERO:
		return

	var dx := objective.x - _units.x[i]
	var dy := objective.y - _units.y[i]
	var dist := sqrt(dx * dx + dy * dy)
	if dist < 100.0:
		return

	# Use A* path — _do_movement_toward_pos handles waypoint following
	_do_movement_toward_pos(i, objective, dt)
	# Override speed to advance speed
	var spd: float = _units.max_speed[i] * _advance_speed_mult
	var cur_speed := sqrt(_units.vx[i] * _units.vx[i] + _units.vy[i] * _units.vy[i])
	if cur_speed > spd:
		var s := spd / cur_speed
		_units.vx[i] *= s
		_units.vy[i] *= s
	# Attack any enemy in range while advancing
	if _units.target_unit[i] == PLAYER_TARGET_ID:
		_do_attack_player(i)
	else:
		_do_attack(i)

func _do_rout_retreat(i: int, dt: float) -> void:
	## Controlled retreat — move away from nearest enemy
	var nearest := _units.find_nearest_enemy(i, 300.0)
	if nearest >= 0:
		var dx := _units.x[i] - _units.x[nearest]
		var dy := _units.y[i] - _units.y[nearest]
		var dist := sqrt(dx * dx + dy * dy)
		if dist > 0.1:
			var nx := dx / dist
			var ny := dy / dist
			if _flow and _flow.is_valid():
				var avoid_dir := _flow.get_avoidance_dir(_units.x[i], _units.y[i], Vector2(nx, ny), 48.0)
				nx = avoid_dir.x
				ny = avoid_dir.y
			_units.vx[i] += nx * _units.acceleration[i] * dt * 60.0
			_units.vy[i] += ny * _units.acceleration[i] * dt * 60.0
	var spd := _units.max_speed[i] * 0.8
	var cur := sqrt(_units.vx[i] * _units.vx[i] + _units.vy[i] * _units.vy[i])
	if cur > spd:
		var s := spd / cur
		_units.vx[i] *= s
		_units.vy[i] *= s

func _do_rout(i: int, dt: float) -> void:
	var flee_dir := -1.0 if _units.faction[i] == BattleUnitSystem.Faction.BLUE else 1.0
	var scatter_y := (randf() - 0.5) * 0.5
	_units.vx[i] += flee_dir * _units.acceleration[i] * 1.5 * dt * 60.0
	_units.vy[i] += scatter_y * _units.acceleration[i] * dt * 60.0
	var spd := _units.max_speed[i]
	var cur := sqrt(_units.vx[i] * _units.vx[i] + _units.vy[i] * _units.vy[i])
	if cur > spd:
		var s := spd / cur
		_units.vx[i] *= s
		_units.vy[i] *= s
	_units.facing[i] = atan2(_units.vy[i], _units.vx[i])

var _group_prev_alive: Dictionary = {}  # group_id -> last known alive count
var _group_routed: Dictionary = {}  # group_id -> true if group has routed

func _update_morale() -> void:
	# --- Group-level morale cascades ---
	for g in _commander.get_all_groups():
		var alive_count := _units.get_group_alive_count(g.id)
		var prev_alive: int = _group_prev_alive.get(g.id, alive_count)
		_group_prev_alive[g.id] = alive_count

		if g.initial_size == 0:
			g.initial_size = _get_group_total_count(g)

		# Group lost >50% total — morale cascade to nearby friendly groups
		if g.initial_size > 0 and alive_count < g.initial_size * 0.5:
			if not _group_routed.get(g.id, false):
				var center := _units.get_group_center(g.id)
				if center != Vector2.ZERO:
					_apply_morale_cascade(center, g.faction, -10.0, 200.0, g.id)

		# Group fully routed (all below threshold) — bigger cascade
		var all_routed := true
		if alive_count > 0:
			for i in _units.count:
				if _units.group_id[i] == g.id and _units.alive[i] == 1:
					if _units.morale[i] >= MORALE_ROUT_THRESHOLD:
						all_routed = false
						break
		else:
			all_routed = false

		if all_routed and not _group_routed.get(g.id, false):
			_group_routed[g.id] = true
			var center := _units.get_group_center(g.id)
			if center != Vector2.ZERO:
				_apply_morale_cascade(center, g.faction, -15.0, 200.0, g.id)

	# --- Per-unit morale recovery ---
	for i in _units.count:
		if _units.alive[i] == 0:
			continue
		var nearest := _units.find_nearest_enemy(i, 200.0)
		var recovery := 0.0
		if nearest < 0:
			recovery = 1.0
		else:
			var dx := _units.x[nearest] - _units.x[i]
			var dy := _units.y[nearest] - _units.y[i]
			var dist := sqrt(dx * dx + dy * dy)
			if dist > 150.0:
				recovery = 0.3
			elif dist > 80.0:
				recovery = 0.1
		if _units.neighbor_count[i] > 3:
			recovery += 0.2
		if _units.morale[i] < MORALE_ROUT_THRESHOLD and nearest >= 0:
			var dx2 := _units.x[nearest] - _units.x[i]
			var dy2 := _units.y[nearest] - _units.y[i]
			if sqrt(dx2 * dx2 + dy2 * dy2) > 200.0:
				recovery += 0.5
		_units.morale[i] = minf(100.0, _units.morale[i] + recovery)

func _apply_morale_cascade(center: Vector2, faction: int, amount: float, radius: float, exclude_group: int) -> void:
	## Apply morale change to all units of same faction within radius, excluding the source group
	var nearby := _units.get_nearby(center.x, center.y, radius)
	for j in nearby:
		if _units.alive[j] == 0 or _units.faction[j] != faction:
			continue
		if _units.group_id[j] == exclude_group:
			continue
		_units.morale[j] = clampf(_units.morale[j] + amount, 0.0, 100.0)

func apply_charge_morale_damage(cx: float, cy: float, target_faction: int, radius: float = 100.0, amount: float = -25.0) -> void:
	## Called externally when cavalry charges — larger radius, devastating morale hit
	var nearby := _units.get_nearby(cx, cy, radius)
	for j in nearby:
		if _units.alive[j] == 0 or _units.faction[j] != target_faction:
			continue
		_units.morale[j] = clampf(_units.morale[j] + amount, 0.0, 100.0)

func _has_los_to_unit(i: int, j: int) -> bool:
	if not _flow:
		return true
	return _flow.has_line_of_sight(_units.x[i], _units.y[i], _units.x[j], _units.y[j])

func _find_nearest_enemy_with_los(i: int, search_range: float) -> int:
	## Like find_nearest_enemy but filters out targets behind walls
	var nearby := _units.get_nearby(_units.x[i], _units.y[i], search_range)
	var best_dist := search_range * search_range
	var best_idx := -1
	var my_fac := _units.faction[i]
	for j in nearby:
		if j == i or _units.alive[j] == 0 or _units.faction[j] == my_fac:
			continue
		var dx := _units.x[j] - _units.x[i]
		var dy := _units.y[j] - _units.y[i]
		var dist_sq := dx * dx + dy * dy
		if dist_sq < best_dist:
			if _has_los_to_unit(i, j):
				best_dist = dist_sq
				best_idx = j
	return best_idx
