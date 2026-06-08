extends Node2D

# Visual-only ghost representing a remote peer's player.
# Owned by no one; receives state updates from CoopRuntime via RPC.
# Not in the "player" group — Phase 1/2 keeps existing PlayerQuery consumers untouched.
# Phase 2.5: drives its own PlayerAnimator with received direction + anim state.

var peer_owner_id: int = 0
var player_slot_index: int = 0
var replicated_proxy: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

var _target_position: Vector2 = Vector2.ZERO
var _has_state: bool = false
var _anim: PlayerAnimator
const LERP_SPEED: float = 28.0  # snappy at 30 Hz updates — ~2 frames at 60fps

func configure(owner_peer_id: int, slot_index: int = 0) -> void:
	peer_owner_id = owner_peer_id
	player_slot_index = slot_index
	add_to_group("remote_player")
	if label:
		label.text = "P%d" % owner_peer_id
	_target_position = global_position
	# Animator drives the sprite from broadcast state. Row 1 = Warrior; class sync deferred.
	if sprite:
		_anim = PlayerAnimator.new()
		_anim.name = "PlayerAnimator"
		add_child(_anim)
		_anim.setup(sprite, 1)

func apply_remote_state(state: Dictionary) -> void:
	if state.has("pos"):
		_target_position = state["pos"]
		_has_state = true
	if _anim:
		if state.has("dir"):
			# Translate Dir enum back into a movement vector so the animator picks the right facing.
			var dir_int: int = int(state.get("dir", 0))
			var dir_vec := _dir_to_vector(dir_int)
			if dir_vec != Vector2.ZERO:
				_anim.set_direction(dir_vec)
		if state.has("anim"):
			_anim.set_state(int(state["anim"]))

func _dir_to_vector(d: int) -> Vector2:
	match d:
		0: return Vector2.RIGHT  # PlayerAnimator.Dir.RIGHT
		1: return Vector2.DOWN
		2: return Vector2.UP
		3: return Vector2.LEFT
	return Vector2.ZERO

func _process(delta: float) -> void:
	if not _has_state:
		return
	global_position = global_position.lerp(_target_position, clampf(LERP_SPEED * delta, 0.0, 1.0))
