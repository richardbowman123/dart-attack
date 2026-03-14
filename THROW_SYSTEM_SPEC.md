# Dart Attack — Throw System Specification

## Purpose

This document is a technical specification for how the throw/aim/landing system works in Dart Attack. It was written after multiple failed implementation attempts so that a fresh session can implement it correctly without repeating mistakes.

**Read this entire document before writing any code.**

---

## 1. The Game Layout

- **Viewport:** 720 x 1280 pixels, portrait orientation (mobile)
- **Board view (top 45%):** Screen y=0 to y=576. The 3D dartboard is rendered here. The player can pinch-to-zoom and pan in this area.
- **Throw zone (bottom 55%):** Screen y=576 to y=1280. The player swipes here to throw darts. Touches that START above y=576 are rejected (to prevent accidental throws during zoom/pan gestures). However, the touch END (release) can be anywhere — the finger naturally travels upward during a swipe.
- **The board extends into the throw zone visually.** The board centre is at roughly screen y=640 (just below the throw zone boundary). The board is small on screen — it spans roughly y=473 to y=807 at default zoom. So the BOTTOM HALF of the board is visually in the throw zone.

### Camera

- **Camera3D** with FOV = 50 degrees
- Default position: (0, 0, 10), looking at (0, 0, 0)
- Zoomed position: (pan_x, pan_y, 5), looking at (pan_x, pan_y, 0)
- Always looks straight down the Z axis toward the board plane at z=0
- Pan range: ±2.5 units in X and Y

### Board

- Circular dartboard at z=0, radius = 2.0 board units (BoardData.BOARD_RADIUS)
- 20 segments arranged per standard BDO dartboard (SEGMENT_ORDER in board_data.gd)
- Segment 20 is at 12 o'clock (angle PI/2 in standard maths coordinates)
- Segments go clockwise (decreasing angle)

---

## 2. How Throwing Works — The User's Experience

The player throws darts by swiping upward in the throw zone:

1. **Touch down** in the throw zone (below y=576)
2. **Swipe upward** toward the board
3. **Release** (lift finger) — WHERE they release is the primary aim
4. The dart flies to the board and lands

### The Two Things That Control Where the Dart Lands

**PRIMARY: Release position.** Where the finger lifts off the screen determines where the dart aims. This is the dominant factor — about 90% of the aim.

**SECONDARY: Speed/distance nudge.** The swipe speed and distance add a small vertical adjustment:
- **Medium speed, medium distance** → dart lands EXACTLY at the release point (zero nudge)
- **Faster or longer swipe** → dart lands slightly HIGHER than the release point
- **Slower or shorter swipe** → dart lands slightly LOWER than the release point

The nudge is small and predictable. At maximum speed the nudge might shift the dart by half a segment width upward. At minimum speed it shifts slightly downward. The nudge rewards consistent, steady throwing.

### The Golden Rule

**At medium pace, the dart lands exactly where you let go.** Everything else flows from this.

---

## 3. The Screen-to-Board Mapping

### The Correct Solution: Direct Ray Projection

The dart lands wherever the player's finger points on the board. Like looking through a window — a straight line from the camera through the release point to the board plane at z=0.

```gdscript
func _screen_to_board(screen_pos: Vector2) -> Vector2:
    var origin := _camera.project_ray_origin(screen_pos)
    var dir := _camera.project_ray_normal(screen_pos)
    if absf(dir.z) < 0.001:
        return Vector2.ZERO
    var t := -origin.z / dir.z
    return Vector2(origin.x + dir.x * t, origin.y + dir.y * t)
```

### Why This Works

- **Matches the player's mental model:** The player sees the board through the screen. They point at what they see. The dart lands there. No translation layer, no mapping formula.
- **Naturally zoom-aware:** Zooming in makes the board bigger on screen, giving the player a larger target area and more precision.
- **Naturally pan-aware:** The camera's transform handles everything.
- **Touch start is in the throw zone, release can be anywhere:** The player starts their swipe in the throw zone (below y=576) and swipes upward. Their finger naturally ends near or on the board. The release position is what matters.

### What NOT To Do

These approaches were tried and failed:

1. **Camera-relative linear mapping (throw zone centre = board centre)** — Maps the centre of the throw zone (y=928) to the camera look-at point. Since y=928 is far below the board on screen, ANY release above that midpoint maps above the board. Darts land way too high. The mapping doesn't match what the player sees.
2. **Mapping throw zone to board view (top 45%), then ray projecting** — Compresses the throw zone into the board view area, then ray-projects. Darts always land too high because the mapping pushes everything toward the upper screen area.
3. **Speed nudge as the primary aim mechanism** — Speed should only add a small secondary vertical adjustment, not determine the aim.
4. **Gravity on darts + compensation math** — Amplifies errors at different zoom levels. Fixed by setting gravity_scale = 0 (straight-line flight).
5. **Offset spawn positions with X/Y velocity** — Damping causes drift. Fixed by spawning at target XY with pure Z velocity.

---

## 4. The Speed/Distance Nudge

After computing the base aim from the release position, apply a small vertical nudge based on swipe speed:

```gdscript
const MEDIUM_SWIPE_SPEED := 750.0   # Reference speed where nudge = 0
const SPEED_NUDGE_MAX := 0.3        # Max nudge in board units (about half a segment width)

# In _on_touch_end, after computing aim:
var speed_ratio := (swipe_speed - MEDIUM_SWIPE_SPEED) / MEDIUM_SWIPE_SPEED
var nudge := clampf(speed_ratio, -1.0, 1.0) * SPEED_NUDGE_MAX
aim.y += nudge
```

This means:
- At 750 px/sec → nudge = 0 (dart lands at release point)
- At 1500 px/sec → nudge = +0.3 (dart lands 0.3 units higher)
- At 375 px/sec → nudge = -0.15 (dart lands 0.15 units lower)
- At 300 px/sec (minimum) → nudge = -0.18 (dart lands 0.18 units lower)

The nudge is clamped so it can never dominate the aim. Release position is always the primary factor.

---

## 5. Dart Spawning and Flight

The dart spawns at the aimed board position and flies straight toward the board:

```gdscript
func _spawn_and_fire(target: Vector2, throw_speed: float, tier: int, character) -> void:
    var dart := Dart.create(tier, character)
    dart.visual_scale = 2.0

    var cam_pos := _camera.global_position
    dart.position = Vector3(target.x, target.y, cam_pos.z * 0.55)

    _darts_container.add_child(dart)

    dart.gravity_scale = 0.0
    dart.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
    dart.linear_damp = 0.0
    dart.linear_velocity = Vector3(0.0, 0.0, -throw_speed)

    dart_thrown.emit(dart)
```

Key points:
- **Spawn at (target.x, target.y)** — the dart starts at the aimed position, not at the camera or at a separate spawn point. This eliminates any X/Y drift during flight.
- **Zero X/Y velocity** — the dart flies straight along -Z only. No horizontal or vertical movement.
- **No gravity** — `gravity_scale = 0.0` ensures straight-line flight. No parabolic trajectory, no gravity compensation needed.
- **No damping** — `linear_damp = 0.0` with `DAMP_MODE_REPLACE` prevents the physics engine from slowing the dart.
- **Add to tree FIRST, then set physics** — the dart's `_ready()` may set default physics values, so override them AFTER `add_child`.

### Why This Design

Previous attempts used offset spawn positions and non-zero X/Y velocities, requiring the dart to travel horizontally during flight. This introduced drift from damping, gravity interactions, and spawn-position-dependent errors. Spawning at the target with pure Z velocity eliminates all of these issues.

---

## 6. Tutorial Guide Dots

The tutorial shows the player where to aim and how to swipe.

### Elements

1. **Yellow crosshair** — on the board, at the target segment's centre. Visual indicator only (decorative).
2. **Red dot** — on the board, at the target position. Means "STOP" — this is where you're aiming, where the dart should land.
3. **Green dot** — in the throw zone, below the red dot. Means "START" — begin your swipe here.
4. **Arrow** — from green up toward red, showing swipe direction.
5. **Instruction text** — with a dark background (black, 80% opacity) so it's readable over the board.

### Positioning the Guide Dots

**Red dot:** Use `_camera.unproject_position(Vector3(target.x, target.y, 0))` to project the board target onto the screen. The red dot sits AT the target's visual position on the board. With direct ray projection, releasing here sends the dart straight to the target.

**Green dot:** SWIPE_LENGTH pixels (150) below the red dot in screen space. Clamped to stay in the throw zone (y >= 576) since touches must START in the throw zone.

```gdscript
_target_screen_pos = _camera.unproject_position(Vector3(_target_board_pos.x, _target_board_pos.y, 0.0))
_red_dot_pos = _target_screen_pos  # Release here to hit the target
_green_dot_pos = Vector2(_red_dot_pos.x, _red_dot_pos.y + SWIPE_LENGTH)
# Clamp green to stay in the throw zone
```

### Why This Works With Ray Projection

The red dot sits on the board at the target's visual position. The user swipes from green (in the throw zone) upward toward red (on the board). They release when their finger reaches the red dot. Since `_screen_to_board` uses direct ray projection, releasing at the red dot's screen position maps directly to the target's board position — it's the same straight line from camera through finger to board.

This is intuitive: point at what you want to hit, and the dart goes there.

---

## 7. Known Issues to Investigate

### Segment Scoring Misalignment

There is a reported bug where a dart visually in segment 11 scores as 8 (adjacent segment). Possible causes:

1. **Boundary precision:** The dart may be very close to the 8/11 boundary. The `int()` truncation in `get_score()` could push borderline hits into the wrong segment.

2. **Visual scale mismatch:** The dart has `visual_scale = 2.0` which scales the mesh but not the physics body. The visual dart tip may appear at a slightly different position than the physics scoring position.

3. **Barrel length offset:** Hit detection uses `tip_local = Vector3(0, 0, -barrel_length)` which offsets the scoring position along Z (into the board), not in X/Y. This should not affect segment scoring but should be verified.

4. **Color confusion:** Segment 8 (even index) has BLACK singles and RED scoring rings. Segment 11 (odd index) has CREAM singles and GREEN scoring rings. A dart in the BLACK area between 8 and 11 is in segment 8, even if the "11" number label appears nearby.

**To investigate:** Add temporary debug output showing the dart's actual (x, y) position and the computed angle/segment_index when scoring. Compare with the visual position.

---

## 8. File Reference

| File | Purpose |
|------|---------|
| `scripts/throw_system.gd` | Touch handling, screen-to-board mapping, dart spawning |
| `scripts/tutorial_overlay.gd` | Tutorial UI, guide dots, feedback text |
| `scripts/board_data.gd` | Board geometry, scoring math, segment angles |
| `scripts/dartboard.gd` | Visual board mesh generation |
| `scripts/dart.gd` | Dart physics, hit detection, scoring position |
| `scripts/camera_rig.gd` | Camera zoom, pan, position |
| `scripts/match_manager.gd` | Game flow, connects throw system to scoring |

---

## 9. Implementation Checklist

When implementing from this spec:

- [x] Replace `_screen_to_board()` with direct ray projection from Section 3
- [x] Add the speed nudge from Section 4 (MEDIUM_SWIPE_SPEED, SPEED_NUDGE_MAX constants)
- [x] Keep dart spawning as described in Section 5 (spawn at target XY, fly along -Z, no gravity)
- [x] Position tutorial red dot on the board using `unproject_position`
- [x] Position tutorial green dot below red in the throw zone
- [x] Ensure instruction text has dark background
- [ ] Test at default zoom AND full zoom — results should be consistent
- [ ] Test at board centre, top, bottom, left, and right — results should be consistent
- [ ] Test at medium speed — dart should land at the release point
- [ ] Test at fast speed — dart should land slightly above the release point
- [ ] Test at slow speed — dart should land slightly below the release point
- [ ] Investigate the segment scoring bug (Section 7)

---

## 10. Design Philosophy

This is being built as "easy mode" first. The base mechanic should feel accurate and predictable. Later difficulty layers will be added through:
- **Nerves** — increased scatter when under pressure
- **Alcohol** — wobble/drift in the aiming
- **Confidence** — affects consistency
- **Dart quality** — better darts have less scatter (DartData.get_scatter_mult)

The throw system itself should be rock-solid and simple. Complexity comes from the game systems on top, not from the throw physics.
