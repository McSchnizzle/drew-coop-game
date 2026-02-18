## Base enemy class — provides state machine framework, take_damage, status effects.
## All enemy types inherit from this. All game logic runs on the server only.
extends CharacterBody3D

enum State { IDLE, CHASE, ATTACK, FLEE, STUNNED, DEAD }

var enemy_id: int = 0
var health: int = 3
var speed: float = 2.5
var contact_damage: int = 10
var _is_alive: bool = true
var _current_state: State = State.IDLE
var _stun_timer: float = 0.0
var _status_effects: Dictionary = {}  # { effect_name: remaining_duration }
var _model_node: Node3D = null  # The visual model root (GLB instance or placeholder)
var _anim_player: AnimationPlayer = null

const CONTACT_DAMAGE_COOLDOWN: float = 1.0
const CONTACT_RANGE: float = 2.5  # 50px / 20
const GRAVITY: float = 20.0
var _contact_damage_timer: float = 0.0
var _attack_timer: float = 0.0
var _attack_hit_landed: bool = false
var _attack_target: Node3D = null  # The player/turret we're attacking
const ATTACK_DURATION: float = 0.5
const ATTACK_HIT_POINT: float = 0.4  # Deal damage at 40% through the animation


func _ready() -> void:
	add_to_group("enemies")
	# Layer 3 = enemies. Mask includes layer 1 (walls) + layer 2 (players).
	# Enemies push players and stop at walls, but pass through each other.
	collision_layer = 4   # Layer 3
	collision_mask = 3    # Layers 1 + 2 (walls + players)


func _get_model_mesh() -> MeshInstance3D:
	# Recursively search the GLB tree for the first MeshInstance3D.
	if _model_node:
		var found := _find_mesh_recursive(_model_node)
		if found:
			return found
	# Fallback to placeholder
	return get_node_or_null("EnemyModel") as MeshInstance3D


func _find_mesh_recursive(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_recursive(child)
		if found:
			return found
	return null


func _load_glb_model(glb_path: String, target_height: float = 0.0) -> void:
	var scene = load(glb_path)
	if not scene:
		return
	_model_node = scene.instantiate()
	add_child(_model_node)
	# Auto-scale to match collision shape (or explicit target_height)
	if target_height <= 0.0:
		target_height = _get_collision_height()
	if target_height > 0.0:
		_fit_model_to_height(target_height)
	# Find AnimationPlayer for walk/idle animations
	_anim_player = _find_anim_player(_model_node)
	if _anim_player:
		# Stop any auto-playing FBX animation (e.g. "Take 001") to avoid stuck poses
		_anim_player.stop()
		_anim_player.autoplay = ""
	# Hide the placeholder
	var placeholder = get_node_or_null("EnemyModel") as MeshInstance3D
	if placeholder:
		placeholder.visible = false


func _get_collision_height() -> float:
	for child in get_children():
		if child is CollisionShape3D:
			var shape = child.shape
			if shape is CapsuleShape3D:
				return shape.height
			elif shape is BoxShape3D:
				return shape.size.y
			elif shape is SphereShape3D:
				return shape.radius * 2.0
			break
	return 0.0


func _fit_model_to_height(target_height: float) -> void:
	if not _model_node:
		return
	# Compute visual bounds including all internal transforms (armature, skeleton, etc.)
	var bounds := _compute_model_bounds()
	if bounds.size.y > 0.01:
		var scale_factor := target_height / bounds.size.y
		# Multiply (not replace) to preserve FBX's built-in transforms
		_model_node.scale *= scale_factor
	# Align model feet to bottom of collision shape
	_reposition_model()


func _reposition_model() -> void:
	## Recalculate model Y position to align feet to bottom of collision shape.
	## Call after any scale or collision shape change (e.g. tier scaling).
	if not _model_node:
		return
	# Reset Y to 0 so bounds computation isn't circular
	_model_node.position.y = 0.0
	var bounds := _compute_model_bounds()
	if bounds.size.y > 0.01:
		var collision_height := _get_collision_height()
		_model_node.position.y = -bounds.position.y - collision_height / 2.0


func _compute_model_bounds() -> AABB:
	if not _model_node:
		return AABB()
	var points: PackedVector3Array = PackedVector3Array()
	_collect_mesh_points(_model_node, Transform3D.IDENTITY, points)
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


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found:
			return found
	return null


func _tint_model(color: Color, emission: float = 0.3) -> void:
	if not _model_node:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = emission
	mat.roughness = 0.5
	_apply_material_recursive(_model_node, mat)


func _apply_material_recursive(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)


func _load_external_animations(anim_map: Dictionary) -> void:
	## Load animations from separate FBX files into the model's AnimationPlayer.
	## anim_map: { "Walk": "res://path/to/walk.fbx", "Death": "res://path/to/death.fbx", ... }
	if not _model_node:
		return
	if not _anim_player:
		_anim_player = AnimationPlayer.new()
		_model_node.add_child(_anim_player)
		_anim_player.root_node = _anim_player.get_path_to(_model_node)

	# Always create a FRESH library per instance. Godot shares sub-resources
	# across instances of the same imported scene, so modifying the existing
	# library from one enemy would corrupt animations on all other enemies.
	var lib := AnimationLibrary.new()
	if _anim_player.has_animation_library(""):
		_anim_player.remove_animation_library("")
	_anim_player.add_animation_library("", lib)

	for anim_name in anim_map:
		var fbx_path: String = anim_map[anim_name]
		var scene: PackedScene = load(fbx_path) as PackedScene
		if not scene:
			continue
		var temp: Node = scene.instantiate()
		var temp_player := _find_anim_player(temp)
		if not temp_player:
			temp.free()
			continue
		var anim_list := temp_player.get_animation_list()
		if anim_list.is_empty():
			temp.free()
			continue
		# Prefer "mixamo_com" (the real animation), not "Take 001" (empty default FBX take)
		var pick_name: String = anim_list[0]
		for candidate in anim_list:
			if "mixamo" in candidate.to_lower():
				pick_name = candidate
				break
		var source_anim: Animation = temp_player.get_animation(pick_name)
		if source_anim:
			var anim_copy := source_anim.duplicate()
			_strip_root_motion(anim_copy)
			if anim_name in ["Idle", "Walk", "Run"]:
				anim_copy.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(anim_name, anim_copy)
		temp.free()
	# Start in idle pose now that real animations are available
	_play_anim("Idle")


func _strip_root_motion(anim: Animation) -> void:
	## Zero out horizontal (X/Z) movement on the Hips bone so animations play in-place.
	## Keeps Y for natural bounce. Without this, the animation fights move_and_slide().
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


const ANIM_BLEND_TIME: float = 0.25  # Cross-fade duration between animations

func _play_anim(anim_name: String, blend: float = ANIM_BLEND_TIME) -> void:
	if not _anim_player:
		return
	var found_name: String = ""
	# Try exact name, then common variations
	for try_name in [anim_name, anim_name.to_lower(), anim_name.to_upper()]:
		if _anim_player.has_animation(try_name):
			found_name = try_name
			break
	# Try partial match (e.g. "Walk" matches "Robot_Walk")
	if found_name.is_empty():
		for a_name in _anim_player.get_animation_list():
			if anim_name.to_lower() in a_name.to_lower():
				found_name = a_name
				break
	if found_name.is_empty():
		return
	# Ensure looping animations actually loop (FBX imports often default to non-looping)
	var anim := _anim_player.get_animation(found_name)
	if anim and anim_name in ["Walk", "Idle", "Run"]:
		anim.loop_mode = Animation.LOOP_LINEAR
	if _anim_player.current_animation != found_name:
		_anim_player.play(found_name, blend)


func _process(_delta: float) -> void:
	# Rotate model to face nearest player (runs on all peers for visual)
	var model = _get_model_mesh()
	if not model:
		return
	var target := _find_nearest_player()
	if target:
		var dir := target.global_position - global_position
		dir.y = 0
		if dir.length_squared() > 0.001:
			dir = dir.normalized()
			rotation.y = atan2(dir.x, dir.z)


func _physics_process(delta: float) -> void:
	if not _is_alive:
		return
	if not multiplayer.is_server():
		return

	# Gravity — ensures split children and spawned enemies settle on the floor
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	_update_status_effects(delta)
	_contact_damage_timer = maxf(_contact_damage_timer - delta, 0.0)
	if _current_state != State.ATTACK:
		_check_contact_damage()

	match _current_state:
		State.IDLE:
			_state_idle(delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACK:
			_state_attack(delta)
		State.FLEE:
			_state_flee(delta)
		State.STUNNED:
			_state_stunned(delta)
		State.DEAD:
			pass

	move_and_slide()


# Virtual methods -- override in subclasses
func _state_idle(_delta: float) -> void:
	_transition_to(State.CHASE)


func _state_chase(_delta: float) -> void:
	var target := _find_nearest_player()
	if not target:
		_transition_to(State.IDLE)
		return
	var dir := (target.global_position - global_position)
	dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed


func _start_attack() -> void:
	## Reset attack state and begin a fresh attack animation.
	_attack_timer = 0.0
	_attack_hit_landed = false
	_current_state = State.ATTACK
	# Force animation restart (stop first so _play_anim doesn't skip it)
	if _anim_player:
		_anim_player.stop()
	_play_anim("Attack")


func _state_attack(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_attack_timer += delta
	# Use real animation length so the full punch/swipe plays out
	var duration := ATTACK_DURATION
	if _anim_player and _anim_player.has_animation("Attack"):
		duration = _anim_player.get_animation("Attack").length

	# Deal damage at the hit point of the animation (when the punch connects visually)
	# Only hits if target is still within melee range
	if not _attack_hit_landed and _attack_timer >= duration * ATTACK_HIT_POINT:
		_attack_hit_landed = true
		if is_instance_valid(_attack_target):
			var hit_dist := global_position.distance_to(_attack_target.global_position)
			if hit_dist <= CONTACT_RANGE * 1.5 and _attack_target.has_method("take_damage"):
				if _attack_target.is_in_group("turrets"):
					_attack_target.take_damage(contact_damage, enemy_id)
				else:
					_attack_target.take_damage(contact_damage)
				_contact_damage_timer = CONTACT_DAMAGE_COOLDOWN
				_show_melee_strike.rpc(global_position.lerp(_attack_target.global_position, 0.5))

	# Animation finished — attack again or chase
	if _attack_timer >= duration:
		var target := _find_nearest_player()
		if target and global_position.distance_to(target.global_position) <= CONTACT_RANGE * 1.5:
			_attack_target = target
			_start_attack()
		else:
			_attack_target = null
			_attack_timer = 0.0
			_attack_hit_landed = false
			_transition_to(State.CHASE)


func _state_flee(_delta: float) -> void:
	var target := _find_nearest_player()
	if not target:
		_transition_to(State.IDLE)
		return
	var dir := (global_position - target.global_position)
	dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * speed * 0.8
	velocity.z = dir.z * speed * 0.8


func _state_stunned(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_stun_timer -= delta
	if _stun_timer <= 0.0:
		_transition_to(State.CHASE)


func _transition_to(new_state: State) -> void:
	_current_state = new_state
	# Play matching animation
	match new_state:
		State.IDLE:
			_play_anim("Idle")
		State.CHASE:
			_play_anim("Walk")
		State.ATTACK:
			_play_anim("Attack")
		State.FLEE:
			_play_anim("Walk")
		State.STUNNED:
			_play_anim("Idle")
		State.DEAD:
			_play_anim("Death")


func take_damage(amount: int, from_player_id: int) -> void:
	if not _is_alive or not multiplayer.is_server():
		return
	if has_status("exposed"):
		amount *= 2
	health -= amount
	_show_hit_flash.rpc()
	if health <= 0:
		health = 0
		_die(from_player_id)


@rpc("authority", "call_local", "reliable")
func _show_hit_flash() -> void:
	if not is_inside_tree():
		return
	# Brief white emission flash so players see damage landing.
	var model = _get_model_mesh()
	if not model:
		return
	var mat = model.get_active_material(0)
	if not mat or not mat is StandardMaterial3D:
		return
	var original_emission: Color = mat.emission
	var original_emission_enabled: bool = mat.emission_enabled
	mat.emission_enabled = true
	mat.emission = Color(3.0, 3.0, 3.0)
	# Use create_tween() so the tween is killed when this node is freed (no stale lambda).
	var tween := create_tween()
	tween.tween_interval(0.1)
	tween.tween_callback(func():
		if is_instance_valid(model) and mat:
			mat.emission_enabled = original_emission_enabled
			mat.emission = original_emission
	)


@rpc("authority", "call_local", "reliable")
func _show_melee_strike(hit_pos: Vector3) -> void:
	if not is_inside_tree():
		return
	# Flash the enemy model orange to show it's attacking
	var model = _get_model_mesh()
	if model:
		var mat = model.get_active_material(0)
		if mat and mat is StandardMaterial3D:
			var original_emission: Color = mat.emission
			var original_emission_enabled: bool = mat.emission_enabled
			mat.emission_enabled = true
			mat.emission = Color(2.5, 0.6, 0.2)
			var flash_tween := create_tween()
			flash_tween.tween_interval(0.15)
			flash_tween.tween_callback(func():
				if is_instance_valid(model) and mat:
					mat.emission_enabled = original_emission_enabled
					mat.emission = original_emission
			)

	# Spawn an expanding hit ring at the contact point
	var ring := _create_hit_ring()
	get_tree().current_scene.add_child(ring)
	ring.global_position = hit_pos


func _create_hit_ring() -> Node3D:
	var node := Node3D.new()
	# Create an expanding sphere mesh as hit ring
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	mesh_instance.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.4, 0.1, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.1)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = mat
	node.add_child(mesh_instance)

	# Animate: scale up and fade out over 0.3s
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_instance, "scale", Vector3(4.0, 4.0, 4.0), 0.3)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tween.set_parallel(false)
	tween.tween_callback(node.queue_free)

	return node


func _die(killed_by: int) -> void:
	_is_alive = false
	_current_state = State.DEAD
	velocity = Vector3.ZERO
	_transition_to(State.DEAD)
	Events.enemy_died.emit(enemy_id, killed_by, false)
	# Delay free so death animation plays
	_delayed_free()


func _delayed_free() -> void:
	# Wait for death animation to finish, then free the node
	var death_time := 1.5
	if _anim_player and _anim_player.has_animation("Death"):
		death_time = _anim_player.get_animation("Death").length
	# Disable collision so dead enemy doesn't block movement
	collision_layer = 0
	collision_mask = 0
	var tween := create_tween()
	tween.tween_interval(death_time)
	tween.tween_callback(queue_free)


func apply_status(effect_name: String, duration: float) -> void:
	_status_effects[effect_name] = duration


func has_status(effect_name: String) -> bool:
	return _status_effects.has(effect_name) and _status_effects[effect_name] > 0.0


func _update_status_effects(delta: float) -> void:
	var expired: Array[String] = []
	for effect_name in _status_effects:
		_status_effects[effect_name] -= delta
		if _status_effects[effect_name] <= 0.0:
			expired.append(effect_name)
	for effect_name in expired:
		_status_effects.erase(effect_name)


func _find_nearest_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("players")
	var nearest: Node3D = null
	var nearest_dist: float = INF
	for player in players:
		if not player is Node3D or not player.visible:
			continue
		# Skip downed or dead players
		if player.get("_is_downed") and player._is_downed:
			continue
		if player.get("_is_alive") != null and not player._is_alive:
			continue
		var dist := global_position.distance_to(player.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = player
	return nearest


func apply_scaling(health_scale: float, speed_scale: float) -> void:
	health = int(ceil(health * health_scale))
	speed = speed * speed_scale


func _check_contact_damage() -> void:
	if _contact_damage_timer > 0.0:
		return
	# Distance-based check — Area3D overlap fails because CharacterBody3D
	# physics pushes bodies apart so they never truly overlap.
	var players := get_tree().get_nodes_in_group("players")
	for player in players:
		if not player is Node3D or not player.visible:
			continue
		if player.get("_is_downed") and player._is_downed:
			continue
		if player.get("_is_alive") != null and not player._is_alive:
			continue
		var dist := global_position.distance_to(player.global_position)
		if dist <= CONTACT_RANGE:
			# Don't deal damage yet — start the attack animation first.
			# Damage lands at ATTACK_HIT_POINT through the animation.
			_attack_target = player
			_start_attack()
			return

	# Also check turrets.
	var turrets := get_tree().get_nodes_in_group("turrets")
	for turret in turrets:
		if not turret is Node3D or not turret.visible:
			continue
		if turret.get("_is_alive") != null and not turret._is_alive:
			continue
		var dist := global_position.distance_to(turret.global_position)
		if dist <= CONTACT_RANGE:
			_attack_target = turret
			_start_attack()
			return
