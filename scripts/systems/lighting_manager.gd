extends Node

const PlayerQuery = preload("res://scripts/systems/player_query.gd")

## Manages ambient lighting (CanvasModulate), point lights (torches, player lantern),
## and post-processing (WorldEnvironment glow/bloom).
## Autoload singleton — access via LightingManager.

enum LightKind {
	TORCH,
	EMBER,
	CRYSTAL,
	LAVA,
	HOLY,
	POISON,
}

enum LightingQuality {
	FULL,
	CHEAP,
	MINIMAL,
}

var enabled: bool = true
var outlines_enabled: bool = false
var lighting_quality: int = LightingQuality.CHEAP
var brightness_scalar: float = 1.0
var darkness_scalar: float = 1.0

var _canvas_mod: CanvasModulate = null
var _light_texture: Texture2D = null
var _soft_light_texture: Texture2D = null  # extra-soft falloff for player lantern
var _vignette_rect: ColorRect = null
var _outline_material: ShaderMaterial = null
var _active_torches: Array[PointLight2D] = []
var _player_lantern: PointLight2D = null
var _current_mood: AreaMoodProfile = null
var _tween: Tween = null
var _flicker_time: float = 0.0

var _world_env: WorldEnvironment = null
var _environment: Environment = null

const PLAYER_LIGHT_RADIUS_SCALE := 0.85
const MAX_FLICKER_LIGHTS := 64

var _builtin_mood_presets: Dictionary = {
	"default": preload("res://resources/moods/default.tres"),
	"dungeon_dark": preload("res://resources/moods/dungeon_dark.tres"),
	"dungeon_infernal": preload("res://resources/moods/dungeon_infernal.tres"),
	"town_cool": preload("res://resources/moods/town_cool.tres"),
	"town_golden": preload("res://resources/moods/town_golden.tres"),
	"wilderness_cold": preload("res://resources/moods/wilderness_cold.tres"),
	"wilderness_desert": preload("res://resources/moods/wilderness_desert.tres"),
	"wilderness_green": preload("res://resources/moods/wilderness_green.tres"),
}

# Preloaded default mood profiles (auto-mapped by tileset/theme)
var _mood_cache: Dictionary = {}  # id -> AreaMoodProfile

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_canvas_modulate()
	_create_light_textures()
	_create_vignette_overlay()
	_create_world_environment()
	_load_mood_presets()
	if outlines_enabled:
		_create_outline_material()
	if outlines_enabled and get_tree() and not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)

func _create_canvas_modulate() -> void:
	_canvas_mod = CanvasModulate.new()
	_canvas_mod.name = "AmbientLight"
	_canvas_mod.color = Color.WHITE
	add_child(_canvas_mod)

func _create_light_textures() -> void:
	# Torch light: lower-res radial gradient so the falloff reads chunkier on pixel art.
	var grad = Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.12, Color(1, 1, 1, 0.92))
	grad.add_point(0.28, Color(1, 1, 1, 0.66))
	grad.add_point(0.48, Color(1, 1, 1, 0.32))
	grad.add_point(0.68, Color(1, 1, 1, 0.12))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	_light_texture = tex

	# Player lantern: bright readable core, slower mid-falloff so dungeons stay playable.
	var grad2 = Gradient.new()
	grad2.set_color(0, Color(1, 1, 1, 0.95))
	grad2.set_color(1, Color(1, 1, 1, 0))
	grad2.add_point(0.12, Color(1, 1, 1, 0.85))
	grad2.add_point(0.30, Color(1, 1, 1, 0.62))
	grad2.add_point(0.50, Color(1, 1, 1, 0.34))
	grad2.add_point(0.70, Color(1, 1, 1, 0.14))
	grad2.add_point(0.86, Color(1, 1, 1, 0.03))
	var tex2 = GradientTexture2D.new()
	tex2.gradient = grad2
	tex2.width = 128
	tex2.height = 128
	tex2.fill = GradientTexture2D.FILL_RADIAL
	tex2.fill_from = Vector2(0.5, 0.5)
	tex2.fill_to = Vector2(0.5, 0.0)
	_soft_light_texture = tex2

func _create_vignette_overlay() -> void:
	_vignette_rect = ColorRect.new()
	_vignette_rect.name = "LightingVignette"
	_vignette_rect.anchor_right = 1.0
	_vignette_rect.anchor_bottom = 1.0
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_rect.color = Color.WHITE
	_vignette_rect.visible = true

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 0.72);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.0;
uniform float vignette_softness : hint_range(0.3, 1.2) = 0.72;

void fragment() {
	vec2 centered = UV * 2.0 - vec2(1.0);
	float dist = length(centered);
	float edge = smoothstep(vignette_softness, 1.35, dist);
	float alpha = edge * vignette_strength * vignette_color.a;
	COLOR = vec4(vignette_color.rgb, alpha);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_vignette_rect.material = mat
	add_child(_vignette_rect)

func _create_outline_material() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 0.92);
uniform float outline_size = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float alpha = tex.a;
	float edge = 0.0;
	vec2 px = TEXTURE_PIXEL_SIZE * outline_size;
	edge = max(edge, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(px.x, px.y)).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(-px.x, px.y)).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(-px.x, -px.y)).a);
	float outline = clamp(edge - alpha, 0.0, 1.0);
	vec3 rgb = mix(outline_color.rgb, tex.rgb, alpha);
	float out_alpha = max(alpha, outline * outline_color.a);
	COLOR = vec4(rgb, out_alpha);
}
"""
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = shader

func _create_world_environment() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_CANVAS
	# Glow/bloom — disabled by default, enabled per mood
	_environment.glow_enabled = false
	_environment.glow_intensity = 0.3
	_environment.glow_bloom = 0.1
	_environment.glow_strength = 0.8
	_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	_environment.glow_hdr_threshold = 0.8

	_world_env = WorldEnvironment.new()
	_world_env.name = "WorldEnv"
	_world_env.environment = _environment
	add_child(_world_env)

func _load_mood_presets() -> void:
	_mood_cache.clear()
	for mood_id in _builtin_mood_presets.keys():
		var preset = _builtin_mood_presets[mood_id]
		if preset is AreaMoodProfile:
			_mood_cache[mood_id] = preset
	var mood_dir = "res://resources/moods/"
	var dir = DirAccess.open(mood_dir)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res = load(mood_dir + file_name) as AreaMoodProfile
			if res:
				var id = file_name.get_basename()
				_mood_cache[id] = res
		file_name = dir.get_next()

func _build_fallback_dungeon_mood(mood_id: String, biome: DungeonBiome) -> AreaMoodProfile:
	var darkness_level := 0.55
	if biome != null:
		darkness_level = clampf(maxf(biome.darkness_level, 0.25), 0.0, 1.0)
	var profile := AreaMoodProfile.new()
	profile.is_dark = true
	if mood_id == "dungeon_infernal":
		profile.darkness_color = Color(
			lerpf(0.17, 0.05, darkness_level),
			lerpf(0.08, 0.03, darkness_level),
			lerpf(0.08, 0.03, darkness_level)
		)
		profile.torch_color = Color(1.0, 0.45, 0.18)
		profile.player_light_color = Color(1.0, 0.72, 0.42)
		profile.vignette_strength = 0.34
		profile.vignette_color = Color(0.08, 0.02, 0.01, 0.76)
		profile.glow_enabled = true
		profile.glow_intensity = 0.28
		profile.glow_bloom = 0.14
	else:
		profile.darkness_color = Color(
			lerpf(0.16, 0.05, darkness_level),
			lerpf(0.16, 0.05, darkness_level),
			lerpf(0.18, 0.06, darkness_level)
		)
		profile.torch_color = Color(1.0, 0.82, 0.45)
		profile.player_light_color = Color(0.9, 0.85, 0.7)
		profile.vignette_strength = 0.42
		profile.vignette_color = Color(0.0, 0.0, 0.0, 0.78)
		profile.glow_enabled = true
		profile.glow_intensity = 0.24
		profile.glow_bloom = 0.12
	profile.torch_intensity = lerpf(0.72, 0.95, darkness_level)
	profile.torch_radius = lerpf(88.0, 118.0, darkness_level)
	profile.torch_flicker = true
	profile.torch_shadows = false
	profile.player_light_radius = lerpf(124.0, 164.0, darkness_level)
	profile.player_light_energy = lerpf(0.88, 1.18, darkness_level)
	profile.player_light_shadows = false
	return profile

func _on_tree_node_added(node: Node) -> void:
	if not outlines_enabled:
		return
	_apply_outline_to_subtree(node)

func apply_outline_to_subtree(root: Node) -> void:
	if not outlines_enabled:
		return
	_apply_outline_to_subtree(root)

func _apply_outline_to_subtree(root: Node) -> void:
	if root == null:
		return
	if root is Control:
		return
	if root is Sprite2D:
		_apply_outline_to_canvas_item(root as Sprite2D)
	for child in root.get_children():
		_apply_outline_to_subtree(child)

func _apply_outline_to_canvas_item(item: CanvasItem) -> void:
	if item == null or _outline_material == null:
		return
	if item.has_meta("no_outline") and bool(item.get_meta("no_outline")):
		return
	if item.material != null:
		return
	item.material = _outline_material

# ─── Public API ───

func apply_mood(profile: AreaMoodProfile, instant: bool = false) -> void:
	if not enabled or profile == null:
		return
	_current_mood = profile
	var target_color = profile.darkness_color if profile.is_dark else profile.ambient_color
	target_color = _scale_mood_color(target_color, profile.is_dark)
	if instant or _canvas_mod.color == Color.WHITE:
		_canvas_mod.color = target_color
	else:
		if _tween:
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(_canvas_mod, "color", target_color, 0.5)
	# Update glow
	_environment.glow_enabled = profile.glow_enabled
	if profile.glow_enabled:
		_environment.glow_intensity = profile.glow_intensity
		_environment.glow_bloom = profile.glow_bloom
	if _vignette_rect and _vignette_rect.material is ShaderMaterial:
		var sm := _vignette_rect.material as ShaderMaterial
		var v_strength := profile.vignette_strength
		if lighting_quality == LightingQuality.MINIMAL:
			v_strength = 0.0
		elif lighting_quality == LightingQuality.CHEAP:
			v_strength *= 0.55
		sm.set_shader_parameter("vignette_strength", v_strength)
		sm.set_shader_parameter("vignette_softness", profile.vignette_softness)
		sm.set_shader_parameter("vignette_color", profile.vignette_color)

func apply_zone_mood(zone: LoyZoneData) -> void:
	## Pick mood for an overworld zone: explicit profile > tileset auto-map
	if zone == null:
		return
	if zone.mood_profile != null:
		apply_mood(zone.mood_profile)
		return
	# Auto-map by tileset
	var mood_id: String
	match zone.tileset:
		112:
			mood_id = "town_golden"
		144:
			mood_id = "wilderness_cold"
		192:
			mood_id = "wilderness_green"
		224:
			mood_id = "wilderness_desert"
		240:
			mood_id = "wilderness_cold"  # mountain = cold
		_:
			mood_id = "default"
	if mood_id in _mood_cache:
		apply_mood(_mood_cache[mood_id])
	else:
		_canvas_mod.color = Color(0.9, 0.9, 0.9)
		_environment.glow_enabled = false

func apply_dungeon_mood(biome: DungeonBiome) -> void:
	## Pick mood for a dungeon biome: explicit profile > theme auto-map
	## darkness_level on biome (0=bright, 1=pitch black) scales the mood.
	if biome == null:
		return
	if biome.mood_profile != null:
		apply_mood(biome.mood_profile)
		return
	# Auto-map by theme
	var mood_id: String
	match biome.theme:
		"red", "crimson":
			mood_id = "dungeon_infernal"
		"black":
			mood_id = "dungeon_dark"
		_:
			mood_id = "dungeon_dark"
	if mood_id in _mood_cache:
		var base_mood: AreaMoodProfile = _mood_cache[mood_id]
		# Scale darkness by biome darkness_level (default 0.25 = mild)
		var dl: float = clampf(biome.darkness_level, 0.0, 1.0)
		if dl > 0.01:
			var scaled := base_mood.duplicate() as AreaMoodProfile
			# Darken the base color: lerp between bright ambient and mood darkness
			var bright := Color(0.18, 0.18, 0.2)  # max brightness floor
			scaled.darkness_color = bright.lerp(base_mood.darkness_color, clampf(dl * 2.0, 0.0, 1.0))
			# Scale torch/lantern with inverse darkness — brighter when darker
			scaled.torch_intensity = lerpf(base_mood.torch_intensity, base_mood.torch_intensity * 1.3, dl)
			scaled.torch_radius = lerpf(base_mood.torch_radius, base_mood.torch_radius * 1.3, dl)
			scaled.player_light_radius = lerpf(base_mood.player_light_radius, base_mood.player_light_radius * 1.3, dl)
			scaled.player_light_energy = lerpf(base_mood.player_light_energy, base_mood.player_light_energy * 1.3, dl)
			scaled.vignette_strength = lerpf(base_mood.vignette_strength, maxf(base_mood.vignette_strength, 0.45), dl)
			apply_mood(scaled, true)
		else:
			# darkness_level=0 → no darkness at all, just ambient light
			var bright_mood := base_mood.duplicate() as AreaMoodProfile
			bright_mood.is_dark = false
			bright_mood.darkness_color = Color(0.22, 0.22, 0.24)
			bright_mood.vignette_strength = 0.0
			apply_mood(bright_mood, true)
	else:
		apply_mood(_build_fallback_dungeon_mood(mood_id, biome), true)

func apply_mine_mood(mine: MineDefinition) -> void:
	## Mines need a much stronger visual identity than normal dungeon themes.
	if mine == null:
		return
	var profile := AreaMoodProfile.new()
	profile.is_dark = true
	var darkness := clampf(mine.darkness_level, 0.15, 0.85)
	match mine.biome_theme:
		"blue":
			profile.darkness_color = Color(
				lerpf(0.12, 0.03, darkness),
				lerpf(0.16, 0.05, darkness),
				lerpf(0.22, 0.10, darkness)
			)
			profile.torch_color = Color(0.55, 0.72, 1.0)
			profile.player_light_color = Color(0.72, 0.84, 1.0)
			profile.glow_enabled = true
			profile.glow_intensity = 0.18
			profile.glow_bloom = 0.06
			profile.vignette_strength = 0.42
			profile.vignette_color = Color(0.02, 0.04, 0.08, 0.78)
		"red", "crimson":
			profile.darkness_color = Color(
				lerpf(0.14, 0.04, darkness),
				lerpf(0.08, 0.02, darkness),
				lerpf(0.08, 0.02, darkness)
			)
			profile.torch_color = Color(1.0, 0.55, 0.28)
			profile.player_light_color = Color(1.0, 0.76, 0.55)
			profile.vignette_strength = 0.34
			profile.vignette_color = Color(0.08, 0.02, 0.01, 0.76)
		_:
			profile.darkness_color = Color(
				lerpf(0.13, 0.04, darkness),
				lerpf(0.13, 0.04, darkness),
				lerpf(0.15, 0.05, darkness)
			)
			profile.torch_color = Color(1.0, 0.78, 0.46)
			profile.player_light_color = Color(0.95, 0.88, 0.7)
			profile.vignette_strength = 0.3
			profile.vignette_color = Color(0.02, 0.02, 0.02, 0.74)
	profile.torch_intensity = lerpf(0.72, 0.92, darkness)
	profile.torch_radius = lerpf(88.0, 112.0, darkness)
	profile.torch_flicker = true
	profile.torch_shadows = false
	profile.player_light_radius = lerpf(132.0, 168.0, darkness)
	profile.player_light_energy = lerpf(0.95, 1.20, darkness)
	profile.player_light_shadows = false
	apply_mood(profile, true)

func get_current_mood() -> AreaMoodProfile:
	return _current_mood

func requires_shadow_occluders() -> bool:
	if not enabled:
		return false
	if lighting_quality != LightingQuality.FULL:
		return false
	if _player_lantern and is_instance_valid(_player_lantern) and _player_lantern.shadow_enabled:
		return true
	for torch in _active_torches:
		if is_instance_valid(torch) and torch.shadow_enabled:
			return true
	return false

func set_lighting_quality(quality: int) -> void:
	lighting_quality = clampi(quality, LightingQuality.FULL, LightingQuality.MINIMAL)
	if _current_mood != null:
		apply_mood(_current_mood, true)

func set_brightness_controls(brightness: float = 1.0, darkness: float = 1.0) -> void:
	brightness_scalar = clampf(brightness, 0.7, 1.35)
	darkness_scalar = clampf(darkness, 0.5, 1.6)
	if _current_mood != null:
		apply_mood(_current_mood, true)

func apply_scene_lighting_policy(quality: int, brightness: float = 1.0, darkness: float = 1.0) -> void:
	set_lighting_quality(quality)
	set_brightness_controls(brightness, darkness)

func get_darkness_gameplay_scalar() -> float:
	if _current_mood == null:
		return 0.0
	var color := _canvas_mod.color
	var luminance := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	return clampf(1.0 - luminance, 0.0, 1.0)

func get_visibility_gameplay_scalar() -> float:
	return 1.0 - get_darkness_gameplay_scalar()

func get_lighting_cost_hint() -> String:
	match lighting_quality:
		LightingQuality.FULL:
			return "high"
		LightingQuality.CHEAP:
			return "medium"
		LightingQuality.MINIMAL:
			return "low"
		_:
			return "medium"

func _scale_mood_color(base: Color, is_dark: bool) -> Color:
	if is_dark:
		var lifted := Color(
			pow(base.r, 1.0 / darkness_scalar),
			pow(base.g, 1.0 / darkness_scalar),
			pow(base.b, 1.0 / darkness_scalar),
			base.a
		)
		return Color(
			clampf(lifted.r, 0.0, 1.0),
			clampf(lifted.g, 0.0, 1.0),
			clampf(lifted.b, 0.0, 1.0),
			base.a
		)
	return Color(
		clampf(base.r * brightness_scalar, 0.0, 1.0),
		clampf(base.g * brightness_scalar, 0.0, 1.0),
		clampf(base.b * brightness_scalar, 0.0, 1.0),
		base.a
	)

func get_shadow_alpha_mult() -> float:
	## How strong fake shadows / cliff shadows should read in the current mood.
	## Bright moods → 0.6 (subtle). Dark dungeon moods → 1.4 (heavier).
	if _current_mood == null:
		return 1.0
	if not _current_mood.is_dark:
		return 0.6
	# vignette_strength is a decent proxy for "how moody is this space"
	return clampf(0.9 + _current_mood.vignette_strength * 1.0, 0.7, 1.6)

func spawn_fake_shadow(parent: Node, world_pos: Vector2, size: Vector2, alpha_mult: float = 1.0) -> Sprite2D:
	## Soft blob shadow drawn behind props/enemies/raised tiles. Cheap, no shaders.
	var col := Color(0.0, 0.0, 0.0, 0.35)
	if _current_mood:
		col = _current_mood.fake_shadow_color
	col.a = clampf(col.a * alpha_mult * get_shadow_alpha_mult(), 0.0, 0.9)
	var img := Image.create(int(maxf(size.x, 1.0)), int(maxf(size.y, 1.0)), false, Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var cx := float(w) * 0.5
	var cy := float(h) * 0.5
	var rx := maxf(cx, 1.0)
	var ry := maxf(cy, 1.0)
	for y in range(h):
		for x in range(w):
			var dx = (float(x) + 0.5 - cx) / rx
			var dy = (float(y) + 0.5 - cy) / ry
			var d = sqrt(dx * dx + dy * dy)
			if d > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var fade = 1.0 - smoothstep(0.5, 1.0, d)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * fade))
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	spr.centered = true
	spr.position = world_pos
	spr.z_index = -1
	parent.add_child(spr)
	return spr

func spawn_prop_light(pos: Vector2, parent: Node, kind: int = LightKind.TORCH) -> PointLight2D:
	## Typed prop light. Each kind has its own color/energy/radius signature.
	if not enabled or _light_texture == null:
		return null
	var light := PointLight2D.new()
	light.texture = _light_texture
	light.position = pos
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.shadow_enabled = false
	match kind:
		LightKind.EMBER:
			light.color = Color(1.0, 0.28, 0.12)
			light.energy = 0.45
			light.texture_scale = 48.0 / 128.0
		LightKind.CRYSTAL:
			light.color = Color(0.42, 0.75, 1.0)
			light.energy = 0.55
			light.texture_scale = 64.0 / 128.0
		LightKind.LAVA:
			light.color = Color(1.0, 0.22, 0.05)
			light.energy = 0.80
			light.texture_scale = 96.0 / 128.0
		LightKind.HOLY:
			light.color = Color(1.0, 0.95, 0.62)
			light.energy = 0.75
			light.texture_scale = 80.0 / 128.0
		LightKind.POISON:
			light.color = Color(0.45, 1.0, 0.38)
			light.energy = 0.45
			light.texture_scale = 56.0 / 128.0
		_:
			# Fall back to mood-driven torch
			light.color = _current_mood.torch_color if _current_mood else Color(1.0, 0.66, 0.34)
			light.energy = _current_mood.torch_intensity if _current_mood else 0.65
			light.texture_scale = ((_current_mood.torch_radius if _current_mood else 80.0)) / 128.0
	# Lights sitting on raised terrain reach further (sit higher = see further)
	var hs = _find_height_system()
	if hs:
		var ts = int(hs.tile_size) if hs.tile_size > 0 else 8
		var tile := Vector2i(int(floor(pos.x / ts)), int(floor(pos.y / ts)))
		var lvl: int = int(hs.get_height(tile))
		if lvl > 0:
			light.texture_scale *= 1.0 + 0.15 * float(lvl)
			light.energy *= 1.0 + 0.06 * float(lvl)
	light.set_meta("base_energy", light.energy)
	parent.add_child(light)
	_active_torches.append(light)
	return light

func _find_height_system() -> Node:
	var dm = get_tree().get_first_node_in_group("dungeon_manager") if get_tree() else null
	if dm == null:
		return null
	if dm.get("_height_system") == null:
		return null
	var hs = dm._height_system
	if hs and is_instance_valid(hs):
		return hs
	return null

func spawn_torch_light(pos: Vector2, parent: Node) -> PointLight2D:
	## Create a PointLight2D at the given position, parented to parent node.
	if not enabled or _light_texture == null:
		return null
	var mood = _current_mood
	var light = PointLight2D.new()
	light.texture = _light_texture
	light.position = pos
	light.color = mood.torch_color if mood else Color(1.0, 0.85, 0.5)
	light.energy = mood.torch_intensity if mood else 0.7
	light.set_meta("base_energy", light.energy)
	light.texture_scale = (mood.torch_radius if mood else 80.0) / 128.0
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.shadow_enabled = mood.torch_shadows if mood else false
	light.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	# Lights placed on raised terrain reach further
	var hs2 = _find_height_system()
	if hs2:
		var ts2 = int(hs2.tile_size) if hs2.tile_size > 0 else 8
		var tile2 := Vector2i(int(floor(pos.x / ts2)), int(floor(pos.y / ts2)))
		var lvl2: int = int(hs2.get_height(tile2))
		if lvl2 > 0:
			light.texture_scale *= 1.0 + 0.15 * float(lvl2)
			light.energy *= 1.0 + 0.06 * float(lvl2)
			light.set_meta("base_energy", light.energy)
	parent.add_child(light)
	_active_torches.append(light)
	return light

func setup_player_lantern(player: Node) -> void:
	## Attach or update the player lantern PointLight2D.
	if _player_lantern and is_instance_valid(_player_lantern):
		_player_lantern.queue_free()
		_player_lantern = null
	if not enabled or _soft_light_texture == null:
		return
	var mood = _current_mood
	if mood == null or not mood.is_dark:
		return
	var light = PointLight2D.new()
	light.texture = _soft_light_texture  # softer falloff for less contrast
	light.position = Vector2.ZERO
	light.color = mood.player_light_color
	light.energy = mood.player_light_energy
	light.texture_scale = (mood.player_light_radius * PLAYER_LIGHT_RADIUS_SCALE) / 128.0
	light.blend_mode = Light2D.BLEND_MODE_ADD
	# Exported desktop builds have been failing specifically on shadowed player lanterns
	# in normal dungeons, while mines remain readable because they already disable this path.
	# Keep editor behavior unchanged, but force the player lantern shadow path off in exports.
	light.shadow_enabled = mood.player_light_shadows if OS.has_feature("editor") else false
	light.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	player.add_child(light)
	_player_lantern = light

func clear_torches() -> void:
	## Remove all active torch lights (call when leaving dungeon/zone).
	for torch in _active_torches:
		if is_instance_valid(torch):
			torch.queue_free()
	_active_torches.clear()

func clear_player_lantern() -> void:
	if _player_lantern and is_instance_valid(_player_lantern):
		_player_lantern.queue_free()
		_player_lantern = null

func get_debug_snapshot(player_override: Node = null) -> Dictionary:
	var player := player_override
	if player == null and get_tree():
		player = PlayerQuery.get_primary_player(get_tree())
	var mood_id := "<none>"
	if _current_mood != null:
		for key in _mood_cache.keys():
			if _mood_cache[key] == _current_mood:
				mood_id = str(key)
				break
	var lantern_parent := "<none>"
	var lantern_exists := _player_lantern != null and is_instance_valid(_player_lantern)
	if lantern_exists and _player_lantern.get_parent():
		lantern_parent = str(_player_lantern.get_parent().get_path())
	return {
		"enabled": enabled,
		"quality": lighting_quality,
		"scene_root": str(get_tree().current_scene.get_path()) if get_tree() and get_tree().current_scene else "<none>",
		"canvas_color": _canvas_mod.color if _canvas_mod else Color.WHITE,
		"mood_id": mood_id,
		"mood_dark": _current_mood != null and _current_mood.is_dark,
		"mood_darkness": _current_mood.darkness_color if _current_mood != null else Color.WHITE,
		"mood_player_radius": _current_mood.player_light_radius if _current_mood != null else 0.0,
		"mood_player_energy": _current_mood.player_light_energy if _current_mood != null else 0.0,
		"mood_player_shadows": _current_mood.player_light_shadows if _current_mood != null else false,
		"lantern_exists": lantern_exists,
		"lantern_energy": _player_lantern.energy if lantern_exists else 0.0,
		"lantern_scale": _player_lantern.texture_scale if lantern_exists else 0.0,
		"lantern_shadow_enabled": _player_lantern.shadow_enabled if lantern_exists else false,
		"lantern_parent": lantern_parent,
		"torch_count": _active_torches.size(),
		"mood_cache_size": _mood_cache.size(),
		"cache_has_dungeon_dark": _mood_cache.has("dungeon_dark"),
		"cache_has_dungeon_infernal": _mood_cache.has("dungeon_infernal"),
		"player_path": str(player.get_path()) if player != null else "<none>",
	}

func reset() -> void:
	## Full reset — call when switching scenes (overworld ↔ dungeon).
	clear_torches()
	clear_player_lantern()
	if _tween:
		_tween.kill()
		_tween = null
	_current_mood = null
	brightness_scalar = 1.0
	darkness_scalar = 1.0
	_canvas_mod.color = Color.WHITE
	_environment.glow_enabled = false
	if _vignette_rect and _vignette_rect.material is ShaderMaterial:
		var sm := _vignette_rect.material as ShaderMaterial
		sm.set_shader_parameter("vignette_strength", 0.0)
		sm.set_shader_parameter("vignette_softness", 0.72)
		sm.set_shader_parameter("vignette_color", Color(0.0, 0.0, 0.0, 0.72))

# ─── Flicker ───

var _flicker_resort_timer: float = 0.0
var _flicker_pool: Array[PointLight2D] = []

func _process(delta: float) -> void:
	if not enabled or _active_torches.is_empty():
		return
	_flicker_time += delta
	# Drop dead torches once
	for i in range(_active_torches.size() - 1, -1, -1):
		if not is_instance_valid(_active_torches[i]):
			_active_torches.remove_at(i)
	if _current_mood == null or not _current_mood.torch_flicker:
		return
	# Re-pick the flicker pool every ~1s based on distance to player.
	# Static far torches stay constant; cheap and visually indistinguishable.
	_flicker_resort_timer -= delta
	if _flicker_resort_timer <= 0.0 or _flicker_pool.is_empty():
		_flicker_resort_timer = 1.0
		_rebuild_flicker_pool()
	for i in range(_flicker_pool.size()):
		var torch = _flicker_pool[i]
		if not is_instance_valid(torch):
			continue
		var base_energy: float = float(torch.get_meta("base_energy", _current_mood.torch_intensity))
		var phase = float(i) * 1.7
		var flicker = sin(_flicker_time * 3.5 + phase) * 0.1 + sin(_flicker_time * 6.1 + phase * 2.3) * 0.05
		torch.energy = clampf(base_energy + flicker, base_energy * 0.78, base_energy * 1.22)

func _rebuild_flicker_pool() -> void:
	_flicker_pool.clear()
	if _active_torches.size() <= MAX_FLICKER_LIGHTS:
		for t in _active_torches:
			if is_instance_valid(t):
				_flicker_pool.append(t)
		return
	var p = PlayerQuery.get_primary_player(get_tree()) if get_tree() else null
	if p == null:
		# No player — just take the first N
		for i in range(mini(MAX_FLICKER_LIGHTS, _active_torches.size())):
			_flicker_pool.append(_active_torches[i])
		return
	var ppos: Vector2 = p.global_position
	var entries: Array = []
	for t in _active_torches:
		if not is_instance_valid(t):
			continue
		entries.append({"t": t, "d": t.global_position.distance_squared_to(ppos)})
	entries.sort_custom(func(a, b): return a["d"] < b["d"])
	for i in range(mini(MAX_FLICKER_LIGHTS, entries.size())):
		_flicker_pool.append(entries[i]["t"])
