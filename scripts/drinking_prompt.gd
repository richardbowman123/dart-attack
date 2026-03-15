extends CanvasLayer
class_name DrinkingPrompt

## Drinking prompt — slides up after each player visit in career mode.
## Three choices: nothing, half pint, full pint.
## Auto-dismisses after 5 seconds (= "nothing").

signal choice_made(drink_type: int)  # 0=nothing, 1=half, 2=full

const DRINK_NONE := 0
const DRINK_HALF := 1
const DRINK_FULL := 2

const SLIDE_DURATION := 0.3
const AUTO_DISMISS_TIME := 5.0
const PANEL_HEIGHT := 100
const PANEL_Y_HIDDEN := 1280  # Off screen (below viewport)
const PANEL_Y_SHOWN := 1280 - PANEL_HEIGHT - 20

var _panel: PanelContainer
var _auto_timer: Tween
var _is_showing := false

func _ready() -> void:
	layer = 20  # Above everything else
	_build_ui()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.03, 0.92)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)
	_panel.position = Vector2(20, PANEL_Y_HIDDEN)
	_panel.size = Vector2(680, PANEL_HEIGHT)
	_panel.visible = false

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# Nothing button (grey)
	var btn_none := _make_button("NOTHING", Color(0.3, 0.3, 0.35), Color(0.5, 0.5, 0.55))
	btn_none.pressed.connect(_on_choice.bind(DRINK_NONE))
	hbox.add_child(btn_none)

	# Half pint button (amber)
	var btn_half := _make_button("HALF PINT", Color(0.6, 0.4, 0.1), Color(0.85, 0.6, 0.15))
	btn_half.pressed.connect(_on_choice.bind(DRINK_HALF))
	hbox.add_child(btn_half)

	# Full pint button (gold)
	var btn_full := _make_button("FULL PINT", Color(0.7, 0.55, 0.05), Color(1.0, 0.85, 0.0))
	btn_full.pressed.connect(_on_choice.bind(DRINK_FULL))
	hbox.add_child(btn_full)

	_panel.add_child(hbox)
	add_child(_panel)

func _make_button(text: String, bg_color: Color, border_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(190, 60)
	UIFont.apply_button(btn, UIFont.CAPTION)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))

	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = bg_color.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed)

	return btn

## Show the drinking prompt (slides up from bottom)
func show_prompt() -> void:
	if _is_showing:
		return
	_is_showing = true
	_panel.visible = true
	_panel.position.y = PANEL_Y_HIDDEN

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_panel, "position:y", PANEL_Y_SHOWN, SLIDE_DURATION)

	# Auto-dismiss after timeout
	_auto_timer = create_tween()
	_auto_timer.tween_interval(AUTO_DISMISS_TIME)
	_auto_timer.tween_callback(_on_choice.bind(DRINK_NONE))

## Hide the prompt (slides down)
func _hide_prompt() -> void:
	_is_showing = false
	if _auto_timer and _auto_timer.is_valid():
		_auto_timer.kill()

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_panel, "position:y", PANEL_Y_HIDDEN, SLIDE_DURATION)
	tween.tween_callback(func() -> void: _panel.visible = false)

func _on_choice(drink_type: int) -> void:
	if not _is_showing:
		return
	_hide_prompt()
	choice_made.emit(drink_type)

## Stub for future vision blur effect
func _apply_blur(_drinks: int) -> void:
	pass
