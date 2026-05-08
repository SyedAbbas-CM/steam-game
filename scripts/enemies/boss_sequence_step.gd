class_name BossSequenceStep
extends Resource

enum AttackMode {
	NONE,
	ATTACK_TYPE,
	GENERIC_SHOT
}

@export_group("Identity")
@export var step_id: String = "step"
@export var display_name: String = ""

@export_group("Timing")
@export var duration: float = 2.0

@export_group("Movement")
@export var movement_pattern: MovementPattern

@export_group("Attack")
@export var attack_mode: AttackMode = AttackMode.NONE
@export var attack_type: int = 2
@export var shot_pattern: BossShotPattern
@export var attack_interval: float = 0.5
@export var require_line_of_sight: bool = true
@export var min_attack_distance: float = 0.0
@export var max_attack_distance: float = 0.0
