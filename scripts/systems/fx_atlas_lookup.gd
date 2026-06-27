class_name FXAtlasLookup
extends RefCounted

## Resolves named FX tiles from the Oryx 16-bit tilesets into AtlasTextures
## or one-shot Sprite2D bursts that callers can drop into the scene.
##
## The tilesets store an FX name in custom_data_layer "name" per tile. We scan
## both atlases on first use and cache the (name → AtlasTexture) map, so
## subsequent lookups are O(1). Use FXAtlasLookup.spawn() to drop a sprite at
## a position; use get_texture() if you want to assign to your own Sprite2D.

const LARGE_TILESET_PATH := "res://assets/tilesets/oryx_16bit_fx_large_tileset.tres"
const SMALL_TILESET_PATH := "res://assets/tilesets/oryx_16bit_fx_small_tileset.tres"

static var _texture_cache: Dictionary = {}  # name → AtlasTexture
static var _scanned: bool = false

static func _ensure_scanned() -> void:
	if _scanned:
		return
	_scanned = true
	for path in [LARGE_TILESET_PATH, SMALL_TILESET_PATH]:
		var ts := load(path) as TileSet
		if ts == null:
			continue
		# Find the "name" custom data layer index.
		var name_layer := -1
		for i in ts.get_custom_data_layers_count():
			if ts.get_custom_data_layer_name(i) == "name":
				name_layer = i
				break
		if name_layer < 0:
			continue
		for source_id in ts.get_source_count():
			var src := ts.get_source(ts.get_source_id(source_id)) as TileSetAtlasSource
			if src == null:
				continue
			var tex: Texture2D = src.texture
			var region_size: Vector2i = src.texture_region_size
			var margins: Vector2i = src.margins
			for ti in src.get_tiles_count():
				var coords: Vector2i = src.get_tile_id(ti)
				var data := src.get_tile_data(coords, 0)
				if data == null:
					continue
				var fx_name = data.get_custom_data_by_layer_id(name_layer)
				if fx_name == null or str(fx_name) == "":
					continue
				var s := str(fx_name)
				# Skip placeholder grid names so they don't clobber real entries
				# if the user reused a grid name elsewhere by accident.
				if s.begins_with("large_") or s.begins_with("small_"):
					if s.length() > 6 and s[6].is_valid_int():
						continue
				var atex := AtlasTexture.new()
				atex.atlas = tex
				atex.region = Rect2(margins + coords * region_size, region_size)
				_texture_cache[s] = atex

static func get_texture(fx_name: String) -> AtlasTexture:
	_ensure_scanned()
	if not _texture_cache.has(fx_name):
		return null
	return _texture_cache[fx_name] as AtlasTexture

## Cycle through a list of FX tile names at world_pos as a flipbook animation.
## Each frame holds for frame_duration seconds. After the last frame the sprite
## fades out and frees itself. Use this for short bursts like fire_impact →
## fire_explosion or electric_explosion_1 → electric_explosion_2.
##
## If looping=true, the animation repeats until the timer fires after
## total_duration; useful for telegraphs (e.g. lightning ball flicker).
static func spawn_anim(scene_root: Node, fx_names: Array, world_pos: Vector2, frame_duration: float = 0.08, target_px: float = 48.0, z_index: int = 8, loop: bool = false, total_duration: float = 0.6, color: Color = Color.WHITE) -> Sprite2D:
	if scene_root == null or not scene_root.is_inside_tree() or fx_names.is_empty():
		return null
	_ensure_scanned()
	# Build the texture list. Skip unresolved names rather than aborting, so a
	# typo'd frame doesn't break the whole effect.
	var frames: Array = []
	for n in fx_names:
		var t = get_texture(str(n))
		if t != null:
			frames.append(t)
	if frames.is_empty():
		return null
	var s := Sprite2D.new()
	s.texture = frames[0]
	s.global_position = world_pos
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.z_index = z_index
	s.modulate = color
	var native: float = float((frames[0] as AtlasTexture).region.size.x)
	if native > 0.0:
		s.scale = Vector2.ONE * (target_px / native)
	scene_root.get_tree().current_scene.add_child(s)
	var tw := s.create_tween()
	if loop:
		# Telegraph mode: flicker between frames for total_duration, then free.
		# Loop count is large enough to cover the duration at frame_duration
		# pace; we hard-stop via a separate timer so the lifetime stays exact.
		tw.set_loops()
		for i in frames.size():
			var frame_tex = frames[i]
			tw.tween_callback(func(): if is_instance_valid(s): s.texture = frame_tex)
			tw.tween_interval(frame_duration)
		scene_root.get_tree().create_timer(total_duration).timeout.connect(func():
			if is_instance_valid(s):
				tw.kill()
				var fade := s.create_tween()
				fade.tween_property(s, "modulate:a", 0.0, 0.15)
				fade.tween_callback(s.queue_free)
		)
	else:
		# One-shot burst: play each frame once, fade, free.
		for i in frames.size():
			var frame_tex = frames[i]
			tw.tween_callback(func(): if is_instance_valid(s): s.texture = frame_tex)
			tw.tween_interval(frame_duration)
		tw.tween_property(s, "modulate:a", 0.0, 0.18)
		tw.tween_callback(s.queue_free)
	return s

## Drop a one-shot FX sprite at world_pos. Returns the Sprite2D so callers can
## tween it further. Default behaviour: scale to target_px, fade to 0 over
## duration, then queue_free.
static func spawn(scene_root: Node, fx_name: String, world_pos: Vector2, duration: float = 0.5, target_px: float = 48.0, z_index: int = 8, color: Color = Color.WHITE) -> Sprite2D:
	if scene_root == null or not scene_root.is_inside_tree():
		return null
	var atex := get_texture(fx_name)
	if atex == null:
		return null
	var s := Sprite2D.new()
	s.texture = atex
	s.global_position = world_pos
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.z_index = z_index
	s.modulate = color
	var native: float = float(atex.region.size.x)
	if native > 0.0:
		s.scale = Vector2.ONE * (target_px / native)
	scene_root.get_tree().current_scene.add_child(s)
	# Fade and free. tween_callback fires after the property tween completes.
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, duration)
	tw.tween_callback(s.queue_free)
	return s
