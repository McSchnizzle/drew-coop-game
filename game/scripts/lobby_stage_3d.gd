## 3D lobby stage -- renders player characters on a floor inside a SubViewport.
extends Node3D

const ROLE_COLORS := {
	"striker": Color(0.910, 0.530, 0.169),
	"engineer": Color(0.231, 0.769, 0.290),
}
# Neon accent colors for visor/trim matching the sprite art palette
const ROLE_ACCENTS := {
	"striker": Color(1.0, 0.2, 0.6),   # Hot pink like the striker sprite
	"engineer": Color(0.0, 0.9, 0.9),  # Cyan like the engineer sprite
}
const EMPTY_COLOR := Color(0.165, 0.165, 0.220)
const EMPTY_ACCENT := Color(0.25, 0.25, 0.35)
const MAX_PLAYERS := 4

# Character proportions
const BODY_RADIUS := 0.18
const BODY_HEIGHT := 0.55
const HEAD_RADIUS := 0.14
const VISOR_SIZE := Vector3(0.22, 0.06, 0.08)
const CHAR_TOTAL_HEIGHT := 0.97  # body_center(0.35) + body_half(0.275) + head(0.28) + gap

var _spawn_points: Array[Marker3D] = []
var _player_figures: Array = []   # Node3D roots for each slot
var _player_labels: Array = []


func _ready() -> void:
	var spawn_parent := $SpawnPositions
	for i in MAX_PLAYERS:
		_spawn_points.append(spawn_parent.get_node("Spawn%d" % i))

	_player_figures.resize(MAX_PLAYERS)
	_player_labels.resize(MAX_PLAYERS)
	for i in MAX_PLAYERS:
		_player_figures[i] = null
		_player_labels[i] = null

	_create_particles()


func _process(delta: float) -> void:
	for i in MAX_PLAYERS:
		if _player_figures[i] != null:
			var fig: Node3D = _player_figures[i]
			fig.rotation.y += delta * 0.3
			fig.position.y = sin(Time.get_ticks_msec() * 0.002 + i * 1.5) * 0.04


## Called by lobby.gd whenever role_assignments or names change.
func set_players(role_assignments: Dictionary, player_names: Dictionary = {}) -> void:
	for i in MAX_PLAYERS:
		if _player_figures[i] != null:
			_player_figures[i].queue_free()
			_player_figures[i] = null
		if _player_labels[i] != null:
			_player_labels[i].queue_free()
			_player_labels[i] = null

	var player_ids: Array = role_assignments.keys()
	for i in MAX_PLAYERS:
		if i < player_ids.size():
			var pid: int = player_ids[i]
			var role: String = role_assignments[pid]
			var display_name: String = player_names.get(pid, "Player %d" % pid)
			_create_character(i, role, 1.0)
			_create_label(i, display_name, ROLE_COLORS.get(role, EMPTY_COLOR), 1.0)
		else:
			_create_character(i, "", 0.3)
			_create_label(i, "Empty", EMPTY_COLOR, 0.3)


func _create_character(slot_index: int, role: String, opacity: float) -> void:
	var root := Node3D.new()
	var color: Color = ROLE_COLORS.get(role, EMPTY_COLOR)
	var accent: Color = ROLE_ACCENTS.get(role, EMPTY_ACCENT)
	var filled := opacity >= 1.0

	# --- Body (capsule) ---
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	body.mesh = capsule
	body.material_override = _make_neon_mat(color, opacity, 0.2 if filled else 0.0)
	body.position.y = BODY_HEIGHT / 2.0 + 0.05  # Slight lift off floor
	root.add_child(body)

	# --- Head (sphere) ---
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = HEAD_RADIUS
	sphere.height = HEAD_RADIUS * 2.0
	head.mesh = sphere
	head.material_override = _make_neon_mat(color, opacity, 0.25 if filled else 0.0)
	head.position.y = BODY_HEIGHT + 0.05 + HEAD_RADIUS + 0.02  # On top of body
	root.add_child(head)

	# --- Visor (thin box across the face) ---
	var visor := MeshInstance3D.new()
	var visor_box := BoxMesh.new()
	visor_box.size = VISOR_SIZE
	visor.mesh = visor_box
	visor.material_override = _make_neon_mat(accent, opacity, 1.5 if filled else 0.0)
	visor.position = Vector3(0, head.position.y, HEAD_RADIUS * 0.65)
	root.add_child(visor)

	# --- Shoulders (two small spheres) ---
	if filled:
		for side in [-1.0, 1.0]:
			var shoulder := MeshInstance3D.new()
			var s_mesh := SphereMesh.new()
			s_mesh.radius = 0.08
			s_mesh.height = 0.16
			shoulder.mesh = s_mesh
			shoulder.material_override = _make_neon_mat(color, opacity, 0.15)
			shoulder.position = Vector3(side * (BODY_RADIUS + 0.04), BODY_HEIGHT * 0.75 + 0.05, 0)
			root.add_child(shoulder)

	# Position at spawn point
	var spawn_pos: Vector3 = _spawn_points[slot_index].position
	root.position = Vector3(spawn_pos.x, 0, spawn_pos.z)

	add_child(root)
	_player_figures[slot_index] = root


func _make_neon_mat(color: Color, opacity: float, emission_strength: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, opacity)
	if opacity < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.4
	mat.metallic = 0.2
	if emission_strength > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_strength
	return mat


func _create_label(slot_index: int, text: String, color: Color, opacity: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 32
	label.pixel_size = 0.005
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(color.r, color.g, color.b, opacity)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true

	var spawn_pos: Vector3 = _spawn_points[slot_index].position
	label.position = Vector3(spawn_pos.x, -0.15, spawn_pos.z + 0.45)

	add_child(label)
	_player_labels[slot_index] = label


func _create_particles() -> void:
	var particles := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.5
	mat.gravity = Vector3(0, 0, 0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(5, 0.1, 3)
	mat.color = Color(0.4, 0.2, 0.8, 0.6)
	mat.scale_min = 0.5
	mat.scale_max = 1.5

	var mesh := SphereMesh.new()
	mesh.radius = 0.015
	mesh.height = 0.03

	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(0.5, 0.3, 0.9, 0.8)
	mesh_mat.emission_enabled = true
	mesh_mat.emission = Color(0.4, 0.2, 0.8, 1)
	mesh_mat.emission_energy_multiplier = 2.0
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	particles.process_material = mat
	particles.draw_pass_1 = mesh
	particles.material_override = mesh_mat
	particles.amount = 40
	particles.lifetime = 6.0
	particles.position = Vector3(0, 0.5, 0)
	particles.emitting = true

	add_child(particles)
