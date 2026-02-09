## Deploy Turret -- Engineer ability.
## Places an auto-targeting turret near the player. Max 2 active.
## Runs on server only as child of AbilityManager.
extends Node

const COOLDOWN: float = 15.0
const TURRET_MAX_ACTIVE: int = 2

var TURRET_SCENE: PackedScene = null
var _active_turrets: Array = []
var _next_turret_id: int = 100000


func _ready() -> void:
	TURRET_SCENE = load("res://scenes/turret.tscn")


func activate(player_pos: Vector2, facing: int) -> void:
	if TURRET_SCENE == null:
		return

	var player = get_parent().get_parent()
	var player_id: int = player.player_id

	var turret_pos := player_pos + Vector2(facing * 60, 0)
	_enforce_turret_limit()

	var turret = TURRET_SCENE.instantiate()
	turret.owner_id = player_id
	turret.turret_id = _next_turret_id
	turret.name = "Turret_%d" % _next_turret_id
	turret.position = turret_pos
	_next_turret_id += 1

	var effects_node = get_tree().current_scene.get_node("Effects")
	effects_node.add_child(turret, true)

	_active_turrets.append(turret)
	Events.turret_deployed.emit(player_id, turret.turret_id, turret_pos)
	Events.ability_activated.emit(player_id, "deploy_turret", turret_pos, Vector2(facing, 0))


func _enforce_turret_limit() -> void:
	# Remove dead turrets from tracking
	_active_turrets = _active_turrets.filter(func(t): return is_instance_valid(t))

	# Remove oldest turrets if at limit
	while _active_turrets.size() >= TURRET_MAX_ACTIVE:
		var oldest = _active_turrets.pop_front()
		if is_instance_valid(oldest):
			Events.turret_destroyed.emit(oldest.turret_id)
			oldest.queue_free()
