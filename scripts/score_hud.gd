extends CanvasLayer
class_name ScoreHUD

# ── Layout constants ──
const DART_ICON_Y := 1180        # Near the bottom of the screen
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
const IDENTITY_Y := 1140
const IDENTITY_PORTRAIT_SIZE := 90
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

func _ready() -> void:
	_build_remaining_display()
	_build_dart_icons()
	_build_impact_flash()
	_build_summary_panel()
	_build_zoom_hint()

# ── Remaining score (small, top-right corner) ──

func _build_remaining_display() -> void:
	_remaining_label = Label.new()
	_remaining_label.text = "501"
	_remaining_label.add_theme_font_size_override("font_size", 28)
	_remaining_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.7))
	_remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_remaining_label.position = Vector2(720 - 300 - REMAINING_MARGIN, REMAINING_MARGIN)
	_remaining_label.size = Vector2(300, 35)
	add_child(_remaining_label)

# ── Three dart icons at the bottom ──

func _build_dart_icons() -> void:
	var centre_x := 360.0  # Middle of 720px screen
	var start_x := centre_x - DART_ICON_SPACING

	for i in range(3):
		var icon := _create_dart_icon()
		icon.position = Vector2(start_x + i * DART_ICON_SPACING, DART_ICON_Y)
		add_child(icon)
		_dart_icons.append(icon)

func _create_dart_icon() -> Control:
	var container := Control.new()
	container.size = Vector2(DART_FLIGHT_W, DART_BARREL_H + DART_FLIGHT_H + DART_TIP_H)

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
	container.add_child(barrel)

	# Tip (tiny point at bottom)
	var tip := ColorRect.new()
	tip.color = Color(0.8, 0.8, 0.85, 0.9)
	tip.size = Vector2(2, DART_TIP_H)
	tip.position = Vector2((DART_FLIGHT_W - 2) / 2.0, DART_FLIGHT_H + DART_BARREL_H)
	container.add_child(tip)

	return container

# ── Zoom hint ──

func _build_zoom_hint() -> void:
	_zoom_hint = Label.new()
	_zoom_hint.text = "Pinch to zoom in for accuracy"
	_zoom_hint.add_theme_font_size_override("font_size", 14)
	_zoom_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 0.6))
	_zoom_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_hint.position = Vector2(0, DART_ICON_Y - 30)
	_zoom_hint.size = Vector2(720, 20)
	add_child(_zoom_hint)

# ── Impact flash (brief score text that fades) ──

func _build_impact_flash() -> void:
	_impact_label = Label.new()
	_impact_label.text = ""
	_impact_label.add_theme_font_size_override("font_size", 36)
	_impact_label.add_theme_color_override("font_color", Color.WHITE)
	_impact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_impact_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_impact_label.size = Vector2(200, 50)
	_impact_label.visible = false
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

	_summary_content = VBoxContainer.new()
	_summary_content.add_theme_constant_override("separation", 6)

	_summary_title = Label.new()
	_summary_title.add_theme_font_size_override("font_size", 18)
	_summary_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_summary_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_content.add_child(_summary_title)

	_summary_darts_label = Label.new()
	_summary_darts_label.add_theme_font_size_override("font_size", 24)
	_summary_darts_label.add_theme_color_override("font_color", Color.WHITE)
	_summary_darts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_content.add_child(_summary_darts_label)

	_summary_total_label = Label.new()
	_summary_total_label.add_theme_font_size_override("font_size", 32)
	_summary_total_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_summary_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_content.add_child(_summary_total_label)

	_summary_remaining_label = Label.new()
	_summary_remaining_label.add_theme_font_size_override("font_size", 20)
	_summary_remaining_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_summary_remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	_opponent_label.add_theme_font_size_override("font_size", 22)
	_opponent_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.5))
	_opponent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_opponent_label.position = Vector2(REMAINING_MARGIN, REMAINING_MARGIN)
	_opponent_label.size = Vector2(300, 55)
	add_child(_opponent_label)

	# Turn indicator at top-centre
	_turn_indicator = Label.new()
	_turn_indicator.text = "YOUR THROW"
	_turn_indicator.add_theme_font_size_override("font_size", 16)
	_turn_indicator.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	_turn_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_indicator.position = Vector2(210, REMAINING_MARGIN + 6)
	_turn_indicator.size = Vector2(300, 24)
	add_child(_turn_indicator)

	# Build identity display at bottom of screen
	_build_identity_display(opponent_id)

# ── Identity display (portraits + names at bottom of screen) ──

func _build_identity_display(opponent_id: String) -> void:
	# Left container — positioned at bottom-left
	_identity_left = Control.new()
	_identity_left.position = Vector2(IDENTITY_MARGIN, IDENTITY_Y)
	_identity_left.size = Vector2(200, 120)
	add_child(_identity_left)

	# Right container — positioned at bottom-right
	_identity_right = Control.new()
	_identity_right.position = Vector2(720 - 200 - IDENTITY_MARGIN, IDENTITY_Y)
	_identity_right.size = Vector2(200, 120)
	add_child(_identity_right)

	# Build player portrait
	_player_portrait = _build_player_portrait()

	# Build player name/nickname labels
	_player_name_label = Label.new()
	_player_name_label.text = DartData.get_character_name(GameState.character)
	_player_name_label.add_theme_font_size_override("font_size", 22)
	_player_name_label.add_theme_color_override("font_color", Color.WHITE)

	_player_nick_label = Label.new()
	_player_nick_label.text = DartData.get_character_nickname(GameState.character)
	_player_nick_label.add_theme_font_size_override("font_size", 14)
	# Use the character's flight front colour for the nickname
	var flight_col: Color = DartData.get_flight_colors(GameState.character)["front"]
	_player_nick_label.add_theme_color_override("font_color", flight_col)

	# Build opponent portrait placeholder
	_opp_portrait_panel = _build_opponent_placeholder(opponent_id)

	# Build opponent name/nickname labels
	_opp_name_label = Label.new()
	_opp_name_label.text = OpponentData.get_display_name(opponent_id)
	_opp_name_label.add_theme_font_size_override("font_size", 22)
	_opp_name_label.add_theme_color_override("font_color", Color.WHITE)

	_opp_nick_label = Label.new()
	_opp_nick_label.text = OpponentData.get_nickname(opponent_id)
	_opp_nick_label.add_theme_font_size_override("font_size", 14)
	_opp_nick_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))

	# Default layout: player turn (portrait left, stats right)
	_set_identity_layout(true)

func _build_player_portrait() -> Control:
	# Wrap in a clipping container to enforce fixed 90x90 size
	var clip := Control.new()
	clip.clip_contents = true
	clip.custom_minimum_size = Vector2(IDENTITY_PORTRAIT_SIZE, IDENTITY_PORTRAIT_SIZE)
	clip.size = Vector2(IDENTITY_PORTRAIT_SIZE, IDENTITY_PORTRAIT_SIZE)

	var portrait := TextureRect.new()
	var image_path := DartData.get_profile_image(GameState.character)
	var tex: Texture2D = load(image_path)
	portrait.texture = tex
	portrait.custom_minimum_size = Vector2(IDENTITY_PORTRAIT_SIZE, IDENTITY_PORTRAIT_SIZE)
	portrait.size = Vector2(IDENTITY_PORTRAIT_SIZE, IDENTITY_PORTRAIT_SIZE)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	clip.add_child(portrait)
	return clip

func _build_opponent_placeholder(opponent_id: String) -> Control:
	# Wrap in a clipping container to enforce fixed 90x90 size
	var clip := Control.new()
	clip.clip_contents = true
	clip.custom_minimum_size = Vector2(IDENTITY_PORTRAIT_SIZE, IDENTITY_PORTRAIT_SIZE)
	clip.size = Vector2(IDENTITY_PORTRAIT_SIZE, IDENTITY_PORTRAIT_SIZE)

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
		_opp_initial_label.add_theme_font_size_override("font_size", 36)
		_opp_initial_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 0.8))
		_opp_initial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(_opp_initial_label)

		var nick := Label.new()
		nick.text = OpponentData.get_nickname(opponent_id)
		nick.add_theme_font_size_override("font_size", 8)
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
		_turn_indicator.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		# Brighten player score, dim opponent
		_remaining_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.9))
		if _opponent_label:
			_opponent_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.35))
	else:
		_turn_indicator.text = OpponentData.get_display_name(_vs_opponent_id)
		_turn_indicator.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
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
	if label_text == "Miss":
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
