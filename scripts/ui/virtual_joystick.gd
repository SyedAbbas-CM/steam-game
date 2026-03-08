class_name VirtualJoystick
extends Control

@export var stick_radius: float = 30.0
@export var dead_zone: float = 0.15

var _pressed: bool = false
var _touch_index: int = -1
var _output: Vector2 = Vector2.ZERO

var base_circle: ColorRect
var nub_circle: ColorRect

func get_output() -> Vector2:
	return _output

func is_active() -> bool:
	return _pressed

func _ready() -> void:
	custom_minimum_size = Vector2(stick_radius * 2 + 10, stick_radius * 2 + 10)
	size = custom_minimum_size

	# Base circle (outer ring)
	base_circle = ColorRect.new()
	base_circle.size = Vector2(stick_radius * 2, stick_radius * 2)
	base_circle.position = Vector2(5, 5)
	base_circle.color = Color(1, 1, 1, 0.15)
	add_child(base_circle)

	# Nub (inner circle)
	nub_circle = ColorRect.new()
	nub_circle.size = Vector2(16, 16)
	nub_circle.color = Color(1, 1, 1, 0.4)
	add_child(nub_circle)
	_center_nub()

func _center_nub() -> void:
	nub_circle.position = base_circle.position + Vector2(stick_radius, stick_radius) - nub_circle.size / 2.0

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _is_in_zone(event.position):
			_pressed = true
			_touch_index = event.index
			_update_nub(event.position)
		elif not event.pressed and event.index == _touch_index:
			_reset()
	elif event is InputEventScreenDrag:
		if event.index == _touch_index and _pressed:
			_update_nub(event.position)

func _is_in_zone(pos: Vector2) -> bool:
	var local = pos - global_position
	return local.x >= -20 and local.x <= size.x + 20 and local.y >= -20 and local.y <= size.y + 20

func _update_nub(screen_pos: Vector2) -> void:
	var center = global_position + base_circle.position + Vector2(stick_radius, stick_radius)
	var local = screen_pos - center
	var clamped = local
	if local.length() > stick_radius:
		clamped = local.normalized() * stick_radius
	nub_circle.position = base_circle.position + Vector2(stick_radius, stick_radius) + clamped - nub_circle.size / 2.0
	_output = clamped / stick_radius
	if _output.length() < dead_zone:
		_output = Vector2.ZERO

func _reset() -> void:
	_pressed = false
	_touch_index = -1
	_output = Vector2.ZERO
	_center_nub()
