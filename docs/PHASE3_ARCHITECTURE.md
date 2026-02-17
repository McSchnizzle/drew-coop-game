# Phase 3 Architecture: 2D to 3D First-Person Conversion

> **Last updated:** 2026-02-15
> **Builds on:** Phase 2 combat systems (see `docs/PHASE2_ARCHITECTURE.md`)
> **Engine:** Godot 4.6 | **Language:** GDScript | **Networking:** ENet (host-authoritative)

**Design goal:** Convert the top-down 2D wave survival shooter into a first-person 3D game while preserving all gameplay systems, networking, and multiplayer architecture intact.

---

## Table of Contents

1. [Conversion Overview](#1-conversion-overview)
2. [What Stays the Same](#2-what-stays-the-same)
3. [Node Type Mapping](#3-node-type-mapping)
4. [Scene-by-Scene Conversion Plan](#4-scene-by-scene-conversion-plan)
5. [Script-by-Script Change List](#5-script-by-script-change-list)
6. [New 3D Systems](#6-new-3d-systems)
7. [Multiplayer Sync Changes](#7-multiplayer-sync-changes)
8. [Physics and Collision Migration](#8-physics-and-collision-migration)
9. [HUD and UI Strategy](#9-hud-and-ui-strategy)
10. [Risk Areas and Known Pitfalls](#10-risk-areas-and-known-pitfalls)
11. [Implementation Order](#11-implementation-order)
12. [Constants Migration Reference](#12-constants-migration-reference)

---

## 1. Conversion Overview

### Philosophy

The 2D codebase was designed with this conversion in mind ("No investment in 2D-specific visuals beyond colored rectangles. Everything here carries over to 3D." -- Phase 2 doc). The game logic, networking, wave system, abilities, and enemy AI are all dimension-agnostic. The conversion is primarily about:

1. **Swapping node types** (CharacterBody2D -> CharacterBody3D, etc.)
2. **Adding a first-person camera** to the player
3. **Converting Vector2 to Vector3** (using XZ plane for ground movement, Y for vertical)
4. **Rebuilding scenes** with 3D nodes and meshes
5. **Replacing 2D visuals** with 3D meshes/materials

### Coordinate System Convention

The 2D game uses X/Y for the ground plane. In 3D:

| 2D Axis | 3D Axis | Purpose |
|---------|---------|---------|
| X | X | Left/right |
| Y | Z | Forward/back (was "up/down" in top-down) |
| N/A | Y | Vertical (up/down in 3D, gravity axis) |

All `Vector2` ground positions map to `Vector3(x, 0, z)` where the old Y becomes Z.

### Scope Boundaries

**IN scope:** Game scene, player, enemies, projectiles, turrets, arena, HUD updates.
**OUT of scope:** Lobby scene (already has 3D preview stage; lobby UI stays 2D), main menu, autoloads (Events, NetworkManager, SoundManager stay identical).

---

## 2. What Stays the Same

These systems require **zero or trivial changes**:

| System | Why It's Unchanged |
|--------|--------------------|
| **NetworkManager autoload** | Pure networking logic, no spatial references |
| **Events autoload** | Signal bus with no 2D dependencies (signal parameters that pass Vector2 positions will change to Vector3, but the signal bus itself is unchanged) |
| **SoundManager autoload** | Audio logic is dimension-agnostic |
| **Wave state machine** (wave_manager.gd logic) | All spawn/state/timer logic is pure game logic. Only spawn positions change (Vector2 -> Vector3) |
| **Ability logic** (ability_manager.gd) | Reads input, manages cooldowns, delegates. No spatial code |
| **Super logic** (super_overdrive.gd, super_healing_pulse.gd) | Apply statuses, emit signals. Only visual RPCs need updating |
| **Status effect system** | Dictionary-based timers, pure logic |
| **Revive system logic** | Timer-based hold-to-revive. Only distance checks change (2D -> 3D) |
| **Role selection in lobby** | UI-only, stays 2D |
| **Host migration** | Snapshot/restore logic, no spatial references |
| **HUD CanvasLayer** | Stays as 2D overlay on top of 3D viewport |
| **Dual MultiplayerSynchronizer pattern** | Architecture unchanged; synced property types change |
| **MultiplayerSpawner setup** | Same spawn_path structure; scene references update to 3D versions |

---

## 3. Node Type Mapping

### Core Type Conversions

| 2D Type | 3D Type | Notes |
|---------|---------|-------|
| `CharacterBody2D` | `CharacterBody3D` | Player, all enemies |
| `StaticBody2D` | `StaticBody3D` | Walls, floor, turret |
| `Area2D` | `Area3D` | Projectile hit detection, hurtboxes |
| `CollisionShape2D` + `RectangleShape2D` | `CollisionShape3D` + `BoxShape3D` | All collision shapes |
| `CollisionShape2D` + `CircleShape2D` | `CollisionShape3D` + `SphereShape3D` | Aura radius detection |
| `Sprite2D` | `MeshInstance3D` | All entity visuals |
| `ColorRect` (visual effects) | `MeshInstance3D` or `GPUParticles3D` | Melee flash, scan zone, etc. |
| `Camera2D` | `Camera3D` | Player camera (now first-person) |
| `Marker2D` | `Marker3D` | Shoot point, spawn points |
| `Node2D` (containers) | `Node3D` (containers) | Players, Enemies, Projectiles, Effects |
| `Parallax2D` + `Sprite2D` | `WorldEnvironment` + `DirectionalLight3D` | Background visuals |
| `ProgressBar` (revive bar) | `ProgressBar` in CanvasLayer, or `Sprite3D` billboard | HUD-based for local player, billboard for others |
| `Label` (floating) | `Label3D` with billboard mode | "Repo Owner" label above host |

### Data Type Conversions

| 2D Type | 3D Type | Conversion Rule |
|---------|---------|-----------------|
| `Vector2(x, y)` (position) | `Vector3(x, 0, z)` | Y becomes Z, Y=0 for ground plane |
| `Vector2(x, y)` (direction) | `Vector3(x, 0, z)` | Same mapping, normalize after conversion |
| `Vector2(x, y)` (input_move_dir) | `Vector3(x, 0, z)` | Left/right stays X, forward/back becomes Z |
| `Vector2(x, y)` (input_aim_dir) | `Vector3(x, 0, z)` | Aim on the ground plane (pitch handled separately by camera) |
| `float` (rotation) | `Vector3` (rotation) or `Basis` | Y-axis rotation for facing direction |
| `move_and_slide()` | `move_and_slide()` | Same API on CharacterBody3D, returns bool |

---

## 4. Scene-by-Scene Conversion Plan

### 4.1 game.tscn -> game.tscn (3D)

**Root node:** `Node2D` -> `Node3D`

```
Game (Node3D) [script: game_manager.gd]
+-- WorldEnvironment
|   +-- Environment (sky, ambient light, fog)
+-- DirectionalLight3D (sun)
+-- Arena (Node3D)
|   +-- Floor (StaticBody3D)
|   |   +-- CollisionShape3D (BoxShape3D, flat)
|   |   +-- MeshInstance3D (PlaneMesh or BoxMesh)
|   +-- Walls (Node3D)
|   |   +-- NorthWall (StaticBody3D + CollisionShape3D + MeshInstance3D)
|   |   +-- SouthWall (StaticBody3D + CollisionShape3D + MeshInstance3D)
|   |   +-- EastWall (StaticBody3D + CollisionShape3D + MeshInstance3D)
|   |   +-- WestWall (StaticBody3D + CollisionShape3D + MeshInstance3D)
+-- Players (Node3D)
+-- Enemies (Node3D)
+-- Projectiles (Node3D)
+-- Effects (Node3D)
+-- WaveManager (Node) [script: wave_manager.gd]
+-- PlayerSpawner (MultiplayerSpawner)
+-- EnemySpawner (MultiplayerSpawner)
+-- ProjectileSpawner (MultiplayerSpawner)
+-- EffectsSpawner (MultiplayerSpawner)
+-- UI (CanvasLayer)
    +-- HUD (Control) [unchanged]
```

**Arena dimensions:**

| Property | 2D Value | 3D Value |
|----------|----------|----------|
| Floor size | 1200 x 600 px | 60 x 30 units (1 unit = 20px) |
| Wall height | N/A (2D) | 4 units |
| Wall thickness | 32 px | 1 unit |
| Arena bounds (playable) | (32, 32) to (1168, 568) | (-29, 0, -14) to (29, 0, 14) |

**Conversion factor:** 1 Godot 3D unit = 20 pixels from the 2D game. This keeps proportions feeling right.

**Removed:** Parallax2D layers (replaced by WorldEnvironment sky/fog).
**Added:** WorldEnvironment, DirectionalLight3D, OmniLight3D/SpotLight3D for arena lighting.

### 4.2 player.tscn -> player.tscn (3D)

**Root node:** `CharacterBody2D` -> `CharacterBody3D`

```
Player (CharacterBody3D) [script: player.gd]
+-- CollisionShape3D (CapsuleShape3D, radius=0.4, height=1.8)
+-- PlayerModel (Node3D)
|   +-- Body (MeshInstance3D — CapsuleMesh)
|   +-- Head (MeshInstance3D — SphereMesh)
|   +-- Visor (MeshInstance3D — BoxMesh)
+-- CameraMount (Node3D) [at head height, y=1.5]
|   +-- Camera3D [first-person, current for local player only]
+-- ShootPoint (Marker3D) [offset forward from camera]
+-- ServerSync (MultiplayerSynchronizer)
|   replicates: position, velocity, health, stamina, _is_downed,
|               _bleedout_timer, ability_cooldown, super_charge, active_statuses,
|               _look_angle_y (new: vertical look angle for remote player head tilt)
+-- InputSync (MultiplayerSynchronizer)
|   replicates: input_move_dir (Vector3), input_aim_dir (Vector3),
|               input_shoot, input_sprint, input_melee,
|               input_ability, input_super, input_interact,
|               _camera_pitch (new: for syncing where player is looking vertically)
+-- AbilityManager (Node) [script: ability_manager.gd]
+-- ReviveSystem (Node) [script: revive_system.gd]
```

**Key changes:**
- Camera is first-person, attached to CameraMount at head height
- PlayerModel is visible to other players but hidden for the local player (set `visible = false` on local peer's model, or use camera near-clip)
- CapsuleShape3D instead of RectangleShape2D for player collision
- ShootPoint is a Marker3D in front of the camera
- New synced property: `_camera_pitch` (float, vertical look angle) so other players' models can tilt

### 4.3 Enemy Scenes (all enemies)

Each enemy scene follows the same pattern:

**Before (2D):**
```
Enemy (CharacterBody2D)
+-- CollisionShape2D (RectangleShape2D)
+-- Sprite2D
+-- Hurtbox (Area2D)
|   +-- CollisionShape2D
+-- MultiplayerSynchronizer
```

**After (3D):**
```
Enemy (CharacterBody3D)
+-- CollisionShape3D (BoxShape3D or CapsuleShape3D)
+-- EnemyModel (MeshInstance3D — BoxMesh, CapsuleMesh, or imported .glb)
+-- Hurtbox (Area3D)
|   +-- CollisionShape3D
+-- MultiplayerSynchronizer
```

**Per-enemy model details:**

| Enemy | Mesh Type | Approximate Size (3D units) |
|-------|-----------|----------------------------|
| Merge Conflict T0 | BoxMesh (spiky/angular) | 2.4 x 2.4 x 2.4 |
| Merge Conflict T1 | BoxMesh | 1.6 x 1.6 x 1.6 |
| Merge Conflict T2 | BoxMesh | 1.0 x 1.0 x 1.0 |
| Hallucination (disguised) | SphereMesh (health pickup look) | 1.2 x 1.2 x 1.2 |
| Hallucination (revealed) | CapsuleMesh (tall, alien) | 2.0 x 2.0 x 2.0 |
| Context Rot | CylinderMesh (floating eye look) | 2.0 x 2.0 x 2.0 |
| Dependency Hell | BoxMesh (large, heavy) | 2.8 x 2.8 x 2.8 |
| Kernel Panic (boss) | BoxMesh (massive, BSOD screen) | 6.0 x 6.0 x 6.0 |

**Boss health bar and shield visual:** The boss_kernel_panic scene additionally has:
- HealthBarBG/HealthBarFill: Move to HUD CanvasLayer (2D health bar at top of screen)
- ShieldVisual: Becomes a MeshInstance3D (flat plane or curved mesh) positioned on the shield-facing side

### 4.4 projectile.tscn -> projectile.tscn (3D)

**Before:** `Area2D` with Sprite2D
**After:** `Area3D` with MeshInstance3D

```
Projectile (Area3D) [script: projectile.gd]
+-- CollisionShape3D (SphereShape3D, radius=0.15)
+-- MeshInstance3D (SphereMesh, small glowing orb)
+-- OmniLight3D (optional, small glow radius=1.0, dim)
```

### 4.5 projectile_enemy.tscn -> projectile_enemy.tscn (3D)

Same structure as player projectile but with enemy-colored material:

```
EnemyProjectile (Area3D) [script: projectile_enemy.gd]
+-- CollisionShape3D (SphereShape3D, radius=0.2)
+-- MeshInstance3D (SphereMesh, dark green / red glow)
```

### 4.6 turret.tscn -> turret.tscn (3D)

**Before:** `StaticBody2D`
**After:** `StaticBody3D`

```
Turret (StaticBody3D) [script: turret.gd]
+-- CollisionShape3D (BoxShape3D, 1.2 x 1.2 x 1.2)
+-- TurretModel (Node3D)
|   +-- Base (MeshInstance3D — CylinderMesh)
|   +-- Barrel (MeshInstance3D — BoxMesh, rotates toward target)
+-- ShootPoint (Marker3D)
+-- MultiplayerSynchronizer
```

### 4.7 lobby.tscn -> lobby.tscn (minimal changes)

The lobby scene already has a 3D preview stage (`lobby_stage_3d.tscn`/`lobby_stage_3d.gd`). The lobby UI is 2D and stays 2D. No conversion needed.

### 4.8 lobby_stage_3d.tscn -> lobby_stage_3d.tscn (no changes)

Already 3D. No conversion needed.

---

## 5. Script-by-Script Change List

### 5.1 player.gd (MAJOR CHANGES)

This is the largest single script change. Every spatial operation converts from 2D to 3D.

| Section | Change |
|---------|--------|
| **Class declaration** | `extends CharacterBody2D` -> `extends CharacterBody3D` |
| **Constants** | All speed values stay the same numerically (they'll feel different at 3D scale; tune after) |
| **Position/velocity** | All `Vector2` -> `Vector3` with Y=0 for ground plane |
| **input_move_dir** | `Vector2` -> `Vector3` (x, 0, z). Input gathering uses camera-relative directions |
| **input_aim_dir** | `Vector2` -> `Vector3`. In FPS, aim is camera forward projected onto ground plane (or full 3D if we want vertical aiming) |
| **_facing** | Remove the `get: return 1 if input_aim_dir.x >= 0.0 else -1` pattern. In 3D, facing is the player's `rotation.y` |
| **_gather_input()** | Complete rewrite for FPS: mouse moves camera (pitch/yaw), WASD is camera-relative movement, aim_dir comes from camera forward vector |
| **Camera setup** | Remove `$Camera2D.make_current()`. Add `$CameraMount/Camera3D.make_current()` for local player. Hide local PlayerModel |
| **_server_process()** | `velocity = input_move_dir * current_speed` stays the same pattern but with Vector3. Remove gravity (we're on a flat arena). `move_and_slide()` API is the same |
| **_process()** | Remove `$Sprite2D.rotation = input_aim_dir.angle()`. Replace with `rotation.y` based on aim direction. For remote players, interpolate model rotation |
| **_fire_projectile()** | ShootPoint is now Marker3D. Spawn position is `$ShootPoint.global_position`. Direction is `input_aim_dir` (Vector3). Projectile scene is 3D |
| **_do_melee()** | Cone check: `to_enemy.normalized().dot(input_aim_dir) > 0.3` -- same logic, just with Vector3 |
| **Visual RPCs** | `_show_melee_visual()`: Replace ColorRect with MeshInstance3D or particles. `_show_overdrive_visual()`: Replace with material glow or particles. `_show_healing_visual()`: Replace with green particles. `_show_scan_visual()`: Replace with expanding sphere mesh or particles. `_show_downed_visual()`: Change Sprite2D texture -> change model material |
| **_update_hud()** | Unchanged (reads synced values, writes to CanvasLayer labels) |
| **Collision setup** | `collision_layer = 2; collision_mask = 5` stays the same bitmask values, but collision shapes are 3D |
| **die()** | `velocity = Vector2.ZERO` -> `velocity = Vector3.ZERO`. Position signal changes from Vector2 to Vector3 |
| **New: Camera pitch** | Add `_camera_pitch: float = 0.0` synced via InputSync. Mouse Y movement rotates CameraMount around local X axis. Clamped to +/- 85 degrees |
| **New: Mouse capture** | In `_ready()` for local player: `Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)`. Add `_input()` handler for mouse motion |

**New input gathering for FPS:**

```gdscript
# Pseudocode for _gather_input() in 3D FPS mode
func _gather_input() -> void:
    # Mouse look is handled in _input() via InputEventMouseMotion
    # WASD movement is camera-relative:
    var move_x := Input.get_axis("move_left", "move_right")
    var move_z := Input.get_axis("move_up", "move_down")  # "up" = forward, "down" = backward

    # Transform movement to be relative to camera yaw (player rotation.y)
    var cam_basis := Basis(Vector3.UP, rotation.y)
    var local_move := Vector3(move_x, 0, move_z).normalized()
    input_move_dir = cam_basis * local_move
    if input_move_dir.length() > 1.0:
        input_move_dir = input_move_dir.normalized()

    # Aim direction: camera forward vector projected to ground plane
    # For projectiles, we may want the full 3D aim (including pitch)
    var cam := $CameraMount/Camera3D as Camera3D
    input_aim_dir = -cam.global_transform.basis.z  # Camera looks along -Z in local space
```

**New mouse look handler:**

```gdscript
const MOUSE_SENSITIVITY: float = 0.002

var _camera_pitch: float = 0.0  # Synced via InputSync

func _input(event: InputEvent) -> void:
    if player_id != multiplayer.get_unique_id():
        return
    if not get_window().has_focus():
        return
    if event is InputEventMouseMotion:
        # Yaw: rotate the player body
        rotation.y -= event.relative.x * MOUSE_SENSITIVITY
        # Pitch: rotate the camera mount (clamped)
        _camera_pitch -= event.relative.y * MOUSE_SENSITIVITY
        _camera_pitch = clampf(_camera_pitch, deg_to_rad(-85), deg_to_rad(85))
        $CameraMount.rotation.x = _camera_pitch
```

### 5.2 enemy_base.gd (MODERATE CHANGES)

| Section | Change |
|---------|--------|
| **Class declaration** | `extends CharacterBody2D` -> `extends CharacterBody3D` |
| **_state_chase()** | `var dir := (target.global_position - global_position).normalized()` -- works with Vector3. Ensure Y component is zeroed: `dir.y = 0; dir = dir.normalized()` |
| **_state_flee()** | Same Vector3 conversion, zero Y |
| **_state_stunned()** | `velocity = Vector2.ZERO` -> `velocity = Vector3.ZERO` |
| **_find_nearest_player()** | `global_position.distance_to(player.global_position)` works in 3D but measures full 3D distance. Since everything is on the ground plane, this is fine. If needed, use `Vector2(pos.x, pos.z).distance_to(...)` for strictly horizontal distance |
| **_check_contact_damage()** | Same distance check pattern, just with Vector3 positions. The 50-unit distance needs to be converted: `50px / 20 = 2.5 units` |
| **_show_hit_flash()** | Change from Sprite2D modulate to MeshInstance3D material emission pulse |
| **_show_melee_strike()** | The hit ring visual becomes a 3D expanding sphere/ring mesh |
| **_process()** (sprite rotation) | Remove `$Sprite2D.rotation = dir.angle()`. Replace with `look_at()` or manual Y rotation toward target |
| **Collision setup** | Same bitmask values, 3D shapes |
| **apply_scaling()** | Unchanged (just modifies health/speed floats) |

### 5.3 All Enemy Subclasses

**enemy_merge_conflict.gd:**

| Change | Detail |
|--------|--------|
| Size tiers | `TIER_SIZE: Array[Vector2]` -> irrelevant (mesh scale instead). Add `TIER_SCALE: Array[float] = [1.0, 0.67, 0.42]` |
| `_apply_tier_stats()` | Instead of setting Sprite2D texture and RectangleShape2D size, scale the CollisionShape3D and MeshInstance3D |
| `_spawn_children()` | Offset `Vector2(offset, 0)` -> `Vector3(offset_x, 0, offset_z)`. Use random XZ offset |
| Visual update | Replace Sprite2D texture swap with material color change on MeshInstance3D |

**enemy_hallucination.gd:**

| Change | Detail |
|--------|--------|
| Size constants | `HALL_DISGUISED_SIZE` / `HALL_REVEALED_SIZE` become scale floats |
| `_update_visual_disguised()` | Swap mesh or material instead of Sprite2D texture |
| `_update_visual_revealed()` | Swap mesh from sphere (pickup look) to capsule (alien), update collision shape scale |
| `_check_reveal_trigger()` | Distance check works the same with Vector3 (convert 80px to 4.0 units) |

**enemy_context_rot.gd:**

| Change | Detail |
|--------|--------|
| `_fire_rot_projectile()` | Direction is Vector3. Spawn position offset: `global_position + direction * 1.25` (25px / 20). Projectile scene is 3D |
| Range constants | `CR_FIRE_RANGE: 350px` -> `17.5 units`. `CR_FLEE_RANGE: 100px` -> `5.0 units` |

**enemy_dependency_hell.gd:**

| Change | Detail |
|--------|--------|
| `_apply_aura()` | Distance check: `DH_AURA_RADIUS: 200px` -> `10.0 units`. Same logic otherwise |
| Visual aura | Could add a transparent SphereMesh or particles to show the aura radius in 3D |

**enemy_kernel_panic.gd:**

| Change | Detail |
|--------|--------|
| `_lunge_direction` | `Vector2` -> `Vector3` (zero Y) |
| `_shield_facing_dir` | `Vector2` -> `Vector3` (zero Y) |
| `_fire_projectile_spread()` | Direction rotation: `base_dir.rotated(angle)` -> rotate around Y axis: `base_dir.rotated(Vector3.UP, angle)` |
| `_check_contact_damage()` | Distance: 80px -> 4.0 units |
| `_spawn_crash_dumps()` | Offset: `Vector2(randf_range(-40, 40), randf_range(-40, 40))` -> `Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))` |
| Shield visual | `ColorRect` -> `MeshInstance3D` (flat plane mesh positioned on shield side) |
| Health bar | Move from in-scene ColorRect to HUD CanvasLayer (2D bar at top of screen, visible when boss is alive) |

### 5.4 projectile.gd (MODERATE CHANGES)

| Section | Change |
|---------|--------|
| **Class declaration** | `extends Area2D` -> `extends Area3D` |
| **direction** | `Vector2` -> `Vector3` |
| **_ready()** | Remove `rotation = direction.angle()`. Add `look_at(global_position + direction, Vector3.UP)` or equivalent |
| **_physics_process()** | `position += direction * speed * delta` works the same with Vector3 |
| **_on_body_entered()** | `CharacterBody2D` -> `CharacterBody3D` type check |
| **collision_mask** | Same bitmask values |

### 5.5 projectile_enemy.gd (MODERATE CHANGES)

Same pattern as projectile.gd. `extends Area2D` -> `extends Area3D`. Direction is Vector3.

### 5.6 turret.gd (MODERATE CHANGES)

| Section | Change |
|---------|--------|
| **Class declaration** | `extends StaticBody2D` -> `extends StaticBody3D` |
| **_fire_at()** | Direction: `(target.global_position - global_position).normalized()` -> zero Y: `var dir := Vector3(delta.x, 0, delta.z).normalized()` |
| **_find_nearest_enemy()** | Distance check with Vector3. `TURRET_RANGE: 250px` -> `12.5 units` |
| **Barrel rotation** | Add visual: rotate barrel MeshInstance3D toward current target |

### 5.7 ability_weak_point_scan.gd (MINOR CHANGES)

| Change | Detail |
|--------|--------|
| `activate(player_pos: Vector2, _aim_dir: Vector2)` | -> `activate(player_pos: Vector3, _aim_dir: Vector3)` |
| `SCAN_RADIUS: 300px` | -> `15.0 units` |
| Distance check | `enemy.global_position.distance_to(player_pos)` works with Vector3 |
| Scan visual RPC | `player._show_scan_visual.rpc(player_pos, SCAN_RADIUS)` -- visual changes from ColorRect to 3D sphere |

### 5.8 ability_deploy_turret.gd (MINOR CHANGES)

| Change | Detail |
|--------|--------|
| `activate(player_pos: Vector2, aim_dir: Vector2)` | -> `activate(player_pos: Vector3, aim_dir: Vector3)` |
| Turret position | `player_pos + aim_dir * 60.0` -> `player_pos + aim_dir * 3.0` (60px / 20) |

### 5.9 super_overdrive.gd (NO CHANGES)

Pure logic: applies status and calls visual RPC. The visual RPC on player.gd changes, but this script itself is unchanged.

### 5.10 super_healing_pulse.gd (MINIMAL CHANGES)

Only change: if `ReviveBar` creation used Vector2 for position, that changes. The healing logic is pure game logic.

### 5.11 wave_manager.gd (MINOR CHANGES)

| Section | Change |
|---------|--------|
| **Arena bounds constants** | `ARENA_LEFT/RIGHT/TOP/BOTTOM` (px) -> `ARENA_MIN_X/MAX_X/MIN_Z/MAX_Z` (3D units) |
| **_random_edge_position()** | Returns `Vector3` instead of `Vector2`. Spawns along edges of the 3D arena |
| **All other logic** | Unchanged (wave state machine, difficulty scaling, enemy type picking) |

**New arena constants:**
```gdscript
const ARENA_MIN_X: float = -29.0
const ARENA_MAX_X: float = 29.0
const ARENA_MIN_Z: float = -14.0
const ARENA_MAX_Z: float = 14.0
const SPAWN_Y: float = 0.0  # Ground level

func _random_edge_position() -> Vector3:
    var edge := randi() % 4
    match edge:
        0:  # North (negative Z)
            return Vector3(randf_range(ARENA_MIN_X, ARENA_MAX_X), SPAWN_Y, ARENA_MIN_Z)
        1:  # East (positive X)
            return Vector3(ARENA_MAX_X, SPAWN_Y, randf_range(ARENA_MIN_Z, ARENA_MAX_Z))
        2:  # South (positive Z)
            return Vector3(randf_range(ARENA_MIN_X, ARENA_MAX_X), SPAWN_Y, ARENA_MAX_Z)
        _:  # West (negative X)
            return Vector3(ARENA_MIN_X, SPAWN_Y, randf_range(ARENA_MIN_Z, ARENA_MAX_Z))
```

### 5.12 game_manager.gd (MODERATE CHANGES)

| Section | Change |
|---------|--------|
| **Class declaration** | `extends Node2D` -> `extends Node3D` |
| **PLAYER_SPAWN_POSITIONS** | `Array[Vector2]` -> `Array[Vector3]`. Centered in arena |
| **_create_repo_owner_label()** | Use `Label3D` with billboard mode instead of HUD Label + screen-space positioning. OR keep as HUD label and project 3D position to screen (like the existing `get_global_transform_with_canvas().origin` pattern -- but that's 2D-only; use `camera.unproject_position()` in 3D) |
| **_process()** | Repo owner label tracking: use `Camera3D.unproject_position(host_player.global_position)` to get screen coords, then position the HUD label. Or use Label3D billboard above the player in 3D space |
| **Snapshot** | `position` in snapshot is Vector3. Backward-compatible because we're replacing the whole scene |

**New spawn positions:**
```gdscript
const PLAYER_SPAWN_POSITIONS: Array[Vector3] = [
    Vector3(-3, 0, -2),
    Vector3(3, 0, -2),
    Vector3(-3, 0, 2),
    Vector3(3, 0, 2),
]
```

### 5.13 revive_system.gd (MINOR CHANGES)

| Section | Change |
|---------|--------|
| `REVIVE_RANGE: 80px` | -> `4.0 units` |
| Distance check | Works with Vector3 positions, no other change needed |
| `_update_revive_bar()` | The ProgressBar added as child of a CharacterBody3D won't render in 3D. Options: (a) Use `SubViewport` + `Sprite3D` billboard, (b) Move to HUD CanvasLayer and position via `camera.unproject_position()`, (c) Use a `Sprite3D` with a texture-based bar. **Recommendation:** Put it in the HUD CanvasLayer for simplicity, matching the existing pattern for floating labels |

### 5.14 events.gd (MINOR CHANGES)

Update signal parameter types where positions are passed:

```gdscript
# Before:
signal player_joined(player_id: int, spawn_position: Vector2)
signal player_died(player_id: int, position: Vector2)
signal player_downed(player_id: int, position: Vector2)
signal enemy_spawned(enemy_id: int, enemy_type: String, position: Vector2)
signal enemy_split(parent_id: int, child_ids: Array, positions: Array)
signal ability_activated(player_id: int, ability: String, position: Vector2, direction: Vector2)
signal turret_deployed(owner_id: int, turret_id: int, position: Vector2)
signal hallucination_revealed(enemy_id: int, position: Vector2)
signal boss_spawned(boss_id: int, boss_type: String, position: Vector2)

# After:
signal player_joined(player_id: int, spawn_position: Vector3)
signal player_died(player_id: int, position: Vector3)
signal player_downed(player_id: int, position: Vector3)
signal enemy_spawned(enemy_id: int, enemy_type: String, position: Vector3)
signal enemy_split(parent_id: int, child_ids: Array, positions: Array)
signal ability_activated(player_id: int, ability: String, position: Vector3, direction: Vector3)
signal turret_deployed(owner_id: int, turret_id: int, position: Vector3)
signal hallucination_revealed(enemy_id: int, position: Vector3)
signal boss_spawned(boss_id: int, boss_type: String, position: Vector3)
```

### 5.15 lobby_stage_3d.gd (NO CHANGES)

Already 3D. The character figures it creates match what the in-game models should look like.

### 5.16 lobby.gd (NO CHANGES)

The lobby is 2D UI with a 3D SubViewport preview. Nothing changes.

### 5.17 network_manager.gd (NO CHANGES)

Pure networking logic. The cached snapshot contains position data that changes type, but the snapshot is a Dictionary with variant values, so it handles Vector3 transparently.

### 5.18 sound_manager.gd (NO CHANGES)

Audio is dimension-agnostic. Optionally upgrade to `AudioStreamPlayer3D` for positional audio later (not in this phase).

---

## 6. New 3D Systems

### 6.1 First-Person Camera System

The player gets a first-person camera mounted at head height.

**Architecture:**
```
Player (CharacterBody3D)
+-- CameraMount (Node3D) [y = 1.5, pitch rotation on X axis]
    +-- Camera3D [current for local player only]
```

**Mouse look:**
- Mouse X -> Player `rotation.y` (yaw)
- Mouse Y -> CameraMount `rotation.x` (pitch), clamped to [-85, 85] degrees
- Mouse captured via `Input.MOUSE_MODE_CAPTURED`
- ESC to release mouse (for menu/disconnect)
- Re-capture on click

**Controller look:**
- Right stick X -> Player `rotation.y` (yaw), scaled by sensitivity
- Right stick Y -> CameraMount `rotation.x` (pitch), same clamping

**Syncing:**
- `_camera_pitch: float` added to InputSync so remote players' head models tilt correctly
- Player `rotation.y` is implicitly synced because `position` and facing are server-authoritative. Actually, for smooth interpolation, we should sync `rotation.y` via ServerSync

**New ServerSync property:**
```
rotation.y -> synced as float for visual interpolation on remote players
```

### 6.2 Camera-Relative Movement

In 2D top-down, WASD moved in screen-space (up = -Y, right = +X). In 3D FPS, WASD must be relative to where the camera is facing:

```gdscript
# Camera-relative movement
var forward := Vector3.FORWARD.rotated(Vector3.UP, rotation.y)  # Player's forward
var right := Vector3.RIGHT.rotated(Vector3.UP, rotation.y)      # Player's right

var move_input := Vector3.ZERO
move_input += forward * Input.get_axis("move_down", "move_up")    # W/S
move_input += right * Input.get_axis("move_left", "move_right")   # A/D
input_move_dir = move_input.normalized() if move_input.length() > 0 else Vector3.ZERO
```

**Important:** The input actions `move_up`/`move_down` still mean "forward/backward" in the input map. The names are from the 2D era. We may want to alias them as `move_forward`/`move_backward` but the actual bindings (W/S) stay the same.

### 6.3 3D Shooting (Raycasting)

In 2D, projectiles are spawned at a ShootPoint with a direction from `input_aim_dir`. In 3D FPS, the aim direction comes from the camera center (crosshair):

```gdscript
func _get_aim_direction() -> Vector3:
    var cam := $CameraMount/Camera3D as Camera3D
    return -cam.global_transform.basis.z  # Camera forward is -Z in local space
```

**Projectile spawning:**
```gdscript
func _fire_projectile() -> void:
    var cam := $CameraMount/Camera3D as Camera3D
    var aim_dir := -cam.global_transform.basis.z
    $ShootPoint.global_position = cam.global_position + aim_dir * 1.0  # 1 unit in front of camera

    var projectile = _projectile_scene.instantiate()
    projectile.direction = aim_dir
    projectile.owner_id = player_id
    projectile.position = $ShootPoint.global_position
    # ... same spawning logic
```

**Optional: Hitscan raycast for instant feedback.** The current game uses projectile travel, which works fine in 3D. No need to switch to hitscan unless we want to.

### 6.4 3D Arena Construction

The arena is a rectangular room:

```
Floor: PlaneMesh or BoxMesh (60 x 1 x 30), positioned at Y = -0.5
North Wall: BoxMesh (60 x 4 x 1), positioned at Z = -15
South Wall: BoxMesh (60 x 4 x 1), positioned at Z = 15
East Wall: BoxMesh (1 x 4 x 30), positioned at X = 30
West Wall: BoxMesh (1 x 4 x 30), positioned at X = -30
```

**Materials:** Use `StandardMaterial3D` with the theme colors (dark cyberpunk/tech aesthetic matching the "software bugs" theme). Emission on edges for a neon look.

**Lighting:**
- `DirectionalLight3D` for overall ambient (dim, blue-tinted)
- `OmniLight3D` scattered around arena for neon accent lighting
- Player projectiles can have small `OmniLight3D` for dramatic effect

**WorldEnvironment:**
- Dark sky or enclosed ceiling (no sky visible)
- Ambient light: dim, cool-toned
- Fog: short range to add atmosphere and hide hard arena edges
- Glow post-processing: enhances the neon aesthetic

### 6.5 3D Visuals for Effects

| 2D Effect | 3D Replacement |
|-----------|---------------|
| Melee swing (ColorRect flash) | MeshInstance3D arc + fade tween, or GPUParticles3D burst |
| Overdrive glow (ColorRect border) | Material emission on player model + OmniLight3D glow |
| Healing pulse (green ColorRect) | GPUParticles3D green burst on all players |
| Scan zone (yellow ColorRect) | Transparent SphereMesh expanding + fading, or GPUParticles3D ring |
| Downed visual | Material swap to gray + alpha pulse on model |
| Hit flash (enemy) | Material emission spike |
| Boss lunge telegraph | Red material flash |
| Boss shield | MeshInstance3D flat plane with shield material, positioned by facing direction |
| Contact damage ring | GPUParticles3D expanding ring |

### 6.6 Crosshair

Add a simple crosshair to the HUD:

```
UI (CanvasLayer)
+-- HUD (Control)
    +-- Crosshair (TextureRect or ColorRect) [centered on screen, small +/dot]
```

Small white dot or thin cross lines, centered at viewport center. Only visible for the local player.

---

## 7. Multiplayer Sync Changes

### 7.1 ServerSync Property Updates

**Player ServerSync:**

| Property | 2D Type | 3D Type | Notes |
|----------|---------|---------|-------|
| `position` | `Vector2` | `Vector3` | Automatic with CharacterBody3D |
| `velocity` | `Vector2` | `Vector3` | Automatic with CharacterBody3D |
| `health` | `int` | `int` | Unchanged |
| `stamina` | `float` | `float` | Unchanged |
| `_is_downed` | `bool` | `bool` | Unchanged |
| `_bleedout_timer` | `float` | `float` | Unchanged |
| `ability_cooldown` | `float` | `float` | Unchanged |
| `super_charge` | `float` | `float` | Unchanged |
| `active_statuses` | `PackedStringArray` | `PackedStringArray` | Unchanged |
| `rotation.y` | **NEW** | `float` | Player facing direction (yaw) |

**Player InputSync:**

| Property | 2D Type | 3D Type | Notes |
|----------|---------|---------|-------|
| `input_move_dir` | `Vector2` | `Vector3` | XZ ground plane movement |
| `input_aim_dir` | `Vector2` | `Vector3` | Camera forward direction |
| `input_shoot` | `bool` | `bool` | Unchanged |
| `input_sprint` | `bool` | `bool` | Unchanged |
| `input_melee` | `bool` | `bool` | Unchanged |
| `input_ability` | `bool` | `bool` | Unchanged |
| `input_super` | `bool` | `bool` | Unchanged |
| `input_interact` | `bool` | `bool` | Unchanged |
| `_camera_pitch` | **NEW** | `float` | Vertical look angle for remote player model |

### 7.2 Enemy MultiplayerSynchronizer Updates

Position changes from Vector2 to Vector3 automatically. All other synced properties (health, _current_state, size_tier, is_disguised, etc.) remain unchanged.

For the boss, `_shield_facing_dir` changes from Vector2 to Vector3.

### 7.3 RPC Parameter Changes

RPCs that pass position/direction parameters need type updates:

| RPC | Parameter Changes |
|-----|-------------------|
| `_show_melee_visual(aim_dir)` | `Vector2` -> `Vector3` |
| `_show_scan_visual(center, radius)` | `center: Vector2` -> `center: Vector3` |
| `_show_melee_strike(hit_pos)` | `Vector2` -> `Vector3` |

**Important architectural note:** RPCs on the player node work fine because player nodes exist on all peers (via MultiplayerSpawner). RPCs on enemy nodes also work because enemies are replicated via EnemySpawner. This does NOT change in 3D. The critical pattern from MEMORY.md ("RPC on dynamically-added nodes WILL FAIL on clients") still applies -- ability/super child nodes are still dynamically added server-side, so visuals must still be routed through player.gd or enemy_base.gd RPCs.

### 7.4 MultiplayerSpawner Scene References

Update all `_spawnable_scenes` to reference the new 3D scene files. If we keep the same file paths (just replacing the .tscn content), the spawner config doesn't change. If we create new paths, update the spawner entries.

**Recommendation:** Keep the same file paths. Replace the .tscn content in-place. This avoids touching spawner configuration.

---

## 8. Physics and Collision Migration

### 8.1 Collision Layer Assignment (Unchanged)

| Layer | Bit | Entities |
|-------|-----|----------|
| 1 | 1 | Walls, floor (static geometry) |
| 2 | 2 | Players |
| 3 | 4 | Enemies |

**Player:** `collision_layer = 2, collision_mask = 5` (layers 1 + 3)
**Enemy:** `collision_layer = 4, collision_mask = 3` (layers 1 + 2)
**Projectile (player):** `collision_mask = 4` (layer 3 = enemies)
**Projectile (enemy):** `collision_mask = 2` (layer 2 = players)

These bitmasks stay identical. Godot 4's collision layers work the same in 2D and 3D.

### 8.2 Contact Damage Distance Conversion

All distance-based checks need pixel-to-unit conversion (divide by 20):

| Check | 2D Distance (px) | 3D Distance (units) |
|-------|-------------------|---------------------|
| Base enemy contact damage | 50 | 2.5 |
| Boss contact damage | 80 | 4.0 |
| Melee range | 60 | 3.0 |
| Hallucination reveal range | 80 | 4.0 |
| Context Rot fire range | 350 | 17.5 |
| Context Rot flee range | 100 | 5.0 |
| Dependency Hell aura | 200 | 10.0 |
| Turret range | 250 | 12.5 |
| Revive range | 80 | 4.0 |
| Scan radius | 300 | 15.0 |

### 8.3 Collision Shape Sizes

| Entity | 2D Shape | 3D Shape | Size |
|--------|----------|----------|------|
| Player | RectangleShape2D(32, 32) | CapsuleShape3D | radius=0.4, height=1.8 |
| Merge Conflict T0 | RectangleShape2D(48, 48) | BoxShape3D | 2.4 x 2.4 x 2.4 |
| Merge Conflict T1 | RectangleShape2D(32, 32) | BoxShape3D | 1.6 x 1.6 x 1.6 |
| Merge Conflict T2 | RectangleShape2D(20, 20) | BoxShape3D | 1.0 x 1.0 x 1.0 |
| Hallucination (disguised) | RectangleShape2D(24, 24) | SphereShape3D | radius=0.6 |
| Hallucination (revealed) | RectangleShape2D(40, 40) | CapsuleShape3D | radius=0.5, height=2.0 |
| Context Rot | RectangleShape2D(40, 40) | CapsuleShape3D | radius=0.5, height=2.0 |
| Dependency Hell | RectangleShape2D(56, 56) | BoxShape3D | 2.8 x 2.8 x 2.8 |
| Kernel Panic | RectangleShape2D(120, 120) | BoxShape3D | 6.0 x 6.0 x 6.0 |
| Turret | RectangleShape2D(24, 24) | BoxShape3D | 1.2 x 1.2 x 1.2 |
| Player Projectile | (Area2D circle) | SphereShape3D | radius=0.15 |
| Enemy Projectile | (Area2D circle) | SphereShape3D | radius=0.2 |

### 8.4 Gravity

The 2D game is top-down with no gravity. In 3D, `CharacterBody3D` has gravity support but we don't want it -- the arena is flat and everything stays on the ground.

**Solution:** Do NOT apply gravity in `_server_process()`. Set `velocity.y = 0` if needed. The game is a flat arena shooter, not a platformer. If an entity somehow gets bumped off the ground plane, clamp `position.y = 0`.

Alternatively, in project settings, set the 3D physics gravity to 0 for this project. Or just never set a Y velocity component.

---

## 9. HUD and UI Strategy

### 9.1 HUD Stays 2D

The HUD is already a CanvasLayer overlay. It stays exactly as-is:

```
UI (CanvasLayer)
+-- HUD (Control)
    +-- HealthLabel
    +-- StaminaBar
    +-- WaveLabel
    +-- AbilityLabel
    +-- SuperLabel
    +-- ControlsLabel
    +-- EndScreen
    +-- Crosshair (NEW)
```

All HUD logic in `player._update_hud()` reads synced values and writes to labels. This is completely dimension-agnostic.

### 9.2 New Crosshair Element

Add a small white dot/cross at the center of the screen:

```gdscript
# In game.tscn, add under UI/HUD:
[node name="Crosshair" type="ColorRect" parent="UI/HUD"]
layout_mode = 1
anchors_preset = 8  # CENTER
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -2.0
offset_top = -2.0
offset_right = 2.0
offset_bottom = 2.0
color = Color(1, 1, 1, 0.8)
```

A 4x4 pixel white square at screen center. Simple and functional.

### 9.3 Floating Labels / Bars in 3D

The "Repo Owner" label currently positions itself by converting world-to-screen coords:
```gdscript
var screen_pos: Vector2 = host_player.get_global_transform_with_canvas().origin
```

In 3D, `get_global_transform_with_canvas()` doesn't exist on Node3D. Instead:

**Option A: Use Label3D (recommended for simplicity)**
```gdscript
# Label3D as child of the player, billboard mode
var label := Label3D.new()
label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
label.position = Vector3(0, 2.5, 0)  # Above head
label.text = "Repo Owner"
host_player.add_child(label)
```

**Option B: HUD label + camera projection**
```gdscript
var cam := get_viewport().get_camera_3d()
if cam:
    var screen_pos := cam.unproject_position(host_player.global_position + Vector3(0, 2.5, 0))
    if cam.is_position_behind(host_player.global_position):
        label.visible = false
    else:
        label.position = screen_pos - label.size / 2.0
        label.visible = true
```

**Recommendation:** Use Option A (Label3D) for the "Repo Owner" label. It's simpler, already proven in lobby_stage_3d.gd, and doesn't require per-frame camera projection.

For the revive progress bar, use Option B (project to HUD) since ProgressBar is a Control node.

### 9.4 Boss Health Bar

Currently the boss has a health bar as child nodes (HealthBarBG, HealthBarFill) of the boss scene. In 3D, these should move to the HUD:

```
UI/HUD/BossHealthBar (Control) [hidden by default]
+-- HealthBarBG (ColorRect)
+-- HealthBarFill (ColorRect)
+-- BossNameLabel (Label)
```

The wave_manager already sends `_notify_boss_spawned` RPC. Add logic to show the boss health bar on this event. The boss health is synced via MultiplayerSynchronizer, so the HUD can poll it or the boss can emit a signal on damage.

### 9.5 Controls Label Update

The controls label needs updating for FPS:

```
WASD  Move  |  L Stick
Mouse  Look/Aim  |  R Stick
LMB  Shoot  |  RT
K  Melee  |  X
RMB  Ability  |  LT
E  Super  |  LB
Shift  Sprint  |  RB
F  Revive  |  Y
ESC  Release Mouse
```

---

## 10. Risk Areas and Known Pitfalls

### 10.1 CRITICAL: RPC on Dynamic Nodes Still Fails

This is the #1 recurring bug from the project memory. The pattern does NOT change in 3D:

- AbilityManager is a scene node (exists on all peers) -- safe
- Ability and Super child nodes are DYNAMICALLY added by `game_manager._setup_player_abilities()` -- still server-only
- All visual RPCs MUST continue to be routed through `player.gd` or `enemy_base.gd` (nodes that exist on all peers)

**No change needed in the routing pattern. Just don't break it during conversion.**

### 10.2 Vector2 -> Vector3 Incomplete Conversion

The biggest risk is missing a Vector2 somewhere. Every script file must be audited for:
- `Vector2` type annotations and default values
- `.angle()` calls (no direct equivalent in Vector3; use `atan2()` or `look_at()`)
- `.rotated(angle)` (use `.rotated(Vector3.UP, angle)` for ground-plane rotation)
- `.normalized()` (works the same, but ensure Y is zeroed for ground-plane operations)
- `distance_to()` (works in 3D but measures full 3D distance; for ground-plane only, zero Y first)

### 10.3 move_and_slide() Behavior Differences

In 2D `CharacterBody2D`, `move_and_slide()` returns void. In 3D `CharacterBody3D`, `move_and_slide()` also returns void (as of Godot 4.x). The API is the same. However:

- 3D `move_and_slide()` considers the `up_direction` property (default `Vector3.UP`)
- Floor detection works differently (walls vs. floor vs. ceiling)
- Set `floor_max_angle` to `0` if we never want floor sliding behavior (flat arena)

### 10.4 CharacterBody3D Contact Detection Still Fails

The MEMORY.md note about `Area2D.get_overlapping_bodies()` returning empty for CharacterBody2D also applies in 3D. The existing distance-based contact damage check is correct and should be kept.

### 10.5 Camera on Remote Players

Only the LOCAL player should have an active Camera3D. Remote players should NOT have their cameras enabled. The existing pattern:

```gdscript
if player_id == multiplayer.get_unique_id():
    $CameraMount/Camera3D.make_current()
```

This stays the same. But additionally, we need to handle the camera when the player is downed (keep camera active but maybe allow looking around, or fix it at death position).

### 10.6 Mouse Capture Edge Cases

- When the EndScreen panel shows, release the mouse
- When the window loses focus, release the mouse (already handled for input)
- When opening any menu/overlay, release the mouse
- ESC key should toggle mouse capture
- Clicking the window should re-capture

### 10.7 First-Person Model Visibility

The local player should NOT see their own body model (it would fill the screen). Options:
- Set `$PlayerModel.visible = false` for the local player
- Use camera near-clip to hide geometry close to the camera
- Use render layers to exclude the local model from the local camera

**Recommendation:** `$PlayerModel.visible = false` on the local peer. Remote players see each other's models.

### 10.8 Projectile Direction in FPS

In 2D top-down, projectiles travel along the 2D aim direction. In 3D FPS, the player might be looking up or down. Projectiles should travel in the full 3D aim direction (including pitch), not just the ground plane. This means projectiles can fly above enemies or into the ground.

**Decision:** Allow full 3D aiming. Projectiles travel along the camera forward vector. This feels natural for FPS. The projectile's Area3D collision will detect hits in 3D space.

### 10.9 Enemy AI Y-Axis Issues

Enemies chase players on the ground plane. Their AI must zero out the Y component of direction vectors:

```gdscript
var dir := (target.global_position - global_position)
dir.y = 0  # Stay on ground plane
dir = dir.normalized()
velocity = dir * speed
```

If this is missed, enemies will try to move vertically (Y) toward a player's head position, causing weird behavior.

### 10.10 Timer Callbacks on Freed Nodes

The MEMORY.md note about timer callbacks crashing on freed nodes still applies. All existing `is_instance_valid()` guards must be preserved during conversion. The 3D visual replacements (MeshInstance3D, GPUParticles3D) should use the same guard pattern:

```gdscript
get_tree().create_timer(0.3).timeout.connect(func():
    if is_instance_valid(mesh):
        mesh.queue_free()
)
```

---

## 11. Implementation Order

The conversion should be done in phases, with each phase producing a testable result.

### Phase 3A: Core Player and Arena (TEST: Player can move and look around in 3D)

1. **Convert game.tscn to 3D**
   - Replace root Node2D with Node3D
   - Remove Parallax layers
   - Add WorldEnvironment + DirectionalLight3D
   - Build 3D arena (floor + 4 walls as StaticBody3D + MeshInstance3D)
   - Keep Players/Enemies/Projectiles/Effects as Node3D containers
   - Keep WaveManager as-is (Node)
   - Keep MultiplayerSpawner nodes
   - Keep UI CanvasLayer + HUD
   - Add Crosshair to HUD

2. **Convert player.tscn to 3D**
   - Replace CharacterBody2D with CharacterBody3D
   - Add CapsuleShape3D collision
   - Add PlayerModel (capsule body + sphere head, matching lobby_stage_3d.gd style)
   - Add CameraMount + Camera3D
   - Replace Marker2D with Marker3D for ShootPoint
   - Update ServerSync and InputSync replication configs

3. **Convert player.gd for 3D FPS**
   - Change extends to CharacterBody3D
   - Add mouse look (`_input()` handler, sensitivity, pitch clamping)
   - Add camera-relative movement in `_gather_input()`
   - Convert `_server_process()` to Vector3
   - Hide local player model
   - Add mouse capture/release
   - Update `_fire_projectile()` for 3D
   - Update `_do_melee()` for Vector3
   - Update `die()` for Vector3

4. **Convert game_manager.gd for 3D**
   - Change extends to Node3D
   - Update PLAYER_SPAWN_POSITIONS to Vector3
   - Update "Repo Owner" label to Label3D or camera-projected HUD label

5. **Update events.gd signal types**
   - Change Vector2 parameters to Vector3

**Test checkpoint:** Host a game, spawn as player. Can move with WASD, look with mouse, see the 3D arena. Multiplayer: two players can see each other.

### Phase 3B: Projectiles and Shooting (TEST: Player can shoot and see projectiles)

6. **Convert projectile.tscn and projectile.gd to 3D**
   - Area3D + SphereShape3D + MeshInstance3D
   - Vector3 direction and movement

7. **Convert projectile_enemy.tscn and projectile_enemy.gd to 3D**
   - Same pattern as player projectile

8. **Test shooting in multiplayer**
   - Both players can shoot
   - Projectiles travel in 3D
   - MultiplayerSpawner replicates projectiles to clients

**Test checkpoint:** Two players can shoot. Projectiles spawn and travel correctly. Clients see each other's projectiles.

### Phase 3C: Enemies (TEST: Wave 1 plays with Merge Conflicts)

9. **Convert enemy_base.gd to 3D**
   - CharacterBody3D, Vector3 movement, distance checks
   - 3D visual effects (hit flash via material, contact ring)

10. **Convert enemy_merge_conflict.tscn and .gd to 3D**
    - BoxMesh for body, scaled per tier
    - Split children use Vector3 offsets
    - Collision with projectiles works

11. **Update wave_manager.gd spawn positions**
    - Vector3 edge positions
    - Arena bounds constants

12. **Test wave 1-2**
    - Enemies spawn at arena edges
    - Chase players in 3D
    - Take damage from projectiles
    - Split on death (Merge Conflict)
    - Wave progresses

**Test checkpoint:** Full wave 1-2 loop works in 3D.

### Phase 3D: Remaining Enemies (TEST: All enemy types work)

13. **Convert enemy_hallucination.tscn and .gd**
    - Disguised/revealed mesh swap
    - Reveal range check in 3D

14. **Convert enemy_context_rot.tscn and .gd**
    - Ranged attack with 3D projectile
    - Range/flee distances converted

15. **Convert enemy_dependency_hell.tscn and .gd**
    - Aura distance check in 3D
    - Optional: visible aura sphere mesh

16. **Convert boss_kernel_panic.tscn and .gd**
    - Large 3D model
    - Lunge in 3D (Vector3 direction)
    - Projectile spread with Y-axis rotation
    - Shield as 3D mesh
    - Health bar on HUD

**Test checkpoint:** All enemy types spawn and behave correctly. Boss fight works.

### Phase 3E: Abilities and Turret (TEST: Both roles fully functional)

17. **Convert turret.tscn and turret.gd**
    - StaticBody3D, 3D model, targeting in 3D

18. **Update ability_weak_point_scan.gd**
    - Vector3 parameters, 3D distance check

19. **Update ability_deploy_turret.gd**
    - Vector3 placement position

20. **Update visual RPCs in player.gd**
    - Replace all ColorRect-based visuals with 3D meshes/particles
    - Melee visual, overdrive glow, healing flash, scan zone

21. **Update revive_system.gd**
    - Vector3 distance check
    - Revive bar rendering (HUD projection or billboard)

**Test checkpoint:** Both Striker and Engineer roles work. Abilities activate with correct 3D visuals. Turrets deploy and fire. Revive system works.

### Phase 3F: Polish and Full Integration (TEST: Complete game loop)

22. **Lighting and materials**
    - Neon-themed materials for arena, enemies, player
    - Post-processing (glow, fog, ambient occlusion)

23. **Sound integration**
    - Existing SoundManager calls should work (2D AudioStreamPlayer is fine for now)
    - Optional: convert to AudioStreamPlayer3D for positional audio

24. **Full multiplayer integration test**
    - 2-4 players
    - 5+ waves with all enemy types
    - Both roles (Striker + Engineer)
    - Boss fight
    - Revive scenario
    - Host migration
    - Return to lobby

25. **Controls label and HUD cleanup**
    - Update controls text for FPS
    - Verify all HUD elements read correctly

---

## 12. Constants Migration Reference

### Pixel-to-Unit Conversion

**Factor: 1 unit = 20 pixels**

| Constant | 2D (pixels) | 3D (units) | Used In |
|----------|-------------|------------|---------|
| `RUN_SPEED` | 170 | 8.5 | player.gd |
| `SPRINT_SPEED` | 300 | 15.0 | player.gd |
| `MELEE_RANGE` | 60 | 3.0 | player.gd |
| `CONTACT_DAMAGE_COOLDOWN` | N/A | N/A | enemy_base.gd (time, not distance) |
| `CONTACT_RANGE` (base enemy) | 50 | 2.5 | enemy_base.gd |
| `CONTACT_RANGE` (boss) | 80 | 4.0 | enemy_kernel_panic.gd |
| `SCAN_RADIUS` | 300 | 15.0 | ability_weak_point_scan.gd |
| `TURRET_RANGE` | 250 | 12.5 | turret.gd |
| `TURRET_DEPLOY_OFFSET` | 60 | 3.0 | ability_deploy_turret.gd |
| `REVIVE_RANGE` | 80 | 4.0 | revive_system.gd |
| `HALL_REVEAL_RANGE` | 80 | 4.0 | enemy_hallucination.gd |
| `CR_FIRE_RANGE` | 350 | 17.5 | enemy_context_rot.gd |
| `CR_FLEE_RANGE` | 100 | 5.0 | enemy_context_rot.gd |
| `DH_AURA_RADIUS` | 200 | 10.0 | enemy_dependency_hell.gd |
| `LUNGE_SPEED[0]` | 250 | 12.5 | enemy_kernel_panic.gd |
| `LUNGE_SPEED[1]` | 280 | 14.0 | enemy_kernel_panic.gd |
| `LUNGE_SPEED[2]` | 300 | 15.0 | enemy_kernel_panic.gd |
| `MC_T0_SPEED` | 50 | 2.5 | enemy_merge_conflict.gd |
| `MC_T1_SPEED` | 65 | 3.25 | enemy_merge_conflict.gd |
| `MC_T2_SPEED` | 80 | 4.0 | enemy_merge_conflict.gd |
| `HALL_CHASE_SPEED` | 70 | 3.5 | enemy_hallucination.gd |
| `CR_SPEED` | 40 | 2.0 | enemy_context_rot.gd |
| `DH_SPEED` | 30 | 1.5 | enemy_dependency_hell.gd |
| `BOSS_SPEED` | 35 | 1.75 | enemy_kernel_panic.gd |
| `PROJ_SPEED` (player) | 400 | 20.0 | projectile.gd |
| `CR_PROJ_SPEED` | 200 | 10.0 | enemy_context_rot.gd |
| `BOSS_PROJ_SPEED` | 180 | 9.0 | enemy_kernel_panic.gd |
| `ARENA_LEFT` | 32 | -29.0 | wave_manager.gd |
| `ARENA_RIGHT` | 1168 | 29.0 | wave_manager.gd |
| `ARENA_TOP` | 32 | -14.0 | wave_manager.gd |
| `ARENA_BOTTOM` | 568 | 14.0 | wave_manager.gd |

### Arena Mapping

2D arena: (0, 0) to (1200, 600) with 32px wall insets -> playable (32, 32) to (1168, 568)

3D arena: Center at origin. Floor: 60 x 30 units. Playable: (-29, 0, -14) to (29, 0, 14)

Conversion: `3D_x = (2D_x - 600) / 20`, `3D_z = (2D_y - 300) / 20`

### Spawn Position Conversion

2D player spawns:
```
(500, 300), (700, 300), (500, 400), (700, 400)
```

3D player spawns (centered at origin):
```
(-5, 0, 0), (5, 0, 0), (-5, 0, 5), (5, 0, 5)
```

---

## Appendix A: New Input Actions

| Action | Key | Controller | Notes |
|--------|-----|------------|-------|
| `look_up` | Mouse Y- | R Stick Y- | Camera pitch up (handled in _input) |
| `look_down` | Mouse Y+ | R Stick Y+ | Camera pitch down |
| `look_left` | Mouse X- | R Stick X- | Camera yaw left |
| `look_right` | Mouse X+ | R Stick X+ | Camera yaw right |
| `toggle_mouse` | ESC | N/A | Release/capture mouse |

Mouse look is handled via `InputEventMouseMotion` in `_input()`, not through the input map. The controller right stick already works via `Input.get_joy_axis()`. The `toggle_mouse` action is new for releasing/recapturing the mouse.

## Appendix B: File Change Summary

### Files That Change (in-place)

| File | Change Magnitude |
|------|-----------------|
| `scenes/game.tscn` | **Major** — complete rebuild as 3D scene |
| `scenes/player.tscn` | **Major** — rebuild with 3D nodes |
| `scenes/enemies/enemy_merge_conflict.tscn` | **Major** — rebuild with 3D nodes |
| `scenes/enemies/enemy_hallucination.tscn` | **Major** — rebuild with 3D nodes |
| `scenes/enemies/enemy_context_rot.tscn` | **Major** — rebuild with 3D nodes |
| `scenes/enemies/enemy_dependency_hell.tscn` | **Major** — rebuild with 3D nodes |
| `scenes/enemies/boss_kernel_panic.tscn` | **Major** — rebuild with 3D nodes |
| `scenes/projectile.tscn` | **Major** — rebuild with 3D nodes |
| `scenes/projectile_enemy.tscn` | **Major** — rebuild with 3D nodes |
| `scenes/turret.tscn` | **Major** — rebuild with 3D nodes |
| `scripts/player.gd` | **Major** — FPS camera, Vector3, mouse look |
| `scripts/game_manager.gd` | **Moderate** — Node3D, Vector3 spawns, label |
| `scripts/enemies/enemy_base.gd` | **Moderate** — CharacterBody3D, Vector3, visuals |
| `scripts/enemies/enemy_merge_conflict.gd` | **Moderate** — Vector3, mesh scaling |
| `scripts/enemies/enemy_hallucination.gd` | **Moderate** — Vector3, mesh swap |
| `scripts/enemies/enemy_context_rot.gd` | **Moderate** — Vector3, ranges |
| `scripts/enemies/enemy_dependency_hell.gd` | **Minor** — Vector3 distances |
| `scripts/enemies/enemy_kernel_panic.gd` | **Moderate** — Vector3, shield mesh, projectile spread |
| `scripts/projectile.gd` | **Moderate** — Area3D, Vector3 |
| `scripts/entities/projectile_enemy.gd` | **Moderate** — Area3D, Vector3 |
| `scripts/entities/turret.gd` | **Moderate** — StaticBody3D, Vector3 |
| `scripts/wave_manager.gd` | **Minor** — Vector3 spawn positions |
| `scripts/abilities/ability_weak_point_scan.gd` | **Minor** — Vector3 parameters |
| `scripts/abilities/ability_deploy_turret.gd` | **Minor** — Vector3 placement |
| `scripts/revive_system.gd` | **Minor** — Vector3 distance |
| `scripts/autoloads/events.gd` | **Minor** — Vector2 -> Vector3 in signal types |

### Files That Do NOT Change

| File | Reason |
|------|--------|
| `scripts/ability_manager.gd` | Pure logic, no spatial code |
| `scripts/abilities/super_overdrive.gd` | Pure logic, calls player RPCs |
| `scripts/abilities/super_healing_pulse.gd` | Pure logic, iterates players |
| `scripts/autoloads/network_manager.gd` | Pure networking |
| `scripts/autoloads/sound_manager.gd` | Audio, dimension-agnostic |
| `scripts/lobby.gd` | 2D UI, already has 3D preview |
| `scripts/lobby_stage_3d.gd` | Already 3D |
| `scenes/lobby.tscn` | 2D UI scene |
| `scenes/lobby_stage_3d.tscn` | Already 3D |

### New Files (if any)

No new script files should be needed. The conversion is in-place. All logic stays in existing scripts.

Optional new files:
- `assets/materials/` — 3D materials for arena, enemies, player (StandardMaterial3D resources)
- `assets/meshes/` — If using imported .glb models instead of primitive meshes

---

## Appendix C: Quick Conversion Cheat Sheet

For the engineer implementing this, here are the most common patterns:

```gdscript
# Position conversion
# Before: var pos = Vector2(x, y)
# After:  var pos = Vector3(x, 0, z)  # Y is always 0 for ground

# Direction on ground plane
# Before: var dir = (target.global_position - global_position).normalized()
# After:  var diff = target.global_position - global_position
#         diff.y = 0
#         var dir = diff.normalized()

# Angle to rotation
# Before: sprite.rotation = direction.angle()
# After:  look_at(global_position + direction, Vector3.UP)
#    or:  rotation.y = atan2(direction.x, direction.z)
#    NOTE: atan2(x, z) not atan2(z, x) because Godot's forward is -Z

# Rotated direction (for projectile spread)
# Before: var dir = base_dir.rotated(angle)
# After:  var dir = base_dir.rotated(Vector3.UP, angle)

# Velocity
# Before: velocity = dir * speed  (Vector2)
# After:  velocity = dir * speed  (Vector3, same API)

# Distance check
# Before: pos1.distance_to(pos2)
# After:  pos1.distance_to(pos2)  # Works in 3D, measures full 3D distance
#    Or for horizontal only: Vector2(pos1.x, pos1.z).distance_to(Vector2(pos2.x, pos2.z))

# Dot product (melee cone, shield facing)
# Before: dir1.dot(dir2)
# After:  dir1.dot(dir2)  # Same API in Vector3

# Collision shape
# Before: RectangleShape2D with size = Vector2(w, h)
# After:  BoxShape3D with size = Vector3(w/20, height, h/20)
#    Or:  CapsuleShape3D with radius and height

# move_and_slide()
# Same API in both 2D and 3D. Just call it.

# Camera (2D -> 3D)
# Before: $Camera2D.make_current()
# After:  $CameraMount/Camera3D.make_current()
```
