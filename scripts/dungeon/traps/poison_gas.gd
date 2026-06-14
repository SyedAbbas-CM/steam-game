extends "res://scripts/dungeon/traps/dungeon_trap.gd"

## Proximity-triggered gas cloud. Spawns a persistent poison AOE when player gets near.

var trap_atlas: Vector2i

const PROXIMITY_RANGE_SQ = 256.0  # 16px = 2 tiles
const CLOUD_DURATION = 8.0
const CLOUD_RADIUS = 24.0  # 3 tiles
const DAMAGE_INTERVAL = 0.5
const POISON_STATUS_DURATION = 4.0
const ENEMY_DAMAGE_MULT = 2

var player: Node2D
var _cloud: Node2D
var _cloud_timer: float = 0.0
var _damage_timer: float = 0.0
var _ring: Polygon2D
var _ring_timer: float = 0.0

func _ready() -> void:
	super._ready()
	player = get_tree().get_first_node_in_group("player")

func get_damage() -> int:
	return _scaled_trap_damage(2, 1, 1, 2)

func trigger_remote() -> void:
	if _triggered:
		return
	_triggered = true
	_spawn_cloud()

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return

	if not _triggered:
		if player:
			if global_position.distance_squared_to(player.global_position) <= PROXIMITY_RANGE_SQ:
				_triggered = true
				_spawn_cloud()
		return

	# Cloud is active — tick damage and lifetime
	if _cloud and is_instance_valid(_cloud):
		_cloud_timer += delta
		_damage_timer += delta
		_ring_timer += delta
		_update_ring_visual()

		# Damage player and enemies inside cloud
		if _damage_timer >= DAMAGE_INTERVAL:
			_damage_timer -= DAMAGE_INTERVAL
			var cloud_pos = _cloud.global_position
			var damage = get_damage()

			# Damage player
			var player = _find_player()
			if player and cloud_pos.distance_to(player.global_position) <= CLOUD_RADIUS:
				if player.has_method("take_damage"):
					player.take_damage(damage, Vector2.INF, false, false, CombatTypes.DamageType.TRUE)
				if "status_effects" in player and player.status_effects:
					player.status_effects.apply_status("POISONED", POISON_STATUS_DURATION)

			# Damage enemies (2x) + 15% confusion chance per tick
			for enemy in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(enemy) and cloud_pos.distance_to(enemy.global_position) <= CLOUD_RADIUS:
					if enemy.has_method("take_damage"):
						enemy.take_damage(damage * ENEMY_DAMAGE_MULT, false, CombatTypes.DamageType.TRUE)
					if randf() < 0.15 and enemy.has_method("apply_status"):
						enemy.apply_status("CONFUSED", 3.0)

		# Fade out in last second
		if _cloud_timer >= CLOUD_DURATION - 1.0:
			var fade = 1.0 - (_cloud_timer - (CLOUD_DURATION - 1.0))
			_cloud.modulate.a = maxf(fade, 0.0)

		# Remove cloud
		if _cloud_timer >= CLOUD_DURATION:
			_cloud.queue_free()
			_cloud = null
			set_physics_process(false)
			queue_free()

func _spawn_cloud() -> void:
	_play_sfx("gas", -3.0, 0.1)
	if _has_deco_layer():
		deco_layer.erase_cell(origin + tile_pos)

	# Create cloud visual with CPUParticles2D
	_cloud = Node2D.new()
	_cloud.global_position = global_position
	_cloud.add_to_group("poison_cloud")

	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 28
	particles.lifetime = 1.5
	particles.one_shot = false
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = CLOUD_RADIUS
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 5.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 3.0
	particles.color = Color(0.2, 0.8, 0.2, 0.4)
	_cloud.add_child(particles)

	_ring = Polygon2D.new()
	_ring.color = Color(0.25, 0.95, 0.35, 0.16)
	_ring.polygon = _make_circle_points(CLOUD_RADIUS * 0.95, 18)
	_cloud.add_child(_ring)

	get_tree().current_scene.add_child(_cloud)

	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.status_puff(global_position, "POISONED")

func _update_ring_visual() -> void:
	if _ring == null:
		return
	var pulse = 0.92 + 0.12 * sin(_ring_timer * 3.5)
	_ring.scale = Vector2.ONE * pulse
	_ring.rotation += 0.01
	_ring.color.a = 0.12 + 0.07 * (0.5 + 0.5 * sin(_ring_timer * 5.0))

func _make_circle_points(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts
