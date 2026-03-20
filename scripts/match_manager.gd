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
var _player_nerves: float = 50.0      # Derived — displayed on HUD
var _player_confidence: float = 50.0  # Derived — displayed on HUD
var _player_dart_quality: float = 0.0
var _player_anger: float = 0.0        # Derived — displayed on HUD
var _drinks_this_match: int = 0
var _player_visit_count: int = 0

# ── Raw stats (before drunk modifiers) ──
var _raw_nerves: float = 50.0
var _raw_confidence: float = 50.0
var _gameplay_anger: float = 0.0

# ── Multi-leg match state ──
var _legs_to_win: int = 1
var _player_legs_won: int = 0
var _opponent_legs_won: int = 0

# ── Round offer (every 3rd player visit, career L2+) ──
var _round_offer_pending: bool = false
var _round_is_player_paying: bool = false
var _round_first_decided: bool = false  # False until first coin flip
var _player_broke_round: bool = false   # True when it's player's round but they can't afford it

# ── Barman drink offer at 18 (career RTC only) ──
var _drink_offered_at_18 := false
var _drink_offer_pending := false

# ── Second drink offer (after next visit post-first-drink) ──
var _second_drink_after_visits: int = -1  # Visits until offer, -1 = inactive
var _second_drink_pending := false
var _re_offer_drink := false

# ── Mad Dog bribe system (L5 only) ──
var _bribe_offer_pending: bool = false
var _bribe_used: bool = false

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

# ── Cinematic camera state ──
var _cinematic: CinematicCamera
var _cinematic_active := false

# ── Sandbox mode (free throw after tutorial) ──
var _sandbox_mode := false
var _sandbox_overlay: SandboxOverlay

# Zoom reminder — escalates to red if player doesn't zoom during a visit
var _player_missed_zoom := false

# Confidence decay while aiming
var _confidence_decay_timer: float = 0.0
var _confidence_decay_active: bool = false

# Pre-drink advice popup (first visit only)
var _pre_drink_advice_shown := false
var _pre_drink_units_at_start: int = 0

# Drunk drinking warning (once per match, when heavy + accepting more)
var _drunk_warning_shown: bool = false

# High nerves warning — mate suggests a drink (once per match, when nerves first hit 75%+)
var _high_nerves_warning_shown: bool = false

func _ready() -> void:
	_is_vs_ai = GameState.is_vs_ai
	_opponent_id = GameState.opponent_id
	_setup_environment()
	_build_scene()
	_connect_signals()
	_init_game_mode()
	_start_visit()
	# Doubles tip is now triggered per-dart when score first reaches a checkout value
	# (see _check_doubles_tip in _handle_countdown_hit)

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
	_raw_confidence = clampf(_raw_confidence - CONFIDENCE_DECAY_RATE, CONFIDENCE_FLOOR, 100.0)
	_recalculate_drunk_stats()

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
				CareerState.money = maxi(CareerState.money, 0)
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
		DrinkManager.drinks_changed.connect(_on_drinks_changed)
		DrinkManager.sweet_spot_reached.connect(_on_sweet_spot_reached)
	_score_hud.debug_menu_requested.connect(_show_debug_menu)

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
		_raw_nerves = OpponentData.get_base_nerves(_opponent_id)
		if CareerState.losses_at_current_level == 0:
			_raw_confidence = 20.0  # First attempt at this level
		else:
			_raw_confidence = CareerState.confidence_carry
		_player_dart_quality = _tier_to_quality(GameState.dart_tier)
		_gameplay_anger = 0.0
		_drinks_this_match = 0
		_player_visit_count = 0
		_drunk_warning_shown = false
		_high_nerves_warning_shown = false
		_round_first_decided = false
		_player_broke_round = false

		# Apply pre-match drinking from between-match card
		DrinkManager.reset()
		_pre_drink_units_at_start = CareerState.pre_drink_units
		_pre_drink_advice_shown = false
		if CareerState.pre_drink_units > 0:
			DrinkManager.set_level(CareerState.pre_drink_units)
			# Sober venue anxiety doesn't apply when pre-drinking
			CareerState.pre_drink_units = 0
		else:
			# Sober: bigger venues add extra nerves from crowd/atmosphere
			# L1-2: no extra (local pub). L3+: escalating venue pressure.
			var venue_anxiety := maxf(0.0, (CareerState.career_level - 2) * 4.0)
			# Exhibition matches are more relaxed — halve the venue pressure
			if CareerState.exhibition_mode:
				venue_anxiety *= 0.5
			_raw_nerves = clampf(_raw_nerves + venue_anxiety, 0.0, 100.0)

		# Derive displayed stats from raw + drunk modifiers
		_recalculate_drunk_stats()

		# Set companion stage for dialogue system
		var stage_map := {1: 0, 2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 7: 5}
		CompanionManager.companion_stage = stage_map.get(CareerState.career_level, 0)

		# Opponent dart quality matches their actual dart tier (one above player, capped at 3)
		_opp_dart_quality = _tier_to_quality(_throw_system.ai_dart_tier)
		_opp_nerves = OpponentData.get_base_nerves(_opponent_id)
		_opp_confidence = OpponentData.get_base_confidence(_opponent_id)
		_opp_anger = OpponentData.get_base_anger(_opponent_id)
		_opp_anger_rate = OpponentData.get_anger_rate(_opponent_id)
		# Walk-on volume bonus — louder music winds up the opponent
		if CareerState.career_mode_active and CareerState.walkon_volume >= 0:
			var volume_anger: float = [0.0, 5.0, 15.0, 30.0][CareerState.walkon_volume]
			_opp_anger = clampf(_opp_anger + volume_anger, 0.0, 99.0)

	# Set up multi-leg match
	if _is_vs_ai:
		_legs_to_win = OpponentData.get_legs_to_win(_opponent_id)
		_player_legs_won = 0
		_opponent_legs_won = 0

	# Set up dual HUD if VS mode
	if _is_vs_ai:
		_score_hud.setup_vs_mode(_opponent_id)
		if _legs_to_win > 1:
			_score_hud.setup_leg_counter(_legs_to_win)
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
		# Check for Mad Dog bribe offer
		if _bribe_offer_pending and CareerState.career_mode_active:
			_bribe_offer_pending = false
			_state = MatchState.BETWEEN_DARTS
			_throw_system.set_can_throw(false)
			_score_hud.reset_dart_icons()
			_score_hud.hide_summary()
			_show_bribe_popup()
			return

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

		# Check for round offer (every 3rd visit, career L2+)
		if _round_offer_pending and CareerState.career_mode_active:
			_round_offer_pending = false
			_state = MatchState.BETWEEN_DARTS
			_throw_system.set_can_throw(false)
			_score_hud.reset_dart_icons()
			_score_hud.hide_summary()
			if _is_vs_ai:
				_score_hud.update_turn_indicator(true)
				if CareerState.career_mode_active:
					_show_player_stats()
			var ctx := {}
			if _player_broke_round:
				ctx["companion_round"] = true
				ctx["player_broke"] = true
			elif _round_is_player_paying:
				ctx["player_round"] = true
			else:
				ctx["companion_round"] = true
			CompanionManager.request_dialogue(CompanionData.DRINK_OFFER, ctx)
			return

		# Track visits and apply alcohol decay
		_player_visit_count += 1
		if CareerState.career_mode_active:
			DrinkManager.apply_visit_decay()
			# Schedule round offer after every 3rd visit (L2+)
			if CareerState.career_level >= 2 and _player_visit_count > 0 and _player_visit_count % 3 == 0:
				_round_offer_pending = true
				_player_broke_round = false
				# First round: 50/50 coin flip. After that: alternate.
				if not _round_first_decided:
					_round_is_player_paying = randi() % 2 == 0
					_round_first_decided = true
				else:
					_round_is_player_paying = not _round_is_player_paying
				# If player can't afford their round, companion covers but guilt trips
				if _round_is_player_paying:
					var config = DrinkManager.get_level_config(CareerState.career_level)
					if config != null:
						var round_cost: int = config["pint_price"] * config["round_size"]
						if CareerState.money < round_cost:
							_player_broke_round = true
							_round_is_player_paying = false

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

		# Ensure raw confidence is at least the floor at the start of each visit
		if CareerState.career_mode_active:
			if _raw_confidence < CONFIDENCE_FLOOR:
				_raw_confidence = CONFIDENCE_FLOOR
			_recalculate_drunk_stats()

		# Pre-drink advice on first visit (career L2+), or normal tier flash
		if not _pre_drink_advice_shown and CareerState.career_mode_active and _pre_drink_units_at_start > 0 and CareerState.career_level >= 2:
			_pre_drink_advice_shown = true
			_throw_system.set_can_throw(false)
			_stop_confidence_decay()
			_show_pre_drink_advice()
		else:
			_throw_system.set_can_throw(true)
			_start_confidence_decay()
			if not CareerState.career_mode_active:
				DrinkManager.flash_tier_name()

		# Restore the player's zoom from before the AI turn
		_camera_rig.restore_view()

		# Auto-zoom to 20 in 301/501 when score is high (almost always aiming at T20)
		if _is_countdown() and GameState.starting_score >= 301 and _score_remaining >= 180 and _is_player_turn:
			_camera_rig.zoom_to_twenty()

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
	# Save the player's zoom and show the full board for the AI turn
	_camera_rig.save_view()
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
	if _should_play_cinematic():
		_start_game_shot_cinematic(dart)
	else:
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

	# One-time doubles tip — fires when score first reaches a single-dart checkout value
	_check_doubles_tip()

	# Near checkout pressure
	if _score_remaining > 0 and _score_remaining <= 40:
		_update_stats_on_near_checkout()

	# Checkout
	if _score_remaining == 0:
		_update_stats_on_player_checkout()
		_state = MatchState.FINISHED
		_throw_system.set_can_throw(false)
		_score_hud.show_message(_checkout_message(true), 3.0)
		var tween := create_tween()
		tween.tween_interval(3.5)
		tween.tween_callback(_on_leg_complete.bind(true))
		return

	if _visit_score == 180:
		_score_hud.show_message("ONE HUNDRED AND EIGHTY!", 3.0)
		_flash_180()

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

	# AI checkout — double-check that last dart was a double (safety guard)
	if _opp_score_remaining == 0:
		var final_mult: int = score_data.get("multiplier", 1)
		if final_mult != 2:
			# Safety: should have been caught by bust check above
			_opp_score_remaining = _opp_visit_score_before
			_score_hud.update_opponent_score(_opp_score_remaining)
			_cancel_ai_turn()
			var opp_name := OpponentData.get_display_name(_opponent_id)
			_score_hud.show_bust_summary_named(opp_name, _visit_dart_labels, _opp_score_remaining)
			_state = MatchState.VISIT_SUMMARY
			_schedule_clear()
			return
		_cancel_ai_turn()
		_update_stats_on_opponent_checkout()
		_state = MatchState.FINISHED
		_score_hud.show_message(_checkout_message(false), 3.0)
		var tween := create_tween()
		tween.tween_interval(3.5)
		tween.tween_callback(_on_leg_complete.bind(false))
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

			# Build hit description
			var prefix := ""
			if multiplier == 2:
				prefix = "D"
			elif multiplier == 3:
				prefix = "T"
			_rtc_hits_this_visit.append({"text": prefix + str(old_target), "scoring": true})

			_rtc_target = new_target
			_score_hud.update_remaining_text(_rtc_target_label())
		else:
			# Hit wrong number or missed board — show what was actually hit
			_rtc_hits_this_visit.append(_rtc_non_scoring_entry(hit_number, multiplier))
	elif _rtc_target == 21:
		# Must hit outer bull (25) specifically
		if hit_number == 25:
			_rtc_hits_this_visit.append({"text": "OUTER", "scoring": true})
			_rtc_target += 1
			_score_hud.update_remaining_text(_rtc_target_label())
		else:
			_rtc_hits_this_visit.append(_rtc_non_scoring_entry(hit_number, multiplier))
	else:
		# Must hit bullseye (double 25) specifically
		if hit_number == 25 and multiplier == 2:
			_rtc_hits_this_visit.append({"text": "BULL", "scoring": true})
			_rtc_target += 1
			_score_hud.update_remaining_text(_rtc_target_label())
		else:
			_rtc_hits_this_visit.append(_rtc_non_scoring_entry(hit_number, multiplier))

	# RTC: treat hitting the target as a good score for stats
	if _rtc_hits_this_visit.size() > 0:
		var last_entry: Dictionary = _rtc_hits_this_visit[-1]
		if last_entry.get("scoring", false):
			var last_text: String = last_entry.get("text", "")
			if last_text.begins_with("T"):
				_update_career_stats(-3.0, 10.0)
			elif last_text.begins_with("D"):
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
			_score_hud.show_message(_checkout_message(true), 3.0)
		else:
			_score_hud.show_message("ROUND COMPLETE!", 3.0)
		var tween := create_tween()
		tween.tween_interval(3.5)
		if _is_vs_ai:
			tween.tween_callback(_on_leg_complete.bind(true))
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
			_opp_rtc_hits_this_visit.append({"text": prefix + str(old_target), "scoring": true})

			_opp_rtc_target = new_target
			_score_hud.update_opponent_remaining_text(_opp_rtc_target_label())
		else:
			_opp_rtc_hits_this_visit.append(_rtc_non_scoring_entry(hit_number, multiplier))
	elif _opp_rtc_target == 21:
		# Must hit outer bull (25) specifically
		if hit_number == 25:
			_opp_rtc_hits_this_visit.append({"text": "OUTER", "scoring": true})
			_opp_rtc_target += 1
			_score_hud.update_opponent_remaining_text(_opp_rtc_target_label())
		else:
			_opp_rtc_hits_this_visit.append(_rtc_non_scoring_entry(hit_number, multiplier))
	else:
		# Must hit bullseye (double 25) specifically
		if hit_number == 25 and multiplier == 2:
			_opp_rtc_hits_this_visit.append({"text": "BULL", "scoring": true})
			_opp_rtc_target += 1
			_score_hud.update_opponent_remaining_text(_opp_rtc_target_label())
		else:
			_opp_rtc_hits_this_visit.append(_rtc_non_scoring_entry(hit_number, multiplier))

	# Check for AI win
	if _opp_rtc_target > 22:
		_cancel_ai_turn()
		_update_stats_on_opponent_checkout()
		_state = MatchState.FINISHED
		_score_hud.show_message(_checkout_message(false), 3.0)
		var tween := create_tween()
		tween.tween_interval(3.5)
		tween.tween_callback(_on_leg_complete.bind(false))
		return

	# Flag drink offer when AI reaches 18 (career RTC only, once per match)
	if not _drink_offered_at_18 and _opp_rtc_target >= 18 and CareerState.career_mode_active:
		_drink_offered_at_18 = true
		_drink_offer_pending = true

	_ai_advance_turn()

func _rtc_non_scoring_entry(hit_number: int, multiplier: int) -> Dictionary:
	if hit_number > 0 and multiplier > 0:
		var mp := ""
		if multiplier == 2:
			mp = "D"
		elif multiplier == 3:
			mp = "T"
		return {"text": mp + str(hit_number), "scoring": false}
	return {"text": "MISS", "scoring": false}

func _rtc_target_label() -> String:
	if _rtc_target <= 20:
		return "Next: " + str(_rtc_target)
	elif _rtc_target == 21:
		return "Next: OUTER"
	elif _rtc_target == 22:
		return "Next: BULL"
	else:
		return "DONE!"

func _opp_rtc_target_label() -> String:
	if _opp_rtc_target <= 20:
		return "Next: " + str(_opp_rtc_target)
	elif _opp_rtc_target == 21:
		return "Next: OUTER"
	elif _opp_rtc_target == 22:
		return "Next: BULL"
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

# ── Cinematic "Game Shot" camera ──

## Returns true if a single dart can finish the given score (even 2-40 or 50).
func _is_valid_single_dart_checkout(score: int) -> bool:
	if score == 50:
		return true  # Bullseye
	return score >= 2 and score <= 40 and score % 2 == 0

## Should we play the cinematic for this dart?
## Player on checkout: always. Opponent on checkout: 50% chance.
## Never in tutorial or sandbox.
func _should_play_cinematic() -> bool:
	if _is_tutorial() or _sandbox_mode or _is_free_throw():
		return false
	# Only trigger on the 3rd dart of a visit — keeps it dramatic without
	# interrupting the player's throwing rhythm on darts 1 and 2.
	if _darts_this_visit != 2:
		return false

	var on_checkout := false
	if _is_player_turn or not _is_vs_ai:
		# Player's dart
		if _is_countdown():
			on_checkout = _is_valid_single_dart_checkout(_score_remaining)
		elif _is_rtc():
			on_checkout = (_rtc_target == 22)  # Bullseye = final target
		if on_checkout:
			return true
	else:
		# Opponent's dart
		if _is_countdown():
			on_checkout = _is_valid_single_dart_checkout(_opp_score_remaining)
		elif _is_rtc():
			on_checkout = (_opp_rtc_target == 22)
		if on_checkout:
			return randf() < 0.5

	return false

## Start the cinematic sequence — freeze the physics dart, compute the score,
## and hand off to CinematicCamera.
func _start_game_shot_cinematic(dart: Dart) -> void:
	_cinematic_active = true
	_camera_rig.save_view()

	# The dart's XY at spawn IS the landing point (dart flies straight along Z).
	var landing_2d := Vector2(dart.position.x, dart.position.y)

	# Compute what this dart would score
	var score_data: Dictionary = BoardData.get_score(landing_2d)

	# Check if it's actually a checkout
	var is_checkout := false
	if _is_player_turn or not _is_vs_ai:
		# Player checkout: remaining must reach 0 AND hit a double
		if _is_countdown():
			var points: int = score_data.get("total", 0)
			var mult: int = score_data.get("multiplier", 0)
			is_checkout = (points == _score_remaining and mult == 2)
		elif _is_rtc():
			# RTC bullseye checkout: must hit double 25 (bullseye)
			var hit_number: int = score_data.get("number", 0)
			var mult: int = score_data.get("multiplier", 0)
			is_checkout = (hit_number == 25 and mult == 2)
	else:
		# Opponent checkout
		if _is_countdown():
			var points: int = score_data.get("total", 0)
			var mult: int = score_data.get("multiplier", 0)
			is_checkout = (points == _opp_score_remaining and mult == 2)
		elif _is_rtc():
			var hit_number: int = score_data.get("number", 0)
			var mult: int = score_data.get("multiplier", 0)
			is_checkout = (hit_number == 25 and mult == 2)

	# Freeze and hide the physics dart — cinematic builds its own visual dart
	dart.freeze = true
	dart.gravity_scale = 0.0
	dart.visible = false

	# Disable CameraRig controls during cinematic
	_camera_rig.set_process(false)
	_camera_rig.set_process_input(false)
	_camera_rig.set_process_unhandled_input(false)

	# Disable throwing
	_throw_system.set_can_throw(false)

	# Hide HUD during cinematic
	_score_hud.visible = false

	# Pick the correct dart tier for the cinematic visual
	var cinematic_tier: int
	if _is_player_turn or not _is_vs_ai:
		cinematic_tier = GameState.dart_tier
	else:
		cinematic_tier = _throw_system.ai_dart_tier

	# Create and play the cinematic
	_cinematic = CinematicCamera.new()
	add_child(_cinematic)
	_cinematic.setup(
		_camera_rig.get_camera(),
		Vector3(landing_2d.x, landing_2d.y, CinematicCamera.FLIGHT_START_Z),
		landing_2d,
		is_checkout,
		cinematic_tier,
		_is_player_turn
	)
	_cinematic.play()

	# When cinematic finishes, resume normal flow
	_cinematic.cinematic_finished.connect(
		_on_game_shot_cinematic_finished.bind(dart, score_data, landing_2d)
	)

## Called when the cinematic camera sequence finishes.
## Restores normal camera, places the dart, and runs the standard scoring logic.
func _on_game_shot_cinematic_finished(dart: Dart, score_data: Dictionary, hit_pos: Vector2) -> void:
	# Clean up the cinematic (restores camera FOV, removes visual dart and HUD)
	if _cinematic and is_instance_valid(_cinematic):
		_cinematic.cleanup()
		_cinematic.queue_free()
		_cinematic = null

	# Restore CameraRig controls
	_camera_rig.set_process(true)
	_camera_rig.set_process_input(true)
	_camera_rig.set_process_unhandled_input(true)
	_camera_rig.restore_view()

	# Show HUD again
	_score_hud.visible = true

	# Place the original physics dart at its resting position on the board
	var dart_tier := dart.get_tier()
	var resting_pos := CinematicCamera.get_resting_position(hit_pos, dart_tier)
	var resting_dir := CinematicCamera.get_resting_direction()
	dart.visible = true
	dart.global_position = resting_pos
	dart.look_at(dart.global_position + resting_dir, Vector3.UP)

	_cinematic_active = false

	# Feed the score into the normal scoring pipeline
	_on_dart_hit(score_data, hit_pos, dart)

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

# ── 180 flash effect ──

func _flash_180() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0.8)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	add_child(layer)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.5)
	tween.tween_callback(layer.queue_free)

# ── Career stats helpers ──

func _update_career_stats(nerves_delta: float, confidence_delta: float) -> void:
	if not CareerState.career_mode_active:
		return
	# Update raw values — drunk modifiers applied by _recalculate_drunk_stats
	var nerves_cap := _get_nerves_cap()
	_raw_nerves = clampf(_raw_nerves + nerves_delta, 0.0, nerves_cap)
	_raw_confidence = clampf(_raw_confidence + confidence_delta, 0.0, 100.0)
	_recalculate_drunk_stats()

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

## Apply a drink effect — tracks drinks count and liver damage.
## Nerve/confidence/anger effects are now driven by DrinkManager.drinks_level
## via _recalculate_drunk_stats(), not one-off deltas.
func apply_drink(is_full_pint: bool) -> void:
	if is_full_pint:
		_drinks_this_match += 2
		CareerState.liver_damage += 2.0 * maxf(0.5, 1.0 - CareerState.heft_tier * 0.15)
	else:
		_drinks_this_match += 1
		CareerState.liver_damage += 1.0 * maxf(0.5, 1.0 - CareerState.heft_tier * 0.15)
	# Recalculate stats (DrinkManager.drinks_level already updated by caller)
	_recalculate_drunk_stats()
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

## One-time doubles tip — show when the player's remaining score first reaches
## a value where a single dart could win (even numbers 2-40, or 50 for bullseye).
func _check_doubles_tip() -> void:
	if not CareerState.career_mode_active or CareerState.doubles_tip_shown:
		return
	if _score_remaining == 50 or (_score_remaining >= 2 and _score_remaining <= 40 and _score_remaining % 2 == 0):
		_score_hud.show_doubles_tip()

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
	_gameplay_anger = clampf(_gameplay_anger + delta, 0.0, 100.0)
	_recalculate_drunk_stats()

# ── Drunk effects on stats ──

## Signal handler for DrinkManager.drinks_changed — recalc whenever drinks change
func _on_drinks_changed(_level: int) -> void:
	_recalculate_drunk_stats()

## Fired once when player crosses from blurry drunk (7+) to clear tipsy (4-6)
func _on_sweet_spot_reached() -> void:
	_score_hud.show_message("Starting to see a bit clearer now...", 3.0)

## Central recalculation — derives displayed stats from raw + drunk modifiers
func _recalculate_drunk_stats() -> void:
	var dl := DrinkManager.drinks_level
	var nerves_cap := _get_nerves_cap()

	# Nerves: raw * modifier (drunk suppresses nerves)
	var nerve_mod := _get_drunk_nerve_modifier(dl)
	_player_nerves = clampf(_raw_nerves * nerve_mod, 0.0, nerves_cap)

	# Confidence: max of raw and drunk floor (drunk lifts the floor)
	var conf_floor := _get_drunk_confidence_floor(dl)
	_player_confidence = clampf(maxf(_raw_confidence, conf_floor), 0.0, 100.0)

	# Anger: gameplay + drunk contribution, with dampening and hard cap
	var drunk_anger := _get_drunk_anger(dl)
	var total_anger := _gameplay_anger + drunk_anger
	# Soft dampening above 60: excess scaled by 0.4
	if total_anger > 60.0:
		total_anger = 60.0 + (total_anger - 60.0) * 0.4
	# Hard cap at 82 — player anger NEVER reaches 100 from drink alone
	_player_anger = clampf(total_anger, 0.0, 82.0)

	if not _suppress_hud_update and _is_player_turn:
		_score_hud.update_stats_bars(_player_dart_quality, _player_nerves, _player_confidence, _player_anger)
	_throw_system.career_scatter_mult = get_career_scatter_mult()

	# High nerves warning — mate suggests a drink (once per match, L2+)
	if not _high_nerves_warning_shown and _player_nerves >= 75.0 and CareerState.career_mode_active and CareerState.career_level >= 2:
		_high_nerves_warning_shown = true
		var player_name: String = DartData.get_character_name(GameState.character)
		_score_hud.show_message(player_name + ", you look like a wreck up there. Get some booze in you or those darts are going everywhere.", 5.0)

## Nerve modifier: drinks suppress nerves. Floor depends on career level.
func _get_drunk_nerve_modifier(dl: int) -> float:
	if dl < 4:
		return 1.0
	# Level-based floor: L1-4 = 0.0 (full suppression), L5+ gets partial
	var level: int = CareerState.career_level
	var floor_mod: float
	if level <= 4:
		floor_mod = 0.0
	elif level == 5:
		floor_mod = 0.08
	elif level == 6:
		floor_mod = 0.16
	else:
		floor_mod = 0.25
	# Ramp from 1.0 toward floor_mod over drinks 4-7
	var t := clampf(float(dl - 3) / 4.0, 0.0, 1.0)  # 0 at 3, 1 at 7+
	return lerpf(1.0, floor_mod, t)

## Confidence floor: drunk raises the minimum displayed confidence
func _get_drunk_confidence_floor(dl: int) -> float:
	if dl < 4:
		return 0.0
	# Diminishing returns: each additional drink adds less
	# drinks 4→60, 6→77, 8→88, 10→92
	return 100.0 * (1.0 - pow(0.8, dl - 3))

## Drunk anger: exponential curve starting at 4 drinks, capped at 60
func _get_drunk_anger(dl: int) -> float:
	if dl <= 3:
		return 0.0
	return minf(60.0, 0.6 * pow(float(dl - 3), 2.0))

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

## Opponent anger has hit 100% — car park fight! Winner wins the whole match.
func _trigger_fight_scene() -> void:
	_cancel_ai_turn()
	_throw_system.set_can_throw(false)
	_state = MatchState.FINISHED
	_score_hud.show_message("FIGHT!", 2.0)

	# Store fight context so fight screen can set up
	CareerState.fight_pending = true
	CareerState.fight_opponent_id = _opponent_id

	# Brief pause to show "FIGHT!" then transition
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_callback(_goto_fight_screen)

func _goto_fight_screen() -> void:
	var fight := CarParkFight.create_from_match(
		CareerState.fight_opponent_id,
		DrinkManager.drinks_level
	)
	fight.fight_finished.connect(_on_fight_finished)
	get_tree().root.add_child(fight)
	# Hide the match scene — fight takes over
	visible = false
	_score_hud.visible = false

func _on_fight_finished(result: int) -> void:
	CareerState.fight_pending = false
	if result == CarParkFight.RESULT_WIN or result == CarParkFight.RESULT_SCRAPE:
		_on_player_wins()
	else:
		_on_player_loses()

# ── Multi-leg match handling ──

func _leg_ordinal(n: int) -> String:
	match n:
		1: return "FIRST"
		2: return "SECOND"
		3: return "THIRD"
		4: return "FOURTH"
		5: return "FIFTH"
		6: return "SIXTH"
		7: return "SEVENTH"
		_: return str(n) + "TH"

func _checkout_message(player_won: bool) -> String:
	# Single-leg match
	if _legs_to_win <= 1:
		if player_won:
			return "GAME SHOT!"
		else:
			return OpponentData.get_display_name(_opponent_id) + " WINS!"
	# Multi-leg: check if this leg decides the match
	var winning_count: int
	if player_won:
		winning_count = _player_legs_won + 1
	else:
		winning_count = _opponent_legs_won + 1
	if winning_count >= _legs_to_win:
		return "GAME SHOT\nAND THE MATCH!"
	# Non-deciding leg
	var leg_number := _player_legs_won + _opponent_legs_won + 1
	return "GAME SHOT\nAND THE " + _leg_ordinal(leg_number) + " LEG!"

func _on_leg_complete(player_won: bool) -> void:
	# Single-leg match — go straight to win/loss
	if _legs_to_win <= 1:
		if player_won:
			_on_player_wins()
		else:
			_on_player_loses()
		return

	if player_won:
		_player_legs_won += 1
	else:
		_opponent_legs_won += 1

	# Update HUD
	_score_hud.update_leg_score(_player_legs_won, _opponent_legs_won)

	# Mad Dog throw/bribe triggers
	if _opponent_id == "mad_dog" and CareerState.career_mode_active and not CareerState.exhibition_mode:
		var total_legs := _player_legs_won + _opponent_legs_won
		# Track leg 4 result: did the player honour the deal?
		# Leg 4 = the leg that just completed when total_legs reaches 4
		if total_legs == 4 and CareerState.throw_leg_required:
			CareerState.throw_leg_honoured = not player_won  # True if opponent won leg 4
		# Bribe offer when Mad Dog is one leg from winning
		if not player_won and _opponent_legs_won == _legs_to_win - 1 and not _bribe_used:
			_bribe_offer_pending = true

	# Check for match win/loss
	if _player_legs_won >= _legs_to_win:
		_on_player_wins()
		return
	if _opponent_legs_won >= _legs_to_win:
		_on_player_loses()
		return

	# More legs to play — brief pause then start new leg
	# (the checkout message already announced which leg it was)
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(_start_new_leg.bind(not player_won))

func _start_new_leg(player_throws_first: bool) -> void:
	# Clear darts from the board
	for dart in _active_darts:
		if is_instance_valid(dart):
			dart.queue_free()
	_active_darts.clear()

	# Reset scores for the new leg
	if _is_countdown():
		_score_remaining = GameState.starting_score
		_visit_score = 0
		_visit_score_before = _score_remaining
		_opp_score_remaining = GameState.starting_score
		_opp_visit_score = 0
		_opp_visit_score_before = _opp_score_remaining
		_score_hud.update_remaining(_score_remaining)
		_score_hud.update_opponent_score(_opp_score_remaining)
	else:
		_rtc_target = 1
		_opp_rtc_target = 1
		_score_hud.update_remaining_text(_rtc_target_label())
		_score_hud.update_opponent_remaining_text(_opp_rtc_target_label())

	# Reset dart tracking for the new leg
	_darts_this_visit = 0
	_visit_dart_labels.clear()
	_state = MatchState.THROWING

	# Set who throws first (real darts rule: loser of previous leg throws first)
	_is_player_turn = player_throws_first
	_score_hud.update_turn_indicator(_is_player_turn)

	# Career stats (nerves, confidence, anger) carry over between legs.
	# Drinks reset completely — player sobers up between games.
	if CareerState.career_mode_active:
		DrinkManager.reset()

	_start_visit()

func _on_player_wins() -> void:
	if CareerState.career_mode_active:
		CareerState.confidence_carry = _raw_confidence * 0.5
		if CareerState.exhibition_mode:
			# Exhibition win: prize money, no career progression
			var prize: int = ExhibitionData.current_prize
			CareerState.money += prize
			GameState.match_won = true
			GameState.match_prize = prize
			GameState.match_career_over = false
		else:
			CareerState.losses_at_current_level = 0
			var prize: int = OpponentData.get_prize_money(_opponent_id)
			CareerState.money += prize
			CareerState.career_level += 1
			GameState.match_won = true
			GameState.match_prize = prize
			GameState.match_career_over = false
		# Drunk win: adrenaline snap sober over ~2s before results
		if DrinkManager.drinks_level > 3:
			DrinkManager.sober_snap()
			var tween := create_tween()
			tween.tween_interval(2.5)
			tween.tween_callback(_goto_results)
		else:
			_goto_results()
		return
	_restart_game()

func _on_player_loses() -> void:
	if CareerState.career_mode_active:
		CareerState.confidence_carry = 20.0
		if CareerState.exhibition_mode:
			# Exhibition loss: no strike, no career impact
			GameState.match_won = false
			GameState.match_prize = 0
			GameState.match_career_over = false
		else:
			CareerState.losses_at_current_level += 1
			var max_losses: int = OpponentData.get_max_losses(_opponent_id)
			var is_career_over: bool = CareerState.losses_at_current_level >= max_losses
			GameState.match_won = false
			GameState.match_prize = 0
			GameState.match_career_over = is_career_over
		# Drunk loss: drunkenness spirals worse, then fade to black
		if DrinkManager.drinks_level > 3:
			DrinkManager.ramp_to_blackout(5.0)
			var tween := create_tween()
			tween.tween_interval(5.5)
			tween.tween_callback(_fade_to_black_and_results)
		else:
			_goto_results()
		return
	_restart_game()

func _fade_to_black_and_results() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	var black := ColorRect.new()
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.color = Color(0, 0, 0, 0)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	add_child(layer)
	var tween := create_tween()
	tween.tween_property(black, "color:a", 1.0, 1.0)
	tween.tween_callback(_goto_results)

func _trigger_drink_death() -> void:
	# Player took a drink after the doctor's death warning — cardiac arrest
	_score_hud.show_message("You take a sip.\n\nEverything goes dark.", 4.0)
	GameState.match_won = false
	GameState.match_prize = 0
	GameState.match_career_over = true
	CareerState.doctor_death_warning = false  # Clear flag
	CareerState.drink_death_occurred = true   # Special death ending
	# Dramatic blackout then results
	DrinkManager.ramp_to_blackout(3.0)
	var tween := create_tween()
	tween.tween_interval(4.5)
	tween.tween_callback(_fade_to_black_and_results)

func _goto_results() -> void:
	_cancel_ai_turn()
	DrinkManager.clear_effects()
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

# ── Debug skip menu (hidden 10-tap trigger) ──

var _debug_overlay: Control

func _show_debug_menu() -> void:
	# Don't show if already visible
	if _debug_overlay and is_instance_valid(_debug_overlay):
		return

	_cancel_ai_turn()
	_throw_system.set_can_throw(false)

	_debug_overlay = _make_popup_overlay()

	var panel := _make_popup_panel(Vector2(110, 400), 500)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title := Label.new()
	title.text = "DEBUG MENU"
	UIFont.apply(title, UIFont.BODY)
	title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(436, 0)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var win_btn := _make_popup_button("Auto Win", Color(0.15, 0.45, 0.15))
	win_btn.pressed.connect(func() -> void:
		_debug_overlay.queue_free()
		_debug_overlay = null
		_state = MatchState.FINISHED
		_on_player_wins()
	)
	vbox.add_child(win_btn)

	var lose_btn := _make_popup_button("Auto Lose", Color(0.55, 0.15, 0.15))
	lose_btn.pressed.connect(func() -> void:
		_debug_overlay.queue_free()
		_debug_overlay = null
		_state = MatchState.FINISHED
		_on_player_loses()
	)
	vbox.add_child(lose_btn)

	var cancel_btn := _make_popup_button("Cancel", Color(0.25, 0.25, 0.3))
	cancel_btn.pressed.connect(func() -> void:
		_debug_overlay.queue_free()
		_debug_overlay = null
		_throw_system.set_can_throw(true)
	)
	vbox.add_child(cancel_btn)

	panel.add_child(vbox)
	_debug_overlay.add_child(panel)
	_fade_in_overlay(_debug_overlay)

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
	# Doctor death warning — any drink in the final kills the player
	if CareerState.doctor_death_warning:
		var is_drink := consequence_id in ["add_half_pint", "buy_half_pint", "accept_free_pint", "buy_round"]
		if is_drink:
			_trigger_drink_death()
			return

	if consequence_id == "add_half_pint":
		# Free half pint from barman — set up animated nerves decrease
		_nerves_before_drink = _player_nerves
		_suppress_hud_update = true
		DrinkManager.add_drink(true, 2)  # Free half pint = 2 units (visual effects)
		apply_drink(false)               # Career stats: nerves -8, anger +2
		_suppress_hud_update = false
		_pending_nerves_anim = _player_nerves
		# Trigger second drink offer after the player's next visit
		_second_drink_after_visits = 1
	elif consequence_id == "buy_half_pint":
		# Paid half pint — player is paying this time
		_nerves_before_drink = _player_nerves
		_suppress_hud_update = true
		DrinkManager.add_drink(true, 2)  # Half pint = 2 units (payment handled below)
		apply_drink(false)               # Career stats: nerves -8, anger +2
		_suppress_hud_update = false
		_pending_nerves_anim = _player_nerves
		# Deduct cost from career money
		CareerState.money -= DrinkManager.COST_PER_UNIT
		_score_hud.update_balance(CareerState.money)
	elif consequence_id == "accept_free_pint":
		# Companion's round — free pint for the player (1 pint = 4 units)
		_nerves_before_drink = _player_nerves
		_suppress_hud_update = true
		DrinkManager.add_drink(true, 4)  # Free pint (visual effects)
		apply_drink(true)                # Career stats: full pint effects
		_suppress_hud_update = false
		_pending_nerves_anim = _player_nerves
		_check_drunk_warning()
	elif consequence_id == "buy_round":
		# Player's round — buy pints for everyone, player drinks 1 pint
		_nerves_before_drink = _player_nerves
		_suppress_hud_update = true
		DrinkManager.add_drink(true, 4)  # Pint visual effects (payment below)
		apply_drink(true)                # Career stats: full pint effects
		_suppress_hud_update = false
		_pending_nerves_anim = _player_nerves
		# Deduct round cost from career money
		var config = DrinkManager.get_level_config(CareerState.career_level)
		if config != null:
			var round_cost: int = config["pint_price"] * config["round_size"]
			CareerState.money -= round_cost
			_score_hud.update_balance(CareerState.money)
		_check_drunk_warning()
	elif consequence_id == "reject_full_pint":
		# Full pint rejected — loop back to the choice screen
		_re_offer_drink = true

func _check_drunk_warning() -> void:
	if _drunk_warning_shown:
		return
	if DrinkManager.drinks_level >= 7:
		_drunk_warning_shown = true
		var char_first: String = DartData.get_character_name(GameState.character)
		var tween := create_tween()
		tween.tween_interval(1.0)
		tween.tween_callback(func():
			_score_hud.show_message("Take it easy mate... if you start to think you're a state, you definitely are a state.", 4.0)
		)

# ── Mad Dog bribe popup (L5 only) ─────────────────────────

func _show_bribe_popup() -> void:
	var max_bribe: int = _opponent_legs_won - _player_legs_won
	if max_bribe <= 0:
		_start_visit()
		return

	var overlay := Control.new()
	overlay.size = Vector2(720, 1280)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100
	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.5)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dimmer)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.94)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.85, 0.6, 0.15, 0.6)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(50, 200)
	panel.size = Vector2(620, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	var caller_tex := load("res://The Contact Unknown caller cropped.png")
	if caller_tex:
		var portrait := TextureRect.new()
		portrait.texture = caller_tex
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(560, 120)
		vbox.add_child(portrait)

	var name_lbl := Label.new()
	name_lbl.text = "UNKNOWN NUMBER"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
	UIFont.apply(name_lbl, UIFont.BODY)
	vbox.add_child(name_lbl)

	var text_lbl := Label.new()
	text_lbl.text = "\"She's one leg away from finishing you.\"\n\nA long pause.\n\n\"I can make a call. Fix a few legs.\nHow many do you want back?\""
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.custom_minimum_size = Vector2(560, 0)
	text_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	UIFont.apply(text_lbl, UIFont.BODY)
	vbox.add_child(text_lbl)

	panel.add_child(vbox)
	overlay.add_child(panel)

	var btn_col := VBoxContainer.new()
	btn_col.add_theme_constant_override("separation", 12)
	btn_col.position = Vector2(110, 740)
	btn_col.size = Vector2(500, 0)

	for i in range(1, max_bribe + 1):
		var leg_word: String = "LEG" if i == 1 else "LEGS"
		var btn := _make_popup_button(str(i) + " " + leg_word, Color(0.5, 0.15, 0.15))
		btn.custom_minimum_size = Vector2(480, 0)
		var legs_to_bribe: int = i
		btn.pressed.connect(func():
			overlay.queue_free()
			_bribe_used = true
			CareerState.bribe_legs_used = legs_to_bribe
			_opponent_legs_won -= legs_to_bribe
			_score_hud.update_leg_score(_player_legs_won, _opponent_legs_won)
			var new_score := str(_player_legs_won) + " - " + str(_opponent_legs_won)
			_score_hud.show_message("The fix is in.\nLegs: " + new_score, 3.0)
			var delay := create_tween()
			delay.tween_interval(3.5)
			delay.tween_callback(_start_visit)
		)
		btn_col.add_child(btn)

	var no_btn := _make_popup_button("NO THANKS", Color(0.2, 0.2, 0.3))
	no_btn.custom_minimum_size = Vector2(480, 0)
	no_btn.pressed.connect(func():
		overlay.queue_free()
		_bribe_used = true
		_start_visit()
	)
	btn_col.add_child(no_btn)

	overlay.add_child(btn_col)

	overlay.modulate = Color(1, 1, 1, 0)
	_score_hud._popup_layer.add_child(overlay)
	var fade := create_tween()
	fade.tween_property(overlay, "modulate", Color(1, 1, 1, 1), 0.25)

# ── Pre-drink advice popup (first visit, career L2+) ─────────────────────────

func _show_pre_drink_advice() -> void:
	# Wait 1.5 seconds so the player sees the board first
	var delay_tween := create_tween()
	delay_tween.tween_interval(1.5)
	delay_tween.tween_callback(_display_pre_drink_popup)

func _display_pre_drink_popup() -> void:
	var units := _pre_drink_units_at_start
	# Pick advice text based on how much they drank
	var advice: String
	if units <= 4:
		advice = "Those pre-drinks really settled your nerves.\n\nNice and steady."
	elif units <= 6:
		advice = "You've got a good base, but remember to keep drinking or you'll get nervy.\n\nTry and keep that level."
	elif units <= 8:
		advice = "Looks like you went a bit heavy on the drinks there.\n\nTry and hold it together."
	else:
		advice = "Mate... you can barely see straight. Good luck with that.\n\nMaybe try and avoid that one in the future."

	# Build popup overlay
	var overlay := Control.new()
	overlay.size = Vector2(720, 1280)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100

	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.5)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dimmer)

	# Panel
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.07, 0.12, 0.94)
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_color = Color(0.85, 0.6, 0.15, 0.6)
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.position = Vector2(50, 350)
	panel.size = Vector2(620, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	# Mate portrait
	var tex = load("res://Mate for Level 2 - Alan.png")
	if tex:
		var portrait := TextureRect.new()
		portrait.texture = tex
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(560, 120)
		vbox.add_child(portrait)

	# Speaker name
	var name_label := Label.new()
	name_label.text = "YOUR MATE"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
	UIFont.apply(name_label, UIFont.BODY)
	vbox.add_child(name_label)

	# Advice text
	var advice_label := Label.new()
	advice_label.text = '"' + advice + '"'
	advice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	advice_label.custom_minimum_size = Vector2(560, 0)
	advice_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	UIFont.apply(advice_label, UIFont.BODY)
	vbox.add_child(advice_label)

	panel.add_child(vbox)
	overlay.add_child(panel)

	# Dismiss button
	var btn := Button.new()
	btn.text = "LET'S GO"
	UIFont.apply_button(btn, UIFont.BODY)
	btn.custom_minimum_size = Vector2(300, 60)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.5, 0.2)
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
	btn_style.content_margin_left = 15
	btn_style.content_margin_right = 15
	btn_style.content_margin_top = 10
	btn_style.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.2, 0.6, 0.3)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_stylebox_override("pressed", btn_hover)
	btn.add_theme_color_override("font_color", Color.WHITE)

	var btn_wrapper := CenterContainer.new()
	btn_wrapper.position = Vector2(0, 850)
	btn_wrapper.size = Vector2(720, 80)
	btn_wrapper.add_child(btn)
	overlay.add_child(btn_wrapper)

	# Fade in — add to popup layer so it renders above drunk vision overlay
	overlay.modulate = Color(1, 1, 1, 0)
	_score_hud._popup_layer.add_child(overlay)
	var fade := create_tween()
	fade.tween_property(overlay, "modulate", Color(1, 1, 1, 1), 0.25)

	# Dismiss callback
	btn.pressed.connect(func():
		overlay.queue_free()
		_throw_system.set_can_throw(true)
		_start_confidence_decay()
	)
