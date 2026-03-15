extends Node

## CareerState — autoload that persists career progression between matches.
## Only relevant when career_mode_active is true.

var career_mode_active: bool = false
var career_level: int = 1
var money: int = 340
var heft_tier: int = 0           # 0=skinny, 1=slim, 2=average, 3=stocky, 4=unit
var dart_tier_owned: int = 0
var jewellery_items: Array = []
var manager: String = ""         # "big_phil" / "sue" / "dave"
var losses_at_current_level: int = 0

# Hidden stats (player never sees raw numbers)
var liver_damage: float = 0.0    # 0-100
var heart_risk: float = 0.0      # 0-100
var reputation: float = 50.0     # 0=dirty, 100=clean

# Carries between matches
var confidence_carry: float = 50.0

## Reset everything for a new career
func reset() -> void:
	career_mode_active = false
	career_level = 1
	money = 340
	heft_tier = 0
	dart_tier_owned = 0
	jewellery_items.clear()
	manager = ""
	losses_at_current_level = 0
	liver_damage = 0.0
	heart_risk = 0.0
	reputation = 50.0
	confidence_carry = 50.0
