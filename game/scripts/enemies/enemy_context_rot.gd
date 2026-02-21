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
var _propeller_node: Node3D = null

const PROPELLER_SPIN_SPEED: float = 30.0  # Radians/sec — fast spin


func _ready() -> void:
	super._ready()
	_load_glb_model("res://assets/models/context_rot.glb")
	health = CR_HP
	speed = CR_SPEED
	contact_damage = CR_PROJ_DAMAGE
	_current_state = State.IDLE
	# Offset drone above ground
	position.y = HOVER_HEIGHT
	# Find propeller node for spinning
	if _model_node:
		_propeller_node = _create_propeller_blades()


func _process(delta: float) -> void:
	super._process(delta)
	if not _model_node:
		return
	_drone_time += delta

	# ── Top rotor spin ───────────────────────────────────────────────────
	if _propeller_node:
		_propeller_node.rotation.y += delta * PROPELLER_SPIN_SPEED

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
	_model_node.position.y = bob

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


func _create_propeller_blades() -> Node3D:
	if not _model_node:
		return null

	# Use actual mesh bounds to find the visual top of the drone body.
	# _compute_model_bounds() returns AABB in CharacterBody3D space (includes model transform).
	var bounds := _compute_model_bounds()
	var visual_top_world := bounds.position.y + bounds.size.y

	# The model has been auto-scaled. Undo model scale for propeller components
	# so their dimensions stay in world-space units.
	var ms: float = _model_node.scale.x
	var inv_s := 1.0 / ms

	# Convert world-space top to model-local coordinates
	var top_local := (visual_top_world - _model_node.position.y) / ms

	# World-space shaft dimensions
	var shaft_height := 0.20

	# Shaft connecting body to rotor (doesn't spin, parented to model)
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.02
	shaft_mesh.bottom_radius = 0.035
	shaft_mesh.height = shaft_height
	shaft.mesh = shaft_mesh
	var shaft_mat := StandardMaterial3D.new()
	shaft_mat.albedo_color = Color(0.25, 0.25, 0.25)
	shaft_mat.metallic = 0.7
	shaft.material_override = shaft_mat
	shaft.scale = Vector3(inv_s, inv_s, inv_s)
	shaft.position = Vector3(0, top_local + (shaft_height / 2.0) * inv_s, 0)
	_model_node.add_child(shaft)

	# Top-mounted rotor (spins)
	var prop_root := Node3D.new()
	prop_root.name = "TopRotor"
	prop_root.position = Vector3(0, top_local + shaft_height * inv_s, 0)
	prop_root.scale = Vector3(inv_s, inv_s, inv_s)
	_model_node.add_child(prop_root)

	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.7, 0.7, 0.7, 0.85)
	blade_mat.metallic = 0.6
	blade_mat.roughness = 0.3
	blade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blade_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Rotor hub
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.03
	hub_mesh.bottom_radius = 0.04
	hub_mesh.height = 0.06
	hub.mesh = hub_mesh
	var hub_mat := StandardMaterial3D.new()
	hub_mat.albedo_color = Color(0.3, 0.3, 0.3)
	hub_mat.metallic = 0.7
	hub.material_override = hub_mat
	prop_root.add_child(hub)

	# 3 tilted blades — geometry built with rise so they're visibly pitched
	var blade_mesh := _make_tilted_blade_mesh(0.45, 0.08, 0.06)
	for i in 3:
		var blade := MeshInstance3D.new()
		blade.mesh = blade_mesh
		blade.material_override = blade_mat
		blade.rotation_degrees.y = i * 120.0
		prop_root.add_child(blade)

	return prop_root


func _make_tilted_blade_mesh(length: float, width: float, rise: float) -> ArrayMesh:
	var half_l := length / 2.0
	var half_w := width / 2.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v0 := Vector3(-half_l, 0, -half_w)
	var v1 := Vector3(-half_l, 0, half_w)
	var v2 := Vector3(half_l, rise, half_w)
	var v3 := Vector3(half_l, rise, -half_w)
	st.set_normal(Vector3(0, 1, 0))
	st.add_vertex(v0)
	st.add_vertex(v1)
	st.add_vertex(v2)
	st.add_vertex(v0)
	st.add_vertex(v2)
	st.add_vertex(v3)
	st.set_normal(Vector3(0, -1, 0))
	st.add_vertex(v2)
	st.add_vertex(v1)
	st.add_vertex(v0)
	st.add_vertex(v3)
	st.add_vertex(v2)
	st.add_vertex(v0)
	return st.commit()


func _find_node_by_name(node: Node, target_name: String) -> Node3D:
	if node.name == target_name and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found := _find_node_by_name(child, target_name)
		if found:
			return found
	return null


func _fire_rot_projectile(direction: Vector3) -> void:
	_recoil_timer = 0.3  # Trigger recoil animation
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
