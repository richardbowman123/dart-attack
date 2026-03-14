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

	# Title: "DART" and "ATTACK"
	var dart_label := Label.new()
	dart_label.text = "DART"
	dart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dart_label.position = Vector2(0, 100)
	dart_label.size = Vector2(720, 120)
	dart_label.rotation = deg_to_rad(-5.0)
	dart_label.pivot_offset = Vector2(360, 60)

	var dart_settings := LabelSettings.new()
	dart_settings.font_size = 96
	dart_settings.font_color = Color.WHITE
	dart_settings.outline_size = 14
	dart_settings.outline_color = Color(0.75, 0.1, 0.1)
	dart_settings.shadow_size = 8
	dart_settings.shadow_color = Color(0.0, 0.0, 0.0, 0.8)
	dart_settings.shadow_offset = Vector2(5, 5)
	dart_label.label_settings = dart_settings
	title_container.add_child(dart_label)

	var attack_label := Label.new()
	attack_label.text = "ATTACK"
	attack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attack_label.position = Vector2(0, 210)
	attack_label.size = Vector2(720, 120)
	attack_label.rotation = deg_to_rad(-5.0)
	attack_label.pivot_offset = Vector2(360, 60)

	var attack_settings := LabelSettings.new()
	attack_settings.font_size = 96
	attack_settings.font_color = Color.WHITE
	attack_settings.outline_size = 14
	attack_settings.outline_color = Color(0.75, 0.1, 0.1)
	attack_settings.shadow_size = 8
	attack_settings.shadow_color = Color(0.0, 0.0, 0.0, 0.8)
	attack_settings.shadow_offset = Vector2(5, 5)
	attack_label.label_settings = attack_settings
	title_container.add_child(attack_label)

	# Play button — hidden initially
	_play_button = Button.new()
	_play_button.text = "PLAY"
	_play_button.position = Vector2(210, 1050)
	_play_button.size = Vector2(300, 80)
	_play_button.add_theme_font_size_override("font_size", 36)
	_play_button.modulate.a = 0.0

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.85, 0.15, 0.15)
	btn_normal.corner_radius_top_left = 12
	btn_normal.corner_radius_top_right = 12
	btn_normal.corner_radius_bottom_left = 12
	btn_normal.corner_radius_bottom_right = 12
	btn_normal.border_width_left = 3
	btn_normal.border_width_right = 3
	btn_normal.border_width_top = 3
	btn_normal.border_width_bottom = 3
	btn_normal.border_color = Color(1.0, 1.0, 1.0)
	_play_button.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := btn_normal.duplicate()
	btn_hover.bg_color = Color(1.0, 0.2, 0.2)
	_play_button.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed := btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.65, 0.1, 0.1)
	_play_button.add_theme_stylebox_override("pressed", btn_pressed)

	_play_button.add_theme_color_override("font_color", Color.WHITE)
	_play_button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))
	_play_button.pressed.connect(_on_play_pressed)
	title_container.add_child(_play_button)

# ─────────────────────────────────────────────────────────
#  DART ANIMATION
# ─────────────────────────────────────────────────────────

func _animate_darts() -> void:
	# Hit positions — offset so the dart tip lands near the bullseye
	# With the new dramatic angle, the barrel hangs mostly downward from the tip
	var hit_positions: Array[Vector3] = [
		Vector3(0.03, 0.84, 0.21),
		Vector3(-0.02, 0.82, 0.20),
		Vector3(0.01, 0.83, 0.20),
	]

	# Dart direction: 80deg from camera for dramatic full-profile view
	# Shows the full barrel length — TV-style close-up appearance
	var dart_direction := Vector3(0.0, -0.971, -0.239)

	var start_pos := Vector3(0.0, 1.5, 9.0)

	# Stagger timings — builds anticipation with increasing gaps
	var delays := [0.5, 1.1, 2.0]

	for i in range(3):
		var dart := Dart.create(0, DartData.Character.DAI)  # Brass — visible against dark board
		dart.freeze = true
		dart.visual_scale = 2.5
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
