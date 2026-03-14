extends RefCounted
class_name DartData

# Dart tiers — unlocked as weight increases through career
# Each tier has tighter scatter but needs more throw power to fly well
const TIERS := [
	{
		"name": "Brass",
		"barrel_color": Color(0.75, 0.60, 0.20),
		"barrel_metallic": 0.5,
		"flight_color": Color(0.9, 0.2, 0.1),
		"barrel_radius": 0.014,
		"barrel_length": 0.22,
		"scatter_mult": 1.0,       # Base scatter
		"weight_label": "18g",
	},
	{
		"name": "Nickel Silver",
		"barrel_color": Color(0.7, 0.7, 0.72),
		"barrel_metallic": 0.7,
		"flight_color": Color(0.1, 0.4, 0.9),
		"barrel_radius": 0.013,
		"barrel_length": 0.24,
		"scatter_mult": 0.85,      # Tighter grouping
		"weight_label": "22g",
	},
	{
		"name": "Tungsten",
		"barrel_color": Color(0.35, 0.35, 0.40),
		"barrel_metallic": 0.85,
		"flight_color": Color(0.1, 0.8, 0.2),
		"barrel_radius": 0.011,
		"barrel_length": 0.26,
		"scatter_mult": 0.65,      # Noticeably tighter
		"weight_label": "24g",
	},
	{
		"name": "Premium Tungsten",
		"barrel_color": Color(0.15, 0.15, 0.18),
		"barrel_metallic": 0.95,
		"flight_color": Color(0.85, 0.7, 0.0),
		"barrel_radius": 0.010,
		"barrel_length": 0.28,
		"scatter_mult": 0.45,      # Minimal scatter
		"weight_label": "26g",
	},
]

static func get_tier(tier: int) -> Dictionary:
	return TIERS[clampi(tier, 0, TIERS.size() - 1)]

static func get_name(tier: int) -> String:
	return get_tier(tier)["name"]

static func get_scatter_mult(tier: int) -> float:
	return get_tier(tier)["scatter_mult"]

static func get_barrel_color(tier: int) -> Color:
	return get_tier(tier)["barrel_color"]

static func get_flight_color(tier: int) -> Color:
	return get_tier(tier)["flight_color"]

static func get_barrel_radius(tier: int) -> float:
	return get_tier(tier)["barrel_radius"]

static func get_barrel_length(tier: int) -> float:
	return get_tier(tier)["barrel_length"]

static func get_barrel_metallic(tier: int) -> float:
	return get_tier(tier)["barrel_metallic"]
