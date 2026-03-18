extends Node

## PlayerStats — autoload singleton for gameplay-affecting stats.
##
## Persistent stats (skill, heft, confidence, player_anger) are saved to disk
## and survive across sessions. Match-scoped stats (opponent_anger) reset at the
## start of each match and are never persisted.
##
## All stats use a 1–5 star rating (floats, so 2.7 stars is valid).
## Use the set_*() methods to change values — they clamp and emit the signal.

signal stats_changed(stat_name: String, new_value: float)

const SAVE_PATH := "user://player_stats.json"
const STAR_MIN := 1.0
const STAR_MAX := 5.0

# ── Persistent stats (saved to disk) ──────────────────────────────────────────
var skill: float = 1.0          # Increases through rounds played / won
var heft: float = 1.0           # Only granted by explicit game events (food, etc.)
var confidence: float = 3.0     # Boosted by celebrations / bling, dropped by losses
var player_anger: float = 1.0   # Driven by drinks level + margin of loss

# ── Match-scoped stat (not persisted) ─────────────────────────────────────────
var opponent_anger: float = 1.0 # Driven by player celebrations + opponent losing

# ── Debug overlay (debug builds only) ─────────────────────────────────────────
var _debug_overlay: CanvasLayer
var _debug_labels: Dictionary = {}

# ──────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ──────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	load_stats()
	if OS.is_debug_build():
		_build_debug_overlay()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_stats()

func _unhandled_input(event: InputEvent) -> void:
	if not _debug_overlay:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_debug_overlay.visible = not _debug_overlay.visible

# ──────────────────────────────────────────────────────────────────────────────
# Setters — clamp to 1.0–5.0 stars and emit stats_changed
# ──────────────────────────────────────────────────────────────────────────────

func set_skill(value: float) -> void:
	skill = clampf(value, STAR_MIN, STAR_MAX)
	stats_changed.emit("skill", skill)

func set_heft(value: float) -> void:
	heft = clampf(value, STAR_MIN, STAR_MAX)
	stats_changed.emit("heft", heft)

func set_confidence(value: float) -> void:
	confidence = clampf(value, STAR_MIN, STAR_MAX)
	stats_changed.emit("confidence", confidence)

func set_player_anger(value: float) -> void:
	player_anger = clampf(value, STAR_MIN, STAR_MAX)
	stats_changed.emit("player_anger", player_anger)

func set_opponent_anger(value: float) -> void:
	opponent_anger = clampf(value, STAR_MIN, STAR_MAX)
	stats_changed.emit("opponent_anger", opponent_anger)

# ──────────────────────────────────────────────────────────────────────────────
# Match lifecycle
# ──────────────────────────────────────────────────────────────────────────────

## Resets match-scoped stats without touching persisted stats.
## Call this at the start of every new match.
func reset_match_stats() -> void:
	set_opponent_anger(STAR_MIN)

# ──────────────────────────────────────────────────────────────────────────────
# Persistence (FileAccess + JSON)
# ──────────────────────────────────────────────────────────────────────────────

## Save persistent stats to user://player_stats.json.
## Called automatically on app close / mobile pause, and can be called manually.
func save_stats() -> void:
	var data := {
		"skill": skill,
		"heft": heft,
		"confidence": confidence,
		"player_anger": player_anger,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

## Load persistent stats from disk. Called once in _ready().
func load_stats() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	if not json.data is Dictionary:
		return
	var data: Dictionary = json.data
	skill = clampf(data.get("skill", 1.0), STAR_MIN, STAR_MAX)
	heft = clampf(data.get("heft", 1.0), STAR_MIN, STAR_MAX)
	confidence = clampf(data.get("confidence", 3.0), STAR_MIN, STAR_MAX)
	player_anger = clampf(data.get("player_anger", 1.0), STAR_MIN, STAR_MAX)

# ──────────────────────────────────────────────────────────────────────────────
# Star display helper
# ──────────────────────────────────────────────────────────────────────────────

## Returns a string like "⭐⭐⭐——" for a star value.
## Rounds to the nearest whole star for the visual; exact value shown separately.
func _stars_visual(value: float) -> String:
	var filled := clampi(roundi(value), 1, 5)
	var empty := 5 - filled
	var result := ""
	for i in range(filled):
		result += "⭐"
	for i in range(empty):
		result += "—"
	return result

# ──────────────────────────────────────────────────────────────────────────────
# Debug overlay (F3 to toggle, debug builds only)
# ──────────────────────────────────────────────────────────────────────────────

func _build_debug_overlay() -> void:
	_debug_overlay = CanvasLayer.new()
	_debug_overlay.layer = 100
	_debug_overlay.visible = false
	add_child(_debug_overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(8, 8)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title := Label.new()
	title.text = "PLAYER STATS [F3]"
	UIFont.apply(title, UIFont.CAPTION)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var stat_names := ["skill", "heft", "confidence", "player_anger", "opponent_anger"]
	for stat_name in stat_names:
		var lbl := Label.new()
		UIFont.apply(lbl, UIFont.CAPTION)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(lbl)
		_debug_labels[stat_name] = lbl

	panel.add_child(vbox)
	_debug_overlay.add_child(panel)

	stats_changed.connect(_on_stats_changed_debug)
	_refresh_debug_labels()

func _on_stats_changed_debug(_stat_name: String, _new_value: float) -> void:
	_refresh_debug_labels()

func _refresh_debug_labels() -> void:
	if _debug_labels.is_empty():
		return
	_debug_labels["skill"].text = "Skill  %s" % _stars_visual(skill)
	_debug_labels["heft"].text = "Heft   %s" % _stars_visual(heft)
	_debug_labels["confidence"].text = "Conf   %s" % _stars_visual(confidence)
	_debug_labels["player_anger"].text = "P.Ang  %s" % _stars_visual(player_anger)
	_debug_labels["opponent_anger"].text = "O.Ang  %s" % _stars_visual(opponent_anger)
