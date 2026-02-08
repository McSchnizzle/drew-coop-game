# Architecture Document: Drew's Co-op Agent-Bot Shooter

> **Last updated:** 2026-02-08 (Golden Path build)
> **Engine:** Godot 4.4 | **Language:** GDScript | **Networking:** ENet (Godot High-Level Multiplayer)

---

## 1. System Overview

Drew's Co-op Game is a 2D side-scrolling co-op shooter (Contra/Metal Slug style) where 2 players fight waves of "agent-bot" enemies whose attacks are software failures made physical. The first enemy type is the **Merge Conflict**, which splits into smaller copies when killed with normal shots but can be cleanly dissolved with the "Git Revert" ability.

### Tech Stack

| Layer | Technology | Notes |
|-------|-----------|-------|
| Engine | Godot 4.4 | Native Mac/Windows, scene-based architecture |
| Language | GDScript | All game logic |
| Networking | ENet via `ENetMultiplayerPeer` | Built-in high-level multiplayer API |
| Replication | `MultiplayerSynchronizer` + `MultiplayerSpawner` | Declarative state sync |
| Art (Phase 1) | Colored rectangles | Placeholder; 16-bit pixel art planned |
| Input | Keyboard + Controller (Xbox/PS) | Unified via Godot Input Map |

### How the Pieces Connect

```
+--------------------------------------------------+
|                     Godot Engine                  |
|                                                   |
|  +------------+      +------------------------+  |
|  | Events.gd  |<---->| NetworkManager.gd      |  |
|  | (signal bus)|      | (host/join/peer mgmt)  |  |
|  +-----+------+      +----------+-------------+  |
|        |                         |                |
|        v                         v                |
|  +------------+      +------------------------+  |
|  | Game Scene |      | ENetMultiplayerPeer    |  |
|  | Manager    |      | (transport layer)      |  |
|  +--+----+----+      +------------------------+  |
|     |    |                                        |
|     v    v                                        |
|  +------+ +-------+ +----------+ +--------+      |
|  |Player| |Enemy  | |Projectile| |Effects |      |
|  +------+ +-------+ +----------+ +--------+      |
|     |                                             |
|     +-- ServerSync (position/health -> all peers) |
|     +-- InputSync  (input -> server)              |
+--------------------------------------------------+
```

**Data flow summary:**
1. Each client reads local input and writes to their `InputSync` (MultiplayerSynchronizer)
2. The server reads all players' `InputSync` data and runs authoritative physics
3. The server writes authoritative state (position, health, velocity) to `ServerSync`
4. `ServerSync` replicates state to all clients automatically
5. Entity spawns/despawns flow through `MultiplayerSpawner` nodes

---

## 2. Project Structure

```
/game/
+-- project.godot                          # Godot project config, autoloads, input map
+-- scenes/
|   +-- lobby.tscn                         # Host/join UI screen
|   +-- game.tscn                          # Main gameplay scene with level geometry
|   +-- player.tscn                        # Player entity (CharacterBody2D)
|   +-- enemy.tscn                         # Enemy entity (CharacterBody2D)
|   +-- projectile.tscn                    # Bullet entity (Area2D)
+-- scripts/
|   +-- autoloads/
|   |   +-- network_manager.gd             # Singleton: ENet host/join, peer lifecycle
|   |   +-- events.gd                      # Singleton: signal bus (all game events)
|   +-- lobby.gd                           # Lobby UI logic (host/join/start)
|   +-- game_manager.gd                    # Spawning players/enemies, game state
|   +-- player.gd                          # Player movement, shooting, stamina, fatigue
|   +-- enemy.gd                           # Enemy AI (chase nearest player), health
|   +-- projectile.gd                      # Bullet movement, collision, lifetime
+-- assets/
    +-- placeholder/                       # (Future) colored rectangle textures
```

### File Responsibilities

| File | Responsibility | Runs On |
|------|---------------|---------|
| `network_manager.gd` | Create/join server, emit connection events | All peers |
| `events.gd` | Central signal bus for all game events | All peers |
| `lobby.gd` | UI button handlers, display join code, trigger scene change | All peers |
| `game_manager.gd` | Spawn players/enemies, manage entity containers | Server only (spawning) |
| `player.gd` | Read input (local peer), apply physics (server), sync state | Split authority |
| `enemy.gd` | Chase nearest player, take damage, die | Server only (logic) |
| `projectile.gd` | Move in direction, detect hits, auto-destroy | All peers (movement), Server (hits) |

---

## 3. Scene Tree Diagrams

### lobby.tscn

```
Lobby (Control) [script: lobby.gd]
+-- VBoxContainer
    +-- TitleLabel (Label) .............. "Drew's Co-op Game"
    +-- HostButton (Button) ............. "Host Game"
    +-- JoinContainer (HBoxContainer)
    |   +-- IPInput (LineEdit) .......... placeholder: "Enter IP address"
    |   +-- JoinButton (Button) ......... "Join Game"
    +-- StatusLabel (Label) ............. connection status text
    +-- StartButton (Button) ............ "Start Game" (hidden until 2+ players)
```

Node names use `%UniqueNameAccess` pattern for `@onready` references in lobby.gd.

### game.tscn

```
Game (Node2D) [script: game_manager.gd]
+-- Level (Node2D)
|   +-- Floor (StaticBody2D) ........... pos (600, 600)
|       +-- CollisionShape2D ........... RectangleShape2D 1200x32
|       +-- ColorRect .................. Gray 1200x32 (visual)
+-- Players (Node2D) ................... Container for player instances
+-- Enemies (Node2D) ................... Container for enemy instances
+-- Projectiles (Node2D) ............... Container for projectile instances
+-- Effects (Node2D) ................... Container for ability effects (future)
+-- PlayerSpawner (MultiplayerSpawner)
|   spawnable: player.tscn
|   spawn_path: ../Players
+-- EnemySpawner (MultiplayerSpawner)
|   spawnable: enemy.tscn
|   spawn_path: ../Enemies
+-- ProjectileSpawner (MultiplayerSpawner)
|   spawnable: projectile.tscn
|   spawn_path: ../Projectiles
+-- UI (CanvasLayer)
    +-- HUD (Control)
        +-- HealthLabel (Label) ......... "Health: 100"
        +-- StaminaBar (ProgressBar) .... value: 100
        +-- WaveLabel (Label) ........... "Wave: 1"
```

### player.tscn

```
Player (CharacterBody2D) [script: player.gd]
+-- CollisionShape2D ................... RectangleShape2D 32x64
+-- ColorRect .......................... 32x64, Blue (host) or White (client)
+-- Camera2D ........................... enabled=false (activated for local player)
+-- ShootPoint (Marker2D) .............. pos (20, 0) — projectile spawn origin
+-- ServerSync (MultiplayerSynchronizer)
|   authority: server (peer 1)
|   replicates: position, velocity, health
+-- InputSync (MultiplayerSynchronizer)
    authority: owning peer (set via player_id setter)
    replicates: input_move_dir, input_shoot, input_jump,
                input_sprint, input_melee, input_ability, input_super
```

### enemy.tscn

```
Enemy (CharacterBody2D) [script: enemy.gd]
+-- CollisionShape2D ................... RectangleShape2D 48x48
+-- ColorRect .......................... 48x48, Red (0.9, 0.15, 0.15)
+-- Hurtbox (Area2D) ................... For projectile hit detection
|   +-- CollisionShape2D ............... RectangleShape2D 48x48
+-- MultiplayerSynchronizer
    authority: server (peer 1)
    replicates: position, health
```

### projectile.tscn

```
Projectile (Area2D) [script: projectile.gd]
+-- CollisionShape2D ................... RectangleShape2D 8x8
+-- ColorRect .......................... 8x8, Yellow (1.0, 0.95, 0.2)
```

---

## 4. Networking Architecture

### 4.1 Host-Authoritative Model

The game uses a **host-authoritative** (also called "listen server") model:

```
+---------------------+                  +---------------------+
|   HOST (peer_id=1)  |   ENet (UDP)     |   CLIENT (peer_id=N)|
|                     |<================>|                     |
| - Runs game logic   |                  | - Sends input       |
| - Spawns entities   |                  | - Receives state    |
| - Processes combat  |                  | - Renders game      |
| - Validates actions |                  | - Plays locally     |
| - Is also a player  |                  |                     |
+---------------------+                  +---------------------+
```

**Key rules:**
- The host (peer_id = 1) is the **authority** for all game state
- Each client is the authority for **only their own input**
- Clients never modify game state directly; they send input, the server decides outcomes
- Enemy AI, damage calculations, spawning, and death all run on the server only

### 4.2 Dual MultiplayerSynchronizer Pattern

Every player entity has **two** MultiplayerSynchronizer nodes with different authorities:

```
Player Node
|
+-- ServerSync (MultiplayerSynchronizer)
|   Authority: Server (peer 1)
|   Direction: Server -> All Clients
|   Properties: position, velocity, health
|   Purpose: Authoritative game state
|
+-- InputSync (MultiplayerSynchronizer)
    Authority: Owning Peer
    Direction: Owning Client -> Server
    Properties: input_move_dir, input_shoot, input_jump,
                input_sprint, input_melee, input_ability, input_super
    Purpose: Client input replication
```

**Why two synchronizers?**
- `ServerSync` pushes authoritative state FROM the server TO all clients
- `InputSync` pushes input FROM the owning client TO the server
- This separation ensures clients can only affect their own input, not game state
- The server reads `InputSync` values and applies physics in `_physics_process()`

**Authority assignment flow:**
1. `game_manager.gd` instantiates a player and adds it to the `Players` container
2. After adding to the tree, it sets `player.player_id = peer_id`
3. The `player_id` setter calls `$InputSync.set_multiplayer_authority(peer_id)`
4. `ServerSync` keeps default authority (server/peer 1)

### 4.3 MultiplayerSpawner Setup

Three MultiplayerSpawner nodes in `game.tscn` handle entity replication:

| Spawner | Spawnable Scene | Spawn Path | What It Does |
|---------|----------------|------------|-------------|
| `PlayerSpawner` | `player.tscn` | `../Players` | When server adds a child to `Players`, all clients auto-create the same node |
| `EnemySpawner` | `enemy.tscn` | `../Enemies` | When server adds a child to `Enemies`, all clients auto-create the same node |
| `ProjectileSpawner` | `projectile.tscn` | `../Projectiles` | When server adds a child to `Projectiles`, all clients auto-create the same node |

**Spawning flow:**
1. Server calls `$Players.add_child(player_instance, true)` (the `true` forces a readable name)
2. `MultiplayerSpawner` detects the new child and replicates the spawn to all clients
3. Clients instantiate the same scene with the same node name
4. `MultiplayerSynchronizer` nodes begin syncing properties

**Node naming is critical:** Each spawned entity MUST have a unique name (we use `str(peer_id)` for players and `"Enemy_%d" % enemy_id` for enemies). Duplicate names cause silent replication failures.

### 4.4 RPC Usage Guidelines

| Annotation | Who Can Call | Delivery | Use For |
|-----------|-------------|----------|---------|
| `@rpc("authority", "reliable")` | Only the authority node | Guaranteed | State changes, death, ability activation |
| `@rpc("authority", "unreliable")` | Only the authority node | May drop | Position updates (if not using synchronizers) |
| `@rpc("authority", "call_local")` | Authority, also runs locally | Guaranteed | Actions server needs to see locally too |
| `@rpc("any_peer", "reliable")` | Any peer | Guaranteed | Client requests to server (scene change, etc.) |
| `@rpc("any_peer", "unreliable")` | Any peer | May drop | Client position hints (not used in current design) |

**Current golden path approach:** We use `MultiplayerSynchronizer` for state replication instead of manual RPCs wherever possible. RPCs are reserved for one-shot events and actions.

### 4.5 Entity Replication Flow

```
CLIENT A (owner)         SERVER (host)           CLIENT B (other)
     |                       |                        |
     | [press "shoot"]       |                        |
     |                       |                        |
     | InputSync replicates  |                        |
     | input_shoot=true ---->|                        |
     |                       |                        |
     |                 [_physics_process()]            |
     |                 reads input_shoot               |
     |                 calls _fire_projectile()        |
     |                 adds projectile to              |
     |                 $Projectiles container           |
     |                       |                        |
     |    ProjectileSpawner replicates spawn           |
     |<--[projectile appears]-+-[projectile appears]-->|
     |                       |                        |
     |                 [projectile hits enemy]         |
     |                 enemy.take_damage()             |
     |                 enemy health -> 0               |
     |                 enemy.queue_free()              |
     |                       |                        |
     |    Spawner detects removal                      |
     |<--[enemy disappears]--+-[enemy disappears]----->|
     |                       |                        |
     |    Events.enemy_died.emit()                    |
     |                       |                        |
```

### 4.6 Networking Gotchas

1. **Do NOT call `set_multiplayer_authority()` in `_enter_tree()`** -- The node is not fully configured yet. Use `_ready()` or an exported property setter instead.

2. **Use unique node names for all spawned entities.** If two nodes have the same name under the same parent, `MultiplayerSpawner` will fail silently or produce "has_node is true" errors.

3. **Connect multiplayer signals BEFORE setting `multiplayer.multiplayer_peer`.** The `peer_connected` signal fires immediately upon connection; if you connect after, you miss it.

4. **Use `"reliable"` for state changes, `"unreliable"` only for position/velocity.** Dropping a death event or ability activation causes desyncs.

5. **Do NOT use `change_scene_to_packed()` during active multiplayer.** It destroys all nodes including multiplayer infrastructure. Instead, manage scene transitions by adding/removing nodes from the tree. (Exception: lobby-to-game transition works because it happens before gameplay starts.)

6. **Both test instances must use the same Godot version** or connections silently fail with no error message.

7. **`MultiplayerSpawner` only replicates `add_child()` calls from the server.** If a client tries to spawn, nothing happens on other peers.

8. **Set `player_id` AFTER `add_child()`, not before.** The `$InputSync` node path isn't available until the node is in the tree.

9. **`queue_free()` on the server automatically propagates** through `MultiplayerSpawner` -- you don't need to RPC the removal.

10. **Autoloads are local to each peer.** `Events.gd` signals fire only on the local machine. If the server emits `Events.enemy_died`, clients do NOT hear it unless you explicitly RPC the notification or use a synchronizer.

---

## 5. Gameplay Systems

### 5.1 Player Movement

| Parameter | Value | Notes |
|-----------|-------|-------|
| Run speed | 170 px/s | "Between medium and slow" -- deliberate, positioning matters |
| Sprint speed | 250 px/s | With stamina drain |
| Gravity | 900 px/s^2 | Snappy fall, not floaty |
| Jump velocity | -320 px/s | Modest single jump |
| Jump style | Single jump only | No double jump |

Movement is processed on the **server only** in `_server_process()`:
```gdscript
var current_speed := SPRINT_SPEED if is_sprinting else RUN_SPEED
velocity.x = input_move_dir * current_speed
velocity.y += GRAVITY * delta
move_and_slide()
```

### 5.2 Sprint Stamina System

| Parameter | Value |
|-----------|-------|
| Max stamina | 100 |
| Drain rate | 30/s (while sprinting) |
| Regen rate | 20/s (while not sprinting) |
| Sprint condition | `input_sprint AND stamina > 0 AND moving` |

Stamina drains while sprinting and regenerates when not sprinting. The player cannot sprint while standing still. When stamina hits 0, the player drops to run speed. The UI shows a `ProgressBar` for stamina.

### 5.3 Jump Fatigue System

| Parameter | Value |
|-----------|-------|
| Window | 2.0 seconds |
| Threshold | 3 jumps within the window |
| Penalty | 15% velocity reduction per fatigued jump |
| Max penalty | 50% (clamped) |

The system tracks timestamps of recent jumps. When a player makes 3+ jumps within 2 seconds, subsequent jumps are weaker:

```
Jump 1: 100% velocity (-320)
Jump 2: 100% velocity (-320)
Jump 3: 100% velocity (-320)   <-- threshold reached
Jump 4:  85% velocity (-272)   <-- 1 fatigue stack
Jump 5:  70% velocity (-224)   <-- 2 fatigue stacks
Jump 6:  55% velocity (-176)   <-- 3 fatigue stacks
Jump 7+: 50% velocity (-160)   <-- clamped at 50%
```

Jump fatigue is tracked on the **server** (since all physics runs there). The `_jump_timestamps` array is pruned each jump to remove entries older than the 2-second window.

### 5.4 Shooting System

| Parameter | Value |
|-----------|-------|
| Tap cooldown | 0.3s |
| Auto-fire rate | 0.12s between shots |
| Auto-fire delay | 0.4s hold before auto-fire starts |
| Projectile speed | 400 px/s |
| Projectile lifetime | 3.0s |
| Projectile damage | 1 |

**Tap + Hold behavior:**
1. **Tap:** Press and release shoot -- fires one shot, 0.3s cooldown before next shot
2. **Hold:** Hold shoot for 0.4s -- transitions to auto-fire mode, fires at 0.12s intervals
3. **Release:** Releasing resets hold timer and exits auto-fire mode

```
Time: 0.0s    0.3s    0.4s    0.52s   0.64s   0.76s
      |        |       |       |       |       |
      [TAP]   [can     [AUTO-  [FIRE]  [FIRE]  [FIRE] ...
      FIRE    tap      FIRE
      1 shot  again]   START]
```

### 5.5 Melee Attack

Melee is bound to `K` / Xbox X / PS Square. In the golden path, the melee input is read and synced via `InputSync` but **no melee logic is implemented yet**. This is a placeholder for Lane B (Combat) to build out.

### 5.6 Enemy Behavior (Merge Conflict)

| Parameter | Value |
|-----------|-------|
| Health | 3 |
| Speed | 50 px/s |
| AI | Chase nearest living player |
| Size | 48x48 pixels |

**Behavior loop (server only):**
1. Find nearest living, visible player in the "players" group
2. Move toward that player at `speed` px/s
3. If no valid target, stop moving

**Death (golden path):** When health reaches 0, the enemy emits `Events.enemy_died` and calls `queue_free()`. The split mechanic is NOT implemented in the golden path -- `clean_kill` is always `false`.

### 5.7 Merge Conflict Split Mechanic (Lane Design -- Not in Golden Path)

When implemented by Lane B, the split mechanic will work as follows:

```
Normal Kill                        Clean Kill (Git Revert)
+----------+                       +----------+
| Tier 0   |  normal shot          | Tier 0   |  Git Revert beam
| (full)   | ------> SPLITS        | (full)   | ------> DISSOLVES
+----------+    |                   +----------+    (no children)
           +----+----+
      +----+--+ +----+--+
      |Tier 1 | |Tier 1 |  normal shot
      |(med)  | |(med)  | ------> SPLITS
      +-------+ +-------+    |
                         +----+----+
                    +----+--+ +----+--+
                    |Tier 2 | |Tier 2 |
                    |(small)| |(small)| ------> DIES (no split)
                    +-------+ +-------+
```

- Tier 0 (full size): splits into 2x Tier 1 on normal kill
- Tier 1 (medium): splits into 2x Tier 2 on normal kill
- Tier 2 (smallest): dies without splitting on any kill
- Git Revert (clean kill): dissolves enemy at any tier without splitting
- The `enemy_split` event carries `parent_id`, `child_ids`, and `positions`

---

## 6. Event / Signal Flow

All events are defined in `events.gd` (autoload singleton `Events`). See `/docs/interfaces/game_events.md` for the complete contract.

### Key Scenario: Player Shoots Enemy

```
[Client]                    [Server]                     [All Peers]

1. Player presses shoot
2. InputSync replicates
   input_shoot=true ------->
                            3. _server_process() reads
                               input_shoot, fires projectile
                            4. Projectile added to
                               $Projectiles container
                                                         5. ProjectileSpawner
                                                            replicates spawn
                            6. Projectile._on_body_entered()
                               detects enemy collision
                            7. enemy.take_damage(1, player_id)
                            8. enemy.health -= 1
```

### Key Scenario: Enemy Dies

```
[Server]                                    [All Peers]

1. enemy.health reaches 0
2. enemy._die(killed_by)
3. Events.enemy_died.emit(
     enemy_id, killed_by, false)
   (local signal on server only)
4. enemy.queue_free()
                                            5. MultiplayerSpawner detects
                                               removal, removes on clients
```

**Important:** `Events.enemy_died` only fires on the server. If clients need to react (e.g., play death animation, update score UI), the server must either:
- Use an RPC to notify clients, or
- Sync a "death" state via MultiplayerSynchronizer before `queue_free()`

### Key Scenario: Wave Clears (Future -- Lane B)

```
[Server]
1. Last enemy in wave dies
2. GameManager detects enemy count = 0
3. Events.wave_cleared.emit(wave_number)
4. Brief pause timer
5. Events.wave_started.emit(wave_number + 1, enemy_count)
6. Spawn new enemies
```

### Full Event Reference

| Event | Emitter | Payload | Listeners |
|-------|---------|---------|-----------|
| `player_joined` | NetworkManager, GameManager | `(player_id, spawn_position)` | GameManager, UI |
| `player_left` | NetworkManager | `(player_id)` | GameManager |
| `player_died` | Player | `(player_id, position)` | Networking, UI |
| `player_respawned` | GameManager | `(player_id, position)` | Networking, UI |
| `enemy_spawned` | GameManager | `(enemy_id, enemy_type, position)` | Networking |
| `enemy_died` | Enemy | `(enemy_id, killed_by, clean_kill)` | Networking, UI |
| `enemy_split` | Enemy (future) | `(parent_id, child_ids, positions)` | Networking, UI |
| `ability_activated` | Player (future) | `(player_id, ability, position, direction)` | Networking, UI |
| `wave_started` | GameManager (future) | `(wave_number, enemy_count)` | Networking, UI |
| `wave_cleared` | GameManager (future) | `(wave_number)` | Networking, UI |
| `connection_established` | NetworkManager | `(peer_id, is_host)` | Lobby, UI |
| `connection_lost` | NetworkManager | `(peer_id, reason)` | Lobby, UI |

---

## 7. Input Handling

### 7.1 Input Map

All actions are defined in `project.godot` under `[input]`. Each action has keyboard AND controller bindings so both work with zero extra code.

| Action | Keyboard Primary | Keyboard Alt | Controller | Godot Axis/Button |
|--------|-----------------|-------------|------------|-------------------|
| `move_left` | A | Left Arrow | Left Stick Left | Axis 0, value -1.0 |
| `move_right` | D | Right Arrow | Left Stick Right | Axis 0, value 1.0 |
| `jump` | Space | W | A (Xbox) / Cross (PS) | Button 0 |
| `shoot` | J | Left Mouse | Right Trigger | Axis 7, value 1.0 |
| `melee` | K | -- | X (Xbox) / Square (PS) | Button 2 |
| `sprint` | Left Shift | -- | Left Stick Click | Button 7 |
| `ability` | L | Right Mouse | Left Trigger | Axis 6, value 1.0 |
| `super` | E | Middle Mouse | (not yet mapped) | -- |

### 7.2 Input Reading

Input is read using Godot's action system in `_gather_input()`:

```gdscript
input_move_dir = Input.get_axis("move_left", "move_right")  # Returns -1.0 to 1.0
input_jump     = Input.is_action_just_pressed("jump")
input_sprint   = Input.is_action_pressed("sprint")
input_shoot    = Input.is_action_pressed("shoot")            # Held for auto-fire
input_melee    = Input.is_action_just_pressed("melee")
input_ability  = Input.is_action_just_pressed("ability")
input_super    = Input.is_action_just_pressed("super")
```

### 7.3 InputSync Relay to Server

```
+----------------+         +-------------------+         +------------------+
| Client (owner) |         | InputSync         |         | Server           |
|                |         | (MultiplayerSync) |         |                  |
| _gather_input()|-------->| input_move_dir    |-------->| _server_process()|
|  reads gamepad |         | input_shoot       |         |  applies physics |
|  reads keyboard|         | input_jump        |         |  moves character |
|                |         | input_sprint      |         |  fires bullets   |
|                |         | input_melee       |         |  checks fatigue  |
|                |         | input_ability     |         |                  |
|                |         | input_super       |         |                  |
+----------------+         +-------------------+         +------------------+
```

The `InputSync` MultiplayerSynchronizer's authority is set to the owning peer. This means:
- Only the owning client can write to these properties
- The server reads them each `_physics_process()` tick
- Other clients also receive them (for potential local prediction, though not implemented in golden path)

### 7.4 `is_action_just_pressed` Over the Network

**Gotcha:** `Input.is_action_just_pressed()` returns `true` for exactly one frame. The `InputSync` synchronizer replicates at the network tick rate, which may be different from the physics frame rate. This means a "just pressed" event could be missed by the server if it happens between network ticks.

**Current approach:** For the golden path, this is acceptable. For production, Lane A should consider either:
- Using an RPC for one-shot actions (jump, melee, ability, super)
- Or buffering "just pressed" flags until the server acknowledges them

---

## 8. Entity Schema

All networked entities follow the schemas defined in `/docs/interfaces/entity_schema.md`.

### Player Entity

| Field | Type | Sync Mode | Synced Via | Description |
|-------|------|----------|-----------|-------------|
| `player_id` | int | Init | MultiplayerSpawner (node name) | Matches peer_id |
| `position` | Vector2 | Continuous | ServerSync | World position |
| `velocity` | Vector2 | Continuous | ServerSync | Movement vector |
| `health` | int | Continuous | ServerSync | Current HP (max 100) |
| `stamina` | float | OnChange | (local only currently) | Sprint stamina (max 100) |
| `input_move_dir` | float | Continuous | InputSync | -1.0 to 1.0 |
| `input_shoot` | bool | Continuous | InputSync | Shoot button held |
| `input_jump` | bool | Continuous | InputSync | Jump just pressed |
| `input_sprint` | bool | Continuous | InputSync | Sprint held |
| `input_melee` | bool | Continuous | InputSync | Melee just pressed |
| `input_ability` | bool | Continuous | InputSync | Ability just pressed |
| `input_super` | bool | Continuous | InputSync | Super just pressed |

### Enemy Entity (Merge Conflict)

| Field | Type | Sync Mode | Synced Via | Description |
|-------|------|----------|-----------|-------------|
| `enemy_id` | int | Init | Script variable | Unique ID (starts at 1000) |
| `position` | Vector2 | Continuous | MultiplayerSynchronizer | World position |
| `health` | int | Continuous | MultiplayerSynchronizer | Current HP (default 3) |
| `speed` | float | Init | Script constant | Movement speed (50 px/s) |

### Projectile Entity

| Field | Type | Sync Mode | Description |
|-------|------|----------|-------------|
| `direction` | Vector2 | Init | Normalized direction vector |
| `speed` | float | Init | 400 px/s |
| `damage` | int | Init | 1 |
| `owner_id` | int | Init | Player who fired it |

### ID Generation Rules

| Entity Type | ID Range Start | Generator |
|-------------|---------------|-----------|
| Players | peer_id (assigned by Godot) | ENet |
| Enemies | 1000+ | `_next_enemy_id` in game_manager.gd |
| Projectiles | Random (randi) | Inline in player.gd |
| Powerups | 50000+ (future) | game_manager.gd |
| Effects | 100000+ (future) | game_manager.gd |

---

## 9. Phase 2/3 Extension Points

### Adding New Enemy Types

1. Create a new scene (e.g., `enemy_context_rot.tscn`) with `CharacterBody2D` root
2. Create a script with the same interface as `enemy.gd`: `take_damage(amount, from_player_id)`, `health`, `enemy_id`
3. Add a `MultiplayerSynchronizer` for position/health
4. Register the scene in `EnemySpawner._spawnable_scenes` in `game.tscn`
5. Update `game_manager.gd` to spawn the new type with the correct `enemy_type` string
6. Emit `Events.enemy_spawned` with the new type name

### Adding New Abilities

1. Create an ability component script (e.g., `git_revert.gd`)
2. Add it as a child node under the Player (or under an `AbilityManager` node)
3. Read `input_ability` from the parent player's synced input
4. Implement cooldown logic, spawn the ability effect scene
5. Emit `Events.ability_activated` with ability name and parameters

### Adding Weapon Pickups

1. Create a `weapon_pickup.tscn` scene (Area2D with collision)
2. On pickup collision (server only), swap the player's active ability nodes
3. Create new projectile variants (e.g., `projectile_spread.tscn`, `projectile_laser.tscn`)
4. Register new projectile scenes in `ProjectileSpawner._spawnable_scenes`

### Adding an Inventory System

1. Create an `InventoryComponent` node that attaches to the player
2. Add inventory fields to the player's `ServerSync` replication config
3. Use `Events.powerup_collected` to trigger inventory changes
4. Add UI elements to the HUD for inventory display

### Adding the Role System (Striker / Engineer)

1. Define role configurations as resources or dictionaries
2. On player spawn, assign a role and configure ability nodes accordingly
3. Striker: damage abilities, enemy weak point reveals
4. Engineer: defense placement, healing, cooldown management
5. Role selection happens in the lobby before game start

### Host Migration Considerations (Phase 2)

Host migration is complex. The approach:
1. Periodically snapshot full game state on all peers (via `game_state_sync` event)
2. When host disconnects, the lowest peer_id becomes new host
3. New host rebuilds the scene tree from the last snapshot
4. All other clients reconnect to the new host
5. Resume from snapshot state

This requires serializable game state and is NOT in scope for Phase 1.

---

## 10. Golden Path vs Full Game

### What the Golden Path Includes

| Feature | Status |
|---------|--------|
| Host/join lobby with IP code | Done |
| 2-player networking (ENet) | Done |
| Player movement (run, sprint, jump) | Done |
| Sprint stamina (drain/regen) | Done |
| Jump fatigue system | Done |
| Tap + hold auto-fire shooting | Done |
| Input synced via MultiplayerSynchronizer | Done |
| Server-authoritative physics | Done |
| One test enemy (Merge Conflict) | Done |
| Enemy chases nearest player | Done |
| Projectile hits kill enemy | Done |
| MultiplayerSpawner replication | Done |
| Keyboard + controller input bindings | Done |
| Placeholder colored rectangles | Done |
| Basic HUD (health, stamina, wave label) | Done |

### What Lanes Will Add

| Feature | Lane | Priority |
|---------|------|----------|
| Merge Conflict split mechanic | Lane B (Combat) | High |
| Git Revert ability (clean kill beam) | Lane B (Combat) | High |
| Clear Context super (co-op AOE) | Lane B (Combat) | High |
| Melee attack implementation | Lane B (Combat) | Medium |
| Wave system (5 waves) | Lane B (Combat) | High |
| Win/lose conditions | Lane B (Combat) | High |
| Damage/death/respawn system | Lane B (Combat) | High |
| Powerup drops from kills | Lane B (Combat) | Medium |
| Scoreboard / kill counter | Lane B (Combat) | Medium |
| Lag compensation / client prediction | Lane A (Networking) | Medium |
| Host migration | Lane A (Networking) | Low (Phase 2) |
| Reconnect on disconnect | Lane A (Networking) | Medium |
| 16-bit pixel art sprites | Lane C (Art) | High |
| Level tileset (side-scrolling platforms) | Lane C (Art) | High |
| UI polish (health bars, cooldown indicators) | Lane C (Art) | Medium |
| Animations (run, jump, shoot, die) | Lane C (Art) | High |
| Sound effects and music | Lane C (Art) | Low (after golden path) |

---

## 11. Setup Instructions

### Prerequisites

- **Godot 4.4+** installed
  - macOS: `/Applications/Godot.app` or `/opt/homebrew/bin/godot`
  - Download from [godotengine.org](https://godotengine.org/download)

### Opening the Project

1. Clone the repository:
   ```bash
   git clone https://github.com/McSchnizzle/drew-coop-game.git
   cd drew-coop-game
   ```

2. Open Godot and import the project at `/game/project.godot`

3. Or from the command line:
   ```bash
   /Applications/Godot.app/Contents/MacOS/Godot --path game/
   # or
   /opt/homebrew/bin/godot --path game/
   ```

### Running Two Instances for Testing

**Method 1: Two editor instances (recommended for development)**

1. Open a terminal and run the first instance:
   ```bash
   /opt/homebrew/bin/godot --path /path/to/repo/game/
   ```
2. Click "Host Game" in the lobby
3. Note the IP address displayed

4. Open a second terminal and run:
   ```bash
   /opt/homebrew/bin/godot --path /path/to/repo/game/
   ```
5. Enter the IP address and click "Join Game"
6. On the host, click "Start Game"

**Method 2: Export and run builds**

1. Export two copies of the game (Project > Export)
2. Run both executables
3. Host on one, join on the other

**Method 3: Use Godot's built-in debug multiple instances**

1. In the editor, go to Debug > Customize Run Instances
2. Set to 2 instances
3. Press F5 to run both
4. Host on one window, join on the other using `127.0.0.1`

### Verifying the Setup

After both players connect and start the game:
- [ ] Both players appear as colored rectangles (blue = host, white = client)
- [ ] Both players can move with A/D, jump with Space
- [ ] Sprint works with Shift (drains stamina bar)
- [ ] Shooting with J fires yellow projectiles
- [ ] Red enemy chases the nearest player
- [ ] Shooting the enemy 3 times kills it
- [ ] Both players see the enemy disappear

---

## 12. Known Limitations

### Intentionally Not Implemented (Golden Path Scope)

1. **No split mechanic** -- Enemies die without splitting regardless of how they are killed
2. **No abilities** -- Git Revert and Clear Context inputs are read but have no effect
3. **No melee** -- Melee input is read but has no effect
4. **No wave system** -- Only one enemy spawns; no wave progression
5. **No win/lose conditions** -- Game runs indefinitely
6. **No respawn** -- Dead players stay dead until the game is restarted
7. **No real art** -- All entities are colored rectangles
8. **No animations** -- No sprite animations, no state machine
9. **No sound** -- No sound effects or music
10. **No UI beyond basics** -- Health label, stamina bar, and wave label only

### Technical Limitations

1. **No client-side prediction** -- Players see their character with a full round-trip delay. This is noticeable on high-latency connections but acceptable for local/LAN play.

2. **`is_action_just_pressed` may be missed** -- One-frame inputs synced via MultiplayerSynchronizer can be dropped between network ticks. Production should use RPCs for one-shot actions.

3. **No lag compensation** -- Projectile hit detection runs on the server using server-side positions. A client who "clearly hit" an enemy on their screen may miss due to latency.

4. **Events are local only** -- `Events.gd` signals only fire on the machine that emits them. Cross-peer event propagation requires explicit RPCs or synchronizers.

5. **Stamina is not synced** -- The `stamina` field is tracked on the server but not included in the `ServerSync` replication config. Other clients don't see each other's stamina (only the local HUD uses it).

6. **No scene transition sync** -- The lobby uses `change_scene_to_file()` which only works because it happens before gameplay. During gameplay, scene changes must be managed manually.

7. **Single floor platform** -- The level has only one flat floor (1200x32 at y=600). No platforms, walls, or level boundaries.

8. **No entity limit** -- Nothing prevents spawning unlimited enemies or projectiles. Lane B should implement wave budgets and projectile pooling.

9. **Projectile naming uses `randi()`** -- There is a small chance of name collision. Production should use the `projectile_id` counter from `entity_schema.md` (starts at 10000).

---

## Appendix A: Autoload Registration

These are registered in `project.godot` under `[autoload]`:

| Autoload Name | Script Path | Purpose |
|---------------|------------|---------|
| `Events` | `res://scripts/autoloads/events.gd` | Central signal bus |
| `NetworkManager` | `res://scripts/autoloads/network_manager.gd` | Hosting, joining, peer management |

Both are prefixed with `*` in `project.godot` to indicate they are autoloads.

---

## Appendix B: Placeholder Colors

| Entity | Color | RGB |
|--------|-------|-----|
| Player 1 (Host) | Blue | (0.2, 0.4, 1.0) |
| Player 2+ (Client) | White | (1.0, 1.0, 1.0) |
| Enemy (Merge Conflict) | Red | (0.9, 0.15, 0.15) |
| Projectile | Yellow | (1.0, 0.95, 0.2) |
| Floor/Platforms | Gray | (0.5, 0.5, 0.5) |

---

## Appendix C: Physics Constants Quick Reference

```gdscript
# Movement
const RUN_SPEED: float        = 170.0   # px/s
const SPRINT_SPEED: float     = 250.0   # px/s
const GRAVITY: float          = 900.0   # px/s^2
const JUMP_VELOCITY: float    = -320.0  # px/s (negative = up)

# Sprint Stamina
const SPRINT_STAMINA_MAX: float   = 100.0
const SPRINT_STAMINA_DRAIN: float = 30.0   # per second
const SPRINT_STAMINA_REGEN: float = 20.0   # per second

# Jump Fatigue
const JUMP_FATIGUE_WINDOW: float    = 2.0   # seconds
const JUMP_FATIGUE_THRESHOLD: int   = 3     # jumps before penalty
const JUMP_FATIGUE_PENALTY: float   = 0.15  # 15% per fatigued jump

# Shooting
const SHOOT_COOLDOWN_TAP: float  = 0.3    # seconds
const SHOOT_COOLDOWN_AUTO: float = 0.12   # seconds
const AUTO_FIRE_DELAY: float     = 0.4    # seconds hold before auto

# Projectile
const PROJECTILE_SPEED: float   = 400.0   # px/s
const PROJECTILE_LIFETIME: float = 3.0    # seconds
const PROJECTILE_DAMAGE: int     = 1

# Enemy (Merge Conflict)
const ENEMY_HEALTH: int   = 3
const ENEMY_SPEED: float  = 50.0  # px/s
```
