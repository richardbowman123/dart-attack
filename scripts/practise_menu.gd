extends Control

func _ready() -> void:
	_build_menu()

func _build_menu() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Scrollable container
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 0)
	scroll.size = Vector2(720, 1280)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 0)
	scroll.add_child(content)

	_add_spacer(content, 50)

	# Title
	var title := Label.new()
	title.text = "PRACTISE"
	UIFont.apply(title, UIFont.SCREEN_TITLE)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(720, 80)
	content.add_child(title)

	_add_spacer(content, 40)

	# Practice modes
	var button_data := [
		{"text": "Round the Clock", "mode": "rtc", "score": 0},
		{"text": "101", "mode": "countdown", "score": 101},
		{"text": "301", "mode": "countdown", "score": 301},
		{"text": "501", "mode": "countdown", "score": 501},
		{"text": "Free Throw", "mode": "free_throw", "score": 0},
	]

	for data in button_data:
		var btn := _create_button(data["text"], 640, 80, UIFont.HEADING)
		btn.pressed.connect(_on_mode_selected.bind(data["mode"], data["score"]))
		var wrapper := CenterContainer.new()
		wrapper.custom_minimum_size = Vector2(720, 90)
		wrapper.add_child(btn)
		content.add_child(wrapper)

	# Back button
	_add_spacer(content, 40)

	var back_btn := _create_button("BACK", 640, 80, UIFont.SUBHEADING)
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.1, 0.1, 0.13)
	back_style.corner_radius_top_left = 12
	back_style.corner_radius_top_right = 12
	back_style.corner_radius_bottom_left = 12
	back_style.corner_radius_bottom_right = 12
	back_style.border_width_left = 3
	back_style.border_width_right = 3
	back_style.border_width_top = 3
	back_style.border_width_bottom = 3
	back_style.border_color = Color(0.25, 0.25, 0.3)
	back_btn.add_theme_stylebox_override("normal", back_style)
	var back_hover := back_style.duplicate()
	back_hover.bg_color = Color(0.15, 0.15, 0.2)
	back_btn.add_theme_stylebox_override("hover", back_hover)
	back_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	back_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	back_btn.pressed.connect(_on_back_pressed)
	var back_wrapper := CenterContainer.new()
	back_wrapper.custom_minimum_size = Vector2(720, 90)
	back_wrapper.add_child(back_btn)
	content.add_child(back_wrapper)

	_add_spacer(content, 40)

func _add_spacer(parent: Control, height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(720, height)
	parent.add_child(spacer)

func _create_button(text: String, w: int, h: int, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(w, h)
	UIFont.apply_button(btn, font_size)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.15, 0.2)
	normal_style.corner_radius_top_left = 12
	normal_style.corner_radius_top_right = 12
	normal_style.corner_radius_bottom_left = 12
	normal_style.corner_radius_bottom_right = 12
	normal_style.border_width_left = 3
	normal_style.border_width_right = 3
	normal_style.border_width_top = 3
	normal_style.border_width_bottom = 3
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

	return btn

func _on_mode_selected(mode: String, score: int) -> void:
	GameState.is_vs_ai = false
	GameState.opponent_id = ""
	CareerState.career_mode_active = false
	if mode == "free_throw":
		GameState.game_mode = GameState.GameMode.FREE_THROW
	elif mode == "rtc":
		GameState.game_mode = GameState.GameMode.ROUND_THE_CLOCK
	else:
		GameState.game_mode = GameState.GameMode.COUNTDOWN
		GameState.starting_score = score
	get_tree().change_scene_to_file("res://scenes/dart_select.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
