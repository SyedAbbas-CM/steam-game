extends CharacterBody2D

var hp: int = 30
var max_hp: int = 30
var mp: float = 20.0
var max_mp: float = 20.0
var shield: int = 0
var invincible: bool = false
var touch_controls: TouchControls

@onready var sprite: Sprite2D = $Sprite2D
@onready var equipment_manager: EquipmentManager = $EquipmentManager
@onready var weapon_system: WeaponSystem = $WeaponSystem
@onready var mutation_processor: MutationProcessor = $MutationProcessor
@onready var status_effects: StatusEffectManager = $StatusEffectManager
@onready var level_system: LevelSystem = $LevelSystem

signal hp_changed(new_hp: int)
signal mp_changed(new_mp: float)
signal player_died

var _regen_accumulator: float = 0.0

func _ready() -> void:
	add_to_group("player")

	# Wire level system into equipment manager
	equipment_manager.level_system = level_system
	weapon_system.setup(equipment_manager)
	status_effects.setup(self)

	# Load level data from GameManager if available
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("load_level_data"):
		gm.load_level_data(level_system)

	max_hp = equipment_manager.get_max_hp()
	hp = max_hp
	max_mp = equipment_manager.get_max_mp()
	mp = max_mp

	equipment_manager.stats_changed.connect(_on_stats_changed)
	level_system.leveled_up.connect(_on_level_up)
	$Hitbox.area_entered.connect(_on_hitbox_area_entered)

func _physics_process(delta: float) -> void:
	var direction = Vector2.ZERO

	# Touch input takes priority
	if touch_controls and touch_controls.visible and touch_controls.get_move_input().length() > 0:
		direction = touch_controls.get_move_input()
	else:
		direction.x = Input.get_axis("move_left", "move_right")
		direction.y = Input.get_axis("move_up", "move_down")

	if direction.length() > 0:
		direction = direction.normalized()

	# Acceleration-based movement
	var target_velocity = direction * equipment_manager.get_move_speed() * status_effects.get_speed_multiplier()
	var accel = equipment_manager.get_acceleration()
	velocity = velocity.lerp(target_velocity, accel * delta * 10.0)
	move_and_slide()

	if direction.x < 0:
		sprite.flip_h = true
	elif direction.x > 0:
		sprite.flip_h = false

	# Shooting: twin-stick or mouse/keyboard
	if touch_controls and touch_controls.visible and touch_controls.is_shooting():
		var aim_dir = touch_controls.get_aim_input().normalized()
		weapon_system.try_shoot(global_position, aim_dir)
	elif Input.is_action_pressed("shoot"):
		var mouse_pos = get_global_mouse_position()
		var aim_dir = (mouse_pos - global_position).normalized()
		weapon_system.try_shoot(global_position, aim_dir)

func _process(delta: float) -> void:
	# HP and MP regen
	_regen_accumulator += delta
	if _regen_accumulator >= 1.0:
		_regen_accumulator -= 1.0
		var hp_regen = equipment_manager.get_hp_regen()
		if hp_regen > 0 and hp < max_hp:
			hp = mini(hp + int(ceilf(hp_regen)), max_hp)
			hp_changed.emit(hp)

	var mp_regen = equipment_manager.get_mp_regen()
	if mp_regen > 0 and mp < max_mp:
		mp = minf(mp + mp_regen * delta, max_mp)

func gain_xp(amount: int) -> void:
	var xp_mult = equipment_manager.get_xp_mult()
	level_system.gain_xp(amount, xp_mult)

func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	hp_changed.emit(hp)

func add_shield(amount: int) -> void:
	shield += amount

func use_mp(cost: float) -> bool:
	if mp < cost:
		return false
	mp -= cost
	mp_changed.emit(mp)
	return true

func take_damage(amount: int) -> void:
	if invincible:
		return

	# Dodge check
	var dodge = equipment_manager.get_dodge_chance()
	if dodge > 0 and randf() * 100.0 < dodge:
		# Dodged! Brief white flash
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(2, 2, 2), 0.05)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		return

	# Armor reduction
	var armor = int(equipment_manager.get_armor())
	if armor > 0:
		amount = maxi(1, amount - armor)

	# Shield absorption
	if shield > 0:
		var absorbed = mini(shield, amount)
		shield -= absorbed
		amount -= absorbed

	if amount <= 0:
		return

	hp -= amount
	hp_changed.emit(hp)

	invincible = true
	var tween = create_tween()
	for i in range(5):
		tween.tween_property(sprite, "modulate:a", 0.2, 0.08)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.08)
	tween.tween_callback(func(): invincible = false)

	if hp <= 0:
		player_died.emit()

func _on_stats_changed() -> void:
	var new_max = equipment_manager.get_max_hp()
	if new_max > max_hp:
		hp += new_max - max_hp
	max_hp = new_max
	max_mp = equipment_manager.get_max_mp()
	hp_changed.emit(hp)

func _on_level_up(new_level: int) -> void:
	# Restore HP on level up
	max_hp = equipment_manager.get_max_hp()
	hp = max_hp
	max_mp = equipment_manager.get_max_mp()
	mp = max_mp
	hp_changed.emit(hp)
	mp_changed.emit(mp)
	equipment_manager.stats_changed.emit()

	# Visual flash
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2, 2, 0.5), 0.15)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)

func _on_hitbox_area_entered(_area: Area2D) -> void:
	pass
