extends Control

## Between-match hub screen — appears from L3 onwards after narrative cards.
## Player can eat, buy/sell merch, place bets, get sponsorship before proceeding.
## Options unlock progressively as career characters are met.

# Hub-specific pre-match food (different from narrative celebration meals)
const HUB_FOOD := {
	3: {"name": "Pie and chips", "cost": 500, "quip": "Social club canteen. Meat pie, chips, mushy peas."},
	4: {"name": "Curry", "cost": 0, "quip": "Indian round the corner. Tikka masala, rice, two naans.", "free_note": "Coach's treat"},
	5: {"name": "Carvery", "cost": 1200, "quip": "Hotel carvery. Three meats, five veg, Yorkshires."},
	6: {"name": "Fish and chips", "cost": 1500, "quip": "Chippy on the walk to the venue. Cod, chips, battered sausage."},
	7: {"name": "Five star steak", "cost": 5000, "quip": "Hotel restaurant. Fillet mignon, truffle sauce. The night before the final."},
}

# Glow Up — cosmetic shopping spree per level (money sink, no stat effect)
const GLOW_UP := {
	3: {"name": "Gold chain", "cost": 2000, "quip": "Market stall bling. Fake gold chain to go with the tattoos. Completing the look."},
	4: {"name": "Designer polo shirt", "cost": 5000, "quip": "Sports brand outlet. Polo shirt with the collar up. Very 2005."},
	5: {"name": "New trainers and watch", "cost": 8000, "quip": "Retail park shopping spree. White trainers, chunky watch. Looking the part."},
	6: {"name": "Full outfit and haircut", "cost": 15000, "quip": "High street makeover. New jeans, shirt, shoes, and a proper barber trim. Almost unrecognisable."},
	7: {"name": "Suit and cufflinks", "cost": 25000, "quip": "Suited and booted for the final. Three-piece, silk tie, monogrammed cufflinks. The full works."},
}

var _balance_label: Label
var _popup_overlay: ColorRect
var _popup_card: PanelContainer
var _popup_content_parent: VBoxContainer
var _eat_button: Button
var _has_eaten: bool = false
var _merch_buy_qty: int = 0
var _merch_sell_qty: int = 0
var _merch_sale_committed: bool = false

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Full dark bg
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Content area (no scrolling — everything fits in 1280px)
	var content := VBoxContainer.new()
	content.position = Vector2(40, 0)
	content.size = Vector2(640, 1280)
	content.add_theme_constant_override("separation", 0)
	add_child(content)

	_add_spacer(content, 20)

	# Balance display
	_balance_label = Label.new()
	_update_balance_label()
	UIFont.apply(_balance_label, UIFont.CAPTION)
	_balance_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.3))
	_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balance_label.custom_minimum_size = Vector2(640, 35)
	content.add_child(_balance_label)

	_add_spacer(content, 12)

	# Opponent info panel
	_build_opponent_panel(content)

	_add_spacer(content, 15)

	# "PREPARE FOR MATCH" header
	var prep_label := Label.new()
	prep_label.text = "PREPARE FOR MATCH"
	UIFont.apply(prep_label, UIFont.SUBHEADING)
	prep_label.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
	prep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prep_label.custom_minimum_size = Vector2(640, 45)
	content.add_child(prep_label)

	_add_spacer(content, 8)

	# Action buttons (only unlocked ones)
	_build_action_buttons(content)

	_add_spacer(content, 15)

	# PROCEED button
	var proceed_btn := _create_button("PROCEED TO MATCH", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4), UIFont.SUBHEADING, Vector2(620, 85))
	proceed_btn.pressed.connect(_on_proceed)
	var proceed_wrapper := CenterContainer.new()
	proceed_wrapper.custom_minimum_size = Vector2(640, 90)
	proceed_wrapper.add_child(proceed_btn)
	content.add_child(proceed_wrapper)

	_add_spacer(content, 15)

	# Popup system (on top of everything)
	_build_popup_system()


func _build_opponent_panel(parent: Control) -> void:
	var opp_id: String = GameState.opponent_id
	var opp: Dictionary = OpponentData.get_opponent(opp_id)
	var display_name: String = OpponentData.get_display_name(opp_id)
	var nickname: String = OpponentData.get_nickname(opp_id)

	# Panel container with companion styling
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.07, 0.12, 0.94)
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.content_margin_left = 15
	panel_style.content_margin_right = 15
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_color = Color(0.85, 0.6, 0.15, 0.6)
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)

	# "YOUR NEXT OPPONENT" header
	var header := Label.new()
	header.text = "YOUR NEXT OPPONENT"
	UIFont.apply(header, UIFont.CAPTION)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.custom_minimum_size = Vector2(600, 30)
	vbox.add_child(header)

	# Portrait (compact for hub)
	var image_path: String = OpponentData.get_image(opp_id)
	if image_path != "":
		var tex := load(image_path)
		if tex:
			var img := TextureRect.new()
			img.texture = tex
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.custom_minimum_size = Vector2(560, 80)
			vbox.add_child(img)
	else:
		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(560, 80)
		var prt_bg := ColorRect.new()
		prt_bg.position = Vector2(100, 0)
		prt_bg.size = Vector2(360, 80)
		prt_bg.color = Color(0.2, 0.2, 0.25)
		wrapper.add_child(prt_bg)
		var initial := Label.new()
		initial.text = display_name.left(1)
		initial.position = Vector2(100, 0)
		initial.size = Vector2(360, 80)
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UIFont.apply(initial, UIFont.HEADING)
		initial.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		wrapper.add_child(initial)
		vbox.add_child(wrapper)

	# Name + nickname
	var name_label := Label.new()
	name_label.text = display_name + ' "' + nickname + '"'
	UIFont.apply(name_label, UIFont.BODY)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(600, 0)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)

	# Game mode + venue + entry
	var legs: int = opp.get("legs_to_win", 1)
	var best_of: int = legs * 2 - 1
	var mode_text: String
	if opp["game_mode"] == "rtc":
		mode_text = "Round the Clock"
	else:
		mode_text = str(opp["starting_score"])
		if legs > 1:
			mode_text += " - Best of " + str(best_of)

	var venue: String = OpponentData.get_venue(opp_id, GameState.character)
	var details_text := mode_text + "\n" + venue

	var details := Label.new()
	details.text = details_text
	UIFont.apply(details, UIFont.CAPTION)
	details.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size = Vector2(600, 0)
	vbox.add_child(details)

	# Entry fee
	var buy_in: int = OpponentData.get_buy_in(opp_id)
	if buy_in > 0:
		var entry_label := Label.new()
		entry_label.text = "Entry: " + _format_money(buy_in)
		UIFont.apply(entry_label, UIFont.CAPTION)
		entry_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		entry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		entry_label.custom_minimum_size = Vector2(600, 30)
		vbox.add_child(entry_label)

	panel.add_child(vbox)
	parent.add_child(panel)


func _build_action_buttons(parent: Control) -> void:
	var level := CareerState.career_level

	# EAT — always available from L3
	_eat_button = _create_action_button("EAT")
	_eat_button.pressed.connect(_on_eat_pressed)
	parent.add_child(_center_button(_eat_button))

	_add_spacer(parent, 6)

	# GLOW UP — always available from L3
	var glow_btn := _create_action_button("GLOW UP")
	glow_btn.pressed.connect(_on_glow_up_pressed)
	parent.add_child(_center_button(glow_btn))

	_add_spacer(parent, 6)

	# BUY/SELL MERCH — from L3 (Trader met after L2 win)
	var merch_btn := _create_action_button("BUY/SELL MERCH")
	merch_btn.pressed.connect(_on_merch_pressed)
	parent.add_child(_center_button(merch_btn))

	if level >= 5:
		_add_spacer(parent, 6)
		var bet_btn := _create_action_button("PLACE A BET")
		bet_btn.pressed.connect(_on_bet_pressed)
		parent.add_child(_center_button(bet_btn))

	if level >= 6:
		_add_spacer(parent, 6)
		var sponsor_btn := _create_action_button("GET SPONSORSHIP")
		sponsor_btn.pressed.connect(_on_sponsor_pressed)
		parent.add_child(_center_button(sponsor_btn))

	# EXHIBITION MATCH — always available from L3
	_add_spacer(parent, 6)
	var exh_btn := _create_action_button("EXHIBITION MATCH")
	exh_btn.pressed.connect(_on_exhibition_pressed)
	parent.add_child(_center_button(exh_btn))


func _build_popup_system() -> void:
	# Dark overlay
	_popup_overlay = ColorRect.new()
	_popup_overlay.color = Color(0, 0, 0, 0.75)
	_popup_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_overlay.visible = false
	_popup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_popup_overlay)

	# Card panel
	_popup_card = PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.07, 0.12, 0.94)
	card_style.corner_radius_top_left = 14
	card_style.corner_radius_top_right = 14
	card_style.corner_radius_bottom_left = 14
	card_style.corner_radius_bottom_right = 14
	card_style.content_margin_left = 25
	card_style.content_margin_right = 25
	card_style.content_margin_top = 25
	card_style.content_margin_bottom = 25
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_color = Color(0.85, 0.6, 0.15, 0.6)
	_popup_card.add_theme_stylebox_override("panel", card_style)
	_popup_card.position = Vector2(40, 1280)  # Start off-screen below
	_popup_card.size = Vector2(640, 0)
	_popup_card.visible = false
	add_child(_popup_card)

	# Content container inside the card
	_popup_content_parent = VBoxContainer.new()
	_popup_content_parent.add_theme_constant_override("separation", 15)
	_popup_card.add_child(_popup_content_parent)


# ======================================================
# BUTTON HANDLERS
# ======================================================

func _on_eat_pressed() -> void:
	_show_popup(_build_food_popup())

func _on_glow_up_pressed() -> void:
	_show_popup(_build_glow_up_popup())

func _on_merch_pressed() -> void:
	if CareerState.trader_met:
		_merch_buy_qty = 0
		_merch_sell_qty = 0
		_merch_sale_committed = CareerState.inflatables_pending_sale > 0
		_show_popup(_build_merch_popup())
	else:
		_show_popup(_build_coming_soon("MERCH", "The Trader is setting up his stall. Inflatables, knock-off watches, and dodgy aftershave."))

func _on_bet_pressed() -> void:
	_show_popup(_build_coming_soon("BETTING", "Unknown Number has a proposition. Lose a leg on purpose. Big money if you do. Broken legs if you don't."))

func _on_sponsor_pressed() -> void:
	_show_popup(_build_coming_soon("SPONSORSHIP", "The Sponsor Rep has some interesting offers. Logos on your shirt, branding on your darts."))

func _on_exhibition_pressed() -> void:
	ExhibitionData.generate_matchup(CareerState.career_level)
	_show_popup(_build_exhibition_popup())

func _on_proceed() -> void:
	get_tree().change_scene_to_file("res://scenes/match.tscn")


# ======================================================
# POPUP BUILDERS
# ======================================================

func _build_food_popup() -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)

	var level := CareerState.career_level

	# Already eaten this visit?
	if _has_eaten:
		var title := Label.new()
		title.text = "ALREADY EATEN"
		UIFont.apply(title, UIFont.SUBHEADING)
		title.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.custom_minimum_size = Vector2(590, 50)
		content.add_child(title)

		var msg := Label.new()
		msg.text = "You've already had your fill. Save room for the match."
		UIFont.apply(msg, UIFont.BODY)
		msg.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg.custom_minimum_size = Vector2(590, 0)
		content.add_child(msg)

		var back_btn := _create_button("BACK", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5), UIFont.BODY, Vector2(400, 70))
		back_btn.pressed.connect(_dismiss_popup)
		var back_wrapper := CenterContainer.new()
		back_wrapper.custom_minimum_size = Vector2(590, 80)
		back_wrapper.add_child(back_btn)
		content.add_child(back_wrapper)
		return content

	# Get food for this level
	var food: Dictionary = HUB_FOOD.get(level, HUB_FOOD[7])  # Default to L7 food if beyond

	# Title
	var title := Label.new()
	title.text = food["name"].to_upper()
	UIFont.apply(title, UIFont.SUBHEADING)
	title.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(590, 50)
	content.add_child(title)

	# Quip
	var quip := Label.new()
	quip.text = food["quip"]
	UIFont.apply(quip, UIFont.BODY)
	quip.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	quip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quip.custom_minimum_size = Vector2(590, 0)
	content.add_child(quip)

	# Cost line
	var cost: int = food["cost"]
	if cost > 0:
		var cost_label := Label.new()
		cost_label.text = _format_money(cost)
		UIFont.apply(cost_label, UIFont.BODY)
		cost_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.custom_minimum_size = Vector2(590, 40)
		content.add_child(cost_label)
	elif food.has("free_note"):
		var free_label := Label.new()
		free_label.text = food["free_note"]
		UIFont.apply(free_label, UIFont.CAPTION)
		free_label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.3))
		free_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		free_label.custom_minimum_size = Vector2(590, 35)
		content.add_child(free_label)

	# Note — no stat effect (heft handled by narrative cards)
	var note := Label.new()
	note.text = "Line your stomach before the match. No stat effect."
	UIFont.apply(note, UIFont.CAPTION)
	note.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(590, 0)
	content.add_child(note)

	# Can't afford?
	if cost > 0 and CareerState.money < cost:
		var broke := Label.new()
		broke.text = "Can't afford it"
		UIFont.apply(broke, UIFont.CAPTION)
		broke.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
		broke.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		broke.custom_minimum_size = Vector2(590, 35)
		content.add_child(broke)

		var back_btn := _create_button("BACK", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5), UIFont.BODY, Vector2(400, 70))
		back_btn.pressed.connect(_dismiss_popup)
		var back_wrapper := CenterContainer.new()
		back_wrapper.custom_minimum_size = Vector2(590, 80)
		back_wrapper.add_child(back_btn)
		content.add_child(back_wrapper)
		return content

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	btn_row.custom_minimum_size = Vector2(590, 80)

	var eat_btn := _create_button("EAT", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4), UIFont.BODY, Vector2(250, 70))
	eat_btn.pressed.connect(_on_food_accept.bind(cost))
	btn_row.add_child(eat_btn)

	var skip_btn := _create_button("NO THANKS", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5), UIFont.BODY, Vector2(250, 70))
	skip_btn.pressed.connect(_dismiss_popup)
	btn_row.add_child(skip_btn)

	content.add_child(btn_row)
	return content


func _build_glow_up_popup() -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)

	var level := CareerState.career_level
	var glow: Dictionary = GLOW_UP.get(level, GLOW_UP[7])

	# Title
	var title := Label.new()
	title.text = "GLOW UP"
	UIFont.apply(title, UIFont.SUBHEADING)
	title.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(590, 50)
	content.add_child(title)

	# Item name
	var item := Label.new()
	item.text = glow["name"]
	UIFont.apply(item, UIFont.BODY)
	item.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.custom_minimum_size = Vector2(590, 40)
	content.add_child(item)

	# Quip
	var quip := Label.new()
	quip.text = glow["quip"]
	UIFont.apply(quip, UIFont.BODY)
	quip.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	quip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quip.custom_minimum_size = Vector2(590, 0)
	content.add_child(quip)

	# Cost
	var cost: int = glow["cost"]
	var cost_label := Label.new()
	cost_label.text = _format_money(cost)
	UIFont.apply(cost_label, UIFont.BODY)
	cost_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.custom_minimum_size = Vector2(590, 40)
	content.add_child(cost_label)

	# Note — no stat effect
	var note := Label.new()
	note.text = "Pure vanity. No stat effect."
	UIFont.apply(note, UIFont.CAPTION)
	note.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.custom_minimum_size = Vector2(590, 30)
	content.add_child(note)

	# Can't afford?
	if CareerState.money < cost:
		var broke := Label.new()
		broke.text = "Can't afford it"
		UIFont.apply(broke, UIFont.CAPTION)
		broke.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
		broke.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		broke.custom_minimum_size = Vector2(590, 35)
		content.add_child(broke)

		var back_btn := _create_button("BACK", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5), UIFont.BODY, Vector2(400, 70))
		back_btn.pressed.connect(_dismiss_popup)
		var back_wrapper := CenterContainer.new()
		back_wrapper.custom_minimum_size = Vector2(590, 80)
		back_wrapper.add_child(back_btn)
		content.add_child(back_wrapper)
		return content

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	btn_row.custom_minimum_size = Vector2(590, 80)

	var buy_btn := _create_button("TREAT YOURSELF", Color(0.15, 0.4, 0.5), Color(0.3, 0.7, 0.8), UIFont.BODY, Vector2(300, 70))
	buy_btn.pressed.connect(func():
		CareerState.money -= cost
		_update_balance_label()
		_dismiss_popup()
	)
	btn_row.add_child(buy_btn)

	var skip_btn := _create_button("NAH", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5), UIFont.BODY, Vector2(200, 70))
	skip_btn.pressed.connect(_dismiss_popup)
	btn_row.add_child(skip_btn)

	content.add_child(btn_row)
	return content


func _build_exhibition_popup() -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)

	var opp_id: String = ExhibitionData.current_opponent_id
	var opp_name: String = OpponentData.get_display_name(opp_id)
	var opp_nick: String = OpponentData.get_nickname(opp_id)

	# Title
	var title := Label.new()
	title.text = "EXHIBITION MATCH"
	UIFont.apply(title, UIFont.SUBHEADING)
	title.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(590, 50)
	content.add_child(title)

	# Opponent name
	var name_label := Label.new()
	name_label.text = opp_name + ' "' + opp_nick + '"'
	UIFont.apply(name_label, UIFont.BODY)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(590, 0)
	content.add_child(name_label)

	# Format
	var format_label := Label.new()
	format_label.text = ExhibitionData.get_format_label()
	UIFont.apply(format_label, UIFont.CAPTION)
	format_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	format_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	format_label.custom_minimum_size = Vector2(590, 30)
	content.add_child(format_label)

	# Venue
	var venue_label := Label.new()
	venue_label.text = ExhibitionData.current_venue
	UIFont.apply(venue_label, UIFont.CAPTION)
	venue_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	venue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	venue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	venue_label.custom_minimum_size = Vector2(590, 30)
	content.add_child(venue_label)

	# Prize (green, prominent)
	var prize_label := Label.new()
	prize_label.text = "Prize: " + _format_money(ExhibitionData.current_prize)
	UIFont.apply(prize_label, UIFont.HEADING)
	prize_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.3))
	prize_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prize_label.custom_minimum_size = Vector2(590, 55)
	content.add_child(prize_label)

	# No entry fee
	var fee_label := Label.new()
	fee_label.text = "No entry fee"
	UIFont.apply(fee_label, UIFont.CAPTION)
	fee_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	fee_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fee_label.custom_minimum_size = Vector2(590, 25)
	content.add_child(fee_label)

	# Companion advice
	var advice := Label.new()
	advice.text = "No pre-drinking. Less pressure. Just darts."
	UIFont.apply(advice, UIFont.CAPTION)
	advice.add_theme_color_override("font_color", Color(0.65, 0.6, 0.5))
	advice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	advice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	advice.custom_minimum_size = Vector2(590, 0)
	content.add_child(advice)

	# Buttons: PLAY / REROLL / BACK
	var btn_row := VBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.custom_minimum_size = Vector2(590, 0)

	var play_btn := _create_button("PLAY", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4), UIFont.BODY, Vector2(500, 70))
	play_btn.pressed.connect(_on_exhibition_play)
	var play_wrapper := CenterContainer.new()
	play_wrapper.custom_minimum_size = Vector2(590, 75)
	play_wrapper.add_child(play_btn)
	btn_row.add_child(play_wrapper)

	var reroll_btn := _create_button("REROLL", Color(0.3, 0.25, 0.1), Color(0.85, 0.6, 0.15), UIFont.BODY, Vector2(500, 70))
	reroll_btn.pressed.connect(_on_exhibition_reroll)
	var reroll_wrapper := CenterContainer.new()
	reroll_wrapper.custom_minimum_size = Vector2(590, 75)
	reroll_wrapper.add_child(reroll_btn)
	btn_row.add_child(reroll_wrapper)

	var back_btn := _create_button("BACK", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5), UIFont.BODY, Vector2(500, 70))
	back_btn.pressed.connect(_dismiss_popup)
	var back_wrapper := CenterContainer.new()
	back_wrapper.custom_minimum_size = Vector2(590, 75)
	back_wrapper.add_child(back_btn)
	btn_row.add_child(back_wrapper)

	content.add_child(btn_row)
	return content


func _on_exhibition_play() -> void:
	_dismiss_popup()
	CareerState.exhibition_mode = true
	CareerState.pre_drink_units = 0
	ExhibitionData.apply_to_game_state()
	get_tree().change_scene_to_file("res://scenes/match.tscn")


func _on_exhibition_reroll() -> void:
	ExhibitionData.reroll(CareerState.career_level)
	_dismiss_popup()
	await get_tree().create_timer(0.35).timeout
	_show_popup(_build_exhibition_popup())


func _build_coming_soon(title_text: String, description: String) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)

	var title := Label.new()
	title.text = title_text
	UIFont.apply(title, UIFont.SUBHEADING)
	title.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(590, 50)
	content.add_child(title)

	var desc := Label.new()
	desc.text = description
	UIFont.apply(desc, UIFont.BODY)
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(590, 0)
	content.add_child(desc)

	var coming := Label.new()
	coming.text = "COMING SOON"
	UIFont.apply(coming, UIFont.CAPTION)
	coming.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	coming.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coming.custom_minimum_size = Vector2(590, 35)
	content.add_child(coming)

	var back_btn := _create_button("BACK", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5), UIFont.BODY, Vector2(400, 70))
	back_btn.pressed.connect(_dismiss_popup)
	var back_wrapper := CenterContainer.new()
	back_wrapper.custom_minimum_size = Vector2(590, 80)
	back_wrapper.add_child(back_btn)
	content.add_child(back_wrapper)

	return content


func _build_merch_popup() -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)

	var item_name: String = MerchData.get_inflatable_title(GameState.character)
	var level: int = CareerState.career_level

	# Title
	var title := Label.new()
	title.text = "INFLATABLE " + item_name
	UIFont.apply(title, UIFont.SUBHEADING)
	title.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(590, 50)
	content.add_child(title)

	# Stock display
	var stock_label := Label.new()
	stock_label.text = "Stock: " + str(CareerState.inflatables_stock)
	stock_label.name = "StockLabel"
	UIFont.apply(stock_label, UIFont.CAPTION)
	stock_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.3))
	stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stock_label.custom_minimum_size = Vector2(590, 30)
	content.add_child(stock_label)

	# Separator
	var sep1 := ColorRect.new()
	sep1.color = Color(0.3, 0.3, 0.35, 0.5)
	sep1.custom_minimum_size = Vector2(590, 1)
	content.add_child(sep1)

	# ---- BUY SECTION ----
	var buy_header := Label.new()
	buy_header.text = "BUY MORE"
	UIFont.apply(buy_header, UIFont.CAPTION)
	buy_header.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
	buy_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buy_header.custom_minimum_size = Vector2(590, 30)
	content.add_child(buy_header)

	# Price info
	var unit_price: int = CareerState.get_inflatable_unit_price()
	var discount_pct: int = int((1.0 - unit_price / 100.0) * 100)
	var price_info := Label.new()
	if discount_pct > 0:
		price_info.text = _format_money(unit_price) + " each (" + str(discount_pct) + "% discount)"
	else:
		price_info.text = _format_money(unit_price) + " each"
	price_info.name = "BuyPriceInfo"
	UIFont.apply(price_info, UIFont.CAPTION)
	price_info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	price_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_info.custom_minimum_size = Vector2(590, 25)
	content.add_child(price_info)

	# +/- row
	var buy_row := HBoxContainer.new()
	buy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buy_row.add_theme_constant_override("separation", 15)
	buy_row.custom_minimum_size = Vector2(590, 65)

	var buy_minus := _create_button("- 10", Color(0.3, 0.15, 0.15), Color(0.6, 0.3, 0.3), UIFont.CAPTION, Vector2(120, 55))
	buy_minus.name = "BuyMinus"
	buy_minus.disabled = true
	buy_row.add_child(buy_minus)

	var buy_qty_label := Label.new()
	buy_qty_label.text = "0"
	buy_qty_label.name = "BuyQtyLabel"
	UIFont.apply(buy_qty_label, UIFont.BODY)
	buy_qty_label.add_theme_color_override("font_color", Color.WHITE)
	buy_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buy_qty_label.custom_minimum_size = Vector2(100, 55)
	buy_row.add_child(buy_qty_label)

	var buy_plus := _create_button("+ 10", Color(0.15, 0.3, 0.15), Color(0.3, 0.6, 0.3), UIFont.CAPTION, Vector2(120, 55))
	buy_plus.name = "BuyPlus"
	buy_row.add_child(buy_plus)
	content.add_child(buy_row)

	# Total cost
	var buy_total := Label.new()
	buy_total.text = "Total: " + _format_money(0)
	buy_total.name = "BuyTotal"
	UIFont.apply(buy_total, UIFont.BODY)
	buy_total.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	buy_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buy_total.custom_minimum_size = Vector2(590, 35)
	content.add_child(buy_total)

	# BUY button
	var buy_btn := _create_button("BUY", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4), UIFont.BODY, Vector2(250, 60))
	buy_btn.name = "BuyBtn"
	buy_btn.disabled = true
	var buy_wrapper := CenterContainer.new()
	buy_wrapper.custom_minimum_size = Vector2(590, 65)
	buy_wrapper.add_child(buy_btn)
	content.add_child(buy_wrapper)

	# Separator
	var sep2 := ColorRect.new()
	sep2.color = Color(0.3, 0.3, 0.35, 0.5)
	sep2.custom_minimum_size = Vector2(590, 1)
	content.add_child(sep2)

	# ---- SELL SECTION ----
	var sell_header := Label.new()
	sell_header.text = "SELL AT VENUE"
	UIFont.apply(sell_header, UIFont.CAPTION)
	sell_header.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
	sell_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sell_header.custom_minimum_size = Vector2(590, 30)
	content.add_child(sell_header)

	var venue_config: Variant = MerchData.get_venue_config(level)

	if _merch_sale_committed:
		# Already committed
		var pending_label := Label.new()
		pending_label.text = "PENDING: " + str(CareerState.inflatables_pending_sale) + " committed for sale"
		UIFont.apply(pending_label, UIFont.CAPTION)
		pending_label.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
		pending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pending_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pending_label.custom_minimum_size = Vector2(590, 40)
		content.add_child(pending_label)
	elif venue_config == null:
		# Not at a selling venue yet
		var no_sell := Label.new()
		no_sell.text = "Selling starts at the County Club (Level 4)"
		UIFont.apply(no_sell, UIFont.CAPTION)
		no_sell.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		no_sell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_sell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		no_sell.custom_minimum_size = Vector2(590, 40)
		content.add_child(no_sell)
	elif CareerState.inflatables_stock <= 0:
		var no_stock := Label.new()
		no_stock.text = "No stock to sell"
		UIFont.apply(no_stock, UIFont.CAPTION)
		no_stock.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		no_stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_stock.custom_minimum_size = Vector2(590, 40)
		content.add_child(no_stock)
	else:
		# Venue info
		var venue_info := Label.new()
		venue_info.text = venue_config["venue_name"] + " - up to " + str(venue_config["max_sales"])
		UIFont.apply(venue_info, UIFont.CAPTION)
		venue_info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		venue_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		venue_info.custom_minimum_size = Vector2(590, 25)
		content.add_child(venue_info)

		var sell_price := Label.new()
		sell_price.text = _format_money(venue_config["price_per_unit"]) + " each"
		UIFont.apply(sell_price, UIFont.CAPTION)
		sell_price.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
		sell_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sell_price.custom_minimum_size = Vector2(590, 25)
		content.add_child(sell_price)

		# +/- row
		var sell_row := HBoxContainer.new()
		sell_row.alignment = BoxContainer.ALIGNMENT_CENTER
		sell_row.add_theme_constant_override("separation", 15)
		sell_row.custom_minimum_size = Vector2(590, 65)

		var sell_minus := _create_button("- 10", Color(0.3, 0.15, 0.15), Color(0.6, 0.3, 0.3), UIFont.CAPTION, Vector2(120, 55))
		sell_minus.name = "SellMinus"
		sell_minus.disabled = true
		sell_row.add_child(sell_minus)

		var sell_qty_label := Label.new()
		sell_qty_label.text = "0"
		sell_qty_label.name = "SellQtyLabel"
		UIFont.apply(sell_qty_label, UIFont.BODY)
		sell_qty_label.add_theme_color_override("font_color", Color.WHITE)
		sell_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sell_qty_label.custom_minimum_size = Vector2(100, 55)
		sell_row.add_child(sell_qty_label)

		var sell_plus := _create_button("+ 10", Color(0.15, 0.3, 0.15), Color(0.3, 0.6, 0.3), UIFont.CAPTION, Vector2(120, 55))
		sell_plus.name = "SellPlus"
		sell_row.add_child(sell_plus)
		content.add_child(sell_row)

		# Estimated return
		var sell_est := Label.new()
		sell_est.text = "Expected: " + _format_money(0)
		sell_est.name = "SellEstimate"
		UIFont.apply(sell_est, UIFont.BODY)
		sell_est.add_theme_color_override("font_color", Color(0.2, 0.85, 0.3))
		sell_est.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sell_est.custom_minimum_size = Vector2(590, 35)
		content.add_child(sell_est)

		# CONFIRM SALE button
		var sell_btn := _create_button("CONFIRM SALE", Color(0.5, 0.35, 0.1), Color(0.85, 0.6, 0.15), UIFont.BODY, Vector2(350, 60))
		sell_btn.name = "SellBtn"
		sell_btn.disabled = true
		var sell_wrapper := CenterContainer.new()
		sell_wrapper.custom_minimum_size = Vector2(590, 65)
		sell_wrapper.add_child(sell_btn)
		content.add_child(sell_wrapper)

		# Max sellable
		var max_sell: int = mini(CareerState.inflatables_stock, venue_config["max_sales"])
		# Round down to nearest 10
		max_sell = int(max_sell / 10) * 10

		# Wire sell +/- buttons
		sell_plus.pressed.connect(func():
			_merch_sell_qty = mini(_merch_sell_qty + 10, max_sell)
			_update_sell_display(content, venue_config)
		)
		sell_minus.pressed.connect(func():
			_merch_sell_qty = maxi(_merch_sell_qty - 10, 0)
			_update_sell_display(content, venue_config)
		)
		sell_btn.pressed.connect(func():
			_on_merch_sell_confirm(content)
		)

	# Separator
	var sep3 := ColorRect.new()
	sep3.color = Color(0.3, 0.3, 0.35, 0.5)
	sep3.custom_minimum_size = Vector2(590, 1)
	content.add_child(sep3)

	# BACK button
	var back_btn := _create_button("BACK", Color(0.15, 0.15, 0.25), Color(0.3, 0.3, 0.5), UIFont.BODY, Vector2(400, 60))
	back_btn.pressed.connect(_dismiss_popup)
	var back_wrapper := CenterContainer.new()
	back_wrapper.custom_minimum_size = Vector2(590, 65)
	back_wrapper.add_child(back_btn)
	content.add_child(back_wrapper)

	# Wire buy +/- buttons
	var buy_plus_node: Button = content.find_child("BuyPlus", true, false)
	var buy_minus_node: Button = content.find_child("BuyMinus", true, false)
	var buy_btn_node: Button = content.find_child("BuyBtn", true, false)

	if buy_plus_node:
		buy_plus_node.pressed.connect(func():
			_merch_buy_qty += 10
			_update_buy_display(content)
		)
	if buy_minus_node:
		buy_minus_node.pressed.connect(func():
			_merch_buy_qty = maxi(_merch_buy_qty - 10, 0)
			_update_buy_display(content)
		)
	if buy_btn_node:
		buy_btn_node.pressed.connect(func():
			_on_merch_buy(content)
		)

	return content


func _update_buy_display(popup: VBoxContainer) -> void:
	var unit_price: int = CareerState.get_inflatable_unit_price()
	# Price changes at batch boundaries — recalculate for what the NEXT batch would cost
	# after buying _merch_buy_qty
	var total_cost: int = 0
	var temp_bought: int = CareerState.inflatables_total_bought
	var remaining: int = _merch_buy_qty
	while remaining > 0:
		var step: int = int(temp_bought / 10)
		var price: int = int(100.0 * pow(0.95, step))
		# How many until next discount boundary?
		var next_boundary: int = (step + 1) * 10
		var can_buy_at_this_price: int = mini(next_boundary - temp_bought, remaining)
		total_cost += can_buy_at_this_price * price
		temp_bought += can_buy_at_this_price
		remaining -= can_buy_at_this_price

	var qty_label: Label = popup.find_child("BuyQtyLabel", true, false)
	if qty_label:
		qty_label.text = str(_merch_buy_qty)

	var total_label: Label = popup.find_child("BuyTotal", true, false)
	if total_label:
		total_label.text = "Total: " + _format_money(total_cost)

	var buy_btn: Button = popup.find_child("BuyBtn", true, false)
	if buy_btn:
		buy_btn.disabled = _merch_buy_qty == 0 or total_cost > CareerState.money

	var minus_btn: Button = popup.find_child("BuyMinus", true, false)
	if minus_btn:
		minus_btn.disabled = _merch_buy_qty == 0

	# Update price info to show what next batch costs
	var new_unit_price: int = int(100.0 * pow(0.95, int((CareerState.inflatables_total_bought + _merch_buy_qty) / 10)))
	var price_info: Label = popup.find_child("BuyPriceInfo", true, false)
	if price_info:
		var disc: int = int((1.0 - unit_price / 100.0) * 100)
		if disc > 0:
			price_info.text = _format_money(unit_price) + " each (" + str(disc) + "% discount)"
		else:
			price_info.text = _format_money(unit_price) + " each"


func _update_sell_display(popup: VBoxContainer, venue_config: Dictionary) -> void:
	var qty_label: Label = popup.find_child("SellQtyLabel", true, false)
	if qty_label:
		qty_label.text = str(_merch_sell_qty)

	var est_label: Label = popup.find_child("SellEstimate", true, false)
	if est_label:
		var estimate: Dictionary = MerchData.estimate_sale(_merch_sell_qty, CareerState.career_level)
		est_label.text = "Expected: " + _format_money(estimate["revenue"])

	var sell_btn: Button = popup.find_child("SellBtn", true, false)
	if sell_btn:
		sell_btn.disabled = _merch_sell_qty == 0

	var minus_btn: Button = popup.find_child("SellMinus", true, false)
	if minus_btn:
		minus_btn.disabled = _merch_sell_qty == 0

	var max_sell: int = mini(CareerState.inflatables_stock, venue_config["max_sales"])
	max_sell = int(max_sell / 10) * 10
	var plus_btn: Button = popup.find_child("SellPlus", true, false)
	if plus_btn:
		plus_btn.disabled = _merch_sell_qty >= max_sell


func _on_merch_buy(popup: VBoxContainer) -> void:
	if _merch_buy_qty <= 0:
		return
	# Calculate exact cost across discount boundaries
	var total_cost: int = 0
	var temp_bought: int = CareerState.inflatables_total_bought
	var remaining: int = _merch_buy_qty
	while remaining > 0:
		var step: int = int(temp_bought / 10)
		var price: int = int(100.0 * pow(0.95, step))
		var next_boundary: int = (step + 1) * 10
		var can_buy: int = mini(next_boundary - temp_bought, remaining)
		total_cost += can_buy * price
		temp_bought += can_buy
		remaining -= can_buy

	if total_cost > CareerState.money:
		return

	CareerState.money -= total_cost
	CareerState.inflatables_stock += _merch_buy_qty
	CareerState.inflatables_total_bought += _merch_buy_qty
	_merch_buy_qty = 0

	# Recalculate hustle (buying merch may trigger star 2 if coach already hired)
	var old_hustle: int = CareerState.hustle_stars
	CareerState.recalculate_hustle()

	_update_balance_label()

	# Refresh the popup
	_dismiss_popup()
	# Small delay then reshow
	await get_tree().create_timer(0.35).timeout
	_merch_sale_committed = CareerState.inflatables_pending_sale > 0
	_show_popup(_build_merch_popup())


func _on_merch_sell_confirm(popup: VBoxContainer) -> void:
	if _merch_sell_qty <= 0:
		return
	CareerState.inflatables_pending_sale = _merch_sell_qty
	_merch_sale_committed = true

	# Refresh popup
	_dismiss_popup()
	await get_tree().create_timer(0.35).timeout
	_show_popup(_build_merch_popup())


# ======================================================
# FOOD LOGIC
# ======================================================

func _on_food_accept(cost: int) -> void:
	_has_eaten = true
	if cost > 0:
		CareerState.money -= cost
	# Hub food is flavour/money sink only — heft progression handled by narrative cards
	_dismiss_popup()


# ======================================================
# POPUP ANIMATION
# ======================================================

func _show_popup(content: VBoxContainer) -> void:
	# Clear previous content
	for child in _popup_content_parent.get_children():
		child.queue_free()
	_popup_content_parent.add_child(content)

	# Position card off-screen and show
	_popup_card.position = Vector2(40, 1280)
	_popup_card.visible = true
	_popup_overlay.modulate = Color(1, 1, 1, 0)
	_popup_overlay.visible = true

	# Calculate target Y — centre the card vertically
	# Wait one frame for size to resolve
	await get_tree().process_frame
	var card_height: float = _popup_card.size.y
	var target_y: float = max(100, (1280 - card_height) / 2.0)

	# Animate overlay fade in + card slide up
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_popup_overlay, "modulate", Color(1, 1, 1, 1), 0.25)
	tween.tween_property(_popup_card, "position:y", target_y, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _dismiss_popup() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_popup_overlay, "modulate", Color(1, 1, 1, 0), 0.2)
	tween.tween_property(_popup_card, "position:y", 1280.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.chain().tween_callback(func():
		_popup_overlay.visible = false
		_popup_card.visible = false
		_update_balance_label()
	)


# ======================================================
# HELPERS
# ======================================================

func _create_action_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(620, 65)
	UIFont.apply_button(btn, UIFont.BODY)
	btn.add_theme_color_override("font_color", Color.WHITE)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.18, 0.94)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.6, 0.15, 0.4)
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = Color(0.18, 0.16, 0.26, 0.94)
	hover.border_color = Color(0.85, 0.6, 0.15, 0.7)
	btn.add_theme_stylebox_override("hover", hover)

	return btn


func _create_button(text: String, bg_color: Color, border_color: Color, font_size: int, min_size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	UIFont.apply_button(btn, font_size)
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


func _center_button(btn: Button) -> CenterContainer:
	var wrapper := CenterContainer.new()
	wrapper.custom_minimum_size = Vector2(640, 70)
	wrapper.add_child(btn)
	return wrapper


func _add_spacer(parent: Control, height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(640, height)
	parent.add_child(spacer)


func _update_balance_label() -> void:
	if _balance_label:
		_balance_label.text = "BALANCE: " + _format_money(CareerState.money)


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
