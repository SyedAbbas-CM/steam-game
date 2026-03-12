class_name WeaponSystem
extends Node

@export var weapon_pattern: WeaponPattern

var bullet_scene: PackedScene
var equipment_manager: EquipmentManager
var can_shoot: bool = true

@onready var cooldown_timer: Timer = Timer.new()

func _ready() -> void:
	bullet_scene = preload("res://scenes/bullet.tscn")
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(func(): can_shoot = true)
	add_child(cooldown_timer)

	if not weapon_pattern:
		weapon_pattern = WeaponPattern.new()

func setup(equip_mgr: EquipmentManager) -> void:
	equipment_manager = equip_mgr

func try_shoot(origin: Vector2, aim_direction: Vector2) -> void:
	if not can_shoot or weapon_pattern == null or equipment_manager == null:
		return

	can_shoot = false
	var cooldown = weapon_pattern.cooldown_override
	if cooldown <= 0.0:
		cooldown = equipment_manager.get_attack_speed()
	cooldown_timer.wait_time = maxf(cooldown, 0.05)
	cooldown_timer.start()

	var fire_data = weapon_pattern.get_fire_data(aim_direction, equipment_manager)

	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return

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

	# Crit roll: chance = luck / 2 %
	var luck = equipment_manager.get_luck()
	var crit_chance = luck / 2.0
	if crit_chance > 0 and randf() * 100.0 < crit_chance:
		bullet.is_crit = true
		bullet.damage = int(base_damage * equipment_manager.get_crit_damage())
	else:
		bullet.damage = base_damage

	bullet.pierce_count = equipment_manager.get_pierce_count()
	bullet.lifetime = equipment_manager.get_bullet_lifetime()

	# Apply weapon-specific bullet sprite and range
	bullet.bullet_sprite_index = equipment_manager.get_bullet_sprite_index()
	var wrange = equipment_manager.get_weapon_range()
	if wrange > 0.0:
		# Convert range to lifetime: lifetime = range / speed (in seconds)
		bullet.lifetime = wrange / maxf(bullet.speed, 1.0) * 100.0

	# Apply bullet modifiers from equipment
	for item in equipment_manager.get_equipped_items():
		for bmod in item.bullet_modifiers:
			match bmod.type:
				BulletModifier.ModType.HOMING:
					bullet.homing_strength = bmod.strength
				BulletModifier.ModType.PIERCE:
					bullet.pierce_count += int(bmod.strength)

	# Apply enchantment from equipped weapon
	var weapon = equipment_manager.get_equipped_weapon()
	if weapon and weapon.enchantment:
		bullet.enchant_type = weapon.enchantment.type
		bullet.enchant_proc_chance = weapon.enchantment.proc_chance
		bullet.enchant_bonus_damage = weapon.enchantment.bonus_damage

	container.add_child(bullet)
