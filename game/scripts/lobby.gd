## Lobby scene logic -- host/join UI, role selection, and game start flow.
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
@onready var striker_button: Button = %StrikerButton
@onready var engineer_button: Button = %EngineerButton
@onready var role_label: Label = %RoleLabel
@onready var name_input: LineEdit = %NameInput
@onready var leave_button: Button = %LeaveButton
@onready var version_label: Label = %VersionLabel

var _lobby_stage_3d: Node3D

const TEXT_PRIMARY := Color(0.910, 0.910, 0.941, 1)
const TEXT_SECONDARY := Color(0.690, 0.690, 0.753, 1)
const TEXT_DISABLED := Color(0.376, 0.376, 0.439, 1)
const MAX_PLAYERS := 4
var _connected_player_count: int = 0
var _is_host: bool = false
var _room_code: String = ""
var _selected_role: String = "striker"

# StyleBoxFlat resources for role button active states
var _striker_active_style: StyleBoxFlat
var _engineer_active_style: StyleBoxFlat


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_button.pressed.connect(_on_start_pressed)
	copy_button.pressed.connect(_on_copy_pressed)
	striker_button.pressed.connect(_on_striker_pressed)
	engineer_button.pressed.connect(_on_engineer_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	name_input.text_changed.connect(_on_name_changed)

	# Listen for networking events to update lobby state.
	Events.connection_established.connect(_on_connection_established)
	Events.player_joined.connect(_on_player_joined)
	Events.player_left.connect(_on_player_left)
	Events.connection_lost.connect(_on_connection_lost)

	# Grab the 3D lobby stage from the SubViewport
	var viewport := get_node("StageViewportContainer/SubViewport")
	_lobby_stage_3d = viewport.get_node("LobbyStage3D")

	# Apply theme styling and build role active styles
	_setup_theme()

	if NetworkManager.is_returning_to_lobby:
		_setup_returning_lobby()
		NetworkManager.is_returning_to_lobby = false
	else:
		_setup_fresh_lobby()

	_update_role_buttons()
	_rebuild_player_stage()
	_load_version()


func _setup_fresh_lobby() -> void:
	start_button.visible = false
	room_code_container.visible = false
	leave_button.visible = false
	status_label.text = "Ready to host or join."
	role_label.text = "Role: Striker"


func _setup_returning_lobby() -> void:
	_is_host = multiplayer.is_server()
	_connected_player_count = NetworkManager.role_assignments.size()

	# Recover this peer's selected role and name
	var my_id := multiplayer.get_unique_id()
	_selected_role = NetworkManager.role_assignments.get(my_id, "striker")
	role_label.text = "Role: %s" % _selected_role.capitalize()
	var my_name: String = NetworkManager.player_names.get(my_id, "")
	if not my_name.is_empty():
		name_input.text = my_name

	# Already connected — hide host/join controls to keep panel compact
	host_button.visible = false
	join_button.get_parent().visible = false
	leave_button.visible = true

	if _is_host:
		var ip := NetworkManager.get_local_ip()
		_room_code = NetworkManager.ip_to_room_code(ip)
		room_code_label.text = "Room Code:  %s" % _room_code
		room_code_container.visible = true
		start_button.visible = _connected_player_count >= 2
		status_label.text = "Players connected: %d" % _connected_player_count
	else:
		room_code_container.visible = false
		start_button.visible = false
		status_label.text = "Connected. Waiting for host to start..."


# ── Theme Setup ───────────────────────────────────────────────────────────────

func _setup_theme() -> void:
	# -- Button base styles (normal/hover/pressed/disabled) --
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.145, 0.145, 0.208, 1)
	btn_normal.border_color = Color(0.227, 0.227, 0.322, 1)
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(6)
	btn_normal.content_margin_left = 12.0
	btn_normal.content_margin_top = 6.0
	btn_normal.content_margin_right = 12.0
	btn_normal.content_margin_bottom = 6.0

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.188, 0.188, 0.282, 1)
	btn_hover.border_color = Color(0.290, 0.290, 0.408, 1)
	btn_hover.set_border_width_all(1)
	btn_hover.set_corner_radius_all(6)
	btn_hover.content_margin_left = 12.0
	btn_hover.content_margin_top = 6.0
	btn_hover.content_margin_right = 12.0
	btn_hover.content_margin_bottom = 6.0

	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.102, 0.102, 0.157, 1)
	btn_pressed.border_color = Color(0.227, 0.227, 0.322, 1)
	btn_pressed.set_border_width_all(1)
	btn_pressed.set_corner_radius_all(6)
	btn_pressed.content_margin_left = 12.0
	btn_pressed.content_margin_top = 6.0
	btn_pressed.content_margin_right = 12.0
	btn_pressed.content_margin_bottom = 6.0

	var btn_disabled := StyleBoxFlat.new()
	btn_disabled.bg_color = Color(0.102, 0.102, 0.133, 1)
	btn_disabled.border_color = Color(0.180, 0.180, 0.251, 1)
	btn_disabled.set_border_width_all(1)
	btn_disabled.set_corner_radius_all(6)
	btn_disabled.content_margin_left = 12.0
	btn_disabled.content_margin_top = 6.0
	btn_disabled.content_margin_right = 12.0
	btn_disabled.content_margin_bottom = 6.0

	# -- Action button styles (Host, Join, Start) --
	var action_normal := StyleBoxFlat.new()
	action_normal.bg_color = Color(0.231, 0.490, 0.847, 1)
	action_normal.border_color = Color(0.290, 0.569, 0.937, 1)
	action_normal.set_border_width_all(1)
	action_normal.set_corner_radius_all(6)
	action_normal.content_margin_left = 12.0
	action_normal.content_margin_top = 6.0
	action_normal.content_margin_right = 12.0
	action_normal.content_margin_bottom = 6.0

	var action_hover := StyleBoxFlat.new()
	action_hover.bg_color = Color(0.290, 0.569, 0.937, 1)
	action_hover.border_color = Color(0.380, 0.650, 1.0, 1)
	action_hover.set_border_width_all(1)
	action_hover.set_corner_radius_all(6)
	action_hover.content_margin_left = 12.0
	action_hover.content_margin_top = 6.0
	action_hover.content_margin_right = 12.0
	action_hover.content_margin_bottom = 6.0

	var action_pressed := StyleBoxFlat.new()
	action_pressed.bg_color = Color(0.180, 0.400, 0.730, 1)
	action_pressed.border_color = Color(0.231, 0.490, 0.847, 1)
	action_pressed.set_border_width_all(1)
	action_pressed.set_corner_radius_all(6)
	action_pressed.content_margin_left = 12.0
	action_pressed.content_margin_top = 6.0
	action_pressed.content_margin_right = 12.0
	action_pressed.content_margin_bottom = 6.0

	# -- LineEdit styles --
	var line_edit_normal := StyleBoxFlat.new()
	line_edit_normal.bg_color = Color(0.094, 0.094, 0.141, 1)
	line_edit_normal.border_color = Color(0.180, 0.180, 0.251, 1)
	line_edit_normal.set_border_width_all(1)
	line_edit_normal.set_corner_radius_all(6)
	line_edit_normal.content_margin_left = 10.0
	line_edit_normal.content_margin_top = 6.0
	line_edit_normal.content_margin_right = 10.0
	line_edit_normal.content_margin_bottom = 6.0

	var line_edit_focus := StyleBoxFlat.new()
	line_edit_focus.bg_color = Color(0.094, 0.094, 0.141, 1)
	line_edit_focus.border_color = Color(0.231, 0.490, 0.847, 1)
	line_edit_focus.set_border_width_all(2)
	line_edit_focus.set_corner_radius_all(6)
	line_edit_focus.content_margin_left = 10.0
	line_edit_focus.content_margin_top = 6.0
	line_edit_focus.content_margin_right = 10.0
	line_edit_focus.content_margin_bottom = 6.0

	# -- Apply action (blue accent) styles to Host, Join, Start, Copy buttons --
	for btn: Button in [host_button, join_button, start_button, copy_button]:
		btn.add_theme_stylebox_override("normal", action_normal)
		btn.add_theme_stylebox_override("hover", action_hover)
		btn.add_theme_stylebox_override("pressed", action_pressed)
		btn.add_theme_stylebox_override("disabled", btn_disabled)
		btn.add_theme_color_override("font_color", TEXT_PRIMARY)
		btn.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
		btn.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
		btn.add_theme_color_override("font_disabled_color", TEXT_DISABLED)

	# -- Apply base button styles to role buttons (Striker, Engineer) --
	for btn: Button in [striker_button, engineer_button]:
		btn.add_theme_stylebox_override("normal", btn_normal)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("pressed", btn_pressed)
		btn.add_theme_stylebox_override("disabled", btn_disabled)
		btn.add_theme_color_override("font_color", TEXT_PRIMARY)
		btn.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
		btn.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
		btn.add_theme_color_override("font_disabled_color", TEXT_DISABLED)

	# -- Striker active style (orange accent, applied when selected/disabled) --
	_striker_active_style = StyleBoxFlat.new()
	_striker_active_style.bg_color = Color(0.910, 0.530, 0.169, 0.2)
	_striker_active_style.border_color = Color(0.910, 0.530, 0.169, 1)
	_striker_active_style.set_border_width_all(2)
	_striker_active_style.set_corner_radius_all(6)
	_striker_active_style.content_margin_left = 12.0
	_striker_active_style.content_margin_top = 6.0
	_striker_active_style.content_margin_right = 12.0
	_striker_active_style.content_margin_bottom = 6.0

	# -- Engineer active style (green accent, applied when selected/disabled) --
	_engineer_active_style = StyleBoxFlat.new()
	_engineer_active_style.bg_color = Color(0.231, 0.769, 0.290, 0.2)
	_engineer_active_style.border_color = Color(0.231, 0.769, 0.290, 1)
	_engineer_active_style.set_border_width_all(2)
	_engineer_active_style.set_corner_radius_all(6)
	_engineer_active_style.content_margin_left = 12.0
	_engineer_active_style.content_margin_top = 6.0
	_engineer_active_style.content_margin_right = 12.0
	_engineer_active_style.content_margin_bottom = 6.0

	# -- Apply LineEdit styles to AddressInput --
	address_input.add_theme_stylebox_override("normal", line_edit_normal)
	address_input.add_theme_stylebox_override("focus", line_edit_focus)
	address_input.add_theme_color_override("font_color", TEXT_PRIMARY)
	address_input.add_theme_color_override("font_placeholder_color", TEXT_SECONDARY)

	# -- Apply semi-transparent style to ControlPanel --
	var control_panel := get_node_or_null("ControlPanel")
	if control_panel:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.071, 0.071, 0.094, 0.85)
		panel_style.border_color = Color(0.180, 0.180, 0.251, 0.5)
		panel_style.set_border_width_all(0)
		panel_style.border_width_top = 1
		panel_style.corner_radius_top_left = 12
		panel_style.corner_radius_top_right = 12
		control_panel.add_theme_stylebox_override("panel", panel_style)

	# -- Set font colors on labels --
	var title_label := get_node_or_null("TitleLabel")
	if title_label:
		title_label.add_theme_color_override("font_color", TEXT_PRIMARY)

	status_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	role_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	room_code_label.add_theme_color_override("font_color", TEXT_PRIMARY)

	# -- Leave button (red/danger style) --
	var leave_normal := StyleBoxFlat.new()
	leave_normal.bg_color = Color(0.698, 0.133, 0.133, 1)
	leave_normal.border_color = Color(0.831, 0.200, 0.200, 1)
	leave_normal.set_border_width_all(1)
	leave_normal.set_corner_radius_all(6)
	leave_normal.content_margin_left = 12.0
	leave_normal.content_margin_top = 6.0
	leave_normal.content_margin_right = 12.0
	leave_normal.content_margin_bottom = 6.0

	var leave_hover := StyleBoxFlat.new()
	leave_hover.bg_color = Color(0.831, 0.200, 0.200, 1)
	leave_hover.border_color = Color(0.933, 0.300, 0.300, 1)
	leave_hover.set_border_width_all(1)
	leave_hover.set_corner_radius_all(6)
	leave_hover.content_margin_left = 12.0
	leave_hover.content_margin_top = 6.0
	leave_hover.content_margin_right = 12.0
	leave_hover.content_margin_bottom = 6.0

	leave_button.add_theme_stylebox_override("normal", leave_normal)
	leave_button.add_theme_stylebox_override("hover", leave_hover)
	leave_button.add_theme_stylebox_override("pressed", btn_pressed)
	leave_button.add_theme_color_override("font_color", TEXT_PRIMARY)
	leave_button.add_theme_color_override("font_hover_color", TEXT_PRIMARY)


# ── Player Stage ──────────────────────────────────────────────────────────────

func _rebuild_player_stage() -> void:
	if not _lobby_stage_3d:
		return

	var roles: Dictionary = NetworkManager.role_assignments
	var names: Dictionary = NetworkManager.player_names

	# Show local player preview before hosting/joining
	if roles.is_empty():
		var preview_name := name_input.text.strip_edges()
		if preview_name.is_empty():
			preview_name = "You"
		roles = { 0: _selected_role }
		names = { 0: preview_name }

	_lobby_stage_3d.set_players(roles, names)


# ── Role Selection ────────────────────────────────────────────────────────────

func _on_striker_pressed() -> void:
	_selected_role = "striker"
	role_label.text = "Role: Striker"
	_update_role_buttons()
	Events.role_selected.emit(multiplayer.get_unique_id(), "striker")
	if multiplayer.multiplayer_peer != null:
		_request_role.rpc_id(1, "striker")
	_rebuild_player_stage()


func _on_engineer_pressed() -> void:
	_selected_role = "engineer"
	role_label.text = "Role: Engineer"
	_update_role_buttons()
	Events.role_selected.emit(multiplayer.get_unique_id(), "engineer")
	if multiplayer.multiplayer_peer != null:
		_request_role.rpc_id(1, "engineer")
	_rebuild_player_stage()


func _update_role_buttons() -> void:
	if _selected_role == "striker":
		striker_button.disabled = true
		engineer_button.disabled = false
		if _striker_active_style:
			striker_button.add_theme_stylebox_override("disabled", _striker_active_style)
		engineer_button.remove_theme_stylebox_override("disabled")
	else:
		striker_button.disabled = false
		engineer_button.disabled = true
		if _engineer_active_style:
			engineer_button.add_theme_stylebox_override("disabled", _engineer_active_style)
		striker_button.remove_theme_stylebox_override("disabled")


@rpc("any_peer", "call_local", "reliable")
func _request_role(role_name: String) -> void:
	if not multiplayer.is_server():
		return
	if role_name not in ["striker", "engineer"]:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1  # Local call from host
	NetworkManager.role_assignments[sender_id] = role_name
	# Sync ALL roles to ALL peers so everyone sees every player
	for pid in NetworkManager.role_assignments:
		_confirm_role.rpc(pid, NetworkManager.role_assignments[pid])
	print("Lobby: Player %d selected role '%s'" % [sender_id, role_name])


@rpc("authority", "call_local", "reliable")
func _confirm_role(player_id: int, role_name: String) -> void:
	NetworkManager.role_assignments[player_id] = role_name
	Events.role_assigned.emit(player_id, role_name)
	_rebuild_player_stage()


# ── Name Sync ─────────────────────────────────────────────────────────────────

func _on_name_changed(new_text: String) -> void:
	var display_name := new_text.strip_edges()
	if display_name.is_empty():
		display_name = "Player %d" % multiplayer.get_unique_id()
	NetworkManager.player_names[multiplayer.get_unique_id()] = display_name
	if multiplayer.multiplayer_peer != null:
		_request_name.rpc_id(1, display_name)
	_rebuild_player_stage()


@rpc("any_peer", "call_local", "reliable")
func _request_name(display_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	NetworkManager.player_names[sender_id] = display_name
	# Sync all names to all peers
	for pid in NetworkManager.player_names:
		_confirm_name.rpc(pid, NetworkManager.player_names[pid])


@rpc("authority", "call_local", "reliable")
func _confirm_name(player_id: int, display_name: String) -> void:
	NetworkManager.player_names[player_id] = display_name
	_rebuild_player_stage()


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

	# Hide host/join controls to keep panel compact
	host_button.visible = false
	join_button.get_parent().visible = false

	# Register host's role and name
	NetworkManager.role_assignments[1] = _selected_role
	var host_name := name_input.text.strip_edges()
	if host_name.is_empty():
		host_name = "Player 1"
	NetworkManager.player_names[1] = host_name
	leave_button.visible = true
	_rebuild_player_stage()


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
	host_button.visible = false
	join_button.get_parent().visible = false


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(_room_code)
	copy_button.text = "Copied!"
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(copy_button):
		copy_button.text = "Copy"


func _on_leave_pressed() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	NetworkManager.peer = null
	NetworkManager.role_assignments.clear()
	NetworkManager.player_names.clear()
	NetworkManager.is_returning_to_lobby = false

	# Reset to fresh lobby state
	_is_host = false
	_connected_player_count = 0
	_room_code = ""
	host_button.visible = true
	join_button.get_parent().visible = true
	leave_button.visible = false
	_setup_fresh_lobby()
	_rebuild_player_stage()


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
		leave_button.visible = true
		# Send role and name to server
		_request_role.rpc_id(1, _selected_role)
		var my_name := name_input.text.strip_edges()
		if my_name.is_empty():
			my_name = "Player %d" % multiplayer.get_unique_id()
		_request_name.rpc_id(1, my_name)
	_rebuild_player_stage()


func _on_player_joined(_player_id: int, _spawn_position: Vector2) -> void:
	_connected_player_count += 1
	_update_lobby_status()
	_rebuild_player_stage()


func _on_player_left(_player_id: int) -> void:
	_connected_player_count = maxi(_connected_player_count - 1, 1)
	_update_lobby_status()
	_rebuild_player_stage()


func _on_connection_lost(_peer_id: int, reason: String) -> void:
	if reason == "peer_disconnected":
		# A single peer left — don't reset the whole lobby.
		# NetworkManager already erased their role_assignment.
		if multiplayer.is_server():
			_connected_player_count = NetworkManager.role_assignments.size()
			_update_lobby_status()
			_rebuild_player_stage()
		return

	# Server disconnected or connection failed — full reset.
	status_label.text = "Connection lost: %s" % reason
	start_button.visible = false
	room_code_container.visible = false
	leave_button.visible = false
	_room_code = ""
	host_button.visible = true
	join_button.get_parent().visible = true
	_connected_player_count = 0
	_is_host = false
	_rebuild_player_stage()


# ── Helpers ────────────────────────────────────────────────────────────────────

func _load_version() -> void:
	var config := ConfigFile.new()
	if config.load("res://version.cfg") == OK:
		var ver: String = config.get_value("version", "version", "0.0.0")
		version_label.text = "v%s" % ver
	else:
		version_label.text = ""


func _update_lobby_status() -> void:
	status_label.text = "Players connected: %d" % _connected_player_count
	# Show start button only for the host when at least 2 players are present.
	start_button.visible = _is_host and _connected_player_count >= 2
