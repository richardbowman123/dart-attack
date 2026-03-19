class_name ExhibitionData
extends RefCounted

## Exhibition match data — random opponents, formats, prizes for money grinding.
## Available from L3+ via the between-match hub.

# Pool of exhibition opponents (placeholder — Richard to expand to ~20)
const OPPONENT_IDS: Array[String] = [
	"exh_barry", "exh_donna", "exh_slim", "exh_tank", "exh_fingers",
]

# Game format pool — picked randomly per exhibition
const FORMATS := [
	{"game_mode": "rtc", "starting_score": 0, "legs_to_win": 1, "label": "Round the Clock"},
	{"game_mode": "countdown", "starting_score": 101, "legs_to_win": 1, "label": "101 Single Leg"},
	{"game_mode": "countdown", "starting_score": 101, "legs_to_win": 2, "label": "101 Best of 3"},
	{"game_mode": "countdown", "starting_score": 301, "legs_to_win": 1, "label": "301 Single Leg"},
	{"game_mode": "countdown", "starting_score": 301, "legs_to_win": 3, "label": "301 Best of 5"},
	{"game_mode": "countdown", "starting_score": 501, "legs_to_win": 1, "label": "501 Single Leg"},
	{"game_mode": "countdown", "starting_score": 501, "legs_to_win": 2, "label": "501 Best of 3"},
]

# Prize ranges per career level (pence). Random within range, rounded to nearest £10.
const PRIZE_RANGES := {
	3: {"min": 10000, "max": 50000},
	4: {"min": 50000, "max": 200000},
	5: {"min": 200000, "max": 750000},
	6: {"min": 500000, "max": 1500000},
	7: {"min": 1000000, "max": 2000000},
}

# Exhibition venue names per career level
const VENUES := {
	3: "Back-Room Exhibition, Social Club",
	4: "County Club Exhibition Night",
	5: "National Open Exhibition",
	6: "All-Stars Exhibition, The Arrow Palace",
	7: "All-Stars Exhibition, The Arrow Palace",
}

# Current matchup (set by generate_matchup, read by hub + match)
static var current_opponent_id: String = ""
static var current_format: Dictionary = {}
static var current_prize: int = 0
static var current_venue: String = ""

## Generate a random exhibition matchup for the given career level.
static func generate_matchup(level: int) -> void:
	# Pick random opponent
	current_opponent_id = OPPONENT_IDS[randi() % OPPONENT_IDS.size()]

	# Pick random format
	current_format = FORMATS[randi() % FORMATS.size()]

	# Pick random prize within level range
	var range_dict: Dictionary = PRIZE_RANGES.get(level, PRIZE_RANGES[3])
	var raw_prize: int = randi_range(range_dict["min"], range_dict["max"])
	# Round to nearest £10 (1000 pence)
	current_prize = int(round(raw_prize / 1000.0)) * 1000

	# Set venue
	current_venue = VENUES.get(level, VENUES[3])

## Re-randomise everything for the same level.
static func reroll(level: int) -> void:
	generate_matchup(level)

## Write exhibition matchup onto GameState + OpponentData for match start.
static func apply_to_game_state() -> void:
	GameState.opponent_id = current_opponent_id
	GameState.is_vs_ai = true
	GameState.dart_tier = max(0, CareerState.dart_tier_owned)

	if current_format["game_mode"] == "rtc":
		GameState.game_mode = GameState.GameMode.ROUND_THE_CLOCK
		GameState.starting_score = 0
	else:
		GameState.game_mode = GameState.GameMode.COUNTDOWN
		GameState.starting_score = current_format["starting_score"]

## Get the format label for display (e.g. "301 Best of 5").
static func get_format_label() -> String:
	return current_format.get("label", "Exhibition")

## Get legs_to_win for the current exhibition format.
static func get_legs_to_win() -> int:
	return current_format.get("legs_to_win", 1)
