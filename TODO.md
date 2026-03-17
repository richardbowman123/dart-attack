# Dart Attack — Master TODO List

Last updated: 16 March 2026

Working through this level by level. Tick items off as they're built and tested.

---

## THE BIG CHUNKY ONES

- [ ] **Alcohol & Drinking System (full)** — Vision blur shader (sober to double vision at 7+ pints), heft-based tolerance, drinking as primary nerve-reducer, pass-out death at extreme levels, natural-feeling drink prompt between visits
- [ ] **Between-Match Screens & Shop** — The entire "between matches" layer: food shop (heft), jewellery (crowd/arm weight), dart upgrades, manager hiring, doctor/medicine (L6+), gambling/betting (L4+), new dynamics introduction screens
- [ ] **Multi-Leg Match System** — L3+ needs best-of-N (L3: 101 Bo7, L4: 301 Bo5, L5: 301 Bo7, L6: 501 Bo5[TBC], L7: 501 Bo7). Between-leg celebrations, leg tracking, set scoring, display
- [ ] **Nerves / Confidence / Stats Engine** — Four stat bars are on HUD but not wired to gameplay. Nerves, confidence, opponent anger all need to affect throws and be driven by match events
- [ ] **AI Opponent Brain (full)** — 7 opponents with escalating accuracy, finishing ability, pressure handling, personality effects (Steve talks trash, Micky slams, Philip silent, etc.)
- [ ] **Character Art & Visual Progression** — Dai done at 18. Terry, Rab, Siobhan not started. Age progression for all four. Visual updates from purchases (heft, bling, darts, tattoos)
- [ ] **Fight System (wiring)** — Car park scene built but not connected. Wire anger trigger at 100, heft+drunkenness outcome, consequences (injury, money loss, reputation)
- [ ] **Death Systems** — Liver failure, heart attack, gang hit, pass-out death. All designed, none built
- [ ] **Sponsorship Grid (L5+)** — 9-cell system, fictional brands, risk levels, deadly options, own UI needed
- [ ] **Six Endings & Reputation System** — Hidden reputation score, 3 victory endings, 3 death endings, career over ending, cutscenes, newspaper headlines

---

## SMALLER ITEMS

### Money & Economy
- [ ] **Negative balance bug** — nothing stops CareerState.money going below zero. Need "can't afford it" checks on buy-ins, drinks, and all purchases
- [ ] Buy-in gate — check player can afford entry fee before starting match
- [ ] Many prices still [TBC] in spec (pint prices L2-5, food, jewellery, darts, doctor, inflatables, team hiring)
- [ ] Wire all spending to CareerState.money and update_balance() properly

### Companion Dialogue (BUILT, not wired)
- [ ] Add CompanionManager as autoload in project.godot
- [ ] Call from match_manager at trigger points (pre-match, post-win, post-loss, between rounds, drink offers)
- [ ] Connect dialogue_finished signal to resume game flow
- [ ] Wire _handle_consequence() stubs to DrinkManager and PlayerStats
- [ ] Wire directive stats (skill boost, heft, confidence/crowd)
- [ ] Wire PlayerStats.PlayerAnger for angry dialogue variants
- [ ] Read actual DrinkManager.drinks_level (currently hardcoded placeholder of 3)

### Pre-Match Drinking Round (NEW IDEA)
- [ ] Entourage takes you out drinking before the match — cheaper than buying drinks during the game
- [ ] Drinks have unknown strength — you arrive at the oche anywhere from mildly merry to seeing double
- [ ] Sets starting state: high confidence, low nerves, but potentially blurred vision from the off
- [ ] Still buy drinks during the match as normal — this is just a cheaper pre-game option
- [ ] Tied to companion stage (barman rounds early, lads rounds later, etc.)

### Coach as Dodgy Ex-Player (NEW IDEA)
- [ ] Coach character inspired by Chubs Peterson (Happy Gilmore) — brilliant former player gone wrong
- [ ] Banned from competitive darts (match-fixing? Punching a ref? Gambling debts?)
- [ ] Can only coach, never play — gives insider knowledge but moral grey area
- [ ] Natural gateway to darker career paths (betting syndicate, bribe connections)
- [ ] Great tactical advice but questionable influence

### Celebrations (L3+)
- [ ] No celebration / The Flex / The Big Fish / Down a Pint
- [ ] Each boosts confidence, increases opponent anger
- [ ] Down a Pint costs a pint + adds drink level

### Bribe System (L3 one-time)
- [ ] Manager offers bribe before Regional final vs Steve
- [ ] Pay = easy win + reputation hit. Refuse = harder match + clean record
- [ ] Post-win trap: thank companion publicly = overheard = banned = game over

### Betting Syndicate (L4+)
- [ ] Bet on self (safe) or against self (one-time, huge risk)
- [ ] Must lose one leg deliberately if betting against
- [ ] Fail to throw = gang hit death

### Inflatable Trading (L3+)
- [ ] Buy bulk inflatables post-L3
- [ ] Sell at escalating profit (L5: 10%, L6: 2x, L7: 5x)

### Walk-On Sequences (L4+)
- [ ] Music selection from set list
- [ ] Escalating production (small crowd to full pyro)

### Level Progression Gates
- [ ] Specific unlock conditions per level (heft, dart tier, manager, entry fee)
- [ ] Three-strike system at L1-3, win-or-bust at L5+, L4 [TBC]

### Throw System Enhancements
- [ ] Throw quality modifier on scatter (speed-based)
- [ ] In-air wobble on slow darts (cosmetic)
- [ ] Random bad throw on failed swipe at higher levels
- [ ] Progressive zoom unlock tied to career progression

### Dart-on-Dart Bounce
- [ ] Darts landing on/near previous darts bounce out by tier (Brass 50%, Nickel Silver 30%, Tungsten 15%, Premium Tungsten 5%)

### HUD & Popups
- [ ] In-match coaching popups ("Confidence is dropping — have a drink")
- [ ] Confidence decay while aiming (timer exists, not wired)
- [ ] Round the Clock auto-focus camera on next target segment (focus_segment exists, not called)

### Tutorial
- [ ] Advanced tutorial after beating Big Kev (doubles and trebles for L2's 101 mode)

### Opponent Data
- [ ] Full personality data for all 7 opponents (accuracy, finishing, pressure, walk-on music)

### Known Bug
- [ ] Segment scoring: dart visually in 11, scored as 8. Not consistent. Parked — Richard flags if it recurs

### Deployment
- [ ] Deployment process still error-prone (Richard flagged stale live site twice)

### Spec [TBC] Items (design decisions needed)
- [ ] L4 strike system (3 tries? 2? Win-or-bust?)
- [ ] L6 game mode (best of 5 or 7?)
- [ ] Team hiring costs (upfront or % of winnings?)
- [ ] All food/jewellery/dart/doctor/inflatable pricing
- [ ] L4 and L5 post-win character details
