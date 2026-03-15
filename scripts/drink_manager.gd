extends Node

## DrinkManager — autoload that tracks the player's drink level (0–10)
## and drives the drunk vision shader overlay.
##
## The visual effect uses a CanvasLayer (layer 10) with a full-screen
## ColorRect running a canvas_item shader. This sits above all game UI
## without touching any existing scene nodes.
##
## Usage:
##   DrinkManager.add_drink(true)       # Free drink (companion buys), 1 unit
##   DrinkManager.add_drink(false)      # Purchased half pint (1 unit)
##   DrinkManager.add_drink(false, 2)   # Purchased full pint (2 units)
##   DrinkManager.reset()               # Call at match start

# TODO: wire to PlayerStats.Heft — high Heft means drinks above 5
# count for less visually. Implement in _update_targets() by computing
# an effective drinks level before the tier mapping:
#   var effective := float(drinks_level)
#   if effective > 5.0:
#       var heft_norm := (PlayerStats.heft - 1.0) / 4.0  # 0.0 to 1.0
#       effective = 5.0 + (effective - 5.0) * (1.0 - heft_norm * 0.5)
# Heft 1 star: no reduction. Heft 5 stars: each drink above 5 counts
# as half for visual effects. Pass-out is still based on actual
# drinks_level (13), not effective — you still pass out, you just
# handle your drink better on the way there.

# TODO: wire to PlayerStats.PlayerAnger — high PlayerAnger
# should increase sway_speed independently of drinks level,
# representing agitation rather than intoxication.

signal drinks_changed(level: int)
signal warning_triggered(message: String)
signal passed_out

const MAX_DRINKS := 13
const COST_PER_UNIT := 340  # Pence — £3.40 per half-pint unit

var drinks_level: int = 0

## Placeholder budget in pence — will be wired to CareerState.money later
var _budget: int = 5000

# ── Shader overlay ───────────────────────────────────────────────────────────
var _canvas_layer: CanvasLayer
var _rect: ColorRect
var _warning_label: Label
var _warning_tween: Tween

# ── Current smoothed shader values ───────────────────────────────────────────
var _current_blur: float = 0.0
var _current_double_vision: float = 0.0
var _current_sway_amount: float = 0.0
var _current_sway_speed: float = 1.0
var _current_vignette: float = 0.0
var _current_warmth: float = 0.0

# ── Target shader values (derived from drinks_level) ────────────────────────
var _target_blur: float = 0.0
var _target_double_vision: float = 0.0
var _target_sway_amount: float = 0.0
var _target_sway_speed: float = 1.0
var _target_vignette: float = 0.0
var _target_warmth: float = 0.0


func _ready() -> void:
	_build_overlay()
	_build_warning_label()


func _build_overlay() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 10
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = ShaderMaterial.new()
	_rect.material.shader = preload("res://shaders/drunk.gdshader")
	_rect.visible = false  # Hidden when sober — saves GPU
	_canvas_layer.add_child(_rect)
	add_child(_canvas_layer)


func _build_warning_label() -> void:
	_warning_label = Label.new()
	UIFont.apply(_warning_label, UIFont.BODY)
	_warning_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_warning_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	_warning_label.add_theme_constant_override("shadow_offset_x", 2)
	_warning_label.add_theme_constant_override("shadow_offset_y", 2)
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Top third of 720x1280 viewport, centred horizontally
	_warning_label.position = Vector2(40, 300)
	_warning_label.size = Vector2(640, 120)
	_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning_label.visible = false
	_canvas_layer.add_child(_warning_label)


# ── Public API ───────────────────────────────────────────────────────────────

## Add drinks. free=true means no cost deducted.
## amount: 1 = half pint, 2 = full pint.
## Returns true if drink was added, false if at max or can't afford.
func add_drink(free: bool = false, amount: int = 1) -> bool:
	if drinks_level >= MAX_DRINKS:
		return false

	var cost := amount * COST_PER_UNIT
	if not free:
		if _budget < cost:
			return false
		_budget -= cost

	var old_level := drinks_level
	drinks_level = mini(drinks_level + amount, MAX_DRINKS)
	_update_targets()
	drinks_changed.emit(drinks_level)

	# Warning text — trigger only when crossing a threshold
	if old_level < 13 and drinks_level >= 13:
		warning_triggered.emit("Lights out...")
		_show_warning("Lights out...")
		passed_out.emit()
	elif old_level < 9 and drinks_level >= 9:
		warning_triggered.emit("If you start to think you're a state, you definitely are.")
		_show_warning("If you start to think you're a state, you definitely are.")
	elif old_level < 7 and drinks_level >= 7:
		warning_triggered.emit("Take it easy mate...")
		_show_warning("Take it easy mate...")

	return true


## Visual effect intensity (0.0–1.0) — kept for compatibility with drink_test.
func get_effect_intensity() -> float:
	if drinks_level <= 3:
		return 0.0
	return clampf(float(drinks_level - 3) / 10.0, 0.0, 1.0)


## Returns the current tier name based on drinks level.
## Empty string for sober (0–3).
func get_tier_name() -> String:
	if drinks_level <= 3:
		return ""
	elif drinks_level <= 6:
		return "TIPSY"
	elif drinks_level <= 8:
		return "DRUNK"
	elif drinks_level <= 10:
		return "HAMMERED"
	elif drinks_level <= 12:
		return "ABSOLUTELY WRECKED"
	else:
		return "PASSED OUT"


## Flash the current tier name on screen. Called at the start of each
## player visit by MatchManager. Does nothing if sober (drinks 0–3).
func flash_tier_name() -> void:
	var tier := get_tier_name()
	if tier == "":
		return
	if _warning_tween and _warning_tween.is_valid():
		_warning_tween.kill()
	_warning_label.text = tier
	_warning_label.modulate.a = 0.0
	_warning_label.visible = true
	_warning_tween = create_tween()
	_warning_tween.tween_property(_warning_label, "modulate:a", 1.0, 0.2)
	_warning_tween.tween_interval(1.0)
	_warning_tween.tween_property(_warning_label, "modulate:a", 0.0, 0.3)
	_warning_tween.tween_callback(func() -> void: _warning_label.visible = false)


## Set drinks level directly (for testing / UI sliders).
## Triggers visual update and warnings when crossing thresholds.
func set_level(level: int) -> void:
	var old_level := drinks_level
	drinks_level = clampi(level, 0, MAX_DRINKS)
	_update_targets()
	drinks_changed.emit(drinks_level)
	if old_level < 13 and drinks_level >= 13:
		warning_triggered.emit("Lights out...")
		_show_warning("Lights out...")
		passed_out.emit()
	elif old_level < 9 and drinks_level >= 9:
		warning_triggered.emit("If you start to think you're a state, you definitely are.")
		_show_warning("If you start to think you're a state, you definitely are.")
	elif old_level < 7 and drinks_level >= 7:
		warning_triggered.emit("Take it easy mate...")
		_show_warning("Take it easy mate...")


## Reset to sober — call at match start
func reset() -> void:
	drinks_level = 0
	_budget = 5000
	_update_targets()
	drinks_changed.emit(drinks_level)


# ── Target mapping from drinks_level ────────────────────────────────────────

func _update_targets() -> void:
	var d := drinks_level
	if d <= 3:
		_target_blur = 0.0
		_target_double_vision = 0.0
		_target_sway_amount = 0.0
		_target_sway_speed = 1.0
		_target_vignette = 0.0
		_target_warmth = 0.0
	elif d <= 6:
		var t := float(d - 3) / 3.0
		_target_blur = lerpf(0.0, 0.3, t)
		_target_double_vision = lerpf(0.0, 0.3, t)
		_target_sway_amount = 0.0
		_target_sway_speed = 1.0
		_target_vignette = lerpf(0.0, 0.2, t)
		_target_warmth = lerpf(0.0, 0.3, t)
	elif d <= 8:
		var t := float(d - 6) / 2.0
		_target_blur = lerpf(0.3, 0.6, t)
		_target_double_vision = lerpf(0.3, 0.6, t)
		_target_sway_amount = lerpf(0.0, 0.4, t)
		_target_sway_speed = 1.5
		_target_vignette = lerpf(0.2, 0.5, t)
		_target_warmth = lerpf(0.3, 0.5, t)
	elif d <= 10:
		var t := float(d - 8) / 2.0
		_target_blur = lerpf(0.6, 0.9, t)
		_target_double_vision = lerpf(0.6, 0.85, t)
		_target_sway_amount = lerpf(0.4, 0.8, t)
		_target_sway_speed = 2.5
		_target_vignette = lerpf(0.5, 0.8, t)
		_target_warmth = lerpf(0.5, 0.6, t)
	elif d <= 12:
		var t := float(d - 10) / 2.0
		_target_blur = lerpf(0.9, 1.0, t)
		_target_double_vision = lerpf(0.85, 1.0, t)
		_target_sway_amount = lerpf(0.8, 1.0, t)
		_target_sway_speed = 3.0
		_target_vignette = lerpf(0.8, 0.95, t)
		_target_warmth = lerpf(0.6, 0.7, t)
	else:  # 13 — passed out
		_target_blur = 1.0
		_target_double_vision = 1.0
		_target_sway_amount = 1.0
		_target_sway_speed = 3.5
		_target_vignette = 1.0
		_target_warmth = 0.7


# ── Smooth transitions in _process ──────────────────────────────────────────

func _process(delta: float) -> void:
	_current_blur = _smooth(_current_blur, _target_blur, delta)
	_current_double_vision = _smooth(_current_double_vision, _target_double_vision, delta)
	_current_sway_amount = _smooth(_current_sway_amount, _target_sway_amount, delta)
	_current_sway_speed = _smooth(_current_sway_speed, _target_sway_speed, delta)
	_current_vignette = _smooth(_current_vignette, _target_vignette, delta)
	_current_warmth = _smooth(_current_warmth, _target_warmth, delta)

	# Show/hide the overlay to save GPU when sober
	var active := _current_blur > 0.001 or _current_double_vision > 0.001 \
		or _current_sway_amount > 0.001 or _current_vignette > 0.001 \
		or _current_warmth > 0.001
	_rect.visible = active

	if active:
		var mat := _rect.material as ShaderMaterial
		mat.set_shader_parameter("blur_amount", _current_blur)
		mat.set_shader_parameter("double_vision", _current_double_vision)
		mat.set_shader_parameter("sway_amount", _current_sway_amount)
		mat.set_shader_parameter("sway_speed", _current_sway_speed)
		mat.set_shader_parameter("vignette_strength", _current_vignette)
		mat.set_shader_parameter("warmth", _current_warmth)


## Smooth a single value toward its target.
## Onset (increasing) uses delta * 2.0 — settles in ~0.5s.
## Recovery (decreasing) uses delta * 0.5 — settles in ~2s.
func _smooth(current: float, target: float, delta: float) -> float:
	var factor := delta * 2.0 if target > current else delta * 0.5
	return lerpf(current, target, clampf(factor, 0.0, 1.0))


# ── Warning text display ────────────────────────────────────────────────────

func _show_warning(text: String) -> void:
	if _warning_tween and _warning_tween.is_valid():
		_warning_tween.kill()

	_warning_label.text = text
	_warning_label.modulate.a = 0.0
	_warning_label.visible = true

	_warning_tween = create_tween()
	# Fade in 0.3s, hold 2.5s, fade out 0.5s
	_warning_tween.tween_property(_warning_label, "modulate:a", 1.0, 0.3)
	_warning_tween.tween_interval(2.5)
	_warning_tween.tween_property(_warning_label, "modulate:a", 0.0, 0.5)
	_warning_tween.tween_callback(func() -> void: _warning_label.visible = false)
