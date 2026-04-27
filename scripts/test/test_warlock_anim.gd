extends Node2D

# Warlock sprite: 192x8, 24 frames of 8x8
# Layout: walk_right(0-3), walk_down(4-7), walk_up(8-11),
#          attack_up(12-15), attack_down(16-19), attack_right(20-23)

@onready var sprite: Sprite2D = $Sprite

var _anim_timer: float = 0.0
var _frame_duration: float = 0.15  # seconds per frame
var _current_anim: String = "walk_right"
var _anim_index: int = 0

# Animation definitions: name -> [start_frame, frame_count]
var ANIMS = {
	"walk_right": [0, 4],
	"walk_down":  [4, 4],
	"walk_up":    [8, 4],
	"attack_up":  [12, 4],
	"attack_down":[16, 4],
	"attack_right":[20, 4],
}

var _anim_order = ["walk_right", "walk_down", "walk_up", "attack_up", "attack_down", "attack_right"]
var _current_anim_idx: int = 0
var _cycle_timer: float = 0.0
var _cycle_duration: float = 1.5  # show each animation for 1.5s

var _label: Label

func _ready() -> void:
	# Label showing current animation name
	_label = Label.new()
	_label.position = Vector2(-40, 10)
	_label.add_theme_font_size_override("font_size", 4)
	_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_label)
	_set_anim(_anim_order[0])

func _process(delta: float) -> void:
	# Cycle through animations
	_cycle_timer += delta
	if _cycle_timer >= _cycle_duration:
		_cycle_timer = 0.0
		_current_anim_idx = (_current_anim_idx + 1) % _anim_order.size()
		_set_anim(_anim_order[_current_anim_idx])

	# Animate frames
	_anim_timer += delta
	if _anim_timer >= _frame_duration:
		_anim_timer -= _frame_duration
		_anim_index = (_anim_index + 1) % ANIMS[_current_anim][1]
		sprite.frame = ANIMS[_current_anim][0] + _anim_index

func _set_anim(anim_name: String) -> void:
	_current_anim = anim_name
	_anim_index = 0
	_anim_timer = 0.0
	sprite.frame = ANIMS[_current_anim][0]
	_label.text = anim_name
