extends Node3D
class_name MatchManager

enum MatchState { THROWING, BETWEEN_DARTS, VISIT_SUMMARY, CLEARING, FINISHED }

const DARTS_PER_VISIT := 3
const BETWEEN_DART_DELAY := 0.6
const SUMMARY_DISPLAY_TIME := 2.0

var _state: MatchState = MatchState.THROWING
var _darts_this_visit: int = 0
var _active_darts: Array[Dart] = []
var _visit_dart_labels: Array = []

# ── Countdown mode state ──
var _score_remaining: int = 501
var _visit_score: int = 0
var _visit_score_before: int = 501

# ── Round the Clock state ──
# Target goes 1..20 then 21=first bull, 22=second bull. Done when > 22.
var _rtc_target: int = 1
var _rtc_hits_this_visit: Array = []  # What numbers were ticked off this visit

var _dartboard: Dartboard
var _throw_system: ThrowSystem
var _camera_rig: CameraRig
var _score_hud: ScoreHUD
var _darts_container: Node3D

func _ready() -> void:
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

	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-15), deg_to_rad(10), 0)
	light.light_energy = 1.5
	light.shadow_enabled = false
	add_child(light)

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

	_score_hud = ScoreHUD.new()
	add_child(_score_hud)

func _connect_signals() -> void:
	_throw_system.dart_thrown.connect(_on_dart_thrown)

func _init_game_mode() -> void:
	if _is_countdown():
		_score_remaining = GameState.starting_score
		_visit_score_before = _score_remaining
	else:
		_rtc_target = 1

func _is_countdown() -> bool:
	return GameState.game_mode == GameState.GameMode.COUNTDOWN

func _is_rtc() -> bool:
	return GameState.game_mode == GameState.GameMode.ROUND_THE_CLOCK

# ── Visit flow ──

func _start_visit() -> void:
	_state = MatchState.THROWING
	_darts_this_visit = 0
	_visit_dart_labels.clear()

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

	if _is_countdown():
		_handle_countdown_hit(score_data)
	else:
		_handle_rtc_hit(score_data)

# ── Countdown mode (101 / 301 / 501) ──

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
	elif new_remaining == 0 and score_data.get("multiplier", 1) != 2:
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

# ── Round the Clock mode ──

func _handle_rtc_hit(score_data: Dictionary) -> void:
	var hit_number: int = score_data.get("number", 0)
	var multiplier: int = score_data.get("multiplier", 0)

	if _rtc_target <= 20:
		# Targeting a number 1-20
		if hit_number == _rtc_target and multiplier > 0:
			# Hit the target number
			var advance := multiplier  # single=1, double=2, treble=3
			var old_target := _rtc_target

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
		_score_hud.show_message("ROUND COMPLETE!", 3.0)
		var tween := create_tween()
		tween.tween_interval(3.5)
		tween.tween_callback(_restart_game)
		return

	_advance_turn()

func _rtc_target_label() -> String:
	if _rtc_target <= 20:
		return "Next: " + str(_rtc_target)
	elif _rtc_target == 21:
		return "Next: BULL (1 of 2)"
	elif _rtc_target == 22:
		return "Next: BULL (2 of 2)"
	else:
		return "DONE!"

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

func _schedule_clear() -> void:
	var tween := create_tween()
	tween.tween_interval(SUMMARY_DISPLAY_TIME)
	tween.tween_callback(_clear_and_next_visit)

func _clear_and_next_visit() -> void:
	for dart in _active_darts:
		if is_instance_valid(dart):
			dart.queue_free()
	_active_darts.clear()
	_start_visit()

func _restart_game() -> void:
	for dart in _active_darts:
		if is_instance_valid(dart):
			dart.queue_free()
	_active_darts.clear()
	# Go back to menu
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
