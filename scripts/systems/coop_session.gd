extends Node

enum SessionMode {
	OFFLINE,
	HOST,
	CLIENT,
	DEDICATED_SERVER,
}

signal session_mode_changed(mode: int)
signal hosting_started(port: int, max_players: int)
signal joined_server(address: String, port: int)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal connection_failed
signal server_disconnected
signal session_closed
signal host_network_info_updated(info: Dictionary)

const DEFAULT_PORT: int = 24567
const DEFAULT_MAX_PLAYERS: int = 4

var mode: int = SessionMode.OFFLINE
var listen_port: int = DEFAULT_PORT
var max_players: int = DEFAULT_MAX_PLAYERS
var connect_address: String = ""
var room_code: String = ""
var host_network_info: Dictionary = {
	"port": DEFAULT_PORT,
	"local_addresses": PackedStringArray(),
	"external_address": "",
	"upnp_ok": false,
	"gateway": "",
}

func _ready() -> void:
	_bind_multiplayer_signals()

func _bind_multiplayer_signals() -> void:
	var mp := get_tree().get_multiplayer()
	if not mp.peer_connected.is_connected(_on_peer_connected):
		mp.peer_connected.connect(_on_peer_connected)
	if not mp.peer_disconnected.is_connected(_on_peer_disconnected):
		mp.peer_disconnected.connect(_on_peer_disconnected)
	if not mp.connected_to_server.is_connected(_on_connected_to_server):
		mp.connected_to_server.connect(_on_connected_to_server)
	if not mp.connection_failed.is_connected(_on_connection_failed):
		mp.connection_failed.connect(_on_connection_failed)
	if not mp.server_disconnected.is_connected(_on_server_disconnected):
		mp.server_disconnected.connect(_on_server_disconnected)

func is_multiplayer_active() -> bool:
	return mode != SessionMode.OFFLINE and multiplayer.has_multiplayer_peer()

func is_host() -> bool:
	return mode == SessionMode.HOST or mode == SessionMode.DEDICATED_SERVER

func is_client() -> bool:
	return mode == SessionMode.CLIENT

func get_local_peer_id() -> int:
	if not multiplayer.has_multiplayer_peer():
		return 1
	return multiplayer.get_unique_id()

func get_connected_peer_ids() -> PackedInt32Array:
	if not multiplayer.has_multiplayer_peer():
		return PackedInt32Array()
	return multiplayer.get_peers()

func get_local_ipv4_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for addr in IP.get_local_addresses():
		var ip: String = String(addr)
		if ":" in ip:
			continue
		if ip.begins_with("127."):
			continue
		if ip == "0.0.0.0":
			continue
		out.append(ip)
	return out

func get_host_network_summary() -> Dictionary:
	var info := host_network_info.duplicate(true)
	info["mode"] = mode
	return info

func host_direct(port: int = DEFAULT_PORT, desired_max_players: int = DEFAULT_MAX_PLAYERS) -> Error:
	close_session()
	listen_port = port
	max_players = clampi(desired_max_players, 1, 32)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(listen_port, max_players)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = SessionMode.HOST
	host_network_info = {
		"port": listen_port,
		"local_addresses": get_local_ipv4_addresses(),
		"external_address": "",
		"upnp_ok": false,
		"gateway": "",
	}
	session_mode_changed.emit(mode)
	hosting_started.emit(listen_port, max_players)
	host_network_info_updated.emit(get_host_network_summary())
	return OK

func host_with_optional_upnp(port: int = DEFAULT_PORT, desired_max_players: int = DEFAULT_MAX_PLAYERS, use_upnp: bool = true) -> Dictionary:
	var result := {
		"error": OK,
		"upnp": {
			"ok": false,
			"gateway": "",
			"external_address": "",
			"error": OK,
		},
		"network_info": {},
	}
	var err := host_direct(port, desired_max_players)
	result.error = err
	if err != OK:
		return result
	if use_upnp:
		result.upnp = try_upnp(port)
		host_network_info["upnp_ok"] = bool(result.upnp.get("ok", false))
		host_network_info["gateway"] = String(result.upnp.get("gateway", ""))
		host_network_info["external_address"] = String(result.upnp.get("external_address", ""))
		host_network_info_updated.emit(get_host_network_summary())
	result.network_info = get_host_network_summary()
	return result

func join_direct(address: String, port: int = DEFAULT_PORT) -> Error:
	close_session()
	connect_address = address.strip_edges()
	listen_port = port
	if connect_address == "":
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(connect_address, listen_port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = SessionMode.CLIENT
	session_mode_changed.emit(mode)
	return OK

func try_upnp(port: int = DEFAULT_PORT) -> Dictionary:
	var result := {
		"ok": false,
		"gateway": "",
		"external_address": "",
		"error": OK,
	}
	var upnp := UPNP.new()
	var discover_err := upnp.discover()
	result.error = discover_err
	if discover_err != OK:
		return result
	var gateway = upnp.get_gateway()
	if gateway == null or not gateway.is_valid_gateway():
		result.error = ERR_UNAVAILABLE
		return result
	var map_err := upnp.add_port_mapping(port, port, ProjectSettings.get_setting("application/config/name", "Godot Coop"), "UDP")
	if map_err != OK:
		result.error = map_err
		return result
	result.ok = true
	result.gateway = gateway.get_model_name()
	result.external_address = upnp.query_external_address()
	result.error = OK
	return result

func close_session() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
	var was_active := mode != SessionMode.OFFLINE
	mode = SessionMode.OFFLINE
	connect_address = ""
	room_code = ""
	host_network_info = {
		"port": DEFAULT_PORT,
		"local_addresses": PackedStringArray(),
		"external_address": "",
		"upnp_ok": false,
		"gateway": "",
	}
	if was_active:
		session_mode_changed.emit(mode)
		session_closed.emit()

func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	peer_left.emit(peer_id)

func _on_connected_to_server() -> void:
	joined_server.emit(connect_address, listen_port)

func _on_connection_failed() -> void:
	close_session()
	connection_failed.emit()

func _on_server_disconnected() -> void:
	close_session()
	server_disconnected.emit()
