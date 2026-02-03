# Agent Prompt: Lane B — Combat

Copy this entire prompt when starting a new agent session for Lane B work.

---

## Context

You are working on **Lane B: Combat** for a 2-player co-op game built in Godot 4.

**Project repo:** https://github.com/McSchnizzle/drew-coop-game
**Branch:** `lane-b/combat`
**Your folder:** `/game/lane_b_combat/` — you own this folder exclusively

## Your Responsibilities

1. Player movement and shooting
2. Git Revert ability (short-range beam, clean kill, cooldown)
3. Clear Context super (zone AOE, co-op combo mechanic)
4. Merge Conflict enemy (splits on normal kill, clean kill prevents split)
5. Wave spawning system
6. Win/lose conditions
7. Damage and death systems

## Critical Rules

### DO NOT MODIFY these files/folders:
- `/game/lane_a_networking/` — owned by Lane A
- `/game/lane_c_art/` — owned by Lane C
- `/docs/interfaces/game_events.md` — interface contract (propose changes only)
- `/docs/interfaces/entity_schema.md` — interface contract (propose changes only)

### You MUST:
- Read `/docs/interfaces/game_events.md` before writing any event-related code
- Read `/docs/interfaces/entity_schema.md` before writing any entity-related code
- Update `/game/lane_b_combat/LANE_STATUS.md` at the end of your session
- Use the exact event names and payload structures defined in the contracts
- Emit events for anything networking needs to replicate

### If you need an interface change:
1. Do NOT modify the interface files directly
2. Document your proposed change in `LANE_STATUS.md` under "Interface Change Proposals"
3. Continue work with a temporary workaround if possible
4. The change will be reviewed at the next checkpoint

## Phase 1 Scope

- Side-scrolling movement (left/right, jump)
- One weapon: normal shot (causes Merge Conflicts to split)
- Git Revert: short-range beam, clean kill, cooldown (TBD seconds)
- Clear Context: zone AOE, solo = partial, both players = full effect, long cooldown
- Merge Conflict enemy: 3 size tiers, splits on normal kill, smallest tier doesn't split
- Wave system: ~10 waves, each wave harder
- Win: survive all waves
- Lose: both players dead at same time

## Events You Emit

- `player_died`
- `player_respawned`
- `enemy_spawned`
- `enemy_died`
- `enemy_split`
- `ability_activated`
- `ability_ready`
- `clear_context_combo`
- `wave_started`
- `wave_cleared`
- `game_won`
- `game_lost`

## Events You Listen To

- `player_joined` (from Lane A)
- `player_left` (from Lane A)
- `player_input` (from Lane A)
- `connection_established` (from Lane A)
- `connection_lost` (from Lane A)

## At End of Session

Update `/game/lane_b_combat/LANE_STATUS.md` with:
- What you completed
- What's in progress
- Any blockers or interface proposals
- Known issues
- Recommended next steps

## Key Files to Reference

- `/docs/game-spec-drew.md` — full game spec
- `/docs/interfaces/game_events.md` — event contract
- `/docs/interfaces/entity_schema.md` — entity contract
- `/game/lane_b_combat/LANE_STATUS.md` — your status file
