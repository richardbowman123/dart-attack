extends Control

## Post-match results screen — multi-card flow.
## Level 1 Win: Prize → Skill star → Chinese buffet story → Buffet decision → Barman L2 → Mate intro
## Level 2-6 Win: Prize → Story → [Meal voucher if applicable] → Next opponent
## Level 7 Win: Prize → World Champion ending
## Loss: Single card (strikes or career over, with L1-specific flavour text)

var _cards: Array[Control] = []
var _current_card: int = 0
var _card_animations: Dictionary = {}

# Post-win narrative text for each level. Shown after beating that opponent.
const POST_WIN_STORY := {
	1: "Big Kev shakes your hand.\n\n\"Not bad. Not bad at all.\"\n\nHe slides a voucher across the bar.\n\n\"All-you-can-eat Chinese buffet. On me.\n\nGet yourself fed.\nYou'll need it.\"",
	2: "Your mate nudges you on the way out.\n\n\"You're starting to look the part. We should get you some proper bling and a decent tattoo.\"\n\nHe grins. \"And maybe some better darts.\"",
	3: "A bloke in a flat cap catches your eye at the bar.\n\n\"Saw your match. You've got something. But you need to learn when to celebrate and when to keep your head down.\"\n\nHe taps his nose. \"And watch your back in the car park.\"",
	4: "A sharp-suited woman approaches your table.\n\n\"I manage fighters. Boxers mostly. But I know talent when I see it.\"\n\nShe slides a card across. \"Call me when you're ready to take this seriously.\"",
	5: "After the match, a man with a clipboard and a lanyard corners you.\n\n\"Sponsorship opportunity. Big money. But you'll need to fill that shirt out a bit more first.\"\n\nHe looks you up and down. \"We'll talk.\"",
	6: "Your team gathers around. The coach speaks first.\n\n\"One more. That's all that stands between you and the title.\"\n\nHe pauses. \"But the doc says you need a check-up first. No arguments.\"",
}

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

# ══════════════════════════════════════════
# WIN FLOW
# ══════════════════════════════════════════

func _build_win_cards() -> void:
	var prize: int = GameState.match_prize
	var opp_id: String = GameState.opponent_id
	var opp_name: String = OpponentData.get_display_name(opp_id)
	var opp_nick: String = OpponentData.get_nickname(opp_id)
	var opp_level: int = OpponentData.get_opponent(opp_id)["level"]

	# ── Card 1: Prize Money (all levels) ──
	_build_prize_card(opp_name, opp_nick, prize)

	# ── Branch by level ──
	if CareerState.career_level > 7:
		_build_world_champion_card()
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
	else:
		_build_story_card(opp_level)
		_build_next_opponent_card()

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

# ── Skill Star Card (Level 1 win only) ──

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
	skill_stars_before.text = "☆☆☆☆☆"
	skill_stars_before.position = Vector2.ZERO
	skill_stars_before.size = Vector2(200, 50)
	UIFont.apply(skill_stars_before, UIFont.BODY)
	skill_stars_before.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	skill_stars_before.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	skill_stars_wrapper.add_child(skill_stars_before)
	var skill_stars_after := Label.new()
	skill_stars_after.text = "★☆☆☆☆"
	skill_stars_after.position = Vector2.ZERO
	skill_stars_after.size = Vector2(200, 50)
	UIFont.apply(skill_stars_after, UIFont.BODY)
	skill_stars_after.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	skill_stars_after.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	skill_stars_after.visible = false
	skill_stars_wrapper.add_child(skill_stars_after)
	skill_row.add_child(skill_stars_wrapper)
	card.add_child(skill_row)

	# Other star rows (static)
	var heft_row := _career_stars_row("HEFT", CareerState.heft_tier, 5)
	card.add_child(heft_row)
	var hustle_row := _career_stars_row("HUSTLE", CareerState.hustle_stars, 5)
	card.add_child(hustle_row)
	var swagger_row := _career_stars_row("SWAGGER", CareerState.swagger_stars, 5)
	card.add_child(swagger_row)

	_add_spacer(card, 25)

	# Quip (fades in after animation — running commentary, no speech marks)
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

	# Set the star
	CareerState.skill_stars = 1

	_add_card(card, "Skill Star")

	# Deferred animation — stars flip when card becomes visible
	var card_idx := _cards.size() - 1
	_card_animations[card_idx] = func():
		var tween := create_tween()
		# Flip: scale Y down, swap stars, scale Y back up
		tween.tween_property(skill_stars_wrapper, "scale:y", 0.0, 0.15).set_delay(0.8)
		tween.tween_callback(func():
			skill_stars_before.visible = false
			skill_stars_after.visible = true
		)
		tween.tween_property(skill_stars_wrapper, "scale:y", 1.0, 0.15)
		tween.tween_property(quip, "modulate:a", 1.0, 0.3).set_delay(0.3)
		tween.tween_property(cont_wrapper, "modulate:a", 1.0, 0.3).set_delay(0.2)

# ── Story Card (all non-champion levels) ──

func _build_story_card(opp_level: int) -> void:
	var card := _create_card()

	_add_spacer(card, 200)

	var story_text: String = POST_WIN_STORY.get(opp_level, "The crowd disperses. Time to move on.")
	var story_label := Label.new()
	story_label.text = story_text
	UIFont.apply(story_label, UIFont.BODY)
	story_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_label.custom_minimum_size = Vector2(640, 400)
	card.add_child(story_label)

	_add_spacer(card, 60)

	_add_continue_button(card)
	_add_card(card, "Story")

# ── Big Kev Dialogue Card (Level 1 win — companion panel style) ──

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

	# Companion-style panel
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

	# Big Kev portrait
	var tex := load("res://Big Kev.jpg")
	if tex:
		var portrait := TextureRect.new()
		portrait.texture = tex
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(560, 180)
		vbox.add_child(portrait)

	# Speaker name
	var name_label := Label.new()
	name_label.text = "BIG KEV"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
	UIFont.apply(name_label, UIFont.BODY)
	vbox.add_child(name_label)

	# Dialogue text
	var dialogue := Label.new()
	dialogue.text = "\"Not bad. Not bad at all.\"\n\nHe slides a voucher across the bar.\n\n\"All-you-can-eat Chinese buffet. On me.\n\nGet yourself fed.\nYou'll need it.\""
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue.custom_minimum_size = Vector2(560, 0)
	dialogue.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	UIFont.apply(dialogue, UIFont.BODY)
	vbox.add_child(dialogue)

	panel.add_child(vbox)
	card.add_child(panel)

	_add_spacer(card, 25)

	_add_continue_button(card)
	_add_card(card, "Big Kev Dialogue")

# ── Chinese Buffet Card (Level 1 win — replaces old meal voucher) ──

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

# ── Heft Star Snapshot (Level 1 win, after eating) ──

func _build_heft_star_card() -> void:
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

	# Star rows — HEFT animates from 0 to 1
	var skill_row := _career_stars_row("SKILL", CareerState.skill_stars, 5)
	card.add_child(skill_row)

	# HEFT row — category label stays visible, only stars flip
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
	# Stars overlay — only this part flips
	var heft_stars_wrapper := Control.new()
	heft_stars_wrapper.custom_minimum_size = Vector2(200, 50)
	heft_stars_wrapper.pivot_offset = Vector2(100, 25)
	var heft_stars_before := Label.new()
	heft_stars_before.text = "\u2606\u2606\u2606\u2606\u2606"
	heft_stars_before.position = Vector2.ZERO
	heft_stars_before.size = Vector2(200, 50)
	UIFont.apply(heft_stars_before, UIFont.BODY)
	heft_stars_before.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	heft_stars_before.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heft_stars_wrapper.add_child(heft_stars_before)
	var heft_stars_after := Label.new()
	heft_stars_after.text = "\u2605\u2606\u2606\u2606\u2606"
	heft_stars_after.position = Vector2.ZERO
	heft_stars_after.size = Vector2(200, 50)
	UIFont.apply(heft_stars_after, UIFont.BODY)
	heft_stars_after.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	heft_stars_after.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heft_stars_after.visible = false
	heft_stars_wrapper.add_child(heft_stars_after)
	heft_row.add_child(heft_stars_wrapper)
	card.add_child(heft_row)

	var hustle_row := _career_stars_row("HUSTLE", CareerState.hustle_stars, 5)
	card.add_child(hustle_row)
	var swagger_row := _career_stars_row("SWAGGER", CareerState.swagger_stars, 5)
	card.add_child(swagger_row)

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

	# Deferred animation — stars flip when card becomes visible
	var card_idx := _cards.size() - 1
	_card_animations[card_idx] = func():
		var tween := create_tween()
		# Flip: scale Y down, swap stars, scale Y back up
		tween.tween_property(heft_stars_wrapper, "scale:y", 0.0, 0.15).set_delay(0.8)
		tween.tween_callback(func():
			heft_stars_before.visible = false
			heft_stars_after.visible = true
		)
		tween.tween_property(heft_stars_wrapper, "scale:y", 1.0, 0.15)
		tween.tween_property(quip, "modulate:a", 1.0, 0.3).set_delay(0.3)
		tween.tween_property(cont_wrapper, "modulate:a", 1.0, 0.3).set_delay(0.2)

# ── Barman Introduces Level 2 (Level 1 win only) ──

func _build_barman_level2_card() -> void:
	var card := _create_card()

	_add_spacer(card, 30)

	# Barman portrait (compact to leave room for story text)
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

# ── Friday Night Bridge (Level 1 win — links barman suggestion to mate intro) ──

func _build_friday_night_card() -> void:
	var card := _create_card()

	_add_spacer(card, 100)

	var next_venue: String = OpponentData.get_venue("derek", GameState.character)
	var dart_cost: int = 500  # £5 for a set of brass darts
	var pre_balance: int = CareerState.money

	# Story part 1 — up to "Out of your winnings."
	var story1 := Label.new()
	story1.text = "Friday comes around quick enough.\n\nYour mate drags you to the sports shop on the way. Brass darts. Five quid.\nOut of your winnings."
	UIFont.apply(story1, UIFont.BODY)
	story1.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	story1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story1.custom_minimum_size = Vector2(640, 0)
	card.add_child(story1)

	_add_spacer(card, 10)

	# Balance display — right under "Out of your winnings."
	var balance_label := Label.new()
	balance_label.text = "Balance: " + _format_money(pre_balance)
	UIFont.apply(balance_label, UIFont.BODY)
	balance_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_label.custom_minimum_size = Vector2(640, 40)
	card.add_child(balance_label)

	# Deduction label (hidden, fades in via deferred animation)
	var deduction_label := Label.new()
	deduction_label.text = "Brass darts: -" + _format_money(dart_cost)
	UIFont.apply(deduction_label, UIFont.CAPTION)
	deduction_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
	deduction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deduction_label.custom_minimum_size = Vector2(640, 35)
	deduction_label.modulate.a = 0.0
	card.add_child(deduction_label)

	_add_spacer(card, 15)

	# Story part 2 — venue + crowd quip
	var story2 := Label.new()
	story2.text = next_venue + ".\n\nThere's actually a crowd.\nWell, eight people. Still more than Tuesday."
	UIFont.apply(story2, UIFont.BODY)
	story2.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	story2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story2.custom_minimum_size = Vector2(640, 0)
	card.add_child(story2)

	# Deduct cost and set dart ownership
	CareerState.money -= dart_cost
	CareerState.dart_tier_owned = 0  # brass
	GameState.dart_tier = 0

	_add_spacer(card, 20)

	_add_continue_button(card)
	_add_card(card, "Friday Night")

	# Deferred animation — balance winds down when card appears
	var card_idx := _cards.size() - 1
	_card_animations[card_idx] = func():
		var tween := create_tween()
		tween.tween_property(deduction_label, "modulate:a", 1.0, 0.3).set_delay(1.0)
		tween.tween_property(balance_label, "modulate:a", 0.0, 0.2).set_delay(0.3)
		tween.tween_callback(func(): balance_label.text = "Balance: " + _format_money(CareerState.money))
		tween.tween_property(balance_label, "modulate:a", 1.0, 0.3)

# ── Doubles Explanation (mate explains checkout rules before 101) ──

func _build_doubles_explanation_card() -> void:
	var card := _create_card()

	_add_spacer(card, 60)

	# Companion-style panel for the mate
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

	# Mate placeholder portrait (coloured rect with initial)
	var mate_wrapper := Control.new()
	mate_wrapper.custom_minimum_size = Vector2(560, 140)
	var mate_bg := ColorRect.new()
	mate_bg.position = Vector2.ZERO
	mate_bg.size = Vector2(560, 140)
	mate_bg.color = Color(0.2, 0.35, 0.5)
	mate_wrapper.add_child(mate_bg)
	var mate_initial := Label.new()
	mate_initial.text = "M"
	mate_initial.position = Vector2.ZERO
	mate_initial.size = Vector2(560, 140)
	mate_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mate_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIFont.apply(mate_initial, UIFont.SCREEN_TITLE)
	mate_initial.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	mate_wrapper.add_child(mate_initial)
	vbox.add_child(mate_wrapper)

	# Speaker name
	var name_label := Label.new()
	name_label.text = "YOUR MATE"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
	UIFont.apply(name_label, UIFont.BODY)
	vbox.add_child(name_label)

	# Dialogue
	var dialogue := Label.new()
	dialogue.text = "This one's 101. You know you have to check out on a double, yeah?"
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue.custom_minimum_size = Vector2(560, 0)
	dialogue.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	UIFont.apply(dialogue, UIFont.BODY)
	vbox.add_child(dialogue)

	panel.add_child(vbox)
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

	# Explanation (hidden initially) — uses RichTextLabel for coloured "double" text
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

# ── Mate Introduces Derek (Level 1 win only) ──

func _build_mate_intro_card() -> void:
	var card := _create_card()

	_add_spacer(card, 50)

	# Derek portrait at top
	var tex := load("res://Derek.jpg")
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(640, 220)
		card.add_child(img)
		_add_spacer(card, 15)

	# Companion-style panel for the mate's dialogue
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

	# Mate placeholder portrait
	var mate_wrapper := Control.new()
	mate_wrapper.custom_minimum_size = Vector2(560, 120)
	var mate_bg := ColorRect.new()
	mate_bg.position = Vector2.ZERO
	mate_bg.size = Vector2(560, 120)
	mate_bg.color = Color(0.2, 0.35, 0.5)
	mate_wrapper.add_child(mate_bg)
	var mate_initial := Label.new()
	mate_initial.text = "M"
	mate_initial.position = Vector2.ZERO
	mate_initial.size = Vector2(560, 120)
	mate_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mate_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIFont.apply(mate_initial, UIFont.SCREEN_TITLE)
	mate_initial.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	mate_wrapper.add_child(mate_initial)
	vbox.add_child(mate_wrapper)

	# Speaker name
	var name_label := Label.new()
	name_label.text = "YOUR MATE"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
	UIFont.apply(name_label, UIFont.BODY)
	vbox.add_child(name_label)

	# Dialogue
	var dialogue := Label.new()
	dialogue.text = "Derek \"The Postman\" they call him.\n\nI can't see him being too much of a problem."
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue.custom_minimum_size = Vector2(560, 0)
	dialogue.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	UIFont.apply(dialogue, UIFont.BODY)
	vbox.add_child(dialogue)

	panel.add_child(vbox)
	card.add_child(panel)

	_add_spacer(card, 25)

	_add_continue_button(card)
	_add_card(card, "Mate Intro")

# ── Derek Stats Card (Level 1 win — opponent reveal before match) ──

func _build_derek_stats_card() -> void:
	var card := _create_card()

	_add_spacer(card, 25)

	# "YOUR OPPONENT" header (yellow — standard for all opponent reveal cards)
	var header := Label.new()
	header.text = "YOUR OPPONENT"
	UIFont.apply(header, UIFont.SUBHEADING)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.custom_minimum_size = Vector2(640, 50)
	card.add_child(header)

	_add_spacer(card, 10)

	# Derek portrait (reduced to fit with header)
	var tex := load("res://Derek.jpg")
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(640, 180)
		card.add_child(img)

	_add_spacer(card, 10)

	# Name + nickname
	var name_label := Label.new()
	name_label.text = "Derek\n\"The Postman\""
	UIFont.apply(name_label, UIFont.HEADING)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(640, 90)
	card.add_child(name_label)

	_add_spacer(card, 10)

	# Derek's star ratings
	var skill_row := _career_stars_row("SKILL", 4, 5)
	card.add_child(skill_row)
	var heft_row := _career_stars_row("HEFT", 1, 5)
	card.add_child(heft_row)
	var hustle_row := _career_stars_row("HUSTLE", 4, 5)
	card.add_child(hustle_row)
	var swagger_row := _career_stars_row("SWAGGER", 0, 5)
	card.add_child(swagger_row)

	_add_spacer(card, 15)

	# Game details
	var next_venue: String = OpponentData.get_venue("derek", GameState.character)
	var details := Label.new()
	details.text = "101\n" + next_venue + "\nEntry: " + _format_money(500)
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

	_add_card(card, "Derek Stats")

# ── World Champion Card ──

func _build_world_champion_card() -> void:
	var card := _create_card()

	_add_spacer(card, 150)

	var champ_label := Label.new()
	champ_label.text = "WORLD CHAMPION!"
	UIFont.apply(champ_label, UIFont.SCREEN_TITLE)
	champ_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	champ_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	champ_label.custom_minimum_size = Vector2(640, 90)
	card.add_child(champ_label)

	_add_spacer(card, 40)

	var story_label := Label.new()
	story_label.text = "You buy your parents a house with the winnings.\n\nNot bad for a kid from the local."
	UIFont.apply(story_label, UIFont.BODY)
	story_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_label.custom_minimum_size = Vector2(640, 200)
	card.add_child(story_label)

	_add_spacer(card, 60)

	var new_btn := _create_button("NEW CAREER", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	new_btn.pressed.connect(_on_new_career)
	var new_wrapper := CenterContainer.new()
	new_wrapper.custom_minimum_size = Vector2(640, 100)
	new_wrapper.add_child(new_btn)
	card.add_child(new_wrapper)

	_add_card(card, "World Champion")

# ── Next Opponent Card (Level 2+ generic) ──

func _build_next_opponent_card() -> void:
	var card := _create_card()
	var next_opp_id: String = OpponentData.OPPONENT_ORDER[CareerState.career_level - 1]
	var next_name: String = OpponentData.get_display_name(next_opp_id)
	var next_nick: String = OpponentData.get_nickname(next_opp_id)
	var next_venue: String = OpponentData.get_venue(next_opp_id, GameState.character)
	var next_opp: Dictionary = OpponentData.get_opponent(next_opp_id)
	var next_mode: String = "Round the Clock" if next_opp["game_mode"] == "rtc" else str(next_opp["starting_score"])
	var next_buy_in: int = OpponentData.get_buy_in(next_opp_id)

	_add_spacer(card, 100)

	var next_title := Label.new()
	next_title.text = "NEXT OPPONENT"
	UIFont.apply(next_title, UIFont.SUBHEADING)
	next_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	next_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_title.custom_minimum_size = Vector2(640, 50)
	card.add_child(next_title)

	_add_spacer(card, 20)

	var image_path: String = OpponentData.get_image(next_opp_id)
	if image_path != "":
		var tex := load(image_path)
		if tex:
			var img := TextureRect.new()
			img.texture = tex
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.custom_minimum_size = Vector2(640, 300)
			card.add_child(img)
			_add_spacer(card, 10)

	var name_label := Label.new()
	name_label.text = next_name + '\n"' + next_nick + '"'
	UIFont.apply(name_label, UIFont.HEADING)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(640, 100)
	card.add_child(name_label)

	_add_spacer(card, 10)

	var details_text := next_mode + "\n" + next_venue
	if next_buy_in > 0:
		details_text += "\nEntry: " + _format_money(next_buy_in)
	var details_label := Label.new()
	details_label.text = details_text
	UIFont.apply(details_label, UIFont.BODY)
	details_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.custom_minimum_size = Vector2(640, 120)
	card.add_child(details_label)

	_add_spacer(card, 40)

	var next_btn := _create_button("NEXT MATCH", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	next_btn.pressed.connect(_on_next_match)
	var next_wrapper := CenterContainer.new()
	next_wrapper.custom_minimum_size = Vector2(640, 100)
	next_wrapper.add_child(next_btn)
	card.add_child(next_wrapper)

	_add_card(card, "Next Opponent")

# ══════════════════════════════════════════
# LOSS FLOW
# ══════════════════════════════════════════

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
		var over_label := Label.new()
		if opp_level == 1:
			over_label.text = "Three weeks in a row.\nBig Kev hasn't even broken a sweat."
		elif max_losses == 1:
			over_label.text = "Win or bust.\nYou lost."
		else:
			over_label.text = "Three strikes.\nYou're out."
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

		# Level 1 flavour text
		if opp_level == 1:
			var flavour := Label.new()
			if losses == 1:
				flavour.text = "Unlucky. Same time next week?"
			else:
				flavour.text = "Nobody entered again.\nJust you and Big Kev."
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

		# Level 1 uses "COME BACK NEXT WEEK" instead of "TRY AGAIN"
		var retry_text: String = "COME BACK NEXT WEEK" if opp_level == 1 else "TRY AGAIN"
		var retry_btn := _create_button(retry_text, Color(0.15, 0.15, 0.4), Color(0.3, 0.3, 0.7))
		retry_btn.pressed.connect(_on_try_again)
		var retry_wrapper := CenterContainer.new()
		retry_wrapper.custom_minimum_size = Vector2(640, 100)
		retry_wrapper.add_child(retry_btn)
		card.add_child(retry_wrapper)

	_add_card(card, "Loss")

# ══════════════════════════════════════════
# Card system
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

# ══════════════════════════════════════════
# Helpers
# ══════════════════════════════════════════

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

func _heft_stars(tier: int) -> String:
	var filled := mini(tier, 5)
	var empty := 5 - filled
	var star_filled := "★"
	var star_empty := "☆"
	return star_filled.repeat(filled) + star_empty.repeat(empty)

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
	var star_filled_char := "★"
	var star_empty_char := "☆"
	stars.text = star_filled_char.repeat(filled) + star_empty_char.repeat(total - filled)
	stars.custom_minimum_size = Vector2(200, 50)
	UIFont.apply(stars, UIFont.BODY)
	if filled > 0:
		stars.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		stars.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(stars)

	return row

# ══════════════════════════════════════════
# Navigation
# ══════════════════════════════════════════

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
