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
const ROLE_MODELS := {
	"striker": "res://assets/models/striker/striker.fbx",
	"engineer": "res://assets/models/pete/pete.fbx",
}
const FALLBACK_MODEL_PATH := "res://assets/models/player_robot.fbx"

# Character proportions
const BODY_RADIUS := 0.18
const BODY_HEIGHT := 0.55
const HEAD_RADIUS := 0.14
const VISOR_SIZE := Vector3(0.22, 0.06, 0.08)
const CHAR_TOTAL_HEIGHT := 0.55  # Tuned for camera framing in lobby SubViewport

var _spawn_points: Array[Marker3D] = []
var _player_figures: Array = []   # Node3D roots for each slot
var _player_labels: Array = []
var _host_label: Label3D          # "Repo Owner" label above host


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
			var base_y: float = _spawn_points[i].position.y
			fig.position.y = base_y + sin(Time.get_ticks_msec() * 0.002 + i * 1.5) * 0.04


## Called by lobby.gd whenever role_assignments or names change.
func set_players(role_assignments: Dictionary, player_names: Dictionary = {}) -> void:
	for i in MAX_PLAYERS:
		if _player_figures[i] != null:
			_player_figures[i].queue_free()
			_player_figures[i] = null
		if _player_labels[i] != null:
			_player_labels[i].queue_free()
			_player_labels[i] = null
	if _host_label:
		_host_label.queue_free()
		_host_label = null

	var player_ids: Array = role_assignments.keys()
	for i in MAX_PLAYERS:
		if i < player_ids.size():
			var pid: int = player_ids[i]
			var role: String = role_assignments[pid]
			var display_name: String = player_names.get(pid, "Player %d" % pid)
			_create_character(i, role, 1.0)
			_create_label(i, display_name, ROLE_COLORS.get(role, EMPTY_COLOR), 1.0)
			if pid == 1:
				_create_host_label(i)
		else:
			_create_character(i, "", 0.3)
			_create_label(i, "Empty", EMPTY_COLOR, 0.3)


func _create_character(slot_index: int, role: String, opacity: float) -> void:
	var root := Node3D.new()
	var color: Color = ROLE_COLORS.get(role, EMPTY_COLOR)
	var filled := opacity >= 1.0

	# Try to load the role-specific 3D model (empty slots use placeholder)
	var model_path: String = ROLE_MODELS.get(role, "")
	var model_scene = load(model_path) if not model_path.is_empty() else null
	if model_scene:
		var model = model_scene.instantiate()
		root.add_child(model)
		# Play Idle animation to get out of T-pose before scaling
		var anim_player := _find_anim_player(model)
		if anim_player:
			_play_idle_anim(anim_player)
		# Auto-scale to lobby display height using full model bounds
		var bounds := _compute_node_bounds(model)
		if bounds.size.y > 0.01:
			var s := CHAR_TOTAL_HEIGHT / bounds.size.y
			model.scale *= s  # Multiply to preserve FBX built-in transforms
		# Recompute bounds after scaling so foot alignment is accurate
		model.position.y = 0.0
		var scaled_bounds := _compute_node_bounds(model)
		if scaled_bounds.size.y > 0.01:
			model.position.y = -scaled_bounds.position.y
		# Only tint empty/fallback slots — real role models keep their original textures
		if not filled:
			var mat := _make_neon_mat(color, opacity, 0.0)
			_apply_material_recursive(model, mat)
	else:
		# Fallback: keep primitive meshes if model fails to load
		_create_placeholder_character(root, color, opacity, filled)

	# Position at spawn point
	var spawn_pos: Vector3 = _spawn_points[slot_index].position
	root.position = spawn_pos

	add_child(root)
	_player_figures[slot_index] = root


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


func _apply_material_recursive(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found:
			return found
	return null


func _play_idle_anim(anim_player: AnimationPlayer) -> void:
	for anim_name in anim_player.get_animation_list():
		if "idle" in anim_name.to_lower():
			var anim := anim_player.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			anim_player.play(anim_name)
			anim_player.advance(0)  # Apply first frame immediately
			return


func _create_placeholder_character(root: Node3D, color: Color, opacity: float, filled: bool) -> void:
	var accent: Color = ROLE_ACCENTS.get("", EMPTY_ACCENT)

	# --- Body (capsule) ---
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	body.mesh = capsule
	body.material_override = _make_neon_mat(color, opacity, 0.2 if filled else 0.0)
	body.position.y = BODY_HEIGHT / 2.0 + 0.05
	root.add_child(body)

	# --- Head (sphere) ---
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = HEAD_RADIUS
	sphere.height = HEAD_RADIUS * 2.0
	head.mesh = sphere
	head.material_override = _make_neon_mat(color, opacity, 0.25 if filled else 0.0)
	head.position.y = BODY_HEIGHT + 0.05 + HEAD_RADIUS + 0.02
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
	label.position = Vector3(spawn_pos.x - 0.08, spawn_pos.y - 0.15, spawn_pos.z)

	add_child(label)
	_player_labels[slot_index] = label


func set_host_label_visible(vis: bool) -> void:
	if _host_label and is_instance_valid(_host_label):
		_host_label.visible = vis


func _create_host_label(slot_index: int) -> void:
	_host_label = Label3D.new()
	_host_label.text = "Repo Owner"
	_host_label.font_size = 24
	_host_label.pixel_size = 0.005
	_host_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_host_label.modulate = Color(0.3, 0.9, 1.0, 1.0)
	_host_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_host_label.no_depth_test = true
	_host_label.outline_size = 4

	var spawn_pos: Vector3 = _spawn_points[slot_index].position
	_host_label.position = Vector3(spawn_pos.x, spawn_pos.y + CHAR_TOTAL_HEIGHT + 0.65, spawn_pos.z)

	add_child(_host_label)


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
