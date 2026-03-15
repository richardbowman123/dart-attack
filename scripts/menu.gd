extends Control

func _ready() -> void:
	# Reset VS mode flag when returning to menu
	GameState.is_vs_ai = false
	GameState.opponent_id = ""
	_build_menu()

func _build_menu() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Scrollable container for all content
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 0)
	scroll.size = Vector2(720, 1280)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 0)
	scroll.add_child(content)

	# Spacer at top
	var top_spacer := Control.new()
	top_spacer.custom_minimum_size = Vector2(720, 50)
	content.add_child(top_spacer)

	# Title
	var title := Label.new()
	title.text = "DART ATTACK"
	UIFont.apply(title, UIFont.SCREEN_TITLE)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(720, 80)
	content.add_child(title)

	# Spacer
	var sp1 := Control.new()
	sp1.custom_minimum_size = Vector2(720, 8)
	content.add_child(sp1)

	# Show selected character name
	var names := [
		"Dai \"The Dragon\" Davies",
		"Terry \"The Hammer\" Hoskins",
		"Rab \"The Flame\" McTavish",
		"Siobhan \"The Banshee\" O'Hara",
	]
	var char_index: int = GameState.character
	var player_label := Label.new()
	player_label.text = "Playing as " + names[char_index]
	UIFont.apply(player_label, UIFont.CAPTION)
	player_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.2))
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_label.custom_minimum_size = Vector2(720, 40)
	content.add_child(player_label)

	# ── Tutorial button ──
	var tut_spacer := Control.new()
	tut_spacer.custom_minimum_size = Vector2(720, 30)
	content.add_child(tut_spacer)

	var tut_btn := _create_menu_button("Tutorial", 640, 80, UIFont.HEADING)
	tut_btn.pressed.connect(_on_tutorial_pressed)
	var tut_wrapper := CenterContainer.new()
	tut_wrapper.custom_minimum_size = Vector2(720, 90)
	tut_wrapper.add_child(tut_btn)
	content.add_child(tut_wrapper)

	# ── Practice section ──
	var practice_spacer := Control.new()
	practice_spacer.custom_minimum_size = Vector2(720, 30)
	content.add_child(practice_spacer)

	var practice_label := Label.new()
	practice_label.text = "Practice"
	UIFont.apply(practice_label, UIFont.SUBHEADING)
	practice_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	practice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	practice_label.custom_minimum_size = Vector2(720, 44)
	content.add_child(practice_label)

	var practice_gap := Control.new()
	practice_gap.custom_minimum_size = Vector2(720, 10)
	content.add_child(practice_gap)

	var button_data := [
		{"text": "Round the Clock", "mode": "rtc", "score": 0},
		{"text": "101", "mode": "countdown", "score": 101},
		{"text": "301", "mode": "countdown", "score": 301},
		{"text": "501", "mode": "countdown", "score": 501},
	]

	for data in button_data:
		var btn := _create_menu_button(data["text"], 640, 80, UIFont.HEADING)
		btn.pressed.connect(_on_mode_selected.bind(data["mode"], data["score"]))
		var wrapper := CenterContainer.new()
		wrapper.custom_minimum_size = Vector2(720, 90)
		wrapper.add_child(btn)
		content.add_child(wrapper)

	# ── VS Opponent section ──
	var vs_spacer := Control.new()
	vs_spacer.custom_minimum_size = Vector2(720, 30)
	content.add_child(vs_spacer)

	var vs_label := Label.new()
	vs_label.text = "Career Mode"
	UIFont.apply(vs_label, UIFont.SUBHEADING)
	vs_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_label.custom_minimum_size = Vector2(720, 44)
	content.add_child(vs_label)

	var vs_gap := Control.new()
	vs_gap.custom_minimum_size = Vector2(720, 10)
	content.add_child(vs_gap)

	# Career Mode: only show Big Kev for now (unlock others later)
	var career_opponents := ["big_kev"]
	for opp_id in career_opponents:
		var label_text: String = OpponentData.get_menu_label(opp_id)
		var btn := _create_menu_button(label_text, 640, 80, UIFont.HEADING)
		# Red-tinted style for VS buttons
		var vs_style := StyleBoxFlat.new()
		vs_style.bg_color = Color(0.2, 0.1, 0.12)
		vs_style.corner_radius_top_left = 12
		vs_style.corner_radius_top_right = 12
		vs_style.corner_radius_bottom_left = 12
		vs_style.corner_radius_bottom_right = 12
		vs_style.border_width_left = 3
		vs_style.border_width_right = 3
		vs_style.border_width_top = 3
		vs_style.border_width_bottom = 3
		vs_style.border_color = Color(0.4, 0.2, 0.2)
		btn.add_theme_stylebox_override("normal", vs_style)
		var vs_hover := vs_style.duplicate()
		vs_hover.bg_color = Color(0.3, 0.15, 0.15)
		vs_hover.border_color = Color(0.6, 0.3, 0.3)
		btn.add_theme_stylebox_override("hover", vs_hover)
		var vs_pressed := vs_style.duplicate()
		vs_pressed.bg_color = Color(0.35, 0.18, 0.18)
		btn.add_theme_stylebox_override("pressed", vs_pressed)
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.6, 0.5))
		btn.pressed.connect(_on_vs_selected.bind(opp_id))
		var wrapper := CenterContainer.new()
		wrapper.custom_minimum_size = Vector2(720, 90)
		wrapper.add_child(btn)
		content.add_child(wrapper)

	# ── Back button ──
	var back_spacer := Control.new()
	back_spacer.custom_minimum_size = Vector2(720, 30)
	content.add_child(back_spacer)

	var back_btn := _create_menu_button("BACK", 640, 80, UIFont.SUBHEADING)
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

	# Bottom padding
	var bottom_spacer := Control.new()
	bottom_spacer.custom_minimum_size = Vector2(720, 40)
	content.add_child(bottom_spacer)

func _create_menu_button(text: String, w: int, h: int, font_size: int) -> Button:
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

func _on_tutorial_pressed() -> void:
	GameState.game_mode = GameState.GameMode.TUTORIAL
	GameState.dart_tier = 0
	GameState.is_vs_ai = false
	GameState.opponent_id = ""
	CareerState.career_mode_active = false
	get_tree().change_scene_to_file("res://scenes/match.tscn")

func _on_mode_selected(mode: String, score: int) -> void:
	GameState.is_vs_ai = false
	GameState.opponent_id = ""
	CareerState.career_mode_active = false
	if mode == "rtc":
		GameState.game_mode = GameState.GameMode.ROUND_THE_CLOCK
	else:
		GameState.game_mode = GameState.GameMode.COUNTDOWN
		GameState.starting_score = score
	get_tree().change_scene_to_file("res://scenes/dart_select.tscn")

func _on_vs_selected(opponent_id: String) -> void:
	var opp: Dictionary = OpponentData.get_opponent(opponent_id)
	GameState.is_vs_ai = true
	GameState.opponent_id = opponent_id
	CareerState.career_mode_active = true
	if opp["game_mode"] == "rtc":
		GameState.game_mode = GameState.GameMode.ROUND_THE_CLOCK
		GameState.starting_score = 0
	else:
		GameState.game_mode = GameState.GameMode.COUNTDOWN
		GameState.starting_score = opp["starting_score"]
	get_tree().change_scene_to_file("res://scenes/career_dart_choice.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")
