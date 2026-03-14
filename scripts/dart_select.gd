extends Control

const CARD_WIDTH := 620
const CARD_HEIGHT := 130
const CARD_GAP := 16
const CARD_START_Y := 340
const CARD_X := 50  # (720 - 620) / 2

const ACCURACY_LABELS := [
	"Pub standard - wide scatter",
	"Decent grouping - learning to aim",
	"Tight clusters - serious kit",
	"Precision grouping - match ready",
]

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Title
	var title := Label.new()
	title.text = "CHOOSE YOUR DARTS"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 120)
	title.size = Vector2(720, 55)
	add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Select a tier to play or view in 3D"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 180)
	subtitle.size = Vector2(720, 30)
	add_child(subtitle)

	# Current mode label
	var mode_label := Label.new()
	var mode_text := ""
	match GameState.game_mode:
		GameState.GameMode.TUTORIAL:
			mode_text = "Tutorial"
		GameState.GameMode.ROUND_THE_CLOCK:
			mode_text = "Round the Clock"
		GameState.GameMode.COUNTDOWN:
			mode_text = str(GameState.starting_score)
	mode_label.text = mode_text
	mode_label.add_theme_font_size_override("font_size", 22)
	mode_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.position = Vector2(0, 220)
	mode_label.size = Vector2(720, 30)
	add_child(mode_label)

	# Tier cards
	for i in range(DartData.TIERS.size()):
		_build_card(i)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(260, 1170)
	back_btn.size = Vector2(200, 60)
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.add_theme_color_override("font_color", Color.WHITE)

	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.15, 0.15, 0.2)
	back_style.corner_radius_top_left = 8
	back_style.corner_radius_top_right = 8
	back_style.corner_radius_bottom_left = 8
	back_style.corner_radius_bottom_right = 8
	back_style.border_width_left = 2
	back_style.border_width_right = 2
	back_style.border_width_top = 2
	back_style.border_width_bottom = 2
	back_style.border_color = Color(0.3, 0.3, 0.35)
	back_btn.add_theme_stylebox_override("normal", back_style)

	var back_hover := back_style.duplicate()
	back_hover.bg_color = Color(0.2, 0.2, 0.28)
	back_hover.border_color = Color(0.5, 0.5, 0.6)
	back_btn.add_theme_stylebox_override("hover", back_hover)

	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

func _build_card(tier: int) -> void:
	var data := DartData.get_tier(tier)
	var y := CARD_START_Y + tier * (CARD_HEIGHT + CARD_GAP)

	# Card background
	var card := Panel.new()
	card.position = Vector2(CARD_X, y)
	card.size = Vector2(CARD_WIDTH, CARD_HEIGHT)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.1, 0.1, 0.14)
	card_style.corner_radius_top_left = 10
	card_style.corner_radius_top_right = 10
	card_style.corner_radius_bottom_left = 10
	card_style.corner_radius_bottom_right = 10
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.25, 0.25, 0.3)
	card.add_theme_stylebox_override("panel", card_style)
	add_child(card)

	# Barrel colour swatch
	var swatch := ColorRect.new()
	swatch.color = data["barrel_color"]
	swatch.position = Vector2(CARD_X + 16, y + 20)
	swatch.size = Vector2(40, 40)
	add_child(swatch)

	# Collar colour swatch (smaller, below barrel)
	var collar_swatch := ColorRect.new()
	collar_swatch.color = data["collar_color"]
	collar_swatch.position = Vector2(CARD_X + 16, y + 66)
	collar_swatch.size = Vector2(40, 20)
	add_child(collar_swatch)

	# Tier name
	var name_label := Label.new()
	name_label.text = data["name"]
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	name_label.position = Vector2(CARD_X + 72, y + 12)
	name_label.size = Vector2(300, 32)
	add_child(name_label)

	# Weight label
	var weight_label := Label.new()
	weight_label.text = data["weight_label"]
	weight_label.add_theme_font_size_override("font_size", 18)
	weight_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	weight_label.position = Vector2(CARD_X + 72, y + 46)
	weight_label.size = Vector2(100, 24)
	add_child(weight_label)

	# Accuracy description
	var acc_label := Label.new()
	acc_label.text = ACCURACY_LABELS[tier]
	acc_label.add_theme_font_size_override("font_size", 14)
	acc_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	acc_label.position = Vector2(CARD_X + 72, y + 72)
	acc_label.size = Vector2(300, 20)
	add_child(acc_label)

	# SELECT button (green)
	var select_btn := Button.new()
	select_btn.text = "SELECT"
	select_btn.position = Vector2(CARD_X + CARD_WIDTH - 230, y + 18)
	select_btn.size = Vector2(100, 42)
	select_btn.add_theme_font_size_override("font_size", 16)
	select_btn.add_theme_color_override("font_color", Color.WHITE)

	var select_style := StyleBoxFlat.new()
	select_style.bg_color = Color(0.15, 0.5, 0.2)
	select_style.corner_radius_top_left = 6
	select_style.corner_radius_top_right = 6
	select_style.corner_radius_bottom_left = 6
	select_style.corner_radius_bottom_right = 6
	select_btn.add_theme_stylebox_override("normal", select_style)

	var select_hover := select_style.duplicate()
	select_hover.bg_color = Color(0.2, 0.6, 0.25)
	select_btn.add_theme_stylebox_override("hover", select_hover)

	var select_pressed := select_style.duplicate()
	select_pressed.bg_color = Color(0.25, 0.65, 0.3)
	select_btn.add_theme_stylebox_override("pressed", select_pressed)

	select_btn.pressed.connect(_on_select.bind(tier))
	add_child(select_btn)

	# VIEW button (dark blue)
	var view_btn := Button.new()
	view_btn.text = "VIEW"
	view_btn.position = Vector2(CARD_X + CARD_WIDTH - 115, y + 18)
	view_btn.size = Vector2(100, 42)
	view_btn.add_theme_font_size_override("font_size", 16)
	view_btn.add_theme_color_override("font_color", Color.WHITE)

	var view_style := StyleBoxFlat.new()
	view_style.bg_color = Color(0.12, 0.18, 0.4)
	view_style.corner_radius_top_left = 6
	view_style.corner_radius_top_right = 6
	view_style.corner_radius_bottom_left = 6
	view_style.corner_radius_bottom_right = 6
	view_btn.add_theme_stylebox_override("normal", view_style)

	var view_hover := view_style.duplicate()
	view_hover.bg_color = Color(0.18, 0.25, 0.5)
	view_btn.add_theme_stylebox_override("hover", view_hover)

	var view_pressed := view_style.duplicate()
	view_pressed.bg_color = Color(0.22, 0.3, 0.55)
	view_btn.add_theme_stylebox_override("pressed", view_pressed)

	view_btn.pressed.connect(_on_view.bind(tier))
	add_child(view_btn)

	# Scatter indicator (visual bar)
	var scatter_bg := ColorRect.new()
	scatter_bg.color = Color(0.2, 0.2, 0.25)
	scatter_bg.position = Vector2(CARD_X + CARD_WIDTH - 230, y + 74)
	scatter_bg.size = Vector2(215, 8)
	add_child(scatter_bg)

	var scatter_fill := ColorRect.new()
	var accuracy: float = 1.0 - data["scatter_mult"]  # Invert: lower scatter = higher accuracy
	scatter_fill.color = Color(0.2, 0.7, 0.3).lerp(Color(1.0, 0.85, 0.2), accuracy)
	scatter_fill.position = Vector2(CARD_X + CARD_WIDTH - 230, y + 74)
	scatter_fill.size = Vector2(215 * accuracy, 8)
	add_child(scatter_fill)

	# Accuracy label for bar
	var bar_label := Label.new()
	bar_label.text = "Accuracy"
	bar_label.add_theme_font_size_override("font_size", 10)
	bar_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	bar_label.position = Vector2(CARD_X + CARD_WIDTH - 230, y + 84)
	bar_label.size = Vector2(100, 14)
	add_child(bar_label)

func _on_select(tier: int) -> void:
	GameState.dart_tier = tier
	get_tree().change_scene_to_file("res://scenes/match.tscn")

func _on_view(tier: int) -> void:
	GameState.dart_tier = tier
	get_tree().change_scene_to_file("res://scenes/dart_viewer.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
