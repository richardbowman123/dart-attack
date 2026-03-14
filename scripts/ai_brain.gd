extends RefCounted
class_name AIBrain

# AI decision logic — where to aim and how to scatter.

# ── Checkout table ──
# Maps remaining score to [target_number, multiplier] for the finishing dart.
# Only covers finishes that end on a double (or bull).
# The AI works backwards: e.g. on 60, aim D20 (not T20).
# On higher scores it throws at T20 to reduce, then checks out.
static var CHECKOUTS := {
	170: [20, 3],  # T20 (but needs T20 T20 Bull to finish — simplified)
	160: [20, 3],
	140: [20, 3],
	120: [20, 3],
	100: [20, 3],
	80: [20, 3],
	60: [20, 2],   # D20
	58: [18, 2],
	56: [16, 2],
	54: [14, 2],
	52: [12, 2],
	50: [25, 1],   # Bull (counts as double for checkout)
	48: [8, 2],    # D8 — leave nice even number routes
	46: [6, 2],    # S14 then D16, but simplified: aim D6 area
	44: [12, 2],
	42: [10, 2],   # S10 then D16, simplified
	40: [20, 2],   # D20
	38: [19, 2],
	36: [18, 2],
	34: [17, 2],
	32: [16, 2],
	30: [15, 2],
	28: [14, 2],
	26: [13, 2],
	24: [12, 2],
	22: [11, 2],
	20: [10, 2],
	18: [9, 2],
	16: [8, 2],
	14: [7, 2],
	12: [6, 2],
	10: [5, 2],
	8: [4, 2],
	6: [3, 2],
	4: [2, 2],
	2: [1, 2],
}

# Scores where the AI should try to set up a checkout rather than blast T20
const CHECKOUT_RANGE := 170

# ── Aiming ──

## Choose where to aim on the board (returns Vector2 in board coordinates).
## game_mode: "countdown" or "rtc"
## score_remaining: current score (countdown only)
## rtc_target: current target number (rtc only)
static func choose_aim(game_mode: String, score_remaining: int, rtc_target: int) -> Vector2:
	if game_mode == "rtc":
		return _aim_rtc(rtc_target)
	else:
		return _aim_countdown(score_remaining)

## Aim for countdown mode — T20 for scoring, checkout table when in range
static func _aim_countdown(remaining: int) -> Vector2:
	# Check if we have a direct checkout
	if remaining in CHECKOUTS:
		var checkout: Array = CHECKOUTS[remaining]
		var number: int = checkout[0]
		var multiplier: int = checkout[1]
		return _get_ring_position(number, multiplier)

	# Even numbers <= 40: go for the double directly
	if remaining <= 40 and remaining % 2 == 0:
		return _get_ring_position(remaining / 2, 2)

	# Odd numbers <= 41: hit a single 1 to make it even, then double
	# (simplified — just aim for single of the right setup number)
	if remaining <= 41 and remaining % 2 == 1:
		# Aim for single 1 to leave an even number
		return _get_ring_position(1, 1)

	# High score — blast treble 20
	return _get_ring_position(20, 3)

## Aim for round the clock — centre of the fat outer single area.
## Aiming between treble and double gives the biggest target area and
## lets natural scatter push darts off the board occasionally (realistic).
static func _aim_rtc(target: int) -> Vector2:
	if target > 20:
		# Aiming for bullseye
		return Vector2.ZERO

	# Find the segment index for this number
	var seg_index := -1
	for i in range(BoardData.SEGMENT_ORDER.size()):
		if BoardData.SEGMENT_ORDER[i] == target:
			seg_index = i
			break

	if seg_index < 0:
		return Vector2.ZERO

	# Aim at the centre of the outer single (between treble and double rings)
	var angles: Array = BoardData.get_segment_angles(seg_index)
	var mid_angle: float = (angles[0] + angles[1]) / 2.0
	var mid_radius: float = BoardData.BOARD_RADIUS * (BoardData.TREBLE_OUTER_R + BoardData.DOUBLE_INNER_R) / 2.0

	return Vector2(cos(mid_angle), sin(mid_angle)) * mid_radius

## Get the board position for a specific number and ring
static func _get_ring_position(number: int, multiplier: int) -> Vector2:
	# Bull
	if number == 25 or number == 50:
		return Vector2.ZERO

	# Find segment index
	var seg_index := -1
	for i in range(BoardData.SEGMENT_ORDER.size()):
		if BoardData.SEGMENT_ORDER[i] == number:
			seg_index = i
			break

	if seg_index < 0:
		return Vector2.ZERO

	var angles: Array = BoardData.get_segment_angles(seg_index)
	var mid_angle: float = (angles[0] + angles[1]) / 2.0

	# Pick the right ring radius
	var radius: float
	match multiplier:
		2:  # Double ring
			radius = BoardData.BOARD_RADIUS * (BoardData.DOUBLE_INNER_R + BoardData.DOUBLE_OUTER_R) / 2.0
		3:  # Treble ring
			radius = BoardData.BOARD_RADIUS * (BoardData.TREBLE_INNER_R + BoardData.TREBLE_OUTER_R) / 2.0
		_:  # Single — aim at fat outer single (between treble and double)
			radius = BoardData.BOARD_RADIUS * (BoardData.TREBLE_OUTER_R + BoardData.DOUBLE_INNER_R) / 2.0

	return Vector2(cos(mid_angle), sin(mid_angle)) * radius

# ── Scatter ──

## Apply Gaussian scatter around the aim point using Box-Muller transform.
## scatter_radius: from OpponentData (higher = worse accuracy)
## double_hit_pct: chance of hitting the intended double (when aiming at one)
## aim_multiplier: what ring the AI is aiming at (2 = double)
static func apply_scatter(aim: Vector2, scatter_radius: float, double_hit_pct: float, aim_multiplier: int) -> Vector2:
	# For doubles: sometimes override scatter to guarantee a hit
	# This prevents even good players from never checking out
	if aim_multiplier == 2 and randf() < double_hit_pct:
		# Tight scatter — dart lands very close to aim
		var tight := scatter_radius * 0.15
		return aim + _gaussian_offset(tight)

	# Normal Gaussian scatter
	return aim + _gaussian_offset(scatter_radius)

## Generate a 2D offset using Box-Muller transform for realistic dart grouping.
## Most darts land near the aim; occasional wild ones fly out.
static func _gaussian_offset(radius: float) -> Vector2:
	# Box-Muller: convert two uniform randoms to Gaussian
	var u1 := maxf(randf(), 0.0001)  # Avoid log(0)
	var u2 := randf()
	var mag := radius * sqrt(-2.0 * log(u1))
	var angle := TAU * u2
	return Vector2(cos(angle), sin(angle)) * mag
