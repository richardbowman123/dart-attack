extends Node3D
class_name ThrowSystem

signal dart_thrown(dart: Dart)

const THROW_ZONE_TOP := 0.45      # Top 45% is board view, bottom 55% is throw zone
const MIN_SWIPE_DISTANCE := 30.0  # Minimum pixels to register as a throw
const DART_START_Z := 5.5         # Where the dart spawns (in front of camera)
const DART_SPEED_MIN := 6.0       # Minimum throw speed
const DART_SPEED_MAX := 14.0      # Maximum throw speed
const SWIPE_SPEED_FOR_MAX := 1500.0  # Swipe pixels/sec for max power
const SCATTER_AMOUNT := 0.12      # Random scatter on the board (in board units)
const GRAVITY_DROP := 2.0         # Gravity on the dart in flight

# How much of the board the throw zone covers
# At 1.0, the edges of the throw zone map to the double ring edges
const AIM_RANGE := 1.15           # Slightly beyond doubles so you can hit the edges

var _touch_start_pos := Vector2.ZERO
var _touch_start_time := 0.0
var _is_touching := false
var _can_throw := true
var _viewport_size := Vector2(720, 1280)
var _darts_container: Node3D
var _reticle: MeshInstance3D
var _current_aim := Vector2.ZERO  # Board-space aim position (updated during drag)
var _dart_tier: int = 0           # Current dart tier (affects scatter)

# Track recent positions for smooth aim (avoids flick shifting the target)
var _aim_before_flick := Vector2.ZERO
var _last_slow_pos := Vector2.ZERO
var _last_slow_time := 0.0

func setup(darts_container: Node3D, viewport_size: Vector2) -> void:
	_darts_container = darts_container
	_viewport_size = viewport_size
	_create_reticle()

func set_dart_tier(tier: int) -> void:
	_dart_tier = tier

func set_can_throw(can: bool) -> void:
	_can_throw = can
	if _reticle and not can:
		_reticle.visible = false

func _create_reticle() -> void:
	_reticle = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.04
	mesh.outer_radius = 0.07
	mesh.rings = 16
	mesh.ring_segments = 16
	_reticle.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_reticle.material_override = mat
	_reticle.visible = false
	add_child(_reticle)

func _unhandled_input(event: InputEvent) -> void:
	if not _can_throw:
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

	# Set initial aim from touch position
	_current_aim = _screen_to_board(pos)
	_aim_before_flick = _current_aim
	_last_slow_pos = pos
	_last_slow_time = _touch_start_time

	_reticle.visible = true
	_update_reticle(_current_aim)

func _on_touch_move(pos: Vector2) -> void:
	if not _is_touching:
		return

	# Update aim — maps finger position to board position
	_current_aim = _screen_to_board(pos)
	_update_reticle(_current_aim)

	# Track the last "slow" position — before the flick starts
	# This prevents the upward flick from shifting aim off target
	var now := Time.get_ticks_msec() / 1000.0
	var dt := now - _last_slow_time
	if dt > 0.001:
		var speed := (pos - _last_slow_pos).length() / dt
		if speed < 800.0:  # Still aiming, not flicking yet
			_aim_before_flick = _current_aim
	_last_slow_pos = pos
	_last_slow_time = now

func _on_touch_end(pos: Vector2) -> void:
	if not _is_touching:
		return
	_is_touching = false
	_reticle.visible = false

	# Calculate swipe speed for power
	var swipe_delta := _touch_start_pos - pos  # Positive Y = swiped up
	var swipe_distance := swipe_delta.length()

	if swipe_distance < MIN_SWIPE_DISTANCE:
		return
	if swipe_delta.y < 10.0:
		return  # Need at least some upward component

	var elapsed := (Time.get_ticks_msec() / 1000.0) - _touch_start_time
	if elapsed < 0.01:
		elapsed = 0.01
	var swipe_speed := swipe_distance / elapsed

	# Use the aim from BEFORE the flick, so the upward release doesn't shift the target
	_do_throw(_aim_before_flick, swipe_speed)

func _screen_to_board(screen_pos: Vector2) -> Vector2:
	# Map the throw zone to the full dartboard
	# X: left edge → left of board, right edge → right of board
	var norm_x := (screen_pos.x / _viewport_size.x - 0.5) * 2.0  # -1 to 1

	# Y: bottom of screen → bottom of board, top of throw zone → top of board
	var throw_zone_top_px := _viewport_size.y * THROW_ZONE_TOP
	var throw_zone_height := _viewport_size.y - throw_zone_top_px
	# Invert: screen Y increases downward, board Y increases upward
	var norm_y := ((_viewport_size.y - screen_pos.y) / throw_zone_height) * 2.0 - 1.0

	var board_extent := BoardData.BOARD_RADIUS * BoardData.DOUBLE_OUTER_R * AIM_RANGE
	return Vector2(norm_x * board_extent, norm_y * board_extent)

func _update_reticle(board_aim: Vector2) -> void:
	_reticle.position = Vector3(board_aim.x, board_aim.y, 0.02)

func _do_throw(aim: Vector2, swipe_speed: float) -> void:
	if not _can_throw:
		return
	_can_throw = false

	# Add scatter (modified by dart tier quality)
	var scatter_scale := SCATTER_AMOUNT * DartData.get_scatter_mult(_dart_tier)
	var scatter := Vector2(
		randf_range(-scatter_scale, scatter_scale),
		randf_range(-scatter_scale, scatter_scale)
	)
	var target := aim + scatter

	# Calculate throw power from swipe speed
	var power_t := clampf(swipe_speed / SWIPE_SPEED_FOR_MAX, 0.0, 1.0)
	var throw_speed := lerpf(DART_SPEED_MIN, DART_SPEED_MAX, power_t)

	# Spawn dart slightly offset from centre, below the board
	var dart := Dart.create(_dart_tier)
	dart.position = Vector3(aim.x * 0.3, -1.5, DART_START_Z)

	# Calculate velocity to hit the target on the board (z=0)
	var to_target := Vector3(target.x, target.y, 0.0) - dart.position
	var flight_time := to_target.z / (-throw_speed)
	if flight_time < 0.05:
		flight_time = 0.05

	var vel_x := to_target.x / flight_time
	var vel_y := (to_target.y / flight_time) + (0.5 * GRAVITY_DROP * flight_time)
	var vel_z := -throw_speed

	dart.linear_velocity = Vector3(vel_x, vel_y, vel_z)
	dart.gravity_scale = GRAVITY_DROP / 9.8

	_darts_container.add_child(dart)
	dart_thrown.emit(dart)
