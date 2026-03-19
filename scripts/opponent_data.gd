extends RefCounted
class_name OpponentData

# AI opponent roster — 7 opponents with escalating difficulty.
# scatter: radius in board units (higher = less accurate)
# double_hit_pct: chance of hitting a double when aiming at one (0.0–1.0)
# throw_delay: seconds between darts (pacing)
#
# Venues for levels 1-3 are character-specific (local to where each player lives).
# From level 4 onwards, all characters play at the same national/international venues.

const OPPONENTS := {
	"big_kev": {
		"name": "Big Kev",
		"nickname": "THE FRIDGE",
		"level": 1,
		"scatter": 0.38,
		"double_hit_pct": 0.20,
		"throw_delay": 0.8,
		"game_mode": "rtc",
		"starting_score": 0,
		"image": "res://Big Kev.jpg",
		"vibe": "Back room of the local. Sticky carpet, fruit machine, three regulars watching.",
		"buy_in": 0,
		"prize_money": 1000,
		"max_losses": 3,
		# RTC scatter: single Gaussian spread applied to every throw.
		# No hit/miss branching — just natural scatter like a real player.
		# Outer single is ~0.49 wide, ~0.65 deep. At 0.22, most darts
		# land in the right segment; some drift into neighbours or off the board.
		"rtc_scatter": 0.22,
		# Rubber-banding: tighter when behind (more hits), wider when ahead
		"rtc_scatter_ahead": 0.30,   # Looser when cruising — more misses
		"rtc_scatter_behind": 0.15,  # Tighter when catching up — more hits
		"dart_quality": 20,
		"base_confidence": 40,
		"base_anger": 10,
		"anger_rate": 0.5,
		"legs_to_win": 1,
		"fight_heft": 4, "fight_swagger": 1, "fight_drunk": 2,
	},
	"derek": {
		"name": "Derek",
		"nickname": "THE POSTMAN",
		"level": 2,
		"scatter": 0.35,
		"double_hit_pct": 0.25,
		"throw_delay": 0.7,
		"game_mode": "countdown",
		"starting_score": 101,
		"image": "res://Derek.jpg",
		"vibe": "Friday night tournament. Tables pushed back, chalked bracket on the blackboard, pints everywhere.",
		"buy_in": 500,
		"prize_money": 5000,
		"max_losses": 3,
		"dart_quality": 35,
		"base_confidence": 50,
		"base_anger": 15,
		"anger_rate": 0.8,
		"legs_to_win": 2,
		"fight_heft": 2, "fight_swagger": 2, "fight_drunk": 2,
	},
	"steve": {
		"name": "Steve",
		"nickname": "THE SPARKY",
		"level": 3,
		"scatter": 0.32,
		"double_hit_pct": 0.35,
		"throw_delay": 0.65,
		"game_mode": "countdown",
		"starting_score": 101,
		"image": "",
		"vibe": "Working men's club. Proper oche, small stage, folding chairs for fifty, commentator with a microphone.",
		"buy_in": 2000,
		"prize_money": 20000,
		"max_losses": 3,
		"dart_quality": 45,
		"base_confidence": 55,
		"base_anger": 20,
		"anger_rate": 1.0,
		"legs_to_win": 4,
		"fight_heft": 2, "fight_swagger": 2, "fight_drunk": 3,
	},
	"philip": {
		"name": "Philip",
		"nickname": "THE ACCOUNTANT",
		"level": 4,
		"scatter": 0.22,
		"double_hit_pct": 0.55,
		"throw_delay": 0.6,
		"game_mode": "countdown",
		"starting_score": 301,
		"venue": "County Darts Club",
		"image": "",
		"vibe": "Civic hall. Lighting rig, raised oche, sponsor banners, two hundred in the crowd, regional TV cameras.",
		"buy_in": 7500,
		"prize_money": 75000,
		"max_losses": 3,
		"dart_quality": 60,
		"base_confidence": 65,
		"base_anger": 10,
		"anger_rate": 0.6,
		"legs_to_win": 3,
		"fight_heft": 1, "fight_swagger": 1, "fight_drunk": 0,
	},
	"mad_dog": {
		"name": "Mad Dog",
		"nickname": "MAD DOG",
		"level": 5,
		"scatter": 0.18,
		"double_hit_pct": 0.60,
		"throw_delay": 0.5,
		"game_mode": "countdown",
		"starting_score": 301,
		"venue": "National Qualifying, Milton Keynes",
		"image": "",
		"vibe": "Conference centre. Harsh fluorescent lighting, professional oche, five hundred watching. Everyone thinks they're good enough.",
		"buy_in": 20000,
		"prize_money": 300000,
		"max_losses": 1,
		"dart_quality": 55,
		"base_confidence": 60,
		"base_anger": 40,
		"anger_rate": 2.0,
		"legs_to_win": 4,
		"fight_heft": 3, "fight_swagger": 4, "fight_drunk": 2,
	},
	"lars": {
		"name": "Lars",
		"nickname": "THE VIKING",
		"level": 6,
		"scatter": 0.12,
		"double_hit_pct": 0.75,
		"throw_delay": 0.55,
		"game_mode": "countdown",
		"starting_score": 501,
		"venue": "The Arrow Palace, London",
		"image": "",
		"vibe": "The cathedral of darts. Walk-on music, pyrotechnics, two thousand in fancy dress. The board is lit like a shrine.",
		"buy_in": 50000,
		"prize_money": 1000000,
		"max_losses": 1,
		"dart_quality": 80,
		"base_confidence": 75,
		"base_anger": 15,
		"anger_rate": 0.7,
		"legs_to_win": 3,
		"fight_heft": 5, "fight_swagger": 4, "fight_drunk": 3,
	},
	"vinnie": {
		"name": "Vinnie Gold",
		"nickname": "THE GOLD",
		"level": 7,
		"scatter": 0.08,
		"double_hit_pct": 0.85,
		"throw_delay": 0.45,
		"game_mode": "countdown",
		"starting_score": 501,
		"venue": "The Arrow Palace, London",
		"image": "",
		"vibe": "World Championship Final. Gold confetti, fireworks, the crowd is on their feet. This is it.",
		"buy_in": 100000,
		"prize_money": 5000000,
		"max_losses": 1,
		"dart_quality": 95,
		"base_confidence": 85,
		"base_anger": 25,
		"anger_rate": 1.5,
		"legs_to_win": 4,
		"fight_heft": 3, "fight_swagger": 5, "fight_drunk": 2,
	},
	# ── Exhibition opponents (level 0 — no career slot) ──
	"exh_barry": {
		"name": "Barry", "nickname": "THE BRICKLAYER", "level": 0,
		"scatter": 0.34, "double_hit_pct": 0.25, "throw_delay": 0.75,
		"game_mode": "countdown", "starting_score": 301,
		"image": "", "buy_in": 0, "prize_money": 0, "max_losses": 1,
		"dart_quality": 30, "base_confidence": 45, "base_anger": 20, "anger_rate": 0.8,
		"legs_to_win": 1,
	},
	"exh_donna": {
		"name": "Donna", "nickname": "THE DUCHESS", "level": 0,
		"scatter": 0.30, "double_hit_pct": 0.30, "throw_delay": 0.65,
		"game_mode": "countdown", "starting_score": 301,
		"image": "", "buy_in": 0, "prize_money": 0, "max_losses": 1,
		"dart_quality": 40, "base_confidence": 55, "base_anger": 10, "anger_rate": 0.5,
		"legs_to_win": 1,
	},
	"exh_slim": {
		"name": "Slim", "nickname": "THE NEEDLE", "level": 0,
		"scatter": 0.28, "double_hit_pct": 0.35, "throw_delay": 0.6,
		"game_mode": "countdown", "starting_score": 301,
		"image": "", "buy_in": 0, "prize_money": 0, "max_losses": 1,
		"dart_quality": 45, "base_confidence": 50, "base_anger": 15, "anger_rate": 1.0,
		"legs_to_win": 1,
	},
	"exh_tank": {
		"name": "Tank", "nickname": "THE BULLDOZER", "level": 0,
		"scatter": 0.36, "double_hit_pct": 0.20, "throw_delay": 0.85,
		"game_mode": "countdown", "starting_score": 301,
		"image": "", "buy_in": 0, "prize_money": 0, "max_losses": 1,
		"dart_quality": 25, "base_confidence": 40, "base_anger": 35, "anger_rate": 1.5,
		"legs_to_win": 1,
	},
	"exh_fingers": {
		"name": "Fingers", "nickname": "THE MAGICIAN", "level": 0,
		"scatter": 0.25, "double_hit_pct": 0.40, "throw_delay": 0.55,
		"game_mode": "countdown", "starting_score": 301,
		"image": "", "buy_in": 0, "prize_money": 0, "max_losses": 1,
		"dart_quality": 50, "base_confidence": 60, "base_anger": 5, "anger_rate": 0.4,
		"legs_to_win": 1,
	},
}

# Character-specific venues for levels 1-3 (keyed by DartData.Character index)
# Each character plays through their local area before reaching the national circuit.
const LOCAL_VENUES := {
	# Dai "The Dragon" Davies — South Wales
	0: {
		1: "The Red Dragon, Pontypridd",
		2: "The Lamb & Flag, Merthyr Tydfil",
		3: "Valleys Social Club, Aberdare",
	},
	# Terry "The Hammer" Hoskins — East London
	1: {
		1: "The Blind Beggar, Bethnal Green",
		2: "The Nag's Head, Bow",
		3: "Dagenham & District Social Club",
	},
	# Rab "The Flame" McTavish — Dundee, Scotland
	2: {
		1: "The Braw Lad, Dundee",
		2: "The Auld Stag, Arbroath",
		3: "Tayside Working Men's Club, Perth",
	},
	# Siobhan "The Banshee" O'Hara — Belfast
	3: {
		1: "The Crown Bar, Belfast",
		2: "The Harp & Crown, Lisburn",
		3: "Falls Road Social Club, Belfast",
	},
}

# Ordered list of opponent IDs for menu display
const OPPONENT_ORDER: Array[String] = [
	"big_kev", "derek", "steve", "philip", "mad_dog", "lars", "vinnie",
]

static func get_opponent(id: String) -> Dictionary:
	return OPPONENTS[id]

static func get_display_name(id: String) -> String:
	return OPPONENTS[id]["name"]

static func get_nickname(id: String) -> String:
	return OPPONENTS[id]["nickname"]

static func get_scatter(id: String) -> float:
	return OPPONENTS[id]["scatter"]

static func get_double_hit_pct(id: String) -> float:
	return OPPONENTS[id]["double_hit_pct"]

static func get_throw_delay(id: String) -> float:
	return OPPONENTS[id]["throw_delay"]

## Get the venue name for a given opponent and character.
## Levels 1-3 use character-specific local venues.
## Level 4+ use the shared venue from the opponent data.
static func get_venue(id: String, character_index: int) -> String:
	var opp: Dictionary = OPPONENTS[id]
	var level: int = opp["level"]
	# Exhibition opponents use the venue from ExhibitionData
	if level == 0:
		return ExhibitionData.current_venue
	if level <= 3 and character_index in LOCAL_VENUES:
		var char_venues: Dictionary = LOCAL_VENUES[character_index]
		if level in char_venues:
			return char_venues[level]
	if opp.has("venue"):
		return opp["venue"]
	return ""

static func get_vibe(id: String) -> String:
	return OPPONENTS[id].get("vibe", "")

static func get_image(id: String) -> String:
	return OPPONENTS[id].get("image", "")

## Get the RTC scatter for this opponent, adjusted for rubber-banding.
## lead: how far ahead the AI is (positive = AI leading, negative = AI behind)
## Returns a Gaussian scatter radius in board units.
static func get_rtc_scatter(id: String, lead: int) -> float:
	var opp: Dictionary = OPPONENTS[id]
	var base: float = opp.get("rtc_scatter", 0.22)
	if lead >= 5:
		# AI is cruising — widen scatter (more misses)
		return opp.get("rtc_scatter_ahead", base * 1.4)
	elif lead <= -5:
		# AI is behind — tighten scatter (more hits)
		return opp.get("rtc_scatter_behind", base * 0.7)
	else:
		return base

## Starting nerves value for the player when facing this opponent.
## Higher level = more pressure = higher starting nerves.
static func get_base_nerves(id: String) -> float:
	var level: int = OPPONENTS[id]["level"]
	match level:
		0: return 35.0   # Exhibition — relaxed, no stakes
		1: return 30.0   # Big Kev — friendly local, low pressure
		2: return 40.0   # Derek — Friday night tournament
		3: return 45.0   # Steve — regional, some crowd
		4: return 55.0   # Philip — county level, real pressure
		5: return 65.0   # Mad Dog — national qualifier, intense
		6: return 75.0   # Lars — world semi-final
		7: return 85.0   # Vinnie Gold — world final, maximum pressure
		_: return 50.0

static func get_dart_quality(id: String) -> int:
	return OPPONENTS[id].get("dart_quality", 50)

static func get_base_confidence(id: String) -> float:
	return float(OPPONENTS[id].get("base_confidence", 50))

static func get_base_anger(id: String) -> float:
	return float(OPPONENTS[id].get("base_anger", 10))

static func get_anger_rate(id: String) -> float:
	return OPPONENTS[id].get("anger_rate", 1.0)

static func get_prize_money(id: String) -> int:
	return OPPONENTS[id].get("prize_money", 0)

static func get_buy_in(id: String) -> int:
	return OPPONENTS[id].get("buy_in", 0)

static func get_max_losses(id: String) -> int:
	return OPPONENTS[id].get("max_losses", 3)

static func get_legs_to_win(id: String) -> int:
	if OPPONENTS[id]["level"] == 0:
		return ExhibitionData.get_legs_to_win()
	return OPPONENTS[id].get("legs_to_win", 1)

static func get_menu_label(id: String) -> String:
	var opp: Dictionary = OPPONENTS[id]
	if opp["game_mode"] == "rtc":
		return "vs " + opp["name"] + " (RTC)"
	else:
		var legs: int = opp.get("legs_to_win", 1)
		if legs <= 1:
			return "vs " + opp["name"] + " (" + str(opp["starting_score"]) + ")"
		var best_of: int = legs * 2 - 1
		return "vs " + opp["name"] + " (" + str(opp["starting_score"]) + ", Best of " + str(best_of) + ")"
