## Overdrive -- Striker super ability.
## Doubles attack speed, +100% damage, +20% movement speed for 8 seconds.
## Runs on server only as child of AbilityManager.
extends Node

const OVERDRIVE_DURATION: float = 8.0


func activate(player: CharacterBody3D) -> void:
	player._play_oneshot_anim.rpc("PowerUp", 1.0)
	player.apply_status("overdrive", OVERDRIVE_DURATION)
	Events.super_activated.emit(player.player_id, "overdrive")
	# Show visual via player's RPC (player node exists on all peers).
	player._show_overdrive_visual.rpc(OVERDRIVE_DURATION)
