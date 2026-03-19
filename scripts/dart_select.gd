extends Control

# ─── Carousel layout ───
const TILE_W := 460
const TILE_H := 680
const TILE_GAP := 24
const TILE_STEP := TILE_W + TILE_GAP       # px between tile centres
const TILE_X_OFFSET := 130                  # (720 - TILE_W) / 2
const CAROUSEL_Y := 170
const CAROUSEL_H := 700
const PREVIEW_W := 400
const PREVIEW_H := 380
const PREVIEW_X := 30                       # (TILE_W - PREVIEW_W) / 2
const PREVIEW_Y := 128

# ─── Text data ───
const ACCURACY_LABELS := [
	"Pub standard — wide scatter",
	"Decent grouping — learning to aim",
	"Tight clusters — serious kit",
	"Precision grouping — match ready",
]

const TIER_COSTS := [500, 2000, 8000, 32000]  # £5, £20, £80, £320 (4x exponential)

# ─── Active tile border colours ───
const BORDER_ACTIVE := Color(0.2, 0.75, 0.3)
const BORDER_INACTIVE := Color(0.2, 0.2, 0.28)
const BORDER_ACTIVE_W := 4
const BORDER_INACTIVE_W := 2

# ─── Carousel state ───
var _current_index := 0
var _scroll_x := 0.0
var _target_x := 0.0
var _dragging := false
var _drag_start_screen_x := 0.0
var _drag_start_scroll := 0.0

# ─── Shop mode ───
var _shop_mode := false
var _balance_label: Label
var _leave_btn: Button

# ─── Node references ───
var _carousel: Control
var _dots: Array[ColorRect] = []
var _tile_styles: Array[StyleBoxFlat] = []
var _dart_pivots: Array[Node3D] = []

# ─── View mode (shop) ───
var _viewing_tier: int = -1
var _overlay_refs: Array = []
var _action_refs: Array = []


func _ready() -> void:
	_shop_mode = CareerState.dart_shop_return != ""
	if _shop_mode:
		_current_index = 0
	else:
		_current_index = GameState.dart_tier
	_scroll_x = float(_current_index * TILE_STEP)
	_target_x = _scroll_x
	_build_ui()


# ═══════════════════════════════════════════════════════════
#  UI CONSTRUCTION
# ═══════════════════════════════════════════════════════════

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Title
	var title := Label.new()
	title.text = "DART SHOP" if _shop_mode else "CHOOSE YOUR DARTS"
	UIFont.apply(title, UIFont.HEADING)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 36)
	title.size = Vector2(720, 40)
	add_child(title)

	# Mode label / Balance display
	var mode_label := Label.new()
	if _shop_mode:
		mode_label.text = "Balance: " + _format_price(CareerState.money)
		mode_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.3))
		_balance_label = mode_label
	else:
		var mode_text := ""
		match GameState.game_mode:
			GameState.GameMode.TUTORIAL:
				mode_text = "Tutorial"
			GameState.GameMode.ROUND_THE_CLOCK:
				mode_text = "Round the Clock"
			GameState.GameMode.COUNTDOWN:
				mode_text = str(GameState.starting_score)
		mode_label.text = mode_text
		mode_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	UIFont.apply(mode_label, UIFont.CAPTION)
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.position = Vector2(0, 106)
	mode_label.size = Vector2(720, 24)
	add_child(mode_label)

	# Hint
	var hint := Label.new()
	if _shop_mode:
		hint.text = "Swipe to browse  ·  Tap to buy"
	else:
		hint.text = "Swipe to browse  ·  Tap to play"
	UIFont.apply(hint, UIFont.CAPTION)
	hint.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 145)
	hint.size = Vector2(720, 22)
	add_child(hint)

	# Carousel clip area
	var clip := Control.new()
	clip.clip_contents = true
	clip.position = Vector2(0, CAROUSEL_Y)
	clip.size = Vector2(720, CAROUSEL_H)
	add_child(clip)

	# Carousel container — slides left/right
	_carousel = Control.new()
	_carousel.size = Vector2(float(DartData.TIERS.size() * TILE_STEP + 720), CAROUSEL_H)
	clip.add_child(_carousel)

	for i in range(DartData.TIERS.size()):
		_build_tile(i)

	_build_dots()
	_build_back_button()
	_update_carousel_position()
	_update_indicators()


func _build_tile(tier: int) -> void:
	var data := DartData.get_tier(tier)
	var is_locked := _is_tier_locked(tier)
	var tile_x := float(TILE_X_OFFSET + tier * TILE_STEP)

	# Tile panel
	var tile := Panel.new()
	tile.position = Vector2(tile_x, 10)
	tile.size = Vector2(TILE_W, TILE_H)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12)
	_set_corners(style, 16)
	style.border_width_left = BORDER_INACTIVE_W
	style.border_width_right = BORDER_INACTIVE_W
	style.border_width_top = BORDER_INACTIVE_W
	style.border_width_bottom = BORDER_INACTIVE_W
	style.border_color = BORDER_INACTIVE
	tile.add_theme_stylebox_override("panel", style)
	_carousel.add_child(tile)
	_tile_styles.append(style)

	# ── Dart name ──
	var name_lbl := Label.new()
	name_lbl.text = data["name"].to_upper()
	# Use BODY for long names like "PREMIUM TUNGSTEN" that overflow at SUBHEADING
	var name_font_size: int = UIFont.BODY if data["name"].length() > 14 else UIFont.SUBHEADING
	UIFont.apply(name_lbl, name_font_size)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.position = Vector2(10, 14)
	name_lbl.size = Vector2(TILE_W - 20, 44)
	tile.add_child(name_lbl)

	# ── Weight ──
	var weight_lbl := Label.new()
	weight_lbl.text = data["weight_label"]
	UIFont.apply(weight_lbl, UIFont.BODY)
	weight_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	weight_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weight_lbl.position = Vector2(10, 56)
	weight_lbl.size = Vector2(TILE_W - 20, 26)
	tile.add_child(weight_lbl)

	# ── Accuracy description ──
	var acc_lbl := Label.new()
	acc_lbl.text = ACCURACY_LABELS[tier]
	UIFont.apply(acc_lbl, UIFont.CAPTION)
	acc_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	acc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	acc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	acc_lbl.position = Vector2(20, 86)
	acc_lbl.size = Vector2(TILE_W - 40, 40)
	tile.add_child(acc_lbl)

	# ── 3D dart preview ──
	_build_dart_preview(tile, tier)

	# ── Accuracy bar ──
	var bar_x := 40
	var bar_w := TILE_W - 80
	var bar_y := 530

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.15, 0.15, 0.2)
	bar_bg.position = Vector2(bar_x, bar_y)
	bar_bg.size = Vector2(bar_w, 10)
	tile.add_child(bar_bg)

	var accuracy: float = 1.0 - data["scatter_mult"]
	var bar_fill := ColorRect.new()
	bar_fill.color = Color(0.2, 0.7, 0.3).lerp(Color(1.0, 0.85, 0.2), accuracy)
	bar_fill.position = Vector2(bar_x, bar_y)
	bar_fill.size = Vector2(bar_w * accuracy, 10)
	tile.add_child(bar_fill)

	var bar_label := Label.new()
	bar_label.text = "ACCURACY"
	UIFont.apply(bar_label, UIFont.CAPTION)
	bar_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar_label.position = Vector2(0, bar_y + 16)
	bar_label.size = Vector2(TILE_W, 18)
	tile.add_child(bar_label)

	# ── Lock overlay / Shop overlay ──
	if is_locked:
		var can_afford: bool = _shop_mode and CareerState.money >= TIER_COSTS[tier]

		var overlay := Panel.new()
		overlay.position = Vector2(0, 0)
		overlay.size = Vector2(TILE_W, TILE_H)
		var ov_style := StyleBoxFlat.new()
		ov_style.bg_color = Color(0.0, 0.0, 0.0, 0.5 if can_afford else 0.6)
		_set_corners(ov_style, 16)
		overlay.add_theme_stylebox_override("panel", ov_style)
		tile.add_child(overlay)
		_overlay_refs.append(overlay)

		# Price and action labels as tile children (stay visible when overlay fades)
		var price_lbl := Label.new()
		price_lbl.text = _format_price(TIER_COSTS[tier])
		UIFont.apply(price_lbl, UIFont.SCREEN_TITLE)
		if can_afford:
			price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 0.95))
		else:
			price_lbl.add_theme_color_override("font_color", Color(0.7, 0.6, 0.3, 0.7))
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_lbl.position = Vector2(0, TILE_H * 0.5 - 50)
		price_lbl.size = Vector2(TILE_W, 60)
		tile.add_child(price_lbl)

		var action_lbl := Label.new()
		if _shop_mode:
			action_lbl.text = "TAP TO BUY" if can_afford else "CAN'T AFFORD YET"
			action_lbl.add_theme_color_override("font_color", Color(0.2, 0.85, 0.3, 0.95) if can_afford else Color(0.5, 0.35, 0.3, 0.7))
		else:
			action_lbl.text = "LOCKED"
			action_lbl.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3, 0.85))
		UIFont.apply(action_lbl, UIFont.BODY)
		action_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		action_lbl.position = Vector2(0, TILE_H * 0.5 + 15)
		action_lbl.size = Vector2(TILE_W, 30)
		tile.add_child(action_lbl)
		_action_refs.append(action_lbl)
	elif _shop_mode:
		# Owned tier in shop mode — subtle green "OWNED" badge
		_overlay_refs.append(null)
		_action_refs.append(null)
		var owned_lbl := Label.new()
		owned_lbl.text = "OWNED"
		UIFont.apply(owned_lbl, UIFont.CAPTION)
		owned_lbl.add_theme_color_override("font_color", Color(0.2, 0.75, 0.3, 0.8))
		owned_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		owned_lbl.position = Vector2(0, 592)
		owned_lbl.size = Vector2(TILE_W, 24)
		tile.add_child(owned_lbl)
	else:
		_overlay_refs.append(null)
		_action_refs.append(null)


func _build_dart_preview(tile: Panel, tier: int) -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.position = Vector2(PREVIEW_X, PREVIEW_Y)
	container.size = Vector2(PREVIEW_W, PREVIEW_H)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(PREVIEW_W, PREVIEW_H)
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.physics_object_picking = false
	container.add_child(viewport)

	# Environment — solid bg matching tile colour
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.08, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.35)
	env.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	# Lighting — same three-point setup as dart_viewer
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-30), deg_to_rad(30), 0)
	key.light_energy = 1.8
	key.shadow_enabled = false
	viewport.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-20), deg_to_rad(-40), 0)
	fill.light_energy = 0.6
	fill.shadow_enabled = false
	viewport.add_child(fill)

	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(15), deg_to_rad(180), 0)
	rim.light_energy = 0.8
	rim.shadow_enabled = false
	viewport.add_child(rim)

	# Camera — must be added BEFORE the dart, and set as current
	var data := DartData.get_tier(tier)
	var barrel_len: float = data["barrel_length"]
	var tip_offset: float = barrel_len + Dart.TIP_LENGTH
	var total_length: float = tip_offset + Dart.SHAFT_LENGTH + 0.003 + Dart.FLIGHT_WIDTH
	var mid := total_length / 2.0
	# Dart is centred on pivot, so orbit centre is at the origin
	var orbit_centre := Vector3.ZERO

	var camera := Camera3D.new()
	camera.fov = 45.0
	camera.current = true
	var cam_dist := 0.75
	var cam_pitch := 0.15
	var cam_yaw := 0.05
	camera.position = orbit_centre + Vector3(
		cam_dist * cos(cam_pitch) * sin(cam_yaw),
		cam_dist * sin(cam_pitch),
		cam_dist * cos(cam_pitch) * cos(cam_yaw)
	)
	camera.look_at(orbit_centre)
	viewport.add_child(camera)

	# Dart — tilted at 45 degrees (natural throwing angle)
	var pivot := Node3D.new()
	viewport.add_child(pivot)
	pivot.rotation.x = deg_to_rad(-45)

	var dart := Dart.create(tier, GameState.character)
	# Centre the dart's geometric midpoint at the pivot origin.
	# The dart's geometry ranges from z=-tip_offset (tip end) to
	# z=SHAFT_LENGTH+0.003+FLIGHT_WIDTH (flight trailing edge).
	# Offset by the average to centre it.
	var dart_centre_z := (-tip_offset + Dart.SHAFT_LENGTH + 0.003 + Dart.FLIGHT_WIDTH) / 2.0
	dart.position.z = -dart_centre_z
	dart.freeze = true
	dart.gravity_scale = 0
	pivot.add_child(dart)
	dart.set_physics_process.call_deferred(false)

	_dart_pivots.append(pivot)


func _build_dots() -> void:
	var count := DartData.TIERS.size()
	var dot_size := 10
	var gap := 16
	var total_w := count * dot_size + (count - 1) * gap
	var start_x := (720 - total_w) / 2
	var dot_y := CAROUSEL_Y + CAROUSEL_H + 18

	for i in range(count):
		var dot := ColorRect.new()
		dot.size = Vector2(dot_size, dot_size)
		dot.position = Vector2(start_x + i * (dot_size + gap), dot_y)
		add_child(dot)
		_dots.append(dot)


func _build_back_button() -> void:
	var back_btn := Button.new()
	var needs_darts := _shop_mode and CareerState.dart_tier_owned < 0

	if _shop_mode:
		if needs_darts:
			back_btn.text = "BUY SOME DARTS!"
			back_btn.disabled = true
		else:
			back_btn.text = "LEAVE SHOP"
	else:
		back_btn.text = "BACK"

	back_btn.position = Vector2(200, 940)
	back_btn.size = Vector2(320, 56)
	UIFont.apply_button(back_btn, UIFont.BODY)
	back_btn.add_theme_color_override("font_color", Color.WHITE)

	var style := StyleBoxFlat.new()
	if _shop_mode and not needs_darts:
		style.bg_color = Color(0.12, 0.35, 0.15)
		_set_corners(style, 8)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.2, 0.65, 0.3)
	else:
		style.bg_color = Color(0.15, 0.15, 0.2)
		_set_corners(style, 8)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.3, 0.3, 0.35)
	back_btn.add_theme_stylebox_override("normal", style)

	if needs_darts:
		var disabled_style := style.duplicate()
		disabled_style.bg_color = Color(0.1, 0.1, 0.13)
		disabled_style.border_color = Color(0.2, 0.2, 0.25)
		back_btn.add_theme_stylebox_override("disabled", disabled_style)
		back_btn.add_theme_color_override("font_color_disabled", Color(0.35, 0.35, 0.4))

	var hover := style.duplicate()
	hover.bg_color = style.bg_color * 1.3
	hover.border_color = style.border_color * 1.2
	back_btn.add_theme_stylebox_override("hover", hover)

	back_btn.pressed.connect(_on_back)
	add_child(back_btn)
	_leave_btn = back_btn


# ═══════════════════════════════════════════════════════════
#  INPUT — carousel drag + tap to play
# ═══════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var is_press := false
	var is_release := false
	var is_drag := false

	if event is InputEventScreenTouch:
		pos = event.position
		if event.pressed:
			is_press = true
		else:
			is_release = true
	elif event is InputEventScreenDrag:
		pos = event.position
		is_drag = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		if event.pressed:
			is_press = true
		else:
			is_release = true
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		pos = event.position
		is_drag = true
	else:
		return

	if is_press and pos.y >= CAROUSEL_Y and pos.y <= CAROUSEL_Y + CAROUSEL_H:
		_dragging = true
		_drag_start_screen_x = pos.x
		_drag_start_scroll = _scroll_x
		_consume_input()

	elif is_release and _dragging:
		_dragging = false
		var drag_dist := absf(pos.x - _drag_start_screen_x)
		_consume_input()
		if drag_dist < 12.0:
			_snap_to_nearest()
			if _shop_mode:
				# Shop mode — tap to buy directly
				if _is_tier_locked(_current_index):
					if CareerState.money >= TIER_COSTS[_current_index]:
						_buy_tier(_current_index)
			else:
				# Normal mode — tap to play
				if not _is_tier_locked(_current_index):
					GameState.dart_tier = _current_index
					get_tree().change_scene_to_file("res://scenes/match.tscn")
		else:
			_snap_to_nearest()

	elif is_drag and _dragging:
		var max_scroll := float((DartData.TIERS.size() - 1) * TILE_STEP)
		_scroll_x = clampf(
			_drag_start_scroll - (pos.x - _drag_start_screen_x),
			-float(TILE_STEP) * 0.25,
			max_scroll + float(TILE_STEP) * 0.25
		)
		_update_carousel_position()
		_consume_input()


# ═══════════════════════════════════════════════════════════
#  FRAME UPDATE — smooth snap + dart turntable
# ═══════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if not _dragging:
		_scroll_x = lerpf(_scroll_x, _target_x, minf(delta * 10.0, 1.0))
		if absf(_scroll_x - _target_x) < 0.5:
			_scroll_x = _target_x
		_update_carousel_position()

	# Slow turntable spin
	for pivot in _dart_pivots:
		if is_instance_valid(pivot):
			pivot.rotation.y += delta * 0.5


# ═══════════════════════════════════════════════════════════
#  CAROUSEL HELPERS
# ═══════════════════════════════════════════════════════════

func _snap_to_nearest() -> void:
	var raw := _scroll_x / float(TILE_STEP)
	_current_index = clampi(roundi(raw), 0, DartData.TIERS.size() - 1)
	_target_x = float(_current_index * TILE_STEP)
	if _viewing_tier >= 0 and _viewing_tier != _current_index:
		_exit_view_mode()
	_update_indicators()


func _update_carousel_position() -> void:
	_carousel.position.x = -_scroll_x


func _update_indicators() -> void:
	# Dots
	for i in range(_dots.size()):
		if i == _current_index:
			_dots[i].color = Color(1.0, 0.85, 0.2)
		else:
			_dots[i].color = Color(0.2, 0.2, 0.25)

	# Green border on active tile
	for i in range(_tile_styles.size()):
		if i == _current_index:
			_tile_styles[i].border_color = BORDER_ACTIVE
			_tile_styles[i].border_width_left = BORDER_ACTIVE_W
			_tile_styles[i].border_width_right = BORDER_ACTIVE_W
			_tile_styles[i].border_width_top = BORDER_ACTIVE_W
			_tile_styles[i].border_width_bottom = BORDER_ACTIVE_W
		else:
			_tile_styles[i].border_color = BORDER_INACTIVE
			_tile_styles[i].border_width_left = BORDER_INACTIVE_W
			_tile_styles[i].border_width_right = BORDER_INACTIVE_W
			_tile_styles[i].border_width_top = BORDER_INACTIVE_W
			_tile_styles[i].border_width_bottom = BORDER_INACTIVE_W


func _consume_input() -> void:
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()


func _is_tier_locked(tier: int) -> bool:
	if not CareerState.career_mode_active:
		return false
	return tier > CareerState.dart_tier_owned


func _set_corners(sb: StyleBoxFlat, radius: int) -> void:
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius


# ═══════════════════════════════════════════════════════════
#  ACTIONS
# ═══════════════════════════════════════════════════════════

func _on_back() -> void:
	if _shop_mode:
		var return_scene := CareerState.dart_shop_return
		CareerState.dart_shop_return = ""
		GameState.dart_tier = max(0, CareerState.dart_tier_owned)
		get_tree().change_scene_to_file(return_scene)
	else:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _buy_tier(tier: int) -> void:
	CareerState.money -= TIER_COSTS[tier]
	if tier > CareerState.dart_tier_owned:
		CareerState.dart_tier_owned = tier
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_dots.clear()
	_tile_styles.clear()
	_dart_pivots.clear()
	_overlay_refs.clear()
	_action_refs.clear()
	_carousel = null
	_balance_label = null
	_leave_btn = null
	_viewing_tier = -1
	# Keep scroll position on the same tile
	_scroll_x = float(_current_index * TILE_STEP)
	_target_x = _scroll_x
	_build_ui()


func _enter_view_mode(tier: int) -> void:
	if _viewing_tier >= 0:
		_exit_view_mode()
	_viewing_tier = tier
	if tier < _overlay_refs.size() and _overlay_refs[tier]:
		var tw := create_tween()
		tw.tween_property(_overlay_refs[tier], "modulate:a", 0.08, 0.25)
	if tier < _action_refs.size() and _action_refs[tier]:
		var can_afford: bool = CareerState.money >= TIER_COSTS[tier]
		_action_refs[tier].text = "TAP TO BUY" if can_afford else "CAN'T AFFORD YET"


func _exit_view_mode() -> void:
	if _viewing_tier < 0:
		return
	var tier := _viewing_tier
	if tier < _overlay_refs.size() and _overlay_refs[tier]:
		var tw := create_tween()
		tw.tween_property(_overlay_refs[tier], "modulate:a", 1.0, 0.25)
	if tier < _action_refs.size() and _action_refs[tier]:
		var can_afford: bool = CareerState.money >= TIER_COSTS[tier]
		if _shop_mode:
			_action_refs[tier].text = "TAP TO BUY" if can_afford else "CAN'T AFFORD YET"
			_action_refs[tier].add_theme_color_override("font_color", Color(0.2, 0.85, 0.3, 0.95) if can_afford else Color(0.5, 0.35, 0.3, 0.7))
	_viewing_tier = -1


func _format_price(pence: int) -> String:
	var pounds := int(pence / 100)
	var p := pence % 100
	var p_str: String = str(p) if p >= 10 else "0" + str(p)
	return "£" + str(pounds) + "." + p_str
