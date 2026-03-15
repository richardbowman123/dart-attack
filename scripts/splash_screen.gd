extends Node3D

# ─────────────────────────────────────────────────────────
#  SPLASH SCREEN
#  Dramatic intro: tilted dartboard, premium tungsten darts
#  thud in, bold title, Play button.
# ─────────────────────────────────────────────────────────

var _play_button: Button
var _darts: Array[Dart] = []

var _thud_stream: AudioStreamWAV
var _thud_player: AudioStreamPlayer

func _ready() -> void:
	_thud_stream = _create_thud_sound()
	_build_scene()
	_animate_darts()

# ─────────────────────────────────────────────────────────
#  SCENE CONSTRUCTION
# ─────────────────────────────────────────────────────────

func _build_scene() -> void:
	# Dark background
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.04)
	env.ambient_light_color = Color(0.15, 0.15, 0.18)
	env.ambient_light_energy = 0.3

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Dartboard — tilted back: bottom closer to camera, top further away
	# This reveals dart profiles from the front without looking down from above
	var dartboard := Dartboard.new()
	dartboard.rotation_degrees.x = -35.0
	add_child(dartboard)

	# Camera — at bullseye height, straight-on, bullseye centred
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, -0.3, 4.5)
	camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	camera.fov = 50.0
	add_child(camera)

	# Dramatic spot light from above-right
	var spot := SpotLight3D.new()
	spot.position = Vector3(1.0, 2.5, 3.0)
	spot.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	spot.light_energy = 3.0
	spot.light_color = Color(1.0, 0.95, 0.85)
	spot.spot_range = 12.0
	spot.spot_angle = 40.0
	spot.shadow_enabled = true
	add_child(spot)

	# Fill light from the left
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.4
	fill.light_color = Color(0.6, 0.65, 0.8)
	fill.rotation_degrees = Vector3(-20, -40, 0)
	add_child(fill)

	# Audio player for thud sounds
	_thud_player = AudioStreamPlayer.new()
	_thud_player.stream = _thud_stream
	add_child(_thud_player)

	# ── UI Layer ──
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var title_container := Control.new()
	title_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(title_container)

	# Title: "DART" and "ATTACK" — per-letter dartboard-coloured outlines
	# The four dartboard segment colours, cycling through each letter
	var board_colours := [
		Color(0.85, 0.12, 0.12),   # Red
		Color(0.0, 0.50, 0.15),    # Green
		Color(0.08, 0.08, 0.08),   # Black
		Color(0.92, 0.87, 0.72),   # Cream
	]

	var logo_font_size := 130
	_build_logo_word("DART", logo_font_size, 350, 0, board_colours, title_container)
	_build_logo_word("ATTACK", logo_font_size, 500, 4, board_colours, title_container)

	# Play button — hidden initially
	_play_button = Button.new()
	_play_button.text = "PLAY"
	_play_button.position = Vector2(210, 1050)
	_play_button.size = Vector2(300, 80)
	UIFont.apply_button(_play_button, UIFont.HEADING)
	_play_button.modulate.a = 0.0

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.15, 0.55, 0.2)
	btn_normal.corner_radius_top_left = 12
	btn_normal.corner_radius_top_right = 12
	btn_normal.corner_radius_bottom_left = 12
	btn_normal.corner_radius_bottom_right = 12
	btn_normal.border_width_left = 3
	btn_normal.border_width_right = 3
	btn_normal.border_width_top = 3
	btn_normal.border_width_bottom = 3
	btn_normal.border_color = Color(0.3, 0.85, 0.4)
	_play_button.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := btn_normal.duplicate()
	btn_hover.bg_color = Color(0.2, 0.65, 0.25)
	_play_button.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed := btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.1, 0.45, 0.15)
	_play_button.add_theme_stylebox_override("pressed", btn_pressed)

	_play_button.add_theme_color_override("font_color", Color.WHITE)
	_play_button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))
	_play_button.pressed.connect(_on_play_pressed)
	title_container.add_child(_play_button)

# ─────────────────────────────────────────────────────────
#  LOGO — per-letter dartboard-coloured outlines
# ─────────────────────────────────────────────────────────

func _build_logo_word(word: String, font_size: int, y_pos: int, colour_offset: int, colours: Array, parent: Control) -> void:
	# Container for the whole word — tilted slightly for attitude
	var word_container := Control.new()
	word_container.size = Vector2(720, font_size + 40)
	word_container.position = Vector2(0, y_pos)
	word_container.rotation = deg_to_rad(-4.0)
	word_container.pivot_offset = Vector2(360, (font_size + 40) / 2.0)
	parent.add_child(word_container)

	# Measure total width so we can centre the letters
	var font: Font = UIFont._font
	var total_width := 0.0
	var char_widths: Array[float] = []
	for i in range(word.length()):
		var ch := word[i]
		var w: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		char_widths.append(w)
		total_width += w

	# Place each letter with its own outline colour
	var x_offset := (720.0 - total_width) / 2.0
	for i in range(word.length()):
		var ch := word[i]
		var outline_col: Color = colours[(colour_offset + i) % colours.size()]

		var letter := Label.new()
		letter.text = ch
		letter.position = Vector2(x_offset, 0)
		letter.size = Vector2(char_widths[i], font_size + 40)

		var settings := UIFont.make_label_settings(font_size, Color.WHITE)
		settings.outline_size = 16
		settings.outline_color = outline_col
		settings.shadow_size = 10
		settings.shadow_color = Color(0.0, 0.0, 0.0, 0.8)
		settings.shadow_offset = Vector2(5, 5)
		letter.label_settings = settings

		word_container.add_child(letter)
		x_offset += char_widths[i]

# ─────────────────────────────────────────────────────────
#  DART ANIMATION
# ─────────────────────────────────────────────────────────

func _animate_darts() -> void:
	# Hit positions — offset so the dart tip lands near the bullseye
	# With the new dramatic angle, the barrel hangs mostly downward from the tip
	var hit_positions: Array[Vector3] = [
		Vector3(0.03, 0.84, 0.19),   # Green — back
		Vector3(-0.02, 0.82, 0.20),  # Black — middle
		Vector3(0.01, 0.83, 0.21),   # Red — front (closest to camera)
	]

	# Dart direction: 80deg from camera for dramatic full-profile view
	# Shows the full barrel length — TV-style close-up appearance
	var dart_direction := Vector3(0.0, -0.971, -0.239)

	var start_pos := Vector3(0.0, 1.5, 9.0)

	# Stagger timings — builds anticipation with increasing gaps
	var delays := [0.5, 1.1, 2.0]

	# Flight colours: green, black, red — the dartboard colours
	var flight_colours := [
		Color(0.05, 0.45, 0.15),   # Green
		Color(0.08, 0.08, 0.08),   # Black
		Color(0.78, 0.12, 0.12),   # Red
	]

	for i in range(3):
		var dart := Dart.create(0, DartData.Character.DAI)
		dart.freeze = true
		dart.visual_scale = 2.5
		dart.flight_scale = 1.5
		dart.custom_flight_color = flight_colours[i]
		dart.position = start_pos
		add_child(dart)

		# Orient dart at dramatic 80deg angle — use BACK as up vector to avoid gimbal lock
		dart.look_at(dart.global_position + dart_direction, Vector3.BACK)

		_darts.append(dart)

		var target: Vector3 = hit_positions[i]

		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_EXPO)

		tween.tween_interval(delays[i])
		tween.tween_property(dart, "position", target, 0.15)

		# Thud sound when dart lands
		tween.tween_callback(_play_thud)

	# Fade in Play button after last dart (lands at ~2.15s)
	var btn_tween := create_tween()
	btn_tween.tween_interval(3.0)
	btn_tween.tween_property(_play_button, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_IN_OUT)

# ─────────────────────────────────────────────────────────
#  THUD SOUND — layered impact
#  Sharp noise transient + multiple board resonances + fibre crack
# ─────────────────────────────────────────────────────────

func _create_thud_sound() -> AudioStreamWAV:
	var sample_rate := 44100
	var duration := 0.18
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	for i in range(num_samples):
		var t := float(i) / sample_rate

		# Sharp impact transient — noise burst, first 5ms
		var impact := 0.0
		if t < 0.005:
			impact = _pseudo_noise(i) * (1.0 - t / 0.005) * 0.7

		# Board resonance — multiple damped frequencies (dense wood/sisal character)
		var res := 0.0
		res += sin(TAU * 110.0 * t) * exp(-t * 30.0) * 0.45
		res += sin(TAU * 175.0 * t) * exp(-t * 38.0) * 0.30
		res += sin(TAU * 260.0 * t) * exp(-t * 45.0) * 0.18
		res += sin(TAU * 350.0 * t) * exp(-t * 55.0) * 0.10

		# Fibre splitting — mid-freq noise, decays in ~25ms
		var fibre := 0.0
		if t < 0.025:
			fibre = _pseudo_noise(i + 10000) * exp(-t * 60.0) * 0.25

		var sample := (impact + res + fibre)
		var sample_int := int(sample * 28000.0)
		sample_int = clampi(sample_int, -32768, 32767)

		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

func _play_thud() -> void:
	_thud_player.play()

# Deterministic noise for audio generation
func _pseudo_noise(seed_val: int) -> float:
	var n := seed_val
	n = (n << 13) ^ n
	n = n * (n * n * 15731 + 789221) + 1376312589
	return 1.0 - float(n & 0x7fffffff) / 1073741824.0

# ─────────────────────────────────────────────────────────
#  NAVIGATION
# ─────────────────────────────────────────────────────────

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")
