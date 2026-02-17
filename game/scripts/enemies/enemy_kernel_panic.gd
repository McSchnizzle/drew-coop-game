## Kernel Panic boss — BSOD blue rectangle, halt-lunge attack pattern.
## Phase 1: chase + halt-lunge. Phase 2: shield + projectiles + crash dumps.
## Phase 3: enrage, no shield, faster attacks, visual pulse.
extends "res://scripts/enemies/enemy_base.gd"

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectile_enemy.tscn")
const MERGE_CONFLICT_SCENE_PATH: String = "res://scenes/enemies/enemy_merge_conflict.tscn"

# -- Base Stats (converted: speeds / 20) ---
const BOSS_HP: int = 80
const BOSS_SPEED: float = 1.75  # 35px / 20
const BOSS_CONTACT_DMG: int = 20
const BOSS_CONTACT_RANGE: float = 4.0  # 80px / 20
const BOSS_COLOR: Color = Color(0.0, 0.3, 0.9)

# -- Lunge Parameters (per phase, speeds / 20) ---
const LUNGE_CYCLE:    Array[float] = [4.0, 3.0, 2.0]
const FREEZE_DURATION: Array[float] = [1.0, 0.7, 0.5]
const LUNGE_SPEED:    Array[float] = [12.5, 14.0, 15.0]  # 250/20, 280/20, 300/20
const LUNGE_DURATION: float = 0.5

# -- Projectile Parameters (speed / 20) ---
const PROJ_SPEED: float = 9.0  # 180px / 20
const PROJ_DAMAGE: int = 8
const PROJ_COOLDOWN: Array[float] = [999.0, 5.0, 3.0]
const PROJ_COUNT: Array[int] = [0, 3, 5]
const PROJ_SPREAD_DEG: Array[float] = [0.0, 30.0, 36.0]

# -- Crash Dump (Phase 2 only) ---
const CRASH_DUMP_COOLDOWN: float = 12.0
const CRASH_DUMP_COUNT: int = 2

# -- Shield (Phase 2 only) ---
const SHIELD_FLANK_WINDOW: float = 2.0
const SHIELD_DROP_DURATION: float = 4.0

# -- Phase Thresholds ---
const PHASE_2_THRESHOLD: float = 0.6
const PHASE_3_THRESHOLD: float = 0.25
const PHASE_TRANSITION_STUN: float = 2.0

# -- State ---
enum Phase { PHASE_1, PHASE_2, PHASE_3 }

var max_health: int = BOSS_HP
var _current_phase: int = Phase.PHASE_1

# Halt-lunge state
var _is_frozen: bool = false
var _lunge_cycle_timer: float = 0.0
var _freeze_timer: float = 0.0
var _lunge_timer: float = 0.0
var _lunge_direction: Vector3 = Vector3.ZERO
var _is_lunging: bool = false

# Projectile state
var _proj_cooldown_timer: float = 0.0

# Crash dump state
var _crash_dump_timer: float = 0.0

# Shield state (Phase 2 only)
var _shield_active: bool = false
var _shield_facing_dir: Vector3 = Vector3(-1, 0, 0)  # faces left by default
var _shield_dropped_timer: float = 0.0
var _recent_hit_dirs: Array[Vector3] = []
var _flank_window_timer: float = 0.0

# Phase 3 visual pulse
var _pulse_timer: float = 0.0

# Lazy-loaded scene for crash dump spawns
var _merge_conflict_scene: PackedScene = null


func _ready() -> void:
	super._ready()
	_load_glb_model("res://assets/models/monster_dragon.fbx")
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
	super._process(delta)
	_update_health_bar()
	# Client-side visuals only
	if multiplayer.is_server():
		return
	_update_shield_visual()
	_update_freeze_visual()
	if _current_phase == Phase.PHASE_3:
		_pulse_timer += delta
		_update_phase3_pulse()


# -- State Overrides ---

func _state_chase(delta: float) -> void:
	var target := _find_nearest_player()
	if not target:
		_transition_to(State.IDLE)
		return

	# Halt-lunge cycle
	_lunge_cycle_timer -= delta
	if _lunge_cycle_timer <= 0.0 and not _is_frozen and not _is_lunging:
		_is_frozen = true
		_freeze_timer = FREEZE_DURATION[_current_phase]
		var dir := (target.global_position - global_position)
		dir.y = 0
		_lunge_direction = dir.normalized()
		velocity.x = 0.0
		velocity.z = 0.0
		_show_lunge_telegraph.rpc()
		return

	if _is_frozen:
		velocity.x = 0.0
		velocity.z = 0.0
		_freeze_timer -= delta
		if _freeze_timer <= 0.0:
			_is_frozen = false
			_is_lunging = true
			_lunge_timer = LUNGE_DURATION
			_transition_to(State.ATTACK)
		return

	# Normal chase movement
	var dir := (target.global_position - global_position)
	dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed


func _state_attack(delta: float) -> void:
	if not _is_lunging:
		_transition_to(State.CHASE)
		return

	velocity.x = _lunge_direction.x * LUNGE_SPEED[_current_phase]
	velocity.z = _lunge_direction.z * LUNGE_SPEED[_current_phase]

	_lunge_timer -= delta
	if _lunge_timer <= 0.0:
		_is_lunging = false
		_lunge_cycle_timer = LUNGE_CYCLE[_current_phase]
		_transition_to(State.CHASE)


func _state_stunned(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_is_frozen = false
	_is_lunging = false
	_stun_timer -= delta
	if _stun_timer <= 0.0:
		_lunge_cycle_timer = LUNGE_CYCLE[_current_phase]
		_transition_to(State.CHASE)


# -- Damage & Shield ---

func take_damage(amount: int, from_player_id: int) -> void:
	if not _is_alive or not multiplayer.is_server():
		return

	# Shield check (Phase 2 only)
	if _current_phase == Phase.PHASE_2 and _shield_active:
		var attacker := _find_player_by_id(from_player_id)
		if attacker:
			var hit_dir := (global_position - attacker.global_position)
			hit_dir.y = 0
			hit_dir = hit_dir.normalized()
			if hit_dir.dot(_shield_facing_dir) > 0.0:
				_show_shield_block.rpc()
				_recent_hit_dirs.append(hit_dir)
				return
			else:
				_recent_hit_dirs.append(hit_dir)

		_check_flank_break()

	if has_status("exposed"):
		amount *= 2
	health -= amount
	_show_hit_flash.rpc()

	if health <= 0:
		health = 0
		_die(from_player_id)
		return

	_check_phase_transition()


func _check_flank_break() -> void:
	for i in range(_recent_hit_dirs.size()):
		for j in range(i + 1, _recent_hit_dirs.size()):
			if _recent_hit_dirs[i].dot(_recent_hit_dirs[j]) < 0.0:
				_shield_active = false
				_shield_dropped_timer = SHIELD_DROP_DURATION
				apply_status("exposed", SHIELD_DROP_DURATION)
				_recent_hit_dirs.clear()
				_flank_window_timer = 0.0
				return


func _check_phase_transition() -> void:
	var health_pct := float(health) / float(max_health)

	if _current_phase == Phase.PHASE_1 and health_pct <= PHASE_2_THRESHOLD:
		_enter_phase(Phase.PHASE_2)
	elif _current_phase == Phase.PHASE_2 and health_pct <= PHASE_3_THRESHOLD:
		_enter_phase(Phase.PHASE_3)


func _enter_phase(phase: int) -> void:
	_current_phase = phase
	Events.boss_phase_changed.emit(enemy_id, phase)

	_is_frozen = false
	_is_lunging = false
	_stun_timer = PHASE_TRANSITION_STUN
	_transition_to(State.STUNNED)

	_lunge_cycle_timer = LUNGE_CYCLE[phase]

	if phase == Phase.PHASE_2:
		_shield_active = true
		_shield_facing_dir = Vector3(-1, 0, 0)
		_proj_cooldown_timer = PROJ_COOLDOWN[Phase.PHASE_2]
		_crash_dump_timer = CRASH_DUMP_COOLDOWN
		_notify_phase_change.rpc(phase)
	elif phase == Phase.PHASE_3:
		_shield_active = false
		_proj_cooldown_timer = PROJ_COOLDOWN[Phase.PHASE_3]
		_notify_phase_change.rpc(phase)


# -- Projectile Spread ---

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

	var base_dir := (target.global_position - global_position)
	base_dir.y = 0
	base_dir = base_dir.normalized()
	var count: int = PROJ_COUNT[_current_phase]
	var spread_deg: float = PROJ_SPREAD_DEG[_current_phase]

	var angles: Array[float] = [0.0]
	if count >= 3:
		angles.append(deg_to_rad(spread_deg))
		angles.append(deg_to_rad(-spread_deg))
	if count >= 5:
		angles.append(deg_to_rad(spread_deg * 2.0))
		angles.append(deg_to_rad(-spread_deg * 2.0))

	for angle in angles:
		# Rotate base_dir around Y axis for projectile spread
		var d2 := Vector2(base_dir.x, base_dir.z).rotated(angle)
		var dir := Vector3(d2.x, 0, d2.y)
		var proj = PROJECTILE_SCENE.instantiate()
		proj.direction = dir
		proj.speed = PROJ_SPEED
		proj.damage = PROJ_DAMAGE
		proj.owner_id = enemy_id
		proj.is_enemy_projectile = true
		proj.status_effect = "panic"
		proj.name = "BossProj_%d" % (randi() % 1000000)
		proj.position = global_position + dir * 1.5  # 30px / 20 = 1.5 units
		get_tree().current_scene.get_node("Projectiles").add_child(proj, true)


# -- Crash Dump Spawns (Phase 2 only) ---

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
		enemy.position = global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		enemies_node.add_child(enemy, true)


# -- Shield Logic ---

func _update_shield_timers(delta: float) -> void:
	if _current_phase != Phase.PHASE_2:
		return

	if _recent_hit_dirs.size() > 0:
		_flank_window_timer += delta
		if _flank_window_timer >= SHIELD_FLANK_WINDOW:
			_recent_hit_dirs.clear()
			_flank_window_timer = 0.0

	if not _shield_active and _shield_dropped_timer > 0.0:
		_shield_dropped_timer -= delta
		if _shield_dropped_timer <= 0.0:
			_shield_active = true
			_recent_hit_dirs.clear()

	if _shield_active:
		_update_shield_facing()


func _update_shield_facing() -> void:
	var target := _find_nearest_player()
	if target:
		var dir := (target.global_position - global_position)
		dir.y = 0
		if dir.length_squared() > 0.001:
			_shield_facing_dir = dir.normalized()


# -- Death ---

func _die(killed_by: int) -> void:
	_is_alive = false
	_current_state = State.DEAD
	velocity = Vector3.ZERO
	_transition_to(State.DEAD)
	Events.enemy_died.emit(enemy_id, killed_by, false)
	Events.boss_died.emit(enemy_id, killed_by)
	_notify_boss_died.rpc()
	_delayed_free()


# -- Scaling Override ---

func apply_scaling(health_scale: float, _speed_scale: float) -> void:
	health = int(ceil(health * health_scale))
	max_health = health


# -- Contact Damage Override ---
# Boss is 6.0 units, so extend the contact distance check.

func _check_contact_damage() -> void:
	if _contact_damage_timer > 0.0:
		return
	var players := get_tree().get_nodes_in_group("players")
	for player in players:
		if not player is Node3D or not player.visible:
			continue
		if player.get("_is_downed") and player._is_downed:
			continue
		if player.get("_is_alive") != null and not player._is_alive:
			continue
		var dist := global_position.distance_to(player.global_position)
		if dist <= BOSS_CONTACT_RANGE and player.has_method("take_damage"):
			player.take_damage(contact_damage)
			_contact_damage_timer = CONTACT_DAMAGE_COOLDOWN
			_show_melee_strike.rpc(global_position.lerp(player.global_position, 0.5))
			break


# -- Helper ---

func _find_player_by_id(pid: int) -> Node3D:
	var players := get_tree().get_nodes_in_group("players")
	for player in players:
		if player.get("player_id") == pid:
			return player
	return null


# -- RPCs (boss node exists on all peers via MultiplayerSpawner) ---

@rpc("authority", "call_local", "reliable")
func _show_lunge_telegraph() -> void:
	var model = _get_model_mesh()
	if not model:
		return
	var mat = model.get_active_material(0)
	if not mat or not mat is StandardMaterial3D:
		return
	var original_emission: Color = mat.emission
	mat.emission = Color(1.0, 0.2, 0.2)
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(model) and mat:
			mat.emission = original_emission
	)


@rpc("authority", "call_local", "reliable")
func _show_shield_block() -> void:
	var shield_visual = get_node_or_null("ShieldVisual") as MeshInstance3D
	if not shield_visual:
		return
	var mat = shield_visual.material_override as StandardMaterial3D
	if not mat:
		return
	var original_emission: Color = mat.emission
	mat.emission = Color(1.0, 1.0, 1.0)
	get_tree().create_timer(0.2).timeout.connect(func():
		if is_instance_valid(shield_visual) and mat:
			mat.emission = original_emission
	)


@rpc("authority", "call_local", "reliable")
func _notify_phase_change(phase: int) -> void:
	_current_phase = phase


@rpc("authority", "call_local", "reliable")
func _notify_boss_died() -> void:
	pass


# -- Client-Side Visuals ---

func _update_health_bar() -> void:
	# Boss health bar is now in the HUD CanvasLayer (managed by wave_manager/game_manager).
	# We emit data for the HUD to pick up via the synced health/max_health values.
	# The HUD reads health directly from the boss node.
	pass


func _update_shield_visual() -> void:
	var shield_visual = get_node_or_null("ShieldVisual") as MeshInstance3D
	if not shield_visual:
		return

	if _current_phase == Phase.PHASE_2 and _shield_active:
		shield_visual.visible = true
		# Position shield along the facing direction, 3.0 units out from center
		shield_visual.position = _shield_facing_dir * 3.0
		# Rotate shield to face the same direction
		if _shield_facing_dir.length_squared() > 0.001:
			shield_visual.rotation.y = atan2(_shield_facing_dir.x, _shield_facing_dir.z)
	else:
		shield_visual.visible = false


func _update_freeze_visual() -> void:
	var model = _get_model_mesh()
	if not model:
		return
	var mat = model.get_active_material(0)
	if not mat or not mat is StandardMaterial3D:
		return
	if _is_frozen and _current_phase != Phase.PHASE_3:
		mat.emission = Color(1.0, 0.2, 0.2)
	elif _current_phase != Phase.PHASE_3:
		mat.emission = BOSS_COLOR


func _update_phase3_pulse() -> void:
	var model = _get_model_mesh()
	if not model:
		return
	var mat = model.get_active_material(0)
	if not mat or not mat is StandardMaterial3D:
		return
	var t := (sin(_pulse_timer * 4.0) + 1.0) / 2.0
	mat.emission = BOSS_COLOR.lerp(Color(1.0, 1.0, 1.0), t)
