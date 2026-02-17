# Auto-Update System Research for Godot 4.6 Game

## Executive Summary

For a 2-person indie team distributing a Godot 4.6 co-op shooter with regular updates, the recommended approach is a **Godot-native launcher + PCK patching** system, hosted on **Cloudflare R2** (free tier), with **itch.io butler** as the primary distribution platform and **GitHub Releases** as a secondary/fallback host. Version gating should happen at the lobby connection level.

---

## 1. How Godot Exports Work (Background)

When you export a Godot game, it produces:
- **An executable** — a copy of the Godot export template binary (platform-specific)
- **A .pck file** — all game resources (scenes, scripts, textures, audio) packed into a single archive

You can choose to embed the PCK inside the executable (single file) or keep them separate. For an auto-update system, **keeping the PCK separate is critical** — you can update the PCK without touching the executable.

### PCK File Format
- Uncompressed archive with a file index (like a table of contents)
- Each entry has: file path, offset, size
- Fast read performance at runtime
- Can be created via the Export dialog ("Export PCK/Zip") or programmatically via `PCKPacker`

### Loading PCK Files at Runtime
```gdscript
# Load a resource pack — files inside override existing ones
var success = ProjectSettings.load_resource_pack("user://update.pck")

# With replace_files=false, existing files are NOT overridden
ProjectSettings.load_resource_pack("user://mod.pck", false)
```

**Key behaviors:**
- Files in the loaded PCK that share paths with existing resources **replace** them (unless `replace_files=false`)
- No error/exception if loading fails — you must validate manually
- Works at runtime, no restart needed for resource overrides
- Scripts loaded this way take effect when scenes using them are (re)loaded

---

## 2. Architecture Options

### Option A: Godot Launcher Project (RECOMMENDED)

A separate, minimal Godot project that:
1. Launches and shows a splash/loading screen
2. Checks a version endpoint for updates
3. Downloads the latest game PCK if needed
4. Loads the PCK via `ProjectSettings.load_resource_pack()`
5. Changes scene to the main game

**Pros:**
- Pure GDScript, no external dependencies
- Launcher is tiny (~5MB) and rarely needs updating
- Game updates are just PCK files (typically 20-80MB)
- Cross-platform with Godot's export templates
- Players always get the latest version

**Cons:**
- Two Godot projects to maintain (but launcher is simple)
- Requires internet on every launch (can cache last PCK as fallback)
- PCK-only updates can't change the engine binary

**Architecture:**
```
launcher/                    # Separate Godot project
  scenes/
    launcher.tscn            # Loading UI
  scripts/
    launcher.gd              # Version check + download + load PCK
    update_checker.gd        # HTTP version check logic

game/                        # Main game project (current)
  ...existing code...

server/
  version.json               # Hosted version manifest
```

**Launcher flow (pseudocode):**
```gdscript
extends Control

const VERSION_URL = "https://your-domain.com/version.json"
const PCK_URL_TEMPLATE = "https://your-domain.com/builds/game-v%s.pck"
const LOCAL_PCK = "user://game.pck"
const LOCAL_VERSION = "user://version.txt"

func _ready():
    check_for_updates()

func check_for_updates():
    var http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_version_check)
    http.request(VERSION_URL)

func _on_version_check(result, code, headers, body):
    if code != 200:
        # Offline — try loading cached PCK
        load_cached_or_fail()
        return

    var remote = JSON.parse_string(body.get_string_from_utf8())
    var remote_version = remote["version"]
    var local_version = load_local_version()

    if remote_version != local_version:
        download_update(remote_version, remote["sha256"])
    else:
        launch_game()

func download_update(version: String, expected_hash: String):
    var url = PCK_URL_TEMPLATE % version
    # ... download to LOCAL_PCK, verify SHA256, save version ...

func launch_game():
    var ok = ProjectSettings.load_resource_pack(LOCAL_PCK)
    if ok:
        get_tree().change_scene_to_file("res://scenes/lobby.tscn")
```

### Option B: itch.io App (Simplest)

Players install the **itch.io desktop app**, which handles updates automatically using butler's delta patching.

**Pros:**
- Zero custom code needed
- Delta patching built in (only changed bytes downloaded)
- Cross-platform (Windows, macOS, Linux)
- Free hosting

**Cons:**
- Requires players to use the itch.io app (not just the web download)
- No control over the update UX
- Web downloads get the full build every time (no delta)
- Less professional feel for players unfamiliar with itch.io

### Option C: Electron/Tauri Launcher

A native launcher built with Tauri (Rust + web UI) or Electron.

**Pros:**
- Full control over UX (custom branding, news feed, etc.)
- Mature auto-update libraries
- Can handle both game binary and PCK updates

**Cons:**
- Significant extra complexity for a 2-person team
- Tauri adds Rust dependency; Electron adds ~100MB to launcher size
- Overkill for current scale

### Recommendation

**Start with Option B (itch.io butler) for distribution + Option A (Godot launcher) for direct-download players.** The itch.io app handles updates automatically for players who use it. The Godot launcher serves players who download directly from your website or other sources.

---

## 3. Version Checking

### Version Manifest (version.json)
Host a simple JSON file at a known URL:
```json
{
    "version": "0.4.2",
    "min_version": "0.4.0",
    "pck_url": "https://r2.your-domain.com/builds/game-v0.4.2.pck",
    "pck_sha256": "a1b2c3d4e5f6...",
    "pck_size_bytes": 45000000,
    "changelog": "- Fixed turret targeting\n- New enemy type",
    "updated_at": "2026-02-15T00:00:00Z"
}
```

### Version Check in Godot
```gdscript
# In launcher or game autoload
func check_version():
    var http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_version_response)
    http.request("https://your-domain.com/version.json")

func _on_version_response(result, code, headers, body):
    if result != HTTPRequest.RESULT_SUCCESS or code != 200:
        return  # Offline, skip check
    var data = JSON.parse_string(body.get_string_from_utf8())
    var remote_ver = data["version"]
    var local_ver = ProjectSettings.get_setting("application/config/version")
    if remote_ver != local_ver:
        show_update_prompt(data)
```

### Lobby Version Gate
The game already has a `version_label` in the lobby. Add version checking at connection time:

```gdscript
# In network_manager.gd or lobby.gd
# When a client connects, server sends its version
# Client compares and disconnects if mismatched

# Server side (in peer_connected handler):
@rpc("authority", "call_remote", "reliable")
func send_server_version(version: String):
    pass  # Client receives this

# Client side:
func _on_server_version_received(version: String):
    var my_version = ProjectSettings.get_setting("application/config/version")
    if version != my_version:
        show_version_mismatch_error(version, my_version)
        multiplayer.multiplayer_peer.close()
```

**Important:** Godot's ENet multiplayer does NOT check versions automatically. A 4.6.0 client can connect to a 4.6.1 server with undefined behavior. You must implement version gating yourself.

---

## 4. Update Hosting Options

### Cloudflare R2 (RECOMMENDED for Direct Downloads)

| Feature | Details |
|---------|---------|
| Free tier | 10 GB storage, 1M Class B requests/month |
| Egress | **Zero egress fees** (huge advantage) |
| API | S3-compatible |
| CDN | Built-in with custom domain |
| Setup | ~30 min via Cloudflare dashboard |

**Cost estimate for indie scale:**
- 50MB PCK x 500 downloads/month = 25 GB egress = **$0** (R2 has no egress fees)
- Same on AWS S3 = ~$2.25/month in egress alone
- Storage for 10 versions = 500 MB = **$0** (within free tier)

**Setup:**
1. Create R2 bucket in Cloudflare dashboard
2. Bind a custom domain (e.g., `updates.yourgame.com`)
3. Upload builds via S3 API or Cloudflare dashboard
4. Set CORS headers for Godot's HTTPRequest

### GitHub Releases (Good Secondary/Fallback)

| Feature | Details |
|---------|---------|
| Free tier | Unlimited public repos, 2 GB per release asset |
| API | `GET /repos/{owner}/{repo}/releases/latest` |
| CDN | GitHub's CDN (fast globally) |
| Setup | Already using GitHub |

**Checking latest version:**
```
GET https://api.github.com/repos/your-user/your-game/releases/latest
→ { "tag_name": "v0.4.2", "assets": [{ "browser_download_url": "..." }] }
```

**Limitations:**
- 2 GB per asset (fine for PCK files)
- Rate limited (60 req/hr unauthenticated)
- Less control over URLs/caching

### itch.io Butler (RECOMMENDED for Primary Distribution)

**Push a build:**
```bash
butler push game/export/windows your-user/your-game:windows --userversion 0.4.2
butler push game/export/linux your-user/your-game:linux --userversion 0.4.2
butler push game/export/mac your-user/your-game:mac --userversion 0.4.2
```

**Key features:**
- Delta patching: Only uploads/downloads changed bytes (80-95% bandwidth savings)
- Auto-versioning or custom `--userversion`
- Channel-based platform targeting
- 30 GB max per build
- Free hosting, no egress fees

**Check latest version via API:**
```
GET https://itch.io/api/1/x/wharf/latest?channel_name=windows&target=your-user/your-game
→ { "latest": "0.4.2" }
```

**CI/CD integration (GitHub Actions):**
```yaml
- name: Push to itch.io
  uses: yeslayla/butler-publish-itchio-action@master
  env:
    BUTLER_CREDENTIALS: ${{ secrets.BUTLER_API_KEY }}
  with:
    butler_path: butler
    itch_game: your-user/your-game
    itch_user: your-user
    build_dir: export/windows
    channel: windows
    version: ${{ github.ref_name }}
```

---

## 5. Delta vs Full Updates

### Full PCK Replacement (Simple, Recommended to Start)

- Export entire game as PCK, upload, clients download full file
- PCK size for this game: likely 20-80 MB
- Simple to implement, easy to debug
- On modern connections, a 50 MB download takes ~10 seconds

### Godot's Built-in Patch PCK (Partial, Unreliable)

Godot's export dialog has a "Patches" tab for exporting only changed resources:
- **Status:** Historically buggy and unreliable
- **Problem:** Patch PCK includes excess unmodified content due to scene dependencies
- **Verdict:** Not recommended — community consensus is this feature is underbaked

### Binary Delta Patching (Advanced, Future)

Tools like **xdelta3** or **bsdiff** can create patches between two binary files:
- Patch sizes are typically 5-20% of the full file
- Requires keeping old versions to generate deltas
- Client must apply patches sequentially (v1 -> v2 -> v3)

**Implementation sketch:**
```bash
# Build pipeline
xdelta3 -e -s game-v0.4.1.pck game-v0.4.2.pck patch-0.4.1-to-0.4.2.xd3

# Client-side (via OS.execute or bundled xdelta)
xdelta3 -d -s old.pck patch.xd3 new.pck
```

**Verdict:** Overkill for a 2-person team at current scale. Revisit if PCK exceeds 200 MB.

### Recommendation

**Use full PCK replacement.** At indie scale (< 100 MB), the simplicity wins. Butler handles delta patching for itch.io app users automatically — you get it for free on that platform.

---

## 6. Platform Concerns

### Windows

**SmartScreen warnings:** Unsigned executables trigger "Windows protected your PC" dialog.

**Mitigation options:**
1. **Code signing certificate** (~$100-500/year) — reduces warnings but SmartScreen still shows for new certificates until reputation builds
2. **EV code signing certificate** (~$300-600/year) — historically bypassed SmartScreen instantly, but since March 2024 Microsoft changed policy; EV certs now also need reputation
3. **Distribute via itch.io app** — the itch.io app is already trusted, so games launched through it don't trigger SmartScreen
4. **Instruct users** — many indie games ship with "how to bypass SmartScreen" instructions

**Recommendation:** Start without code signing. Distribute via itch.io. Add code signing later if direct-download numbers warrant it.

### macOS

**Code signing + notarization is effectively mandatory** on modern macOS (especially Apple Silicon).

**Requirements:**
- Apple Developer Program membership ($99/year)
- Developer ID certificate for signing
- Notarization submission to Apple's servers (automated, 5-30 min)
- Staple the notarization ticket to the .app bundle

**Godot support:** Godot's macOS export template can handle signing and notarization if you provide your Apple Developer credentials in the export preset.

**Without signing:** Users must right-click > Open > confirm security dialog. Increasingly hostile UX in newer macOS versions.

**Recommendation:** If either team member has a Mac + Apple Developer account, set up signing. Otherwise, prioritize Windows/Linux and add macOS signing later. Cost is $99/year.

### Linux

**No signing requirements.** Distribute as:
- Tarball (.tar.gz) with executable + PCK
- AppImage (single-file, portable)
- Flatpak (sandboxed, discoverable via Flathub)

**Recommendation:** Tarball is simplest. AppImage is a nice upgrade if you want single-file distribution.

---

## 7. Security

### Hash Verification (Minimum Viable Security)

Include SHA-256 hashes in `version.json` and verify after download:

```gdscript
func verify_download(file_path: String, expected_hash: String) -> bool:
    var file = FileAccess.open(file_path, FileAccess.READ)
    var ctx = HashingContext.new()
    ctx.start(HashingContext.HASH_SHA256)
    while file.get_position() < file.get_length():
        ctx.update(file.get_buffer(65536))  # Read in 64KB chunks
    var hash = ctx.finish().hex_encode()
    return hash == expected_hash
```

### Signed Manifests (Better Security)

Sign the `version.json` with a private key. The launcher verifies the signature with the embedded public key. This prevents MITM attacks where an attacker replaces both the PCK and the hash.

**Implementation:** Use Godot's `Crypto` class or verify signatures server-side.

### HTTPS Everywhere

- Serve `version.json` and PCK downloads over HTTPS only
- Cloudflare R2 with custom domain provides free TLS
- GitHub Releases and itch.io are HTTPS by default

### Recommendation

**Start with SHA-256 hash verification + HTTPS.** This covers:
- Corrupted downloads (network errors)
- Basic tampering detection
- CDN/cache poisoning

Add manifest signing later if the game gets popular enough to be a target.

---

## 8. Integration with Lobby Server

The game's lobby already has `version_label` in the UI. Here's how to integrate version gating:

### At Connection Time
```gdscript
# network_manager.gd — add to the connection flow

const GAME_VERSION := "0.4.2"  # Or read from ProjectSettings

# Server: when a peer connects, send version
func _on_peer_connected(id: int):
    rpc_id(id, "receive_server_version", GAME_VERSION)

@rpc("authority", "call_remote", "reliable")
func receive_server_version(server_version: String):
    if server_version != GAME_VERSION:
        Events.version_mismatch.emit(server_version, GAME_VERSION)
        peer.close()
```

### In Lobby UI
```gdscript
# lobby.gd
func _ready():
    version_label.text = "v" + NetworkManager.GAME_VERSION
    Events.version_mismatch.connect(_on_version_mismatch)

func _on_version_mismatch(server_ver, client_ver):
    status_label.text = "Version mismatch! Server: %s, You: %s\nPlease update." % [server_ver, client_ver]
```

### With Dedicated Lobby Server (Future)
If you move to a dedicated lobby server (Railway/etc.), the server can:
1. Accept connections
2. Check client version in the handshake
3. Reject outdated clients with a message pointing to the update URL
4. Maintain a list of compatible version ranges

---

## 9. What Other Indie Games Do

### Common Patterns
- **Most itch.io games:** Rely entirely on itch.io butler + app for updates. No in-game update system.
- **Steam games:** Steam handles everything (delta patches, version management, CDN). Zero custom code needed.
- **Custom launchers:** Games like Minecraft, League of Legends, and Warframe use custom launchers. Overkill for small indie games.
- **Godot games specifically:** The Parlette.org blog documents a Godot launcher that downloads PCK files from S3 on every launch — the closest documented example to what this project needs.

### Real-World Examples
| Game | Platform | Update Strategy |
|------|----------|----------------|
| Most itch.io games | itch.io | Butler push, players re-download or use itch app |
| Godot community games | Various | Manual re-download, no auto-update |
| Cosmic Trading Crew | Custom | Godot launcher + S3-hosted PCK (documented by Parlette.org) |
| Professional indie | Steam | Steam CDN handles everything |

### Takeaway
Very few Godot indie games implement custom auto-update. Most rely on platform tools (itch.io butler, Steam). The Godot launcher + PCK approach is documented but uncommon — it's the right choice only if you need players to always have the latest version without visiting a website.

---

## 10. Recommended Implementation Plan

### Phase 1: Butler + Manual Updates (NOW)
1. Set up itch.io butler in your build script
2. Push builds with `butler push` and `--userversion`
3. Add `application/config/version` to project settings
4. Show version in lobby UI (already have `version_label`)
5. Add version check on lobby connection (reject mismatched clients)

**Effort:** ~2 hours. **Result:** Players download from itch.io, itch app users get auto-updates.

### Phase 2: Version Check API (SOON)
1. Create `version.json` and host on Cloudflare R2 or GitHub Pages
2. Add version check on game startup (non-blocking)
3. Show "Update available!" banner in lobby with download link
4. Add SHA-256 hash to version manifest

**Effort:** ~4 hours. **Result:** Players are notified of updates in-game.

### Phase 3: Godot Launcher with Auto-Download (LATER)
1. Create minimal launcher Godot project
2. Launcher checks version, downloads PCK, loads it
3. Host PCK files on Cloudflare R2
4. Distribute launcher via itch.io (launcher itself rarely updates)

**Effort:** ~1-2 days. **Result:** Fully automatic updates without platform dependency.

### Phase 4: Polish (MUCH LATER)
- macOS code signing + notarization ($99/year)
- Windows code signing (~$200/year)
- Delta patching (if PCK exceeds 200 MB)
- Signed update manifests
- GitHub Actions CI/CD for automated builds + butler push

---

## 11. Key Technical References

- [Godot PCK Export Docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_pcks.html)
- [PCKPacker Class Reference](https://docs.godotengine.org/en/stable/classes/class_pckpacker.html)
- [Butler Manual — Pushing Builds](https://itch.io/docs/butler/pushing.html)
- [Butler itch.io GitHub Action](https://github.com/yeslayla/butler-publish-itchio-action)
- [Parlette.org — Auto-Update Godot Clients](https://parlette.org/blog/2022/09/automatically-update-godot-game-clients/)
- [Cloudflare R2 Pricing](https://developers.cloudflare.com/r2/pricing/)
- [GitHub Releases API](https://docs.github.com/en/rest/releases/releases)
- [macOS Signing Guide for Godot](https://alicegg.tech/2024/09/12/godot-mac)
- [Godot Version Mismatch Proposal](https://github.com/godotengine/godot-proposals/issues/10348)
- [Godot Patch System Proposal](https://github.com/godotengine/godot-proposals/issues/146)
- [GodotPckTool (standalone PCK tool)](https://github.com/hhyyrylainen/GodotPckTool)
- [IndieLauncher (game launcher/updater)](https://github.com/dan200/IndieLauncher)
