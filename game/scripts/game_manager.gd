## Game manager -- attached to the root node of game.tscn.
## Handles spawning players and delegating enemy spawning to wave_manager.
## Only the host (server) performs spawning; MultiplayerSpawner replicates to clients.
extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

# Spawn positions for up to 4 players (golden path uses 2).
const PLAYER_SPAWN_POSITIONS: Array[Vector2] = [
	Vector2(200, 500),
	Vector2(400, 500),
	Vector2(300, 500),
	Vector2(500, 500),
]

# Enemy ID counter (starts at 1000 per entity_schema.md).
var _next_enemy_id: int = 1000


func _ready() -> void:
	# Connect end screen return button (all peers need this).
	var return_btn = get_node_or_null("UI/HUD/EndScreen/VBoxContainer/ReturnButton")
	if return_btn:
		return_btn.pressed.connect(_on_return_button_pressed)

	if not multiplayer.is_server():
		return

	# Spawn a player for the host.
	_spawn_player(1)

	# Spawn players for any peers already connected (joined before scene loaded).
	for peer_id in multiplayer.get_peers():
		_spawn_player(peer_id)

	# Listen for late-joining peers.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Start waves (WaveManager is a scene node in game.tscn, exists on all peers).
	$WaveManager.start_waves()


func _on_peer_connected(id: int) -> void:
	_spawn_player(id)


func _on_peer_disconnected(id: int) -> void:
	# Remove the player node when they disconnect.
	var players_node = $Players
	for child in players_node.get_children():
		if child.name == str(id):
			child.queue_free()
			break


# ── Public API ──────────────────────────────────────────────────────────────

func next_enemy_id() -> int:
	var id := _next_enemy_id
	_next_enemy_id += 1
	return id


# ── Return to Lobby ─────────────────────────────────────────────────────────

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


# ── Player Spawning ──────────────────────────────────────────────────────────

func _spawn_player(peer_id: int) -> void:
	var player = PLAYER_SCENE.instantiate()

	# Use peer_id as node name so MultiplayerSpawner can identify it uniquely.
	player.name = str(peer_id)

	# Determine spawn index (host = 0, first client = 1, etc.).
	var spawn_index: int = 0
	if peer_id != 1:
		spawn_index = clampi(multiplayer.get_peers().find(peer_id) + 1, 1, PLAYER_SPAWN_POSITIONS.size() - 1)

	player.position = PLAYER_SPAWN_POSITIONS[spawn_index]

	var role: String = NetworkManager.role_assignments.get(peer_id, "striker")

	# Add to the Players container (MultiplayerSpawner handles replication).
	$Players.add_child(player, true)

	# Set player_id AFTER adding to tree so the setter can find $InputSync.
	player.player_id = peer_id

	# Set role color + label on ALL peers via RPC (must be after add_child so node exists).
	player._set_role_color.rpc(role)

	# Set up abilities based on role
	_setup_player_abilities(player, role)

	Events.player_joined.emit(peer_id, player.position)
	Events.role_assigned.emit(peer_id, role)
	print("GameManager: Spawned player for peer %d as %s at %s" % [peer_id, role, player.position])


# ── Role / Ability Setup ────────────────────────────────────────────────────

func _setup_player_abilities(player: CharacterBody2D, role: String) -> void:
	var ability_mgr = player.get_node_or_null("AbilityManager")
	if not ability_mgr:
		return

	ability_mgr.role = role

	# Create Ability child node
	var ability_node := Node.new()
	ability_node.name = "Ability"
	if role == "striker":
		ability_node.set_script(load("res://scripts/abilities/ability_weak_point_scan.gd"))
	elif role == "engineer":
		ability_node.set_script(load("res://scripts/abilities/ability_deploy_turret.gd"))
	ability_mgr.add_child(ability_node)

	# Create Super child node
	var super_node := Node.new()
	super_node.name = "Super"
	if role == "striker":
		super_node.set_script(load("res://scripts/abilities/super_overdrive.gd"))
	elif role == "engineer":
		super_node.set_script(load("res://scripts/abilities/super_healing_pulse.gd"))
	ability_mgr.add_child(super_node)
