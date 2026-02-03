# drew-coop-game

Co-op Agent-Bot Shooter — 2-4 players vs software failures made physical.

## Repo Structure

```
/
├── game/       # Godot 4 project
├── server/     # Dedicated server (Phase 2+ if needed)
├── docs/       # Design specs, documentation
└── tools/      # Build scripts, asset pipeline
```

## Phase 1 Scope

- 2 players, networked (host/join via code)
- 2D side-scrolling, 16-bit art style
- Wave-based survival (~10 waves)
- One enemy type: Merge Conflict (splits when killed normally)
- Abilities: Git Revert (clean kill), Clear Context (co-op AOE super)

See [docs/game-spec-drew.md](docs/game-spec-drew.md) for full spec.

## Tech Stack

- **Engine:** Godot 4
- **Networking:** Godot High-Level Multiplayer (ENet)
- **Platforms:** Mac + Windows
