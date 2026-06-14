class_name LightingDebugOverlay
extends CanvasLayer

const BUILD_ID := "lightingdbg5"
var _panel: ColorRect
var _label: Label
var _visible_overlay := false
var _sample_timer := 0.0
var _player: Node = null
const SAMPLE_INTERVAL := 0.15

func _ready() -> void:
	layer = 121
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_visible_overlay = not OS.has_feature("editor")
	visible = _visible_overlay
	if _visible_overlay:
		_refresh()

func setup(player: Node) -> void:
	_player = player

func _build_ui() -> void:
	_panel = ColorRect.new()
	_panel.color = Color(0.03, 0.02, 0.02, 0.86)
	_panel.position = Vector2(14, 300)
	_panel.size = Vector2(470, 220)
	add_child(_panel)

	_label = Label.new()
	_label.position = Vector2(10, 8)
	_label.size = Vector2(450, 204)
	var settings := LabelSettings.new()
	settings.font_size = 14
	settings.font_color = Color(0.96, 0.94, 0.9)
	settings.outline_size = 2
	settings.outline_color = Color(0, 0, 0, 0.92)
	_label.label_settings = settings
	_panel.add_child(_label)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10 or event.keycode == KEY_O or event.keycode == KEY_0:
			_toggle_overlay()

func _process(delta: float) -> void:
	if not _visible_overlay:
		return
	_sample_timer += delta
	if _sample_timer >= SAMPLE_INTERVAL:
		_sample_timer = 0.0
		_refresh()

func _toggle_overlay() -> void:
	_visible_overlay = not _visible_overlay
	visible = _visible_overlay
	if _visible_overlay:
		_refresh()

func _refresh() -> void:
	var lm = get_node_or_null("/root/LightingManager")
	if lm == null or not lm.has_method("get_debug_snapshot"):
		_label.text = "LightingDbg[F10/O]\nLightingManager unavailable"
		return
	var snap: Dictionary = lm.get_debug_snapshot(_player)
	var player_speed := 0.0
	var bullet_speed := 0.0
	var player_path := str(snap.get("player_path", "<none>"))
	if _player != null and is_instance_valid(_player) and "equipment_manager" in _player and _player.equipment_manager:
		player_speed = float(_player.equipment_manager.get_move_speed())
		bullet_speed = float(_player.equipment_manager.get_bullet_speed())
	var canvas: Color = snap.get("canvas_color", Color.WHITE)
	var darkness: Color = snap.get("mood_darkness", Color.WHITE)
	var dungeon_start := "<none>"
	var dungeon_biome := "<none>"
	var dungeon_mine := "<none>"
	var dm = get_tree().get_first_node_in_group("dungeon_manager")
	if dm != null:
		dungeon_start = str(dm.get("starting_biome_name"))
		var cb = dm.get("current_biome")
		if cb != null:
			dungeon_biome = str(cb.get("biome_name"))
		var cm = dm.get("current_mine")
		if cm != null:
			dungeon_mine = str(cm.get("mine_name"))
	_label.text = "\n".join([
		"LightingDbg[%s][F10/O] player=%s editor=%s" % [BUILD_ID, player_path, str(OS.has_feature("editor"))],
		"mood=%s dark=%s canvas=(%.2f, %.2f, %.2f) darkcol=(%.2f, %.2f, %.2f)" % [
			str(snap.get("mood_id", "<none>")),
			str(bool(snap.get("mood_dark", false))),
			canvas.r, canvas.g, canvas.b,
			darkness.r, darkness.g, darkness.b,
		],
		"lantern exists=%s parent=%s" % [
			str(bool(snap.get("lantern_exists", false))),
			str(snap.get("lantern_parent", "<none>")),
		],
		"lantern energy=%.2f scale=%.2f shadow=%s torches=%d" % [
			float(snap.get("lantern_energy", 0.0)),
			float(snap.get("lantern_scale", 0.0)),
			str(bool(snap.get("lantern_shadow_enabled", false))),
			int(snap.get("torch_count", 0)),
		],
		"mood player radius=%.2f energy=%.2f shadows=%s" % [
			float(snap.get("mood_player_radius", 0.0)),
			float(snap.get("mood_player_energy", 0.0)),
			str(bool(snap.get("mood_player_shadows", false))),
		],
		"scene=%s quality=%s enabled=%s" % [
			str(snap.get("scene_root", "<none>")),
			str(snap.get("quality", "<none>")),
			str(bool(snap.get("enabled", false))),
		],
		"cache size=%d dark=%s infernal=%s" % [
			int(snap.get("mood_cache_size", 0)),
			str(bool(snap.get("cache_has_dungeon_dark", false))),
			str(bool(snap.get("cache_has_dungeon_infernal", false))),
		],
		"start=%s biome=%s mine=%s" % [dungeon_start, dungeon_biome, dungeon_mine],
		"player move=%.2f bullet=%.2f" % [player_speed, bullet_speed],
	])
