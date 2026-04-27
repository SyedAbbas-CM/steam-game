class_name PlayerAnimator
extends Node

## Directional sprite animation for player characters.
## Uses lofi_char_animated_main.png with mixed-width frames per row.
##
## Frame layout (pixel X offsets):
##   x=0:   stand_right (8x8)
##   x=8:   move_right_1 (8x8)
##   x=16:  move_right_2 (8x8)
##   x=24:  move_right_3 (8x8)
##   x=32:  stand_down (8x8)
##   x=40:  move_down_1 (8x8)
##   x=48:  move_down_2 (8x8)
##   x=56:  move_down_3 (8x8)
##   x=64:  stand_up (8x8)
##   x=72:  move_up_1 (8x8)
##   x=80:  move_up_2 (8x8)
##   x=88:  move_up_3 (8x8)
##   x=96:  attack_down_1 (8x8)
##   x=104: attack_down_2 (8x8)
##   x=112: attack_up_1 (8x8)
##   x=120: attack_up_2 (8x8)
##   x=128: attack_right_1 (8x8)
##   x=136: attack_right_2 (12x8)
##   x=148: dash_1 (8x8)
##   x=156: dash_2 (8x8)
##   x=164: special_attack_1 (8x8)
##   x=172: special_attack_2 (12x8)
##
## Left = flip_h of right frames.
## Row mapping: 0=Ranger, 1=Warrior, 2=Wizard, 3=Mercenary

enum Dir { RIGHT, DOWN, UP, LEFT }
enum AnimState { IDLE, WALK, ATTACK, DASH, SPECIAL_ATTACK, CHARGE }

const ROW_HEIGHT := 8
const WALK_FPS := 8.0
const ATTACK_FPS := 10.0
const DASH_FPS := 10.0
const SPECIAL_FPS := 10.0
const TEXTURE_PATH := "res://assets/sprites/lofi_char_animated_main.png"

# Frame definitions: [x_offset, width]
# Indices used as keys in _frame_cache
const F_STAND_RIGHT := 0
const F_WALK_RIGHT_1 := 1
const F_WALK_RIGHT_2 := 2
const F_WALK_RIGHT_3 := 3
const F_STAND_DOWN := 4
const F_WALK_DOWN_1 := 5
const F_WALK_DOWN_2 := 6
const F_WALK_DOWN_3 := 7
const F_STAND_UP := 8
const F_WALK_UP_1 := 9
const F_WALK_UP_2 := 10
const F_WALK_UP_3 := 11
const F_ATK_DOWN_1 := 12
const F_ATK_DOWN_2 := 13
const F_ATK_UP_1 := 14
const F_ATK_UP_2 := 15
const F_ATK_RIGHT_1 := 16
const F_ATK_RIGHT_2 := 17
const F_DASH_1 := 18
const F_DASH_2 := 19
const F_SPECIAL_1 := 20
const F_SPECIAL_2 := 21
const FRAME_COUNT := 22

# [x_offset, width] for each frame index
# All frames are 8x8 EXCEPT attack_right_2 and special_2 which are 12x8
const FRAME_DEFS: Array = [
	[0, 8], [8, 8], [16, 8], [24, 8],       # stand/walk right
	[32, 8], [40, 8], [48, 8], [56, 8],      # stand/walk down
	[64, 8], [72, 8], [80, 8], [88, 8],      # stand/walk up
	[96, 8], [104, 8],                         # attack down 1-2
	[112, 8], [120, 8],                        # attack up 1-2
	[128, 8], [136, 12],                       # attack right 1 (8px), attack right 2 (12px)
	[148, 8], [156, 8],                        # dash 1-2
	[164, 8], [172, 12],                       # special 1 (8px), special 2 (12px)
]

var _sprite: Sprite2D
var _base_texture: Texture2D
var _row: int = 0
var _dir: Dir = Dir.DOWN
var _state: AnimState = AnimState.IDLE
var _timer: float = 0.0
var _frame_index: int = 0
var _current_frame_id: int = -1
var _current_flip: bool = false
var _frame_cache: Array[AtlasTexture] = []
var _looping: bool = false  # when true, SPECIAL_ATTACK loops instead of returning to IDLE

func setup(sprite: Sprite2D, row: int) -> void:
	_sprite = sprite
	_row = row
	_base_texture = load(TEXTURE_PATH) as Texture2D
	_sprite.hframes = 1
	_sprite.vframes = 1
	_sprite.frame = 0
	# Pre-build atlas textures for all frames
	_frame_cache.resize(FRAME_COUNT)
	for i in range(FRAME_COUNT):
		var def = FRAME_DEFS[i]
		var atlas = AtlasTexture.new()
		atlas.atlas = _base_texture
		atlas.region = Rect2(def[0], _row * ROW_HEIGHT, def[1], ROW_HEIGHT)
		_frame_cache[i] = atlas
	_apply_frame(_get_idle_frame())

func set_direction(move_dir: Vector2) -> void:
	if move_dir.length_squared() < 0.01:
		return
	if absf(move_dir.x) >= absf(move_dir.y):
		_dir = Dir.LEFT if move_dir.x < 0 else Dir.RIGHT
	else:
		_dir = Dir.UP if move_dir.y < 0 else Dir.DOWN

func set_aim_direction(aim_dir: Vector2) -> void:
	if aim_dir.length_squared() < 0.01:
		return
	if absf(aim_dir.x) >= absf(aim_dir.y):
		_dir = Dir.LEFT if aim_dir.x < 0 else Dir.RIGHT
	else:
		_dir = Dir.UP if aim_dir.y < 0 else Dir.DOWN

func set_state(new_state: AnimState, start_frame: int = 0, looping: bool = false) -> void:
	if _state == new_state and start_frame == 0 and _looping == looping:
		return
	_state = new_state
	_frame_index = start_frame
	_timer = 0.0
	_looping = looping

func is_locked() -> bool:
	## Returns true if current state should NOT be overridden by walk/idle/attack.
	## Looping special attacks CAN be overridden (they stop when ability ends).
	match _state:
		AnimState.DASH, AnimState.CHARGE:
			return true
		AnimState.SPECIAL_ATTACK:
			return not _looping  # one-shot specials are locked; looping ones are not
	return false

func _physics_process(delta: float) -> void:
	if not _sprite or not is_instance_valid(_sprite):
		return

	match _state:
		AnimState.IDLE:
			_apply_frame(_get_idle_frame())
		AnimState.WALK:
			_timer += delta
			if _timer >= 1.0 / WALK_FPS:
				_timer -= 1.0 / WALK_FPS
				_frame_index = (_frame_index + 1) % 4
			# Cycle: idle(0) → walk1(1) → walk2(2) → walk3(3)
			if _frame_index == 0:
				_apply_frame(_get_idle_frame())
			else:
				_apply_frame(_get_walk_frame(_frame_index - 1))
		AnimState.ATTACK:
			_timer += delta
			if _timer >= 1.0 / ATTACK_FPS:
				_timer -= 1.0 / ATTACK_FPS
				_frame_index += 1
				if _frame_index >= 2:
					_frame_index = 0
					_state = AnimState.IDLE
					_apply_frame(_get_idle_frame())
					return
			_apply_frame(_get_attack_frame(_frame_index))
		AnimState.DASH:
			_timer += delta
			if _timer >= 1.0 / DASH_FPS:
				_timer -= 1.0 / DASH_FPS
				_frame_index = (_frame_index + 1) % 2
			# Dash frames are right-facing only; up/down use walk frames instead
			if _dir in [Dir.RIGHT, Dir.LEFT]:
				_apply_frame(F_DASH_1 + _frame_index)
			else:
				_apply_frame(_get_walk_frame(_frame_index))
		AnimState.SPECIAL_ATTACK:
			_timer += delta
			if _timer >= 1.0 / SPECIAL_FPS:
				_timer -= 1.0 / SPECIAL_FPS
				_frame_index += 1
				if _frame_index >= 2:
					if _looping:
						_frame_index = 0  # loop back
					else:
						_frame_index = 0
						_state = AnimState.IDLE
						_apply_frame(_get_idle_frame())
						return
			_apply_frame(_get_special_frame(_frame_index))
		AnimState.CHARGE:
			# Hold special frame 0 statically (staff channeling)
			_apply_frame(_get_special_frame(0))

func _get_idle_frame() -> int:
	match _dir:
		Dir.RIGHT, Dir.LEFT: return F_STAND_RIGHT
		Dir.DOWN: return F_STAND_DOWN
		Dir.UP: return F_STAND_UP
	return F_STAND_RIGHT

func _get_walk_frame(idx: int) -> int:
	match _dir:
		Dir.RIGHT, Dir.LEFT: return F_WALK_RIGHT_1 + idx
		Dir.DOWN: return F_WALK_DOWN_1 + idx
		Dir.UP: return F_WALK_UP_1 + idx
	return F_WALK_RIGHT_1 + idx

func _get_attack_frame(idx: int) -> int:
	match _dir:
		Dir.DOWN: return F_ATK_DOWN_1 + idx
		Dir.UP: return F_ATK_UP_1 + idx
		Dir.RIGHT, Dir.LEFT: return F_ATK_RIGHT_1 + idx
	return F_ATK_DOWN_1 + idx

func _get_special_frame(idx: int) -> int:
	# Special attacks use special frames for left/right,
	# normal attack frames for up/down
	match _dir:
		Dir.RIGHT, Dir.LEFT: return F_SPECIAL_1 + idx
		Dir.DOWN: return F_ATK_DOWN_1 + idx
		Dir.UP: return F_ATK_UP_1 + idx
	return F_SPECIAL_1 + idx

func _apply_frame(frame_id: int) -> void:
	if frame_id < 0 or frame_id >= FRAME_COUNT:
		return
	var flip = (_dir == Dir.LEFT)
	if frame_id == _current_frame_id and flip == _current_flip:
		return
	_current_frame_id = frame_id
	_current_flip = flip
	_sprite.texture = _frame_cache[frame_id]
	_sprite.flip_h = flip
	# Compensate for wider frames (12px) — extra 4px extends outward, not shifting center
	var w = FRAME_DEFS[frame_id][1]
	if w > ROW_HEIGHT:
		var extra = (w - ROW_HEIGHT) * 0.5  # 2px for 12px frames
		_sprite.offset.x = extra if not flip else -extra
	else:
		_sprite.offset.x = 0.0
