## Projectile script -- bullet that travels in a direction and damages enemies (or players).
## Collision detection runs on the server (host) only.
extends Area3D

var direction: Vector3 = Vector3.FORWARD
var speed: float = 20.0
var damage: int = 1
var owner_id: int = 0
var is_enemy_projectile: bool = false
var status_effect: String = ""

const LIFETIME: float = 3.0
var _elapsed: float = 0.0


func _ready() -> void:
	# Detect enemies on layer 3 (bit 4).
	collision_mask = 4
	body_entered.connect(_on_body_entered)
	# Orient bolt to face travel direction
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta

	if multiplayer.is_server():
		_elapsed += delta
		if _elapsed >= LIFETIME:
			queue_free()


func _on_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return

	if body is CharacterBody3D and body.has_method("take_damage"):
		if is_enemy_projectile:
			if body.is_in_group("players"):
				body.take_damage(damage)
				if status_effect != "" and body.has_method("apply_status"):
					var duration := 5.0
					if status_effect == "context_rot":
						duration = 5.0
					body.apply_status(status_effect, duration)
				queue_free()
		else:
			if body.is_in_group("enemies"):
				body.take_damage(damage, owner_id)
				_charge_owner_super()
				queue_free()
			elif body.is_in_group("players"):
				pass


func _charge_owner_super() -> void:
	var players := get_tree().get_nodes_in_group("players")
	for player in players:
		if player.player_id == owner_id:
			var ability_mgr = player.get_node_or_null("AbilityManager")
			if ability_mgr:
				ability_mgr.add_super_charge(ability_mgr.SUPER_CHARGE_PER_PROJECTILE_HIT)
			break
