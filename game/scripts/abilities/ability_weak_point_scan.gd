## Weak Point Scan -- Striker ability.
## Marks all enemies within radius as "exposed" (take 2x damage).
## Runs on server only as child of AbilityManager.
extends Node

const COOLDOWN: float = 12.0
const SCAN_RADIUS: float = 300.0
const SCAN_DURATION: float = 6.0
const HALLUCINATION_STUN: float = 2.0


func activate(player_pos: Vector2, _facing: int) -> void:
	var player = get_parent().get_parent()
	var player_id: int = player.player_id

	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.global_position.distance_to(player_pos) <= SCAN_RADIUS:
			enemy.apply_status("exposed", SCAN_DURATION)
			# Reveal Hallucinations with stun
			if enemy.has_method("reveal_from_scan"):
				enemy.reveal_from_scan()

	Events.ability_activated.emit(player_id, "weak_point_scan", player_pos, Vector2.ZERO)
	_show_scan_visual.rpc(player_pos)


@rpc("authority", "call_local", "reliable")
func _show_scan_visual(center: Vector2) -> void:
	# Simple expanding circle visual -- colored rectangle as placeholder
	var visual := ColorRect.new()
	visual.size = Vector2(SCAN_RADIUS * 2, SCAN_RADIUS * 2)
	visual.position = center - Vector2(SCAN_RADIUS, SCAN_RADIUS)
	visual.color = Color(1.0, 1.0, 0.0, 0.15)
	get_tree().current_scene.add_child(visual)
	get_tree().create_timer(0.5).timeout.connect(visual.queue_free)
