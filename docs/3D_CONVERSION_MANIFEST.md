# 3D Conversion Manifest

Exhaustive file-by-file analysis of every 2D-specific element that must change for the 2D-to-3D conversion. Each file lists the exact lines, what must change, the 3D equivalent, pure logic that stays, and overall complexity.

---

## Table of Contents

1. [player.gd](#playergd)
2. [game_manager.gd](#game_managergd)
3. [wave_manager.gd](#wave_managergd)
4. [ability_manager.gd](#ability_managergd)
5. [revive_system.gd](#revive_systemgd)
6. [enemy_base.gd](#enemy_basegd)
7. [enemy_merge_conflict.gd](#enemy_merge_conflictgd)
8. [enemy_hallucination.gd](#enemy_hallucinationgd)
9. [enemy_context_rot.gd](#enemy_context_rotgd)
10. [enemy_dependency_hell.gd](#enemy_dependency_hellgd)
11. [enemy_kernel_panic.gd](#enemy_kernel_panickgd)
12. [ability_weak_point_scan.gd](#ability_weak_point_scangd)
13. [ability_deploy_turret.gd](#ability_deploy_turretgd)
14. [super_overdrive.gd](#super_overdrivegd)
15. [super_healing_pulse.gd](#super_healing_pulsegd)
16. [turret.gd](#turretgd)
17. [projectile.gd](#projectilegd)
18. [projectile_enemy.gd](#projectile_enemygd)
19. [events.gd](#eventsgd)
20. [network_manager.gd](#network_managergd)
21. [sound_manager.gd](#sound_managergd)
22. [lobby.gd](#lobbygd)
23. [lobby_stage_3d.gd](#lobby_stage_3dgd)
24. [game.tscn](#gametscn)
25. [player.tscn](#playertscn)
26. [lobby.tscn](#lobbytscn)
27. [lobby_stage_3d.tscn](#lobby_stage_3dtscn)
28. [Enemy .tscn files](#enemy-tscn-files)
29. [turret.tscn](#turrettscn)
30. [projectile.tscn / projectile_enemy.tscn](#projectile-tscn-files)
31. [project.godot](#projectgodot)

---

## player.gd

**File**: `scripts/player.gd`
**Complexity**: HARD
**Root node type change**: `CharacterBody2D` -> `CharacterBody3D`

### 2D-Specific Code That Must Change

| Line(s) | Current (2D) | 3D Equivalent | Notes |
|---------|-------------|---------------|-------|
| 1 | Comment: `CharacterBody2D` | Update comment | |
| 4 | `extends CharacterBody2D` | `extends CharacterBody3D` | Core type change |
| 30-33 | `TEX_*` sprite texture paths | 3D model paths or `MeshInstance3D` references | Sprites replaced by 3D models |
| 55 | `input_move_dir: Vector2 = Vector2.ZERO` | `input_move_dir: Vector2 = Vector2.ZERO` | **KEEP AS-IS** -- input stays 2D (XZ plane mapped from XY) |
| 56 | `input_aim_dir: Vector2 = Vector2.RIGHT` | `input_aim_dir: Vector2 = Vector2.RIGHT` | **KEEP AS-IS** -- aim stays 2D (top-down angle on XZ plane) |
| 65-66 | `_facing` uses `input_aim_dir.x` | Same logic, still works for XZ plane | |
| 92 | `$Camera2D.make_current()` | `$Camera3D.make_current()` -- use a 3D camera (likely overhead or third-person) | Camera setup completely different |
| 94-97 | `collision_layer = 2`, `collision_mask = 5` | Same layer/mask values but on 3D collision layers | |
| 109 | `$Sprite2D.rotation = input_aim_dir.angle()` | Rotate 3D model on Y axis: `$Model.rotation.y = -input_aim_dir.angle()` (or use `look_at`) | Sprite rotation -> model rotation |
| 139, 151 | `input_move_dir = Vector2(move_x, move_y)` | Keep as Vector2, convert to Vector3 for velocity: `Vector3(input_move_dir.x, 0, input_move_dir.y)` | |
| 157-160 | Right stick `Vector2` | Same (input is still 2D) | **KEEP** |
| 174 | `get_global_mouse_position() - global_position` | Need raycast from camera through mouse position to XZ ground plane | **TRICKY** -- requires `Camera3D.project_ray_normal()` + plane intersection |
| 231 | `velocity = input_move_dir * current_speed` | `velocity = Vector3(input_move_dir.x, 0, input_move_dir.y) * current_speed` | 2D velocity -> 3D velocity on XZ plane |
| 246 | `move_and_slide()` | Same method, works on `CharacterBody3D` | **KEEP** |
| 292 | `$ShootPoint.position = input_aim_dir * 20.0` | `$ShootPoint.position = Vector3(input_aim_dir.x, 0.5, input_aim_dir.y) * 20.0` | Offset from ground |
| 294 | `var spawn_pos: Vector2 = $ShootPoint.global_position` | `var spawn_pos: Vector3 = $ShootPoint.global_position` | |
| 307 | `projectile.position = spawn_pos` | Same, but `Vector3` | |
| 329 | `if not enemy is Node2D` | `if not enemy is Node3D` | |
| 332 | `var to_enemy: Vector2 = enemy.global_position - global_position` | `var to_enemy: Vector3 = enemy.global_position - global_position` then use XZ distance | |
| 333 | `to_enemy.normalized().dot(input_aim_dir)` | Project to XZ: `Vector2(to_enemy.x, to_enemy.z).normalized().dot(input_aim_dir)` | |
| 334 | `to_enemy.length()` | Use XZ length or full 3D distance | |
| 343-356 | `_show_melee_visual` -- creates `ColorRect` at 2D position | Replace with 3D mesh/particle effect | Visual overhaul |
| 345 | `swing.size = Vector2(80, 60)` | 3D mesh dimensions | |
| 349-350 | `swing.position = aim_dir * 8.0 - Vector2(0, 30)`, `swing.rotation = aim_dir.angle()` | 3D position + rotation | |
| 360-371 | `_show_overdrive_visual` -- `ColorRect` 44x44 | 3D glow/particle effect | |
| 365 | `visual.size = Vector2(44, 44)`, `position = Vector2(-22, -22)` | 3D mesh/shader | |
| 375-385 | `_show_healing_visual` -- `ColorRect` 40x40 | 3D particle/glow | |
| 389-399 | `_show_scan_visual(center: Vector2, radius: float)` | `_show_scan_visual(center: Vector3, radius: float)` + 3D circle/sphere mesh | |
| 393 | `visual.size = Vector2(radius * 2, radius * 2)`, `position = center - Vector2(radius, radius)` | Create a flat 3D disc mesh or a cylinder | |
| 460 | `velocity = Vector2.ZERO` | `velocity = Vector3.ZERO` | |
| 461 | `Events.player_downed.emit(player_id, global_position)` | `global_position` is now Vector3 -- update signal signature or convert | |
| 464 | `get_node_or_null("CollisionShape2D")` | `get_node_or_null("CollisionShape3D")` | |
| 474 | `get_node_or_null("Sprite2D") as Sprite2D` | `get_node_or_null("Model") as Node3D` (or `MeshInstance3D`) | |
| 476-477 | `sprite.texture = load(TEX_DOWNED)`, `sprite.modulate` | Change material/color on 3D model | |
| 482-488 | `_set_role_color` -- Sprite2D texture swap | 3D model material swap | |

### Pure Logic That Stays As-Is
- Sprint/stamina system (lines 209-227)
- Shoot cooldown / auto-fire system (lines 256-285)
- Health/damage/die/bleedout logic (lines 443-508)
- Status effects system (lines 510-552)
- HUD update logic (lines 402-441) -- all CanvasLayer/Control UI stays 2D
- Input gathering (most of it -- WASD, controller detection)
- One-shot input consumption pattern
- Multiplayer authority/server checks

---

## game_manager.gd

**File**: `scripts/game_manager.gd`
**Complexity**: MEDIUM
**Root node type change**: `extends Node2D` -> `extends Node3D`

### 2D-Specific Code That Must Change

| Line(s) | Current (2D) | 3D Equivalent | Notes |
|---------|-------------|---------------|-------|
| 4 | `extends Node2D` | `extends Node3D` | |
| 9-14 | `PLAYER_SPAWN_POSITIONS: Array[Vector2]` with `Vector2(500,300)` etc. | `Array[Vector3]` with positions on XZ plane, e.g., `Vector3(5, 0, 3)` | Need to decide 3D arena scale |
| 92 | `_repo_owner_label.size = Vector2(96, 24)` | Stays (it's UI) | **KEEP** |
| 108 | `var screen_pos: Vector2 = host_player.get_global_transform_with_canvas().origin` | In 3D, use camera `unproject_position()` to convert 3D world pos -> 2D screen pos | **TRICKY** |
| 109 | `_repo_owner_label.position = screen_pos + Vector2(-48, -50)` | Same approach after camera projection | |
| 170 | `player.position = PLAYER_SPAWN_POSITIONS[spawn_index]` | Now `Vector3` | |
| 186 | `Events.player_joined.emit(peer_id, player.position)` | `player.position` is `Vector3` now -- update signal or convert | |
| 193 | `func _setup_player_abilities(player: CharacterBody2D, role: String)` | `CharacterBody3D` | |
| 294 | `func _apply_snapshot_to_player(player_node: CharacterBody2D, ...)` | `CharacterBody3D` | |

### Pure Logic That Stays As-Is
- Player spawning logic (names, peer IDs, roles)
- Host migration snapshot system
- Return-to-lobby flow
- All HUD/UI code (CanvasLayer is dimension-agnostic)
- Wave manager integration
- Role/ability setup

---

## wave_manager.gd

**File**: `scripts/wave_manager.gd`
**Complexity**: MEDIUM

### 2D-Specific Code That Must Change

| Line(s) | Current (2D) | 3D Equivalent | Notes |
|---------|-------------|---------------|-------|
| 4 | `extends Node` | **KEEP** -- WaveManager is a plain Node | |
| 13-16 | `ARENA_LEFT/RIGHT/TOP/BOTTOM` as flat floats (pixel coords) | Convert to 3D world units on XZ plane | Arena bounds need rethinking for 3D |
| 197 | `enemy.position = _random_edge_position()` | Returns `Vector3` instead of `Vector2` | |
| 207 | `Events.enemy_spawned.emit(enemy_id, enemy_type, enemy.position)` | Position is now `Vector3` | |
| 222 | `boss.position = _random_edge_position()` | `Vector3` | |
| 230 | `Events.boss_spawned.emit(...)` | Position is `Vector3` | |
| 235-246 | `_random_edge_position() -> Vector2` -- returns 2D edge positions | `_random_edge_position() -> Vector3` -- same logic but y=0, x and z from arena bounds | |
| 239 | `Vector2(randf_range(...), ARENA_TOP)` | `Vector3(randf_range(...), 0, ARENA_TOP_Z)` | |
| 328 | `enemy.position = global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))` (crash dumps) | `Vector3(randf_range(...), 0, randf_range(...))` | In kernel_panic.gd actually |

### Pure Logic That Stays As-Is
- Wave state machine (IDLE, SPAWNING, ACTIVE, etc.)
- Enemy type selection / weighted random
- Difficulty scaling formula
- All RPC notifications
- HUD updates (CanvasLayer/Control UI)
- Death messages / end screen
- Boss announcement UI

---

## ability_manager.gd

**File**: `scripts/ability_manager.gd`
**Complexity**: SIMPLE

### 2D-Specific Code That Must Change

| Line(s) | Current (2D) | 3D Equivalent | Notes |
|---------|-------------|---------------|-------|
| 40 | `ability_node.activate(player.global_position, player.input_aim_dir)` | `player.global_position` is `Vector3` now, `input_aim_dir` stays `Vector2` | Ability activate signatures need updating |

### Pure Logic That Stays As-Is
- ALL logic is pure game mechanics (cooldowns, charge, damage multipliers)
- Role-based bonuses
- Input consumption pattern
- Super charge system

---

## revive_system.gd

**File**: `scripts/revive_system.gd`
**Complexity**: SIMPLE-MEDIUM

### 2D-Specific Code That Must Change

| Line(s) | Current (2D) | 3D Equivalent | Notes |
|---------|-------------|---------------|-------|
| 35 | `func _try_start_revive(rescuer: CharacterBody2D)` | `CharacterBody3D` | |
| 47 | `func _continue_revive(rescuer: CharacterBody2D, delta: float)` | `CharacterBody3D` | |
| 51 | `rescuer.global_position.distance_to(_revive_target.global_position)` | Works the same in 3D (may want XZ distance only) | |
| 64 | `func _complete_revive(rescuer: CharacterBody2D)` | `CharacterBody3D` | |
| 75 | `get_node_or_null("CollisionShape2D")` | `"CollisionShape3D"` | |
| 106 | `func _find_downed_player_in_range(rescuer: CharacterBody2D) -> CharacterBody2D` | Both -> `CharacterBody3D` | |
| 108 | `var nearest: CharacterBody2D = null` | `CharacterBody3D` | |
| 116 | `rescuer.global_position.distance_to(player.global_position)` | Same API, works in 3D | |
| 134 | `func _update_revive_bar(target: CharacterBody2D, progress: float)` | `CharacterBody3D` | |
| 149 | `bar.size = Vector2(50, 8)`, `bar.position = Vector2(-25, -50)` | Revive bar is a UI ProgressBar added as child -- in 3D this needs to be a `SubViewport` or billboarded `Label3D`/`Sprite3D` | **TRICKY** -- 2D controls as children of 3D nodes don't render |

### Pure Logic That Stays As-Is
- Revive timing/progress
- Revive range check (same concept)
- RPC for progress sync
- Cancel/complete flow

---

## enemy_base.gd

**File**: `scripts/enemies/enemy_base.gd`
**Complexity**: HARD
**Root node type change**: `CharacterBody2D` -> `CharacterBody3D`

### 2D-Specific Code That Must Change

| Line(s) | Current (2D) | 3D Equivalent | Notes |
|---------|-------------|---------------|-------|
| 3 | `extends CharacterBody2D` | `extends CharacterBody3D` | |
| 24 | `collision_layer = 4`, `collision_mask = 3` | Same values, 3D layers | |
| 30-31 | `get_node_or_null("Sprite2D") as Sprite2D` | `get_node_or_null("Model") as MeshInstance3D` | |
| 35 | `var dir := (target.global_position - global_position).normalized()` | `Vector3` direction, use for Y-axis rotation | |
| 36 | `sprite.rotation = dir.angle()` | `model.rotation.y = -Vector2(dir.x, dir.z).angle()` or `look_at()` | |
| 74-76 | `var dir := (target.global_position - global_position).normalized()`, `velocity = dir * speed`, `move_and_slide()` | `dir` is `Vector3`, may want to zero out Y: `dir.y = 0; dir = dir.normalized()` | Movement stays on ground plane |
| 88-89 | flee direction calc + velocity | Same but `Vector3` | |
| 94 | `velocity = Vector2.ZERO` | `velocity = Vector3.ZERO` | |
| 119-128 | `_show_hit_flash` -- `Sprite2D` modulate | 3D mesh material color flash | |
| 132 | `_show_melee_strike(hit_pos: Vector2)` | `hit_pos: Vector3` | |
| 145 | `ring.global_position = hit_pos` | `Vector3` | |
| 149-178 | `_create_hit_ring()` -- procedural Image/Sprite2D ring | 3D particle effect or MeshInstance3D ring | **FULL REPLACEMENT** |
| 154-167 | Procedural `Image.create(16,16)` pixel-by-pixel ring | Replace with 3D torus mesh or particle | |
| 171-176 | Tween on `ring.scale` (Vector2) and `ring.modulate:a` | 3D scale tween (Vector3) and material alpha | |
| 184 | `velocity = Vector2.ZERO` | `Vector3.ZERO` | |
| 207-223 | `_find_nearest_player() -> Node2D` | `-> Node3D` | |
| 212 | `if not player is Node2D` | `if not player is Node3D` | |
| 219 | `global_position.distance_to(player.global_position)` | Same API | **KEEP** |
| 237-263 | `_check_contact_damage` -- all `Node2D` checks, `distance_to`, `global_position.lerp` | `Node3D` type checks | |
| 248 | `global_position.lerp(player.global_position, 0.5)` | Same API in 3D | **KEEP** |

### Pure Logic That Stays As-Is
- State machine (IDLE, CHASE, ATTACK, etc.)
- take_damage logic
- Status effects
- apply_scaling
- Multiplayer server authority checks

---

## enemy_merge_conflict.gd

**File**: `scripts/enemies/enemy_merge_conflict.gd`
**Complexity**: MEDIUM

### 2D-Specific Code That Must Change

| Line(s) | Current (2D) | 3D Equivalent | Notes |
|---------|-------------|---------------|-------|
| 11 | `TIER_SIZE: Array[Vector2]` | Not needed in 3D (use 3D collision shapes) -- or `Array[Vector3]` | |
| 38-40 | `Sprite2D` texture swap | 3D model/material swap per tier | |
| 44-52 | `CollisionShape2D`, `RectangleShape2D` resize | `CollisionShape3D`, `BoxShape3D` resize | |
| 58 | `velocity = Vector2.ZERO` | `Vector3.ZERO` | |
| 73 | `child_positions: Array[Vector2]` | `Array[Vector3]` | |
| 78 | `Vector2.from_angle(randf() * TAU + PI * i) * 30.0` | `Vector3(cos(angle) * 30.0, 0, sin(angle) * 30.0)` | |
| 79 | `child.position = global_position + offset` | `Vector3` math | |

### Pure Logic That Stays As-Is
- Tier system (HP, speed, damage per tier)
- Split-on-death mechanic
- exposed/clean-kill check

---

## enemy_hallucination.gd

**File**: `scripts/enemies/enemy_hallucination.gd`
**Complexity**: MEDIUM

### 2D-Specific Code That Must Change

| Line(s) | Current (2D) | 3D Equivalent | Notes |
|---------|-------------|---------------|-------|
| 9-10 | `HALL_DISGUISED_SIZE: Vector2`, `HALL_REVEALED_SIZE: Vector2` | `Vector3` for 3D collision | |
| 17 | `TEX_DISGUISED`, `TEX_REVEALED` texture paths | 3D model/material swaps | |
| 47 | `global_position.distance_to(target.global_position)` | Same API | **KEEP** |
| 94-97 | `Sprite2D` texture/modulate | 3D model swap | |
| 101 | `var half := HALL_REVEALED_SIZE / 2.0` | Vector3 division | |
| 102-105 | `Sprite2D` texture swap | 3D model swap | |
| 108-116 | `CollisionShape2D` + `RectangleShape2D` resize | `CollisionShape3D` + `BoxShape3D` | |

### Pure Logic That Stays As-Is
- Disguise/reveal state machine
- Reveal trigger distance check (same concept)
- Scan stun mechanic
- take_damage override

---

## enemy_context_rot.gd

**File**: `scripts/enemies/enemy_context_rot.gd`
**Complexity**: MEDIUM

### 2D-Specific Code That Must Change

| Line(s) | Current (2D) | 3D Equivalent | Notes |
|---------|-------------|---------------|-------|
| 14 | `CR_SIZE: Vector2` | Not directly needed (collision defined in scene) | |
| 38-53 | Chase/flee: `distance_to`, `dir` as `Vector2` | `Vector3` directions, zero Y | |
| 58 | `velocity = Vector2.ZERO` | `Vector3.ZERO` | |
| 78 | `var dir := (target.global_position - global_position).normalized()` | `Vector3` | |
| 101-110 | `_fire_rot_projectile(direction: Vector2)` | `direction: Vector3` (or keep as `Vector2` for XZ aim, convert at spawn) | |
| 109 | `proj.position = global_position + direction * 25.0` | `Vector3` math | |

### Pure Logic That Stays As-Is
- Fire range/flee range checks
- Fire cooldown
- Status effect on projectile

---

## enemy_dependency_hell.gd

**File**: `scripts/enemies/enemy_dependency_hell.gd`
**Complexity**: SIMPLE

### 2D-Specific Code That Must Change

| Line(s) | Current (2D) | 3D Equivalent | Notes |
|---------|-------------|---------------|-------|
| 9 | `DH_SIZE: Vector2` | `Vector3` or remove | |
| 40 | `global_position.distance_to(player.global_position)` | Same API in 3D | **KEEP** |

### Pure Logic That Stays As-Is
- Aura mechanic (distance-based, same concept)
- All base class methods inherited from enemy_base

---

## enemy_kernel_panic.gd

**File**: `scripts/enemies/enemy_kernel_panic.gd`
**Complexity**: HARD

### 2D-Specific Code That Must Change

| Line(s) | Current (2D) | 3D Equivalent | Notes |
|---------|-------------|---------------|-------|
| 13 | `BOSS_SIZE: Vector2` | `Vector3` or just collision dimensions | |
| 53 | `_lunge_direction: Vector2` | `Vector3` (zero Y) | |
| 64 | `_shield_facing_dir: Vector2 = Vector2.LEFT` | `Vector3(−1,0,0)` | |
| 123 | `_lunge_direction = (target.global_position - global_position).normalized()` | `Vector3`, zero Y | |
| 124 | `velocity = Vector2.ZERO` | `Vector3.ZERO` | |
| 141-142 | chase velocity `dir * speed`, `move_and_slide()` | `Vector3` | |
| 151-152 | `velocity = _lunge_direction * LUNGE_SPEED[...]`, `move_and_slide()` | `Vector3` | |
| 162 | `velocity = Vector2.ZERO` | `Vector3.ZERO` | |
| 181 | `hit_dir := (global_position - attacker.global_position).normalized()` | `Vector3` | |
| 182 | `hit_dir.dot(_shield_facing_dir)` | Same dot product, works in 3D | **KEEP** |
| 213 | `_recent_hit_dirs[i].dot(_recent_hit_dirs[j])` | Same | **KEEP** |
| 247 | `_shield_facing_dir = Vector2.LEFT` | `Vector3(-1, 0, 0)` | |
| 276 | `base_dir := (target.global_position - global_position).normalized()` | `Vector3` | |
| 290 | `var dir := base_dir.rotated(angle)` | `Vector2.rotated()` doesn't exist for `Vector3` -- need `dir.rotated(Vector3.UP, angle)` or use XZ `Vector2` rotation then convert | **TRICKY** |
| 299 | `proj.position = global_position + dir * 30.0` | `Vector3` | |
| 328 | `enemy.position = global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))` | `global_position + Vector3(randf_range(-40, 40), 0, randf_range(-40, 40))` | |
| 362 | `_shield_facing_dir = (target.global_position - global_position).normalized()` | `Vector3` | |
| 370 | `velocity = Vector2.ZERO` | `Vector3.ZERO` | |
| 392-405 | `_check_contact_damage` -- `Node2D`, `distance_to`, `lerp` | `Node3D`, same distance API | |
| 437-438 | `ShieldVisual` as `ColorRect` | 3D mesh (flat plane or shield model) | |
| 462-472 | `HealthBarFill` as `ColorRect`, `offset_right` manipulation | 3D health bar (SubViewport or billboarded Sprite3D) | |
| 474 | `HealthBarLabel` as `Label` | `Label3D` or SubViewport-based | |
| 486-496 | Shield visual positioning: `_shield_facing_dir * 60.0 - Vector2(10, 60)` and `rotation = angle()` | 3D position and Y-rotation | |

### Pure Logic That Stays As-Is
- Phase system (thresholds, transitions, stun)
- Lunge cycle timing
- Projectile spread angles (concept)
- Crash dump spawning logic
- Shield flank detection (dot products -- same math)
- take_damage shield block logic

---

## ability_weak_point_scan.gd

**File**: `scripts/abilities/ability_weak_point_scan.gd`
**Complexity**: SIMPLE

### 2D-Specific Code That Must Change

| Line(s) | Current (2D) | 3D Equivalent | Notes |
|---------|-------------|---------------|-------|
| 12 | `func activate(player_pos: Vector2, _aim_dir: Vector2)` | `player_pos: Vector3` | |
| 18 | `enemy.global_position.distance_to(player_pos)` | Same API, works in 3D | **KEEP** |
| 24 | `Events.ability_activated.emit(..., player_pos, Vector2.ZERO)` | Position is `Vector3` | |
| 26 | `player._show_scan_visual.rpc(player_pos, SCAN_RADIUS)` | `player_pos` is `Vector3` | |

### Pure Logic That Stays As-Is
- Scan radius check
- Exposed status application
- Hallucination reveal mechanic

---

## ability_deploy_turret.gd

**File**: `scripts/abilities/ability_deploy_turret.gd`
**Complexity**: SIMPLE

### 2D-Specific Code That Must Change

| Line(s) | Current (2D) | 3D Equivalent | Notes |
|---------|-------------|---------------|-------|
| 18 | `func activate(player_pos: Vector2, aim_dir: Vector2)` | `player_pos: Vector3`, aim_dir stays `Vector2` (XZ) | |
| 25 | `var turret_pos := player_pos + aim_dir * 60.0` | Need Vector3 math: `player_pos + Vector3(aim_dir.x, 0, aim_dir.y) * 60.0` | |
| 39 | `Events.turret_deployed.emit(..., turret_pos)` | `Vector3` | |

### Pure Logic That Stays As-Is
- Turret limit enforcement
- Scene instantiation
- All turret ID management

---

## super_overdrive.gd

**File**: `scripts/abilities/super_overdrive.gd`
**Complexity**: SIMPLE (nearly zero 2D code)

### 2D-Specific Code That Must Change

| Line(s) | Current (2D) | 3D Equivalent | Notes |
|---------|-------------|---------------|-------|
| 9 | `func activate(player: CharacterBody2D)` | `CharacterBody3D` | |

### Pure Logic That Stays As-Is
- Everything else (status application, RPC visual call, event emit)

---

## super_healing_pulse.gd

**File**: `scripts/abilities/super_healing_pulse.gd`
**Complexity**: SIMPLE

### 2D-Specific Code That Must Change

| Line(s) | Current (2D) | 3D Equivalent | Notes |
|---------|-------------|---------------|-------|
| 20 | `get_node_or_null("CollisionShape2D")` | `"CollisionShape3D"` | |

### Pure Logic That Stays As-Is
- All healing/revive logic
- Status removal
- RPC calls

---

## turret.gd

**File**: `scripts/entities/turret.gd`
**Complexity**: MEDIUM
**Root node type change**: `StaticBody2D` -> `StaticBody3D`

### 2D-Specific Code That Must Change

| Line(s) | Current (2D) | 3D Equivalent | Notes |
|---------|-------------|---------------|-------|
| 3 | `extends StaticBody2D` | `extends StaticBody3D` | |
| 66 | `var dir := (target.global_position - global_position).normalized()` | `Vector3` direction | |
| 72 | `projectile.position = global_position + dir * 16.0` | `Vector3` | |
| 93 | `if not enemy is Node2D` | `if not enemy is Node3D` | |
| 95 | `global_position.distance_to(enemy.global_position)` | Same API | **KEEP** |

### Pure Logic That Stays As-Is
- Fire rate, damage, lifetime
- Health/take_damage
- Super charge for owner
- Enemy targeting logic (concept)

---

## projectile.gd

**File**: `scripts/projectile.gd`
**Complexity**: MEDIUM
**Root node type change**: `Area2D` -> `Area3D`

### 2D-Specific Code That Must Change

| Line(s) | Current (2D) | 3D Equivalent | Notes |
|---------|-------------|---------------|-------|
| 3 | `extends Area2D` | `extends Area3D` | |
| 5 | `var direction: Vector2 = Vector2.RIGHT` | `var direction: Vector3 = Vector3.RIGHT` | |
| 22 | `rotation = direction.angle()` | `look_at(global_position + direction)` or `rotation.y = -Vector2(direction.x, direction.z).angle()` | |
| 27 | `position += direction * speed * delta` | Same syntax, `Vector3` math | **KEEP** |
| 41 | `if body is CharacterBody2D` | `if body is CharacterBody3D` | |

### Pure Logic That Stays As-Is
- Collision mask setup
- Damage/status effect application
- Lifetime tracking
- Super charge for owner
- Friendly fire prevention

---

## projectile_enemy.gd

**File**: `scripts/entities/projectile_enemy.gd`
**Complexity**: MEDIUM
**Root node type change**: `Area2D` -> `Area3D`

### 2D-Specific Code That Must Change

| Line(s) | Current (2D) | 3D Equivalent | Notes |
|---------|-------------|---------------|-------|
| 3 | `extends Area2D` | `extends Area3D` | |
| 5 | `var direction: Vector2 = Vector2.RIGHT` | `var direction: Vector3 = Vector3.RIGHT` | |
| 27 | `rotation = direction.angle()` | `look_at()` or Y-axis rotation | |
| 31 | `position += direction * speed * delta` | Same, `Vector3` | |

### Pure Logic That Stays As-Is
- Status effect application
- Collision handling
- Lifetime

---

## events.gd

**File**: `scripts/autoloads/events.gd`
**Complexity**: SIMPLE (but touches everything)

### 2D-Specific Code That Must Change

| Line(s) | Current (2D) | 3D Equivalent | Notes |
|---------|-------------|---------------|-------|
| 7 | `signal player_joined(player_id: int, spawn_position: Vector2)` | `Vector3` | |
| 10 | `signal player_died(player_id: int, position: Vector2)` | `Vector3` | |
| 11 | `signal player_respawned(player_id: int, position: Vector2)` | `Vector3` | |
| 14 | `signal enemy_spawned(enemy_id: int, enemy_type: String, position: Vector2)` | `Vector3` | |
| 16 | `signal enemy_split(parent_id: int, child_ids: Array, positions: Array)` | Array of `Vector3` | |
| 19 | `signal ability_activated(..., position: Vector2, direction: Vector2)` | `position: Vector3`, `direction: Vector2` (XZ aim stays 2D) | |
| 21 | `signal clear_context_combo(..., center: Vector2, radius: float)` | `center: Vector3` | |
| 30 | `signal powerup_spawned(..., position: Vector2)` | `Vector3` | |
| 52 | `signal player_downed(player_id: int, position: Vector2)` | `Vector3` | |
| 64 | `signal turret_deployed(..., position: Vector2)` | `Vector3` | |
| 68 | `signal boss_spawned(..., position: Vector2)` | `Vector3` | |
| 73 | `signal hallucination_revealed(enemy_id: int, position: Vector2)` | `Vector3` | |

**Note**: GDScript signals are duck-typed, so changing `Vector2` to `Vector3` in the type hints here may not cause errors if some consumers haven't been updated yet, but all emitters and consumers should be updated for correctness.

### Pure Logic That Stays As-Is
- All signal declarations that don't use Vector2 (most of them)

---

## network_manager.gd

**File**: `scripts/autoloads/network_manager.gd`
**Complexity**: SIMPLE (almost zero 2D code)

### 2D-Specific Code That Must Change

| Line(s) | Current (2D) | 3D Equivalent | Notes |
|---------|-------------|---------------|-------|
| 159 | `Events.player_joined.emit(id, Vector2.ZERO)` | `Vector3.ZERO` | Single line |

### Pure Logic That Stays As-Is
- ALL networking logic (ENet, hosting, joining, migration)
- Room code system
- Signal wiring
- Snapshot system
- Peer address tracking

---

## sound_manager.gd

**File**: `scripts/autoloads/sound_manager.gd`
**Complexity**: NONE (zero 2D code)

### 2D-Specific Code That Must Change

Nothing. `AudioStreamPlayer` is dimension-agnostic. If positional audio is desired later, it would use `AudioStreamPlayer3D`, but that's a feature addition, not a conversion requirement.

### Pure Logic That Stays As-Is
- Everything

---

## lobby.gd

**File**: `scripts/lobby.gd`
**Complexity**: NONE (zero 2D game code)

### 2D-Specific Code That Must Change

Nothing. The lobby is a `Control` node (2D UI), which is dimension-agnostic. It already uses a `SubViewport` with a 3D stage (`lobby_stage_3d.gd`). The lobby will remain exactly as-is.

### Pure Logic That Stays As-Is
- Everything (all UI, networking, role selection, tabs, keyboard)

---

## lobby_stage_3d.gd

**File**: `scripts/lobby_stage_3d.gd`
**Complexity**: NONE (already 3D)

### 2D-Specific Code That Must Change

Nothing. This file already uses `Node3D`, `MeshInstance3D`, `StandardMaterial3D`, `Label3D`, `GPUParticles3D`, etc. It's fully 3D.

### Pure Logic That Stays As-Is
- Everything

---

## game.tscn

**File**: `scenes/game.tscn`
**Complexity**: HARD (complete scene rebuild)

### 2D-Specific Elements That Must Change

| Node | Current (2D) | 3D Equivalent | Notes |
|------|-------------|---------------|-------|
| `Game` root | `Node2D` | `Node3D` | |
| `ParallaxFar/Mid/Near` | `Parallax2D` + `Sprite2D` | Remove entirely or replace with 3D skybox/environment | |
| `Level/Floor` | `StaticBody2D` + `CollisionShape2D` (RectangleShape2D) + `Sprite2D` | `StaticBody3D` + `CollisionShape3D` (BoxShape3D) + `MeshInstance3D` (plane/box) | |
| `Level/LeftWall`, `RightWall`, `Ceiling` | `StaticBody2D` + `CollisionShape2D` (RectangleShape2D) + `Sprite2D` | `StaticBody3D` + `CollisionShape3D` (BoxShape3D) + `MeshInstance3D` | Walls around arena |
| `Players` | `Node2D` container | `Node3D` container | |
| `Enemies` | `Node2D` container | `Node3D` container | |
| `Projectiles` | `Node2D` container | `Node3D` container | |
| `Effects` | `Node2D` container | `Node3D` container | |
| `WaveManager` | `Node` | **KEEP** | Already a plain Node |
| `PlayerSpawner` | `MultiplayerSpawner` | **KEEP** -- update `_spawnable_scenes` paths if scene paths change | |
| `EnemySpawner` | `MultiplayerSpawner` | **KEEP** -- update paths | |
| `ProjectileSpawner` | `MultiplayerSpawner` | **KEEP** -- update paths | |
| `EffectsSpawner` | `MultiplayerSpawner` | **KEEP** -- update paths | |
| `UI/HUD` | `CanvasLayer` + `Control` | **KEEP** -- UI stays 2D (CanvasLayer overlays 3D) | |
| All HUD labels, bars, end screen | `Label`, `ProgressBar`, `Panel`, `Button` | **KEEP** | |
| All `RectangleShape2D` sub-resources | 2D shapes | `BoxShape3D` sub-resources | |
| All `Texture2D` backgrounds/tiles | 2D textures for floor/walls | 3D materials on meshes | |
| Camera | None in game.tscn (per-player `Camera2D` in player.tscn) | Need a `Camera3D` setup | |

### What Stays
- `WaveManager` (pure Node)
- All `MultiplayerSpawner` nodes (just update paths)
- All `UI/HUD` children (CanvasLayer + Controls are 2D overlay on 3D)

---

## player.tscn

**File**: `scenes/player.tscn`
**Complexity**: HARD (complete scene rebuild)

### 2D-Specific Elements That Must Change

| Node | Current (2D) | 3D Equivalent | Notes |
|------|-------------|---------------|-------|
| `Player` root | `CharacterBody2D` | `CharacterBody3D` | |
| `CollisionShape2D` | `CollisionShape2D` + `RectangleShape2D` (32x32) | `CollisionShape3D` + `CapsuleShape3D` or `BoxShape3D` | |
| `Sprite2D` | `Sprite2D` with texture | `MeshInstance3D` with 3D model (or procedural capsule+head like lobby) | |
| `Camera2D` | `Camera2D` with zoom/limits | `Camera3D` -- likely overhead or follow camera with 3D positioning | |
| `ShootPoint` | `Marker2D` at (20, 0) | `Marker3D` at `Vector3(0.2, 0.5, 0)` or similar | |
| `ServerSync` replication config | Syncs `position` (Vector2), `velocity` (Vector2) | Syncs `position` (Vector3), `velocity` (Vector3) -- **auto-handled** by type change | |
| `InputSync` replication config | Syncs `input_move_dir` (Vector2), `input_aim_dir` (Vector2) | These stay Vector2 (input is 2D) -- **KEEP** | |
| `AbilityManager` | `Node` | **KEEP** | |
| `ReviveSystem` | `Node` | **KEEP** | |

---

## lobby.tscn

**File**: `scenes/lobby.tscn`
**Complexity**: NONE

Nothing changes. The lobby is a pure UI scene (`Control` root) with a `SubViewportContainer` for the 3D character preview. All 2D UI elements stay. The `SubViewport` and `LobbyStage3D` are already 3D.

---

## lobby_stage_3d.tscn

**File**: `scenes/lobby_stage_3d.tscn`
**Complexity**: NONE (already 3D)

Nothing changes. Already uses `Node3D`, `Camera3D`, `DirectionalLight3D`, `WorldEnvironment`, `MeshInstance3D`, `Marker3D`.

---

## Enemy .tscn Files

**Files**: `scenes/enemies/enemy_merge_conflict.tscn`, `enemy_hallucination.tscn`, `enemy_context_rot.tscn`, `enemy_dependency_hell.tscn`, `boss_kernel_panic.tscn`
**Complexity**: MEDIUM (per file, but repetitive pattern)

### Common Pattern Across All Enemy Scenes

| Node | Current (2D) | 3D Equivalent |
|------|-------------|---------------|
| Root `Enemy` | `CharacterBody2D` | `CharacterBody3D` |
| `CollisionShape2D` | `CollisionShape2D` + `RectangleShape2D` | `CollisionShape3D` + `BoxShape3D` or `CapsuleShape3D` |
| `Sprite2D` | `Sprite2D` + `Texture2D` | `MeshInstance3D` + 3D model or procedural mesh |
| `Hurtbox` | `Area2D` + `CollisionShape2D` | `Area3D` + `CollisionShape3D` |
| `Hurtbox/CollisionShape2D` | `RectangleShape2D` | `BoxShape3D` |
| `MultiplayerSynchronizer` | Syncs `position` (Vector2) | Syncs `position` (Vector3) -- auto |
| Replication config `.:position` | Vector2 internally | Vector3 -- type changes automatically with node type |

### Boss-Specific (boss_kernel_panic.tscn)

| Node | Current (2D) | 3D Equivalent |
|------|-------------|---------------|
| `ShieldVisual` | `ColorRect` (2D rect) | `MeshInstance3D` (flat plane mesh with shield material) |
| `HealthBarBg` | `ColorRect` | `MeshInstance3D` or `SubViewport`+`Sprite3D` for 2D-style bar in 3D |
| `HealthBarFill` | `ColorRect` | Same approach as above |
| `HealthBarLabel` | `Label` (2D) | `Label3D` or SubViewport |
| Syncs `_shield_facing_dir` (Vector2) | Vector2 | Vector3 -- need to update replication config |

---

## turret.tscn

**File**: `scenes/turret.tscn`
**Complexity**: MEDIUM

| Node | Current (2D) | 3D Equivalent |
|------|-------------|---------------|
| Root `Turret` | `StaticBody2D` | `StaticBody3D` |
| `CollisionShape2D` | `RectangleShape2D` (24x24) | `BoxShape3D` or `CylinderShape3D` |
| `Sprite2D` | `Sprite2D` + turret texture | `MeshInstance3D` + 3D model |
| `DetectionArea` | `Area2D` + `CircleShape2D` (r=250) | `Area3D` + `SphereShape3D` (r=250) |
| `ShootPoint` | `Marker2D` | `Marker3D` |
| `MultiplayerSynchronizer` | Syncs position (Vector2) | Position auto-becomes Vector3 |

---

## Projectile .tscn Files

**Files**: `scenes/projectile.tscn`, `scenes/projectile_enemy.tscn`
**Complexity**: MEDIUM

| Node | Current (2D) | 3D Equivalent |
|------|-------------|---------------|
| Root | `Area2D` | `Area3D` |
| `CollisionShape2D` | `RectangleShape2D` (12x6 or 12x12) | `BoxShape3D` or `SphereShape3D` |
| `Sprite2D` | `Sprite2D` + projectile texture | `MeshInstance3D` + small sphere/capsule mesh with emissive material |
| `MultiplayerSynchronizer` | Syncs `position` (Vector2), `direction` (Vector2) | `position` (Vector3), `direction` (Vector3) |

---

## project.godot

**File**: `project.godot`
**Complexity**: SIMPLE

### Settings That Must Change

| Setting | Current | 3D Equivalent | Notes |
|---------|---------|---------------|-------|
| `window/size/viewport_width` | 1900 | Keep or adjust | May want different aspect for 3D |
| `window/size/viewport_height` | 1200 | Keep or adjust | |
| `window/stretch/mode` | `"canvas_items"` | `"canvas_items"` or `"viewport"` | **KEEP** -- works for 3D too |
| `window/stretch/scale` | 2.0 | May need adjustment for 3D | |
| `rendering/textures/canvas_textures/default_texture_filter` | 0 (nearest) | Remove or keep for UI | Only affects 2D textures |
| `rendering/environment/defaults/default_clear_color` | `Color(0.08, 0.08, 0.1, 1)` | Keep or use WorldEnvironment | |
| Input mappings | All fine | **KEEP** | Input is input-device-level, not dimension-specific |

### May Want to Add
- `rendering/quality/shadow_atlas/size` for shadow quality
- 3D-specific rendering settings
- Anti-aliasing settings for 3D

---

## Summary: Conversion Complexity by File

| File | Complexity | Key Changes |
|------|-----------|-------------|
| **player.gd** | HARD | CharacterBody2D->3D, all movement, aim, visuals, camera |
| **game_manager.gd** | MEDIUM | Node2D->3D, spawn positions, screen projection for labels |
| **wave_manager.gd** | MEDIUM | Arena bounds, spawn positions |
| **ability_manager.gd** | SIMPLE | Just one Vector2 arg |
| **revive_system.gd** | SIMPLE-MEDIUM | Type annotations, collision node names, progress bar in 3D |
| **enemy_base.gd** | HARD | CharacterBody2D->3D, all movement, visuals, hit ring |
| **enemy_merge_conflict.gd** | MEDIUM | Tier visuals, collision shapes, split offset calc |
| **enemy_hallucination.gd** | MEDIUM | Disguise/reveal visuals, collision shapes |
| **enemy_context_rot.gd** | MEDIUM | Direction vectors, projectile spawn |
| **enemy_dependency_hell.gd** | SIMPLE | Minimal changes (inherits base) |
| **enemy_kernel_panic.gd** | HARD | Lunge direction, shield facing, projectile spread rotation, health bar, shield visual |
| **ability_weak_point_scan.gd** | SIMPLE | Vector2->Vector3 for position |
| **ability_deploy_turret.gd** | SIMPLE | Turret placement math |
| **super_overdrive.gd** | SIMPLE | One type annotation |
| **super_healing_pulse.gd** | SIMPLE | One collision node name |
| **turret.gd** | MEDIUM | StaticBody2D->3D, targeting math |
| **projectile.gd** | MEDIUM | Area2D->Area3D, direction type, rotation |
| **projectile_enemy.gd** | MEDIUM | Same as projectile.gd |
| **events.gd** | SIMPLE | Vector2->Vector3 in signal signatures |
| **network_manager.gd** | SIMPLE | One Vector2.ZERO -> Vector3.ZERO |
| **sound_manager.gd** | NONE | Zero changes |
| **lobby.gd** | NONE | Zero changes (pure UI) |
| **lobby_stage_3d.gd** | NONE | Already 3D |
| **game.tscn** | HARD | Full scene rebuild (arena, physics, containers) |
| **player.tscn** | HARD | Full scene rebuild (body, camera, collision, markers) |
| **lobby.tscn** | NONE | Already works |
| **lobby_stage_3d.tscn** | NONE | Already 3D |
| **Enemy .tscn files (x5)** | MEDIUM | Same pattern: CB2D->CB3D, shapes, sprites->meshes |
| **turret.tscn** | MEDIUM | SB2D->SB3D, shapes, sprite->mesh |
| **projectile .tscn files (x2)** | MEDIUM | Area2D->Area3D, shapes, sprite->mesh |
| **project.godot** | SIMPLE | Rendering settings |

---

## Critical Gotchas

1. **Mouse Aim in 3D**: The biggest single challenge. Currently `get_global_mouse_position() - global_position` gives a 2D aim vector. In 3D, you must raycast from the camera through the mouse cursor onto the ground plane (`Plane(Vector3.UP, 0)`). This is a fundamental input change in `player.gd:174`.

2. **2D Controls as Children of 3D Nodes**: `ProgressBar`, `ColorRect`, and `Label` nodes added as children of `CharacterBody3D` (e.g., revive bar, boss health bar) will NOT render. They must either:
   - Be moved to a `CanvasLayer` and repositioned each frame using camera projection
   - Use `SubViewport` + `Sprite3D` for in-world 2D UI
   - Use `Label3D` for text

3. **Vector2.rotated() Has No Vector3 Equivalent**: `base_dir.rotated(angle)` in `enemy_kernel_panic.gd:290` for projectile spread must be reimplemented as `dir.rotated(Vector3.UP, angle)` for Vector3 rotation around Y axis.

4. **MultiplayerSynchronizer Replication Configs**: The `.tscn` files define `SceneReplicationConfig` sub-resources that sync `position` and `velocity`. When the root node changes from 2D to 3D, these properties automatically change from `Vector2` to `Vector3`. The replication configs should work without modification because they reference property paths (`.:position`), not types. However, any custom synced `Vector2` properties (like `_shield_facing_dir` in the boss) need manual attention.

5. **ColorRect Visuals Throughout**: The codebase uses `ColorRect` extensively for visual effects (melee swing, overdrive glow, healing flash, scan zone, shield, hit ring). ALL of these need 3D replacements (meshes, particles, or shaders).

6. **distance_to() Works Identically**: `Vector3.distance_to()` has the same API as `Vector2.distance_to()`. All distance checks (melee range, aura radius, contact damage, turret range, revive range) will work without logic changes -- only the type annotations change.

7. **Parallax Background**: The `Parallax2D` layers in `game.tscn` have no direct 3D equivalent. Replace with a `WorldEnvironment` node with a skybox or procedural sky.

8. **Arena Bounds**: Currently defined as pixel coordinates (32-1168 x, 32-568 y). Need to be redefined in 3D world units. The scale factor from pixels to 3D units needs to be decided and applied consistently everywhere.
