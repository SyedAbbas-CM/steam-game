extends Node

## Autoload for visual effects — blood splatters, death pops, screen shake, ability FX.
## Toggle: VFXManager.enabled = false to disable all particle effects.
## All effects auto-cleanup after their lifetime.

var enabled: bool = true
var screen_shake_enabled: bool = true

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

func dash_afterimage(sprite: Sprite2D, pos: Vector2, parent: Node = null) -> void:
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
	ghost.z_index = -1
	_add_to_scene(ghost, parent)
	var tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)

func dash_trail_lines(pos: Vector2, dash_dir: Vector2, sprite_scale: Vector2 = Vector2.ONE, parent: Node = null) -> void:
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
		trail.z_index = -1
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

# ── Helpers ──

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
