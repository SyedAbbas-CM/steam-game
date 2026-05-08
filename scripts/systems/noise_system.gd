extends Node

## Noise system: player actions emit noise that alerts nearby enemies.
## Enemies within radius get awareness bumps based on intensity and distance.

func emit_noise(pos: Vector2, radius: float, intensity: float) -> void:
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.state == enemy.State.DEAD:
			continue
		if enemy.state == enemy.State.CHASE:
			continue  # already alerted
		var dist = enemy.global_position.distance_to(pos)
		if dist > radius:
			continue
		var falloff = 1.0 - (dist / radius)
		var bump = intensity * falloff
		if enemy.has_method("_on_noise_heard"):
			enemy._on_noise_heard(pos, bump)
		else:
			enemy._awareness = minf(enemy._awareness + bump, 1.0)
