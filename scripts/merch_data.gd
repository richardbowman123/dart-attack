class_name MerchData
extends RefCounted

## Merch / inflatables trading data.
## Venue config, inflatable naming, sale estimation and resolution.

# Level -> {max_sales, price_per_unit (pence), venue_name}
const VENUE_TRADING := {
	4: {"max_sales": 50, "price_per_unit": 300, "venue_name": "County Club"},
	5: {"max_sales": 150, "price_per_unit": 500, "venue_name": "National Qualifying"},
	6: {"max_sales": 500, "price_per_unit": 800, "venue_name": "The Arrow Palace"},
	7: {"max_sales": 1500, "price_per_unit": 1500, "venue_name": "World Championship"},
}

# Character nickname -> plural inflatable name
const INFLATABLE_NAMES := {
	"THE DRAGON": "dragons",
	"THE HAMMER": "hammers",
	"THE FLAME": "flames",
	"THE BANSHEE": "banshees",
}

## Get the inflatable item name (plural) for the current character.
static func get_inflatable_name(character: int) -> String:
	var nick: String = DartData.get_character_nickname(character)
	return INFLATABLE_NAMES.get(nick, "darts")

## Get the inflatable item name capitalised for titles (e.g. "DRAGONS").
static func get_inflatable_title(character: int) -> String:
	return get_inflatable_name(character).to_upper()

## Estimate a sale before the match (shown in hub).
## Returns {volume, unit_price, revenue}
static func estimate_sale(qty: int, level: int) -> Dictionary:
	var config: Dictionary = VENUE_TRADING.get(level, VENUE_TRADING[4])
	var unit_price: int = config["price_per_unit"]
	return {"volume": qty, "unit_price": unit_price, "revenue": qty * unit_price}

## Resolve sale after match — applies +/- 20% variance on volume.
## Returns {sold, revenue, unsold, flavour_text}
static func resolve_sale(qty: int, level: int) -> Dictionary:
	var config: Dictionary = VENUE_TRADING.get(level, VENUE_TRADING[4])
	var unit_price: int = config["price_per_unit"]

	# Variance: 80% to 120% of committed qty, capped at committed
	var variance: float = randf_range(0.8, 1.2)
	var actual_sold: int = mini(int(qty * variance), qty)
	actual_sold = maxi(actual_sold, 1)  # sell at least 1 if any committed

	var revenue: int = actual_sold * unit_price
	var unsold: int = qty - actual_sold

	var flavour: String
	if actual_sold > qty * 0.95:
		flavour = "Sold out before the third leg!"
	elif actual_sold < qty * 0.85:
		flavour = "Bit quiet out there tonight."
	else:
		flavour = "Shifted the lot. Right on the money."

	return {"sold": actual_sold, "revenue": revenue, "unsold": unsold, "flavour_text": flavour}

## Get venue info for selling at a given level.
## Returns null if selling not available at this level.
static func get_venue_config(level: int) -> Variant:
	if level in VENUE_TRADING:
		return VENUE_TRADING[level]
	return null
