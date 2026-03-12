class_name SpriteAnimator
extends Node

## Lightweight sprite animation for actors.
## Supports frame-based cycling (lofi sprites) and visual effects (LoY atlas sprites).

enum Mode { FRAME_BASED, LOY_ATLAS }
enum State { IDLE, WALK, ATTACK }

var mode: Mode = Mode.LOY_ATLAS
var state: State = State.IDLE

## Frame-based settings (for lofi_char.png sprites with hframes/vframes)
var idle_frames: Array[int] = [1]
var walk_frames: Array[int] = [0, 1]
var attack_frames: Array[int] = [2, 3]
var fps: float = 6.0

## Internal state
var _sprite: Sprite2D
var _timer: float = 0.0
var _frame_index: int = 0
var _base_scale: Vector2 = Vector2.ONE
var _base_offset_y: float = 0.0
var _bob_time: float = 0.0
var _attack_tween: Tween

func setup(sprite: Sprite2D, anim_mode: Mode = Mode.LOY_ATLAS) -> void:
	_sprite = sprite
	mode = anim_mode
	_base_scale = sprite.scale
	_base_offset_y = sprite.offset.y

func set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	_frame_index = 0
	_timer = 0.0

	if mode == Mode.LOY_ATLAS and new_state == State.ATTACK:
		_play_attack_effect()

func _process(delta: float) -> void:
	if not _sprite or not is_instance_valid(_sprite):
		return

	match mode:
		Mode.FRAME_BASED:
			_process_frame_based(delta)
		Mode.LOY_ATLAS:
			_process_loy_atlas(delta)

func _process_frame_based(delta: float) -> void:
	var frames: Array[int]
	match state:
		State.IDLE:
			frames = idle_frames
		State.WALK:
			frames = walk_frames
		State.ATTACK:
			frames = attack_frames if not attack_frames.is_empty() else walk_frames

	if frames.is_empty():
		return

	_timer += delta
	var frame_duration = 1.0 / fps
	if _timer >= frame_duration:
		_timer -= frame_duration
		_frame_index = (_frame_index + 1) % frames.size()
		_sprite.frame = frames[_frame_index]

func _process_loy_atlas(delta: float) -> void:
	_bob_time += delta
	match state:
		State.IDLE:
			# Subtle breathing: gentle Y bob
			var bob = sin(_bob_time * 2.0) * 0.5
			_sprite.offset.y = _base_offset_y + bob
		State.WALK:
			# Faster bob + slight horizontal squash
			var bob = sin(_bob_time * 8.0) * 1.5
			_sprite.offset.y = _base_offset_y + bob
			var squash = 1.0 + sin(_bob_time * 8.0) * 0.03
			_sprite.scale = Vector2(_base_scale.x * squash, _base_scale.y / squash)
		State.ATTACK:
			# Attack is handled by tween, just keep walking bob
			var bob = sin(_bob_time * 6.0) * 1.0
			_sprite.offset.y = _base_offset_y + bob

func _play_attack_effect() -> void:
	if not _sprite or not is_instance_valid(_sprite):
		return
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	_attack_tween = _sprite.create_tween()
	_attack_tween.tween_property(_sprite, "scale", _base_scale * 1.2, 0.08)
	_attack_tween.tween_property(_sprite, "scale", _base_scale, 0.12)

func reset() -> void:
	if _sprite and is_instance_valid(_sprite):
		_sprite.scale = _base_scale
		_sprite.offset.y = _base_offset_y
	state = State.IDLE
	_timer = 0.0
	_frame_index = 0
	_bob_time = 0.0
