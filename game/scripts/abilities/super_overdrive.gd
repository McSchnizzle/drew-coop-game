## Overdrive -- Striker super ability.
## Doubles attack speed, +100% damage, +20% movement speed for 8 seconds.
## Runs on server only as child of AbilityManager.
extends Node

const OVERDRIVE_DURATION: float = 8.0


func activate(player: CharacterBody2D) -> void:
	player.apply_status("overdrive", OVERDRIVE_DURATION)
	Events.super_activated.emit(player.player_id, "overdrive")
	_show_overdrive_visual.rpc(player.get_path())


@rpc("authority", "call_local", "reliable")
func _show_overdrive_visual(player_path: NodePath) -> void:
	var player = get_node_or_null(player_path)
	if not player:
		return
	var visual := ColorRect.new()
	visual.size = Vector2(40, 72)
	visual.position = Vector2(-20, -36)
	visual.color = Color(1.0, 0.8, 0.0, 0.3)
	player.add_child(visual)
	get_tree().create_timer(OVERDRIVE_DURATION).timeout.connect(visual.queue_free)
