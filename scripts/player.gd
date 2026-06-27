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
var peer_owner_id: int = 1
var player_slot_index: int = 0
var replicated_proxy: bool = false
var _dead: bool = false
# Death recap — captured every time take_damage runs so the death screen can
# show "Killed by Skeleton Captain: Sword Slash, 14 damage" instead of leaving
# the player guessing what killed them. Cleared on respawn.
var _last_damage_source_name: String = ""
var _last_damage_attack_name: String = ""
var _last_damage_amount: int = 0

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

# Class meter (0-100). Per-class identity (Phase 1 redesign):
#   Warrior   "rage"       — builds on damage TAKEN (+0.25%/HP, 0.5s grace).
#                            Fuels dash/dash-burst (+0.4%/stack), weapon dmg (+0.3%/stack),
#                            and reduces Iron Skin / Shield Bash MP cost 1:1.
#                            X: Blood Dream — 30s vampiric trance, banked HP restore + end debuff.
#   Mercenary "adrenaline" — +1 crit, +5 parry, +2 kill, +15 weapon-swap.
#                            +0.5%/stack fire rate (max +50%) and +0.15%/stack crit chance.
#                            X: Reckless Strike — 30s glass-cannon (50% evade, 2× dmg taken,
#                            +50% fire rate, 5% on-hit stun, full stamina refill).
#   Archer    "focus"       — builds passively in combat when clean (6/s walking, 12/s stationary).
#                            +5/kill. -15% + 3s lockout on damage taken. Decays out of combat.
#                            ≥75 grants +20% bullet speed/range; 50-74 grants +10%/+10%.
#                            X: Killshot — 3×–5× crit pierce 3, available at focus ≥60, drains bar.
#   Wizard    "mana_flow"   — +4/cast, +2/spell-kill, +1/s while MP>50%.
#                            Spend mana flow to fire EMPOWERED versions of spells.
#                            X: Overflow — 6s of free empowered casts + 3× cooldown speed.
var class_meter: float = 0.0
var class_meter_max: float = 100.0
var _rage_decay_grace: float = 0.0
signal class_meter_changed(value: float, max_value: float)

# Warrior Rage — only count one damage instance per ~0.5s so heavy hits aren't double-dipped.
var _rage_damage_grace: float = 0.0
# Warrior Rampage (X-press spend at 30-99 rage). Mirrors the Killshot model:
# partial-bar spend for a short power-burst; full bar (100) still triggers
# Blood Dream as the proper ult.
const RAMPAGE_MIN_RAGE := 30.0
const RAMPAGE_DURATION := 4.0
const RAMPAGE_FIRE_RATE_BONUS := 0.75              # +75% fire/swing rate
const RAMPAGE_DAMAGE_BONUS := 0.25                 # +25% damage on top of weapon
const RAGE_SPLASH_MIN := 50.0                      # melee swings AoE-splash above this
const RAGE_SPLASH_RADIUS := 24.0
const RAGE_SPLASH_DMG_PCT := 0.5                   # splash deals 50% of bullet damage

# Warrior Blood Dream (X) — vampiric trance state.
var _blood_dream_active: bool = false
var _blood_dream_until: float = 0.0
var _blood_dream_banked_hp: int = 0
var _blood_dream_heal_budget: float = 0.0      # caps lifesteal to ~30% max HP/sec
var _blood_dream_heal_budget_until: float = 0.0 # 1-second window for the cap
const BLOOD_DREAM_DURATION := 30.0
const BLOOD_DREAM_LIFESTEAL_CAP_PCT := 0.30     # 30% max HP per second
const BLOOD_DREAM_END_PARALYZE := 3.0
const BLOOD_DREAM_END_SLOW := 6.0
const BLOOD_DREAM_RAGE_LEFTOVER := 20.0

# Mercenary Reckless Strike (X) — glass-cannon timer.
var _reckless_strike_until: float = 0.0
const RECKLESS_STRIKE_DURATION := 30.0
const RECKLESS_STRIKE_EVASION := 0.5            # 50% chance to dodge
const RECKLESS_STRIKE_DMG_TAKEN_MULT := 2.0     # landed hits deal 2× damage
const RECKLESS_STRIKE_FIRE_RATE_BONUS := 0.50   # +50% fire rate on top of meter
const RECKLESS_STRIKE_STUN_CHANCE := 0.05       # 5% per hit
const RECKLESS_STRIKE_STUN_DURATION := 0.5

# Archer Focus — regen / lockout state.
var _archer_focus_lockout: float = 0.0          # 3s after taking damage, no regen
var _archer_shoot_grace: float = 0.0            # ticks down; if >0, you are "shooting" (not aiming down sights)
# On-player visual that shows the Killshot is queued. Spawned when X is pressed
# at ≥60 focus, freed automatically when the next bullet consumes the meta.
var _killshot_indicator: Node2D = null
const ARCHER_FOCUS_LOCKOUT := 3.0
const ARCHER_FOCUS_REGEN_BASE := 6.0            # /sec while in combat, no damage
const ARCHER_FOCUS_REGEN_STATIONARY := 12.0     # /sec while standing still and not shooting
const ARCHER_FOCUS_OOC_DECAY := 10.0            # out of combat: drains to 0 in ~10s
const ARCHER_FOCUS_DAMAGE_PENALTY_PCT := 0.15   # 15% of max meter lost per damage instance
const ARCHER_FOCUS_KILL_BONUS := 5.0            # restore on kill (also works during lockout)
const ARCHER_COMBAT_RADIUS := 600.0
const ARCHER_STATIONARY_VEL_THRESHOLD := 5.0
const KILLSHOT_MIN_FOCUS := 60.0
const KILLSHOT_BASE_MULT := 3.0                 # at 60 focus → 3 + 60/100 × 2 = 4.2×
const KILLSHOT_PER_FOCUS_MULT := 2.0            # at 100 focus → 5×
const KILLSHOT_PIERCE_COUNT := 3

# Wizard Mana Flow — passive regen window + empowered-cast state.
var _wizard_mp_regen_passive_accum: float = 0.0  # +1 per second while MP > 50%
var _empowered_cast_pending: bool = false        # true for one spell when empowerment triggered
var _wizard_overflow_until: float = 0.0          # X-key window
# Bullet shield (wizard H spell) — pure member vars instead of meta so the
# state can never get orphaned on respawn / scene reload.
var _bullet_shield_charges: int = 0
var _bullet_shield_until: float = 0.0
# Child Sprite2D that renders the looping bullet_Shield / bullet_Shield_2
# flipbook on the player while the shield is active. We hold the ref here so
# the watchdog can free it the instant the charges expire or the timer runs
# out — no orphaned visuals after the shield dies.
var _bullet_shield_sprite: Sprite2D = null
# Watchdog for the `invincible` flag — without this, a failed tween callback
# (scene change mid-blink) can leave the player permanently untargetable.
var _invincible_until: float = 0.0
const WIZARD_MANAFLOW_PER_CAST := 4.0
const WIZARD_MANAFLOW_PER_SPELL_KILL := 2.0
const WIZARD_MANAFLOW_PASSIVE_PER_SEC := 1.0
const WIZARD_OVERFLOW_DURATION := 10.0
const WIZARD_OVERFLOW_COOLDOWN_MULT := 3.0
const WIZARD_OVERFLOW_DAMAGE_BUFF := 0.40  # +40% damage to spells + shots during Overflow
const WIZARD_MANAFLOW_REGEN_MAX_BONUS := 4.0  # +0..4 MP/s on top of base, scaled by class_meter %
# Empowerment cost per spell ID (Mana Flow consumed in addition to MP).
# Cheaper for utility, higher for game-changers. Empty value = empowerment unavailable.
const WIZARD_EMPOWERMENT_COSTS := {
	"fireball_spell": 40,
	"frost_nova": 35,
	"heal": 25,
	"greater_heal": 40,
	"chain_lightning": 45,
	"arrow_rain": 35,
	"battle_cry": 30,
	"shadow_strike": 40,
	"stone_toss": 20,
	"life_drain": 35,
	"mana_surge": 30,
}

# Lock-on: TAB cycles to nearest enemy in front; press again to cycle next or release.
var _lock_on_target: Node2D = null
# Tracks whether the lock-on reticle was drawn last frame. Used to detect the
# transition from "had target" → "target gone" without a state=DEAD check, so
# we can fire one final queue_redraw and wipe the stale corner-brackets.
var _had_lock_prev: bool = false
const LOCK_ON_MAX_RANGE := 360.0
const LOCK_ON_CYCLE_RANGE := 240.0
const LOCK_ON_DOUBLE_TAP_WINDOW := 0.28
var _last_lock_on_press_time: float = -1.0
var _lock_on_suppressed: bool = false

# Shield block (Warrior)
var _shield_active: bool = false
var _shield_charges: int = 30  # each hit costs 1 charge regardless of damage
var _shield_max_charges: int = 30
var _shield_regen_delay: float = 0.0
var _shield_regen_accum: float = 0.0
var _shield_broken: bool = false
var _shield_break_stun: float = 0.0
var _shield_raise_cooldown: float = 0.0  # delay after lowering before can raise again
var _last_offhand_type: String = ""
const SHIELD_RAISE_DELAY = 0.35  # parry-stick / fallback delay
const SHIELD_RAISE_DELAY_BIG = 0.9  # heavy shield (warrior native) — slower to toggle
const SHIELD_RAISE_DELAY_LIGHT = 0.30  # buckler — snappy but you can't mash through it
const BUCKLER_STAMINA_COST = 12.0  # each buckler tap takes a real bite of stamina
const SHIELD_REGEN_RATE = 1.5  # charges per second (~20s for full recharge)
const SHIELD_SPEED_MULT = 0.3
const SHIELD_BREAK_STUN_TIME = 0.5
const SHIELD_BROKEN_COOLDOWN = 6.0  # 6s lockout after shield breaks
signal shield_changed(shield_hp: int)

# Weapon swap (Mercenary/Ranger)
var _secondary_weapon: EquipmentItem = null

# Off-hand throw — when a secondary weapon is equipped, R/TAB throws it as a
# bullet-clearing projectile instead of triggering a parry.
var _offhand_throw_cooldown: float = 0.0
const OFFHAND_THROW_COOLDOWN := 0.6
const OFFHAND_THROW_STAMINA := 16.0  # each parrying-dagger throw is a meaningful commit
const OFFHAND_THROW_SPEED := 380.0  # slower, feels like a thrown blade not a bullet
const OFFHAND_THROW_LIFETIME := 0.95  # slightly longer life to keep range reasonable
const OFFHAND_BULLET_DESTROY_LIMIT := 4  # native parrying dagger clears a 2-3 bullet path comfortably
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
const DOUBLE_TAP_SPRINT_WINDOW = 0.5  # seconds between two taps of the same direction to start sprinting

var _last_move_tap_time: Dictionary = {"move_up": -1.0, "move_down": -1.0, "move_left": -1.0, "move_right": -1.0}
var _double_tap_sprint: bool = false
var _is_sprinting: bool = false
var _sneaking: bool = false
var _pushing: bool = false  # hold Ctrl/Cmd to brace and shove enemies
var _stealth_kill_cooldown: float = 0.0
const STEALTH_KILL_COOLDOWN = 1.0
const STEALTH_KILL_RANGE = 28.0
const AMBUSH_DAMAGE_MULT = 2.5

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
const CHARGE_FLAT_DMG = 180  # flat bonus damage at full charge (added on top of multiplied base). Phase 1 ×12.
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
# Push mode (hold Ctrl/Cmd): braced, slow, more inertia, can shove enemies sustainedly
const PUSH_SPEED_MULT = 0.55  # 55% move speed while pushing
const PUSH_ACCEL_MULT = 0.35  # 35% acceleration -> heavy inertia
const PUSH_FORCE = 110.0      # per-tick push force vs enemies (vs 50 default)
const PUSH_BOSS_RECOIL = 35.0 # boss pushback applied to player per contact tick
const DUNGEON_MOVE_SCALE = 0.25
const DUNGEON_PROJECTILE_SCALE = 0.25

# Parry mechanic
var _parry_window: float = 0.0
const PARRY_WINDOW_TIME = 0.26  # total window: perfect (0.14s) + late (0.12s)
const PARRY_WINDOW_LATE = 0.12  # final 0.12s = "late parry" — blocks but skips bonuses
const PARRY_STAMINA_COST_PCT = 0.20  # tap-parry costs 20% max stamina; refunded on successful block

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
	if gm and gm.has_method("load_perk_data"):
		gm.load_perk_data()
	# Add perk tree UI if not already present
	if not get_tree().get_first_node_in_group("perk_tree_screen"):
		var pts = PerkTreeScreen.new()
		pts.add_to_group("perk_tree_screen")
		get_tree().current_scene.add_child.call_deferred(pts)

	# Load saved equipment, or give starting items if first time
	var loaded_equip = false
	if gm and gm.save_data and gm.has_method("load_equipment"):
		loaded_equip = gm.load_equipment(equipment_manager)
	if not loaded_equip and equipment_manager.inventory.is_empty() and equipment_manager.equipped.is_empty():
		_give_starting_items()
	# Always apply the class action-bar layout — fresh characters get their
	# weapon + pots auto-placed, and existing characters with stale legacy
	# defaults (Apple + Red Potion in slots 0/1) get force-corrected to the
	# new layout. Customisations the player made past slot 4 stay intact.
	call_deferred("_apply_class_action_bar_defaults")
	if gm and gm.has_method("apply_pending_legacy_equipment"):
		gm.apply_pending_legacy_equipment(equipment_manager)
	# Restore secondary weapon for mercenary/ranger weapon swap
	if gm and gm.save_data and gm.save_data.secondary_weapon_path != "":
		var sec_res = load(gm.save_data.secondary_weapon_path) as EquipmentItem
		if sec_res:
			_secondary_weapon = sec_res.make_copy()
	_refresh_offhand_state()

	# Load spellbook AND always run the starter pass — _setup_starter_spells is
	# additive (idempotent on learn, only fills empty slots), so existing
	# wizards pick up newly-added starters (lightning_x, arcane_familiar,
	# inferno_lance) without losing their custom bindings.
	if gm and gm.has_method("load_spellbook"):
		gm.load_spellbook(spell_book)
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

func configure_peer_owner(owner_peer_id: int, slot_index: int = 0, proxy: bool = false) -> void:
	peer_owner_id = max(owner_peer_id, 1)
	player_slot_index = max(slot_index, 0)
	replicated_proxy = proxy

func is_local_controlled() -> bool:
	var coop = get_node_or_null("/root/CoopSession")
	if coop == null or not coop.has_method("is_multiplayer_active") or not coop.is_multiplayer_active():
		return true
	if replicated_proxy:
		return false
	return multiplayer.get_unique_id() == peer_owner_id

func is_dead() -> bool:
	return _dead

# Coop: compact snapshot for remote ghosts. CoopRuntime calls this at 20 Hz on the
# locally-controlled player only. Dir is PlayerAnimator.Dir (RIGHT/DOWN/UP/LEFT) and
# anim_state is PlayerAnimator.AnimState — ghost feeds these into its own animator.
func get_network_state() -> Dictionary:
	var dir_v: int = 0
	var anim_v: int = 0
	if _player_anim:
		dir_v = int(_player_anim._dir)
		anim_v = int(_player_anim._state)
	return {
		"pos": global_position,
		"dir": dir_v,
		"anim": anim_v,
	}

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
	var perk_tree = get_tree().get_first_node_in_group("perk_tree_screen")
	if perk_tree and perk_tree is CanvasLayer and perk_tree.visible:
		return true
	# Check CraftingUI, ShopUI, EnchantUI, SpellCraftUI (SpellBookUI removed —
	# spells live in the inventory now)
	for ui_name in ["crafting_ui", "shop_ui", "enchant_ui", "spell_craft_ui", "world_map", "chest_ui"]:
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

	# Parry window countdown. When it expires:
	#   - Clear the "first-parry" flag so the next raise can pay heal/meter bonuses
	#   - Auto-drop the buckler (timer-free — no race when spamming taps)
	if _parry_window > 0:
		_parry_window -= delta
		if _parry_window <= 0:
			if has_meta("parry_bonuses_consumed"):
				remove_meta("parry_bonuses_consumed")
			# Buckler: shield_active is gated entirely on parry_window
			if _shield_active and equipment_manager \
					and equipment_manager.get_equipped_offhand_type() == "buckler":
				_shield_active = false

	# Off-hand throw cooldown
	if _offhand_throw_cooldown > 0:
		_offhand_throw_cooldown -= delta

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

	# Stamina regen — 2× rate when standing absolutely still (no input + no attack)
	if _stamina_regen_delay > 0:
		_stamina_regen_delay -= delta
	elif stamina < max_stamina:
		var regen_rate = equipment_manager.get_stamina_regen()
		var has_move_input = false
		if touch_controls and touch_controls.visible:
			has_move_input = touch_controls.get_move_input().length() > 0.1
		else:
			has_move_input = (
				Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")
				or Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down")
			)
		var has_attack_input = (
			Input.is_action_pressed("shoot")
			or (touch_controls and touch_controls.visible and touch_controls.get_aim_input().length() > 0.1)
		)
		var is_idle = (
			not has_move_input
			and not has_attack_input
			and not _is_dashing
			and not _is_sprinting
			and velocity.length() < 1.0
		)
		if is_idle:
			regen_rate *= 2.0
		stamina = minf(stamina + regen_rate * delta, max_stamina)
		stamina_changed.emit(stamina)

	# MP regen (slow, delayed after use). For wizard, the class_meter ("Mana
	# Flow") scales regen up to +4 MP/s at full meter — so the more you cast,
	# the faster you regen. That's the new identity instead of an X-key dump.
	if _mp_regen_delay > 0:
		_mp_regen_delay -= delta
	elif mp < max_mp:
		var mp_rate = MP_REGEN_RATE_WIZARD if _get_player_class() == "wizard" else MP_REGEN_RATE
		if _get_player_class() == "wizard" and class_meter_max > 0.0:
			mp_rate += WIZARD_MANAFLOW_REGEN_MAX_BONUS * (class_meter / class_meter_max)
		mp = minf(mp + mp_rate * delta, max_mp)
		mp_changed.emit(mp)

	# Per-class meter dynamics. Each class now has a distinct identity here.
	_tick_class_meter(delta)
	# Per-class trance/burst timers (Blood Dream, Reckless Strike, Overflow).
	_tick_class_meter_buffs(delta)
	# Warrior 0.5s grace between damage instances (so heavy hits don't double-charge rage).
	if _rage_damage_grace > 0.0:
		_rage_damage_grace = maxf(0.0, _rage_damage_grace - delta)
	# Archer "are you shooting?" grace — set on every try_shoot call, decays fast.
	if _archer_shoot_grace > 0.0:
		_archer_shoot_grace = maxf(0.0, _archer_shoot_grace - delta)

	# Handle lingering i-frames after dash
	if _dash_linger > 0:
		_dash_linger -= delta
		if _dash_linger <= 0:
			invincible = false
			sprite.modulate.a = 1.0
			# Restore enemy collision once the dash + linger window finishes
			set_collision_mask_value(2, true)

	# Handle active dash
	if _is_dashing:
		_dash_timer -= delta
		# Warrior: collision with an *enemy* triggers AoE burst and ends dash.
		# Walls do NOT end the dash — the dash slides along them so the warrior
		# can still trigger his end-of-dash AoE even when starting against a wall.
		var pc_dash = _get_player_class()
		var warrior_collide := false
		if pc_dash == "warrior":
			for si in range(get_slide_collision_count()):
				var col = get_slide_collision(si)
				var collider = col.get_collider() if col else null
				if collider and collider.is_in_group("enemy"):
					warrior_collide = true
					break
		if _dash_timer <= 0 or warrior_collide:
			_is_dashing = false
			_lunge_active = false
			_dash_hit_enemies.clear()
			if _player_anim and _player_anim._state == PlayerAnimator.AnimState.DASH:
				_player_anim.set_state(PlayerAnimator.AnimState.IDLE)
			# Axe: cleave AoE on dash landing
			if _dash_cleave_pending:
				_dash_cleave_pending = false
				_ability_blade_flurry()
			# Warrior: burst AoE on dash end (no i-frames). Restore enemy collision immediately.
			if pc_dash == "warrior":
				_warrior_dash_burst()
				sprite.modulate.a = 1.0
				set_collision_mask_value(2, true)
			else:
				_dash_linger = DASH_LINGER_TIME
				var tween = create_tween()
				tween.tween_property(sprite, "modulate:a", 1.0, DASH_LINGER_TIME)
		else:
			var dash_speed_mod = 0.5 if _shield_active else 1.0  # slower dash while shielding
			velocity = _dash_direction * equipment_manager.get_move_speed() * _get_scene_motion_scale() * DASH_SPEED_MULT * dash_speed_mod
			move_and_slide()
			# Dash push: shove enemies we collide with during dash
			var player_w_d = get_weight()
			for si_d in range(get_slide_collision_count()):
				var col_d = get_slide_collision(si_d)
				var coll_d = col_d.get_collider()
				if coll_d and coll_d.is_in_group("enemies") and coll_d is CharacterBody2D:
					var ew: float = float(coll_d.get("_weight")) if coll_d.get("_weight") != null else 1.0
					var push_d = _dash_direction * 250.0 * player_w_d / ew
					var pushed_velocity = coll_d.get("_pushed_velocity")
					if pushed_velocity != null:
						coll_d.set("_pushed_velocity", pushed_velocity + push_d)
					else:
						coll_d.velocity += push_d
					if coll_d.get("_contact_bounce") != null:
						coll_d.set("_contact_bounce", 0.3)
			_dash_strike_check()
			# Spawn afterimages + trail lines during dash
			var vfx2 = get_node_or_null("/root/VFXManager")
			if vfx2 and Engine.get_physics_frames() % 2 == 0:
				vfx2.dash_afterimage(sprite, global_position, null, z_index - 1)
				vfx2.dash_trail_lines(global_position, _dash_direction, sprite.scale, null, z_index - 1)
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
	elif _wtype == "staff":
		# Wizard mobility on Space: tap → teleport (mirrors other classes' dash
		# on Space). Costs MP, not stamina. Charge-shot is now on hold-Shift —
		# handled in the staff-charge block further down.
		if Input.is_action_just_pressed("dash") and _teleport_cooldown <= 0 and mp >= 8.0:
			_staff_teleport_active = true
			use_mp(8.0)
			_ability_teleport()
			_teleport_cooldown = 0.5

	# Shield block — R key TOGGLE (press to raise, press again to lower).
	# Requires shield item + melee weapon equipped.
	if _shield_raise_cooldown > 0:
		_shield_raise_cooldown -= delta
	# A shield/buckler item in the SHIELD slot counts as equipped regardless of
	# which weapon is currently held. (Previously this required a melee weapon,
	# which meant a mercenary holding their bow silently fell back to the slower
	# parry-stick branch — felt like a delay.)
	# A real shield or buckler is in the offhand. Parrying daggers also live in
	# the SHIELD slot but they're handled by the throw branch below — they don't
	# raise a shield, don't slow movement, don't follow the cursor.
	var _offhand_item = equipment_manager.equipped.get(EquipmentItem.SlotType.SHIELD, null) as EquipmentItem
	var _has_shield_equipped = _offhand_item != null and _offhand_item.weapon_type != "parrying_dagger"
	var was_shielding = _shield_active
	if _has_shield_equipped and Input.is_action_just_pressed("shield_raise") and _shield_raise_cooldown <= 0:
		var off_type = equipment_manager.get_equipped_offhand_type() if equipment_manager else ""
		var prof = equipment_manager.get_offhand_proficiency_mult(_get_player_class()) if equipment_manager else 1.0
		if off_type == "buckler":
			# Buckler tap-parry. Costs 20% max stamina up front — refunded on a
			# successful block (see take_damage parry block). Active state gated
			# entirely on _parry_window > 0 (no timer races).
			var tap_cost = max_stamina * PARRY_STAMINA_COST_PCT
			if not _shield_broken and _shield_charges > 0 and stamina >= tap_cost:
				_shield_active = true
				_parry_window = PARRY_WINDOW_TIME * prof
				_shield_raise_cooldown = SHIELD_RAISE_DELAY_LIGHT
				stamina = maxf(stamina - tap_cost, 0.0)
				_stamina_regen_delay = 0.3
				stamina_changed.emit(stamina)
				# Track the cost so we can refund the exact amount if the parry lands
				set_meta("parry_pending_refund", tap_cost)
				var sfx_sb = get_node_or_null("/root/SFXManager")
				if sfx_sb:
					sfx_sb.play("clack", -6.0, 0.0)
		else:
			# Heavy shield (warrior native) — toggle hold mode.
			if _shield_active:
				_shield_active = false
				_shield_raise_cooldown = SHIELD_RAISE_DELAY_BIG
				var sfx_sl = get_node_or_null("/root/SFXManager")
				if sfx_sl:
					sfx_sl.play("click", -6.0, 0.0)
			elif not _shield_broken and _shield_charges > 0:
				_shield_active = true
				var sfx_sr = get_node_or_null("/root/SFXManager")
				if sfx_sr:
					sfx_sr.play("clack", -6.0, 0.0)
				_parry_window = PARRY_WINDOW_TIME * prof
	# Auto-drop shield if broken or out of charges — but ONLY when a real shield
	# is equipped. Without this guard, the archer/wizard parry-stick gets killed
	# the same frame it's raised (their _shield_charges is 0 by default).
	if _has_shield_equipped and _shield_active and (_shield_broken or _shield_charges <= 0):
		_shield_active = false
		var off_type_drop = equipment_manager.get_equipped_offhand_type() if equipment_manager else ""
		_shield_raise_cooldown = SHIELD_RAISE_DELAY_BIG if off_type_drop == "shield" else SHIELD_RAISE_DELAY
	if _shield_active:
		_update_shield_visual(true)
	else:
		_update_shield_visual(false)
		if _has_shield_equipped and was_shielding:
			sprite.modulate = Color.WHITE

	# Stone toss (T key) — throw distraction stone (charge-based)
	if Input.is_action_just_pressed("stone_toss") and _stone_toss_charges > 0:
		_stone_toss()
		_stone_toss_charges -= 1

	var _pc_wrestle = _get_player_class()

	# Off-hand action is decided by the equipped SHIELD-slot item:
	#   Parrying Dagger → throw (bullet-clear + chip damage)
	#   any shield/buckler → toggle shield + parry (handled in the shield block above)
	#   nothing equipped → wrestle (warrior/merc melee) OR parry-stick (wizard etc.)
	var _shield_slot_item: EquipmentItem = equipment_manager.equipped.get(EquipmentItem.SlotType.SHIELD, null) if equipment_manager else null
	var _has_parrying_dagger = _shield_slot_item != null and _shield_slot_item.weapon_type == "parrying_dagger"

	if _has_parrying_dagger \
			and Input.is_action_just_pressed("shield_raise") \
			and _offhand_throw_cooldown <= 0.0 \
			and stamina >= OFFHAND_THROW_STAMINA:
		_throw_secondary(_shield_slot_item)
		return

	# Wrestling grab — warrior/merc with melee weapon (no shield/dagger equipped).
	var _can_wrestle = (_pc_wrestle == "warrior" or _pc_wrestle == "mercenary") and _cur_slot == EquipmentItem.SlotType.WEAPON_MELEE
	if _can_wrestle and Input.is_action_just_pressed("shield_raise") and _wrestle_cooldown <= 0 and not _has_shield_equipped:
		_wrestle_grab()
		_wrestle_cooldown = WRESTLE_COOLDOWN
		return

	# Parrying-stick: archer/ranger only get the stick if they DON'T have a
	# parrying-dagger equipped (rare edge case). Wizard has no parry — they're
	# a spellcaster, their R should do nothing if no offhand item is held.
	# Warrior/Mercenary fall back to the stick if holding ranged with no offhand.
	var _stick_classes = ["ranger", "archer"]
	var _can_parry_stick = (_pc_wrestle in _stick_classes \
			or (_pc_wrestle == "mercenary" and not _has_shield_equipped) \
			or (_pc_wrestle == "warrior" and _cur_slot != EquipmentItem.SlotType.WEAPON_MELEE and not _has_shield_equipped)) \
			and not _has_parrying_dagger
	if _can_parry_stick \
			and Input.is_action_just_pressed("shield_raise") \
			and not _has_shield_equipped \
			and _shield_raise_cooldown <= 0:
		_shield_active = true
		_parry_window = PARRY_WINDOW_TIME * 0.7  # shorter window than warrior
		_shield_raise_cooldown = 0.6
		# Auto-drop the stick after the window closes
		var stick_timer = get_tree().create_timer(0.18) if get_tree() else null
		if stick_timer:
			stick_timer.timeout.connect(func():
				if is_instance_valid(self):
					_shield_active = false)
		var sfx_ps = get_node_or_null("/root/SFXManager")
		if sfx_ps:
			sfx_ps.play("clack", -8.0, 0.0)
		# Visual: brief blue tick on the sprite so the player SEES the parry try
		# (no text popup — keep it subtle)
		if sprite:
			var ps_tween = create_tween()
			ps_tween.tween_property(sprite, "modulate", Color(0.6, 0.85, 1.0), 0.04)
			ps_tween.tween_property(sprite, "modulate", Color.WHITE, 0.16)

	# Lock-on (TAB)
	#   single tap: acquire / cycle target
	#   fast double tap: clear lock
	if Input.is_action_just_pressed("lock_on"):
		var now_lock := Time.get_ticks_msec() / 1000.0
		if _last_lock_on_press_time > 0.0 and now_lock - _last_lock_on_press_time <= LOCK_ON_DOUBLE_TAP_WINDOW:
			_lock_on_target = null
			_lock_on_suppressed = true
			_last_lock_on_press_time = -1.0
			queue_redraw()
		else:
			_last_lock_on_press_time = now_lock
			_lock_on_suppressed = false
			_cycle_lock_on()

	# Class-meter full move (X key) — fires when class_meter is full, consumes it
	if Input.is_action_just_pressed("class_meter_use"):
		# Archer Killshot fires at >=60 focus (partial-charge shot).
		# Warrior Rampage fires at >=30 rage (Blood Dream stays at 100, branched inside the unleash).
		# Everyone else still needs a full meter.
		var pc_x = _get_player_class()
		var min_needed = class_meter_max
		if pc_x == "archer" or pc_x == "ranger":
			min_needed = KILLSHOT_MIN_FOCUS
		elif pc_x == "warrior":
			min_needed = RAMPAGE_MIN_RAGE
		if class_meter >= min_needed:
			_unleash_class_meter_move()
		else:
			# Deny feedback so the press isn't a silent no-op. Tells the player
			# how much more meter they need (or just "NOT READY" for non-archers).
			var _sfx_d = get_node_or_null("/root/SFXManager")
			if _sfx_d:
				_sfx_d.play("error", -8.0, 0.05)
			var _root_d = get_tree().current_scene if is_inside_tree() else null
			if _root_d:
				var needed_pts = int(ceil(min_needed - class_meter))
				var msg = ("+%d FOCUS" % needed_pts) if (pc_x == "archer" or pc_x == "ranger") else "NOT READY"
				FloatingText.spawn(_root_d, global_position + Vector2(0, -18), msg, Color(0.85, 0.85, 0.85))
	# Refresh reticle every frame while locked (target moves)
	if is_instance_valid(_lock_on_target):
		queue_redraw()
	# Track whether the player had a target last frame — if so, we want to
	# auto-relock when it dies/leaves rather than silently dropping.
	var _had_lock = is_instance_valid(_lock_on_target)
	if _had_lock:
		var d = global_position.distance_to(_lock_on_target.global_position)
		var dead = false
		if _lock_on_target.has_method("get") and "state" in _lock_on_target:
			dead = _lock_on_target.state == _lock_on_target.State.DEAD
		if dead or d > LOCK_ON_MAX_RANGE:
			_lock_on_target = null
			# Try to find another on-screen enemy automatically. If nothing
			# qualifies, the lock just releases as before.
			_auto_relock()
			queue_redraw()
	else:
		# Target became invalid without going through the dead/out-of-range
		# branch above (e.g. queue_free from explode-on-death, scene transition,
		# parent removal). We still need a queue_redraw to wipe the stale
		# reticle that _draw painted on the previous frame. _had_lock_prev
		# tracks "did we draw a reticle last frame?" to fire that one redraw.
		if _had_lock_prev:
			_lock_on_target = null
			_auto_relock()
			queue_redraw()
		else:
			_lock_on_target = null
	_had_lock_prev = is_instance_valid(_lock_on_target)

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
	# Staff: hold Shift to charge a powershot, release to fire. (Teleport moved
	# to Space — see SPACE-abilities block.) The actual charge accumulator and
	# stamina drain run in the dedicated staff-charge block further down.
	elif _wtype == "staff" and Input.is_action_pressed("sprint"):
		pass  # charge logic owns the rest; this branch keeps the elif chain intact
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
	# Staff Powershot — hold SHIFT to charge, release to fire. Matches the
	# other classes' "special on Shift" pattern. Stamina drains during the
	# channel; player stands still while charging. Releases on key-up or when
	# stamina hits zero.
	if _wtype == "staff":
		var _can_start_charge = not _charge_active and stamina >= 21
		var _can_continue_charge = _charge_active and stamina > 0
		if Input.is_action_pressed("sprint") and (_can_start_charge or _can_continue_charge):
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
			var drain = (max_stamina / CHARGE_MAX_TIME) * delta
			stamina = maxf(stamina - drain, 0.0)
			_stamina_regen_delay = 0.5
			stamina_changed.emit(stamina)
			_update_charge_indicator()
			if stamina <= 0 and _charge_active:
				_release_staff_charge(true)
		elif _charge_active:
			# Released — sub-min taps cancel, real charges fire.
			_release_staff_charge(false)

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

	# Unified action bar: 10 slots, each can hold either an item or a spell.
	# Hotkeys map: quickbar_1..3 → slots 0..2, spell_slot_1..7 → slots 3..9
	# (key labels 1,2,3,4,5,6,7,8,9,0). The router checks item first, then spell.
	for qi in range(3):
		if Input.is_action_just_pressed("quickbar_%d" % (qi + 1)):
			_on_action_bar_pressed(qi)
	for si in range(7):
		if Input.is_action_just_pressed("spell_slot_%d" % (si + 1)):
			_on_action_bar_pressed(3 + si)

	# B key (spellbook) — removed: spells live in the inventory grid now.
	# The action binding stays in project.godot but the press is intentionally
	# a no-op; press I and look for the purple spell tiles instead.

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

	# Push mode (hold Ctrl / Cmd) — braced, no transparency, can shove enemies
	var push_pressed: bool = Input.is_action_pressed("push_mode") and not _is_dashing and not _shield_active
	if push_pressed and not _pushing:
		var sfx_pu = get_node_or_null("/root/SFXManager")
		if sfx_pu:
			sfx_pu.play("click", -8.0)
	_pushing = push_pressed
	if _pushing:
		_sneaking = false  # push cancels sneak (mutually exclusive)
	# Sneak drains stamina slowly (reduced by STEALTH stat, or free with "ghost" perk)
	if _sneaking:
		if stamina <= 0 or _is_dashing:
			var _pm = get_node_or_null("/root/PerkManager")
			if not (_pm and _pm.has_special("ghost")):
				_sneaking = false
		else:
			var _pm = get_node_or_null("/root/PerkManager")
			if not (_pm and _pm.has_special("ghost")):
				# stealth_stat is 0-1 (0.15 = 15%). Caps at 0.6 = 60% drain cut.
				var stealth_stat = equipment_manager.get_stealth()
				var sneak_drain = SNEAK_STAMINA_BASE_DRAIN * (1.0 - clampf(stealth_stat, 0.0, 0.6))
				stamina = maxf(stamina - sneak_drain * delta, 0.0)
				_stamina_regen_delay = 0.5
				stamina_changed.emit(stamina)
	# Sneak visual
	if _sneaking:
		sprite.modulate.a = 0.5
	elif not _is_dashing and _dash_linger <= 0 and not _shield_active:
		sprite.modulate.a = 1.0

	# Stealth kill cooldown
	if _stealth_kill_cooldown > 0:
		_stealth_kill_cooldown -= delta
	# Stealth kill (E key while sneaking behind unaware enemy)
	if _sneaking and _stealth_kill_cooldown <= 0 and Input.is_action_just_pressed("interact"):
		_try_stealth_kill()

	# Sprint:
	#   1) Double-tap any WASD direction within 0.5 s → start sprinting (works
	#      regardless of weapon — this is the main path now)
	#   2) Hold SHIFT also sprints, but only for weapons without a shift ability
	#      (short_bow / unarmed). All other weapons consume SHIFT as their special.
	_update_double_tap_sprint()

	_is_sprinting = false
	var _sprint_weapons = ["short_bow", ""]
	var _has_shift_ability = _wtype != "" and _wtype not in _sprint_weapons
	var shift_sprint_held = Input.is_action_pressed("sprint") and not _has_shift_ability
	var sprint_pressed = shift_sprint_held or _double_tap_sprint
	if sprint_pressed and direction.length() > 0 and stamina > 0 and not _is_dashing and not _shield_active and not _pushing:
		_is_sprinting = true
		_sneaking = false  # sprinting cancels sneak
		stamina = maxf(stamina - SPRINT_STAMINA_DRAIN * delta, 0.0)
		_stamina_regen_delay = 0.5
		stamina_changed.emit(stamina)
		if stamina <= 0:
			_is_sprinting = false
			_double_tap_sprint = false
	if not _is_sprinting:
		# Lose the double-tap latch the moment movement stops, so a single tap
		# next direction change doesn't start a free sprint.
		if direction.length() <= 0.0 or stamina <= 0:
			_double_tap_sprint = false

	# Acceleration-based movement. Mercenary takes an extra penalty for shield use.
	var shield_mult = SHIELD_SPEED_MULT if _shield_active else 1.0
	if _shield_active and _get_player_class() == "mercenary":
		shield_mult *= 0.80  # mercenary shields are heavy for them: extra -20% on top
	var buff_speed = (status_effects.get_buff_multiplier("speed") * status_effects.get_buff_multiplier("town_speed")) if status_effects else 1.0
	var sneak_mult = SNEAK_SPEED_MULT if _sneaking else 1.0
	var aimed_mult = 0.5 if _aimed_mode_active else 1.0
	var charge_mult = 0.45 if _charge_active else 1.0  # Staff powershot: slowed (not frozen) while channeling
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

	var push_mult = PUSH_SPEED_MULT if _pushing else 1.0
	var speed_mult = status_effects.get_speed_multiplier() * (SPRINT_SPEED_MULT if _is_sprinting else 1.0) * shield_mult * buff_speed * sneak_mult * push_mult * aimed_mult * charge_mult * stance_mult
	var scene_move_mult = _get_scene_motion_scale()
	var target_velocity = direction * equipment_manager.get_move_speed() * speed_mult * scene_move_mult
	var accel = equipment_manager.get_acceleration()
	if _pushing:
		accel *= PUSH_ACCEL_MULT  # heavier inertia while braced
	velocity = velocity.lerp(target_velocity, accel * delta * 10.0)
	# Apply external push (from enemy contact knockback) — decays quickly, capped
	var _max_push := 200.0
	if _pushed_velocity.length_squared() > _max_push * _max_push:
		_pushed_velocity = _pushed_velocity.normalized() * _max_push
	velocity += _pushed_velocity
	_pushed_velocity *= 0.82  # exponential decay per frame (~60fps = gone in ~0.25s)
	move_and_slide()
	# Noise emission for stealth system
	if direction.length() > 0.1:
		var noise = get_node_or_null("/root/NoiseSystem")
		if noise:
			if _is_sprinting:
				noise.emit_noise(global_position, 100.0, 0.6 * delta)
			elif _sneaking:
				var _pm_n = get_node_or_null("/root/PerkManager")
				if not (_pm_n and _pm_n.has_special("silent_step")):
					noise.emit_noise(global_position, 20.0, 0.05 * delta)
			else:
				noise.emit_noise(global_position, 60.0, 0.3 * delta)
	# Sync 3D first-person camera
	if fps_mode and _first_person_view:
		_first_person_view.update_camera(global_position, fps_angle)
	# Slide collision: push enemies away using center-to-center direction (not slide normal)
	for si in range(get_slide_collision_count()):
		var col = get_slide_collision(si)
		var collider = col.get_collider()
		if not collider or not collider.is_in_group("enemies"):
			continue
		if not collider is CharacterBody2D:
			continue
		# Use center-to-center direction — prevents "slipping to sides" from slide normals
		var push_dir_c: Vector2 = (collider.global_position - global_position).normalized()
		if push_dir_c == Vector2.ZERO:
			push_dir_c = Vector2.RIGHT.rotated(randf() * TAU)
		# Push enemy away — gentle by default, harder on sprint/dash
		var player_w = get_weight()
		var push_force: float = 50.0 * player_w
		if _is_sprinting:
			push_force = 100.0 * player_w
		if _is_dashing:
			push_force = 220.0 * player_w
		if _blade_dance_active or _phalanx_active:
			push_force = 140.0 * player_w
		if _pushing:
			# Braced sustained shove: stronger per-tick force, scales with player weight
			push_force = PUSH_FORCE * player_w
		var enemy_weight: float = float(collider.get("_weight")) if collider.get("_weight") != null else 1.0
		var push_vec = push_dir_c * push_force / enemy_weight
		# Accumulate push so multiple sources don't cancel each other
		var collider_push = collider.get("_pushed_velocity")
		if collider_push != null:
			collider.set("_pushed_velocity", collider_push + push_vec)
		else:
			collider.velocity += push_vec
		# Brief contact_bounce so enemy AI doesn't immediately override the push
		var collider_bounce = collider.get("_contact_bounce")
		if collider_bounce != null and float(collider_bounce) <= 0.0:
			collider.set("_contact_bounce", 0.12)
		# Low-stamina stagger: when winded, heavier foes shove the player back
		if not _is_dashing and not _is_sprinting and not _pushing and enemy_weight > player_w and max_stamina > 0:
			if stamina / max_stamina < 0.25:
				_pushed_velocity += -push_dir_c * 18.0 * enemy_weight / maxf(player_w, 0.5)
		# Push-mode boss recoil: heavy bosses still shove the player back even when braced
		if _pushing and enemy_weight >= 4.0:
			_pushed_velocity += -push_dir_c * PUSH_BOSS_RECOIL * (enemy_weight / 5.0) / maxf(player_w, 0.5)

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

	# Class-conditional ability profiles. Each weapon's SHIFT ability behaves
	# differently for Warrior (heavy/aggressive), Mercenary (versatile baseline),
	# Archer (precise/fast), and Wizard (MP-scaling).
	var _pc_class = _get_player_class()

	# Apply dagger rapid fire mode / aimed mode to weapon system
	if _dagger_rapid_active:
		# Dagger rapid attack — fastest in the kit.
		if _pc_class == "warrior":
			# Warrior wields a dagger like a stab — slower, weighty hits.
			weapon_system.fire_rate_mult = DAGGER_RAPID_FIRE_MULT * 0.7
			weapon_system.crit_bonus = DAGGER_RAPID_CRIT_BONUS * 0.5
			weapon_system.damage_mult = 1.5
		elif _pc_class == "wizard":
			# Wizard rune-dagger: same speed, MP-fueled crit boost.
			weapon_system.fire_rate_mult = DAGGER_RAPID_FIRE_MULT
			weapon_system.crit_bonus = DAGGER_RAPID_CRIT_BONUS + 15.0
			weapon_system.damage_mult = 0.9
		else:
			# Mercenary / Archer (native): existing rapid attack
			weapon_system.fire_rate_mult = DAGGER_RAPID_FIRE_MULT
			weapon_system.crit_bonus = DAGGER_RAPID_CRIT_BONUS
			weapon_system.damage_mult = 1.0
	elif _aimed_mode_active:
		# Crossbow aimed — Archer is the natural user.
		if _pc_class == "archer" or _pc_class == "ranger":
			weapon_system.fire_rate_mult = 0.7
			weapon_system.crit_bonus = 30.0  # extra precision
			weapon_system.damage_mult = 2.2
		elif _pc_class == "warrior":
			# Warrior crossbow: harder hit, slower.
			weapon_system.fire_rate_mult = 0.5
			weapon_system.crit_bonus = 10.0
			weapon_system.damage_mult = 2.6
		else:
			weapon_system.fire_rate_mult = 0.7
			weapon_system.crit_bonus = 20.0
			weapon_system.damage_mult = 2.0
	elif _blade_dance_active:
		# Sword SHIFT — Warrior gets heavy swings, Merc gets the dance, Wizard gets arcane infusion.
		if _pc_class == "warrior":
			# Warrior power swings — slower, harder hits, knockback feel.
			weapon_system.fire_rate_mult = 0.75
			weapon_system.crit_bonus = 5.0
			weapon_system.damage_mult = 1.8
		elif _pc_class == "wizard":
			# Wizard arcane sword — moderate fire rate, big crit chance.
			weapon_system.fire_rate_mult = 1.4
			weapon_system.crit_bonus = 25.0
			weapon_system.damage_mult = 1.0
		else:
			# Mercenary / Archer dancing blade — fast flurry, lower per-hit.
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

	# Suppress Space-based shooting for melee (space=dash) and staff (space=
	# teleport). The "shoot" action is dual-bound to LMB + Space in the input
	# map; without this suppression, pressing Space would teleport AND fire a
	# staff bullet on the same frame.
	var _space_suppressed = _charge_active or _is_dashing or _cur_slot == EquipmentItem.SlotType.WEAPON_MELEE or _wtype == "staff"
	var _is_touch = touch_controls and touch_controls.visible

	if _is_touch and touch_controls.is_shooting():
		# Touch: only right joystick triggers shooting
		var aim_dir = touch_controls.get_aim_input().normalized()
		var _was_sneak_fire = _sneaking
		_sneaking = false  # firing breaks sneak
		var _ns = get_node_or_null("/root/NoiseSystem")
		if _ns: _ns.emit_noise(global_position, 120.0, 0.8)
		if _was_sneak_fire:
			weapon_system.damage_mult *= AMBUSH_DAMAGE_MULT
		weapon_system.try_shoot(global_position, aim_dir)
		if _was_sneak_fire:
			weapon_system.damage_mult /= AMBUSH_DAMAGE_MULT
			FloatingText.spawn(get_parent(), global_position + Vector2(0, -16), "AMBUSH!", Color(1.0, 0.6, 0.1))
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
		var _auto_shoot = is_instance_valid(_lock_on_target) and not _lock_on_suppressed
		if _mouse_shooting or (_kb_shooting and not _space_suppressed) or _auto_shoot:
			var _was_sneak_fire2 = _sneaking
			_sneaking = false  # firing breaks sneak
			var _ns2 = get_node_or_null("/root/NoiseSystem")
			if _ns2: _ns2.emit_noise(global_position, 120.0, 0.8)
			if _was_sneak_fire2:
				weapon_system.damage_mult *= AMBUSH_DAMAGE_MULT
				# Hawkeye perk: stealth attacks always crit
				var _pm_hw = get_node_or_null("/root/PerkManager")
				if _pm_hw and _pm_hw.has_special("hawkeye"):
					weapon_system.crit_bonus += 100.0
			var aim_dir: Vector2
			if fps_mode:
				# FPS: shoot in the direction the camera is facing
				aim_dir = Vector2(cos(fps_angle), sin(fps_angle))
			elif is_instance_valid(_lock_on_target):
				# Lock-on overrides mouse — point at the locked target.
				aim_dir = (_lock_on_target.global_position - global_position).normalized()
			else:
				var mouse_pos = get_global_mouse_position()
				aim_dir = (mouse_pos - global_position).normalized()
			weapon_system.try_shoot(global_position, aim_dir)
			if _was_sneak_fire2:
				weapon_system.damage_mult /= AMBUSH_DAMAGE_MULT
				var _pm_hw2 = get_node_or_null("/root/PerkManager")
				if _pm_hw2 and _pm_hw2.has_special("hawkeye"):
					weapon_system.crit_bonus -= 100.0
				FloatingText.spawn(get_parent(), global_position + Vector2(0, -16), "AMBUSH!", Color(1.0, 0.6, 0.1))
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
	_refresh_offhand_state()

	# Watchdogs for time-bound damage avoidance — without these, a failed
	# tween callback or a respawn can leave you permanently untargetable.
	var now_wd := Time.get_ticks_msec() / 1000.0
	if _bullet_shield_charges > 0 and now_wd >= _bullet_shield_until:
		_bullet_shield_charges = 0
		_bullet_shield_until = 0.0
		_clear_bullet_shield_sprite()
	# If the sprite is alive but the shield is already done (e.g. take_damage
	# zeroed the charges), wipe the visual too.
	elif _bullet_shield_charges <= 0 and is_instance_valid(_bullet_shield_sprite):
		_clear_bullet_shield_sprite()
	if invincible and _invincible_until > 0.0 and now_wd >= _invincible_until:
		invincible = false
		_invincible_until = 0.0
		# If a teleport tween failed to fire its callback, the mask bits stay
		# disabled. Restore them defensively so enemies become solid again.
		if not _is_dashing:
			set_collision_mask_value(2, true)
			set_collision_mask_value(4, true)
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

## Unified passive-effect check: perk OR equipped gear with the enchantment.
func _has_effect(effect_name: String) -> bool:
	var pm = get_node_or_null("/root/PerkManager")
	if pm and pm.has_method("has_special") and pm.has_special(effect_name):
		return true
	if equipment_manager and equipment_manager.has_passive_effect(effect_name):
		return true
	return false

func is_sneaking() -> bool:
	return _sneaking

func _refresh_offhand_state() -> void:
	if equipment_manager == null:
		return
	var off_type := equipment_manager.get_equipped_offhand_type()
	if off_type == _last_offhand_type:
		return
	_last_offhand_type = off_type
	_shield_active = false
	_parry_window = 0.0
	_shield_raise_cooldown = 0.0
	_shield_regen_accum = 0.0
	_shield_broken = false
	_shield_charges = _shield_max_charges
	shield_changed.emit(_shield_charges)
	_update_shield_visual(false)

## Attempt a stealth kill on the nearest valid target
func _try_stealth_kill() -> void:
	var best_enemy: Node2D = null
	var best_dist: float = STEALTH_KILL_RANGE
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.state == enemy.State.DEAD:
			continue
		var d = global_position.distance_to(enemy.global_position)
		if d > STEALTH_KILL_RANGE:
			continue
		# Must be unaware and back exposed
		if not enemy.has_method("get_awareness") or enemy.get_awareness() >= 0.3:
			continue
		if not enemy.has_method("is_back_exposed") or not enemy.is_back_exposed(global_position):
			continue
		if d < best_dist:
			best_dist = d
			best_enemy = enemy
	if not best_enemy:
		return
	var _pm_sk = get_node_or_null("/root/PerkManager")
	var sk_cd = STEALTH_KILL_COOLDOWN
	if _pm_sk and _pm_sk.has_special("predator"):
		sk_cd *= 0.5
	_stealth_kill_cooldown = sk_cd
	# Determine damage based on enemy size
	var size_class = 0
	if best_enemy.definition:
		size_class = best_enemy.definition.size_class
	if size_class == 0:  # NORMAL — instant kill
		best_enemy.take_damage(best_enemy.hp + best_enemy.shield_hp + 999)
	elif size_class == 1:  # LARGE — 4x weapon damage
		var dmg = maxi(equipment_manager.get_damage() * 4, best_enemy._max_hp / 3)
		best_enemy.take_damage(dmg)
	else:  # BOSS — 2x weapon damage
		var dmg = maxi(equipment_manager.get_damage() * 2, best_enemy._max_hp / 6)
		best_enemy.take_damage(dmg)
	# VFX + SFX
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.death_burst(best_enemy.global_position)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("crit", -2.0)
	# Floating text
	FloatingText.spawn(get_parent(), best_enemy.global_position + Vector2(0, -12), "STEALTH KILL!", Color(0.9, 0.2, 0.9))
	# Assassin perk: stealth kills restore stamina
	if _pm_sk and _pm_sk.has_special("assassin"):
		stamina = minf(stamina + 30.0, max_stamina)
		stamina_changed.emit(stamina)
	# Minimal noise from the kill
	var ns = get_node_or_null("/root/NoiseSystem")
	if ns:
		ns.emit_noise(best_enemy.global_position, 40.0, 0.3)

## Get the nearest stealth-killable enemy (for HUD prompt)
func get_stealth_kill_target() -> Node2D:
	if not _sneaking or _stealth_kill_cooldown > 0:
		return null
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.state == enemy.State.DEAD:
			continue
		if global_position.distance_to(enemy.global_position) > STEALTH_KILL_RANGE:
			continue
		if not enemy.has_method("get_awareness") or enemy.get_awareness() >= 0.3:
			continue
		if not enemy.has_method("is_back_exposed") or not enemy.is_back_exposed(global_position):
			continue
		return enemy
	return null

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
	# Soul Siphon: restore MP on kill
	if _has_effect("soul_siphon"):
		mp = minf(mp + 4.0, max_mp)
		mp_changed.emit(mp)
		var scene_root_ss = get_tree().current_scene if is_inside_tree() else null
		if scene_root_ss:
			FloatingText.spawn(scene_root_ss, global_position + Vector2(0, -10), "+4 MP", Color(0.3, 0.6, 1.0))
	# Berserker Frenzy: attack-speed buff on kill
	if _has_effect("frenzy") and status_effects:
		status_effects.apply_buff("fire_rate", 3.0, 0.30)
	# Class meters on kill — per Phase 1 redesign each class has its own kill payout.
	# Warrior gets NOTHING (rage is from damage taken, not kills).
	var _pc_kill = _get_player_class()
	match _pc_kill:
		"warrior":
			pass  # No on-kill rage. See take_damage() for the build path.
		"mercenary":
			class_meter = minf(class_meter + 2.0, class_meter_max)
			_rage_decay_grace = 4.0
			class_meter_changed.emit(class_meter, class_meter_max)
		"wizard":
			# +2 Mana Flow per spell-kill — current weapon being a magic weapon is the heuristic.
			var holding_mag = false
			if equipment_manager:
				var w = equipment_manager.get_equipped_weapon()
				holding_mag = w and w.slot_type == EquipmentItem.SlotType.WEAPON_MAGIC
			if holding_mag:
				class_meter = minf(class_meter + WIZARD_MANAFLOW_PER_SPELL_KILL, class_meter_max)
				_rage_decay_grace = 3.0
				class_meter_changed.emit(class_meter, class_meter_max)
		"ranger", "archer":
			# +5 Focus per kill. Bypasses the regen lockout — kills during lockout still pay.
			class_meter = minf(class_meter + ARCHER_FOCUS_KILL_BONUS, class_meter_max)
			class_meter_changed.emit(class_meter, class_meter_max)

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
	# Overflow (X-key, wizard only): all spells cost 0 MP for 6s.
	var now_um = Time.get_ticks_msec() / 1000.0
	if _get_player_class() == "wizard" and now_um < _wizard_overflow_until:
		cost = 0.0
	if mp < cost:
		return false
	mp -= cost
	# Wizards regen on the move — short post-cast lockout so the bar isn't
	# tied to standing still. Other classes keep the original 3 s delay.
	_mp_regen_delay = 0.4 if _get_player_class() == "wizard" else MP_REGEN_DELAY
	mp_changed.emit(mp)
	# Mana Flow build: +4 per spell cast (wizard only).
	if _get_player_class() == "wizard":
		class_meter = minf(class_meter + WIZARD_MANAFLOW_PER_CAST, class_meter_max)
		_rage_decay_grace = 3.0
		class_meter_changed.emit(class_meter, class_meter_max)
	return true

func take_damage(amount: int, source_pos: Vector2 = Vector2.INF, is_contact: bool = false, is_backstab: bool = false, _damage_type: int = 0) -> void:
	if _dead:
		return
	if invincible:
		return
	# Capture death-recap source before any guards eat the hit. Heuristic:
	# nearest enemy within 80px of source_pos is presumed the attacker.
	# Cheap, good enough for the recap line; precise attribution would need
	# bullet/contact callsites to pass the source explicitly.
	if source_pos != Vector2.INF and source_pos.is_finite():
		var nearest_e: Node = null
		var nearest_d := 80.0
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e):
				continue
			var d: float = source_pos.distance_to(e.global_position)
			if d < nearest_d:
				nearest_d = d
				nearest_e = e
		if nearest_e:
			_last_damage_source_name = str(nearest_e.get("definition").enemy_name) if nearest_e.get("definition") != null else str(nearest_e.name)
			_last_damage_attack_name = "Contact" if is_contact else "Projectile"
		else:
			_last_damage_source_name = "the dark"
			_last_damage_attack_name = "Contact" if is_contact else "Projectile"
		_last_damage_amount = amount
	var is_true_damage: bool = _damage_type == CombatTypes.DamageType.TRUE

	# Dashing = full invincibility (except for Warrior, who trades invuln for end-of-dash AoE)
	if (_is_dashing or _dash_linger > 0) and _get_player_class() != "warrior":
		return

	# Mercenary Reckless Strike: 50/50 coin-flip evasion. Eats the hit entirely.
	# Checked before any damage math so it skips armor/dodge/etc.
	if not is_true_damage and Time.get_ticks_msec() / 1000.0 < _reckless_strike_until \
			and _get_player_class() == "mercenary" and randf() < RECKLESS_STRIKE_EVASION:
		var sfx_rs = get_node_or_null("/root/SFXManager")
		if sfx_rs:
			sfx_rs.play("woosh_b", -5.0, 0.15)
		var tween_rs = create_tween()
		tween_rs.tween_property(sprite, "modulate", Color(2.2, 1.8, 0.4), 0.05)
		tween_rs.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		return

	# Bullet Shield: absorbs ranged hits while charges + timer are positive.
	# Member-var state — never read from meta here.
	if _bullet_shield_charges > 0:
		var now_bs := Time.get_ticks_msec() / 1000.0
		if now_bs >= _bullet_shield_until:
			# Expired naturally — drop the state and fall through to normal damage.
			_bullet_shield_charges = 0
			_bullet_shield_until = 0.0
		elif not is_true_damage and not is_contact and source_pos != Vector2.INF:
			_bullet_shield_charges -= 1
			if _bullet_shield_charges <= 0:
				_bullet_shield_until = 0.0
			var vfx_bs = get_node_or_null("/root/VFXManager")
			if vfx_bs:
				vfx_bs.shockwave(global_position, 18.0, Color(0.4, 0.7, 1.0, 0.7))
			var scene_root_bs2 = get_tree().current_scene if is_inside_tree() else null
			if scene_root_bs2:
				var label := "BLOCKED" if _bullet_shield_charges <= 0 else "BLOCKED (%d left)" % _bullet_shield_charges
				FloatingText.spawn(scene_root_bs2, global_position + Vector2(0, -14), label, Color(0.4, 0.7, 1.0))
			return

	# PARRY CHECK — the window lasts a few hundred ms and deflects EVERY shot
	# during that time. Mini-stun is no longer automatic — only enemies hit by
	# the reflected bullets get stunned. Direction check uses the mouse cursor,
	# not the lock-on shoot direction, so you can parry while locked elsewhere.
	if not is_true_damage and _shield_active and _parry_window > 0:
		var pc_parry = _get_player_class()
		var parry_ok := true
		var parry_dir = _get_shield_facing_direction()
		# Direction always comes from the player's literal aim cursor — never
		# from the lock-on shoot direction.
		if source_pos != Vector2.INF:
			var to_atk = (source_pos - global_position).normalized()
			# Warrior has a wide arc; everyone else has a 60° front cone.
			var cone_threshold = -0.2 if pc_parry == "warrior" else 0.5
			parry_ok = parry_dir.dot(to_atk) > cone_threshold
		if parry_ok:
			# Two-tier window: the first PARRY_WINDOW_TIME - PARRY_WINDOW_LATE seconds
			# count as "PERFECT" (full effects). Anything still within _parry_window > 0
			# but past that is "LATE" — blocks damage only, no bonuses, no reflect.
			var is_perfect_parry = _parry_window > PARRY_WINDOW_LATE
			var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
			# Reflect bullet only on a PERFECT parry. Late parries just block.
			if is_perfect_parry:
				var off_prof_r = equipment_manager.get_offhand_proficiency_mult(pc_parry) if equipment_manager else 1.0
				var reflect_range = 56.0 * off_prof_r * (4.0 if in_ow else 1.0)
				var reflect_dir = _get_parry_reflect_direction()
				var reflect_speed_mult = _get_parry_reflect_speed_mult()
				var reflected_bullet = _find_parry_reflect_bullet(source_pos, reflect_range)
				if reflected_bullet:
					reflected_bullet.reflect(reflect_dir, reflect_speed_mult, _get_parry_reflect_min_speed())
					reflected_bullet.set_meta("parry_stun_on_hit", true)
				else:
					_spawn_parry_counter_projectile(reflect_dir, reflect_speed_mult, amount, off_prof_r)
			# Refund the staked stamina on ANY successful parry (perfect or late) —
			# only once per window. Heal + class bonuses only on PERFECT.
			if not has_meta("parry_bonuses_consumed"):
				set_meta("parry_bonuses_consumed", true)
				# Stamina refund (any success)
				if has_meta("parry_pending_refund"):
					var refund: float = float(get_meta("parry_pending_refund"))
					stamina = minf(stamina + refund, max_stamina)
					stamina_changed.emit(stamina)
					remove_meta("parry_pending_refund")
				# Perfect-only bonuses
				if is_perfect_parry:
					var heal_amt = 1
					if randf() < 0.15:
						heal_amt = 2
					hp = mini(hp + heal_amt, max_hp)
					hp_changed.emit(hp)
					match pc_parry:
						"archer", "ranger":
							# Parry still gives focus, but the new Focus model means
							# archers rarely rely on this — it's a niche bonus now.
							class_meter = minf(class_meter + 3.0, class_meter_max)
							class_meter_changed.emit(class_meter, class_meter_max)
						"mercenary":
							class_meter = minf(class_meter + 5.0, class_meter_max)
							_rage_decay_grace = 4.0
							class_meter_changed.emit(class_meter, class_meter_max)
						"wizard":
							mp = minf(mp + 5.0, max_mp)
							mp_changed.emit(mp)
			# VFX + SFX — gold ring on perfect, dimmer blue ring on late
			var vfx_p = get_node_or_null("/root/VFXManager")
			if vfx_p:
				var ring_r = 56.0 * (4.0 if in_ow else 1.0)
				if is_perfect_parry:
					vfx_p.shockwave(global_position, ring_r, Color(1.0, 0.9, 0.3, 0.75))
					vfx_p.shake(1.4, 0.07)
				else:
					vfx_p.shockwave(global_position, ring_r * 0.7, Color(0.45, 0.6, 1.0, 0.45))
			var sfx_p = get_node_or_null("/root/SFXManager")
			if sfx_p:
				# Layered impact: metallic clack + a chime ring on perfect, just
				# a softer clack on late. Gives the parry a real "TING!" feel.
				if is_perfect_parry:
					sfx_p.play("clack", 2.0, 0.1)
					sfx_p.play("ding", -2.0, 0.05, 1.2)
					sfx_p.play("impact_b", -4.0, 0.15)
				else:
					sfx_p.play("clack", -4.0, 0.2)
			# Sprite flash — bright white on perfect, soft blue on late
			var tween_p = create_tween()
			if is_perfect_parry:
				tween_p.tween_property(sprite, "modulate", Color(3.0, 3.0, 3.0), 0.05)
			else:
				tween_p.tween_property(sprite, "modulate", Color(0.7, 0.85, 1.2), 0.04)
			tween_p.tween_property(sprite, "modulate", Color.WHITE, 0.15)
			return  # parry blocks ALL damage, no charge cost

	# Warrior shield block — each hit costs 1 charge, blocks ALL damage
	if not is_true_damage and _shield_active and _shield_charges > 0:
		var blocked = true
		if source_pos != Vector2.INF:
			var shield_dir = Vector2(cos(_shield_angle), sin(_shield_angle))
			var hit_dir = (source_pos - global_position).normalized()
			var angle_diff = abs(shield_dir.angle_to(hit_dir))
			blocked = angle_diff < SHIELD_ARC_ANGLE / 2.0 + 0.15
		if blocked:
			# Off-class offhand drains charges twice as fast
			var off_prof = equipment_manager.get_offhand_proficiency_mult(_get_player_class()) if equipment_manager else 1.0
			var charge_cost = 1 if off_prof >= 1.0 else 2
			_shield_charges -= charge_cost
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
			# Shield ABSORBS rage the same as a raw hit — based on RAW incoming damage,
			# not the (zeroed) post-block amount. The warrior is "absorbing punishment"
			# even when his shield eats it.
			_grant_warrior_rage_from_hit(amount)
			return  # fully blocked, no damage gets through

	# Dodge check. Stat is in 0-1 range (0.15 = 15%). Evasion Surge spell
	# applies a buff via status_effects with the percent-point value (e.g. 80
	# = +80%); we divide by 100 to combine with the 0-1 gear stat.
	var dodge = equipment_manager.get_dodge_chance()
	if status_effects and status_effects.has_method("get_buff_value"):
		dodge += status_effects.get_buff_value("dodge") / 100.0
	if not is_true_damage and dodge > 0.0 and randf() < dodge:
		# Dodged! Brief white flash + SFX
		var sfx_dg = get_node_or_null("/root/SFXManager")
		if sfx_dg:
			sfx_dg.play("woosh_b", -5.0, 0.15)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(2, 2, 2), 0.05)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		return

	# The hit IS going to land in some form (dodge already burned its check).
	# Grant warrior rage off the RAW incoming damage now — before Iron Skin
	# armor / damage reduction perks zero it out. The 0.5s grace stops
	# multi-tick hits from double-charging.
	if not is_true_damage:
		_grant_warrior_rage_from_hit(amount)
		# Archer focus loss is also based on raw input (the punishment is
		# "got hit at all", not "took N HP through armor").
		var _pc_focus = _get_player_class()
		if _pc_focus == "archer" or _pc_focus == "ranger":
			class_meter = maxf(0.0, class_meter - class_meter_max * ARCHER_FOCUS_DAMAGE_PENALTY_PCT)
			_archer_focus_lockout = ARCHER_FOCUS_LOCKOUT
			class_meter_changed.emit(class_meter, class_meter_max)

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
	if not is_true_damage and armor > 0 and not is_backstab:
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
	if not is_true_damage and shield > 0:
		var absorbed = mini(shield, amount)
		shield -= absorbed
		amount -= absorbed

	# Bastion: -30% damage when HP is critical (<30%)
	if not is_true_damage and max_hp > 0 and float(hp) / float(max_hp) < 0.30 and _has_effect("bastion"):
		amount = maxi(1, int(amount * 0.70))
		var vfx_b = get_node_or_null("/root/VFXManager")
		if vfx_b:
			vfx_b.shockwave(global_position, 24.0, Color(0.85, 0.75, 0.4, 0.6))

	# Last Stand: -25% damage when HP <= 25% (warrior)
	if not is_true_damage and max_hp > 0 and float(hp) / float(max_hp) <= 0.25 and _has_effect("last_stand"):
		amount = maxi(1, int(amount * 0.75))

	# Adrenaline: taking damage grants +20% attack speed for 3s
	if amount > 0 and _has_effect("adrenaline") and status_effects:
		status_effects.apply_buff("fire_rate", 3.0, 0.20)

	# Vengeful: reflect 30% of incoming damage to nearby enemies
	if amount > 0 and _has_effect("vengeful") and is_inside_tree():
		var reflect_dmg = maxi(1, int(amount * 0.30))
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e) or e.global_position.distance_to(global_position) > 60.0:
				continue
			if e.has_method("take_damage"):
				e.take_damage(reflect_dmg)
		var vfx_v = get_node_or_null("/root/VFXManager")
		if vfx_v:
			vfx_v.shockwave(global_position, 60.0, Color(0.8, 0.2, 0.2, 0.5))

	# Phoenix: lethal-damage save once per dungeon, revive at 25% HP
	if amount >= hp and _has_effect("phoenix") and not has_meta("phoenix_used"):
		set_meta("phoenix_used", true)
		amount = hp - maxi(1, int(max_hp * 0.25))
		var vfx_pn = get_node_or_null("/root/VFXManager")
		if vfx_pn:
			vfx_pn.level_up_burst(global_position)
		var scene_root_pn = get_tree().current_scene if is_inside_tree() else null
		if scene_root_pn:
			FloatingText.spawn(scene_root_pn, global_position + Vector2(0, -20), "PHOENIX!", Color(1.0, 0.6, 0.2))

	# Mystic Shield: divert 20% of damage to MP loss instead of HP
	if not is_true_damage and amount > 0 and mp > 0 and _has_effect("mystic_shield"):
		var diverted = int(ceilf(amount * 0.20))
		var mp_spent = minf(mp, diverted)
		if mp_spent > 0:
			mp -= mp_spent
			mp_changed.emit(mp)
			amount = maxi(0, amount - int(mp_spent))
			var vfx_m = get_node_or_null("/root/VFXManager")
			if vfx_m:
				vfx_m.shockwave(global_position, 20.0, Color(0.3, 0.6, 1.0, 0.7))
			var scene_root_m = get_tree().current_scene if is_inside_tree() else null
			if scene_root_m:
				FloatingText.spawn(scene_root_m, global_position + Vector2(0, -18), "-%d MP" % int(mp_spent), Color(0.3, 0.6, 1.0))

	if amount <= 0:
		return

	# Mercenary Reckless Strike: landed hits do 2× damage (the coin-flip cost).
	if not is_true_damage and Time.get_ticks_msec() / 1000.0 < _reckless_strike_until \
			and _get_player_class() == "mercenary":
		amount = int(amount * RECKLESS_STRIKE_DMG_TAKEN_MULT)

	hp -= amount
	if hp < 0:
		hp = 0
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
		_invincible_until = Time.get_ticks_msec() / 1000.0 + 0.12
		var iframe_tween = create_tween()
		iframe_tween.tween_property(sprite, "modulate:a", 0.3, 0.04)
		iframe_tween.tween_property(sprite, "modulate:a", 1.0, 0.04)
		iframe_tween.tween_callback(func():
			invincible = false
			_invincible_until = 0.0
		)

	if hp <= 0:
		# Undying perk: survive lethal hit once per dungeon
		var _pm_ud = get_node_or_null("/root/PerkManager")
		if _pm_ud and _pm_ud.has_special("undying") and not has_meta("undying_used"):
			hp = 1
			set_meta("undying_used", true)
			FloatingText.spawn(get_parent(), global_position + Vector2(0, -16), "UNDYING!", Color(1.0, 0.3, 0.3))
			var _sfx_ud = get_node_or_null("/root/SFXManager")
			if _sfx_ud: _sfx_ud.play("shield_break", -2.0)
		else:
			_dead = true
			invincible = true
			hp = 0
			hp_changed.emit(hp)
			# Stash the death recap on GameManager.save_data so the death screen
			# and Hall of Ancestors can read it without coupling to player state.
			# Done BEFORE emit so _snapshot_death_legacy picks the values up.
			var gm_dr = get_node_or_null("/root/GameManager")
			if gm_dr and gm_dr.save_data:
				gm_dr.save_data.set_meta("last_death_recap", {
					"source": _last_damage_source_name,
					"attack": _last_damage_attack_name,
					"damage": _last_damage_amount,
				})
			player_died.emit()

func _on_stats_changed() -> void:
	# IMPORTANT: do NOT add HP/stamina when max increases — that opened a heal
	# exploit (equip → +5 HP, unequip → keep, equip → +5 again …). Keep current
	# values; only top up if the player was AT FULL before the change so it
	# still feels right when buffing gear while full.
	var was_full_hp := hp >= max_hp
	var was_full_stam := stamina >= max_stamina
	max_hp = equipment_manager.get_max_hp()
	if was_full_hp:
		hp = max_hp
	else:
		hp = mini(hp, max_hp)
	max_mp = equipment_manager.get_max_mp()
	mp = minf(mp, max_mp)
	max_stamina = equipment_manager.get_max_stamina()
	if was_full_stam:
		stamina = max_stamina
	else:
		stamina = minf(stamina, max_stamina)
	hp_changed.emit(hp)
	mp_changed.emit(mp)
	stamina_changed.emit(stamina)
	weapon_system.update_pattern_for_weapon()

func _on_level_up(new_level: int) -> void:
	# Restore HP and stamina on level up
	_dead = false
	invincible = false
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
	# Floating text — "+1 STAT POINT" so player knows to spend it (anywhere via I or P)
	var scene_root = get_parent()
	if scene_root:
		FloatingText.spawn(scene_root, global_position + Vector2(0, -20), "LEVEL %d!" % new_level, Color(1.0, 0.95, 0.2))
		FloatingText.spawn(scene_root, global_position + Vector2(0, -40), "+1 stat point (open I or P)", Color(0.6, 1.0, 0.6))

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
	bs.move_speed = player_class.base_speed * 1.1
	bs.attack_damage = int(player_class.base_damage)
	bs.max_mp = player_class.base_mp
	bs.weight = player_class.base_weight
	bs.acceleration = player_class.base_acceleration
	bs.tenacity = player_class.base_tenacity
	bs.thorns = player_class.base_thorns
	if pc == "mercenary":
		bs.max_stamina = 150.0  # mercenary has extra stamina for versatility
	# Hall of Souls permanent upgrades
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_hall_upgrade_level"):
		# Phase 1 ×12: hall HP/damage upgrades scaled to match the new HP/damage
		# floor (skeleton ~360, sword ~12) so each stack still gives a perceptible
		# bump (HP +60/stack, dmg +12/stack) instead of becoming rounding noise.
		bs.max_hp += gm.get_hall_upgrade_level("starting_health") * 60
		bs.attack_damage += gm.get_hall_upgrade_level("starting_damage") * 12
		bs.hp_regen += gm.get_hall_upgrade_level("heart_of_embers") * 0.1
		bs.gold_mult += gm.get_hall_upgrade_level("gold_find") * 0.05
		bs.xp_mult += gm.get_hall_upgrade_level("xp_find") * 0.05
	# Permanent elixir bonuses (stack up to 3 each; persisted via save_data)
	if gm and gm.save_data:
		var atk_stacks = int(gm.save_data.permanent_upgrades.get("elixir_attack", 0))
		var def_stacks = int(gm.save_data.permanent_upgrades.get("elixir_defence", 0))
		# Phase 1 ×12 to match the rescaled damage/armor floor.
		bs.attack_damage += atk_stacks * 12
		bs.armor += def_stacks * 24.0

func get_weight() -> float:
	var pc = _get_player_class()
	var class_path = "res://resources/classes/%s.tres" % pc
	if pc == "ranger":
		class_path = "res://resources/classes/archer.tres"
	var player_class = load(class_path) as PlayerClass
	var base = player_class.base_weight if player_class else 1.0
	# Equipment weight adds to player weight (heavier armor = harder to push)
	var equip_weight = equipment_manager.get_weight() if equipment_manager else 0.0
	return base + maxf(equip_weight - base, 0.0)

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

## Apply push from enemy, reduced by player weight
func apply_push(push_vec: Vector2) -> void:
	var w = get_weight()
	_pushed_velocity = push_vec / maxf(w, 0.5)

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
	# Mercenary Adrenaline: each swap adds 15 to the meter (dialed down from 25 in Phase 1 redesign).
	if _get_player_class() == "mercenary":
		class_meter = minf(class_meter + 15.0, class_meter_max)
		_rage_decay_grace = 3.0
		class_meter_changed.emit(class_meter, class_meter_max)
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
	var hud = get_tree().get_first_node_in_group("game_hud") as CanvasLayer
	if not hud:
		return
	hud._on_quickbar_pressed(slot_index)

## Unified action-bar router. Each of the 10 slots can hold an item OR a spell.
## Item takes priority — if quickbar_items[slot] is set, the item wins and the
## spell (if any) is dormant; clear the item slot to surface the spell again.
func _on_action_bar_pressed(slot: int) -> void:
	if not is_inside_tree() or slot < 0:
		return
	var hud = get_tree().get_first_node_in_group("game_hud") as CanvasLayer
	if not hud:
		return
	var item_name: String = ""
	if "_quickbar_items" in hud and slot < hud._quickbar_items.size():
		item_name = hud._quickbar_items[slot]
	if item_name != "":
		hud._on_quickbar_pressed(slot)
		return
	if spell_book and slot < spell_book.MAX_SPELL_SLOTS and spell_book.spell_slots[slot] != null:
		_use_spell_slot(slot)

# Shield visual — directional arc that rotates toward shoot direction
var _shield_visual: Polygon2D = null
var _shield_angle: float = 0.0  # current shield facing angle
const SHIELD_ARC_INNER_BASE = 6.0   # inner radius in dungeon (8px tiles)
const SHIELD_ARC_OUTER_BASE = 10.0   # outer radius in dungeon
const SHIELD_ARC_ANGLE = PI * 0.42  # ~76 degree arc — tight front cone
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
			_shield_angle = _get_parry_direction().angle()
			# Shield HP label centered on arc
			_shield_charges_label = Label.new()
			_shield_charges_label.add_theme_font_size_override("font_size", 8 if sc < 2.0 else 16)
			_shield_charges_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
			_shield_charges_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_shield_charges_label.z_index = 2
			add_child(_shield_charges_label)
		# Rotate shield toward the mouse / aim joystick (NOT the lock-on target)
		var target_angle = _get_parry_direction().angle()
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
		# Charge label — only for actual shields (not buckler/parrying dagger),
		# since bucklers don't absorb damage as a stacked pool.
		var off_for_label = equipment_manager.get_equipped_offhand_type() if equipment_manager else ""
		if off_for_label == "shield":
			var label_pos = Vector2(cos(_shield_angle), sin(_shield_angle)) * (inner + outer) * 0.5
			_shield_charges_label.text = str(_shield_charges)
			_shield_charges_label.position = label_pos - Vector2(12, 6)
			_shield_charges_label.visible = true
		else:
			_shield_charges_label.visible = false
		sprite.modulate = Color(0.7, 0.8, 1.0)
	else:
		if _shield_visual:
			_shield_visual.queue_free()
			_shield_visual = null
		if _shield_charges_label:
			_shield_charges_label.queue_free()
			_shield_charges_label = null

## Returns the player's facing direction for *defensive* actions (shield visual,
## parry cone). Always uses the literal mouse cursor / aim joystick — never the
## lock-on auto-aim, since the player's threat awareness should follow their
## eyes, not their gunbarrel.
func _get_parry_direction() -> Vector2:
	if touch_controls and touch_controls.visible:
		var aim = touch_controls.get_aim_input()
		if aim.length() > 0.1:
			return aim.normalized()
	var mouse_pos = get_global_mouse_position()
	var dir = (mouse_pos - global_position).normalized()
	return dir if dir.length() > 0 else _last_move_dir

func _get_shield_facing_direction() -> Vector2:
	var dir = Vector2(cos(_shield_angle), sin(_shield_angle))
	return dir.normalized() if dir.length() > 0.0 else _get_parry_direction()

func _get_parry_movement_direction() -> Vector2:
	if _is_dashing and _dash_direction.length() > 0.0:
		return _dash_direction.normalized()
	if velocity.length() > 6.0:
		return velocity.normalized()
	return Vector2.ZERO

func _get_parry_reflect_direction() -> Vector2:
	var shield_dir = _get_shield_facing_direction()
	var move_dir = _get_parry_movement_direction()
	if move_dir == Vector2.ZERO:
		return shield_dir
	var move_weight := 0.45 if _is_dashing else 0.22
	return (shield_dir + move_dir * move_weight).normalized()

func _get_parry_reflect_speed_mult() -> float:
	if _is_dashing:
		return 1.9
	var base_move = 0.0
	if equipment_manager:
		base_move = equipment_manager.get_move_speed() * _get_scene_motion_scale()
	var current_speed = velocity.length()
	if base_move <= 1.0:
		return 0.9 if current_speed <= 6.0 else 1.2
	var speed_ratio = clampf(current_speed / base_move, 0.0, 1.35)
	return lerpf(0.9, 1.45, speed_ratio / 1.35)

func _get_parry_reflect_min_speed() -> float:
	var base_speed = 320.0 * _get_scene_projectile_scale()
	if equipment_manager:
		base_speed = maxf(base_speed, equipment_manager.get_bullet_speed() * _get_scene_projectile_scale() * 0.9)
	return base_speed

func _get_parry_reflect_damage(incoming_damage: int, proficiency: float) -> int:
	var scaled_incoming = float(maxi(1, incoming_damage)) * 3.0
	var base_weapon = 4.0
	if equipment_manager:
		base_weapon = maxf(base_weapon, equipment_manager.get_damage() * 0.5 * proficiency)
	return maxi(1, int(round(maxf(scaled_incoming, base_weapon))))

func _find_parry_reflect_bullet(source_pos: Vector2, reflect_range: float) -> Node:
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return null
	var best: Node = null
	var best_score := INF
	for b in bullets_container.get_children():
		if not is_instance_valid(b) or not b.has_method("reflect"):
			continue
		if b.get("is_player_bullet") != null and b.is_player_bullet:
			continue
		var dist_to_player = b.global_position.distance_to(global_position)
		if dist_to_player > reflect_range:
			continue
		var score = dist_to_player
		if source_pos != Vector2.INF:
			score += b.global_position.distance_to(source_pos) * 0.75
		if score < best_score:
			best_score = score
			best = b
	return best

func _spawn_parry_counter_projectile(direction: Vector2, speed_mult: float, incoming_damage: int, proficiency: float) -> void:
	if not is_inside_tree() or not weapon_system or not weapon_system.bullet_scene:
		return
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	var bullet = weapon_system.bullet_scene.instantiate()
	bullet.global_position = global_position + direction * 8.0
	bullet.direction = direction
	bullet.is_player_bullet = true
	bullet.speed = _get_parry_reflect_min_speed() * speed_mult
	bullet.damage = _get_parry_reflect_damage(incoming_damage, proficiency)
	bullet.lifetime = OFFHAND_THROW_LIFETIME
	bullet.set_meta("parry_stun_on_hit", true)
	bullet.set_meta("projectile_fx_kind", "lightning")
	bullet.set_meta("projectile_fx_energy", 0.85)
	var sprite_scale_mult := 1.15 if _is_dashing else 1.0
	if sprite_scale_mult != 1.0:
		bullet.set_meta("sprite_scale_mult", sprite_scale_mult)
	bullets_container.add_child(bullet)

func _get_shoot_direction() -> Vector2:
	## Returns the direction the player is currently shooting (for shield facing)
	# Lock-on overrides aim — always point toward the locked target if valid.
	if is_instance_valid(_lock_on_target):
		var d = _lock_on_target.global_position - global_position
		if d.length() > 1.0:
			return d.normalized()
	if touch_controls and touch_controls.visible:
		var aim = touch_controls.get_aim_input()
		if aim.length() > 0:
			return aim.normalized()
	var mouse_pos = get_global_mouse_position()
	var dir = (mouse_pos - global_position).normalized()
	return dir if dir.length() > 0 else _last_move_dir

func _get_free_aim_direction() -> Vector2:
	## Returns raw mouse/touch aim and intentionally ignores lock-on.
	if touch_controls and touch_controls.visible:
		var aim = touch_controls.get_aim_input()
		if aim.length() > 0:
			return aim.normalized()
	var mouse_pos = get_global_mouse_position()
	var dir = (mouse_pos - global_position).normalized()
	return dir if dir.length() > 0 else _last_move_dir

func _get_aim_direction() -> Vector2:
	return _get_shoot_direction()

func _get_scene_motion_scale() -> float:
	return DUNGEON_MOVE_SCALE if in_dungeon else 1.0

func _get_scene_projectile_scale() -> float:
	return DUNGEON_PROJECTILE_SCALE if in_dungeon else 1.0

func _get_lock_on_candidates() -> Array[Node2D]:
	var out: Array[Node2D] = []
	if not is_inside_tree():
		return out
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if "state" in e and e.state == e.State.DEAD:
			continue
		if not _is_on_screen(e.global_position):
			continue
		var d = global_position.distance_to(e.global_position)
		if d > LOCK_ON_MAX_RANGE:
			continue
		if e.has_method("get_awareness") and float(e.get_awareness()) < 0.3 and d > LOCK_ON_CYCLE_RANGE:
			continue
		out.append(e)
	return out

func _get_cursor_priority_score(enemy: Node2D) -> float:
	var aim_dir := _get_free_aim_direction()
	var cursor_anchor := global_position + aim_dir * minf(LOCK_ON_MAX_RANGE, 220.0)
	var cursor_dist := enemy.global_position.distance_to(cursor_anchor)
	var player_dist := enemy.global_position.distance_to(global_position)
	return cursor_dist + player_dist * 0.12

## Auto-relock to the nearest on-screen enemy when the current target dies/leaves.
func _auto_relock() -> void:
	if _lock_on_suppressed:
		_lock_on_target = null
		return
	var candidates := _get_lock_on_candidates()
	if candidates.is_empty():
		_lock_on_target = null
		return
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return _get_cursor_priority_score(a) < _get_cursor_priority_score(b)
	)
	_lock_on_target = candidates[0]

## Class-specific signature move that fires when the class meter hits 100%.
## Consumes the full meter; each class gets a distinct payoff:
##   Warrior  Rage       → "Bloodthirst" — 5s of +30% dmg + 4% max-HP heal per hit
##   Wizard   Mana Flow  → "Arcane Surge" — next 3 spells cost 0 MP + 75% dmg
##   Archer   Focus      → "Killshot" — next shot is a guaranteed 5× crit that pierces all
##   Mercenary Adrenaline → "Reckless Strike" — full stamina + 4s of +75% fire rate
func _unleash_class_meter_move() -> void:
	var pc = _get_player_class()
	var vfx = get_node_or_null("/root/VFXManager")
	var sfx = get_node_or_null("/root/SFXManager")
	var scene_root = get_tree().current_scene if is_inside_tree() else null
	var now = Time.get_ticks_msec() / 1000.0
	# Archer Killshot is special: it consumes the FOCUS bar but only when at ≥60.
	# Warrior has a similar two-tier model: 30-99 = Rampage, 100 = Blood Dream.
	# Other classes require a full meter (the input gate at the call site enforces it).
	if pc == "archer" or pc == "ranger":
		if class_meter < KILLSHOT_MIN_FOCUS:
			return
	elif pc == "warrior":
		if class_meter < RAMPAGE_MIN_RAGE:
			return
	match pc:
		"warrior":
			# Two-tier: full meter triggers the proper ult, partial spends as Rampage.
			if class_meter >= class_meter_max:
				# Blood Dream — 30s vampiric trance. Snapshot HP, fill the bar, lifesteal everything.
				# Backlash on expiry: paralyze 3s + slow 6s. Rage drops to 20% (head start).
				_blood_dream_active = true
				_blood_dream_until = now + BLOOD_DREAM_DURATION
				_blood_dream_banked_hp = hp
				_blood_dream_heal_budget = float(max_hp) * BLOOD_DREAM_LIFESTEAL_CAP_PCT
				_blood_dream_heal_budget_until = now + 1.0
				hp = max_hp
				hp_changed.emit(hp)
				if vfx:
					vfx.shockwave(global_position, 40.0, Color(0.85, 0.05, 0.10, 0.75))
					vfx.shake(2.8, 0.20)
				if sfx:
					sfx.play("special_b", 0.0, 0.0)
				if scene_root:
					FloatingText.spawn(scene_root, global_position + Vector2(0, -16), "BLOOD DREAM!", Color(0.95, 0.15, 0.15))
				class_meter = 0.0
				class_meter_changed.emit(class_meter, class_meter_max)
			else:
				# Rampage — 4s burst of +75% fire rate + +25% damage. Spends all rage.
				# Status-effect buffs let weapon_system's existing fire_rate/damage
				# multipliers pick the bonus up automatically — no hot-path changes.
				if status_effects:
					if status_effects.has_method("apply_buff"):
						status_effects.apply_buff("fire_rate", RAMPAGE_DURATION, RAMPAGE_FIRE_RATE_BONUS)
						status_effects.apply_buff("damage", RAMPAGE_DURATION, RAMPAGE_DAMAGE_BONUS)
				if vfx:
					vfx.shockwave(global_position, 32.0, Color(1.0, 0.30, 0.15, 0.85))
					vfx.shake(2.2, 0.15)
				if sfx:
					sfx.play("special_b", 0.0, 0.05)
				if scene_root:
					var pct_r = int(round(class_meter))
					FloatingText.spawn(scene_root, global_position + Vector2(0, -16), "RAMPAGE %d!" % pct_r, Color(1.0, 0.35, 0.15))
				class_meter = 0.0
				class_meter_changed.emit(class_meter, class_meter_max)
		"wizard":
			# Overflow — 10 s of free empowered casts, 3× cooldown ticks,
			# +40% damage. Also tops MP and applies a brief damage buff so the
			# wave of spells feels like a real ultimate, not "free cast for 6s".
			_wizard_overflow_until = now + WIZARD_OVERFLOW_DURATION
			mp = max_mp
			mp_changed.emit(mp)
			if status_effects:
				status_effects.apply_buff("damage", WIZARD_OVERFLOW_DURATION, WIZARD_OVERFLOW_DAMAGE_BUFF)
			if vfx:
				vfx.shockwave(global_position, 44.0, Color(0.45, 0.55, 1.0, 0.85))
				vfx.shake(2.0, 0.15)
			if sfx:
				sfx.play("mystical", 0.0, 0.0)
			if scene_root:
				FloatingText.spawn(scene_root, global_position + Vector2(0, -16), "OVERFLOW!", Color(0.5, 0.7, 1.0))
			class_meter = 0.0
			class_meter_changed.emit(class_meter, class_meter_max)
		"ranger", "archer":
			# Killshot — 1 medium-speed crit, pierces 3, damage scales with focus spent.
			# Bullet damage mult computed in weapon_system from the stored focus_spent meta.
			set_meta("killshot_charge", true)
			set_meta("killshot_focus_spent", class_meter)
			if vfx:
				vfx.shockwave(global_position, 36.0, Color(0.55, 1.0, 0.55, 0.85))
			if sfx:
				sfx.play("special_a", 0.0, 0.0)
			if scene_root:
				var pct = int(round(class_meter))
				FloatingText.spawn(scene_root, global_position + Vector2(0, -16), "KILLSHOT %d!" % pct, Color(0.6, 1.0, 0.6))
			# Charge indicator — a pulsing golden halo on the player tells you
			# the shot is queued. _tick_class_meter_buffs frees it when the
			# bullet consumes killshot_charge meta.
			_spawn_killshot_indicator()
			# Drain bar to 0 (Killshot always burns ALL focus, regardless of how much).
			class_meter = 0.0
			class_meter_changed.emit(class_meter, class_meter_max)
		"mercenary":
			# Reckless Strike — 30s glass-cannon: +50% fire rate (meta), 50% evade, 2× dmg taken, 5% stun.
			_reckless_strike_until = now + RECKLESS_STRIKE_DURATION
			stamina = max_stamina
			stamina_changed.emit(stamina)
			if status_effects:
				# Fire-rate buff applied as a status; consumed by weapon_system fire path.
				status_effects.apply_buff("fire_rate", RECKLESS_STRIKE_DURATION, RECKLESS_STRIKE_FIRE_RATE_BONUS)
			if vfx:
				vfx.shockwave(global_position, 40.0, Color(1.0, 0.75, 0.20, 0.85))
				vfx.shake(2.0, 0.12)
			if sfx:
				sfx.play("special_b", 0.0, 0.0)
			if scene_root:
				FloatingText.spawn(scene_root, global_position + Vector2(0, -16), "RECKLESS STRIKE!", Color(1.0, 0.75, 0.2))
			class_meter = 0.0
			class_meter_changed.emit(class_meter, class_meter_max)

## Per-class meter dynamics. Each class behaves differently:
##  - Warrior/Mercenary use the legacy decay model (kills + build actions feed it).
##  - Archer is REGEN-based: builds in combat when clean, decays out of combat, 3s lockout on damage.
##  - Wizard also has a passive +1/s while MP > 50% (rewards conservative casting).
func _tick_class_meter(delta: float) -> void:
	var pc_mt = _get_player_class()
	if pc_mt == "ranger" or pc_mt == "archer":
		_tick_archer_focus(delta)
		return
	# Wizard passive regen while MP > 50%.
	if pc_mt == "wizard" and max_mp > 0.0 and mp / max_mp > 0.5 and class_meter < class_meter_max:
		_wizard_mp_regen_passive_accum += WIZARD_MANAFLOW_PASSIVE_PER_SEC * delta
		if _wizard_mp_regen_passive_accum >= 1.0:
			var inc = floor(_wizard_mp_regen_passive_accum)
			_wizard_mp_regen_passive_accum -= inc
			class_meter = minf(class_meter + inc, class_meter_max)
			class_meter_changed.emit(class_meter, class_meter_max)
	# Decay (warrior / mercenary / wizard) with grace.
	if class_meter <= 0.0:
		return
	if _rage_decay_grace > 0.0:
		_rage_decay_grace -= delta
		return
	var decay_rate := 3.0
	match pc_mt:
		"warrior":   decay_rate = 3.0   # 100→0 in ~33s
		"wizard":    decay_rate = 2.0   # 50s — slow decay so build-up matters
		"mercenary": decay_rate = 3.5   # 28s
	var new_v = maxf(0.0, class_meter - decay_rate * delta)
	if new_v != class_meter:
		class_meter = new_v
		class_meter_changed.emit(class_meter, class_meter_max)

## Archer focus model: builds in combat when clean, decays out of combat,
## damage triggers 3s regen lockout + flat 15% loss.
func _tick_archer_focus(delta: float) -> void:
	if _archer_focus_lockout > 0.0:
		_archer_focus_lockout = maxf(0.0, _archer_focus_lockout - delta)
		return
	var in_combat = _has_enemies_nearby(ARCHER_COMBAT_RADIUS)
	var changed := false
	if in_combat:
		if class_meter < class_meter_max:
			var stationary = velocity.length() < ARCHER_STATIONARY_VEL_THRESHOLD and _archer_shoot_grace <= 0.0
			var regen = ARCHER_FOCUS_REGEN_STATIONARY if stationary else ARCHER_FOCUS_REGEN_BASE
			class_meter = minf(class_meter + regen * delta, class_meter_max)
			changed = true
	else:
		if class_meter > 0.0:
			class_meter = maxf(0.0, class_meter - ARCHER_FOCUS_OOC_DECAY * delta)
			changed = true
	if changed:
		class_meter_changed.emit(class_meter, class_meter_max)

## Per-frame book-keeping for Blood Dream / Reckless Strike / Overflow.
## Reckless Strike and Overflow are checked lazily by hot paths — only Blood
## Dream needs its own tick (heal-budget reset + duration expiry).
func _tick_class_meter_buffs(_delta: float) -> void:
	# Killshot indicator: free the halo the moment weapon_system clears the meta
	# (i.e. the queued shot was fired). Cheap presence check every frame.
	if _killshot_indicator and not has_meta("killshot_charge"):
		_killshot_indicator.queue_free()
		_killshot_indicator = null
	if not _blood_dream_active:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now >= _blood_dream_heal_budget_until:
		_blood_dream_heal_budget = float(max_hp) * BLOOD_DREAM_LIFESTEAL_CAP_PCT
		_blood_dream_heal_budget_until = now + 1.0
	if now >= _blood_dream_until:
		_end_blood_dream()

## Build the on-player Killshot halo. CPUParticles2D so it pulses on its own
## without us needing to drive a tween per frame.
func _spawn_killshot_indicator() -> void:
	if _killshot_indicator and is_instance_valid(_killshot_indicator):
		_killshot_indicator.queue_free()
	var p := CPUParticles2D.new()
	p.name = "KillshotIndicator"
	p.amount = 14
	p.lifetime = 0.55
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 7.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 22.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.6
	p.color = Color(1.4, 1.15, 0.35, 0.95)
	p.z_index = 6
	add_child(p)
	_killshot_indicator = p

## Distance check: is at least one alive enemy within `radius` pixels?
func _has_enemies_nearby(radius: float) -> bool:
	if not is_inside_tree():
		return false
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if e.has_method("get") and "state" in e and "State" in e and e.state == e.State.DEAD:
			continue
		if e.global_position.distance_to(global_position) <= radius:
			return true
	return false

## End-of-Blood-Dream backlash: restore banked HP regardless of where the temp
## bar ended, then paralyze + slow + leave 20% rage as a head-start.
func _end_blood_dream() -> void:
	_blood_dream_active = false
	# Overwrite HP back to banked. If banked > current, this effectively heals.
	hp = clampi(_blood_dream_banked_hp, 1, max_hp)
	hp_changed.emit(hp)
	# End-of-trance debuff: paralyze + slow.
	if status_effects:
		# Apply both via status_effects so existing systems handle the move/attack lock.
		if status_effects.has_method("apply_status"):
			status_effects.apply_status("STUNNED", BLOOD_DREAM_END_PARALYZE)
		if status_effects.has_method("apply_status"):
			status_effects.apply_status("SLOWED", BLOOD_DREAM_END_SLOW)
	# Leave 20% rage as a head start.
	class_meter = BLOOD_DREAM_RAGE_LEFTOVER
	class_meter_changed.emit(class_meter, class_meter_max)
	# Floating + VFX cue so the player FEELS the trance end.
	var scene_root = get_tree().current_scene if is_inside_tree() else null
	if scene_root:
		FloatingText.spawn(scene_root, global_position + Vector2(0, -16), "TRANCE ENDS", Color(0.9, 0.2, 0.2))
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position, 36.0, Color(0.6, 0.05, 0.05, 0.6))
		vfx.shake(2.0, 0.18)

## Apply per-class on-crit hook (called by weapon_system when a bullet rolls a crit).
func on_crit_landed() -> void:
	if _get_player_class() == "mercenary":
		class_meter = minf(class_meter + 1.0, class_meter_max)
		_rage_decay_grace = 2.0
		class_meter_changed.emit(class_meter, class_meter_max)

## Warrior rage gain — fires whenever the warrior is HIT (shield-blocked OR
## damage-dealt). Scales with the RAW incoming damage so Iron Skin / armor /
## shield absorbing the hit doesn't starve the meter.
## 0.5s grace prevents multi-tick hits (DoTs, lasers) from double-charging.
func _grant_warrior_rage_from_hit(raw_incoming: int) -> void:
	if _get_player_class() != "warrior" or raw_incoming <= 0:
		return
	if _rage_damage_grace > 0.0:
		return
	var gain = float(raw_incoming) * 1.5
	class_meter = minf(class_meter + gain, class_meter_max)
	_rage_damage_grace = 0.5
	_rage_decay_grace = 4.0
	class_meter_changed.emit(class_meter, class_meter_max)

## Called by bullet.gd / ability handlers whenever the player deals damage.
## During Blood Dream, the player heals 1:1 (capped at 30% max HP per second).
## Also feeds Wizard "Mana Flow on spell kill" — handled separately at the kill hook.
func apply_blood_dream_lifesteal(damage_dealt: int) -> void:
	if not _blood_dream_active or damage_dealt <= 0:
		return
	var amount = minf(float(damage_dealt), _blood_dream_heal_budget)
	if amount <= 0.0:
		return
	_blood_dream_heal_budget -= amount
	hp = mini(hp + int(amount), max_hp)
	hp_changed.emit(hp)

## Returns true if a wizard cast is empowered (and consumes the flag).
## Spell ability functions check this to decide which form to fire.
func _consume_empowered() -> bool:
	if _empowered_cast_pending:
		_empowered_cast_pending = false
		var scene_root = get_tree().current_scene if is_inside_tree() else null
		if scene_root:
			FloatingText.spawn(scene_root, global_position + Vector2(0, -22), "EMPOWERED", Color(0.55, 0.75, 1.0))
		return true
	return false

## Returns true if the world position is inside the camera's visible rect.
func _is_on_screen(world_pos: Vector2) -> bool:
	var cam = get_node_or_null("Camera2D") as Camera2D
	if not cam:
		return true
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var half = vp_size * 0.5 / maxf(cam.zoom.x, 0.001)
	var cam_pos = cam.get_screen_center_position() if cam.has_method("get_screen_center_position") else cam.global_position
	var rel = world_pos - cam_pos
	return absf(rel.x) <= half.x and absf(rel.y) <= half.y

## Pick the nearest *on-screen* enemy; cycle on repeat press.
func _cycle_lock_on() -> void:
	if _lock_on_suppressed:
		_lock_on_target = null
		queue_redraw()
		return
	var candidates := _get_lock_on_candidates()
	if candidates.is_empty():
		_lock_on_target = null
		queue_redraw()
		return
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return _get_cursor_priority_score(a) < _get_cursor_priority_score(b)
	)
	if not is_instance_valid(_lock_on_target):
		_lock_on_target = candidates[0]
	else:
		var idx := candidates.find(_lock_on_target)
		if idx < 0:
			_lock_on_target = candidates[0]
		elif idx + 1 < candidates.size():
			_lock_on_target = candidates[idx + 1]
		else:
			_lock_on_target = candidates[0]
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(_lock_on_target):
		return
	# Reticle around the locked target, drawn in the player's local space.
	var rel = _lock_on_target.global_position - global_position
	var r := 7.0
	var col := Color(1.0, 0.85, 0.30, 0.95)
	# Four corner brackets
	var l := 3.0
	# top-left
	draw_line(rel + Vector2(-r, -r), rel + Vector2(-r + l, -r), col, 1.5)
	draw_line(rel + Vector2(-r, -r), rel + Vector2(-r, -r + l), col, 1.5)
	# top-right
	draw_line(rel + Vector2(r, -r), rel + Vector2(r - l, -r), col, 1.5)
	draw_line(rel + Vector2(r, -r), rel + Vector2(r, -r + l), col, 1.5)
	# bottom-left
	draw_line(rel + Vector2(-r, r), rel + Vector2(-r + l, r), col, 1.5)
	draw_line(rel + Vector2(-r, r), rel + Vector2(-r, r - l), col, 1.5)
	# bottom-right
	draw_line(rel + Vector2(r, r), rel + Vector2(r - l, r), col, 1.5)
	draw_line(rel + Vector2(r, r), rel + Vector2(r, r - l), col, 1.5)
	# Small diamond pip in the center top
	draw_polyline([
		rel + Vector2(0, -r - 2),
		rel + Vector2(2, -r),
		rel + Vector2(0, -r + 2),
		rel + Vector2(-2, -r),
		rel + Vector2(0, -r - 2),
	], col, 1.0)
	# Faint line from player to target
	draw_line(Vector2.ZERO, rel, Color(col.r, col.g, col.b, 0.18), 1.0)

func get_high_ground_level() -> int:
	## Returns 0-3 based on player's current height tile. Ramps count as the higher level.
	var dm = get_tree().get_first_node_in_group("dungeon_manager")
	if dm == null or dm.get("_height_system") == null:
		return 0
	var hs = dm._height_system
	if not is_instance_valid(hs):
		return 0
	var ts: int = int(hs.tile_size)
	if ts <= 0:
		ts = 8
	var tile := Vector2i(int(floor(global_position.x / ts)), int(floor(global_position.y / ts)))
	var h: int = int(hs.get_height(tile))
	if hs.is_ramp(tile):
		var top := h
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
			top = maxi(top, int(hs.get_height(tile + d)))
		h = top
	return h

func get_high_ground_damage_mult() -> float:
	# Pits (negative levels) give no bonus but no debuff either.
	return 1.0 + 0.20 * float(maxi(0, get_high_ground_level()))

func get_high_ground_crit_bonus() -> float:
	return 10.0 * float(maxi(0, get_high_ground_level()))

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
			# Sword + short bow (weapon-swap) + Wooden Buckler (offhand, parry)
			var merc_sword = load("res://resources/items/loy/sword.tres") as EquipmentItem
			var short_bow = load("res://resources/items/loy/short_bow.tres") as EquipmentItem
			var merc_buckler = load("res://resources/items/loy/wooden_buckler.tres") as EquipmentItem
			if merc_sword:
				equipment_manager.add_to_inventory(merc_sword.make_copy())
				equipment_manager.toggle_equip(equipment_manager.inventory.size() - 1)
				_quickbar_preload[merc_sword.item_name] = 0
			if short_bow:
				var sb_copy = short_bow.make_copy()
				equipment_manager.add_to_inventory(sb_copy)
				_quickbar_preload[short_bow.item_name] = 1
				_secondary_weapon = sb_copy
			if merc_buckler:
				equipment_manager.add_to_inventory(merc_buckler.make_copy())
				equipment_manager.toggle_equip(equipment_manager.inventory.size() - 1)
				_quickbar_preload[merc_buckler.item_name] = 2
		"ranger":
			# Long bow + Parrying Dagger (offhand, throw-parry)
			var bow = load("res://resources/items/loy/long_bow.tres") as EquipmentItem
			var parry_dgr = load("res://resources/items/loy/parrying_dagger.tres") as EquipmentItem
			if bow:
				equipment_manager.add_to_inventory(bow.make_copy())
				equipment_manager.toggle_equip(equipment_manager.inventory.size() - 1)
				_quickbar_preload[bow.item_name] = 0
			if parry_dgr:
				equipment_manager.add_to_inventory(parry_dgr.make_copy())
				equipment_manager.toggle_equip(equipment_manager.inventory.size() - 1)
				_quickbar_preload[parry_dgr.item_name] = 1
		"wizard":
			var staff = load("res://resources/items/loy/staff.tres") as EquipmentItem
			if staff:
				equipment_manager.add_to_inventory(staff.make_copy())
				equipment_manager.toggle_equip(equipment_manager.inventory.size() - 1)
				_quickbar_preload[staff.item_name] = 0

	# Leather armor goes to everyone EXCEPT wizard — their kit is staff-only by
	# design (cloth caster fantasy / no mid-game leather-vs-robe trade-off).
	if starter_armor and player_class != "wizard":
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
	# Stamina pot — needed so the auto-fill in _populate_quickbar can put one in
	# the action bar; without inventory backing the slot would just look broken.
	var stam_potion = load("res://resources/items/loy/green_potion.tres") as EquipmentItem
	if stam_potion:
		for i in range(5):
			equipment_manager.add_to_inventory(stam_potion.make_copy())

	# Hall of Souls starting-bonus carry-overs
	var gm_h = get_node_or_null("/root/GameManager")
	if gm_h and gm_h.has_method("get_hall_upgrade_level") and gm_h.save_data:
		# Apothecary's Gift: extra red potions
		var extra_pots = gm_h.get_hall_upgrade_level("starting_potions")
		if extra_pots > 0 and red_potion:
			for i in range(extra_pots):
				equipment_manager.add_to_inventory(red_potion.make_copy())
		# Veteran's Stipend: starting gold
		var bonus_gold = gm_h.get_hall_upgrade_level("starting_gold") * 50
		if bonus_gold > 0 and gm_h.has_method("add_gold"):
			gm_h.add_gold(bonus_gold, false)
		# Free Stat Points
		var bonus_stat_pts = gm_h.get_hall_upgrade_level("free_stat_points") * 2
		if bonus_stat_pts > 0 and level_system:
			level_system.unspent_stat_points += bonus_stat_pts
		# Perk Token Carryover
		var bonus_tokens = gm_h.get_hall_upgrade_level("perk_token_carryover")
		if bonus_tokens > 0:
			var pm = get_node_or_null("/root/PerkManager")
			if pm and pm.has_method("add_token"):
				pm.add_token(bonus_tokens)
		# Soul Anchor: start at higher level
		var anchor_levels = gm_h.get_hall_upgrade_level("soul_anchor")
		if anchor_levels > 0 and level_system and level_system.level == 1:
			for _i in range(anchor_levels):
				level_system.gain_xp(level_system.xp_to_next_level(), 1.0)

	# Quickbar layout is applied by _apply_class_action_bar_defaults (deferred
	# from the main _ready). _quickbar_preload is no longer used as the
	# placement source; the class layout in _get_class_action_bar_layout() owns
	# the slot positions.

## Authoritative per-class action-bar layout. Called for both new and existing
## characters from player._ready (deferred so the HUD has spawned). Forces the
## weapon into slot 0 and the offhand into slot 1; pots fill empty seed slots
## only, so player customisation past slot 4 stays intact.
func _apply_class_action_bar_defaults() -> void:
	if not is_inside_tree():
		return
	var hud = get_tree().get_first_node_in_group("game_hud") as CanvasLayer
	if not hud:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		hud = get_tree().get_first_node_in_group("game_hud") as CanvasLayer
	if not hud:
		return
	var layout := _get_class_action_bar_layout()
	# Weapons + offhand: force-overwrite. The class identity says "your sword
	# lives at hotkey 1", and stale Apple/Red Potion that the old fallback
	# wrote must be cleared so the weapon is visible without manual cleanup.
	for entry in layout.get("force", []):
		var slot: int = entry["slot"]
		var name: String = entry["name"]
		# Only place the item if the player actually has it in inventory —
		# otherwise we leak a phantom name into the bar that the refresh can't
		# resolve to an icon.
		if _inventory_has_item(name):
			hud.assign_to_quickbar(slot, name)
		elif slot < hud._quickbar_items.size() and hud._quickbar_items[slot] != "":
			# No item in inventory but a stale name is sitting there — clear it
			# so the slot doesn't show a broken icon.
			hud.assign_to_quickbar(slot, "")
	# Pots: fill empty seed slots only. Lets the player rearrange / drop pots
	# elsewhere without us undoing their work each scene load.
	for entry in layout.get("pots", []):
		var slot: int = entry["slot"]
		var name: String = entry["name"]
		if slot >= hud._quickbar_items.size():
			continue
		if hud._quickbar_items[slot] == "" and _inventory_has_item(name):
			hud.assign_to_quickbar(slot, name)

func _inventory_has_item(name: String) -> bool:
	if name == "" or not equipment_manager:
		return false
	for it in equipment_manager.inventory:
		if it and it.item_name == name:
			return true
	return false

## Returns {"force": [{slot, name}, ...], "pots": [{slot, name}, ...]} for the
## current class. Force-list items always claim their slot (weapons + offhand);
## pot-list items only fill empty slots so player edits are preserved.
func _get_class_action_bar_layout() -> Dictionary:
	var pc := _get_player_class()
	match pc:
		"wizard":
			return {
				"force": [
					{"slot": 0, "name": "Staff"},
				],
				"pots": [
					{"slot": 1, "name": "Red Potion"},
					{"slot": 2, "name": "Mana Potion"},
					{"slot": 3, "name": "Stamina Potion"},
				],
			}
		"warrior":
			return {
				"force": [
					{"slot": 0, "name": "Sword"},
					{"slot": 1, "name": "Wooden Shield"},
				],
				"pots": [
					{"slot": 2, "name": "Red Potion"},
					{"slot": 3, "name": "Mana Potion"},
					{"slot": 4, "name": "Stamina Potion"},
				],
			}
		"mercenary":
			return {
				"force": [
					{"slot": 0, "name": "Sword"},
					{"slot": 1, "name": "Short Bow"},
				],
				"pots": [
					{"slot": 2, "name": "Red Potion"},
					{"slot": 3, "name": "Mana Potion"},
					{"slot": 4, "name": "Stamina Potion"},
				],
			}
		"ranger":
			return {
				"force": [
					{"slot": 0, "name": "Long Bow"},
					{"slot": 1, "name": "Parrying Dagger"},
				],
				"pots": [
					{"slot": 2, "name": "Red Potion"},
					{"slot": 3, "name": "Mana Potion"},
					{"slot": 4, "name": "Stamina Potion"},
				],
			}
		_:
			return {"force": [], "pots": []}

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
	# Phase through enemies while dashing so we never get pinned by a heavy elite.
	# Walls (layer 16) and decals (layer 64) still collide.
	set_collision_mask_value(2, false)
	var _ns_dash = get_node_or_null("/root/NoiseSystem")
	if _ns_dash: _ns_dash.emit_noise(global_position, 80.0, 0.5)
	# Combat Roll perk: dash grants 1s stealth
	var _pm_cr = get_node_or_null("/root/PerkManager")
	if _pm_cr and _pm_cr.has_special("combat_roll"):
		_sneaking = true
	if _player_anim:
		_player_anim.set_direction(_dash_direction)  # lock direction to dash direction
		_player_anim.set_state(PlayerAnimator.AnimState.DASH)
	# SFX + VFX
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("woosh_a", -3.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.dash_afterimage(sprite, global_position, null, z_index - 1)

	# Wraithwalk: dash leaves a damaging shadow trail
	if _has_effect("wraithwalk"):
		_spawn_wraithwalk_trail()

func _warrior_dash_burst() -> void:
	# Warrior dash end: AoE around player, knockback + damage.
	# Rage scaling: +0.4% damage per stack on the AoE (up to +40% at 100 rage).
	var base_dmg = equipment_manager.get_damage() if equipment_manager else 1
	var rage_mult = 1.0 + class_meter * 0.004
	var dmg = maxi(2, int((base_dmg * 2.0 + level_system.level * 0.5) * rage_mult))
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_mult = 4.0 if in_ow else 1.0
	var radius = 32.0 * scale_mult
	var kb_force = (180.0 + base_dmg * 4.0) * scale_mult
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var to_e = e.global_position - global_position
		var dist = to_e.length()
		if dist > radius:
			continue
		if e.has_method("take_damage"):
			e.take_damage(dmg)
		var kb_dir = to_e.normalized() if dist > 0.01 else Vector2.RIGHT
		e.velocity = kb_dir * kb_force
		if e.has_method("apply_status"):
			e.apply_status("STUNNED", 0.8)
	var vfx_db = get_node_or_null("/root/VFXManager")
	if vfx_db:
		vfx_db.shockwave(global_position, radius, Color(1.0, 0.6, 0.2, 0.7))
		vfx_db.shake(2.5, 0.15)
	var sfx_db = get_node_or_null("/root/SFXManager")
	if sfx_db:
		sfx_db.play("hit", -2.0)

func _spawn_wraithwalk_trail() -> void:
	# Damaging Area2D that lingers for 1.5s and ticks enemies in radius
	var trail := Area2D.new()
	trail.global_position = global_position
	trail.collision_layer = 0
	trail.collision_mask = 2  # enemy layer
	trail.process_mode = Node.PROCESS_MODE_PAUSABLE
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	trail.add_child(shape)
	# Visual: purple shadow puff
	var vfx_w = get_node_or_null("/root/VFXManager")
	if vfx_w and vfx_w.has_method("status_puff"):
		vfx_w.status_puff(global_position, "CONFUSED")
	# Damage tick on enter + every 0.4s
	var dmg = maxi(2, equipment_manager.get_damage() / 4) if equipment_manager else 4
	var trail_script := GDScript.new()
	trail_script.source_code = """extends Area2D
var dmg: int = 4
var ttl: float = 1.5
var tick: float = 0.0
func _physics_process(delta: float) -> void:
	ttl -= delta
	tick -= delta
	if tick <= 0.0:
		tick = 0.4
		for body in get_overlapping_bodies():
			if body and body.has_method('take_damage') and body.is_in_group('enemy'):
				body.take_damage(dmg)
	if ttl <= 0.0:
		queue_free()
"""
	trail_script.reload()
	trail.set_script(trail_script)
	trail.set("dmg", dmg)
	var parent = get_parent()
	if parent:
		parent.add_child(trail)

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
		var enemy_def = e.get("definition")
		if enemy_def != null and enemy_def.size_class >= 2:  # BOSS
			if is_melee and not _dash_hit_enemies.has(e.get_instance_id()):
				_dash_hit_enemies[e.get_instance_id()] = true
				var boss_dmg = int(dmg * DASH_BOSS_DMG_MULT)
				if _lunge_active:
					_lunge_hit_count += 1
					boss_dmg = int(boss_dmg * (1.0 + _lunge_hit_count * 0.5))
				if e.has_method("take_damage"):
					e.take_damage(boss_dmg)
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
				var lunge_push = e.get("_pushed_velocity")
				if lunge_push != null:
					e.set("_pushed_velocity", _dash_direction * kb_force)
				else:
					e.velocity = _dash_direction * kb_force
				if e.get("_contact_bounce") != null:
					e.set("_contact_bounce", 0.3)
			else:
				var kb_dir = (e.global_position - global_position).normalized()
				var enemy_push = e.get("_pushed_velocity")
				if enemy_push != null:
					e.set("_pushed_velocity", kb_dir * kb_force)
				else:
					e.velocity = kb_dir * kb_force
				if e.get("_contact_bounce") != null:
					e.set("_contact_bounce", 0.2)
			# VFX: impact spark per hit during lunge
			if _lunge_active:
				var vfx = get_node_or_null("/root/VFXManager")
				if vfx:
					vfx.hit_spark(e.global_position)
		# Environmental nudge: push enemy in dash direction (all weapons)
		elif e.get("_nudge_timer") != null and e._nudge_timer <= 0:
			e._nudge_velocity = _dash_direction * nudge_speed
			e._nudge_timer = 0.15

# --- Off-hand Throw (Parrying Dagger; bullet-clear + chip damage) ---

func _throw_secondary(offhand_item: EquipmentItem = null) -> void:
	if not is_inside_tree() or not weapon_system or not weapon_system.bullet_scene:
		return
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		return
	# Off-class penalty: half damage, 1 bullet kill (vs 3), double stamina cost.
	var prof = equipment_manager.get_offhand_proficiency_mult(_get_player_class()) if equipment_manager else 1.0
	var stam_cost = OFFHAND_THROW_STAMINA * (1.0 if prof >= 1.0 else 2.0)
	if stamina < stam_cost:
		return
	stamina = maxf(stamina - stam_cost, 0.0)
	_stamina_regen_delay = 0.5
	stamina_changed.emit(stamina)
	_offhand_throw_cooldown = OFFHAND_THROW_COOLDOWN

	# Aim at the mouse / aim joystick, NOT the lock-on shoot direction.
	var aim_dir = _get_parry_direction()
	var base_dmg = equipment_manager.get_damage() if equipment_manager else 1
	var dmg = maxi(1, int(base_dmg * 0.4 * prof))  # chip damage scaled by proficiency

	var bullet = weapon_system.bullet_scene.instantiate()
	bullet.global_position = global_position + aim_dir * 8.0
	bullet.direction = aim_dir
	bullet.is_player_bullet = true
	bullet.speed = OFFHAND_THROW_SPEED
	bullet.lifetime = OFFHAND_THROW_LIFETIME
	bullet.damage = dmg
	# Pierces enemies (chip damage + WEAKEN on hit) and destroys enemy bullets
	bullet.set("_hits_remaining", 6)
	bullet.set_meta("offhand_throw", true)
	# Bullet destruction limit scales by proficiency (3 native, 1 off-class)
	bullet.set_meta("destroys_bullets_left", OFFHAND_BULLET_DESTROY_LIMIT if prof >= 1.0 else 2)
	bullet.set_meta("apply_weaken", 1.5 if prof >= 1.0 else 0.8)
	bullet.collision_layer = 4
	bullet.collision_mask = 2 | 8 | 16  # enemies + enemy bullets + walls
	# Visual tint from item enchantment if present
	if offhand_item and offhand_item.enchantment:
		var spr_t = bullet.get_node_or_null("Sprite2D")
		if spr_t:
			spr_t.modulate = offhand_item.enchantment.get_color()
	bullets_container.add_child(bullet)

	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("swing", -8.0, 0.1)

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
	var speed = equipment_manager.get_bullet_speed() * _get_scene_projectile_scale()
	# Class identity tuning:
	#   Archer (native): 2 extra bullets, 60% dmg, narrow spread — the bow specialist
	#   Warrior:         1 extra heavy bullet, 110% dmg, no spread — a "power draw"
	#   Mercenary:       3 extra bullets, 45% dmg, wider spread — a scattergun feel
	#   Wizard:          2 extra bullets, 50% dmg, magical purple tint
	var pc = _get_player_class()
	var extra_count = MULTISHOT_EXTRA_BULLETS
	var spread_step = MULTISHOT_SPREAD
	var per_bullet_dmg = 0.6
	var tint: Color = Color.WHITE
	match pc:
		"warrior":
			extra_count = 1
			spread_step = 0.0  # straight power draw
			per_bullet_dmg = 1.10
		"mercenary":
			extra_count = 3
			spread_step = 0.14
			per_bullet_dmg = 0.45
		"wizard":
			extra_count = 2
			spread_step = 0.10
			per_bullet_dmg = 0.5
			tint = Color(0.6, 0.4, 1.0)
		_:  # archer/ranger native + fallback
			extra_count = 2
			spread_step = MULTISHOT_SPREAD
			per_bullet_dmg = 0.6
	for i in range(extra_count):
		var angle_offset = spread_step * (i + 1) * (1.0 if i % 2 == 0 else -1.0)
		var spread_dir = aim_dir.rotated(angle_offset)
		var bullet = bullet_scene.instantiate()
		bullet.global_position = global_position
		bullet.direction = spread_dir
		bullet.is_player_bullet = true
		bullet.speed = speed
		bullet.damage = maxi(1, int(base_damage * per_bullet_dmg))
		if tint != Color.WHITE and "modulate" in bullet:
			bullet.modulate = tint
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
		bullet.speed = equipment_manager.get_bullet_speed() * _get_scene_projectile_scale() * CHARGE_SPEED_MULT * shield_penalty
		bullet.damage = maxi(5, int(base_damage * dmg_mult) + flat_bonus)
		bullet.set_meta("sprite_scale_mult", size_mult)
		bullet.set_meta("projectile_fx_kind", "arcane")
		bullet.set_meta("projectile_fx_energy", 1.0 + ratio * 0.5)
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
		bullet.speed = equipment_manager.get_bullet_speed() * _get_scene_projectile_scale() * 0.8 * shield_penalty
		bullet.damage = base_damage + 1
		bullet.set_meta("sprite_scale_mult", 1.2)
		bullet.set_meta("projectile_fx_kind", "arcane")
		bullet.set_meta("projectile_fx_energy", 0.7 + ratio * 0.2)
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
	bullet.speed = equipment_manager.get_bullet_speed() * _get_scene_projectile_scale()
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
	bullet.set_meta("projectile_fx_kind", "lightning")
	bullet.set_meta("projectile_fx_energy", 0.95)
	bullets_container.add_child(bullet)
	# Tint bullet yellow-green for paralyze
	var bspr = bullet.get_node_or_null("Sprite2D")
	if bspr:
		bspr.modulate = Color(0.6, 1.0, 0.3)
	# SFX
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("woosh_a", -1.0, 0.05)

func _release_staff_charge(force_fire: bool) -> void:
	if not _charge_active:
		return
	var should_fire := force_fire or _charge_time >= CHARGE_MIN_TIME
	if should_fire:
		_stamina_regen_delay = 1.0
		var mp_to_use = minf(mp, CHARGE_MP_COST)
		if mp_to_use > 0:
			use_mp(mp_to_use)
		_fire_charged_blast()
		if _player_anim:
			_player_anim.set_state(PlayerAnimator.AnimState.SPECIAL_ATTACK, 1)
	else:
		if _player_anim:
			_player_anim.set_state(PlayerAnimator.AnimState.IDLE)
	_charge_active = false
	_charge_time = 0.0
	_hide_charge_indicator()

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
			starter_ids = ["shield_bash", "iron_skin"]
		"mercenary":
			starter_ids = ["battle_cry", "berserk"]
		"ranger":
			starter_ids = ["arrow_rain", "evasion_surge", "heal"]
		"wizard":
			# Wizard's whole identity is spells, so they start with a full hand.
			starter_ids = ["frost_nova", "bullet_shield", "lightning_x", "arcane_familiar", "inferno_lance", "minor_heal"]

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
		"mana_shield": "res://resources/spells/mana_shield.tres",
		"evasion_surge": "res://resources/spells/evasion_surge.tres",
		"minor_heal": "res://resources/spells/minor_heal.tres",
		"bullet_shield": "res://resources/spells/bullet_shield.tres",
		"lightning_x": "res://resources/spells/lightning_x.tres",
		"arcane_familiar": "res://resources/spells/arcane_familiar.tres",
		"inferno_lance": "res://resources/spells/inferno_lance.tres",
	}
	# Additive: learn anything new, equip into the first empty slot AT OR AFTER
	# the class's ability start slot. The bar layout reserves slots 0..N-1 for
	# weapons + pots, so starting from N keeps spells from sharing a slot with
	# an item (item wins display + click in the unified router).
	var ability_start := _get_ability_start_slot()
	for sid in starter_ids:
		if not all_spells.has(sid):
			continue
		var spell = load(all_spells[sid]) as SpellDefinition
		if not spell:
			continue
		# Already bound somewhere → leave it alone.
		var already_equipped := false
		for i in range(spell_book.MAX_SPELL_SLOTS):
			if spell_book.spell_slots[i] and spell_book.spell_slots[i].id == sid:
				already_equipped = true
				break
		spell_book.learn_spell(spell)
		if already_equipped:
			continue
		# Find first empty spell-slot AT OR AFTER ability_start. Fall back to
		# scanning from 0 only if every slot above ability_start is full — the
		# spell will live somewhere, even if it overlaps an item visually.
		var placed := false
		for i in range(ability_start, spell_book.MAX_SPELL_SLOTS):
			if spell_book.spell_slots[i] == null:
				spell_book.equip_spell(spell, i)
				placed = true
				break
		if not placed:
			for i in range(spell_book.MAX_SPELL_SLOTS):
				if spell_book.spell_slots[i] == null:
					spell_book.equip_spell(spell, i)
					break

## Per-class index where abilities start sitting on the action bar. Slots
## 0..ability_start-1 are reserved for the class's weapon/offhand + HP/MP/
## stamina pots set up by _give_starting_items + _populate_quickbar.
func _get_ability_start_slot() -> int:
	var pc := _get_player_class()
	match pc:
		"wizard":
			return 4  # 0=staff, 1=red, 2=mana, 3=stamina, 4..9=abilities
		_:
			return 5  # 0=weapon, 1=offhand, 2=red, 3=mana, 4=stamina, 5..9=abilities

func _use_spell_slot(index: int) -> void:
	if not spell_book or index < 0 or index >= spell_book.MAX_SPELL_SLOTS:
		return
	var spell = spell_book.spell_slots[index] as SpellDefinition
	if not spell:
		return

	# --- Per-class pre-cast effects ---
	# Warrior Rage spell-fuel: Iron Skin & Shield Bash MP cost reduced 1:1 by current rage.
	var effective_mp_cost = float(spell.mp_cost)
	var rage_spent := 0.0
	var pc_sp = _get_player_class()
	if pc_sp == "warrior" and (spell.id == "iron_skin" or spell.id == "shield_bash") and class_meter > 0.0:
		var discount = minf(effective_mp_cost, class_meter)
		effective_mp_cost = maxf(0.0, effective_mp_cost - discount)
		rage_spent = discount

	# Wizard empowerment: now ONLY happens during Overflow (X-key window).
	# Mana Flow no longer gets drained by every empowerable cast — it's a pure
	# passive resource that boosts MP regen and feeds Overflow.
	_empowered_cast_pending = false
	var now_sp = Time.get_ticks_msec() / 1000.0
	if pc_sp == "wizard" and now_sp < _wizard_overflow_until:
		var emp_cost = float(WIZARD_EMPOWERMENT_COSTS.get(spell.id, -1))
		_empowered_cast_pending = emp_cost > 0

	# --- Cast guards ---
	# Cooldown gate (always enforced).
	if spell_book.slot_cooldowns[index] > 0.0:
		_empowered_cast_pending = false
		return
	# MP gate: warrior rage-fuel + wizard Overflow both bypass it.
	var can_pay = mp >= effective_mp_cost or (pc_sp == "wizard" and now_sp < _wizard_overflow_until)
	if not can_pay:
		_empowered_cast_pending = false
		return
	if spell.id == "mana_surge" and stamina < 30.0:
		_empowered_cast_pending = false
		return

	# Pay costs.
	use_mp(effective_mp_cost)
	if rage_spent > 0.0:
		class_meter = maxf(0.0, class_meter - rage_spent)
		class_meter_changed.emit(class_meter, class_meter_max)

	# Cooldown — Overflow ticks cooldowns 3× faster, so reduce the locked time accordingly.
	var cdr = clampf(equipment_manager.get_total_cooldown_reduction(), 0.0, 50.0)
	var cd_time = spell.cooldown * (1.0 - cdr / 100.0)
	if pc_sp == "wizard" and now_sp < _wizard_overflow_until:
		cd_time /= WIZARD_OVERFLOW_COOLDOWN_MULT
	spell_book.slot_cooldowns[index] = cd_time

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
			"minor_heal":
				_ability_minor_heal()
			"bullet_shield":
				_ability_bullet_shield()
			"lightning_x":
				_ability_lightning_x()
			"arcane_familiar":
				_ability_arcane_familiar()
			"inferno_lance":
				_ability_inferno_lance()
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

func _update_double_tap_sprint() -> void:
	# If we're already sprinting from a double-tap, hold it; the main sprint
	# block decides when to drop the flag based on stamina / movement input.
	if _double_tap_sprint:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for action in ["move_up", "move_down", "move_left", "move_right"]:
		if Input.is_action_just_pressed(action):
			var last: float = _last_move_tap_time.get(action, -1.0)
			if last > 0.0 and now - last <= DOUBLE_TAP_SPRINT_WINDOW:
				_double_tap_sprint = true
			_last_move_tap_time[action] = now


func _stone_toss() -> void:
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_mult = 4.0 if in_ow else 1.0
	# Stone goes wherever you aim — no range cap. Lob duration scales below so
	# longer throws don't blur into hyperspeed.
	var target_pos: Vector2
	if touch_controls and touch_controls.visible and touch_controls.get_aim_input().length() > 0.1:
		var aim_dir = touch_controls.get_aim_input().normalized()
		# Touch has no cursor — fall back to a generous default reach.
		target_pos = global_position + aim_dir * STONE_TOSS_RANGE * 6.0 * scale_mult
	else:
		target_pos = get_global_mouse_position()
	var aim_dir = (target_pos - global_position).normalized()
	var bullet_scn = preload("res://scenes/bullet.tscn")
	var stone = bullet_scn.instantiate()
	stone.global_position = global_position
	stone.direction = aim_dir
	stone.is_player_bullet = true
	stone.damage = 0  # no damage — triggers noise on landing
	# Scale lob duration with distance so a long throw still feels like an arc
	# instead of a hitscan. ~250 px / sec at dungeon scale, ~1000 in overworld.
	var throw_dist := global_position.distance_to(target_pos)
	var travel_speed: float = 1000.0 if in_ow else 250.0
	var lob_time: float = clampf(throw_dist / travel_speed, 0.25, 1.5)
	stone.lifetime = lob_time + 0.5
	stone.bullet_sprite_index = 131  # grey bolt from lofi_obj.png
	stone.behavior = stone.BulletBehavior.LOBBED
	stone._target_pos = target_pos
	stone._lob_start_pos = global_position
	stone._lob_duration = lob_time
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
			var grapple_def = e.get("definition")
			if grapple_def != null and grapple_def.size_class >= grapple_def.SizeClass.BOSS:
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
	# Targeted AoE freeze at aim position — distributes damage across enemies.
	# EMPOWERED: ~70% larger radius, longer freeze, survivors get a 4s SLOWED chill after thaw.
	var empowered = _consume_empowered()
	var base_dmg = equipment_manager.get_damage()
	var max_total_dmg = maxi(3, int(base_dmg * (4.0 if empowered else 3.0) + level_system.level * 0.8))
	var in_ow_fn = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var ow_scale = 4.0 if in_ow_fn else 1.0
	var radius = ((48.0 if empowered else 28.0) + level_system.level * 0.5) * ow_scale
	var freeze_dur = (2.2 if empowered else 1.5) + level_system.level * 0.04
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
				# Empowered: 4s SLOWED status after the freeze wears off (overwrites
				# nothing — SLOWED takes hold once FROZEN ticks down).
				if empowered:
					e.apply_status("SLOWED", freeze_dur + 4.0)

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
	# Oryx FX overlay — 2-frame impact → explosion flipbook centred on the nova.
	# ice_impact is the bright initial hit; ice_explosion is the ring shockwave.
	# target_px ≈ radius × 1.2 keeps the sprite footprint close to the actual
	# AoE rather than blowing past it like the old 2.0× did.
	FXAtlasLookup.spawn_anim(self, ["ice_impact", "ice_explosion"], target_pos, 0.10, radius * 1.2, 9, false, 0.5)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		# Pitched down + quieter + a lower crackle underneath. The default
		# sorcery sample was too high and shrill for a frost effect.
		sfx.play("sorcery", -8.0, 0.06, 0.55)
		sfx.play("lightning_b", -10.0, 0.08, 0.7)

func _ability_teleport() -> void:
	# Blink forward in aim direction — distance scales with level.
	# Doubled base distance + per-level so the wizard actually escapes / repositions.
	var aim_dir = _get_free_aim_direction()
	var in_ow_tp = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var base_dist = 130.0 + level_system.level * 3.0
	var dist = base_dist * (4.0 if in_ow_tp else _get_scene_motion_scale())
	var start_pos = global_position
	var target = global_position + aim_dir * dist
	# Raycast to prevent teleporting through walls / out of bounds. If we hit
	# a wall, try to phase through up to ~2 tiles of it — peek past the hit
	# point and if there's clear floor on the other side, blink there.
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target, collision_mask)
	var result = space.intersect_ray(query)
	if result:
		var tile_size: float = 32.0 if in_ow_tp else 8.0
		var wall_budget: float = tile_size * 2.0 + 2.0  # 2 tiles + tiny buffer
		var exit_pos: Vector2 = result.position + aim_dir * wall_budget
		# Clamp exit_pos to the desired target if we'd overshoot the player's pick
		if (exit_pos - global_position).length() > (target - global_position).length():
			exit_pos = target
		var pq := PhysicsPointQueryParameters2D.new()
		pq.position = exit_pos
		pq.collision_mask = collision_mask
		pq.collide_with_areas = false
		pq.collide_with_bodies = true
		if space.intersect_point(pq, 1).is_empty():
			# Other side is open space — blink across the wall.
			target = exit_pos
		else:
			# Wall too thick or no clear floor past it; stop short.
			target = result.position - aim_dir * 2.0
	# Brief invincibility during teleport (watchdog-bounded to 0.3 s).
	# Also phase through enemies + enemy bullets — landing on an enemy mid-blink
	# shouldn't shove you back or eat a contact hit. Restored on tween callback.
	invincible = true
	_invincible_until = Time.get_ticks_msec() / 1000.0 + 0.3
	set_collision_mask_value(2, false)  # enemy bodies (CharacterBody2D)
	set_collision_mask_value(4, false)  # enemy bullets (Area2D)
	global_position = target
	# Visual: fade out at start, fade in at end
	sprite.modulate = Color(0.5, 0.5, 2.0, 0.3)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	tween.tween_callback(func():
		invincible = false
		_invincible_until = 0.0
		set_collision_mask_value(2, true)
		set_collision_mask_value(4, true)
	)
	# VFX at start and end — small radii + duration_scale 0.25 so the shader
	# disappears almost instantly instead of lingering after the blink.
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.warp_link(start_pos, target, Color(0.86, 0.08, 0.05, 0.98), 4.5, 6.5, null, 0.25)
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
	_invincible_until = Time.get_ticks_msec() / 1000.0 + blind_duration
	_sneaking = true
	sprite.modulate.a = 0.3
	if status_effects:
		status_effects.apply_buff("speed", blind_duration, 0.5)
		status_effects.apply_buff("stealth", blind_duration, 50.0)
	var tween = create_tween()
	tween.tween_interval(blind_duration)
	tween.tween_callback(func():
		invincible = false
		_invincible_until = 0.0
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
	# Restore 20 + level*2 HP.
	# EMPOWERED: AoE heal pulse — heals self for 1.5× AND adds a small shield (10 + level).
	var empowered = _consume_empowered()
	# Phase 1 ×12: heal amounts scaled to match 360-HP class baseline.
	var amount = 240 + level_system.level * 24
	if empowered:
		amount = int(amount * 1.5)
	heal(amount)
	if empowered:
		shield += 120 + level_system.level * 12
		var scene_root = get_tree().current_scene if is_inside_tree() else null
		if scene_root:
			FloatingText.spawn(scene_root, global_position + Vector2(0, -28), "+%d Shield" % (10 + level_system.level), Color(0.6, 0.85, 1.0))
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
		if empowered:
			vfx.shockwave(global_position, 28.0, Color(0.4, 1.0, 0.5, 0.5))

func _ability_minor_heal() -> void:
	# Wizard starter: quick small heal. Phase 1 ×12 ≈ 96 + lvl*12.
	var amount = 96 + level_system.level * 12
	heal(amount)
	sprite.modulate = Color(0.6, 1.8, 0.6)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("heal_a", -3.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.status_puff(global_position, Color(0.4, 1.0, 0.5))

func _ability_arcane_familiar() -> void:
	# Summon a single floating wisp that auto-fires + can be steered with V.
	var familiar_script: GDScript = load("res://scripts/objects/arcane_familiar.gd")
	if not familiar_script:
		return
	# Despawn any previous one — one familiar at a time.
	for node in get_tree().get_nodes_in_group("arcane_familiar"):
		if is_instance_valid(node):
			node.queue_free()
	var fam = familiar_script.new()
	fam.add_to_group("arcane_familiar")
	fam.player = self
	fam.global_position = global_position + Vector2(20, -10)
	get_tree().current_scene.add_child(fam)
	var sfx_af = get_node_or_null("/root/SFXManager")
	if sfx_af:
		sfx_af.play("mystical", -6.0, 0.1, 1.3)
	var vfx_af = get_node_or_null("/root/VFXManager")
	if vfx_af and vfx_af.has_method("shockwave"):
		vfx_af.shockwave(global_position, 20.0, Color(0.6, 0.8, 1.0, 0.7))


func _ability_inferno_lance() -> void:
	# Charged fire spear — fast piercing projectile that explodes on impact.
	var in_ow_il := get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_il := 4.0 if in_ow_il else 1.0
	var aim_dir: Vector2
	if touch_controls and touch_controls.visible and touch_controls.get_aim_input().length() > 0.1:
		aim_dir = touch_controls.get_aim_input().normalized()
	else:
		aim_dir = (get_global_mouse_position() - global_position).normalized()
	if aim_dir.length() < 0.1:
		aim_dir = _last_move_dir if _last_move_dir.length() > 0.0 else Vector2.RIGHT
	var bullet = preload("res://scenes/bullet.tscn").instantiate()
	bullet.global_position = global_position + aim_dir * 6.0 * scale_il
	bullet.direction = aim_dir
	bullet.is_player_bullet = true
	var base_dmg = equipment_manager.get_damage()
	bullet.damage = maxi(15, int(base_dmg * 4.0 + level_system.level * 0.6))
	bullet.speed = 200.0 * scale_il
	bullet.lifetime = 1.4
	bullet.bullet_sprite_index = 131
	# Use the existing fireball AoE hook so impact spawns a flame burst.
	if "set_meta" in bullet:
		bullet.set_meta("fireball_aoe", true)
		bullet.set_meta("fireball_aoe_radius", 26.0 * scale_il)
		# Oryx visuals: single firebolt streak in flight, 2-frame fire burst on
		# impact. Override the default lofi bullet pellet so the lance reads
		# as a charged spell instead of a regular shot. Scale 0.25 = half of
		# the previous 0.5 so the projectile reads as a focused spear instead
		# of a huge fireball blocking the screen.
		bullet.set_meta("fx_overlay", "firebolt")
		bullet.set_meta("fx_overlay_scale", 0.25)
		bullet.set_meta("fx_impact", ["fire_impact", "fire_explosion"])
	if "pierce_count" in bullet:
		bullet.pierce_count = 2
	get_tree().current_scene.add_child(bullet)
	var sfx_il = get_node_or_null("/root/SFXManager")
	if sfx_il:
		sfx_il.play("bazooka", -4.0, 0.08, 0.85)
	var vfx_il = get_node_or_null("/root/VFXManager")
	if vfx_il and vfx_il.has_method("shockwave"):
		vfx_il.shockwave(global_position, 14.0, Color(1.0, 0.5, 0.15, 0.7))


func _ability_lightning_x() -> void:
	# Mark the ground at the cursor with a glowing X. After 3 s, lightning
	# strikes a medium AoE: 10 base damage + 5 s stun on hit.
	var in_ow_lx := get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_lx: float = 4.0 if in_ow_lx else 1.0
	var target_pos: Vector2
	if touch_controls and touch_controls.visible and touch_controls.get_aim_input().length() > 0.1:
		target_pos = global_position + touch_controls.get_aim_input().normalized() * 80.0 * scale_lx
	else:
		target_pos = get_global_mouse_position()
	var radius_lx: float = 36.0 * scale_lx
	# Telegraph: a flickering electric ball at the target. spawn_anim() handles
	# the 2-frame loop (electric_ball ↔ electric_ball_2) and self-frees after
	# total_duration. Sprite footprint ≈ AoE radius so the marker reads as
	# "this is the danger zone" rather than overhanging the affected area.
	var glyph := FXAtlasLookup.spawn_anim(
		self,
		["electric_ball", "electric_ball_2"],
		target_pos,
		0.10,                # frame_duration → tight flicker
		radius_lx * 1.0,
		5,
		true,                # loop
		3.0                  # total_duration → matches the strike delay
	)
	var sfx_pre = get_node_or_null("/root/SFXManager")
	if sfx_pre:
		sfx_pre.play("ping", -6.0, 0.05)
	# Schedule the strike.
	var dmg_lx := 10
	var stun_dur := 5.0
	get_tree().create_timer(3.0).timeout.connect(func():
		# Kill the telegraph the moment the strike lands — let spawn_anim's
		# internal cleanup handle the fade if the glyph is still around.
		if is_instance_valid(glyph):
			glyph.queue_free()
		var vfx_lx = get_node_or_null("/root/VFXManager")
		if vfx_lx:
			if vfx_lx.has_method("shockwave"):
				vfx_lx.shockwave(target_pos, radius_lx * 1.4, Color(0.5, 0.85, 1.0, 0.9))
			if vfx_lx.has_method("shake"):
				vfx_lx.shake(2.5, 0.18)
		# Strike VFX: 2-frame burst (electric_explosion_1 → electric_explosion_2)
		# at ~1.3× radius — slight overshoot reads as the bolt actually expanding
		# past its damage area, without flooding the screen.
		FXAtlasLookup.spawn_anim(
			self,
			["electric_explosion_1", "electric_explosion_2"],
			target_pos,
			0.08,
			radius_lx * 1.3,
			10
		)
		var sfx_hit = get_node_or_null("/root/SFXManager")
		if sfx_hit:
			sfx_hit.play("boom_b", -4.0, 0.08, 0.85)
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e):
				continue
			if e.global_position.distance_to(target_pos) > radius_lx:
				continue
			if e.has_method("take_damage"):
				e.take_damage(dmg_lx)
			if e.has_method("apply_status"):
				e.apply_status("STUNNED", stun_dur)
	)


func _clear_bullet_shield_sprite() -> void:
	# Fade + free the bullet shield bubble. Called by the watchdog the instant
	# charges hit zero or the 12s timer runs out, so the visual never lingers.
	if not is_instance_valid(_bullet_shield_sprite):
		_bullet_shield_sprite = null
		return
	var s := _bullet_shield_sprite
	_bullet_shield_sprite = null
	var fade := s.create_tween()
	fade.tween_property(s, "modulate:a", 0.0, 0.2)
	fade.tween_callback(s.queue_free)


func _ability_bullet_shield() -> void:
	# Wizard starter: absorbs the next 4 bullets within 12 s. State lives in
	# _bullet_shield_charges / _bullet_shield_until (see take_damage).
	_bullet_shield_charges = 4
	_bullet_shield_until = Time.get_ticks_msec() / 1000.0 + 12.0
	# Clean up the legacy meta if anything ever set it (older saves / scripts).
	if has_meta("bullet_shield_charges"):
		remove_meta("bullet_shield_charges")
	if has_meta("bullet_shield_expires"):
		remove_meta("bullet_shield_expires")
	sprite.modulate = Color(0.6, 0.9, 1.6)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("clack", -3.0)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position, 32.0, Color(0.4, 0.7, 1.0, 0.85))
	var scene_root_bs = get_tree().current_scene if is_inside_tree() else null
	if scene_root_bs:
		FloatingText.spawn(scene_root_bs, global_position + Vector2(0, -18), "+4 Bullet Shield", Color(0.4, 0.7, 1.0))
	# Visual: looping 2-frame Oryx bubble (bullet_Shield ↔ bullet_Shield_2)
	# parented to the player so it follows movement. Watchdog in _process frees
	# the sprite the moment charges hit zero or the 12s timer expires.
	if is_instance_valid(_bullet_shield_sprite):
		_bullet_shield_sprite.queue_free()
		_bullet_shield_sprite = null
	var shield_frame_1 := FXAtlasLookup.get_texture("bullet_Shield")
	var shield_frame_2 := FXAtlasLookup.get_texture("bullet_Shield_2")
	if shield_frame_1 and shield_frame_2:
		var s := Sprite2D.new()
		s.texture = shield_frame_1
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Render behind the wizard sprite so the bubble looks like it's
		# wrapped around the player rather than plastered on top.
		# show_behind_parent forces this CanvasItem to draw BEFORE the
		# player's own children, which puts it under the body sprite.
		s.show_behind_parent = true
		s.z_index = -1
		# Semi-transparent ghost — keeps the wizard sprite readable through
		# the bubble and softens the visual weight of the FX.
		s.modulate = Color(1.0, 1.0, 1.0, 0.55)
		var native: float = float(shield_frame_1.region.size.x)
		var in_ow_bs := get_tree().current_scene and get_tree().current_scene.name == "Overworld"
		var ow_scale: float = 4.0 if in_ow_bs else 1.0
		var target_px: float = 14.0 * ow_scale
		if native > 0.0:
			s.scale = Vector2.ONE * (target_px / native)
		add_child(s)
		_bullet_shield_sprite = s
		var flicker := s.create_tween()
		flicker.set_loops()
		flicker.tween_callback(func(): if is_instance_valid(s): s.texture = shield_frame_1)
		flicker.tween_interval(0.15)
		flicker.tween_callback(func(): if is_instance_valid(s): s.texture = shield_frame_2)
		flicker.tween_interval(0.15)

func _ability_greater_heal() -> void:
	# Restore 600 + level*36 HP. Phase 1 ×12 from 50 + lvl*3.
	var amount = 600 + level_system.level * 36
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
	# Large slow projectile, explodes on impact for AoE + BURNING.
	# EMPOWERED: ~80% larger AoE and longer burn (5s vs 3s).
	var empowered = _consume_empowered()
	var aim_dir = _get_shoot_direction()
	var base_dmg = equipment_manager.get_damage()
	var dmg = int(base_dmg * (2.6 if empowered else 2.0) + level_system.level)
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
	fireball.set_meta("fireball_aoe_radius", (36.0 if empowered else 20.0) * scale_mult)
	fireball.set_meta("fireball_aoe_dmg_pct", 0.8 if empowered else 0.6)
	fireball.set_meta("apply_burning", 5.0 if empowered else 3.0)
	# Tell bullet.gd which Oryx tile to overlay during travel and which to drop
	# on impact. Bullet reads these in its _ready / _fireball_explode paths.
	fireball.set_meta("fx_overlay", "firebolt")
	# 2-frame impact: fire_impact bright flash → fire_explosion bloom.
	fireball.set_meta("fx_impact", ["fire_impact", "fire_explosion"])
	var bullets_container = get_tree().get_first_node_in_group("bullets")
	if bullets_container:
		bullets_container.add_child(fireball)
	else:
		get_tree().current_scene.add_child(fireball)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("sorcery", -2.0)

func _ability_chain_lightning() -> void:
	# Instant hit on nearest enemy, chains to 2 more.
	# EMPOWERED: chains to 5 more (6 hits total), each jump applies 0.4s STUNNED.
	var empowered = _consume_empowered()
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var scale_mult = 4.0 if in_ow else 1.0
	var max_range = 40.0 * scale_mult
	var chain_range = 30.0 * scale_mult
	var base_dmg = equipment_manager.get_damage()
	var dmg = int(base_dmg * 1.5 + level_system.level * 0.8)
	var luck = equipment_manager.get_luck()
	if luck > 0 and randf() * 100.0 < luck:
		dmg = int(dmg * equipment_manager.get_crit_damage())
	var jumps = 5 if empowered else 2
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
	# Chain to N more (empowered = 5 extra jumps for 6 total, plus per-jump stun)
	var current = nearest
	var chain_dmg = dmg
	for _i in range(jumps):
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
		if empowered and next_target.has_method("apply_status"):
			next_target.apply_status("STUNNED", 0.4)
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
	_invincible_until = Time.get_ticks_msec() / 1000.0 + 0.3
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
	tween.tween_callback(func():
		invincible = false
		_invincible_until = 0.0
	)
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
	status_effects.apply_buff("fire_rate", 8.0, -0.15)  # negative = faster
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
				var pull_dir: Vector2 = (well_pos - e.global_position).normalized()
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
			# Whip-Spin extra bullets at 0.5x base (was 1.5x). With base damage
			# at the Phase 1 floor, the spin is a costly burst window — +50 DPS
			# during 25 stamina/s drain — rather than free permanent +15 DPS.
			bullet.damage = int(equipment_manager.get_damage() * 0.5)
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

	var dir = _get_free_aim_direction()
	var in_ow = get_tree().current_scene and get_tree().current_scene.name == "Overworld"
	var blink_dist = 60.0 * (4.0 if in_ow else _get_scene_motion_scale())
	var target = global_position + dir * blink_dist
	invincible = true
	sprite.modulate.a = 0.3
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.dash_afterimage(sprite, global_position, null, z_index - 1)
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
		# Pitched down + much quieter — was -6 dB every 0.5 s, which read as
		# constant "dun dun dun" while walking with a hammer.
		sfx_eq.play("area_effect_a", -16.0, 0.15, 0.75)

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
		var pull_dir: Vector2 = (global_position - nearest.global_position).normalized()
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
