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

var _balance_label: Label
var _popup_overlay: ColorRect
var _popup_card: PanelContainer
var _popup_content_parent: VBoxContainer
var _eat_button: Button
var _has_eaten: bool = false

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Full dark bg
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Scrollable content area
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 0)
	scroll.size = Vector2(640, 1280)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(640, 0)
	content.add_theme_constant_override("separation", 0)
	scroll.add_child(content)

	_add_spacer(content, 30)

	# Balance display
	_balance_label = Label.new()
	_update_balance_label()
	UIFont.apply(_balance_label, UIFont.CAPTION)
	_balance_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.3))
	_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balance_label.custom_minimum_size = Vector2(640, 40)
	content.add_child(_balance_label)

	_add_spacer(content, 20)

	# Opponent info panel
	_build_opponent_panel(content)

	_add_spacer(content, 30)

	# "PREPARE FOR MATCH" header
	var prep_label := Label.new()
	prep_label.text = "PREPARE FOR MATCH"
	UIFont.apply(prep_label, UIFont.SUBHEADING)
	prep_label.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
	prep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prep_label.custom_minimum_size = Vector2(640, 55)
	content.add_child(prep_label)

	_add_spacer(content, 15)

	# Action buttons (only unlocked ones)
	_build_action_buttons(content)

	_add_spacer(content, 30)

	# PROCEED button
	var proceed_btn := _create_button("PROCEED TO MATCH", Color(0.15, 0.5, 0.2), Color(0.3, 0.8, 0.4), UIFont.SUBHEADING, Vector2(620, 100))
	proceed_btn.pressed.connect(_on_proceed)
	var proceed_wrapper := CenterContainer.new()
	proceed_wrapper.custom_minimum_size = Vector2(640, 110)
	proceed_wrapper.add_child(proceed_btn)
	content.add_child(proceed_wrapper)

	_add_spacer(content, 40)

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
	vbox.add_theme_constant_override("separation", 8)

	# "YOUR NEXT OPPONENT" header
	var header := Label.new()
	header.text = "YOUR NEXT OPPONENT"
	UIFont.apply(header, UIFont.CAPTION)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.custom_minimum_size = Vector2(600, 35)
	vbox.add_child(header)

	# Portrait
	var image_path: String = OpponentData.get_image(opp_id)
	if image_path != "":
		var tex := load(image_path)
		if tex:
			var img := TextureRect.new()
			img.texture = tex
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.custom_minimum_size = Vector2(560, UIFont.PORTRAIT_S)
			vbox.add_child(img)
	else:
		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(560, UIFont.PORTRAIT_S)
		var bg := ColorRect.new()
		bg.position = Vector2(100, 0)
		bg.size = Vector2(360, UIFont.PORTRAIT_S)
		bg.color = Color(0.2, 0.2, 0.25)
		wrapper.add_child(bg)
		var initial := Label.new()
		initial.text = display_name.left(1)
		initial.position = Vector2(100, 0)
		initial.size = Vector2(360, UIFont.PORTRAIT_S)
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UIFont.apply(initial, UIFont.SCREEN_TITLE)
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

	_add_spacer(parent, 10)

	# BUY/SELL MERCH — from L3 (Trader met after L2 win)
	var merch_btn := _create_action_button("BUY/SELL MERCH")
	merch_btn.pressed.connect(_on_merch_pressed)
	parent.add_child(_center_button(merch_btn))

	if level >= 5:
		_add_spacer(parent, 10)
		# PLACE A BET — from L4 (Contact met after L3 win)
		# Actually available from L5 since Contact is met after L4 win
		var bet_btn := _create_action_button("PLACE A BET")
		bet_btn.pressed.connect(_on_bet_pressed)
		parent.add_child(_center_button(bet_btn))

	if level >= 6:
		_add_spacer(parent, 10)
		# GET SPONSORSHIP — from L5 (Sponsor Rep met after L4 win)
		# Actually available from L6 since Sponsor Rep is met after L5 win
		var sponsor_btn := _create_action_button("GET SPONSORSHIP")
		sponsor_btn.pressed.connect(_on_sponsor_pressed)
		parent.add_child(_center_button(sponsor_btn))


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

func _on_merch_pressed() -> void:
	_show_popup(_build_coming_soon("MERCH", "The Trader is setting up his stall. Inflatables, knock-off watches, and dodgy aftershave. Coming soon."))

func _on_bet_pressed() -> void:
	_show_popup(_build_coming_soon("BETTING", "The Contact knows a bloke who knows a bloke. Side bets, accumulators, and risky propositions. Coming soon."))

func _on_sponsor_pressed() -> void:
	_show_popup(_build_coming_soon("SPONSORSHIP", "The Sponsor Rep has some interesting offers. Logos on your shirt, branding on your darts. Coming soon."))

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

	# Heft maxed note
	if CareerState.heft_tier >= 5:
		var maxed := Label.new()
		maxed.text = "Heft maxed — eat for fun, no stat gain"
		UIFont.apply(maxed, UIFont.CAPTION)
		maxed.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		maxed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		maxed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		maxed.custom_minimum_size = Vector2(590, 0)
		content.add_child(maxed)

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


# ======================================================
# FOOD LOGIC
# ======================================================

func _on_food_accept(cost: int) -> void:
	_has_eaten = true
	if cost > 0:
		CareerState.money -= cost
	if CareerState.heft_tier < 5:
		CareerState.heft_tier += 1
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
	btn.custom_minimum_size = Vector2(620, 80)
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
	wrapper.custom_minimum_size = Vector2(640, 90)
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
