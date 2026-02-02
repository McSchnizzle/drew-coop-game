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
| **Objective** | Survival — waves of enemies, survive for X time or Y waves |
| **Combat** | Move + shoot (one weapon type), one active ability (same for both players) |
| **Super ability** | "Clear Context" — AOE that wipes out a large group of enemies, has cooldown |
| **Death** | Simple respawn or game over |
| **Networking** | Host/join via code/IP, basic replication working |
| **Art style** | 16-bit (SNES/Genesis era) |
| **Input** | Keyboard |

### Phase 2: Prove It's Fun
Shift to top-down perspective, add variety, roles, tuning, and first boss. Goal: Something worth showing to outside playtesters.

| Aspect | Decision |
|--------|----------|
| **Perspective** | 2D top-down with twin-stick controls |
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
| **Graphics approach** | Need to identify good asset sources or generation methods (neither dev is a graphic designer) |

---

## 4. Core Gameplay Loop

### Phase 1 Loop (Survival)
1. Players join a session (host/join via code)
2. Waves of enemies spawn
3. Players survive using weapons, abilities, and "Clear Context" super
4. Win condition: survive X waves or Y time

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

---

## 6. Enemy Design: Failure Weapons

### Phase 1 Enemy
| Enemy Type | Mechanic |
|------------|----------|
| **Merge Conflict** | Splits into 2 smaller enemies when killed with normal attack; requires "clean kill" (specific attack/ability) to destroy without splitting |

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
- Mono-repo, strict folders: `/game`, `/server (optional)`, `/docs`, `/tools`

---

## 11. Parallel Development Plan

Split into "mergeable lanes" with hard interfaces. Drew has ongoing input into design decisions.

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

**Lane C — Art + Assets (TBD)**
- 16-bit style sprites for players, enemies, projectiles
- Simple arena/level tileset
- Basic UI elements (health, cooldowns, wave counter)
- Approach TBD: asset packs, AI generation, or commissioned

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
- A shared `GameEvents` spec: event names + payloads
- A shared `EntitySchema`: fields replicated over network
- A shared "Definition of Done" checklist per feature (host can run a scripted demo)

---

## 12. Drew's Gameplay Preferences

- **Favorite co-op games:** Fortnite, Minecraft
- **What he enjoys:** Combat/survival tension primarily, building/creating secondarily

---

## References

- [Godot High-Level Multiplayer Docs](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
- [Godot Dedicated Server Export Guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html)
- [Ink Language (GitHub)](https://github.com/inkle/ink)
- [godot-ink Integration (GitHub)](https://github.com/paulloz/godot-ink)
- [Yarn Spinner (GitHub)](https://github.com/YarnSpinnerTool/YarnSpinner)
- [Nakama Server (GitHub)](https://github.com/heroiclabs/nakama)
- [Renet - Rust Networking (GitHub)](https://github.com/lucaspoffo/renet)
