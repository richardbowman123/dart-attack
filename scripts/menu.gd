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

	# Main content — 40px side margins for consistency with card system
	var content := VBoxContainer.new()
	content.position = Vector2(40, 0)
	content.size = Vector2(640, 1280)
	content.add_theme_constant_override("separation", 0)
	add_child(content)

	_add_spacer(content, 50)

	# Title
	var title := Label.new()
	title.text = "DART ATTACK"
	UIFont.apply(title, UIFont.SCREEN_TITLE)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(640, 80)
	content.add_child(title)

	_add_spacer(content, 8)

	# Character name
	var char_index: int = GameState.character
	var display_name: String = DartData.get_full_name(char_index)
	if CareerState.nickname_active:
		var nick: String = DartData.get_character_nickname(char_index)
		display_name = DartData.get_character_name(char_index) + ' "' + nick + '" ' + display_name.split(" ")[-1]
	var player_label := Label.new()
	player_label.text = "Playing as " + display_name
	UIFont.apply(player_label, UIFont.CAPTION)
	player_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.2))
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_label.custom_minimum_size = Vector2(640, 40)
	content.add_child(player_label)

	_add_spacer(content, 40)

	# Barman portrait — centred
	var tex := load("res://Barman.jpg")
	if tex:
		var portrait_wrapper := CenterContainer.new()
		portrait_wrapper.custom_minimum_size = Vector2(640, 240)
		var portrait := TextureRect.new()
		portrait.texture = tex
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(240, 240)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_wrapper.add_child(portrait)
		content.add_child(portrait_wrapper)

	_add_spacer(content, 16)

	# "What will it be?"
	var quote := Label.new()
	quote.text = "\"What will it be?\""
	UIFont.apply(quote, UIFont.BODY)
	quote.add_theme_color_override("font_color", Color(0.85, 0.7, 0.2))
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote.custom_minimum_size = Vector2(640, 44)
	content.add_child(quote)

	_add_spacer(content, 50)

	# ── I'll Play button (green — career mode) ──
	if CareerState.career_level > 7:
		var champ_label := Label.new()
		champ_label.text = "WORLD CHAMPION!"
		UIFont.apply(champ_label, UIFont.HEADING)
		champ_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		champ_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		champ_label.custom_minimum_size = Vector2(640, 80)
		content.add_child(champ_label)
	else:
		var career_btn := _create_green_button("I'LL PLAY", 500, 80, UIFont.SUBHEADING)
		career_btn.pressed.connect(_on_career_pressed)
		var career_wrapper := CenterContainer.new()
		career_wrapper.custom_minimum_size = Vector2(640, 90)
		career_wrapper.add_child(career_btn)
		content.add_child(career_wrapper)

	_add_spacer(content, 15)

	# ── Teach Me button (blue — tutorial) ──
	var tut_btn := _create_blue_button("TEACH ME HOW TO PLAY!", 500, 80, UIFont.BODY)
	tut_btn.pressed.connect(_on_tutorial_pressed)
	var tut_wrapper := CenterContainer.new()
	tut_wrapper.custom_minimum_size = Vector2(640, 90)
	tut_wrapper.add_child(tut_btn)
	content.add_child(tut_wrapper)

	_add_spacer(content, 50)

	# ── Back button (muted) ──
	var back_btn := _create_back_button("BACK", 500, 70)
	back_btn.pressed.connect(_on_back_pressed)
	var back_wrapper := CenterContainer.new()
	back_wrapper.custom_minimum_size = Vector2(640, 80)
	back_wrapper.add_child(back_btn)
	content.add_child(back_wrapper)

	_add_spacer(content, 40)


# ── Helpers ──

func _add_spacer(parent: Control, height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(640, height)
	parent.add_child(spacer)

func _create_green_button(text: String, w: int, h: int, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(w, h)
	UIFont.apply_button(btn, font_size)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.1, 0.35, 0.12)
	normal_style.corner_radius_top_left = 12
	normal_style.corner_radius_top_right = 12
	normal_style.corner_radius_bottom_left = 12
	normal_style.corner_radius_bottom_right = 12
	normal_style.border_width_left = 3
	normal_style.border_width_right = 3
	normal_style.border_width_top = 3
	normal_style.border_width_bottom = 3
	normal_style.border_color = Color(0.2, 0.6, 0.25)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.15, 0.45, 0.18)
	hover_style.border_color = Color(0.3, 0.75, 0.35)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color(0.08, 0.28, 0.1)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(0.8, 1.0, 0.8))

	return btn

func _create_blue_button(text: String, w: int, h: int, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(w, h)
	UIFont.apply_button(btn, font_size)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.1, 0.2, 0.45)
	normal_style.corner_radius_top_left = 12
	normal_style.corner_radius_top_right = 12
	normal_style.corner_radius_bottom_left = 12
	normal_style.corner_radius_bottom_right = 12
	normal_style.border_width_left = 3
	normal_style.border_width_right = 3
	normal_style.border_width_top = 3
	normal_style.border_width_bottom = 3
	normal_style.border_color = Color(0.2, 0.4, 0.7)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.15, 0.3, 0.55)
	hover_style.border_color = Color(0.3, 0.5, 0.8)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color(0.08, 0.15, 0.35)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(0.8, 0.9, 1.0))

	return btn

func _create_back_button(text: String, w: int, h: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(w, h)
	UIFont.apply_button(btn, UIFont.BODY)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.13)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.25, 0.25, 0.3)
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = Color(0.15, 0.15, 0.2)
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

	return btn


# ── Actions ──

func _on_tutorial_pressed() -> void:
	GameState.game_mode = GameState.GameMode.TUTORIAL
	GameState.dart_tier = 0
	GameState.is_vs_ai = false
	GameState.opponent_id = ""
	CareerState.career_mode_active = false
	get_tree().change_scene_to_file("res://scenes/match.tscn")

func _on_career_pressed() -> void:
	# First career match — show the full intro sequence (barman, rules, opponent reveal)
	if CareerState.career_level == 1 and not CareerState.career_intro_seen:
		CareerState.career_mode_active = true
		get_tree().change_scene_to_file("res://scenes/career_intro.tscn")
		return

	# Resume career — set up current opponent and go
	var opp_id: String = OpponentData.OPPONENT_ORDER[CareerState.career_level - 1]
	var opp: Dictionary = OpponentData.get_opponent(opp_id)
	GameState.is_vs_ai = true
	GameState.opponent_id = opp_id
	CareerState.career_mode_active = true
	if opp["game_mode"] == "rtc":
		GameState.game_mode = GameState.GameMode.ROUND_THE_CLOCK
		GameState.starting_score = 0
	else:
		GameState.game_mode = GameState.GameMode.COUNTDOWN
		GameState.starting_score = opp["starting_score"]
	GameState.dart_tier = max(0, CareerState.dart_tier_owned)
	get_tree().change_scene_to_file("res://scenes/match.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")
