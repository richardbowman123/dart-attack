# Batch 3 — Bigger Builds (Need Richard's input during session)

These items need design decisions. Read the context below, then ask Richard for specifics before building.

## 1. Fight scene / unknown caller / throwing a leg
- When opponent anger hits 100, a fight triggers (currently counts as a loss)
- The unknown caller rings during the L5 (Mad Dog) match offering to fix legs
- After the call, there's no follow-up conversation/decision card — need to add one
- **Ask Richard:** How should the fight actually play out? Is it a mini-game, a card sequence, or just narrative? What happens after — injury effects? Does the unknown caller appear at other levels too?

## 2. Over-celebrating at L4
- At L3 the player learns to celebrate. Steve squares up about it.
- At L4, celebrating too hard should have consequences
- **Ask Richard:** What's the consequence? A fight? Getting knocked out? Does it affect the next match? Is it a narrative card or an in-match event?

## 3. Team introduction with roles
- When the full team is hired (L6), each person needs a named role
- Manager speaks first (not coach)
- Unknown metric on the card should be replaced with a breathalyser reading
- **Ask Richard:** What roles does he want? Suggestions: physio, nutritionist, PR/media handler, kit manager? How many people in the team? Does each get their own card or one group card?

## 4. 180 fanfare visual effect
- Current 180 graphic should be used for any score 140+
- Actual 180 gets a special effect: number pops out, white-to-gold glisten sweeping left to right
- **Build approach:** Find the current 180 display in `match_manager.gd`, extend the threshold to 140+, then add a gold tween effect for 180 specifically
- **Ask Richard to confirm:** Is the effect just on the number text, or should the whole screen flash? How long should it last?

## 5. End credits
- After winning the final (L7), show "where are they now" for every character
- The £50k buys the parents a house
- **Ask Richard:** Does he want to write the lines himself, or should Claude draft them? Which characters get credit lines? (Big Kev, Derek, Steve, Philip, Mad Dog, Lars, Vinnie, Alan, Coach, Manager, Trader, Contact, Doctor, Sponsor Rep, the mates?)

## 6. Outstanding images
- Some player character images and all exhibition opponent images still need adding
- **Ask Richard:** Which specific images are missing? Are the files already in the project folder, or does he need to provide them?

## 7. Menu usability pass
- Some menus pushed to the right
- Drunk warning ("take it easy mate") appearing in wrong places
- **Best approach:** Ask Richard to play through and screenshot each problem as he hits it. Fix them one by one.

## 8. In-match drinking accumulation
- Round offer system exists (every 3rd visit, L2+)
- Need to verify it properly accumulates and can push player into heavy/hammered
- With the Batch 1 fix (pint = 4 units), this should work better automatically
- **Check:** Does `DrinkManager.apply_drink()` actually get called on round acceptance? Does the drinks_changed signal fire?

## Key context files:
- `NARRATIVE.md` — full game design document
- `NOTES.md` — development notes with the full amends list
- `scripts/match_manager.gd` — main match logic, fight triggers, 180 display
- `scripts/match_results.gd` — all narrative cards, team hire, end credits
- `scripts/career_state.gd` — all career flags and state
- `scripts/companion_data.gd` — companion dialogue data
- `scripts/drink_manager.gd` — drinking system

## Rules:
- Always ask Richard before building anything in this batch
- Keep card text concise — Bungee font is wide
- Card overflow prevention: total height under 1280px
- Don't touch throw/aim code
