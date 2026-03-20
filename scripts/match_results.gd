extends Control

## Post-match results screen — multi-card flow.
## Level 1 Win: Prize -> Skill star -> Big Kev dialogue -> Buffet decision -> Heft star ->
##              Barman L2 -> Friday night (ENTER SHOP) -> [dart shop] -> Swagger star (first darts!) -> Bridge -> Doubles explanation -> Alan intro -> Derek stats
## Level 2 Win: Prize -> Skill star -> Hustle star -> Kebab -> Alan hungover ->
##              Tattoos & Bling (3 tiers) -> Swagger star (IMAGE CHANGE!) -> Alan introduces Steve -> Mates joining -> [DART SHOP] -> Bridge -> Steve stats
## Level 3 Win: Prize -> [Trader Profit] -> Skill star -> Steve dialogue -> Celebration choice -> Swagger star ->
##              Fry up -> Heft star -> Trader intro -> Coach offer -> Hustle star -> [DART SHOP] -> Bridge -> Edward stats
## Level 4 Win: Prize -> Skill star -> Steak dinner -> Heft star -> Manager offer ->
##              Hustle star -> Silk shirt -> Swagger star -> Gambling intro -> [DART SHOP] -> Bridge -> Mad Dog stats
## Level 5 Win: Prize -> Skill star (MAX) -> Pasta -> Heft star -> Sponsor intro ->
##              Dodgy bet -> Swagger star -> Team offer -> Hustle star -> Doctor hint -> [DART SHOP] -> Bridge -> Manager Lars intro -> Lars stats
## Level 6 Win: Prize -> All stars snapshot -> Room service -> Heft star (if <5) ->
##              Coach dialogue -> Doctor visit -> Vinnie "The Gold" intro -> Walk-on music (narrative only) -> [DART SHOP] -> Bridge -> Manager Vinnie intro -> Vinnie stats
## Level 7 Win: Prize -> Final stars -> Ending -> New Career
## Loss: [Trader Profit if pending] -> Level-specific flavour text + strikes or career over
## Trader profit card appears after prize (win) or before loss card (loss) if merch was committed

var _cards: Array[Control] = []
var _current_card: int = 0
var _card_animations: Dictionary = {}
var _retry_mode := false
var _balance_panel: PanelContainer
var _balance_label_overlay: Label

# Big Kev's random meal offers — one picked per playthrough, all free, all dodgy
const KEV_MEALS := [
	"I've got a voucher for the Golden Dragon. Two-for-one, expires tomorrow. The sweet and sour is... an experience. Go on, fill your boots.",
	"My mate runs a burger van round the back. Failed the last inspection but it's still open. Tell him I sent you, he'll sort you out.",
	"The kebab shop bloke owes me twenty quid. I'm not seeing that money again. But he'll give you a large donner and chips if you tell him Big Kev sent you.",
	"My cousin does a chippy tea on Fridays. Family discount. Which means free. The batter's an inch thick.",
	"My nan makes pies for the social club. She always makes too many. Nobody asks what's in them. Nobody wants to know.",
	"The pub does an all-day breakfast. I've got a loyalty card, tenth one's free. I've got about forty of these.",
	"The Indian next door owes me a favour. Don't ask what favour. But they'll give you a lamb bhuna and chips.",
	"The barmaid does jacket potatoes on Tuesdays. Tell her you're with me. She'll put extra beans on.",
]

# Insistence dialogue — companion forces food/hiring if player declines twice
const FOOD_INSISTENCE := {
	1: {"speaker": "BIG KEV", "first": "Come on, I won this voucher for you. Don't be daft.", "forced": "Right, you're having the duck. End of.", "color": Color.BLACK, "initial": "", "image": "res://Big Kev.jpg"},
	2: {"speaker": "ALAN", "first": "You need something to soak up tonight. Trust me.", "forced": "Right, you're eating whether you like it or not.", "color": Color.BLACK, "initial": "", "image": "res://Mate for Level 2 - Alan.png"},
	3: {"speaker": "ALAN", "first": "Heavy day ahead. Best line your stomach.", "forced": "I'm not taking you to the county club looking like that. Eat.", "color": Color.BLACK, "initial": "", "image": "res://Mate for Level 2 - Alan.png"},
	4: {"speaker": "THE MANAGER", "first": "She's paying. Don't be rude.", "forced": "It's already ordered. Sit down.", "color": Color(0.4, 0.15, 0.25), "initial": "S", "image": "res://Manager cropped new.png"},
	5: {"speaker": "THE COACH", "first": "Carb loading. It's science.", "forced": "You're eating the pasta. Non-negotiable.", "color": Color(0.15, 0.35, 0.2), "initial": "C", "image": "res://Coach cropped.png"},
	6: {"speaker": "THE MANAGER", "first": "You need fuel for tomorrow. Order something.", "forced": "Room service is already on its way. Deal with it.", "color": Color(0.4, 0.15, 0.25), "initial": "S", "image": "res://Manager cropped new.png"},
}

const HIRE_INSISTENCE := {
	"coach": {"speaker": "ALAN", "first": "I've taken you as far as I can. You need someone who knows what they're doing.", "forced": "I've already spoken to him. He's on board.", "color": Color.BLACK, "initial": "", "image": "res://Mate for Level 2 - Alan.png"},
	"manager": {"speaker": "THE COACH", "first": "You need someone handling the business side. Focus on the darts.", "forced": "I've arranged it. She's starting tomorrow.", "color": Color(0.15, 0.35, 0.2), "initial": "C", "image": "res://Coach cropped.png"},
	"team": {"speaker": "THE MANAGER", "first": "The Worlds is a different beast. You can't do this alone.", "forced": "I've made the calls. The team's in place.", "color": Color(0.4, 0.15, 0.25), "initial": "S", "image": "res://Manager cropped new.png"},
}

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	if CareerState.exhibition_mode:
		_build_exhibition_result_cards()
	elif CareerState.post_shop_resume:
		CareerState.post_shop_resume = false
		_build_post_shop_cards()
	elif GameState.match_won:
		_build_win_cards()
	else:
		if CareerState.drink_death_occurred:
			_build_drink_death_card()
		elif CareerState.fight_decided_match:
			# Lars killed you — death card (same format as drink/mafia death)
			_build_lars_death_card()
		else:
			# Trader profit card before loss card (sales happen regardless of result)
			_build_trader_profit_card()
			_build_loss_card()

	_show_card(0)
	_build_balance_overlay()

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

	# Trader profit card (if pending sale — appears after prize, before level cards)
	_build_trader_profit_card()

	# Branch by level
	if CareerState.career_level > 7:
		_build_world_champion_cards()
	elif opp_level == 1:
		_build_skill_star_card()
		_build_bigkev_meal_card()
		_build_heft_star_card()
		_build_barman_level2_card()
		_build_friday_night_card()
		_build_doubles_explanation_card()
		_build_mate_intro_card()
		_build_pre_drink_card()
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
		_build_dart_shop_card()
		_build_pre_drink_card()
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

	_add_spacer(card, 15)

	# Player portrait — use tier-aware image in career mode
	var portrait_path: String
	if CareerState.career_mode_active:
		portrait_path = DartData.get_profile_image_for_tier(GameState.character, CareerState.calculate_appearance_tier())
	else:
		portrait_path = DartData.get_profile_image(GameState.character)
	var tex := load(portrait_path)
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.custom_minimum_size = Vector2(640, 420)
		card.add_child(img)

	_add_spacer(card, 10)

	# Player name (nickname only if active)
	var char_name: String = DartData.get_full_name(GameState.character)
	var name_label := Label.new()
	if CareerState.nickname_active:
		var char_nick: String = DartData.get_character_nickname(GameState.character)
		name_label.text = char_name + '\n"' + char_nick + '"'
		name_label.custom_minimum_size = Vector2(640, 90)
	else:
		name_label.text = char_name
		name_label.custom_minimum_size = Vector2(640, 60)
	UIFont.apply(name_label, UIFont.HEADING)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	skill_stars_wrapper.custom_minimum_size = Vector2(260, 50)
	skill_stars_wrapper.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	skill_stars_wrapper.pivot_offset = Vector2(130, 25)
	var skill_stars_before := _build_star_image(0)
	skill_stars_before.position = Vector2.ZERO
	skill_stars_before.size = Vector2(260, 50)
	skill_stars_wrapper.add_child(skill_stars_before)
	var skill_stars_after := _build_star_image(1)
	skill_stars_after.position = Vector2.ZERO
	skill_stars_after.size = Vector2(260, 50)
	skill_stars_after.visible = false
	skill_stars_wrapper.add_child(skill_stars_after)
	skill_row.add_child(skill_stars_wrapper)
	card.add_child(skill_row)

	# Other star rows (static except SWAGGER which also flips)
	card.add_child(_career_stars_row("HEFT", CareerState.heft_tier, 5))
	card.add_child(_career_stars_row("HUSTLE", CareerState.hustle_stars, 5))

	# SWAGGER row — static at L1, grows from L2 onwards
	card.add_child(_career_stars_row("SWAGGER", CareerState.swagger_stars, 5))

	_add_spacer(card, 25)

	# Quip (fades in after animation -- running commentary, no speech marks)
	var quip := Label.new()
	quip.text = "Well, you're not hopeless..."
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

	_add_card(card, "Skill Star")

	# Deferred animation — skill star flip
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
		# Quip and button fade in after flip
		tween.tween_property(quip, "modulate:a", 1.0, 0.3).set_delay(0.3)
		tween.tween_property(cont_wrapper, "modulate:a", 1.0, 0.3).set_delay(0.2)

func _build_bigkev_meal_card() -> void:
	var card := _create_card()

	_add_spacer(card, 40)

	# Pick a random meal from the pool
	var meal_text: String = KEV_MEALS[randi() % KEV_MEALS.size()]

	# Big Kev panel — congratulation + bulking up + meal offer
	var panel := _build_companion_panel(
		"BIG KEV",
		"\"Not bad. Not bad at all.\"\n\nHe looks you up and down.\n\n\"You need feeding up. You're like a pipe cleaner.\"\n\nHe leans across the bar.\n\n\"" + meal_text + "\"",
		Color.BLACK, "", "res://Big Kev.jpg", UIFont.PORTRAIT_S
	)
	card.add_child(panel)

	_add_spacer(card, 20)

	# One button — no choice, just flavour
	var btn := _create_button("CHEERS KEV", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	btn.pressed.connect(func():
		CareerState.heft_tier += 1
		_advance_card()
	)
	var btn_w := CenterContainer.new()
	btn_w.custom_minimum_size = Vector2(640, 80)
	btn_w.add_child(btn)
	card.add_child(btn_w)

	_add_card(card, "Big Kev Meal")

func _build_heft_star_card() -> void:
	var card := _create_card()

	_add_spacer(card, 15)

	var portrait_path: String
	if CareerState.career_mode_active:
		portrait_path = DartData.get_profile_image_for_tier(GameState.character, CareerState.calculate_appearance_tier())
	else:
		portrait_path = DartData.get_profile_image(GameState.character)
	var tex := load(portrait_path)
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.custom_minimum_size = Vector2(640, 420)
		card.add_child(img)

	_add_spacer(card, 10)

	var char_name: String = DartData.get_full_name(GameState.character)
	var name_label := Label.new()
	if CareerState.nickname_active:
		var char_nick: String = DartData.get_character_nickname(GameState.character)
		name_label.text = char_name + '\n"' + char_nick + '"'
		name_label.custom_minimum_size = Vector2(640, 90)
	else:
		name_label.text = char_name
		name_label.custom_minimum_size = Vector2(640, 60)
	UIFont.apply(name_label, UIFont.HEADING)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	heft_stars_wrapper.custom_minimum_size = Vector2(260, 50)
	heft_stars_wrapper.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	heft_stars_wrapper.pivot_offset = Vector2(130, 25)
	var heft_stars_before := _build_star_image(0)
	heft_stars_before.position = Vector2.ZERO
	heft_stars_before.size = Vector2(260, 50)
	heft_stars_wrapper.add_child(heft_stars_before)
	var heft_stars_after := _build_star_image(1)
	heft_stars_after.position = Vector2.ZERO
	heft_stars_after.size = Vector2(260, 50)
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

	_add_spacer(card, 20)

	var tex := load("res://Barman.jpg")
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.custom_minimum_size = Vector2(640, UIFont.PORTRAIT_M)
		card.add_child(img)

	_add_spacer(card, 10)

	var next_venue: String = OpponentData.get_venue("derek", GameState.character)

	var story := Label.new()
	story.text = "The barman catches you on the way out.\n\n\"There's a proper tournament Friday night. 101. Five quid entry.\n\n" + next_venue + ".\n\nYou'll need your own darts, mind.\""
	UIFont.apply(story, UIFont.BODY)
	story.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.custom_minimum_size = Vector2(640, 0)
	card.add_child(story)

	_add_spacer(card, 15)

	_add_continue_button(card)
	_add_card(card, "Barman L2")

func _build_friday_night_card() -> void:
	var card := _create_card()

	_add_spacer(card, 120)

	var story := Label.new()
	story.text = "Friday comes around quick enough.\n\nYou pop into a discount sports shop on the way.\n\nTime to get your own set."
	UIFont.apply(story, UIFont.BODY)
	story.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.custom_minimum_size = Vector2(640, 0)
	card.add_child(story)

	_add_spacer(card, 20)

	var balance_label := Label.new()
	balance_label.text = "Balance: " + _format_money(CareerState.money)
	UIFont.apply(balance_label, UIFont.CAPTION)
	balance_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.3))
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_label.custom_minimum_size = Vector2(640, 35)
	card.add_child(balance_label)

	_add_spacer(card, 40)

	var shop_btn := _create_button("ENTER SHOP", Color(0.12, 0.35, 0.15), Color(0.2, 0.65, 0.3))
	shop_btn.pressed.connect(_on_enter_shop)
	var shop_wrapper := CenterContainer.new()
	shop_wrapper.custom_minimum_size = Vector2(640, 100)
	shop_wrapper.add_child(shop_btn)
	card.add_child(shop_wrapper)

	_add_card(card, "Friday Night")


func _on_enter_shop() -> void:
	CareerState.dart_shop_return = "res://scenes/match_results.tscn"
	CareerState.post_shop_resume = true
	get_tree().change_scene_to_file("res://scenes/dart_select.tscn")


func _build_dart_shop_card() -> void:
	# Skip if player already owns the best darts (Premium Tungsten, tier 3)
	if CareerState.dart_tier_owned >= 3:
		return

	var card := _create_card()
	_add_spacer(card, 120)

	var title := Label.new()
	title.text = "DART SHOP"
	UIFont.apply(title, UIFont.HEADING)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(640, 70)
	card.add_child(title)

	_add_spacer(card, 10)

	var dart_name: String = DartData.get_tier(max(0, CareerState.dart_tier_owned))["name"]
	var desc := Label.new()
	desc.text = "Currently playing with " + dart_name + " darts.\nFancy an upgrade?"
	UIFont.apply(desc, UIFont.BODY)
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(640, 0)
	card.add_child(desc)

	_add_spacer(card, 10)

	var balance := Label.new()
	balance.text = "Balance: " + _format_money(CareerState.money)
	UIFont.apply(balance, UIFont.CAPTION)
	balance.add_theme_color_override("font_color", Color(0.2, 0.85, 0.3))
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance.custom_minimum_size = Vector2(640, 35)
	card.add_child(balance)

	_add_spacer(card, 30)

	var shop_btn := _create_button("ENTER SHOP", Color(0.12, 0.35, 0.15), Color(0.2, 0.65, 0.3))
	shop_btn.pressed.connect(_on_enter_shop)
	var shop_w := CenterContainer.new()
	shop_w.custom_minimum_size = Vector2(640, 100)
	shop_w.add_child(shop_btn)
	card.add_child(shop_w)

	_add_spacer(card, 10)

	var skip_btn := _create_button("SKIP", Color(0.2, 0.2, 0.25), Color(0.4, 0.4, 0.45))
	skip_btn.pressed.connect(_advance_card)
	var skip_w := CenterContainer.new()
	skip_w.custom_minimum_size = Vector2(640, 100)
	skip_w.add_child(skip_btn)
	card.add_child(skip_w)

	_add_card(card, "Dart Shop")


func _build_post_shop_cards() -> void:
	# Resuming after the dart shop — build remaining cards for the level we just beat
	var beaten_level := CareerState.career_level - 1

	match beaten_level:
		1:
			# L1 post-shop: swagger star (darts) + bridge + doubles + mate intro + pre-drink + Derek
			# Buying darts triggers swagger star 1
			CareerState.recalculate_swagger()
			_build_star_flip_card("SWAGGER", CareerState.swagger_stars - 1, CareerState.swagger_stars,
				"Your own cheap brass darts. Classy.",
				func(): CareerState.recalculate_swagger())
			var next_venue: String = OpponentData.get_venue("derek", GameState.character)
			var dart_name: String = DartData.get_tier(max(0, CareerState.dart_tier_owned))["name"]
			var card := _create_card()
			_add_spacer(card, 150)
			var story := Label.new()
			story.text = dart_name + " darts in the bag.\n\n" + next_venue + ".\n\nThere's actually a crowd.\nWell, eight people. Still more than Tuesday.\n\nYou spot your 'mate' Alan in the crowd. Not seen him since school."
			UIFont.apply(story, UIFont.BODY)
			story.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
			story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			story.custom_minimum_size = Vector2(640, 0)
			card.add_child(story)
			_add_spacer(card, 30)
			_add_continue_button(card)
			_add_card(card, "Post-Shop Bridge")
			_build_doubles_explanation_card()
			_build_mate_intro_card()
			_build_pre_drink_card()
			_build_derek_stats_card()
		2:
			_build_bridge_card("", OpponentData.get_venue("steve", GameState.character), "Proper oche. Small stage. Folding chairs for fifty. A commentator with a microphone.", 2000)
			_build_pre_drink_card()
			_build_opponent_stats_card("steve", "Steve", "The Sparky", {"SKILL": 3, "HEFT": 2, "HUSTLE": 2, "SWAGGER": 1}, "101, Best of 7")
		3:
			_build_bridge_card("", "County Darts Club", "Lighting rig. Raised oche. Sponsor banners. Two hundred in the crowd. Regional TV cameras.\n\nWin or bust from here. No second chances.", 7500)
			_build_pre_drink_card()
			_build_opponent_stats_card("philip", "Edward", "The Accountant", {"SKILL": 4, "HEFT": 2, "HUSTLE": 3, "SWAGGER": 3}, "301, Best of 5")
		4:
			_build_bridge_card("", "National Qualifying, Milton Keynes", "Conference centre. Harsh fluorescent lighting. Five hundred watching. Everyone thinks they're good enough.\n\nWin or bust from here. No second chances.", 20000)
			_build_pre_drink_card()
			_build_opponent_stats_card("mad_dog", "Lisa", "Mad Dog", {"SKILL": 3, "HEFT": 3, "HUSTLE": 2, "SWAGGER": 4}, "301, Best of 7")
		5:
			_build_bridge_card("The Arrow Palace, London.", "World Championship Semi-Final", "The cathedral of darts. Walk-on music. Pyrotechnics. Two thousand in fancy dress.", 50000)
			_build_pre_drink_card()
			_build_opponent_stats_card("lars", "Lars", "The Viking", {"SKILL": 4, "HEFT": 5, "HUSTLE": 3, "SWAGGER": 4}, "501, Best of 5")
		6:
			_build_bridge_card("World Championship Final.", "The Arrow Palace, London", "Gold confetti loaded. Fireworks ready.\nTwo thousand on their feet.\n\nThis is it.", 100000)
			_build_pre_drink_card()
			_build_opponent_stats_card("vinnie", "Vinnie", "The Gold", {"SKILL": 5, "HEFT": 4, "HUSTLE": 5, "SWAGGER": 5}, "501, Best of 7")

func _build_doubles_explanation_card() -> void:
	var card := _create_card()

	_add_spacer(card, 60)

	var panel := _build_companion_panel(
		"ALAN",
		"This one's 101. You know you have to check out on a double, yeah?",
		Color.BLACK, "", "res://Mate for Level 2 - Alan.png", UIFont.PORTRAIT_L
	)
	card.add_child(panel)

	# Get reference to dialogue label inside panel so we can hide it on expand
	var panel_dialogue: Label = panel.get_child(0).get_child(2)

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
		panel_dialogue.visible = false
		explain.visible = true
		got_wrapper.visible = true
	)

	_add_card(card, "Doubles")

func _build_mate_intro_card() -> void:
	var card := _create_card()

	_add_spacer(card, 15)

	var tex := load("res://Derek.jpg")
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.custom_minimum_size = Vector2(640, 420)
		card.add_child(img)
		_add_spacer(card, 15)

	var panel := _build_companion_panel(
		"ALAN",
		"Looks like you've been drawn against Derek. \"The Postman\" they call him.\n\nI can't see him being too much of a problem.",
		Color.BLACK, "", "res://Mate for Level 2 - Alan.png", UIFont.PORTRAIT_S
	)
	card.add_child(panel)

	_add_spacer(card, 25)

	_add_continue_button(card)
	_add_card(card, "Alan Intro")

func _build_derek_stats_card() -> void:
	_build_opponent_stats_card(
		"derek", "Derek", "The Postman",
		{"SKILL": 4, "HEFT": 1, "HUSTLE": 4, "SWAGGER": 0},
		"101, Best of 3"
	)

# ======================================================
# LEVEL 2 POST-WIN (Beat Derek "The Postman")
# ======================================================

func _build_l2_win_cards() -> void:
	# Card 2: Skill star 1->2
	_build_star_flip_card("SKILL", CareerState.skill_stars, CareerState.skill_stars + 1, "Friday night champion.", func(): CareerState.skill_stars += 1)

	# Card 3: Hustle star 1->2 (two tournaments won — people are paying attention)
	_build_star_flip_card("HUSTLE", CareerState.hustle_stars, CareerState.hustle_stars + 1, "Two wins.\nGoing places.", func(): CareerState.recalculate_hustle())

	# Card 4: Drunken walk home — kebab shop (three choices, all +1 heft)
	_build_kebab_card()

	# Card 5: Hungover next day — mate suggests tattoos and bling
	var mate_card := _create_card()
	_add_spacer(mate_card, 60)
	var mate_panel := _build_companion_panel(
		"ALAN",
		"Hungover. Alan rings.\n\n\"We should celebrate your emergence as a proper darts player. Tattoos and a bit of bling. I know a place.\n\nI'm going cheap obviously. You're paying.\"",
		Color.BLACK, "", "res://Mate for Level 2 - Alan.png", UIFont.PORTRAIT_XL
	)
	mate_card.add_child(mate_panel)
	_add_spacer(mate_card, 30)
	_add_continue_button(mate_card)
	_add_card(mate_card, "L2 Alan Hungover")

	# Card 6: Tattoos & bling — three price tiers, no skip, all give swagger
	var bling_card := _create_card()
	_add_spacer(bling_card, 80)

	var bling_title := Label.new()
	bling_title.text = "TATTOOS & BLING"
	UIFont.apply(bling_title, UIFont.HEADING)
	bling_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	bling_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bling_title.custom_minimum_size = Vector2(640, 70)
	bling_card.add_child(bling_title)

	_add_spacer(bling_card, 10)

	var bling_desc := Label.new()
	bling_desc.text = "Matching tattoos and a bit of gold.\nPick your budget.\nAlan's going cheap either way."
	UIFont.apply(bling_desc, UIFont.BODY)
	bling_desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	bling_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bling_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bling_desc.custom_minimum_size = Vector2(640, 80)
	bling_card.add_child(bling_desc)

	_add_spacer(bling_card, 20)

	# Reaction area (hidden until selection)
	var bling_reaction := VBoxContainer.new()
	bling_reaction.visible = false
	bling_reaction.add_theme_constant_override("separation", 15)
	bling_reaction.custom_minimum_size = Vector2(640, 0)
	var bling_reaction_label := Label.new()
	UIFont.apply(bling_reaction_label, UIFont.BODY)
	bling_reaction_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	bling_reaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bling_reaction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bling_reaction_label.custom_minimum_size = Vector2(640, 0)
	bling_reaction.add_child(bling_reaction_label)
	var bling_done_btn := _create_button("CONTINUE", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5))
	bling_done_btn.pressed.connect(_advance_card)
	var bling_done_w := CenterContainer.new()
	bling_done_w.custom_minimum_size = Vector2(640, 80)
	bling_done_w.add_child(bling_done_btn)
	bling_reaction.add_child(bling_done_w)

	# Options wrapper
	var bling_options := VBoxContainer.new()
	bling_options.add_theme_constant_override("separation", 10)
	bling_options.custom_minimum_size = Vector2(640, 0)

	# Determine costs (cheapest: Alan covers if player is broke)
	var bling_cheap_cost: int = 1000 if CareerState.money >= 1000 else 0

	# Purchase handler
	var _do_bling = func(cost_pence: int, tier_name: String):
		if cost_pence > CareerState.money:
			return  # Can't afford — do nothing
		if cost_pence > 0:
			CareerState.money -= cost_pence
			_update_balance_overlay()
		CareerState.shopping_spree_done = true
		CareerState.recalculate_swagger()
		bling_options.visible = false
		bling_desc.visible = false
		var reaction: String
		if tier_name == "cheap":
			reaction = "\"Knew you'd go cheap. Still looks class though.\""
		elif tier_name == "mid":
			reaction = "\"Good call. Looks proper, that.\""
		else:
			reaction = "\"Get you! Going full celebrity.\""
		bling_reaction_label.text = reaction
		bling_reaction.visible = true

	# Build option panels
	var bling_tiers := [
		{"name": "cheap", "title": "ON THE CHEAP", "cost": bling_cheap_cost, "desc": "Alan's bloke. Kitchen table. Cash only.", "col": Color(0.45, 0.35, 0.15)},
		{"name": "mid", "title": "DECENT STUDIO", "cost": 2500, "desc": "Clean needles. Proper portfolio.", "col": Color(0.2, 0.35, 0.5)},
		{"name": "pro", "title": "THE FULL WORKS", "cost": 4000, "desc": "Top parlour. The real deal.", "col": Color(0.5, 0.2, 0.35)},
	]

	for tier in bling_tiers:
		var opt_panel := PanelContainer.new()
		var opt_style := StyleBoxFlat.new()
		opt_style.bg_color = tier["col"]
		opt_style.corner_radius_top_left = 12
		opt_style.corner_radius_top_right = 12
		opt_style.corner_radius_bottom_left = 12
		opt_style.corner_radius_bottom_right = 12
		opt_style.content_margin_left = 18
		opt_style.content_margin_right = 18
		opt_style.content_margin_top = 12
		opt_style.content_margin_bottom = 12
		opt_panel.add_theme_stylebox_override("panel", opt_style)
		opt_panel.custom_minimum_size = Vector2(500, 0)
		opt_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var opt_vbox := VBoxContainer.new()
		opt_vbox.add_theme_constant_override("separation", 4)
		var opt_title := Label.new()
		var tier_cost: int = tier["cost"]
		if tier_cost > 0:
			opt_title.text = tier["title"] + " — " + _format_money(tier_cost)
		else:
			opt_title.text = tier["title"] + " — FREE"
		UIFont.apply(opt_title, UIFont.BODY)
		opt_title.add_theme_color_override("font_color", Color.WHITE)
		opt_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		opt_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		opt_title.custom_minimum_size = Vector2(460, 0)
		opt_vbox.add_child(opt_title)
		var opt_desc := Label.new()
		opt_desc.text = tier["desc"]
		if tier_cost > CareerState.money and tier["name"] != "cheap":
			opt_desc.text += " (Can't afford)"
			opt_style.bg_color = Color(0.2, 0.2, 0.2)
		UIFont.apply(opt_desc, UIFont.CAPTION)
		opt_desc.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.7))
		opt_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		opt_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		opt_desc.custom_minimum_size = Vector2(460, 0)
		opt_vbox.add_child(opt_desc)
		opt_panel.add_child(opt_vbox)
		var opt_center := CenterContainer.new()
		opt_center.custom_minimum_size = Vector2(640, 0)
		opt_center.add_child(opt_panel)
		bling_options.add_child(opt_center)
		var t_name: String = tier["name"]
		var t_cost: int = tier_cost
		opt_panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				_do_bling.call(t_cost, t_name)
		)
		opt_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	bling_card.add_child(bling_options)
	bling_card.add_child(bling_reaction)

	_add_card(bling_card, "L2 Tattoos & Bling")

	# Card 7: Swagger star 1->2 (tattoos & bling done — all four at 2, IMAGE CHANGE!)
	_build_star_flip_card("SWAGGER", CareerState.swagger_stars, CareerState.swagger_stars + 1, "Looking dangerous.", func(): CareerState.recalculate_swagger())

	# Card 7: Mate introduces Steve
	var steve_intro := _create_card()
	_add_spacer(steve_intro, 60)
	var steve_panel := _build_companion_panel(
		"ALAN",
		"There's a regional comp next month. It's a bit of a journey - train ride to the venue.\n\nYou're up against Steve 'The Sparky'. Wirey old chap this one. Get it?\n\nI'll bring a few mates down, they're a lively bunch.\n\nBest of seven this time. First to four legs.",
		Color.BLACK, "", "res://Mate for Level 2 - Alan.png", UIFont.PORTRAIT_XL
	)
	steve_intro.add_child(steve_panel)
	_add_spacer(steve_intro, 30)
	_add_continue_button(steve_intro)
	_add_card(steve_intro, "L2 Steve Intro")

	# Mates joining — Alan brings the group along
	var mates_card := _create_card()
	_add_spacer(mates_card, 60)
	var mates_panel := _build_companion_panel(
		"THE MATES",
		"Excited by your emerging success, Alan ropes three other mates along.\n\nProper darts fans, this lot.",
		Color.BLACK, "", "res://Group of mates for Level 3 better trimmed.png", UIFont.PORTRAIT_XL
	)
	mates_card.add_child(mates_panel)
	_add_spacer(mates_card, 30)
	_add_continue_button(mates_card)
	_add_card(mates_card, "L2 Mates Joining")

	# Dart shop
	_build_dart_shop_card()

	# Card 7: Bridge card
	var next_venue: String = OpponentData.get_venue("steve", GameState.character)
	_build_bridge_card(
		"",
		next_venue,
		"Proper oche. Small stage. Folding chairs for fifty. A commentator with a microphone.",
		2000
	)

	# Pre-match drinking
	_build_pre_drink_card()

	# Card 8: Steve stats
	_build_opponent_stats_card(
		"steve", "Steve", "The Sparky",
		{"SKILL": 3, "HEFT": 2, "HUSTLE": 2, "SWAGGER": 1},
		"101, Best of 7"
	)

# ======================================================
# LEVEL 3 POST-WIN (Beat Steve "The Sparky")
# ======================================================

func _build_l3_win_cards() -> void:
	# Skill star 2->3 (first — you've just won)
	_build_star_flip_card("SKILL", CareerState.skill_stars, CareerState.skill_stars + 1, "Regional champion.\nPeople are talking.", func(): CareerState.skill_stars += 1)

	# Choose your celebration
	var celeb_card := _create_card()
	_add_spacer(celeb_card, 80)
	var celeb_title := Label.new()
	celeb_title.text = "CHOOSE YOUR\nCELEBRATION"
	UIFont.apply(celeb_title, UIFont.HEADING)
	celeb_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	celeb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	celeb_title.custom_minimum_size = Vector2(640, 100)
	celeb_card.add_child(celeb_title)
	_add_spacer(celeb_card, 15)
	var celeb_desc := Label.new()
	celeb_desc.text = "Every champion needs a signature move.\nPick one. Own it."
	UIFont.apply(celeb_desc, UIFont.BODY)
	celeb_desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	celeb_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	celeb_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	celeb_desc.custom_minimum_size = Vector2(640, 60)
	celeb_card.add_child(celeb_desc)
	_add_spacer(celeb_card, 30)

	var _set_celebration := func(style: int):
		CareerState.celebration_style = style
		CareerState.recalculate_swagger()
		_advance_card()

	var flex_btn := _create_button("THE FLEX", Color(0.4, 0.15, 0.15), Color(0.7, 0.3, 0.3))
	flex_btn.pressed.connect(func(): _set_celebration.call(0))
	var flex_w := CenterContainer.new()
	flex_w.custom_minimum_size = Vector2(640, 80)
	flex_w.add_child(flex_btn)
	celeb_card.add_child(flex_w)
	var flex_sub := Label.new()
	flex_sub.text = "Arms out. Muscles tense. Pure power."
	UIFont.apply(flex_sub, UIFont.CAPTION)
	flex_sub.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	flex_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flex_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flex_sub.custom_minimum_size = Vector2(640, 30)
	celeb_card.add_child(flex_sub)
	_add_spacer(celeb_card, 25)

	var fish_btn := _create_button("REEL IN THE FISH", Color(0.15, 0.15, 0.4), Color(0.3, 0.3, 0.7))
	fish_btn.custom_minimum_size = Vector2(600, 90)
	fish_btn.add_theme_font_size_override("font_size", 40)
	fish_btn.pressed.connect(func(): _set_celebration.call(1))
	var fish_w := CenterContainer.new()
	fish_w.custom_minimum_size = Vector2(640, 80)
	fish_w.add_child(fish_btn)
	celeb_card.add_child(fish_w)
	var fish_sub := Label.new()
	fish_sub.text = "Mime reeling one in. The crowd goes wild."
	UIFont.apply(fish_sub, UIFont.CAPTION)
	fish_sub.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	fish_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fish_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fish_sub.custom_minimum_size = Vector2(640, 30)
	celeb_card.add_child(fish_sub)
	_add_spacer(celeb_card, 25)

	var pint_btn := _create_button("DOWN A PINT", Color(0.35, 0.25, 0.1), Color(0.6, 0.45, 0.2))
	pint_btn.pressed.connect(func(): _set_celebration.call(2))
	var pint_w := CenterContainer.new()
	pint_w.custom_minimum_size = Vector2(640, 80)
	pint_w.add_child(pint_btn)
	celeb_card.add_child(pint_w)
	var pint_sub := Label.new()
	pint_sub.text = "Skull a pint on the oche. Costs a drink."
	UIFont.apply(pint_sub, UIFont.CAPTION)
	pint_sub.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	pint_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pint_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pint_sub.custom_minimum_size = Vector2(640, 30)
	celeb_card.add_child(pint_sub)
	_add_card(celeb_card, "L3 Celebration Choice")

	# Swagger star flip (celebration style)
	_build_star_flip_card("SWAGGER", CareerState.swagger_stars, CareerState.swagger_stars + 1, "Signature move unlocked.\nOwn it.", func(): CareerState.recalculate_swagger())

	# Steve angry about celebrating in his face
	var steve_card := _create_card()
	_add_spacer(steve_card, 60)
	var steve_panel := _build_companion_panel(
		"STEVE",
		"Steve shakes his head.\n\n\"Three years I've had that title. Three years. And you're celebrating in my face?\"\n\nHe squares up.\n\n\"It's not that sort of game.\"",
		Color.BLACK, "", "res://Steve The Sparky cropped.png", UIFont.PORTRAIT_XL
	)
	steve_card.add_child(steve_panel)
	_add_spacer(steve_card, 30)
	_add_continue_button(steve_card)
	_add_card(steve_card, "L3 Steve Dialogue")

	# Food card: Winner's buffet at the venue
	_build_food_card("BUFFET", "The venue puts on a spread for the winner.\nSandwiches, sausage rolls, crisps.\nTuck in?", "TUCK IN", 0, "Buffet demolished.\nProfessional fuel.", 3)

	var char_first: String = DartData.get_character_name(GameState.character)
	var char_nick: String = DartData.get_character_nickname(GameState.character)
	var _inflatable_item: String = MerchData.get_inflatable_name(GameState.character)
	var _inflatable_title: String = MerchData.get_inflatable_title(GameState.character)
	var son_or_love: String = "love" if DartData.get_is_female(GameState.character) else "son"

	# Alan handoff — passes companionship to the coach
	var alan_handoff := _create_card()
	_add_spacer(alan_handoff, 60)
	var alan_panel := _build_companion_panel(
		"ALAN",
		"Alan catches you before you leave.\n\n\"Listen, mate. I've taken you as far as I can. But you've got real potential.\"\n\n\"I've hooked you up with a coach. Former pro. He was watching you tonight. He believes in you.\"",
		Color(0.2, 0.3, 0.5), "A", "res://Mate for Level 2 - Alan.png", UIFont.PORTRAIT_ML
	)
	alan_handoff.add_child(alan_panel)
	_add_spacer(alan_handoff, 30)
	_add_continue_button(alan_handoff)
	_add_card(alan_handoff, "L3 Alan Handoff")

	# Coach approaches — gives nickname
	var nick_card := _create_card()
	_add_spacer(nick_card, 60)
	var nick_panel := _build_companion_panel(
		"THE COACH",
		"The coach walks over.\n\n\"Saw your game tonight. The crowd need a name to chant.\"\n\n\"'" + char_nick + "'. That's you from now on. Own it.\"",
		Color(0.15, 0.35, 0.2), "C", "res://Coach cropped.png", UIFont.PORTRAIT_L
	)
	nick_card.add_child(nick_panel)
	_add_spacer(nick_card, 30)
	var nick_btn := _create_button("OWN IT", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5))
	nick_btn.pressed.connect(func():
		CareerState.nickname_active = true
		_advance_card()
	)
	var nick_wrapper := CenterContainer.new()
	nick_wrapper.custom_minimum_size = Vector2(640, 100)
	nick_wrapper.add_child(nick_btn)
	nick_card.add_child(nick_wrapper)
	_add_card(nick_card, "L3 Coach Nickname")

	# Car park encounter — The Trader references the nickname + inflatables
	var trader_card := _create_card()
	_add_spacer(trader_card, 60)
	var trader_panel := _build_companion_panel(
		"THE TRADER",
		"A bloke in a hi-vis catches you in the car park.\n\n\"I hear they're calling you '" + char_nick + "' now. Love it.\"\n\nHe opens the back of a van. Giant inflatable " + _inflatable_item + ".\n\n\"Quid each, minimum ten. The more you shift, the cheaper they get.\"",
		Color(0.7, 0.7, 0.1), "T", "res://The Trader cropped.png", UIFont.PORTRAIT_ML
	)
	trader_card.add_child(trader_panel)
	_add_spacer(trader_card, 30)
	var trader_continue := _create_button("CONTINUE", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5))
	trader_continue.pressed.connect(func():
		CareerState.trader_met = true
		_advance_card()
	)
	var trader_wrapper := CenterContainer.new()
	trader_wrapper.custom_minimum_size = Vector2(640, 100)
	trader_wrapper.add_child(trader_continue)
	trader_card.add_child(trader_wrapper)
	_add_card(trader_card, "L3 Trader")

	# ── Trader forced merch purchase — +/- counter UI (minimum 10) ──
	var merch_buy_card := _create_card()
	_add_spacer(merch_buy_card, 420)
	var merch_quote := Label.new()
	merch_quote.text = "\"Right, how many " + _inflatable_item + " are you having?\""
	UIFont.apply(merch_quote, UIFont.BODY)
	merch_quote.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	merch_quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	merch_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	merch_quote.custom_minimum_size = Vector2(640, 0)
	merch_buy_card.add_child(merch_quote)
	_add_spacer(merch_buy_card, 20)
	var _calc_merch_cost_l3 = func(qty: int) -> int:
		var total := 0
		var base := CareerState.inflatables_total_bought
		for b in range(qty / 10):
			var step := int((base + b * 10) / 10)
			total += int(100.0 * pow(0.95, step)) * 10
		return total
	var merch_qty := [10]
	var qty_row := HBoxContainer.new()
	qty_row.add_theme_constant_override("separation", 0)
	qty_row.custom_minimum_size = Vector2(640, 80)
	qty_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var minus_btn := _create_button("-", Color(0.5, 0.15, 0.15), Color(0.8, 0.3, 0.3))
	minus_btn.custom_minimum_size = Vector2(100, 70)
	qty_row.add_child(minus_btn)
	var qty_label := Label.new()
	qty_label.text = str(merch_qty[0])
	UIFont.apply(qty_label, UIFont.DISPLAY)
	qty_label.add_theme_color_override("font_color", Color.WHITE)
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_label.custom_minimum_size = Vector2(200, 70)
	qty_row.add_child(qty_label)
	var plus_btn := _create_button("+", Color(0.15, 0.5, 0.15), Color(0.3, 0.8, 0.3))
	plus_btn.custom_minimum_size = Vector2(100, 70)
	qty_row.add_child(plus_btn)
	var qty_center := CenterContainer.new()
	qty_center.custom_minimum_size = Vector2(640, 80)
	qty_center.add_child(qty_row)
	merch_buy_card.add_child(qty_center)
	_add_spacer(merch_buy_card, 10)
	var merch_cost_label := Label.new()
	merch_cost_label.text = "Cost: " + _format_money(_calc_merch_cost_l3.call(10))
	UIFont.apply(merch_cost_label, UIFont.BODY)
	merch_cost_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
	merch_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	merch_cost_label.custom_minimum_size = Vector2(640, 40)
	merch_buy_card.add_child(merch_cost_label)
	var merch_warn := Label.new()
	merch_warn.text = ""
	UIFont.apply(merch_warn, UIFont.CAPTION)
	merch_warn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	merch_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	merch_warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	merch_warn.custom_minimum_size = Vector2(640, 0)
	merch_buy_card.add_child(merch_warn)
	_add_spacer(merch_buy_card, 15)
	var _refresh_merch := func():
		qty_label.text = str(merch_qty[0])
		var cost: int = _calc_merch_cost_l3.call(merch_qty[0])
		if CareerState.money < cost:
			merch_cost_label.text = "FREE (companion's covering it)"
			merch_cost_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4))
		else:
			merch_cost_label.text = "Cost: " + _format_money(cost)
			merch_cost_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
		var remaining: int = CareerState.money - cost
		if remaining >= 0 and remaining < 3000 and cost > 0:
			merch_warn.text = "That won't leave much for drinking..."
		else:
			merch_warn.text = ""
		minus_btn.disabled = merch_qty[0] <= 10
	minus_btn.pressed.connect(func():
		if merch_qty[0] > 10:
			merch_qty[0] -= 10
			_refresh_merch.call()
	)
	plus_btn.pressed.connect(func():
		merch_qty[0] += 10
		_refresh_merch.call()
	)
	_refresh_merch.call()
	var merch_buy_btn := _create_button("BUY", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	var merch_buy_w := CenterContainer.new()
	merch_buy_w.custom_minimum_size = Vector2(640, 80)
	merch_buy_w.add_child(merch_buy_btn)
	merch_buy_card.add_child(merch_buy_w)
	var merch_reaction := VBoxContainer.new()
	merch_reaction.visible = false
	merch_reaction.add_theme_constant_override("separation", 15)
	merch_reaction.custom_minimum_size = Vector2(640, 0)
	var merch_reaction_label := Label.new()
	UIFont.apply(merch_reaction_label, UIFont.BODY)
	merch_reaction_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	merch_reaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	merch_reaction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	merch_reaction_label.custom_minimum_size = Vector2(640, 0)
	merch_reaction.add_child(merch_reaction_label)
	var merch_done_btn := _create_button("CONTINUE", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5))
	merch_done_btn.pressed.connect(_advance_card)
	var merch_done_w := CenterContainer.new()
	merch_done_w.custom_minimum_size = Vector2(640, 80)
	merch_done_w.add_child(merch_done_btn)
	merch_reaction.add_child(merch_done_w)
	merch_buy_card.add_child(merch_reaction)
	merch_buy_btn.pressed.connect(func():
		var qty: int = merch_qty[0]
		var cost: int = _calc_merch_cost_l3.call(qty)
		if CareerState.money < cost:
			cost = 0
		if cost > 0:
			CareerState.money -= cost
			_update_balance_overlay()
		CareerState.inflatables_stock += qty
		CareerState.inflatables_total_bought += qty
		merch_quote.visible = false
		qty_center.visible = false
		merch_cost_label.visible = false
		merch_warn.visible = false
		merch_buy_w.visible = false
		var reaction: String
		if qty <= 10:
			reaction = "\"Just ten? Not much of a risk-taker, are you...\""
		elif qty <= 30:
			reaction = "\"Now you're talking. Should shift those nicely.\""
		elif qty <= 100:
			reaction = "\"Big spender! The crowd are going to love these.\""
		else:
			reaction = "\"Blimey! You've bought the whole van!\""
		if CareerState.money < 3000 and cost > 0:
			reaction += "\n\n\"And, er... remember you'll need some cash for drinking.\""
		merch_reaction_label.text = reaction
		merch_reaction.visible = true
	)
	_add_card(merch_buy_card, "L3 Merch Buy")

	# Card 7: Coach decision (forced — player cannot skip)
	var hire_card := _create_card()
	var coach_actual_cost: int = 5000 if CareerState.money >= 5000 else 0

	# --- Original group ---
	var coach_original := VBoxContainer.new()
	coach_original.add_theme_constant_override("separation", 0)
	_add_spacer(coach_original, 120)
	var hire_title := Label.new()
	hire_title.text = "HIRE THE COACH?"
	UIFont.apply(hire_title, UIFont.HEADING)
	hire_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	hire_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hire_title.custom_minimum_size = Vector2(640, 70)
	coach_original.add_child(hire_title)
	_add_spacer(coach_original, 20)
	var hire_desc := Label.new()
	hire_desc.text = "The county tournament's a different beast.\nCheckout hints during matches.\nPre-match strategy.\nSomeone in your corner who knows\nwhat they're doing."
	UIFont.apply(hire_desc, UIFont.BODY)
	hire_desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	hire_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hire_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hire_desc.custom_minimum_size = Vector2(640, 100)
	coach_original.add_child(hire_desc)
	_add_spacer(coach_original, 10)
	var hire_cost := Label.new()
	hire_cost.text = ("Cost: " + _format_money(coach_actual_cost)) if coach_actual_cost > 0 else "FREE (Alan's covering it)"
	UIFont.apply(hire_cost, UIFont.BODY)
	hire_cost.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3) if coach_actual_cost > 0 else Color(0.3, 0.8, 0.4))
	hire_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hire_cost.custom_minimum_size = Vector2(640, 40)
	coach_original.add_child(hire_cost)
	_add_spacer(coach_original, 30)
	var hire_yes := _create_button("HIRE HIM", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	var hire_yes_w := CenterContainer.new()
	hire_yes_w.custom_minimum_size = Vector2(640, 100)
	hire_yes_w.add_child(hire_yes)
	coach_original.add_child(hire_yes_w)
	_add_spacer(coach_original, 10)
	var hire_no := _create_button("I'LL MANAGE", Color(0.2, 0.2, 0.25), Color(0.4, 0.4, 0.45))
	var hire_no_w := CenterContainer.new()
	hire_no_w.custom_minimum_size = Vector2(640, 100)
	hire_no_w.add_child(hire_no)
	coach_original.add_child(hire_no_w)
	hire_card.add_child(coach_original)

	# --- Coach insistence group ---
	var coach_insist_group := VBoxContainer.new()
	coach_insist_group.add_theme_constant_override("separation", 0)
	coach_insist_group.visible = false
	_add_spacer(coach_insist_group, 60)
	var coach_insist_data: Dictionary = HIRE_INSISTENCE["coach"]
	var coach_insist_panel := _build_companion_panel(
		coach_insist_data["speaker"],
		"\"" + coach_insist_data["first"] + "\"",
		coach_insist_data["color"], coach_insist_data["initial"], coach_insist_data["image"], UIFont.PORTRAIT_XL
	)
	coach_insist_group.add_child(coach_insist_panel)
	_add_spacer(coach_insist_group, 30)
	var coach_ok_btn := _create_button("OK", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5))
	var coach_ok_w := CenterContainer.new()
	coach_ok_w.custom_minimum_size = Vector2(640, 100)
	coach_ok_w.add_child(coach_ok_btn)
	coach_insist_group.add_child(coach_ok_w)
	hire_card.add_child(coach_insist_group)

	var coach_decline := [0]

	var _do_hire_coach := func():
		if coach_actual_cost > 0:
			CareerState.money -= coach_actual_cost
			_update_balance_overlay()
		CareerState.coach_hired = true
		var old_hustle: int = CareerState.hustle_stars
		CareerState.recalculate_hustle()
		if CareerState.hustle_stars > old_hustle:
			_advance_card()
		else:
			if _current_card + 2 < _cards.size():
				_show_card(_current_card + 2)
			else:
				_advance_card()

	hire_yes.pressed.connect(func(): _do_hire_coach.call())

	hire_no.pressed.connect(func():
		coach_decline[0] += 1
		if coach_decline[0] == 1:
			coach_original.visible = false
			coach_insist_group.visible = true
		else:
			_do_hire_coach.call()
	)

	coach_ok_btn.pressed.connect(func():
		coach_insist_group.visible = false
		coach_original.visible = true
	)

	_add_card(hire_card, "L3 Coach Decision")

	# Card 8: Hustle star (only if compound condition met: coach + merch bought)
	_build_star_flip_card("HUSTLE", CareerState.hustle_stars, CareerState.hustle_stars + 1, "Going professional.", null)

	# Dart shop
	_build_dart_shop_card()

	# Card 9: Bridge card
	_build_bridge_card(
		"",
		"County Darts Club",
		"Lighting rig. Raised oche. Sponsor banners. Two hundred in the crowd. Regional TV cameras.",
		7500
	)

	# Coach scouting report on Edward
	var scout_card := _create_card()
	_add_spacer(scout_card, 60)
	var scout_panel := _build_companion_panel(
		"THE COACH",
		"\"Right. Edward. They call him The Accountant.\"\n\nHe lowers his voice.\n\n\"Bit special, this lad. This chap is big in oil. Runs his own jewellery workshop. We just call him The Accountant.\"",
		Color(0.15, 0.35, 0.2), "C", "res://Coach cropped.png", UIFont.PORTRAIT_L
	)
	scout_card.add_child(scout_panel)
	_add_spacer(scout_card, 30)
	_add_continue_button(scout_card)
	_add_card(scout_card, "L3 Coach Scouting Edward")

	# Pre-match drinking
	_build_pre_drink_card()

	# Card 10: Edward stats
	_build_opponent_stats_card(
		"philip", "Edward", "The Accountant",
		{"SKILL": 4, "HEFT": 2, "HUSTLE": 3, "SWAGGER": 2},
		"301, Best of 5"
	)

# ======================================================
# LEVEL 4 POST-WIN (Beat Edward "The Accountant")
# ======================================================

func _build_l4_win_cards() -> void:
	# Post-match celebration — Edward laughs it off
	_build_celebration_reaction_card(
		"EDWARD",
		"Edward watches your celebration.\n\nHe laughs.\n\n\"Pathetic.\"\n\nHe shakes his head, packs his darts away, and leaves without another word.",
		"res://Edward The Accountant cropped.png"
	)

	# Card 2: Skill star 3->4
	_build_star_flip_card("SKILL", CareerState.skill_stars, CareerState.skill_stars + 1, "County champion.\nThe phone's ringing.", func(): CareerState.skill_stars += 1)

	# Food card: Steak dinner (manager's treat — free)
	_build_food_card("STEAK DINNER", "The manager takes you out to celebrate.\nFillet steak, chips, peppercorn sauce.\nHer treat.", "ORDER STEAK", 0, "Steak and chips.\nThis is the life.", 4)

	# Manager buildup — seductive typewriter reveal, no image, no header
	var mgr_buildup := _create_card()
	_add_spacer(mgr_buildup, 120)
	var buildup_lines: Array[String] = [
		"A sharp-suited woman approaches your table.",
		"Gorgeous hair.",
		"Beautiful soft skin.",
		"Stunning jewellery.",
		"Delicious perfume. Not even from the market.",
		"And then she says...",
	]
	var buildup_labels: Array[Label] = []
	for line_text in buildup_lines:
		var lbl := Label.new()
		lbl.text = line_text
		UIFont.apply(lbl, UIFont.BODY)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.custom_minimum_size = Vector2(600, 0)
		lbl.visible_ratio = 0.0
		mgr_buildup.add_child(lbl)
		_add_spacer(mgr_buildup, 20)
		buildup_labels.append(lbl)
	_add_spacer(mgr_buildup, 20)
	var buildup_btn_wrapper := CenterContainer.new()
	buildup_btn_wrapper.custom_minimum_size = Vector2(640, 100)
	var buildup_btn := _create_button("CONTINUE", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5))
	buildup_btn.pressed.connect(_advance_card)
	buildup_btn_wrapper.add_child(buildup_btn)
	buildup_btn_wrapper.modulate.a = 0.0
	mgr_buildup.add_child(buildup_btn_wrapper)
	_add_card(mgr_buildup, "L4 Manager Buildup")

	# Deferred animation — typewriter reveal line by line
	var buildup_card_idx := _cards.size() - 1
	var _buildup_labels := buildup_labels
	var _buildup_btn_wrapper := buildup_btn_wrapper
	_card_animations[buildup_card_idx] = func():
		var tw := create_tween()
		var delay := 0.0
		for i in range(_buildup_labels.size()):
			var lbl: Label = _buildup_labels[i]
			var char_count: int = lbl.text.length()
			var type_speed := 0.025  # seconds per character — snappy
			var line_duration: float = char_count * type_speed
			tw.tween_property(lbl, "visible_ratio", 1.0, line_duration).set_delay(delay)
			if i == 0:
				delay = 0.6  # beat after opening line
			else:
				delay = 0.4  # quick beat between description lines
		# Show CONTINUE after last line finishes
		tw.tween_property(_buildup_btn_wrapper, "modulate:a", 1.0, 0.3).set_delay(0.5)

	# Manager reveal (companion panel — the reality)
	var mgr_intro := _create_card()
	_add_spacer(mgr_intro, 60)
	var mgr_panel := _build_companion_panel(
		"THE MANAGER",
		"\"I manage fighters. Boxers mostly. Started dabbling with the greyhounds as well. But I know talent when I see it.\"\n\nShe says, in a deep Yorkshire accent.\n\nShe slides a card across.\n\n\"Call me when you're ready to take this seriously.\"",
		Color(0.4, 0.15, 0.25), "S", "res://Manager cropped new.png", UIFont.PORTRAIT_L
	)
	mgr_intro.add_child(mgr_panel)
	_add_spacer(mgr_intro, 30)
	_add_continue_button(mgr_intro)
	_add_card(mgr_intro, "L4 Manager Intro")

	# Card 4: Manager decision — percentage of winnings model (forced)
	var mgr_card := _create_card()

	var _do_hire_manager := func():
		CareerState.manager_hired = true
		var old_hustle: int = CareerState.hustle_stars
		CareerState.recalculate_hustle()
		if CareerState.hustle_stars > old_hustle:
			_advance_card()
		else:
			if _current_card + 2 < _cards.size():
				_show_card(_current_card + 2)
			else:
				_advance_card()

	# --- First offer: 20% of winnings ---
	var mgr_offer1 := VBoxContainer.new()
	mgr_offer1.add_theme_constant_override("separation", 0)
	_add_spacer(mgr_offer1, 80)
	var mgr_title := Label.new()
	mgr_title.text = "HIRE THE MANAGER?"
	UIFont.apply(mgr_title, UIFont.HEADING)
	mgr_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	mgr_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mgr_title.custom_minimum_size = Vector2(640, 70)
	mgr_offer1.add_child(mgr_title)
	_add_spacer(mgr_offer1, 15)
	var mgr_desc := Label.new()
	mgr_desc.text = "Sponsorship deals. Better money.\nSomeone to handle the business side\nso you can focus on the darts."
	UIFont.apply(mgr_desc, UIFont.BODY)
	mgr_desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	mgr_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mgr_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mgr_desc.custom_minimum_size = Vector2(640, 80)
	mgr_offer1.add_child(mgr_desc)
	_add_spacer(mgr_offer1, 10)
	var mgr_terms := Label.new()
	mgr_terms.text = "Her terms: 20% of your winnings."
	UIFont.apply(mgr_terms, UIFont.BODY)
	mgr_terms.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
	mgr_terms.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mgr_terms.custom_minimum_size = Vector2(640, 40)
	mgr_offer1.add_child(mgr_terms)
	_add_spacer(mgr_offer1, 25)
	var mgr_accept1 := _create_button("20% IT IS", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	var mgr_accept1_w := CenterContainer.new()
	mgr_accept1_w.custom_minimum_size = Vector2(640, 90)
	mgr_accept1_w.add_child(mgr_accept1)
	mgr_offer1.add_child(mgr_accept1_w)
	_add_spacer(mgr_offer1, 10)
	var mgr_decline1 := _create_button("NOT YET", Color(0.2, 0.2, 0.25), Color(0.4, 0.4, 0.45))
	var mgr_decline1_w := CenterContainer.new()
	mgr_decline1_w.custom_minimum_size = Vector2(640, 90)
	mgr_decline1_w.add_child(mgr_decline1)
	mgr_offer1.add_child(mgr_decline1_w)
	mgr_card.add_child(mgr_offer1)

	# --- Second offer: 10% or else ---
	var mgr_offer2 := VBoxContainer.new()
	mgr_offer2.add_theme_constant_override("separation", 0)
	mgr_offer2.visible = false
	_add_spacer(mgr_offer2, 60)
	var mgr_panel2 := _build_companion_panel(
		"THE MANAGER",
		"She calls back the next day.\n\n\"Fine. Ten percent. Final offer.\"\n\nA long pause.\n\n\"Or I send someone round to break your legs.\"",
		Color(0.4, 0.15, 0.25), "S", "res://Manager cropped new.png", UIFont.PORTRAIT_L
	)
	mgr_offer2.add_child(mgr_panel2)
	_add_spacer(mgr_offer2, 25)
	var mgr_accept2 := _create_button("10%. DEAL.", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	var mgr_accept2_w := CenterContainer.new()
	mgr_accept2_w.custom_minimum_size = Vector2(640, 90)
	mgr_accept2_w.add_child(mgr_accept2)
	mgr_offer2.add_child(mgr_accept2_w)
	_add_spacer(mgr_offer2, 10)
	var mgr_decline2 := _create_button("BREAK MY LEGS", Color(0.4, 0.15, 0.15), Color(0.7, 0.3, 0.3))
	var mgr_decline2_w := CenterContainer.new()
	mgr_decline2_w.custom_minimum_size = Vector2(640, 90)
	mgr_decline2_w.add_child(mgr_decline2)
	mgr_offer2.add_child(mgr_decline2_w)
	mgr_card.add_child(mgr_offer2)

	mgr_accept1.pressed.connect(func(): _do_hire_manager.call())
	mgr_accept2.pressed.connect(func(): _do_hire_manager.call())

	mgr_decline1.pressed.connect(func():
		mgr_offer1.visible = false
		mgr_offer2.visible = true
	)
	mgr_decline2.pressed.connect(func():
		# She sends someone round... but you still get the manager
		_do_hire_manager.call()
	)

	_add_card(mgr_card, "L4 Manager Decision")

	# Card 5: Hustle star (only if compound condition met: manager + merch sold)
	_build_star_flip_card("HUSTLE", CareerState.hustle_stars, CareerState.hustle_stars + 1, "Big time.", null)

	# Coach endorses the manager — reassures player he's still around
	var son_or_love_l4: String = "love" if DartData.get_is_female(GameState.character) else "son"
	var coach_endorse := _create_card()
	_add_spacer(coach_endorse, 60)
	var endorse_panel := _build_companion_panel(
		"THE COACH",
		"The coach catches your eye.\n\n\"Good choice, " + son_or_love_l4 + ". She knows what she's doing.\"\n\nHe folds his arms.\n\n\"I'll still be right here, coaching you on the oche. But off the oche? You're in great hands now.\"",
		Color(0.15, 0.35, 0.2), "C", "res://Coach cropped.png", UIFont.PORTRAIT_L
	)
	coach_endorse.add_child(endorse_panel)
	_add_spacer(coach_endorse, 30)
	_add_continue_button(coach_endorse)
	_add_card(coach_endorse, "L4 Coach Endorses Manager")

	# Card: Manager motivational speech (sets up silk shirt)
	var motiv_card := _create_card()
	_add_spacer(motiv_card, 40)
	var motiv_panel := _build_companion_panel(
		"THE MANAGER",
		"She sits you down.\n\n\"Right. I don't do losers. Fitness. Nutrition. Image. Sponsors. I handle all of it.\"\n\n\"The Arrow Palace. That's where we're heading. You're not walking in there looking like a pub player.\"\n\n\"Let's get you in some proper silks.\"",
		Color(0.4, 0.15, 0.25), "S", "res://Manager cropped new.png", UIFont.PORTRAIT_L
	)
	motiv_card.add_child(motiv_panel)
	_add_spacer(motiv_card, 20)
	_add_continue_button(motiv_card)
	_add_card(motiv_card, "L4 Manager Motivational")

	# Card: Silk shirt from the manager (Swagger star 3)
	var silk_card := _create_card()
	_add_spacer(silk_card, 60)
	var silk_panel := _build_companion_panel(
		"THE MANAGER",
		"She's waiting outside with a garment bag.\n\n\"If you're going on TV, you're not wearing that.\"\n\nShe elegantly lifts out a designer silk shirt.\n\n\"Consider it an investment.\"",
		Color(0.4, 0.15, 0.25), "S", "res://Manager cropped new.png", UIFont.PORTRAIT_XL
	)
	silk_card.add_child(silk_panel)
	_add_spacer(silk_card, 30)
	var silk_btn := _create_button("PUT IT ON", Color(0.3, 0.15, 0.35), Color(0.5, 0.3, 0.6))
	silk_btn.pressed.connect(func():
		CareerState.silk_shirt_received = true
		CareerState.recalculate_swagger()
		_advance_card()
	)
	var silk_w := CenterContainer.new()
	silk_w.custom_minimum_size = Vector2(640, 100)
	silk_w.add_child(silk_btn)
	silk_card.add_child(silk_w)
	_add_card(silk_card, "L4 Silk Shirt")

	# Swagger star flip (silk shirt)
	_build_star_flip_card("SWAGGER", CareerState.swagger_stars, CareerState.swagger_stars + 1, "Looking the part.", func(): CareerState.recalculate_swagger())

	# Card: Unknown Number — phone call about throwing leg 4 vs Mad Dog
	var gamble_card := _create_card()
	_add_spacer(gamble_card, 40)

	# Initial state: phone ringing, two choices
	var ring_panel := _build_companion_panel(
		"UNKNOWN NUMBER",
		"Your phone buzzes. Unknown number.",
		Color(0.3, 0.3, 0.35), "?", "res://The Contact Unknown caller cropped.png", UIFont.PORTRAIT_ML
	)
	gamble_card.add_child(ring_panel)
	_add_spacer(gamble_card, 20)

	var ring_btns := VBoxContainer.new()
	ring_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	ring_btns.add_theme_constant_override("separation", 12)
	var take_btn := _create_button("TAKE THE CALL", Color(0.15, 0.4, 0.2), Color(0.3, 0.7, 0.4))
	var hangup_btn := _create_button("HANG UP", Color(0.4, 0.15, 0.15), Color(0.7, 0.3, 0.3))
	var take_w := CenterContainer.new()
	take_w.custom_minimum_size = Vector2(640, 0)
	take_w.add_child(take_btn)
	ring_btns.add_child(take_w)
	var hangup_w := CenterContainer.new()
	hangup_w.custom_minimum_size = Vector2(640, 0)
	hangup_w.add_child(hangup_btn)
	ring_btns.add_child(hangup_w)
	gamble_card.add_child(ring_btns)

	# ── TAKE THE CALL path ──
	var call_group := VBoxContainer.new()
	call_group.visible = false
	_add_spacer(call_group, 10)
	var call_panel := _build_companion_panel(
		"UNKNOWN NUMBER",
		"\"County champion. Very impressive.\"\n\nA pause.\n\n\"I've got a lot of money on you beating Mad Dog. But I need you to lose the fourth leg.\"\n\n\"Five grand. Cash.\"",
		Color(0.3, 0.3, 0.35), "?", "res://The Contact Unknown caller cropped.png", UIFont.PORTRAIT_S
	)
	call_group.add_child(call_panel)
	_add_spacer(call_group, 15)

	var call_btns := VBoxContainer.new()
	call_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	call_btns.add_theme_constant_override("separation", 12)
	var accept_btn := _create_button("ACCEPT", Color(0.15, 0.4, 0.2), Color(0.3, 0.7, 0.4))
	var decline_btn := _create_button("DECLINE", Color(0.4, 0.15, 0.15), Color(0.7, 0.3, 0.3))
	var accept_w := CenterContainer.new()
	accept_w.custom_minimum_size = Vector2(640, 0)
	accept_w.add_child(accept_btn)
	call_btns.add_child(accept_w)
	var decline_w := CenterContainer.new()
	decline_w.custom_minimum_size = Vector2(640, 0)
	decline_w.add_child(decline_btn)
	call_btns.add_child(decline_w)
	call_group.add_child(call_btns)

	# Decline → forced anyway
	var forced_panel := _build_companion_panel(
		"UNKNOWN NUMBER",
		"\"I'm gonna break your legs anyway, so you might as well take my money.\"\n\nThe line goes dead.",
		Color(0.3, 0.3, 0.35), "?", "", UIFont.PORTRAIT_S
	)
	forced_panel.visible = false
	call_group.add_child(forced_panel)
	_add_spacer(call_group, 10)

	var forced_btn := _create_button("RIGHT THEN", Color(0.3, 0.3, 0.35), Color(0.5, 0.5, 0.55))
	var forced_w := CenterContainer.new()
	forced_w.custom_minimum_size = Vector2(640, 80)
	forced_w.add_child(forced_btn)
	forced_w.visible = false
	call_group.add_child(forced_w)

	gamble_card.add_child(call_group)

	# ── HANG UP path ──
	var vm_group := VBoxContainer.new()
	vm_group.visible = false
	_add_spacer(vm_group, 10)
	var vm_panel := _build_companion_panel(
		"VOICEMAIL",
		"One new voicemail.\n\n\"I've got a lot of money on you beating Mad Dog. But I need you to lose the fourth leg. Five grand. Cash.\"\n\nA pause.\n\n\"Don't make me come find you.\"",
		Color(0.3, 0.3, 0.35), "?", "res://The Contact Unknown caller cropped.png", UIFont.PORTRAIT_S
	)
	vm_group.add_child(vm_panel)
	_add_spacer(vm_group, 10)
	var vm_btn := _create_button("CONTINUE", Color(0.3, 0.3, 0.35), Color(0.5, 0.5, 0.55))
	var vm_w := CenterContainer.new()
	vm_w.custom_minimum_size = Vector2(640, 80)
	vm_w.add_child(vm_btn)
	vm_group.add_child(vm_w)
	gamble_card.add_child(vm_group)

	# ── Button connections ──

	# TAKE THE CALL: show caller dialogue
	take_btn.pressed.connect(func():
		ring_panel.visible = false
		ring_btns.visible = false
		call_group.visible = true
	)

	# HANG UP: show voicemail
	hangup_btn.pressed.connect(func():
		ring_panel.visible = false
		ring_btns.visible = false
		vm_group.visible = true
	)

	# ACCEPT: take the deal, advance
	accept_btn.pressed.connect(func():
		CareerState.throw_leg_required = true
		CareerState.throw_leg_money = 500000
		CareerState.money += 500000
		_update_balance_overlay()
		_advance_card()
	)

	# DECLINE: show forced panel
	decline_btn.pressed.connect(func():
		call_panel.visible = false
		call_btns.visible = false
		forced_panel.visible = true
		forced_w.visible = true
	)

	# RIGHT THEN (forced): same outcome
	forced_btn.pressed.connect(func():
		CareerState.throw_leg_required = true
		CareerState.throw_leg_money = 500000
		CareerState.money += 500000
		_update_balance_overlay()
		_advance_card()
	)

	# VOICEMAIL CONTINUE: same outcome
	vm_btn.pressed.connect(func():
		CareerState.throw_leg_required = true
		CareerState.throw_leg_money = 500000
		CareerState.money += 500000
		_update_balance_overlay()
		_advance_card()
	)

	_add_card(gamble_card, "L4 Unknown Number")

	# Dart shop
	_build_dart_shop_card()

	# Card 7: Bridge card
	_build_bridge_card(
		"",
		"National Qualifying, Milton Keynes",
		"Conference centre. Harsh fluorescent lighting. Five hundred watching. Everyone thinks they're good enough.\n\nWin or bust from here. No second chances.",
		20000
	)

	# Pre-match drinking
	_build_pre_drink_card()

	# Card 8: Mad Dog stats
	_build_opponent_stats_card(
		"mad_dog", "Lisa", "Mad Dog",
		{"SKILL": 3, "HEFT": 3, "HUSTLE": 2, "SWAGGER": 4},
		"301, Best of 7"
	)

# ======================================================
# LEVEL 5 POST-WIN (Beat Mad Dog)
# ======================================================

func _build_l5_win_cards() -> void:
	# Post-match celebration — Mad Dog has to be held back
	_build_celebration_reaction_card(
		"MAD DOG",
		"You celebrate.\n\nMad Dog lunges.\n\nTwo stewards grab her arms. She's growling. Actually growling.\n\n\"I'LL FIND YOU IN THE CAR PARK.\"\n\nThey drag her away. She's still growling.",
		"res://Lisa Mad Dog cropped.jpg"
	)

	# Card 2: Skill star 4->5 (MAX)
	_build_star_flip_card("SKILL", CareerState.skill_stars, 5, "National qualifier.\nFive stars. Maximum.", func(): CareerState.skill_stars = 5)

	# Food card: Massive pasta / carb loading
	_build_food_card("CARB LOADING", "The coach has a plan.\nMassive bowl of pasta. Garlic bread.\nBulking up so people think twice\nabout fighting you.", "LOAD UP", 1500, "Carb loaded.\nNobody's messing with you now.", 5)

	# Sponsor intro
	var sponsor_card := _create_card()
	_add_spacer(sponsor_card, 60)
	var sponsor_panel := _build_companion_panel(
		"THE SPONSOR REP",
		"After the match, a man with a clipboard and a lanyard corners you.\n\n\"Sponsorship opportunity. Big money.\"\n\nHe hands you a card.\n\n\"We'll talk.\"",
		Color(0.1, 0.15, 0.35), "S", "res://Sponsorship Man cropped.png", UIFont.PORTRAIT_L
	)
	sponsor_card.add_child(sponsor_panel)
	_add_spacer(sponsor_card, 30)
	_add_continue_button(sponsor_card)
	_add_card(sponsor_card, "L5 Sponsor Intro")

	# Card: Unknown Number reaction — only if player accepted the throw deal
	if CareerState.throw_leg_required and not CareerState.throw_leg_honoured:
		# Deal broken — angry phone call, then mafia death (career over)
		var angry_card := _create_card()
		_add_spacer(angry_card, 60)
		var angry_panel := _build_companion_panel(
			"UNKNOWN NUMBER",
			"Your phone buzzes.\n\n\"You won the fourth leg.\"\n\nSilence.\n\n\"That wasn't the deal.\"\n\nThe line goes dead.",
			Color(0.5, 0.15, 0.15), "?", "res://The Contact Unknown caller cropped.png", UIFont.PORTRAIT_L
		)
		angry_card.add_child(angry_panel)
		_add_spacer(angry_card, 30)
		_add_continue_button(angry_card)
		_add_card(angry_card, "L5 Deal Broken")
		_build_mafia_death_card()
		return  # Career over — don't build remaining L5 cards

	# Deal honoured — caller is happy (only if player took the deal)
	if CareerState.throw_leg_required and CareerState.throw_leg_honoured:
		var bet_card := _create_card()
		_add_spacer(bet_card, 60)
		var bet_panel := _build_companion_panel(
			"UNKNOWN NUMBER",
			"Your phone buzzes again.\n\n\"Told you Mad Dog was beatable.\"\n\nA pause.\n\n\"Five grand. Leather bag in the boot of your car. No questions asked.\"\n\nAnother pause.\n\n\"Pleasure doing business. You'll never hear from me again.\"",
			Color(0.3, 0.3, 0.35), "?", "res://The Contact Unknown caller cropped.png", UIFont.PORTRAIT_L
		)
		bet_card.add_child(bet_panel)
		_add_spacer(bet_card, 30)
		var bet_btn := _create_button("CONTINUE", Color(0.3, 0.3, 0.35), Color(0.5, 0.5, 0.55))
		bet_btn.pressed.connect(func():
			CareerState.dodgy_bet_won = true
			CareerState.recalculate_swagger()
			_advance_card()
		)
		var bet_w := CenterContainer.new()
		bet_w.custom_minimum_size = Vector2(640, 100)
		bet_w.add_child(bet_btn)
		bet_card.add_child(bet_w)
		_add_card(bet_card, "L5 Deal Honoured")

	# Swagger star flip (dodgy bet)
	_build_star_flip_card("SWAGGER", CareerState.swagger_stars, CareerState.swagger_stars + 1, "Playing both sides.", func(): CareerState.recalculate_swagger())

	# Card: Team decision (forced — player cannot skip)
	var team_card := _create_card()
	var team_actual_cost: int = 50000 if CareerState.money >= 50000 else 0

	# --- Original group ---
	var team_original := VBoxContainer.new()
	team_original.add_theme_constant_override("separation", 0)
	_add_spacer(team_original, 60)
	var team_intro_panel := _build_companion_panel(
		"THE COACH",
		"The coach pulls you aside.\n\n\"The Worlds is a different animal. You need a proper team. Physio. Medic. Someone to keep you alive up there.\"\n\nHe pauses.\n\n\"It's not cheap.\"",
		Color(0.15, 0.35, 0.2), "C", "res://Coach cropped.png", UIFont.PORTRAIT_ML
	)
	team_original.add_child(team_intro_panel)
	_add_spacer(team_original, 10)
	var team_cost := Label.new()
	team_cost.text = ("Cost: " + _format_money(team_actual_cost)) if team_actual_cost > 0 else "FREE (manager's covering it)"
	UIFont.apply(team_cost, UIFont.BODY)
	team_cost.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3) if team_actual_cost > 0 else Color(0.3, 0.8, 0.4))
	team_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	team_cost.custom_minimum_size = Vector2(640, 40)
	team_original.add_child(team_cost)
	_add_spacer(team_original, 20)
	var team_yes := _create_button("BUILD THE TEAM", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	var team_yes_w := CenterContainer.new()
	team_yes_w.custom_minimum_size = Vector2(640, 100)
	team_yes_w.add_child(team_yes)
	team_original.add_child(team_yes_w)
	_add_spacer(team_original, 10)
	var team_no := _create_button("JUST US", Color(0.2, 0.2, 0.25), Color(0.4, 0.4, 0.45))
	var team_no_w := CenterContainer.new()
	team_no_w.custom_minimum_size = Vector2(640, 100)
	team_no_w.add_child(team_no)
	team_original.add_child(team_no_w)
	team_card.add_child(team_original)

	# --- Team insistence group ---
	var team_insist_group := VBoxContainer.new()
	team_insist_group.add_theme_constant_override("separation", 0)
	team_insist_group.visible = false
	_add_spacer(team_insist_group, 60)
	var team_insist_data: Dictionary = HIRE_INSISTENCE["team"]
	var team_insist_panel := _build_companion_panel(
		team_insist_data["speaker"],
		"\"" + team_insist_data["first"] + "\"",
		team_insist_data["color"], team_insist_data["initial"], team_insist_data["image"], UIFont.PORTRAIT_XL
	)
	team_insist_group.add_child(team_insist_panel)
	_add_spacer(team_insist_group, 30)
	var team_ok_btn := _create_button("OK", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5))
	var team_ok_w := CenterContainer.new()
	team_ok_w.custom_minimum_size = Vector2(640, 100)
	team_ok_w.add_child(team_ok_btn)
	team_insist_group.add_child(team_ok_w)
	team_card.add_child(team_insist_group)

	var team_decline := [0]

	var _do_hire_team := func():
		if team_actual_cost > 0:
			CareerState.money -= team_actual_cost
			_update_balance_overlay()
		CareerState.team_hired = true
		var old_hustle: int = CareerState.hustle_stars
		CareerState.recalculate_hustle()
		if CareerState.hustle_stars > old_hustle:
			_advance_card()
		else:
			if _current_card + 2 < _cards.size():
				_show_card(_current_card + 2)
			else:
				_advance_card()

	team_yes.pressed.connect(func(): _do_hire_team.call())

	team_no.pressed.connect(func():
		team_decline[0] += 1
		if team_decline[0] == 1:
			team_original.visible = false
			team_insist_group.visible = true
		else:
			_do_hire_team.call()
	)

	team_ok_btn.pressed.connect(func():
		team_insist_group.visible = false
		team_original.visible = true
	)

	_add_card(team_card, "L5 Team Decision")

	# Card 5: Hustle star (team hire is standalone condition)
	_build_star_flip_card("HUSTLE", CareerState.hustle_stars, CareerState.hustle_stars + 1, "Full support.\nNo excuses.\nA true athlete.", null)

	# Card 6: Doctor hint
	var doc_card := _create_card()
	_add_spacer(doc_card, 60)
	var doc_panel := _build_companion_panel(
		"THE DOCTOR",
		"A woman in a white coat stops you in the corridor. Smart. Professional.\n\n\"I see a lot of darts players come through here. Most of them in worse shape than they think.\"\n\nShe hands you a leaflet.\n\n\"Get checked out before the semis. Trust me.\"",
		Color(0.3, 0.5, 0.35), "D", "res://Doctor cropped.png", UIFont.PORTRAIT_ML
	)
	doc_card.add_child(doc_panel)
	_add_spacer(doc_card, 30)
	_add_continue_button(doc_card)
	_add_card(doc_card, "L5 Doctor Hint")

	# Dart shop
	_build_dart_shop_card()

	# Card 7: Bridge card
	_build_bridge_card(
		"The Arrow Palace, London.",
		"World Championship Semi-Final",
		"The cathedral of darts. Walk-on music. Pyrotechnics. Two thousand in fancy dress.",
		50000
	)

	# Pre-match drinking
	_build_pre_drink_card()

	# Card 8: Lars stats — show his intimidating image first (CONTINUE, not NEXT MATCH — manager card follows)
	_build_opponent_stats_card(
		"lars", "Lars", "The Viking",
		{"SKILL": 4, "HEFT": 5, "HUSTLE": 3, "SWAGGER": 4},
		"501, Best of 5", true
	)

	# Card 9: Manager cuts him down
	var lars_intro := _create_card()
	_add_spacer(lars_intro, 60)
	var lars_panel := _build_companion_panel(
		"THE MANAGER",
		"Lars the Viking is a pathetic excuse for a man. Thinks he's got Nordic blood but I know for a fact he's from Bristol.\n\nWears an old rug round his shoulders. Calls it a \"fair shame\" he's so good at darts.\n\nImagine how good he'd be if he took those ridiculous arm guards off.\n\nBest of luck.",
		Color(0.4, 0.15, 0.25), "S", "res://Manager cropped new.png", UIFont.PORTRAIT_L
	)
	lars_intro.add_child(lars_panel)
	_add_spacer(lars_intro, 30)
	var lars_next := _create_button("NEXT MATCH", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	lars_next.pressed.connect(_on_next_match)
	var lars_next_w := CenterContainer.new()
	lars_next_w.custom_minimum_size = Vector2(640, 100)
	lars_next_w.add_child(lars_next)
	lars_intro.add_child(lars_next_w)
	_add_card(lars_intro, "L5 Manager Lars Intro")

# ======================================================
# LEVEL 6 POST-WIN (Beat Lars "The Viking")
# ======================================================

func _build_l6_win_cards() -> void:
	# Post-match celebration — Lars takes it stoically
	# (fight = death, so if we're here the player won cleanly on darts)
	_build_celebration_reaction_card(
		"LARS",
		"Lars stares at you across the oche.\n\nHe nods. Once.\n\n\"Good match.\"\n\nHe walks off. No handshake.",
		"res://Lars The Viking cropped.png"
	)

	# Card 2: All stars snapshot (no SKILL increase, already at 5)
	var snap_card := _create_card()
	_add_spacer(snap_card, 15)

	var portrait_path: String
	if CareerState.career_mode_active:
		portrait_path = DartData.get_profile_image_for_tier(GameState.character, CareerState.calculate_appearance_tier())
	else:
		portrait_path = DartData.get_profile_image(GameState.character)
	var tex := load(portrait_path)
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.custom_minimum_size = Vector2(640, 420)
		snap_card.add_child(img)

	_add_spacer(snap_card, 10)

	var char_name: String = DartData.get_full_name(GameState.character)
	var name_label := Label.new()
	if CareerState.nickname_active:
		var char_nick: String = DartData.get_character_nickname(GameState.character)
		name_label.text = char_name + '\n"' + char_nick + '"'
		name_label.custom_minimum_size = Vector2(640, 90)
	else:
		name_label.text = char_name
		name_label.custom_minimum_size = Vector2(640, 60)
	UIFont.apply(name_label, UIFont.HEADING)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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

	# Food card: Room service at the hotel
	_build_food_card("ROOM SERVICE", "Can't sleep. Pre-final nerves.\nThe entourage orders room service.\nClub sandwich, chips, cheesecake.\nComfort eating at midnight.", "ORDER IT", 2500, "Room service at midnight.\nLiving the dream.", 6)

	# Coach/team dialogue
	var coach_card := _create_card()
	_add_spacer(coach_card, 60)
	var speaker_name: String = "THE TEAM" if CareerState.team_hired else "THE COACH"
	var _coach_img: String = "res://Manager and full team cropped new.png" if CareerState.team_hired else "res://Coach cropped.png"
	var coach_panel := _build_companion_panel(
		speaker_name,
		"The manager speaks first.\n\n\"One more. That's all that stands between you and the title.\"\n\nShe pauses.\n\n\"But the doc says you need a check-up first. No arguments.\"",
		Color(0.15, 0.35, 0.2), "C", _coach_img, UIFont.PORTRAIT_XL
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
		Color(0.3, 0.5, 0.35), "D", "res://Doctor cropped.png", UIFont.PORTRAIT_XL
	)
	doc_card.add_child(doc_panel)
	_add_spacer(doc_card, 30)
	_add_continue_button(doc_card)
	_add_card(doc_card, "L6 Doctor")

	# Card 5: Vinnie "The Gold" introduction (two variants, random)
	var vinnie_card := _create_card()
	_add_spacer(vinnie_card, 60)
	var vinnie_text: String
	if randi() % 2 == 0:
		vinnie_text = "The cameras find you in the corridor.\n\nVinnie walks past. Gold shoes. Gold watch. Gold tooth.\n\nHe brushes past. Close enough to smell the aftershave.\n\nHe doesn't say a word. He doesn't need to."
	else:
		var _sol: String = "love" if DartData.get_is_female(GameState.character) else "son"
		vinnie_text = "The cameras find you in the corridor.\n\nVinnie walks past. Gold shoes. Gold watch. Gold tooth.\n\nHe stops. Looks you up and down.\n\n\"Enjoy tonight, " + _sol + ". It's as close as you'll get.\"\n\nHe walks on."
	var vinnie_panel := _build_companion_panel(
		"VINNIE \"THE GOLD\"",
		vinnie_text,
		Color(0.6, 0.5, 0.1), "V", "res://Vinnie The Gold cropped.png", UIFont.PORTRAIT_L
	)
	vinnie_card.add_child(vinnie_panel)
	_add_spacer(vinnie_card, 30)
	_add_continue_button(vinnie_card)
	_add_card(vinnie_card, "L6 Vinnie Intro")

	# Card: Choose walk-on music (Swagger star 5)
	var walkon_card := _create_card()
	_add_spacer(walkon_card, 80)
	var walkon_title := Label.new()
	walkon_title.text = "WALK-ON MUSIC"
	UIFont.apply(walkon_title, UIFont.HEADING)
	walkon_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	walkon_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	walkon_title.custom_minimum_size = Vector2(640, 70)
	walkon_card.add_child(walkon_title)
	_add_spacer(walkon_card, 15)
	var walkon_desc := Label.new()
	walkon_desc.text = "World Championship Final.\nYou need a walk-on track.\nWhat's it going to be?"
	UIFont.apply(walkon_desc, UIFont.BODY)
	walkon_desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	walkon_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	walkon_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	walkon_desc.custom_minimum_size = Vector2(640, 70)
	walkon_card.add_child(walkon_desc)
	_add_spacer(walkon_card, 30)

	var _set_walkon := func(track: int):
		CareerState.walkon_track = track
		CareerState.recalculate_swagger()
		_advance_card()

	var track1_btn := _create_button("THUNDERSTRUCK", Color(0.4, 0.15, 0.15), Color(0.7, 0.3, 0.3))
	track1_btn.pressed.connect(func(): _set_walkon.call(0))
	var track1_w := CenterContainer.new()
	track1_w.custom_minimum_size = Vector2(640, 80)
	track1_w.add_child(track1_btn)
	walkon_card.add_child(track1_w)
	var track1_sub := Label.new()
	track1_sub.text = "AC/DC. Classic.\nThe crowd knows every beat."
	UIFont.apply(track1_sub, UIFont.CAPTION)
	track1_sub.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	track1_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	track1_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	track1_sub.custom_minimum_size = Vector2(600, 50)
	walkon_card.add_child(track1_sub)
	_add_spacer(walkon_card, 10)

	var track2_btn := _create_button("EYE OF THE TIGER", Color(0.15, 0.15, 0.4), Color(0.3, 0.3, 0.7))
	track2_btn.pressed.connect(func(): _set_walkon.call(1))
	var track2_w := CenterContainer.new()
	track2_w.custom_minimum_size = Vector2(640, 80)
	track2_w.add_child(track2_btn)
	walkon_card.add_child(track2_w)
	var track2_sub := Label.new()
	track2_sub.text = "Survivor.\nUnderdog anthem. Perfect."
	UIFont.apply(track2_sub, UIFont.CAPTION)
	track2_sub.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	track2_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	track2_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	track2_sub.custom_minimum_size = Vector2(600, 50)
	walkon_card.add_child(track2_sub)
	_add_spacer(walkon_card, 10)

	var track3_btn := _create_button("PAUL YOUNG", Color(0.35, 0.25, 0.1), Color(0.6, 0.45, 0.2))
	track3_btn.pressed.connect(func(): _set_walkon.call(2))
	var track3_w := CenterContainer.new()
	track3_w.custom_minimum_size = Vector2(640, 80)
	track3_w.add_child(track3_btn)
	walkon_card.add_child(track3_w)
	var track3_sub := Label.new()
	track3_sub.text = "Bold choice. The crowd won't know what to do."
	UIFont.apply(track3_sub, UIFont.CAPTION)
	track3_sub.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	track3_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	track3_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	track3_sub.custom_minimum_size = Vector2(600, 50)
	walkon_card.add_child(track3_sub)
	_add_card(walkon_card, "L6 Walk-on Music")

	# Card: Walk-on volume — louder = more opponent anger at match start
	var vol_card := _create_card()
	_add_spacer(vol_card, 80)
	var vol_title := Label.new()
	vol_title.text = "HOW LOUD?"
	UIFont.apply(vol_title, UIFont.HEADING)
	vol_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vol_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vol_title.custom_minimum_size = Vector2(640, 70)
	vol_card.add_child(vol_title)
	_add_spacer(vol_card, 15)
	var vol_desc := Label.new()
	vol_desc.text = "The sound engineer looks at you.\nHow loud do you want it?"
	UIFont.apply(vol_desc, UIFont.BODY)
	vol_desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	vol_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vol_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vol_desc.custom_minimum_size = Vector2(640, 60)
	vol_card.add_child(vol_desc)
	_add_spacer(vol_card, 25)

	var vol_reaction := Label.new()
	vol_reaction.text = ""
	UIFont.apply(vol_reaction, UIFont.CAPTION)
	vol_reaction.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	vol_reaction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vol_reaction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vol_reaction.custom_minimum_size = Vector2(600, 40)
	vol_reaction.visible = false

	var _set_volume := func(level: int):
		CareerState.walkon_volume = level
		match level:
			0: vol_reaction.text = "A gentle hum.\nVinnie doesn't even notice you walk in."
			1: vol_reaction.text = "Respectable.\nVinnie glances over. Nothing more."
			2: vol_reaction.text = "The crowd are singing along.\nVinnie's jaw tightens."
			3: vol_reaction.text = "The whole building shakes.\nVinnie looks furious."
		vol_reaction.visible = true
		await get_tree().create_timer(2.0).timeout
		_advance_card()

	# Volume buttons — 4 options, escalating colour intensity
	var vol1_btn := _create_button("QUIET", Color(0.2, 0.25, 0.2), Color(0.35, 0.4, 0.35))
	vol1_btn.pressed.connect(func(): _set_volume.call(0))
	var vol1_w := CenterContainer.new()
	vol1_w.custom_minimum_size = Vector2(640, 65)
	vol1_w.add_child(vol1_btn)
	vol_card.add_child(vol1_w)
	_add_spacer(vol_card, 8)

	var vol2_btn := _create_button("MEDIUM", Color(0.25, 0.25, 0.15), Color(0.45, 0.45, 0.25))
	vol2_btn.pressed.connect(func(): _set_volume.call(1))
	var vol2_w := CenterContainer.new()
	vol2_w.custom_minimum_size = Vector2(640, 65)
	vol2_w.add_child(vol2_btn)
	vol_card.add_child(vol2_w)
	_add_spacer(vol_card, 8)

	var vol3_btn := _create_button("LOUD", Color(0.35, 0.2, 0.1), Color(0.6, 0.35, 0.15))
	vol3_btn.pressed.connect(func(): _set_volume.call(2))
	var vol3_w := CenterContainer.new()
	vol3_w.custom_minimum_size = Vector2(640, 65)
	vol3_w.add_child(vol3_btn)
	vol_card.add_child(vol3_w)
	_add_spacer(vol_card, 8)

	var vol4_btn := _create_button("DEAFENING", Color(0.45, 0.1, 0.1), Color(0.75, 0.2, 0.2))
	vol4_btn.pressed.connect(func(): _set_volume.call(3))
	var vol4_w := CenterContainer.new()
	vol4_w.custom_minimum_size = Vector2(640, 65)
	vol4_w.add_child(vol4_btn)
	vol_card.add_child(vol4_w)
	_add_spacer(vol_card, 15)

	vol_card.add_child(vol_reaction)
	_add_card(vol_card, "L6 Walk-on Volume")

	# Walk-on is a narrative choice only — no swagger star (swagger maxes at 5 by L5)

	# Dart shop
	_build_dart_shop_card()

	# Card 6: Bridge card
	_build_bridge_card(
		"World Championship Final.",
		"The Arrow Palace, London",
		"Gold confetti loaded. Fireworks ready.\nTwo thousand on their feet.\n\nThis is it.",
		100000
	)

	# Pre-match drinking
	_build_pre_drink_card()

	# Card 7: Doctor's pre-final check — severity depends on liver/heart damage
	var son_or_love_doc: String = "love" if DartData.get_is_female(GameState.character) else "son"
	var doc_final := _create_card()
	_add_spacer(doc_final, 60)
	var doc_final_text: String
	if CareerState.liver_damage >= 60 or CareerState.heart_risk >= 60:
		# High damage — one more drink and you're dead
		doc_final_text = "She catches you outside the green room.\n\n\"I've seen your blood work. Your liver is hanging on by a thread.\"\n\nShe looks you dead in the eye.\n\n\"One more drink and you're dead, " + son_or_love_doc + ". I mean it. Not tomorrow. Tonight.\""
		CareerState.doctor_death_warning = true
	elif CareerState.liver_damage >= 30 or CareerState.heart_risk >= 30:
		# Medium damage — warning but no death risk
		doc_final_text = "She catches you outside the green room.\n\n\"Your body's taken a battering this tournament. Liver's not great. Heart's working harder than it should.\"\n\nShe sighs.\n\n\"You'll survive the final. But maybe ease off the pints, " + son_or_love_doc + ".\""
	else:
		# Low damage — clean bill of health
		doc_final_text = "She catches you outside the green room.\n\n\"I've had a look at your results.\"\n\nShe smiles.\n\n\"You're in good shape, " + son_or_love_doc + ". Go win that final.\""
	var doc_final_panel := _build_companion_panel(
		"THE DOCTOR",
		doc_final_text,
		Color(0.3, 0.5, 0.35), "D", "res://Doctor cropped.png", UIFont.PORTRAIT_ML
	)
	doc_final.add_child(doc_final_panel)
	_add_spacer(doc_final, 30)
	_add_continue_button(doc_final)
	_add_card(doc_final, "L7 Doctor Check")

	# Card 8: Vinnie "The Gold" stats (CONTINUE, not NEXT MATCH — manager card follows)
	_build_opponent_stats_card(
		"vinnie", "Vinnie", "The Gold",
		{"SKILL": 5, "HEFT": 4, "HUSTLE": 5, "SWAGGER": 5},
		"501, Best of 7", true
	)

	# Card 9: Manager cuts Vinnie down
	var vinnie_intro := _create_card()
	_add_spacer(vinnie_intro, 60)
	var vinnie_mgr_panel := _build_companion_panel(
		"THE MANAGER",
		"Vincent Golding. Five world titles, I'll give him that.\n\nBut he's forty-three, he's carrying a groin injury, and he hasn't played anyone under thirty in two years.\n\nHe's got a chequered past, this one. Three of his former opponents have quietly disappeared from the circuit. One the night before the final of the world championships. Nobody asks questions. I'd advise you don't either.\n\nWhatever you do, do not wind him up.\n\nGo and take his crown.",
		Color(0.4, 0.15, 0.25), "S", "res://Manager cropped new.png", UIFont.PORTRAIT_XS
	)
	vinnie_intro.add_child(vinnie_mgr_panel)
	_add_spacer(vinnie_intro, 30)
	var vinnie_next := _create_button("NEXT MATCH", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	vinnie_next.pressed.connect(_on_next_match)
	var vinnie_next_w := CenterContainer.new()
	vinnie_next_w.custom_minimum_size = Vector2(640, 100)
	vinnie_next_w.add_child(vinnie_next)
	vinnie_intro.add_child(vinnie_next_w)
	_add_card(vinnie_intro, "L6 Manager Vinnie Intro")

# ======================================================
# WORLD CHAMPION (Level 7 win — expanded)
# ======================================================

func _build_world_champion_cards() -> void:
	# Card 1: Prize money already added by _build_prize_card

	# Card 2: 5th hustle star — world champion hustle
	if CareerState.hustle_stars < 5:
		CareerState.hustle_stars = 5
	var victory_img := DartData.get_victory_image(GameState.character)
	_build_star_flip_card("HUSTLE", 4, 5, "World champion.\nMaximum hustle.", null, victory_img)

	# Card 3: Final stars snapshot — victory crowd scene
	var snap_card := _create_card()
	_add_spacer(snap_card, 15)

	var portrait_path: String
	if CareerState.career_mode_active:
		portrait_path = DartData.get_victory_image(GameState.character)
	else:
		portrait_path = DartData.get_profile_image(GameState.character)
	var tex := load(portrait_path)
	if tex:
		# Full-width victory image — breaks out of card margins via offset container
		var img_holder := Control.new()
		img_holder.custom_minimum_size = Vector2(640, 420)
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.position = Vector2(-40, 0)
		img.size = Vector2(720, 420)
		img_holder.add_child(img)
		snap_card.add_child(img_holder)

	_add_spacer(snap_card, 10)

	var char_name: String = DartData.get_full_name(GameState.character)
	var name_label := Label.new()
	if CareerState.nickname_active:
		var char_nick: String = DartData.get_character_nickname(GameState.character)
		name_label.text = char_name + '\n"' + char_nick + '"'
		name_label.custom_minimum_size = Vector2(640, 90)
	else:
		name_label.text = char_name
		name_label.custom_minimum_size = Vector2(640, 60)
	UIFont.apply(name_label, UIFont.HEADING)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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

	# Card 3: Cinematic credits scroll
	_build_credits_card()


# ======================================================
# DRINK DEATH (cinematic funeral card)
# ======================================================

var _death_tween: Tween

func _build_drink_death_card() -> void:
	CareerState.drink_death_occurred = false  # Clear flag

	var card := _create_card()

	# Holder fills the VBoxContainer card; full_screen breaks out of margins
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(640, 1280)
	card.add_child(holder)

	var full_screen := Control.new()
	full_screen.position = Vector2(-40, 0)
	full_screen.size = Vector2(720, 1280)
	full_screen.clip_contents = true
	holder.add_child(full_screen)

	# Very dark background with subtle red tint
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.03, 0.03)
	bg.size = Vector2(720, 1280)
	full_screen.add_child(bg)

	# --- Framed portrait (age 19 — when they were healthy) ---

	# Outer frame: dark wood colour
	var frame_outer := ColorRect.new()
	var frame_w := 260
	var frame_h := 280
	var frame_x := (720 - frame_w) / 2
	var frame_y := 80
	frame_outer.position = Vector2(frame_x, frame_y)
	frame_outer.size = Vector2(frame_w, frame_h)
	frame_outer.color = Color(0.22, 0.14, 0.08)
	full_screen.add_child(frame_outer)

	# Inner frame: gold border
	var frame_inner := ColorRect.new()
	var border := 8
	frame_inner.position = Vector2(border, border)
	frame_inner.size = Vector2(frame_w - border * 2, frame_h - border * 2)
	frame_inner.color = Color(0.72, 0.58, 0.25)
	frame_outer.add_child(frame_inner)

	# Portrait image (age 19)
	var portrait_path: String = DartData.get_profile_image_for_tier(GameState.character, 0)
	var tex := load(portrait_path)
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var img_border := 4
		img.position = Vector2(img_border, img_border)
		img.size = Vector2(frame_inner.size.x - img_border * 2, frame_inner.size.y - img_border * 2)
		frame_inner.add_child(img)

	# --- Flowers beneath the frame ---

	# Simple floral arrangement: muted coloured ovals beneath the portrait
	var flower_y := frame_y + frame_h + 5
	var flower_colors := [
		Color(0.55, 0.15, 0.15),  # dark red
		Color(0.65, 0.55, 0.65),  # dusty lilac
		Color(0.45, 0.12, 0.12),  # deep burgundy
		Color(0.6, 0.6, 0.55),    # muted sage
		Color(0.55, 0.15, 0.15),  # dark red
		Color(0.65, 0.55, 0.65),  # dusty lilac
		Color(0.45, 0.12, 0.12),  # deep burgundy
	]
	var flower_start_x := frame_x - 10
	var flower_spacing := (frame_w + 20) / flower_colors.size()
	for i in flower_colors.size():
		var petal := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = flower_colors[i]
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		petal.add_theme_stylebox_override("panel", style)
		petal.position = Vector2(flower_start_x + i * flower_spacing + 5, flower_y + (i % 2) * 6)
		petal.size = Vector2(flower_spacing - 8, 22)
		full_screen.add_child(petal)

	# Green leaves underneath
	var leaf_bar := Panel.new()
	var leaf_style := StyleBoxFlat.new()
	leaf_style.bg_color = Color(0.18, 0.28, 0.15, 0.7)
	leaf_style.corner_radius_top_left = 4
	leaf_style.corner_radius_top_right = 4
	leaf_style.corner_radius_bottom_left = 4
	leaf_style.corner_radius_bottom_right = 4
	leaf_bar.add_theme_stylebox_override("panel", leaf_style)
	leaf_bar.position = Vector2(frame_x + 10, flower_y + 28)
	leaf_bar.size = Vector2(frame_w - 20, 8)
	full_screen.add_child(leaf_bar)

	# --- Text elements (all start invisible, fade in with tween) ---

	var text_y := flower_y + 45
	var text_elements: Array = []

	# Player name
	var name_label := Label.new()
	var full_name: String = DartData.get_full_name(GameState.character)
	if CareerState.nickname_active:
		var nickname: String = DartData.get_character_nickname(GameState.character)
		name_label.text = full_name + '\n"' + nickname + '"'
	else:
		name_label.text = full_name
	UIFont.apply(name_label, UIFont.SUBHEADING)
	name_label.add_theme_color_override("font_color", Color(0.75, 0.65, 0.4))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(60, text_y)
	name_label.size = Vector2(600, 90)
	name_label.modulate.a = 0.0
	full_screen.add_child(name_label)
	text_elements.append(name_label)

	text_y += 100

	# Death lines — each fades in separately
	var son_or_love: String = "love" if DartData.get_is_female(GameState.character) else "son"
	var first_name: String = DartData.get_character_name(GameState.character)
	var death_lines := [
		"She told you.",
		"One more drink.",
		"",
		"The paramedics arrived",
		"in three minutes.",
		"It was already too late.",
		"",
		"So close to glory, " + son_or_love + ".",
		"So close.",
		"",
		"RIP " + first_name + ".",
	]

	for line in death_lines:
		if line == "":
			text_y += 25  # Beat pause
			continue
		var lbl := Label.new()
		lbl.text = line
		UIFont.apply(lbl, UIFont.BODY)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.position = Vector2(60, text_y)
		lbl.size = Vector2(600, 48)
		lbl.modulate.a = 0.0
		full_screen.add_child(lbl)
		text_elements.append(lbl)
		text_y += 48

	# NEW CAREER button (also fades in)
	text_y += 25
	var new_btn := _create_button("NEW CAREER", Color(0.5, 0.15, 0.15), Color(0.8, 0.3, 0.3))
	new_btn.pressed.connect(_on_new_career)
	var btn_wrapper := CenterContainer.new()
	btn_wrapper.position = Vector2(60, text_y)
	btn_wrapper.size = Vector2(600, 100)
	btn_wrapper.modulate.a = 0.0
	btn_wrapper.add_child(new_btn)
	full_screen.add_child(btn_wrapper)
	text_elements.append(btn_wrapper)

	# Store card index for deferred animation (must be before _add_card)
	var card_idx: int = _cards.size()
	_card_animations[card_idx] = _start_death_fade_in.bind(text_elements)
	_add_card(card, "Drink Death")


func _start_death_fade_in(elements: Array) -> void:
	_death_tween = create_tween()
	_death_tween.tween_interval(1.5)  # Initial pause — let the portrait sink in

	for element in elements:
		_death_tween.tween_property(element, "modulate:a", 1.0, 1.2)
		_death_tween.tween_interval(0.8)  # Pause between each line


# ======================================================
# MAFIA DEATH (cinematic funeral card — deal broken)
# ======================================================

func _build_mafia_death_card() -> void:
	var card := _create_card()

	# Holder fills the VBoxContainer card; full_screen breaks out of margins
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(640, 1280)
	card.add_child(holder)

	var full_screen := Control.new()
	full_screen.position = Vector2(-40, 0)
	full_screen.size = Vector2(720, 1280)
	full_screen.clip_contents = true
	holder.add_child(full_screen)

	# Very dark background with subtle red tint
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.03, 0.03)
	bg.size = Vector2(720, 1280)
	full_screen.add_child(bg)

	# --- Framed portrait (age 19 — when they were healthy) ---

	# Outer frame: dark wood colour
	var frame_outer := ColorRect.new()
	var frame_w := 260
	var frame_h := 280
	var frame_x := (720 - frame_w) / 2
	var frame_y := 80
	frame_outer.position = Vector2(frame_x, frame_y)
	frame_outer.size = Vector2(frame_w, frame_h)
	frame_outer.color = Color(0.22, 0.14, 0.08)
	full_screen.add_child(frame_outer)

	# Inner frame: gold border
	var frame_inner := ColorRect.new()
	var border := 8
	frame_inner.position = Vector2(border, border)
	frame_inner.size = Vector2(frame_w - border * 2, frame_h - border * 2)
	frame_inner.color = Color(0.72, 0.58, 0.25)
	frame_outer.add_child(frame_inner)

	# Portrait image (age 19)
	var portrait_path: String = DartData.get_profile_image_for_tier(GameState.character, 0)
	var tex := load(portrait_path)
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var img_border := 4
		img.position = Vector2(img_border, img_border)
		img.size = Vector2(frame_inner.size.x - img_border * 2, frame_inner.size.y - img_border * 2)
		frame_inner.add_child(img)

	# --- Flowers beneath the frame ---

	var flower_y := frame_y + frame_h + 5
	var flower_colors := [
		Color(0.55, 0.15, 0.15),  # dark red
		Color(0.65, 0.55, 0.65),  # dusty lilac
		Color(0.45, 0.12, 0.12),  # deep burgundy
		Color(0.6, 0.6, 0.55),    # muted sage
		Color(0.55, 0.15, 0.15),  # dark red
		Color(0.65, 0.55, 0.65),  # dusty lilac
		Color(0.45, 0.12, 0.12),  # deep burgundy
	]
	var flower_start_x := frame_x - 10
	var flower_spacing := (frame_w + 20) / flower_colors.size()
	for i in flower_colors.size():
		var petal := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = flower_colors[i]
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		petal.add_theme_stylebox_override("panel", style)
		petal.position = Vector2(flower_start_x + i * flower_spacing + 5, flower_y + (i % 2) * 6)
		petal.size = Vector2(flower_spacing - 8, 22)
		full_screen.add_child(petal)

	# Green leaves underneath
	var leaf_bar := Panel.new()
	var leaf_style := StyleBoxFlat.new()
	leaf_style.bg_color = Color(0.18, 0.28, 0.15, 0.7)
	leaf_style.corner_radius_top_left = 4
	leaf_style.corner_radius_top_right = 4
	leaf_style.corner_radius_bottom_left = 4
	leaf_style.corner_radius_bottom_right = 4
	leaf_bar.add_theme_stylebox_override("panel", leaf_style)
	leaf_bar.position = Vector2(frame_x + 10, flower_y + 28)
	leaf_bar.size = Vector2(frame_w - 20, 8)
	full_screen.add_child(leaf_bar)

	# --- Text elements (all start invisible, fade in with tween) ---

	var text_y := flower_y + 45
	var text_elements: Array = []

	# Player name
	var name_label := Label.new()
	var full_name: String = DartData.get_full_name(GameState.character)
	if CareerState.nickname_active:
		var nickname: String = DartData.get_character_nickname(GameState.character)
		name_label.text = full_name + '\n"' + nickname + '"'
	else:
		name_label.text = full_name
	UIFont.apply(name_label, UIFont.SUBHEADING)
	name_label.add_theme_color_override("font_color", Color(0.75, 0.65, 0.4))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(60, text_y)
	name_label.size = Vector2(600, 90)
	name_label.modulate.a = 0.0
	full_screen.add_child(name_label)
	text_elements.append(name_label)

	text_y += 100

	# Death lines — each fades in separately
	var first_name: String = DartData.get_character_name(GameState.character)
	var death_lines := [
		"That wasn't the deal.",
		"",
		"A car park.",
		"Two men. No words.",
		"",
		"They found you",
		"the next morning.",
		"",
		"RIP " + first_name + ".",
	]

	for line in death_lines:
		if line == "":
			text_y += 25  # Beat pause
			continue
		var lbl := Label.new()
		lbl.text = line
		UIFont.apply(lbl, UIFont.BODY)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.position = Vector2(60, text_y)
		lbl.size = Vector2(600, 48)
		lbl.modulate.a = 0.0
		full_screen.add_child(lbl)
		text_elements.append(lbl)
		text_y += 48

	# NEW CAREER button (also fades in)
	text_y += 25
	var new_btn := _create_button("NEW CAREER", Color(0.5, 0.15, 0.15), Color(0.8, 0.3, 0.3))
	new_btn.pressed.connect(_on_new_career)
	var btn_wrapper := CenterContainer.new()
	btn_wrapper.position = Vector2(60, text_y)
	btn_wrapper.size = Vector2(600, 100)
	btn_wrapper.modulate.a = 0.0
	btn_wrapper.add_child(new_btn)
	full_screen.add_child(btn_wrapper)
	text_elements.append(btn_wrapper)

	# Store card index for deferred animation
	var card_idx: int = _cards.size()
	_card_animations[card_idx] = _start_death_fade_in.bind(text_elements)
	_add_card(card, "Mafia Death")


## Lars fight death — celebrated too hard, Lars killed you.
## Same funeral visual format as drink/mafia death.
func _build_lars_death_card() -> void:
	var card := _create_card()

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(640, 1280)
	card.add_child(holder)

	var full_screen := Control.new()
	full_screen.position = Vector2(-40, 0)
	full_screen.size = Vector2(720, 1280)
	full_screen.clip_contents = true
	holder.add_child(full_screen)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.03, 0.03)
	bg.size = Vector2(720, 1280)
	full_screen.add_child(bg)

	# --- Framed portrait (age 19) ---
	var frame_outer := ColorRect.new()
	var frame_w := 260
	var frame_h := 280
	var frame_x := (720 - frame_w) / 2
	var frame_y := 80
	frame_outer.position = Vector2(frame_x, frame_y)
	frame_outer.size = Vector2(frame_w, frame_h)
	frame_outer.color = Color(0.22, 0.14, 0.08)
	full_screen.add_child(frame_outer)

	var frame_inner := ColorRect.new()
	var border := 8
	frame_inner.position = Vector2(border, border)
	frame_inner.size = Vector2(frame_w - border * 2, frame_h - border * 2)
	frame_inner.color = Color(0.72, 0.58, 0.25)
	frame_outer.add_child(frame_inner)

	var portrait_path: String = DartData.get_profile_image_for_tier(GameState.character, 0)
	var tex := load(portrait_path)
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var img_border := 4
		img.position = Vector2(img_border, img_border)
		img.size = Vector2(frame_inner.size.x - img_border * 2, frame_inner.size.y - img_border * 2)
		frame_inner.add_child(img)

	# --- Flowers ---
	var flower_y := frame_y + frame_h + 5
	var flower_colors := [
		Color(0.55, 0.15, 0.15), Color(0.65, 0.55, 0.65),
		Color(0.45, 0.12, 0.12), Color(0.6, 0.6, 0.55),
		Color(0.55, 0.15, 0.15), Color(0.65, 0.55, 0.65),
		Color(0.45, 0.12, 0.12),
	]
	var flower_start_x := frame_x - 10
	var flower_spacing := (frame_w + 20) / flower_colors.size()
	for i in flower_colors.size():
		var petal := Panel.new()
		var pstyle := StyleBoxFlat.new()
		pstyle.bg_color = flower_colors[i]
		pstyle.corner_radius_top_left = 10
		pstyle.corner_radius_top_right = 10
		pstyle.corner_radius_bottom_left = 10
		pstyle.corner_radius_bottom_right = 10
		petal.add_theme_stylebox_override("panel", pstyle)
		petal.position = Vector2(flower_start_x + i * flower_spacing + 5, flower_y + (i % 2) * 6)
		petal.size = Vector2(flower_spacing - 8, 22)
		full_screen.add_child(petal)

	var leaf_bar := Panel.new()
	var leaf_style := StyleBoxFlat.new()
	leaf_style.bg_color = Color(0.18, 0.28, 0.15, 0.7)
	leaf_style.corner_radius_top_left = 4
	leaf_style.corner_radius_top_right = 4
	leaf_style.corner_radius_bottom_left = 4
	leaf_style.corner_radius_bottom_right = 4
	leaf_bar.add_theme_stylebox_override("panel", leaf_style)
	leaf_bar.position = Vector2(frame_x + 10, flower_y + 28)
	leaf_bar.size = Vector2(frame_w - 20, 8)
	full_screen.add_child(leaf_bar)

	# --- Text ---
	var text_y := flower_y + 45
	var text_elements: Array = []

	var name_label := Label.new()
	var full_name: String = DartData.get_full_name(GameState.character)
	if CareerState.nickname_active:
		var nickname: String = DartData.get_character_nickname(GameState.character)
		name_label.text = full_name + '\n"' + nickname + '"'
	else:
		name_label.text = full_name
	UIFont.apply(name_label, UIFont.SUBHEADING)
	name_label.add_theme_color_override("font_color", Color(0.75, 0.65, 0.4))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(60, text_y)
	name_label.size = Vector2(600, 90)
	name_label.modulate.a = 0.0
	full_screen.add_child(name_label)
	text_elements.append(name_label)

	text_y += 100

	var first_name: String = DartData.get_character_name(GameState.character)
	var death_lines := [
		"You celebrated",
		"one time too many.",
		"",
		"Lars didn't wait",
		"for security.",
		"",
		"They found you",
		"behind the stage.",
		"",
		"RIP " + first_name + ".",
	]

	for line in death_lines:
		if line == "":
			text_y += 25
			continue
		var lbl := Label.new()
		lbl.text = line
		UIFont.apply(lbl, UIFont.BODY)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.position = Vector2(60, text_y)
		lbl.size = Vector2(600, 48)
		lbl.modulate.a = 0.0
		full_screen.add_child(lbl)
		text_elements.append(lbl)
		text_y += 48

	text_y += 25
	var new_btn := _create_button("NEW CAREER", Color(0.5, 0.15, 0.15), Color(0.8, 0.3, 0.3))
	new_btn.pressed.connect(_on_new_career)
	var btn_wrapper := CenterContainer.new()
	btn_wrapper.position = Vector2(60, text_y)
	btn_wrapper.size = Vector2(600, 100)
	btn_wrapper.modulate.a = 0.0
	btn_wrapper.add_child(new_btn)
	full_screen.add_child(btn_wrapper)
	text_elements.append(btn_wrapper)

	var card_idx: int = _cards.size()
	_card_animations[card_idx] = _start_death_fade_in.bind(text_elements)
	_add_card(card, "Lars Fight Death")


# ======================================================
# CREDITS SCROLL (cinematic ending)
# ======================================================

var _credits_tween: Tween
var _credits_text_column: VBoxContainer
var _credits_skip_btn: Button

func _build_credits_card() -> void:
	var card := _create_card()

	# Holder fills the VBoxContainer card; full_screen breaks out of margins
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(640, 1280)
	card.add_child(holder)

	var full_screen := Control.new()
	full_screen.position = Vector2(-40, 0)
	full_screen.size = Vector2(720, 1280)
	full_screen.clip_contents = true
	holder.add_child(full_screen)

	# 1. Victory image — fills the screen as background
	var portrait_path: String
	if CareerState.career_mode_active:
		portrait_path = DartData.get_victory_image(GameState.character)
	else:
		portrait_path = DartData.get_profile_image(GameState.character)
	var tex := load(portrait_path)
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.size = Vector2(720, 1280)
		full_screen.add_child(img)

	# 2. Gradient overlay — subtle at top (image visible), dark at bottom (text readable)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0.25))
	gradient.set_offset(0, 0.0)
	gradient.set_color(1, Color(0, 0, 0, 0.92))
	gradient.set_offset(1, 1.0)
	gradient.add_point(0.35, Color(0, 0, 0, 0.4))
	gradient.add_point(0.65, Color(0, 0, 0, 0.8))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = gradient
	grad_tex.fill_from = Vector2(0.5, 0)
	grad_tex.fill_to = Vector2(0.5, 1)
	grad_tex.width = 4
	grad_tex.height = 256
	var overlay := TextureRect.new()
	overlay.texture = grad_tex
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.size = Vector2(720, 1280)
	full_screen.add_child(overlay)

	# 3. Scrolling text — starts below screen, scrolls upward like movie credits
	var scroll_clip := Control.new()
	scroll_clip.position = Vector2(0, 0)
	scroll_clip.size = Vector2(720, 1280)
	scroll_clip.clip_contents = true
	full_screen.add_child(scroll_clip)

	var text_column := VBoxContainer.new()
	text_column.position = Vector2(60, 1280)
	text_column.size = Vector2(600, 0)
	text_column.add_theme_constant_override("separation", 0)
	scroll_clip.add_child(text_column)
	_credits_text_column = text_column

	# --- Credits content ---
	# NOTE: spacers in credits use 600px width (not _add_spacer's 640px)
	# to keep VBoxContainer at exactly 600px and centred on screen.

	# Lead-in spacer (brief pause before text scrolls in)
	var _cs := func(h: int):
		var s := Control.new()
		s.custom_minimum_size = Vector2(600, h)
		text_column.add_child(s)
	_cs.call(40)

	# "WORLD CHAMPION" title
	var title_label := Label.new()
	title_label.text = "WORLD CHAMPION"
	UIFont.apply(title_label, UIFont.HEADING)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.custom_minimum_size = Vector2(600, 70)
	text_column.add_child(title_label)

	_cs.call(50)

	# Character name + nickname
	var char_name := DartData.get_full_name(GameState.character)
	var name_label := Label.new()
	if CareerState.nickname_active:
		var nick := DartData.get_character_nickname(GameState.character)
		name_label.text = char_name + '\n"' + nick + '"'
		name_label.custom_minimum_size = Vector2(600, 90)
	else:
		name_label.text = char_name
		name_label.custom_minimum_size = Vector2(600, 55)
	UIFont.apply(name_label, UIFont.SUBHEADING)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_column.add_child(name_label)

	_cs.call(80)

	# Thin gold divider line
	var divider := ColorRect.new()
	divider.color = Color(1.0, 0.85, 0.2, 0.4)
	divider.custom_minimum_size = Vector2(200, 2)
	var div_center := CenterContainer.new()
	div_center.custom_minimum_size = Vector2(600, 20)
	div_center.add_child(divider)
	text_column.add_child(div_center)

	_cs.call(60)

	# Character-specific ending text
	var ending := EndingsData.get_ending(GameState.character)
	for line in ending:
		if line == "":
			_cs.call(45)
		else:
			var para := Label.new()
			para.text = line
			UIFont.apply(para, UIFont.CAPTION)
			para.add_theme_color_override("font_color", Color(0.88, 0.88, 0.92))
			para.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			para.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			para.custom_minimum_size = Vector2(600, 0)
			text_column.add_child(para)
			_cs.call(8)

	# Trailing spacer before button
	_cs.call(200)

	# Second divider
	var divider2 := ColorRect.new()
	divider2.color = Color(1.0, 0.85, 0.2, 0.4)
	divider2.custom_minimum_size = Vector2(200, 2)
	var div_center2 := CenterContainer.new()
	div_center2.custom_minimum_size = Vector2(600, 20)
	div_center2.add_child(divider2)
	text_column.add_child(div_center2)

	_cs.call(80)

	# NEW CAREER button (scrolls in at the very end)
	var new_btn := _create_button("NEW CAREER", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	new_btn.pressed.connect(_on_new_career)
	var btn_wrapper := CenterContainer.new()
	btn_wrapper.custom_minimum_size = Vector2(600, 120)
	btn_wrapper.add_child(new_btn)
	text_column.add_child(btn_wrapper)

	_cs.call(400)

	# 4. SKIP button — fixed in bottom-right corner
	var skip_btn := Button.new()
	skip_btn.text = "SKIP"
	UIFont.apply_button(skip_btn, 20)
	skip_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.6))
	skip_btn.position = Vector2(620, 1220)
	skip_btn.size = Vector2(80, 40)
	var skip_style := StyleBoxEmpty.new()
	skip_btn.add_theme_stylebox_override("normal", skip_style)
	skip_btn.add_theme_stylebox_override("hover", skip_style)
	skip_btn.add_theme_stylebox_override("pressed", skip_style)
	skip_btn.add_theme_stylebox_override("focus", skip_style)
	full_screen.add_child(skip_btn)
	_credits_skip_btn = skip_btn

	# Store card index for deferred animation
	var card_idx: int = _cards.size()
	skip_btn.pressed.connect(_credits_skip)

	_card_animations[card_idx] = _start_credits_scroll.bind(text_column, skip_btn)
	_add_card(card, "Credits")

func _start_credits_scroll(text_column: VBoxContainer, skip_btn: Button) -> void:
	# Wait for layout to settle so we can measure content height
	await get_tree().process_frame
	await get_tree().process_frame

	# Measure total content height
	var content_height: float = 0.0
	for child in text_column.get_children():
		content_height += child.size.y

	# Scroll from below screen (y=1280) up until the NEW CAREER button
	# reaches roughly the centre of the screen
	var end_y: float = -(content_height - 900)
	var total_distance: float = 1280.0 - end_y
	var scroll_speed: float = 62.0
	var duration: float = total_distance / scroll_speed

	_credits_tween = create_tween()
	_credits_tween.tween_property(text_column, "position:y", end_y, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	_credits_tween.finished.connect(func(): skip_btn.visible = false)

func _credits_skip() -> void:
	if _credits_tween and _credits_tween.is_running():
		_credits_tween.kill()
	if _credits_skip_btn:
		_credits_skip_btn.visible = false
	if _credits_text_column:
		var content_height: float = 0.0
		for child in _credits_text_column.get_children():
			content_height += child.size.y
		_credits_text_column.position.y = -(content_height - 900)


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
		2: "Your mates are going quiet.",
		"career_over": "Three-time champion.\nMake that four.\nSteve raises a pint. You don't.",
		"retry": "ENTER AGAIN",
	},
	# Level 4 (Edward)
	4: {
		1: "Edward adjusts his glasses.\n\"Interesting match.\"\nHe doesn't mean it.",
		2: "The coach shakes her head.",
		"career_over": "Three county finals. Three losses.\nEdward doesn't celebrate.\nHe just packs his darts away.",
		"retry": "TRY AGAIN",
	},
	# Level 5 (Mad Dog) -- win or bust
	5: {
		"career_over": "Mad Dog doesn't shake hands.\nShe just walks away.\n\nYou catch a train home in silence.",
	},
	# Level 6 (Lars) -- win or bust
	6: {
		"career_over": "So close.\nSo close.",
	},
	# Level 7 (Vinnie "The Gold") -- win or bust
	7: {
		"career_over": "Gold confetti. Vinnie's confetti.\nNot yours.\n\nYou buy a kebab on the way to the station.",
	},
}

# ======================================================
# EXHIBITION RESULT CARDS
# ======================================================

func _build_exhibition_result_cards() -> void:
	var opp_id: String = GameState.opponent_id
	var opp_name: String = OpponentData.get_display_name(opp_id)
	var opp_nick: String = OpponentData.get_nickname(opp_id)

	var card := _create_card()

	_add_spacer(card, 150)

	if GameState.match_won:
		var win_label := Label.new()
		win_label.text = "EXHIBITION WIN"
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
		prize_label.text = _format_money(GameState.match_prize)
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
	else:
		var loss_label := Label.new()
		loss_label.text = "EXHIBITION LOSS"
		UIFont.apply(loss_label, UIFont.SCREEN_TITLE)
		loss_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		loss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		loss_label.custom_minimum_size = Vector2(640, 90)
		card.add_child(loss_label)

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

		var no_harm := Label.new()
		no_harm.text = "No harm done.\nBack to the hub."
		UIFont.apply(no_harm, UIFont.HEADING)
		no_harm.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		no_harm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_harm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		no_harm.custom_minimum_size = Vector2(640, 100)
		card.add_child(no_harm)

		_add_spacer(card, 20)

		var balance_label := Label.new()
		balance_label.text = "Balance: " + _format_money(CareerState.money)
		UIFont.apply(balance_label, UIFont.BODY)
		balance_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		balance_label.custom_minimum_size = Vector2(640, 50)
		card.add_child(balance_label)

	_add_spacer(card, 80)

	var hub_btn := _create_button("BACK TO HUB", Color(0.15, 0.15, 0.4), Color(0.3, 0.3, 0.7))
	hub_btn.pressed.connect(_on_exhibition_return)
	var hub_wrapper := CenterContainer.new()
	hub_wrapper.custom_minimum_size = Vector2(640, 100)
	hub_wrapper.add_child(hub_btn)
	card.add_child(hub_wrapper)

	_add_card(card, "Exhibition Result")


func _on_exhibition_return() -> void:
	CareerState.exhibition_mode = false
	# Restore career opponent on GameState so the hub shows the right info
	var career_opp_id: String = OpponentData.OPPONENT_ORDER[CareerState.career_level - 1]
	var career_opp: Dictionary = OpponentData.get_opponent(career_opp_id)
	GameState.opponent_id = career_opp_id
	GameState.is_vs_ai = true
	if career_opp["game_mode"] == "rtc":
		GameState.game_mode = GameState.GameMode.ROUND_THE_CLOCK
		GameState.starting_score = 0
	else:
		GameState.game_mode = GameState.GameMode.COUNTDOWN
		GameState.starting_score = career_opp["starting_score"]
	GameState.dart_tier = max(0, CareerState.dart_tier_owned)
	get_tree().change_scene_to_file("res://scenes/between_match_hub.tscn")


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
# TRADER PROFIT CARD (post-match, when pending sale > 0)
# ======================================================

func _build_trader_profit_card() -> void:
	if CareerState.inflatables_pending_sale <= 0:
		return

	var level: int = CareerState.career_level
	# Selling happens at the level we just played (career_level was already advanced for wins)
	# For wins, career_level was bumped before this — use the opponent's level
	var opp_id: String = GameState.opponent_id
	var opp_level: int = OpponentData.get_opponent(opp_id)["level"]

	var result: Dictionary = MerchData.resolve_sale(CareerState.inflatables_pending_sale, opp_level)
	var sold: int = result["sold"]
	var revenue: int = result["revenue"]
	var unsold: int = result["unsold"]
	var flavour: String = result["flavour_text"]

	var item_name: String = MerchData.get_inflatable_name(GameState.character)

	var card := _create_card()
	_add_spacer(card, 60)

	# Trader companion panel
	var venue_config: Variant = MerchData.get_venue_config(opp_level)
	var venue_name: String = venue_config["venue_name"] if venue_config else "the venue"

	var dialogue: String = "\"Shifted " + str(sold) + " " + item_name + " at " + _format_money(venue_config["price_per_unit"]) + " each.\"\n\n" + flavour
	if unsold > 0:
		dialogue += "\n\n\"Got " + str(unsold) + " left. They'll keep.\""

	var trader_panel := _build_companion_panel(
		"THE TRADER",
		dialogue,
		Color(0.7, 0.7, 0.1), "T", "res://The Trader cropped.png", UIFont.PORTRAIT_XL
	)
	card.add_child(trader_panel)
	_add_spacer(card, 20)

	# Revenue display
	var revenue_label := Label.new()
	revenue_label.text = "+" + _format_money(revenue)
	UIFont.apply(revenue_label, UIFont.HEADING)
	revenue_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.3))
	revenue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	revenue_label.custom_minimum_size = Vector2(640, 60)
	card.add_child(revenue_label)

	_add_spacer(card, 10)

	# Apply the sale (cost was already deducted at purchase time)
	CareerState.money += revenue
	_update_balance_overlay()
	CareerState.inflatables_stock -= sold
	# Unsold stock returns to inventory (already counted in stock minus sold)
	CareerState.inflatables_total_sold += sold
	CareerState.inflatables_total_profit += revenue
	CareerState.inflatables_pending_sale = 0

	# Check hustle
	var old_hustle: int = CareerState.hustle_stars
	CareerState.recalculate_hustle()

	_add_spacer(card, 10)
	_add_continue_button(card)
	_add_card(card, "Trader Profit")

	# If hustle increased, add a star flip card
	if CareerState.hustle_stars > old_hustle:
		var star_text: String
		if CareerState.hustle_stars >= 5:
			star_text = "Trading empire. Five star hustle."
		elif CareerState.hustle_stars >= 3:
			star_text = "The merch is moving."
		else:
			star_text = "Side hustle paying off."
		_build_star_flip_card("HUSTLE", old_hustle, CareerState.hustle_stars, star_text, null)


# ======================================================
# REUSABLE HELPERS — Companion Panel
# ======================================================

## Build a companion-style dialogue panel.
## If image_path is provided (non-empty), uses a real image as portrait.
## Otherwise uses a coloured rectangle with an initial letter.
func _build_companion_panel(speaker_name: String, dialogue_text: String,
		portrait_color: Color, portrait_initial: String,
		image_path: String = "", portrait_height: int = UIFont.PORTRAIT_S) -> PanelContainer:
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
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

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
			portrait.custom_minimum_size = Vector2(560, portrait_height)
			vbox.add_child(portrait)
	else:
		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(560, portrait_height)
		var bg := ColorRect.new()
		bg.position = Vector2.ZERO
		bg.size = Vector2(560, portrait_height)
		bg.color = portrait_color
		wrapper.add_child(bg)
		var initial := Label.new()
		initial.text = portrait_initial
		initial.position = Vector2.ZERO
		initial.size = Vector2(560, portrait_height)
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

	# Dialogue text — CAPTION (28pt) gives breathing room on tight cards
	var dialogue := Label.new()
	dialogue.text = dialogue_text
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue.custom_minimum_size = Vector2(560, 0)
	dialogue.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	UIFont.apply(dialogue, UIFont.CAPTION)
	vbox.add_child(dialogue)

	panel.add_child(vbox)
	return panel

# ======================================================
# REUSABLE HELPERS — Food Card
# ======================================================

## L2 kebab shop — three food choices (all free, all +1 heft), same forced pattern.
func _build_kebab_card() -> void:
	var can_gain_heft := CareerState.heft_tier < 5

	var card := _create_card()

	# --- Original group (visible by default) ---
	var original_group := VBoxContainer.new()
	original_group.add_theme_constant_override("separation", 0)

	_add_spacer(original_group, 100)

	var title_label := Label.new()
	title_label.text = "KEBAB SHOP"
	UIFont.apply(title_label, UIFont.HEADING)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.custom_minimum_size = Vector2(640, 60)
	original_group.add_child(title_label)

	_add_spacer(original_group, 15)

	var desc_label := Label.new()
	desc_label.text = "Drunken walk home.\nAlan steers you into the kebab shop.\nTime to soak up the booze."
	UIFont.apply(desc_label, UIFont.BODY)
	desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(640, 100)
	original_group.add_child(desc_label)

	_add_spacer(original_group, 20)

	# Three kebab shop options — all do the same thing (heft +1)
	var food_options := [
		["LAMB DONER, EXTRA CHILLI", Color(0.6, 0.15, 0.1), Color(0.85, 0.3, 0.2)],
		["CHEESY CHIPS", Color(0.6, 0.5, 0.1), Color(0.85, 0.75, 0.2)],
		["CHICKEN SHISH", Color(0.15, 0.4, 0.15), Color(0.3, 0.65, 0.3)],
	]

	# Label ref for the star flip quip — set after star flip card is built
	var heft_quip_ref: Array = [null]

	for i in food_options.size():
		var opt: Array = food_options[i]
		var btn := _create_button(opt[0], opt[1], opt[2])
		btn.custom_minimum_size = Vector2(620, 70)
		UIFont.apply_button(btn, UIFont.BODY)
		var idx: int = i
		btn.pressed.connect(func():
			# Cheesy chips aren't a kebab
			if heft_quip_ref[0] and idx == 1:
				heft_quip_ref[0].text = "Chips consumed.\nProfessional fuel."
			if can_gain_heft:
				CareerState.heft_tier += 1
			_advance_card()
		)
		var wrapper := CenterContainer.new()
		wrapper.custom_minimum_size = Vector2(640, 80)
		wrapper.add_child(btn)
		original_group.add_child(wrapper)

	_add_spacer(original_group, 5)

	var skip_btn := _create_button("NO THANKS", Color(0.2, 0.2, 0.25), Color(0.4, 0.4, 0.45))
	skip_btn.custom_minimum_size = Vector2(620, 70)
	UIFont.apply_button(skip_btn, UIFont.BODY)
	var skip_wrapper := CenterContainer.new()
	skip_wrapper.custom_minimum_size = Vector2(640, 80)
	skip_wrapper.add_child(skip_btn)
	original_group.add_child(skip_wrapper)

	card.add_child(original_group)

	# --- Insistence group (hidden by default) ---
	var insistence_group := VBoxContainer.new()
	insistence_group.add_theme_constant_override("separation", 0)
	insistence_group.visible = false

	_add_spacer(insistence_group, 60)

	var insist_data: Dictionary = FOOD_INSISTENCE[2]
	var insist_panel := _build_companion_panel(
		insist_data["speaker"],
		"\"" + insist_data["first"] + "\"",
		insist_data["color"], insist_data["initial"], insist_data["image"], UIFont.PORTRAIT_XL
	)
	insistence_group.add_child(insist_panel)

	_add_spacer(insistence_group, 30)

	var ok_btn := _create_button("OK", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5))
	var ok_wrapper := CenterContainer.new()
	ok_wrapper.custom_minimum_size = Vector2(640, 100)
	ok_wrapper.add_child(ok_btn)
	insistence_group.add_child(ok_wrapper)

	card.add_child(insistence_group)

	# --- Button logic with decline tracking ---
	var decline_count := [0]

	skip_btn.pressed.connect(func():
		decline_count[0] += 1
		if decline_count[0] == 1:
			original_group.visible = false
			insistence_group.visible = true
		else:
			if can_gain_heft:
				CareerState.heft_tier += 1
			_advance_card()
	)

	ok_btn.pressed.connect(func():
		insistence_group.visible = false
		original_group.visible = true
	)

	_add_card(card, "Kebab Shop")

	if can_gain_heft:
		_build_star_flip_card("HEFT", CareerState.heft_tier,
			CareerState.heft_tier + 1, "Kebab consumed.\nProfessional fuel.", null)
		# Find the quip label on the star flip card so buttons can update it
		var star_card: Control = _cards[_cards.size() - 1]
		for child in star_card.get_children():
			if child is Label and child.text == "Kebab consumed.\nProfessional fuel.":
				heft_quip_ref[0] = child
				break

## Build a food offer card with EAT / NO THANKS buttons.
## If player can't afford cost, the food card AND heft star flip are both skipped.
## If heft is already at max (5), only the food card is shown (no star flip).
func _build_food_card(title: String, description: String,
		button_text: String, cost: int, heft_quip: String, level: int = 0) -> void:
	var can_gain_heft := CareerState.heft_tier < 5
	# If player can't afford, companion covers it (cost waived)
	var actual_cost: int = cost if CareerState.money >= cost else 0

	var card := _create_card()

	# --- Original group (visible by default) ---
	var original_group := VBoxContainer.new()
	original_group.add_theme_constant_override("separation", 0)

	_add_spacer(original_group, 150)

	var title_label := Label.new()
	title_label.text = title
	UIFont.apply(title_label, UIFont.HEADING)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.custom_minimum_size = Vector2(640, 70)
	original_group.add_child(title_label)

	_add_spacer(original_group, 30)

	var desc_label := Label.new()
	desc_label.text = description
	UIFont.apply(desc_label, UIFont.BODY)
	desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(640, 120)
	original_group.add_child(desc_label)

	if actual_cost > 0:
		_add_spacer(original_group, 10)
		var cost_label := Label.new()
		cost_label.text = "Cost: " + _format_money(actual_cost)
		UIFont.apply(cost_label, UIFont.BODY)
		cost_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.custom_minimum_size = Vector2(640, 40)
		original_group.add_child(cost_label)

	_add_spacer(original_group, 50)

	var eat_btn := _create_button(button_text, Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
	var eat_wrapper := CenterContainer.new()
	eat_wrapper.custom_minimum_size = Vector2(640, 100)
	eat_wrapper.add_child(eat_btn)
	original_group.add_child(eat_wrapper)

	_add_spacer(original_group, 10)

	var skip_btn := _create_button("NO THANKS", Color(0.2, 0.2, 0.25), Color(0.4, 0.4, 0.45))
	var skip_wrapper := CenterContainer.new()
	skip_wrapper.custom_minimum_size = Vector2(640, 100)
	skip_wrapper.add_child(skip_btn)
	original_group.add_child(skip_wrapper)

	card.add_child(original_group)

	# --- Insistence group (hidden by default) ---
	var insistence_group := VBoxContainer.new()
	insistence_group.add_theme_constant_override("separation", 0)
	insistence_group.visible = false

	_add_spacer(insistence_group, 60)

	var insist_data: Dictionary = FOOD_INSISTENCE.get(level, FOOD_INSISTENCE[2])
	var insist_panel := _build_companion_panel(
		insist_data["speaker"],
		"\"" + insist_data["first"] + "\"",
		insist_data["color"], insist_data["initial"], insist_data["image"], UIFont.PORTRAIT_XL
	)
	insistence_group.add_child(insist_panel)

	_add_spacer(insistence_group, 30)

	var ok_btn := _create_button("OK", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5))
	var ok_wrapper := CenterContainer.new()
	ok_wrapper.custom_minimum_size = Vector2(640, 100)
	ok_wrapper.add_child(ok_btn)
	insistence_group.add_child(ok_wrapper)

	card.add_child(insistence_group)

	# --- Button logic with decline tracking ---
	var decline_count := [0]

	eat_btn.pressed.connect(func():
		if actual_cost > 0:
			CareerState.money -= actual_cost
			_update_balance_overlay()
		if can_gain_heft:
			CareerState.heft_tier += 1
		_advance_card()
	)

	skip_btn.pressed.connect(func():
		decline_count[0] += 1
		if decline_count[0] == 1:
			original_group.visible = false
			insistence_group.visible = true
		else:
			# Second decline — force it (companion covers cost if needed)
			if actual_cost > 0:
				CareerState.money -= actual_cost
				_update_balance_overlay()
			if can_gain_heft:
				CareerState.heft_tier += 1
			_advance_card()
	)

	ok_btn.pressed.connect(func():
		insistence_group.visible = false
		original_group.visible = true
	)

	_add_card(card, "Food: " + title)

	# Only add heft star flip if player can still gain
	if can_gain_heft:
		_build_star_flip_card("HEFT", CareerState.heft_tier,
			CareerState.heft_tier + 1, heft_quip, null)

# ======================================================
# REUSABLE HELPERS — Star Flip Card
# ======================================================

## Build a player stats card with one star row that flips from old_val to new_val.
## set_callback is called when the animation fires (to update CareerState).
## If set_callback is null, the caller has already updated the value.
## portrait_override: if non-empty, uses this image path instead of the tier-based portrait.
func _build_star_flip_card(star_name: String, old_val: int, new_val: int,
		quip_text: String, set_callback, portrait_override: String = "") -> void:
	var card := _create_card()
	_add_spacer(card, 15)

	# Determine appearance tier BEFORE this star change for golden flash crossfade
	var old_appearance_tier := CareerState.calculate_appearance_tier()

	# Use tier-aware portrait image if in career mode (unless overridden)
	var portrait_path: String
	if portrait_override != "":
		portrait_path = portrait_override
	elif CareerState.career_mode_active:
		portrait_path = DartData.get_profile_image_for_tier(GameState.character, old_appearance_tier)
	else:
		portrait_path = DartData.get_profile_image(GameState.character)

	# Portrait container (holds both old and new images for crossfade)
	# Hardcoded 420px — top third of screen, big enough to see detail.
	var portrait_h := 420
	var portrait_holder := Control.new()
	portrait_holder.custom_minimum_size = Vector2(640, portrait_h)
	portrait_holder.clip_contents = true

	var old_img := TextureRect.new()
	var tex := load(portrait_path)
	if tex:
		old_img.texture = tex
	old_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	old_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	old_img.custom_minimum_size = Vector2(640, portrait_h)
	old_img.position = Vector2.ZERO
	old_img.size = Vector2(640, portrait_h)
	portrait_holder.add_child(old_img)

	# Pre-build new tier image (hidden — used if appearance tier changes)
	var new_img := TextureRect.new()
	new_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	new_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	new_img.custom_minimum_size = Vector2(640, portrait_h)
	new_img.position = Vector2.ZERO
	new_img.size = Vector2(640, portrait_h)
	new_img.modulate.a = 0.0
	portrait_holder.add_child(new_img)

	# Gold flash overlay (ColorRect that pulses gold during transition)
	var gold_flash := ColorRect.new()
	gold_flash.color = Color(1.0, 0.85, 0.2, 0.0)
	gold_flash.position = Vector2.ZERO
	gold_flash.size = Vector2(640, portrait_h)
	gold_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_holder.add_child(gold_flash)

	card.add_child(portrait_holder)

	_add_spacer(card, 10)

	var char_name: String = DartData.get_full_name(GameState.character)
	var name_label := Label.new()
	if CareerState.nickname_active:
		var char_nick: String = DartData.get_character_nickname(GameState.character)
		name_label.text = char_name + '\n"' + char_nick + '"'
		name_label.custom_minimum_size = Vector2(640, 90)
	else:
		name_label.text = char_name
		name_label.custom_minimum_size = Vector2(640, 60)
	UIFont.apply(name_label, UIFont.HEADING)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_label)

	_add_spacer(card, 15)

	# Build all 4 star rows — the target row gets a flip animation
	# Non-target rows use placeholder containers so they show CURRENT values
	# at display time, not stale values from build time.
	var star_categories := ["SKILL", "HEFT", "HUSTLE", "SWAGGER"]

	var flip_wrapper: Control = null
	var before_slots: TextureRect = null
	var after_slots: TextureRect = null
	var non_target_placeholders: Array[Control] = []

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
			flip_wrapper.custom_minimum_size = Vector2(260, 50)
			flip_wrapper.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			flip_wrapper.pivot_offset = Vector2(130, 25)

			before_slots = _build_star_image(old_val)
			before_slots.position = Vector2.ZERO
			before_slots.size = Vector2(260, 50)
			flip_wrapper.add_child(before_slots)

			after_slots = _build_star_image(new_val)
			after_slots.position = Vector2.ZERO
			after_slots.size = Vector2(260, 50)
			after_slots.visible = false
			flip_wrapper.add_child(after_slots)

			row.add_child(flip_wrapper)
			card.add_child(row)
		else:
			# Placeholder — filled at display time with live CareerState values
			var placeholder := VBoxContainer.new()
			placeholder.custom_minimum_size = Vector2(640, 50)
			placeholder.set_meta("star_cat", cat)
			card.add_child(placeholder)
			non_target_placeholders.append(placeholder)

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

	# Deferred animation — star flip + optional golden flash crossfade
	var card_idx := _cards.size() - 1
	var _fw := flip_wrapper
	var _bl := before_slots
	var _al := after_slots
	var _cb = set_callback
	var _old_tier := old_appearance_tier
	var _old_img := old_img
	var _new_img := new_img
	var _gold_flash := gold_flash
	var _placeholders := non_target_placeholders
	_card_animations[card_idx] = func():
		if _cb != null and _cb is Callable:
			_cb.call()

		# Populate non-target star rows with LIVE CareerState values
		var live_values := {
			"SKILL": CareerState.skill_stars,
			"HEFT": CareerState.heft_tier,
			"HUSTLE": CareerState.hustle_stars,
			"SWAGGER": CareerState.swagger_stars,
		}
		for ph in _placeholders:
			var cat_name: String = ph.get_meta("star_cat")
			# Clear any previous children (in case of re-display)
			for child in ph.get_children():
				child.queue_free()
			var row := _career_stars_row(cat_name, live_values[cat_name], 5)
			ph.add_child(row)

		# Check if appearance tier changed after the callback updated stars
		var _new_tier := CareerState.calculate_appearance_tier()
		var tier_changed := _new_tier > _old_tier

		# If tier changed, load the new portrait
		if tier_changed:
			var new_path: String = DartData.get_profile_image_for_tier(GameState.character, _new_tier)
			var new_tex = load(new_path)
			if new_tex:
				_new_img.texture = new_tex

		# Star flip animation
		var tween := create_tween()
		tween.tween_property(_fw, "scale:y", 0.0, 0.15).set_delay(0.8)
		tween.tween_callback(func():
			_bl.visible = false
			_al.visible = true
		)
		tween.tween_property(_fw, "scale:y", 1.0, 0.15)

		# Golden flash crossfade if tier changed (starts after star flip completes)
		if tier_changed:
			tween.tween_property(_gold_flash, "color:a", 0.6, 0.2).set_delay(0.2)
			tween.tween_callback(func():
				_new_img.modulate.a = 1.0
			)
			tween.tween_property(_gold_flash, "color:a", 0.0, 0.35)
			tween.tween_property(quip, "modulate:a", 1.0, 0.3).set_delay(0.2)
			tween.tween_property(cont_wrapper, "modulate:a", 1.0, 0.3).set_delay(0.2)
		else:
			tween.tween_property(quip, "modulate:a", 1.0, 0.3).set_delay(0.3)
			tween.tween_property(cont_wrapper, "modulate:a", 1.0, 0.3).set_delay(0.2)

# ======================================================
# REUSABLE HELPERS — Celebration Reaction Card
# ======================================================

## Build a post-match celebration card. Uses the player's chosen celebration style.
## Shows the celebration, then the opponent's reaction.
## Skipped if player hasn't chosen a celebration yet (pre-L3).
func _build_celebration_reaction_card(opponent_name: String, reaction_text: String, opponent_image: String) -> void:
	if CareerState.celebration_style < 0:
		return  # No celebration chosen yet

	var celeb_names := ["THE FLEX", "REEL IN THE FISH", "DOWN A PINT"]
	var style_idx: int = clampi(CareerState.celebration_style, 0, 2)

	# Celebration text progresses across levels
	var level: int = CareerState.career_level
	var celeb_text: String
	if level <= 4:
		# First celebration — introduce the move
		celeb_text = [
			"You step forward. Arms out. Muscles tense.\n\nThe crowd erupts.",
			"You step forward. Mime casting the rod. Wind the reel. Heave it in.\n\nThe crowd erupts.",
			"You grab a pint off the oche. Skull it in one.\n\nThe crowd erupts.",
		][style_idx]
	elif level == 5:
		# Second time — becoming a habit
		celeb_text = [
			"The Flex is back. You're making this a habit.\n\nThe crowd knows what's coming.",
			"Reel In The Fish is back. It's becoming your thing.\n\nThe crowd sees it coming before you've even started.",
			"Down a Pint is back. It's becoming a tradition.\n\nThe crowd are cheering before you've even picked up the glass.",
		][style_idx]
	else:
		# Third time onwards — it's the signature move now
		celeb_text = [
			"The customary Flex. Arms out. Muscles tense.\n\nHalf the crowd are doing it with you now.",
			"The customary Reel In The Fish. Cast, wind, heave.\n\nHalf the crowd are doing it with you now.",
			"The customary pint. You skull it on the oche.\n\nHalf the crowd are raising their glasses with you.",
		][style_idx]

	# Card 1: The celebration itself
	var celeb_card := _create_card()
	_add_spacer(celeb_card, 160)
	var celeb_header := Label.new()
	celeb_header.text = "You celebrate..."
	UIFont.apply(celeb_header, UIFont.BODY)
	celeb_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	celeb_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	celeb_header.custom_minimum_size = Vector2(640, 40)
	celeb_card.add_child(celeb_header)
	_add_spacer(celeb_card, 10)
	var celeb_title := Label.new()
	celeb_title.text = celeb_names[style_idx]
	UIFont.apply(celeb_title, UIFont.SUBHEADING)
	celeb_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	celeb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	celeb_title.custom_minimum_size = Vector2(640, 60)
	celeb_card.add_child(celeb_title)
	_add_spacer(celeb_card, 30)
	var celeb_desc := Label.new()
	celeb_desc.text = celeb_text
	UIFont.apply(celeb_desc, UIFont.BODY)
	celeb_desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	celeb_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	celeb_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	celeb_desc.custom_minimum_size = Vector2(640, 80)
	celeb_card.add_child(celeb_desc)
	_add_spacer(celeb_card, 40)
	_add_continue_button(celeb_card)
	_add_card(celeb_card, opponent_name + " Celebration")

	# Card 2: Opponent reaction
	var react_card := _create_card()
	_add_spacer(react_card, 60)
	var react_panel := _build_companion_panel(
		opponent_name,
		reaction_text,
		Color.BLACK, "", opponent_image, UIFont.PORTRAIT_XL
	)
	react_card.add_child(react_panel)
	_add_spacer(react_card, 30)
	_add_continue_button(react_card)
	_add_card(react_card, opponent_name + " Reaction")

# ======================================================
# REUSABLE HELPERS — Bridge Card
# ======================================================

func _build_bridge_card(time_text: String, venue_name: String,
		vibe_text: String, entry_fee: int) -> void:
	var card := _create_card()
	_add_spacer(card, 120)

	if time_text != "":
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
		nickname: String, stars: Dictionary, game_mode_text: String, continue_only: bool = false) -> void:
	var card := _create_card()

	_add_spacer(card, 30)

	# "YOUR OPPONENT" header (yellow -- standard for all opponent reveal cards)
	var header := Label.new()
	header.text = "YOUR OPPONENT"
	UIFont.apply(header, UIFont.SUBHEADING)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.custom_minimum_size = Vector2(640, 50)
	card.add_child(header)

	_add_spacer(card, 5)

	# Portrait (real image if available, otherwise placeholder)
	var image_path: String = OpponentData.get_image(opp_id)
	if image_path != "":
		var tex := load(image_path)
		if tex:
			var img := TextureRect.new()
			img.texture = tex
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.custom_minimum_size = Vector2(640, 420)
			card.add_child(img)
	else:
		# Placeholder
		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(640, 420)
		var bg := ColorRect.new()
		bg.position = Vector2(140, 0)
		bg.size = Vector2(360, 420)
		bg.color = Color(0.2, 0.2, 0.25)
		wrapper.add_child(bg)
		var initial := Label.new()
		initial.text = display_name.left(1)
		initial.position = Vector2(140, 0)
		initial.size = Vector2(360, 420)
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UIFont.apply(initial, UIFont.SCREEN_TITLE)
		initial.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		wrapper.add_child(initial)
		card.add_child(wrapper)

	_add_spacer(card, 5)

	# Name + nickname
	var name_label := Label.new()
	name_label.text = display_name + '\n"' + nickname + '"'
	UIFont.apply(name_label, UIFont.HEADING)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(640, 80)
	card.add_child(name_label)

	_add_spacer(card, 5)

	# Star ratings
	for cat in ["SKILL", "HEFT", "HUSTLE", "SWAGGER"]:
		card.add_child(_career_stars_row(cat, stars.get(cat, 0), 5))

	_add_spacer(card, 5)

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

	_add_spacer(card, 10)

	if continue_only:
		_add_continue_button(card)
	else:
		var next_btn := _create_button("NEXT MATCH", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4))
		next_btn.pressed.connect(_on_next_match)
		var next_wrapper := CenterContainer.new()
		next_wrapper.custom_minimum_size = Vector2(640, 100)
		next_wrapper.add_child(next_btn)
		card.add_child(next_wrapper)

	_add_card(card, display_name + " Stats")

# ======================================================
# REUSABLE HELPERS — Pre-Match Drinking Card
# ======================================================

func _build_pre_drink_card() -> void:
	var level := CareerState.career_level
	var config = DrinkManager.get_level_config(level)
	if config == null:
		return
	# If player can't afford, companion covers the cost
	var session_cost: int = config["pre_drink_price"]
	var companion_covering := false
	if session_cost > 0 and CareerState.money < session_cost:
		session_cost = 0
		companion_covering = true

	# Companion image mapping
	var companion_images := {
		"Alan": "res://Mate for Level 2 - Alan.png",
		"mates": "res://Group of mates for Level 3 better trimmed.png",
		"coach": "res://Coach cropped.png",
		"manager": "res://Manager cropped new.png",
		"entourage": "res://Manager and full team cropped new.png",
	}

	var comp_type: String = config["companion"]
	var card := _create_card()
	_add_spacer(card, 15)

	# Companion portrait at top
	var portrait_path: String = companion_images.get(comp_type, "")
	if portrait_path != "":
		var tex = load(portrait_path)
		if tex:
			var img := TextureRect.new()
			img.texture = tex
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.custom_minimum_size = Vector2(640, UIFont.PORTRAIT_M)
			card.add_child(img)
			_add_spacer(card, 10)

	# Setting line (where you are)
	var setting_label := Label.new()
	setting_label.text = config["setting"]
	UIFont.apply(setting_label, UIFont.CAPTION)
	setting_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	setting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setting_label.custom_minimum_size = Vector2(640, 0)
	card.add_child(setting_label)

	_add_spacer(card, 10)

	# Companion's intro line
	var intro := Label.new()
	intro.text = config["intro"]
	UIFont.apply(intro, UIFont.BODY)
	intro.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(640, 0)
	card.add_child(intro)

	_add_spacer(card, 8)

	# Price if not free (or companion covering)
	if config["pre_drink_price"] > 0:
		var price_label := Label.new()
		if companion_covering:
			price_label.text = "On the house. Companion's treat."
			UIFont.apply(price_label, UIFont.CAPTION)
			price_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4))
		else:
			price_label.text = "Cost: " + _format_money(session_cost)
			UIFont.apply(price_label, UIFont.CAPTION)
			price_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.custom_minimum_size = Vector2(640, 30)
		card.add_child(price_label)

	_add_spacer(card, 12)

	# Drinks + skip wrapper (hidden together on refusal)
	var drinks_group := VBoxContainer.new()
	drinks_group.add_theme_constant_override("separation", 0)

	# Drink box colours — each drink gets a distinct colour
	var box_colours := [
		Color(0.45, 0.25, 0.1),   # warm amber / whisky
		Color(0.2, 0.35, 0.15),   # mossy green / cider
		Color(0.35, 0.15, 0.3),   # plum / berry
	]

	# 3 random drink options — each as a coloured clickable panel
	var drinks := DrinkManager.get_random_drinks(3)
	for i in drinks.size():
		var drink = drinks[i]
		var box_col: Color = box_colours[i % box_colours.size()]

		# Coloured panel container
		var panel := PanelContainer.new()
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = box_col
		panel_style.corner_radius_top_left = 12
		panel_style.corner_radius_top_right = 12
		panel_style.corner_radius_bottom_left = 12
		panel_style.corner_radius_bottom_right = 12
		panel_style.content_margin_left = 18
		panel_style.content_margin_right = 18
		panel_style.content_margin_top = 14
		panel_style.content_margin_bottom = 14
		panel.add_theme_stylebox_override("panel", panel_style)
		panel.custom_minimum_size = Vector2(600, 0)

		# Content — name + description
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 4)

		var name_label := Label.new()
		name_label.text = drink["name"].to_upper()
		UIFont.apply(name_label, UIFont.BODY)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = drink["desc"]
		UIFont.apply(desc_label, UIFont.CAPTION)
		desc_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.75))
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(560, 0)
		content.add_child(desc_label)

		panel.add_child(content)

		var panel_wrapper := CenterContainer.new()
		panel_wrapper.custom_minimum_size = Vector2(640, 0)
		panel_wrapper.add_child(panel)
		drinks_group.add_child(panel_wrapper)

		# Make the panel clickable via gui_input
		var cb := func(u: int, p: int):
			if p > 0:
				CareerState.money -= p
				_update_balance_overlay()
			CareerState.pre_drink_units = u
			_advance_card()
		var bound_cb := cb.bind(drink["units"], session_cost)
		panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				bound_cb.call()
		)
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_add_spacer(drinks_group, 12)

	# Skip option
	var skip_btn := _create_button("NO THANKS", Color(0.2, 0.2, 0.25), Color(0.4, 0.4, 0.45))
	UIFont.apply_button(skip_btn, UIFont.CAPTION)
	skip_btn.custom_minimum_size = Vector2(400, 55)
	var skip_wrapper := CenterContainer.new()
	skip_wrapper.custom_minimum_size = Vector2(640, 60)
	skip_wrapper.add_child(skip_btn)
	drinks_group.add_child(skip_wrapper)

	card.add_child(drinks_group)

	# Refusal reaction — just text, no portrait (companion already visible at top)
	var refusal_label := Label.new()
	refusal_label.text = "\"Fair enough, but you're on your own out there, " + ("love" if DartData.get_is_female(GameState.character) else "mate") + ".\""
	UIFont.apply(refusal_label, UIFont.BODY)
	refusal_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	refusal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	refusal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	refusal_label.custom_minimum_size = Vector2(600, 0)
	refusal_label.visible = false
	card.add_child(refusal_label)
	_add_spacer(card, 30)
	var refusal_continue := _create_button("CONTINUE", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5))
	refusal_continue.visible = false
	var refusal_c_wrapper := CenterContainer.new()
	refusal_c_wrapper.custom_minimum_size = Vector2(640, 80)
	refusal_c_wrapper.add_child(refusal_continue)
	card.add_child(refusal_c_wrapper)
	refusal_continue.pressed.connect(func():
		CareerState.pre_drink_units = 0
		CareerState.pre_drink_refused = true
		_advance_card()
	)

	skip_btn.pressed.connect(func():
		# Hide all drink options + skip, show refusal text + continue
		drinks_group.visible = false
		refusal_label.visible = true
		refusal_continue.visible = true
	)

	_add_card(card, "Pre-Drinks L" + str(level))

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
	var next_mode: String
	if next_opp["game_mode"] == "rtc":
		next_mode = "Round the Clock"
	else:
		var legs: int = next_opp.get("legs_to_win", 1)
		if legs > 1:
			next_mode = str(next_opp["starting_score"]) + ", Best of " + str(legs * 2 - 1)
		else:
			next_mode = str(next_opp["starting_score"])
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
	_update_balance_overlay()

func _advance_card() -> void:
	if _current_card < _cards.size() - 1:
		_show_card(_current_card + 1)
	elif _retry_mode:
		get_tree().change_scene_to_file("res://scenes/match.tscn")

func _add_continue_button(card: Control) -> void:
	var top_fill := Control.new()
	top_fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(top_fill)
	var btn := _create_button("CONTINUE", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5))
	btn.pressed.connect(_advance_card)
	var wrapper := CenterContainer.new()
	wrapper.custom_minimum_size = Vector2(640, 100)
	wrapper.add_child(btn)
	card.add_child(wrapper)
	var bottom_fill := Control.new()
	bottom_fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(bottom_fill)

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

# ── Balance overlay (career mode — top centre) ──

func _build_balance_overlay() -> void:
	if not CareerState.career_mode_active:
		return

	_balance_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.85)
	style.border_color = Color.WHITE
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_balance_panel.add_theme_stylebox_override("panel", style)
	_balance_panel.position = Vector2(280, 2)
	_balance_panel.size = Vector2(160, 24)
	_balance_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_balance_label_overlay = Label.new()
	UIFont.apply(_balance_label_overlay, 24)
	_balance_label_overlay.add_theme_color_override("font_color", Color.WHITE)
	_balance_label_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balance_label_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_balance_label_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_balance_label_overlay.text = _format_money(CareerState.money)

	_balance_panel.add_child(_balance_label_overlay)
	add_child(_balance_panel)

func _update_balance_overlay() -> void:
	if _balance_label_overlay:
		_balance_label_overlay.text = _format_money(CareerState.money)

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
	img.custom_minimum_size = Vector2(260, 50)
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
	# Auto-play with best owned darts
	GameState.dart_tier = max(0, CareerState.dart_tier_owned)
	if CareerState.career_level >= 3:
		get_tree().change_scene_to_file("res://scenes/between_match_hub.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/match.tscn")

func _on_try_again() -> void:
	GameState.dart_tier = max(0, CareerState.dart_tier_owned)
	CareerState.pre_drink_units = 0
	# Clear existing cards from screen
	for card in _cards:
		if is_instance_valid(card):
			card.queue_free()
	_cards.clear()
	_card_animations.clear()
	_current_card = 0
	_retry_mode = true
	# Build pre-drink card (L2+ only — returns without building if no config)
	_build_pre_drink_card()
	if _cards.size() > 0:
		_show_card(0)
	else:
		# No pre-drink available (L1) — go straight to match
		get_tree().change_scene_to_file("res://scenes/match.tscn")

func _on_new_career() -> void:
	CareerState.reset()
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")
