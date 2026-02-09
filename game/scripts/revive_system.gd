## ReviveSystem -- child Node of Player, handles hold-to-revive logic.
## Server-authoritative. Rescuer holds interact near a downed player to revive them.
extends Node

const REVIVE_RANGE: float = 80.0
const REVIVE_TIME: float = 3.0
const REVIVE_HEALTH: int = 50
const REVIVE_SPEED_MULT: float = 0.5

var _revive_target: CharacterBody2D = null
var _revive_progress: float = 0.0
var _is_reviving: bool = false


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	var player = get_parent()
	if not player._is_alive or player._is_downed:
		if _is_reviving:
			_cancel_revive()
		return

	if player.input_interact:
		if not _is_reviving:
			_try_start_revive(player)
		else:
			_continue_revive(player, delta)
	else:
		if _is_reviving:
			_cancel_revive()


func _try_start_revive(rescuer: CharacterBody2D) -> void:
	var target := _find_downed_player_in_range(rescuer)
	if not target:
		return
	_revive_target = target
	_revive_progress = 0.0
	_is_reviving = true
	rescuer._is_reviving_someone = true
	Events.revive_started.emit(rescuer.player_id, target.player_id)
	_notify_revive_progress.rpc(rescuer.player_id, target.player_id, 0.0)


func _continue_revive(rescuer: CharacterBody2D, delta: float) -> void:
	if not is_instance_valid(_revive_target) or not _revive_target._is_downed:
		_cancel_revive()
		return
	if rescuer.global_position.distance_to(_revive_target.global_position) > REVIVE_RANGE:
		_cancel_revive()
		return

	_revive_progress += delta
	var progress_pct := _revive_progress / REVIVE_TIME
	Events.revive_progress.emit(rescuer.player_id, _revive_target.player_id, progress_pct)
	_notify_revive_progress.rpc(rescuer.player_id, _revive_target.player_id, progress_pct)

	if _revive_progress >= REVIVE_TIME:
		_complete_revive(rescuer)


func _complete_revive(rescuer: CharacterBody2D) -> void:
	if not is_instance_valid(_revive_target):
		_cancel_revive()
		return

	_revive_target.health = REVIVE_HEALTH
	_revive_target._is_downed = false
	_revive_target._is_alive = true
	_revive_target._bleedout_timer = 0.0

	# Re-enable collision
	var collision = _revive_target.get_node_or_null("CollisionShape2D")
	if collision:
		collision.set_deferred("disabled", false)

	# Restore color based on role
	var ability_mgr = _revive_target.get_node_or_null("AbilityManager")
	var color_rect = _revive_target.get_node_or_null("ColorRect") as ColorRect
	if color_rect and ability_mgr:
		if ability_mgr.role == "engineer":
			color_rect.color = Color(0.2, 0.8, 0.3, 1.0)
		else:
			color_rect.color = Color(1.0, 0.6, 0.1, 1.0)

	Events.revive_completed.emit(rescuer.player_id, _revive_target.player_id)
	_notify_revive_progress.rpc(rescuer.player_id, _revive_target.player_id, 1.0)
	print("ReviveSystem: Player %d revived player %d" % [rescuer.player_id, _revive_target.player_id])

	rescuer._is_reviving_someone = false
	_revive_target = null
	_revive_progress = 0.0
	_is_reviving = false


func _cancel_revive() -> void:
	var player = get_parent()
	if _is_reviving and is_instance_valid(_revive_target):
		Events.revive_cancelled.emit(player.player_id, _revive_target.player_id)
	player._is_reviving_someone = false
	_revive_target = null
	_revive_progress = 0.0
	_is_reviving = false


func _find_downed_player_in_range(rescuer: CharacterBody2D) -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("players")
	var nearest: CharacterBody2D = null
	var nearest_dist: float = INF

	for player in players:
		if player == rescuer:
			continue
		if not player._is_downed:
			continue
		var dist := rescuer.global_position.distance_to(player.global_position)
		if dist <= REVIVE_RANGE and dist < nearest_dist:
			nearest_dist = dist
			nearest = player

	return nearest


@rpc("authority", "call_local", "unreliable")
func _notify_revive_progress(rescuer_id: int, target_id: int, progress: float) -> void:
	# Clients can use this to display a revive progress bar
	pass
