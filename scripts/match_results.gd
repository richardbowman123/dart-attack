extends Control

## Post-match results screen — multi-card flow.
## Win: Card 1 (prize money) → Card 2 (post-win story) → Card 3 (next opponent)
## Loss: Single card (strikes or career over)
## World Champion: Card 1 (prize) → Card 2 (champion ending)

var _cards: Array[Control] = []
var _current_card: int = 0

# Post-win narrative text for each level. Shown on card 2 after beating that opponent.
# These introduce the next dynamic/character as per the career spec.
const POST_WIN_STORY := {
	1: "Big Kev shakes your hand.\n\n\"Not bad. Not bad at all.\"\n\nHe slides a chip shop meal voucher across the bar.\n\n\"Get yourself fed. You'll need it.\"",
	2: "Your mate nudges you on the way out.\n\n\"You're starting to look the part. We should get you some proper bling and a decent tattoo.\"\n\nHe grins. \"And maybe some better darts.\"",
	3: "A bloke in a flat cap catches your eye at the bar.\n\n\"Saw your match. You've got something. But you need to learn when to celebrate and when to keep your head down.\"\n\nHe taps his nose. \"And watch your back in the car park.\"",
	4: "A sharp-suited woman approaches your table.\n\n\"I manage fighters. Boxers mostly. But I know talent when I see it.\"\n\nShe slides a card across. \"Call me when you're ready to take this seriously.\"",
	5: "After the match, a man with a clipboard and a lanyard corners you.\n\n\"Sponsorship opportunity. Big money. But you'll need to fill that shirt out a bit more first.\"\n\nHe looks you up and down. \"We'll talk.\"",
	6: "Your team gathers around. The coach speaks first.\n\n\"One more. That's all that stands between you and the title.\"\n\nHe pauses. \"But the doc says you need a check-up first. No arguments.\"",
}

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Dark background (permanent, behind all cards)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	if GameState.match_won:
		_build_win_cards()
	else:
		_build_loss_card()

	# Show the first card
	_show_card(0)

func _build_win_cards() -> void:
	var prize: int = GameState.match_prize
	var opp_id: String = GameState.opponent_id
	var opp_name: String = OpponentData.get_display_name(opp_id)
	var opp_nick: String = OpponentData.get_nickname(opp_id)
	var opp_level: int = OpponentData.get_opponent(opp_id)["level"]

	# ── Card 1: Prize Money ──
	var card1 := _create_card()

	_add_spacer(card1, 150)

	var win_label := Label.new()
	win_label.text = "YOU WIN!"
	UIFont.apply(win_label, UIFont.SCREEN_TITLE)
	win_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.custom_minimum_size = Vector2(720, 90)
	card1.add_child(win_label)

	_add_spacer(card1, 10)

	var vs_label := Label.new()
	vs_label.text = "vs " + opp_name + ' "' + opp_nick + '"'
	UIFont.apply(vs_label, UIFont.SUBHEADING)
	vs_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vs_label.custom_minimum_size = Vector2(720, 50)
	card1.add_child(vs_label)

	_add_spacer(card1, 50)

	var prize_label := Label.new()
	prize_label.text = _format_money(prize)
	UIFont.apply(prize_label, UIFont.DISPLAY)
	prize_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	prize_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prize_label.custom_minimum_size = Vector2(720, 130)
	card1.add_child(prize_label)

	_add_spacer(card1, 10)

	var balance_label := Label.new()
	balance_label.text = "Balance: " + _format_money(CareerState.money)
	UIFont.apply(balance_label, UIFont.BODY)
	balance_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_label.custom_minimum_size = Vector2(720, 50)
	card1.add_child(balance_label)

	_add_spacer(card1, 80)

	_add_continue_button(card1)
	_cards.append(card1)
	add_child(card1)

	# ── Card 2: Post-win story / new character introduction ──
	if CareerState.career_level > 7:
		# World Champion ending
		var card2 := _create_card()

		_add_spacer(card2, 150)

		var champ_label := Label.new()
		champ_label.text = "WORLD CHAMPION!"
		UIFont.apply(champ_label, UIFont.SCREEN_TITLE)
		champ_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		champ_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		champ_label.custom_minimum_size = Vector2(720, 90)
		card2.add_child(champ_label)

		_add_spacer(card2, 40)

		var story_label := Label.new()
		story_label.text = "You buy your parents a house with the winnings.\n\nNot bad for a kid from the local."
		UIFont.apply(story_label, UIFont.BODY)
		story_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		story_label.custom_minimum_size = Vector2(720, 200)
		card2.add_child(story_label)

		_add_spacer(card2, 60)

		var new_btn := _create_button("NEW CAREER", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
		new_btn.pressed.connect(_on_new_career)
		var new_wrapper := CenterContainer.new()
		new_wrapper.custom_minimum_size = Vector2(720, 100)
		new_wrapper.add_child(new_btn)
		card2.add_child(new_wrapper)

		_cards.append(card2)
		add_child(card2)
	else:
		# Post-win narrative card
		var card2 := _create_card()

		_add_spacer(card2, 200)

		var story_text: String = POST_WIN_STORY.get(opp_level, "The crowd disperses. Time to move on.")
		var story_label := Label.new()
		story_label.text = story_text
		UIFont.apply(story_label, UIFont.BODY)
		story_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		story_label.custom_minimum_size = Vector2(720, 400)
		card2.add_child(story_label)

		_add_spacer(card2, 60)

		_add_continue_button(card2)
		_cards.append(card2)
		add_child(card2)

		# ── Card 3: Next opponent introduction ──
		var card3 := _create_card()
		var next_opp_id: String = OpponentData.OPPONENT_ORDER[CareerState.career_level - 1]
		var next_name: String = OpponentData.get_display_name(next_opp_id)
		var next_nick: String = OpponentData.get_nickname(next_opp_id)
		var next_venue: String = OpponentData.get_venue(next_opp_id, GameState.character)
		var next_opp: Dictionary = OpponentData.get_opponent(next_opp_id)
		var next_mode: String = "Round the Clock" if next_opp["game_mode"] == "rtc" else str(next_opp["starting_score"])
		var next_buy_in: int = OpponentData.get_buy_in(next_opp_id)

		_add_spacer(card3, 100)

		var next_title := Label.new()
		next_title.text = "NEXT OPPONENT"
		UIFont.apply(next_title, UIFont.SUBHEADING)
		next_title.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		next_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		next_title.custom_minimum_size = Vector2(720, 50)
		card3.add_child(next_title)

		_add_spacer(card3, 20)

		# Opponent image
		var image_path: String = OpponentData.get_image(next_opp_id)
		if image_path != "":
			var tex := load(image_path)
			if tex:
				var img := TextureRect.new()
				img.texture = tex
				img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				img.custom_minimum_size = Vector2(720, 300)
				card3.add_child(img)
				_add_spacer(card3, 10)

		# Name
		var name_label := Label.new()
		name_label.text = next_name + '\n"' + next_nick + '"'
		UIFont.apply(name_label, UIFont.HEADING)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.custom_minimum_size = Vector2(720, 100)
		card3.add_child(name_label)

		_add_spacer(card3, 10)

		# Details
		var details_text := next_mode + "\n" + next_venue
		if next_buy_in > 0:
			details_text += "\nEntry: " + _format_money(next_buy_in)
		var details_label := Label.new()
		details_label.text = details_text
		UIFont.apply(details_label, UIFont.BODY)
		details_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details_label.custom_minimum_size = Vector2(720, 120)
		card3.add_child(details_label)

		_add_spacer(card3, 40)

		# Next match button
		var next_btn := _create_button("NEXT MATCH", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
		next_btn.pressed.connect(_on_next_match)
		var next_wrapper := CenterContainer.new()
		next_wrapper.custom_minimum_size = Vector2(720, 100)
		next_wrapper.add_child(next_btn)
		card3.add_child(next_wrapper)

		_cards.append(card3)
		add_child(card3)

func _build_loss_card() -> void:
	var opp_id: String = GameState.opponent_id
	var opp_name: String = OpponentData.get_display_name(opp_id)
	var opp_nick: String = OpponentData.get_nickname(opp_id)
	var career_over: bool = GameState.match_career_over
	var max_losses: int = OpponentData.get_max_losses(opp_id)
	var losses: int = CareerState.losses_at_current_level

	var card := _create_card()

	_add_spacer(card, 150)

	# Result banner
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
	result_label.custom_minimum_size = Vector2(720, 90)
	card.add_child(result_label)

	_add_spacer(card, 10)

	var vs_label := Label.new()
	vs_label.text = "vs " + opp_name + ' "' + opp_nick + '"'
	UIFont.apply(vs_label, UIFont.SUBHEADING)
	vs_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vs_label.custom_minimum_size = Vector2(720, 50)
	card.add_child(vs_label)

	_add_spacer(card, 40)

	if career_over:
		var over_label := Label.new()
		if max_losses == 1:
			over_label.text = "Win or bust.\nYou lost."
		else:
			over_label.text = "Three strikes.\nYou're out."
		UIFont.apply(over_label, UIFont.HEADING)
		over_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.4))
		over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		over_label.custom_minimum_size = Vector2(720, 100)
		card.add_child(over_label)

		_add_spacer(card, 20)

		var balance_label := Label.new()
		balance_label.text = "Final balance: " + _format_money(CareerState.money)
		UIFont.apply(balance_label, UIFont.BODY)
		balance_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		balance_label.custom_minimum_size = Vector2(720, 50)
		card.add_child(balance_label)

		_add_spacer(card, 50)

		var new_btn := _create_button("NEW CAREER", Color(0.5, 0.15, 0.15), Color(0.8, 0.3, 0.3))
		new_btn.pressed.connect(_on_new_career)
		var new_wrapper := CenterContainer.new()
		new_wrapper.custom_minimum_size = Vector2(720, 100)
		new_wrapper.add_child(new_btn)
		card.add_child(new_wrapper)
	else:
		# Strike count
		var strike_label := Label.new()
		strike_label.text = "Strike " + str(losses) + " of " + str(max_losses)
		UIFont.apply(strike_label, UIFont.HEADING)
		strike_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
		strike_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		strike_label.custom_minimum_size = Vector2(720, 60)
		card.add_child(strike_label)

		# Visual strike indicators
		var strikes_row := HBoxContainer.new()
		strikes_row.alignment = BoxContainer.ALIGNMENT_CENTER
		strikes_row.add_theme_constant_override("separation", 20)
		strikes_row.custom_minimum_size = Vector2(720, 70)
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

		var balance_label := Label.new()
		balance_label.text = "Balance: " + _format_money(CareerState.money)
		UIFont.apply(balance_label, UIFont.BODY)
		balance_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		balance_label.custom_minimum_size = Vector2(720, 50)
		card.add_child(balance_label)

		_add_spacer(card, 40)

		var retry_btn := _create_button("TRY AGAIN", Color(0.15, 0.15, 0.4), Color(0.3, 0.3, 0.7))
		retry_btn.pressed.connect(_on_try_again)
		var retry_wrapper := CenterContainer.new()
		retry_wrapper.custom_minimum_size = Vector2(720, 100)
		retry_wrapper.add_child(retry_btn)
		card.add_child(retry_wrapper)

	_cards.append(card)
	add_child(card)

# ── Card system ──

func _create_card() -> VBoxContainer:
	var card := VBoxContainer.new()
	card.position = Vector2(0, 0)
	card.size = Vector2(720, 1280)
	card.add_theme_constant_override("separation", 0)
	card.visible = false
	return card

func _show_card(index: int) -> void:
	for i in range(_cards.size()):
		_cards[i].visible = (i == index)
	_current_card = index

func _advance_card() -> void:
	if _current_card < _cards.size() - 1:
		_show_card(_current_card + 1)

func _add_continue_button(card: Control) -> void:
	var btn := _create_button("CONTINUE", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5))
	btn.pressed.connect(_advance_card)
	var wrapper := CenterContainer.new()
	wrapper.custom_minimum_size = Vector2(720, 100)
	wrapper.add_child(btn)
	card.add_child(wrapper)

# ── Helpers ──

func _add_spacer(parent: Control, height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(720, height)
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

# ── Navigation ──

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
	get_tree().change_scene_to_file("res://scenes/career_dart_choice.tscn")

func _on_try_again() -> void:
	get_tree().change_scene_to_file("res://scenes/career_dart_choice.tscn")

func _on_new_career() -> void:
	CareerState.reset()
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")
