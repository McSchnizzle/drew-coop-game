# Agent Prompt: Lane C — Art + Assets

Copy this entire prompt when starting a new agent session for Lane C work.

---

## Context

You are working on **Lane C: Art + Assets** for a 2-player co-op game built in Godot 4.

**Project repo:** https://github.com/McSchnizzle/drew-coop-game
**Branch:** `lane-c/art`
**Your folder:** `/game/lane_c_art/` — you own this folder exclusively

## Your Responsibilities

1. 16-bit pixel art sprites (player, enemies, projectiles, effects)
2. Level tilesets for side-scrolling environment
3. UI elements (health bar, cooldown indicators, wave counter)
4. Visual effects (Git Revert beam, Clear Context AOE, enemy split/death)
5. Animation definitions
6. Asset organization and sprite sheets

## Critical Rules

### DO NOT MODIFY these files/folders:
- `/game/lane_a_networking/` — owned by Lane A
- `/game/lane_b_combat/` — owned by Lane B
- `/docs/interfaces/game_events.md` — interface contract (propose changes only)
- `/docs/interfaces/entity_schema.md` — interface contract (propose changes only)

### You MUST:
- Read `/docs/interfaces/entity_schema.md` for animation_state values
- Update `/game/lane_c_art/LANE_STATUS.md` at the end of your session
- Follow the 16-bit (SNES/Genesis) art style
- Ensure sprites are readable at a glance (co-op chaos needs clarity)
- Name assets consistently so other lanes can reference them

### If you need an interface change:
1. Do NOT modify the interface files directly
2. Document your proposed change in `LANE_STATUS.md` under "Interface Change Proposals"
3. Continue work with a temporary workaround if possible
4. The change will be reviewed at the next checkpoint

## Phase 1 Asset List

### Player Character
- Idle animation
- Run animation
- Jump animation (up, apex, fall)
- Shoot animation
- Git Revert ability animation
- Death animation

### Merge Conflict Enemy (3 sizes)
- Tier 0 (full size): walk, attack, die_normal (with split effect), die_clean
- Tier 1 (medium): same animations, smaller
- Tier 2 (smallest): same animations, smallest, no split on die_normal

### Projectiles
- Normal shot
- Git Revert beam (short-range, code dissolve effect)

### Effects
- Clear Context AOE (expanding ring, "garbage collection" visual)
- Enemy split effect (one enemy becomes two)
- Enemy clean death (dissolve into code fragments)
- Player death/respawn

### UI
- Health bar
- Git Revert cooldown indicator
- Clear Context cooldown indicator
- Wave counter ("Wave 3/10")
- Co-op combo indicator (when both players activate Clear Context)

### Environment
- Basic platform tileset
- Background layers (parallax if feasible)
- Spawn point indicators

## Art Direction

- **Style:** 16-bit pixel art (SNES/Genesis era)
- **Generation method:** AI-generated (Nano Banana Pro, GPT Imagen 1.5) with manual cleanup
- **Readability:** Enemies must be instantly distinguishable from background and players
- **Color palette:** TBD (open question for Drew — see game spec section 13)

## At End of Session

Update `/game/lane_c_art/LANE_STATUS.md` with:
- What you completed
- What's in progress
- Any blockers or interface proposals
- Known issues
- Recommended next steps

## Key Files to Reference

- `/docs/game-spec-drew.md` — full game spec (see section 13 for Drew's open questions)
- `/docs/interfaces/entity_schema.md` — animation_state values
- `/game/lane_c_art/LANE_STATUS.md` — your status file
