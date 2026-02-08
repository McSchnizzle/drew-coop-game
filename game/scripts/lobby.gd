## Lobby scene logic — host/join UI and game start flow.
## Attach this script to the root Control node of lobby.tscn.
extends Control

# Expected child node paths (set up in lobby.tscn):
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var start_button: Button = %StartButton
@onready var address_input: LineEdit = %AddressInput
@onready var status_label: Label = %StatusLabel
@onready var room_code_container: HBoxContainer = %RoomCodeContainer
@onready var room_code_label: Label = %RoomCodeLabel
@onready var copy_button: Button = %CopyButton

var _connected_player_count: int = 0
var _is_host: bool = false
var _room_code: String = ""


func _ready() -> void:
	start_button.visible = false
	room_code_container.visible = false
	status_label.text = "Ready to host or join."

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_button.pressed.connect(_on_start_pressed)
	copy_button.pressed.connect(_on_copy_pressed)

	# Listen for networking events to update lobby state.
	Events.connection_established.connect(_on_connection_established)
	Events.player_joined.connect(_on_player_joined)
	Events.player_left.connect(_on_player_left)
	Events.connection_lost.connect(_on_connection_lost)


# ── Button Handlers ────────────────────────────────────────────────────────────

func _on_host_pressed() -> void:
	var error := NetworkManager.host_game()
	if error != OK:
		status_label.text = "Failed to host: %s" % error_string(error)
		return

	_is_host = true
	_connected_player_count = 1  # Host counts as first player.
	var ip := NetworkManager.get_local_ip()
	_room_code = NetworkManager.ip_to_room_code(ip)
	room_code_label.text = "Room Code:  %s" % _room_code
	room_code_container.visible = true
	status_label.text = "Waiting for players..."

	# Disable host/join buttons once hosting.
	host_button.disabled = true
	join_button.disabled = true
	address_input.editable = false


func _on_join_pressed() -> void:
	var input_text := address_input.text.strip_edges()
	if input_text.is_empty():
		status_label.text = "Enter a room code or IP address."
		return

	var ip: String
	var port: int = NetworkManager.DEFAULT_PORT

	# If it contains a dot, treat as IP address. Otherwise, treat as room code.
	if "." in input_text:
		var parts := input_text.split(":")
		ip = parts[0]
		if parts.size() > 1:
			port = parts[1].to_int()
	else:
		ip = NetworkManager.room_code_to_ip(input_text)
		if ip.is_empty():
			status_label.text = "Invalid room code. Try again."
			return

	var error := NetworkManager.join_game(ip, port)
	if error != OK:
		status_label.text = "Failed to join: %s" % error_string(error)
		return

	status_label.text = "Connecting..."
	host_button.disabled = true
	join_button.disabled = true
	address_input.editable = false


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(_room_code)
	copy_button.text = "Copied!"
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(copy_button):
		copy_button.text = "Copy"


func _on_start_pressed() -> void:
	# Only the host triggers the scene change.
	if not _is_host:
		return
	# Tell all clients to change scene, then change locally.
	_change_scene_all_peers.rpc("res://scenes/game.tscn")


@rpc("authority", "call_local", "reliable")
func _change_scene_all_peers(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


# ── Event Handlers ─────────────────────────────────────────────────────────────

func _on_connection_established(_peer_id: int, is_host: bool) -> void:
	if not is_host:
		status_label.text = "Connected to server!"
		_connected_player_count = 1  # We'll get accurate count from player_joined signals.


func _on_player_joined(_player_id: int, _spawn_position: Vector2) -> void:
	_connected_player_count += 1
	_update_lobby_status()


func _on_player_left(_player_id: int) -> void:
	_connected_player_count = maxi(_connected_player_count - 1, 1)
	_update_lobby_status()


func _on_connection_lost(_peer_id: int, reason: String) -> void:
	status_label.text = "Connection lost: %s" % reason
	start_button.visible = false
	room_code_container.visible = false
	_room_code = ""
	host_button.disabled = false
	join_button.disabled = false
	address_input.editable = true
	_connected_player_count = 0
	_is_host = false


# ── Helpers ────────────────────────────────────────────────────────────────────

func _update_lobby_status() -> void:
	status_label.text = "Players connected: %d" % _connected_player_count
	# Show start button only for the host when at least 2 players are present.
	start_button.visible = _is_host and _connected_player_count >= 2
