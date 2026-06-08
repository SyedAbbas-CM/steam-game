@tool
class_name Overworld
extends Node2D

const PlayerQuery = preload("res://scripts/systems/player_query.gd")
const LIQUID_SURFACE_SHADER = preload("res://shaders/dungeon/liquid_surface.gdshader")

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
var _shadow_occluders: Node2D
var _door_areas: Array[Area2D] = []
var _enemy_def_cache: Dictionary = {}  # path -> EnemyDefinition
var _nearby_entrance: Area2D = null  # entrance the player is standing near
var _tile_inspector: TileInspector = null  # tile inspection popup
var _zone_spawn_data: Array = []  # [{zone, spawn_data, enemy_def, ox, oy, s}] for respawning
var _respawn_timer: float = 0.0
var _water_shader_material: ShaderMaterial = null
const RESPAWN_INTERVAL: float = 8.0  # seconds between spawn ticks (enemies appear gradually)
const MAX_ENEMIES_PER_ZONE: int = 6
const DEFAULT_TEST_MINE_ID: String = "ironvein_depths"
const CRYSTAL_TEST_MINE_ID: String = "crystal_hollows"

## Zone-based loading: only load chunks in current zone + connected zones
var _current_zone: LoyZoneData = null
var _allowed_zone_ids: Array = []  # zone IDs whose chunks can load
var _zone_bboxes: Dictionary = {}  # zone_id -> Rect2i (tile bounding box with corridor margin)
var _zone_gates: Array = []  # Area2D gate triggers at zone exits
var _zone_label: Label = null  # zone name HUD
var _zone_label_tween: Tween = null
var _last_zone_chime_msec: int = 0
var _last_zone_change_msec: int = 0  # cooldown for zone transitions
var _last_shown_zone_id: String = ""  # prevent re-showing same zone
const ZONE_CHANGE_COOLDOWN_MSEC: int = 3000  # min ms between zone transitions
const TOWN_SPEED_MULT: float = 3.0  # speed multiplier in safe/town zones
var _town_speed_active: bool = false

# Battle region waypoint pairs — zone_id -> { "ps": Vector2i (player spawn tile), "es": Vector2i (enemy spawn tile) }
const BATTLE_REGIONS := {
	# Darl Woods area
	"wastes": {"ps": Vector2i(276, -1), "es": Vector2i(406, -47)},
	"rotgrove": {"ps": Vector2i(276, -1), "es": Vector2i(406, -47)},
	"witchglade": {"ps": Vector2i(276, -1), "es": Vector2i(406, -47)},
	"darlwood": {"ps": Vector2i(276, -1), "es": Vector2i(406, -47)},
	# Staging Grounds area
	"gallows": {"ps": Vector2i(265, 37), "es": Vector2i(321, 39)},
	"wardens": {"ps": Vector2i(265, 37), "es": Vector2i(321, 39)},
	# Farm area
	"duskfarm": {"ps": Vector2i(124, 64), "es": Vector2i(224, 45)},
	# Highway area
	"dreadbridge": {"ps": Vector2i(137, -58), "es": Vector2i(254, -70)},
	"brg2": {"ps": Vector2i(137, -58), "es": Vector2i(254, -70)},
	# Wilderness area
	"cutthroat": {"ps": Vector2i(106, -47), "es": Vector2i(-24, -53)},
	"frostpass": {"ps": Vector2i(-15, -206), "es": Vector2i(-57, -135)},
	"cold2": {"ps": Vector2i(-15, -206), "es": Vector2i(-57, -135)},
	# Graveyard area
	"barrows": {"ps": Vector2i(32, 125), "es": Vector2i(32, 217)},
}
# Fallback: all waypoint pairs for nearest-match lookup
const _ALL_WAYPOINT_PAIRS := [
	[Vector2i(276, -1), Vector2i(406, -47)],      # Darl Woods
	[Vector2i(265, 37), Vector2i(321, 39)],        # Staging Grounds
	[Vector2i(124, 64), Vector2i(224, 45)],        # Farm
	[Vector2i(137, -58), Vector2i(254, -70)],      # Highway
	[Vector2i(106, -47), Vector2i(-24, -53)],      # Wilderness 1
	[Vector2i(-15, -206), Vector2i(-57, -135)],    # Wilderness 2
	[Vector2i(32, 125), Vector2i(32, 217)],        # Graveyard
]

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
	add_to_group("overworld")
	_setup_water_shader()

	var t0 = Time.get_ticks_msec()
	var player = $Player
	# Scale visuals only — scaling CharacterBody2D breaks move_and_slide()
	# Animated sprites (8x8) need 4x scale; static LoY chars.png (32x32) need 1x
	var spr = player.get_node("Sprite2D")
	if player.get("_player_anim") != null:
		spr.scale = Vector2(4, 4)  # 8x8 animated sprite — scale up to 32px
	elif spr.texture is AtlasTexture:
		spr.scale = Vector2(1, 1)  # 32x32 atlas from chars.png — already tile-sized
	else:
		spr.scale = Vector2(4, 4)  # 8x8 lofi_char.png — scale up to 32px
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

	# Set player position: return to dungeon entrance if coming back, else default spawn
	var gm = get_node_or_null("/root/GameManager")
	var spawn_px = Vector2(player_spawn_tile.x * 32 + 16, player_spawn_tile.y * 32 + 16)
	if gm and gm.overworld_return_position != Vector2.ZERO:
		spawn_px = gm.overworld_return_position
		gm.overworld_return_position = Vector2.ZERO  # clear so next fresh load uses default
	player.global_position = spawn_px
	print("Player spawn: pixel %s" % spawn_px)
	_play_player_spawn_warp(player, spawn_px)

	# Spawn temporary town portal if returning from boss kill
	if gm and gm.has_meta("spawn_overworld_portal") and gm.get_meta("spawn_overworld_portal"):
		gm.remove_meta("spawn_overworld_portal")
		_spawn_temp_portal(spawn_px + Vector2(0, 40))

	var lm = get_node_or_null("/root/LightingManager")
	if lm and lm.has_method("apply_outline_to_subtree"):
		lm.apply_outline_to_subtree(self)

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
	if PerfTelemetry.is_enabled():
		_perf_overlay = PerfOverlay.new()
		add_child(_perf_overlay)
		_perf_overlay.setup()
		PerfTelemetry.attach_scene(self, self)

	# Pass zone data to QuestManager for objective position resolution + quest arrow
	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("set_zone_data"):
		qm.set_zone_data(zone_data)
		qm.quest_started.connect(_on_quest_arrow_update)
		qm.quest_completed.connect(_on_quest_arrow_update)
		qm.quest_progressed.connect(func(_qid, _pname, _val): _on_quest_arrow_update(""))
		_update_quest_arrow()

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

	# Show victory notification if returning from a won battle
	if gm and gm.has_meta("last_battle_victory_zone"):
		var won_zone: String = gm.get_meta("last_battle_victory_zone")
		gm.remove_meta("last_battle_victory_zone")
		_show_battle_victory_notification.call_deferred(won_zone)

func _play_player_spawn_warp(player: Node2D, spawn_px: Vector2) -> void:
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.storm_arrival(spawn_px, Color(0.86, 0.08, 0.05, 0.98), 96.0, 1.15)
		vfx.shockwave(spawn_px, 42.0, Color(1.0, 0.18, 0.08, 0.26))
		vfx.shake(1.8, 0.18)

	var spr = player.get_node_or_null("Sprite2D") as Sprite2D
	if spr:
		spr.modulate = Color(1.35, 0.72, 0.72, 0.22)
		var tween = create_tween()
		tween.tween_property(spr, "modulate", Color.WHITE, 0.36)

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

	_shadow_occluders = Node2D.new()
	_shadow_occluders.name = "ShadowOccluders"
	add_child(_shadow_occluders)


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
		_update_town_speed(_current_zone)
		# Apply zone lighting mood
		var lm = get_node_or_null("/root/LightingManager")
		if lm:
			lm.reset()
			lm.apply_zone_mood(_current_zone)
			lm.setup_player_lantern(player)
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
			_load_chunk_immediate(key)
	# Request the rest of LOAD_RADIUS async (will paint incrementally)
	for dy in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			if abs(dx) <= 1 and abs(dy) <= 1:
				continue  # already loaded sync
			var key = Vector2i(center.x + dx, center.y + dy)
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
	# Zone-based spawning for passive creatures + zone-specific enemies
	_spawn_zone_enemies()
	# Editor-defined spawn regions for hostile area enemies
	_spawn_editor_enemies()
	print("TIMING: overworld spawn enemies took %d ms" % (Time.get_ticks_msec() - t1))
	_spawn_equipment_bag()
	_spawn_mine_entrances()
	_spawn_test_arena_entrance()
	_spawn_height_test_entrance()

	t1 = Time.get_ticks_msec()
	_spawn_harvest_nodes()
	print("TIMING: overworld spawn harvest nodes took %d ms" % (Time.get_ticks_msec() - t1))

	# UI overlays
	var dialogue_ui = DialogueUI.new()
	add_child(dialogue_ui)
	var quest_log = QuestLog.new()
	add_child(quest_log)
	var shop_ui = ShopUI.new()
	add_child(shop_ui)

	# Territory/diplomacy attack notifications
	_setup_attack_notifications()

	# Zone gates and HUD
	_create_zone_gates()
	if _current_zone:
		_last_shown_zone_id = _current_zone.id
		_last_zone_change_msec = Time.get_ticks_msec()
		_show_zone_name(_current_zone.zone_name if _current_zone.zone_name != "" else _current_zone.id)
	var qm = get_node_or_null("/root/QuestManager")
	if qm and _current_zone:
		qm.on_zone_entered(_current_zone.id)
		# Spawn quest enemies for active kill quests on game load
		check_quest_enemy_spawns(_current_zone.id)

	# 3D first-person view (L key toggle)
	var fpv = FirstPersonView.new()
	fpv.name = "FirstPersonView"
	fpv.visible = false
	add_child(fpv)
	fpv.setup(32.0)
	# Overworld tile sources
	fpv.add_source(0, "res://assets/sprites/loy/maptiles.png", 16, 16)      # ground + walls
	fpv.add_source(1, "res://assets/sprites/lofiEnvironment_32.png", 16, 26) # env tiles
	fpv.add_source(2, "res://assets/sprites/lofi_dungeon_features_32.png", 12, 9)
	fpv.add_source(3, "res://assets/sprites/lofi_obj_32.png", 16, 16)       # objects
	fpv.add_source(4, "res://assets/sprites/lofi_obj_packB_32.png", 9, 8)   # more objects
	fpv.add_source(5, "res://assets/sprites/loy/tiles.png", 16, 16)         # extra ground
	fpv.add_source(6, "res://assets/sprites/loy/tiles2.png", 16, 16)        # extra ground
	fpv.set_layers(ground, buildings)
	fpv.add_object_layer(decorations, "decorations")
	fpv.add_object_layer(buildings, "buildings")  # source 3/4 objects rendered as quads
	fpv.add_floor_overlay_layer(paths, "paths")
	fpv.add_floor_overlay_layer(water, "water")
	fpv.setup_overworld(self, buildings, fences, water)
	player._first_person_view = fpv

	print("TIMING: overworld TOTAL _async_init took %d ms" % (Time.get_ticks_msec() - t0))

	# Hide GameManager loading screen if visible
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("_hide_loading_screen"):
		gm._hide_loading_screen()

	# One-shot post-tutorial guidance: point the new Penitent at the Elder.
	if gm and gm.save_data and gm.save_data.tutorial_just_completed:
		gm.save_data.tutorial_just_completed = false
		gm.save_data.save_to_slot()
		call_deferred("_show_post_tutorial_dialogue")

func _load_zone_data() -> void:
	for path in ResourceRegistry.zones():
		var zone = load(path) as LoyZoneData
		if zone:
			zone_data.append(zone)

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
	var now = Time.get_ticks_msec()
	if now - _last_zone_change_msec < ZONE_CHANGE_COOLDOWN_MSEC:
		return  # cooldown active — prevent flickering at zone borders
	var tile = Vector2i(int(player.position.x / 32), int(player.position.y / 32))
	# If player is still inside current zone, don't switch (prevents overlap flicker)
	if _current_zone and _tile_in_zone(tile, _current_zone):
		return
	var zone = _find_zone_data_for_tile(tile)
	if zone and zone != _current_zone:
		_switch_to_zone(zone)

func _tile_in_zone(cell: Vector2i, zone: LoyZoneData) -> bool:
	if zone.baked_offset == Vector2i(-99999, -99999):
		return false
	var s: int = zone.baked_scale if zone.baked_scale > 0 else 1
	var w: int = (zone.width if zone.width > 0 else 50) * s
	var h: int = (zone.height if zone.height > 0 else 50) * s
	return cell.x >= zone.baked_offset.x and cell.x < zone.baked_offset.x + w and cell.y >= zone.baked_offset.y and cell.y < zone.baked_offset.y + h

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
	var now = Time.get_ticks_msec()
	if now - _last_zone_change_msec < ZONE_CHANGE_COOLDOWN_MSEC:
		return
	var target = _find_zone_by_id(target_zone_id)
	if target and target != _current_zone:
		_switch_to_zone(target)

func _switch_to_zone(zone: LoyZoneData) -> void:
	PerfTelemetry.mark_checkpoint("zone_changed", {
		"zone_id": zone.id,
		"zone_name": zone.zone_name,
	})
	_current_zone = zone
	_last_zone_change_msec = Time.get_ticks_msec()
	_rebuild_allowed_zones()
	_create_zone_gates()
	_update_town_speed(zone)
	# Transition lighting mood
	var lm = get_node_or_null("/root/LightingManager")
	if lm:
		lm.apply_zone_mood(zone)
		lm.setup_player_lantern($Player)
	var zone_name = zone.zone_name if zone.zone_name != "" else zone.id
	# Only show name + chime if this is a different zone than last shown
	if zone.id != _last_shown_zone_id:
		_last_shown_zone_id = zone.id
		_show_zone_name(zone_name)
	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		qm.on_zone_entered(zone.id)
	# Spawn quest enemies if needed for active kill quests in this zone
	check_quest_enemy_spawns(zone.id)
	# Unload chunks outside new allowed zones (but keep chunks near player)
	for key in _loaded_chunks.keys():
		var near_player = abs(key.x - _last_chunk.x) <= LOAD_RADIUS and abs(key.y - _last_chunk.y) <= LOAD_RADIUS
		if not near_player and not _chunk_in_allowed_zones(key) and key not in _unload_queue:
			_unload_queue.append(key)

func _show_zone_name(zone_name: String) -> void:
	var now = Time.get_ticks_msec()
	if now - _last_zone_chime_msec > 2000:
		_last_zone_chime_msec = now
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("chime", -4.0, 0.0)
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

func _show_battle_victory_notification(zone_name: String) -> void:
	if not _zone_label:
		_setup_zone_label()
	if not _zone_label:
		return
	_zone_label.text = "VICTORY! %s conquered!" % zone_name
	_zone_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	_zone_label.modulate.a = 0.0
	_zone_label.visible = true
	if _zone_label_tween and _zone_label_tween.is_valid():
		_zone_label_tween.kill()
	_zone_label_tween = create_tween()
	_zone_label_tween.tween_property(_zone_label, "modulate:a", 1.0, 0.3)
	_zone_label_tween.tween_interval(3.0)
	_zone_label_tween.tween_property(_zone_label, "modulate:a", 0.0, 1.0)
	_zone_label_tween.tween_callback(func(): _zone_label.add_theme_color_override("font_color", Color.WHITE))

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
	var mine_id = _get_default_mine_id_for_biome(biome_name)
	entrance.set_meta("mine_id", mine_id)

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(tile_size, tile_size)
	shape.shape = rect
	entrance.add_child(shape)

	# E-key prompt label (hidden until player is nearby)
	var prompt = Label.new()
	if TouchControls.is_mobile():
		prompt.text = "Tap to Enter %s" % display_name
	else:
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

func _get_default_mine_id_for_biome(biome_name: String) -> String:
	if biome_name == "" or biome_name.begins_with("Test-") or biome_name == "TestCombo" or biome_name == "TestMovement":
		return ""
	var lowered := biome_name.to_lower()
	for crystal_key in ["spire", "frost", "storm", "sanctum", "eldori", "cenneth", "crystal"]:
		if crystal_key in lowered:
			return CRYSTAL_TEST_MINE_ID
	return DEFAULT_TEST_MINE_ID

func _on_entrance_proximity(body: Node2D, entrance: Area2D) -> void:
	if body.is_in_group("player"):
		_nearby_entrance = entrance
		var prompt = entrance.get_meta("prompt_label") as Label
		if prompt:
			prompt.visible = true
		if TouchControls.is_mobile():
			var tc = get_tree().get_first_node_in_group("touch_controls") as TouchControls
			if tc:
				var dn = str(entrance.get_meta("display_name"))
				tc.show_interact_button("Enter " + dn)

func _on_entrance_left(body: Node2D, entrance: Area2D) -> void:
	if body.is_in_group("player") and _nearby_entrance == entrance:
		var prompt = entrance.get_meta("prompt_label") as Label
		if prompt:
			prompt.visible = false
		_nearby_entrance = null
		if TouchControls.is_mobile():
			var tc = get_tree().get_first_node_in_group("touch_controls") as TouchControls
			if tc:
				tc.hide_interact_button()

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
			# Move elder NPCs into their office building
			if str(npc_data.get("name", "")).to_lower().contains("elder"):
				ny += 1
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

	# Spawn War Tables in all towns
	_spawn_war_tables()

const WAR_TABLE_ZONES := [
	"haven", "briarvale", "ashheim", "windhold", "kor", "brackwater", "grimhold",
	"mirage", "boghollow", "duskwatch", "thule", "duskport", "eldori", "cenneth", "scorchgate",
]

func _spawn_war_tables() -> void:
	var ts := 32
	if ground and ground.tile_set:
		ts = ground.tile_set.tile_size.x
	var wt_script = load("res://scripts/objects/war_table.gd")
	if not wt_script:
		return
	for zone in zone_data:
		if zone.id not in WAR_TABLE_ZONES:
			continue
		if zone.baked_offset == Vector2i(-99999, -99999):
			continue
		var ox := zone.baked_offset.x
		var oy := zone.baked_offset.y
		var s: int = zone.baked_scale if zone.baked_scale > 0 else 1
		# Find anchor NPC: prioritize by name "Elder", then type elder/scriptfile/shop, then first NPC
		var anchor_x := zone.width / 2
		var anchor_y := zone.height / 2
		var found := false
		# Pass 1: NPC named "Elder"
		for npc_data in zone.npcs:
			if str(npc_data.get("name", "")).to_lower().contains("elder"):
				anchor_x = int(npc_data.get("x", anchor_x))
				anchor_y = int(npc_data.get("y", anchor_y))
				found = true
				break
		# Pass 2: type priority
		if not found:
			for priority_type in ["elder", "scriptfile", "shop"]:
				for npc_data in zone.npcs:
					if str(npc_data.get("type", "")) == priority_type:
						anchor_x = int(npc_data.get("x", anchor_x))
						anchor_y = int(npc_data.get("y", anchor_y))
						found = true
						break
				if found:
					break
		# Pass 3: first NPC
		if not found and not zone.npcs.is_empty():
			var npc_data = zone.npcs[0]
			anchor_x = int(npc_data.get("x", anchor_x))
			anchor_y = int(npc_data.get("y", anchor_y))
		# Place war table 1 tile east of elder, same row
		var table_x := mini(anchor_x + 1, (zone.width if zone.width > 0 else 25) - 2)
		var table_y := anchor_y + 1
		var table = wt_script.new()
		table.position = Vector2((ox + table_x * s) * ts + ts / 2, (oy + table_y * s) * ts + ts / 2)
		table.z_index = 3
		add_child(table)
		print("Overworld: War Table spawned in %s at %s" % [zone.id, str(table.position)])

func _spawn_zone_enemies() -> void:
	# Register zone spawn data — actual spawning deferred to _respawn_zone_enemies()
	for zone in zone_data:
		if zone.baked_offset == Vector2i(-99999, -99999):
			continue

		var is_safe = zone.id in SAFE_ZONES
		var ox = zone.baked_offset.x
		var oy = zone.baked_offset.y
		var s = zone.baked_scale if zone.baked_scale > 0 else 1

		for spawn_data in zone.spawns:
			var monster_type = str(spawn_data.get("type", ""))
			var enemy_def = _get_cached_enemy_def(monster_type)
			if not enemy_def:
				continue
			# Safe zones: only spawn passive creatures (chickens, fairies)
			if is_safe and enemy_def.hostile:
				continue

			_zone_spawn_data.append({
				"zone_id": zone.id,
				"spawn_data": spawn_data,
				"enemy_def": enemy_def,
				"ox": ox, "oy": oy, "s": s
			})
	print("Registered %d zone spawn entries (lazy)" % _zone_spawn_data.size())

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
		if enemy_def.hostile:
			# Hostile: scale stats for overworld (32px tiles vs 8px dungeon = 4x)
			ow_def.move_speed = enemy_def.move_speed * 4.0
			ow_def.aggro_range = enemy_def.aggro_range * 4.0
			ow_def.preferred_distance = enemy_def.preferred_distance * 4.0
			ow_def.bullet_speed = enemy_def.bullet_speed * 4.0
			ow_def.charge_speed = enemy_def.charge_speed * 4.0
		else:
			# Passive: disarm, slow wander
			ow_def.attack_type = EnemyDefinition.AttackType.NONE
			ow_def.move_speed = 15.0
			ow_def.preferred_distance = 0.0
			ow_def.bullet_count = 0
		enemy.setup(ow_def)
	# LoY sprites are 32x32 native; setup() scales to 0.25 for dungeon (8px tiles)
	# Override to 1.0 for overworld (32px tiles) = native size
	var _enemy_spr = enemy.get_node_or_null("Sprite2D")
	if _enemy_spr:
		_enemy_spr.scale = Vector2(1, 1)
	enemy.set_meta("zone_id", zone_id)
	enemy.set_meta("spawn_pos", pos)
	enemy.set_meta("leash_radius", float(maxi(sw, sh) * s * ts))
	if enemy_def.hostile:
		enemy.set_meta("behavior", "wander")
		enemy.set_meta("hostile", true)
	else:
		enemy.set_meta("behavior", "wander")
		enemy.set_meta("passive_until_hit", true)
	container.add_child(enemy)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.warp_portal(pos, Color(0.84, 0.1, 0.05, 0.96), 22.0, 0.5)

## ── Quest Enemy Spawning ────────────────────────────────────────────────────

func spawn_quest_enemies(zone_id: String, enemy_name: String, count: int, area: Dictionary = {}) -> void:
	## Spawn a batch of enemies in a zone for quest purposes.
	## area: optional {x, y, w, h} in zone-local LoY tiles. If empty, uses full zone.
	var container = get_node_or_null("EnemyContainer")
	if not container:
		print("spawn_quest_enemies: No EnemyContainer")
		return
	var enemy_def = _get_cached_enemy_def(enemy_name)
	if not enemy_def:
		print("spawn_quest_enemies: Enemy '%s' not found" % enemy_name)
		return
	var enemy_scene = load("res://scenes/enemy.tscn") as PackedScene
	if not enemy_scene:
		return

	# Find the zone data for the target zone
	var zone: LoyZoneData = null
	for z in zone_data:
		if z.id == zone_id:
			zone = z
			break
	if not zone:
		print("spawn_quest_enemies: Zone '%s' not found" % zone_id)
		return

	var ox = zone.baked_offset.x
	var oy = zone.baked_offset.y
	var s = zone.baked_scale if zone.baked_scale > 0 else 1
	var ts: int = 32
	var half: int = ts / 2

	# Use explicit area if provided, otherwise zone's full dims with margin
	var zw: int = zone.width if zone.width > 0 else 25
	var zh: int = zone.height if zone.height > 0 else 25
	var spawn_x: int
	var spawn_y: int
	var spawn_w: int
	var spawn_h: int
	if area.has("x"):
		spawn_x = int(area["x"])
		spawn_y = int(area["y"])
		spawn_w = maxi(1, int(area["w"]))
		spawn_h = maxi(1, int(area["h"]))
	else:
		var margin: int = 3
		spawn_x = margin
		spawn_y = margin
		spawn_w = maxi(1, zw - margin * 2)
		spawn_h = maxi(1, zh - margin * 2)
	print("spawn_quest_enemies: zone '%s' offset=(%d,%d) scale=%d dims=%dx%d spawn_area=(%d,%d,%d,%d)" % [zone_id, ox, oy, s, zw, zh, spawn_x, spawn_y, spawn_w, spawn_h])

	var spawned = 0
	for _i in range(count * 3):  # extra attempts since some may collide with walls
		if spawned >= count:
			break
		var ex = spawn_x + randi() % maxi(1, spawn_w)
		var ey = spawn_y + randi() % maxi(1, spawn_h)
		# Convert zone-local LoY tile to world pixel position
		var tile_x: int = ox + ex * s
		var tile_y: int = oy + ey * s
		var pos = Vector2(tile_x * ts + half, tile_y * ts + half)
		var enemy = enemy_scene.instantiate()
		enemy.global_position = pos
		if enemy.has_method("setup"):
			var ow_def = enemy_def.duplicate()
			ow_def.move_speed = enemy_def.move_speed * 4.0
			ow_def.aggro_range = enemy_def.aggro_range * 4.0
			ow_def.preferred_distance = enemy_def.preferred_distance * 4.0
			ow_def.bullet_speed = enemy_def.bullet_speed * 4.0
			ow_def.charge_speed = enemy_def.charge_speed * 4.0
			enemy.setup(ow_def)
		var _enemy_spr = enemy.get_node_or_null("Sprite2D")
		if _enemy_spr:
			_enemy_spr.scale = Vector2(1, 1)
		enemy.set_meta("zone_id", zone_id)
		enemy.set_meta("spawn_pos", pos)
		enemy.set_meta("leash_radius", float(maxi(spawn_w, spawn_h) * s * ts))
		enemy.set_meta("behavior", "wander")
		enemy.set_meta("hostile", true)
		enemy.set_meta("quest_enemy", true)  # prevents despawning
		enemy.set_meta("enemy_name", enemy_name)
		container.add_child(enemy)
		spawned += 1
		if spawned <= 3:
			print("  quest enemy #%d at %s" % [spawned, pos])

	print("spawn_quest_enemies: Spawned %d x '%s' in zone '%s'" % [spawned, enemy_name, zone_id])

func check_quest_enemy_spawns(zone_id: String) -> void:
	## Called on zone enter. For each active kill quest targeting this zone,
	## spawn enemies if none of that type are alive in the zone.
	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		return
	var container = get_node_or_null("EnemyContainer")
	if not container:
		return

	# Collect alive quest enemy types per zone
	var alive_types: Dictionary = {}  # enemy_name -> count
	for child in container.get_children():
		if child is CharacterBody2D and child.has_meta("quest_enemy") and child.has_meta("zone_id"):
			if child.get_meta("zone_id") == zone_id:
				var ename = ""
				if "definition" in child and child.definition and child.definition.enemy_name != "":
					ename = child.definition.enemy_name
				elif child.has_meta("enemy_name"):
					ename = child.get_meta("enemy_name")
				if ename != "":
					alive_types[ename] = alive_types.get(ename, 0) + 1

	# Check active quests for kill events targeting enemies in this zone
	for quest_id in qm.active_quests:
		if not qm.active_quests[quest_id].get("active", false):
			continue
		if not qm.definitions.has(quest_id):
			continue
		var quest = qm.definitions[quest_id]
		# Find kill events to determine enemy type
		for event in quest.events:
			if event.get("type") == "kill":
				var enemy_name = str(event.get("param", ""))
				if enemy_name == "" or enemy_name == "*":
					continue  # wildcard kills don't spawn enemies
				# Find the original spawnEnemies command to get the CORRECT spawn zone
				var spawn_cmd: Dictionary = _find_spawn_cmd(quest.start_script, enemy_name)
				if spawn_cmd.size() == 0:
					continue  # no spawn command found, don't guess
				# Only spawn if the spawn command's zone matches the zone we're entering
				var spawn_zone = str(spawn_cmd.get("zone", ""))
				if spawn_zone != zone_id:
					continue  # this quest spawns in a different zone
				var alive = alive_types.get(enemy_name, 0)
				if alive > 0:
					continue  # some still alive, don't respawn
				var spawn_count = int(spawn_cmd.get("count", "10"))
				# Subtract kills already made (quest property index 0 = kill counter)
				var kills_so_far = qm.get_quest_value(quest_id, 0)
				var remaining = maxi(0, spawn_count - kills_so_far)
				if remaining <= 0:
					continue  # all required kills done, no need to spawn more
				var area: Dictionary = {}
				if spawn_cmd.has("x"):
					area = {"x": int(spawn_cmd.get("x", "0")), "y": int(spawn_cmd.get("y", "0")), "w": int(spawn_cmd.get("w", "8")), "h": int(spawn_cmd.get("h", "8"))}
				print("check_quest_enemy_spawns: Spawning %d x '%s' for quest '%s' in zone '%s' (killed %d/%d)" % [remaining, enemy_name, quest_id, zone_id, kills_so_far, spawn_count])
				spawn_quest_enemies(zone_id, enemy_name, remaining, area)

func _cmd_is_spawn(cmd: Dictionary, enemy_name: String) -> bool:
	return cmd.get("cmd", "") in ["spawn", "spawnEnemies"] and cmd.get("enemy", "") == enemy_name

func _find_spawn_cmd(commands: Array, enemy_name: String) -> Dictionary:
	## Recursively search quest script commands for a spawnEnemies command matching enemy_name
	for cmd in commands:
		if _cmd_is_spawn(cmd, enemy_name):
			return cmd
		for opt in cmd.get("options", []):
			var found = _find_spawn_cmd(opt.get("script", []), enemy_name)
			if found.size() > 0:
				return found
		var sub = cmd.get("script", [])
		if sub.size() > 0:
			var found = _find_spawn_cmd(sub, enemy_name)
			if found.size() > 0:
				return found
	return {}

## ── Harvest Nodes ────────────────────────────────────────────────────────────

const HARVEST_NODE_CONFIGS = {
	"herb": {
		"drop_table": [
			"res://resources/items/crafting/healing_herb.tres",
			"res://resources/items/crafting/swamp_root.tres",
		],
		"sprite_tile": 123,
	},
	"ore": {
		"drop_table": [
			"res://resources/items/crafting/iron_ore.tres",
			"res://resources/items/crafting/cave_crystal.tres",
		],
		"sprite_tile": 116,
	},
	"tree": {
		"drop_table": [
			"res://resources/items/crafting/ancient_bark.tres",
			"res://resources/items/crafting/healing_herb.tres",
		],
		"sprite_tile": 126,
	},
	"mushroom": {
		"drop_table": [
			"res://resources/items/crafting/wild_mushroom.tres",
		],
		"sprite_tile": 124,
	},
	"bug_nest": {
		"drop_table": [
			"res://resources/items/crafting/venom_sac.tres",
			"res://resources/items/crafting/leather_scraps.tres",
		],
		"sprite_tile": 119,
	},
}

func _get_zone_harvest_types(zone: LoyZoneData) -> Array[String]:
	# Town zones — no harvest
	if zone.id in SAFE_ZONES:
		return []
	var types: Array[String] = []
	match zone.tileset:
		112:  # town — skip
			return []
		0, 8:  # grey/brown — forest/mountain
			types = ["herb", "herb", "tree"]
		16:  # blue — cave
			types = ["ore", "ore", "mushroom"]
		144:  # ice
			types = ["ore", "tree"]
		192:  # jungle
			types = ["herb", "bug_nest", "mushroom"]
		224:  # desert
			types = ["ore", "herb"]
		240:  # mountain
			types = ["ore", "ore", "tree"]
		_:  # default forest-like
			types = ["herb", "tree", "mushroom"]
	return types

func _spawn_harvest_nodes() -> void:
	var ts = 32
	if ground and ground.tile_set:
		ts = ground.tile_set.tile_size.x
	var half = ts / 2

	var node_count = 0
	for zone in zone_data:
		if zone.baked_offset == Vector2i(-99999, -99999):
			continue
		var harvest_types = _get_zone_harvest_types(zone)
		if harvest_types.is_empty():
			continue

		var ox = zone.baked_offset.x
		var oy = zone.baked_offset.y
		var s = zone.baked_scale if zone.baked_scale > 0 else 1
		var zw = zone.width
		var zh = zone.height

		for i in range(harvest_types.size()):
			var htype = harvest_types[i]
			var config = HARVEST_NODE_CONFIGS[htype]

			var node = HarvestNode.new()
			node.harvest_type = htype
			node.drop_table.assign(config["drop_table"])
			node.sprite_tile_index = config["sprite_tile"]
			node.respawn_time = 90.0
			node.persist_key = "%s:%d" % [zone.id, i]
			node.collision_radius = 48.0  # same as NPC detection range
			node.sprite_scale = 1.0  # native 32x32, same size as NPCs

			# Random position within zone bounds
			var rx = randi() % maxi(1, zw - 4) + 2
			var ry = randi() % maxi(1, zh - 4) + 2
			node.position = Vector2(
				(ox + rx * s) * ts + half,
				(oy + ry * s) * ts + half
			)

			node.z_index = 2
			add_child(node)
			node_count += 1

func _check_respawns(delta: float) -> void:
	_respawn_timer += delta
	if _respawn_timer < RESPAWN_INTERVAL:
		return
	_respawn_timer = 0.0
	_respawn_editor_enemies()
	_respawn_zone_enemies()
	_despawn_far_enemies()

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
	## Just loads spawn regions — actual spawning happens over time via _respawn_editor_enemies
	_load_editor_spawns()
	if _editor_spawn_regions.is_empty():
		return
	print("Editor spawn regions loaded: %d — enemies will spawn over time" % _editor_spawn_regions.size())

func _pick_from_spawn_table(region: Dictionary) -> String:
	## Pick a random enemy type from a region's spawn_table (weighted) or single enemy_type
	var table = region.get("spawn_table", [])
	if table is Array and table.size() > 0:
		var total_weight: float = 0.0
		for entry in table:
			total_weight += float(entry.get("weight", 1))
		var roll = randf() * total_weight
		var cumulative: float = 0.0
		for entry in table:
			cumulative += float(entry.get("weight", 1))
			if roll <= cumulative:
				return str(entry.get("type", "Goblin"))
		return str(table[0].get("type", "Goblin"))
	return str(region.get("enemy_type", "Goblin"))

func _spawn_one_enemy(region: Dictionary, container: Node, enemy_scene: PackedScene) -> void:
	var ts = 32
	var half = ts / 2
	var x1 = int(region.get("x1", 0))
	var y1 = int(region.get("y1", 0))
	var x2 = int(region.get("x2", 0))
	var y2 = int(region.get("y2", 0))
	var hostile = bool(region.get("hostile", true))
	var behavior = str(region.get("behavior", "chase"))
	var region_name = str(region.get("name", ""))
	var w = maxi(1, x2 - x1)
	var h = maxi(1, y2 - y1)
	var leash = float(maxi(w, h) * ts)

	var enemy_type = _pick_from_spawn_table(region)
	var enemy_def = _get_cached_enemy_def(enemy_type)
	if not enemy_def:
		return

	var ex = x1 + randi() % w
	var ey = y1 + randi() % h
	var pos = Vector2(ex * ts + half, ey * ts + half)
	var enemy = enemy_scene.instantiate()
	enemy.global_position = pos
	if enemy.has_method("setup"):
		var ow_def = enemy_def.duplicate()
		if not hostile or behavior == "passive":
			ow_def.attack_type = EnemyDefinition.AttackType.NONE
		# Scale all distances/speeds for overworld (32px tiles vs 8px dungeon = 4x)
		ow_def.move_speed = enemy_def.move_speed * 4.0
		ow_def.aggro_range = enemy_def.aggro_range * 4.0
		ow_def.preferred_distance = enemy_def.preferred_distance * 4.0
		ow_def.bullet_speed = enemy_def.bullet_speed * 4.0
		ow_def.charge_speed = enemy_def.charge_speed * 4.0
		enemy.setup(ow_def)
	# LoY sprites are 32x32, setup() scales to 0.25 for dungeon (8px tiles)
	# Overworld tiles are 32px, so set scale to 1.0 (native size)
	var _enemy_spr = enemy.get_node_or_null("Sprite2D")
	if _enemy_spr:
		_enemy_spr.scale = Vector2(1, 1)
	enemy.set_meta("spawn_region", region_name)
	enemy.set_meta("spawn_pos", pos)
	enemy.set_meta("leash_radius", leash)
	enemy.set_meta("behavior", behavior)
	enemy.set_meta("hostile", hostile)
	if not hostile or behavior == "passive":
		enemy.set_meta("passive_until_hit", true)
	container.add_child(enemy)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.warp_portal(pos, Color(0.84, 0.1, 0.05, 0.96), 22.0, 0.5)

func _respawn_editor_enemies() -> void:
	if _editor_spawn_regions.is_empty():
		return
	var container = get_node_or_null("EnemyContainer")
	if not container:
		return
	var player_node = PlayerQuery.get_primary_player(get_tree())
	if not player_node:
		return
	var ts = 32
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
		# Only spawn if region is in an allowed zone (near player)
		var x1 = int(region.get("x1", 0))
		var y1 = int(region.get("y1", 0))
		var x2 = int(region.get("x2", 0))
		var y2 = int(region.get("y2", 0))
		var center = Vector2((x1 + x2) / 2.0 * ts, (y1 + y2) / 2.0 * ts)
		if player_node.global_position.distance_to(center) > 3000:
			continue
		# Spawn multiple enemies per tick to fill regions faster
		var to_spawn = mini(3, max_count - current)
		for _i in range(to_spawn):
			_spawn_one_enemy(region, container, enemy_scene)

const ZONE_SPAWN_RADIUS: float = 3000.0   # spawn zone enemies within this range
const ZONE_DESPAWN_RADIUS: float = 4500.0  # despawn enemies beyond this range

func _respawn_zone_enemies() -> void:
	if _zone_spawn_data.is_empty():
		return
	var container = get_node_or_null("EnemyContainer")
	if not container:
		return
	var player_node = PlayerQuery.get_primary_player(get_tree())
	if not player_node:
		return
	var ts: int = 32
	var half: int = ts / 2
	var enemy_scene = load("res://scenes/enemy.tscn") as PackedScene
	if not enemy_scene:
		return

	# Count living enemies per zone
	var zone_counts: Dictionary = {}
	for child in container.get_children():
		if child is CharacterBody2D and child.has_meta("zone_id"):
			var zid = child.get_meta("zone_id")
			zone_counts[zid] = zone_counts.get(zid, 0) + 1

	for entry in _zone_spawn_data:
		var zone_id: String = entry["zone_id"]
		var current = zone_counts.get(zone_id, 0)
		if current >= MAX_ENEMIES_PER_ZONE:
			continue

		var spawn_data: Dictionary = entry["spawn_data"]
		var enemy_def: EnemyDefinition = entry["enemy_def"]
		var ox: int = entry["ox"]
		var oy: int = entry["oy"]
		var s: int = entry["s"]
		var sx: int = int(spawn_data.get("x", 0))
		var sy: int = int(spawn_data.get("y", 0))
		var sw: int = int(spawn_data.get("width", 4))
		var sh: int = int(spawn_data.get("height", 4))

		# Center of spawn region in world pixels
		var center_x = (ox + (sx + sw / 2.0) * s) * ts
		var center_y = (oy + (sy + sh / 2.0) * s) * ts
		var center = Vector2(center_x, center_y)

		if player_node.global_position.distance_to(center) > ZONE_SPAWN_RADIUS:
			continue

		# Roll spawn chance
		var chance = int(spawn_data.get("chance", 100))
		if randi() % 100 >= chance:
			continue

		# Spawn up to 2 per tick
		var to_spawn = mini(2, MAX_ENEMIES_PER_ZONE - current)
		for _i in range(to_spawn):
			_spawn_overworld_enemy(enemy_scene, container, enemy_def, ox, oy, s, sx, sy, sw, sh, ts, half, zone_id)
		zone_counts[zone_id] = current + to_spawn

func _despawn_far_enemies() -> void:
	var container = get_node_or_null("EnemyContainer")
	if not container:
		return
	var player_node = PlayerQuery.get_primary_player(get_tree())
	if not player_node:
		return
	var player_pos = player_node.global_position
	for child in container.get_children():
		if not (child is CharacterBody2D):
			continue
		# Never despawn quest-spawned enemies
		if child.has_meta("quest_enemy"):
			continue
		if child.global_position.distance_to(player_pos) > ZONE_DESPAWN_RADIUS:
			child.queue_free()

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

## Spawn dedicated mine entrances in specific zones
func _spawn_mine_entrances() -> void:
	var ts := 32
	if ground and ground.tile_set:
		ts = ground.tile_set.tile_size.x
	var half := ts / 2

	# Mine entrance in Haven (Ravenhollow) — south of the wizard's shop (Morin at x:20, y:18)
	for zone in zone_data:
		if zone.id != "haven":
			continue
		if zone.baked_offset == Vector2i(-99999, -99999):
			continue
		var ox := zone.baked_offset.x
		var oy := zone.baked_offset.y
		var s: int = zone.baked_scale if zone.baked_scale > 0 else 1
		# Place mine entrance 2 tiles south of the wizard (zone coords 20, 21)
		var mine_x := 20
		var mine_y := 21
		var mine_pos := Vector2((ox + mine_x * s) * ts + half, (oy + mine_y * s) * ts + half)
		var mine_nodes := _add_entrance(mine_pos, "Haven-Dungeons", ts, "Ironvein Mine")
		if mine_nodes.size() > 0:
			var entrance = mine_nodes[0]
			# Override: this entrance always goes to mine, no sprint needed
			entrance.set_meta("mine_id", "ironvein_depths")
			entrance.set_meta("force_mine", true)
			# Update prompt
			var prompt_lbl = entrance.get_meta("prompt_label", null)
			if prompt_lbl and prompt_lbl is Label:
				if TouchControls.is_mobile():
					prompt_lbl.text = "Tap to Enter Ironvein Mine"
				else:
					prompt_lbl.text = "[E] Enter Ironvein Mine"
			# Add mine entrance visual (darker stairs sprite)
			var sprite := Sprite2D.new()
			sprite.texture = load("res://assets/sprites/loy/maptiles.png")
			sprite.region_enabled = true
			sprite.region_rect = Rect2(5 * 32, 0, 32, 32)  # stairs tile
			sprite.modulate = Color(0.7, 0.5, 0.3)  # brown tint for mine
			sprite.z_index = 1
			entrance.add_child(sprite)
		break

## Spawn Test Arena entrance near player spawn in Aria town
func _spawn_test_arena_entrance() -> void:
	var spawn_px = Vector2(player_spawn_tile.x * 32 + 16, player_spawn_tile.y * 32 + 16)
	var start_offset = Vector2(96, 0)
	var spacing = 64.0
	var entries = [
		{"biome": "Test-Arena", "label": "Test Arena", "tint": Color(1, 1, 1)},
		{"biome": "Test-Arena-Boss", "label": "Boss Arena", "tint": Color(1.0, 0.55, 0.35)},
		{"biome": "TestCombo", "label": "Combo Arena", "tint": Color(0.4, 1.0, 0.4)},
		{"biome": "PushTest", "label": "Push Arena", "tint": Color(1.0, 0.6, 1.0)},
		{"biome": "StealthTest", "label": "Stealth Arena", "tint": Color(0.5, 0.9, 1.0)},
	]
	for i in range(entries.size()):
		var entry = entries[i]
		var entrance_pos = spawn_px + start_offset + Vector2(spacing * i, 0)
		var nodes = _add_entrance(entrance_pos, str(entry["biome"]), 32, str(entry["label"]))
		if nodes.size() <= 0:
			continue
		var entrance = nodes[0]
		var sprite = Sprite2D.new()
		sprite.texture = load("res://assets/sprites/loy/maptiles.png")
		sprite.region_enabled = true
		sprite.region_rect = Rect2(5 * 32, 0, 32, 32)
		sprite.z_index = 1
		sprite.modulate = entry["tint"]
		entrance.add_child(sprite)


## Spawn Height Test entrance near player spawn
func _show_post_tutorial_dialogue() -> void:
	# Wait a couple frames so the QuestManager + DialogueUI are wired up before
	# we ask them to render anything.
	await get_tree().process_frame
	await get_tree().process_frame
	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		return
	qm._waiting_for_dialogue = true
	qm.show_dialogue_requested.emit(
		"Confessor Elias",
		147,
		"You stand in Ravenhollow, Penitent. The work begins here. / / Find me in the chapel — the building marked with the Synod sigil. Walk north until you see the censer-smoke. We have words.",
		["I'll find you"],
	)


func _spawn_height_test_entrance() -> void:
	var spawn_px = Vector2(player_spawn_tile.x * 32 + 16, player_spawn_tile.y * 32 + 16)
	var entrance_pos = spawn_px + Vector2(128, 128)
	var nodes = _add_entrance(entrance_pos, "HeightTest", 32, "Height Test")
	if nodes.size() > 0:
		var entrance = nodes[0]
		var sprite = Sprite2D.new()
		sprite.texture = load("res://assets/sprites/loy/maptiles.png")
		sprite.region_enabled = true
		sprite.region_rect = Rect2(5 * 32, 0, 32, 32)
		sprite.z_index = 1
		sprite.modulate = Color(0.5, 0.7, 1.0)  # blue tint to distinguish
		entrance.add_child(sprite)

## Safe zones where no enemies should spawn (towns, settlements, etc.)
const SAFE_ZONES: Array = [
	"haven", "duskfarm", "wardens", "mirage", "ashheim", "briarvale", "grimhold", "driftport", "saltmere",
	"scorchgate", "smugglers", "wharves", "eldori", "thule", "shrine", "cenneth", "brackwater",
	"kor", "boghollow", "duskwatch", "windhold", "duskport", "bleachbone", "cliffs", "moloch",
	"spire", "hellgate", "sanctum", "llecudd", "willows", "tempid",
]

## Apply or remove town speed boost based on zone safety
func _update_town_speed(zone: LoyZoneData) -> void:
	var player = get_node_or_null("Player")
	if not player or not player.get_node_or_null("StatusEffectManager"):
		return
	var is_safe = zone.id in SAFE_ZONES
	if is_safe and not _town_speed_active:
		_town_speed_active = true
		player.status_effects.apply_buff("town_speed", 9999.0, TOWN_SPEED_MULT - 1.0)
	elif not is_safe and _town_speed_active:
		_town_speed_active = false
		player.status_effects._buffs.erase("town_speed")

func _get_enemy_def_path(monster_name: String) -> String:
	var name_map: Dictionary = {
		"Skeleton": "res://resources/enemies/loy/undead/skeleton.tres",
		"Skeleton Archer": "res://resources/enemies/loy/undead/skeleton_archer.tres",
		"Skeleton Frostbow": "res://resources/enemies/loy/undead/skeleton_frostbow.tres",
		"Bone Bombardier": "res://resources/enemies/loy/undead/bone_bombardier.tres",
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
		"Chicken": "res://resources/enemies/overworld/ow_chicken.tres",
		"Overworld Skeleton": "res://resources/enemies/overworld/ow_skeleton.tres",
		"Overworld Archer": "res://resources/enemies/overworld/ow_skeleton_archer.tres",
		"Golden Skeleton": "res://resources/enemies/overworld/golden_skeleton.tres",
		"Fairy": "res://resources/enemies/overworld/fairy.tres",
		"Overworld Ghost": "res://resources/enemies/overworld/ow_ghost.tres",
		"Scarecrow": "res://resources/enemies/basic/scarecrow.tres",
	}
	if name_map.has(monster_name):
		return name_map[monster_name]
	# Fallback: search all enemy definitions by enemy_name
	for dir_path in ["res://resources/enemies/basic/", "res://resources/enemies/loy/", "res://resources/enemies/custom/"]:
		var snake = monster_name.to_lower().replace(" ", "_")
		var guess = dir_path + snake + ".tres"
		if ResourceLoader.exists(guess):
			var def = load(guess) as EnemyDefinition
			if def and def.enemy_name == monster_name:
				return guess
	return ""

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

func _build_light_occluder_for_shape(shape: CollisionShape2D) -> LightOccluder2D:
	if not (shape.shape is RectangleShape2D):
		return null
	var rect := shape.shape as RectangleShape2D
	var half := rect.size * 0.5
	var polygon := OccluderPolygon2D.new()
	polygon.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	var occluder := LightOccluder2D.new()
	occluder.occluder = polygon
	occluder.position = shape.position
	return occluder

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
	# F11: toggle Sigil HUD ↔ classic HUD (live, no restart)
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F11:
		_toggle_hud_style()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		# Priority 0: Close tile inspector if open
		if _tile_inspector and _tile_inspector.is_open():
			_tile_inspector.hide_info()
			get_viewport().set_input_as_handled()
			return
		# Priority 1: Dungeon entrance
		if _nearby_entrance:
			var sfx = get_node_or_null("/root/SFXManager")
			if sfx:
				sfx.play("teleport", -2.0, 0.0)
			var biome_name = _nearby_entrance.get_meta("biome_name", "Dungeon") as String
			var mine_id = _nearby_entrance.get_meta("mine_id", "") as String
			# Special-case: push/weight test arena is a standalone scene, not a dungeon floor
			if biome_name == "PushTest":
				get_viewport().set_input_as_handled()
				get_tree().change_scene_to_file.call_deferred("res://scenes/test/push_test_arena.tscn")
				return
			if biome_name == "StealthTest":
				get_viewport().set_input_as_handled()
				get_tree().change_scene_to_file.call_deferred("res://scenes/test/stealth_test_arena.tscn")
				return
			var gm = get_node_or_null("/root/GameManager")
			if gm:
				var use_mine = mine_id != "" and bool(_nearby_entrance.get_meta("force_mine", false))
				gm.start_dungeon_run(biome_name, mine_id if use_mine else "")
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


	# Territory panel is now accessed via DIPLOMACY button in WorldMapScreen (M key)

func _get_battle_region_for_zone(zone_id: String) -> Dictionary:
	## Returns {battle_region: Rect2i, player_spawn_rect: Rect2, enemy_spawn_rect: Rect2}
	var ps: Vector2i
	var es: Vector2i
	if BATTLE_REGIONS.has(zone_id):
		ps = BATTLE_REGIONS[zone_id]["ps"]
		es = BATTLE_REGIONS[zone_id]["es"]
	else:
		# Fallback: find nearest waypoint pair by zone baked_offset center
		var zone_center := Vector2.ZERO
		if _current_zone:
			zone_center = Vector2(_current_zone.baked_offset) + Vector2(_current_zone.width, _current_zone.height) * 0.5
		var best_dist := INF
		ps = Vector2i(276, -1)
		es = Vector2i(406, -47)
		for pair in _ALL_WAYPOINT_PAIRS:
			var mid := Vector2(pair[0] + pair[1]) * 0.5
			var d := zone_center.distance_squared_to(mid)
			if d < best_dist:
				best_dist = d
				ps = pair[0]
				es = pair[1]

	# Compute battle_region bounding both spawns + 20 tile margin
	var min_x := mini(ps.x, es.x) - 20
	var min_y := mini(ps.y, es.y) - 20
	var max_x := maxi(ps.x, es.x) + 20
	var max_y := maxi(ps.y, es.y) + 20
	var region := Rect2i(min_x, min_y, max_x - min_x, max_y - min_y)

	# Spawn rects: 800x400 pixel rects centered on each spawn tile
	var ps_px := Vector2(ps.x * 32.0, ps.y * 32.0)
	var es_px := Vector2(es.x * 32.0, es.y * 32.0)
	return {
		"battle_region": region,
		"player_spawn_rect": Rect2(ps_px.x - 400, ps_px.y - 200, 800, 400),
		"enemy_spawn_rect": Rect2(es_px.x - 400, es_px.y - 200, 800, 400),
	}

func _try_start_battle() -> void:
	if not _current_zone:
		return
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return
	var zone_id := _current_zone.id
	var zone_display := _current_zone.zone_name if _current_zone.zone_name != "" else zone_id
	# Check if already owned (use zone ID for consistent key matching)
	if gm.save_data and zone_id in gm.save_data.owned_territories:
		print("Already own %s" % zone_id)
		return

	# --- Player army: hired fighters only ---
	var hired: Dictionary = {}
	if gm.save_data and gm.save_data.army_state.has("hired_fighters"):
		hired = gm.save_data.army_state["hired_fighters"]

	var player_army: Array = []

	# Type mapping for hired fighters
	var type_map := {
		"infantry": BattleUnitSystem.UnitType.INFANTRY,
		"archer": BattleUnitSystem.UnitType.ARCHER,
		"heavy_infantry": BattleUnitSystem.UnitType.HEAVY_INFANTRY,
		"cavalry": BattleUnitSystem.UnitType.CAVALRY,
		"mage": BattleUnitSystem.UnitType.MAGE,
		"heavy_cavalry": BattleUnitSystem.UnitType.HEAVY_CAVALRY,
		"spear": BattleUnitSystem.UnitType.SPEAR,
		"horse_archer": BattleUnitSystem.UnitType.HORSE_ARCHER,
		"ranged_infantry": BattleUnitSystem.UnitType.RANGED_INFANTRY,
	}
	var formation_map := {
		"infantry": BattleUnitSystem.FormationType.LINE,
		"archer": BattleUnitSystem.FormationType.LOOSE_LINE,
		"heavy_infantry": BattleUnitSystem.FormationType.SHIELD_WALL,
		"cavalry": BattleUnitSystem.FormationType.WEDGE,
		"mage": BattleUnitSystem.FormationType.LOOSE_LINE,
		"heavy_cavalry": BattleUnitSystem.FormationType.WEDGE,
		"spear": BattleUnitSystem.FormationType.LINE,
		"horse_archer": BattleUnitSystem.FormationType.LOOSE_LINE,
		"ranged_infantry": BattleUnitSystem.FormationType.LOOSE_LINE,
	}

	# Only use hired fighters — no free militia
	var hired_infantry := int(hired.get("infantry", 0))
	# Minimum 5 militia so the player isn't completely empty if they hired nothing
	var total_infantry := maxi(5, hired_infantry)
	player_army.append({"type": BattleUnitSystem.UnitType.INFANTRY, "count": total_infantry, "formation": BattleUnitSystem.FormationType.LINE})

	# Add other hired types
	for type_name in hired:
		if type_name == "infantry":
			continue  # already merged above
		var count: int = int(hired[type_name])
		if count > 0 and type_map.has(type_name):
			player_army.append({"type": type_map[type_name], "count": count, "formation": formation_map[type_name]})

	# --- Enemy army: use faction or bandit army builder ---
	var fm = get_node_or_null("/root/FactionManager")
	var enemy_army: Array = []
	var army_source := "none"
	if fm:
		var zone_owner: String = fm.get_zone_owner(zone_id)
		if zone_owner != "" and zone_owner != "player" and zone_owner != "bandit" and fm.factions.has(zone_owner):
			enemy_army = fm.build_faction_army(zone_owner)
			army_source = "faction:%s" % zone_owner
		else:
			# Unclaimed, bandit, or unknown faction → default to bandit army sized by zone difficulty
			enemy_army = fm.build_bandit_army(zone_id)
			army_source = "bandit(owner='%s')" % zone_owner
	if enemy_army.is_empty():
		push_warning("Enemy army empty for zone %s — FactionManager missing or uninitialized" % zone_id)
		enemy_army = _build_army_from_budget(80, false)
		army_source = "FALLBACK_BUDGET"
	_log_enemy_army(zone_id, army_source, enemy_army)

	# --- Battle region from zone waypoints ---
	var region_info := _get_battle_region_for_zone(_current_zone.id)

	# Get enemy faction tier and zone count for scaling
	var enemy_tier := 1
	var enemy_zone_count := 0
	if fm:
		var zo: String = fm.get_zone_owner(zone_id)
		if zo != "" and zo != "player" and zo != "bandit" and fm.factions.has(zo):
			enemy_tier = fm.factions[zo].get("tier", 1)
			for zid in fm.territory_owners:
				if fm.territory_owners[zid] == zo:
					enemy_zone_count += 1

	var config := {
		"zone_name": zone_id,
		"zone_display_name": zone_display,
		"tileset": _current_zone.tileset,
		"player_army": player_army,
		"enemy_army": enemy_army,
		"enemy_tier": enemy_tier,
		"enemy_zone_count": enemy_zone_count,
		"battle_region": region_info["battle_region"],
		"player_spawn_rect": region_info["player_spawn_rect"],
		"enemy_spawn_rect": region_info["enemy_spawn_rect"],
	}
	var p_total := 0
	for entry in player_army:
		p_total += entry["count"]
	var e_total := 0
	for entry in enemy_army:
		e_total += entry["count"]
	print("Starting battle for %s — Player: %d units, Enemy: %d units (tier=%d, zones=%d), Region: %s" % [zone_id, p_total, e_total, enemy_tier, enemy_zone_count, str(region_info["battle_region"])])
	gm.start_battle(config)

func _log_enemy_army(zone_id: String, source: String, army: Array) -> void:
	## Debug: print enemy army source + composition when a battle starts so we can
	## verify the faction/bandit builder is actually being used (and not a fallback).
	var total := 0
	var parts := PackedStringArray()
	for e in army:
		var c: int = int(e.get("count", 0))
		total += c
		var t: int = int(e.get("type", 0))
		var tname: String = BattleUnitSystem.UnitType.keys()[t] if t >= 0 and t < BattleUnitSystem.UnitType.size() else str(t)
		parts.append("%s=%d" % [tname, c])
	print("Battle start zone=%s source=%s total=%d [%s]" % [zone_id, source, total, ", ".join(parts)])

func _build_army_from_budget(budget: int, is_player: bool) -> Array:
	# Distribute budget across unit types using percentage allocation
	# Budget unit costs: inf=1, archer=2, spear=1.5, ranged_inf=2, cav=4, heavy_inf=3, heavy_cav=6, horse_archer=4, mage=3
	var army := []
	# Allocate by percentage of budget
	var inf_budget := int(budget * 0.25)
	var archer_budget := int(budget * 0.12)
	var spear_budget := int(budget * 0.12)
	var cav_budget := int(budget * 0.15)
	var heavy_inf_budget := int(budget * 0.10)
	var ranged_inf_budget := int(budget * 0.06)
	var horse_archer_budget := int(budget * 0.08)
	var mage_budget := int(budget * 0.05)
	var heavy_cav_budget := budget - inf_budget - archer_budget - spear_budget - cav_budget - heavy_inf_budget - ranged_inf_budget - horse_archer_budget - mage_budget

	# Convert budget to unit counts (divide by unit cost)
	var entries := [
		[BattleUnitSystem.UnitType.INFANTRY, maxi(5, inf_budget), BattleUnitSystem.FormationType.LINE],
		[BattleUnitSystem.UnitType.SPEAR, maxi(2, int(spear_budget / 1.5)), BattleUnitSystem.FormationType.LINE],
		[BattleUnitSystem.UnitType.HEAVY_INFANTRY, maxi(2, int(heavy_inf_budget / 3.0)), BattleUnitSystem.FormationType.SHIELD_WALL],
		[BattleUnitSystem.UnitType.ARCHER, maxi(2, int(archer_budget / 2.0)), BattleUnitSystem.FormationType.LOOSE_LINE],
		[BattleUnitSystem.UnitType.RANGED_INFANTRY, maxi(1, int(ranged_inf_budget / 2.0)), BattleUnitSystem.FormationType.LOOSE_LINE],
		[BattleUnitSystem.UnitType.CAVALRY, maxi(2, int(cav_budget / 4.0)), BattleUnitSystem.FormationType.WEDGE],
		[BattleUnitSystem.UnitType.HEAVY_CAVALRY, maxi(1, int(heavy_cav_budget / 6.0)), BattleUnitSystem.FormationType.WEDGE],
		[BattleUnitSystem.UnitType.HORSE_ARCHER, maxi(1, int(horse_archer_budget / 4.0)), BattleUnitSystem.FormationType.LOOSE_LINE],
		[BattleUnitSystem.UnitType.MAGE, maxi(1, int(mage_budget / 3.0)), BattleUnitSystem.FormationType.LOOSE_LINE],
	]
	for e in entries:
		if int(e[1]) > 0:
			army.append({"type": e[0], "count": int(e[1]), "formation": e[2]})
	return army

# --- Territory Panel ---
var _territory_panel = null  # TerritoryPanel instance or null
var _attack_notification_label: Label = null
var _attack_notification_tween: Tween = null
var _pending_attack: Dictionary = {}  # {zone_id, faction, army, auto_resolve_time}

func _toggle_territory_panel() -> void:
	if _territory_panel and is_instance_valid(_territory_panel):
		_territory_panel.queue_free()
		_territory_panel = null
		return
	var panel_script = load("res://scripts/ui/territory_panel.gd")
	if not panel_script:
		return
	_territory_panel = panel_script.new()
	_territory_panel.attack_zone.connect(_on_territory_attack)
	_territory_panel.travel_to_zone.connect(_on_territory_travel)
	_territory_panel.closed.connect(func(): _territory_panel = null)
	add_child(_territory_panel)

func get_current_zone_id() -> String:
	if _current_zone:
		return _current_zone.id
	return ""

func _on_territory_travel(zone_id: String) -> void:
	## Player chose to fast-travel to an owned zone.
	var zone_path := "res://resources/world/zones/%s.tres" % zone_id
	if not ResourceLoader.exists(zone_path):
		print("Travel failed: zone %s not found" % zone_id)
		return
	var zd = load(zone_path) as LoyZoneData
	if not zd or zd.baked_offset == Vector2i(-99999, -99999):
		print("Travel failed: zone %s has no baked offset" % zone_id)
		return

	# Calculate zone center in pixel coordinates
	var s: int = zd.baked_scale if zd.baked_scale > 0 else 1
	var w: int = (zd.width if zd.width > 0 else 50) * s
	var h: int = (zd.height if zd.height > 0 else 50) * s
	var center_tile := Vector2(zd.baked_offset.x + w * 0.5, zd.baked_offset.y + h * 0.5)
	var target_px := center_tile * 32.0

	# Teleport player
	var player = PlayerQuery.get_primary_player(get_tree())
	if not player:
		player = $Player
	if player:
		player.global_position = target_px
		# Force zone switch
		_current_zone = zd
		_switch_to_zone(zd)
		# Force chunk reload by resetting last chunk tracker
		_last_chunk = Vector2i(-99999, -99999)
		var display: String = zd.zone_name if zd.zone_name != "" else zd.id
		_show_zone_name("Traveled to %s" % display)
		print("Fast travel to %s at pixel %s" % [zone_id, target_px])

func _on_territory_attack(zone_id: String) -> void:
	## Player chose to attack a zone from the territory panel.
	if not _current_zone:
		return
	var gm = get_node_or_null("/root/GameManager")
	var fm = get_node_or_null("/root/FactionManager")
	if not gm or not fm:
		return

	var zone_display := zone_id
	var zone_path := "res://resources/world/zones/%s.tres" % zone_id
	if ResourceLoader.exists(zone_path):
		var zd = load(zone_path)
		if zd and zd is LoyZoneData and zd.zone_name != "":
			zone_display = zd.zone_name

	# Build player army (same as _try_start_battle)
	var hired: Dictionary = {}
	if gm.save_data and gm.save_data.army_state.has("hired_fighters"):
		hired = gm.save_data.army_state["hired_fighters"]
	var player_army: Array = []
	var type_map := {
		"infantry": BattleUnitSystem.UnitType.INFANTRY,
		"archer": BattleUnitSystem.UnitType.ARCHER,
		"heavy_infantry": BattleUnitSystem.UnitType.HEAVY_INFANTRY,
		"cavalry": BattleUnitSystem.UnitType.CAVALRY,
		"mage": BattleUnitSystem.UnitType.MAGE,
		"heavy_cavalry": BattleUnitSystem.UnitType.HEAVY_CAVALRY,
		"spear": BattleUnitSystem.UnitType.SPEAR,
		"horse_archer": BattleUnitSystem.UnitType.HORSE_ARCHER,
		"ranged_infantry": BattleUnitSystem.UnitType.RANGED_INFANTRY,
	}
	var formation_map := {
		"infantry": BattleUnitSystem.FormationType.LINE,
		"archer": BattleUnitSystem.FormationType.LOOSE_LINE,
		"heavy_infantry": BattleUnitSystem.FormationType.SHIELD_WALL,
		"cavalry": BattleUnitSystem.FormationType.WEDGE,
		"mage": BattleUnitSystem.FormationType.LOOSE_LINE,
		"heavy_cavalry": BattleUnitSystem.FormationType.WEDGE,
		"spear": BattleUnitSystem.FormationType.LINE,
		"horse_archer": BattleUnitSystem.FormationType.LOOSE_LINE,
		"ranged_infantry": BattleUnitSystem.FormationType.LOOSE_LINE,
	}
	var hired_infantry := int(hired.get("infantry", 0))
	var total_infantry := maxi(5, hired_infantry)
	player_army.append({"type": BattleUnitSystem.UnitType.INFANTRY, "count": total_infantry, "formation": BattleUnitSystem.FormationType.LINE})
	for type_name in hired:
		if type_name == "infantry":
			continue
		var count: int = int(hired[type_name])
		if count > 0 and type_map.has(type_name):
			player_army.append({"type": type_map[type_name], "count": count, "formation": formation_map[type_name]})

	# Enemy army from faction or bandit army builder
	var owner: String = fm.get_zone_owner(zone_id)
	var enemy_army: Array = []
	var army_source := "none"
	if owner != "" and owner != "player" and owner != "bandit" and fm.factions.has(owner):
		enemy_army = fm.build_faction_army(owner)
		army_source = "faction:%s" % owner
	else:
		enemy_army = fm.build_bandit_army(zone_id)
		army_source = "bandit(owner='%s')" % owner
	if enemy_army.is_empty():
		push_warning("Enemy army empty for zone %s (territory attack)" % zone_id)
		enemy_army = _build_army_from_budget(80, false)
		army_source = "FALLBACK_BUDGET"
	_log_enemy_army(zone_id, army_source, enemy_army)

	var enemy_tier: int = 1
	var enemy_zone_count: int = 0
	if fm.factions.has(owner):
		enemy_tier = int(fm.factions[owner].get("tier", 1))
		enemy_zone_count = int(fm.factions[owner].get("zones", []).size())
	var zone_tileset: int = 0
	if ResourceLoader.exists(zone_path):
		var zd2 = load(zone_path)
		if zd2 and zd2 is LoyZoneData:
			zone_tileset = zd2.tileset

	var region_info := _get_battle_region_for_zone(zone_id)
	var config := {
		"zone_name": zone_id,
		"zone_display_name": zone_display,
		"tileset": zone_tileset,
		"player_army": player_army,
		"enemy_army": enemy_army,
		"enemy_tier": enemy_tier,
		"enemy_zone_count": enemy_zone_count,
		"battle_region": region_info["battle_region"],
		"player_spawn_rect": region_info["player_spawn_rect"],
		"enemy_spawn_rect": region_info["enemy_spawn_rect"],
	}
	print("Territory attack: %s (owner=%s, tier=%d, zones=%d)" % [zone_id, owner, enemy_tier, enemy_zone_count])
	gm.start_battle(config)

func _setup_attack_notifications() -> void:
	var fm = get_node_or_null("/root/FactionManager")
	if fm and not fm.territory_attacked.is_connected(_on_territory_attacked):
		fm.territory_attacked.connect(_on_territory_attacked)

func _on_territory_attacked(zone_id: String, attacker_faction: String, attacker_army: Array) -> void:
	var fm = get_node_or_null("/root/FactionManager")
	var faction_name := attacker_faction
	if fm and fm.factions.has(attacker_faction):
		faction_name = str(fm.factions[attacker_faction].get("name", attacker_faction))

	_pending_attack = {
		"zone_id": zone_id,
		"faction": attacker_faction,
		"army": attacker_army,
		"auto_resolve_time": Time.get_ticks_msec() + 60000,  # 60 second window
	}

	# Show attack notification
	_show_attack_notification("%s is attacking %s!" % [faction_name, zone_id.capitalize()])
	print("ATTACK: %s attacks %s — auto-resolves in 60s" % [faction_name, zone_id])

func _show_attack_notification(text: String) -> void:
	if _attack_notification_label and is_instance_valid(_attack_notification_label):
		_attack_notification_label.queue_free()
	if _attack_notification_tween:
		_attack_notification_tween.kill()

	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	_attack_notification_label = Label.new()
	_attack_notification_label.text = text
	_attack_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attack_notification_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_attack_notification_label.position.y = 60
	var ls := LabelSettings.new()
	ls.font_size = 26
	ls.font_color = Color(1.0, 0.3, 0.2)
	ls.outline_size = 3
	ls.outline_color = Color(0, 0, 0)
	_attack_notification_label.label_settings = ls
	canvas.add_child(_attack_notification_label)

	# Fade in, hold, fade out
	_attack_notification_tween = create_tween()
	_attack_notification_label.modulate.a = 0.0
	_attack_notification_tween.tween_property(_attack_notification_label, "modulate:a", 1.0, 0.5)
	_attack_notification_tween.tween_interval(5.0)
	_attack_notification_tween.tween_property(_attack_notification_label, "modulate:a", 0.0, 1.0)
	_attack_notification_tween.tween_callback(func():
		if is_instance_valid(canvas):
			canvas.queue_free()
	)

func _check_pending_attack_auto_resolve() -> void:
	if _pending_attack.is_empty():
		return
	if Time.get_ticks_msec() > _pending_attack.get("auto_resolve_time", 0):
		# Auto-resolve: garrison vs attacker
		var fm = get_node_or_null("/root/FactionManager")
		var gm = get_node_or_null("/root/GameManager")
		if fm:
			var garrison_strength := 0
			if gm and gm.save_data and gm.save_data.army_state.has("garrisons"):
				var garrisons: Dictionary = gm.save_data.army_state["garrisons"]
				var zone_garrison: Dictionary = garrisons.get(_pending_attack["zone_id"], {})
				for type_name in zone_garrison:
					garrison_strength += int(zone_garrison[type_name])
			var defended: bool = fm.auto_resolve_attack(
				str(_pending_attack["zone_id"]),
				str(_pending_attack["faction"]),
				garrison_strength
			)
			if defended:
				_show_attack_notification("Garrison defended %s!" % str(_pending_attack["zone_id"]).capitalize())
			else:
				_show_attack_notification("%s has fallen!" % str(_pending_attack["zone_id"]).capitalize())
				if fm:
					fm.save_to(gm.save_data)
					gm.save_data.save_to_slot()
		_pending_attack = {}

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
	var sfx_dr = get_node_or_null("/root/SFXManager")
	if sfx_dr:
		sfx_dr.play("bay_door_open", -4.0, 0.1)
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

var _game_hud: CanvasLayer  ## SigilHUD or GameHUD — both share the public API used here.
var _quest_world_marker: Node2D
var _quest_world_marker_pos: Vector2 = Vector2.ZERO
var _perf_overlay: PerfOverlay = null

func _setup_game_hud(player_node: CharacterBody2D) -> void:
	_game_hud = SigilHUD.new() if (UIPrefs.use_sigil_hud and not TouchControls.is_mobile()) else GameHUD.new()
	add_child(_game_hud)
	_game_hud.setup(player_node)

## Live-swap between Sigil and classic HUD. Player keeps the active scene.
func _toggle_hud_style() -> void:
	var new_use_sigil := UIPrefs.toggle_hud()
	var player_node = get_node_or_null("Player") as CharacterBody2D
	if not player_node:
		return
	if _game_hud:
		_game_hud.queue_free()
		_game_hud = null
	_setup_game_hud(player_node)
	if _game_hud and _game_hud.has_method("flash_text"):
		_game_hud.flash_text("HUD: " + ("Sigil" if new_use_sigil else "Classic"), Color(0.918, 0.702, 0.031), 2.0)
	if not player_node.player_died.is_connected(_on_player_died):
		player_node.player_died.connect(_on_player_died)
	_update_gold_label()

	# Loot bag UI
	var loot_ui = LootBagUI.new()
	add_child(loot_ui)
	loot_ui.setup(player_node.equipment_manager)

	# Chest UI (scrollable container UI for test chests)
	var chest_ui = ChestUI.new()
	add_child(chest_ui)
	chest_ui.setup(player_node.equipment_manager)

	# Tile inspector popup
	_tile_inspector = TileInspector.new()
	add_child(_tile_inspector)

func _on_quest_arrow_update(_quest_id: String) -> void:
	_update_quest_arrow()

func _update_quest_arrow() -> void:
	if not _game_hud:
		return
	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		_game_hud.clear_quest_objective()
		_hide_world_marker()
		return
	var quest_id = qm.get_first_active_quest_id()
	if quest_id == "":
		_game_hud.clear_quest_objective()
		_hide_world_marker()
		return
	var pos = qm.get_quest_objective_position(quest_id)
	if pos == Vector2.ZERO:
		_game_hud.clear_quest_objective()
		_hide_world_marker()
		return

	# Try to snap to nearest dungeon entrance in target zone
	var quest = qm.definitions.get(quest_id) as QuestDefinition
	var label = quest.title if quest else ""
	# For dungeon quests, use a larger search radius to ensure we find the entrance
	var search_radius = 800.0 if (quest and quest.boss_dungeon != "") else 400.0
	var entrance_pos = _find_nearest_entrance_near(pos, search_radius)
	if entrance_pos != Vector2.ZERO:
		pos = entrance_pos

	# World marker at target + HUD arrow as off-screen fallback
	_game_hud.set_quest_objective(pos, label)
	_show_world_marker(pos, label)
	print("QUEST MARKER: pos=%s label=%s quest=%s" % [pos, label, quest_id])

func _find_nearest_entrance_near(target_pos: Vector2, max_dist: float = 400.0) -> Vector2:
	## Find the closest dungeon entrance within max_dist of target_pos.
	var best_dist := max_dist
	var best_pos := Vector2.ZERO
	for child in get_children():
		if child is Area2D and child.has_meta("biome_name"):
			var d = child.global_position.distance_to(target_pos)
			if d < best_dist:
				best_dist = d
				best_pos = child.global_position
	return best_pos

func _show_world_marker(world_pos: Vector2, label_text: String) -> void:
	_quest_world_marker_pos = world_pos
	if not _quest_world_marker:
		_quest_world_marker = _QuestWorldMarker.new()
		add_child(_quest_world_marker)
	_quest_world_marker.global_position = world_pos
	_quest_world_marker.set_label(label_text)
	_quest_world_marker.visible = true

func _hide_world_marker() -> void:
	_quest_world_marker_pos = Vector2.ZERO
	if _quest_world_marker:
		_quest_world_marker.visible = false

class _QuestWorldMarker extends Node2D:
	## In-world floating quest marker: bobbing diamond + label above target position.
	var _elapsed: float = 0.0
	var _label: Label
	var _label_text: String = ""

	func _ready() -> void:
		z_index = 100
		_label = Label.new()
		var settings = LabelSettings.new()
		settings.font_size = 8
		settings.font_color = Color(1.0, 0.95, 0.6)
		settings.outline_size = 2
		settings.outline_color = Color(0, 0, 0)
		_label.label_settings = settings
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.position = Vector2(-50, -42)
		_label.size = Vector2(100, 16)
		add_child(_label)

	func set_label(text: String) -> void:
		_label_text = text
		if _label:
			_label.text = text

	func _process(delta: float) -> void:
		_elapsed += delta
		queue_redraw()

	func _draw() -> void:
		# Bobbing offset
		var bob = sin(_elapsed * 3.0) * 4.0
		var y_off = -24.0 + bob

		# Draw downward-pointing arrow/diamond (large, visible)
		var pts = PackedVector2Array([
			Vector2(0, y_off + 12),   # bottom point
			Vector2(-8, y_off),       # left
			Vector2(0, y_off - 10),   # top
			Vector2(8, y_off),        # right
		])
		draw_colored_polygon(pts, Color(1.0, 0.85, 0.15, 0.95))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
			Color(0.9, 0.6, 0.0), 1.5)

		# Vertical line from diamond to ground
		draw_line(Vector2(0, y_off + 12), Vector2(0, 4), Color(1.0, 0.85, 0.2, 0.6), 1.0)

		# Pulsing glow circle at ground level
		var pulse = 0.4 + 0.2 * sin(_elapsed * 4.0)
		draw_circle(Vector2(0, 4), 8.0, Color(1.0, 0.85, 0.2, pulse))

func _on_player_died() -> void:
	var player_node = get_node_or_null("Player")
	if not player_node:
		return

	# Pause game and show death screen overlay
	get_tree().paused = true
	player_node.process_mode = Node.PROCESS_MODE_DISABLED

	var death_overlay = _build_death_overlay()
	add_child(death_overlay)

	# Wait for player to leave the overlay (Hall transition)
	await death_overlay.tree_exited

func _build_death_overlay() -> CanvasLayer:
	var layer = CanvasLayer.new()
	layer.layer = 200
	layer.process_mode = Node.PROCESS_MODE_ALWAYS

	var vp_size = Vector2(1920, 1080)  # match project viewport

	# Dark overlay background — explicit size since CanvasLayer has no layout
	var overlay = ColorRect.new()
	overlay.position = Vector2.ZERO
	overlay.size = vp_size
	overlay.color = Color(0.02, 0.02, 0.05, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)

	# Fade in dark overlay
	var fade = overlay.create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(overlay, "color:a", 0.92, 0.8)

	# Centered VBox — explicit size, centers children vertically
	var center = VBoxContainer.new()
	center.position = Vector2.ZERO
	center.size = vp_size
	center.add_theme_constant_override("separation", 20)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	layer.add_child(center)

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
	center.add_child(title)

	var t_tw = title.create_tween()
	t_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t_tw.tween_interval(0.5)
	t_tw.tween_property(title, "modulate:a", 1.0, 0.6)

	# Subtitle
	var sub = Label.new()
	sub.text = "Your equipment has been lost..."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub_s = LabelSettings.new()
	sub_s.font_size = 20
	sub_s.font_color = Color(0.7, 0.6, 0.6)
	sub.label_settings = sub_s
	sub.modulate.a = 0.0
	center.add_child(sub)

	var s_tw = sub.create_tween()
	s_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	s_tw.tween_interval(1.2)
	s_tw.tween_property(sub, "modulate:a", 1.0, 0.5)

	# Hall button
	var btn = Button.new()
	btn.text = "Enter Hall of Ancestors"
	btn.custom_minimum_size = Vector2(200, 50)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 22)
	btn.focus_mode = Control.FOCUS_NONE
	btn.modulate.a = 0.0

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
	center.add_child(btn)

	var b_tw = btn.create_tween()
	b_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	b_tw.tween_interval(2.0)
	b_tw.tween_property(btn, "modulate:a", 1.0, 0.4)

	btn.pressed.connect(func():
		var gm = get_node_or_null("/root/GameManager")
		get_tree().paused = false
		layer.queue_free()
		if gm:
			gm.on_character_death()
			gm.call_deferred("go_to_hall_of_ancestors")
	)
	return layer

func _update_gold_label() -> void:
	if not _game_hud:
		return
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.save_data:
		_game_hud.set_gold(gm.save_data.gold)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_water_shader()
	_update_gold_label()
	_poll_async_loads()
	_update_current_zone()
	_update_chunks()
	_drain_unload_queue()
	_process_ready_chunks()
	_drain_tile_queue()
	_check_respawns(_delta)
	_check_pending_attack_auto_resolve()
	if _debug_tile_labels_visible:
		_debug_update_labels()

func _setup_water_shader() -> void:
	if water == null:
		return
	_water_shader_material = ShaderMaterial.new()
	_water_shader_material.shader = LIQUID_SURFACE_SHADER
	_water_shader_material.set_shader_parameter("tile_size", 32.0)
	_water_shader_material.set_shader_parameter("active_liquid_type", 1)
	_water_shader_material.set_shader_parameter("player_world_pos", Vector2.ZERO)
	water.material = _water_shader_material

func _update_water_shader() -> void:
	if _water_shader_material == null:
		return
	var player = get_node_or_null("Player")
	if player and is_instance_valid(player):
		_water_shader_material.set_shader_parameter("player_world_pos", player.global_position)

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
			# Always load chunks within LOAD_RADIUS of player (no zone filter)
			# Zone filter only applies to prefetch beyond LOAD_RADIUS
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

	for occluder in chunk_info.get("shadow_occluders", []):
		if is_instance_valid(occluder):
			occluder.queue_free()

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
		# Source 5/6 (tiles.png, tiles2.png) on fences = trees/barriers — block
		if source == 5 or source == 6:
			return true
	# Decorations layer = walkable scatter (flowers, grass) — never blocks
	return false

func _generate_chunk_collisions(chunk_key: Vector2i, chunk_info: Dictionary) -> void:
	var tile_size = 32
	var half = tile_size / 2
	var blocking_set: Dictionary = {}
	var door_set: Dictionary = {}
	var shadow_occluders: Array = []

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
		var door_occluder = _build_light_occluder_for_shape(shape)
		if door_occluder and _shadow_occluders:
			_shadow_occluders.add_child(door_occluder)
			shadow_occluders.append(door_occluder)
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
				var occ = _build_light_occluder_for_shape(s)
				if occ and _shadow_occluders:
					_shadow_occluders.add_child(occ)
					shadow_occluders.append(occ)
				run_start = xs[i]
				run_end = xs[i]
		var s = _add_merged_shape(_wall_body, run_start, run_end, y, tile_size, half)
		chunk_info["shapes"].append(s)
		var occ = _build_light_occluder_for_shape(s)
		if occ and _shadow_occluders:
			_shadow_occluders.add_child(occ)
			shadow_occluders.append(occ)
	chunk_info["shadow_occluders"] = shadow_occluders

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

func _spawn_temp_portal(pos: Vector2) -> void:
	var portal = Area2D.new()
	portal.name = "TempTownPortal"
	portal.position = pos
	portal.collision_layer = 0
	portal.collision_mask = 1
	# Visual
	var sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex = load("res://assets/sprites/loy/tiles.png") as Texture2D
	if tex:
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(3 * 32, 6 * 32, 32, 32)
		sprite.texture = atlas
	sprite.modulate = Color(0.5, 0.8, 1.5, 1.0)
	portal.add_child(sprite)
	# Collision
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	portal.add_child(shape)
	# Label
	var label = Label.new()
	label.text = "Portal"
	var settings = LabelSettings.new()
	settings.font_size = 10
	settings.font_color = Color(0.6, 0.9, 1.0)
	settings.outline_size = 2
	settings.outline_color = Color.BLACK
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-30, -24)
	label.size = Vector2(60, 14)
	portal.add_child(label)
	# Pulsing glow
	var tween = portal.create_tween().set_loops()
	tween.tween_property(sprite, "modulate", Color(0.8, 1.0, 2.0, 1.0), 0.8)
	tween.tween_property(sprite, "modulate", Color(0.5, 0.8, 1.5, 1.0), 0.8)
	add_child(portal)
	# Auto-remove after 10 seconds with fade
	var fade_tween = portal.create_tween()
	fade_tween.tween_interval(8.0)
	fade_tween.tween_property(sprite, "modulate:a", 0.0, 2.0)
	fade_tween.tween_callback(portal.queue_free)
	print("Overworld: Temporary town portal spawned at %s (10s lifetime)" % pos)

func _exit_tree() -> void:
	if has_node("/root/PerfTelemetry"):
		PerfTelemetry.detach_scene(self)
