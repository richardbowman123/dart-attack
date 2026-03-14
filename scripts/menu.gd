extends Control

func _ready() -> void:
	_build_menu()

func _build_menu() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Title
	var title := Label.new()
	title.text = "DART ATTACK"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 200)
	title.size = Vector2(720, 70)
	add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Practice Mode"
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 280)
	subtitle.size = Vector2(720, 35)
	add_child(subtitle)

	# Buttons
	var button_data := [
		{"text": "Round the Clock", "mode": "rtc", "score": 0},
		{"text": "101", "mode": "countdown", "score": 101},
		{"text": "301", "mode": "countdown", "score": 301},
		{"text": "501", "mode": "countdown", "score": 501},
	]

	var start_y := 420
	var button_height := 70
	var button_gap := 20

	for i in range(button_data.size()):
		var data: Dictionary = button_data[i]
		var btn := Button.new()
		btn.text = data["text"]
		btn.position = Vector2(140, start_y + i * (button_height + button_gap))
		btn.size = Vector2(440, button_height)
		btn.add_theme_font_size_override("font_size", 28)

		# Style the button
		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = Color(0.15, 0.15, 0.2)
		normal_style.corner_radius_top_left = 8
		normal_style.corner_radius_top_right = 8
		normal_style.corner_radius_bottom_left = 8
		normal_style.corner_radius_bottom_right = 8
		normal_style.border_width_left = 2
		normal_style.border_width_right = 2
		normal_style.border_width_top = 2
		normal_style.border_width_bottom = 2
		normal_style.border_color = Color(0.3, 0.3, 0.35)
		btn.add_theme_stylebox_override("normal", normal_style)

		var hover_style := normal_style.duplicate()
		hover_style.bg_color = Color(0.2, 0.2, 0.28)
		hover_style.border_color = Color(0.5, 0.5, 0.6)
		btn.add_theme_stylebox_override("hover", hover_style)

		var pressed_style := normal_style.duplicate()
		pressed_style.bg_color = Color(0.25, 0.25, 0.35)
		btn.add_theme_stylebox_override("pressed", pressed_style)

		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.3))

		var mode: String = data["mode"]
		var score: int = data["score"]
		btn.pressed.connect(_on_mode_selected.bind(mode, score))
		add_child(btn)

func _on_mode_selected(mode: String, score: int) -> void:
	if mode == "rtc":
		GameState.game_mode = GameState.GameMode.ROUND_THE_CLOCK
	else:
		GameState.game_mode = GameState.GameMode.COUNTDOWN
		GameState.starting_score = score
	get_tree().change_scene_to_file("res://scenes/match.tscn")
