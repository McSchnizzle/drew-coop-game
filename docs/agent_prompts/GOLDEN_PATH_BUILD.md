# Agent Prompt: Build the Golden Path (Walking Skeleton)

**Give this entire prompt to an AI coding agent to build the initial working game.**

---

## Your Mission

Build a minimal working co-op game in Godot 4 that proves the full loop works:
- Two players can connect
- Both players appear on screen and can move
- Basic shooting works
- One enemy spawns and can be killed

This is the "golden path" — a working foundation that future development will build on.

---

## Project Setup

**Repo:** https://github.com/McSchnizzle/drew-coop-game
**Clone and work on the `main` branch.**

The repo already has this structure:
```
/
├── game/           # Put the Godot project here
├── server/         # Ignore for now
├── docs/           # Reference docs (read these!)
└── tools/          # Ignore for now
```

---

## Step 1: Read the Reference Docs

Before writing code, read these files in the repo:

1. **`/docs/game-spec-drew.md`** — Full game spec, Phase 1 scope
2. **`/docs/interfaces/game_events.md`** — Event names and payloads you must use
3. **`/docs/interfaces/entity_schema.md`** — Entity fields and types you must use
4. **`/docs/GOLDEN_PATH.md`** — Acceptance criteria for this task

---

## Step 2: Create Godot Project

Initialize a new Godot 4 project in `/game/`:

```
/game/
├── project.godot
├── scenes/
│   ├── lobby.tscn         # Host/join UI
│   ├── game.tscn          # Main game scene
│   ├── player.tscn        # Player entity
│   ├── enemy.tscn         # Enemy entity (Merge Conflict)
│   └── projectile.tscn    # Basic bullet
├── scripts/
│   ├── autoloads/
│   │   ├── network_manager.gd   # Singleton: lobby, connections
│   │   └── events.gd            # Singleton: signal bus
│   ├── game_manager.gd          # Game state, spawning
│   ├── player.gd                # Player movement, shooting
│   ├── enemy.gd                 # Enemy behavior
│   └── projectile.gd            # Projectile logic
└── assets/
    └── placeholder/             # Colored rectangles for now
```

---

## Step 3: Implement Core Systems

### 3.1 Network Manager (Autoload)

`/game/scripts/autoloads/network_manager.gd`

Must handle:
- `host_game()` — Create server, generate join code (use port as code for simplicity)
- `join_game(code)` — Connect to host using code
- `_on_peer_connected(id)` — Emit `player_joined` event
- `_on_peer_disconnected(id)` — Emit `player_left` event

Use Godot's high-level multiplayer:
```gdscript
var peer = ENetMultiplayerPeer.new()
peer.create_server(port)  # For host
peer.create_client(ip, port)  # For client
multiplayer.multiplayer_peer = peer
```

### 3.2 Event Bus (Autoload)

`/game/scripts/autoloads/events.gd`

Define signals matching `/docs/interfaces/game_events.md`:
```gdscript
signal player_joined(player_id: int, spawn_position: Vector2)
signal player_left(player_id: int)
signal player_died(player_id: int, position: Vector2)
signal enemy_spawned(enemy_id: int, enemy_type: String, position: Vector2)
signal enemy_died(enemy_id: int, killed_by: int, clean_kill: bool)
# Add others as needed
```

### 3.3 Lobby Scene

`/game/scenes/lobby.tscn`

Simple UI:
- "Host Game" button → calls `NetworkManager.host_game()`, shows join code
- "Join Game" button + text input → calls `NetworkManager.join_game(code)`
- When both players connected, host can click "Start Game" → changes scene to game.tscn

### 3.4 Player Scene

`/game/scenes/player.tscn`

Structure:
- CharacterBody2D (root)
  - CollisionShape2D
  - Sprite2D (or ColorRect as placeholder)
  - Camera2D (only active for local player)

`/game/scripts/player.gd`

Must handle:
- Movement: left/right with A/D or arrow keys, jump with Space/W
- Shooting: shoot with J or Left Mouse, spawns projectile
- Sync: position replicated via `@rpc`
- Authority: use `set_multiplayer_authority()` so each player controls their own

```gdscript
# Example structure
func _ready():
    if is_multiplayer_authority():
        $Camera2D.make_current()

func _physics_process(delta):
    if is_multiplayer_authority():
        handle_input()
        move_and_slide()
        sync_position.rpc(global_position)

@rpc("any_peer", "unreliable")
func sync_position(pos: Vector2):
    if not is_multiplayer_authority():
        global_position = pos
```

### 3.5 Enemy Scene

`/game/scenes/enemy.tscn`

Structure:
- CharacterBody2D (root)
  - CollisionShape2D
  - Sprite2D (or ColorRect — different color than player)

`/game/scripts/enemy.gd`

Must handle:
- Movement: move toward nearest player
- Death: when health <= 0, emit `enemy_died` event, queue_free()
- Authority: host controls all enemies

```gdscript
var health: int = 3
var speed: float = 50.0

func _physics_process(delta):
    if multiplayer.is_server():
        var target = find_nearest_player()
        if target:
            var direction = (target.global_position - global_position).normalized()
            velocity = direction * speed
            move_and_slide()
            sync_position.rpc(global_position)

func take_damage(amount: int, from_player: int):
    health -= amount
    if health <= 0:
        Events.enemy_died.emit(get_instance_id(), from_player, false)
        queue_free()
```

### 3.6 Projectile Scene

`/game/scenes/projectile.tscn`

Structure:
- Area2D (root)
  - CollisionShape2D
  - Sprite2D (or ColorRect — small rectangle)

`/game/scripts/projectile.gd`

Must handle:
- Movement: travel in fired direction
- Collision: on hitting enemy, call `enemy.take_damage()`
- Cleanup: destroy after timeout or hitting something

### 3.7 Game Scene

`/game/scenes/game.tscn`

Structure:
- Node2D (root)
  - TileMapLayer or StaticBody2D platforms (basic level geometry)
  - Node2D "Players" (container for player instances)
  - Node2D "Enemies" (container for enemy instances)
  - Node2D "Projectiles" (container for projectile instances)
  - MultiplayerSpawner (for syncing entity spawns)

`/game/scripts/game_manager.gd`

Attached to root. Must handle:
- Spawning players when game starts (one per connected peer)
- Spawning one enemy (host only)
- Placeholder level geometry (floor, some platforms)

---

## Step 4: Configure Autoloads

In Godot Project Settings → Autoload:
- Add `NetworkManager` → `res://scripts/autoloads/network_manager.gd`
- Add `Events` → `res://scripts/autoloads/events.gd`

---

## Step 5: Test Acceptance Criteria

Run two instances of the game (export or two editor windows with different ports):

- [ ] Player 1 can host (sees join code)
- [ ] Player 2 can join using code
- [ ] Both players see each other on screen
- [ ] Both players can move (left/right, jump)
- [ ] Both players can shoot
- [ ] One enemy spawns when game starts
- [ ] Enemy moves toward players
- [ ] Shooting enemy kills it
- [ ] Both players see the enemy die

---

## Important Technical Notes

### Multiplayer Authority
- Host (peer_id 1) is authoritative for game state
- Each player is authoritative for their own input
- Host controls enemy logic and spawning

### RPC Annotations (Godot 4)
```gdscript
@rpc("any_peer", "reliable")    # Any peer can call, guaranteed delivery
@rpc("any_peer", "unreliable")  # Any peer can call, may drop (use for position)
@rpc("authority", "reliable")   # Only authority can call
@rpc("authority", "call_local") # Authority calls, also runs locally
```

### Node Paths with Multiplayer
Use `set_multiplayer_authority(peer_id)` on player nodes so each client controls their own player.

### Spawning Synced Entities
Use `MultiplayerSpawner` node to automatically replicate spawned scenes:
1. Add MultiplayerSpawner to game scene
2. Set spawn path to the container node (e.g., "Players")
3. Add spawnable scenes in the inspector
4. When host calls `container.add_child(player_instance)`, it auto-replicates

---

## Placeholder Art

Use ColorRect nodes with distinct colors:
- Player 1: Blue rectangle (32x64 pixels)
- Player 2: Green rectangle (32x64 pixels)
- Enemy: Red rectangle (48x48 pixels)
- Projectile: Yellow rectangle (8x8 pixels)
- Platforms: Gray rectangles

---

## What NOT to Build Yet

These are for later (lanes will add them):
- ❌ Git Revert ability
- ❌ Clear Context super
- ❌ Enemy split mechanic
- ❌ Wave system
- ❌ Win/lose conditions
- ❌ Real art/sprites
- ❌ UI beyond lobby
- ❌ Sound

---

## When Done

1. Verify all acceptance criteria pass
2. Commit with message: "Golden path complete: basic networked co-op working"
3. Push to `main`
4. Update `/docs/GOLDEN_PATH.md` — check off completed criteria

---

## If You Get Stuck

Common issues:
- **Players don't see each other:** Check MultiplayerSpawner config and authority settings
- **Movement not syncing:** Ensure `@rpc` functions are being called and received
- **Enemy not spawning on client:** Host must spawn, use MultiplayerSpawner
- **Connection fails:** Check port numbers match, no firewall blocking

If blocked, document the issue clearly and stop — don't hack around it.
