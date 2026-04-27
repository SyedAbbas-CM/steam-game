class_name MovementPattern
extends Resource

## Movement type — fundamentally different movement behaviors.
## WEIGHTED uses the old blend system. All others override it entirely.
enum MoveType {
	WEIGHTED,        ## 0 — legacy weight-based blending
	ORBIT_PLAYER,    ## 1 — circles the player at orbit_radius
	ORBIT_POINT,     ## 2 — circles own spawn position
	ORBIT_ALLY,      ## 3 — circles nearest ally enemy
	PATROL_H,        ## 4 — paces left/right from spawn
	PATROL_V,        ## 5 — paces up/down from spawn
	FLEE,            ## 6 — always runs away, fires backward
	ZIGZAG,          ## 7 — zigzags while approaching
	WALL_BOUNCE,     ## 8 — bounces off walls like a billiard ball
	DASH_IN_OUT,     ## 9 — dashes to player, attacks, dashes back
	KITE,            ## 10 — maintains exact distance, retreats if close, advances if far
	SWOOP,           ## 11 �� fast arc past the player, loops back for another pass
	TELEPORT,        ## 12 — blinks to random position in room when hit
	MIRROR,          ## 13 — copies player movement, pulls player toward self
	INTERCEPT,       ## 14 — predicts player position, commits to intercept point
	ELASTIC,         ## 15 — spring-tethered to spawn, stretches then whips back
	EDGE_SKATER,     ## 16 — rides along walls/room perimeter
	BAIT_PUNISH,     ## 17 — retreats to bait chase, flips to aggressive punish
	AMBUSH,          ## 18 — hides invisible in corner, attacks when player is occupied
}

@export var move_type: MoveType = MoveType.WEIGHTED

@export_group("Orbit / Patrol")
@export var orbit_radius: float = 40.0       ## radius for ORBIT_* types
@export var orbit_speed: float = 2.0         ## radians/sec for orbit, or cycles/sec for patrol
@export var patrol_length: float = 50.0      ## pixels for PATROL_H / PATROL_V half-width

@export_group("Dash In/Out")
@export var dash_in_speed: float = 150.0
@export var dash_pause: float = 0.5          ## seconds to pause at player before retreating
@export var dash_cooldown: float = 3.0

@export_group("Kite")
@export var kite_distance: float = 60.0      ## ideal distance to maintain from player

@export_group("Swoop")
@export var swoop_speed: float = 200.0       ## speed during the swooping arc
@export var swoop_arc_size: float = 80.0     ## how wide the arc loops

@export_group("Teleport")
@export var teleport_interval: float = 2.0   ## seconds between blinks
@export var teleport_range: float = 60.0     ## max distance to blink

@export_group("Mirror")
@export var mirror_offset: float = 60.0      ## distance offset from player's mirrored position
@export var mirror_pull_strength: float = 80.0  ## pull force applied to player

@export_group("Intercept")
@export var intercept_commit_time: float = 0.8  ## how long to commit to intercept point
@export var intercept_predict_time: float = 0.5 ## how far ahead to predict player position

@export_group("Elastic")
@export var elastic_max_stretch: float = 90.0   ## max distance from anchor before whipping back
@export var elastic_whip_speed: float = 300.0   ## speed of the recoil snap

@export_group("Edge Skater")
@export var edge_skate_speed: float = 2.0       ## speed multiplier along walls

@export_group("Bait & Punish")
@export var bait_flee_time: float = 1.5         ## how long to flee before checking
@export var punish_speed: float = 250.0         ## speed of the punish charge

@export_group("Movement Weights")
@export_range(0.0, 1.0) var approach_weight: float = 1.0
@export_range(0.0, 1.0) var retreat_weight: float = 0.0
@export_range(0.0, 1.0) var strafe_weight: float = 0.0
@export_range(0.0, 1.0) var hold_weight: float = 0.0

@export_group("Speed")
@export var speed_mult: float = 1.0

@export_group("Distance")
@export var preferred_distance: float = 0.0
@export var close_threshold: float = 20.0

@export_group("Close Behavior")
@export var close_approach: float = -1.0
@export var close_retreat: float = -1.0
@export var close_strafe: float = -1.0
@export var close_speed_mult: float = 1.0

@export_group("Far Behavior")
@export var far_approach: float = -1.0
@export var far_retreat: float = -1.0
@export var far_strafe: float = -1.0
@export var far_speed_mult: float = 1.0
@export var far_threshold_mult: float = 1.5

@export_group("Charge")
@export var can_charge: bool = false
@export var charge_speed_mult: float = 3.0
@export var charge_duration: float = 0.3
@export var charge_cooldown: float = 3.0
@export var charge_min_dist: float = 20.0
@export var charge_max_dist: float = 80.0

@export_group("Dodge")
@export var dodge_enabled: bool = true
@export var dodge_interval_min: float = 0.5
@export var dodge_interval_max: float = 1.5
@export var weave_amplitude: float = 0.0

@export_group("Enrage")
@export var enrage_speed_bonus: float = 0.5
@export var enrage_approach_boost: float = 0.3
