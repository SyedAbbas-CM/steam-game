class_name WeaponSystem
extends Node

## weapon_type → list of accepted ammo_type strings. Anything not listed here
## either uses no ammo (melee) or accepts any (empty allowlist).
const WEAPON_AMMO_TYPES := {
	"bow": ["arrow"],
	"short_bow": ["arrow"],
	"crossbow": ["arrow", "bolt"],
	"throwing": ["knife", "throwing"],
	"javelin": ["javelin"],
	"sling": ["stone", "rock"],
}

@export var weapon_pattern: WeaponPattern

var bullet_scene: PackedScene
var equipment_manager: EquipmentManager
var can_shoot: bool = true
var fire_rate_mult: float = 1.0  # set by player for dagger rapid mode
var crit_bonus: float = 0.0  # extra crit chance from abilities
var damage_mult: float = 1.0  # set by player for aimed mode (crossbow)

# Pattern cache: weapon_type → WeaponPattern instance
var _pattern_cache: Dictionary = {}
var _default_pattern: WeaponPattern
var _spell_fire_counter: int = 0  # only every Nth wizard fire plays the spell SFX

@onready var cooldown_timer: Timer = Timer.new()

func _ready() -> void:
	bullet_scene = preload("res://scenes/bullet.tscn")
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(func(): can_shoot = true)
	add_child(cooldown_timer)

	if not weapon_pattern:
		weapon_pattern = SpreadPattern.new()
	_default_pattern = weapon_pattern

func setup(equip_mgr: EquipmentManager) -> void:
	equipment_manager = equip_mgr
	update_pattern_for_weapon()

## Switch weapon_pattern based on the currently equipped weapon's weapon_type.
func update_pattern_for_weapon() -> void:
	if not equipment_manager:
		return
	var weapon = equipment_manager.get_equipped_weapon()
	if not weapon:
		weapon_pattern = _default_pattern
		return
	var wtype = weapon.get_weapon_type()
	if wtype == "":
		weapon_pattern = _default_pattern
		return
	if _pattern_cache.has(wtype):
		weapon_pattern = _pattern_cache[wtype]
		return
	var pattern: WeaponPattern
	match wtype:
		"sword", "club", "short_bow", "staff":
			pattern = SpreadPattern.new()
		"dagger":
			pattern = BurstPattern.new()
		"axe":
			pattern = ShotgunPattern.new()
		"hammer":
			pattern = MeteorPattern.new()
		"flail":
			pattern = BoomerangPattern.new()
		"spear", "javelin", "halberd":
			pattern = TridentPattern.new()
		"throwing", "sling":
			pattern = ScatterPattern.new()
		"bow":
			pattern = ParallelPattern.new()
		"crossbow":
			pattern = RailgunPattern.new()
		"wand":
			pattern = BurstPattern.new()
		"tome":
			var nova = NovaPattern.new()
			nova.inner_count = 4
			nova.outer_count = 4
			pattern = nova
		"greatsword":
			var p = SpreadPattern.new()
			p.cooldown_override = 0.8
			pattern = p
		"great_axe":
			var p = ShotgunPattern.new()
			p.cooldown_override = 0.7
			pattern = p
		"whip":
			pattern = WavePattern.new()
		"scythe":
			pattern = CrossPattern.new()
		"claws":
			# Honor the GatlingPattern default 0.65 s cooldown. The old
			# 0.3 s override turned claws into a machine gun at 4× sword DPS
			# (post-Phase 1 maxi(1) floor no longer hides the cheat).
			pattern = GatlingPattern.new()
		_:
			pattern = SpreadPattern.new()
	_pattern_cache[wtype] = pattern
	weapon_pattern = pattern

func try_shoot(origin: Vector2, aim_direction: Vector2) -> void:
	if not can_shoot or weapon_pattern == null or equipment_manager == null:
		return

	can_shoot = false
	var cooldown = weapon_pattern.cooldown_override
	if cooldown <= 0.0:
		cooldown = equipment_manager.get_attack_speed()
	# Apply equipped attack-speed bonuses as a divisor so percent_bonus = 0.15
	# means +15% faster fire (lower cooldown), in line with every other percent
	# stat in the game. Base cooldown comes from the pattern or class stat.
	cooldown = cooldown / equipment_manager.get_attack_speed_mult()
	# Apply fire_rate buff from status effects (e.g. Battle Cry, Reckless Strike).
	var total_fire_mult = fire_rate_mult
	var p = get_parent()
	if p and p.get("status_effects") and p.status_effects.has_method("get_buff_multiplier"):
		total_fire_mult *= p.status_effects.get_buff_multiplier("fire_rate")
	# Mercenary Adrenaline: +0.5%/stack fire rate (up to +50% at full meter).
	if p and "class_meter" in p and p.has_method("_get_player_class") and p._get_player_class() == "mercenary":
		total_fire_mult *= 1.0 + p.class_meter * 0.005
	cooldown_timer.wait_time = maxf(cooldown / total_fire_mult, 0.05)
	cooldown_timer.start()
	# Notify the player that a shot was fired — archer uses this to detect
	# "aiming-down-sights" (stationary regen only when NOT shooting).
	if p and "_archer_shoot_grace" in p:
		p._archer_shoot_grace = 0.18

	var fire_data = weapon_pattern.get_fire_data(aim_direction, equipment_manager)

	if not is_inside_tree():
		return
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return

	# Archer Killshot: pull the meta off the player ONCE and attach the focus
	# spent to every bullet in this volley. This way multi-bullet patterns
	# (bow ParallelPattern, scatter, etc.) get the bonus on every arrow, not
	# just the first one through _spawn_bullet. Meta is cleared here so any
	# follow-up `try_shoot` (next frame) won't re-apply it.
	if p and p.has_meta("killshot_charge"):
		var _ks_focus = float(p.get_meta("killshot_focus_spent", 100.0))
		for d in fire_data:
			d["killshot_focus"] = _ks_focus
		p.remove_meta("killshot_charge")
		p.remove_meta("killshot_focus_spent")

	# SFX: fire sound based on weapon type. If the player has 0 proficiency
	# (off-class weapon with no stats allocated), play the error chime instead so
	# the swing/shoot still happens but feels obviously wrong.
	var sfx = get_node_or_null("/root/SFXManager")
	var _prof_zero = equipment_manager.has_method("get_proficiency_mult") and equipment_manager.get_proficiency_mult() <= 0.0
	if sfx:
		var weapon = equipment_manager.get_equipped_weapon()
		if weapon:
			if _prof_zero:
				sfx.play("error", -6.0, 0.0)
			else:
				match weapon.slot_type:
					EquipmentItem.SlotType.WEAPON_MELEE:
						sfx.play("swing", -9.0, 0.1)
					EquipmentItem.SlotType.WEAPON_RANGED:
						sfx.play("shoot_a", -12.0, 0.15)
					EquipmentItem.SlotType.WEAPON_MAGIC:
						# Wizard shot used to play "spell_a" at -9 dB every pull, which
						# read as constant explosions. Throttled to every 3rd cast and
						# halved in volume — the visual VFX carries the rest.
						_spell_fire_counter += 1
						if _spell_fire_counter >= 3:
							_spell_fire_counter = 0
							sfx.play("spell_a", -16.0, 0.18, 0.9)
					_:
						sfx.play("shoot_a", -12.0, 0.15)

	for data in fire_data:
		if data["delay"] > 0.0:
			_spawn_delayed(origin, data, bullets_container)
		else:
			_spawn_bullet(origin, data, bullets_container)

func _spawn_delayed(origin: Vector2, data: Dictionary, container: Node) -> void:
	get_tree().create_timer(data["delay"]).timeout.connect(
		func(): _spawn_bullet(origin, data, container))

func _spawn_bullet(origin: Vector2, data: Dictionary, container: Node) -> void:
	if not is_instance_valid(container):
		return
	var bullet = bullet_scene.instantiate()
	bullet.global_position = origin + data["offset"]
	bullet.direction = data["direction"]
	bullet.is_player_bullet = true
	var player = equipment_manager.get_parent()
	var projectile_scale = 0.25 if player and player.get("in_dungeon") else 1.0
	var p = get_parent()
	# Archer Focus: high focus → faster bullets + longer effective range.
	#  ≥75 focus: +20% bullet speed (and lifetime scales below for +20% range).
	#  50–74:    +10% / +10%.
	#  <50:      baseline.
	var _archer_speed_mult := 1.0
	var _archer_range_mult := 1.0
	if p and "class_meter" in p and p.has_method("_get_player_class"):
		var _pc_a = p._get_player_class()
		if _pc_a == "archer" or _pc_a == "ranger":
			var _f = float(p.class_meter)
			if _f >= 75.0:
				_archer_speed_mult = 1.2
				_archer_range_mult = 1.2
			elif _f >= 50.0:
				_archer_speed_mult = 1.1
				_archer_range_mult = 1.1
	bullet.speed = equipment_manager.get_bullet_speed() * projectile_scale * data["speed_mult"] * _archer_speed_mult
	var base_damage = equipment_manager.get_damage()
	# Apply damage_mult (e.g. crossbow aimed mode)
	if damage_mult != 1.0:
		base_damage = int(base_damage * damage_mult)
	# Apply damage buff from status effects (e.g. Battle Cry)
	if p and p.get("status_effects") and p.status_effects.has_method("get_buff_multiplier"):
		base_damage = int(base_damage * p.status_effects.get_buff_multiplier("damage"))
	# WEAKENED/STRENGTHENED damage multiplier
	if p and p.get("status_effects") and p.status_effects.has_method("get_damage_multiplier"):
		base_damage = int(base_damage * p.status_effects.get_damage_multiplier())
	# High-ground combat bonus: +20% damage per height level
	if p and p.has_method("get_high_ground_damage_mult"):
		base_damage = int(base_damage * p.get_high_ground_damage_mult())
	# Class-meter damage hooks. Phase 1 redesign:
	#  - Warrior: keep weapon-damage scaling (+0.3%/stack from Rage).
	#  - Mercenary: damage scaling REMOVED — fire rate + crit chance ramps replace it (above + below).
	#  - Archer: NO base-damage scaling (Killshot is the only damage spike); per-stack bullet speed/range applied to the bullet itself further down.
	#  - Wizard: damage scaling REMOVED — empowerment is the lever now.
	var _killshot_pierce_bonus := 0  # archer Killshot: +3 pierces, applied AFTER the equipment pierce line so it isn't overwritten
	var _killshot_force_crit := false
	var _rage_stack_for_splash := 0.0
	if p and "class_meter" in p:
		var pc = p._get_player_class() if p.has_method("_get_player_class") else ""
		var stack: float = p.class_meter
		if pc == "warrior":
			# Rage: up to +60% weapon damage at full stack (doubled from +30% —
			# the old number was too subtle to feel without a damage readout).
			base_damage = int(base_damage * (1.0 + stack * 0.006))
			_rage_stack_for_splash = stack
	# Killshot — read from per-bullet data, not player meta. All bullets in a
	# multi-bullet volley get the bonus because try_shoot stamps every fire_data
	# dict with `killshot_focus` before this loop runs.
	if data.has("killshot_focus"):
		var fs = float(data["killshot_focus"])
		var mult = 3.0 + clampf(fs / 100.0, 0.0, 1.0) * 2.0
		base_damage = int(base_damage * mult)
		_killshot_pierce_bonus = 3
		_killshot_force_crit = true
	# Per-bullet damage split from pattern (e.g. shotgun pellets share total damage)
	if data.has("damage_mult"):
		base_damage = maxi(1, int(base_damage * data["damage_mult"]))

	# Crit roll: chance = luck / 2 %
	var luck = equipment_manager.get_luck()
	var crit_chance = luck / 2.0 + crit_bonus
	# High-ground combat bonus: +10 crit chance per height level
	if p and p.has_method("get_high_ground_crit_bonus"):
		crit_chance += p.get_high_ground_crit_bonus()
	# Mercenary Adrenaline: +0.15%/stack passive crit chance (up to +15% at full meter).
	if p and "class_meter" in p and p.has_method("_get_player_class") and p._get_player_class() == "mercenary":
		crit_chance += p.class_meter * 0.15
	# Killshot is a guaranteed crit — bypasses the RNG roll so the design-doc
	# 3-5× damage stacks WITH the crit-damage multiplier, and the bullet gets
	# the scaled-up "crit" sprite + crit_spark VFX on impact for free.
	if _killshot_force_crit:
		bullet.is_crit = true
		bullet.damage = int(base_damage * equipment_manager.get_crit_damage())
	elif crit_chance > 0 and randf() * 100.0 < crit_chance:
		bullet.is_crit = true
		bullet.damage = int(base_damage * equipment_manager.get_crit_damage())
		# Mercenary: every crit landed adds +1 to Adrenaline.
		if p and p.has_method("on_crit_landed"):
			p.on_crit_landed()
	else:
		bullet.damage = base_damage

	bullet.pierce_count = equipment_manager.get_pierce_count()
	# Pattern-specified pierce bonus (e.g. spear trident center bullet)
	if data.has("pierce"):
		bullet.pierce_count += data["pierce"]
	# Killshot pierce bonus — applied AFTER equipment so it survives.
	if _killshot_pierce_bonus > 0:
		bullet.pierce_count += _killshot_pierce_bonus
	# Killshot bullets get an extra ~40% sprite scale on top of the crit pop
	# (bullet._ready() reads sprite_scale_mult to multiply the final sprite).
	if _killshot_force_crit:
		bullet.set_meta("sprite_scale_mult", 1.4)
	bullet.lifetime = equipment_manager.get_bullet_lifetime()

	# Apply weapon-specific bullet sprite and range
	bullet.bullet_sprite_index = equipment_manager.get_bullet_sprite_index()
	var wrange = equipment_manager.get_weapon_range()
	if wrange > 0.0:
		# Convert range to lifetime: lifetime = range / speed (in seconds)
		# In dungeon (8px tiles) scale is 4x smaller than overworld (32px tiles)
		var range_scale = 1.0
		player = equipment_manager.get_parent()
		if player and player.get("in_dungeon"):
			range_scale = 0.25
		bullet.lifetime = wrange * range_scale * _archer_range_mult / maxf(bullet.speed, 1.0) * 100.0

	# Apply bullet modifiers from equipment
	for item in equipment_manager.get_equipped_items():
		for bmod in item.bullet_modifiers:
			match bmod.type:
				BulletModifier.ModType.HOMING:
					bullet.homing_strength = bmod.strength
				BulletModifier.ModType.PIERCE:
					bullet.pierce_count += int(bmod.strength)

	# Ranger distance scaling on ranged weapons
	var weapon = equipment_manager.get_equipped_weapon()
	if weapon and weapon.slot_type == EquipmentItem.SlotType.WEAPON_RANGED:
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.get("selected_class") == "ranger":
			bullet.distance_scaling = true

	# Apply enchantment from equipped weapon
	if weapon and weapon.enchantment:
		bullet.enchant_type = weapon.enchantment.type
		bullet.enchant_proc_chance = weapon.enchantment.proc_chance
		bullet.enchant_bonus_damage = weapon.enchantment.bonus_damage

	# Apply ability buff on-hit effects (Fire Fists, Venom Coat)
	if p:
		if p.get_meta("fire_fists_active", false):
			bullet.set_meta("apply_burning", 3.0)
		if p.get_meta("venom_coat_active", false):
			bullet.set_meta("apply_poison", 4.0)

	# Spell staff unique on-hit effects (based on weapon name)
	if weapon:
		match weapon.item_name:
			"Frost Bolt":
				bullet.set_meta("apply_slowed", 2.0)
			"Freeze":
				bullet.set_meta("apply_frozen", 1.5)
			"Flashbang":
				bullet.set_meta("apply_stunned", 1.0)
			"Weaken":
				bullet.set_meta("apply_slowed", 3.0)
			"Explosion":
				bullet.set_meta("fireball_aoe", true)
				bullet.set_meta("fireball_aoe_radius", 24.0)
				bullet.set_meta("fireball_aoe_dmg_pct", 0.8)
			"Magic Missile":
				bullet.pierce_count += 2
			"Smite":
				bullet.set_meta("apply_stunned", 0.5)
			"Corlion":
				bullet.set_meta("apply_confused", 2.0)
			"Malorian Crook":
				bullet.set_meta("apply_feared", 2.0)

	# Arrow/throwing ammo effects. The weapon's projectile class has to match
	# the ammo's ammo_type — slings can't fire arrows, bows can't fire stones,
	# javelins can't fire throwing knives. Empty ammo_type defaults to "arrow"
	# for back-compat with the existing fire_arrow / freeze_arrow / etc. .tres.
	var uses_ammo = weapon and (weapon.slot_type == EquipmentItem.SlotType.WEAPON_RANGED or weapon.weapon_type in ["throwing", "javelin"])
	if uses_ammo:
		var ammo = equipment_manager.get_equipped_ammo()
		if ammo and ammo.quantity > 0 and ammo.arrow_effect != "":
			var expected_ammo: Array = WEAPON_AMMO_TYPES.get(weapon.weapon_type, [])
			var ammo_kind: String = ammo.ammo_type if ammo.ammo_type != "" else "arrow"
			if expected_ammo.is_empty() or ammo_kind in expected_ammo:
				_apply_arrow_effects(bullet, ammo)
				equipment_manager.consume_ammo()

	# Cliff respect: default is slot-based (melee blocked, ranged passes through). Designers
	# can override per-weapon via EquipmentItem.cliff_respect (Auto / Blocked / Passes).
	if weapon:
		match weapon.cliff_respect:
			1:  # forced blocked
				bullet.is_melee = true
			2:  # forced pass-through
				bullet.is_melee = false
			_:  # auto: slot-based default
				if weapon.slot_type == EquipmentItem.SlotType.WEAPON_MELEE \
					and weapon.weapon_type not in ["throwing", "javelin"]:
					bullet.is_melee = true

	# Warrior Rage Splash — at ≥50 rage, every melee swing creates a tiny AoE
	# splash on hit. Bullet reads `rage_splash_radius` / `rage_splash_dmg_pct`
	# in its hurtbox hit path to damage nearby enemies. Felt on every swing,
	# unlike the silent +%damage bonus.
	if _rage_stack_for_splash >= 50.0 and weapon and weapon.slot_type == EquipmentItem.SlotType.WEAPON_MELEE:
		bullet.set_meta("rage_splash_radius", 24.0)
		bullet.set_meta("rage_splash_dmg_pct", 0.5)

	# Hammer Shift — replaces the old walking-slam loop. While shift is held
	# (_earthquake_active), every hammer swing gets the same AoE splash the
	# warrior sword gets at ≥50 rage. Hammer is class-agnostic on this — any
	# class can equip a hammer and get the splash by holding shift, since the
	# whole hammer identity is "AoE swings with movement penalty".
	if weapon and weapon.weapon_type == "hammer" and p and p.get("_earthquake_active"):
		bullet.set_meta("rage_splash_radius", 24.0)
		bullet.set_meta("rage_splash_dmg_pct", 0.5)
		bullet.set_meta("rage_splash_color", Color(0.55, 0.40, 0.20, 0.65))


	container.add_child(bullet)
	# Coop: notify peers so they can render a visual ghost of this player bullet.
	# Damage routing for any hit on enemies stays inside bullet.gd (RPC to host).
	var coop_rt = get_node_or_null("/root/CoopRuntime")
	if coop_rt and coop_rt.has_method("broadcast_player_bullet"):
		coop_rt.broadcast_player_bullet(bullet.global_position, bullet.direction, bullet.speed, bullet.bullet_sprite_index)

func _apply_arrow_effects(bullet, ammo: EquipmentItem) -> void:
	# Arrows add +50% bonus damage on top of weapon base
	bullet.damage = int(ceil(bullet.damage * 1.5))
	match ammo.arrow_effect:
		"fire":
			bullet.set_meta("apply_burning", 5.0)
			bullet.set_meta("fire_arrow_spread", true)
			bullet.set_meta("projectile_fx_kind", "fire")
			bullet.set_meta("projectile_fx_energy", 0.95)
			bullet.modulate = Color(1.0, 0.6, 0.2)
		"freeze":
			bullet.set_meta("apply_frozen", 3.0)  # 3s full freeze
			bullet.set_meta("projectile_fx_kind", "frost")
			bullet.set_meta("projectile_fx_energy", 0.9)
			bullet.modulate = Color(0.5, 0.9, 1.0)
		"explosion":
			bullet.set_meta("fireball_aoe", true)
			bullet.set_meta("fireball_aoe_radius", 48.0)  # 6 tiles in dungeon
			bullet.set_meta("fireball_aoe_dmg_pct", 1.2)  # 120% weapon damage AoE
			bullet.set_meta("projectile_fx_kind", "fire")
			bullet.set_meta("projectile_fx_energy", 1.15)
			bullet.modulate = Color(1.0, 0.4, 0.1)
		"poison":
			bullet.set_meta("apply_poison", 6.0)  # 6s poison, stackable
			bullet.set_meta("poison_stackable", true)
			bullet.set_meta("projectile_fx_kind", "poison")
			bullet.set_meta("projectile_fx_energy", 0.95)
			bullet.modulate = Color(0.4, 1.0, 0.3)
		"lightning":
			bullet.set_meta("chain_lightning_arrow", true)  # custom chain, not enchant
			bullet.set_meta("projectile_fx_kind", "lightning")
			bullet.set_meta("projectile_fx_energy", 1.05)
			bullet.modulate = Color(0.8, 0.8, 1.0)
		"slow":
			bullet.set_meta("apply_slowed", 5.0)  # 5s heavy slow
			bullet.set_meta("projectile_fx_kind", "frost")
			bullet.set_meta("projectile_fx_energy", 0.8)
			bullet.modulate = Color(0.4, 0.6, 1.0)
		"throwing_knife":
			bullet.damage = int(ceil(bullet.damage * 0.87))  # 1.5 * 0.87 ≈ 1.3x total
			bullet.pierce_count += 1
		"javelin":
			bullet.damage = int(ceil(bullet.damage * 1.2))  # 1.5 * 1.2 ≈ 1.8x total
			bullet.pierce_count += 3
		"poison_knife":
			bullet.set_meta("apply_poison", 5.0)
			bullet.set_meta("poison_stackable", true)
			bullet.modulate = Color(0.4, 1.0, 0.3)
		"explosive_javelin":
			bullet.set_meta("fireball_aoe", true)
			bullet.set_meta("fireball_aoe_radius", 40.0)
			bullet.set_meta("fireball_aoe_dmg_pct", 1.0)
			bullet.modulate = Color(1.0, 0.4, 0.1)
