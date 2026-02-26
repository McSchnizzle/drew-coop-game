## Lobby scene logic -- host/join UI, role selection, and game start flow.
## Attach this script to the root Control node of lobby.tscn.
extends Control

# Expected child node paths (set up in lobby.tscn):
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var start_button: Button = %StartButton
@onready var address_input: LineEdit = %AddressInput
@onready var status_label: Label = %StatusLabel
@onready var room_code_container: HBoxContainer = %RoomCodeContainer
@onready var room_code_label: Label = %RoomCodeLabel
@onready var copy_button: Button = %CopyButton
@onready var striker_button: Button = %StrikerButton
@onready var engineer_button: Button = %EngineerButton
@onready var role_label: Label = %RoleLabel
@onready var role_description: Label = %RoleDescription
@onready var name_input: LineEdit = %NameInput
@onready var leave_button: Button = %LeaveButton
@onready var version_label: Label = %VersionLabel

var _lobby_stage_3d: Node3D

const TEXT_PRIMARY := Color(0.910, 0.910, 0.941, 1)
const TEXT_SECONDARY := Color(0.690, 0.690, 0.753, 1)
const TEXT_DISABLED := Color(0.376, 0.376, 0.439, 1)
const MAX_PLAYERS := 4

const ROLE_DESCRIPTIONS := {
	"striker": "Ability: Weak Point Scan — expose enemies for 2x damage\nSuper: Overdrive — double fire rate + damage for 8s\nPassive: +15% damage",
	"engineer": "Ability: Deploy Turret — place auto-targeting turrets (max 2)\nSuper: Healing Pulse — heal & revive all teammates\nPassive: +20% stamina regen",
}

const ENEMY_DATA := [
	{
		"name": "MERGE CONFLICT",
		"sprite": "res://assets/sprites/enemies/enemy_merge_conflict_t0.png",
		"wave": 1,
		"accent": Color(0.85, 0.20, 0.20),
		"is_boss": false,
		"description": "Chases players. Splits into 2 smaller copies on death. Kill with \"exposed\" status for a clean kill (no split).",
	},
	{
		"name": "HALLUCINATION",
		"sprite": "res://assets/sprites/enemies/enemy_hallucination_disguised.png",
		"wave": 3,
		"accent": Color(0.65, 0.30, 0.80),
		"is_boss": false,
		"description": "Disguises as a player. Shoot it to reveal its true form — then it's vulnerable.",
	},
	{
		"name": "CONTEXT ROT",
		"sprite": "res://assets/sprites/enemies/enemy_context_rot.png",
		"wave": 4,
		"accent": Color(0.70, 0.78, 0.20),
		"is_boss": false,
		"description": "Ranged attacker that keeps its distance. Projectiles scramble your HUD for 5s — your health and stamina bars show fake values. Don't panic, your real stats are fine!",
	},
	{
		"name": "DEADLOCK",
		"sprite": "res://assets/sprites/enemies/enemy_dependency_hell.png",
		"wave": 5,
		"accent": Color(0.20, 0.30, 0.70),
		"is_boss": false,
		"description": "Slow tank with a 200px aura that disables your abilities. Stay outside the aura or burst it down fast.",
	},
	{
		"name": "KERNEL PANIC",
		"sprite": "res://assets/sprites/enemies/boss_kernel_panic.png",
		"wave": 5,
		"accent": Color(0.10, 0.45, 0.90),
		"is_boss": true,
		"description": "Boss. Freezes then lunges at high speed (dodge the telegraph!). Phase 2: directional shield — attack from both sides to break it. Fires projectiles that invert your controls for 2s.",
	},
	{
		"name": "STACK OVERFLOW",
		"sprite": "res://assets/sprites/enemies/boss_kernel_panic.png",
		"wave": 10,
		"accent": Color(0.90, 0.15, 0.60),
		"is_boss": true,
		"description": "Ultra Boss. Recursively spawns smaller clones that each spawn more clones. Overloads the arena if you don't kill clones fast. Core is shielded until all active clones are dead. Attacks cause exponentially stacking damage-over-time.",
	},
]
var _connected_player_count: int = 0
var _is_host: bool = false
var _room_code: String = ""
var _selected_role: String = ""

# StyleBoxFlat resources for role button active states
var _striker_active_style: StyleBoxFlat
var _engineer_active_style: StyleBoxFlat

# Character select overlay (built in _build_character_select)
var _char_select: Control
var _striker_card: PanelContainer
var _engineer_card: PanelContainer
var _striker_select_btn: Button
var _engineer_select_btn: Button
var _current_role_label: Label
var _card_normal_style: StyleBoxFlat
var _card_selected_striker_style: StyleBoxFlat
var _card_selected_engineer_style: StyleBoxFlat

# Vertical menu (left side, COD-style)
var _title_label: Label
var _menu_container: VBoxContainer
var _menu_items: Array[Label] = []
var _menu_accent_bars: Array[ColorRect] = []
var _menu_index: int = 0
const _MENU_LABELS: Array[String] = ["CHOOSE ROLE", "ENEMIES"]
var _current_tab: String = "role"
const _TAB_ORDER: Array[String] = ["role", "enemies"]

# 3D viewport (hidden during pregame, shown in lobby)
var _stage_viewport_container: SubViewportContainer

# Back-to-pregame hint (shown only in lobby state)
var _back_hint: Label

# Enemies bestiary panel
var _enemies_panel: Control

var _glass_shader: Shader

# Title splash screen
var _splash: Control
var _splash_prompt: Label
var _splash_tween: Tween

# Navigation hints (shown next to menu)
var _nav_hints: Label

# On-screen keyboard for controller name entry
var _onscreen_kb: Control
var _kb_display: Label
var _kb_target: LineEdit
var _kb_first_key: Button
var _kb_caps: bool = false
var _kb_hints: Label


func _ready() -> void:
	# Always show the mouse cursor when entering the lobby
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_ensure_ui_joypad_mappings()

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_button.pressed.connect(_on_start_pressed)
	copy_button.pressed.connect(_on_copy_pressed)
	striker_button.pressed.connect(_on_striker_pressed)
	engineer_button.pressed.connect(_on_engineer_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	name_input.text_changed.connect(_on_name_changed)

	# Listen for networking events to update lobby state.
	Events.connection_established.connect(_on_connection_established)
	Events.player_joined.connect(_on_player_joined)
	Events.player_left.connect(_on_player_left)
	Events.connection_lost.connect(_on_connection_lost)

	# Grab the 3D lobby stage from the SubViewport
	_stage_viewport_container = get_node("StageViewportContainer") as SubViewportContainer
	var viewport := _stage_viewport_container.get_node("SubViewport")
	_lobby_stage_3d = viewport.get_node("LobbyStage3D")

	# Load blur shader for character select overlay, then style everything
	_glass_shader = load("res://shaders/glass_blur.gdshader")
	_setup_theme()
	_build_character_select()
	_build_enemies_panel()
	_build_title_splash()
	_build_onscreen_keyboard()

	if NetworkManager.is_returning_to_lobby:
		_setup_returning_lobby()
		NetworkManager.is_returning_to_lobby = false
	else:
		_setup_fresh_lobby()

	_update_role_buttons()
	_rebuild_player_stage()
	_load_version()


func _input(event: InputEvent) -> void:
	# Title splash: any press dismisses it
	if _splash and _splash.visible:
		var is_press := false
		if event is InputEventKey and event.pressed:
			is_press = true
		elif event is InputEventJoypadButton and event.pressed:
			is_press = true
		elif event is InputEventMouseButton and event.pressed:
			is_press = true
		if is_press:
			_dismiss_splash()
			get_viewport().set_input_as_handled()
			return

	# Keyboard input
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _current_tab == "lobby":
				SoundManager.play_ui_click()
				_switch_to_role_tab()
				get_viewport().set_input_as_handled()
				return
		# Up/Down arrow keys for pregame menu navigation
		if _current_tab != "lobby":
			if event.keycode == KEY_UP:
				SoundManager.play_ui_click()
				_prev_menu_item()
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_DOWN:
				SoundManager.play_ui_click()
				_next_menu_item()
				get_viewport().set_input_as_handled()
				return

	if not (event is InputEventJoypadButton and event.pressed):
		return

	# On-screen keyboard takes priority when visible.
	if _onscreen_kb and _onscreen_kb.visible:
		if event.button_index == JOY_BUTTON_A:
			var focused := get_viewport().gui_get_focus_owner()
			if focused is BaseButton and not focused.disabled:
				focused.emit_signal("pressed")
			elif _kb_first_key:
				_kb_first_key.grab_focus()
		elif event.button_index == JOY_BUTTON_X:
			_kb_backspace()
		elif event.button_index == JOY_BUTTON_LEFT_STICK:
			_kb_toggle_caps()
		elif event.button_index == JOY_BUTTON_Y or event.button_index == JOY_BUTTON_START:
			_hide_onscreen_keyboard()
		get_viewport().set_input_as_handled()
		return

	# Normal lobby input.
	if event.button_index == JOY_BUTTON_B:
		if _current_tab == "lobby":
			SoundManager.play_ui_click()
			_switch_to_role_tab()
			get_viewport().set_input_as_handled()
			return

	# D-pad and shoulder buttons for menu navigation (pregame only)
	if _current_tab != "lobby":
		if event.button_index == JOY_BUTTON_DPAD_DOWN or event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			SoundManager.play_ui_click()
			_next_menu_item()
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == JOY_BUTTON_DPAD_UP or event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			SoundManager.play_ui_click()
			_prev_menu_item()
			get_viewport().set_input_as_handled()
			return

	if event.button_index == JOY_BUTTON_A:
		_handle_gamepad_accept()
		if is_inside_tree():
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Smooth right-stick scrolling for enemies panel.
	if _current_tab == "enemies" and _enemies_panel and _enemies_panel.visible:
		var ry := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		if abs(ry) > 0.15:
			var scroll = _enemies_panel.get_node_or_null("EnemyScroll") as ScrollContainer
			if scroll:
				scroll.scroll_vertical += int(ry * 400.0 * delta)


func _handle_gamepad_accept() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused and focused.is_visible_in_tree():
		if focused is BaseButton and not focused.disabled:
			focused.emit_signal("pressed")
		elif focused is LineEdit:
			_show_onscreen_keyboard(focused)
		return
	# No control has focus — set it for the current tab.
	_grab_tab_default_focus()


func _grab_tab_default_focus() -> void:
	match _current_tab:
		"role":
			if _striker_select_btn and _striker_select_btn.is_visible_in_tree():
				_striker_select_btn.grab_focus()
			elif _engineer_select_btn and _engineer_select_btn.is_visible_in_tree():
				_engineer_select_btn.grab_focus()
		"lobby":
			if start_button.visible and start_button.is_visible_in_tree():
				start_button.grab_focus()
			elif host_button.visible and host_button.is_visible_in_tree():
				host_button.grab_focus()


func _next_menu_item() -> void:
	_menu_index = (_menu_index + 1) % _MENU_LABELS.size()
	_update_menu_highlight()
	_switch_to_tab(_TAB_ORDER[_menu_index])


func _prev_menu_item() -> void:
	_menu_index = (_menu_index - 1 + _MENU_LABELS.size()) % _MENU_LABELS.size()
	_update_menu_highlight()
	_switch_to_tab(_TAB_ORDER[_menu_index])


func _switch_to_tab(tab: String) -> void:
	match tab:
		"role": _switch_to_role_tab()
		"enemies": _switch_to_enemies_tab()
		"lobby": _switch_to_lobby_tab()


func _setup_fresh_lobby() -> void:
	start_button.visible = false
	room_code_container.visible = false
	leave_button.visible = false
	status_label.text = "Ready to host or join."
	role_label.text = "Role: None"
	# Show splash screen instead of going directly to menu
	_show_splash()


func _setup_returning_lobby() -> void:
	_is_host = multiplayer.is_server()
	_connected_player_count = NetworkManager.role_assignments.size()

	# Recover this peer's selected role and name
	var my_id := multiplayer.get_unique_id()
	_selected_role = NetworkManager.role_assignments.get(my_id, "")
	if _selected_role.is_empty():
		role_label.text = "Role: None"
	else:
		role_label.text = "Role: %s" % _selected_role.capitalize()
	role_description.text = ROLE_DESCRIPTIONS.get(_selected_role, "")
	var my_name: String = NetworkManager.player_names.get(my_id, "")
	if not my_name.is_empty():
		name_input.text = my_name

	# Already connected — hide host/join controls to keep panel compact
	host_button.visible = false
	join_button.get_parent().visible = false
	leave_button.visible = true

	if _is_host:
		var ip := NetworkManager.get_local_ip()
		_room_code = NetworkManager.ip_to_room_code(ip)
		room_code_label.text = "Room Code:  %s  (%s)" % [_room_code, ip]
		room_code_container.visible = true
		start_button.visible = _connected_player_count >= 1
		status_label.text = "Players connected: %d" % _connected_player_count
	else:
		room_code_container.visible = false
		start_button.visible = false
		status_label.text = "Connected. Waiting for host to start..."

	_switch_to_lobby_tab()
	if start_button.visible:
		_focus_after_frame(start_button)
	else:
		_focus_after_frame(leave_button)


# ── Theme Setup ───────────────────────────────────────────────────────────────

func _setup_theme() -> void:
	# ── Title label (top-left, COD-style) ──
	_title_label = get_node_or_null("TitleLabel") as Label
	if _title_label:
		_title_label.add_theme_color_override("font_color", TEXT_PRIMARY)
		_title_label.add_theme_font_size_override("font_size", 36)
		_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_title_label.anchor_left = 0
		_title_label.anchor_top = 0
		_title_label.anchor_right = 0
		_title_label.anchor_bottom = 0
		_title_label.offset_left = 60
		_title_label.offset_top = 40
		_title_label.offset_right = 500
		_title_label.offset_bottom = 90

	# ── Action buttons (Host, Join, Copy): frosted glass ──
	var act_n := _make_stylebox(
		Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.12), 1, 12)
	var act_h := _make_stylebox(
		Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.22),
		1, 12, Color(1, 1, 1, 0.06), 6)
	var act_p := _make_stylebox(
		Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.08), 1, 12)
	var btn_dis := _make_stylebox(
		Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.05), 1, 12)

	var act_f := _make_stylebox(
		Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.30), 2, 12,
		Color(1, 1, 1, 0.08), 6)

	for btn: Button in [host_button, join_button, copy_button]:
		btn.add_theme_stylebox_override("normal", act_n)
		btn.add_theme_stylebox_override("hover", act_h)
		btn.add_theme_stylebox_override("pressed", act_p)
		btn.add_theme_stylebox_override("disabled", btn_dis)
		btn.add_theme_stylebox_override("focus", act_f)
		btn.add_theme_color_override("font_color", TEXT_PRIMARY)
		btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
		btn.add_theme_color_override("font_disabled_color", TEXT_DISABLED)
		btn.add_theme_font_size_override("font_size", 16)
		btn.custom_minimum_size.y = 44

	# ── Start button: cyan glass, prominent ──
	var start_n := _make_stylebox(
		Color(0.08, 0.55, 0.75, 0.30), Color(0.15, 0.70, 0.95, 0.50),
		1, 14, Color(0.10, 0.55, 0.80, 0.12), 8)
	var start_h := _make_stylebox(
		Color(0.10, 0.65, 0.85, 0.40), Color(0.20, 0.80, 1.0, 0.65),
		1, 14, Color(0.15, 0.65, 0.90, 0.20), 12)
	var start_p := _make_stylebox(
		Color(0.06, 0.45, 0.65, 0.25), Color(0.12, 0.60, 0.85, 0.45), 1, 14)
	start_button.add_theme_stylebox_override("normal", start_n)
	start_button.add_theme_stylebox_override("hover", start_h)
	start_button.add_theme_stylebox_override("pressed", start_p)
	start_button.add_theme_stylebox_override("disabled", btn_dis)
	start_button.add_theme_color_override("font_color", Color(0.7, 0.95, 1.0, 1))
	start_button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	start_button.add_theme_color_override("font_disabled_color", TEXT_DISABLED)
	start_button.add_theme_font_size_override("font_size", 18)
	start_button.custom_minimum_size.y = 50
	var start_f := _make_stylebox(
		Color(0.08, 0.55, 0.75, 0.35), Color(0.15, 0.70, 0.95, 0.65),
		2, 14, Color(0.10, 0.55, 0.80, 0.15), 10)
	start_button.add_theme_stylebox_override("focus", start_f)

	# ── Role buttons (hidden, kept for refs) ──
	_striker_active_style = _make_stylebox(
		Color(0.91, 0.53, 0.17, 0.12), Color(0.91, 0.53, 0.17, 0.60),
		1, 12, Color(0.91, 0.53, 0.17, 0.08), 4)
	_engineer_active_style = _make_stylebox(
		Color(0.23, 0.77, 0.29, 0.12), Color(0.23, 0.77, 0.29, 0.60),
		1, 12, Color(0.23, 0.77, 0.29, 0.08), 4)

	# ── LineEdits: dark glass with subtle white border ──
	var le_n := StyleBoxFlat.new()
	le_n.bg_color = Color(0, 0, 0, 0.30)
	le_n.border_color = Color(1, 1, 1, 0.08)
	le_n.set_border_width_all(1)
	le_n.set_corner_radius_all(10)
	le_n.content_margin_left = 12.0
	le_n.content_margin_top = 6.0
	le_n.content_margin_right = 12.0
	le_n.content_margin_bottom = 6.0

	var le_f := StyleBoxFlat.new()
	le_f.bg_color = Color(0, 0, 0, 0.35)
	le_f.border_color = Color(1, 1, 1, 0.22)
	le_f.set_border_width_all(1)
	le_f.set_corner_radius_all(10)
	le_f.content_margin_left = 12.0
	le_f.content_margin_top = 6.0
	le_f.content_margin_right = 12.0
	le_f.content_margin_bottom = 6.0
	le_f.shadow_color = Color(1, 1, 1, 0.05)
	le_f.shadow_size = 4

	for le: LineEdit in [address_input, name_input]:
		le.add_theme_stylebox_override("normal", le_n)
		le.add_theme_stylebox_override("focus", le_f)
		le.add_theme_color_override("font_color", TEXT_PRIMARY)
		le.add_theme_color_override("font_placeholder_color", TEXT_SECONDARY)
		le.add_theme_font_size_override("font_size", 15)

	# ── Labels ──
	status_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	status_label.add_theme_font_size_override("font_size", 13)
	role_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	role_label.add_theme_font_size_override("font_size", 15)
	room_code_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	room_code_label.add_theme_font_size_override("font_size", 13)

	# ── Leave button: subtle glass outline, red on hover ──
	var leave_n := _make_stylebox(
		Color(0, 0, 0, 0), Color(0.80, 0.20, 0.20, 0.30), 1, 12)
	var leave_h := _make_stylebox(
		Color(0.80, 0.15, 0.15, 0.15), Color(0.85, 0.20, 0.20, 0.50),
		1, 12, Color(0.70, 0.12, 0.12, 0.08), 4)
	var leave_p := _make_stylebox(
		Color(0.60, 0.10, 0.10, 0.20), Color(0.70, 0.15, 0.15, 0.45), 1, 12)
	leave_button.add_theme_stylebox_override("normal", leave_n)
	leave_button.add_theme_stylebox_override("hover", leave_h)
	leave_button.add_theme_stylebox_override("pressed", leave_p)
	leave_button.add_theme_color_override("font_color", Color(0.80, 0.30, 0.30, 1))
	leave_button.add_theme_color_override("font_hover_color", Color(1.0, 0.40, 0.40, 1))
	leave_button.add_theme_font_size_override("font_size", 14)
	leave_button.custom_minimum_size.y = 38
	var leave_f := _make_stylebox(
		Color(0.80, 0.15, 0.15, 0.12), Color(0.85, 0.20, 0.20, 0.45),
		2, 12, Color(0.70, 0.12, 0.12, 0.06), 4)
	leave_button.add_theme_stylebox_override("focus", leave_f)


func _make_stylebox(bg: Color, border: Color, border_w: int, corner_r: int,
		shadow_col: Color = Color(0, 0, 0, 0), shadow_sz: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(corner_r)
	sb.content_margin_left = 14.0
	sb.content_margin_top = 6.0
	sb.content_margin_right = 14.0
	sb.content_margin_bottom = 6.0
	if shadow_sz > 0:
		sb.shadow_color = shadow_col
		sb.shadow_size = shadow_sz
	return sb


# ── Player Stage ──────────────────────────────────────────────────────────────

func _rebuild_player_stage() -> void:
	if not _lobby_stage_3d:
		return

	var roles: Dictionary = NetworkManager.role_assignments
	var names: Dictionary = NetworkManager.player_names

	# Show local player preview before hosting/joining
	if roles.is_empty():
		if _selected_role.is_empty():
			_lobby_stage_3d.set_players({}, {})
			return
		var preview_name := name_input.text.strip_edges()
		if preview_name.is_empty():
			preview_name = "You"
		roles = { 0: _selected_role }
		names = { 0: preview_name }

	_lobby_stage_3d.set_players(roles, names)


# ── Role Selection ────────────────────────────────────────────────────────────

func _on_striker_pressed() -> void:
	SoundManager.play_ui_click()
	_selected_role = "striker"
	role_label.text = "Role: Striker"
	role_description.text = ROLE_DESCRIPTIONS["striker"]
	_update_role_buttons()
	Events.role_selected.emit(multiplayer.get_unique_id(), "striker")
	if multiplayer.multiplayer_peer != null:
		_request_role.rpc_id(1, "striker")
	_rebuild_player_stage()


func _on_engineer_pressed() -> void:
	SoundManager.play_ui_click()
	_selected_role = "engineer"
	role_label.text = "Role: Engineer"
	role_description.text = ROLE_DESCRIPTIONS["engineer"]
	_update_role_buttons()
	Events.role_selected.emit(multiplayer.get_unique_id(), "engineer")
	if multiplayer.multiplayer_peer != null:
		_request_role.rpc_id(1, "engineer")
	_rebuild_player_stage()


func _update_role_buttons() -> void:
	if _selected_role == "striker":
		striker_button.disabled = true
		engineer_button.disabled = false
		if _striker_active_style:
			striker_button.add_theme_stylebox_override("disabled", _striker_active_style)
		engineer_button.remove_theme_stylebox_override("disabled")
	elif _selected_role == "engineer":
		striker_button.disabled = false
		engineer_button.disabled = true
		if _engineer_active_style:
			engineer_button.add_theme_stylebox_override("disabled", _engineer_active_style)
		striker_button.remove_theme_stylebox_override("disabled")
	else:
		striker_button.disabled = false
		engineer_button.disabled = false
		striker_button.remove_theme_stylebox_override("disabled")
		engineer_button.remove_theme_stylebox_override("disabled")


# ── Character Select & Tab Navigation ─────────────────────────────────────────

func _switch_to_role_tab() -> void:
	if not _char_select:
		return
	_current_tab = "role"
	_menu_index = 0
	_char_select.visible = true
	if _enemies_panel:
		_enemies_panel.visible = false
	var hud := get_node_or_null("BottomHUD")
	if hud:
		hud.visible = false
	# Hide 3D viewport in pregame, show menu
	if _stage_viewport_container:
		_stage_viewport_container.visible = false
	if _menu_container:
		_menu_container.visible = true
	if _title_label:
		_title_label.visible = true
	if _back_hint:
		_back_hint.visible = false
	if _nav_hints:
		_nav_hints.visible = true
	_update_menu_highlight()
	_update_character_select_cards()
	if _lobby_stage_3d:
		_lobby_stage_3d.set_host_label_visible(false)
	if _striker_select_btn:
		_focus_after_frame(_striker_select_btn)


func _switch_to_lobby_tab() -> void:
	if not _char_select:
		return
	_current_tab = "lobby"
	_char_select.visible = false
	if _enemies_panel:
		_enemies_panel.visible = false
	var hud := get_node_or_null("BottomHUD")
	if hud:
		hud.visible = true
	# Show 3D viewport, hide pregame menu
	if _stage_viewport_container:
		_stage_viewport_container.visible = true
	if _menu_container:
		_menu_container.visible = false
	if _title_label:
		_title_label.visible = false
	if _back_hint:
		_back_hint.visible = true
	if _nav_hints:
		_nav_hints.visible = false
	if _lobby_stage_3d:
		_lobby_stage_3d.set_host_label_visible(true)

	# Set up focus neighbors so the stick can navigate between panels.
	_setup_lobby_focus()

	# Give focus to a lobby button so the controller can navigate.
	if start_button.visible:
		_focus_after_frame(start_button)
	elif host_button.visible:
		_focus_after_frame(host_button)


func _switch_to_enemies_tab() -> void:
	if not _enemies_panel:
		return
	_current_tab = "enemies"
	_menu_index = 1
	_enemies_panel.visible = true
	_refresh_enemies_panel()
	if _char_select:
		_char_select.visible = false
	var hud := get_node_or_null("BottomHUD")
	if hud:
		hud.visible = false
	# Hide 3D viewport in pregame, show menu
	if _stage_viewport_container:
		_stage_viewport_container.visible = false
	if _menu_container:
		_menu_container.visible = true
	if _title_label:
		_title_label.visible = true
	if _back_hint:
		_back_hint.visible = false
	if _nav_hints:
		_nav_hints.visible = true
	_update_menu_highlight()
	if _lobby_stage_3d:
		_lobby_stage_3d.set_host_label_visible(false)


func _setup_lobby_focus() -> void:
	# Build ordered list of visible+focusable controls in the action panel.
	var right_controls: Array[Control] = []
	if host_button.visible:
		right_controls.append(host_button)
	if join_button.get_parent().visible:
		right_controls.append(address_input)
		right_controls.append(join_button)
	if room_code_container.visible:
		right_controls.append(copy_button)
	if start_button.visible:
		right_controls.append(start_button)
	if leave_button.visible:
		right_controls.append(leave_button)

	# Set up vertical focus neighbors in the right column.
	for i in range(right_controls.size()):
		var ctrl: Control = right_controls[i]
		if i > 0:
			ctrl.focus_neighbor_top = ctrl.get_path_to(right_controls[i - 1])
		if i < right_controls.size() - 1:
			ctrl.focus_neighbor_bottom = ctrl.get_path_to(right_controls[i + 1])

	# Connect left column (name_input) to right column.
	if right_controls.size() > 0:
		var first_right: Control = right_controls[0]
		name_input.focus_neighbor_right = name_input.get_path_to(first_right)
		name_input.focus_neighbor_bottom = name_input.get_path_to(first_right)
		first_right.focus_neighbor_left = first_right.get_path_to(name_input)


func _update_menu_highlight() -> void:
	for i in range(_menu_items.size()):
		if i == _menu_index:
			_menu_items[i].add_theme_font_size_override("font_size", 28)
			_menu_items[i].add_theme_color_override("font_color", Color.WHITE)
			_menu_accent_bars[i].visible = true
		else:
			_menu_items[i].add_theme_font_size_override("font_size", 22)
			_menu_items[i].add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			_menu_accent_bars[i].visible = false


func _on_select_striker() -> void:
	SoundManager.play_ui_click()
	_selected_role = "striker"
	role_label.text = "Role: Striker"
	_update_role_buttons()
	_update_character_select_cards()
	Events.role_selected.emit(multiplayer.get_unique_id(), "striker")
	if multiplayer.multiplayer_peer != null:
		_request_role.rpc_id(1, "striker")
	_rebuild_player_stage()
	_switch_to_lobby_tab()


func _on_select_engineer() -> void:
	SoundManager.play_ui_click()
	_selected_role = "engineer"
	role_label.text = "Role: Engineer"
	_update_role_buttons()
	_update_character_select_cards()
	Events.role_selected.emit(multiplayer.get_unique_id(), "engineer")
	if multiplayer.multiplayer_peer != null:
		_request_role.rpc_id(1, "engineer")
	_rebuild_player_stage()
	_switch_to_lobby_tab()


func _update_character_select_cards() -> void:
	if not _char_select:
		return

	if _selected_role == "striker":
		_striker_card.add_theme_stylebox_override("panel", _card_selected_striker_style)
		_engineer_card.add_theme_stylebox_override("panel", _card_normal_style)
		_striker_select_btn.text = "Selected — Play"
		_striker_select_btn.disabled = false
		_style_button_accent(_striker_select_btn, Color(1.0, 0.65, 0.25))
		_engineer_select_btn.text = "Select Engineer"
		_engineer_select_btn.disabled = false
		_style_button_accent(_engineer_select_btn, Color(0.231, 0.769, 0.290))
		_current_role_label.text = "Currently selected: Striker"
	elif _selected_role == "engineer":
		_striker_card.add_theme_stylebox_override("panel", _card_normal_style)
		_engineer_card.add_theme_stylebox_override("panel", _card_selected_engineer_style)
		_striker_select_btn.text = "Select Striker"
		_striker_select_btn.disabled = false
		_style_button_accent(_striker_select_btn, Color(0.910, 0.530, 0.169))
		_engineer_select_btn.text = "Selected — Play"
		_engineer_select_btn.disabled = false
		_style_button_accent(_engineer_select_btn, Color(0.35, 0.95, 0.40))
		_current_role_label.text = "Currently selected: Engineer"
	else:
		_striker_card.add_theme_stylebox_override("panel", _card_normal_style)
		_engineer_card.add_theme_stylebox_override("panel", _card_normal_style)
		_striker_select_btn.text = "Select Striker"
		_striker_select_btn.disabled = false
		_style_button_accent(_striker_select_btn, Color(0.910, 0.530, 0.169))
		_engineer_select_btn.text = "Select Engineer"
		_engineer_select_btn.disabled = false
		_style_button_accent(_engineer_select_btn, Color(0.231, 0.769, 0.290))
		_current_role_label.text = "Select a role to begin"


func _build_character_select() -> void:
	# -- Card styles: glassmorphism with subtle borders --
	_card_normal_style = StyleBoxFlat.new()
	_card_normal_style.bg_color = Color(0.18, 0.16, 0.28, 0.75)
	_card_normal_style.border_color = Color(1, 1, 1, 0.15)
	_card_normal_style.set_border_width_all(1)
	_card_normal_style.set_corner_radius_all(16)
	_card_normal_style.shadow_color = Color(0, 0, 0, 0.30)
	_card_normal_style.shadow_size = 12

	_card_selected_striker_style = StyleBoxFlat.new()
	_card_selected_striker_style.bg_color = Color(0.91, 0.53, 0.17, 0.08)
	_card_selected_striker_style.border_color = Color(0.91, 0.53, 0.17, 0.55)
	_card_selected_striker_style.set_border_width_all(1)
	_card_selected_striker_style.set_corner_radius_all(16)
	_card_selected_striker_style.shadow_color = Color(0.91, 0.53, 0.17, 0.12)
	_card_selected_striker_style.shadow_size = 10

	_card_selected_engineer_style = StyleBoxFlat.new()
	_card_selected_engineer_style.bg_color = Color(0.23, 0.77, 0.29, 0.08)
	_card_selected_engineer_style.border_color = Color(0.23, 0.77, 0.29, 0.55)
	_card_selected_engineer_style.set_border_width_all(1)
	_card_selected_engineer_style.set_corner_radius_all(16)
	_card_selected_engineer_style.shadow_color = Color(0.23, 0.77, 0.29, 0.12)
	_card_selected_engineer_style.shadow_size = 10

	# -- Character select panel (right side, no blur — dark bg behind) --
	_char_select = Control.new()
	_char_select.name = "CharacterSelect"
	_char_select.visible = false
	_char_select.set_anchors_preset(Control.PRESET_FULL_RECT)
	_char_select.offset_left = 250
	_char_select.offset_top = 80
	_char_select.offset_bottom = -40
	add_child(_char_select)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 60)
	_char_select.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 24)
	margin.add_child(main_vbox)

	# -- Current role label (above cards) --
	_current_role_label = Label.new()
	_current_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_current_role_label.add_theme_font_size_override("font_size", 16)
	_current_role_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	main_vbox.add_child(_current_role_label)

	# -- Card container --
	var card_container := HBoxContainer.new()
	card_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	card_container.add_theme_constant_override("separation", 40)
	main_vbox.add_child(card_container)

	# -- Striker card --
	var striker_color := Color(0.910, 0.530, 0.169)
	_striker_card = _build_role_card(
		"STRIKER", "Offensive Specialist", striker_color,
		"Weak Point Scan",
		"Expose enemies within 300px radius for 2x damage. Lasts 6s, 12s cooldown.",
		"Overdrive",
		"Double fire rate + damage and +20% move speed for 8s.",
		"+15% projectile damage",
		"Select Striker",
	)
	card_container.add_child(_striker_card)
	_striker_select_btn = _striker_card.get_meta("select_button")
	_striker_select_btn.pressed.connect(_on_select_striker)
	_style_button_accent(_striker_select_btn, striker_color)

	# -- Engineer card --
	var engineer_color := Color(0.231, 0.769, 0.290)
	_engineer_card = _build_role_card(
		"ENGINEER", "Support Specialist", engineer_color,
		"Deploy Turret",
		"Place an auto-targeting turret. Max 2 active, 15s cooldown.",
		"Healing Pulse",
		"Heal all teammates 50 HP, revive downed players, and remove debuffs.",
		"+20% stamina regen",
		"Select Engineer",
	)
	card_container.add_child(_engineer_card)
	_engineer_select_btn = _engineer_card.get_meta("select_button")
	_engineer_select_btn.pressed.connect(_on_select_engineer)
	_style_button_accent(_engineer_select_btn, engineer_color)

	# Focus neighbors between role select buttons for controller navigation.
	_striker_select_btn.focus_neighbor_right = _striker_select_btn.get_path_to(_engineer_select_btn)
	_engineer_select_btn.focus_neighbor_left = _engineer_select_btn.get_path_to(_striker_select_btn)

	# -- Vertical menu (left side, COD-style) --
	_menu_container = VBoxContainer.new()
	_menu_container.name = "MenuContainer"
	_menu_container.anchor_left = 0
	_menu_container.anchor_top = 0
	_menu_container.anchor_right = 0
	_menu_container.anchor_bottom = 0
	_menu_container.offset_left = 60
	_menu_container.offset_top = 120
	_menu_container.offset_right = 240
	_menu_container.offset_bottom = 300
	_menu_container.add_theme_constant_override("separation", 12)
	add_child(_menu_container)

	for i in range(_MENU_LABELS.size()):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_menu_container.add_child(row)

		# Left accent bar
		var accent_bar := ColorRect.new()
		accent_bar.custom_minimum_size = Vector2(4, 28)
		accent_bar.color = Color.WHITE
		accent_bar.visible = (i == 0)
		row.add_child(accent_bar)
		_menu_accent_bars.append(accent_bar)

		# Menu label
		var lbl := Label.new()
		lbl.text = _MENU_LABELS[i]
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if i == 0:
			lbl.add_theme_font_size_override("font_size", 28)
			lbl.add_theme_color_override("font_color", Color.WHITE)
		else:
			lbl.add_theme_font_size_override("font_size", 22)
			lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		row.add_child(lbl)
		_menu_items.append(lbl)

	# -- Navigation hints (below menu) --
	_nav_hints = Label.new()
	_nav_hints.name = "NavHints"
	_nav_hints.text = "↑↓  Navigate    Enter  Select"
	_nav_hints.anchor_left = 0
	_nav_hints.anchor_top = 0
	_nav_hints.anchor_right = 0
	_nav_hints.anchor_bottom = 0
	_nav_hints.offset_left = 60
	_nav_hints.offset_top = 200
	_nav_hints.offset_right = 300
	_nav_hints.offset_bottom = 220
	_nav_hints.add_theme_font_size_override("font_size", 13)
	_nav_hints.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	add_child(_nav_hints)

	# -- Back hint label (shown only in lobby state) --
	_back_hint = Label.new()
	_back_hint.text = "[Esc] Change Loadout"
	_back_hint.visible = false
	_back_hint.anchor_left = 0.0
	_back_hint.anchor_top = 0.0
	_back_hint.offset_left = 20
	_back_hint.offset_top = 20
	_back_hint.add_theme_font_size_override("font_size", 14)
	_back_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	add_child(_back_hint)

	_update_character_select_cards()


func _build_role_card(role_name: String, subtitle: String, accent: Color,
		ability_name: String, ability_desc: String,
		super_name: String, super_desc: String,
		passive_text: String, button_text: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 0)
	card.size_flags_vertical = 0

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 20)
	card_margin.add_theme_constant_override("margin_top", 0)
	card_margin.add_theme_constant_override("margin_right", 20)
	card_margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(card_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card_margin.add_child(vbox)

	# Color bar at top
	var color_bar := ColorRect.new()
	color_bar.color = accent
	color_bar.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(color_bar)

	# Role name
	var name_label := Label.new()
	name_label.text = role_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	vbox.add_child(name_label)

	# Subtitle
	var sub_label := Label.new()
	sub_label.text = subtitle
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_size_override("font_size", 14)
	sub_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	vbox.add_child(sub_label)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	vbox.add_child(sep)

	# Ability section
	_add_card_section(vbox, "ABILITY", accent, ability_name, ability_desc)

	# Super section
	_add_card_section(vbox, "SUPER", accent, super_name, super_desc)

	# Passive section
	var passive_header := Label.new()
	passive_header.text = "PASSIVE"
	passive_header.add_theme_font_size_override("font_size", 12)
	passive_header.add_theme_color_override("font_color", accent)
	vbox.add_child(passive_header)

	var passive_label := Label.new()
	passive_label.text = passive_text
	passive_label.add_theme_font_size_override("font_size", 16)
	passive_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	vbox.add_child(passive_label)


	# Select button
	var select_btn := Button.new()
	select_btn.text = button_text
	select_btn.custom_minimum_size = Vector2(0, 44)
	vbox.add_child(select_btn)

	card.set_meta("select_button", select_btn)
	return card


func _add_card_section(parent: VBoxContainer, header: String, accent: Color,
		title: String, desc: String) -> void:
	var header_label := Label.new()
	header_label.text = header
	header_label.add_theme_font_size_override("font_size", 12)
	header_label.add_theme_color_override("font_color", accent)
	parent.add_child(header_label)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", TEXT_PRIMARY)
	parent.add_child(title_lbl)

	var desc_label := Label.new()
	desc_label.text = desc
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(desc_label)


func _style_button_accent(btn: Button, accent: Color) -> void:
	var normal := _make_stylebox(
		Color(accent.r, accent.g, accent.b, 0.12),
		Color(accent.r, accent.g, accent.b, 0.35), 1, 14,
		Color(accent.r, accent.g, accent.b, 0.06), 4)
	var hover := _make_stylebox(
		Color(accent.r, accent.g, accent.b, 0.22),
		Color(accent.r, accent.g, accent.b, 0.50), 1, 14,
		Color(accent.r, accent.g, accent.b, 0.12), 8)
	var disabled := _make_stylebox(
		Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.05), 1, 14)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", TEXT_DISABLED)
	btn.add_theme_font_size_override("font_size", 16)
	btn.custom_minimum_size.y = 48
	var focus_style := _make_stylebox(
		Color(accent.r, accent.g, accent.b, 0.18),
		Color(accent.r, accent.g, accent.b, 0.65), 2, 14,
		Color(accent.r, accent.g, accent.b, 0.10), 6)
	btn.add_theme_stylebox_override("focus", focus_style)


# ── Enemy Bestiary ─────────────────────────────────────────────────────────────

func _build_enemies_panel() -> void:
	_enemies_panel = Control.new()
	_enemies_panel.name = "EnemiesPanel"
	_enemies_panel.visible = false
	_enemies_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_enemies_panel.offset_left = 250
	_enemies_panel.offset_top = 80
	_enemies_panel.offset_bottom = -40
	add_child(_enemies_panel)

	# Scroll container for the card list
	var scroll := ScrollContainer.new()
	scroll.name = "EnemyScroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_enemies_panel.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "EnemyList"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Build one card per enemy
	for data in ENEMY_DATA:
		var card := _build_enemy_card(data)
		vbox.add_child(card)


func _build_enemy_card(data: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_normal_style)
	card.set_meta("enemy_wave", data["wave"])
	card.set_meta("enemy_description", data["description"])
	card.set_meta("enemy_accent", data["accent"])

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 16)
	card_margin.add_theme_constant_override("margin_top", 16)
	card_margin.add_theme_constant_override("margin_right", 16)
	card_margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(card_margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	card_margin.add_child(hbox)

	# Enemy sprite (64x64)
	var sprite_rect := TextureRect.new()
	sprite_rect.name = "Sprite"
	sprite_rect.custom_minimum_size = Vector2(64, 64)
	sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex := load(data["sprite"]) as Texture2D
	if tex:
		sprite_rect.texture = tex
	hbox.add_child(sprite_rect)

	# Right side: name, wave tag, description
	var info_vbox := VBoxContainer.new()
	info_vbox.name = "Info"
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)

	# Top row: name + wave/boss tag
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	info_vbox.add_child(top_row)

	var accent: Color = data["accent"]
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = data["name"]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", accent)
	top_row.add_child(name_label)

	var wave_tag := Label.new()
	wave_tag.name = "WaveTag"
	if data["is_boss"]:
		wave_tag.text = "BOSS — Wave %d" % data["wave"]
	else:
		wave_tag.text = "Wave %d" % data["wave"]
	wave_tag.add_theme_font_size_override("font_size", 12)
	wave_tag.add_theme_color_override("font_color", TEXT_SECONDARY)
	top_row.add_child(wave_tag)

	# Description
	var desc_label := Label.new()
	desc_label.text = data["description"]
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_label)

	# Store direct node refs for _refresh_enemies_panel
	card.set_meta("ref_sprite", sprite_rect)
	card.set_meta("ref_name", name_label)
	card.set_meta("ref_desc", desc_label)

	return card


func _refresh_enemies_panel() -> void:
	if not _enemies_panel:
		return
	var scroll := _enemies_panel.get_node_or_null("EnemyScroll")
	if not scroll:
		return
	# MarginContainer is the first (only) child of ScrollContainer
	var margin := scroll.get_child(0) if scroll.get_child_count() > 0 else null
	if not margin:
		return
	var vbox := margin.get_node_or_null("EnemyList")
	if not vbox:
		return

	var highest: int = NetworkManager.highest_wave_reached
	for card in vbox.get_children():
		if not card is PanelContainer:
			continue
		var unlock_wave: int = card.get_meta("enemy_wave")
		var unlocked := highest >= unlock_wave

		var sprite: TextureRect = card.get_meta("ref_sprite")
		var name_lbl: Label = card.get_meta("ref_name")
		var desc_lbl: Label = card.get_meta("ref_desc")

		if unlocked:
			if sprite:
				sprite.modulate = Color(1, 1, 1, 1)
			if name_lbl:
				name_lbl.modulate = Color(1, 1, 1, 1)
				name_lbl.add_theme_color_override("font_color", card.get_meta("enemy_accent"))
			if desc_lbl:
				desc_lbl.text = card.get_meta("enemy_description")
				desc_lbl.add_theme_color_override("font_color", TEXT_SECONDARY)
		else:
			if sprite:
				sprite.modulate = Color(0.25, 0.25, 0.25, 0.6)
			if name_lbl:
				name_lbl.modulate = Color(0.5, 0.5, 0.5, 0.7)
				name_lbl.add_theme_color_override("font_color", TEXT_DISABLED)
			if desc_lbl:
				desc_lbl.text = "Reach wave %d to unlock" % unlock_wave
				desc_lbl.add_theme_color_override("font_color", TEXT_DISABLED)


@rpc("any_peer", "call_local", "reliable")
func _request_role(role_name: String) -> void:
	if not multiplayer.is_server():
		return
	if role_name not in ["striker", "engineer"]:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1  # Local call from host
	NetworkManager.role_assignments[sender_id] = role_name
	# Sync ALL roles to ALL peers so everyone sees every player
	for pid in NetworkManager.role_assignments:
		_confirm_role.rpc(pid, NetworkManager.role_assignments[pid])
	print("Lobby: Player %d selected role '%s'" % [sender_id, role_name])


@rpc("authority", "call_local", "reliable")
func _confirm_role(player_id: int, role_name: String) -> void:
	NetworkManager.role_assignments[player_id] = role_name
	Events.role_assigned.emit(player_id, role_name)
	_rebuild_player_stage()


# ── Name Sync ─────────────────────────────────────────────────────────────────

func _on_name_changed(new_text: String) -> void:
	var display_name := new_text.strip_edges()
	if display_name.is_empty():
		display_name = "Player %d" % multiplayer.get_unique_id()
	NetworkManager.player_names[multiplayer.get_unique_id()] = display_name
	if multiplayer.multiplayer_peer != null:
		_request_name.rpc_id(1, display_name)
	_rebuild_player_stage()


@rpc("any_peer", "call_local", "reliable")
func _request_name(display_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	NetworkManager.player_names[sender_id] = display_name
	# Sync all names to all peers
	for pid in NetworkManager.player_names:
		_confirm_name.rpc(pid, NetworkManager.player_names[pid])


@rpc("authority", "call_local", "reliable")
func _confirm_name(player_id: int, display_name: String) -> void:
	NetworkManager.player_names[player_id] = display_name
	_rebuild_player_stage()


# ── Button Handlers ────────────────────────────────────────────────────────────

func _on_host_pressed() -> void:
	SoundManager.play_ui_click()
	var error := NetworkManager.host_game()
	if error != OK:
		status_label.text = "Failed to host: %s" % error_string(error)
		return

	_is_host = true
	_connected_player_count = 1  # Host counts as first player.
	var ip := NetworkManager.get_local_ip()
	_room_code = NetworkManager.ip_to_room_code(ip)
	room_code_label.text = "Room Code:  %s  (%s)" % [_room_code, ip]
	room_code_container.visible = true
	status_label.text = "Waiting for players..."
	start_button.visible = true

	# Hide host/join controls to keep panel compact
	host_button.visible = false
	join_button.get_parent().visible = false

	# Register host's role and name (if selected)
	if not _selected_role.is_empty():
		NetworkManager.role_assignments[1] = _selected_role
	var host_name := name_input.text.strip_edges()
	if host_name.is_empty():
		host_name = "Player 1"
	NetworkManager.player_names[1] = host_name
	leave_button.visible = true
	_rebuild_player_stage()

	# Give focus to start button so controller highlight stays visible.
	_focus_after_frame(start_button)


func _on_join_pressed() -> void:
	SoundManager.play_ui_click()
	var input_text := address_input.text.strip_edges()
	if input_text.is_empty():
		status_label.text = "Enter a room code or IP address."
		return

	var ip: String
	var port: int = NetworkManager.DEFAULT_PORT

	# If it contains a dot, treat as IP address. Otherwise, treat as room code.
	if "." in input_text:
		var parts := input_text.split(":")
		ip = parts[0]
		if parts.size() > 1:
			port = parts[1].to_int()
	else:
		ip = NetworkManager.room_code_to_ip(input_text)
		if ip.is_empty():
			status_label.text = "Invalid room code. Try again."
			return

	var error := NetworkManager.join_game(ip, port)
	if error != OK:
		status_label.text = "Failed to join: %s" % error_string(error)
		return

	status_label.text = "Connecting..."
	host_button.visible = false
	join_button.get_parent().visible = false


func _on_copy_pressed() -> void:
	SoundManager.play_ui_click()
	DisplayServer.clipboard_set(_room_code)
	copy_button.text = "Copied!"
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(copy_button):
		copy_button.text = "Copy"


func _on_leave_pressed() -> void:
	SoundManager.play_ui_click()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	NetworkManager.peer = null
	NetworkManager.role_assignments.clear()
	NetworkManager.player_names.clear()
	NetworkManager.is_returning_to_lobby = false

	# Reset to fresh lobby state
	_is_host = false
	_connected_player_count = 0
	_room_code = ""
	_selected_role = ""
	host_button.visible = true
	join_button.get_parent().visible = true
	leave_button.visible = false
	_setup_fresh_lobby()
	_rebuild_player_stage()


func _on_start_pressed() -> void:
	SoundManager.play_ui_click()
	SoundManager.stop_lobby_music()
	# Only the host triggers the scene change.
	if not _is_host:
		return
	# Tell all clients to change scene, then change locally.
	_change_scene_all_peers.rpc("res://scenes/game.tscn")


@rpc("authority", "call_local", "reliable")
func _change_scene_all_peers(scene_path: String) -> void:
	SoundManager.stop_lobby_music()
	get_tree().change_scene_to_file(scene_path)


# ── Event Handlers ─────────────────────────────────────────────────────────────

func _on_connection_established(_peer_id: int, is_host: bool) -> void:
	if not is_host:
		status_label.text = "Connected to server!"
		_connected_player_count = 1  # We'll get accurate count from player_joined signals.
		leave_button.visible = true
		# Send role and name to server (if selected)
		if not _selected_role.is_empty():
			_request_role.rpc_id(1, _selected_role)
		var my_name := name_input.text.strip_edges()
		if my_name.is_empty():
			my_name = "Player %d" % multiplayer.get_unique_id()
		_request_name.rpc_id(1, my_name)
	_rebuild_player_stage()


func _on_player_joined(_player_id: int, _spawn_position: Vector2) -> void:
	_connected_player_count += 1
	_update_lobby_status()
	_rebuild_player_stage()


func _on_player_left(_player_id: int) -> void:
	_connected_player_count = maxi(_connected_player_count - 1, 1)
	_update_lobby_status()
	_rebuild_player_stage()


func _on_connection_lost(_peer_id: int, reason: String) -> void:
	if reason == "peer_disconnected":
		# A single peer left — don't reset the whole lobby.
		# NetworkManager already erased their role_assignment.
		if multiplayer.is_server():
			_connected_player_count = NetworkManager.role_assignments.size()
			_update_lobby_status()
			_rebuild_player_stage()
		return

	# Server disconnected or connection failed — full reset.
	_selected_role = ""
	status_label.text = "Connection lost: %s" % reason
	start_button.visible = false
	room_code_container.visible = false
	leave_button.visible = false
	_room_code = ""
	host_button.visible = true
	join_button.get_parent().visible = true
	_connected_player_count = 0
	_is_host = false
	role_label.text = "Role: None"
	_switch_to_role_tab()
	_rebuild_player_stage()


# ── Helpers ────────────────────────────────────────────────────────────────────

func _load_version() -> void:
	var config := ConfigFile.new()
	if config.load("res://version.cfg") == OK:
		var ver: String = config.get_value("version", "version", "0.0.0")
		version_label.text = "v%s" % ver
	else:
		version_label.text = ""


func _focus_after_frame(ctrl: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(ctrl) and ctrl.is_visible_in_tree():
		ctrl.grab_focus()


func _ensure_ui_joypad_mappings() -> void:
	# Godot's built-in ui_* actions don't include gamepad by default.
	# Add A button to ui_accept and left stick to ui navigation.
	var accept_ev := InputEventJoypadButton.new()
	accept_ev.button_index = JOY_BUTTON_A
	accept_ev.device = -1
	InputMap.action_add_event("ui_accept", accept_ev)

	var cancel_ev := InputEventJoypadButton.new()
	cancel_ev.button_index = JOY_BUTTON_B
	cancel_ev.device = -1
	InputMap.action_add_event("ui_cancel", cancel_ev)

	var axes := [
		["ui_up", JOY_AXIS_LEFT_Y, -1.0],
		["ui_down", JOY_AXIS_LEFT_Y, 1.0],
		["ui_left", JOY_AXIS_LEFT_X, -1.0],
		["ui_right", JOY_AXIS_LEFT_X, 1.0],
	]
	for mapping in axes:
		var ev := InputEventJoypadMotion.new()
		ev.axis = mapping[1]
		ev.axis_value = mapping[2]
		ev.device = -1
		InputMap.action_add_event(mapping[0], ev)


# ── Title Splash ───────────────────────────────────────────────────────────────

func _build_title_splash() -> void:
	_splash = Control.new()
	_splash.name = "TitleSplash"
	_splash.visible = false
	_splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_splash.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_splash)

	# Dark overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.02, 0.05, 0.95)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash.add_child(overlay)

	# Center container for title + prompt
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -500
	center.offset_top = -100
	center.offset_right = 500
	center.offset_bottom = 100
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 30)
	_splash.add_child(center)

	# Game title
	var title := Label.new()
	title.text = "SEGFAULT: FATAL EXCEPTION 1"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color.WHITE)
	center.add_child(title)

	# "Press any button" prompt
	_splash_prompt = Label.new()
	_splash_prompt.text = "PRESS ANY BUTTON"
	_splash_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_splash_prompt.add_theme_font_size_override("font_size", 18)
	_splash_prompt.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	center.add_child(_splash_prompt)


func _show_splash() -> void:
	if not _splash:
		_switch_to_role_tab()
		return
	_splash.visible = true
	# Hide pregame UI behind splash
	if _char_select:
		_char_select.visible = false
	if _enemies_panel:
		_enemies_panel.visible = false
	if _menu_container:
		_menu_container.visible = false
	if _title_label:
		_title_label.visible = false
	if _stage_viewport_container:
		_stage_viewport_container.visible = false
	if _nav_hints:
		_nav_hints.visible = false
	var hud := get_node_or_null("BottomHUD")
	if hud:
		hud.visible = false
	# Pulse animation on the prompt
	_start_splash_pulse()


func _start_splash_pulse() -> void:
	if _splash_tween:
		_splash_tween.kill()
	_splash_tween = create_tween().set_loops()
	_splash_tween.tween_property(_splash_prompt, "modulate:a", 0.3, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_splash_tween.tween_property(_splash_prompt, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _dismiss_splash() -> void:
	SoundManager.play_ui_click()
	SoundManager.play_lobby_music()
	if _splash_tween:
		_splash_tween.kill()
		_splash_tween = null
	if _splash:
		_splash.visible = false
	_switch_to_role_tab()


# ── On-Screen Keyboard ─────────────────────────────────────────────────────────

func _build_onscreen_keyboard() -> void:
	_onscreen_kb = Control.new()
	_onscreen_kb.name = "OnscreenKeyboard"
	_onscreen_kb.visible = false
	_onscreen_kb.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_onscreen_kb)

	# Dark overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_onscreen_kb.add_child(overlay)

	# Center panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -230
	panel.offset_top = -150
	panel.offset_right = 230
	panel.offset_bottom = 150
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.06, 0.14, 0.95)
	panel_style.border_color = Color(1, 1, 1, 0.15)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_right = 16
	panel_style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", panel_style)
	_onscreen_kb.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Current text display
	_kb_display = Label.new()
	_kb_display.text = ""
	_kb_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kb_display.add_theme_font_size_override("font_size", 22)
	_kb_display.add_theme_color_override("font_color", TEXT_PRIMARY)
	vbox.add_child(_kb_display)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Key grid (10 columns × 4 rows)
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	vbox.add_child(grid)

	var key_style := _make_stylebox(
		Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.15), 1, 6)
	var key_focus := _make_stylebox(
		Color(0.2, 0.6, 1.0, 0.20), Color(0.3, 0.7, 1.0, 0.60), 2, 6,
		Color(0.2, 0.6, 1.0, 0.10), 4)

	var rows := [
		["1","2","3","4","5","6","7","8","9","0"],
		["Q","W","E","R","T","Y","U","I","O","P"],
		["A","S","D","F","G","H","J","K","L","←"],
		["Z","X","C","V","B","N","M",".","SP","OK"],
	]

	var first := true
	for row in rows:
		for key in row:
			var btn := Button.new()
			if key == "←":
				btn.text = "←"
				btn.pressed.connect(_kb_backspace)
			elif key == "OK":
				btn.text = "OK"
				btn.pressed.connect(_hide_onscreen_keyboard)
			elif key == "SP":
				btn.text = "SP"
				btn.pressed.connect(_on_kb_char.bind(" "))
			else:
				btn.text = key
				btn.pressed.connect(_on_kb_char.bind(key))
			btn.custom_minimum_size = Vector2(38, 34)
			btn.add_theme_stylebox_override("normal", key_style)
			btn.add_theme_stylebox_override("focus", key_focus)
			btn.add_theme_font_size_override("font_size", 14)
			btn.add_theme_color_override("font_color", TEXT_PRIMARY)
			grid.add_child(btn)
			if first:
				_kb_first_key = btn
				first = false

	# Hint labels
	_kb_hints = Label.new()
	_kb_hints.text = "A: Type   X: Delete   Y: Done   L3: CAPS"
	_kb_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kb_hints.add_theme_font_size_override("font_size", 12)
	_kb_hints.add_theme_color_override("font_color", TEXT_SECONDARY)
	vbox.add_child(_kb_hints)


func _show_onscreen_keyboard(target: LineEdit) -> void:
	_kb_target = target
	_kb_display.text = target.text if not target.text.is_empty() else ""
	_onscreen_kb.visible = true
	# Hide lobby controls so focus stays on keyboard keys.
	var hud := get_node_or_null("BottomHUD")
	if hud:
		hud.visible = false
	if _kb_first_key:
		_kb_first_key.grab_focus()


func _hide_onscreen_keyboard() -> void:
	if _kb_target and is_instance_valid(_kb_target):
		_kb_target.text = _kb_display.text
		_kb_target.text_changed.emit(_kb_display.text)
	_onscreen_kb.visible = false
	_kb_target = null
	# Restore lobby UI.
	var hud := get_node_or_null("BottomHUD")
	if hud:
		hud.visible = true
	_grab_tab_default_focus()


func _on_kb_char(c: String) -> void:
	var max_len: int = 12
	if _kb_target and _kb_target.max_length > 0:
		max_len = _kb_target.max_length
	if _kb_display.text.length() < max_len:
		var ch := c.to_upper() if _kb_caps else c.to_lower()
		_kb_display.text += ch


func _kb_backspace() -> void:
	if _kb_display.text.length() > 0:
		_kb_display.text = _kb_display.text.substr(0, _kb_display.text.length() - 1)


func _kb_toggle_caps() -> void:
	_kb_caps = not _kb_caps
	if _kb_hints:
		if _kb_caps:
			_kb_hints.text = "A: Type   X: Delete   Y: Done   L3: caps"
		else:
			_kb_hints.text = "A: Type   X: Delete   Y: Done   L3: CAPS"


func _update_lobby_status() -> void:
	status_label.text = "Players connected: %d" % _connected_player_count
	# Show start button only for the host when at least 2 players are present.
	start_button.visible = _is_host and _connected_player_count >= 1
