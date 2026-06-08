class_name WeaponSystem
extends Node

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
			var p = GatlingPattern.new()
			p.cooldown_override = 0.3
			pattern = p
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
	# Apply fire_rate buff from status effects (e.g. Battle Cry)
	var total_fire_mult = fire_rate_mult
	var p = get_parent()
	if p and p.get("status_effects") and p.status_effects.has_method("get_buff_multiplier"):
		total_fire_mult *= p.status_effects.get_buff_multiplier("fire_rate")
	cooldown_timer.wait_time = maxf(cooldown / total_fire_mult, 0.05)
	cooldown_timer.start()

	var fire_data = weapon_pattern.get_fire_data(aim_direction, equipment_manager)

	if not is_inside_tree():
		return
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return

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
						sfx.play("shoot_a", -9.0, 0.1)
					EquipmentItem.SlotType.WEAPON_MAGIC:
						sfx.play("spell_a", -9.0, 0.1)
					_:
						sfx.play("shoot_a", -9.0, 0.1)

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
	bullet.speed = equipment_manager.get_bullet_speed() * data["speed_mult"]
	var base_damage = equipment_manager.get_damage()
	# Apply damage_mult (e.g. crossbow aimed mode)
	if damage_mult != 1.0:
		base_damage = int(base_damage * damage_mult)
	# Apply damage buff from status effects (e.g. Battle Cry)
	var p = get_parent()
	if p and p.get("status_effects") and p.status_effects.has_method("get_buff_multiplier"):
		base_damage = int(base_damage * p.status_effects.get_buff_multiplier("damage"))
	# WEAKENED/STRENGTHENED damage multiplier
	if p and p.get("status_effects") and p.status_effects.has_method("get_damage_multiplier"):
		base_damage = int(base_damage * p.status_effects.get_damage_multiplier())
	# High-ground combat bonus: +20% damage per height level
	if p and p.has_method("get_high_ground_damage_mult"):
		base_damage = int(base_damage * p.get_high_ground_damage_mult())
	# Class-meter damage hooks — passive ramps that scale with current stack.
	# Meters are NEVER consumed; they decay over time so the player stays in
	# their "rhythm zone" by repeating the build-action (kills, casts, focused
	# hits, swaps). At 100 stacks the effect peaks; at 0 there's no bonus.
	if p and "class_meter" in p:
		var pc = p._get_player_class() if p.has_method("_get_player_class") else ""
		var stack: float = p.class_meter
		if pc == "warrior":
			# Rage: up to +30% damage at full stack
			base_damage = int(base_damage * (1.0 + stack * 0.003))
		elif pc == "wizard":
			# Mana Flow: up to +25% damage at full stack
			base_damage = int(base_damage * (1.0 + stack * 0.0025))
			# Arcane Surge meter-full move — next 3 spells +75% damage and free MP
			if p.has_meta("arcane_surge_charges"):
				var charges = int(p.get_meta("arcane_surge_charges"))
				if charges > 0:
					base_damage = int(base_damage * 1.75)
					p.set_meta("arcane_surge_charges", charges - 1)
					if charges - 1 <= 0:
						p.remove_meta("arcane_surge_charges")
		elif pc == "ranger" or pc == "archer":
			# Focus: up to +35% damage at full stack (precision builds)
			base_damage = int(base_damage * (1.0 + stack * 0.0035))
			# Killshot meter-full move — next shot is a 5× crit that pierces all
			if p.has_meta("killshot_charge"):
				base_damage = int(base_damage * 5.0)
				bullet.set("_hits_remaining", 9999)
				p.remove_meta("killshot_charge")
		elif pc == "mercenary":
			# Adrenaline: up to +25% damage at full stack
			base_damage = int(base_damage * (1.0 + stack * 0.0025))
	# Per-bullet damage split from pattern (e.g. shotgun pellets share total damage)
	if data.has("damage_mult"):
		base_damage = maxi(1, int(base_damage * data["damage_mult"]))

	# Crit roll: chance = luck / 2 %
	var luck = equipment_manager.get_luck()
	var crit_chance = luck / 2.0 + crit_bonus
	# High-ground combat bonus: +10 crit chance per height level
	if p and p.has_method("get_high_ground_crit_bonus"):
		crit_chance += p.get_high_ground_crit_bonus()
	if crit_chance > 0 and randf() * 100.0 < crit_chance:
		bullet.is_crit = true
		bullet.damage = int(base_damage * equipment_manager.get_crit_damage())
	else:
		bullet.damage = base_damage

	bullet.pierce_count = equipment_manager.get_pierce_count()
	# Pattern-specified pierce bonus (e.g. spear trident center bullet)
	if data.has("pierce"):
		bullet.pierce_count += data["pierce"]
	bullet.lifetime = equipment_manager.get_bullet_lifetime()

	# Apply weapon-specific bullet sprite and range
	bullet.bullet_sprite_index = equipment_manager.get_bullet_sprite_index()
	var wrange = equipment_manager.get_weapon_range()
	if wrange > 0.0:
		# Convert range to lifetime: lifetime = range / speed (in seconds)
		# In dungeon (8px tiles) scale is 4x smaller than overworld (32px tiles)
		var range_scale = 1.0
		var player = equipment_manager.get_parent()
		if player and player.get("in_dungeon"):
			range_scale = 0.25
		bullet.lifetime = wrange * range_scale / maxf(bullet.speed, 1.0) * 100.0

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

	# Arrow/throwing ammo effects (ranged weapons + throwing/javelin melee)
	var uses_ammo = weapon and (weapon.slot_type == EquipmentItem.SlotType.WEAPON_RANGED or weapon.weapon_type in ["throwing", "javelin"])
	if uses_ammo:
		var ammo = equipment_manager.get_equipped_ammo()
		if ammo and ammo.quantity > 0 and ammo.arrow_effect != "":
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
