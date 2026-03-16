extends Node3D
class_name ThrowSystem

signal dart_thrown(dart: Dart)
signal swipe_update(speed: float)
signal swipe_ended()
signal throw_rejected

const THROW_ZONE_TOP := 0.08      # Only reject touches in top 8% (HUD area)
const MIN_SWIPE_DISTANCE := 30.0  # Minimum pixels to register as a throw
const DART_SPEED_MIN := 6.0       # Minimum throw speed
const DART_SPEED_MAX := 14.0      # Maximum throw speed
const SWIPE_SPEED_FOR_MAX := 1500.0  # Swipe pixels/sec for max power
const MIN_SWIPE_SPEED := 300.0       # Below this, throw is rejected (too slow to fly)
const SCATTER_AMOUNT := 0.12      # Random scatter on the board (in board units)
const MEDIUM_SWIPE_SPEED := 750.0    # Reference speed (px/sec) where speed nudge = 0
const SPEED_NUDGE_MAX := 0.1         # Max nudge in board units (subtle — prevents upward bias)

var _touch_start_pos := Vector2.ZERO
var _touch_start_time := 0.0
var _is_touching := false
var _can_throw := true
var _viewport_size := Vector2(720, 1280)
var _darts_container: Node3D
var _camera: Camera3D
var _dart_tier: int = 0           # Current dart tier (affects scatter)
var _character: DartData.Character = DartData.Character.DAI

## Career mode scatter multiplier — set by MatchManager before each player visit.
## 1.0 = no effect (practice mode). Values > 1 = worse scatter, < 1 = better.
var career_scatter_mult: float = 1.0

# Track recent position for speed calculation (used by tutorial speed indicator)
var _last_move_pos := Vector2.ZERO
var _last_move_time := 0.0

# ── Multi-touch tracking ──
# Independently tracks finger count so we can cancel throws during pinch/zoom gestures
var _active_touch_count := 0
var _gesture_occurred := false  # Set true when 2+ fingers detected, stays until all lift

func setup(darts_container: Node3D, viewport_size: Vector2, camera: Camera3D) -> void:
	_darts_container = darts_container
	_viewport_size = viewport_size
	_camera = camera
	_character = GameState.character

func set_dart_tier(tier: int) -> void:
	_dart_tier = tier

func set_can_throw(can: bool) -> void:
	_can_throw = can

# Track all touches via _input so we know when multi-touch is happening.
# This runs alongside camera_rig's _input — neither consumes the events,
# they just independently track state.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_active_touch_count += 1
		else:
			_active_touch_count = maxi(_active_touch_count - 1, 0)

		# Second finger down — cancel any in-progress throw aim
		if _active_touch_count > 1:
			_gesture_occurred = true
			if _is_touching:
				_is_touching = false

		# All fingers lifted — reset gesture flag for next touch
		if _active_touch_count == 0:
			_gesture_occurred = false

func _unhandled_input(event: InputEvent) -> void:
	if not _can_throw:
		return

	# Ignore all single-touch events if a gesture just happened
	if _gesture_occurred:
		return

	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_on_touch_start(touch.position)
		else:
			_on_touch_end(touch.position)

	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		_on_touch_move(drag.position)

func _on_touch_start(pos: Vector2) -> void:
	# Only start if touch is in the throw zone (bottom portion of screen)
	if pos.y < _viewport_size.y * THROW_ZONE_TOP:
		return
	_is_touching = true
	_touch_start_pos = pos
	_touch_start_time = Time.get_ticks_msec() / 1000.0
	_last_move_pos = pos
	_last_move_time = _touch_start_time


func _on_touch_move(pos: Vector2) -> void:
	if not _is_touching:
		return

	# Track speed for the tutorial's speed indicator
	var now := Time.get_ticks_msec() / 1000.0
	var dt := now - _last_move_time
	if dt > 0.001:
		var speed := (pos - _last_move_pos).length() / dt
		swipe_update.emit(speed)
	_last_move_pos = pos
	_last_move_time = now

func _on_touch_end(pos: Vector2) -> void:
	if not _is_touching:
		return
	_is_touching = false
	swipe_ended.emit()

	# Calculate swipe speed
	var swipe_delta := _touch_start_pos - pos  # Positive Y = swiped up
	var swipe_distance := swipe_delta.length()

	if swipe_distance < MIN_SWIPE_DISTANCE:
		throw_rejected.emit()
		return
	if swipe_delta.y < 10.0:
		throw_rejected.emit()
		return  # Need at least some upward component

	var elapsed := (Time.get_ticks_msec() / 1000.0) - _touch_start_time
	if elapsed < 0.01:
		elapsed = 0.01
	var swipe_speed := swipe_distance / elapsed

	if swipe_speed < MIN_SWIPE_SPEED:
		throw_rejected.emit()
		return  # Too slow — dart won't fly

	# Release position is the primary aim (~90%). Speed nudge adds a small
	# vertical adjustment (~10%) — see THROW_SYSTEM_SPEC.md Section 4.
	var aim := _screen_to_board(pos)

	# Speed nudge: medium speed (750 px/sec) = zero nudge.
	# Faster = dart lands higher. Slower = dart lands lower.
	# Clamped so nudge never dominates the aim.
	var speed_ratio := (swipe_speed - MEDIUM_SWIPE_SPEED) / MEDIUM_SWIPE_SPEED
	var nudge := clampf(speed_ratio, -1.0, 1.0) * SPEED_NUDGE_MAX
	aim.y += nudge

	_do_throw(aim, swipe_speed)

func _screen_to_board(screen_pos: Vector2) -> Vector2:
	# Direct ray projection: the dart lands wherever the player points on the
	# board. Like looking through a window — a straight line from the camera
	# through the release point to the board plane at z=0.
	# Naturally zoom-aware and pan-aware (uses the camera's actual transform).
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	if absf(dir.z) < 0.001:
		return Vector2.ZERO
	var t := -origin.z / dir.z
	return Vector2(origin.x + dir.x * t, origin.y + dir.y * t)

static func _gaussian_offset(radius: float) -> Vector2:
	var u1 := maxf(randf(), 0.0001)
	var u2 := randf()
	var mag := radius * sqrt(-2.0 * log(u1))
	var angle := TAU * u2
	# Elliptical scatter: release timing causes more vertical error than
	# horizontal aim drift. 1.5:1 ratio (vertical:horizontal).
	return Vector2(cos(angle) * 0.8, sin(angle) * 1.2) * mag

func _do_throw(aim: Vector2, swipe_speed: float) -> void:
	if not _can_throw:
		return
	_can_throw = false

	# Add scatter (modified by dart tier quality and career stats)
	var scatter_scale := SCATTER_AMOUNT * DartData.get_scatter_mult(_dart_tier) * career_scatter_mult
	var scatter := _gaussian_offset(scatter_scale)
	var target := aim + scatter

	# Calculate throw power from swipe speed
	var power_t := clampf(swipe_speed / SWIPE_SPEED_FOR_MAX, 0.0, 1.0)
	var throw_speed := lerpf(DART_SPEED_MIN, DART_SPEED_MAX, power_t)

	_spawn_and_fire(target, throw_speed, _dart_tier, _character)

## AI throw — spawns a dart aimed at the target position, bypassing swipe input.
## AI dart tier — set by match_manager based on opponent level.
## Opponents use one tier above the player, capped at 3.
## Final opponent (level 7) matches the player's tier.
var ai_dart_tier: int = 0

## Called by match_manager during AI turns.
func do_ai_throw(target: Vector2) -> void:
	var throw_speed := DART_SPEED_MAX * 0.9  # Slightly faster for snappy AI turns
	_spawn_and_fire(target, throw_speed, ai_dart_tier, DartData.Character.TERRY)

func _spawn_and_fire(target: Vector2, throw_speed: float, tier: int, character: DartData.Character) -> void:
	var dart := Dart.create(tier, character)
	dart.visual_scale = 2.0  # Scale visuals only (RigidBody3D ignores node scale)

	# Spawn at the target's XY with only a Z offset from the camera.
	# Zero horizontal/vertical velocity = zero drift. The dart flies
	# straight forward along Z and lands exactly at (target.x, target.y).
	var cam_pos := _camera.global_position
	dart.position = Vector3(target.x, target.y, cam_pos.z * 0.55)

	# Add to tree FIRST (triggers _ready which sets gravity_scale = 1.0),
	# then override physics properties so our values stick.
	_darts_container.add_child(dart)

	dart.gravity_scale = 0.0
	dart.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	dart.linear_damp = 0.0
	dart.linear_velocity = Vector3(0.0, 0.0, -throw_speed)

	dart_thrown.emit(dart)
