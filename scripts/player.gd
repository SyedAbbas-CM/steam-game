extends CharacterBody2D

var hp: int = 30
var max_hp: int = 30
var mp: float = 20.0
var max_mp: float = 20.0
var shield: int = 0
var invincible: bool = false
var iframes_enabled: bool = false  # disabled for now; can become an armor perk later
var in_dungeon: bool = false
var touch_controls: TouchControls

@onready var sprite: Sprite2D = $Sprite2D
@onready var equipment_manager: EquipmentManager = $EquipmentManager
@onready var weapon_system: WeaponSystem = $WeaponSystem
@onready var mutation_processor: MutationProcessor = $MutationProcessor
@onready var status_effects: StatusEffectManager = $StatusEffectManager
@onready var level_system: LevelSystem = $LevelSystem

signal hp_changed(new_hp: int)
signal mp_changed(new_mp: float)
signal xp_changed(xp: int, xp_needed: int)
signal player_died

var _regen_accumulator: float = 0.0
var _dbg_frame: int = 0
var _dbg_file: FileAccess = null
var _animator: SpriteAnimator  # disabled until spritesheets support animation

# Dash system
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _last_move_dir: Vector2 = Vector2.RIGHT
const DASH_DURATION = 0.15
const DASH_SPEED_MULT = 3.0
const DASH_COOLDOWN = 1.0

# Item ability
var _ability_cooldown: float = 0.0

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

	# Load saved equipment, or give starting items if first time
	var loaded_equip = false
	if gm and gm.has_method("load_equipment"):
		loaded_equip = gm.load_equipment(equipment_manager)
	if not loaded_equip and equipment_manager.inventory.is_empty() and equipment_manager.equipped.is_empty():
		_give_starting_items()

	max_hp = equipment_manager.get_max_hp()
	hp = max_hp
	max_mp = equipment_manager.get_max_mp()
	mp = max_mp

	equipment_manager.stats_changed.connect(_on_stats_changed)
	level_system.leveled_up.connect(_on_level_up)
	$Hitbox.area_entered.connect(_on_hitbox_area_entered)

func _is_ui_open() -> bool:
	if not is_inside_tree():
		return true
	var inv = get_tree().get_first_node_in_group("inventory_screen")
	if inv and inv.has_method("is_open") and inv.is_open():
		return true
	var quest_log = get_tree().get_first_node_in_group("quest_log")
	if quest_log and quest_log is CanvasLayer and quest_log.visible:
		return true
	return false

func _physics_process(delta: float) -> void:
	# Block all game input when UI is open
	if _is_ui_open():
		velocity = velocity.lerp(Vector2.ZERO, 0.3)
		move_and_slide()
		return

	# Dash cooldown tick
	if _dash_cooldown > 0:
		_dash_cooldown -= delta
	if _ability_cooldown > 0:
		_ability_cooldown -= delta

	# Handle active dash
	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0:
			_is_dashing = false
			invincible = false
			sprite.modulate.a = 1.0
		else:
			velocity = _dash_direction * equipment_manager.get_move_speed() * DASH_SPEED_MULT
			move_and_slide()
			return

	var direction = Vector2.ZERO

	# Touch input takes priority
	if touch_controls and touch_controls.visible and touch_controls.get_move_input().length() > 0:
		direction = touch_controls.get_move_input()
	else:
		direction.x = Input.get_axis("move_left", "move_right")
		direction.y = Input.get_axis("move_up", "move_down")

	if direction.length() > 0:
		direction = direction.normalized()
		_last_move_dir = direction

	# Dash input (SPACE)
	if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0:
		_start_dash()

	# Item ability (right-click / R)
	if Input.is_action_just_pressed("ability") and _ability_cooldown <= 0:
		_use_item_ability()

	# Acceleration-based movement
	var target_velocity = direction * equipment_manager.get_move_speed() * status_effects.get_speed_multiplier()
	var accel = equipment_manager.get_acceleration()
	velocity = velocity.lerp(target_velocity, accel * delta * 10.0)
	move_and_slide()
	# DEBUG: log ALL slide collisions
	_dbg_frame += 1
	var slides = get_slide_collision_count()
	if slides > 0:
		for si in range(slides):
			var col = get_slide_collision(si)
			var collider = col.get_collider()
			if _dbg_frame % 60 == 0:
				print("SLIDE: body=%s layer=%d normal=%s playerpos=%s" % [
					collider.name if collider else "?",
					collider.collision_layer if collider else -1,
					col.get_normal(), global_position])
	# Every 2 seconds, print test_move results
	if _dbg_frame % 120 == 0 and velocity.length() > 1:
		var hit = false
		for dir_name in ["R", "L", "D", "U"]:
			var dir = {"R": Vector2(32,0), "L": Vector2(-32,0), "D": Vector2(0,32), "U": Vector2(0,-32)}[dir_name]
			if test_move(global_transform, dir):
				print("TEST_MOVE %s=COLLIDE pos=%s" % [dir_name, global_position])
				hit = true
		if not hit:
			print("TEST_MOVE: NO collisions in any direction pos=%s" % global_position)
	if _dbg_frame == 1:
		print("PLAYER SPAWN: pos=%s scale=%s col_layer=%d col_mask=%d" % [global_position, scale, collision_layer, collision_mask])
		var cs = get_node_or_null("CollisionShape2D")
		if cs and cs.shape is RectangleShape2D:
			print("  shape_size=%s disabled=%s" % [cs.shape.size, cs.disabled])
		_dbg_file = FileAccess.open("user://player_collision_log.txt", FileAccess.WRITE)
		if _dbg_file:
			_dbg_file.store_line("PLAYER SPAWN: pos=%s scale=%s col_layer=%d col_mask=%d shape=%s" % [global_position, scale, collision_layer, collision_mask, cs.shape.size if cs and cs.shape is RectangleShape2D else "?"])
	# Write to file every frame when moving
	if _dbg_file and velocity.length() > 1 and _dbg_frame % 10 == 0:
		var line = "f=%d pos=%s vel=%s slides=%d" % [_dbg_frame, global_position, velocity, slides]
		if slides > 0:
			for si2 in range(slides):
				var c2 = get_slide_collision(si2)
				line += " col=%s" % c2.get_collider().name if c2.get_collider() else " col=null"
		_dbg_file.store_line(line)
		_dbg_file.flush()

	if direction.x < 0:
		sprite.flip_h = true
	elif direction.x > 0:
		sprite.flip_h = false

	# Update animation state
	var is_shooting = false

	# Shooting: twin-stick or mouse/keyboard
	# No weapon equipped = no shooting
	if not equipment_manager.get_equipped_weapon():
		if _animator:
			_animator.set_state(SpriteAnimator.State.WALK if direction.length() > 0 else SpriteAnimator.State.IDLE)
		return

	if touch_controls and touch_controls.visible and touch_controls.is_shooting():
		var aim_dir = touch_controls.get_aim_input().normalized()
		weapon_system.try_shoot(global_position, aim_dir)
		is_shooting = true
	elif Input.is_action_pressed("shoot"):
		var mouse_pos = get_global_mouse_position()
		var aim_dir = (mouse_pos - global_position).normalized()
		weapon_system.try_shoot(global_position, aim_dir)
		is_shooting = true

	if _animator:
		if is_shooting:
			_animator.set_state(SpriteAnimator.State.ATTACK)
		elif direction.length() > 0:
			_animator.set_state(SpriteAnimator.State.WALK)
		else:
			_animator.set_state(SpriteAnimator.State.IDLE)

func _process(delta: float) -> void:
	_regen_accumulator += delta
	if _regen_accumulator >= 1.0:
		_regen_accumulator -= 1.0
		# HP regen only outside dungeons (potions/abilities still work inside)
		if not in_dungeon:
			var hp_regen = equipment_manager.get_hp_regen()
			if hp_regen > 0 and hp < max_hp:
				hp = mini(hp + int(ceilf(hp_regen)), max_hp)
				hp_changed.emit(hp)

	# MP regen everywhere
	var mp_regen = equipment_manager.get_mp_regen()
	if mp_regen > 0 and mp < max_mp:
		mp = minf(mp + mp_regen * delta, max_mp)

func gain_xp(amount: int) -> void:
	var xp_mult = equipment_manager.get_xp_mult()
	level_system.gain_xp(amount, xp_mult)
	xp_changed.emit(level_system.xp, level_system.xp_to_next_level())

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

	# Floating damage number on player
	var scene_root = get_tree().current_scene
	if scene_root and amount > 0:
		FloatingText.spawn_damage(scene_root, global_position, amount, Color(1.0, 0.3, 0.3))

	# Iframes — disabled by default, can be enabled by armor perks later
	if iframes_enabled:
		invincible = true
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.3, 0.04)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.04)
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

func _give_starting_items() -> void:
	# Load starter gear, add to inventory, then equip by toggling
	var starter_weapon = load("res://resources/items/loy/sword.tres") as EquipmentItem
	var starter_armor = load("res://resources/items/loy/leather_armor.tres") as EquipmentItem

	if starter_weapon:
		var w = starter_weapon.duplicate()
		equipment_manager.add_to_inventory(w)
		equipment_manager.toggle_equip(equipment_manager.inventory.size() - 1)

	if starter_armor:
		var a = starter_armor.duplicate()
		equipment_manager.add_to_inventory(a)
		equipment_manager.toggle_equip(equipment_manager.inventory.size() - 1)

	# Give healing potions
	var apple = load("res://resources/items/loy/apple.tres") as EquipmentItem
	if apple:
		for i in range(3):
			equipment_manager.add_to_inventory(apple.duplicate())

	# Test items: various equipment types for testing
	var test_items = [
		"res://resources/items/loy/bow.tres",
		"res://resources/items/loy/staff.tres",
		"res://resources/items/loy/iron_helm.tres",
		"res://resources/items/loy/buckler.tres",
		"res://resources/items/loy/boots.tres",
		"res://resources/items/loy/leather_gloves.tres",
		"res://resources/items/loy/gold_ring.tres",
		"res://resources/items/loy/cloak.tres",
	]
	for path in test_items:
		var res = load(path) as EquipmentItem
		if res:
			equipment_manager.add_to_inventory(res.duplicate())

func _on_hitbox_area_entered(_area: Area2D) -> void:
	pass

# --- Dash ---

func _start_dash() -> void:
	_is_dashing = true
	_dash_timer = DASH_DURATION
	# Dash cooldown benefits from cooldown reduction (cap 50%)
	var cdr = clampf(equipment_manager.get_cooldown_reduction(), 0.0, 50.0)
	_dash_cooldown = DASH_COOLDOWN * (1.0 - cdr / 100.0)
	_dash_direction = _last_move_dir
	invincible = true
	sprite.modulate.a = 0.4  # ghost effect

# --- Class Ability ---

func _use_item_ability() -> void:
	var weapon = equipment_manager.get_equipped_weapon()
	if not weapon or weapon.ability_id == "":
		return
	if mp < weapon.ability_mp_cost:
		return

	use_mp(weapon.ability_mp_cost)
	# Cooldown from weapon, reduced by CDR (cap 50%)
	var cdr = clampf(equipment_manager.get_cooldown_reduction(), 0.0, 50.0)
	_ability_cooldown = weapon.ability_cooldown * (1.0 - cdr / 100.0)

	match weapon.ability_id:
		"shield_bash":
			_ability_shield_bash()
		"arrow_rain":
			_ability_arrow_rain()
		"frost_nova":
			_ability_frost_nova()
		_:
			print("Unknown ability: %s" % weapon.ability_id)

func _ability_shield_bash() -> void:
	# AoE knockback + damage around player — scales with ATK and level
	var base_dmg = equipment_manager.get_damage()
	var dmg = int(base_dmg * 2.5 + level_system.level * 0.5)
	var radius = 24.0 + level_system.level * 0.5  # grows with level
	var kb_force = 200.0 + base_dmg * 5.0  # knockback scales with ATK
	# Crit chance based on luck
	var luck = equipment_manager.get_luck()
	var crit_mult = equipment_manager.get_crit_damage()
	if luck > 0 and randf() * 100.0 < luck:
		dmg = int(dmg * crit_mult)

	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var dist = global_position.distance_to(e.global_position)
		if dist < radius:
			if e.has_method("take_damage"):
				e.take_damage(dmg)
			# Knockback
			var kb_dir = (e.global_position - global_position).normalized()
			e.velocity = kb_dir * kb_force
	# Visual: brief white flash
	sprite.modulate = Color(2, 2, 1)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func _ability_arrow_rain() -> void:
	# Fire arrows in a spread — count and damage scale with stats
	var aim_dir = _last_move_dir
	var bullet_scn = preload("res://scenes/bullet.tscn")
	var base_dmg = equipment_manager.get_damage()
	var arrow_count = 8 + level_system.level / 5  # +1 arrow every 5 levels
	var spread = 1.5 + level_system.level * 0.02  # wider spread with levels
	var luck = equipment_manager.get_luck()
	var crit_mult = equipment_manager.get_crit_damage()

	for i in range(arrow_count):
		var angle = aim_dir.angle() + (float(i) / float(arrow_count) - 0.5) * spread
		var b = bullet_scn.instantiate()
		b.global_position = global_position
		b.direction = Vector2.from_angle(angle)
		b.speed = equipment_manager.get_bullet_speed() * 1.2
		var dmg = base_dmg
		# Each arrow can crit independently
		if luck > 0 and randf() * 100.0 < luck:
			dmg = int(dmg * crit_mult)
		b.damage = dmg
		b.is_player_bullet = true
		b.lifetime = 2.0
		b.pierce_remaining = equipment_manager.get_pierce_count()
		get_tree().current_scene.add_child(b)
	# Visual: brief yellow flash
	sprite.modulate = Color(1.5, 1.5, 0.5)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func _ability_frost_nova() -> void:
	# AoE freeze around player — scales with ATK, level, and luck
	var base_dmg = equipment_manager.get_damage()
	var dmg = maxi(1, int(base_dmg * 0.8 + level_system.level * 0.3))
	var radius = 32.0 + level_system.level * 0.8  # grows with level
	var freeze_dur = 3.0 + level_system.level * 0.05  # slightly longer freeze at higher levels
	var luck = equipment_manager.get_luck()
	var crit_mult = equipment_manager.get_crit_damage()
	if luck > 0 and randf() * 100.0 < luck:
		dmg = int(dmg * crit_mult)

	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var dist = global_position.distance_to(e.global_position)
		if dist < radius:
			if e.has_method("apply_status"):
				e.apply_status("SLOWED", freeze_dur)
			if e.has_method("take_damage"):
				e.take_damage(dmg)
	# Visual: brief blue flash
	sprite.modulate = Color(0.5, 0.8, 2.0)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
