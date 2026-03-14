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

## Session log — 14 March 2026

### What got done this session

1. **Full narrative design document written** (`NARRATIVE.md`)
   - Four playable characters: Dai (Welsh), Terry (cockney), Rab (Scottish), Siobhan (Belfast)
   - Six levels from pub Round the Clock to World Championship best-of-three 501
   - Meta-game systems: weight, drinking, jewellery, manager choice, inflatables, betting syndicate, bribe
   - Nerve-O-Metre: visible HUD bar, affects dart scatter, reduced by drinking
   - In-game drinking between every visit (3 darts) — half pint or full pint tap choice
   - Progressive blur effect up to double vision at extreme drinking levels
   - Three death mechanics: liver failure, heart attack, gang hit — all from player choices
   - Hidden health meters — only visible by paying to visit the doctor + buying medicine
   - Three-strike loss mechanic (lose same level 3x = career over)
   - Seven opponents with escalating difficulty, each a darts stereotype
   - Three ending types based on hidden reputation score (clean/dirty/mixed)

2. **Character select screen added**
   - "Pick your player" screen with 2x2 grid
   - Dai is selectable with his profile image
   - Terry, Rab, Siobhan shown as locked "Coming Soon" cards with $, $$, $$$ price hints
   - Flows into the existing game mode menu

3. **Throw system camera fix** (major bug)
   - Darts were landing in wrong areas when camera was zoomed/panned
   - Root cause: `_screen_to_board()` used fixed screen-to-board mapping, ignoring camera position
   - Fix: replaced with camera ray projection — cast ray from camera through mapped screen position to board plane
   - Dart spawn position now relative to camera instead of hardcoded at centre
   - Tested and confirmed working on both desktop and mobile

4. **Web export and GitHub Pages**
   - Game exported for web and deployed to GitHub Pages
   - Live at: https://richardbowman123.github.io/dart-attack/
   - Repo is public (needed for free GitHub Pages)
   - `copy_to_docs.ps1` script automates the export-to-docs rename process

5. **Character art started**
   - Three images of Dai "The Dragon" Davies at age 16 (profile, full body, in situ)
   - Generated externally, saved in project root
   - Written detailed image briefs for Terry, Rab, and Siobhan to match Dai's style
   - Plan: generate all four at young age, then progression stages through career

### Key files added/changed
| File | What |
|------|------|
| `NARRATIVE.md` | Full game narrative design document |
| `scripts/character_select.gd` | Character select screen (new) |
| `scenes/character_select.tscn` | Character select scene (new) |
| `scripts/throw_system.gd` | Camera ray projection fix |
| `scripts/match_manager.gd` | Passes camera to throw system |
| `project.godot` | Main scene changed to character_select |
| `copy_to_docs.ps1` | Web export automation script |
| `docs/` | Web export for GitHub Pages |

### What comes next

1. **Character art** — generate Terry, Rab, Siobhan images to match Dai's style, then age progression stages for all four
2. **Integrate character images** — wire remaining character portraits into the select screen as they're created
3. **AI opponent system** — opponents with configurable accuracy, finishing ability, pressure response
4. **Nerve-O-Metre** — visible bar on HUD during matches, affected by match events and drinking
5. **In-game drinking** — "have a drink?" prompt between visits
6. **Vision blur shader** — progressive blur effect from drinking, up to double vision
7. **Career mode structure** — level progression, between-match menus, unlock flow
8. **Round the Clock camera** — auto-focus on the next target segment (the `focus_segment` function exists but isn't wired up yet)

### Deployment workflow
1. Make changes in Godot
2. Export: Project > Export > Web
3. In Claude Code: run `copy_to_docs.ps1` (copies and renames files)
4. Claude fixes `index.html` (replaces "Dart Attack" refs with "index", keeps title)
5. Upload to GitHub
6. Wait 1-2 mins for GitHub Pages rebuild

## Design notes — throw quality system (future, Phase 3)

Discussed 14 March 2026. The idea: a fast, short, stabbing swipe should produce a flatter trajectory and tighter accuracy, like a confident player. A light, slow flick should produce a loopy arc with more wobble, like a nervous beginner.

Three components:
1. **Trajectory feel** — already partially works (fast swipe = less time in air = less gravity drop), but visually both feel the same. Need to sell the difference with dart behaviour and possibly camera.
2. **Throw quality modifier on scatter** — NOT built yet. Currently scatter is only based on dart tier. Adding a speed-based scatter multiplier (fast confident throw = tighter grouping, weak flick = wider scatter) is straightforward.
3. **In-air wobble** — NOT built yet. A slow dart should visually oscillate/drift during flight. Fast dart flies dead straight. Just a rotation oscillation in `_physics_process`, scaled inversely to speed.

**When to build:** Phase 3, alongside the Nerve-O-Metre. These are two halves of the same accuracy model:
- Nerve-O-Metre = game-controlled difficulty (nerves add scatter, drinking/crowd reduce it)
- Throw quality = player-controlled skill (your actual swipe technique affects accuracy)

They multiply together: calm player + clean throw = laser accurate. Nervous player + panicky flick = all over the shop.

The in-air wobble visual could come earlier (Phase 2 polish) since it's purely cosmetic.

## Technical notes
- 720x1280 portrait viewport, mobile renderer
- Touch emulated from mouse for PC testing
- Dart uses RigidBody3D with continuous collision detection
- Board meshes use indexed triangles with normals (not triangle strips — those don't render on mobile renderer)
- OneDrive-safe naming throughout
