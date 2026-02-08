## Projectile script — basic bullet that travels in a direction and damages enemies.
## Collision detection runs on the server (host) only.
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var damage: int = 1
var owner_id: int = 0   # Player who fired this projectile

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

	# Don't hit the player who fired this projectile.
	if body is CharacterBody2D and body.has_method("take_damage"):
		if body.is_in_group("enemies"):
			body.take_damage(damage, owner_id)
			queue_free()
		elif body.is_in_group("players"):
			# No friendly fire — ignore player collisions.
			pass
