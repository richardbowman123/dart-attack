extends CanvasLayer
class_name SandboxOverlay

signal scatter_changed(mult: float)
signal clear_requested
signal exit_requested

# Stat values (0–100, step by 10) — all different so variety is obvious
var _dart_quality: float = 80.0
var _nerves: float = 15.0
var _confidence: float = 85.0
var _anger: float = 10.0

# Bar UI references
var _bar_fills: Array[ColorRect] = []

# Layout constants — centred horizontally with breathing room
const BAR_WIDTH := 200
const BAR_HEIGHT := 12
const ROW_STEP := 34
const BAR_NAMES: Array[String] = ["DARTS", "NERVES", "CONFIDENCE", "ANGER"]

# Horizontal layout — everything centred with equal left/right margins
const LABEL_W := 140
const BTN_W := 48
const CONTENT_W := 464  # 140 + 10 + 200 + 12 + 48 + 6 + 48
const MARGIN_X := 128   # (720 - 464) / 2

func _ready() -> void:
	layer = 15
	_build_ui()

func get_scatter_mult() -> float:
	# Must match match_manager.get_career_scatter_mult() exactly
	var nerve_mult := 0.85 + (_nerves / 100.0) * 0.7
	var conf_mult := 1.25 - (_confidence / 100.0) * 0.5
	var dq_mult := 1.15 - (_dart_quality / 100.0) * 0.35
	return nerve_mult * conf_mult * dq_mult

func _build_ui() -> void:
	# Panel background at the bottom — taller for breathing room
	var panel_h := 234
	var panel_y := 1280 - panel_h
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.07, 0.92)
	bg.position = Vector2(0, panel_y)
	bg.size = Vector2(720, panel_h)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Title
	var title := Label.new()
	title.text = "FREE THROW"
	UIFont.apply(title, UIFont.CAPTION)
	title.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, panel_y + 6)
	title.size = Vector2(720, 24)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	# Stat rows — centred layout with equal margins
	var row_y_start := panel_y + 38
	var stat_values := [_dart_quality, _nerves, _confidence, _anger]

	var label_x := MARGIN_X
	var bar_x := label_x + LABEL_W + 10
	var btn_minus_x := bar_x + BAR_WIDTH + 12
	var btn_plus_x := btn_minus_x + BTN_W + 6

	for i in range(4):
		var y := row_y_start + i * ROW_STEP
		var bar_y := y + (ROW_STEP - BAR_HEIGHT) / 2.0

		# Label — right-aligned, smaller font so CONFIDENCE fits
		var lbl := Label.new()
		lbl.text = BAR_NAMES[i]
		UIFont.apply(lbl, 20)
		lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(label_x, y)
		lbl.size = Vector2(LABEL_W, ROW_STEP)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)

		# Bar background
		var bar_bg := ColorRect.new()
		bar_bg.color = Color(0.12, 0.12, 0.15)
		bar_bg.position = Vector2(bar_x, bar_y)
		bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
		bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar_bg)

		# Bar fill
		var fill := ColorRect.new()
		var frac: float = float(stat_values[i]) / 100.0
		fill.color = _get_bar_color(i, frac)
		fill.position = Vector2(bar_x, bar_y)
		fill.size = Vector2(BAR_WIDTH * frac, BAR_HEIGHT)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fill)
		_bar_fills.append(fill)

		# Minus button
		var minus_btn := _make_btn("-", Color(0.35, 0.15, 0.15), BTN_W)
		minus_btn.position = Vector2(btn_minus_x, y + 2)
		minus_btn.size = Vector2(BTN_W, ROW_STEP - 4)
		minus_btn.pressed.connect(_on_stat_change.bind(i, -10))
		add_child(minus_btn)

		# Plus button
		var plus_btn := _make_btn("+", Color(0.15, 0.35, 0.15), BTN_W)
		plus_btn.position = Vector2(btn_plus_x, y + 2)
		plus_btn.size = Vector2(BTN_W, ROW_STEP - 4)
		plus_btn.pressed.connect(_on_stat_change.bind(i, 10))
		add_child(plus_btn)

	# Button row at the bottom — centred with equal margins
	var btn_y := row_y_start + 4 * ROW_STEP + 10
	var action_btn_w := 300
	var action_gap := 20
	var action_total := action_btn_w * 2 + action_gap
	var action_x := (720 - action_total) / 2

	var clear_btn := _make_btn("CLEAR BOARD", Color(0.3, 0.25, 0.1), action_btn_w)
	clear_btn.position = Vector2(action_x, btn_y)
	clear_btn.size = Vector2(action_btn_w, 44)
	clear_btn.pressed.connect(func() -> void: clear_requested.emit())
	add_child(clear_btn)

	var done_btn := _make_btn("DONE", Color(0.15, 0.45, 0.15), action_btn_w)
	done_btn.position = Vector2(action_x + action_btn_w + action_gap, btn_y)
	done_btn.size = Vector2(action_btn_w, 44)
	done_btn.pressed.connect(func() -> void: exit_requested.emit())
	add_child(done_btn)

func _on_stat_change(index: int, delta: int) -> void:
	match index:
		0: _dart_quality = clampf(_dart_quality + delta, 0.0, 100.0)
		1: _nerves = clampf(_nerves + delta, 0.0, 100.0)
		2: _confidence = clampf(_confidence + delta, 0.0, 100.0)
		3: _anger = clampf(_anger + delta, 0.0, 100.0)

	var values := [_dart_quality, _nerves, _confidence, _anger]
	var frac: float = float(values[index]) / 100.0
	_bar_fills[index].size = Vector2(BAR_WIDTH * frac, BAR_HEIGHT)
	_bar_fills[index].color = _get_bar_color(index, frac)
	scatter_changed.emit(get_scatter_mult())

## Bar colour logic — matches ScoreHUD exactly
func _get_bar_color(bar_index: int, frac: float) -> Color:
	match bar_index:
		0:
			# Darts: grey → silver → gold
			if frac < 0.5:
				return Color(0.4, 0.4, 0.4).lerp(Color(0.75, 0.75, 0.78), frac * 2.0)
			else:
				return Color(0.75, 0.75, 0.78).lerp(Color(1.0, 0.85, 0.0), (frac - 0.5) * 2.0)
		1:
			# Nerves: green → amber → red
			if frac < 0.5:
				return Color(0.2, 0.8, 0.2).lerp(Color(1.0, 0.7, 0.1), frac * 2.0)
			else:
				return Color(1.0, 0.7, 0.1).lerp(Color(0.9, 0.15, 0.15), (frac - 0.5) * 2.0)
		2:
			# Confidence: red → amber → gold
			if frac < 0.5:
				return Color(0.8, 0.2, 0.2).lerp(Color(1.0, 0.7, 0.1), frac * 2.0)
			else:
				return Color(1.0, 0.7, 0.1).lerp(Color(1.0, 0.85, 0.0), (frac - 0.5) * 2.0)
		3:
			# Anger: green → amber → red
			if frac < 0.5:
				return Color(0.2, 0.8, 0.2).lerp(Color(1.0, 0.7, 0.1), frac * 2.0)
			else:
				return Color(1.0, 0.7, 0.1).lerp(Color(0.9, 0.15, 0.15), (frac - 0.5) * 2.0)
		_:
			return Color(0.5, 0.5, 0.5)

func _make_btn(text: String, bg_color: Color, w: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(w, 24)
	UIFont.apply_button(btn, UIFont.CAPTION)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))

	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = bg_color.lightened(0.3)
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = bg_color.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed)

	return btn
