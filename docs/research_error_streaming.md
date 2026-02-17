# Research: Streaming Godot Error Output to Claude Code

## Environment
- macOS (Darwin 25.2.0), Apple M1
- Godot 4.6 stable (installed at `/Applications/Godot.app` and `/opt/homebrew/bin/godot`)
- Project name: `drew-coop-game`

---

## Option 1: Read Existing Log Files (EASIEST -- Works Today)

Godot already writes log files to disk. They exist right now on this machine:

```
~/Library/Application Support/Godot/app_userdata/drew-coop-game/logs/godot.log
```

The log file contains errors with full backtraces, exactly as shown in the editor Output panel. Example from the current log:

```
ERROR: Condition "!is_inside_tree()" is true. Returning: Transform3D()
   at: get_global_transform (scene/3d/node_3d.cpp:642)
   GDScript backtrace (most recent call first):
       [0] _show_melee_strike (res://scripts/enemies/enemy_base.gd:264)
       [1] _check_contact_damage (res://scripts/enemies/enemy_base.gd:363)
```

### How to use with Claude Code

Just ask Claude to read the log file:
```
"Read the Godot log at ~/Library/Application Support/Godot/app_userdata/drew-coop-game/logs/godot.log and tell me what errors are happening"
```

Or create a symlink for convenience:
```bash
ln -s ~/Library/Application\ Support/Godot/app_userdata/drew-coop-game/logs/godot.log \
  /Users/drewdavid/coding-projects/multiplayer-game/godot.log
```

### Caveats
- The log file is overwritten each time Godot launches (old logs are rotated with timestamps)
- The file only contains what `print()`, `push_error()`, `push_warning()`, and engine errors emit
- File logging is ON by default in the editor; for exports, you need to enable `debug/file_logging/enable_file_logging` in Project Settings
- Max 5 log files kept by default (configurable via `debug/file_logging/max_log_files`)

### Verdict: **Recommended as immediate solution.** Zero setup required.

---

## Option 2: Run Godot from Terminal with `--log-file`

Godot 4.3+ supports `--log-file <path>` to write output to a custom location:

```bash
godot --path /Users/drewdavid/coding-projects/multiplayer-game/game \
      --log-file /Users/drewdavid/coding-projects/multiplayer-game/game_errors.log
```

This writes ALL stdout/stderr (including errors, warnings, print statements) to the specified file. Log rotation is disabled when using `--log-file`.

### Other useful CLI flags

| Flag | Description |
|------|-------------|
| `--verbose` / `-v` | Verbose stdout (resource loading details, etc.) |
| `--debug` / `-d` | Enable local stdout debugger |
| `--quiet` | Suppress normal output, show only errors |
| `--print-fps` | Print FPS to stdout |
| `--headless` | Run without display (for server testing) |

### Full terminal capture approach

```bash
# Run game and capture all output
godot --path /Users/drewdavid/coding-projects/multiplayer-game/game 2>&1 | tee game_output.log

# Or run with --log-file for cleaner file output
godot --path /Users/drewdavid/coding-projects/multiplayer-game/game \
      --log-file /Users/drewdavid/coding-projects/multiplayer-game/game_errors.log

# Then ask Claude to read it
```

### Caveats
- Running from terminal launches a separate game instance (not the editor's Play button)
- Some developers prefer the editor's Play button for its integrated debugger
- The `--log-file` path can be absolute or relative to the project directory

### Verdict: **Good for automated/scripted testing.** Slightly more friction than Option 1 since you must launch from terminal instead of the editor Play button.

---

## Option 3: Custom Logger Autoload (Godot 4.5+ Logger Class)

Godot 4.5 introduced the `Logger` class, which can intercept ALL internal engine errors, warnings, and messages. Since you're on Godot 4.6, this is available.

### How it works

1. Create a script that extends `Logger`
2. Override `_log_error()` and `_log_message()` virtual methods
3. Register it with `OS.add_logger()`
4. Write intercepted messages to a file Claude can read

### Implementation sketch

```gdscript
# res://scripts/autoloads/debug_logger.gd
class_name DebugLogger extends Logger

const LOG_PATH := "res://debug_errors.log"  # In project dir for Claude to read
static var _log_file: FileAccess
static var _is_valid: bool

static func _static_init() -> void:
    _log_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
    _is_valid = _log_file != null and _log_file.is_open()
    if _is_valid:
        OS.add_logger(DebugLogger.new())

func _log_error(function: String, file: String, line: int,
    code: String, rationale: String, _editor_notify: bool,
    error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
    if not _is_valid:
        return
    var level := "WARNING" if error_type == ERROR_TYPE_WARNING else "ERROR"
    var timestamp := Time.get_time_string_from_system()
    var msg := "[%s] %s: %s\n  at: %s (%s:%d)\n" % [timestamp, level, rationale, function, file, line]
    # Add backtrace
    for bt in script_backtraces:
        if bt.get_language_name() == "GDScript":
            msg += "  GDScript backtrace:\n    %s\n" % str(bt)
    _log_file.store_string(msg)
    _log_file.flush()

func _log_message(message: String, is_error: bool) -> void:
    if not _is_valid:
        return
    var level := "ERROR" if is_error else "INFO"
    var timestamp := Time.get_time_string_from_system()
    _log_file.store_string("[%s] %s: %s\n" % [timestamp, level, message])
    _log_file.flush()
```

### Enable backtrace tracking
In Project Settings: `Debug > Settings > GDScript > Always Track Call Stacks = true`
(Minimal performance overhead even in release builds.)

### Advantages over Option 1
- Can write to a file inside the project directory (easier for Claude to find)
- Can filter/format errors however you want
- Can add custom context (e.g., current wave, player count, game state)
- Can add timestamps to each error

### Caveats
- Requires adding a script and registering it as autoload
- Must NOT use `print()`, `push_error()`, or `push_warning()` inside the logger callbacks (infinite recursion)
- The Godot 4.5 Logger API is relatively new; community examples are limited
- Writing to `res://` only works in the editor (not in exports); use `user://` for exports

### Verdict: **Best long-term solution.** More setup, but gives maximum control over error capture. Can be customized to include game state context.

---

## Option 4: Godot MCP Servers

Multiple Model Context Protocol servers exist for Godot integration:

### 1. Coding-Solo/godot-mcp (Most relevant for error capture)
- **URL**: https://github.com/Coding-Solo/godot-mcp
- **Features**: Launch editor, run projects, capture debug output, scene management
- **Error capture**: Captures stdout/stderr when running projects; provides `get_debug_output` tool
- **Setup**: Node.js server; `npm install && npm run build`; configure in Claude Desktop or IDE MCP settings
- **No Godot plugin required** -- communicates via CLI

### 2. bradypp/godot-mcp
- **URL**: https://github.com/bradypp/godot-mcp
- **Features**: Similar to above; project management, scene management, real-time output capture
- **Also Node.js-based**, no Godot plugin needed

### 3. ee0pdt/Godot-MCP
- **URL**: https://github.com/ee0pdt/Godot-MCP
- **Features**: Can see scene tree, capture screenshots, read errors, make changes directly
- **More comprehensive editor integration**

### How MCP servers capture errors
They spawn Godot as a child process via CLI and capture its stdout/stderr streams. This is essentially Option 2 automated behind an MCP interface.

### Claude Code MCP Integration
Claude Code supports MCP servers. You would add the server config to your Claude Code MCP settings file. Once configured, Claude gets tools like `run_project`, `get_debug_output`, etc.

### Caveats
- Adds Node.js dependency to your workflow
- MCP servers run Godot via CLI (separate from editor), so you lose editor integration
- These are community projects with varying maintenance levels
- Overkill if you just need error streaming (Options 1-2 are simpler)

### Verdict: **Powerful but heavy.** Best if you want Claude to also manipulate scenes, manage nodes, etc. For just error reading, simpler options are better.

---

## Option 5: File Watcher / Log Tailing

### Claude Code can read files directly
Claude Code's `Read` tool can read any file on disk. No need for real-time tailing -- just ask Claude to read the log file when you encounter an error.

### MCP Tail Server
- **URL**: https://lobehub.com/mcp/adam-palmer1-mcp-tailserver
- An MCP server specifically for tailing log files with real-time streaming via SSE
- Could be configured to watch the Godot log file
- Overkill for this use case

### Shell piping into Claude Code
Claude Code supports piping:
```bash
tail -f ~/Library/Application\ Support/Godot/app_userdata/drew-coop-game/logs/godot.log | claude -p "Analyze these Godot errors"
```

### Verdict: **Unnecessary complexity.** Just reading the file on demand is simpler and sufficient.

---

## Option 6: Godot Remote Debugger

Godot has a remote debugger that communicates over TCP:
```bash
# In editor: Debug > Keep Debug Server Open
# Run exported game with:
./game --remote-debug tcp://127.0.0.1:6007
```

This sends debug info back to the editor, not to a file. There's no built-in way to redirect remote debugger output to a file or external tool.

### DAP (Debug Adapter Protocol) Server
Godot exposes a GDScript DAP server (`--dap-port <port>`) for use with VS Code and similar editors. This could theoretically be used to capture breakpoint/error info, but:
- DAP is designed for step-debugging, not log streaming
- No existing tool bridges DAP to Claude Code

### Verdict: **Not useful for this purpose.** The remote debugger is for editor-to-device debugging, not log capture.

---

## Recommendations (Ranked)

### Immediate (zero effort):
**Option 1 -- Read the existing log file.** It already exists at:
```
~/Library/Application Support/Godot/app_userdata/drew-coop-game/logs/godot.log
```
Just tell Claude "read my Godot log file" and give the path. Create a symlink into the project for convenience.

### Short-term improvement:
**Option 2 -- Use `--log-file` for CLI runs.** When testing specific scenarios, run from terminal:
```bash
godot --path /Users/drewdavid/coding-projects/multiplayer-game/game \
      --log-file /Users/drewdavid/coding-projects/multiplayer-game/game_errors.log
```

### Medium-term (if error debugging is frequent):
**Option 3 -- Custom Logger autoload.** Write errors to a file in the project directory with timestamps and game state context. Takes 30 min to set up, pays off over many debugging sessions.

### Only if needed:
**Option 4 -- MCP server.** Only if you want Claude to also control Godot (run scenes, manage nodes, etc.), not just read errors.

---

## Quick-Start: Simplest Setup

Add this to your CLAUDE.md or tell Claude in conversation:

```
When I mention Godot errors, read the log file at:
~/Library/Application Support/Godot/app_userdata/drew-coop-game/logs/godot.log

The log is overwritten each game launch. Look for lines starting with ERROR: or WARNING:
```

Or create a convenience symlink:
```bash
ln -s "$HOME/Library/Application Support/Godot/app_userdata/drew-coop-game/logs/godot.log" \
  /Users/drewdavid/coding-projects/multiplayer-game/godot.log
```
