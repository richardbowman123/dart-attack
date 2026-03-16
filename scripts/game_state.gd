extends Node

enum GameMode { ROUND_THE_CLOCK, COUNTDOWN, TUTORIAL, FREE_THROW }

const SETTINGS_PATH := "user://settings.cfg"

var game_mode: GameMode = GameMode.COUNTDOWN
var starting_score: int = 501  # Only used for COUNTDOWN mode
var character: DartData.Character = DartData.Character.DAI
var dart_tier: int = 0
var tutorial_completed: bool = false
var throw_tip_dismissed: bool = false

# VS AI mode
var is_vs_ai: bool = false
var opponent_id: String = ""

# Match result (transient — set before navigating to results screen)
var match_won: bool = false
var match_prize: int = 0
var match_career_over: bool = false

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		throw_tip_dismissed = config.get_value("tips", "throw_tip_dismissed", false)

func dismiss_throw_tip() -> void:
	throw_tip_dismissed = true
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("tips", "throw_tip_dismissed", true)
	config.save(SETTINGS_PATH)
