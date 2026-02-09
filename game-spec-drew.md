# Product Requirements Document: Co-op Agent-Bot Shooter

**Working title:** TBD
**Pitch:** 2–4 players co-op against an army of "agent-bots" whose attacks are software failures made physical.

---

## 1. Target Experience

| Aspect | Decision |
|--------|----------|
| **Dimension** | 3D |
| **Camera/view** | Third-person (behind player) |
| **Game modes** | Campaign (story progression, keep progress) + Roguelite (fresh runs, permanent unlocks) |
| **Core emotion** | Panic + clutch teamwork |
| **Difficulty** | Challenging/punishing — deaths teach, victories feel earned |
| **Platforms** | Mac + Windows |
| **v0.1 target** | 1-2 weeks |

---

## 2. Tone & Art Direction

| Aspect | Decision |
|--------|----------|
| **Overall tone** | Serious/epic |
| **4th wall breaks** | Yes — game talks to players like developers |
| **Death messages** | Dev-themed |
| **Boss personality** | Mythic/epic — genuinely threatening |
| **Art style** | Blend of realistic, neon wireframe, and low-poly (evenly mixed) |
| **Readability rule** | Enemies must be readable at a glance (co-op chaos needs clarity) |

---

## 3. Core Gameplay Loop

1. Players enter a "facility" (data center / repo labyrinth / prompt-temple)
2. Swarms spawn (bots) + hazards appear (hallucinations, context rot)
3. Players complete objectives to weaken boss shield ("restore state", "pin dependencies", "write tests", etc.)
4. Boss fight: one named failure mode
5. Loot/unlocks: new "anti-bug" tools

---

## 4. Player Roles

Two roles designed for 2-player core experience:

| Role | Abilities |
|------|-----------|
| **Striker** | Damage abilities, reveals enemy weak points, counters hallucinations (combines Promptsmith + Debugger) |
| **Engineer** | Builds defenses/turrets, heals teammates, manages cooldowns (combines Architect + Ops) |

---

## 5. Enemy Design: Failure Weapons

| Enemy Type | Mechanic |
|------------|----------|
| **Context Rot** | Enemy projectiles scramble HUD/map; players must "re-anchor" at terminals |
| **Hallucination** | Fake doors, fake pickups, fake boss tells |
| **Merge Conflicts** | Enemies that split or combine unpredictably |
| **Dependency Hell** | Enemy auras that force loadout changes or disable certain weapon/ability types |
| **Unfinished Code** | Partial enemies that split into bugs unless "completed" (finish objective) |

**Excluded:**
- ~~Tech Debt / Lazy Shortcut~~
- ~~Rate Limits / 429s~~

---

## 6. Boss Design

| Aspect | Decision |
|--------|----------|
| **Style** | Puzzle + skill-check combined (learn the mechanic, execute under pressure) |
| **Tone** | Mythic/epic — real threats, dramatic encounters |

### Boss Ideas
- **Boss 1:** TBD
- **Mid boss:** Merge Conflict Hydra
- **Boss: Moltbook:** A living documentation dungeon; the map reshapes when you "curl" the wrong endpoint; win condition is restoring a heartbeat + making the "blank homepage" render again

---

## 7. Co-op Rules

| Aspect | Decision |
|--------|----------|
| **Players** | 2–4 |
| **Host/join flow** | One player hosts; others join via code/IP |
| **Friendly fire** | No |
| **Revives** | Timed (hold to revive, rescuer is vulnerable) |
| **Voice** | Out of scope (use Discord) |
| **Drop-in reconnect** | TBD |

---

## 8. Multiplayer Requirements

- 2–4 players
- Host/join flow: "One player hosts; others join via code/IP" (simple)
- Godot implementation uses its multiplayer API (ENet-based)

---

## 9. Recommended Tech Stack

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

## 10. Parallel Development Plan

Split into "mergeable lanes" with hard interfaces:

### Lane A — Networking + Game State
- Lobby/host/join
- Replicated entities (players/enemies/projectiles)
- Authoritative rules ("server decides")
- Lag handling: client prediction (v2)

### Lane B — Core Combat + Enemies
- Weapons, cooldowns
- Enemy behaviors + status effects (context rot, hallucination, etc.)
- Boss encounter scripting hooks

### Lane C — Narrative + Dialogue + Level Concepts (optional)
- Ink/Yarn story graphs
- Boss monologues, mission briefings
- "Tooltips as lore" writing

### Lane D — UI/UX + Juice (optional)
- HUD, damage/readability
- Animations, screenshake (tasteful), feedback
- Accessibility options

### Integration Contract (non-negotiable)
- A shared `GameEvents` spec: event names + payloads
- A shared `EntitySchema`: fields replicated over network
- A shared "Definition of Done" checklist per feature (host can run a scripted demo)

---

## 11. Drew's Gameplay Preferences

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
