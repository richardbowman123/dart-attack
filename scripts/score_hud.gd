extends CanvasLayer
class_name ScoreHUD

# ── Layout constants ──
const DART_ICON_Y := 1225        # Near the bottom of the screen
const DART_ICON_SPACING := 60    # Gap between dart icons
const DART_BARREL_W := 4
const DART_BARREL_H := 40
const DART_FLIGHT_W := 16
const DART_FLIGHT_H := 10
const DART_TIP_H := 8

const REMAINING_MARGIN := 20
const IMPACT_FADE_TIME := 1.2
const SUMMARY_DISPLAY_TIME := 2.5

# ── Node references ──
var _remaining_label: Label
var _dart_icons: Array[Control] = []
var _impact_label: Label
var _summary_panel: PanelContainer
var _summary_content: VBoxContainer
var _summary_title: Label
var _summary_darts_label: Label
var _summary_total_label: Label
var _summary_remaining_label: Label

# ── VS mode elements ──
var _is_vs_mode := false
var _vs_opponent_id := ""
var _opponent_label: Label
var _turn_indicator: Label

# ── Identity display (bottom of screen, VS mode only) ──
const IDENTITY_Y := 1115
const IDENTITY_PORTRAIT_SIZE := 80
const IDENTITY_MARGIN := 16
var _identity_left: Control    # Container on the left side
var _identity_right: Control   # Container on the right side
var _player_portrait: Control
var _player_name_label: Label
var _player_nick_label: Label
var _opp_portrait_panel: Control  # Clipping container for opponent portrait
var _opp_initial_label: Label
var _opp_name_label: Label
var _opp_nick_label: Label

var _zoom_hint: Label

# ── Throw tip popup ──
var _throw_tip_overlay: Control

# ── Balance display (career mode only) ──
const BALANCE_BOX_W := 160
const BALANCE_BOX_H := 24
const BALANCE_Y := 2
var _balance_panel: PanelContainer
var _balance_label: Label

# ── Stats bars (career mode only) ──
const STATS_BAR_WIDTH := 140
const STATS_BAR_HEIGHT := 12
const STATS_LABEL_W := 200
const STATS_GAP := 8
const STATS_FIRST_ROW_Y := 970
const STATS_ROW_STEP := 24
const BAR_NAMES: Array[String] = ["DARTS", "NERVES", "CONFIDENCE", "ANGER"]

var _bar_bgs: Array[ColorRect] = []
var _bar_fills: Array[ColorRect] = []
var _bar_labels: Array[Label] = []
var _stats_container: Control

func _ready() -> void:
	_build_remaining_display()
	_build_dart_icons()
	_build_impact_flash()
	_build_summary_panel()
	_build_zoom_hint()
	_build_balance_display()
	_build_throw_tip()

# ── Remaining score (small, top-right corner) ──

func _build_remaining_display() -> void:
	_remaining_label = Label.new()
	_remaining_label.text = "501"
	UIFont.apply(_remaining_label, UIFont.SUBHEADING)
	_remaining_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.7))
	_remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_remaining_label.position = Vector2(720 - 360 - REMAINING_MARGIN, REMAINING_MARGIN)
	_remaining_label.size = Vector2(360, 45)
	_remaining_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_remaining_label)

# ── Three dart icons at the bottom ──

func _build_dart_icons() -> void:
	var centre_x := 360.0  # Middle of 720px screen
	var start_x := centre_x - DART_ICON_SPACING

	for i in range(3):
		var icon := _create_dart_icon()
		icon.position = Vector2(start_x + i * DART_ICON_SPACING, DART_ICON_Y)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		_dart_icons.append(icon)

func _create_dart_icon() -> Control:
	var container := Control.new()
	container.size = Vector2(DART_FLIGHT_W, DART_BARREL_H + DART_FLIGHT_H + DART_TIP_H)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Pull colours from the selected dart tier and character
	var tier_data := DartData.get_tier(GameState.dart_tier)
	var flight_cols := DartData.get_flight_colors(GameState.character)
	var barrel_col: Color = tier_data["barrel_color"]
	var flight_col: Color = flight_cols["front"]

	# Flight — shield shape with 45-deg leading edges
	# Narrow stem at bottom widens at 45 deg to full width, flat top
	var cx := DART_FLIGHT_W / 2.0
	var half_barrel := DART_BARREL_W / 2.0
	var spread := (DART_FLIGHT_W / 2.0) - half_barrel  # Pixels to widen on each side
	var angle_h := spread  # At 45 deg, height = spread (tan45=1)

	var flight := Polygon2D.new()
	flight.polygon = PackedVector2Array([
		Vector2(cx - half_barrel, DART_FLIGHT_H),    # Bottom left (stem)
		Vector2(0, DART_FLIGHT_H - angle_h),          # Full width reached, left
		Vector2(0, 0),                                 # Top left
		Vector2(DART_FLIGHT_W, 0),                     # Top right
		Vector2(DART_FLIGHT_W, DART_FLIGHT_H - angle_h), # Full width reached, right
		Vector2(cx + half_barrel, DART_FLIGHT_H),     # Bottom right (stem)
	])
	flight.color = Color(flight_col.r, flight_col.g, flight_col.b, 0.9)
	flight.position = Vector2(0, 0)
	container.add_child(flight)

	# Barrel (thin middle)
	var barrel := ColorRect.new()
	barrel.color = Color(barrel_col.r, barrel_col.g, barrel_col.b, 0.9)
	barrel.size = Vector2(DART_BARREL_W, DART_BARREL_H)
	barrel.position = Vector2((DART_FLIGHT_W - DART_BARREL_W) / 2.0, DART_FLIGHT_H)
	barrel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(barrel)

	# Tip (tiny point at bottom)
	var tip := ColorRect.new()
	tip.color = Color(0.8, 0.8, 0.85, 0.9)
	tip.size = Vector2(2, DART_TIP_H)
	tip.position = Vector2((DART_FLIGHT_W - 2) / 2.0, DART_FLIGHT_H + DART_BARREL_H)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(tip)

	return container

# ── Zoom hint ──

func _build_zoom_hint() -> void:
	_zoom_hint = Label.new()
	_zoom_hint.text = "Pinch to zoom in for accuracy"
	UIFont.apply(_zoom_hint, UIFont.CAPTION)
	_zoom_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 0.6))
	_zoom_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_hint.position = Vector2(0, 935)
	_zoom_hint.size = Vector2(720, 28)
	_zoom_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_zoom_hint)

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
	UIFont.apply(_balance_label, UIFont.CAPTION)
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
	UIFont.apply(msg, UIFont.CAPTION)
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
	add_child(_throw_tip_overlay)

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

# ── Impact flash (brief score text that fades) ──

func _build_impact_flash() -> void:
	_impact_label = Label.new()
	_impact_label.text = ""
	UIFont.apply(_impact_label, UIFont.HEADING)
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
	_summary_panel.position = Vector2(110, 450)
	_summary_panel.size = Vector2(500, 180)
	_summary_panel.visible = false
	_summary_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_summary_content = VBoxContainer.new()
	_summary_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_content.add_theme_constant_override("separation", 6)

	_summary_title = Label.new()
	UIFont.apply(_summary_title, UIFont.CAPTION)
	_summary_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_summary_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_content.add_child(_summary_title)

	_summary_darts_label = Label.new()
	UIFont.apply(_summary_darts_label, UIFont.SUBHEADING)
	_summary_darts_label.add_theme_color_override("font_color", Color.WHITE)
	_summary_darts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_darts_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_content.add_child(_summary_darts_label)

	_summary_total_label = Label.new()
	UIFont.apply(_summary_total_label, UIFont.HEADING)
	_summary_total_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_summary_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_total_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_content.add_child(_summary_total_label)

	_summary_remaining_label = Label.new()
	UIFont.apply(_summary_remaining_label, UIFont.BODY)
	_summary_remaining_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_summary_remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_remaining_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_content.add_child(_summary_remaining_label)

	_summary_panel.add_child(_summary_content)
	add_child(_summary_panel)

# ── VS mode setup (called by match_manager when is_vs_ai) ──

func setup_vs_mode(opponent_id: String) -> void:
	_is_vs_mode = true
	_vs_opponent_id = opponent_id

	# Opponent name + score at top-left
	_opponent_label = Label.new()
	var opp_name := OpponentData.get_display_name(opponent_id)
	_opponent_label.text = opp_name
	UIFont.apply(_opponent_label, UIFont.BODY)
	_opponent_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.5))
	_opponent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_opponent_label.position = Vector2(REMAINING_MARGIN, REMAINING_MARGIN)
	_opponent_label.size = Vector2(300, 55)
	_opponent_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_opponent_label)

	# Turn indicator — large, over the top of the board
	_turn_indicator = Label.new()
	_turn_indicator.text = "YOUR THROW"
	UIFont.apply(_turn_indicator, UIFont.HEADING)
	_turn_indicator.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3, 0.7))
	_turn_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_indicator.position = Vector2(60, 155)
	_turn_indicator.size = Vector2(600, 50)
	_turn_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_turn_indicator)

	# Build identity display at bottom of screen
	_build_identity_display(opponent_id)

	# Build stats bars if career mode
	if CareerState.career_mode_active:
		_build_stats_bars()

# ── Identity display (portraits + names at bottom of screen) ──

func _build_identity_display(opponent_id: String) -> void:
	# Left container — positioned at bottom-left
	_identity_left = Control.new()
	_identity_left.position = Vector2(IDENTITY_MARGIN, IDENTITY_Y)
	_identity_left.size = Vector2(200, 100)
	_identity_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_identity_left)

	# Right container — positioned at bottom-right
	_identity_right = Control.new()
	_identity_right.position = Vector2(720 - 200 - IDENTITY_MARGIN, IDENTITY_Y)
	_identity_right.size = Vector2(200, 100)
	_identity_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_identity_right)

	# Build player portrait
	_player_portrait = _build_player_portrait()

	# Build player name/nickname labels
	_player_name_label = Label.new()
	_player_name_label.text = DartData.get_character_name(GameState.character)
	UIFont.apply(_player_name_label, UIFont.CAPTION)
	_player_name_label.add_theme_color_override("font_color", Color.WHITE)
	_player_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_player_nick_label = Label.new()
	_player_nick_label.text = DartData.get_character_nickname(GameState.character)
	UIFont.apply(_player_nick_label, 18)
	# Use the character's flight front colour for the nickname
	var flight_col: Color = DartData.get_flight_colors(GameState.character)["front"]
	_player_nick_label.add_theme_color_override("font_color", flight_col)
	_player_nick_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Build opponent portrait placeholder
	_opp_portrait_panel = _build_opponent_placeholder(opponent_id)

	# Build opponent name/nickname labels
	_opp_name_label = Label.new()
	_opp_name_label.text = OpponentData.get_display_name(opponent_id)
	UIFont.apply(_opp_name_label, UIFont.CAPTION)
	_opp_name_label.add_theme_color_override("font_color", Color.WHITE)
	_opp_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_opp_nick_label = Label.new()
	_opp_nick_label.text = OpponentData.get_nickname(opponent_id)
	UIFont.apply(_opp_nick_label, 18)
	_opp_nick_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	_opp_nick_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Default layout: player turn (portrait left, stats right)
	_set_identity_layout(true)

func _build_player_portrait() -> Control:
	# Wrap in a clipping container to enforce fixed size
	var clip := Control.new()
	clip.clip_contents = true
	clip.custom_minimum_size = Vector2(IDENTITY_PORTRAIT_SIZE, IDENTITY_PORTRAIT_SIZE)
	clip.size = Vector2(IDENTITY_PORTRAIT_SIZE, IDENTITY_PORTRAIT_SIZE)
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Dark background so empty/loading state isn't white
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.13)
	bg.size = Vector2(IDENTITY_PORTRAIT_SIZE, IDENTITY_PORTRAIT_SIZE)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(bg)

	var image_path := DartData.get_profile_image(GameState.character)
	var tex: Texture2D = null
	if ResourceLoader.exists(image_path):
		tex = load(image_path)

	if tex:
		var portrait := TextureRect.new()
		portrait.texture = tex
		portrait.custom_minimum_size = Vector2(IDENTITY_PORTRAIT_SIZE, IDENTITY_PORTRAIT_SIZE)
		portrait.size = Vector2(IDENTITY_PORTRAIT_SIZE, IDENTITY_PORTRAIT_SIZE)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(portrait)
	else:
		# Fallback: coloured panel with initial letter
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		var flight_col: Color = DartData.get_flight_colors(GameState.character)["front"]
		style.bg_color = flight_col.darkened(0.6)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		panel.add_theme_stylebox_override("panel", style)
		panel.custom_minimum_size = Vector2(IDENTITY_PORTRAIT_SIZE, IDENTITY_PORTRAIT_SIZE)
		panel.size = Vector2(IDENTITY_PORTRAIT_SIZE, IDENTITY_PORTRAIT_SIZE)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var initial := Label.new()
		var char_name := DartData.get_character_name(GameState.character)
		initial.text = char_name.substr(0, 1)
		UIFont.apply(initial, UIFont.HEADING)
		initial.add_theme_color_override("font_color", flight_col)
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(initial)
		clip.add_child(panel)
	return clip

func _build_opponent_placeholder(opponent_id: String) -> Control:
	# Wrap in a clipping container to enforce fixed size
	var clip := Control.new()
	clip.clip_contents = true
	clip.custom_minimum_size = Vector2(IDENTITY_PORTRAIT_SIZE, IDENTITY_PORTRAIT_SIZE)
	clip.size = Vector2(IDENTITY_PORTRAIT_SIZE, IDENTITY_PORTRAIT_SIZE)
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Check if opponent has a real image
	var img_path := OpponentData.get_image(opponent_id)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(IDENTITY_PORTRAIT_SIZE, IDENTITY_PORTRAIT_SIZE)
	panel.size = Vector2(IDENTITY_PORTRAIT_SIZE, IDENTITY_PORTRAIT_SIZE)

	if img_path != "" and ResourceLoader.exists(img_path):
		# Real image — load as TextureRect inside the panel
		var portrait := TextureRect.new()
		var tex: Texture2D = load(img_path)
		portrait.texture = tex
		portrait.custom_minimum_size = Vector2(IDENTITY_PORTRAIT_SIZE, IDENTITY_PORTRAIT_SIZE)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		panel.add_child(portrait)
	else:
		# No image — dark panel with initial letter and nickname
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 0)

		_opp_initial_label = Label.new()
		var opp_name := OpponentData.get_display_name(opponent_id)
		_opp_initial_label.text = opp_name.substr(0, 1)
		UIFont.apply(_opp_initial_label, UIFont.HEADING)
		_opp_initial_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 0.8))
		_opp_initial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(_opp_initial_label)

		var nick := Label.new()
		nick.text = OpponentData.get_nickname(opponent_id)
		UIFont.apply(nick, UIFont.CAPTION)
		nick.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		nick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(nick)

		panel.add_child(vbox)

	clip.add_child(panel)
	return clip

func _set_identity_layout(is_player_turn: bool) -> void:
	# Remove all children from both containers
	for child in _identity_left.get_children():
		_identity_left.remove_child(child)
	for child in _identity_right.get_children():
		_identity_right.remove_child(child)

	if is_player_turn:
		# Player portrait on the left
		_identity_left.add_child(_player_portrait)
		_player_portrait.position = Vector2(0, 0)

		# Player name/nickname on the right, right-aligned
		_identity_right.add_child(_player_name_label)
		_player_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_player_name_label.position = Vector2(0, 10)
		_player_name_label.size = Vector2(200, 30)
		_identity_right.add_child(_player_nick_label)
		_player_nick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_player_nick_label.position = Vector2(0, 40)
		_player_nick_label.size = Vector2(200, 20)
	else:
		# Opponent portrait on the right
		_identity_right.add_child(_opp_portrait_panel)
		_opp_portrait_panel.position = Vector2(200 - IDENTITY_PORTRAIT_SIZE, 0)

		# Opponent name/nickname on the left, left-aligned
		_identity_left.add_child(_opp_name_label)
		_opp_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_opp_name_label.position = Vector2(0, 10)
		_opp_name_label.size = Vector2(200, 30)
		_identity_left.add_child(_opp_nick_label)
		_opp_nick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_opp_nick_label.position = Vector2(0, 40)
		_opp_nick_label.size = Vector2(200, 20)

# ── Stats bars (inline layout, career mode only) ──

func _build_stats_bars() -> void:
	_stats_container = Control.new()
	_stats_container.position = Vector2(0, 0)
	_stats_container.size = Vector2(720, 1280)
	_stats_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stats_container)

	# Total row width: label + gap + bar
	var total_w := STATS_LABEL_W + STATS_GAP + STATS_BAR_WIDTH
	var start_x := (720 - total_w) / 2.0
	var bar_x := start_x + STATS_LABEL_W + STATS_GAP

	# Build 4 bars: DARTS, NERVES, CONFIDENCE, ANGER
	_bar_bgs.clear()
	_bar_fills.clear()
	_bar_labels.clear()

	for i in range(4):
		var row_y := STATS_FIRST_ROW_Y + i * STATS_ROW_STEP
		var bar_y := row_y + (STATS_ROW_STEP - STATS_BAR_HEIGHT) / 2.0  # Centre bar vertically

		# Label — left of the bar, right-aligned
		var lbl := Label.new()
		lbl.text = BAR_NAMES[i]
		UIFont.apply(lbl, UIFont.CAPTION)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		lbl.position = Vector2(start_x, row_y)
		lbl.size = Vector2(STATS_LABEL_W, STATS_ROW_STEP)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stats_container.add_child(lbl)
		_bar_labels.append(lbl)

		# Background
		var bg := ColorRect.new()
		bg.color = Color(0.15, 0.15, 0.18)
		bg.position = Vector2(bar_x, bar_y)
		bg.size = Vector2(STATS_BAR_WIDTH, STATS_BAR_HEIGHT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stats_container.add_child(bg)
		_bar_bgs.append(bg)

		# Fill
		var fill := ColorRect.new()
		fill.color = Color(0.5, 0.5, 0.5)
		fill.position = Vector2(bar_x, bar_y)
		fill.size = Vector2(0, STATS_BAR_HEIGHT)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stats_container.add_child(fill)
		_bar_fills.append(fill)

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

		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_bar_fills[i], "size", Vector2(width, STATS_BAR_HEIGHT), 0.3)
		tw.tween_property(_bar_fills[i], "color", col, 0.3)

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
	if _zoom_hint:
		_zoom_hint.visible = is_player_turn
	# Flip identity display sides
	if _identity_left:
		_set_identity_layout(is_player_turn)

func on_dart_thrown(dart_index: int) -> void:
	# Hide the dart icon for the thrown dart (0, 1, or 2)
	if dart_index >= 0 and dart_index < _dart_icons.size():
		var tween := create_tween()
		tween.tween_property(_dart_icons[dart_index], "modulate", Color(1, 1, 1, 0), 0.2)

func show_impact(label_text: String, screen_pos: Vector2) -> void:
	# Brief score flash near where the dart hit
	if label_text == "BOUNCE OUT":
		_impact_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))
	elif label_text == "Miss":
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
	_set_darts_text(dart_labels)
	_set_visit_total(visit_total)
	_summary_remaining_label.text = str(remaining) + " remaining"
	_summary_panel.visible = true

func show_visit_summary_named(name: String, dart_labels: Array, visit_total: int, remaining: int) -> void:
	_summary_title.text = name + " - VISIT"
	_set_darts_text(dart_labels)
	_set_visit_total(visit_total)
	_summary_remaining_label.text = str(remaining) + " remaining"
	_summary_panel.visible = true

func show_bust_summary(dart_labels: Array, reverted_score: int) -> void:
	_summary_title.text = "BUST!"
	_set_darts_text(dart_labels)
	_summary_total_label.text = "BUST"
	_summary_total_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	_summary_remaining_label.text = "Back to " + str(reverted_score)
	_summary_panel.visible = true

func show_bust_summary_named(name: String, dart_labels: Array, reverted_score: int) -> void:
	_summary_title.text = name + " - BUST!"
	_set_darts_text(dart_labels)
	_summary_total_label.text = "BUST"
	_summary_total_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	_summary_remaining_label.text = "Back to " + str(reverted_score)
	_summary_panel.visible = true

func show_message(text: String, duration: float = 1.5) -> void:
	# For special callouts like "180!" or "CHECKOUT!"
	_summary_title.text = ""
	_summary_darts_label.text = ""
	_summary_total_label.text = text
	_summary_total_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	_summary_remaining_label.text = ""
	_summary_panel.visible = true
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(func() -> void: _summary_panel.visible = false)

func show_rtc_summary(dart_labels: Array, hits: Array, next_target: String) -> void:
	_summary_title.text = "VISIT"
	_set_darts_text(dart_labels)
	_set_rtc_hits(hits)
	_summary_remaining_label.text = next_target
	_summary_panel.visible = true

func show_rtc_summary_named(name: String, dart_labels: Array, hits: Array, next_target: String) -> void:
	_summary_title.text = name + " - VISIT"
	_set_darts_text(dart_labels)
	_set_rtc_hits(hits)
	_summary_remaining_label.text = next_target
	_summary_panel.visible = true

func hide_summary() -> void:
	_summary_panel.visible = false

func reset_dart_icons() -> void:
	for icon in _dart_icons:
		icon.modulate = Color(1, 1, 1, 1)

# ── Private helpers ──

func _set_darts_text(dart_labels: Array) -> void:
	var darts_text := ""
	for i in range(dart_labels.size()):
		if i > 0:
			darts_text += "   "
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
	var hits_text := ""
	for h in hits:
		if h != "-":
			if hits_text != "":
				hits_text += ", "
			hits_text += str(h)
	if hits_text == "":
		_summary_total_label.text = "No hits"
		_summary_total_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		_summary_total_label.text = hits_text
		_summary_total_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
