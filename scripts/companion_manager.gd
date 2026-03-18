extends Node

## CompanionManager — autoload that orchestrates companion dialogue.
##
## Usage from game code:
##   CompanionManager.request_dialogue("PRE_MATCH", {"first_time": true})
##   CompanionManager.show_debrief(true)  # true = player won
##
## The manager checks for matching interactive exchanges first, then
## falls back to broadcast dialogue. It handles follow-up sequences,
## consequence dispatch, and repetition avoidance.

signal dialogue_started(trigger: String)
signal dialogue_finished(trigger: String)
signal consequence_triggered(consequence_id: String)

# ---- Companion stage (0-5). Default to barman. ----

var companion_stage: int = 0

# ---- Internal ----

var _panel: CompanionPanel
var _recently_used: Dictionary = {}  # "key" -> last used index
var _follow_up_queue: Array = []
var _current_trigger := ""
var _pending_consequence := ""

# =====================================================================
# LIFECYCLE
# =====================================================================

func _ready() -> void:
	_panel = CompanionPanel.new()
	add_child(_panel)
	_panel.broadcast_finished.connect(_on_panel_broadcast_finished)
	_panel.response_chosen.connect(_on_panel_response_chosen)

# =====================================================================
# PUBLIC API
# =====================================================================

## Request dialogue for a trigger. Checks interactive first, then
## broadcast. Returns true if dialogue was shown.
func request_dialogue(trigger: String, context: Dictionary = {}) -> bool:
	if _panel._state != CompanionPanel.PanelState.IDLE:
		return false  # Already showing something

	_current_trigger = trigger

	# Try interactive exchange first
	var exchange := _find_interactive(trigger, context)
	if exchange.size() > 0:
		_show_exchange(exchange)
		dialogue_started.emit(trigger)
		return true

	# Fall back to broadcast
	return _show_broadcast_for_trigger(trigger, context)

## Show post-match debrief. Combines a win/loss comment with a
## randomly weighted training directive.
func show_debrief(player_won: bool) -> void:
	if _panel._state != CompanionPanel.PanelState.IDLE:
		return

	_current_trigger = CompanionData.BETWEEN_ROUND
	var stage := companion_stage

	# Pick a win/loss comment
	var pool: Dictionary = CompanionData.DEBRIEF_WIN if player_won else CompanionData.DEBRIEF_LOSS
	var comments: Array = pool.get(stage, ["Good game."])
	var comment: String = _pick_random(comments, "debrief_%d_%s" % [stage, "win" if player_won else "loss"])

	# Pick a directive
	var directives := CompanionData.DEBRIEF_DIRECTIVES
	var directive: Dictionary = directives[randi() % directives.size()]
	var directive_text: String = directive["text"]
	# TODO: wire directive["stat"] to PlayerStats signals

	# Queue the directive as a follow-up after the main comment
	_follow_up_queue = [directive_text]

	var speaker := _get_speaker_name(stage)
	_panel.show_broadcast(speaker, comment, stage)
	dialogue_started.emit(CompanionData.BETWEEN_ROUND)

## Show a checkout hint for the given remaining score.
func show_checkout_hint(score: int) -> void:
	if _panel._state != CompanionPanel.PanelState.IDLE:
		return

	_current_trigger = CompanionData.CHECKOUT_HINT
	var stage := companion_stage
	var key := "%d_%s" % [stage, CompanionData.CHECKOUT_HINT]
	var lines: Array = CompanionData.BROADCAST.get(key, [])

	if lines.is_empty():
		return

	var raw_line: String = _pick_random(lines, key)
	var formatted := CompanionData.format_checkout_hint(raw_line, score)

	var speaker := _get_speaker_name(stage)
	_panel.show_broadcast(speaker, formatted, stage)
	dialogue_started.emit(CompanionData.CHECKOUT_HINT)

# =====================================================================
# DIALOGUE SELECTION
# =====================================================================

func _show_broadcast_for_trigger(trigger: String, context: Dictionary) -> bool:
	var stage := companion_stage
	var key := "%d_%s" % [stage, trigger]

	# Check for anger-aware variant
	# TODO: wire to PlayerStats.PlayerAnger — if > 0.6, use ANGRY variant
	var player_anger := 0.0  # placeholder
	var lines: Array = []
	if player_anger > 0.6 and CompanionData.ANGRY_BROADCAST.has(key):
		lines = CompanionData.ANGRY_BROADCAST[key]
	elif CompanionData.BROADCAST.has(key):
		lines = CompanionData.BROADCAST[key]

	if lines.is_empty():
		return false

	var line: String = _pick_random(lines, key)

	# Handle checkout hint formatting
	if trigger == CompanionData.CHECKOUT_HINT:
		var score: int = context.get("score", 0)
		line = CompanionData.format_checkout_hint(line, score)

	var speaker := _get_speaker_name(stage)
	_panel.show_broadcast(speaker, line, stage)
	dialogue_started.emit(trigger)
	return true

func _find_interactive(trigger: String, context: Dictionary) -> Dictionary:
	for exchange in CompanionData.INTERACTIVE_EXCHANGES:
		if exchange["trigger"] != trigger:
			continue
		if exchange["companion_stage"] != companion_stage:
			continue
		if not _check_condition(exchange.get("condition", ""), context):
			continue
		return exchange
	return {}

func _show_exchange(exchange: Dictionary) -> void:
	var speaker: String = exchange.get("speaker", _get_speaker_name(companion_stage))
	var prompt: String = exchange["prompt"]
	var responses: Array = exchange["responses"]

	var labels: Array = []
	for r in responses:
		labels.append(r["label"])

	# Store the exchange so we can handle the response
	set_meta("_current_exchange", exchange)

	_panel.show_interactive(speaker, prompt, labels, companion_stage)

# =====================================================================
# CONDITION CHECKING
# =====================================================================

func _check_condition(condition: String, context: Dictionary) -> bool:
	if condition == "" or condition == "always":
		return true
	match condition:
		"first_round_clock_game":
			return context.get("game_mode", "") == "round_the_clock" and context.get("first_time", false)
		"bad_loss":
			return context.get("loss_margin", 0) > 200
		"tough_opponent":
			return context.get("opponent_difficulty", 0) > 3
		"missed_checkout":
			return context.get("missed_checkout", false)
		"high_stakes":
			return context.get("high_stakes", false)
		"reached_18":
			return context.get("reached_18", false)
		"second_drink_offer":
			return context.get("second_drink_offer", false)
		"companion_round":
			return context.get("companion_round", false)
		"player_round":
			return context.get("player_round", false)
		"periodic":
			# Always valid when explicitly triggered
			return true
	# Unknown condition — default to false (safe)
	return false

# =====================================================================
# CONSEQUENCE HANDLING
# =====================================================================

func _handle_consequence(id: String) -> void:
	if id == "" or id == null:
		return
	# TODO: wire consequences to game flow
	# Known consequences:
	# "redirect_to_practice" — send player to practice mode
	# "add_free_drink" — DrinkManager.add_drink(free=true)
	# "deduct_money" — budget system (wire later)
	# "boost_confidence" — PlayerStats.Confidence (wire later)
	# "breathalyser_result" — see _resolve_dynamic_reply
	# "sponsorship_flag_set" — log for later progression system
	consequence_triggered.emit(id)

# =====================================================================
# DYNAMIC REPLY RESOLUTION
# =====================================================================

func _resolve_dynamic_reply(key: String) -> String:
	match key:
		"breathalyser_check":
			# TODO: read actual DrinkManager.drinks_level
			var drinks_level := 0  # placeholder
			if drinks_level <= 3:
				return "You're too sober. Get another in before the next round."
			elif drinks_level <= 7:
				return "You're in the zone. Perfect."
			else:
				return "You're over the top, mate. Lay off for a round."
	return "..."

# =====================================================================
# SIGNAL HANDLERS
# =====================================================================

func _on_panel_broadcast_finished() -> void:
	# Check for queued follow-up lines
	if _follow_up_queue.size() > 0:
		var next_line: String = _follow_up_queue.pop_front()
		var speaker := _get_speaker_name(companion_stage)
		_panel.show_broadcast(speaker, next_line, companion_stage)
		return

	# Fire consequence BEFORE dialogue_finished so game logic can set
	# flags (e.g. re-offer drink) that the finished handler checks.
	var trigger := _current_trigger
	_current_trigger = ""
	if _pending_consequence != "":
		_handle_consequence(_pending_consequence)
		_pending_consequence = ""

	dialogue_finished.emit(trigger)

func _on_panel_response_chosen(index: int) -> void:
	var exchange: Dictionary = get_meta("_current_exchange", {})
	if exchange.is_empty():
		return

	var responses: Array = exchange["responses"]
	if index < 0 or index >= responses.size():
		return

	var chosen: Dictionary = responses[index]

	# Resolve the reply text
	var reply_text: String
	if chosen.has("dynamic_reply") and chosen["dynamic_reply"] != "":
		reply_text = _resolve_dynamic_reply(chosen["dynamic_reply"])
	else:
		reply_text = chosen.get("reply", "...")

	# Queue follow-ups if any
	if chosen.has("follow_up"):
		_follow_up_queue = chosen["follow_up"].duplicate()

	# Store consequence to fire after panel dismissal
	_pending_consequence = chosen.get("consequence", "")

	# Show the reply as a typewriter sequence
	_panel.show_reply(reply_text)

# =====================================================================
# HELPERS
# =====================================================================

func _get_speaker_name(stage: int) -> String:
	return CompanionData.COMPANION_NAMES.get(stage, "???")

## Pick a random line from an array, avoiding the most recently used.
func _pick_random(lines: Array, key: String) -> String:
	if lines.is_empty():
		return ""
	if lines.size() == 1:
		return lines[0]

	var last_index: int = _recently_used.get(key, -1)
	var index := randi() % lines.size()

	# Re-roll once if we got the same line as last time
	if index == last_index:
		index = (index + 1) % lines.size()

	_recently_used[key] = index
	return lines[index]
