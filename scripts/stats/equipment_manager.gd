class_name EquipmentManager
extends Node

@export var base_stats: PlayerStats

# Equipped items by slot (up to 12 simultaneous)
var equipped: Dictionary = {}  # SlotType -> EquipmentItem
# Inventory bag
var inventory: Array[EquipmentItem] = []
const MAX_INVENTORY = 56  # 8x7 grid

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
		# Equip — if slot already occupied by different item, unequip old one first
		equipped[slot] = item
	stats_changed.emit()
	inventory_changed.emit()

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
