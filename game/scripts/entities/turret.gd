## Turret entity -- auto-targets nearest enemy and fires projectiles.
## Spawned by Engineer's Deploy Turret ability. Server-authoritative.
extends StaticBody3D

const TURRET_HP: int = 5
const TURRET_FIRE_RATE: float = 0.8
const TURRET_DAMAGE: int = 1
const TURRET_RANGE: float = 12.5  # 250px / 20
const TURRET_LIFETIME: float = 10.0

var turret_id: int = 0
var owner_id: int = 0
var health: int = TURRET_HP

var _fire_timer: float = 0.0
var _lifetime_timer: float = TURRET_LIFETIME
var _is_alive: bool = true
var _projectile_scene: PackedScene = null


func _ready() -> void:
	add_to_group("turrets")
	_projectile_scene = load("res://scenes/projectile.tscn")


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if not _is_alive:
		return

	# Lifetime countdown
	_lifetime_timer -= delta
	if _lifetime_timer <= 0.0:
		_destroy()
		return

	# Fire at nearest enemy
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		var target := _find_nearest_enemy()
		if target:
			_fire_at(target)
			_fire_timer = TURRET_FIRE_RATE


func take_damage(amount: int, _from_id: int) -> void:
	if not _is_alive or not multiplayer.is_server():
		return
	health -= amount
	if health <= 0:
		health = 0
		_destroy()


func _destroy() -> void:
	_is_alive = false
	Events.turret_destroyed.emit(turret_id)
	queue_free()


func _fire_at(target: Node3D) -> void:
	if _projectile_scene == null:
		return

	var dir := (target.global_position - global_position)
	dir.y = 0
	dir = dir.normalized()
	var projectile = _projectile_scene.instantiate()
	projectile.direction = dir
	projectile.damage = TURRET_DAMAGE
	projectile.owner_id = owner_id
	projectile.name = "TurretProj_%d" % (randi() % 1000000)
	projectile.position = global_position + dir * 0.8  # 16px / 20 = 0.8 units

	var projectiles_node = get_tree().current_scene.get_node("Projectiles")
	if projectiles_node:
		projectiles_node.add_child(projectile, true)

	# Charge the owner's super on fire
	var players := get_tree().get_nodes_in_group("players")
	for player in players:
		if player.player_id == owner_id:
			var ability_mgr = player.get_node_or_null("AbilityManager")
			if ability_mgr:
				ability_mgr.add_super_charge(ability_mgr.SUPER_CHARGE_PER_TURRET_HIT)
			break


func _find_nearest_enemy() -> Node3D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node3D = null
	var nearest_dist: float = INF
	for enemy in enemies:
		if not enemy is Node3D:
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= TURRET_RANGE and dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest
