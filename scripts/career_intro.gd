extends Control

## Pre-match career intro — 5-card flow for Level 1 first play.
## Card 1: Career stars (all empty)
## Card 2: Barman scene (portrait + story + I'LL PLAY / NAH)
## Card 3: Rules check (YEAH, COURSE / NOT REALLY...)
## Card 4: Big Kev opponent card (portrait + stars + venue)
## Card 5: Dart choice (use own / ask bar → both give brass pub darts)

var _cards: Array[Control] = []
var _current_card: int = 0

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_build_card_1_stars()
	_build_card_2_barman()
	_build_card_3_rules()
	_build_card_4_opponent()
	_build_card_5_darts()

	_show_card(0)

# ══════════════════════════════════════════
# Card 1: Career Stars (all at 0/5)
# ══════════════════════════════════════════

func _build_card_1_stars() -> void:
	var card := _create_card()

	_add_spacer(card, 40)

	# Player portrait
	var portrait_path: String = DartData.get_profile_image(GameState.character)
	var tex := load(portrait_path)
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(640, 160)
		card.add_child(img)

	_add_spacer(card, 10)

	# Player name + nickname
	var char_name: String = DartData.get_character_name(GameState.character)
	var char_nick: String = DartData.get_character_nickname(GameState.character)
	var name_label := Label.new()
	name_label.text = char_name + '\n"' + char_nick + '"'
	UIFont.apply(name_label, UIFont.HEADING)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(640, 100)
	card.add_child(name_label)

	_add_spacer(card, 20)

	# Star rows — each animates in with staggered delay
	var star_data := [
		["SKILL", CareerState.skill_stars],
		["HEFT", CareerState.heft_tier],
		["HUSTLE", CareerState.hustle_stars],
		["SWAGGER", CareerState.swagger_stars],
	]
	var star_rows: Array[Control] = []
	for entry in star_data:
		var row := _career_stars_row(entry[0], entry[1], 5)
		row.modulate.a = 0.0
		card.add_child(row)
		star_rows.append(row)
		_add_spacer(card, 8)

	_add_spacer(card, 30)

	var quip := Label.new()
	quip.text = "Not looking good, is it?"
	UIFont.apply(quip, UIFont.BODY)
	quip.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	quip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quip.custom_minimum_size = Vector2(640, 50)
	quip.modulate.a = 0.0
	card.add_child(quip)

	_add_spacer(card, 40)

	var cont_wrapper := CenterContainer.new()
	cont_wrapper.custom_minimum_size = Vector2(640, 100)
	var cont_btn := _create_button("CONTINUE", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5))
	cont_btn.pressed.connect(_advance_card)
	cont_wrapper.add_child(cont_btn)
	cont_wrapper.modulate.a = 0.0
	card.add_child(cont_wrapper)

	_add_card(card, "Stars")

	# Animate rows in with staggered tweens
	var tween := create_tween()
	for i in range(star_rows.size()):
		tween.tween_property(star_rows[i], "modulate:a", 1.0, 0.3).set_delay(0.3 + i * 0.25)
	tween.tween_property(quip, "modulate:a", 1.0, 0.4).set_delay(0.2)
	tween.tween_property(cont_wrapper, "modulate:a", 1.0, 0.3).set_delay(0.3)

# ══════════════════════════════════════════
# Card 2: Barman Scene
# ══════════════════════════════════════════

func _build_card_2_barman() -> void:
	var card := _create_card()

	_add_spacer(card, 15)

	# Scene setting — location and time
	var venue_text: String = OpponentData.get_venue("big_kev", GameState.character)
	var setting := Label.new()
	setting.text = "Tuesday night.\n" + venue_text + "."
	UIFont.apply(setting, UIFont.BODY)
	setting.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	setting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setting.custom_minimum_size = Vector2(640, 0)
	card.add_child(setting)

	_add_spacer(card, 10)

	# Barman portrait
	var tex := load("res://Barman.jpg")
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(640, 160)
		card.add_child(img)

	_add_spacer(card, 10)

	# Dialogue
	var story := Label.new()
	story.text = "The barman leans over.\n\n\"We do a Round the Clock on Tuesday nights.\n\nOnly Big Kev's entered, so you might have a chance of winning.\n\nFancy it?\""
	UIFont.apply(story, UIFont.BODY)
	story.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.custom_minimum_size = Vector2(640, 0)
	card.add_child(story)

	_add_spacer(card, 20)

	# I'LL PLAY button (green, primary action)
	var play_btn := _create_button("I'LL PLAY", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	UIFont.apply_button(play_btn, UIFont.BODY)
	play_btn.custom_minimum_size = Vector2(500, 65)
	play_btn.pressed.connect(_advance_card)
	var play_wrapper := CenterContainer.new()
	play_wrapper.custom_minimum_size = Vector2(640, 70)
	play_wrapper.add_child(play_btn)
	card.add_child(play_wrapper)

	_add_spacer(card, 10)

	# NAH button (grey, secondary — same width as PLAY)
	var nah_btn := _create_button("NAH, I NEED TO LEARN\nTO PLAY FIRST", Color(0.2, 0.2, 0.25), Color(0.4, 0.4, 0.45))
	UIFont.apply_button(nah_btn, UIFont.CAPTION)
	nah_btn.custom_minimum_size = Vector2(500, 65)
	nah_btn.pressed.connect(_on_nah)
	var nah_wrapper := CenterContainer.new()
	nah_wrapper.custom_minimum_size = Vector2(640, 70)
	nah_wrapper.add_child(nah_btn)
	card.add_child(nah_wrapper)

	_add_card(card, "Barman")

# ══════════════════════════════════════════
# Card 3: Rules Check
# ══════════════════════════════════════════

func _build_card_3_rules() -> void:
	var card := _create_card()

	_add_spacer(card, 30)

	# Barman portrait
	var tex := load("res://Barman.jpg")
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(640, 160)
		card.add_child(img)

	_add_spacer(card, 15)

	var question := Label.new()
	question.text = "\"You know how Round the Clock works, yeah?\""
	UIFont.apply(question, UIFont.BODY)
	question.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.custom_minimum_size = Vector2(640, 80)
	card.add_child(question)

	_add_spacer(card, 20)

	# Choice buttons container
	var choice_box := VBoxContainer.new()
	choice_box.add_theme_constant_override("separation", 15)
	choice_box.custom_minimum_size = Vector2(640, 220)

	var yeah_btn := _create_button("YEAH, COURSE", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	yeah_btn.pressed.connect(_advance_card)
	var yeah_wrapper := CenterContainer.new()
	yeah_wrapper.custom_minimum_size = Vector2(640, 100)
	yeah_wrapper.add_child(yeah_btn)
	choice_box.add_child(yeah_wrapper)

	var not_really_btn := _create_button("NOT REALLY...", Color(0.2, 0.2, 0.25), Color(0.4, 0.4, 0.45))
	var not_wrapper := CenterContainer.new()
	not_wrapper.custom_minimum_size = Vector2(640, 100)
	not_wrapper.add_child(not_really_btn)
	choice_box.add_child(not_wrapper)

	card.add_child(choice_box)

	# Explanation text (hidden initially)
	var explain := Label.new()
	explain.text = "\"Simple. Hit 1 through 20, in order.\n\nFirst to finish wins.\n\nHit a double, skip a number.\nTrebles skip two.\n\nFinish on outer bull, then bull.\""
	UIFont.apply(explain, UIFont.BODY)
	explain.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	explain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explain.custom_minimum_size = Vector2(640, 250)
	explain.visible = false
	card.add_child(explain)

	_add_spacer(card, 20)

	# GOT IT button (hidden initially)
	var got_it_btn := _create_button("GOT IT", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	got_it_btn.pressed.connect(_advance_card)
	var got_wrapper := CenterContainer.new()
	got_wrapper.custom_minimum_size = Vector2(640, 100)
	got_wrapper.add_child(got_it_btn)
	got_wrapper.visible = false
	card.add_child(got_wrapper)

	not_really_btn.pressed.connect(func():
		choice_box.visible = false
		explain.visible = true
		got_wrapper.visible = true
	)

	_add_card(card, "Rules")

# ══════════════════════════════════════════
# Card 4: Big Kev Opponent Card
# ══════════════════════════════════════════

func _build_card_4_opponent() -> void:
	var card := _create_card()

	_add_spacer(card, 30)

	# "YOUR OPPONENT" header (yellow — standard for all opponent reveal cards)
	var header := Label.new()
	header.text = "YOUR OPPONENT"
	UIFont.apply(header, UIFont.SUBHEADING)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.custom_minimum_size = Vector2(640, 50)
	card.add_child(header)

	_add_spacer(card, 10)

	# Opponent portrait
	var tex := load("res://Big Kev.jpg")
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(640, 160)
		card.add_child(img)

	_add_spacer(card, 10)

	# Name + nickname
	var name_label := Label.new()
	name_label.text = "Big Kev\n\"THE FRIDGE\""
	UIFont.apply(name_label, UIFont.HEADING)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(640, 90)
	card.add_child(name_label)

	_add_spacer(card, 10)

	# His star ratings
	var kev_skill := _career_stars_row("SKILL", 2, 5)
	card.add_child(kev_skill)
	var kev_heft := _career_stars_row("HEFT", 4, 5)
	card.add_child(kev_heft)
	var kev_hustle := _career_stars_row("HUSTLE", 1, 5)
	card.add_child(kev_hustle)
	var kev_swagger := _career_stars_row("SWAGGER", 3, 5)
	card.add_child(kev_swagger)

	_add_spacer(card, 10)

	# Venue
	var venue_text: String = OpponentData.get_venue("big_kev", GameState.character)
	var venue_label := Label.new()
	venue_label.text = venue_text + "\nRound the Clock\nFree entry"
	UIFont.apply(venue_label, UIFont.BODY)
	venue_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	venue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	venue_label.custom_minimum_size = Vector2(640, 100)
	card.add_child(venue_label)

	_add_spacer(card, 20)

	_add_continue_button(card)

	_add_card(card, "Opponent")

# ══════════════════════════════════════════
# Card 5: Dart Choice
# ══════════════════════════════════════════

func _build_card_5_darts() -> void:
	var card := _create_card()

	_add_spacer(card, 200)

	var question := Label.new()
	question.text = "Which darts do you want to use?"
	UIFont.apply(question, UIFont.HEADING)
	question.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.custom_minimum_size = Vector2(640, 100)
	card.add_child(question)

	_add_spacer(card, 40)

	# Choice buttons
	var btn_own := _create_button("USE MY OWN DARTS", Color(0.15, 0.15, 0.2), Color(0.3, 0.3, 0.35))
	var own_wrapper := CenterContainer.new()
	own_wrapper.custom_minimum_size = Vector2(640, 100)
	own_wrapper.add_child(btn_own)
	card.add_child(own_wrapper)

	var btn_bar := _create_button("ASK BEHIND THE BAR", Color(0.15, 0.15, 0.2), Color(0.3, 0.3, 0.35))
	var bar_wrapper := CenterContainer.new()
	bar_wrapper.custom_minimum_size = Vector2(640, 100)
	bar_wrapper.add_child(btn_bar)
	card.add_child(bar_wrapper)

	_add_spacer(card, 20)

	# Post-choice message (hidden initially)
	var msg := Label.new()
	UIFont.apply(msg, UIFont.BODY)
	msg.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(640, 150)
	msg.visible = false
	card.add_child(msg)

	_add_spacer(card, 20)

	# LET'S GO button (hidden initially)
	var go_btn := _create_button("LET'S GO", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	go_btn.pressed.connect(_on_lets_go)
	var go_wrapper := CenterContainer.new()
	go_wrapper.custom_minimum_size = Vector2(640, 100)
	go_wrapper.add_child(go_btn)
	go_wrapper.visible = false
	card.add_child(go_wrapper)

	btn_own.pressed.connect(func():
		own_wrapper.visible = false
		bar_wrapper.visible = false
		msg.text = "You're broke. You can't afford any darts right now.\n\nThe barman rummages around behind the bar and hands you a set of old pub brass darts from a jar."
		msg.visible = true
		go_wrapper.visible = true
		GameState.dart_tier = 0
	)

	btn_bar.pressed.connect(func():
		own_wrapper.visible = false
		bar_wrapper.visible = false
		msg.text = "The barman rummages around behind the bar and pulls out a jar of old brass darts.\n\n\"These'll do you for now.\""
		msg.visible = true
		go_wrapper.visible = true
		GameState.dart_tier = 0
	)

	_add_card(card, "Darts")

# ══════════════════════════════════════════
# Card system (shared pattern with match_results)
# ══════════════════════════════════════════

func _create_card() -> VBoxContainer:
	var card := VBoxContainer.new()
	card.position = Vector2(40, 0)
	card.size = Vector2(640, 1280)
	card.add_theme_constant_override("separation", 0)
	card.visible = false
	return card

func _add_card(card: VBoxContainer, card_name: String) -> void:
	CardValidator.validate(card, card_name)
	_cards.append(card)
	add_child(card)

func _show_card(index: int) -> void:
	for i in range(_cards.size()):
		_cards[i].visible = (i == index)
	_current_card = index

func _advance_card() -> void:
	if _current_card < _cards.size() - 1:
		_show_card(_current_card + 1)

func _add_spacer(parent: Control, height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(640, height)
	parent.add_child(spacer)

func _add_continue_button(card: Control) -> void:
	var btn := _create_button("CONTINUE", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5))
	btn.pressed.connect(_advance_card)
	var wrapper := CenterContainer.new()
	wrapper.custom_minimum_size = Vector2(640, 100)
	wrapper.add_child(btn)
	card.add_child(wrapper)

func _create_button(text: String, bg_color: Color, border_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(500, 90)
	UIFont.apply_button(btn, UIFont.HEADING)
	btn.add_theme_color_override("font_color", Color.WHITE)

	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = border_color
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = bg_color * 1.3
	hover.border_color = border_color * 1.2
	btn.add_theme_stylebox_override("hover", hover)

	return btn

# ══════════════════════════════════════════
# Star row helper
# ══════════════════════════════════════════

func _build_star_image(filled: int) -> TextureRect:
	var img := TextureRect.new()
	var path_png := "res://Star ratings/Stars " + str(filled) + ".png"
	var path_jpg := "res://Star ratings/" + str(filled) + " stars.jpg"
	var tex = load(path_png)
	if tex == null:
		tex = load(path_jpg)
	if tex:
		img.texture = tex
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(260, 44)
	img.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return img

func _career_stars_row(cat_name: String, filled: int, _total: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(640, 50)

	var label := Label.new()
	label.text = cat_name
	label.custom_minimum_size = Vector2(180, 50)
	UIFont.apply(label, UIFont.BODY)
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(label)

	row.add_child(_build_star_image(filled))

	return row

# ══════════════════════════════════════════
# Navigation
# ══════════════════════════════════════════

func _on_nah() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _on_lets_go() -> void:
	GameState.is_vs_ai = true
	GameState.opponent_id = "big_kev"
	GameState.game_mode = GameState.GameMode.ROUND_THE_CLOCK
	GameState.starting_score = 0
	CareerState.career_mode_active = true
	CareerState.career_intro_seen = true
	get_tree().change_scene_to_file("res://scenes/match.tscn")
