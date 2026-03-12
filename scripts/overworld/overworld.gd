@tool
class_name Overworld
extends Node2D

@onready var ground: TileMapLayer = $Ground
@onready var paths: TileMapLayer = $Paths
@onready var water: TileMapLayer = $Water
@onready var decorations: TileMapLayer = $Decorations
@onready var buildings: TileMapLayer = $Buildings
@onready var fences: TileMapLayer = $Fences

## All loaded zone data for the world
var zone_data: Array[LoyZoneData] = []
var _door_shapes: Dictionary = {}  # cell -> CollisionShape2D
var _wall_body: StaticBody2D
var _door_areas: Array[Area2D] = []
var _enemy_def_cache: Dictionary = {}  # path -> EnemyDefinition
var _nearby_entrance: Area2D = null  # entrance the player is standing near
var _tile_inspector: TileInspector = null  # tile inspection popup
var _zone_spawn_data: Array = []  # [{zone, spawn_data, enemy_def, ox, oy, s}] for respawning
var _respawn_timer: float = 0.0
const RESPAWN_INTERVAL: float = 45.0  # seconds between respawn checks
const MAX_ENEMIES_PER_ZONE: int = 6

## Zone-based loading: only load chunks in current zone + connected zones
var _current_zone: LoyZoneData = null
var _allowed_zone_ids: Array = []  # zone IDs whose chunks can load
var _zone_bboxes: Dictionary = {}  # zone_id -> Rect2i (tile bounding box with corridor margin)
var _zone_gates: Array = []  # Area2D gate triggers at zone exits
var _zone_label: Label = null  # zone name HUD
var _zone_label_tween: Tween = null

const CHUNK_SIZE = 64  # tiles per chunk side
const LOAD_RADIUS = 3  # chunks loaded around player
@export var chunks_base_path: String = "res://resources/world/chunks"
@export var player_spawn_tile: Vector2i = Vector2i(65, 27)  # tile coords from editor
const TILES_PER_FRAME = 2000  # max tile set_cell calls per frame
var _chunk_keys_set: Dictionary = {}  # "cx_cy" -> true (available chunks from index)
var _chunk_cache: Dictionary = {}  # "cx_cy" -> Resource (pre-loaded chunk data)
var _loaded_chunks: Dictionary = {}  # Vector2i -> { "cells": { layer -> [cells] }, "shapes": Array, "entrances": Array }
var _tile_queue: Array = []  # [{chunk_key, layer, cells_remaining, chunk_info}] for incremental loading
var _pending_loads: Dictionary = {}  # "cx_cy" -> true (async loads in progress)
var _unload_queue: Array = []  # Array of Vector2i chunk keys to unload incrementally
var _last_chunk: Vector2i = Vector2i(-9999, -9999)
var _all_layers: Dictionary = {}  # name -> TileMapLayer
var _layer_names: Array = ["ground", "paths", "water", "decorations", "buildings", "fences"]
const PREFETCH_RADIUS = 5  # pre-request chunks beyond LOAD_RADIUS

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Skip _ready when running headless (e.g., rebuild scripts)
	if DisplayServer.get_name() == "headless":
		return

	var t0 = Time.get_ticks_msec()
	var player = $Player
	# Scale visuals only — scaling CharacterBody2D breaks move_and_slide()
	player.get_node("Sprite2D").scale = Vector2(4, 4)
	var _col = player.get_node("CollisionShape2D")
	_col.shape = RectangleShape2D.new()
	_col.shape.size = Vector2(24, 24)
	var _hitbox_col = player.get_node("Hitbox/CollisionShape2D")
	_hitbox_col.shape = CircleShape2D.new()
	_hitbox_col.shape.radius = 8.0
	# DEBUG: verify player physics setup
	print("DEBUG PLAYER: scale=%s col_layer=%d col_mask=%d shape_size=%s" % [player.scale, player.collision_layer, player.collision_mask, _col.shape.size])
	print("DEBUG PLAYER: col_shape disabled=%s" % _col.disabled)

	# Fix camera zoom at runtime (scene .scn may have stale values)
	var cam = player.get_node_or_null("Camera2D")
	if cam:
		cam.zoom = Vector2(1.6, 1.6)

	# Set player to spawn position (tile coords → pixel coords)
	var spawn_px = Vector2(player_spawn_tile.x * 32 + 16, player_spawn_tile.y * 32 + 16)
	player.global_position = spawn_px
	print("Player spawn: tile %s → pixel %s" % [player_spawn_tile, spawn_px])

	# Phase 1: Essential setup
	_load_zone_data()
	print("TIMING: overworld _load_zone_data took %d ms" % (Time.get_ticks_msec() - t0))

	# Load tile names from external .tres tilesets (with custom_data tile names)
	# Each .tres has source 0 internally, mapped to overworld source IDs 0/1/2
	var _name_tilesets: Array = [
		[0, "res://assets/tilesets/loy_maptiles_tileset.tres"],
		[1, "res://assets/tilesets/environment_32_tileset.tres"],
		[2, "res://assets/tilesets/dungeon_features_32_tileset.tres"],
	]
	for entry in _name_tilesets:
		var ts_res = load(entry[1]) as TileSet
		if ts_res:
			TileNames.load_from_tileset(ts_res, 0, entry[0])
	TileNames.load_fallbacks()

	_setup_game_hud(player)

	if has_node("TouchControls"):
		player.touch_controls = $TouchControls
	if has_node("InventoryScreen"):
		$InventoryScreen.setup(player.equipment_manager)

	# Phase 2: Init chunk system (clear scene tiles, load index, load nearby chunks)
	var t1 = Time.get_ticks_msec()
	_init_chunk_system()
	print("TIMING: overworld chunk init took %d ms" % (Time.get_ticks_msec() - t1))

	# Phase 3: Defer heavy work
	_deferred_init.call_deferred()
	print("TIMING: overworld _ready took %d ms (deferred init pending)" % (Time.get_ticks_msec() - t0))

var _use_file_chunks: bool = true  # true = load from .tres files, false = extracted from scene

func _init_chunk_system() -> void:
	_all_layers = {
		"ground": ground,
		"paths": paths,
		"water": water,
		"decorations": decorations,
		"buildings": buildings,
		"fences": fences,
	}

	# Create wall body for collision shapes
	_wall_body = StaticBody2D.new()
	_wall_body.name = "WallBody"
	_wall_body.collision_layer = 16
	_wall_body.collision_mask = 0
	add_child(_wall_body)

	# Check if pre-baked chunks exist and are up-to-date
	print("CHUNKS: Loading from '%s'" % chunks_base_path)
	var index_path = chunks_base_path + "/index.tres"
	var chunks_valid = false

	if ResourceLoader.exists(index_path):
		var index = load(index_path) as Resource
		var keys = index.get_meta("keys", PackedStringArray())
		if keys.size() > 0:
			for k in keys:
				_chunk_keys_set[k] = true
			chunks_valid = true
			print("Chunk index: %d chunks available (pre-baked)" % keys.size())

	if chunks_valid:
		_use_file_chunks = true
		# Clear any stale tile data from the scene
		for layer_name in _all_layers:
			(_all_layers[layer_name] as TileMapLayer).clear()
		# Chunks loaded on-demand and cached after first load (no upfront cost)
	else:
		_use_file_chunks = false
		print("WARNING: No valid chunk files — extracting tiles from scene (run bake_chunks.gd for faster loading)")
		_extract_chunks_from_scene()

	# Initialize zone tracking before loading chunks
	var player = $Player
	var tile_pos = Vector2i(int(player.position.x / 32), int(player.position.y / 32))
	_current_zone = _find_zone_data_for_tile(tile_pos)
	if _current_zone:
		_rebuild_allowed_zones()
		print("Starting zone: %s (%s)" % [_current_zone.id, _current_zone.zone_name])
	else:
		print("WARNING: Player spawn tile not in any zone — loading all chunks")

	# Load chunks near player start position (immediately, not queued)
	_last_chunk = Vector2i(
		int(floor(float(tile_pos.x) / CHUNK_SIZE)),
		int(floor(float(tile_pos.y) / CHUNK_SIZE))
	)
	_load_initial_chunks(_last_chunk)

## Get cached chunk resource (returns null if not yet loaded)
func _get_chunk_resource(key_str: String) -> Resource:
	if _chunk_cache.has(key_str):
		return _chunk_cache[key_str]
	return null

## Start async loading of a chunk resource
func _request_chunk_load(key_str: String) -> void:
	if _chunk_cache.has(key_str) or _pending_loads.has(key_str):
		return
	var chunk_path = chunks_base_path + "/chunk_%s.tres" % key_str
	if not ResourceLoader.exists(chunk_path):
		return
	ResourceLoader.load_threaded_request(chunk_path)
	_pending_loads[key_str] = true

## Check pending async loads and move completed ones to cache
func _poll_async_loads() -> void:
	var done: Array = []
	for key_str in _pending_loads:
		var chunk_path = chunks_base_path + "/chunk_%s.tres" % key_str
		var status = ResourceLoader.load_threaded_get_status(chunk_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var res = ResourceLoader.load_threaded_get(chunk_path)
			if res:
				_chunk_cache[key_str] = res
			done.append(key_str)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			done.append(key_str)
	for key_str in done:
		_pending_loads.erase(key_str)

## Synchronous load for initial chunks only (startup)
func _load_chunk_resource_sync(key_str: String) -> Resource:
	if _chunk_cache.has(key_str):
		return _chunk_cache[key_str]
	var chunk_path = chunks_base_path + "/chunk_%s.tres" % key_str
	var res = load(chunk_path)
	if res:
		_chunk_cache[key_str] = res
	return res

func _load_initial_chunks(center: Vector2i) -> void:
	# Load only the closest ring synchronously (essential for first frame)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var key = Vector2i(center.x + dx, center.y + dy)
			if _chunk_in_allowed_zones(key):
				_load_chunk_immediate(key)
	# Request the rest of LOAD_RADIUS async (will paint incrementally)
	for dy in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			if abs(dx) <= 1 and abs(dy) <= 1:
				continue  # already loaded sync
			var key = Vector2i(center.x + dx, center.y + dy)
			if not _chunk_in_allowed_zones(key):
				continue
			var key_str = "%d_%d" % [key.x, key.y]
			if _chunk_keys_set.has(key_str):
				_request_chunk_load(key_str)
	# Pre-request chunks in the prefetch ring for seamless movement
	_prefetch_chunks(center)

## Fallback: extract tile data from the loaded scene into in-memory chunks
## Used when chunk files don't exist (e.g. first run after editing overworld.tscn)
var _memory_chunks: Dictionary = {}  # layer_name -> { chunk_key -> Array of [cell, source, atlas] }

func _extract_chunks_from_scene() -> void:
	var t0 = Time.get_ticks_msec()
	for layer_name in _all_layers:
		var layer = _all_layers[layer_name] as TileMapLayer
		_memory_chunks[layer_name] = {}
		for cell in layer.get_used_cells():
			var chunk_key = Vector2i(
				int(floor(float(cell.x) / CHUNK_SIZE)),
				int(floor(float(cell.y) / CHUNK_SIZE))
			)
			var key_str = "%d_%d" % [chunk_key.x, chunk_key.y]
			_chunk_keys_set[key_str] = true
			if not _memory_chunks[layer_name].has(chunk_key):
				_memory_chunks[layer_name][chunk_key] = []
			var source = layer.get_cell_source_id(cell)
			var atlas = layer.get_cell_atlas_coords(cell)
			_memory_chunks[layer_name][chunk_key].append([cell, source, atlas])
		layer.clear()
	print("TIMING: Extracted tiles from scene in %d ms (fallback mode)" % (Time.get_ticks_msec() - t0))

func _deferred_init() -> void:
	# Use await to spread heavy work across frames (loading screen stays visible)
	_async_init.call_deferred()

func _async_init() -> void:
	var t0 = Time.get_ticks_msec()
	var player = $Player
	$Bullets.add_to_group("bullets")

	var t1 = Time.get_ticks_msec()
	_spawn_npcs()
	print("TIMING: overworld spawn NPCs took %d ms" % (Time.get_ticks_msec() - t1))
	await get_tree().process_frame

	t1 = Time.get_ticks_msec()
	# Old zone-based enemy spawning disabled — replaced by editor-defined spawn regions
	# _spawn_zone_enemies()
	_spawn_editor_enemies()
	print("TIMING: overworld spawn enemies took %d ms" % (Time.get_ticks_msec() - t1))
	_spawn_equipment_bag()

	# UI overlays
	var dialogue_ui = DialogueUI.new()
	add_child(dialogue_ui)
	var quest_log = QuestLog.new()
	add_child(quest_log)
	var shop_ui = ShopUI.new()
	add_child(shop_ui)

	# Zone gates and HUD
	_create_zone_gates()
	if _current_zone:
		_show_zone_name(_current_zone.zone_name if _current_zone.zone_name != "" else _current_zone.id)
	var qm = get_node_or_null("/root/QuestManager")
	if qm and _current_zone:
		qm.on_zone_entered(_current_zone.id)

	print("TIMING: overworld TOTAL _async_init took %d ms" % (Time.get_ticks_msec() - t0))

	# Hide GameManager loading screen if visible
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("_hide_loading_screen"):
		gm._hide_loading_screen()

func _load_zone_data() -> void:
	var zone_dir = "res://resources/world/zones/"
	var dir = DirAccess.open(zone_dir)
	if not dir:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var zone = load(zone_dir + fname) as LoyZoneData
			if zone:
				zone_data.append(zone)
		fname = dir.get_next()

# _create_dungeon_entrances is now handled per-chunk in _create_chunk_entrances

func _find_zone_for_tile(cell: Vector2i) -> String:
	var zone = _find_zone_data_for_tile(cell)
	if zone:
		return zone.zone_name if zone.zone_name != "" else zone.id
	return "Dungeon"

func _find_zone_data_for_tile(cell: Vector2i) -> LoyZoneData:
	for zone in zone_data:
		if zone.baked_offset == Vector2i(-99999, -99999):
			continue
		var ox = zone.baked_offset.x
		var oy = zone.baked_offset.y
		var s = zone.baked_scale if zone.baked_scale > 0 else 1
		var w = (zone.width if zone.width > 0 else 50) * s
		var h = (zone.height if zone.height > 0 else 50) * s
		if cell.x >= ox and cell.x < ox + w and cell.y >= oy and cell.y < oy + h:
			return zone
	return null

func _find_zone_by_id(zone_id: String) -> LoyZoneData:
	for zone in zone_data:
		if zone.id == zone_id:
			return zone
	return null

func _get_zone_bbox(zone: LoyZoneData) -> Rect2i:
	## Returns tile bounding box for a zone (with corridor margin)
	var s = zone.baked_scale if zone.baked_scale > 0 else 1
	var w = (zone.width if zone.width > 0 else 50) * s
	var h = (zone.height if zone.height > 0 else 50) * s
	var margin = 25  # corridor gap + buffer
	return Rect2i(
		zone.baked_offset.x - margin, zone.baked_offset.y - margin,
		w + margin * 2, h + margin * 2
	)

func _rebuild_allowed_zones() -> void:
	## Rebuild the set of zone IDs whose chunks are allowed to load
	_allowed_zone_ids.clear()
	_zone_bboxes.clear()
	if not _current_zone:
		return
	_allowed_zone_ids.append(_current_zone.id)
	_zone_bboxes[_current_zone.id] = _get_zone_bbox(_current_zone)
	# Add connected zones (via exits)
	for exit_data in _current_zone.exits:
		var target_id = str(exit_data.get("target", ""))
		if target_id == "" or target_id in _allowed_zone_ids:
			continue
		var target_zone = _find_zone_by_id(target_id)
		if target_zone and target_zone.baked_offset != Vector2i(-99999, -99999):
			_allowed_zone_ids.append(target_id)
			_zone_bboxes[target_id] = _get_zone_bbox(target_zone)
	# Also add zones that have exits TO the current zone (reverse connections)
	for zone in zone_data:
		if zone.id in _allowed_zone_ids:
			continue
		if zone.baked_offset == Vector2i(-99999, -99999):
			continue
		for exit_data in zone.exits:
			if str(exit_data.get("target", "")) == _current_zone.id:
				_allowed_zone_ids.append(zone.id)
				_zone_bboxes[zone.id] = _get_zone_bbox(zone)
				break
	print("Zone: %s — allowed zones: %s" % [_current_zone.id, _allowed_zone_ids])
	# Force chunk re-evaluation
	_last_chunk = Vector2i(-9999, -9999)

func _chunk_in_allowed_zones(chunk_key: Vector2i) -> bool:
	## Check if a chunk overlaps any allowed zone bounding box
	if _allowed_zone_ids.is_empty():
		return true  # no zone restriction (fallback)
	var cx = chunk_key.x * CHUNK_SIZE
	var cy = chunk_key.y * CHUNK_SIZE
	var chunk_rect = Rect2i(cx, cy, CHUNK_SIZE, CHUNK_SIZE)
	for zone_id in _allowed_zone_ids:
		if _zone_bboxes.has(zone_id):
			if _zone_bboxes[zone_id].intersects(chunk_rect):
				return true
	return false

func _update_current_zone() -> void:
	var player = get_node_or_null("Player")
	if not player:
		return
	var tile = Vector2i(int(player.position.x / 32), int(player.position.y / 32))
	var zone = _find_zone_data_for_tile(tile)
	if zone and zone != _current_zone:
		var old_zone = _current_zone
		_current_zone = zone
		_rebuild_allowed_zones()
		_create_zone_gates()
		_show_zone_name(zone.zone_name if zone.zone_name != "" else zone.id)
		# Notify quest system
		var qm = get_node_or_null("/root/QuestManager")
		if qm:
			qm.on_zone_entered(zone.id)
		# Unload chunks outside new allowed zones
		for key in _loaded_chunks.keys():
			if not _chunk_in_allowed_zones(key) and key not in _unload_queue:
				_unload_queue.append(key)

func _create_zone_gates() -> void:
	## Remove old gates
	for gate in _zone_gates:
		if is_instance_valid(gate):
			gate.queue_free()
	_zone_gates.clear()
	if not _current_zone:
		return
	var ts = 32
	var half = ts / 2
	var s = _current_zone.baked_scale if _current_zone.baked_scale > 0 else 1
	var ox = _current_zone.baked_offset.x
	var oy = _current_zone.baked_offset.y
	for exit_data in _current_zone.exits:
		var target_id = str(exit_data.get("target", ""))
		var target_zone = _find_zone_by_id(target_id)
		if not target_zone or target_zone.baked_offset == Vector2i(-99999, -99999):
			continue
		# Exit position in world tiles
		var ex = ox + int(exit_data.get("x", 0)) * s
		var ey = oy + int(exit_data.get("y", 0)) * s
		# Target entry position in world tiles
		var tox = target_zone.baked_offset.x
		var toy = target_zone.baked_offset.y
		var ts2 = target_zone.baked_scale if target_zone.baked_scale > 0 else 1
		var tx = tox + int(exit_data.get("tx", 0)) * ts2
		var ty = toy + int(exit_data.get("ty", 0)) * ts2
		# Gate at midpoint of exit→target corridor
		var gate_tile_x = (ex + tx) / 2
		var gate_tile_y = (ey + ty) / 2
		var gate_pos = Vector2(gate_tile_x * ts + half, gate_tile_y * ts + half)
		# Create gate Area2D
		var gate = Area2D.new()
		gate.name = "ZoneGate_%s" % target_id
		gate.position = gate_pos
		gate.collision_layer = 0
		gate.collision_mask = 1  # detect player
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(ts * 4, ts * 4)  # 4x4 tile trigger area
		shape.shape = rect
		gate.add_child(shape)
		gate.set_meta("target_zone_id", target_id)
		gate.body_entered.connect(_on_zone_gate_entered.bind(target_id))
		add_child(gate)
		_zone_gates.append(gate)
	# Also create gates for zones that exit INTO the current zone (reverse)
	for zone in zone_data:
		if zone.id == _current_zone.id or zone.id not in _allowed_zone_ids:
			continue
		if zone.baked_offset == Vector2i(-99999, -99999):
			continue
		var zs = zone.baked_scale if zone.baked_scale > 0 else 1
		for exit_data in zone.exits:
			if str(exit_data.get("target", "")) != _current_zone.id:
				continue
			# This zone's exit that leads to current zone — place gate at midpoint
			var ex2 = zone.baked_offset.x + int(exit_data.get("x", 0)) * zs
			var ey2 = zone.baked_offset.y + int(exit_data.get("y", 0)) * zs
			var tx2 = ox + int(exit_data.get("tx", 0)) * s
			var ty2 = oy + int(exit_data.get("ty", 0)) * s
			var gx = (ex2 + tx2) / 2
			var gy = (ey2 + ty2) / 2
			var gate = Area2D.new()
			gate.name = "ZoneGate_%s" % zone.id
			gate.position = Vector2(gx * ts + half, gy * ts + half)
			gate.collision_layer = 0
			gate.collision_mask = 1
			var shape2 = CollisionShape2D.new()
			var rect2 = RectangleShape2D.new()
			rect2.size = Vector2(ts * 4, ts * 4)
			shape2.shape = rect2
			gate.add_child(shape2)
			gate.set_meta("target_zone_id", zone.id)
			gate.body_entered.connect(_on_zone_gate_entered.bind(zone.id))
			add_child(gate)
			_zone_gates.append(gate)

func _on_zone_gate_entered(body: Node, target_zone_id: String) -> void:
	if not body.is_in_group("player"):
		return
	var target = _find_zone_by_id(target_zone_id)
	if target and target != _current_zone:
		_current_zone = target
		_rebuild_allowed_zones()
		_create_zone_gates()
		_show_zone_name(target.zone_name if target.zone_name != "" else target.id)
		var qm = get_node_or_null("/root/QuestManager")
		if qm:
			qm.on_zone_entered(target.id)
		# Unload out-of-zone chunks
		for key in _loaded_chunks.keys():
			if not _chunk_in_allowed_zones(key) and key not in _unload_queue:
				_unload_queue.append(key)

func _show_zone_name(zone_name: String) -> void:
	if not _zone_label:
		_setup_zone_label()
	if not _zone_label:
		return
	_zone_label.text = zone_name
	_zone_label.modulate.a = 0.0
	_zone_label.visible = true
	if _zone_label_tween and _zone_label_tween.is_valid():
		_zone_label_tween.kill()
	_zone_label_tween = create_tween()
	_zone_label_tween.tween_property(_zone_label, "modulate:a", 1.0, 0.3)
	_zone_label_tween.tween_interval(2.0)
	_zone_label_tween.tween_property(_zone_label, "modulate:a", 0.0, 1.0)

func _setup_zone_label() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "ZoneHUD"
	canvas.layer = 10
	add_child(canvas)
	_zone_label = Label.new()
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_zone_label.anchor_left = 0.5
	_zone_label.anchor_right = 0.5
	_zone_label.anchor_top = 0.1
	_zone_label.anchor_bottom = 0.1
	_zone_label.offset_left = -200
	_zone_label.offset_right = 200
	_zone_label.offset_top = -20
	_zone_label.offset_bottom = 20
	_zone_label.add_theme_font_size_override("font_size", 28)
	_zone_label.add_theme_color_override("font_color", Color.WHITE)
	_zone_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_zone_label.add_theme_constant_override("shadow_offset_x", 2)
	_zone_label.add_theme_constant_override("shadow_offset_y", 2)
	_zone_label.visible = false
	canvas.add_child(_zone_label)

func _add_entrance(pos: Vector2, biome_name: String, tile_size: int = 32, display_name: String = "") -> Array:
	if display_name == "":
		display_name = biome_name
	var nodes: Array = []
	var entrance = Area2D.new()
	entrance.position = pos
	entrance.collision_layer = 0
	entrance.collision_mask = 1
	entrance.set_meta("biome_name", biome_name)
	entrance.set_meta("display_name", display_name)

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(tile_size, tile_size)
	shape.shape = rect
	entrance.add_child(shape)

	# E-key prompt label (hidden until player is nearby)
	var prompt = Label.new()
	prompt.text = "[E] Enter %s" % display_name
	prompt.position = Vector2(-40, -28)
	prompt.add_theme_font_size_override("font_size", 10)
	prompt.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 3)
	prompt.z_index = 10
	prompt.visible = false
	entrance.add_child(prompt)
	entrance.set_meta("prompt_label", prompt)

	entrance.body_entered.connect(_on_entrance_proximity.bind(entrance))
	entrance.body_exited.connect(_on_entrance_left.bind(entrance))
	add_child(entrance)
	nodes.append(entrance)

	var sign_label = _add_zone_sign(pos + Vector2(tile_size, 0), display_name)
	if sign_label:
		nodes.append(sign_label)
	return nodes

func _on_entrance_proximity(body: Node2D, entrance: Area2D) -> void:
	if body.is_in_group("player"):
		_nearby_entrance = entrance
		var prompt = entrance.get_meta("prompt_label") as Label
		if prompt:
			prompt.visible = true

func _on_entrance_left(body: Node2D, entrance: Area2D) -> void:
	if body.is_in_group("player") and _nearby_entrance == entrance:
		var prompt = entrance.get_meta("prompt_label") as Label
		if prompt:
			prompt.visible = false
		_nearby_entrance = null

func _try_inspect_tile() -> void:
	var player = get_node_or_null("Player")
	if not player:
		return
	var pos = player.global_position
	var center = Vector2i(int(floor(pos.x / 32)), int(floor(pos.y / 32)))
	# Scan player cell + neighbors for non-ground tiles
	var best_tile: Dictionary = {}
	var best_dist: float = 999.0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cell = center + Vector2i(dx, dy)
			var cell_center = Vector2(cell.x * 32 + 16, cell.y * 32 + 16)
			var dist = pos.distance_to(cell_center)
			if dist >= best_dist:
				continue
			for layer_name in ["fences", "decorations", "buildings", "water"]:
				var layer = _all_layers[layer_name] as TileMapLayer
				var src = layer.get_cell_source_id(cell)
				if src < 0:
					continue
				var atlas = layer.get_cell_atlas_coords(cell)
				best_dist = dist
				best_tile = {"layer": layer_name, "source": src, "atlas": atlas, "cell": cell}
				break  # take first non-ground layer hit
	if best_tile.is_empty():
		return
	if _tile_inspector:
		var info = TileNames.get_tile_info(best_tile["layer"], best_tile["source"], best_tile["atlas"])
		_tile_inspector.show_info(info["name"], info["desc"])
		get_viewport().set_input_as_handled()

func _add_zone_sign(pos: Vector2, text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.position = pos - Vector2(20, 12)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.z_index = 5
	add_child(label)
	return label

func _spawn_npcs() -> void:
	var ts = 32
	if ground and ground.tile_set:
		ts = ground.tile_set.tile_size.x
	var half = ts / 2

	var npc_count = 0
	for zone in zone_data:
		if zone.baked_offset == Vector2i(-99999, -99999):
			continue
		var ox = zone.baked_offset.x
		var oy = zone.baked_offset.y

		for npc_data in zone.npcs:
			var npc = NPC.new()
			npc.npc_name = str(npc_data.get("name", "NPC"))
			npc.loy_tile = int(npc_data.get("tile", 0))
			npc.npc_type = str(npc_data.get("type", "message"))
			npc.portrait_tile = int(npc_data.get("portrait", npc.loy_tile))
			npc.zone_id = zone.id
			npc.script_file = str(npc_data.get("file", ""))
			npc.shop_id = str(npc_data.get("shop", ""))

			var nx = int(npc_data.get("x", 0))
			var ny = int(npc_data.get("y", 0))
			var s = zone.baked_scale if zone.baked_scale > 0 else 1
			npc.position = Vector2((ox + nx * s) * ts + half, (oy + ny * s) * ts + half)

			var msg = str(npc_data.get("message", ""))
			if msg != "":
				npc.dialogue_text = msg
			elif npc.npc_type == "tips":
				npc.dialogue_text = "I have some advice for you, adventurer."
			elif npc.npc_type == "message":
				npc.dialogue_text = "Greetings, traveler."
			elif npc.npc_type == "shop":
				npc.dialogue_text = "Browse my wares!"

			npc.z_index = 3
			add_child(npc)
			npc_count += 1

func _spawn_zone_enemies() -> void:
	var ts = 32
	if ground and ground.tile_set:
		ts = ground.tile_set.tile_size.x
	var half = ts / 2

	var enemy_scene_path = "res://scenes/enemy.tscn"
	if not ResourceLoader.exists(enemy_scene_path):
		return
	var enemy_scene = load(enemy_scene_path) as PackedScene
	var container = $EnemyContainer

	for zone in zone_data:
		if zone.baked_offset == Vector2i(-99999, -99999):
			continue
		if zone.id in SAFE_ZONES:
			continue

		var ox = zone.baked_offset.x
		var oy = zone.baked_offset.y
		var s = zone.baked_scale if zone.baked_scale > 0 else 1

		for spawn_data in zone.spawns:
			var monster_type = str(spawn_data.get("type", ""))
			var enemy_def = _get_cached_enemy_def(monster_type)
			if not enemy_def:
				continue

			# Store for respawning
			_zone_spawn_data.append({
				"zone_id": zone.id,
				"spawn_data": spawn_data,
				"enemy_def": enemy_def,
				"ox": ox, "oy": oy, "s": s
			})

			var sx = int(spawn_data.get("x", 0))
			var sy = int(spawn_data.get("y", 0))
			var sw = int(spawn_data.get("width", 1))
			var sh = int(spawn_data.get("height", 1))
			var chance = int(spawn_data.get("chance", 50))

			var num_spawns = maxi(1, (sw * sh) / 30)
			for _i in range(num_spawns):
				if randi() % 100 >= chance:
					continue
				_spawn_overworld_enemy(enemy_scene, container, enemy_def, ox, oy, s, sx, sy, sw, sh, ts, half, zone.id)

func _spawn_overworld_enemy(enemy_scene: PackedScene, container: Node, enemy_def: EnemyDefinition, ox: int, oy: int, s: int, sx: int, sy: int, sw: int, sh: int, ts: int, half: int, zone_id: String) -> void:
	var ex = sx + randi() % maxi(1, sw)
	var ey = sy + randi() % maxi(1, sh)
	var pos = Vector2(
		(ox + ex * s) * ts + half,
		(oy + ey * s) * ts + half
	)
	# Don't spawn enemies within 15 tiles of the player spawn
	var spawn_px = Vector2(player_spawn_tile.x * ts + half, player_spawn_tile.y * ts + half)
	if pos.distance_to(spawn_px) < ts * 15:
		return
	var enemy = enemy_scene.instantiate()
	enemy.global_position = pos
	if enemy.has_method("setup"):
		var ow_def = enemy_def.duplicate()
		ow_def.attack_type = EnemyDefinition.AttackType.NONE
		ow_def.move_speed = 15.0
		ow_def.preferred_distance = 0.0
		ow_def.bullet_count = 0
		enemy.setup(ow_def)
	var _enemy_spr = enemy.get_node_or_null("Sprite2D")
	if _enemy_spr:
		_enemy_spr.scale = Vector2(4, 4)
	enemy.set_meta("zone_id", zone_id)
	enemy.set_meta("spawn_pos", pos)
	enemy.set_meta("leash_radius", float(maxi(sw, sh) * s * ts))
	container.add_child(enemy)

func _check_respawns(delta: float) -> void:
	_respawn_timer += delta
	if _respawn_timer < RESPAWN_INTERVAL:
		return
	_respawn_timer = 0.0
	_respawn_editor_enemies()

## ── Editor-defined spawn regions ─────────────────────────────────────────────
## Loaded from res://resources/world/enemy_spawns.tres (created by import pipeline)
## Each region: {name, x1, y1, x2, y2, enemy_type, max_count, behavior, hostile}
## Coordinates are in world tiles.
var _editor_spawn_regions: Array = []
const EDITOR_SPAWN_PATH = "res://resources/world/enemy_spawns.tres"

func _load_editor_spawns() -> void:
	if not ResourceLoader.exists(EDITOR_SPAWN_PATH):
		return
	var res = load(EDITOR_SPAWN_PATH) as Resource
	if not res:
		return
	var regions = res.get_meta("regions", [])
	for r in regions:
		_editor_spawn_regions.append(r)
	print("Loaded %d editor spawn regions" % _editor_spawn_regions.size())

func _spawn_editor_enemies() -> void:
	_load_editor_spawns()
	if _editor_spawn_regions.is_empty():
		return
	var enemy_scene_path = "res://scenes/enemy.tscn"
	if not ResourceLoader.exists(enemy_scene_path):
		return
	var enemy_scene = load(enemy_scene_path) as PackedScene
	var container = $EnemyContainer
	var ts = 32
	var half = ts / 2

	for region in _editor_spawn_regions:
		var enemy_type = str(region.get("enemy_type", "Goblin"))
		var enemy_def = _get_cached_enemy_def(enemy_type)
		if not enemy_def:
			continue
		var max_count = int(region.get("max_count", 3))
		var x1 = int(region.get("x1", 0))
		var y1 = int(region.get("y1", 0))
		var x2 = int(region.get("x2", 0))
		var y2 = int(region.get("y2", 0))
		var hostile = bool(region.get("hostile", true))
		var behavior = str(region.get("behavior", "chase"))  # wander, chase, passive
		var region_name = str(region.get("name", ""))

		var w = maxi(1, x2 - x1)
		var h = maxi(1, y2 - y1)
		var leash = float(maxi(w, h) * ts)

		for _i in range(max_count):
			var ex = x1 + randi() % w
			var ey = y1 + randi() % h
			var pos = Vector2(ex * ts + half, ey * ts + half)
			# Exclusion near player spawn
			var spawn_px = Vector2(player_spawn_tile.x * ts + half, player_spawn_tile.y * ts + half)
			if pos.distance_to(spawn_px) < ts * 10:
				continue
			var enemy = enemy_scene.instantiate()
			enemy.global_position = pos
			if enemy.has_method("setup"):
				var ow_def = enemy_def.duplicate()
				if not hostile or behavior == "passive":
					ow_def.attack_type = EnemyDefinition.AttackType.NONE
				ow_def.move_speed = 20.0 if behavior == "chase" else 10.0
				ow_def.preferred_distance = 0.0
				ow_def.bullet_count = 0
				enemy.setup(ow_def)
			var _enemy_spr = enemy.get_node_or_null("Sprite2D")
			if _enemy_spr:
				_enemy_spr.scale = Vector2(4, 4)
			enemy.set_meta("spawn_region", region_name)
			enemy.set_meta("spawn_pos", pos)
			enemy.set_meta("leash_radius", leash)
			enemy.set_meta("behavior", behavior)
			enemy.set_meta("hostile", hostile)
			# Passive enemies: start non-hostile, become hostile when hit
			if not hostile or behavior == "passive":
				enemy.set_meta("passive_until_hit", true)
			container.add_child(enemy)

func _respawn_editor_enemies() -> void:
	if _editor_spawn_regions.is_empty():
		return
	var container = get_node_or_null("EnemyContainer")
	if not container:
		return
	var player_node = get_tree().get_first_node_in_group("player")
	if not player_node:
		return
	var ts = 32
	var half = ts / 2
	var enemy_scene = load("res://scenes/enemy.tscn") as PackedScene
	if not enemy_scene:
		return

	# Count living enemies per region
	var region_counts: Dictionary = {}
	for child in container.get_children():
		if child is CharacterBody2D and child.has_meta("spawn_region"):
			var rname = child.get_meta("spawn_region")
			region_counts[rname] = region_counts.get(rname, 0) + 1

	for region in _editor_spawn_regions:
		var region_name = str(region.get("name", ""))
		var max_count = int(region.get("max_count", 3))
		var current = region_counts.get(region_name, 0)
		if current >= max_count:
			continue
		# Only respawn if region center is near player
		var x1 = int(region.get("x1", 0))
		var y1 = int(region.get("y1", 0))
		var x2 = int(region.get("x2", 0))
		var y2 = int(region.get("y2", 0))
		var center = Vector2((x1 + x2) / 2.0 * ts, (y1 + y2) / 2.0 * ts)
		if player_node.global_position.distance_to(center) > 3000:
			continue
		var enemy_type = str(region.get("enemy_type", "Goblin"))
		var enemy_def = _get_cached_enemy_def(enemy_type)
		if not enemy_def:
			continue
		var hostile = bool(region.get("hostile", true))
		var behavior = str(region.get("behavior", "chase"))
		var w = maxi(1, x2 - x1)
		var h = maxi(1, y2 - y1)
		var leash = float(maxi(w, h) * ts)
		# Spawn one per cycle
		var ex = x1 + randi() % w
		var ey = y1 + randi() % h
		var pos = Vector2(ex * ts + half, ey * ts + half)
		var enemy = enemy_scene.instantiate()
		enemy.global_position = pos
		if enemy.has_method("setup"):
			var ow_def = enemy_def.duplicate()
			if not hostile or behavior == "passive":
				ow_def.attack_type = EnemyDefinition.AttackType.NONE
			ow_def.move_speed = 20.0 if behavior == "chase" else 10.0
			ow_def.preferred_distance = 0.0
			ow_def.bullet_count = 0
			enemy.setup(ow_def)
		var _enemy_spr = enemy.get_node_or_null("Sprite2D")
		if _enemy_spr:
			_enemy_spr.scale = Vector2(4, 4)
		enemy.set_meta("spawn_region", region_name)
		enemy.set_meta("spawn_pos", pos)
		enemy.set_meta("leash_radius", leash)
		enemy.set_meta("behavior", behavior)
		enemy.set_meta("hostile", hostile)
		if not hostile or behavior == "passive":
			enemy.set_meta("passive_until_hit", true)
		container.add_child(enemy)

func _get_cached_enemy_def(monster_type: String) -> EnemyDefinition:
	if _enemy_def_cache.has(monster_type):
		return _enemy_def_cache[monster_type]
	var def_path = _get_enemy_def_path(monster_type)
	if def_path == "" or not ResourceLoader.exists(def_path):
		_enemy_def_cache[monster_type] = null
		return null
	var def = load(def_path) as EnemyDefinition
	_enemy_def_cache[monster_type] = def
	return def

func _spawn_equipment_bag() -> void:
	var bag_scene = preload("res://scenes/objects/equipment_bag.tscn")
	var bag = bag_scene.instantiate()
	bag.position = Vector2(player_spawn_tile.x * 32 + 16, player_spawn_tile.y * 32 + 16)
	add_child(bag)

## Safe zones where no enemies should spawn (towns, settlements, etc.)
const SAFE_ZONES: Array = [
	"aria", "farm", "camp", "sthel", "heim", "gomb", "nord1", "tor1", "tor2",
	"tor4", "tor5", "tor6", "paititi", "thule", "shrine", "cennyn", "naleg",
	"kor", "talmita", "talnivek", "airlon", "ynys", "bch1", "blf1", "cel1",
	"crt1", "end1", "pst1", "llecudd", "willows", "tempid",
]

func _get_enemy_def_path(monster_name: String) -> String:
	var name_map: Dictionary = {
		"Skeleton": "res://resources/enemies/loy/undead/skeleton.tres",
		"Ghost": "res://resources/enemies/loy/undead/ghost.tres",
		"Goblin": "res://resources/enemies/loy/orc/goblin.tres",
		"Kobold": "res://resources/enemies/loy/orc/kobold.tres",
		"Spider": "res://resources/enemies/loy/crawler/spider.tres",
		"Blob": "res://resources/enemies/loy/crawler/blob.tres",
		"Cobra": "res://resources/enemies/loy/crawler/cobra.tres",
		"Scorpion": "res://resources/enemies/loy/crawler/scorpion.tres",
		"Wild Dog": "res://resources/enemies/loy/animal/wild_dog.tres",
		"Bear": "res://resources/enemies/loy/animal/bear.tres",
		"Imp": "res://resources/enemies/loy/demon/imp.tres",
		"Thief": "res://resources/enemies/loy/human/thief.tres",
		"Bandit": "res://resources/enemies/loy/human/bandit.tres",
		"Orc": "res://resources/enemies/loy/orc/orc.tres",
		"Ogre": "res://resources/enemies/loy/orc/ogre.tres",
		"Devil": "res://resources/enemies/loy/demon/devil.tres",
		"Dragon": "res://resources/enemies/loy/animal/dragon.tres",
		"Creeper": "res://resources/enemies/loy/crawler/creeper.tres",
		"Cyclops": "res://resources/enemies/loy/orc/cyclops.tres",
		"Dark Lord": "res://resources/enemies/loy/undead/dark_lord.tres",
		"Rock Troll": "res://resources/enemies/loy/orc/rock_troll.tres",
		"Mummy": "res://resources/enemies/loy/undead/mummy.tres",
		"Widow": "res://resources/enemies/loy/crawler/widow.tres",
		"Vampire": "res://resources/enemies/loy/undead/vampire.tres",
		"Spectre": "res://resources/enemies/loy/undead/spectre.tres",
		"Liche": "res://resources/enemies/loy/undead/liche.tres",
		"Minotaur": "res://resources/enemies/loy/orc/minotaur.tres",
		"Centaur": "res://resources/enemies/loy/magical/centaur.tres",
		"Medusa": "res://resources/enemies/loy/magical/medusa.tres",
		"Hydra": "res://resources/enemies/loy/magical/hydra.tres",
		"Beholder": "res://resources/enemies/loy/crawler/beholder.tres",
		"Black Knight": "res://resources/enemies/loy/human/black_knight.tres",
		"Fire Elemental": "res://resources/enemies/loy/demon/fire_elemental.tres",
		"Ice Elemental": "res://resources/enemies/loy/demon/ice_elemental.tres",
		"Genie": "res://resources/enemies/loy/magical/genie.tres",
		"Fire Ifrit": "res://resources/enemies/loy/demon/fire_elemental.tres",
		"Frost Ifrit": "res://resources/enemies/loy/demon/ice_elemental.tres",
		"Silver Ifrit": "res://resources/enemies/loy/demon/fire_elemental.tres",
		"Frost Skull": "res://resources/enemies/loy/undead/skeleton.tres",
		"Zombini": "res://resources/enemies/loy/undead/skeleton.tres",
		"Zomboid": "res://resources/enemies/loy/undead/mummy.tres",
		"Night Goblin": "res://resources/enemies/loy/orc/goblin.tres",
		"Imp Warrior": "res://resources/enemies/loy/demon/imp.tres",
		"Imp Witch": "res://resources/enemies/loy/demon/imp.tres",
		"Robber": "res://resources/enemies/loy/human/thief.tres",
		"Wolf Rider": "res://resources/enemies/loy/orc/orc.tres",
		"Dingo": "res://resources/enemies/loy/animal/wild_dog.tres",
		"Wild Boar": "res://resources/enemies/loy/animal/bear.tres",
		"Lion": "res://resources/enemies/loy/animal/bear.tres",
		"Tiger": "res://resources/enemies/loy/animal/bear.tres",
		"Polar Bear": "res://resources/enemies/loy/animal/bear.tres",
		"Rhino": "res://resources/enemies/loy/animal/bear.tres",
		"Squib": "res://resources/enemies/loy/crawler/blob.tres",
		"Enderman": "res://resources/enemies/loy/demon/devil.tres",
		"Faca": "res://resources/enemies/loy/orc/ogre.tres",
		"Cannibal": "res://resources/enemies/loy/human/bandit.tres",
		"Water Elemental": "res://resources/enemies/loy/demon/ice_elemental.tres",
	}
	return name_map.get(monster_name, "")

# Collisions and entrances are now generated per-chunk in _generate_chunk_collisions / _create_chunk_entrances

func _add_merged_shape(body: StaticBody2D, x_start: int, x_end: int, y: int, tile_size: int, half: int) -> CollisionShape2D:
	var run_len = x_end - x_start + 1
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(tile_size * run_len, tile_size)
	shape.shape = rect
	shape.position = Vector2(
		x_start * tile_size + (tile_size * run_len) / 2.0,
		y * tile_size + half
	)
	body.add_child(shape)
	return shape

func _is_door_tile(atlas: Vector2i, tile_size: int) -> bool:
	if tile_size == 32:
		return (atlas.x == 2 or atlas.x == 3) and atlas.y <= 7
	return atlas.y == 23 and atlas.x <= 9

func _is_stairs_tile(atlas: Vector2i, tile_size: int) -> bool:
	if tile_size == 32:
		return atlas.x == 5 and atlas.y <= 7
	return false


var _nearby_door: Area2D = null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		# Priority 0: Close tile inspector if open
		if _tile_inspector and _tile_inspector.is_open():
			_tile_inspector.hide_info()
			get_viewport().set_input_as_handled()
			return
		# Priority 1: Dungeon entrance
		if _nearby_entrance:
			var biome_name = _nearby_entrance.get_meta("biome_name", "Dungeon") as String
			var gm = get_node_or_null("/root/GameManager")
			if gm:
				gm.start_dungeon_run(biome_name)
			get_viewport().set_input_as_handled()
			return
		# Priority 2: Door interaction
		_try_open_door()
		# Priority 3: Tile inspection (handled after NPC gets a chance via _unhandled_input order)
		if not get_viewport().is_input_handled():
			_try_inspect_tile()
	# DEBUG: Press F9 to print tile/collision info at player position
	if event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		var player = get_node_or_null("Player")
		if not player:
			return
		var pos = player.global_position
		var cell = Vector2i(int(floor(pos.x / 32)), int(floor(pos.y / 32)))
		var ck = Vector2i(int(floor(float(cell.x) / CHUNK_SIZE)), int(floor(float(cell.y) / CHUNK_SIZE)))
		print("=== DEBUG F9: player pos=%s cell=%s chunk=%s ===" % [pos, cell, ck])
		for layer_name in _layer_names:
			var layer = _all_layers[layer_name] as TileMapLayer
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var c = cell + Vector2i(dx, dy)
					var src = layer.get_cell_source_id(c)
					if src >= 0:
						var atlas = layer.get_cell_atlas_coords(c)
						print("  %s cell=%s src=%d atlas=%s" % [layer_name, c, src, atlas])
		var space = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = pos
		query.collision_mask = 16
		var results = space.intersect_point(query, 10)
		print("  Physics point query hits at player pos: %d" % results.size())
		for r in results:
			var body = r["collider"]
			print("    hit: %s layer=%d rid=%s" % [body.name, body.collision_layer, r["rid"]])
		# Also check nearby cells for shapes
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var test_cell = cell + Vector2i(dx, dy)
				var test_pos = Vector2(test_cell.x * 32 + 16, test_cell.y * 32 + 16)
				var q2 = PhysicsPointQueryParameters2D.new()
				q2.position = test_pos
				q2.collision_mask = 16
				var r2 = space.intersect_point(q2, 5)
				if r2.size() > 0:
					print("  SHAPE at cell=%s pos=%s hits=%d" % [test_cell, test_pos, r2.size()])
		# Check wall_body state
		print("  wall_body: children=%d enabled=%s in_tree=%s layer=%d pos=%s scale=%s" % [_wall_body.get_child_count(), not _wall_body.process_mode == Node.PROCESS_MODE_DISABLED, _wall_body.is_inside_tree(), _wall_body.collision_layer, _wall_body.global_position, _wall_body.scale])
		# Check player state
		print("  player: scale=%s col_layer=%d col_mask=%d pos=%s" % [player.scale, player.collision_layer, player.collision_mask, player.global_position])
		var col_shape = player.get_node_or_null("CollisionShape2D")
		if col_shape:
			print("  player col_shape: disabled=%s shape=%s" % [col_shape.disabled, col_shape.shape])
			if col_shape.shape is RectangleShape2D:
				print("  player shape size=%s" % col_shape.shape.size)
		# Test move_and_slide collision detection
		print("  player.get_slide_collision_count()=%d" % player.get_slide_collision_count())
		# Try a test_move to see if physics detects walls
		for dir in [Vector2(32, 0), Vector2(-32, 0), Vector2(0, 32), Vector2(0, -32)]:
			var can_collide = player.test_move(player.global_transform, dir)
			if can_collide:
				print("  test_move dir=%s WOULD COLLIDE" % dir)

	# DEBUG: Press F10 to toggle visible collision shapes
	if event is InputEventKey and event.pressed and event.keycode == KEY_F10:
		get_tree().debug_collisions_hint = not get_tree().debug_collisions_hint
		print("DEBUG: Collision shapes visible = %s" % get_tree().debug_collisions_hint)

	# DEBUG: Press F11 to write full debug to file and show tile labels
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		_debug_write_full_report()

	# DEBUG: Press T to toggle on-screen tile labels
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		_debug_tile_labels_visible = not _debug_tile_labels_visible
		if not _debug_tile_labels_visible:
			_debug_clear_labels()
		print("DEBUG: Tile labels = %s" % _debug_tile_labels_visible)

var _debug_tile_labels_visible: bool = false
var _debug_labels: Array = []
var _debug_blocking_cells: Dictionary = {}  # cell -> true for all blocking cells

func _debug_clear_labels() -> void:
	for lbl in _debug_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	_debug_labels.clear()

func _debug_write_full_report() -> void:
	var player = get_node_or_null("Player")
	if not player:
		return
	var pos = player.global_position
	var cell = Vector2i(int(floor(pos.x / 32)), int(floor(pos.y / 32)))

	var lines: Array = []
	lines.append("=== FULL DEBUG REPORT ===")
	lines.append("player pos=%s cell=%s scale=%s" % [pos, cell, player.scale])
	lines.append("player col_layer=%d col_mask=%d" % [player.collision_layer, player.collision_mask])
	var cs = player.get_node_or_null("CollisionShape2D")
	if cs:
		lines.append("player shape=%s disabled=%s" % [cs.shape, cs.disabled])
		if cs.shape is RectangleShape2D:
			lines.append("player shape size=%s" % cs.shape.size)

	lines.append("wall_body children=%d layer=%d pos=%s scale=%s in_tree=%s" % [
		_wall_body.get_child_count(), _wall_body.collision_layer,
		_wall_body.global_position, _wall_body.scale, _wall_body.is_inside_tree()])

	# Check tiles in 5x5 area around player
	lines.append("")
	lines.append("--- TILES AROUND PLAYER ---")
	for layer_name in _layer_names:
		var layer = _all_layers[layer_name] as TileMapLayer
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var c = cell + Vector2i(dx, dy)
				var src = layer.get_cell_source_id(c)
				if src >= 0:
					var atlas = layer.get_cell_atlas_coords(c)
					lines.append("%s cell=%s src=%d atlas=%s" % [layer_name, c, src, atlas])

	# Check collision shapes in area
	lines.append("")
	lines.append("--- COLLISION SHAPES AROUND PLAYER ---")
	var space = get_world_2d().direct_space_state
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var test_cell = cell + Vector2i(dx, dy)
			var test_pos = Vector2(test_cell.x * 32 + 16, test_cell.y * 32 + 16)
			var q = PhysicsPointQueryParameters2D.new()
			q.position = test_pos
			q.collision_mask = 0xFFFFFFFF  # check ALL layers
			var results = space.intersect_point(q, 5)
			if results.size() > 0:
				for r in results:
					lines.append("SHAPE cell=%s pos=%s body=%s layer=%d" % [test_cell, test_pos, r["collider"].name, r["collider"].collision_layer])

	# Test move in all directions
	lines.append("")
	lines.append("--- TEST_MOVE ---")
	for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		for dist in [16, 32, 64]:
			var can = player.test_move(player.global_transform, dir * dist)
			if can:
				lines.append("test_move dir=%s dist=%d COLLIDES" % [dir, dist])

	lines.append("")
	lines.append("slide_collisions=%d" % player.get_slide_collision_count())

	# Write to file
	var f = FileAccess.open("user://debug_collision.txt", FileAccess.WRITE)
	for line in lines:
		f.store_line(line)
		print(line)
	f.close()
	print("=== Debug written to user://debug_collision.txt ===")

func _debug_update_labels() -> void:
	_debug_clear_labels()
	var player = get_node_or_null("Player")
	if not player:
		return
	var pos = player.global_position
	var cell = Vector2i(int(floor(pos.x / 32)), int(floor(pos.y / 32)))

	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var c = cell + Vector2i(dx, dy)
			var has_collision = _debug_blocking_cells.has(c)
			var parts: Array = []
			# Check all layers at this cell
			for layer_name in ["ground", "fences", "decorations", "buildings", "water", "paths"]:
				var layer = _all_layers[layer_name] as TileMapLayer
				var src = layer.get_cell_source_id(c)
				if src < 0:
					continue
				var atlas = layer.get_cell_atlas_coords(c)
				var short_name = layer_name.left(3)
				parts.append("%s:s%d(%d,%d)" % [short_name, src, atlas.x, atlas.y])
			if parts.is_empty() and not has_collision:
				continue
			var lbl = Label.new()
			# Show only non-ground layers to reduce clutter, or [WALL] marker
			var display_parts: Array = []
			for p in parts:
				if not p.begins_with("gro:"):
					display_parts.append(p)
			var text = "\n".join(display_parts)
			if has_collision:
				text = "[WALL]\n" + text if text != "" else "[WALL]"
			if text == "":
				continue
			lbl.text = text
			lbl.add_theme_font_size_override("font_size", 14)
			if has_collision:
				lbl.add_theme_color_override("font_color", Color.RED)
			else:
				lbl.add_theme_color_override("font_color", Color.YELLOW)
			lbl.add_theme_color_override("font_outline_color", Color.BLACK)
			lbl.add_theme_constant_override("outline_size", 4)
			lbl.global_position = Vector2(c.x * 32 + 1, c.y * 32 + 1)
			lbl.z_index = 100
			add_child(lbl)
			_debug_labels.append(lbl)

func _try_open_door() -> void:
	var player_node = get_node_or_null("Player")
	if not player_node:
		return
	var ppos = player_node.global_position
	var ts = 32
	if ground and ground.tile_set:
		ts = ground.tile_set.tile_size.x

	var best_dist = ts * 2.0
	var best_area: Area2D = null
	for area in _door_areas:
		var dist = ppos.distance_to(area.global_position)
		if dist < best_dist:
			best_dist = dist
			best_area = area

	if best_area:
		var cell = best_area.get_meta("door_cell") as Vector2i
		_open_door(cell, best_area)

func _open_door(cell: Vector2i, area: Area2D) -> void:
	if _door_shapes.has(cell):
		var shape = _door_shapes[cell]
		if is_instance_valid(shape):
			shape.queue_free()
		_door_shapes.erase(cell)

	var atlas = buildings.get_cell_atlas_coords(cell)
	if atlas.x == 2:
		buildings.set_cell(cell, 0, Vector2i(3, atlas.y))

	_door_areas.erase(area)
	area.queue_free()

var _game_hud: GameHUD

func _setup_game_hud(player_node: CharacterBody2D) -> void:
	_game_hud = GameHUD.new()
	add_child(_game_hud)
	_game_hud.setup(player_node)
	player_node.player_died.connect(_on_player_died)
	_update_gold_label()

	# Loot bag UI
	var loot_ui = LootBagUI.new()
	add_child(loot_ui)
	loot_ui.setup(player_node.equipment_manager)

	# Tile inspector popup
	_tile_inspector = TileInspector.new()
	add_child(_tile_inspector)

func _on_player_died() -> void:
	var player_node = get_node_or_null("Player")
	if player_node:
		# Drop all equipment — fresh start
		player_node.equipment_manager.equipped.clear()
		player_node.equipment_manager.inventory.clear()
		player_node.equipment_manager.stats_changed.emit()
		player_node.equipment_manager.inventory_changed.emit()

		# Give fresh starting items
		player_node._give_starting_items()

		# Reset HP/MP to new max
		player_node.max_hp = player_node.equipment_manager.get_max_hp()
		player_node.hp = player_node.max_hp
		player_node.max_mp = player_node.equipment_manager.get_max_mp()
		player_node.mp = player_node.max_mp
		player_node.hp_changed.emit(player_node.hp)
		player_node.mp_changed.emit(player_node.mp)

		# Reset level
		player_node.level_system.level = 1
		player_node.level_system.xp = 0
		player_node.level_system.unspent_stat_points = 0
		player_node.level_system.allocated.clear()
		player_node.xp_changed.emit(0, player_node.level_system.xp_to_next_level())

		# Save cleared state
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.save_equipment(player_node.equipment_manager)
			gm.save_level_data(player_node.level_system)

		# Teleport to spawn point
		player_node.global_position = Vector2(player_spawn_tile.x * 32 + 16, player_spawn_tile.y * 32 + 16)
		player_node.invincible = true
		var tween = create_tween()
		for i in range(8):
			tween.tween_property(player_node.sprite, "modulate:a", 0.2, 0.1)
			tween.tween_property(player_node.sprite, "modulate:a", 1.0, 0.1)
		tween.tween_callback(func(): player_node.invincible = false)

func _update_gold_label() -> void:
	if not _game_hud:
		return
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.save_data:
		_game_hud.set_gold(gm.save_data.gold)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_gold_label()
	_poll_async_loads()
	_update_current_zone()
	_update_chunks()
	_drain_unload_queue()
	_process_ready_chunks()
	_drain_tile_queue()
	_check_respawns(_delta)
	if _debug_tile_labels_visible:
		_debug_update_labels()

func _drain_unload_queue() -> void:
	# Unload max 2 chunks per frame to avoid stutters
	var count = 0
	while count < 2 and not _unload_queue.is_empty():
		var key = _unload_queue.pop_front()
		if _loaded_chunks.has(key):
			_unload_chunk(key)
			count += 1

func _update_chunks() -> void:
	var player = get_node_or_null("Player")
	if not player:
		return
	var tile_pos = Vector2i(int(player.position.x / 32), int(player.position.y / 32))
	var chunk = Vector2i(
		int(floor(float(tile_pos.x) / CHUNK_SIZE)),
		int(floor(float(tile_pos.y) / CHUNK_SIZE))
	)
	if chunk == _last_chunk:
		return
	_last_chunk = chunk
	_load_chunks_around(chunk)

func _load_chunks_around(center: Vector2i) -> void:
	var needed: Dictionary = {}
	for dy in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var key = Vector2i(center.x + dx, center.y + dy)
			# Zone filter: only load chunks in allowed zones
			if _chunk_in_allowed_zones(key):
				needed[key] = true

	# Queue chunks for incremental unloading (not all at once)
	for key in _loaded_chunks:
		if not needed.has(key) and not key in _unload_queue:
			_unload_queue.append(key)

	# Cancel queued tiles for chunks no longer needed
	_tile_queue = _tile_queue.filter(func(item): return needed.has(item["chunk_key"]))

	# Request async loading for needed chunks (no blocking!)
	for key in needed:
		if not _loaded_chunks.has(key):
			var key_str = "%d_%d" % [key.x, key.y]
			if _chunk_keys_set.has(key_str):
				_request_chunk_load(key_str)

	# Prefetch chunks beyond load radius (also zone-filtered)
	_prefetch_chunks(center)

## Check if any async-loaded chunks are ready and queue them for tile painting
func _process_ready_chunks() -> void:
	if not _use_file_chunks:
		return
	var needed: Dictionary = {}
	for dy in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			needed[Vector2i(_last_chunk.x + dx, _last_chunk.y + dy)] = true

	for key in needed:
		if _loaded_chunks.has(key):
			continue
		# Check if already in tile queue
		var already_queued = false
		for item in _tile_queue:
			if item["chunk_key"] == key:
				already_queued = true
				break
		if already_queued:
			continue

		var key_str = "%d_%d" % [key.x, key.y]
		if not _chunk_keys_set.has(key_str):
			continue

		if not _use_file_chunks:
			_load_chunk_from_memory(key)
			continue

		var chunk_res = _get_chunk_resource(key_str)
		if not chunk_res:
			# Resource not loaded yet — request was already sent, just wait
			continue

		_queue_chunk_from_resource(key, chunk_res)

func _queue_chunk_from_resource(chunk_key: Vector2i, chunk_res: Resource) -> void:
	# Build a flat list of tile operations for this chunk
	var ops: Array = []
	for layer_name in _layer_names:
		var arr = chunk_res.get_meta(layer_name, PackedInt32Array()) as PackedInt32Array
		for i in range(0, arr.size(), 5):
			ops.append([layer_name, arr[i], arr[i+1], arr[i+2], arr[i+3], arr[i+4]])

	if ops.is_empty():
		return

	var chunk_info = {"cells": {}, "tile_data": {}, "shapes": [], "entrances": []}
	_loaded_chunks[chunk_key] = chunk_info

	_tile_queue.append({
		"chunk_key": chunk_key,
		"ops": ops,
		"idx": 0,
		"chunk_res": chunk_res,
	})

## Prefetch chunks in a ring beyond LOAD_RADIUS (async, no stall)
func _prefetch_chunks(center: Vector2i) -> void:
	if not _use_file_chunks:
		return
	for dy in range(-PREFETCH_RADIUS, PREFETCH_RADIUS + 1):
		for dx in range(-PREFETCH_RADIUS, PREFETCH_RADIUS + 1):
			if abs(dx) <= LOAD_RADIUS and abs(dy) <= LOAD_RADIUS:
				continue
			var key = Vector2i(center.x + dx, center.y + dy)
			if not _chunk_in_allowed_zones(key):
				continue
			var key_str = "%d_%d" % [key.x, key.y]
			if _chunk_keys_set.has(key_str):
				_request_chunk_load(key_str)

func _drain_tile_queue() -> void:
	if _tile_queue.is_empty():
		return

	var budget = TILES_PER_FRAME
	while budget > 0 and not _tile_queue.is_empty():
		var item = _tile_queue[0]
		var ops = item["ops"] as Array
		var idx = item["idx"] as int
		var chunk_key = item["chunk_key"] as Vector2i
		var chunk_info = _loaded_chunks.get(chunk_key)
		if not chunk_info:
			_tile_queue.pop_front()
			continue

		var end = mini(idx + budget, ops.size())
		for i in range(idx, end):
			var op = ops[i]
			var layer_name = op[0] as String
			var cell = Vector2i(op[1], op[2])
			var source = op[3] as int
			var atlas = Vector2i(op[4], op[5])
			var layer = _all_layers[layer_name] as TileMapLayer
			layer.set_cell(cell, source, atlas)
			if not chunk_info["cells"].has(layer_name):
				chunk_info["cells"][layer_name] = []
			chunk_info["cells"][layer_name].append(cell)
			if not chunk_info["tile_data"].has(layer_name):
				chunk_info["tile_data"][layer_name] = {}
			chunk_info["tile_data"][layer_name][cell] = [source, atlas]

		budget -= (end - idx)
		item["idx"] = end

		if end >= ops.size():
			# Chunk fully loaded — generate collisions and entrances
			_tile_queue.pop_front()
			if _wall_body:
				_generate_chunk_collisions(chunk_key, chunk_info)
				var chunk_res = item.get("chunk_res") as Resource
				if chunk_res:
					_create_chunk_entrances(chunk_key, chunk_res, chunk_info)
				else:
					_create_chunk_entrances_from_layer(chunk_key, chunk_info)
			# Only finish one chunk per frame to avoid stacking collision gen
			break

## Load a chunk all at once (used for initial spawn — no queueing)
func _load_chunk_immediate(chunk_key: Vector2i) -> void:
	var key_str = "%d_%d" % [chunk_key.x, chunk_key.y]
	if not _chunk_keys_set.has(key_str):
		return

	var chunk_res: Resource = null
	var chunk_info = {"cells": {}, "tile_data": {}, "shapes": [], "entrances": []}

	if _use_file_chunks:
		chunk_res = _load_chunk_resource_sync(key_str)
		if not chunk_res:
			return
		for layer_name in _layer_names:
			var arr = chunk_res.get_meta(layer_name, PackedInt32Array()) as PackedInt32Array
			if arr.size() == 0:
				continue
			var layer = _all_layers[layer_name] as TileMapLayer
			var cells_list: Array = []
			var td: Dictionary = {}
			for i in range(0, arr.size(), 5):
				var cell = Vector2i(arr[i], arr[i + 1])
				var source = arr[i + 2]
				var atlas = Vector2i(arr[i + 3], arr[i + 4])
				layer.set_cell(cell, source, atlas)
				cells_list.append(cell)
				td[cell] = [source, atlas]
			chunk_info["cells"][layer_name] = cells_list
			chunk_info["tile_data"][layer_name] = td
	else:
		_load_chunk_from_memory_into(chunk_key, chunk_info)

	_loaded_chunks[chunk_key] = chunk_info
	if _wall_body:
		_generate_chunk_collisions(chunk_key, chunk_info)
		if chunk_res:
			_create_chunk_entrances(chunk_key, chunk_res, chunk_info)
		else:
			_create_chunk_entrances_from_layer(chunk_key, chunk_info)

func _load_chunk_from_memory(chunk_key: Vector2i) -> void:
	var chunk_info = {"cells": {}, "tile_data": {}, "shapes": [], "entrances": []}
	_load_chunk_from_memory_into(chunk_key, chunk_info)
	_loaded_chunks[chunk_key] = chunk_info
	if _wall_body:
		_generate_chunk_collisions(chunk_key, chunk_info)
		_create_chunk_entrances_from_layer(chunk_key, chunk_info)

func _load_chunk_from_memory_into(chunk_key: Vector2i, chunk_info: Dictionary) -> void:
	for layer_name in _layer_names:
		var mem_data = _memory_chunks.get(layer_name, {})
		var tile_list = mem_data.get(chunk_key, []) as Array
		if tile_list.size() == 0:
			continue
		var layer = _all_layers[layer_name] as TileMapLayer
		var cells_list: Array = []
		var td: Dictionary = {}
		for tile_info in tile_list:
			layer.set_cell(tile_info[0], tile_info[1], tile_info[2])
			cells_list.append(tile_info[0])
			td[tile_info[0]] = [tile_info[1], tile_info[2]]
		chunk_info["cells"][layer_name] = cells_list
		chunk_info["tile_data"][layer_name] = td

func _unload_chunk(chunk_key: Vector2i) -> void:
	var chunk_info = _loaded_chunks.get(chunk_key)
	if not chunk_info:
		return
	_loaded_chunks.erase(chunk_key)

	# Remove debug blocking cells for this chunk
	var chunk_blocking = chunk_info.get("blocking_cells", []) as Array
	for cell in chunk_blocking:
		_debug_blocking_cells.erase(cell)

	# Erase tile cells
	var cells_dict = chunk_info.get("cells", {}) as Dictionary
	for layer_name in cells_dict:
		var layer = _all_layers.get(layer_name) as TileMapLayer
		if layer:
			for cell in cells_dict[layer_name]:
				layer.erase_cell(cell)

	# Remove collision shapes
	for shape in chunk_info.get("shapes", []):
		if is_instance_valid(shape):
			shape.queue_free()

	# Remove entrance areas and signs
	for node in chunk_info.get("entrances", []):
		if is_instance_valid(node):
			node.queue_free()
			# Also remove from _door_areas if present
			if node is Area2D and node in _door_areas:
				_door_areas.erase(node)

func _is_blocking_tile(layer_name: String, source: int, atlas: Vector2i) -> bool:
	## Returns true if this tile should generate collision.
	## Buildings/fences layers are walls & barriers — block by default.
	## Only specific decorative/object sources are walkable.
	if layer_name == "water":
		return true
	if layer_name == "buildings":
		# Source 3/4 (lofi_obj, lofi_obj_packB) = placed objects — walkable
		if source == 3 or source == 4:
			return false
		# All other buildings tiles (source 0 walls, roofs, etc.) block
		return true
	if layer_name == "fences":
		if source == 0:
			# Row 8 = flags/banners — decorative, walkable
			if atlas.y == 8:
				return false
			# Everything else (walls, fences, trees) blocks
			return true
	# Decorations layer = walkable scatter (flowers, grass) — never blocks
	return false

func _generate_chunk_collisions(chunk_key: Vector2i, chunk_info: Dictionary) -> void:
	var tile_size = 32
	var half = tile_size / 2
	var blocking_set: Dictionary = {}
	var door_set: Dictionary = {}

	# Build blocking set from tile layers (read directly from TileMapLayer)
	for layer_name in ["decorations", "buildings", "fences", "water"]:
		var cells = chunk_info["cells"].get(layer_name, []) as Array
		var layer = _all_layers[layer_name] as TileMapLayer
		for cell in cells:
			var source = layer.get_cell_source_id(cell)
			if source < 0:
				continue
			var atlas = layer.get_cell_atlas_coords(cell)
			if _is_stairs_tile(atlas, tile_size):
				continue
			if not _is_blocking_tile(layer_name, source, atlas):
				continue
			blocking_set[cell] = true
			if _is_door_tile(atlas, tile_size):
				door_set[cell] = true

	# Void border tiles (ground edge detection)
	var ground_cells = chunk_info["cells"].get("ground", []) as Array
	var ground_layer = _all_layers["ground"] as TileMapLayer
	var walkable_set: Dictionary = {}
	var void_cells: Array = []
	for cell in ground_cells:
		var source = ground_layer.get_cell_source_id(cell)
		if source >= 0:
			# All ground sources are walkable (0=maptiles, 1=lofiEnv, 5=tiles, 6=tiles2)
			walkable_set[cell] = true
		else:
			void_cells.append(cell)

	for cell in void_cells:
		for offset in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			if walkable_set.has(cell + offset):
				blocking_set[cell] = true
				break

	# Store blocking cells for debug overlay and cleanup
	var blocking_list: Array = []
	for cell in blocking_set:
		_debug_blocking_cells[cell] = true
		blocking_list.append(cell)
	chunk_info["blocking_cells"] = blocking_list

	# Door cells get individual shapes
	for cell in door_set:
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(tile_size, tile_size)
		shape.shape = rect
		shape.position = Vector2(cell.x * tile_size + half, cell.y * tile_size + half)
		_wall_body.add_child(shape)
		_door_shapes[cell] = shape
		chunk_info["shapes"].append(shape)
		blocking_set.erase(cell)

		# Door interaction area
		var area = Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 1
		area.monitoring = true
		area.position = Vector2(cell.x * tile_size + half, cell.y * tile_size + half)
		area.set_meta("door_cell", cell)
		var ashape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = float(tile_size) * 1.5
		ashape.shape = circle
		area.add_child(ashape)
		add_child(area)
		_door_areas.append(area)
		chunk_info["entrances"].append(area)

	# Row-merge remaining blocking cells
	var rows: Dictionary = {}
	for cell in blocking_set:
		if not rows.has(cell.y):
			rows[cell.y] = []
		rows[cell.y].append(cell.x)

	for y in rows:
		var xs: Array = rows[y]
		xs.sort()
		var run_start: int = xs[0]
		var run_end: int = xs[0]
		for i in range(1, xs.size()):
			if xs[i] == run_end + 1:
				run_end = xs[i]
			else:
				var s = _add_merged_shape(_wall_body, run_start, run_end, y, tile_size, half)
				chunk_info["shapes"].append(s)
				run_start = xs[i]
				run_end = xs[i]
		var s = _add_merged_shape(_wall_body, run_start, run_end, y, tile_size, half)
		chunk_info["shapes"].append(s)

func _create_chunk_entrances(chunk_key: Vector2i, chunk_res: Resource, chunk_info: Dictionary) -> void:
	var tile_size = 32
	var half = tile_size / 2
	var buildings_arr = chunk_res.get_meta("buildings", PackedInt32Array()) as PackedInt32Array

	for i in range(0, buildings_arr.size(), 5):
		var atlas_x = buildings_arr[i + 3]
		if atlas_x == 5:  # stairs tile
			var cell = Vector2i(buildings_arr[i], buildings_arr[i + 1])
			var pixel_pos = Vector2(cell.x * tile_size + half, cell.y * tile_size + half)
			var zone = _find_zone_data_for_tile(cell)
			var biome_name = "Dungeon"
			var display_name = "Dungeon"
			if zone:
				biome_name = zone.dungeon_base if zone.dungeon_base != "" else zone.zone_name
				display_name = zone.zone_name if zone.zone_name != "" else zone.id
			var nodes = _add_entrance(pixel_pos, biome_name, tile_size, display_name)
			chunk_info["entrances"].append_array(nodes)

func _create_chunk_entrances_from_layer(chunk_key: Vector2i, chunk_info: Dictionary) -> void:
	var tile_size = 32
	var half = tile_size / 2
	var cells = chunk_info["cells"].get("buildings", []) as Array
	var layer = _all_layers["buildings"] as TileMapLayer
	for cell in cells:
		var atlas = layer.get_cell_atlas_coords(cell)
		if atlas.x == 5:  # stairs tile
			var pixel_pos = Vector2(cell.x * tile_size + half, cell.y * tile_size + half)
			var zone = _find_zone_data_for_tile(cell)
			var biome_name = "Dungeon"
			var display_name = "Dungeon"
			if zone:
				biome_name = zone.dungeon_base if zone.dungeon_base != "" else zone.zone_name
				display_name = zone.zone_name if zone.zone_name != "" else zone.id
			var nodes = _add_entrance(pixel_pos, biome_name, tile_size, display_name)
			chunk_info["entrances"].append_array(nodes)
