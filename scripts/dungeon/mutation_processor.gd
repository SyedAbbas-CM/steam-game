class_name MutationProcessor
extends Node

var active_mutations: Array[MutationDefinition] = []

func add_mutation(mutation: MutationDefinition) -> void:
	# Check stacking
	var current_stacks = 0
	for m in active_mutations:
		if m.type == mutation.type:
			current_stacks += 1
	if current_stacks < mutation.max_stacks:
		active_mutations.append(mutation)

func get_strength(type: MutationDefinition.MutationType) -> float:
	var total: float = 0.0
	for m in active_mutations:
		if m.type == type:
			total += m.strength * m.tier
	return total

func has_mutation(type: MutationDefinition.MutationType) -> bool:
	for m in active_mutations:
		if m.type == type:
			return true
	return false

# Called when a bullet hits an enemy
func on_bullet_hit(bullet: Node2D, target: Node2D, player: Node2D) -> void:
	# Life steal
	var life_steal = get_strength(MutationDefinition.MutationType.LIFE_STEAL)
	if life_steal > 0.0 and player.has_method("heal"):
		var heal_amount = int(max(1, bullet.damage * life_steal * 0.1))
		player.heal(heal_amount)

	# Exploding bullets
	var explode_strength = get_strength(MutationDefinition.MutationType.EXPLODING_BULLETS)
	if explode_strength > 0.0:
		_spawn_explosion(target.global_position, int(bullet.damage * explode_strength * 0.5))

	# Chain lightning
	var chain_strength = get_strength(MutationDefinition.MutationType.CHAIN_LIGHTNING)
	if chain_strength > 0.0:
		_chain_damage(target, int(bullet.damage * chain_strength * 0.3), 3)

# Called when an enemy dies
func on_enemy_killed(enemy_pos: Vector2, player: Node2D) -> void:
	# Vampiric burst
	var vamp = get_strength(MutationDefinition.MutationType.VAMPIRIC_BURST)
	if vamp > 0.0 and player.has_method("heal"):
		player.heal(int(max(1, vamp * 2)))

	# Shield on kill
	var shield = get_strength(MutationDefinition.MutationType.SHIELD_ON_KILL)
	if shield > 0.0 and player.has_method("add_shield"):
		player.add_shield(int(shield))

# Modify bullet properties before firing
func modify_bullet(bullet: Node2D) -> void:
	# Pierce
	var pierce = get_strength(MutationDefinition.MutationType.BULLET_PIERCE)
	if pierce > 0.0:
		bullet.pierce_count += int(pierce)

	# Homing
	var homing = get_strength(MutationDefinition.MutationType.HOMING_SHOTS)
	if homing > 0.0:
		bullet.homing_strength = homing * 3.0

func _spawn_explosion(pos: Vector2, damage: int) -> void:
	# Create AoE damage at position
	var enemies = get_tree().get_nodes_in_group("enemy")
	var aoe_radius = 30.0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(pos) < aoe_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)

func _chain_damage(source: Node2D, damage: int, max_chains: int) -> void:
	var hit_enemies: Array[Node2D] = [source]
	var current = source
	var chain_range = 40.0

	for _i in range(max_chains):
		var nearest: Node2D = null
		var nearest_dist: float = chain_range

		for enemy in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(enemy) or enemy in hit_enemies:
				continue
			var dist = current.global_position.distance_to(enemy.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = enemy

		if nearest:
			if nearest.has_method("take_damage"):
				nearest.take_damage(damage)
			hit_enemies.append(nearest)
			current = nearest
		else:
			break
