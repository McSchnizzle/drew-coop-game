## Enemy script — "Merge Conflict" enemy that chases the nearest player.
## All game logic runs on the server (host) only.
## Position is synced to clients via MultiplayerSynchronizer on the scene.
extends CharacterBody2D

var enemy_id: int = 0
var health: int = 3
var speed: float = 50.0
var _is_alive: bool = true


func _ready() -> void:
	add_to_group("enemies")


func _physics_process(delta: float) -> void:
	if not _is_alive:
		return

	# Only the server controls enemy movement.
	if not multiplayer.is_server():
		return

	var target := _find_nearest_player()
	if target:
		var direction := (target.global_position - global_position).normalized()
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()


## Finds the nearest living player by checking the "players" group.
func _find_nearest_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("players")
	var nearest: Node2D = null
	var nearest_dist: float = INF

	for player in players:
		if not player is Node2D:
			continue
		# Skip dead players.
		if player.has_method("is_alive") and not player.is_alive():
			continue
		if not player.visible:
			continue

		var dist := global_position.distance_to(player.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = player

	return nearest


## Called when this enemy takes damage. Only meaningful on the server.
func take_damage(amount: int, from_player_id: int) -> void:
	if not _is_alive:
		return
	if not multiplayer.is_server():
		return

	health -= amount
	if health <= 0:
		health = 0
		_die(from_player_id)


func _die(killed_by: int) -> void:
	_is_alive = false
	velocity = Vector2.ZERO
	# Golden path: no split mechanic yet, so clean_kill is always false.
	Events.enemy_died.emit(enemy_id, killed_by, false)
	queue_free()
