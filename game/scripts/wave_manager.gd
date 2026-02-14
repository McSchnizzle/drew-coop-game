## Wave manager -- server-authoritative wave spawning and difficulty scaling.
## Added as a child Node of Game (game_manager.gd) at runtime.
## Controls the wave state machine, enemy spawning, and rest periods.
extends Node

enum WaveState { IDLE, SPAWNING, ACTIVE, REST_PERIOD, GAME_WON, GAME_OVER }

# ── Wave Configuration ───────────────────────────────────────────────────────
const MAX_WAVE: int = 10
const WAVE_MAX_ENEMIES: int = 30
const SPAWN_STAGGER: float = 0.15

const SPAWN_X_MIN: float = 800.0
const SPAWN_X_MAX: float = 1100.0
const SPAWN_Y: float = 500.0

const REST_DURATIONS: Array[float] = [5.0, 5.0, 5.0, 4.0, 4.0, 3.0]

# Wave enemy counts for waves 1-5; wave 6+ uses formula.
const WAVE_ENEMY_COUNTS: Array[int] = [3, 5, 7, 10, 13]

# Scaling clamps
const HEALTH_SCALE_MAX: float = 3.0
const SPEED_SCALE_MAX: float = 1.5
const DAMAGE_SCALE_MAX: float = 2.5

# ── Enemy Scenes ─────────────────────────────────────────────────────────────
var _enemy_scenes: Dictionary = {}

# Wave enemy type availability (per architecture doc)
# Wave 1-2: Merge Conflict only
# Wave 3: Merge Conflict + Hallucination
# Wave 4: Merge Conflict + Hallucination + Context Rot
# Wave 5+: All types with weighted random
const WAVE_TYPE_WEIGHTS: Dictionary = {
	"merge_conflict": 40,
	"hallucination": 20,
	"context_rot": 25,
	"dependency_hell": 15,
}

# ── State ────────────────────────────────────────────────────────────────────
var _wave_state: WaveState = WaveState.IDLE
var _current_wave: int = 0
var _enemies_to_spawn: int = 0
var _enemies_spawned_this_wave: int = 0
var _spawn_timer: float = 0.0
var _rest_timer: float = 0.0
var _game_time: float = 0.0
var _boss_spawned_this_wave: bool = false

# Synced to clients via parent GameManager's WaveSync
var current_wave: int = 0
var wave_state_value: int = 0  # int representation of WaveState for sync


func _ready() -> void:
	_enemy_scenes = {
		"merge_conflict": load("res://scenes/enemies/enemy_merge_conflict.tscn"),
		"hallucination": load("res://scenes/enemies/enemy_hallucination.tscn"),
		"context_rot": load("res://scenes/enemies/enemy_context_rot.tscn"),
		"dependency_hell": load("res://scenes/enemies/enemy_dependency_hell.tscn"),
		"boss_kernel_panic": load("res://scenes/enemies/boss_kernel_panic.tscn"),
	}


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	_game_time += delta

	match _wave_state:
		WaveState.IDLE:
			pass
		WaveState.SPAWNING:
			_process_spawning(delta)
		WaveState.ACTIVE:
			_check_wave_status()
			_check_all_players_dead()
		WaveState.REST_PERIOD:
			_process_rest(delta)
		WaveState.GAME_WON:
			pass
		WaveState.GAME_OVER:
			pass


# ── Public API ───────────────────────────────────────────────────────────────

func start_waves() -> void:
	if not multiplayer.is_server():
		return
	_start_next_wave()


# ── Wave State Machine ───────────────────────────────────────────────────────

func _start_next_wave() -> void:
	_current_wave += 1
	current_wave = _current_wave
	wave_state_value = WaveState.SPAWNING
	NetworkManager.highest_wave_reached = maxi(NetworkManager.highest_wave_reached, _current_wave)

	_enemies_to_spawn = _get_enemy_count(_current_wave)
	_enemies_spawned_this_wave = 0
	_spawn_timer = 0.0
	_boss_spawned_this_wave = false
	_wave_state = WaveState.SPAWNING

	Events.wave_started.emit(_current_wave, _enemies_to_spawn)
	_notify_wave_started.rpc(_current_wave, _enemies_to_spawn)
	print("WaveManager: Wave %d started — spawning %d enemies" % [_current_wave, _enemies_to_spawn])


func _process_spawning(delta: float) -> void:
	# Spawn boss on every 5th wave (5, 10, 15...)
	if _current_wave % 5 == 0 and not _boss_spawned_this_wave:
		_spawn_boss()
		_boss_spawned_this_wave = true

	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _enemies_spawned_this_wave < _enemies_to_spawn:
		_spawn_enemy()
		_enemies_spawned_this_wave += 1
		_spawn_timer = SPAWN_STAGGER

	if _enemies_spawned_this_wave >= _enemies_to_spawn:
		_wave_state = WaveState.ACTIVE
		wave_state_value = WaveState.ACTIVE


func _check_wave_status() -> void:
	var alive_enemies := get_tree().get_nodes_in_group("enemies")
	if alive_enemies.size() == 0 and _wave_state == WaveState.ACTIVE:
		_wave_state = WaveState.REST_PERIOD
		wave_state_value = WaveState.REST_PERIOD
		Events.wave_cleared.emit(_current_wave)
		_notify_wave_cleared.rpc(_current_wave)
		_rest_timer = REST_DURATIONS[mini(_current_wave - 1, REST_DURATIONS.size() - 1)]
		print("WaveManager: Wave %d cleared!" % _current_wave)


func _process_rest(delta: float) -> void:
	_rest_timer -= delta
	if _rest_timer <= 0.0:
		if _current_wave >= MAX_WAVE:
			_wave_state = WaveState.GAME_WON
			wave_state_value = WaveState.GAME_WON
			Events.game_won.emit(_current_wave, _game_time)
			_notify_game_won.rpc(_current_wave, _game_time)
			print("WaveManager: All waves cleared! Game won!")
		else:
			_start_next_wave()


func _check_all_players_dead() -> void:
	var players := get_tree().get_nodes_in_group("players")
	if players.size() == 0:
		return
	var any_standing := false
	for player in players:
		# A player is "standing" if alive and not downed
		if player._is_alive and not player._is_downed:
			any_standing = true
			break
	if not any_standing:
		_wave_state = WaveState.GAME_OVER
		wave_state_value = WaveState.GAME_OVER
		Events.game_lost.emit(_current_wave, _game_time)
		_notify_game_lost.rpc(_current_wave, _game_time)
		print("WaveManager: All players dead or downed! Game over at wave %d" % _current_wave)


# ── Enemy Spawning ───────────────────────────────────────────────────────────

func _spawn_enemy() -> void:
	var enemy_type := _pick_enemy_type(_current_wave)
	var scene: PackedScene = _enemy_scenes.get(enemy_type)
	if scene == null:
		return

	var game_manager = get_parent()
	var enemy = scene.instantiate()
	enemy.enemy_id = game_manager.next_enemy_id()
	enemy.name = "Enemy_%d" % enemy.enemy_id

	# Randomize spawn position along the right edge
	var spawn_x := randf_range(SPAWN_X_MIN, SPAWN_X_MAX)
	enemy.position = Vector2(spawn_x, SPAWN_Y)

	var enemies_node = get_tree().current_scene.get_node("Enemies")
	enemies_node.add_child(enemy, true)

	# Apply difficulty scaling AFTER add_child so _ready() has set base stats
	var health_scale := clampf(1.0 + (_current_wave - 1) * 0.15, 1.0, HEALTH_SCALE_MAX)
	var speed_scale := clampf(1.0 + (_current_wave - 1) * 0.05, 1.0, SPEED_SCALE_MAX)
	enemy.apply_scaling(health_scale, speed_scale)

	Events.enemy_spawned.emit(enemy.enemy_id, enemy_type, enemy.position)


func _spawn_boss() -> void:
	var scene: PackedScene = _enemy_scenes.get("boss_kernel_panic")
	if scene == null:
		return

	var game_manager = get_parent()
	var boss = scene.instantiate()
	boss.enemy_id = game_manager.next_enemy_id()
	boss.name = "Enemy_%d" % boss.enemy_id

	# Spawn boss at center-right of the arena
	boss.position = Vector2(1000, 300)

	var enemies_node = get_tree().current_scene.get_node("Enemies")
	enemies_node.add_child(boss, true)

	# Apply difficulty scaling AFTER add_child so _ready() has set base stats
	var health_scale := clampf(1.0 + (_current_wave - 1) * 0.15, 1.0, HEALTH_SCALE_MAX)
	var speed_scale := clampf(1.0 + (_current_wave - 1) * 0.05, 1.0, SPEED_SCALE_MAX)
	boss.apply_scaling(health_scale, speed_scale)

	Events.boss_spawned.emit(boss.enemy_id, "boss_kernel_panic", boss.position)
	_notify_boss_spawned.rpc()
	print("WaveManager: BOSS Kernel Panic spawned on wave %d!" % _current_wave)


func _pick_enemy_type(wave_number: int) -> String:
	if wave_number <= 2:
		return "merge_conflict"
	elif wave_number == 3:
		return ["merge_conflict", "hallucination"][randi() % 2]
	elif wave_number == 4:
		var types := ["merge_conflict", "merge_conflict", "hallucination", "context_rot"]
		return types[randi() % types.size()]
	else:
		# Wave 5+: weighted random per architecture doc
		var total_weight: int = 0
		for w in WAVE_TYPE_WEIGHTS.values():
			total_weight += w
		var roll: int = randi() % total_weight
		var cumulative: int = 0
		for type_name in WAVE_TYPE_WEIGHTS:
			cumulative += WAVE_TYPE_WEIGHTS[type_name]
			if roll < cumulative:
				return type_name
		return "merge_conflict"


# ── Wave Configuration ───────────────────────────────────────────────────────

func _get_enemy_count(wave_number: int) -> int:
	if wave_number <= WAVE_ENEMY_COUNTS.size():
		return WAVE_ENEMY_COUNTS[wave_number - 1]
	var count := 5 + (wave_number * 2)
	return mini(count, WAVE_MAX_ENEMIES)


# ── RPCs ─────────────────────────────────────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func _notify_wave_started(wave_number: int, enemy_count: int) -> void:
	current_wave = wave_number
	wave_state_value = WaveState.SPAWNING
	_update_wave_hud(wave_number)


@rpc("authority", "call_local", "reliable")
func _notify_wave_cleared(wave_number: int) -> void:
	wave_state_value = WaveState.REST_PERIOD
	_update_wave_hud_status("Wave %d cleared!" % wave_number)


@rpc("authority", "call_local", "reliable")
func _notify_game_won(total_waves: int, time: float) -> void:
	wave_state_value = WaveState.GAME_WON
	_update_wave_hud_status("Victory! All %d waves cleared!" % total_waves)
	_show_end_screen("VICTORY!", total_waves, time)


@rpc("authority", "call_local", "reliable")
func _notify_game_lost(wave: int, time: float) -> void:
	wave_state_value = WaveState.GAME_OVER
	_update_wave_hud_status("Game Over - Wave %d" % wave)
	_show_end_screen("GAME OVER", wave, time)


@rpc("authority", "call_local", "reliable")
func _notify_boss_spawned() -> void:
	_update_wave_hud_status("WARNING: KERNEL PANIC DETECTED")
	# Clear warning after 3 seconds
	get_tree().create_timer(3.0).timeout.connect(func():
		var hud = get_tree().current_scene.get_node_or_null("UI/HUD")
		if not hud:
			return
		var wave_label = hud.get_node_or_null("WaveLabel") as Label
		if wave_label and wave_label.text == "WARNING: KERNEL PANIC DETECTED":
			wave_label.text = "Wave: %d" % current_wave
	)


# ── HUD Helpers ──────────────────────────────────────────────────────────────

func _update_wave_hud(wave_number: int) -> void:
	var hud = get_tree().current_scene.get_node_or_null("UI/HUD")
	if not hud:
		return
	var wave_label = hud.get_node_or_null("WaveLabel") as Label
	if wave_label:
		wave_label.text = "Wave: %d" % wave_number


func _update_wave_hud_status(status_text: String) -> void:
	var hud = get_tree().current_scene.get_node_or_null("UI/HUD")
	if not hud:
		return
	var wave_label = hud.get_node_or_null("WaveLabel") as Label
	if wave_label:
		wave_label.text = status_text


func _show_end_screen(result: String, wave: int, time: float) -> void:
	var hud = get_tree().current_scene.get_node_or_null("UI/HUD")
	if not hud:
		return
	var end_screen = hud.get_node_or_null("EndScreen")
	if not end_screen:
		return

	var result_label = end_screen.get_node_or_null("VBoxContainer/ResultLabel") as Label
	var stats_label = end_screen.get_node_or_null("VBoxContainer/StatsLabel") as Label
	if result_label:
		result_label.text = result
	if stats_label:
		stats_label.text = "Wave %d  |  Time: %ds" % [wave, int(time)]

	end_screen.visible = true

	# Auto-return to lobby after 8 seconds (server triggers for all peers).
	get_tree().create_timer(8.0).timeout.connect(func():
		if not multiplayer.is_server():
			return
		var game_mgr = get_tree().current_scene
		if is_instance_valid(game_mgr) and game_mgr.has_method("_return_to_lobby"):
			game_mgr._return_to_lobby()
	)
