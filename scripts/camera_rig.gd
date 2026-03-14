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

func _ready() -> void:
	_camera = Camera3D.new()
	_camera.fov = DEFAULT_FOV
	add_child(_camera)
	_update_camera_immediate()

func get_camera() -> Camera3D:
	return _camera

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

func _unhandled_input(event: InputEvent) -> void:
	# Scroll wheel to zoom
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom = clampf(_zoom + ZOOM_SPEED, 0.0, 1.0)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom = clampf(_zoom - ZOOM_SPEED, 0.0, 1.0)

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
