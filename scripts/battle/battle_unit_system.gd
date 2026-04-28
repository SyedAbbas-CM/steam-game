class_name BattleUnitSystem
extends RefCounted

# Unit types matching Mixed_Units.png columns
enum UnitType { INFANTRY = 0, HEAVY_INFANTRY = 1, CAVALRY = 2, HEAVY_CAVALRY = 3, ARCHER = 4, MAGE = 5, SPEAR = 6, HORSE_ARCHER = 7, RANGED_INFANTRY = 8 }
enum Faction { RED = 0, BLUE = 1 }
enum FormationType { LINE, SHIELD_WALL, BLOCK, WEDGE, LOOSE_LINE }

const MAX_UNITS := 2000
const SPATIAL_CELL_SIZE := 80.0

# Stats per unit type: [infantry, heavy_inf, cavalry, heavy_cav, archer, mage, spear, horse_archer, ranged_inf]
const UNIT_STATS := {
	#                    INF    H.INF  CAV    H.CAV  ARCH   MAGE   SPEAR  H.ARC  R.INF
	"hp":              [45.0, 95.0, 85.0, 140.0, 22.0, 18.0, 55.0, 30.0, 40.0],
	"base_defense":    [5.0, 14.0, 8.0, 13.0, 1.5, 1.0, 8.0, 3.0, 7.0],
	"mass":            [1.6, 5.5, 7.0, 13.0, 0.6, 0.5, 2.0, 6.5, 1.4],
	"inertia":         [0.4, 0.8, 0.85, 1.4, 0.5, 0.4, 0.5, 0.85, 0.4],
	"friction":        [0.91, 0.89, 0.95, 0.95, 0.88, 0.88, 0.90, 0.95, 0.90],
	"knockback_resist":[0.35, 0.92, 0.7, 0.92, 0.05, 0.0, 0.45, 0.6, 0.30],
	"max_speed":       [2.2, 1.8, 4.8, 4.0, 1.9, 1.7, 1.9, 4.5, 1.8],
	"acceleration":    [0.16, 0.10, 0.15, 0.12, 0.075, 0.08, 0.12, 0.14, 0.10],
	"radius":          [16.0, 20.0, 24.0, 28.0, 14.0, 14.0, 18.0, 22.0, 16.0],
	"attack_damage":   [5.5, 9.0, 12.0, 15.0, 5.5, 9.0, 8.0, 4.5, 7.5],
	"attack_range":    [75.0, 85.0, 127.0, 142.0, 500.0, 400.0, 100.0, 380.0, 300.0],
	"preferred_range": [65.0, 70.0, 112.0, 127.0, 420.0, 340.0, 85.0, 300.0, 240.0],
	"attack_cooldown": [0.45, 0.55, 0.5, 0.55, 0.85, 1.2, 0.55, 0.70, 1.0],
	"bullet_speed":    [14.0, 12.0, 18.0, 16.0, 15.0, 10.0, 14.0, 14.0, 13.0],
	"bullet_mass":     [0.3, 0.7, 1.0, 1.8, 0.12, 0.3, 0.5, 0.10, 0.25],
	"charge_bonus":    [1.5, 1.0, 3.0, 3.5, 1.0, 1.0, 1.0, 2.0, 1.0],
	"charge_knockback":[0.0, 0.0, 8.0, 11.0, 0.0, 0.0, 0.0, 5.0, 0.0],
	"stagger_resist":  [0.15, 0.95, 0.4, 0.85, 0.0, 0.0, 0.25, 0.3, 0.10],
	"archer_resist":   [0.1, 0.35, 0.2, 0.45, 0.0, 0.0, 0.15, 0.15, 0.30],
	"cluster_def_bonus":[1.6, 2.2, 1.0, 1.0, 1.0, 1.0, 1.8, 1.0, 1.0],
	"anti_cav_bonus":  [1.3, 1.8, 1.0, 1.0, 1.0, 1.0, 2.5, 1.0, 1.0],
	"flank_bonus":     [1.0, 1.0, 1.0, 1.0, 1.5, 1.0, 1.0, 1.5, 1.0],
	"min_safe_distance":[0.0, 0.0, 0.0, 0.0, 200.0, 220.0, 0.0, 180.0, 160.0],
}

# Terrain types derived from zone tileset IDs
enum TerrainType { PLAINS = 0, FOREST = 1, MOUNTAIN = 2, DESERT = 3, ICE = 4, JUNGLE = 5, SWAMP = 6, TOWN = 7, CAVE = 8, VOID = 9 }

# Tileset ID → TerrainType mapping
const TILESET_TO_TERRAIN := {
	0: TerrainType.VOID,
	8: TerrainType.FOREST,
	16: TerrainType.CAVE,
	84: TerrainType.SWAMP,
	100: TerrainType.SWAMP,
	112: TerrainType.TOWN,
	144: TerrainType.ICE,
	192: TerrainType.JUNGLE,
	224: TerrainType.DESERT,
	240: TerrainType.MOUNTAIN,
}

# Terrain multipliers per unit type: [INF, H.INF, CAV, H.CAV, ARCH, MAGE, SPEAR, H.ARC, R.INF]
# >1.0 = bonus, <1.0 = penalty. Applied to speed, damage, and defense.
# Spear~infantry, Horse Archer~cavalry, Ranged Inf~archer for terrain purposes.
const TERRAIN_SPEED_MULT := {
	TerrainType.PLAINS:   [1.0, 1.0, 1.3, 1.3, 1.0, 1.0, 1.0, 1.2, 1.0],
	TerrainType.FOREST:   [1.0, 0.9, 0.75, 0.7, 1.1, 1.0, 1.0, 0.75, 1.05],
	TerrainType.MOUNTAIN: [0.9, 0.85, 0.6, 0.55, 1.0, 1.0, 0.9, 0.6, 0.95],
	TerrainType.DESERT:   [0.95, 0.9, 1.15, 1.1, 1.0, 1.0, 0.95, 1.1, 1.0],
	TerrainType.ICE:      [0.85, 0.8, 0.8, 0.75, 0.9, 1.0, 0.85, 0.8, 0.9],
	TerrainType.JUNGLE:   [0.9, 0.85, 0.65, 0.6, 1.0, 1.05, 0.9, 0.65, 1.0],
	TerrainType.SWAMP:    [0.85, 0.8, 0.7, 0.65, 0.9, 1.0, 0.85, 0.7, 0.9],
	TerrainType.TOWN:     [1.0, 1.0, 0.85, 0.8, 1.05, 1.0, 1.0, 0.85, 1.0],
	TerrainType.CAVE:     [0.95, 0.9, 0.6, 0.55, 0.9, 1.1, 0.95, 0.6, 0.9],
	TerrainType.VOID:     [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
}
const TERRAIN_DAMAGE_MULT := {
	TerrainType.PLAINS:   [1.0, 1.0, 1.2, 1.2, 1.0, 1.0, 1.0, 1.15, 1.0],
	TerrainType.FOREST:   [1.05, 1.0, 0.85, 0.8, 1.15, 1.0, 1.05, 0.85, 1.1],
	TerrainType.MOUNTAIN: [1.05, 1.1, 0.7, 0.7, 1.1, 1.05, 1.05, 0.7, 1.05],
	TerrainType.DESERT:   [1.0, 1.0, 1.1, 1.1, 1.0, 1.0, 1.0, 1.1, 1.0],
	TerrainType.ICE:      [0.95, 0.95, 0.9, 0.9, 1.0, 1.1, 0.95, 0.9, 1.0],
	TerrainType.JUNGLE:   [1.0, 1.0, 0.75, 0.75, 1.05, 1.1, 1.0, 0.75, 1.05],
	TerrainType.SWAMP:    [0.95, 0.95, 0.8, 0.8, 0.95, 1.05, 0.95, 0.8, 0.95],
	TerrainType.TOWN:     [1.05, 1.05, 0.9, 0.85, 1.0, 1.0, 1.05, 0.9, 1.0],
	TerrainType.CAVE:     [1.0, 1.05, 0.65, 0.6, 0.95, 1.15, 1.0, 0.65, 0.95],
	TerrainType.VOID:     [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
}
const TERRAIN_DEFENSE_MULT := {
	TerrainType.PLAINS:   [1.0, 1.0, 1.0, 1.0, 0.9, 0.9, 1.0, 1.0, 0.9],
	TerrainType.FOREST:   [1.1, 1.05, 0.9, 0.85, 1.15, 1.1, 1.1, 0.9, 1.1],
	TerrainType.MOUNTAIN: [1.15, 1.15, 0.8, 0.8, 1.1, 1.1, 1.15, 0.8, 1.1],
	TerrainType.DESERT:   [0.95, 0.95, 1.0, 1.0, 0.9, 0.95, 0.95, 1.0, 0.9],
	TerrainType.ICE:      [0.9, 0.95, 0.9, 0.9, 0.95, 1.0, 0.9, 0.9, 0.95],
	TerrainType.JUNGLE:   [1.1, 1.05, 0.85, 0.8, 1.1, 1.1, 1.1, 0.85, 1.1],
	TerrainType.SWAMP:    [0.95, 1.0, 0.85, 0.85, 1.0, 1.0, 0.95, 0.85, 1.0],
	TerrainType.TOWN:     [1.1, 1.1, 0.9, 0.85, 1.1, 1.05, 1.1, 0.9, 1.1],
	TerrainType.CAVE:     [1.05, 1.1, 0.7, 0.7, 1.0, 1.1, 1.05, 0.7, 1.0],
	TerrainType.VOID:     [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
}

static func get_terrain_from_tileset(tileset_id: int) -> int:
	if TILESET_TO_TERRAIN.has(tileset_id):
		return TILESET_TO_TERRAIN[tileset_id]
	# Default: plains for unknown tilesets (most open/default behavior)
	return TerrainType.PLAINS

# Damage multiplier matrix [attacker_type][defender_type] — rock-paper-scissors counters
# Rows/Cols: INF, H.INF, CAV, H.CAV, ARCH, MAGE, SPEAR, H.ARC, R.INF
const DAMAGE_MULT := [
	#       INF   H.INF  CAV   H.CAV  ARCH  MAGE  SPEAR  H.ARC  R.INF
	[1.0,  0.6,  0.7,  0.5,  1.2,  1.3,  0.8,  0.9,  1.0],  # Infantry
	[1.2,  0.8,  1.8,  1.5,  0.8,  1.0,  0.9,  1.2,  0.8],  # Heavy Infantry
	[1.3,  0.5,  1.0,  0.8,  1.6,  1.6,  0.6,  1.0,  1.4],  # Cavalry — weak vs spear
	[1.5,  0.7,  1.2,  1.0,  1.8,  1.8,  0.7,  1.2,  1.6],  # Heavy Cavalry — resists spear better
	[1.0,  0.7,  0.5,  0.4,  1.0,  1.2,  0.9,  0.7,  0.8],  # Archer
	[1.5,  1.3,  0.6,  0.5,  1.0,  1.0,  1.3,  0.7,  1.2],  # Mage
	[1.2,  0.7,  1.8,  1.5,  0.9,  0.8,  1.0,  1.5,  0.9],  # Spear — strong vs cavalry
	[1.1,  0.4,  0.8,  0.6,  1.2,  1.3,  0.6,  1.0,  1.0],  # Horse Archer — mobile harass
	[1.1,  0.8,  0.6,  0.5,  0.9,  1.0,  0.8,  0.8,  1.0],  # Ranged Infantry — crossbow
]

# Formation stat modifiers (applied on top of base stats)
const FORMATION_MODS := {
	FormationType.LINE: {
		"defense_bonus": 2.0, "speed_mult": 1.0, "knockback_resist": 0.05
	},
	FormationType.SHIELD_WALL: {
		"defense_bonus": 10.0, "speed_mult": 0.65, "knockback_resist": 0.35
	},
	FormationType.BLOCK: {
		"defense_bonus": 5.0, "speed_mult": 0.85, "knockback_resist": 0.15
	},
	FormationType.WEDGE: {
		"defense_bonus": 1.0, "speed_mult": 1.1, "knockback_resist": 0.1
	},
	FormationType.LOOSE_LINE: {
		"defense_bonus": 0.0, "speed_mult": 1.15, "knockback_resist": 0.0
	},
}

# Formation counter matrix: [attacker_formation][defender_formation] → damage multiplier
# WEDGE beats SHIELD_WALL (punch through), SHIELD_WALL beats LINE (absorbs charges),
# LINE beats LOOSE_LINE (concentrated force), LOOSE_LINE beats BLOCK (flanking),
# BLOCK beats WEDGE (absorbs the point).  Rows=attacker, Cols=defender.
#                          LINE  SHIELD  BLOCK  WEDGE  LOOSE
const FORMATION_COUNTER := [
	[1.0,  0.8,   0.9,   1.0,   1.2 ],  # LINE: good vs loose, bad vs shield
	[1.15, 1.0,   0.85,  0.75,  1.0 ],  # SHIELD_WALL: good vs line, bad vs wedge
	[1.0,  1.1,   1.0,   1.2,   0.8 ],  # BLOCK: good vs wedge+shield, bad vs loose
	[1.1,  1.3,   0.8,   1.0,   1.0 ],  # WEDGE: great vs shield, bad vs block
	[0.85, 1.0,   1.2,   1.0,   1.0 ],  # LOOSE_LINE: great vs block, bad vs line
]

# SoA arrays
var x: PackedFloat32Array
var y: PackedFloat32Array
var vx: PackedFloat32Array
var vy: PackedFloat32Array
var unit_type: PackedInt32Array
var faction: PackedInt32Array
var hp: PackedFloat32Array
var max_hp: PackedFloat32Array
var base_defense: PackedFloat32Array
var current_defense: PackedFloat32Array
var mass: PackedFloat32Array
var inertia: PackedFloat32Array
var friction: PackedFloat32Array
var knockback_resist: PackedFloat32Array
var max_speed: PackedFloat32Array
var acceleration: PackedFloat32Array
var radius: PackedFloat32Array
var alive: PackedInt32Array  # 0 or 1
var group_id: PackedInt32Array
var last_attack_time: PackedFloat32Array
var target_unit: PackedInt32Array
var morale: PackedFloat32Array
var facing: PackedFloat32Array
var stagger_time: PackedFloat32Array
var neighbor_count: PackedInt32Array
var charge_impact_time: PackedFloat32Array
var post_charge_bogged_time: PackedFloat32Array

# Ability system SoA
var ability_cooldown: PackedFloat32Array   # time until ability ready
var ability_timer: PackedFloat32Array      # active ability duration remaining
var ability_active: PackedInt32Array       # 0=inactive, 1=active

# Burn status SoA
var burn_time: PackedFloat32Array          # remaining burn duration
var burn_dps: PackedFloat32Array           # damage per second from burn

# Commander SoA
var is_commander: PackedInt32Array         # 0 or 1
var commander_debuff_timer: PackedFloat32Array  # seconds remaining of commander-death debuff

# Veteran SoA — 0=Raw, 1=Trained, 2=Veteran, 3=Elite
var veteran_rank: PackedInt32Array

# Formation bonus SoA
var formation_bonus_active: PackedInt32Array  # 0 or 1 — formation condition met this frame

# Per-unit formation type (synced from group commander each update)
var group_formation: PackedInt32Array      # FormationType enum value

# Cavalry charge tracking
var charge_time: PackedFloat32Array        # seconds spent charging (for momentum bonus)

# Scatter SoA (cavalry fear/panic)
var scatter_time: PackedFloat32Array       # seconds of SCATTERED state remaining
var scatter_dir_x: PackedFloat32Array      # flee direction X
var scatter_dir_y: PackedFloat32Array      # flee direction Y
var saved_group_id: PackedInt32Array       # original group_id before scatter

# Cached stats (not in SoA for simplicity, looked up by type)
var count: int = 0

# Spatial hash
var _spatial_hash: Dictionary = {}

func _init() -> void:
	x = PackedFloat32Array()
	y = PackedFloat32Array()
	vx = PackedFloat32Array()
	vy = PackedFloat32Array()
	unit_type = PackedInt32Array()
	faction = PackedInt32Array()
	hp = PackedFloat32Array()
	max_hp = PackedFloat32Array()
	base_defense = PackedFloat32Array()
	current_defense = PackedFloat32Array()
	mass = PackedFloat32Array()
	inertia = PackedFloat32Array()
	friction = PackedFloat32Array()
	knockback_resist = PackedFloat32Array()
	max_speed = PackedFloat32Array()
	acceleration = PackedFloat32Array()
	radius = PackedFloat32Array()
	alive = PackedInt32Array()
	group_id = PackedInt32Array()
	last_attack_time = PackedFloat32Array()
	target_unit = PackedInt32Array()
	morale = PackedFloat32Array()
	facing = PackedFloat32Array()
	stagger_time = PackedFloat32Array()
	neighbor_count = PackedInt32Array()
	charge_impact_time = PackedFloat32Array()
	post_charge_bogged_time = PackedFloat32Array()
	ability_cooldown = PackedFloat32Array()
	ability_timer = PackedFloat32Array()
	ability_active = PackedInt32Array()
	burn_time = PackedFloat32Array()
	burn_dps = PackedFloat32Array()
	is_commander = PackedInt32Array()
	commander_debuff_timer = PackedFloat32Array()
	veteran_rank = PackedInt32Array()
	formation_bonus_active = PackedInt32Array()
	group_formation = PackedInt32Array()
	charge_time = PackedFloat32Array()
	scatter_time = PackedFloat32Array()
	scatter_dir_x = PackedFloat32Array()
	scatter_dir_y = PackedFloat32Array()
	saved_group_id = PackedInt32Array()
	# Pre-allocate
	for arr in [x, y, vx, vy, hp, max_hp, base_defense, current_defense, mass,
		inertia, friction, knockback_resist, max_speed, acceleration, radius,
		last_attack_time, morale, facing, stagger_time, charge_impact_time,
		post_charge_bogged_time, ability_cooldown, ability_timer, burn_time, burn_dps,
		commander_debuff_timer, charge_time, scatter_time, scatter_dir_x, scatter_dir_y]:
		arr.resize(MAX_UNITS)
	for arr in [unit_type, faction, alive, group_id, target_unit, neighbor_count, ability_active,
		is_commander, veteran_rank, formation_bonus_active, group_formation, saved_group_id]:
		arr.resize(MAX_UNITS)

# Battle-wide terrain type (set before spawning units)
var battle_terrain: int = TerrainType.PLAINS

func spawn(px: float, py: float, type: int, fac: int, grp_id: int = -1, stat_mult: float = 1.0, vet_rank: int = 0) -> int:
	if count >= MAX_UNITS:
		return -1
	var i := count
	count += 1
	x[i] = px
	y[i] = py
	vx[i] = 0.0
	vy[i] = 0.0
	unit_type[i] = type
	faction[i] = fac

	# Base stats
	var base_hp: float = UNIT_STATS["hp"][type]
	var base_def: float = UNIT_STATS["base_defense"][type]
	var base_spd: float = UNIT_STATS["max_speed"][type]

	# Terrain multipliers
	var terrain_spd: float = TERRAIN_SPEED_MULT[battle_terrain][type]
	var terrain_def: float = TERRAIN_DEFENSE_MULT[battle_terrain][type]

	# Veteran rank bonuses: Raw=0, Trained=+5%, Veteran=+12%, Elite=+20%
	var vet_mult := 1.0
	match vet_rank:
		1: vet_mult = 1.05
		2: vet_mult = 1.12
		3: vet_mult = 1.20

	# Apply combined multipliers (stat_mult includes upgrades + enemy scaling)
	hp[i] = base_hp * stat_mult * vet_mult
	max_hp[i] = hp[i]
	base_defense[i] = base_def * stat_mult * terrain_def * vet_mult
	current_defense[i] = base_defense[i]
	mass[i] = UNIT_STATS["mass"][type]
	inertia[i] = UNIT_STATS["inertia"][type]
	friction[i] = UNIT_STATS["friction"][type]
	knockback_resist[i] = UNIT_STATS["knockback_resist"][type]
	max_speed[i] = base_spd * terrain_spd
	acceleration[i] = UNIT_STATS["acceleration"][type] * terrain_spd
	radius[i] = UNIT_STATS["radius"][type]
	alive[i] = 1
	group_id[i] = grp_id
	last_attack_time[i] = -10.0
	target_unit[i] = -1
	morale[i] = 100.0
	facing[i] = 0.0 if fac == Faction.BLUE else PI
	stagger_time[i] = 0.0
	neighbor_count[i] = 0
	charge_impact_time[i] = 0.0
	post_charge_bogged_time[i] = 0.0
	ability_cooldown[i] = 0.0
	ability_timer[i] = 0.0
	ability_active[i] = 0
	burn_time[i] = 0.0
	burn_dps[i] = 0.0
	is_commander[i] = 0
	commander_debuff_timer[i] = 0.0
	veteran_rank[i] = vet_rank
	formation_bonus_active[i] = 0
	group_formation[i] = 0  # LINE by default
	charge_time[i] = 0.0
	scatter_time[i] = 0.0
	scatter_dir_x[i] = 0.0
	scatter_dir_y[i] = 0.0
	saved_group_id[i] = -1
	return i

func damage(i: int, base_dmg: float, attack_angle: float = 0.0, is_from_archer: bool = false, _attacker_vx: float = 0.0, _attacker_vy: float = 0.0, source_unit_type: int = -1, attacker_formation: int = -1) -> float:
	if alive[i] == 0:
		return 0.0
	var t := unit_type[i]
	# Counter multiplier from DAMAGE_MULT table
	var counter_mult := 1.0
	if source_unit_type >= 0 and source_unit_type < DAMAGE_MULT.size():
		counter_mult = DAMAGE_MULT[source_unit_type][t]
	# Terrain damage multiplier for attacker
	var terrain_dmg_mult := 1.0
	if source_unit_type >= 0:
		terrain_dmg_mult = TERRAIN_DAMAGE_MULT[battle_terrain][source_unit_type]
	# Formation counter multiplier (attacker formation vs defender formation)
	var formation_counter_mult := 1.0
	if attacker_formation >= 0 and attacker_formation < FORMATION_COUNTER.size():
		var defender_gid := group_id[i]
		# We need to look up defender's formation — stored per unit as group_formation
		# For now use formation_bonus_active as proxy: if active, use group formation
		# The actual formation is passed by caller or we use a simple lookup
		if defender_gid >= 0 and group_formation.size() > i:
			var def_form: int = group_formation[i]
			if def_form >= 0 and def_form < FORMATION_COUNTER[attacker_formation].size():
				formation_counter_mult = FORMATION_COUNTER[attacker_formation][def_form]

	# Base defense reduction
	var actual := maxf(1.0, base_dmg * counter_mult * terrain_dmg_mult * formation_counter_mult * (1.0 - current_defense[i] * 0.02))

	# Directional damage (amplified flanking)
	var angle_diff := absf(wrapf(attack_angle - facing[i], -PI, PI))
	var dir_mult := 1.0
	if angle_diff < PI / 3.0:
		dir_mult = 0.8  # Front (shielded)
	elif angle_diff < 2.0 * PI / 3.0:
		dir_mult = 1.6  # Flank (was 1.3)
	else:
		dir_mult = 2.2  # Rear (was 1.8)
	actual *= dir_mult

	# Archer resist
	if is_from_archer:
		actual *= (1.0 - UNIT_STATS["archer_resist"][t])
		if dir_mult > 1.0:
			actual *= UNIT_STATS["flank_bonus"][t]

	# Anti-cavalry bonus (heavy inf vs cavalry)
	# Handled externally by caller

	# Morale tier modifier — Inspired/Steady/Wavering/Shaken/Broken
	if morale[i] >= 80.0:
		actual *= 0.9  # Inspired: -10% damage taken
	elif morale[i] < 15.0:
		actual *= 1.3  # Broken: +30% damage taken
	elif morale[i] < 30.0:
		actual *= 1.2  # Shaken: +20% damage taken
	elif morale[i] < 50.0:
		actual *= 1.1  # Wavering: +10% damage taken

	# Support resistance — more nearby allies = slightly tougher
	var support := minf(1.0, float(neighbor_count[i]) / 5.0)
	if support > 0.2:
		actual *= (1.0 - support * 0.2)

	# Passive formation bonus: infantry/heavy_inf/spear in groups get extra damage reduction
	if t == UnitType.INFANTRY and neighbor_count[i] >= 3:
		var wall_bonus := minf(0.3, float(neighbor_count[i]) * 0.04)  # up to 30% at 7+ neighbors
		actual *= (1.0 - wall_bonus)
	elif t == UnitType.HEAVY_INFANTRY and neighbor_count[i] >= 2:
		var brace_bonus := minf(0.25, float(neighbor_count[i]) * 0.05)  # up to 25% at 5+ neighbors
		actual *= (1.0 - brace_bonus)
	elif t == UnitType.SPEAR and neighbor_count[i] >= 2:
		var pike_bonus := minf(0.25, float(neighbor_count[i]) * 0.04)  # up to 25% at 6+ neighbors
		actual *= (1.0 - pike_bonus)

	# Scattered units take 50% more damage
	if scatter_time[i] > 0.0:
		actual *= 1.5

	# Cavalry is VULNERABLE during charge impact (committed to melee)
	if (t == UnitType.CAVALRY or t == UnitType.HEAVY_CAVALRY) and charge_impact_time[i] > 0.0:
		actual *= 1.2

	# Commander debuff: -15% defense for 10s after commander death
	if commander_debuff_timer[i] > 0.0:
		actual *= 1.15

	hp[i] -= actual
	# Morale loss from taking damage (slower drain)
	morale[i] = maxf(0.0, morale[i] - actual * 0.1)

	# Cavalry rear charge stun: short stagger on rear hit from mounted units
	if dir_mult >= 2.0 and (source_unit_type == UnitType.CAVALRY or source_unit_type == UnitType.HEAVY_CAVALRY or source_unit_type == UnitType.HORSE_ARCHER):
		stagger_time[i] = maxf(stagger_time[i], 0.4)

	if hp[i] <= 0.0:
		alive[i] = 0
	return actual

func build_spatial_hash() -> void:
	_spatial_hash.clear()
	for i in count:
		if alive[i] == 0:
			continue
		var cx := int(floor(x[i] / SPATIAL_CELL_SIZE))
		var cy := int(floor(y[i] / SPATIAL_CELL_SIZE))
		var key := (cy + 1000) * 10000 + (cx + 1000)
		if not _spatial_hash.has(key):
			_spatial_hash[key] = PackedInt32Array()
		_spatial_hash[key].append(i)

func get_nearby(px: float, py: float, search_radius: float) -> PackedInt32Array:
	var result := PackedInt32Array()
	var cx := int(floor(px / SPATIAL_CELL_SIZE))
	var cy := int(floor(py / SPATIAL_CELL_SIZE))
	var cells := int(search_radius / SPATIAL_CELL_SIZE) + 1
	var r_sq := search_radius * search_radius
	for dy in range(-cells, cells + 1):
		for dx in range(-cells, cells + 1):
			var key := (cy + dy + 1000) * 10000 + (cx + dx + 1000)
			if _spatial_hash.has(key):
				for idx in _spatial_hash[key]:
					var ddx := x[idx] - px
					var ddy := y[idx] - py
					if ddx * ddx + ddy * ddy <= r_sq:
						result.append(idx)
	return result

func find_nearest_enemy(i: int, max_range: float = 400.0) -> int:
	var best := -1
	var best_dist_sq := max_range * max_range
	var fac := faction[i]
	var nearby := get_nearby(x[i], y[i], max_range)
	for j in nearby:
		if j == i or alive[j] == 0 or faction[j] == fac:
			continue
		var dx := x[j] - x[i]
		var dy := y[j] - y[i]
		var d_sq := dx * dx + dy * dy
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best = j
	return best

func update_formation_bonuses(commander) -> void:
	# Reset neighbor counts and base stats
	for i in count:
		if alive[i] == 0:
			continue
		neighbor_count[i] = 0
		current_defense[i] = base_defense[i]
		knockback_resist[i] = UNIT_STATS["knockback_resist"][unit_type[i]]

	# Count neighbors and apply formation bonuses per group
	for i in count:
		if alive[i] == 0:
			continue
		var nearby := get_nearby(x[i], y[i], 100.0)
		var n := 0
		for j in nearby:
			if j != i and alive[j] == 1 and faction[j] == faction[i]:
				n += 1
		neighbor_count[i] = n

		# Formation bonus from group
		var gid := group_id[i]
		if gid >= 0 and commander:
			var group = commander.get_group(gid)
			if group:
				group_formation[i] = group.formation_type
				var fm: int = group.formation_type
				var mods: Dictionary = FORMATION_MODS[fm]
				current_defense[i] += mods["defense_bonus"]
				knockback_resist[i] = minf(1.0, knockback_resist[i] + mods["knockback_resist"])
				# Cluster defense for infantry/heavy_inf with 3+ neighbors
				if n >= 3:
					var cluster_mult: float = UNIT_STATS["cluster_def_bonus"][unit_type[i]]
					if cluster_mult > 1.0:
						current_defense[i] *= cluster_mult

		# Neighbor defense bonus (up to +15)
		var def_bonus := minf(15.0, float(n) * 3.0)
		current_defense[i] += def_bonus

func count_by_faction(fac: int) -> int:
	var c := 0
	for i in count:
		if alive[i] == 1 and faction[i] == fac:
			c += 1
	return c

func get_group_center(grp_id: int) -> Vector2:
	var cx := 0.0
	var cy := 0.0
	var n := 0
	for i in count:
		if alive[i] == 1 and group_id[i] == grp_id:
			cx += x[i]
			cy += y[i]
			n += 1
	if n == 0:
		return Vector2.ZERO
	return Vector2(cx / n, cy / n)

func get_group_alive_count(grp_id: int) -> int:
	var c := 0
	for i in count:
		if alive[i] == 1 and group_id[i] == grp_id:
			c += 1
	return c

func get_stat(type: int, stat_name: String) -> float:
	return UNIT_STATS[stat_name][type]
