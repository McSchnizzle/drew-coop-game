## 3D lobby stage -- renders player cubes on a floor inside a SubViewport.
extends Node3D

const ROLE_COLORS := {
	"striker": Color(0.910, 0.530, 0.169),
	"engineer": Color(0.231, 0.769, 0.290),
}
const EMPTY_COLOR := Color(0.165, 0.165, 0.220)
const MAX_PLAYERS := 4

# Cube dimensions: taller than wide to feel roughly person-shaped
const CUBE_SIZE := Vector3(0.5, 0.8, 0.4)

var _spawn_points: Array[Marker3D] = []
var _player_cubes: Array = []
var _player_labels: Array = []


func _ready() -> void:
	var spawn_parent := $SpawnPositions
	for i in MAX_PLAYERS:
		_spawn_points.append(spawn_parent.get_node("Spawn%d" % i))

	_player_cubes.resize(MAX_PLAYERS)
	_player_labels.resize(MAX_PLAYERS)
	for i in MAX_PLAYERS:
		_player_cubes[i] = null
		_player_labels[i] = null


## Called by lobby.gd whenever role_assignments or names change.
func set_players(role_assignments: Dictionary, player_names: Dictionary = {}) -> void:
	# Remove existing cubes and labels
	for i in MAX_PLAYERS:
		if _player_cubes[i] != null:
			_player_cubes[i].queue_free()
			_player_cubes[i] = null
		if _player_labels[i] != null:
			_player_labels[i].queue_free()
			_player_labels[i] = null

	# Create cubes and labels for connected players
	var player_ids: Array = role_assignments.keys()
	for i in MAX_PLAYERS:
		if i < player_ids.size():
			var pid: int = player_ids[i]
			var role: String = role_assignments[pid]
			var display_name: String = player_names.get(pid, "Player %d" % pid)
			_create_cube(i, ROLE_COLORS.get(role, EMPTY_COLOR), 1.0)
			_create_label(i, display_name, ROLE_COLORS.get(role, EMPTY_COLOR), 1.0)
		else:
			_create_cube(i, EMPTY_COLOR, 0.3)
			_create_label(i, "Empty", EMPTY_COLOR, 0.3)


func _create_cube(slot_index: int, color: Color, opacity: float) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = CUBE_SIZE
	mesh_instance.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, opacity)
	if opacity < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.6
	mat.metallic = 0.1
	# Subtle emission glow for filled cubes
	if opacity >= 1.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.15
	mesh_instance.material_override = mat

	# Position cube so bottom sits on the floor (Y=0)
	var spawn_pos: Vector3 = _spawn_points[slot_index].position
	mesh_instance.position = Vector3(spawn_pos.x, CUBE_SIZE.y / 2.0, spawn_pos.z)

	add_child(mesh_instance)
	_player_cubes[slot_index] = mesh_instance


func _create_label(slot_index: int, text: String, color: Color, opacity: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 32
	label.pixel_size = 0.005
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(color.r, color.g, color.b, opacity)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true  # Always visible, even through the floor

	# Position centered below the cube (offset toward camera so it appears underneath)
	var spawn_pos: Vector3 = _spawn_points[slot_index].position
	label.position = Vector3(spawn_pos.x, -0.15, spawn_pos.z + 0.45)

	add_child(label)
	_player_labels[slot_index] = label
