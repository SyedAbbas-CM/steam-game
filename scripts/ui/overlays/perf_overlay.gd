class_name PerfOverlay
extends CanvasLayer

# DEBUG ONLY: on-screen perf overlay. Keep out of release gameplay.
var _panel: ColorRect
var _label: Label
var _visible_overlay: bool = false
var _sample_timer: float = 0.0
const SAMPLE_INTERVAL := 0.25

func _ready() -> void:
	if not PerfTelemetry.is_enabled():
		queue_free()
		return
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func setup() -> void:
	pass

func _build_ui() -> void:
	_panel = ColorRect.new()
	_panel.color = Color(0.02, 0.03, 0.04, 0.82)
	_panel.position = Vector2(14, 140)
	_panel.size = Vector2(290, 150)
	add_child(_panel)

	_label = Label.new()
	_label.position = Vector2(10, 8)
	_label.size = Vector2(270, 132)
	var settings := LabelSettings.new()
	settings.font_size = 14
	settings.font_color = Color(0.88, 0.96, 0.9)
	settings.outline_size = 2
	settings.outline_color = Color(0, 0, 0, 0.9)
	_label.label_settings = settings
	_panel.add_child(_label)

func _input(event: InputEvent) -> void:
	if not PerfTelemetry.is_enabled():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("perf_toggle") or event.keycode == KEY_F9:
			_toggle_overlay()

func _process(delta: float) -> void:
	if not PerfTelemetry.is_enabled():
		return
	if not _visible_overlay:
		return
	_sample_timer += delta
	if _sample_timer >= SAMPLE_INTERVAL:
		_sample_timer = 0.0
		_refresh()

func _refresh() -> void:
	if _label == null:
		return
	var metrics := PerfTelemetry.get_metrics_snapshot()
	var fps := int(metrics.get("fps", 0.0))
	var frame_time_ms := float(metrics.get("frame_time_ms", 0.0))
	var memory_mb := float(metrics.get("memory_static_mb", 0.0))
	var video_mem_mb := float(metrics.get("video_mem_mb", 0.0))
	var object_count := int(metrics.get("object_count", 0.0))
	var resource_count := int(metrics.get("resource_count", 0.0))
	var orphan_count := int(metrics.get("orphan_nodes", 0.0))
	var player_count := int(metrics.get("players_active", 0.0))
	var enemy_count := int(metrics.get("enemies_active", 0.0))
	var bullet_count := int(metrics.get("bullets_active", 0.0))
	var hazard_count := int(metrics.get("hazards_active", 0.0))
	var trap_count := int(metrics.get("traps_active", 0.0))
	var particles_count := int(metrics.get("particles_active", 0.0))
	var fire_patch_count := int(metrics.get("fire_patches_active", 0.0))
	var poison_cloud_count := int(metrics.get("poison_clouds_active", 0.0))
	var timer_count := int(metrics.get("timers_active", 0.0))
	var room_count := int(metrics.get("rooms_tracked", 0.0))
	var node_count := int(metrics.get("node_count", 0.0))
	var line1 := "Perf[9/F9] FPS:%d Frame:%.2fms Mem:%.1fMB VRAM:%.1fMB" % [fps, frame_time_ms, memory_mb, video_mem_mb]
	var line2 := "Players:%d Enemies:%d Bullets:%d Hazards:%d Traps:%d" % [player_count, enemy_count, bullet_count, hazard_count, trap_count]
	var line3 := "Fire:%d Gas:%d Particles:%d Timers:%d Rooms:%d" % [fire_patch_count, poison_cloud_count, particles_count, timer_count, room_count]
	var line4 := "Objects:%d Resources:%d Nodes:%d Orphans:%d" % [object_count, resource_count, node_count, orphan_count]
	_label.text = "%s\n%s\n%s\n%s" % [line1, line2, line3, line4]

func _toggle_overlay() -> void:
	_visible_overlay = not _visible_overlay
	visible = _visible_overlay
	if _visible_overlay:
		_refresh()
