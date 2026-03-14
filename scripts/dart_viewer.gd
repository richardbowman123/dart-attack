extends Node3D

# ── Orbit camera settings ──
const DEFAULT_YAW := 0.0
const DEFAULT_PITCH := 0.3        # Slightly above, looking down at darts
const DEFAULT_DISTANCE := 0.8
const MIN_DISTANCE := 0.3
const MAX_DISTANCE := 1.5
const ORBIT_SENSITIVITY := 0.005
const ZOOM_SENSITIVITY := 0.002
const MOUSE_ZOOM_STEP := 0.05
const LERP_SPEED := 8.0


var _camera: Camera3D
var _yaw := DEFAULT_YAW
var _pitch := DEFAULT_PITCH
var _distance := DEFAULT_DISTANCE
var _current_yaw := DEFAULT_YAW
var _current_pitch := DEFAULT_PITCH
var _current_distance := DEFAULT_DISTANCE
var _orbit_centre := Vector3.ZERO

# ── Touch tracking ──
var _touches: Dictionary = {}     # index -> position
var _prev_pinch_dist := 0.0
var _single_touch_index := -1

# ── UI ──
var _hint_label: Label
var _hint_alpha := 1.0

func _ready() -> void:
	_compute_orbit_centre()
	_setup_environment()
	_setup_lighting()
	_setup_camera()
	_spawn_darts()
	_setup_ui()

func _compute_orbit_centre() -> void:
	var data := DartData.get_tier(GameState.dart_tier)
	var barrel_len: float = data["barrel_length"]
	# Total dart length from tip point to flight trailing edge
	var total_length: float = Dart.TIP_LENGTH + barrel_len + Dart.SHAFT_LENGTH + 0.003 + Dart.FLIGHT_WIDTH
	# Tips converge at origin; darts extend upward after pivot rotation
	# Orbit centre at the midpoint of the centre dart
	_orbit_centre = Vector3(0, total_length / 2.0, 0)

# ─────────────────────────────────────────────────────────
#  SCENE SETUP
# ─────────────────────────────────────────────────────────

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.35)
	env.ambient_light_energy = 0.6

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

func _setup_lighting() -> void:
	# Key light — main illumination from upper-right
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-30), deg_to_rad(30), 0)
	key.light_energy = 1.8
	key.shadow_enabled = false
	add_child(key)

	# Fill light — softer from upper-left
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-20), deg_to_rad(-40), 0)
	fill.light_energy = 0.6
	fill.shadow_enabled = false
	add_child(fill)

	# Rim light — from behind/below for metallic edge highlights
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(15), deg_to_rad(180), 0)
	rim.light_energy = 0.8
	rim.shadow_enabled = false
	add_child(rim)

func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 45.0
	add_child(_camera)
	_update_camera_immediate()

func _spawn_darts() -> void:
	var tier: int = GameState.dart_tier
	var character: DartData.Character = GameState.character
	var data := DartData.get_tier(tier)
	var barrel_len: float = data["barrel_length"]
	var tip_offset: float = barrel_len + Dart.TIP_LENGTH

	# Single dart, tip down, flights up
	var dart := Dart.create(tier, character)

	var pivot := Node3D.new()
	pivot.position = Vector3.ZERO
	add_child(pivot)

	# Rotate so dart's -Z (tip) points downward (-Y)
	pivot.rotation.x = deg_to_rad(-90)

	# Offset dart so its tip point sits at the pivot origin
	dart.position.z = tip_offset

	# Freeze physics — display only
	dart.freeze = true
	dart.gravity_scale = 0

	pivot.add_child(dart)

	# Disable physics processing to prevent the miss timeout
	dart.set_physics_process.call_deferred(false)

func _update_camera_immediate() -> void:
	var pos := _spherical_to_cartesian(_current_yaw, _current_pitch, _current_distance)
	_camera.position = _orbit_centre + pos
	_camera.look_at(_orbit_centre)

# ─────────────────────────────────────────────────────────
#  ORBIT CAMERA
# ─────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Smooth lerp toward target values
	_current_yaw = lerpf(_current_yaw, _yaw, LERP_SPEED * delta)
	_current_pitch = lerpf(_current_pitch, _pitch, LERP_SPEED * delta)
	_current_distance = lerpf(_current_distance, _distance, LERP_SPEED * delta)

	var pos := _spherical_to_cartesian(_current_yaw, _current_pitch, _current_distance)
	_camera.position = _orbit_centre + pos
	_camera.look_at(_orbit_centre)

	# Fade hint text
	if _hint_label and _hint_alpha > 0:
		_hint_alpha -= delta * 0.33  # Fades over ~3 seconds
		if _hint_alpha <= 0:
			_hint_label.visible = false
		else:
			_hint_label.modulate.a = _hint_alpha

func _spherical_to_cartesian(yaw: float, pitch: float, dist: float) -> Vector3:
	var x := dist * cos(pitch) * sin(yaw)
	var y := dist * sin(pitch)
	var z := dist * cos(pitch) * cos(yaw)
	return Vector3(x, y, z)

# ── Multi-touch (pinch zoom) — uses _input so it captures before UI ──
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touches[touch.index] = touch.position
			if _touches.size() == 2:
				var positions: Array = _touches.values()
				_prev_pinch_dist = (positions[0] as Vector2).distance_to(positions[1] as Vector2)
		else:
			_touches.erase(touch.index)

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index in _touches:
			_touches[drag.index] = drag.position

		# Pinch zoom when 2 fingers active
		if _touches.size() >= 2:
			var positions: Array = _touches.values()
			var dist := (positions[0] as Vector2).distance_to(positions[1] as Vector2)
			var delta_dist := dist - _prev_pinch_dist
			_distance = clampf(_distance - delta_dist * ZOOM_SENSITIVITY, MIN_DISTANCE, MAX_DISTANCE)
			_prev_pinch_dist = dist

# ── Single-finger orbit + mouse — uses _unhandled_input so buttons eat taps first ──
func _unhandled_input(event: InputEvent) -> void:
	# Single-finger drag = orbit
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _touches.size() <= 1:
			_yaw -= drag.relative.x * ORBIT_SENSITIVITY
			_pitch += drag.relative.y * ORBIT_SENSITIVITY
			_pitch = clampf(_pitch, deg_to_rad(-80), deg_to_rad(80))

	# Mouse: left-drag = orbit
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_yaw -= motion.relative.x * ORBIT_SENSITIVITY
			_pitch += motion.relative.y * ORBIT_SENSITIVITY
			_pitch = clampf(_pitch, deg_to_rad(-80), deg_to_rad(80))

	# Mouse: scroll = zoom
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_distance = clampf(_distance - MOUSE_ZOOM_STEP, MIN_DISTANCE, MAX_DISTANCE)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_distance = clampf(_distance + MOUSE_ZOOM_STEP, MIN_DISTANCE, MAX_DISTANCE)

# ─────────────────────────────────────────────────────────
#  UI OVERLAY
# ─────────────────────────────────────────────────────────

func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var tier_data := DartData.get_tier(GameState.dart_tier)

	# Tier name (gold, top centre)
	var tier_label := Label.new()
	tier_label.text = tier_data["name"]
	tier_label.add_theme_font_size_override("font_size", 36)
	tier_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_label.position = Vector2(0, 60)
	tier_label.size = Vector2(720, 48)
	canvas.add_child(tier_label)

	# Weight label (grey, below tier name)
	var weight_label := Label.new()
	weight_label.text = tier_data["weight_label"]
	weight_label.add_theme_font_size_override("font_size", 22)
	weight_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weight_label.position = Vector2(0, 112)
	weight_label.size = Vector2(720, 30)
	canvas.add_child(weight_label)

	# Hint text (fades after 3 seconds)
	_hint_label = Label.new()
	_hint_label.text = "Drag to rotate  -  Pinch to zoom"
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.position = Vector2(0, 160)
	_hint_label.size = Vector2(720, 24)
	canvas.add_child(_hint_label)

	# BACK button (bottom centre)
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(260, 1170)
	back_btn.size = Vector2(200, 60)
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.add_theme_color_override("font_color", Color.WHITE)

	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.15, 0.15, 0.2)
	back_style.corner_radius_top_left = 8
	back_style.corner_radius_top_right = 8
	back_style.corner_radius_bottom_left = 8
	back_style.corner_radius_bottom_right = 8
	back_style.border_width_left = 2
	back_style.border_width_right = 2
	back_style.border_width_top = 2
	back_style.border_width_bottom = 2
	back_style.border_color = Color(0.3, 0.3, 0.35)
	back_btn.add_theme_stylebox_override("normal", back_style)

	var back_hover := back_style.duplicate()
	back_hover.bg_color = Color(0.2, 0.2, 0.28)
	back_hover.border_color = Color(0.5, 0.5, 0.6)
	back_btn.add_theme_stylebox_override("hover", back_hover)

	back_btn.pressed.connect(_on_back)
	canvas.add_child(back_btn)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/dart_select.tscn")
