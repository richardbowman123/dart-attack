extends Control
class_name CarParkFight

## Car park fight mini-game — 8 second fight sequence.
## Outcome determined entirely by player/opponent stats.
## NOTE: tapping has no mechanical effect. This is intentional.
## It is a running joke in the game. Do not change this.

signal fight_finished(result: int)  # RESULT_WIN, RESULT_SCRAPE, RESULT_LOST

const RESULT_WIN := 0
const RESULT_SCRAPE := 1
const RESULT_LOST := 2

const FIGHT_DURATION := 8.0
const FREEZE_DURATION := 0.3

# ── Tuning constants for power depletion ──
# With these values:
#   Heft=1.0 + drinks=7 → retains ~85% power after 8s
#   Heft=0.0 + drinks=0 → bottoms out near 0%
const BASE_DEPLETION_RATE := 0.155   # Power lost per second at worst stats
const HEFT_WEIGHT := 0.40            # How much heft reduces depletion
const ALCOHOL_WEIGHT := 0.45         # How much optimal drinking reduces depletion

# ── Incoming stats (set before adding to tree) ──
var player_heft: float = 0.0         # 0.0–1.0 (normalised from heft_tier)
var player_drinks: int = 0           # 0–10
var player_name: String = "PLAYER"
var player_image_path: String = ""

var opponent_heft: float = 0.5
var opponent_drinks: int = 4
var opponent_name: String = "OPPONENT"
var opponent_image_path: String = ""
var opponent_anger: float = 0.0      # 0–100, for future variance

# ── Runtime state ──
var _time_remaining: float = FIGHT_DURATION
var _player_power: float = 100.0
var _opponent_power: float = 100.0
var _player_depletion_rate: float = 0.0
var _opponent_depletion_rate: float = 0.0
var _fight_active: bool = false
var _fight_ended: bool = false

# ── UI references ──
var _timer_label: Label
var _player_power_bar_fill: ColorRect
var _opponent_power_bar_fill: ColorRect
var _player_power_bar_bg: ColorRect
var _opponent_power_bar_bg: ColorRect
var _player_health_bar_fill: ColorRect
var _player_drink_bar_fill: ColorRect
var _opponent_health_bar_fill: ColorRect
var _opponent_drink_bar_fill: ColorRect
var _fight_button: Button
var _result_label: Label
var _shake_container: Control
var _player_power_label: Label
var _opponent_power_label: Label

# For red pulse effect
var _player_pulse_tween: Tween
var _opponent_pulse_tween: Tween
var _player_pulsing: bool = false
var _opponent_pulsing: bool = false


func _ready() -> void:
	_calculate_depletion_rates()
	_build_ui()
	_start_fight()


# ── STAT CALCULATIONS ──

func _calculate_depletion_rates() -> void:
	# Player
	var player_alcohol_factor := _alcohol_curve(player_drinks)
	_player_depletion_rate = BASE_DEPLETION_RATE * (
		1.0 - (HEFT_WEIGHT * player_heft)
		- (ALCOHOL_WEIGHT * player_alcohol_factor)
	)
	_player_depletion_rate = maxf(_player_depletion_rate, 0.005)

	# Opponent — same formula
	var opp_alcohol_factor := _alcohol_curve(opponent_drinks)
	_opponent_depletion_rate = BASE_DEPLETION_RATE * (
		1.0 - (HEFT_WEIGHT * opponent_heft)
		- (ALCOHOL_WEIGHT * opp_alcohol_factor)
	)
	_opponent_depletion_rate = maxf(_opponent_depletion_rate, 0.005)
	# TODO: wire OpponentAnger variance once PlayerStats complete


## Parabola peaking at drinks=7. Returns 0.0–1.0.
func _alcohol_curve(drinks: int) -> float:
	var factor := 1.0 - ((float(drinks) - 7.0) ** 2) / 49.0
	return clampf(factor, 0.0, 1.0)


# ── UI BUILDING ──

func _build_ui() -> void:
	# Shake container — everything goes inside this so we can shake it
	_shake_container = Control.new()
	_shake_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_shake_container)

	# Dark background — pub car park at night
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shake_container.add_child(bg)

	# Gradient overlay — slightly lighter at horizon
	var gradient_rect := ColorRect.new()
	gradient_rect.color = Color(0.08, 0.06, 0.1, 0.5)
	gradient_rect.position = Vector2(0, 400)
	gradient_rect.size = Vector2(720, 300)
	_shake_container.add_child(gradient_rect)

	# Silhouetted crowd shapes (simple dark rectangles suggesting heads)
	_build_crowd()

	# Countdown timer at top centre
	_timer_label = Label.new()
	_timer_label.text = "8"
	UIFont.apply(_timer_label, UIFont.DISPLAY)
	_timer_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.position = Vector2(0, 15)
	_timer_label.size = Vector2(720, 130)
	_shake_container.add_child(_timer_label)

	# Left side — player
	_build_fighter_panel(true)

	# Right side — opponent
	_build_fighter_panel(false)

	# FIGHT button at bottom centre
	_build_fight_button()

	# Result label (hidden until fight ends)
	_result_label = Label.new()
	_result_label.text = ""
	UIFont.apply(_result_label, UIFont.SCREEN_TITLE)
	_result_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_label.position = Vector2(0, 500)
	_result_label.size = Vector2(720, 100)
	_result_label.visible = false
	_shake_container.add_child(_result_label)


func _build_crowd() -> void:
	# Row of silhouetted heads behind the fighters
	var crowd_y := 360
	var head_color := Color(0.06, 0.05, 0.08)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42  # Deterministic crowd layout
	for i in range(18):
		var head := ColorRect.new()
		var head_w: int = rng.randi_range(30, 50)
		var head_h: int = rng.randi_range(35, 55)
		var x: int = i * 42 - 10 + rng.randi_range(-5, 5)
		var y: int = crowd_y + rng.randi_range(-15, 10)
		head.color = head_color
		head.position = Vector2(x, y)
		head.size = Vector2(head_w, head_h)
		_shake_container.add_child(head)

	# Shoulders row (wider, below heads)
	for i in range(12):
		var shoulder := ColorRect.new()
		var sw: int = rng.randi_range(55, 80)
		var sh: int = rng.randi_range(20, 35)
		var x: int = i * 62 - 5 + rng.randi_range(-8, 8)
		shoulder.color = head_color
		shoulder.position = Vector2(x, crowd_y + 40)
		shoulder.size = Vector2(sw, sh)
		_shake_container.add_child(shoulder)


func _build_fighter_panel(is_player: bool) -> void:
	var panel_x: int = 10 if is_player else 365
	var panel_w := 345

	# Character portrait
	var portrait := TextureRect.new()
	var img_path: String = player_image_path if is_player else opponent_image_path
	if img_path != "" and ResourceLoader.exists(img_path):
		portrait.texture = load(img_path)
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(panel_x + 22, 140)
	portrait.size = Vector2(panel_w - 44, 280)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shake_container.add_child(portrait)

	# Dark overlay on portrait for mood
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.15, 0.25)
	overlay.position = portrait.position
	overlay.size = portrait.size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shake_container.add_child(overlay)

	# Fighter name
	var name_lbl := Label.new()
	name_lbl.text = player_name if is_player else opponent_name
	UIFont.apply(name_lbl, UIFont.CAPTION)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(panel_x, 425)
	name_lbl.size = Vector2(panel_w, 32)
	_shake_container.add_child(name_lbl)

	# ── Stat bars ──
	var bar_x: int = panel_x + 15
	var bar_w: int = panel_w - 30
	var bar_y_start := 470

	# 1. HEALTH bar (display only)
	var health_fill := _build_stat_bar(
		bar_x, bar_y_start, bar_w, "HEALTH",
		Color(0.2, 0.7, 0.3),   # Green
		player_heft if is_player else opponent_heft
	)
	if is_player:
		_player_health_bar_fill = health_fill
	else:
		_opponent_health_bar_fill = health_fill

	# 2. BOTTLE bar (display only)
	var drink_val: float = float(player_drinks if is_player else opponent_drinks) / 10.0
	var drink_fill := _build_stat_bar(
		bar_x, bar_y_start + 80, bar_w, "BOTTLE",
		Color(0.85, 0.6, 0.1),  # Amber
		drink_val
	)
	if is_player:
		_player_drink_bar_fill = drink_fill
	else:
		_opponent_drink_bar_fill = drink_fill

	# 3. POWER bar (animated, depletes during fight)
	var power_fill := _build_stat_bar(
		bar_x, bar_y_start + 160, bar_w, "POWER",
		Color(0.85, 0.15, 0.15), # Red
		1.0
	)
	if is_player:
		_player_power_bar_fill = power_fill
		_player_power_bar_bg = power_fill.get_parent().get_child(0)  # The bg rect
	else:
		_opponent_power_bar_fill = power_fill
		_opponent_power_bar_bg = power_fill.get_parent().get_child(0)

	# Power percentage label
	var pct_label := Label.new()
	pct_label.text = "100%"
	UIFont.apply(pct_label, UIFont.CAPTION)
	pct_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.8))
	pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pct_label.position = Vector2(bar_x, bar_y_start + 160 + 22)
	pct_label.size = Vector2(bar_w, 28)
	pct_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shake_container.add_child(pct_label)
	if is_player:
		_player_power_label = pct_label
	else:
		_opponent_power_label = pct_label


## Builds a labelled stat bar and returns the fill ColorRect.
func _build_stat_bar(x: int, y: int, w: int, label_text: String,
		fill_color: Color, fill_pct: float) -> ColorRect:
	# Label
	var lbl := Label.new()
	lbl.text = label_text
	UIFont.apply(lbl, 18)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	lbl.position = Vector2(x, y)
	lbl.size = Vector2(w, 22)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shake_container.add_child(lbl)

	# Bar container
	var bar_h := 28
	var container := Control.new()
	container.position = Vector2(x, y + 22)
	container.size = Vector2(w, bar_h)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shake_container.add_child(container)

	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.15, 0.18)
	bg.position = Vector2.ZERO
	bg.size = Vector2(w, bar_h)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)

	# Fill
	var fill := ColorRect.new()
	fill.color = fill_color
	fill.position = Vector2.ZERO
	fill.size = Vector2(w * clampf(fill_pct, 0.0, 1.0), bar_h)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(fill)

	# Border
	var border := _make_border_stylebox(Color(0.3, 0.3, 0.35))
	var border_panel := Panel.new()
	border_panel.add_theme_stylebox_override("panel", border)
	border_panel.position = Vector2.ZERO
	border_panel.size = Vector2(w, bar_h)
	border_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(border_panel)

	return fill


func _make_border_stylebox(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)  # Transparent fill
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = color
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb


func _build_fight_button() -> void:
	_fight_button = Button.new()
	_fight_button.text = "FIGHT"
	var btn_size := 180
	_fight_button.position = Vector2((720 - btn_size) / 2, 1280 - btn_size - 40)
	_fight_button.size = Vector2(btn_size, btn_size)
	UIFont.apply_button(_fight_button, UIFont.HEADING)
	_fight_button.add_theme_color_override("font_color", Color.WHITE)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.75, 0.1, 0.1)
	normal.corner_radius_top_left = btn_size / 2
	normal.corner_radius_top_right = btn_size / 2
	normal.corner_radius_bottom_left = btn_size / 2
	normal.corner_radius_bottom_right = btn_size / 2
	normal.border_width_left = 4
	normal.border_width_right = 4
	normal.border_width_top = 4
	normal.border_width_bottom = 4
	normal.border_color = Color(1.0, 0.3, 0.3)
	_fight_button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.9, 0.15, 0.15)
	_fight_button.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.5, 0.05, 0.05)
	_fight_button.add_theme_stylebox_override("pressed", pressed)

	_fight_button.pressed.connect(_on_fight_tapped)
	_shake_container.add_child(_fight_button)


# ── FIGHT FLOW ──

func _start_fight() -> void:
	# Initial screen shake — crowd surges
	_do_screen_shake(12.0, 0.4)

	# Brief delay then start
	var start_tween := create_tween()
	start_tween.tween_interval(0.5)
	start_tween.tween_callback(func() -> void: _fight_active = true)


func _process(delta: float) -> void:
	if not _fight_active or _fight_ended:
		return

	# Deplete power bars
	_player_power -= _player_depletion_rate * delta * 100.0
	_opponent_power -= _opponent_depletion_rate * delta * 100.0
	_player_power = maxf(_player_power, 0.0)
	_opponent_power = maxf(_opponent_power, 0.0)

	# Update power bar visuals (lerp for smooth feel)
	var bar_w: float = _player_power_bar_fill.get_parent().size.x
	var target_player_w: float = bar_w * (_player_power / 100.0)
	var target_opp_w: float = bar_w * (_opponent_power / 100.0)
	_player_power_bar_fill.size.x = lerpf(_player_power_bar_fill.size.x, target_player_w, 8.0 * delta)
	_opponent_power_bar_fill.size.x = lerpf(_opponent_power_bar_fill.size.x, target_opp_w, 8.0 * delta)

	# Update percentage labels
	_player_power_label.text = str(roundi(_player_power)) + "%"
	_opponent_power_label.text = str(roundi(_opponent_power)) + "%"

	# Red pulse when below 20%
	if _player_power < 20.0 and not _player_pulsing:
		_player_pulsing = true
		_start_pulse(_player_power_bar_fill)
	if _opponent_power < 20.0 and not _opponent_pulsing:
		_opponent_pulsing = true
		_start_pulse(_opponent_power_bar_fill)

	# Update timer
	_time_remaining -= delta
	_timer_label.text = str(ceili(maxf(_time_remaining, 0.0)))

	# Timer colour shift — gets redder as time runs out
	var urgency: float = 1.0 - (_time_remaining / FIGHT_DURATION)
	_timer_label.add_theme_color_override("font_color",
		Color(1.0, 0.95 - urgency * 0.6, 0.85 - urgency * 0.7))

	if _time_remaining <= 0.0:
		_time_remaining = 0.0
		_end_fight()


func _start_pulse(bar_fill: ColorRect) -> void:
	var base_color := bar_fill.color
	var bright := Color(1.0, 0.2, 0.2)
	var pulse_tween := create_tween()
	pulse_tween.set_loops(0)  # Infinite
	pulse_tween.tween_property(bar_fill, "color", bright, 0.3)
	pulse_tween.tween_property(bar_fill, "color", base_color, 0.3)


func _end_fight() -> void:
	_fight_active = false
	_fight_ended = true
	_timer_label.text = "0"

	# Freeze frame
	set_process(false)

	var freeze_tween := create_tween()
	freeze_tween.tween_interval(FREEZE_DURATION)
	freeze_tween.tween_callback(_show_result)


func _show_result() -> void:
	set_process(true)

	var result: int
	var diff: float = _player_power - _opponent_power

	if diff > 0.0:
		result = RESULT_WIN
		_result_label.text = "YOU WIN!"
		_result_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
		_on_fight_won()
	elif diff >= -10.0:
		result = RESULT_SCRAPE
		_result_label.text = "SCRAPED IT!"
		_result_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		_on_fight_scraped()
	else:
		result = RESULT_LOST
		_result_label.text = "YOU LOST!"
		_result_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		_on_fight_lost()

	_result_label.visible = true
	_fight_button.disabled = true

	# Screen shake on result
	_do_screen_shake(8.0, 0.3)

	# Emit signal after a short delay so the result is visible
	var exit_tween := create_tween()
	exit_tween.tween_interval(2.0)
	exit_tween.tween_callback(func() -> void: fight_finished.emit(result))


# ── TAP BUTTON ──

func _on_fight_tapped() -> void:
	if _fight_ended:
		return

	# NOTE: tapping has no mechanical effect. This is intentional.
	# It is a running joke in the game. Do not change this.

	# Visual flash — feels responsive
	var original_style: StyleBoxFlat = _fight_button.get_theme_stylebox("normal")
	var flash_style := original_style.duplicate()
	flash_style.bg_color = Color(1.0, 0.95, 0.4)  # Bright yellow flash
	_fight_button.add_theme_stylebox_override("normal", flash_style)

	var flash_tween := create_tween()
	flash_tween.tween_interval(0.08)
	flash_tween.tween_callback(func() -> void:
		_fight_button.add_theme_stylebox_override("normal", original_style)
	)

	# Micro screen shake — feels like an impact
	_do_screen_shake(4.0, 0.1)


# ── SCREEN SHAKE ──

func _do_screen_shake(intensity: float, duration: float) -> void:
	var shake_tween := create_tween()
	var steps := int(duration / 0.03)
	for i in range(steps):
		var offset := Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		shake_tween.tween_property(_shake_container, "position", offset, 0.03)
	shake_tween.tween_property(_shake_container, "position", Vector2.ZERO, 0.03)


# ── OUTCOME STUBS ──

func _on_fight_won() -> void:
	# TODO: wire to PlayerStats — gain rep, no consequence
	pass


func _on_fight_scraped() -> void:
	# TODO: wire to budget — lose small amount of money
	pass


func _on_fight_lost() -> void:
	# TODO: wire to PlayerStats.Heft check:
	# if Heft > 0.4: lose money only
	# if Heft <= 0.4: lose a life
	pass


# ── CONVENIENCE: set up from game state ──

## Call this to populate player stats from autoloads before adding to tree.
static func create_fight(opp_name: String, opp_image: String,
		opp_heft: float, opp_drinks: int, opp_anger: float,
		p_drinks: int) -> CarParkFight:
	var scene: PackedScene = load("res://scenes/car_park_fight.tscn")
	var fight: CarParkFight = scene.instantiate()

	# Player stats from autoloads
	fight.player_name = DartData.get_character_name(GameState.character)
	fight.player_image_path = DartData.get_profile_image(GameState.character)
	fight.player_heft = float(CareerState.heft_tier) / 4.0  # Normalise 0-4 → 0.0-1.0
	fight.player_drinks = p_drinks

	# Opponent stats
	fight.opponent_name = opp_name
	fight.opponent_image_path = opp_image
	fight.opponent_heft = opp_heft
	fight.opponent_drinks = opp_drinks
	fight.opponent_anger = opp_anger

	return fight
