extends CharacterBody2D

var hp: int = 30
var max_hp: int = 30
var shield: int = 0
var invincible: bool = false
var touch_controls: TouchControls

@onready var sprite: Sprite2D = $Sprite2D
@onready var equipment_manager: EquipmentManager = $EquipmentManager
@onready var weapon_system: WeaponSystem = $WeaponSystem
@onready var mutation_processor: MutationProcessor = $MutationProcessor
@onready var status_effects: StatusEffectManager = $StatusEffectManager

signal hp_changed(new_hp: int)
signal player_died

func _ready() -> void:
	add_to_group("player")
	weapon_system.setup(equipment_manager)
	status_effects.setup(self)

	max_hp = equipment_manager.get_max_hp()
	hp = max_hp
	equipment_manager.stats_changed.connect(_on_stats_changed)
	$Hitbox.area_entered.connect(_on_hitbox_area_entered)

func _physics_process(_delta: float) -> void:
	var direction = Vector2.ZERO

	# Touch input takes priority
	if touch_controls and touch_controls.visible and touch_controls.get_move_input().length() > 0:
		direction = touch_controls.get_move_input()
	else:
		direction.x = Input.get_axis("move_left", "move_right")
		direction.y = Input.get_axis("move_up", "move_down")

	if direction.length() > 0:
		direction = direction.normalized()

	velocity = direction * equipment_manager.get_move_speed() * status_effects.get_speed_multiplier()
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

func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	hp_changed.emit(hp)

func add_shield(amount: int) -> void:
	shield += amount

func take_damage(amount: int) -> void:
	if invincible:
		return

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
	hp_changed.emit(hp)

func _on_hitbox_area_entered(_area: Area2D) -> void:
	pass
