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

func _ready() -> void:
	_build_remaining_display()
	_build_dart_icons()
	_build_impact_flash()
	_build_summary_panel()

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

# ── Public methods called by match_manager ──

func update_remaining(value: int) -> void:
	_remaining_label.text = str(value)

func update_remaining_text(text: String) -> void:
	_remaining_label.text = text

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
	var darts_text := ""
	for i in range(dart_labels.size()):
		if i > 0:
			darts_text += "   "
		darts_text += str(dart_labels[i])
	_summary_darts_label.text = darts_text

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

	_summary_remaining_label.text = str(remaining) + " remaining"
	_summary_panel.visible = true

func show_bust_summary(dart_labels: Array, reverted_score: int) -> void:
	_summary_title.text = "BUST!"
	var darts_text := ""
	for i in range(dart_labels.size()):
		if i > 0:
			darts_text += "   "
		darts_text += str(dart_labels[i])
	_summary_darts_label.text = darts_text
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
	var darts_text := ""
	for i in range(dart_labels.size()):
		if i > 0:
			darts_text += "   "
		darts_text += str(dart_labels[i])
	_summary_darts_label.text = darts_text

	# Show what numbers were ticked off
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

	_summary_remaining_label.text = next_target
	_summary_panel.visible = true

func hide_summary() -> void:
	_summary_panel.visible = false

func reset_dart_icons() -> void:
	for icon in _dart_icons:
		icon.modulate = Color(1, 1, 1, 1)
