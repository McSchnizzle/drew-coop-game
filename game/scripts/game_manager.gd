## Game manager -- attached to the root node of game.tscn.
## Handles spawning players and delegating enemy spawning to wave_manager.
## Only the host (server) performs spawning; MultiplayerSpawner replicates to clients.
extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

# Spawn positions for up to 4 players (3D arena centered at origin).
const PLAYER_SPAWN_POSITIONS: Array[Vector3] = [
	Vector3(-5, 0, 0),
	Vector3(5, 0, 0),
	Vector3(-5, 0, 5),
	Vector3(5, 0, 5),
]

# Enemy ID counter (starts at 1000 per entity_schema.md).
var _next_enemy_id: int = 1000

# Floating "Repo Owner" label — Label3D child of host player in 3D space.
var _repo_owner_label: Label3D


func _ready() -> void:
	# Connect end screen return button (all peers need this).
	var return_btn = get_node_or_null("UI/HUD/EndScreen/VBoxContainer/ReturnButton")
	if return_btn:
		return_btn.pressed.connect(_on_return_button_pressed)

	# Show migration announcement on all peers (before server-only guard).
	if NetworkManager.is_migrating:
		_show_migration_announcement(multiplayer.is_server())

	if not multiplayer.is_server():
		return

	# Start periodic snapshot timer (sends state to clients for host migration).
	_start_snapshot_timer()

	# Listen for peers connecting/disconnecting.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if NetworkManager.is_migrating:
		_restore_from_migration()
		return

	# Spawn a player for the host.
	_spawn_player(1)

	# Spawn players for any peers already connected (joined before scene loaded).
	for peer_id in multiplayer.get_peers():
		_spawn_player(peer_id)

	# Start waves (WaveManager is a scene node in game.tscn, exists on all peers).
	$WaveManager.start_waves()

	# Send first snapshot immediately so clients can migrate right away.
	_snapshot_timer_tick()


func _on_peer_connected(id: int) -> void:
	if NetworkManager.is_migrating:
		return
	_spawn_player(id)


func _on_peer_disconnected(id: int) -> void:
	var players_node = $Players
	for child in players_node.get_children():
		if child.name == str(id):
			child.queue_free()
			break


# ── Repo Owner Label (Label3D billboard above host player) ────────────────

func _create_repo_owner_label(host_player: Node3D) -> void:
	_repo_owner_label = Label3D.new()
	_repo_owner_label.text = "Repo Owner"
	_repo_owner_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_repo_owner_label.position = Vector3(0, 2.5, 0)
	_repo_owner_label.font_size = 48
	_repo_owner_label.modulate = Color(0.3, 0.9, 1.0)
	_repo_owner_label.outline_modulate = Color(0, 0, 0)
	_repo_owner_label.outline_size = 6
	host_player.add_child(_repo_owner_label)


func _input(event: InputEvent) -> void:
	var end_screen = get_node_or_null("UI/HUD/EndScreen")
	if not end_screen or not end_screen.visible:
		return

	# Controller: any face button or ui_accept action returns to lobby
	var should_return := false
	if event is InputEventJoypadButton and event.pressed:
		should_return = true
	elif event.is_action_pressed("ui_accept"):
		should_return = true

	if should_return:
		_on_return_button_pressed()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# Hide label when end screen is showing
	if _repo_owner_label and is_instance_valid(_repo_owner_label):
		var end_screen = get_node_or_null("UI/HUD/EndScreen")
		if end_screen and end_screen.visible:
			_repo_owner_label.visible = false
		else:
			_repo_owner_label.visible = true


# ── Public API ──────────────────────────────────────────────────────────

func next_enemy_id() -> int:
	var id := _next_enemy_id
	_next_enemy_id += 1
	return id


# ── Return to Lobby ─────────────────────────────────────────────────────

var _returning: bool = false


func _on_return_button_pressed() -> void:
	if multiplayer.is_server():
		_return_to_lobby()
	else:
		_request_early_return.rpc_id(1)


func _return_to_lobby() -> void:
	if _returning:
		return
	if not multiplayer.is_server():
		return
	_returning = true
	NetworkManager.is_returning_to_lobby = true
	_return_all_peers_to_lobby.rpc()


@rpc("authority", "call_local", "reliable")
func _return_all_peers_to_lobby() -> void:
	NetworkManager.is_returning_to_lobby = true
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


@rpc("any_peer", "reliable")
func _request_early_return() -> void:
	if multiplayer.is_server():
		_return_to_lobby()


# ── Player Spawning ──────────────────────────────────────────────────────

func _spawn_player(peer_id: int) -> void:
	var player = PLAYER_SCENE.instantiate()

	player.name = str(peer_id)

	var spawn_index: int = 0
	if peer_id != 1:
		spawn_index = clampi(multiplayer.get_peers().find(peer_id) + 1, 1, PLAYER_SPAWN_POSITIONS.size() - 1)

	player.position = PLAYER_SPAWN_POSITIONS[spawn_index]

	var role: String = NetworkManager.role_assignments.get(peer_id, "striker")

	$Players.add_child(player, true)

	player.player_id = peer_id

	player._set_role_color.rpc(role)

	_setup_player_abilities(player, role)

	# Add Repo Owner label above host player on all peers
	if peer_id == 1:
		_create_repo_owner_label(player)

	Events.player_joined.emit(peer_id, player.position)
	Events.role_assigned.emit(peer_id, role)
	print("GameManager: Spawned player for peer %d as %s at %s" % [peer_id, role, player.position])


# ── Role / Ability Setup ────────────────────────────────────────────────

func _setup_player_abilities(player: CharacterBody3D, role: String) -> void:
	var ability_mgr = player.get_node_or_null("AbilityManager")
	if not ability_mgr:
		return

	ability_mgr.role = role

	var ability_node := Node.new()
	ability_node.name = "Ability"
	if role == "striker":
		ability_node.set_script(load("res://scripts/abilities/ability_weak_point_scan.gd"))
	elif role == "engineer":
		ability_node.set_script(load("res://scripts/abilities/ability_deploy_turret.gd"))
	ability_mgr.add_child(ability_node)

	var super_node := Node.new()
	super_node.name = "Super"
	if role == "striker":
		super_node.set_script(load("res://scripts/abilities/super_overdrive.gd"))
	elif role == "engineer":
		super_node.set_script(load("res://scripts/abilities/super_healing_pulse.gd"))
	ability_mgr.add_child(super_node)


# ── Host Migration: Snapshot & Restoration ─────────────────────────────

func _start_snapshot_timer() -> void:
	var timer := Timer.new()
	timer.name = "SnapshotTimer"
	timer.wait_time = 3.0
	timer.autostart = true
	timer.timeout.connect(_snapshot_timer_tick)
	add_child(timer)


func _snapshot_timer_tick() -> void:
	if not multiplayer.is_server():
		return
	var snapshot := _build_snapshot()
	NetworkManager.send_snapshot(snapshot)


func _build_snapshot() -> Dictionary:
	var snapshot := {}
	snapshot["wave"] = $WaveManager.current_wave
	snapshot["game_time"] = $WaveManager._game_time

	var players_data := {}
	for player in get_tree().get_nodes_in_group("players"):
		if not player.name.is_valid_int():
			continue
		var pid: int = player.name.to_int()
		var display_name: String = NetworkManager.player_names.get(pid, "Player %d" % pid)
		var role: String = NetworkManager.role_assignments.get(pid, "striker")
		players_data[display_name] = {
			"role": role,
			"health": player.health,
			"super_charge": player.super_charge,
			"is_downed": player._is_downed,
		}

	snapshot["players"] = players_data
	return snapshot


func _restore_from_migration() -> void:
	print("GameManager: Restoring from migration snapshot...")

	Events.migration_player_registered.connect(_on_migration_player_registered)

	_spawn_player(1)
	var player_node = $Players.get_node_or_null("1")
	if player_node:
		_apply_snapshot_to_player(player_node, NetworkManager._my_display_name)

	var snapshot: Dictionary = NetworkManager._cached_snapshot
	var wave_num: int = snapshot.get("wave", 1)
	var game_time: float = snapshot.get("game_time", 0.0)
	$WaveManager.restore_wave(wave_num, game_time)

	get_tree().create_timer(5.0).timeout.connect(func():
		NetworkManager.is_migrating = false
		NetworkManager._host_migration_active = false
		print("GameManager: Migration complete!")
	)


func _on_migration_player_registered(peer_id: int) -> void:
	_spawn_player(peer_id)
	var display_name: String = NetworkManager.player_names.get(peer_id, "")
	var player_node = $Players.get_node_or_null(str(peer_id))
	if player_node:
		_apply_snapshot_to_player(player_node, display_name)


func _apply_snapshot_to_player(player_node: CharacterBody3D, display_name: String) -> void:
	var snapshot: Dictionary = NetworkManager._cached_snapshot
	if not snapshot.has("players"):
		return
	var pdata: Dictionary = snapshot["players"].get(display_name, {})
	if pdata.is_empty():
		return
	player_node.health = pdata.get("health", 3)
	player_node.super_charge = pdata.get("super_charge", 0.0)
	if pdata.get("is_downed", false):
		player_node._is_downed = true
		player_node._bleedout_timer = 15.0


func _show_migration_announcement(is_promoted: bool) -> void:
	var hud = get_node_or_null("UI/HUD")
	if not hud:
		return

	var overlay := ColorRect.new()
	overlay.name = "MigrationOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(overlay)

	var container := VBoxContainer.new()
	container.name = "MigrationAnnounce"
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.offset_left = -300.0
	container.offset_top = -60.0
	container.offset_right = 300.0
	container.offset_bottom = 60.0
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(container)

	var title_label := Label.new()
	title_label.text = "RO disconnected"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	container.add_child(title_label)

	var status_label := Label.new()
	if is_promoted:
		status_label.text = "You've been promoted to Repo Owner!"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	else:
		status_label.text = "Reconnected to new Repo Owner"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 20)
	container.add_child(status_label)

	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(overlay):
			overlay.queue_free()
		if is_instance_valid(container):
			container.queue_free()
	)
