class_name BattleHUD
extends CanvasLayer

signal retreat_pressed
signal speed_changed(multiplier: float)
signal return_pressed
signal command_mode_toggled(enabled: bool)
signal fog_toggled(enabled: bool)

var _player_count_label: Label
var _enemy_count_label: Label
var _timer_label: Label
var _speed_buttons: Array[Button] = []
var _retreat_button: Button
var _overlay: ColorRect
var _overlay_label: Label
var _return_button: Button
var _current_speed: float = 1.0
var _command_mode_label: Label
var _command_mode: bool = false
var _fog_button: Button
var _fog_enabled: bool = true

func _ready() -> void:
	layer = 10
	_build_ui()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	# Top row: army counts + timer + command mode indicator
	var top := HBoxContainer.new()
	vbox.add_child(top)

	_player_count_label = Label.new()
	_player_count_label.add_theme_font_size_override("font_size", 20)
	_player_count_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	top.add_child(_player_count_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", 20)
	_timer_label.add_theme_color_override("font_color", Color.WHITE)
	top.add_child(_timer_label)

	var spacer1b := Control.new()
	spacer1b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer1b)

	_command_mode_label = Label.new()
	_command_mode_label.text = "[Tab] Command"
	_command_mode_label.add_theme_font_size_override("font_size", 16)
	_command_mode_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	top.add_child(_command_mode_label)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer2)

	_enemy_count_label = Label.new()
	_enemy_count_label.add_theme_font_size_override("font_size", 20)
	_enemy_count_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	top.add_child(_enemy_count_label)

	# Bottom row: speed buttons + retreat
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(bottom_spacer)

	var bottom := HBoxContainer.new()
	vbox.add_child(bottom)

	for spd in [1.0, 2.0, 4.0]:
		var btn := Button.new()
		btn.text = "%dx" % int(spd)
		btn.pressed.connect(_on_speed_pressed.bind(spd))
		btn.add_theme_font_size_override("font_size", 16)
		bottom.add_child(btn)
		_speed_buttons.append(btn)

	_fog_button = Button.new()
	_fog_button.text = "Fog: ON"
	_fog_button.add_theme_font_size_override("font_size", 16)
	_fog_button.pressed.connect(_on_fog_toggle)
	bottom.add_child(_fog_button)

	var bottom_spacer2 := Control.new()
	bottom_spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(bottom_spacer2)

	_retreat_button = Button.new()
	_retreat_button.text = "Retreat"
	_retreat_button.add_theme_font_size_override("font_size", 16)
	_retreat_button.pressed.connect(func(): retreat_pressed.emit())
	bottom.add_child(_retreat_button)

	# Victory/Defeat overlay (hidden)
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.7)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var overlay_vbox := VBoxContainer.new()
	overlay_vbox.set_anchors_preset(Control.PRESET_CENTER)
	overlay_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay.add_child(overlay_vbox)

	_overlay_label = Label.new()
	_overlay_label.add_theme_font_size_override("font_size", 48)
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_vbox.add_child(_overlay_label)

	_return_button = Button.new()
	_return_button.text = "Return to Overworld"
	_return_button.add_theme_font_size_override("font_size", 20)
	_return_button.pressed.connect(func(): return_pressed.emit())
	overlay_vbox.add_child(_return_button)

func update_counts(player_alive: int, enemy_alive: int) -> void:
	_player_count_label.text = "YOUR ARMY: %d" % player_alive
	_enemy_count_label.text = "ENEMY: %d" % enemy_alive

func update_timer(seconds: float) -> void:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	_timer_label.text = "%d:%02d" % [mins, secs]

func set_command_mode(enabled: bool) -> void:
	_command_mode = enabled
	if enabled:
		_command_mode_label.text = "COMMANDING"
		_command_mode_label.add_theme_color_override("font_color", Color.GOLD)
	else:
		_command_mode_label.text = "[Tab] Command"
		_command_mode_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))

func show_result(victory: bool) -> void:
	_overlay.visible = true
	if victory:
		_overlay_label.text = "VICTORY!"
		_overlay_label.add_theme_color_override("font_color", Color.GOLD)
	else:
		_overlay_label.text = "DEFEAT"
		_overlay_label.add_theme_color_override("font_color", Color.RED)

func _on_speed_pressed(spd: float) -> void:
	_current_speed = spd
	speed_changed.emit(spd)

func show_notification(text: String) -> void:
	## Show a temporary gold notification at the top center of the screen.
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl.position.y = 50
	lbl.modulate.a = 0.0
	add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.0)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tween.tween_callback(lbl.queue_free)

func _on_fog_toggle() -> void:
	_fog_enabled = not _fog_enabled
	_fog_button.text = "Fog: ON" if _fog_enabled else "Fog: OFF"
	fog_toggled.emit(_fog_enabled)
