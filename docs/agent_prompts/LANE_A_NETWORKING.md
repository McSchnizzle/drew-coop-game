# Agent Prompt: Lane A — Networking

Copy this entire prompt when starting a new agent session for Lane A work.

---

## Context

You are working on **Lane A: Networking** for a 2-player co-op game built in Godot 4.

**Project repo:** https://github.com/McSchnizzle/drew-coop-game
**Branch:** `lane-a/networking`
**Your folder:** `/game/lane_a_networking/` — you own this folder exclusively

## Your Responsibilities

1. Lobby system (host/join via code)
2. Player connection and disconnection handling
3. Replicating entity state across the network
4. Input forwarding from client to host
5. Game state sync from host to client

## Critical Rules

### DO NOT MODIFY these files/folders:
- `/game/lane_b_combat/` — owned by Lane B
- `/game/lane_c_art/` — owned by Lane C
- `/docs/interfaces/game_events.md` — interface contract (propose changes only)
- `/docs/interfaces/entity_schema.md` — interface contract (propose changes only)

### You MUST:
- Read `/docs/interfaces/game_events.md` before writing any event-related code
- Read `/docs/interfaces/entity_schema.md` before writing any entity-related code
- Update `/game/lane_a_networking/LANE_STATUS.md` at the end of your session
- Use the exact event names and payload structures defined in the contracts
- Use host-authoritative model (host runs game logic, clients send input)

### If you need an interface change:
1. Do NOT modify the interface files directly
2. Document your proposed change in `LANE_STATUS.md` under "Interface Change Proposals"
3. Continue work with a temporary workaround if possible
4. The change will be reviewed at the next checkpoint

## Phase 1 Scope

- 2 players only (host + 1 client)
- Host is authority (no host migration yet)
- Basic replication: player position, enemy position, projectiles
- No client-side prediction (Phase 2)

## Events You Emit

- `player_joined`
- `player_left`
- `player_input`
- `connection_established`
- `connection_lost`
- `game_state_sync`

## Events You Listen To

- `player_died` (from Lane B)
- `player_respawned` (from Lane B)
- `enemy_spawned` (from Lane B)
- `enemy_died` (from Lane B)
- `enemy_split` (from Lane B)
- `ability_activated` (from Lane B)
- `wave_started` (from Lane B)
- `wave_cleared` (from Lane B)
- `game_won` (from Lane B)
- `game_lost` (from Lane B)

## At End of Session

Update `/game/lane_a_networking/LANE_STATUS.md` with:
- What you completed
- What's in progress
- Any blockers or interface proposals
- Known issues
- Recommended next steps

## Key Files to Reference

- `/docs/game-spec-drew.md` — full game spec
- `/docs/interfaces/game_events.md` — event contract
- `/docs/interfaces/entity_schema.md` — entity contract
- `/game/lane_a_networking/LANE_STATUS.md` — your status file
