extends Node

## Autoload for visual effects — blood splatters, death pops, screen shake, ability FX.
## Toggle: VFXManager.enabled = false to disable all particle effects.
## All effects auto-cleanup after their lifetime.

var enabled: bool = true
var screen_shake_enabled: bool = true
var _warp_quad_texture: Texture2D = null
var _warp_shader: Shader = preload("res://shaders/vfx/warp_portal.gdshader")

var _camera: Camera2D = null
var _shake_intensity: float = 0.0
var _shake_decay: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if _shake_intensity > 0 and screen_shake_enabled:
		_shake_intensity = maxf(0.0, _shake_intensity - _shake_decay * delta)
		if not _camera:
			_camera = _find_camera()
		if _camera:
			_camera.offset = Vector2(
				randf_range(-_shake_intensity, _shake_intensity),
				randf_range(-_shake_intensity, _shake_intensity)
			)
			if _shake_intensity <= 0:
				_camera.offset = Vector2.ZERO

func _find_camera() -> Camera2D:
	if not is_inside_tree():
		return null
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var cam = player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			return cam
	return get_viewport().get_camera_2d()

# ── Screen Shake ──

func shake(intensity: float = 2.0, duration: float = 0.15) -> void:
	if not screen_shake_enabled:
		return
	_shake_intensity = intensity
	_shake_decay = intensity / maxf(duration, 0.01)

# ── Blood Splatter (on enemy hit) ──

func blood_splatter(pos: Vector2, hit_dir: Vector2 = Vector2.ZERO, color: Color = Color(0.7, 0.0, 0.0), parent: Node = null) -> void:
	if not enabled:
		return
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 6
	particles.lifetime = 0.3
	particles.speed_scale = 1.5
	particles.direction = hit_dir if hit_dir.length() > 0 else Vector2.UP
	particles.spread = 35.0
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 50.0
	particles.gravity = Vector2(0, 80)
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.8
	particles.color = color
	particles.global_position = pos
	_add_to_scene(particles, parent)
	_auto_free(particles, 0.6)

# ── Death Burst (enemy dies) ──

func death_burst(pos: Vector2, color: Color = Color(0.8, 0.1, 0.1), size_class: int = 0, parent: Node = null) -> void:
	if not enabled:
		return
	var amount = 10 + size_class * 6
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = 0.4
	particles.speed_scale = 1.2
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 15.0
	particles.initial_velocity_max = 40.0 + size_class * 15.0
	particles.gravity = Vector2(0, 60)
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 1.2 + size_class * 0.3
	particles.color = color
	particles.global_position = pos
	_add_to_scene(particles, parent)
	_auto_free(particles, 0.8)
	# Also flash a brief expanding ring
	_spawn_ring(pos, color.lightened(0.3), 12.0 + size_class * 8.0, 0.25, parent)

# ── Hit Spark (bullet impact) ──

func hit_spark(pos: Vector2, color: Color = Color(1.0, 0.9, 0.5), parent: Node = null) -> void:
	if not enabled:
		return
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 4
	particles.lifetime = 0.15
	particles.speed_scale = 2.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 10.0
	particles.initial_velocity_max = 30.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 0.2
	particles.scale_amount_max = 0.5
	particles.color = color
	particles.global_position = pos
	_add_to_scene(particles, parent)
	_auto_free(particles, 0.4)

# ── Crit Spark (big flashy impact) ──

func crit_spark(pos: Vector2, parent: Node = null) -> void:
	if not enabled:
		return
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 8
	particles.lifetime = 0.25
	particles.speed_scale = 1.8
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 50.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.8
	particles.color = Color(1.0, 1.0, 0.3)
	particles.global_position = pos
	_add_to_scene(particles, parent)
	_auto_free(particles, 0.5)
	# Flash ring
	_spawn_ring(pos, Color(1.0, 0.9, 0.2, 0.7), 10.0, 0.2, parent)

# ── Dash Afterimage ──

func dash_afterimage(sprite: Sprite2D, pos: Vector2, parent: Node = null, z: int = 1) -> void:
	if not enabled or not sprite:
		return
	var ghost = Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.region_enabled = sprite.region_enabled
	ghost.region_rect = sprite.region_rect
	ghost.flip_h = sprite.flip_h
	ghost.scale = sprite.scale
	ghost.modulate = Color(0.4, 0.6, 1.0, 0.5)
	ghost.global_position = pos
	# Absolute z so trail stays above ground regardless of scene structure
	ghost.z_as_relative = false
	ghost.z_index = z
	_add_to_scene(ghost, parent)
	var tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)

func dash_trail_lines(pos: Vector2, dash_dir: Vector2, sprite_scale: Vector2 = Vector2.ONE, parent: Node = null, z: int = 1) -> void:
	## Spawns 3 black trail lines behind the player during dash.
	## Uses Sprite2D nodes drawn as stretched black pixels that elongate and fade.
	if not enabled:
		return
	var trail_dir = -dash_dir.normalized()
	var perp = Vector2(-trail_dir.y, trail_dir.x)
	var spacing = 2.0 * sprite_scale.x
	var base_length = 6.0  # starting length in pixels
	var max_length = 18.0  # stretched length
	var angle = trail_dir.angle()
	for i in range(3):
		var offset = perp * (i - 1) * spacing
		var trail_pos = pos + offset + trail_dir * 4.0 * sprite_scale.x
		# Use a simple Node2D with _draw for a pixel-perfect black rectangle
		var trail = _DashTrailLine.new()
		trail.length = base_length * sprite_scale.x
		trail.global_position = trail_pos
		trail.rotation = angle
		# Absolute z so trail stays above ground regardless of scene structure
		trail.z_as_relative = false
		trail.z_index = z
		_add_to_scene(trail, parent)
		var tween = trail.create_tween()
		tween.set_parallel(true)
		tween.tween_property(trail, "length", max_length * sprite_scale.x, 0.2)
		tween.tween_property(trail, "modulate:a", 0.0, 0.3)
		tween.set_parallel(false)
		tween.tween_callback(trail.queue_free)

# ── Shield Bash Shockwave ──

func shockwave(pos: Vector2, radius: float = 24.0, color: Color = Color(1.0, 0.9, 0.5, 0.6), parent: Node = null) -> void:
	if not enabled:
		return
	_spawn_ring(pos, color, radius, 0.3, parent)
	# Also burst particles outward
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 12
	particles.lifetime = 0.3
	particles.speed_scale = 1.5
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 60.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.7
	particles.color = color
	particles.global_position = pos
	_add_to_scene(particles, parent)
	_auto_free(particles, 0.6)

# ── Frost Nova Ring ──

func frost_ring(pos: Vector2, radius: float = 32.0, parent: Node = null) -> void:
	if not enabled:
		return
	_spawn_ring(pos, Color(0.4, 0.7, 1.0, 0.6), radius, 0.4, parent)
	# Ice particle burst
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.amount = 16
	particles.lifetime = 0.5
	particles.speed_scale = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 10.0
	particles.initial_velocity_max = 35.0
	particles.gravity = Vector2(0, -10)  # float upward slightly
	particles.scale_amount_min = 0.2
	particles.scale_amount_max = 0.6
	particles.color = Color(0.6, 0.85, 1.0, 0.8)
	particles.global_position = pos
	_add_to_scene(particles, parent)
	_auto_free(particles, 0.8)

# ── Warp / Portal Spawn ──

func warp_portal(pos: Vector2, color: Color = Color(0.82, 0.08, 0.06, 0.98), radius: float = 20.0, duration: float = 0.55, parent: Node = null, collapse: bool = false, duration_scale: float = 1.0) -> void:
	if not enabled:
		return
	var actual_duration := duration * maxf(duration_scale, 0.1)
	var root = Node2D.new()
	root.global_position = pos
	root.z_index = 18

	var sprite = Sprite2D.new()
	sprite.texture = _get_warp_quad_texture()
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * maxf(radius * 2.0 / 96.0, 0.1)

	var mat = ShaderMaterial.new()
	mat.shader = _warp_shader
	mat.set_shader_parameter("warp_color", color)
	mat.set_shader_parameter("edge_color", color.lightened(0.45))
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("collapse_bias", 0.25 if collapse else 0.0)
	mat.set_shader_parameter("alpha_strength", 1.22)
	mat.set_shader_parameter("crackle_strength", 1.5)
	sprite.material = mat
	root.add_child(sprite)
	_add_to_scene(root, parent)

	_spawn_storm_crackle(pos, color, radius, parent, actual_duration)
	if duration_scale > 1.1:
		_spawn_storm_crackle(pos, color.lightened(0.08), radius * 0.78, parent, actual_duration * 0.92)
	if not collapse:
		_schedule_storm_burst(pos, color, radius * 0.92, parent, actual_duration * 0.26, actual_duration * 0.78)
		_schedule_storm_burst(pos, color.lightened(0.06), radius * 0.72, parent, actual_duration * 0.48, actual_duration * 0.62)

	var tween = root.create_tween()
	tween.tween_property(mat, "shader_parameter/progress", 0.76, actual_duration * 0.58)
	tween.tween_property(mat, "shader_parameter/progress", 1.0, actual_duration * 0.42)
	if collapse:
		tween.parallel().tween_property(sprite, "scale", sprite.scale * 0.82, actual_duration)
	else:
		tween.parallel().tween_property(sprite, "scale", sprite.scale * 1.16, actual_duration)
	tween.parallel().tween_interval(actual_duration * 0.52)
	tween.parallel().tween_property(root, "modulate:a", 0.0, actual_duration * 0.48)
	tween.tween_callback(root.queue_free)

func warp_link(start_pos: Vector2, end_pos: Vector2, color: Color = Color(0.82, 0.08, 0.06, 0.98), start_radius: float = 16.0, end_radius: float = 22.0, parent: Node = null, duration_scale: float = 1.0) -> void:
	if not enabled:
		return
	warp_portal(start_pos, color, start_radius, 0.42, parent, true, duration_scale)
	warp_portal(end_pos, color.lightened(0.02), end_radius, 0.58, parent, false, duration_scale)
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 10
	particles.lifetime = 0.22
	particles.speed_scale = 1.6
	particles.direction = (end_pos - start_pos).normalized()
	particles.spread = 10.0
	particles.initial_velocity_min = start_pos.distance_to(end_pos) * 1.8
	particles.initial_velocity_max = start_pos.distance_to(end_pos) * 2.4
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 0.18
	particles.scale_amount_max = 0.42
	particles.color = color.lightened(0.35)
	particles.global_position = start_pos
	_add_to_scene(particles, parent)
	_auto_free(particles, 0.45 * maxf(duration_scale, 0.1))
	_spawn_storm_bolt(start_pos, end_pos, color.lightened(0.3), parent)
	_spawn_storm_bolt(
		start_pos + Vector2(randf_range(-4.0, 4.0), randf_range(-6.0, 2.0)),
		end_pos + Vector2(randf_range(-4.0, 4.0), randf_range(-2.0, 6.0)),
		color.lightened(0.45),
		parent,
		0.16 * maxf(duration_scale, 0.1)
	)

func storm_arrival(pos: Vector2, color: Color = Color(0.84, 0.07, 0.05, 0.98), radius: float = 32.0, duration: float = 0.9, parent: Node = null) -> void:
	if not enabled:
		return
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("lightning_b", -5.0, 0.03)
		sfx.play("teleport", -8.0, 0.02)
	_spawn_storm_core(pos, radius * 0.32, duration, parent)
	_spawn_storm_aura(pos, color, radius * 0.72, parent, duration * 0.9)
	_spawn_storm_crackle(pos, color, radius * 0.82, parent, duration * 0.42)
	_schedule_storm_cluster(pos, color, radius, parent, 0.0, duration * 0.34)
	_schedule_storm_cluster(pos, color.lightened(0.06), radius * 0.92, parent, duration * 0.16, duration * 0.3)
	_schedule_storm_cluster(pos, color.darkened(0.08), radius * 0.72, parent, duration * 0.33, duration * 0.26)
	_schedule_storm_cluster(pos, color.lightened(0.12), radius * 0.58, parent, duration * 0.52, duration * 0.22)
	_schedule_storm_aura_burst(pos, color, radius * 0.58, parent, duration * 0.22, duration * 0.34)
	_schedule_storm_aura_burst(pos, color.lightened(0.08), radius * 0.46, parent, duration * 0.48, duration * 0.28)

# ── Arrow Rain Markers ──

func arrow_rain_burst(pos: Vector2, parent: Node = null) -> void:
	if not enabled:
		return
	# Yellow burst of particles
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.6
	particles.amount = 10
	particles.lifetime = 0.3
	particles.speed_scale = 1.5
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 45.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 0.2
	particles.scale_amount_max = 0.5
	particles.color = Color(1.0, 0.9, 0.3, 0.8)
	particles.global_position = pos
	_add_to_scene(particles, parent)
	_auto_free(particles, 0.5)

# ── Charged Blast Impact ──

func charged_impact(pos: Vector2, charge_ratio: float = 1.0, parent: Node = null) -> void:
	if not enabled:
		return
	var size = 8.0 + charge_ratio * 16.0
	_spawn_ring(pos, Color(0.5, 0.7, 1.0, 0.7), size, 0.3, parent)
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = int(6 + charge_ratio * 10)
	particles.lifetime = 0.3
	particles.speed_scale = 1.5
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 15.0
	particles.initial_velocity_max = 40.0 + charge_ratio * 20.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.6 + charge_ratio * 0.4
	particles.color = Color(0.6, 0.8, 1.0)
	particles.global_position = pos
	_add_to_scene(particles, parent)
	_auto_free(particles, 0.6)

# ── Status Effect Applied ──

func status_puff(pos: Vector2, status_or_color: Variant, parent: Node = null) -> void:
	if not enabled:
		return
	var color = Color.WHITE
	if status_or_color is Color:
		color = status_or_color
	elif status_or_color is String:
		match status_or_color:
			"BURNING": color = Color(1.0, 0.5, 0.1)
			"SLOWED": color = Color(0.4, 0.7, 1.0)
			"POISONED": color = Color(0.3, 0.9, 0.2)
			"HEAL": color = Color(0.2, 1.0, 0.3)
			"CURE": color = Color(0.9, 1.0, 0.9)
			"STEALTH": color = Color(0.5, 0.5, 0.7)
			"POWER": color = Color(1.0, 0.6, 0.2)
			"POISON": color = Color(0.3, 0.9, 0.2)
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.amount = 6
	particles.lifetime = 0.4
	particles.speed_scale = 1.0
	particles.direction = Vector2.UP
	particles.spread = 60.0
	particles.initial_velocity_min = 5.0
	particles.initial_velocity_max = 15.0
	particles.gravity = Vector2(0, -20)
	particles.scale_amount_min = 0.2
	particles.scale_amount_max = 0.5
	particles.color = color
	particles.global_position = pos
	_add_to_scene(particles, parent)
	_auto_free(particles, 0.7)

# ── Level Up Burst ──

func level_up_burst(pos: Vector2, parent: Node = null) -> void:
	if not enabled:
		return
	_spawn_ring(pos, Color(1.0, 0.9, 0.2, 0.6), 20.0, 0.5, parent)
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.5
	particles.amount = 20
	particles.lifetime = 0.8
	particles.speed_scale = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 10.0
	particles.initial_velocity_max = 30.0
	particles.gravity = Vector2(0, -15)
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.8
	particles.color = Color(1.0, 0.85, 0.2)
	particles.global_position = pos
	_add_to_scene(particles, parent)
	_auto_free(particles, 1.2)

# ── Gold Pickup Sparkle ──

func gold_sparkle(pos: Vector2, parent: Node = null) -> void:
	if not enabled:
		return
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 4
	particles.lifetime = 0.3
	particles.speed_scale = 1.2
	particles.direction = Vector2.UP
	particles.spread = 120.0
	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 20.0
	particles.gravity = Vector2(0, -10)
	particles.scale_amount_min = 0.2
	particles.scale_amount_max = 0.4
	particles.color = Color(1.0, 0.9, 0.3)
	particles.global_position = pos
	_add_to_scene(particles, parent)
	_auto_free(particles, 0.5)

# ── Helper: Expanding Ring ──

func _spawn_ring(pos: Vector2, color: Color, radius: float, duration: float, parent: Node = null) -> void:
	# Draw ring as a thin donut using a simple polygon circle
	var ring = Node2D.new()
	ring.global_position = pos
	ring.modulate = color
	ring.z_index = 10

	var draw_node = _RingDraw.new()
	draw_node.target_radius = radius
	draw_node.duration = duration
	ring.add_child(draw_node)

	_add_to_scene(ring, parent)

	var tween = ring.create_tween()
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.tween_callback(ring.queue_free)

func _spawn_storm_crackle(pos: Vector2, color: Color, radius: float, parent: Node = null, duration: float = 0.4) -> void:
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.94
	particles.amount = 20
	particles.lifetime = maxf(0.22, duration * 0.55)
	particles.speed_scale = 1.35
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = radius * 0.35
	particles.initial_velocity_max = radius * 0.95
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 0.14
	particles.scale_amount_max = 0.34
	particles.color = color.lightened(0.4)
	particles.global_position = pos
	_add_to_scene(particles, parent)
	_auto_free(particles, maxf(0.4, duration))
	for i in range(6):
		var angle = randf() * TAU
		var dir = Vector2.from_angle(angle)
		_spawn_storm_bolt(
			pos + dir * randf_range(2.0, radius * 0.18),
			pos + dir * randf_range(radius * 0.32, radius * 0.72),
			color.lightened(0.22),
			parent,
			maxf(0.14, duration * 0.34)
		)

func _spawn_storm_aura(pos: Vector2, color: Color, radius: float, parent: Node = null, duration: float = 0.5) -> void:
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.35
	particles.amount = clampi(int(radius * 0.65), 18, 52)
	particles.lifetime = maxf(0.28, duration * 0.75)
	particles.speed_scale = 0.92
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = radius * 0.06
	particles.initial_velocity_max = radius * 0.24
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 0.05
	particles.scale_amount_max = 0.14
	particles.color = Color(color.r, color.g * 0.7, color.b * 0.7, 0.42)
	particles.global_position = pos + Vector2(randf_range(-radius * 0.12, radius * 0.12), randf_range(-radius * 0.12, radius * 0.12))
	_add_to_scene(particles, parent)
	_auto_free(particles, maxf(0.45, duration))

func _schedule_storm_burst(pos: Vector2, color: Color, radius: float, parent: Node = null, delay: float = 0.1, duration: float = 0.35) -> void:
	var timer := get_tree().create_timer(maxf(delay, 0.01))
	timer.timeout.connect(func():
		if not is_inside_tree():
			return
		_spawn_storm_crackle(pos, color, radius, parent, duration)
	)

func _schedule_storm_aura_burst(pos: Vector2, color: Color, radius: float, parent: Node = null, delay: float = 0.0, duration: float = 0.24) -> void:
	var timer := get_tree().create_timer(maxf(delay, 0.0))
	timer.timeout.connect(func():
		if not is_inside_tree():
			return
		_spawn_storm_aura(
			pos + Vector2(randf_range(-radius * 0.18, radius * 0.18), randf_range(-radius * 0.18, radius * 0.18)),
			color,
			radius * randf_range(0.82, 1.12),
			parent,
			duration
		)
	)

func _schedule_storm_cluster(pos: Vector2, color: Color, radius: float, parent: Node = null, delay: float = 0.0, duration: float = 0.28) -> void:
	var timer := get_tree().create_timer(maxf(delay, 0.0))
	timer.timeout.connect(func():
		if not is_inside_tree():
			return
		var offsets := [
			Vector2(0, -radius * randf_range(0.45, 0.9)),
			Vector2(0, radius * randf_range(0.35, 0.75)),
			Vector2(-radius * randf_range(0.35, 0.85), randf_range(-radius * 0.25, radius * 0.25)),
			Vector2(radius * randf_range(0.35, 0.85), randf_range(-radius * 0.25, radius * 0.25)),
			Vector2(-radius * randf_range(0.18, 0.55), -radius * randf_range(0.18, 0.55)),
			Vector2(radius * randf_range(0.18, 0.55), radius * randf_range(0.18, 0.55)),
		]
		for offset in offsets:
			var start_pos: Vector2 = pos + offset * randf_range(0.45, 0.85)
			var end_pos: Vector2 = pos + offset + Vector2(randf_range(-radius * 0.12, radius * 0.12), randf_range(-radius * 0.12, radius * 0.12))
			_spawn_storm_bolt(start_pos, end_pos, color.lightened(randf_range(0.08, 0.22)), parent, maxf(0.12, duration * randf_range(0.72, 1.08)))
		_spawn_storm_crackle(pos + Vector2(randf_range(-radius * 0.12, radius * 0.12), randf_range(-radius * 0.12, radius * 0.12)), color, radius * randf_range(0.38, 0.62), parent, duration)
	)

func _spawn_storm_core(pos: Vector2, radius: float, duration: float, parent: Node = null) -> void:
	var core = _StormCoreDraw.new()
	core.radius = radius
	core.duration = duration
	core.global_position = pos
	core.z_index = 17
	_add_to_scene(core, parent)
	var tween = core.create_tween()
	tween.tween_interval(duration * 0.58)
	tween.tween_property(core, "modulate:a", 0.0, duration * 0.42)
	tween.tween_callback(core.queue_free)

func _spawn_storm_bolt(start_pos: Vector2, end_pos: Vector2, color: Color, parent: Node = null, duration: float = 0.22) -> void:
	var bolt = _StormBoltDraw.new()
	var bolt_len := start_pos.distance_to(end_pos)
	bolt.global_position = start_pos
	bolt.relative_points = PackedVector2Array(_build_bolt_points(start_pos, end_pos))
	bolt.outer_width = clampf(bolt_len / 24.0, 0.5, 1.4)
	bolt.inner_width = clampf(bolt_len / 48.0, 0.28, 0.75)
	bolt.modulate = color
	bolt.z_index = 19
	_add_to_scene(bolt, parent)
	var tween = bolt.create_tween()
	tween.tween_property(bolt, "modulate:a", 0.0, duration)
	tween.tween_callback(bolt.queue_free)

func _build_bolt_points(start_pos: Vector2, end_pos: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var total = end_pos - start_pos
	var dist = total.length()
	var dir = total.normalized() if dist > 0.001 else Vector2.RIGHT
	var perp = dir.orthogonal()
	var segments = maxi(3, int(dist / 10.0))
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var point = total * t
		if i != 0 and i != segments:
			point += perp * randf_range(-dist * 0.12, dist * 0.12)
		points.append(point)
	return points

# ── Helpers ──

func _get_warp_quad_texture() -> Texture2D:
	if _warp_quad_texture:
		return _warp_quad_texture
	var img = Image.create(96, 96, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_warp_quad_texture = ImageTexture.create_from_image(img)
	return _warp_quad_texture

func _add_to_scene(node: Node, parent: Node = null) -> void:
	if parent and is_instance_valid(parent):
		parent.add_child(node)
	else:
		var scene = get_tree().current_scene
		if scene:
			scene.add_child(node)

func _auto_free(node: Node, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(
		func():
			if is_instance_valid(node):
				node.queue_free()
	)

# ── Inner class for drawing expanding ring ──

class _RingDraw extends Node2D:
	var target_radius: float = 20.0
	var duration: float = 0.3
	var _elapsed: float = 0.0

	func _process(delta: float) -> void:
		_elapsed += delta
		queue_redraw()

	func _draw() -> void:
		var t = clampf(_elapsed / maxf(duration, 0.01), 0.0, 1.0)
		var r = target_radius * t
		if r > 0.5:
			draw_arc(Vector2.ZERO, r, 0, TAU, 24, Color.WHITE, 1.0, true)

class _DashTrailLine extends Node2D:
	## A simple drawn black rectangle used as a dash trail line.
	var length: float = 6.0:
		set(v):
			length = v
			queue_redraw()

	func _draw() -> void:
		# Draw a 1px tall black rectangle extending along local X axis
		draw_rect(Rect2(0, -0.5, length, 1.0), Color.BLACK)

class _StormBoltDraw extends Node2D:
	var relative_points: PackedVector2Array = PackedVector2Array()
	var outer_width: float = 2.0
	var inner_width: float = 1.0

	func _draw() -> void:
		if relative_points.size() < 2:
			return
		draw_polyline(relative_points, Color(1.0, 0.92, 0.75, 0.85), outer_width, true)
		draw_polyline(relative_points, Color(1.0, 0.2, 0.08, 0.95), inner_width, true)

class _StormCoreDraw extends Node2D:
	var radius: float = 8.0
	var duration: float = 0.6
	var _elapsed: float = 0.0

	func _process(delta: float) -> void:
		_elapsed += delta
		queue_redraw()

	func _draw() -> void:
		var t := clampf(_elapsed / maxf(duration, 0.01), 0.0, 1.0)
		var wobble := 0.92 + sin(TAU * t * 2.5) * 0.05
		draw_circle(Vector2.ZERO, radius * wobble, Color(0.08, 0.0, 0.0, 0.5 * (1.0 - t * 0.65)))
