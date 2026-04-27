class_name EnemyAnimData
extends Resource

## Defines the animation frame layout for an animated enemy.
## Each enemy spritesheet has rows of 8x8 (or custom size) frames.
## Frame indices are column offsets within the row.
##
## Example: a simple enemy with 2 idle, 3 walk, 2 attack frames (all right-facing):
##   idle_start=0, walk_start=2, walk_count=3, attack_start=5, attack_count=2
##
## For directional enemies, dir_offset_down/up shift the base column.
## Left = flip_h of right frames (automatic).

@export var spritesheet_path: String = ""
@export var row: int = 0  # which row in the spritesheet
@export var frame_size: int = 8  # pixels per frame (usually 8)

@export_group("Idle")
@export var idle_start: int = 0  # column index of idle frame (right/default)

@export_group("Walk")
@export var walk_start: int = 1  # column index of first walk frame
@export var walk_count: int = 3  # number of walk frames
@export var walk_fps: float = 6.0

@export_group("Attack")
@export var attack_start: int = -1  # -1 = no attack animation
@export var attack_count: int = 2
@export var attack_fps: float = 8.0

@export_group("Directions")
@export var directional: bool = false  # true = has separate frames for down/up
@export var dir_offset_down: int = 4  # column offset from right to down frames
@export var dir_offset_up: int = 8  # column offset from right to up frames

func total_frames() -> int:
	var max_col = idle_start + 1
	if walk_count > 0:
		max_col = maxi(max_col, walk_start + walk_count)
	if attack_start >= 0 and attack_count > 0:
		max_col = maxi(max_col, attack_start + attack_count)
	if directional:
		max_col = maxi(max_col, max_col + dir_offset_up)
	return max_col
