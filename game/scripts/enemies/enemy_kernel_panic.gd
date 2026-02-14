## Kernel Panic boss — BSOD blue rectangle, halt-lunge attack pattern.
## Phase 1: chase + halt-lunge. Phase 2: shield + projectiles + crash dumps.
## Phase 3: enrage, no shield, faster attacks, visual pulse.
extends "res://scripts/enemies/enemy_base.gd"

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectile_enemy.tscn")
const MERGE_CONFLICT_SCENE_PATH: String = "res://scenes/enemies/enemy_merge_conflict.tscn"

# ── Base Stats ────────────────────────────────────────────────────────────────
const BOSS_HP: int = 80
const BOSS_SPEED: float = 35.0
const BOSS_CONTACT_DMG: int = 20
const BOSS_SIZE: Vector2 = Vector2(120, 120)
const BOSS_COLOR: Color = Color(0.0, 0.3, 0.9)

# ── Lunge Parameters (per phase) ─────────────────────────────────────────────
const LUNGE_CYCLE:    Array[float] = [4.0, 3.0, 2.0]   # seconds between lunges
const FREEZE_DURATION: Array[float] = [1.0, 0.7, 0.5]  # telegraph freeze time
const LUNGE_SPEED:    Array[float] = [250.0, 280.0, 300.0]
const LUNGE_DURATION: float = 0.5  # how long the lunge movement lasts

# ── Projectile Parameters ────────────────────────────────────────────────────
const PROJ_SPEED: float = 180.0
const PROJ_DAMAGE: int = 8
const PROJ_COOLDOWN: Array[float] = [999.0, 5.0, 3.0]  # Phase 1 = no projectiles
const PROJ_COUNT: Array[int] = [0, 3, 5]
const PROJ_SPREAD_DEG: Array[float] = [0.0, 30.0, 36.0]

# ── Crash Dump (Phase 2 only) ────────────────────────────────────────────────
const CRASH_DUMP_COOLDOWN: float = 12.0
const CRASH_DUMP_COUNT: int = 2

# ── Shield (Phase 2 only) ────────────────────────────────────────────────────
const SHIELD_FLANK_WINDOW: float = 2.0  # seconds window for both-side hits
const SHIELD_DROP_DURATION: float = 4.0 # seconds shield stays down after flank

# ── Phase Thresholds (fraction of max_health) ────────────────────────────────
const PHASE_2_THRESHOLD: float = 0.6
const PHASE_3_THRESHOLD: float = 0.25
const PHASE_TRANSITION_STUN: float = 2.0

# ── State ─────────────────────────────────────────────────────────────────────
enum Phase { PHASE_1, PHASE_2, PHASE_3 }

var max_health: int = BOSS_HP
var _current_phase: int = Phase.PHASE_1  # synced via MultiplayerSynchronizer

# Halt-lunge state
var _is_frozen: bool = false  # synced — telegraph visual
var _lunge_cycle_timer: float = 0.0
var _freeze_timer: float = 0.0
var _lunge_timer: float = 0.0
var _lunge_direction: Vector2 = Vector2.ZERO
var _is_lunging: bool = false

# Projectile state
var _proj_cooldown_timer: float = 0.0

# Crash dump state
var _crash_dump_timer: float = 0.0

# Shield state (Phase 2 only)
var _shield_active: bool = false   # synced
var _shield_facing_left: bool = true  # synced — which side is shielded
var _shield_dropped_timer: float = 0.0  # countdown while shield is dropped
var _hit_from_left: bool = false
var _hit_from_right: bool = false
var _flank_window_timer: float = 0.0

# Phase 3 visual pulse
var _pulse_timer: float = 0.0

# Lazy-loaded scene for crash dump spawns
var _merge_conflict_scene: PackedScene = null


func _ready() -> void:
	super._ready()
	health = BOSS_HP
	max_health = BOSS_HP
	speed = BOSS_SPEED
	contact_damage = BOSS_CONTACT_DMG
	_current_state = State.IDLE
	_lunge_cycle_timer = LUNGE_CYCLE[Phase.PHASE_1]


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _is_alive or not multiplayer.is_server():
		return

	_update_projectile_timer(delta)
	_update_crash_dump_timer(delta)
	_update_shield_timers(delta)


func _process(delta: float) -> void:
	# Client-side visuals only
	if multiplayer.is_server():
		return
	_update_shield_visual()
	_update_freeze_visual()
	if _current_phase == Phase.PHASE_3:
		_pulse_timer += delta
		_update_phase3_pulse()


# ── State Overrides ───────────────────────────────────────────────────────────

func _state_chase(delta: float) -> void:
	var target := _find_nearest_player()
	if not target:
		_transition_to(State.IDLE)
		return

	# Halt-lunge cycle
	_lunge_cycle_timer -= delta
	if _lunge_cycle_timer <= 0.0 and not _is_frozen and not _is_lunging:
		# Start freeze telegraph
		_is_frozen = true
		_freeze_timer = FREEZE_DURATION[_current_phase]
		_lunge_direction = (target.global_position - global_position).normalized()
		velocity = Vector2.ZERO
		_show_lunge_telegraph.rpc()
		return

	if _is_frozen:
		velocity = Vector2.ZERO
		_freeze_timer -= delta
		if _freeze_timer <= 0.0:
			# Launch the lunge
			_is_frozen = false
			_is_lunging = true
			_lunge_timer = LUNGE_DURATION
			_transition_to(State.ATTACK)
		return

	# Normal chase movement
	var dir := (target.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()


func _state_attack(delta: float) -> void:
	if not _is_lunging:
		_transition_to(State.CHASE)
		return

	# Lunge movement
	velocity = _lunge_direction * LUNGE_SPEED[_current_phase]
	move_and_slide()

	_lunge_timer -= delta
	if _lunge_timer <= 0.0:
		_is_lunging = false
		_lunge_cycle_timer = LUNGE_CYCLE[_current_phase]
		_transition_to(State.CHASE)


func _state_stunned(delta: float) -> void:
	velocity = Vector2.ZERO
	_is_frozen = false
	_is_lunging = false
	_stun_timer -= delta
	if _stun_timer <= 0.0:
		_lunge_cycle_timer = LUNGE_CYCLE[_current_phase]
		_transition_to(State.CHASE)


# ── Damage & Shield ──────────────────────────────────────────────────────────

func take_damage(amount: int, from_player_id: int) -> void:
	if not _is_alive or not multiplayer.is_server():
		return

	# Shield check (Phase 2 only)
	if _current_phase == Phase.PHASE_2 and _shield_active:
		var attacker := _find_player_by_id(from_player_id)
		if attacker:
			var hit_from_left := attacker.global_position.x < global_position.x
			if hit_from_left == _shield_facing_left:
				# Blocked by shield
				_show_shield_block.rpc()
				# Track flanking
				if hit_from_left:
					_hit_from_left = true
				else:
					_hit_from_right = true
				return
			else:
				# Hit from unshielded side
				if hit_from_left:
					_hit_from_left = true
				else:
					_hit_from_right = true

		# Check if both sides hit within window (flanking)
		_check_flank_break()

	# Apply exposed multiplier and deal damage
	if has_status("exposed"):
		amount *= 2
	health -= amount
	_show_hit_flash.rpc()

	if health <= 0:
		health = 0
		_die(from_player_id)
		return

	# Check phase transitions
	_check_phase_transition()


func _check_flank_break() -> void:
	if _hit_from_left and _hit_from_right:
		# Both sides hit — break the shield!
		_shield_active = false
		_shield_dropped_timer = SHIELD_DROP_DURATION
		apply_status("exposed", SHIELD_DROP_DURATION)
		_hit_from_left = false
		_hit_from_right = false
		_flank_window_timer = 0.0


func _check_phase_transition() -> void:
	var health_pct := float(health) / float(max_health)

	if _current_phase == Phase.PHASE_1 and health_pct <= PHASE_2_THRESHOLD:
		_enter_phase(Phase.PHASE_2)
	elif _current_phase == Phase.PHASE_2 and health_pct <= PHASE_3_THRESHOLD:
		_enter_phase(Phase.PHASE_3)


func _enter_phase(phase: int) -> void:
	_current_phase = phase
	Events.boss_phase_changed.emit(enemy_id, phase)

	# Stun on phase transition
	_is_frozen = false
	_is_lunging = false
	_stun_timer = PHASE_TRANSITION_STUN
	_transition_to(State.STUNNED)

	# Reset lunge cycle for new phase
	_lunge_cycle_timer = LUNGE_CYCLE[phase]

	if phase == Phase.PHASE_2:
		_shield_active = true
		_shield_facing_left = true
		_proj_cooldown_timer = PROJ_COOLDOWN[Phase.PHASE_2]
		_crash_dump_timer = CRASH_DUMP_COOLDOWN
		_notify_phase_change.rpc(phase)
	elif phase == Phase.PHASE_3:
		_shield_active = false  # Shield drops permanently
		_proj_cooldown_timer = PROJ_COOLDOWN[Phase.PHASE_3]
		_notify_phase_change.rpc(phase)


# ── Projectile Spread ────────────────────────────────────────────────────────

func _update_projectile_timer(delta: float) -> void:
	if _current_phase == Phase.PHASE_1:
		return
	if _current_state == State.STUNNED or _current_state == State.DEAD:
		return

	_proj_cooldown_timer -= delta
	if _proj_cooldown_timer <= 0.0:
		_fire_projectile_spread()
		_proj_cooldown_timer = PROJ_COOLDOWN[_current_phase]


func _fire_projectile_spread() -> void:
	var target := _find_nearest_player()
	if not target:
		return

	var base_dir := (target.global_position - global_position).normalized()
	var count: int = PROJ_COUNT[_current_phase]
	var spread_deg: float = PROJ_SPREAD_DEG[_current_phase]

	# Fire center projectile + spread
	var angles: Array[float] = [0.0]
	if count >= 3:
		angles.append(deg_to_rad(spread_deg))
		angles.append(deg_to_rad(-spread_deg))
	if count >= 5:
		angles.append(deg_to_rad(spread_deg * 2.0))
		angles.append(deg_to_rad(-spread_deg * 2.0))

	for angle in angles:
		var dir := base_dir.rotated(angle)
		var proj = PROJECTILE_SCENE.instantiate()
		proj.direction = dir
		proj.speed = PROJ_SPEED
		proj.damage = PROJ_DAMAGE
		proj.owner_id = enemy_id
		proj.is_enemy_projectile = true
		proj.status_effect = "panic"
		proj.name = "BossProj_%d" % (randi() % 1000000)
		proj.position = global_position + dir * 30.0
		get_tree().current_scene.get_node("Projectiles").add_child(proj, true)


# ── Crash Dump Spawns (Phase 2 only) ─────────────────────────────────────────

func _update_crash_dump_timer(delta: float) -> void:
	if _current_phase != Phase.PHASE_2:
		return
	if _current_state == State.STUNNED or _current_state == State.DEAD:
		return

	_crash_dump_timer -= delta
	if _crash_dump_timer <= 0.0:
		_spawn_crash_dumps()
		_crash_dump_timer = CRASH_DUMP_COOLDOWN


func _spawn_crash_dumps() -> void:
	if not _merge_conflict_scene:
		_merge_conflict_scene = load(MERGE_CONFLICT_SCENE_PATH)

	var game_manager = get_tree().current_scene
	var enemies_node = game_manager.get_node("Enemies")

	for i in CRASH_DUMP_COUNT:
		var enemy = _merge_conflict_scene.instantiate()
		enemy.enemy_id = game_manager.next_enemy_id()
		enemy.name = "Enemy_%d" % enemy.enemy_id
		enemy.position = global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		enemies_node.add_child(enemy, true)


# ── Shield Logic ─────────────────────────────────────────────────────────────

func _update_shield_timers(delta: float) -> void:
	if _current_phase != Phase.PHASE_2:
		return

	# Flank detection window
	if _hit_from_left or _hit_from_right:
		_flank_window_timer += delta
		if _flank_window_timer >= SHIELD_FLANK_WINDOW:
			# Window expired — reset
			_hit_from_left = false
			_hit_from_right = false
			_flank_window_timer = 0.0

	# Shield recovery after being dropped
	if not _shield_active and _shield_dropped_timer > 0.0:
		_shield_dropped_timer -= delta
		if _shield_dropped_timer <= 0.0:
			_shield_active = true
			_hit_from_left = false
			_hit_from_right = false

	# Update shield facing toward last attacker
	if _shield_active:
		_update_shield_facing()


func _update_shield_facing() -> void:
	# Face shield toward nearest player
	var target := _find_nearest_player()
	if target:
		_shield_facing_left = target.global_position.x < global_position.x


# ── Death ─────────────────────────────────────────────────────────────────────

func _die(killed_by: int) -> void:
	_is_alive = false
	_current_state = State.DEAD
	velocity = Vector2.ZERO
	Events.enemy_died.emit(enemy_id, killed_by, false)
	Events.boss_died.emit(enemy_id, killed_by)
	_notify_boss_died.rpc()
	queue_free()


# ── Scaling Override ──────────────────────────────────────────────────────────

func apply_scaling(health_scale: float, _speed_scale: float) -> void:
	# Scale health only — lunge speed is fixed for game feel
	health = int(ceil(health * health_scale))
	max_health = health


# ── Contact Damage Override ──────────────────────────────────────────────────
# Boss is 120x120, so extend the contact distance check.

func _check_contact_damage() -> void:
	if _contact_damage_timer > 0.0:
		return
	var players := get_tree().get_nodes_in_group("players")
	for player in players:
		if not player is Node2D or not player.visible:
			continue
		if player.get("_is_downed") and player._is_downed:
			continue
		if player.get("_is_alive") != null and not player._is_alive:
			continue
		var dist := global_position.distance_to(player.global_position)
		# Larger contact radius for 120x120 boss
		if dist <= 80.0 and player.has_method("take_damage"):
			player.take_damage(contact_damage)
			_contact_damage_timer = CONTACT_DAMAGE_COOLDOWN
			break


# ── Helper ────────────────────────────────────────────────────────────────────

func _find_player_by_id(pid: int) -> Node2D:
	var players := get_tree().get_nodes_in_group("players")
	for player in players:
		if player.get("player_id") == pid:
			return player
	return null


# ── RPCs (boss node exists on all peers via MultiplayerSpawner) ──────────────

@rpc("authority", "call_local", "reliable")
func _show_lunge_telegraph() -> void:
	# Brief red flash to telegraph the incoming lunge
	var sprite = get_node_or_null("Sprite2D") as Sprite2D
	if not sprite:
		return
	var original: Color = sprite.modulate
	sprite.modulate = Color(1.0, 0.2, 0.2, 1.0)  # Red warning flash
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(sprite):
			sprite.modulate = original
	)


@rpc("authority", "call_local", "reliable")
func _show_shield_block() -> void:
	# White flash on the shield visual when a hit is blocked
	var shield_visual = get_node_or_null("ShieldVisual") as ColorRect
	if not shield_visual:
		return
	var original_color: Color = shield_visual.color
	shield_visual.color = Color(1.0, 1.0, 1.0, 0.9)
	get_tree().create_timer(0.2).timeout.connect(func():
		if is_instance_valid(shield_visual):
			shield_visual.color = original_color
	)


@rpc("authority", "call_local", "reliable")
func _notify_phase_change(phase: int) -> void:
	_current_phase = phase
	var type_label = get_node_or_null("TypeLabel") as Label
	if phase == Phase.PHASE_2:
		if type_label:
			type_label.text = "CORE\nDUMP"
	elif phase == Phase.PHASE_3:
		if type_label:
			type_label.text = "BSOD"


@rpc("authority", "call_local", "reliable")
func _notify_boss_died() -> void:
	# Could add death animation here
	pass


# ── Client-Side Visuals ──────────────────────────────────────────────────────

func _update_shield_visual() -> void:
	var shield_visual = get_node_or_null("ShieldVisual") as ColorRect
	if not shield_visual:
		return

	if _current_phase == Phase.PHASE_2 and _shield_active:
		shield_visual.visible = true
		# Position shield on the facing side
		if _shield_facing_left:
			shield_visual.position = Vector2(-70, -60)
		else:
			shield_visual.position = Vector2(50, -60)
	else:
		shield_visual.visible = false


func _update_freeze_visual() -> void:
	var sprite = get_node_or_null("Sprite2D") as Sprite2D
	if not sprite:
		return
	# When frozen (telegraphing), tint slightly red on client
	if _is_frozen and _current_phase != Phase.PHASE_3:
		sprite.modulate = Color(1.0, 0.4, 0.4, 1.0)
	elif _current_phase != Phase.PHASE_3:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _update_phase3_pulse() -> void:
	var sprite = get_node_or_null("Sprite2D") as Sprite2D
	if not sprite:
		return
	# Pulse between blue and white
	var t := (sin(_pulse_timer * 4.0) + 1.0) / 2.0
	sprite.modulate = BOSS_COLOR.lerp(Color(1.0, 1.0, 1.0, 1.0), t)
