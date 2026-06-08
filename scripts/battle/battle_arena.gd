extends Node2D

# Battle arena orchestrator — fights happen on real overworld terrain
# Player runs around fighting alongside their army. Tab toggles command mode.
#
# battle_config = {
#   "zone_name": String,
#   "battle_region": Rect2i (tile coords of battlefield),
#   "player_army": [ { "type": UnitType, "count": int, "formation": FormationType }, ... ],
#   "enemy_army":  [ { "type": UnitType, "count": int, "formation": FormationType }, ... ],
#   "player_spawn_rect": Rect2 (pixel coords, optional),
#   "enemy_spawn_rect": Rect2 (pixel coords, optional),
# }

const TILE_SIZE := 32
const FRICTION := 0.92

# Cached tileset — saved to .tres on first use so we don't re-instantiate the overworld scene
const TILESET_CACHE_PATH := "res://resources/world/overworld_tileset.tres"
static var _cached_tileset: TileSet = null

static func _get_overworld_tileset() -> TileSet:
	if _cached_tileset:
		return _cached_tileset
	# Try loading saved tileset first (fast: ~5ms vs 290ms)
	if ResourceLoader.exists(TILESET_CACHE_PATH):
		_cached_tileset = load(TILESET_CACHE_PATH) as TileSet
		if _cached_tileset:
			return _cached_tileset
	# Fallback: extract from the live runtime overworld scene and save for next time.
	# Do not reference editor-only world variants here or exports will drag them in.
	for path in ["res://scenes/overworld/overworld_light.tscn"]:
		if ResourceLoader.exists(path):
			var ow_scene = load(path) as PackedScene
			if ow_scene:
				var ow = ow_scene.instantiate()
				var gl = ow.get_node_or_null("Ground") as TileMapLayer
				if gl:
					_cached_tileset = gl.tile_set.duplicate()
					ResourceSaver.save(_cached_tileset, TILESET_CACHE_PATH)
					print("BattleArena: Saved tileset cache to %s" % TILESET_CACHE_PATH)
				ow.queue_free()
				break
	return _cached_tileset

# -- Systems (SoA physics) --
var units: BattleUnitSystem
var projectiles: BattleProjectileSystem
var commander: BattleCommander
var collision: BattleCollision
var ai: BattleSimpleAI

# -- Visual / UI --
var renderer: BattleRenderer
var hud: BattleHUD
var game_hud: Node  # GameHUD (the normal game UI with HP/MP/stamina)
var command_overlay: BattleCommandOverlay
var fog: BattleFogOfWar
var cam: Camera2D

# -- Player --
var player: CharacterBody2D
var _player_scene: PackedScene = preload("res://scenes/player.tscn")

# -- Terrain collision --
var _wall_body: StaticBody2D

# -- Terrain layers --
var ground_layer: TileMapLayer
var paths_layer: TileMapLayer
var water_layer: TileMapLayer
var decor_layer: TileMapLayer
var buildings_layer: TileMapLayer
var fences_layer: TileMapLayer

# -- State --
var _blocked_tiles: Dictionary = {}  # Vector2i -> true
var battle_time: float = 0.0

var _deferred_visual_data: Array = []  # [[TileMapLayer, PackedInt32Array], ...]
var _deferred_load_index: int = 0
var speed_multiplier: float = 1.0
var battle_ended: bool = false
var _initial_blue_count: int = 0
var _initial_red_count: int = 0
var command_mode: bool = false

# Commander switching — player can switch camera focus between commander units
var _active_commander_index: int = -1  # -1 = controlling main player, 0+ = index into _blue_commanders
var _blue_commanders: PackedInt32Array = PackedInt32Array()  # unit indices of BLUE commander units
var _commander_switch_cooldown: float = 0.0

# Wave spawning
const WAVE_THRESHOLD := 100
const WAVE_SIZE := 80
const WAVE_INTERVAL := 30.0
const MAX_RED_WAVES := 2  # Cap enemy reinforcements to prevent endless battles
var _pending_blue_waves: Array = []  # Array of army arrays
var _pending_red_waves: Array = []
var _wave_timer: float = 0.0

# Deferred chunk loading state
var _chunk_paths: Array[String] = []
var _chunk_load_index: int = 0
var _chunks_done: bool = false
var _battle_initialized: bool = false
const CHUNKS_PER_FRAME := 8
var _all_layer_map: Dictionary = {}
var _blocking_layers: Array[String] = ["water", "buildings", "fences"]
var _config: Dictionary = {}

# Performance tracking
var _perf_frame: int = 0
var _perf: Dictionary = {}
const PERF_INTERVAL := 60  # Print perf summary every N frames
var _formation_frame: int = 0
const FORMATION_THROTTLE := 10  # Update formation bonuses every N frames

# Battle region in tile coords and pixel coords
var tile_region: Rect2i
var pixel_region: Rect2
var tile_offset: Vector2i

# Spawn rects in world pixel coords
var player_spawn_rect: Rect2
var enemy_spawn_rect: Rect2

# Camera settings
const NORMAL_ZOOM := Vector2(1.6, 1.6)
const COMMAND_ZOOM := Vector2(0.8, 0.8)
const ZOOM_SPEED := 4.0

var _target_zoom: Vector2 = NORMAL_ZOOM
var _banner_update_timer: float = 0.0
const BANNER_UPDATE_INTERVAL := 0.5

# Battle SFX
var _sfx_timer: float = 0.0
var _prev_blue_alive: int = 0
var _prev_red_alive: int = 0

@export var chunks_base_path: String = "res://resources/world/chunks"

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	# Systems
	units = BattleUnitSystem.new()
	projectiles = BattleProjectileSystem.new()
	commander = BattleCommander.new()
	collision = BattleCollision.new()
	ai = BattleSimpleAI.new()

	# Get config
	_config = {}
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.get("battle_config"):
		_config = gm.battle_config

	# Set up terrain region and spawn rects
	_setup_region(_config)
	# Prepare terrain layers and discover chunks (fast — no chunk loading yet)
	_prepare_terrain()

	# Bullets container (weapon_system looks for "bullets" group)
	var bullets_container := Node2D.new()
	bullets_container.name = "BulletsContainer"
	bullets_container.add_to_group("bullets")
	add_child(bullets_container)

	# Unit container (renderer draws units here)
	var unit_container := Node2D.new()
	unit_container.name = "UnitContainer"
	add_child(unit_container)

	# Renderer (Sprite2D pool on unit container)
	renderer = BattleRenderer.new()
	renderer.name = "Renderer"
	renderer.initialize(units, projectiles)
	unit_container.add_child(renderer)

	# Fog of war (disabled for now — re-enable later)
	fog = BattleFogOfWar.new()
	fog.name = "FogOfWar"
	fog.setup(units, pixel_region)
	fog.enabled = false
	fog.visible = false
	unit_container.add_child(fog)

	# Spawn Player
	_spawn_player()

	# Camera on player
	cam = Camera2D.new()
	cam.zoom = NORMAL_ZOOM
	_target_zoom = NORMAL_ZOOM
	if player:
		player.add_child(cam)
		cam.make_current()
	else:
		cam.position = Vector2(
			tile_offset.x * TILE_SIZE + pixel_region.size.x * 0.5,
			tile_offset.y * TILE_SIZE + pixel_region.size.y * 0.5
		)
		add_child(cam)
		cam.make_current()

	# Battle HUD (army counts, speed, retreat)
	hud = BattleHUD.new()
	hud.speed_changed.connect(func(s): speed_multiplier = s)
	hud.retreat_pressed.connect(_on_retreat)
	hud.return_pressed.connect(_on_return)
	hud.fog_toggled.connect(func(on): if fog: fog.enabled = on)
	add_child(hud)

	# Real GameHUD (or Sigil HUD if enabled)
	if player:
		game_hud = SigilHUD.new() if (UIPrefs.use_sigil_hud and not TouchControls.is_mobile()) else GameHUD.new()
		add_child(game_hud)
		game_hud.setup(player)
		_hide_gamehud_clutter()

	# Command overlay
	command_overlay = BattleCommandOverlay.new()
	command_overlay.initialize(units, commander, unit_container)
	command_overlay.command_issued.connect(_on_command_issued)
	command_overlay.exit_command_mode.connect(_toggle_command_mode)
	command_overlay.focus_group.connect(_on_focus_group)
	command_overlay.zoom_requested.connect(func(z): _target_zoom = Vector2(z, z))
	add_child(command_overlay)

	# Scale up player bullets when they spawn into battle
	var bcont = get_tree().get_first_node_in_group("bullets")
	if bcont:
		bcont.child_entered_tree.connect(_on_bullet_spawned)

	var t_end := Time.get_ticks_msec()
	print("BattleArena TIMING: _ready = %dms (chunks deferred: %d)" % [t_end - t0, _chunk_paths.size()])

func _setup_region(config: Dictionary) -> void:
	if config.has("battle_region"):
		tile_region = config["battle_region"]
	else:
		# Default: Darl Woods + Staging Grounds battle area
		# Covers all 4 army spawn waypoints with 20-tile margin:
		#   Darl_woods_Army_Spawn1 (276,-1), Darl_woods_army_spawn_2 (406,-47)
		#   StagingGrounds_ArmySpawn1 (265,37), StagingGround_ArmySpawn2 (321,39)
		# X: 245 to 426 (181 tiles), Y: -67 to 59 (126 tiles)
		tile_region = Rect2i(245, -67, 181, 126)

	tile_offset = Vector2i(tile_region.position.x, tile_region.position.y)
	pixel_region = Rect2(
		tile_region.position.x * TILE_SIZE,
		tile_region.position.y * TILE_SIZE,
		tile_region.size.x * TILE_SIZE,
		tile_region.size.y * TILE_SIZE
	)

	# Spawn rects (world pixel coords) — use Darl Woods army spawn waypoints
	if config.has("player_spawn_rect"):
		player_spawn_rect = config["player_spawn_rect"]
	else:
		# Player army spawns near Darl_woods_Army_Spawn1 (tile 276, -1)
		var spawn1_px := Vector2(276.0 * TILE_SIZE, -1.0 * TILE_SIZE)
		player_spawn_rect = Rect2(spawn1_px.x - 400, spawn1_px.y - 200, 800, 400)

	if config.has("enemy_spawn_rect"):
		enemy_spawn_rect = config["enemy_spawn_rect"]
	else:
		# Enemy army spawns near Darl_woods_army_spawn_2 (tile 406, -47)
		var spawn2_px := Vector2(406.0 * TILE_SIZE, -47.0 * TILE_SIZE)
		enemy_spawn_rect = Rect2(spawn2_px.x - 400, spawn2_px.y - 200, 800, 400)

func _spawn_player() -> void:
	player = _player_scene.instantiate() as CharacterBody2D
	if not player:
		push_error("BattleArena: Failed to instantiate player scene")
		return
	player.name = "Player"
	player.add_to_group("player")
	# Place at center of player spawn rect
	player.global_position = Vector2(
		player_spawn_rect.position.x + player_spawn_rect.size.x * 0.5,
		player_spawn_rect.position.y + player_spawn_rect.size.y * 0.5
	)
	add_child(player)

	# Scale player 4x to match 32px overworld tiles (same as overworld)
	player.scale = Vector2(4, 4)
	# Collision shape: 6x6 local = 24x24 at 4x scale (fits ~1 tile)
	var col = player.get_node_or_null("CollisionShape2D")
	if col:
		col.shape = RectangleShape2D.new()
		col.shape.size = Vector2(6, 6)
	# Hitbox: 2.0 local radius = 8px at 4x scale
	var hitbox_col = player.get_node_or_null("Hitbox/CollisionShape2D")
	if hitbox_col:
		hitbox_col.shape = CircleShape2D.new()
		hitbox_col.shape.radius = 2.0
	# Ensure player collision mask includes walls (layer 16 = bit 5)
	player.collision_mask = player.collision_mask | 16
	# Connect death signal
	if player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)
	print("BattleArena: Player collision_layer=%d mask=%d scale=%s" % [player.collision_layer, player.collision_mask, player.scale])

func _prepare_terrain() -> void:
	## Sets up TileMapLayers and discovers which chunks to load.
	## Actual chunk loading is deferred to _physics_process (CHUNKS_PER_FRAME per frame).
	var tileset_res: TileSet = _get_overworld_tileset()
	if not tileset_res:
		push_error("BattleArena: Could not load tileset from overworld scene")
		return

	var layer_names := ["ground", "paths", "water", "decorations", "buildings", "fences"]
	var layers: Array[TileMapLayer] = []
	for lname in layer_names:
		var layer := TileMapLayer.new()
		layer.name = lname.capitalize()
		layer.tile_set = tileset_res
		add_child(layer)
		layers.append(layer)
	ground_layer = layers[0]
	paths_layer = layers[1]
	water_layer = layers[2]
	decor_layer = layers[3]
	buildings_layer = layers[4]
	fences_layer = layers[5]

	_all_layer_map = {
		"ground": ground_layer,
		"paths": paths_layer,
		"water": water_layer,
		"decorations": decor_layer,
		"buildings": buildings_layer,
		"fences": fences_layer,
	}

	# Discover which chunks overlap our tile_region
	var chunk_size := 64
	var cx_min := int(floor(float(tile_region.position.x) / chunk_size))
	var cx_max := int(floor(float(tile_region.end.x) / chunk_size))
	var cy_min := int(floor(float(tile_region.position.y) / chunk_size))
	var cy_max := int(floor(float(tile_region.end.y) / chunk_size))

	_chunk_paths = []
	for cy in range(cy_min, cy_max + 1):
		for cx in range(cx_min, cx_max + 1):
			var path := "%s/chunk_%d_%d.tres" % [chunks_base_path, cx, cy]
			if ResourceLoader.exists(path):
				_chunk_paths.append(path)
	_chunk_load_index = 0
	_chunks_done = false
	_blocked_tiles.clear()
	_deferred_visual_data = []
	_deferred_load_index = 0

func _load_next_chunks() -> void:
	## Load CHUNKS_PER_FRAME chunks, extract blocking data + queue visuals.
	var loaded := 0
	while _chunk_load_index < _chunk_paths.size() and loaded < CHUNKS_PER_FRAME:
		var chunk_res = load(_chunk_paths[_chunk_load_index])
		_chunk_load_index += 1
		loaded += 1
		if not chunk_res:
			continue
		for lname in _blocking_layers:
			if chunk_res.has_meta(lname):
				var data: PackedInt32Array = chunk_res.get_meta(lname)
				if data.size() > 0:
					_extract_blocked_from_data(lname, data)
		for lname in _all_layer_map:
			if chunk_res.has_meta(lname):
				var data: PackedInt32Array = chunk_res.get_meta(lname)
				if data.size() > 0:
					_deferred_visual_data.append([_all_layer_map[lname], data])

	if _chunk_load_index >= _chunk_paths.size():
		_chunks_done = true
		print("BattleArena: All %d chunks loaded, %d blocked tiles" % [_chunk_paths.size(), _blocked_tiles.size()])

func _finalize_battle_init() -> void:
	## Called once all chunks are loaded. Builds collision, loads ALL tiles, spawns armies, inits AI.
	var t0 := Time.get_ticks_msec()

	# Build collision shapes
	_wall_body = StaticBody2D.new()
	_wall_body.name = "WallBody"
	_wall_body.collision_layer = 16
	_wall_body.collision_mask = 0
	add_child(_wall_body)
	var shape_count := _build_collision_shapes()
	_add_boundary_walls()
	var t1 := Time.get_ticks_msec()

	# Load ALL visual tiles immediately (deferred streaming caused black screen issues)
	var tile_count := 0
	for entry in _deferred_visual_data:
		var layer: TileMapLayer = entry[0]
		var data: PackedInt32Array = entry[1]
		_apply_tile_data(layer, data)
		tile_count += data.size() / 5
	_deferred_visual_data.clear()
	_deferred_load_index = 0
	var t2 := Time.get_ticks_msec()

	# Set terrain type from zone data
	_setup_battle_terrain(_config)

	# Spawn armies
	_spawn_armies(_config)

	# All AI runs at ELITE — maximum tactical effort
	ai.ai_tier = BattleSimpleAI.AITier.ELITE
	ai.initialize(units, projectiles, commander)
	ai.setup_flow_fields(_blocked_tiles, tile_region)
	ai.red_objective = Vector2(
		player_spawn_rect.position.x + player_spawn_rect.size.x * 0.5,
		player_spawn_rect.position.y + player_spawn_rect.size.y * 0.5
	)
	ai.blue_objective = Vector2(
		enemy_spawn_rect.position.x + enemy_spawn_rect.size.x * 0.5,
		enemy_spawn_rect.position.y + enemy_spawn_rect.size.y * 0.5
	)
	# Precompute flow fields (BFS from objectives — one-time, covers entire map)
	ai.compute_initial_flow_fields()

	# Ensure player collision with new wall body
	if player:
		player.collision_mask = player.collision_mask | 16

	_battle_initialized = true
	var t3 := Time.get_ticks_msec()
	print("BattleArena: Init breakdown — shapes=%dms tiles=%dms(%d) armies+ai=%dms total=%dms" % [
		t1 - t0, t2 - t1, tile_count, t3 - t2, t3 - t0])

	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("_hide_loading_screen"):
		gm._hide_loading_screen()

func _extract_blocked_from_data(layer_name: String, data: PackedInt32Array) -> int:
	var added := 0
	var i := 0
	var count := data.size()
	var rx := tile_region.position.x - 2
	var rex := tile_region.end.x + 2
	var ry := tile_region.position.y - 2
	var rey := tile_region.end.y + 2
	while i + 4 < count:
		var tx: int = data[i]
		var ty: int = data[i + 1]
		var source_id: int = data[i + 2]
		var atlas_x: int = data[i + 3]
		var atlas_y: int = data[i + 4]
		i += 5
		if tx < rx or tx > rex or ty < ry or ty > rey:
			continue
		if _is_blocking_tile(layer_name, source_id, Vector2i(atlas_x, atlas_y)):
			_blocked_tiles[Vector2i(tx, ty)] = true
			added += 1
	return added

func _apply_tile_data(layer: TileMapLayer, data: PackedInt32Array) -> void:
	var i := 0
	var count := data.size()
	while i + 4 < count:
		var tx: int = data[i]
		var ty: int = data[i + 1]
		var source_id: int = data[i + 2]
		var atlas_x: int = data[i + 3]
		var atlas_y: int = data[i + 4]
		i += 5
		if tx >= tile_region.position.x - 2 and tx <= tile_region.end.x + 2 \
			and ty >= tile_region.position.y - 2 and ty <= tile_region.end.y + 2:
			layer.set_cell(Vector2i(tx, ty), source_id, Vector2i(atlas_x, atlas_y))

func _build_blocking_map() -> void:
	# Legacy — no longer used. Blocking is now extracted directly from chunk data.
	pass

func _add_boundary_walls() -> void:
	## Create 4 thick invisible walls around the arena perimeter
	var ox: float = tile_region.position.x * TILE_SIZE
	var oy: float = tile_region.position.y * TILE_SIZE
	var w: float = tile_region.size.x * TILE_SIZE
	var wall_thickness := TILE_SIZE * 3.0
	var h: float = tile_region.size.y * TILE_SIZE
	# Top wall
	var s_top := CollisionShape2D.new()
	var r_top := RectangleShape2D.new()
	r_top.size = Vector2(w + wall_thickness * 2, wall_thickness)
	s_top.shape = r_top
	s_top.position = Vector2(ox + w / 2.0, oy - wall_thickness / 2.0)
	_wall_body.add_child(s_top)
	# Bottom wall
	var s_bot := CollisionShape2D.new()
	var r_bot := RectangleShape2D.new()
	r_bot.size = Vector2(w + wall_thickness * 2, wall_thickness)
	s_bot.shape = r_bot
	s_bot.position = Vector2(ox + w / 2.0, oy + h + wall_thickness / 2.0)
	_wall_body.add_child(s_bot)
	# Left wall
	var s_left := CollisionShape2D.new()
	var r_left := RectangleShape2D.new()
	r_left.size = Vector2(wall_thickness, h + wall_thickness * 2)
	s_left.shape = r_left
	s_left.position = Vector2(ox - wall_thickness / 2.0, oy + h / 2.0)
	_wall_body.add_child(s_left)
	# Right wall
	var s_right := CollisionShape2D.new()
	var r_right := RectangleShape2D.new()
	r_right.size = Vector2(wall_thickness, h + wall_thickness * 2)
	s_right.shape = r_right
	s_right.position = Vector2(ox + w + wall_thickness / 2.0, oy + h / 2.0)
	_wall_body.add_child(s_right)
	print("BattleArena: Added 4 boundary walls around arena perimeter")

func _build_collision_shapes() -> int:
	## Row-merge: group blocked tiles by row, sort x per row, merge consecutive runs.
	## O(N) — produces ~500 shapes instead of ~200 but loads in <50ms vs 1-5s.
	if _blocked_tiles.is_empty():
		return 0
	var half := TILE_SIZE / 2.0
	var rows: Dictionary = {}  # y -> Array[int] of x values
	for cell in _blocked_tiles:
		if not rows.has(cell.y):
			rows[cell.y] = []
		rows[cell.y].append(cell.x)
	var shape_count := 0
	for y_key in rows:
		var xs: Array = rows[y_key]
		xs.sort()
		var run_start: int = xs[0]
		var run_end: int = xs[0]
		for i in range(1, xs.size()):
			if xs[i] == run_end + 1:
				run_end = xs[i]
			else:
				_add_row_shape(run_start, run_end, y_key, half)
				shape_count += 1
				run_start = xs[i]
				run_end = xs[i]
		_add_row_shape(run_start, run_end, y_key, half)
		shape_count += 1
	return shape_count

func _add_row_shape(x_start: int, x_end: int, y: int, half: float) -> void:
	var w := (x_end - x_start + 1) * TILE_SIZE
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, TILE_SIZE)
	shape.shape = rect
	shape.position = Vector2(
		x_start * TILE_SIZE + w / 2.0,
		y * TILE_SIZE + half
	)
	_wall_body.add_child(shape)

func _is_blocking_tile(layer_name: String, source: int, atlas: Vector2i) -> bool:
	if layer_name == "water":
		return true
	if layer_name == "buildings":
		if source == 3 or source == 4:
			return false
		return true
	if layer_name == "fences":
		if source == 0:
			if atlas.y == 8:
				return false
			return true
		if source == 5 or source == 6:
			return true
	return false

func is_tile_blocked(world_x: float, world_y: float) -> bool:
	var tx := int(floor(world_x / TILE_SIZE))
	var ty := int(floor(world_y / TILE_SIZE))
	return _blocked_tiles.has(Vector2i(tx, ty))

func _setup_battle_terrain(config: Dictionary) -> void:
	## Determine terrain type from zone data and apply to unit system.
	var zone_name: String = config.get("zone_name", "")
	var tileset_id: int = config.get("tileset", -1)

	# If tileset not in config, try loading from zone .tres
	if tileset_id < 0 and zone_name != "":
		var zone_path := "res://resources/world/zones/%s.tres" % zone_name
		if ResourceLoader.exists(zone_path):
			var zone_data = load(zone_path)
			if zone_data and zone_data.get("tileset") != null:
				tileset_id = zone_data.tileset

	if tileset_id >= 0:
		units.battle_terrain = BattleUnitSystem.get_terrain_from_tileset(tileset_id)
	else:
		units.battle_terrain = BattleUnitSystem.TerrainType.PLAINS

	var terrain_names := BattleUnitSystem.TerrainType.keys()
	var terrain_name: String = terrain_names[units.battle_terrain] if units.battle_terrain < terrain_names.size() else "UNKNOWN"
	print("BattleArena: Terrain = %s (tileset=%d, zone=%s)" % [terrain_name, tileset_id, zone_name])

func _spawn_armies(config: Dictionary) -> void:
	var player_army: Array = config.get("player_army", [])
	var enemy_army: Array = config.get("enemy_army", [])
	var divisions: Array = config.get("divisions", [])

	# Fallback test armies — scale from arena size
	var max_per_side := _compute_army_size()
	if player_army.is_empty():
		player_army = _generate_army_composition(max_per_side)
	if enemy_army.is_empty():
		enemy_army = _generate_army_composition(max_per_side)

	# Count totals for wave splitting
	var blue_total := _count_army(player_army)
	var red_total := _count_army(enemy_army)
	_initial_blue_count = blue_total
	_initial_red_count = red_total

	# BLUE (player) always spawns ALL at once — player bought those units
	# RED (enemy) splits into waves if large army (reinforcements)
	var red_waves := _split_into_waves(enemy_army, WAVE_SIZE) if red_total > WAVE_THRESHOLD else [enemy_army]

	# Spawn ALL player units immediately
	if not divisions.is_empty():
		_spawn_faction_with_divisions(player_army, divisions, BattleUnitSystem.Faction.BLUE, player_spawn_rect)
	else:
		_spawn_faction_in_rect(player_army, BattleUnitSystem.Faction.BLUE, player_spawn_rect)

	# Spawn first RED wave
	if not red_waves.is_empty():
		var first_red: Array = red_waves.pop_front()
		_spawn_faction_in_rect(first_red, BattleUnitSystem.Faction.RED, enemy_spawn_rect)

	# Store remaining RED waves only (no BLUE waves), capped to prevent endless battles
	_pending_blue_waves = []
	_pending_red_waves = red_waves.slice(0, MAX_RED_WAVES)
	_wave_timer = 0.0

	if not _pending_red_waves.is_empty():
		print("BattleArena: Enemy reinforcement waves pending — %d waves" % _pending_red_waves.size())

func _count_army(army: Array) -> int:
	var total := 0
	for entry in army:
		total += int(entry.get("count", 0))
	return total

func _split_into_waves(army: Array, wave_size: int) -> Array:
	## Split an army into waves of approximately wave_size units.
	## Returns Array of army arrays. Each wave has proportional distribution.
	var total := _count_army(army)
	if total <= wave_size:
		return [army]

	var waves: Array = []
	var remaining_counts: Dictionary = {}  # type -> remaining count
	var type_info: Dictionary = {}  # type -> {formation}
	for entry in army:
		var t: int = entry.get("type", 0)
		remaining_counts[t] = int(entry.get("count", 0))
		type_info[t] = {"formation": entry.get("formation", 0)}

	while true:
		var remaining_total := 0
		for t in remaining_counts:
			remaining_total += remaining_counts[t]
		if remaining_total <= 0:
			break

		var wave: Array = []
		var this_wave_size := mini(wave_size, remaining_total)
		for t in remaining_counts:
			if remaining_counts[t] <= 0:
				continue
			var proportion: float = float(remaining_counts[t]) / float(remaining_total)
			var count := maxi(1, int(proportion * this_wave_size))
			count = mini(count, remaining_counts[t])
			remaining_counts[t] -= count
			wave.append({"type": t, "count": count, "formation": type_info[t]["formation"]})

		if not wave.is_empty():
			waves.append(wave)
	return waves

func _spawn_faction_with_divisions(army: Array, divisions: Array, fac: int, rect: Rect2) -> void:
	## Spawn player army with named division groups first, then remaining as default groups.
	var type_map := {
		"infantry": BattleUnitSystem.UnitType.INFANTRY,
		"archer": BattleUnitSystem.UnitType.ARCHER,
		"heavy_infantry": BattleUnitSystem.UnitType.HEAVY_INFANTRY,
		"cavalry": BattleUnitSystem.UnitType.CAVALRY,
		"heavy_cavalry": BattleUnitSystem.UnitType.HEAVY_CAVALRY,
		"mage": BattleUnitSystem.UnitType.MAGE,
		"spear": BattleUnitSystem.UnitType.SPEAR,
		"horse_archer": BattleUnitSystem.UnitType.HORSE_ARCHER,
		"ranged_infantry": BattleUnitSystem.UnitType.RANGED_INFANTRY,
	}
	var formation_map := {
		"infantry": BattleUnitSystem.FormationType.LINE,
		"archer": BattleUnitSystem.FormationType.LOOSE_LINE,
		"heavy_infantry": BattleUnitSystem.FormationType.SHIELD_WALL,
		"cavalry": BattleUnitSystem.FormationType.WEDGE,
		"heavy_cavalry": BattleUnitSystem.FormationType.WEDGE,
		"mage": BattleUnitSystem.FormationType.LOOSE_LINE,
		"spear": BattleUnitSystem.FormationType.LINE,
		"horse_archer": BattleUnitSystem.FormationType.LOOSE_LINE,
		"ranged_infantry": BattleUnitSystem.FormationType.LOOSE_LINE,
	}

	# Track how many units each type has been assigned to divisions
	var div_assigned: Dictionary = {}  # unit_type_int -> count assigned to divisions
	for div in divisions:
		for u in div.get("units", []):
			var type_name: String = u.get("type", "")
			if type_map.has(type_name):
				var t: int = type_map[type_name]
				div_assigned[t] = div_assigned.get(t, 0) + int(u.get("count", 0))

	# Get valid positions
	var total_needed := 0
	for entry in army:
		total_needed += int(entry.get("count", 0))
	var spacing := 18.0
	var valid_pos := _get_valid_spawn_grid(rect, spacing)
	if valid_pos.size() < total_needed:
		valid_pos = _get_valid_spawn_grid(rect, 14.0)

	var facing_right := (fac == BattleUnitSystem.Faction.BLUE)
	if facing_right:
		valid_pos.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x > b.x)
	else:
		valid_pos.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

	# Spawn division groups first
	var pos_idx := 0
	for div in divisions:
		var div_name: String = div.get("name", "Division")
		for u in div.get("units", []):
			var type_name: String = u.get("type", "")
			var count: int = int(u.get("count", 0))
			if count <= 0 or not type_map.has(type_name):
				continue
			var u_type: int = type_map[type_name]
			var formation: int = formation_map.get(type_name, BattleUnitSystem.FormationType.LINE)
			var group_name := "%s_%s" % [div_name, type_name]
			var group := commander.create_group(group_name, fac, formation)
			var div_stat_mult := _get_stat_mult(fac, u_type)
			for _i in count:
				if pos_idx >= valid_pos.size():
					break
				var pos: Vector2 = valid_pos[pos_idx]
				pos_idx += 1
				var idx := units.spawn(pos.x, pos.y, u_type, fac, group.id, div_stat_mult)
				if _i == 0 and idx >= 0:
					_make_commander(idx)

	# Spawn remaining (unassigned) units as default groups
	var type_to_entry := {}
	var spawn_order := [
		BattleUnitSystem.UnitType.INFANTRY, BattleUnitSystem.UnitType.HEAVY_INFANTRY,
		BattleUnitSystem.UnitType.SPEAR,
		BattleUnitSystem.UnitType.CAVALRY, BattleUnitSystem.UnitType.HEAVY_CAVALRY,
		BattleUnitSystem.UnitType.ARCHER, BattleUnitSystem.UnitType.RANGED_INFANTRY,
		BattleUnitSystem.UnitType.MAGE, BattleUnitSystem.UnitType.HORSE_ARCHER,
	]
	for entry in army:
		type_to_entry[entry.get("type", 0)] = entry

	for u_type in spawn_order:
		if not type_to_entry.has(u_type):
			continue
		var entry: Dictionary = type_to_entry[u_type]
		var total_count: int = entry.get("count", 0)
		var assigned: int = div_assigned.get(u_type, 0)
		var remaining := total_count - assigned
		if remaining <= 0:
			continue
		var group_name := "%s_%s" % [BattleUnitSystem.UnitType.keys()[u_type], "BLUE" if fac == BattleUnitSystem.Faction.BLUE else "RED"]
		var group := commander.create_group(group_name, fac, entry.get("formation", BattleUnitSystem.FormationType.LINE))
		var rem_stat_mult := _get_stat_mult(fac, u_type)
		for _i in remaining:
			if pos_idx >= valid_pos.size():
				break
			var pos: Vector2 = valid_pos[pos_idx]
			pos_idx += 1
			var idx := units.spawn(pos.x, pos.y, u_type, fac, group.id, rem_stat_mult)
			if _i == 0 and idx >= 0:
				_make_commander(idx)

const UNIT_NAMES_SHORT := {
	0: "Inf", 1: "HInf", 2: "Cav", 3: "HCav", 4: "Arch", 5: "Mage",
	6: "Spear", 7: "HArc", 8: "RInf",
}

func _make_commander(i: int) -> void:
	## Flag unit as commander: +50% HP, +20% damage (via higher max_hp)
	units.is_commander[i] = 1
	units.hp[i] *= 1.5
	units.max_hp[i] *= 1.5

func _get_stat_mult(fac: int, _u_type: int) -> float:
	## Get stat multiplier for spawning. BLUE gets upgrade bonuses, RED gets enemy scaling.
	if fac == BattleUnitSystem.Faction.BLUE:
		return _get_player_upgrade_mult(_u_type)
	else:
		return _get_enemy_scaling_mult()

func _get_veteran_ranks_for_type(fac: int, u_type: int, count: int) -> Array[int]:
	## Returns array of veteran ranks (highest first) for spawning.
	var ranks: Array[int] = []
	ranks.resize(count)
	ranks.fill(0)
	if fac != BattleUnitSystem.Faction.BLUE:
		return ranks
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.save_data:
		return ranks
	var veterans: Dictionary = gm.save_data.army_state.get("veterans", {})
	var type_names := ["infantry", "heavy_infantry", "cavalry", "heavy_cavalry", "archer", "mage", "spear", "horse_archer", "ranged_infantry"]
	if u_type < 0 or u_type >= type_names.size():
		return ranks
	var tname: String = type_names[u_type]
	if not veterans.has(tname):
		return ranks
	var vet_data: Dictionary = veterans[tname]
	var elite: int = vet_data.get("elite", 0)
	var veteran: int = vet_data.get("veteran", 0)
	var trained: int = vet_data.get("trained", 0)
	# Fill ranks array: elite first, then veteran, then trained, rest raw
	var idx := 0
	for _i in mini(elite, count - idx):
		ranks[idx] = 3
		idx += 1
	for _i in mini(veteran, count - idx):
		ranks[idx] = 2
		idx += 1
	for _i in mini(trained, count - idx):
		ranks[idx] = 1
		idx += 1
	return ranks

func _get_player_upgrade_mult(u_type: int) -> float:
	## Calculate combined upgrade multiplier from save_data for a unit type.
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.save_data:
		return 1.0
	var upgrades: Dictionary = gm.save_data.army_state.get("unit_upgrades", {})
	if upgrades.is_empty():
		return 1.0
	var type_names := ["infantry", "heavy_infantry", "cavalry", "heavy_cavalry", "archer", "mage", "spear", "horse_archer", "ranged_infantry"]
	if u_type < 0 or u_type >= type_names.size():
		return 1.0
	var prefix: String = type_names[u_type]
	# ATK: +12% per level, DEF: +15% per level, HP: +15% per level → average them into stat_mult
	var atk_level: int = upgrades.get(prefix + "_atk", 0)
	var def_level: int = upgrades.get(prefix + "_def", 0)
	var hp_level: int = upgrades.get(prefix + "_hp", 0)
	# Return HP mult (damage/def applied separately in damage() via upgrade_atk_mult)
	return 1.0 + hp_level * 0.15

func _get_enemy_scaling_mult() -> float:
	## Enemy stats scale with faction tier and zone count.
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return 1.0
	var cfg: Dictionary = gm.battle_config if gm.get("battle_config") else {}
	var tier: int = cfg.get("enemy_tier", 1)
	var zone_count: int = cfg.get("enemy_zone_count", 0)
	var tier_mult := 1.0 + (tier - 1) * 0.15  # tier 3 = 1.3x
	var zone_mult := 1.0 + zone_count * 0.02   # 10 zones = 1.2x
	return tier_mult * zone_mult

func _spawn_next_wave() -> void:
	## Spawn the next reinforcement wave for each side.
	if not _pending_blue_waves.is_empty():
		var wave: Array = _pending_blue_waves.pop_front()
		var count := _count_army(wave)
		_spawn_faction_in_rect(wave, BattleUnitSystem.Faction.BLUE, player_spawn_rect)
		hud.show_notification("REINFORCEMENTS ARRIVING! (+%d allies)" % count)
		print("BattleArena: Blue reinforcement wave — %d units (%d waves remaining)" % [count, _pending_blue_waves.size()])
	if not _pending_red_waves.is_empty():
		var wave: Array = _pending_red_waves.pop_front()
		var count := _count_army(wave)
		_spawn_faction_in_rect(wave, BattleUnitSystem.Faction.RED, enemy_spawn_rect)
		if _pending_blue_waves.is_empty():
			hud.show_notification("ENEMY REINFORCEMENTS! (+%d foes)" % count)
		print("BattleArena: Red reinforcement wave — %d units (%d waves remaining)" % [count, _pending_red_waves.size()])

func _compute_army_size() -> int:
	## Scale army size based on arena tile count
	var arena_tiles := tile_region.size.x * tile_region.size.y
	return clampi(arena_tiles / 80, 30, 300)

func _generate_army_composition(max_per_side: int) -> Array:
	## Generate balanced army with all 9 unit types
	var inf_count := int(max_per_side * 0.22)
	var archer_count := int(max_per_side * 0.14)
	var cav_count := int(max_per_side * 0.12)
	var heavy_inf_count := int(max_per_side * 0.10)
	var mage_count := int(max_per_side * 0.06)
	var spear_count := int(max_per_side * 0.12)
	var horse_archer_count := int(max_per_side * 0.08)
	var ranged_inf_count := int(max_per_side * 0.08)
	var heavy_cav_count := max_per_side - inf_count - archer_count - cav_count - heavy_inf_count - mage_count - spear_count - horse_archer_count - ranged_inf_count
	return [
		{"type": BattleUnitSystem.UnitType.INFANTRY, "count": inf_count, "formation": BattleUnitSystem.FormationType.LINE},
		{"type": BattleUnitSystem.UnitType.HEAVY_INFANTRY, "count": heavy_inf_count, "formation": BattleUnitSystem.FormationType.SHIELD_WALL},
		{"type": BattleUnitSystem.UnitType.SPEAR, "count": spear_count, "formation": BattleUnitSystem.FormationType.LINE},
		{"type": BattleUnitSystem.UnitType.ARCHER, "count": archer_count, "formation": BattleUnitSystem.FormationType.LOOSE_LINE},
		{"type": BattleUnitSystem.UnitType.RANGED_INFANTRY, "count": ranged_inf_count, "formation": BattleUnitSystem.FormationType.LOOSE_LINE},
		{"type": BattleUnitSystem.UnitType.CAVALRY, "count": cav_count, "formation": BattleUnitSystem.FormationType.WEDGE},
		{"type": BattleUnitSystem.UnitType.HEAVY_CAVALRY, "count": heavy_cav_count, "formation": BattleUnitSystem.FormationType.WEDGE},
		{"type": BattleUnitSystem.UnitType.HORSE_ARCHER, "count": horse_archer_count, "formation": BattleUnitSystem.FormationType.LOOSE_LINE},
		{"type": BattleUnitSystem.UnitType.MAGE, "count": mage_count, "formation": BattleUnitSystem.FormationType.LOOSE_LINE},
	]

func _get_valid_spawn_grid(rect: Rect2, spacing: float) -> Array[Vector2]:
	## Returns valid spawn positions in ROW order (not shuffled) for organized formation layout.
	var positions: Array[Vector2] = []
	var y := rect.position.y + spacing * 0.5
	while y < rect.end.y:
		var x_pos := rect.position.x + spacing * 0.5
		while x_pos < rect.end.x:
			var center_tx := int(floor(x_pos / TILE_SIZE))
			var center_ty := int(floor(y / TILE_SIZE))
			if not _blocked_tiles.has(Vector2i(center_tx, center_ty)):
				positions.append(Vector2(x_pos, y))
			x_pos += spacing
		y += spacing
	return positions

func _spawn_faction_in_rect(army: Array, fac: int, rect: Rect2) -> void:
	## Spawn army in organized formation: front → back rows by unit role.
	## Layout (facing enemy): Infantry front, Heavy Inf behind, Cavalry flanks, Archers/Mages rear.
	## For BLUE (left side): front = right edge. For RED (right side): front = left edge.
	var total_needed := 0
	for entry in army:
		total_needed += entry.get("count", 10)

	var spacing := 18.0
	var valid_pos := _get_valid_spawn_grid(rect, spacing)
	if valid_pos.size() < total_needed:
		valid_pos = _get_valid_spawn_grid(rect, 14.0)
	print("BattleArena: Spawn fac=%d need=%d valid_positions=%d rect=%s" % [fac, total_needed, valid_pos.size(), rect])

	# Sort positions: BLUE faces right (front = higher X), RED faces left (front = lower X)
	var facing_right := (fac == BattleUnitSystem.Faction.BLUE)
	if facing_right:
		valid_pos.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x > b.x)
	else:
		valid_pos.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

	# Define spawn order: front-line → back-line
	# [infantry, heavy_inf, spear, cavalry, heavy_cav, archers, ranged_inf, mages, horse_archer]
	var spawn_order: Array[int] = [
		BattleUnitSystem.UnitType.INFANTRY,
		BattleUnitSystem.UnitType.HEAVY_INFANTRY,
		BattleUnitSystem.UnitType.SPEAR,
		BattleUnitSystem.UnitType.CAVALRY,
		BattleUnitSystem.UnitType.HEAVY_CAVALRY,
		BattleUnitSystem.UnitType.ARCHER,
		BattleUnitSystem.UnitType.RANGED_INFANTRY,
		BattleUnitSystem.UnitType.MAGE,
		BattleUnitSystem.UnitType.HORSE_ARCHER,
	]

	# Build a lookup: unit_type → army entry.
	# Multiple entries of the same type are merged (sum counts, keep first formation).
	var type_to_entry: Dictionary = {}
	for entry in army:
		var t: int = entry.get("type", 0)
		var c: int = int(entry.get("count", 0))
		if type_to_entry.has(t):
			type_to_entry[t]["count"] = int(type_to_entry[t]["count"]) + c
		else:
			type_to_entry[t] = {"count": c, "formation": entry.get("formation", BattleUnitSystem.FormationType.LINE)}

	var pos_idx := 0
	for u_type in spawn_order:
		if not type_to_entry.has(u_type):
			continue
		var entry: Dictionary = type_to_entry[u_type]
		var u_count: int = entry.get("count", 10)
		var formation: int = entry.get("formation", BattleUnitSystem.FormationType.LINE)

		var group_name := "%s_%s" % [BattleUnitSystem.UnitType.keys()[u_type], "BLUE" if fac == BattleUnitSystem.Faction.BLUE else "RED"]

		# Get stat multiplier for this faction (enemy scaling)
		var stat_mult := _get_stat_mult(fac, u_type)
		# Get veteran ranks for BLUE units
		var vet_ranks := _get_veteran_ranks_for_type(fac, u_type, u_count)

		var group := commander.create_group(group_name, fac, formation)
		for ui in u_count:
			if pos_idx >= valid_pos.size():
				push_warning("BattleArena: Ran out of valid spawn positions for %s" % group_name)
				break
			var pos: Vector2 = valid_pos[pos_idx]
			pos_idx += 1
			var vet_rank: int = vet_ranks[ui] if ui < vet_ranks.size() else 0
			var idx := units.spawn(pos.x, pos.y, u_type, fac, group.id, stat_mult, vet_rank)
			# First unit in group becomes commander (prefer highest veteran)
			if ui == 0 and idx >= 0:
				_make_commander(idx)

func _input(event: InputEvent) -> void:
	if battle_ended:
		return

	# Tab toggles command mode
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_toggle_command_mode()
		get_viewport().set_input_as_handled()

	# R key: Release/Scatter — all FOLLOW groups scatter and charge forward
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_release_army()
		get_viewport().set_input_as_handled()

	# F1-F9: switch camera to commander unit, F10/0: return to player
	if event is InputEventKey and event.pressed and _commander_switch_cooldown <= 0.0:
		var key: int = event.keycode
		if key == KEY_F10 or key == KEY_0:
			_switch_to_player()
			_commander_switch_cooldown = 0.3
			get_viewport().set_input_as_handled()
		elif key >= KEY_F1 and key <= KEY_F9:
			var idx: int = key - KEY_F1  # 0-based
			_switch_to_commander(idx)
			_commander_switch_cooldown = 0.3
			get_viewport().set_input_as_handled()

	# Scroll wheel zoom (works in and out of command mode)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var z := clampf(_target_zoom.x * 1.1, 0.15, 2.0)
			_target_zoom = Vector2(z, z)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var z := clampf(_target_zoom.x / 1.1, 0.15, 2.0)
			_target_zoom = Vector2(z, z)
			get_viewport().set_input_as_handled()

	# Mac trackpad: two-finger scroll (pan gesture) for zoom
	if event is InputEventPanGesture:
		var pan_delta: float = event.delta.y  # positive = scroll down, negative = scroll up
		if absf(pan_delta) > 0.01:
			var factor := 1.0 - pan_delta * 0.08
			var z := clampf(_target_zoom.x * factor, 0.15, 2.0)
			_target_zoom = Vector2(z, z)
			get_viewport().set_input_as_handled()

	# Mac trackpad: pinch-to-zoom (magnify gesture)
	if event is InputEventMagnifyGesture:
		var z := clampf(_target_zoom.x * event.factor, 0.15, 2.0)
		_target_zoom = Vector2(z, z)
		get_viewport().set_input_as_handled()

func _toggle_command_mode() -> void:
	command_mode = not command_mode
	hud.set_command_mode(command_mode)

	if command_mode:
		_target_zoom = COMMAND_ZOOM
		command_overlay.show_overlay()
		# Keep fog visible in command mode so player sees what units see
		# Detach camera from player, put at battlefield center
		if cam.get_parent() == player:
			var global_pos := cam.global_position
			cam.get_parent().remove_child(cam)
			add_child(cam)
			cam.global_position = global_pos
			cam.make_current()
	else:
		_target_zoom = NORMAL_ZOOM
		command_overlay.hide_overlay()
		# Reattach camera to player
		if player and cam.get_parent() != player:
			var global_pos := cam.global_position
			cam.get_parent().remove_child(cam)
			player.add_child(cam)
			cam.position = Vector2.ZERO
			cam.make_current()

func _update_blue_commanders() -> void:
	## Refresh the list of BLUE commander unit indices.
	_blue_commanders.clear()
	for i in units.count:
		if units.alive[i] == 1 and units.faction[i] == BattleUnitSystem.Faction.BLUE and units.is_commander[i] == 1:
			_blue_commanders.append(i)

func _switch_to_commander(idx: int) -> void:
	## Switch camera focus to the Nth BLUE commander unit.
	_update_blue_commanders()
	if idx < 0 or idx >= _blue_commanders.size():
		return
	var unit_idx := _blue_commanders[idx]
	if units.alive[unit_idx] == 0:
		return
	_active_commander_index = idx
	# Detach camera from player, move to commander position
	if cam.get_parent() == player:
		var gpos := cam.global_position
		cam.get_parent().remove_child(cam)
		add_child(cam)
		cam.global_position = gpos
		cam.make_current()
	cam.global_position = Vector2(units.x[unit_idx], units.y[unit_idx])
	# Slight zoom out for commander view
	_target_zoom = Vector2(1.0, 1.0)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("chime", -8.0)
	var gid := units.group_id[unit_idx]
	var grp = commander.get_group(gid)
	var grp_name: String = grp.name if grp else "Unknown"
	hud.show_notification("Viewing: %s (F%d)" % [grp_name, idx + 1])
	print("Switched to commander %d: unit %d (group %s)" % [idx + 1, unit_idx, grp_name])

func _switch_to_player() -> void:
	## Return camera to the main player character.
	_active_commander_index = -1
	if player and is_instance_valid(player):
		if cam.get_parent() != player:
			var gpos := cam.global_position
			cam.get_parent().remove_child(cam)
			player.add_child(cam)
			cam.position = Vector2.ZERO
			cam.make_current()
		_target_zoom = NORMAL_ZOOM
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("chime", -8.0)
		hud.show_notification("Viewing: Player (F10)")
		print("Switched back to main player")

func _release_army() -> void:
	## Release all FOLLOW groups: scatter them and charge toward the enemy
	var released := 0
	var blue_groups := commander.get_faction_groups(BattleUnitSystem.Faction.BLUE)
	for g in blue_groups:
		if g.command == BattleCommander.CommandType.FOLLOW:
			g.command = BattleCommander.CommandType.ATTACK
			# Target enemy center
			var enemy_center := Vector2.ZERO
			var enemy_count := 0
			var red_groups := commander.get_faction_groups(BattleUnitSystem.Faction.RED)
			for rg in red_groups:
				var rc := units.get_group_center(rg.id)
				if rc != Vector2.ZERO:
					enemy_center += rc
					enemy_count += 1
			if enemy_count > 0:
				enemy_center /= float(enemy_count)
				g.target_x = enemy_center.x + randf_range(-100, 100)
				g.target_y = enemy_center.y + randf_range(-100, 100)
			released += 1
	if released > 0:
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("scatter", -5.0)
		print("Released %d groups to attack!" % released)

func _on_focus_group(center_x: float, center_y: float) -> void:
	## Smoothly move camera to group/unit position in command mode
	if command_mode and cam and cam.get_parent() != player:
		cam.global_position = Vector2(center_x, center_y)

func _on_command_issued(group_id: int, cmd: int, target_x: float, target_y: float) -> void:
	var group := commander.get_group(group_id)
	if not group:
		return
	group.command = cmd
	group.target_x = target_x
	group.target_y = target_y
	var cmd_keys := BattleCommander.CommandType.keys()
	var cmd_name: String = cmd_keys[cmd] if cmd >= 0 and cmd < cmd_keys.size() else "UNKNOWN(%d)" % cmd
	print("BattleArena: Group %d (%s) → command %s" % [group_id, group.name, cmd_name])

	# Command SFX — only for button commands, not ground clicks
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		match cmd:
			BattleCommander.CommandType.HOLD, BattleCommander.CommandType.DEFENSIVE:
				sfx.play("close_shut", -5.0)
			BattleCommander.CommandType.SCATTER:
				sfx.play("scatter", -5.0)
			BattleCommander.CommandType.FOLLOW:
				sfx.play("chime", -5.0)
			BattleCommander.CommandType.RETREAT:
				sfx.play("fall", -3.0)

	# Clear targets and paths so units re-evaluate with new command
	for i in units.count:
		if units.alive[i] == 1 and units.group_id[i] == group_id:
			units.target_unit[i] = -1
	ai.clear_paths_for_group(group_id)

func _physics_process(delta: float) -> void:
	# Phase 1: Deferred chunk loading (CHUNKS_PER_FRAME per frame)
	if not _chunks_done:
		_load_next_chunks()
		return

	# Phase 2: One-time battle initialization after all chunks loaded
	if not _battle_initialized:
		_finalize_battle_init()
		return

	if battle_ended:
		return

	var frame_start := Time.get_ticks_usec()
	var dt := delta * speed_multiplier
	battle_time += dt

	# Smooth camera zoom
	cam.zoom = cam.zoom.lerp(_target_zoom, ZOOM_SPEED * delta)

	# Commander switch cooldown
	if _commander_switch_cooldown > 0.0:
		_commander_switch_cooldown -= delta

	# Commander camera tracking — follow the selected commander unit
	if _active_commander_index >= 0 and not command_mode and cam.get_parent() != player:
		_update_blue_commanders()
		if _active_commander_index < _blue_commanders.size():
			var ci := _blue_commanders[_active_commander_index]
			if units.alive[ci] == 1:
				cam.global_position = cam.global_position.lerp(
					Vector2(units.x[ci], units.y[ci]), 6.0 * delta)
			else:
				# Commander died, switch back to player
				_switch_to_player()
		else:
			_switch_to_player()

	# Command mode: allow camera panning with WASD/arrows
	if command_mode and cam.get_parent() != player:
		var pan_speed := 800.0 / cam.zoom.x
		var pan := Vector2.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			pan.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			pan.y += 1
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			pan.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			pan.x += 1
		if pan != Vector2.ZERO:
			cam.global_position += pan.normalized() * pan_speed * delta

	var ox := float(tile_offset.x * TILE_SIZE)
	var oy := float(tile_offset.y * TILE_SIZE)
	var bw := pixel_region.size.x
	var bh := pixel_region.size.y

	# 1. Spatial hash
	var t := Time.get_ticks_usec()
	units.build_spatial_hash()
	_perf["hash"] = _perf.get("hash", 0) + (Time.get_ticks_usec() - t)

	# 2. Formation bonuses — throttled to every Nth frame
	_formation_frame += 1
	if _formation_frame >= FORMATION_THROTTLE:
		_formation_frame = 0
		t = Time.get_ticks_usec()
		units.update_formation_bonuses(commander)
		_perf["formation"] = _perf.get("formation", 0) + (Time.get_ticks_usec() - t)

	# 3. AI (movement + targeting + firing)
	if player and is_instance_valid(player):
		ai.player_position = player.global_position
		ai.player_alive = true
	else:
		ai.player_alive = false
	t = Time.get_ticks_usec()
	ai.update(dt)
	_perf["ai"] = _perf.get("ai", 0) + (Time.get_ticks_usec() - t)

	# 4. Projectiles
	t = Time.get_ticks_usec()
	projectiles.update(dt, units, ox + bw, oy + bh, ox, oy, _blocked_tiles)
	_check_soa_projectiles_vs_player()
	_check_player_bullets_vs_soa()
	_perf["proj"] = _perf.get("proj", 0) + (Time.get_ticks_usec() - t)

	# 5. Collision (terrain-aware)
	t = Time.get_ticks_usec()
	collision.resolve(units, dt, _blocked_tiles)
	_resolve_player_unit_collision()
	_check_player_abilities_vs_soa()
	_perf["collision"] = _perf.get("collision", 0) + (Time.get_ticks_usec() - t)

	# 6. Physics: velocity, friction, terrain collision with wall sliding, boundary clamp
	t = Time.get_ticks_usec()
	_update_unit_physics(dt, ox, oy, bw, bh)
	_perf["physics"] = _perf.get("physics", 0) + (Time.get_ticks_usec() - t)

	# 6b. Wave reinforcements
	if not _pending_blue_waves.is_empty() or not _pending_red_waves.is_empty():
		_wave_timer += dt
		if _wave_timer >= WAVE_INTERVAL:
			_wave_timer = 0.0
			_spawn_next_wave()

	# 7. Win/loss check (account for pending waves)
	var blue_alive := units.count_by_faction(BattleUnitSystem.Faction.BLUE)
	var red_alive := units.count_by_faction(BattleUnitSystem.Faction.RED)
	hud.update_counts(blue_alive, red_alive)
	hud.update_timer(battle_time)

	# Battle ambient SFX — play combat sounds periodically when armies are fighting
	_sfx_timer += dt
	if _sfx_timer >= 0.4:
		_sfx_timer = 0.0
		_play_battle_sfx(blue_alive, red_alive)
	_prev_blue_alive = blue_alive
	_prev_red_alive = red_alive

	# Win/loss check — victory when all current enemies dead (remaining waves are routed)
	if blue_alive == 0:
		_end_battle(false)
	elif red_alive == 0:
		_end_battle(true)

	# 8. Fog of war
	if fog:
		var pp := player.global_position if player and is_instance_valid(player) else Vector2.ZERO
		fog.update_fog(dt, pp, player != null and is_instance_valid(player))

	# 9. Update renderer
	t = Time.get_ticks_usec()
	renderer.selected_units = command_overlay.get_selected_units()
	renderer.fog = fog
	renderer.cam = cam
	renderer.update_visuals()
	_perf["render"] = _perf.get("render", 0) + (Time.get_ticks_usec() - t)

	# 10. Command banners + selection circles
	if command_mode:
		command_overlay.update_circles()  # Every frame — circles track units
		_banner_update_timer += dt
		if _banner_update_timer >= BANNER_UPDATE_INTERVAL:
			_banner_update_timer = 0.0
			command_overlay.update_banners()

	# Perf summary
	_perf["total"] = _perf.get("total", 0) + (Time.get_ticks_usec() - frame_start)
	_perf_frame += 1
	if _perf_frame >= PERF_INTERVAL:
		var n := float(_perf_frame)
		var parts := []
		for key in ["hash", "formation", "ai", "proj", "collision", "physics", "render", "tiles", "total"]:
			parts.append("%s=%.1fms" % [key, _perf.get(key, 0) / n / 1000.0])
		var msg := "PERF[%d frames]: %s" % [_perf_frame, " ".join(parts)]
		print(msg)
		# Also write to file for reliable capture
		var f := FileAccess.open("user://battle_perf.log", FileAccess.WRITE)
		if f:
			f.store_string(msg + "\n")
			f.close()
		_perf.clear()
		_perf_frame = 0

func _update_unit_physics(dt: float, ox: float, oy: float, bw: float, bh: float) -> void:
	for i in units.count:
		if units.alive[i] == 0:
			continue
		# Wall repulsion — push units away from adjacent blocked tiles
		var ux := units.x[i]
		var uy := units.y[i]
		var utx := int(floor(ux / TILE_SIZE))
		var uty := int(floor(uy / TILE_SIZE))
		var ur := units.radius[i]
		var repel_x := 0.0
		var repel_y := 0.0
		# Check 4 cardinal directions only (skip diagonals — 50% cheaper, nearly same effect)
		for wdir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			if _blocked_tiles.has(Vector2i(utx + wdir.x, uty + wdir.y)):
				var wcx: float = (utx + wdir.x + 0.5) * TILE_SIZE
				var wcy: float = (uty + wdir.y + 0.5) * TILE_SIZE
				var wdx := ux - wcx
				var wdy := uy - wcy
				var wdist := sqrt(wdx * wdx + wdy * wdy)
				if wdist < TILE_SIZE + ur and wdist > 0.1:
					var strength := 1.2 / maxf(0.5, wdist / TILE_SIZE)
					repel_x += (wdx / wdist) * strength
					repel_y += (wdy / wdist) * strength
		units.vx[i] += repel_x
		units.vy[i] += repel_y

		var prev_x := units.x[i]
		var prev_y := units.y[i]
		units.x[i] += units.vx[i] * dt * 60.0
		units.y[i] += units.vy[i] * dt * 60.0
		units.vx[i] *= FRICTION
		units.vy[i] *= FRICTION
		var r := units.radius[i]
		# Separate X/Y collision for wall sliding
		var blocked_x := false
		var blocked_y := false
		# Check X axis (single center ray — skip 3-ray for speed)
		var tx := int(floor(units.x[i] / TILE_SIZE))
		var ty := int(floor(prev_y / TILE_SIZE))
		if _blocked_tiles.has(Vector2i(tx, ty)):
			blocked_x = true
		var slide_force := absf(units.vx[i]) * 0.6
		if blocked_x:
			units.x[i] = prev_x
			if units.vy[i] > 0.01:
				units.vy[i] += slide_force
			elif units.vy[i] < -0.01:
				units.vy[i] -= slide_force
			else:
				units.vy[i] += slide_force * (1.0 if i % 2 == 0 else -1.0)
			units.vx[i] = 0.0
		# Check Y axis (single center ray)
		tx = int(floor(units.x[i] / TILE_SIZE))
		ty = int(floor(units.y[i] / TILE_SIZE))
		if _blocked_tiles.has(Vector2i(tx, ty)):
			blocked_y = true
		if blocked_y:
			units.y[i] = prev_y
			slide_force = absf(units.vy[i]) * 0.6
			if units.vx[i] > 0.01:
				units.vx[i] += slide_force
			elif units.vx[i] < -0.01:
				units.vx[i] -= slide_force
			else:
				units.vx[i] += slide_force * (1.0 if i % 2 == 0 else -1.0)
			units.vy[i] = 0.0
		if blocked_x and blocked_y:
			units.vx[i] = 0.0
			units.vy[i] = 0.0
		# Emergency: if unit is STILL inside a blocked tile, push to nearest clear tile
		var final_tx := int(floor(units.x[i] / TILE_SIZE))
		var final_ty := int(floor(units.y[i] / TILE_SIZE))
		if _blocked_tiles.has(Vector2i(final_tx, final_ty)):
			# Spiral search for nearest unblocked tile (up to 8 tiles away)
			var escaped := false
			for push_dist in range(1, 9):
				if escaped:
					break
				for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
							Vector2i(1,1), Vector2i(-1,1), Vector2i(1,-1), Vector2i(-1,-1)]:
					var check := Vector2i(final_tx + dir.x * push_dist, final_ty + dir.y * push_dist)
					if not _blocked_tiles.has(check):
						units.x[i] = (check.x + 0.5) * TILE_SIZE
						units.y[i] = (check.y + 0.5) * TILE_SIZE
						units.vx[i] = 0.0
						units.vy[i] = 0.0
						escaped = true
						break
		units.x[i] = clampf(units.x[i], ox + r, ox + bw - r)
		units.y[i] = clampf(units.y[i], oy + r, oy + bh - r)

func _end_battle(victory: bool) -> void:
	battle_ended = true
	if command_mode:
		_toggle_command_mode()
	hud.show_result(victory)

	# Track hired fighter losses — count surviving blue units by type
	_update_hired_fighter_losses()

	# Process veterans — promote surviving BLUE units
	_process_veterans(victory)

	# Award troop tokens
	_award_troop_tokens(victory)

	# Compute survival ratios for territory consequences
	var blue_alive := units.count_by_faction(BattleUnitSystem.Faction.BLUE)
	var blue_survival := float(blue_alive) / maxf(float(_initial_blue_count), 1.0)
	var red_alive := units.count_by_faction(BattleUnitSystem.Faction.RED)
	var red_survival := float(red_alive) / maxf(float(_initial_red_count), 1.0)

	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("on_battle_ended"):
		var cfg := gm.battle_config as Dictionary
		gm.on_battle_ended({
			"victory": victory,
			"zone_name": cfg.get("zone_name", ""),
			"army_id": cfg.get("army_id", cfg.get("zone_name", "")),
			"blue_survival": blue_survival,
			"red_survival": red_survival,
		})

func _award_troop_tokens(victory: bool) -> void:
	## Award troop tokens based on battle outcome.
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.save_data:
		return
	if not victory:
		return  # No tokens on defeat

	var enemy_tier: int = _config.get("enemy_tier", 1)
	var blue_alive := units.count_by_faction(BattleUnitSystem.Faction.BLUE)
	var blue_survival := float(blue_alive) / maxf(float(_initial_blue_count), 1.0)
	var decisive := blue_survival > 0.5
	var pyrrhic := blue_survival < 0.2

	# Base: 5 + enemy_tier * 3 + (decisive ? 5 : 0) = 8-20 tokens
	var tokens := 5 + enemy_tier * 3
	if decisive:
		tokens += 5
	if pyrrhic:
		tokens = tokens / 2  # Half tokens for pyrrhic victory

	# Zone conquest bonus
	var zone_name: String = _config.get("zone_name", "")
	if zone_name != "":
		tokens += 10

	gm.save_data.troop_tokens += tokens
	print("BattleArena: Awarded %d troop tokens (total: %d)" % [tokens, gm.save_data.troop_tokens])

func _process_veterans(victory: bool) -> void:
	## After battle, count surviving BLUE units by type and promote veterans.
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.save_data:
		return
	if not victory:
		# On defeat, lose some veterans
		_reduce_veterans_on_defeat()
		return

	if not gm.save_data.army_state.has("veterans"):
		gm.save_data.army_state["veterans"] = {}

	var type_key_map := {
		BattleUnitSystem.UnitType.INFANTRY: "infantry",
		BattleUnitSystem.UnitType.HEAVY_INFANTRY: "heavy_infantry",
		BattleUnitSystem.UnitType.CAVALRY: "cavalry",
		BattleUnitSystem.UnitType.HEAVY_CAVALRY: "heavy_cavalry",
		BattleUnitSystem.UnitType.ARCHER: "archer",
		BattleUnitSystem.UnitType.MAGE: "mage",
	}

	# Count survivors by type and veteran rank
	var survivors := {}  # type_name -> {0: count, 1: count, 2: count, 3: count}
	for i in units.count:
		if units.alive[i] == 1 and units.faction[i] == BattleUnitSystem.Faction.BLUE:
			var tname: String = type_key_map.get(units.unit_type[i], "")
			if tname == "":
				continue
			if not survivors.has(tname):
				survivors[tname] = {0: 0, 1: 0, 2: 0, 3: 0}
			var rank: int = units.veteran_rank[i]
			survivors[tname][rank] = survivors[tname].get(rank, 0) + 1

	# Promote survivors: each survivor gains 1 battle toward next rank
	# Raw(0 battles)→Trained(1)→Veteran(3)→Elite(5)
	# For simplicity: surviving raw → trained, surviving trained → veteran (if 3+ battles tracked),
	# We just promote each tier up by 1 rank on victory
	var veterans: Dictionary = gm.save_data.army_state["veterans"]
	for tname in survivors:
		if not veterans.has(tname):
			veterans[tname] = {"trained": 0, "veteran": 0, "elite": 0}
		# Promote existing veterans that survived
		var surviving_elite: int = survivors[tname].get(3, 0)
		var surviving_veteran: int = survivors[tname].get(2, 0)
		var surviving_trained: int = survivors[tname].get(1, 0)
		var surviving_raw: int = survivors[tname].get(0, 0)

		# Elite stays elite, veteran promotes to elite, trained to veteran, raw to trained
		var new_elite: int = surviving_elite + int(surviving_veteran * 0.5)  # 50% of veterans promote
		var new_veteran: int = int(surviving_veteran * 0.5) + int(surviving_trained * 0.4)
		var new_trained: int = int(surviving_trained * 0.6) + int(surviving_raw * 0.3)

		var vet_data: Dictionary = veterans.get(tname, {})
		vet_data["elite"] = new_elite
		vet_data["veteran"] = new_veteran
		vet_data["trained"] = new_trained
		veterans[tname] = vet_data

	gm.save_data.army_state["veterans"] = veterans
	print("BattleArena: Veterans updated — %s" % str(veterans))

func _reduce_veterans_on_defeat() -> void:
	## On defeat, lose ~50% of veterans.
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.save_data:
		return
	if not gm.save_data.army_state.has("veterans"):
		return
	var veterans: Dictionary = gm.save_data.army_state["veterans"]
	for tname in veterans:
		var vet_data: Dictionary = veterans[tname]
		vet_data["trained"] = maxi(0, int(vet_data.get("trained", 0) * 0.5))
		vet_data["veteran"] = maxi(0, int(vet_data.get("veteran", 0) * 0.5))
		vet_data["elite"] = maxi(0, int(vet_data.get("elite", 0) * 0.7))  # Elite survive better
		veterans[tname] = vet_data

func _update_hired_fighter_losses() -> void:
	## After battle, reduce hired fighters to match surviving blue units.
	## Also sync army_divisions to reflect losses.
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.save_data:
		return
	if not gm.save_data.army_state.has("hired_fighters"):
		return

	# Count surviving blue units by type
	var type_name_map := {
		BattleUnitSystem.UnitType.INFANTRY: "infantry",
		BattleUnitSystem.UnitType.HEAVY_INFANTRY: "heavy_infantry",
		BattleUnitSystem.UnitType.CAVALRY: "cavalry",
		BattleUnitSystem.UnitType.HEAVY_CAVALRY: "heavy_cavalry",
		BattleUnitSystem.UnitType.ARCHER: "archer",
		BattleUnitSystem.UnitType.MAGE: "mage",
		BattleUnitSystem.UnitType.SPEAR: "spear",
		BattleUnitSystem.UnitType.HORSE_ARCHER: "horse_archer",
		BattleUnitSystem.UnitType.RANGED_INFANTRY: "ranged_infantry",
	}

	var surviving := {}
	for i in units.count:
		if units.alive[i] == 1 and units.faction[i] == BattleUnitSystem.Faction.BLUE:
			var tname: String = type_name_map.get(units.unit_type[i], "")
			if tname != "":
				surviving[tname] = surviving.get(tname, 0) + 1

	# Surviving count IS the new hired count (no free militia except 5 min infantry)
	# Subtract the 5 minimum militia infantry that aren't "hired"
	var hired: Dictionary = gm.save_data.army_state.get("hired_fighters", {})
	var old_hired := hired.duplicate()
	for type_name in hired:
		var alive: int = surviving.get(type_name, 0)
		if type_name == "infantry":
			# 5 minimum militia aren't hired — don't count them
			hired[type_name] = maxi(0, alive - 5)
		else:
			# All surviving of this type are hired
			hired[type_name] = alive
	# Clean up zeros
	var to_remove: Array[String] = []
	for type_name in hired:
		if int(hired[type_name]) <= 0:
			to_remove.append(type_name)
	for type_name in to_remove:
		hired.erase(type_name)

	# Debug: print losses
	for type_name in old_hired:
		var was: int = int(old_hired[type_name])
		var now: int = int(hired.get(type_name, 0))
		if was != now:
			print("  Army loss: %s %d -> %d (-%d)" % [type_name, was, now, was - now])

	# Sync divisions — cap each division's unit counts to available hired fighters
	_sync_divisions_to_hired(gm.save_data)

func _sync_divisions_to_hired(save_data) -> void:
	## After losses, reduce division unit counts so they don't exceed available troops.
	var hired: Dictionary = save_data.army_state.get("hired_fighters", {})
	# Count how many of each type are allocated across all divisions
	var allocated := {}  # type_name -> total across all divs
	for div in save_data.army_divisions:
		for unit_entry in div.get("units", []):
			var tn: String = unit_entry.get("type", "")
			allocated[tn] = allocated.get(tn, 0) + int(unit_entry.get("count", 0))

	# For each type, if allocated > available, scale down proportionally
	for tn in allocated:
		var available: int = int(hired.get(tn, 0))
		if tn == "infantry":
			available += 5  # account for minimum militia
		var total_alloc: int = allocated[tn]
		if total_alloc > available and total_alloc > 0:
			var ratio := float(available) / float(total_alloc)
			var remaining := available
			for div in save_data.army_divisions:
				for unit_entry in div.get("units", []):
					if unit_entry.get("type", "") == tn:
						var new_count := mini(remaining, maxi(0, int(int(unit_entry["count"]) * ratio)))
						remaining -= new_count
						unit_entry["count"] = new_count
			print("  Division sync: %s allocated %d -> capped to %d" % [tn, total_alloc, available])

func _on_player_died() -> void:
	if battle_ended:
		return
	# Supreme leader died — entire army routs!
	if player and is_instance_valid(player):
		player.visible = false
		player.set_physics_process(false)
		player.set_process(false)
	ai.player_alive = false

	# Crush all BLUE morale — army routs
	for i in units.count:
		if units.alive[i] == 1 and units.faction[i] == BattleUnitSystem.Faction.BLUE:
			units.morale[i] = 0.0  # Broken — will rout
	# Set all BLUE groups to retreat
	var blue_groups := commander.get_faction_groups(BattleUnitSystem.Faction.BLUE)
	for g in blue_groups:
		g.command = BattleCommander.CommandType.RETREAT
	print("SUPREME LEADER FALLEN — Army is routing!")
	# Battle ends as loss after a brief delay for the rout to play out
	get_tree().create_timer(5.0).timeout.connect(func(): _end_battle(false))

func _play_battle_sfx(blue_alive: int, red_alive: int) -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if not sfx:
		return
	var total_alive := blue_alive + red_alive
	if total_alive <= 0:
		return

	# Death sounds when units die
	var blue_died := _prev_blue_alive - blue_alive
	var red_died := _prev_red_alive - red_alive
	var total_died := blue_died + red_died
	if total_died >= 3:
		sfx.play(["impact_a", "impact_b", "boom_a"].pick_random(), -4.0)
	elif total_died >= 1:
		sfx.play(["hit", "impact_a", "impact_b"].pick_random(), -8.0)

	# Ambient combat sounds based on how many units are in combat
	# Count units that are actively fighting (have enemies nearby)
	var fighting := 0
	for i in units.count:
		if units.alive[i] == 1 and units.target_unit[i] >= 0:
			fighting += 1

	if fighting > 40:
		sfx.play(["swing", "clack", "attack_b"].pick_random(), randf_range(-12.0, -8.0))
	elif fighting > 15:
		if randf() < 0.6:
			sfx.play(["swing", "clack"].pick_random(), randf_range(-14.0, -10.0))
	elif fighting > 5:
		if randf() < 0.3:
			sfx.play(["swing", "hit"].pick_random(), randf_range(-16.0, -12.0))

func _on_retreat() -> void:
	if battle_ended:
		return
	_end_battle(false)

func _on_return() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("return_to_overworld"):
		gm.return_to_overworld()
	else:
		if ResourceLoader.exists("res://scenes/overworld/overworld.scn"):
			get_tree().change_scene_to_file("res://scenes/overworld/overworld.scn")
		else:
			get_tree().change_scene_to_file("res://scenes/overworld/overworld.tscn")

func _hide_gamehud_clutter() -> void:
	## Hide inventory/equipment/map/quest UI from GameHUD during battle.
	## Keep only VitalsPanel (HP/MP/stamina bars) visible.
	if not game_hud or not is_instance_valid(game_hud):
		return
	for child in game_hud.get_children():
		if child is Control:
			match child.name:
				"VitalsPanel":
					child.visible = true  # Keep HP/MP bars
				_:
					child.visible = false  # Hide everything else (quickbar, spells, info, action buttons, minimap)

var _player_contact_dmg_timer: float = 0.0
const PLAYER_CONTACT_DMG_INTERVAL := 0.4  # Melee damage every 0.4s

func _resolve_player_unit_collision() -> void:
	if not player or not is_instance_valid(player):
		return
	var px := player.global_position.x
	var py := player.global_position.y
	var player_r := 12.0
	var nearby := units.get_nearby(px, py, 64.0)
	var contact_enemies := 0
	for idx in nearby:
		if units.alive[idx] == 0:
			continue
		var dx := px - units.x[idx]
		var dy := py - units.y[idx]
		var dist := sqrt(dx * dx + dy * dy)
		var min_dist := player_r + units.radius[idx]
		if dist < min_dist and dist > 0.1:
			var overlap := min_dist - dist
			var nx := dx / dist
			var ny := dy / dist
			# Push the SoA unit away from player — but not into blocked tiles
			var push := overlap * 0.8
			var new_ux := units.x[idx] + nx * push
			var new_uy := units.y[idx] + ny * push
			var check_tx := int(floor(new_ux / TILE_SIZE))
			var check_ty := int(floor(new_uy / TILE_SIZE))
			if not _blocked_tiles.has(Vector2i(check_tx, check_ty)):
				units.x[idx] = new_ux
				units.y[idx] = new_uy
			units.vx[idx] += nx * 0.3
			units.vy[idx] += ny * 0.3
			if units.faction[idx] == BattleUnitSystem.Faction.RED:
				contact_enemies += 1
				player.velocity += Vector2(-nx, -ny) * overlap * 20.0
	# Player deals contact damage to enemies (like overworld)
	if contact_enemies > 0:
		_player_contact_dmg_timer += get_physics_process_delta_time()
		if _player_contact_dmg_timer >= PLAYER_CONTACT_DMG_INTERVAL:
			_player_contact_dmg_timer = 0.0
			# Player damages enemies on contact
			var player_dmg := 5.0
			if player.get("equipment_manager"):
				player_dmg = float(player.equipment_manager.get_damage()) * 0.5
				for idx2 in nearby:
					if units.alive[idx2] == 0 or units.faction[idx2] != BattleUnitSystem.Faction.RED:
						continue
					var d2 := sqrt((units.x[idx2] - px) * (units.x[idx2] - px) + (units.y[idx2] - py) * (units.y[idx2] - py))
					if d2 < player_r + units.radius[idx2] + 5.0:
						var angle := atan2(units.y[idx2] - py, units.x[idx2] - px)
						units.damage(idx2, player_dmg, angle, false)
						units.vx[idx2] += cos(angle) * 1.5
						units.vy[idx2] += sin(angle) * 1.5
			# Enemies damage player
			var melee_dmg := contact_enemies * 3
			if player.has_method("take_damage"):
				player.take_damage(melee_dmg, player.global_position)
	else:
		_player_contact_dmg_timer = 0.0

func _on_bullet_spawned(node: Node) -> void:
	# Scale up player bullets to be visible at battle camera zoom
	if node is Area2D:
		node.scale = Vector2(3.0, 3.0)

# --- Player ↔ SoA Bridge ---

func _check_player_bullets_vs_soa() -> void:
	# Find bullets container and check each player bullet against SoA units
	var container = get_tree().get_first_node_in_group("bullets")
	if not container:
		return
	for bullet in container.get_children():
		if not is_instance_valid(bullet) or not bullet.get("is_player_bullet"):
			continue
		if bullet.get("_spent"):
			continue
		var bx: float = bullet.global_position.x
		var by: float = bullet.global_position.y
		var bdmg: int = bullet.get("damage") if bullet.get("damage") else 10
		var hit_r: float = 6.0  # bullet hit radius
		var nearby := units.get_nearby(bx, by, 32.0)
		var vfx = get_node_or_null("/root/VFXManager")
		# Check against nearby SoA units (all factions — player can hit both, but focus on RED enemies)
		for idx in nearby:
			if units.alive[idx] == 0:
				continue
			# Player bullets hit RED (enemy) units
			if units.faction[idx] != BattleUnitSystem.Faction.RED:
				continue
			var dx: float = units.x[idx] - bx
			var dy: float = units.y[idx] - by
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist < units.radius[idx] + hit_r:
				var angle := atan2(dy, dx)
				units.damage(idx, float(bdmg), angle, false)
				# Knockback
				if dist > 0.01:
					var kb := 0.8
					units.vx[idx] += (dx / dist) * kb
					units.vy[idx] += (dy / dist) * kb
				# VFX
				if vfx and vfx.has_method("spawn_hit_spark"):
					vfx.spawn_hit_spark(Vector2(units.x[idx], units.y[idx]))
				# Consume bullet (pierce handling)
				var hits_remaining = bullet.get("_hits_remaining") if bullet.get("_hits_remaining") != null else 1
				hits_remaining -= 1
				if hits_remaining <= 0:
					bullet.queue_free()
				else:
					bullet.set("_hits_remaining", hits_remaining)
				break  # One hit per frame per bullet

func _check_soa_projectiles_vs_player() -> void:
	if not player or not is_instance_valid(player):
		return
	var player_r: float = 12.0  # player hit radius
	for i in projectiles.count:
		if projectiles.alive[i] == 0:
			continue
		# Only RED (enemy) projectiles hit player
		if projectiles.proj_faction[i] != BattleUnitSystem.Faction.RED:
			continue
		var dx: float = projectiles.x[i] - player.global_position.x
		var dy: float = projectiles.y[i] - player.global_position.y
		var dist: float = sqrt(dx * dx + dy * dy)
		if dist < player_r + 3.0:  # 3.0 = projectile radius
			# Damage the player
			var dmg_val: float = projectiles.dmg[i]
			var proj_pos := Vector2(projectiles.x[i], projectiles.y[i])
			if player.has_method("take_damage"):
				player.take_damage(int(dmg_val), proj_pos)
			# VFX
			var vfx = get_node_or_null("/root/VFXManager")
			if vfx and vfx.has_method("spawn_hit_spark"):
				vfx.spawn_hit_spark(player.global_position)
			projectiles.alive[i] = 0

var _ability_check_timer: float = 0.0

func _check_player_abilities_vs_soa() -> void:
	## Bridge player AoE abilities to SoA units.
	## Checks if player is dashing (dash damage) or using an ability that
	## sets meta flags, and applies effects to nearby SoA enemies.
	if not player or not is_instance_valid(player):
		return

	var px: float = player.global_position.x
	var py: float = player.global_position.y
	var nearby := units.get_nearby(px, py, 180.0)

	# Dash damage — player is dashing through enemies
	if player.get("_is_dashing") and player._is_dashing:
		var dash_radius := 30.0
		var dash_dmg := 8.0
		if player.get("equipment_manager"):
			dash_dmg = float(player.equipment_manager.get_damage()) * 0.8
		for idx in nearby:
			if units.alive[idx] == 0 or units.faction[idx] != BattleUnitSystem.Faction.RED:
				continue
			var dx: float = units.x[idx] - px
			var dy: float = units.y[idx] - py
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist < dash_radius + units.radius[idx]:
				var angle := atan2(dy, dx)
				units.damage(idx, dash_dmg, angle, false)
				units.vx[idx] += cos(angle) * 3.0
				units.vy[idx] += sin(angle) * 3.0
				units.stagger_time[idx] = maxf(units.stagger_time[idx], 0.3)

	# Ability AoE — check player meta for active ability effects
	# Shield bash, frost nova, battle cry etc. set a meta "battle_aoe" on the player
	if player.has_meta("battle_aoe"):
		var aoe: Dictionary = player.get_meta("battle_aoe")
		player.remove_meta("battle_aoe")
		var aoe_radius: float = aoe.get("radius", 100.0)
		var aoe_dmg: float = aoe.get("damage", 10.0)
		var aoe_stun: float = aoe.get("stun", 0.0)
		var aoe_kb: float = aoe.get("knockback", 0.0)
		var aoe_dir: Vector2 = aoe.get("direction", Vector2.ZERO)
		var aoe_cone: float = aoe.get("cone_angle", PI * 2.0)
		# Some abilities (frost nova) target a position, not the player
		var aoe_center: Vector2 = aoe.get("center", Vector2(px, py))
		var aoe_nearby := units.get_nearby(aoe_center.x, aoe_center.y, aoe_radius + 30.0)
		for idx in aoe_nearby:
			if units.alive[idx] == 0 or units.faction[idx] != BattleUnitSystem.Faction.RED:
				continue
			var dx := units.x[idx] - aoe_center.x
			var dy := units.y[idx] - aoe_center.y
			var dist := sqrt(dx * dx + dy * dy)
			if dist > aoe_radius + units.radius[idx]:
				continue
			# Cone check if directional (cone_angle = half-angle in radians)
			if aoe_cone < PI * 1.9 and aoe_dir.length_squared() > 0.01:
				var to_unit := Vector2(dx, dy).normalized()
				if absf(aoe_dir.angle_to(to_unit)) > aoe_cone:
					continue
			var angle := atan2(dy, dx)
			if aoe_dmg > 0:
				units.damage(idx, aoe_dmg, angle, false)
			if aoe_stun > 0:
				units.stagger_time[idx] = maxf(units.stagger_time[idx], aoe_stun)
			if aoe_kb > 0 and dist > 0.1:
				units.vx[idx] += cos(angle) * aoe_kb
				units.vy[idx] += sin(angle) * aoe_kb
