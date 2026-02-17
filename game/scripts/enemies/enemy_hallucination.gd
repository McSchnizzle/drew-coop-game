## Hallucination enemy — disguises as a health pickup, reveals and chases when triggered.
## Reveal triggers: player within 4.0 units, takes any damage, or Weak Point Scan (stuns 2s).
extends "res://scripts/enemies/enemy_base.gd"

const HALL_HP: int = 2
const HALL_CHASE_SPEED: float = 3.5  # 70px / 20
const HALL_REVEAL_RANGE: float = 4.0  # 80px / 20
const HALL_CONTACT_DMG: int = 15
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
	_load_glb_model("res://assets/models/monster_slime.fbx", 2.0)  # Match revealed capsule height, not disguised sphere
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
