extends Node

## CareerState — autoload that persists career progression between matches.
## Only relevant when career_mode_active is true.

const HEFT_NAMES := ["SKINNY", "SLIM", "AVERAGE", "STOCKY", "HEAVY", "UNIT"]

var career_mode_active: bool = false
var career_level: int = 1
var money: int = 340
var heft_tier: int = 0           # 0=skinny, 1=slim, 2=average, 3=stocky, 4=unit
var skill_stars: int = 0
var hustle_stars: int = 1
var swagger_stars: int = 0
var career_intro_seen: bool = false
var doubles_tip_shown: bool = false
var sweet_spot_tip_shown: bool = false
var dart_tier_owned: int = -1  # -1 = no owned darts (pub darts only)

# Dart shop navigation
var dart_shop_return: String = ""   # Scene to go back to after leaving shop
var post_shop_resume: bool = false  # If true, match_results resumes post-shop cards
var jewellery_items: Array = []
var manager: String = ""         # "big_phil" / "sue" / "dave"
var losses_at_current_level: int = 0
var inflatables_stock: int = 0          # actual count in inventory
var inflatables_total_bought: int = 0   # cumulative — drives discount formula
var inflatables_total_sold: int = 0     # cumulative — for hustle condition
var inflatables_pending_sale: int = 0   # allocated for sale at next match
var inflatables_total_profit: int = 0   # cumulative pence — for hustle star 5
var trader_met: bool = false
var coach_hired: bool = false
var manager_hired: bool = false
var team_hired: bool = false

# Pre-match drinking — units stored here, applied when match starts
var pre_drink_units: int = 0

# Exhibition mode — one-off matches, no career progression
var exhibition_mode: bool = false

# Swagger progression — all non-optional, forced by narrative
var shopping_spree_done: bool = false   # Star 1 (L2) — bling + tattoos
var celebration_style: int = -1         # Star 2 (L3) — 0=Flex, 1=Big Fish, 2=Down a Pint
var silk_shirt_received: bool = false   # Star 3 (L4) — gift from coach/manager
var dodgy_bet_won: bool = false         # Star 4 (L5) — bet on yourself and won
var walkon_track: int = -1              # Star 5 (L6) — 0/1/2 = track choices

# Fight state — set before transitioning to fight screen
var fight_pending: bool = false
var fight_opponent_id: String = ""

# Hidden stats (player never sees raw numbers)
var liver_damage: float = 0.0    # 0-100
var heart_risk: float = 0.0      # 0-100
var reputation: float = 50.0     # 0=dirty, 100=clean

# Carries between matches
var confidence_carry: float = 50.0

func get_heft_name() -> String:
	if heft_tier >= 0 and heft_tier < HEFT_NAMES.size():
		return HEFT_NAMES[heft_tier]
	return "UNKNOWN"

## Reset everything for a new career
func reset() -> void:
	career_mode_active = false
	career_level = 1
	money = 340
	heft_tier = 0
	skill_stars = 0
	hustle_stars = 1
	swagger_stars = 0
	career_intro_seen = false
	doubles_tip_shown = false
	sweet_spot_tip_shown = false
	dart_tier_owned = -1
	dart_shop_return = ""
	post_shop_resume = false
	jewellery_items.clear()
	manager = ""
	losses_at_current_level = 0
	inflatables_stock = 0
	inflatables_total_bought = 0
	inflatables_total_sold = 0
	inflatables_pending_sale = 0
	inflatables_total_profit = 0
	trader_met = false
	coach_hired = false
	manager_hired = false
	team_hired = false
	pre_drink_units = 0
	exhibition_mode = false
	shopping_spree_done = false
	celebration_style = -1
	silk_shirt_received = false
	dodgy_bet_won = false
	walkon_track = -1
	fight_pending = false
	fight_opponent_id = ""
	liver_damage = 0.0
	heart_risk = 0.0
	reputation = 50.0
	confidence_carry = 50.0

## Get the current unit price in pence for the next batch of 10 inflatables.
## 5% compounding discount per 10 previously bought.
func get_inflatable_unit_price() -> int:
	var discount_steps := int(inflatables_total_bought / 10)
	return int(100.0 * pow(0.95, discount_steps))

## Recalculate hustle_stars from compound conditions.
## Call after any change to coach/manager/team/merch state.
func recalculate_hustle() -> void:
	var stars := 1  # base
	if coach_hired and inflatables_total_bought > 0:
		stars += 1
	if manager_hired and inflatables_total_sold > 0:
		stars += 1
	if team_hired:
		stars += 1
	if inflatables_total_profit >= 20000:  # £200 in pence
		stars += 1
	hustle_stars = mini(stars, 5)

## Recalculate swagger_stars from narrative milestones.
## All are non-optional — companion forces each one.
func recalculate_swagger() -> void:
	var stars := 0
	if shopping_spree_done:
		stars += 1
	if celebration_style >= 0:
		stars += 1
	if silk_shirt_received:
		stars += 1
	if dodgy_bet_won:
		stars += 1
	if walkon_track >= 0:
		stars += 1
	swagger_stars = mini(stars, 5)
