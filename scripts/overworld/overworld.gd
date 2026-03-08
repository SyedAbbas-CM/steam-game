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

const CHUNK_SIZE = 64  # tiles per chunk side
const LOAD_RADIUS = 3  # chunks loaded around player
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

	var t0 = Time.get_ticks_msec()
	var player = $Player
	player.scale = Vector2(4, 4)

	# Fix camera zoom at runtime (scene .scn may have stale values)
	var cam = player.get_node_or_null("Camera2D")
	if cam:
		cam.zoom = Vector2(1.6, 1.6)

	# Phase 1: Essential setup
	_load_zone_data()
	print("TIMING: overworld _load_zone_data took %d ms" % (Time.get_ticks_msec() - t0))
	_setup_hud(player)

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
	_wall_body.collision_layer = 16
	_wall_body.collision_mask = 0
	add_child(_wall_body)

	# Check if pre-baked chunks exist and are up-to-date
	var index_path = "res://resources/world/chunks/index.tres"
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

	# Load chunks near player start position (immediately, not queued)
	var player = $Player
	var tile_pos = Vector2i(int(player.position.x / 32), int(player.position.y / 32))
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
	var chunk_path = "res://resources/world/chunks/chunk_%s.tres" % key_str
	if not ResourceLoader.exists(chunk_path):
		return
	ResourceLoader.load_threaded_request(chunk_path)
	_pending_loads[key_str] = true

## Check pending async loads and move completed ones to cache
func _poll_async_loads() -> void:
	var done: Array = []
	for key_str in _pending_loads:
		var chunk_path = "res://resources/world/chunks/chunk_%s.tres" % key_str
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
	var chunk_path = "res://resources/world/chunks/chunk_%s.tres" % key_str
	var res = load(chunk_path)
	if res:
		_chunk_cache[key_str] = res
	return res

func _load_initial_chunks(center: Vector2i) -> void:
	# Load only the closest ring synchronously (essential for first frame)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			_load_chunk_immediate(Vector2i(center.x + dx, center.y + dy))
	# Request the rest of LOAD_RADIUS async (will paint incrementally)
	for dy in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			if abs(dx) <= 1 and abs(dy) <= 1:
				continue  # already loaded sync
			var key_str = "%d_%d" % [center.x + dx, center.y + dy]
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
	_spawn_zone_enemies()
	print("TIMING: overworld spawn enemies took %d ms" % (Time.get_ticks_msec() - t1))
	_spawn_equipment_bag()

	# UI overlays
	var dialogue_ui = DialogueUI.new()
	add_child(dialogue_ui)
	var quest_log = QuestLog.new()
	add_child(quest_log)
	var shop_ui = ShopUI.new()
	add_child(shop_ui)

	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		qm.on_zone_entered("aria")

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

func _add_entrance(pos: Vector2, biome_name: String, tile_size: int = 32, display_name: String = "") -> Array:
	if display_name == "":
		display_name = biome_name
	var nodes: Array = []
	var entrance = Area2D.new()
	entrance.position = pos
	entrance.collision_layer = 0
	entrance.collision_mask = 1
	entrance.set_meta("biome_name", biome_name)

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(tile_size, tile_size)
	shape.shape = rect
	entrance.add_child(shape)

	entrance.body_entered.connect(_on_entrance_entered.bind(biome_name))
	add_child(entrance)
	nodes.append(entrance)

	var sign_label = _add_zone_sign(pos + Vector2(tile_size, 0), display_name)
	if sign_label:
		nodes.append(sign_label)
	return nodes

func _on_entrance_entered(body: Node2D, biome_name: String) -> void:
	if body.is_in_group("player"):
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.start_dungeon_run(biome_name)

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
			var sx = int(spawn_data.get("x", 0))
			var sy = int(spawn_data.get("y", 0))
			var sw = int(spawn_data.get("width", 1))
			var sh = int(spawn_data.get("height", 1))
			var chance = int(spawn_data.get("chance", 50))

			var enemy_def = _get_cached_enemy_def(monster_type)
			if not enemy_def:
				continue

			var num_spawns = maxi(1, (sw * sh) / 30)
			for _i in range(num_spawns):
				if randi() % 100 >= chance:
					continue
				var ex = sx + randi() % maxi(1, sw)
				var ey = sy + randi() % maxi(1, sh)
				var enemy = enemy_scene.instantiate()
				enemy.global_position = Vector2(
					(ox + ex * s) * ts + half,
					(oy + ey * s) * ts + half
				)
				if enemy.has_method("setup"):
					var ow_def = enemy_def.duplicate()
					# Overworld enemies just chase + contact, no shooting
					ow_def.attack_type = EnemyDefinition.AttackType.NONE
					ow_def.move_speed = 15.0
					ow_def.preferred_distance = 0.0
					ow_def.bullet_count = 0
					enemy.setup(ow_def)
				enemy.scale = Vector2(4, 4)  # match player's 4x overworld scale
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
	bag.position = Vector2(48, 48)
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
		_try_open_door()

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

var _hp_label: Label
var _gold_label: Label

func _setup_hud(player_node: CharacterBody2D) -> void:
	var hud = CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 10
	add_child(hud)

	var settings = LabelSettings.new()
	settings.font_size = 28
	settings.outline_size = 3
	settings.outline_color = Color.BLACK

	_hp_label = Label.new()
	_hp_label.label_settings = settings
	_hp_label.position = Vector2(20, 10)
	hud.add_child(_hp_label)

	_gold_label = Label.new()
	_gold_label.label_settings = settings
	_gold_label.position = Vector2(20, 45)
	hud.add_child(_gold_label)

	player_node.hp_changed.connect(_on_player_hp_changed)
	player_node.player_died.connect(_on_player_died)
	_on_player_hp_changed(player_node.hp)
	_update_gold_label()

func _on_player_hp_changed(new_hp: int) -> void:
	var player_node = get_node_or_null("Player")
	if player_node:
		_hp_label.text = "HP: " + str(new_hp) + "/" + str(player_node.max_hp)

func _on_player_died() -> void:
	var player_node = get_node_or_null("Player")
	if player_node:
		player_node.hp = player_node.max_hp
		player_node.hp_changed.emit(player_node.hp)
		player_node.global_position = Vector2(48, 48)
		player_node.invincible = true
		var tween = create_tween()
		for i in range(8):
			tween.tween_property(player_node.sprite, "modulate:a", 0.2, 0.1)
			tween.tween_property(player_node.sprite, "modulate:a", 1.0, 0.1)
		tween.tween_callback(func(): player_node.invincible = false)

func _update_gold_label() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.save_data:
		_gold_label.text = "Gold: " + str(gm.save_data.gold)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_gold_label()
	_poll_async_loads()
	_update_chunks()
	_drain_unload_queue()
	_process_ready_chunks()
	_drain_tile_queue()

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
			needed[Vector2i(center.x + dx, center.y + dy)] = true

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

	# Prefetch chunks beyond load radius
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

	var chunk_info = {"cells": {}, "shapes": [], "entrances": []}
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
			# Skip chunks already in load radius
			if abs(dx) <= LOAD_RADIUS and abs(dy) <= LOAD_RADIUS:
				continue
			var key_str = "%d_%d" % [center.x + dx, center.y + dy]
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
	var chunk_info = {"cells": {}, "shapes": [], "entrances": []}

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
			for i in range(0, arr.size(), 5):
				var cell = Vector2i(arr[i], arr[i + 1])
				layer.set_cell(cell, arr[i + 2], Vector2i(arr[i + 3], arr[i + 4]))
				cells_list.append(cell)
			chunk_info["cells"][layer_name] = cells_list
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
	var chunk_info = {"cells": {}, "shapes": [], "entrances": []}
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
		for tile_info in tile_list:
			layer.set_cell(tile_info[0], tile_info[1], tile_info[2])
			cells_list.append(tile_info[0])
		chunk_info["cells"][layer_name] = cells_list

func _unload_chunk(chunk_key: Vector2i) -> void:
	var chunk_info = _loaded_chunks.get(chunk_key)
	if not chunk_info:
		return
	_loaded_chunks.erase(chunk_key)

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

func _generate_chunk_collisions(chunk_key: Vector2i, chunk_info: Dictionary) -> void:
	var tile_size = 32
	var half = tile_size / 2
	var blocking_set: Dictionary = {}
	var door_set: Dictionary = {}

	# Blocking layers: decorations, buildings, fences, water
	for layer_name in ["decorations", "buildings", "fences", "water"]:
		var cells = chunk_info["cells"].get(layer_name, []) as Array
		var layer = _all_layers[layer_name] as TileMapLayer
		for cell in cells:
			var atlas = layer.get_cell_atlas_coords(cell)
			if _is_stairs_tile(atlas, tile_size):
				continue
			blocking_set[cell] = true
			if _is_door_tile(atlas, tile_size):
				door_set[cell] = true

	# Void border tiles (ground tiles adjacent to walkable)
	var ground_cells = chunk_info["cells"].get("ground", []) as Array
	var walkable_set: Dictionary = {}
	var void_cells: Array = []
	var ground_layer = _all_layers["ground"] as TileMapLayer
	for cell in ground_cells:
		var source = ground_layer.get_cell_source_id(cell)
		if source == 0:
			walkable_set[cell] = true
		else:
			void_cells.append(cell)

	for cell in void_cells:
		for offset in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			if walkable_set.has(cell + offset):
				blocking_set[cell] = true
				break

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
