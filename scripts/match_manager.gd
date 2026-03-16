extends Node3D
class_name MatchManager

enum MatchState { THROWING, BETWEEN_DARTS, VISIT_SUMMARY, CLEARING, AI_THROWING, FINISHED }

const DARTS_PER_VISIT := 3
const BETWEEN_DART_DELAY := 0.1
const SUMMARY_DISPLAY_TIME := 2.0
const AI_SUMMARY_DISPLAY_TIME := 1.5
const CONFIDENCE_DECAY_RATE := 0.5    # Points lost per second while aiming
const CONFIDENCE_DECAY_INTERVAL := 1.0 # Seconds between ticks
const CONFIDENCE_FLOOR := 33.0        # Minimum confidence — resets to this each visit

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

# ── Barman drink offer at 18 (career RTC only) ──
var _drink_offered_at_18 := false
var _drink_offer_pending := false

# ── Second drink offer (after next visit post-first-drink) ──
var _second_drink_after_visits: int = -1  # Visits until offer, -1 = inactive
var _second_drink_pending := false
var _re_offer_drink := false

# ── Animated nerves bar (slow decrease visible at the oche) ──
var _pending_nerves_anim: float = -1.0  # Target nerves value, -1 = no pending anim
var _nerves_before_drink: float = 0.0
var _suppress_hud_update := false

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

# ── Sandbox mode (free throw after tutorial) ──
var _sandbox_mode := false
var _sandbox_overlay: SandboxOverlay

# Zoom reminder — escalates to red if player doesn't zoom during a visit
var _player_missed_zoom := false

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
	_player_confidence = clampf(_player_confidence - CONFIDENCE_DECAY_RATE, CONFIDENCE_FLOOR, 100.0)
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
	_camera_rig.visit_zoom_detected.connect(_on_visit_zoom)
	if _is_tutorial():
		_setup_tutorial()
	# Connect companion dialogue signals (career mode only)
	if CareerState.career_mode_active:
		CompanionManager.dialogue_finished.connect(_on_companion_dialogue_finished)
		CompanionManager.consequence_triggered.connect(_on_companion_consequence)

func _on_first_zoom() -> void:
	_score_hud.hide_zoom_reminder()

func _on_visit_zoom() -> void:
	_score_hud.hide_zoom_reminder()

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
	return GameState.game_mode == GameState.GameMode.TUTORIAL and not _sandbox_mode

func _is_free_throw() -> bool:
	return GameState.game_mode == GameState.GameMode.FREE_THROW

# ── Visit flow ──

func _start_visit() -> void:
	_darts_this_visit = 0
	_visit_dart_labels.clear()

	# Free Throw from practice menu — go straight to sandbox
	if _is_free_throw() and not _sandbox_mode:
		_enter_sandbox()
		return

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
		# Check for barman drink offer (career RTC only, once per match)
		if _drink_offer_pending and _is_rtc() and CareerState.career_mode_active:
			_drink_offer_pending = false
			_state = MatchState.BETWEEN_DARTS
			_throw_system.set_can_throw(false)
			_score_hud.reset_dart_icons()
			_score_hud.hide_summary()
			if _is_vs_ai:
				_score_hud.update_turn_indicator(true)
				if CareerState.career_mode_active:
					_show_player_stats()
			CompanionManager.request_dialogue(CompanionData.DRINK_OFFER, {"reached_18": true})
			return

		# Check for second barman drink offer (after next visit post-first-drink)
		if _second_drink_pending and CareerState.career_mode_active:
			_second_drink_pending = false
			_state = MatchState.BETWEEN_DARTS
			_throw_system.set_can_throw(false)
			_score_hud.reset_dart_icons()
			_score_hud.hide_summary()
			if _is_vs_ai:
				_score_hud.update_turn_indicator(true)
				if CareerState.career_mode_active:
					_show_player_stats()
			CompanionManager.request_dialogue(CompanionData.DRINK_OFFER, {"second_drink_offer": true})
			return

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

		# Ensure confidence is at least the floor at the start of each visit
		if CareerState.career_mode_active:
			if _player_confidence < CONFIDENCE_FLOOR:
				_player_confidence = CONFIDENCE_FLOOR
			_throw_system.career_scatter_mult = get_career_scatter_mult()

		_throw_system.set_can_throw(true)
		_start_confidence_decay()
		DrinkManager.flash_tier_name()

		# Zoom reminder — reset per-visit tracking and show hint
		_camera_rig.reset_visit_zoom()
		if not _is_tutorial() and not _sandbox_mode:
			_score_hud.show_zoom_reminder(_player_missed_zoom)

		if _is_vs_ai:
			_score_hud.update_turn_indicator(true)
			if CareerState.career_mode_active:
				# Show stats with pre-drink nerves if animation is pending
				if _pending_nerves_anim >= 0.0:
					_score_hud.update_stats_bars(_player_dart_quality, _nerves_before_drink, _player_confidence, _player_anger)
				else:
					_show_player_stats()

		# Animate nerves decrease if pending from a drink
		if _pending_nerves_anim >= 0.0:
			_score_hud.animate_single_bar(1, _nerves_before_drink, _pending_nerves_anim, 2.5)
			_pending_nerves_anim = -1.0
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
	elif _sandbox_mode:
		_handle_sandbox_hit(score_data, hit_pos)
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
			# Compute new target: doubles/trebles can skip numbers but NEVER past 20.
			# Player must hit 20 to move to outer bull (21).
			var old_target := _rtc_target
			var new_target: int
			if _rtc_target < 20:
				new_target = mini(_rtc_target + multiplier, 20)
			else:
				# Target is 20: any hit advances to outer bull only
				new_target = 21

			# Build hit description with actual skipped numbers
			var prefix := ""
			if multiplier == 2:
				prefix = "D"
			elif multiplier == 3:
				prefix = "T"

			var skipped: Array = []
			for n in range(old_target + 1, new_target):
				skipped.append(str(n))
			if skipped.size() > 0:
				_rtc_hits_this_visit.append(prefix + str(old_target) + " (skip " + ",".join(skipped) + ")")
			else:
				_rtc_hits_this_visit.append(prefix + str(old_target))

			_rtc_target = new_target
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
	# Treble gives biggest confidence bump, then double, then single
	if _rtc_hits_this_visit.size() > 0:
		var last_hit: String = _rtc_hits_this_visit[-1]
		if last_hit != "-":
			if last_hit.begins_with("T"):
				_update_career_stats(-3.0, 10.0)
			elif last_hit.begins_with("D"):
				_update_career_stats(-2.0, 7.0)
			else:
				_update_career_stats(-1.0, 4.0)
		else:
			_update_career_stats(3.0, -3.0)

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

	# Flag drink offer when player reaches 18 (career RTC only, once per match)
	if not _drink_offered_at_18 and _rtc_target >= 18 and CareerState.career_mode_active:
		_drink_offered_at_18 = true
		_drink_offer_pending = true

	_advance_turn()

# ── Round the Clock mode — AI opponent ──

func _handle_ai_rtc_hit(score_data: Dictionary) -> void:
	var hit_number: int = score_data.get("number", 0)
	var multiplier: int = score_data.get("multiplier", 0)

	if _opp_rtc_target <= 20:
		if hit_number == _opp_rtc_target and multiplier > 0:
			var old_target := _opp_rtc_target
			var new_target: int
			if _opp_rtc_target < 20:
				new_target = mini(_opp_rtc_target + multiplier, 20)
			else:
				new_target = 21

			var prefix := ""
			if multiplier == 2:
				prefix = "D"
			elif multiplier == 3:
				prefix = "T"

			var skipped: Array = []
			for n in range(old_target + 1, new_target):
				skipped.append(str(n))
			if skipped.size() > 0:
				_opp_rtc_hits_this_visit.append(prefix + str(old_target) + " (skip " + ",".join(skipped) + ")")
			else:
				_opp_rtc_hits_this_visit.append(prefix + str(old_target))

			_opp_rtc_target = new_target
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

	# Flag drink offer when AI reaches 18 (career RTC only, once per match)
	if not _drink_offered_at_18 and _opp_rtc_target >= 18 and CareerState.career_mode_active:
		_drink_offered_at_18 = true
		_drink_offer_pending = true

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
		tween.tween_callback(_show_tutorial_complete)
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

# ── Sandbox mode (free throw with stat controls) ──

## Step 1: Tutorial done — offer Back to menu or Free throw
func _show_tutorial_complete() -> void:
	# Hide the tutorial overlay to prevent its "Nice one!" text clashing with the popup
	if _tutorial_overlay:
		_tutorial_overlay.visible = false

	var overlay := _make_popup_overlay()

	var panel := _make_popup_panel(Vector2(80, 400), 560)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var msg := Label.new()
	msg.text = "Nice one!"
	UIFont.apply(msg, UIFont.BODY)
	msg.add_theme_color_override("font_color", Color.WHITE)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.custom_minimum_size = Vector2(496, 0)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(msg)

	var menu_btn := _make_popup_button("Back to menu", Color(0.25, 0.25, 0.3))
	menu_btn.pressed.connect(func() -> void:
		overlay.queue_free()
		_restart_game()
	)
	vbox.add_child(menu_btn)

	var free_btn := _make_popup_button("Free throw", Color(0.15, 0.45, 0.15))
	free_btn.pressed.connect(func() -> void:
		overlay.queue_free()
		_show_sandbox_intro()
	)
	vbox.add_child(free_btn)

	panel.add_child(vbox)
	overlay.add_child(panel)
	_fade_in_overlay(overlay)

## Step 2: Explain free throw mode before entering sandbox
func _show_sandbox_intro() -> void:
	var overlay := _make_popup_overlay()

	var panel := _make_popup_panel(Vector2(60, 340), 600)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var msg := Label.new()
	msg.text = "In free throw mode, you can throw as many darts as you like.\n\nUse the controls to change your stats and see how they affect your accuracy.\n\nThese stats will matter when you start your career."
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(536, 0)
	UIFont.apply(msg, UIFont.BODY)
	msg.add_theme_color_override("font_color", Color.WHITE)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(msg)

	var btn := _make_popup_button("Let's throw!", Color(0.15, 0.45, 0.15))
	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		_enter_sandbox()
	)
	vbox.add_child(btn)

	panel.add_child(vbox)
	overlay.add_child(panel)
	_fade_in_overlay(overlay)

## Shared popup helpers — keeps the two popups consistent
func _make_popup_overlay() -> Control:
	var overlay := Control.new()
	overlay.size = Vector2(720, 1280)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100
	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.5)
	dimmer.size = Vector2(720, 1280)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dimmer)
	return overlay

func _make_popup_panel(pos: Vector2, w: float) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 28
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	panel.position = pos
	panel.size = Vector2(w, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel

func _make_popup_button(text: String, bg_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	UIFont.apply_button(btn, UIFont.BODY)
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.bg_color = bg_color.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.custom_minimum_size = Vector2(496, 0)
	return btn

func _fade_in_overlay(overlay: Control) -> void:
	overlay.modulate = Color(1, 1, 1, 0)
	_score_hud.add_child(overlay)
	var tween := create_tween()
	tween.tween_property(overlay, "modulate", Color(1, 1, 1, 1), 0.3)

func _enter_sandbox() -> void:
	# Clear tutorial darts
	for dart in _active_darts:
		if is_instance_valid(dart):
			dart.queue_free()
	_active_darts.clear()

	# Remove tutorial overlay
	if _tutorial_overlay:
		_tutorial_overlay.queue_free()
		_tutorial_overlay = null

	_sandbox_mode = true

	# Create sandbox overlay
	_sandbox_overlay = SandboxOverlay.new()
	add_child(_sandbox_overlay)
	_sandbox_overlay.scatter_changed.connect(_on_sandbox_scatter_changed)
	_sandbox_overlay.clear_requested.connect(_on_sandbox_clear)
	_sandbox_overlay.exit_requested.connect(_on_sandbox_exit)

	# Set initial scatter from sandbox defaults
	_throw_system.career_scatter_mult = _sandbox_overlay.get_scatter_mult()

	# Update HUD
	_score_hud.update_remaining_text("FREE THROW")
	_score_hud.hide_summary()
	_score_hud.reset_dart_icons()

	# Enable throwing
	_state = MatchState.THROWING
	_darts_this_visit = 0
	_throw_system.set_can_throw(true)

func _handle_sandbox_hit(_score_data: Dictionary, _hit_pos: Vector2) -> void:
	# Re-enable throwing after a brief pause — no scoring or turns
	_state = MatchState.BETWEEN_DARTS
	_throw_system.set_can_throw(false)

	# Reset dart icons every 3 darts so they cycle
	if _darts_this_visit >= 3:
		_darts_this_visit = 0
		_score_hud.reset_dart_icons()

	var tween := create_tween()
	tween.tween_interval(BETWEEN_DART_DELAY)
	tween.tween_callback(func() -> void:
		_state = MatchState.THROWING
		_throw_system.set_can_throw(true)
	)

func _on_sandbox_scatter_changed(mult: float) -> void:
	_throw_system.career_scatter_mult = mult

func _on_sandbox_clear() -> void:
	for dart in _active_darts:
		if is_instance_valid(dart):
			dart.queue_free()
	_active_darts.clear()
	_darts_this_visit = 0
	_score_hud.reset_dart_icons()

func _on_sandbox_exit() -> void:
	_restart_game()

# ── Turn management ──

func _advance_turn() -> void:
	if _darts_this_visit >= DARTS_PER_VISIT:
		_state = MatchState.VISIT_SUMMARY
		_throw_system.set_can_throw(false)

		# Track if the player finished a visit without zooming
		if (_is_player_turn or not _is_vs_ai) and not _is_tutorial() and not _sandbox_mode:
			_player_missed_zoom = not _camera_rig.did_zoom_this_visit()

		# Count down to second drink offer (player turn only)
		if _second_drink_after_visits > 0 and (_is_player_turn or not _is_vs_ai):
			_second_drink_after_visits -= 1
			if _second_drink_after_visits == 0:
				_second_drink_pending = true
				_second_drink_after_visits = -1

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
	# Level-based nerves cap — early levels feel less punishing
	var nerves_cap := _get_nerves_cap()
	_player_nerves = clampf(_player_nerves + nerves_delta, 0.0, nerves_cap)
	_player_confidence = clampf(_player_confidence + confidence_delta, 0.0, 100.0)
	if not _suppress_hud_update:
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
			_update_career_stats(4.0, -3.0)  # Missed the board entirely
		else:
			_update_career_stats(3.0, -2.0)  # Hit wrong segment
	elif points >= 100:
		_update_career_stats(-5.0, 10.0)
	elif multiplier == 3:
		_update_career_stats(-3.0, 8.0)   # Hit a treble — biggest bump
	elif multiplier == 2:
		_update_career_stats(-2.0, 6.0)   # Hit a double — big bump
	elif points >= 60:
		_update_career_stats(-3.0, 5.0)
	elif points < 20:
		_update_career_stats(2.0, -2.0)
	else:
		_update_career_stats(-1.0, 3.0)   # Decent single

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

## Apply a drink effect to nerves, anger, and opponent anger.
## A drink cuts nerves to a fraction of their current value — big visible effect.
func apply_drink(is_full_pint: bool) -> void:
	if is_full_pint:
		_update_player_anger(4.0)
		# Full pint: nerves drop to 15% of current, confidence +10
		var nerve_drop := _player_nerves * 0.85
		_update_career_stats(-nerve_drop, 10.0)
		_drinks_this_match += 2
		CareerState.liver_damage += 2.0 * maxf(0.5, 1.0 - CareerState.heft_tier * 0.15)
	else:
		_update_player_anger(2.0)
		# Half pint: nerves drop to 25% of current, confidence +6
		var nerve_drop := _player_nerves * 0.75
		_update_career_stats(-nerve_drop, 6.0)
		_drinks_this_match += 1
		CareerState.liver_damage += 1.0 * maxf(0.5, 1.0 - CareerState.heft_tier * 0.15)
	# Opponent cools off slightly while player drinks
	_update_opponent_stats(0.0, 0.0, -2.0)

## Get the career scatter multiplier for the throw system
func get_career_scatter_mult() -> float:
	if not CareerState.career_mode_active:
		return 1.0
	# Compressed ranges so even at worst stats, darts still cluster near the aim.
	# Old max product was 3.9 — now capped around 2.2.
	# Nerves: 0=calm (0.85x), 50=neutral (1.2x), 100=terrified (1.55x)
	var nerve_mult := 0.85 + (_player_nerves / 100.0) * 0.7
	# Confidence: 0=no belief (1.25x), 50=neutral (1.0x), 100=peak (0.75x)
	var conf_mult := 1.25 - (_player_confidence / 100.0) * 0.5
	# Dart quality: 0=bad darts (1.15x scatter), 100=precision (0.8x)
	var dq_mult := 1.15 - (_player_dart_quality / 100.0) * 0.35
	return nerve_mult * conf_mult * dq_mult

## Nerves cap by career level — keeps early levels forgiving
func _get_nerves_cap() -> float:
	var level: int = OpponentData.OPPONENTS.get(_opponent_id, {}).get("level", 1)
	match level:
		1: return 50.0   # Big Kev — pub, relaxed, nerves can't spiral
		2: return 65.0   # Derek — tournament, some pressure
		3: return 75.0   # Steve — regional, getting serious
		_: return 100.0  # Level 4+ — full range

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
	if _is_player_turn and not _suppress_hud_update:
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

# ── Companion dialogue handlers ──

func _on_companion_dialogue_finished(trigger: String) -> void:
	if trigger == CompanionData.DRINK_OFFER:
		if _re_offer_drink:
			_re_offer_drink = false
			# Brief pause before re-showing the offer (let panel slide out first)
			var tween := create_tween()
			tween.tween_interval(0.5)
			tween.tween_callback(func() -> void:
				CompanionManager.request_dialogue(CompanionData.DRINK_OFFER, {"second_drink_offer": true})
			)
			return
		# Drink offer dismissed — resume the player's visit
		_start_visit()

func _on_companion_consequence(consequence_id: String) -> void:
	if consequence_id == "add_half_pint":
		# Free half pint from barman — set up animated nerves decrease
		_nerves_before_drink = _player_nerves
		_suppress_hud_update = true
		DrinkManager.add_drink(true, 1)  # Free half pint (visual effects)
		apply_drink(false)               # Career stats: nerves -8, anger +2
		_suppress_hud_update = false
		_pending_nerves_anim = _player_nerves
		# Trigger second drink offer after the player's next visit
		_second_drink_after_visits = 1
	elif consequence_id == "buy_half_pint":
		# Paid half pint — player is paying this time
		_nerves_before_drink = _player_nerves
		_suppress_hud_update = true
		DrinkManager.add_drink(true, 1)  # Visual effects (payment handled below)
		apply_drink(false)               # Career stats: nerves -8, anger +2
		_suppress_hud_update = false
		_pending_nerves_anim = _player_nerves
		# Deduct cost from career money
		CareerState.money -= DrinkManager.COST_PER_UNIT
		_score_hud.update_balance(CareerState.money)
	elif consequence_id == "reject_full_pint":
		# Full pint rejected — loop back to the choice screen
		_re_offer_drink = true
