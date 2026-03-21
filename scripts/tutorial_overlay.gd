extends CanvasLayer
class_name TutorialOverlay

signal ready_to_throw  # Emitted when player taps Go and throwing should be enabled

# Tutorial sequence: hit 1, 2, 3 in order
const TUTORIAL_TARGETS := [1, 2, 3]

# Layout
const THROW_ZONE_TOP := 0.45  # Must match ThrowSystem
const DOT_RADIUS := 18.0
const ARROW_WIDTH := 3.0
const SWIPE_LENGTH := 150.0

# Target aiming radius — halfway between treble and double (the fat single area)
# Treble outer = 0.629, Double inner = 0.953 → midpoint ≈ 0.79
const AIM_RADIUS_FRAC := 0.79

# States
enum Phase { INTRO, AIMING, FEEDBACK, COMPLETE }

var _viewport_size := Vector2(720, 1280)
var _camera: Camera3D
var _camera_rig: CameraRig
var _current_step := 0
var _phase: Phase = Phase.INTRO

# Guide dot positions — recalculated every frame from the camera
var _green_dot_pos := Vector2.ZERO
var _red_dot_pos := Vector2.ZERO

# Target screen position (board view area) — for drawing the target circle
var _target_screen_pos := Vector2.ZERO

# Target board position for feedback calculations
var _target_board_pos := Vector2.ZERO

# Speed feedback — track the last swipe speed for miss diagnosis
var _current_swipe_speed := 0.0
var _last_throw_speed := 0.0

# Tracks whether we've shown the "now throw" hint after zoom
var _showed_throw_hint := false

# UI nodes
var _instruction_label: Label
var _feedback_label: Label
var _feedback_bg: ColorRect
var _guide_canvas: Control
var _instruction_bg: ColorRect
var _intro_panel: PanelContainer
var _intro_label: Label
var _go_button: Button

func setup(viewport_size: Vector2, camera: Camera3D, camera_rig: CameraRig) -> void:
	_viewport_size = viewport_size
	_camera = camera
	_camera_rig = camera_rig

func start() -> void:
	_current_step = 0
	visible = true
	_show_intro()

func get_current_target() -> int:
	if _current_step < TUTORIAL_TARGETS.size():
		return TUTORIAL_TARGETS[_current_step]
	return -1

func is_waiting_for_input() -> bool:
	return _phase == Phase.INTRO

# Called by match_manager when a dart hits
func on_hit(hit_number: int, multiplier: int, hit_pos: Vector2) -> void:
	if _phase != Phase.AIMING:
		return

	var target: int = get_current_target()
	if target < 0:
		return

	# Capture the swipe speed that produced this throw
	_last_throw_speed = _current_swipe_speed

	_phase = Phase.FEEDBACK

	if hit_number == target and multiplier > 0:
		_current_step += 1
		if _current_step >= TUTORIAL_TARGETS.size():
			_phase = Phase.COMPLETE
			_show_completion()
		else:
			_show_success()
	else:
		_show_miss_feedback(hit_pos, hit_number)

func on_swipe_update(speed: float) -> void:
	if _phase != Phase.AIMING:
		return
	_current_swipe_speed = speed

func on_swipe_end() -> void:
	pass

# Called by match_manager after the feedback pause to move on
func advance(was_hit: bool) -> void:
	_feedback_label.visible = false
	_feedback_bg.visible = false
	if _phase == Phase.COMPLETE:
		return
	if was_hit:
		_show_intro()
	else:
		_begin_aiming()
		ready_to_throw.emit()


# ── UI building ──

func _ready() -> void:
	layer = 10

	_build_intro_panel()
	_build_instruction_label()
	_build_feedback_elements()
	_build_guide_canvas()

func _build_intro_panel() -> void:
	_intro_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.94)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.6, 0.15, 0.6)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	_intro_panel.add_theme_stylebox_override("panel", style)
	_intro_panel.position = Vector2(60, 380)
	_intro_panel.size = Vector2(600, 280)
	_intro_panel.visible = false

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	# BARMAN header
	var header := Label.new()
	header.text = "BARMAN"
	UIFont.apply(header, UIFont.CAPTION)
	header.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	_intro_label = Label.new()
	UIFont.apply(_intro_label, UIFont.BODY)
	_intro_label.add_theme_color_override("font_color", Color.WHITE)
	_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_intro_label)

	_go_button = Button.new()
	_go_button.text = "LET'S GO!"
	UIFont.apply_button(_go_button, UIFont.SUBHEADING)
	_go_button.custom_minimum_size = Vector2(300, 60)
	_go_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.35, 0.12)
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
	btn_style.border_width_left = 2
	btn_style.border_width_right = 2
	btn_style.border_width_top = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.2, 0.6, 0.25)
	_go_button.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.15, 0.45, 0.18)
	_go_button.add_theme_stylebox_override("hover", btn_hover)
	_go_button.add_theme_color_override("font_color", Color.WHITE)
	_go_button.pressed.connect(_on_go_pressed)
	vbox.add_child(_go_button)

	_intro_panel.add_child(vbox)
	add_child(_intro_panel)

func _build_instruction_label() -> void:
	# Dark background so text is readable over the board
	_instruction_bg = ColorRect.new()
	_instruction_bg.color = Color(0.0, 0.0, 0.0, 0.8)
	_instruction_bg.size = Vector2(560, 200)
	_instruction_bg.position = Vector2(80, _viewport_size.y * THROW_ZONE_TOP + 6)
	_instruction_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_instruction_bg.visible = false
	add_child(_instruction_bg)

	_instruction_label = Label.new()
	UIFont.apply(_instruction_label, UIFont.SUBHEADING)
	_instruction_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction_label.size = Vector2(520, 190)
	_instruction_label.position = Vector2(100, _viewport_size.y * THROW_ZONE_TOP + 11)
	_instruction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_instruction_label.visible = false
	add_child(_instruction_label)

func _build_feedback_elements() -> void:
	# Dark background behind feedback text so it's always readable
	_feedback_bg = ColorRect.new()
	_feedback_bg.color = Color(0.0, 0.0, 0.0, 0.8)
	_feedback_bg.size = Vector2(680, 110)
	_feedback_bg.position = Vector2(20, _viewport_size.y * 0.28)
	_feedback_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_bg.visible = false
	add_child(_feedback_bg)

	_feedback_label = Label.new()
	UIFont.apply(_feedback_label, UIFont.BODY)
	_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.size = Vector2(660, 100)
	_feedback_label.position = Vector2(30, _viewport_size.y * 0.285)
	_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_label.visible = false
	add_child(_feedback_label)


func _build_guide_canvas() -> void:
	_guide_canvas = Control.new()
	_guide_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_guide_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_canvas.draw.connect(_draw_guides)
	add_child(_guide_canvas)

# ── Intro screen ──

func _show_intro() -> void:
	_phase = Phase.INTRO
	var target: int = TUTORIAL_TARGETS[_current_step]

	if _current_step == 0:
		_intro_label.text = "Learn to throw!\n\nFirst up: hit number " + str(target) + "\n\nUse two fingers to zoom in on it\nSwipe up to throw"
	else:
		_intro_label.text = "Great stuff!\n\nNow hit number " + str(target) + "\n\nZoom in and swipe up to throw"

	_intro_panel.visible = true
	_instruction_label.visible = false
	_instruction_bg.visible = false
	_guide_canvas.visible = false
	# Reset camera to full board view so the target circle is visible
	if _camera_rig:
		_camera_rig.reset_view()
	_update_board_target()

func _on_go_pressed() -> void:
	_intro_panel.visible = false
	_begin_aiming()
	ready_to_throw.emit()

func _begin_aiming() -> void:
	_phase = Phase.AIMING
	_showed_throw_hint = false
	_update_board_target()

	_instruction_label.text = "Use two fingers to zoom in, then swipe GREEN to RED"

	# Position instructions to avoid clashing with guide dots
	# Number 1 is at the top of the board — put instructions in bottom half
	# Numbers 2 and 3 are lower on the board — put instructions higher
	var target: int = TUTORIAL_TARGETS[_current_step]
	var instr_y: float
	if target == 1:
		instr_y = _viewport_size.y * 0.52
	else:
		instr_y = _viewport_size.y * 0.15
	_instruction_bg.position.y = instr_y
	_instruction_label.position.y = instr_y + 5

	_instruction_label.visible = true
	_instruction_bg.visible = true
	_guide_canvas.visible = true

func _update_board_target() -> void:
	var target: int = TUTORIAL_TARGETS[_current_step]
	var seg_index := _find_segment(target)
	if seg_index < 0:
		return
	var angles := BoardData.get_segment_angles(seg_index)
	var mid_angle: float = (angles[0] + angles[1]) / 2.0
	var target_r := BoardData.BOARD_RADIUS * AIM_RADIUS_FRAC
	_target_board_pos = Vector2(cos(mid_angle) * target_r, sin(mid_angle) * target_r)

# ── Every frame: recalculate guide dot positions from camera ──

func _process(_delta: float) -> void:
	if _phase == Phase.AIMING:
		_recalculate_guide_positions()
		_guide_canvas.queue_redraw()

		# Once the player zooms in, update the instruction to focus on throwing
		if _camera_rig and _camera_rig.get_zoom() > 0.15 and not _showed_throw_hint:
			_showed_throw_hint = true
			_instruction_label.text = "Swipe from GREEN up to RED"

func _recalculate_guide_positions() -> void:
	if not _camera:
		return

	# Both the yellow crosshair and the red dot sit at the target's visual
	# position on the board. With ray projection in ThrowSystem, releasing
	# at this screen position sends the dart straight to the target — the
	# same straight line from camera through finger to board.
	var board_pos_3d := Vector3(_target_board_pos.x, _target_board_pos.y, 0.0)
	_target_screen_pos = _camera.unproject_position(board_pos_3d)

	# Red dot = RELEASE point, right on top of the target on the board.
	# Releasing here ray-projects directly to the target board position.
	_red_dot_pos = _target_screen_pos
	_red_dot_pos.x = clampf(_red_dot_pos.x, DOT_RADIUS, _viewport_size.x - DOT_RADIUS)
	_red_dot_pos.y = clampf(_red_dot_pos.y, DOT_RADIUS, _viewport_size.y - DOT_RADIUS)

	# Green dot = START of swipe, below the red dot. Must be in the throw
	# zone since touches above the boundary (y < 576) are rejected.
	var tz_top := _viewport_size.y * THROW_ZONE_TOP
	_green_dot_pos = Vector2(_red_dot_pos.x, _red_dot_pos.y + SWIPE_LENGTH)
	_green_dot_pos.x = clampf(_green_dot_pos.x, DOT_RADIUS, _viewport_size.x - DOT_RADIUS)
	var min_green_y := maxf(tz_top + DOT_RADIUS, _red_dot_pos.y + DOT_RADIUS * 2.5)
	_green_dot_pos.y = clampf(_green_dot_pos.y, min_green_y, _viewport_size.y - DOT_RADIUS)

# ── Drawing ──

func _draw_guides() -> void:
	if _phase != Phase.AIMING:
		return

	var pulse := (sin(Time.get_ticks_msec() / 300.0) + 1.0) / 2.0

	# ── Yellow crosshair on the board (aim indicator) ──
	var crosshair_r := 22.0 + pulse * 4.0
	_guide_canvas.draw_circle(_target_screen_pos, crosshair_r, Color(1.0, 1.0, 0.0, 0.5 + pulse * 0.2), false, 2.5)
	_guide_canvas.draw_circle(_target_screen_pos, crosshair_r * 0.4, Color(1.0, 1.0, 0.0, 0.3), false, 1.5)
	var cross := 6.0
	_guide_canvas.draw_line(_target_screen_pos + Vector2(-cross, 0), _target_screen_pos + Vector2(cross, 0), Color(1.0, 1.0, 0.0, 0.5), 1.5)
	_guide_canvas.draw_line(_target_screen_pos + Vector2(0, -cross), _target_screen_pos + Vector2(0, cross), Color(1.0, 1.0, 0.0, 0.5), 1.5)

	# ── Red dot at the target on the board (release/stop point) ──
	_guide_canvas.draw_circle(_red_dot_pos, DOT_RADIUS, Color(0.9, 0.2, 0.2, 0.9))
	_guide_canvas.draw_circle(_red_dot_pos, DOT_RADIUS + 2, Color(0.9, 0.2, 0.2, 0.4), false, 2.0)

	# ── Green dot below = swipe start ──
	_guide_canvas.draw_circle(_green_dot_pos, DOT_RADIUS, Color(0.2, 0.9, 0.2, 0.9))
	_guide_canvas.draw_circle(_green_dot_pos, DOT_RADIUS + 2, Color(0.2, 0.9, 0.2, 0.4), false, 2.0)

	# ── Arrow from green UP to red (swipe direction) ──
	var dir := (_red_dot_pos - _green_dot_pos).normalized()
	var line_start := _green_dot_pos + dir * DOT_RADIUS
	var line_end := _red_dot_pos - dir * DOT_RADIUS
	_guide_canvas.draw_line(line_start, line_end, Color(1, 1, 1, 0.6), ARROW_WIDTH)

	# Arrowhead
	var arrow_size := 12.0
	var perp := Vector2(-dir.y, dir.x)
	var tip := line_end
	var left := tip - dir * arrow_size + perp * arrow_size * 0.5
	var right := tip - dir * arrow_size - perp * arrow_size * 0.5
	_guide_canvas.draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(1, 1, 1, 0.8))

	# Pulsing glow on green dot (start here)
	var glow_r := DOT_RADIUS + 6.0 + pulse * 6.0
	_guide_canvas.draw_circle(_green_dot_pos, glow_r, Color(0.2, 0.9, 0.2, 0.15 + pulse * 0.1), false, 2.0)

# ── Miss feedback ──
#
# Release position is the primary aim factor (~90%). Swipe speed adds a small
# vertical nudge (~10%): faster = higher, slower = lower, medium = zero nudge.

func _show_miss_feedback(hit_pos: Vector2, hit_number: int) -> void:
	var delta := hit_pos - _target_board_pos
	var target: int = get_current_target()
	var feedback := ""

	if hit_number == 0:
		if hit_pos.y < -BoardData.BOARD_RADIUS:
			feedback = "Missed low! Release a bit higher, or swipe a bit faster"
		else:
			feedback = "Off the board! Release closer to the red dot"
	else:
		var horiz_off := absf(delta.x)
		var vert_off := absf(delta.y)

		if horiz_off > 0.25 and horiz_off > vert_off * 1.3:
			if delta.x > 0:
				feedback = "Drifted right. Release a little to the left"
			else:
				feedback = "Drifted left. Release a little to the right"

		elif vert_off > 0.25:
			if delta.y > 0:
				# Dart went HIGH — released too high or swiped too fast
				feedback = "Went high! Release a touch lower, or try a gentler swipe"
			else:
				# Dart went LOW — released too low or swiped too slowly
				feedback = "Fell short! Release a touch higher, or swipe a bit faster"
		else:
			feedback = "Close! You hit " + str(hit_number) + " — just a touch off. Try again"

	_feedback_label.text = feedback
	_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_feedback_label.visible = true
	_feedback_bg.color = Color(0.0, 0.0, 0.0, 0.8)
	_feedback_bg.visible = true

# ── Success / completion ──

func _show_success() -> void:
	_feedback_label.text = "Got it!"
	_feedback_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	_feedback_label.visible = true
	_feedback_bg.visible = true
	_feedback_bg.color = Color(0.0, 0.15, 0.0, 0.8)
	_instruction_label.visible = false
	_instruction_bg.visible = false
	_guide_canvas.visible = false

func _show_completion() -> void:
	_instruction_label.visible = false
	_instruction_bg.visible = false
	_guide_canvas.visible = false
	_feedback_label.text = "Nice one!\nYou've got the hang of it"
	_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	_feedback_label.visible = true
	_feedback_bg.visible = true
	_feedback_bg.color = Color(0.0, 0.0, 0.0, 0.8)

# ── Helpers ──

func _find_segment(number: int) -> int:
	for i in range(BoardData.SEGMENT_ORDER.size()):
		if BoardData.SEGMENT_ORDER[i] == number:
			return i
	return -1
