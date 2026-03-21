extends CanvasLayer
class_name ScoreHUD

# ── Layout constants ──
const REMAINING_MARGIN := 20
const IMPACT_FADE_TIME := 1.2
const SUMMARY_DISPLAY_TIME := 2.5

# ── Bottom card layout ──
const CARD_MARGIN := 10
const CARD_Y := 1000
const CARD_W := 700
const CARD_H := 270
const CARD_PORTRAIT_SIZE := 90
const CARD_PAD := 12          # Inner padding on all sides
const CARD_DOT_SIZE := 12
const CARD_DOT_GAP := 20
# Row Y offsets inside the card (from top of card):
const ROW_PORTRAIT_Y := 10   # Portraits + names row
const ROW_DIVIDER_Y := 108   # Thin line after portraits
const ROW_DOTS_Y := 116      # Dart dots
const ROW_STATS_Y := 140     # Stats bars start

# ── Node references ──
var _remaining_label: Label
var _impact_label: Label
var _summary_panel: PanelContainer
var _summary_content: VBoxContainer
var _message_tween: Tween  # Track active message to prevent stacking
var _summary_title: Label
var _summary_darts_label: Label
var _summary_total_label: Label
var _rtc_hits_rich: RichTextLabel
var _summary_remaining_label: Label

# ── VS mode elements ──
var _is_vs_mode := false
var _vs_opponent_id := ""
var _opponent_label: Label
var _turn_indicator: Label

# ── Bottom card (unified HUD — VS mode only) ──
var _card_accent: StyleBoxFlat  # Accent border style (changes colour on turn)
var _player_portrait: Control
var _player_name_label: Label
var _player_nick_label: Label
var _opp_portrait_panel: Control
var _opp_initial_label: Label
var _opp_name_label: Label
var _opp_nick_label: Label
var _portrait_left: Control    # Left slot in card
var _portrait_right: Control   # Right slot in card
var _name_left: Control        # Left name area
var _name_right: Control       # Right name area
var _portrait_tween: Tween     # Track portrait fade tween
var _dart_dot_container: Control
var _dart_dots: Array[Control] = []

var _zoom_hint: Label

# ── Leg counter (multi-leg matches only) ──
var _leg_counter: Label
var _leg_counter_tween: Tween
var _legs_to_win_display: int = 1

# ── Popup layer (above drunk overlay at layer 10) ──
var _popup_layer: CanvasLayer

# ── Throw tip popup ──
var _throw_tip_overlay: Control

# ── Doubles tip popup (one-time, first countdown game) ──
var _doubles_tip_overlay: Control

# ── Coach checkout tip popup (one-time, 301/501 when score <= 170) ──
var _coach_checkout_overlay: Control
var _coach_checkout_callback: Callable

# ── Sweet spot tip popup (one-time, when sobering from blurry to clear) ──
var _sweet_spot_overlay: Control

# ── Balance display (career mode only) ──
const BALANCE_BOX_W := 160
const BALANCE_BOX_H := 24
const BALANCE_Y := 2
var _balance_panel: PanelContainer
var _balance_label: Label

# ── Stats bars (career mode only) ──
const STATS_BAR_WIDTH := 220
const STATS_BAR_HEIGHT := 12
const STATS_GAP := 8
const STATS_ROW_STEP := 24
const BAR_NAMES: Array[String] = ["DARTS", "NERVES", "CONFIDENCE", "ANGER"]

var _bar_bgs: Array[ColorRect] = []
var _bar_fills: Array[ColorRect] = []
var _bar_labels: Array[Label] = []
var _bar_tweens: Array = []  # Per-bar tween tracking (so we can kill/replace)
var _stats_container: Control

# ── Debug skip (hidden 10-tap trigger) ──
signal debug_menu_requested
var _debug_tap_count: int = 0
var _debug_last_tap_ms: int = 0

func _ready() -> void:
	# Popup layer renders above the drunk vision overlay (layer 10)
	_popup_layer = CanvasLayer.new()
	_popup_layer.layer = 15
	add_child(_popup_layer)

	_build_remaining_display()
	_build_impact_flash()
	_build_summary_panel()
	_build_zoom_hint()
	_build_balance_display()
	_build_throw_tip()
	_build_doubles_tip()
	_build_coach_checkout_tip()
	_build_sweet_spot_tip()
	DrinkManager.sweet_spot_reached.connect(_on_sweet_spot_reached)
	_build_debug_tap_zone()
	# In non-VS mode, build standalone dart dots at the bottom
	if not GameState.is_vs_ai:
		_build_standalone_dart_dots()

# ── Remaining score (small, top-right corner) ──

func _build_remaining_display() -> void:
	_remaining_label = Label.new()
	_remaining_label.text = ""
	UIFont.apply(_remaining_label, 38)
	_remaining_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.7))
	_remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_remaining_label.position = Vector2(REMAINING_MARGIN, REMAINING_MARGIN)
	_remaining_label.size = Vector2(250, 45)
	_remaining_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_remaining_label)

# ── Mini dart shape builder ──

func _build_mini_dart(flight_color: Color, barrel_color: Color) -> Control:
	# Vertical dart (flight at top, tip at bottom) — shield-shaped flight
	var dart := Control.new()
	var w := 24
	var h := 80
	dart.size = Vector2(w, h)
	dart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Flight (shield/heart shape — matches the 3D dart fin profile)
	var flight := Control.new()
	flight.position = Vector2(0, 0)
	flight.size = Vector2(w, 28)
	flight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := flight_color  # capture for draw callback
	var fw := float(w)
	flight.draw.connect(func() -> void:
		var pts := PackedVector2Array([
			Vector2(fw * 0.5, 28),       # bottom centre (meets barrel)
			Vector2(fw * 0.15, 22),      # lower-left taper
			Vector2(0, 12),              # left shoulder (widest)
			Vector2(fw * 0.08, 3),       # top-left curve
			Vector2(fw * 0.3, 0),        # left bump peak
			Vector2(fw * 0.5, 4),        # top centre dip (heart notch)
			Vector2(fw * 0.7, 0),        # right bump peak
			Vector2(fw * 0.92, 3),       # top-right curve
			Vector2(fw, 12),             # right shoulder (widest)
			Vector2(fw * 0.85, 22),      # lower-right taper
		])
		flight.draw_colored_polygon(pts, col)
	)
	dart.add_child(flight)
	# Barrel (middle, narrow)
	var barrel := ColorRect.new()
	barrel.color = barrel_color
	barrel.position = Vector2((w - 8) / 2.0, 28)
	barrel.size = Vector2(8, 38)
	barrel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dart.add_child(barrel)
	# Tip (bottom, tapered point)
	var tip := ColorRect.new()
	tip.color = Color(0.7, 0.7, 0.72)
	tip.position = Vector2((w - 4) / 2.0, 66)
	tip.size = Vector2(4, 14)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dart.add_child(tip)
	return dart

# ── Three mini darts (built inside the bottom card, not standalone) ──

func _build_dart_dots(parent: Control, y_offset: float) -> void:
	_dart_dot_container = Control.new()
	_dart_dot_container.position = Vector2(0, y_offset)
	_dart_dot_container.size = Vector2(CARD_W, 85)
	_dart_dot_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_dart_dot_container)

	var flight_cols := DartData.get_flight_colors(GameState.character)
	var barrel_col: Color = DartData.get_tier(GameState.dart_tier)["barrel_color"]

	var dart_w := 24
	var gap := 12
	var total_w := 3 * dart_w + 2 * gap
	var start_x := (CARD_W - total_w) / 2.0

	_dart_dots.clear()
	for i in range(3):
		var mini := _build_mini_dart(flight_cols["front"], barrel_col)
		mini.position = Vector2(start_x + i * (dart_w + gap), 0)
		_dart_dot_container.add_child(mini)
		_dart_dots.append(mini)

func _build_standalone_dart_dots() -> void:
	# Mini darts for practise/tutorial/free throw mode (no card)
	var y := 1190.0
	var container := Control.new()
	container.position = Vector2(0, y)
	container.size = Vector2(720, 85)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	var flight_cols := DartData.get_flight_colors(GameState.character)
	var barrel_col: Color = DartData.get_tier(GameState.dart_tier)["barrel_color"]

	var dart_w := 24
	var gap := 12
	var total_w := 3 * dart_w + 2 * gap
	var start_x := (720 - total_w) / 2.0

	_dart_dots.clear()
	for i in range(3):
		var mini := _build_mini_dart(flight_cols["front"], barrel_col)
		mini.position = Vector2(start_x + i * (dart_w + gap), 0)
		container.add_child(mini)
		_dart_dots.append(mini)

# ── Zoom reminder ──

var _zoom_hint_tween: Tween

func _build_zoom_hint() -> void:
	_zoom_hint = Label.new()
	_zoom_hint.text = "Don't forget to zoom in"
	UIFont.apply(_zoom_hint, 24)
	_zoom_hint.add_theme_color_override("font_color", Color.WHITE)
	_zoom_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_hint.position = Vector2(60, 210)
	_zoom_hint.size = Vector2(600, 28)
	_zoom_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom_hint.visible = false
	add_child(_zoom_hint)

## Show the zoom reminder. persistent=false: white flash that fades.
## persistent=true: red text that stays until dismissed.
func show_zoom_reminder(persistent: bool) -> void:
	if not _zoom_hint:
		return
	# Kill any running animation
	if _zoom_hint_tween and _zoom_hint_tween.is_valid():
		_zoom_hint_tween.kill()
	_zoom_hint.visible = true
	_zoom_hint.modulate = Color(1, 1, 1, 1)

	if persistent:
		# Red text, stays visible
		_zoom_hint.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	else:
		# White text, pulse in then fade out after 2.5s
		_zoom_hint.add_theme_color_override("font_color", Color.WHITE)
		_zoom_hint_tween = create_tween()
		# Pulse: fade in, hold, fade out
		_zoom_hint.modulate.a = 0.0
		_zoom_hint_tween.tween_property(_zoom_hint, "modulate:a", 1.0, 0.3)
		_zoom_hint_tween.tween_interval(2.0)
		_zoom_hint_tween.tween_property(_zoom_hint, "modulate:a", 0.0, 0.8)
		_zoom_hint_tween.tween_callback(func() -> void:
			_zoom_hint.visible = false
		)

func hide_zoom_reminder() -> void:
	if not _zoom_hint:
		return
	if _zoom_hint_tween and _zoom_hint_tween.is_valid():
		_zoom_hint_tween.kill()
	if _zoom_hint.visible:
		# Quick fade out
		_zoom_hint_tween = create_tween()
		_zoom_hint_tween.tween_property(_zoom_hint, "modulate:a", 0.0, 0.3)
		_zoom_hint_tween.tween_callback(func() -> void:
			_zoom_hint.visible = false
		)

func hide_zoom_hint_forever() -> void:
	hide_zoom_reminder()

# ── Balance display (career mode only, top-centre) ──

func _build_balance_display() -> void:
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
	_balance_panel.position = Vector2((720 - BALANCE_BOX_W) / 2.0, BALANCE_Y)
	_balance_panel.size = Vector2(BALANCE_BOX_W, BALANCE_BOX_H)
	_balance_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_balance_label = Label.new()
	UIFont.apply(_balance_label, 24)
	_balance_label.add_theme_color_override("font_color", Color.WHITE)
	_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_balance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_balance_label.text = _format_money(CareerState.money)

	_balance_panel.add_child(_balance_label)
	add_child(_balance_panel)

func _format_money(pence: int) -> String:
	var pounds_val := int(pence / 100)
	var pence_val := pence % 100
	if pence < 10000:
		# Below 100 pounds — show pence (e.g. "£3.40")
		return "£" + str(pounds_val) + "." + ("0" + str(pence_val) if pence_val < 10 else str(pence_val))
	elif pence < 100000:
		# £100-£999 — no pence
		return "£" + str(pounds_val)
	else:
		# £1,000+ — with comma separator
		var result := ""
		var s := str(pounds_val)
		var len_s := s.length()
		for i in range(len_s):
			if i > 0 and (len_s - i) % 3 == 0:
				result += ","
			result += s[i]
		return "£" + result

func update_balance(pence: int) -> void:
	if _balance_label:
		_balance_label.text = _format_money(pence)

# ── Throw tip popup (shows when swipe doesn't register) ──

func _build_throw_tip() -> void:
	# Full-screen overlay catches all touches while visible
	_throw_tip_overlay = Control.new()
	_throw_tip_overlay.size = Vector2(720, 1280)
	_throw_tip_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_throw_tip_overlay.visible = false
	_throw_tip_overlay.z_index = 100
	_throw_tip_overlay.gui_input.connect(_on_throw_tip_bg_input)

	# Slight screen dimmer
	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.3)
	dimmer.size = Vector2(720, 1280)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_throw_tip_overlay.add_child(dimmer)

	# Message panel
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(110, 380)
	panel.size = Vector2(500, 140)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var msg := Label.new()
	msg.text = "Nearly! Try a bigger, steadier\nswipe to throw the dart."
	UIFont.apply(msg, 24)
	msg.add_theme_color_override("font_color", Color.WHITE)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(msg)

	var btn := Button.new()
	btn.text = "Got it, don't show again"
	UIFont.apply_button(btn, 18)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.2, 0.25, 0.5)
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6
	btn_style.content_margin_left = 12
	btn_style.content_margin_right = 12
	btn_style.content_margin_top = 8
	btn_style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_stylebox_override("hover", btn_style)
	btn.add_theme_stylebox_override("pressed", btn_style)
	btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	btn.add_theme_color_override("font_hover_color", Color(0.8, 0.8, 0.85))
	btn.add_theme_color_override("font_pressed_color", Color(0.45, 0.45, 0.5))
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_throw_tip_dismiss_forever)
	vbox.add_child(btn)

	panel.add_child(vbox)
	_throw_tip_overlay.add_child(panel)
	_popup_layer.add_child(_throw_tip_overlay)

func show_throw_tip() -> void:
	if not _throw_tip_overlay or _throw_tip_overlay.visible:
		return
	_throw_tip_overlay.visible = true
	_throw_tip_overlay.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_throw_tip_overlay, "modulate", Color(1, 1, 1, 1), 0.2)

func _on_throw_tip_bg_input(event: InputEvent) -> void:
	# Tap anywhere outside the panel to dismiss
	if event is InputEventScreenTouch and event.pressed:
		_throw_tip_overlay.visible = false
	elif event is InputEventMouseButton and event.pressed:
		_throw_tip_overlay.visible = false

func _on_throw_tip_dismiss_forever() -> void:
	_throw_tip_overlay.visible = false
	GameState.dismiss_throw_tip()

# ── Doubles tip popup (one-time, first countdown game) ──

func _build_doubles_tip() -> void:
	_doubles_tip_overlay = Control.new()
	_doubles_tip_overlay.size = Vector2(720, 1280)
	_doubles_tip_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_doubles_tip_overlay.visible = false
	_doubles_tip_overlay.z_index = 100

	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.3)
	dimmer.size = Vector2(720, 1280)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_doubles_tip_overlay.add_child(dimmer)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.94)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.6, 0.15, 0.6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(40, 260)
	panel.size = Vector2(640, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Portrait — small thumbnail, aspect ratio preserved (80x123, centred)
	# Alan image is 832x1281 — at 80px wide, height = 80 * 1281/832 = 123px
	var portrait_tex := TextureRect.new()
	var img := load("res://Mate for Level 2 - Alan.png")
	if img:
		portrait_tex.texture = img
		portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_tex.custom_minimum_size = Vector2(80, 123)
		portrait_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		portrait_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(portrait_tex)

	# Name label
	var name_label := Label.new()
	name_label.text = "Alan"
	UIFont.apply(name_label, UIFont.BODY)
	name_label.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# Dialogue text
	var msg := Label.new()
	msg.text = "Just remember, you have to hit a double to win this one."
	UIFont.apply(msg, UIFont.CAPTION)
	msg.add_theme_color_override("font_color", Color.WHITE)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(msg)

	# Got it button — companion panel response style
	var btn := Button.new()
	btn.text = "Got it"
	UIFont.apply_button(btn, UIFont.CAPTION)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.18, 0.15, 0.22)
	btn_normal.corner_radius_top_left = 10
	btn_normal.corner_radius_top_right = 10
	btn_normal.corner_radius_bottom_left = 10
	btn_normal.corner_radius_bottom_right = 10
	btn_normal.border_width_left = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = Color(0.85, 0.6, 0.15, 0.5)
	btn_normal.content_margin_left = 16
	btn_normal.content_margin_right = 16
	btn_normal.content_margin_top = 10
	btn_normal.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", btn_normal)
	btn.add_theme_stylebox_override("hover", btn_normal)
	btn.add_theme_stylebox_override("pressed", btn_normal)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))
	btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.7, 0.5))
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_doubles_tip_dismiss)
	vbox.add_child(btn)

	panel.add_child(vbox)
	_doubles_tip_overlay.add_child(panel)
	_popup_layer.add_child(_doubles_tip_overlay)

func show_doubles_tip() -> void:
	if not _doubles_tip_overlay or _doubles_tip_overlay.visible:
		return
	if CareerState.doubles_tip_shown:
		return
	_doubles_tip_overlay.visible = true
	_doubles_tip_overlay.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_doubles_tip_overlay, "modulate", Color(1, 1, 1, 1), 0.2)

func _on_doubles_tip_dismiss() -> void:
	_doubles_tip_overlay.visible = false
	CareerState.doubles_tip_shown = true

# ── Coach checkout tip popup (one-time, 301/501 when score enters checkout range) ──

func _build_coach_checkout_tip() -> void:
	_coach_checkout_overlay = Control.new()
	_coach_checkout_overlay.size = Vector2(720, 1280)
	_coach_checkout_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_coach_checkout_overlay.visible = false
	_coach_checkout_overlay.z_index = 100

	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.3)
	dimmer.size = Vector2(720, 1280)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coach_checkout_overlay.add_child(dimmer)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.94)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.6, 0.15, 0.6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(40, 260)
	panel.size = Vector2(640, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var portrait_tex := TextureRect.new()
	var img := load("res://Coach cropped.png")
	if img:
		portrait_tex.texture = img
		portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_tex.custom_minimum_size = Vector2(80, 123)
		portrait_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		portrait_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(portrait_tex)

	var name_label := Label.new()
	name_label.text = "The Coach"
	UIFont.apply(name_label, UIFont.BODY)
	name_label.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	var msg := Label.new()
	msg.text = "You can check out from here. Get it low, find your double."
	UIFont.apply(msg, UIFont.CAPTION)
	msg.add_theme_color_override("font_color", Color.WHITE)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(msg)

	var btn := Button.new()
	btn.text = "Got it"
	UIFont.apply_button(btn, UIFont.CAPTION)
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.18, 0.15, 0.22)
	btn_normal.corner_radius_top_left = 10
	btn_normal.corner_radius_top_right = 10
	btn_normal.corner_radius_bottom_left = 10
	btn_normal.corner_radius_bottom_right = 10
	btn_normal.border_width_left = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = Color(0.85, 0.6, 0.15, 0.5)
	btn_normal.content_margin_left = 16
	btn_normal.content_margin_right = 16
	btn_normal.content_margin_top = 10
	btn_normal.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", btn_normal)
	btn.add_theme_stylebox_override("hover", btn_normal)
	btn.add_theme_stylebox_override("pressed", btn_normal)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))
	btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.7, 0.5))
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_coach_checkout_dismiss)
	vbox.add_child(btn)

	panel.add_child(vbox)
	_coach_checkout_overlay.add_child(panel)
	_popup_layer.add_child(_coach_checkout_overlay)

func show_coach_checkout_tip(callback: Callable) -> void:
	if not _coach_checkout_overlay or _coach_checkout_overlay.visible:
		return
	_coach_checkout_callback = callback
	_coach_checkout_overlay.visible = true
	_coach_checkout_overlay.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_coach_checkout_overlay, "modulate", Color(1, 1, 1, 1), 0.2)

func _on_coach_checkout_dismiss() -> void:
	_coach_checkout_overlay.visible = false
	if _coach_checkout_callback.is_valid():
		_coach_checkout_callback.call()

# ── Sweet spot tip popup (one-time, when vision clears after being drunk) ──

func _build_sweet_spot_tip() -> void:
	_sweet_spot_overlay = Control.new()
	_sweet_spot_overlay.size = Vector2(720, 1280)
	_sweet_spot_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_sweet_spot_overlay.visible = false
	_sweet_spot_overlay.z_index = 100

	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.3)
	dimmer.size = Vector2(720, 1280)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sweet_spot_overlay.add_child(dimmer)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.94)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.6, 0.15, 0.6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(40, 260)
	panel.size = Vector2(640, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Portrait — small thumbnail, aspect ratio preserved (80px tall, width natural)
	# Alan image is 832x1281 — at 80px tall, width = 80 * 832/1281 = 52px
	var portrait_tex := TextureRect.new()
	var img := load("res://Mate for Level 2 - Alan.png")
	if img:
		portrait_tex.texture = img
		portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_tex.custom_minimum_size = Vector2(52, 80)
		portrait_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		portrait_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(portrait_tex)

	# Name label
	var name_label := Label.new()
	name_label.text = "Alan"
	UIFont.apply(name_label, UIFont.BODY)
	name_label.add_theme_color_override("font_color", Color(0.85, 0.6, 0.15))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# Dialogue text
	var msg := Label.new()
	msg.text = "You're handling the booze pretty well now. Clear eyes, steady nerves, bags of confidence. This is your peak condition — remember this feeling for the big matches."
	UIFont.apply(msg, UIFont.CAPTION)
	msg.add_theme_color_override("font_color", Color.WHITE)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(msg)

	# Got it button — companion panel response style
	var btn := Button.new()
	btn.text = "Got it"
	UIFont.apply_button(btn, UIFont.CAPTION)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.18, 0.15, 0.22)
	btn_normal.corner_radius_top_left = 10
	btn_normal.corner_radius_top_right = 10
	btn_normal.corner_radius_bottom_left = 10
	btn_normal.corner_radius_bottom_right = 10
	btn_normal.border_width_left = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = Color(0.85, 0.6, 0.15, 0.5)
	btn_normal.content_margin_left = 16
	btn_normal.content_margin_right = 16
	btn_normal.content_margin_top = 10
	btn_normal.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", btn_normal)
	btn.add_theme_stylebox_override("hover", btn_normal)
	btn.add_theme_stylebox_override("pressed", btn_normal)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))
	btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.7, 0.5))
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_sweet_spot_dismiss)
	vbox.add_child(btn)

	panel.add_child(vbox)
	_sweet_spot_overlay.add_child(panel)
	_popup_layer.add_child(_sweet_spot_overlay)

func _on_sweet_spot_reached() -> void:
	if CareerState.sweet_spot_tip_shown:
		return
	if not CareerState.career_mode_active:
		return
	show_sweet_spot_tip()

func show_sweet_spot_tip() -> void:
	if not _sweet_spot_overlay or _sweet_spot_overlay.visible:
		return
	if CareerState.sweet_spot_tip_shown:
		return
	_sweet_spot_overlay.visible = true
	_sweet_spot_overlay.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_sweet_spot_overlay, "modulate", Color(1, 1, 1, 1), 0.2)

func _on_sweet_spot_dismiss() -> void:
	_sweet_spot_overlay.visible = false
	CareerState.sweet_spot_tip_shown = true

# ── Debug tap zone (hidden 10-tap trigger, top-right corner) ──

func _build_debug_tap_zone() -> void:
	var zone := Control.new()
	zone.position = Vector2(620, 0)
	zone.size = Vector2(100, 100)
	zone.mouse_filter = Control.MOUSE_FILTER_STOP
	zone.gui_input.connect(_on_debug_tap_input)
	add_child(zone)

func _on_debug_tap_input(event: InputEvent) -> void:
	var is_tap := false
	if event is InputEventScreenTouch and event.pressed:
		is_tap = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_tap = true
	if not is_tap:
		return

	var now := Time.get_ticks_msec()
	# Reset counter if more than 2 seconds since last tap
	if now - _debug_last_tap_ms > 2000:
		_debug_tap_count = 0
	_debug_last_tap_ms = now
	_debug_tap_count += 1

	if _debug_tap_count >= 10:
		_debug_tap_count = 0
		debug_menu_requested.emit()

# ── Impact flash (brief score text that fades) ──

func _build_impact_flash() -> void:
	_impact_label = Label.new()
	_impact_label.text = ""
	UIFont.apply(_impact_label, 48)
	_impact_label.add_theme_color_override("font_color", Color.WHITE)
	_impact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_impact_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_impact_label.size = Vector2(200, 50)
	_impact_label.visible = false
	_impact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_impact_label)

# ── Visit summary panel (appears after 3 darts) ──

func _build_summary_panel() -> void:
	_summary_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_summary_panel.add_theme_stylebox_override("panel", style)
	_summary_panel.position = Vector2(60, 450)
	_summary_panel.size = Vector2(600, 0)  # Width 600, height auto-sizes from content
	_summary_panel.visible = false
	_summary_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_summary_content = VBoxContainer.new()
	_summary_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_content.add_theme_constant_override("separation", 6)

	_summary_title = Label.new()
	UIFont.apply(_summary_title, 24)
	_summary_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_summary_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_content.add_child(_summary_title)

	_summary_darts_label = Label.new()
	UIFont.apply(_summary_darts_label, 38)
	_summary_darts_label.add_theme_color_override("font_color", Color.WHITE)
	_summary_darts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_darts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_darts_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_content.add_child(_summary_darts_label)

	_summary_total_label = Label.new()
	UIFont.apply(_summary_total_label, 48)
	_summary_total_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_summary_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_total_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_total_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_content.add_child(_summary_total_label)

	_rtc_hits_rich = RichTextLabel.new()
	_rtc_hits_rich.bbcode_enabled = true
	_rtc_hits_rich.fit_content = true
	_rtc_hits_rich.scroll_active = false
	UIFont.apply_rich(_rtc_hits_rich, 38)
	_rtc_hits_rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rtc_hits_rich.visible = false
	_summary_content.add_child(_rtc_hits_rich)

	_summary_remaining_label = Label.new()
	UIFont.apply(_summary_remaining_label, 30)
	_summary_remaining_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_summary_remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_remaining_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_content.add_child(_summary_remaining_label)

	_summary_panel.add_child(_summary_content)
	_popup_layer.add_child(_summary_panel)

# ── VS mode setup (called by match_manager when is_vs_ai) ──

func setup_vs_mode(opponent_id: String) -> void:
	_is_vs_mode = true
	_vs_opponent_id = opponent_id

	# Opponent name + score at top-right
	_opponent_label = Label.new()
	var opp_name := OpponentData.get_display_name(opponent_id)
	_opponent_label.text = opp_name
	UIFont.apply(_opponent_label, 30)
	_opponent_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.5))
	_opponent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_opponent_label.position = Vector2(720 - 300 - REMAINING_MARGIN, REMAINING_MARGIN)
	_opponent_label.size = Vector2(300, 55)
	_opponent_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_opponent_label)

	# Turn indicator — large, over the top of the board
	_turn_indicator = Label.new()
	_turn_indicator.text = "YOUR THROW"
	UIFont.apply(_turn_indicator, 48)
	_turn_indicator.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3, 0.7))
	_turn_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_indicator.position = Vector2(60, 155)
	_turn_indicator.size = Vector2(600, 50)
	_turn_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_turn_indicator)

	# Build unified bottom card (portraits, names, dart dots, stats)
	_build_bottom_card(opponent_id)

## Set up the leg counter for multi-leg matches (called from match_manager).
func setup_leg_counter(legs_to_win: int) -> void:
	if legs_to_win <= 1:
		return
	_legs_to_win_display = legs_to_win
	var best_of: int = legs_to_win * 2 - 1
	_leg_counter = Label.new()
	_leg_counter.text = "LEGS 0 - 0 (Best of " + str(best_of) + ")"
	UIFont.apply(_leg_counter, 24)
	_leg_counter.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	_leg_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_leg_counter.position = Vector2(60, 210)
	_leg_counter.size = Vector2(600, 30)
	_leg_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_leg_counter)
	# Push zoom hint down so it doesn't overlap the leg counter
	if _zoom_hint:
		_zoom_hint.position.y = 245

## Update the leg score display and flash on change.
func update_leg_score(player_legs: int, opp_legs: int) -> void:
	if not _leg_counter:
		return
	var best_of: int = _legs_to_win_display * 2 - 1
	_leg_counter.text = "LEGS " + str(player_legs) + " - " + str(opp_legs) + " (Best of " + str(best_of) + ")"
	# Flash: full opacity then fade to 50%
	if _leg_counter_tween and _leg_counter_tween.is_valid():
		_leg_counter_tween.kill()
	_leg_counter.add_theme_color_override("font_color", Color(1, 1, 1, 1.0))
	_leg_counter_tween = create_tween()
	_leg_counter_tween.tween_interval(1.0)
	_leg_counter_tween.tween_property(_leg_counter, "theme_override_colors/font_color", Color(1, 1, 1, 0.5), 0.5)

# ── Bottom card (unified HUD — portraits, names, dots, stats) ──

func _build_bottom_card(opponent_id: String) -> void:
	# Use Panel (NOT PanelContainer) so children keep their explicit sizes
	var card := Panel.new()
	_card_accent = StyleBoxFlat.new()
	_card_accent.bg_color = Color(0.06, 0.06, 0.09, 0.92)
	_card_accent.corner_radius_top_left = 14
	_card_accent.corner_radius_top_right = 14
	_card_accent.corner_radius_bottom_left = 14
	_card_accent.corner_radius_bottom_right = 14
	_card_accent.border_width_left = 2
	_card_accent.border_width_right = 2
	_card_accent.border_width_top = 2
	_card_accent.border_width_bottom = 2
	_card_accent.border_color = Color(0.2, 0.6, 0.25)
	card.add_theme_stylebox_override("panel", _card_accent)
	card.position = Vector2(CARD_MARGIN, CARD_Y)
	card.size = Vector2(CARD_W, CARD_H)
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)

	# ── Zone calculations (all relative to card top-left) ──
	# Left portrait: x=PAD, y=ROW_PORTRAIT_Y, 90x90
	# Left name: x=PAD+90+10, y=ROW_PORTRAIT_Y, width=to centre, height=90
	# Right name: x=centre+5, y=ROW_PORTRAIT_Y, width=to right portrait, height=90
	# Right portrait: x=CARD_W-PAD-90, y=ROW_PORTRAIT_Y, 90x90
	var name_left_x := CARD_PAD + CARD_PORTRAIT_SIZE + 10
	var name_w := (CARD_W / 2.0) - name_left_x
	var right_portrait_x := CARD_W - CARD_PAD - CARD_PORTRAIT_SIZE
	var name_right_x := CARD_W / 2.0 + 5

	# ── Left portrait slot ──
	_portrait_left = Control.new()
	_portrait_left.position = Vector2(CARD_PAD, ROW_PORTRAIT_Y)
	_portrait_left.size = Vector2(CARD_PORTRAIT_SIZE, CARD_PORTRAIT_SIZE)
	_portrait_left.clip_contents = true
	_portrait_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(_portrait_left)

	# ── Right portrait slot ──
	_portrait_right = Control.new()
	_portrait_right.position = Vector2(right_portrait_x, ROW_PORTRAIT_Y)
	_portrait_right.size = Vector2(CARD_PORTRAIT_SIZE, CARD_PORTRAIT_SIZE)
	_portrait_right.clip_contents = true
	_portrait_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(_portrait_right)

	# ── Left name area ──
	_name_left = Control.new()
	_name_left.position = Vector2(name_left_x, ROW_PORTRAIT_Y)
	_name_left.size = Vector2(name_w, CARD_PORTRAIT_SIZE)
	_name_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(_name_left)

	# ── Right name area ──
	_name_right = Control.new()
	_name_right.position = Vector2(name_right_x, ROW_PORTRAIT_Y)
	_name_right.size = Vector2(name_w, CARD_PORTRAIT_SIZE)
	_name_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(_name_right)

	# ── Thin divider line ──
	var divider := ColorRect.new()
	divider.color = Color(0.2, 0.2, 0.25)
	divider.position = Vector2(20, ROW_DIVIDER_Y)
	divider.size = Vector2(CARD_W - 40, 1)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(divider)

	# ── Stats bars + dart dots (career mode) or standalone dots (non-career) ──
	if CareerState.career_mode_active:
		_build_stats_bars_in_card(card, ROW_STATS_Y)
	else:
		_build_dart_dots(card, ROW_DOTS_Y)

	# ── Build portrait + label elements ──
	_player_portrait = _build_player_portrait()
	_portrait_left.add_child(_player_portrait)

	_player_name_label = Label.new()
	_player_name_label.text = DartData.get_character_name(GameState.character)
	_player_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_player_nick_label = Label.new()
	if CareerState.nickname_active:
		_player_nick_label.text = DartData.get_character_nickname(GameState.character)
	else:
		_player_nick_label.text = ""
	_player_nick_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_opp_portrait_panel = _build_opponent_placeholder(opponent_id)
	_portrait_right.add_child(_opp_portrait_panel)

	_opp_name_label = Label.new()
	_opp_name_label.text = OpponentData.get_display_name(opponent_id)
	_opp_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_opp_nick_label = Label.new()
	_opp_nick_label.text = OpponentData.get_nickname(opponent_id)
	_opp_nick_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Default layout: player turn
	_set_card_layout(true)

func _build_player_portrait() -> Control:
	var sz := CARD_PORTRAIT_SIZE
	# Load image directly (no ResourceLoader.exists check — it fails on spaced paths)
	var image_path: String
	if CareerState.career_mode_active:
		image_path = DartData.get_profile_image_for_tier(GameState.character, CareerState.calculate_appearance_tier())
	else:
		image_path = DartData.get_profile_image(GameState.character)
	var tex: Texture2D = load(image_path)
	if not tex:
		push_warning("Player portrait failed to load: " + image_path + " — try deleting .godot folder")

	if tex:
		# Height-anchored portrait — fix height at 90px, width from aspect ratio
		var tex_size := tex.get_size()
		var scale_factor := float(sz) / tex_size.y
		var img_width := tex_size.x * scale_factor
		var portrait := TextureRect.new()
		portrait.texture = tex
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.size = Vector2(img_width, sz)
		portrait.position = Vector2((sz - img_width) / 2.0, 0)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return portrait

	# Fallback: coloured initial
	var container := Control.new()
	container.custom_minimum_size = Vector2(sz, sz)
	container.size = Vector2(sz, sz)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var flight_col: Color = DartData.get_flight_colors(GameState.character)["front"]
	var bg := ColorRect.new()
	bg.color = flight_col.darkened(0.6)
	bg.position = Vector2.ZERO
	bg.size = Vector2(sz, sz)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)
	var initial := Label.new()
	initial.text = DartData.get_character_name(GameState.character).substr(0, 1)
	UIFont.apply(initial, 38)
	initial.add_theme_color_override("font_color", flight_col)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.position = Vector2.ZERO
	initial.size = Vector2(sz, sz)
	initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(initial)
	return container

func _build_opponent_placeholder(opponent_id: String) -> Control:
	var sz := CARD_PORTRAIT_SIZE
	var img_path := OpponentData.get_image(opponent_id)

	# Try loading image directly
	if img_path != "":
		var tex: Texture2D = load(img_path)
		if not tex:
			push_warning("Opponent portrait failed to load: " + img_path + " — try deleting .godot folder")
		if tex:
			# Height-anchored portrait — fix height at 90px, width from aspect ratio
			var tex_size := tex.get_size()
			var scale_factor := float(sz) / tex_size.y
			var img_width := tex_size.x * scale_factor
			var portrait := TextureRect.new()
			portrait.texture = tex
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.size = Vector2(img_width, sz)
			portrait.position = Vector2((sz - img_width) / 2.0, 0)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return portrait

	# Fallback: dark panel with initial letter
	var container := Control.new()
	container.custom_minimum_size = Vector2(sz, sz)
	container.size = Vector2(sz, sz)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.15, 0.18)
	bg.position = Vector2.ZERO
	bg.size = Vector2(sz, sz)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)
	_opp_initial_label = Label.new()
	_opp_initial_label.text = OpponentData.get_display_name(opponent_id).substr(0, 1)
	UIFont.apply(_opp_initial_label, 38)
	_opp_initial_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 0.8))
	_opp_initial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_opp_initial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_opp_initial_label.position = Vector2.ZERO
	_opp_initial_label.size = Vector2(sz, sz)
	_opp_initial_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_opp_initial_label)
	return container

func _set_card_layout(is_player_turn: bool) -> void:
	# Portraits stay fixed: player always left, opponent always right.
	# Active thrower is bright, inactive is heavily faded.
	for child in _name_left.get_children():
		_name_left.remove_child(child)
	for child in _name_right.get_children():
		_name_right.remove_child(child)

	var full_text_w := _portrait_right.position.x - _name_left.position.x - 10

	# Fade portraits — active thrower fully visible, other heavily dimmed
	if _portrait_tween and _portrait_tween.is_valid():
		_portrait_tween.kill()
	_portrait_tween = create_tween()
	_portrait_tween.set_parallel(true)
	if is_player_turn:
		_portrait_tween.tween_property(_portrait_left, "modulate:a", 1.0, 0.25)
		_portrait_tween.tween_property(_portrait_right, "modulate:a", 0.15, 0.25)
	else:
		_portrait_tween.tween_property(_portrait_left, "modulate:a", 0.15, 0.25)
		_portrait_tween.tween_property(_portrait_right, "modulate:a", 1.0, 0.25)

	if is_player_turn:
		# Player name + nickname — left-aligned, next to player portrait
		_name_left.add_child(_player_name_label)
		_player_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_player_name_label.position = Vector2(0, 5)
		_player_name_label.size = Vector2(full_text_w, 35)
		UIFont.apply(_player_name_label, 30)
		_player_name_label.add_theme_color_override("font_color", Color.WHITE)

		_name_left.add_child(_player_nick_label)
		_player_nick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_player_nick_label.position = Vector2(0, 42)
		_player_nick_label.size = Vector2(full_text_w, 40)
		UIFont.apply(_player_nick_label, 48)
		var flight_col: Color = DartData.get_flight_colors(GameState.character)["front"]
		_player_nick_label.add_theme_color_override("font_color", flight_col)

		# Green border
		_card_accent.border_color = Color(0.2, 0.6, 0.25)
	else:
		# Opponent name + nickname — right-aligned, next to opponent portrait
		_name_left.add_child(_opp_name_label)
		_opp_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_opp_name_label.position = Vector2(0, 5)
		_opp_name_label.size = Vector2(full_text_w, 35)
		UIFont.apply(_opp_name_label, 30)
		_opp_name_label.add_theme_color_override("font_color", Color.WHITE)

		_name_left.add_child(_opp_nick_label)
		_opp_nick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_opp_nick_label.position = Vector2(0, 42)
		_opp_nick_label.size = Vector2(full_text_w, 40)
		UIFont.apply(_opp_nick_label, 48)
		_opp_nick_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))

		# Red border
		_card_accent.border_color = Color(0.6, 0.2, 0.2)

# ── Stats bars (inside the bottom card, career mode only) ──

func _build_stats_bars_in_card(parent: Control, y_start: int) -> void:
	_stats_container = Control.new()
	_stats_container.position = Vector2(0, y_start)
	_stats_container.size = Vector2(CARD_W, STATS_ROW_STEP * 4)
	_stats_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_stats_container)

	var card_label_w := 160  # Wide enough for CONFIDENCE
	var total_w := card_label_w + STATS_GAP + STATS_BAR_WIDTH
	# Shift slightly left of centre so dart dots fit to the right
	var start_x := (CARD_W - total_w) / 2.0 - 30
	var bar_x := start_x + card_label_w + STATS_GAP

	_bar_bgs.clear()
	_bar_fills.clear()
	_bar_labels.clear()
	_bar_tweens.clear()
	_bar_tweens.resize(4)

	for i in range(4):
		var row_y := i * STATS_ROW_STEP
		var bar_y := row_y + (STATS_ROW_STEP - STATS_BAR_HEIGHT) / 2.0

		var lbl := Label.new()
		lbl.text = BAR_NAMES[i]
		UIFont.apply(lbl, 24)  # Fixed size — don't scale with menu text
		lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		lbl.position = Vector2(start_x, row_y)
		lbl.size = Vector2(card_label_w, STATS_ROW_STEP)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stats_container.add_child(lbl)
		_bar_labels.append(lbl)

		var bg := ColorRect.new()
		bg.color = Color(0.12, 0.12, 0.15)
		bg.position = Vector2(bar_x, bar_y)
		bg.size = Vector2(STATS_BAR_WIDTH, STATS_BAR_HEIGHT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stats_container.add_child(bg)
		_bar_bgs.append(bg)

		var fill := ColorRect.new()
		fill.color = Color(0.5, 0.5, 0.5)
		fill.position = Vector2(bar_x, bar_y)
		fill.size = Vector2(0, STATS_BAR_HEIGHT)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stats_container.add_child(fill)
		_bar_fills.append(fill)

	# ── Mini darts — 3 side by side to the right of the bars ──
	var darts_x := bar_x + STATS_BAR_WIDTH + 16
	var dart_w := 24
	var dart_gap := 4
	var dart_h := 80
	# Centre vertically in the stats area
	var darts_y := (STATS_ROW_STEP * 4 - dart_h) / 2.0
	_dart_dots.clear()
	var flight_cols := DartData.get_flight_colors(GameState.character)
	var barrel_col: Color = DartData.get_tier(GameState.dart_tier)["barrel_color"]
	for i in range(3):
		var mini := _build_mini_dart(flight_cols["front"], barrel_col)
		mini.position = Vector2(darts_x + i * (dart_w + dart_gap), darts_y)
		_stats_container.add_child(mini)
		_dart_dots.append(mini)

## Kept for API compatibility — owner label removed to reduce clutter
func set_stats_owner(_owner_name: String) -> void:
	pass

## Update all 4 stats bars with smooth tween animation.
## All values 0-100.
func update_stats_bars(dart_quality: float, nerves: float, confidence: float, anger: float) -> void:
	if not _stats_container:
		return

	var values := [dart_quality, nerves, confidence, anger]

	for i in range(4):
		var frac := clampf(values[i] / 100.0, 0.0, 1.0)
		var width := STATS_BAR_WIDTH * frac
		var col := _get_bar_color(i, frac)

		# Kill existing tween on this bar before starting a new one
		if i < _bar_tweens.size() and _bar_tweens[i] is Tween and _bar_tweens[i].is_valid():
			_bar_tweens[i].kill()

		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_bar_fills[i], "size", Vector2(width, STATS_BAR_HEIGHT), 0.3)
		tw.tween_property(_bar_fills[i], "color", col, 0.3)
		if i < _bar_tweens.size():
			_bar_tweens[i] = tw

## Animate a single bar from one value to another over a longer duration.
## Used for the visible nerves decrease when returning from a drink.
func animate_single_bar(bar_index: int, from_value: float, to_value: float, duration: float) -> void:
	if not _stats_container or bar_index < 0 or bar_index >= _bar_fills.size():
		return
	# Kill any existing tween on this bar
	if bar_index < _bar_tweens.size() and _bar_tweens[bar_index] is Tween and _bar_tweens[bar_index].is_valid():
		_bar_tweens[bar_index].kill()
	# Set starting position immediately
	var from_frac := clampf(from_value / 100.0, 0.0, 1.0)
	_bar_fills[bar_index].size = Vector2(STATS_BAR_WIDTH * from_frac, STATS_BAR_HEIGHT)
	_bar_fills[bar_index].color = _get_bar_color(bar_index, from_frac)
	# Animate to target
	var to_frac := clampf(to_value / 100.0, 0.0, 1.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(_bar_fills[bar_index], "size", Vector2(STATS_BAR_WIDTH * to_frac, STATS_BAR_HEIGHT), duration)
	tw.tween_property(_bar_fills[bar_index], "color", _get_bar_color(bar_index, to_frac), duration)
	if bar_index < _bar_tweens.size():
		_bar_tweens[bar_index] = tw

## Get the colour for a bar based on its index and fill fraction.
func _get_bar_color(bar_index: int, frac: float) -> Color:
	match bar_index:
		0:
			# Darts: grey (0) -> silver (50) -> gold (100)
			if frac < 0.5:
				return Color(0.4, 0.4, 0.4).lerp(Color(0.75, 0.75, 0.78), frac * 2.0)
			else:
				return Color(0.75, 0.75, 0.78).lerp(Color(1.0, 0.85, 0.0), (frac - 0.5) * 2.0)
		1:
			# Nerves: green (0) -> amber (50) -> red (100)
			if frac < 0.5:
				return Color(0.2, 0.8, 0.2).lerp(Color(1.0, 0.7, 0.1), frac * 2.0)
			else:
				return Color(1.0, 0.7, 0.1).lerp(Color(0.9, 0.15, 0.15), (frac - 0.5) * 2.0)
		2:
			# Confidence: red (0) -> amber (50) -> gold (100)
			if frac < 0.5:
				return Color(0.8, 0.2, 0.2).lerp(Color(1.0, 0.7, 0.1), frac * 2.0)
			else:
				return Color(1.0, 0.7, 0.1).lerp(Color(1.0, 0.85, 0.0), (frac - 0.5) * 2.0)
		3:
			# Anger: green (0) -> amber (50) -> red (100)
			if frac < 0.5:
				return Color(0.2, 0.8, 0.2).lerp(Color(1.0, 0.7, 0.1), frac * 2.0)
			else:
				return Color(1.0, 0.7, 0.1).lerp(Color(0.9, 0.15, 0.15), (frac - 0.5) * 2.0)
		_:
			return Color(0.5, 0.5, 0.5)

# ── Public methods called by match_manager ──

func update_remaining(value: int) -> void:
	_remaining_label.text = str(value)
	if _is_vs_mode:
		_remaining_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.9))

func update_remaining_text(text: String) -> void:
	_remaining_label.text = text

func update_opponent_score(value: int) -> void:
	if _opponent_label:
		var parts := _opponent_label.text.split("\n")
		var name_part: String = parts[0]
		_opponent_label.text = name_part + "\n" + str(value)

func update_opponent_remaining_text(text: String) -> void:
	if _opponent_label:
		var parts := _opponent_label.text.split("\n")
		var name_part: String = parts[0]
		_opponent_label.text = name_part + "\n" + text

func update_turn_indicator(is_player_turn: bool) -> void:
	if not _turn_indicator:
		return
	if is_player_turn:
		_turn_indicator.text = "YOUR THROW"
		_turn_indicator.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3, 0.7))
		# Brighten player score, dim opponent
		_remaining_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.9))
		if _opponent_label:
			_opponent_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.35))
	else:
		_turn_indicator.text = OpponentData.get_display_name(_vs_opponent_id)
		_turn_indicator.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 0.7))
		# Dim player score, brighten opponent
		_remaining_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.35))
		if _opponent_label:
			_opponent_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.9))
	# Hide zoom hint during opponent's turn
	if _zoom_hint and _zoom_hint.visible:
		if not is_player_turn:
			_zoom_hint.visible = false
	# Flip card layout sides
	if _portrait_left:
		_set_card_layout(is_player_turn)

func on_dart_thrown(dart_index: int) -> void:
	# Fade out the dart dot for the thrown dart (0, 1, or 2)
	if dart_index >= 0 and dart_index < _dart_dots.size():
		var tween := create_tween()
		tween.tween_property(_dart_dots[dart_index], "modulate", Color(1, 1, 1, 0.15), 0.2)

func show_impact(label_text: String, screen_pos: Vector2) -> void:
	# Brief score flash near where the dart hit
	if label_text == "MISS" or label_text == "BOUNCE OUT":
		_impact_label.add_theme_color_override("font_color", Color(0.6, 0.3, 0.3))
	else:
		_impact_label.add_theme_color_override("font_color", Color.WHITE)
	_impact_label.text = label_text
	_impact_label.position = Vector2(screen_pos.x - 100, screen_pos.y - 60)
	_impact_label.modulate = Color(1, 1, 1, 1)
	_impact_label.visible = true

	var tween := create_tween()
	tween.tween_property(_impact_label, "modulate", Color(1, 1, 1, 0), IMPACT_FADE_TIME)
	tween.tween_callback(func() -> void: _impact_label.visible = false)

func show_visit_summary(dart_labels: Array, visit_total: int, remaining: int) -> void:
	_summary_title.text = "VISIT"
	_summary_darts_label.visible = true
	_set_darts_text(dart_labels)
	_rtc_hits_rich.visible = false
	_summary_total_label.visible = true
	_set_visit_total(visit_total)
	_summary_remaining_label.text = str(remaining) + " remaining"
	_summary_panel.visible = true

func show_visit_summary_named(name: String, dart_labels: Array, visit_total: int, remaining: int) -> void:
	_summary_title.text = name + " - VISIT"
	_summary_darts_label.visible = true
	_set_darts_text(dart_labels)
	_rtc_hits_rich.visible = false
	_summary_total_label.visible = true
	_set_visit_total(visit_total)
	_summary_remaining_label.text = str(remaining) + " remaining"
	_summary_panel.visible = true

func show_bust_summary(dart_labels: Array, reverted_score: int) -> void:
	_summary_title.text = "BUST!"
	_summary_darts_label.visible = true
	_set_darts_text(dart_labels)
	_rtc_hits_rich.visible = false
	_summary_total_label.visible = true
	_summary_total_label.text = "BUST"
	_summary_total_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	_summary_remaining_label.text = "Back to " + str(reverted_score)
	_summary_panel.visible = true

func show_bust_summary_named(name: String, dart_labels: Array, reverted_score: int) -> void:
	_summary_title.text = name + " - BUST!"
	_summary_darts_label.visible = true
	_set_darts_text(dart_labels)
	_rtc_hits_rich.visible = false
	_summary_total_label.visible = true
	_summary_total_label.text = "BUST"
	_summary_total_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	_summary_remaining_label.text = "Back to " + str(reverted_score)
	_summary_panel.visible = true

func show_message(text: String, duration: float = 1.5) -> void:
	# Kill any existing message to prevent stacking (only one message at a time)
	if _message_tween and _message_tween.is_valid():
		_message_tween.kill()

	_rtc_hits_rich.visible = false
	_summary_total_label.visible = true
	_summary_title.text = ""
	_summary_darts_label.text = ""
	_summary_total_label.text = text
	_summary_total_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	_summary_remaining_label.text = ""
	_summary_panel.visible = true
	_message_tween = create_tween()
	_message_tween.tween_interval(duration)
	_message_tween.tween_callback(func() -> void: _summary_panel.visible = false)

func show_rtc_summary(dart_labels: Array, hits: Array, next_target: String) -> void:
	_summary_title.text = "VISIT"
	_summary_darts_label.visible = false
	_summary_total_label.visible = false
	_rtc_hits_rich.visible = true
	_set_rtc_hits(hits)
	_summary_remaining_label.text = next_target
	_summary_panel.visible = true

func show_rtc_summary_named(name: String, dart_labels: Array, hits: Array, next_target: String) -> void:
	_summary_title.text = name + " - VISIT"
	_summary_darts_label.visible = false
	_summary_total_label.visible = false
	_rtc_hits_rich.visible = true
	_set_rtc_hits(hits)
	_summary_remaining_label.text = next_target
	_summary_panel.visible = true

func hide_summary() -> void:
	_summary_panel.visible = false

func reset_dart_icons() -> void:
	for dot in _dart_dots:
		dot.modulate = Color(1, 1, 1, 1)

# ── Private helpers ──

func _set_darts_text(dart_labels: Array) -> void:
	var darts_text := ""
	for i in range(dart_labels.size()):
		if i > 0:
			darts_text += ",  "
		darts_text += str(dart_labels[i])
	_summary_darts_label.text = darts_text

func _set_visit_total(visit_total: int) -> void:
	if visit_total > 0:
		_summary_total_label.text = str(visit_total)
		if visit_total >= 100:
			_summary_total_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
		elif visit_total >= 60:
			_summary_total_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		else:
			_summary_total_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	else:
		_summary_total_label.text = "0"
		_summary_total_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

func _set_rtc_hits(hits: Array) -> void:
	_summary_darts_label.text = ""
	_summary_darts_label.visible = false
	_rtc_hits_rich.clear()
	_rtc_hits_rich.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	var first := true
	for hit in hits:
		var text: String = hit.get("text", "") if hit is Dictionary else str(hit)
		if text == "":
			continue  # skip complete misses (no number hit)
		if not first:
			_rtc_hits_rich.push_color(Color.WHITE)
			_rtc_hits_rich.add_text(",  ")
			_rtc_hits_rich.pop()
		var scoring: bool = hit.get("scoring", false) if hit is Dictionary else true
		if scoring:
			_rtc_hits_rich.push_color(Color(0.3, 1.0, 0.3))  # green for scoring
		else:
			_rtc_hits_rich.push_color(Color.WHITE)  # white for non-scoring
		_rtc_hits_rich.add_text(text)
		_rtc_hits_rich.pop()
		first = false
	_rtc_hits_rich.pop()  # end paragraph
	_rtc_hits_rich.visible = true
