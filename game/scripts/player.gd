## Player script — CharacterBody2D with dual MultiplayerSynchronizer pattern.
## Server reads InputSync variables and applies authoritative physics.
## Each peer writes their own input to InputSync (authority set via player_id).
extends CharacterBody2D

# ── Physics Constants (Drew's exact preferences) ─────────────────────────────
const RUN_SPEED: float = 170.0           # Between medium and slow — deliberate
const SPRINT_SPEED: float = 300.0        # With stamina drain — noticeable boost
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
const JUMP_FATIGUE_WINDOW: float = 3.0   # Seconds to track consecutive jumps
const JUMP_FATIGUE_THRESHOLD: int = 3    # Jumps before fatigue kicks in
const JUMP_FATIGUE_PENALTY: float = 0.25 # 25% reduction per fatigued jump

# Melee
const MELEE_RANGE: float = 60.0          # How far melee reaches
const MELEE_DAMAGE: int = 2              # Damage per melee hit
const MELEE_COOLDOWN: float = 0.5        # Seconds between melee attacks

# Projectile scene path
const PROJECTILE_SCENE: String = "res://scenes/projectile.tscn"

# Revive constants
const BLEEDOUT_TIME: float = 30.0

# ── Exported Properties ──────────────────────────────────────────────────────
@export var player_id: int = 1:
	set(id):
		player_id = id
		# Give this peer authority over their own InputSync node.
		$InputSync.set_multiplayer_authority(id)

# ── Synced State (replicated by ServerSync to all peers) ─────────────────────
var health: int = 100
var stamina: float = SPRINT_STAMINA_MAX
var _is_downed: bool = false
var _bleedout_timer: float = 0.0
var ability_cooldown: float = 0.0
var super_charge: float = 0.0
var active_statuses: PackedStringArray = PackedStringArray()

# ── Input Variables (replicated by InputSync from owning peer to server) ─────
var input_move_dir: float = 0.0
var input_shoot: bool = false
var input_jump: bool = false
var input_sprint: bool = false
var input_melee: bool = false
var input_ability: bool = false
var input_super: bool = false
var input_interact: bool = false

# ── Internal State (not synced) ──────────────────────────────────────────────
var _facing: int = 1                     # -1 left, 1 right
var _is_alive: bool = true
var _shoot_cooldown_timer: float = 0.0
var _shoot_hold_time: float = 0.0        # How long shoot has been held
var _is_auto_firing: bool = false
var _jump_timestamps: Array[float] = []  # Recent jump times for fatigue tracking
var _melee_cooldown_timer: float = 0.0
var _projectile_scene: PackedScene = null
var _sprint_toggled: bool = false          # Toggle sprint on/off with one click
var _status_effects: Dictionary = {}      # { "effect_name": remaining_seconds }
var _is_reviving_someone: bool = false   # Set by ReviveSystem


func _ready() -> void:
	# Pre-load projectile scene so we don't load it every shot.
	_projectile_scene = load(PROJECTILE_SCENE)

	# When replicated via MultiplayerSpawner, the node name carries the peer_id
	# (set by game_manager before add_child). Use it to configure authority and camera
	# since @export values aren't replicated to clients by the spawner.
	if name.is_valid_int():
		player_id = name.to_int()

	# Set player color locally: host (id 1) = Blue, everyone else = White.
	var color_rect = $ColorRect as ColorRect
	if color_rect:
		if player_id == 1:
			color_rect.color = Color(0.2, 0.4, 1.0, 1.0)
		else:
			color_rect.color = Color(1.0, 1.0, 1.0, 1.0)

	# Only the local player gets the camera.
	if player_id == multiplayer.get_unique_id():
		$Camera2D.make_current()

	# Add to players group for enemy targeting.
	add_to_group("players")


func _physics_process(delta: float) -> void:
	if not _is_alive:
		return

	# Downed players cannot act
	if _is_downed:
		if multiplayer.is_server():
			_process_bleedout(delta)
		return

	# LOCAL PEER: read input and write to synced variables.
	if player_id == multiplayer.get_unique_id():
		_gather_input()
		_update_hud()

	# SERVER: apply physics using synced input.
	if multiplayer.is_server():
		_server_process(delta)


# ── Input Gathering (runs on owning peer only) ──────────────────────────────

func _gather_input() -> void:
	# Ignore input when window isn't focused — prevents controller input from
	# bleeding between instances when testing two windows on the same machine.
	# Direct Window-level focus check every frame.
	if not get_window().has_focus():
		input_move_dir = 0.0
		input_jump = false
		input_sprint = false
		input_shoot = false
		input_melee = false
		input_ability = false
		input_super = false
		input_interact = false
		return

	input_move_dir = Input.get_axis("move_left", "move_right")
	# One-shot inputs: directly assign so they auto-clear to false next frame.
	input_jump = Input.is_action_just_pressed("jump")
	input_shoot = Input.is_action_pressed("shoot")
	input_melee = Input.is_action_just_pressed("melee")
	input_ability = Input.is_action_just_pressed("ability")
	input_super = Input.is_action_just_pressed("super")
	input_interact = Input.is_action_pressed("interact")

	# Sprint toggle: click once to start sprinting, click again to stop.
	# Auto-stops when stamina runs out.
	if Input.is_action_just_pressed("sprint"):
		_sprint_toggled = not _sprint_toggled
	if stamina <= 0.0:
		_sprint_toggled = false
	input_sprint = _sprint_toggled


# ── Server-Side Physics (authoritative game logic) ──────────────────────────

func _server_process(delta: float) -> void:
	# -- Tick status effects --
	_update_status_effects(delta)

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
		var regen_mult := 1.0
		var ability_mgr = get_node_or_null("AbilityManager")
		if ability_mgr:
			regen_mult = ability_mgr.get_stamina_regen_multiplier()
		stamina = minf(stamina + SPRINT_STAMINA_REGEN * regen_mult * delta, SPRINT_STAMINA_MAX)

	# -- Speed modification from status effects --
	var speed_mult := 1.0
	if has_status("slow"):
		speed_mult *= 0.6
	if _is_reviving_someone:
		speed_mult *= 0.5
		is_sprinting = false
	if has_status("overdrive"):
		speed_mult *= 1.2

	# -- Horizontal movement --
	var current_speed := (SPRINT_SPEED if is_sprinting else RUN_SPEED) * speed_mult
	velocity.x = input_move_dir * current_speed

	# -- Facing direction --
	if input_move_dir > 0.0:
		_facing = 1
	elif input_move_dir < 0.0:
		_facing = -1

	# -- Jump with fatigue --
	if input_jump and is_on_floor():
		_apply_jump()

	# -- Shooting (blocked during revive) --
	if not _is_reviving_someone:
		_process_shooting(delta)
	else:
		_shoot_cooldown_timer = maxf(_shoot_cooldown_timer - delta, 0.0)

	# -- Melee (blocked during revive) --
	_melee_cooldown_timer = maxf(_melee_cooldown_timer - delta, 0.0)
	if input_melee and _melee_cooldown_timer <= 0.0 and not _is_reviving_someone:
		_do_melee()
		_melee_cooldown_timer = MELEE_COOLDOWN

	# -- Apply movement --
	move_and_slide()

	# -- Consume one-shot inputs so they don't fire repeatedly --
	# NOTE: input_ability and input_super are consumed by AbilityManager,
	# which runs after this (child nodes process after parent in Godot).
	input_jump = false
	input_melee = false


# ── Jump Fatigue System ──────────────────────────────────────────────────────

func _apply_jump() -> void:
	var now := Time.get_ticks_msec() / 1000.0

	# Prune old jump timestamps outside the fatigue window.
	_jump_timestamps = _jump_timestamps.filter(
		func(t: float) -> bool: return now - t < JUMP_FATIGUE_WINDOW
	)

	# Record THIS jump before checking so it counts toward the threshold.
	_jump_timestamps.append(now)

	# Calculate fatigue penalty.
	var jumps_in_window: int = _jump_timestamps.size()
	var jump_vel := JUMP_VELOCITY
	if jumps_in_window >= JUMP_FATIGUE_THRESHOLD:
		var fatigue_count: int = jumps_in_window - JUMP_FATIGUE_THRESHOLD + 1
		jump_vel *= (1.0 - JUMP_FATIGUE_PENALTY * fatigue_count)
		# Clamp so jump velocity never exceeds 60% reduction.
		jump_vel = maxf(jump_vel, JUMP_VELOCITY * 0.4)

	velocity.y = jump_vel


# ── Shooting System (tap + hold auto-fire) ───────────────────────────────────

func _process_shooting(delta: float) -> void:
	_shoot_cooldown_timer = maxf(_shoot_cooldown_timer - delta, 0.0)

	# Get shoot cooldown multiplier from overdrive
	var auto_cooldown := SHOOT_COOLDOWN_AUTO
	if has_status("overdrive"):
		auto_cooldown *= 0.5

	if input_shoot:
		_shoot_hold_time += delta

		if not _is_auto_firing:
			# First frame of press -- fire a single tap shot.
			if _shoot_hold_time <= delta + 0.001 and _shoot_cooldown_timer <= 0.0:
				_fire_projectile()
				_shoot_cooldown_timer = SHOOT_COOLDOWN_TAP

			# Transition to auto-fire after holding long enough.
			if _shoot_hold_time >= AUTO_FIRE_DELAY:
				_is_auto_firing = true
				_shoot_cooldown_timer = 0.0  # Start auto-fire immediately
		else:
			# Auto-fire mode -- fire at fast rate.
			if _shoot_cooldown_timer <= 0.0:
				_fire_projectile()
				_shoot_cooldown_timer = auto_cooldown
	else:
		_shoot_hold_time = 0.0
		_is_auto_firing = false


func _fire_projectile() -> void:
	if _projectile_scene == null:
		return

	# Flip shoot point to match facing direction BEFORE reading its position.
	$ShootPoint.position.x = absf($ShootPoint.position.x) * _facing

	var spawn_pos: Vector2 = $ShootPoint.global_position
	var projectile = _projectile_scene.instantiate()
	projectile.direction = Vector2(_facing, 0)
	projectile.owner_id = player_id
	projectile.name = "Projectile_%d" % (randi() % 1000000)

	# Apply damage multiplier from abilities
	var ability_mgr = get_node_or_null("AbilityManager")
	if ability_mgr:
		projectile.damage = int(ceil(projectile.damage * ability_mgr.get_damage_multiplier()))

	# Set position BEFORE add_child so MultiplayerSpawner includes it in spawn state.
	# Projectiles container is at (0,0), so local position == global position.
	projectile.position = spawn_pos

	# Spawn into the Projectiles container (MultiplayerSpawner handles replication).
	var projectiles_node = get_tree().current_scene.get_node("Projectiles")
	if projectiles_node:
		projectiles_node.add_child(projectile, true)


# ── Melee Attack ─────────────────────────────────────────────────────────────

func _do_melee() -> void:
	# Show visual on ALL peers via RPC (server + all clients see the swing).
	_show_melee_visual.rpc(_facing)

	# Hit detection (server-only — we're inside _server_process).
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not enemy is Node2D:
			continue
		# Check if enemy is in front of the player and within melee range.
		var to_enemy: Vector2 = enemy.global_position - global_position
		var in_front := (to_enemy.x * _facing) > 0.0
		if in_front and to_enemy.length() <= MELEE_RANGE:
			if enemy.has_method("take_damage"):
				enemy.take_damage(MELEE_DAMAGE, player_id)
				# Charge super for melee hits
				var melee_ability_mgr = get_node_or_null("AbilityManager")
				if melee_ability_mgr:
					melee_ability_mgr.add_super_charge(melee_ability_mgr.SUPER_CHARGE_PER_MELEE_HIT)


@rpc("authority", "call_local", "reliable")
func _show_melee_visual(facing: int) -> void:
	# Big orange flash in front of the player so it's obvious you're meleeing.
	var swing := ColorRect.new()
	swing.size = Vector2(80, 60)
	swing.color = Color(1.0, 0.5, 0.0, 0.9)  # Bright orange, nearly opaque
	swing.position = Vector2(8.0 * facing, -30.0)
	if facing < 0:
		swing.position.x = -80.0 - 8.0
	add_child(swing)
	# Flash for 0.3 seconds so it's noticeable.
	get_tree().create_timer(0.3).timeout.connect(swing.queue_free)


# ── HUD Updates (runs on local player only) ─────────────────────────────────

func _update_hud() -> void:
	var hud = get_tree().current_scene.get_node_or_null("UI/HUD")
	if not hud:
		return

	var health_label = hud.get_node_or_null("HealthLabel") as Label
	var stamina_bar = hud.get_node_or_null("StaminaBar") as ProgressBar

	if has_status("context_rot"):
		# Scramble HUD with fake values
		if health_label:
			health_label.text = "Health: %d" % (randi() % 200)
		if stamina_bar:
			stamina_bar.value = randf() * 100.0
	else:
		if health_label:
			health_label.text = "Health: %d" % health
		if stamina_bar:
			stamina_bar.value = stamina

	# Ability cooldown display
	var ability_label = hud.get_node_or_null("AbilityLabel") as Label
	if ability_label:
		if ability_cooldown > 0.0:
			ability_label.text = "Ability: %.1fs" % ability_cooldown
		else:
			ability_label.text = "Ability: READY"

	# Super charge display
	var super_label = hud.get_node_or_null("SuperLabel") as Label
	if super_label:
		if super_charge >= 100.0:
			super_label.text = "Super: READY!"
		else:
			super_label.text = "Super: %d%%" % int(super_charge)


# ── Health / Damage ──────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if not _is_alive:
		return
	if _is_downed:
		return
	health -= amount
	if health <= 0:
		health = 0
		die()


func die() -> void:
	# Enter downed state instead of permanent death
	_is_downed = true
	_bleedout_timer = BLEEDOUT_TIME
	velocity = Vector2.ZERO
	Events.player_downed.emit(player_id, global_position)

	# Disable collision so enemies walk through
	var collision = get_node_or_null("CollisionShape2D")
	if collision:
		collision.set_deferred("disabled", true)

	# Visual: gray color
	var color_rect = get_node_or_null("ColorRect") as ColorRect
	if color_rect:
		color_rect.color = Color(0.5, 0.5, 0.5, 1.0)


func _process_bleedout(delta: float) -> void:
	if not _is_downed:
		return
	_bleedout_timer -= delta
	if _bleedout_timer <= 0.0:
		# Permanent death
		_is_alive = false
		_is_downed = false
		visible = false
		set_physics_process(false)
		Events.player_bleedout.emit(player_id)
		Events.player_died.emit(player_id, global_position)


# ── Status Effects (server-authoritative) ────────────────────────────────────

func apply_status(effect_name: String, duration: float) -> void:
	if not multiplayer.is_server():
		return
	_status_effects[effect_name] = duration
	_sync_active_statuses()
	Events.status_applied.emit(player_id, effect_name, duration)


func remove_status(effect_name: String) -> void:
	if _status_effects.has(effect_name):
		_status_effects.erase(effect_name)
		_sync_active_statuses()
		Events.status_removed.emit(player_id, effect_name)


func has_status(effect_name: String) -> bool:
	# On server, check the authoritative dictionary; on client, check the synced array.
	if multiplayer.is_server():
		return _status_effects.has(effect_name) and _status_effects[effect_name] > 0.0
	return active_statuses.has(effect_name)


func _update_status_effects(delta: float) -> void:
	var expired: Array[String] = []
	for effect_name in _status_effects:
		_status_effects[effect_name] -= delta
		if _status_effects[effect_name] <= 0.0:
			expired.append(effect_name)
	for effect_name in expired:
		_status_effects.erase(effect_name)
		Events.status_removed.emit(player_id, effect_name)
	if expired.size() > 0:
		_sync_active_statuses()


func _sync_active_statuses() -> void:
	var names: PackedStringArray = PackedStringArray()
	for effect_name in _status_effects:
		if _status_effects[effect_name] > 0.0:
			names.append(effect_name)
	active_statuses = names
