# Dart Attack - Development Notes

## What this is

A 3D mobile darts game built in Godot 4.6. Flick-to-throw mechanic, portrait mode, designed for mobile but testable on PC.

The ultimate game is a career mode from pub leagues to Alexandra Palace (see NARRATIVE.md for full story design). This build is the core throwing engine and practice modes.

## Current state (Phase 1 - Practice Mode)

### What works
- Full dartboard with correct proportions, colours, number sequence (20 at top)
- Flick-to-throw mechanic (touch on mobile, mouse on PC)
- Four practice modes: Round the Clock, 101, 301, 501
- Round the Clock: hit 1-20 in order then two bullseyes. Doubles skip one, trebles skip two.
- Countdown modes: proper 501 rules — bust if below zero, on 1, or finish without a double
- Score reverts to start of visit on bust
- Three dart icons at bottom showing remaining throws per visit
- Subtle HUD: small remaining score top-right, brief impact flash, visit summary panel
- Back wall catches missed darts (no more flying to infinity)
- Camera pan (WASD/arrows) and zoom (scroll wheel), R to reset view
- Dart tier system ready (brass, nickel silver, tungsten, premium tungsten)
- Escape key returns to menu

### Known issues to fix next session

1. ~~**Camera zoom only goes to board centre.**~~ **FIXED.** Camera now supports:
   - **Mobile:** Pinch to zoom in/out, two-finger drag to pan around the board
   - **PC:** Scroll wheel to zoom, right-click drag to pan, WASD/arrows still work, R to reset
   - Throw system cancels any in-progress aim if a second finger is detected (no accidental throws during pinch/zoom)

2. ~~**Dart position vs score mismatch near segment borders.**~~ **FIXED.** Root cause: scoring used the dart body centre (`global_position`) instead of the tip position. With barrel lengths of 0.22–0.28 game units, the body is displaced inward from the tip when the dart approaches at an angle — enough to push treble hits into the single ring (which is only 0.094 units wide). Fix: scoring now calculates the tip's world position using `global_transform * tip_local_offset`.

3. **Wire bounce.** The wire dividers between segments should have a slight thickness. In rare cases, a dart hitting the wire should bounce off — display "WIRE!" and count as a miss. This adds realism and tension.

## Architecture

All code-driven (no scene editor UI). Follows the same patterns as Animal Merge:
- `InputSetup` autoload for custom input actions
- `GameState` autoload for mode selection
- Pure data classes (BoardData, DartData) extend RefCounted with static methods
- State machine in MatchManager controls game flow
- ScoreHUD is a CanvasLayer with dynamic UI

### Key files
| File | Purpose |
|------|---------|
| `board_data.gd` | Dartboard geometry, score calculation, segment colours |
| `dartboard.gd` | Builds the 3D board visually (procedural meshes) |
| `dart.gd` | Dart object — RigidBody3D with tier-based visual |
| `dart_data.gd` | Dart tier definitions (brass through premium tungsten) |
| `throw_system.gd` | Swipe input, aiming reticle, dart spawning |
| `camera_rig.gd` | Camera with pan/zoom controls |
| `match_manager.gd` | Game loop — Round the Clock and countdown modes |
| `score_hud.gd` | Minimal HUD — dart icons, impact flash, visit summary |
| `menu.gd` | Mode selection screen |
| `NARRATIVE.md` | Full story/career design (from character arc session) |

## What comes next

### Phase 2: Opponent play
- AI opponent throws between your visits
- Instant summary of their throw (e.g. "T20, T20, 20 = 140")
- Adjustable skill level (scatter amount)
- Practice mode stays as-is for solo play

### Phase 3: Stats and career
- Five stats: weight, alcohol, arm hair, nerve, swagger
- Each affects throwing differently
- Between-match shop for upgrades
- See NARRATIVE.md for full detail

### Phase 4: Mobile deployment
- Export to Android (APK)
- Tune throw sensitivity for touch
- Test on actual device
- The game is mobile-first — PC testing is for development convenience

## Technical notes
- 720x1280 portrait viewport, mobile renderer
- Touch emulated from mouse for PC testing
- Dart uses RigidBody3D with continuous collision detection
- Board meshes use indexed triangles with normals (not triangle strips — those don't render on mobile renderer)
- OneDrive-safe naming throughout
