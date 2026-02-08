## Player script — CharacterBody2D with dual MultiplayerSynchronizer pattern.
## Server reads InputSync variables and applies authoritative physics.
## Each peer writes their own input to InputSync (authority set via player_id).
extends CharacterBody2D

# ── Physics Constants (Drew's exact preferences) ─────────────────────────────
const RUN_SPEED: float = 170.0           # Between medium and slow — deliberate
const SPRINT_SPEED: float = 250.0        # With stamina drain
const JUMP_VELOCITY: float = -320.0      # Modest single jump
const GRAVITY: float = 900.0             # Snappy fall

# Sprint stamina
const SPRINT_STAMINA_MAX: float = 100.0
const SPRINT_STAMINA_DRAIN: float = 30.0 # Per second while sprinting
const SPRINT_STAMINA_REGEN: float = 20.0 # Per second when not sprinting

# Shooting
const SHOOT_COOLDOWN_TAP: float = 0.3    # Single shot delay
const SHOOT_COOLDOWN_AUTO: float = 0.12  # Auto-fire rate when holding
const AUTO_FIRE_DELAY: float = 0.4       # Hold time before auto-fire starts

# Jump fatigue
const JUMP_FATIGUE_WINDOW: float = 2.0   # Seconds to track consecutive jumps
const JUMP_FATIGUE_THRESHOLD: int = 3    # Jumps before fatigue kicks in
const JUMP_FATIGUE_PENALTY: float = 0.15 # 15% reduction per fatigued jump

# Projectile scene path
const PROJECTILE_SCENE: String = "res://scenes/projectile.tscn"

# ── Exported Properties ──────────────────────────────────────────────────────
@export var player_id: int = 1:
	set(id):
		player_id = id
		# Give this peer authority over their own InputSync node.
		$InputSync.set_multiplayer_authority(id)

# ── Synced State (replicated by ServerSync to all peers) ─────────────────────
var health: int = 100
var stamina: float = SPRINT_STAMINA_MAX

# ── Input Variables (replicated by InputSync from owning peer to server) ─────
var input_move_dir: float = 0.0
var input_shoot: bool = false
var input_jump: bool = false
var input_sprint: bool = false
var input_melee: bool = false
var input_ability: bool = false
var input_super: bool = false

# ── Internal State (not synced) ──────────────────────────────────────────────
var _facing: int = 1                     # -1 left, 1 right
var _is_alive: bool = true
var _shoot_cooldown_timer: float = 0.0
var _shoot_hold_time: float = 0.0        # How long shoot has been held
var _is_auto_firing: bool = false
var _jump_timestamps: Array[float] = []  # Recent jump times for fatigue tracking
var _projectile_scene: PackedScene = null


func _ready() -> void:
	# Pre-load projectile scene so we don't load it every shot.
	_projectile_scene = load(PROJECTILE_SCENE)

	# Only the local player gets the camera.
	if player_id == multiplayer.get_unique_id():
		$Camera2D.make_current()

	# Add to players group for enemy targeting.
	add_to_group("players")


func _physics_process(delta: float) -> void:
	if not _is_alive:
		return

	# LOCAL PEER: read input and write to synced variables.
	if player_id == multiplayer.get_unique_id():
		_gather_input()

	# SERVER: apply physics using synced input.
	if multiplayer.is_server():
		_server_process(delta)


# ── Input Gathering (runs on owning peer only) ──────────────────────────────

func _gather_input() -> void:
	input_move_dir = Input.get_axis("move_left", "move_right")
	# For one-shot actions, set true on press; server will consume and clear.
	if Input.is_action_just_pressed("jump"):
		input_jump = true
	input_sprint = Input.is_action_pressed("sprint")
	input_shoot = Input.is_action_pressed("shoot")
	if Input.is_action_just_pressed("melee"):
		input_melee = true
	if Input.is_action_just_pressed("ability"):
		input_ability = true
	if Input.is_action_just_pressed("super"):
		input_super = true


# ── Server-Side Physics (authoritative game logic) ──────────────────────────

func _server_process(delta: float) -> void:
	# -- Sanitize client input --
	input_move_dir = clampf(input_move_dir, -1.0, 1.0)

	# -- Gravity --
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# -- Sprint stamina --
	var is_sprinting := input_sprint and stamina > 0.0 and input_move_dir != 0.0
	if is_sprinting:
		stamina = maxf(stamina - SPRINT_STAMINA_DRAIN * delta, 0.0)
	else:
		stamina = minf(stamina + SPRINT_STAMINA_REGEN * delta, SPRINT_STAMINA_MAX)

	# -- Horizontal movement --
	var current_speed := SPRINT_SPEED if is_sprinting else RUN_SPEED
	velocity.x = input_move_dir * current_speed

	# -- Facing direction --
	if input_move_dir > 0.0:
		_facing = 1
	elif input_move_dir < 0.0:
		_facing = -1

	# -- Jump with fatigue --
	if input_jump and is_on_floor():
		_apply_jump()

	# -- Shooting --
	_process_shooting(delta)

	# -- Apply movement --
	move_and_slide()

	# -- Consume one-shot inputs so they don't fire repeatedly --
	input_jump = false
	input_melee = false
	input_ability = false
	input_super = false


# ── Jump Fatigue System ──────────────────────────────────────────────────────

func _apply_jump() -> void:
	var now := Time.get_ticks_msec() / 1000.0

	# Prune old jump timestamps outside the fatigue window.
	_jump_timestamps = _jump_timestamps.filter(
		func(t: float) -> bool: return now - t < JUMP_FATIGUE_WINDOW
	)

	# Calculate fatigue penalty.
	var jumps_in_window: int = _jump_timestamps.size()
	var jump_vel := JUMP_VELOCITY
	if jumps_in_window >= JUMP_FATIGUE_THRESHOLD:
		var fatigue_count: int = jumps_in_window - JUMP_FATIGUE_THRESHOLD + 1
		jump_vel *= (1.0 - JUMP_FATIGUE_PENALTY * fatigue_count)
		# Clamp so jump velocity never exceeds 50% reduction.
		jump_vel = maxf(jump_vel, JUMP_VELOCITY * 0.5)

	velocity.y = jump_vel
	_jump_timestamps.append(now)


# ── Shooting System (tap + hold auto-fire) ───────────────────────────────────

func _process_shooting(delta: float) -> void:
	_shoot_cooldown_timer = maxf(_shoot_cooldown_timer - delta, 0.0)

	if input_shoot:
		_shoot_hold_time += delta

		if not _is_auto_firing:
			# First frame of press — fire a single tap shot.
			if _shoot_hold_time <= delta + 0.001 and _shoot_cooldown_timer <= 0.0:
				_fire_projectile()
				_shoot_cooldown_timer = SHOOT_COOLDOWN_TAP

			# Transition to auto-fire after holding long enough.
			if _shoot_hold_time >= AUTO_FIRE_DELAY:
				_is_auto_firing = true
				_shoot_cooldown_timer = 0.0  # Start auto-fire immediately
		else:
			# Auto-fire mode — fire at fast rate.
			if _shoot_cooldown_timer <= 0.0:
				_fire_projectile()
				_shoot_cooldown_timer = SHOOT_COOLDOWN_AUTO
	else:
		_shoot_hold_time = 0.0
		_is_auto_firing = false


func _fire_projectile() -> void:
	if _projectile_scene == null:
		return

	# Flip shoot point to match facing direction BEFORE reading its position.
	$ShootPoint.position.x = absf($ShootPoint.position.x) * _facing

	var spawn_pos := $ShootPoint.global_position
	var projectile := _projectile_scene.instantiate()
	projectile.direction = Vector2(_facing, 0)
	projectile.owner_id = player_id
	projectile.name = "Projectile_%d" % (randi() % 1000000)

	# Spawn into the Projectiles container (MultiplayerSpawner handles replication).
	var projectiles_node := get_tree().current_scene.get_node("Projectiles")
	if projectiles_node:
		projectiles_node.add_child(projectile, true)
		# Set global_position AFTER adding to tree so it resolves correctly.
		projectile.global_position = spawn_pos


# ── Health / Damage ──────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if not _is_alive:
		return
	health -= amount
	if health <= 0:
		health = 0
		die()


func die() -> void:
	_is_alive = false
	velocity = Vector2.ZERO
	Events.player_died.emit(player_id, global_position)
	# Hide the player visually but keep the node for potential respawn.
	visible = false
	set_physics_process(false)
