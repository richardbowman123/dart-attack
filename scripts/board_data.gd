extends RefCounted
class_name BoardData

# Standard dartboard number sequence (clockwise from top)
const SEGMENT_ORDER: Array[int] = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]

# Radii in game units. Real board is 170mm to double wire outer edge.
# We define BOARD_RADIUS as the outer edge of the scoring area (double ring).
# Everything is expressed as a fraction of that scoring radius.
const BOARD_RADIUS := 2.0

# Ring boundaries as fractions of BOARD_RADIUS
# Based on official BDO/WDF measurements:
#   Inner bull: 6.35mm radius, Outer bull: 16mm, Treble inner: 99mm,
#   Treble outer: 107mm, Double inner: 162mm, Double outer: 170mm
const BULLSEYE_R := 0.037        # 6.35 / 170 — inner bull
const OUTER_BULL_R := 0.094      # 16 / 170 — outer bull
const TREBLE_INNER_R := 0.582    # 99 / 170 — treble ring inner edge
const TREBLE_OUTER_R := 0.629    # 107 / 170 — treble ring outer edge
const DOUBLE_INNER_R := 0.953    # 162 / 170 — double ring inner edge
const DOUBLE_OUTER_R := 1.0      # 170 / 170 — double ring outer edge
const NUMBER_RING_R := 1.12      # where the numbers sit (just outside doubles)
const SURROUND_R := 1.30         # black non-scoring surround

# Colours
const COL_RED := Color(0.78, 0.12, 0.12)
const COL_GREEN := Color(0.05, 0.45, 0.15)
const COL_BLACK := Color(0.08, 0.08, 0.08)
const COL_CREAM := Color(0.95, 0.90, 0.75)
const COL_WIRE := Color(0.75, 0.75, 0.78)
const COL_BULLSEYE := Color(0.78, 0.12, 0.12)
const COL_OUTER_BULL := Color(0.05, 0.45, 0.15)
const COL_BOARD_SURROUND := Color(0.05, 0.05, 0.05)

# Each segment spans 18 degrees (360 / 20)
const SEGMENT_ANGLE := TAU / 20.0

## Returns the score and multiplier for a hit at the given position.
## pos is a Vector2 representing the hit point on the board face,
## where (0,0) is the centre. Returns {"number": int, "multiplier": int, "label": String}
static func get_score(pos: Vector2) -> Dictionary:
	var dist := pos.length() / BOARD_RADIUS
	var angle := pos.angle()

	# Off the board entirely
	if dist > DOUBLE_OUTER_R:
		return {"number": 0, "multiplier": 0, "label": "MISS"}

	# Bullseye — double 25 (counts as a double for checkout)
	if dist <= BULLSEYE_R:
		return {"number": 25, "multiplier": 2, "label": "BULL", "total": 50}

	# Outer bull
	if dist <= OUTER_BULL_R:
		return {"number": 25, "multiplier": 1, "label": "25", "total": 25}

	# Determine which segment (number)
	# Angle 0 is right (3 o'clock). Segment 20 is at 12 o'clock (PI/2).
	# Segments go clockwise (decreasing angle). Offset so segment 0 starts
	# half a segment left of 12 o'clock.
	var offset := PI / 2.0 + SEGMENT_ANGLE / 2.0 - angle
	offset = fmod(offset + TAU, TAU)
	var segment_index := int(offset / SEGMENT_ANGLE) % 20
	var number: int = SEGMENT_ORDER[segment_index]

	# Determine ring (multiplier)
	var multiplier := 1
	var ring_name := ""
	if dist <= TREBLE_INNER_R:
		multiplier = 1
		ring_name = ""
	elif dist <= TREBLE_OUTER_R:
		multiplier = 3
		ring_name = "T"
	elif dist <= DOUBLE_INNER_R:
		multiplier = 1
		ring_name = ""
	elif dist <= DOUBLE_OUTER_R:
		multiplier = 2
		ring_name = "D"

	var total := number * multiplier
	var label := ring_name + str(number) if ring_name != "" else str(number)
	if total == 180:
		label = "T20!"

	return {"number": number, "multiplier": multiplier, "label": label, "total": total}

## Returns the colour for a given segment and ring.
## segment_index: 0-19, ring: "inner_single", "treble", "outer_single", "double"
static func get_segment_colour(segment_index: int, is_scoring_ring: bool) -> Color:
	if segment_index % 2 == 0:
		return COL_RED if is_scoring_ring else COL_BLACK
	else:
		return COL_GREEN if is_scoring_ring else COL_CREAM

## Returns the angle range for a segment (start_angle, end_angle) in radians.
## Segment 0 = number 20 (at the top).
static func get_segment_angles(segment_index: int) -> Array:
	# 20 is at the top (12 o'clock = PI/2). Segments go clockwise (decreasing angle).
	# Segment 0 starts half a segment LEFT of 12 o'clock.
	var base_angle := PI / 2.0 + SEGMENT_ANGLE / 2.0
	var start := base_angle - segment_index * SEGMENT_ANGLE
	var end := start - SEGMENT_ANGLE
	return [start, end]

# ── Wire proximity & bounce-out ──

# Ring wire positions (as fractions of BOARD_RADIUS) — same 6 boundaries used for rendering
const WIRE_RING_RADII: Array[float] = [0.037, 0.094, 0.582, 0.629, 0.953, 1.0]

# Influence zone in normalised units (~3.4mm real-world)
const WIRE_INFLUENCE := 0.02

## Returns 0.0 (far from any wire) to 1.0 (dead centre of a wire).
static func get_wire_proximity(pos: Vector2) -> float:
	var dist := pos.length() / BOARD_RADIUS  # normalised radial distance

	# Find minimum distance to any ring wire
	var min_dist := 999.0
	for wr in WIRE_RING_RADII:
		var d := absf(dist - wr)
		if d < min_dist:
			min_dist = d

	# Spoke wires only matter between outer bull and double outer
	if dist > OUTER_BULL_R and dist <= DOUBLE_OUTER_R:
		var angle := pos.angle()
		var base := PI / 2.0 + SEGMENT_ANGLE / 2.0
		for i in range(20):
			var spoke_angle := base - i * SEGMENT_ANGLE
			# Angular distance, converted to arc length at this radius
			var ang_diff := absf(fmod(angle - spoke_angle + PI + TAU, TAU) - PI)
			var arc_dist := ang_diff * dist  # normalised arc length
			if arc_dist < min_dist:
				min_dist = arc_dist

	# Map through influence zone
	if min_dist >= WIRE_INFLUENCE:
		return 0.0
	return clampf(1.0 - (min_dist / WIRE_INFLUENCE), 0.0, 1.0)

## Roll for a bounce-out. Returns true if the dart bounces off the wire.
static func check_bounce_out(pos: Vector2, dart_tier: int) -> bool:
	var proximity := get_wire_proximity(pos)
	if proximity <= 0.0:
		return false
	var base_rate: float = DartData.get_tier(dart_tier).get("bounce_rate", 0.05)
	# proximity_factor: 0 at edge of influence, 2.0 at wire centre
	var effective_chance := base_rate * 2.0 * proximity
	return randf() < effective_chance
