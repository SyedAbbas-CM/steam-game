class_name BattleProjectileSystem
extends RefCounted

const MAX_PROJECTILES := 5000
const MAX_LIFETIME := 4.0
const HIT_RADIUS := 3.0
const SPLASH_RADIUS := 20.0

var x: PackedFloat32Array
var y: PackedFloat32Array
var vx: PackedFloat32Array
var vy: PackedFloat32Array
var dmg: PackedFloat32Array
var bullet_mass: PackedFloat32Array
var proj_faction: PackedInt32Array
var source_type: PackedInt32Array
var source_formation: PackedInt32Array     # Formation of the unit that fired
var alive: PackedInt32Array
var lifetime: PackedFloat32Array
var is_splash: PackedInt32Array       # 0 or 1
var splash_radius: PackedFloat32Array # 0.0 or 50.0 for fireballs
var is_burning: PackedInt32Array      # applies burn on hit

var count: int = 0

func _init() -> void:
	for arr in [x, y, vx, vy, dmg, bullet_mass, lifetime]:
		arr = PackedFloat32Array()
		arr.resize(MAX_PROJECTILES)
	for arr in [proj_faction, source_type, alive]:
		arr = PackedInt32Array()
		arr.resize(MAX_PROJECTILES)
	# Re-init properly
	x = PackedFloat32Array()
	y = PackedFloat32Array()
	vx = PackedFloat32Array()
	vy = PackedFloat32Array()
	dmg = PackedFloat32Array()
	bullet_mass = PackedFloat32Array()
	lifetime = PackedFloat32Array()
	proj_faction = PackedInt32Array()
	source_type = PackedInt32Array()
	source_formation = PackedInt32Array()
	alive = PackedInt32Array()
	is_splash = PackedInt32Array()
	splash_radius = PackedFloat32Array()
	is_burning = PackedInt32Array()
	x.resize(MAX_PROJECTILES)
	y.resize(MAX_PROJECTILES)
	vx.resize(MAX_PROJECTILES)
	vy.resize(MAX_PROJECTILES)
	dmg.resize(MAX_PROJECTILES)
	bullet_mass.resize(MAX_PROJECTILES)
	lifetime.resize(MAX_PROJECTILES)
	proj_faction.resize(MAX_PROJECTILES)
	source_type.resize(MAX_PROJECTILES)
	source_formation.resize(MAX_PROJECTILES)
	alive.resize(MAX_PROJECTILES)
	is_splash.resize(MAX_PROJECTILES)
	splash_radius.resize(MAX_PROJECTILES)
	is_burning.resize(MAX_PROJECTILES)

func spawn(px: float, py: float, vel_x: float, vel_y: float, damage: float, mass_val: float, fac: int, src_type: int, src_formation: int = -1) -> int:
	# Find a free slot or append
	var i := -1
	for idx in count:
		if alive[idx] == 0:
			i = idx
			break
	if i == -1:
		if count >= MAX_PROJECTILES:
			return -1
		i = count
		count += 1
	x[i] = px
	y[i] = py
	vx[i] = vel_x
	vy[i] = vel_y
	dmg[i] = damage
	bullet_mass[i] = mass_val
	proj_faction[i] = fac
	source_type[i] = src_type
	source_formation[i] = src_formation
	alive[i] = 1
	lifetime[i] = 0.0
	is_splash[i] = 0
	splash_radius[i] = 0.0
	is_burning[i] = 0
	return i

func update(dt: float, units: BattleUnitSystem, world_max_x: float, world_max_y: float, world_min_x: float = 0.0, world_min_y: float = 0.0, blocked_tiles: Dictionary = {}) -> void:
	var tile_size := 32
	for i in count:
		if alive[i] == 0:
			continue
		# Move
		x[i] += vx[i] * dt * 60.0
		y[i] += vy[i] * dt * 60.0
		lifetime[i] += dt

		# Bounds check
		if x[i] < world_min_x or x[i] > world_max_x or y[i] < world_min_y or y[i] > world_max_y or lifetime[i] > MAX_LIFETIME:
			alive[i] = 0
			continue

		# Terrain collision — kill projectile if it hits a blocked tile
		if not blocked_tiles.is_empty():
			var tx := int(floor(x[i] / tile_size))
			var ty := int(floor(y[i] / tile_size))
			if blocked_tiles.has(Vector2i(tx, ty)):
				alive[i] = 0
				continue

		# Collision with enemy units
		var nearby := units.get_nearby(x[i], y[i], 35.0)
		for j in nearby:
			if units.alive[j] == 0 or units.faction[j] == proj_faction[i]:
				continue
			var dx := units.x[j] - x[i]
			var dy := units.y[j] - y[i]
			var dist := sqrt(dx * dx + dy * dy)
			if dist < units.radius[j] + HIT_RADIUS:
				var is_archer := source_type[i] == BattleUnitSystem.UnitType.ARCHER
				var attack_angle := atan2(vy[i], vx[i])

				if is_splash[i] == 1:
					# Splash damage — hit ALL enemies in splash radius
					var splash_r := splash_radius[i]
					var splash_targets := units.get_nearby(x[i], y[i], splash_r)
					for k in splash_targets:
						if units.alive[k] == 0 or units.faction[k] == proj_faction[i]:
							continue
						var sdx := units.x[k] - x[i]
						var sdy := units.y[k] - y[i]
						var sdist := sqrt(sdx * sdx + sdy * sdy)
						if sdist > splash_r:
							continue
						var falloff := 1.0 - (sdist / splash_r) * 0.5  # 50% falloff at edge
						var splash_dmg := dmg[i] * falloff
						var s_angle := atan2(sdy, sdx)
						units.damage(k, splash_dmg, s_angle, false, 0.0, 0.0, source_type[i], source_formation[i])
						# Splash knockback
						if sdist > 0.01:
							var kb := bullet_mass[i] * 1.5 * falloff
							units.vx[k] += (sdx / sdist) * kb * (1.0 - units.knockback_resist[k])
							units.vy[k] += (sdy / sdist) * kb * (1.0 - units.knockback_resist[k])
						units.stagger_time[k] = maxf(units.stagger_time[k], 0.15)
						# Apply burn
						if is_burning[i] == 1 and units.alive[k] == 1:
							units.burn_time[k] = 3.0
							units.burn_dps[k] = 3.0
				else:
					# Single-target hit
					var base_damage := dmg[i]
					var momentum_bonus := bullet_mass[i] * 2.0
					var total_damage := base_damage + momentum_bonus

					# Slow cavalry vulnerability
					var target_speed := sqrt(units.vx[j] * units.vx[j] + units.vy[j] * units.vy[j])
					var t := units.unit_type[j]
					if (t == BattleUnitSystem.UnitType.CAVALRY or t == BattleUnitSystem.UnitType.HEAVY_CAVALRY):
						var speed_ratio := target_speed / maxf(0.01, units.max_speed[j])
						if speed_ratio < 0.4:
							var vuln := 1.0 + (0.4 - speed_ratio) * 1.25
							total_damage *= vuln

					# Volley ability: ignore 50% defense
					if is_archer and units.ability_active[j] == 0:
						# Normal archer shot — no special defense ignore
						pass

					units.damage(j, total_damage, attack_angle, is_archer, 0.0, 0.0, source_type[i], source_formation[i])

					# Archer arrow stagger
					if is_archer and units.alive[j] == 1:
						var stagger_resist: float = BattleUnitSystem.UNIT_STATS["stagger_resist"][t]
						var arrow_effect: float = 1.0 - stagger_resist
						if (t == BattleUnitSystem.UnitType.CAVALRY or t == BattleUnitSystem.UnitType.HEAVY_CAVALRY):
							var sr := target_speed / maxf(0.01, units.max_speed[j])
							if sr > 0.7:
								arrow_effect *= 0.15
							else:
								arrow_effect *= 0.6
						units.stagger_time[j] = maxf(units.stagger_time[j], 0.08 * arrow_effect)

					# Impulse from projectile
					if dist > 0.01:
						var impulse := bullet_mass[i] * 0.5
						units.vx[j] += (dx / dist) * impulse * (1.0 - units.knockback_resist[j])
						units.vy[j] += (dy / dist) * impulse * (1.0 - units.knockback_resist[j])

				alive[i] = 0
				break
