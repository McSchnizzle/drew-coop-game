# Entity Schema Interface Contract

> **This file is the source of truth for all networked entity structures.**
> No lane modifies this without explicit coordination at a checkpoint.

---

## Player Entity

| Field | Type | Sync | Owner | Description |
|-------|------|------|-------|-------------|
| `player_id` | int | Init | Networking | Unique identifier, matches peer_id |
| `position` | Vector2 | Continuous | Networking | World position |
| `velocity` | Vector2 | Continuous | Networking | Current movement vector |
| `facing` | int | Continuous | Networking | -1 (left) or 1 (right) |
| `health` | int | OnChange | Combat | Current health (max TBD by Drew) |
| `is_alive` | bool | OnChange | Combat | False when health <= 0 |
| `ability_cooldown` | float | OnChange | Combat | Seconds until Git Revert ready |
| `super_cooldown` | float | OnChange | Combat | Seconds until Clear Context ready |
| `animation_state` | String | OnChange | Combat | Current animation: "idle", "run", "jump", "shoot", "ability", "dead" |

**Sync Legend:**
- `Init` = sent once when entity created
- `Continuous` = sent every network tick
- `OnChange` = sent only when value changes

---

## Enemy Entity (Merge Conflict)

| Field | Type | Sync | Owner | Description |
|-------|------|------|-------|-------------|
| `enemy_id` | int | Init | Combat | Unique identifier |
| `enemy_type` | String | Init | Combat | "merge_conflict" for Phase 1 |
| `position` | Vector2 | Continuous | Combat | World position |
| `velocity` | Vector2 | Continuous | Combat | Current movement vector |
| `health` | int | OnChange | Combat | Current health |
| `size_tier` | int | Init | Combat | 0 = full size, 1 = first split, 2 = smallest |
| `target_player_id` | int | OnChange | Combat | Which player this enemy is targeting |
| `animation_state` | String | OnChange | Combat | "walk", "attack", "split", "die", "die_clean" |

**Size Tier Behavior:**
- Tier 0: Full size, splits into 2x Tier 1 on normal kill
- Tier 1: Medium, splits into 2x Tier 2 on normal kill
- Tier 2: Smallest, dies without splitting (even on normal kill)

---

## Projectile Entity

| Field | Type | Sync | Owner | Description |
|-------|------|------|-------|-------------|
| `projectile_id` | int | Init | Combat | Unique identifier |
| `owner_id` | int | Init | Combat | Player who fired it |
| `position` | Vector2 | Continuous | Combat | World position |
| `velocity` | Vector2 | Init | Combat | Direction and speed (constant) |
| `projectile_type` | String | Init | Combat | "normal_shot" or "git_revert_beam" |
| `damage` | int | Init | Combat | Damage dealt on hit |
| `is_clean_kill` | bool | Init | Combat | True for Git Revert (prevents split) |

---

## Ability Effect Entity

| Field | Type | Sync | Owner | Description |
|-------|------|------|-------|-------------|
| `effect_id` | int | Init | Combat | Unique identifier |
| `effect_type` | String | Init | Combat | "clear_context_solo", "clear_context_combo" |
| `position` | Vector2 | Init | Combat | Center of effect |
| `radius` | float | Init | Combat | Area of effect |
| `owner_ids` | Array[int] | Init | Combat | Players who triggered it |
| `damage` | int | Init | Combat | Damage dealt (combo > solo) |

---

## ID Generation Rules

- **player_id**: Assigned by host, matches Godot multiplayer peer_id
- **enemy_id**: Host generates, starts at 1000, increments
- **projectile_id**: Host generates, starts at 10000, increments
- **effect_id**: Host generates, starts at 100000, increments

This ensures no ID collisions across entity types.

---

## Modification Process

1. Propose change in your `LANE_STATUS.md`
2. At checkpoint, all lanes review proposals
3. If approved, update this file FIRST
4. Then all lanes adapt to new contract
5. Merge to main only after all lanes pass integration tests
