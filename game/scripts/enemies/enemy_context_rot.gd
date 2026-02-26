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
const CR_PROJ_DAMAGE: int = 1

const COLOR: Color = Color(0.7, 0.8, 0.1)

# Drone animation constants
const HOVER_HEIGHT: float = 1.5       # Float above ground
const HOVER_BOB_SPEED: float = 2.5    # Bob frequency
const HOVER_BOB_AMOUNT: float = 0.15  # Bob amplitude
const TILT_SPEED: float = 5.0         # How fast tilt responds
const TILT_MAX_DEG: float = 20.0      # Max forward/back tilt
const BANK_MAX_DEG: float = 15.0      # Max side banking

var _fire_cooldown: float = 0.0
var _drone_time: float = 0.0
var _current_tilt: Vector3 = Vector3.ZERO  # Smoothed tilt angles
var _recoil_timer: float = 0.0
var _death_spin: float = 0.0
var _death_drop: float = 0.0
var _model_base_y: float = 0.0  # Store base Y from model repositioning


func _ready() -> void:
	super._ready()
	_load_glb_model("res://assets/models/context_rot_drone.glb")
	health = CR_HP
	speed = CR_SPEED
	contact_damage = CR_PROJ_DAMAGE
	_current_state = State.IDLE
	# Store the repositioned model Y so hover bob adds to it
	if _model_node:
		_model_base_y = _model_node.position.y
	# Offset drone above ground
	position.y = HOVER_HEIGHT


func _process(delta: float) -> void:
	super._process(delta)
	if not _model_node:
		return
	_drone_time += delta

	# ── Death spiral ─────────────────────────────────────────────────────
	if _current_state == State.DEAD:
		_death_spin += delta * 8.0
		_death_drop += delta * 3.0
		_model_node.rotation_degrees.z = _death_spin * 60.0
		_model_node.rotation_degrees.x = _death_spin * 20.0
		_model_node.position.y -= _death_drop * delta
		return

	# ── Hover bob ────────────────────────────────────────────────────────
	var bob := sin(_drone_time * HOVER_BOB_SPEED) * HOVER_BOB_AMOUNT
	_model_node.position.y = _model_base_y + bob

	# ── Movement tilt (lean into velocity) ───────────────────────────────
	var target_tilt := Vector3.ZERO
	var speed_sq := Vector2(velocity.x, velocity.z).length_squared()
	if speed_sq > 0.1:
		# Forward tilt based on speed
		target_tilt.x = -TILT_MAX_DEG
		# Bank into turns: cross product of facing vs velocity
		var facing := Vector2(sin(rotation.y), cos(rotation.y))
		var vel_dir := Vector2(velocity.x, velocity.z).normalized()
		var cross := facing.x * vel_dir.y - facing.y * vel_dir.x
		target_tilt.z = cross * BANK_MAX_DEG

	# Fleeing: tilt backward instead
	if _current_state == State.FLEE:
		target_tilt.x = TILT_MAX_DEG * 0.7

	# Shooting recoil
	if _recoil_timer > 0.0:
		_recoil_timer -= delta
		target_tilt.x += 10.0  # Kick back

	# Smooth interpolation
	_current_tilt = _current_tilt.lerp(target_tilt, TILT_SPEED * delta)
	_model_node.rotation_degrees.x = _current_tilt.x
	_model_node.rotation_degrees.z = _current_tilt.z


func _transition_to(new_state: State) -> void:
	_current_state = new_state
	match new_state:
		State.IDLE:
			_play_anim("Idle")
		State.CHASE:
			_play_anim("Run")
		State.ATTACK:
			_play_anim("Idle")  # Hover/aim between shots; "Shoot" plays on fire
		State.FLEE:
			_play_anim("Run")
		State.STUNNED:
			_play_anim("Idle")
		State.DEAD:
			_play_anim("Dead")


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
	_recoil_timer = 0.3  # Trigger recoil tilt
	# Play shoot animation (stop first to restart if already playing)
	if _anim_player:
		_anim_player.stop()
	_play_anim("Shoot")
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
