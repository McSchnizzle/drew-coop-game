# Phase 2 Architecture: Combat Systems, Enemies, and Roles

> **Last updated:** 2026-02-08
> **Builds on:** Phase 1 golden path (see `docs/ARCHITECTURE.md`)
> **Engine:** Godot 4.6 | **Language:** GDScript | **Networking:** ENet (host-authoritative)

**Design constraint:** All systems are pure game logic and data. No investment in 2D-specific visuals beyond colored rectangles. Everything here carries over to 3D.

---

## Table of Contents

1. [Wave System](#1-wave-system)
2. [Role and Ability System](#2-role-and-ability-system)
3. [Super / Ultimate System](#3-super--ultimate-system)
4. [Enemy Types](#4-enemy-types)
5. [Enemy AI State Machine](#5-enemy-ai-state-machine)
6. [Revive System](#6-revive-system)
7. [Status Effects](#7-status-effects)
8. [New Signals (Events Autoload)](#8-new-signals-events-autoload)
9. [File Structure](#9-file-structure)
10. [Multiplayer Integration Summary](#10-multiplayer-integration-summary)
11. [Entity Schema Additions](#11-entity-schema-additions)
12. [Implementation Order](#12-implementation-order)

---

## 1. Wave System

### Overview

Waves are the core gameplay loop. The server spawns groups of enemies, players clear them, a brief rest period follows, then the next wave begins. Difficulty escalates through enemy count, enemy type mix, and stat scaling.

### Wave Progression

| Wave | Enemy Count Formula | Enemy Types Available | Rest Period |
|------|--------------------|-----------------------|-------------|
| 1 | 3 | Merge Conflict only | 5s |
| 2 | 5 | Merge Conflict only | 5s |
| 3 | 7 | Merge Conflict + Hallucination | 5s |
| 4 | 10 | Merge Conflict + Hallucination + Context Rot | 4s |
| 5 | 13 | All types including Dependency Hell | 4s |
| 6+ | `5 + (wave * 2)` | All types, weighted random | 3s |

**Enemy count formula (wave 6+):** `base_count = 5 + (wave_number * 2)`, capped at 30.

### Difficulty Scaling

Each wave after wave 3 applies a scaling multiplier to enemy stats:

```gdscript
# In wave_manager.gd — server only
var health_scale: float = 1.0 + (wave_number - 1) * 0.15   # +15% HP per wave
var speed_scale: float  = 1.0 + (wave_number - 1) * 0.05   # +5% speed per wave
var damage_scale: float = 1.0 + (wave_number - 1) * 0.10   # +10% damage per wave
```

Scaling is clamped: health max 3.0x, speed max 1.5x, damage max 2.5x.

### Wave Type Weights (wave 5+)

| Enemy Type | Weight | Notes |
|------------|--------|-------|
| Merge Conflict | 40% | Bread-and-butter fodder |
| Hallucination | 20% | Deception and confusion |
| Context Rot | 25% | Pressure through status effects |
| Dependency Hell | 15% | Rare, high-threat |

### Wave State Machine (Server Only)

```
  [IDLE] ---(game_start)---> [SPAWNING] ---(all spawned)---> [ACTIVE]
                                                                 |
                                                    (all enemies dead)
                                                                 |
                                                            [REST_PERIOD]
                                                                 |
                                                        (timer expires)
                                                                 |
                                          +---- (max_wave reached) ----> [GAME_WON]
                                          |
                                     [SPAWNING] (next wave)

  At any point: (all players dead) ---> [GAME_OVER]
```

### Wave Complete Detection

The server tracks enemies via group membership. Every frame during `ACTIVE` state:

```gdscript
func _check_wave_status() -> void:
    var alive_enemies := get_tree().get_nodes_in_group("enemies")
    if alive_enemies.size() == 0 and _wave_state == WaveState.ACTIVE:
        _wave_state = WaveState.REST_PERIOD
        Events.wave_cleared.emit(_current_wave)
        _rest_timer = REST_DURATIONS[mini(_current_wave, REST_DURATIONS.size() - 1)]
```

### Spawn Pattern

Enemies spawn at randomized positions along the right edge of the level, staggered over 1-2 seconds (not all at once) to avoid clumping. The spawn positions are offset vertically to avoid stacking:

```gdscript
const SPAWN_X_MIN: float = 800.0
const SPAWN_X_MAX: float = 1100.0
const SPAWN_Y: float = 500.0  # On the floor
const SPAWN_STAGGER: float = 0.15  # Seconds between each enemy spawn
```

### Multiplayer: Wave System

| Aspect | Runs On | Synced How |
|--------|---------|-----------|
| Wave state machine | Server only | RPC to notify clients of wave_started/wave_cleared |
| Enemy spawning | Server only | MultiplayerSpawner replicates automatically |
| Wave count / timer | Server only | Synced via WaveSync MultiplayerSynchronizer on GameManager |
| Wave HUD label | All clients | Each client reads synced `current_wave` and `wave_state` |

---

## 2. Role and Ability System

### Overview

Each player selects a role in the lobby before the game starts. There are two roles: **Striker** and **Engineer**. Each role has one **ability** (regular cooldown, tactical use) and one **super** (charges over time by dealing damage, powerful effect).

### Role Selection

Role selection happens in the lobby. Each player clicks a role button. The host stores role assignments in a dictionary `{peer_id: role_name}`. When the game scene loads, `game_manager.gd` reads the role assignments and attaches the correct ability components to each player.

If no role is selected, default is Striker.

### Role: Striker

**Theme:** Offensive specialist. Deals damage, reveals weaknesses.

| Property | Value |
|----------|-------|
| Color | Orange rectangle `(1.0, 0.6, 0.1)` |
| Passive | +15% projectile damage (damage = 1 becomes 1; applied as rounding-aware multiplier at higher base damages) |

**Ability: Weak Point Scan**

| Property | Value |
|----------|-------|
| Cooldown | 12 seconds |
| Duration | 6 seconds |
| Effect | Marks all enemies in a 300px radius as "exposed" -- exposed enemies take 2x damage from all sources |
| Range | 300px radius centered on player |
| Multiplayer | Server applies "exposed" status to enemies; clients see color change (enemies flash white) |

```gdscript
# In ability_weak_point_scan.gd — runs on server
func activate(player_pos: Vector2) -> void:
    var enemies := get_tree().get_nodes_in_group("enemies")
    for enemy in enemies:
        if enemy.global_position.distance_to(player_pos) <= SCAN_RADIUS:
            enemy.apply_status("exposed", SCAN_DURATION)
    Events.ability_activated.emit(player_id, "weak_point_scan", player_pos, Vector2.ZERO)
```

**Super: Overdrive**

| Property | Value |
|----------|-------|
| Charge required | 100 super points |
| Duration | 8 seconds |
| Effect | Player attack speed doubles (auto-fire cooldown halved), projectile damage +100%, movement speed +20% |
| Multiplayer | Server applies buff to player; stat changes replicated via ServerSync |

### Role: Engineer

**Theme:** Defensive support. Builds, heals, controls space.

| Property | Value |
|----------|-------|
| Color | Green rectangle `(0.2, 0.8, 0.3)` |
| Passive | +20% stamina regen rate |

**Ability: Deploy Turret**

| Property | Value |
|----------|-------|
| Cooldown | 15 seconds |
| Duration | 10 seconds (turret lifetime) |
| Turret HP | 5 hits |
| Turret fire rate | 1 shot per 0.8 seconds |
| Turret damage | 1 per shot |
| Turret range | 250px |
| Max turrets | 2 active at a time (oldest destroyed when placing 3rd) |
| Multiplayer | Server spawns turret entity; MultiplayerSpawner replicates to clients |

```gdscript
# In ability_deploy_turret.gd — runs on server
func activate(player_pos: Vector2, facing: int) -> void:
    var turret_pos := player_pos + Vector2(facing * 60, 0)
    _enforce_turret_limit()
    var turret := TURRET_SCENE.instantiate()
    turret.owner_id = player_id
    turret.position = turret_pos
    turret.name = "Turret_%d" % _next_turret_id
    _next_turret_id += 1
    get_tree().current_scene.get_node("Effects").add_child(turret, true)
    Events.ability_activated.emit(player_id, "deploy_turret", turret_pos, Vector2(facing, 0))
```

**Super: Healing Pulse**

| Property | Value |
|----------|-------|
| Charge required | 100 super points |
| Effect | Instantly heals ALL living players for 50 HP. Removes all negative status effects from all players. |
| Range | Global (affects all players regardless of distance) |
| Multiplayer | Server modifies all player health values; replicated via ServerSync |

### Ability Component Architecture

Abilities are implemented as child nodes attached to the Player node. This keeps ability logic modular and separate from the core player script.

```
Player (CharacterBody2D)
+-- ... (existing nodes)
+-- AbilityManager (Node) [script: ability_manager.gd]
    +-- Ability (Node) [script: varies by role]
    +-- Super (Node) [script: varies by role]
```

`ability_manager.gd` reads `input_ability` and `input_super` from the parent player and delegates to the appropriate child. It also tracks cooldowns and super charge.

```gdscript
# ability_manager.gd — attached as child of Player, runs on server
extends Node

var role: String = "striker"
var ability_cooldown: float = 0.0
var super_charge: float = 0.0
const SUPER_CHARGE_MAX: float = 100.0

func _physics_process(delta: float) -> void:
    if not multiplayer.is_server():
        return

    var player := get_parent() as CharacterBody2D
    ability_cooldown = maxf(ability_cooldown - delta, 0.0)

    if player.input_ability and ability_cooldown <= 0.0:
        $Ability.activate(player.global_position, player._facing)
        ability_cooldown = $Ability.COOLDOWN

    if player.input_super and super_charge >= SUPER_CHARGE_MAX:
        $Super.activate(player)
        super_charge = 0.0
```

### Multiplayer: Role System

| Aspect | Runs On | Synced How |
|--------|---------|-----------|
| Role selection | Each client locally, sent to server | RPC from client to server on selection |
| Role assignment dictionary | Server (authoritative) | Stored in GameManager, used at spawn time |
| Ability activation | Server only | Server reads input_ability, runs ability logic |
| Ability cooldown | Server only | Synced via ServerSync (ability_cooldown field on player) |
| Super charge | Server only | Synced via ServerSync (super_charge field on player) |
| Turret entity | Server spawns | MultiplayerSpawner replicates to all clients |
| Turret targeting/shooting | Server only | Turret projectiles spawned server-side, replicated |

---

## 3. Super / Ultimate System

### Charge Mechanic

Super charge accumulates by dealing damage. All damage dealt by a player (projectile hits, melee hits, turret damage attributed to owner, ability damage) adds to their super charge.

| Damage Source | Charge Gained |
|--------------|---------------|
| Projectile hit | 10 per hit |
| Melee hit | 15 per hit |
| Turret hit (Engineer) | 5 per hit |
| Ability damage (Weak Point Scan doesn't deal direct damage) | 0 |

**Charge formula:** `super_charge = min(super_charge + charge_amount, 100.0)`

When `super_charge >= 100.0`, the player can activate their super with the `super` input. After activation, charge resets to 0.

### Super Charge Sync

`super_charge` is a float on the player entity, synced via ServerSync to all clients. The HUD reads this value to display a charge meter.

### Multiplayer: Super System

| Aspect | Runs On | Synced How |
|--------|---------|-----------|
| Charge accumulation | Server only | Server adds charge when damage is dealt |
| Charge value | Server authoritative | Synced via ServerSync on player |
| Super activation | Server only | Server reads input_super, checks charge >= 100 |
| Super effects | Server only | Effects applied server-side (heal, buff, etc.) |
| HUD charge meter | Each client locally | Reads synced super_charge value |

---

## 4. Enemy Types

### 4.1 Merge Conflict (Existing, Enhanced)

**Theme:** Splits into smaller copies on death.

| Property | Value |
|----------|-------|
| Color | Red `(0.9, 0.15, 0.15)` |
| Tier 0 HP | 3 |
| Tier 1 HP | 2 |
| Tier 2 HP | 1 |
| Speed | 50 px/s (Tier 0), 65 px/s (Tier 1), 80 px/s (Tier 2) |
| Contact damage | 10 |
| Size | 48x48 (Tier 0), 32x32 (Tier 1), 20x20 (Tier 2) |
| Behavior | Chase nearest player |

**Split mechanic (Phase 2 addition):**
- On death, if `size_tier < 2`, spawn 2 children at `size_tier + 1`
- Children spawn offset left/right from parent death position
- `clean_kill` (from Weak Point Scan exposed state) skips splitting
- Emit `Events.enemy_split(parent_id, child_ids, positions)` on split

```gdscript
# In enemy_merge_conflict.gd — server only
func _die(killed_by: int) -> void:
    _is_alive = false
    var was_clean := has_status("exposed")
    Events.enemy_died.emit(enemy_id, killed_by, was_clean)

    if not was_clean and size_tier < 2:
        _spawn_children(killed_by)

    queue_free()

func _spawn_children(killed_by: int) -> void:
    var child_ids: Array[int] = []
    var child_positions: Array[Vector2] = []
    for offset in [-30.0, 30.0]:
        var child := SELF_SCENE.instantiate()
        child.size_tier = size_tier + 1
        child.enemy_id = GameManager.next_enemy_id()
        child.position = global_position + Vector2(offset, 0)
        child.name = "Enemy_%d" % child.enemy_id
        child_ids.append(child.enemy_id)
        child_positions.append(child.position)
        get_tree().current_scene.get_node("Enemies").add_child(child, true)

    Events.enemy_split.emit(enemy_id, child_ids, child_positions)
```

### 4.2 Hallucination

**Theme:** Deception. Disguises as a pickup or ally, then attacks when players get close.

| Property | Value |
|----------|-------|
| Color (disguised) | Green `(0.2, 0.9, 0.2)` — mimics health pickup |
| Color (revealed) | Purple `(0.6, 0.1, 0.8)` |
| HP | 2 |
| Speed (chasing) | 70 px/s |
| Contact damage | 15 |
| Size | 24x24 (disguised), 40x40 (revealed) |
| Reveal trigger | Player within 80px, or takes any damage |
| Behavior | Sits still while disguised; chases aggressively once revealed |

**Disguise mechanic:**
- Spawns looking like a health pickup (green square, smaller size)
- Stationary until a player approaches within 80px OR it takes any damage
- On reveal: plays a brief "grow" transition (size change from 24x24 to 40x40), switches to chase AI
- Striker's Weak Point Scan ability reveals all Hallucinations in range without triggering their attack (they become revealed but stunned for 2s)

**State flow:**
```
[DISGUISED] --(player within 80px OR takes damage)--> [REVEALING] --(0.3s)--> [AGGRESSIVE]
[DISGUISED] --(Weak Point Scan hits)--> [REVEALING] --(0.3s)--> [STUNNED 2s] --> [AGGRESSIVE]
```

### 4.3 Context Rot

**Theme:** Information warfare. Projectiles scramble the player's HUD.

| Property | Value |
|----------|-------|
| Color | Yellow-green `(0.7, 0.8, 0.1)` |
| HP | 4 |
| Speed | 40 px/s |
| Projectile damage | 8 |
| Projectile speed | 200 px/s |
| Fire rate | 1 shot per 2.0 seconds |
| Fire range | 350px (stops and shoots when player is in range) |
| Size | 40x40 |
| Behavior | Approaches to firing range, then stops and shoots |
| Special | Projectile hits apply "context_rot" status effect to player (see Status Effects) |

**Projectile behavior:**
- Context Rot fires a distinct projectile type (`projectile_context_rot`)
- On hit, applies `context_rot` status effect to the player for 5 seconds
- The projectile is visually distinct: dark green `(0.2, 0.5, 0.1)` and slightly larger (12x12)

```gdscript
# In enemy_context_rot.gd — server only
func _attack() -> void:
    if _fire_cooldown > 0.0:
        return
    var target := _find_nearest_player()
    if not target:
        return
    var dir := (target.global_position - global_position).normalized()
    _fire_rot_projectile(dir)
    _fire_cooldown = FIRE_RATE

func _fire_rot_projectile(direction: Vector2) -> void:
    var proj := ROT_PROJECTILE_SCENE.instantiate()
    proj.direction = direction
    proj.damage = PROJECTILE_DAMAGE
    proj.owner_id = enemy_id
    proj.is_enemy_projectile = true
    proj.status_effect = "context_rot"
    proj.name = "RotProj_%d" % (randi() % 1000000)
    proj.position = global_position + direction * 25.0
    get_tree().current_scene.get_node("Projectiles").add_child(proj, true)
```

### 4.4 Dependency Hell

**Theme:** Area denial. Aura disables player abilities.

| Property | Value |
|----------|-------|
| Color | Dark blue `(0.15, 0.15, 0.6)` |
| HP | 6 |
| Speed | 30 px/s |
| Contact damage | 12 |
| Aura radius | 200px |
| Size | 56x56 |
| Behavior | Slow, tanky. Walks toward players. Aura passively disables abilities. |
| Special | Players within aura radius have "ability_disabled" status effect (see Status Effects) |

**Aura mechanic:**
- Every physics frame (server only), checks all players within `AURA_RADIUS`
- Players inside the aura receive `ability_disabled` status effect, refreshed each frame they remain inside
- When a player leaves the aura, the status effect expires after 1 second (grace period)
- The aura does NOT disable super abilities -- only regular abilities
- Killing the Dependency Hell immediately removes all its aura effects

```gdscript
# In enemy_dependency_hell.gd — server only, called in _physics_process
func _apply_aura() -> void:
    var players := get_tree().get_nodes_in_group("players")
    for player in players:
        if not player.visible:
            continue
        var dist := global_position.distance_to(player.global_position)
        if dist <= AURA_RADIUS:
            player.apply_status("ability_disabled", 1.0)  # Refreshed each frame
```

### Enemy Type Summary

| Type | Color | HP | Speed | Size | Threat |
|------|-------|-----|-------|------|--------|
| Merge Conflict (T0) | Red | 3 | 50 | 48x48 | Splits on death |
| Merge Conflict (T1) | Light Red | 2 | 65 | 32x32 | Splits on death |
| Merge Conflict (T2) | Pink | 1 | 80 | 20x20 | Dies clean |
| Hallucination | Green/Purple | 2 | 70 | 24->40 | Ambush |
| Context Rot | Yellow-green | 4 | 40 | 40x40 | Ranged + status |
| Dependency Hell | Dark Blue | 6 | 30 | 56x56 | Ability denial aura |

### Multiplayer: Enemy Types

| Aspect | Runs On | Synced How |
|--------|---------|-----------|
| Enemy AI / behavior | Server only | Position synced via MultiplayerSynchronizer |
| Enemy spawning | Server only | MultiplayerSpawner replicates to all clients |
| Split mechanic | Server only | Server spawns children; spawner replicates |
| Hallucination reveal | Server only | `is_disguised` bool synced via MultiplayerSynchronizer |
| Context Rot projectiles | Server spawns | ProjectileSpawner replicates |
| Dependency Hell aura | Server only | Status applied server-side; status effects synced on player |
| Enemy health | Server authoritative | Synced via MultiplayerSynchronizer |
| Contact damage | Server only | Server detects collision, calls player.take_damage() |

---

## 5. Enemy AI State Machine

### Base State Machine

All enemies inherit from a common base class `enemy_base.gd` that provides a state machine framework. Individual enemy types override specific states or add new ones.

### States

| State | Description | Transitions To |
|-------|-------------|---------------|
| `IDLE` | Enemy is stationary. Used for initial spawn delay and Hallucination disguise. | `CHASE`, `ATTACK` |
| `CHASE` | Enemy moves toward nearest player. | `ATTACK` (in range), `IDLE` (no target), `FLEE` (low HP, if applicable) |
| `ATTACK` | Enemy performs its attack action (contact damage, ranged shot, etc.). | `CHASE` (target moved out of range), `IDLE` (target dead) |
| `FLEE` | Enemy retreats from players. Only used by Context Rot when players get too close. | `CHASE` (distance restored) |
| `STUNNED` | Enemy cannot act. Applied by Weak Point Scan on Hallucination, or by future stun effects. | `CHASE` (stun duration expires) |
| `DEAD` | Terminal state. Enemy plays death logic and is freed. | None |

### Base Enemy Script

```gdscript
# enemy_base.gd — base class for all enemy types
extends CharacterBody2D

enum State { IDLE, CHASE, ATTACK, FLEE, STUNNED, DEAD }

var enemy_id: int = 0
var health: int = 3
var speed: float = 50.0
var contact_damage: int = 10
var _is_alive: bool = true
var _current_state: State = State.IDLE
var _stun_timer: float = 0.0
var _status_effects: Dictionary = {}  # { effect_name: remaining_duration }

func _ready() -> void:
    add_to_group("enemies")

func _physics_process(delta: float) -> void:
    if not _is_alive or not multiplayer.is_server():
        return
    _update_status_effects(delta)
    match _current_state:
        State.IDLE:
            _state_idle(delta)
        State.CHASE:
            _state_chase(delta)
        State.ATTACK:
            _state_attack(delta)
        State.FLEE:
            _state_flee(delta)
        State.STUNNED:
            _state_stunned(delta)
        State.DEAD:
            pass

# Virtual methods — override in subclasses
func _state_idle(_delta: float) -> void:
    _transition_to(State.CHASE)

func _state_chase(delta: float) -> void:
    var target := _find_nearest_player()
    if not target:
        _transition_to(State.IDLE)
        return
    var dir := (target.global_position - global_position).normalized()
    velocity = dir * speed
    move_and_slide()

func _state_attack(_delta: float) -> void:
    pass  # Override per enemy type

func _state_flee(delta: float) -> void:
    var target := _find_nearest_player()
    if not target:
        _transition_to(State.IDLE)
        return
    var dir := (global_position - target.global_position).normalized()
    velocity = dir * speed * 0.8
    move_and_slide()

func _state_stunned(delta: float) -> void:
    velocity = Vector2.ZERO
    _stun_timer -= delta
    if _stun_timer <= 0.0:
        _transition_to(State.CHASE)

func _transition_to(new_state: State) -> void:
    _current_state = new_state

func take_damage(amount: int, from_player_id: int) -> void:
    if not _is_alive or not multiplayer.is_server():
        return
    # Check for "exposed" status (Weak Point Scan doubles damage)
    if has_status("exposed"):
        amount *= 2
    health -= amount
    if health <= 0:
        health = 0
        _die(from_player_id)

func _die(killed_by: int) -> void:
    _is_alive = false
    _current_state = State.DEAD
    velocity = Vector2.ZERO
    Events.enemy_died.emit(enemy_id, killed_by, false)
    queue_free()

func apply_status(effect_name: String, duration: float) -> void:
    _status_effects[effect_name] = duration

func has_status(effect_name: String) -> bool:
    return _status_effects.has(effect_name) and _status_effects[effect_name] > 0.0

func _update_status_effects(delta: float) -> void:
    var expired: Array[String] = []
    for effect_name in _status_effects:
        _status_effects[effect_name] -= delta
        if _status_effects[effect_name] <= 0.0:
            expired.append(effect_name)
    for effect_name in expired:
        _status_effects.erase(effect_name)

func _find_nearest_player() -> Node2D:
    var players := get_tree().get_nodes_in_group("players")
    var nearest: Node2D = null
    var nearest_dist: float = INF
    for player in players:
        if not player is Node2D or not player.visible:
            continue
        var dist := global_position.distance_to(player.global_position)
        if dist < nearest_dist:
            nearest_dist = dist
            nearest = player
    return nearest
```

### Per-Type State Overrides

| Enemy Type | IDLE | CHASE | ATTACK | FLEE | Special States |
|------------|------|-------|--------|------|---------------|
| Merge Conflict | Immediate transition to CHASE | Chase nearest player | Contact damage on overlap | N/A | `_die()` overridden to split |
| Hallucination | Stay disguised until triggered | Fast chase (70 px/s) | Contact damage on overlap | N/A | `DISGUISED` (custom state before IDLE) |
| Context Rot | Immediate transition to CHASE | Approach to 350px range | Fire projectile every 2s | Flee if player < 100px | N/A |
| Dependency Hell | Immediate transition to CHASE | Slow chase (30 px/s) | Contact damage on overlap | N/A | Aura runs in `_physics_process` alongside state |

### Contact Damage System

All melee enemies deal contact damage when overlapping with a player. This is handled in the base class using an `Area2D` hurtbox:

```gdscript
# In enemy_base.gd
const CONTACT_DAMAGE_COOLDOWN: float = 1.0
var _contact_damage_timer: float = 0.0

func _on_hurtbox_body_entered(body: Node) -> void:
    if not multiplayer.is_server():
        return
    if body.is_in_group("players") and body.has_method("take_damage"):
        if _contact_damage_timer <= 0.0:
            body.take_damage(contact_damage)
            _contact_damage_timer = CONTACT_DAMAGE_COOLDOWN
```

### Multiplayer: AI State Machine

| Aspect | Runs On | Synced How |
|--------|---------|-----------|
| State transitions | Server only | `_current_state` synced via MultiplayerSynchronizer for client-side visual cues |
| Movement | Server only | Position synced via MultiplayerSynchronizer |
| Status effects on enemies | Server only | Individual status bools synced if needed for visuals |
| Target selection | Server only | Not synced (clients don't need to know targeting) |

---

## 6. Revive System

### Overview

When a player dies, they enter a "downed" state instead of being permanently dead. A living teammate can hold the revive action near the downed player to bring them back.

### Revive Rules

| Property | Value |
|----------|-------|
| Revive input | Hold `interact` action (F key / Y button on Xbox / Triangle on PS) |
| Revive range | 80px |
| Revive time | 3.0 seconds (must hold continuously) |
| Health on revive | 50% of max (50 HP) |
| Rescuer restrictions | Cannot shoot, use abilities, or sprint while reviving. Can still move (slowly, 50% speed). |
| Interruption | Taking damage interrupts the revive (resets progress). Moving out of range interrupts. Releasing the key interrupts. |
| Bleedout timer | 30 seconds. If not revived within 30s, player is permanently dead for the rest of the wave. |
| Revives per wave | Unlimited |
| Visual indicator | Downed player rectangle flashes. Progress bar appears above downed player (0-100%). |

### Downed State

When `player.health <= 0`:
1. Player enters downed state (`_is_downed = true`)
2. Player becomes unable to act (no input processing)
3. Player collision is disabled (enemies walk through)
4. Bleedout timer starts counting down (30s)
5. Player color changes to gray with flashing alpha

### Revive Flow (Server-Authoritative)

```
[Rescuer holds interact near downed player]
        |
        v
[Server validates: rescuer alive, target downed, within 80px]
        |
        v
[Server starts revive timer, emits revive_started]
        |
  (each frame: check distance, input held, rescuer alive, no damage taken)
        |
  (if any check fails) --> [Cancel revive, emit revive_cancelled]
        |
  (3.0 seconds elapsed)
        |
        v
[Server restores player: health=50, _is_downed=false, collision re-enabled]
[Emit revive_completed]
```

### Revive Input

A new input action `interact` is needed:

| Action | Keyboard | Controller |
|--------|----------|------------|
| `interact` | F | Y (Xbox) / Triangle (PS) |

This is also added to `InputSync` as `input_interact: bool`.

### Revive Script

```gdscript
# In revive_system.gd — child of Player, runs on server
extends Node

const REVIVE_RANGE: float = 80.0
const REVIVE_TIME: float = 3.0
const REVIVE_HEALTH: int = 50
const REVIVE_SPEED_MULT: float = 0.5
const BLEEDOUT_TIME: float = 30.0

var _revive_target: CharacterBody2D = null
var _revive_progress: float = 0.0
var _is_reviving: bool = false

func _physics_process(delta: float) -> void:
    if not multiplayer.is_server():
        return
    var player := get_parent() as CharacterBody2D
    if not player._is_alive or player._is_downed:
        return

    if player.input_interact:
        if not _is_reviving:
            _try_start_revive(player)
        else:
            _continue_revive(player, delta)
    else:
        _cancel_revive()

func _try_start_revive(rescuer: CharacterBody2D) -> void:
    var target := _find_downed_player_in_range(rescuer)
    if not target:
        return
    _revive_target = target
    _revive_progress = 0.0
    _is_reviving = true
    Events.revive_started.emit(rescuer.player_id, target.player_id)

func _continue_revive(rescuer: CharacterBody2D, delta: float) -> void:
    if not is_instance_valid(_revive_target) or not _revive_target._is_downed:
        _cancel_revive()
        return
    if rescuer.global_position.distance_to(_revive_target.global_position) > REVIVE_RANGE:
        _cancel_revive()
        return
    _revive_progress += delta
    Events.revive_progress.emit(rescuer.player_id, _revive_target.player_id, _revive_progress / REVIVE_TIME)
    if _revive_progress >= REVIVE_TIME:
        _complete_revive(rescuer)

func _complete_revive(rescuer: CharacterBody2D) -> void:
    _revive_target.health = REVIVE_HEALTH
    _revive_target._is_downed = false
    _revive_target._is_alive = true
    _revive_target.visible = true
    _revive_target.set_physics_process(true)
    Events.revive_completed.emit(rescuer.player_id, _revive_target.player_id)
    _cancel_revive()
```

### Multiplayer: Revive System

| Aspect | Runs On | Synced How |
|--------|---------|-----------|
| Downed state | Server authoritative | `_is_downed` bool synced via ServerSync |
| Revive progress | Server only | RPC to clients for progress bar UI |
| Bleedout timer | Server only | `_bleedout_timer` synced via ServerSync |
| Revive completion | Server only | Server sets health and state; replicated via ServerSync |
| Rescuer speed penalty | Server only | Server applies 0.5x speed during revive |
| Rescuer shoot lock | Server only | Server ignores shoot/ability inputs during revive |

---

## 7. Status Effects

### Overview

Status effects are temporary modifiers applied to players or enemies. They are tracked as dictionaries on the affected entity.

### Player Status Effects

| Effect | Applied By | Duration | Behavior | Stacking |
|--------|-----------|----------|----------|----------|
| `context_rot` | Context Rot enemy projectile | 5 seconds | HUD elements display scrambled/wrong values (health shows random number, stamina bar inverted, wave label garbled). Actual game state is unaffected -- only the local HUD display is corrupted. | Duration refreshes (does not stack intensity) |
| `ability_disabled` | Dependency Hell aura | 1 second (refreshed while in aura) | Player cannot activate their regular ability (input_ability is ignored by server). Super is NOT affected. | Duration refreshes |
| `slow` | Reserved for future use | 3 seconds | Movement speed reduced by 40%. | Duration refreshes, does not stack intensity |
| `exposed` | Weak Point Scan (applied to enemies, not players) | 6 seconds | Enemy takes 2x damage from all sources. | Duration refreshes |

### Status Effect Implementation (Player Side)

```gdscript
# Added to player.gd
var _status_effects: Dictionary = {}  # { "effect_name": remaining_seconds }

func apply_status(effect_name: String, duration: float) -> void:
    # Server only — clients receive synced status via ServerSync
    if not multiplayer.is_server():
        return
    _status_effects[effect_name] = duration
    Events.status_applied.emit(player_id, effect_name, duration)

func remove_status(effect_name: String) -> void:
    if _status_effects.has(effect_name):
        _status_effects.erase(effect_name)
        Events.status_removed.emit(player_id, effect_name)

func has_status(effect_name: String) -> bool:
    return _status_effects.has(effect_name) and _status_effects[effect_name] > 0.0

func _update_status_effects(delta: float) -> void:
    # Called each _physics_process on the server
    var expired: Array[String] = []
    for effect_name in _status_effects:
        _status_effects[effect_name] -= delta
        if _status_effects[effect_name] <= 0.0:
            expired.append(effect_name)
    for effect_name in expired:
        _status_effects.erase(effect_name)
        Events.status_removed.emit(player_id, effect_name)
```

### Status Effect Application Points

In `_server_process()` in `player.gd`:

```gdscript
# Speed modification
var speed_mult := 1.0
if has_status("slow"):
    speed_mult *= 0.6

# During revive
if _is_reviving_someone:
    speed_mult *= 0.5

var current_speed := (SPRINT_SPEED if is_sprinting else RUN_SPEED) * speed_mult
velocity.x = input_move_dir * current_speed

# Ability blocking
if player.input_ability and ability_cooldown <= 0.0:
    if not player.has_status("ability_disabled"):
        $Ability.activate(...)
```

### Context Rot HUD Scramble (Client-Side Only)

The `context_rot` effect is purely visual and only affects the local client's HUD. The server tracks and syncs the status, but the actual scrambling happens client-side:

```gdscript
# In player.gd _update_hud() — runs on owning client
func _update_hud() -> void:
    var hud = get_tree().current_scene.get_node_or_null("UI/HUD")
    if not hud:
        return

    var health_label = hud.get_node_or_null("HealthLabel") as Label
    var stamina_bar = hud.get_node_or_null("StaminaBar") as ProgressBar

    if has_status("context_rot"):
        # Scramble HUD with fake values
        if health_label:
            health_label.text = "Health: %d" % (randi() % 200)
        if stamina_bar:
            stamina_bar.value = randf() * 100.0
    else:
        if health_label:
            health_label.text = "Health: %d" % health
        if stamina_bar:
            stamina_bar.value = stamina
```

### Multiplayer: Status Effects

| Aspect | Runs On | Synced How |
|--------|---------|-----------|
| Status application/removal | Server only | Server modifies `_status_effects` dict |
| Active status list | Server authoritative | Synced as packed data via ServerSync (active_statuses: Array[String]) |
| Context rot HUD scramble | Client only (visual) | Client reads synced status list, scrambles own HUD locally |
| Ability disable enforcement | Server only | Server checks status before allowing ability activation |
| Speed modification | Server only | Server applies speed multiplier in physics |

---

## 8. New Signals (Events Autoload)

All new signals to add to `events.gd`:

```gdscript
# ── Role Events ───────────────────────────────────────────────────────────────
signal role_selected(player_id: int, role: String)
signal role_assigned(player_id: int, role: String)

# ── Revive Events ─────────────────────────────────────────────────────────────
signal revive_started(rescuer_id: int, target_id: int)
signal revive_progress(rescuer_id: int, target_id: int, progress: float)
signal revive_completed(rescuer_id: int, target_id: int)
signal revive_cancelled(rescuer_id: int, target_id: int)
signal player_downed(player_id: int, position: Vector2)
signal player_bleedout(player_id: int)

# ── Status Effect Events ──────────────────────────────────────────────────────
signal status_applied(entity_id: int, effect_name: String, duration: float)
signal status_removed(entity_id: int, effect_name: String)

# ── Super Events ──────────────────────────────────────────────────────────────
signal super_charged(player_id: int, charge: float)
signal super_activated(player_id: int, super_name: String)

# ── Turret Events ─────────────────────────────────────────────────────────────
signal turret_deployed(owner_id: int, turret_id: int, position: Vector2)
signal turret_destroyed(turret_id: int)

# ── Enemy-Specific Events ─────────────────────────────────────────────────────
signal hallucination_revealed(enemy_id: int, position: Vector2)
signal dependency_aura_entered(player_id: int, enemy_id: int)
signal dependency_aura_exited(player_id: int, enemy_id: int)
```

### Full Updated Signal List

The complete `events.gd` after Phase 2 will contain all existing Phase 1 signals plus the signals listed above.

---

## 9. File Structure

### New Files

```
game/
+-- scripts/
|   +-- wave_manager.gd                    # Wave state machine, spawning logic, difficulty scaling
|   +-- ability_manager.gd                  # Per-player node: manages ability + super, reads input
|   +-- revive_system.gd                    # Per-player node: revive detection and progress
|   +-- status_effect_handler.gd            # Shared utility: apply/remove/tick status effects
|   +-- enemies/
|   |   +-- enemy_base.gd                   # Base class: state machine, take_damage, status effects
|   |   +-- enemy_merge_conflict.gd         # Merge Conflict: chase + split on death
|   |   +-- enemy_hallucination.gd          # Hallucination: disguise + reveal + aggressive chase
|   |   +-- enemy_context_rot.gd            # Context Rot: ranged + status projectile
|   |   +-- enemy_dependency_hell.gd        # Dependency Hell: slow tank + ability-disable aura
|   +-- abilities/
|   |   +-- ability_weak_point_scan.gd      # Striker ability: reveal weak points in radius
|   |   +-- ability_deploy_turret.gd        # Engineer ability: place auto-targeting turret
|   |   +-- super_overdrive.gd              # Striker super: attack speed + damage boost
|   |   +-- super_healing_pulse.gd          # Engineer super: heal all players, clear statuses
|   +-- entities/
|   |   +-- turret.gd                       # Turret entity: auto-target + shoot nearest enemy
|   |   +-- projectile_enemy.gd             # Enemy projectile: can apply status effects on hit
+-- scenes/
|   +-- enemies/
|   |   +-- enemy_merge_conflict.tscn       # Merge Conflict scene (replaces old enemy.tscn)
|   |   +-- enemy_hallucination.tscn        # Hallucination scene
|   |   +-- enemy_context_rot.tscn          # Context Rot scene
|   |   +-- enemy_dependency_hell.tscn      # Dependency Hell scene
|   +-- turret.tscn                         # Turret entity scene
|   +-- projectile_enemy.tscn               # Enemy projectile scene
```

### Modified Files

| File | Changes |
|------|---------|
| `scripts/player.gd` | Add `_is_downed`, `_bleedout_timer`, `_status_effects`, `apply_status()`, `has_status()`, `remove_status()`, `_update_status_effects()`. Modify `die()` to enter downed state instead of permanent death. Modify `_server_process()` to check status effects for speed/ability modifiers. Modify `_update_hud()` for context_rot scramble. Add `input_interact` to input variables. |
| `scripts/game_manager.gd` | Replace `_spawn_test_enemy()` with wave system delegation to `wave_manager.gd`. Add role assignment storage. Add `next_enemy_id()` public method. Add turret spawner setup. Update `_ready()` to instantiate `wave_manager` and start wave 1. |
| `scripts/autoloads/events.gd` | Add all new signals from section 8. |
| `scripts/projectile.gd` | Add `is_enemy_projectile: bool` and `status_effect: String` fields. Modify `_on_body_entered()` to handle enemy projectiles hitting players (apply status, deal damage). |
| `scripts/lobby.gd` | Add role selection buttons. Store selected role locally. Send role to server via RPC when selected. |
| `scenes/game.tscn` | Add `EffectsSpawner` (MultiplayerSpawner for turrets). Register new enemy scenes in `EnemySpawner._spawnable_scenes`. Register `projectile_enemy.tscn` in `ProjectileSpawner._spawnable_scenes`. Add revive-related HUD elements. Add ability cooldown and super charge HUD elements. |
| `scenes/player.tscn` | Add `AbilityManager` child node. Add `ReviveSystem` child node. Add `input_interact` to InputSync replication config. Add `_is_downed`, `ability_cooldown`, `super_charge`, `active_statuses` to ServerSync replication config. |

### Scene Tree: Updated player.tscn

```
Player (CharacterBody2D) [script: player.gd]
+-- CollisionShape2D
+-- ColorRect
+-- Camera2D
+-- ShootPoint (Marker2D)
+-- ServerSync (MultiplayerSynchronizer)
|   replicates: position, velocity, health, stamina, _is_downed,
|               _bleedout_timer, ability_cooldown, super_charge, active_statuses
+-- InputSync (MultiplayerSynchronizer)
|   replicates: input_move_dir, input_shoot, input_jump, input_sprint,
|               input_melee, input_ability, input_super, input_interact
+-- AbilityManager (Node) [script: ability_manager.gd]
|   +-- Ability (Node) [script: varies — set at spawn by game_manager]
|   +-- Super (Node) [script: varies — set at spawn by game_manager]
+-- ReviveSystem (Node) [script: revive_system.gd]
```

### Scene Tree: enemy_merge_conflict.tscn

```
Enemy (CharacterBody2D) [script: enemy_merge_conflict.gd]
+-- CollisionShape2D       # Scales with size_tier
+-- ColorRect              # Scales with size_tier, color varies by tier
+-- Hurtbox (Area2D)       # For projectile hit detection
|   +-- CollisionShape2D   # Scales with size_tier
+-- MultiplayerSynchronizer
    replicates: position, health, _current_state, size_tier
```

### Scene Tree: turret.tscn

```
Turret (StaticBody2D) [script: turret.gd]
+-- CollisionShape2D           # 24x24
+-- ColorRect                  # Cyan (0.0, 0.8, 0.8)
+-- DetectionArea (Area2D)     # 250px radius circle for target detection
|   +-- CollisionShape2D       # CircleShape2D, radius 250
+-- ShootPoint (Marker2D)
+-- MultiplayerSynchronizer
    replicates: position, health, owner_id
```

---

## 10. Multiplayer Integration Summary

### Authority Map

| System | Authority | Client Role |
|--------|-----------|-------------|
| Wave state machine | Server | Display wave number, state from synced data |
| Enemy spawning | Server | Receive via MultiplayerSpawner |
| Enemy AI | Server | Display position from synced data |
| Ability activation | Server | Send input via InputSync |
| Ability cooldown | Server | Display from synced cooldown value |
| Super charge | Server | Display from synced charge value |
| Turret behavior | Server | Receive entity via MultiplayerSpawner |
| Revive logic | Server | Send interact input via InputSync, display progress from RPC |
| Status effects (logic) | Server | N/A |
| Status effects (HUD) | Client | Read synced status list, apply visual effects locally |
| Damage calculation | Server | N/A |
| Role assignment | Server | Send preference via RPC, receive confirmed role |

### New Synced Properties (ServerSync additions on Player)

| Property | Type | Purpose |
|----------|------|---------|
| `_is_downed` | bool | Whether player is in downed state |
| `_bleedout_timer` | float | Seconds remaining before permanent death |
| `ability_cooldown` | float | Seconds until ability is ready |
| `super_charge` | float | Current super charge (0-100) |
| `active_statuses` | PackedStringArray | List of active status effect names |

### New Input (InputSync addition on Player)

| Property | Type | Purpose |
|----------|------|---------|
| `input_interact` | bool | Interact/revive button held |

### New MultiplayerSpawner Registrations

| Spawner | New Scenes to Register |
|---------|----------------------|
| `EnemySpawner` | `enemy_merge_conflict.tscn`, `enemy_hallucination.tscn`, `enemy_context_rot.tscn`, `enemy_dependency_hell.tscn` |
| `ProjectileSpawner` | `projectile_enemy.tscn` |
| `EffectsSpawner` (new) | `turret.tscn` |

### RPC Calls (New)

| RPC | Direction | Channel | Purpose |
|-----|-----------|---------|---------|
| `_notify_wave_started(wave_number, enemy_count)` | Server -> All | Reliable | Inform clients of new wave |
| `_notify_wave_cleared(wave_number)` | Server -> All | Reliable | Inform clients wave is complete |
| `_notify_game_won(total_waves, time)` | Server -> All | Reliable | Game victory |
| `_notify_game_lost(wave, time)` | Server -> All | Reliable | Game over |
| `_notify_revive_progress(rescuer_id, target_id, progress)` | Server -> All | Unreliable | Update revive progress bar |
| `_request_role(role_name)` | Client -> Server | Reliable | Player requests a role in lobby |
| `_confirm_role(player_id, role_name)` | Server -> All | Reliable | Broadcast confirmed role assignment |

---

## 11. Entity Schema Additions

### Turret Entity

| Field | Type | Sync | Description |
|-------|------|------|-------------|
| `turret_id` | int | Init | Unique identifier |
| `owner_id` | int | Init | Player who deployed it |
| `position` | Vector2 | Continuous | World position (stationary) |
| `health` | int | OnChange | Current HP (max 5) |

**ID range:** Turrets use the Effects ID range, starting at 100000.

### Enemy Projectile Entity

| Field | Type | Sync | Description |
|-------|------|------|-------------|
| `direction` | Vector2 | Init | Normalized direction |
| `speed` | float | Init | 200 px/s |
| `damage` | int | Init | Varies by enemy type |
| `owner_id` | int | Init | Enemy that fired it |
| `is_enemy_projectile` | bool | Init | Always true |
| `status_effect` | String | Init | Status to apply on hit (e.g., "context_rot") |

**Reuses projectile ID range** starting at 10000.

---

## 12. Implementation Order

The systems should be built in this order to minimize blocking dependencies:

### Step 1: Foundation (no dependencies)
1. **Enemy base class** (`enemy_base.gd`) — state machine, take_damage, status effect tracking
2. **Status effect handler** — apply/remove/tick logic on both player and enemy
3. **Wave manager skeleton** (`wave_manager.gd`) — state machine, spawn timing, wave count

### Step 2: Core Combat (depends on Step 1)
4. **Merge Conflict upgrade** — split mechanic using enemy_base, replace old enemy.gd
5. **Contact damage system** — enemies damage players on overlap
6. **Enemy projectile** — enemy-fired projectiles that can hit players and apply status effects
7. **Context Rot enemy** — ranged enemy using enemy projectile + context_rot status

### Step 3: Roles and Abilities (depends on Step 1)
8. **Ability manager** — per-player component, cooldown tracking, input routing
9. **Weak Point Scan** (Striker ability)
10. **Deploy Turret** (Engineer ability) + turret entity
11. **Role selection in lobby** — UI and RPC for choosing role

### Step 4: Advanced Systems (depends on Steps 2-3)
12. **Hallucination enemy** — disguise + reveal, interaction with Weak Point Scan
13. **Dependency Hell enemy** — aura system, interaction with ability_disabled status
14. **Super system** — charge accumulation, Overdrive and Healing Pulse supers
15. **Revive system** — downed state, hold-to-revive, bleedout timer

### Step 5: Integration
16. **Wire everything into game_manager.gd** — wave spawning with all enemy types, role-based player setup
17. **HUD updates** — ability cooldown display, super charge meter, status effect indicators, revive progress
18. **Full integration test** — 2 players, 5+ waves, both roles, all enemy types, revive scenario

---

## Appendix A: Placeholder Colors (Phase 2 Additions)

| Entity | Color | RGB |
|--------|-------|-----|
| Player (Striker) | Orange | (1.0, 0.6, 0.1) |
| Player (Engineer) | Green | (0.2, 0.8, 0.3) |
| Merge Conflict T0 | Red | (0.9, 0.15, 0.15) |
| Merge Conflict T1 | Light Red | (0.9, 0.4, 0.4) |
| Merge Conflict T2 | Pink | (0.9, 0.6, 0.6) |
| Hallucination (disguised) | Green | (0.2, 0.9, 0.2) |
| Hallucination (revealed) | Purple | (0.6, 0.1, 0.8) |
| Context Rot | Yellow-green | (0.7, 0.8, 0.1) |
| Context Rot projectile | Dark Green | (0.2, 0.5, 0.1) |
| Dependency Hell | Dark Blue | (0.15, 0.15, 0.6) |
| Turret | Cyan | (0.0, 0.8, 0.8) |
| Downed player | Gray (flashing) | (0.5, 0.5, 0.5, alpha pulses) |

## Appendix B: Constants Quick Reference

```gdscript
# Wave System
const WAVE_REST_DURATIONS: Array[float] = [5.0, 5.0, 5.0, 4.0, 4.0, 3.0]
const WAVE_MAX_ENEMIES: int = 30
const WAVE_SPAWN_STAGGER: float = 0.15

# Role: Striker
const STRIKER_DAMAGE_BONUS: float = 0.15
const SCAN_COOLDOWN: float = 12.0
const SCAN_DURATION: float = 6.0
const SCAN_RADIUS: float = 300.0
const OVERDRIVE_DURATION: float = 8.0
const OVERDRIVE_ATTACK_MULT: float = 2.0
const OVERDRIVE_DAMAGE_MULT: float = 2.0
const OVERDRIVE_SPEED_MULT: float = 1.2

# Role: Engineer
const ENGINEER_STAMINA_REGEN_BONUS: float = 0.2
const TURRET_COOLDOWN: float = 15.0
const TURRET_LIFETIME: float = 10.0
const TURRET_HP: int = 5
const TURRET_FIRE_RATE: float = 0.8
const TURRET_DAMAGE: int = 1
const TURRET_RANGE: float = 250.0
const TURRET_MAX_ACTIVE: int = 2
const HEALING_PULSE_AMOUNT: int = 50

# Super System
const SUPER_CHARGE_MAX: float = 100.0
const SUPER_CHARGE_PER_PROJECTILE_HIT: float = 10.0
const SUPER_CHARGE_PER_MELEE_HIT: float = 15.0
const SUPER_CHARGE_PER_TURRET_HIT: float = 5.0

# Revive System
const REVIVE_RANGE: float = 80.0
const REVIVE_TIME: float = 3.0
const REVIVE_HEALTH: int = 50
const REVIVE_SPEED_MULT: float = 0.5
const BLEEDOUT_TIME: float = 30.0

# Status Effects
const CONTEXT_ROT_DURATION: float = 5.0
const ABILITY_DISABLE_DURATION: float = 1.0
const SLOW_DURATION: float = 3.0
const SLOW_SPEED_MULT: float = 0.6
const EXPOSED_DURATION: float = 6.0
const EXPOSED_DAMAGE_MULT: float = 2.0

# Contact Damage
const CONTACT_DAMAGE_COOLDOWN: float = 1.0

# Enemy: Merge Conflict
const MC_T0_HP: int = 3
const MC_T0_SPEED: float = 50.0
const MC_T0_SIZE: Vector2 = Vector2(48, 48)
const MC_T0_CONTACT_DMG: int = 10
const MC_T1_HP: int = 2
const MC_T1_SPEED: float = 65.0
const MC_T1_SIZE: Vector2 = Vector2(32, 32)
const MC_T1_CONTACT_DMG: int = 8
const MC_T2_HP: int = 1
const MC_T2_SPEED: float = 80.0
const MC_T2_SIZE: Vector2 = Vector2(20, 20)
const MC_T2_CONTACT_DMG: int = 5

# Enemy: Hallucination
const HALL_HP: int = 2
const HALL_CHASE_SPEED: float = 70.0
const HALL_REVEAL_RANGE: float = 80.0
const HALL_CONTACT_DMG: int = 15
const HALL_DISGUISED_SIZE: Vector2 = Vector2(24, 24)
const HALL_REVEALED_SIZE: Vector2 = Vector2(40, 40)
const HALL_REVEAL_TIME: float = 0.3
const HALL_SCAN_STUN: float = 2.0

# Enemy: Context Rot
const CR_HP: int = 4
const CR_SPEED: float = 40.0
const CR_FIRE_RATE: float = 2.0
const CR_FIRE_RANGE: float = 350.0
const CR_FLEE_RANGE: float = 100.0
const CR_PROJ_SPEED: float = 200.0
const CR_PROJ_DAMAGE: int = 8
const CR_SIZE: Vector2 = Vector2(40, 40)

# Enemy: Dependency Hell
const DH_HP: int = 6
const DH_SPEED: float = 30.0
const DH_AURA_RADIUS: float = 200.0
const DH_CONTACT_DMG: int = 12
const DH_SIZE: Vector2 = Vector2(56, 56)
```
