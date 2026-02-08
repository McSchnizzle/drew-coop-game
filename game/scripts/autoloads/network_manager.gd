## Network manager autoload — handles hosting, joining, and peer lifecycle.
## Add this as an autoload named "NetworkManager" in Project Settings.
extends Node

const DEFAULT_PORT: int = 7000
const MAX_CLIENTS: int = 3

var peer: ENetMultiplayerPeer


# ── Public API ─────────────────────────────────────────────────────────────────

## Creates a server on the given port.
## Returns OK on success or an error code on failure.
func host_game(port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		push_error("NetworkManager: Failed to create server on port %d — %s" % [port, error_string(error)])
		return error

	# Connect multiplayer signals BEFORE assigning the peer (per Godot networking gotchas).
	_connect_signals()
	multiplayer.multiplayer_peer = peer

	print("NetworkManager: Hosting on port %d" % port)
	Events.connection_established.emit(multiplayer.get_unique_id(), true)
	return OK


## Connects to a host at the given address and port.
## Returns OK on success or an error code on failure.
func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		push_error("NetworkManager: Failed to connect to %s:%d — %s" % [address, port, error_string(error)])
		return error

	# Connect multiplayer signals BEFORE assigning the peer.
	_connect_signals()
	multiplayer.multiplayer_peer = peer

	print("NetworkManager: Joining %s:%d" % [address, port])
	return OK


## Returns this machine's local IP address (useful for displaying a join code).
func get_local_ip() -> String:
	var addresses := IP.get_local_addresses()
	for addr in addresses:
		# Return the first non-loopback IPv4 address.
		if addr != "127.0.0.1" and not ":" in addr:
			return addr
	return "127.0.0.1"


# ── Signal Wiring ──────────────────────────────────────────────────────────────

func _connect_signals() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# ── Signal Handlers ────────────────────────────────────────────────────────────

func _on_peer_connected(id: int) -> void:
	print("NetworkManager: Peer connected — id %d" % id)
	Events.player_joined.emit(id, Vector2.ZERO)


func _on_peer_disconnected(id: int) -> void:
	print("NetworkManager: Peer disconnected — id %d" % id)
	Events.player_left.emit(id)
	Events.connection_lost.emit(id, "peer_disconnected")


func _on_connected_to_server() -> void:
	print("NetworkManager: Successfully connected to server")
	Events.connection_established.emit(multiplayer.get_unique_id(), false)


func _on_connection_failed() -> void:
	print("NetworkManager: Connection to server failed")
	Events.connection_lost.emit(0, "connection_failed")
	multiplayer.multiplayer_peer = null
	peer = null


func _on_server_disconnected() -> void:
	print("NetworkManager: Server disconnected")
	Events.connection_lost.emit(1, "server_disconnected")
	multiplayer.multiplayer_peer = null
	peer = null
