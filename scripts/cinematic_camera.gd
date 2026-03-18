extends Node3D
class_name CinematicCamera

## Cinematic "Game Shot" camera — tracks a dart from the side during flight,
## then orbits to face the board and reveal the result.

signal cinematic_finished

var _camera: Camera3D
var _dart_visual: Node3D  # The animated dart (non-physics)

# Flight path parameters
var _start_pos := Vector3.ZERO
var _end_pos := Vector3.ZERO
var _arc_height := 0.35  # Parabolic arc peak — slightly larger for the longer flight path

# Timing
var _flight_duration := 1.2  # Longer flight — camera has more runway to track alongside the dart
var _orbit_duration := 0.6   # Camera orbit to front
var _hold_duration := 2.0    # Hold on result text

# State
enum Phase { IDLE, FLIGHT, ORBIT, RESULT, DONE }
var _phase: Phase = Phase.IDLE
var _phase_time := 0.0

# Camera tracking — side position (behind and to the left of the dart)
# Portrait mode (720x1280) has a very narrow horizontal FOV, so the camera
# must be positioned BEHIND the dart to keep it visible in frame.
const CAM_SIDE_OFFSET := 1.5    # Left of dart — narrow for portrait mode
const CAM_UP_OFFSET := 0.5      # Slightly above dart
const CAM_BEHIND_OFFSET := 2.0  # Behind the dart — ensures dart is visible in frame
const CAM_FORWARD_LOOK := 2.0   # Look ahead of dart toward the board
const CINEMATIC_FOV := 65.0     # Wider FOV to accommodate portrait orientation

# Pan-around — camera swings from side to directly behind dart near impact.
# In the last 25% of flight time, the camera smoothly orbits from the side
# tracking position to directly behind the dart, so we see the dart hit the
# board from behind as the action slows down.
const PAN_START_T := 0.75       # Start pan at 75% of flight time
const CAM_BEHIND_CLOSE := 1.5   # Distance behind dart when directly behind it

# Flight start distance — how far back the cinematic dart begins its journey
const FLIGHT_START_Z := 12.0    # Well back from the board for a long, dramatic tracking shot

# Wobble parameters
const WOBBLE_AMPLITUDE := 3.0   # Degrees
const WOBBLE_FREQ := 8.0        # Hz — subtle rapid oscillation
const WOBBLE_DECAY := 0.7       # How much wobble fades over flight (0=none, 1=full)

# Dart pitch (tip angle relative to flight path)
const INITIAL_PITCH_UP := 4.0    # Degrees — tip slightly above fins at start
const IMPACT_ANGLE_DEG := 12.0   # Degrees below horizontal at board impact (tip lower than flights)

# Dart penetration — 70% of the tip spike goes into the board
const TIP_PENETRATION := 0.70

# Camera orbit end position
const ORBIT_END_DIST := 3.0     # Distance from board when facing it

# Result
var _is_hit := false
var _is_player := true
var _result_label: Label
var _hud_layer: CanvasLayer
var _original_fov := 50.0
var _dart_tier := 0

# Orbit interpolation (set when transitioning from flight to orbit)
var _orbit_start_pos := Vector3.ZERO
var _board_contact_2d := Vector2.ZERO  # Scoring point on board surface (Z=0)


func setup(camera: Camera3D, start: Vector3, end_board_2d: Vector2, is_hit: bool, dart_tier: int, is_player: bool = true) -> void:
	_camera = camera
	_is_hit = is_hit
	_is_player = is_player
	_dart_tier = dart_tier
	_original_fov = camera.fov

	# Override the start Z to place the dart well back from the board.
	# Keep the original X/Y so the dart flies toward its landing point naturally.
	_start_pos = Vector3(start.x, start.y, FLIGHT_START_Z)

	# The scoring point is where the dart shaft crosses the board surface (Z=0).
	# The dart body sits in front of and above this point due to the impact angle.
	_board_contact_2d = end_board_2d
	var contact_dist := get_contact_dist(dart_tier)
	var angle_rad := deg_to_rad(IMPACT_ANGLE_DEG)
	_end_pos = Vector3(
		end_board_2d.x,
		end_board_2d.y + contact_dist * sin(angle_rad),
		contact_dist * cos(angle_rad)
	)


## Distance along the dart axis from body centre to board surface intersection.
## 70% of the tip penetrates — the board surface crosses the remaining 30%.
static func get_contact_dist(dart_tier: int) -> float:
	var data := DartData.get_tier(dart_tier)
	var barrel_len: float = data["barrel_length"]
	return (barrel_len + Dart.TIP_LENGTH * (1.0 - TIP_PENETRATION)) * 2.0


## Get the resting body position for a dart stuck in the board at the given scoring point.
## The scoring point (board_2d) is where the shaft crosses the board surface (Z=0).
## The dart body sits above and in front of this point due to the downward impact angle.
static func get_resting_position(board_2d: Vector2, dart_tier: int) -> Vector3:
	var contact_dist := get_contact_dist(dart_tier)
	var angle_rad := deg_to_rad(IMPACT_ANGLE_DEG)
	return Vector3(
		board_2d.x,
		board_2d.y + contact_dist * sin(angle_rad),
		contact_dist * cos(angle_rad)
	)


## Get the direction vector for a dart stuck in the board (tip angled down into the board).
static func get_resting_direction() -> Vector3:
	var angle_rad := deg_to_rad(IMPACT_ANGLE_DEG)
	return Vector3(0.0, -sin(angle_rad), -cos(angle_rad))


func play() -> void:
	_phase = Phase.FLIGHT
	_phase_time = 0.0
	# Switch to cinematic FOV (telephoto look)
	_camera.fov = CINEMATIC_FOV
	# Build the cinematic dart visual
	_build_dart_visual()
	_dart_visual.position = _start_pos


func _process(delta: float) -> void:
	match _phase:
		Phase.FLIGHT:
			_process_flight(delta)
		Phase.ORBIT:
			_process_orbit(delta)
		Phase.RESULT:
			_process_result(delta)
		_:
			pass


func _process_flight(delta: float) -> void:
	_phase_time += delta

	var raw_t := clampf(_phase_time / _flight_duration, 0.0, 1.0)

	# Speed curve: fast early, dramatically slows near impact
	var visual_t := _ease_in_out_custom(raw_t)

	# Position along the arc
	var pos := _get_arc_position(visual_t)
	_dart_visual.position = pos

	# Dart orientation — follow tangent + pitch adjustment + wobble
	_orient_dart(visual_t)

	# Camera tracking — side tracking with pan-around near impact
	_update_tracking_camera(pos, raw_t)

	if raw_t >= 1.0:
		# Flight complete — snap dart to final position and angle
		_dart_visual.position = _end_pos
		var impact_dir := get_resting_direction()
		_dart_visual.look_at(_dart_visual.position + impact_dir, Vector3.UP)
		# Transition to orbit
		_phase = Phase.ORBIT
		_phase_time = 0.0
		_orbit_start_pos = _camera.global_position


func _process_orbit(delta: float) -> void:
	_phase_time += delta
	var t := clampf(_phase_time / _orbit_duration, 0.0, 1.0)

	# Ease-out for smooth deceleration
	var eased_t := 1.0 - pow(1.0 - t, 2.5)

	# Orbit end: in front of the board, facing the scoring point on the board surface
	var orbit_end := Vector3(_board_contact_2d.x, _board_contact_2d.y, ORBIT_END_DIST)

	_camera.global_position = _orbit_start_pos.lerp(orbit_end, eased_t)

	var look_target := Vector3(_board_contact_2d.x, _board_contact_2d.y, 0.0)
	_camera.look_at(look_target, Vector3.UP)

	if t >= 1.0:
		_phase = Phase.RESULT
		_phase_time = 0.0
		_show_result()


func _process_result(delta: float) -> void:
	_phase_time += delta
	if _phase_time >= _hold_duration:
		_phase = Phase.DONE
		cinematic_finished.emit()


# ── Arc position calculation ──

func _get_arc_position(t: float) -> Vector3:
	var x := lerpf(_start_pos.x, _end_pos.x, t)
	var z := lerpf(_start_pos.z, _end_pos.z, t)

	# Smooth arc Y: sine curve rises and falls cleanly from start to end.
	# No clamping, no kinks — smooth all the way through.
	var base_y := lerpf(_start_pos.y, _end_pos.y, t)
	var arc_factor := sin(t * PI)
	var y := base_y + _arc_height * arc_factor

	return Vector3(x, y, z)


# ── Dart orientation ──

func _orient_dart(t: float) -> void:
	# Calculate tangent from the arc derivative
	var dt := 0.01
	var t0 := clampf(t - dt, 0.0, 1.0)
	var t1 := clampf(t + dt, 0.0, 1.0)
	var p0 := _get_arc_position(t0)
	var p1 := _get_arc_position(t1)
	var tangent := (p1 - p0).normalized()

	if tangent.length_squared() < 0.0001:
		return

	# Look along the flight path tangent
	_dart_visual.look_at(_dart_visual.position + tangent, Vector3.UP)

	# Pitch: tip angled up at start, down at end (12 degrees below horizontal at impact)
	var pitch_deg := lerpf(INITIAL_PITCH_UP, -IMPACT_ANGLE_DEG, t)
	_dart_visual.rotate_object_local(Vector3.RIGHT, deg_to_rad(pitch_deg))

	# Wobble: sinusoidal roll around flight axis, decaying over time
	var wobble_envelope := 1.0 - t * WOBBLE_DECAY
	var wobble_angle := WOBBLE_AMPLITUDE * sin(t * WOBBLE_FREQ * TAU) * wobble_envelope
	_dart_visual.rotate_object_local(Vector3.FORWARD, deg_to_rad(wobble_angle))


# ── Camera tracking — side tracking with pan-around near impact ──

func _update_tracking_camera(dart_pos: Vector3, raw_t: float) -> void:
	# ── Phase A (0% - 75%): Side tracking ──
	# Camera is behind and to the left of the dart, looking forward.
	# The dart is visible in the right side of the frame.
	var side_cam := Vector3(
		dart_pos.x - CAM_SIDE_OFFSET,
		dart_pos.y + CAM_UP_OFFSET,
		dart_pos.z + CAM_BEHIND_OFFSET
	)
	var side_look := Vector3(
		dart_pos.x,
		dart_pos.y,
		dart_pos.z - CAM_FORWARD_LOOK
	)

	# ── Phase B (75% - 100%): Pan to behind dart ──
	# Camera swings around to directly behind the dart, looking at the board.
	# The dart slows down (easing handles this) as the camera pans around,
	# so we see the dart approach and hit the board from behind.
	var behind_cam := Vector3(
		dart_pos.x,
		dart_pos.y + 0.3,
		dart_pos.z + CAM_BEHIND_CLOSE
	)
	var behind_look := Vector3(
		_board_contact_2d.x,
		_board_contact_2d.y,
		0.0
	)

	if raw_t <= PAN_START_T:
		# Pure side tracking
		_camera.global_position = side_cam
		_camera.look_at(side_look, Vector3.UP)
	else:
		# Blend from side to behind — smooth ease-in for natural pan start
		var blend := (raw_t - PAN_START_T) / (1.0 - PAN_START_T)
		blend = blend * blend  # Ease-in: pan starts gently, accelerates
		_camera.global_position = side_cam.lerp(behind_cam, blend)
		var look := side_look.lerp(behind_look, blend)
		_camera.look_at(look, Vector3.UP)


# ── Speed easing ──

func _ease_in_out_custom(t: float) -> float:
	# 80% of distance in first 70% of time, then smooth deceleration into board
	if t < 0.7:
		return (t / 0.7) * 0.8
	else:
		var local_t := (t - 0.7) / 0.3
		var eased := 1.0 - (1.0 - local_t) * (1.0 - local_t)
		return 0.8 + eased * 0.2


# ── Build cinematic dart visual ──

func _build_dart_visual() -> void:
	var dart_inst := Dart.create(_dart_tier, GameState.character)
	dart_inst.visual_scale = 2.0
	dart_inst.skip_random_rotation = true

	add_child(dart_inst)
	_dart_visual = dart_inst

	# Disable ALL physics — we control position/rotation entirely
	dart_inst.freeze = true
	dart_inst.gravity_scale = 0.0
	dart_inst.contact_monitor = false
	dart_inst.set_physics_process(false)



# ── Result display ──

func _show_result() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 50
	add_child(_hud_layer)

	# Dark vignette behind text
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.4)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(bg)

	_result_label = Label.new()
	if _is_hit:
		_result_label.text = "GAME SHOT!"
		_result_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	else:
		_result_label.text = "UNLUCKY!" if _is_player else "MISS!"
		_result_label.add_theme_color_override("font_color", Color(0.9, 0.25, 0.2))

	UIFont.apply(_result_label, UIFont.SCREEN_TITLE)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_label.set_anchors_preset(Control.PRESET_CENTER)
	_result_label.position = Vector2(-360, -60)
	_result_label.size = Vector2(720, 120)
	_result_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_result_label)

	# Fade in with scale punch
	bg.modulate = Color(1, 1, 1, 0)
	_result_label.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(bg, "modulate:a", 1.0, 0.3)
	tween.tween_property(_result_label, "modulate:a", 1.0, 0.3)

	_result_label.pivot_offset = Vector2(360, 60)
	_result_label.scale = Vector2(1.4, 1.4)
	tween.tween_property(_result_label, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func cleanup() -> void:
	if _camera and is_instance_valid(_camera):
		_camera.fov = _original_fov
	if _dart_visual and is_instance_valid(_dart_visual):
		_dart_visual.queue_free()
	if _hud_layer and is_instance_valid(_hud_layer):
		_hud_layer.queue_free()
