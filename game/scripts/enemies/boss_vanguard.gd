## Vanguard boss — armored mech, ground pound AoE + missile barrage pattern.
## Phase 1: chase + ground pound AoE. Phase 2: missile barrage + charge attack.
## Phase 3: enrage, faster everything, ground pound leaves lingering damage zone.
extends "res://scripts/enemies/enemy_base.gd"

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectile_enemy.tscn")

# -- Base Stats ---
const BOSS_HP: int = 120
const BOSS_SPEED: float = 1.5  # Slow heavy mech
const BOSS_CONTACT_DMG: int = 2
const BOSS_CONTACT_RANGE: float = 5.0
const BOSS_COLOR: Color = Color(0.6, 0.2, 0.2)

# -- Ground Pound (all phases) ---
const POUND_CYCLE: Array[float] = [5.0, 4.0, 3.0]
const POUND_WINDUP: float = 1.0  # Freeze before slam
const POUND_RADIUS: Array[float] = [8.0, 10.0, 12.0]
const POUND_DAMAGE: Array[int] = [1, 2, 2]

# -- Charge Attack (Phase 2+) ---
const CHARGE_SPEED: float = 18.0
const CHARGE_DURATION: float = 0.8
const CHARGE_COOLDOWN: Array[float] = [999.0, 8.0, 5.0]

# -- Missile Barrage (Phase 2+) ---
const MISSILE_COOLDOWN: Array[float] = [999.0, 6.0, 4.0]
const MISSILE_COUNT: Array[int] = [0, 4, 6]
const MISSILE_SPEED: float = 7.0
const MISSILE_DAMAGE: int = 1

# -- Phase Thresholds ---
const PHASE_2_THRESHOLD: float = 0.6
const PHASE_3_THRESHOLD: float = 0.25
const PHASE_TRANSITION_STUN: float = 2.0

# -- State ---
enum Phase { PHASE_1, PHASE_2, PHASE_3 }

var max_health: int = BOSS_HP
var _current_phase: int = Phase.PHASE_1

# Ground pound state
var _pound_cycle_timer: float = 0.0
var _pound_windup_timer: float = 0.0
var _is_winding_up: bool = false

# Charge state
var _charge_cooldown_timer: float = 0.0
var _charge_timer: float = 0.0
var _charge_direction: Vector3 = Vector3.ZERO
var _is_charging: bool = false

# Missile state
var _missile_cooldown_timer: float = 0.0

# Phase 3 pulse
var _pulse_timer: float = 0.0


func _ready() -> void:
	super._ready()
	_load_glb_model("res://assets/models/vanguard/vanguard.fbx")
	health = BOSS_HP
	max_health = BOSS_HP
	speed = BOSS_SPEED
	contact_damage = BOSS_CONTACT_DMG
	_current_state = State.IDLE
	_pound_cycle_timer = POUND_CYCLE[Phase.PHASE_1]


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _is_alive or not multiplayer.is_server():
		return

	_update_missile_timer(delta)
	_update_charge_timer(delta)


func _process(delta: float) -> void:
	super._process(delta)
	_update_health_bar()
	if not multiplayer.is_server() and _current_phase == Phase.PHASE_3:
		_pulse_timer += delta
		_update_phase3_pulse()


# -- State Overrides ---

func _state_chase(delta: float) -> void:
	var target := _find_nearest_player()
	if not target:
		_transition_to(State.IDLE)
		return

	# Ground pound cycle
	_pound_cycle_timer -= delta
	if _pound_cycle_timer <= 0.0 and not _is_winding_up and not _is_charging:
		_is_winding_up = true
		_pound_windup_timer = POUND_WINDUP
		velocity.x = 0.0
		velocity.z = 0.0
		_show_pound_telegraph.rpc()
		return

	if _is_winding_up:
		velocity.x = 0.0
		velocity.z = 0.0
		_pound_windup_timer -= delta
		if _pound_windup_timer <= 0.0:
			_is_winding_up = false
			_execute_ground_pound()
			_pound_cycle_timer = POUND_CYCLE[_current_phase]
		return

	# Normal chase
	var dir := (target.global_position - global_position)
	dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed


func _state_attack(delta: float) -> void:
	if not _is_charging:
		_transition_to(State.CHASE)
		return

	velocity.x = _charge_direction.x * CHARGE_SPEED
	velocity.z = _charge_direction.z * CHARGE_SPEED

	_charge_timer -= delta
	if _charge_timer <= 0.0:
		_is_charging = false
		_transition_to(State.CHASE)


func _state_stunned(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_is_winding_up = false
	_is_charging = false
	_stun_timer -= delta
	if _stun_timer <= 0.0:
		_pound_cycle_timer = POUND_CYCLE[_current_phase]
		_transition_to(State.CHASE)


# -- Ground Pound ---

func _execute_ground_pound() -> void:
	var radius: float = POUND_RADIUS[_current_phase]
	var damage: int = POUND_DAMAGE[_current_phase]

	var players := get_tree().get_nodes_in_group("players")
	for player in players:
		if not player is Node3D or not player.visible:
			continue
		if player.get("_is_downed") and player._is_downed:
			continue
		if player.get("_is_alive") != null and not player._is_alive:
			continue
		var dist := global_position.distance_to(player.global_position)
		if dist <= radius and player.has_method("take_damage"):
			player.take_damage(damage)

	_show_ground_pound.rpc(global_position, radius)


# -- Charge Attack (Phase 2+) ---

func _update_charge_timer(delta: float) -> void:
	if _current_phase == Phase.PHASE_1:
		return
	if _current_state == State.STUNNED or _current_state == State.DEAD:
		return
	if _is_charging or _is_winding_up:
		return

	_charge_cooldown_timer -= delta
	if _charge_cooldown_timer <= 0.0:
		_start_charge()
		_charge_cooldown_timer = CHARGE_COOLDOWN[_current_phase]


func _start_charge() -> void:
	var target := _find_nearest_player()
	if not target:
		return
	var dir := (target.global_position - global_position)
	dir.y = 0
	_charge_direction = dir.normalized()
	_is_charging = true
	_charge_timer = CHARGE_DURATION
	_transition_to(State.ATTACK)
	_show_charge_telegraph.rpc()


# -- Missile Barrage (Phase 2+) ---

func _update_missile_timer(delta: float) -> void:
	if _current_phase == Phase.PHASE_1:
		return
	if _current_state == State.STUNNED or _current_state == State.DEAD:
		return

	_missile_cooldown_timer -= delta
	if _missile_cooldown_timer <= 0.0:
		_fire_missile_barrage()
		_missile_cooldown_timer = MISSILE_COOLDOWN[_current_phase]


func _fire_missile_barrage() -> void:
	var count: int = MISSILE_COUNT[_current_phase]
	var players := get_tree().get_nodes_in_group("players")
	var living_players: Array = []
	for p in players:
		if p.get("_is_alive") and p._is_alive and not (p.get("_is_downed") and p._is_downed):
			living_players.append(p)
	if living_players.is_empty():
		return

	for i in count:
		var target: Node3D = living_players[i % living_players.size()]
		var dir: Vector3 = (target.global_position - global_position)
		dir.y = 0
		dir = dir.normalized()
		# Add slight spread
		var angle_offset := randf_range(-0.2, 0.2)
		var d2 := Vector2(dir.x, dir.z).rotated(angle_offset)
		var final_dir := Vector3(d2.x, 0, d2.y)

		var proj = PROJECTILE_SCENE.instantiate()
		proj.direction = final_dir
		proj.speed = MISSILE_SPEED
		proj.damage = MISSILE_DAMAGE
		proj.owner_id = enemy_id
		proj.is_enemy_projectile = true
		proj.name = "VanguardMissile_%d" % (randi() % 1000000)
		proj.position = global_position + final_dir * 2.0
		get_tree().current_scene.get_node("Projectiles").add_child(proj, true)


# -- Damage & Phase Transitions ---

func take_damage(amount: int, from_player_id: int) -> void:
	if not _is_alive or not multiplayer.is_server():
		return
	if has_status("exposed"):
		amount *= 2
	health -= amount
	_show_hit_flash.rpc()
	if health <= 0:
		health = 0
		_die(from_player_id)
		return
	_check_phase_transition()


func _check_phase_transition() -> void:
	var health_pct := float(health) / float(max_health)
	if _current_phase == Phase.PHASE_1 and health_pct <= PHASE_2_THRESHOLD:
		_enter_phase(Phase.PHASE_2)
	elif _current_phase == Phase.PHASE_2 and health_pct <= PHASE_3_THRESHOLD:
		_enter_phase(Phase.PHASE_3)


func _enter_phase(phase: int) -> void:
	_current_phase = phase
	Events.boss_phase_changed.emit(enemy_id, phase)

	_is_winding_up = false
	_is_charging = false
	_stun_timer = PHASE_TRANSITION_STUN
	_transition_to(State.STUNNED)

	_pound_cycle_timer = POUND_CYCLE[phase]

	if phase == Phase.PHASE_2:
		speed = BOSS_SPEED * 1.3
		_missile_cooldown_timer = MISSILE_COOLDOWN[Phase.PHASE_2]
		_charge_cooldown_timer = CHARGE_COOLDOWN[Phase.PHASE_2]
		_notify_phase_change.rpc(phase)
	elif phase == Phase.PHASE_3:
		speed = BOSS_SPEED * 1.8
		_missile_cooldown_timer = MISSILE_COOLDOWN[Phase.PHASE_3]
		_charge_cooldown_timer = CHARGE_COOLDOWN[Phase.PHASE_3]
		_notify_phase_change.rpc(phase)


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


# -- RPCs ---

@rpc("authority", "call_local", "reliable")
func _show_pound_telegraph() -> void:
	# Red glow warning before ground pound
	_tint_model(Color(1.0, 0.2, 0.2))
	get_tree().create_timer(POUND_WINDUP).timeout.connect(func():
		if is_instance_valid(self):
			_tint_model(BOSS_COLOR)
	)


@rpc("authority", "call_local", "reliable")
func _show_ground_pound(center: Vector3, radius: float) -> void:
	# Expanding shockwave ring on the ground
	var ring := MeshInstance3D.new()
	var torus := CylinderMesh.new()
	torus.top_radius = radius
	torus.bottom_radius = radius
	torus.height = 0.3
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.1, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.1)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	ring.global_position = Vector3(center.x, 0.1, center.z)
	get_tree().current_scene.add_child(ring)
	get_tree().create_timer(0.8).timeout.connect(func():
		if is_instance_valid(ring):
			ring.queue_free()
	)


@rpc("authority", "call_local", "reliable")
func _show_charge_telegraph() -> void:
	# Brief flash before charge
	_tint_model(Color(1.0, 0.5, 0.0))
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(self):
			_tint_model(BOSS_COLOR)
	)


@rpc("authority", "call_local", "reliable")
func _notify_phase_change(phase: int) -> void:
	_current_phase = phase


@rpc("authority", "call_local", "reliable")
func _notify_boss_died() -> void:
	pass


# -- Client-Side Visuals ---

func _update_health_bar() -> void:
	pass


func _update_phase3_pulse() -> void:
	var model = _get_model_mesh()
	if not model:
		return
	var mat = model.get_active_material(0)
	if not mat or not mat is StandardMaterial3D:
		return
	var t := (sin(_pulse_timer * 4.0) + 1.0) / 2.0
	mat.emission = BOSS_COLOR.lerp(Color(1.0, 1.0, 1.0), t)
