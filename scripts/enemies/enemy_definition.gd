class_name EnemyDefinition
extends Resource

enum AttackType {
	NONE, MELEE, RANGED, BURST, CHARGE, DASH,
	SUMMON, SLAM, TELEPORT, HEAL,
	SPLIT, STEALTH, SHIELD, BEAM, SPIRAL, POISON_SHOT,
	VOLLEY, CROSS_SHOT, WAVE_SHOT, GATLING, MORTAR, NOVA, ZIGZAG,
	SHOTGUN_BLAST, HELIX, METEOR_SHOWER, BOOMERANG_SHOT, STRAFE_RUN, MINEFIELD,
	RETURNING_VOLLEY, SEEKING_MINES, DETONATOR, SPLITTER, SINE_BARRAGE,
	HOMING_SALVO, TELEGRAPH_EXPLOSION, ORBIT_LAUNCH
}

enum SizeClass { NORMAL, LARGE, BOSS }

@export var enemy_name: String = "Enemy"
@export var description: String = ""
@export var max_hp: int = 3
@export var move_speed: float = 20.0
@export var contact_damage: int = 1
@export var level: int = 1

@export_group("Identity")
@export var kingdom: String = "unknown"  # undead, orc, crawler, animal, demon, human, magical, mecha
@export var size_class: SizeClass = SizeClass.NORMAL
@export var hostile: bool = true

@export_group("Attack")
@export var attack_type: AttackType = AttackType.RANGED
@export var attack_damage: int = 1
@export var attack_speed: float = 1.5
@export var bullet_speed: float = 80.0
@export var bullet_count: int = 1

@export_group("Behavior")
@export var preferred_distance: float = 0.0
@export var charge_speed: float = 80.0
@export var charge_duration: float = 0.3
@export var aggro_range: float = 80.0
@export var ignores_terrain: bool = false  # flying/ghost

@export_group("Special")
@export var summon_count: int = 2
@export var summon_definition: EnemyDefinition
@export var slam_radius: float = 24.0
@export var teleport_cooldown: float = 3.0
@export var heal_amount: int = 2
@export var heal_range: float = 48.0
@export var leaves_trail: bool = false
@export var trail_type: String = ""  # "fire", "web", "poison"
@export var explodes_on_death: bool = false
@export var explode_radius: float = 20.0
@export var drains_resource: bool = false
@export var poison_chance: float = 0.0  # 0-1
@export var split_count: int = 2  # for SPLIT attack type
@export var split_definition: EnemyDefinition  # smaller version to spawn on death
@export var stealth_duration: float = 2.0
@export var shield_hp: int = 0  # frontal shield that absorbs damage
@export var beam_duration: float = 1.0
@export var beam_sweep_speed: float = 1.5  # radians/sec

@export_group("Boss Phases")
@export var boss_phases: int = 1  # 1=no phases, 2=two phases, 3=three phases
@export var phase_2_attack: AttackType = AttackType.NONE  # attack at <66% HP
@export var phase_3_attack: AttackType = AttackType.NONE  # attack at <33% HP
@export var phase_2_bullet_count: int = 0  # 0 = use base bullet_count
@export var phase_3_bullet_count: int = 0
@export var summon_on_phase_change: bool = false
@export var summon_phase_count: int = 3  # minions spawned per phase change

@export_group("Visuals")
@export var sprite_frame: int = 48
@export var sprite_color: Color = Color.WHITE
@export var use_loy_sprite: bool = false  # true = use LoY char sprite sheet
@export var loy_tile_index: int = -1  # LoY tile index for chars.png/chars2.png

@export_group("Rewards")
@export var drop_table: DropTable
@export var xp_value: int = 1
@export var score_value: int = 10
