## Weak Point Scan -- Striker ability.
## Marks all enemies within radius as "exposed" (take 2x damage).
## Runs on server only as child of AbilityManager.
extends Node

const COOLDOWN: float = 12.0
const SCAN_RADIUS: float = 15.0  # 300px / 20
const SCAN_DURATION: float = 6.0
const HALLUCINATION_STUN: float = 2.0


func activate(player_pos: Vector3, _aim_dir: Vector3) -> void:
	var player = get_parent().get_parent()
	var player_id: int = player.player_id
	player._play_oneshot_anim.rpc("Cast", 0.8)

	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.global_position.distance_to(player_pos) <= SCAN_RADIUS:
			enemy.apply_status("exposed", SCAN_DURATION)
			# Reveal Hallucinations with stun
			if enemy.has_method("reveal_from_scan"):
				enemy.reveal_from_scan()

	Events.ability_activated.emit(player_id, "weak_point_scan", player_pos, Vector3.ZERO)
	# Show visual via player's RPC (player node exists on all peers).
	player._show_scan_visual.rpc(player_pos, SCAN_RADIUS)
