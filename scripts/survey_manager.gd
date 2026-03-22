extends Node

## Survey question manager autoload.
## Fetches questions from Supabase (web) or uses test data (editor).
## NO class_name — autoload name provides the global reference.

# ── State ──
var _questions: Array = []
var _answered_ids: Array = []
var _is_web: bool = false
var _fetched: bool = false


# ── Test data (mirrors Supabase survey_questions table) ──
const TEST_QUESTIONS: Array = [
	{
		"id": 1,
		"question_text": "What are you into?",
		"question_type": "multi_select",
		"answers": ["Darts", "Booze", "Pub culture", "Sport in general", "None of these"],
		"exclusive_answer": "None of these",
		"heading_text": "ONE QUICK QUESTION",
		"intro_text": "To help our developers build a better game, we'd love to know a bit about you.",
		"text_placeholder": "",
		"trigger_point": "before_l1",
		"sort_order": 1,
		"skippable": false,
	},
	{
		"id": 2,
		"question_text": "How would you rate the game so far?",
		"question_type": "rating_select",
		"answers": ["Absolute shambles", "Needs work", "Proper decent", "Loving it", "Best game ever"],
		"text_placeholder": "",
		"trigger_point": "l2_win_rating",
		"sort_order": 2,
		"skippable": false,
		"repeatable_days": 60,
	},
	{
		"id": 3,
		"question_text": "What are you loving about the game, if anything?",
		"question_type": "multi_select_text",
		"answers": ["Gameplay", "Story", "Humour", "Graphics", "Nothing yet"],
		"exclusive_answer": "Nothing yet",
		"text_placeholder": "Tell us more...",
		"trigger_point": "l2_win",
		"sort_order": 3,
		"skippable": false,
	},
	{
		"id": 4,
		"question_text": "What sucks?",
		"question_type": "short_text",
		"answers": [],
		"text_placeholder": "Be honest...",
		"trigger_point": "l2_win",
		"sort_order": 4,
		"skippable": true,
	},
	{
		"id": 5,
		"question_text": "What else would you like to see in the game?",
		"question_type": "short_text",
		"answers": [],
		"text_placeholder": "Ideas welcome...",
		"trigger_point": "l2_win",
		"sort_order": 5,
		"skippable": true,
	},
	{
		"id": 6,
		"question_text": "Would you pay £££ for any of these?",
		"question_type": "multi_select_text",
		"answers": ["Upload a photo to play as yourself", "Upload a photo and nickname to become an opponent everyone plays against", "Add new pre-drinks", "Gift the developers", "I wouldn't pay"],
		"exclusive_answer": "I wouldn't pay",
		"intro_text": "We are determined not to flood this game with cheap adverts which interrupt your play.",
		"text_placeholder": "Anything else...",
		"trigger_point": "l2_win",
		"sort_order": 6,
		"skippable": false,
	},
	{
		"id": 7,
		"question_text": "Got a question or something to say?",
		"question_type": "short_text",
		"answers": [],
		"text_placeholder": "Type here...",
		"trigger_point": "menu_feedback",
		"sort_order": 7,
		"skippable": true,
	},
]


func _ready() -> void:
	_is_web = OS.has_feature("web")
	if _is_web:
		call_deferred("_fetch_questions_from_supabase")
	else:
		_questions = TEST_QUESTIONS.duplicate(true)
		_fetched = true
		print("[Survey] Loaded %d test questions" % _questions.size())


# ══════════════════════════════════════════
# PUBLIC API
# ══════════════════════════════════════════

func has_pending(trigger: String) -> bool:
	return get_pending_questions(trigger).size() > 0


func get_pending_questions(trigger: String) -> Array:
	if not _fetched:
		_questions = TEST_QUESTIONS.duplicate(true)
		_fetched = true
	var pending: Array = []
	for q in _questions:
		var q_id = q.get("id", 0)
		if q.get("trigger_point", "") == trigger and not (q_id in _answered_ids) and q.get("active", true):
			pending.append(q)
	pending.sort_custom(func(a, b): return a.get("sort_order", 0) < b.get("sort_order", 0))
	return pending


func build_card(question: Dictionary, advance_callable: Callable) -> VBoxContainer:
	var q_type: String = question.get("question_type", "")
	match q_type:
		"multi_select":
			return _build_multi_select_card(question, advance_callable)
		"rating_select":
			return _build_rating_select_card(question, advance_callable)
		"short_text":
			return _build_short_text_card(question, advance_callable)
		"multi_select_text":
			return _build_multi_select_text_card(question, advance_callable)
	# Legacy fallback for old star_rating type
	if q_type == "star_rating":
		return _build_rating_select_card(question, advance_callable)
	return _create_card()


## Build a simple intro card (developer portrait, dark panel, text, CONTINUE button)
func build_intro_card(advance_callable: Callable) -> VBoxContainer:
	var card := _create_card()
	_add_spacer(card, 30)

	# Developer intro image — smaller, more room for text below
	var tex := load("res://Developer intro cropped.png")
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.custom_minimum_size = Vector2(640, 160)
		card.add_child(img)
		_add_spacer(card, 12)

	var panel := _create_survey_panel()
	var inner := _get_panel_inner(panel)
	card.add_child(panel)

	# Heading
	var heading := Label.new()
	heading.text = "QUICK FEEDBACK"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIFont.apply(heading, UIFont.SUBHEADING)
	heading.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	inner.add_child(heading)
	_add_spacer(inner, 12)

	# Body text
	var body := Label.new()
	body.text = "Thanks for getting this far! This is a brand new game from a tiny development studio, and your feedback genuinely helps us make it better.\n\nWe've got a few quick questions. Don't worry, we'll only ask these once."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIFont.apply(body, UIFont.CAPTION)
	body.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	inner.add_child(body)

	_add_spacer(card, 30)
	var btn := _create_action_button("LET'S GO")
	btn.pressed.connect(func(): advance_callable.call())
	card.add_child(btn)

	return card


## Build a thank you card shown after all survey questions
func build_thank_you_card(advance_callable: Callable) -> VBoxContainer:
	var card := _create_card()
	_add_spacer(card, 20)

	# Developer thanks image — big, plenty of room on this card
	var tex := load("res://Developer says thanks cropped.png")
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.custom_minimum_size = Vector2(640, 450)
		card.add_child(img)
		_add_spacer(card, 16)

	var panel := _create_survey_panel()
	var inner := _get_panel_inner(panel)
	card.add_child(panel)

	var heading := Label.new()
	heading.text = "THANK YOU!"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIFont.apply(heading, UIFont.HEADING)
	heading.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	inner.add_child(heading)
	_add_spacer(inner, 16)

	var body := Label.new()
	body.text = "That really helps. Now let's get you back to the darts."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIFont.apply(body, UIFont.BODY)
	body.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	inner.add_child(body)

	_add_spacer(card, 30)
	var btn := _create_action_button("BACK TO THE DARTS")
	btn.custom_minimum_size = Vector2(560, 80)
	btn.pressed.connect(func(): advance_callable.call())
	card.add_child(btn)

	return card


# ══════════════════════════════════════════
# CARD BUILDERS
# ══════════════════════════════════════════

func _build_multi_select_card(q: Dictionary, advance: Callable) -> VBoxContainer:
	var card := _create_card()
	_add_spacer(card, 40)

	var panel := _create_survey_panel()
	var inner := _get_panel_inner(panel)
	card.add_child(panel)

	# Optional heading above intro text (e.g. "ONE QUICK QUESTION")
	var heading_text: String = q.get("heading_text", "")
	if not heading_text.is_empty():
		var heading := Label.new()
		heading.text = heading_text
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UIFont.apply(heading, UIFont.SUBHEADING)
		heading.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		inner.add_child(heading)
		_add_spacer(inner, 10)

	# Optional intro text above the question
	var intro_text: String = q.get("intro_text", "")
	if not intro_text.is_empty():
		var intro_label := Label.new()
		intro_label.text = intro_text
		intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UIFont.apply(intro_label, UIFont.CAPTION)
		intro_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
		inner.add_child(intro_label)
		_add_spacer(inner, 10)

	var q_label := _create_question_label(q.get("question_text", ""))
	inner.add_child(q_label)
	_add_spacer(inner, 12)

	var selected: Array = []
	var answers: Array = q.get("answers", [])
	var exclusive: String = q.get("exclusive_answer", "")
	var all_buttons: Array = []

	# Create action button first so toggle callbacks can reference it
	var next_btn := _create_action_button("NEXT")
	next_btn.disabled = true

	for i in range(answers.size()):
		var answer_text: String = answers[i]
		var btn := _create_toggle_button(answer_text)
		all_buttons.append({"btn": btn, "text": answer_text})
		var _nb := next_btn
		var _excl := exclusive
		var _sel := selected
		var _btns := all_buttons
		btn.pressed.connect(func():
			_handle_exclusive_toggle(answer_text, _excl, _sel, _btns)
			_nb.disabled = _sel.is_empty()
		)
		inner.add_child(btn)

	_add_spacer(card, 20)
	next_btn.pressed.connect(func():
		_save_response(q.get("id", 0), {"selected": selected})
		advance.call()
	)
	card.add_child(next_btn)

	return card


func _build_rating_select_card(q: Dictionary, advance: Callable) -> VBoxContainer:
	var card := _create_card()
	_add_spacer(card, 60)

	var panel := _create_survey_panel()
	var inner := _get_panel_inner(panel)
	card.add_child(panel)

	var q_label := _create_question_label(q.get("question_text", ""))
	inner.add_child(q_label)
	_add_spacer(inner, 12)

	var rating_labels: Array = q.get("answers", ["1", "2", "3", "4", "5"])
	var state: Array = [0]  # state[0] = selected rating (1-5, 0 = none)
	var buttons: Array = []

	# Colour gradient: red (1) → orange (2) → yellow (3) → light green (4) → green (5)
	var gradient_colors: Array = [
		Color(0.75, 0.22, 0.22),   # Red
		Color(0.80, 0.50, 0.18),   # Orange
		Color(0.75, 0.70, 0.20),   # Yellow
		Color(0.45, 0.70, 0.30),   # Light green
		Color(0.25, 0.65, 0.30),   # Green
	]
	var gradient_pastel: Array = [
		Color(0.75, 0.22, 0.22, 0.2),
		Color(0.80, 0.50, 0.18, 0.2),
		Color(0.75, 0.70, 0.20, 0.2),
		Color(0.45, 0.70, 0.30, 0.2),
		Color(0.25, 0.65, 0.30, 0.2),
	]

	var next_btn := _create_action_button("NEXT")
	next_btn.disabled = true

	for i in range(5):
		var label_text: String = rating_labels[i] if i < rating_labels.size() else str(i + 1)
		var btn := _create_toggle_button(label_text)
		buttons.append(btn)
		# Set pastel background as default
		_style_rating_button(btn, false, gradient_pastel[i], gradient_colors[i])

		var rating_val := i + 1
		var _nb := next_btn
		var _gc := gradient_colors
		var _gp := gradient_pastel
		btn.pressed.connect(func():
			state[0] = rating_val
			# Single-select: only the tapped one is filled
			for j in range(buttons.size()):
				_style_rating_button(buttons[j], j == rating_val - 1, _gp[j], _gc[j])
			_nb.disabled = false
		)
		inner.add_child(btn)

	_add_spacer(card, 20)
	next_btn.pressed.connect(func():
		var label_str: String = rating_labels[state[0] - 1] if state[0] > 0 and state[0] <= rating_labels.size() else ""
		_save_response(q.get("id", 0), {"rating": state[0], "label": label_str})
		advance.call()
	)
	card.add_child(next_btn)

	return card


func _build_short_text_card(q: Dictionary, advance: Callable) -> VBoxContainer:
	var card := _create_card()
	_add_spacer(card, 80)

	var panel := _create_survey_panel()
	var inner := _get_panel_inner(panel)
	card.add_child(panel)

	var q_label := _create_question_label(q.get("question_text", ""))
	inner.add_child(q_label)
	_add_spacer(inner, 12)

	var placeholder: String = q.get("text_placeholder", "Type here...")
	if placeholder.is_empty():
		placeholder = "Type here..."
	var text_input := _create_text_area(placeholder)
	inner.add_child(text_input)

	_add_spacer(card, 20)

	var submit_btn := _create_action_button("SUBMIT")
	submit_btn.disabled = true
	text_input.text_changed.connect(func():
		submit_btn.disabled = text_input.text.strip_edges().is_empty()
	)
	submit_btn.pressed.connect(func():
		_save_response(q.get("id", 0), {"text": text_input.text.strip_edges()})
		advance.call()
	)
	card.add_child(submit_btn)

	if q.get("skippable", false):
		_add_spacer(card, 10)
		var skip_btn := _create_skip_button("SKIP")
		skip_btn.pressed.connect(func():
			_save_response(q.get("id", 0), {"skipped": true})
			advance.call()
		)
		card.add_child(skip_btn)

	return card


func _build_multi_select_text_card(q: Dictionary, advance: Callable) -> VBoxContainer:
	var card := _create_card()
	_add_spacer(card, 20)

	var panel := _create_survey_panel()
	var inner := _get_panel_inner(panel)
	card.add_child(panel)

	# Optional intro text above the question
	var intro_text: String = q.get("intro_text", "")
	if not intro_text.is_empty():
		var intro_label := Label.new()
		intro_label.text = intro_text
		intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UIFont.apply(intro_label, UIFont.CAPTION)
		intro_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
		inner.add_child(intro_label)
		_add_spacer(inner, 10)

	var q_label := _create_question_label(q.get("question_text", ""))
	inner.add_child(q_label)
	_add_spacer(inner, 8)

	var selected: Array = []
	var answers: Array = q.get("answers", [])
	var exclusive: String = q.get("exclusive_answer", "")
	var all_buttons: Array = []

	# Create text input and submit button before the loop (closures reference them)
	var placeholder: String = q.get("text_placeholder", "Tell us more...")
	if placeholder.is_empty():
		placeholder = "Tell us more..."
	var text_input := _create_text_area(placeholder)

	var submit_btn := _create_action_button("SUBMIT")
	submit_btn.disabled = true

	for i in range(answers.size()):
		var answer_text: String = answers[i]
		var btn := _create_toggle_button(answer_text)
		all_buttons.append({"btn": btn, "text": answer_text})
		var _excl := exclusive
		var _sel := selected
		var _btns := all_buttons
		var _ti := text_input
		var _sb := submit_btn
		btn.pressed.connect(func():
			_handle_exclusive_toggle(answer_text, _excl, _sel, _btns)
			_sb.disabled = _sel.is_empty() and _ti.text.strip_edges().is_empty()
		)
		inner.add_child(btn)

	_add_spacer(inner, 8)
	inner.add_child(text_input)
	text_input.text_changed.connect(func():
		submit_btn.disabled = selected.is_empty() and text_input.text.strip_edges().is_empty()
	)

	_add_spacer(card, 20)
	submit_btn.pressed.connect(func():
		var response := {"selected": selected}
		var extra := text_input.text.strip_edges()
		if not extra.is_empty():
			response["text"] = extra
		_save_response(q.get("id", 0), response)
		advance.call()
	)
	card.add_child(submit_btn)

	return card


# ══════════════════════════════════════════
# EXCLUSIVE TOGGLE LOGIC
# ══════════════════════════════════════════

## Handles the exclusive answer toggle: if the tapped answer IS the exclusive
## option, deselect everything else. If tapping a normal option, deselect the
## exclusive one. "None of these" / "Nothing yet" / "I wouldn't pay" etc.
func _handle_exclusive_toggle(tapped: String, exclusive: String, selected: Array, all_buttons: Array) -> void:
	if exclusive.is_empty():
		# No exclusive logic — simple toggle
		if tapped in selected:
			selected.erase(tapped)
			_set_btn_state(all_buttons, tapped, false)
		else:
			selected.append(tapped)
			_set_btn_state(all_buttons, tapped, true)
		return

	if tapped == exclusive:
		# Tapped the exclusive option
		if tapped in selected:
			# Deselect it
			selected.erase(tapped)
			_set_btn_state(all_buttons, tapped, false)
		else:
			# Select exclusive, deselect everything else
			selected.clear()
			selected.append(tapped)
			for entry in all_buttons:
				_style_toggle(entry["btn"], entry["text"] == tapped)
	else:
		# Tapped a normal option — deselect exclusive if it was on
		if exclusive in selected:
			selected.erase(exclusive)
			_set_btn_state(all_buttons, exclusive, false)
		# Toggle the tapped option
		if tapped in selected:
			selected.erase(tapped)
			_set_btn_state(all_buttons, tapped, false)
		else:
			selected.append(tapped)
			_set_btn_state(all_buttons, tapped, true)


func _set_btn_state(all_buttons: Array, answer_text: String, on: bool) -> void:
	for entry in all_buttons:
		if entry["text"] == answer_text:
			_style_toggle(entry["btn"], on)
			break


# ══════════════════════════════════════════
# UI HELPERS
# ══════════════════════════════════════════

func _create_card() -> VBoxContainer:
	var card := VBoxContainer.new()
	card.position = Vector2(40, 0)
	card.size = Vector2(640, 1280)
	card.add_theme_constant_override("separation", 0)
	card.visible = false
	return card


func _create_survey_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.94)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.85, 0.6, 0.15, 0.6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	panel.add_child(inner)

	return panel


func _get_panel_inner(panel: PanelContainer) -> VBoxContainer:
	return panel.get_child(0) as VBoxContainer


func _create_question_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIFont.apply(label, UIFont.BODY)
	label.add_theme_color_override("font_color", Color.WHITE)
	return label


func _create_toggle_button(text: String) -> Control:
	# For short text, use a standard Button.
	# For long text (>30 chars), use a PanelContainer with a Label inside
	# so the text wraps properly. Both return a Control with the same
	# toggle styling and pressed signal.
	if text.length() <= 30:
		var btn := Button.new()
		btn.text = text
		btn.custom_minimum_size = Vector2(580, 56)
		btn.clip_text = false
		UIFont.apply_button(btn, UIFont.CAPTION)
		_style_toggle(btn, false)
		return btn

	# Long text: clickable panel with wrapping label
	var wrapper := Button.new()
	wrapper.text = ""
	wrapper.custom_minimum_size = Vector2(580, 0)
	wrapper.clip_text = false

	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIFont.apply(label, UIFont.CAPTION)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 12
	label.offset_right = -12
	label.offset_top = 8
	label.offset_bottom = -8
	wrapper.add_child(label)

	# Estimate height from text length
	var chars_per_line: int = 26
	var lines: int = max(1, ceili(float(text.length()) / float(chars_per_line)))
	wrapper.custom_minimum_size = Vector2(580, 24 + lines * 34)

	_style_toggle(wrapper, false)
	# Store label ref so _style_toggle can update font colour
	wrapper.set_meta("label", label)
	return wrapper


func _style_toggle(btn: Control, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2

	var font_color: Color
	if selected:
		style.bg_color = Color(0.85, 0.6, 0.15, 0.8)
		style.border_color = Color(0.85, 0.6, 0.15, 1.0)
		font_color = Color(0.05, 0.05, 0.08)
	else:
		style.bg_color = Color(0.15, 0.14, 0.2, 0.8)
		style.border_color = Color(0.3, 0.3, 0.4, 0.6)
		font_color = Color(0.8, 0.8, 0.85)

	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)

	# Update inner label colour for long-text buttons
	if btn.has_meta("label"):
		var label: Label = btn.get_meta("label")
		label.add_theme_color_override("font_color", font_color)


## Style a rating button — pastel background normally, filled bold when selected
func _style_rating_button(btn: Control, selected: bool, pastel: Color, bold: Color) -> void:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2

	if selected:
		style.bg_color = Color(bold.r, bold.g, bold.b, 0.85)
		style.border_color = Color(bold.r, bold.g, bold.b, 1.0)
		btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		style.bg_color = pastel
		style.border_color = Color(bold.r, bold.g, bold.b, 0.35)
		btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)


func _create_action_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(500, 80)
	UIFont.apply_button(btn, UIFont.HEADING)
	btn.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08))

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.506, 0.78, 0.518)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_color = Color(0.18, 0.49, 0.2)
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = Color(0.56, 0.83, 0.57)
	btn.add_theme_stylebox_override("hover", hover)

	var disabled := style.duplicate()
	disabled.bg_color = Color(0.3, 0.35, 0.3, 0.5)
	disabled.border_color = Color(0.25, 0.3, 0.25, 0.5)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.45, 0.4))

	return btn


func _create_skip_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 56)
	UIFont.apply_button(btn, UIFont.CAPTION)
	btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.14, 0.2, 0.5)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = Color(0.3, 0.3, 0.35, 0.5)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)

	return btn


## Multi-line text input (3-4 lines, word wrapping)
func _create_text_area(placeholder: String) -> TextEdit:
	var input := TextEdit.new()
	input.placeholder_text = placeholder
	input.custom_minimum_size = Vector2(580, 130)
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input.scroll_fit_content_height = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.16, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.85, 0.6, 0.15, 0.4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	input.add_theme_stylebox_override("normal", style)

	var focus_style := style.duplicate()
	focus_style.border_color = Color(0.85, 0.6, 0.15, 0.8)
	input.add_theme_stylebox_override("focus", focus_style)

	input.add_theme_font_size_override("font_size", 26)
	input.add_theme_color_override("font_color", Color.WHITE)
	input.add_theme_color_override("font_placeholder_color", Color(0.4, 0.4, 0.45))

	return input


func _add_spacer(parent: Control, height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)


# ══════════════════════════════════════════
# DATA — SAVE & FETCH
# ══════════════════════════════════════════

func _save_response(question_id, answer) -> void:
	_answered_ids.append(question_id)

	if _is_web:
		_post_to_supabase(question_id, answer)
	else:
		print("[Survey] Q%s answered: %s" % [str(question_id), str(answer)])


func _post_to_supabase(question_id, answer) -> void:
	var sb_url = JavaScriptBridge.eval("window.dartAttackSupabase ? window.dartAttackSupabase.url : ''")
	var sb_key = JavaScriptBridge.eval("window.dartAttackSupabase ? window.dartAttackSupabase.key : ''")
	var token = JavaScriptBridge.eval("window.dartAttackSupabase ? window.dartAttackSupabase.accessToken : ''")
	var player_id = JavaScriptBridge.eval("window.dartAttackUser ? window.dartAttackUser.id : ''")

	if not sb_url or not sb_key or not token or not player_id:
		print("[Survey] Cannot save — no auth credentials")
		return

	var http := HTTPRequest.new()
	add_child(http)

	var url: String = str(sb_url) + "/rest/v1/survey_responses"
	var headers: PackedStringArray = [
		"apikey: " + str(sb_key),
		"Authorization: Bearer " + str(token),
		"Content-Type: application/json",
	]

	var payload := {
		"player_id": str(player_id),
		"question_id": question_id,
		"answer": answer,
	}

	# Attach session_id if Analytics has one
	if Analytics._session_id != "":
		payload["session_id"] = Analytics._session_id

	var body := JSON.stringify(payload)

	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, _response_body: PackedByteArray) -> void:
		if response_code >= 200 and response_code < 300:
			print("[Survey] Response saved for Q%s" % str(question_id))
		else:
			print("[Survey] Save failed for Q%s (HTTP %d)" % [str(question_id), response_code])
		http.queue_free()
	)

	http.request(url, headers, HTTPClient.METHOD_POST, body)


func _fetch_questions_from_supabase() -> void:
	var sb_url = JavaScriptBridge.eval("window.dartAttackSupabase ? window.dartAttackSupabase.url : ''")
	var sb_key = JavaScriptBridge.eval("window.dartAttackSupabase ? window.dartAttackSupabase.key : ''")
	var token = JavaScriptBridge.eval("window.dartAttackSupabase ? window.dartAttackSupabase.accessToken : ''")
	var player_id = JavaScriptBridge.eval("window.dartAttackUser ? window.dartAttackUser.id : ''")

	if not sb_url or not sb_key or not token:
		print("[Survey] No credentials — using test data")
		_questions = TEST_QUESTIONS.duplicate(true)
		_fetched = true
		return

	var http := HTTPRequest.new()
	add_child(http)

	var url: String = str(sb_url) + "/rest/v1/survey_questions?active=eq.true&order=sort_order"
	var headers: PackedStringArray = [
		"apikey: " + str(sb_key),
		"Authorization: Bearer " + str(token),
	]

	var _pid := str(player_id) if player_id else ""
	var _surl := str(sb_url)
	var _skey := str(sb_key)
	var _tok := str(token)

	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray) -> void:
		if response_code >= 200 and response_code < 300:
			var json := JSON.new()
			if json.parse(response_body.get_string_from_utf8()) == OK:
				_questions = json.data if json.data is Array else []
				print("[Survey] Fetched %d questions from Supabase" % _questions.size())
			else:
				_questions = TEST_QUESTIONS.duplicate(true)
		else:
			print("[Survey] Fetch failed (HTTP %d) — using test data" % response_code)
			_questions = TEST_QUESTIONS.duplicate(true)
		_fetched = true
		http.queue_free()

		# Now fetch which questions this player already answered
		if not _pid.is_empty():
			_fetch_answered_from_supabase(_surl, _skey, _tok, _pid)
	)

	http.request(url, headers)


func _fetch_answered_from_supabase(sb_url: String, sb_key: String, token: String, player_id: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)

	# Fetch question_id and created_at so we can handle repeatable questions
	var url: String = sb_url + "/rest/v1/survey_responses?player_id=eq." + player_id + "&select=question_id,created_at&order=created_at.desc"
	var headers: PackedStringArray = [
		"apikey: " + sb_key,
		"Authorization: Bearer " + token,
	]

	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray) -> void:
		if response_code >= 200 and response_code < 300:
			var json := JSON.new()
			if json.parse(response_body.get_string_from_utf8()) == OK:
				var parsed = json.data
				if parsed is Array:
					# Build a map of question_id -> most recent created_at
					var latest_answers: Dictionary = {}
					for row in parsed:
						var qid = row.get("question_id", 0)
						if qid and not latest_answers.has(qid):
							latest_answers[qid] = row.get("created_at", "")

					# Check each answered question — skip repeatable ones whose cooldown expired
					for qid in latest_answers:
						var should_mark := true
						var q_def := _find_question(qid)
						if q_def and q_def.get("repeatable_days", 0) > 0:
							var answered_at: String = latest_answers[qid]
							if not answered_at.is_empty():
								var days_ago := _days_since(answered_at)
								if days_ago >= q_def.get("repeatable_days", 0):
									should_mark = false
									print("[Survey] Q%s is repeatable and cooldown expired (%d days ago)" % [str(qid), days_ago])
						if should_mark and not (qid in _answered_ids):
							_answered_ids.append(qid)
					print("[Survey] Player has answered %d questions (after repeatable check)" % _answered_ids.size())
		http.queue_free()
	)

	http.request(url, headers)


func _find_question(qid) -> Dictionary:
	for q in _questions:
		if q.get("id", 0) == qid:
			return q
	return {}


func _days_since(iso_timestamp: String) -> int:
	# Parse ISO 8601 timestamp (e.g. "2026-03-22T10:30:00.000Z") and return days since
	if iso_timestamp.length() < 10:
		return 0
	var date_part := iso_timestamp.left(10)  # "2026-03-22"
	var parts := date_part.split("-")
	if parts.size() < 3:
		return 0
	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2])
	var now := Time.get_datetime_dict_from_system(true)
	# Rough calculation — good enough for 60-day cooldowns
	var answered_days := year * 365 + month * 30 + day
	var now_days: int = int(now.get("year", 2026)) * 365 + int(now.get("month", 1)) * 30 + int(now.get("day", 1))
	return now_days - answered_days
