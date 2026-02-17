## Healing Pulse -- Engineer super ability.
## Instantly heals ALL living players for 50 HP and removes negative statuses.
## Runs on server only as child of AbilityManager.
extends Node

const HEALING_AMOUNT: int = 50


func activate(player: CharacterBody3D) -> void:
	var players := get_tree().get_nodes_in_group("players")
	for p in players:
		if not p._is_alive:
			continue
		# Revive downed teammates
		if p.get("_is_downed") and p._is_downed:
			p._is_downed = false
			p.health = HEALING_AMOUNT
			p._bleedout_timer = 0.0
			# Re-enable collision
			var collision = p.get_node_or_null("CollisionShape3D")
			if collision:
				collision.set_deferred("disabled", false)
			# Restore color on ALL peers via RPC
			var ability_mgr = p.get_node_or_null("AbilityManager")
			var role: String = ability_mgr.role if ability_mgr else "striker"
			p._show_revived_visual.rpc(role)
			# Remove revive bar if present
			var bar = p.get_node_or_null("ReviveBar")
			if bar:
				bar.queue_free()
			p._show_healing_visual.rpc()
			print("HealingPulse: Revived player %d" % p.player_id)
			continue
		# Heal standing players
		p.health = mini(p.health + HEALING_AMOUNT, 100)
		# Remove negative statuses
		p.remove_status("context_rot")
		p.remove_status("slow")
		p.remove_status("ability_disabled")
		p._show_healing_visual.rpc()
		print("HealingPulse: Healed player %d to %d HP" % [p.player_id, p.health])

	Events.super_activated.emit(player.player_id, "healing_pulse")
