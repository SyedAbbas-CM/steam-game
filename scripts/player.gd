extends CharacterBody2D
#variables
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
var spell_book: SpellBook

signal hp_changed(new_hp: int)
signal mp_changed(new_mp: float)
signal stamina_changed(new_stamina: float)
signal xp_changed(xp: int, xp_needed: int)
signal player_died

var stamina: float = 100.0
var max_stamina: float = 100.0

# Shield block (Warrior)
var _shield_active: bool = false
var _shield_charges: int = 30  # each hit costs 1 charge regardless of damage
var _shield_max_charges: int = 30
var _shield_regen_delay: float = 0.0
var _shield_regen_accum: float = 0.0
var _shield_broken: bool = false
var _shield_break_stun: float = 0.0
var _shield_raise_cooldown: float = 0.0  # delay after lowering before can raise again
const SHIELD_RAISE_DELAY = 2.0
const SHIELD_REGEN_RATE = 1.5  # charges per second (~20s for full recharge)
const SHIELD_SPEED_MULT = 0.3
const SHIELD_BREAK_STUN_TIME = 0.5
const SHIELD_BROKEN_COOLDOWN = 6.0  # 6s lockout after shield breaks
signal shield_changed(shield_hp: int)

# Weapon swap (Mercenary/Ranger)
var _secondary_weapon: EquipmentItem = null
var _weapon_swap_cooldown: float = 0.0
const WEAPON_SWAP_COOLDOWN = 0.3
var _stamina_regen_delay: float = 0.0  # 1s delay after stamina use before regen starts
var _mp_regen_delay: float = 0.0  # delay after MP use before regen starts
const MP_REGEN_RATE = 0.5  # MP per second base (non-wizard)
const MP_REGEN_RATE_WIZARD = 2.0  # MP per second for wizard
const MP_REGEN_DELAY = 3.0  # seconds after MP use before regen kicks in
var _regen_accumulator: float = 0.0
var _animator: SpriteAnimator  # disabled until spritesheets support animation
var _player_anim: PlayerAnimator

# Dash system
var _is_dashing: bool = false
var _pushed_velocity: Vector2 = Vector2.ZERO  # external push from enemy collisions
var _dash_timer: float = 0.0
var _dash_cooldown: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _dash_linger: float = 0.0  # lingering i-frames after dash ends
var _dash_hit_enemies: Dictionary = {}  # enemies already hit during this dash
var _last_move_dir: Vector2 = Vector2.RIGHT

# First-person 3D view
var fps_mode: bool = false
var fps_angle: float = 0.0
var _first_person_view = null  # FirstPersonView reference
const FPS_TURN_SPEED: float = 5.0
const FPS_MOUSE_SENSITIVITY: float = 0.003
const DASH_DURATION = 0.3
const DASH_SPEED_MULT = 3.0
const DASH_COOLDOWN = 0.3
const DASH_STAMINA_COST = 25.0
const DASH_MP_COST = 3.0
const DASH_LINGER_TIME = 0.25  # longer lingering i-frames after dash
const DASH_BOSS_DMG_MULT = 2.0  # extra collision damage to bosses
const SPRINT_SPEED_MULT = 2.0
const SPRINT_STAMINA_DRAIN = 20.0  # stamina per second while sprinting
var _is_sprinting: bool = false
var _sneaking: bool = false

# i do not like these variables and implementations to be in the player.gd file
#TODO: seperate files for all of this
# Axe dash cleave
var _dash_cleave_pending: bool = false

# Whirlwind (axe Shift)
var _whirlwind_active: bool = false
var _saved_pattern: WeaponPattern = null

# Aimed mode (crossbow Shift)
var _aimed_mode_active: bool = false

# Staff teleport (Shift)
var _staff_teleport_active: bool = false
var _teleport_cooldown: float = 0.0

# Barrage (throwing Shift)
var _barrage_cooldown: float = 0.0

# Sword: Blade Dance (Shift)
var _blade_dance_active: bool = false

# Hammer: Earthquake (Shift)
var _earthquake_active: bool = false
var _earthquake_timer: float = 0.0

# Club: Berserk Swing (Shift)
var _berserk_swing_active: bool = false

# Spear: Phalanx (Shift)
var _phalanx_active: bool = false

# Wand: Magic Barrage (Shift)
var _magic_barrage_active: bool = false

# Tome: Arcane Shield (Shift)
var _arcane_shield_active: bool = false

# Javelin: Rain of Javelins (Shift)
var _javelin_rain_active: bool = false

# Sling: Rapid Sling (Shift)
var _rapid_sling_active: bool = false

# Halberd: Guard Stance (Shift)
var _guard_stance_active: bool = false

# Short Bow: Rapid Fire (Shift)
var _rapid_fire_active: bool = false

# Greatsword: Berserker Rage (Shift)
var _berserker_rage_active: bool = false

# Great Axe: Executioner (Shift)
var _executioner_active: bool = false

# Whip: Crack Whip (Shift)
var _crack_whip_active: bool = false

# Scythe: Soul Harvest (Shift)
var _soul_harvest_active: bool = false

# Claws: Frenzy (Shift)
var _frenzy_active: bool = false

# Bow multishot (Shift while shooting)
var _multishot_active: bool = false
var _multishot_cooldown: float = 0.0
const MULTISHOT_STAMINA_DRAIN = 25.0  # stamina per second
const MULTISHOT_MP_DRAIN = 5.0  # MP per second
const MULTISHOT_EXTRA_BULLETS = 2  # fires 3 total (1 normal + 2 extra)
const MULTISHOT_SPREAD = 0.08  # radians spread per extra bullet (~4.5 degrees)
const MULTISHOT_FIRE_RATE = 0.3  # seconds between multishot bursts

# Dagger rapid attack (hold Shift with dagger)
var _dagger_rapid_active: bool = false
const DAGGER_RAPID_STAMINA_DRAIN = 45.0  # heavy stamina drain
const DAGGER_RAPID_MP_DRAIN = 4.0  # MP per second
const DAGGER_RAPID_FIRE_MULT = 1.5  # 1.5x faster attack speed
const DAGGER_RAPID_CRIT_BONUS = 30.0  # +30% crit chance during rapid

# Staff charged blast (hold Space to charge, release to fire)
var _charge_active: bool = false
var _charge_time: float = 0.0
const CHARGE_MAX_TIME = 2.0  # seconds to fully charge
const CHARGE_STAMINA_COST = 30.0  # stamina on release (legacy, now drained during charge)
const CHARGE_MP_COST = 15.0  # MP on release
const CHARGE_MIN_TIME = 0.15  # very short min hold — almost always fires
const CHARGE_DMG_MULT = 5.0  # damage multiplier at full charge
const CHARGE_FLAT_DMG = 15  # flat bonus damage at full charge (added on top of multiplied base)
const CHARGE_SIZE_MULT = 3.0  # bullet size at full charge
const CHARGE_SPEED_MULT = 0.5  # slower projectile
var _charge_indicator: ColorRect  # visual charge bar

# Ranger Longshot (Space) — piercing arrow that briefly paralyzes enemies
const LONGSHOT_DMG = 5
const LONGSHOT_STAMINA_COST = 15.0
const LONGSHOT_MP_COST = 5.0
const LONGSHOT_COOLDOWN = 1.5
const LONGSHOT_PIERCE = 3  # hits up to 3 enemies
const LONGSHOT_STUN_MIN = 1.0
const LONGSHOT_STUN_MAX = 1.5

# Stone toss (T key) — distraction, charge-based
var _stone_toss_charges: int = 5
const STONE_TOSS_MAX_CHARGES = 5
const STONE_TOSS_CHARGE_TIME = 8.0  # seconds per charge regen
var _stone_toss_regen_timer: float = 0.0
const STONE_TOSS_RANGE = 100.0  # ~12 tiles

# Wrestling grab & throw (R key for warrior/merc with melee)
var _wrestle_cooldown: float = 0.0
var _stagger_cooldown: float = 0.0
const STAGGER_COOLDOWN = 3.0
const WRESTLE_COOLDOWN = 1.5
const WRESTLE_RANGE_DUNGEON = 12.0
const WRESTLE_RANGE_OVERWORLD = 48.0
const WRESTLE_THROW_FORCE = 120.0
const WRESTLE_CONE_HALF = 0.785  # ~45 degrees

# Massacre kill tracker (for FEARED status trigger)
var _recent_kill_times: Array[float] = []
const MASSACRE_WINDOW = 2.0  # seconds
const MASSACRE_KILL_COUNT = 3  # kills within window to trigger fear
const MASSACRE_FEAR_RADIUS = 40.0  # pixels
const MASSACRE_FEAR_DURATION = 2.5  # seconds

# Sneak mode constants
const SNEAK_SPEED_MULT = 0.4
const SNEAK_STAMINA_BASE_DRAIN = 5.0  # per second, reduced by stealth stat

# Parry mechanic
var _parry_window: float = 0.0
const PARRY_WINDOW_TIME = 0.2  # seconds to parry after raising shield

# Scout view (V key) — offset camera in aim direction
var _scout_view_active: bool = false
const SCOUT_VIEW_OFFSET = 80.0  # pixels offset in dungeon
const SCOUT_VIEW_OFFSET_OW = 320.0  # pixels offset in overworld (4x scale)
const SCOUT_VIEW_LERP_SPEED = 5.0  # smooth transition speed

# Item ability
var _ability_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("player")

	# Wire level system into equipment manager
	equipment_manager.level_system = level_system
	weapon_system.setup(equipment_manager)
	status_effects.setup(self)

	# Buff/debuff display above player
	var buff_display = BuffDisplay.new()
	buff_display.name = "BuffDisplay"
	add_child(buff_display)
	buff_display.setup(status_effects)

	# SpellBook system
	spell_book = SpellBook.new()
	spell_book.name = "SpellBook"
	add_child(spell_book)

	# Load level data from GameManager if available
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.save_data and gm.has_method("load_level_data"):
		gm.load_level_data(level_system)

	# Load saved equipment, or give starting items if first time
	var loaded_equip = false
	if gm and gm.save_data and gm.has_method("load_equipment"):
		loaded_equip = gm.load_equipment(equipment_manager)
	if not loaded_equip and equipment_manager.inventory.is_empty() and equipment_manager.equipped.is_empty():
		_give_starting_items()
	# Restore secondary weapon for mercenary/ranger weapon swap
	if gm and gm.save_data and gm.save_data.secondary_weapon_path != "":
		var sec_res = load(gm.save_data.secondary_weapon_path) as EquipmentItem
		if sec_res:
			_secondary_weapon = sec_res.make_copy()

	# Load spellbook or setup starters
	if gm and gm.has_method("load_spellbook"):
		var loaded_spells = gm.load_spellbook(spell_book)
		if not loaded_spells:
			_setup_starter_spells()
	else:
		_setup_starter_spells()

	# Apply class-specific base stats
	_apply_class_stats()

	# Set class-specific sprite from chars.png
	_setup_class_sprite()

	max_hp = equipment_manager.get_max_hp()
	hp = max_hp
	max_mp = equipment_manager.get_max_mp()
	mp = max_mp
	max_stamina = equipment_manager.get_max_stamina()
	stamina = max_stamina

	equipment_manager.stats_changed.connect(_on_stats_changed)
	level_system.leveled_up.connect(_on_level_up)
	$Hitbox.area_entered.connect(_on_hitbox_area_entered)

	# Ensure weapon pattern matches equipped weapon (signal was missed during _give_starting_items)
	weapon_system.update_pattern_for_weapon()

func _is_ui_open() -> bool:
	if not is_inside_tree():
		return true
	# Dialogue open — block movement
	var dialogue = get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue and dialogue.has_method("is_open") and dialogue.is_open():
		return true
	var inv = get_tree().get_first_node_in_group("inventory_screen")
	if inv and inv.has_method("is_open") and inv.is_open():
		return true
	var quest_log = get_tree().get_first_node_in_group("quest_log")
	if quest_log and quest_log is CanvasLayer and quest_log.visible:
		return true
	# Check CraftingUI, ShopUI, EnchantUI, SpellCraftUI, SpellBookUI
	for ui_name in ["crafting_ui", "shop_ui", "enchant_ui", "spell_craft_ui", "spellbook_ui", "world_map", "chest_ui"]:
		var ui = get_tree().get_first_node_in_group(ui_name)
		if ui and ui.has_method("is_open") and ui.is_open():
			return true
	return false

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
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
	if _multishot_cooldown > 0:
		_multishot_cooldown -= delta
	if _weapon_swap_cooldown > 0:
		_weapon_swap_cooldown -= delta
	if _stone_toss_charges < STONE_TOSS_MAX_CHARGES:
		_stone_toss_regen_timer += delta
		if _stone_toss_regen_timer >= STONE_TOSS_CHARGE_TIME:
			_stone_toss_regen_timer -= STONE_TOSS_CHARGE_TIME
			_stone_toss_charges = mini(_stone_toss_charges + 1, STONE_TOSS_MAX_CHARGES)
	else:
		_stone_toss_regen_timer = 0.0
	if _wrestle_cooldown > 0:
		_wrestle_cooldown -= delta
	if _stagger_cooldown > 0:
		_stagger_cooldown -= delta
	if _teleport_cooldown > 0:
		_teleport_cooldown -= delta
	if _barrage_cooldown > 0:
		_barrage_cooldown -= delta
	if spell_book:
		spell_book.tick_cooldowns(delta)

	# Shield break stun (Warrior)
	if _shield_break_stun > 0:
		_shield_break_stun -= delta
		velocity = velocity.lerp(Vector2.ZERO, 0.3)
		move_and_slide()
		return

	# Shield broken cooldown (can't raise shield for 3s)
	if _shield_broken:
		_shield_regen_delay -= delta
		if _shield_regen_delay <= 0:
			_shield_broken = false
			_shield_charges = _shield_max_charges
			shield_changed.emit(_shield_charges)

	# Parry window countdown
	if _parry_window > 0:
		_parry_window -= delta

	# Shield regen when not blocking and not broken (any class with shield equipped)
	var _player_class = _get_player_class()
	var _has_shield_item = equipment_manager.equipped.has(EquipmentItem.SlotType.SHIELD) and equipment_manager.equipped[EquipmentItem.SlotType.SHIELD] != null
	if _has_shield_item and not _shield_active and not _shield_broken and _shield_charges < _shield_max_charges:
		_shield_regen_accum += SHIELD_REGEN_RATE * delta
		if _shield_regen_accum >= 1.0:
			var points = int(_shield_regen_accum)
			_shield_regen_accum -= points
			_shield_charges = mini(_shield_charges + points, _shield_max_charges)
			shield_changed.emit(_shield_charges)

	# Stamina regen
	if _stamina_regen_delay > 0:
		_stamina_regen_delay -= delta
	elif stamina < max_stamina:
		var regen_rate = equipment_manager.get_stamina_regen()
		stamina = minf(stamina + regen_rate * delta, max_stamina)
		stamina_changed.emit(stamina)

	# MP regen (slow, delayed after use)
	if _mp_regen_delay > 0:
		_mp_regen_delay -= delta
	elif mp < max_mp:
		var mp_rate = MP_REGEN_RATE_WIZARD if _get_player_class() == "wizard" else MP_REGEN_RATE
		mp = minf(mp + mp_rate * delta, max_mp)
		mp_changed.emit(mp)

	# Handle lingering i-frames after dash
	if _dash_linger > 0:
		_dash_linger -= delta
		if _dash_linger <= 0:
			invincible = false
			sprite.modulate.a = 1.0

	# Handle active dash
	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0:
			_is_dashing = false
			_lunge_active = false
			_dash_hit_enemies.clear()
			if _player_anim and _player_anim._state == PlayerAnimator.AnimState.DASH:
				_player_anim.set_state(PlayerAnimator.AnimState.IDLE)
			# Axe: cleave AoE on dash landing
			if _dash_cleave_pending:
				_dash_cleave_pending = false
				_ability_blade_flurry()
			# Start lingering i-frames (still invincible, fade alpha back)
			_dash_linger = DASH_LINGER_TIME
			var tween = create_tween()
			tween.tween_property(sprite, "modulate:a", 1.0, DASH_LINGER_TIME)
		else:
			var dash_speed_mod = 0.5 if _shield_active else 1.0  # slower dash while shielding
			velocity = _dash_direction * equipment_manager.get_move_speed() * DASH_SPEED_MULT * dash_speed_mod
			move_and_slide()
			_dash_strike_check()
			# Spawn afterimages + trail lines during dash
			var vfx2 = get_node_or_null("/root/VFXManager")
			if vfx2 and Engine.get_physics_frames() % 2 == 0:
				vfx2.dash_afterimage(sprite, global_position)
				vfx2.dash_trail_lines(global_position, _dash_direction, sprite.scale)
			# Keep FPS camera synced during dash
			if fps_mode and _first_person_view:
				_first_person_view.update_camera(global_position, fps_angle)
			return

	var direction = Vector2.ZERO

	if fps_mode:
		# FPS movement: WASD relative to camera facing direction
		var forward = Vector2(cos(fps_angle), sin(fps_angle))
		var right_dir = Vector2(-sin(fps_angle), cos(fps_angle))
		if Input.is_action_pressed("move_up"):
			direction += forward
		if Input.is_action_pressed("move_down"):
			direction -= forward
		if Input.is_action_pressed("move_left"):
			direction -= right_dir
		if Input.is_action_pressed("move_right"):
			direction += right_dir
		# Arrow key turning
		if Input.is_key_pressed(KEY_LEFT):
			fps_angle -= FPS_TURN_SPEED * delta
		if Input.is_key_pressed(KEY_RIGHT):
			fps_angle += FPS_TURN_SPEED * delta
		if direction.length() > 0:
			direction = direction.normalized()
		_last_move_dir = forward
	else:
		# Touch input takes priority
		if touch_controls and touch_controls.visible and touch_controls.get_move_input().length() > 0:
			direction = touch_controls.get_move_input()
		else:
			direction.x = Input.get_axis("move_left", "move_right")
			direction.y = Input.get_axis("move_up", "move_down")

	if direction.length() > 0:
		direction = direction.normalized()
		if not fps_mode:
			_last_move_dir = direction

	# Weapon-specific abilities based on equipped type
	var _cur_weapon = equipment_manager.get_equipped_weapon()
	var _cur_slot = _cur_weapon.slot_type if _cur_weapon else -1
	var _wtype = _cur_weapon.get_weapon_type() if _cur_weapon else ""

	# Update touch control buttons based on weapon type
	if touch_controls and touch_controls.visible:
		var _has_shield = equipment_manager.equipped.has(EquipmentItem.SlotType.SHIELD) and equipment_manager.equipped[EquipmentItem.SlotType.SHIELD] != null and _cur_slot == EquipmentItem.SlotType.WEAPON_MELEE
		touch_controls.show_shield_button(_has_shield)
		match _wtype:
			"staff": touch_controls.set_power_label("Powershot")
			"bow": touch_controls.set_power_label("Longshot" if _get_player_class() == "ranger" else "Dash")
			"crossbow": touch_controls.set_power_label("Power Shot")
			"club": touch_controls.set_power_label("Pound")
			"hammer": touch_controls.set_power_label("Throw")
			"spear": touch_controls.set_power_label("Lunge")
			_: touch_controls.set_power_label("Dash")

	# SPACE abilities based on weapon_type
	if _wtype in ["sword", "dagger"]:
		# Dash
		if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= DASH_STAMINA_COST:
			_start_dash()
	elif _wtype == "flail":
		if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= 20.0:
			_flail_chain_lash()
	elif _wtype == "throwing":
		if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= 15.0:
			_throwing_fan_of_knives()
	elif _wtype == "short_bow":
		if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= 15.0:
			_short_bow_evasive_shot()
	elif _wtype == "axe":
		# Dash + Cleave AoE on landing
		if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= DASH_STAMINA_COST:
			_dash_cleave_pending = true
			_start_dash()
	elif _wtype == "club":
		# Ground Pound — AoE stun, no movement
		if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= 25.0:
			_ground_pound()
	elif _wtype == "hammer":
		# Hammer Throw — boomerang projectile
		if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= 20.0:
			_hammer_throw()
	elif _wtype == "spear":
		# Lunge — 2x distance dash with line damage
		if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= DASH_STAMINA_COST:
			_start_lunge()
	elif _wtype == "crossbow":
		# Power Shot — quick charge, 4x dmg, pierce all
		if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= 20.0:
			_power_shot()
	elif _wtype == "wand":
		if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= 15.0:
			_wand_blink()
	elif _wtype == "tome":
		if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= 30.0:
			_tome_nova_burst()
	elif _wtype == "javelin":
		if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= 20.0:
			_javelin_throw()
	elif _wtype == "sling":
		if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= 20.0:
			_sling_scatter_volley()
	elif _wtype == "halberd":
		if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= 25.0:
			_halberd_sweep()
	elif _wtype == "greatsword":
		if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= 30.0:
			_greatsword_overhead_slam()
	elif _wtype == "great_axe":
		if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= 25.0:
			_great_axe_whirlwind_cleave()
	elif _wtype == "whip":
		if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= 15.0:
			_whip_lasso_pull()
	elif _wtype == "scythe":
		if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= 25.0:
			_scythe_reap()
	elif _wtype == "claws":
		if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= 20.0:
			_claws_pounce()

	# Shield block — R key, requires shield item + melee weapon equipped
	var was_shielding = _shield_active
	_shield_active = false
	if _shield_raise_cooldown > 0:
		_shield_raise_cooldown -= delta
	var _has_shield_equipped = equipment_manager.equipped.has(EquipmentItem.SlotType.SHIELD) and equipment_manager.equipped[EquipmentItem.SlotType.SHIELD] != null and _cur_slot == EquipmentItem.SlotType.WEAPON_MELEE
	if _has_shield_equipped and Input.is_action_pressed("shield_raise") and not _shield_broken and _shield_charges > 0 and _shield_raise_cooldown <= 0:
		if not was_shielding:
			var sfx_sr = get_node_or_null("/root/SFXManager")
			if sfx_sr:
				sfx_sr.play("clack", -6.0, 0.0)
			# Parry window starts when shield is first raised
			_parry_window = PARRY_WINDOW_TIME
		_shield_active = true
		_update_shield_visual(true)
	if not _shield_active:
		_update_shield_visual(false)
		if _has_shield_equipped:
			sprite.modulate = Color.WHITE
		# Start raise cooldown when shield is lowered
		if was_shielding:
			_shield_raise_cooldown = SHIELD_RAISE_DELAY
			var sfx_sl = get_node_or_null("/root/SFXManager")
			if sfx_sl:
				sfx_sl.play("click", -6.0, 0.0)

	# Stone toss (T key) — throw distraction stone (charge-based)
	if Input.is_action_just_pressed("stone_toss") and _stone_toss_charges > 0:
		_stone_toss()
		_stone_toss_charges -= 1

	# Wrestling grab (R key) — warrior/merc with melee weapon
	var _pc_wrestle = _get_player_class()
	var _can_wrestle = (_pc_wrestle == "warrior" or _pc_wrestle == "mercenary") and _cur_slot == EquipmentItem.SlotType.WEAPON_MELEE
	if _can_wrestle and Input.is_action_just_pressed("shield_raise") and _wrestle_cooldown <= 0 and not _has_shield_equipped:
		_wrestle_grab()
		_wrestle_cooldown = WRESTLE_COOLDOWN

	# Scout view (V key) — hold to offset camera in aim direction
	var cam = get_node_or_null("Camera2D")
	if cam:
		_scout_view_active = Input.is_action_pressed("scout_view")
		if _scout_view_active:
			var aim = _get_shoot_direction()
			var in_ow_sv = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
			var offset_dist = SCOUT_VIEW_OFFSET_OW if in_ow_sv else SCOUT_VIEW_OFFSET
			var target_offset = aim * offset_dist
			cam.offset = cam.offset.lerp(target_offset, SCOUT_VIEW_LERP_SPEED * delta)
		else:
			cam.offset = cam.offset.lerp(Vector2.ZERO, SCOUT_VIEW_LERP_SPEED * delta)

	# SHIFT abilities based on weapon_type
	_multishot_active = false
	_dagger_rapid_active = false
	_whirlwind_active = false
	_aimed_mode_active = false
	_staff_teleport_active = false
	_blade_dance_active = false
	_earthquake_active = false
	_berserk_swing_active = false
	_phalanx_active = false
	_magic_barrage_active = false
	_arcane_shield_active = false
	_javelin_rain_active = false
	_rapid_sling_active = false
	_guard_stance_active = false
	_rapid_fire_active = false
	_berserker_rage_active = false
	_executioner_active = false
	_crack_whip_active = false
	_soul_harvest_active = false
	_frenzy_active = false

	if _wtype == "bow" and Input.is_action_pressed("sprint") and stamina > 0 and mp > 0:
		# Bow: Multishot
		_multishot_active = true
		stamina = maxf(stamina - MULTISHOT_STAMINA_DRAIN * delta, 0.0)
		mp = maxf(mp - MULTISHOT_MP_DRAIN * delta, 0.0)
		_stamina_regen_delay = 0.5
		stamina_changed.emit(stamina)
		mp_changed.emit(mp)
		if stamina <= 0 or mp <= 0:
			_multishot_active = false
	elif _wtype == "dagger" and Input.is_action_pressed("sprint") and stamina > 0 and mp > 0:
		# Dagger: Rapid attack mode
		_dagger_rapid_active = true
		stamina = maxf(stamina - DAGGER_RAPID_STAMINA_DRAIN * delta, 0.0)
		mp = maxf(mp - DAGGER_RAPID_MP_DRAIN * delta, 0.0)
		_stamina_regen_delay = 0.5
		stamina_changed.emit(stamina)
		mp_changed.emit(mp)
		if stamina <= 0 or mp <= 0:
			_dagger_rapid_active = false
	elif _wtype == "axe" and Input.is_action_pressed("sprint") and stamina > 0:
		# Axe: Whirlwind — ring pattern bullets, very heavy stamina drain (90/s)
		_whirlwind_active = true
		stamina = maxf(stamina - 45.0 * delta, 0.0)
		_stamina_regen_delay = 0.5
		stamina_changed.emit(stamina)
		if stamina <= 0:
			_whirlwind_active = false
	elif _wtype == "flail" and Input.is_action_pressed("sprint") and stamina > 0:
		# Flail: Whip Spin — extended range boomerang multishot
		_handle_whip_spin(delta)
		if _player_anim:
			_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK, 0, true)
	elif _wtype == "throwing" and Input.is_action_just_pressed("sprint") and stamina >= 20.0 and _barrage_cooldown <= 0:
		# Throwing: Barrage — scatter burst
		_handle_barrage()
	elif _wtype == "crossbow" and Input.is_action_pressed("sprint") and stamina > 0:
		# Crossbow: Aimed Mode — 50% speed, 2x dmg
		_aimed_mode_active = true
		stamina = maxf(stamina - 15.0 * delta, 0.0)
		_stamina_regen_delay = 0.5
		stamina_changed.emit(stamina)
		if stamina <= 0:
			_aimed_mode_active = false
	elif _wtype == "staff" and Input.is_action_just_pressed("sprint") and _teleport_cooldown <= 0 and mp >= 8.0:
		# Staff: Teleport with very short cooldown
		_staff_teleport_active = true
		use_mp(8.0)
		_ability_teleport()
		_teleport_cooldown = 0.5
	elif _wtype == "sword" and Input.is_action_pressed("sprint") and stamina > 0:
		_blade_dance_active = true
		stamina = maxf(stamina - 30.0 * delta, 0.0)
		_stamina_regen_delay = 0.5
		stamina_changed.emit(stamina)
		if stamina <= 0:
			_blade_dance_active = false
	elif _wtype == "hammer" and Input.is_action_pressed("sprint") and stamina > 0:
		_earthquake_active = true
		stamina = maxf(stamina - 35.0 * delta, 0.0)
		_stamina_regen_delay = 0.5
		stamina_changed.emit(stamina)
		if stamina <= 0:
			_earthquake_active = false
	elif _wtype == "club" and Input.is_action_pressed("sprint") and stamina > 0:
		_berserk_swing_active = true
		stamina = maxf(stamina - 25.0 * delta, 0.0)
		_stamina_regen_delay = 0.5
		stamina_changed.emit(stamina)
		if stamina <= 0:
			_berserk_swing_active = false
	elif _wtype == "spear" and Input.is_action_pressed("sprint") and stamina > 0:
		_phalanx_active = true
		stamina = maxf(stamina - 20.0 * delta, 0.0)
		_stamina_regen_delay = 0.5
		stamina_changed.emit(stamina)
		if stamina <= 0:
			_phalanx_active = false
	elif _wtype == "wand" and Input.is_action_pressed("sprint") and stamina > 0 and mp > 0:
		_magic_barrage_active = true
		stamina = maxf(stamina - 20.0 * delta, 0.0)
		mp = maxf(mp - 5.0 * delta, 0.0)
		_stamina_regen_delay = 0.5
		stamina_changed.emit(stamina)
		mp_changed.emit(mp)
		if stamina <= 0 or mp <= 0:
			_magic_barrage_active = false
	elif _wtype == "tome" and Input.is_action_pressed("sprint") and mp > 0:
		_arcane_shield_active = true
		mp = maxf(mp - 8.0 * delta, 0.0)
		mp_changed.emit(mp)
		if mp <= 0:
			_arcane_shield_active = false
	elif _wtype == "javelin" and Input.is_action_pressed("sprint") and stamina > 0:
		_javelin_rain_active = true
		stamina = maxf(stamina - 30.0 * delta, 0.0)
		_stamina_regen_delay = 0.5
		stamina_changed.emit(stamina)
		if stamina <= 0:
			_javelin_rain_active = false
	elif _wtype == "sling" and Input.is_action_pressed("sprint") and stamina > 0:
		_rapid_sling_active = true
		stamina = maxf(stamina - 25.0 * delta, 0.0)
		_stamina_regen_delay = 0.5
		stamina_changed.emit(stamina)
		if stamina <= 0:
			_rapid_sling_active = false
	elif _wtype == "halberd" and Input.is_action_pressed("sprint") and stamina > 0:
		_guard_stance_active = true
		stamina = maxf(stamina - 15.0 * delta, 0.0)
		_stamina_regen_delay = 0.5
		stamina_changed.emit(stamina)
		if stamina <= 0:
			_guard_stance_active = false
	elif _wtype == "greatsword" and Input.is_action_pressed("sprint") and stamina > 0:
		_berserker_rage_active = true
		stamina = maxf(stamina - 40.0 * delta, 0.0)
		_stamina_regen_delay = 0.5
		stamina_changed.emit(stamina)
		if stamina <= 0:
			_berserker_rage_active = false
	elif _wtype == "great_axe" and Input.is_action_pressed("sprint") and stamina > 0:
		_executioner_active = true
		stamina = maxf(stamina - 35.0 * delta, 0.0)
		_stamina_regen_delay = 0.5
		stamina_changed.emit(stamina)
		if stamina <= 0:
			_executioner_active = false
	elif _wtype == "whip" and Input.is_action_pressed("sprint") and stamina > 0:
		_crack_whip_active = true
		stamina = maxf(stamina - 20.0 * delta, 0.0)
		_stamina_regen_delay = 0.5
		stamina_changed.emit(stamina)
		if stamina <= 0:
			_crack_whip_active = false
	elif _wtype == "scythe" and Input.is_action_pressed("sprint") and stamina > 0:
		_soul_harvest_active = true
		stamina = maxf(stamina - 30.0 * delta, 0.0)
		_stamina_regen_delay = 0.5
		stamina_changed.emit(stamina)
		if stamina <= 0:
			_soul_harvest_active = false
	elif _wtype == "claws" and Input.is_action_pressed("sprint") and stamina > 0:
		_frenzy_active = true
		stamina = maxf(stamina - 25.0 * delta, 0.0)
		_stamina_regen_delay = 0.5
		stamina_changed.emit(stamina)
		if stamina <= 0:
			_frenzy_active = false

	# STAFF: Powershot (hold SPACE to charge, release to fire)
	# Stamina drains while charging. Need >= 21 stamina to START, but continues until 0.
	# Always fires on release or stamina depletion — uses whatever MP is available.
	# Player becomes stationary while channeling.
	if _wtype == "staff":
		var _can_start_charge = not _charge_active and stamina >= 21
		var _can_continue_charge = _charge_active and stamina > 0
		if Input.is_action_pressed("dash") and (_can_start_charge or _can_continue_charge):
			if not _charge_active:
				_charge_active = true
				_charge_time = 0.0
				_show_charge_indicator()
				if _player_anim:
					_player_anim.set_state(PlayerAnimator.AnimState.CHARGE)
				var sfx_ch = get_node_or_null("/root/SFXManager")
				if sfx_ch:
					sfx_ch.play("spell_a", -6.0, 0.0)
			_charge_time = minf(_charge_time + delta, CHARGE_MAX_TIME)
			# Drain stamina proportionally: full charge in CHARGE_MAX_TIME drains all stamina
			var drain = (max_stamina / CHARGE_MAX_TIME) * delta
			stamina = maxf(stamina - drain, 0.0)
			_stamina_regen_delay = 0.5
			stamina_changed.emit(stamina)
			_update_charge_indicator()
			# Out of stamina — force premature fire (always fires, uses available MP)
			if stamina <= 0 and _charge_active:
				_stamina_regen_delay = 1.0
				var mp_to_use = minf(mp, CHARGE_MP_COST)
				if mp_to_use > 0:
					use_mp(mp_to_use)
				_fire_charged_blast()
				_charge_active = false
				_charge_time = 0.0
				_hide_charge_indicator()
				if _player_anim:
					_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK, 1)
		elif _charge_active:
			# Released — always fire, use whatever MP is available
			_stamina_regen_delay = 1.0
			var mp_to_use = minf(mp, CHARGE_MP_COST)
			if mp_to_use > 0:
				use_mp(mp_to_use)
			_fire_charged_blast()
			_charge_active = false
			_charge_time = 0.0
			_hide_charge_indicator()
			if _player_anim:
				_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK, 1)

	# BOW: Ranger gets Longshot (Space), non-ranger bow gets Dash
	if _wtype == "bow":
		if _get_player_class() == "ranger":
			if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= LONGSHOT_STAMINA_COST and mp >= LONGSHOT_MP_COST:
				stamina -= LONGSHOT_STAMINA_COST
				_stamina_regen_delay = 1.0
				stamina_changed.emit(stamina)
				use_mp(LONGSHOT_MP_COST)
				_fire_longshot()
				_dash_cooldown = LONGSHOT_COOLDOWN
		else:
			if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0 and stamina >= DASH_STAMINA_COST:
				_start_dash()

	# Spell slots: F/G/H/J/K/L (6 slots)
	for si in range(6):
		if Input.is_action_just_pressed("spell_slot_%d" % (si + 1)):
			_use_spell_slot(si)

	# Quickbar keys 1-6 — use/equip items from quickbar slots
	for qi in range(6):
		if Input.is_action_just_pressed("quickbar_%d" % (qi + 1)):
			_use_quickbar_slot(qi)

	# Spellbook toggle (B key)
	if Input.is_action_just_pressed("spellbook"):
		_toggle_spellbook()

	# First-person view toggle (V key)
	if Input.is_action_just_pressed("fps_toggle"):
		_toggle_fps_mode()

	# Sneak toggle (C key) — independent of sprint
	if Input.is_action_just_pressed("sneak_toggle"):
		_sneaking = not _sneaking
		if _sneaking:
			var sfx_sn = get_node_or_null("/root/SFXManager")
			if sfx_sn:
				sfx_sn.play("click", -6.0)
	# Sneak drains stamina slowly (reduced by STEALTH stat)
	if _sneaking:
		if stamina <= 0 or _is_dashing:
			_sneaking = false
		else:
			var stealth_stat = equipment_manager.get_stealth()
			var sneak_drain = SNEAK_STAMINA_BASE_DRAIN * (1.0 - clampf(stealth_stat / 50.0, 0.0, 0.6))
			stamina = maxf(stamina - sneak_drain * delta, 0.0)
			_stamina_regen_delay = 0.5
			stamina_changed.emit(stamina)
	# Sneak visual
	if _sneaking:
		sprite.modulate.a = 0.5
	elif not _is_dashing and _dash_linger <= 0 and not _shield_active:
		sprite.modulate.a = 1.0

	# Sprint (hold Shift while moving — weapons without a special shift ability get sprint)
	# Short bows and unarmed also get sprint instead of a special ability
	_is_sprinting = false
	var _sprint_weapons = ["short_bow", ""]  # weapon types that sprint on shift
	var _has_shift_ability = _wtype != "" and _wtype not in _sprint_weapons
	if not _has_shift_ability:
		if Input.is_action_pressed("sprint") and direction.length() > 0 and stamina > 0 and not _is_dashing and not _shield_active:
			_is_sprinting = true
			_sneaking = false  # sprinting cancels sneak
			stamina = maxf(stamina - SPRINT_STAMINA_DRAIN * delta, 0.0)
			_stamina_regen_delay = 0.5
			stamina_changed.emit(stamina)
			if stamina <= 0:
				_is_sprinting = false

	# Acceleration-based movement
	var shield_mult = SHIELD_SPEED_MULT if _shield_active else 1.0
	var buff_speed = (status_effects.get_buff_multiplier("speed") * status_effects.get_buff_multiplier("town_speed")) if status_effects else 1.0
	var sneak_mult = SNEAK_SPEED_MULT if _sneaking else 1.0
	var aimed_mult = 0.5 if _aimed_mode_active else 1.0
	var charge_mult = 0.0 if _charge_active else 1.0  # Staff powershot: stationary while channeling
	var stance_mult = 1.0
	if _phalanx_active or _guard_stance_active:
		stance_mult = 0.0
	elif _berserk_swing_active:
		stance_mult = 0.5
	elif _earthquake_active:
		stance_mult = 0.3
	elif _arcane_shield_active:
		stance_mult = 0.6
	elif _berserker_rage_active:
		stance_mult = 0.5
	elif _executioner_active:
		stance_mult = 0.7

	if _earthquake_active:
		_earthquake_timer += delta
		if _earthquake_timer >= 0.5:
			_earthquake_timer -= 0.5
			_earthquake_slam()

	var speed_mult = status_effects.get_speed_multiplier() * (SPRINT_SPEED_MULT if _is_sprinting else 1.0) * shield_mult * buff_speed * sneak_mult * aimed_mult * charge_mult * stance_mult
	var target_velocity = direction * equipment_manager.get_move_speed() * speed_mult
	var accel = equipment_manager.get_acceleration()
	velocity = velocity.lerp(target_velocity, accel * delta * 10.0)
	# Apply external push (from enemy contact knockback)
	velocity += _pushed_velocity
	_pushed_velocity = _pushed_velocity.move_toward(Vector2.ZERO, delta * 400.0)
	move_and_slide()
	# Sync 3D first-person camera
	if fps_mode and _first_person_view:
		_first_person_view.update_camera(global_position, fps_angle)
	# Slide collision: push enemies via _pushed_velocity (persists through AI updates)
	for si in range(get_slide_collision_count()):
		var col = get_slide_collision(si)
		var collider = col.get_collider()
		if not collider or not collider.is_in_group("enemies"):
			continue
		if not collider is CharacterBody2D:
			continue
		var push_dir_c = -col.get_normal()  # direction from player toward enemy
		# Push enemy away — sprinting/dashing pushes harder
		var push_force := 80.0
		if _is_sprinting:
			push_force = 180.0
		if _is_dashing:
			push_force = 350.0
		if _blade_dance_active or _phalanx_active:
			push_force = 250.0
		# Heavier enemies resist push
		var enemy_weight: float = collider._weight if "_weight" in collider else 1.0
		var push_vec = push_dir_c * push_force / enemy_weight
		# Use _pushed_velocity so it persists through enemy AI updates
		if "_pushed_velocity" in collider:
			collider._pushed_velocity = push_vec
		else:
			collider.velocity += push_vec

	# Update facing direction (locked during dash to prevent frame flicker)
	if _player_anim and not _is_dashing:
		_player_anim.set_direction(direction)
	elif not _player_anim:
		if direction.x < 0:
			sprite.flip_h = true
		elif direction.x > 0:
			sprite.flip_h = false

	# Update animation state
	var is_shooting = false

	# Shooting: twin-stick or mouse/keyboard
	# No weapon equipped = no shooting
	if not equipment_manager.get_equipped_weapon():
		if _player_anim and not _player_anim.is_locked():
			_player_anim.set_state(PlayerAnimator.AnimState.WALK if direction.length() > 0 else PlayerAnimator.AnimState.IDLE)
		elif _animator:
			_animator.set_state(SpriteAnimator.State.WALK if direction.length() > 0 else SpriteAnimator.State.IDLE)
		return

	# Apply dagger rapid fire mode / aimed mode to weapon system
	if _dagger_rapid_active:
		weapon_system.fire_rate_mult = DAGGER_RAPID_FIRE_MULT
		weapon_system.crit_bonus = DAGGER_RAPID_CRIT_BONUS
		weapon_system.damage_mult = 1.0
	elif _aimed_mode_active:
		weapon_system.fire_rate_mult = 0.7  # slightly slower fire for heavy shots
		weapon_system.crit_bonus = 20.0  # +20% crit in aimed mode
		weapon_system.damage_mult = 2.0  # 2x damage
	elif _blade_dance_active:
		weapon_system.fire_rate_mult = 2.0
		weapon_system.crit_bonus = 15.0
		weapon_system.damage_mult = 0.7
	elif _berserk_swing_active:
		weapon_system.fire_rate_mult = 0.8
		weapon_system.crit_bonus = 0.0
		weapon_system.damage_mult = 1.5
	elif _phalanx_active:
		weapon_system.fire_rate_mult = 1.5
		weapon_system.crit_bonus = 0.0
		weapon_system.damage_mult = 0.8
	elif _magic_barrage_active:
		weapon_system.fire_rate_mult = 2.5
		weapon_system.crit_bonus = 0.0
		weapon_system.damage_mult = 0.5
	elif _javelin_rain_active:
		weapon_system.fire_rate_mult = 2.0
		weapon_system.crit_bonus = 0.0
		weapon_system.damage_mult = 0.6
	elif _rapid_sling_active:
		weapon_system.fire_rate_mult = 2.5
		weapon_system.crit_bonus = 10.0
		weapon_system.damage_mult = 0.6
	elif _guard_stance_active:
		weapon_system.fire_rate_mult = 1.2
		weapon_system.crit_bonus = 0.0
		weapon_system.damage_mult = 1.2
	elif _rapid_fire_active:
		weapon_system.fire_rate_mult = 2.0
		weapon_system.crit_bonus = 0.0
		weapon_system.damage_mult = 0.6
	elif _berserker_rage_active:
		weapon_system.fire_rate_mult = 0.8
		weapon_system.crit_bonus = 20.0
		weapon_system.damage_mult = 2.0
	elif _executioner_active:
		weapon_system.fire_rate_mult = 0.9
		weapon_system.crit_bonus = 10.0
		weapon_system.damage_mult = 1.75
	elif _crack_whip_active:
		weapon_system.fire_rate_mult = 2.0
		weapon_system.crit_bonus = 0.0
		weapon_system.damage_mult = 0.7
	elif _soul_harvest_active:
		weapon_system.fire_rate_mult = 1.0
		weapon_system.crit_bonus = 15.0
		weapon_system.damage_mult = 1.5
	elif _frenzy_active:
		weapon_system.fire_rate_mult = 3.0
		weapon_system.crit_bonus = 5.0
		weapon_system.damage_mult = 1.25
	else:
		weapon_system.fire_rate_mult = 1.0
		weapon_system.crit_bonus = 0.0
		weapon_system.damage_mult = 1.0

	# Whirlwind: temporarily swap to ring pattern while active
	if _whirlwind_active and not _saved_pattern:
		_saved_pattern = weapon_system.weapon_pattern
		if not weapon_system._pattern_cache.has("_ring"):
			weapon_system._pattern_cache["_ring"] = RingPattern.new()
		weapon_system.weapon_pattern = weapon_system._pattern_cache["_ring"]
	elif not _whirlwind_active and _saved_pattern:
		weapon_system.weapon_pattern = _saved_pattern
		_saved_pattern = null

	# Suppress Space-based shooting for melee (space=dash) and staff (space=charge)
	var _space_suppressed = _charge_active or _is_dashing or _cur_slot == EquipmentItem.SlotType.WEAPON_MELEE or _wtype == "staff"
	var _is_touch = touch_controls and touch_controls.visible

	if _is_touch and touch_controls.is_shooting():
		# Touch: only right joystick triggers shooting
		var aim_dir = touch_controls.get_aim_input().normalized()
		_sneaking = false  # firing breaks sneak
		weapon_system.try_shoot(global_position, aim_dir)
		if _multishot_active and _multishot_cooldown <= 0:
			_fire_multishot(aim_dir)
			_multishot_cooldown = MULTISHOT_FIRE_RATE
		is_shooting = true
		if _player_anim:
			_player_anim.set_aim_direction(aim_dir)
	elif not _is_touch:
		# Desktop: mouse/keyboard shooting (skip entirely on mobile to avoid emulated mouse)
		var _mouse_shooting = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		var _kb_shooting = Input.is_action_pressed("shoot") and not _mouse_shooting
		if _mouse_shooting or (_kb_shooting and not _space_suppressed):
			_sneaking = false  # firing breaks sneak
			var aim_dir: Vector2
			if fps_mode:
				# FPS: shoot in the direction the camera is facing
				aim_dir = Vector2(cos(fps_angle), sin(fps_angle))
			else:
				var mouse_pos = get_global_mouse_position()
				aim_dir = (mouse_pos - global_position).normalized()
			weapon_system.try_shoot(global_position, aim_dir)
			if _multishot_active and _multishot_cooldown <= 0:
				_fire_multishot(aim_dir)
				_multishot_cooldown = MULTISHOT_FIRE_RATE
			is_shooting = true
			if _player_anim:
				_player_anim.set_aim_direction(aim_dir)

	if _player_anim:
		if not _player_anim.is_locked():
			# Shift abilities (whirlwind, multishot, whip spin) use looping special attack anim
			if is_shooting and (_whirlwind_active or _multishot_active):
				_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK, 0, true)
			elif is_shooting:
				_player_anim.set_state(PlayerAnimator.AnimState.ATTACK)
			elif direction.length() > 0:
				_player_anim.set_state(PlayerAnimator.AnimState.WALK)
			else:
				_player_anim.set_state(PlayerAnimator.AnimState.IDLE)
	elif _animator:
		if is_shooting:
			_animator.set_state(SpriteAnimator.State.ATTACK)
		elif direction.length() > 0:
			_animator.set_state(SpriteAnimator.State.WALK)
		else:
			_animator.set_state(SpriteAnimator.State.IDLE)

func _process(delta: float) -> void:
	var hp_regen = equipment_manager.get_hp_regen()
	if hp_regen > 0 and hp < max_hp:
		_regen_accumulator += hp_regen * delta
		if _regen_accumulator >= 1.0:
			var healed = int(_regen_accumulator)
			_regen_accumulator -= healed
			hp = mini(hp + healed, max_hp)
			hp_changed.emit(hp)

	# MP regen from equipment (stacks with base regen)
	var mp_regen = equipment_manager.get_mp_regen()
	if mp_regen > 0 and mp < max_mp:
		mp = minf(mp + mp_regen * delta, max_mp)
		mp_changed.emit(mp)

func gain_xp(amount: int) -> void:
	var xp_mult = equipment_manager.get_xp_mult() + status_effects.get_buff_value("xp")
	level_system.gain_xp(amount, xp_mult)
	xp_changed.emit(level_system.xp, level_system.xp_to_next_level())

func is_sneaking() -> bool:
	return _sneaking

## Called by enemy._die() to track massacre kills for FEARED trigger
func on_enemy_killed_for_massacre() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	_recent_kill_times.append(now)
	# Prune old entries
	while _recent_kill_times.size() > 0 and now - _recent_kill_times[0] > MASSACRE_WINDOW:
		_recent_kill_times.remove_at(0)
	# Check if massacre threshold reached (this kill is already counted)
	if _recent_kill_times.size() >= MASSACRE_KILL_COUNT:
		_trigger_massacre_fear()

func _trigger_massacre_fear() -> void:
	_recent_kill_times.clear()
	if not is_inside_tree():
		return
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var fear_radius = MASSACRE_FEAR_RADIUS * (4.0 if in_ow else 1.0)
	var feared_any = false
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.state == e.State.DEAD:
			continue
		if e.global_position.distance_to(global_position) < fear_radius:
			if e.has_method("apply_status"):
				e.apply_status("FEARED", MASSACRE_FEAR_DURATION)
				feared_any = true
	if feared_any:
		var vfx = get_node_or_null("/root/VFXManager")
		if vfx:
			vfx.shockwave(global_position, fear_radius, Color(1.0, 0.3, 0.3, 0.5))
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("shriek", -3.0)
		var scene_root = get_tree().current_scene
		if scene_root:
			FloatingText.spawn(scene_root, global_position + Vector2(0, -12), "MASSACRE!", Color(1.0, 0.2, 0.2))

func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	hp_changed.emit(hp)
	var scene_root = get_tree().current_scene if is_inside_tree() else null
	if scene_root and amount > 0:
		FloatingText.spawn(scene_root, global_position + Vector2(0, -8), "+%d HP" % amount, Color(0.2, 1.0, 0.3))

func add_shield(amount: int) -> void:
	shield += amount

func use_mp(cost: float) -> bool:
	if mp < cost:
		return false
	mp -= cost
	_mp_regen_delay = MP_REGEN_DELAY
	mp_changed.emit(mp)
	return true

func take_damage(amount: int, source_pos: Vector2 = Vector2.INF, is_contact: bool = false, is_backstab: bool = false, _damage_type: int = 0) -> void:
	if invincible:
		return

	# Dashing = full invincibility
	if _is_dashing or _dash_linger > 0:
		return

	# PARRY CHECK — perfect block within parry window
	if _shield_active and _parry_window > 0:
		_parry_window = 0.0  # consume parry window
		# No shield charge consumed!
		# Stun all nearby enemies
		var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
		var stun_radius = 16.0 * (4.0 if in_ow else 1.0)
		for e in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(e) and e.global_position.distance_to(global_position) < stun_radius:
				if e.has_method("apply_status"):
					e.apply_status("STUNNED", 1.0)
		# Warrior: try to reflect incoming projectile
		if _get_player_class() == "warrior" and source_pos != Vector2.INF:
			var bullets_container = get_tree().get_first_node_in_group("bullets")
			if bullets_container:
				var reflect_range = 16.0 * (4.0 if in_ow else 1.0)
				for b in bullets_container.get_children():
					if not is_instance_valid(b) or not b.has_method("reflect"):
						continue
					if b.get("is_player_bullet") != null and b.is_player_bullet:
						continue
					if b.global_position.distance_to(global_position) < reflect_range:
						b.reflect()
						break
		# VFX + SFX
		var vfx_p = get_node_or_null("/root/VFXManager")
		if vfx_p:
			vfx_p.shockwave(global_position, stun_radius, Color(1.0, 1.0, 1.0, 0.8))
			vfx_p.shake(2.0, 0.1)
		var sfx_p = get_node_or_null("/root/SFXManager")
		if sfx_p:
			sfx_p.play("clack", 0.0, 0.2)
		# White flash
		var tween_p = create_tween()
		tween_p.tween_property(sprite, "modulate", Color(3.0, 3.0, 3.0), 0.05)
		tween_p.tween_property(sprite, "modulate", Color.WHITE, 0.15)
		return  # parry blocks ALL damage, no charge cost

	# Warrior shield block — each hit costs 1 charge, blocks ALL damage
	if _shield_active and _shield_charges > 0:
		var blocked = true
		if source_pos != Vector2.INF:
			var shield_dir = Vector2(cos(_shield_angle), sin(_shield_angle))
			var hit_dir = (source_pos - global_position).normalized()
			var angle_diff = abs(shield_dir.angle_to(hit_dir))
			blocked = angle_diff < SHIELD_ARC_ANGLE / 2.0 + 0.15
		if blocked:
			_shield_charges -= 1  # 1 charge per hit regardless of damage
			shield_changed.emit(_shield_charges)
			var sfx_blk = get_node_or_null("/root/SFXManager")
			if sfx_blk:
				sfx_blk.play("clack", -4.0, 0.1)
			var tween_s = create_tween()
			tween_s.tween_property(sprite, "modulate", Color(0.4, 0.5, 1.5), 0.05)
			tween_s.tween_property(sprite, "modulate", Color(0.7, 0.8, 1.0), 0.1)
			if _shield_charges <= 0:
				_shield_active = false
				_shield_broken = true
				_shield_regen_delay = SHIELD_BROKEN_COOLDOWN
				_shield_break_stun = SHIELD_BREAK_STUN_TIME
				sprite.modulate = Color.WHITE
				_update_shield_visual(false)
				var sfx_s = get_node_or_null("/root/SFXManager")
				if sfx_s:
					sfx_s.play("impact_a", 0.0)
				var vfx_sb = get_node_or_null("/root/VFXManager")
				if vfx_sb:
					vfx_sb.shake(2.5, 0.15)
			return  # fully blocked, no damage gets through

	# Dodge check
	var dodge = equipment_manager.get_dodge_chance()
	if dodge > 0 and randf() * 100.0 < dodge:
		# Dodged! Brief white flash + SFX
		var sfx_dg = get_node_or_null("/root/SFXManager")
		if sfx_dg:
			sfx_dg.play("woosh_b", -5.0, 0.15)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(2, 2, 2), 0.05)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		return

	# Backstab — stealth enemy hit from behind deals 25% max HP, bypasses armor
	if is_backstab and source_pos != Vector2.INF:
		var hit_dir = (source_pos - global_position).normalized()
		var facing_dot = _last_move_dir.dot(hit_dir)
		if facing_dot < 0:
			# Hit from behind (source is opposite to movement direction)
			amount = maxi(amount, int(ceil(max_hp * 0.25)))
			var sfx_bs = get_node_or_null("/root/SFXManager")
			if sfx_bs:
				sfx_bs.play("attack_a", 0.0)
			var scene_root = get_tree().current_scene if is_inside_tree() else null
			if scene_root:
				FloatingText.spawn_damage(scene_root, global_position + Vector2(0, -12), amount, Color(1.0, 0.0, 0.5))

	# Armor reduction — weak attacks fully blockable, strong attacks always deal 20% min
	var armor = int(equipment_manager.get_armor()) + int(status_effects.get_buff_value("armor"))
	if armor > 0 and not is_backstab:
		var raw = amount
		amount = maxi(0, amount - armor)
		# Strong attacks (raw > armor) always deal at least 20% of original damage
		if raw > armor:
			amount = maxi(amount, maxi(1, int(raw * 0.2)))

	# Contact damage resistance for melee classes (only when holding melee weapon)
		if is_contact:
			var pc = _get_player_class()
			var cur_wep = equipment_manager.get_equipped_weapon()
			var holding_melee = cur_wep and cur_wep.slot_type == EquipmentItem.SlotType.WEAPON_MELEE
			if pc == "warrior":
				amount = maxi(0, int(amount * 0.4))  # 60% contact resistance (always, warrior is tanky)
			elif pc == "mercenary" and holding_melee:
				amount = maxi(0, int(amount * 0.6))  # 40% contact resistance only with sword

		if _arcane_shield_active and mp > 0:
			var mp_drain = amount * 1.5
			if mp >= mp_drain:
				mp -= mp_drain
				mp_changed.emit(mp)
				amount = maxi(1, int(amount * 0.4))
			else:
				mp = 0.0
				mp_changed.emit(mp)
				_arcane_shield_active = false

		if _guard_stance_active:
			amount = maxi(1, int(amount * 0.5))

	# Shield absorption (equipment-based shield, separate from warrior block)
	if shield > 0:
		var absorbed = mini(shield, amount)
		shield -= absorbed
		amount -= absorbed

	if amount <= 0:
		return

	hp -= amount
	hp_changed.emit(hp)

	# Floating damage number on player
	var scene_root = get_tree().current_scene if is_inside_tree() else null
	if scene_root and amount > 0:
		FloatingText.spawn_damage(scene_root, global_position, amount, Color(1.0, 0.3, 0.3))
	# SFX + VFX
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("impact_a", -2.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shake(1.5, 0.12)
		vfx.blood_splatter(global_position, Vector2.UP, Color(0.8, 0.0, 0.0))

	# Iframes — disabled by default, can be enabled by armor perks later
	if iframes_enabled:
		invincible = true
		var iframe_tween = create_tween()
		iframe_tween.tween_property(sprite, "modulate:a", 0.3, 0.04)
		iframe_tween.tween_property(sprite, "modulate:a", 1.0, 0.04)
		iframe_tween.tween_callback(func(): invincible = false)

	if hp <= 0:
		player_died.emit()

func _on_stats_changed() -> void:
	var new_max = equipment_manager.get_max_hp()
	if new_max > max_hp:
		hp += new_max - max_hp  # Gain HP when equipping HP items
	max_hp = new_max
	hp = mini(hp, max_hp)  # Clamp HP down when unequipping HP items
	max_mp = equipment_manager.get_max_mp()
	mp = minf(mp, max_mp)
	var new_max_stam = equipment_manager.get_max_stamina()
	if new_max_stam > max_stamina:
		stamina += new_max_stam - max_stamina
	max_stamina = new_max_stam
	stamina = minf(stamina, max_stamina)
	hp_changed.emit(hp)
	mp_changed.emit(mp)
	stamina_changed.emit(stamina)
	weapon_system.update_pattern_for_weapon()

func _on_level_up(new_level: int) -> void:
	# Restore HP and stamina on level up
	max_hp = equipment_manager.get_max_hp()
	hp = max_hp
	max_mp = equipment_manager.get_max_mp()
	mp = max_mp
	max_stamina = equipment_manager.get_max_stamina()
	stamina = max_stamina
	hp_changed.emit(hp)
	mp_changed.emit(mp)
	stamina_changed.emit(stamina)
	equipment_manager.stats_changed.emit()

	# Visual flash
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2, 2, 0.5), 0.15)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	# SFX + VFX
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("level_up", 0.0, 0.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.level_up_burst(global_position)

func _get_player_class() -> String:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.get("selected_class"):
		return gm.selected_class
	return "warrior"

func _apply_class_stats() -> void:
	var pc = _get_player_class()
	var class_path = "res://resources/classes/%s.tres" % pc
	if pc == "ranger":
		class_path = "res://resources/classes/archer.tres"
	var player_class = load(class_path) as PlayerClass
	if not player_class:
		return
	var bs = equipment_manager.base_stats
	bs.max_hp = player_class.base_hp
	bs.move_speed = player_class.base_speed
	bs.attack_damage = int(player_class.base_damage)
	bs.max_mp = player_class.base_mp
	bs.weight = player_class.base_weight
	bs.acceleration = player_class.base_acceleration
	bs.tenacity = player_class.base_tenacity
	bs.thorns = player_class.base_thorns
	if pc == "mercenary":
		bs.max_stamina = 150.0  # mercenary has extra stamina for versatility

func get_poise() -> float:
	var pc = _get_player_class()
	var class_path = "res://resources/classes/%s.tres" % pc
	if pc == "ranger":
		class_path = "res://resources/classes/archer.tres"
	var player_class = load(class_path) as PlayerClass
	var base = player_class.base_poise if player_class else 3.0
	# Add equipment WEIGHT bonuses to poise (heavier gear = more poise)
	var weight_bonus = equipment_manager.get_weight() - (player_class.base_weight if player_class else 1.0)
	return base + maxf(weight_bonus, 0.0)

func apply_stagger(duration: float) -> void:
	if _stagger_cooldown > 0:
		return
	_stagger_cooldown = STAGGER_COOLDOWN
	# Apply SLOWED status effect
	status_effects.apply_effect(StatusEffect.Type.SLOWED, duration, 0.3)
	# Brief movement freeze (0.3s)
	_shield_break_stun = 0.3
	# Screen shake + VFX
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shake(4.0, 0.2)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("impact_a", -2.0)
	# Floating text
	var scene_root = get_tree().current_scene if is_inside_tree() else null
	if scene_root:
		FloatingText.spawn(scene_root, global_position + Vector2(0, -12), "STAGGERED!", Color(1.0, 0.6, 0.2))

func _setup_class_sprite() -> void:
	# Load class .tres and use its loy_tile_index for the player sprite
	var pc = _get_player_class()
	var class_path = "res://resources/classes/%s.tres" % pc
	# ranger uses archer.tres
	if pc == "ranger":
		class_path = "res://resources/classes/archer.tres"
	var player_class = load(class_path)
	if not player_class:
		return

	# Use animated spritesheet if anim_row is set
	var anim_row: int = player_class.get("anim_row") if player_class.get("anim_row") != null else -1
	if anim_row >= 0:
		_player_anim = PlayerAnimator.new()
		add_child(_player_anim)
		_player_anim.setup(sprite, anim_row)
		# 8x8 sprite, scale to match dungeon tiles (8px = 1 tile)
		sprite.scale = Vector2(1.0, 1.0)
		if player_class.get("sprite_color"):
			sprite.modulate = player_class.sprite_color
		return

	# Fallback: static LoY atlas sprite
	var tile_index: int = player_class.loy_tile_index
	var tex_path = LoySpriteIndex.get_char_texture_path(tile_index)
	var region = LoySpriteIndex.get_char_region(tile_index)
	var tex = load(tex_path) as Texture2D
	if not tex:
		return
	var atlas = AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = region
	sprite.texture = atlas
	sprite.hframes = 1
	sprite.vframes = 1
	sprite.frame = 0
	# chars.png is 32x32 per tile; in dungeons (8px tiles) scale down, overworld handles its own
	sprite.scale = Vector2(0.25, 0.25)
	# Apply class sprite tint
	if player_class.get("sprite_color"):
		sprite.modulate = player_class.sprite_color

func _swap_weapons() -> void:
	if not _secondary_weapon:
		return
	_weapon_swap_cooldown = WEAPON_SWAP_COOLDOWN
	var current_weapon = equipment_manager.get_equipped_weapon()
	if not current_weapon:
		return
	# Unequip current weapon
	var cur_idx = equipment_manager.inventory.find(current_weapon)
	if cur_idx < 0:
		return
	equipment_manager.toggle_equip(cur_idx)  # unequip
	# Equip secondary weapon (should be in inventory already)
	var sec_idx = equipment_manager.inventory.find(_secondary_weapon)
	if sec_idx < 0:
		# Secondary not in inventory — add it back
		equipment_manager.add_to_inventory(_secondary_weapon)
		sec_idx = equipment_manager.inventory.size() - 1
	equipment_manager.toggle_equip(sec_idx)
	# Swap references
	_secondary_weapon = current_weapon
	equipment_manager.inventory_changed.emit()
	# SFX
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("swing", -4.0, 0.05)

func _use_quickbar_slot(slot_index: int) -> void:
	if not is_inside_tree():
		return
	var hud = get_tree().get_first_node_in_group("game_hud") as GameHUD
	if not hud:
		return
	hud._on_quickbar_pressed(slot_index)

# Shield visual — directional arc that rotates toward shoot direction
var _shield_visual: Polygon2D = null
var _shield_angle: float = 0.0  # current shield facing angle
const SHIELD_ARC_INNER_BASE = 6.0   # inner radius in dungeon (8px tiles)
const SHIELD_ARC_OUTER_BASE = 10.0   # outer radius in dungeon
const SHIELD_ARC_ANGLE = PI * 0.7  # ~126 degree arc wrapping around
const SHIELD_ARC_SEGMENTS = 12
const SHIELD_TURN_SPEED = 3.5  # radians per second — takes ~0.5s to turn 180°
var _shield_charges_label: Label = null

func _get_shield_scale() -> float:
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	return 4.0 if in_ow else 1.0

func _update_shield_visual(active: bool) -> void:
	if active:
		var sc = _get_shield_scale()
		var inner = SHIELD_ARC_INNER_BASE * sc
		var outer = SHIELD_ARC_OUTER_BASE * sc
		if not _shield_visual:
			_shield_visual = Polygon2D.new()
			_shield_visual.name = "ShieldVisual"
			_shield_visual.color = Color(0.4, 0.55, 0.85, 0.45)
			_shield_visual.z_index = 1
			add_child(_shield_visual)
			_shield_angle = _get_shoot_direction().angle()
			# Shield HP label centered on arc
			_shield_charges_label = Label.new()
			_shield_charges_label.add_theme_font_size_override("font_size", 8 if sc < 2.0 else 16)
			_shield_charges_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
			_shield_charges_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_shield_charges_label.z_index = 2
			add_child(_shield_charges_label)
		# Rotate shield toward current shoot direction
		var target_angle = _get_shoot_direction().angle()
		var diff = angle_difference(_shield_angle, target_angle)
		var max_turn = SHIELD_TURN_SPEED * get_physics_process_delta_time()
		_shield_angle += clampf(diff, -max_turn, max_turn)
		# Build arc ring polygon (outer arc forward, inner arc back = band around character)
		var points: PackedVector2Array = []
		for seg_i in range(SHIELD_ARC_SEGMENTS + 1):
			var t = float(seg_i) / SHIELD_ARC_SEGMENTS
			var a = _shield_angle - SHIELD_ARC_ANGLE / 2.0 + SHIELD_ARC_ANGLE * t
			points.append(Vector2(cos(a), sin(a)) * outer)
		for seg_i in range(SHIELD_ARC_SEGMENTS, -1, -1):
			var t2 = float(seg_i) / SHIELD_ARC_SEGMENTS
			var a2 = _shield_angle - SHIELD_ARC_ANGLE / 2.0 + SHIELD_ARC_ANGLE * t2
			points.append(Vector2(cos(a2), sin(a2)) * inner)
		_shield_visual.polygon = points
		# Shield HP ratio affects opacity + color (blue→red as HP drops)
		var ratio = float(_shield_charges) / float(_shield_max_charges)
		var r = lerpf(0.8, 0.4, ratio)
		var g = lerpf(0.3, 0.55, ratio)
		_shield_visual.color = Color(r, g, 0.85, 0.3 + 0.35 * ratio)
		# Position HP label at shield center
		var label_pos = Vector2(cos(_shield_angle), sin(_shield_angle)) * (inner + outer) * 0.5
		_shield_charges_label.text = str(_shield_charges)
		_shield_charges_label.position = label_pos - Vector2(12, 6)
		sprite.modulate = Color(0.7, 0.8, 1.0)
	else:
		if _shield_visual:
			_shield_visual.queue_free()
			_shield_visual = null
		if _shield_charges_label:
			_shield_charges_label.queue_free()
			_shield_charges_label = null

func _get_shoot_direction() -> Vector2:
	## Returns the direction the player is currently shooting (for shield facing)
	if touch_controls and touch_controls.visible:
		var aim = touch_controls.get_aim_input()
		if aim.length() > 0:
			return aim.normalized()
	var mouse_pos = get_global_mouse_position()
	var dir = (mouse_pos - global_position).normalized()
	return dir if dir.length() > 0 else _last_move_dir

func _get_aim_direction() -> Vector2:
	return _get_shoot_direction()

func _give_starting_items() -> void:
	var player_class = _get_player_class()
	var starter_armor = load("res://resources/items/loy/leather_armor.tres") as EquipmentItem

	# Track which items go to quickbar (item_name -> quickbar slot index)
	var _quickbar_preload: Dictionary = {}

	match player_class:
		"warrior":
			var sword = load("res://resources/items/loy/sword.tres") as EquipmentItem
			var shield_item = load("res://resources/items/loy/wooden_shield.tres") as EquipmentItem
			if sword:
				equipment_manager.add_to_inventory(sword.make_copy())
				equipment_manager.toggle_equip(equipment_manager.inventory.size() - 1)
				_quickbar_preload[sword.item_name] = 0
			if shield_item:
				equipment_manager.add_to_inventory(shield_item.make_copy())
				equipment_manager.toggle_equip(equipment_manager.inventory.size() - 1)
				_quickbar_preload[shield_item.item_name] = 1
		"mercenary":
			var merc_sword = load("res://resources/items/loy/sword.tres") as EquipmentItem
			var short_bow = load("res://resources/items/loy/short_bow.tres") as EquipmentItem
			if merc_sword:
				equipment_manager.add_to_inventory(merc_sword.make_copy())
				equipment_manager.toggle_equip(equipment_manager.inventory.size() - 1)
				_quickbar_preload[merc_sword.item_name] = 0
			if short_bow:
				var sb_copy = short_bow.make_copy()
				equipment_manager.add_to_inventory(sb_copy)
				_quickbar_preload[short_bow.item_name] = 1
				_secondary_weapon = sb_copy
		"ranger":
			var bow = load("res://resources/items/loy/long_bow.tres") as EquipmentItem
			var dagger = load("res://resources/items/loy/dagger.tres") as EquipmentItem
			if bow:
				equipment_manager.add_to_inventory(bow.make_copy())
				equipment_manager.toggle_equip(equipment_manager.inventory.size() - 1)
				_quickbar_preload[bow.item_name] = 0
			if dagger:
				var dg_copy = dagger.make_copy()
				equipment_manager.add_to_inventory(dg_copy)
				_quickbar_preload[dagger.item_name] = 1
				_secondary_weapon = dg_copy
		"wizard":
			var staff = load("res://resources/items/loy/staff.tres") as EquipmentItem
			if staff:
				equipment_manager.add_to_inventory(staff.make_copy())
				equipment_manager.toggle_equip(equipment_manager.inventory.size() - 1)
				_quickbar_preload[staff.item_name] = 0

	if starter_armor:
		equipment_manager.add_to_inventory(starter_armor.make_copy())
		equipment_manager.toggle_equip(equipment_manager.inventory.size() - 1)

	# Give healing items
	var apple = load("res://resources/items/loy/apple.tres") as EquipmentItem
	if apple:
		for i in range(5):
			equipment_manager.add_to_inventory(apple.make_copy())
	var red_potion = load("res://resources/items/loy/red_potion.tres") as EquipmentItem
	if red_potion:
		for i in range(10):
			equipment_manager.add_to_inventory(red_potion.make_copy())
	var mana_potion = load("res://resources/items/loy/mana_potion.tres") as EquipmentItem
	if mana_potion:
		for i in range(5):
			equipment_manager.add_to_inventory(mana_potion.make_copy())

	# Pre-populate quickbar with weapons + potions (deferred so HUD is ready)
	var qb_data = _quickbar_preload.duplicate()
	call_deferred("_populate_quickbar", qb_data)

func _populate_quickbar(qb_data: Dictionary) -> void:
	if not is_inside_tree():
		return
	# Wait one more frame if HUD still not ready
	var hud = get_tree().get_first_node_in_group("game_hud") as GameHUD
	if not hud:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		hud = get_tree().get_first_node_in_group("game_hud") as GameHUD
	if not hud:
		return
	for item_name in qb_data:
		hud.assign_to_quickbar(qb_data[item_name], item_name)
	# Fill remaining slots with consumables
	if not qb_data.has("Red Potion"):
		hud.assign_to_quickbar(4, "Red Potion")
	if not qb_data.has("Mana Potion"):
		hud.assign_to_quickbar(5, "Mana Potion")

func _on_hitbox_area_entered(_area: Area2D) -> void:
	pass

# --- Dash ---

func _start_dash() -> void:
	# Consume stamina
	stamina -= DASH_STAMINA_COST
	_stamina_regen_delay = 1.0  # 1s delay before regen starts
	stamina_changed.emit(stamina)

	_is_dashing = true
	_dash_timer = DASH_DURATION
	_dash_cooldown = DASH_COOLDOWN
	_dash_direction = _last_move_dir
	_dash_hit_enemies.clear()
	sprite.modulate.a = 0.4  # ghost effect
	if _player_anim:
		_player_anim.set_direction(_dash_direction)  # lock direction to dash direction
		_player_anim.set_state(PlayerAnimator.AnimState.DASH)
	# SFX + VFX
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("woosh_a", -3.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.dash_afterimage(sprite, global_position)

## Dash-strike: damage and knockback enemies we collide with during dash (melee only)
## Also nudges ALL nearby enemies in dash direction (environmental knockback)
## Spear lunge: stronger push, escalating damage per enemy pierced
func _dash_strike_check() -> void:
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var nudge_range = 32.0 if in_ow else 8.0
	var nudge_speed = 320.0 if in_ow else 80.0

	var weapon = equipment_manager.get_equipped_weapon()
	var is_melee = weapon and weapon.slot_type == EquipmentItem.SlotType.WEAPON_MELEE
	var base_dmg = equipment_manager.get_damage() if is_melee else 0
	var dmg = maxi(1, int(base_dmg * 0.5)) if is_melee else 0
	var kb_force = 200.0 if in_ow else 60.0

	# Spear lunge: full weapon damage + escalating bonus per pierce, strong push
	if _lunge_active:
		dmg = maxi(1, base_dmg)  # full damage instead of 50%
		kb_force = 400.0 if in_ow else 120.0  # 2x knockback force

	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var dist = global_position.distance_to(e.global_position)
		if dist > nudge_range:
			continue
		# Bosses immune to nudge but take damage
		if e.get("definition") and e.definition and e.definition.size_class >= 2:  # BOSS
			if is_melee and not _dash_hit_enemies.has(e.get_instance_id()):
				_dash_hit_enemies[e.get_instance_id()] = true
				var boss_dmg = int(dmg * DASH_BOSS_DMG_MULT)
				if _lunge_active:
					_lunge_hit_count += 1
					boss_dmg = int(boss_dmg * (1.0 + _lunge_hit_count * 0.5))
				e.take_damage(boss_dmg) if e.has_method("take_damage") else null
			continue
		# Melee dash-strike damage (only melee weapons)
		if is_melee and not _dash_hit_enemies.has(e.get_instance_id()):
			_dash_hit_enemies[e.get_instance_id()] = true
			var hit_dmg = dmg
			if _lunge_active:
				_lunge_hit_count += 1
				# Each successive enemy takes +50% more: 1st=100%, 2nd=150%, 3rd=200%, etc.
				hit_dmg = int(dmg * (1.0 + (_lunge_hit_count - 1) * 0.5))
			if e.has_method("take_damage"):
				e.take_damage(hit_dmg)
			# Spear lunge pushes enemies far in the charge direction (not radially)
			if _lunge_active:
				if "_pushed_velocity" in e:
					e._pushed_velocity = _dash_direction * kb_force
				else:
					e.velocity = _dash_direction * kb_force
				e._contact_bounce = 0.3 if "_contact_bounce" in e else 0.0
			else:
				var kb_dir = (e.global_position - global_position).normalized()
				if "_pushed_velocity" in e:
					e._pushed_velocity = kb_dir * kb_force
				else:
					e.velocity = kb_dir * kb_force
				e._contact_bounce = 0.2 if "_contact_bounce" in e else 0.0
			# VFX: impact spark per hit during lunge
			if _lunge_active:
				var vfx = get_node_or_null("/root/VFXManager")
				if vfx:
					vfx.hit_spark(e.global_position)
		# Environmental nudge: push enemy in dash direction (all weapons)
		elif e.get("_nudge_timer") != null and e._nudge_timer <= 0:
			e._nudge_velocity = _dash_direction * nudge_speed
			e._nudge_timer = 0.15

# --- Bow Multishot ---

func _fire_multishot(aim_dir: Vector2) -> void:
	if not is_inside_tree():
		return
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	var bullet_scene = weapon_system.bullet_scene
	if not bullet_scene:
		return
	var base_damage = equipment_manager.get_damage()
	var speed = equipment_manager.get_bullet_speed()
	for i in range(MULTISHOT_EXTRA_BULLETS):
		var angle_offset = MULTISHOT_SPREAD * (i + 1) * (1.0 if i % 2 == 0 else -1.0)
		var spread_dir = aim_dir.rotated(angle_offset)
		var bullet = bullet_scene.instantiate()
		bullet.global_position = global_position
		bullet.direction = spread_dir
		bullet.is_player_bullet = true
		bullet.speed = speed
		bullet.damage = maxi(1, int(base_damage * 0.6))  # 60% damage on spread shots
		bullets_container.add_child(bullet)
	# SFX for multishot burst
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("shoot_b", -8.0, 0.1)

# --- Staff Charged Blast ---

func _fire_charged_blast() -> void:
	if not is_inside_tree():
		return
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	var bullet_scene = weapon_system.bullet_scene
	if not bullet_scene:
		return

	# Charge ratio: 0.0 (min charge) to 1.0 (full charge)
	var ratio = clampf((_charge_time - CHARGE_MIN_TIME) / (CHARGE_MAX_TIME - CHARGE_MIN_TIME), 0.0, 1.0)
	var fully_charged = ratio >= 0.5  # 50%+ = full powered piercing blast

	var aim_dir: Vector2
	if touch_controls and touch_controls.visible and touch_controls.get_aim_input().length() > 0.1:
		aim_dir = touch_controls.get_aim_input().normalized()
	else:
		aim_dir = (get_global_mouse_position() - global_position).normalized()

	var base_damage = equipment_manager.get_damage()
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = aim_dir
	bullet.is_player_bullet = true
	var shield_penalty = 0.5 if _shield_active else 1.0

	if fully_charged:
		# Full blast: high damage, pierces everything, big projectile
		var power_ratio = clampf((ratio - 0.5) / 0.5, 0.0, 1.0)  # 0-1 within the 50-100% range
		var dmg_mult = lerpf(3.0, CHARGE_DMG_MULT, power_ratio)
		var flat_bonus = int(lerpf(8.0, CHARGE_FLAT_DMG, power_ratio))
		var size_mult = lerpf(2.0, CHARGE_SIZE_MULT, power_ratio)
		bullet.speed = equipment_manager.get_bullet_speed() * CHARGE_SPEED_MULT * shield_penalty
		bullet.damage = maxi(5, int(base_damage * dmg_mult) + flat_bonus)
		bullet.scale = Vector2(size_mult, size_mult)
		bullet.pierce_count = 99  # pierces all enemies
		bullets_container.add_child(bullet)
		bullet.collision_mask = bullet.collision_mask & ~16  # passes through walls
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("bazooka", -5.0, 0.05)
		var vfx = get_node_or_null("/root/VFXManager")
		if vfx:
			vfx.charged_impact(global_position, ratio)
			vfx.shake(1.0 + ratio * 2.0, 0.15)
	else:
		# Weak quick shot: base damage +1, no pierce, small projectile
		bullet.speed = equipment_manager.get_bullet_speed() * 0.8 * shield_penalty
		bullet.damage = base_damage + 1
		bullet.scale = Vector2(1.2, 1.2)
		bullets_container.add_child(bullet)
		var sfx2 = get_node_or_null("/root/SFXManager")
		if sfx2:
			sfx2.play("spell_b", -8.0, 0.1)

func _fire_longshot() -> void:
	if _player_anim:
		_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK)
	if not is_inside_tree():
		return
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	var bullet_scene = weapon_system.bullet_scene
	if not bullet_scene:
		return

	var aim_dir: Vector2
	if touch_controls and touch_controls.visible and touch_controls.get_aim_input().length() > 0.1:
		aim_dir = touch_controls.get_aim_input().normalized()
	else:
		aim_dir = (get_global_mouse_position() - global_position).normalized()

	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = aim_dir
	bullet.is_player_bullet = true
	bullet.speed = equipment_manager.get_bullet_speed()
	bullet.damage = LONGSHOT_DMG
	bullet.pierce_count = LONGSHOT_PIERCE
	# Use same range as equipped bow
	bullet.bullet_sprite_index = equipment_manager.get_bullet_sprite_index()
	var wrange = equipment_manager.get_weapon_range()
	if wrange > 0.0:
		var range_scale = 0.25 if get("in_dungeon") else 1.0
		bullet.lifetime = wrange * range_scale / maxf(bullet.speed, 1.0) * 100.0
	bullet.set_meta("longshot_paralyze", true)
	bullet.set_meta("longshot_stun_min", LONGSHOT_STUN_MIN)
	bullet.set_meta("longshot_stun_max", LONGSHOT_STUN_MAX)
	bullets_container.add_child(bullet)
	# Tint bullet yellow-green for paralyze
	var bspr = bullet.get_node_or_null("Sprite2D")
	if bspr:
		bspr.modulate = Color(0.6, 1.0, 0.3)
	# SFX
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("woosh_a", -1.0, 0.05)

var _charge_circle: Polygon2D = null  # grey growing circle pointing at shoot dir
const CHARGE_CIRCLE_SEGMENTS = 16
var _charge_hit_enemies: Dictionary = {}  # enemies already hit this charge

func _show_charge_indicator() -> void:
	if _charge_indicator:
		return
	# Bar above head
	_charge_indicator = ColorRect.new()
	_charge_indicator.size = Vector2(0, 4)
	_charge_indicator.color = Color(0.4, 0.6, 1.0, 0.9)
	_charge_indicator.position = Vector2(-16, -24)
	_charge_indicator.z_index = 10
	add_child(_charge_indicator)
	# Grey directional circle that grows — flat arc pointing at shoot direction
	_charge_circle = Polygon2D.new()
	_charge_circle.color = Color(0.6, 0.6, 0.65, 0.3)
	_charge_circle.z_index = -1
	add_child(_charge_circle)
	_charge_hit_enemies.clear()

func _update_charge_indicator() -> void:
	if not _charge_indicator:
		return
	var ratio = clampf(_charge_time / CHARGE_MAX_TIME, 0.0, 1.0)
	_charge_indicator.size.x = 32.0 * ratio
	_charge_indicator.color = Color(0.4 + 0.6 * ratio, 0.6 + 0.4 * ratio, 1.0, 0.9)
	# Grey circle grows with charge, has a directional notch pointing at shoot dir
	if _charge_circle:
		var shoot_dir = _get_shoot_direction()
		var center_angle = shoot_dir.angle()
		var circle_radius = 6.0 + 18.0 * ratio
		var points: PackedVector2Array = []
		# Full circle with a pointed tip in shoot direction
		for i in range(CHARGE_CIRCLE_SEGMENTS):
			var a = TAU * float(i) / CHARGE_CIRCLE_SEGMENTS
			var r = circle_radius
			# Extend radius in shoot direction to create a pointed shape
			var angle_to_shoot = abs(angle_difference(a, center_angle))
			if angle_to_shoot < 0.5:
				r += (circle_radius * 0.6) * (1.0 - angle_to_shoot / 0.5)
			points.append(Vector2(cos(a), sin(a)) * r)
		_charge_circle.polygon = points
		# Gets brighter/more opaque as charge builds
		var grey = 0.5 + 0.3 * ratio
		_charge_circle.color = Color(grey, grey, grey + 0.1, 0.2 + 0.35 * ratio)
	# Sprite brightens while charging
	sprite.modulate = Color(0.85 + 0.3 * ratio, 0.85 + 0.3 * ratio, 1.0 + 0.5 * ratio)
	# Collision damage — enemies touching us while charging take damage
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var hit_range = (12.0 + 8.0 * ratio) * (4.0 if in_ow else 1.0)
	var charge_dmg = maxi(1, int(equipment_manager.get_damage() * ratio * 2.0))
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(global_position) < hit_range:
			if not _charge_hit_enemies.has(enemy.get_instance_id()):
				_charge_hit_enemies[enemy.get_instance_id()] = true
				if enemy.has_method("take_damage"):
					enemy.take_damage(charge_dmg)

func _hide_charge_indicator() -> void:
	if _charge_indicator:
		_charge_indicator.queue_free()
		_charge_indicator = null
	if _charge_circle:
		_charge_circle.queue_free()
		_charge_circle = null
	sprite.modulate = Color.WHITE
	_charge_hit_enemies.clear()

# --- Spell Slot System ---

func _setup_starter_spells() -> void:
	if not spell_book:
		return
	var pc = _get_player_class()
	# Class-based starter spells:
	# Warrior: 0 spells (shield is his ability)
	# Mercenary: 0 spells
	# Ranger: arrow_rain
	# Wizard: frost_nova + teleport
	var starter_ids: Array[String] = []
	match pc:
		"warrior":
			starter_ids = ["shield_bash"]
		"mercenary":
			starter_ids = ["battle_cry"]
		"ranger":
			starter_ids = ["arrow_rain"]
		"wizard":
			starter_ids = ["frost_nova"]

	var all_spells = {
		"shield_bash": "res://resources/spells/shield_bash.tres",
		"arrow_rain": "res://resources/spells/arrow_rain.tres",
		"frost_nova": "res://resources/spells/frost_nova.tres",
		"battle_cry": "res://resources/spells/battle_cry.tres",
		"blade_flurry": "res://resources/spells/blade_flurry.tres",
		"smoke_bomb": "res://resources/spells/smoke_bomb.tres",
		"execute": "res://resources/spells/execute.tres",
		"stone_toss": "res://resources/spells/stone_toss.tres",
		"berserk": "res://resources/spells/berserk.tres",
		"fire_fists": "res://resources/spells/fire_fists.tres",
		"venom_coat": "res://resources/spells/venom_coat.tres",
		"iron_skin": "res://resources/spells/iron_skin.tres",
		"heal": "res://resources/spells/heal.tres",
		"greater_heal": "res://resources/spells/greater_heal.tres",
		"cleanse": "res://resources/spells/cleanse.tres",
		"mana_surge": "res://resources/spells/mana_surge.tres",
		"fireball_spell": "res://resources/spells/fireball_spell.tres",
		"chain_lightning": "res://resources/spells/chain_lightning.tres",
		"life_drain": "res://resources/spells/life_drain.tres",
		"fear_shout": "res://resources/spells/fear_shout.tres",
		"shadow_strike": "res://resources/spells/shadow_strike.tres",
	}
	var slot_idx = 0
	for sid in starter_ids:
		if not all_spells.has(sid):
			continue
		var spell = load(all_spells[sid]) as SpellDefinition
		if spell:
			spell_book.learn_spell(spell)
			spell_book.equip_spell(spell, slot_idx)
			slot_idx += 1

func _use_spell_slot(index: int) -> void:
	if not spell_book or index < 0 or index >= spell_book.MAX_SPELL_SLOTS:
		return
	var spell = spell_book.spell_slots[index] as SpellDefinition
	if not spell:
		return

	if not spell_book.can_cast(index, mp):
		return
	# Mana Surge costs stamina instead of MP
	if spell.id == "mana_surge" and stamina < 30.0:
		return
	use_mp(spell.mp_cost)
	var cdr = clampf(equipment_manager.get_total_cooldown_reduction(), 0.0, 50.0)
	spell_book.slot_cooldowns[index] = spell.cooldown * (1.0 - cdr / 100.0)

	if _player_anim:
		_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK)

	# Starter spells use legacy scaling; crafted spells use fixed magnitude
	if spell.is_starter:
		match spell.id:
			"shield_bash":
				_ability_shield_bash()
			"arrow_rain":
				_ability_arrow_rain()
			"frost_nova":
				_ability_frost_nova()
			"battle_cry":
				_ability_battle_cry()
			"blade_flurry":
				_ability_blade_flurry()
			"smoke_bomb":
				_ability_smoke_bomb()
			"execute":
				_ability_execute()
			"berserk":
				_ability_berserk()
			"fire_fists":
				_ability_fire_fists()
			"venom_coat":
				_ability_venom_coat()
			"iron_skin":
				_ability_iron_skin()
			"heal":
				_ability_heal()
			"greater_heal":
				_ability_greater_heal()
			"cleanse":
				_ability_cleanse()
			"mana_surge":
				_ability_mana_surge()
			"fireball_spell":
				_ability_fireball()
			"chain_lightning":
				_ability_chain_lightning()
			"life_drain":
				_ability_life_drain()
			"fear_shout":
				_ability_fear_shout()
			"shadow_strike":
				_ability_shadow_strike()
			_:
				_cast_crafted_spell(index, spell)
	else:
		_cast_crafted_spell(index, spell)

func _cast_crafted_spell(index: int, spell: SpellDefinition) -> void:
	var aim_dir = _last_move_dir
	if touch_controls and touch_controls.visible and touch_controls.get_aim_input().length() > 0.1:
		aim_dir = touch_controls.get_aim_input().normalized()
	else:
		var mouse_pos = get_global_mouse_position()
		aim_dir = (mouse_pos - global_position).normalized()
	spell_book.cast_spell(index, self, aim_dir)

func _toggle_spellbook() -> void:
	var sb_ui = get_tree().get_first_node_in_group("spellbook_ui") as SpellBookUI
	if sb_ui:
		if sb_ui.is_open():
			sb_ui.close()
		else:
			sb_ui.open()
	else:
		sb_ui = SpellBookUI.new()
		get_tree().current_scene.add_child(sb_ui)
		sb_ui.open()

# --- Legacy Abilities (starter spell scaling) ---

func _ability_shield_bash() -> void:
	# Cone knockback + damage + stun in shoot direction
	var base_dmg = equipment_manager.get_damage()
	var dmg = int(base_dmg * 2.5 + level_system.level * 0.5)
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_mult = 4.0 if in_ow else 1.0
	var radius = (24.0 + level_system.level * 0.5) * scale_mult
	var kb_force = (200.0 + base_dmg * 5.0) * scale_mult
	var cone_half_angle = 0.7  # ~40 degrees half-angle
	var stun_duration = 1.5  # seconds enemies can't attack
	var aim_dir = _get_shoot_direction()
	# Crit chance based on luck
	var luck = equipment_manager.get_luck()
	var crit_mult = equipment_manager.get_crit_damage()
	if luck > 0 and randf() * 100.0 < luck:
		dmg = int(dmg * crit_mult)

	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var to_enemy = e.global_position - global_position
		var dist = to_enemy.length()
		if dist > radius:
			continue
		# Cone check — only hit enemies in the aimed direction
		var angle = aim_dir.angle_to(to_enemy.normalized())
		if absf(angle) > cone_half_angle:
			continue
		if e.has_method("take_damage"):
			e.take_damage(dmg)
		# Knockback
		var kb_dir = to_enemy.normalized()
		e.velocity = kb_dir * kb_force
		# Stun — stops enemies from attacking
		if e.has_method("apply_status"):
			e.apply_status("STUNNED", stun_duration)
	# Bridge to SoA battle units
	set_meta("battle_aoe", {
		"radius": radius, "damage": float(dmg), "stun": stun_duration,
		"knockback": kb_force * 0.02, "direction": aim_dir, "cone_angle": cone_half_angle * 2.0
	})
	# Visual: brief white flash + cone shockwave VFX
	sprite.modulate = Color(2, 2, 1)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position, radius, Color(1.0, 0.9, 0.5, 0.6))
		vfx.shake(2.5, 0.2)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("area_effect_a", 0.0)

func _stone_toss() -> void:
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_mult = 4.0 if in_ow else 1.0
	# Land at cursor position, clamped to max range
	var target_pos: Vector2
	if touch_controls and touch_controls.visible and touch_controls.get_aim_input().length() > 0.1:
		var aim_dir = touch_controls.get_aim_input().normalized()
		target_pos = global_position + aim_dir * STONE_TOSS_RANGE * scale_mult
	else:
		target_pos = get_global_mouse_position()
		var to_target = target_pos - global_position
		var max_range = STONE_TOSS_RANGE * scale_mult
		if to_target.length() > max_range:
			target_pos = global_position + to_target.normalized() * max_range
	var aim_dir = (target_pos - global_position).normalized()
	var bullet_scn = preload("res://scenes/bullet.tscn")
	var stone = bullet_scn.instantiate()
	stone.global_position = global_position
	stone.direction = aim_dir
	stone.is_player_bullet = true
	stone.damage = 0  # no damage — triggers noise on landing
	stone.lifetime = 2.0
	stone.bullet_sprite_index = 131  # grey bolt from lofi_obj.png
	stone.behavior = stone.BulletBehavior.LOBBED
	stone._target_pos = target_pos
	stone._lob_start_pos = global_position
	stone._lob_duration = 0.4
	stone._lob_height = 0.8
	stone._lob_aoe_radius = 0.0
	stone._lob_ring_count = 0
	stone._lob_cluster_count = 0
	get_tree().current_scene.add_child(stone)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click", -6.0)

func _wrestle_grab() -> void:
	var aim_dir = _get_shoot_direction()
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var grab_range = WRESTLE_RANGE_OVERWORLD if in_ow else WRESTLE_RANGE_DUNGEON
	var scale_mult = 4.0 if in_ow else 1.0
	# Find nearest enemy in cone
	var best_enemy: Node2D = null
	var best_dist: float = grab_range + 1.0
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.state == e.State.DEAD:
			continue
		# Boss immunity
		if e.definition and e.definition.size_class >= e.definition.SizeClass.BOSS:
			continue
		var to_e = e.global_position - global_position
		var d = to_e.length()
		if d > grab_range:
			continue
		if d < 1.0:
			if d < best_dist:
				best_enemy = e
				best_dist = d
			continue
		var angle = aim_dir.angle_to(to_e.normalized())
		if absf(angle) > WRESTLE_CONE_HALF:
			continue
		if d < best_dist:
			best_enemy = e
			best_dist = d
	if not best_enemy:
		return
	# Player lunge toward target
	var lunge_dir = (best_enemy.global_position - global_position).normalized()
	velocity = lunge_dir * 60.0 * scale_mult
	# Grab SFX
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("claw", -3.0)
	# Throw after brief grab delay (0.15s)
	var throw_dir = aim_dir
	var throw_force = WRESTLE_THROW_FORCE * scale_mult
	var thrower_dmg = equipment_manager.get_damage()
	# Use a timer for the grab delay
	get_tree().create_timer(0.15).timeout.connect(
		func():
			if is_instance_valid(best_enemy) and best_enemy.has_method("apply_throw"):
				best_enemy.apply_throw(throw_dir, throw_force, thrower_dmg)
	)

func _ability_arrow_rain() -> void:
	# Fire arrows in random directions around aim — count and damage scale with stats
	var aim_dir: Vector2
	if touch_controls and touch_controls.visible and touch_controls.get_aim_input().length() > 0.1:
		aim_dir = touch_controls.get_aim_input().normalized()
	else:
		aim_dir = (get_global_mouse_position() - global_position).normalized()

	var bullet_scn = preload("res://scenes/bullet.tscn")
	var base_dmg = equipment_manager.get_damage()
	var arrow_count = 8 + level_system.level / 5  # +1 arrow every 5 levels
	var spread = 1.2 + level_system.level * 0.02  # total random spread cone
	var luck = equipment_manager.get_luck()
	var crit_mult = equipment_manager.get_crit_damage()

	for i in range(arrow_count):
		var random_angle = aim_dir.angle() + randf_range(-spread * 0.5, spread * 0.5)
		var b = bullet_scn.instantiate()
		b.global_position = global_position
		b.direction = Vector2.from_angle(random_angle)
		b.speed = equipment_manager.get_bullet_speed() * randf_range(1.0, 1.4)
		var dmg = base_dmg
		# Each arrow can crit independently
		if luck > 0 and randf() * 100.0 < luck:
			dmg = int(dmg * crit_mult)
		b.damage = dmg
		b.is_player_bullet = true
		b.lifetime = 2.0
		b.pierce_count = equipment_manager.get_pierce_count()
		b.bullet_sprite_index = 145  # yellow bolt sprite
		b.enchant_type = 0  # FIRE tint
		get_tree().current_scene.add_child(b)
	# Visual: brief yellow flash + arrow burst VFX
	sprite.modulate = Color(1.5, 1.5, 0.5)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.arrow_rain_burst(global_position)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("shotgun", -2.0)

func _ability_frost_nova() -> void:
	# Targeted AoE freeze at aim position — distributes damage across enemies
	var base_dmg = equipment_manager.get_damage()
	var max_total_dmg = maxi(3, int(base_dmg * 3.0 + level_system.level * 0.8))
	var in_ow_fn = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var ow_scale = 4.0 if in_ow_fn else 1.0
	var radius = (28.0 + level_system.level * 0.5) * ow_scale
	var freeze_dur = 1.5 + level_system.level * 0.04
	var luck = equipment_manager.get_luck()
	var crit_mult = equipment_manager.get_crit_damage()
	if luck > 0 and randf() * 100.0 < luck:
		max_total_dmg = int(max_total_dmg * crit_mult)

	# Target at aim position (mouse or touch) clamped to max range
	var target_pos: Vector2
	var max_range = (60.0 + level_system.level * 1.0) * ow_scale
	if touch_controls and touch_controls.visible and touch_controls.get_aim_input().length() > 0.1:
		target_pos = global_position + touch_controls.get_aim_input().normalized() * max_range * 0.5
	else:
		target_pos = get_global_mouse_position()
	# Clamp to max range
	var offset_vec = target_pos - global_position
	if offset_vec.length() > max_range:
		target_pos = global_position + offset_vec.normalized() * max_range

	# Collect enemies in range, freeze all, distribute damage pool
	var hit_enemies: Array = []
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var dist = target_pos.distance_to(e.global_position)
		if dist < radius:
			hit_enemies.append(e)
			if e.has_method("apply_status"):
				e.apply_status("FROZEN", freeze_dur)

	# Distribute damage: total pool split across all hit enemies (min 1 each)
	if hit_enemies.size() > 0:
		var dmg_per = maxi(1, max_total_dmg / hit_enemies.size())
		for e in hit_enemies:
			if e.has_method("take_damage"):
				e.take_damage(dmg_per)
	# Bridge to SoA battle units (AoE freeze at target position)
	set_meta("battle_aoe", {
		"radius": radius, "damage": float(max_total_dmg) / maxf(1.0, float(hit_enemies.size())),
		"stun": freeze_dur, "knockback": 0.0,
		"direction": Vector2.ZERO, "cone_angle": PI * 2.0,
		"center": target_pos,  # Frost nova is at target pos, not player pos
	})
	# Visual: brief blue flash + frost ring at target
	sprite.modulate = Color(0.5, 0.8, 2.0)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.frost_ring(target_pos, radius)
		vfx.shake(1.5, 0.15)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("sorcery", 0.0)

func _ability_teleport() -> void:
	# Blink forward in aim direction — distance scales with level
	var aim_dir = _get_shoot_direction()
	var in_ow_tp = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var base_dist = 60.0 + level_system.level * 1.5
	var dist = base_dist * (4.0 if in_ow_tp else 1.0)
	var start_pos = global_position
	var target = global_position + aim_dir * dist
	# Raycast to prevent teleporting through walls / out of bounds
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target, collision_mask)
	var result = space.intersect_ray(query)
	if result:
		# Stop short of the wall (2px buffer so we don't clip inside)
		target = result.position - aim_dir * 2.0
	# Brief invincibility during teleport
	invincible = true
	global_position = target
	# Visual: fade out at start, fade in at end
	sprite.modulate = Color(0.5, 0.5, 2.0, 0.3)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	tween.tween_callback(func(): invincible = false)
	# VFX at start and end
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.hit_spark(start_pos, Color(0.4, 0.5, 1.5))
		vfx.hit_spark(target, Color(0.4, 0.5, 1.5))
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("teleport", -2.0, 0.05)

func _ability_battle_cry() -> void:
	# Big damage + attack speed + move speed buff, taunt nearby enemies
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_mult = 4.0 if in_ow else 1.0
	var taunt_radius = 48.0 * scale_mult
	var buff_duration = 6.0 + level_system.level * 0.15
	var dmg_buff = 0.5 + level_system.level * 0.02  # +50%+ damage
	# Apply buffs to self
	if status_effects:
		status_effects.apply_buff("damage", buff_duration, dmg_buff)
		status_effects.apply_buff("speed", buff_duration, 0.25)
		status_effects.apply_buff("fire_rate", buff_duration, 0.3)  # 30% faster attacks
	# Taunt all nearby enemies — force them to aggro and chase
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(global_position) < taunt_radius:
			if e.get("_hit_aggro_timer") != null:
				e._hit_aggro_timer = buff_duration
			if e.get("_chase_timer") != null:
				e._chase_timer = 0.0
	# Bridge to SoA — battle cry taunts SoA enemies (stagger = interrupt)
	set_meta("battle_aoe", {
		"radius": taunt_radius, "damage": 0.0, "stun": 0.5,
		"knockback": 0.0, "direction": Vector2.ZERO, "cone_angle": PI * 2.0
	})
	# Visual: sustained red/orange glow during buff
	sprite.modulate = Color(2.0, 1.2, 0.5)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.5, 1.1, 0.8), 0.3)
	tween.tween_interval(buff_duration - 0.6)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position, taunt_radius, Color(1.0, 0.6, 0.2, 0.5))
		vfx.shake(2.0, 0.15)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("area_effect_a", -2.0)

func _ability_blade_flurry() -> void:
	# Quick 3-hit combo in a cone — deals 3x base damage
	var aim_dir = _get_shoot_direction()
	var base_dmg = equipment_manager.get_damage()
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_mult = 4.0 if in_ow else 1.0
	var radius = 20.0 * scale_mult
	var cone_half = 0.6  # ~35 degrees
	var total_dmg = int(base_dmg * 3.0 + level_system.level * 0.5)
	var kb_force = 150.0 * scale_mult
	var luck = equipment_manager.get_luck()
	var crit_mult = equipment_manager.get_crit_damage()
	if luck > 0 and randf() * 100.0 < luck:
		total_dmg = int(total_dmg * crit_mult)
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var to_e = e.global_position - global_position
		if to_e.length() > radius:
			continue
		if absf(aim_dir.angle_to(to_e.normalized())) > cone_half:
			continue
		if e.has_method("take_damage"):
			e.take_damage(total_dmg)
		e.velocity = to_e.normalized() * kb_force
	# Bridge to SoA battle system
	set_meta("battle_aoe", {"radius": radius, "damage": total_dmg, "stun": 0.0, "knockback": kb_force, "direction": aim_dir, "cone_angle": cone_half})
	# Visual: 3 rapid flashes
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2, 1, 0.5), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	tween.tween_property(sprite, "modulate", Color(2, 1, 0.5), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	tween.tween_property(sprite, "modulate", Color(2, 1, 0.5), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("swing", -3.0, 0.0)
		get_tree().create_timer(0.1).timeout.connect(func(): if sfx: sfx.play("swing", -3.0, 0.05))
		get_tree().create_timer(0.2).timeout.connect(func(): if sfx: sfx.play("swing", -3.0, 0.1))

func _ability_smoke_bomb() -> void:
	# Blind nearby enemies (stunned 2s) + player gets invisibility + speed boost
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_mult = 4.0 if in_ow else 1.0
	var radius = 32.0 * scale_mult
	var blind_duration = 2.0 + level_system.level * 0.05
	# Blind/stun nearby enemies
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(global_position) < radius:
			if e.has_method("apply_status"):
				e.apply_status("STUNNED", blind_duration)
	# Bridge to SoA battle system
	set_meta("battle_aoe", {"radius": radius, "damage": 0, "stun": blind_duration, "knockback": 0.0})
	# Player gets invisibility + speed buff + sneak mode + stealth buff
	invincible = true
	_sneaking = true
	sprite.modulate.a = 0.3
	if status_effects:
		status_effects.apply_buff("speed", blind_duration, 0.5)
		status_effects.apply_buff("stealth", blind_duration, 50.0)
	var tween = create_tween()
	tween.tween_interval(blind_duration)
	tween.tween_callback(func():
		invincible = false
		_sneaking = false
		sprite.modulate.a = 1.0
	)
	# Visual: dark puff
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position, radius, Color(0.2, 0.2, 0.2, 0.8))
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("curse", -3.0)

func _ability_execute() -> void:
	# Powerful single strike — 3x bonus damage to enemies below 30% HP
	var aim_dir = _get_shoot_direction()
	var base_dmg = equipment_manager.get_damage()
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_mult = 4.0 if in_ow else 1.0
	var radius = 18.0 * scale_mult
	var cone_half = 0.5
	var dmg = int(base_dmg * 2.0 + level_system.level)
	var luck = equipment_manager.get_luck()
	var crit_mult = equipment_manager.get_crit_damage()
	if luck > 0 and randf() * 100.0 < luck:
		dmg = int(dmg * crit_mult)
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var to_e = e.global_position - global_position
		if to_e.length() > radius:
			continue
		if absf(aim_dir.angle_to(to_e.normalized())) > cone_half:
			continue
		var hit_dmg = dmg
		# Execute bonus: 3x damage to low HP enemies
		if e.get("hp") != null and e.get("_max_hp") != null:
			if e.hp < e._max_hp * 0.3:
				hit_dmg = int(hit_dmg * 3.0)
		if e.has_method("take_damage"):
			e.take_damage(hit_dmg)
		e.velocity = to_e.normalized() * 100.0 * scale_mult
	# Bridge to SoA battle system (execute bonus not applied to SoA — just base damage)
	set_meta("battle_aoe", {"radius": radius, "damage": dmg, "stun": 0.0, "knockback": 100.0 * scale_mult, "direction": aim_dir, "cone_angle": cone_half})
	# Visual: dark red flash + VFX
	sprite.modulate = Color(2.0, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("special_a", -2.0, 0.05)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position + aim_dir * radius * 0.5, radius, Color(1.0, 0.2, 0.2, 0.6))
		vfx.shake(1.5, 0.12)

# --- New Ability Spells ---

func _ability_berserk() -> void:
	# +50% damage, +25% speed, reduced armor for 8s
	status_effects.apply_buff("damage", 8.0, 0.5)
	status_effects.apply_buff("speed", 8.0, 0.25)
	var armor_penalty = -int(maxf(equipment_manager.get_armor() * 0.3, 2.0))
	status_effects.apply_buff("armor", 8.0, armor_penalty)
	# Visual: red pulsing glow
	sprite.modulate = Color(2.0, 0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.3, 0.8, 0.8), 0.5)
	tween.tween_property(sprite, "modulate", Color(2.0, 0.5, 0.5), 0.5)
	tween.set_loops(8)  # pulse for 8s
	tween.finished.connect(func(): sprite.modulate = Color.WHITE)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("area_effect_a", 0.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.status_puff(global_position, Color(1.0, 0.3, 0.3))

func _ability_fire_fists() -> void:
	# +25% damage, bullets apply BURNING for 8s
	status_effects.apply_buff("damage", 8.0, 0.25)
	set_meta("fire_fists_active", true)
	# Timer to clear the flag
	get_tree().create_timer(8.0).timeout.connect(func():
		set_meta("fire_fists_active", false)
	)
	# Visual: orange glow
	sprite.modulate = Color(2.0, 1.2, 0.5)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.4, 1.0, 0.7), 0.5)
	tween.tween_property(sprite, "modulate", Color(2.0, 1.2, 0.5), 0.5)
	tween.set_loops(8)
	tween.finished.connect(func(): sprite.modulate = Color.WHITE)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("area_effect_a", -2.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.status_puff(global_position, Color(1.0, 0.6, 0.2))

func _ability_venom_coat() -> void:
	# Bullets apply POISONED for 8s
	set_meta("venom_coat_active", true)
	get_tree().create_timer(8.0).timeout.connect(func():
		set_meta("venom_coat_active", false)
	)
	# Visual: green glow
	sprite.modulate = Color(0.7, 2.0, 0.5)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(0.8, 1.4, 0.7), 0.5)
	tween.tween_property(sprite, "modulate", Color(0.7, 2.0, 0.5), 0.5)
	tween.set_loops(8)
	tween.finished.connect(func(): sprite.modulate = Color.WHITE)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("curse", -2.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.status_puff(global_position, Color(0.3, 1.0, 0.3))

func _ability_iron_skin() -> void:
	# +5 flat armor for 10s (significant at all levels)
	status_effects.apply_buff("armor", 10.0, 5.0)
	# Visual: grey metallic tint
	sprite.modulate = Color(1.5, 1.5, 1.6)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.2, 1.2, 1.3), 1.0)
	tween.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.6), 1.0)
	tween.set_loops(5)
	tween.finished.connect(func(): sprite.modulate = Color.WHITE)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("clack", -2.0)

func _ability_heal() -> void:
	# Restore 20 + level*2 HP
	var amount = 20 + level_system.level * 2
	heal(amount)
	# Visual: green flash + status puff
	sprite.modulate = Color(0.5, 2.0, 0.5)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("heal_a", 0.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.status_puff(global_position, Color(0.2, 1.0, 0.3))

func _ability_greater_heal() -> void:
	# Restore 50 + level*3 HP
	var amount = 50 + level_system.level * 3
	heal(amount)
	# Visual: bright green flash
	sprite.modulate = Color(0.3, 2.5, 0.3)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.4)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("heal_a", 2.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.status_puff(global_position, Color(0.2, 1.0, 0.3))
		vfx.status_puff(global_position + Vector2(0, -8), Color(0.2, 1.0, 0.3))

func _ability_cleanse() -> void:
	# Remove all negative statuses
	status_effects.remove_all_negative()
	# Visual: white flash
	sprite.modulate = Color(2.5, 2.5, 2.5)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("heal_a", -2.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.status_puff(global_position, Color.WHITE)

func _ability_mana_surge() -> void:
	# Spend 30 stamina to restore 30% max MP
	stamina -= 30.0
	_stamina_regen_delay = 1.0
	stamina_changed.emit(stamina)
	var restore = max_mp * 0.3
	mp = minf(mp + restore, max_mp)
	mp_changed.emit(mp)
	# Visual: blue flash
	sprite.modulate = Color(0.5, 0.5, 2.5)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("mystical", -2.0)
	var scene_root = get_tree().current_scene
	if scene_root:
		FloatingText.spawn(scene_root, global_position + Vector2(0, -8), "+%d MP" % int(restore), Color(0.3, 0.5, 1.0))

func _ability_fireball() -> void:
	# Large slow projectile, explodes on impact for AoE + BURNING
	var aim_dir = _get_shoot_direction()
	var base_dmg = equipment_manager.get_damage()
	var dmg = int(base_dmg * 2.0 + level_system.level)
	var luck = equipment_manager.get_luck()
	if luck > 0 and randf() * 100.0 < luck:
		dmg = int(dmg * equipment_manager.get_crit_damage())
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_mult = 4.0 if in_ow else 1.0
	var bullet_scene = preload("res://scenes/bullet.tscn")
	var fireball = bullet_scene.instantiate()
	fireball.global_position = global_position
	fireball.direction = aim_dir
	fireball.is_player_bullet = true
	fireball.speed = equipment_manager.get_bullet_speed() * 0.5
	fireball.damage = dmg
	fireball.lifetime = 2.0
	fireball.set_meta("fireball_aoe", true)
	fireball.set_meta("fireball_aoe_radius", 20.0 * scale_mult)
	fireball.set_meta("fireball_aoe_dmg_pct", 0.6)
	fireball.set_meta("apply_burning", 3.0)
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if bullets_container:
		bullets_container.add_child(fireball)
	else:
		get_tree().current_scene.add_child(fireball)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("sorcery", -2.0)

func _ability_chain_lightning() -> void:
	# Instant hit on nearest enemy, chains to 2 more
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_mult = 4.0 if in_ow else 1.0
	var max_range = 40.0 * scale_mult
	var chain_range = 30.0 * scale_mult
	var base_dmg = equipment_manager.get_damage()
	var dmg = int(base_dmg * 1.5 + level_system.level * 0.8)
	var luck = equipment_manager.get_luck()
	if luck > 0 and randf() * 100.0 < luck:
		dmg = int(dmg * equipment_manager.get_crit_damage())
	# Find nearest enemy
	var enemies = get_tree().get_nodes_in_group("enemy")
	var nearest: Node2D = null
	var nearest_dist: float = max_range + 1.0
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var d = global_position.distance_to(e.global_position)
		if d < nearest_dist:
			nearest = e
			nearest_dist = d
	if not nearest:
		# Refund MP — no target
		mp = minf(mp + 20.0, max_mp)
		mp_changed.emit(mp)
		return
	# Hit first target
	var hit_targets: Array[Node2D] = [nearest]
	if nearest.has_method("take_damage"):
		nearest.take_damage(dmg)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.hit_spark(nearest.global_position, Color(0.8, 0.9, 1.0))
	# Chain to 2 more
	var current = nearest
	var chain_dmg = dmg
	for _i in range(2):
		chain_dmg = int(chain_dmg * 0.7)
		var next_target: Node2D = null
		var next_dist: float = chain_range + 1.0
		for e in enemies:
			if not is_instance_valid(e) or e in hit_targets:
				continue
			var d = current.global_position.distance_to(e.global_position)
			if d < next_dist:
				next_target = e
				next_dist = d
		if not next_target:
			break
		hit_targets.append(next_target)
		if next_target.has_method("take_damage"):
			next_target.take_damage(chain_dmg)
		if vfx:
			vfx.hit_spark(next_target.global_position, Color(0.8, 0.9, 1.0))
		current = next_target
	# Bridge to SoA battle system (hits in radius around player)
	set_meta("battle_aoe", {"radius": max_range, "damage": dmg, "stun": 0.3, "knockback": 0.0})
	# Visual: white flash on player
	sprite.modulate = Color(2.0, 2.0, 2.5)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("shock", -2.0)
	if vfx:
		vfx.shake(1.0, 0.1)

func _ability_life_drain() -> void:
	# Cone attack, heals player for 50% of damage dealt
	var aim_dir = _get_shoot_direction()
	var base_dmg = equipment_manager.get_damage()
	var dmg = int(base_dmg * 1.5)
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_mult = 4.0 if in_ow else 1.0
	var radius = 20.0 * scale_mult
	var cone_half = 0.6
	var luck = equipment_manager.get_luck()
	if luck > 0 and randf() * 100.0 < luck:
		dmg = int(dmg * equipment_manager.get_crit_damage())
	var total_dealt := 0
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var to_e = e.global_position - global_position
		if to_e.length() > radius:
			continue
		if to_e.length() > 1.0 and absf(aim_dir.angle_to(to_e.normalized())) > cone_half:
			continue
		if e.has_method("take_damage"):
			e.take_damage(dmg)
			total_dealt += dmg
		# Purple tint flash on enemy
		var espr = e.get_node_or_null("Sprite2D")
		if espr:
			espr.modulate = Color(1.5, 0.3, 1.5)
			var etw = create_tween()
			etw.tween_property(espr, "modulate", Color.WHITE, 0.3)
	# Bridge to SoA battle system
	set_meta("battle_aoe", {"radius": radius, "damage": dmg, "stun": 0.0, "knockback": 0.0, "direction": aim_dir, "cone_angle": cone_half})
	# Heal for 50% of damage dealt
	if total_dealt > 0:
		heal(int(total_dealt * 0.5))
	# Visual: green heal flash on player
	sprite.modulate = Color(0.8, 2.0, 0.8)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("curse", 0.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position + aim_dir * radius * 0.5, radius, Color(0.6, 0.2, 0.8, 0.5))

func _ability_fear_shout() -> void:
	# All enemies within 32px radius → FEARED 3s
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_mult = 4.0 if in_ow else 1.0
	var radius = 32.0 * scale_mult
	var enemies = get_tree().get_nodes_in_group("enemy")
	var hit_count := 0
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if global_position.distance_to(e.global_position) > radius:
			continue
		if e.has_method("apply_status"):
			e.apply_status("FEARED", 3.0)
			hit_count += 1
	# Bridge to SoA battle system (fear = stun in SoA)
	set_meta("battle_aoe", {"radius": radius, "damage": 0, "stun": 3.0, "knockback": 0.0})
	# Visual: dark shockwave
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position, radius, Color(0.3, 0.2, 0.4, 0.7))
		vfx.shake(2.0, 0.15)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("area_effect_a", 0.0)

func _ability_shadow_strike() -> void:
	# Blink to nearest enemy within 48px, backstab damage. 5x from stealth
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_mult = 4.0 if in_ow else 1.0
	var max_range = 48.0 * scale_mult
	var base_dmg = equipment_manager.get_damage()
	var was_sneaking = _sneaking
	# Find nearest enemy
	var enemies = get_tree().get_nodes_in_group("enemy")
	var target: Node2D = null
	var target_dist: float = max_range + 1.0
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var d = global_position.distance_to(e.global_position)
		if d < target_dist:
			target = e
			target_dist = d
	if not target:
		# Refund MP — no target
		mp = minf(mp + 15.0, max_mp)
		mp_changed.emit(mp)
		return
	# Calculate damage
	var dmg = int(base_dmg * 3.0)
	if was_sneaking:
		dmg = int(base_dmg * 5.0)
	var luck = equipment_manager.get_luck()
	if luck > 0 and randf() * 100.0 < luck:
		dmg = int(dmg * equipment_manager.get_crit_damage())
	# Teleport behind enemy
	var dir_to_player = (global_position - target.global_position).normalized()
	var arrive_pos = target.global_position + dir_to_player * (-8.0 * scale_mult)
	var start_pos = global_position
	invincible = true
	global_position = arrive_pos
	# Deal damage
	if target.has_method("take_damage"):
		target.take_damage(dmg)
	# Stun if was sneaking
	if was_sneaking and target.has_method("apply_status"):
		target.apply_status("STUNNED", 1.0)
	_sneaking = false
	# Visual: dark purple flash at start + end
	sprite.modulate = Color(1.0, 0.3, 1.5, 0.5)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	tween.tween_callback(func(): invincible = false)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.hit_spark(start_pos, Color(0.5, 0.2, 0.8))
		vfx.hit_spark(arrive_pos, Color(0.5, 0.2, 0.8))
		if was_sneaking:
			vfx.crit_spark(target.global_position)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("teleport", -4.0)
	var scene_root = get_tree().current_scene
	if scene_root:
		if was_sneaking:
			FloatingText.spawn(scene_root, target.global_position + Vector2(0, -12), "BACKSTAB!", Color(0.8, 0.2, 1.0))

func _ability_blood_pact() -> void:
	# Sacrifice 30% current HP for +100% damage and +50% attack speed for 8s
	var sacrifice = int(hp * 0.3)
	hp -= sacrifice
	hp = maxi(hp, 1)
	hp_changed.emit(hp)
	status_effects.apply_buff("damage", 8.0, 1.0)
	status_effects.apply_buff("attack_speed", 8.0, -0.15)  # negative = faster
	# Red blood visual
	sprite.modulate = Color(2.0, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5), 0.5)
	tween.tween_property(sprite, "modulate", Color(2.0, 0.3, 0.3), 0.5)
	tween.set_loops(8)
	tween.finished.connect(func(): sprite.modulate = Color.WHITE)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("impact_a", 0.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.blood_splatter(global_position, Vector2.UP, Color(0.8, 0.0, 0.0))
		vfx.status_puff(global_position, Color(1.0, 0.2, 0.2))
	var scene_root = get_tree().current_scene
	if scene_root:
		FloatingText.spawn(scene_root, global_position + Vector2(0, -12), "-%d HP" % sacrifice, Color(1.0, 0.3, 0.3))

func _ability_borrowed_time() -> void:
	# Become immune for 3s, then take 50% of absorbed damage
	set_meta("borrowed_time_active", true)
	set_meta("borrowed_time_stored", 0.0)
	invincible = true
	# Golden shimmer
	sprite.modulate = Color(2.0, 1.8, 0.8)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.5, 1.3, 0.6), 0.5)
	tween.tween_property(sprite, "modulate", Color(2.0, 1.8, 0.8), 0.5)
	tween.set_loops(3)
	tween.finished.connect(func():
		sprite.modulate = Color.WHITE
		invincible = false
		set_meta("borrowed_time_active", false)
		var stored = get_meta("borrowed_time_stored", 0.0) as float
		if stored > 0:
			var payback = int(stored * 0.5)
			if payback > 0:
				hp -= payback
				hp = maxi(hp, 1)
				hp_changed.emit(hp)
				var scene_root2 = get_tree().current_scene
				if scene_root2:
					FloatingText.spawn_damage(scene_root2, global_position, payback, Color(1.0, 0.8, 0.2))
				var vfx2 = get_node_or_null("/root/VFXManager")
				if vfx2:
					vfx2.shake(2.0, 0.15)
		remove_meta("borrowed_time_stored")
	)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("mystical", 0.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position, 16.0, Color(1.0, 0.9, 0.4, 0.6))

func _ability_bulwark() -> void:
	# 70% damage reduction for 5s, -40% speed
	set_meta("bulwark_active", true)
	status_effects.apply_buff("speed", 5.0, -0.4)
	sprite.modulate = Color(0.7, 0.7, 0.8)
	get_tree().create_timer(5.0).timeout.connect(func():
		if is_instance_valid(self):
			set_meta("bulwark_active", false)
			sprite.modulate = Color.WHITE
	)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("clack", -2.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position, 10.0, Color(0.5, 0.5, 0.6, 0.6))

func _ability_consecration() -> void:
	# Holy zone: 6s, damages enemies inside, heals player inside
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_mult = 4.0 if in_ow else 1.0
	var zone_radius = 24.0 * scale_mult
	var zone_pos = global_position
	var zone_dmg = 3 + level_system.level
	var zone_heal = 3.0
	var zone_node = Node2D.new()
	zone_node.global_position = zone_pos
	zone_node.set_meta("consecration_radius", zone_radius)
	get_tree().current_scene.add_child(zone_node)
	var tick_count = 0
	var tick_timer = Timer.new()
	tick_timer.wait_time = 0.5
	tick_timer.one_shot = false
	zone_node.add_child(tick_timer)
	tick_timer.timeout.connect(func():
		tick_count += 1
		if tick_count >= 12 or not is_instance_valid(zone_node):
			zone_node.queue_free()
			return
		var enemies = get_tree().get_nodes_in_group("enemy")
		for e in enemies:
			if is_instance_valid(e) and e.global_position.distance_to(zone_pos) < zone_radius:
				if e.has_method("take_damage"):
					e.take_damage(zone_dmg)
		if is_instance_valid(self) and global_position.distance_to(zone_pos) < zone_radius:
			heal(int(zone_heal))
		var vfx2 = get_node_or_null("/root/VFXManager")
		if vfx2:
			vfx2.shockwave(zone_pos, zone_radius * 0.5, Color(1.0, 0.9, 0.4, 0.3))
	)
	tick_timer.start()
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("sorcery", -2.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(zone_pos, zone_radius, Color(1.0, 0.9, 0.4, 0.5))

func _ability_evasion_surge() -> void:
	# 80% dodge + 50% speed for 5s
	status_effects.apply_buff("dodge", 5.0, 80.0)
	status_effects.apply_buff("speed", 5.0, 0.5)
	var _trail_count = 0
	var trail_timer = Timer.new()
	trail_timer.wait_time = 0.15
	trail_timer.one_shot = false
	add_child(trail_timer)
	trail_timer.timeout.connect(func():
		_trail_count += 1
		if _trail_count >= 33 or not is_instance_valid(self):
			trail_timer.stop()
			trail_timer.queue_free()
			return
		var vfx2 = get_node_or_null("/root/VFXManager")
		if vfx2:
			vfx2.dash_afterimage(global_position, Color(1.0, 1.0, 1.0, 0.3))
	)
	trail_timer.start()
	sprite.modulate = Color(2.0, 2.0, 2.0)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("woosh_b", 0.0)

func _ability_gravity_well() -> void:
	# Place a vortex that pulls enemies for 3s
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_mult = 4.0 if in_ow else 1.0
	var aim_dir = _get_shoot_direction()
	var well_pos = global_position + aim_dir * 24.0 * scale_mult
	var well_radius = 32.0 * scale_mult
	var well_node = Node2D.new()
	well_node.global_position = well_pos
	get_tree().current_scene.add_child(well_node)
	var tick_count = 0
	var pull_timer = Timer.new()
	pull_timer.wait_time = 0.1
	pull_timer.one_shot = false
	well_node.add_child(pull_timer)
	pull_timer.timeout.connect(func():
		tick_count += 1
		if tick_count >= 30 or not is_instance_valid(well_node):
			well_node.queue_free()
			return
		var enemies = get_tree().get_nodes_in_group("enemy")
		for e in enemies:
			if not is_instance_valid(e):
				continue
			var d = e.global_position.distance_to(well_pos)
			if d < well_radius and d > 4.0:
				var pull_dir = (well_pos - e.global_position).normalized()
				var strength = (1.0 - d / well_radius) * 80.0 * scale_mult
				e.velocity += pull_dir * strength
				if e.has_method("apply_status"):
					e.apply_status("SLOWED", 0.3)
		if tick_count % 5 == 0:
			var vfx2 = get_node_or_null("/root/VFXManager")
			if vfx2:
				vfx2.shockwave(well_pos, well_radius * 0.3, Color(0.4, 0.2, 0.8, 0.4))
	)
	pull_timer.start()
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("sorcery", -2.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(well_pos, well_radius, Color(0.4, 0.2, 0.8, 0.5))

func _ability_mana_shield() -> void:
	# Damage absorbed by MP (2 MP per 1 HP) for 8s
	set_meta("mana_shield_active", true)
	sprite.modulate = Color(0.6, 0.8, 2.0)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(0.7, 0.9, 1.5), 0.5)
	tween.tween_property(sprite, "modulate", Color(0.6, 0.8, 2.0), 0.5)
	tween.set_loops(8)
	tween.finished.connect(func():
		sprite.modulate = Color.WHITE
		set_meta("mana_shield_active", false)
	)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("mystical", -2.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.status_puff(global_position, Color(0.3, 0.5, 1.0))

func _ability_mirror_image() -> void:
	# Spawn 2 decoy copies for 5s
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_mult = 4.0 if in_ow else 1.0
	for i in range(2):
		var decoy = Area2D.new()
		decoy.name = "MirrorDecoy_%d" % i
		decoy.add_to_group("player")
		decoy.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-12, 12)) * scale_mult
		var decoy_spr = Sprite2D.new()
		decoy_spr.texture = sprite.texture
		decoy_spr.hframes = sprite.hframes
		decoy_spr.vframes = sprite.vframes
		decoy_spr.frame = sprite.frame
		decoy_spr.modulate = Color(1.0, 1.0, 1.0, 0.4)
		decoy.add_child(decoy_spr)
		var col = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 4.0 * scale_mult
		col.shape = shape
		decoy.add_child(col)
		decoy.collision_layer = 1
		decoy.collision_mask = 0
		decoy.set_meta("decoy_hp", 1)
		get_tree().current_scene.add_child(decoy)
		var wander_timer = Timer.new()
		wander_timer.wait_time = 0.3
		wander_timer.one_shot = false
		decoy.add_child(wander_timer)
		var wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		wander_timer.timeout.connect(func():
			if is_instance_valid(decoy):
				wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
				decoy.position += wander_dir * 4.0 * scale_mult
		)
		wander_timer.start()
		get_tree().create_timer(5.0).timeout.connect(func():
			if is_instance_valid(decoy):
				decoy.queue_free()
		)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("teleport", -4.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.status_puff(global_position, Color(1.0, 1.0, 1.0, 0.5))

func _ability_phase_shift() -> void:
	# Intangible for 2s - no damage, no attacks, move through enemies
	invincible = true
	set_meta("phase_shift_active", true)
	collision_layer = 0
	sprite.modulate = Color(0.5, 0.7, 1.5, 0.3)
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(self):
			invincible = false
			set_meta("phase_shift_active", false)
			collision_layer = 1
			sprite.modulate = Color.WHITE
	)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("teleport", -4.0)

func _ability_reflect_barrier() -> void:
	# Reflect all projectiles for 4s
	set_meta("reflect_barrier_active", true)
	sprite.modulate = Color(0.5, 2.0, 2.0)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(0.7, 1.4, 1.4), 0.5)
	tween.tween_property(sprite, "modulate", Color(0.5, 2.0, 2.0), 0.5)
	tween.set_loops(4)
	tween.finished.connect(func():
		sprite.modulate = Color.WHITE
		set_meta("reflect_barrier_active", false)
	)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("clack", 0.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position, 12.0, Color(0.3, 1.0, 1.0, 0.6))

func _ability_soul_drain() -> void:
	# Channel for 3s: damage nearby enemies, heal 50% of damage dealt
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_mult = 4.0 if in_ow else 1.0
	var drain_radius = 16.0 * scale_mult
	var drain_dmg = 2 + level_system.level
	set_meta("channeling", true)
	sprite.modulate = Color(1.0, 0.5, 2.0)
	var tick_count = 0
	var drain_timer = Timer.new()
	drain_timer.wait_time = 0.5
	drain_timer.one_shot = false
	add_child(drain_timer)
	drain_timer.timeout.connect(func():
		tick_count += 1
		if tick_count >= 6 or not is_instance_valid(self) or not get_meta("channeling", false):
			set_meta("channeling", false)
			sprite.modulate = Color.WHITE
			drain_timer.stop()
			drain_timer.queue_free()
			return
		var total_dealt = 0
		var enemies = get_tree().get_nodes_in_group("enemy")
		for e in enemies:
			if is_instance_valid(e) and e.global_position.distance_to(global_position) < drain_radius:
				if e.has_method("take_damage"):
					e.take_damage(drain_dmg)
					total_dealt += drain_dmg
		if total_dealt > 0:
			heal(int(total_dealt * 0.5))
		var vfx2 = get_node_or_null("/root/VFXManager")
		if vfx2:
			vfx2.status_puff(global_position, Color(0.6, 0.2, 1.0))
	)
	drain_timer.start()
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("curse", -2.0)

func _ability_time_warp() -> void:
	# Slow all enemies and enemy bullets by 60% for 4s
	set_meta("time_warp_active", true)
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(self):
			set_meta("time_warp_active", false)
	)
	sprite.modulate = Color(0.7, 0.5, 2.0)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("sorcery", 0.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position, 48.0, Color(0.5, 0.3, 1.0, 0.4))
		vfx.shake(1.0, 0.1)

# --- First-person 3D view ---

func _input(event: InputEvent) -> void:
	if fps_mode and event is InputEventMouseMotion:
		fps_angle += event.relative.x * FPS_MOUSE_SENSITIVITY

func _toggle_fps_mode() -> void:
	if not _first_person_view:
		return
	fps_mode = !fps_mode
	_first_person_view.visible = fps_mode
	_first_person_view.enabled = fps_mode
	if fps_mode:
		fps_angle = _last_move_dir.angle()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# Disable 2D camera so 3D viewport shows
		var cam2d = get_node_or_null("Camera2D")
		if cam2d:
			cam2d.enabled = false
		_first_person_view.update_camera(global_position, fps_angle)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var cam2d_restore = get_node_or_null("Camera2D")
		if cam2d_restore:
			cam2d_restore.enabled = true

# ── New weapon_type abilities ──

func _ground_pound() -> void:
	# Club: 360-degree AoE stun + damage, no movement
	stamina -= 25.0
	_stamina_regen_delay = 1.0
	stamina_changed.emit(stamina)
	_dash_cooldown = 1.0
	if _player_anim:
		_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK)

	var base_dmg = equipment_manager.get_damage()
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_mult = 4.0 if in_ow else 1.0
	var radius = 40.0 * scale_mult
	var total_dmg = int(base_dmg * 2.5 + level_system.level * 0.5)
	var luck = equipment_manager.get_luck()
	if luck > 0 and randf() * 100.0 < luck:
		total_dmg = int(total_dmg * equipment_manager.get_crit_damage())
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var dist = e.global_position.distance_to(global_position)
		if dist > radius:
			continue
		if e.has_method("take_damage"):
			e.take_damage(total_dmg)
		if e.has_method("apply_status"):
			e.apply_status("STUNNED", 1.5)
		# Strong knockback away from player center
		var kb_dir = (e.global_position - global_position).normalized()
		var kb_force = 400.0 * scale_mult
		e.velocity = kb_dir * kb_force
	# Visual: shockwave + screen shake
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position, radius, Color(0.8, 0.6, 0.3, 0.5))
		vfx.shake(3.0, 0.2)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("area_effect_a", -2.0, 0.0)

func _hammer_throw() -> void:
	# Hammer: fire boomerang projectile, 3x dmg, pierce + AoE knockback from player
	stamina -= 20.0
	_stamina_regen_delay = 1.0
	stamina_changed.emit(stamina)
	_dash_cooldown = 2.0
	if _player_anim:
		_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK)

	var aim_dir = _get_shoot_direction()
	var bullet_scene = preload("res://scenes/bullet.tscn")
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = aim_dir
	bullet.is_player_bullet = true
	bullet.speed = equipment_manager.get_bullet_speed() * 0.8
	bullet.damage = int(equipment_manager.get_damage() * 3.0)
	bullet.pierce_count = 99  # pierce all
	bullet.lifetime = 1.5
	bullet.behavior = bullet.BulletBehavior.BOOMERANG
	bullet._origin_entity = self
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if bullets_container:
		bullets_container.add_child(bullet)

	# AoE knockback: push all nearby enemies away from player
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_mult = 4.0 if in_ow else 1.0
	var push_radius = 48.0 * scale_mult
	var push_force = 350.0 * scale_mult
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(global_position) > push_radius:
			continue
		var kb_dir = (e.global_position - global_position).normalized()
		e.velocity = kb_dir * push_force

	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position, push_radius * 0.8, Color(0.7, 0.5, 0.2, 0.4))
		vfx.shake(2.0, 0.15)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("swing", -3.0, 0.05)

var _lunge_active: bool = false
var _lunge_hit_count: int = 0  # escalating damage per enemy pierced

func _start_lunge() -> void:
	# Spear: 2.5x distance charge with line damage, push, and escalating pierce damage
	stamina -= DASH_STAMINA_COST
	_stamina_regen_delay = 1.0
	stamina_changed.emit(stamina)
	_dash_cooldown = DASH_COOLDOWN + 0.4

	var dir = _get_shoot_direction()
	_dash_direction = dir
	_is_dashing = true
	_lunge_active = true
	_lunge_hit_count = 0
	_dash_timer = DASH_DURATION * 2.5  # 2.5x distance for a proper charge
	if _player_anim:
		_player_anim.set_direction(_dash_direction)  # lock direction to lunge direction
		_player_anim.set_state(PlayerAnimator.AnimState.DASH)
	_dash_hit_enemies.clear()
	invincible = true
	sprite.modulate = Color(1.5, 1.0, 0.5, 0.6)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("swing", -2.0, 0.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position, 24.0, Color(1.0, 0.8, 0.4, 0.5))

func _power_shot() -> void:
	# Crossbow: quick high-damage shot, pierce all
	stamina -= 20.0
	_stamina_regen_delay = 1.0
	stamina_changed.emit(stamina)
	_dash_cooldown = 1.5
	if _player_anim:
		_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK)

	var aim_dir = _get_shoot_direction()
	var bullet_scene = preload("res://scenes/bullet.tscn")
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = aim_dir
	bullet.is_player_bullet = true
	bullet.speed = equipment_manager.get_bullet_speed() * 1.5
	bullet.damage = int(equipment_manager.get_damage() * 4.0)
	bullet.pierce_count = 99
	bullet.lifetime = 2.0
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if bullets_container:
		bullets_container.add_child(bullet)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("shoot_a", -2.0, 0.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.hit_spark(global_position + aim_dir * 6.0, Color(1.0, 0.9, 0.4))

func _handle_whip_spin(delta: float) -> void:
	# Flail Shift: extended range boomerang multishot
	stamina = maxf(stamina - 25.0 * delta, 0.0)
	_stamina_regen_delay = 0.5
	stamina_changed.emit(stamina)
	if stamina <= 0:
		return
	# Fire boomerang bullets outward in a ring every 0.3s
	if _multishot_cooldown <= 0:
		_multishot_cooldown = 0.3
		var aim_dir = _get_shoot_direction()
		var bullet_scene = preload("res://scenes/bullet.tscn")
		var bullets_container = get_tree().get_first_node_in_group("bullets")
		if not bullets_container:
			return
		for i in range(3):
			var angle_offset = (i - 1) * 0.4
			var dir = aim_dir.rotated(angle_offset)
			var bullet = bullet_scene.instantiate()
			bullet.global_position = global_position
			bullet.direction = dir
			bullet.is_player_bullet = true
			bullet.speed = equipment_manager.get_bullet_speed() * 0.6
			bullet.damage = int(equipment_manager.get_damage() * 1.5)
			bullet.pierce_count = 2
			bullet.lifetime = 0.8
			bullet.behavior = bullet.BulletBehavior.BOOMERANG
			bullet._origin_entity = self
			bullets_container.add_child(bullet)
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("swing", -5.0, 0.1)

func _handle_barrage() -> void:
	# Throwing Shift: scatter burst of projectiles
	stamina -= 20.0
	_stamina_regen_delay = 1.0
	stamina_changed.emit(stamina)
	_barrage_cooldown = 2.0
	if _player_anim:
		_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK)

	var aim_dir = _get_shoot_direction()
	var bullet_scene = preload("res://scenes/bullet.tscn")
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	for i in range(7):
		var angle_offset = (i - 3) * 0.15 + randf_range(-0.05, 0.05)
		var dir = aim_dir.rotated(angle_offset)
		var bullet = bullet_scene.instantiate()
		bullet.global_position = global_position
		bullet.direction = dir
		bullet.is_player_bullet = true
		bullet.speed = equipment_manager.get_bullet_speed() * (0.8 + randf() * 0.4)
		bullet.damage = equipment_manager.get_damage()
		bullet.lifetime = 0.6
		bullets_container.add_child(bullet)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("shoot_a", -3.0, 0.1)

func _wand_blink() -> void:
	stamina -= 15.0
	_stamina_regen_delay = 1.0
	stamina_changed.emit(stamina)
	_dash_cooldown = 0.8
	if _player_anim:
		_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK)

	var dir = _last_move_dir if _last_move_dir != Vector2.ZERO else _get_shoot_direction()
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var blink_dist = 60.0 * (4.0 if in_ow else 1.0)
	var target = global_position + dir * blink_dist
	invincible = true
	sprite.modulate.a = 0.3
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.dash_afterimage(sprite, global_position)
	global_position = target
	if vfx:
		vfx.hit_spark(global_position, Color(0.5, 0.7, 1.0))
	_dash_linger = 0.2
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 1.0, 0.2)
	tween.tween_callback(func(): invincible = false)
	var sfx_wb = get_node_or_null("/root/SFXManager")
	if sfx_wb:
		sfx_wb.play("spell_a", -4.0, 0.1)

func _tome_nova_burst() -> void:
	stamina -= 30.0
	_stamina_regen_delay = 1.0
	stamina_changed.emit(stamina)
	_dash_cooldown = 1.5
	if _player_anim:
		_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK)

	var base_dmg = equipment_manager.get_damage()
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_m = 4.0 if in_ow else 1.0
	var radius = 40.0 * scale_m
	var total_dmg = int(base_dmg * 3.0 + level_system.level * 0.5)
	var bullet_scene = preload("res://scenes/bullet.tscn")
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if bullets_container:
		for i in range(8):
			var angle = i * TAU / 8.0
			var dir = Vector2(cos(angle), sin(angle))
			var bullet = bullet_scene.instantiate()
			bullet.global_position = global_position
			bullet.direction = dir
			bullet.is_player_bullet = true
			bullet.speed = equipment_manager.get_bullet_speed() * 0.6
			bullet.damage = int(base_dmg * 1.5)
			bullet.pierce_count = 2
			bullet.lifetime = 0.5
			bullets_container.add_child(bullet)
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(global_position) > radius:
			continue
		if e.has_method("take_damage"):
			e.take_damage(total_dmg)
		if e.has_method("apply_status"):
			e.apply_status("SLOWED", 1.5)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position, radius, Color(0.4, 0.3, 1.0, 0.6))
		vfx.shake(2.5, 0.15)
	var sfx_tn = get_node_or_null("/root/SFXManager")
	if sfx_tn:
		sfx_tn.play("area_effect_a", -2.0, 0.0)

func _javelin_throw() -> void:
	stamina -= 20.0
	_stamina_regen_delay = 1.0
	stamina_changed.emit(stamina)
	_dash_cooldown = 1.2
	if _player_anim:
		_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK)

	var aim_dir = _get_shoot_direction()
	var bullet_scene = preload("res://scenes/bullet.tscn")
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = aim_dir
	bullet.is_player_bullet = true
	bullet.speed = equipment_manager.get_bullet_speed() * 2.0
	bullet.damage = int(equipment_manager.get_damage() * 3.5)
	bullet.pierce_count = 5
	bullet.lifetime = 2.0
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if bullets_container:
		bullets_container.add_child(bullet)
	var sfx_jt = get_node_or_null("/root/SFXManager")
	if sfx_jt:
		sfx_jt.play("swing", -2.0, 0.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.hit_spark(global_position + aim_dir * 6.0, Color(0.8, 0.7, 0.3))

func _sling_scatter_volley() -> void:
	stamina -= 20.0
	_stamina_regen_delay = 1.0
	stamina_changed.emit(stamina)
	_dash_cooldown = 1.0
	if _player_anim:
		_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK)

	var aim_dir = _get_shoot_direction()
	var bullet_scene = preload("res://scenes/bullet.tscn")
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	for i in range(6):
		var angle_offset = (i - 2.5) * 0.2 + randf_range(-0.05, 0.05)
		var dir = aim_dir.rotated(angle_offset)
		var bullet = bullet_scene.instantiate()
		bullet.global_position = global_position
		bullet.direction = dir
		bullet.is_player_bullet = true
		bullet.speed = equipment_manager.get_bullet_speed() * (0.9 + randf() * 0.3)
		bullet.damage = int(equipment_manager.get_damage() * 1.2)
		bullet.lifetime = 0.7
		bullets_container.add_child(bullet)
	var sfx_ss = get_node_or_null("/root/SFXManager")
	if sfx_ss:
		sfx_ss.play("shoot_a", -3.0, 0.1)

func _halberd_sweep() -> void:
	stamina -= 25.0
	_stamina_regen_delay = 1.0
	stamina_changed.emit(stamina)
	_dash_cooldown = 1.0
	if _player_anim:
		_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK)

	var aim_dir = _get_shoot_direction()
	var base_dmg = equipment_manager.get_damage()
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_m = 4.0 if in_ow else 1.0
	var sweep_range = 28.0 * scale_m
	var sweep_angle = PI * 0.6
	var total_dmg = int(base_dmg * 2.0)
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var to_enemy = e.global_position - global_position
		var dist = to_enemy.length()
		if dist > sweep_range:
			continue
		var angle_diff = abs(aim_dir.angle_to(to_enemy.normalized()))
		if angle_diff > sweep_angle / 2.0:
			continue
		if e.has_method("take_damage"):
			e.take_damage(total_dmg)
		var kb_dir = to_enemy.normalized()
		e.velocity = kb_dir * 300.0 * scale_m
	var bullet_scene = preload("res://scenes/bullet.tscn")
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if bullets_container:
		for i in range(3):
			var angle_off = (i - 1) * 0.35
			var dir = aim_dir.rotated(angle_off)
			var bullet = bullet_scene.instantiate()
			bullet.global_position = global_position + aim_dir * 4.0
			bullet.direction = dir
			bullet.is_player_bullet = true
			bullet.speed = equipment_manager.get_bullet_speed() * 0.7
			bullet.damage = int(base_dmg * 1.2)
			bullet.pierce_count = 2
			bullet.lifetime = 0.4
			bullets_container.add_child(bullet)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position + aim_dir * 12.0 * scale_m, sweep_range * 0.6, Color(0.8, 0.8, 0.8, 0.5))
		vfx.shake(2.0, 0.12)
	var sfx_hs = get_node_or_null("/root/SFXManager")
	if sfx_hs:
		sfx_hs.play("swing", -2.0, 0.0)

func _earthquake_slam() -> void:
	var base_dmg = equipment_manager.get_damage()
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_m = 4.0 if in_ow else 1.0
	var radius = 28.0 * scale_m
	var slam_dmg = int(base_dmg * 1.5)
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(global_position) > radius:
			continue
		if e.has_method("take_damage"):
			e.take_damage(slam_dmg)
		if e.has_method("apply_status"):
			e.apply_status("STUNNED", 0.4)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position, radius, Color(0.6, 0.4, 0.2, 0.4))
		vfx.shake(1.5, 0.1)
	var sfx_eq = get_node_or_null("/root/SFXManager")
	if sfx_eq:
		sfx_eq.play("area_effect_a", -6.0, 0.1)

func _flail_chain_lash() -> void:
	stamina -= 20.0
	_stamina_regen_delay = 1.0
	stamina_changed.emit(stamina)
	_dash_cooldown = 1.2
	if _player_anim:
		_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK)
	var aim_dir = _get_shoot_direction()
	var base_dmg = equipment_manager.get_damage()
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_m = 4.0 if in_ow else 1.0
	var lash_range = 32.0 * scale_m
	var lash_angle = PI * 0.5
	var total_dmg = int(base_dmg * 2.0)
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var to_enemy = e.global_position - global_position
		var dist = to_enemy.length()
		if dist > lash_range:
			continue
		var angle_diff = abs(aim_dir.angle_to(to_enemy.normalized()))
		if angle_diff > lash_angle / 2.0:
			continue
		if e.has_method("take_damage"):
			e.take_damage(total_dmg)
		var pull_vec = (global_position - e.global_position).normalized()
		e.velocity = pull_vec * 250.0 * scale_m
	var bullet_scene = preload("res://scenes/bullet.tscn")
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if bullets_container:
		var bullet = bullet_scene.instantiate()
		bullet.global_position = global_position
		bullet.direction = aim_dir
		bullet.is_player_bullet = true
		bullet.speed = equipment_manager.get_bullet_speed() * 0.5
		bullet.damage = int(base_dmg * 1.0)
		bullet.pierce_count = 3
		bullet.lifetime = 0.6
		bullet.behavior = bullet.BulletBehavior.BOOMERANG
		bullet._origin_entity = self
		bullets_container.add_child(bullet)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position + aim_dir * 16.0 * scale_m, lash_range * 0.5, Color(0.7, 0.5, 0.3, 0.5))
		vfx.shake(2.0, 0.12)
	var sfx_fl = get_node_or_null("/root/SFXManager")
	if sfx_fl:
		sfx_fl.play("swing", -2.0, 0.0)

func _throwing_fan_of_knives() -> void:
	stamina -= 15.0
	_stamina_regen_delay = 1.0
	stamina_changed.emit(stamina)
	_dash_cooldown = 1.0
	if _player_anim:
		_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK)
	var aim_dir = _get_shoot_direction()
	var bullet_scene = preload("res://scenes/bullet.tscn")
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	for i in range(5):
		var angle_offset = (i - 2) * 0.35
		var dir = aim_dir.rotated(angle_offset)
		var bullet = bullet_scene.instantiate()
		bullet.global_position = global_position
		bullet.direction = dir
		bullet.is_player_bullet = true
		bullet.speed = equipment_manager.get_bullet_speed() * (0.9 + randf() * 0.2)
		bullet.damage = int(equipment_manager.get_damage() * 0.8)
		bullet.lifetime = 0.6
		bullets_container.add_child(bullet)
	var sfx_fk = get_node_or_null("/root/SFXManager")
	if sfx_fk:
		sfx_fk.play("shoot_a", -3.0, 0.05)

func _short_bow_evasive_shot() -> void:
	stamina -= 15.0
	_stamina_regen_delay = 1.0
	stamina_changed.emit(stamina)
	_dash_cooldown = 0.8
	if _player_anim:
		_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK)
	var aim_dir = _get_shoot_direction()
	_dash_direction = -aim_dir
	_is_dashing = true
	_dash_timer = DASH_DURATION * 0.6
	_dash_hit_enemies.clear()
	invincible = true
	sprite.modulate.a = 0.6
	var bullet_scene = preload("res://scenes/bullet.tscn")
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if bullets_container:
		for i in range(3):
			var spread = (i - 1) * 0.1
			var dir = aim_dir.rotated(spread)
			var bullet = bullet_scene.instantiate()
			bullet.global_position = global_position
			bullet.direction = dir
			bullet.is_player_bullet = true
			bullet.speed = equipment_manager.get_bullet_speed() * 1.2
			bullet.damage = equipment_manager.get_damage()
			bullet.lifetime = 1.0
			bullets_container.add_child(bullet)
	var sfx_es = get_node_or_null("/root/SFXManager")
	if sfx_es:
		sfx_es.play("shoot_a", -4.0, 0.05)

func _greatsword_overhead_slam() -> void:
	stamina -= 30.0
	_stamina_regen_delay = 1.0
	stamina_changed.emit(stamina)
	_dash_cooldown = 1.5
	if _player_anim:
		_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK)
	var aim_dir = _get_shoot_direction()
	var base_dmg = equipment_manager.get_damage()
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_m = 4.0 if in_ow else 1.0
	var slam_range = 24.0 * scale_m
	var slam_angle = PI * 0.5
	var total_dmg = int(base_dmg * 3.5)
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var to_enemy = e.global_position - global_position
		if to_enemy.length() > slam_range:
			continue
		if abs(aim_dir.angle_to(to_enemy.normalized())) > slam_angle / 2.0:
			continue
		if e.has_method("take_damage"):
			e.take_damage(total_dmg)
		if e.has_method("apply_status"):
			e.apply_status("STUNNED", 0.5)
		e.velocity = to_enemy.normalized() * 200.0 * scale_m
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position + aim_dir * 12.0 * scale_m, slam_range * 0.7, Color(1.0, 0.6, 0.2, 0.6))
		vfx.shake(3.5, 0.2)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("area_effect_a", -2.0, 0.0)

func _great_axe_whirlwind_cleave() -> void:
	stamina -= 25.0
	_stamina_regen_delay = 1.0
	stamina_changed.emit(stamina)
	_dash_cooldown = 1.2
	if _player_anim:
		_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK)
	var base_dmg = equipment_manager.get_damage()
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_m = 4.0 if in_ow else 1.0
	var radius = 30.0 * scale_m
	var total_dmg = int(base_dmg * 2.5)
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var dist = e.global_position.distance_to(global_position)
		if dist > radius:
			continue
		if e.has_method("take_damage"):
			e.take_damage(total_dmg)
		var kb_dir = (e.global_position - global_position).normalized()
		e.velocity = kb_dir * 350.0 * scale_m
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position, radius, Color(0.8, 0.3, 0.2, 0.5))
		vfx.shake(3.0, 0.18)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("swing", -2.0, 0.0)

func _whip_lasso_pull() -> void:
	stamina -= 15.0
	_stamina_regen_delay = 1.0
	stamina_changed.emit(stamina)
	_dash_cooldown = 1.0
	if _player_anim:
		_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK)
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_m = 4.0 if in_ow else 1.0
	var pull_range = 48.0 * scale_m
	var nearest: Node2D = null
	var nearest_dist = pull_range
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var dist = e.global_position.distance_to(global_position)
		if dist < nearest_dist and dist > 4.0 * scale_m:
			nearest = e
			nearest_dist = dist
	if nearest:
		var pull_dir = (global_position - nearest.global_position).normalized()
		var target_pos = global_position - pull_dir * 8.0 * scale_m
		nearest.global_position = target_pos
		nearest.velocity = Vector2.ZERO
		if nearest.has_method("apply_status"):
			nearest.apply_status("STUNNED", 0.3)
		if nearest.has_method("take_damage"):
			nearest.take_damage(int(equipment_manager.get_damage() * 1.5))
		var vfx = get_node_or_null("/root/VFXManager")
		if vfx:
			vfx.hit_spark(nearest.global_position, Color(0.6, 0.4, 0.2))
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("swing", -3.0, 0.0)

func _scythe_reap() -> void:
	stamina -= 25.0
	_stamina_regen_delay = 1.0
	stamina_changed.emit(stamina)
	_dash_cooldown = 1.3
	if _player_anim:
		_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK)
	var aim_dir = _get_shoot_direction()
	var base_dmg = equipment_manager.get_damage()
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_m = 4.0 if in_ow else 1.0
	var reap_range = 28.0 * scale_m
	var reap_angle = PI
	var total_dmg = int(base_dmg * 2.5)
	var total_dealt = 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var to_enemy = e.global_position - global_position
		if to_enemy.length() > reap_range:
			continue
		if abs(aim_dir.angle_to(to_enemy.normalized())) > reap_angle / 2.0:
			continue
		if e.has_method("take_damage"):
			e.take_damage(total_dmg)
			total_dealt += total_dmg
	if total_dealt > 0:
		var heal_amount = maxi(1, int(total_dealt * 0.1))
		heal(heal_amount)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position + aim_dir * 10.0 * scale_m, reap_range * 0.6, Color(0.3, 0.8, 0.2, 0.5))
		vfx.shake(2.0, 0.12)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("swing", -2.0, 0.0)

func _claws_pounce() -> void:
	stamina -= 20.0
	_stamina_regen_delay = 1.0
	stamina_changed.emit(stamina)
	_dash_cooldown = 0.8
	if _player_anim:
		_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK)
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_m = 4.0 if in_ow else 1.0
	var pounce_range = 40.0 * scale_m
	var nearest: Node2D = null
	var nearest_dist = pounce_range
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var dist = e.global_position.distance_to(global_position)
		if dist < nearest_dist and dist > 4.0 * scale_m:
			nearest = e
			nearest_dist = dist
	if nearest:
		var to_enemy = (nearest.global_position - global_position).normalized()
		global_position = nearest.global_position - to_enemy * 6.0 * scale_m
		if nearest.has_method("take_damage"):
			nearest.take_damage(int(equipment_manager.get_damage() * 3.0))
		if nearest.has_method("apply_status"):
			nearest.apply_status("STUNNED", 0.3)
		var vfx = get_node_or_null("/root/VFXManager")
		if vfx:
			vfx.hit_spark(nearest.global_position, Color(1.0, 0.5, 0.2))
			vfx.shake(2.0, 0.1)
	else:
		var dir = _last_move_dir if _last_move_dir != Vector2.ZERO else _get_shoot_direction()
		_dash_direction = dir
		_is_dashing = true
		_dash_timer = DASH_DURATION * 0.8
		_dash_hit_enemies.clear()
		invincible = true
		sprite.modulate.a = 0.6
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("swing", -3.0, 0.05)
