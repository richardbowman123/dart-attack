extends Control

const CARD_W := 300.0
const CARD_H := 380.0
const CARD_GAP := 20.0

func _ready() -> void:
	_build_screen()

func _build_screen() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# "Pick your player" title
	var title := Label.new()
	title.text = "PICK YOUR PLAYER"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 60)
	title.size = Vector2(720, 60)
	add_child(title)

	# 2x2 grid of character cards
	var grid_left := (720.0 - (CARD_W * 2 + CARD_GAP)) / 2.0
	var grid_top := 160.0

	# Row 1
	_add_character_card(
		Vector2(grid_left, grid_top),
		"Dai \"The Dragon\" Davies", "Pontypridd, Wales",
		"res://Dai The Dragon Davies 16 profile.jpg"
	)
	_add_locked_card(
		Vector2(grid_left + CARD_W + CARD_GAP, grid_top),
		"Terry \"The Hammer\" Hoskins", "Bethnal Green, London",
		"$"
	)

	# Row 2
	_add_locked_card(
		Vector2(grid_left, grid_top + CARD_H + CARD_GAP),
		"Rab \"The Flame\" McTavish", "Dundee, Scotland",
		"$$"
	)
	_add_locked_card(
		Vector2(grid_left + CARD_W + CARD_GAP, grid_top + CARD_H + CARD_GAP),
		"Siobhan \"The Banshee\" O'Hara", "Belfast, N. Ireland",
		"$$$"
	)

func _add_character_card(pos: Vector2, char_name: String, origin: String, image_path: String) -> void:
	var card := Panel.new()
	card.position = pos
	card.size = Vector2(CARD_W, CARD_H)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.12, 0.16)
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.85, 0.7, 0.2)
	card.add_theme_stylebox_override("panel", card_style)
	add_child(card)

	# Portrait image
	var portrait := TextureRect.new()
	var img := Image.load_from_file(image_path)
	var tex := ImageTexture.create_from_image(img)
	portrait.texture = tex
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(15, 10)
	portrait.size = Vector2(CARD_W - 30, 240)
	card.add_child(portrait)

	# Name
	var name_label := Label.new()
	name_label.text = char_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.2))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.position = Vector2(5, 255)
	name_label.size = Vector2(CARD_W - 10, 40)
	card.add_child(name_label)

	# Origin
	var origin_label := Label.new()
	origin_label.text = origin
	origin_label.add_theme_font_size_override("font_size", 14)
	origin_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	origin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	origin_label.position = Vector2(5, 295)
	origin_label.size = Vector2(CARD_W - 10, 25)
	card.add_child(origin_label)

	# Select button
	var btn := Button.new()
	btn.text = "SELECT"
	btn.position = Vector2(40, CARD_H - 55)
	btn.size = Vector2(CARD_W - 80, 42)
	btn.add_theme_font_size_override("font_size", 20)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.6, 0.15, 0.15)
	normal_style.corner_radius_top_left = 6
	normal_style.corner_radius_top_right = 6
	normal_style.corner_radius_bottom_left = 6
	normal_style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.75, 0.2, 0.2)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color(0.85, 0.25, 0.25)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.pressed.connect(_on_select_pressed)
	card.add_child(btn)

func _add_locked_card(pos: Vector2, char_name: String, origin: String, price: String) -> void:
	var card := Panel.new()
	card.position = pos
	card.size = Vector2(CARD_W, CARD_H)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.08, 0.1)
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.2, 0.2, 0.25)
	card.add_theme_stylebox_override("panel", card_style)
	add_child(card)

	# Silhouette placeholder — question mark
	var silhouette := Label.new()
	silhouette.text = "?"
	silhouette.add_theme_font_size_override("font_size", 120)
	silhouette.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))
	silhouette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	silhouette.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	silhouette.position = Vector2(0, 30)
	silhouette.size = Vector2(CARD_W, 200)
	card.add_child(silhouette)

	# Name (dimmed)
	var name_label := Label.new()
	name_label.text = char_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.position = Vector2(5, 255)
	name_label.size = Vector2(CARD_W - 10, 40)
	card.add_child(name_label)

	# Origin (dimmed)
	var origin_label := Label.new()
	origin_label.text = origin
	origin_label.add_theme_font_size_override("font_size", 14)
	origin_label.add_theme_color_override("font_color", Color(0.25, 0.25, 0.3))
	origin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	origin_label.position = Vector2(5, 295)
	origin_label.size = Vector2(CARD_W - 10, 25)
	card.add_child(origin_label)

	# "Coming Soon" label instead of button
	var coming := Label.new()
	coming.text = "COMING SOON"
	coming.add_theme_font_size_override("font_size", 18)
	coming.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
	coming.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coming.position = Vector2(0, CARD_H - 55)
	coming.size = Vector2(CARD_W, 25)
	card.add_child(coming)

	# Price indicator
	var price_label := Label.new()
	price_label.text = price
	price_label.add_theme_font_size_override("font_size", 16)
	price_label.add_theme_color_override("font_color", Color(0.4, 0.35, 0.2))
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.position = Vector2(0, CARD_H - 32)
	price_label.size = Vector2(CARD_W, 22)
	card.add_child(price_label)

func _on_select_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
