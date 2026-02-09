## Projectile script -- bullet that travels in a direction and damages enemies (or players).
## Collision detection runs on the server (host) only.
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var damage: int = 1
var owner_id: int = 0   # Player or enemy that fired this projectile
var is_enemy_projectile: bool = false
var status_effect: String = ""

const LIFETIME: float = 3.0  # Auto-destroy after this many seconds
var _elapsed: float = 0.0


func _ready() -> void:
	# Connect collision signal for server-side hit detection.
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	# Move the projectile every frame on all peers (visual smoothness).
	position += direction * speed * delta

	# Track lifetime and auto-destroy (server authoritative).
	if multiplayer.is_server():
		_elapsed += delta
		if _elapsed >= LIFETIME:
			queue_free()


func _on_body_entered(body: Node) -> void:
	# Only the server processes collision logic.
	if not multiplayer.is_server():
		return

	if body is CharacterBody2D and body.has_method("take_damage"):
		if is_enemy_projectile:
			# Enemy projectile: damage players only
			if body.is_in_group("players"):
				body.take_damage(damage)
				# Apply status effect if set
				if status_effect != "" and body.has_method("apply_status"):
					var duration := 5.0
					if status_effect == "context_rot":
						duration = 5.0
					body.apply_status(status_effect, duration)
				queue_free()
		else:
			# Player projectile: damage enemies only
			if body.is_in_group("enemies"):
				body.take_damage(damage, owner_id)
				# Charge super for projectile hits
				_charge_owner_super()
				queue_free()
			elif body.is_in_group("players"):
				# No friendly fire -- ignore player collisions.
				pass


func _charge_owner_super() -> void:
	var players := get_tree().get_nodes_in_group("players")
	for player in players:
		if player.player_id == owner_id:
			var ability_mgr = player.get_node_or_null("AbilityManager")
			if ability_mgr:
				ability_mgr.add_super_charge(ability_mgr.SUPER_CHARGE_PER_PROJECTILE_HIT)
			break
