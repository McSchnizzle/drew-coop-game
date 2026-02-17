## Context Rot enemy — approaches to firing range, fires status projectiles, flees if close.
## Projectiles apply "context_rot" status to players, scrambling their HUD.
extends "res://scripts/enemies/enemy_base.gd"

const ROT_PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectile_enemy.tscn")

const CR_HP: int = 4
const CR_SPEED: float = 2.0  # 40px / 20
const CR_FIRE_RATE: float = 2.0
const CR_FIRE_RANGE: float = 17.5  # 350px / 20
const CR_FLEE_RANGE: float = 5.0  # 100px / 20
const CR_PROJ_SPEED: float = 10.0  # 200px / 20
const CR_PROJ_DAMAGE: int = 8

const COLOR: Color = Color(0.7, 0.8, 0.1)

var _fire_cooldown: float = 0.0


func _ready() -> void:
	super._ready()
	_load_glb_model("res://assets/models/enemy_eyedrone.fbx")
	health = CR_HP
	speed = CR_SPEED
	contact_damage = CR_PROJ_DAMAGE
	_current_state = State.IDLE


func _state_chase(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	var target := _find_nearest_player()
	if not target:
		_transition_to(State.IDLE)
		return

	var dist := global_position.distance_to(target.global_position)

	# Flee if player is too close
	if dist <= CR_FLEE_RANGE:
		_transition_to(State.FLEE)
		return

	# In firing range — stop and shoot
	if dist <= CR_FIRE_RANGE:
		_transition_to(State.ATTACK)
		return

	# Otherwise approach
	var dir := (target.global_position - global_position)
	dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed


func _state_attack(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	velocity.x = 0.0
	velocity.z = 0.0
	var target := _find_nearest_player()
	if not target:
		_transition_to(State.IDLE)
		return

	var dist := global_position.distance_to(target.global_position)

	# Flee if player is too close
	if dist <= CR_FLEE_RANGE:
		_transition_to(State.FLEE)
		return

	# Out of range, chase again
	if dist > CR_FIRE_RANGE:
		_transition_to(State.CHASE)
		return

	# Fire if cooldown ready
	if _fire_cooldown <= 0.0:
		var dir := (target.global_position - global_position)
		dir.y = 0
		dir = dir.normalized()
		_fire_rot_projectile(dir)
		_fire_cooldown = CR_FIRE_RATE


func _state_flee(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	var target := _find_nearest_player()
	if not target:
		_transition_to(State.IDLE)
		return

	var dist := global_position.distance_to(target.global_position)
	if dist > CR_FLEE_RANGE * 1.5:
		_transition_to(State.CHASE)
		return

	var dir := (global_position - target.global_position)
	dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * speed * 0.8
	velocity.z = dir.z * speed * 0.8


func _fire_rot_projectile(direction: Vector3) -> void:
	var proj = ROT_PROJECTILE_SCENE.instantiate()
	proj.direction = direction
	proj.speed = CR_PROJ_SPEED
	proj.damage = CR_PROJ_DAMAGE
	proj.owner_id = enemy_id
	proj.is_enemy_projectile = true
	proj.status_effect = "context_rot"
	proj.name = "RotProj_%d" % (randi() % 1000000)
	proj.position = global_position + direction * 1.25  # 25px / 20 = 1.25 units
	get_tree().current_scene.get_node("Projectiles").add_child(proj, true)
