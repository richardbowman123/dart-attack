extends Control

var _selected_index: int = 0
var _card_styles: Array = []
var _card_names: Array = []
var _info_name: Label
var _info_origin: Label
var _char_enums: Array = []

func _ready() -> void:
	_build_screen()

func _build_screen() -> void:
	var characters := [
		{
			"enum": DartData.Character.DAI,
			"name": "Dai Davies",
			"short_name": "DAI",
			"origin": "Pontypridd, Wales",
			"image": "res://Dai The Dragon Davies 16 profile.jpg",
		},
		{
			"enum": DartData.Character.TERRY,
			"name": "Terry Hoskins",
			"short_name": "TERRY",
			"origin": "Bethnal Green, London",
			"image": "res://Terry The Hammer Hoskins 19 profile.jpg",
		},
		{
			"enum": DartData.Character.RAB,
			"name": "Rab McTavish",
			"short_name": "RAB",
			"origin": "Dundee, Scotland",
			"image": "res://Rab The Flame McTavish 21 profile.jpg",
		},
		{
			"enum": DartData.Character.SIOBHAN,
			"name": "Siobhan O'Hara",
			"short_name": "SIOBHAN",
			"origin": "Belfast, N. Ireland",
			"image": "res://Siobhan The Banshee O'Hara 19 profile.jpg",
		},
	]

	for i in range(characters.size()):
		_char_enums.append(characters[i]["enum"])
		if characters[i]["enum"] == GameState.character:
			_selected_index = i

	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Title
	var title := Label.new()
	title.text = "DART ATTACK"
	UIFont.apply(title, UIFont.SCREEN_TITLE)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 25)
	title.size = Vector2(720, 75)
	add_child(title)

	# Subtitle
	var pick_label := Label.new()
	pick_label.text = "Pick your player"
	UIFont.apply(pick_label, UIFont.CAPTION)
	pick_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	pick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pick_label.position = Vector2(0, 105)
	pick_label.size = Vector2(720, 35)
	add_child(pick_label)

	# ── 2x2 grid of large character cards ──
	var card_w := 320
	var card_h := 370
	var card_gap := 16
	var total_w := card_w * 2 + card_gap
	var grid_left := (720 - total_w) / 2
	var grid_top := 155

	for i in range(characters.size()):
		var data: Dictionary = characters[i]
		var col: int = i % 2
		var row: int = i / 2
		var x: int = grid_left + col * (card_w + card_gap)
		var y: int = grid_top + row * (card_h + card_gap)
		_build_character_card(Vector2(x, y), card_w, card_h, data, i)

	# Selected character info below grid — spread out evenly
	var info_y: int = grid_top + card_h * 2 + card_gap + 10
	_info_name = Label.new()
	UIFont.apply(_info_name, UIFont.SUBHEADING)
	_info_name.add_theme_color_override("font_color", Color(0.85, 0.7, 0.2))
	_info_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_name.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_info_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_name.position = Vector2(70, info_y)
	_info_name.size = Vector2(580, 85)
	add_child(_info_name)

	_info_origin = Label.new()
	UIFont.apply(_info_origin, UIFont.CAPTION)
	_info_origin.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	_info_origin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_origin.position = Vector2(0, info_y + 130)
	_info_origin.size = Vector2(720, 35)
	add_child(_info_origin)

	_update_selection(characters)

	# ── NEXT button (green, matching splash screen PLAY) ──
	var next_btn := Button.new()
	next_btn.text = "NEXT"
	next_btn.position = Vector2(160, info_y + 210)
	next_btn.size = Vector2(400, 80)
	UIFont.apply_button(next_btn, UIFont.HEADING)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.55, 0.2)
	normal_style.corner_radius_top_left = 12
	normal_style.corner_radius_top_right = 12
	normal_style.corner_radius_bottom_left = 12
	normal_style.corner_radius_bottom_right = 12
	normal_style.border_width_left = 3
	normal_style.border_width_right = 3
	normal_style.border_width_top = 3
	normal_style.border_width_bottom = 3
	normal_style.border_color = Color(0.3, 0.85, 0.4)
	next_btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.2, 0.65, 0.25)
	next_btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color(0.1, 0.45, 0.15)
	next_btn.add_theme_stylebox_override("pressed", pressed_style)

	next_btn.add_theme_color_override("font_color", Color.WHITE)
	next_btn.pressed.connect(_on_next_pressed)
	add_child(next_btn)

func _build_character_card(pos: Vector2, w: int, h: int, data: Dictionary, index: int) -> void:
	var card := Panel.new()
	card.position = pos
	card.size = Vector2(w, h)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.2, 0.2, 0.25)
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	_card_styles.append(style)

	# Portrait image — fills most of the card
	var portrait := TextureRect.new()
	var image_path: String = data["image"]
	var tex: Texture2D = load(image_path)
	portrait.texture = tex
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(6, 6)
	portrait.size = Vector2(w - 12, h - 60)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(portrait)

	# Character name at bottom of card
	var name_label := Label.new()
	var short_name: String = data["short_name"]
	name_label.text = short_name
	UIFont.apply(name_label, UIFont.CAPTION)
	name_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(0, h - 42)
	name_label.size = Vector2(w, 36)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_label)
	_card_names.append(name_label)

	card.gui_input.connect(_on_card_tap.bind(index))

func _on_card_tap(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_selected_index = index
			GameState.character = _char_enums[index]
			_refresh_selection()

func _refresh_selection() -> void:
	for i in range(_card_styles.size()):
		if i == _selected_index:
			_card_styles[i].border_color = Color(0.85, 0.7, 0.2)
			_card_names[i].add_theme_color_override("font_color", Color(0.85, 0.7, 0.2))
		else:
			_card_styles[i].border_color = Color(0.2, 0.2, 0.25)
			_card_names[i].add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))

	var names := [
		"Dai Davies",
		"Terry Hoskins",
		"Rab McTavish",
		"Siobhan O'Hara",
	]
	var origins := [
		"Pontypridd, Wales",
		"Bethnal Green, London",
		"Dundee, Scotland",
		"Belfast, N. Ireland",
	]
	_info_name.text = names[_selected_index]
	_info_origin.text = origins[_selected_index]

func _update_selection(characters: Array) -> void:
	for i in range(_card_styles.size()):
		if i == _selected_index:
			_card_styles[i].border_color = Color(0.85, 0.7, 0.2)
			_card_names[i].add_theme_color_override("font_color", Color(0.85, 0.7, 0.2))
		else:
			_card_styles[i].border_color = Color(0.2, 0.2, 0.25)
			_card_names[i].add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))

	var selected_data: Dictionary = characters[_selected_index]
	var sel_name: String = selected_data["name"]
	var sel_origin: String = selected_data["origin"]
	_info_name.text = sel_name
	_info_origin.text = sel_origin

func _on_next_pressed() -> void:
	if CareerState.career_level == 1 and not CareerState.career_intro_seen:
		get_tree().change_scene_to_file("res://scenes/career_intro.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
