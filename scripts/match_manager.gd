extends Node3D
class_name MatchManager

enum MatchState { THROWING, BETWEEN_DARTS, VISIT_SUMMARY, CLEARING, AI_THROWING, FINISHED }

const DARTS_PER_VISIT := 3
const BETWEEN_DART_DELAY := 0.2
const SUMMARY_DISPLAY_TIME := 2.0
const AI_SUMMARY_DISPLAY_TIME := 1.5
const CONFIDENCE_DECAY_RATE := 0.5    # Points lost per second while aiming
const CONFIDENCE_DECAY_INTERVAL := 1.0 # Seconds between ticks

var _state: MatchState = MatchState.THROWING
var _darts_this_visit: int = 0
var _active_darts: Array[Dart] = []
var _visit_dart_labels: Array = []

# ── Countdown mode state (player) ──
var _score_remaining: int = 501
var _visit_score: int = 0
var _visit_score_before: int = 501

# ── Round the Clock state (player) ──
# Target goes 1..20 then 21=outer bull, 22=bullseye. Done when > 22.
var _rtc_target: int = 1
var _rtc_hits_this_visit: Array = []  # What numbers were ticked off this visit

# ── VS AI state ──
var _is_vs_ai := false
var _is_player_turn := true
var _opponent_id := ""

# Opponent scoring (countdown)
var _opp_score_remaining: int = 501
var _opp_visit_score: int = 0
var _opp_visit_score_before: int = 501

# Opponent scoring (RTC)
var _opp_rtc_target: int = 1
var _opp_rtc_hits_this_visit: Array = []

# AI throw sequencing
var _ai_darts_thrown: int = 0
var _ai_turn_tween: Tween

# ── Career mode stats (only active when CareerState.career_mode_active) ──
var _player_nerves: float = 50.0
var _player_confidence: float = 50.0
var _player_dart_quality: float = 0.0
var _player_anger: float = 0.0
var _drinks_this_match: int = 0

# ── Opponent stats (career mode) ──
var _opp_dart_quality: float = 0.0
var _opp_nerves: float = 50.0
var _opp_confidence: float = 50.0
var _opp_anger: float = 0.0
var _opp_anger_rate: float = 1.0

var _dartboard: Dartboard
var _throw_system: ThrowSystem
var _camera_rig: CameraRig
var _score_hud: ScoreHUD
var _darts_container: Node3D
var _tutorial_overlay: TutorialOverlay
var _tutorial_last_was_hit := false

# Confidence decay while aiming
var _confidence_decay_timer: float = 0.0
var _confidence_decay_active: bool = false

func _ready() -> void:
	_is_vs_ai = GameState.is_vs_ai
	_opponent_id = GameState.opponent_id
	_setup_environment()
	_build_scene()
	_connect_signals()
	_init_game_mode()
	_start_visit()

func _process(delta: float) -> void:
	if not _confidence_decay_active:
		return
	_confidence_decay_timer += delta
	if _confidence_decay_timer >= CONFIDENCE_DECAY_INTERVAL:
		_confidence_decay_timer -= CONFIDENCE_DECAY_INTERVAL
		_apply_confidence_decay()

func _start_confidence_decay() -> void:
	if not CareerState.career_mode_active:
		return
	_confidence_decay_timer = 0.0
	_confidence_decay_active = true

func _stop_confidence_decay() -> void:
	_confidence_decay_active = false

func _apply_confidence_decay() -> void:
	_player_confidence = clampf(_player_confidence - CONFIDENCE_DECAY_RATE, 0.0, 100.0)
	_score_hud.update_stats_bars(_player_dart_quality, _player_nerves, _player_confidence, _player_anger)
	# Update scatter multiplier in real time so the next dart uses decayed value
	_throw_system.career_scatter_mult = get_career_scatter_mult()

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.4, 0.45)
	env.ambient_light_energy = 0.8

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# LED oche lighting — bright spots from above and below for even coverage.
	# Three main spots from above (like TV darts), plus two fill lights
	# from below to stop the bottom of the board looking too dark.
	var spot_positions := [
		Vector3(0.0, 2.5, 2.5),    # Centre-above: main key light
		Vector3(-1.8, 2.0, 2.0),   # Left-above: fills left side
		Vector3(1.8, 2.0, 2.0),    # Right-above: fills right side
		Vector3(-1.2, -1.8, 2.0),  # Left-below: fills bottom-left wire
		Vector3(1.2, -1.8, 2.0),   # Right-below: fills bottom-right wire
	]
	var spot_energies := [2.5, 1.5, 1.5, 1.0, 1.0]

	for i in range(spot_positions.size()):
		var spot := SpotLight3D.new()
		spot.position = spot_positions[i]
		spot.look_at(Vector3(0, 0, 0), Vector3.UP)
		spot.light_energy = spot_energies[i]
		spot.light_color = Color(1.0, 0.97, 0.92)  # Bright daylight white
		spot.spot_range = 10.0
		spot.spot_angle = 45.0
		spot.shadow_enabled = true
		add_child(spot)

func _build_scene() -> void:
	_camera_rig = CameraRig.new()
	add_child(_camera_rig)

	_dartboard = Dartboard.new()
	add_child(_dartboard)

	_darts_container = Node3D.new()
	_darts_container.name = "Darts"
	add_child(_darts_container)

	_throw_system = ThrowSystem.new()
	var viewport_size := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	add_child(_throw_system)
	_throw_system.setup(_darts_container, viewport_size, _camera_rig.get_camera())
	_throw_system.set_dart_tier(GameState.dart_tier)

	# Set AI dart tier — one tier above the player, capped at 3 (premium tungsten).
	# Level 7 (final) opponent matches the player's tier.
	if _is_vs_ai:
		var opp_level: int = OpponentData.get_opponent(_opponent_id)["level"]
		if opp_level >= 7:
			_throw_system.ai_dart_tier = GameState.dart_tier
		else:
			_throw_system.ai_dart_tier = mini(GameState.dart_tier + 1, 3)

	_score_hud = ScoreHUD.new()
	add_child(_score_hud)

	# Career mode extras
	if CareerState.career_mode_active:
		# Deduct entry fee (buy-in) at match start
		if _is_vs_ai:
			var buy_in: int = OpponentData.get_buy_in(_opponent_id)
			if buy_in > 0:
				CareerState.money -= buy_in
		_score_hud.update_balance(CareerState.money)

func _connect_signals() -> void:
	_throw_system.dart_thrown.connect(_on_dart_thrown)
	_throw_system.throw_rejected.connect(_on_throw_rejected)
	_camera_rig.first_zoomed.connect(_on_first_zoom)
	if _is_tutorial():
		_setup_tutorial()

func _on_first_zoom() -> void:
	_score_hud.hide_zoom_hint_forever()

func _init_game_mode() -> void:
	if _is_countdown():
		_score_remaining = GameState.starting_score
		_visit_score_before = _score_remaining
		if _is_vs_ai:
			_opp_score_remaining = GameState.starting_score
			_opp_visit_score_before = _opp_score_remaining
	elif _is_tutorial():
		pass  # Tutorial state managed by TutorialOverlay
	else:
		_rtc_target = 1
		if _is_vs_ai:
			_opp_rtc_target = 1

	# Init career stats
	if CareerState.career_mode_active and _is_vs_ai:
		_player_nerves = OpponentData.get_base_nerves(_opponent_id)
		if CareerState.losses_at_current_level == 0:
			_player_confidence = 20.0  # First attempt at this level
		else:
			_player_confidence = CareerState.confidence_carry
		_player_dart_quality = _tier_to_quality(GameState.dart_tier)
		_player_anger = 0.0
		_drinks_this_match = 0

		# Opponent dart quality matches their actual dart tier (one above player, capped at 3)
		_opp_dart_quality = _tier_to_quality(_throw_system.ai_dart_tier)
		_opp_nerves = OpponentData.get_base_nerves(_opponent_id)
		_opp_confidence = OpponentData.get_base_confidence(_opponent_id)
		_opp_anger = OpponentData.get_base_anger(_opponent_id)
		_opp_anger_rate = OpponentData.get_anger_rate(_opponent_id)

	# Set up dual HUD if VS mode
	if _is_vs_ai:
		_score_hud.setup_vs_mode(_opponent_id)
		_score_hud.update_turn_indicator(true)
		if _is_countdown():
			_score_hud.update_opponent_score(_opp_score_remaining)
		else:
			_score_hud.update_opponent_remaining_text(_opp_rtc_target_label())

		# Show initial stats bars (player's stats first)
		if CareerState.career_mode_active:
			_score_hud.set_stats_owner("YOUR STATS")
			_score_hud.update_stats_bars(_player_dart_quality, _player_nerves, _player_confidence, _player_anger)

func _is_countdown() -> bool:
	return GameState.game_mode == GameState.GameMode.COUNTDOWN

func _is_rtc() -> bool:
	return GameState.game_mode == GameState.GameMode.ROUND_THE_CLOCK

func _is_tutorial() -> bool:
	return GameState.game_mode == GameState.GameMode.TUTORIAL

# ── Visit flow ──

func _start_visit() -> void:
	_darts_this_visit = 0
	_visit_dart_labels.clear()

	if _is_tutorial():
		_state = MatchState.THROWING
		var target: int = _tutorial_overlay.get_current_target()
		if target > 0:
			_score_hud.update_remaining_text("Hit: " + str(target))
		_score_hud.reset_dart_icons()
		_score_hud.hide_summary()
		# Don't enable throwing — the intro panel / Go button controls that
		_throw_system.set_can_throw(false)
		return

	if _is_player_turn or not _is_vs_ai:
		# Player's turn
		_state = MatchState.THROWING
		if _is_countdown():
			_visit_score = 0
			_visit_score_before = _score_remaining
			_score_hud.update_remaining(_score_remaining)
		else:
			_rtc_hits_this_visit.clear()
			_score_hud.update_remaining_text(_rtc_target_label())

		_score_hud.reset_dart_icons()
		_score_hud.hide_summary()

		# Set scatter multiplier from career stats before player throws
		if CareerState.career_mode_active:
			_throw_system.career_scatter_mult = get_career_scatter_mult()

		_throw_system.set_can_throw(true)
		_start_confidence_decay()
		DrinkManager.flash_tier_name()

		if _is_vs_ai:
			_score_hud.update_turn_indicator(true)
			if CareerState.career_mode_active:
				_show_player_stats()
	else:
		# AI's turn
		_start_ai_visit()

func _start_ai_visit() -> void:
	_stop_confidence_decay()
	_camera_rig.reset_view()
	_state = MatchState.AI_THROWING
	_darts_this_visit = 0
	_visit_dart_labels.clear()
	_ai_darts_thrown = 0
	_throw_system.set_can_throw(false)

	if _is_countdown():
		_opp_visit_score = 0
		_opp_visit_score_before = _opp_score_remaining
	else:
		_opp_rtc_hits_this_visit.clear()

	_score_hud.reset_dart_icons()
	_score_hud.hide_summary()
	_score_hud.update_turn_indicator(false)

	if CareerState.career_mode_active:
		_show_opponent_stats()

	# Start throwing sequence with delay
	var delay := OpponentData.get_throw_delay(_opponent_id)
	_ai_turn_tween = create_tween()
	_ai_turn_tween.tween_interval(delay * 0.5)  # Brief pause before first dart
	_ai_turn_tween.tween_callback(_ai_throw_next_dart)

func _ai_throw_next_dart() -> void:
	if _state != MatchState.AI_THROWING:
		return  # Turn was cancelled (bust/checkout)

	# Decide where to aim
	var game_mode_str := "countdown" if _is_countdown() else "rtc"
	var aim_score := _opp_score_remaining if _is_countdown() else 0
	var aim_rtc := _opp_rtc_target if _is_rtc() else 0
	var aim := AIBrain.choose_aim(game_mode_str, aim_score, aim_rtc)

	var target: Vector2

	if _is_rtc():
		# RTC: single natural scatter — no hit/miss branching.
		# The scatter radius determines how often darts land in the right
		# segment vs drift into neighbours or off the board. Rubber-banding
		# adjusts the scatter: tighter when behind, wider when ahead.
		var ai_progress := _opp_rtc_target
		var player_progress := _rtc_target
		var lead := player_progress - ai_progress  # positive = AI ahead
		var rtc_scatter := OpponentData.get_rtc_scatter(_opponent_id, lead)
		target = aim + AIBrain._gaussian_offset(rtc_scatter)
	else:
		# Countdown: use standard scatter + double_hit_pct system
		var aim_multiplier := 1
		if aim_score in AIBrain.CHECKOUTS:
			aim_multiplier = AIBrain.CHECKOUTS[aim_score][1]
		elif aim_score <= 40 and aim_score % 2 == 0:
			aim_multiplier = 2

		var scatter := OpponentData.get_scatter(_opponent_id)
		var double_pct := OpponentData.get_double_hit_pct(_opponent_id)
		target = AIBrain.apply_scatter(aim, scatter, double_pct, aim_multiplier)

	# Clamp to board area (allow some misses beyond the doubles ring)
	if target.length() > BoardData.BOARD_RADIUS * BoardData.SURROUND_R:
		target = target.normalized() * BoardData.BOARD_RADIUS * BoardData.SURROUND_R

	# Fire the dart
	_throw_system.do_ai_throw(target)

func _on_throw_rejected() -> void:
	# Don't show tip during tutorial (it has its own feedback) or if dismissed
	if _is_tutorial():
		return
	if GameState.throw_tip_dismissed:
		return
	_score_hud.show_throw_tip()

func _on_dart_thrown(dart: Dart) -> void:
	_stop_confidence_decay()
	_score_hud.on_dart_thrown(_darts_this_visit)
	dart.dart_hit.connect(_on_dart_hit.bind(dart))

func _on_dart_hit(score_data: Dictionary, hit_pos: Vector2, dart: Dart) -> void:
	_active_darts.append(dart)

	_darts_this_visit += 1

	# Show brief impact flash
	var screen_pos := Vector2(360 + hit_pos.x * 40, 400 - hit_pos.y * 40)
	var label_text: String = score_data.get("label", "Miss")
	_score_hud.show_impact(label_text, screen_pos)
	_visit_dart_labels.append(label_text)

	if _is_tutorial():
		_handle_tutorial_hit(score_data, hit_pos)
	elif _is_vs_ai and not _is_player_turn:
		# AI dart landed
		if _is_countdown():
			_handle_ai_countdown_hit(score_data)
		else:
			_handle_ai_rtc_hit(score_data)
	elif _is_countdown():
		_handle_countdown_hit(score_data)
	else:
		_handle_rtc_hit(score_data)

# ── Countdown mode (101 / 301 / 501) — player ──

func _handle_countdown_hit(score_data: Dictionary) -> void:
	var points: int = score_data.get("total", 0)
	if points == 0 and score_data.has("number"):
		points = score_data["number"] * score_data.get("multiplier", 1)
	var is_miss := (points == 0)

	if is_miss:
		_update_stats_on_player_score(score_data)
		_advance_turn()
		return

	_visit_score += points

	# Bust check
	var new_remaining := _visit_score_before - _visit_score
	var is_bust := false
	if new_remaining < 0:
		is_bust = true
	elif new_remaining == 1:
		is_bust = true
	elif new_remaining == 0:
		# Must finish on a double (bullseye counts as double 25)
		var mult: int = score_data.get("multiplier", 1)
		if mult != 2:
			is_bust = true

	if is_bust:
		_score_remaining = _visit_score_before
		_score_hud.update_remaining(_score_remaining)
		_update_stats_on_player_bust()
		_state = MatchState.VISIT_SUMMARY
		_throw_system.set_can_throw(false)
		_score_hud.show_bust_summary(_visit_dart_labels, _score_remaining)
		_schedule_clear()
		return

	_score_remaining = _visit_score_before - _visit_score
	_score_hud.update_remaining(_score_remaining)

	# Track per-dart stats
	_update_stats_on_player_score(score_data)

	# Near checkout pressure
	if _score_remaining > 0 and _score_remaining <= 40:
		_update_stats_on_near_checkout()

	# Checkout
	if _score_remaining == 0:
		_update_stats_on_player_checkout()
		_state = MatchState.FINISHED
		_throw_system.set_can_throw(false)
		_score_hud.show_message("CHECKOUT!", 3.0)
		var tween := create_tween()
		tween.tween_interval(3.5)
		tween.tween_callback(_on_player_wins)
		return

	if _visit_score == 180:
		_score_hud.show_message("ONE HUNDRED AND EIGHTY!", 2.0)

	_advance_turn()

# ── Countdown mode — AI opponent ──

func _handle_ai_countdown_hit(score_data: Dictionary) -> void:
	var points: int = score_data.get("total", 0)
	if points == 0 and score_data.has("number"):
		points = score_data["number"] * score_data.get("multiplier", 1)

	if points > 0:
		_opp_visit_score += points

	# Bust check
	var new_remaining := _opp_visit_score_before - _opp_visit_score
	var is_bust := false
	if new_remaining < 0:
		is_bust = true
	elif new_remaining == 1:
		is_bust = true
	elif new_remaining == 0:
		# Must finish on a double (bullseye counts as double 25)
		var mult: int = score_data.get("multiplier", 1)
		if mult != 2:
			is_bust = true

	if is_bust:
		# AI busted — revert score and end turn immediately
		_opp_score_remaining = _opp_visit_score_before
		_score_hud.update_opponent_score(_opp_score_remaining)
		_update_opponent_stats(5.0, -6.0, 5.0 * _opp_anger_rate)
		_cancel_ai_turn()
		var opp_name := OpponentData.get_display_name(_opponent_id)
		_score_hud.show_bust_summary_named(opp_name, _visit_dart_labels, _opp_score_remaining)
		_state = MatchState.VISIT_SUMMARY
		_schedule_clear()
		return

	_opp_score_remaining = _opp_visit_score_before - _opp_visit_score
	_score_hud.update_opponent_score(_opp_score_remaining)

	# Update opponent stats based on this dart
	if points >= 60:
		_update_opponent_stats(-3.0, 4.0, 0.0)
	elif points < 20 or points == 0:
		_update_opponent_stats(2.0, -3.0, 0.0)

	# AI checkout
	if _opp_score_remaining == 0:
		_cancel_ai_turn()
		_update_stats_on_opponent_checkout()
		_state = MatchState.FINISHED
		var opp_name := OpponentData.get_display_name(_opponent_id)
		_score_hud.show_message(opp_name + " WINS!", 3.0)
		var tween := create_tween()
		tween.tween_interval(3.5)
		tween.tween_callback(_on_player_loses)
		return

	if _opp_visit_score == 180:
		_score_hud.show_message("ONE HUNDRED AND EIGHTY!", 2.0)

	_ai_advance_turn()

# ── Round the Clock mode — player ──

func _handle_rtc_hit(score_data: Dictionary) -> void:
	var hit_number: int = score_data.get("number", 0)
	var multiplier: int = score_data.get("multiplier", 0)

	if _rtc_target <= 20:
		# Targeting a number 1-20
		if hit_number == _rtc_target and multiplier > 0:
			# Hit the target number
			var advance := multiplier  # single=1, double=2, treble=3

			if multiplier == 1:
				_rtc_hits_this_visit.append(str(_rtc_target))
			elif multiplier == 2:
				# Double: hit this number + skip one
				var skipped := mini(_rtc_target + 1, 21)
				_rtc_hits_this_visit.append("D" + str(_rtc_target) + " (skip " + str(skipped) + ")")
			elif multiplier == 3:
				# Treble: hit this number + skip two
				var s1 := mini(_rtc_target + 1, 21)
				var s2 := mini(_rtc_target + 2, 21)
				_rtc_hits_this_visit.append("T" + str(_rtc_target) + " (skip " + str(s1) + "," + str(s2) + ")")

			_rtc_target = mini(_rtc_target + advance, 21)
			# If we've gone past 20, move to bulls
			_score_hud.update_remaining_text(_rtc_target_label())
		else:
			# Missed the target (hit wrong number or missed board)
			_rtc_hits_this_visit.append("-")
	elif _rtc_target == 21:
		# Must hit outer bull (25) specifically
		if hit_number == 25:
			_rtc_hits_this_visit.append("Outer Bull")
			_rtc_target += 1
			_score_hud.update_remaining_text(_rtc_target_label())
		else:
			_rtc_hits_this_visit.append("-")
	else:
		# Must hit bullseye (double 25) specifically
		if hit_number == 25 and multiplier == 2:
			_rtc_hits_this_visit.append("Bullseye")
			_rtc_target += 1
			_score_hud.update_remaining_text(_rtc_target_label())
		else:
			_rtc_hits_this_visit.append("-")

	# RTC: treat hitting the target as a good score for stats
	if _rtc_hits_this_visit.size() > 0:
		var last_hit: String = _rtc_hits_this_visit[-1]
		if last_hit != "-":
			if last_hit.begins_with("T"):
				_update_career_stats(-1.0, 2.0)
			elif last_hit.begins_with("D"):
				_update_career_stats(-2.0, 3.0)
			else:
				_update_career_stats(-3.0, 4.0)
		else:
			_update_career_stats(3.0, -4.0)

	# Check for win
	if _rtc_target > 22:
		_update_stats_on_player_checkout()
		_state = MatchState.FINISHED
		_throw_system.set_can_throw(false)
		if _is_vs_ai:
			_score_hud.show_message("YOU WIN!", 3.0)
		else:
			_score_hud.show_message("ROUND COMPLETE!", 3.0)
		var tween := create_tween()
		tween.tween_interval(3.5)
		if _is_vs_ai:
			tween.tween_callback(_on_player_wins)
		else:
			tween.tween_callback(_restart_game)
		return

	_advance_turn()

# ── Round the Clock mode — AI opponent ──

func _handle_ai_rtc_hit(score_data: Dictionary) -> void:
	var hit_number: int = score_data.get("number", 0)
	var multiplier: int = score_data.get("multiplier", 0)

	if _opp_rtc_target <= 20:
		if hit_number == _opp_rtc_target and multiplier > 0:
			var advance := multiplier

			if multiplier == 1:
				_opp_rtc_hits_this_visit.append(str(_opp_rtc_target))
			elif multiplier == 2:
				var skipped := mini(_opp_rtc_target + 1, 21)
				_opp_rtc_hits_this_visit.append("D" + str(_opp_rtc_target) + " (skip " + str(skipped) + ")")
			elif multiplier == 3:
				var s1 := mini(_opp_rtc_target + 1, 21)
				var s2 := mini(_opp_rtc_target + 2, 21)
				_opp_rtc_hits_this_visit.append("T" + str(_opp_rtc_target) + " (skip " + str(s1) + "," + str(s2) + ")")

			_opp_rtc_target = mini(_opp_rtc_target + advance, 21)
			_score_hud.update_opponent_remaining_text(_opp_rtc_target_label())
		else:
			_opp_rtc_hits_this_visit.append("-")
	elif _opp_rtc_target == 21:
		# Must hit outer bull (25) specifically
		if hit_number == 25:
			_opp_rtc_hits_this_visit.append("Outer Bull")
			_opp_rtc_target += 1
			_score_hud.update_opponent_remaining_text(_opp_rtc_target_label())
		else:
			_opp_rtc_hits_this_visit.append("-")
	else:
		# Must hit bullseye (double 25) specifically
		if hit_number == 25 and multiplier == 2:
			_opp_rtc_hits_this_visit.append("Bullseye")
			_opp_rtc_target += 1
			_score_hud.update_opponent_remaining_text(_opp_rtc_target_label())
		else:
			_opp_rtc_hits_this_visit.append("-")

	# Check for AI win
	if _opp_rtc_target > 22:
		_cancel_ai_turn()
		_update_stats_on_opponent_checkout()
		_state = MatchState.FINISHED
		var opp_name := OpponentData.get_display_name(_opponent_id)
		_score_hud.show_message(opp_name + " WINS!", 3.0)
		var tween := create_tween()
		tween.tween_interval(3.5)
		tween.tween_callback(_on_player_loses)
		return

	_ai_advance_turn()

func _rtc_target_label() -> String:
	if _rtc_target <= 20:
		return "Next: " + str(_rtc_target)
	elif _rtc_target == 21:
		return "Next: Outer Bull"
	elif _rtc_target == 22:
		return "Next: Bullseye"
	else:
		return "DONE!"

func _opp_rtc_target_label() -> String:
	if _opp_rtc_target <= 20:
		return "Next: " + str(_opp_rtc_target)
	elif _opp_rtc_target == 21:
		return "Next: Outer Bull"
	elif _opp_rtc_target == 22:
		return "Next: Bullseye"
	else:
		return "DONE!"

# ── Tutorial mode ──

func _setup_tutorial() -> void:
	_tutorial_overlay = TutorialOverlay.new()
	add_child(_tutorial_overlay)
	var viewport_size := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	_tutorial_overlay.setup(viewport_size, _camera_rig.get_camera(), _camera_rig)
	_tutorial_overlay.start()
	_throw_system.swipe_update.connect(_tutorial_overlay.on_swipe_update)
	_throw_system.swipe_ended.connect(_tutorial_overlay.on_swipe_end)
	_tutorial_overlay.ready_to_throw.connect(_on_tutorial_ready)
	# Disable throwing until the player taps Go
	_throw_system.set_can_throw(false)

func _on_tutorial_ready() -> void:
	_state = MatchState.THROWING
	_throw_system.set_can_throw(true)
	var target: int = _tutorial_overlay.get_current_target()
	if target > 0:
		_score_hud.update_remaining_text("Hit: " + str(target))

func _handle_tutorial_hit(score_data: Dictionary, hit_pos: Vector2) -> void:
	var hit_number: int = score_data.get("number", 0)
	var multiplier: int = score_data.get("multiplier", 0)
	var target: int = _tutorial_overlay.get_current_target()

	_tutorial_last_was_hit = (hit_number == target and multiplier > 0)
	_tutorial_overlay.on_hit(hit_number, multiplier, hit_pos)

	# Check if the tutorial just completed
	if _tutorial_overlay.get_current_target() < 0:
		GameState.tutorial_completed = true
		_state = MatchState.FINISHED
		_throw_system.set_can_throw(false)
		var tween := create_tween()
		tween.tween_interval(3.0)
		tween.tween_callback(_restart_game)
		return

	# Pause to show feedback, then advance
	_state = MatchState.BETWEEN_DARTS
	_throw_system.set_can_throw(false)
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_callback(_tutorial_next_throw)

func _tutorial_next_throw() -> void:
	for dart in _active_darts:
		if is_instance_valid(dart):
			dart.queue_free()
	_active_darts.clear()
	_darts_this_visit = 0
	_score_hud.reset_dart_icons()

	# Tell the overlay to advance — it decides whether to show intro or resume aiming
	_tutorial_overlay.advance(_tutorial_last_was_hit)

# ── Turn management ──

func _advance_turn() -> void:
	if _darts_this_visit >= DARTS_PER_VISIT:
		_state = MatchState.VISIT_SUMMARY
		_throw_system.set_can_throw(false)

		# Opponent reacts to player's visit total
		if _is_countdown() and _is_vs_ai and _is_player_turn:
			_update_opponent_anger_on_player_score(_visit_score)

		if _is_countdown():
			_score_hud.show_visit_summary(_visit_dart_labels, _visit_score, _score_remaining)
		else:
			_score_hud.show_rtc_summary(_visit_dart_labels, _rtc_hits_this_visit, _rtc_target_label())

		_schedule_clear()
	else:
		_state = MatchState.BETWEEN_DARTS
		_throw_system.set_can_throw(false)
		var tween := create_tween()
		tween.tween_interval(BETWEEN_DART_DELAY)
		tween.tween_callback(func() -> void:
			_state = MatchState.THROWING
			_throw_system.set_can_throw(true)
			_start_confidence_decay()
		)

## AI turn advancement — schedule the next dart or end the visit
func _ai_advance_turn() -> void:
	_ai_darts_thrown += 1

	if _darts_this_visit >= DARTS_PER_VISIT:
		# AI visit complete — update player stats based on AI's total visit score
		if _is_countdown():
			_update_stats_on_opponent_score(_opp_visit_score)

		# Show summary
		_state = MatchState.VISIT_SUMMARY
		var opp_name := OpponentData.get_display_name(_opponent_id)

		if _is_countdown():
			_score_hud.show_visit_summary_named(opp_name, _visit_dart_labels, _opp_visit_score, _opp_score_remaining)
		else:
			_score_hud.show_rtc_summary_named(opp_name, _visit_dart_labels, _opp_rtc_hits_this_visit, _opp_rtc_target_label())

		var tween := create_tween()
		tween.tween_interval(AI_SUMMARY_DISPLAY_TIME)
		tween.tween_callback(_clear_and_next_visit)
	else:
		# More darts to throw — schedule next
		var delay := OpponentData.get_throw_delay(_opponent_id)
		_ai_turn_tween = create_tween()
		_ai_turn_tween.tween_interval(delay)
		_ai_turn_tween.tween_callback(_ai_throw_next_dart)

func _cancel_ai_turn() -> void:
	if _ai_turn_tween and _ai_turn_tween.is_valid():
		_ai_turn_tween.kill()
	_ai_turn_tween = null

func _schedule_clear() -> void:
	var tween := create_tween()
	tween.tween_interval(SUMMARY_DISPLAY_TIME)

	tween.tween_callback(_clear_and_next_visit)

func _clear_and_next_visit() -> void:
	for dart in _active_darts:
		if is_instance_valid(dart):
			dart.queue_free()
	_active_darts.clear()

	# In VS mode, alternate turns
	if _is_vs_ai:
		_is_player_turn = not _is_player_turn

	_start_visit()

# ── Career stats helpers ──

func _update_career_stats(nerves_delta: float, confidence_delta: float) -> void:
	if not CareerState.career_mode_active:
		return
	_player_nerves = clampf(_player_nerves + nerves_delta, 0.0, 100.0)
	_player_confidence = clampf(_player_confidence + confidence_delta, 0.0, 100.0)
	_score_hud.update_stats_bars(_player_dart_quality, _player_nerves, _player_confidence, _player_anger)

func _update_stats_on_player_score(score_data: Dictionary) -> void:
	if not CareerState.career_mode_active:
		return
	var points: int = score_data.get("total", 0)
	if points == 0 and score_data.has("number"):
		points = score_data["number"] * score_data.get("multiplier", 1)
	var multiplier: int = score_data.get("multiplier", 0)
	var number: int = score_data.get("number", 0)

	if points == 0:
		# Miss
		if number == 0:
			_update_career_stats(4.0, -5.0)  # Missed the board entirely
		else:
			_update_career_stats(3.0, -4.0)  # Scored under 20
	elif points >= 100:
		_update_career_stats(-5.0, 8.0)
	elif points >= 60:
		_update_career_stats(-3.0, 4.0)
	elif multiplier == 2:
		_update_career_stats(-2.0, 3.0)  # Hit a double
	elif multiplier == 3:
		_update_career_stats(-1.0, 2.0)  # Hit a treble
	elif points < 20:
		_update_career_stats(3.0, -4.0)

func _update_stats_on_player_bust() -> void:
	_update_player_anger(3.0)
	_update_career_stats(6.0, -8.0)

func _update_stats_on_player_checkout() -> void:
	_update_opponent_stats(0.0, 0.0, 10.0 * _opp_anger_rate)
	_update_career_stats(-20.0, 15.0)

func _update_stats_on_opponent_score(visit_total: int) -> void:
	if not CareerState.career_mode_active:
		return
	if visit_total >= 100:
		_update_career_stats(6.0, -3.0)
	elif visit_total >= 60:
		_update_career_stats(3.0, -2.0)

## Called when the player scores well — opponent reacts with anger
func _update_opponent_anger_on_player_score(visit_total: int) -> void:
	if not CareerState.career_mode_active:
		return
	if visit_total >= 100:
		_update_opponent_stats(0.0, 0.0, 3.0 * _opp_anger_rate)
	elif visit_total >= 60:
		_update_opponent_stats(0.0, 0.0, 1.0 * _opp_anger_rate)

func _update_stats_on_opponent_checkout() -> void:
	_update_player_anger(5.0)
	_update_career_stats(10.0, -5.0)

func _update_stats_on_near_checkout() -> void:
	# Called when player is near checkout (remaining <= 40)
	_update_career_stats(3.0, 0.0)

## Apply a drink effect to nerves, anger, and opponent anger
func apply_drink(is_full_pint: bool) -> void:
	if is_full_pint:
		_update_player_anger(4.0)
		_update_career_stats(-15.0, 0.0)
		_drinks_this_match += 2
		CareerState.liver_damage += 2.0 * maxf(0.5, 1.0 - CareerState.heft_tier * 0.15)
	else:
		_update_player_anger(2.0)
		_update_career_stats(-8.0, 0.0)
		_drinks_this_match += 1
		CareerState.liver_damage += 1.0 * maxf(0.5, 1.0 - CareerState.heft_tier * 0.15)
	# Opponent cools off slightly while player drinks
	_update_opponent_stats(0.0, 0.0, -2.0)

## Get the career scatter multiplier for the throw system
func get_career_scatter_mult() -> float:
	if not CareerState.career_mode_active:
		return 1.0
	# Nerves: 0=calm (0.7x), 50=neutral (1.35x), 100=terrified (2.0x)
	var nerve_mult := 0.7 + (_player_nerves / 100.0) * 1.3
	# Confidence: 0=no belief (1.5x), 50=neutral (1.05x), 100=peak (0.6x)
	var conf_mult := 1.5 - (_player_confidence / 100.0) * 0.9
	# Dart quality: 0=bad darts (1.3x scatter), 100=precision (0.7x)
	var dq_mult := 1.3 - (_player_dart_quality / 100.0) * 0.6
	return nerve_mult * conf_mult * dq_mult

## Map dart tier (0-3) to quality value (0-100)
func _tier_to_quality(tier: int) -> float:
	match tier:
		0: return 20.0   # Brass
		1: return 45.0   # Nickel Silver
		2: return 70.0   # Tungsten
		3: return 95.0   # Premium
		_: return 20.0

## Show the player's stats on the HUD
func _show_player_stats() -> void:
	_score_hud.set_stats_owner("YOUR STATS")
	_score_hud.update_stats_bars(_player_dart_quality, _player_nerves, _player_confidence, _player_anger)

## Show the opponent's stats on the HUD
func _show_opponent_stats() -> void:
	var opp_name := OpponentData.get_display_name(_opponent_id).to_upper()
	_score_hud.set_stats_owner(opp_name + "'S STATS")
	_score_hud.update_stats_bars(_opp_dart_quality, _opp_nerves, _opp_confidence, _opp_anger)

## Update player anger (clamped 0-100)
func _update_player_anger(delta: float) -> void:
	if not CareerState.career_mode_active:
		return
	_player_anger = clampf(_player_anger + delta, 0.0, 100.0)
	# Refresh HUD if it's the player's turn
	if _is_player_turn:
		_score_hud.update_stats_bars(_player_dart_quality, _player_nerves, _player_confidence, _player_anger)

## Update opponent stats (nerves, confidence, anger) and check anger threshold
func _update_opponent_stats(nerves_d: float, confidence_d: float, anger_d: float) -> void:
	if not CareerState.career_mode_active:
		return
	_opp_nerves = clampf(_opp_nerves + nerves_d, 0.0, 100.0)
	_opp_confidence = clampf(_opp_confidence + confidence_d, 0.0, 100.0)
	_opp_anger = clampf(_opp_anger + anger_d, 0.0, 100.0)
	# Refresh HUD if it's the opponent's turn
	if not _is_player_turn:
		_score_hud.update_stats_bars(_opp_dart_quality, _opp_nerves, _opp_confidence, _opp_anger)
	# Check anger threshold
	if _opp_anger >= 100.0:
		_trigger_fight_scene()

## Stub — opponent anger has hit 100%. Show "FIGHT!" and treat as a loss.
func _trigger_fight_scene() -> void:
	_cancel_ai_turn()
	_throw_system.set_can_throw(false)
	_state = MatchState.FINISHED
	var opp_name := OpponentData.get_display_name(_opponent_id)
	_score_hud.show_message("FIGHT!", 3.0)
	var tween := create_tween()
	tween.tween_interval(3.5)
	tween.tween_callback(_on_player_loses)

func _on_player_wins() -> void:
	if CareerState.career_mode_active:
		CareerState.confidence_carry = _player_confidence * 0.5
		CareerState.losses_at_current_level = 0
		var prize: int = OpponentData.get_prize_money(_opponent_id)
		CareerState.money += prize
		CareerState.career_level += 1
		GameState.match_won = true
		GameState.match_prize = prize
		GameState.match_career_over = false
		_goto_results()
		return
	_restart_game()

func _on_player_loses() -> void:
	if CareerState.career_mode_active:
		CareerState.confidence_carry = 20.0
		CareerState.losses_at_current_level += 1
		var max_losses: int = OpponentData.get_max_losses(_opponent_id)
		var is_career_over: bool = CareerState.losses_at_current_level >= max_losses
		GameState.match_won = false
		GameState.match_prize = 0
		GameState.match_career_over = is_career_over
		_goto_results()
		return
	_restart_game()

func _goto_results() -> void:
	_cancel_ai_turn()
	for dart in _active_darts:
		if is_instance_valid(dart):
			dart.queue_free()
	_active_darts.clear()
	get_tree().change_scene_to_file("res://scenes/match_results.tscn")

func _restart_game() -> void:
	_cancel_ai_turn()
	for dart in _active_darts:
		if is_instance_valid(dart):
			dart.queue_free()
	_active_darts.clear()
	# Go back to menu
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		_cancel_ai_turn()
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
