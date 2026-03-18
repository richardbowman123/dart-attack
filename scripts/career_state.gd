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
var dart_tier_owned: int = 0
var jewellery_items: Array = []
var manager: String = ""         # "big_phil" / "sue" / "dave"
var losses_at_current_level: int = 0
var inflatables_owned: int = 0
var inflatables_cost: int = 0
var coach_hired: bool = false
var manager_hired: bool = false
var team_hired: bool = false

# Pre-match drinking — units stored here, applied when match starts
var pre_drink_units: int = 0

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
	dart_tier_owned = 0
	jewellery_items.clear()
	manager = ""
	losses_at_current_level = 0
	inflatables_owned = 0
	inflatables_cost = 0
	coach_hired = false
	manager_hired = false
	team_hired = false
	pre_drink_units = 0
	liver_damage = 0.0
	heart_risk = 0.0
	reputation = 50.0
	confidence_carry = 50.0
