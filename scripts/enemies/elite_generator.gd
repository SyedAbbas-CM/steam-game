class_name EliteGenerator
extends RefCounted

const ARCHETYPE_DIR := "res://resources/enemy_generation/archetypes"
const AFFIX_DIR := "res://resources/enemy_generation/affixes"
const MOVE_WEIGHTED := 0
const MOVE_ORBIT_PLAYER := 1
const MOVE_ORBIT_POINT := 2
const MOVE_ORBIT_ALLY := 3
const MOVE_PATROL_H := 4
const MOVE_PATROL_V := 5
const MOVE_FLEE := 6
const MOVE_TELEPORT := 12
const MOVE_MIRROR := 13

enum Tier {
	ELITE,
	HYPER,
	BOSS,
}

const _MELEE_ATTACKS := {
	EnemyDefinition.AttackType.MELEE: true,
	EnemyDefinition.AttackType.CHARGE: true,
	EnemyDefinition.AttackType.DASH: true,
	EnemyDefinition.AttackType.SLAM: true,
	EnemyDefinition.AttackType.DASH_STRIKE: true,
	EnemyDefinition.AttackType.WHIP_LASH: true,
	EnemyDefinition.AttackType.LANCE_THRUST: true,
	EnemyDefinition.AttackType.LEAPING_SLAM: true,
	EnemyDefinition.AttackType.SWORD_SLASH: true,
	EnemyDefinition.AttackType.SPEAR_LUNGE: true,
	EnemyDefinition.AttackType.CHARGE_BULL: true,
	EnemyDefinition.AttackType.CLEAVE_COMBO: true,
	EnemyDefinition.AttackType.WHIRLWIND: true,
	EnemyDefinition.AttackType.GROUND_POUND: true,
	EnemyDefinition.AttackType.TAIL_WHIP: true,
	EnemyDefinition.AttackType.SHIELD_BASH: true,
	EnemyDefinition.AttackType.GRAB_THROW: true,
	EnemyDefinition.AttackType.STOMP_WAVE: true,
}

const _SUPPORT_ATTACKS := {
	EnemyDefinition.AttackType.HEAL: true,
	EnemyDefinition.AttackType.SUMMON: true,
	EnemyDefinition.AttackType.SHIELD: true,
	EnemyDefinition.AttackType.BARRIER_WALL: true,
	EnemyDefinition.AttackType.PULL_SHOT: true,
	EnemyDefinition.AttackType.PUSH_WAVE: true,
	EnemyDefinition.AttackType.SUMMON_WALL: true,
	EnemyDefinition.AttackType.CURSE_BOLT: true,
	EnemyDefinition.AttackType.SHIELD_WALL: true,
}

const _RANGED_FALLBACK_POOL: Array[int] = [
	EnemyDefinition.AttackType.VOLLEY,
	EnemyDefinition.AttackType.CROSS_SHOT,
	EnemyDefinition.AttackType.SHOTGUN_BLAST,
	EnemyDefinition.AttackType.RETURNING_VOLLEY,
	EnemyDefinition.AttackType.HOMING_SALVO,
]

const _MELEE_FALLBACK_POOL: Array[int] = [
	EnemyDefinition.AttackType.CHARGE_BULL,
	EnemyDefinition.AttackType.CLEAVE_COMBO,
	EnemyDefinition.AttackType.WHIRLWIND,
	EnemyDefinition.AttackType.GROUND_POUND,
	EnemyDefinition.AttackType.SHIELD_BASH,
]

const _SUPPORT_FALLBACK_POOL: Array[int] = [
	EnemyDefinition.AttackType.SUMMON,
	EnemyDefinition.AttackType.CURSE_BOLT,
	EnemyDefinition.AttackType.POISON_CLOUD,
	EnemyDefinition.AttackType.BARRIER_WALL,
	EnemyDefinition.AttackType.PUSH_WAVE,
]

const _HEAVY_BOMB_ATTACKS := {
	EnemyDefinition.AttackType.BOMB_TOSS: true,
	EnemyDefinition.AttackType.CARPET_BOMB: true,
	EnemyDefinition.AttackType.FIRE_RAIN: true,
	EnemyDefinition.AttackType.CLUSTER_BOMB: true,
	EnemyDefinition.AttackType.MINE_DROP: true,
	EnemyDefinition.AttackType.ARTILLERY: true,
	EnemyDefinition.AttackType.POISON_CLOUD: true,
	EnemyDefinition.AttackType.MORTAR: true,
	EnemyDefinition.AttackType.METEOR_SHOWER: true,
}

const _AREA_DENIAL_ATTACKS := {
	EnemyDefinition.AttackType.MINEFIELD: true,
	EnemyDefinition.AttackType.SEEKING_MINES: true,
	EnemyDefinition.AttackType.MINE_DROP: true,
	EnemyDefinition.AttackType.POISON_CLOUD: true,
	EnemyDefinition.AttackType.BARRIER_WALL: true,
	EnemyDefinition.AttackType.TELEGRAPH_EXPLOSION: true,
	EnemyDefinition.AttackType.ORBIT_LAUNCH: true,
}

static var _archetypes: Array = []
static var _affixes: Array = []
static var _loaded: bool = false

static func apply_generated_identity(def: EnemyDefinition, tier: int) -> void:
	if def == null:
		return
	_ensure_loaded()
	if _archetypes.is_empty():
		return
	var role := _classify_role(def)
	var archetype: Resource = _pick_archetype(def, role, tier)
	if archetype == null:
		return
	var affixes: Array = _pick_affixes(def, role, tier)
	_apply_archetype(def, archetype)
	for affix in affixes:
		_apply_affix(def, affix)
	_finalize_generated_identity(def, archetype, affixes, role, tier)

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_archetypes.clear()
	for res in _load_resources_in_dir(ARCHETYPE_DIR):
		if res != null:
			_archetypes.append(res)
	_affixes.clear()
	for res in _load_resources_in_dir(AFFIX_DIR):
		if res != null:
			_affixes.append(res)

static func _load_resources_in_dir(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".tres"):
			var res = load(dir_path.path_join(name))
			if res != null:
				out.append(res)
		name = dir.get_next()
	dir.list_dir_end()
	out.sort_custom(func(a, b): return String(a.resource_path) < String(b.resource_path))
	return out

static func _classify_role(def: EnemyDefinition) -> String:
	if def.attack_type in _MELEE_ATTACKS:
		return "melee"
	if def.attack_type in _SUPPORT_ATTACKS:
		return "support"
	return "ranged"

static func _pick_archetype(def: EnemyDefinition, role: String, tier: int):
	var candidates: Array = []
	var lvl := maxi(def.level if def else 1, 1)
	for archetype in _archetypes:
		if archetype == null:
			continue
		if lvl <= 4 and tier <= Tier.ELITE:
			if archetype.summon_on_phase_change:
				continue
			if archetype.forced_attack_type in _SUPPORT_ATTACKS:
				continue
			var archetype_pool: Array = archetype.attack_pool
			var has_support_attack := false
			for attack_type in archetype_pool:
				if _SUPPORT_ATTACKS.has(attack_type) or _AREA_DENIAL_ATTACKS.has(attack_type):
					has_support_attack = true
					break
			if has_support_attack:
				continue
		if _role_allowed(role, archetype.allowed_roles):
			candidates.append(archetype)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]

static func _pick_affixes(def: EnemyDefinition, role: String, tier: int) -> Array:
	var target_count := 1
	if tier >= Tier.HYPER:
		target_count = 2
	if tier >= Tier.BOSS:
		target_count = 3
	var projectile_capable := not _MELEE_ATTACKS.has(def.attack_type) and def.attack_type != EnemyDefinition.AttackType.SUMMON
	var melee_capable := _MELEE_ATTACKS.has(def.attack_type)
	var candidates: Array = []
	for affix in _affixes:
		if affix == null:
			continue
		if affix.min_tier > tier:
			continue
		if def.level <= 4 and tier <= Tier.ELITE:
			if affix.affix_id in ["toxic", "phantom", "bulwark"]:
				continue
			var has_area_denial := false
			for attack_type in affix.add_attack_types:
				if _AREA_DENIAL_ATTACKS.has(attack_type) or _SUPPORT_ATTACKS.has(attack_type):
					has_area_denial = true
					break
			if has_area_denial:
				continue
		if not _role_allowed(role, affix.allowed_roles):
			continue
		if affix.requires_projectiles and not projectile_capable:
			continue
		if affix.requires_melee and not melee_capable:
			continue
		candidates.append(affix)
	candidates.shuffle()
	var picked: Array = []
	for affix in candidates:
		if picked.size() >= target_count:
			break
		picked.append(affix)
	return picked

static func _role_allowed(role: String, allowed_roles: Array[String]) -> bool:
	if allowed_roles.is_empty():
		return true
	return "any" in allowed_roles or role in allowed_roles

static func _apply_archetype(def: EnemyDefinition, archetype) -> void:
	def.max_hp = maxi(1, int(round(def.max_hp * archetype.hp_mult)))
	def.attack_damage = maxi(1, int(round(def.attack_damage * archetype.damage_mult)))
	def.move_speed *= archetype.move_speed_mult
	def.attack_speed *= archetype.attack_speed_mult
	def.bullet_speed *= archetype.bullet_speed_mult
	def.bullet_count = maxi(1, def.bullet_count + archetype.bullet_count_bonus)
	def.armor += archetype.armor_bonus
	if archetype.movement_pattern != null:
		def.movement_pattern = archetype.movement_pattern
	if archetype.forced_attack_type != EnemyDefinition.AttackType.NONE:
		def.attack_type = archetype.forced_attack_type
	if def.phase_2_attack == EnemyDefinition.AttackType.NONE and archetype.phase_2_attack != EnemyDefinition.AttackType.NONE:
		def.phase_2_attack = archetype.phase_2_attack
	if def.phase_3_attack == EnemyDefinition.AttackType.NONE and archetype.phase_3_attack != EnemyDefinition.AttackType.NONE:
		def.phase_3_attack = archetype.phase_3_attack
	if archetype.summon_on_phase_change:
		def.summon_on_phase_change = true
		def.summon_phase_count = maxi(def.summon_phase_count, archetype.summon_phase_count)
	def.sprite_color = def.sprite_color.lerp(archetype.color_tint, 0.35)

static func _apply_affix(def: EnemyDefinition, affix) -> void:
	def.max_hp = maxi(1, int(round(def.max_hp * affix.hp_mult)))
	def.attack_damage = maxi(1, int(round(def.attack_damage * affix.damage_mult)))
	def.move_speed *= affix.move_speed_mult
	def.attack_speed *= affix.attack_speed_mult
	def.bullet_speed *= affix.bullet_speed_mult
	def.bullet_count = maxi(1, def.bullet_count + affix.bullet_count_bonus)
	def.armor += affix.armor_bonus
	if affix.movement_override != null:
		def.movement_pattern = affix.movement_override
	if def.phase_2_attack == EnemyDefinition.AttackType.NONE and affix.phase_2_attack != EnemyDefinition.AttackType.NONE:
		def.phase_2_attack = affix.phase_2_attack
	if def.phase_3_attack == EnemyDefinition.AttackType.NONE and affix.phase_3_attack != EnemyDefinition.AttackType.NONE:
		def.phase_3_attack = affix.phase_3_attack
	if affix.bullet_status_effect != "":
		def.bullet_status_effect = affix.bullet_status_effect
		def.bullet_status_duration = affix.bullet_status_duration
	def.sprite_color = def.sprite_color.lerp(affix.color_tint, 0.28)
	def.attack_modifier = _merge_affix_modifier(def.attack_modifier, affix)

static func _merge_affix_modifier(base_modifier, affix):
	var mod = null
	if base_modifier != null:
		mod = base_modifier.duplicate(true)
	else:
		mod = AttackModifier.new()
	mod.homing_strength = clampf(mod.homing_strength + affix.homing_strength, 0.0, 1.25)
	mod.bounce_count += affix.bounce_count
	mod.pierce_count += affix.pierce_count
	mod.speed_mult *= affix.speed_mult
	mod.sine_wave = mod.sine_wave or affix.sine_wave
	mod.lifetime_mult *= affix.lifetime_mult
	mod.push_force += affix.push_force
	mod.persist_as_mine = mod.persist_as_mine or affix.persist_as_mine
	mod.persist_duration = maxf(mod.persist_duration, affix.persist_duration)
	if affix.split_after > 0.0:
		mod.split_after = affix.split_after if mod.split_after <= 0.0 else minf(mod.split_after, affix.split_after)
	mod.split_count = maxi(mod.split_count, affix.split_count)
	mod.apply_burning = mod.apply_burning or affix.apply_burning
	mod.apply_slowed = mod.apply_slowed or affix.apply_slowed
	mod.apply_poisoned = mod.apply_poisoned or affix.apply_poisoned
	mod.apply_stunned = mod.apply_stunned or affix.apply_stunned
	mod.explode_on_hit = mod.explode_on_hit or affix.explode_on_hit
	mod.explode_radius = maxf(mod.explode_radius, affix.explode_radius)
	return mod

static func _finalize_generated_identity(def: EnemyDefinition, archetype, affixes: Array, role: String, tier: int) -> void:
	var attack_pool := _build_attack_pool(def, archetype, affixes, role, tier)
	if def.phase_2_attack == EnemyDefinition.AttackType.NONE and attack_pool.size() > 0:
		def.phase_2_attack = int(attack_pool[min(1, attack_pool.size() - 1)])
	if tier >= Tier.HYPER and def.phase_3_attack == EnemyDefinition.AttackType.NONE and attack_pool.size() > 0:
		def.phase_3_attack = int(attack_pool[min(attack_pool.size() - 1, 2)])
	def.set_meta("generated_identity_locked", true)
	def.set_meta("generated_archetype_id", archetype.archetype_id)
	def.set_meta("generated_attack_pool", attack_pool)
	var affix_ids: Array[String] = []
	for affix in affixes:
		affix_ids.append(affix.affix_id)
	def.set_meta("generated_affix_ids", affix_ids)
	def.enemy_name = _compose_name(def.enemy_name, archetype, affixes)

static func _build_attack_pool(def: EnemyDefinition, archetype, affixes: Array, role: String, tier: int) -> Array[int]:
	var pool: Array[int] = []
	var max_size := 2 if tier == Tier.ELITE else 3
	if def.attack_type != EnemyDefinition.AttackType.NONE:
		if _attack_allowed_for_context(def.attack_type, def, tier):
			pool.append(def.attack_type)
	if archetype.forced_attack_type != EnemyDefinition.AttackType.NONE and archetype.forced_attack_type not in pool:
		if _attack_allowed_for_context(archetype.forced_attack_type, def, tier):
			pool.append(archetype.forced_attack_type)
	for attack_type in archetype.attack_pool:
		if attack_type != EnemyDefinition.AttackType.NONE and attack_type not in pool and _attack_allowed_for_context(attack_type, def, tier):
			pool.append(attack_type)
	for affix in affixes:
		for attack_type in affix.add_attack_types:
			if attack_type != EnemyDefinition.AttackType.NONE and attack_type not in pool and _attack_allowed_for_context(attack_type, def, tier):
				pool.append(attack_type)
	var fallback := _RANGED_FALLBACK_POOL
	if role == "melee":
		fallback = _MELEE_FALLBACK_POOL
	elif role == "support":
		fallback = _SUPPORT_FALLBACK_POOL
	for attack_type in fallback:
		if pool.size() >= max_size:
			break
		if attack_type not in pool:
			pool.append(attack_type)
	if pool.size() > max_size:
		pool.resize(max_size)
	return pool

static func _attack_allowed_for_context(attack_type: int, def: EnemyDefinition, tier: int) -> bool:
	if not _HEAVY_BOMB_ATTACKS.has(attack_type):
		if _AREA_DENIAL_ATTACKS.has(attack_type) and _movement_discourages_commitment(def.movement_pattern):
			return false
		return true
	var lvl := maxi(def.level if def else 1, 1)
	if tier <= Tier.ELITE and lvl <= 5:
		return false
	if tier <= Tier.HYPER and lvl <= 3:
		return false
	if _movement_discourages_commitment(def.movement_pattern):
		return false
	return true

static func _movement_discourages_commitment(p) -> bool:
	if p == null:
		return false
	var skittish := [
		MOVE_ORBIT_PLAYER,
		MOVE_ORBIT_POINT,
		MOVE_ORBIT_ALLY,
		MOVE_PATROL_H,
		MOVE_PATROL_V,
		MOVE_FLEE,
		MOVE_TELEPORT,
		MOVE_MIRROR,
	]
	if skittish.has(p.move_type):
		return true
	return p.move_type == MOVE_WEIGHTED \
		and p.approach_weight <= 0.45 \
		and (p.hold_weight + p.retreat_weight) >= 0.55

static func _compose_name(base_name: String, archetype, affixes: Array) -> String:
	var prefix_parts: Array[String] = []
	if archetype.display_prefix != "":
		prefix_parts.append(archetype.display_prefix)
	for affix in affixes:
		if affix.display_prefix != "":
			prefix_parts.append(affix.display_prefix)
	var suffix_parts: Array[String] = []
	if archetype.display_suffix != "":
		suffix_parts.append(archetype.display_suffix)
	for affix in affixes:
		if affix.display_suffix != "":
			suffix_parts.append(affix.display_suffix)
	var name := base_name
	if not prefix_parts.is_empty():
		name = " ".join(prefix_parts) + " " + name
	if not suffix_parts.is_empty():
		name += " " + " ".join(suffix_parts)
	return name
