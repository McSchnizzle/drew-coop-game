## Player script — CharacterBody3D with dual MultiplayerSynchronizer pattern.
## Server reads InputSync variables and applies authoritative physics.
## Each peer writes their own input to InputSync (authority set via player_id).
extends CharacterBody3D

# ── Physics Constants ─────────────────────────────────────────────────────
const RUN_SPEED: float = 8.5
const SPRINT_SPEED: float = 15.0

# Sprint stamina
const SPRINT_STAMINA_MAX: float = 100.0
const SPRINT_STAMINA_DRAIN: float = 30.0
const SPRINT_STAMINA_REGEN: float = 20.0

# Shooting
const SHOOT_COOLDOWN_TAP: float = 0.3
const SHOOT_COOLDOWN_AUTO: float = 0.12
const AUTO_FIRE_DELAY: float = 0.4

# Melee
const MELEE_RANGE: float = 3.0
const MELEE_DAMAGE: int = 3
const MELEE_COOLDOWN: float = 0.5

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
var health: int = 100
var stamina: float = SPRINT_STAMINA_MAX
var _is_downed: bool = false
var _bleedout_timer: float = 0.0
var ability_cooldown: float = 0.0
var super_charge: float = 0.0
var active_statuses: PackedStringArray = PackedStringArray()

# ── Input Variables (replicated by InputSync from owning peer to server) ─
var input_move_dir: Vector3 = Vector3.ZERO
var input_aim_dir: Vector3 = Vector3.FORWARD
var input_shoot: bool = false
var input_sprint: bool = false
var input_melee: bool = false
var input_ability: bool = false
var input_super: bool = false
var input_interact: bool = false

# ── Camera State (synced for remote player head tilt) ────────────────────
var _camera_pitch: float = 0.0

# ── Internal State (not synced) ──────────────────────────────────────────
var _is_alive: bool = true
var _shoot_cooldown_timer: float = 0.0
var _shoot_hold_time: float = 0.0
var _is_auto_firing: bool = false
var _melee_cooldown_timer: float = 0.0
var _projectile_scene: PackedScene = null
var _sprint_toggled: bool = false
var _status_effects: Dictionary = {}
var _is_reviving_someone: bool = false
var _using_controller: bool = false
var _is_repo_owner: bool = false
var _current_role: String = "striker"


func _ready() -> void:
	_projectile_scene = load(PROJECTILE_SCENE)

	if name.is_valid_int():
		player_id = name.to_int()

	# Load the actual 3D player model, auto-scaled to match collision capsule
	var player_model_scene = load("res://assets/models/player_robot.fbx")
	if player_model_scene:
		var model_instance = player_model_scene.instantiate()
		$PlayerModel.add_child(model_instance)
		# Auto-scale to collision capsule height
		var target_h := 1.8  # default
		var col = get_node_or_null("CollisionShape3D")
		if col and col.shape is CapsuleShape3D:
			target_h = col.shape.height
		var bounds := _compute_node_bounds(model_instance)
		if bounds.size.y > 0.01:
			var s := target_h / bounds.size.y
			model_instance.scale *= s  # Multiply to preserve FBX built-in transforms
			model_instance.position.y = -bounds.position.y * s
		# Hide placeholder meshes
		if $PlayerModel.has_node("Body"):
			$PlayerModel/Body.visible = false
		if $PlayerModel.has_node("Head"):
			$PlayerModel/Head.visible = false

	# Load blaster weapon model and attach to shoot point
	var blaster_scene = load("res://assets/models/blaster_kenney.glb")
	if blaster_scene:
		var blaster = blaster_scene.instantiate()
		blaster.scale = Vector3(0.5, 0.5, 0.5)
		$ShootPoint.add_child(blaster)

	# Only the local player gets the camera and mouse capture.
	if player_id == multiplayer.get_unique_id():
		$CameraMount/Camera3D.make_current()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		# Hide local player model (first-person: don't see own body).
		$PlayerModel.visible = false

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


func _process(_delta: float) -> void:
	# Remote players: tilt the whole model slightly based on synced camera pitch
	if player_id != multiplayer.get_unique_id():
		$PlayerModel.rotation.x = _camera_pitch * 0.3


func _physics_process(delta: float) -> void:
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

	# Sprint toggle
	if Input.is_action_just_pressed("sprint"):
		_sprint_toggled = not _sprint_toggled
	if stamina <= 0.0:
		_sprint_toggled = false
	input_sprint = _sprint_toggled


# ── Server-Side Physics (authoritative game logic) ──────────────────────

func _server_process(delta: float) -> void:
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

	# -- Movement (flat arena, no gravity) --
	var current_speed := (SPRINT_SPEED if is_sprinting else RUN_SPEED) * speed_mult
	velocity = input_move_dir * current_speed
	velocity.y = 0  # Keep on ground plane

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

	# -- Clamp to ground plane --
	if position.y != 0.0:
		position.y = 0.0

	# -- Consume one-shot inputs --
	input_melee = false


# ── Shooting System (tap + hold auto-fire) ───────────────────────────────

func _process_shooting(delta: float) -> void:
	_shoot_cooldown_timer = maxf(_shoot_cooldown_timer - delta, 0.0)

	var auto_cooldown := SHOOT_COOLDOWN_AUTO
	if has_status("overdrive"):
		auto_cooldown *= 0.5

	if input_shoot:
		_shoot_hold_time += delta

		if not _is_auto_firing:
			if _shoot_hold_time <= delta + 0.001 and _shoot_cooldown_timer <= 0.0:
				_fire_projectile()
				_shoot_cooldown_timer = SHOOT_COOLDOWN_TAP

			if _shoot_hold_time >= AUTO_FIRE_DELAY:
				_is_auto_firing = true
				_shoot_cooldown_timer = 0.0
		else:
			if _shoot_cooldown_timer <= 0.0:
				_fire_projectile()
				_shoot_cooldown_timer = auto_cooldown
	else:
		_shoot_hold_time = 0.0
		_is_auto_firing = false


func _fire_projectile() -> void:
	if _projectile_scene == null:
		return

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

	var melee_ability_mgr = get_node_or_null("AbilityManager")
	var melee_dmg := MELEE_DAMAGE
	if melee_ability_mgr:
		melee_dmg = int(ceil(MELEE_DAMAGE * melee_ability_mgr.get_damage_multiplier()))

	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not enemy is Node3D:
			continue
		var to_enemy: Vector3 = enemy.global_position - global_position
		to_enemy.y = 0
		var aim_flat := Vector3(input_aim_dir.x, 0, input_aim_dir.z).normalized()
		var in_cone := to_enemy.normalized().dot(aim_flat) > 0.3
		if in_cone and to_enemy.length() <= MELEE_RANGE:
			if enemy.has_method("take_damage"):
				enemy.take_damage(melee_dmg, player_id)
				if melee_ability_mgr:
					melee_ability_mgr.add_super_charge(melee_ability_mgr.SUPER_CHARGE_PER_MELEE_HIT)


@rpc("authority", "call_local", "reliable")
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

func _update_hud() -> void:
	var hud = get_tree().current_scene.get_node_or_null("UI/HUD")
	if not hud:
		return

	var health_label = hud.get_node_or_null("HealthLabel") as Label
	var stamina_bar = hud.get_node_or_null("StaminaBar") as ProgressBar

	if has_status("context_rot"):
		if health_label:
			health_label.text = "Health: %d" % (randi() % 200)
		if stamina_bar:
			stamina_bar.value = randf() * 100.0
	else:
		if health_label:
			health_label.text = "Health: %d" % health
		if stamina_bar:
			stamina_bar.value = stamina

	var ability_label = hud.get_node_or_null("AbilityLabel") as Label
	if ability_label:
		if ability_cooldown > 0.0:
			ability_label.text = "Ability: %.1fs" % ability_cooldown
		else:
			ability_label.text = "Ability: READY"

	var super_label = hud.get_node_or_null("SuperLabel") as Label
	if super_label:
		if super_charge >= 100.0:
			super_label.text = ">> Super: READY! (E) <<"
			super_label.modulate = Color(1.0, 1.0, 0.0)
		else:
			super_label.text = "Super: %d%%" % int(super_charge)
			super_label.modulate = Color(1.0, 1.0, 1.0)


# ── Health / Damage ──────────────────────────────────────────────────────

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
	_is_downed = true
	_bleedout_timer = BLEEDOUT_TIME
	velocity = Vector3.ZERO
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


@rpc("authority", "call_local", "reliable")
func _set_role_color(role: String) -> void:
	_current_role = role
	if role == "engineer":
		_set_model_color(COLOR_ENGINEER)
	else:
		_set_model_color(COLOR_STRIKER)


func _set_model_color(color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.3
	for child in _get_all_mesh_instances($PlayerModel):
		child.material_override = mat


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


@rpc("authority", "call_local", "reliable")
func _show_revived_visual(role: String) -> void:
	_set_role_color(role)


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
