## 3D lobby stage -- dark brick bunker room with per-slot spotlights.
## Empty slots stay dark and mysterious. Spotlights light up when players join.
extends Node3D

const ROLE_COLORS := {
	"striker": Color(0.910, 0.530, 0.169),
	"engineer": Color(0.231, 0.769, 0.290),
}
const ROLE_ACCENTS := {
	"striker": Color(1.0, 0.2, 0.6),
	"engineer": Color(0.0, 0.9, 0.9),
}
const EMPTY_COLOR := Color(0.165, 0.165, 0.220)
const MAX_PLAYERS := 4
const ROLE_MODELS := {
	"striker": "res://assets/models/striker/striker.fbx",
	"engineer": "res://assets/models/pete/pete.fbx",
}

# Character display height
const CHAR_TOTAL_HEIGHT := 1.8

# Room dimensions
const ROOM_WIDTH := 10.0
const ROOM_DEPTH := 8.0
const ROOM_HEIGHT := 4.0

# Fixed X positions for each of the 4 lantern slots
const SLOT_POSITIONS := [-1.8, -0.6, 0.6, 1.8]

# Which slots to use based on player count (keeps characters centered)
const CENTER_SLOTS := {
	1: [1],            # x=-0.6, near center
	2: [1, 2],         # x=-0.6, 0.6 — straddling center
	3: [0, 1, 2],      # three left-center slots
	4: [0, 1, 2, 3],   # all four
}

var _spawn_points: Array[Marker3D] = []
var _player_figures: Array = []
var _player_labels: Array = []
var _host_label: Label3D
var _room_built := false

# Per-slot lights
var _slot_lantern_meshes: Array = []  # (unused, kept for array sizing)
var _slot_lantern_lights: Array = []  # SpotLight3D — front spotlight on character
var _slot_lantern_glow_mats: Array = []  # (unused)
var _slot_wall_lights: Array = []  # SpotLight3D — wall-mounted light behind player


func _ready() -> void:
	var spawn_parent := $SpawnPositions
	for i in MAX_PLAYERS:
		_spawn_points.append(spawn_parent.get_node("Spawn%d" % i))
		# Set fixed slot positions
		_spawn_points[i].position.x = SLOT_POSITIONS[i]

	_player_figures.resize(MAX_PLAYERS)
	_player_labels.resize(MAX_PLAYERS)
	_slot_lantern_meshes.resize(MAX_PLAYERS)
	_slot_lantern_lights.resize(MAX_PLAYERS)
	_slot_lantern_glow_mats.resize(MAX_PLAYERS)
	_slot_wall_lights.resize(MAX_PLAYERS)
	for i in MAX_PLAYERS:
		_player_figures[i] = null
		_player_labels[i] = null
		_slot_lantern_meshes[i] = null
		_slot_lantern_lights[i] = null
		_slot_lantern_glow_mats[i] = null
		_slot_wall_lights[i] = null

	_build_room()
	_create_particles()


func _process(_delta: float) -> void:
	# Subtle idle bob (no spinning — characters face the camera)
	for i in MAX_PLAYERS:
		if _player_figures[i] != null:
			var fig: Node3D = _player_figures[i]
			var base_y: float = _spawn_points[i].position.y
			fig.position.y = base_y + sin(Time.get_ticks_msec() * 0.002 + i * 1.5) * 0.02


## Called by lobby.gd whenever role_assignments or names change.
func set_players(role_assignments: Dictionary, player_names: Dictionary = {}) -> void:
	# Clean up existing figures and labels
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
	var player_count := player_ids.size()
	var slots: Array = CENTER_SLOTS.get(player_count, CENTER_SLOTS[4])

	# Turn all lanterns off first
	for i in MAX_PLAYERS:
		_set_lantern_lit(i, false)

	# Place each player at a centered slot and light that lantern
	for pi in player_count:
		if pi >= slots.size():
			break
		var slot_idx: int = slots[pi]
		var pid: int = player_ids[pi]
		var role: String = role_assignments[pid]
		var display_name: String = player_names.get(pid, "Player %d" % pid)
		_create_character(slot_idx, role)
		_create_label(slot_idx, display_name, ROLE_COLORS.get(role, EMPTY_COLOR))
		_set_lantern_lit(slot_idx, true)
		if pid == 1:
			_create_host_label(slot_idx)


func _create_character(slot_index: int, role: String) -> void:
	var root := Node3D.new()

	var model_path: String = ROLE_MODELS.get(role, "")
	var model_scene = load(model_path) if not model_path.is_empty() else null
	if model_scene:
		var model = model_scene.instantiate()
		root.add_child(model)
		# Load proper idle animation (Mixamo FBX names don't match "idle" search)
		var anim_player := _load_idle_animation_on(model)
		if anim_player:
			anim_player.play("Idle")
			anim_player.advance(0)
		# Auto-scale to lobby display height
		var bounds := _compute_node_bounds(model)
		if bounds.size.y > 0.01:
			var s := CHAR_TOTAL_HEIGHT / bounds.size.y
			model.scale *= s
		# Foot alignment
		model.position.y = 0.0
		var scaled_bounds := _compute_node_bounds(model)
		if scaled_bounds.size.y > 0.01:
			model.position.y = -scaled_bounds.position.y

	var spawn_pos: Vector3 = _spawn_points[slot_index].position
	root.position = spawn_pos

	# Small face light — tight spot aimed at the head so you can see the face
	var face_light := SpotLight3D.new()
	face_light.position = Vector3(0, CHAR_TOTAL_HEIGHT - 0.15, 1.2)  # In front of face
	face_light.rotation_degrees = Vector3(0, 0, 0)  # Points -Z, toward the face
	face_light.light_color = Color(1.0, 0.97, 0.93)
	face_light.light_energy = 3.0
	face_light.spot_range = 2.0
	face_light.spot_angle = 12.0  # Very tight — just the head
	face_light.shadow_enabled = false
	root.add_child(face_light)

	# Body light — wider spot covering torso down to feet
	var body_light := SpotLight3D.new()
	body_light.position = Vector3(0, 0.8, 1.5)  # In front of mid-body
	body_light.rotation_degrees = Vector3(0, 0, 0)  # Points -Z, toward the body
	body_light.light_color = Color(1.0, 0.97, 0.93)
	body_light.light_energy = 3.0
	body_light.spot_range = 2.5
	body_light.spot_angle = 25.0  # Wider — covers torso to feet
	body_light.shadow_enabled = false
	root.add_child(body_light)

	add_child(root)
	_player_figures[slot_index] = root


# ── Animation Loading (ported from player.gd) ────────────────────────────

func _load_idle_animation_on(model_node: Node3D) -> AnimationPlayer:
	var ap := _find_anim_player(model_node)
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

	var target_skel := _find_skeleton_in(model_node)
	var skel_path_str := ""
	var bone_remap := {}
	if target_skel:
		skel_path_str = str(model_node.get_path_to(target_skel))
		for i in target_skel.get_bone_count():
			var bname := target_skel.get_bone_name(i)
			var base := _strip_mixamo_prefix(bname)
			bone_remap[base] = bname

	var idle_path := "res://assets/models/ybot/pistol_idle.fbx"
	var scene: PackedScene = load(idle_path) as PackedScene
	if not scene:
		return ap
	var temp: Node = scene.instantiate()
	var temp_player := _find_anim_player(temp)
	if not temp_player:
		temp.free()
		return ap
	var anim_list := temp_player.get_animation_list()
	if anim_list.is_empty():
		temp.free()
		return ap
	var pick_name: String = anim_list[0]
	for candidate in anim_list:
		if "mixamo" in candidate.to_lower():
			pick_name = candidate
			break
	var source_anim: Animation = temp_player.get_animation(pick_name)
	if source_anim:
		var anim_copy := source_anim.duplicate()
		_strip_root_motion(anim_copy)
		_remap_anim_tracks(anim_copy, skel_path_str, bone_remap)
		anim_copy.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation("Idle", anim_copy)
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
		var base_bone := _strip_mixamo_prefix(subname)
		var new_bone: String = bone_remap.get(base_bone, subname)
		anim.track_set_path(track_idx, NodePath(skel_path + ":" + new_bone))


func _strip_root_motion(anim: Animation) -> void:
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


func _find_skeleton_in(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton_in(child)
		if found:
			return found
	return null


# ── Room Construction ─────────────────────────────────────────────────────

func _build_room() -> void:
	if _room_built:
		return
	_room_built = true

	var room := Node3D.new()
	room.name = "Room"
	add_child(room)

	var hw := ROOM_WIDTH / 2.0
	var hd := ROOM_DEPTH / 2.0

	# Load brick wall shader
	var brick_shader = load("res://shaders/brick_wall.gdshader")

	# --- Walls (brick shader) ---
	var back_wall := _make_box_mesh(Vector3(ROOM_WIDTH, ROOM_HEIGHT, 0.2))
	back_wall.material_override = _make_brick_mat(brick_shader, Vector2(5.0, 3.5))
	back_wall.position = Vector3(0, ROOM_HEIGHT / 2.0, -hd)
	room.add_child(back_wall)

	var left_wall := _make_box_mesh(Vector3(0.2, ROOM_HEIGHT, ROOM_DEPTH))
	left_wall.material_override = _make_brick_mat(brick_shader, Vector2(4.0, 3.5))
	left_wall.position = Vector3(-hw, ROOM_HEIGHT / 2.0, 0)
	room.add_child(left_wall)

	var right_wall := _make_box_mesh(Vector3(0.2, ROOM_HEIGHT, ROOM_DEPTH))
	right_wall.material_override = _make_brick_mat(brick_shader, Vector2(4.0, 3.5))
	right_wall.position = Vector3(hw, ROOM_HEIGHT / 2.0, 0)
	room.add_child(right_wall)

	# --- Ceiling (dark concrete) ---
	var ceiling := _make_box_mesh(Vector3(ROOM_WIDTH, 0.2, ROOM_DEPTH))
	ceiling.material_override = _make_dark_concrete_mat()
	ceiling.position = Vector3(0, ROOM_HEIGHT, 0)
	room.add_child(ceiling)

	# --- Concrete floor ---
	_add_concrete_floor(room)

	# --- Neon strip lines on the floor ---
	_add_floor_strips(room)

	# --- Per-slot ceiling lanterns ---
	for i in MAX_PLAYERS:
		_add_slot_lantern(room, i)

	# --- Subtle accent strips along back wall base ---
	_add_wall_base_strips(room)


func _make_brick_mat(shader: Shader, uv_scale: Vector2) -> Material:
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("uv_scale", uv_scale)
		return mat
	# Fallback if shader doesn't load
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.08, 0.07)
	mat.roughness = 0.9
	return mat


func _make_dark_concrete_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.06, 0.07)
	mat.roughness = 0.9
	mat.metallic = 0.0
	return mat


func _make_box_mesh(size: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	return mi


func _add_concrete_floor(parent: Node3D) -> void:
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(ROOM_WIDTH, ROOM_DEPTH)
	floor_mesh.mesh = plane
	floor_mesh.name = "ConcreteFloor"

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.07, 0.07, 0.08)
	mat.roughness = 0.85
	mat.metallic = 0.05
	floor_mesh.material_override = mat
	floor_mesh.position = Vector3(0, 0.0, 0)
	parent.add_child(floor_mesh)


func _add_floor_strips(parent: Node3D) -> void:
	## Thin neon cyan strip lines running across the floor (left to right).
	var cyan := Color(0.0, 0.85, 1.0)
	var strip_mat := StandardMaterial3D.new()
	strip_mat.albedo_color = cyan
	strip_mat.emission_enabled = true
	strip_mat.emission = cyan
	strip_mat.emission_energy_multiplier = 2.0

	var hw := ROOM_WIDTH / 2.0
	var hd := ROOM_DEPTH / 2.0
	var strip_count := 7
	var spacing := ROOM_DEPTH / float(strip_count + 1)

	for i in strip_count:
		var z_pos := -hd + spacing * float(i + 1)
		var strip := _make_box_mesh(Vector3(ROOM_WIDTH - 0.5, 0.008, 0.025))
		strip.material_override = strip_mat
		strip.position = Vector3(0, 0.005, z_pos)
		parent.add_child(strip)


func _add_wall_base_strips(parent: Node3D) -> void:
	## Dim cyan accent strip along the base of the back wall.
	var cyan_dim := Color(0.0, 0.5, 0.7)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cyan_dim
	mat.emission_enabled = true
	mat.emission = cyan_dim
	mat.emission_energy_multiplier = 1.0

	var hw := ROOM_WIDTH / 2.0
	var hd := ROOM_DEPTH / 2.0

	# Back wall base
	var back_strip := _make_box_mesh(Vector3(ROOM_WIDTH - 0.4, 0.025, 0.025))
	back_strip.material_override = mat
	back_strip.position = Vector3(0, 0.015, -hd + 0.12)
	parent.add_child(back_strip)

	# Side wall bases
	for x_sign in [-1.0, 1.0]:
		var side_strip := _make_box_mesh(Vector3(0.025, 0.025, ROOM_DEPTH - 0.4))
		side_strip.material_override = mat
		side_strip.position = Vector3(x_sign * (hw - 0.12), 0.015, 0)
		parent.add_child(side_strip)


func _add_slot_lantern(parent: Node3D, slot_index: int) -> void:
	## Create a ceiling lantern above the given slot. Starts dark (unlit).
	var x_pos: float = SLOT_POSITIONS[slot_index]
	var lantern_y := ROOM_HEIGHT - 0.25  # Hang slightly below ceiling

	# Cord from ceiling to lantern
	var cord := MeshInstance3D.new()
	var cord_cyl := CylinderMesh.new()
	cord_cyl.top_radius = 0.008
	cord_cyl.bottom_radius = 0.008
	cord_cyl.height = 0.5
	cord.mesh = cord_cyl
	var cord_mat := StandardMaterial3D.new()
	cord_mat.albedo_color = Color(0.1, 0.1, 0.1)
	cord.material_override = cord_mat
	cord.position = Vector3(x_pos, ROOM_HEIGHT - 0.25, 0)
	parent.add_child(cord)

	# Lantern body (small cone/cylinder shape)
	var lantern_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.18
	cyl.height = 0.15
	lantern_mesh.mesh = cyl
	# Start with unlit (dark) material
	var unlit_mat := StandardMaterial3D.new()
	unlit_mat.albedo_color = Color(0.08, 0.08, 0.08)
	unlit_mat.roughness = 0.8
	lantern_mesh.material_override = unlit_mat
	lantern_mesh.position = Vector3(x_pos, lantern_y, 0)
	parent.add_child(lantern_mesh)
	_slot_lantern_meshes[slot_index] = lantern_mesh

	# SpotLight3D angled down from the lantern
	var spot := SpotLight3D.new()
	spot.position = Vector3(x_pos, lantern_y - 0.1, 0)
	spot.rotation_degrees = Vector3(-65, 0, 0)  # Tilted ~25° toward back wall
	spot.light_color = Color(1.0, 0.93, 0.82)  # Warm white
	spot.light_energy = 14.0
	spot.spot_range = 10.0
	spot.spot_angle = 45.0
	spot.shadow_enabled = true
	spot.visible = false  # Start off
	parent.add_child(spot)
	_slot_lantern_lights[slot_index] = spot

	_slot_wall_lights[slot_index] = null


func _set_lantern_lit(slot_index: int, lit: bool) -> void:
	## Turn a slot's lantern on or off.
	var light: SpotLight3D = _slot_lantern_lights[slot_index]
	if light:
		light.visible = lit

	var mesh: MeshInstance3D = _slot_lantern_meshes[slot_index]
	if mesh:
		if lit:
			var lit_mat := StandardMaterial3D.new()
			lit_mat.albedo_color = Color(1.0, 0.93, 0.82)
			lit_mat.emission_enabled = true
			lit_mat.emission = Color(1.0, 0.9, 0.7)
			lit_mat.emission_energy_multiplier = 4.0
			mesh.material_override = lit_mat
		else:
			var unlit_mat := StandardMaterial3D.new()
			unlit_mat.albedo_color = Color(0.08, 0.08, 0.08)
			unlit_mat.roughness = 0.8
			mesh.material_override = unlit_mat

	var wall_light: SpotLight3D = _slot_wall_lights[slot_index]
	if wall_light:
		wall_light.visible = lit


# ── Utility Functions ─────────────────────────────────────────────────────

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


func _create_label(slot_index: int, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 42
	label.pixel_size = 0.005
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(color.r, color.g, color.b, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true

	var spawn_pos: Vector3 = _spawn_points[slot_index].position
	label.position = Vector3(spawn_pos.x, -0.15, spawn_pos.z + 0.4)

	add_child(label)
	_player_labels[slot_index] = label


func set_host_label_visible(vis: bool) -> void:
	if _host_label and is_instance_valid(_host_label):
		_host_label.visible = vis


func _create_host_label(slot_index: int) -> void:
	_host_label = Label3D.new()
	_host_label.text = "Repo Owner"
	_host_label.font_size = 32
	_host_label.pixel_size = 0.005
	_host_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_host_label.modulate = Color(0.3, 0.9, 1.0, 1.0)
	_host_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_host_label.no_depth_test = true
	_host_label.outline_size = 4

	var spawn_pos: Vector3 = _spawn_points[slot_index].position
	_host_label.position = Vector3(spawn_pos.x, CHAR_TOTAL_HEIGHT + 0.3, spawn_pos.z)

	add_child(_host_label)


func _create_particles() -> void:
	# Very subtle floating dust in the dark room
	var particles := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0.5, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 0.02
	mat.initial_velocity_max = 0.08
	mat.gravity = Vector3(0, 0, 0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(4.0, 1.8, 3.0)
	mat.color = Color(0.5, 0.5, 0.5, 0.15)
	mat.scale_min = 0.2
	mat.scale_max = 0.5

	var mesh := SphereMesh.new()
	mesh.radius = 0.008
	mesh.height = 0.016

	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(0.6, 0.6, 0.6, 0.2)
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	particles.process_material = mat
	particles.draw_pass_1 = mesh
	particles.material_override = mesh_mat
	particles.amount = 20
	particles.lifetime = 10.0
	particles.position = Vector3(0, 2.0, 0)
	particles.emitting = true

	add_child(particles)
