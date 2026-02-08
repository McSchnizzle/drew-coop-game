# Security Review -- Phase 1 Golden Path

**Reviewed:** 2026-02-08
**Scope:** All `.gd` scripts and `.tscn` scene files under `game/`
**Architecture:** Godot 4 authoritative server (host) with ENet peer-to-peer

---

## Executive Summary

The codebase follows a solid authoritative-server architecture. All physics, damage, spawning, and game logic runs exclusively on the server/host. Clients only write input variables and render replicated state. No RPCs (`@rpc`) are used at all -- the game relies entirely on `MultiplayerSynchronizer` for replication, which significantly reduces the RPC attack surface.

**One critical issue was found and fixed:** client input values were not clamped on the server, allowing a speed-hack exploit. All other findings are medium or low severity and acceptable for Phase 1.

| Severity | Count | Fixed |
|----------|-------|-------|
| Critical | 1     | 1     |
| Medium   | 3     | 0     |
| Low      | 3     | 1     |

---

## Findings

### CRITICAL-01: Unclamped `input_move_dir` allows speed hack [FIXED]

**File:** `scripts/player.gd:118`
**Category:** Input Validation
**Status:** Fixed in this review

**Vulnerability:** The `input_move_dir` variable is synced from the owning client to the server via `InputSync`. The server used this value directly in `velocity.x = input_move_dir * current_speed`. A malicious client could set `input_move_dir = 100.0` to move at 100x normal speed.

**Exploit:** Modify the client to write arbitrary float values to `input_move_dir` instead of using `Input.get_axis()` which naturally returns `[-1.0, 1.0]`.

**Fix applied:**
```gdscript
# Added at the start of _server_process():
input_move_dir = clampf(input_move_dir, -1.0, 1.0)
```

---

### MEDIUM-01: No rate limiting on projectile creation

**File:** `scripts/player.gd:168-191`
**Category:** Resource Exhaustion

**Vulnerability:** Projectile spawning is gated by `_shoot_cooldown_timer` on the server, which prevents excessive firing under normal conditions. However, the auto-fire rate (`SHOOT_COOLDOWN_AUTO = 0.12s`) produces ~8 projectiles/second. Each projectile is a replicated scene node via `MultiplayerSpawner`. In a 4-player game with all players holding shoot, this creates 32 networked nodes/second.

**Exploit:** Not directly exploitable beyond holding the shoot button. The server controls fire rate. However, with many players, this could cause network saturation.

**Recommended fix (Phase 2):** Add a maximum active projectile count per player. When the limit is hit, either deny new shots or remove the oldest projectile.

**Phase 1 acceptable:** Yes. With 2 players (golden path), the rate is manageable.

---

### MEDIUM-02: `take_damage()` on Player has no server-authority guard

**File:** `scripts/player.gd:215-221`
**Category:** Authority Checks

**Vulnerability:** The `take_damage()` function on Player does not verify `multiplayer.is_server()` before modifying `health`. While no code path currently calls this from clients (projectile collision checks `is_server()`, and no `@rpc` calls exist), this is a missing defense-in-depth check. If future code accidentally calls `take_damage()` from a client context, the `health` variable (replicated via ServerSync) could potentially be overwritten locally and then pushed back to the server depending on sync direction.

**Exploit:** Not exploitable in the current codebase, but a latent risk for future development.

**Recommended fix (Phase 2):**
```gdscript
func take_damage(amount: int) -> void:
    if not multiplayer.is_server():
        return
    if not _is_alive:
        return
    health -= amount
    if health <= 0:
        health = 0
        die()
```

**Phase 1 acceptable:** Yes. No current exploit path exists. ServerSync replicates server-to-all, so a client writing `health` locally would be overwritten on the next sync tick.

---

### MEDIUM-03: Scene change not authority-gated via RPC

**File:** `scripts/lobby.gd:74-79`
**Category:** Authority Checks

**Vulnerability:** The `_on_start_pressed()` method calls `get_tree().change_scene_to_file()` which only changes the scene locally on the host. Clients don't receive this scene change through any networked mechanism. In the current flow, this works because the Godot engine propagates scene changes through the `MultiplayerSpawner` mechanism, but this is implicit rather than explicit.

**Exploit:** Not directly exploitable. A client calling this locally would only affect their own game instance.

**Recommended fix (Phase 2):** Use an `@rpc("authority", "call_local", "reliable")` to trigger scene changes across all peers simultaneously for a more robust game start flow.

**Phase 1 acceptable:** Yes. The implicit Godot scene synchronization handles this for 2-player testing.

---

### LOW-01: Stamina not replicated to clients [FIXED]

**File:** `scenes/player.tscn` (ServerSync config)
**Category:** Information Leakage (inverse -- missing info)
**Status:** Fixed in this review

**Vulnerability:** The `stamina` variable was not included in the `ServerSync` `SceneReplicationConfig`. This meant clients could not display other players' stamina bars, and the HUD `StaminaBar` would only show accurate values for the local player on the host.

**Fix applied:** Added `stamina` as `properties/3` in the ServerSync replication config in `player.tscn`.

---

### LOW-02: Projectile `owner_id` not validated

**File:** `scripts/projectile.gd:8`, `scripts/player.gd:200`
**Category:** Entity ID Manipulation

**Vulnerability:** When a projectile is created in `_fire_projectile()`, it sets `owner_id = player_id`. This value is used to credit kills via `take_damage(damage, owner_id)`. Since projectiles are spawned only on the server, a client cannot create projectiles with fake `owner_id` values. However, the `owner_id` field is not validated against the actual peer who triggered the shot.

**Exploit:** Not exploitable in Phase 1. The server creates projectiles using `player_id` from the player node, which is set by `game_manager.gd` during spawn. A client cannot modify their own `player_id` because it's set server-side.

**Phase 1 acceptable:** Yes. The attack chain is blocked by server-authoritative spawning.

---

### LOW-03: Enemy `enemy_id` is a simple incrementing counter

**File:** `scripts/game_manager.gd:22`
**Category:** Entity ID Manipulation

**Vulnerability:** Enemy IDs are simple incrementing integers starting at 1000. This is predictable. However, since `take_damage()` on enemies is only called from server-side projectile collision (`projectile.gd:38`), and enemy lookup is done via scene-tree node groups (not by ID), the predictable IDs do not create an exploitable attack vector.

**Exploit:** None in current architecture. If an RPC allowing clients to specify target enemy IDs were added in the future, this would become relevant.

**Phase 1 acceptable:** Yes.

---

## Architecture Security Assessment

### What is done well

1. **No RPCs at all.** The entire networking model uses `MultiplayerSynchronizer` for state replication and `MultiplayerSpawner` for entity spawning. This eliminates the most common Godot multiplayer vulnerability class (improperly secured `@rpc` calls).

2. **Server-authoritative physics.** All game logic in `player.gd` runs inside `if multiplayer.is_server()` blocks. Clients only gather input and write to synced variables.

3. **Server-authoritative spawning.** All `add_child()` calls for players, enemies, and projectiles happen only when `multiplayer.is_server()` is true (in `game_manager.gd` and `player.gd:_fire_projectile()`). `MultiplayerSpawner` replicates these to clients.

4. **Server-authoritative enemy logic.** Enemy movement (`enemy.gd:21`) and damage processing (`enemy.gd:61`) both check `multiplayer.is_server()`.

5. **Input/State separation.** The dual-synchronizer pattern (InputSync for client-to-server input, ServerSync for server-to-all state) properly separates trust boundaries.

### What clients can control

| Variable | Sync Direction | Clamped/Validated |
|----------|---------------|-------------------|
| `input_move_dir` | Client -> Server | Yes (after fix) |
| `input_shoot` | Client -> Server | Boolean -- safe |
| `input_jump` | Client -> Server | Boolean -- safe |
| `input_sprint` | Client -> Server | Boolean -- safe |
| `input_melee` | Client -> Server | Boolean -- safe |
| `input_ability` | Client -> Server | Boolean -- safe |
| `input_super` | Client -> Server | Boolean -- safe |

### What the server controls

| Variable | Sync Direction | Notes |
|----------|---------------|-------|
| `position` | Server -> All | Physics-authoritative |
| `velocity` | Server -> All | Physics-authoritative |
| `health` | Server -> All | Damage-authoritative |
| `stamina` | Server -> All | Sprint-authoritative |
| Enemy `position` | Server -> All | AI-authoritative |
| Enemy `health` | Server -> All | Damage-authoritative |

### MultiplayerSpawner Configuration

| Spawner | Allowed Scenes | Spawn Path | Risk |
|---------|---------------|------------|------|
| PlayerSpawner | `player.tscn` | `Players` | Low -- only host calls `add_child` |
| EnemySpawner | `enemy.tscn` | `Enemies` | Low -- only host calls `add_child` |
| ProjectileSpawner | `projectile.tscn` | `Projectiles` | Low -- only host creates projectiles |

By default, `MultiplayerSpawner` only replicates spawns initiated by the authority (server). Clients cannot inject entities through the spawner.

---

## Recommendations for Phase 2

1. **Add server-authority guards to all `take_damage()` functions** as defense-in-depth.
2. **Add per-player projectile limits** to prevent network saturation in 4-player games.
3. **Add server-authoritative scene change RPC** for robust game-start synchronization.
4. **Consider adding input sequence numbers** to detect and reject stale/replayed inputs.
5. **Add server-side position bounds checking** to teleport players back if they escape the level.
6. **Add connection authentication** if the game moves beyond LAN play.

---

## Conclusion

The Phase 1 codebase has a strong security foundation. The authoritative-server model with no RPCs is the correct architecture for a multiplayer game. The one critical issue (unclamped movement input) has been fixed. All remaining findings are defense-in-depth improvements appropriate for Phase 2.
