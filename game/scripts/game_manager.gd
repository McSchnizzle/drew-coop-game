## Game manager — attached to the root node of game.tscn.
## Handles spawning players and a test enemy when the game scene loads.
## Only the host (server) performs spawning; MultiplayerSpawner replicates to clients.
extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")

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

	# Spawn one test enemy on the right side of the level.
	_spawn_test_enemy()


func _on_peer_connected(id: int) -> void:
	_spawn_player(id)


func _on_peer_disconnected(id: int) -> void:
	# Remove the player node when they disconnect.
	var players_node = $Players
	for child in players_node.get_children():
		if child.name == str(id):
			child.queue_free()
			break


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

	# Set player color based on host vs client.
	var color_rect = player.get_node("ColorRect") as ColorRect
	if color_rect:
		color_rect.color = COLOR_HOST if peer_id == 1 else COLOR_CLIENT

	# Add to the Players container (MultiplayerSpawner handles replication).
	$Players.add_child(player, true)

	# Set player_id AFTER adding to tree so the setter can find $InputSync.
	player.player_id = peer_id

	Events.player_joined.emit(peer_id, player.position)
	print("GameManager: Spawned player for peer %d at %s" % [peer_id, player.position])


# ── Enemy Spawning ───────────────────────────────────────────────────────────

func _spawn_test_enemy() -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.enemy_id = _next_enemy_id
	_next_enemy_id += 1

	# Use enemy_id as node name for unique identification.
	enemy.name = "Enemy_%d" % enemy.enemy_id

	# Spawn on the right side of the level.
	enemy.position = Vector2(900, 500)

	$Enemies.add_child(enemy, true)

	Events.enemy_spawned.emit(enemy.enemy_id, "merge_conflict", enemy.position)
	print("GameManager: Spawned test enemy at %s" % enemy.position)
