class_name BattleCollision
extends RefCounted

const ITERATIONS := 1
const MIN_DIST_SQ := 0.0001
const TILE_SIZE := 32

func resolve(units: BattleUnitSystem, _dt: float, blocked_tiles: Dictionary = {}) -> void:
	for iteration in ITERATIONS:
		for i in units.count:
			if units.alive[i] == 0:
				continue
			var search_r := units.radius[i] * 2.5
			var nearby := units.get_nearby(units.x[i], units.y[i], search_r)
			for j in nearby:
				if j <= i or units.alive[j] == 0:
					continue
				var dx := units.x[j] - units.x[i]
				var dy := units.y[j] - units.y[i]
				var dist_sq := dx * dx + dy * dy
				var min_dist := units.radius[i] + units.radius[j]
				if dist_sq >= min_dist * min_dist or dist_sq < MIN_DIST_SQ:
					continue

				var dist := sqrt(dist_sq)
				var nx := dx / dist
				var ny := dy / dist
				var overlap := min_dist - dist

				var same_faction := units.faction[i] == units.faction[j]

				if same_faction:
					# Soft separation only — no velocity response, no blocking behaviors
					var total_mass := units.mass[i] + units.mass[j]
					var ratio_i := units.mass[j] / total_mass
					var ratio_j := units.mass[i] / total_mass
					var sep := overlap * 0.35
					units.x[i] -= nx * sep * ratio_i
					units.y[i] -= ny * sep * ratio_i
					units.x[j] += nx * sep * ratio_j
					units.y[j] += ny * sep * ratio_j
					continue

				# Enemy collision — infantry in groups resist knockback more
				var kb1 := 1.0 - _effective_kb_resist(units, i)
				var kb2 := 1.0 - _effective_kb_resist(units, j)

				# Momentum impact damage (first iteration only)
				if iteration == 0:
					_apply_impact_damage(units, i, j, nx, ny)
					_apply_charge_impact(units, i, j, nx, ny)
					_apply_charge_impact(units, j, i, -nx, -ny)

				# Mass-based separation
				var total_mass := units.mass[i] + units.mass[j]
				var ratio_i := units.mass[j] / total_mass
				var ratio_j := units.mass[i] / total_mass

				var sep := overlap * 0.95

				# Save positions before separation
				var prev_ix := units.x[i]
				var prev_iy := units.y[i]
				var prev_jx := units.x[j]
				var prev_jy := units.y[j]

				units.x[i] -= nx * sep * ratio_i * kb1
				units.y[i] -= ny * sep * ratio_i * kb1
				units.x[j] += nx * sep * ratio_j * kb2
				units.y[j] += ny * sep * ratio_j * kb2

				# Terrain check: revert if pushed into blocked tile
				if not blocked_tiles.is_empty():
					if _is_in_blocked(units.x[i], units.y[i], units.radius[i], blocked_tiles):
						units.x[i] = prev_ix
						units.y[i] = prev_iy
					if _is_in_blocked(units.x[j], units.y[j], units.radius[j], blocked_tiles):
						units.x[j] = prev_jx
						units.y[j] = prev_jy

				# Velocity response (only first iteration)
				if iteration == 0:
					var approach := (units.vx[i] - units.vx[j]) * nx + (units.vy[i] - units.vy[j]) * ny
					if approach > 0:
						var impulse := approach * 0.5
						units.vx[i] -= nx * impulse * ratio_i * kb1
						units.vy[i] -= ny * impulse * ratio_i * kb1
						units.vx[j] += nx * impulse * ratio_j * kb2
						units.vy[j] += ny * impulse * ratio_j * kb2

				# Hard clamp bogged cavalry velocity — prevent coasting through formations
				for idx in [i, j]:
					if units.post_charge_bogged_time[idx] > 0.0:
						var bogged_max := units.max_speed[idx] * 0.3
						var spd := sqrt(units.vx[idx] * units.vx[idx] + units.vy[idx] * units.vy[idx])
						if spd > bogged_max:
							var s := bogged_max / spd
							units.vx[idx] *= s
							units.vy[idx] *= s

func _apply_impact_damage(units: BattleUnitSystem, i: int, j: int, nx: float, ny: float) -> void:
	var approach := (units.vx[i] - units.vx[j]) * nx + (units.vy[i] - units.vy[j]) * ny
	if approach <= 0.2:
		return
	var impact_scale := minf(1.5, approach / 3.0)
	# i damages j
	var base_impact_i: float = float(BattleUnitSystem.UNIT_STATS["attack_damage"][units.unit_type[i]]) * 0.25
	var kb_j := 1.0 - units.knockback_resist[j]
	var dmg_to_j: float = base_impact_i * impact_scale * maxf(0.2, kb_j)
	if dmg_to_j > 0.5:
		units.damage(j, dmg_to_j, atan2(ny, nx), false, 0.0, 0.0, units.unit_type[i])
	# j damages i
	var base_impact_j: float = float(BattleUnitSystem.UNIT_STATS["attack_damage"][units.unit_type[j]]) * 0.25
	var kb_i := 1.0 - units.knockback_resist[i]
	var dmg_to_i: float = base_impact_j * impact_scale * maxf(0.2, kb_i)
	if dmg_to_i > 0.5:
		units.damage(i, dmg_to_i, atan2(-ny, -nx), false, 0.0, 0.0, units.unit_type[j])

func _apply_charge_impact(units: BattleUnitSystem, charger: int, target: int, nx: float, ny: float) -> void:
	var t := units.unit_type[charger]
	if not _is_cavalry(t):
		return
	# Only apply charge damage ONCE — skip if already in post-charge state
	if units.charge_impact_time[charger] > 0.0 or units.post_charge_bogged_time[charger] > 0.0:
		return
	var speed := sqrt(units.vx[charger] * units.vx[charger] + units.vy[charger] * units.vy[charger])
	var speed_ratio := speed / maxf(0.01, units.max_speed[charger])
	if speed_ratio < 0.5:
		return  # Not moving fast enough to charge

	var charge_kb: float = BattleUnitSystem.UNIT_STATS["charge_knockback"][t]
	var kb_target := 1.0 - _effective_kb_resist(units, target)
	var knockback := charge_kb * speed_ratio * kb_target

	if knockback > 0.15:
		# Apply knockback velocity to target
		units.vx[target] += nx * knockback
		units.vy[target] += ny * knockback
		# Charge damage (one-time)
		var charge_bonus: float = BattleUnitSystem.UNIT_STATS["charge_bonus"][t]
		var charge_dmg: float = float(BattleUnitSystem.UNIT_STATS["attack_damage"][t]) * charge_bonus * speed_ratio
		# Anti-cavalry defense — infantry types resist charges
		var target_type := units.unit_type[target]
		if target_type == BattleUnitSystem.UnitType.HEAVY_INFANTRY:
			var anti_cav: float = BattleUnitSystem.UNIT_STATS["anti_cav_bonus"][target_type]
			if units.ability_active[target] == 1:
				anti_cav *= 2.0
			charge_dmg /= anti_cav
		elif target_type == BattleUnitSystem.UnitType.INFANTRY:
			var anti_cav: float = BattleUnitSystem.UNIT_STATS["anti_cav_bonus"][target_type]
			if units.ability_active[target] == 1:
				anti_cav *= 1.5
			if units.neighbor_count[target] >= 3:
				anti_cav *= 1.0 + float(mini(units.neighbor_count[target], 8)) * 0.1
			charge_dmg /= anti_cav
		elif target_type == BattleUnitSystem.UnitType.SPEAR:
			# Spear infantry: THE anti-cavalry unit
			var anti_cav: float = BattleUnitSystem.UNIT_STATS["anti_cav_bonus"][target_type]
			if units.ability_active[target] == 1:
				# SPEAR_BRACE: multiplier + reflected damage + stun charger
				anti_cav *= 2.0
				# Heavy cavalry resists reflect (armored charge)
				var reflect_pct := 0.25 if t == BattleUnitSystem.UnitType.HEAVY_CAVALRY else 0.40
				var reflect_dmg := charge_dmg * reflect_pct
				units.damage(charger, reflect_dmg, atan2(-ny, -nx), false, 0.0, 0.0, target_type)
				var stun_time := 0.4 if t == BattleUnitSystem.UnitType.HEAVY_CAVALRY else 0.6
				units.stagger_time[charger] = stun_time
			if units.neighbor_count[target] >= 2:
				anti_cav *= 1.0 + float(mini(units.neighbor_count[target], 6)) * 0.10
			charge_dmg /= anti_cav
		units.damage(target, charge_dmg, atan2(ny, nx), false, 0.0, 0.0, t)
		units.stagger_time[target] = maxf(units.stagger_time[target], 0.2 * kb_target)

		# Charger slows on impact — cavalry commits to melee
		# Heavy cavalry retains more momentum (armored charge breaks through)
		var vel_retain := 0.20 if t == BattleUnitSystem.UnitType.HEAVY_CAVALRY else 0.08
		units.vx[charger] *= vel_retain
		units.vy[charger] *= vel_retain
		units.charge_impact_time[charger] = 0.5
		var bog_time := 1.5 if t == BattleUnitSystem.UnitType.HEAVY_CAVALRY else 2.0
		units.post_charge_bogged_time[charger] = bog_time

		# Trample AoE — only with active ability, smaller and weaker
		if units.ability_active[charger] == 1:
			var trample_r := 30.0 if t == BattleUnitSystem.UnitType.CAVALRY else 40.0
			var trample_mult := 0.25
			var trample_targets := units.get_nearby(units.x[charger], units.y[charger], trample_r)
			for k in trample_targets:
				if k == charger or k == target or units.alive[k] == 0:
					continue
				if units.faction[k] == units.faction[charger]:
					continue
				var tdx := units.x[k] - units.x[charger]
				var tdy := units.y[k] - units.y[charger]
				var tdist := sqrt(tdx * tdx + tdy * tdy)
				if tdist > trample_r:
					continue
				units.damage(k, charge_dmg * trample_mult, atan2(tdy, tdx), false, 0.0, 0.0, t)

		# Trigger FEAR PULSE — cavalry charge scatters weak infantry nearby
		_trigger_fear_pulse(units, charger, units.x[target], units.y[target])

func _is_in_blocked(px: float, py: float, radius: float, blocked_tiles: Dictionary) -> bool:
	## Check if position overlaps any blocked tile (center + 4 edge + 4 diagonal offsets)
	var half_r := radius * 0.5
	for off in [Vector2(0, 0), Vector2(half_r, 0), Vector2(-half_r, 0), Vector2(0, half_r), Vector2(0, -half_r),
				Vector2(half_r, half_r), Vector2(-half_r, half_r), Vector2(half_r, -half_r), Vector2(-half_r, -half_r)]:
		var tx := int(floor((px + off.x) / TILE_SIZE))
		var ty := int(floor((py + off.y) / TILE_SIZE))
		if blocked_tiles.has(Vector2i(tx, ty)):
			return true
	return false

func _effective_kb_resist(units: BattleUnitSystem, i: int) -> float:
	## Infantry/heavy_inf/spear in groups get massive knockback resist — they brace together.
	var base := units.knockback_resist[i]
	var t := units.unit_type[i]
	if t == BattleUnitSystem.UnitType.INFANTRY:
		var group_bonus := minf(0.64, float(units.neighbor_count[i]) * 0.08)
		if units.ability_active[i] == 1:
			group_bonus += 0.25
		base = minf(0.98, base + group_bonus)
	elif t == BattleUnitSystem.UnitType.HEAVY_INFANTRY:
		var group_bonus := minf(0.06, float(units.neighbor_count[i]) * 0.015)
		if units.ability_active[i] == 1:
			group_bonus += 0.04
		base = minf(0.99, base + group_bonus)
	elif t == BattleUnitSystem.UnitType.SPEAR:
		var group_bonus := minf(0.50, float(units.neighbor_count[i]) * 0.07)
		if units.ability_active[i] == 1:
			group_bonus += 0.20
		base = minf(0.97, base + group_bonus)
	return base

func _trigger_fear_pulse(units: BattleUnitSystem, charger: int, impact_x: float, impact_y: float) -> void:
	## Cavalry charge creates a fear pulse that can scatter weak infantry nearby.
	var nearby := units.get_nearby(impact_x, impact_y, 120.0)
	var charger_fac := units.faction[charger]
	var group_counts: Dictionary = {}  # group_id -> {total, scattered}

	for j in nearby:
		if units.alive[j] == 0 or units.faction[j] == charger_fac:
			continue
		if units.scatter_time[j] > 0.0:
			continue  # Already scattered
		var jt := units.unit_type[j]
		# Spear infantry: IMMUNE to cavalry fear (trained to face charges)
		if jt == BattleUnitSystem.UnitType.SPEAR:
			continue
		# Only affects infantry-class units (not cavalry/ranged)
		if not _is_infantry(jt):
			continue

		# Fear resistance calculation
		var resist := 0.50
		resist += minf(0.40, float(units.neighbor_count[j]) * 0.05)
		if units.ability_active[j] == 1:
			resist += 0.20
		# Commander nearby?
		var cmdr_nearby := units.get_nearby(units.x[j], units.y[j], 150.0)
		for k in cmdr_nearby:
			if k != j and units.alive[k] == 1 and units.faction[k] == units.faction[j] and units.is_commander[k] == 1:
				resist += 0.15
				break
		# Veteran rank bonus
		resist += float(mini(units.veteran_rank[j], 3)) * 0.10
		# Morale penalties
		if units.morale[j] < 30.0:
			resist -= 0.40
		elif units.morale[j] < 50.0:
			resist -= 0.20
		# Strong formation immunity: 5+ neighbors AND ability active
		if units.neighbor_count[j] >= 5 and units.ability_active[j] == 1:
			continue

		# Roll fear check
		if randf() < resist:
			continue  # Resisted

		# SCATTERED!
		units.scatter_time[j] = randf_range(2.0, 3.0)
		units.saved_group_id[j] = units.group_id[j]
		units.group_id[j] = -1
		var flee_angle := randf() * TAU
		units.scatter_dir_x[j] = cos(flee_angle)
		units.scatter_dir_y[j] = sin(flee_angle)

		# Track for group morale cascade
		var gid := units.saved_group_id[j]
		if gid >= 0:
			if not group_counts.has(gid):
				group_counts[gid] = {"total": 0, "scattered": 0}
			group_counts[gid]["scattered"] += 1

	# Count group totals for cascade check
	for j in nearby:
		if units.alive[j] == 0 or units.faction[j] == charger_fac:
			continue
		var gid := units.group_id[j]
		if gid < 0:
			gid = units.saved_group_id[j]
		if gid >= 0 and group_counts.has(gid):
			group_counts[gid]["total"] += 1

	# If 30%+ of a group scattered, remaining get -15 morale
	for gid in group_counts:
		var data: Dictionary = group_counts[gid]
		if data["total"] > 0 and float(data["scattered"]) / float(data["total"]) >= 0.3:
			for j in nearby:
				if units.alive[j] == 0 or units.faction[j] == charger_fac:
					continue
				if (units.group_id[j] == gid or units.saved_group_id[j] == gid) and units.scatter_time[j] <= 0.0:
					units.morale[j] = maxf(0.0, units.morale[j] - 15.0)

func _is_cavalry(t: int) -> bool:
	return t == BattleUnitSystem.UnitType.CAVALRY or t == BattleUnitSystem.UnitType.HEAVY_CAVALRY or t == BattleUnitSystem.UnitType.HORSE_ARCHER

func _is_infantry(t: int) -> bool:
	return t == BattleUnitSystem.UnitType.INFANTRY or t == BattleUnitSystem.UnitType.HEAVY_INFANTRY or t == BattleUnitSystem.UnitType.SPEAR or t == BattleUnitSystem.UnitType.RANGED_INFANTRY
