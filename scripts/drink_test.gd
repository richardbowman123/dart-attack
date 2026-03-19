extends Node3D

## Drink Test — standalone scene for testing the drunk vision shader.
## Shows a dartboard behind the UI so you can see blur/sway/vignette in action.
## Controls stay crisp (high CanvasLayer) while the 3D board gets blurry.

var _level_label: Label
var _tier_label: Label
var _intensity_label: Label
var _camera_rig: CameraRig
var _darts_container: Node3D
var _throw_system: ThrowSystem
var _active_darts: Array[Dart] = []


func _ready() -> void:
	DrinkManager.reset()
	_build_3d_scene()
	_build_ui()
	_update_display()


func _build_3d_scene() -> void:
	# Simple environment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.4, 0.45)
	env.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Camera rig — supports pinch-to-zoom, scroll wheel, WASD pan, R to reset
	_camera_rig = CameraRig.new()
	add_child(_camera_rig)

	# Dartboard — gives the shader something detailed to blur
	var board := Dartboard.new()
	add_child(board)

	# Oche lighting (same as match scene)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0.0, 2.5, 2.5)
	spot.look_at(Vector3.ZERO, Vector3.UP)
	spot.light_energy = 2.5
	spot.light_color = Color(1.0, 0.97, 0.92)
	spot.spot_range = 10.0
	spot.spot_angle = 45.0
	spot.shadow_enabled = true
	add_child(spot)

	# Darts container and throw system — throw darts while testing drunk vision
	_darts_container = Node3D.new()
	add_child(_darts_container)

	_throw_system = ThrowSystem.new()
	add_child(_throw_system)
	_throw_system.setup(_darts_container, Vector2(720, 1280), _camera_rig.get_camera())
	_throw_system.set_dart_tier(GameState.dart_tier)
	_throw_system.dart_thrown.connect(_on_dart_thrown)
	_throw_system.set_can_throw(true)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 25  # Above vision effect (5) — controls stay crisp
	add_child(ui)

	# Semi-transparent backdrop strip across the top for readability
	var top_bg := ColorRect.new()
	top_bg.color = Color(0.0, 0.0, 0.0, 0.5)
	top_bg.position = Vector2(0, 0)
	top_bg.size = Vector2(720, 320)
	top_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(top_bg)

	# Title
	var title := Label.new()
	title.text = "DRINK TEST"
	UIFont.apply(title, UIFont.HEADING)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 30)
	title.size = Vector2(720, 60)
	ui.add_child(title)

	# Big drinks level number
	_level_label = Label.new()
	UIFont.apply(_level_label, UIFont.DISPLAY)
	_level_label.add_theme_color_override("font_color", Color.WHITE)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.position = Vector2(0, 100)
	_level_label.size = Vector2(720, 130)
	ui.add_child(_level_label)

	# Tier description (SOBER / MILD / MODERATE / HEAVY)
	_tier_label = Label.new()
	UIFont.apply(_tier_label, UIFont.SUBHEADING)
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_label.position = Vector2(0, 230)
	_tier_label.size = Vector2(720, 45)
	ui.add_child(_tier_label)

	# Intensity percentage
	_intensity_label = Label.new()
	UIFont.apply(_intensity_label, UIFont.CAPTION)
	_intensity_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_intensity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intensity_label.position = Vector2(0, 275)
	_intensity_label.size = Vector2(720, 35)
	ui.add_child(_intensity_label)

	# ── Button row — centred near the bottom ──
	var btn_bg := ColorRect.new()
	btn_bg.color = Color(0.0, 0.0, 0.0, 0.5)
	btn_bg.position = Vector2(0, 1050)
	btn_bg.size = Vector2(720, 230)
	btn_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(btn_bg)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.position = Vector2(30, 1065)
	btn_row.size = Vector2(660, 80)
	ui.add_child(btn_row)

	var btn_minus := _make_btn("-1", Color(0.5, 0.2, 0.2), 145)
	btn_minus.pressed.connect(_on_minus)
	btn_row.add_child(btn_minus)

	var btn_reset := _make_btn("RESET", Color(0.25, 0.25, 0.3), 145)
	btn_reset.pressed.connect(_on_reset)
	btn_row.add_child(btn_reset)

	var btn_plus := _make_btn("+1", Color(0.6, 0.4, 0.1), 145)
	btn_plus.pressed.connect(_on_plus_one)
	btn_row.add_child(btn_plus)

	var btn_plus2 := _make_btn("+2", Color(0.7, 0.55, 0.05), 145)
	btn_plus2.pressed.connect(_on_plus_two)
	btn_row.add_child(btn_plus2)

	# Back button
	var back_btn := _make_btn("BACK TO MENU", Color(0.12, 0.12, 0.15), 660)
	back_btn.pressed.connect(_on_back)
	back_btn.position = Vector2(30, 1160)
	back_btn.size = Vector2(660, 70)
	ui.add_child(back_btn)


func _make_btn(text: String, bg_color: Color, w: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(w, 70)
	UIFont.apply_button(btn, UIFont.SUBHEADING)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))

	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = bg_color.lightened(0.3)
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = bg_color.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed)

	return btn


func _on_minus() -> void:
	DrinkManager.set_level(DrinkManager.drinks_level - 1)
	_update_display()


func _on_reset() -> void:
	DrinkManager.reset()
	_clear_darts()
	_update_display()


func _on_plus_one() -> void:
	DrinkManager.set_level(DrinkManager.drinks_level + 1)
	_update_display()


func _on_plus_two() -> void:
	DrinkManager.set_level(DrinkManager.drinks_level + 2)
	_update_display()


func _update_display() -> void:
	var level := DrinkManager.drinks_level
	var intensity := DrinkManager.get_effect_intensity()

	_level_label.text = str(level)
	_intensity_label.text = "Intensity: " + str(snapped(intensity * 100, 1)) + "%"

	# Tier name and colour
	if level <= 8:
		_tier_label.text = "SOBER"
		_tier_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	elif level <= 10:
		_tier_label.text = "HAMMERED"
		_tier_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	elif level <= 12:
		_tier_label.text = "ABSOLUTELY WRECKED"
		_tier_label.add_theme_color_override("font_color", Color(0.8, 0.1, 0.5))
	else:
		_tier_label.text = "PASSED OUT"
		_tier_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))


func _on_back() -> void:
	_clear_darts()
	DrinkManager.reset()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _on_dart_thrown(dart: Dart) -> void:
	_active_darts.append(dart)
	# Re-enable throwing after a short delay
	var tween := create_tween()
	tween.tween_interval(0.3)
	tween.tween_callback(func() -> void: _throw_system.set_can_throw(true))


func _clear_darts() -> void:
	for dart in _active_darts:
		if is_instance_valid(dart):
			dart.queue_free()
	_active_darts.clear()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		_on_back()
