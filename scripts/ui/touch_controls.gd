class_name TouchControls
extends CanvasLayer

var left_stick: VirtualJoystick
var right_stick: VirtualJoystick
var _interact_btn: Control
var _sprint_btn: Control  # Shift key — sprint / alt-fire
var _shield_btn: Control  # R key — warrior shield
var _power_btn: Control   # Space key — class powers (charge, paralysis, dash)
var _interact_visible: bool = false
var _sprint_held: bool = false

# Touch tracking per button: action_name -> touch_index
var _btn_touch_map: Dictionary = {}

static func is_mobile() -> bool:
	return OS.get_name() == "Android" or OS.get_name() == "iOS"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("touch_controls")

	if not TouchControls.is_mobile():
		visible = false

	_build_ui()

func _build_ui() -> void:
	var container = Control.new()
	container.anchors_preset = Control.PRESET_FULL_RECT
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	var vp_size = get_viewport().get_visible_rect().size
	var margin = 30
	var stick_size = 250 # 120 radius * 2 + 10

	# Left joystick - bottom left
	left_stick = VirtualJoystick.new()
	left_stick.position = Vector2(margin, vp_size.y - margin - stick_size)
	container.add_child(left_stick)

	# Right joystick - bottom right
	right_stick = VirtualJoystick.new()
	right_stick.position = Vector2(vp_size.x - margin - stick_size, vp_size.y - margin - stick_size)
	container.add_child(right_stick)

	# --- Interact button (bottom center, hidden by default) ---
	_interact_btn = _make_touch_btn("interact", "Interact", Vector2(280, 100), 34,
		Color(0.1, 0.4, 0.15, 0.85), Color(0.3, 0.9, 0.4))
	_interact_btn.position = Vector2(vp_size.x / 2.0 - 140, vp_size.y - margin - 290)
	_interact_btn.visible = false
	container.add_child(_interact_btn)

	# All action buttons on RIGHT side
	var right_x = vp_size.x - margin - stick_size  # right joystick left edge

	# --- Sprint / Alt-Fire button — maps to Shift — right side, above-left of joystick ---
	_sprint_btn = _make_touch_btn("sprint", "Sprint", Vector2(220, 90), 32,
		Color(0.15, 0.25, 0.5, 0.85), Color(0.3, 0.5, 0.9))
	_sprint_btn.position = Vector2(right_x - 235, vp_size.y - margin - stick_size - 20)
	container.add_child(_sprint_btn)

	# --- Shield button — maps to R, warrior only — right side, above sprint ---
	_shield_btn = _make_touch_btn("shield_raise", "Shield", Vector2(220, 90), 32,
		Color(0.4, 0.2, 0.5, 0.85), Color(0.7, 0.4, 0.9))
	_shield_btn.position = Vector2(right_x - 235, vp_size.y - margin - stick_size - 130)
	_shield_btn.visible = false
	container.add_child(_shield_btn)

	# --- Power button — maps to Space ("dash" action) — right side, above joystick ---
	_power_btn = _make_touch_btn("dash", "Power", Vector2(220, 90), 32,
		Color(0.5, 0.3, 0.1, 0.85), Color(0.9, 0.6, 0.2))
	_power_btn.position = Vector2(right_x + 15, vp_size.y - margin - stick_size - 110)
	container.add_child(_power_btn)

func _make_touch_btn(action_name: String, text: String, min_size: Vector2, font_size: int,
		bg_color: Color, border_color: Color) -> Control:
	var panel = Control.new()
	panel.custom_minimum_size = min_size
	panel.size = min_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta("action", action_name)
	panel.set_meta("bg_color", bg_color)
	panel.set_meta("border_color", border_color)

	var bg = ColorRect.new()
	bg.size = min_size
	bg.color = bg_color
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg)
	panel.set_meta("bg_rect", bg)

	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = min_size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	panel.set_meta("label", label)

	return panel

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if left_stick and left_stick.owns_touch(event.index):
			return
		if right_stick and right_stick.owns_touch(event.index):
			return
		if event.pressed:
			if _check_btn_touch(event.position, event.index):
				return
			var vp_size = get_viewport().get_visible_rect().size
			if _interact_visible and event.position.y > 140.0 and event.position.y < vp_size.y - 300.0:
				_tap_action("interact")
				get_viewport().set_input_as_handled()
		else:
			_release_btn_touch(event.index)

func _check_btn_touch(pos: Vector2, index: int) -> bool:
	var buttons = [_sprint_btn, _interact_btn, _shield_btn, _power_btn]
	for btn in buttons:
		if btn == null or not btn.visible:
			continue
		if _is_in_btn(pos, btn):
			var action: String = btn.get_meta("action")
			_btn_touch_map[action] = index
			_on_btn_pressed(btn, action)
			get_viewport().set_input_as_handled()
			return true
	return false

func _release_btn_touch(index: int) -> void:
	for action in _btn_touch_map.keys():
		if _btn_touch_map[action] == index:
			_btn_touch_map.erase(action)
			_on_btn_released(action)
			var btn = _get_btn_for_action(action)
			if btn:
				var bg_rect: ColorRect = btn.get_meta("bg_rect")
				bg_rect.color = btn.get_meta("bg_color")
			get_viewport().set_input_as_handled()
			return

func _is_in_btn(pos: Vector2, btn: Control) -> bool:
	var gp = btn.global_position
	var sz = btn.size
	var pad = 20.0
	return pos.x >= gp.x - pad and pos.x <= gp.x + sz.x + pad \
		and pos.y >= gp.y - pad and pos.y <= gp.y + sz.y + pad

func _get_btn_for_action(action: String) -> Control:
	match action:
		"sprint": return _sprint_btn
		"interact": return _interact_btn
		"shield_raise": return _shield_btn
		"dash": return _power_btn
	return null

func _on_btn_pressed(btn: Control, action: String) -> void:
	var bg_rect: ColorRect = btn.get_meta("bg_rect")
	bg_rect.color = btn.get_meta("bg_color").lightened(0.3)
	if action == "interact":
		_tap_action(action)
		return
	Input.action_press(action)
	if action == "sprint":
		_sprint_held = true

func _on_btn_released(action: String) -> void:
	if action == "interact":
		return
	Input.action_release(action)
	if action == "sprint":
		_sprint_held = false

func _tap_action(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)

func show_interact_button(text: String = "Interact") -> void:
	if _interact_btn:
		var label: Label = _interact_btn.get_meta("label")
		label.text = text
		_interact_btn.visible = true
		_interact_visible = true

func hide_interact_button() -> void:
	if _interact_btn:
		_interact_btn.visible = false
		_interact_visible = false

func show_shield_button(show: bool) -> void:
	if _shield_btn:
		_shield_btn.visible = show

func set_power_label(text: String) -> void:
	if _power_btn:
		var label: Label = _power_btn.get_meta("label")
		label.text = text

func is_sprinting() -> bool:
	return _sprint_held

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
