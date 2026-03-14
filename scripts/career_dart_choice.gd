extends Control

# Career mode dart choice — "Use your own" or "Ask behind the bar"
# At Level 1 (Big Kev), the player is broke. Either choice gives them pub brass (tier 0).

var _message_label: Label
var _btn_own: Button
var _btn_bar: Button
var _continue_btn: Button

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Title
	var title := Label.new()
	title.text = "CAREER MODE"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 120)
	title.size = Vector2(720, 55)
	add_child(title)

	# Opponent info
	var opp_name := OpponentData.get_display_name(GameState.opponent_id)
	var opp_nick := OpponentData.get_nickname(GameState.opponent_id)
	var vs_label := Label.new()
	vs_label.text = "vs " + opp_name + ' "' + opp_nick + '"'
	vs_label.add_theme_font_size_override("font_size", 22)
	vs_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_label.position = Vector2(0, 185)
	vs_label.size = Vector2(720, 30)
	add_child(vs_label)

	# Mode label
	var mode_label := Label.new()
	mode_label.text = "Round the Clock"
	if GameState.game_mode == GameState.GameMode.COUNTDOWN:
		mode_label.text = str(GameState.starting_score)
	mode_label.add_theme_font_size_override("font_size", 18)
	mode_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.position = Vector2(0, 225)
	mode_label.size = Vector2(720, 26)
	add_child(mode_label)

	# Question
	var question := Label.new()
	question.text = "Which darts do you want to use?"
	question.add_theme_font_size_override("font_size", 26)
	question.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.position = Vector2(0, 380)
	question.size = Vector2(720, 36)
	add_child(question)

	# Two choice buttons
	_btn_own = _create_choice_button("Use my own darts", Vector2(110, 460))
	_btn_own.pressed.connect(_on_use_own)
	add_child(_btn_own)

	_btn_bar = _create_choice_button("Ask what they've got behind the bar", Vector2(110, 540))
	_btn_bar.pressed.connect(_on_ask_bar)
	add_child(_btn_bar)

	# Message area (hidden until a choice is made)
	_message_label = Label.new()
	_message_label.add_theme_font_size_override("font_size", 22)
	_message_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.position = Vector2(60, 680)
	_message_label.size = Vector2(600, 200)
	_message_label.visible = false
	add_child(_message_label)

	# Continue button (hidden until message shown)
	_continue_btn = Button.new()
	_continue_btn.text = "LET'S GO"
	_continue_btn.position = Vector2(210, 920)
	_continue_btn.size = Vector2(300, 70)
	_continue_btn.add_theme_font_size_override("font_size", 28)
	_continue_btn.add_theme_color_override("font_color", Color.WHITE)
	_continue_btn.visible = false

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.5, 0.2)
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
	btn_style.border_width_left = 2
	btn_style.border_width_right = 2
	btn_style.border_width_top = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.3, 0.8, 0.4)
	_continue_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.2, 0.6, 0.25)
	_continue_btn.add_theme_stylebox_override("hover", btn_hover)

	_continue_btn.pressed.connect(_on_continue)
	add_child(_continue_btn)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(260, 1170)
	back_btn.size = Vector2(200, 60)
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))

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

	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

func _create_choice_button(text: String, pos: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = Vector2(500, 60)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color.WHITE)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.35)
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = Color(0.2, 0.2, 0.28)
	hover.border_color = Color(0.5, 0.5, 0.6)
	btn.add_theme_stylebox_override("hover", hover)

	return btn

func _on_use_own() -> void:
	_btn_own.visible = false
	_btn_bar.visible = false
	_message_label.text = "You're broke. You can't afford any darts right now.\n\nThe barman rummages around and hands you a set of pub brass from a jar behind the bar."
	_message_label.visible = true
	_continue_btn.visible = true
	GameState.dart_tier = 0

func _on_ask_bar() -> void:
	_btn_own.visible = false
	_btn_bar.visible = false
	_message_label.text = "The barman rummages around behind the bar and pulls out a jar of old brass darts.\n\n\"These'll do you for now.\""
	_message_label.visible = true
	_continue_btn.visible = true
	GameState.dart_tier = 0

func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/match.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
