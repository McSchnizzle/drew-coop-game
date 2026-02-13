## Context Rot enemy — approaches to firing range, fires status projectiles, flees if close.
## Projectiles apply "context_rot" status to players, scrambling their HUD.
extends "res://scripts/enemies/enemy_base.gd"

const ROT_PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectile_enemy.tscn")

const CR_HP: int = 4
const CR_SPEED: float = 40.0
const CR_FIRE_RATE: float = 2.0
const CR_FIRE_RANGE: float = 350.0
const CR_FLEE_RANGE: float = 100.0
const CR_PROJ_SPEED: float = 200.0
const CR_PROJ_DAMAGE: int = 8
const CR_SIZE: Vector2 = Vector2(40, 40)

const COLOR: Color = Color(0.7, 0.8, 0.1)

var _fire_cooldown: float = 0.0


func _ready() -> void:
	super._ready()
	health = CR_HP
	speed = CR_SPEED
	contact_damage = CR_PROJ_DAMAGE
	_current_state = State.IDLE

	# Sprite2D is set via the scene file; no ColorRect resize needed.


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
	var dir := (target.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()


func _state_attack(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	velocity = Vector2.ZERO
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
		var dir := (target.global_position - global_position).normalized()
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

	var dir := (global_position - target.global_position).normalized()
	velocity = dir * speed * 0.8
	move_and_slide()


func _fire_rot_projectile(direction: Vector2) -> void:
	var proj = ROT_PROJECTILE_SCENE.instantiate()
	proj.direction = direction
	proj.speed = CR_PROJ_SPEED
	proj.damage = CR_PROJ_DAMAGE
	proj.owner_id = enemy_id
	proj.is_enemy_projectile = true
	proj.status_effect = "context_rot"
	proj.name = "RotProj_%d" % (randi() % 1000000)
	proj.position = global_position + direction * 25.0
	get_tree().current_scene.get_node("Projectiles").add_child(proj, true)
