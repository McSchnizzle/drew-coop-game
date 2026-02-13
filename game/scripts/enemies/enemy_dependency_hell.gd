## Dependency Hell enemy — slow tanky, 200px aura disables player abilities each frame.
## Players inside the aura receive "ability_disabled" status refreshed each frame.
extends "res://scripts/enemies/enemy_base.gd"

const DH_HP: int = 6
const DH_SPEED: float = 30.0
const DH_AURA_RADIUS: float = 200.0
const DH_CONTACT_DMG: int = 12
const DH_SIZE: Vector2 = Vector2(56, 56)

const COLOR: Color = Color(0.15, 0.15, 0.6)


func _ready() -> void:
	super._ready()
	health = DH_HP
	speed = DH_SPEED
	contact_damage = DH_CONTACT_DMG
	_current_state = State.IDLE

	# Sprite2D is set via the scene file; no ColorRect resize needed.


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _is_alive or not multiplayer.is_server():
		return
	_apply_aura()


func _apply_aura() -> void:
	var players := get_tree().get_nodes_in_group("players")
	for player in players:
		if not player.visible:
			continue
		if player.get("_is_downed") and player._is_downed:
			continue
		if player.get("_is_alive") != null and not player._is_alive:
			continue
		var dist := global_position.distance_to(player.global_position)
		if dist <= DH_AURA_RADIUS:
			if player.has_method("apply_status"):
				player.apply_status("ability_disabled", 1.0)
