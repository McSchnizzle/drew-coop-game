## AbilityManager -- child Node of Player, manages ability + super activation.
## Reads input_ability and input_super from parent player and delegates
## to Ability and Super child nodes. Runs on server only.
extends Node

var role: String = "striker"

const SUPER_CHARGE_MAX: float = 100.0
const SUPER_CHARGE_PER_PROJECTILE_HIT: float = 10.0
const SUPER_CHARGE_PER_MELEE_HIT: float = 15.0
const SUPER_CHARGE_PER_TURRET_HIT: float = 5.0

# Passive bonuses
const STRIKER_DAMAGE_BONUS: float = 0.15
const ENGINEER_STAMINA_REGEN_BONUS: float = 0.2


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	var player = get_parent()
	if not player._is_alive:
		return
	if player.get("_is_downed") and player._is_downed:
		return

	# Tick ability cooldown on the player (synced to clients via ServerSync)
	player.ability_cooldown = maxf(player.ability_cooldown - delta, 0.0)

	# Block abilities and super while reviving
	if player._is_reviving_someone:
		return

	# Ability activation
	if player.input_ability and player.ability_cooldown <= 0.0:
		if not player.has_status("ability_disabled"):
			var ability_node = get_node_or_null("Ability")
			if ability_node:
				ability_node.activate(player.global_position, player._facing)
				player.ability_cooldown = ability_node.COOLDOWN

	# Super activation
	if player.input_super:
		if player.super_charge >= SUPER_CHARGE_MAX:
			var super_node = get_node_or_null("Super")
			if super_node:
				print("AbilityManager: Super activated for player %d!" % player.player_id)
				super_node.activate(player)
				player.super_charge = 0.0
			else:
				print("AbilityManager: No Super node found for player %d" % player.player_id)
		else:
			print("AbilityManager: Super not ready — charge %.0f/%.0f" % [player.super_charge, SUPER_CHARGE_MAX])

	# Consume one-shot inputs after reading them (parent already ran _server_process)
	player.input_ability = false
	player.input_super = false


func add_super_charge(amount: float) -> void:
	var player = get_parent()
	player.super_charge = minf(player.super_charge + amount, SUPER_CHARGE_MAX)
	Events.super_charged.emit(player.player_id, player.super_charge)


func get_damage_multiplier() -> float:
	var player = get_parent()
	var mult := 1.0
	if role == "striker":
		mult += STRIKER_DAMAGE_BONUS
	# Check for overdrive buff
	if player.has_status("overdrive"):
		mult *= 2.0
	return mult


func get_stamina_regen_multiplier() -> float:
	if role == "engineer":
		return 1.0 + ENGINEER_STAMINA_REGEN_BONUS
	return 1.0
