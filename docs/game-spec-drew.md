# Product Requirements Document: Co-op Agent-Bot Shooter

**Working title:** drew-coop-game
**Pitch:** 2–4 players co-op against an army of "agent-bots" whose attacks are software failures made physical.
**Repo:** https://github.com/McSchnizzle/drew-coop-game (private)

---

## 1. Development Phases

### Phase 1: Prove It Works (MVP)
Core combat + networking functional. Goal: Drew can play with one friend and confirm the tech works.

| Aspect | Decision |
|--------|----------|
| **Perspective** | 2D side-scrolling (Contra/Metal Slug style) |
| **Players** | 2 |
| **Enemy type** | Merge Conflict — splits into smaller enemies when killed wrong; requires specific attack to kill cleanly |
| **Objective** | Survival — survive all waves (e.g., 10 waves), each wave spawns more/faster enemies |
| **Combat** | Move + shoot (normal shot causes Merge Conflicts to split) |
| **Active ability** | "Git Revert" — short-range beam that dissolves enemies cleanly (no split), has cooldown |
| **Super ability** | "Clear Context" — zone clear AOE around player; solo = partial effect, both players activate together = full "garbage collection" wipe; long cooldown |
| **Death** | Simple respawn or game over |
| **Networking** | Host is authority — Player 1 hosts and runs game logic, Player 2 sends inputs, host sends state |
| **Level structure** | Scrolling level with boundaries — camera follows players, enemies spawn from sides/ahead |
| **Art style** | 16-bit (SNES/Genesis era) |
| **Input** | Keyboard |

### Phase 2: Prove It's Fun
Shift to top-down perspective, add variety, roles, tuning, and first boss. Goal: Something worth showing to outside playtesters.

| Aspect | Decision |
|--------|----------|
| **Perspective** | 2D top-down with twin-stick controls |
| **Networking** | Host authority + host migration (if host disconnects, another player becomes host) |
| **Roles** | Both roles functional (Striker + Engineer) with distinct abilities |
| **Enemies** | Multiple enemy types with varied behaviors |
| **Boss** | First boss encounter |
| **Input** | Keyboard + Xbox controller support |
| **Polish** | Tuning pass on combat feel and difficulty |

### Phase 3: Prove It's Complete
Full 3D, campaign/roguelite structure, content, and polish. Goal: Something releasable.

| Aspect | Decision |
|--------|----------|
| **Perspective** | Full 3D (first-person vs third-person TBD) |
| **Networking** | Peer-to-peer with reconciliation (each player runs simulation, sync differences) |
| **Modes** | Campaign mode with story progression + Roguelite mode with permanent unlocks |
| **Content** | Multiple bosses and levels |
| **Systems** | Full progression systems |
| **Polish** | Juice, accessibility options, full art pass |

---

## 2. Target Experience (Full Vision)

| Aspect | Decision |
|--------|----------|
| **Perspective progression** | Phase 1: 2D side-scrolling → Phase 2: 2D top-down twin-stick → Phase 3: Full 3D (first/third person TBD) |
| **Game style** | Campaign-oriented (movement beyond arena, level progression) |
| **Game modes** | Campaign + Roguelite (Phase 3) |
| **Core emotion** | Panic + clutch teamwork |
| **Difficulty** | Challenging/punishing — deaths teach, victories feel earned |
| **Platforms** | Mac + Windows |
| **Input** | Keyboard initially; Xbox controller support planned |

---

## 3. Tone & Art Direction

| Aspect | Decision |
|--------|----------|
| **Overall tone** | Serious/epic |
| **4th wall breaks** | Yes — game talks to players like developers |
| **Death messages** | Dev-themed |
| **Boss personality** | Mythic/epic — genuinely threatening |
| **Art style (Phase 1)** | 16-bit pixel art (SNES/Genesis era) — prioritize readability and fast iteration |
| **Art style (Later)** | TBD — may evolve based on Phase 1 feedback |
| **Readability rule** | Enemies must be readable at a glance (co-op chaos needs clarity) |
| **Graphics approach** | AI-generated sprites (Nano Banana Pro, GPT Imagen 1.5) with manual cleanup; prompts to be developed for consistent 16-bit style |

---

## 4. Core Gameplay Loop

### Phase 1 Loop (Wave Survival)
1. Players join a session (host/join via code)
2. Wave starts — Merge Conflict enemies spawn
3. Players clear the wave using normal shots, Git Revert, and Clear Context
4. Brief pause between waves, then next wave (more/faster enemies)
5. Win condition: survive all waves (e.g., 10 waves)
6. Lose condition: both players dead at same time

### Full Vision Loop (Phase 2+)
1. Players enter a "facility" (data center / repo labyrinth / prompt-temple)
2. Swarms spawn (bots) + hazards appear (hallucinations, context rot)
3. Players complete objectives to weaken boss shield ("restore state", "pin dependencies", "write tests", etc.)
4. Boss fight: one named failure mode
5. Loot/unlocks: new "anti-bug" tools

---

## 5. Player Roles (Phase 2+)

Two roles designed for 2-player core experience:

| Role | Abilities |
|------|-----------|
| **Striker** | Damage abilities, reveals enemy weak points, counters hallucinations (combines Promptsmith + Debugger) |
| **Engineer** | Builds defenses/turrets, heals teammates, manages cooldowns (combines Architect + Ops) |

**Saved for role specialization:**
- Chain reaction Git Revert (triggers clean kills in sequence, enemies dissolve one after another) — potential Striker signature ability

---

## 6. Enemy Design: Failure Weapons

### Phase 1 Enemy
| Enemy Type | Mechanic |
|------------|----------|
| **Merge Conflict** | Splits into 2 smaller enemies when killed with normal shot; "clean kill" with active ability destroys without splitting |

**Phase 1 combat loop:**
- Normal shot → enemy dies but splits into 2 smaller enemies
- "Git Revert" beam (active ability) → clean kill, enemy dissolves into code fragments, no split
- Risk/reward: Git Revert is short-range (must get close) and has cooldown
- Player tension: spend cooldown and risk getting close, or stay safe and deal with splits?
- "Clear Context" super (long cooldown) → zone AOE wipes nearby enemies
  - Solo activation = partial effect
  - Both players activate together = full "garbage collection" wipe
  - Co-op tension: coordinate timing for maximum impact

*Why this one first:* Clear cause-and-effect, easy to debug, classic side-scroller mechanic.

### Phase 2+ Enemies
| Enemy Type | Mechanic |
|------------|----------|
| **Context Rot** | Enemy projectiles scramble HUD/map; players must "re-anchor" at terminals |
| **Hallucination** | Fake doors, fake pickups, fake boss tells |
| **Dependency Hell** | Enemy auras that force loadout changes or disable certain weapon/ability types |
| **Unfinished Code** | Partial enemies that split into bugs unless "completed" (finish objective) |

*Note:* Context Rot deferred to Phase 2+ because HUD scrambling makes debugging difficult during early development.

**Excluded:**
- ~~Tech Debt / Lazy Shortcut~~
- ~~Rate Limits / 429s~~

---

## 7. Boss Design (Phase 2+)

| Aspect | Decision |
|--------|----------|
| **Style** | Puzzle + skill-check combined (learn the mechanic, execute under pressure) |
| **Tone** | Mythic/epic — real threats, dramatic encounters |

### Boss Ideas
- **Boss 1:** TBD
- **Mid boss:** Merge Conflict Hydra
- **Boss: Moltbook:** A living documentation dungeon; the map reshapes when you "curl" the wrong endpoint; win condition is restoring a heartbeat + making the "blank homepage" render again

---

## 8. Co-op Rules

| Aspect | Decision |
|--------|----------|
| **Players** | 2–4 |
| **Host/join flow** | One player hosts; others join via code/IP |
| **Friendly fire** | No |
| **Revives** | Timed (hold to revive, rescuer is vulnerable) |
| **Voice** | Out of scope (use Discord) |
| **Drop-in reconnect** | TBD |

---

## 9. Multiplayer Requirements

- 2–4 players
- Host/join flow: "One player hosts; others join via code/IP" (simple)
- Godot implementation uses its multiplayer API (ENet-based)

---

## 10. Recommended Tech Stack

### Engine + Networking
- **Godot Engine (Godot 4)** for native Mac/Windows app, fast iteration, and sane multiplayer API
- **Godot High-Level Multiplayer** (built on modified ENet) for 2–4 co-op without inventing netcode from scratch
- Godot supports running headless / dedicated server exports if needed later

### Narrative / Dialogue Tooling (pick one)
- **Ink + Inky editor** (great for branching narrative) with **godot-ink** integration
- OR **Yarn Spinner** with Godot port (beta/WIP)

### "If this gets big" Server Option (not needed for v1)
- **Heroic Labs Nakama** for accounts, matchmaking, persistence (skip for v1)

### Repo Structure
```
/
├── game/
│   ├── interfaces/           # Shared code contracts (sacred, coordinate changes)
│   ├── lane_a_networking/    # Lane A owns this folder
│   ├── lane_b_combat/        # Lane B owns this folder
│   ├── lane_c_art/           # Lane C owns this folder
│   └── main/                 # Integration point
├── server/                   # Dedicated server (Phase 2+ if needed)
├── docs/
│   ├── interfaces/           # Contract docs (game_events.md, entity_schema.md)
│   ├── agent_prompts/        # Copy these when starting agent sessions
│   └── CHECKPOINT_PROCESS.md # How to merge and integrate
└── tools/                    # Build scripts, asset pipeline
```

### Branch Strategy
- `main` — stable, integrated code only
- `lane-a/networking` — Lane A work
- `lane-b/combat` — Lane B work
- `lane-c/art` — Lane C work
- `integration/checkpoint-*` — temporary merge branches

---

## 11. Parallel Development Plan

Split into "mergeable lanes" with hard interfaces. Drew has ongoing input into design decisions.

### Pre-requisite: Golden Path
Before splitting into lanes, build a "walking skeleton" on `main` that proves the full loop:
- Host/join works
- Both players visible and moving
- Basic shooting works
- One enemy spawns and dies

See `/docs/GOLDEN_PATH.md` for acceptance criteria. Lanes branch from this working base.

### Phase 1 Lanes (MVP scope)

**Lane A — Networking Foundation**
- Lobby/host/join flow
- Player entity replication (position, health, actions)
- Enemy spawning synced across clients
- Projectile replication
- Basic "host is authority" model

**Lane B — Core Combat**
- Player movement + shooting (one weapon)
- One active ability (same for both players)
- "Clear Context" super ability with cooldown
- One enemy type with one behavior
- Damage/death/respawn system

**Lane C — Art + Assets**
- 16-bit style sprites for players, enemies, projectiles
- Simple level tileset (side-scrolling platform/arena)
- Basic UI elements (health, cooldowns, wave counter)
- Approach: AI-generated (Nano Banana Pro, GPT Imagen 1.5) with manual cleanup
- Asset list needed: player character, Merge Conflict enemy (+ split variants), projectiles, Git Revert beam, Clear Context effect, tiles, UI

### Phase 2+ Lanes (Full Vision)

**Lane A — Networking + Game State**
- Replicated entities (players/enemies/projectiles)
- Authoritative rules ("server decides")
- Lag handling: client prediction

**Lane B — Core Combat + Enemies**
- Weapons, cooldowns
- Enemy behaviors + status effects (context rot, hallucination, etc.)
- Boss encounter scripting hooks

**Lane C — Narrative + Dialogue + Level Concepts**
- Ink/Yarn story graphs
- Boss monologues, mission briefings
- "Tooltips as lore" writing

**Lane D — UI/UX + Juice**
- HUD, damage/readability
- Animations, screenshake (tasteful), feedback
- Accessibility options

### Integration Contract (non-negotiable)
- **Event contract:** `/docs/interfaces/game_events.md` — all events, payloads, emitters, listeners
- **Entity contract:** `/docs/interfaces/entity_schema.md` — all entity fields, types, sync behavior
- **Checkpoint process:** `/docs/CHECKPOINT_PROCESS.md` — how to merge lanes and handle interface changes
- **Agent prompts:** `/docs/agent_prompts/` — copy these when starting agent sessions
- **Lane status:** Each lane updates `LANE_STATUS.md` at end of session

---

## 12. Drew's Gameplay Preferences

- **Favorite co-op games:** Fortnite, Minecraft
- **What he enjoys:** Combat/survival tension primarily, building/creating secondarily

---

## 13. Drew's Decisions

*(This section will be filled in during Drew's first session)*

| Decision | Drew's Choice | Date |
|----------|---------------|------|
| Movement feel | TBD | |
| Player speed | TBD | |
| Jump style | TBD | |
| Shooting style | TBD | |
| Placeholder colors | TBD | |
| Test wave count | TBD | |
| Priority feel | TBD | |

---

## 14. Open Questions for Drew

> **Drew's First Session:** Use `/docs/agent_prompts/DREW_FIRST_SESSION.md` — this prompt will ask Drew these questions, record his answers, and then build the golden path.

These decisions are intentionally left open for Drew's input:

### Gameplay Feel (Asked in First Session)
- **Movement feel:** Floaty jumps (Mega Man) vs snappy/heavy (Contra)? → *First session Q1*
- **Player speed:** Fast/medium/slow running? → *First session Q2*
- **Jump style:** Single, double, or variable height? → *First session Q4*
- **Shooting style:** Tap, hold, or both? → *First session Q5*

### Difficulty & Tuning (Partially in First Session)
- **Wave count:** How many waves for first test? → *First session Q6*
- **Enemy speed/aggression:** How punishing should Merge Conflicts be? → *After first playtest*
- **Cooldown timing:** How long between Git Revert uses? Clear Context uses? → *After first playtest*

### Visual Style (Partially in First Session)
- **Placeholder colors:** What colors for players, enemies, projectiles? → *First session Q3*
- **Player character design:** What should the player look like? Human? Robot? Abstract code entity? → *Phase 1 art pass*
- **Color palette:** Dark/neon (cyberpunk)? Bright/colorful (arcade)? → *Phase 1 art pass*
- **Environment theme:** Server room? Abstract code space? Office building gone wrong? → *Phase 1 art pass*
- **Death/respawn visuals:** Pixelated explosion? Glitch effect? → *Phase 1 art pass*

### Sound Design (Later)
- **Sound direction:** Retro chiptune? Modern with retro flavor? → *After golden path*

### Lore & Personality (Later)
- **4th wall break style:** Snarky? Deadpan? Encouraging? → *Phase 2+*
- **Enemy personality:** Are Merge Conflicts menacing? Annoying? Tragic? → *Phase 2+*
- **Victory/defeat messages:** What does the game say when you win or lose? → *Phase 2+*

### Future Ideas (Phase 2+)
- **Which enemy type next:** Context Rot? Hallucination? Dependency Hell?
- **Role preference:** Does Drew want to play Striker or Engineer?
- **Boss concepts:** Any ideas for what the first boss should be?

---

## References

- [Godot High-Level Multiplayer Docs](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
- [Godot Dedicated Server Export Guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html)
- [Ink Language (GitHub)](https://github.com/inkle/ink)
- [godot-ink Integration (GitHub)](https://github.com/paulloz/godot-ink)
- [Yarn Spinner (GitHub)](https://github.com/YarnSpinnerTool/YarnSpinner)
- [Nakama Server (GitHub)](https://github.com/heroiclabs/nakama)
- [Renet - Rust Networking (GitHub)](https://github.com/lucaspoffo/renet)
