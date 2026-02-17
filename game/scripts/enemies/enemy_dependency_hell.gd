## Dependency Hell enemy — slow tanky, 10.0 unit aura disables player abilities each frame.
## Players inside the aura receive "ability_disabled" status refreshed each frame.
extends "res://scripts/enemies/enemy_base.gd"

const DH_HP: int = 6
const DH_SPEED: float = 1.5  # 30px / 20
const DH_AURA_RADIUS: float = 10.0  # 200px / 20
const DH_CONTACT_DMG: int = 12

const COLOR: Color = Color(0.15, 0.15, 0.6)


func _ready() -> void:
	super._ready()
	_load_glb_model("res://assets/models/enemy_quadshell.fbx")
	health = DH_HP
	speed = DH_SPEED
	contact_damage = DH_CONTACT_DMG
	_current_state = State.IDLE


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
