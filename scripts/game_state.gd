extends Node

enum GameMode { ROUND_THE_CLOCK, COUNTDOWN }

var game_mode: GameMode = GameMode.COUNTDOWN
var starting_score: int = 501  # Only used for COUNTDOWN mode
