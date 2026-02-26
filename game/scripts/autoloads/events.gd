## Signal bus autoload -- single source of truth for all game events.
## Add this as an autoload named "Events" in Project Settings.
## See docs/interfaces/game_events.md for the full contract.
extends Node

# ── Player Events ──────────────────────────────────────────────────────────────
signal player_joined(player_id: int, spawn_position: Vector3)
signal player_left(player_id: int)
signal player_input(player_id: int, input: Dictionary)
signal player_died(player_id: int, position: Vector3)
signal player_respawned(player_id: int, position: Vector3)

# ── Enemy Events ───────────────────────────────────────────────────────────────
signal enemy_spawned(enemy_id: int, enemy_type: String, position: Vector3)
signal enemy_died(enemy_id: int, killed_by: int, clean_kill: bool)
signal enemy_split(parent_id: int, child_ids: Array, positions: Array)

# ── Ability Events ─────────────────────────────────────────────────────────────
signal ability_activated(player_id: int, ability: String, position: Vector3, direction: Vector3)
signal ability_ready(player_id: int, ability: String)
signal clear_context_combo(player_ids: Array, center: Vector3, radius: float)

# ── Wave Events ────────────────────────────────────────────────────────────────
signal wave_started(wave_number: int, enemy_count: int)
signal wave_cleared(wave_number: int)
signal game_won(total_waves: int, time_elapsed: float)
signal game_lost(wave_reached: int, time_elapsed: float)

# ── Powerup Events ─────────────────────────────────────────────────────────────
signal powerup_spawned(powerup_id: int, powerup_type: String, position: Vector3)
signal powerup_collected(powerup_id: int, player_id: int, powerup_type: String)
signal powerup_expired(player_id: int, powerup_type: String)

# ── Score Events ───────────────────────────────────────────────────────────────
signal score_updated(player_id: int, kills: int, clean_kills: int)

# ── Network Events ─────────────────────────────────────────────────────────────
signal connection_established(peer_id: int, is_host: bool)
signal connection_lost(peer_id: int, reason: String)
signal game_state_sync(state: Dictionary)
signal migration_player_registered(peer_id: int)

# ── Role Events ────────────────────────────────────────────────────────────────
signal role_selected(player_id: int, role: String)
signal role_assigned(player_id: int, role: String)

# ── Revive Events ──────────────────────────────────────────────────────────────
signal revive_started(rescuer_id: int, target_id: int)
signal revive_progress(rescuer_id: int, target_id: int, progress: float)
signal revive_completed(rescuer_id: int, target_id: int)
signal revive_cancelled(rescuer_id: int, target_id: int)
signal player_downed(player_id: int, position: Vector3)
signal player_bleedout(player_id: int)

# ── Status Effect Events ──────────────────────────────────────────────────────
signal status_applied(entity_id: int, effect_name: String, duration: float)
signal status_removed(entity_id: int, effect_name: String)

# ── Super Events ──────────────────────────────────────────────────────────────
signal super_charged(player_id: int, charge: float)
signal super_activated(player_id: int, super_name: String)

# ── Turret Events ─────────────────────────────────────────────────────────────
signal turret_deployed(owner_id: int, turret_id: int, position: Vector3)
signal turret_destroyed(turret_id: int)

# ── Boss Events ──────────────────────────────────────────────────────────────
signal boss_spawned(boss_id: int, boss_type: String, position: Vector3)
signal boss_phase_changed(boss_id: int, new_phase: int)
signal boss_died(boss_id: int, killed_by: int)

# ── Enemy-Specific Events ─────────────────────────────────────────────────────
signal hallucination_revealed(enemy_id: int, position: Vector3)
signal dependency_aura_entered(player_id: int, enemy_id: int)
signal dependency_aura_exited(player_id: int, enemy_id: int)

# ── Kill Feed Events ─────────────────────────────────────────────────────
signal kill_feed_entry(killer_name: String, enemy_type: String)
