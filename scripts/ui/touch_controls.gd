class_name TouchControls
extends CanvasLayer

var left_stick: VirtualJoystick
var right_stick: VirtualJoystick

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Only show on touch devices (or when emulating touch)
	if not DisplayServer.is_touchscreen_available():
		visible = false

	_build_ui()

func _build_ui() -> void:
	# Container for positioning
	var container = Control.new()
	container.anchors_preset = Control.PRESET_FULL_RECT
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	var vp_size = get_viewport().get_visible_rect().size
	var margin = 20
	var stick_size = 70  # approximate joystick visual radius

	# Left joystick - bottom left
	left_stick = VirtualJoystick.new()
	left_stick.position = Vector2(margin + stick_size, vp_size.y - margin - stick_size)
	container.add_child(left_stick)

	# Right joystick - bottom right
	right_stick = VirtualJoystick.new()
	right_stick.position = Vector2(vp_size.x - margin - stick_size, vp_size.y - margin - stick_size)
	container.add_child(right_stick)

func get_move_input() -> Vector2:
	if left_stick:
		return left_stick.get_output()
	return Vector2.ZERO

func get_aim_input() -> Vector2:
	if right_stick:
		return right_stick.get_output()
	return Vector2.ZERO

func is_shooting() -> bool:
	if right_stick:
		return right_stick.is_active() and right_stick.get_output().length() > 0.1
	return false
