## Hallucination enemy — disguises as a health pickup, reveals and chases when triggered.
## Reveal triggers: player within 4.0 units, takes any damage, or Weak Point Scan (stuns 2s).
extends "res://scripts/enemies/enemy_base.gd"

const HALL_HP: int = 2
const HALL_CHASE_SPEED: float = 3.5  # 70px / 20
const HALL_REVEAL_RANGE: float = 4.0  # 80px / 20
const HALL_CONTACT_DMG: int = 1
const HALL_DISGUISED_SCALE: float = 0.6
const HALL_REVEALED_SCALE: float = 1.0
const HALL_REVEAL_TIME: float = 0.3
const HALL_SCAN_STUN: float = 2.0

const COLOR_DISGUISED: Color = Color(0.2, 0.9, 0.2)
const COLOR_REVEALED: Color = Color(0.6, 0.1, 0.8)

var is_disguised: bool = true
var _reveal_timer: float = 0.0
var _was_scan_revealed: bool = false
var _chase_speed: float = HALL_CHASE_SPEED
var _last_disguised: bool = true  # tracks synced value for client visual update


func _ready() -> void:
	super._ready()
	_load_glb_model("res://assets/models/ely/ely.fbx", 2.0)  # Ely model — humanoid disguised as friendly
	_load_external_animations({
		"Idle": "res://assets/models/ybot/idle.fbx",
		"Walk": "res://assets/models/ybot/walk.fbx",
		"Run": "res://assets/models/ybot/run.fbx",
		"Death": "res://assets/models/ybot/death.fbx",
		"HitReaction": "res://assets/models/ybot/hit_reaction.fbx",
		"Attack": "res://assets/models/ybot/attack.fbx",
	})
	_attach_robot_helmet()
	health = HALL_HP
	speed = 0.0
	contact_damage = HALL_CONTACT_DMG
	_current_state = State.IDLE
	_update_visual_disguised()


func _process(_delta: float) -> void:
	super._process(_delta)
	# Client-side: watch for synced is_disguised to change and update visual
	if not multiplayer.is_server() and is_disguised != _last_disguised:
		_last_disguised = is_disguised
		if is_disguised:
			_update_visual_disguised()
		else:
			_update_visual_revealed()


func _state_idle(delta: float) -> void:
	if is_disguised:
		_check_reveal_trigger()
	elif _reveal_timer > 0.0:
		_reveal_timer -= delta
		if _reveal_timer <= 0.0:
			_finish_reveal()


func _check_reveal_trigger() -> void:
	var target := _find_nearest_player()
	if not target:
		return
	var dist := global_position.distance_to(target.global_position)
	if dist <= HALL_REVEAL_RANGE:
		_start_reveal(false)


func _start_reveal(from_scan: bool) -> void:
	is_disguised = false
	_last_disguised = false
	_was_scan_revealed = from_scan
	_reveal_timer = HALL_REVEAL_TIME
	_update_visual_revealed()


func apply_scaling(health_scale: float, speed_scale: float) -> void:
	health = int(ceil(health * health_scale))
	_chase_speed = HALL_CHASE_SPEED * speed_scale


func _finish_reveal() -> void:
	speed = _chase_speed
	Events.hallucination_revealed.emit(enemy_id, global_position)
	if _was_scan_revealed:
		_stun_timer = HALL_SCAN_STUN
		_transition_to(State.STUNNED)
	else:
		_transition_to(State.CHASE)


func take_damage(amount: int, from_player_id: int) -> void:
	if not _is_alive or not multiplayer.is_server():
		return
	if is_disguised:
		_start_reveal(false)
	if has_status("exposed"):
		amount *= 2
	health -= amount
	_show_hit_flash.rpc()
	if health <= 0:
		health = 0
		_die(from_player_id)


func reveal_from_scan() -> void:
	if is_disguised:
		_start_reveal(true)


func _attach_robot_helmet() -> void:
	if not _model_node:
		return
	var helmet := _build_robot_helmet()
	# Helmet is built in world-space units (~0.2m pieces for a 2m character).
	# Undo model scale so helmet stays at world size, position in model-local coords.
	var ms: float = _model_node.scale.x
	var inv_s := 1.0 / ms
	helmet.scale = Vector3(inv_s, inv_s, inv_s)
	helmet.position = Vector3(0, 1.62 / ms, 0)
	_model_node.add_child(helmet)


func _build_robot_helmet() -> Node3D:
	var helmet := Node3D.new()
	helmet.name = "RobotHelmet"

	# ── Materials matching Ely's armor ───────────────────────────────────
	var armor_mat := StandardMaterial3D.new()
	armor_mat.albedo_color = Color(0.20, 0.14, 0.16)  # Dark charcoal-maroon matching Ely's armor
	armor_mat.metallic = 0.4
	armor_mat.roughness = 0.55
	armor_mat.emission_enabled = true
	armor_mat.emission = Color(0.18, 0.12, 0.14)
	armor_mat.emission_energy_multiplier = 0.5

	var armor_dark := StandardMaterial3D.new()
	armor_dark.albedo_color = Color(0.10, 0.07, 0.09)  # Deep dark layer matching Ely's recesses
	armor_dark.metallic = 0.3
	armor_dark.roughness = 0.7

	var visor_mat := StandardMaterial3D.new()
	visor_mat.albedo_color = Color(1.0, 0.5, 0.1, 0.9)
	visor_mat.emission_enabled = true
	visor_mat.emission = Color(1.0, 0.45, 0.05)
	visor_mat.emission_energy_multiplier = 4.0
	visor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visor_mat.metallic = 0.9
	visor_mat.roughness = 0.1

	var accent_mat := StandardMaterial3D.new()
	accent_mat.albedo_color = Color(0.9, 0.35, 0.05)
	accent_mat.emission_enabled = true
	accent_mat.emission = Color(1.0, 0.4, 0.05)
	accent_mat.emission_energy_multiplier = 2.5
	accent_mat.metallic = 0.5
	accent_mat.roughness = 0.3

	var led_mat := StandardMaterial3D.new()
	led_mat.albedo_color = Color(1.0, 0.6, 0.1)
	led_mat.emission_enabled = true
	led_mat.emission = Color(1.0, 0.5, 0.05)
	led_mat.emission_energy_multiplier = 5.0

	# ── Main dome (smooth rounded shell) ─────────────────────────────────
	var dome := MeshInstance3D.new()
	var dome_m := SphereMesh.new()
	dome_m.radius = 0.15
	dome_m.height = 0.32
	dome.mesh = dome_m
	dome.material_override = armor_mat
	dome.position = Vector3(0, 0.03, -0.01)
	helmet.add_child(dome)

	# Inner dark layer (slightly smaller, visible through gaps)
	var inner := MeshInstance3D.new()
	var inner_m := SphereMesh.new()
	inner_m.radius = 0.135
	inner_m.height = 0.29
	inner.mesh = inner_m
	inner.material_override = armor_dark
	inner.position = Vector3(0, 0.03, -0.01)
	helmet.add_child(inner)

	# ── Face shield (smooth curved front) ────────────────────────────────
	var face := MeshInstance3D.new()
	var face_m := SphereMesh.new()
	face_m.radius = 0.13
	face_m.height = 0.24
	face.mesh = face_m
	face.material_override = armor_mat
	face.position = Vector3(0, 0.0, 0.06)
	face.scale = Vector3(1.0, 1.0, 0.5)  # Flatten forward
	helmet.add_child(face)

	# ── Visor (wide curved slit) ─────────────────────────────────────────
	# Visor recess (dark groove the glass sits in)
	var visor_recess := MeshInstance3D.new()
	var vr_m := CapsuleMesh.new()
	vr_m.radius = 0.015
	vr_m.height = 0.22
	visor_recess.mesh = vr_m
	visor_recess.material_override = armor_dark
	visor_recess.position = Vector3(0, 0.025, 0.135)
	visor_recess.rotation_degrees = Vector3(0, 0, 90)
	helmet.add_child(visor_recess)

	# Visor glass (glowing orange, capsule shape for smooth edges)
	var visor := MeshInstance3D.new()
	var v_m := CapsuleMesh.new()
	v_m.radius = 0.012
	v_m.height = 0.20
	visor.mesh = v_m
	visor.material_override = visor_mat
	visor.position = Vector3(0, 0.025, 0.14)
	visor.rotation_degrees = Vector3(0, 0, 90)
	helmet.add_child(visor)

	# ── Brow ridge (curved cylinder across the top of visor) ─────────────
	var brow := MeshInstance3D.new()
	var br_m := CapsuleMesh.new()
	br_m.radius = 0.018
	br_m.height = 0.24
	brow.mesh = br_m
	brow.material_override = armor_mat
	brow.position = Vector3(0, 0.06, 0.12)
	brow.rotation_degrees = Vector3(0, 0, 90)
	helmet.add_child(brow)

	# Brow accent (thin orange line under the ridge)
	var brow_acc := MeshInstance3D.new()
	var ba_m := CapsuleMesh.new()
	ba_m.radius = 0.006
	ba_m.height = 0.21
	brow_acc.mesh = ba_m
	brow_acc.material_override = accent_mat
	brow_acc.position = Vector3(0, 0.048, 0.135)
	brow_acc.rotation_degrees = Vector3(0, 0, 90)
	helmet.add_child(brow_acc)

	# ── Side armor (left + right) ────────────────────────────────────────
	for side in [-1.0, 1.0]:
		# Cheek plate (flattened sphere for smooth curve)
		var cheek := MeshInstance3D.new()
		var ck_m := SphereMesh.new()
		ck_m.radius = 0.08
		ck_m.height = 0.20
		cheek.mesh = ck_m
		cheek.material_override = armor_mat
		cheek.position = Vector3(side * 0.11, -0.01, 0.02)
		cheek.scale = Vector3(0.4, 1.0, 0.9)
		helmet.add_child(cheek)

		# Side accent strip (capsule for smooth glow line)
		var strip := MeshInstance3D.new()
		var st_m := CapsuleMesh.new()
		st_m.radius = 0.005
		st_m.height = 0.16
		strip.mesh = st_m
		strip.material_override = accent_mat
		strip.position = Vector3(side * 0.145, 0.04, 0.0)
		strip.rotation_degrees = Vector3(90, 0, 0)
		helmet.add_child(strip)

		# Lower accent strip
		var strip2 := MeshInstance3D.new()
		var st2_m := CapsuleMesh.new()
		st2_m.radius = 0.004
		st2_m.height = 0.12
		strip2.mesh = st2_m
		strip2.material_override = accent_mat
		strip2.position = Vector3(side * 0.14, -0.03, 0.01)
		strip2.rotation_degrees = Vector3(90, 0, 0)
		helmet.add_child(strip2)

		# Ear module (cylinder disk)
		var ear := MeshInstance3D.new()
		var ear_m := CylinderMesh.new()
		ear_m.top_radius = 0.03
		ear_m.bottom_radius = 0.035
		ear_m.height = 0.025
		ear.mesh = ear_m
		ear.material_override = armor_mat
		ear.position = Vector3(side * 0.155, 0.02, -0.02)
		ear.rotation_degrees = Vector3(0, 0, 90)
		helmet.add_child(ear)

		# Ear glow ring
		var ear_ring := MeshInstance3D.new()
		var er_m := TorusMesh.new()
		er_m.inner_radius = 0.018
		er_m.outer_radius = 0.028
		ear_ring.mesh = er_m
		ear_ring.material_override = accent_mat
		ear_ring.position = Vector3(side * 0.16, 0.02, -0.02)
		ear_ring.rotation_degrees = Vector3(0, 0, 90)
		ear_ring.scale = Vector3(1, 1, 0.3)
		helmet.add_child(ear_ring)

		# Status LED
		var led := MeshInstance3D.new()
		var led_m := SphereMesh.new()
		led_m.radius = 0.008
		led_m.height = 0.016
		led.mesh = led_m
		led.material_override = led_mat
		led.position = Vector3(side * 0.15, 0.08, 0.04)
		helmet.add_child(led)

	# ── Nose ridge (smooth vertical line) ────────────────────────────────
	var nose := MeshInstance3D.new()
	var ns_m := CapsuleMesh.new()
	ns_m.radius = 0.008
	ns_m.height = 0.10
	nose.mesh = ns_m
	nose.material_override = armor_mat
	nose.position = Vector3(0, 0.0, 0.145)
	helmet.add_child(nose)

	# Nose accent
	var nose_acc := MeshInstance3D.new()
	var na_m := CapsuleMesh.new()
	na_m.radius = 0.004
	na_m.height = 0.08
	nose_acc.mesh = na_m
	nose_acc.material_override = accent_mat
	nose_acc.position = Vector3(0, 0.0, 0.148)
	helmet.add_child(nose_acc)

	# ── Chin guard (rounded) ─────────────────────────────────────────────
	var chin := MeshInstance3D.new()
	var ch_m := SphereMesh.new()
	ch_m.radius = 0.08
	ch_m.height = 0.10
	chin.mesh = ch_m
	chin.material_override = armor_mat
	chin.position = Vector3(0, -0.09, 0.06)
	chin.scale = Vector3(1.2, 0.6, 0.8)
	helmet.add_child(chin)

	# Chin accent
	var chin_acc := MeshInstance3D.new()
	var ca_m := CapsuleMesh.new()
	ca_m.radius = 0.004
	ca_m.height = 0.08
	chin_acc.mesh = ca_m
	chin_acc.material_override = accent_mat
	chin_acc.position = Vector3(0, -0.07, 0.11)
	chin_acc.rotation_degrees = Vector3(0, 0, 90)
	helmet.add_child(chin_acc)

	# ── Top crest (smooth ridge) ─────────────────────────────────────────
	var crest := MeshInstance3D.new()
	var cr_m := CapsuleMesh.new()
	cr_m.radius = 0.012
	cr_m.height = 0.20
	crest.mesh = cr_m
	crest.material_override = armor_mat
	crest.position = Vector3(0, 0.16, -0.01)
	crest.rotation_degrees = Vector3(90, 0, 0)
	helmet.add_child(crest)

	# Crest accent glow
	var crest_acc := MeshInstance3D.new()
	var cra_m := CapsuleMesh.new()
	cra_m.radius = 0.005
	cra_m.height = 0.18
	crest_acc.mesh = cra_m
	crest_acc.material_override = accent_mat
	crest_acc.position = Vector3(0, 0.175, -0.01)
	crest_acc.rotation_degrees = Vector3(90, 0, 0)
	helmet.add_child(crest_acc)

	# ── Antenna ──────────────────────────────────────────────────────────
	var antenna := MeshInstance3D.new()
	var ant_m := CylinderMesh.new()
	ant_m.top_radius = 0.005
	ant_m.bottom_radius = 0.01
	ant_m.height = 0.07
	antenna.mesh = ant_m
	antenna.material_override = armor_mat
	antenna.position = Vector3(0.09, 0.18, -0.03)
	helmet.add_child(antenna)

	# Antenna tip glow
	var ant_tip := MeshInstance3D.new()
	var at_m := SphereMesh.new()
	at_m.radius = 0.01
	at_m.height = 0.02
	ant_tip.mesh = at_m
	ant_tip.material_override = led_mat
	ant_tip.position = Vector3(0.09, 0.22, -0.03)
	helmet.add_child(ant_tip)

	# ── Back (smooth curved plate) ───────────────────────────────────────
	var back := MeshInstance3D.new()
	var bk_m := SphereMesh.new()
	bk_m.radius = 0.11
	bk_m.height = 0.22
	back.mesh = bk_m
	back.material_override = armor_mat
	back.position = Vector3(0, 0.02, -0.08)
	back.scale = Vector3(1.0, 1.0, 0.5)
	helmet.add_child(back)

	# Back accent
	var back_acc := MeshInstance3D.new()
	var bka_m := CapsuleMesh.new()
	bka_m.radius = 0.004
	bka_m.height = 0.08
	back_acc.mesh = bka_m
	back_acc.material_override = accent_mat
	back_acc.position = Vector3(0, 0.06, -0.13)
	back_acc.rotation_degrees = Vector3(0, 0, 90)
	helmet.add_child(back_acc)

	# ── Neck guard (curved) ──────────────────────────────────────────────
	var neck := MeshInstance3D.new()
	var nk_m := CylinderMesh.new()
	nk_m.top_radius = 0.09
	nk_m.bottom_radius = 0.10
	nk_m.height = 0.05
	neck.mesh = nk_m
	neck.material_override = armor_mat
	neck.position = Vector3(0, -0.13, -0.03)
	helmet.add_child(neck)

	var neck_acc := MeshInstance3D.new()
	var nka_m := TorusMesh.new()
	nka_m.inner_radius = 0.07
	nka_m.outer_radius = 0.09
	neck_acc.mesh = nka_m
	neck_acc.material_override = accent_mat
	neck_acc.position = Vector3(0, -0.11, -0.03)
	neck_acc.scale = Vector3(1, 1, 0.3)
	helmet.add_child(neck_acc)

	return helmet


func _update_visual_disguised() -> void:
	# Hide the real GLB model, show the placeholder as a green sphere
	if _model_node:
		_model_node.visible = false
	var placeholder = get_node_or_null("EnemyModel") as MeshInstance3D
	if placeholder:
		placeholder.visible = true
		var sphere := SphereMesh.new()
		sphere.radius = 0.6
		sphere.height = 1.2
		placeholder.mesh = sphere
		placeholder.scale = Vector3(HALL_DISGUISED_SCALE, HALL_DISGUISED_SCALE, HALL_DISGUISED_SCALE)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = COLOR_DISGUISED
		mat.emission_enabled = true
		mat.emission = COLOR_DISGUISED
		mat.emission_energy_multiplier = 0.5
		placeholder.material_override = mat


func _update_visual_revealed() -> void:
	# Show the real GLB model, hide the placeholder
	if _model_node:
		_model_node.visible = true
	var placeholder = get_node_or_null("EnemyModel") as MeshInstance3D
	if placeholder:
		placeholder.visible = false

	# Update collision shapes to revealed size
	var body_shape = get_node_or_null("CollisionShape3D")
	if body_shape:
		var capsule_shape := CapsuleShape3D.new()
		capsule_shape.radius = 0.5
		capsule_shape.height = 2.0
		body_shape.shape = capsule_shape

	var hurtbox_shape = get_node_or_null("Hurtbox/CollisionShape3D")
	if hurtbox_shape:
		var capsule_shape := CapsuleShape3D.new()
		capsule_shape.radius = 0.5
		capsule_shape.height = 2.0
		hurtbox_shape.shape = capsule_shape
