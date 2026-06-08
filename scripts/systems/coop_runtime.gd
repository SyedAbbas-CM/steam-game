extends Node

# Per-scene multiplayer orchestration.
# CoopSession handles transport (ENet); CoopRuntime handles "given the current scene,
# what does each peer see": local-player ownership, remote ghost spawning, position +
# animation broadcasts, host-authoritative enemy snapshots.

const REMOTE_PLAYER_SCENE_PATH := "res://scenes/remote_player.tscn"
const BULLET_SCENE_PATH := "res://scenes/bullet.tscn"
const PLAYER_BROADCAST_INTERVAL_SEC := 0.033  # 30 Hz
const ENEMY_BROADCAST_INTERVAL_SEC := 0.05    # 20 Hz

var _ghosts: Dictionary = {}              # peer_id -> RemotePlayer
var _enemies: Dictionary = {}             # network_id -> enemy node (host: all alive; client: known proxies)
var _local_player: Node = null
var _scene_root: Node = null
var _player_broadcast_accum: float = 0.0
var _enemy_broadcast_accum: float = 0.0
var _setup_for_scene: bool = false

func _ready() -> void:
	var coop = get_node_or_null("/root/CoopSession")
	if coop:
		if not coop.peer_joined.is_connected(_on_peer_joined):
			coop.peer_joined.connect(_on_peer_joined)
		if not coop.peer_left.is_connected(_on_peer_left):
			coop.peer_left.connect(_on_peer_left)
		if not coop.session_closed.is_connected(_on_session_closed):
			coop.session_closed.connect(_on_session_closed)

func _process(delta: float) -> void:
	if not _setup_for_scene:
		return
	var coop = get_node_or_null("/root/CoopSession")
	if coop == null or not coop.is_multiplayer_active():
		return
	_tick_player_broadcast(delta)
	if coop.is_host():
		_tick_enemy_broadcast(delta)

func _tick_player_broadcast(delta: float) -> void:
	if _local_player == null or not is_instance_valid(_local_player):
		_local_player = null
		return
	_player_broadcast_accum += delta
	if _player_broadcast_accum < PLAYER_BROADCAST_INTERVAL_SEC:
		return
	_player_broadcast_accum = 0.0
	var state := {}
	if _local_player.has_method("get_network_state"):
		state = _local_player.get_network_state()
	else:
		state = {"pos": _local_player.global_position}
	receive_player_state.rpc(state)

func _tick_enemy_broadcast(delta: float) -> void:
	_enemy_broadcast_accum += delta
	if _enemy_broadcast_accum < ENEMY_BROADCAST_INTERVAL_SEC:
		return
	_enemy_broadcast_accum = 0.0
	# Build snapshot: id -> [x, y, hp]. Prune dead/invalid entries inline.
	var snap := {}
	var dead_ids: Array = []
	for id in _enemies.keys():
		var e = _enemies[id]
		if not is_instance_valid(e) or not e.is_inside_tree():
			dead_ids.append(id)
			continue
		var hp_val: int = int(e.get("hp")) if "hp" in e else -1
		snap[id] = PackedFloat32Array([e.global_position.x, e.global_position.y, float(hp_val)])
	for id in dead_ids:
		_enemies.erase(id)
	if snap.is_empty():
		return
	receive_enemy_snapshot.rpc(snap)

# Called by dungeon_scene._ready(). No-op when offline.
func setup_scene(scene_root: Node, local_player: Node) -> void:
	teardown_scene()
	var coop = get_node_or_null("/root/CoopSession")
	if coop == null or not coop.is_multiplayer_active():
		return
	if scene_root == null or local_player == null:
		return
	_scene_root = scene_root
	_local_player = local_player
	_setup_for_scene = true
	var my_id := multiplayer.get_unique_id()
	if local_player.has_method("configure_peer_owner"):
		local_player.configure_peer_owner(my_id, 0, false)
	for peer_id in multiplayer.get_peers():
		_spawn_ghost(peer_id)
	print("CoopRuntime: scene setup. local_peer=%d, remote_peers=%s, is_host=%s" % [my_id, str(multiplayer.get_peers()), str(coop.is_host())])

func teardown_scene() -> void:
	for peer_id in _ghosts.keys():
		var g = _ghosts[peer_id]
		if is_instance_valid(g):
			g.queue_free()
	_ghosts.clear()
	# CRITICAL: do NOT clear _enemies here. DungeonManager registers enemies during
	# start_run() which runs BEFORE dungeon_scene calls setup_scene(). teardown_scene()
	# at the start of setup_scene() would wipe those registrations, leaving host with
	# nothing to broadcast and client's proxies stuck at spawn. enemies clean themselves
	# up via tree_exited; full reset happens in _on_session_closed.
	_local_player = null
	_scene_root = null
	_player_broadcast_accum = 0.0
	_enemy_broadcast_accum = 0.0
	_setup_for_scene = false

func _spawn_ghost(peer_id: int) -> void:
	if _scene_root == null or not is_instance_valid(_scene_root):
		return
	if _ghosts.has(peer_id):
		return
	var packed: PackedScene = load(REMOTE_PLAYER_SCENE_PATH) as PackedScene
	if packed == null:
		push_warning("CoopRuntime: remote_player scene missing")
		return
	var ghost: Node2D = packed.instantiate()
	ghost.name = "RemotePlayer_%d" % peer_id
	if _local_player and is_instance_valid(_local_player):
		ghost.global_position = _local_player.global_position
	_scene_root.add_child(ghost)
	if ghost.has_method("configure"):
		ghost.configure(peer_id, 0)
	_ghosts[peer_id] = ghost
	print("CoopRuntime: spawned ghost for peer %d" % peer_id)

func _despawn_ghost(peer_id: int) -> void:
	if not _ghosts.has(peer_id):
		return
	var g = _ghosts[peer_id]
	if is_instance_valid(g):
		g.queue_free()
	_ghosts.erase(peer_id)

# Called by DungeonManager right after enemy_container.add_child(enemy).
# On host: track for snapshot broadcast. On client: mark as proxy + track for state updates.
# NOTE: this MUST work before setup_scene runs, because dungeon_manager.start_run() spawns
# the initial wave of enemies (including the Test-Arena-Boss boss) BEFORE dungeon_scene
# calls our setup_scene. We gate only on multiplayer being active, not on _setup_for_scene.
func register_enemy(enemy: Node, network_id: int) -> void:
	if enemy == null or network_id == 0:
		return
	var coop = get_node_or_null("/root/CoopSession")
	if coop == null or not coop.is_multiplayer_active():
		return
	enemy.set("network_id", network_id)
	if coop.is_client():
		enemy.set("_is_remote_proxy", true)
	_enemies[network_id] = enemy
	enemy.tree_exited.connect(_on_enemy_tree_exited.bind(network_id))

func _on_enemy_tree_exited(network_id: int) -> void:
	_enemies.erase(network_id)

func _on_peer_joined(peer_id: int) -> void:
	if _setup_for_scene:
		_spawn_ghost(peer_id)

func _on_peer_left(peer_id: int) -> void:
	_despawn_ghost(peer_id)

func _on_session_closed() -> void:
	teardown_scene()
	# Full reset on session end — clear any lingering enemy registrations from the run.
	_enemies.clear()

# --- RPCs ---

@rpc("any_peer", "call_remote", "unreliable_ordered")
func receive_player_state(state: Dictionary) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		return
	var ghost = _ghosts.get(sender_id)
	if ghost and is_instance_valid(ghost) and ghost.has_method("apply_remote_state"):
		ghost.apply_remote_state(state)

@rpc("authority", "call_remote", "unreliable_ordered")
func receive_enemy_snapshot(snap: Dictionary) -> void:
	# Client-side: apply state to known enemies; cull any not in snapshot.
	# Enemies the client knows about but host doesn't = killed on host → free locally.
	for id in _enemies.keys():
		var e = _enemies[id]
		if not is_instance_valid(e):
			continue
		if snap.has(id):
			var arr: PackedFloat32Array = snap[id]
			if arr.size() >= 3 and e.has_method("apply_remote_state"):
				e.apply_remote_state(Vector2(arr[0], arr[1]), int(arr[2]))
		else:
			# Host considers this enemy dead. Free silently — no death FX on client for now.
			e.queue_free()

# --- Bullet sync (Phase 3) ---
#
# Two flavors:
#   • Enemy bullets: host's enemies fire locally, then broadcast the spawn so each client
#     can instantiate a REAL bullet that collides + damages their local player.
#   • Player bullets: each peer's player fires locally. The other peer instantiates a
#     VISUAL ghost — no collision with players, no damage. Player→enemy damage is routed
#     separately via request_enemy_damage so host stays authoritative over enemy HP.

func broadcast_enemy_bullet(pos: Vector2, dir: Vector2, spd: float, dmg: int, sprite_idx: int, kingdom: String) -> void:
	var coop = get_node_or_null("/root/CoopSession")
	if coop == null or not coop.is_multiplayer_active() or not coop.is_host():
		return
	receive_enemy_bullet.rpc(pos, dir, spd, dmg, sprite_idx, kingdom)

func broadcast_player_bullet(pos: Vector2, dir: Vector2, spd: float, sprite_idx: int) -> void:
	var coop = get_node_or_null("/root/CoopSession")
	if coop == null or not coop.is_multiplayer_active():
		return
	receive_player_bullet_ghost.rpc(pos, dir, spd, sprite_idx)

@rpc("authority", "call_remote", "reliable")
func receive_enemy_bullet(pos: Vector2, dir: Vector2, spd: float, dmg: int, sprite_idx: int, kingdom: String) -> void:
	var container = _get_bullets_container()
	if container == null:
		return
	var packed: PackedScene = load(BULLET_SCENE_PATH) as PackedScene
	if packed == null:
		return
	var b = packed.instantiate()
	b.global_position = pos
	b.direction = dir
	b.speed = spd
	b.is_player_bullet = false
	b.damage = dmg
	b.bullet_sprite_index = sprite_idx
	b.enemy_kingdom = kingdom
	container.add_child(b)

@rpc("any_peer", "call_remote", "reliable")
func receive_player_bullet_ghost(pos: Vector2, dir: Vector2, spd: float, sprite_idx: int) -> void:
	var container = _get_bullets_container()
	if container == null:
		return
	var packed: PackedScene = load(BULLET_SCENE_PATH) as PackedScene
	if packed == null:
		return
	var b = packed.instantiate()
	b.global_position = pos
	b.direction = dir
	b.speed = spd
	b.is_player_bullet = true
	b.bullet_sprite_index = sprite_idx
	b.damage = 0  # visual ghost only
	container.add_child(b)
	# Strip collision after add — _ready may set it; we override on the next frame.
	b.collision_layer = 0
	b.collision_mask = 16  # walls only, so it despawns on walls naturally

func _get_bullets_container() -> Node:
	var t = get_tree()
	if t == null:
		return null
	return t.get_first_node_in_group("bullets")

# --- Damage routing (client → host) ---
#
# Called from bullet.gd when a LOCAL player bullet hits an enemy that's a proxy
# (i.e. host owns the real enemy). RPC to host, host applies via take_damage.

func request_enemy_damage(network_id: int, damage: int) -> void:
	var coop = get_node_or_null("/root/CoopSession")
	if coop == null or not coop.is_multiplayer_active():
		return
	if coop.is_host():
		_apply_enemy_damage_local(network_id, damage)
	else:
		rpc_id(1, "_rpc_apply_enemy_damage", network_id, damage)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_apply_enemy_damage(network_id: int, damage: int) -> void:
	_apply_enemy_damage_local(network_id, damage)

func _apply_enemy_damage_local(network_id: int, damage: int) -> void:
	var e = _enemies.get(network_id)
	if e and is_instance_valid(e) and e.has_method("take_damage"):
		e.take_damage(damage, true)
