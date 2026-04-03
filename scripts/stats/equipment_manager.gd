class_name EquipmentManager
extends Node

@export var base_stats: PlayerStats

# Equipped items by slot (up to 12 simultaneous)
var equipped: Dictionary = {}  # SlotType -> EquipmentItem
# Inventory bag
var inventory: Array[EquipmentItem] = []
const MAX_INVENTORY = 9999  # effectively unlimited

signal stats_changed
signal inventory_changed

func _ready() -> void:
	if not base_stats:
		base_stats = PlayerStats.new()

func add_to_inventory(item: EquipmentItem) -> bool:
	if inventory.size() >= MAX_INVENTORY:
		return false
	inventory.append(item)
	inventory_changed.emit()
	return true

func remove_from_inventory(index: int) -> EquipmentItem:
	if index < 0 or index >= inventory.size():
		return null
	var item = inventory[index]
	inventory.remove_at(index)
	inventory_changed.emit()
	return item

func toggle_equip(inv_index: int) -> void:
	if inv_index < 0 or inv_index >= inventory.size():
		return
	var item = inventory[inv_index]
	var slot = item.slot_type
	if not EquipmentItem.is_equippable(slot):
		return

	# If this item is already equipped, unequip it
	if equipped.has(slot) and equipped[slot] == item:
		equipped.erase(slot)
	else:
		# Weapons are exclusive — equipping one unequips all other weapon types
		if EquipmentItem.is_weapon_slot(slot):
			for ws in [EquipmentItem.SlotType.WEAPON_MELEE, EquipmentItem.SlotType.WEAPON_RANGED, EquipmentItem.SlotType.WEAPON_MAGIC]:
				equipped.erase(ws)
		equipped[slot] = item
	stats_changed.emit()
	inventory_changed.emit()

signal use_effect_triggered(effect: String)

func use_consumable(inv_index: int) -> bool:
	if inv_index < 0 or inv_index >= inventory.size():
		return false
	var item = inventory[inv_index]
	if item.slot_type != EquipmentItem.SlotType.CONSUMABLE:
		return false

	var sfx = get_node_or_null("/root/SFXManager")
	var vfx = get_node_or_null("/root/VFXManager")

	# Special use effects
	if item.use_effect != "":
		inventory.remove_at(inv_index)
		inventory_changed.emit()
		var player = get_tree().get_first_node_in_group("player")
		match item.use_effect:
			"cure_poison":
				if player and player.has_node("StatusEffectManager"):
					player.get_node("StatusEffectManager").remove_all_of_type(StatusEffect.Type.POISONED)
				if vfx and player:
					vfx.status_puff(player.global_position, "CURE")
				if sfx:
					sfx.play("heal_a", -4.0)
			"restore_stamina":
				if player and "stamina" in player and "max_stamina" in player:
					player.stamina = player.max_stamina
					if player.has_signal("stamina_changed"):
						player.stamina_changed.emit(player.stamina)
				if sfx:
					sfx.play("heal_a", -4.0)
			"iron_skin":
				if player and player.has_node("StatusEffectManager"):
					player.get_node("StatusEffectManager").apply_buff("armor", 30.0, 5.0)
				if vfx and player:
					vfx.shockwave(player.global_position, 16.0, Color(0.8, 0.7, 0.3, 0.5))
				if sfx:
					sfx.play("mystical", -4.0)
			"xp_boost":
				if player and player.has_node("StatusEffectManager"):
					player.get_node("StatusEffectManager").apply_buff("xp", 60.0, 0.5)
				if vfx and player:
					vfx.gold_sparkle(player.global_position)
				if sfx:
					sfx.play("mystical", -4.0)
			"fire_aoe":
				if player:
					_do_flask_aoe(player, "BURNING", 15, 40.0, 3.0, Color(1.0, 0.4, 0.1, 0.7), false)
			"ice_aoe":
				if player:
					_do_flask_aoe(player, "SLOWED", 10, 40.0, 4.0, Color(0.3, 0.5, 1.0, 0.7), true)
			"poison_aoe":
				if player:
					_do_flask_aoe(player, "POISONED", 12, 40.0, 4.0, Color(0.3, 0.9, 0.2, 0.7), false)
				if vfx and player:
					vfx.status_puff(player.global_position, "POISON")
			"heal_cure":
				if player:
					player.heal(item.heal_hp)
					if vfx:
						vfx.status_puff(player.global_position, "HEAL")
					if player.has_node("StatusEffectManager"):
						player.get_node("StatusEffectManager").remove_all_of_type(StatusEffect.Type.POISONED)
				if sfx:
					sfx.play("heal_a", -4.0)
			"speed_boost":
				if player and player.has_node("StatusEffectManager"):
					player.get_node("StatusEffectManager").apply_buff("speed", 30.0, 0.25)
				if vfx and player:
					vfx.gold_sparkle(player.global_position)
				if sfx:
					sfx.play("mystical", -4.0)
			"stun_aoe":
				if player:
					_do_stun_aoe(player, 48.0, 2.0)
				if sfx:
					sfx.play("area_effect_a", -3.0)
			"pushback_aoe":
				if player:
					_do_pushback_aoe(player, 48.0, 200.0)
				if sfx:
					sfx.play("area_effect_a", -3.0)
			"stealth_buff":
				if player:
					player._sneaking = true
					if player.has_node("StatusEffectManager"):
						player.get_node("StatusEffectManager").apply_buff("stealth", 15.0, 50.0)
				if vfx and player:
					vfx.status_puff(player.global_position, "STEALTH")
				if sfx:
					sfx.play("mystical", -4.0)
			"berserk":
				if player and player.has_node("StatusEffectManager"):
					var sem = player.get_node("StatusEffectManager")
					sem.apply_buff("damage", 10.0, 1.0)  # +100% dmg
					sem.apply_buff("speed", 10.0, 0.5)  # +50% speed
					sem.apply_buff("armor", 10.0, -0.5)  # -50% armor
				if vfx and player:
					vfx.shockwave(player.global_position, 20.0, Color(1.0, 0.2, 0.2, 0.6))
				if sfx:
					sfx.play("area_effect_a", -2.0)
			"damage_buff":
				if player and player.has_node("StatusEffectManager"):
					player.get_node("StatusEffectManager").apply_buff("damage", 30.0, 0.3)
				if vfx and player:
					vfx.status_puff(player.global_position, "POWER")
				if sfx:
					sfx.play("mystical", -4.0)
			"town_portal":
				use_effect_triggered.emit("town_portal")
				if sfx:
					sfx.play("teleport", -2.0, 0.0)
				return true
			_:
				if sfx:
					sfx.play("heal_a", -4.0)
		use_effect_triggered.emit(item.use_effect)
		return true

	# HP/MP healing consumables
	if item.heal_hp <= 0 and item.heal_mp <= 0:
		return false
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return false
	if item.heal_hp > 0:
		player.heal(item.heal_hp)
		if vfx:
			vfx.status_puff(player.global_position, "HEAL")
	if item.heal_mp > 0:
		player.mp = minf(player.mp + item.heal_mp, player.max_mp)
		player.mp_changed.emit(player.mp)
		var scene_root = get_tree().current_scene
		if scene_root:
			FloatingText.spawn(scene_root, player.global_position + Vector2(0, -4), "+%d MP" % int(item.heal_mp), Color(0.3, 0.5, 1.0))
	if sfx:
		sfx.play("heal_a", -4.0)
	inventory.remove_at(inv_index)
	inventory_changed.emit()
	return true

func _do_flask_aoe(player: CharacterBody2D, status: String, damage: int, radius: float, duration: float, color: Color, is_ice: bool) -> void:
	var ow_scale = 4.0 if get_tree().current_scene.name == "Overworld" else 1.0
	var actual_radius = radius * ow_scale
	var sfx = get_node_or_null("/root/SFXManager")
	var vfx = get_node_or_null("/root/VFXManager")
	# Damage and apply status to nearby enemies
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(player.global_position) < actual_radius:
			if e.has_method("take_damage"):
				e.take_damage(damage)
			if e.has_method("apply_status"):
				e.apply_status(status, duration)
	# VFX
	if vfx:
		if is_ice:
			vfx.frost_ring(player.global_position, actual_radius)
		else:
			vfx.shockwave(player.global_position, actual_radius, color)
		vfx.shake(1.5, 0.12)
	# SFX
	if sfx:
		if is_ice:
			sfx.play("sorcery", -2.0)
		else:
			sfx.play("boom_a", -2.0)

func _do_stun_aoe(player: CharacterBody2D, radius: float, duration: float) -> void:
	var ow_scale = 4.0 if get_tree().current_scene.name == "Overworld" else 1.0
	var actual_radius = radius * ow_scale
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(player.global_position) < actual_radius:
			if e.has_method("apply_status"):
				e.apply_status("STUNNED", duration)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(player.global_position, actual_radius, Color(1.0, 1.0, 0.3, 0.5))
		vfx.shake(2.0, 0.15)

func _do_pushback_aoe(player: CharacterBody2D, radius: float, force: float) -> void:
	var ow_scale = 4.0 if get_tree().current_scene.name == "Overworld" else 1.0
	var actual_radius = radius * ow_scale
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var dist = e.global_position.distance_to(player.global_position)
		if dist < actual_radius:
			var kb_dir = (e.global_position - player.global_position).normalized()
			e.velocity = kb_dir * force * ow_scale
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(player.global_position, actual_radius, Color(0.5, 0.7, 1.0, 0.5))
		vfx.shake(1.5, 0.1)

func is_equipped(item: EquipmentItem) -> bool:
	for equipped_item in equipped.values():
		if equipped_item == item:
			return true
	return false

# Legacy compatibility
func equip_from_inventory(inv_index: int) -> void:
	toggle_equip(inv_index)

func unequip_to_inventory(slot: EquipmentItem.SlotType) -> void:
	if not equipped.has(slot):
		return
	equipped.erase(slot)
	stats_changed.emit()
	inventory_changed.emit()

# Legacy — just adds to bag
func equip(item: EquipmentItem) -> void:
	add_to_inventory(item)

var level_system: LevelSystem  # Set by player on ready

func get_stat(stat_type: StatModifier.StatType) -> float:
	var base_value: float = _get_base_value(stat_type)
	var flat_sum: float = 0.0
	var percent_sum: float = 0.0

	# Level bonuses
	if level_system:
		flat_sum += level_system.get_level_bonus(stat_type)
		flat_sum += level_system.get_allocation_bonus(stat_type)

	# All equipped items contribute stats
	for item in equipped.values():
		for mod in item.modifiers:
			if mod.stat == stat_type:
				flat_sum += mod.flat_bonus
				percent_sum += mod.percent_bonus

	return (base_value + flat_sum) * (1.0 + percent_sum)

func _get_base_value(stat_type: StatModifier.StatType) -> float:
	match stat_type:
		StatModifier.StatType.MAX_HP: return base_stats.max_hp
		StatModifier.StatType.MOVE_SPEED: return base_stats.move_speed
		StatModifier.StatType.ATTACK_DAMAGE: return base_stats.attack_damage
		StatModifier.StatType.ATTACK_SPEED: return base_stats.attack_speed
		StatModifier.StatType.BULLET_SPEED: return base_stats.bullet_speed
		StatModifier.StatType.BULLET_COUNT: return base_stats.bullet_count
		StatModifier.StatType.SPREAD_ANGLE: return base_stats.spread_angle
		StatModifier.StatType.PIERCE_COUNT: return base_stats.pierce_count
		StatModifier.StatType.BULLET_LIFETIME: return base_stats.bullet_lifetime
		StatModifier.StatType.MAX_MP: return base_stats.max_mp
		StatModifier.StatType.HP_REGEN: return base_stats.hp_regen
		StatModifier.StatType.MP_REGEN: return base_stats.mp_regen
		StatModifier.StatType.LUCK: return base_stats.luck
		StatModifier.StatType.CRIT_DAMAGE: return base_stats.crit_damage
		StatModifier.StatType.ARMOR: return base_stats.armor
		StatModifier.StatType.WEIGHT: return base_stats.weight
		StatModifier.StatType.ACCELERATION: return base_stats.acceleration
		StatModifier.StatType.DODGE_CHANCE: return base_stats.dodge_chance
		StatModifier.StatType.XP_MULT: return base_stats.xp_mult
		StatModifier.StatType.GOLD_MULT: return base_stats.gold_mult
		StatModifier.StatType.PICKUP_RADIUS: return base_stats.pickup_radius
		StatModifier.StatType.COOLDOWN_REDUCTION: return base_stats.cooldown_reduction
		StatModifier.StatType.STEALTH: return base_stats.stealth
		StatModifier.StatType.MAX_STAMINA: return base_stats.max_stamina
		StatModifier.StatType.STAMINA_REGEN: return base_stats.stamina_regen
		StatModifier.StatType.TENACITY: return base_stats.tenacity
		StatModifier.StatType.THORNS: return base_stats.thorns
	return 0.0

# Convenience getters
func get_move_speed() -> float: return get_stat(StatModifier.StatType.MOVE_SPEED)
func get_attack_speed() -> float: return get_stat(StatModifier.StatType.ATTACK_SPEED)
func get_damage() -> int: return int(get_stat(StatModifier.StatType.ATTACK_DAMAGE))
func get_bullet_speed() -> float: return get_stat(StatModifier.StatType.BULLET_SPEED)
func get_bullet_count() -> int: return int(get_stat(StatModifier.StatType.BULLET_COUNT))
func get_spread_angle() -> float: return get_stat(StatModifier.StatType.SPREAD_ANGLE)
func get_pierce_count() -> int: return int(get_stat(StatModifier.StatType.PIERCE_COUNT))
func get_max_hp() -> int: return int(get_stat(StatModifier.StatType.MAX_HP))
func get_bullet_lifetime() -> float: return get_stat(StatModifier.StatType.BULLET_LIFETIME)
func get_max_mp() -> float: return get_stat(StatModifier.StatType.MAX_MP)
func get_hp_regen() -> float: return get_stat(StatModifier.StatType.HP_REGEN)
func get_mp_regen() -> float: return get_stat(StatModifier.StatType.MP_REGEN)
func get_luck() -> float: return get_stat(StatModifier.StatType.LUCK)
func get_crit_damage() -> float: return get_stat(StatModifier.StatType.CRIT_DAMAGE)
func get_armor() -> float: return get_stat(StatModifier.StatType.ARMOR)
func get_weight() -> float: return get_stat(StatModifier.StatType.WEIGHT)
func get_acceleration() -> float: return get_stat(StatModifier.StatType.ACCELERATION)
func get_dodge_chance() -> float: return get_stat(StatModifier.StatType.DODGE_CHANCE)
func get_xp_mult() -> float: return get_stat(StatModifier.StatType.XP_MULT)
func get_gold_mult() -> float: return get_stat(StatModifier.StatType.GOLD_MULT)
func get_pickup_radius() -> float: return get_stat(StatModifier.StatType.PICKUP_RADIUS)
func get_cooldown_reduction() -> float: return get_stat(StatModifier.StatType.COOLDOWN_REDUCTION)
func get_stealth() -> float: return get_stat(StatModifier.StatType.STEALTH)
func get_max_stamina() -> float: return get_stat(StatModifier.StatType.MAX_STAMINA)
func get_stamina_regen() -> float: return get_stat(StatModifier.StatType.STAMINA_REGEN)
func get_tenacity() -> float: return clampf(get_stat(StatModifier.StatType.TENACITY), 0.0, 80.0)
func get_thorns() -> float: return get_stat(StatModifier.StatType.THORNS)

# Total gear score from all equipped items (sum of flat + percent bonuses weighted)
func get_gear_score() -> int:
	var score: float = 0.0
	for item in equipped.values():
		if not item:
			continue
		for mod in item.modifiers:
			# Flat bonuses: damage counts most, HP next, others less
			match mod.stat:
				StatModifier.StatType.ATTACK_DAMAGE:
					score += mod.flat_bonus * 5.0 + mod.percent_bonus * 20.0
				StatModifier.StatType.MAX_HP:
					score += mod.flat_bonus * 0.3 + mod.percent_bonus * 15.0
				StatModifier.StatType.ARMOR:
					score += mod.flat_bonus * 2.0 + mod.percent_bonus * 10.0
				_:
					score += mod.flat_bonus * 1.0 + mod.percent_bonus * 8.0
	return int(score)

# Full power level: level + stat points + gear
func get_power_level() -> int:
	var base_power: int = 0
	if level_system:
		base_power = level_system.get_power_level()
	return base_power + get_gear_score()

# Returns the primary equipped weapon (melee > ranged > magic priority)
func get_equipped_weapon() -> EquipmentItem:
	for slot in [EquipmentItem.SlotType.WEAPON_MELEE, EquipmentItem.SlotType.WEAPON_RANGED, EquipmentItem.SlotType.WEAPON_MAGIC]:
		if equipped.has(slot):
			return equipped[slot]
	return null

func get_bullet_sprite_index() -> int:
	var weapon = get_equipped_weapon()
	if weapon and weapon.bullet_sprite_index >= 0:
		return weapon.bullet_sprite_index
	return -1

func get_weapon_range() -> float:
	var weapon = get_equipped_weapon()
	if weapon and weapon.weapon_range > 0.0:
		return weapon.weapon_range
	return 0.0

# Get all equipped items as flat array (for bullet modifier iteration etc.)
func get_equipped_items() -> Array[EquipmentItem]:
	var result: Array[EquipmentItem] = []
	for item in equipped.values():
		result.append(item)
	return result
