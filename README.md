# drew-coop-game

Co-op Agent-Bot Shooter — 2-4 players vs software failures made physical.

## Repo Structure

```
/
├── game/
│   ├── interfaces/           # Shared code contracts
│   ├── lane_a_networking/    # Lane A: networking code
│   ├── lane_b_combat/        # Lane B: combat code
│   ├── lane_c_art/           # Lane C: art assets
│   └── main/                 # Integration point
├── server/                   # Dedicated server (Phase 2+)
├── docs/
│   ├── interfaces/           # Event + entity contracts
│   ├── agent_prompts/        # Prompts for AI agent sessions
│   └── CHECKPOINT_PROCESS.md # Integration process
└── tools/                    # Build scripts, asset pipeline
```

## Parallel Development

This project uses lane-based parallel development with AI coding agents.

- **Lane A:** Networking (lobby, replication, sync)
- **Lane B:** Combat (movement, abilities, enemies, waves)
- **Lane C:** Art + Assets (sprites, UI, effects)

See `docs/agent_prompts/` for lane-specific agent prompts.
See `docs/CHECKPOINT_PROCESS.md` for integration workflow.

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
