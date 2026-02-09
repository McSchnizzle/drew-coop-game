## Merge Conflict enemy — chases players, splits into smaller copies on death.
## 3 size tiers: T0 (48x48), T1 (32x32), T2 (20x20).
## On death, if not exposed and tier < 2, spawns 2 children at tier+1.
extends "res://scripts/enemies/enemy_base.gd"

const SELF_SCENE: PackedScene = preload("res://scenes/enemies/enemy_merge_conflict.tscn")

# Per-tier stats
const TIER_HP: Array[int] = [3, 2, 1]
const TIER_SPEED: Array[float] = [50.0, 65.0, 80.0]
const TIER_SIZE: Array[Vector2] = [Vector2(48, 48), Vector2(32, 32), Vector2(20, 20)]
const TIER_CONTACT_DMG: Array[int] = [10, 8, 5]
const TIER_COLORS: Array[Color] = [
	Color(0.9, 0.15, 0.15),  # Red (T0)
	Color(0.9, 0.4, 0.4),    # Light Red (T1)
	Color(0.9, 0.6, 0.6),    # Pink (T2)
]

var size_tier: int = 0


func _ready() -> void:
	super._ready()
	_apply_tier_stats()


func _apply_tier_stats() -> void:
	health = TIER_HP[size_tier]
	speed = TIER_SPEED[size_tier]
	contact_damage = TIER_CONTACT_DMG[size_tier]

	# Update visual size
	var half := TIER_SIZE[size_tier] / 2.0
	var color_rect = get_node_or_null("ColorRect") as ColorRect
	if color_rect:
		color_rect.offset_left = -half.x
		color_rect.offset_top = -half.y
		color_rect.offset_right = half.x
		color_rect.offset_bottom = half.y
		color_rect.color = TIER_COLORS[size_tier]

	# Update collision shapes
	var body_shape = get_node_or_null("CollisionShape2D")
	if body_shape and body_shape.shape is RectangleShape2D:
		body_shape.shape = body_shape.shape.duplicate()
		body_shape.shape.size = TIER_SIZE[size_tier]

	var hurtbox_shape = get_node_or_null("Hurtbox/CollisionShape2D")
	if hurtbox_shape and hurtbox_shape.shape is RectangleShape2D:
		hurtbox_shape.shape = hurtbox_shape.shape.duplicate()
		hurtbox_shape.shape.size = TIER_SIZE[size_tier]


func _die(killed_by: int) -> void:
	_is_alive = false
	_current_state = State.DEAD
	velocity = Vector2.ZERO
	var was_clean := has_status("exposed")
	Events.enemy_died.emit(enemy_id, killed_by, was_clean)

	if not was_clean and size_tier < 2:
		_spawn_children(killed_by)

	queue_free()


func _spawn_children(_killed_by: int) -> void:
	var game_manager = get_tree().current_scene
	var child_ids: Array[int] = []
	var child_positions: Array[Vector2] = []
	for offset in [-30.0, 30.0]:
		var child = SELF_SCENE.instantiate()
		child.size_tier = size_tier + 1
		child.enemy_id = game_manager.next_enemy_id()
		child.position = global_position + Vector2(offset, 0)
		child.name = "Enemy_%d" % child.enemy_id
		child_ids.append(child.enemy_id)
		child_positions.append(child.position)
		game_manager.get_node("Enemies").add_child(child, true)

	Events.enemy_split.emit(enemy_id, child_ids, child_positions)
