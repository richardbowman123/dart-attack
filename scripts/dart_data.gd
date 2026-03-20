extends RefCounted
class_name DartData

# Dart tiers — unlocked as weight increases through career
# Each tier has tighter scatter but needs more throw power to fly well
const TIERS := [
	{
		# ── Tier 0: Brass ── pub darts, found in a jar behind the bar
		"name": "Brass",
		"barrel_color": Color(0.75, 0.60, 0.20),
		"barrel_metallic": 0.5,
		"barrel_roughness": 0.4,
		"barrel_radius": 0.014,
		"barrel_length": 0.22,
		"scatter_mult": 1.0,
		"bounce_rate": 0.05,
		"weight_label": "18g",
		# Visual detail
		"tip_taper": 0.4,
		"collar_color": Color(0.7, 0.7, 0.72),       # Chrome
		"collar_metallic": 0.9,
		# 5 uniform rings — basic knurl
		"grip_pattern": [
			[0.0, 1.0], [0.25, 1.0], [0.5, 1.0], [0.75, 1.0], [1.0, 1.0],
		],
		"flight_sheen": false,       # Flat plastic, fully unshaded
		"flight_gold_edge": false,
	},
	{
		# ── Tier 1: Nickel Silver ── first "own darts" from a sports shop
		"name": "Nickel Silver",
		"barrel_color": Color(0.7, 0.7, 0.72),
		"barrel_metallic": 0.7,
		"barrel_roughness": 0.3,
		"barrel_radius": 0.013,
		"barrel_length": 0.24,
		"scatter_mult": 0.85,
		"bounce_rate": 0.035,
		"weight_label": "22g",
		# Visual detail
		"tip_taper": 0.35,
		"collar_color": Color(0.82, 0.82, 0.84),     # Polished silver
		"collar_metallic": 0.92,
		# 7 alternating wide/narrow rings — deliberate pattern
		"grip_pattern": [
			[0.0, 1.0], [0.15, 1.7], [0.3, 1.0], [0.45, 1.7],
			[0.6, 1.0], [0.75, 1.7], [1.0, 1.0],
		],
		"flight_sheen": false,
		"flight_gold_edge": false,
	},
	{
		# ── Tier 2: Tungsten ── serious kit, spending real money
		"name": "Tungsten",
		"barrel_color": Color(0.78, 0.78, 0.82),
		"barrel_metallic": 0.85,
		"barrel_roughness": 0.25,
		"barrel_radius": 0.011,
		"barrel_length": 0.26,
		"scatter_mult": 0.65,
		"bounce_rate": 0.02,
		"weight_label": "24g",
		# Visual detail
		"tip_taper": 0.3,
		"collar_color": Color(0.55, 0.45, 0.2),      # Dark gold
		"collar_metallic": 0.93,
		# 9 dense rings — precision knurl
		"grip_pattern": [
			[0.0, 1.0], [0.125, 1.0], [0.25, 1.0], [0.375, 1.0],
			[0.5, 1.0], [0.625, 1.0], [0.75, 1.0], [0.875, 1.0], [1.0, 1.0],
		],
		"flight_sheen": true,        # Subtle metallic response — catches light
		"flight_gold_edge": false,
	},
	{
		# ── Tier 3: Premium Tungsten ── match-day darts, kept in a leather case
		# Blue-steel silver finish — lighter than before, visible against black board segments
		"name": "Premium Tungsten",
		"barrel_color": Color(0.75, 0.77, 0.85),
		"barrel_metallic": 0.92,
		"barrel_roughness": 0.12,
		"barrel_radius": 0.010,
		"barrel_length": 0.28,
		"scatter_mult": 0.45,
		"bounce_rate": 0.01,
		"weight_label": "26g",
		# Visual detail
		"tip_taper": 0.25,
		"collar_color": Color(0.85, 0.7, 0.0),       # Bright gold
		"collar_metallic": 0.95,
		# Signature cluster: 3 + gap + 3 + gap + 2 — pro grip pattern
		"grip_pattern": [
			[0.0, 1.2], [0.07, 1.2], [0.14, 1.2],
			[0.50, 1.2], [0.57, 1.2], [0.64, 1.2],
			[0.88, 1.2], [1.0, 1.2],
		],
		"flight_sheen": true,
		"flight_gold_edge": true,    # Gold trailing edge on flights
	},
]

# Flight colours by character — two colours per character for front/back split
# These replace per-tier flight colours; the player's country always shows
enum Character { DAI, TERRY, RAB, SIOBHAN }

const FLIGHT_COLORS := {
	Character.DAI: {
		"front": Color(0.80, 0.0, 0.0),     # Welsh red
		"back": Color(0.0, 0.65, 0.32),      # Welsh green
	},
	Character.TERRY: {
		"front": Color(0.81, 0.07, 0.14),    # St George red
		"back": Color(0.95, 0.95, 0.95),     # White
	},
	Character.RAB: {
		"front": Color(0.0, 0.37, 0.72),     # Saltire blue
		"back": Color(0.95, 0.95, 0.95),     # White
	},
	Character.SIOBHAN: {
		"front": Color(0.0, 0.60, 0.29),     # Irish green
		"back": Color(0.95, 0.95, 0.95),     # White
	},
}

static func get_tier(tier: int) -> Dictionary:
	return TIERS[clampi(tier, 0, TIERS.size() - 1)]

static func get_name(tier: int) -> String:
	return get_tier(tier)["name"]

static func get_scatter_mult(tier: int) -> float:
	return get_tier(tier)["scatter_mult"]

static func get_barrel_color(tier: int) -> Color:
	return get_tier(tier)["barrel_color"]

static func get_flight_colors(character: Character) -> Dictionary:
	return FLIGHT_COLORS[character]

static func get_barrel_radius(tier: int) -> float:
	return get_tier(tier)["barrel_radius"]

static func get_barrel_length(tier: int) -> float:
	return get_tier(tier)["barrel_length"]

static func get_barrel_metallic(tier: int) -> float:
	return get_tier(tier)["barrel_metallic"]

# Profile image paths for each playable character
const PROFILE_IMAGES := {
	Character.DAI: "res://Dai The Dragon Davies 16 profile.jpg",
	Character.TERRY: "res://Terry The Hammer Hoskins 19 profile.jpg",
	Character.RAB: "res://Rab The Flame McTavish 21 profile.jpg",
	Character.SIOBHAN: "res://Siobhan The Banshee O'Hara 19 profile.jpg",
}

# Short display names for each character
const CHARACTER_NAMES := {
	Character.DAI: "Dai",
	Character.TERRY: "Terry",
	Character.RAB: "Rab",
	Character.SIOBHAN: "Siobhan",
}

# Nicknames for each character
const CHARACTER_NICKNAMES := {
	Character.DAI: "THE DRAGON",
	Character.TERRY: "THE HAMMER",
	Character.RAB: "THE FLAME",
	Character.SIOBHAN: "THE SHAMROCK",
}

static func get_profile_image(character: Character) -> String:
	return PROFILE_IMAGES[character]

# Age labels for each appearance tier (0-3)
const TIER_AGES := ["19", "21", "23", "25"]

## Get career progression portrait for a given appearance tier (0-3).
## Uses images from "Final player images/" folder.
static func get_profile_image_for_tier(character: Character, tier: int) -> String:
	var char_name: String = CHARACTER_NAMES[character]
	var age: String = TIER_AGES[clampi(tier, 0, 3)]
	return "res://Final player images/" + char_name + " aged " + age + ".jpg"

## Get the victory crowd scene image (used only on L7 world champion win).
static func get_victory_image(character: Character) -> String:
	return "res://Final player images/" + CHARACTER_NAMES[character] + " wins.jpg"

static func get_character_name(character: Character) -> String:
	return CHARACTER_NAMES[character]

static func get_character_nickname(character: Character) -> String:
	return CHARACTER_NICKNAMES[character]

static func get_is_female(character: Character) -> bool:
	return character == Character.SIOBHAN

## Full surname for each character
const CHARACTER_FULL_NAMES := {
	Character.DAI: "Dai Davies",
	Character.TERRY: "Terry Hoskins",
	Character.RAB: "Rab McTavish",
	Character.SIOBHAN: "Siobhan O'Hara",
}

static func get_full_name(character: Character) -> String:
	return CHARACTER_FULL_NAMES[character]
