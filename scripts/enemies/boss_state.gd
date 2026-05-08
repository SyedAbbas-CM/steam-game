class_name BossState
extends Resource

enum AttackMode {
	NONE,
	ATTACK_TYPE,
	GENERIC_SHOT
}

enum TransitionMode {
	TIME,
	HP_BELOW,
	EXTERNAL_TRIGGER,
	TIME_OR_HP,
	TIME_OR_EXTERNAL
}

@export_group("Identity")
@export var state_id: String = "state"
@export var display_name: String = ""

@export_group("Movement")
@export var movement_pattern: MovementPattern

@export_group("Attack")
@export var attack_mode: AttackMode = AttackMode.NONE
@export var attack_type: int = 2  # EnemyDefinition.AttackType.RANGED
@export var shot_pattern: BossShotPattern
@export var attack_interval: float = 0.5
@export var require_line_of_sight: bool = true
@export var min_attack_distance: float = 0.0
@export var max_attack_distance: float = 0.0
@export var sequence_steps: Array[Resource] = []  # BossSequenceStep resources for timed sub-patterns inside this HP phase
@export var loop_sequence: bool = true

@export_group("Transition")
@export var duration: float = 1.0
@export var transition_mode: TransitionMode = TransitionMode.TIME
@export var hp_threshold: float = 0.5
@export var external_trigger: String = ""
@export var next_state_id: String = ""
