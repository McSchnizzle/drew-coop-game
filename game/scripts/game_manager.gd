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

# Colors: peer 1 = Blue, others = White (Drew's preference).
const COLOR_HOST := Color(0.2, 0.4, 1.0, 1.0)   # Blue
const COLOR_CLIENT := Color(1.0, 1.0, 1.0, 1.0)  # White

# Enemy ID counter (starts at 1000 per entity_schema.md).
var _next_enemy_id: int = 1000

# Wave manager (server creates at runtime).
var _wave_manager: Node = null



func _ready() -> void:
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

	# Create and start the wave system.
	_setup_wave_manager()


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

	# Set player color based on role or host/client default.
	var role: String = NetworkManager.role_assignments.get(peer_id, "striker")
	var color_rect = player.get_node("ColorRect") as ColorRect
	if color_rect:
		if role == "engineer":
			color_rect.color = Color(0.2, 0.8, 0.3, 1.0)
		elif role == "striker":
			color_rect.color = Color(1.0, 0.6, 0.1, 1.0)
		else:
			color_rect.color = COLOR_HOST if peer_id == 1 else COLOR_CLIENT

	# Add to the Players container (MultiplayerSpawner handles replication).
	$Players.add_child(player, true)

	# Set player_id AFTER adding to tree so the setter can find $InputSync.
	player.player_id = peer_id

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


# ── Wave System Setup ────────────────────────────────────────────────────────

func _setup_wave_manager() -> void:
	var wave_manager_script = load("res://scripts/wave_manager.gd")
	_wave_manager = Node.new()
	_wave_manager.name = "WaveManager"
	_wave_manager.set_script(wave_manager_script)
	add_child(_wave_manager)
	_wave_manager.start_waves()
