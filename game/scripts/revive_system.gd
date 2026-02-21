## ReviveSystem -- child Node of Player, handles hold-to-revive logic.
## Server-authoritative. Rescuer holds interact near a downed player to revive them.
extends Node

const REVIVE_RANGE: float = 4.0  # 80px / 20
const REVIVE_TIME: float = 3.0
const REVIVE_HEALTH: int = 50
const REVIVE_SPEED_MULT: float = 0.5

var _revive_target: CharacterBody3D = null
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


func _try_start_revive(rescuer: CharacterBody3D) -> void:
	var target := _find_downed_player_in_range(rescuer)
	if not target:
		return
	_revive_target = target
	_revive_progress = 0.0
	_is_reviving = true
	rescuer._is_reviving_someone = true

	# Face and snap close to the downed player so the kneeling animation looks right
	_face_target(rescuer, target)
	var dist := rescuer.global_position.distance_to(target.global_position)
	if dist > 1.5:
		var dir := (target.global_position - rescuer.global_position).normalized()
		rescuer.global_position = target.global_position - dir * 1.5

	rescuer._play_oneshot_anim.rpc("Revive", REVIVE_TIME)
	Events.revive_started.emit(rescuer.player_id, target.player_id)
	_notify_revive_progress.rpc(target.player_id, 0.0)


func _continue_revive(rescuer: CharacterBody3D, delta: float) -> void:
	if not is_instance_valid(_revive_target) or not _revive_target._is_downed:
		_cancel_revive()
		return
	if rescuer.global_position.distance_to(_revive_target.global_position) > REVIVE_RANGE:
		_cancel_revive()
		return

	# Keep rescuer facing the downed player
	_face_target(rescuer, _revive_target)

	_revive_progress += delta
	var progress_pct := _revive_progress / REVIVE_TIME
	Events.revive_progress.emit(rescuer.player_id, _revive_target.player_id, progress_pct)
	_notify_revive_progress.rpc(_revive_target.player_id, progress_pct)

	if _revive_progress >= REVIVE_TIME:
		_complete_revive(rescuer)


func _complete_revive(rescuer: CharacterBody3D) -> void:
	if not is_instance_valid(_revive_target):
		_cancel_revive()
		return

	_revive_target.health = REVIVE_HEALTH
	_revive_target._is_downed = false
	_revive_target._is_alive = true
	_revive_target._bleedout_timer = 0.0

	# Re-enable collision
	var collision = _revive_target.get_node_or_null("CollisionShape3D")
	if collision:
		collision.set_deferred("disabled", false)

	# Restore color on ALL peers via RPC
	var ability_mgr = _revive_target.get_node_or_null("AbilityManager")
	var role: String = ability_mgr.role if ability_mgr else "striker"
	_revive_target._show_revived_visual.rpc(role)
	_revive_target._play_oneshot_anim.rpc("GetUp", 1.5)

	Events.revive_completed.emit(rescuer.player_id, _revive_target.player_id)
	# Send progress=1.0 so clients hide the bar, then -1.0 to clean up
	_notify_revive_progress.rpc(_revive_target.player_id, -1.0)
	print("ReviveSystem: Player %d revived player %d" % [rescuer.player_id, _revive_target.player_id])

	rescuer._is_reviving_someone = false
	_revive_target = null
	_revive_progress = 0.0
	_is_reviving = false


func _cancel_revive() -> void:
	var player = get_parent()
	if _is_reviving and is_instance_valid(_revive_target):
		Events.revive_cancelled.emit(player.player_id, _revive_target.player_id)
		_notify_revive_progress.rpc(_revive_target.player_id, -1.0)
	player._is_reviving_someone = false
	_revive_target = null
	_revive_progress = 0.0
	_is_reviving = false


func _face_target(rescuer: CharacterBody3D, target: CharacterBody3D) -> void:
	var to_target := target.global_position - rescuer.global_position
	to_target.y = 0.0
	if to_target.length() > 0.01:
		rescuer.rotation.y = atan2(to_target.x, to_target.z)


func _find_downed_player_in_range(rescuer: CharacterBody3D) -> CharacterBody3D:
	var players := get_tree().get_nodes_in_group("players")
	var nearest: CharacterBody3D = null
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
func _notify_revive_progress(target_id: int, progress: float) -> void:
	# Find the target player and show/update a progress indicator above them.
	var players := get_tree().get_nodes_in_group("players")
	for player in players:
		if player.player_id == target_id:
			_update_revive_bar(player, progress)
			break


func _update_revive_bar(target: CharacterBody3D, progress: float) -> void:
	if not is_instance_valid(target):
		return
	var label = target.get_node_or_null("ReviveBar")

	# progress < 0 means cancel/complete — remove the bar.
	if progress < 0.0:
		if label:
			label.queue_free()
		return

	# Create Label3D billboard if it doesn't exist.
	if not label:
		label = Label3D.new()
		label.name = "ReviveBar"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0, 2.5, 0)  # Above head
		label.font_size = 32
		label.modulate = Color(0.2, 1.0, 0.2, 1.0)
		label.no_depth_test = true
		target.add_child(label)

	label.text = "REVIVING %d%%" % int(progress * 100.0)
