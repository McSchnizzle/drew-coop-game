## Base enemy class — provides state machine framework, take_damage, status effects.
## All enemy types inherit from this. All game logic runs on the server only.
extends CharacterBody2D

enum State { IDLE, CHASE, ATTACK, FLEE, STUNNED, DEAD }

var enemy_id: int = 0
var health: int = 3
var speed: float = 50.0
var contact_damage: int = 10
var _is_alive: bool = true
var _current_state: State = State.IDLE
var _stun_timer: float = 0.0
var _status_effects: Dictionary = {}  # { effect_name: remaining_duration }

const CONTACT_DAMAGE_COOLDOWN: float = 1.0
var _contact_damage_timer: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	var hurtbox = get_node_or_null("Hurtbox")
	if hurtbox:
		hurtbox.body_entered.connect(_on_hurtbox_body_entered)


func _physics_process(delta: float) -> void:
	if not _is_alive:
		return
	if not multiplayer.is_server():
		return

	_update_status_effects(delta)
	_contact_damage_timer = maxf(_contact_damage_timer - delta, 0.0)
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


# Virtual methods -- override in subclasses
func _state_idle(_delta: float) -> void:
	_transition_to(State.CHASE)


func _state_chase(delta: float) -> void:
	var target := _find_nearest_player()
	if not target:
		_transition_to(State.IDLE)
		return
	var dir := (target.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()


func _state_attack(_delta: float) -> void:
	pass  # Override per enemy type


func _state_flee(delta: float) -> void:
	var target := _find_nearest_player()
	if not target:
		_transition_to(State.IDLE)
		return
	var dir := (global_position - target.global_position).normalized()
	velocity = dir * speed * 0.8
	move_and_slide()


func _state_stunned(delta: float) -> void:
	velocity = Vector2.ZERO
	_stun_timer -= delta
	if _stun_timer <= 0.0:
		_transition_to(State.CHASE)


func _transition_to(new_state: State) -> void:
	_current_state = new_state


func take_damage(amount: int, from_player_id: int) -> void:
	if not _is_alive or not multiplayer.is_server():
		return
	if has_status("exposed"):
		amount *= 2
	health -= amount
	if health <= 0:
		health = 0
		_die(from_player_id)


func _die(killed_by: int) -> void:
	_is_alive = false
	_current_state = State.DEAD
	velocity = Vector2.ZERO
	Events.enemy_died.emit(enemy_id, killed_by, false)
	queue_free()


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


func _find_nearest_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("players")
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for player in players:
		if not player is Node2D or not player.visible:
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
	var hurtbox = get_node_or_null("Hurtbox")
	if not hurtbox:
		return
	for body in hurtbox.get_overlapping_bodies():
		if not body.is_in_group("players") or not body.has_method("take_damage"):
			continue
		if body.get("_is_downed") and body._is_downed:
			continue
		if body.get("_is_alive") != null and not body._is_alive:
			continue
		body.take_damage(contact_damage)
		_contact_damage_timer = CONTACT_DAMAGE_COOLDOWN
		break


func _on_hurtbox_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return
	if body.is_in_group("players") and body.has_method("take_damage"):
		if _contact_damage_timer <= 0.0:
			body.take_damage(contact_damage)
			_contact_damage_timer = CONTACT_DAMAGE_COOLDOWN
