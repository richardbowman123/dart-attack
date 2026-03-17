extends Control

## Post-match results screen — multi-card flow.
## Level 1 Win: Prize -> Skill star -> Big Kev dialogue -> Buffet decision -> Heft star ->
##              Barman L2 -> Friday night -> Doubles explanation -> Mate intro -> Derek stats
## Level 2 Win: Prize -> Skill star -> Mate shopping -> Shopping decision -> Swagger star ->
##              Mate introduces Steve -> Bridge -> Steve stats
## Level 3 Win: Prize -> Skill star -> Steve dialogue -> Inflatables -> Coach offer ->
##              Hustle star -> Bridge -> Philip stats
## Level 4 Win: Prize -> Skill star -> Manager offer -> Hustle star -> Gambling intro ->
##              Bridge -> Mad Dog stats
## Level 5 Win: Prize -> Skill star (MAX) -> Sponsor intro -> Team offer -> Hustle star ->
##              Doctor hint -> Bridge -> Lars stats
## Level 6 Win: Prize -> All stars snapshot -> Coach dialogue -> Doctor visit ->
##              Vinnie Gold intro -> Bridge -> Vinnie stats
## Level 7 Win: Prize -> Final stars -> Ending -> New Career
## Loss: Level-specific flavour text + strikes or career over

var _cards: Array[Control] = []
var _current_card: int = 0
var _card_animations: Dictionary = {}

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	if GameState.match_won:
		_build_win_cards()
	else:
		_build_loss_card()

	_show_card(0)

# ======================================================
# WIN FLOW
# ======================================================

func _build_win_cards() -> void:
	var prize: int = GameState.match_prize
	var opp_id: String = GameState.opponent_id
	var opp_name: String = OpponentData.get_display_name(opp_id)
	var opp_nick: String = OpponentData.get_nickname(opp_id)
	var opp_level: int = OpponentData.get_opponent(opp_id)["level"]

	# Card 1: Prize Money (all levels)
	_build_prize_card(opp_name, opp_nick, prize)

	# Branch by level
	if CareerState.career_level > 7:
		_build_world_champion_cards()
	elif opp_level == 1:
		_build_skill_star_card()
		_build_bigkev_dialogue_card()
		_build_chinese_buffet_card()
		_build_heft_star_card()
		_build_barman_level2_card()
		_build_friday_night_card()
		_build_doubles_explanation_card()
		_build_mate_intro_card()
		_build_derek_stats_card()
	elif opp_level == 2:
		_build_l2_win_cards()
	elif opp_level == 3:
		_build_l3_win_cards()
	elif opp_level == 4:
		_build_l4_win_cards()
	elif opp_level == 5:
		_build_l5_win_cards()
	elif opp_level == 6:
		_build_l6_win_cards()
	else:
		_build_generic_story_card(opp_level)
		_build_generic_next_opponent_card()

# ======================================================
# PRIZE CARD (all levels)
# ======================================================

func _build_prize_card(opp_name: String, opp_nick: String, prize: int) -> void:
	var card := _create_card()

	_add_spacer(card, 150)

	var win_label := Label.new()
	win_label.text = "YOU WIN!"
	UIFont.apply(win_label, UIFont.SCREEN_TITLE)
	win_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.custom_minimum_size = Vector2(640, 90)
	card.add_child(win_label)

	_add_spacer(card, 10)

	var vs_label := Label.new()
	vs_label.text = "vs " + opp_name + ' "' + opp_nick + '"'
	UIFont.apply(vs_label, UIFont.SUBHEADING)
	vs_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vs_label.custom_minimum_size = Vector2(640, 50)
	card.add_child(vs_label)

	_add_spacer(card, 50)

	var prize_label := Label.new()
	prize_label.text = _format_money(prize)
	UIFont.apply(prize_label, UIFont.DISPLAY)
	prize_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	prize_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prize_label.custom_minimum_size = Vector2(640, 130)
	card.add_child(prize_label)

	_add_spacer(card, 10)

	var balance_label := Label.new()
	balance_label.text = "Balance: " + _format_money(CareerState.money)
	UIFont.apply(balance_label, UIFont.BODY)
	balance_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_label.custom_minimum_size = Vector2(640, 50)
	card.add_child(balance_label)

	_add_spacer(card, 80)

	_add_continue_button(card)
	_add_card(card, "Prize")

# ======================================================
# LEVEL 1 WIN CARDS (existing — kept as-is)
# ======================================================

func _build_skill_star_card() -> void:
	var card := _create_card()

	_add_spacer(card, 40)

	# Player portrait
	var portrait_path: String = DartData.get_profile_image(GameState.character)
	var tex := load(portrait_path)
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(640, 220)
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
	name_label.custom_minimum_size = Vector2(640, 90)
	card.add_child(name_label)

	_add_spacer(card, 15)

	# SKILL row — category label stays visible, only stars flip
	var skill_row := HBoxContainer.new()
	skill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_row.add_theme_constant_override("separation", 10)
	skill_row.custom_minimum_size = Vector2(640, 50)
	var skill_label := Label.new()
	skill_label.text = "SKILL"
	skill_label.custom_minimum_size = Vector2(180, 50)
	UIFont.apply(skill_label, UIFont.BODY)
	skill_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skill_row.add_child(skill_label)
	# Stars overlay — only this part flips
	var skill_stars_wrapper := Control.new()
	skill_stars_wrapper.custom_minimum_size = Vector2(200, 50)
	skill_stars_wrapper.pivot_offset = Vector2(100, 25)
	var skill_stars_before := Label.new()
	skill_stars_before.text = _stars_string(0, 5)
	skill_stars_before.position = Vector2.ZERO
	skill_stars_before.size = Vector2(200, 50)
	UIFont.apply(skill_stars_before, UIFont.BODY)
	skill_stars_before.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	skill_stars_before.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	skill_stars_wrapper.add_child(skill_stars_before)
	var skill_stars_after := Label.new()
	skill_stars_after.text = _stars_string(1, 5)
	skill_stars_after.position = Vector2.ZERO
	skill_stars_after.size = Vector2(200, 50)
	UIFont.apply(skill_stars_after, UIFont.BODY)
	skill_stars_after.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	skill_stars_after.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	skill_stars_after.visible = false
	skill_stars_wrapper.add_child(skill_stars_after)
	skill_row.add_child(skill_stars_wrapper)
	card.add_child(skill_row)

	# Other star rows (static except SWAGGER which also flips)
	card.add_child(_career_stars_row("HEFT", CareerState.heft_tier, 5))
	card.add_child(_career_stars_row("HUSTLE", CareerState.hustle_stars, 5))

	# SWAGGER row — flips 0→1 right after SKILL
	var swagger_row := HBoxContainer.new()
	swagger_row.alignment = BoxContainer.ALIGNMENT_CENTER
	swagger_row.add_theme_constant_override("separation", 10)
	swagger_row.custom_minimum_size = Vector2(640, 50)
	var swagger_label := Label.new()
	swagger_label.text = "SWAGGER"
	swagger_label.custom_minimum_size = Vector2(180, 50)
	UIFont.apply(swagger_label, UIFont.BODY)
	swagger_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	swagger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	swagger_row.add_child(swagger_label)
	var swagger_stars_wrapper := Control.new()
	swagger_stars_wrapper.custom_minimum_size = Vector2(200, 50)
	swagger_stars_wrapper.pivot_offset = Vector2(100, 25)
	var swagger_stars_before := Label.new()
	swagger_stars_before.text = _stars_string(0, 5)
	swagger_stars_before.position = Vector2.ZERO
	swagger_stars_before.size = Vector2(200, 50)
	UIFont.apply(swagger_stars_before, UIFont.BODY)
	swagger_stars_before.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	swagger_stars_before.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	swagger_stars_wrapper.add_child(swagger_stars_before)
	var swagger_stars_after := Label.new()
	swagger_stars_after.text = _stars_string(1, 5)
	swagger_stars_after.position = Vector2.ZERO
	swagger_stars_after.size = Vector2(200, 50)
	UIFont.apply(swagger_stars_after, UIFont.BODY)
	swagger_stars_after.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	swagger_stars_after.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	swagger_stars_after.visible = false
	swagger_stars_wrapper.add_child(swagger_stars_after)
	swagger_row.add_child(swagger_stars_wrapper)
	card.add_child(swagger_row)

	_add_spacer(card, 25)

	# Quip (fades in after animation -- running commentary, no speech marks)
	var quip := Label.new()
	quip.text = "You can actually play."
	UIFont.apply(quip, UIFont.BODY)
	quip.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	quip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quip.custom_minimum_size = Vector2(640, 50)
	quip.modulate.a = 0.0
	card.add_child(quip)

	_add_spacer(card, 25)

	var cont_wrapper := CenterContainer.new()
	cont_wrapper.custom_minimum_size = Vector2(640, 100)
	var cont_btn := _create_button("CONTINUE", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5))
	cont_btn.pressed.connect(_advance_card)
	cont_wrapper.add_child(cont_btn)
	cont_wrapper.modulate.a = 0.0
	card.add_child(cont_wrapper)

	# Set the stars
	CareerState.skill_stars = 1
	CareerState.swagger_stars = 1

	_add_card(card, "Skill Star")

	# Deferred animation — skill flips first, then swagger flips immediately after
	var card_idx := _cards.size() - 1
	_card_animations[card_idx] = func():
		var tween := create_tween()
		# SKILL flip
		tween.tween_property(skill_stars_wrapper, "scale:y", 0.0, 0.15).set_delay(0.8)
		tween.tween_callback(func():
			skill_stars_before.visible = false
			skill_stars_after.visible = true
		)
		tween.tween_property(skill_stars_wrapper, "scale:y", 1.0, 0.15)
		# SWAGGER flip — starts right after SKILL finishes
		tween.tween_property(swagger_stars_wrapper, "scale:y", 0.0, 0.15).set_delay(0.3)
		tween.tween_callback(func():
			swagger_stars_before.visible = false
			swagger_stars_after.visible = true
		)
		tween.tween_property(swagger_stars_wrapper, "scale:y", 1.0, 0.15)
		# Quip and button fade in after both flips
		tween.tween_property(quip, "modulate:a", 1.0, 0.3).set_delay(0.3)
		tween.tween_property(cont_wrapper, "modulate:a", 1.0, 0.3).set_delay(0.2)

func _build_bigkev_dialogue_card() -> void:
	var card := _create_card()

	_add_spacer(card, 60)

	# Narrative setup (above the panel)
	var narrative := Label.new()
	narrative.text = "Big Kev shakes your hand."
	UIFont.apply(narrative, UIFont.BODY)
	narrative.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	narrative.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	narrative.custom_minimum_size = Vector2(640, 50)
	card.add_child(narrative)

	_add_spacer(card, 15)

	# Big Kev panel with real portrait
	var panel := _build_companion_panel(
		"BIG KEV",
		"\"Not bad. Not bad at all.\"\n\nHe slides a voucher across the bar.\n\n\"All-you-can-eat Chinese buffet. On me.\n\nGet yourself fed.\nYou'll need it.\"",
		Color.BLACK, "", "res://Big Kev.jpg"
	)
	card.add_child(panel)

	_add_spacer(card, 25)

	_add_continue_button(card)
	_add_card(card, "Big Kev Dialogue")

func _build_chinese_buffet_card() -> void:
	var card := _create_card()

	_add_spacer(card, 150)

	var title_label := Label.new()
	title_label.text = "ALL-YOU-CAN-EAT BUFFET"
	UIFont.apply(title_label, UIFont.HEADING)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.custom_minimum_size = Vector2(640, 70)
	card.add_child(title_label)

	_add_spacer(card, 30)

	var desc_label := Label.new()
	desc_label.text = "Big Kev's Chinese buffet voucher.\nCrispy duck, sweet and sour,\nthe works."
	UIFont.apply(desc_label, UIFont.BODY)
	desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(640, 120)
	card.add_child(desc_label)

	_add_spacer(card, 50)

	# Choice buttons
	var use_btn := _create_button("USE VOUCHER", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	var use_wrapper := CenterContainer.new()
	use_wrapper.custom_minimum_size = Vector2(640, 100)
	use_wrapper.add_child(use_btn)
	card.add_child(use_wrapper)

	_add_spacer(card, 10)

	var skip_btn := _create_button("NO THANKS", Color(0.2, 0.2, 0.25), Color(0.4, 0.4, 0.45))
	var skip_wrapper := CenterContainer.new()
	skip_wrapper.custom_minimum_size = Vector2(640, 100)
	skip_wrapper.add_child(skip_btn)
	card.add_child(skip_wrapper)

	# USE VOUCHER: increment heft, advance to heft snapshot card
	use_btn.pressed.connect(func():
		CareerState.heft_tier += 1
		_advance_card()
	)

	# NO THANKS: skip past the heft snapshot card (advance by 2)
	skip_btn.pressed.connect(func():
		if _current_card + 2 < _cards.size():
			_show_card(_current_card + 2)
		else:
			_advance_card()
	)

	_add_card(card, "Chinese Buffet")

func _build_heft_star_card() -> void:
	var card := _create_card()

	_add_spacer(card, 40)

	var portrait_path: String = DartData.get_profile_image(GameState.character)
	var tex := load(portrait_path)
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(640, 220)
		card.add_child(img)

	_add_spacer(card, 10)

	var char_name: String = DartData.get_character_name(GameState.character)
	var char_nick: String = DartData.get_character_nickname(GameState.character)
	var name_label := Label.new()
	name_label.text = char_name + '\n"' + char_nick + '"'
	UIFont.apply(name_label, UIFont.HEADING)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(640, 90)
	card.add_child(name_label)

	_add_spacer(card, 15)

	# Star rows -- HEFT animates from 0 to 1
	card.add_child(_career_stars_row("SKILL", CareerState.skill_stars, 5))

	# HEFT row -- category label stays visible, only stars flip
	var heft_row := HBoxContainer.new()
	heft_row.alignment = BoxContainer.ALIGNMENT_CENTER
	heft_row.add_theme_constant_override("separation", 10)
	heft_row.custom_minimum_size = Vector2(640, 50)
	var heft_label := Label.new()
	heft_label.text = "HEFT"
	heft_label.custom_minimum_size = Vector2(180, 50)
	UIFont.apply(heft_label, UIFont.BODY)
	heft_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	heft_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heft_row.add_child(heft_label)
	var heft_stars_wrapper := Control.new()
	heft_stars_wrapper.custom_minimum_size = Vector2(200, 50)
	heft_stars_wrapper.pivot_offset = Vector2(100, 25)
	var heft_stars_before := Label.new()
	heft_stars_before.text = _stars_string(0, 5)
	heft_stars_before.position = Vector2.ZERO
	heft_stars_before.size = Vector2(200, 50)
	UIFont.apply(heft_stars_before, UIFont.BODY)
	heft_stars_before.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	heft_stars_before.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heft_stars_wrapper.add_child(heft_stars_before)
	var heft_stars_after := Label.new()
	heft_stars_after.text = _stars_string(1, 5)
	heft_stars_after.position = Vector2.ZERO
	heft_stars_after.size = Vector2(200, 50)
	UIFont.apply(heft_stars_after, UIFont.BODY)
	heft_stars_after.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	heft_stars_after.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heft_stars_after.visible = false
	heft_stars_wrapper.add_child(heft_stars_after)
	heft_row.add_child(heft_stars_wrapper)
	card.add_child(heft_row)

	card.add_child(_career_stars_row("HUSTLE", CareerState.hustle_stars, 5))
	card.add_child(_career_stars_row("SWAGGER", CareerState.swagger_stars, 5))

	_add_spacer(card, 25)

	var quip := Label.new()
	quip.text = "Feeling heavier already.\nBetter grip on those darts."
	UIFont.apply(quip, UIFont.BODY)
	quip.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	quip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quip.custom_minimum_size = Vector2(640, 60)
	quip.modulate.a = 0.0
	card.add_child(quip)

	_add_spacer(card, 20)

	var cont_wrapper := CenterContainer.new()
	cont_wrapper.custom_minimum_size = Vector2(640, 100)
	var cont_btn := _create_button("CONTINUE", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5))
	cont_btn.pressed.connect(_advance_card)
	cont_wrapper.add_child(cont_btn)
	cont_wrapper.modulate.a = 0.0
	card.add_child(cont_wrapper)

	_add_card(card, "Heft Star")

	var card_idx := _cards.size() - 1
	_card_animations[card_idx] = func():
		var tween := create_tween()
		tween.tween_property(heft_stars_wrapper, "scale:y", 0.0, 0.15).set_delay(0.8)
		tween.tween_callback(func():
			heft_stars_before.visible = false
			heft_stars_after.visible = true
		)
		tween.tween_property(heft_stars_wrapper, "scale:y", 1.0, 0.15)
		tween.tween_property(quip, "modulate:a", 1.0, 0.3).set_delay(0.3)
		tween.tween_property(cont_wrapper, "modulate:a", 1.0, 0.3).set_delay(0.2)

func _build_barman_level2_card() -> void:
	var card := _create_card()

	_add_spacer(card, 30)

	var tex := load("res://Barman.jpg")
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(640, 100)
		card.add_child(img)

	_add_spacer(card, 10)

	var next_venue: String = OpponentData.get_venue("derek", GameState.character)

	var story := Label.new()
	story.text = "The barman catches you on the way out.\n\n\"There's a proper tournament Friday night. 101. Five quid entry.\n\n" + next_venue + ".\n\nYou'll need your own darts, mind.\""
	UIFont.apply(story, UIFont.BODY)
	story.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.custom_minimum_size = Vector2(640, 200)
	card.add_child(story)

	_add_spacer(card, 15)

	_add_continue_button(card)
	_add_card(card, "Barman L2")

func _build_friday_night_card() -> void:
	var card := _create_card()

	_add_spacer(card, 100)

	var next_venue: String = OpponentData.get_venue("derek", GameState.character)
	var dart_cost: int = 500
	var pre_balance: int = CareerState.money

	var story1 := Label.new()
	story1.text = "Friday comes around quick enough.\n\nYour mate drags you to the sports shop on the way. Brass darts. Five quid.\nOut of your winnings."
	UIFont.apply(story1, UIFont.BODY)
	story1.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	story1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story1.custom_minimum_size = Vector2(640, 0)
	card.add_child(story1)

	_add_spacer(card, 10)

	var balance_label := Label.new()
	balance_label.text = "Balance: " + _format_money(pre_balance)
	UIFont.apply(balance_label, UIFont.BODY)
	balance_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_label.custom_minimum_size = Vector2(640, 40)
	card.add_child(balance_label)

	var deduction_label := Label.new()
	deduction_label.text = "Brass darts: -" + _format_money(dart_cost)
	UIFont.apply(deduction_label, UIFont.CAPTION)
	deduction_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
	deduction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deduction_label.custom_minimum_size = Vector2(640, 35)
	deduction_label.modulate.a = 0.0
	card.add_child(deduction_label)

	_add_spacer(card, 15)

	var story2 := Label.new()
	story2.text = next_venue + ".\n\nThere's actually a crowd.\nWell, eight people. Still more than Tuesday."
	UIFont.apply(story2, UIFont.BODY)
	story2.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	story2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story2.custom_minimum_size = Vector2(640, 0)
	card.add_child(story2)

	CareerState.money -= dart_cost
	CareerState.dart_tier_owned = 0
	GameState.dart_tier = 0

	_add_spacer(card, 20)

	_add_continue_button(card)
	_add_card(card, "Friday Night")

	var card_idx := _cards.size() - 1
	_card_animations[card_idx] = func():
		var tween := create_tween()
		tween.tween_property(deduction_label, "modulate:a", 1.0, 0.3).set_delay(1.0)
		tween.tween_property(balance_label, "modulate:a", 0.0, 0.2).set_delay(0.3)
		tween.tween_callback(func(): balance_label.text = "Balance: " + _format_money(CareerState.money))
		tween.tween_property(balance_label, "modulate:a", 1.0, 0.3)

func _build_doubles_explanation_card() -> void:
	var card := _create_card()

	_add_spacer(card, 60)

	var panel := _build_companion_panel(
		"YOUR MATE",
		"This one's 101. You know you have to check out on a double, yeah?",
		Color(0.2, 0.35, 0.5), "M"
	)
	card.add_child(panel)

	_add_spacer(card, 20)

	# Choice buttons
	var choice_box := VBoxContainer.new()
	choice_box.add_theme_constant_override("separation", 15)
	choice_box.custom_minimum_size = Vector2(640, 220)

	var yeah_btn := _create_button("YEAH, COURSE", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	yeah_btn.pressed.connect(_advance_card)
	var yeah_wrapper := CenterContainer.new()
	yeah_wrapper.custom_minimum_size = Vector2(640, 100)
	yeah_wrapper.add_child(yeah_btn)
	choice_box.add_child(yeah_wrapper)

	var not_btn := _create_button("NOT REALLY...", Color(0.2, 0.2, 0.25), Color(0.4, 0.4, 0.45))
	var not_wrapper := CenterContainer.new()
	not_wrapper.custom_minimum_size = Vector2(640, 100)
	not_wrapper.add_child(not_btn)
	choice_box.add_child(not_wrapper)

	card.add_child(choice_box)

	# Explanation (hidden initially)
	var explain := RichTextLabel.new()
	explain.bbcode_enabled = true
	explain.text = "You start on 101. Each dart takes your score down.\n\n[color=#ffdd44]Your last dart has to be a double[/color] to take you down to zero.\n\nSo if you're on 32, you need double 16. On 20, double 10.\n\nGet your score down, then finish on the double."
	UIFont.apply_rich(explain, UIFont.BODY)
	explain.add_theme_color_override("default_color", Color(0.85, 0.85, 0.9))
	explain.scroll_active = false
	explain.fit_content = true
	explain.custom_minimum_size = Vector2(640, 250)
	explain.visible = false
	card.add_child(explain)

	_add_spacer(card, 15)

	var got_btn := _create_button("GOT IT", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	got_btn.pressed.connect(_advance_card)
	var got_wrapper := CenterContainer.new()
	got_wrapper.custom_minimum_size = Vector2(640, 100)
	got_wrapper.add_child(got_btn)
	got_wrapper.visible = false
	card.add_child(got_wrapper)

	not_btn.pressed.connect(func():
		choice_box.visible = false
		explain.visible = true
		got_wrapper.visible = true
	)

	_add_card(card, "Doubles")

func _build_mate_intro_card() -> void:
	var card := _create_card()

	_add_spacer(card, 50)

	var tex := load("res://Derek.jpg")
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(640, 220)
		card.add_child(img)
		_add_spacer(card, 15)

	var panel := _build_companion_panel(
		"YOUR MATE",
		"Derek \"The Postman\" they call him.\n\nI can't see him being too much of a problem.",
		Color(0.2, 0.35, 0.5), "M"
	)
	card.add_child(panel)

	_add_spacer(card, 25)

	_add_continue_button(card)
	_add_card(card, "Mate Intro")

func _build_derek_stats_card() -> void:
	_build_opponent_stats_card(
		"derek", "Derek", "The Postman",
		{"SKILL": 4, "HEFT": 1, "HUSTLE": 4, "SWAGGER": 0},
		"101"
	)

# ======================================================
# LEVEL 2 POST-WIN (Beat Derek "The Postman")
# ======================================================

func _build_l2_win_cards() -> void:
	# Card 2: Skill star 1->2
	_build_star_flip_card("SKILL", CareerState.skill_stars, CareerState.skill_stars + 1, "Friday night champion.", func(): CareerState.skill_stars += 1)

	# Card 3: Mate dialogue
	var mate_card := _create_card()
	_add_spacer(mate_card, 60)
	var mate_panel := _build_companion_panel(
		"YOUR MATE",
		"Told you he wouldn't deliver. Come on - let's get you looking the part. Tattoos and a bit of bling.",
		Color(0.2, 0.35, 0.5), "M"
	)
	mate_card.add_child(mate_panel)
	_add_spacer(mate_card, 30)
	_add_continue_button(mate_card)
	_add_card(mate_card, "L2 Mate")

	# Card 4: Shopping decision
	var shop_card := _create_card()
	_add_spacer(shop_card, 120)
	var shop_title := Label.new()
	shop_title.text = "SHOPPING SPREE"
	UIFont.apply(shop_title, UIFont.HEADING)
	shop_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_title.custom_minimum_size = Vector2(640, 70)
	shop_card.add_child(shop_title)
	_add_spacer(shop_card, 20)
	var shop_desc := Label.new()
	shop_desc.text = "Matching tattoos and a sovereign ring.\nYour mate's treat. Well, mostly."
	UIFont.apply(shop_desc, UIFont.BODY)
	shop_desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	shop_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_desc.custom_minimum_size = Vector2(640, 100)
	shop_card.add_child(shop_desc)
	_add_spacer(shop_card, 10)
	var shop_cost := Label.new()
	shop_cost.text = "Cost: " + _format_money(2000)
	UIFont.apply(shop_cost, UIFont.BODY)
	shop_cost.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
	shop_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_cost.custom_minimum_size = Vector2(640, 40)
	shop_card.add_child(shop_cost)
	_add_spacer(shop_card, 30)
	var shop_yes := _create_button("LET'S DO IT", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	var shop_yes_w := CenterContainer.new()
	shop_yes_w.custom_minimum_size = Vector2(640, 100)
	shop_yes_w.add_child(shop_yes)
	shop_card.add_child(shop_yes_w)
	_add_spacer(shop_card, 10)
	var shop_no := _create_button("NAH, SAVE IT", Color(0.2, 0.2, 0.25), Color(0.4, 0.4, 0.45))
	var shop_no_w := CenterContainer.new()
	shop_no_w.custom_minimum_size = Vector2(640, 100)
	shop_no_w.add_child(shop_no)
	shop_card.add_child(shop_no_w)

	shop_yes.pressed.connect(func():
		CareerState.money -= 2000
		CareerState.swagger_stars = 1
		_advance_card()
	)
	shop_no.pressed.connect(func():
		# Skip swagger star card
		if _current_card + 2 < _cards.size():
			_show_card(_current_card + 2)
		else:
			_advance_card()
	)
	_add_card(shop_card, "L2 Shopping")

	# Card 5: Swagger star (only if shopped)
	_build_star_flip_card("SWAGGER", 0, 1, "Looking dangerous.", null)

	# Card 6: Mate introduces Steve
	var steve_intro := _create_card()
	_add_spacer(steve_intro, 60)
	var steve_panel := _build_companion_panel(
		"YOUR MATE",
		"There's a regional comp next month. Steve \"The Sparky\" - three years running. Bit of a wind-up merchant. Talks through your throw.\n\nBest of seven this time. First to four legs.",
		Color(0.2, 0.35, 0.5), "M"
	)
	steve_intro.add_child(steve_panel)
	_add_spacer(steve_intro, 30)
	_add_continue_button(steve_intro)
	_add_card(steve_intro, "L2 Steve Intro")

	# Card 7: Bridge card
	var next_venue: String = OpponentData.get_venue("steve", GameState.character)
	_build_bridge_card(
		"Four weeks later.",
		next_venue,
		"Proper oche. Small stage. Folding chairs for fifty. A commentator with a microphone.",
		2000
	)

	# Card 8: Steve stats
	_build_opponent_stats_card(
		"steve", "Steve", "The Sparky",
		{"SKILL": 3, "HEFT": 2, "HUSTLE": 2, "SWAGGER": 1},
		"101 - Best of 7"
	)

# ======================================================
# LEVEL 3 POST-WIN (Beat Steve "The Sparky")
# ======================================================

func _build_l3_win_cards() -> void:
	# Card 2: Skill star 2->3
	_build_star_flip_card("SKILL", CareerState.skill_stars, CareerState.skill_stars + 1, "Regional champion. People are talking.", func(): CareerState.skill_stars += 1)

	# Card 3: Steve post-win dialogue
	var steve_card := _create_card()
	_add_spacer(steve_card, 60)
	var steve_panel := _build_companion_panel(
		"STEVE",
		"Steve shakes his head.\n\n\"Three years I've had that title. Three years.\"\n\nHe hands you a pint.\n\n\"Fair play. You earned it.\"",
		Color(0.5, 0.35, 0.15), "S"
	)
	steve_card.add_child(steve_panel)
	_add_spacer(steve_card, 30)
	_add_continue_button(steve_card)
	_add_card(steve_card, "L3 Steve Dialogue")

	# Card 4: Car park encounter — The Trader
	var trader_card := _create_card()
	_add_spacer(trader_card, 60)
	var trader_panel := _build_companion_panel(
		"THE TRADER",
		"A bloke in a hi-vis catches you in the car park.\n\n\"You're getting a following, son. People need something to wave.\"\n\nHe opens the back of a van. Your face is on an inflatable.",
		Color(0.7, 0.7, 0.1), "T"
	)
	trader_card.add_child(trader_panel)
	_add_spacer(trader_card, 30)
	_add_continue_button(trader_card)
	_add_card(trader_card, "L3 Trader")

	# Card 5: Inflatables decision
	var infl_card := _create_card()
	_add_spacer(infl_card, 120)
	var infl_title := Label.new()
	infl_title.text = "INFLATABLES"
	UIFont.apply(infl_title, UIFont.HEADING)
	infl_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	infl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	infl_title.custom_minimum_size = Vector2(640, 70)
	infl_card.add_child(infl_title)
	_add_spacer(infl_card, 20)
	var infl_desc := Label.new()
	infl_desc.text = "Buy in bulk now while they're cheap.\nSell later when the crowds get bigger."
	UIFont.apply(infl_desc, UIFont.BODY)
	infl_desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	infl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	infl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	infl_desc.custom_minimum_size = Vector2(640, 80)
	infl_card.add_child(infl_desc)
	_add_spacer(infl_card, 10)
	var infl_cost := Label.new()
	infl_cost.text = "Cost: " + _format_money(10000)
	UIFont.apply(infl_cost, UIFont.BODY)
	infl_cost.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
	infl_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	infl_cost.custom_minimum_size = Vector2(640, 40)
	infl_card.add_child(infl_cost)
	_add_spacer(infl_card, 30)
	var infl_yes := _create_button("BUY SOME", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	var infl_yes_w := CenterContainer.new()
	infl_yes_w.custom_minimum_size = Vector2(640, 100)
	infl_yes_w.add_child(infl_yes)
	infl_card.add_child(infl_yes_w)
	_add_spacer(infl_card, 10)
	var infl_no := _create_button("NOT YET", Color(0.2, 0.2, 0.25), Color(0.4, 0.4, 0.45))
	var infl_no_w := CenterContainer.new()
	infl_no_w.custom_minimum_size = Vector2(640, 100)
	infl_no_w.add_child(infl_no)
	infl_card.add_child(infl_no_w)

	infl_yes.pressed.connect(func():
		CareerState.money -= 10000
		CareerState.inflatables_owned = 1
		CareerState.inflatables_cost = 10000
		_advance_card()
	)
	infl_no.pressed.connect(func():
		_advance_card()
	)
	_add_card(infl_card, "L3 Inflatables")

	# Card 6: Coach introduction
	var coach_card := _create_card()
	_add_spacer(coach_card, 60)
	var coach_panel := _build_companion_panel(
		"THE COACH",
		"A bloke in a flat cap catches your eye at the bar.\n\n\"Saw your match. You've got something. But the county tournament's a different beast. You need someone in your corner.\"\n\nHe taps his nose.\n\n\"I could help. If you're interested.\"",
		Color(0.15, 0.35, 0.2), "C"
	)
	coach_card.add_child(coach_panel)
	_add_spacer(coach_card, 30)
	_add_continue_button(coach_card)
	_add_card(coach_card, "L3 Coach Intro")

	# Card 7: Coach decision
	var hire_card := _create_card()
	_add_spacer(hire_card, 120)
	var hire_title := Label.new()
	hire_title.text = "HIRE A COACH?"
	UIFont.apply(hire_title, UIFont.HEADING)
	hire_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	hire_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hire_title.custom_minimum_size = Vector2(640, 70)
	hire_card.add_child(hire_title)
	_add_spacer(hire_card, 20)
	var hire_desc := Label.new()
	hire_desc.text = "Checkout hints during matches.\nPre-match strategy.\nSomeone who actually knows\nwhat they're doing."
	UIFont.apply(hire_desc, UIFont.BODY)
	hire_desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	hire_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hire_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hire_desc.custom_minimum_size = Vector2(640, 100)
	hire_card.add_child(hire_desc)
	_add_spacer(hire_card, 10)
	var hire_cost := Label.new()
	hire_cost.text = "Cost: " + _format_money(5000)
	UIFont.apply(hire_cost, UIFont.BODY)
	hire_cost.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
	hire_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hire_cost.custom_minimum_size = Vector2(640, 40)
	hire_card.add_child(hire_cost)
	_add_spacer(hire_card, 30)
	var hire_yes := _create_button("HIRE HIM", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	var hire_yes_w := CenterContainer.new()
	hire_yes_w.custom_minimum_size = Vector2(640, 100)
	hire_yes_w.add_child(hire_yes)
	hire_card.add_child(hire_yes_w)
	_add_spacer(hire_card, 10)
	var hire_no := _create_button("I'LL MANAGE", Color(0.2, 0.2, 0.25), Color(0.4, 0.4, 0.45))
	var hire_no_w := CenterContainer.new()
	hire_no_w.custom_minimum_size = Vector2(640, 100)
	hire_no_w.add_child(hire_no)
	hire_card.add_child(hire_no_w)

	hire_yes.pressed.connect(func():
		CareerState.money -= 5000
		CareerState.coach_hired = true
		CareerState.hustle_stars += 1
		_advance_card()
	)
	hire_no.pressed.connect(func():
		# Skip hustle star card
		if _current_card + 2 < _cards.size():
			_show_card(_current_card + 2)
		else:
			_advance_card()
	)
	_add_card(hire_card, "L3 Coach Decision")

	# Card 8: Hustle star (only if hired)
	_build_star_flip_card("HUSTLE", CareerState.hustle_stars, CareerState.hustle_stars + 1, "Going professional.", null)

	# Card 9: Bridge card
	_build_bridge_card(
		"Two months later.",
		"County Darts Club",
		"Lighting rig. Raised oche. Sponsor banners. Two hundred in the crowd. Regional TV cameras.",
		7500
	)

	# Card 10: Philip stats
	_build_opponent_stats_card(
		"philip", "Philip", "The Accountant",
		{"SKILL": 4, "HEFT": 2, "HUSTLE": 3, "SWAGGER": 2},
		"301 - Best of 5"
	)

# ======================================================
# LEVEL 4 POST-WIN (Beat Philip "The Accountant")
# ======================================================

func _build_l4_win_cards() -> void:
	# Card 2: Skill star 3->4
	_build_star_flip_card("SKILL", CareerState.skill_stars, CareerState.skill_stars + 1, "County champion. The phone's ringing.", func(): CareerState.skill_stars += 1)

	# Card 3: Manager introduction (companion panel)
	var mgr_intro := _create_card()
	_add_spacer(mgr_intro, 60)
	var mgr_panel := _build_companion_panel(
		"THE MANAGER",
		"A sharp-suited woman approaches your table.\n\n\"I manage fighters. Boxers mostly. But I know talent when I see it.\"\n\nShe slides a card across.\n\n\"Call me when you're ready to take this seriously.\"",
		Color(0.4, 0.15, 0.25), "S"
	)
	mgr_intro.add_child(mgr_panel)
	_add_spacer(mgr_intro, 30)
	_add_continue_button(mgr_intro)
	_add_card(mgr_intro, "L4 Manager Intro")

	# Card 4: Manager decision
	var mgr_card := _create_card()
	_add_spacer(mgr_card, 120)
	var mgr_title := Label.new()
	mgr_title.text = "HIRE A MANAGER?"
	UIFont.apply(mgr_title, UIFont.HEADING)
	mgr_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	mgr_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mgr_title.custom_minimum_size = Vector2(640, 70)
	mgr_card.add_child(mgr_title)
	_add_spacer(mgr_card, 20)
	var mgr_desc := Label.new()
	mgr_desc.text = "Sponsorship deals. Better money.\nSomeone to handle the business side\nso you can focus on the darts."
	UIFont.apply(mgr_desc, UIFont.BODY)
	mgr_desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	mgr_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mgr_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mgr_desc.custom_minimum_size = Vector2(640, 100)
	mgr_card.add_child(mgr_desc)
	_add_spacer(mgr_card, 10)
	var mgr_cost := Label.new()
	mgr_cost.text = "Cost: " + _format_money(10000)
	UIFont.apply(mgr_cost, UIFont.BODY)
	mgr_cost.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
	mgr_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mgr_cost.custom_minimum_size = Vector2(640, 40)
	mgr_card.add_child(mgr_cost)
	_add_spacer(mgr_card, 30)
	var mgr_yes := _create_button("CALL HER", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	var mgr_yes_w := CenterContainer.new()
	mgr_yes_w.custom_minimum_size = Vector2(640, 100)
	mgr_yes_w.add_child(mgr_yes)
	mgr_card.add_child(mgr_yes_w)
	_add_spacer(mgr_card, 10)
	var mgr_no := _create_button("NOT YET", Color(0.2, 0.2, 0.25), Color(0.4, 0.4, 0.45))
	var mgr_no_w := CenterContainer.new()
	mgr_no_w.custom_minimum_size = Vector2(640, 100)
	mgr_no_w.add_child(mgr_no)
	mgr_card.add_child(mgr_no_w)

	mgr_yes.pressed.connect(func():
		CareerState.money -= 10000
		CareerState.manager_hired = true
		CareerState.hustle_stars += 1
		_advance_card()
	)
	mgr_no.pressed.connect(func():
		# Skip hustle star card
		if _current_card + 2 < _cards.size():
			_show_card(_current_card + 2)
		else:
			_advance_card()
	)
	_add_card(mgr_card, "L4 Manager Decision")

	# Card 5: Hustle star (only if hired)
	_build_star_flip_card("HUSTLE", CareerState.hustle_stars, CareerState.hustle_stars + 1, "Big time.", null)

	# Card 6: Gambling introduction
	var gamble_card := _create_card()
	_add_spacer(gamble_card, 60)
	var gamble_panel := _build_companion_panel(
		"THE CONTACT",
		"A man in a sheepskin coat finds you in the car park.\n\n\"County champion. Very impressive.\"\n\nHe lights a cigarette.\n\n\"Word is, Mad Dog's beatable. You know it. I know it. The bookmakers don't.\"\n\nHe hands you a card.\n\n\"Think about it.\"",
		Color(0.3, 0.3, 0.35), "?"
	)
	gamble_card.add_child(gamble_panel)
	_add_spacer(gamble_card, 30)
	_add_continue_button(gamble_card)
	_add_card(gamble_card, "L4 Gambling Intro")

	# Card 7: Bridge card
	_build_bridge_card(
		"Three months later.",
		"National Qualifying, Milton Keynes",
		"Conference centre. Harsh fluorescent lighting. Five hundred watching. Everyone thinks they're good enough.\n\nWin or bust from here. No second chances.",
		20000
	)

	# Card 8: Mad Dog stats
	_build_opponent_stats_card(
		"mad_dog", "Mad Dog", "Mad Dog",
		{"SKILL": 3, "HEFT": 3, "HUSTLE": 2, "SWAGGER": 4},
		"301 - Best of 7"
	)

# ======================================================
# LEVEL 5 POST-WIN (Beat Mad Dog)
# ======================================================

func _build_l5_win_cards() -> void:
	# Card 2: Skill star 4->5 (MAX)
	_build_star_flip_card("SKILL", CareerState.skill_stars, 5, "National qualifier. Five stars. Maximum.", func(): CareerState.skill_stars = 5)

	# Card 3: Sponsor intro
	var sponsor_card := _create_card()
	_add_spacer(sponsor_card, 60)
	var sponsor_panel := _build_companion_panel(
		"THE SPONSOR REP",
		"After the match, a man with a clipboard and a lanyard corners you.\n\n\"Sponsorship opportunity. Big money.\"\n\nHe looks you up and down.\n\n\"But you'll need to fill that shirt out a bit more first. We'll talk.\"",
		Color(0.1, 0.15, 0.35), "S"
	)
	sponsor_card.add_child(sponsor_panel)
	_add_spacer(sponsor_card, 30)
	_add_continue_button(sponsor_card)
	_add_card(sponsor_card, "L5 Sponsor Intro")

	# Card 4: Team decision
	var team_card := _create_card()
	_add_spacer(team_card, 60)
	var team_panel := _build_companion_panel(
		"THE COACH",
		"The coach pulls you aside.\n\n\"The Worlds is a different animal. You need a proper team. Physio. Medic. Someone to keep you alive up there.\"\n\nHe pauses.\n\n\"It's not cheap.\"",
		Color(0.15, 0.35, 0.2), "C"
	)
	team_card.add_child(team_panel)
	_add_spacer(team_card, 10)
	var team_cost := Label.new()
	team_cost.text = "Cost: " + _format_money(50000)
	UIFont.apply(team_cost, UIFont.BODY)
	team_cost.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
	team_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	team_cost.custom_minimum_size = Vector2(640, 40)
	team_card.add_child(team_cost)
	_add_spacer(team_card, 20)
	var team_yes := _create_button("BUILD THE TEAM", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	var team_yes_w := CenterContainer.new()
	team_yes_w.custom_minimum_size = Vector2(640, 100)
	team_yes_w.add_child(team_yes)
	team_card.add_child(team_yes_w)
	_add_spacer(team_card, 10)
	var team_no := _create_button("JUST US", Color(0.2, 0.2, 0.25), Color(0.4, 0.4, 0.45))
	var team_no_w := CenterContainer.new()
	team_no_w.custom_minimum_size = Vector2(640, 100)
	team_no_w.add_child(team_no)
	team_card.add_child(team_no_w)

	team_yes.pressed.connect(func():
		CareerState.money -= 50000
		CareerState.team_hired = true
		CareerState.hustle_stars += 1
		_advance_card()
	)
	team_no.pressed.connect(func():
		# Skip hustle star card
		if _current_card + 2 < _cards.size():
			_show_card(_current_card + 2)
		else:
			_advance_card()
	)
	_add_card(team_card, "L5 Team Decision")

	# Card 5: Hustle star (only if hired team)
	_build_star_flip_card("HUSTLE", CareerState.hustle_stars, CareerState.hustle_stars + 1, "Full support. No excuses.", null)

	# Card 6: Doctor hint
	var doc_card := _create_card()
	_add_spacer(doc_card, 60)
	var doc_panel := _build_companion_panel(
		"THE DOCTOR",
		"A tired-looking man in a white coat catches you in the corridor.\n\n\"I see a lot of darts players come through here. Most of them in worse shape than they think.\"\n\nHe hands you a leaflet.\n\n\"Get checked out before the semis. Trust me.\"",
		Color(0.3, 0.5, 0.35), "D"
	)
	doc_card.add_child(doc_panel)
	_add_spacer(doc_card, 30)
	_add_continue_button(doc_card)
	_add_card(doc_card, "L5 Doctor Hint")

	# Card 7: Bridge card
	_build_bridge_card(
		"The Arrow Palace, London.",
		"World Championship Semi-Final",
		"The cathedral of darts. Walk-on music. Pyrotechnics. Two thousand in fancy dress.",
		50000
	)

	# Card 8: Lars stats
	_build_opponent_stats_card(
		"lars", "Lars", "The Viking",
		{"SKILL": 5, "HEFT": 3, "HUSTLE": 3, "SWAGGER": 4},
		"501 - Best of 5"
	)

# ======================================================
# LEVEL 6 POST-WIN (Beat Lars "The Viking")
# ======================================================

func _build_l6_win_cards() -> void:
	# Card 2: All stars snapshot (no SKILL increase, already at 5)
	var snap_card := _create_card()
	_add_spacer(snap_card, 40)

	var portrait_path: String = DartData.get_profile_image(GameState.character)
	var tex := load(portrait_path)
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(640, 220)
		snap_card.add_child(img)

	_add_spacer(snap_card, 10)

	var char_name: String = DartData.get_character_name(GameState.character)
	var char_nick: String = DartData.get_character_nickname(GameState.character)
	var name_label := Label.new()
	name_label.text = char_name + '\n"' + char_nick + '"'
	UIFont.apply(name_label, UIFont.HEADING)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(640, 90)
	snap_card.add_child(name_label)

	_add_spacer(snap_card, 15)

	snap_card.add_child(_career_stars_row("SKILL", CareerState.skill_stars, 5))
	snap_card.add_child(_career_stars_row("HEFT", CareerState.heft_tier, 5))
	snap_card.add_child(_career_stars_row("HUSTLE", CareerState.hustle_stars, 5))
	snap_card.add_child(_career_stars_row("SWAGGER", CareerState.swagger_stars, 5))

	_add_spacer(snap_card, 25)

	var quip := Label.new()
	quip.text = "World Championship finalist.\nOne match from immortality."
	UIFont.apply(quip, UIFont.BODY)
	quip.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	quip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quip.custom_minimum_size = Vector2(640, 60)
	snap_card.add_child(quip)

	_add_spacer(snap_card, 25)

	_add_continue_button(snap_card)
	_add_card(snap_card, "L6 Stars Snapshot")

	# Card 3: Coach/team dialogue
	var coach_card := _create_card()
	_add_spacer(coach_card, 60)
	var speaker_name: String = "THE TEAM" if CareerState.team_hired else "THE COACH"
	var coach_panel := _build_companion_panel(
		speaker_name,
		"The coach speaks first.\n\n\"One more. That's all that stands between you and the title.\"\n\nHe pauses.\n\n\"But the doc says you need a check-up first. No arguments.\"",
		Color(0.15, 0.35, 0.2), "C"
	)
	coach_card.add_child(coach_panel)
	_add_spacer(coach_card, 30)
	_add_continue_button(coach_card)
	_add_card(coach_card, "L6 Coach")

	# Card 4: Doctor visit (narrative based on hidden stats)
	var doc_card := _create_card()
	_add_spacer(doc_card, 60)
	var doc_text: String
	if CareerState.liver_damage < 30 and CareerState.heart_risk < 30:
		doc_text = "You're in decent shape. Don't get cocky, but you should be fine for one more match."
	elif CareerState.liver_damage < 60 and CareerState.heart_risk < 60:
		doc_text = "Your liver's working hard. And your heart's not loving the extra weight.\n\nOne more match - but go easy on the pints."
	else:
		doc_text = "I'm going to be straight with you. Your body's under serious strain.\n\nOne more big night could be the last."
	var doc_panel := _build_companion_panel(
		"THE DOCTOR",
		doc_text,
		Color(0.3, 0.5, 0.35), "D"
	)
	doc_card.add_child(doc_panel)
	_add_spacer(doc_card, 30)
	_add_continue_button(doc_card)
	_add_card(doc_card, "L6 Doctor")

	# Card 5: Vinnie Gold introduction
	var vinnie_card := _create_card()
	_add_spacer(vinnie_card, 60)
	var vinnie_panel := _build_companion_panel(
		"VINNIE GOLD",
		"The cameras find you in the corridor.\n\nVinnie Gold walks past. Gold shoes. Gold watch. Gold teeth.\n\nHe doesn't look at you.\n\n\"Tell him I said good luck.\"\n\nHe doesn't mean it.",
		Color(0.6, 0.5, 0.1), "V"
	)
	vinnie_card.add_child(vinnie_panel)
	_add_spacer(vinnie_card, 30)
	_add_continue_button(vinnie_card)
	_add_card(vinnie_card, "L6 Vinnie Intro")

	# Card 6: Bridge card
	_build_bridge_card(
		"World Championship Final.",
		"The Arrow Palace, London",
		"Gold confetti loaded. Fireworks ready.\nTwo thousand on their feet.\n\nThis is it.",
		100000
	)

	# Card 7: Vinnie Gold stats
	_build_opponent_stats_card(
		"vinnie", "Vinnie Gold", "The Gold",
		{"SKILL": 5, "HEFT": 4, "HUSTLE": 5, "SWAGGER": 5},
		"501 - Best of 7"
	)

# ======================================================
# WORLD CHAMPION (Level 7 win — expanded)
# ======================================================

func _build_world_champion_cards() -> void:
	# Card 1: Prize money already added by _build_prize_card

	# Card 2: Final stars snapshot
	var snap_card := _create_card()
	_add_spacer(snap_card, 40)

	var portrait_path: String = DartData.get_profile_image(GameState.character)
	var tex := load(portrait_path)
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(640, 220)
		snap_card.add_child(img)

	_add_spacer(snap_card, 10)

	var char_name: String = DartData.get_character_name(GameState.character)
	var char_nick: String = DartData.get_character_nickname(GameState.character)
	var name_label := Label.new()
	name_label.text = char_name + '\n"' + char_nick + '"'
	UIFont.apply(name_label, UIFont.HEADING)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(640, 90)
	snap_card.add_child(name_label)

	_add_spacer(snap_card, 15)

	snap_card.add_child(_career_stars_row("SKILL", CareerState.skill_stars, 5))
	snap_card.add_child(_career_stars_row("HEFT", CareerState.heft_tier, 5))
	snap_card.add_child(_career_stars_row("HUSTLE", CareerState.hustle_stars, 5))
	snap_card.add_child(_career_stars_row("SWAGGER", CareerState.swagger_stars, 5))

	_add_spacer(snap_card, 25)

	var quip := Label.new()
	quip.text = "World Champion."
	UIFont.apply(quip, UIFont.BODY)
	quip.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	quip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quip.custom_minimum_size = Vector2(640, 50)
	snap_card.add_child(quip)

	_add_spacer(snap_card, 25)
	_add_continue_button(snap_card)
	_add_card(snap_card, "Champion Stars")

	# Card 3: The ending
	var end_card := _create_card()
	_add_spacer(end_card, 150)

	var champ_label := Label.new()
	champ_label.text = "WORLD CHAMPION!"
	UIFont.apply(champ_label, UIFont.SCREEN_TITLE)
	champ_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	champ_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	champ_label.custom_minimum_size = Vector2(640, 90)
	end_card.add_child(champ_label)

	_add_spacer(end_card, 40)

	var story_label := Label.new()
	story_label.text = "You buy your parents a house with the winnings.\n\nNot bad for a kid from the local."
	UIFont.apply(story_label, UIFont.BODY)
	story_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_label.custom_minimum_size = Vector2(640, 200)
	end_card.add_child(story_label)

	_add_spacer(end_card, 60)

	var new_btn := _create_button("NEW CAREER", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	new_btn.pressed.connect(_on_new_career)
	var new_wrapper := CenterContainer.new()
	new_wrapper.custom_minimum_size = Vector2(640, 100)
	new_wrapper.add_child(new_btn)
	end_card.add_child(new_wrapper)

	_add_card(end_card, "World Champion")

# ======================================================
# LOSS FLOW
# ======================================================

# Level-specific loss flavour text
const LOSS_FLAVOUR := {
	# Level 2 (Derek)
	2: {
		1: "Not your night. There's always next Friday.",
		2: "Derek's starting to look comfortable.",
		"career_over": "Three Fridays. Three losses.\nThe postman delivered after all.",
		"retry": "TRY AGAIN FRIDAY",
	},
	# Level 3 (Steve)
	3: {
		1: "Steve grins. \"Better luck next time, pal.\"",
		2: "The lads are going quiet.",
		"career_over": "Three-time champion.\nMake that four.\nSteve raises a pint. You don't.",
		"retry": "ENTER AGAIN",
	},
	# Level 4 (Philip)
	4: {
		1: "Philip adjusts his glasses.\n\"Interesting match.\"\nHe doesn't mean it.",
		2: "The coach shakes her head.",
		"career_over": "Three county finals. Three losses.\nPhilip doesn't celebrate.\nHe just packs his darts away.",
		"retry": "TRY AGAIN",
	},
	# Level 5 (Mad Dog) -- win or bust
	5: {
		"career_over": "Mad Dog doesn't shake hands.\nShe just walks away.\n\nYou catch a train home in silence.",
	},
	# Level 6 (Lars) -- win or bust
	6: {
		"career_over": "Lars raises his hammer.\nThe crowd goes wild.\n\nYou watch from the wings.\nClose. So close.",
	},
	# Level 7 (Vinnie Gold) -- win or bust
	7: {
		"career_over": "Gold confetti. Vinnie's confetti.\nNot yours.\n\nYou buy a kebab on the way to the station.",
	},
}

func _build_loss_card() -> void:
	var opp_id: String = GameState.opponent_id
	var opp_name: String = OpponentData.get_display_name(opp_id)
	var opp_nick: String = OpponentData.get_nickname(opp_id)
	var opp_level: int = OpponentData.get_opponent(opp_id)["level"]
	var career_over: bool = GameState.match_career_over
	var max_losses: int = OpponentData.get_max_losses(opp_id)
	var losses: int = CareerState.losses_at_current_level

	var card := _create_card()

	_add_spacer(card, 150)

	var result_label := Label.new()
	if career_over:
		result_label.text = "CAREER OVER"
		UIFont.apply(result_label, UIFont.SCREEN_TITLE)
		result_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	else:
		result_label.text = "YOU LOSE"
		UIFont.apply(result_label, UIFont.SCREEN_TITLE)
		result_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.custom_minimum_size = Vector2(640, 90)
	card.add_child(result_label)

	_add_spacer(card, 10)

	var vs_label := Label.new()
	vs_label.text = "vs " + opp_name + ' "' + opp_nick + '"'
	UIFont.apply(vs_label, UIFont.SUBHEADING)
	vs_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vs_label.custom_minimum_size = Vector2(640, 50)
	card.add_child(vs_label)

	_add_spacer(card, 40)

	if career_over:
		var over_text: String
		# Try level-specific career over text
		if opp_level in LOSS_FLAVOUR and "career_over" in LOSS_FLAVOUR[opp_level]:
			over_text = LOSS_FLAVOUR[opp_level]["career_over"]
		elif opp_level == 1:
			over_text = "Three weeks in a row.\nBig Kev hasn't even broken a sweat."
		elif max_losses == 1:
			over_text = "Win or bust.\nYou lost."
		else:
			over_text = "Three strikes.\nYou're out."

		var over_label := Label.new()
		over_label.text = over_text
		UIFont.apply(over_label, UIFont.HEADING)
		over_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.4))
		over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		over_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		over_label.custom_minimum_size = Vector2(640, 120)
		card.add_child(over_label)

		_add_spacer(card, 20)

		var balance_label := Label.new()
		balance_label.text = "Final balance: " + _format_money(CareerState.money)
		UIFont.apply(balance_label, UIFont.BODY)
		balance_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		balance_label.custom_minimum_size = Vector2(640, 50)
		card.add_child(balance_label)

		_add_spacer(card, 50)

		var new_btn := _create_button("NEW CAREER", Color(0.5, 0.15, 0.15), Color(0.8, 0.3, 0.3))
		new_btn.pressed.connect(_on_new_career)
		var new_wrapper := CenterContainer.new()
		new_wrapper.custom_minimum_size = Vector2(640, 100)
		new_wrapper.add_child(new_btn)
		card.add_child(new_wrapper)
	else:
		# Strike count
		var strike_label := Label.new()
		strike_label.text = "Strike " + str(losses) + " of " + str(max_losses)
		UIFont.apply(strike_label, UIFont.HEADING)
		strike_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
		strike_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		strike_label.custom_minimum_size = Vector2(640, 60)
		card.add_child(strike_label)

		# Visual strike indicators
		var strikes_row := HBoxContainer.new()
		strikes_row.alignment = BoxContainer.ALIGNMENT_CENTER
		strikes_row.add_theme_constant_override("separation", 20)
		strikes_row.custom_minimum_size = Vector2(640, 70)
		for i in range(max_losses):
			var mark := Label.new()
			if i < losses:
				mark.text = "X"
				UIFont.apply(mark, UIFont.HEADING)
				mark.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
			else:
				mark.text = "O"
				UIFont.apply(mark, UIFont.HEADING)
				mark.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
			strikes_row.add_child(mark)
		card.add_child(strikes_row)

		_add_spacer(card, 20)

		# Level-specific flavour text
		var flavour_text: String = ""
		if opp_level == 1:
			if losses == 1:
				flavour_text = "Unlucky. Same time next week?"
			else:
				flavour_text = "Nobody entered again.\nJust you and Big Kev."
		elif opp_level in LOSS_FLAVOUR and losses in LOSS_FLAVOUR[opp_level]:
			flavour_text = LOSS_FLAVOUR[opp_level][losses]

		if flavour_text != "":
			var flavour := Label.new()
			flavour.text = flavour_text
			UIFont.apply(flavour, UIFont.BODY)
			flavour.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
			flavour.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			flavour.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			flavour.custom_minimum_size = Vector2(640, 80)
			card.add_child(flavour)
			_add_spacer(card, 10)

		var balance_label := Label.new()
		balance_label.text = "Balance: " + _format_money(CareerState.money)
		UIFont.apply(balance_label, UIFont.BODY)
		balance_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		balance_label.custom_minimum_size = Vector2(640, 50)
		card.add_child(balance_label)

		_add_spacer(card, 40)

		# Level-specific retry button text
		var retry_text: String = "TRY AGAIN"
		if opp_level == 1:
			retry_text = "COME BACK NEXT WEEK"
		elif opp_level in LOSS_FLAVOUR and "retry" in LOSS_FLAVOUR[opp_level]:
			retry_text = LOSS_FLAVOUR[opp_level]["retry"]
		var retry_btn := _create_button(retry_text, Color(0.15, 0.15, 0.4), Color(0.3, 0.3, 0.7))
		retry_btn.pressed.connect(_on_try_again)
		var retry_wrapper := CenterContainer.new()
		retry_wrapper.custom_minimum_size = Vector2(640, 100)
		retry_wrapper.add_child(retry_btn)
		card.add_child(retry_wrapper)

	_add_card(card, "Loss")

# ======================================================
# REUSABLE HELPERS — Companion Panel
# ======================================================

## Build a companion-style dialogue panel.
## If image_path is provided (non-empty), uses a real image as portrait.
## Otherwise uses a coloured rectangle with an initial letter.
func _build_companion_panel(speaker_name: String, dialogue_text: String,
		portrait_color: Color, portrait_initial: String,
		image_path: String = "") -> PanelContainer:
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.07, 0.12, 0.94)
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_color = Color(0.85, 0.6, 0.15, 0.6)
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	# Portrait — either real image or placeholder
	if image_path != "":
		var tex := load(image_path)
		if tex:
			var portrait := TextureRect.new()
			portrait.texture = tex
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.custom_minimum_size = Vector2(560, 140)
			vbox.add_child(portrait)
	else:
		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(560, 140)
		var bg := ColorRect.new()
		bg.position = Vector2.ZERO
		bg.size = Vector2(560, 140)
		bg.color = portrait_color
		wrapper.add_child(bg)
		var initial := Label.new()
		initial.text = portrait_initial
		initial.position = Vector2.ZERO
		initial.size = Vector2(560, 140)
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UIFont.apply(initial, UIFont.SCREEN_TITLE)
		initial.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		wrapper.add_child(initial)
		vbox.add_child(wrapper)

	# Speaker name
	var name_label := Label.new()
	name_label.text = speaker_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
	UIFont.apply(name_label, UIFont.BODY)
	vbox.add_child(name_label)

	# Dialogue text
	var dialogue := Label.new()
	dialogue.text = dialogue_text
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue.custom_minimum_size = Vector2(560, 0)
	dialogue.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	UIFont.apply(dialogue, UIFont.BODY)
	vbox.add_child(dialogue)

	panel.add_child(vbox)
	return panel

# ======================================================
# REUSABLE HELPERS — Star Flip Card
# ======================================================

## Build a player stats card with one star row that flips from old_val to new_val.
## set_callback is called when the animation fires (to update CareerState).
## If set_callback is null, the caller has already updated the value.
func _build_star_flip_card(star_name: String, old_val: int, new_val: int,
		quip_text: String, set_callback) -> void:
	var card := _create_card()
	_add_spacer(card, 40)

	var portrait_path: String = DartData.get_profile_image(GameState.character)
	var tex := load(portrait_path)
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(640, 220)
		card.add_child(img)

	_add_spacer(card, 10)

	var char_name: String = DartData.get_character_name(GameState.character)
	var char_nick: String = DartData.get_character_nickname(GameState.character)
	var name_label := Label.new()
	name_label.text = char_name + '\n"' + char_nick + '"'
	UIFont.apply(name_label, UIFont.HEADING)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(640, 90)
	card.add_child(name_label)

	_add_spacer(card, 15)

	# Build all 4 star rows — the target row gets a flip animation
	var star_categories := ["SKILL", "HEFT", "HUSTLE", "SWAGGER"]
	var star_values := {
		"SKILL": CareerState.skill_stars,
		"HEFT": CareerState.heft_tier,
		"HUSTLE": CareerState.hustle_stars,
		"SWAGGER": CareerState.swagger_stars,
	}

	var flip_wrapper: Control = null
	var before_label: Label = null
	var after_label: Label = null

	for cat in star_categories:
		if cat == star_name:
			# Build flip row
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 10)
			row.custom_minimum_size = Vector2(640, 50)
			var lbl := Label.new()
			lbl.text = cat
			lbl.custom_minimum_size = Vector2(180, 50)
			UIFont.apply(lbl, UIFont.BODY)
			lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(lbl)

			flip_wrapper = Control.new()
			flip_wrapper.custom_minimum_size = Vector2(200, 50)
			flip_wrapper.pivot_offset = Vector2(100, 25)

			before_label = Label.new()
			before_label.text = _stars_string(old_val, 5)
			before_label.position = Vector2.ZERO
			before_label.size = Vector2(200, 50)
			UIFont.apply(before_label, UIFont.BODY)
			if old_val > 0:
				before_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			else:
				before_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
			before_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			flip_wrapper.add_child(before_label)

			after_label = Label.new()
			after_label.text = _stars_string(new_val, 5)
			after_label.position = Vector2.ZERO
			after_label.size = Vector2(200, 50)
			UIFont.apply(after_label, UIFont.BODY)
			after_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			after_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			after_label.visible = false
			flip_wrapper.add_child(after_label)

			row.add_child(flip_wrapper)
			card.add_child(row)
		else:
			card.add_child(_career_stars_row(cat, star_values[cat], 5))

	_add_spacer(card, 25)

	var quip := Label.new()
	quip.text = quip_text
	UIFont.apply(quip, UIFont.BODY)
	quip.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	quip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quip.custom_minimum_size = Vector2(640, 50)
	quip.modulate.a = 0.0
	card.add_child(quip)

	_add_spacer(card, 25)

	var cont_wrapper := CenterContainer.new()
	cont_wrapper.custom_minimum_size = Vector2(640, 100)
	var cont_btn := _create_button("CONTINUE", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5))
	cont_btn.pressed.connect(_advance_card)
	cont_wrapper.add_child(cont_btn)
	cont_wrapper.modulate.a = 0.0
	card.add_child(cont_wrapper)

	_add_card(card, star_name + " Star")

	# Deferred animation
	var card_idx := _cards.size() - 1
	var _fw := flip_wrapper
	var _bl := before_label
	var _al := after_label
	var _cb = set_callback
	_card_animations[card_idx] = func():
		if _cb != null and _cb is Callable:
			_cb.call()
		var tween := create_tween()
		tween.tween_property(_fw, "scale:y", 0.0, 0.15).set_delay(0.8)
		tween.tween_callback(func():
			_bl.visible = false
			_al.visible = true
		)
		tween.tween_property(_fw, "scale:y", 1.0, 0.15)
		tween.tween_property(quip, "modulate:a", 1.0, 0.3).set_delay(0.3)
		tween.tween_property(cont_wrapper, "modulate:a", 1.0, 0.3).set_delay(0.2)

# ======================================================
# REUSABLE HELPERS — Bridge Card
# ======================================================

func _build_bridge_card(time_text: String, venue_name: String,
		vibe_text: String, entry_fee: int) -> void:
	var card := _create_card()
	_add_spacer(card, 120)

	var time_label := Label.new()
	time_label.text = time_text
	UIFont.apply(time_label, UIFont.HEADING)
	time_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	time_label.custom_minimum_size = Vector2(640, 60)
	card.add_child(time_label)

	_add_spacer(card, 10)

	var venue_label := Label.new()
	venue_label.text = venue_name
	UIFont.apply(venue_label, UIFont.SUBHEADING)
	venue_label.add_theme_color_override("font_color", Color.WHITE)
	venue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	venue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	venue_label.custom_minimum_size = Vector2(640, 50)
	card.add_child(venue_label)

	_add_spacer(card, 20)

	var vibe_label := Label.new()
	vibe_label.text = vibe_text
	UIFont.apply(vibe_label, UIFont.BODY)
	vibe_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vibe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vibe_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vibe_label.custom_minimum_size = Vector2(640, 0)
	card.add_child(vibe_label)

	_add_spacer(card, 30)

	var balance_label := Label.new()
	balance_label.text = "Balance: " + _format_money(CareerState.money)
	UIFont.apply(balance_label, UIFont.BODY)
	balance_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_label.custom_minimum_size = Vector2(640, 40)
	card.add_child(balance_label)

	if entry_fee > 0:
		_add_spacer(card, 5)
		var entry_label := Label.new()
		entry_label.text = "Entry: " + _format_money(entry_fee)
		UIFont.apply(entry_label, UIFont.BODY)
		entry_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
		entry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		entry_label.custom_minimum_size = Vector2(640, 40)
		card.add_child(entry_label)

	_add_spacer(card, 30)
	_add_continue_button(card)
	_add_card(card, "Bridge")

# ======================================================
# REUSABLE HELPERS — Opponent Stats Card
# ======================================================

func _build_opponent_stats_card(opp_id: String, display_name: String,
		nickname: String, stars: Dictionary, game_mode_text: String) -> void:
	var card := _create_card()

	_add_spacer(card, 25)

	# "YOUR OPPONENT" header (yellow -- standard for all opponent reveal cards)
	var header := Label.new()
	header.text = "YOUR OPPONENT"
	UIFont.apply(header, UIFont.SUBHEADING)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.custom_minimum_size = Vector2(640, 50)
	card.add_child(header)

	_add_spacer(card, 10)

	# Portrait (real image if available, otherwise placeholder)
	var image_path: String = OpponentData.get_image(opp_id)
	if image_path != "":
		var tex := load(image_path)
		if tex:
			var img := TextureRect.new()
			img.texture = tex
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.custom_minimum_size = Vector2(640, 180)
			card.add_child(img)
	else:
		# Placeholder
		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(640, 140)
		var bg := ColorRect.new()
		bg.position = Vector2(140, 0)
		bg.size = Vector2(360, 140)
		bg.color = Color(0.2, 0.2, 0.25)
		wrapper.add_child(bg)
		var initial := Label.new()
		initial.text = display_name.left(1)
		initial.position = Vector2(140, 0)
		initial.size = Vector2(360, 140)
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UIFont.apply(initial, UIFont.SCREEN_TITLE)
		initial.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		wrapper.add_child(initial)
		card.add_child(wrapper)

	_add_spacer(card, 10)

	# Name + nickname
	var name_label := Label.new()
	name_label.text = display_name + '\n"' + nickname + '"'
	UIFont.apply(name_label, UIFont.HEADING)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(640, 90)
	card.add_child(name_label)

	_add_spacer(card, 10)

	# Star ratings
	for cat in ["SKILL", "HEFT", "HUSTLE", "SWAGGER"]:
		card.add_child(_career_stars_row(cat, stars.get(cat, 0), 5))

	_add_spacer(card, 15)

	# Game details
	var venue: String = OpponentData.get_venue(opp_id, GameState.character)
	var buy_in: int = OpponentData.get_buy_in(opp_id)
	var details_text := game_mode_text + "\n" + venue
	if buy_in > 0:
		details_text += "\nEntry: " + _format_money(buy_in)
	var details := Label.new()
	details.text = details_text
	UIFont.apply(details, UIFont.BODY)
	details.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size = Vector2(640, 0)
	card.add_child(details)

	_add_spacer(card, 20)

	var next_btn := _create_button("NEXT MATCH", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	next_btn.pressed.connect(_on_next_match)
	var next_wrapper := CenterContainer.new()
	next_wrapper.custom_minimum_size = Vector2(640, 100)
	next_wrapper.add_child(next_btn)
	card.add_child(next_wrapper)

	_add_card(card, display_name + " Stats")

# ======================================================
# GENERIC FALLBACK (for any unhandled levels)
# ======================================================

func _build_generic_story_card(opp_level: int) -> void:
	var card := _create_card()
	_add_spacer(card, 200)
	var story_label := Label.new()
	story_label.text = "The crowd disperses. Time to move on."
	UIFont.apply(story_label, UIFont.BODY)
	story_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_label.custom_minimum_size = Vector2(640, 400)
	card.add_child(story_label)
	_add_spacer(card, 60)
	_add_continue_button(card)
	_add_card(card, "Story")

func _build_generic_next_opponent_card() -> void:
	if CareerState.career_level - 1 >= OpponentData.OPPONENT_ORDER.size():
		return
	var next_opp_id: String = OpponentData.OPPONENT_ORDER[CareerState.career_level - 1]
	var next_name: String = OpponentData.get_display_name(next_opp_id)
	var next_nick: String = OpponentData.get_nickname(next_opp_id)
	var next_opp: Dictionary = OpponentData.get_opponent(next_opp_id)
	var next_mode: String = "Round the Clock" if next_opp["game_mode"] == "rtc" else str(next_opp["starting_score"])
	_build_opponent_stats_card(next_opp_id, next_name, next_nick,
		{"SKILL": 3, "HEFT": 2, "HUSTLE": 2, "SWAGGER": 1}, next_mode)

# ======================================================
# Card system
# ======================================================

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
	# Run deferred animation if one exists for this card
	if _card_animations.has(index):
		_card_animations[index].call()
		_card_animations.erase(index)

func _advance_card() -> void:
	if _current_card < _cards.size() - 1:
		_show_card(_current_card + 1)

func _add_continue_button(card: Control) -> void:
	var btn := _create_button("CONTINUE", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5))
	btn.pressed.connect(_advance_card)
	var wrapper := CenterContainer.new()
	wrapper.custom_minimum_size = Vector2(640, 100)
	wrapper.add_child(btn)
	card.add_child(wrapper)

# ======================================================
# Helpers
# ======================================================

func _add_spacer(parent: Control, height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(640, height)
	parent.add_child(spacer)

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

func _format_money(pence: int) -> String:
	var pounds_val := int(pence / 100)
	var pence_val := pence % 100
	if pence < 10000:
		var p_str: String = str(pence_val) if pence_val >= 10 else "0" + str(pence_val)
		return "£" + str(pounds_val) + "." + p_str
	elif pence < 100000:
		return "£" + str(pounds_val)
	else:
		var result := ""
		var s := str(pounds_val)
		var len_s := s.length()
		for i in range(len_s):
			if i > 0 and (len_s - i) % 3 == 0:
				result += ","
			result += s[i]
		return "£" + result

func _stars_string(filled: int, total: int) -> String:
	var star_filled := "★"
	var star_empty := "☆"
	return star_filled.repeat(filled) + star_empty.repeat(total - filled)

func _heft_stars(tier: int) -> String:
	return _stars_string(mini(tier, 5), 5)

func _career_stars_row(cat_name: String, filled: int, total: int) -> HBoxContainer:
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

	var stars := Label.new()
	stars.text = _stars_string(filled, total)
	stars.custom_minimum_size = Vector2(200, 50)
	UIFont.apply(stars, UIFont.BODY)
	if filled > 0:
		stars.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		stars.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(stars)

	return row

# ======================================================
# Navigation
# ======================================================

func _on_next_match() -> void:
	var next_opp_id: String = OpponentData.OPPONENT_ORDER[CareerState.career_level - 1]
	var next_opp: Dictionary = OpponentData.get_opponent(next_opp_id)
	GameState.opponent_id = next_opp_id
	GameState.is_vs_ai = true
	if next_opp["game_mode"] == "rtc":
		GameState.game_mode = GameState.GameMode.ROUND_THE_CLOCK
		GameState.starting_score = 0
	else:
		GameState.game_mode = GameState.GameMode.COUNTDOWN
		GameState.starting_score = next_opp["starting_score"]
	# Skip dart choice if player only owns one set
	GameState.dart_tier = CareerState.dart_tier_owned
	get_tree().change_scene_to_file("res://scenes/match.tscn")

func _on_try_again() -> void:
	GameState.dart_tier = CareerState.dart_tier_owned
	get_tree().change_scene_to_file("res://scenes/match.tscn")

func _on_new_career() -> void:
	CareerState.reset()
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")
