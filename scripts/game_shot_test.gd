extends Node3D
class_name GameShotTest

## Game Shot Test — standalone cinematic camera test scene.
## Player aims and throws at a dartboard. On release, a cinematic
## side-tracking shot follows the dart to wherever it actually lands,
## then orbits to reveal the result.

var _dartboard: Dartboard
var _camera_rig: CameraRig
var _throw_system: ThrowSystem
var _darts_container: Node3D
var _cinematic: CinematicCamera
var _hud: CanvasLayer
var _status_label: Label
var _instruction_label: Label
var _active_darts: Array[Dart] = []

# State
var _waiting_for_throw := true
var _cinematic_active := false
var _darts_thrown := 0  # Count total darts so we can show previous ones


func _ready() -> void:
	_setup_environment()
	_build_scene()
	_build_hud()
	_enable_throwing()


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

	# Same oche lighting as the main match
	var spot_positions := [
		Vector3(0.0, 2.5, 2.5),
		Vector3(-1.8, 2.0, 2.0),
		Vector3(1.8, 2.0, 2.0),
		Vector3(-1.2, -1.8, 2.0),
		Vector3(1.2, -1.8, 2.0),
	]
	var spot_energies := [2.5, 1.5, 1.5, 1.0, 1.0]

	for i in range(spot_positions.size()):
		var spot := SpotLight3D.new()
		spot.position = spot_positions[i]
		spot.look_at(Vector3(0, 0, 0), Vector3.UP)
		spot.light_energy = spot_energies[i]
		spot.light_color = Color(1.0, 0.97, 0.92)
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


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)

	# Status label (top centre)
	_status_label = Label.new()
	_status_label.text = "GAME SHOT TEST"
	UIFont.apply(_status_label, UIFont.SUBHEADING)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.position = Vector2(0, 20)
	_status_label.size = Vector2(720, 50)
	_hud.add_child(_status_label)

	# Target label
	var target_label := Label.new()
	target_label.text = "CINEMATIC CAMERA TEST"
	UIFont.apply(target_label, UIFont.CAPTION)
	target_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_label.position = Vector2(0, 70)
	target_label.size = Vector2(720, 36)
	_hud.add_child(target_label)

	# Instruction label (bottom)
	_instruction_label = Label.new()
	_instruction_label.text = "Throw the dart!"
	UIFont.apply(_instruction_label, UIFont.BODY)
	_instruction_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction_label.position = Vector2(0, 1220)
	_instruction_label.size = Vector2(720, 44)
	_hud.add_child(_instruction_label)

	# Back button (top left)
	var back_btn := Button.new()
	back_btn.text = "BACK"
	UIFont.apply_button(back_btn, UIFont.CAPTION)
	back_btn.position = Vector2(20, 20)
	back_btn.custom_minimum_size = Vector2(120, 50)
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	back_style.corner_radius_top_left = 8
	back_style.corner_radius_top_right = 8
	back_style.corner_radius_bottom_left = 8
	back_style.corner_radius_bottom_right = 8
	back_btn.add_theme_stylebox_override("normal", back_style)
	back_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	back_btn.pressed.connect(_on_back_pressed)
	_hud.add_child(back_btn)


func _enable_throwing() -> void:
	_waiting_for_throw = true
	_cinematic_active = false
	_throw_system.set_can_throw(true)
	if not _throw_system.dart_thrown.is_connected(_on_dart_thrown):
		_throw_system.dart_thrown.connect(_on_dart_thrown)
	_instruction_label.text = "Throw the dart!"


func _on_dart_thrown(dart: Dart) -> void:
	_waiting_for_throw = false
	_throw_system.set_can_throw(false)
	_instruction_label.text = ""

	# Grab the dart's actual throw position — the throw system places the dart
	# at (target.x, target.y) and fires straight along Z, so the XY position
	# IS where the dart will land on the board.
	var spawn_pos := dart.global_position
	var landing_pos := Vector2(spawn_pos.x, spawn_pos.y)

	# Kill the physics dart immediately — cinematic takes over from here
	dart.visible = false
	dart.freeze = true
	dart.gravity_scale = 0.0
	dart.linear_velocity = Vector3.ZERO
	dart.contact_monitor = false
	dart.set_physics_process(false)

	# Determine hit or miss — game shot requires hitting a double
	var score_data = BoardData.get_score(landing_pos)
	var is_hit = score_data["multiplier"] == 2  # Only doubles count as a game shot

	# Track this dart
	_active_darts.append(dart)
	_darts_thrown += 1

	# Hide the HUD during cinematic
	_status_label.visible = false

	# Start the cinematic after a brief beat (feels more natural)
	var tween := create_tween()
	tween.tween_interval(0.15)
	tween.tween_callback(_start_cinematic.bind(spawn_pos, landing_pos, is_hit, dart))


func _start_cinematic(spawn_pos: Vector3, landing_2d: Vector2, is_hit: bool, original_dart: Dart) -> void:
	_cinematic_active = true

	# Disable camera rig controls during cinematic
	_camera_rig.set_process(false)
	_camera_rig.set_process_input(false)
	_camera_rig.set_process_unhandled_input(false)

	# Create cinematic controller
	_cinematic = CinematicCamera.new()
	add_child(_cinematic)

	_cinematic.setup(_camera_rig.get_camera(), spawn_pos, landing_2d, is_hit, GameState.dart_tier)
	_cinematic.cinematic_finished.connect(_on_cinematic_finished.bind(landing_2d, is_hit, original_dart))
	_cinematic.play()


func _on_cinematic_finished(landing_2d: Vector2, is_hit: bool, original_dart: Dart) -> void:
	_cinematic_active = false

	# Place the original dart at the landing position.
	# Scoring point (landing_2d) is where the shaft crosses the board surface (Z=0).
	# Dart body is offset above and in front of that point due to impact angle.
	original_dart.visible = true
	original_dart.global_position = CinematicCamera.get_resting_position(landing_2d, GameState.dart_tier)
	var impact_dir := CinematicCamera.get_resting_direction()
	original_dart.look_at(original_dart.global_position + impact_dir, Vector3.UP)

	# Clean up cinematic
	_cinematic.cleanup()
	_cinematic.queue_free()
	_cinematic = null

	# Restore camera rig
	_camera_rig.set_process(true)
	_camera_rig.set_process_input(true)
	_camera_rig.set_process_unhandled_input(true)
	_camera_rig.reset_view()

	# Show status again
	_status_label.visible = true
	_status_label.text = "GAME SHOT!" if is_hit else "MISS!"
	_status_label.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.1) if is_hit else Color(0.9, 0.3, 0.25))

	# After a pause, allow another throw
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(_reset_for_next_throw)


func _reset_for_next_throw() -> void:
	# Clear darts every 3 throws (like the main game)
	if _active_darts.size() >= 3:
		for dart in _active_darts:
			if is_instance_valid(dart):
				dart.queue_free()
		_active_darts.clear()

	_status_label.text = "GAME SHOT TEST"
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))

	# Reconnect throw signal (it was one-shot per throw)
	if not _throw_system.dart_thrown.is_connected(_on_dart_thrown):
		_throw_system.dart_thrown.connect(_on_dart_thrown)
	_throw_system.set_can_throw(true)
	_instruction_label.text = "Throw the dart!"
	_waiting_for_throw = true



func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
