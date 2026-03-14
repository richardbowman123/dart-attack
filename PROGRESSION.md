# Dart Attack - Progression & Meta-Game Design

This document captures the full progression system, in-match stats, career stats, and level gates. It sits alongside NARRATIVE.md (story, characters, endings) and is the mechanical reference for building the career mode.

---

## In-Match Stats

Four stats visible on HUD during every match, shown for both player and opponent.

### 1. Dart Quality
- **What it is:** The tier of darts the player owns (pub brass → premium tungsten)
- **Effect:** Better darts = tighter grouping / better accuracy on every throw
- **How you improve it:** Buy better darts between games (costs money)
- **Opponent version:** Each AI opponent has a fixed dart quality that matches their level

### 2. Confidence
- **What it is:** How well the player is throwing right now
- **Starting state:** Very low on the first visit of each NEW level (you've never been here before). Resets partially on rematches at the same level
- **What raises it:** Hitting good scores (60+, 100+, 180), hitting doubles, winning legs
- **What drops it:** Missing shots, opponent scoring well, being on an important checkout
- **Effect:** Modifies accuracy. High confidence = throws land closer to where you aim. Low confidence = wider scatter, especially on pressure shots like checkouts
- **Tie to dart quality:** Good darts + high confidence = surgical. Good darts + low confidence = still scattered because your hands are shaking

### 3. Nerves
- **What it is:** Inverse of confidence, but a separate meter
- **What raises them:** Start of match (baseline set by level — pub = low, Worlds = high), missing shots, opponent scoring well, being close to checkout, match point against you
- **What lowers them:** Hitting good scores, opponent missing, drinking
- **Effect:** Scatter/wobble on the throw. High nerves = dart wanders from where you aimed
- **Key mechanic:** Drinking is the primary nerve reducer — but drinking too much has its own consequences (see Drinking below)
- **Opponent version:** AI opponents have a nerve baseline. Early opponents crack under pressure (miss when close to finishing). Vinnie Gold gets BETTER under pressure.

### 4. Anger (opponent stat)
- **What it is:** How wound up the opponent is
- **What raises it:** Player celebrations between legs (in multi-leg matches, levels 6-7). The more you celebrate, the more their anger rises
- **What drops it:** Time passing, opponent scoring well
- **Effect on opponent:** Anger makes them less accurate (scatter increases)
- **THE FIGHT:** If opponent anger hits maximum, they snap. There's a fight. You ALWAYS lose the fight. Career consequences (TBD — could be injury, lost money, reputation hit). This is the risk/reward of celebrating: you can tilt your opponent, but push too far and you're done
- **Player celebration options (between legs):**
  - Modest nod (no anger increase, no confidence boost to you)
  - Fist pump (small anger increase, small confidence boost)
  - Full crowd celebration (big anger increase, big confidence boost)
  - Over-the-top showboat (massive anger increase, massive confidence boost, high fight risk)

---

## Drinking System

Drinking is a real-time decision made during and before matches.

### When you can drink
- **Before the match:** Pre-match drinks at the bar. Sets your starting nerve level and blur level
- **Between visits:** After every 3 darts, quick prompt: "Have a drink?" Half pint / full pint / nothing. Fast tap, doesn't break flow — like reaching for your glass on the oche shelf

### What drinking does
- **Positive:** Reduces nerves. The sweet spot is 1-2 pints — calm hands, clear vision
- **Negative:** Progressive vision impairment:
  - Sober: Crystal clear but high nerve baseline
  - Mellow (1-2 drinks): No visible change. Sweet spot
  - Tipsy (3-4): Edges soften slightly
  - Drunk (5-6): Board visibly blurs. Aiming becomes guesswork in the outer ring
  - Hammered (7+): Double vision — two overlapping boards. Functionally unplayable but hilarious
  - **Beyond hammered: You pass out and die.** Game over. Permanent.

### Heft interaction
- **Higher heft = higher tolerance.** A heavy player can drink more before hitting each threshold
- A skinny Level 1 character might get blurry after 3 pints. A Level 5 unit can handle 6 before the same effect

### Career impact
- Every drink across the entire game contributes to a hidden liver damage meter (from NARRATIVE.md)
- This can eventually kill you if you don't visit the doctor / buy medicine

---

## Career Stats (Between Games)

### Heft
- **What it is:** How big/heavy the player is. Starts skinny
- **Driven by:** Eating between games (pies, kebabs, full English, etc.)
- **Effects:**
  - **Fight resistance:** Higher heft = less likely to lose badly in a fight (opponent anger). A skinny player gets destroyed. A heavy player can take a punch
  - **Booze resistance:** Higher heft = higher alcohol tolerance. Can drink more before blur/blackout
  - **Level access:** Some later levels require minimum heft (you need to be a proper darts physique to compete at the top level)
  - **Visual:** Player character visibly fills out through the game. Commentators remark on it
- **No downside cap yet** (unlike NARRATIVE.md which has heart attack risk from max weight — keep this as a future consideration)

### Money
- **Earned from:** Match winnings (increase at higher levels), inflatable sales (from Level 3+), betting
- **Spent on:**
  - **Darts** — unlock better tiers (progression gate)
  - **Food** — pies, kebabs, full English, Sunday roast, Chinese buffet (increase heft)
  - **Jewellery** — sovereign ring, gold chain, bracelet, watch (affect appearance + crowd reaction)
  - **Manager** — one-time choice after Level 2 (Big Phil / Silent Sue / Dodgy Dave)
  - **Gambling** — bet on yourself or against yourself (risk/reward)
  - **Doctor / medicine** — health checks and treatment (from NARRATIVE.md)

### Appearance
- **Changes based on:** Food purchases (body size), jewellery (bling), dart tier (what you're holding)
- **Visible to player:** Character model/portrait updates between games
- **Affects gameplay:** Jewellery increases crowd support (nerve reduction) but adds arm weight at extreme levels

---

## Progression Gates

What the player needs to advance from each level to the next.

### Level 1 → Level 2
- **Beat:** Big Kev (Round the Clock)
- **Need:** Own a set of darts
- **Opening moment:** Game asks "Which darts would you like to use? Use your own or ask what they've got behind the bar." If player says "Use your own" → "You're broke. You can't afford any darts right now." Player uses pub darts (brass, behind the bar) for Level 1. Winnings from beating Big Kev buy their first set of proper darts
- **Unlocks:** Friday Night Tournament + dart shop access

### Level 2 → Level 3
- **Beat:** Derek (101)
- **Need:** Minimum heft (can't be skin and bone at the regionals — need at least one meal in you)
- **Opening moment:** "The regional's next month. You'll need to fill out a bit if you want to be taken seriously." Player must buy food to reach minimum heft before entering
- **Unlocks:** Regional Pub Tournament + manager choice

### Level 3 → Level 4
- **Beat:** Steve (101)
- **Need:** Better darts (nickel silver minimum — pub brass won't cut it at county level) + a manager
- **Opening moment:** Manager says "County's a different world. You'll need proper darts. And someone in your corner." Player must upgrade darts and choose a manager
- **Unlocks:** County Tournament + inflatable investment + jewellery shop

### Level 4 → Level 5
- **Beat:** Philip (301)
- **Need:** Tungsten darts (minimum) + entry fee (costs real money from your pot)
- **Opening moment:** "National qualifying. Entry fee's steep. And you'll want tungsten for this crowd — they can smell a pub player." Player must have saved enough AND upgraded darts
- **Unlocks:** National Qualifying + betting syndicate opportunity

### Level 5 → Level 6
- **Beat:** Mad Dog (301)
- **Need:** Premium tungsten darts + minimum heft (high — you're playing at Ally Pally, need the physique) + entry fee (large)
- **Opening moment:** Manager says "Right. Palace time. But you need to look the part, throw the part, and afford the part." All three gates must be met
- **Unlocks:** World Championship (semi-final vs Lars, then final vs Vinnie)

### Level 6 → Level 7
- **Beat:** Lars (501, best of 3 legs)
- **Need:** Nothing extra — you're already at Ally Pally. If you beat Lars, you face Vinnie in the final
- **Opening moment:** "One more. The Showman. Everything you've done has been for this."

---

## Between-Game Shop

After each level, the player visits a between-game screen where they can spend money.

### Food (increases heft)
| Item | Cost | Heft gain | Notes |
|------|------|-----------|-------|
| Chip butty | Cheap | Small | The staple |
| Pie and mash | Moderate | Moderate | A proper meal |
| Full English | Moderate | Good | Morning-after recovery |
| Kebab | Cheap | Moderate | Post-match classic |
| Sunday roast with seconds | Expensive | Large | Treat yourself |
| Chinese buffet (all you can eat) | Expensive | Massive | Temporary accuracy penalty next match (sluggish) |

### Jewellery (increases appearance + crowd support)
| Item | Cost | Bling level | Arm weight |
|------|------|-------------|------------|
| Sovereign ring | Cheap | Small | Negligible |
| Gold chain | Moderate | Moderate | Small |
| Chunky bracelet | Expensive | Good | Moderate |
| Diamond watch | Very expensive | High | Significant |
| Full Mr T starter kit | Ludicrous | Maximum | Severe penalty |

### Darts (progression gate + accuracy)
| Tier | Cost | Accuracy | Gate for |
|------|------|----------|----------|
| Pub brass (behind the bar) | Free | Worst | Level 1 only |
| Nickel silver | Level 1 winnings | Better | Level 2+ |
| Tungsten | Moderate | Good | Level 4+ |
| Premium tungsten | Expensive | Best | Level 5+ |

### Manager (one-time choice after Level 2)
| Manager | Bonus | Downside |
|---------|-------|----------|
| "Big Phil" Carver | +30% prize money | No training benefit |
| "Silent" Sue Palmer | -15% scatter (training) | Takes bigger cut |
| "Dodgy" Dave Slater | Intimidates opponents (+scatter) | Steals from your winnings |

---

## How Stats Interact

```
DART QUALITY ──────────────┐
                           ├──→ THROW ACCURACY (where the dart lands)
CONFIDENCE ────────────────┤
                           │
NERVES ────────────────────┘
   ↑
   │ reduces
DRINKING ─────────→ BLUR/VISION (too much = impaired, way too much = death)
   │
   │ tolerance from
HEFT ─────────────→ FIGHT RESISTANCE (opponent anger)
   │                BOOZE RESISTANCE
   │                LEVEL ACCESS (gates)
   │
   ← driven by FOOD (between games, costs money)

CELEBRATIONS ────→ OPPONENT ANGER ────→ FIGHT (if maxed = you lose)
   │                                     ↑
   └──→ YOUR CONFIDENCE (boost)         HEFT reduces damage

JEWELLERY ───────→ CROWD SUPPORT ──→ NERVE REDUCTION (small)
                   ARM WEIGHT (if too much → accuracy penalty)
```

---

## Design Notes

- **The Nerve-O-Meter** is the HUD element that shows nerves. It's the visible bar that fluctuates. The name is important — it's a proper noun in this game
- Anger only matters in multi-leg matches (levels 6-7) where there are celebrations between legs. Earlier levels are single-leg so anger doesn't apply
- The fight mechanic means there's genuine risk to showboating. You can psychologically destroy your opponent — but if you push too far, you're the one who loses
- Death can come from drinking (pass out), liver failure (cumulative career drinking), or a fight (if you're too skinny). Heft is protection against two of these
- The "You're broke" moment at Level 1 is the game's first joke and sets the tone — you're a nobody with nothing, working your way up
