## Network manager autoload — handles hosting, joining, and peer lifecycle.
## Add this as an autoload named "NetworkManager" in Project Settings.
extends Node

const DEFAULT_PORT: int = 7000
const MAX_CLIENTS: int = 3

var peer: ENetMultiplayerPeer

# Role assignments: { peer_id: role_name } — set by lobby, read by game_manager
var role_assignments: Dictionary = {}

# Player names: { peer_id: display_name } — set by lobby
var player_names: Dictionary = {}

# Set true when returning to lobby from a game (connection stays alive)
var is_returning_to_lobby: bool = false


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


# ── Room Code System (IP ↔ short alphanumeric code for easy sharing) ──────────

# 32-char alphabet: no 0, 1, I, O to avoid visual confusion.
const _CODE_CHARS := "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"

## Encodes a local IP address into a short room code like "52C-K2D6".
func ip_to_room_code(ip: String) -> String:
	var octets := ip.split(".")
	if octets.size() != 4:
		return ""

	var value: int = (octets[0].to_int() << 24) | (octets[1].to_int() << 16) | (octets[2].to_int() << 8) | octets[3].to_int()

	var base: int = _CODE_CHARS.length()
	var code := ""
	while value > 0:
		code = _CODE_CHARS[value % base] + code
		value = value / base

	# Pad to 7 characters so all codes are the same length.
	while code.length() < 7:
		code = _CODE_CHARS[0] + code

	# Format as XXX-XXXX for readability.
	return code.substr(0, 3) + "-" + code.substr(3)


## Decodes a room code back into an IP address. Returns "" on invalid input.
func room_code_to_ip(code: String) -> String:
	code = code.to_upper().strip_edges().replace("-", "").replace(" ", "")

	var base: int = _CODE_CHARS.length()
	var value: int = 0
	for i in code.length():
		var idx := _CODE_CHARS.find(code[i])
		if idx == -1:
			return ""
		value = value * base + idx

	var d: int = value & 0xFF
	value = value >> 8
	var c: int = value & 0xFF
	value = value >> 8
	var b: int = value & 0xFF
	value = value >> 8
	var a: int = value & 0xFF

	if a > 255 or b > 255 or c > 255 or d > 255:
		return ""

	return "%d.%d.%d.%d" % [a, b, c, d]


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
	role_assignments.erase(id)
	player_names.erase(id)
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
	role_assignments.clear()
	player_names.clear()
	# If we're in the game scene, return to lobby automatically
	if get_tree().current_scene and get_tree().current_scene.name != "Lobby":
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")
