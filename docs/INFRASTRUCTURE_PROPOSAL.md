# Infrastructure Proposal: Lobby Server, Error Streaming, and Auto-Update

> **Date:** 2026-02-15
> **For:** Drew (review and approval before implementation)
> **Context:** 2-4 player co-op shooter, Godot 4.6, GDScript, ENet networking, 2-person indie team

---

## 1. Executive Summary

We need three pieces of infrastructure to take the game from "works on LAN" to "works for real players": a dedicated server so players don't need port forwarding, error streaming so Claude can debug issues faster, and an auto-update system so players always have the latest build. The recommended approach costs $0/month, uses a Raspberry Pi on Drew's network with Cloudflare Tunnel for public access, reads Godot's existing log files for error streaming (zero setup), and distributes updates through GitHub Releases with an in-game version check. Total implementation effort is roughly 6-8 hours spread across three phases.

---

## 2. Recommended Stack

| Area | Choice | Why |
|------|--------|-----|
| **Game Server** | Raspberry Pi + Cloudflare Tunnel | $0/mo, full UDP support, ENet works as-is, hardware Drew already owns |
| **Lobby/Matchmaking** | Same Pi, built into the headless Godot server | No need for a separate service at this scale -- one box does everything |
| **Error Streaming** | Read Godot's existing log file + custom Logger autoload | Zero-cost, already works today, Logger adds timestamps and game context |
| **Auto-Update Distribution** | GitHub Releases | Free, already using GitHub, direct download links, no extra tools |
| **Version Manifest** | GitHub API (`/repos/:owner/:repo/releases/latest`) | Free, automatic, no manual version.json to maintain |
| **Version Gating** | In-game check at lobby connection time | Server rejects mismatched clients with a helpful error message |

---

## 3. System Flow

```
Game Launch
    |
    v
[Check GitHub API for latest release] ---(offline or up-to-date)---> [Show Lobby]
    |
    (outdated)
    |
    v
[Show "Update Available" banner with GitHub release link]
    |
    (player downloads update from GitHub)
    |
    v
[Show Lobby] ---(player clicks Host or Join)--->
    |
    +--- Host: Connect to dedicated server on Pi via ENet/UDP (through Cloudflare Tunnel)
    +--- Join: Enter server address or use hardcoded address, connect via ENet/UDP
    |
    v
[Server validates client version on connect]
    |
    +--- Version match: Player joins game
    +--- Version mismatch: Server sends rejection with update URL, client disconnects
    |
    v
[Game Session Running on Raspberry Pi]
    |
    (errors occur)
    |
    v
[Godot writes to log file / custom Logger writes to project dir]
    |
    v
[Drew asks Claude to read the log file for debugging]
```

---

## 4. Architecture Diagram

```
                         PLAYERS (2-4)
                     /    |    |    \
                    /     |    |     \
                ENet/UDP  connections
                  /       |    |      \
                 v        v    v       v
        +------------------------------------------+
        |     CLOUDFLARE TUNNEL (free)             |
        |     - Public hostname for the Pi         |
        |     - UDP passthrough to local network   |
        +------------------------------------------+
                         |
                         v
        +------------------------------------------+
        |     RASPBERRY PI (Drew's network, $0)    |
        |                                          |
        |  +------------------------------------+  |
        |  | Headless Godot Server              |  |
        |  | - Game logic (waves, enemies, etc) |  |
        |  | - Lobby management                 |  |
        |  | - Version gate on connect          |  |
        |  | - Port 7777 UDP (ENet)             |  |
        |  +------------------------------------+  |
        +------------------------------------------+

        +------------------------------------------+
        |        GITHUB (free)                     |
        |  - Source code                           |
        |  - Releases for game builds + downloads  |
        |  - API for in-game version checking      |
        +------------------------------------------+

   DEV MACHINE (Drew's Mac)
        |
        +-- Godot Editor
        |     |
        |     +-- Writes logs to:
        |         ~/Library/Application Support/Godot/
        |           app_userdata/drew-coop-game/logs/godot.log
        |
        +-- Custom Logger (autoload)
        |     |
        |     +-- Writes to: <project>/debug_errors.log
        |         (timestamps, backtraces, game state context)
        |
        +-- Claude Code
              |
              +-- Reads log files on demand for debugging
```

---

## 5. Lobby Server Design

### What It Runs

A single headless Godot export of the game project, running on the Raspberry Pi. This is not a separate codebase -- it is the same game project exported with the "Dedicated Server" export preset, which strips rendering, audio, and display. The server runs as both the game host and the lobby.

### How It Works

1. Export the game as a headless Linux ARM server binary (Godot's dedicated server export)
2. Copy to the Pi via `scp` or USB
3. Run with `./game --headless` on port 7777 (UDP)
4. Cloudflare Tunnel exposes port 7777 to a public hostname (e.g., `game.yourdomain.com`)
5. Players connect to the public hostname using the existing ENet networking code
6. The server acts as the authoritative host (same as current peer-to-peer host, but now on a dedicated machine)

### Deployment

```bash
# One-time Pi setup
ssh pi@raspberrypi
sudo apt update && sudo apt install -y unzip
mkdir -p ~/game-server

# Deploy a new build
scp game-server-linux-arm.zip pi@raspberrypi:~/game-server/
ssh pi@raspberrypi "cd ~/game-server && unzip -o game-server-linux-arm.zip && chmod +x game-server"

# Run (use systemd for auto-restart)
ssh pi@raspberrypi "sudo systemctl restart game-server"
```

A systemd unit file keeps the server running and auto-restarts on crash:

```ini
# /etc/systemd/system/game-server.service
[Unit]
Description=Game Server
After=network.target

[Service]
ExecStart=/home/pi/game-server/game-server --headless
WorkingDirectory=/home/pi/game-server
Restart=always
RestartSec=5
User=pi

[Install]
WantedBy=multi-user.target
```

### Cloudflare Tunnel Setup (Drew handles later)

Cloudflare Tunnel (formerly Argo Tunnel) gives the Pi a public hostname without port forwarding. Drew will configure this separately using `cloudflared` on the Pi. The tunnel forwards UDP traffic on port 7777 to the headless Godot server.

### Why Not a Separate Lobby Service?

At this scale (1 server, 2-4 players), a separate lobby/matchmaking service adds complexity for no benefit. The headless Godot server IS the lobby. Players connect, pick roles, and the game starts -- all through the same ENet connection.

---

## 6. Error Streaming Design

### Immediate (Zero Effort) -- Use Today

Godot already writes a log file every time the game runs:

```
~/Library/Application Support/Godot/app_userdata/drew-coop-game/logs/godot.log
```

This file contains all `print()` output, `push_error()`, `push_warning()`, and engine errors with full GDScript backtraces. To use it, just ask Claude to read it:

> "Read my Godot log and tell me what errors are happening"

For convenience, create a symlink into the project:

```bash
ln -s "$HOME/Library/Application Support/Godot/app_userdata/drew-coop-game/logs/godot.log" \
  /Users/drewdavid/coding-projects/multiplayer-game/godot.log
```

### Short-Term Upgrade -- Custom Logger Autoload

A custom autoload intercepts ALL engine errors and writes them to a file in the project directory with timestamps and game context:

```
game/scripts/autoloads/debug_logger.gd  -->  writes to  -->  <project>/debug_errors.log
```

**What changes in the game code:**
1. Add `debug_logger.gd` as a new autoload (Project Settings > Autoload)
2. That is it -- no other code changes needed

**What this adds over the raw log:**
- Timestamps on every error
- Game state context (current wave, player count, etc.)
- Writes to the project directory where Claude can easily find it
- Formatted for quick scanning

### What Does NOT Change

- No external services, no MCP servers, no Node.js dependencies
- Error streaming is purely local file-based
- Claude reads the file on demand -- there is no real-time streaming needed
- Works in both editor and exported builds (using `user://` path for exports)

---

## 7. Auto-Update Design

### Distribution: GitHub Releases

Builds are uploaded as release assets on GitHub. Each release is tagged with a version number.

```bash
# Export the game for each platform, then:
gh release create v0.4.2 \
  game/export/windows/game-windows.zip \
  game/export/linux/game-linux.zip \
  game/export/mac/game-mac.zip \
  --title "v0.4.2" \
  --notes "- Fixed turret targeting\n- New enemy type"
```

Players download from the GitHub Releases page. The `gh` CLI or a simple `deploy.sh` script handles creating releases.

### Version Checking: In-Game on Startup

On launch, the game makes an HTTP request to the GitHub API:

```
GET https://api.github.com/repos/drewdavid/multiplayer-game/releases/latest
--> { "tag_name": "v0.4.2", "html_url": "https://github.com/.../releases/tag/v0.4.2" }
```

If the local version differs, show a non-blocking banner in the lobby: "Update available! v0.4.2 -- click here to download." The game remains playable offline or on older versions for single-player testing, but the server will reject mismatched clients.

### Version Gating: At Server Connection

When a client connects to the dedicated server:

1. Server sends its version string to the client via RPC
2. Client compares against its own version
3. If mismatched, client shows an error: "Version mismatch! Server: 0.4.2, You: 0.4.1. Please update."
4. Client disconnects

This is implemented in `network_manager.gd` with a simple RPC exchange -- roughly 20 lines of code.

### What We Are NOT Building (Yet)

- **No custom launcher** -- GitHub Releases handles distribution. A Godot-native launcher is only worth building if you need players to always auto-update without visiting a website.
- **No PCK hot-patching** -- Full builds are simpler and more reliable.
- **No code signing** -- Start without it. Add macOS notarization ($99/year) and Windows signing later if direct-download numbers warrant it.
- **No delta patching** -- The game build is small enough (<100 MB) that full downloads are fine.

---

## 8. How They Work Together

### Integration Points

```
               GitHub API
          (/releases/latest)
                  |
                  v
 [Game Launch] --> [Version Check] --> [Lobby UI shows update banner if needed]
                                            |
                                            v
                                  [Player connects to Pi via Cloudflare]
                                            |
                                            v
                                  [Server validates version]
                                    /               \
                            (match)                (mismatch)
                             /                        \
                  [Join game]              [Reject with GitHub release URL]
```

**Update check happens before lobby join:** The version check is a non-blocking HTTP request that fires on game launch. By the time the player reaches the lobby screen, the check has completed and the banner is showing (if needed).

**Error streaming is independent:** The log file approach is purely a development tool. It works the same whether running locally or testing against the Pi server.

**Deploy flow ties them together:**
1. Make code changes
2. Export game (client builds + headless ARM server build)
3. Create GitHub Release with client build assets (`gh release create`)
4. Copy server build to Pi via scp
5. Restart server via systemd

This can be scripted into a single `./deploy.sh` command.

---

## 9. Implementation Priority

### Phase 1: Error Streaming (Do First)

**Why first:** Immediately improves debugging speed for everything else you build. Zero cost, minimal effort.

| Task | Effort |
|------|--------|
| Create symlink to Godot log file | 1 minute |
| Add log file path to CLAUDE.md / memory | 5 minutes |
| Add `debug_logger.gd` autoload | 30 minutes |

**Total: ~30 minutes**

### Phase 2: Dedicated Server on Raspberry Pi (Do Second)

**Why second:** This is the highest-value infrastructure change. Eliminates NAT/port-forwarding issues for all players.

| Task | Effort |
|------|--------|
| Create "Dedicated Server" export preset in Godot (Linux ARM) | 15 minutes |
| Set up Pi with headless Godot binary | 30 minutes |
| Install and configure Cloudflare Tunnel on Pi | 30 minutes |
| Create systemd service for auto-restart | 15 minutes |
| Update game client to connect to Cloudflare hostname | 15 minutes |
| Add version check RPC on connection | 30 minutes |
| Test 2-player game through tunnel | 30 minutes |

**Total: ~3 hours**

### Phase 3: Auto-Update System (Do Third)

**Why third:** Only matters once you have players downloading builds. Lower urgency than the server.

| Task | Effort |
|------|--------|
| Add `application/config/version` to Project Settings | 5 minutes |
| Add version check HTTP request on game startup (GitHub API) | 45 minutes |
| Add "Update Available" banner in lobby UI | 30 minutes |
| Add version mismatch rejection at server connection | 30 minutes |
| Write `deploy.sh` script (export + gh release + scp to Pi) | 30 minutes |

**Total: ~2.5 hours**

---

## 10. Risks and Tradeoffs

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Pi loses power or crashes | Low | Players cannot connect | Systemd auto-restart; UPS battery backup if needed |
| Drew's internet goes down | Low | Server unreachable | Fallback to P2P (current mode); Pi server is a convenience, not a requirement |
| Cloudflare Tunnel adds latency | Low | Slightly higher ping | Tunnel adds <5ms typically; acceptable for co-op (not competitive) |
| Godot ARM export issues | Medium | Can't run on Pi | Fall back to x86 mini PC or cheap VPS |
| GitHub API rate limiting (60 req/hr unauthenticated) | Low | Version check fails silently | Graceful degradation -- game is playable without the check |
| Log file gets large | Low | Slower to parse | Godot auto-rotates logs (max 5 files); custom logger can cap size |

### What We Are Choosing NOT To Do

| Decision | Why |
|----------|-----|
| **No paid hosting** | Pi + Cloudflare Tunnel is free and sufficient for this scale |
| **No separate lobby/matchmaking service** | One headless Godot instance does everything |
| **No WebSocket fallback** | ENet/UDP is correct for a shooter. Cloudflare Tunnel handles the NAT problem |
| **No itch.io / Steam** | GitHub Releases is simpler since we're already there. Add storefronts later |
| **No custom launcher with PCK hot-patching** | An in-game banner + GitHub link is sufficient |
| **No MCP server for error streaming** | Reading the log file directly is simpler |
| **No code signing** | $100-500/year cost. Add later when distribution scale warrants it |
| **No Docker** | Bare binary + systemd is simpler on a Pi |

---

## 11. Cost Estimate

### Monthly Recurring

| Item | Cost |
|------|------|
| Raspberry Pi (owned hardware) | $0 |
| Cloudflare Tunnel (free tier) | $0 |
| GitHub (free tier) | $0 |
| Error streaming | $0 |
| **Total** | **$0/mo** |

### One-Time (if not already owned)

| Item | Cost |
|------|------|
| Raspberry Pi 4/5 | $35-80 (if not already owned) |
| Domain name (optional, for nicer URLs) | ~$10/year |
| Apple Developer Program (macOS signing, optional, later) | $99/year |

---

## 12. Effort Estimate

| Piece | Complexity | Time Estimate | Dependencies |
|-------|-----------|---------------|-------------|
| Error streaming (symlink + memory) | **Trivial** | 5 minutes | None |
| Error streaming (custom Logger autoload) | **Small** | 30 minutes | None |
| Dedicated server export + Pi setup | **Medium** | 2-3 hours | Pi + Cloudflare account |
| Version gating RPC | **Small** | 30 minutes | Server running |
| In-game version check + update banner | **Small** | 1-2 hours | GitHub repo |
| Deploy script (`deploy.sh`) | **Small** | 30 minutes | All above |
| **Total** | | **~5-7 hours** | |

---

## Appendix: Future Upgrades (Not Recommended Now)

- **GodotSteam integration**: If you publish on Steam, replace the Pi + GitHub with Steam's free relay network and CDN. This is the eventual endgame for most indie games.
- **CI/CD pipeline**: GitHub Actions to auto-export and create releases on every tagged commit.
- **Multiple servers**: Run multiple Godot instances on the Pi (different ports) or add a second Pi.
- **Server browser**: A simple JSON listing active servers, served by the Pi's HTTP endpoint.
- **itch.io distribution**: Add as a secondary channel if you want a storefront page with delta patching.

---

## Next Steps

1. **Phase 1 starts now** -- set up error streaming (symlink + logger autoload)
2. Phase 2 when Drew has the Pi ready and Cloudflare configured
3. Phase 3 when the game is ready for outside players
