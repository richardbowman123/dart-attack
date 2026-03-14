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
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 60)
	title.size = Vector2(720, 58)
	add_child(title)

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
	player_label.add_theme_font_size_override("font_size", 18)
	player_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.2))
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.position = Vector2(0, 130)
	player_label.size = Vector2(720, 26)
	add_child(player_label)

	# ── Game mode section ──
	var mode_label := Label.new()
	mode_label.text = "Choose your game"
	mode_label.add_theme_font_size_override("font_size", 20)
	mode_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.position = Vector2(0, 200)
	mode_label.size = Vector2(720, 28)
	add_child(mode_label)

	var button_data := [
		{"text": "Tutorial", "mode": "tutorial", "score": 0},
		{"text": "Round the Clock", "mode": "rtc", "score": 0},
		{"text": "101", "mode": "countdown", "score": 101},
		{"text": "301", "mode": "countdown", "score": 301},
		{"text": "501", "mode": "countdown", "score": 501},
	]

	var btn_start_y := 250
	var btn_h := 58
	var btn_gap := 12

	for i in range(button_data.size()):
		var data: Dictionary = button_data[i]
		_build_mode_button(data, btn_start_y + i * (btn_h + btn_gap), btn_h)

	# ── Back button ──
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(140, btn_start_y + button_data.size() * (btn_h + btn_gap) + 20)
	back_btn.size = Vector2(440, 50)
	back_btn.add_theme_font_size_override("font_size", 22)

	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.1, 0.1, 0.13)
	back_style.corner_radius_top_left = 8
	back_style.corner_radius_top_right = 8
	back_style.corner_radius_bottom_left = 8
	back_style.corner_radius_bottom_right = 8
	back_style.border_width_left = 2
	back_style.border_width_right = 2
	back_style.border_width_top = 2
	back_style.border_width_bottom = 2
	back_style.border_color = Color(0.25, 0.25, 0.3)
	back_btn.add_theme_stylebox_override("normal", back_style)

	var back_hover := back_style.duplicate()
	back_hover.bg_color = Color(0.15, 0.15, 0.2)
	back_btn.add_theme_stylebox_override("hover", back_hover)

	back_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	back_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)

func _build_mode_button(data: Dictionary, y: int, h: int) -> void:
	var btn := Button.new()
	var btn_text: String = data["text"]
	btn.text = btn_text
	btn.position = Vector2(140, y)
	btn.size = Vector2(440, h)
	btn.add_theme_font_size_override("font_size", 26)

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
	if mode == "tutorial":
		GameState.game_mode = GameState.GameMode.TUTORIAL
	elif mode == "rtc":
		GameState.game_mode = GameState.GameMode.ROUND_THE_CLOCK
	else:
		GameState.game_mode = GameState.GameMode.COUNTDOWN
		GameState.starting_score = score
	get_tree().change_scene_to_file("res://scenes/dart_select.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")
