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
signal equip_failed(item: EquipmentItem)

var _save_pending: bool = false

func _ready() -> void:
	if not base_stats:
		base_stats = PlayerStats.new()
	inventory_changed.connect(_on_inventory_changed)

func _on_inventory_changed() -> void:
	# Debounce saves so bulk operations only write once per frame
	if _save_pending:
		return
	_save_pending = true
	call_deferred("_flush_save")

func _flush_save() -> void:
	_save_pending = false
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("save_equipment"):
		gm.save_equipment(self)

func add_to_inventory(item: EquipmentItem) -> bool:
	if inventory.size() >= MAX_INVENTORY:
		return false
	# Stack ammo: if same arrow type already in inventory, add quantity
	if item.slot_type == EquipmentItem.SlotType.AMMO and item.quantity > 0:
		for existing in inventory:
			if existing.slot_type == EquipmentItem.SlotType.AMMO and existing.item_name == item.item_name:
				existing.quantity = mini(existing.quantity + item.quantity, maxi(existing.max_quantity, 99))
				inventory_changed.emit()
				return true
		# Also check equipped ammo
		var eq_ammo = get_equipped_ammo()
		if eq_ammo and eq_ammo.item_name == item.item_name:
			eq_ammo.quantity = mini(eq_ammo.quantity + item.quantity, maxi(eq_ammo.max_quantity, 99))
			inventory_changed.emit()
			return true
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
		_on_item_unequipped(item)
		equipped.erase(slot)
	else:
		# Check equipment restrictions before equipping
		var gm = get_node_or_null("/root/GameManager")
		var pc = gm.selected_class if gm and gm.get("selected_class") else "warrior"
		var lvl = level_system.level if level_system else 1
		var alloc = level_system.allocated if level_system else {}
		if not item.can_equip(pc, lvl, alloc):
			equip_failed.emit(item)
			return
		# Weapons are exclusive — equipping one unequips all other weapon types
		if EquipmentItem.is_weapon_slot(slot):
			for ws in [EquipmentItem.SlotType.WEAPON_MELEE, EquipmentItem.SlotType.WEAPON_RANGED, EquipmentItem.SlotType.WEAPON_MAGIC]:
				if equipped.has(ws):
					_on_item_unequipped(equipped[ws])
				equipped.erase(ws)
		elif equipped.has(slot):
			_on_item_unequipped(equipped[slot])
		equipped[slot] = item
		_on_item_equipped(item)
	stats_changed.emit()
	inventory_changed.emit()

func _on_item_equipped(item: EquipmentItem) -> void:
	if item.grants_spell != "":
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var spell_book = player.get_node_or_null("SpellBook")
			if spell_book:
				spell_book.learn_spell_from_equipment(item.grants_spell)

func _on_item_unequipped(item: EquipmentItem) -> void:
	if item.grants_spell != "":
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var spell_book = player.get_node_or_null("SpellBook")
			if spell_book:
				spell_book.unlearn_spell_from_equipment(item.grants_spell)

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
			"restore_stamina_partial":
				if player and "stamina" in player and "max_stamina" in player:
					player.stamina = minf(player.stamina + 40.0, player.max_stamina)
					if player.has_signal("stamina_changed"):
						player.stamina_changed.emit(player.stamina)
				if sfx:
					sfx.play("heal_a", -4.0)
				if vfx and player:
					vfx.status_puff(player.global_position, "HEAL")
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
					sem.apply_buff("damage", 10.0, 1.0)
					sem.apply_buff("speed", 10.0, 0.5)
					sem.apply_buff("armor", 10.0, -0.5)
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
			"learn_spell":
				var spell_id = item.grants_spell
				if spell_id != "" and player:
					var spell_book = player.get_node_or_null("SpellBook")
					if spell_book:
						var spell_res = load("res://resources/spells/%s.tres" % spell_id) as SpellDefinition
						if spell_res:
							spell_book.learn_spell(spell_res)
							spell_book.mark_permanently_learned(spell_id)
							if vfx:
								vfx.level_up_burst(player.global_position)
							if sfx:
								sfx.play("mystical", -2.0)
							var scene_root = get_tree().current_scene
							if scene_root:
								FloatingText.spawn(scene_root, player.global_position + Vector2(0, -4), "Learned: %s" % spell_res.spell_name, Color(0.8, 0.5, 1.0))
				use_effect_triggered.emit(item.use_effect)
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
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(player.global_position) < actual_radius:
			if e.has_method("take_damage"):
				e.take_damage(damage)
			if e.has_method("apply_status"):
				e.apply_status(status, duration)
	if vfx:
		if is_ice:
			vfx.frost_ring(player.global_position, actual_radius)
		else:
			vfx.shockwave(player.global_position, actual_radius, color)
		vfx.shake(1.5, 0.12)
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

func get_equipped(slot: EquipmentItem.SlotType) -> EquipmentItem:
	return equipped.get(slot, null)

func get_equipped_weapon() -> EquipmentItem:
	for slot in [EquipmentItem.SlotType.WEAPON_MELEE, EquipmentItem.SlotType.WEAPON_RANGED, EquipmentItem.SlotType.WEAPON_MAGIC]:
		var w = equipped.get(slot, null)
		if w:
			return w
	return null

func get_equipped_ammo() -> EquipmentItem:
	return equipped.get(EquipmentItem.SlotType.AMMO, null)

func consume_ammo(count: int = 1) -> void:
	var ammo = get_equipped_ammo()
	if not ammo:
		return
	ammo.quantity -= count
	if ammo.quantity <= 0:
		equipped.erase(EquipmentItem.SlotType.AMMO)
	inventory_changed.emit()

func get_equipped_items() -> Array:
	var items: Array = []
	for item in equipped.values():
		if item:
			items.append(item)
	return items

# Legacy compatibility
func equip_from_inventory(inv_index: int) -> void:
	toggle_equip(inv_index)

func unequip_to_inventory(slot: EquipmentItem.SlotType) -> void:
	if not equipped.has(slot):
		return
	var item = equipped[slot] as EquipmentItem
	_on_item_unequipped(item)
	equipped.erase(slot)
	stats_changed.emit()
	inventory_changed.emit()

# Legacy — just adds to bag
func equip(item: EquipmentItem) -> void:
	add_to_inventory(item)

func get_total_armor() -> float:
	return get_stat(StatModifier.StatType.ARMOR)

func get_total_move_speed() -> float:
	return get_stat(StatModifier.StatType.MOVE_SPEED)

func get_total_attack_damage() -> float:
	return get_stat(StatModifier.StatType.ATTACK_DAMAGE)

func get_total_attack_speed() -> float:
	return get_stat(StatModifier.StatType.ATTACK_SPEED)

func get_total_bullet_speed() -> float:
	return get_stat(StatModifier.StatType.BULLET_SPEED)

func get_total_max_hp() -> float:
	return get_stat(StatModifier.StatType.MAX_HP)

func get_total_max_mp() -> float:
	return get_stat(StatModifier.StatType.MAX_MP)

func get_total_mp_regen() -> float:
	return get_stat(StatModifier.StatType.MP_REGEN)

func get_total_luck() -> float:
	return get_stat(StatModifier.StatType.LUCK)

func get_total_crit_damage() -> float:
	return get_stat(StatModifier.StatType.CRIT_DAMAGE)

func get_total_dodge() -> float:
	return get_stat(StatModifier.StatType.DODGE_CHANCE)

func get_total_pickup_radius() -> float:
	return get_stat(StatModifier.StatType.PICKUP_RADIUS)

func get_total_cooldown_reduction() -> float:
	return get_stat(StatModifier.StatType.COOLDOWN_REDUCTION)

func get_total_xp_mult() -> float:
	return get_stat(StatModifier.StatType.XP_MULT)

func get_total_gold_mult() -> float:
	return get_stat(StatModifier.StatType.GOLD_MULT)

func get_total_weight() -> float:
	return get_stat(StatModifier.StatType.WEIGHT)

var level_system: LevelSystem:
	get:
		var player = get_parent()
		return player.get_node_or_null("LevelSystem") as LevelSystem if player else null

func get_stat(stat_type: StatModifier.StatType) -> float:
	var total = 0.0
	match stat_type:
		StatModifier.StatType.MAX_HP: total += base_stats.max_hp
		StatModifier.StatType.MOVE_SPEED: total += base_stats.move_speed
		StatModifier.StatType.ACCELERATION: total += base_stats.acceleration
		StatModifier.StatType.ATTACK_DAMAGE: total += base_stats.attack_damage
		StatModifier.StatType.ATTACK_SPEED: total += base_stats.attack_speed
		StatModifier.StatType.BULLET_SPEED: total += base_stats.bullet_speed
		StatModifier.StatType.BULLET_COUNT: total += base_stats.bullet_count
		StatModifier.StatType.SPREAD_ANGLE: total += base_stats.spread_angle
		StatModifier.StatType.PIERCE_COUNT: total += base_stats.pierce_count
		StatModifier.StatType.BULLET_LIFETIME: total += base_stats.bullet_lifetime
		StatModifier.StatType.MAX_MP: total += base_stats.max_mp
		StatModifier.StatType.HP_REGEN: total += base_stats.hp_regen
		StatModifier.StatType.MP_REGEN: total += base_stats.mp_regen
		StatModifier.StatType.LUCK: total += base_stats.luck
		StatModifier.StatType.CRIT_DAMAGE: total += base_stats.crit_damage
		StatModifier.StatType.ARMOR: total += base_stats.armor
		StatModifier.StatType.DODGE_CHANCE: total += base_stats.dodge_chance
		StatModifier.StatType.PICKUP_RADIUS: total += base_stats.pickup_radius
		StatModifier.StatType.COOLDOWN_REDUCTION: total += base_stats.cooldown_reduction
		StatModifier.StatType.STEALTH: total += base_stats.stealth
		StatModifier.StatType.XP_MULT: total += base_stats.xp_mult
		StatModifier.StatType.GOLD_MULT: total += base_stats.gold_mult
		StatModifier.StatType.WEIGHT: total += base_stats.weight
		StatModifier.StatType.MAX_STAMINA: total += base_stats.max_stamina
		StatModifier.StatType.STAMINA_REGEN: total += base_stats.stamina_regen
		StatModifier.StatType.TENACITY: total += base_stats.tenacity
		StatModifier.StatType.THORNS: total += base_stats.thorns
	if level_system:
		total += level_system.get_level_bonus(stat_type)
		total += level_system.get_allocation_bonus(stat_type)
	for item in equipped.values():
		if item:
			for mod in item.modifiers:
				if mod.stat == stat_type:
					total += mod.flat_bonus
	if stat_type in [StatModifier.StatType.ATTACK_DAMAGE, StatModifier.StatType.MOVE_SPEED, StatModifier.StatType.ATTACK_SPEED, StatModifier.StatType.BULLET_SPEED, StatModifier.StatType.BULLET_COUNT, StatModifier.StatType.SPREAD_ANGLE, StatModifier.StatType.PIERCE_COUNT, StatModifier.StatType.BULLET_LIFETIME, StatModifier.StatType.MAX_HP, StatModifier.StatType.MAX_MP, StatModifier.StatType.HP_REGEN, StatModifier.StatType.MP_REGEN, StatModifier.StatType.LUCK, StatModifier.StatType.CRIT_DAMAGE, StatModifier.StatType.ARMOR, StatModifier.StatType.DODGE_CHANCE, StatModifier.StatType.PICKUP_RADIUS, StatModifier.StatType.COOLDOWN_REDUCTION, StatModifier.StatType.STEALTH, StatModifier.StatType.XP_MULT, StatModifier.StatType.GOLD_MULT, StatModifier.StatType.MAX_STAMINA, StatModifier.StatType.STAMINA_REGEN, StatModifier.StatType.TENACITY, StatModifier.StatType.THORNS]:
			var mult = 1.0
			for item in equipped.values():
				if item:
					for mod in item.modifiers:
						if mod.stat == stat_type and mod.percent_bonus != 0:
							mult += mod.percent_bonus
			total *= mult
	return total

func get_damage() -> int: return int(round(get_stat(StatModifier.StatType.ATTACK_DAMAGE)))
func get_attack_speed() -> float: return get_stat(StatModifier.StatType.ATTACK_SPEED)
func get_bullet_speed() -> float: return get_stat(StatModifier.StatType.BULLET_SPEED)
func get_bullet_count() -> int: return maxi(1, int(round(get_stat(StatModifier.StatType.BULLET_COUNT))))
func get_spread_angle() -> float: return get_stat(StatModifier.StatType.SPREAD_ANGLE)
func get_pierce_count() -> int: return int(round(get_stat(StatModifier.StatType.PIERCE_COUNT)))
func get_bullet_lifetime() -> float: return get_stat(StatModifier.StatType.BULLET_LIFETIME)
func get_max_hp() -> int: return int(round(get_stat(StatModifier.StatType.MAX_HP)))
func get_max_mp() -> int: return int(round(get_stat(StatModifier.StatType.MAX_MP)))
func get_hp_regen() -> float: return get_stat(StatModifier.StatType.HP_REGEN)
func get_mp_regen() -> float: return get_stat(StatModifier.StatType.MP_REGEN)
func get_move_speed() -> float: return get_stat(StatModifier.StatType.MOVE_SPEED)
func get_acceleration() -> float: return get_stat(StatModifier.StatType.ACCELERATION)
func get_luck() -> float: return get_stat(StatModifier.StatType.LUCK)
func get_crit_damage() -> float: return get_stat(StatModifier.StatType.CRIT_DAMAGE)
func get_armor() -> float: return get_stat(StatModifier.StatType.ARMOR)
func get_dodge_chance() -> float: return get_stat(StatModifier.StatType.DODGE_CHANCE)
func get_pickup_radius() -> float: return get_stat(StatModifier.StatType.PICKUP_RADIUS)
func get_cdr() -> float: return get_stat(StatModifier.StatType.COOLDOWN_REDUCTION)
func get_stealth() -> float: return get_stat(StatModifier.StatType.STEALTH)
func get_xp_mult() -> float: return get_stat(StatModifier.StatType.XP_MULT)
func get_gold_mult() -> float: return get_stat(StatModifier.StatType.GOLD_MULT)
func get_weight() -> float: return get_stat(StatModifier.StatType.WEIGHT)
func get_max_stamina() -> float: return get_stat(StatModifier.StatType.MAX_STAMINA)
func get_stamina_regen() -> float: return get_stat(StatModifier.StatType.STAMINA_REGEN)
func get_tenacity() -> float: return clampf(get_stat(StatModifier.StatType.TENACITY), 0.0, 80.0)
func get_thorns() -> float: return get_stat(StatModifier.StatType.THORNS)
func get_bullet_sprite_index() -> int:
	var ammo = get_equipped_ammo()
	if ammo and ammo.bullet_sprite_index >= 0:
		return ammo.bullet_sprite_index
	var weapon = get_equipped_weapon()
	if weapon and weapon.bullet_sprite_index >= 0:
		return weapon.bullet_sprite_index
	return -1

func get_weapon_range() -> float:
	var weapon = get_equipped_weapon()
	if weapon and weapon.weapon_range > 0.0:
		return weapon.weapon_range
	return 0.0
