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

# Tracks the highest wave reached across sessions (for bestiary unlock)
var highest_wave_reached: int = 0

# ── Host Migration State ──────────────────────────────────────────────────────
var is_migrating: bool = false
var _host_migration_active: bool = false
var _cached_snapshot: Dictionary = {}
var _peer_addresses: Dictionary = {}  # { peer_id: ip_address }
var _my_peer_id: int = 0
var _my_display_name: String = ""


# ── Public API ─────────────────────────────────────────────────────────────────

## Creates a server on the given port.
## Returns OK on success or an error code on failure.
func host_game(port: int = DEFAULT_PORT) -> Error:
	# Close any existing peer to release the port
	if peer and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		peer.close()
		multiplayer.multiplayer_peer = null
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
	# Close any existing peer to release resources
	if peer and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		peer.close()
		multiplayer.multiplayer_peer = null
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
	# Disconnect any existing connections first to prevent double-connections
	# during host migration (signals belong to SceneMultiplayer, not the peer).
	var mp := multiplayer
	if mp.peer_connected.is_connected(_on_peer_connected):
		mp.peer_connected.disconnect(_on_peer_connected)
	if mp.peer_disconnected.is_connected(_on_peer_disconnected):
		mp.peer_disconnected.disconnect(_on_peer_disconnected)
	if mp.connected_to_server.is_connected(_on_connected_to_server):
		mp.connected_to_server.disconnect(_on_connected_to_server)
	if mp.connection_failed.is_connected(_on_connection_failed):
		mp.connection_failed.disconnect(_on_connection_failed)
	if mp.server_disconnected.is_connected(_on_server_disconnected):
		mp.server_disconnected.disconnect(_on_server_disconnected)

	mp.peer_connected.connect(_on_peer_connected)
	mp.peer_disconnected.connect(_on_peer_disconnected)
	mp.connected_to_server.connect(_on_connected_to_server)
	mp.connection_failed.connect(_on_connection_failed)
	mp.server_disconnected.connect(_on_server_disconnected)


# ── Signal Handlers ────────────────────────────────────────────────────────────

func _on_peer_connected(id: int) -> void:
	print("NetworkManager: Peer connected — id %d" % id)
	Events.player_joined.emit(id, Vector3.ZERO)


func _on_peer_disconnected(id: int) -> void:
	print("NetworkManager: Peer disconnected — id %d" % id)
	role_assignments.erase(id)
	player_names.erase(id)
	Events.player_left.emit(id)
	Events.connection_lost.emit(id, "peer_disconnected")


func _on_connected_to_server() -> void:
	print("NetworkManager: Successfully connected to server")
	# Cache peer ID now while the connection is alive — it may return 0 after
	# server_disconnected fires.
	_my_peer_id = multiplayer.get_unique_id()
	Events.connection_established.emit(_my_peer_id, false)

	if is_migrating:
		# Register our identity with the new host so it can spawn us with snapshot data.
		_register_migrated_player.rpc_id(1, _my_display_name)
		get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_connection_failed() -> void:
	print("NetworkManager: Connection to server failed")
	Events.connection_lost.emit(0, "connection_failed")
	multiplayer.multiplayer_peer = null
	peer = null

	if _host_migration_active:
		print("NetworkManager: Migration reconnection failed — falling back to lobby")
		_abort_migration()


func _on_server_disconnected() -> void:
	print("NetworkManager: Server disconnected")

	# If migration is already in progress and the new host also failed, give up.
	if _host_migration_active:
		print("NetworkManager: New host also disconnected — falling back to lobby")
		_abort_migration()
		return

	# _my_peer_id was cached in _on_connected_to_server while the connection was alive.
	_my_display_name = player_names.get(_my_peer_id, "")

	var can_migrate := not _cached_snapshot.is_empty()

	Events.connection_lost.emit(1, "server_disconnected")
	multiplayer.multiplayer_peer = null
	peer = null

	if can_migrate:
		_initiate_migration()
	else:
		role_assignments.clear()
		player_names.clear()
		if get_tree().current_scene and get_tree().current_scene.name != "Lobby":
			get_tree().change_scene_to_file("res://scenes/lobby.tscn")


# ── Host Migration ────────────────────────────────────────────────────────────

## Called by GameManager every 3 seconds to send a state snapshot to all clients.
func send_snapshot(snapshot: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_receive_snapshot.rpc(snapshot)
	_build_and_share_peer_addresses()


@rpc("authority", "reliable")
func _receive_snapshot(snapshot: Dictionary) -> void:
	_cached_snapshot = snapshot


func _build_and_share_peer_addresses() -> void:
	if not multiplayer.is_server():
		return
	_peer_addresses.clear()
	_peer_addresses[1] = get_local_ip()
	for pid in multiplayer.get_peers():
		var enet_peer := peer.get_peer(pid)
		if enet_peer:
			_peer_addresses[pid] = enet_peer.get_remote_address()
	_receive_peer_addresses.rpc(_peer_addresses)


@rpc("authority", "reliable")
func _receive_peer_addresses(addresses: Dictionary) -> void:
	_peer_addresses = addresses


func _initiate_migration() -> void:
	_host_migration_active = true
	is_migrating = true
	print("NetworkManager: Initiating host migration...")

	# Determine new host: lowest peer ID excluding the old server (peer 1).
	var candidate_ids: Array[int] = []
	for pid in _peer_addresses:
		if pid != 1:
			candidate_ids.append(pid)
	candidate_ids.sort()

	if candidate_ids.is_empty():
		_abort_migration()
		return

	var new_host_id: int = candidate_ids[0]
	var is_promoted := _my_peer_id == new_host_id

	_show_migration_message(is_promoted)

	if is_promoted:
		print("NetworkManager: I am the new Repo Owner!")
		_become_new_host()
	else:
		var new_host_ip: String = _peer_addresses.get(new_host_id, "")
		if new_host_ip.is_empty():
			_abort_migration()
			return
		print("NetworkManager: Reconnecting to new Repo Owner (peer %d) at %s" % [new_host_id, new_host_ip])
		# Wait for the new host to start their server before connecting.
		get_tree().create_timer(2.0).timeout.connect(func():
			_reconnect_to_new_host(new_host_ip)
		)


func _become_new_host() -> void:
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(DEFAULT_PORT, MAX_CLIENTS)
	if error != OK:
		push_error("NetworkManager: Failed to create migration server — %s" % error_string(error))
		_abort_migration()
		return

	_connect_signals()
	multiplayer.multiplayer_peer = peer

	# Map our identity to the new server peer ID (always 1).
	player_names.clear()
	player_names[1] = _my_display_name

	# Recover our role from the snapshot.
	role_assignments.clear()
	if _cached_snapshot.has("players") and _cached_snapshot["players"].has(_my_display_name):
		role_assignments[1] = _cached_snapshot["players"][_my_display_name].get("role", "striker")

	print("NetworkManager: Migration server started. Loading game scene...")
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _reconnect_to_new_host(host_ip: String) -> void:
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(host_ip, DEFAULT_PORT)
	if error != OK:
		push_error("NetworkManager: Failed to reconnect to new host at %s — %s" % [host_ip, error_string(error)])
		_abort_migration()
		return

	_connect_signals()
	multiplayer.multiplayer_peer = peer
	print("NetworkManager: Connecting to new host at %s:%d" % [host_ip, DEFAULT_PORT])


@rpc("any_peer", "reliable")
func _register_migrated_player(display_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	player_names[sender_id] = display_name
	# Recover role from snapshot.
	if _cached_snapshot.has("players") and _cached_snapshot["players"].has(display_name):
		role_assignments[sender_id] = _cached_snapshot["players"][display_name].get("role", "striker")
	print("NetworkManager: Migrated player registered — peer %d as '%s'" % [sender_id, display_name])
	Events.migration_player_registered.emit(sender_id)


func _abort_migration() -> void:
	_host_migration_active = false
	is_migrating = false
	_cached_snapshot.clear()
	_peer_addresses.clear()
	role_assignments.clear()
	player_names.clear()
	multiplayer.multiplayer_peer = null
	peer = null
	if get_tree().current_scene and get_tree().current_scene.name != "Lobby":
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _show_migration_message(is_promoted: bool) -> void:
	var hud = get_tree().current_scene.get_node_or_null("UI/HUD")
	if not hud:
		return

	# Dark overlay so the message stands out.
	var overlay := ColorRect.new()
	overlay.name = "MigrationOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.5)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(overlay)

	var container := VBoxContainer.new()
	container.name = "MigrationMessage"
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.offset_left = -300.0
	container.offset_top = -60.0
	container.offset_right = 300.0
	container.offset_bottom = 60.0
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(container)

	var title_label := Label.new()
	title_label.text = "Repo Owner disconnected"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	container.add_child(title_label)

	var status_label := Label.new()
	if is_promoted:
		status_label.text = "You've been promoted to Repo Owner!"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	else:
		status_label.text = "Reconnecting to new Repo Owner..."
		status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 20)
	container.add_child(status_label)
