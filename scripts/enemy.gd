extends CharacterBody2D

const PlayerQuery = preload("res://scripts/systems/player_query.gd")

enum State { IDLE, CHASE, ATTACK, COOLDOWN, CHARGING, DEAD, STEALTHED, INVESTIGATE }

# Coop: host owns AI; clients hold proxies driven by host snapshots.
# network_id is set by DungeonManager at spawn (derived from grid_pos + room index).
var network_id: int = 0
var _is_remote_proxy: bool = false
var _remote_target_pos: Vector2 = Vector2.ZERO
var _remote_has_state: bool = false

var definition: EnemyDefinition
var hp: int = 3
var shield_hp: int = 0
var armor: int = 0  # flat damage reduction
var speed: float = 20.0
var shoot_interval: float = 1.5
var state: State = State.IDLE
var attack_timer: float = 0.0
var cooldown_timer: float = 0.0
var charge_timer: float = 0.0
var charge_dir: Vector2 = Vector2.ZERO
var player: Node2D
var _trail_timer: float = 0.0
var _stealth_timer: float = 0.0
var _beam_timer: float = 0.0
var _beam_angle: float = 0.0
var _spiral_angle: float = 0.0
var _los_check_timer: float = 0.0
var _chase_timer: float = 0.0  # how long we've been chasing
var _hit_aggro_timer: float = 0.0  # prevents de-aggro for a few seconds after being hit
const CHASE_TIMEOUT = 8.0  # give up after this many seconds
var _wander_timer: float = 0.0  # time until next wander direction change
var _wander_dir: Vector2 = Vector2.ZERO  # current wander direction
var _stuck_timer: float = 0.0  # detect if stuck on wall
var _hold_timer: float = 0.0  # ranged enemies reposition after holding ground
var _last_pos: Vector2 = Vector2.ZERO
# Melee combat behavior
var _melee_dodge_timer: float = 0.0  # countdown to next side-dodge
var _melee_dodge_dir: float = 1.0  # +1 or -1 for strafe direction
var _melee_flank_timer: float = 0.0  # time spent circling before closing in
var _melee_lunge_cd: float = 0.0  # cooldown for dash-lunge attacks
# INVESTIGATE state
var _investigate_pos: Vector2 = Vector2.ZERO
var _investigate_timer: float = 0.0
var _investigate_look_timer: float = 0.0
var _investigate_dir: Vector2 = Vector2.ZERO  # direction to continue searching past investigate_pos
var _investigate_phase: int = 0  # 0=walk to pos, 1=continue in dir, 2=look around
# Last known player tracking (updated while chasing)
var _last_known_player_pos: Vector2 = Vector2.ZERO
var _last_known_player_dir: Vector2 = Vector2.ZERO
# Wrestling throw
var _thrown_timer: float = 0.0
var _thrown_velocity: Vector2 = Vector2.ZERO
var _thrower_dmg: int = 0
var _loy_sprite: Sprite2D  # separate sprite for LoY characters
var _enemy_anim: EnemyAnimator
# Nudge from dash knockback
var _nudge_timer: float = 0.0
var _nudge_velocity: Vector2 = Vector2.ZERO
# Awareness meter (gradual aggro)
var _awareness: float = 0.0  # 0.0–1.0: unaware → suspicious → alert
var _awareness_indicator: Label  # ? or ! above sprite
var _facing_dir: Vector2 = Vector2.RIGHT  # direction enemy is "looking" for vision cone
var _current_phase: int = 1
var _max_hp: int = 0
var _animator: SpriteAnimator
var _nav: RefCounted  # DungeonNav flow-field navigation (set by dungeon manager)
var _dm: Node  # DungeonManager ref for obstacle breaking (set by dungeon manager)

# Movement type state
var _spawn_pos: Vector2 = Vector2.ZERO  # position when first placed
var _orbit_angle: float = 0.0  # current angle for orbit movements
var _patrol_dir: float = 1.0  # +1 or -1 for patrol direction
var _patrol_offset: float = 0.0  # current offset from spawn
var _dash_state: int = 0  # 0=idle, 1=dashing in, 2=pausing, 3=dashing out
var _dash_timer: float = 0.0
var _dash_cd: float = 0.0

# Boss/Elite behavior vars
var _enraged: bool = false
var _slam_timer: float = 7.0  # boss ground slam cooldown
var _break_timer: float = 0.0  # obstacle breaking check timer
var _elite_taunt_done: bool = false  # elite aggro taunt animation
var _boss_shadow: Node2D  # pulsing shadow under boss
var _boss_name_label: Label  # name label above boss
var _boss_base_name: String = ""

# Random attack pool for elites/bosses
var _attack_pool: Array[int] = []  # random attack types assigned on setup
var _attack_pool_idx: int = 0  # cycles through pool
var _obs_attack_seq: int = 0
var _obs_current_attack_id: int = 0
var _obs_current_attack_name: String = ""
var _obs_stationary_time: float = 0.0
var _obs_last_stationary_report_msec: int = 0

# AttackSlot system: per-attack modifiers
var _active_modifier: AttackModifier  # set per-attack from slot, cleared after firing
var _slot_idx: int = 0  # cycles through definition.attack_slots

# Behavioral overhaul: Mummy bodyguard / Arch Mage shared vision
var _attached_ally: Node2D           # mummy bodyguard target
var _bodyguard_mode: bool = false    # following ally instead of player
var _shared_vision_has_los: bool = false  # cached: does any nearby ally see player?
var _shared_vision_checked: bool = false  # one-time shared vision performed?

# Boss HP bar
var _hp_bar_bg: ColorRect
var _hp_bar_fill: ColorRect

# Explicit boss-state machine
var _boss_state_index: int = -1
var _boss_state_elapsed: float = 0.0
var _boss_state_attack_timer: float = 0.0
var _boss_pending_trigger: String = ""
var _boss_spin_angle: float = 0.0
var _boss_sequence_index: int = -1
var _boss_sequence_elapsed: float = 0.0
var _boss_sequence_attack_timer: float = 0.0

# Boss HP regen
var _time_since_hit: float = 0.0
static var _hit_stop_active: bool = false
var _punch_tween: Tween = null
var _original_sprite_scale: Vector2 = Vector2.ZERO  # captured lazily on first hit
var _regen_accum: float = 0.0
var _is_boss_or_large: bool = false

var bullet_scene: PackedScene
var pickup_scene: PackedScene
var _contact_cooldown: float = 0.0  # prevents rapid contact damage ticks
var _knockback_timer: float = 0.0  # prevents movement override during knockback
var _weight: float = 1.0  # mass for collision momentum damage
var _contact_bounce: float = 0.0  # brief bounce-back after touching player
var _pushed_velocity: Vector2 = Vector2.ZERO  # external push (from player collisions)

@export var drop_table: DropTable

func _get_bullets_container() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("bullets")

func _obs_node() -> Node:
	if not is_inside_tree():
		return null
	var obs = get_node_or_null("/root/EnemyObservability")
	if obs and obs.has_method("is_enabled") and obs.is_enabled():
		return obs
	return null

func _obs_attack_name(atk: int) -> String:
	for key in EnemyDefinition.AttackType.keys():
		if int(EnemyDefinition.AttackType[key]) == atk:
			return str(key)
	return str(atk)

func _obs_state_name() -> String:
	for key in State.keys():
		if int(State[key]) == state:
			return str(key)
	return str(state)

func _obs_context(extra: Dictionary = {}) -> Dictionary:
	var ctx := {
		"attack_id": _obs_current_attack_id,
		"attack_type": _obs_current_attack_name,
		"phase": _current_phase,
		"state": _obs_state_name(),
		"major_enemy": _is_boss_or_large or (definition and definition.has_meta("generated_archetype_id")),
	}
	if has_meta("enemy_obs_context"):
		var spawn_ctx = get_meta("enemy_obs_context")
		if spawn_ctx is Dictionary:
			for key in spawn_ctx:
				ctx[key] = spawn_ctx[key]
	if has_meta("grid_pos"):
		ctx["room_grid"] = str(get_meta("grid_pos"))
	for key in extra:
		ctx[key] = extra[key]
	return ctx

func _obs_record_attack(atk: int, source: String) -> void:
	var obs = _obs_node()
	if obs == null or definition == null or not obs.has_method("record_enemy_attack"):
		return
	_obs_attack_seq += 1
	_obs_current_attack_id = _obs_attack_seq
	_obs_current_attack_name = _obs_attack_name(atk)
	var dist := -1.0
	if is_instance_valid(player):
		dist = global_position.distance_to(player.global_position)
	obs.record_enemy_attack(self, definition, atk, _obs_context({
		"source": source,
		"distance_to_player": dist,
		"cooldown": shoot_interval,
		"bullet_count": _get_active_bullet_count(),
		"bullet_speed": definition.bullet_speed if definition else 0.0,
		"attack_pool": _attack_pool.duplicate(),
	}))

func _obs_record_projectile(projectile: Node, extra: Dictionary = {}) -> void:
	var obs = _obs_node()
	if obs == null or definition == null or not obs.has_method("record_projectile_spawn"):
		return
	obs.record_projectile_spawn(self, definition, projectile, _obs_context(extra))

func _obs_record_suspicion(reason: String, extra: Dictionary = {}) -> void:
	var obs = _obs_node()
	if obs == null or definition == null or not obs.has_method("record_enemy_suspicion"):
		return
	obs.record_enemy_suspicion(self, definition, reason, _obs_context(extra))

func _obs_tick_runtime(delta: float, dist_to_player: float) -> void:
	if definition == null or state == State.DEAD:
		return
	var should_watch := _is_boss_or_large or definition.has_meta("generated_archetype_id")
	if not should_watch or state not in [State.CHASE, State.ATTACK, State.COOLDOWN]:
		_obs_stationary_time = 0.0
		return
	if dist_to_player > 180.0:
		_obs_stationary_time = 0.0
		return
	if velocity.length() <= 2.0:
		_obs_stationary_time += delta
	else:
		_obs_stationary_time = 0.0
	if _obs_stationary_time < 3.0:
		return
	var now := Time.get_ticks_msec()
	if now - _obs_last_stationary_report_msec < 3000:
		return
	_obs_last_stationary_report_msec = now
	_obs_record_suspicion("stationary_too_long", {
		"duration": _obs_stationary_time,
		"velocity": velocity.length(),
		"distance_to_player": dist_to_player,
		"attack_type": _obs_current_attack_name,
	})


func _ready() -> void:
	bullet_scene = preload("res://scenes/bullet.tscn")
	pickup_scene = preload("res://scenes/pickup.tscn")
	collision_layer = 2
	# walls (16) + player (1) + cliff walls (64)
	collision_mask = 1 | 16 | 64
	# Render above terrain height layers
	z_index = 5
	add_to_group("enemy")
	if is_inside_tree():
		player = get_tree().get_first_node_in_group("player")

func setup(def: EnemyDefinition) -> void:
	var dm = get_tree().get_first_node_in_group("dungeon_manager") if is_inside_tree() else null
	var spr = $Sprite2D
	definition = def
	_spawn_pos = global_position
	hp = def.max_hp
	_max_hp = def.max_hp
	shield_hp = def.shield_hp
	armor = def.armor
	speed = def.move_speed
	shoot_interval = def.attack_speed
	drop_table = def.drop_table

	if def.anim_data and def.anim_data.spritesheet_path != "":
		_enemy_anim = EnemyAnimator.new()
		add_child(_enemy_anim)
		_enemy_anim.setup($Sprite2D, def.anim_data)
		$Sprite2D.scale = Vector2(1, 1)
	elif def.use_loy_sprite and def.loy_tile_index >= 0:
		_setup_loy_sprite(def.loy_tile_index)
	else:
		$Sprite2D.frame = def.sprite_frame
		$Sprite2D.scale = Vector2(1, 1)  # native 8x8 sprites stay 8px (1 tile)

	$Sprite2D.modulate = def.sprite_color

	# Scale and weight for large/boss enemies
	# Only scale the sprite — scaling the whole node makes hitboxes huge in dungeons
	var loy_spr = get_node_or_null("LoYSprite")
	var size_mult = 1.0
	match def.size_class:
		EnemyDefinition.SizeClass.NORMAL:
			_weight = 1.0
		EnemyDefinition.SizeClass.LARGE:
			size_mult = 2.0
			_weight = 2.5
		EnemyDefinition.SizeClass.BOSS:
			size_mult = 3.0
			_weight = 5.0
	# Ranged/support enemies are lighter (easier to push) unless elite/boss
	if def.size_class == EnemyDefinition.SizeClass.NORMAL:
		var _at = def.attack_type
		var _melee_types = [
			EnemyDefinition.AttackType.MELEE, EnemyDefinition.AttackType.CHARGE,
			EnemyDefinition.AttackType.DASH, EnemyDefinition.AttackType.NONE,
			EnemyDefinition.AttackType.SWORD_SLASH, EnemyDefinition.AttackType.SHIELD_BASH,
			EnemyDefinition.AttackType.SLAM, EnemyDefinition.AttackType.STRAFE_RUN,
		]
		if _at not in _melee_types:
			_weight = 0.5  # ranged/support enemies are easy to push
	if size_mult > 1.0:
		if spr: spr.scale *= size_mult
		if loy_spr: loy_spr.scale *= size_mult

	# Enlarge hitboxes for overworld enemies (32px tiles, need bigger targets)
	if not dm:
		var hurtbox_shape = get_node_or_null("Hurtbox/CollisionShape2D")
		if hurtbox_shape and hurtbox_shape.shape is CircleShape2D:
			hurtbox_shape.shape = hurtbox_shape.shape.duplicate()
			hurtbox_shape.shape.radius *= 2.5
		var body_shape = get_node_or_null("CollisionShape2D")
		if body_shape and body_shape.shape is RectangleShape2D:
			body_shape.shape = body_shape.shape.duplicate()
			body_shape.shape.size *= 2.5

	# Ghost enemies phase through walls
	if def.ignores_terrain:
		$Sprite2D.modulate.a = 0.7
		collision_mask = 1  # ghosts phase through walls but collide with player

	# Boss/Large HP bar
	_is_boss_or_large = def.size_class >= EnemyDefinition.SizeClass.LARGE
	if _is_boss_or_large:
		_create_boss_hp_bar()

	# Boss: name label + pulsing shadow
	if def.size_class >= EnemyDefinition.SizeClass.BOSS:
		_create_boss_name_label(def.enemy_name)
		_create_boss_shadow()

	# Assign attack pool for elites/bosses unless they are running authored attack slots/states.
	# Generated elites can preload a curated pool through metadata.
	if _is_boss_or_large and def.attack_slots.size() == 0 and not _uses_boss_state_machine():
		_assign_random_attack_pool(def)

	# Auto-assign the new movement system for regular enemies.
	# Keep explicit authored test-arena movement resources intact.
	var _movement_path := def.resource_path
	var _is_test_movement_enemy := _movement_path.find("/resources/enemies/test/") != -1
	if not _is_test_movement_enemy and not _uses_boss_state_machine() and not _locks_generated_identity():
		_assign_random_movement(def)
	elif not def.movement_pattern and not _uses_boss_state_machine() and not _locks_generated_identity():
		_assign_random_movement(def)

	# Awareness indicator (? or !) above sprite
	_awareness_indicator = Label.new()
	_awareness_indicator.text = "?"
	_awareness_indicator.add_theme_font_size_override("font_size", 6)
	_awareness_indicator.add_theme_color_override("font_color", Color.YELLOW)
	_awareness_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_awareness_indicator.position = Vector2(-3, -14)
	_awareness_indicator.visible = false
	_awareness_indicator.z_index = 10
	add_child(_awareness_indicator)

	# Scale bullet speed by enemy level — low level = slower, high level = faster
	# Level 1-3: cap at 50, Level 4-8: cap at 70, Level 9-14: cap at 90, Level 15+: uncapped
	if def.bullet_speed > 0:
		var lvl = def.level
		var speed_cap := 999.0
		if lvl <= 3:
			speed_cap = 50.0
		elif lvl <= 8:
			speed_cap = 70.0
		elif lvl <= 14:
			speed_cap = 90.0
		# Add slight random variation (±10%)
		var variation = randf_range(0.9, 1.1)
		definition.bullet_speed = minf(def.bullet_speed * variation, speed_cap)

	state = State.IDLE
	if _uses_boss_state_machine():
		_enter_boss_state(0)

# Interesting attacks for random pool (excludes basic NONE/MELEE/RANGED/SPLIT/STEALTH/HEAL)
const ATTACK_POOL_CANDIDATES: Array = [
	EnemyDefinition.AttackType.BURST,
	EnemyDefinition.AttackType.SPIRAL,
	EnemyDefinition.AttackType.BEAM,
	EnemyDefinition.AttackType.VOLLEY,
	EnemyDefinition.AttackType.CROSS_SHOT,
	EnemyDefinition.AttackType.WAVE_SHOT,
	EnemyDefinition.AttackType.GATLING,
	EnemyDefinition.AttackType.MORTAR,
	EnemyDefinition.AttackType.NOVA,
	EnemyDefinition.AttackType.ZIGZAG,
	EnemyDefinition.AttackType.SHOTGUN_BLAST,
	EnemyDefinition.AttackType.HELIX,
	EnemyDefinition.AttackType.METEOR_SHOWER,
	EnemyDefinition.AttackType.BOOMERANG_SHOT,
	EnemyDefinition.AttackType.STRAFE_RUN,
	EnemyDefinition.AttackType.MINEFIELD,
	EnemyDefinition.AttackType.RETURNING_VOLLEY,
	EnemyDefinition.AttackType.SEEKING_MINES,
	EnemyDefinition.AttackType.DETONATOR,
	EnemyDefinition.AttackType.SPLITTER,
	EnemyDefinition.AttackType.SINE_BARRAGE,
	EnemyDefinition.AttackType.HOMING_SALVO,
	EnemyDefinition.AttackType.TELEGRAPH_EXPLOSION,
	EnemyDefinition.AttackType.ORBIT_LAUNCH,
	EnemyDefinition.AttackType.WALL_BOUNCE,
	EnemyDefinition.AttackType.LASER_GRID,
	EnemyDefinition.AttackType.GRAVITY_WELL,
	EnemyDefinition.AttackType.CHAIN_LIGHTNING,
	EnemyDefinition.AttackType.DEATH_SPIRAL,
	EnemyDefinition.AttackType.BOMB_TOSS,
	EnemyDefinition.AttackType.CARPET_BOMB,
	EnemyDefinition.AttackType.FIRE_RAIN,
	EnemyDefinition.AttackType.CLUSTER_BOMB,
	EnemyDefinition.AttackType.MINE_DROP,
	EnemyDefinition.AttackType.BARRIER_WALL,
	EnemyDefinition.AttackType.PULL_SHOT,
	EnemyDefinition.AttackType.PUSH_WAVE,
	# Original 5 melee attacks — tested and approved
	EnemyDefinition.AttackType.SWORD_SLASH,
	EnemyDefinition.AttackType.SPEAR_LUNGE,
	EnemyDefinition.AttackType.CHARGE_BULL,
	EnemyDefinition.AttackType.CLEAVE_COMBO,
	EnemyDefinition.AttackType.WHIRLWIND,
	# New 5 melee attacks — add here after testing in test arena
	#EnemyDefinition.AttackType.GROUND_POUND,
	#EnemyDefinition.AttackType.TAIL_WHIP,
	#EnemyDefinition.AttackType.SHIELD_BASH,
	#EnemyDefinition.AttackType.GRAB_THROW,
	#EnemyDefinition.AttackType.STOMP_WAVE,
]

## Melee-only pool for normal enemies' random secondary melee attack
const MELEE_ATTACK_POOL: Array = [
	EnemyDefinition.AttackType.SWORD_SLASH,
	EnemyDefinition.AttackType.SPEAR_LUNGE,
	EnemyDefinition.AttackType.CHARGE_BULL,
	EnemyDefinition.AttackType.CLEAVE_COMBO,
	EnemyDefinition.AttackType.WHIRLWIND,
	# New 5 — uncomment after testing
	#EnemyDefinition.AttackType.GROUND_POUND,
	#EnemyDefinition.AttackType.TAIL_WHIP,
	#EnemyDefinition.AttackType.SHIELD_BASH,
	#EnemyDefinition.AttackType.GRAB_THROW,
	#EnemyDefinition.AttackType.STOMP_WAVE,
]

## Movement pattern pools — preloaded for random assignment
## Aggressive: melee-oriented enemies that chase and engage
static var _MOVE_POOL_MELEE: Array = []
## Ranged: enemies that prefer distance
static var _MOVE_POOL_RANGED: Array = []
## Support: summoners, healers, defensive enemies
static var _MOVE_POOL_SUPPORT: Array = []
## Boss: larger, more dramatic movements
static var _MOVE_POOL_BOSS: Array = []
static var _move_pools_loaded: bool = false

static func _load_movement_pools() -> void:
	if _move_pools_loaded:
		return
	_move_pools_loaded = true
	# Old weighted presets (basic approach, weave, strafe, etc.)
	var _chase_direct = preload("res://resources/movements/chase_direct.tres")
	var _chase_weave = preload("res://resources/movements/chase_weave.tres")
	var _chase_aggressive = preload("res://resources/movements/chase_aggressive.tres")
	var _strafe_run = preload("res://resources/movements/strafe_run.tres")
	var _lunge_circle = preload("res://resources/movements/lunge_circle.tres")
	var _kite_ranged = preload("res://resources/movements/kite_ranged.tres")
	var _hold_ranged = preload("res://resources/movements/hold_ranged.tres")
	var _anchor_turret = preload("res://resources/movements/anchor_turret.tres")
	var _defensive_wall = preload("res://resources/movements/defensive_wall.tres")
	# New special presets
	var _zigzag = preload("res://resources/movements/zigzag.tres")
	var _dash_in_out = preload("res://resources/movements/dash_in_out.tres")
	var _swoop = preload("res://resources/movements/swoop.tres")
	var _intercept = preload("res://resources/movements/intercept.tres")
	var _elastic = preload("res://resources/movements/elastic.tres")
	var _bait_punish = preload("res://resources/movements/bait_punish.tres")
	var _orbit_player = preload("res://resources/movements/orbit_player.tres")
	var _kite = preload("res://resources/movements/kite.tres")
	var _patrol_h = preload("res://resources/movements/patrol_horizontal.tres")
	var _patrol_v = preload("res://resources/movements/patrol_vertical.tres")
	var _flee = preload("res://resources/movements/flee.tres")
	var _edge_skater = preload("res://resources/movements/edge_skater.tres")
	var _wall_bounce = preload("res://resources/movements/wall_bounce.tres")
	var _orbit_ally = preload("res://resources/movements/orbit_ally.tres")
	var _orbit_point = preload("res://resources/movements/orbit_point.tres")
	var _teleport = preload("res://resources/movements/teleport.tres")
	var _mirror = preload("res://resources/movements/mirror.tres")
	var _ambush = preload("res://resources/movements/ambush.tres")
	# Melee pool: basic approach-heavy + special aggressive
	_MOVE_POOL_MELEE = [
		_chase_direct, _chase_direct, _chase_direct,  # basic approach (common)
		_chase_weave, _chase_weave,                    # weaving approach
		_chase_aggressive,                             # fast aggressive
		_lunge_circle,                                 # lunge + circle
		_strafe_run,                                   # strafe while closing
		# Special types
		_zigzag, _dash_in_out, _swoop, _intercept, _elastic, _bait_punish,
	]
	# Ranged pool: basic hold/kite + special distance types
	_MOVE_POOL_RANGED = [
		_hold_ranged, _hold_ranged, _hold_ranged,     # hold position (common)
		_kite_ranged, _kite_ranged,                    # kite away when close
		_strafe_run,                                   # strafe while shooting
		# Special types
		_orbit_player, _kite, _patrol_h, _patrol_v, _flee,
		_edge_skater, _wall_bounce,
	]
	# Support pool: basic defensive + special utility
	_MOVE_POOL_SUPPORT = [
		_hold_ranged, _hold_ranged,                    # stay at range
		_kite_ranged,                                  # keep moving if pressured
		_strafe_run,                                   # reposition while supporting
		_kite_ranged,                                  # kite if pressured
		# Special types
		_orbit_ally, _teleport, _flee,
	]
	# Boss pool: no basic — always dramatic
	_MOVE_POOL_BOSS = [
		_chase_aggressive, _lunge_circle,              # weighted but aggressive
		_orbit_player, _intercept, _elastic, _swoop,
		_bait_punish, _kite, _edge_skater, _mirror,
	]

const _MELEE_ATTACK_TYPES: Array = [
	EnemyDefinition.AttackType.MELEE,
	EnemyDefinition.AttackType.CHARGE,
	EnemyDefinition.AttackType.DASH,
	EnemyDefinition.AttackType.SWORD_SLASH,
	EnemyDefinition.AttackType.SPEAR_LUNGE,
	EnemyDefinition.AttackType.CHARGE_BULL,
	EnemyDefinition.AttackType.CLEAVE_COMBO,
	EnemyDefinition.AttackType.WHIRLWIND,
	EnemyDefinition.AttackType.GROUND_POUND,
	EnemyDefinition.AttackType.TAIL_WHIP,
	EnemyDefinition.AttackType.SHIELD_BASH,
	EnemyDefinition.AttackType.GRAB_THROW,
	EnemyDefinition.AttackType.STOMP_WAVE,
	EnemyDefinition.AttackType.DASH_STRIKE,
	EnemyDefinition.AttackType.WHIP_LASH,
]

const _SUPPORT_ATTACK_TYPES: Array = [
	EnemyDefinition.AttackType.HEAL,
	EnemyDefinition.AttackType.SUMMON,
	EnemyDefinition.AttackType.SHIELD,
	EnemyDefinition.AttackType.BARRIER_WALL,
	EnemyDefinition.AttackType.PUSH_WAVE,
	EnemyDefinition.AttackType.PULL_SHOT,
	EnemyDefinition.AttackType.POISON_CLOUD,
]

func _assign_random_movement(def: EnemyDefinition) -> void:
	var is_boss = def.size_class >= EnemyDefinition.SizeClass.BOSS
	var is_elite = def.size_class == EnemyDefinition.SizeClass.LARGE
	# Normal: 80% default movement, 20% special
	# Elite: 50% default movement, 50% special
	# Boss/Hyper-elite: choose from the full global movement set equally
	var special_chance := 0.2
	if is_elite:
		special_chance = 0.5
	elif is_boss:
		special_chance = 1.0
	if randf() > special_chance:
		return  # keep default WEIGHTED (basic approach)
	_load_movement_pools()
	var pool: Array
	if is_boss:
		pool = []
		for candidate in _MOVE_POOL_MELEE + _MOVE_POOL_RANGED + _MOVE_POOL_SUPPORT + _MOVE_POOL_BOSS:
			if candidate not in pool:
				pool.append(candidate)
	elif def.attack_type in _MELEE_ATTACK_TYPES:
		pool = _MOVE_POOL_MELEE
	elif def.attack_type in _SUPPORT_ATTACK_TYPES:
		pool = _MOVE_POOL_SUPPORT
	else:
		pool = _MOVE_POOL_RANGED
	if pool.size() > 0:
		def.movement_pattern = pool[randi() % pool.size()]

func _assign_random_attack_pool(def: EnemyDefinition) -> void:
	if def != null and def.has_meta("generated_attack_pool"):
		var generated_pool = def.get_meta("generated_attack_pool")
		if generated_pool is Array and not generated_pool.is_empty():
			_attack_pool.clear()
			for attack_id in generated_pool:
				_attack_pool.append(int(attack_id))
			_attack_pool_idx = 0
			return
	var is_boss = def.size_class >= EnemyDefinition.SizeClass.BOSS
	var pool_size = 3 if is_boss else 2
	# Always include the enemy's native attack (if it's interesting)
	_attack_pool.clear()
	var native = def.attack_type
	if native in ATTACK_POOL_CANDIDATES:
		_attack_pool.append(native)
	# Also include phase attacks if they exist
	if def.phase_2_attack != EnemyDefinition.AttackType.NONE and def.phase_2_attack in ATTACK_POOL_CANDIDATES:
		if def.phase_2_attack not in _attack_pool:
			_attack_pool.append(def.phase_2_attack)
	if def.phase_3_attack != EnemyDefinition.AttackType.NONE and def.phase_3_attack in ATTACK_POOL_CANDIDATES:
		if def.phase_3_attack not in _attack_pool:
			_attack_pool.append(def.phase_3_attack)
	# Fill remaining slots with random picks
	var candidates = ATTACK_POOL_CANDIDATES.duplicate()
	candidates.shuffle()
	for c in candidates:
		if _attack_pool.size() >= pool_size:
			break
		if c not in _attack_pool:
			_attack_pool.append(c)
	_attack_pool.shuffle()
	_attack_pool_idx = 0

func _uses_boss_state_machine() -> bool:
	return definition != null and definition.boss_states.size() > 0

func _locks_generated_identity() -> bool:
	return definition != null and definition.has_meta("generated_identity_locked") and bool(definition.get_meta("generated_identity_locked"))

func _get_active_players() -> Array[Node2D]:
	if not is_inside_tree():
		return []
	return PlayerQuery.get_active_players(get_tree())

func _get_primary_player() -> Node2D:
	if not is_inside_tree():
		return null
	return PlayerQuery.get_primary_player(get_tree())

func _get_nearest_player(from_pos: Vector2 = global_position) -> Node2D:
	if not is_inside_tree():
		return null
	return PlayerQuery.get_nearest_player(get_tree(), from_pos)

func _get_current_boss_state() -> BossState:
	if not _uses_boss_state_machine():
		return null
	if _boss_state_index < 0 or _boss_state_index >= definition.boss_states.size():
		return null
	return definition.boss_states[_boss_state_index]

func _get_current_boss_sequence_step():
	var boss_state = _get_current_boss_state()
	if boss_state == null or boss_state.sequence_steps.is_empty():
		return null
	if _boss_sequence_index < 0 or _boss_sequence_index >= boss_state.sequence_steps.size():
		return null
	return boss_state.sequence_steps[_boss_sequence_index]

func _find_boss_state_index(state_id: String) -> int:
	if not _uses_boss_state_machine() or state_id == "":
		return -1
	for i in range(definition.boss_states.size()):
		var state = definition.boss_states[i] as BossState
		if state and state.state_id == state_id:
			return i
	return -1

func _enter_boss_state(index: int) -> void:
	if not _uses_boss_state_machine():
		return
	if index < 0 or index >= definition.boss_states.size():
		return
	_boss_state_index = index
	_boss_state_elapsed = 0.0
	_boss_state_attack_timer = 0.0
	_boss_sequence_index = 0
	_boss_sequence_elapsed = 0.0
	_boss_sequence_attack_timer = 0.0
	_boss_pending_trigger = ""
	_refresh_boss_name_label()

func trigger_boss_state(trigger_name: String) -> void:
	_boss_pending_trigger = trigger_name

func _next_pool_attack() -> int:
	if _attack_pool.is_empty():
		return EnemyDefinition.AttackType.BURST
	var atk = _attack_pool[_attack_pool_idx]
	_attack_pool_idx = (_attack_pool_idx + 1) % _attack_pool.size()
	return atk

func _peek_pool_attack() -> int:
	if _attack_pool.is_empty():
		return EnemyDefinition.AttackType.BURST
	return _attack_pool[_attack_pool_idx]

func _create_boss_hp_bar() -> void:
	var bar_w = 20.0  # fixed world pixels
	# Use a top-level Node2D to avoid inheriting enemy scale
	var bar_anchor = Node2D.new()
	bar_anchor.top_level = true  # ignores parent transform
	bar_anchor.z_index = 10
	add_child(bar_anchor)

	var bar_h = 2.0

	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = Color(0.15, 0.15, 0.15, 0.9)
	_hp_bar_bg.size = Vector2(bar_w, bar_h)
	_hp_bar_bg.position = Vector2(-bar_w / 2, 6)
	bar_anchor.add_child(_hp_bar_bg)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color = Color(0.1, 0.8, 0.15)
	_hp_bar_fill.size = Vector2(bar_w, bar_h)
	_hp_bar_fill.position = Vector2(-bar_w / 2, 6)
	bar_anchor.add_child(_hp_bar_fill)

func _update_boss_hp_bar() -> void:
	if _hp_bar_fill and _max_hp > 0:
		var ratio = clampf(float(hp) / float(_max_hp), 0.0, 1.0)
		var bar_w = 20.0
		_hp_bar_fill.size.x = bar_w * ratio
		# Green when healthy, red when low
		_hp_bar_fill.color = Color(0.1 + 0.8 * (1.0 - ratio), 0.8 * ratio, 0.1)
	# Keep bar following enemy position
	if _hp_bar_bg:
		_hp_bar_bg.get_parent().global_position = global_position

func _create_boss_name_label(boss_name: String) -> void:
	_boss_base_name = boss_name
	var container = Control.new()
	var anchor = Node2D.new()
	anchor.top_level = true
	anchor.z_index = 10
	add_child(anchor)
	# Render at font_size 16 (crisp) then scale container to 0.25 for sharp small text
	container.scale = Vector2(0.25, 0.25)
	anchor.add_child(container)
	_boss_name_label = Label.new()
	_boss_name_label.text = boss_name
	_boss_name_label.add_theme_font_size_override("font_size", 16)
	_boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_boss_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_boss_name_label.add_theme_constant_override("shadow_offset_x", 2)
	_boss_name_label.add_theme_constant_override("shadow_offset_y", 2)
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	# At font_size 16, ~9px per char; after 0.25 scale → ~2.25 world px per char
	var est_w = boss_name.length() * 9.0
	_boss_name_label.position = Vector2(-est_w / 2.0, -72)  # -72 * 0.25 = -18 world px above
	_boss_name_label.size = Vector2(est_w, 20)
	container.add_child(_boss_name_label)
	_refresh_boss_name_label()

func _refresh_boss_name_label() -> void:
	if _boss_name_label == null:
		return
	var text = _boss_base_name if _boss_base_name != "" else (definition.enemy_name if definition else "Boss")
	var boss_state = _get_current_boss_state()
	if boss_state and boss_state.display_name != "":
		text += " - " + boss_state.display_name
		var seq_step = _get_current_boss_sequence_step()
		if seq_step and seq_step.display_name != "" and seq_step.display_name != boss_state.display_name:
			text += " / " + seq_step.display_name
	_boss_name_label.text = text
	var est_w = text.length() * 9.0
	_boss_name_label.position = Vector2(-est_w / 2.0, -72)
	_boss_name_label.size = Vector2(est_w, 20)

func _create_boss_shadow() -> void:
	var _elapsed: float = 0.0
	var alpha: float = 0.4
	_boss_shadow = Node2D.new()
	_boss_shadow.z_index = -1
	add_child(_boss_shadow)
	# Draw a dark oval under boss
	var shadow_draw = _BossShadowDraw.new()
	_boss_shadow.add_child(shadow_draw)

class _BossShadowDraw extends Node2D:
	var _elapsed := 0.0
	func _process(delta: float) -> void:
		_elapsed += delta
		queue_redraw()
	func _draw() -> void:
		var alpha := clampf(0.3 + 0.1 * sin(_elapsed * 2.0), 0.1, 0.5)
		draw_circle(Vector2.ZERO, 10.0, Color(0.1, 0.0, 0.15, alpha))

func _setup_loy_sprite(tile_index: int) -> void:
	var atlas = AtlasTexture.new()
	var tex_path = LoySpriteIndex.get_char_texture_path(tile_index)
	var region = LoySpriteIndex.get_char_region(tile_index)
	var tex = load(tex_path) as Texture2D
	if not tex:
		return
	atlas.atlas = tex
	atlas.region = region
	$Sprite2D.texture = atlas
	# Reset hframes/vframes so the AtlasTexture isn't subdivided
	$Sprite2D.hframes = 1
	$Sprite2D.vframes = 1
	$Sprite2D.frame = 0
	# LoY sprites are 32x32, scale to 8px (1 tile, same as player)
	$Sprite2D.scale = Vector2(0.25, 0.25)

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	if state == State.DEAD:
		return
	# Coop client: skip all AI, just lerp toward host's broadcast position.
	# Damage / collision logic is gated to Phase 3 — proxy can still take visual hits later.
	if _is_remote_proxy:
		if _remote_has_state:
			global_position = global_position.lerp(_remote_target_pos, clampf(22.0 * delta, 0.0, 1.0))
		return
	var nearest_player = _get_nearest_player()
	if is_instance_valid(nearest_player):
		player = nearest_player
	if not is_instance_valid(player):
		return

	var to_player = player.global_position - global_position
	var dist = to_player.length()
	var player_vel: Vector2 = player.velocity if player is CharacterBody2D else Vector2.ZERO
	var t = Time.get_ticks_msec() / 1000.0
	var is_boss = definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS

	# Tick hit aggro timer (global, not just in chase)
	if _hit_aggro_timer > 0:
		_hit_aggro_timer -= delta

	# WHIRLWIND tick: bouncing spin — damage handled by _MeleeSpinBar child
	# Runs its own move_and_slide + bounce, then skips the state machine entirely.
	if has_meta("whirlwind_active") and get_meta("whirlwind_active"):
		var ww_time = get_meta("whirlwind_time") - delta
		set_meta("whirlwind_time", ww_time)
		# Use stored velocity (bouncing projectile style)
		velocity = get_meta("whirlwind_velocity")
		# Sprite spin fast
		$Sprite2D.rotation += delta * 30.0
		if ww_time <= 0:
			set_meta("whirlwind_active", false)
			$Sprite2D.rotation = 0
			velocity = Vector2.ZERO
			cooldown_timer = 0.5
			state = State.COOLDOWN
		else:
			# Move and bounce off walls
			move_and_slide()
			for i in range(get_slide_collision_count()):
				var col = get_slide_collision(i)
				if col:
					var n = col.get_normal()
					var ww_vel = get_meta("whirlwind_velocity") as Vector2
					var reflected = ww_vel.bounce(n)
					reflected = reflected.rotated(randf_range(-0.15, 0.15))
					set_meta("whirlwind_velocity", reflected.normalized() * 140.0)
					var sfx_b = get_node_or_null("/root/SFXManager")
					if sfx_b:
						sfx_b.play("impact_a", -8.0, 0.1)
					break
			_contact_cooldown -= delta
			if _contact_cooldown <= 0:
				_check_contact_damage()
		return  # Skip state machine — whirlwind controls movement

	# HP regen for LARGE/BOSS (after no damage for a delay)
	# LARGE (elites): 1% max HP per 2s after 4s no damage
	# BOSS: 1% max HP per 3s after 5s no damage (slower regen)
	_time_since_hit += delta
	if _is_boss_or_large and hp < _max_hp:
		var regen_delay = 5.0 if is_boss else 4.0
		var regen_interval = 3.0 if is_boss else 2.0
		if _time_since_hit > regen_delay:
			_regen_accum += delta
			if _regen_accum >= regen_interval:
				_regen_accum -= regen_interval
				hp = mini(hp + maxi(1, _max_hp / 100), _max_hp)
				_update_boss_hp_bar()

	# Keep HP bar following enemy
	if _hp_bar_bg:
		_hp_bar_bg.get_parent().global_position = global_position

	# Keep boss name label following
	if _boss_name_label:
		_boss_name_label.get_parent().global_position = global_position

	# Boss enrage at <30% HP
	if not _enraged and definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS:
		if hp < _max_hp * 0.3 and hp > 0:
			_enraged = true
			$Sprite2D.modulate = Color(1.5, 0.4, 0.4)
			var vfx_en = get_node_or_null("/root/VFXManager")
			if vfx_en:
				vfx_en.shockwave(global_position, 20.0, Color(1.0, 0.2, 0.1, 0.5))
				vfx_en.shake(2.0, 0.15)
			var sfx_en = get_node_or_null("/root/SFXManager")
			if sfx_en:
				sfx_en.play("special_b", -10.0, 0.08)

	# Boss ground slam (periodic AoE)
	if definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS and state == State.CHASE:
		_slam_timer -= delta
		if _slam_timer <= 0:
			_slam_timer = 5.0 if _enraged else 7.0
			_do_ground_slam()

	# Elite yellow glow pulse
	if definition and definition.size_class == EnemyDefinition.SizeClass.LARGE and not _enraged:
		var glow = Color(1.0 + 0.15 * sin(t * 3.0), 1.0 + 0.1 * sin(t * 3.0), 0.7)
		$Sprite2D.modulate = glow

	# Boss/Elite obstacle breaking — always active regardless of state
	# Break faster when stuck (velocity near zero while chasing)
	if _is_boss_or_large and _dm:
		var _stuck = state == State.CHASE and velocity.length() < speed * 0.2
		_break_timer -= delta
		if _break_timer <= 0:
			_break_timer = 0.1 if _stuck else 0.3  # break faster when stuck
			_break_nearby_obstacles()

	# Time Warp: slow enemy movement by 60%
	var _time_warp_mult = 1.0
	if is_instance_valid(player) and player.has_meta("time_warp_active") and player.get_meta("time_warp_active"):
		_time_warp_mult = 0.4

	var dir = to_player.normalized() if dist > 0 else Vector2.ZERO

	if _enemy_anim:
		_enemy_anim.set_direction(dir)
	else:
		if dir.x < 0:
			$Sprite2D.flip_h = true
		elif dir.x > 0:
			$Sprite2D.flip_h = false

	var aggro_range = 100.0
	if definition:
		aggro_range = definition.aggro_range if definition.aggro_range > 0 else 100.0
	# Player stealth now handled via awareness ramp rate (stealth_factor)

	# Leash check: overworld enemies must stay near their spawn zone
	# Skip leash if recently hit — let them chase for a bit
	if has_meta("spawn_pos") and has_meta("leash_radius") and _hit_aggro_timer <= 0:
		var _sp = get_meta("spawn_pos") as Vector2
		var _lr = get_meta("leash_radius") as float
		if _lr > 0 and global_position.distance_to(_sp) > _lr + 200:
			# Too far from spawn — return home via investigate to spawn
			_investigate_pos = _sp
			_investigate_dir = Vector2.ZERO
			_investigate_phase = 0
			_investigate_timer = 0.0
			state = State.INVESTIGATE
			_chase_timer = 0.0
			global_position = global_position.move_toward(_sp, speed * delta * 2)
			move_and_slide()
			return

	# Knockback separation: skip movement AI during knockback to prevent sticking
	if _knockback_timer > 0:
		_knockback_timer -= delta
		move_and_slide()
		_contact_cooldown -= delta
		return

	# Contact bounce: skip movement AI during bounce-back but still check damage
	# EXCEPTION: don't interrupt CHARGING state (lunges must complete)
	if _contact_bounce > 0 and state != State.CHARGING:
		_contact_bounce -= delta
		velocity += _pushed_velocity
		_pushed_velocity *= 0.85  # exponential decay — gone in ~0.3s at 60fps
		move_and_slide()
		_contact_cooldown -= delta
		if _contact_cooldown <= 0:
			_check_contact_damage()
		return

	# Passive-until-hit: don't aggro until damaged
	var is_passive = has_meta("passive_until_hit") and get_meta("passive_until_hit")
	var should_wander = has_meta("behavior") and get_meta("behavior") == "wander"

	match state:
		State.IDLE:
			_chase_timer = 0.0
			# Wander behavior: move randomly within leash radius
			if should_wander or is_passive:
				_wander_timer -= delta
				if _wander_timer <= 0:
					_wander_timer = 1.5 + randf() * 2.5
					if randf() < 0.7:  # 70% chance to pick a direction, 30% stand still
						_wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
					else:
						_wander_dir = Vector2.ZERO
				velocity = _wander_dir * speed * 0.6
				if _wander_dir.length() > 0.1:
					_facing_dir = _wander_dir.normalized()
				if _enemy_anim:
					_enemy_anim.set_direction(_wander_dir)
				elif _wander_dir.x < 0:
					$Sprite2D.flip_h = true
				elif _wander_dir.x > 0:
					$Sprite2D.flip_h = false
			else:
				velocity = Vector2.ZERO
			# Ambush enemies: skip awareness system, go straight to chase
			var _is_ambush_mt = definition and definition.movement_pattern and definition.movement_pattern.move_type == MovementPattern.MoveType.AMBUSH
			if _is_ambush_mt and dist < aggro_range:
				_awareness = 1.0
				state = State.CHASE
			# Awareness ramp/decay (skip if passive)
			if not is_passive and not _is_ambush_mt:
				# LOS check is expensive — do it periodically, cache result
				var _player_sneaking = is_instance_valid(player) and player.has_method("is_sneaking") and player.is_sneaking()
				# Sneaking halves effective detection range
				var eff_aggro_range = aggro_range * 0.4 if _player_sneaking else aggro_range
				_los_check_timer -= delta
				if _los_check_timer <= 0:
					_los_check_timer = 0.3 + randf() * 0.2
					var has_los = _has_line_of_sight_or_shared()
					var can_see = has_los and dist < eff_aggro_range
					if not can_see and _is_boss_or_large and dist < eff_aggro_range * 0.3:
						can_see = true
					set_meta("_cached_can_see", can_see)
				# Ramp/decay awareness every frame using cached LOS result
				var can_see_cached = get_meta("_cached_can_see", false) as bool
				if can_see_cached:
					var dist_factor = 1.0 - clampf(dist / eff_aggro_range, 0.0, 0.8)
					var stealth_stat = 0.0
					if is_instance_valid(player) and player.get_node_or_null("EquipmentManager"):
						stealth_stat = player.equipment_manager.get_stealth()
					# stealth_stat is 0-1 (0.15 = 15%). At 1.0 (full stealth gear)
					# awareness ramp is halved; partial stealth scales between.
					var stealth_factor = 1.0 / (1.0 + stealth_stat)
					# Sneak: 0.1x awareness ramp (very slow detection)
					var sneak_factor = 0.1 if _player_sneaking else 1.0
					# Vision cone: detection depends on angle between facing and player
					var vision_factor = 1.0
					if _facing_dir.length() > 0.1 and dir.length() > 0.1:
						var facing_dot = _facing_dir.dot(dir)
						if facing_dot > 0.5:  # front cone (~60deg)
							vision_factor = 1.0
						elif facing_dot > -0.25:  # side (~105deg)
							vision_factor = 0.3
						else:  # behind
							vision_factor = 0.05
					_awareness = minf(_awareness + 3.0 * dist_factor * stealth_factor * sneak_factor * vision_factor * delta, 1.0)
				else:
					_awareness = maxf(_awareness - 0.4 * delta, 0.0)
				_update_awareness_indicator()
				# Threshold transitions
				if _awareness >= 0.7:
					_on_awareness_alert()
				elif _awareness >= 0.3 and state == State.IDLE:
					# Suspicious → investigate toward player
					if is_instance_valid(player):
						_investigate_pos = player.global_position
						_investigate_dir = Vector2.ZERO
						_investigate_phase = 0
						_investigate_timer = 0.0
						_investigate_look_timer = 0.0
						state = State.INVESTIGATE
		State.CHASE:
			_chase_timer += delta
			if dir.length() > 0.1: _facing_dir = dir
			# Track player's position and movement direction while chasing
			if is_instance_valid(player):
				if player_vel.length() > 5.0:
					_last_known_player_dir = player_vel.normalized()
				_last_known_player_pos = player.global_position
			var chase_limit = CHASE_TIMEOUT
			if _dm:
				chase_limit = 30.0  # dungeon enemies chase much longer
			if _is_boss_or_large:
				chase_limit = 999.0  # bosses/elites never give up
			if _chase_timer > chase_limit:
				_begin_search()
			else:
				_do_chase(dir, dist, delta)
		State.ATTACK:
			_do_attack(dir)
			if _has_continuous_movement():
				_apply_movement_pattern(definition.movement_pattern, dir, dist, delta)
		State.COOLDOWN:
			cooldown_timer -= delta
			var pref = definition.preferred_distance if definition else 0.0
			if _has_continuous_movement():
				_apply_movement_pattern(definition.movement_pattern, dir, dist, delta)
			else:
				if pref > 0:
					# Ranged enemy — hold position during cooldown
					velocity = Vector2.ZERO
				else:
					# Melee enemy — keep advancing during cooldown
					if dist > 20.0:
						velocity = dir * speed * 0.4
					else:
						velocity = Vector2.ZERO
			if cooldown_timer <= 0:
				state = State.CHASE
		State.CHARGING:
			charge_timer -= delta
			var _is_bull = has_meta("bull_charge") and get_meta("bull_charge")
			var charge_spd = (definition.charge_speed if definition else 80.0)
			if _is_bull:
				charge_spd = 100.0  # slow heavy charge
			velocity = charge_dir * charge_spd
			# Damage on contact during ANY charge/lunge
			if is_instance_valid(player):
				var _charge_hit_key = "_charge_dmg_dealt"
				var _already_hit = has_meta(_charge_hit_key) and get_meta(_charge_hit_key)
				var _charge_range = 10.0 * scale.x
				if _is_bull:
					_charge_range = 20.0
				if not _already_hit and global_position.distance_to(player.global_position) < _charge_range:
					if not ("_is_dashing" in player and player._is_dashing):
						if player.has_method("take_damage"):
							var charge_mult = 2.0 if _is_bull else 1.5
							var bdmg = int((definition.attack_damage if definition else 2) * charge_mult)
							player.take_damage(maxi(bdmg, 1), global_position, true, false)
						# Push player in charge direction
						var push_str = 150.0 if _is_bull else 80.0
						if player.has_method("apply_push"):
							player.apply_push(charge_dir * push_str)
						else:
							player.velocity += charge_dir * push_str
						set_meta(_charge_hit_key, true)
						var sfx_ch = get_node_or_null("/root/SFXManager")
						if sfx_ch:
							sfx_ch.play("impact_b", -5.0, 0.1)
						if _is_bull:
							var vfx_b = get_node_or_null("/root/VFXManager")
							if vfx_b:
								vfx_b.shockwave(player.global_position, 16.0, Color(1.0, 0.2, 0.1, 0.7))
								vfx_b.shake(4.0, 0.2)
			# CHARGE_BULL: wall collision stun — check slide collisions
			if _is_bull and get_slide_collision_count() > 0:
				charge_timer = 0
				set_meta("bull_charge", false)
				set_meta("stunned", true)
				cooldown_timer = 1.5
				state = State.COOLDOWN
				velocity = Vector2.ZERO
				var vfx_w = get_node_or_null("/root/VFXManager")
				if vfx_w:
					vfx_w.shake(5.0, 0.25)
				var sfx_w = get_node_or_null("/root/SFXManager")
				if sfx_w:
					sfx_w.play("impact_b", -3.0, 0.1)
				get_tree().create_timer(1.5).timeout.connect(
					func():
						if is_instance_valid(self):
							set_meta("stunned", false)
				)
			if charge_timer <= 0:
				velocity = Vector2.ZERO
				cooldown_timer = shoot_interval
				state = State.COOLDOWN
				set_meta("_charge_dmg_dealt", false)
				if _is_bull:
					set_meta("bull_charge", false)
		State.STEALTHED:
			_stealth_timer -= delta
			velocity = dir * speed * 0.5
			if _stealth_timer <= 0:
				$Sprite2D.modulate.a = 1.0
				# Backstab: if close enough, deal 25% max HP from behind
				if player and is_instance_valid(player) and global_position.distance_to(player.global_position) < 30.0:
					if player.has_method("take_damage"):
						var dmg = maxi(1, int(player.max_hp * 0.25))
						player.take_damage(dmg, global_position, false, true)
				state = State.ATTACK
				var sfx_bs = get_node_or_null("/root/SFXManager")
				if sfx_bs:
					sfx_bs.play("attack_a", -10.0, 0.12)

		State.INVESTIGATE:
			_investigate_timer += delta
			# Slow awareness decay while investigating
			_awareness = maxf(_awareness - 0.15 * delta, 0.0)
			_update_awareness_indicator()
			match _investigate_phase:
				0:  # Phase 0: walk to last known position
					var to_inv = _investigate_pos - global_position
					var inv_dist = to_inv.length()
					if inv_dist > 6.0 and _investigate_timer < 5.0:
						velocity = to_inv.normalized() * speed * 0.8
						if to_inv.x < 0:
							$Sprite2D.flip_h = true
						elif to_inv.x > 0:
							$Sprite2D.flip_h = false
					else:
						# Arrived at last known pos — continue in player's direction if known
						if _investigate_dir.length() > 0.1:
							_investigate_phase = 1
							_investigate_timer = 0.0
							_investigate_pos = global_position + _investigate_dir * 30.0  # search ~4 tiles ahead
						else:
							_investigate_phase = 2
							_investigate_timer = 0.0
				1:  # Phase 1: continue in player's last movement direction
					var to_fwd = _investigate_pos - global_position
					var fwd_dist = to_fwd.length()
					if fwd_dist > 6.0 and _investigate_timer < 3.0:
						velocity = to_fwd.normalized() * speed * 0.6
						if to_fwd.x < 0:
							$Sprite2D.flip_h = true
						elif to_fwd.x > 0:
							$Sprite2D.flip_h = false
					else:
						_investigate_phase = 2
						_investigate_timer = 0.0
				2:  # Phase 2: look around at final position
					velocity = Vector2.ZERO
					_investigate_look_timer -= delta
					if _investigate_look_timer <= 0:
						_investigate_look_timer = 0.8
						$Sprite2D.flip_h = randf() > 0.5
					if _investigate_timer > 3.0:
						state = State.IDLE
						_awareness = maxf(_awareness - 0.3, 0.0)
						_update_awareness_indicator()
						_investigate_timer = 0.0
						_investigate_phase = 0
			# If player spotted during any investigation phase → CHASE
			var _inv_player_sneaking = is_instance_valid(player) and player.has_method("is_sneaking") and player.is_sneaking()
			var _inv_eff_range = aggro_range * 0.4 if _inv_player_sneaking else aggro_range
			if not is_passive and dist < _inv_eff_range and _has_line_of_sight_or_shared():
				state = State.CHASE
				_chase_timer = 0.0
				_investigate_phase = 0

	# Thrown by wrestler — override movement
	if _thrown_timer > 0:
		_thrown_timer -= delta
		velocity = _thrown_velocity
		move_and_slide()
		# Check wall collision
		if get_slide_collision_count() > 0:
			if _thrower_dmg > 0:
				take_damage(maxi(1, _thrower_dmg / 4), false)
			_thrown_timer = 0.0
			_thrown_velocity = Vector2.ZERO
			var vfx_t = get_node_or_null("/root/VFXManager")
			if vfx_t:
				vfx_t.hit_spark(global_position)
			var sfx_t = get_node_or_null("/root/SFXManager")
			if sfx_t:
				sfx_t.play("impact_a", -10.0)
		# Check enemy-enemy collision
		for e in get_tree().get_nodes_in_group("enemy"):
			if e == self or not is_instance_valid(e) or e.state == State.DEAD:
				continue
			if global_position.distance_to(e.global_position) < 8.0:
				var col_dmg = maxi(1, _thrower_dmg / 2)
				take_damage(col_dmg, false)
				e.take_damage(col_dmg, false)
				_thrown_timer = 0.0
				_thrown_velocity = Vector2.ZERO
				var vfx_c = get_node_or_null("/root/VFXManager")
				if vfx_c:
					vfx_c.hit_spark(global_position)
				break
		if _thrown_timer <= 0:
			_thrown_velocity = Vector2.ZERO
			_check_hazard_at_position()
		return  # skip normal move_and_slide during throw

	# Nudge from dash knockback
	if _nudge_timer > 0:
		_nudge_timer -= delta
		velocity = _nudge_velocity
		move_and_slide()
		if _nudge_timer <= 0:
			_nudge_velocity = Vector2.ZERO
			_check_hazard_at_position()
		return

	# Beam sweep
	if _beam_timer > 0:
		_beam_timer -= delta
		_beam_angle += (definition.beam_sweep_speed if definition else 1.5) * delta
		_shoot_single(Vector2.RIGHT.rotated(_beam_angle))

	# Apply external push (from player collision) — capped to prevent runaway accumulation
	var max_push := 300.0
	if _pushed_velocity.length_squared() > max_push * max_push:
		_pushed_velocity = _pushed_velocity.normalized() * max_push
	velocity += _pushed_velocity
	_pushed_velocity *= 0.85  # exponential decay — gone in ~0.3s at 60fps

	# Enemy-enemy soft separation (prevents stacking/clumping)
	_apply_separation(delta)

	_maybe_leave_trail(delta)
	if has_meta("_wall_bounce_handled"):
		remove_meta("_wall_bounce_handled")
	else:
		move_and_slide()

	# Post-move charge hit: if CHARGING and slide-collided with player, deal damage
	if state == State.CHARGING and is_instance_valid(player):
		var _chk = "_charge_dmg_dealt"
		if not (has_meta(_chk) and get_meta(_chk)):
			for si in range(get_slide_collision_count()):
				var col = get_slide_collision(si)
				if col.get_collider() == player:
					if not ("_is_dashing" in player and player._is_dashing):
						var _is_bull_c = has_meta("bull_charge") and get_meta("bull_charge")
						var charge_mult_c = 2.0 if _is_bull_c else 1.5
						var bdmg_c = int((definition.attack_damage if definition else 2) * charge_mult_c)
						if player.has_method("take_damage"):
							player.take_damage(maxi(bdmg_c, 1), global_position, true, false)
						var push_str_c = 150.0 if _is_bull_c else 80.0
						if player.has_method("apply_push"):
							player.apply_push(charge_dir * push_str_c)
						else:
							player.velocity += charge_dir * push_str_c
						set_meta(_chk, true)
						var sfx_chc = get_node_or_null("/root/SFXManager")
						if sfx_chc:
							sfx_chc.play("impact_b", -5.0, 0.1)
						var vfx_chc = get_node_or_null("/root/VFXManager")
						if vfx_chc:
							vfx_chc.hit_spark(player.global_position)
					break

	# Bounce-back on player contact to prevent sticking
	# Skip during CHARGING (lunges must reach target) and KNOCKBACK
	if _contact_bounce <= 0 and state != State.CHARGING and _knockback_timer <= 0:
		for si in range(get_slide_collision_count()):
			var col = get_slide_collision(si)
			if col.get_collider() == player:
				# Use center-to-center direction (away from player) — not slide normal
				var bounce_dir: Vector2 = (global_position - player.global_position).normalized()
				if bounce_dir == Vector2.ZERO:
					bounce_dir = Vector2.RIGHT.rotated(randf() * TAU)
				# Gentle baseline bounce; stronger only when player is dashing/sprinting
				var bounce_str := 0.5
				var bounce_time := 0.15
				if is_instance_valid(player):
					if "_is_dashing" in player and player._is_dashing:
						bounce_str = 2.5
						bounce_time = 0.3
					elif "_is_sprinting" in player and player._is_sprinting:
						bounce_str = 1.2
						bounce_time = 0.2
				velocity = bounce_dir * speed * bounce_str
				_pushed_velocity = bounce_dir * speed * bounce_str * 0.3
				_contact_bounce = bounce_time
				# Trigger contact damage immediately on physical collision
				if _contact_cooldown <= 0:
					_check_contact_damage(true)
				break

	# Update enemy animation state
	if _enemy_anim:
		if velocity.length_squared() > 4.0:
			_enemy_anim.set_state(EnemyAnimator.AnimState.WALK)
		else:
			_enemy_anim.set_state(EnemyAnimator.AnimState.IDLE)

	# (Whirlwind bounce is handled in the early-return block above)
	_obs_tick_runtime(delta, dist)

	# Time Warp velocity reduction
	if _time_warp_mult < 1.0:
		velocity *= _time_warp_mult

	# Contact damage — slide collision (reliable) + distance fallback
	_contact_cooldown -= delta
	if _contact_cooldown <= 0:
		var _slide_touched := false
		for _si_cd in range(get_slide_collision_count()):
			if get_slide_collision(_si_cd).get_collider() == player:
				_slide_touched = true
				break
		if _slide_touched:
			_check_contact_damage(true)  # force — we physically touched
		else:
			_check_contact_damage(false)  # distance check

func _move_intercept(dir: Vector2, dist: float, p: MovementPattern, spd: float, delta: float) -> void:
	var perp = Vector2(-dir.y, dir.x)
	var player_vel: Vector2 = player.velocity if is_instance_valid(player) and player is CharacterBody2D else Vector2.ZERO
	var to_target = Vector2.ZERO
	if not has_meta("ic_state"):
		set_meta("ic_state", 0)  # 0=tracking, 1=committed
		set_meta("ic_timer", 0.0)
		set_meta("ic_target", Vector2.ZERO)
	var ic_state: int = get_meta("ic_state")
	var ic_timer: float = float(get_meta("ic_timer"))
	if ic_state == 0:
		# Tracking — orbit at distance, wait for opening
		velocity = (perp * 0.8 + dir * 0.2).normalized() * spd * 0.5
		ic_timer += delta
		set_meta("ic_timer", ic_timer)
		if ic_timer >= 1.0 and is_instance_valid(player):
			# Commit! Predict player position FAR ahead
			var predict_pos = player.global_position + player_vel * p.intercept_predict_time
			set_meta("ic_target", predict_pos)
			set_meta("ic_state", 1)
			set_meta("ic_timer", p.intercept_commit_time)
	else:
		# Committed — ROCKET to intercept point, no course correction, immune to pushback
		ic_timer -= delta
		set_meta("ic_timer", ic_timer)
		if to_target.length() > 5.0 and ic_timer > 0:
			velocity = to_target.normalized() * spd * 5.0
		else:
			# Overshoot or arrived — brief pause then reset
			set_meta("ic_state", 0)
			set_meta("ic_timer", 0.0)
			velocity = Vector2.ZERO

## Elastic: spring-tethered to spawn with real tension, acceleration, and bounce rebound
func _move_elastic(dir: Vector2, p: MovementPattern, spd: float, delta: float) -> void:
	var bounces: int = 0
	var to_spawn: Vector2 = _spawn_pos - global_position
	if not has_meta("el_state"):
		set_meta("el_state", 0)  # 0=stretching out, 1=snapping back, 2=rebounding past spawn
		set_meta("el_vel", Vector2.ZERO)
		set_meta("el_bounces", 0)
	var el_state: int = get_meta("el_state")
	var el_vel: Vector2 = get_meta("el_vel")
	var anchor_dist = to_spawn.length()
	var to_spawn_dir = to_spawn.normalized() if anchor_dist > 1.0 else Vector2.ZERO
	match el_state:
		0:  # Stretching out toward player — spring tension builds
			var tension = clampf(anchor_dist / p.elastic_max_stretch, 0.0, 1.0)
			# Accelerate toward player but tension pulls back progressively
			var accel = dir * spd * 3.0 * (1.0 - tension * 0.9)
			# Spring pull back toward anchor
			var spring_pull = to_spawn_dir * tension * spd * 4.0
			el_vel = (el_vel + (accel + spring_pull) * delta).limit_length(spd * 2.0)
			velocity = el_vel
			set_meta("el_vel", el_vel)
			if anchor_dist >= p.elastic_max_stretch:
				# SNAP! Convert all distance into recoil energy
				set_meta("el_state", 1)
				set_meta("el_vel", to_spawn_dir * p.elastic_whip_speed)
				set_meta("el_bounces", 0)
		1:  # Snapping back toward spawn — accelerating, unstoppable
			# Spring acceleration toward anchor
			el_vel += to_spawn_dir * p.elastic_whip_speed * 3.0 * delta
			el_vel = el_vel.limit_length(p.elastic_whip_speed)
			velocity = el_vel
			set_meta("el_vel", el_vel)
			if anchor_dist < 10.0:
				# Passed through spawn — rebound out the other side
				set_meta("el_state", 2)
				# Keep velocity but dampen for bounce
				set_meta("el_vel", el_vel * 0.6)
				set_meta("el_bounces", get_meta("el_bounces") + 1)
		2:  # Rebounding past spawn — oscillating bounce
			# Spring pulls back toward anchor
			el_vel += to_spawn_dir * spd * 6.0 * delta
			# Damping
			el_vel *= (1.0 - 1.5 * delta)
			velocity = el_vel
			set_meta("el_vel", el_vel)
			if anchor_dist < 10.0 and el_vel.length() < spd * 0.3:
				# Settled — restart stretch cycle
				set_meta("el_state", 0)
				set_meta("el_vel", Vector2.ZERO)
			elif anchor_dist < 10.0 and bounces < 3:
				# Another bounce through
				set_meta("el_state", 1)
				set_meta("el_vel", el_vel * 0.5)
				set_meta("el_bounces", bounces + 1)

## Edge Skater: rides along walls, flowing around perimeter
func _move_edge_skater(p: MovementPattern, spd: float, delta: float) -> void:
	if not has_meta("es_dir"):
		# Start moving in a random cardinal direction
		var dirs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
		set_meta("es_dir", dirs[randi() % 4])
		set_meta("es_wall_timer", 0.0)
	var es_dir: Vector2 = get_meta("es_dir")
	var es_speed = spd * p.edge_skate_speed
	# Move along current direction
	velocity = es_dir * es_speed
	# Use move_and_slide collision to detect walls
	move_and_slide()
	if get_slide_collision_count() > 0:
		# Hit a wall — turn 90 degrees (clockwise)
		var col = get_slide_collision(0)
		var normal = col.get_normal()
		# Slide along the wall: turn perpendicular to normal
		es_dir = Vector2(-normal.y, normal.x)  # 90 degrees CW
		set_meta("es_dir", es_dir)
		velocity = es_dir * es_speed
	# Also check if we're drifting away from walls — steer back toward nearest wall
	set_meta("es_wall_timer", float(get_meta("es_wall_timer")) + delta)
	if float(get_meta("es_wall_timer")) > 2.0 and get_slide_collision_count() == 0:
		# Haven't hit a wall in 2s — veer toward spawn (room center has walls around it)
		var to_wall = (_spawn_pos - global_position)
		if to_wall.length() > 60.0:
			# We're far from center, probably near walls already — try perpendicular
			velocity = Vector2(-es_dir.y, es_dir.x) * es_speed * 0.5 + es_dir * es_speed * 0.5
	set_meta("_wall_bounce_handled", true)  # skip double move_and_slide

## Bait & Punish: retreat to bait, then flip into punish charge
func _move_bait_punish(dir: Vector2, dist: float, p: MovementPattern, spd: float, delta: float) -> void:
	if not has_meta("bp_state"):
		set_meta("bp_state", 0)  # 0=bait (flee), 1=watching, 2=punish
		set_meta("bp_timer", 0.0)
		set_meta("bp_prev_dist", dist)
	var bp_state: int = get_meta("bp_state")
	var bp_timer: float = float(get_meta("bp_timer"))
	match bp_state:
		0:  # Bait — flee away from player
			velocity = _steer_around_walls(-dir) * spd * 1.2
			bp_timer += delta
			set_meta("bp_timer", bp_timer)
			if bp_timer >= p.bait_flee_time:
				set_meta("bp_state", 1)
				set_meta("bp_timer", 0.0)
				set_meta("bp_prev_dist", dist)
		1:  # Watching — check if player is chasing (distance decreasing)
			velocity = Vector2.ZERO  # pause briefly
			bp_timer += delta
			set_meta("bp_timer", bp_timer)
			var prev_d: float = float(get_meta("bp_prev_dist"))
			if dist < prev_d - 5.0 or bp_timer > 0.5:
				# Player is pursuing or timeout — PUNISH
				set_meta("bp_state", 2)
				set_meta("bp_timer", 1.0)
			elif bp_timer > 1.0:
				# Player didn't chase — go back to bait
				set_meta("bp_state", 0)
				set_meta("bp_timer", 0.0)
		2:  # Punish — charge at player at high speed
			velocity = _steer_around_walls(dir) * p.punish_speed
			bp_timer -= delta
			set_meta("bp_timer", bp_timer)
			if bp_timer <= 0 or dist < 10.0:
				set_meta("bp_state", 0)
				set_meta("bp_timer", 0.0)

## Ambush: permanently invisible, hides near walls, repositions when hit
func _move_ambush(dir: Vector2, dist: float, p: MovementPattern, spd: float, delta: float) -> void:
	var spr = $Sprite2D
	# Permanently semi-invisible
	if not has_meta("amb_init"):
		set_meta("amb_init", true)
		set_meta("amb_state", 0)  # 0=hiding, 1=engaging
		if spr:
			spr.modulate.a = 0.08  # nearly invisible
	var amb_state: int = get_meta("amb_state")
	if amb_state == 0:
		# Hiding — creep slowly toward player but stay very faint
		if spr and spr.modulate.a > 0.08:
			spr.modulate.a = maxf(spr.modulate.a - delta * 0.5, 0.08)
		if dist > 40.0:
			velocity = _steer_around_walls(dir) * spd * 0.3
		else:
			velocity = Vector2.ZERO
		# If player is close and fighting other enemies, engage
		var other_enemies_fighting = false
		for e in get_tree().get_nodes_in_group("enemy"):
			if e != self and is_instance_valid(e) and e.state == State.CHASE and e.state != State.DEAD:
				if e.global_position.distance_to(global_position) < 200.0:
					other_enemies_fighting = true
					break
		if (dist < 60.0 and other_enemies_fighting) or dist < 25.0:
			set_meta("amb_state", 1)
			if spr:
				spr.modulate.a = 0.5  # become partially visible when attacking
	else:
		# Engaging — chase and attack, become more visible
		if spr:
			spr.modulate.a = minf(spr.modulate.a + delta * 0.3, 0.5)
		velocity = _steer_around_walls(dir) * spd * 1.5
		# If player gets far, go back to hiding
		if dist > 100.0:
			set_meta("amb_state", 0)
	# Reactive teleport when hit — reposition and go back to hiding
	if not has_meta("amb_last_hp"):
		set_meta("amb_last_hp", hp)
	var alh: int = get_meta("amb_last_hp")
	if hp < alh:
		set_meta("amb_last_hp", hp)
		# Teleport away to valid floor position and hide again
		global_position = _find_valid_floor_pos(_spawn_pos, 30.0, 60.0)
		set_meta("amb_state", 0)
		if spr:
			spr.modulate.a = 0.08

func _apply_movement_pattern(p: MovementPattern, dir: Vector2, dist: float, delta: float) -> void:
	var to_ally: Vector2 = Vector2.ZERO
	var eff_speed: float = speed
	var ally_dist: float = 0.0
	var center: Vector2 = global_position
	if _enraged:
		# Bomb enemies get only 30% of the enrage speed bonus — they shouldn't kite the
		# player with bombs at sprinting speed.
		var _bonus = p.enrage_speed_bonus
		if _is_bomb_attack_type(_get_active_attack_type()):
			_bonus *= 0.30
		eff_speed *= (1.0 + _bonus)

	# Bodyguard override: follow ally instead of player
	if _bodyguard_mode and is_instance_valid(_attached_ally):
		if ally_dist > 12.0:
			velocity = _steer_around_walls(to_ally) * eff_speed * 0.8
		else:
			velocity = Vector2.ZERO
		return

	# Dispatch by movement type
	match p.move_type:
		MovementPattern.MoveType.ORBIT_PLAYER:
			_move_orbit_target(player.global_position if is_instance_valid(player) else global_position, p, eff_speed, delta)
		MovementPattern.MoveType.ORBIT_POINT:
			_move_orbit_target(_spawn_pos, p, eff_speed, delta)
		MovementPattern.MoveType.ORBIT_ALLY:
			var ally = _find_nearest_ally()
			if ally:
				center = ally.global_position
			_move_orbit_target(center, p, eff_speed, delta)
		MovementPattern.MoveType.PATROL_H:
			_move_patrol(Vector2.RIGHT, p, eff_speed, delta)
		MovementPattern.MoveType.PATROL_V:
			_move_patrol(Vector2.DOWN, p, eff_speed, delta)
		MovementPattern.MoveType.FLEE:
			velocity = _steer_around_walls(-dir) * eff_speed
		MovementPattern.MoveType.ZIGZAG:
			_move_zigzag(dir, p, eff_speed, delta)
		MovementPattern.MoveType.WALL_BOUNCE:
			_move_wall_bounce(p, eff_speed, delta)
		MovementPattern.MoveType.DASH_IN_OUT:
			_move_dash_in_out(dir, dist, p, eff_speed, delta)
		MovementPattern.MoveType.KITE:
			_move_kite(dir, dist, p, eff_speed)
		MovementPattern.MoveType.SWOOP:
			_move_swoop(dir, dist, p, delta)
		MovementPattern.MoveType.TELEPORT:
			_move_teleport(p, eff_speed, delta)
		MovementPattern.MoveType.MIRROR:
			_move_mirror(p, eff_speed, delta)
		MovementPattern.MoveType.INTERCEPT:
			_move_intercept(dir, dist, p, eff_speed, delta)
		MovementPattern.MoveType.ELASTIC:
			_move_elastic(dir, p, eff_speed, delta)
		MovementPattern.MoveType.EDGE_SKATER:
			_move_edge_skater(p, eff_speed, delta)
		MovementPattern.MoveType.BAIT_PUNISH:
			_move_bait_punish(dir, dist, p, eff_speed, delta)
		MovementPattern.MoveType.AMBUSH:
			_move_ambush(dir, dist, p, eff_speed, delta)
		_:
			_move_weighted(p, dir, dist, delta, eff_speed)

	# Generated and ranged enemies still need to commit toward the player eventually.
	# Without this, hold/kite/orbit identities can devolve into stationary turret behavior.
	if dist > 72.0:
		var pursuit_dir := _steer_around_walls(dir)
		var active_attack := _get_active_attack_type(false)
		var is_area_denial := _is_area_denial_attack(active_attack)
		var can_force_pursuit := p.move_type in [
			MovementPattern.MoveType.WEIGHTED,
			MovementPattern.MoveType.KITE,
			MovementPattern.MoveType.ORBIT_PLAYER,
			MovementPattern.MoveType.ORBIT_POINT,
			MovementPattern.MoveType.ORBIT_ALLY,
			MovementPattern.MoveType.PATROL_H,
			MovementPattern.MoveType.PATROL_V,
			MovementPattern.MoveType.TELEPORT,
			MovementPattern.MoveType.MIRROR,
		]
		var pursuit_delay := 1.35 if is_area_denial else 2.5
		if can_force_pursuit and (_chase_timer > pursuit_delay or velocity.length() < eff_speed * 0.22):
			velocity = (velocity * 0.45 + pursuit_dir * eff_speed * 0.9).limit_length(eff_speed)

## Orbit around a center point at orbit_radius — always tangential, corrects radius
func _move_orbit_target(center: Vector2, p: MovementPattern, spd: float, delta: float) -> void:
	_orbit_angle += p.orbit_speed * delta
	var to_center = center - global_position
	var current_dist = to_center.length()
	if current_dist < 1.0:
		velocity = Vector2.RIGHT * spd
		return
	# Tangential direction (perpendicular to radius)
	var tangent = Vector2(-to_center.y, to_center.x).normalized()
	if p.orbit_speed < 0:
		tangent = -tangent
	# Radial correction — gentle, capped at 30% of speed so tangent always dominates
	var radial_error = current_dist - p.orbit_radius
	var correction_strength = clampf(radial_error / p.orbit_radius, -0.3, 0.3) * spd
	var correction = to_center.normalized() * correction_strength
	velocity = (tangent * spd + correction)

## Patrol back and forth along an axis from spawn
func _move_patrol(axis: Vector2, p: MovementPattern, spd: float, delta: float) -> void:
	var target: Vector2 = player.global_position if is_instance_valid(player) else global_position
	_patrol_offset += _patrol_dir * spd * delta
	if absf(_patrol_offset) > p.patrol_length:
		_patrol_dir = -_patrol_dir
		_patrol_offset = clampf(_patrol_offset, -p.patrol_length, p.patrol_length)
	var to_target = target - global_position
	if to_target.length() > 2.0:
		velocity = _steer_around_walls(to_target.normalized()) * spd
	else:
		velocity = axis * _patrol_dir * spd

## Zigzag: sharp lateral zigzag while slowly approaching player
func _move_zigzag(dir: Vector2, p: MovementPattern, spd: float, delta: float) -> void:
	var perp = Vector2(-dir.y, dir.x)
	var side = 1.0 if sin(_melee_flank_timer / 0.4 * PI) >= 0.0 else -1.0
	_melee_flank_timer += delta
	var zigzag_period = 0.4
	# Mostly sideways (perpendicular to player), slight forward creep
	var zigzag_dir = (perp * side * 3.0 + dir * 0.3).normalized()
	velocity = _steer_around_walls(zigzag_dir) * spd

## Wall bounce: picks a random direction on first call, bounces off walls like a billiard ball
func _move_wall_bounce(p: MovementPattern, spd: float, delta: float) -> void:
	if not has_meta("bounce_dir"):
		set_meta("bounce_dir", Vector2.from_angle(randf() * TAU))
	var bdir: Vector2 = get_meta("bounce_dir")
	velocity = bdir * spd
	move_and_slide()
	# Check wall collisions and reflect
	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i)
		if col:
			bdir = bdir.bounce(col.get_normal())
			set_meta("bounce_dir", bdir)
	# Don't let move_and_slide run again in physics — mark handled
	set_meta("_wall_bounce_handled", true)

## Kite: maintain exact distance from player — retreat if too close, advance if too far
func _move_kite(dir: Vector2, dist: float, p: MovementPattern, spd: float) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var ideal = p.kite_distance
	var margin = 10.0
	if dist < ideal - margin:
		# Too close — back away
		velocity = _steer_around_walls(-dir) * spd
	elif dist > ideal + margin:
		# Too far — approach
		velocity = _steer_around_walls(dir) * spd * 0.7
	else:
		# At ideal range — strafe sideways
		var side := 1.0 if int(Engine.get_physics_frames() / 24) % 2 == 0 else -1.0
		velocity = _steer_around_walls(perp * side) * spd * 0.8

## Swoop: fast arc that passes BESIDE the player (not through), loops wide, comes back
func _move_swoop(dir: Vector2, dist: float, p: MovementPattern, delta: float) -> void:
	# States: 0=looping out (wide arc away), 1=swooping in (fast pass beside player)
	if not has_meta("swoop_state"):
		set_meta("swoop_state", 1)
		set_meta("swoop_side", 1.0 if randf() > 0.5 else -1.0)
		set_meta("swoop_closest", 999.0)
		set_meta("swoop_timer", 0.0)
	var side: float = float(get_meta("swoop_side", 1.0))
	var perp := Vector2(-dir.y, dir.x)
	var sw_state: int = int(get_meta("swoop_state", 1))
	if sw_state == 1:
		# Aim beside the player — lateral component biases the pass to one side
		var swoop_dir := (dir + perp * side * 2.5).normalized()
		velocity = swoop_dir * p.swoop_speed
		# Track closest approach — once we start getting farther, we've passed
		var prev_closest: float = float(get_meta("swoop_closest", 999.0))
		if dist < prev_closest:
			set_meta("swoop_closest", dist)
		elif dist > prev_closest + 15.0:
			# We've passed the player — start looping out
			set_meta("swoop_state", 0)
			set_meta("swoop_timer", 0.0)
			set_meta("swoop_side", -side)
			set_meta("swoop_closest", 999.0)
	else:
		# Looping out in a wide arc away from player
		var timer: float = float(get_meta("swoop_timer", 0.0)) + delta
		set_meta("swoop_timer", timer)
		var arc_dir := (-dir + perp * side * 2.0).normalized()
		velocity = arc_dir * p.swoop_speed * 0.5
		if timer > 1.5 or dist > p.swoop_arc_size:
			set_meta("swoop_state", 1)

## Teleport: blinks to random position in room when hit, also periodic blink
func _move_teleport(p: MovementPattern, spd: float, delta: float) -> void:
	var to_spawn: Vector2 = _spawn_pos - global_position
	if not has_meta("tp_timer"):
		set_meta("tp_timer", p.teleport_interval)
		set_meta("tp_last_hp", hp)
	var timer: float = get_meta("tp_timer", p.teleport_interval) as float
	timer -= delta
	set_meta("tp_timer", timer)
	# Reactive teleport: blink immediately when taking damage
	var last_hp: int = get_meta("tp_last_hp", hp)
	var took_damage = hp < last_hp
	set_meta("tp_last_hp", hp)
	if took_damage or timer <= 0:
		_do_teleport_blink(p)
		set_meta("tp_timer", p.teleport_interval)
	else:
		# Slow drift between teleports
		if to_spawn.length() > 8.0:
			velocity = to_spawn.normalized() * spd * 0.3
		else:
			velocity = Vector2.ZERO

## Find a valid floor position near a center point. Returns center if no floor found.
func _find_valid_floor_pos(center: Vector2, min_dist: float, max_dist: float) -> Vector2:
	var room_node = get_parent().get_parent() if get_parent() else null
	var floor_tm: TileMapLayer = null
	if room_node and room_node.has_node("Floor"):
		floor_tm = room_node.get_node("Floor") as TileMapLayer
	for _i in range(15):
		var dist := randf_range(min_dist, maxf(min_dist, max_dist))
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * dist
		var candidate = center + offset
		if floor_tm:
			var local_pos = floor_tm.to_local(candidate)
			var cell = floor_tm.local_to_map(local_pos)
			if floor_tm.get_cell_source_id(cell) >= 0:
				return candidate
		else:
			return candidate
	return center  # couldn't find valid spot, stay put

func _do_teleport_blink(p: MovementPattern) -> void:
	var start_pos := global_position
	var tw = create_tween()
	var anchor := global_position
	if is_instance_valid(player):
		var away := (global_position - player.global_position)
		if away.length() > 0.01:
			anchor = global_position + away.normalized() * minf(p.teleport_range * 0.35, 24.0)
	global_position = _find_valid_floor_pos(anchor, 20.0, p.teleport_range)
	velocity = Vector2.ZERO
	# Visual flash
	var spr = get_node_or_null("Sprite2D")
	if spr:
		tw.tween_property(spr, "modulate:a", 0.2, 0.05)
		tw.tween_property(spr, "modulate:a", 1.0, 0.15)
	var vfx_tp = get_node_or_null("/root/VFXManager")
	if vfx_tp:
		vfx_tp.warp_link(start_pos, global_position, Color(0.84, 0.09, 0.05, 0.96), 12.0, 18.0)

## Mirror: copies player movement + constantly pulls player toward self
func _move_mirror(p: MovementPattern, spd: float, delta: float) -> void:
	var pull_dir: Vector2 = Vector2.ZERO
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		return
	if not has_meta("mirror_prev_player"):
		set_meta("mirror_prev_player", player.global_position)
	var prev_pp: Vector2 = get_meta("mirror_prev_player")
	var player_vel = player.global_position - prev_pp
	set_meta("mirror_prev_player", player.global_position)
	# Move exactly as the player moves (copy their velocity)
	if player_vel.length() > 0.5:
		velocity = player_vel / maxf(delta, 0.001)
	else:
		# Player is still — slowly drift around at idle speed
		_orbit_angle += 1.5 * delta
		var idle_target = _spawn_pos + Vector2.from_angle(_orbit_angle) * 25.0
		var to_idle = idle_target - global_position
		if to_idle.length() > 3.0:
			velocity = to_idle.normalized() * spd * 0.5
		else:
			velocity = Vector2.ZERO
	# Pull effect: constantly drag player toward this enemy
	if player is CharacterBody2D:
		var pull_dist = pull_dir.length()
		if pull_dist > 10.0 and pull_dist < 150.0:
			var pull_strength = p.mirror_pull_strength * (1.0 - pull_dist / 150.0)
			player.velocity += pull_dir.normalized() * pull_strength * delta

## Dash to player, pause, dash back to spawn
func _move_dash_in_out(dir: Vector2, dist: float, p: MovementPattern, spd: float, delta: float) -> void:
	_dash_cd -= delta
	_dash_timer -= delta
	match _dash_state:
		0:  # idle at spawn, wait for cooldown
			var to_spawn = _spawn_pos - global_position
			if to_spawn.length() > 4.0:
				velocity = _steer_around_walls(to_spawn.normalized()) * spd * 0.5
			else:
				velocity = Vector2.ZERO
			if _dash_cd <= 0:
				_dash_state = 1
				_dash_timer = 1.5  # max dash time
		1:  # dashing in toward player
			velocity = _steer_around_walls(dir) * p.dash_in_speed
			if dist < 15.0 or _dash_timer <= 0:
				_dash_state = 2
				_dash_timer = p.dash_pause
				velocity = Vector2.ZERO
		2:  # pausing at player (attack happens via normal attack timer)
			velocity = Vector2.ZERO
			if _dash_timer <= 0:
				_dash_state = 3
				_dash_timer = 1.5
		3:  # dashing back to spawn
			var to_spawn = _spawn_pos - global_position
			if to_spawn.length() > 8.0 and _dash_timer > 0:
				velocity = _steer_around_walls(to_spawn.normalized()) * p.dash_in_speed
			else:
				_dash_state = 0
				_dash_cd = p.dash_cooldown
				velocity = Vector2.ZERO

func _find_nearest_ally() -> Node2D:
	var nearest_dist := INF
	var nearest: Node2D = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not is_instance_valid(e) or e.state == State.DEAD:
			continue
		var d = global_position.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest

## Soft separation: enemies push away from overlapping neighbors (prevents clumping)
func _apply_separation(_delta: float) -> void:
	if state == State.DEAD or state == State.CHARGING:
		return
	var sep_radius := 12.0 * (1.0 + (_weight - 1.0) * 0.3)  # larger enemies need more space
	var sep_force := 60.0
	var sep := Vector2.ZERO
	var enemies = get_tree().get_nodes_in_group("enemy")
	var my_pos := global_position
	for e in enemies:
		if e == self or not is_instance_valid(e):
			continue
		if "state" in e and e.state == State.DEAD:
			continue
		var diff: Vector2 = my_pos - e.global_position
		var dist_sq: float = diff.length_squared()
		if dist_sq < sep_radius * sep_radius and dist_sq > 0.01:
			var dist_val: float = sqrt(dist_sq)
			# Stronger push when closer (inverse linear)
			var strength: float = (sep_radius - dist_val) / sep_radius
			sep += diff.normalized() * strength
	if sep.length_squared() > 0.01:
		velocity += sep.normalized() * sep_force * minf(sep.length(), 2.0)

## Legacy weighted movement (existing system)
func _move_weighted(p: MovementPattern, dir: Vector2, dist: float, delta: float, eff_speed: float) -> void:
	var flow_dir: Vector2 = Vector2.ZERO
	var t: float = Time.get_ticks_msec() / 1000.0
	var sfx = get_node_or_null("/root/SFXManager")
	var pref = p.preferred_distance if p.preferred_distance > 0 else (definition.preferred_distance if definition else 0.0)

	var aw = p.approach_weight
	var rw = p.retreat_weight
	var sw = p.strafe_weight
	var hw = p.hold_weight

	if pref > 0:
		if dist < p.close_threshold:
			if p.close_approach >= 0: aw = p.close_approach
			if p.close_retreat >= 0: rw = p.close_retreat
			if p.close_strafe >= 0: sw = p.close_strafe
			eff_speed *= p.close_speed_mult
		elif dist > pref * p.far_threshold_mult:
			if p.far_approach >= 0: aw = p.far_approach
			if p.far_retreat >= 0: rw = p.far_retreat
			if p.far_strafe >= 0: sw = p.far_strafe
			eff_speed *= p.far_speed_mult
		elif dist < pref * 0.8:
			rw += t * 0.5
			aw *= (1.0 - t * 0.5)
		elif dist > pref:
			var denom = pref * (p.far_threshold_mult - 1.0)
			if denom > 0:
				aw += t * 0.3

	if _enraged:
		aw += p.enrage_approach_boost

	var approach_vec = dir
	var retreat_vec = -dir
	var strafe_vec = dir.rotated(PI * 0.5 * _melee_dodge_dir)

	if p.weave_amplitude > 0:
		var weave_angle = PI * p.weave_amplitude * sin(_melee_flank_timer * 3.0)
		approach_vec = dir.rotated(weave_angle)
		_melee_flank_timer += delta

	var total = aw + rw + sw + hw
	if total < 0.01:
		velocity = Vector2.ZERO
	else:
		var move_component = approach_vec * aw + retreat_vec * rw + strafe_vec * sw
		var hold_factor = 1.0 - (hw / total)
		if move_component.length() < 0.01:
			velocity = Vector2.ZERO
		else:
			var final_dir = move_component.normalized()
			if _nav and _nav.is_ready() and not (definition and definition.ignores_terrain) and dist > 12.0:
				if aw > rw and aw > sw:
					if flow_dir != Vector2.ZERO:
						final_dir = flow_dir
			velocity = _steer_around_walls(final_dir) * eff_speed * hold_factor

	if p.can_charge and _boss_charge_cd <= 0 and dist > p.charge_min_dist and dist < p.charge_max_dist:
		_boss_charge_cd = p.charge_cooldown if not _enraged else p.charge_cooldown * 0.5
		charge_dir = dir
		charge_timer = p.charge_duration
		state = State.CHARGING
		velocity = dir * speed * p.charge_speed_mult
		if sfx:
			sfx.play("attack_b", -6.0, 0.1)

	if p.dodge_enabled:
		_melee_dodge_timer -= delta
		if _melee_dodge_timer <= 0:
			_melee_dodge_timer = randf_range(p.dodge_interval_min, p.dodge_interval_max)
			_melee_dodge_dir = -_melee_dodge_dir

func _do_legacy_movement(dir: Vector2, dist: float, delta: float) -> void:
	var dodge: float = 0.0
	var is_boss: bool = definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS
	var away: Vector2 = Vector2.ZERO
	var sfx_l = get_node_or_null("/root/SFXManager")
	var weave: Vector2 = Vector2.ZERO
	var approach: Vector2 = Vector2.ZERO
	var to_ally: Vector2 = Vector2.ZERO
	var atk_type_m: int = definition.attack_type if definition else 0
	var strafe: Vector2 = Vector2.ZERO
	var sfx_bc = get_node_or_null("/root/SFXManager")
	var ally_dist: float = 0.0
	var base_atk: int = definition.attack_damage if definition else 2
	var atk_type: int = definition.attack_type if definition else 0
	var pref_dist = definition.preferred_distance if definition else 0.0
	var move_dir = dir
	var eff_speed = speed
	var enraged = _enraged

	if enraged:
		eff_speed *= 1.5

	# Use flow-field pathfinding if available (dungeon) and not a ghost
	var use_flow = _nav and _nav.is_ready() and not (definition and definition.ignores_terrain)
	if use_flow and dist > 12.0:
		var flow_dir = _nav.get_flow_direction(global_position)
		if flow_dir != Vector2.ZERO:
			move_dir = flow_dir
	elif not (definition and definition.ignores_terrain):
		move_dir = _steer_around_walls(dir)

	# Boss/Elite special movement behaviors
	if _is_boss_or_large and definition:
		match base_atk:
			EnemyDefinition.AttackType.MELEE, EnemyDefinition.AttackType.CHARGE, EnemyDefinition.AttackType.DASH:
				if _boss_charge_cd <= 0 and dist > 20 and dist < 80:
					_boss_charge_cd = 3.0 if not enraged else 1.5
					charge_dir = dir
					charge_timer = 0.4
					state = State.CHARGING
					velocity = dir * eff_speed * 3.0
					if sfx_bc:
						sfx_bc.play("attack_b", -4.0, 0.1)
					return
				velocity = move_dir * eff_speed * 1.5
			EnemyDefinition.AttackType.SUMMON:
				if _boss_summon_cd <= 0:
					_boss_summon_cd = 5.0 if not enraged else 3.0
					_do_summon()
				if dist > 60:
					velocity = move_dir * eff_speed * 0.4
				else:
					velocity = Vector2.ZERO
			EnemyDefinition.AttackType.BEAM:
				velocity = move_dir * eff_speed * 0.3
			_:
				if pref_dist > 0:
					if dist > pref_dist:
						velocity = move_dir * eff_speed * 0.8
					else:
						velocity = Vector2.ZERO
				else:
					velocity = move_dir * eff_speed * 1.2
	elif pref_dist > 0:
		if atk_type == EnemyDefinition.AttackType.PUSH_WAVE and _bodyguard_mode and is_instance_valid(_attached_ally):
			if ally_dist > 12.0:
				velocity = _steer_around_walls(to_ally) * eff_speed * 0.8
			else:
				velocity = Vector2.ZERO
		elif atk_type in [EnemyDefinition.AttackType.FIRE_RAIN,
			EnemyDefinition.AttackType.BOMB_TOSS, EnemyDefinition.AttackType.CARPET_BOMB,
			EnemyDefinition.AttackType.CLUSTER_BOMB, EnemyDefinition.AttackType.MINE_DROP,
			EnemyDefinition.AttackType.ARTILLERY, EnemyDefinition.AttackType.POISON_CLOUD]:
			if is_boss:
				if dist < pref_dist * 0.4:
					velocity = _steer_around_walls(-dir) * eff_speed * 0.4
				elif dist < pref_dist:
					velocity = Vector2.ZERO
				else:
					velocity = move_dir * eff_speed * 0.5
					_hold_timer = 0.0
			else:
				if dist < pref_dist:
					velocity = _steer_around_walls(away) * eff_speed * 0.9
				elif dist < pref_dist * 1.5:
					velocity = Vector2.ZERO
				else:
					velocity = move_dir * eff_speed * 0.4
					_hold_timer = 0.0
		elif atk_type == EnemyDefinition.AttackType.BARRIER_WALL:
			if dist < 20.0:
				velocity = move_dir * eff_speed * 1.5
			elif dist < pref_dist:
				velocity = _steer_around_walls(away) * eff_speed * 0.7
			else:
				velocity = Vector2.ZERO
		else:
			if dist > pref_dist * 1.5:
				velocity = move_dir * eff_speed * 0.8
				_hold_timer = 0.0
			else:
				_hold_timer += delta
				if _hold_timer > 3.0:
					velocity = move_dir * eff_speed * 0.6
					if _hold_timer > 4.5:
						_hold_timer = 0.0
				else:
					velocity = Vector2.ZERO
	else:
		_melee_dodge_timer -= delta
		_melee_lunge_cd -= delta
		if atk_type_m == EnemyDefinition.AttackType.CHARGE or atk_type_m == EnemyDefinition.AttackType.DASH:
			if dist > 50:
				velocity = move_dir * eff_speed * 1.3
			elif dist > 20:
				_melee_flank_timer += delta
				velocity = _steer_around_walls((strafe + approach).normalized()) * eff_speed * 1.1
				if _melee_flank_timer > 1.5 and _melee_lunge_cd <= 0:
					_melee_flank_timer = 0.0
					_melee_lunge_cd = 2.5
					charge_dir = dir
					charge_timer = 0.3
					state = State.CHARGING
					velocity = dir * eff_speed * 3.0
					if sfx_l:
						sfx_l.play("attack_b", -6.0, 0.1)
			else:
				velocity = move_dir * eff_speed * 1.5
			if _melee_dodge_timer <= 0:
				_melee_dodge_timer = randf_range(0.8, 2.0)
				_melee_dodge_dir = -_melee_dodge_dir
		elif atk_type_m == EnemyDefinition.AttackType.NONE:
			velocity = move_dir * eff_speed
		elif atk_type_m == EnemyDefinition.AttackType.STRAFE_RUN:
			velocity = _steer_around_walls((strafe + approach).normalized()) * eff_speed * 1.2
			var _contact_dist := 8.0
			if is_boss:
				_contact_dist = 14.0
			elif _is_boss_or_large:
				_contact_dist = 10.0
			if _melee_dodge_timer <= 0:
				_melee_dodge_timer = randf_range(0.6, 1.5)
				_melee_dodge_dir = -_melee_dodge_dir
			else:
				if dist > 30:
					velocity = _steer_around_walls(weave) * eff_speed * 1.2
					_melee_flank_timer += delta
				elif dist > _contact_dist:
					if _melee_dodge_timer > 0:
						var dodge_dir = dir.rotated(PI * 0.5 * _melee_dodge_dir)
						velocity = _steer_around_walls(dodge_dir) * eff_speed * 1.4
					else:
						velocity = move_dir * eff_speed * 1.5
				else:
					velocity = dir.rotated(PI * 0.5 * _melee_dodge_dir) * eff_speed * 0.8
				if _melee_dodge_timer <= 0:
					_melee_dodge_timer = randf_range(0.5, 1.2)
					_melee_dodge_dir = -_melee_dodge_dir

func _get_active_attack_type(consume_pool: bool = false) -> EnemyDefinition.AttackType:
	if not definition:
		return EnemyDefinition.AttackType.RANGED
	# Artillery enemies always use their native attack — no pool mixing
	if definition.attack_type == EnemyDefinition.AttackType.ARTILLERY:
		return EnemyDefinition.AttackType.ARTILLERY
	# Elites/bosses cycle through their random attack pool
	if _is_boss_or_large and not _attack_pool.is_empty():
		return _next_pool_attack() if consume_pool else _peek_pool_attack()
	# Normal enemies with melee secondary: 40% chance to use melee when player is close
	if definition.has_meta("melee_secondary") and is_instance_valid(player):
		var _md = global_position.distance_to(player.global_position)
		if _md < 50.0 and randf() < 0.4:
			return definition.get_meta("melee_secondary") as EnemyDefinition.AttackType
	if _current_phase == 3 and definition.phase_3_attack != EnemyDefinition.AttackType.NONE:
		return definition.phase_3_attack
	if _current_phase == 2 and definition.phase_2_attack != EnemyDefinition.AttackType.NONE:
		return definition.phase_2_attack
	return definition.attack_type

func _get_active_bullet_count() -> int:
	if not definition:
		return 1
	if _current_phase == 3 and definition.phase_3_bullet_count > 0:
		return definition.phase_3_bullet_count
	if _current_phase == 2 and definition.phase_2_bullet_count > 0:
		return definition.phase_2_bullet_count
	return definition.bullet_count

func _get_bomb_attack_count(default_count: int = 1) -> int:
	if not definition:
		return default_count
	var raw = _get_active_bullet_count()
	if definition.size_class >= EnemyDefinition.SizeClass.BOSS:
		return clampi(raw, default_count, default_count + 1)
	if definition.size_class >= EnemyDefinition.SizeClass.LARGE:
		return clampi(raw, default_count, default_count)
	return clampi(raw, default_count, default_count)

func _is_bomb_attack_type(atk: int) -> bool:
	return atk in [
		EnemyDefinition.AttackType.BOMB_TOSS,
		EnemyDefinition.AttackType.CARPET_BOMB,
		EnemyDefinition.AttackType.FIRE_RAIN,
		EnemyDefinition.AttackType.CLUSTER_BOMB,
		EnemyDefinition.AttackType.MINE_DROP,
		EnemyDefinition.AttackType.ARTILLERY,
		EnemyDefinition.AttackType.POISON_CLOUD,
	]

func _get_bomb_flight_time(base_flight: float, extra_scale: float = 1.0) -> float:
	# Bombs need a readable marker, but long flights made carpet bombs feel broken.
	var tuned = maxf(base_flight, 0.85) * extra_scale
	if definition:
		var lvl := maxi(definition.level, 1)
		if lvl <= 3:
			tuned *= 1.15
		elif lvl <= 7:
			tuned *= 1.08
	return clampf(tuned, 0.9, 2.2)

func _is_heavy_bomb_attack(atk: int) -> bool:
	return atk in [
		EnemyDefinition.AttackType.BOMB_TOSS,
		EnemyDefinition.AttackType.CARPET_BOMB,
		EnemyDefinition.AttackType.FIRE_RAIN,
		EnemyDefinition.AttackType.CLUSTER_BOMB,
		EnemyDefinition.AttackType.MINE_DROP,
		EnemyDefinition.AttackType.ARTILLERY,
		EnemyDefinition.AttackType.POISON_CLOUD,
		EnemyDefinition.AttackType.MORTAR,
		EnemyDefinition.AttackType.METEOR_SHOWER,
	]

func _is_area_denial_attack(atk: int) -> bool:
	return atk in [
		EnemyDefinition.AttackType.MINEFIELD,
		EnemyDefinition.AttackType.SEEKING_MINES,
		EnemyDefinition.AttackType.MINE_DROP,
		EnemyDefinition.AttackType.POISON_CLOUD,
		EnemyDefinition.AttackType.BARRIER_WALL,
		EnemyDefinition.AttackType.TELEGRAPH_EXPLOSION,
		EnemyDefinition.AttackType.ORBIT_LAUNCH,
	]

func _get_effective_attack_range(atk: int) -> float:
	var lvl := maxi(definition.level if definition else 1, 1)
	match atk:
		EnemyDefinition.AttackType.ARTILLERY:
			return clampf(120.0 + float(lvl) * 10.0, 120.0, 280.0)
		EnemyDefinition.AttackType.BOMB_TOSS:
			return clampf(76.0 + float(lvl) * 4.0, 76.0, 140.0)
		EnemyDefinition.AttackType.CARPET_BOMB:
			return clampf(84.0 + float(lvl) * 5.0, 84.0, 150.0)
		EnemyDefinition.AttackType.FIRE_RAIN:
			return clampf(80.0 + float(lvl) * 4.0, 80.0, 145.0)
		EnemyDefinition.AttackType.CLUSTER_BOMB:
			return clampf(78.0 + float(lvl) * 4.0, 78.0, 140.0)
		EnemyDefinition.AttackType.MINE_DROP:
			return clampf(64.0 + float(lvl) * 2.0, 64.0, 104.0)
		EnemyDefinition.AttackType.POISON_CLOUD:
			return clampf(82.0 + float(lvl) * 4.0, 82.0, 145.0)
		_:
			return 120.0

func _steer_around_walls(desired_dir: Vector2) -> Vector2:
	var space = get_world_2d().direct_space_state
	# Cast rays ahead to detect walls and steer around them
	if desired_dir.length_squared() < 0.01:
		return desired_dir
	var look_dist = 12.0  # how far ahead to check

	# Check straight ahead
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + desired_dir * look_dist, 16)
	query.exclude = [get_rid()]
	var result = space.intersect_ray(query)
	if result.is_empty():
		return desired_dir  # no wall ahead, go straight

	# Wall ahead — try left and right rotations to find open path
	for angle in [0.6, -0.6, 1.0, -1.0, 1.4, -1.4]:
		var test_dir = desired_dir.rotated(angle)
		query = PhysicsRayQueryParameters2D.create(global_position, global_position + test_dir * look_dist, 16)
		query.exclude = [get_rid()]
		result = space.intersect_ray(query)
		if result.is_empty():
			return test_dir.normalized()

	# All directions blocked — just try perpendicular
	return desired_dir.rotated(PI / 2)

func _get_runtime_movement_pattern() -> MovementPattern:
	var seq_step = _get_current_boss_sequence_step()
	if seq_step and seq_step.movement_pattern:
		return seq_step.movement_pattern
	var boss_state = _get_current_boss_state()
	if boss_state and boss_state.movement_pattern:
		return boss_state.movement_pattern
	return definition.movement_pattern if definition else null

var _boss_charge_cd: float = 0.0  # cooldown for boss charge attacks
var _boss_summon_cd: float = 0.0  # cooldown for boss periodic summons

func _do_chase(dir: Vector2, dist: float, delta: float) -> void:
	var side: Vector2 = Vector2.ZERO
	var atk: int = definition.attack_type if definition else 0
	# FEARED: run away from player
	if has_meta("feared") and get_meta("feared"):
		var flee_dir = -dir  # opposite of player direction
		velocity = flee_dir * speed * 1.3
		if flee_dir.x < 0:
			$Sprite2D.flip_h = true
		elif flee_dir.x > 0:
			$Sprite2D.flip_h = false
		return
	# CONFUSED: random movement
	if has_meta("confused") and get_meta("confused"):
		_wander_timer -= delta
		if _wander_timer <= 0:
			_wander_timer = 0.5 + randf() * 1.0
			_wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		velocity = _wander_dir * speed * 0.8
		# Randomly trigger attack in random direction
		if attack_timer <= 0:
			attack_timer = shoot_interval
			state = State.ATTACK
		return
	# STUNNED: don't move
	if has_meta("stunned") and get_meta("stunned"):
		velocity = Vector2.ZERO
		return
	# Lose aggro if player is very far away (but not if recently hit)
	var deaggro_dist = 400.0 if _dm else 200.0
	if _is_boss_or_large:
		deaggro_dist = 9999.0  # bosses/elites never de-aggro
	if dist > deaggro_dist and _hit_aggro_timer <= 0:
		velocity = Vector2.ZERO
		_begin_search()
		return

	# Tick boss ability cooldowns
	if _boss_charge_cd > 0:
		_boss_charge_cd -= delta
	if _boss_summon_cd > 0:
		_boss_summon_cd -= delta

	# Boss enrage at <30% HP
	_enraged = _is_boss_or_large and hp < _max_hp * 0.3
	if _enraged and attack_timer > 0:
		# Bomb attacks ignore enrage attack-speed boost (they already telegraphed/slow).
		# Only non-bomb attacks get the double-tick.
		var _atk_now = _get_active_attack_type()
		if not _is_bomb_attack_type(_atk_now):
			attack_timer -= delta  # double-tick non-bomb attacks when enraged

	# --- Data-driven movement pattern ---
	var runtime_movement = _get_runtime_movement_pattern()
	if runtime_movement:
		_apply_movement_pattern(runtime_movement, dir, dist, delta)
	else:
		# --- Legacy hardcoded movement ---
		_do_legacy_movement(dir, dist, delta)

	attack_timer -= delta
	if _uses_boss_state_machine():
		_tick_boss_state_machine(delta, dir, dist)
		return
	# Artillery: re-check shared vision every ~1s (allies may die)
	if definition and definition.attack_type == EnemyDefinition.AttackType.ARTILLERY and Engine.get_physics_frames() % 60 == 0:
		_shared_vision_checked = false
		_check_shared_vision_once()
	var _atk_check = _get_active_attack_type(false) if attack_timer <= 0 else EnemyDefinition.AttackType.NONE
	var _no_los_attacks = [EnemyDefinition.AttackType.HEAL, EnemyDefinition.AttackType.SUMMON,
		EnemyDefinition.AttackType.BOMB_TOSS, EnemyDefinition.AttackType.CARPET_BOMB,
		EnemyDefinition.AttackType.FIRE_RAIN, EnemyDefinition.AttackType.CLUSTER_BOMB,
		EnemyDefinition.AttackType.MINE_DROP, EnemyDefinition.AttackType.ARTILLERY,
		EnemyDefinition.AttackType.POISON_CLOUD]
	var _needs_los = _atk_check not in _no_los_attacks
	# Artillery has extreme range (10-15 rooms ≈ 500px) and uses ally sight
	var _attack_range = _get_effective_attack_range(_atk_check)
	var _has_los = false
	if not _needs_los:
		_has_los = true
	elif _atk_check == EnemyDefinition.AttackType.ARTILLERY:
		_has_los = _has_line_of_sight_or_shared()
	else:
		_has_los = _has_line_of_sight()
	# Movement-attack coupling: check modifier distance constraints
	var _atk_mod = definition.attack_modifier if definition else null
	var _mod_blocks_attack = false
	if _atk_mod and attack_timer <= 0:
		if _atk_mod.min_fire_distance > 0 and dist < _atk_mod.min_fire_distance:
			_mod_blocks_attack = true
		elif _atk_mod.max_fire_distance > 0 and dist > _atk_mod.max_fire_distance:
			_mod_blocks_attack = true

	if attack_timer <= 0 and dist < _attack_range and _has_los and not _mod_blocks_attack:
		if _atk_mod and _atk_mod.requires_stationary and not _has_continuous_movement():
			velocity = Vector2.ZERO
		# All enemies shoot bullets as baseline — special types add extra behavior
		match atk:
			EnemyDefinition.AttackType.NONE:
				state = State.ATTACK  # still shoots
			EnemyDefinition.AttackType.MELEE:
				if dist < 30:
					# Lunge + shoot, then dodge back
					_shoot_single(dir)
					charge_dir = dir
					charge_timer = 0.2
					attack_timer = shoot_interval
					state = State.CHARGING
					# Queue a retreat dodge after the lunge
					get_tree().create_timer(0.25).timeout.connect(
						func():
							if is_instance_valid(self) and hp > 0 and state != State.DEAD:
								var retreat = -dir.rotated(randf_range(-0.5, 0.5))
								charge_dir = retreat
								charge_timer = 0.15
								state = State.CHARGING
					)
				else:
					state = State.ATTACK  # shoot from range
			EnemyDefinition.AttackType.CHARGE:
				if dist < 60:
					# Charge with side-dodge after impact
					_shoot_single(dir)
					_start_charge(dir)
					# Side-dodge after charge ends
					get_tree().create_timer(definition.charge_duration + 0.1 if definition else 0.5).timeout.connect(
						func():
							if is_instance_valid(self) and hp > 0 and state != State.DEAD:
								charge_dir = side
								charge_timer = 0.2
								state = State.CHARGING
								_melee_dodge_dir = -_melee_dodge_dir
					)
				else:
					state = State.ATTACK
			EnemyDefinition.AttackType.DASH:
				if dist < 80:
					# Dash through player then loop around
					_shoot_single(dir)
					_start_charge(dir)
					# After dash: curve back toward player from behind
					get_tree().create_timer(definition.charge_duration + 0.1 if definition else 0.5).timeout.connect(
						func():
							if is_instance_valid(self) and hp > 0 and state != State.DEAD:
								var loop = dir.rotated(PI * 0.7 * _melee_dodge_dir)
								charge_dir = loop
								charge_timer = 0.25
								state = State.CHARGING
								_melee_dodge_dir = -_melee_dodge_dir
					)
				else:
					state = State.ATTACK
			EnemyDefinition.AttackType.TELEPORT:
				if dist > 60:
					_do_teleport()
					attack_timer = definition.teleport_cooldown
				else:
					state = State.ATTACK
			EnemyDefinition.AttackType.HEAL:
				_try_heal_nearby()
				_shoot_single(dir)  # healers also shoot
				attack_timer = shoot_interval
			EnemyDefinition.AttackType.STEALTH:
				if _stealth_timer <= 0:
					_enter_stealth()
				else:
					state = State.ATTACK
			EnemyDefinition.AttackType.STRAFE_RUN:
				# Charge perpendicular while shooting
				_shoot_strafe_run(dir)
				var strafe_dir = dir.rotated(PI / 2.0 * (1.0 if randf() > 0.5 else -1.0))
				charge_dir = strafe_dir
				charge_timer = 0.4
				attack_timer = shoot_interval * 0.5
				state = State.CHARGING
			EnemyDefinition.AttackType.SWORD_SLASH:
				if dist < 28:
					_shoot_sword_slash(dir)
					attack_timer = shoot_interval
				else:
					state = State.ATTACK
			EnemyDefinition.AttackType.SPEAR_LUNGE:
				if dist < 65:
					_shoot_spear_lunge(dir)
					attack_timer = shoot_interval
				else:
					state = State.ATTACK
			EnemyDefinition.AttackType.CHARGE_BULL:
				if dist < 130 and dist > 25:
					_shoot_charge_bull(dir)
					attack_timer = shoot_interval
				else:
					state = State.ATTACK
			EnemyDefinition.AttackType.CLEAVE_COMBO:
				if dist < 30:
					_shoot_cleave_combo(dir)
					attack_timer = shoot_interval
				else:
					state = State.ATTACK
			EnemyDefinition.AttackType.WHIRLWIND:
				if dist < 50:
					_shoot_whirlwind(dir)
					attack_timer = shoot_interval
				else:
					state = State.ATTACK
			EnemyDefinition.AttackType.GROUND_POUND:
				if dist < 40:
					_shoot_ground_pound(dir)
					attack_timer = shoot_interval
				else:
					state = State.ATTACK
			EnemyDefinition.AttackType.TAIL_WHIP:
				if dist < 28:
					_shoot_tail_whip(dir)
					attack_timer = shoot_interval
				else:
					state = State.ATTACK
			EnemyDefinition.AttackType.SHIELD_BASH:
				if dist < 45:
					_shoot_melee_shield_bash(dir)
					attack_timer = shoot_interval
				else:
					state = State.ATTACK
			EnemyDefinition.AttackType.GRAB_THROW:
				if dist < 22:
					_shoot_grab_throw(dir)
					attack_timer = shoot_interval
				else:
					state = State.ATTACK
			EnemyDefinition.AttackType.STOMP_WAVE:
				if dist < 50:
					_shoot_stomp_wave(dir)
					attack_timer = shoot_interval
				else:
					state = State.ATTACK
			_:
				state = State.ATTACK

func _has_continuous_movement() -> bool:
	var runtime_movement = _get_runtime_movement_pattern()
	if runtime_movement == null:
		return false
	return runtime_movement.move_type != MovementPattern.MoveType.WEIGHTED

func _tick_boss_state_machine(delta: float, dir: Vector2, dist: float) -> void:
	var boss_state = _get_current_boss_state()
	if boss_state == null:
		return
	_boss_state_elapsed += delta
	var seq_step = _get_current_boss_sequence_step()
	var active_attack_mode = boss_state.attack_mode
	var active_attack_type = boss_state.attack_type
	var active_shot_pattern = boss_state.shot_pattern
	var active_attack_interval = boss_state.attack_interval
	var active_require_los = boss_state.require_line_of_sight
	var active_min_distance = boss_state.min_attack_distance
	var active_max_distance = boss_state.max_attack_distance
	if seq_step:
		_boss_sequence_elapsed += delta
		_boss_sequence_attack_timer -= delta
		active_attack_mode = seq_step.attack_mode
		active_attack_type = seq_step.attack_type
		active_shot_pattern = seq_step.shot_pattern
		active_attack_interval = seq_step.attack_interval
		active_require_los = seq_step.require_line_of_sight
		active_min_distance = seq_step.min_attack_distance
		active_max_distance = seq_step.max_attack_distance
	else:
		_boss_state_attack_timer -= delta
	if active_shot_pattern and active_shot_pattern.aim_mode == BossShotPattern.AimMode.SPINNING:
		_boss_spin_angle += deg_to_rad(active_shot_pattern.spinning_speed_degrees) * delta

	var has_los = true
	if active_require_los:
		has_los = _has_line_of_sight()
	if active_min_distance > 0.0 and dist < active_min_distance:
		has_los = false
	if active_max_distance > 0.0 and dist > active_max_distance:
		has_los = false

	var attack_timer_ref = _boss_sequence_attack_timer if seq_step else _boss_state_attack_timer
	if active_attack_mode != BossState.AttackMode.NONE and attack_timer_ref <= 0.0 and has_los:
		match active_attack_mode:
			BossState.AttackMode.ATTACK_TYPE:
				_fire_attack_type(active_attack_type, dir)
			BossState.AttackMode.GENERIC_SHOT:
				if active_shot_pattern:
					_fire_boss_shot_pattern(dir, active_shot_pattern)
		if seq_step:
			_boss_sequence_attack_timer = maxf(active_attack_interval, 0.05)
		else:
			_boss_state_attack_timer = maxf(active_attack_interval, 0.05)
		_active_modifier = null

	if seq_step and _should_advance_boss_sequence_step(boss_state, seq_step):
		_advance_boss_sequence_step(boss_state)

	if _should_advance_boss_state(boss_state):
		var next_idx = _find_boss_state_index(boss_state.next_state_id)
		if next_idx >= 0:
			_enter_boss_state(next_idx)
		else:
			_enter_boss_state((_boss_state_index + 1) % definition.boss_states.size())

func _should_advance_boss_state(boss_state: BossState) -> bool:
	if boss_state == null:
		return false
	var hp_ratio = float(hp) / float(maxi(_max_hp, 1))
	match boss_state.transition_mode:
		BossState.TransitionMode.TIME:
			return _boss_state_elapsed >= boss_state.duration
		BossState.TransitionMode.HP_BELOW:
			return hp_ratio <= boss_state.hp_threshold
		BossState.TransitionMode.EXTERNAL_TRIGGER:
			return boss_state.external_trigger != "" and _boss_pending_trigger == boss_state.external_trigger
		BossState.TransitionMode.TIME_OR_HP:
			return _boss_state_elapsed >= boss_state.duration or hp_ratio <= boss_state.hp_threshold
		BossState.TransitionMode.TIME_OR_EXTERNAL:
			return _boss_state_elapsed >= boss_state.duration or (boss_state.external_trigger != "" and _boss_pending_trigger == boss_state.external_trigger)
	return false

func _should_advance_boss_sequence_step(boss_state: BossState, seq_step) -> bool:
	if boss_state == null or seq_step == null:
		return false
	if boss_state.sequence_steps.is_empty():
		return false
	return _boss_sequence_elapsed >= maxf(float(seq_step.duration), 0.01)

func _advance_boss_sequence_step(boss_state: BossState) -> void:
	if boss_state == null or boss_state.sequence_steps.is_empty():
		return
	_boss_sequence_elapsed = 0.0
	_boss_sequence_attack_timer = 0.0
	_boss_sequence_index += 1
	if _boss_sequence_index >= boss_state.sequence_steps.size():
		if boss_state.loop_sequence:
			_boss_sequence_index = 0
		else:
			_boss_sequence_index = boss_state.sequence_steps.size() - 1
	_refresh_boss_name_label()

func _do_attack(dir: Vector2) -> void:
	var d: float = 0.0
	# WHIRLWIND active: don't override velocity — bouncing is handled in physics tick
	if has_meta("whirlwind_active") and get_meta("whirlwind_active"):
		return
	if not _has_continuous_movement():
		velocity = Vector2.ZERO
	# STUNNED: can't attack
	if has_meta("stunned") and get_meta("stunned"):
		state = State.CHASE
		return
	# FEARED: can't attack
	if has_meta("feared") and get_meta("feared"):
		state = State.CHASE
		return
	# CONFUSED: randomize attack direction, 30% chance to target nearest enemy
	var atk_dir = dir
	if has_meta("confused") and get_meta("confused"):
		if randf() < 0.3:
			# Friendly fire — aim at nearest ally
			var nearest_ally: Node2D = null
			var nearest_dist: float = INF
			for e in get_tree().get_nodes_in_group("enemy"):
				if e == self or not is_instance_valid(e) or e.state == State.DEAD:
					continue
				if d < nearest_dist:
					nearest_dist = d
					nearest_ally = e
			if nearest_ally:
				atk_dir = (nearest_ally.global_position - global_position).normalized()
			else:
				atk_dir = Vector2.from_angle(randf() * TAU)
		else:
			atk_dir = Vector2.from_angle(randf() * TAU)
		dir = atk_dir

	# Boss/Elite combo attacks — phase 2+ fires multiple pool attacks (not artillery)
	var _native_atk = definition.attack_type if definition else EnemyDefinition.AttackType.NONE
	if _is_boss_or_large and _current_phase >= 2 and not _attack_pool.is_empty() and _native_atk != EnemyDefinition.AttackType.ARTILLERY:
		_do_boss_combo_attack(dir)
		# If the combo pool includes any bomb-type attack, the elite/boss has to
		# use the full cooldown for the next combo — otherwise they spam 2-3
		# bombs per second. Only "all bullet" pools keep the 0.25x rapid rate.
		var _bomb_pool_types = [
			EnemyDefinition.AttackType.BOMB_TOSS, EnemyDefinition.AttackType.CARPET_BOMB,
			EnemyDefinition.AttackType.FIRE_RAIN, EnemyDefinition.AttackType.CLUSTER_BOMB,
			EnemyDefinition.AttackType.MINE_DROP, EnemyDefinition.AttackType.ARTILLERY,
			EnemyDefinition.AttackType.POISON_CLOUD, EnemyDefinition.AttackType.LEAPING_SLAM,
			EnemyDefinition.AttackType.ARROW_VOLLEY, EnemyDefinition.AttackType.MORTAR,
			EnemyDefinition.AttackType.METEOR_SHOWER,
		]
		var combo_has_bomb := false
		for atk_in_pool in _attack_pool:
			if atk_in_pool in _bomb_pool_types:
				combo_has_bomb = true
				break
		if combo_has_bomb:
			attack_timer = shoot_interval * 2.75  # heavy bomb combos need real downtime
		else:
			attack_timer = shoot_interval * 0.25
		cooldown_timer = 0.1
		state = State.COOLDOWN
		return

	# AttackSlot system: cycle through defined slots with per-attack modifiers
	var atk = _get_active_attack_type(true)
	if definition and definition.attack_slots.size() > 0:
		var slot = definition.attack_slots[_slot_idx % definition.attack_slots.size()]
		atk = slot.attack_type
		_active_modifier = slot.modifier  # may be null = plain attack
		_slot_idx += 1
	_obs_record_attack(atk, "direct")

	match atk:
		EnemyDefinition.AttackType.NONE:
			_shoot_single(dir)
		EnemyDefinition.AttackType.MELEE:
			# Lunge + shoot
			_shoot_single(dir)
			charge_dir = dir
			charge_timer = 0.2
			state = State.CHARGING
			attack_timer = shoot_interval * 0.25
			return  # charging handles cooldown
		EnemyDefinition.AttackType.RANGED:
			_shoot_single(dir)
		EnemyDefinition.AttackType.BURST:
			_shoot_ring(dir)
		EnemyDefinition.AttackType.CHARGE:
			_shoot_single(dir)
		EnemyDefinition.AttackType.DASH:
			_shoot_single(dir)
		EnemyDefinition.AttackType.SUMMON:
			_do_summon()
			_shoot_ring(dir)  # summon + ring burst
		EnemyDefinition.AttackType.SLAM:
			_do_slam()
			_shoot_ring(dir)  # slam + ring burst
		EnemyDefinition.AttackType.TELEPORT:
			_shoot_single(dir)
		EnemyDefinition.AttackType.SPIRAL:
			_shoot_spiral(dir)
		EnemyDefinition.AttackType.POISON_SHOT:
			_shoot_single(dir)
		EnemyDefinition.AttackType.STEALTH:
			_shoot_single(dir)
		EnemyDefinition.AttackType.SHIELD:
			_shoot_shield_bash(dir)
		EnemyDefinition.AttackType.BEAM:
			_start_beam(dir)
			_shoot_single(dir)  # also fires bullets during beam
		EnemyDefinition.AttackType.SPLIT:
			_shoot_single(dir)
		EnemyDefinition.AttackType.VOLLEY:
			_shoot_volley(dir)
		EnemyDefinition.AttackType.CROSS_SHOT:
			_shoot_cross(dir)
		EnemyDefinition.AttackType.WAVE_SHOT:
			_shoot_wave(dir)
		EnemyDefinition.AttackType.GATLING:
			_shoot_gatling(dir)
		EnemyDefinition.AttackType.MORTAR:
			_shoot_mortar(dir)
		EnemyDefinition.AttackType.NOVA:
			_shoot_nova(dir)
		EnemyDefinition.AttackType.ZIGZAG:
			_shoot_zigzag(dir)
		EnemyDefinition.AttackType.SHOTGUN_BLAST:
			_shoot_shotgun(dir)
		EnemyDefinition.AttackType.HELIX:
			_shoot_helix(dir)
		EnemyDefinition.AttackType.METEOR_SHOWER:
			_shoot_meteor_shower(dir)
		EnemyDefinition.AttackType.BOOMERANG_SHOT:
			_shoot_boomerang(dir)
		EnemyDefinition.AttackType.STRAFE_RUN:
			_shoot_strafe_run(dir)
		EnemyDefinition.AttackType.MINEFIELD:
			_shoot_minefield()
		EnemyDefinition.AttackType.RETURNING_VOLLEY:
			_shoot_returning(dir)
		EnemyDefinition.AttackType.SEEKING_MINES:
			_shoot_seeking_mines()
		EnemyDefinition.AttackType.DETONATOR:
			_shoot_detonator(dir)
		EnemyDefinition.AttackType.SPLITTER:
			_shoot_splitter(dir)
		EnemyDefinition.AttackType.SINE_BARRAGE:
			_shoot_sine_barrage(dir)
		EnemyDefinition.AttackType.HOMING_SALVO:
			_shoot_homing_salvo(dir)
		EnemyDefinition.AttackType.TELEGRAPH_EXPLOSION:
			_shoot_telegraph_explosion()
		EnemyDefinition.AttackType.ORBIT_LAUNCH:
			_shoot_orbit_launch(dir)
		EnemyDefinition.AttackType.WALL_BOUNCE:
			_shoot_wall_bounce(dir)
		EnemyDefinition.AttackType.LASER_GRID:
			_shoot_laser_grid(dir)
		EnemyDefinition.AttackType.GRAVITY_WELL:
			_shoot_gravity_well(dir)
		EnemyDefinition.AttackType.CHAIN_LIGHTNING:
			_shoot_chain_lightning(dir)
		EnemyDefinition.AttackType.DEATH_SPIRAL:
			_shoot_spiral(dir)  # same as spiral when used as active attack
		EnemyDefinition.AttackType.BOMB_TOSS:
			_shoot_bomb_toss()
		EnemyDefinition.AttackType.CARPET_BOMB:
			_shoot_carpet_bomb(dir)
		EnemyDefinition.AttackType.FIRE_RAIN:
			_shoot_fire_rain()
		EnemyDefinition.AttackType.CLUSTER_BOMB:
			_shoot_cluster_bomb()
		EnemyDefinition.AttackType.MINE_DROP:
			_shoot_mine_drop()
		EnemyDefinition.AttackType.BARRIER_WALL:
			_shoot_barrier_wall(dir)
		EnemyDefinition.AttackType.PULL_SHOT:
			_shoot_pull_shot(dir)
		EnemyDefinition.AttackType.PUSH_WAVE:
			_shoot_push_wave(dir)
		EnemyDefinition.AttackType.VORTEX:
			_shoot_vortex(dir)
		EnemyDefinition.AttackType.RING_PULSE:
			_shoot_ring_pulse(dir)
		EnemyDefinition.AttackType.ARTILLERY:
			_shoot_artillery()
		EnemyDefinition.AttackType.WHIP_LASH:
			_shoot_whip_lash(dir)
		EnemyDefinition.AttackType.POISON_CLOUD:
			_shoot_poison_cloud()
		EnemyDefinition.AttackType.DASH_STRIKE:
			_shoot_dash_strike(dir)
		EnemyDefinition.AttackType.LANCE_THRUST:
			_shoot_lance_thrust(dir)
		EnemyDefinition.AttackType.SHIELD_WALL:
			_shoot_shield_wall(dir)
		EnemyDefinition.AttackType.CURSE_BOLT:
			_shoot_curse_bolt(dir)
		EnemyDefinition.AttackType.SUMMON_WALL:
			_shoot_summon_wall(dir)
		EnemyDefinition.AttackType.LEAPING_SLAM:
			_shoot_leaping_slam(dir)
		EnemyDefinition.AttackType.ARROW_VOLLEY:
			_shoot_arrow_volley()
		EnemyDefinition.AttackType.SWORD_SLASH:
			_shoot_sword_slash(dir)
		EnemyDefinition.AttackType.SPEAR_LUNGE:
			_shoot_spear_lunge(dir)
		EnemyDefinition.AttackType.CHARGE_BULL:
			_shoot_charge_bull(dir)
		EnemyDefinition.AttackType.CLEAVE_COMBO:
			_shoot_cleave_combo(dir)
		EnemyDefinition.AttackType.WHIRLWIND:
			_shoot_whirlwind(dir)
		EnemyDefinition.AttackType.GROUND_POUND:
			_shoot_ground_pound(dir)
		EnemyDefinition.AttackType.TAIL_WHIP:
			_shoot_tail_whip(dir)
		EnemyDefinition.AttackType.SHIELD_BASH:
			_shoot_melee_shield_bash(dir)
		EnemyDefinition.AttackType.GRAB_THROW:
			_shoot_grab_throw(dir)
		EnemyDefinition.AttackType.STOMP_WAVE:
			_shoot_stomp_wave(dir)

	# Bomb/heavy attacks get longer cooldowns — they're AOE so shouldn't spam
	var _bomb_attacks = [
		EnemyDefinition.AttackType.BOMB_TOSS, EnemyDefinition.AttackType.CARPET_BOMB,
		EnemyDefinition.AttackType.FIRE_RAIN, EnemyDefinition.AttackType.CLUSTER_BOMB,
		EnemyDefinition.AttackType.MINE_DROP, EnemyDefinition.AttackType.ARTILLERY,
		EnemyDefinition.AttackType.POISON_CLOUD, EnemyDefinition.AttackType.LEAPING_SLAM,
		EnemyDefinition.AttackType.ARROW_VOLLEY]
	if atk in _bomb_attacks:
		attack_timer = shoot_interval * 2.8  # bombs are AOE — keep them rare and readable
	else:
		attack_timer = shoot_interval * 0.25  # aggressive fire rate for bullet attacks
	cooldown_timer = 0.1
	state = State.COOLDOWN
	_active_modifier = null  # clear per-attack modifier after firing

func _fire_attack_type(atk: int, dir: Vector2) -> void:
	_obs_record_attack(atk, "combo")
	match atk:
		EnemyDefinition.AttackType.NONE, EnemyDefinition.AttackType.RANGED, \
		EnemyDefinition.AttackType.CHARGE, EnemyDefinition.AttackType.DASH, \
		EnemyDefinition.AttackType.POISON_SHOT, EnemyDefinition.AttackType.STEALTH, \
		EnemyDefinition.AttackType.SPLIT:
			_shoot_single(dir)
		EnemyDefinition.AttackType.MELEE:
			_shoot_single(dir)
		EnemyDefinition.AttackType.BURST:
			_shoot_ring(dir)
		EnemyDefinition.AttackType.SUMMON:
			_do_summon()
			_shoot_ring(dir)
		EnemyDefinition.AttackType.SLAM:
			_do_slam()
			_shoot_ring(dir)
		EnemyDefinition.AttackType.TELEPORT:
			_shoot_single(dir)
		EnemyDefinition.AttackType.SPIRAL, EnemyDefinition.AttackType.DEATH_SPIRAL:
			_shoot_spiral(dir)
		EnemyDefinition.AttackType.SHIELD:
			_shoot_shield_bash(dir)
		EnemyDefinition.AttackType.BEAM:
			_start_beam(dir)
			_shoot_single(dir)
		EnemyDefinition.AttackType.VOLLEY:
			_shoot_volley(dir)
		EnemyDefinition.AttackType.CROSS_SHOT:
			_shoot_cross(dir)
		EnemyDefinition.AttackType.WAVE_SHOT:
			_shoot_wave(dir)
		EnemyDefinition.AttackType.GATLING:
			_shoot_gatling(dir)
		EnemyDefinition.AttackType.MORTAR:
			_shoot_mortar(dir)
		EnemyDefinition.AttackType.NOVA:
			_shoot_nova(dir)
		EnemyDefinition.AttackType.ZIGZAG:
			_shoot_zigzag(dir)
		EnemyDefinition.AttackType.SHOTGUN_BLAST:
			_shoot_shotgun(dir)
		EnemyDefinition.AttackType.HELIX:
			_shoot_helix(dir)
		EnemyDefinition.AttackType.METEOR_SHOWER:
			_shoot_meteor_shower(dir)
		EnemyDefinition.AttackType.BOOMERANG_SHOT:
			_shoot_boomerang(dir)
		EnemyDefinition.AttackType.STRAFE_RUN:
			_shoot_strafe_run(dir)
		EnemyDefinition.AttackType.MINEFIELD:
			_shoot_minefield()
		EnemyDefinition.AttackType.RETURNING_VOLLEY:
			_shoot_returning(dir)
		EnemyDefinition.AttackType.SEEKING_MINES:
			_shoot_seeking_mines()
		EnemyDefinition.AttackType.DETONATOR:
			_shoot_detonator(dir)
		EnemyDefinition.AttackType.SPLITTER:
			_shoot_splitter(dir)
		EnemyDefinition.AttackType.SINE_BARRAGE:
			_shoot_sine_barrage(dir)
		EnemyDefinition.AttackType.HOMING_SALVO:
			_shoot_homing_salvo(dir)
		EnemyDefinition.AttackType.TELEGRAPH_EXPLOSION:
			_shoot_telegraph_explosion()
		EnemyDefinition.AttackType.ORBIT_LAUNCH:
			_shoot_orbit_launch(dir)
		EnemyDefinition.AttackType.WALL_BOUNCE:
			_shoot_wall_bounce(dir)
		EnemyDefinition.AttackType.LASER_GRID:
			_shoot_laser_grid(dir)
		EnemyDefinition.AttackType.GRAVITY_WELL:
			_shoot_gravity_well(dir)
		EnemyDefinition.AttackType.CHAIN_LIGHTNING:
			_shoot_chain_lightning(dir)
		EnemyDefinition.AttackType.BOMB_TOSS:
			_shoot_bomb_toss()
		EnemyDefinition.AttackType.CARPET_BOMB:
			_shoot_carpet_bomb(dir)
		EnemyDefinition.AttackType.FIRE_RAIN:
			_shoot_fire_rain()
		EnemyDefinition.AttackType.CLUSTER_BOMB:
			_shoot_cluster_bomb()
		EnemyDefinition.AttackType.MINE_DROP:
			_shoot_mine_drop()
		EnemyDefinition.AttackType.BARRIER_WALL:
			_shoot_barrier_wall(dir)
		EnemyDefinition.AttackType.PULL_SHOT:
			_shoot_pull_shot(dir)
		EnemyDefinition.AttackType.PUSH_WAVE:
			_shoot_push_wave(dir)
		EnemyDefinition.AttackType.VORTEX:
			_shoot_vortex(dir)
		EnemyDefinition.AttackType.RING_PULSE:
			_shoot_ring_pulse(dir)
		EnemyDefinition.AttackType.ARTILLERY:
			_shoot_artillery()
		EnemyDefinition.AttackType.WHIP_LASH:
			_shoot_whip_lash(dir)
		EnemyDefinition.AttackType.POISON_CLOUD:
			_shoot_poison_cloud()
		EnemyDefinition.AttackType.DASH_STRIKE:
			_shoot_dash_strike(dir)
		EnemyDefinition.AttackType.LANCE_THRUST:
			_shoot_lance_thrust(dir)
		EnemyDefinition.AttackType.SHIELD_WALL:
			_shoot_shield_wall(dir)
		EnemyDefinition.AttackType.CURSE_BOLT:
			_shoot_curse_bolt(dir)
		EnemyDefinition.AttackType.SUMMON_WALL:
			_shoot_summon_wall(dir)
		EnemyDefinition.AttackType.LEAPING_SLAM:
			_shoot_leaping_slam(dir)
		EnemyDefinition.AttackType.ARROW_VOLLEY:
			_shoot_arrow_volley()
		EnemyDefinition.AttackType.SWORD_SLASH:
			_shoot_sword_slash(dir)
		EnemyDefinition.AttackType.SPEAR_LUNGE:
			_shoot_spear_lunge(dir)
		EnemyDefinition.AttackType.CHARGE_BULL:
			_shoot_charge_bull(dir)
		EnemyDefinition.AttackType.CLEAVE_COMBO:
			_shoot_cleave_combo(dir)
		EnemyDefinition.AttackType.WHIRLWIND:
			_shoot_whirlwind(dir)
		EnemyDefinition.AttackType.GROUND_POUND:
			_shoot_ground_pound(dir)
		EnemyDefinition.AttackType.TAIL_WHIP:
			_shoot_tail_whip(dir)
		EnemyDefinition.AttackType.SHIELD_BASH:
			_shoot_melee_shield_bash(dir)
		EnemyDefinition.AttackType.GRAB_THROW:
			_shoot_grab_throw(dir)
		EnemyDefinition.AttackType.STOMP_WAVE:
			_shoot_stomp_wave(dir)

func _do_boss_combo_attack(dir: Vector2) -> void:
	var is_boss: bool = definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS
	velocity = Vector2.ZERO

	# Fire multiple attacks from the pool simultaneously
	# Elites (phase 2+): fire 2 pool attacks
	# Bosses (phase 2): fire 2 pool attacks + nova
	# Bosses (phase 3): fire all 3 pool attacks
	# Enraged: fire all pool attacks + nova
	var combo_count = 2
	if is_boss:
		if _current_phase >= 3:
			combo_count = _attack_pool.size()  # all 3
		if _enraged:
			combo_count = _attack_pool.size()  # all attacks when enraged
	var fired_any_heavy_bomb := false
	var fired_count := 0
	var attempts := 0
	var max_attempts := maxi(_attack_pool.size() * 2, combo_count)
	while fired_count < mini(combo_count, _attack_pool.size()) and attempts < max_attempts:
		attempts += 1
		var atk := _next_pool_attack()
		if _is_heavy_bomb_attack(atk):
			if fired_any_heavy_bomb:
				continue
			fired_any_heavy_bomb = true
		_fire_attack_type(atk, dir)
		fired_count += 1

	# Bosses add a nova on top only when the combo was not already a heavy bomb burst.
	if is_boss and (_current_phase >= 2 or _enraged) and not fired_any_heavy_bomb:
		_shoot_nova(dir)

func _check_contact_damage(force_contact: bool = false) -> void:
	if state == State.DEAD or not is_instance_valid(player):
		return
	if not force_contact:
		var dist = global_position.distance_to(player.global_position)
		var in_ow = is_inside_tree() and get_tree().current_scene and get_tree().current_scene.name == "Overworld"
		var contact_range = 12.0 * scale.x * (4.0 if in_ow else 1.0)
		if dist > contact_range:
			return
	# Player dashing — invincible, no contact damage
	if "_is_dashing" in player and player._is_dashing:
		return

	_contact_cooldown = 0.4  # ticks ~2.5x per second on contact
	var sfx_ct = get_node_or_null("/root/SFXManager")
	if sfx_ct:
		sfx_ct.play("impact_b", -5.0, 0.15)

	# Calculate momentum-based damage
	var my_speed = velocity.length()
	var player_speed = player.velocity.length()
	var relative_speed = (velocity - player.velocity).length()

	# Base contact damage from definition (prefer contact_damage, fall back to attack_damage)
	var base_dmg := 1
	if definition:
		if definition.contact_damage > 0:
			base_dmg = definition.contact_damage
		elif definition.attack_damage > 0:
			base_dmg = definition.attack_damage

	# Momentum bonus: faster collisions hurt more
	var momentum_mult = clampf(relative_speed / 40.0, 0.5, 3.0)
	var weight_mult = _weight

	# Enemy deals damage to player
	var player_dmg = int(ceil(base_dmg * momentum_mult * weight_mult))
	# WEAKENED/STRENGTHENED contact damage
	if has_meta("weakened") and get_meta("weakened"):
		player_dmg = maxi(1, int(player_dmg * 0.5))
	if has_meta("strengthened") and get_meta("strengthened"):
		player_dmg = int(ceil(player_dmg * 1.5))
	if player.has_method("take_damage"):
		if _is_boss_or_large:
			player.set_meta("_hit_from_elite", true)
		player.take_damage(maxi(player_dmg, 1), global_position, true, false)

	# Thorns: reflect damage to enemy on contact
	var thorns_em = player.get_node_or_null("EquipmentManager")
	if thorns_em:
		var thorns_dmg = int(thorns_em.get_thorns())
		if thorns_dmg > 0:
			take_damage(thorns_dmg)

	# push_dir points FROM enemy TO player (away from enemy, from player's view)
	var push_dir = (player.global_position - global_position).normalized()
	if push_dir == Vector2.ZERO:
		push_dir = Vector2.RIGHT.rotated(randf() * TAU)

	var is_heavy = definition and definition.size_class >= 1  # LARGE or BOSS
	# Push player AWAY from enemy (+push_dir = from enemy to player = away from enemy)
	if is_heavy:
		if definition.size_class >= 2:  # BOSS
			if player.has_method("apply_push"):
				player.apply_push(push_dir * 90.0 * weight_mult)
			else:
				player.velocity = push_dir * 90.0
		else:  # LARGE/elite
			if player.has_method("apply_push"):
				player.apply_push(push_dir * 55.0 * weight_mult)
			else:
				player.velocity = push_dir * 55.0
	else:
		# Check if movement makes this enemy unstoppable (swoop, bait punish, etc.)
		var _mt = definition.movement_pattern.move_type if definition and definition.movement_pattern else 0
		var _is_swooping = _mt == MovementPattern.MoveType.SWOOP and has_meta("swoop_state") and get_meta("swoop_state") == 1
		var _is_punishing = _mt == MovementPattern.MoveType.BAIT_PUNISH and has_meta("bp_state") and get_meta("bp_state") == 2
		var _is_intercepting = _mt == MovementPattern.MoveType.INTERCEPT and has_meta("ic_state") and get_meta("ic_state") == 1
		var _is_elastic_snap = _mt == MovementPattern.MoveType.ELASTIC and has_meta("el_state") and get_meta("el_state") != 0
		var _is_dash = _mt == MovementPattern.MoveType.DASH_IN_OUT and _dash_state == 1
		var _unstoppable = _is_swooping or _is_punishing or _is_intercepting or _is_elastic_snap or _is_dash

		# Normal enemies: mutual knockback
		var enemy_dmg = int(ceil(momentum_mult / weight_mult))
		if enemy_dmg > 0 and not _unstoppable:
			take_damage(enemy_dmg)

		var kb_resist = definition.knockback_resistance if definition else 0.0
		var kb_mult = 1.0 - clampf(kb_resist, 0.0, 1.0)

		if _unstoppable:
			if player.has_method("apply_push"):
				player.apply_push(push_dir * 80.0)
			elif player is CharacterBody2D:
				player.velocity = push_dir * 80.0
		else:
			# Enemy bounces AWAY from player (-push_dir = from player to enemy = away from player)
			velocity = -push_dir * 40.0 / weight_mult * kb_mult
			_pushed_velocity = -push_dir * 30.0 / weight_mult * kb_mult
			_knockback_timer = 0.1
			# Player gently pushed AWAY from enemy
			if player.has_method("apply_push"):
				player.apply_push(push_dir * 45.0 * weight_mult)
			elif player is CharacterBody2D:
				player.velocity = push_dir * 45.0 * weight_mult

	# Poise check: heavy enemies can stagger the player
	var stagger_power = weight_mult * momentum_mult
	if player.has_method("get_poise") and stagger_power > player.get_poise():
		if player.has_method("apply_stagger"):
			player.apply_stagger(2.0)

func _start_charge(dir: Vector2) -> void:
	charge_dir = dir
	charge_timer = definition.charge_duration if definition else 0.3
	attack_timer = shoot_interval
	state = State.CHARGING
	var sfx_chg = get_node_or_null("/root/SFXManager")
	if sfx_chg:
		sfx_chg.play("woosh_b", -6.0, 0.15)

const MAX_SUMMONED_ENEMIES: int = 15

func _do_summon() -> void:
	var enemy_scene = preload("res://scenes/enemy.tscn")
	var dm = get_node_or_null("/root/DungeonManager")
	var spawn_pos: Vector2 = global_position
	var gp = get_meta("grid_pos", Vector2i(-999, -999))
	var container = get_tree().get_first_node_in_group("enemies")
	if not container:
		container = get_parent()
	if not definition:
		return
	# Cap total enemies in the room to prevent flooding
	if container and container.get_child_count() >= MAX_SUMMONED_ENEMIES:
		return
	# Auto-create a weak minion if no summon_definition set
	if not definition.summon_definition:
		var minion_def := EnemyDefinition.new()
		minion_def.enemy_name = "Minion"
		minion_def.max_hp = maxi(1, definition.max_hp / 3)
		minion_def.move_speed = definition.move_speed * 1.2
		minion_def.attack_type = EnemyDefinition.AttackType.MELEE
		minion_def.attack_damage = maxi(1, definition.attack_damage)
		minion_def.attack_speed = 1.5
		minion_def.bullet_speed = 60.0
		minion_def.bullet_count = 1
		minion_def.kingdom = definition.kingdom
		minion_def.use_loy_sprite = definition.use_loy_sprite
		minion_def.loy_tile_index = definition.loy_tile_index
		minion_def.sprite_color = definition.sprite_color.darkened(0.3)
		minion_def.xp_value = 1
		minion_def.score_value = 2
		definition.summon_definition = minion_def
	var sfx_sum = get_node_or_null("/root/SFXManager")
	if sfx_sum:
		sfx_sum.play("summon", -4.0, 0.1)
	for i in range(definition.summon_count):
		var minion = enemy_scene.instantiate()
		minion.global_position = spawn_pos
		minion.setup(definition.summon_definition.duplicate())
		container.add_child(minion)
		# Register with room state
		if gp != Vector2i(-999, -999):
			minion.set_meta("grid_pos", gp)
			if dm and dm.room_states.has(gp):
				dm.room_states[gp]["alive"] += 1
				minion.tree_exited.connect(dm._on_enemy_died.bind(gp))

func _do_slam() -> void:
	var radius: int = 16
	var bodies: Array = []
	var tween = create_tween()
	if not is_inside_tree():
		return
	for body in bodies:
		if body.global_position.distance_to(global_position) < radius:
			if body.has_method("take_damage"):
				body.take_damage(definition.attack_damage if definition else 1, global_position)
	tween.tween_property($Sprite2D, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property($Sprite2D, "scale", Vector2(1, 1), 0.2)
	var sfx_slam = get_node_or_null("/root/SFXManager")
	if sfx_slam:
		sfx_slam.play("boom_a", -10.0, 0.1)
	var vfx_slam = get_node_or_null("/root/VFXManager")
	if vfx_slam:
		vfx_slam.shockwave(global_position, radius, Color(0.8, 0.4, 0.1, 0.5))
		vfx_slam.shake(2.0, 0.15)

func _do_teleport() -> void:
	var angle: float = 0.0
	var tween = create_tween()
	var dist: float = 0.0
	if not is_instance_valid(player):
		return
	var start_pos := global_position
	var sfx_tp = get_node_or_null("/root/SFXManager")
	if sfx_tp:
		sfx_tp.play("teleport", -4.0, 0.15)
	global_position = player.global_position + Vector2(cos(angle), sin(angle)) * dist
	$Sprite2D.modulate.a = 0.3
	tween.tween_property($Sprite2D, "modulate:a", 1.0, 0.3)
	var vfx_tp = get_node_or_null("/root/VFXManager")
	if vfx_tp:
		vfx_tp.warp_link(start_pos, global_position, Color(0.94, 0.16, 0.08, 0.94), 14.0, 20.0)

func _try_heal_nearby() -> void:
	var orig: Vector2 = global_position
	var enemies = get_tree().get_nodes_in_group("enemy")
	var tween = create_tween()
	var heal_amt = definition.heal_amount if definition else 2
	var heal_rng = definition.heal_range if definition else 48.0
	var sfx_heal = get_node_or_null("/root/SFXManager")
	if sfx_heal:
		sfx_heal.play("heal_b", -4.0, 0.1)
	for e in enemies:
		if e == self:
			continue
		if e.global_position.distance_to(global_position) < heal_rng:
			if e.has_method("heal"):
				e.heal(heal_amt)
	$Sprite2D.modulate = Color.GREEN
	tween.tween_property($Sprite2D, "modulate", orig, 0.3)

func heal(amount: int) -> void:
	var max_val = definition.max_hp if definition else hp + amount
	hp = mini(hp + amount, max_val)

func _maybe_leave_trail(delta: float) -> void:
	if not definition or not definition.leaves_trail:
		return
	_trail_timer -= delta
	if _trail_timer > 0:
		return
	_trail_timer = 0.5

	var hazard = HazardArea.new()
	hazard.collision_layer = 0
	hazard.collision_mask = 1
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(6, 6)
	shape.shape = rect
	hazard.add_child(shape)
	hazard.position = global_position
	hazard.interval = 0.5

	match definition.trail_type:
		"fire":
			hazard.damage = 1
			hazard.status_effect_type = StatusEffect.Type.BURNING
			hazard.status_duration = 2.0
			hazard.status_strength = 1.0
		"web":
			hazard.damage = 0
			hazard.status_effect_type = StatusEffect.Type.SLOWED
			hazard.status_duration = 2.0
			hazard.status_strength = 0.4
		"poison":
			hazard.damage = 1
			hazard.status_effect_type = StatusEffect.Type.POISONED
			hazard.status_duration = 3.0
			hazard.status_strength = 1.0

	# Auto-destroy after 5s
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	timer.timeout.connect(hazard.queue_free)
	hazard.add_child(timer)
	get_tree().current_scene.add_child(hazard)
	timer.start()

func _shoot_spiral(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var bc = bullets_container
	var count: int = _get_active_bullet_count()
	var angle: float = dir.angle() + _spiral_angle
	if not bullets_container:
		return
	if count <= 0:
		return
	if count < 4:
		count = 4
	# Fire 5 rapid volleys for a continuous spiral stream
	var volleys = 5
	for v in range(volleys):
		var volley_idx := v
		get_tree().create_timer(v * 0.12).timeout.connect(
			func():
				if not is_instance_valid(self) or hp <= 0:
					return
				if not bc:
					return
				for i in range(count):
					var shot_angle := angle + float(volley_idx) * 0.35 + TAU * float(i) / float(count)
					_spawn_bullet(bc, Vector2.from_angle(shot_angle), bspeed)
				_spiral_angle += 0.35
		)

func _enter_stealth() -> void:
	_stealth_timer = definition.stealth_duration if definition else 2.0
	$Sprite2D.modulate.a = 0.15
	state = State.STEALTHED
	# Reposition when going invisible — teleport to valid floor position
	global_position = _find_valid_floor_pos(_spawn_pos, 30.0, 70.0)
	var sfx_st = get_node_or_null("/root/SFXManager")
	if sfx_st:
		sfx_st.play("whistle", -6.0, 0.1)

func _start_beam(dir: Vector2) -> void:
	_beam_timer = definition.beam_duration if definition else 1.0
	_beam_angle = dir.angle()
	var sfx_beam = get_node_or_null("/root/SFXManager")
	if sfx_beam:
		sfx_beam.play("laser_a", -4.0, 0.1)

func _shoot_single(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var spread: float = 0.3
	var count: int = _get_active_bullet_count()
	if not bullets_container:
		return
	if count <= 0:
		return
	if count == 1:
		_spawn_bullet(bullets_container, dir, bspeed)
	else:
		# Always fire one bullet directly at the player, spread others around it
		_spawn_bullet(bullets_container, dir, bspeed)  # center shot aimed at player
		for i in range(1, count):
			var angle_offset = (float(i) / count - 0.5) * spread * 2
			_spawn_bullet(bullets_container, dir.rotated(angle_offset), bspeed)

func _shoot_ring(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var count: int = _get_active_bullet_count()
	if not bullets_container:
		return
	if count <= 0:
		return
	if count < 4:
		count = 8
	for i in range(count):
		var angle: float = dir.angle() + TAU * float(i) / float(count)
		_spawn_bullet(bullets_container, Vector2.from_angle(angle), bspeed)

func _apply_attack_modifier(b) -> void:
	var m = _active_modifier if _active_modifier != null else (definition.attack_modifier if definition else null)
	if not m:
		return
	# Homing — apply to any bullet that isn't already using a special behavior
	if m.homing_strength > 0 and b.behavior in [b.BulletBehavior.NORMAL, 0]:
		b.behavior = b.BulletBehavior.HOMING_ENEMY
		# Scale: 0.3 = gentle (1.5), 0.5 = moderate (2.5), 1.0 = aggressive (5.0)
		b.homing_strength = m.homing_strength * 5.0
	# Bounce
	if m.bounce_count > 0:
		b.bounce_count += m.bounce_count
	# Pierce
	if m.pierce_count > 0:
		b.pierce_count += m.pierce_count
	# Speed
	if m.speed_mult != 1.0 and b.speed > 0:
		b.speed *= m.speed_mult
	# Split — only if bullet isn't already homing (homing + split conflicts)
	if m.split_after > 0 and b.behavior != b.BulletBehavior.HOMING_ENEMY:
		b.behavior = b.BulletBehavior.SPLITTING
		b.set_meta("split_time", m.split_after)
		b.set_meta("split_count", m.split_count)
	# Status effects — use apply_status/status_duration metas (enemy bullet → player path)
	if m.apply_burning:
		b.set_meta("apply_status", "BURNING")
		b.set_meta("status_duration", 3.0)
	elif m.apply_slowed:
		b.set_meta("apply_status", "SLOWED")
		b.set_meta("status_duration", 2.0)
	elif m.apply_poisoned:
		b.poison_on_hit = true
	elif m.apply_stunned:
		b.set_meta("apply_status", "STUNNED")
		b.set_meta("status_duration", 1.5)
	# AoE — fireball_aoe only works for player bullets; for enemy bullets use lobbed bomb system instead
	# (enemy AoE is handled via LOBBED behavior and bomb attacks, not this modifier)

func _fire_boss_shot_pattern(dir: Vector2, pattern: BossShotPattern) -> void:
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if bullets_container == null or pattern == null:
		return
	var bursts = maxi(pattern.burst_count, 1)
	for burst_idx in range(bursts):
		var delay = float(burst_idx) * maxf(pattern.burst_interval, 0.0)
		if delay <= 0.0:
			_fire_boss_shot_burst(bullets_container, dir, pattern, burst_idx)
		else:
			var bc = bullets_container
			get_tree().create_timer(delay).timeout.connect(
				func():
					if is_instance_valid(self) and hp > 0 and bc:
						_fire_boss_shot_burst(bc, dir, pattern, burst_idx)
			)

func _fire_boss_shot_burst(container: Node, dir: Vector2, pattern: BossShotPattern, burst_idx: int) -> void:
	var shot_count = maxi(pattern.shot_count, 1)
	var base_angle = dir.angle()
	match pattern.aim_mode:
		BossShotPattern.AimMode.FIXED_ANGLE:
			base_angle = deg_to_rad(pattern.fixed_angle_degrees)
		BossShotPattern.AimMode.SPINNING:
			base_angle = _boss_spin_angle
		_:
			base_angle = dir.angle()
	base_angle += deg_to_rad(pattern.base_angle_offset_degrees + pattern.rotate_per_burst_degrees * float(burst_idx))

	if pattern.pattern_family != BossShotPattern.PatternFamily.BASIC:
		_fire_boss_math_pattern(container, base_angle, pattern, burst_idx)
		return

	if pattern.ring_pattern:
		for i in range(shot_count):
			var angle = base_angle + TAU * float(i) / float(shot_count)
			_spawn_boss_pattern_bullet(container, Vector2.from_angle(angle), pattern)
		return

	if shot_count == 1:
		_spawn_boss_pattern_bullet(container, Vector2.from_angle(base_angle), pattern)
		return

	var spread_rad = deg_to_rad(pattern.spread_degrees)
	var start_angle = base_angle - spread_rad * 0.5 if pattern.symmetric_spread else base_angle
	var step = spread_rad / float(maxi(shot_count - 1, 1))
	for i in range(shot_count):
		var angle = start_angle + step * float(i)
		_spawn_boss_pattern_bullet(container, Vector2.from_angle(angle), pattern)

func _fire_boss_math_pattern(container: Node, base_angle: float, pattern: BossShotPattern, burst_idx: int) -> void:
	var shot_count = maxi(pattern.shot_count, 1)
	var rng = _make_pattern_rng(pattern, burst_idx)
	var angle_jitter = deg_to_rad(pattern.angle_jitter_degrees)
	match pattern.pattern_family:
		BossShotPattern.PatternFamily.ROSE:
			var amp = deg_to_rad(_vary_param(pattern.spread_degrees if pattern.spread_degrees > 0.0 else 70.0, pattern.param_jitter, rng))
			var petals = maxi(int(round(_vary_param(float(maxi(pattern.rose_petals, 1)), pattern.param_jitter, rng))), 1)
			for i in range(shot_count):
				var t = TAU * (float(i) / float(shot_count)) + float(burst_idx) * 0.15
				var angle = base_angle + sin(t * float(petals)) * amp + _rand_signed(rng) * angle_jitter
				_spawn_boss_pattern_bullet(container, Vector2.from_angle(angle), pattern)
		BossShotPattern.PatternFamily.LISSAJOUS:
			var delta = deg_to_rad(_vary_param(pattern.lissajous_delta_degrees, pattern.param_jitter, rng))
			var a = _vary_param(pattern.lissajous_a, pattern.param_jitter, rng)
			var b = _vary_param(pattern.lissajous_b, pattern.param_jitter, rng)
			for i in range(shot_count):
				var t = TAU * (float(i) / float(shot_count)) + float(burst_idx) * 0.12
				var p = Vector2(sin(a * t + delta), sin(b * t))
				if p.length() < 0.01:
					continue
				var dir = p.normalized().rotated(_rand_signed(rng) * angle_jitter)
				_spawn_boss_pattern_bullet(container, dir, pattern)
		BossShotPattern.PatternFamily.CYCLOID:
			var ratio = maxf(_vary_param(pattern.cycloid_ratio, pattern.param_jitter, rng), 1.1)
			var r = 1.0 / ratio
			for i in range(shot_count):
				var t = TAU * (float(i) / float(shot_count)) + float(burst_idx) * 0.1
				var p: Vector2
				if pattern.cycloid_inner:
					p = Vector2((1.0 - r) * cos(t) + r * cos(((1.0 - r) / r) * t), (1.0 - r) * sin(t) - r * sin(((1.0 - r) / r) * t))
				else:
					p = Vector2((1.0 + r) * cos(t) - r * cos(((1.0 + r) / r) * t), (1.0 + r) * sin(t) - r * sin(((1.0 + r) / r) * t))
				if p.length() < 0.01:
					continue
				var dir = p.normalized().rotated(base_angle + _rand_signed(rng) * angle_jitter)
				_spawn_boss_pattern_bullet(container, dir, pattern)
		BossShotPattern.PatternFamily.LOG_SPIRAL:
			var step_angle = deg_to_rad(_vary_param(pattern.spread_degrees if pattern.spread_degrees > 0.0 else 22.0, pattern.param_jitter, rng))
			var growth = _vary_param(pattern.logarithmic_growth, pattern.param_jitter, rng)
			for i in range(shot_count):
				var theta = float(i) * step_angle + float(burst_idx) * deg_to_rad(pattern.rotate_per_burst_degrees)
				var radius_scale = exp(growth * theta)
				var dir = Vector2.from_angle(base_angle + theta + _rand_signed(rng) * angle_jitter)
				var pos = global_position + dir * minf(radius_scale * 2.0, 18.0)
				_spawn_boss_pattern_bullet_at(container, pos, dir, pattern)
		BossShotPattern.PatternFamily.FRACTAL_FAN:
			_emit_recursive_fan(container, base_angle, pattern, maxi(pattern.recursive_depth, 1), 1.0, true, rng)
		BossShotPattern.PatternFamily.RECURSIVE_FAN:
			_emit_recursive_fan(container, base_angle, pattern, maxi(pattern.recursive_depth, 1), 1.0, false, rng)
		_:
			_spawn_boss_pattern_bullet(container, Vector2.from_angle(base_angle), pattern)

func _emit_recursive_fan(container: Node, base_angle: float, pattern: BossShotPattern, depth: int, scale_mult: float, mirrored: bool, rng: RandomNumberGenerator) -> void:
	var emit_angle = base_angle + _rand_signed(rng) * deg_to_rad(pattern.angle_jitter_degrees)
	_spawn_boss_pattern_bullet(container, Vector2.from_angle(emit_angle), pattern)
	if depth <= 0:
		return
	var branch_angle = deg_to_rad(_vary_param(pattern.recursive_branch_angle_degrees, pattern.param_jitter, rng)) * scale_mult
	var next_scale = scale_mult * _vary_param(pattern.recursive_branch_scale, pattern.recursive_spawn_scale_jitter, rng)
	_emit_recursive_fan(container, base_angle + branch_angle, pattern, depth - 1, next_scale, mirrored, rng)
	if mirrored:
		_emit_recursive_fan(container, base_angle - branch_angle, pattern, depth - 1, next_scale, mirrored, rng)

func _make_pattern_rng(pattern: BossShotPattern, burst_idx: int) -> RandomNumberGenerator:
	var rng = RandomNumberGenerator.new()
	if pattern.use_seed_variation:
		rng.seed = int(pattern.seed_value + burst_idx * pattern.seed_step_per_burst)
	else:
		rng.randomize()
	return rng

func _vary_param(base_value: float, jitter: float, rng: RandomNumberGenerator) -> float:
	if jitter <= 0.0:
		return base_value
	return base_value * (1.0 + _rand_signed(rng) * jitter)

func _rand_signed(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(-1.0, 1.0)

func _spawn_boss_pattern_bullet(container: Node, shot_dir: Vector2, pattern: BossShotPattern) -> void:
	_spawn_boss_pattern_bullet_at(container, global_position, shot_dir, pattern)

func _spawn_boss_pattern_bullet_at(container: Node, spawn_pos: Vector2, shot_dir: Vector2, pattern: BossShotPattern) -> void:
	var bspeed = (definition.bullet_speed if definition else 60.0) * pattern.bullet_speed_mult
	var previous_modifier = _active_modifier
	if pattern.modifier_override != null:
		_active_modifier = pattern.modifier_override
	var bullet: Area2D = null
	if spawn_pos == global_position:
		bullet = _spawn_bullet(container, shot_dir, bspeed)
	else:
		bullet = bullet_scene.instantiate()
		bullet.global_position = spawn_pos
		bullet.direction = shot_dir
		_apply_enemy_bullet_props(bullet, bspeed)
		container.add_child(bullet)
	_active_modifier = previous_modifier
	if bullet == null:
		return
	if pattern.bullet_behavior_override >= 0:
		bullet.behavior = pattern.bullet_behavior_override
	if pattern.damage_override >= 0:
		bullet.damage = pattern.damage_override
	if pattern.sprite_scale_mult != 1.0:
		bullet.set_meta("sprite_scale_mult", pattern.sprite_scale_mult)
		var bullet_sprite = bullet.get_node_or_null("Sprite2D")
		if bullet_sprite and bullet_sprite is Sprite2D:
			bullet_sprite.scale *= pattern.sprite_scale_mult
		var bullet_hit_shape = bullet.get_node_or_null("CollisionShape2D")
		if bullet_hit_shape and bullet_hit_shape is CollisionShape2D:
			bullet_hit_shape.scale *= pattern.sprite_scale_mult
	if pattern.movement_pattern != null:
		bullet.movement_pattern = pattern.movement_pattern
		bullet.movement_anchor_entity = self
		bullet.movement_anchor_point = global_position
		bullet._movement_orbit_angle = shot_dir.angle()
		bullet._movement_orbit_radius = pattern.orbit_radius_override if pattern.orbit_radius_override >= 0.0 else pattern.movement_pattern.orbit_radius
		bullet._movement_orbit_radial_speed = pattern.orbit_radial_speed
		bullet._movement_orbit_radial_accel = pattern.orbit_radial_accel
		bullet._movement_orbit_reverse_time = pattern.orbit_reverse_time
		bullet._movement_orbit_reversed = false
	if pattern.bounce_count_override >= 0:
		bullet.bounce_count = pattern.bounce_count_override
	if pattern.status_effect != "":
		bullet.set_meta("apply_status", pattern.status_effect)
		bullet.set_meta("status_duration", pattern.status_duration)

func _apply_enemy_bullet_props(bullet, spd: float) -> void:
	bullet.is_player_bullet = false
	bullet.speed = spd
	if definition:
		var base_dmg: int = definition.attack_damage
		# WEAKENED — deal 50% less damage
		if has_meta("weakened") and get_meta("weakened"):
			base_dmg = maxi(1, int(base_dmg * 0.5))
		# STRENGTHENED — deal 50% more damage
		if has_meta("strengthened") and get_meta("strengthened"):
			base_dmg = int(ceil(base_dmg * 1.5))
		bullet.damage = base_dmg
		bullet.enemy_kingdom = definition.kingdom
		if _is_boss_or_large:
			bullet.set_meta("from_elite", true)
		if definition.bullet_sprite_index >= 0:
			bullet.bullet_sprite_index = definition.bullet_sprite_index
		# Poison bullets for POISON_SHOT enemies
		if definition.poison_chance > 0 and randf() < definition.poison_chance:
			bullet.poison_on_hit = true
			bullet.bullet_sprite_index = 161  # green venom sprite
		# Generic status effect on bullet hit (e.g. SLOWED for frost archers)
		if definition.bullet_status_effect != "":
			bullet.set_meta("apply_status", definition.bullet_status_effect)
			bullet.set_meta("status_duration", definition.bullet_status_duration)
			# Apply attack modifier (composable bullet properties)
		_apply_attack_modifier(bullet)

var _last_fire_sfx_frame: int = 0

func _spawn_bullet(container: Node, dir: Vector2, spd: float) -> Area2D:
	var bullet = bullet_scene.instantiate()
	var sfx = get_node_or_null("/root/SFXManager")
	bullet.global_position = global_position
	bullet.direction = dir
	_apply_enemy_bullet_props(bullet, spd)
	container.add_child(bullet)
	_obs_record_projectile(bullet, {
		"speed": bullet.speed,
		"damage": bullet.damage,
		"direction": bullet.direction,
		"behavior": int(bullet.behavior),
		"lifetime": bullet.lifetime,
	})
	# SFX: enemy fire (rate-limited to avoid spam from multi-bullet patterns)
	var frame = Engine.get_physics_frames()
	if frame != _last_fire_sfx_frame:
		_last_fire_sfx_frame = frame
		if sfx:
			sfx.play("fire_a", -10.0, 0.2)
	_coop_broadcast_enemy_bullet(bullet)
	return bullet

func _spawn_bullet_at(container: Node, pos: Vector2, dir: Vector2, spd: float) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.global_position = pos
	bullet.direction = dir
	_apply_enemy_bullet_props(bullet, spd)
	container.add_child(bullet)
	_obs_record_projectile(bullet, {
		"speed": bullet.speed,
		"damage": bullet.damage,
		"direction": bullet.direction,
		"behavior": int(bullet.behavior),
		"lifetime": bullet.lifetime,
	})
	_coop_broadcast_enemy_bullet(bullet)

func _spawn_behavior_bullet(container: Node, dir: Vector2, spd: float, bhv: int) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = dir
	bullet.behavior = bhv
	bullet._origin_pos = global_position
	bullet._origin_entity = self
	_apply_enemy_bullet_props(bullet, spd)
	container.add_child(bullet)
	_obs_record_projectile(bullet, {
		"speed": bullet.speed,
		"damage": bullet.damage,
		"direction": bullet.direction,
		"behavior": int(bullet.behavior),
		"lifetime": bullet.lifetime,
		"stationary_ok": bhv in [bullet.BulletBehavior.BARRIER, bullet.BulletBehavior.LOBBED],
	})

func _finalize_direct_enemy_bullet(container: Node, bullet: Node, stationary_ok: bool = false) -> void:
	container.add_child(bullet)
	_obs_record_projectile(bullet, {
		"speed": bullet.speed,
		"damage": bullet.damage,
		"direction": bullet.direction,
		"behavior": int(bullet.behavior),
		"lifetime": bullet.lifetime,
		"stationary_ok": stationary_ok,
	})
	_coop_broadcast_enemy_bullet(bullet)

## SHIELD_BASH: Spawns a frontal barrier arc then charges at player
func _shoot_shield_bash(dir: Vector2) -> void:
	var bc = get_tree().get_first_node_in_group("bullets")
	var sfx_sh = get_node_or_null("/root/SFXManager")
	var center: Vector2 = global_position
	if sfx_sh:
		sfx_sh.play("spell_a", -13.0, 0.18)
	if not bc:
		return
	# Spawn a 3-segment barrier arc in front of the enemy
	var perp := Vector2(-dir.y, dir.x)
	for i in range(3):
		var b = bullet_scene.instantiate()
		var lateral := (float(i) - 1.0) * 8.0
		b.global_position = center + dir * 12.0 + perp * lateral
		b.direction = Vector2.ZERO
		b.behavior = b.BulletBehavior.BARRIER
		b.barrier_hp = shield_hp if shield_hp > 0 else 3
		b.lifetime = 3.0
		_apply_enemy_bullet_props(b, 0.0)
		bc.add_child(b)
	# Also shoot at player through the shield
	_shoot_single(dir)
	# Brief charge forward
	charge_dir = dir
	charge_timer = 0.25
	state = State.CHARGING

## VOLLEY: Lobs a spread of small bombs toward the player area — area denial
func _shoot_volley(_dir: Vector2) -> void:
	var bc = get_tree().get_first_node_in_group("bullets")
	var count: int = _get_active_bullet_count()
	var target: Vector2 = player.global_position if is_instance_valid(player) else global_position
	var bcc = get_tree().get_first_node_in_group("bullets")
	if not is_instance_valid(player):
		return
	var sfx_v = get_node_or_null("/root/SFXManager")
	if sfx_v:
		sfx_v.play("shoot_b", -6.0, 0.1)
	if not bc:
		return
	var target_center: Vector2 = player.global_position
	# Scatter lobbed shots in a pattern around the player
	for i in range(count):
		var target_offset := Vector2.from_angle(TAU * float(i) / maxf(float(count), 1.0)) * randf_range(0.0, 18.0)
		var shot_target := target_center + target_offset
		get_tree().create_timer(i * 0.1).timeout.connect(
			func():
				if is_instance_valid(self) and hp > 0:
					if bcc:
						_spawn_lob_at(bcc, shot_target, ObjSpriteIndex.FIREBALL, 8.0, 0.5, 4, 0)
		)

## CROSS_SHOT: Fires + pattern, then delayed X pattern — two interlocked crosses
func _shoot_cross(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var arm_dir: Vector2 = Vector2.RIGHT
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var bc = get_tree().get_first_node_in_group("bullets")
	var sfx_cr = get_node_or_null("/root/SFXManager")
	if sfx_cr:
		sfx_cr.play("fire_b", -6.0, 0.1)
	if not bullets_container:
		return
	# First cross: cardinal directions (+ shape)
	for arm in range(4):
		var shot_dir := arm_dir.rotated(float(arm) * PI * 0.5)
		_spawn_bullet(bullets_container, shot_dir, bspeed)
		_spawn_bullet(bullets_container, shot_dir, bspeed * 0.6)
	# Delayed second cross: diagonal (X shape)
	get_tree().create_timer(0.3).timeout.connect(
		func():
			if not is_instance_valid(self) or hp <= 0:
				return
			if not bc:
				return
			if sfx_cr:
				sfx_cr.play("fire_b", -8.0, 0.1)
			for arm in range(4):
				var shot_dir := arm_dir.rotated(PI * 0.25 + float(arm) * PI * 0.5)
				_spawn_bullet(bc, shot_dir, bspeed * 0.9)
				_spawn_bullet(bc, shot_dir, bspeed * 0.5)
	)

## WAVE_SHOT: Sine-wave spread — bullets fan out then converge in a wave pattern
func _shoot_wave(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var count: int = _get_active_bullet_count()
	var spawn_pos: Vector2 = global_position
	var t: float = Time.get_ticks_msec() / 1000.0
	var sfx_wv = get_node_or_null("/root/SFXManager")
	if sfx_wv:
		sfx_wv.play("spell_a", -7.0, 0.15)
	if not bullets_container:
		return
	for i in range(count):
		var offset_angle := sin(t * PI * 2.0 + float(i) * 0.7) * 0.35
		var lateral := Vector2(-dir.y, dir.x) * (float(i) - float(count - 1) * 0.5) * 3.0
		_spawn_bullet_at(bullets_container, spawn_pos + lateral, dir.rotated(offset_angle), bspeed)

## GATLING: Long burst of fast bullets tracking the player — machine gun
func _shoot_gatling(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var bc = bullets_container
	var count: int = _get_active_bullet_count()
	var sfx_gt = get_node_or_null("/root/SFXManager")
	if sfx_gt:
		sfx_gt.play("blaster", -6.0, 0.1)
	if not bullets_container:
		return
	for i in range(count):
		var shot_jitter := randf_range(-0.08, 0.08)
		get_tree().create_timer(i * 0.05).timeout.connect(
			func():
				if not is_instance_valid(self) or hp <= 0:
					return
				if not bc:
					return
				# Re-aim at player each shot for tracking stream
				var aim := dir
				if is_instance_valid(player):
					aim = (player.global_position - global_position).normalized()
				_spawn_bullet(bc, aim.rotated(shot_jitter), bspeed)
		)

## MORTAR: Lobs bombs in high arc toward player area — artillery barrage
func _shoot_mortar(_dir: Vector2) -> void:
	var bc = get_tree().get_first_node_in_group("bullets")
	var radius: int = 16
	var flight: float = 0.3
	var count: int = _get_active_bullet_count()
	var target: Vector2 = player.global_position if is_instance_valid(player) else global_position
	var bcc = get_tree().get_first_node_in_group("bullets")
	if not is_instance_valid(player):
		return
	var sfx_mt = get_node_or_null("/root/SFXManager")
	if sfx_mt:
		sfx_mt.play("bazooka", -6.0, 0.12)
	if not bc:
		return
	for i in range(count):
		var target_offset := Vector2.from_angle(TAU * float(i) / maxf(float(count), 1.0)) * randf_range(0.0, 20.0)
		var shot_target := target + target_offset
		get_tree().create_timer(i * 0.3).timeout.connect(
			func():
				if is_instance_valid(self) and hp > 0:
					if bcc:
						_spawn_lob_at(bcc, shot_target, ObjSpriteIndex.FIREBALL, radius, flight, 8, 0)
		)

## NOVA: Double ring burst — inner ring fast, outer ring slow with offset
func _shoot_nova(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bc: Node = get_tree().get_first_node_in_group("bullets")
	var bullets_container: Node = get_tree().get_first_node_in_group("bullets")
	var count: int = _get_active_bullet_count()
	# (Dead "var angle: float = 0.0" removed — it was never read here and
	# was shadowed in the deferred lambda below.)
	var sfx_nv = get_node_or_null("/root/SFXManager")
	if sfx_nv:
		sfx_nv.play("area_effect_b", -5.0, 0.08)
	if not bullets_container:
		return
	var base_angle: float = dir.angle()
	# Inner ring: fast, one bullet aimed at player
	var inner: int = maxi(count / 2, 4)
	for i in range(inner):
		var shot_angle: float = base_angle + TAU * float(i) / float(inner)
		_spawn_bullet(bullets_container, Vector2.from_angle(shot_angle), bspeed * 1.5)
	# Outer ring: slow, offset by half step, delayed
	get_tree().create_timer(0.15).timeout.connect(
		func():
			if is_instance_valid(self) and hp > 0:
				if bc:
					var outer: int = count
					var half_step: float = TAU / float(outer) / 2.0
					for j in range(outer):
						var shot_angle: float = base_angle + half_step + TAU * float(j) / float(outer)
						_spawn_bullet(bc, Vector2.from_angle(shot_angle), bspeed * 0.6)
	)

## ZIGZAG: Alternating left-right angled shots for a weaving bullet wall
func _shoot_zigzag(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bc = get_tree().get_first_node_in_group("bullets")
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var count: int = _get_active_bullet_count()
	var sfx_zz = get_node_or_null("/root/SFXManager")
	if sfx_zz:
		sfx_zz.play("woosh_b", -7.0, 0.12)
	if not bullets_container:
		return
	var zigzag_angle = 0.35
	for i in range(count):
		var shot_dir := dir.rotated(zigzag_angle if i % 2 == 0 else -zigzag_angle)
		get_tree().create_timer(i * 0.06).timeout.connect(
			func():
				if is_instance_valid(self) and hp > 0:
					if bc:
						_spawn_bullet(bc, shot_dir, bspeed)
		)

## SHOTGUN_BLAST: Very wide cone, short-lived bullets — close-range devastation
func _shoot_shotgun(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bc = get_tree().get_first_node_in_group("bullets")
	var count: int = _get_active_bullet_count()
	var sfx_sg = get_node_or_null("/root/SFXManager")
	if sfx_sg:
		sfx_sg.play("shotgun", -5.0, 0.1)
	if not bc:
		return
	var cone = 1.2  # very wide cone
	for i in range(count):
		var b = bullet_scene.instantiate()
		var spd = bspeed * randf_range(0.7, 1.3)
		var t := float(i) / maxf(float(count - 1), 1.0)
		var angle := lerpf(-cone * 0.5, cone * 0.5, t)
		b.global_position = global_position
		b.direction = dir.rotated(angle)
		b.lifetime = 0.6  # short range — dies quickly
		_apply_enemy_bullet_props(b, spd)
		bc.add_child(b)

## HELIX: Two intertwined spiraling bullet streams — continuous double helix
var _helix_angle: float = 0.0
func _shoot_helix(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bc = get_tree().get_first_node_in_group("bullets")
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var spawn_pos: Vector2 = global_position
	var sfx_hx = get_node_or_null("/root/SFXManager")
	if sfx_hx:
		sfx_hx.play("spell_b", -7.0, 0.15)
	if not bullets_container:
		return
	# Fire 4 rapid pairs for a visible helix pattern
	for v in range(4):
		get_tree().create_timer(v * 0.1).timeout.connect(
			func():
				if not is_instance_valid(self) or hp <= 0:
					return
				if not bc:
					return
				for stream in range(2):
					var offset = _helix_angle + float(v) * 0.45 + float(stream) * PI
					var bullet_dir = dir.rotated(sin(offset) * 0.7)
					_spawn_bullet_at(bc, spawn_pos, bullet_dir, bspeed)
		)
	_helix_angle += 2.4

## METEOR_SHOWER: Rains large lobbed meteors across the area — chaos from above
func _shoot_meteor_shower(_dir: Vector2) -> void:
	var bc = get_tree().get_first_node_in_group("bullets")
	var count: int = _get_active_bullet_count()
	var target: Vector2 = player.global_position if is_instance_valid(player) else global_position
	var bcc = get_tree().get_first_node_in_group("bullets")
	if not is_instance_valid(player):
		return
	var sfx_ms = get_node_or_null("/root/SFXManager")
	if sfx_ms:
		sfx_ms.play("scatter", -5.0, 0.1)
	if not bc:
		return
	# Rain meteors in random spots near player
	for i in range(count):
		get_tree().create_timer(i * 0.25).timeout.connect(
			func():
				if is_instance_valid(self) and hp > 0:
					if bcc:
						_spawn_lob_at(bcc, target, ObjSpriteIndex.FIREBALL, 14.0, 0.7, 6, 0)
		)

## BOOMERANG_SHOT: Fires bullets that arc out and curve back toward the enemy
func _shoot_boomerang(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var spread: float = 0.3
	var count: int = _get_active_bullet_count()
	var t: float = Time.get_ticks_msec() / 1000.0
	var sfx_bm = get_node_or_null("/root/SFXManager")
	if sfx_bm:
		sfx_bm.play("woosh_b", -6.0, 0.12)
	if not bullets_container:
		return
	for i in range(count):
		var b = bullet_scene.instantiate()
		var offset := (float(i) - float(count - 1) * 0.5) * spread
		b.global_position = global_position
		b.direction = dir.rotated(offset + sin(t + float(i)) * 0.08)
		b.is_player_bullet = false
		b.speed = bspeed
		b.behavior = b.BulletBehavior.BOOMERANG
		b._origin_pos = global_position
		b._origin_entity = self
		b._max_travel = randf_range(35.0, 55.0)
		b.lifetime = 5.0
		_apply_enemy_bullet_props(b, bspeed)
		_finalize_direct_enemy_bullet(bullets_container, b)

## STRAFE_RUN: Fires a spread while moving perpendicular — hit-and-run style
func _shoot_strafe_run(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bc = get_tree().get_first_node_in_group("bullets")
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var count: int = _get_active_bullet_count()
	var sfx_sr = get_node_or_null("/root/SFXManager")
	if sfx_sr:
		sfx_sr.play("shoot_b", -7.0, 0.1)
	if not bullets_container:
		return
	for i in range(count):
		get_tree().create_timer(i * 0.08).timeout.connect(
			func():
				if is_instance_valid(self) and is_instance_valid(player) and hp > 0:
					if bc:
						# Re-aim at player each shot — tracks during strafe
						var aim = (player.global_position - global_position).normalized()
						var jitter = randf_range(-0.1, 0.1)
						_spawn_bullet(bc, aim.rotated(jitter), bspeed)
		)

## MINEFIELD: Drops slow-moving bullets in all directions around self — area denial
func _shoot_minefield() -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var spawn_offset: Vector2 = Vector2.ZERO
	var count: int = _get_active_bullet_count()
	var angle: float = 0.0
	var sfx_mf = get_node_or_null("/root/SFXManager")
	if sfx_mf:
		sfx_mf.play("spell_a", -7.0, 0.2)
	if not bullets_container:
		return
	for i in range(count):
		_spawn_bullet_at(bullets_container, global_position + spawn_offset, Vector2.RIGHT.rotated(angle), bspeed)

## RETURNING_VOLLEY: Fires bullets that curve back toward the enemy after traveling a distance
func _shoot_returning(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var count: int = _get_active_bullet_count()
	var sfx_rv = get_node_or_null("/root/SFXManager")
	if sfx_rv:
		sfx_rv.play("swerve", -6.0, 0.1)
	if not bullets_container:
		return
	for i in range(count):
		var b = bullet_scene.instantiate()
		var angle := (float(i) - float(count - 1) * 0.5) * 0.22
		b.global_position = global_position
		b.direction = dir.rotated(angle)
		b.lifetime = 5.0
		_apply_enemy_bullet_props(b, bspeed * randf_range(0.8, 1.2))
		b.behavior = b.BulletBehavior.RETURNING
		b._origin_pos = global_position
		b._origin_entity = self
		b._max_travel = randf_range(40.0, 70.0)
		_finalize_direct_enemy_bullet(bullets_container, b)

## SEEKING_MINES: Drops slow homing mines that drift toward the player
func _shoot_seeking_mines() -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var spawn_offset: Vector2 = Vector2.ZERO
	var count: int = _get_active_bullet_count()
	var sfx_sm = get_node_or_null("/root/SFXManager")
	if sfx_sm:
		sfx_sm.play("spell_a", -7.0, 0.15)
	if not bullets_container:
		return
	for i in range(count):
		var b = bullet_scene.instantiate()
		var angle := TAU * float(i) / maxf(float(count), 1.0)
		b.global_position = global_position + spawn_offset
		b.direction = Vector2.RIGHT.rotated(angle)
		b.lifetime = 8.0
		_apply_enemy_bullet_props(b, bspeed)
		b.behavior = b.BulletBehavior.SEEKING_MINE
		b._origin_pos = global_position
		bullets_container.add_child(b)

## DETONATOR: Fires bullets that decelerate and explode into sub-bullets when stopped
func _shoot_detonator(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var spread: float = 0.3
	var count: int = _get_active_bullet_count()
	var sfx_dt = get_node_or_null("/root/SFXManager")
	if sfx_dt:
		sfx_dt.play("fire_c", -6.0, 0.1)
	if not bullets_container:
		return
	for i in range(count):
		var b = bullet_scene.instantiate()
		var offset := (float(i) - float(count - 1) * 0.5) * spread
		b.global_position = global_position
		b.direction = dir.rotated(offset)
		b.lifetime = 4.0
		_apply_enemy_bullet_props(b, bspeed)
		b.behavior = b.BulletBehavior.DECELERATING
		b._origin_pos = global_position
		b._decel_rate = randf_range(60.0, 120.0)
		bullets_container.add_child(b)

## SPLITTER: Fires bullets aimed at player that split halfway to the target
func _shoot_splitter(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var spread: float = 0.3
	var dist_to_player: float = global_position.distance_to(player.global_position) if is_instance_valid(player) else 999.0
	var count: int = _get_active_bullet_count()
	var sfx_sp = get_node_or_null("/root/SFXManager")
	if sfx_sp:
		sfx_sp.play("spell_b", -6.0, 0.12)
	if not bullets_container:
		return
	# Split timer = time to travel half the distance to player
	var split_time = maxf((dist_to_player * 0.5) / maxf(bspeed, 1.0), 0.3)
	for i in range(count):
		var b = bullet_scene.instantiate()
		var offset := (float(i) - float(count - 1) * 0.5) * spread
		b.global_position = global_position
		b.direction = dir.rotated(offset * 0.5)  # tighter aim at player
		b.lifetime = 4.0
		_apply_enemy_bullet_props(b, bspeed)
		b.behavior = b.BulletBehavior.SPLITTING
		b._origin_pos = global_position
		b._split_count = randi_range(3, 5)
		b.set_meta("split_time", split_time)
		bullets_container.add_child(b)

## SINE_BARRAGE: Fires sine-wave bullets that oscillate while traveling — hard to dodge
func _shoot_sine_barrage(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var spread: float = 0.3
	var count: int = _get_active_bullet_count()
	var sfx_sb = get_node_or_null("/root/SFXManager")
	if sfx_sb:
		sfx_sb.play("wiggle_a", -6.0, 0.1)
	if not bullets_container:
		return
	for i in range(count):
		var b = bullet_scene.instantiate()
		var offset := (float(i) - float(count - 1) * 0.5) * spread
		b.global_position = global_position
		b.direction = dir.rotated(offset)
		b.lifetime = 4.0
		_apply_enemy_bullet_props(b, bspeed * randf_range(0.8, 1.1))
		b.behavior = b.BulletBehavior.SINE_WAVE
		b._origin_pos = global_position
		b._base_direction = b.direction
		b._sine_amplitude = randf_range(4.0, 10.0)
		b._sine_frequency = randf_range(6.0, 12.0)
		bullets_container.add_child(b)

## HOMING_SALVO: Fires bullets that home toward the player — missile volley
func _shoot_homing_salvo(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bc = get_tree().get_first_node_in_group("bullets")
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var count: int = _get_active_bullet_count()
	var sfx_hs = get_node_or_null("/root/SFXManager")
	if sfx_hs:
		sfx_hs.play("fire_b", -5.0, 0.1)
	if not bullets_container:
		return
	for i in range(count):
		get_tree().create_timer(i * 0.1).timeout.connect(
			func():
				if not is_instance_valid(self) or hp <= 0:
					return
				if not bc:
					return
				# Fire in a wide arc — homing will correct course
				var b = bullet_scene.instantiate()
				var spread_angle = randf_range(-0.8, 0.8)
				b.global_position = global_position
				b.direction = dir.rotated(spread_angle)
				b.is_player_bullet = false
				b.speed = bspeed * randf_range(0.9, 1.3)
				b.behavior = b.BulletBehavior.HOMING_ENEMY
				b._origin_pos = global_position
				b.lifetime = 5.0
				bc.add_child(b)
		)

## TELEGRAPH_EXPLOSION: Spawns a warning marker at player's position, then explodes after delay
func _shoot_telegraph_explosion() -> void:
	var marker = Sprite2D.new()
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var dmg: int = definition.attack_damage if definition else 2
	var bc = get_tree().get_first_node_in_group("bullets")
	var radius: int = 16
	var alpha: float = 0.4
	var tween = create_tween()
	# Dead outer "var angle" removed — the ring/explosion loops below own their
	# own angle locals, and the deferred lambda's `var angle :=` was clashing
	# with this declaration (Godot 4 lambdas inherit parent scope).
	var ring_count: int = 8
	if not is_instance_valid(player):
		return
	var sfx_te = get_node_or_null("/root/SFXManager")
	if sfx_te:
		sfx_te.play("ping", -4.0, 0.0)
	var target_pos = player.global_position
	# Visual telegraph: flash a warning at the target location
	var img = Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
	for y in range(radius * 2):
		for x in range(radius * 2):
			var dx = x - float(radius)
			var dy = y - float(radius)
			var dist_sq = dx * dx + dy * dy
			if dist_sq < radius * radius:
				# Red circle with bright edge
				img.set_pixel(x, y, Color(1.0, 0.15, 0.0, alpha))
	marker.texture = ImageTexture.create_from_image(img)
	marker.global_position = target_pos
	marker.z_index = 1
	get_tree().current_scene.add_child(marker)
	# Blink the marker
	tween.tween_property(marker, "modulate:a", 0.2, 0.3)
	tween.tween_property(marker, "modulate:a", 1.0, 0.3)
	tween.tween_property(marker, "modulate:a", 0.2, 0.2)
	tween.tween_property(marker, "modulate:a", 1.0, 0.2)
	# Explode after delay
	if not is_inside_tree():
		return
	get_tree().create_timer(1.0).timeout.connect(
		func():
			if is_instance_valid(marker):
				marker.queue_free()
			# Spawn ring of bullets at the telegraph position
			var sfx_boom = get_node_or_null("/root/SFXManager")
			if sfx_boom:
				sfx_boom.play("boom_b", -11.0, 0.1)
			if not bc:
				return
			for j in range(ring_count):
				var b = bullet_scene.instantiate()
				var angle := TAU * float(j) / float(ring_count)
				b.global_position = target_pos
				b.direction = Vector2.RIGHT.rotated(angle)
				b.is_player_bullet = false
				b.speed = bspeed * 0.8
				b.lifetime = 3.0
				bc.add_child(b)
			# Direct damage in radius
			if is_instance_valid(player):
				if player.global_position.distance_to(target_pos) < 20.0:
					if player.has_method("take_damage"):
						player.take_damage(dmg, target_pos)
	)

## ORBIT_LAUNCH: Spawns bullets that orbit around the enemy then launch outward
func _shoot_orbit_launch(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var count: int = _get_active_bullet_count()
	var sfx_ol = get_node_or_null("/root/SFXManager")
	if sfx_ol:
		sfx_ol.play("sorcery", -6.0, 0.12)
	if not bullets_container:
		return
	for i in range(count):
		var b = bullet_scene.instantiate()
		var angle := TAU * float(i) / maxf(float(count), 1.0)
		var orbit_offset = Vector2.RIGHT.rotated(angle) * 12.0
		b.global_position = global_position + orbit_offset
		b.direction = dir  # launch direction after orbit completes
		b.lifetime = 5.0
		_apply_enemy_bullet_props(b, bspeed)
		b.behavior = b.BulletBehavior.ORBITING
		b._origin_pos = global_position
		b._origin_entity = self
		b._orbit_center = global_position
		b._orbit_radius = 12.0
		b._orbit_time = randf_range(0.4, 0.8)
		bullets_container.add_child(b)

## WALL_BOUNCE: Spread of bullets that bounce off walls
func _shoot_wall_bounce(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var spread: float = 0.3
	var count: int = _get_active_bullet_count()
	var t: float = Time.get_ticks_msec() / 1000.0
	var sfx_wb = get_node_or_null("/root/SFXManager")
	if sfx_wb:
		sfx_wb.play("rebound", -6.0, 0.1)
	if not bullets_container:
		return
	var bounces = definition.bounce_count if definition and definition.bounce_count > 0 else 2
	for i in range(count):
		var b = bullet_scene.instantiate()
		var offset := (float(i) - float(count - 1) * 0.5) * spread
		b.global_position = global_position
		b.direction = dir.rotated(offset + sin(t + float(i)) * 0.06)
		b.behavior = b.BulletBehavior.WALL_BOUNCE
		b.bounce_count = bounces
		b.lifetime = 4.0
		_apply_enemy_bullet_props(b, bspeed)
		bullets_container.add_child(b)

## LASER_GRID: 4 perpendicular beams of tightly-packed bullets
func _shoot_laser_grid(_dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bc = get_tree().get_first_node_in_group("bullets")
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var delay: float = 0.5
	var sfx_lg = get_node_or_null("/root/SFXManager")
	if sfx_lg:
		sfx_lg.play("laser_b", -5.0, 0.08)
	if not bullets_container:
		return
	# Fire 4 cardinal beams, each with multiple bullets for a laser-line feel
	for arm in range(4):
		var arm_dir = Vector2.RIGHT.rotated(arm * PI / 2.0)
		for j in range(5):
			var shot_delay := delay + float(j) * 0.05
			get_tree().create_timer(shot_delay).timeout.connect(
				func():
					if is_instance_valid(self) and hp > 0:
						if bc:
							var b = bullet_scene.instantiate()
							b.global_position = global_position
							b.direction = arm_dir
							b.lifetime = 1.5
							_apply_enemy_bullet_props(b, bspeed)
							bc.add_child(b)
			)

## GRAVITY_WELL: Slow orb that pulls player toward it, then explodes into a ring
func _shoot_gravity_well(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bc = get_tree().get_first_node_in_group("bullets")
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var sfx_gw = get_node_or_null("/root/SFXManager")
	if sfx_gw:
		sfx_gw.play("special_a", -5.0, 0.1)
	if not bullets_container:
		return
	# Spawn the gravity orb (large, slow). Annotated as Node2D so the deferred
	# lambdas below can infer types on `orb.global_position` — without it the
	# capture is Variant and `var x := orb.global_position - …` fails to compile.
	var orb: Node2D = bullet_scene.instantiate() as Node2D
	orb.global_position = global_position
	orb.direction = dir
	orb.lifetime = 3.0
	orb.bullet_sprite_index = 192  # pink_star for visibility
	_apply_enemy_bullet_props(orb, bspeed)
	bullets_container.add_child(orb)
	# After 3 seconds, explode into a ring of bullets at the orb's position
	get_tree().create_timer(2.8).timeout.connect(
		func():
			if is_instance_valid(orb):
				if bc:
					for i in range(12):
						var sub: Node2D = bullet_scene.instantiate() as Node2D
						var ring_angle: float = TAU * float(i) / 12.0
						sub.global_position = orb.global_position
						sub.direction = Vector2.from_angle(ring_angle)
						sub.is_player_bullet = false
						sub.damage = definition.attack_damage if definition else 2
						sub.speed = 90.0
						sub.lifetime = 2.0
						sub.enemy_kingdom = definition.kingdom if definition else ""
						bc.add_child(sub)
	)
	# Pull effect: periodically nudge player toward orb
	for tick in range(6):
		get_tree().create_timer(0.5 * tick).timeout.connect(
			func():
				if is_instance_valid(orb) and is_instance_valid(player):
					var pull_dir: Vector2 = orb.global_position - player.global_position
					if pull_dir.length() < 100.0 and pull_dir.length() > 0.01:
						# Stronger pull closer to orb
						var strength: float = lerpf(30.0, 10.0, pull_dir.length() / 100.0)
						player.velocity += pull_dir.normalized() * strength
		)

## CHAIN_LIGHTNING: Instant chain of damage areas from enemy to player with visual bolt
func _shoot_chain_lightning(dir: Vector2) -> void:
	var dmg: int = definition.attack_damage if definition else 2
	var bc = get_tree().get_first_node_in_group("bullets")
	var vfx = get_node_or_null("/root/VFXManager")
	var start: Vector2 = global_position
	var to_player: Vector2 = (player.global_position - global_position) if is_instance_valid(player) else Vector2.ZERO
	var delay: float = 0.5
	var tw = create_tween()
	var target: Vector2 = player.global_position if is_instance_valid(player) else global_position
	var bcc = get_tree().get_first_node_in_group("bullets")
	if not is_instance_valid(player):
		return
	var sfx_cl = get_node_or_null("/root/SFXManager")
	if sfx_cl:
		sfx_cl.play("lightning_a", -4.0, 0.1)
	if not bcc:
		return
	var chain_count = 6
	var step = (target - start) / float(chain_count)
	# Create visual lightning bolt line
	var bolt_line = Line2D.new()
	bolt_line.width = 2.0
	bolt_line.default_color = Color(0.4, 0.7, 1.0, 0.9)
	bolt_line.z_index = 5
	for i in range(chain_count + 1):
		var pt = start + step * i
		# Jitter intermediate points for jagged lightning look
		if i > 0 and i < chain_count:
			pt += Vector2(randf_range(-6, 6), randf_range(-6, 6))
		bolt_line.add_point(pt)
	get_tree().current_scene.add_child(bolt_line)
	# Fade and remove bolt
	tw.tween_property(bolt_line, "modulate:a", 0.0, 0.4)
	tw.tween_callback(bolt_line.queue_free)
	# Spawn damage areas along the chain that linger briefly
	for i in range(chain_count):
		var seg_pos = start + step * (i + 0.5) + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		get_tree().create_timer(delay).timeout.connect(
			func():
				if is_instance_valid(self):
					if bcc:
						var b = bullet_scene.instantiate()
						b.global_position = seg_pos
						b.direction = Vector2.ZERO
						b.lifetime = 0.5
						b.bullet_sprite_index = 176
						_apply_enemy_bullet_props(b, 0.0)
						b.speed = 0.0
						bcc.add_child(b)
						# VFX spark
						if vfx:
							vfx.hit_spark(seg_pos, Color(0.4, 0.7, 1.0))
		)
	# Direct damage if player is in chain path
	if is_instance_valid(player):
		var dist := to_player.length()
		if dist < 80.0:
			# Check if player is roughly along the bolt line
			var bolt_dir = (target - start).normalized()
			var proj = to_player.dot(bolt_dir)
			var perp_dist = abs(to_player.cross(bolt_dir))
			if proj > 0 and perp_dist < 15.0 and player.has_method("take_damage"):
				player.take_damage(dmg, start)

## DEATH_SPIRAL: Expanding spiral of bullets fired from a position (used on death)
func _shoot_death_spiral_at(pos: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bc = get_tree().get_first_node_in_group("bullets")
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	var delay: float = 0.5
	if not bullets_container:
		return
	var arms = 3
	var bullets_per_arm = 8
	for i in range(bullets_per_arm):
		var step_idx := i
		get_tree().create_timer(delay * float(i + 1)).timeout.connect(
			func():
				if bc:
					for arm in range(arms):
						var base_angle = (TAU / arms) * arm
						var spiral_angle = base_angle + step_idx * 0.4
						var b = bullet_scene.instantiate()
						b.global_position = pos
						b.direction = Vector2.from_angle(spiral_angle)
						b.is_player_bullet = false
						b.damage = definition.attack_damage if definition else 2
						b.speed = bspeed + step_idx * 8.0
						b.lifetime = 3.0
						b.enemy_kingdom = definition.kingdom if definition else ""
						bc.add_child(b)
		)

## --- Barrier / Pull / Push Attacks ---

## BARRIER_WALL: Spawns a line of stationary barrier bullets perpendicular to player direction
## Max 1 wall alive at a time — won't spawn if existing barriers are still up
func _shoot_barrier_wall(dir: Vector2) -> void:
	var bc = get_tree().get_first_node_in_group("bullets")
	var sfx = get_node_or_null("/root/SFXManager")
	var count: int = _get_active_bullet_count()
	if not bc:
		return
	# Boss/large enemies get 2 walls (6 segments), normal gets 1 wall (3 segments)
	var max_segments = 6 if _is_boss_or_large else 3
	var existing_barriers := 0
	for child in bc.get_children():
		if child is Area2D and child.has_method("queue_free") and child.get("behavior") != null:
			if child.behavior == child.BulletBehavior.BARRIER:
				existing_barriers += 1
	if existing_barriers >= max_segments:
		return  # walls still up, skip
	if sfx:
		sfx.play("spell_a", -13.0, 0.18)
	var seg_hp = 5 if _is_boss_or_large else 3
	var seg_lifetime = 6.0 if _is_boss_or_large else 4.0
	var perp = Vector2(-dir.y, dir.x)
	var wall_dist = 12.0
	var spacing = 8.0
	for i in range(count):
		var b = bullet_scene.instantiate()
		var lateral = (i - (count - 1) * 0.5) * spacing
		b.global_position = global_position + dir * wall_dist + perp * lateral
		b.direction = Vector2.ZERO
		b.behavior = b.BulletBehavior.BARRIER
		b.barrier_hp = seg_hp
		b.lifetime = seg_lifetime
		_apply_enemy_bullet_props(b, 0.0)
		b.bullet_sprite_index = ObjSpriteIndex.STAR_BURST
		bc.add_child(b)

## PULL_SHOT: Fires a slow orb toward player that pulls when nearby — large zone, long-lived
func _shoot_pull_shot(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bc = get_tree().get_first_node_in_group("bullets")
	var sfx = get_node_or_null("/root/SFXManager")
	var b = bullet_scene.instantiate()
	if sfx:
		sfx.play("special_a", -5.0, 0.1)
	if not bc:
		return
	b.global_position = global_position
	b.direction = dir
	b.behavior = b.BulletBehavior.PULL_ORB
	b._force_radius = 48.0  # large zone of influence
	b._force_strength = 3.0  # firm pull toward orb
	b.lifetime = randf_range(6.0, 10.0)  # persists a long time
	_apply_enemy_bullet_props(b, bspeed)
	b.bullet_sprite_index = ObjSpriteIndex.DARK_ORB
	bc.add_child(b)

## PUSH_WAVE: Fires slow orbs in a cone toward the player — large zones, long-lived
func _shoot_push_wave(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bc = get_tree().get_first_node_in_group("bullets")
	var sfx = get_node_or_null("/root/SFXManager")
	var count: int = _get_active_bullet_count()
	if sfx:
		sfx.play("area_effect_b", -5.0, 0.1)
	if not bc:
		return
	var cone_angle = PI * 0.4  # ~72 degree cone
	for i in range(count):
		var b = bullet_scene.instantiate()
		var angle_offset = 0.0
		if count > 1:
			angle_offset = lerp(-cone_angle * 0.5, cone_angle * 0.5, float(i) / float(count - 1))
		var d = dir.rotated(angle_offset)
		b.global_position = global_position
		b.direction = d
		b.behavior = b.BulletBehavior.PUSH_ORB
		b._force_radius = 45.0
		b._force_strength = 4.0
		b.lifetime = randf_range(6.0, 10.0)
		_apply_enemy_bullet_props(b, bspeed)
		b.bullet_sprite_index = ObjSpriteIndex.HOLY_ORB
		bc.add_child(b)

## --- New Pattern Attacks ---

## VORTEX: Spawns a swirling ring of bullets that tighten inward toward the player
func _shoot_vortex(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bc = get_tree().get_first_node_in_group("bullets")
	var count: int = _get_active_bullet_count()
	var sfx_vx = get_node_or_null("/root/SFXManager")
	if sfx_vx:
		sfx_vx.play("spell_b", -5.0, 0.1)
	if not bc:
		return
	# Fire bullets in a wide circle that slowly home toward player
	for i in range(count):
		var b = bullet_scene.instantiate()
		var angle := TAU * float(i) / maxf(float(count), 1.0)
		var spawn_offset = Vector2.from_angle(angle) * 30.0
		b.global_position = global_position + spawn_offset
		# Initial direction is tangential (perpendicular to radius) creating a swirl
		b.direction = spawn_offset.normalized().rotated(PI * 0.5)
		b.is_player_bullet = false
		b.speed = bspeed
		b.behavior = b.BulletBehavior.HOMING_ENEMY
		b._origin_pos = global_position
		b.lifetime = 4.0
		_apply_enemy_bullet_props(b, bspeed)
		b.bullet_sprite_index = ObjSpriteIndex.GLOW_PURPLE
		bc.add_child(b)

## RING_PULSE: Multiple timed rings that expand outward with gaps to dodge through
func _shoot_ring_pulse(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bc = get_tree().get_first_node_in_group("bullets")
	var ring_count: int = 8
	var sfx_rp = get_node_or_null("/root/SFXManager")
	if sfx_rp:
		sfx_rp.play("area_effect_a", -5.0, 0.1)
	var bullets_per_ring = maxi(_get_active_bullet_count(), 6)
	# Leave a gap in each ring for the player to dodge through
	var gap_size = 1  # 1 bullet-slot gap
	for wave in range(ring_count):
		get_tree().create_timer(wave * 0.5).timeout.connect(
			func():
				if not is_instance_valid(self) or hp <= 0:
					return
				if not bc:
					return
				# Rotate the gap position each wave so player must move
				var gap_start = randi_range(0, bullets_per_ring - 1)
				for i in range(bullets_per_ring):
					if i >= gap_start and i < gap_start + gap_size:
						continue  # gap slot
					var angle := TAU * (float(i) / float(bullets_per_ring)) + float(wave) * 0.18
					_spawn_bullet(bc, Vector2.from_angle(angle), bspeed * (1.0 + wave * 0.15))
				if sfx_rp:
					sfx_rp.play("fire_b", -8.0, 0.1)
		)

## ARTILLERY: Single high-damage lobbed bomb with huge AOE + bullet ring explosion
func _shoot_artillery() -> void:
	var bc = get_tree().get_first_node_in_group("bullets")
	var radius: int = 16
	var sfx = get_node_or_null("/root/SFXManager")
	var flight: float = 0.3
	if not is_instance_valid(player):
		return
	if sfx:
		sfx.play("bazooka", -3.0, 0.08)
	if not bc:
		return
	# Single big bomb: large AOE, ring of sub-bullets, high damage
	flight = _get_bomb_flight_time(definition.bomb_flight_time if definition else 0.8, 1.2)
	_spawn_lob_at(bc, player.global_position, ObjSpriteIndex.DARK_ORB, radius, flight, 8, 0, 3.0, 1.5)

## WHIP_LASH: Quick sweeping arc of bullets fired in rapid sequence
func _shoot_whip_lash(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bc = get_tree().get_first_node_in_group("bullets")
	var sfx = get_node_or_null("/root/SFXManager")
	var count: int = _get_active_bullet_count()
	if sfx:
		sfx.play("blaster", -5.0, 0.1)
	if not bc:
		return
	var sweep_arc = PI * 0.6  # 108 degree sweep
	for i in range(count):
		var t := float(i) / maxf(float(count - 1), 1.0)
		var shot_dir := dir.rotated(lerpf(-sweep_arc * 0.5, sweep_arc * 0.5, t))
		get_tree().create_timer(i * 0.03).timeout.connect(
			func():
				if not is_instance_valid(self) or hp <= 0:
					return
				var bcc = _get_bullets_container()
				if not bcc:
					return
				_spawn_bullet(bcc, shot_dir, bspeed)
		)

## POISON_CLOUD: Lobbed bomb that creates a lingering poison zone on impact
func _shoot_poison_cloud() -> void:
	var bc = get_tree().get_first_node_in_group("bullets")
	var flight := _get_bomb_flight_time(definition.bomb_flight_time if definition else 0.8, 1.0)
	var sfx = get_node_or_null("/root/SFXManager")
	var radius: int = 16
	var bomb = bullet_scene.instantiate()
	if not is_instance_valid(player):
		return
	if sfx:
		sfx.play("scatter", -5.0, 0.1)
	if not bc:
		return
	# Lob a poison bomb — on landing, create a lingering cloud
	bomb.global_position = global_position
	bomb.direction = (player.global_position - global_position).normalized()
	bomb.behavior = bomb.BulletBehavior.LOBBED
	bomb._target_pos = player.global_position
	bomb._lob_duration = clampf(flight * 1.25, 0.9, 3.0)
	bomb._lob_aoe_radius = radius
	bomb._lob_ring_count = 0
	bomb._lob_cluster_count = 0
	bomb._lob_is_bomb = true
	bomb.set_meta("poison_cloud", true)  # flag for special landing behavior
	bomb.set_meta("poison_cloud_duration", 4.0)
	bomb.set_meta("poison_cloud_radius", radius)
	_apply_enemy_bullet_props(bomb, 0.0)
	bomb.damage = maxi(1, int(bomb.damage * 1.5))
	bomb.bullet_sprite_index = ObjSpriteIndex.POISON_BALL
	bc.add_child(bomb)
	_spawn_landing_marker(player.global_position, radius, bomb._lob_duration)

## DASH_STRIKE: Quick dash toward player, firing bouncing bullets behind
func _shoot_dash_strike(dir: Vector2) -> void:
	var bc = get_tree().get_first_node_in_group("bullets")
	var sfx = get_node_or_null("/root/SFXManager")
	var count: int = _get_active_bullet_count()
	if sfx:
		sfx.play("dash", -4.0, 0.1)
	# Fire a spread of bouncing bullets behind as we charge
	if bc:
		var back_dir = -dir
		for i in range(count):
			var spread = (float(i) / maxf(count - 1, 1) - 0.5) * PI * 0.4
			var b = bullet_scene.instantiate()
			b.global_position = global_position
			b.direction = back_dir.rotated(spread)
			b.behavior = b.BulletBehavior.WALL_BOUNCE
			b.bounce_count = 3
			b.lifetime = 2.0
			_apply_enemy_bullet_props(b, definition.bullet_speed if definition else 60.0)
			bc.add_child(b)
	# Dash toward player
	charge_dir = dir
	charge_timer = 0.35
	state = State.CHARGING

## --- New Attack Types (56-61) ---

## LANCE_THRUST: 3-4 bullets in a line with staggered delay — piercing attack
func _shoot_lance_thrust(dir: Vector2) -> void:
	var bc = get_tree().get_first_node_in_group("bullets")
	var sfx = get_node_or_null("/root/SFXManager")
	var count: int = _get_active_bullet_count()
	if sfx:
		sfx.play("slash_a", -5.0, 0.1)
	if not bc:
		return
	for i in range(count):
		var delay = i * 0.05
		var spawn_offset := dir * float(i) * 5.0
		get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(self) and state != State.DEAD:
				var b = bullet_scene.instantiate()
				b.global_position = global_position + spawn_offset
				b.direction = dir
				b.lifetime = 2.5
				_apply_enemy_bullet_props(b, definition.bullet_speed if definition else 60.0)
				bc.add_child(b)
		)

## SHIELD_WALL: 3-5 barrier bullets in arc facing player — defensive screen
func _shoot_shield_wall(dir: Vector2) -> void:
	var bc = get_tree().get_first_node_in_group("bullets")
	var sfx = get_node_or_null("/root/SFXManager")
	var count: int = clampi(_get_active_bullet_count(), 3, 5)
	if sfx:
		sfx.play("spell_a", -13.0, 0.18)
	if not bc:
		return
	var spacing = 8.0
	var perp = Vector2(-dir.y, dir.x)  # perpendicular to player direction
	var shield_dist = 10.0  # distance in front of enemy
	for i in range(count):
		var b = bullet_scene.instantiate()
		# Spread bullets in an arc in front of the enemy
		var lateral = (i - (count - 1) * 0.5) * spacing
		var offset = dir * shield_dist + perp * lateral
		b.global_position = global_position + offset
		b.direction = Vector2.ZERO
		b.behavior = b.BulletBehavior.BARRIER
		b.barrier_hp = shield_hp if shield_hp > 0 else 3
		b.lifetime = 4.0
		_apply_enemy_bullet_props(b, 0.0)
		bc.add_child(b)

## CURSE_BOLT: Single slow homing projectile that applies random debuff
func _shoot_curse_bolt(dir: Vector2) -> void:
	var bc = get_tree().get_first_node_in_group("bullets")
	var sfx = get_node_or_null("/root/SFXManager")
	var b = bullet_scene.instantiate()
	if sfx:
		sfx.play("mystical", -5.0, 0.1)
	if not bc:
		return
	if b:
		b.global_position = global_position
		b.direction = dir
		b.behavior = b.BulletBehavior.HOMING_ENEMY
		b.lifetime = 5.0
		b.bullet_sprite_index = ObjSpriteIndex.DARK_ORB
		_apply_enemy_bullet_props(b, definition.bullet_speed if definition else 60.0)
		# Apply random debuff on hit via meta
		var debuffs = ["SLOWED", "POISONED", "BURNING"]
		b.set_meta("apply_status", debuffs[randi() % debuffs.size()])
		b.set_meta("status_duration", 3.0)
		bc.add_child(b)

## SUMMON_WALL: Summon 2-3 weak minions in a line between self and player
func _shoot_summon_wall(dir: Vector2) -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	var enemy_scene = preload("res://scenes/enemy.tscn")
	var container = get_tree().get_first_node_in_group("enemies")
	var spawn_pos: Vector2 = global_position
	var dm = get_node_or_null("/root/DungeonManager")
	var gp = get_meta("grid_pos", Vector2i(-999, -999))
	var count: int = _get_active_bullet_count()
	if not definition:
		return
	if not container:
		container = get_parent()
	if sfx:
		sfx.play("summon", -4.0, 0.1)
	# Auto-create minion def if needed
	if not definition.summon_definition:
		var minion_def := EnemyDefinition.new()
		minion_def.enemy_name = "Minion"
		minion_def.max_hp = maxi(1, definition.max_hp / 4)
		minion_def.move_speed = definition.move_speed * 1.2
		minion_def.attack_type = EnemyDefinition.AttackType.MELEE
		minion_def.attack_damage = maxi(1, definition.attack_damage)
		minion_def.attack_speed = 1.5
		minion_def.bullet_speed = 60.0
		minion_def.bullet_count = 1
		minion_def.kingdom = definition.kingdom
		minion_def.use_loy_sprite = definition.use_loy_sprite
		minion_def.loy_tile_index = definition.loy_tile_index
		minion_def.sprite_color = definition.sprite_color.darkened(0.3)
		minion_def.xp_value = 1
		minion_def.score_value = 2
		definition.summon_definition = minion_def
	var perp = dir.rotated(PI * 0.5)
	var mid = global_position + dir * 20.0
	for i in range(count):
		var minion = enemy_scene.instantiate()
		minion.global_position = spawn_pos
		minion.setup(definition.summon_definition.duplicate())
		container.add_child(minion)
		if gp != Vector2i(-999, -999):
			minion.set_meta("grid_pos", gp)
			if dm and dm.room_states.has(gp):
				dm.room_states[gp]["alive"] += 1
				minion.tree_exited.connect(dm._on_enemy_died.bind(gp))

## LEAPING_SLAM: Jump to player position, AOE shockwave + bullet ring on land
func _shoot_leaping_slam(dir: Vector2) -> void:
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var bc = get_tree().get_first_node_in_group("bullets")
	var sfx = get_node_or_null("/root/SFXManager")
	var sfx2 = get_node_or_null("/root/SFXManager")
	var orig_color: Color = definition.sprite_color if definition else Color.WHITE
	var radius: int = 16
	var tween = create_tween()
	var target: Vector2 = player.global_position if is_instance_valid(player) else global_position
	if not is_instance_valid(player):
		return
	if sfx:
		sfx.play("dash", -4.0, 0.1)
	# Telegraph with landing marker
	_spawn_landing_marker(target, radius, 0.5)
	# Brief invulnerability during jump
	$CollisionShape2D.set_deferred("disabled", true)
	$Sprite2D.modulate.a = 0.4
	# Jump arc via tween
	tween.tween_property(self, "global_position", target, 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		if not is_instance_valid(self) or state == State.DEAD:
			return
		$CollisionShape2D.set_deferred("disabled", false)
		$Sprite2D.modulate = orig_color
		# AOE slam damage
		_do_slam()
		# Bullet ring on landing
		if bc:
			var ring_count = maxi(_get_active_bullet_count(), 8)
			for i in range(ring_count):
				var shot_angle := TAU * float(i) / float(ring_count)
				_spawn_bullet(bc, Vector2.from_angle(shot_angle), bspeed)
		if sfx2:
			sfx2.play("boom_a", -10.0, 0.1)
	)

## ARROW_VOLLEY: 3-5 lobbed arrows that rain down around player position
func _shoot_arrow_volley() -> void:
	var bc = get_tree().get_first_node_in_group("bullets")
	var flight: float = 0.3
	var sfx = get_node_or_null("/root/SFXManager")
	var radius: int = 16
	var count: int = _get_active_bullet_count()
	if not is_instance_valid(player):
		return
	if sfx:
		sfx.play("scatter", -5.0, 0.1)
	if not bc:
		return
	for i in range(count):
		var offset := Vector2.from_angle(TAU * float(i) / maxf(float(count), 1.0)) * randf_range(4.0, 22.0)
		_spawn_lob_at(bc, player.global_position + offset, ObjSpriteIndex.FIREBALL, radius, flight, 0, 0, -1.0, 1.5)

## --- Lobbed Bomb Attacks ---

## Landing marker: blinking orange circle at target position
class _LandingMarkerDraw extends Node2D:
	var _elapsed: float = 0.0
	var duration: float = 1.0
	var radius: float = 12.0
	func _process(delta: float) -> void:
		_elapsed += delta
		queue_redraw()
		if _elapsed >= duration:
			get_parent().queue_free()
	func _draw() -> void:
		var pulse = 0.3 + 0.4 * abs(sin(_elapsed * 14.0))
		# Subtle transparent fill
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.3, 0.0, pulse * 0.4))
		# Thin pulsing ring outline
		draw_arc(Vector2.ZERO, radius, 0, TAU, 24, Color(1.0, 0.5, 0.0, pulse * 1.5), 0.5, true)

func _spawn_landing_marker(target_pos: Vector2, radius: float, duration: float) -> void:
	var marker = Node2D.new()
	var draw_node = _LandingMarkerDraw.new()
	marker.global_position = target_pos
	marker.z_index = 1  # above floor tiles, below enemies
	draw_node.radius = radius
	draw_node.duration = duration
	marker.add_child(draw_node)
	if is_inside_tree():
		get_tree().current_scene.add_child(marker)

## --- Melee Telegraph System ---

## Melee telegraph: red shape (arc/rect/circle) that pulses red during windup
class _MeleeTelegraphDraw extends Node2D:
	enum Shape { ARC, RECT, CIRCLE }
	var shape: int = Shape.ARC
	var angle_center: float = 0.0      # arc direction (radians)
	var arc_span: float = PI * 0.66    # arc width (radians)
	var rect_length: float = 80.0      # rect length for SPEAR_LUNGE
	var rect_width: float = 20.0
	var _elapsed: float = 0.0
	var duration: float = 0.5
	var radius: float = 24.0
	func _process(delta: float) -> void:
		_elapsed += delta
		queue_redraw()
		if _elapsed >= duration:
			get_parent().queue_free()
	func _draw() -> void:
		# Pulse and ramp-up alpha as telegraph progresses (warning gets brighter)
		var pulse = 0.3 + 0.4 * abs(sin(_elapsed * 14.0))
		var alpha = clampf(_elapsed / duration, 0.0, 1.0) * pulse
		var fill = Color(1.0, 0.15, 0.1, alpha * 0.35)
		var edge = Color(1.0, 0.3, 0.2, alpha)
		match shape:
			Shape.ARC:
				var start = angle_center - arc_span * 0.5
				var end = angle_center + arc_span * 0.5
				# Fan fill: draw polygon from center through arc
				var pts: PackedVector2Array = PackedVector2Array()
				var colors: PackedColorArray = PackedColorArray()
				pts.append(Vector2.ZERO)
				var steps = 16
				for i in range(steps + 1):
					var a = lerp(start, end, float(i) / steps)
					pts.append(Vector2(cos(a), sin(a)) * radius)
				for i in range(pts.size()):
					colors.append(fill)
				draw_polygon(pts, colors)
				draw_arc(Vector2.ZERO, radius, start, end, 24, edge, 1.5, true)
			Shape.RECT:
				# Rectangle pointing along angle_center
				var fwd = Vector2(cos(angle_center), sin(angle_center))
				var side = Vector2(-fwd.y, fwd.x)
				var p0 = -side * (rect_width * 0.5)
				var p1 = fwd * rect_length - side * (rect_width * 0.5)
				var p2 = fwd * rect_length + side * (rect_width * 0.5)
				var p3 = side * (rect_width * 0.5)
				var pts: PackedVector2Array = PackedVector2Array([p0, p1, p2, p3])
				var colors: PackedColorArray = PackedColorArray([fill, fill, fill, fill])
				draw_polygon(pts, colors)
				draw_polyline(PackedVector2Array([p0, p1, p2, p3, p0]), edge, 1.5, true)
			Shape.CIRCLE:
				draw_circle(Vector2.ZERO, radius, fill)
				draw_arc(Vector2.ZERO, radius, 0, TAU, 24, edge, 1.5, true)

## Sweeping melee bar: a visible blade that rotates from start_angle to end_angle over duration.
## Checks damage along its length each frame. Attached to enemy so it follows.
class _MeleeSweepBar extends Node2D:
	var length: float = 90.0
	var duration: float = 0.3
	var damage: int = 2
	var push_force: float = 150.0
	var start_angle: float = 0.0    # sweep start (radians, local)
	var end_angle: float = PI       # sweep end
	var hit_player: bool = false
	var _elapsed: float = 0.0
	var _player: CharacterBody2D = null
	var _owner_enemy: Node2D = null
	func _ready() -> void:
		z_index = 2
	func _process(delta: float) -> void:
		_elapsed += delta
		queue_redraw()
		if _elapsed >= duration:
			queue_free()
			return
		if hit_player or not is_instance_valid(_player) or not is_instance_valid(_owner_enemy):
			return
		var current_angle = lerp(start_angle, end_angle, clampf(_elapsed / maxf(duration, 0.001), 0.0, 1.0))
		var bar_dir = Vector2(cos(current_angle), sin(current_angle))
		var to_player = _player.global_position - _owner_enemy.global_position
		var dist_to_player = to_player.length()
		var angle_diff = absf(wrapf(to_player.angle() - current_angle, -PI, PI))
		# Hit if player is anywhere within reach of the bar (distance check + angle check)
		if dist_to_player > length + 6.0:
			return
		# Check angle: player must be within ~30 degrees of current bar angle
		if angle_diff > 0.55:  # ~31 degrees tolerance — generous blade width
			return
		hit_player = true
		if _player.has_method("take_damage"):
			_player.take_damage(damage, _owner_enemy.global_position, true, false)
		# Push player in the sweep direction (tangent of the arc)
		var sweep_tangent = Vector2(-sin(current_angle), cos(current_angle))
		if end_angle < start_angle:
			sweep_tangent = -sweep_tangent
		_player.velocity += sweep_tangent * push_force + bar_dir * push_force * 0.5
	func _draw() -> void:
		if not is_instance_valid(_owner_enemy):
			return
		var t = clampf(_elapsed / maxf(duration, 0.001), 0.0, 1.0)
		var current_angle = lerp(start_angle, end_angle, t)
		var bar_dir = Vector2(cos(current_angle), sin(current_angle))
		var side = Vector2(-bar_dir.y, bar_dir.x) * 1.2
		var tip = bar_dir * length
		var base_l = -side
		var base_r = side
		var mid_l = tip * 0.7 - side * 0.6
		var mid_r = tip * 0.7 + side * 0.6
		var point = tip
		var fill_c = Color(1.0, 0.8, 0.5, 0.85)
		var edge_c = Color(1.0, 0.2, 0.1, 0.95)
		var pts = PackedVector2Array([base_l, mid_l, point, mid_r, base_r])
		var colors = PackedColorArray([fill_c, fill_c, fill_c, fill_c, fill_c])
		# Pointed tip: triangle at end
		# White-hot core with red edge
		# Blade body (rect narrowing to point)
		draw_polygon(pts, colors)
		draw_polyline(PackedVector2Array([base_l, mid_l, point, mid_r, base_r, base_l]), edge_c, 0.8, true)

## Spinning bar for whirlwind: continuously rotates, checking damage with cooldown + push.
class _MeleeSpinBar extends Node2D:
	var length: float = 90.0
	var bar_width: float = 1.5      # thin sharp blade
	var spin_speed: float = 12.0    # radians/sec (slower, more readable)
	var damage: int = 2
	var push_force: float = 150.0   # knockback on hit
	var duration: float = 2.0
	var hit_cooldown: float = 0.6
	var _elapsed: float = 0.0
	var _current_angle: float = 0.0
	var _hit_cd: float = 0.0
	var _player: CharacterBody2D = null
	var _owner_enemy: Node2D = null
	func _ready() -> void:
		z_index = 2
	func _process(delta: float) -> void:
		_elapsed += delta
		_current_angle += spin_speed * delta
		_hit_cd -= delta
		queue_redraw()
		if _elapsed >= duration:
			queue_free()
			return
		if _hit_cd > 0 or not is_instance_valid(_player) or not is_instance_valid(_owner_enemy):
			return
		var to_player = _player.global_position - _owner_enemy.global_position
		var dist_to_player = to_player.length()
		if dist_to_player > length + 6.0:
			return
		# Angle-based hit: player must be within ~31 degrees of bar angle
		var player_angle = to_player.angle()
		var angle_diff = absf(wrapf(player_angle - _current_angle, -PI, PI))
		if angle_diff > 0.55:
			return
		_hit_cd = hit_cooldown
		if _player.has_method("take_damage"):
			_player.take_damage(damage, _owner_enemy.global_position, true, false)
		# Push player in the spin tangent direction + outward
		var spin_dir = Vector2(cos(_current_angle), sin(_current_angle))
		var tangent = Vector2(-sin(_current_angle), cos(_current_angle))
		_player.velocity += tangent * push_force + spin_dir * push_force * 0.3
	func _draw() -> void:
		if not is_instance_valid(_owner_enemy):
			return
		var bar_dir = Vector2(cos(_current_angle), sin(_current_angle))
		var tip = bar_dir * length
		var alpha = 0.85 if _hit_cd <= 0 else 0.3
		# Pointed blade shape
		var side = Vector2(-bar_dir.y, bar_dir.x) * bar_width
		var base_l = -side
		var base_r = side
		var mid_l = tip * 0.7 - side
		var mid_r = tip * 0.7 + side
		var point = tip
		var fill_c = Color(1.0, 0.6, 0.2, alpha)
		var edge_c = Color(1.0, 0.15, 0.0, alpha)
		var pts = PackedVector2Array([base_l, mid_l, point, mid_r, base_r])
		var colors = PackedColorArray([fill_c, fill_c, fill_c, fill_c, fill_c])
		draw_polygon(pts, colors)
		draw_polyline(PackedVector2Array([base_l, mid_l, point, mid_r, base_r, base_l]), edge_c, 0.8, true)

## Spawn a sweep bar that rotates from start_angle to end_angle, dealing damage if it hits player.
func _spawn_sweep_bar(start_angle: float, end_angle: float, reach: float, dmg: int, sweep_time: float) -> void:
	var bar = _MeleeSweepBar.new()
	bar.length = reach
	bar.start_angle = start_angle
	bar.end_angle = end_angle
	bar.duration = sweep_time
	bar.damage = dmg
	bar._player = player
	bar._owner_enemy = self
	add_child(bar)

## Spawn a spinning bar on self for whirlwind.
func _spawn_spin_bar(reach: float, dmg: int, spin_time: float, spin_spd: float, hit_cd: float) -> void:
	var bar = _MeleeSpinBar.new()
	bar.length = reach
	bar.damage = dmg
	bar.duration = spin_time
	bar.spin_speed = spin_spd
	bar.hit_cooldown = hit_cd
	bar._player = player
	bar._owner_enemy = self
	bar._current_angle = randf() * TAU
	add_child(bar)

## Spawn a telegraph decal at origin_pos. Returns the container node (so it can be attached to enemy for following).
func _spawn_melee_telegraph(origin_pos: Vector2, shape: int, duration: float, params: Dictionary = {}, follow: bool = false) -> Node2D:
	var marker = Node2D.new()
	marker.global_position = origin_pos
	marker.z_index = 1
	var draw_node = _MeleeTelegraphDraw.new()
	draw_node.shape = shape
	draw_node.duration = duration
	if params.has("radius"): draw_node.radius = params["radius"]
	if params.has("angle"): draw_node.angle_center = params["angle"]
	if params.has("arc_span"): draw_node.arc_span = params["arc_span"]
	if params.has("rect_length"): draw_node.rect_length = params["rect_length"]
	if params.has("rect_width"): draw_node.rect_width = params["rect_width"]
	marker.add_child(draw_node)
	if is_inside_tree():
		if follow:
			add_child(marker)
			marker.position = Vector2.ZERO
		else:
			get_tree().current_scene.add_child(marker)
	return marker

## Apply melee damage if player is within an arc hitbox in front of enemy.
## angle_center in radians, arc_span in radians.
func _do_melee_arc_damage(radius: float, angle_center: float, arc_span: float, damage: int) -> bool:
	var to_player: Vector2 = (player.global_position - global_position) if is_instance_valid(player) else Vector2.ZERO
	var vfx = get_node_or_null("/root/VFXManager")
	if not is_instance_valid(player):
		return false
	var dist = to_player.length()
	if dist > radius:
		return false
	var player_angle = to_player.angle()
	var diff = wrapf(player_angle - angle_center, -PI, PI)
	if absf(diff) > arc_span * 0.5:
		return false
	if player.has_method("take_damage"):
		player.take_damage(damage, global_position, true, false)
	if vfx:
		vfx.shockwave(player.global_position, 12.0, Color(1.0, 0.2, 0.1, 0.6))
		vfx.shake(2.0, 0.1)
	return true

## Apply damage if player is within a rectangle hitbox pointing in a direction.
func _do_melee_rect_damage(dir: Vector2, length: float, width: float, damage: int) -> bool:
	var to_player: Vector2 = (player.global_position - global_position) if is_instance_valid(player) else Vector2.ZERO
	var vfx = get_node_or_null("/root/VFXManager")
	if not is_instance_valid(player):
		return false
	var fwd = dir.normalized()
	var side = Vector2(-fwd.y, fwd.x)
	var along = to_player.dot(fwd)
	var across = to_player.dot(side)
	if along < 0 or along > length:
		return false
	if absf(across) > width * 0.5:
		return false
	if player.has_method("take_damage"):
		player.take_damage(damage, global_position, true, false)
	if vfx:
		vfx.shockwave(player.global_position, 12.0, Color(1.0, 0.2, 0.1, 0.6))
		vfx.shake(2.0, 0.1)
	return true

## Apply damage if player is within a circle around enemy (for whirlwind/ground pound).
func _do_melee_circle_damage(radius: float, damage: int) -> bool:
	var vfx = get_node_or_null("/root/VFXManager")
	if not is_instance_valid(player):
		return false
	if global_position.distance_to(player.global_position) > radius:
		return false
	if player.has_method("take_damage"):
		player.take_damage(damage, global_position, true, false)
	if vfx:
		vfx.shockwave(global_position, radius, Color(1.0, 0.2, 0.1, 0.5))
		vfx.shake(3.0, 0.15)
	return true

## --- Melee Attack Implementations ---

## SWORD_SLASH: Visible blade sweeps side-to-side. Brief windup -> blade sweeps.
func _shoot_sword_slash(dir: Vector2) -> void:
	var reach: float = 12.0
	var dmg: int = definition.attack_damage if definition else 2
	var sfx = get_node_or_null("/root/SFXManager")
	var sfx2 = get_node_or_null("/root/SFXManager")
	var arc: float = PI / 3.0
	if sfx:
		sfx.play("swing", -6.0, 0.05)
	var windup = 0.15  # brief pause before swing (no big telegraph)
	velocity = Vector2.ZERO
	get_tree().create_timer(windup).timeout.connect(
		func():
			if not is_instance_valid(self) or hp <= 0 or state == State.DEAD:
				return
			if sfx2:
				sfx2.play("impact_a", -4.0, 0.1)
			var strike_dir = Vector2.RIGHT
			if is_instance_valid(player):
				strike_dir = (player.global_position - global_position).normalized()
			var start_a = strike_dir.angle() - arc * 0.5
			var end_a = strike_dir.angle() + arc * 0.5
			_spawn_sweep_bar(start_a, end_a, reach, dmg, 0.3)
			charge_dir = strike_dir
			charge_timer = 0.08
			state = State.CHARGING
	)

## SPEAR_LUNGE: Telegraphed linear thrust. 0.5s rect warning -> tween forward through line.
func _shoot_spear_lunge(dir: Vector2) -> void:
	var dmg: int = definition.attack_damage if definition else 2
	var sfx = get_node_or_null("/root/SFXManager")
	var sfx2 = get_node_or_null("/root/SFXManager")
	var tween = create_tween()
	var telegraph_time: float = 0.3
	if sfx:
		sfx.play("woosh_b", -5.0, 0.1)
	var length = 45.0
	var width = 11.0
	var telegraph = _spawn_melee_telegraph(global_position, _MeleeTelegraphDraw.Shape.RECT, telegraph_time,
		{"rect_length": length, "rect_width": width, "angle": dir.angle()}, true)
	velocity = Vector2.ZERO
	get_tree().create_timer(telegraph_time).timeout.connect(
		func():
			if not is_instance_valid(self) or hp <= 0 or state == State.DEAD:
				return
			if sfx2:
				sfx2.play("impact_b", -3.0, 0.12)
			_do_melee_rect_damage(dir, length, width, dmg)
			# Tween enemy forward along the thrust line fast
			var start = global_position
			var end_pt = start + dir * length
			var lunge_tween = create_tween()
			lunge_tween.tween_property(self, "global_position", end_pt, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			# Recovery: 0.3s freeze
			cooldown_timer = 0.3
			state = State.COOLDOWN
	)

## CHARGE_BULL: 0.6s paw telegraph -> locked straight-line charge up to 200px -> wall stun.
func _shoot_charge_bull(dir: Vector2) -> void:
	var twn = create_tween()
	var sfx = get_node_or_null("/root/SFXManager")
	var sfx2 = get_node_or_null("/root/SFXManager")
	var sp: Node2D = $Sprite2D
	var telegraph_time: float = 0.3
	if sfx:
		sfx.play("shriek", -4.0, 0.08)
	var max_dist = 110.0
	_spawn_melee_telegraph(global_position, _MeleeTelegraphDraw.Shape.RECT, telegraph_time,
		{"rect_length": max_dist, "rect_width": 16.0, "angle": dir.angle()}, true)
	velocity = Vector2.ZERO
	# Sprite shake during telegraph
	var base_pos = sp.position
	twn.set_loops(int(telegraph_time * 10))
	twn.tween_property(sp, "position", base_pos + Vector2(1.5, 0), 0.05)
	twn.tween_property(sp, "position", base_pos - Vector2(1.5, 0), 0.05)
	# Lock direction now — bull doesn't track
	var locked_dir = dir
	get_tree().create_timer(telegraph_time).timeout.connect(
		func():
			if not is_instance_valid(self) or hp <= 0 or state == State.DEAD:
				return
			if sfx2:
				sfx2.play("woosh_a", -3.0, 0.1)
			set_meta("bull_charge", true)
			set_meta("bull_charge_dmg_dealt", false)
			charge_dir = locked_dir
			charge_timer = max_dist / 100.0  # 100 px/s heavy charge
			state = State.CHARGING
	)

## CLEAVE_COMBO: 3-hit chain with visible sweep bars. Left→right, right→left, wide smash.
func _shoot_cleave_combo(dir: Vector2) -> void:
	var base_dmg: int = definition.attack_damage if definition else 2
	var reach: float = 12.0
	var arc = PI * 0.7
	# Hit 1: left-to-right sweep bar (immediate) — wide side-to-side
	_do_cleave_bar(dir, reach, arc, -1.2, 1.2, base_dmg, 0.25, 0.0)
	# Hit 2: right-to-left sweep bar after 0.5s
	_do_cleave_bar(dir, reach, arc, 1.2, -1.2, base_dmg, 0.25, 0.5)
	# Hit 3: wide overhead sweep after 1.0s — even wider arc
	_do_cleave_bar(dir, reach * 1.2, PI * 0.9, -1.5, 1.5, int(base_dmg * 1.5), 0.3, 1.0)
	velocity = Vector2.ZERO
	cooldown_timer = 1.6
	state = State.COOLDOWN

func _do_cleave_bar(base_dir: Vector2, reach: float, arc: float, start_off: float, end_off: float, dmg: int, telegraph_time: float, delay: float) -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	var sfx2 = get_node_or_null("/root/SFXManager")
	get_tree().create_timer(delay).timeout.connect(
		func():
			if not is_instance_valid(self) or hp <= 0 or state == State.DEAD:
				return
			var d = base_dir
			if is_instance_valid(player):
				d = (player.global_position - global_position).normalized()
			var center_angle = d.angle() + (start_off + end_off) * 0.5
			_spawn_melee_telegraph(global_position, _MeleeTelegraphDraw.Shape.ARC, telegraph_time,
				{"radius": reach, "angle": center_angle, "arc_span": arc}, true)
			if sfx:
				sfx.play("woosh_b", -6.0, 0.1)
			get_tree().create_timer(telegraph_time).timeout.connect(
				func():
					if not is_instance_valid(self) or hp <= 0 or state == State.DEAD:
						return
					if sfx2:
						sfx2.play("swing", -4.0, 0.1)
					# Spawn visible sweep bar
					_spawn_sweep_bar(d.angle() + start_off, d.angle() + end_off, reach, dmg, 0.18)
			)
	)

## WHIRLWIND: 0.4s crouch -> 2.0s bouncing spin, ricochets off walls, big contact damage.
func _shoot_whirlwind(_dir: Vector2) -> void:
	var radius: int = 16
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("shriek", -5.0, 0.08)
	var telegraph_time = 0.4
	_spawn_melee_telegraph(global_position, _MeleeTelegraphDraw.Shape.CIRCLE, telegraph_time,
		{"radius": radius}, true)
	velocity = Vector2.ZERO
	get_tree().create_timer(telegraph_time).timeout.connect(
		func():
			if not is_instance_valid(self) or hp <= 0 or state == State.DEAD:
				return
			set_meta("whirlwind_active", true)
			set_meta("whirlwind_radius", radius)
			set_meta("whirlwind_time", 2.0)
			set_meta("whirlwind_tick", 0.0)
			set_meta("whirlwind_hit_cd", 0.0)
			set_meta("whirlwind_dmg", definition.attack_damage if definition else 2)
			# Initial bounce direction: toward player if visible, else random
			var initial = Vector2.RIGHT.rotated(randf() * TAU)
			if is_instance_valid(player):
				initial = (player.global_position - global_position).normalized()
			set_meta("whirlwind_velocity", initial * 140.0)
			# Spawn visible spinning bar (slower, readable)
			var ww_dmg = int((definition.attack_damage if definition else 2) * 1.5)
			_spawn_spin_bar(radius, ww_dmg, 2.0, 12.0, 0.6)
	)

## GROUND_POUND: Jump up, slam down creating expanding shockwave ring.
func _shoot_ground_pound(_dir: Vector2) -> void:
	var base_dmg: int = definition.attack_damage if definition else 2
	var twn = create_tween()
	var sfx = get_node_or_null("/root/SFXManager")
	var sfx2 = get_node_or_null("/root/SFXManager")
	var vfx = get_node_or_null("/root/VFXManager")
	var sp: Node2D = $Sprite2D
	if sfx:
		sfx.play("woosh_a", -5.0, 0.08)
	velocity = Vector2.ZERO
	var slam_pos = global_position
	# Jump up animation (sprite rises then slams)
	twn.tween_property(sp, "position:y", sp.position.y - 16.0, 0.3).set_ease(Tween.EASE_OUT)
	twn.tween_property(sp, "position:y", sp.position.y, 0.15).set_ease(Tween.EASE_IN)
	twn.tween_callback(func():
		if not is_instance_valid(self) or hp <= 0 or state == State.DEAD:
			return
		if sfx2:
			sfx2.play("impact_b", -2.0, 0.1)
		if vfx:
			vfx.shockwave(global_position, 24.0, Color(0.8, 0.4, 0.1, 0.6))
			vfx.shake(3.0, 0.15)
		# Expanding ring damage: 3 waves at increasing radii
		for wave_i in range(3):
			var wave_delay = wave_i * 0.15
			var wave_radius = 12.0 + wave_i * 10.0
			get_tree().create_timer(wave_delay).timeout.connect(func():
				if not is_instance_valid(self) or not is_instance_valid(player):
					return
				# Draw expanding ring visual via helper
				_spawn_melee_telegraph(global_position, _MeleeTelegraphDraw.Shape.CIRCLE, 0.2,
					{"radius": wave_radius}, false)
				# Damage check
				if global_position.distance_to(player.global_position) < wave_radius + 6.0:
					if player.has_method("take_damage"):
						player.take_damage(base_dmg, global_position, true, false)
					# Push outward from center
					var push_dir = (player.global_position - global_position).normalized()
					if push_dir == Vector2.ZERO:
						push_dir = Vector2.RIGHT
					player.velocity += push_dir * 180.0
			)
	)
	cooldown_timer = 1.2
	state = State.COOLDOWN

## TAIL_WHIP: Fast 360° spin sweep — full circle, lighter damage but hard to dodge.
func _shoot_tail_whip(dir: Vector2) -> void:
	var base_dmg: int = definition.attack_damage if definition else 2
	var twn = create_tween()
	var sfx = get_node_or_null("/root/SFXManager")
	var angle: float = 0.0
	var sp: Node2D = $Sprite2D
	if sfx:
		sfx.play("swing", -5.0, 0.05)
	velocity = Vector2.ZERO
	var reach = 20.0
	var strike_dir = dir
	if is_instance_valid(player):
		strike_dir = (player.global_position - global_position).normalized()
	# Full 360° sweep — two bars sweeping opposite directions for visual fullness
	_spawn_sweep_bar(angle, angle + PI * 2.0, reach, base_dmg, 0.4)
	# Small sprite spin
	twn.tween_property(sp, "rotation", TAU, 0.4).set_ease(Tween.EASE_IN_OUT)
	twn.tween_property(sp, "rotation", 0.0, 0.01)
	cooldown_timer = 0.8
	state = State.COOLDOWN

## SHIELD_BASH (melee): Short dash + wide frontal cone hit + heavy push.
func _shoot_melee_shield_bash(dir: Vector2) -> void:
	var base_dmg: int = definition.attack_damage if definition else 2
	var twn = create_tween()
	var sfx = get_node_or_null("/root/SFXManager")
	var sfx2 = get_node_or_null("/root/SFXManager")
	var vfx = get_node_or_null("/root/VFXManager")
	var sp: CanvasItem = $Sprite2D
	if sfx:
		sfx.play("woosh_b", -4.0, 0.08)
	velocity = Vector2.ZERO
	var bash_dir = dir
	if is_instance_valid(player):
		bash_dir = (player.global_position - global_position).normalized()
	# Brief telegraph: flash white
	sp.modulate = Color(2.0, 2.0, 2.0)
	twn.tween_property(sp, "modulate", definition.sprite_color if definition else Color.WHITE, 0.15)
	# Short forward dash
	charge_dir = bash_dir
	charge_timer = 0.12
	state = State.CHARGING
	# After dash completes, do wide frontal cone damage + push
	get_tree().create_timer(0.15).timeout.connect(func():
		if not is_instance_valid(self) or hp <= 0 or state == State.DEAD:
			return
		if sfx2:
			sfx2.play("impact_a", -10.0, 0.12)
		# Wide sweep bar — 140° cone in front
		_spawn_sweep_bar(bash_dir.angle() - 1.2, bash_dir.angle() + 1.2, 18.0, int(base_dmg * 1.3), 0.12)
		if vfx:
			vfx.shake(2.0, 0.1)
		cooldown_timer = 1.0
		state = State.COOLDOWN
	)

## GRAB_THROW: Reaches out, pulls player in, then throws them away.
func _shoot_grab_throw(dir: Vector2) -> void:
	var base_dmg: int = definition.attack_damage if definition else 2
	var sfx2 = get_node_or_null("/root/SFXManager")
	var vfx = get_node_or_null("/root/VFXManager")
	var sfx = get_node_or_null("/root/SFXManager")
	if not is_instance_valid(player):
		return
	if sfx:
		sfx.play("shriek", -6.0, 0.08)
	velocity = Vector2.ZERO
	var grab_reach = 24.0
	var to_player = player.global_position - global_position
	if to_player.length() > grab_reach:
		cooldown_timer = 0.3
		state = State.COOLDOWN
		return
	# Telegraph: brief red flash
	_spawn_melee_telegraph(global_position, _MeleeTelegraphDraw.Shape.CIRCLE, 0.2,
		{"radius": grab_reach}, true)
	get_tree().create_timer(0.2).timeout.connect(func():
		if not is_instance_valid(self) or not is_instance_valid(player) or hp <= 0:
			return
		# Check if player is still in range
		if global_position.distance_to(player.global_position) > grab_reach + 8.0:
			return
		# Phase 1: Pull player to enemy position
		if sfx2:
			sfx2.play("impact_a", -5.0, 0.1)
		if player.has_method("take_damage"):
			player.take_damage(base_dmg, global_position, true, false)
		# Yank player toward us
		var pull_dir: Vector2 = (global_position - player.global_position).normalized()
		player.velocity = pull_dir * 200.0
		# Phase 2: After brief hold, throw player away
		get_tree().create_timer(0.25).timeout.connect(func():
			if not is_instance_valid(self) or not is_instance_valid(player):
				return
			var sfx3 = get_node_or_null("/root/SFXManager")
			if sfx3:
				sfx3.play("woosh_a", -4.0, 0.1)
			# Throw in opposite direction from enemy facing
			var throw_dir = dir
			if is_instance_valid(player):
				throw_dir = (player.global_position - global_position).normalized()
				if throw_dir == Vector2.ZERO:
					throw_dir = dir
			player.velocity = throw_dir * 350.0
			if player.has_method("take_damage"):
				player.take_damage(base_dmg, global_position, true, false)
			if vfx:
				vfx.shake(4.0, 0.15)
		)
	)
	cooldown_timer = 1.5
	state = State.COOLDOWN

## STOMP_WAVE: Rhythmic stomps creating 3 expanding floor shockwaves in sequence.
func _shoot_stomp_wave(_dir: Vector2) -> void:
	var vfx = get_node_or_null("/root/VFXManager")
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("impact_b", -5.0, 0.08)
	velocity = Vector2.ZERO
	var base_dmg = maxi(1, int((definition.attack_damage if definition else 2) * 0.8))
	# 3 stomps, each with an expanding ring
	for stomp_i in range(3):
		get_tree().create_timer(stomp_i * 0.5).timeout.connect(func():
			if not is_instance_valid(self) or hp <= 0 or state == State.DEAD:
				return
			var sfx2 = get_node_or_null("/root/SFXManager")
			if sfx2:
				sfx2.play("impact_a", -4.0, 0.1)
			# Sprite stomp: quick down-up
			var sp = $Sprite2D
			var twn = create_tween()
			twn.tween_property(sp, "position:y", sp.position.y + 2.0, 0.05)
			twn.tween_property(sp, "position:y", sp.position.y, 0.1)
			if vfx:
				vfx.shake(1.5, 0.08)
			# Expanding ring: wave travels outward over 0.4s
			var stomp_pos = global_position
			for ring_i in range(4):
				var ring_delay = ring_i * 0.08
				var ring_radius = 8.0 + ring_i * 8.0
				get_tree().create_timer(ring_delay).timeout.connect(func():
					if not is_instance_valid(self) or not is_instance_valid(player):
						return
					# Visual ring via helper
					_spawn_melee_telegraph(stomp_pos, _MeleeTelegraphDraw.Shape.CIRCLE, 0.15,
						{"radius": ring_radius}, false)
					# Damage if player is within this ring band
					var pd = stomp_pos.distance_to(player.global_position)
					if pd < ring_radius + 5.0 and pd > ring_radius - 8.0:
						if player.has_method("take_damage"):
							player.take_damage(base_dmg, stomp_pos, true, false)
						var push = (player.global_position - stomp_pos).normalized()
						if push == Vector2.ZERO:
							push = Vector2.RIGHT
						player.velocity += push * 100.0
				)
		)
	cooldown_timer = 2.0
	state = State.COOLDOWN

func _spawn_lob_at(container: Node, target: Vector2, sprite_idx: int,
		aoe_radius: float, flight_time: float, ring_count: int, cluster_count: int,
		lob_height: float = -1.0, damage_mult: float = 1.35) -> void:
	# Bomb damage mult dialed back from 1.8 → 1.35. With elite-room dmg_mult,
	# level_scale, and the elite bomb buff already stacking, 1.8 produced 20+ damage
	# bombs in starter dungeons. 1.35 keeps bombs meaningful without one-shotting.
	var bomb = bullet_scene.instantiate()
	bomb.global_position = global_position
	bomb.direction = (target - global_position).normalized() if global_position.distance_to(target) > 1 else Vector2.RIGHT
	bomb.behavior = bomb.BulletBehavior.LOBBED
	bomb._target_pos = target
	bomb._lob_duration = clampf(flight_time * 1.25, 0.9, 3.0)
	bomb._lob_aoe_radius = aoe_radius
	bomb._lob_ring_count = ring_count
	bomb._lob_cluster_count = cluster_count
	bomb._lob_is_bomb = true  # flag for smaller sprite
	# Boss enemies get bigger bomb arcs
	if lob_height >= 0:
		bomb._lob_height = lob_height
	elif definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS:
		bomb._lob_height = 2.5
	_apply_enemy_bullet_props(bomb, 0.0)
	bomb.damage = maxi(2, int(bomb.damage * damage_mult))  # bombs hit harder than regular bullets
	bomb.bullet_sprite_index = sprite_idx  # override after apply so bomb sprite is always correct
	container.add_child(bomb)
	_obs_record_projectile(bomb, {
		"speed": bomb.speed,
		"damage": bomb.damage,
		"direction": bomb.direction,
		"behavior": int(bomb.behavior),
		"lifetime": bomb.lifetime,
		"stationary_ok": true,
		"lob_duration": bomb._lob_duration,
		"lob_radius": aoe_radius,
	})
	_spawn_landing_marker(target, aoe_radius, bomb._lob_duration)

## BOMB_TOSS: Single bomb at player position, explodes into bullet ring
func _shoot_bomb_toss() -> void:
	var bc = get_tree().get_first_node_in_group("bullets")
	var radius: int = 16
	var sfx = get_node_or_null("/root/SFXManager")
	var flight := _get_bomb_flight_time(definition.bomb_flight_time if definition else 0.8, 0.9)
	if not is_instance_valid(player):
		return
	if sfx:
		sfx.play("bazooka", -5.0, 0.12)
	if not bc:
		return
	_spawn_lob_at(bc, player.global_position, ObjSpriteIndex.FIREBALL, radius, flight, 0, 0)

## CARPET_BOMB: 3-5 bombs in a line from enemy toward player
func _shoot_carpet_bomb(dir: Vector2) -> void:
	var bc = get_tree().get_first_node_in_group("bullets")
	var radius: int = 16
	var sfx = get_node_or_null("/root/SFXManager")
	var flight := _get_bomb_flight_time(definition.bomb_flight_time if definition else 0.8, 1.0)
	var count: int = _get_bomb_attack_count(3)
	if not is_instance_valid(player):
		return
	if sfx:
		sfx.play("bazooka", -5.0, 0.1)
	if not bc:
		return
	var dist_to_player = global_position.distance_to(player.global_position)
	var step = maxf(dist_to_player / count, 10.0)
	for i in range(count):
		var target = global_position + dir * step * float(i + 1)
		# Carpet bombs: dialed from 1.8 → 1.35 (multiple bombs already stack damage).
		_spawn_lob_at(bc, target, ObjSpriteIndex.FIREBALL, radius, flight, 0, 0, -1.0, 1.35)

## FIRE_RAIN: 2-4 bombs scattered randomly around player position
func _shoot_fire_rain() -> void:
	var bc = get_tree().get_first_node_in_group("bullets")
	var radius: int = 16
	var sfx = get_node_or_null("/root/SFXManager")
	var count: int = _get_bomb_attack_count(3)
	if not is_instance_valid(player):
		return
	if sfx:
		sfx.play("scatter", -5.0, 0.1)
	if not bc:
		return
	var base_flight = _get_bomb_flight_time(definition.bomb_flight_time if definition else 0.8, 1.0)
	var center = player.global_position
	for i in range(count):
		var angle = randf() * TAU
		var dist = randf_range(8.0, 30.0)
		var offset = Vector2.from_angle(angle) * dist
		var flight = base_flight * randf_range(0.95, 1.15)
		# Fire rain bombs: 1.7 → 1.3 (multiple bombs already stack damage)
		_spawn_lob_at(bc, center + offset, ObjSpriteIndex.FIREBALL, radius, flight, 0, 0, -1.0, 1.3)

## CLUSTER_BOMB: One big bomb that splits into 4 smaller bombs on impact
func _shoot_cluster_bomb() -> void:
	var bc = get_tree().get_first_node_in_group("bullets")
	var radius: int = 16
	var sfx = get_node_or_null("/root/SFXManager")
	if not is_instance_valid(player):
		return
	if sfx:
		sfx.play("bazooka", -4.0, 0.1)
	if not bc:
		return
	var flight = _get_bomb_flight_time(definition.bomb_flight_time if definition else 0.8, 1.2)
	_spawn_lob_at(bc, player.global_position, ObjSpriteIndex.DARK_ORB, radius, flight, 0, 4, -1.0, 1.2)

## MINE_DROP: 2-3 short-range lobs near self with bullet ring on landing
func _shoot_mine_drop() -> void:
	var count: int = _get_bomb_attack_count(2)
	var radius: int = 16
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("ping", -6.0, 0.1)
	var bc = _get_bullets_container()
	if not bc:
		return
	var target_base = player.global_position if is_instance_valid(player) else global_position
	for i in range(count):
		var offset = Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))
		var target = target_base + offset
		_spawn_lob_at(bc, target, ObjSpriteIndex.ENERGY_BALL, radius, _get_bomb_flight_time(0.75, 0.9), 6, 0)

## Fire death bullet pattern at death position
func _fire_death_pattern() -> void:
	var count: int = definition.bullet_count if definition else 8
	var bspeed: float = definition.bullet_speed if definition else 60.0
	var pattern = definition.death_bullet_pattern
	var pos = global_position
	var bullets_container = _get_bullets_container()
	if not bullets_container:
		return
	match pattern:
		EnemyDefinition.AttackType.BURST:
			# Death explosion ring
			for i in range(count):
				var angle = TAU * float(i) / float(count)
				var b = bullet_scene.instantiate()
				b.global_position = pos
				b.direction = Vector2.from_angle(angle)
				b.is_player_bullet = false
				b.damage = maxi(1, definition.attack_damage / 2)
				b.speed = bspeed
				b.lifetime = 2.0
				b.enemy_kingdom = definition.kingdom
				bullets_container.add_child(b)
		EnemyDefinition.AttackType.SPIRAL, EnemyDefinition.AttackType.DEATH_SPIRAL:
			_shoot_death_spiral_at(pos)
		EnemyDefinition.AttackType.NOVA:
			# Double ring
			for ring in range(2):
				for i in range(count):
					var angle = TAU * float(i) / float(count)
					var b = bullet_scene.instantiate()
					b.global_position = pos
					b.direction = Vector2.from_angle(angle)
					b.is_player_bullet = false
					b.damage = maxi(1, definition.attack_damage / 2)
					b.speed = bspeed + ring * 20.0
					b.lifetime = 2.5
					b.enemy_kingdom = definition.kingdom
					bullets_container.add_child(b)
		_:
			# Fallback: simple burst
			for i in range(8):
				var angle = TAU * float(i) / 8.0
				var b = bullet_scene.instantiate()
				b.global_position = pos
				b.direction = Vector2.from_angle(angle)
				b.is_player_bullet = false
				b.damage = maxi(1, (definition.attack_damage if definition else 2) / 2)
				b.speed = 60.0
				b.lifetime = 2.0
				b.enemy_kingdom = definition.kingdom if definition else ""
				bullets_container.add_child(b)

func _has_line_of_sight() -> bool:
	if not is_instance_valid(player):
		return false
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position, 16)  # wall layer only
	query.exclude = [get_rid()]
	var result = space.intersect_ray(query)
	return result.is_empty()  # no wall between us = has LOS

## Shared vision: for Mummy (check attached ally LOS) and Arch Mage (check any nearby ally LOS)
func _has_line_of_sight_or_shared() -> bool:
	var space = get_world_2d().direct_space_state
	if _has_line_of_sight():
		return true
	if not definition:
		return false
	var atk = definition.attack_type
	# Mummy: raycast from attached ally to player
	if atk == EnemyDefinition.AttackType.PUSH_WAVE:
		if is_instance_valid(_attached_ally) and is_instance_valid(player):
			var q = PhysicsRayQueryParameters2D.create(_attached_ally.global_position, player.global_position, 16)
			q.exclude = [_attached_ally.get_rid()]
			return space.intersect_ray(q).is_empty()
	# Arch Mage / Artillery: use cached shared vision result
	if atk in [EnemyDefinition.AttackType.FIRE_RAIN, EnemyDefinition.AttackType.ARTILLERY]:
		return _shared_vision_has_los
	return false

## Mummy: attach to strongest ally in same room on first aggro
func _attach_to_strongest_ally() -> void:
	if _attached_ally != null:
		return  # already attached
	var my_gp = get_meta("grid_pos", Vector2i(-999, -999))
	var best: Node2D = null
	var best_hp: int = 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not is_instance_valid(e):
			continue
		if e.get_meta("grid_pos", Vector2i(-998, -998)) != my_gp:
			continue
		if e.hp > best_hp:
			best_hp = e.hp
			best = e
	if best:
		_attached_ally = best
		_bodyguard_mode = true
		if best.is_inside_tree():
			best.tree_exiting.connect(_on_guarded_ally_died, CONNECT_ONE_SHOT)

func _on_guarded_ally_died() -> void:
	_attached_ally = null
	_bodyguard_mode = false

func _on_guarded_ally_hit() -> void:
	_bodyguard_mode = false
	_chase_timer = 0.0
	_hit_aggro_timer = 5.0

## Called from take_damage — alert attached mummies that this enemy was hit
func _notify_bodyguards_ally_hit() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if e._attached_ally == self and e._bodyguard_mode:
			e._on_guarded_ally_hit()

## Returns true if the given position is behind this enemy (for stealth kills)
## Per-enemy hit reaction. No engine-wide time_scale — your input stays free.
## The enemy's sprite gets a quick scale-punch + slight position shake so the
## hit reads as impact, plus a screen shake on big/killing blows.
func _trigger_hit_stop(is_killing_blow: bool, damage_amt: int) -> void:
	var spr = get_node_or_null("Sprite2D") as Node2D
	if not spr:
		return
	# Capture the enemy's true base scale once (before any punch). All subsequent
	# punches animate FROM and BACK TO this saved scale so multi-shot weapons
	# can't compound the sprite size.
	if _original_sprite_scale == Vector2.ZERO:
		_original_sprite_scale = spr.scale
	# Kill any in-progress punch so we restart cleanly from base — no stacking.
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	spr.scale = _original_sprite_scale
	# Scale punch — strong/quick by default, harder on killing blows
	var punch_scale := 1.20
	var dur := 0.06
	if is_killing_blow:
		punch_scale = 1.55
		dur = 0.14
	elif damage_amt >= maxi(20, _max_hp / 4):
		punch_scale = 1.35
		dur = 0.10
	_punch_tween = create_tween()
	_punch_tween.set_trans(Tween.TRANS_BACK)
	_punch_tween.set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(spr, "scale", _original_sprite_scale * punch_scale, dur * 0.3)
	_punch_tween.tween_property(spr, "scale", _original_sprite_scale, dur * 0.7)
	# Screen shake on heavy hits — feels weighty without freezing anyone
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		if is_killing_blow:
			vfx.shake(2.5, 0.12)
		elif damage_amt >= maxi(20, _max_hp / 4):
			vfx.shake(1.5, 0.08)
	_hit_stop_active = false  # static flag no longer gates anything; clear immediately

## Force this enemy to immediately aggro the player — used by hordes and wave-2
## reinforcements so they actually chase from spawn instead of wandering.
func force_aggro_player() -> void:
	if state == State.DEAD:
		return
	# Deferred call may fire after the dungeon scene was torn down; bail safely.
	if not is_inside_tree():
		return
	if not is_instance_valid(player):
		var tree = get_tree()
		if tree:
			player = tree.get_first_node_in_group("player")
	_awareness = 1.0
	state = State.CHASE
	_chase_timer = 0.0
	if is_instance_valid(player):
		_last_known_player_dir = (player.global_position - global_position).normalized()
		_last_known_player_pos = player.global_position

func is_back_exposed(from_pos: Vector2) -> bool:
	var to_attacker = (from_pos - global_position).normalized()
	return _facing_dir.dot(to_attacker) < -0.3

## Returns current awareness level (0-1) for external queries
func get_awareness() -> float:
	return _awareness

## Update the awareness indicator (? or !) above sprite
func _update_awareness_indicator() -> void:
	if not _awareness_indicator:
		return
	# Ambush enemies never show awareness icons
	if definition and definition.movement_pattern and definition.movement_pattern.move_type == MovementPattern.MoveType.AMBUSH:
		_awareness_indicator.visible = false
		return
	if _awareness < 0.3:
		_awareness_indicator.visible = false
	elif _awareness < 0.7:
		_awareness_indicator.visible = true
		_awareness_indicator.text = "?"
		_awareness_indicator.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0, 0.5 + _awareness))
	else:
		_awareness_indicator.visible = true
		_awareness_indicator.text = "!"
		_awareness_indicator.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1, 0.7 + _awareness * 0.3))

## Called when awareness reaches ALERT threshold (≥ 0.7) — enter CHASE
func _on_awareness_alert() -> void:
	var tw = create_tween()
	if state == State.CHASE or state == State.ATTACK or state == State.DEAD:
		return
	state = State.CHASE
	_last_pos = global_position
	if _awareness_indicator:
		_awareness_indicator.visible = false
	_spread_aggro()
	# Mummy: attach to strongest ally on first aggro
	if definition and definition.attack_type == EnemyDefinition.AttackType.PUSH_WAVE:
		_attach_to_strongest_ally()
	# Arch Mage / Artillery: shared vision check
	if definition and definition.attack_type in [EnemyDefinition.AttackType.FIRE_RAIN, EnemyDefinition.AttackType.ARTILLERY]:
		_check_shared_vision_once()
	# Elite aggro taunt: brief pause + scale pulse
	if definition and definition.size_class == EnemyDefinition.SizeClass.LARGE and not _elite_taunt_done:
		_elite_taunt_done = true
		var spr_t = $Sprite2D
		var orig_scale = spr_t.scale
		tw.tween_property(spr_t, "scale", orig_scale * 1.3, 0.15)
		tw.tween_property(spr_t, "scale", orig_scale, 0.15)
	# Aggro SFX based on kingdom
	var sfx_ag = get_node_or_null("/root/SFXManager")
	if sfx_ag and definition:
		match definition.kingdom:
			"undead": sfx_ag.play("skeleton", -10.0, 0.2)
			"crawler": sfx_ag.play("beetle", -10.0, 0.2)
			"animal": sfx_ag.play("bird", -10.0, 0.2)
			"demon": sfx_ag.play("shriek", -10.0, 0.2)
			"orc": sfx_ag.play("claw", -10.0, 0.2)

## Transition from CHASE to INVESTIGATE — move to player's last known position then continue in their direction
func _begin_search() -> void:
	var is_true_boss: bool = definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS
	_chase_timer = 0.0
	_awareness = 0.5
	if _last_known_player_pos != Vector2.ZERO:
		_investigate_pos = _last_known_player_pos
		_investigate_dir = _last_known_player_dir
	else:
		_investigate_pos = global_position
		_investigate_dir = Vector2.ZERO
	_investigate_phase = 0
	_investigate_timer = 0.0
	_investigate_look_timer = 0.0
	if is_true_boss:
		state = State.IDLE  # true bosses just reset (they never deaggro anyway)
	else:
		state = State.INVESTIGATE

## Spread aggro to nearby idle/investigating enemies when this one enters combat
func _spread_aggro() -> void:
	if not is_inside_tree():
		return
	var spread_range = 40.0  # ~5 tiles in dungeon
	if not _dm:
		spread_range = 160.0  # larger range in overworld
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not is_instance_valid(e):
			continue
		if e.state == State.DEAD or e.state == State.CHASE or e.state == State.ATTACK:
			continue
		if e.global_position.distance_to(global_position) > spread_range:
			continue
		# Passive enemies don't get alerted by neighbors
		if e.has_meta("passive_until_hit") and e.get_meta("passive_until_hit"):
			continue
		# Confused enemies can't contribute to shared awareness
		if e.has_meta("confused") and e.get_meta("confused"):
			continue
		# Spread awareness — elites get less, normal enemies get more
		var spread_amount = _awareness * 0.5
		if e._is_boss_or_large:
			spread_amount = _awareness * 0.3
		e._awareness = minf(e._awareness + spread_amount, 1.0)
		e._update_awareness_indicator()
		# If awareness crossed alert threshold, enter chase
		if e._awareness >= 0.7:
			e._on_awareness_alert()
		elif e._awareness >= 0.3 and e.state == State.IDLE:
			e._investigate_pos = global_position
			e._investigate_dir = (global_position - e.global_position).normalized()
			e._investigate_phase = 0
			e._investigate_timer = 0.0
			e._investigate_look_timer = 0.0
			e.state = State.INVESTIGATE

## Shared vision: check if any ally has LOS to player
## Arch Mage: one-time check (nearby allies only)
## Artillery: periodic re-check (any ally, unlimited range)
func _check_shared_vision_once() -> void:
	var is_artillery = definition and definition.attack_type == EnemyDefinition.AttackType.ARTILLERY
	if not is_artillery and _shared_vision_checked:
		return
	_shared_vision_checked = true
	_shared_vision_has_los = false
	if not is_instance_valid(player):
		return
	var max_ally_dist = 500.0 if is_artillery else 80.0
	var space = get_world_2d().direct_space_state
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not is_instance_valid(e):
			continue
		if e.global_position.distance_to(global_position) > max_ally_dist:
			continue
		var q = PhysicsRayQueryParameters2D.create(e.global_position, player.global_position, 16)
		q.exclude = [e.get_rid()]
		if space.intersect_ray(q).is_empty():
			_shared_vision_has_los = true
			return

func take_damage(amount: int, from_player: bool = true, dmg_type: int = 0) -> void:
	var scene_root = get_tree().current_scene if is_inside_tree() else null
	var sfx = get_node_or_null("/root/SFXManager")
	var vfx = get_node_or_null("/root/VFXManager")
	var tween = create_tween()
	if state == State.DEAD:
		return
	if from_player:
		# Passive enemies become hostile when hit by player
		if has_meta("passive_until_hit") and get_meta("passive_until_hit"):
			set_meta("passive_until_hit", false)
		# Instant full awareness on player damage
		_awareness = 1.0
		_update_awareness_indicator()
		# Getting hit by player always aggros and resets chase timer
		if state == State.IDLE or state == State.INVESTIGATE:
			state = State.CHASE
		_chase_timer = 0.0
		_hit_aggro_timer = 5.0  # stay aggro for 5s even if player is far away
		# Alert nearby enemies — combat awareness spread
		_spread_aggro()
	else:
		# Environmental/trap damage — don't reveal player location
		if state == State.IDLE:
			_investigate_pos = global_position
			_investigate_dir = Vector2.ZERO
			_investigate_phase = 0
			_investigate_timer = 0.0
			_investigate_look_timer = 0.0
			var is_true_boss_td = definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS
			if not is_true_boss_td:
				state = State.INVESTIGATE
		# If already CHASE, stay in CHASE (don't de-aggro)
	# FROZEN — take +50% damage
	if has_meta("frozen") and get_meta("frozen"):
		amount = int(ceil(amount * 1.5))
	# Apply armor reduction with combat type multiplier
	var my_armor_type: int = definition.armor_type if definition else 0
	amount = CombatTypes.apply_combat_damage(amount, dmg_type, my_armor_type, armor, 1)
	hp -= amount
	_time_since_hit = 0.0
	# Hit reaction: scale-punch on this enemy (no engine time_scale)
	if from_player and amount > 0:
		_trigger_hit_stop(hp <= 0, amount)
	# Alert attached mummy bodyguards that this enemy was hit
	_notify_bodyguards_ally_hit()
	# Floating damage number
	if scene_root and amount > 0:
		FloatingText.spawn_damage(scene_root, global_position, amount, Color(1.0, 1.0, 0.3))
	var orig_color = definition.sprite_color if definition else Color.WHITE
	$Sprite2D.modulate = Color.WHITE * 3
	tween.tween_property($Sprite2D, "modulate", orig_color, 0.1)
	# VFX: blood splatter on hit
	if vfx:
		var hit_dir = Vector2.UP  # default
		var p = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
		if p and is_instance_valid(p):
			hit_dir = (global_position - p.global_position).normalized()
		vfx.blood_splatter(global_position, hit_dir, Color(0.7, 0.0, 0.0))
	# SFX: hit sound
	if sfx:
		sfx.play("hit", -3.0)
	_update_boss_hp_bar()
	if hp <= 0:
		_die()
		return
	_check_phase_transition()

func apply_status(status_name: String, duration: float) -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	var vfx = get_node_or_null("/root/VFXManager")
	var sr = get_tree().current_scene if is_inside_tree() else null
	# Status immunity check
	if definition:
		if definition.status_immunities.has(status_name):
			if sr:
				FloatingText.spawn(sr, global_position + Vector2(0, -6), "IMMUNE", Color(0.8, 0.8, 0.8))
			return
		# Bosses auto-immune to hard CC
		if definition.size_class >= 2 and status_name in ["STUNNED", "FEARED", "CONFUSED"]:
			if sr:
				FloatingText.spawn(sr, global_position + Vector2(0, -6), "IMMUNE", Color(0.8, 0.8, 0.8))
			return
		# Elites: half duration on all statuses
		if definition.size_class == 1:
			duration *= 0.5
	# Apply visual tint for status effects
	var color = Color.WHITE
	match status_name:
		"BURNING": color = Color(1.0, 0.5, 0.2)
		"SLOWED": color = Color(0.4, 0.6, 1.0)
		"FROZEN": color = Color(0.3, 0.5, 1.0)
		"POISONED": color = Color(0.3, 0.8, 0.2)
		"STUNNED": color = Color(1.0, 1.0, 0.4)
		"FEARED": color = Color(0.9, 0.9, 0.5)
		"CONFUSED": color = Color(0.6, 0.3, 0.8)
		"WEAKENED": color = Color(0.6, 0.6, 0.6)
		"STRENGTHENED": color = Color(1.0, 0.8, 0.3)
	$Sprite2D.modulate = color
	# VFX + SFX for status applied
	if vfx:
		vfx.status_puff(global_position, status_name)
	if sfx:
		match status_name:
			"BURNING": sfx.play("burn", -4.0)
			"SLOWED": sfx.play("freeze", -4.0)
			"FROZEN": sfx.play("freeze", -2.0)
			"POISONED": sfx.play("curse", -4.0)
			"STUNNED": sfx.play("impact_a", -4.0)
			"FEARED": sfx.play("shriek", -6.0)
			"CONFUSED": sfx.play("curse", -6.0)
			"WEAKENED": sfx.play("curse", -6.0)
			"STRENGTHENED": sfx.play("mystical", -4.0)
	# Burning meta for fire spread checks
	if status_name == "BURNING":
		set_meta("burning", true)
	# Weakened — deal 50% less damage
	if status_name == "WEAKENED":
		set_meta("weakened", true)
	if status_name == "STRENGTHENED":
		set_meta("strengthened", true)
	# Slow enemies when slowed — heavy slowdown
	if status_name == "SLOWED":
		speed *= 0.15  # 85% speed reduction
		shoot_interval *= 3.0  # attacks 3x slower
	if status_name == "FROZEN":
		speed = 0.0  # completely frozen in place
		shoot_interval *= 99.0  # can't attack
		set_meta("frozen", true)
	# Stunned — can't move or attack
	if status_name == "STUNNED":
		speed = 0.0
		shoot_interval *= 99.0
		set_meta("stunned", true)
	# Feared — flee from player, can't attack
	if status_name == "FEARED":
		set_meta("feared", true)
		state = State.CHASE  # CHASE with feared flag = flee behavior
	# Confused — random movement, can friendly-fire
	if status_name == "CONFUSED":
		set_meta("confused", true)
		state = State.CHASE
	# Damage over time for burning/poison
	if status_name == "POISONED":
		var tick_dmg = maxi(1, int(_max_hp / 20.0))
		var ticks = int(duration / 0.5)
		for i in range(ticks):
			get_tree().create_timer(0.5 * (i + 1)).timeout.connect(
				func():
					if is_instance_valid(self) and hp > 0:
						take_damage(tick_dmg, false)
			)
	if status_name == "BURNING":
		# Fire does 50% more DOT than poison and ticks faster (0.4s vs 0.5s)
		var tick_dmg = maxi(1, int(_max_hp / 13.0))
		var ticks = int(duration / 0.4)
		for i in range(ticks):
			get_tree().create_timer(0.4 * (i + 1)).timeout.connect(
				func():
					if is_instance_valid(self) and hp > 0:
						take_damage(tick_dmg, false)
						# Burning spreads to nearby enemies (24px radius)
						_try_spread_fire(duration - 0.4 * (i + 1))
			)
	# Feared: periodic panic noise that alerts other enemies (chain reactions)
	if status_name == "FEARED":
		var fear_noise_ticks = int(duration / 0.5)
		for i in range(fear_noise_ticks):
			get_tree().create_timer(0.5 * (i + 1)).timeout.connect(
				func():
					if is_instance_valid(self) and hp > 0 and has_meta("feared") and get_meta("feared"):
						hear_noise(global_position, 30.0)
			)
	# Confused: sprite wobble
	if status_name == "CONFUSED":
		var wobble_ticks = int(duration / 0.1)
		for i in range(wobble_ticks):
			get_tree().create_timer(0.1 * (i + 1)).timeout.connect(
				func():
					if is_instance_valid(self) and has_meta("confused") and get_meta("confused"):
						$Sprite2D.rotation = sin(float(i) * 2.0) * 0.2
			)
	# Feared: sprite flicker
	if status_name == "FEARED":
		var flicker_ticks = int(duration / 0.1)
		for i in range(flicker_ticks):
			get_tree().create_timer(0.1 * (i + 1)).timeout.connect(
				func():
					if is_instance_valid(self) and has_meta("feared") and get_meta("feared"):
						$Sprite2D.visible = (i % 2 == 0)
			)
	# Restore after duration
	get_tree().create_timer(duration).timeout.connect(
		func():
			if is_instance_valid(self):
				$Sprite2D.modulate = definition.sprite_color if definition else Color.WHITE
				$Sprite2D.visible = true
				$Sprite2D.rotation = 0.0
				if status_name == "BURNING":
					set_meta("burning", false)
				if (status_name == "SLOWED" or status_name == "FROZEN") and definition:
					speed = definition.move_speed
					shoot_interval = definition.attack_speed
				if status_name == "FROZEN":
					set_meta("frozen", false)
				if status_name == "STUNNED":
					if definition:
						speed = definition.move_speed
						shoot_interval = definition.attack_speed
					set_meta("stunned", false)
					_awareness = 0.0  # loses track of player after stun
					_update_awareness_indicator()
					if state == State.CHASE or state == State.ATTACK:
						state = State.IDLE
				if status_name == "FEARED":
					set_meta("feared", false)
					_awareness = 0.5
					_update_awareness_indicator()
					if definition:
						speed = definition.move_speed
				if status_name == "CONFUSED":
					set_meta("confused", false)
					_awareness = 0.3
					_update_awareness_indicator()
				if status_name == "WEAKENED":
					set_meta("weakened", false)
				if status_name == "STRENGTHENED":
					set_meta("strengthened", false)
	)

func _try_spread_fire(remaining_duration: float) -> void:
	if remaining_duration < 0.5 or not is_inside_tree():
		return
	var spread_radius = 40.0
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e) or e == self:
			continue
		if global_position.distance_to(e.global_position) > spread_radius:
			continue
		# Only spread if they're not already burning
		if e.has_meta("burning") and e.get_meta("burning"):
			continue
		if e.has_method("apply_status"):
			e.apply_status("BURNING", remaining_duration * 0.5)

func take_damage_from_front(amount: int, from_dir: Vector2) -> void:
	var tween = create_tween()
	# Shield enemies block frontal damage
	if shield_hp > 0:
		var facing = Vector2.LEFT if $Sprite2D.flip_h else Vector2.RIGHT
		if from_dir.dot(facing) > 0.3:  # hitting the shield side
			shield_hp -= amount
			if shield_hp <= 0:
				shield_hp = 0
			# SFX + Flash blue for shield hit
			var sfx_sh = get_node_or_null("/root/SFXManager")
			if sfx_sh:
				sfx_sh.play("clack", -5.0, 0.12)
			$Sprite2D.modulate = Color.CYAN
			tween.tween_property($Sprite2D, "modulate", definition.sprite_color if definition else Color.WHITE, 0.1)
			return
	take_damage(amount)

func hear_noise(pos: Vector2, radius: float) -> void:
	if state == State.DEAD:
		return
	# Already in combat — noise doesn't change state
	if state == State.CHASE or state == State.ATTACK:
		return
	# Bosses hear at half range, elites hear normally
	var is_true_boss = definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS
	var eff_radius = radius * 0.5 if is_true_boss else radius
	if global_position.distance_to(pos) > eff_radius:
		return
	# Add awareness instead of instant investigate — noise stacks
	_awareness = minf(_awareness + 0.4, 1.0)
	_update_awareness_indicator()
	# If awareness crossed threshold, transitions happen in next IDLE tick
	# But also set investigate target so INVESTIGATE state knows where to go
	if _awareness >= 0.3:
		_investigate_pos = pos
		_investigate_dir = Vector2.ZERO
		_investigate_phase = 0
		_investigate_timer = 0.0
		_investigate_look_timer = 0.0
		if _awareness >= 0.7:
			_on_awareness_alert()
		elif state == State.IDLE:
			state = State.INVESTIGATE

## Check if enemy landed on a trap or hazard after throw/nudge
func _check_hazard_at_position() -> void:
	if not is_inside_tree():
		return
	for t in get_tree().get_nodes_in_group("trap"):
		if is_instance_valid(t) and t.global_position.distance_to(global_position) < 10.0:
			if t.has_method("trigger_remote"):
				t.trigger_remote()

func apply_throw(dir: Vector2, force: float, thrower_dmg: int) -> void:
	var tween = create_tween()
	if _is_boss_or_large and definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS:
		return  # bosses immune to throw
	var actual_force = force
	if _is_boss_or_large:
		actual_force *= 0.5  # elites: halved throw distance
	_thrown_velocity = dir * actual_force
	_thrown_timer = 0.4
	_thrower_dmg = thrower_dmg
	# White flash on grabbed enemy
	$Sprite2D.modulate = Color.WHITE * 3
	var orig = definition.sprite_color if definition else Color.WHITE
	tween.tween_property($Sprite2D, "modulate", orig, 0.2)

func _check_phase_transition() -> void:
	if not definition or definition.boss_phases <= 1 or _max_hp <= 0:
		return
	var hp_percent = float(hp) / float(_max_hp)
	var new_phase = 1
	if definition.boss_phases >= 3 and hp_percent <= 0.33:
		new_phase = 3
	elif definition.boss_phases >= 2 and hp_percent <= 0.66:
		new_phase = 2
	if new_phase > _current_phase:
		_current_phase = new_phase
		_on_phase_change(new_phase)

func _on_phase_change(phase: int) -> void:
	var dm = get_node_or_null("/root/DungeonManager")
	var angle: float = 0.0
	# Flash white to signal phase change
	$Sprite2D.modulate = Color.WHITE * 4
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate", definition.sprite_color if definition else Color.WHITE, 0.4)
	var sfx_ph = get_node_or_null("/root/SFXManager")
	if sfx_ph:
		sfx_ph.play("special_b", -10.0, 0.08)
	var vfx_ph = get_node_or_null("/root/VFXManager")
	if vfx_ph:
		vfx_ph.shockwave(global_position, 24.0, Color(1.0, 0.3, 0.3, 0.6))
		vfx_ph.shake(2.5, 0.2)

	# Spawn minions on phase change
	if definition.summon_on_phase_change and definition.summon_definition:
		var spawn_count = definition.summon_phase_count
		var container = get_tree().get_first_node_in_group("enemies") if is_inside_tree() else null
		if not container:
			container = get_parent()
		if container and container.get_child_count() >= MAX_SUMMONED_ENEMIES:
			spawn_count = 0
		var enemy_scene = preload("res://scenes/enemy.tscn")
		for i in range(spawn_count):
			var minion = enemy_scene.instantiate()
			var offset = Vector2.RIGHT.rotated(angle + TAU * i / maxi(spawn_count, 1)) * 20.0
			minion.global_position = global_position + offset
			var minion_def = definition.summon_definition.duplicate()
			minion_def.max_hp = int(minion_def.max_hp * 0.5)  # minions are weaker
			container.add_child(minion)
			minion.setup(minion_def)
			if has_meta("grid_pos"):
				var gp_val = get_meta("grid_pos")
				minion.set_meta("grid_pos", gp_val)
				minion.tree_exited.connect(func():
					if not is_inside_tree():
						return
					if dm:
						dm._on_enemy_died(gp_val)
				)

	# Increase speed slightly each phase
	speed *= 1.15
	shoot_interval *= 0.85  # attack faster

## Boss ground slam: AoE damage + destroy nearby obstacles
func _do_ground_slam() -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	var vfx = get_node_or_null("/root/VFXManager")
	if not is_instance_valid(player):
		return
	# Brief pause
	velocity = Vector2.ZERO
	# Flash white
	$Sprite2D.modulate = Color.WHITE * 3
	var tw = create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(func():
		if not is_instance_valid(self):
			return
		# AoE damage
		var slam_radius = 25.0
		if is_instance_valid(player) and global_position.distance_to(player.global_position) < slam_radius:
			if player.has_method("take_damage"):
				var dmg = (definition.attack_damage if definition else 3) * 2
				player.take_damage(dmg, global_position)
		# VFX + SFX
		if vfx:
			vfx.shockwave(global_position, slam_radius, Color(0.8, 0.4, 0.1, 0.7))
			vfx.shake(3.0, 0.2)
		if sfx:
			sfx.play("explode_b", -3.0, 0.1)
		# Break nearby obstacles
		_break_nearby_obstacles()
		# Restore color
		var enrage_color = Color(1.5, 0.4, 0.4) if _enraged else (definition.sprite_color if definition else Color.WHITE)
		$Sprite2D.modulate = enrage_color
	)

## Break decoration and wall tiles near this enemy (boss/elite pathfinding aid)
## Both bosses and elites smash through obstacles and walls, creating new floor + wall edges
func _break_nearby_obstacles() -> void:
	var is_boss: bool = definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS
	var vfx = get_node_or_null("/root/VFXManager")
	if not _dm:
		return
	var break_radius = 24.0 if is_boss else 18.0
	var smash_tile_radius = 2 if is_boss else 1
	var tile_size = 8

	# Directly scan deco_layer cells near the enemy — avoids world↔tile conversion bugs
	var broke_any = false
	var broken_deco_tiles: Array[Vector2i] = []
	for cell in _dm.deco_layer.get_used_cells():
		var cell_world = Vector2(cell.x * tile_size + tile_size * 0.5, cell.y * tile_size + tile_size * 0.5)
		if cell_world.distance_to(global_position) > break_radius:
			continue
		# Break any solid deco (rows 0-3 = barrels, furniture, chairs, stone pots)
		# But skip walkable overrides (carpets, track tiles, etc.)
		var atlas = _dm.deco_layer.get_cell_atlas_coords(cell)
		if atlas.y in [0, 1, 2, 3] and atlas not in _dm.WALKABLE_DECO_OVERRIDES:
			_dm.deco_layer.erase_cell(cell)
			if _dm.nav:
				_dm.nav.mark_walkable(cell)
			broke_any = true
			broken_deco_tiles.append(cell)
			if vfx:
				vfx.death_burst(cell_world, Color(0.6, 0.4, 0.2), 0)

	# Also check forward (toward player) for obstacles just out of range
	if is_instance_valid(player) and state == State.CHASE:
		var toward = (player.global_position - global_position).normalized()
		var ahead_pos = global_position + toward * (break_radius + 4.0)
		var ahead_tile = Vector2i(int(floor(ahead_pos.x / tile_size)), int(floor(ahead_pos.y / tile_size)))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var t = ahead_tile + Vector2i(dx, dy)
				var src = _dm.deco_layer.get_cell_source_id(t)
				if src < 0:
					continue
				var atlas = _dm.deco_layer.get_cell_atlas_coords(t)
				if atlas.y in [0, 1, 2, 3] and atlas not in _dm.WALKABLE_DECO_OVERRIDES:
					_dm.deco_layer.erase_cell(t)
					if _dm.nav:
						_dm.nav.mark_walkable(t)
					broke_any = true
					broken_deco_tiles.append(t)

	# Smash walls + void → create new floor with wall edges
	var center_tile = Vector2i(int(floor(global_position.x / tile_size)), int(floor(global_position.y / tile_size)))
	var near_wall = false
	for offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
					Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var neighbor = center_tile + offset
		if _dm.wall_layer.get_cell_source_id(neighbor) >= 0:
			near_wall = true
			break

	# Break standalone physics objects (holes, placed obstacles) in "breakable" group
	for body in get_tree().get_nodes_in_group("breakable"):
		if is_instance_valid(body) and global_position.distance_to(body.global_position) < break_radius:
			if body.has_method("take_damage"):
				body.take_damage(999)
			else:
				body.queue_free()

	if near_wall and _dm.has_method("smash_area"):
		_dm.smash_area(global_position, smash_tile_radius)
	if broke_any:
		if not near_wall and _dm.nav:
			_dm.nav.invalidate()
		_dm._remove_collision_at_tiles(broken_deco_tiles)

func _die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	if _awareness_indicator:
		_awareness_indicator.visible = false

	# Explode on death
	if definition and definition.explodes_on_death:
		_explode_on_death()

	# Death bullet pattern
	if definition and definition.death_bullet_pattern != EnemyDefinition.AttackType.NONE:
		_fire_death_pattern()

	# Split on death (blob-like)
	if definition and definition.attack_type == EnemyDefinition.AttackType.SPLIT:
		if not definition.split_definition:
			# Auto-create smaller split copy
			var sd = definition.duplicate()
			sd.enemy_name = definition.enemy_name + " Shard"
			sd.max_hp = maxi(1, definition.max_hp / 3)
			sd.move_speed = definition.move_speed * 1.3
			sd.attack_type = EnemyDefinition.AttackType.MELEE
			sd.attack_damage = maxi(1, definition.attack_damage)
			sd.split_count = 0
			sd.split_definition = null  # no recursive split
			sd.xp_value = 1
			sd.score_value = 2
			sd.sprite_color = definition.sprite_color.lightened(0.2)
			definition.split_definition = sd
		_split_on_death()

	# Grant XP to player (elite 3x, boss 10x)
	if definition and definition.xp_value > 0 and is_instance_valid(player):
		if player.has_method("gain_xp"):
			var xp_mult = 1
			if definition.size_class == EnemyDefinition.SizeClass.BOSS:
				xp_mult = 10
			elif definition.size_class == EnemyDefinition.SizeClass.LARGE:
				xp_mult = 3
			player.gain_xp(definition.xp_value * xp_mult)

	# Massacre kill tracker
	if is_instance_valid(player) and player.has_method("on_enemy_killed_for_massacre"):
		player.on_enemy_killed_for_massacre()

	# Notify quest system
	if definition:
		var qm = get_node_or_null("/root/QuestManager")
		if qm:
			var kill_name = definition.quest_kill_name if definition.quest_kill_name != "" else definition.enemy_name
			qm.on_enemy_killed(kill_name)
			if definition.size_class >= EnemyDefinition.SizeClass.BOSS:
				qm.on_boss_killed(kill_name)

	# Boss perk token drop
	if definition and definition.size_class >= EnemyDefinition.SizeClass.BOSS:
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.save_data:
			var boss_key = "boss_killed_" + (definition.enemy_name.to_lower().replace(" ", "_"))
			var first_kill = not gm.save_data.world_flags.has(boss_key)
			var drop_token = first_kill or randf() < 0.05
			# Bounty Hunter perk doubles re-kill drop rate
			if not first_kill and not drop_token:
				var pm = get_node_or_null("/root/PerkManager")
				if pm and pm.has_special("bounty_hunter"):
					drop_token = randf() < 0.05  # second roll
			if drop_token:
				gm.save_data.perk_tokens += 1
				gm.save_data.world_flags[boss_key] = true
				var _scene_root = get_tree().current_scene if is_inside_tree() else null
				if _scene_root:
					FloatingText.spawn(_scene_root, global_position + Vector2(0, -16), "+1 PERK TOKEN", Color(1.0, 0.85, 0.0))
				var vfx = get_node_or_null("/root/VFXManager")
				if vfx:
					vfx.gold_sparkle(global_position)
				var sfx = get_node_or_null("/root/SFXManager")
				if sfx:
					sfx.play("level_up", -3.0)

	# Floating text for XP/gold (with size class multiplier)
	var xp_val = definition.xp_value if definition else 0
	if definition:
		if definition.size_class == EnemyDefinition.SizeClass.BOSS:
			xp_val *= 10
		elif definition.size_class == EnemyDefinition.SizeClass.LARGE:
			xp_val *= 3
	var gold_val = definition.score_value if definition else 5
	var scene_root = get_tree().current_scene if is_inside_tree() else null
	if scene_root:
		if xp_val > 0:
			FloatingText.spawn(scene_root, global_position + Vector2(0, -8), "+%d XP" % xp_val, Color(0.5, 1.0, 0.5))
		if gold_val > 0:
			FloatingText.spawn(scene_root, global_position + Vector2(0, 4), "+%d Gold" % gold_val, Color(1.0, 0.85, 0.2))

	# Gold drops as a gold pickup (not in a bag) — scaled by size class
	var gold = definition.score_value if definition else 5
	if definition:
		if definition.size_class >= 2:  # BOSS
			gold *= 5
		elif definition.size_class == 1:  # LARGE/elite
			gold *= 2
	if gold > 0:
		var pickup = pickup_scene.instantiate()
		pickup.gold_amount = gold
		pickup.global_position = global_position + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		if is_inside_tree():
			get_tree().current_scene.add_child(pickup)

	# Items drop in a loot bag (only if items rolled)
	var bag_items: Array[EquipmentItem] = []
	var is_boss = definition and definition.size_class >= 2
	var is_elite = definition and definition.size_class == 1

	# Consumable drops: apples and potions from any enemy
	if definition:
		var apple_chance = 0.12  # 12% apple
		var hp_pot_chance = 0.06  # 6% red potion
		var mp_pot_chance = 0.04  # 4% blue potion
		var hp_pot = load("res://resources/items/loy/red_potion.tres") as EquipmentItem
		var mp_pot = load("res://resources/items/loy/blue_potion.tres") as EquipmentItem
		if is_elite:
			apple_chance = 0.20
			hp_pot_chance = 0.10
			mp_pot_chance = 0.08
		if randf() < apple_chance:
			var apple = load("res://resources/items/loy/apple.tres") as EquipmentItem
			if apple:
				bag_items.append(apple.make_copy())
		if randf() < hp_pot_chance:
			if hp_pot:
				bag_items.append(hp_pot.make_copy())
		if randf() < mp_pot_chance:
			if mp_pot:
				bag_items.append(mp_pot.make_copy())
		var stam_pot_chance = 0.10
		if is_elite:
			stam_pot_chance = 0.20
		if randf() < stam_pot_chance:
			var stam_pot = load("res://resources/items/loy/green_potion.tres") as EquipmentItem
			if stam_pot:
				bag_items.append(stam_pot.make_copy())

	# Boss guaranteed drops: potions + 2-3 equipment items
	if is_boss:
		var hp_pot = load("res://resources/items/loy/red_potion.tres") as EquipmentItem
		var mp_pot = load("res://resources/items/loy/blue_potion.tres") as EquipmentItem
		var boss_stam_pot = load("res://resources/items/loy/green_potion.tres") as EquipmentItem
		if hp_pot:
			for _j in range(randi_range(1, 2)):
				bag_items.append(hp_pot.make_copy())
		if mp_pot:
			for _j in range(randi_range(1, 2)):
				bag_items.append(mp_pot.make_copy())
		if boss_stam_pot:
			bag_items.append(boss_stam_pot.make_copy())
		if drop_table:
			# Bosses drop 2-3 guaranteed equipment items
			var boss_roll_count = randi_range(2, 3)
			for _k in range(boss_roll_count):
				var boss_item = drop_table.roll()
				if boss_item:
					bag_items.append(boss_item.make_copy())
				else:
					# Guarantee at least something from the pool
					var fallback_items = drop_table.entries
					if fallback_items.size() > 0:
						bag_items.append(fallback_items[randi() % fallback_items.size()].item.make_copy())

	# Elite equipment drops: 1-2 items at 70% chance
	elif drop_table and is_elite:
		if randf() < 0.70:
			var roll_count = randi_range(1, 2)
			for _i in range(roll_count):
				var dropped = drop_table.roll()
				if dropped:
					bag_items.append(dropped.make_copy())

	# Normal enemy equipment drops: 1 item at 40% chance (was 20% — felt empty)
	elif drop_table:
		if randf() < 0.40:
			var dropped = drop_table.roll()
			if dropped:
				bag_items.append(dropped.make_copy())

	if not bag_items.is_empty():
		var bag = LootBag.new()
		bag.items = bag_items
		bag.global_position = global_position + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		if is_inside_tree():
			get_tree().current_scene.add_child(bag)

	# Crafting material drops
	_try_drop_crafting_material()

	# Gem drops
	_try_drop_gem()

	# VFX: death burst
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		var death_color = definition.sprite_color if definition else Color(0.8, 0.1, 0.1)
		var sc = definition.size_class if definition else 0
		vfx.death_burst(global_position, death_color, sc)
		if sc >= 2:
			vfx.shake(3.0, 0.25)  # bosses shake the screen
		elif sc == 1:
			vfx.shake(1.5, 0.15)
	# SFX: creature death cry based on kingdom, with a chunky impact under it
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		if definition:
			match definition.kingdom:
				"undead": sfx.play("skeleton", -4.0, 0.15)
				"crawler": sfx.play("beetle", -4.0, 0.15)
				"animal": sfx.play("mouse", -4.0, 0.15)
				"demon": sfx.play("mystical", -4.0, 0.15)
				"orc": sfx.play("claw", -4.0, 0.15)
				"magical": sfx.play("mystical", -4.0, 0.15)
			# Extra impact thud on every kill so the player feels it
			sfx.play("impact_b", -5.0, 0.18, 0.85)
		# Size-based death explosion
		var sc2 = definition.size_class if definition else 0
		if sc2 >= 2:
			sfx.play("explode_b", 0.0, 0.08)
		elif sc2 == 1:
			sfx.play("explode_a", -2.0, 0.08)
		else:
			sfx.play("explode_c", -5.0, 0.1)

	# Delay queue_free if death pattern uses timers (spiral/nova)
	if definition and definition.death_bullet_pattern != EnemyDefinition.AttackType.NONE:
		$Sprite2D.visible = false
		$CollisionShape2D.set_deferred("disabled", true)
		var hurtbox = get_node_or_null("Hurtbox")
		if hurtbox:
			hurtbox.monitoring = false
			hurtbox.monitorable = false
		get_tree().create_timer(2.0).timeout.connect(func(): queue_free())
	else:
		queue_free()

func _explode_on_death() -> void:
	var radius = definition.explode_radius if definition else 20.0
	var sfx_ex = get_node_or_null("/root/SFXManager")
	if sfx_ex:
		sfx_ex.play("boom_a", -10.0, 0.1)
	var vfx_ex = get_node_or_null("/root/VFXManager")
	if vfx_ex:
		vfx_ex.shockwave(global_position, radius, Color(1.0, 0.4, 0.1, 0.7))
	var bodies = get_tree().get_nodes_in_group("player")
	for body in bodies:
		if body.global_position.distance_to(global_position) < radius:
			if body.has_method("take_damage"):
				body.take_damage(definition.attack_damage if definition else 2, global_position)

func _split_on_death() -> void:
	var sfx_split = get_node_or_null("/root/SFXManager")
	if sfx_split:
		sfx_split.play("jelly", -4.0, 0.15)
	var count = definition.split_count if definition else 2
	var enemy_scene = preload("res://scenes/enemy.tscn")
	var container = get_parent()
	for i in range(count):
		var angle = TAU / count * i + randf() * 0.5
		var spawn_pos = global_position + Vector2(cos(angle), sin(angle)) * 8.0
		var minion = enemy_scene.instantiate()
		minion.global_position = spawn_pos
		minion.setup(definition.split_definition.duplicate())
		container.add_child(minion)
		var gp = get_meta("grid_pos", Vector2i(-999, -999))
		if gp != Vector2i(-999, -999):
			minion.set_meta("grid_pos", gp)
			var dm = get_tree().get_first_node_in_group("dungeon_manager") if is_inside_tree() else null
			if dm and dm.room_states.has(gp):
				dm.room_states[gp]["alive"] += 1
				minion.tree_exited.connect(dm._on_enemy_died.bind(gp))

# Material drop tables by kingdom
const KINGDOM_MATERIALS: Dictionary = {
	"undead": ["res://resources/items/crafting/bone_dust.tres"],
	"orc": ["res://resources/items/crafting/iron_ore.tres"],
	"crawler": ["res://resources/items/crafting/leather_scraps.tres", "res://resources/items/crafting/venom_sac.tres"],
	"animal": ["res://resources/items/crafting/leather_scraps.tres", "res://resources/items/crafting/venom_sac.tres"],
	"demon": ["res://resources/items/crafting/demon_shard.tres"],
	"magical": ["res://resources/items/crafting/magic_essence.tres"],
	"human": ["res://resources/items/crafting/iron_ore.tres", "res://resources/items/crafting/leather_scraps.tres"],
}
const RARE_MATERIALS: Array = [
	"res://resources/items/crafting/fire_crystal.tres",
	"res://resources/items/crafting/demon_shard.tres",
	"res://resources/items/crafting/magic_essence.tres",
]

func _try_drop_crafting_material() -> void:
	if not definition:
		return
	var drop_chance = 0.20  # 20% base — felt too dry at 10%
	if definition.size_class == 1:
		drop_chance = 0.50
	elif definition.size_class >= 2:
		drop_chance = 1.0
	if randf() >= drop_chance:
		return

	var kingdom = definition.kingdom
	var possible: Array = KINGDOM_MATERIALS.get(kingdom, []) as Array
	if possible.is_empty():
		possible = ["res://resources/items/crafting/healing_herb.tres"]

	var mat_path: String = possible[randi() % possible.size()]
	var mat_item = load(mat_path) as EquipmentItem
	if not mat_item:
		return

	var mat_bag = LootBag.new()
	mat_bag.items = [mat_item.make_copy()] as Array[EquipmentItem]
	mat_bag.global_position = global_position + Vector2(randf_range(-4, 4), randf_range(-4, 4))
	if is_inside_tree():
		get_tree().current_scene.add_child(mat_bag)

	# Bosses also have a chance for rare materials
	if definition.size_class >= 2 and randf() < 0.5:
		var rare_path: String = RARE_MATERIALS[randi() % RARE_MATERIALS.size()]
		var rare_item = load(rare_path) as EquipmentItem
		if rare_item:
			mat_bag.items.append(rare_item.make_copy())

	# Healing herb has a small chance from any enemy
	if randf() < 0.08 and mat_path != "res://resources/items/crafting/healing_herb.tres":
		var herb = load("res://resources/items/crafting/healing_herb.tres") as EquipmentItem
		if herb:
			mat_bag.items.append(herb.make_copy())

func _try_drop_gem() -> void:
	if not definition:
		return
	var drop_chance := 0.03  # 3% base for normal enemies
	if definition.size_class == 1:
		drop_chance = 0.15  # 15% for elites
	elif definition.size_class >= 2:
		drop_chance = 1.0  # guaranteed for bosses
	if randf() >= drop_chance:
		return

	# Determine max eligible tier
	var max_tier := 1
	if definition.size_class >= 2:
		max_tier = 2  # bosses can drop tier 2
	elif definition.size_class == 1 and randf() < 0.25:
		max_tier = 2  # elites have 25% chance for tier 2

	# Pick a random gem from eligible tiers
	var all_gems: Array[String] = ResourceRegistry.gems()
	var eligible: Array[String] = []
	for gem_path in all_gems:
		var gem = load(gem_path) as GemDefinition
		if gem and gem.tier <= max_tier:
			eligible.append(gem_path)
	if eligible.is_empty():
		return

	var chosen_path: String = eligible[randi() % eligible.size()]
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.add_gem_to_bag(chosen_path)
		var gem_def = load(chosen_path) as GemDefinition
		if gem_def:
			gm.discover_gem(gem_def.gem_id)
			# Visual feedback
			var scene_root = get_tree().current_scene if is_inside_tree() else null
			if scene_root:
				FloatingText.spawn(scene_root, global_position + Vector2(0, -16), "Gem: %s" % gem_def.gem_name, gem_def.color_hint)
			var sfx = get_node_or_null("/root/SFXManager")
			if sfx:
				sfx.play("collect_a", -2.0, 0.1)

# Coop: clients call this on receipt of a host snapshot.
func apply_remote_state(world_pos: Vector2, hp_val: int) -> void:
	_remote_target_pos = world_pos
	_remote_has_state = true
	if hp_val >= 0:
		hp = hp_val

# Coop: notify CoopRuntime to broadcast this enemy bullet spawn to clients so they
# can spawn a local damaging copy. Host only — no-op offline or on client (proxies
# don't fire because their AI is gated).
func _coop_broadcast_enemy_bullet(bullet: Node) -> void:
	if _is_remote_proxy or bullet == null:
		return
	var coop_rt = get_node_or_null("/root/CoopRuntime")
	if coop_rt == null or not coop_rt.has_method("broadcast_enemy_bullet"):
		return
	var spr_idx: int = int(bullet.get("bullet_sprite_index")) if "bullet_sprite_index" in bullet else -1
	var kingdom: String = str(bullet.get("enemy_kingdom")) if "enemy_kingdom" in bullet else ""
	coop_rt.broadcast_enemy_bullet(bullet.global_position, bullet.direction, bullet.speed, bullet.damage, spr_idx, kingdom)
