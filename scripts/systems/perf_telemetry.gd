extends Node

# DEBUG ONLY: profiling/telemetry infrastructure. Keep disabled in non-debug builds.
const SAMPLE_INTERVAL_FAST := 0.25
const SAMPLE_INTERVAL_DEEP := 1.0
const SNAPSHOT_WRITE_INTERVAL := 2.0
const SCRIPT_COUNT_LIMIT := 24
const FRAME_SPIKE_THRESHOLD_MS := 34.0
const PHYSICS_SPIKE_THRESHOLD_MS := 12.0
const SPIKE_SNAPSHOT_COOLDOWN := 5.0

var _scene_root: Node = null
var _manager: Node = null
var _fast_timer: float = 0.0
var _deep_timer: float = 0.0
var _write_timer: float = 0.0
var _session_elapsed: float = 0.0
var _session_name: String = ""
var _session_dir: String = ""
var _snapshot_log_path: String = ""
var _summary_path: String = ""
var _session_active: bool = false
var _peak_metrics: Dictionary = {}
var _baseline_metrics: Dictionary = {}
var _baseline_group_counts: Dictionary = {}
var _baseline_tile_counts: Dictionary = {}
var _content_baseline_metrics: Dictionary = {}
var _content_baseline_group_counts: Dictionary = {}
var _content_baseline_tile_counts: Dictionary = {}
var _context: Dictionary = {}
var _last_spike_snapshot_at: float = -9999.0
var _metrics: Dictionary = {
	"fps": 0.0,
	"frame_time_ms": 0.0,
	"physics_time_ms": 0.0,
	"memory_static_mb": 0.0,
	"memory_message_buffer_mb": 0.0,
	"video_mem_mb": 0.0,
	"texture_mem_mb": 0.0,
	"draw_calls": 0.0,
	"object_count": 0.0,
	"resource_count": 0.0,
	"node_count": 0.0,
	"orphan_nodes": 0.0,
	"players_active": 0.0,
	"enemies_active": 0.0,
	"bullets_active": 0.0,
	"hazards_active": 0.0,
	"traps_active": 0.0,
	"fire_patches_active": 0.0,
	"poison_clouds_active": 0.0,
	"particles_active": 0.0,
	"timers_active": 0.0,
	"rooms_tracked": 0.0,
}

func _ready() -> void:
	if not is_enabled():
		set_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_register_custom_monitors()

func is_enabled() -> bool:
	return OS.is_debug_build() or OS.has_feature("editor")

func attach_scene(scene_root: Node, manager_node: Node = null) -> void:
	if not is_enabled():
		return
	detach_scene()
	_scene_root = scene_root
	_manager = manager_node
	_start_session()
	_sample_fast()
	_sample_deep()
	mark_checkpoint("scene_attached")

func detach_scene(scene_root: Node = null) -> void:
	if not is_enabled():
		return
	if scene_root == null or scene_root == _scene_root:
		if _session_active:
			mark_checkpoint("scene_detaching")
			_write_summary()
			_session_active = false
		_scene_root = null
		_manager = null
		_session_name = ""
		_session_dir = ""
		_snapshot_log_path = ""
		_summary_path = ""
		_session_elapsed = 0.0
		_write_timer = 0.0
		_peak_metrics.clear()
		_reset_scene_metrics()

func get_metric(name: StringName) -> float:
	return float(_metrics.get(name, 0.0))

func get_metrics_snapshot() -> Dictionary:
	return _metrics.duplicate()

func get_session_dir() -> String:
	return _session_dir

func mark_checkpoint(label: String, extra: Dictionary = {}) -> void:
	if not is_enabled():
		return
	if not _session_active:
		return
	_context["last_checkpoint"] = label
	if not extra.is_empty():
		for key in extra.keys():
			_context[key] = extra[key]
	if label == "floor_changed" and int(extra.get("floor", -1)) == 1 and _content_baseline_metrics.is_empty():
		_content_baseline_metrics = _metrics.duplicate(true)
		_content_baseline_group_counts = _build_group_counts()
		_content_baseline_tile_counts = _build_tile_counts()
	_write_snapshot(label, extra, true)

func _process(delta: float) -> void:
	if not is_enabled():
		return
	_fast_timer += delta
	_deep_timer += delta
	if _session_active:
		_session_elapsed += delta
		_write_timer += delta
	if _fast_timer >= SAMPLE_INTERVAL_FAST:
		_fast_timer = 0.0
		_sample_fast()
	if _deep_timer >= SAMPLE_INTERVAL_DEEP:
		_deep_timer = 0.0
		_sample_deep()
	if _session_active and _write_timer >= SNAPSHOT_WRITE_INTERVAL:
		_write_timer = 0.0
		_write_snapshot("interval")

func _register_custom_monitors() -> void:
	if not is_enabled():
		return
	var monitors := {
		"game/fps": Callable(self, "_monitor_fps"),
		"game/frame_time_ms": Callable(self, "_monitor_frame_time_ms"),
		"game/physics_time_ms": Callable(self, "_monitor_physics_time_ms"),
		"game/memory_static_mb": Callable(self, "_monitor_memory_static_mb"),
		"game/memory_message_buffer_mb": Callable(self, "_monitor_memory_message_buffer_mb"),
		"game/video_mem_mb": Callable(self, "_monitor_video_mem_mb"),
		"game/texture_mem_mb": Callable(self, "_monitor_texture_mem_mb"),
		"game/draw_calls": Callable(self, "_monitor_draw_calls"),
		"game/object_count": Callable(self, "_monitor_object_count"),
		"game/resource_count": Callable(self, "_monitor_resource_count"),
		"game/node_count": Callable(self, "_monitor_node_count"),
		"game/orphan_nodes": Callable(self, "_monitor_orphan_nodes"),
		"game/players_active": Callable(self, "_monitor_players_active"),
		"game/enemies_active": Callable(self, "_monitor_enemies_active"),
		"game/bullets_active": Callable(self, "_monitor_bullets_active"),
		"game/hazards_active": Callable(self, "_monitor_hazards_active"),
		"game/traps_active": Callable(self, "_monitor_traps_active"),
		"game/fire_patches_active": Callable(self, "_monitor_fire_patches_active"),
		"game/poison_clouds_active": Callable(self, "_monitor_poison_clouds_active"),
		"game/particles_active": Callable(self, "_monitor_particles_active"),
		"game/timers_active": Callable(self, "_monitor_timers_active"),
		"game/rooms_tracked": Callable(self, "_monitor_rooms_tracked"),
	}
	for monitor_name in monitors:
		Performance.add_custom_monitor(monitor_name, monitors[monitor_name])

func _sample_fast() -> void:
	_metrics["fps"] = float(Engine.get_frames_per_second())
	_metrics["frame_time_ms"] = float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	_metrics["physics_time_ms"] = float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	_metrics["memory_static_mb"] = float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
	_metrics["memory_message_buffer_mb"] = float(Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX)) / 1048576.0
	_metrics["video_mem_mb"] = float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / 1048576.0
	_metrics["texture_mem_mb"] = float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / 1048576.0
	_metrics["draw_calls"] = float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_metrics["object_count"] = float(Performance.get_monitor(Performance.OBJECT_COUNT))
	_metrics["resource_count"] = float(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	_metrics["node_count"] = float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_metrics["orphan_nodes"] = float(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	var tree := get_tree()
	if tree == null:
		_reset_scene_metrics()
		return

	_metrics["players_active"] = float(tree.get_nodes_in_group("player").size())
	_metrics["enemies_active"] = float(tree.get_nodes_in_group("enemy").size())
	_metrics["traps_active"] = float(tree.get_nodes_in_group("trap").size())
	_metrics["fire_patches_active"] = float(tree.get_nodes_in_group("fire_patch").size())
	_metrics["poison_clouds_active"] = float(tree.get_nodes_in_group("poison_cloud").size())

	var bullets_container := tree.get_first_node_in_group("bullets")
	_metrics["bullets_active"] = float(bullets_container.get_child_count()) if bullets_container else 0.0

	var manager := _resolve_manager()
	if manager:
		var hazards = manager.get("hazard_container")
		_metrics["hazards_active"] = float(hazards.get_child_count()) if hazards else 0.0
		var room_states = manager.get("room_states")
		_metrics["rooms_tracked"] = float(room_states.size()) if room_states is Dictionary else 0.0
	else:
		_metrics["hazards_active"] = 0.0
	_metrics["rooms_tracked"] = 0.0
	_update_peak_metrics()
	_maybe_write_spike_snapshot()

func _sample_deep() -> void:
	var root := _resolve_scene_root()
	if root == null:
		_metrics["particles_active"] = 0.0
		_metrics["timers_active"] = 0.0
		return

	var counts := {
		"particles": 0,
		"timers": 0,
	}
	_scan_deep_counts(root, counts)
	_metrics["particles_active"] = float(counts["particles"])
	_metrics["timers_active"] = float(counts["timers"])
	_update_peak_metrics()
	_maybe_write_spike_snapshot()

func _scan_deep_counts(node: Node, counts: Dictionary) -> void:
	if node is CPUParticles2D or node is GPUParticles2D:
		counts["particles"] += 1
	elif node is Timer:
		counts["timers"] += 1

	for child in node.get_children():
		if child is Node:
			_scan_deep_counts(child, counts)

func _resolve_scene_root() -> Node:
	if _scene_root and is_instance_valid(_scene_root):
		return _scene_root
	var tree := get_tree()
	if tree == null:
		return null
	return tree.current_scene

func _resolve_manager() -> Node:
	if _manager and is_instance_valid(_manager):
		return _manager
	var tree := get_tree()
	if tree == null:
		return null
	var manager := tree.get_first_node_in_group("dungeon_manager")
	if manager and is_instance_valid(manager):
		_manager = manager
		return manager
	return null

func _reset_scene_metrics() -> void:
	for key in [
		"fps",
		"frame_time_ms",
		"physics_time_ms",
		"memory_static_mb",
		"memory_message_buffer_mb",
		"video_mem_mb",
		"texture_mem_mb",
		"draw_calls",
		"object_count",
		"resource_count",
		"node_count",
		"orphan_nodes",
		"players_active",
		"enemies_active",
		"bullets_active",
		"hazards_active",
		"traps_active",
		"fire_patches_active",
		"poison_clouds_active",
		"particles_active",
		"timers_active",
		"rooms_tracked",
	]:
		_metrics[key] = 0.0

func _start_session() -> void:
	var root := _resolve_scene_root()
	if root == null:
		return
	var scene_name := root.name.to_lower().replace(" ", "_")
	var timestamp := "%s_%s" % [Time.get_datetime_string_from_system(false).replace(":", "-"), scene_name]
	_session_name = timestamp
	_session_dir = "user://profiling/%s" % timestamp
	_snapshot_log_path = "%s/snapshots.jsonl" % _session_dir
	_summary_path = "%s/summary.json" % _session_dir
	DirAccess.make_dir_recursive_absolute(_session_dir)
	var meta_path := "%s/session.json" % _session_dir
	var meta := {
		"session_name": _session_name,
		"scene_name": root.name,
		"scene_path": root.scene_file_path,
		"started_at": Time.get_datetime_string_from_system(),
		"user_dir": ProjectSettings.globalize_path(_session_dir),
	}
	var meta_file := FileAccess.open(meta_path, FileAccess.WRITE)
	if meta_file:
		meta_file.store_string(JSON.stringify(meta, "\t"))
	var snapshot_file := FileAccess.open(_snapshot_log_path, FileAccess.WRITE)
	if snapshot_file:
		snapshot_file.store_string("")
	_session_active = true
	_write_timer = 0.0
	_session_elapsed = 0.0
	_peak_metrics = _metrics.duplicate(true)
	_baseline_metrics = _metrics.duplicate(true)
	_baseline_group_counts = _build_group_counts()
	_baseline_tile_counts = _build_tile_counts()
	_content_baseline_metrics = {}
	_content_baseline_group_counts = {}
	_content_baseline_tile_counts = {}
	_context = {
		"scene_name": root.name,
	}
	_last_spike_snapshot_at = -9999.0
	print("PERF SESSION STARTED: %s" % ProjectSettings.globalize_path(_session_dir))

func _update_peak_metrics() -> void:
	for key in _metrics.keys():
		var current := float(_metrics[key])
		var peak := float(_peak_metrics.get(key, current))
		if current > peak:
			_peak_metrics[key] = current
		elif not _peak_metrics.has(key):
			_peak_metrics[key] = current

func _write_snapshot(label: String, extra: Dictionary = {}, include_deep_census: bool = false) -> void:
	if _snapshot_log_path == "":
		return
	var payload := {
		"timestamp": Time.get_datetime_string_from_system(),
		"elapsed_s": snappedf(_session_elapsed, 0.001),
		"label": label,
		"metrics": _metrics.duplicate(true),
		"metric_deltas": _build_metric_delta_map(_metrics, _baseline_metrics),
		"tile_counts": _build_tile_counts(),
		"group_counts": _build_group_counts(),
		"context": _context.duplicate(true),
	}
	if not extra.is_empty():
		payload["extra"] = extra.duplicate(true)
	if include_deep_census:
		payload["node_class_counts"] = _build_node_class_counts()
		payload["script_counts"] = _build_script_counts()
		payload["tracked_script_counts"] = _build_tracked_script_counts()
	var file := FileAccess.open(_snapshot_log_path, FileAccess.READ_WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(payload))

func _write_summary() -> void:
	if _summary_path == "":
		return
	var summary := {
		"session_name": _session_name,
		"ended_at": Time.get_datetime_string_from_system(),
		"duration_s": snappedf(_session_elapsed, 0.001),
		"baseline_metrics": _baseline_metrics.duplicate(true),
		"content_baseline_metrics": _content_baseline_metrics.duplicate(true),
		"final_metrics": _metrics.duplicate(true),
		"delta_metrics": _build_metric_delta_map(_metrics, _baseline_metrics),
		"content_delta_metrics": _build_metric_delta_map(_metrics, _content_baseline_metrics),
		"peak_metrics": _peak_metrics.duplicate(true),
		"peak_metric_deltas": _build_metric_delta_map(_peak_metrics, _baseline_metrics),
		"peak_content_deltas": _build_metric_delta_map(_peak_metrics, _content_baseline_metrics),
		"baseline_tile_counts": _baseline_tile_counts.duplicate(true),
		"content_baseline_tile_counts": _content_baseline_tile_counts.duplicate(true),
		"final_tile_counts": _build_tile_counts(),
		"tile_count_deltas": _build_count_delta_map(_build_tile_counts(), _baseline_tile_counts),
		"baseline_group_counts": _baseline_group_counts.duplicate(true),
		"content_baseline_group_counts": _content_baseline_group_counts.duplicate(true),
		"final_group_counts": _build_group_counts(),
		"group_count_deltas": _build_count_delta_map(_build_group_counts(), _baseline_group_counts),
		"content_group_deltas": _build_count_delta_map(_build_group_counts(), _content_baseline_group_counts),
		"final_node_class_counts": _build_node_class_counts(),
		"final_script_counts": _build_script_counts(),
		"tracked_script_counts": _build_tracked_script_counts(),
		"context": _context.duplicate(true),
		"suspect_report": _build_suspect_report(),
	}
	var file := FileAccess.open(_summary_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(summary, "\t"))

func _build_tile_counts() -> Dictionary:
	var out := {}
	var owner := _resolve_manager()
	if owner == null:
		owner = _resolve_scene_root()
	if owner == null:
		return out
	for layer_name in ["floor_layer", "wall_layer", "deco_layer", "liquid_layer", "ground", "paths", "water", "decorations", "buildings", "fences"]:
		var layer = owner.get(layer_name)
		if layer and layer is TileMapLayer:
			out[layer_name] = layer.get_used_cells().size()
	var room_states = owner.get("room_states")
	if room_states is Dictionary:
		out["room_states"] = room_states.size()
	var runtime = owner.get("mine_runtime")
	if runtime and runtime is RefCounted:
		var breakable = runtime.get("_breakable_cells")
		if breakable is Dictionary:
			out["breakable_cells"] = breakable.size()
	return out

func _build_group_counts() -> Dictionary:
	var tree := get_tree()
	if tree == null:
		return {}
	var out := {
		"player": tree.get_nodes_in_group("player").size(),
		"enemy": tree.get_nodes_in_group("enemy").size(),
		"trap": tree.get_nodes_in_group("trap").size(),
		"fire_patch": tree.get_nodes_in_group("fire_patch").size(),
		"poison_cloud": tree.get_nodes_in_group("poison_cloud").size(),
		"breakable": tree.get_nodes_in_group("breakable").size(),
	}
	var bullets_container := tree.get_first_node_in_group("bullets")
	out["bullets_children"] = bullets_container.get_child_count() if bullets_container else 0
	return out

func _build_node_class_counts() -> Dictionary:
	var root := _resolve_scene_root()
	if root == null:
		return {}
	var counts := {}
	_collect_node_class_counts(root, counts)
	return counts

func _collect_node_class_counts(node: Node, counts: Dictionary) -> void:
	var cls := node.get_class()
	counts[cls] = int(counts.get(cls, 0)) + 1
	for child in node.get_children():
		if child is Node:
			_collect_node_class_counts(child, counts)

func _build_script_counts() -> Dictionary:
	var root := _resolve_scene_root()
	if root == null:
		return {}
	var counts := {}
	_collect_script_counts(root, counts)
	var entries: Array[Dictionary] = []
	for key in counts.keys():
		entries.append({"path": key, "count": counts[key]})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["count"]) > int(b["count"]))
	var trimmed := {}
	for i in range(mini(SCRIPT_COUNT_LIMIT, entries.size())):
		trimmed[entries[i]["path"]] = entries[i]["count"]
	return trimmed

func _build_tracked_script_counts() -> Dictionary:
	var root := _resolve_scene_root()
	if root == null:
		return {}
	var raw_counts := {}
	_collect_script_counts(root, raw_counts)
	var tracked := {}
	for key in raw_counts.keys():
		var path := String(key)
		if path.begins_with("res://scripts/dungeon/traps/") \
		or path == "res://scripts/dungeon/trap_tile.gd" \
		or path == "res://scripts/enemy.gd" \
		or path == "res://scripts/bullet.gd" \
		or path == "res://scripts/drops/pickup.gd" \
		or path == "res://scripts/drops/loot_bag.gd":
			tracked[path] = raw_counts[key]
	return tracked

func _build_metric_delta_map(current: Dictionary, baseline: Dictionary) -> Dictionary:
	var out := {}
	for key in current.keys():
		out[key] = float(current.get(key, 0.0)) - float(baseline.get(key, 0.0))
	return out

func _build_count_delta_map(current: Dictionary, baseline: Dictionary) -> Dictionary:
	var out := {}
	for key in current.keys():
		out[key] = int(current.get(key, 0)) - int(baseline.get(key, 0))
	for key in baseline.keys():
		if not out.has(key):
			out[key] = -int(baseline.get(key, 0))
	return out

func _maybe_write_spike_snapshot() -> void:
	if not _session_active:
		return
	if _session_elapsed - _last_spike_snapshot_at < SPIKE_SNAPSHOT_COOLDOWN:
		return
	var frame_ms := float(_metrics.get("frame_time_ms", 0.0))
	var physics_ms := float(_metrics.get("physics_time_ms", 0.0))
	var orphan_delta := float(_metrics.get("orphan_nodes", 0.0)) - float(_baseline_metrics.get("orphan_nodes", 0.0))
	if frame_ms >= FRAME_SPIKE_THRESHOLD_MS or physics_ms >= PHYSICS_SPIKE_THRESHOLD_MS or orphan_delta >= 25.0:
		_last_spike_snapshot_at = _session_elapsed
		_write_snapshot("spike", {
			"frame_time_ms": frame_ms,
			"physics_time_ms": physics_ms,
			"orphan_delta": orphan_delta,
		}, true)

func _collect_script_counts(node: Node, counts: Dictionary) -> void:
	var script = node.get_script()
	if script and script is Script:
		var path: String = script.resource_path if script.resource_path != "" else "<built-in>"
		counts[path] = int(counts.get(path, 0)) + 1
	for child in node.get_children():
		if child is Node:
			_collect_script_counts(child, counts)

func _build_suspect_report() -> Array[Dictionary]:
	var suspects: Array[Dictionary] = []
	_push_suspect_if_peak(suspects, "frame_time_ms", 16.7, "performance", "Frame time exceeded 60 FPS budget.")
	_push_suspect_if_peak(suspects, "bullets_active", 180.0, "gameplay", "Bullet count grew high enough to plausibly cause CPU pressure.")
	_push_suspect_if_peak(suspects, "hazards_active", 80.0, "gameplay", "Hazard count is high; traps/aftermath may be accumulating.")
	_push_suspect_if_peak(suspects, "particles_active", 120.0, "visuals", "Particle count is high; persistent effects may be too expensive.")
	_push_suspect_if_peak(suspects, "timers_active", 120.0, "lifecycle", "Timer count is high; repeated helper/timer creation may be churning.")
	var orphan_baseline := float(_baseline_metrics.get("orphan_nodes", 0.0))
	var orphan_final := float(_metrics.get("orphan_nodes", orphan_baseline))
	var orphan_peak := float(_peak_metrics.get("orphan_nodes", orphan_final))
	if orphan_peak > orphan_baseline + 5.0:
		suspects.append({
			"kind": "leak",
			"metric": "orphan_nodes",
			"baseline": orphan_baseline,
			"final": orphan_final,
			"peak": orphan_peak,
			"message": "Orphan nodes grew during the session; detached nodes may not be freed correctly.",
		})
	elif orphan_peak >= 1.0:
		suspects.append({
			"kind": "baseline",
			"metric": "orphan_nodes",
			"baseline": orphan_baseline,
			"peak": orphan_peak,
			"message": "Orphan nodes were already present at baseline; growth was limited during this session.",
		})

	var final_nodes := float(_metrics.get("node_count", 0.0))
	var peak_nodes := float(_peak_metrics.get("node_count", final_nodes))
	if final_nodes > 0.0 and peak_nodes > final_nodes * 1.25:
		suspects.append({
			"kind": "growth",
			"metric": "node_count",
			"final": final_nodes,
			"peak": peak_nodes,
			"message": "Node count grew materially during the session.",
		})

	var final_resources := float(_metrics.get("resource_count", 0.0))
	var peak_resources := float(_peak_metrics.get("resource_count", final_resources))
	if final_resources > 0.0 and peak_resources > final_resources * 1.15:
		suspects.append({
			"kind": "growth",
			"metric": "resource_count",
			"final": final_resources,
			"peak": peak_resources,
			"message": "Resource count grew materially during the session.",
		})

	var final_vram := float(_metrics.get("video_mem_mb", 0.0))
	var peak_vram := float(_peak_metrics.get("video_mem_mb", final_vram))
	if final_vram > 0.0 and peak_vram > final_vram + 64.0:
		suspects.append({
			"kind": "render",
			"metric": "video_mem_mb",
			"final": final_vram,
			"peak": peak_vram,
			"message": "VRAM usage climbed substantially during the session.",
		})

	var content_baseline_hazards := float(_content_baseline_metrics.get("hazards_active", 0.0))
	var peak_hazards := float(_peak_metrics.get("hazards_active", content_baseline_hazards))
	if content_baseline_hazards >= 80.0:
		suspects.append({
			"kind": "content_density",
			"metric": "hazards_active",
			"baseline": content_baseline_hazards,
			"peak": peak_hazards,
			"message": "Hazard density is already high immediately after floor generation; floor load itself is heavy before combat ramps up.",
		})

	var content_baseline_traps := float(_content_baseline_metrics.get("traps_active", 0.0))
	var peak_traps := float(_peak_metrics.get("traps_active", content_baseline_traps))
	if content_baseline_traps >= 80.0:
		suspects.append({
			"kind": "content_density",
			"metric": "traps_active",
			"baseline": content_baseline_traps,
			"peak": peak_traps,
			"message": "Trap density is already high immediately after floor generation; trap pressure is largely front-loaded by room generation.",
		})

	return suspects

func _push_suspect_if_peak(suspects: Array[Dictionary], metric: String, threshold: float, kind: String, message: String) -> void:
	var peak := float(_peak_metrics.get(metric, 0.0))
	if peak >= threshold:
		suspects.append({
			"kind": kind,
			"metric": metric,
			"threshold": threshold,
			"peak": peak,
			"message": message,
		})

func _monitor_fps() -> float:
	return get_metric("fps")

func _monitor_frame_time_ms() -> float:
	return get_metric("frame_time_ms")

func _monitor_physics_time_ms() -> float:
	return get_metric("physics_time_ms")

func _monitor_memory_static_mb() -> float:
	return get_metric("memory_static_mb")

func _monitor_memory_message_buffer_mb() -> float:
	return get_metric("memory_message_buffer_mb")

func _monitor_video_mem_mb() -> float:
	return get_metric("video_mem_mb")

func _monitor_texture_mem_mb() -> float:
	return get_metric("texture_mem_mb")

func _monitor_draw_calls() -> float:
	return get_metric("draw_calls")

func _monitor_object_count() -> float:
	return get_metric("object_count")

func _monitor_resource_count() -> float:
	return get_metric("resource_count")

func _monitor_node_count() -> float:
	return get_metric("node_count")

func _monitor_orphan_nodes() -> float:
	return get_metric("orphan_nodes")

func _monitor_players_active() -> float:
	return get_metric("players_active")

func _monitor_enemies_active() -> float:
	return get_metric("enemies_active")

func _monitor_bullets_active() -> float:
	return get_metric("bullets_active")

func _monitor_hazards_active() -> float:
	return get_metric("hazards_active")

func _monitor_traps_active() -> float:
	return get_metric("traps_active")

func _monitor_fire_patches_active() -> float:
	return get_metric("fire_patches_active")

func _monitor_poison_clouds_active() -> float:
	return get_metric("poison_clouds_active")

func _monitor_particles_active() -> float:
	return get_metric("particles_active")

func _monitor_timers_active() -> float:
	return get_metric("timers_active")

func _monitor_rooms_tracked() -> float:
	return get_metric("rooms_tracked")
