class_name CompanionPanel
extends CanvasLayer

## Companion dialogue panel — slides up from the bottom of the screen.
## Two modes:
##   BROADCAST — companion speaks, player taps to continue
##   INTERACTIVE — companion asks, player picks a response
##
## The same panel handles both modes. Response buttons are hidden in
## broadcast mode; "tap to continue" is hidden in interactive mode.

signal broadcast_finished
signal response_chosen(response_index: int)

# ---- Layout constants (720x1280 viewport) ----

const PANEL_WIDTH := 680
const PANEL_MARGIN_X := 20
const PANEL_Y_HIDDEN := 1340   # Off-screen below viewport
const SLIDE_DURATION := 0.35
const CHAR_DELAY := 0.035      # Seconds per character (~35ms typewriter)
const PORTRAIT_SIZE := 56

# ---- Internal state ----

enum PanelState { IDLE, TYPING, AWAITING_INPUT, TYPING_REPLY, AWAITING_DISMISS }

var _state: int = PanelState.IDLE
var _is_interactive := false
var _panel: PanelContainer
var _portrait_rect: ColorRect
var _portrait_label: Label
var _name_label: Label
var _dialogue_label: Label
var _tap_label: Label
var _response_container: HBoxContainer
var _response_buttons: Array[Button] = []
var _type_tween: Tween
var _full_text := ""

# ---- Setup ----

func _ready() -> void:
	layer = 20
	_build_ui()

func _build_ui() -> void:
	# Main panel container
	_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.07, 0.12, 0.94)
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 0
	panel_style.corner_radius_bottom_right = 0
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 14
	panel_style.content_margin_bottom = 14
	panel_style.border_width_top = 2
	panel_style.border_color = Color(0.85, 0.6, 0.15, 0.6)
	_panel.add_theme_stylebox_override("panel", panel_style)
	_panel.position = Vector2(PANEL_MARGIN_X, PANEL_Y_HIDDEN)
	_panel.size = Vector2(PANEL_WIDTH, 0)  # Height auto-sizes
	_panel.visible = false

	# Outer VBox: header row, dialogue, responses/tap
	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 10)

	# ---- Header row: portrait + name ----
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	header_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN

	# Portrait placeholder (colored square with initial)
	var portrait_wrapper := Control.new()
	portrait_wrapper.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)

	_portrait_rect = ColorRect.new()
	_portrait_rect.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait_rect.color = Color(0.35, 0.25, 0.15)
	portrait_wrapper.add_child(_portrait_rect)

	_portrait_label = Label.new()
	_portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait_label.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait_label.add_theme_color_override("font_color", Color.WHITE)
	UIFont.apply(_portrait_label, UIFont.SUBHEADING)
	portrait_wrapper.add_child(_portrait_label)

	header_hbox.add_child(portrait_wrapper)

	# Companion name
	_name_label = Label.new()
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.custom_minimum_size = Vector2(0, PORTRAIT_SIZE)
	_name_label.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
	UIFont.apply(_name_label, UIFont.CAPTION)
	header_hbox.add_child(_name_label)

	outer_vbox.add_child(header_hbox)

	# ---- Dialogue text ----
	_dialogue_label = Label.new()
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.custom_minimum_size = Vector2(PANEL_WIDTH - 48, 0)
	_dialogue_label.add_theme_color_override("font_color", Color.WHITE)
	UIFont.apply(_dialogue_label, UIFont.CAPTION)
	_dialogue_label.visible_characters = 0
	outer_vbox.add_child(_dialogue_label)

	# ---- Response buttons (interactive mode) ----
	_response_container = HBoxContainer.new()
	_response_container.add_theme_constant_override("separation", 12)
	_response_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_response_container.visible = false

	for i in range(2):
		var btn := _make_response_button("")
		btn.pressed.connect(_on_response_pressed.bind(i))
		_response_container.add_child(btn)
		_response_buttons.append(btn)

	outer_vbox.add_child(_response_container)

	# ---- Tap to continue label (broadcast mode) ----
	_tap_label = Label.new()
	_tap_label.text = "Tap to continue"
	_tap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tap_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 0.7))
	UIFont.apply(_tap_label, 18)
	_tap_label.visible = false
	outer_vbox.add_child(_tap_label)

	_panel.add_child(outer_vbox)
	add_child(_panel)

func _make_response_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 54)
	UIFont.apply_button(btn, 20)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))
	btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.7, 0.5))

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.15, 0.22)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.6, 0.15, 0.5)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = style.bg_color.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed)

	return btn

# =====================================================================
# PUBLIC API
# =====================================================================

## Show a broadcast line (companion speaks, player taps to continue).
func show_broadcast(speaker_name: String, text: String, stage: int) -> void:
	_is_interactive = false
	_setup_panel(speaker_name, stage)
	_response_container.visible = false
	_tap_label.visible = false  # Shown after typewriter finishes
	_start_typewriter(text)
	_slide_in()

## Show an interactive exchange (companion asks, player picks a response).
func show_interactive(speaker_name: String, prompt: String, labels: Array, stage: int) -> void:
	_is_interactive = true
	_setup_panel(speaker_name, stage)
	_response_container.visible = false  # Shown after typewriter finishes
	_tap_label.visible = false

	# Configure response buttons
	for i in range(min(labels.size(), _response_buttons.size())):
		_response_buttons[i].text = labels[i]
		_response_buttons[i].visible = true
	# Hide extra buttons if fewer than 2 responses
	for i in range(labels.size(), _response_buttons.size()):
		_response_buttons[i].visible = false

	_start_typewriter(prompt)
	_slide_in()

## Show a reply after an interactive choice (typewriter, then tap to dismiss).
func show_reply(text: String) -> void:
	_is_interactive = false
	_response_container.visible = false
	_tap_label.visible = false
	_start_typewriter(text)

## Dismiss the panel immediately.
func dismiss() -> void:
	if _state == PanelState.IDLE:
		return
	_state = PanelState.IDLE
	_kill_typewriter()
	_slide_out()

# =====================================================================
# INTERNAL
# =====================================================================

func _setup_panel(speaker_name: String, stage: int) -> void:
	_name_label.text = speaker_name.to_upper()

	# Portrait placeholder
	var color: Color = CompanionData.PORTRAIT_COLORS.get(stage, Color(0.3, 0.3, 0.3))
	_portrait_rect.color = color
	_portrait_label.text = speaker_name.left(1).to_upper()

func _start_typewriter(text: String) -> void:
	_full_text = text
	_dialogue_label.text = text
	_dialogue_label.visible_characters = 0
	_state = PanelState.TYPING

	_kill_typewriter()
	var duration := text.length() * CHAR_DELAY
	if duration < 0.1:
		duration = 0.1
	_type_tween = create_tween()
	_type_tween.tween_property(_dialogue_label, "visible_characters", text.length(), duration)
	_type_tween.tween_callback(_on_typewriter_done)

func _on_typewriter_done() -> void:
	_dialogue_label.visible_characters = -1  # Show all
	if _is_interactive and _state == PanelState.TYPING:
		_state = PanelState.AWAITING_INPUT
		_response_container.visible = true
	elif _state == PanelState.TYPING:
		_state = PanelState.AWAITING_INPUT
		_tap_label.visible = true
	elif _state == PanelState.TYPING_REPLY:
		_state = PanelState.AWAITING_DISMISS
		_tap_label.visible = true

func _skip_typewriter() -> void:
	_kill_typewriter()
	_dialogue_label.visible_characters = -1
	_on_typewriter_done()

func _kill_typewriter() -> void:
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
	_type_tween = null

func _slide_in() -> void:
	_panel.visible = true
	_panel.position.y = PANEL_Y_HIDDEN

	# Let the panel calculate its size, then determine target Y
	_panel.reset_size()
	await get_tree().process_frame
	var target_y := 1280.0 - _panel.size.y - 10.0
	# Clamp so panel doesn't go above mid-screen
	target_y = max(target_y, 700.0)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_panel, "position:y", target_y, SLIDE_DURATION)

func _slide_out() -> void:
	_tap_label.visible = false
	_response_container.visible = false
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_panel, "position:y", float(PANEL_Y_HIDDEN), SLIDE_DURATION)
	tween.tween_callback(func() -> void: _panel.visible = false)

# ---- Input handling ----

func _unhandled_input(event: InputEvent) -> void:
	if _state == PanelState.IDLE:
		return

	# Accept touch or mouse click
	var is_tap := false
	if event is InputEventScreenTouch and event.pressed:
		is_tap = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_tap = true

	if not is_tap:
		return

	match _state:
		PanelState.TYPING:
			# Skip typewriter — show all text immediately
			_skip_typewriter()
			get_viewport().set_input_as_handled()
		PanelState.AWAITING_INPUT:
			if not _is_interactive:
				# Broadcast mode — tap dismisses
				_state = PanelState.IDLE
				_slide_out()
				broadcast_finished.emit()
				get_viewport().set_input_as_handled()
			# Interactive mode — wait for button press (don't consume tap)
		PanelState.TYPING_REPLY:
			_skip_typewriter()
			get_viewport().set_input_as_handled()
		PanelState.AWAITING_DISMISS:
			_state = PanelState.IDLE
			_slide_out()
			broadcast_finished.emit()
			get_viewport().set_input_as_handled()

func _on_response_pressed(index: int) -> void:
	if _state != PanelState.AWAITING_INPUT:
		return
	_response_container.visible = false
	_state = PanelState.TYPING_REPLY
	response_chosen.emit(index)
