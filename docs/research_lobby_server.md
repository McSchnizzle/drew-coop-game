# Lobby / Dedicated Server Hosting Research

**Date:** 2026-02-15
**Context:** 2-4 player co-op shooter, Godot 4.6, GDScript, ENet (UDP) networking, currently peer-to-peer

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Railway.app](#railwayapp)
3. [Fly.io](#flyio)
4. [Hetzner / DigitalOcean (VPS)](#hetzner--digitalocean-vps)
5. [Godot-Specific Solutions](#godot-specific-solutions)
6. [Game Server Orchestrators](#game-server-orchestrators)
7. [Architecture Options](#architecture-options)
8. [ENet / UDP Specifics](#enet--udp-specifics)
9. [Pricing Comparison](#pricing-comparison)
10. [Recommendation](#recommendation)

---

## Executive Summary

**The core challenge:** ENet uses UDP, and most PaaS platforms (Railway, Render) do NOT support inbound UDP. This immediately narrows our options.

**Top 3 paths forward (ranked):**

| Rank | Option | Cost | Effort | Best For |
|------|--------|------|--------|----------|
| 1 | **Hetzner/DigitalOcean VPS + headless Godot** | $4-6/mo | Medium | Full control, ENet stays as-is |
| 2 | **GodotSteam relay** (if shipping on Steam) | Free | Low | Steam-only distribution |
| 3 | **Railway/Fly.io + WebSocket swap** | $5-7/mo | High | If VPS management is unwanted |

---

## Railway.app

### UDP Support: NO (inbound)
- Railway does **not** support inbound UDP traffic
- Outbound UDP is fine, but your game server needs to *receive* ENet packets
- Only HTTP, TCP (via TCP Proxy), and WebSocket are supported for inbound traffic
- Source: [Railway Networking Docs](https://docs.railway.com/networking)

### What Railway CAN Do
- **TCP Proxy**: Exposes non-HTTP services (databases, game servers) to the internet via TCP
  - Railway generates a proxy domain + port (e.g., `shuttle.proxy.rlwy.net:15140`)
  - Random load balancing across replicas
  - Works for game servers that use TCP-based protocols
- **WebSocket**: Supported natively through HTTP domains
- **Template available**: "Multiplayer Web Lobby" with Socket.IO + Redis

### If You Switched to WebSocket
- Godot 4 has `WebSocketMultiplayerPeer` as a drop-in replacement for `ENetMultiplayerPeer`
- **Major downside**: WebSocket is TCP-only, all RPCs become reliable (no unreliable channel)
- For a fast-paced shooter, this adds latency from TCP head-of-line blocking
- Source: [Godot High-Level Multiplayer Docs](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)

### Pricing
- **Trial**: $0 with $5 credits (30 days)
- **Hobby**: $5/mo (includes $5 usage credits)
- **Pro**: $20/mo
- Compute: ~$0.000278/vCPU-hour, ~$0.0139/GB-RAM-hour
- Egress: $0.05/GB
- Source: [Railway Pricing](https://railway.com/pricing)

### Verdict: NOT RECOMMENDED for ENet
Railway cannot receive UDP. You'd have to rewrite networking to WebSocket, which hurts shooter gameplay. However, Railway is excellent for a **separate matchmaking/lobby API** (HTTP REST or WebSocket) that coordinates players before they connect P2P or to a VPS game server.

---

## Fly.io

### UDP Support: YES (with dedicated IPv4)
- Fly.io supports UDP but **only with a dedicated IPv4 address** (not shared IPv4 or IPv6)
- Dedicated IPv4 costs $2/mo per address
- The Machines API supports both `tcp` and `udp` protocols with configurable port ranges
- Source: [Fly.io Networking Services](https://fly.io/docs/networking/services/)

### How It Works for Game Servers
- Use the Machines API to dynamically spin up headless Godot servers
- Each machine gets a dedicated IPv4 with UDP port allocation
- Port ranges configurable via `start_port` / `end_port`
- Machines are billed per-second and can be stopped when idle
- Regions available worldwide

### Pricing
- **No monthly fee** -- pay per use
- Compute: ~$0.0000015/s for shared-cpu-1x (256MB), roughly $1.94/mo if running 24/7
- Dedicated IPv4: $2/mo per address
- Egress: $0.02/GB (North America/Europe)
- A small game server (1 vCPU, 256MB) running 24/7 = ~$4/mo + $2 IPv4 = ~$6/mo
- Source: [Fly.io Pricing](https://fly.io/pricing/)

### Proven Godot Setup
- Community guide exists: [Deploying Godot UDP servers on Fly.io](https://zenn.dev/submax/articles/fly-udp-game-server-deployment-2024-01-08) (Japanese, but code is universal)
- Docker-based deployment using headless Godot 4.x
- Dynamic server creation via Machines API

### Verdict: VIABLE
Fly.io is the best PaaS option if you want UDP/ENet support without managing a raw VPS. The $2/mo dedicated IPv4 fee is the tradeoff. Good for dynamic scaling but slightly more complex than a plain VPS.

---

## Hetzner / DigitalOcean (VPS)

### Full UDP Support: YES
A plain VPS gives you complete control over networking -- UDP, TCP, any port.

### Hetzner
- **CAX11 (ARM)**: 2 vCPU, 4GB RAM, 40GB SSD -- **EUR 3.79/mo** (~$4.10/mo)
- **CX22 (Intel)**: 2 vCPU, 4GB RAM, 40GB SSD -- **EUR 5.49/mo** (~$5.95/mo)
- Unmetered 1 Gbps bandwidth (20TB included)
- Locations: Germany, Finland, USA (Ashburn, Hillsboro), Singapore
- NVMe storage, hourly billing
- Source: [Hetzner Cloud](https://www.hetzner.com/cloud/)

### DigitalOcean
- **Basic Droplet**: 1 vCPU, 1GB RAM -- **$6/mo**
- **Basic Droplet**: 1 vCPU, 2GB RAM -- **$12/mo**
- 500GB-1TB bandwidth included
- Per-second billing (as of 2026)
- Source: [DigitalOcean Droplet Pricing](https://docs.digitalocean.com/products/droplets/details/pricing/)

### Setup
1. Export Godot project as dedicated server (headless Linux x86_64 or ARM)
2. Upload binary to VPS
3. Open UDP port in firewall (e.g., port 7777)
4. Run with `--headless` flag
5. Optional: Docker container for easier deployment

### Verdict: BEST VALUE
A Hetzner CAX11 at $4/mo is the cheapest option with full UDP/ENet support. No networking protocol changes needed. You manage the server yourself (SSH, updates, etc.) but for a small indie game this is minimal overhead.

---

## Godot-Specific Solutions

### W4 Cloud
- Built by Godot's own networking developers (W4 Games)
- **One-click conversion** from P2P to headless authoritative server
- Multi-region, auto-scaling
- Open source under AGPL (self-host for free)
- Hosted SaaS pricing not publicly disclosed yet (Dev Tier requires invite)
- Source: [W4 Cloud](https://www.w4games.com/w4cloud), [W4 Cloud Docs](https://docs.w4.gd/)

**Assessment**: Most "Godot-native" option but pricing/availability is unclear. Worth watching. Self-hosting the open-source version on a Hetzner VPS is viable.

### Nakama (Heroic Labs)
- Open-source game server with Godot 4 SDK (GDScript)
- Features: matchmaking, lobbies, accounts, chat, leaderboards, storage
- Lobby → game handoff: players join matchmaker, get matched, then connect to game server
- Can relay messages (acts as authoritative server) or just do matchmaking
- Self-host for free or use Heroic Cloud (paid, pricing undisclosed)
- Source: [Nakama Godot Client](https://heroiclabs.com/docs/nakama/client-libraries/godot/), [GitHub](https://github.com/heroiclabs/nakama-godot)

**Assessment**: Excellent for matchmaking/lobby layer. Overkill if you just need "find players, connect them." Best used as a lobby service alongside a separate game server.

### GodotSteam (Steam Networking)
- If distributing on Steam, Steam's relay network handles everything:
  - NAT hole punching (automatic)
  - Relay fallback (no port forwarding needed)
  - Lobby creation/management via Steam API
  - `SteamMultiplayerPeer` integrates with Godot's high-level multiplayer API
- **Cost: Free** (included with Steamworks, requires $100 Steam Direct fee)
- No dedicated server needed -- Steam relays P2P traffic
- Source: [GodotSteam Lobbies](https://godotsteam.com/tutorials/lobbies/), [GodotSteam MultiplayerPeer](https://godotsteam.com/classes/multiplayer_peer/)

**Assessment**: If you're on Steam, this is the easiest path. Zero server costs, zero NAT issues. The `SteamMultiplayerPeer` is a drop-in replacement for `ENetMultiplayerPeer`.

---

## Game Server Orchestrators

### Hathora
- Server orchestration platform with Godot addon (GDScript)
- Dynamically spin up/down game server instances via API
- 14 global regions
- Pricing: $0.07/vCPU-hr on-demand, $0.02/vCPU-hr reserved
- No free tier currently advertised
- Source: [Hathora Gaming](https://hathora.dev/gaming), [Godot Asset](https://godotengine.org/asset-library/asset/3060)

**Assessment**: Designed for larger studios. Pricing is high for a small indie game (~$50/mo for a single always-on vCPU). Better suited for games that need dynamic scaling across many regions.

### Agones (Kubernetes-based)
- Open-source game server orchestration on Kubernetes
- Massive overkill for 2-4 player co-op with small player count
- Requires Kubernetes expertise

**Assessment**: Not appropriate for this project's scale.

---

## Architecture Options

### Option A: Pure P2P (Current) + Lobby Service
```
[Lobby Server (Railway/Fly.io)]  <-- HTTP/WebSocket -->  [Players]
         |
         | (match found, share host IP)
         v
[Player 1 as Host]  <-- ENet/UDP -->  [Player 2, 3, 4]
```
- Lobby server is lightweight (Node.js/Python, HTTP only)
- Once matched, players connect directly via ENet
- **Problem**: Host player needs port forwarding or NAT traversal

### Option B: Dedicated Game Server on VPS
```
[Lobby/Matchmaker]  <-- HTTP -->  [Players]
         |
         | (match found, share server IP:port)
         v
[Headless Godot on VPS]  <-- ENet/UDP -->  [All Players]
```
- VPS runs headless Godot with your game project
- No NAT issues (server has public IP)
- Anti-cheat: server is authoritative
- **Cost**: $4-6/mo for a single VPS handling multiple game sessions

### Option C: Steam Relay (Steam-only)
```
[Steam Matchmaking]  <-- Steam API -->  [Players]
         |
         | (lobby created)
         v
[Player 1 as Host]  <-- Steam Relay Network -->  [Player 2, 3, 4]
```
- Steam handles NAT traversal and relay
- Zero infrastructure cost
- **Limitation**: Steam-only distribution

### Option D: Hybrid (Recommended)
```
[Lightweight Lobby API on Railway]  <-- HTTP/WS -->  [Players]
         |
         | (match found)
         v
[Headless Godot on Hetzner VPS]  <-- ENet/UDP -->  [All Players]
```
- Railway hosts a small lobby/matchmaking API ($5/mo)
- Hetzner VPS runs headless Godot game servers ($4/mo)
- Total: ~$9/mo
- Clean separation of concerns

---

## ENet / UDP Specifics

### NAT Traversal Problem
- ENet is UDP-only. Players behind NAT (most home routers) can't host without port forwarding
- NAT hole punching works ~70-80% of the time (fails with symmetric NAT)
- Available Godot plugins: [HolePuncher](https://godotengine.org/asset-library/asset/608), [Rabid Hole Punch](https://godotengine.org/asset-library/asset/1052)
- Both require a small public "rendezvous" server

### Why a Dedicated Server Solves NAT
- Server has a public IP -- no NAT issues for any player
- All players connect outbound to the server (outbound UDP works through all NATs)
- This is the simplest reliable solution

### WebSocket Fallback (if needed)
- `WebSocketMultiplayerPeer` is a drop-in for `ENetMultiplayerPeer` in Godot 4
- TCP-only, adds latency, no unreliable channel
- **Not recommended for a shooter** but works for turn-based or slow-paced games
- Source: [Godot Multiplayer Docs](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)

### Headless Godot Server Setup
1. Create a "Dedicated Server" export preset in Godot
2. Target: Linux x86_64 (or ARM for Hetzner CAX)
3. This strips rendering, audio, etc. -- pure game logic
4. Run with `--headless` flag
5. Docker images available: [GodotServer-Docker](https://github.com/briancain/GodotServer-Docker)
6. Source: [Godot Dedicated Server Export Docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html)

---

## Pricing Comparison

| Platform | Monthly Cost | UDP Support | Effort | Notes |
|----------|-------------|-------------|--------|-------|
| **Hetzner CAX11** | $4.10 | YES | Medium | Best value, ARM VPS |
| **Hetzner CX22** | $5.95 | YES | Medium | x86 VPS |
| **DigitalOcean** | $6.00 | YES | Medium | Basic droplet |
| **Fly.io** | ~$6.00 | YES* | Medium-High | Needs dedicated IPv4 ($2/mo) |
| **Railway** | $5.00 | NO | Low | HTTP/TCP/WS only |
| **Render** | $7.00 | NO | Low | HTTP/TCP only |
| **GodotSteam** | $0 | N/A (relay) | Low | Steam-only, peer relayed |
| **W4 Cloud (self-host)** | $4-6 (VPS) | YES | Medium-High | Open source, host on own VPS |
| **Nakama (self-host)** | $4-6 (VPS) | YES | High | Powerful but complex |
| **Hathora** | ~$50+ | YES | Low | Overkill for small indie |

*Fly.io UDP requires dedicated IPv4 at $2/mo extra

---

## Recommendation

### For your project (2-4 player co-op shooter, small scale, ENet):

**Immediate / Cheapest Path:**
1. **Hetzner CAX11 VPS ($4/mo)** running headless Godot as a dedicated server
2. Players connect via ENet directly to the VPS IP
3. Simple lobby can be a static list or in-game server browser
4. Total cost: **$4/mo**

**If distributing on Steam:**
1. **GodotSteam relay ($0/mo)** -- swap `ENetMultiplayerPeer` for `SteamMultiplayerPeer`
2. Steam handles NAT, relay, lobbies
3. Total cost: **$0/mo** (after $100 Steam Direct fee)

**If you want separate lobby + game server (more polished):**
1. **Railway ($5/mo)** for a lightweight lobby/matchmaking API (Node.js or Python, HTTP/WebSocket)
2. **Hetzner CAX11 ($4/mo)** for headless Godot game server
3. Total cost: **$9/mo**

### What NOT to do:
- Don't rewrite networking from ENet to WebSocket just to use Railway/Render -- TCP adds unacceptable latency for a shooter
- Don't use Hathora/Agones -- massive overkill for 2-4 players
- Don't rely on NAT hole punching alone -- too unreliable for a good player experience
