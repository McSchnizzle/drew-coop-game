## DebugLogger autoload — writes timestamped errors to a log file Claude can read.
## Captures game context (wave, player count) and listens for Events signals.
## Usage: DebugLogger.error("something broke"), DebugLogger.warn("hmm"), DebugLogger.info("ok")
extends Node

const LOG_PATH_EDITOR := "res://../debug_errors.log"
const LOG_PATH_EXPORT := "user://debug_errors.log"
const MAX_FILE_SIZE := 512 * 1024  # 512 KB cap, then rotate

var _file: FileAccess = null
var _log_path: String = ""

# Godot engine log tailing — captures parse errors, engine errors, etc.
var _godot_log: FileAccess = null
var _godot_log_poll: float = 0.0
const GODOT_LOG_POLL_INTERVAL: float = 0.5

# Game context — updated by signal listeners
var _current_wave: int = 0
var _player_count: int = 0
var _scene_name: String = ""


func _ready() -> void:
	# Choose path based on whether we're running in the editor
	if OS.has_feature("editor"):
		_log_path = ProjectSettings.globalize_path(LOG_PATH_EDITOR)
	else:
		_log_path = ProjectSettings.globalize_path(LOG_PATH_EXPORT)

	_open_log()
	_open_godot_log()
	info("DebugLogger started — writing to %s" % _log_path)

	# Listen for game events to track context
	if Events:
		if Events.has_signal("wave_started"):
			Events.wave_started.connect(_on_wave_started)
		if Events.has_signal("player_joined"):
			Events.player_joined.connect(_on_player_joined)
		if Events.has_signal("player_left"):
			Events.player_left.connect(_on_player_left)
		if Events.has_signal("player_died"):
			Events.player_died.connect(_on_player_died)
		if Events.has_signal("enemy_died"):
			Events.enemy_died.connect(_on_enemy_died)
		if Events.has_signal("boss_died"):
			Events.boss_died.connect(_on_boss_died)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		if _file:
			_file.close()
			_file = null
		if _godot_log:
			_godot_log.close()
			_godot_log = null


func _open_log() -> void:
	# Rotate if file is too large
	if FileAccess.file_exists(_log_path):
		var existing := FileAccess.open(_log_path, FileAccess.READ)
		if existing:
			var size := existing.get_length()
			existing.close()
			if size > MAX_FILE_SIZE:
				var old_path := _log_path + ".old"
				if FileAccess.file_exists(old_path):
					DirAccess.remove_absolute(old_path)
				DirAccess.rename_absolute(_log_path, old_path)

	_file = FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if not _file:
		# File doesn't exist yet, create it
		_file = FileAccess.open(_log_path, FileAccess.WRITE)
	else:
		_file.seek_end()


func _open_godot_log() -> void:
	# Find the Godot engine log and seek to end so we only capture new errors.
	var godot_log_path := ProjectSettings.globalize_path("user://logs/godot.log")
	if not FileAccess.file_exists(godot_log_path):
		return
	_godot_log = FileAccess.open(godot_log_path, FileAccess.READ)
	if _godot_log:
		_godot_log.seek_end()


func _poll_godot_log() -> void:
	if not _godot_log:
		return
	# Read any new lines appended since last poll
	while _godot_log.get_position() < _godot_log.get_length():
		var line := _godot_log.get_line()
		if line.is_empty():
			continue
		# Capture ERROR and WARNING lines from the engine
		if line.begins_with("ERROR:") or line.begins_with("SCRIPT ERROR:") or "Parse Error" in line:
			_write_raw("ENGINE", line.strip_edges())
		elif line.begins_with("WARNING:"):
			_write_raw("ENGINE_WARN", line.strip_edges())


func _write_raw(level: String, msg: String) -> void:
	## Write to debug log without also pushing to Godot output (avoids echo loop).
	var timestamp := Time.get_datetime_string_from_system(false, true)
	var context := _build_context()
	var line := "[%s] %s: %s%s\n" % [timestamp, level, msg, context]
	if _file:
		_file.store_string(line)
		_file.flush()


func _write(level: String, msg: String) -> void:
	var timestamp := Time.get_datetime_string_from_system(false, true)
	var context := _build_context()
	var line := "[%s] %s: %s%s\n" % [timestamp, level, msg, context]

	if _file:
		_file.store_string(line)
		_file.flush()

	# Also print to Godot output so it shows in the engine log
	match level:
		"ERROR":
			push_error("DebugLogger: %s" % msg)
		"WARN":
			push_warning("DebugLogger: %s" % msg)
		_:
			print("DebugLogger: %s" % msg)


func _build_context() -> String:
	var parts: PackedStringArray = PackedStringArray()
	if _current_wave > 0:
		parts.append("wave=%d" % _current_wave)
	if _player_count > 0:
		parts.append("players=%d" % _player_count)
	if not _scene_name.is_empty():
		parts.append("scene=%s" % _scene_name)
	if parts.is_empty():
		return ""
	return " [%s]" % ", ".join(parts)


# ── Public API ────────────────────────────────────────────────────────────────

func error(msg: String) -> void:
	_write("ERROR", msg)


func warn(msg: String) -> void:
	_write("WARN", msg)


func info(msg: String) -> void:
	_write("INFO", msg)


# ── Signal Handlers ───────────────────────────────────────────────────────────

func _on_wave_started(wave_number: int, _enemy_count: int) -> void:
	_current_wave = wave_number
	info("Wave %d started" % wave_number)


func _on_player_joined(player_id: int, _spawn_pos) -> void:
	_player_count += 1
	info("Player %d joined (total: %d)" % [player_id, _player_count])


func _on_player_left(player_id: int) -> void:
	_player_count = maxi(_player_count - 1, 0)
	info("Player %d left (total: %d)" % [player_id, _player_count])


func _on_player_died(player_id: int, _pos) -> void:
	error("Player %d died" % player_id)


func _on_enemy_died(enemy_id: int, killed_by: int, was_clean: bool) -> void:
	info("Enemy %d killed by player %d (clean=%s)" % [enemy_id, killed_by, str(was_clean)])


func _on_boss_died(enemy_id: int, killed_by: int) -> void:
	info("BOSS %d killed by player %d" % [enemy_id, killed_by])


# ── Scene Tracking ────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Poll the Godot engine log for new errors (parse errors, engine crashes, etc.)
	_godot_log_poll += delta
	if _godot_log_poll >= GODOT_LOG_POLL_INTERVAL:
		_godot_log_poll = 0.0
		_poll_godot_log()

	var scene := get_tree().current_scene
	if scene:
		var new_name := scene.name
		if new_name != _scene_name:
			_scene_name = new_name
			info("Scene changed to: %s" % new_name)
