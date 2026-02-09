## Shared utility for ticking status effect dictionaries.
## Used by both player.gd and enemy_base.gd for consistent status effect handling.
## Status effects are stored as { "effect_name": remaining_duration_float }.
extends RefCounted


## Tick all effects by delta. Returns an array of expired effect names.
static func tick(effects: Dictionary, delta: float) -> Array[String]:
	var expired: Array[String] = []
	for effect_name in effects:
		effects[effect_name] -= delta
		if effects[effect_name] <= 0.0:
			expired.append(effect_name)
	for effect_name in expired:
		effects.erase(effect_name)
	return expired


## Apply or refresh a status effect. Returns true if this is a new effect.
static func apply(effects: Dictionary, effect_name: String, duration: float) -> bool:
	var is_new := not effects.has(effect_name)
	effects[effect_name] = duration
	return is_new


## Check if an effect is active.
static func has_effect(effects: Dictionary, effect_name: String) -> bool:
	return effects.has(effect_name) and effects[effect_name] > 0.0


## Remove a specific effect. Returns true if it was present.
static func remove(effects: Dictionary, effect_name: String) -> bool:
	if effects.has(effect_name):
		effects.erase(effect_name)
		return true
	return false


## Get all active effect names as a PackedStringArray (for sync).
static func get_active_names(effects: Dictionary) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for effect_name in effects:
		if effects[effect_name] > 0.0:
			names.append(effect_name)
	return names


## Clear all effects. Returns array of cleared effect names.
static func clear_all(effects: Dictionary) -> Array[String]:
	var cleared: Array[String] = []
	for effect_name in effects:
		cleared.append(effect_name)
	effects.clear()
	return cleared
