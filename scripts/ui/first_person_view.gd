class_name FirstPersonView
extends CanvasLayer

## 3D first-person view overlay.
## Multi-source tile textures, decoration objects as upright quads, entity billboards.

var enabled: bool = false
var tile_size: float = 8.0
var _camera: Camera3D
var _world: Node3D
var _container: SubViewportContainer
var _viewport: SubViewport
var _walkable: Dictionary = {}
var _wall_cells: Dictionary = {}
var _theme_row: int = 0
var wall_layer: TileMapLayer
var floor_layer: TileMapLayer

# Multi-source texture system
# source_id -> {path, cols, rows, texture, material, mesh_instance}
var _sources: Dictionary = {}
var _mesh_container: Node3D

# Decoration/object layers to render as upright X-cross quads
var _object_layers: Array = []  # [{layer: TileMapLayer, name: String, filter: Callable}]

# Floor overlay layers (liquids, paths) rendered as floor-level quads (Y=0.01)
var _floor_overlay_layers: Array = []  # [{layer: TileMapLayer, name: String}]

# Overworld mode
var _is_overworld: bool = false
var _rebuild_radius: int = 40
var _last_rebuild_cell: Vector2i = Vector2i(-9999, -9999)
const REBUILD_MOVE_THRESHOLD = 8
var _extra_wall_layers: Array = []
var _overworld_ref = null

var _has_ceiling: bool = true
var _sky_color: Color = Color(0.05, 0.05, 0.1)

# Billboard system
var _billboards: Dictionary = {}
var _billboard_container: Node3D
var _scene_tree: SceneTree

func setup(p_tile_size: float) -> void:
	tile_size = p_tile_size
	layer = 100

	_container = SubViewportContainer.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.stretch = true
	add_child(_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(960, 540)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	_container.add_child(_viewport)

	_world = Node3D.new()
	_world.name = "World3D"
	_viewport.add_child(_world)

	_camera = Camera3D.new()
	_camera.fov = 75.0
	_camera.near = 0.05
	_camera.far = 50.0
	_world.add_child(_camera)

	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _sky_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.ambient_light_energy = 0.5
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	_world.add_child(world_env)

	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 0.8
	sun.shadow_enabled = false
	_world.add_child(sun)

	_mesh_container = Node3D.new()
	_mesh_container.name = "Meshes"
	_world.add_child(_mesh_container)

	_billboard_container = Node3D.new()
	_billboard_container.name = "Billboards"
	_world.add_child(_billboard_container)

func add_source(source_id: int, texture_path: String, cols: int, rows: int) -> void:
	var tex = load(texture_path) as Texture2D
	if not tex:
		print("FPV: failed to load texture %s" % texture_path)
		return
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Enable alpha for textures with transparency (decorations)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5

	var mi = MeshInstance3D.new()
	mi.name = "Source%d" % source_id
	_mesh_container.add_child(mi)

	_sources[source_id] = {
		"cols": cols,
		"rows": rows,
		"texture": tex,
		"material": mat,
		"mesh_instance": mi,
	}

func set_layers(p_floor: TileMapLayer, p_wall: TileMapLayer) -> void:
	floor_layer = p_floor
	wall_layer = p_wall

func add_object_layer(p_layer: TileMapLayer, p_name: String) -> void:
	_object_layers.append({"layer": p_layer, "name": p_name})

func add_floor_overlay_layer(p_layer: TileMapLayer, p_name: String) -> void:
	_floor_overlay_layers.append({"layer": p_layer, "name": p_name})

func setup_overworld(overworld_node, p_buildings: TileMapLayer, p_fences: TileMapLayer, p_water: TileMapLayer) -> void:
	_is_overworld = true
	_has_ceiling = false
	_sky_color = Color(0.4, 0.55, 0.8)
	_overworld_ref = overworld_node
	_extra_wall_layers = [p_buildings, p_fences, p_water]
	if _world:
		for child in _world.get_children():
			if child is WorldEnvironment:
				child.environment.background_color = _sky_color
				break

func set_walkable(nav) -> void:
	_walkable = nav._walkable.duplicate()
	_last_rebuild_cell = Vector2i(-9999, -9999)
	rebuild_mesh()

func set_overworld_walkable_around(center_px: Vector2) -> void:
	var center_cell = Vector2i(int(floor(center_px.x / tile_size)), int(floor(center_px.y / tile_size)))
	if center_cell.distance_to(_last_rebuild_cell) < REBUILD_MOVE_THRESHOLD:
		return
	_last_rebuild_cell = center_cell

	_walkable.clear()
	_wall_cells.clear()
	var r = _rebuild_radius
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cell = Vector2i(center_cell.x + dx, center_cell.y + dy)
			if floor_layer.get_cell_source_id(cell) >= 0:
				_walkable[cell] = true
			var is_wall = false
			for i in range(_extra_wall_layers.size()):
				var wl = _extra_wall_layers[i]
				var src = wl.get_cell_source_id(cell)
				if src >= 0:
					var atlas = wl.get_cell_atlas_coords(cell)
					var lname = ["buildings", "fences", "water"][i]
					if _overworld_ref and _overworld_ref.has_method("_is_blocking_tile"):
						if _overworld_ref._is_blocking_tile(lname, src, atlas):
							is_wall = true
					else:
						is_wall = true
			if is_wall:
				_walkable.erase(cell)
				_wall_cells[cell] = true
	rebuild_mesh()

func set_theme_row(row: int) -> void:
	_theme_row = row

func update_camera(pos_2d: Vector2, angle: float) -> void:
	if not _camera:
		return
	var x3d = pos_2d.x / tile_size
	var z3d = pos_2d.y / tile_size
	var eye_h = 0.5 if _has_ceiling else 0.8
	_camera.global_position = Vector3(x3d, eye_h, z3d)
	_camera.rotation = Vector3(0, -(angle + PI / 2.0), 0)

	if _is_overworld and visible:
		set_overworld_walkable_around(pos_2d)

	_update_billboards(pos_2d)

# --- Multi-source mesh building ---

func _get_uv(source_id: int, atlas: Vector2i) -> Array:
	## Returns [uv_x, uv_y, uv_w, uv_h] for a tile in the given source
	if not _sources.has(source_id):
		return [0.0, 0.0, 0.0625, 0.0625]
	var s = _sources[source_id]
	var uv_w = 1.0 / float(s["cols"])
	var uv_h = 1.0 / float(s["rows"])
	return [atlas.x * uv_w, atlas.y * uv_h, uv_w, uv_h]

func _get_or_fallback_source(source_id: int) -> int:
	if _sources.has(source_id):
		return source_id
	# Return first available source as fallback
	for sid in _sources:
		return sid
	return -1

func rebuild_mesh() -> void:
	if _walkable.is_empty():
		return

	# One SurfaceTool per source
	var surface_tools: Dictionary = {}  # source_id -> SurfaceTool
	for sid in _sources:
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface_tools[sid] = st

	var wall_height = 1.0 if _has_ceiling else 1.5
	var first_source = _get_or_fallback_source(0)

	for cell in _walkable:
		var fx = float(cell.x)
		var fz = float(cell.y)

		# --- Floor ---
		var floor_src = floor_layer.get_cell_source_id(cell) if floor_layer else -1
		var floor_atlas: Vector2i
		if floor_src >= 0:
			floor_atlas = floor_layer.get_cell_atlas_coords(cell)
		else:
			floor_src = first_source
			floor_atlas = Vector2i(5, _theme_row) if not _is_overworld else Vector2i(2, 1)
		var fsid = _get_or_fallback_source(floor_src)
		if fsid >= 0 and surface_tools.has(fsid):
			# Use atlas coords from actual source; if falling back, use defaults
			var actual_atlas = floor_atlas if _sources.has(floor_src) else (Vector2i(5, _theme_row) if not _is_overworld else Vector2i(2, 1))
			var uv = _get_uv(fsid, actual_atlas)
			_add_quad(surface_tools[fsid],
				Vector3(fx, 0, fz),         Vector3(fx + 1, 0, fz),
				Vector3(fx + 1, 0, fz + 1), Vector3(fx, 0, fz + 1),
				Vector3(0, 1, 0), uv[0], uv[1], uv[2], uv[3])

		# --- Ceiling (dungeons) ---
		if _has_ceiling and fsid >= 0 and surface_tools.has(fsid):
			var cuv = _get_uv(fsid, Vector2i(0, 1))
			_add_quad(surface_tools[fsid],
				Vector3(fx, wall_height, fz + 1),   Vector3(fx + 1, wall_height, fz + 1),
				Vector3(fx + 1, wall_height, fz),   Vector3(fx, wall_height, fz),
				Vector3(0, -1, 0), cuv[0], cuv[1], cuv[2], cuv[3])

		# --- Wall faces ---
		for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			if _walkable.has(cell + dir):
				continue
			var neighbor = cell + dir
			var wall_src = -1
			var wall_atlas = Vector2i(4, _theme_row) if not _is_overworld else Vector2i(0, 7)

			# Check all wall-providing layers for the neighbor tile's texture
			if wall_layer and wall_layer.get_cell_source_id(neighbor) >= 0:
				wall_src = wall_layer.get_cell_source_id(neighbor)
				wall_atlas = wall_layer.get_cell_atlas_coords(neighbor)
			else:
				for wl in _extra_wall_layers:
					if wl.get_cell_source_id(neighbor) >= 0:
						wall_src = wl.get_cell_source_id(neighbor)
						wall_atlas = wl.get_cell_atlas_coords(neighbor)
						break

			var wsid = _get_or_fallback_source(wall_src) if wall_src >= 0 else first_source
			if wsid < 0 or not surface_tools.has(wsid):
				continue
			var actual_wall_atlas = wall_atlas if _sources.has(wall_src) else (Vector2i(4, _theme_row) if not _is_overworld else Vector2i(0, 7))
			var wuv = _get_uv(wsid, actual_wall_atlas)

			var n: Vector3
			var v0: Vector3; var v1: Vector3; var v2: Vector3; var v3: Vector3
			if dir == Vector2i(1, 0):
				n = Vector3(-1, 0, 0)
				v0 = Vector3(fx+1, 0, fz);    v1 = Vector3(fx+1, wall_height, fz)
				v2 = Vector3(fx+1, wall_height, fz+1); v3 = Vector3(fx+1, 0, fz+1)
			elif dir == Vector2i(-1, 0):
				n = Vector3(1, 0, 0)
				v0 = Vector3(fx, 0, fz+1);    v1 = Vector3(fx, wall_height, fz+1)
				v2 = Vector3(fx, wall_height, fz); v3 = Vector3(fx, 0, fz)
			elif dir == Vector2i(0, 1):
				n = Vector3(0, 0, -1)
				v0 = Vector3(fx+1, 0, fz+1);  v1 = Vector3(fx+1, wall_height, fz+1)
				v2 = Vector3(fx, wall_height, fz+1); v3 = Vector3(fx, 0, fz+1)
			else:
				n = Vector3(0, 0, 1)
				v0 = Vector3(fx, 0, fz);      v1 = Vector3(fx, wall_height, fz)
				v2 = Vector3(fx+1, wall_height, fz); v3 = Vector3(fx+1, 0, fz)
			_add_quad(surface_tools[wsid], v0, v1, v2, v3, n, wuv[0], wuv[1], wuv[2], wuv[3])

	# --- Floor overlay layers (liquids, paths, water) as floor-level quads ---
	_build_floor_overlays(surface_tools)

	# --- Decoration/object tiles as upright X-cross quads ---
	_build_object_quads(surface_tools)

	# Commit all sources
	for sid in _sources:
		var st = surface_tools[sid]
		st.generate_tangents()
		var mesh = st.commit()
		_sources[sid]["mesh_instance"].mesh = mesh
		_sources[sid]["mesh_instance"].material_override = _sources[sid]["material"]

func _build_floor_overlays(surface_tools: Dictionary) -> void:
	## Render floor overlay tiles (liquids, paths, water) as floor-level quads at Y=0.01
	for overlay_info in _floor_overlay_layers:
		var overlay_layer = overlay_info["layer"] as TileMapLayer
		var cells_to_check: Array
		if _is_overworld:
			cells_to_check = []
			var r = _rebuild_radius
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var cell = Vector2i(_last_rebuild_cell.x + dx, _last_rebuild_cell.y + dy)
					if overlay_layer.get_cell_source_id(cell) >= 0:
						cells_to_check.append(cell)
		else:
			# Dungeon: check all walkable + nearby cells
			var check_set: Dictionary = {}
			for cell in _walkable:
				check_set[cell] = true
				for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					check_set[cell + d] = true
			cells_to_check = check_set.keys()

		for cell in cells_to_check:
			var src = overlay_layer.get_cell_source_id(cell)
			if src < 0:
				continue
			var sid = _get_or_fallback_source(src)
			if sid < 0 or not surface_tools.has(sid):
				continue
			var atlas = overlay_layer.get_cell_atlas_coords(cell)
			var actual_atlas = atlas if _sources.has(src) else Vector2i(0, 0)
			var uv = _get_uv(sid, actual_atlas)
			var fx = float(cell.x)
			var fz = float(cell.y)
			# Floor-level quad slightly above the base floor to avoid z-fighting
			_add_quad(surface_tools[sid],
				Vector3(fx, 0.01, fz),         Vector3(fx + 1, 0.01, fz),
				Vector3(fx + 1, 0.01, fz + 1), Vector3(fx, 0.01, fz + 1),
				Vector3(0, 1, 0), uv[0], uv[1], uv[2], uv[3])

func _build_object_quads(surface_tools: Dictionary) -> void:
	## Render decoration tiles as upright X-cross quads (visible from all angles)
	for obj_info in _object_layers:
		var obj_layer = obj_info["layer"] as TileMapLayer
		var cells_to_check: Array
		if _is_overworld:
			cells_to_check = []
			var r = _rebuild_radius
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var cell = Vector2i(_last_rebuild_cell.x + dx, _last_rebuild_cell.y + dy)
					if obj_layer.get_cell_source_id(cell) >= 0:
						cells_to_check.append(cell)
		else:
			# Dungeon: check all walkable + nearby cells
			var check_set: Dictionary = {}
			for cell in _walkable:
				check_set[cell] = true
				for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					check_set[cell + d] = true
			cells_to_check = check_set.keys()

		for cell in cells_to_check:
			var src = obj_layer.get_cell_source_id(cell)
			if src < 0:
				continue
			var sid = _get_or_fallback_source(src)
			if sid < 0 or not surface_tools.has(sid):
				continue
			var atlas = obj_layer.get_cell_atlas_coords(cell)
			var actual_atlas = atlas if _sources.has(src) else Vector2i(0, 0)
			var uv = _get_uv(sid, actual_atlas)
			var fx = float(cell.x)
			var fz = float(cell.y)
			var cx = fx + 0.5  # center of tile
			var cz = fz + 0.5
			var h = 0.9 if _has_ceiling else 1.3
			var half = 0.5  # half-width of quad

			# X-cross pattern: two perpendicular quads through center
			# Quad 1: along Z axis (front + back)
			_add_quad(surface_tools[sid],
				Vector3(cx - half, 0, cz),     Vector3(cx - half, h, cz),
				Vector3(cx + half, h, cz),     Vector3(cx + half, 0, cz),
				Vector3(0, 0, 1), uv[0], uv[1], uv[2], uv[3])
			_add_quad(surface_tools[sid],
				Vector3(cx + half, 0, cz),     Vector3(cx + half, h, cz),
				Vector3(cx - half, h, cz),     Vector3(cx - half, 0, cz),
				Vector3(0, 0, -1), uv[0], uv[1], uv[2], uv[3])
			# Quad 2: along X axis (left + right)
			_add_quad(surface_tools[sid],
				Vector3(cx, 0, cz - half),     Vector3(cx, h, cz - half),
				Vector3(cx, h, cz + half),     Vector3(cx, 0, cz + half),
				Vector3(1, 0, 0), uv[0], uv[1], uv[2], uv[3])
			_add_quad(surface_tools[sid],
				Vector3(cx, 0, cz + half),     Vector3(cx, h, cz + half),
				Vector3(cx, h, cz - half),     Vector3(cx, 0, cz - half),
				Vector3(-1, 0, 0), uv[0], uv[1], uv[2], uv[3])

# --- Billboard system ---

func _update_billboards(player_pos: Vector2) -> void:
	if not _scene_tree:
		_scene_tree = _world.get_tree()
		if not _scene_tree:
			return

	var max_dist_sq = (30.0 * tile_size) * (30.0 * tile_size)
	var seen_ids: Dictionary = {}

	var entities: Array[Node] = []
	entities.append_array(_scene_tree.get_nodes_in_group("enemy"))
	entities.append_array(_scene_tree.get_nodes_in_group("companion"))
	entities.append_array(_scene_tree.get_nodes_in_group("loot_bag"))
	entities.append_array(_scene_tree.get_nodes_in_group("npc"))

	for bullet_container in _scene_tree.get_nodes_in_group("bullets"):
		for bullet in bullet_container.get_children():
			if is_instance_valid(bullet) and bullet is Node2D:
				entities.append(bullet)

	for entity in entities:
		if not is_instance_valid(entity) or not entity is Node2D:
			continue
		var e2d = entity as Node2D
		if not e2d.visible:
			continue
		var dist_sq = player_pos.distance_squared_to(e2d.global_position)
		if dist_sq > max_dist_sq:
			continue

		var eid = entity.get_instance_id()
		seen_ids[eid] = true

		var billboard: Sprite3D
		if _billboards.has(eid):
			billboard = _billboards[eid]
			if not is_instance_valid(billboard):
				_billboards.erase(eid)
				billboard = null
		if not billboard:
			billboard = _create_billboard(entity)
			if not billboard:
				continue
			_billboards[eid] = billboard

		var x3 = e2d.global_position.x / tile_size
		var z3 = e2d.global_position.y / tile_size
		var h = 0.4 if _has_ceiling else 0.6
		billboard.global_position = Vector3(x3, h, z3)
		_sync_billboard_texture(billboard, entity)

	var stale: Array = []
	for eid in _billboards:
		if not seen_ids.has(eid):
			stale.append(eid)
	for eid in stale:
		var bb = _billboards[eid]
		if is_instance_valid(bb):
			bb.queue_free()
		_billboards.erase(eid)

func _create_billboard(entity: Node) -> Sprite3D:
	var sprite = _find_sprite(entity)
	if not sprite:
		return null

	var tex = _extract_texture(sprite)
	if not tex:
		return null

	var bb = Sprite3D.new()
	bb.texture = tex
	bb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bb.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	bb.transparent = true
	bb.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	bb.no_depth_test = false

	# pixel_size accounts for sprite's 2D scale
	bb.pixel_size = abs(sprite.scale.x) / tile_size

	# Subtle tint by type
	if entity.is_in_group("enemy"):
		bb.modulate = Color(1.0, 0.85, 0.85)
	elif entity.is_in_group("companion"):
		bb.modulate = Color(0.8, 1.0, 0.8)

	_billboard_container.add_child(bb)
	return bb

func _find_sprite(entity: Node) -> Sprite2D:
	var sprite = entity.get_node_or_null("Sprite2D") as Sprite2D
	if sprite and sprite.texture:
		return sprite
	for child in entity.get_children():
		if child is Sprite2D and child.texture:
			return child
	return null

func _extract_texture(sprite: Sprite2D) -> Texture2D:
	if sprite.texture is AtlasTexture:
		return sprite.texture
	if sprite.hframes > 1 or sprite.vframes > 1:
		var atlas = AtlasTexture.new()
		atlas.atlas = sprite.texture
		var fw = sprite.texture.get_width() / sprite.hframes
		var fh = sprite.texture.get_height() / sprite.vframes
		var col = sprite.frame % sprite.hframes
		var row = sprite.frame / sprite.hframes
		atlas.region = Rect2(col * fw, row * fh, fw, fh)
		return atlas
	return sprite.texture

func _sync_billboard_texture(billboard: Sprite3D, entity: Node) -> void:
	var sprite = _find_sprite(entity)
	if not sprite:
		return
	if sprite.texture is AtlasTexture:
		if billboard.texture != sprite.texture:
			billboard.texture = sprite.texture
	elif sprite.hframes > 1 or sprite.vframes > 1:
		var fw = sprite.texture.get_width() / sprite.hframes
		var fh = sprite.texture.get_height() / sprite.vframes
		var col = sprite.frame % sprite.hframes
		var row = sprite.frame / sprite.hframes
		var new_region = Rect2(col * fw, row * fh, fw, fh)
		if billboard.texture is AtlasTexture:
			(billboard.texture as AtlasTexture).region = new_region
		else:
			var atlas = AtlasTexture.new()
			atlas.atlas = sprite.texture
			atlas.region = new_region
			billboard.texture = atlas
	billboard.flip_h = sprite.flip_h

# --- Geometry helper ---

func _add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3, uv_x: float, uv_y: float, uv_w: float, uv_h: float) -> void:
	st.set_normal(normal)
	st.set_uv(Vector2(uv_x, uv_y + uv_h))
	st.add_vertex(v0)
	st.set_normal(normal)
	st.set_uv(Vector2(uv_x, uv_y))
	st.add_vertex(v1)
	st.set_normal(normal)
	st.set_uv(Vector2(uv_x + uv_w, uv_y))
	st.add_vertex(v2)

	st.set_normal(normal)
	st.set_uv(Vector2(uv_x, uv_y + uv_h))
	st.add_vertex(v0)
	st.set_normal(normal)
	st.set_uv(Vector2(uv_x + uv_w, uv_y))
	st.add_vertex(v2)
	st.set_normal(normal)
	st.set_uv(Vector2(uv_x + uv_w, uv_y + uv_h))
	st.add_vertex(v3)
