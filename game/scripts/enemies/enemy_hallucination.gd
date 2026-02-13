## Hallucination enemy — disguises as a health pickup, reveals and chases when triggered.
## Reveal triggers: player within 80px, takes any damage, or Weak Point Scan (stuns 2s).
extends "res://scripts/enemies/enemy_base.gd"

const HALL_HP: int = 2
const HALL_CHASE_SPEED: float = 70.0
const HALL_REVEAL_RANGE: float = 80.0
const HALL_CONTACT_DMG: int = 15
const HALL_DISGUISED_SIZE: Vector2 = Vector2(24, 24)
const HALL_REVEALED_SIZE: Vector2 = Vector2(40, 40)
const HALL_REVEAL_TIME: float = 0.3
const HALL_SCAN_STUN: float = 2.0

const COLOR_DISGUISED: Color = Color(0.5, 1.2, 0.5)   # Greenish tint when disguised
const COLOR_REVEALED: Color = Color(1.0, 0.4, 1.2)    # Purple/magenta tint when revealed

var is_disguised: bool = true
var _reveal_timer: float = 0.0
var _was_scan_revealed: bool = false
var _chase_speed: float = HALL_CHASE_SPEED


func _ready() -> void:
	super._ready()
	health = HALL_HP
	speed = 0.0
	contact_damage = HALL_CONTACT_DMG
	_current_state = State.IDLE
	_update_visual_disguised()


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
	var sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		# Scale sprite to disguised size (base texture is 48x48)
		var tex_size: Vector2 = sprite.texture.get_size() if sprite.texture else Vector2(48, 48)
		sprite.scale = HALL_DISGUISED_SIZE / tex_size
		sprite.modulate = COLOR_DISGUISED
	var label = get_node_or_null("TypeLabel") as Label
	if label:
		label.text = "+"


func _update_visual_revealed() -> void:
	var half := HALL_REVEALED_SIZE / 2.0
	var sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		# Scale sprite to revealed size (base texture is 48x48)
		var tex_size: Vector2 = sprite.texture.get_size() if sprite.texture else Vector2(48, 48)
		sprite.scale = HALL_REVEALED_SIZE / tex_size
		sprite.modulate = COLOR_REVEALED
	var label = get_node_or_null("TypeLabel") as Label
	if label:
		label.text = "!"
		label.offset_left = -half.x
		label.offset_top = -half.y
		label.offset_right = half.x
		label.offset_bottom = half.y

	# Update collision shapes to revealed size
	var body_shape = get_node_or_null("CollisionShape2D")
	if body_shape and body_shape.shape is RectangleShape2D:
		body_shape.shape = body_shape.shape.duplicate()
		body_shape.shape.size = HALL_REVEALED_SIZE

	var hurtbox_shape = get_node_or_null("Hurtbox/CollisionShape2D")
	if hurtbox_shape and hurtbox_shape.shape is RectangleShape2D:
		hurtbox_shape.shape = hurtbox_shape.shape.duplicate()
		hurtbox_shape.shape.size = HALL_REVEALED_SIZE
