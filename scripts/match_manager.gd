extends Node3D
class_name MatchManager

enum MatchState { THROWING, BETWEEN_DARTS, VISIT_SUMMARY, CLEARING, AI_THROWING, FINISHED }

const DARTS_PER_VISIT := 3
const BETWEEN_DART_DELAY := 0.2
const SUMMARY_DISPLAY_TIME := 2.0
const AI_SUMMARY_DISPLAY_TIME := 1.5

var _state: MatchState = MatchState.THROWING
var _darts_this_visit: int = 0
var _active_darts: Array[Dart] = []
var _visit_dart_labels: Array = []

# ── Countdown mode state (player) ──
var _score_remaining: int = 501
var _visit_score: int = 0
var _visit_score_before: int = 501

# ── Round the Clock state (player) ──
# Target goes 1..20 then 21=first bull, 22=second bull. Done when > 22.
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

var _dartboard: Dartboard
var _throw_system: ThrowSystem
var _camera_rig: CameraRig
var _score_hud: ScoreHUD
var _darts_container: Node3D
var _tutorial_overlay: TutorialOverlay
var _tutorial_last_was_hit := false

func _ready() -> void:
	_is_vs_ai = GameState.is_vs_ai
	_opponent_id = GameState.opponent_id
	_setup_environment()
	_build_scene()
	_connect_signals()
	_init_game_mode()
	_start_visit()

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

	# LED oche lighting — bright spots from above, like TV darts coverage.
	# Three spots at different angles so darts are always well-lit.
	var spot_positions := [
		Vector3(0.0, 2.5, 2.5),    # Centre-above: main key light
		Vector3(-1.8, 2.0, 2.0),   # Left-above: fills left side
		Vector3(1.8, 2.0, 2.0),    # Right-above: fills right side
	]
	var spot_energies := [2.5, 1.5, 1.5]

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

	_score_hud = ScoreHUD.new()
	add_child(_score_hud)

func _connect_signals() -> void:
	_throw_system.dart_thrown.connect(_on_dart_thrown)
	if _is_tutorial():
		_setup_tutorial()

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

	# Set up dual HUD if VS mode
	if _is_vs_ai:
		_score_hud.setup_vs_mode(_opponent_id)
		_score_hud.update_turn_indicator(true)
		if _is_countdown():
			_score_hud.update_opponent_score(_opp_score_remaining)
		else:
			_score_hud.update_opponent_remaining_text(_opp_rtc_target_label())

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
		_throw_system.set_can_throw(true)

		if _is_vs_ai:
			_score_hud.update_turn_indicator(true)
	else:
		# AI's turn
		_start_ai_visit()

func _start_ai_visit() -> void:
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

func _on_dart_thrown(dart: Dart) -> void:
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
		# Must finish on a double (or inner bull which is 50)
		var mult: int = score_data.get("multiplier", 1)
		var num: int = score_data.get("number", 0)
		if mult != 2 and num != 50:
			is_bust = true

	if is_bust:
		_score_remaining = _visit_score_before
		_score_hud.update_remaining(_score_remaining)
		_state = MatchState.VISIT_SUMMARY
		_throw_system.set_can_throw(false)
		_score_hud.show_bust_summary(_visit_dart_labels, _score_remaining)
		_schedule_clear()
		return

	_score_remaining = _visit_score_before - _visit_score
	_score_hud.update_remaining(_score_remaining)

	# Checkout
	if _score_remaining == 0:
		_state = MatchState.FINISHED
		_throw_system.set_can_throw(false)
		_score_hud.show_message("CHECKOUT!", 3.0)
		var tween := create_tween()
		tween.tween_interval(3.5)
		tween.tween_callback(_restart_game)
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
		var mult: int = score_data.get("multiplier", 1)
		var num: int = score_data.get("number", 0)
		if mult != 2 and num != 50:
			is_bust = true

	if is_bust:
		# AI busted — revert score and end turn immediately
		_opp_score_remaining = _opp_visit_score_before
		_score_hud.update_opponent_score(_opp_score_remaining)
		_cancel_ai_turn()
		var opp_name := OpponentData.get_display_name(_opponent_id)
		_score_hud.show_bust_summary_named(opp_name, _visit_dart_labels, _opp_score_remaining)
		_state = MatchState.VISIT_SUMMARY
		_schedule_clear()
		return

	_opp_score_remaining = _opp_visit_score_before - _opp_visit_score
	_score_hud.update_opponent_score(_opp_score_remaining)

	# AI checkout
	if _opp_score_remaining == 0:
		_cancel_ai_turn()
		_state = MatchState.FINISHED
		var opp_name := OpponentData.get_display_name(_opponent_id)
		_score_hud.show_message(opp_name + " WINS!", 3.0)
		var tween := create_tween()
		tween.tween_interval(3.5)
		tween.tween_callback(_restart_game)
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
	else:
		# Targeting bullseye (target 21 or 22)
		if hit_number == 25 or hit_number == 50:
			# Any bull counts
			_rtc_hits_this_visit.append("BULL")
			_rtc_target += 1
			_score_hud.update_remaining_text(_rtc_target_label())
		else:
			_rtc_hits_this_visit.append("-")

	# Check for win
	if _rtc_target > 22:
		_state = MatchState.FINISHED
		_throw_system.set_can_throw(false)
		if _is_vs_ai:
			_score_hud.show_message("YOU WIN!", 3.0)
		else:
			_score_hud.show_message("ROUND COMPLETE!", 3.0)
		var tween := create_tween()
		tween.tween_interval(3.5)
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
	else:
		if hit_number == 25 or hit_number == 50:
			_opp_rtc_hits_this_visit.append("BULL")
			_opp_rtc_target += 1
			_score_hud.update_opponent_remaining_text(_opp_rtc_target_label())
		else:
			_opp_rtc_hits_this_visit.append("-")

	# Check for AI win
	if _opp_rtc_target > 22:
		_cancel_ai_turn()
		_state = MatchState.FINISHED
		var opp_name := OpponentData.get_display_name(_opponent_id)
		_score_hud.show_message(opp_name + " WINS!", 3.0)
		var tween := create_tween()
		tween.tween_interval(3.5)
		tween.tween_callback(_restart_game)
		return

	_ai_advance_turn()

func _rtc_target_label() -> String:
	if _rtc_target <= 20:
		return "Next: " + str(_rtc_target)
	elif _rtc_target == 21:
		return "Next: BULL (1 of 2)"
	elif _rtc_target == 22:
		return "Next: BULL (2 of 2)"
	else:
		return "DONE!"

func _opp_rtc_target_label() -> String:
	if _opp_rtc_target <= 20:
		return "Next: " + str(_opp_rtc_target)
	elif _opp_rtc_target == 21:
		return "BULL (1 of 2)"
	elif _opp_rtc_target == 22:
		return "BULL (2 of 2)"
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
		)

## AI turn advancement — schedule the next dart or end the visit
func _ai_advance_turn() -> void:
	_ai_darts_thrown += 1

	if _darts_this_visit >= DARTS_PER_VISIT:
		# AI visit complete — show summary
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
