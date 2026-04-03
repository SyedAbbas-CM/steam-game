extends "res://scripts/dungeon/traps/dungeon_trap.gd"

## Proximity-triggered gas cloud. Spawns a persistent poison AOE when player gets near.

var trap_atlas: Vector2i

const PROXIMITY_RANGE_SQ = 256.0  # 16px = 2 tiles
const CLOUD_DURATION = 8.0
const CLOUD_RADIUS = 24.0  # 3 tiles
const DAMAGE_INTERVAL = 0.5
const POISON_STATUS_DURATION = 4.0
const ENEMY_DAMAGE_MULT = 2

var _cloud: Node2D
var _cloud_timer: float = 0.0
var _damage_timer: float = 0.0

func _ready() -> void:
	super._ready()

func get_damage() -> int:
	return 1

func trigger_remote() -> void:
	if _triggered:
		return
	_triggered = true
	_spawn_cloud()

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return

	if not _triggered:
		var player = _find_player()
		if player:
			if global_position.distance_squared_to(player.global_position) <= PROXIMITY_RANGE_SQ:
				_triggered = true
				_spawn_cloud()
		return

	# Cloud is active — tick damage and lifetime
	if _cloud and is_instance_valid(_cloud):
		_cloud_timer += delta
		_damage_timer += delta

		# Damage player and enemies inside cloud
		if _damage_timer >= DAMAGE_INTERVAL:
			_damage_timer -= DAMAGE_INTERVAL
			var cloud_pos = _cloud.global_position
			var damage = get_damage()

			# Damage player
			var player = _find_player()
			if player and cloud_pos.distance_to(player.global_position) <= CLOUD_RADIUS:
				if player.has_method("take_damage"):
					player.take_damage(damage)
				if "status_manager" in player and player.status_manager:
					player.status_manager.apply_status("POISONED", POISON_STATUS_DURATION)

			# Damage enemies (2x) + 15% confusion chance per tick
			for enemy in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(enemy) and cloud_pos.distance_to(enemy.global_position) <= CLOUD_RADIUS:
					if enemy.has_method("take_damage"):
						enemy.take_damage(damage * ENEMY_DAMAGE_MULT, false)
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
	deco_layer.erase_cell(origin + tile_pos)

	# Create cloud visual with CPUParticles2D
	_cloud = Node2D.new()
	_cloud.global_position = global_position

	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 20
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

	get_tree().current_scene.add_child(_cloud)

	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.status_puff(global_position, "POISONED")
