extends Node3D
class_name CameraRig

var _camera: Camera3D
var _target := Vector2.ZERO  # Where the camera is looking (X, Y on the board plane)
var _zoom := 0.0             # 0 = full board view, 1 = zoomed in tight

const DEFAULT_DISTANCE := 10.0
const ZOOMED_DISTANCE := 5.0
const DEFAULT_FOV := 50.0
const PAN_SPEED := 3.0
const PAN_LIMIT := 2.5       # Max pan distance from centre
const ZOOM_SPEED := 0.1
const LERP_SPEED := 6.0      # How fast camera smoothly follows target

var _current_pos := Vector3.ZERO
var _current_fov := DEFAULT_FOV

# ── Multi-touch gesture state (mobile pinch/pan) ──
var _touches: Dictionary = {}  # touch_index -> position
var _prev_pinch_dist := 0.0
var _prev_pinch_mid := Vector2.ZERO
var _is_gesturing := false     # True when 2+ fingers are down

# ── Right-click drag (PC pan) ──
var _right_dragging := false

func _ready() -> void:
	_camera = Camera3D.new()
	_camera.fov = DEFAULT_FOV
	add_child(_camera)
	_update_camera_immediate()

func get_camera() -> Camera3D:
	return _camera

func get_zoom() -> float:
	return _zoom

func is_gesturing() -> bool:
	return _is_gesturing

func _process(delta: float) -> void:
	_handle_keyboard_pan(delta)
	_smooth_update(delta)

func _handle_keyboard_pan(delta: float) -> void:
	var pan_input := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		pan_input.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		pan_input.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		pan_input.y += 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		pan_input.y -= 1.0

	if pan_input.length() > 0:
		_target += pan_input.normalized() * PAN_SPEED * delta
		_target.x = clampf(_target.x, -PAN_LIMIT, PAN_LIMIT)
		_target.y = clampf(_target.y, -PAN_LIMIT, PAN_LIMIT)

# ── Multi-touch handling (pinch-to-zoom + two-finger pan) ──
# Uses _input so both camera and throw system can independently track touches.

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touches[touch.index] = touch.position
		else:
			_touches.erase(touch.index)
		_update_gesture_state()

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index in _touches:
			_touches[drag.index] = drag.position
		if _is_gesturing and _touches.size() >= 2:
			_handle_pinch_pan()

func _update_gesture_state() -> void:
	if _touches.size() >= 2 and not _is_gesturing:
		# Entering gesture mode — snapshot initial pinch state
		_is_gesturing = true
		var positions: Array = _touches.values()
		_prev_pinch_dist = (positions[0] as Vector2).distance_to(positions[1] as Vector2)
		_prev_pinch_mid = ((positions[0] as Vector2) + (positions[1] as Vector2)) / 2.0
	elif _touches.size() < 2 and _is_gesturing:
		_is_gesturing = false

func _handle_pinch_pan() -> void:
	var positions: Array = _touches.values()
	var p0: Vector2 = positions[0]
	var p1: Vector2 = positions[1]

	var dist := p0.distance_to(p1)
	var mid := (p0 + p1) / 2.0

	# Pinch zoom — spread fingers to zoom in, pinch to zoom out
	var dist_delta := dist - _prev_pinch_dist
	_zoom = clampf(_zoom + dist_delta * 0.003, 0.0, 1.0)

	# Two-finger pan — drag both fingers to move the view
	var mid_delta := mid - _prev_pinch_mid
	var pan_scale := lerpf(0.003, 0.008, _zoom)
	_target.x -= mid_delta.x * pan_scale
	_target.y += mid_delta.y * pan_scale  # Screen Y is inverted vs board Y
	_target.x = clampf(_target.x, -PAN_LIMIT, PAN_LIMIT)
	_target.y = clampf(_target.y, -PAN_LIMIT, PAN_LIMIT)

	_prev_pinch_dist = dist
	_prev_pinch_mid = mid

# ── PC controls (scroll wheel, right-click drag, keyboard) ──

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		# Scroll wheel to zoom
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom + ZOOM_SPEED, 0.0, 1.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom - ZOOM_SPEED, 0.0, 1.0)
		# Right-click to start/stop pan drag
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_right_dragging = mb.pressed

	# Right-click drag to pan
	if event is InputEventMouseMotion and _right_dragging:
		var motion: InputEventMouseMotion = event
		var pan_scale := lerpf(0.003, 0.008, _zoom)
		_target.x -= motion.relative.x * pan_scale
		_target.y += motion.relative.y * pan_scale
		_target.x = clampf(_target.x, -PAN_LIMIT, PAN_LIMIT)
		_target.y = clampf(_target.y, -PAN_LIMIT, PAN_LIMIT)

	# R key to reset camera
	if event is InputEventKey:
		var key: InputEventKey = event
		if key.pressed and key.keycode == KEY_R:
			_target = Vector2.ZERO
			_zoom = 0.0

func _smooth_update(delta: float) -> void:
	var dist := lerpf(DEFAULT_DISTANCE, ZOOMED_DISTANCE, _zoom)
	var target_pos := Vector3(_target.x, _target.y, dist)
	_current_pos = _current_pos.lerp(target_pos, LERP_SPEED * delta)
	_camera.position = _current_pos
	_camera.look_at(Vector3(_target.x, _target.y, 0.0))

func _update_camera_immediate() -> void:
	var dist := lerpf(DEFAULT_DISTANCE, ZOOMED_DISTANCE, _zoom)
	_current_pos = Vector3(_target.x, _target.y, dist)
	_camera.position = _current_pos
	_camera.look_at(Vector3(_target.x, _target.y, 0.0))

## Move camera to focus on a specific segment (for Around the Clock etc.)
func focus_segment(segment_index: int) -> void:
	var angles := BoardData.get_segment_angles(segment_index)
	var mid_angle: float = (angles[0] + angles[1]) / 2.0
	var focus_r := BoardData.BOARD_RADIUS * 0.7  # Look at the middle of the segment
	_target = Vector2(cos(mid_angle) * focus_r, sin(mid_angle) * focus_r)
	_zoom = 0.4

## Reset camera to show the full board
func reset_view() -> void:
	_target = Vector2.ZERO
	_zoom = 0.0
