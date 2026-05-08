class_name PlayerQuery
extends RefCounted

static func get_active_players(tree: SceneTree) -> Array[Node2D]:
	var players: Array[Node2D] = []
	if tree == null:
		return players
	for node in tree.get_nodes_in_group("player"):
		if node is Node2D and is_instance_valid(node):
			players.append(node)
	return players

static func get_primary_player(tree: SceneTree) -> Node2D:
	var players = get_active_players(tree)
	if players.is_empty():
		return null
	return players[0]

static func get_nearest_player(tree: SceneTree, from_pos: Vector2) -> Node2D:
	var players = get_active_players(tree)
	if players.is_empty():
		return null
	var nearest: Node2D = players[0]
	var nearest_dist := from_pos.distance_squared_to(nearest.global_position)
	for i in range(1, players.size()):
		var candidate = players[i]
		var dist_sq = from_pos.distance_squared_to(candidate.global_position)
		if dist_sq < nearest_dist:
			nearest = candidate
			nearest_dist = dist_sq
	return nearest

static func get_random_player(tree: SceneTree, rng: RandomNumberGenerator = null) -> Node2D:
	var players = get_active_players(tree)
	if players.is_empty():
		return null
	if rng:
		return players[rng.randi_range(0, players.size() - 1)]
	return players[randi() % players.size()]

static func get_local_player(tree: SceneTree) -> Node2D:
	var players = get_active_players(tree)
	for p in players:
		if p.has_method("is_local_controlled") and p.is_local_controlled():
			return p
	if players.is_empty():
		return null
	return players[0]

static func get_players_for_peer(tree: SceneTree, peer_id: int) -> Array[Node2D]:
	var matches: Array[Node2D] = []
	for p in get_active_players(tree):
		if "peer_owner_id" in p and int(p.peer_owner_id) == peer_id:
			matches.append(p)
	return matches

static func get_alive_players(tree: SceneTree) -> Array[Node2D]:
	var alive: Array[Node2D] = []
	for p in get_active_players(tree):
		if not p.has_method("is_dead"):
			alive.append(p)
		elif not p.is_dead():
			alive.append(p)
	return alive
