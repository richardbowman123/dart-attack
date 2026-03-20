# Batch 2 — Medium Builds (No design input needed)

Work through these independently. Read the relevant scripts before editing. All files are in `scripts/` under the Dart Attack folder.

## 1. Coach checkout advice
- After recruiting the coach (L3+), the first time the player comes to the oche, the coach should give one-time generic advice
- NOT specific checkout routes — just something like: "You can check out here. Just try to get the score as low as possible and then work out which double you need."
- One or two lines, non-blocking (use `show_message()` or similar brief display)
- Only show once per career (track with a CareerState flag like `coach_checkout_tip_shown`)
- Should only trigger in countdown modes (101/301/501) when the player's remaining score is checkable
- The coach promised this when hired — this delivers on that promise

## 2. Experienced opponents — tone down nerves display
- Older/more experienced opponents (later levels) shouldn't display as being too nervous on their stats cards
- Their actual AI play quality stays the same (stats don't affect AI behaviour)
- Just adjust the displayed stats to make narrative sense — a seasoned pro doesn't get nervous
- Check `opponent_data.gd` for where opponent stats are defined
- Check `match_results.gd` `_build_opponent_stats_card()` for how they're displayed

## 3. Doctor description fix
- The doctor card describes a "tired-looking man" which doesn't match the image
- Find the doctor card text in `match_results.gd` (L5 or L6 flow)
- Update the description to match the actual doctor character image
- Smooth over the introduction

## 4. Mates card — move earlier in L3
- The mates card ("THE MATES") was recently moved to after the food card in L3
- Richard feels it still needs to come even earlier
- Consider putting it right after the skill star flip, before the food card
- The idea is: you win, you celebrate, mates show up excited, THEN food, THEN Alan hands off to the coach

## 5. Money overdraft prevention + display consistency
- Player should never be able to go overdrawn — add checks before any money deduction
- Money display should be visible when spending (hub, shop, food decisions, hiring)
- Currently shows during match play but weirdly absent during spending moments
- Check all `CareerState.money -= X` calls and add `if CareerState.money >= cost` guards
- Check `score_hud.gd` for balance display logic

## Key files to read first:
- `scripts/match_manager.gd` (coach advice, oche visits)
- `scripts/match_results.gd` (doctor card, mates card, opponent stats)
- `scripts/opponent_data.gd` (opponent stats)
- `scripts/career_state.gd` (money, flags)
- `scripts/between_match_hub.gd` (hub spending)
- `scripts/score_hud.gd` (balance display)

## Rules:
- Keep text in Bungee font style (ALL CAPS in display, but stored normally)
- Card overflow: keep cards under 1280px total height
- Use `_add_card(card, "Name")` pattern (CardValidator)
- Don't touch throw/aim code (see THROW_SYSTEM_SPEC.md)
- Test both paths on toggle-visibility cards
