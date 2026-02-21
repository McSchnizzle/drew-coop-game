## Quick preview — loads Ely with robot helmet, slowly rotates.
## Run with F6. Delete when done.
extends Node3D

var _model: Node3D = null

func _ready() -> void:
	# Add environment light so things are visible
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.2, 0.2, 0.25)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.6, 0.7)
	environment.ambient_light_energy = 1.0
	env.environment = environment
	add_child(env)

	# Add directional light
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	light.light_energy = 1.5
	add_child(light)

	# Load Ely
	var scene = load("res://assets/models/ely/ely.fbx")
	if not scene:
		print("ERROR: Failed to load Ely model")
		return

	_model = scene.instantiate()
	add_child(_model)

	# Figure out how big the model is and scale to ~2 units tall
	var aabb := _get_bounds(_model)
	print("Model bounds: ", aabb)
	print("Model height: ", aabb.size.y)
	var model_scale := 1.0
	if aabb.size.y > 0.01:
		model_scale = 2.0 / aabb.size.y
		_model.scale = Vector3(model_scale, model_scale, model_scale)
		print("Scaled by: ", model_scale)

	# Position camera to look at the model
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 3.0)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.current = true
	cam.fov = 50.0
	add_child(cam)

	# Helmet as child of _model so it rotates with the character.
	# Position and size are in model-local space (divide world values by model_scale).
	var helmet := _build_helmet()
	var inv_s := 1.0 / model_scale
	helmet.scale = Vector3(inv_s, inv_s, inv_s)
	helmet.position = Vector3(0, 1.62 / model_scale, 0)
	_model.add_child(helmet)
	print("Preview ready!")


func _process(delta: float) -> void:
	if _model:
		_model.rotation.y += delta * 0.5


func _get_bounds(node: Node) -> AABB:
	var combined := AABB()
	var first := true
	_collect_bounds(node, Transform3D.IDENTITY, combined, first)
	return combined


func _collect_bounds(node: Node, xform: Transform3D, combined: AABB, first: bool) -> void:
	var local_xform := xform
	if node is Node3D:
		local_xform = xform * node.transform
	if node is MeshInstance3D and node.mesh:
		var mesh_aabb: AABB = node.mesh.get_aabb()
		for i in 8:
			var point: Vector3 = local_xform * mesh_aabb.get_endpoint(i)
			if first:
				combined.position = point
				combined.size = Vector3.ZERO
				first = false
			else:
				combined = combined.expand(point)
	for child in node.get_children():
		_collect_bounds(child, local_xform, combined, first)


func _build_helmet() -> Node3D:
	# Calls the same detailed helmet builder used in enemy_hallucination.gd.
	# Duplicated here for standalone preview — delete this file when done.
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
	face.scale = Vector3(1.0, 1.0, 0.5)
	helmet.add_child(face)

	# ── Visor (wide curved slit) ─────────────────────────────────────────
	var visor_recess := MeshInstance3D.new()
	var vr_m := CapsuleMesh.new()
	vr_m.radius = 0.015
	vr_m.height = 0.22
	visor_recess.mesh = vr_m
	visor_recess.material_override = armor_dark
	visor_recess.position = Vector3(0, 0.025, 0.135)
	visor_recess.rotation_degrees = Vector3(0, 0, 90)
	helmet.add_child(visor_recess)

	var visor := MeshInstance3D.new()
	var v_m := CapsuleMesh.new()
	v_m.radius = 0.012
	v_m.height = 0.20
	visor.mesh = v_m
	visor.material_override = visor_mat
	visor.position = Vector3(0, 0.025, 0.14)
	visor.rotation_degrees = Vector3(0, 0, 90)
	helmet.add_child(visor)

	# ── Brow ridge ───────────────────────────────────────────────────────
	var brow := MeshInstance3D.new()
	var br_m := CapsuleMesh.new()
	br_m.radius = 0.018
	br_m.height = 0.24
	brow.mesh = br_m
	brow.material_override = armor_mat
	brow.position = Vector3(0, 0.06, 0.12)
	brow.rotation_degrees = Vector3(0, 0, 90)
	helmet.add_child(brow)

	var brow_acc := MeshInstance3D.new()
	var ba_m := CapsuleMesh.new()
	ba_m.radius = 0.006
	ba_m.height = 0.21
	brow_acc.mesh = ba_m
	brow_acc.material_override = accent_mat
	brow_acc.position = Vector3(0, 0.048, 0.135)
	brow_acc.rotation_degrees = Vector3(0, 0, 90)
	helmet.add_child(brow_acc)

	# ── Side armor ───────────────────────────────────────────────────────
	for side in [-1.0, 1.0]:
		var cheek := MeshInstance3D.new()
		var ck_m := SphereMesh.new()
		ck_m.radius = 0.08
		ck_m.height = 0.20
		cheek.mesh = ck_m
		cheek.material_override = armor_mat
		cheek.position = Vector3(side * 0.11, -0.01, 0.02)
		cheek.scale = Vector3(0.4, 1.0, 0.9)
		helmet.add_child(cheek)

		var strip := MeshInstance3D.new()
		var st_m := CapsuleMesh.new()
		st_m.radius = 0.005
		st_m.height = 0.16
		strip.mesh = st_m
		strip.material_override = accent_mat
		strip.position = Vector3(side * 0.145, 0.04, 0.0)
		strip.rotation_degrees = Vector3(90, 0, 0)
		helmet.add_child(strip)

		var strip2 := MeshInstance3D.new()
		var st2_m := CapsuleMesh.new()
		st2_m.radius = 0.004
		st2_m.height = 0.12
		strip2.mesh = st2_m
		strip2.material_override = accent_mat
		strip2.position = Vector3(side * 0.14, -0.03, 0.01)
		strip2.rotation_degrees = Vector3(90, 0, 0)
		helmet.add_child(strip2)

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

		var led := MeshInstance3D.new()
		var led_m := SphereMesh.new()
		led_m.radius = 0.008
		led_m.height = 0.016
		led.mesh = led_m
		led.material_override = led_mat
		led.position = Vector3(side * 0.15, 0.08, 0.04)
		helmet.add_child(led)

	# ── Nose ridge ───────────────────────────────────────────────────────
	var nose := MeshInstance3D.new()
	var ns_m := CapsuleMesh.new()
	ns_m.radius = 0.008
	ns_m.height = 0.10
	nose.mesh = ns_m
	nose.material_override = armor_mat
	nose.position = Vector3(0, 0.0, 0.145)
	helmet.add_child(nose)

	var nose_acc := MeshInstance3D.new()
	var na_m := CapsuleMesh.new()
	na_m.radius = 0.004
	na_m.height = 0.08
	nose_acc.mesh = na_m
	nose_acc.material_override = accent_mat
	nose_acc.position = Vector3(0, 0.0, 0.148)
	helmet.add_child(nose_acc)

	# ── Chin guard ───────────────────────────────────────────────────────
	var chin := MeshInstance3D.new()
	var ch_m := SphereMesh.new()
	ch_m.radius = 0.08
	ch_m.height = 0.10
	chin.mesh = ch_m
	chin.material_override = armor_mat
	chin.position = Vector3(0, -0.09, 0.06)
	chin.scale = Vector3(1.2, 0.6, 0.8)
	helmet.add_child(chin)

	var chin_acc := MeshInstance3D.new()
	var ca_m := CapsuleMesh.new()
	ca_m.radius = 0.004
	ca_m.height = 0.08
	chin_acc.mesh = ca_m
	chin_acc.material_override = accent_mat
	chin_acc.position = Vector3(0, -0.07, 0.11)
	chin_acc.rotation_degrees = Vector3(0, 0, 90)
	helmet.add_child(chin_acc)

	# ── Top crest ────────────────────────────────────────────────────────
	var crest := MeshInstance3D.new()
	var cr_m := CapsuleMesh.new()
	cr_m.radius = 0.012
	cr_m.height = 0.20
	crest.mesh = cr_m
	crest.material_override = armor_mat
	crest.position = Vector3(0, 0.16, -0.01)
	crest.rotation_degrees = Vector3(90, 0, 0)
	helmet.add_child(crest)

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

	var ant_tip := MeshInstance3D.new()
	var at_m := SphereMesh.new()
	at_m.radius = 0.01
	at_m.height = 0.02
	ant_tip.mesh = at_m
	ant_tip.material_override = led_mat
	ant_tip.position = Vector3(0.09, 0.22, -0.03)
	helmet.add_child(ant_tip)

	# ── Back ─────────────────────────────────────────────────────────────
	var back := MeshInstance3D.new()
	var bk_m := SphereMesh.new()
	bk_m.radius = 0.11
	bk_m.height = 0.22
	back.mesh = bk_m
	back.material_override = armor_mat
	back.position = Vector3(0, 0.02, -0.08)
	back.scale = Vector3(1.0, 1.0, 0.5)
	helmet.add_child(back)

	var back_acc := MeshInstance3D.new()
	var bka_m := CapsuleMesh.new()
	bka_m.radius = 0.004
	bka_m.height = 0.08
	back_acc.mesh = bka_m
	back_acc.material_override = accent_mat
	back_acc.position = Vector3(0, 0.06, -0.13)
	back_acc.rotation_degrees = Vector3(0, 0, 90)
	helmet.add_child(back_acc)

	# ── Neck guard ───────────────────────────────────────────────────────
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


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null
