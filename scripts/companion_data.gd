class_name CompanionData
extends RefCounted

## =====================================================================
## COMPANION DIALOGUE DATA
## =====================================================================
##
## HOW TO ADD NEW CONTENT
## ----------------------
## This file is the single source of all companion dialogue. You can add
## new lines, new exchanges, and new triggers by editing this file only.
## No game logic code needs to change.
##
## BROADCAST DIALOGUE (companion speaks, player taps to continue):
##   Add a new entry to the BROADCAST dictionary. The key format is:
##       "STAGE_TRIGGER"
##   where STAGE is the companion stage number (0-5) and TRIGGER is one
##   of: PRE_MATCH, CHECKOUT_HINT, POST_WIN, POST_LOSS, BETWEEN_ROUND,
##   DRINK_OFFER. The value is an array of strings — one is picked at
##   random each time. Add as many variants as you like.
##
##   For CHECKOUT_HINT lines, use {score} and {route} placeholders.
##   The system replaces them with the actual score and route.
##
##   For anger-aware variants, add to ANGRY_BROADCAST with the same key
##   format. These are used when PlayerAnger is high (> 0.6).
##
## INTERACTIVE DIALOGUE (companion asks, player picks a response):
##   Copy an existing entry in INTERACTIVE_EXCHANGES and change:
##     - "id": a unique string identifier
##     - "trigger": when this fires (PRE_MATCH, POST_LOSS, etc.)
##     - "companion_stage": which stage (0-5)
##     - "speaker": display name in the panel
##     - "condition": a string the game checks (or "" for always)
##     - "prompt": what the companion says
##     - "responses": array of 2 choices, each with:
##         "label": button text
##         "reply": what the companion says after the choice
##         "consequence": string ID for game logic (or "" for none)
##         "follow_up": (optional) array of strings shown as sequential
##                      broadcasts after the reply
##         "dynamic_reply": (optional) string key — if present, the
##                          reply text is generated at runtime instead
##                          of using the static "reply" field
##
## DEBRIEF (post-match summary from companion):
##   Add to DEBRIEF_WIN or DEBRIEF_LOSS dictionaries (keyed by stage).
##   Add to DEBRIEF_DIRECTIVES to create new training suggestions.
##
## =====================================================================

# ---- Trigger type constants ----

const PRE_MATCH := "PRE_MATCH"
const CHECKOUT_HINT := "CHECKOUT_HINT"
const POST_WIN := "POST_WIN"
const POST_LOSS := "POST_LOSS"
const BETWEEN_ROUND := "BETWEEN_ROUND"
const DRINK_OFFER := "DRINK_OFFER"

# ---- Companion stage constants ----

const STAGE_BARMAN := 0
const STAGE_FRIEND := 1
const STAGE_FRIENDS := 2
const STAGE_COACH := 3
const STAGE_MANAGER := 4
const STAGE_FULL_TEAM := 5

# ---- Display names per stage ----

static var COMPANION_NAMES := {
	0: "Barman",
	1: "Alan",
	2: "Mates",
	3: "Coach",
	4: "Manager",
	5: "The Team",
}

# ---- Portrait colours per stage (fallback when no image exists) ----

static var PORTRAIT_COLORS := {
	0: Color(0.35, 0.25, 0.15),   # dark brown
	1: Color(0.2, 0.4, 0.7),      # blue
	2: Color(0.2, 0.5, 0.3),      # green
	3: Color(0.4, 0.4, 0.45),     # steel grey
	4: Color(0.6, 0.5, 0.15),     # gold
	5: Color(0.7, 0.2, 0.2),      # red
}

# ---- Portrait images per stage (empty string = use colour fallback) ----

static var PORTRAIT_IMAGES := {
	0: "res://Barman.jpg",
	1: "res://Mate for Level 2 - Alan.png",
	2: "res://Group of mates for Level 3 better trimmed.png",
	3: "res://Coach cropped.png",
	4: "res://Manager cropped.png",
	5: "res://Manager and full team cropped.png",
}

# =====================================================================
# BROADCAST DIALOGUE
# =====================================================================
# Key format: "stage_trigger" -> array of line variants.
# The system picks one at random, avoiding the most recently used.

static var BROADCAST := {
	# --- STAGE 0: BARMAN ---
	# Tone: dry, minimal, seen it all before
	"0_PRE_MATCH": [
		"Right. Board's free. Off you go.",
		"Don't take all night, will you.",
		"Your turn.\n\nTry not to hit the wall this time.",
	],
	"0_POST_WIN": [
		"Well. Didn't see that coming.",
		"Not bad.\n\nDon't let it go to your head.",
		"Right then.\n\nYou might not be completely useless.",
	],
	"0_POST_LOSS": [
		"Could've been worse.\n\nProbably.",
		"These things happen.\n\nTo you, mostly.",
		"Chin up.\n\nThere's always the fruit machine.",
	],
	"0_BETWEEN_ROUND": [
		"Decent enough. Get back out there.",
		"I've seen better. I've seen worse. Go on.",
		"You'll do. Barely.",
	],
	"0_DRINK_OFFER": [
		"You look like you need one. The usual?",
		"Same again? Or something stronger?",
		"Thirsty work, that. What'll it be?",
	],
	"0_CHECKOUT_HINT": [
		"You want {score}? Try {route}.",
		"{score} left? {route}. Don't overthink it.",
		"{score}. {route}. Simple enough.",
	],

	# --- STAGE 1: A FRIEND ---
	# Tone: enthusiastic, well-meaning, occasionally wrong
	"1_PRE_MATCH": [
		"Come on then! You've got this!",
		"Right, focus up mate. I believe in you.",
		"I've got a good feeling about this one.",
	],
	"1_POST_WIN": [
		"YES! Get in! I knew it!",
		"Absolute scenes! Drink's on me!",
		"Told you. Told everyone. Nobody listened.",
	],
	"1_POST_LOSS": [
		"Unlucky mate. Could've gone either way.",
		"Not your fault. He was lucky, that's all.",
		"Next time. Definitely next time.",
	],
	"1_BETWEEN_ROUND": [
		"You're doing alright! Keep it going!",
		"Mate, that was class. More of the same.",
		"Solid. Really solid. I think. Yeah.",
	],
	"1_DRINK_OFFER": [
		"Pint? My round. Go on.",
		"You deserve one after that.",
		"I'm getting one anyway. Want one?",
	],
	"1_CHECKOUT_HINT": [
		"Mate, {score} left! I reckon {route}. Yeah, that's right.",
		"{score}? Easy! Just go... {route}. I think.",
		"You need {score}. Try {route}. Or... no wait, yeah, do that.",
	],

	# --- STAGE 2: A FEW FRIENDS ---
	# Tone: louder, group energy, chaotic
	"2_PRE_MATCH": [
		"OI OI! Let's have it!",
		"We're all here mate. Don't let us down!",
		"The whole crew's watching. No pressure.",
	],
	"2_POST_WIN": [
		"GET IN THERE! Drinks all round!",
		"He's only gone and done it! LEGEND!",
		"That's our boy! Someone get the karaoke on!",
	],
	"2_POST_LOSS": [
		"Referee! That was never a... wait, wrong sport.",
		"Doesn't matter. We're going to the kebab shop.",
		"Still the best player in this pub. Probably.",
	],
	"2_BETWEEN_ROUND": [
		"Keep going mate! We've got a chant ready!",
		"Looking good! Well, the darts are anyway.",
		"Another round like that and we'll carry you out!",
	],
	"2_DRINK_OFFER": [
		"We've got a kitty going. What are you having?",
		"Dave's buying. He doesn't know yet. What do you want?",
		"Three pints here already with your name on.",
	],

	# --- STAGE 3: COACH ---
	# Tone: precise, tactical, no warmth
	"3_PRE_MATCH": [
		"Stay in your zone. Don't get fancy.",
		"Stick to the plan. Twenty, twenty, twenty.",
		"Right. Remember what we drilled.",
	],
	"3_POST_WIN": [
		"Good. Clean performance.",
		"That's the standard. Maintain it.",
		"Not perfect. But it'll do for now.",
	],
	"3_POST_LOSS": [
		"Sloppy. We'll fix it in practice.",
		"Analyse what went wrong. Don't repeat it.",
		"Not good enough. You know it. I know it.",
	],
	"3_BETWEEN_ROUND": [
		"Scoring's solid. Work on your doubles.",
		"Your grouping was off in that leg. Tighten up.",
		"Focus. Breathe. Throw. Nothing else matters.",
	],
	"3_CHECKOUT_HINT": [
		"{score}. {route}. No hesitation.",
		"You should know this. {score}: {route}.",
		"{score} remaining. {route}. We practised this.",
	],
	"3_DRINK_OFFER": [
		"One. Steady the nerves. No more.",
		"Have one. Then focus.",
		"You look tense. Have a quick one.",
	],

	# --- STAGE 4: MANAGER ---
	# Tone: money, sponsorship, his own reputation
	"4_PRE_MATCH": [
		"Big crowd tonight. Don't let them down.",
		"I've told the sponsors you're going to shine.",
		"Money's on you tonight. Literally.",
	],
	"4_POST_WIN": [
		"That's what I like to see. Phones are ringing.",
		"Beautiful. The brand just went up ten percent.",
		"Winner winner. Let me make some calls.",
	],
	"4_POST_LOSS": [
		"Not what the sponsors want to see.",
		"I'll handle the press. You sort yourself out.",
		"This is costing us. Both of us.",
	],
	"4_BETWEEN_ROUND": [
		"The cameras are watching. Look sharp.",
		"Viewing figures are up. Don't blow it now.",
		"Decent. The sponsors seem happy. Keep going.",
	],
	"4_DRINK_OFFER": [
		"I'm buying. Call it an investment.",
		"Have whatever you want. It's on expenses.",
		"One drink. The sponsors like you relaxed, not legless.",
	],

	# --- STAGE 5: FULL TEAM ---
	# Tone: mixed — team collective, occasionally the medic
	"5_PRE_MATCH": [
		"The whole team's behind you. Let's do this.",
		"Everyone's in position. You just throw.",
		"We've done the prep. Now it's your turn.",
	],
	"5_POST_WIN": [
		"Outstanding. The whole setup paid off.",
		"That's what a proper team delivers.",
		"Job done. Everyone did their bit tonight.",
	],
	"5_POST_LOSS": [
		"We'll regroup. That's what the team is for.",
		"It's a team effort. We all take the hit.",
		"Back to the drawing board. Together.",
	],
	"5_BETWEEN_ROUND": [
		"Stats are looking good. Keep your rhythm.",
		"The data says you're in range. Trust the process.",
		"Everything's tracking. Stay the course.",
	],
	"5_DRINK_OFFER": [
		"The rider's got refreshments. Help yourself.",
		"Green room's stocked. Take a quick one.",
		"The team says hydrate. They mean beer.",
	],
}

# =====================================================================
# ANGER-AWARE BROADCAST VARIANTS
# =====================================================================
# Used when PlayerAnger > 0.6. Same key format as BROADCAST.
# If no angry variant exists for a trigger, the normal line is used.

static var ANGRY_BROADCAST := {
	# --- BARMAN ---
	"0_POST_LOSS": [
		"Oi. Calm it down. You break anything, you're paying for it.",
		"Deep breath. It's only a game. Allegedly.",
	],
	"0_PRE_MATCH": [
		"Leave whatever happened last round outside. Focus.",
		"You're wound up. I can tell. Take a breath first.",
	],

	# --- FRIEND ---
	"1_POST_LOSS": [
		"Mate, MATE. Calm down. It's not worth it.",
		"I know, I know. But smashing things won't help.",
	],
	"1_PRE_MATCH": [
		"Deep breaths yeah? Channel the anger into the darts.",
		"Use it. But don't let it use you. If that makes sense.",
	],

	# --- COACH ---
	"3_POST_LOSS": [
		"Control yourself. Emotion is the enemy of precision.",
		"That temper cost you the last leg. Don't let it cost another.",
	],
	"3_PRE_MATCH": [
		"I need you cold. Ice cold. Whatever happened, park it.",
		"Anger makes you fast but it makes you sloppy. Drop it.",
	],

	# --- MANAGER ---
	"4_POST_LOSS": [
		"Keep it together. The cameras are on you.",
		"You lose your head, you lose the sponsors. Smile.",
	],
}

# =====================================================================
# INTERACTIVE EXCHANGES
# =====================================================================
# Each exchange is a small branching dialogue. The player picks a
# response and the companion reacts. Consequences are string IDs
# handled by game logic.
#
# To add a new exchange: copy one below, give it a unique "id",
# set the trigger/stage/condition, write the prompt and responses.
# That's it. No other code changes needed.

static var INTERACTIVE_EXCHANGES: Array = [
	# --- BARMAN: Rules check (before first Round the Clock) ---
	{
		"id": "barman_rules_check",
		"trigger": PRE_MATCH,
		"companion_stage": 0,
		"speaker": "Barman",
		"condition": "first_round_clock_game",
		"prompt": "You know the rules of Round the Clock, yeah?",
		"responses": [
			{
				"label": "Yeah, course.",
				"reply": "Good. Get up there then.",
				"consequence": "",
			},
			{
				"label": "Not really...",
				"reply": "Back to the practice board with you. Come find me when you're ready.",
				"consequence": "redirect_to_practice",
			},
		],
	},

	# --- BARMAN: Consolation drink (after bad loss) ---
	{
		"id": "barman_consolation",
		"trigger": POST_LOSS,
		"companion_stage": 0,
		"speaker": "Barman",
		"condition": "bad_loss",
		"prompt": "Want me to get you something stronger?",
		"responses": [
			{
				"label": "Yeah, go on.",
				"reply": "Thought so.",
				"consequence": "add_free_drink",
			},
			{
				"label": "Nah, I'm alright.",
				"reply": "Suit yourself. Probably wise.",
				"consequence": "",
			},
		],
	},

	# --- FRIEND: Scouting report (before tough opponent) ---
	{
		"id": "friend_scouting",
		"trigger": PRE_MATCH,
		"companion_stage": 1,
		"speaker": "Alan",
		"condition": "tough_opponent",
		"prompt": "Mate, I've seen this bloke play. Want me to talk you through his weaknesses?",
		"responses": [
			{
				"label": "Yeah, go on then.",
				"reply": "Right, listen up...",
				"consequence": "boost_confidence",
				"follow_up": [
					"He always starts with 19s. Weird habit, but there it is.",
					"His doubles are shaky under pressure. Make him work for every checkout.",
					"Keep the pressure on early and he'll crack. Trust me.",
				],
			},
			{
				"label": "Nah, I'm good.",
				"reply": "Fair enough. Thought you'd want the edge but what do I know.",
				"consequence": "",
			},
		],
	},

	# --- COACH: Checkout coaching (after missed checkout) ---
	{
		"id": "coach_checkout_tips",
		"trigger": POST_LOSS,
		"companion_stage": 3,
		"speaker": "Coach",
		"condition": "missed_checkout",
		"prompt": "That checkout cost you the leg. Want to go over the optimal routes for common finishes?",
		"responses": [
			{
				"label": "Go on then.",
				"reply": "Right. Listen carefully.",
				"consequence": "boost_confidence",
				"follow_up": [
					"On 170, it's treble 20, treble 20, bull. The big fish.",
					"On 140, go treble 20, treble 20, double 10. Clean and simple.",
					"And on 100, just treble 20, double 20. Don't overthink it.",
					"Learn the routes. Then it's just execution.",
				],
			},
			{
				"label": "I know what I'm doing.",
				"reply": "Your call. Just don't miss it again.",
				"consequence": "",
			},
		],
	},

	# --- MANAGER: Sponsorship offer (before high-stakes round) ---
	{
		"id": "manager_sponsorship",
		"trigger": PRE_MATCH,
		"companion_stage": 4,
		"speaker": "Manager",
		"condition": "high_stakes",
		"prompt": "I've had a word with a few people. There's a sponsorship opportunity if you win tonight. Want me to put your name forward?",
		"responses": [
			{
				"label": "Do it.",
				"reply": "Consider it done. Don't embarrass me.",
				"consequence": "sponsorship_flag_set",
			},
			{
				"label": "Not interested.",
				"reply": "Leaving money on the table. Your funeral.",
				"consequence": "",
			},
		],
	},

	# --- BARMAN: First drink at 18 (Round the Clock tradition) ---
	{
		"id": "barman_drink_at_18",
		"trigger": DRINK_OFFER,
		"companion_stage": 0,
		"speaker": "Barman",
		"condition": "reached_18",
		"prompt": "Getting to the final stages now.\n\nYou look like you're getting nervy.\n\nHave a pint on me to settle the nerves.",
		"responses": [
			{
				"label": "Yes",
				"reply": "That'll calm you down.",
				"consequence": "add_half_pint",
			},
			{
				"label": "No",
				"reply": "Fair enough. Your choice.",
				"consequence": "",
			},
		],
	},

	# --- BARMAN: Second drink offer (after next visit post-first-drink) ---
	{
		"id": "barman_second_drink",
		"trigger": DRINK_OFFER,
		"companion_stage": 0,
		"speaker": "Barman",
		"condition": "second_drink_offer",
		"prompt": "Another.\n\nYou're paying this time.",
		"responses": [
			{
				"label": "No thanks",
				"reply": "Fair enough. Worth asking.",
				"consequence": "",
			},
			{
				"label": "Half pint",
				"reply": "Coming right up.",
				"consequence": "buy_half_pint",
			},
			{
				"label": "Full pint",
				"reply": "Don't think £3.40 is going to cover that, mate.",
				"consequence": "reject_full_pint",
			},
		],
	},

	# --- ALAN: Companion's round (L2) ---
	{
		"id": "mate_companion_round",
		"trigger": DRINK_OFFER,
		"companion_stage": 1,
		"speaker": "Alan",
		"condition": "companion_round",
		"prompt": "My round. Pint?",
		"responses": [
			{"label": "Go on then", "reply": "That's the spirit.", "consequence": "accept_free_pint"},
			{"label": "I'm alright", "reply": "More for me then.", "consequence": ""},
		],
	},
	# --- ALAN: Player's round (L2) ---
	{
		"id": "mate_player_round",
		"trigger": DRINK_OFFER,
		"companion_stage": 1,
		"speaker": "Alan",
		"condition": "player_round",
		"prompt": "Your round, I think.",
		"responses": [
			{"label": "Fair enough", "reply": "Legend.", "consequence": "buy_round"},
			{"label": "I'm skint", "reply": "Tight. Fine.", "consequence": ""},
		],
	},
	# --- MATES: Companion's round (L3) ---
	{
		"id": "lads_companion_round",
		"trigger": DRINK_OFFER,
		"companion_stage": 2,
		"speaker": "Mates",
		"condition": "companion_round",
		"prompt": "Dave's getting them in. Want one?",
		"responses": [
			{"label": "Yeah go on", "reply": "PINT FOR THE PLAYER!", "consequence": "accept_free_pint"},
			{"label": "Nah I'm good", "reply": "More for Dave.", "consequence": ""},
		],
	},
	# --- MATES: Player's round (L3) ---
	{
		"id": "lads_player_round",
		"trigger": DRINK_OFFER,
		"companion_stage": 2,
		"speaker": "Mates",
		"condition": "player_round",
		"prompt": "Your round, mate. Four pints.",
		"responses": [
			{"label": "Get them in", "reply": "That's the spirit! FOUR PINTS!", "consequence": "buy_round"},
			{"label": "Not this time", "reply": "Booooo!", "consequence": ""},
		],
	},
	# --- COACH: Companion's round (L4) ---
	{
		"id": "coach_companion_round",
		"trigger": DRINK_OFFER,
		"companion_stage": 3,
		"speaker": "Coach",
		"condition": "companion_round",
		"prompt": "Have one. Steady the nerves. On me.",
		"responses": [
			{"label": "Cheers", "reply": "Don't make me regret it.", "consequence": "accept_free_pint"},
			{"label": "No thanks", "reply": "Suit yourself.", "consequence": ""},
		],
	},
	# --- COACH: Player's round (L4) ---
	{
		"id": "coach_player_round",
		"trigger": DRINK_OFFER,
		"companion_stage": 3,
		"speaker": "Coach",
		"condition": "player_round",
		"prompt": "Get me one while you're up.",
		"responses": [
			{"label": "On it", "reply": "Just the one. Focus.", "consequence": "buy_round"},
			{"label": "Later", "reply": "Fine. Concentrate.", "consequence": ""},
		],
	},
	# --- MANAGER: Companion's round (L5) ---
	{
		"id": "manager_companion_round",
		"trigger": DRINK_OFFER,
		"companion_stage": 4,
		"speaker": "Manager",
		"condition": "companion_round",
		"prompt": "I'm buying. The sponsors like you relaxed.",
		"responses": [
			{"label": "Don't mind if I do", "reply": "That's my player.", "consequence": "accept_free_pint"},
			{"label": "Not now", "reply": "Your call.", "consequence": ""},
		],
	},
	# --- MANAGER: Player's round (L5) ---
	{
		"id": "manager_player_round",
		"trigger": DRINK_OFFER,
		"companion_stage": 4,
		"speaker": "Manager",
		"condition": "player_round",
		"prompt": "Your shout. And get one for me.",
		"responses": [
			{"label": "Sure", "reply": "On expenses. Naturally.", "consequence": "buy_round"},
			{"label": "Maybe later", "reply": "Probably wise.", "consequence": ""},
		],
	},
	# --- FULL TEAM: Companion's round (L6-7) ---
	{
		"id": "team_companion_round",
		"trigger": DRINK_OFFER,
		"companion_stage": 5,
		"speaker": "The Team",
		"condition": "companion_round",
		"prompt": "The rider's got you covered. What'll it be?",
		"responses": [
			{"label": "Pint please", "reply": "Coming right up.", "consequence": "accept_free_pint"},
			{"label": "I'll pass", "reply": "Noted.", "consequence": ""},
		],
	},
	# --- FULL TEAM: Player's round (L6-7) ---
	{
		"id": "team_player_round",
		"trigger": DRINK_OFFER,
		"companion_stage": 5,
		"speaker": "The Team",
		"condition": "player_round",
		"prompt": "Your round. The team's waiting.",
		"responses": [
			{"label": "Round coming up", "reply": "The team appreciates it.", "consequence": "buy_round"},
			{"label": "Not right now", "reply": "Fair enough.", "consequence": ""},
		],
	},

	# --- MEDIC: Breathalyser (periodic, between rounds) ---
	{
		"id": "medic_breathalyser",
		"trigger": BETWEEN_ROUND,
		"companion_stage": 5,
		"speaker": "Medic",
		"condition": "periodic",
		"prompt": "Want me to do a quick breathalyser? I can tell you if you're at peak fighting level.",
		"responses": [
			{
				"label": "Yeah, go on.",
				"reply": "",
				"dynamic_reply": "breathalyser_check",
				"consequence": "breathalyser_result",
			},
			{
				"label": "I'm fine.",
				"reply": "Suit yourself. Don't blame me if you're off.",
				"consequence": "",
			},
		],
	},
]

# =====================================================================
# CHECKOUT ROUTES
# =====================================================================
# Common darts checkouts. Used to fill {route} in CHECKOUT_HINT lines.
# Key = remaining score, value = shorthand route.

static var CHECKOUT_ROUTES := {
	170: "T20, T20, Bull",
	167: "T20, T19, Bull",
	164: "T20, T18, Bull",
	160: "T20, T20, D20",
	141: "T20, T19, D12",
	140: "T20, T20, D10",
	136: "T20, T20, D8",
	121: "T20, T11, D14",
	120: "T20, 20, D20",
	100: "T20, D20",
	96: "T20, D18",
	80: "T20, D10",
	72: "T20, D6",
	64: "T16, D8",
	60: "20, D20",
	56: "T16, D4",
	50: "18, D16",
	40: "D20",
	36: "D18",
	32: "D16",
	24: "D12",
	20: "D10",
	16: "D8",
	8: "D4",
	4: "D2",
	2: "D1",
}

# =====================================================================
# DEBRIEF DIALOGUE
# =====================================================================
# Shown after each match. Keyed by stage.

static var DEBRIEF_WIN := {
	0: [
		"Not bad. You might have a future in this.",
		"Right then. You earned that one.",
		"Well well. The kid can actually play.",
	],
	1: [
		"MATE! You smashed it! That was incredible!",
		"I am buzzing for you right now. Seriously.",
		"You absolute legend. Drinks on me. All night.",
	],
	2: [
		"GET IN! Your mates are going mental!",
		"We always knew! Well, Dave had doubts, but the rest of us!",
	],
	3: [
		"Good result. But there's still work to do.",
		"Adequate. Your scoring was strong but finishing needs polish.",
		"That's the minimum standard. Don't celebrate yet.",
	],
	4: [
		"Beautiful. I'll have the contracts drawn up by morning.",
		"That's what I like to see. The phone's already ringing.",
		"Winner winner. Let me take some meetings.",
	],
	5: [
		"The whole team delivered tonight. Professional job.",
		"That's what proper preparation looks like.",
	],
}

static var DEBRIEF_LOSS := {
	0: [
		"Unlucky. Or maybe just not good enough. Hard to tell.",
		"Happens to the best. And to you as well.",
		"Another one bites the dust. Drink?",
	],
	1: [
		"Mate... gutted for you. Genuinely. He was lucky though.",
		"Don't beat yourself up. Well, do a bit. But then move on.",
		"Unlucky. You'll smash it next time. I know it.",
	],
	2: [
		"Ah. Well. Kebab shop it is then.",
		"We still love you mate! Even if you're terrible!",
	],
	3: [
		"Unacceptable. We're training doubles until you can't see straight.",
		"Sloppy. I expected more. We'll fix it.",
		"That performance tells me exactly what we need to work on.",
	],
	4: [
		"The sponsors won't like this. Neither do I.",
		"I'll handle the press. You handle your game.",
		"Costly night. For both of us.",
	],
	5: [
		"We'll regroup. The data shows where it went wrong.",
		"Losses happen. What matters is the response.",
	],
}

# Post-match directives — companion tells you what to work on.
# Each has display text and a stat key for future wiring.

static var DEBRIEF_DIRECTIVES: Array = [
	{
		"text": "Get on the practice board. Your technique needs sharpening.",
		"stat": "skill",
		# TODO: wire to PlayerStats.Skill boost
	},
	{
		"text": "You need to bulk up. A heavier throw would help.",
		"stat": "heft",
		# TODO: wire to heft progression
	},
	{
		"text": "Bit of bling never hurt anyone. The crowd needs something to cheer about.",
		"stat": "confidence",
		# TODO: wire to Confidence/crowd boost
	},
]

# =====================================================================
# HELPER — look up a checkout route for a given score
# =====================================================================

static func get_checkout_route(score: int) -> String:
	if CHECKOUT_ROUTES.has(score):
		return CHECKOUT_ROUTES[score]
	# Generic fallback for unlisted scores
	if score <= 40 and score % 2 == 0:
		return "D" + str(score / 2)
	return "work it down and find a double"

# =====================================================================
# HELPER — format a checkout hint line with actual score and route
# =====================================================================

static func format_checkout_hint(line: String, score: int) -> String:
	var route := get_checkout_route(score)
	return line.replace("{score}", str(score)).replace("{route}", route)
