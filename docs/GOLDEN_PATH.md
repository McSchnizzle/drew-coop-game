# Golden Path: Walking Skeleton

> Build this BEFORE splitting into parallel lanes.
> This gives all agents a working reference to build on.

## Goal

Prove the full loop works end-to-end with minimal features:
- Networking works
- Players appear on both screens
- Basic movement and shooting works
- One enemy spawns and can be killed

## Acceptance Criteria

- [ ] Player 1 can host a game (lobby screen with join code)
- [ ] Player 2 can join using the code
- [ ] Both players see each other on screen
- [ ] Both players can move (left/right, jump)
- [ ] Both players can shoot (basic projectile)
- [ ] One enemy spawns (placeholder Merge Conflict)
- [ ] Enemy moves toward players
- [ ] Shooting enemy kills it (no split mechanic yet)
- [ ] When enemy dies, both players see it

## What This Is NOT

- No Git Revert ability yet
- No Clear Context super yet
- No split mechanic yet
- No waves yet
- No win/lose conditions yet
- No real art (colored rectangles are fine)
- No UI beyond basic health display

## Implementation Notes

### Folder Structure
Build directly in `/game/` root, not in lanes:
```
/game/
├── project.godot
├── main.tscn              # Main scene
├── scenes/
│   ├── lobby.tscn         # Host/join UI
│   ├── game.tscn          # Main game scene
│   ├── player.tscn        # Player entity
│   └── enemy.tscn         # Enemy entity
├── scripts/
│   ├── network_manager.gd # Lobby + connection
│   ├── game_manager.gd    # Game state
│   ├── player.gd          # Player logic
│   └── enemy.gd           # Enemy logic
└── interfaces/
    ├── events.gd          # Signal bus (from contracts)
    └── schemas.gd         # Entity classes (from contracts)
```

### Key Technical Decisions
- Use Godot's `@rpc` annotations for network calls
- Use `multiplayer.get_unique_id()` for player IDs
- Host is peer_id 1, authority for game state
- Use `MultiplayerSpawner` for entity replication

### Testing
1. Export two builds (or run two editor instances)
2. First instance: Host
3. Second instance: Join
4. Verify all acceptance criteria

## After Golden Path

Once all acceptance criteria pass:
1. Commit to `main`
2. Create lane branches from `main`:
   - `git checkout -b lane-a/networking`
   - `git checkout -b lane-b/combat`
   - `git checkout -b lane-c/art`
3. Lanes now have working code to enhance
4. Begin parallel development
