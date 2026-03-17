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
	_add_spacer(content, 50)

	# Title
	var title := Label.new()
	title.text = "DART ATTACK"
	UIFont.apply(title, UIFont.SCREEN_TITLE)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(720, 80)
	content.add_child(title)

	_add_spacer(content, 8)

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

	# ── Tutorial (green, top of page) ──
	_add_spacer(content, 30)

	var tut_btn := _create_menu_button("Tutorial", 640, 80, UIFont.HEADING)
	tut_btn.pressed.connect(_on_tutorial_pressed)
	var tut_wrapper := CenterContainer.new()
	tut_wrapper.custom_minimum_size = Vector2(720, 90)
	tut_wrapper.add_child(tut_btn)
	content.add_child(tut_wrapper)

	# ── Practise (green, goes to submenu) ──
	_add_spacer(content, 5)

	var practise_btn := _create_menu_button("Practise", 640, 80, UIFont.HEADING)
	practise_btn.pressed.connect(_on_practise_pressed)
	var practise_wrapper := CenterContainer.new()
	practise_wrapper.custom_minimum_size = Vector2(720, 90)
	practise_wrapper.add_child(practise_btn)
	content.add_child(practise_wrapper)

	# ── Career Mode section ──
	_add_spacer(content, 30)

	var career_label := Label.new()
	career_label.text = "Career Mode"
	UIFont.apply(career_label, UIFont.SUBHEADING)
	career_label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.4))
	career_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	career_label.custom_minimum_size = Vector2(720, 44)
	content.add_child(career_label)

	_add_spacer(content, 10)

	var career_level: int = CareerState.career_level

	if career_level > 7:
		# Player has completed all levels — show all as beaten
		for i in range(7):
			_add_beaten_opponent(content, OpponentData.OPPONENT_ORDER[i])
		_add_spacer(content, 20)
		var champ_label := Label.new()
		champ_label.text = "WORLD CHAMPION!"
		UIFont.apply(champ_label, UIFont.HEADING)
		champ_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		champ_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		champ_label.custom_minimum_size = Vector2(720, 60)
		content.add_child(champ_label)
	else:
		# Show beaten opponents (greyed out, strikethrough)
		for i in range(career_level - 1):
			_add_beaten_opponent(content, OpponentData.OPPONENT_ORDER[i])

		# Current opponent — green, bigger, clickable
		var opp_id: String = OpponentData.OPPONENT_ORDER[career_level - 1]
		var label_text: String = OpponentData.get_menu_label(opp_id)
		var btn := _create_career_button(label_text, true)
		btn.pressed.connect(_on_vs_selected.bind(opp_id))
		var wrapper := CenterContainer.new()
		wrapper.custom_minimum_size = Vector2(720, 100)
		wrapper.add_child(btn)
		content.add_child(wrapper)

		# Next opponent — locked, recessed
		if career_level < 7:
			_add_spacer(content, 5)
			var next_opp_id: String = OpponentData.OPPONENT_ORDER[career_level]
			var next_label: String = OpponentData.get_menu_label(next_opp_id)
			var locked_btn := _create_career_button(next_label, false)
			locked_btn.disabled = true
			var locked_wrapper := CenterContainer.new()
			locked_wrapper.custom_minimum_size = Vector2(720, 70)
			locked_wrapper.add_child(locked_btn)
			content.add_child(locked_wrapper)

	# Big gap for future levels
	_add_spacer(content, 200)

	# ── Back button ──
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

	# ── Drink Effects (test mode — suppressed at very bottom) ──
	_add_spacer(content, 60)

	var drink_test_btn := _create_menu_button("Drink Effects", 400, 60, UIFont.CAPTION)
	var dt_style := StyleBoxFlat.new()
	dt_style.bg_color = Color(0.08, 0.08, 0.1)
	dt_style.corner_radius_top_left = 8
	dt_style.corner_radius_top_right = 8
	dt_style.corner_radius_bottom_left = 8
	dt_style.corner_radius_bottom_right = 8
	dt_style.border_width_left = 1
	dt_style.border_width_right = 1
	dt_style.border_width_top = 1
	dt_style.border_width_bottom = 1
	dt_style.border_color = Color(0.15, 0.15, 0.18)
	drink_test_btn.add_theme_stylebox_override("normal", dt_style)
	var dt_hover := dt_style.duplicate()
	dt_hover.bg_color = Color(0.12, 0.12, 0.15)
	drink_test_btn.add_theme_stylebox_override("hover", dt_hover)
	drink_test_btn.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
	drink_test_btn.add_theme_color_override("font_hover_color", Color(0.4, 0.4, 0.45))
	drink_test_btn.pressed.connect(_on_drink_test_pressed)
	var dt_wrapper := CenterContainer.new()
	dt_wrapper.custom_minimum_size = Vector2(720, 70)
	dt_wrapper.add_child(drink_test_btn)
	content.add_child(dt_wrapper)

	# Bottom padding
	_add_spacer(content, 40)

# ── Beaten opponent row (greyed out with strikethrough) ──

func _add_beaten_opponent(parent: Control, opp_id: String) -> void:
	var label_text: String = OpponentData.get_menu_label(opp_id)

	var row := Control.new()
	row.custom_minimum_size = Vector2(720, 50)

	# Greyed-out text
	var lbl := Label.new()
	lbl.text = label_text
	UIFont.apply(lbl, UIFont.BODY)
	lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.33))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, 0)
	lbl.size = Vector2(720, 50)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	# Strikethrough line
	var line := ColorRect.new()
	line.color = Color(0.3, 0.3, 0.33)
	var line_w := 300
	line.position = Vector2((720 - line_w) / 2.0, 24)
	line.size = Vector2(line_w, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)

	parent.add_child(row)

func _add_spacer(parent: Control, height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(720, height)
	parent.add_child(spacer)

func _create_green_button(text: String, w: int, h: int, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(w, h)
	UIFont.apply_button(btn, font_size)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.55, 0.2)
	normal_style.corner_radius_top_left = 12
	normal_style.corner_radius_top_right = 12
	normal_style.corner_radius_bottom_left = 12
	normal_style.corner_radius_bottom_right = 12
	normal_style.border_width_left = 3
	normal_style.border_width_right = 3
	normal_style.border_width_top = 3
	normal_style.border_width_bottom = 3
	normal_style.border_color = Color(0.3, 0.85, 0.4)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.2, 0.65, 0.25)
	hover_style.border_color = Color(0.4, 0.9, 0.5)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color(0.1, 0.45, 0.15)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))

	return btn

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

## Career opponent button — active (green, clickable) or locked (dark, disabled)
func _create_career_button(text: String, active: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	UIFont.apply_button(btn, UIFont.HEADING)

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3

	if active:
		# Green, bigger — the main call to action
		btn.custom_minimum_size = Vector2(640, 90)
		style.bg_color = Color(0.1, 0.35, 0.12)
		style.border_color = Color(0.2, 0.6, 0.25)
		btn.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate()
		hover.bg_color = Color(0.15, 0.45, 0.18)
		hover.border_color = Color(0.3, 0.75, 0.35)
		btn.add_theme_stylebox_override("hover", hover)
		var pressed := style.duplicate()
		pressed.bg_color = Color(0.08, 0.28, 0.1)
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color(0.8, 1.0, 0.8))
	else:
		# Locked — dark, muted, not interactive
		btn.custom_minimum_size = Vector2(640, 65)
		style.bg_color = Color(0.1, 0.07, 0.08)
		style.border_color = Color(0.2, 0.12, 0.12)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("disabled", style)
		btn.add_theme_color_override("font_color", Color(0.3, 0.2, 0.2))
		btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.2, 0.2))

	return btn

func _on_tutorial_pressed() -> void:
	GameState.game_mode = GameState.GameMode.TUTORIAL
	GameState.dart_tier = 0
	GameState.is_vs_ai = false
	GameState.opponent_id = ""
	CareerState.career_mode_active = false
	get_tree().change_scene_to_file("res://scenes/match.tscn")

func _on_practise_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/practise_menu.tscn")

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
	GameState.dart_tier = CareerState.dart_tier_owned
	get_tree().change_scene_to_file("res://scenes/match.tscn")

func _on_drink_test_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/drink_test.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")
