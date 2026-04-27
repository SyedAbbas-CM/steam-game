class_name EnemyAnimator
extends Node

## Flexible sprite animation for enemies.
## Each enemy can define its own frame layout via EnemyAnimData resource.
## Supports idle, walk, and attack states with directional facing.
## Enemies without anim_data use the existing static sprite system.

enum Dir { RIGHT, DOWN, UP, LEFT }
enum AnimState { IDLE, WALK, ATTACK }

var _sprite: Sprite2D
var _data: EnemyAnimData
var _frame_cache: Array[AtlasTexture] = []
var _dir: Dir = Dir.DOWN
var _state: AnimState = AnimState.IDLE
var _timer: float = 0.0
var _frame_index: int = 0
var _current_col: int = -1
var _current_flip: bool = false

func setup(spr: Sprite2D, data: EnemyAnimData) -> void:
	_sprite = spr
	_data = data
	var tex = load(data.spritesheet_path) as Texture2D
	if not tex:
		return
	_sprite.hframes = 1
	_sprite.vframes = 1
	_sprite.frame = 0
	# Pre-build atlas textures for every frame in this row
	var total_cols = data.total_frames()
	_frame_cache.resize(total_cols)
	var fs = data.frame_size
	for col in range(total_cols):
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(col * fs, data.row * fs, fs, fs)
		_frame_cache[col] = atlas
	_apply_frame(_get_idle_col())

func set_direction(move_dir: Vector2) -> void:
	if move_dir.length_squared() < 0.01:
		return
	if absf(move_dir.x) >= absf(move_dir.y):
		_dir = Dir.LEFT if move_dir.x < 0 else Dir.RIGHT
	else:
		_dir = Dir.UP if move_dir.y < 0 else Dir.DOWN

func set_state(new_state: AnimState) -> void:
	if _state == new_state:
		return
	# If no attack frames defined, treat ATTACK as WALK
	if new_state == AnimState.ATTACK and _data.attack_start < 0:
		new_state = AnimState.WALK
	if _state == new_state:
		return
	_state = new_state
	_frame_index = 0
	_timer = 0.0

func _physics_process(delta: float) -> void:
	if not _sprite or not is_instance_valid(_sprite) or not _data:
		return

	match _state:
		AnimState.IDLE:
			_apply_frame(_get_idle_col())
		AnimState.WALK:
			var frames = _get_walk_frames()
			if frames.is_empty():
				_apply_frame(_get_idle_col())
				return
			_timer += delta
			var spf = 1.0 / _data.walk_fps
			if _timer >= spf:
				_timer -= spf
				_frame_index = (_frame_index + 1) % frames.size()
			_apply_frame(frames[_frame_index])
		AnimState.ATTACK:
			var frames = _get_attack_frames()
			if frames.is_empty():
				_state = AnimState.IDLE
				return
			_timer += delta
			var spf = 1.0 / _data.attack_fps
			if _timer >= spf:
				_timer -= spf
				_frame_index += 1
				if _frame_index >= frames.size():
					_frame_index = 0
					_state = AnimState.IDLE
					_apply_frame(_get_idle_col())
					return
			_apply_frame(frames[_frame_index])

func _get_idle_col() -> int:
	if not _data.directional:
		return _data.idle_start
	match _dir:
		Dir.RIGHT, Dir.LEFT: return _data.idle_start
		Dir.DOWN: return _data.idle_start + _data.dir_offset_down
		Dir.UP: return _data.idle_start + _data.dir_offset_up
	return _data.idle_start

func _get_walk_frames() -> Array[int]:
	var result: Array[int] = []
	if _data.walk_count <= 0:
		return result
	var base = _data.walk_start
	if _data.directional:
		match _dir:
			Dir.DOWN: base = _data.walk_start + _data.dir_offset_down
			Dir.UP: base = _data.walk_start + _data.dir_offset_up
	for i in range(_data.walk_count):
		result.append(base + i)
	return result

func _get_attack_frames() -> Array[int]:
	var result: Array[int] = []
	if _data.attack_start < 0 or _data.attack_count <= 0:
		return result
	var base = _data.attack_start
	if _data.directional:
		match _dir:
			Dir.DOWN: base = _data.attack_start + _data.dir_offset_down
			Dir.UP: base = _data.attack_start + _data.dir_offset_up
	for i in range(_data.attack_count):
		result.append(base + i)
	return result

func _apply_frame(frame_col: int) -> void:
	if frame_col < 0 or frame_col >= _frame_cache.size():
		return
	var flip = (_dir == Dir.LEFT)
	if frame_col == _current_col and flip == _current_flip:
		return
	_current_col = frame_col
	_current_flip = flip
	_sprite.texture = _frame_cache[frame_col]
	_sprite.flip_h = flip
