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
9. **Advanced tutorial (post-Level 1)** — after beating Big Kev at Round the Clock, trigger a "How to Hit Doubles and Trebles" tutorial. Level 2 is 101 countdown where doubles are essential for checkout, so the player needs to understand them before they get there. Can reuse the basic tutorial framework with different targets and instructions

### Deployment workflow
1. Make changes in Godot
2. Export: Project > Export > Web
3. In Claude Code: run `copy_to_docs.ps1` (copies and renames files)
4. Claude fixes `index.html` (replaces "Dart Attack" refs with "index", keeps title)
5. Upload to GitHub
6. Wait 1-2 mins for GitHub Pages rebuild

## Session log — 15 March 2026

### What got done this session

1. **Companion dialogue system built** (3 new files, no existing files modified)
   - `scripts/companion_data.gd` — all dialogue content in one data file, designed so new exchanges can be added by editing text only with zero code changes
   - `scripts/companion_panel.gd` — slide-up UI panel with typewriter effect, broadcast mode (tap to continue) and interactive mode (two response buttons)
   - `scripts/companion_manager.gd` — orchestrator that selects dialogue, checks conditions, handles consequences, avoids repetition
   - 6 companion stages: Barman (dry), Mate (enthusiastic), The Lads (chaotic), Coach (tactical), Manager (money-focused), Full Team with Medic
   - 6 interactive exchanges: barman rules check, barman consolation drink, friend scouting report, coach checkout tips, manager sponsorship, medic breathalyser
   - Broadcast dialogue for all stages across all trigger types (pre-match, post-win, post-loss, between rounds, drink offers, checkout hints)
   - Anger-aware dialogue variants for high-anger states
   - Checkout route lookup table (26 common finishes) with formatted hint delivery
   - Post-match debrief system: win/loss comments + training directives
   - Follow-up sequences for multi-part dialogue (scouting info, checkout coaching)
   - Dynamic reply resolution (breathalyser checks drinks level at runtime)

### Key files added
| File | What |
|------|------|
| `scripts/companion_data.gd` | All dialogue data — broadcast, interactive, checkout hints, debrief (new) |
| `scripts/companion_panel.gd` | Slide-up UI panel with typewriter effect, two dialogue modes (new) |
| `scripts/companion_manager.gd` | Dialogue orchestrator — selection, conditions, consequences (new) |

### Status: BUILT BUT NOT WIRED IN
These files are complete and ready but **not integrated into the game yet**. Nothing calls them. To activate:
1. Add `CompanionManager` as an autoload in `project.godot`
2. Call `CompanionManager.request_dialogue()` from match_manager at appropriate trigger points
3. Connect `CompanionManager.dialogue_finished` signal to resume game flow
4. Fill in TODO stubs in `_handle_consequence()` when DrinkManager and PlayerStats exist

Wire this in when career mode progression and between-match screens are built.

### What comes next (unchanged from previous session)

1. **Character art** — generate Terry, Rab, Siobhan images to match Dai's style, then age progression stages for all four
2. **Integrate character images** — wire remaining character portraits into the select screen as they're created
3. **AI opponent system** — opponents with configurable accuracy, finishing ability, pressure response
4. **Nerve-O-Metre** — visible bar on HUD during matches, affected by match events and drinking
5. **In-game drinking** — "have a drink?" prompt between visits
6. **Vision blur shader** — progressive blur effect from drinking, up to double vision
7. **Career mode structure** — level progression, between-match menus, unlock flow
8. **Round the Clock camera** — auto-focus on the next target segment (the `focus_segment` function exists but isn't wired up yet)
9. **Advanced tutorial (post-Level 1)** — after beating Big Kev at Round the Clock, trigger a "How to Hit Doubles and Trebles" tutorial
10. **Wire companion dialogue** — integrate the companion system once career mode flow exists

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

## Design notes — progressive zoom (future)

Discussed 14 March 2026. The idea: better players can zoom in further than beginners. Currently zoom has a fixed max level. A progressive system would let the player zoom closer to the board as they improve — giving genuine gameplay advantage from progression, not just cosmetic upgrades.

Potential factors that could increase max zoom:
- **Dart quality** — better darts = steadier hand = can zoom more
- **Player heft** — heavier player is more planted, steadier
- **Cumulative experience** — total darts thrown, matches won
- **Combined stat** — a weighted sum of all the above

**Why it's interesting:** zooming in genuinely helps accuracy (the throw target is larger on screen), so unlocking more zoom is a real power progression, not just visual. It rewards investment in the career.

**Known risk:** physics and throw calculations use camera ray projection. Extreme zoom could cause issues with dart spawn position, trajectory angles, or collision detection. Will need testing to find the sweet spot for max zoom at each tier. The throw system already handles zoom correctly (ray projection from camera), so moderate increases should work fine — it's extreme close-ups that might feel weird.

**When to build:** after career mode progression is working, so there's a natural place to gate the zoom levels.

## Outstanding — 20 March 2026

1. **Fight scene** — Need to design and build the fight mechanic. Think about what happens when anger hits 100. Who is the unknown caller? Will we lose the fourth leg?

2. **Over-celebrating** — After L3 (where you learn to celebrate), L4 should have a consequence for celebrating too hard. Getting in a fight or getting knocked out. Steve already squares up at L3 — this should escalate.

3. **Menu usability pass** — Some menus are pushed over to the right. The "take it easy, mate" drunk warning is popping up in places it shouldn't. Need a thorough check across all screens.

4. **Outstanding images** — A couple of player character images still need putting in. All exhibition match opponent images need adding.

5. **Money system** — Make sure you actually spend money and can't go overdrawn. Money display should be consistent throughout: visible when playing the match, but especially visible when you're actually spending money. Currently feels backwards (shows during play, missing during spending).

6. **In-match drinking** — Need the ability to drink more during the game itself, not just from pre-drinking. Player should be able to get too drunk through in-match drinking as well. The round offer system exists but needs checking that it actually accumulates properly and can push you into heavy/hammered territory.

7. **Unknown caller follow-up** — When the unknown caller rings, it doesn't lead to a conversation afterwards. Need a card after the call that prompts you to actually throw/lose the leg. The call should flow into a decision, not just end.

8. **Mates card still too late** — The mates card was moved earlier (from after dart shop to after food) but Richard feels it still needs to come even earlier in the L3 flow. Review positioning.

9. **Team introduction** — When the full team is hired, we need to properly introduce them. Each person in the team should have a named role. Not just "you've got a team now" — give each member a purpose. Also: the team card currently says "the coach speaks first" but the coach isn't part of the management team — should be "the manager speaks first". Some unknown metric is displayed that makes no sense — replace with a breathalyser reading (fits the drinking theme).

10. **Doctor description wrong** — The doctor card currently describes a "tired-looking man" which doesn't match the image. Needs updating to match the actual doctor character. Smooth over the whole doctor introduction.

11. **Skip dart shop when maxed out** — Once you own Premium Tungsten (top tier), stop showing the dart shop card between levels. Nothing left to buy.

12. **End credits** — After winning the final, show what happened to each character. Every opponent, companion, and key figure gets a "where are they now" line. The £50k buys the parents a house. Full closing credits sequence.

13. **Vinnie naming — confirmed** — Full name: Vinnie "The Gold" Gold. "The Gold" in title case. Fix across all files (opponent_data, match_results, image references).

14. **Victory image full width** — The winning/celebration image on the final card should be full width of the screen, not constrained to portrait size.

15. **Fifth hustle star** — Player needs to be awarded the 5th hustle star to complete the full set. Currently missing from the final win flow.

16. **Pint = 4 units, not 1** — Player sobers up faster than they can drink. A pint should count as 4 units (not 1 or 2). At 4 units per drink every 3 visits, the player progressively gets drunker through a match, which is what we want.

17. **Experienced opponents — nerves display** — Older, more experienced opponents shouldn't display as being too nervous. They've been here and done it all before. Their actual play quality stays the same (AI stats don't affect play), but the displayed stats should make narrative sense — a seasoned pro doesn't get nervous.

18. **Coach checkout advice** — The coach promises to help with checkouts but never does. Fix: first time you come to the oche after recruiting the coach, he gives general advice. NOT specific routes like "triple 20, triple 19, double 16" — more like "You can check out here. Just try to get the score as low as possible and then work out which double you need." Deliberately basic advice, but he's being true to his word. One or two lines, not annoying.

19. **180 visual fanfare** — Currently anticlimactic. Use the current 180 graphic for any score 140+. For actual 180: bigger celebration — number pops out of the screen, visual glint/glisten from white to gold sweeping left to right. Not razzmatazz, but something that marks it as special.

20. **Bounce out vs Miss** — When a dart hits the wire or another dart, the in-game popup should say "BOUNCE OUT" not "MISS". The post-visit summary still shows "Miss" (that's fine). Currently both say "Miss" which is confusing — player needs to know they hit the wire, not that they missed.

21. **Post-visit summary miss display** — Richard gave feedback yesterday about how misses display in the visit summary. Check this is working correctly.

## Technical notes
- 720x1280 portrait viewport, mobile renderer
- Touch emulated from mouse for PC testing
- Dart uses RigidBody3D with continuous collision detection
- Board meshes use indexed triangles with normals (not triangle strips — those don't render on mobile renderer)
- OneDrive-safe naming throughout
