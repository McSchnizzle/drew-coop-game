## Enemy projectile — fired by enemies, damages players, can apply status effects.
## Similar to player projectile but has is_enemy_projectile flag and status_effect string.
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 200.0
var damage: int = 8
var owner_id: int = 0
var is_enemy_projectile: bool = true
var status_effect: String = ""

const LIFETIME: float = 3.0
var _elapsed: float = 0.0

const STATUS_DURATIONS: Dictionary = {
	"context_rot": 5.0,
	"slow": 3.0,
}


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta

	if multiplayer.is_server():
		_elapsed += delta
		if _elapsed >= LIFETIME:
			queue_free()


func _on_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return

	if body.is_in_group("players") and body.has_method("take_damage"):
		body.take_damage(damage)
		# Apply status effect if this projectile carries one
		if status_effect != "" and body.has_method("apply_status"):
			var duration: float = STATUS_DURATIONS.get(status_effect, 3.0)
			body.apply_status(status_effect, duration)
		queue_free()
	elif body.is_in_group("enemies"):
		# Don't hit enemies
		pass
