## Healing Pulse -- Engineer super ability.
## Instantly heals ALL living players for 50 HP and removes negative statuses.
## Runs on server only as child of AbilityManager.
extends Node

const HEALING_AMOUNT: int = 50


func activate(player: CharacterBody2D) -> void:
	var players := get_tree().get_nodes_in_group("players")
	for p in players:
		if not p._is_alive:
			continue
		if p.get("_is_downed") and p._is_downed:
			continue
		# Heal
		p.health = mini(p.health + HEALING_AMOUNT, 100)
		# Remove negative statuses
		p.remove_status("context_rot")
		p.remove_status("slow")
		p.remove_status("ability_disabled")

	Events.super_activated.emit(player.player_id, "healing_pulse")
	_show_healing_visual.rpc()


@rpc("authority", "call_local", "reliable")
func _show_healing_visual() -> void:
	# Flash green on all players briefly
	var players := get_tree().get_nodes_in_group("players")
	for p in players:
		if not p.visible:
			continue
		var visual := ColorRect.new()
		visual.size = Vector2(40, 72)
		visual.position = Vector2(-20, -36)
		visual.color = Color(0.2, 1.0, 0.3, 0.4)
		p.add_child(visual)
		get_tree().create_timer(0.5).timeout.connect(visual.queue_free)
