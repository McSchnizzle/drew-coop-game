## Merge Conflict enemy — chases players, splits into smaller copies on death.
## 3 size tiers: T0 (2.4), T1 (1.6), T2 (1.0) in 3D units.
## On death, if not exposed and tier < 2, spawns 2 children at tier+1.
extends "res://scripts/enemies/enemy_base.gd"

var SELF_SCENE: PackedScene  # Loaded on first split to avoid circular preload

# Per-tier stats (speeds converted: 50/20=2.5, 65/20=3.25, 80/20=4.0)
const TIER_HP: Array[int] = [3, 2, 1]
const TIER_SPEED: Array[float] = [2.5, 3.25, 4.0]
const TIER_SCALE: Array[float] = [1.0, 0.67, 0.42]
const TIER_CONTACT_DMG: Array[int] = [10, 8, 5]
const TIER_COLORS: Array[Color] = [
	Color(0.9, 0.15, 0.15),  # Red (T0)
	Color(0.9, 0.4, 0.4),    # Light Red (T1)
	Color(0.9, 0.6, 0.6),    # Pink (T2)
]

var size_tier: int = 0


func _ready() -> void:
	super._ready()
	_load_glb_model("res://assets/models/ybot/ybot.fbx")
	_load_external_animations({
		"Idle": "res://assets/models/ybot/idle.fbx",
		"Walk": "res://assets/models/ybot/walk.fbx",
		"Run": "res://assets/models/ybot/run.fbx",
		"Death": "res://assets/models/ybot/death.fbx",
		"HitReaction": "res://assets/models/ybot/hit_reaction.fbx",
		"Attack": "res://assets/models/ybot/attack.fbx",
	})
	_tint_model(Color(0.9, 0.3, 0.3))  # Red tint
	_apply_tier_stats()


func _transition_to(new_state: State) -> void:
	_current_state = new_state
	match new_state:
		State.IDLE:
			_play_anim("Idle")
		State.CHASE:
			_play_anim("Run")
		State.ATTACK:
			_play_anim("Attack")
		State.FLEE:
			_play_anim("Run")
		State.STUNNED:
			_play_anim("Idle")
		State.DEAD:
			_play_anim("Death")


func _apply_tier_stats() -> void:
	health = TIER_HP[size_tier]
	speed = TIER_SPEED[size_tier]
	contact_damage = TIER_CONTACT_DMG[size_tier]

	# Scale the whole model node (not just the mesh) so skeleton stays in sync
	if _model_node:
		var base_scale := _model_node.scale
		var s: float = TIER_SCALE[size_tier]
		_model_node.scale = base_scale * s

	# Tint per tier
	_tint_model(TIER_COLORS[size_tier])

	# Update collision shapes
	var body_shape = get_node_or_null("CollisionShape3D")
	if body_shape and body_shape.shape is BoxShape3D:
		body_shape.shape = body_shape.shape.duplicate()
		var base_size: float = 2.4 * TIER_SCALE[size_tier]
		body_shape.shape.size = Vector3(base_size, base_size, base_size)

	var hurtbox_shape = get_node_or_null("Hurtbox/CollisionShape3D")
	if hurtbox_shape and hurtbox_shape.shape is BoxShape3D:
		hurtbox_shape.shape = hurtbox_shape.shape.duplicate()
		var base_size: float = 2.4 * TIER_SCALE[size_tier]
		hurtbox_shape.shape.size = Vector3(base_size, base_size, base_size)


func _die(killed_by: int) -> void:
	_is_alive = false
	_current_state = State.DEAD
	velocity = Vector3.ZERO
	var was_clean := has_status("exposed")
	Events.enemy_died.emit(enemy_id, killed_by, was_clean)

	if not was_clean and size_tier < 2:
		_spawn_children(killed_by)

	queue_free()


func _spawn_children(_killed_by: int) -> void:
	if not SELF_SCENE:
		SELF_SCENE = load("res://scenes/enemies/enemy_merge_conflict.tscn")
	var game_manager = get_tree().current_scene
	var child_ids: Array[int] = []
	var child_positions: Array[Vector3] = []
	for i in range(2):
		var child = SELF_SCENE.instantiate()
		child.size_tier = size_tier + 1
		child.enemy_id = game_manager.next_enemy_id()
		var angle := randf() * TAU + PI * i
		var offset := Vector3(cos(angle) * 1.5, 0, sin(angle) * 1.5)  # 30px / 20 = 1.5 units
		child.position = global_position + offset
		child.name = "Enemy_%d" % child.enemy_id
		child_ids.append(child.enemy_id)
		child_positions.append(child.position)
		game_manager.get_node("Enemies").add_child(child, true)

	Events.enemy_split.emit(enemy_id, child_ids, child_positions)
