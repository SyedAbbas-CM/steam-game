class_name EquipmentManager
extends Node

@export var base_stats: PlayerStats

# Equipped items by slot
var equipped: Dictionary = {}  # SlotType -> EquipmentItem
# Inventory bag
var inventory: Array[EquipmentItem] = []
const MAX_INVENTORY = 56  # 8x7 grid

# Legacy: flat array of all equipped items for stat calculation
var equipped_items: Array[EquipmentItem] = []

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

func equip_from_inventory(inv_index: int) -> void:
	if inv_index < 0 or inv_index >= inventory.size():
		return
	var item = inventory[inv_index]
	var slot = item.slot_type

	# If something already equipped in that slot, swap it back to inventory
	if equipped.has(slot):
		var old_item = equipped[slot]
		equipped_items.erase(old_item)
		inventory[inv_index] = old_item
	else:
		inventory.remove_at(inv_index)

	equipped[slot] = item
	equipped_items.append(item)
	stats_changed.emit()
	inventory_changed.emit()

func unequip_to_inventory(slot: EquipmentItem.SlotType) -> void:
	if not equipped.has(slot):
		return
	if inventory.size() >= MAX_INVENTORY:
		return
	var item = equipped[slot]
	equipped.erase(slot)
	equipped_items.erase(item)
	inventory.append(item)
	stats_changed.emit()
	inventory_changed.emit()

# Legacy equip/unequip (used by old systems)
func equip(item: EquipmentItem) -> void:
	add_to_inventory(item)

func unequip(item: EquipmentItem) -> void:
	equipped_items.erase(item)
	stats_changed.emit()

var level_system: LevelSystem  # Set by player on ready

func get_stat(stat_type: StatModifier.StatType) -> float:
	var base_value: float = _get_base_value(stat_type)
	var flat_sum: float = 0.0
	var percent_sum: float = 0.0

	# Level bonuses (auto per-level + allocated stat points)
	if level_system:
		flat_sum += level_system.get_level_bonus(stat_type)
		flat_sum += level_system.get_allocation_bonus(stat_type)

	for item in equipped_items:
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
