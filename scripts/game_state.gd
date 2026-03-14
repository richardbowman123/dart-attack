extends Node

enum GameMode { ROUND_THE_CLOCK, COUNTDOWN, TUTORIAL }

var game_mode: GameMode = GameMode.COUNTDOWN
var starting_score: int = 501  # Only used for COUNTDOWN mode
var character: DartData.Character = DartData.Character.DAI
var dart_tier: int = 0
