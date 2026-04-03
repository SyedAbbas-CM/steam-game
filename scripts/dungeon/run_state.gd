class_name RunState
extends Resource

var run_id: String = ""
var start_time: int = 0
var end_time: int = 0

# Progress
var current_floor: int = 1
var current_room_index: int = 0
var rooms_on_floor: Array[RoomData] = []  # legacy, kept for compatibility
var floor_map: Dictionary = {}  # Vector2i -> RoomData
var current_grid_pos: Vector2i = Vector2i.ZERO
var stairs_pos: Vector2i = Vector2i.ZERO
var floors_cleared: int = 0
var rooms_cleared: int = 0

# Economy
var run_gold: int = 0
var run_relics: int = 0
var run_troop_tokens: int = 0

# Combat stats
var enemies_killed: int = 0
var damage_dealt: int = 0
var damage_taken: int = 0

# Build tracking
var mutations_acquired: Array[String] = []
var weapon_id: String = ""
var companions_used: Array[String] = []

# Events
var blessing_used: bool = false

func get_duration_seconds() -> float:
	if end_time > 0:
		return (end_time - start_time) / 1000.0
	return (Time.get_ticks_msec() - start_time) / 1000.0
