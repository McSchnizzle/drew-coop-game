## Player script — CharacterBody3D with dual MultiplayerSynchronizer pattern.
## Server reads InputSync variables and applies authoritative physics.
## Each peer writes their own input to InputSync (authority set via player_id).
extends CharacterBody3D

# ── Physics Constants ─────────────────────────────────────────────────────
const RUN_SPEED: float = 8.5
const SPRINT_SPEED: float = 15.0
const JUMP_VELOCITY: float = 8.0
const PLAYER_GRAVITY: float = 20.0

# Sprint stamina
const SPRINT_STAMINA_MAX: float = 100.0
const SPRINT_STAMINA_DRAIN: float = 30.0
const SPRINT_STAMINA_REGEN: float = 20.0

# Shooting (semi-auto: one shot per click, slow repeat if held)
const SHOOT_COOLDOWN: float = 0.45

# Melee
const MELEE_RANGE: float = 3.0
const MELEE_DAMAGE: int = 3
const MELEE_COOLDOWN: float = 0.5

# Crouch
const CROUCH_SPEED: float = 4.0

# ADS (aim down sights)
const ADS_FOV: float = 45.0
const DEFAULT_FOV: float = 75.0
const ADS_SPEED_MULT: float = 0.5
const ADS_LERP_SPEED: float = 12.0

# Mouse look
const MOUSE_SENSITIVITY: float = 0.002

# Projectile scene path
const PROJECTILE_SCENE: String = "res://scenes/projectile.tscn"


# Revive constants
const BLEEDOUT_TIME: float = 30.0

# Role colors for player model
const COLOR_STRIKER: Color = Color(0.3, 0.5, 0.9, 1)
const COLOR_ENGINEER: Color = Color(0.2, 0.8, 0.3, 1)
const COLOR_DEFAULT: Color = Color(0.5, 0.5, 0.6, 1)
const COLOR_DOWNED: Color = Color(0.4, 0.4, 0.4, 1)

# ── Exported Properties ──────────────────────────────────────────────────
@export var player_id: int = 1:
	set(id):
		player_id = id
		$InputSync.set_multiplayer_authority(id)

# ── Synced State (replicated by ServerSync to all peers) ─────────────────
var health: int = 3
var stamina: float = SPRINT_STAMINA_MAX
var _is_downed: bool = false
var _bleedout_timer: float = 0.0
var ability_cooldown: float = 0.0
var super_charge: float = 0.0
var active_statuses: PackedStringArray = PackedStringArray()
var _synced_yaw: float = 0.0  # Player facing direction (replicated to all peers)
var _is_alive: bool = true
var ammo_in_mag: int = 8
var reserve_ammo: int = 40

# ── Input Variables (replicated by InputSync from owning peer to server) ─
var input_move_dir: Vector3 = Vector3.ZERO
var input_aim_dir: Vector3 = Vector3.FORWARD
var input_shoot: bool = false
var input_sprint: bool = false
var input_melee: bool = false
var input_ability: bool = false
var input_super: bool = false
var input_interact: bool = false
var input_jump: bool = false
var input_crouch: bool = false
var input_aim: bool = false
var input_reload: bool = false
var _input_yaw: float = 0.0  # Player facing direction (synced from owning peer to server)

# ── Camera State (synced for remote player head tilt) ────────────────────
var _camera_pitch: float = 0.0

# ── Internal State (not synced) ──────────────────────────────────────────
var _was_downed: bool = false  # Track downed transition for animation
var _shoot_cooldown_timer: float = 0.0
var _shoot_pressed_last_frame: bool = false
var _melee_cooldown_timer: float = 0.0
var _is_reloading: bool = false
var _reload_timer: float = 0.0
var _recoil_tween: Tween = null
var _vm_recoil_tween: Tween = null
var _gun_base_rot_x: float = 0.0      # True rest rotation (world gun)
var _vm_gun_base_rot_x: float = 0.0   # True rest rotation (viewmodel gun)
var _recoil_lock_timer: float = 0.0    # Blocks shooting until gun settles
const RECOIL_LOCK_TIME: float = 0.65   # Visible recoil must finish before next shot
const MAG_SIZE: int = 8
const RESERVE_MAX: int = 40
const RELOAD_TIME: float = 1.8
var _projectile_scene: PackedScene = null
var _sprint_toggled: bool = false
var _crouch_toggled: bool = false
var _status_effects: Dictionary = {}
var _is_reviving_someone: bool = false
var _using_controller: bool = false
var _is_repo_owner: bool = false
var _current_role: String = "striker"
var _anim_player: AnimationPlayer = null
var _current_anim: String = ""
var _loaded_model: Node3D = null  # The current role's model instance
var _gun_node: Node3D = null
var _gun_anim_player: AnimationPlayer = null
var _gun_bone_attach: BoneAttachment3D = null
var _vm_camera: Camera3D = null     # Viewmodel camera (own world SubViewport)
var _vm_viewport: SubViewport = null
var _vm_overlay: TextureRect = null
var _vm_model: Node3D = null        # Duplicate player model in viewmodel world
var _vm_anim_player: AnimationPlayer = null
var _vm_gun: Node3D = null          # Duplicate gun in viewmodel world
var _anim_override: String = ""  # One-shot anim that overrides locomotion
var _anim_override_timer: float = 0.0  # Time remaining for override
const ANIM_BLEND: float = 0.25
# Viewmodel positions: hip-fire vs ADS (dedicated FPS arms model)
var VM_POS_HIP := Vector3(0.23, -1.8, -0.36)
var VM_POS_ADS := Vector3(-0.1, -1.7, -0.25)
# Per-role ADS offsets (applied on top of VM_POS_ADS)
const VM_ADS_ROLE_OFFSET := {
	"engineer": Vector3(0.03, -0.04, 0.0),
}
var _vm_debug_label: Label = null
var _vm_debug_mode: int = 0  # 0=model pos, 1=gun pos, 2=gun rot, 3=gun scale
var _vm_debug_t_held: bool = false
var _hit_shake_tween: Tween = null
var _damage_vignette: ColorRect = null
var _vignette_tween: Tween = null
# HUD node references (built programmatically for local player)
var _hud_ammo_mag: Label = null
var _hud_ammo_reserve: Label = null
var _hud_stamina_bar: ProgressBar = null
var _hud_ability_label: Label = null
var _hud_super_label: Label = null
var _hud_super_bar: ProgressBar = null
var _hud_kill_feed: VBoxContainer = null
var _hud_teammate_box: VBoxContainer = null
var _vm_gun_pos := Vector3(-0.03, 0.18, 0.04)
var _vm_gun_rot := Vector3(80.0, 180.0, 90.0)
var _vm_gun_scale := 0.255
const VM_DEBUG_STEP := 0.01
const VM_DEBUG_ROT_STEP := 5.0
const ROLE_MODELS := {
	"striker": "res://assets/models/striker/striker.fbx",
	"engineer": "res://assets/models/pete/pete.fbx",
}
# Arms-only models for viewmodel (extracted via Blender — no body, just arms/hands)
const ROLE_ARMS := {
	"striker": "res://assets/models/striker/striker_arms.fbx",
	"engineer": "res://assets/models/pete/pete_arms.fbx",
}


func _ready() -> void:
	_projectile_scene = load(PROJECTILE_SCENE)

	if name.is_valid_int():
		player_id = name.to_int()

	# Load player model based on role (default striker, swapped if role changes)
	_load_role_model(_current_role)

	# Load gun model and attach to hand bone for all players
	var pistol_scene = load("res://assets/models/pistol_cyberpunk.glb")
	if pistol_scene:
		_gun_node = pistol_scene.instantiate()
		_gun_anim_player = _find_anim_player_in(_gun_node)
		_attach_gun_to_hand()

	# Only the local player gets the camera and mouse capture.
	if player_id == multiplayer.get_unique_id():
		$CameraMount/Camera3D.make_current()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		# Hide own body from main camera — the viewmodel renders arms/gun separately
		$PlayerModel.visible = false
		_setup_viewmodel_viewport()
		_build_hud()

	# Layer 2 = players. Mask includes layer 1 (walls) + layer 3 (enemies).
	collision_layer = 2
	collision_mask = 5

	add_to_group("players")

	if name == "1":
		_is_repo_owner = true


func _input(event: InputEvent) -> void:
	if player_id != multiplayer.get_unique_id():
		return
	if not get_window().has_focus():
		return

	# Mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Yaw: rotate the player body
		rotation.y -= event.relative.x * MOUSE_SENSITIVITY
		# Pitch: rotate the camera mount (clamped)
		_camera_pitch -= event.relative.y * MOUSE_SENSITIVITY
		_camera_pitch = clampf(_camera_pitch, deg_to_rad(-85), deg_to_rad(85))
		$CameraMount.rotation.x = _camera_pitch

	# ESC to release/recapture mouse
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Click to recapture mouse
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(delta: float) -> void:
	# Remote players: apply synced rotation + tilt model
	if player_id != multiplayer.get_unique_id():
		rotation.y = _synced_yaw
		$PlayerModel.rotation.x = _camera_pitch * 0.3
		$CameraMount.rotation.x = _camera_pitch
		return

	# Smoothly lower/raise camera when crouching
	const CAMERA_STANDING_Y = 1.5
	const CAMERA_CROUCH_Y = 0.9
	const CAMERA_CROUCH_LERP_SPEED = 10.0
	var target_cam_y := CAMERA_CROUCH_Y if input_crouch else CAMERA_STANDING_Y
	$CameraMount.position.y = lerpf($CameraMount.position.y, target_cam_y, CAMERA_CROUCH_LERP_SPEED * delta)

	# ADS: smoothly lerp main camera FOV
	var cam := $CameraMount/Camera3D as Camera3D
	var target_fov := ADS_FOV if input_aim else DEFAULT_FOV
	cam.fov = lerpf(cam.fov, target_fov, ADS_LERP_SPEED * delta)
	# Viewmodel: camera pitch follows main camera, ADS FOV
	if _vm_camera:
		_vm_camera.rotation.x = _camera_pitch  # Arms follow look direction
		var vm_target_fov := 35.0 if input_aim else 45.0
		_vm_camera.fov = lerpf(_vm_camera.fov, vm_target_fov, ADS_LERP_SPEED * delta)

	# ADS: smoothly lerp viewmodel position between hip-fire and centered
	# Reload: shift up so the reload animation is more visible
	if _vm_model and is_instance_valid(_vm_model):
		var target_pos := VM_POS_HIP
		if _is_reloading:
			target_pos = VM_POS_HIP + Vector3(0.0, 0.15, 0.1)
		elif input_aim:
			target_pos = VM_POS_ADS + VM_ADS_ROLE_OFFSET.get(_current_role, Vector3.ZERO)
		_vm_model.position = _vm_model.position.lerp(target_pos, ADS_LERP_SPEED * delta)

	# Slow viewmodel idle animation while ADS for stability (no hand sway)
	# Don't slow down oneshot anims like Shoot. Lerp to avoid jitter from rapid toggling.
	if _vm_anim_player:
		var target_speed := 0.15 if (input_aim and _anim_override == "") else 1.0
		_vm_anim_player.speed_scale = lerpf(_vm_anim_player.speed_scale, target_speed, 8.0 * delta)

	# Apply bone modifications after animation (deferred so it runs after anim update)
	call_deferred("_apply_vm_bone_overrides")

	_vm_debug_update()



func _physics_process(delta: float) -> void:
	# Update animation on all peers (uses synced velocity/state)
	_update_player_animation()

	if not _is_alive:
		return

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
		_synced_yaw = rotation.y


# ── Input Gathering (runs on owning peer only) ──────────────────────────

func _gather_input() -> void:
	if not get_window().has_focus():
		input_move_dir = Vector3.ZERO
		input_sprint = false
		input_shoot = false
		input_melee = false
		input_ability = false
		input_super = false
		input_interact = false
		input_jump = false
		input_crouch = false
		input_aim = false
		input_reload = false
		return

	# Camera-relative WASD movement
	var move_x := Input.get_axis("move_left", "move_right")
	var move_z := Input.get_axis("move_up", "move_down")

	var forward := Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
	var right := Vector3.RIGHT.rotated(Vector3.UP, rotation.y)

	var move_input := forward * (-move_z) + right * move_x
	if move_input.length() > 1.0:
		move_input = move_input.normalized()
	input_move_dir = move_input

	# Auto-detect input device
	var right_stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	if right_stick.length() > 0.2:
		_using_controller = true
	elif Input.get_last_mouse_velocity().length() > 0.0:
		_using_controller = false

	# Aim direction: camera forward vector (full 3D including pitch)
	var cam := $CameraMount/Camera3D as Camera3D
	input_aim_dir = -cam.global_transform.basis.z

	# Controller right stick look (if using controller)
	if _using_controller and right_stick.length() > 0.2:
		rotation.y -= right_stick.x * 0.05
		_camera_pitch -= right_stick.y * 0.05
		_camera_pitch = clampf(_camera_pitch, deg_to_rad(-85), deg_to_rad(85))
		$CameraMount.rotation.x = _camera_pitch
		input_aim_dir = -cam.global_transform.basis.z

	# One-shot inputs
	input_shoot = Input.is_action_pressed("shoot")
	input_melee = Input.is_action_just_pressed("melee")
	input_ability = Input.is_action_just_pressed("ability")
	input_super = Input.is_action_just_pressed("super")
	input_interact = Input.is_action_pressed("interact")
	input_jump = Input.is_action_just_pressed("jump")
	input_aim = Input.is_action_pressed("aim")
	input_reload = Input.is_action_just_pressed("reload")

	# Crouch toggle (cancels sprint)
	if Input.is_action_just_pressed("crouch"):
		_crouch_toggled = not _crouch_toggled
		if _crouch_toggled:
			_sprint_toggled = false
	# Sprint toggle (cancels crouch)
	if Input.is_action_just_pressed("sprint"):
		_sprint_toggled = not _sprint_toggled
		if _sprint_toggled:
			_crouch_toggled = false
	if stamina <= 0.0:
		_sprint_toggled = false
	# Aiming cancels sprint
	if input_aim:
		_sprint_toggled = false
	input_sprint = _sprint_toggled
	input_crouch = _crouch_toggled
	_input_yaw = rotation.y


# ── Server-Side Physics (authoritative game logic) ──────────────────────

func _server_process(delta: float) -> void:
	# Apply client rotation (synced from owning peer via InputSync)
	rotation.y = _input_yaw

	# -- Tick status effects --
	_update_status_effects(delta)

	# -- Sanitize client input --
	if input_move_dir.length() > 1.0:
		input_move_dir = input_move_dir.normalized()

	# Panic status: invert movement controls
	if has_status("panic"):
		input_move_dir = -input_move_dir

	# -- Sprint stamina --
	var is_sprinting := input_sprint and stamina > 0.0 and input_move_dir.length() > 0.0
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
	if input_aim:
		speed_mult *= ADS_SPEED_MULT

	# -- Movement --
	var current_speed: float
	if is_sprinting:
		current_speed = SPRINT_SPEED
	elif input_crouch:
		current_speed = CROUCH_SPEED
	else:
		current_speed = RUN_SPEED
	current_speed *= speed_mult
	velocity.x = input_move_dir.x * current_speed
	velocity.z = input_move_dir.z * current_speed

	# -- Gravity & Jump (jumping cancels crouch) --
	if is_on_floor():
		if input_jump:
			velocity.y = JUMP_VELOCITY
			input_crouch = false
	else:
		velocity.y -= PLAYER_GRAVITY * delta

	# -- Reload --
	if _is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			var transfer := mini(MAG_SIZE - ammo_in_mag, reserve_ammo)
			ammo_in_mag += transfer
			reserve_ammo -= transfer
			_is_reloading = false
	elif input_reload and ammo_in_mag < MAG_SIZE and reserve_ammo > 0 and not _is_reviving_someone:
		_start_reload()
	input_reload = false

	# -- Shooting (blocked during revive and reload) --
	if not _is_reviving_someone and not _is_reloading:
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

	# -- Consume one-shot inputs --
	input_melee = false
	input_jump = false


# ── Shooting System (semi-auto: fires on press, slow repeat if held) ─────

func _process_shooting(delta: float) -> void:
	_shoot_cooldown_timer = maxf(_shoot_cooldown_timer - delta, 0.0)
	_recoil_lock_timer = maxf(_recoil_lock_timer - delta, 0.0)

	var cooldown := SHOOT_COOLDOWN
	if has_status("overdrive"):
		cooldown *= 0.5

	if input_shoot:
		if _recoil_lock_timer > 0.0:
			pass
		elif _shoot_cooldown_timer > 0.0:
			pass  # Blocked — cooldown
		elif ammo_in_mag <= 0:
			if reserve_ammo > 0:
				_start_reload()
		else:
			_fire_projectile()
			ammo_in_mag -= 1
			_shoot_cooldown_timer = cooldown
			if ammo_in_mag <= 0 and reserve_ammo > 0:
				_start_reload()

	_shoot_pressed_last_frame = input_shoot


func _start_reload() -> void:
	if _is_reloading:
		return
	_is_reloading = true
	_reload_timer = RELOAD_TIME
	_play_oneshot_anim.rpc("Reload", RELOAD_TIME)
	# Play gun model's built-in slide animation for reload
	_play_gun_reload_anim()


func _play_gun_reload_anim() -> void:
	if _gun_anim_player:
		_gun_anim_player.stop()
		for anim_name in _gun_anim_player.get_animation_list():
			_gun_anim_player.speed_scale = 1.0
			_gun_anim_player.play(anim_name)
			break
	# Viewmodel gun reload animation
	if _vm_gun and is_instance_valid(_vm_gun):
		var vm_gun_anim := _find_anim_player_in(_vm_gun)
		if vm_gun_anim:
			vm_gun_anim.stop()
			for anim_name in vm_gun_anim.get_animation_list():
				vm_gun_anim.speed_scale = 1.0
				vm_gun_anim.play(anim_name)
				break


func _fire_projectile() -> void:
	if _projectile_scene == null:
		return

	# Lock shooting until recoil settles
	_recoil_lock_timer = RECOIL_LOCK_TIME

	# Trigger shoot animation on all peers (short hold — arms settle before lock expires)
	_play_oneshot_anim.rpc("Shoot", 0.3)

	# Gun recoil is handled entirely by the Shoot arm animation via the skeleton.
	# No separate gun rotation tween — it was stacking on top of the animation.

	# Spawn projectile from camera position along aim direction
	var cam := $CameraMount/Camera3D as Camera3D
	var aim_dir := input_aim_dir.normalized()
	var spawn_pos: Vector3 = cam.global_position + aim_dir * 1.0

	var projectile = _projectile_scene.instantiate()
	projectile.direction = aim_dir
	projectile.owner_id = player_id
	projectile.name = "Projectile_%d" % (randi() % 1000000)

	# Apply damage multiplier from abilities
	var ability_mgr = get_node_or_null("AbilityManager")
	if ability_mgr:
		projectile.damage = int(ceil(projectile.damage * ability_mgr.get_damage_multiplier()))

	projectile.position = spawn_pos

	var projectiles_node = get_tree().current_scene.get_node("Projectiles")
	if projectiles_node:
		projectiles_node.add_child(projectile, true)


# ── Melee Attack ─────────────────────────────────────────────────────────

func _do_melee() -> void:
	_show_melee_visual.rpc(input_aim_dir)
	_play_oneshot_anim.rpc("Melee", 0.6)

	var melee_ability_mgr = get_node_or_null("AbilityManager")
	# Melee is a one-hit kill through wave 8 — scale damage to match enemy HP
	var wave_mgr = get_tree().current_scene.get_node_or_null("WaveManager")
	var current_wave: int = wave_mgr.current_wave if wave_mgr else 1
	var melee_dmg := MELEE_DAMAGE
	if current_wave <= 8:
		# Match the health scaling formula so melee always one-shots
		var health_scale := clampf(1.0 + (current_wave - 1) * 0.35, 1.0, 5.0)
		melee_dmg = int(ceil(3.0 * health_scale))  # enemy base HP * scale
	if melee_ability_mgr:
		melee_dmg = int(ceil(melee_dmg * melee_ability_mgr.get_damage_multiplier()))

	var enemies := get_tree().get_nodes_in_group("enemies")
	var best_enemy: Node3D = null
	var best_dist := INF
	var aim_flat := Vector3(input_aim_dir.x, 0, input_aim_dir.z).normalized()
	for enemy in enemies:
		if not enemy is Node3D:
			continue
		var to_enemy: Vector3 = enemy.global_position - global_position
		to_enemy.y = 0
		var dist := to_enemy.length()
		if dist > MELEE_RANGE:
			continue
		if to_enemy.normalized().dot(aim_flat) <= 0.3:
			continue
		if dist < best_dist:
			best_dist = dist
			best_enemy = enemy
	if best_enemy and best_enemy.has_method("take_damage"):
		best_enemy.take_damage(melee_dmg, player_id)
		if melee_ability_mgr:
			melee_ability_mgr.add_super_charge(melee_ability_mgr.SUPER_CHARGE_PER_MELEE_HIT)


@rpc("authority", "call_local", "unreliable")
func _show_melee_visual(aim_dir: Vector3) -> void:
	# 3D melee arc: a flat box mesh in front of the player that fades out.
	var swing := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 0.3, 1.5)
	swing.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.0)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	swing.material_override = mat
	var flat_aim := Vector3(aim_dir.x, 0, aim_dir.z).normalized()
	swing.position = flat_aim * 1.5 + Vector3(0, 1.0, 0)
	if flat_aim.length() > 0.01:
		swing.rotation.y = atan2(flat_aim.x, flat_aim.z)
	add_child(swing)
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(swing):
			swing.queue_free()
	)


@rpc("authority", "call_local", "reliable")
func _show_overdrive_visual(duration: float) -> void:
	# Glowing sphere around the player for the overdrive duration.
	var visual := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	visual.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.0, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.0)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual.material_override = mat
	visual.position = Vector3(0, 0.9, 0)
	add_child(visual)
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(visual):
			visual.queue_free()
	)


@rpc("authority", "call_local", "reliable")
func _show_healing_visual() -> void:
	# Brief green glow around the player.
	var visual := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.8
	sphere.height = 1.6
	visual.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.3, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 1.0, 0.3)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual.material_override = mat
	visual.position = Vector3(0, 0.9, 0)
	add_child(visual)
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(visual):
			visual.queue_free()
	)


@rpc("authority", "call_local", "reliable")
func _show_scan_visual(center: Vector3, radius: float) -> void:
	# Expanding yellow sphere showing the scan zone.
	var visual := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	visual.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 0.0, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 0.0)
	mat.emission_energy_multiplier = 1.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual.material_override = mat
	visual.global_position = center + Vector3(0, 1.0, 0)
	get_tree().current_scene.add_child(visual)
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(visual):
			visual.queue_free()
	)


# ── HUD Updates (runs on local player only) ─────────────────────────────

func _build_hud() -> void:
	var hud = get_tree().current_scene.get_node_or_null("UI/HUD")
	if not hud:
		return

	# ── Bottom-right: Ammo (COD style) ──
	var ammo_container := VBoxContainer.new()
	ammo_container.name = "AmmoContainer"
	ammo_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_container.offset_left = -160.0
	ammo_container.offset_top = -80.0
	ammo_container.offset_right = -20.0
	ammo_container.offset_bottom = -20.0
	ammo_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ammo_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.add_child(ammo_container)

	_hud_ammo_mag = Label.new()
	_hud_ammo_mag.add_theme_font_size_override("font_size", 48)
	_hud_ammo_mag.add_theme_color_override("font_color", Color.WHITE)
	_hud_ammo_mag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_ammo_mag.text = "8"
	ammo_container.add_child(_hud_ammo_mag)

	_hud_ammo_reserve = Label.new()
	_hud_ammo_reserve.add_theme_font_size_override("font_size", 18)
	_hud_ammo_reserve.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_hud_ammo_reserve.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_ammo_reserve.text = "/ 40"
	ammo_container.add_child(_hud_ammo_reserve)

	# ── Bottom-left: Stamina bar ──
	var bl_container := VBoxContainer.new()
	bl_container.name = "BottomLeftHUD"
	bl_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl_container.offset_left = 20.0
	bl_container.offset_top = -110.0
	bl_container.offset_right = 220.0
	bl_container.offset_bottom = -20.0
	bl_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.add_child(bl_container)

	# Ability label
	_hud_ability_label = Label.new()
	_hud_ability_label.add_theme_font_size_override("font_size", 16)
	_hud_ability_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	_hud_ability_label.text = "[RMB] READY"
	bl_container.add_child(_hud_ability_label)

	# Super label + bar
	_hud_super_label = Label.new()
	_hud_super_label.add_theme_font_size_override("font_size", 16)
	_hud_super_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_hud_super_label.text = "Super: 0%"
	bl_container.add_child(_hud_super_label)

	_hud_super_bar = ProgressBar.new()
	_hud_super_bar.custom_minimum_size = Vector2(180, 8)
	_hud_super_bar.max_value = 100.0
	_hud_super_bar.value = 0.0
	_hud_super_bar.show_percentage = false
	var super_bar_style := StyleBoxFlat.new()
	super_bar_style.bg_color = Color(0.15, 0.15, 0.2)
	super_bar_style.corner_radius_top_left = 3
	super_bar_style.corner_radius_top_right = 3
	super_bar_style.corner_radius_bottom_left = 3
	super_bar_style.corner_radius_bottom_right = 3
	_hud_super_bar.add_theme_stylebox_override("background", super_bar_style)
	var super_bar_fill := StyleBoxFlat.new()
	super_bar_fill.bg_color = Color(0.9, 0.8, 0.1)
	super_bar_fill.corner_radius_top_left = 3
	super_bar_fill.corner_radius_top_right = 3
	super_bar_fill.corner_radius_bottom_left = 3
	super_bar_fill.corner_radius_bottom_right = 3
	_hud_super_bar.add_theme_stylebox_override("fill", super_bar_fill)
	bl_container.add_child(_hud_super_bar)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	bl_container.add_child(spacer)

	# Stamina bar
	_hud_stamina_bar = ProgressBar.new()
	_hud_stamina_bar.custom_minimum_size = Vector2(180, 10)
	_hud_stamina_bar.max_value = SPRINT_STAMINA_MAX
	_hud_stamina_bar.value = SPRINT_STAMINA_MAX
	_hud_stamina_bar.show_percentage = false
	var stam_bg := StyleBoxFlat.new()
	stam_bg.bg_color = Color(0.12, 0.12, 0.18)
	stam_bg.corner_radius_top_left = 4
	stam_bg.corner_radius_top_right = 4
	stam_bg.corner_radius_bottom_left = 4
	stam_bg.corner_radius_bottom_right = 4
	_hud_stamina_bar.add_theme_stylebox_override("background", stam_bg)
	var stam_fill := StyleBoxFlat.new()
	stam_fill.bg_color = Color(0.0, 0.85, 0.9)
	stam_fill.corner_radius_top_left = 4
	stam_fill.corner_radius_top_right = 4
	stam_fill.corner_radius_bottom_left = 4
	stam_fill.corner_radius_bottom_right = 4
	_hud_stamina_bar.add_theme_stylebox_override("fill", stam_fill)
	bl_container.add_child(_hud_stamina_bar)

	# ── Top-right: Kill feed ──
	_hud_kill_feed = VBoxContainer.new()
	_hud_kill_feed.name = "KillFeed"
	_hud_kill_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hud_kill_feed.offset_left = -320.0
	_hud_kill_feed.offset_top = 16.0
	_hud_kill_feed.offset_right = -16.0
	_hud_kill_feed.offset_bottom = 200.0
	_hud_kill_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud.add_child(_hud_kill_feed)
	Events.kill_feed_entry.connect(_on_kill_feed_entry)

	# ── Top-left below wave: Teammate status ──
	_hud_teammate_box = VBoxContainer.new()
	_hud_teammate_box.name = "TeammateStatus"
	_hud_teammate_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hud_teammate_box.offset_left = 16.0
	_hud_teammate_box.offset_top = 50.0
	_hud_teammate_box.offset_right = 200.0
	_hud_teammate_box.offset_bottom = 200.0
	hud.add_child(_hud_teammate_box)

	# ── Damage vignette (fullscreen red flash on hit) ──
	_damage_vignette = ColorRect.new()
	_damage_vignette.name = "DamageVignette"
	_damage_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_vignette.color = Color(0.8, 0.0, 0.0, 0.0)
	_damage_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_damage_vignette)


func _on_kill_feed_entry(killer_name: String, enemy_type: String) -> void:
	if not _hud_kill_feed:
		return
	var entry := Label.new()
	entry.text = "%s killed %s" % [killer_name, enemy_type]
	entry.add_theme_font_size_override("font_size", 14)
	entry.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	entry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_kill_feed.add_child(entry)
	# Remove oldest if > 5
	while _hud_kill_feed.get_child_count() > 5:
		_hud_kill_feed.get_child(0).queue_free()
	# Fade out after 4s
	var fade_tween := entry.create_tween()
	fade_tween.tween_interval(4.0)
	fade_tween.tween_property(entry, "modulate:a", 0.0, 0.5)
	fade_tween.tween_callback(func():
		if is_instance_valid(entry):
			entry.queue_free()
	)


func _show_damage_vignette() -> void:
	if not _damage_vignette:
		return
	if _vignette_tween and _vignette_tween.is_valid():
		_vignette_tween.kill()
	var alpha := 0.3 if health >= 2 else 0.5
	_damage_vignette.color.a = alpha
	_vignette_tween = create_tween()
	_vignette_tween.tween_property(_damage_vignette, "color:a", 0.0, 0.6)


func _update_hud() -> void:
	# Ammo display
	if _hud_ammo_mag:
		if _is_reloading:
			_hud_ammo_mag.text = "---"
			_hud_ammo_mag.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		elif has_status("context_rot"):
			_hud_ammo_mag.text = str(randi() % 99)
			_hud_ammo_mag.add_theme_color_override("font_color", Color(0.5, 1.0, 0.0))
		else:
			_hud_ammo_mag.text = str(ammo_in_mag)
			if ammo_in_mag <= 2:
				_hud_ammo_mag.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			else:
				_hud_ammo_mag.add_theme_color_override("font_color", Color.WHITE)
	if _hud_ammo_reserve:
		if has_status("context_rot"):
			_hud_ammo_reserve.text = "/ %d" % (randi() % 200)
		else:
			_hud_ammo_reserve.text = "/ %d" % reserve_ammo

	# Stamina bar
	if _hud_stamina_bar:
		if has_status("context_rot"):
			_hud_stamina_bar.value = randf() * SPRINT_STAMINA_MAX
		else:
			_hud_stamina_bar.value = stamina

	# Ability cooldown
	if _hud_ability_label:
		if ability_cooldown > 0.0:
			_hud_ability_label.text = "[RMB] %.1fs" % ability_cooldown
			_hud_ability_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			_hud_ability_label.text = "[RMB] READY"
			_hud_ability_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))

	# Super charge
	if _hud_super_label:
		if super_charge >= 100.0:
			_hud_super_label.text = ">> SUPER READY <<"
			_hud_super_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))
		else:
			_hud_super_label.text = "Super: %d%%" % int(super_charge)
			_hud_super_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	if _hud_super_bar:
		_hud_super_bar.value = super_charge

	# Teammate status
	if _hud_teammate_box:
		_update_teammate_display()


func _update_teammate_display() -> void:
	# Clear old entries
	for child in _hud_teammate_box.get_children():
		child.queue_free()
	var players := get_tree().get_nodes_in_group("players")
	for p in players:
		if p.player_id == player_id:
			continue  # Skip self
		var display_name: String = NetworkManager.player_names.get(p.player_id, "Player %d" % p.player_id)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 14)
		if not p._is_alive:
			label.text = "%s  [DEAD]" % display_name
			label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		elif p._is_downed:
			label.text = "%s  [DOWNED]" % display_name
			label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		else:
			var pips := "|".repeat(p.health)
			var color := Color(0.3, 1.0, 0.4) if p.health >= 2 else Color(1.0, 0.6, 0.2)
			label.text = "%s  %s" % [display_name, pips]
			label.add_theme_color_override("font_color", color)
		_hud_teammate_box.add_child(label)


# ── Health / Damage ──────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if not _is_alive:
		return
	if _is_downed:
		return
	health -= amount
	_play_oneshot_anim.rpc("HitReaction", 0.5)
	# Camera shake + damage vignette on hit (local player only)
	if player_id == multiplayer.get_unique_id():
		_show_damage_vignette()
		var cam := $CameraMount/Camera3D as Camera3D
		if cam:
			if _hit_shake_tween and _hit_shake_tween.is_valid():
				_hit_shake_tween.kill()
			var orig_rot := cam.rotation
			_hit_shake_tween = create_tween()
			_hit_shake_tween.tween_property(cam, "rotation", orig_rot + Vector3(randf_range(-0.04, 0.04), randf_range(-0.04, 0.04), 0), 0.04)
			_hit_shake_tween.tween_property(cam, "rotation", orig_rot + Vector3(randf_range(-0.02, 0.02), randf_range(-0.02, 0.02), 0), 0.04)
			_hit_shake_tween.tween_property(cam, "rotation", orig_rot, 0.12)
	if health <= 0:
		health = 0
		die()


func die() -> void:
	_is_downed = true
	_bleedout_timer = BLEEDOUT_TIME
	velocity = Vector3.ZERO
	# KnockedDown animation is triggered by _was_downed detection in _update_player_animation()
	# on all peers (driven by synced _is_downed). No RPC needed — avoids double-play.
	Events.player_downed.emit(player_id, global_position)

	# Disable collision
	var collision = get_node_or_null("CollisionShape3D")
	if collision:
		collision.set_deferred("disabled", true)

	# Visual: gray color on ALL peers
	_show_downed_visual.rpc()

	# Release mouse when downed so player can interact with end screen
	if player_id == multiplayer.get_unique_id():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


@rpc("authority", "call_local", "reliable")
func _show_downed_visual() -> void:
	_set_model_color(COLOR_DOWNED)


func _load_role_model(role: String) -> void:
	# Remove old model if swapping roles
	if _loaded_model:
		_loaded_model.queue_free()
		_loaded_model = null
		_anim_player = null
		_current_anim = ""

	var model_path: String = ROLE_MODELS.get(role, ROLE_MODELS["striker"])
	var player_model_scene = load(model_path)
	if player_model_scene:
		_loaded_model = player_model_scene.instantiate()
		$PlayerModel.add_child(_loaded_model)
		# Auto-scale to collision capsule height
		var target_h := 1.8
		var col = get_node_or_null("CollisionShape3D")
		if col and col.shape is CapsuleShape3D:
			target_h = col.shape.height
		var bounds := _compute_node_bounds(_loaded_model)
		if bounds.size.y > 0.01:
			var s := target_h / bounds.size.y
			_loaded_model.scale *= s
			_loaded_model.position.y = -bounds.position.y * s
	# Hide placeholder meshes
	if $PlayerModel.has_node("Body"):
		$PlayerModel/Body.visible = false
	if $PlayerModel.has_node("Head"):
		$PlayerModel/Head.visible = false
	# Set up animations (Mixamo rig shared across all characters)
	if _loaded_model:
		_anim_player = _load_animations_on(_loaded_model)
		_play_player_anim("Idle")
		# Re-attach gun to hand bone (visible for remote players)
		if _gun_node:
			_attach_gun_to_hand()
		# Local player: hide main body, rebuild viewmodel with new model
		if player_id == multiplayer.get_unique_id():
			$PlayerModel.visible = false
			if _vm_viewport:
				_build_vm_model()


@rpc("authority", "call_local", "reliable")
func _set_role_color(role: String) -> void:
	# Swap model if role changed
	var changed := role != _current_role
	_current_role = role  # Set BEFORE loading so viewmodel picks up correct role
	if changed:
		_load_role_model(role)
	# Use the model's own textures — clear any color override
	_clear_model_color()


func _clear_model_color() -> void:
	for child in _get_all_mesh_instances($PlayerModel):
		child.material_override = null


func _set_model_color(color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.3
	for child in _get_all_mesh_instances($PlayerModel):
		child.material_override = mat


func _disable_backface_culling(node: Node) -> void:
	for mesh_inst in _get_all_mesh_instances(node):
		# Handle material_override (covers whole mesh)
		if mesh_inst.material_override and mesh_inst.material_override is BaseMaterial3D:
			var mat_copy := mesh_inst.material_override.duplicate() as BaseMaterial3D
			mat_copy.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh_inst.material_override = mat_copy
			continue
		# Handle per-surface materials
		if not mesh_inst.mesh:
			continue
		for surf_idx in mesh_inst.mesh.get_surface_count():
			var mat = mesh_inst.get_surface_override_material(surf_idx)
			if not mat:
				mat = mesh_inst.mesh.surface_get_material(surf_idx)
			if mat is BaseMaterial3D:
				var mat_copy := mat.duplicate() as BaseMaterial3D
				mat_copy.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh_inst.set_surface_override_material(surf_idx, mat_copy)
			elif mat == null:
				var new_mat := StandardMaterial3D.new()
				new_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh_inst.set_surface_override_material(surf_idx, new_mat)


func _get_all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_get_all_mesh_instances(child))
	return result


func _compute_node_bounds(root: Node) -> AABB:
	var points: PackedVector3Array = PackedVector3Array()
	_collect_mesh_points(root, Transform3D.IDENTITY, points)
	if points.is_empty():
		return AABB()
	var combined := AABB(points[0], Vector3.ZERO)
	for i in range(1, points.size()):
		combined = combined.expand(points[i])
	return combined


func _collect_mesh_points(node: Node, parent_xform: Transform3D, points: PackedVector3Array) -> void:
	var xform := parent_xform
	if node is Node3D:
		xform = parent_xform * node.transform
	if node is MeshInstance3D and node.mesh:
		var aabb: AABB = node.mesh.get_aabb()
		for i in 8:
			points.append(xform * aabb.get_endpoint(i))
	for child in node.get_children():
		_collect_mesh_points(child, xform, points)



func _is_grounded() -> bool:
	# Server has accurate floor detection from move_and_slide().
	# Clients never call move_and_slide(), so is_on_floor() is always false.
	if multiplayer.is_server():
		return is_on_floor()
	return global_position.y < 1.0 and absf(velocity.y) < 2.0


# ── Animation System ─────────────────────────────────────────────────────

func _find_anim_player_in(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player_in(child)
		if found:
			return found
	return null


func _get_bone_names(skeleton: Skeleton3D) -> Array[String]:
	var names: Array[String] = []
	for i in skeleton.get_bone_count():
		names.append(skeleton.get_bone_name(i))
	return names


func _find_skeleton_in(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton_in(child)
		if found:
			return found
	return null


func _attach_gun_to_hand() -> void:
	if not _gun_node or not _loaded_model:
		return
	# Remove from previous parent (CameraMount or old bone attachment)
	if _gun_node.get_parent():
		_gun_node.get_parent().remove_child(_gun_node)
	if _gun_bone_attach and is_instance_valid(_gun_bone_attach):
		_gun_bone_attach.queue_free()
		_gun_bone_attach = null

	var skeleton := _find_skeleton_in(_loaded_model)
	if not skeleton:
		print("[GUN] No skeleton found, fallback to CameraMount")
		$CameraMount.add_child(_gun_node)
		_gun_node.position = Vector3(0.25, -0.15, -0.4)
		_gun_node.rotation_degrees = Vector3(0, 90, 0)
		_gun_node.scale = Vector3(0.02, 0.02, 0.02)
		return

	# Find the right hand bone
	var bone_name := ""
	for i in skeleton.get_bone_count():
		var bname := skeleton.get_bone_name(i)
		if "right" in bname.to_lower() and "hand" in bname.to_lower():
			bone_name = bname
			break
	if bone_name == "":
		print("[GUN] No right hand bone found. Bones: ", _get_bone_names(skeleton))
		$CameraMount.add_child(_gun_node)
		_gun_node.position = Vector3(0.25, -0.15, -0.4)
		_gun_node.rotation_degrees = Vector3(0, 90, 0)
		_gun_node.scale = Vector3(0.02, 0.02, 0.02)
		return

	print("[GUN] Attaching to bone: ", bone_name)
	_gun_bone_attach = BoneAttachment3D.new()
	_gun_bone_attach.bone_name = bone_name
	skeleton.add_child(_gun_bone_attach)
	_gun_bone_attach.add_child(_gun_node)
	# Gun at scale 0.02 in world space looked right — compensate for model auto-scale
	var model_scale: float = _loaded_model.scale.x
	if model_scale > 0.001:
		_gun_node.scale = Vector3.ONE * (0.02 / model_scale)
	else:
		_gun_node.scale = Vector3.ONE
	_gun_node.position = Vector3.ZERO
	_gun_node.rotation_degrees = Vector3(0, -90, 0)
	_gun_base_rot_x = 0.0


func _setup_viewmodel_viewport() -> void:
	## FPS viewmodel using dedicated arm-only model (GDQuest FPS Arms, MIT license).
	## Renders in isolated SubViewport overlaid on the main view.
	_vm_viewport = SubViewport.new()
	_vm_viewport.transparent_bg = true
	_vm_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vm_viewport.own_world_3d = true
	_vm_viewport.size = get_viewport().get_visible_rect().size
	add_child(_vm_viewport)

	# Lighting
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	environment.ambient_light_energy = 0.8
	env.environment = environment
	_vm_viewport.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 45, 0)
	light.light_energy = 1.4
	_vm_viewport.add_child(light)

	# Camera
	_vm_camera = Camera3D.new()
	_vm_camera.current = true
	_vm_camera.near = 0.2
	_vm_camera.far = 5.0
	_vm_camera.fov = 55.0
	_vm_viewport.add_child(_vm_camera)

	# Build the arms viewmodel
	_build_vm_model()

	# Overlay on UI
	_vm_overlay = TextureRect.new()
	_vm_overlay.texture = _vm_viewport.get_texture()
	_vm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vm_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vm_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	var ui_layer = get_tree().current_scene.get_node_or_null("UI")
	if ui_layer:
		ui_layer.add_child(_vm_overlay)
	else:
		get_tree().current_scene.add_child(_vm_overlay)

	get_viewport().size_changed.connect(_on_viewport_resize)




func _build_vm_model() -> void:
	## Creates a duplicate player model + gun in the viewmodel SubViewport world.
	## Hides head/legs via bone collapsing, only arms/hands visible.
	if _vm_model and is_instance_valid(_vm_model):
		_vm_model.queue_free()
		_vm_model = null
		_vm_anim_player = null
		_vm_gun = null

	# Load arms-only model (no body — just arms/hands extracted via Blender)
	var arms_path: String = ROLE_ARMS.get(_current_role, ROLE_ARMS["striker"])
	var scene = load(arms_path) as PackedScene
	if not scene or not _vm_viewport:
		return

	_vm_model = scene.instantiate()
	_vm_camera.add_child(_vm_model)

	# Debug: print what meshes are in the arms model
	print("[VM] Arms model children:")
	_debug_print_tree(_vm_model, "  ")

	# Arms-only model: skeleton is already correct Mixamo proportions, no bounds scaling needed
	_vm_model.rotation.y = PI
	_vm_model.position = VM_POS_HIP

	# Hide non-body meshes (vest, shirt, hair sleeves are weighted to arm bones)
	_hide_vm_clothing_meshes(_vm_model)
	_disable_backface_culling(_vm_model)

	# Load animations
	_vm_anim_player = _load_animations_on(_vm_model)

	# Attach gun to hand bone
	var gun_scene = load("res://assets/models/pistol_cyberpunk.glb") as PackedScene
	if gun_scene:
		_vm_gun = gun_scene.instantiate()
		var skel := _find_skeleton_in(_vm_model)
		if skel:
			var bone_name := ""
			for i in skel.get_bone_count():
				var bname := skel.get_bone_name(i)
				if "right" in bname.to_lower() and "hand" in bname.to_lower():
					bone_name = bname
					break
			if bone_name != "":
				var bone_attach := BoneAttachment3D.new()
				bone_attach.bone_name = bone_name
				skel.add_child(bone_attach)
				bone_attach.add_child(_vm_gun)
				var model_scale: float = _vm_model.scale.x
				if model_scale > 0.001:
					_vm_gun.scale = Vector3.ONE * (_vm_gun_scale / model_scale)
				else:
					_vm_gun.scale = Vector3.ONE
				_vm_gun.position = _vm_gun_pos
				_vm_gun.rotation_degrees = _vm_gun_rot
				_vm_gun_base_rot_x = _vm_gun_rot.x

	_play_vm_anim("Idle")


func _hide_vm_clothing_meshes(node: Node) -> void:
	## In the arms-only viewmodel, hide clothing/accessory meshes (vest, shirt, hair).
	## Only keep the body/skin mesh so the player sees bare arms + gun.
	for child in node.get_children():
		if child is MeshInstance3D:
			var lname := child.name.to_lower()
			if "vest" in lname or "hair" in lname or "hat" in lname or "helmet" in lname:
				child.visible = false
		_hide_vm_clothing_meshes(child)


func _debug_print_tree(node: Node, indent: String) -> void:
	var info := node.get_class()
	if node is MeshInstance3D:
		info += " (mesh, visible=%s, verts=%d)" % [node.visible, node.mesh.get_faces().size() / 3 if node.mesh else 0]
	print(indent + node.name + " [" + info + "]")
	for child in node.get_children():
		_debug_print_tree(child, indent + "  ")


func _remove_unskinned_meshes(node: Node) -> void:
	## Remove MeshInstance3D nodes that aren't skinned (props/accessories like hats).
	## Skinned meshes have a skin property set; unskinned props don't.
	for child in node.get_children():
		if child is MeshInstance3D:
			if not child.skin and not child.skeleton:
				child.queue_free()
				continue
		_remove_unskinned_meshes(child)


func _hide_vm_nonarm_bones() -> void:
	## Collapse head, neck, and leg bones to zero so only arms/hands are visible.
	var skeleton := _find_skeleton_in(_vm_model)
	if not skeleton:
		return
	var hide_parts := ["head", "headtop_end", "neck",
		"leftupleg", "leftleg", "leftfoot", "lefttoebase", "lefttoe_end",
		"rightupleg", "rightleg", "rightfoot", "righttoebase", "righttoe_end"]
	var enlarge_parts := ["lefthand", "righthand", "leftforearm", "rightforearm", "leftarm", "rightarm"]
	var curl_fingers := ["index1", "index2", "index3",
		"middle1", "middle2", "middle3",
		"ring1", "ring2", "ring3",
		"pinky1", "pinky2", "pinky3",
		"thumb2", "thumb3"]
	for i in skeleton.get_bone_count():
		var base := _strip_mixamo_prefix(skeleton.get_bone_name(i)).to_lower()
		if base in hide_parts:
			skeleton.set_bone_pose_scale(i, Vector3(0.001, 0.001, 0.001))
		elif base in enlarge_parts:
			skeleton.set_bone_pose_scale(i, Vector3(1.09, 1.09, 1.09))
		else:
			for finger in curl_fingers:
				if base.ends_with(finger):
					var curl_amount := deg_to_rad(75) if "1" in finger else deg_to_rad(85)
					if "thumb" in finger:
						curl_amount = deg_to_rad(45)
					skeleton.set_bone_pose_rotation(i, Quaternion.from_euler(Vector3(curl_amount, 0, 0)))
					break


func _apply_vm_bone_overrides() -> void:
	## Apply bone scale overrides every frame (deferred, runs after animation).
	if not _vm_model or not is_instance_valid(_vm_model):
		return
	var skeleton := _find_skeleton_in(_vm_model)
	if not skeleton:
		return
	var is_striker := _current_role == "striker"
	var left_uncurl := ["lefthandindex", "lefthandmiddle", "lefthandring", "lefthandpinky", "lefthandthumb"]
	for i in skeleton.get_bone_count():
		var base := _strip_mixamo_prefix(skeleton.get_bone_name(i)).to_lower()
		if base in ["leftarm", "rightarm"]:
			skeleton.set_bone_pose_scale(i, Vector3(1.2, 1.2, 1.2))
		elif base in ["leftforearm", "rightforearm"]:
			skeleton.set_bone_pose_scale(i, Vector3(1.15, 1.15, 1.15))
		elif base in ["lefthand", "righthand"]:
			var s := 0.85 if is_striker else 1.2
			skeleton.set_bone_pose_scale(i, Vector3(s, s, s))
		# Uncurl Striker's left hand fingers (animation curls them too much)
		if is_striker:
			for prefix in left_uncurl:
				if base.begins_with(prefix) and base[-1].is_valid_int():
					var uncurl := deg_to_rad(-25)
					if "thumb" in base:
						uncurl = deg_to_rad(-15)
					var current_rot := skeleton.get_bone_pose_rotation(i)
					var uncurl_quat := Quaternion.from_euler(Vector3(uncurl, 0, 0))
					skeleton.set_bone_pose_rotation(i, current_rot * uncurl_quat)
					break


func _play_vm_anim(anim_name: String, custom_speed: float = 1.0) -> void:
	## Play animation on the viewmodel (mirrors main model's animation).
	if not _vm_anim_player:
		return
	# Skip HitReaction on viewmodel — breaks gun grip pose
	if anim_name == "HitReaction":
		return
	# AimIdle uses Idle (same pistol grip pose, loaded from pistol_idle.fbx)
	if anim_name == "AimIdle":
		anim_name = "Idle"
	for try_name in [anim_name, anim_name.to_lower(), anim_name.to_upper()]:
		if _vm_anim_player.has_animation(try_name):
			_vm_anim_player.play(try_name, ANIM_BLEND, custom_speed)
			return
	for a_name in _vm_anim_player.get_animation_list():
		if anim_name.to_lower() in a_name.to_lower():
			_vm_anim_player.play(a_name, ANIM_BLEND, custom_speed)
			return


func _on_viewport_resize() -> void:
	if _vm_viewport:
		_vm_viewport.size = get_viewport().get_visible_rect().size


func _vm_debug_update() -> void:
	if not _vm_debug_label:
		_vm_debug_label = Label.new()
		_vm_debug_label.position = Vector2(20, 350)
		_vm_debug_label.add_theme_font_size_override("font_size", 14)
		_vm_debug_label.add_theme_color_override("font_color", Color.YELLOW)
		var canvas = get_tree().current_scene.get_node_or_null("UI/HUD")
		if canvas:
			canvas.add_child(_vm_debug_label)
		else:
			return

	# 0 = cycle: model pos → gun pos → gun rot → gun scale
	if Input.is_key_pressed(KEY_0) and not _vm_debug_t_held:
		_vm_debug_t_held = true
		_vm_debug_mode = (_vm_debug_mode + 1) % 4
	elif not Input.is_key_pressed(KEY_0):
		_vm_debug_t_held = false

	var mode_names := ["MODEL POS", "GUN POS", "GUN ROT", "GUN SCALE"]
	var aim_label := " (ADS)" if input_aim else " (HIP)"

	var dx := 0.0
	var dy := 0.0
	var dz := 0.0
	var step: float
	match _vm_debug_mode:
		2: step = VM_DEBUG_ROT_STEP
		3: step = 0.005
		_: step = VM_DEBUG_STEP

	# 1/2=X, 3/4=Y, 5/6=Z
	if Input.is_key_pressed(KEY_1): dx += step
	if Input.is_key_pressed(KEY_2): dx -= step
	if Input.is_key_pressed(KEY_3): dy += step
	if Input.is_key_pressed(KEY_4): dy -= step
	if Input.is_key_pressed(KEY_5): dz += step
	if Input.is_key_pressed(KEY_6): dz -= step

	match _vm_debug_mode:
		0:  # Model pos
			if input_aim:
				VM_POS_ADS += Vector3(dx, dy, dz)
			else:
				VM_POS_HIP += Vector3(dx, dy, dz)
		1:  # Gun pos
			_vm_gun_pos += Vector3(dx, dy, dz)
			if _vm_gun:
				_vm_gun.position = _vm_gun_pos
		2:  # Gun rot
			_vm_gun_rot += Vector3(dx, dy, dz)
			if _vm_gun:
				_vm_gun.rotation_degrees = _vm_gun_rot
		3:  # Gun scale (U/J only)
			_vm_gun_scale += dx
			if _vm_gun:
				_vm_gun.scale = Vector3.ONE * _vm_gun_scale

	var active_val: Vector3
	match _vm_debug_mode:
		0: active_val = VM_POS_ADS if input_aim else VM_POS_HIP
		1: active_val = _vm_gun_pos
		2: active_val = _vm_gun_rot
		3: active_val = Vector3(_vm_gun_scale, 0, 0)

	_vm_debug_label.text = "[T] %s%s  X:%.3f Y:%.3f Z:%.3f\nHIP: %s  ADS: %s\nGun Pos: %s  Rot: %s  Scale: %.4f" % [
		mode_names[_vm_debug_mode],
		aim_label if _vm_debug_mode == 0 else "",
		active_val.x, active_val.y, active_val.z,
		str(VM_POS_HIP), str(VM_POS_ADS),
		str(_vm_gun_pos), str(_vm_gun_rot), _vm_gun_scale,
	]



func _load_animations_on(model_node: Node3D) -> AnimationPlayer:
	## Loads all pistol animations from ybot FBX files onto a model, with bone
	## remapping. Works for any Mixamo-rigged model. Returns the AnimationPlayer.
	var ap := _find_anim_player_in(model_node)
	if not ap:
		ap = AnimationPlayer.new()
		model_node.add_child(ap)
	ap.stop()
	ap.autoplay = ""
	ap.root_node = ap.get_path_to(model_node)

	var lib := AnimationLibrary.new()
	if ap.has_animation_library(""):
		ap.remove_animation_library("")
	ap.add_animation_library("", lib)

	var anim_map := {
		"Idle": "res://assets/models/ybot/pistol_idle.fbx",
		"Walk": "res://assets/models/ybot/pistol_walk.fbx",
		"Run": "res://assets/models/ybot/pistol_run.fbx",
		"Sprint": "res://assets/models/ybot/sprint.fbx",
		"Jump": "res://assets/models/ybot/pistol_jump.fbx",
		"Crouch": "res://assets/models/ybot/pistol_crouch_idle.fbx",
		"CrouchWalk": "res://assets/models/ybot/crouch_walk.fbx",
		"Shoot": "res://assets/models/ybot/pistol_shoot.fbx",
		"Melee": "res://assets/models/ybot/melee_standing_melee_attack_horizontal.fbx",
		"HitReaction": "res://assets/models/ybot/player_hit_reaction.fbx",
		"Taunt": "res://assets/models/ybot/melee_standing_taunt_battlecry.fbx",
		"HealSuper": "res://assets/models/ybot/magic_heal.fbx",
		"Throw": "res://assets/models/ybot/throw.fbx",
		"Cast": "res://assets/models/ybot/magic_cast.fbx",
		"PowerUp": "res://assets/models/ybot/power_up.fbx",
		"Revive": "res://assets/models/ybot/revive.fbx",
		"GetUp": "res://assets/models/ybot/getting_up_2.fbx",
		"KnockedDown": "res://assets/models/ybot/stunned.fbx",
		"Landing": "res://assets/models/ybot/hard_landing.fbx",
		"Crawl": "res://assets/models/ybot/crawl_backward_1.fbx",
		"Death": "res://assets/models/ybot/death_front.fbx",
		"AimIdle": "res://assets/models/ybot/idle_aiming.fbx",
		"Reload": "res://assets/models/ybot/pistol_reload.fbx",
	}

	# Build bone name remap from ybot names → target model's bone names
	var target_skel := _find_skeleton_in(model_node)
	var skel_path_str := ""
	var bone_remap := {}  # "RightHand" → "mixamorig1_RightHand"
	if target_skel:
		skel_path_str = str(model_node.get_path_to(target_skel))
		for i in target_skel.get_bone_count():
			var bname := target_skel.get_bone_name(i)
			var base := _strip_mixamo_prefix(bname)
			bone_remap[base] = bname

	for anim_name in anim_map:
		var scene: PackedScene = load(anim_map[anim_name]) as PackedScene
		if not scene:
			continue
		var temp: Node = scene.instantiate()
		var temp_player := _find_anim_player_in(temp)
		if not temp_player:
			temp.free()
			continue
		var anim_list := temp_player.get_animation_list()
		if anim_list.is_empty():
			temp.free()
			continue
		var pick_name: String = anim_list[0]
		for candidate in anim_list:
			if "mixamo" in candidate.to_lower():
				pick_name = candidate
				break
		var source_anim: Animation = temp_player.get_animation(pick_name)
		if source_anim:
			var anim_copy := source_anim.duplicate()
			_strip_player_root_motion(anim_copy)
			_remap_anim_tracks(anim_copy, skel_path_str, bone_remap)
			if anim_name in ["Idle", "Walk", "Run", "Sprint", "Crouch", "CrouchWalk", "Crawl", "AimIdle"]:
				anim_copy.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(anim_name, anim_copy)
		temp.free()
	return ap


func _strip_mixamo_prefix(bone_name: String) -> String:
	for prefix in ["mixamorig:", "mixamorig_", "mixamorig1_", "mixamorig2_", "mixamorig3_"]:
		if bone_name.begins_with(prefix):
			return bone_name.substr(prefix.length())
	return bone_name


func _remap_anim_tracks(anim: Animation, skel_path: String, bone_remap: Dictionary) -> void:
	if skel_path.is_empty() or bone_remap.is_empty():
		return
	for track_idx in anim.get_track_count():
		var old_path := anim.track_get_path(track_idx)
		var subname := old_path.get_concatenated_subnames()
		if subname.is_empty():
			continue
		# Remap bone name: strip source prefix, look up target name
		var base_bone := _strip_mixamo_prefix(subname)
		var new_bone: String = bone_remap.get(base_bone, subname)
		# Build new path: target_skeleton_path:remapped_bone_name
		anim.track_set_path(track_idx, NodePath(skel_path + ":" + new_bone))


func _strip_player_root_motion(anim: Animation) -> void:
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var path_str := str(anim.track_get_path(i))
		if "Hips" not in path_str:
			continue
		for key_idx in anim.track_get_key_count(i):
			var pos: Vector3 = anim.track_get_key_value(i, key_idx)
			anim.track_set_key_value(i, key_idx, Vector3(0.0, pos.y, 0.0))
		break


func _play_player_anim(anim_name: String, custom_speed: float = 1.0) -> void:
	if not _anim_player or anim_name == _current_anim:
		return
	for try_name in [anim_name, anim_name.to_lower(), anim_name.to_upper()]:
		if _anim_player.has_animation(try_name):
			_anim_player.play(try_name, ANIM_BLEND, custom_speed)
			_current_anim = anim_name
			_play_vm_anim(anim_name, custom_speed)
			return
	for a_name in _anim_player.get_animation_list():
		if anim_name.to_lower() in a_name.to_lower():
			_anim_player.play(a_name, ANIM_BLEND, custom_speed)
			_current_anim = anim_name
			_play_vm_anim(anim_name, custom_speed)
			return


@rpc("authority", "call_local", "reliable")
func _play_oneshot_anim(anim_name: String, duration: float) -> void:
	_anim_override = anim_name
	_anim_override_timer = duration
	_current_anim = ""  # Force re-play even if same anim
	var spd := 1.0
	if anim_name == "Shoot":
		spd = 2.5  # Snappy recoil — animation finishes fast, arms settle before next shot
	_play_player_anim(anim_name, spd)


func _update_player_animation() -> void:
	if _gun_node:
		_gun_node.visible = _is_alive and not _is_downed
	# Hide viewmodel arms/gun when downed or dead
	if _vm_model:
		_vm_model.visible = _is_alive and not _is_downed
	if not _is_alive:
		_play_player_anim("Death")
		if visible:
			visible = false
		return
	# Reset downed tracker when no longer downed (revived)
	if not _is_downed:
		_was_downed = false
	if _is_downed:
		# Detect transition to downed state — play knockdown anim once on all peers
		if not _was_downed:
			_was_downed = true
			_anim_override = "KnockedDown"
			_anim_override_timer = 1.5
			_current_anim = ""  # Force animation restart
		# After knockdown animation finishes, crawl if moving, otherwise stay in Death pose
		if _anim_override_timer > 0.0:
			_anim_override_timer -= get_physics_process_delta_time()
			_play_player_anim(_anim_override)
		elif Vector2(velocity.x, velocity.z).length() > 0.5:
			_play_player_anim("Crawl")
		else:
			_play_player_anim("Death")
		return
	# One-shot override (Shoot, HitReaction, etc.) — let it play out before returning to locomotion
	if _anim_override_timer > 0.0:
		_anim_override_timer -= get_physics_process_delta_time()
		_play_player_anim(_anim_override)
		return
	if not _is_grounded():
		_play_player_anim("Jump")
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if input_crouch:
		if horizontal_speed > 1.0:
			_play_player_anim("CrouchWalk")
		else:
			_play_player_anim("Crouch")
		return
	if horizontal_speed > SPRINT_SPEED * 0.8:
		_play_player_anim("Sprint")
	elif horizontal_speed > 1.0:
		_play_player_anim("Walk")
	elif input_aim:
		_play_player_anim("AimIdle")
	else:
		_play_player_anim("Idle")


@rpc("authority", "call_local", "reliable")
func _show_revived_visual(role: String) -> void:
	_clear_model_color()
	_current_role = role


func _process_bleedout(delta: float) -> void:
	if not _is_downed:
		return
	_bleedout_timer -= delta
	if _bleedout_timer <= 0.0:
		_is_alive = false
		_is_downed = false
		visible = false
		set_physics_process(false)
		Events.player_bleedout.emit(player_id)
		Events.player_died.emit(player_id, global_position)


# ── Status Effects (server-authoritative) ────────────────────────────────

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
