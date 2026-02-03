# Game Events Interface Contract

> **This file is the source of truth for all game events.**
> No lane modifies this without explicit coordination at a checkpoint.

## Event Naming Convention

All events use snake_case: `player_died`, `enemy_spawned`, `wave_started`

---

## Player Events

| Event | Emitted By | Payload | Listeners |
|-------|-----------|---------|-----------|
| `player_joined` | Lane A (Networking) | `{ player_id: int, spawn_position: Vector2 }` | Lane B (Combat) |
| `player_left` | Lane A (Networking) | `{ player_id: int }` | Lane B (Combat) |
| `player_input` | Lane A (Networking) | `{ player_id: int, input: InputPayload }` | Lane B (Combat) |
| `player_died` | Lane B (Combat) | `{ player_id: int, position: Vector2 }` | Lane A (Networking), Lane C (Art/UI) |
| `player_respawned` | Lane B (Combat) | `{ player_id: int, position: Vector2 }` | Lane A (Networking), Lane C (Art/UI) |

## Enemy Events

| Event | Emitted By | Payload | Listeners |
|-------|-----------|---------|-----------|
| `enemy_spawned` | Lane B (Combat) | `{ enemy_id: int, enemy_type: String, position: Vector2 }` | Lane A (Networking) |
| `enemy_died` | Lane B (Combat) | `{ enemy_id: int, killed_by: int, clean_kill: bool }` | Lane A (Networking), Lane C (Art/UI) |
| `enemy_split` | Lane B (Combat) | `{ parent_id: int, child_ids: Array[int], positions: Array[Vector2] }` | Lane A (Networking), Lane C (Art/UI) |

## Ability Events

| Event | Emitted By | Payload | Listeners |
|-------|-----------|---------|-----------|
| `ability_activated` | Lane B (Combat) | `{ player_id: int, ability: String, position: Vector2, direction: Vector2 }` | Lane A (Networking), Lane C (Art/UI) |
| `ability_ready` | Lane B (Combat) | `{ player_id: int, ability: String }` | Lane C (Art/UI) |
| `clear_context_combo` | Lane B (Combat) | `{ player_ids: Array[int], center: Vector2, radius: float }` | Lane A (Networking), Lane C (Art/UI) |

## Wave Events

| Event | Emitted By | Payload | Listeners |
|-------|-----------|---------|-----------|
| `wave_started` | Lane B (Combat) | `{ wave_number: int, enemy_count: int }` | Lane A (Networking), Lane C (Art/UI) |
| `wave_cleared` | Lane B (Combat) | `{ wave_number: int }` | Lane A (Networking), Lane C (Art/UI) |
| `game_won` | Lane B (Combat) | `{ total_waves: int, time_elapsed: float }` | Lane A (Networking), Lane C (Art/UI) |
| `game_lost` | Lane B (Combat) | `{ wave_reached: int, time_elapsed: float }` | Lane A (Networking), Lane C (Art/UI) |

## Network Events

| Event | Emitted By | Payload | Listeners |
|-------|-----------|---------|-----------|
| `connection_established` | Lane A (Networking) | `{ peer_id: int, is_host: bool }` | Lane B (Combat), Lane C (Art/UI) |
| `connection_lost` | Lane A (Networking) | `{ peer_id: int, reason: String }` | Lane B (Combat), Lane C (Art/UI) |
| `game_state_sync` | Lane A (Networking) | `{ state: GameState }` | Lane B (Combat) |

---

## Payload Type Definitions

```gdscript
# InputPayload
{
    move_direction: Vector2,  # -1 to 1 for each axis
    shoot_pressed: bool,
    ability_pressed: bool,    # Git Revert
    super_pressed: bool       # Clear Context
}

# GameState
{
    players: Dictionary,      # player_id -> PlayerState
    enemies: Dictionary,      # enemy_id -> EnemyState
    wave_number: int,
    time_elapsed: float
}

# PlayerState
{
    position: Vector2,
    health: int,
    ability_cooldown: float,
    super_cooldown: float,
    is_alive: bool
}

# EnemyState
{
    position: Vector2,
    health: int,
    enemy_type: String,
    size_tier: int           # 0 = full, 1 = split once, 2 = smallest
}
```

---

## Modification Process

1. Propose change in your `LANE_STATUS.md`
2. At checkpoint, all lanes review proposals
3. If approved, update this file FIRST
4. Then all lanes adapt to new contract
5. Merge to main only after all lanes pass integration tests
