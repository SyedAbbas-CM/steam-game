class_name DeathScreen
extends CanvasLayer

var _overlay: ColorRect
var _center: VBoxContainer
var _stats_label: Label
var _retry_btn: Button

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func show_death(run_state: RunState) -> void:
	get_tree().paused = true
	visible = true
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("lose_a", 0.0, 0.0)
	_build_ui(run_state)

func _build_ui(run_state: RunState) -> void:
	# Clear any previous UI
	_clear_ui()

	var vp_size = Vector2(1920, 1080)

	# Dark overlay
	_overlay = ColorRect.new()
	_overlay.position = Vector2.ZERO
	_overlay.size = vp_size
	_overlay.color = Color(0.02, 0.02, 0.05, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var fade = _overlay.create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(_overlay, "color:a", 0.92, 0.8)

	# Centered VBox
	_center = VBoxContainer.new()
	_center.position = Vector2.ZERO
	_center.size = vp_size
	_center.add_theme_constant_override("separation", 20)
	_center.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_center)

	# "YOU DIED" title
	var title = Label.new()
	title.text = "YOU DIED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_s = LabelSettings.new()
	title_s.font_size = 64
	title_s.font_color = Color(0.9, 0.12, 0.12)
	title_s.outline_size = 4
	title_s.outline_color = Color(0.3, 0.0, 0.0)
	title.label_settings = title_s
	title.modulate.a = 0.0
	_center.add_child(title)

	var t_tw = title.create_tween()
	t_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t_tw.tween_interval(0.5)
	t_tw.tween_property(title, "modulate:a", 1.0, 0.6)

	# Subtitle
	var sub = Label.new()
	sub.text = "Your hero has fallen..."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub_s = LabelSettings.new()
	sub_s.font_size = 20
	sub_s.font_color = Color(0.7, 0.6, 0.6)
	sub.label_settings = sub_s
	sub.modulate.a = 0.0
	_center.add_child(sub)

	var s_tw = sub.create_tween()
	s_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	s_tw.tween_interval(1.2)
	s_tw.tween_property(sub, "modulate:a", 1.0, 0.5)

	# Death recap — answers the tester's "I don't know what killed me" question.
	# Reads from save_data.last_death_run_summary (populated by player.take_damage
	# heuristic + GameManager._snapshot_death_legacy).
	var recap_text := _build_death_recap_line()
	if recap_text != "":
		var recap = Label.new()
		recap.text = recap_text
		recap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var recap_s = LabelSettings.new()
		recap_s.font_size = 22
		recap_s.font_color = Color(0.92, 0.7, 0.4)
		recap_s.outline_size = 2
		recap_s.outline_color = Color(0.1, 0.05, 0.0)
		recap.label_settings = recap_s
		recap.modulate.a = 0.0
		_center.add_child(recap)
		var r_tw = recap.create_tween()
		r_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		r_tw.tween_interval(1.4)
		r_tw.tween_property(recap, "modulate:a", 1.0, 0.5)

	# Run stats
	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stat_s = LabelSettings.new()
	stat_s.font_size = 18
	stat_s.font_color = Color(0.75, 0.75, 0.75)
	_stats_label.label_settings = stat_s

	var text = ""
	text += "Floor Reached: " + str(run_state.current_floor) + "\n"
	text += "Rooms Cleared: " + str(run_state.rooms_cleared) + "\n"
	text += "Enemies Killed: " + str(run_state.enemies_killed) + "\n"
	text += "Gold Earned: " + str(run_state.run_gold) + "\n"
	text += "Time: " + str(int(run_state.get_duration_seconds())) + "s"
	_stats_label.text = text
	_stats_label.modulate.a = 0.0
	_center.add_child(_stats_label)

	var st_tw = _stats_label.create_tween()
	st_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	st_tw.tween_interval(1.5)
	st_tw.tween_property(_stats_label, "modulate:a", 1.0, 0.5)

	# Button container
	var btn_box = HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 20)
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.modulate.a = 0.0
	_center.add_child(btn_box)

	# Enter Hall button (death wipes character, world persists)
	_retry_btn = _make_button("Enter Hall of Ancestors")
	_retry_btn.pressed.connect(_on_retry)
	btn_box.add_child(_retry_btn)

	var b_tw = btn_box.create_tween()
	b_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	b_tw.tween_interval(2.0)
	b_tw.tween_property(btn_box, "modulate:a", 1.0, 0.4)

## Builds the "Killed by X: Y, N damage" line from last_death_run_summary.
## Returns "" when the recap fields weren't populated (older saves, debug
## kills) so the screen quietly omits the line instead of showing "Killed
## by : , 0 damage".
func _build_death_recap_line() -> String:
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.save_data:
		return ""
	var summary: Dictionary = gm.save_data.last_death_run_summary
	if summary.is_empty():
		return ""
	var source: String = str(summary.get("recap_source", ""))
	if source == "":
		return ""
	var attack: String = str(summary.get("recap_attack", "Unknown"))
	var dmg: int = int(summary.get("recap_damage", 0))
	return "Killed by %s — %s, %d damage" % [source, attack, dmg]

func _make_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 50)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 22)
	btn.focus_mode = Control.FOCUS_NONE

	var sty = StyleBoxFlat.new()
	sty.bg_color = Color(0.15, 0.08, 0.08, 0.9)
	sty.border_color = Color(0.7, 0.2, 0.2)
	sty.set_border_width_all(2)
	sty.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", sty)

	var hover = sty.duplicate()
	hover.bg_color = Color(0.3, 0.1, 0.1, 0.95)
	hover.border_color = Color(1.0, 0.3, 0.3)
	btn.add_theme_stylebox_override("hover", hover)

	return btn

func _clear_ui() -> void:
	for c in get_children():
		c.queue_free()
	_overlay = null
	_center = null
	_stats_label = null
	_retry_btn = null

func _on_retry() -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click", -3.0)
	_clear_ui()
	visible = false
	get_tree().paused = false
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.call_deferred("go_to_hall_of_ancestors")
	else:
		get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/hall_of_ancestors.tscn")
