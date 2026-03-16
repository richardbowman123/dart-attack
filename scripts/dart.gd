extends RigidBody3D
class_name Dart

const TIP_LENGTH := 0.12
const SHAFT_LENGTH := 0.06
const SHAFT_RADIUS := 0.004
const FLIGHT_WIDTH := 0.084   # Along shaft (stem to trailing edge)
const FLIGHT_HEIGHT := 0.042  # Perpendicular to shaft (how far fin sticks out)
const FLIGHT_THICKNESS := 0.002
const MISS_TIMEOUT := 4.0

# Barrel detail constants (shared across all tiers — tier data controls the pattern)
const GRIP_RING_EXTRA_R := 0.002
const GRIP_RING_HEIGHT := 0.003   # Base height — tier data multiplies this
const COLLAR_EXTRA_R := 0.003
const COLLAR_HEIGHT := 0.008

var _stuck := false
var _bouncing := false
var _hit_score := {}
var _tier: int = 0
var _character: DartData.Character = DartData.Character.DAI
var _flight_time := 0.0
var visual_scale := 1.0  # Scale visuals without affecting physics
var custom_flight_color = null  # If set, overrides character flight colours (both front/back)
var flight_scale := 1.0  # Scale factor for flights only (e.g. 1.5 for splash screen)
var skip_random_rotation := false  # Set true for decorative darts (splash screen)
var _visual_root: Node3D  # Scaled container for all visual meshes
var _flight_root: Node3D  # Scaled container for flight fins only

signal dart_hit(score_data: Dictionary, hit_pos: Vector2)

static func create(tier: int = 0, character: DartData.Character = DartData.Character.DAI) -> Dart:
	var dart := Dart.new()
	dart._tier = tier
	dart._character = character
	return dart

func _ready() -> void:
	# Create a scaled container for all visual meshes BEFORE building them.
	# RigidBody3D ignores node scale, so we put visuals in a child Node3D
	# and scale that instead. Physics CollisionShape stays on the RigidBody3D.
	_visual_root = Node3D.new()
	_visual_root.scale = Vector3(visual_scale, visual_scale, visual_scale)
	if not skip_random_rotation:
		_visual_root.rotation.z = randf() * TAU  # Random fin orientation per dart
	add_child(_visual_root)
	_build_visual()
	_setup_physics()

# ─────────────────────────────────────────────────────────
#  VISUAL CONSTRUCTION — each section reads tier-specific data
# ─────────────────────────────────────────────────────────

func _build_visual() -> void:
	var data := DartData.get_tier(_tier)
	var barrel_r: float = data["barrel_radius"]
	var barrel_len: float = data["barrel_length"]
	var barrel_col: Color = data["barrel_color"]
	var barrel_met: float = data["barrel_metallic"]
	var barrel_rough: float = data["barrel_roughness"]
	var tip_taper: float = data["tip_taper"]
	var collar_col: Color = data["collar_color"]
	var collar_met: float = data["collar_metallic"]
	var grip_pattern: Array = data["grip_pattern"]
	var flight_sheen: bool = data["flight_sheen"]
	var flight_gold: bool = data["flight_gold_edge"]
	var flight_cols: Dictionary
	if custom_flight_color != null:
		flight_cols = {"front": custom_flight_color, "back": custom_flight_color}
	else:
		flight_cols = DartData.get_flight_colors(_character)

	_build_tip(barrel_r, barrel_len, tip_taper)
	_build_front_collar(barrel_r, barrel_len, collar_col, collar_met)
	_build_barrel(barrel_r, barrel_len, barrel_col, barrel_met, barrel_rough)
	_build_grip_rings(barrel_r, barrel_len, barrel_col, barrel_met, grip_pattern)
	_build_rear_collar(barrel_r, collar_col, collar_met)
	_build_shaft()
	_build_flights(flight_cols, flight_sheen, flight_gold)

# === TIP ===
# Higher tiers get a finer, more tapered point
func _build_tip(barrel_r: float, barrel_len: float, taper: float) -> void:
	var tip_mesh := MeshInstance3D.new()
	var tip_cone := CylinderMesh.new()
	tip_cone.top_radius = 0.0
	tip_cone.bottom_radius = barrel_r * taper * 0.4  # Thin steel needle
	tip_cone.height = TIP_LENGTH
	tip_mesh.mesh = tip_cone
	tip_mesh.rotation.x = PI / 2.0
	tip_mesh.position.z = -(barrel_len + TIP_LENGTH / 2.0)

	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.85, 0.85, 0.88)
	tip_mat.metallic = 1.0
	tip_mat.roughness = 0.2
	tip_mesh.material_override = tip_mat
	_visual_root.add_child(tip_mesh)

# === FRONT COLLAR ===
# Chrome on brass → polished silver → dark gold → bright gold
func _build_front_collar(barrel_r: float, barrel_len: float, col: Color, met: float) -> void:
	var collar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = barrel_r + COLLAR_EXTRA_R
	cyl.bottom_radius = barrel_r + COLLAR_EXTRA_R
	cyl.height = COLLAR_HEIGHT
	collar.mesh = cyl
	collar.rotation.x = PI / 2.0
	collar.position.z = -(barrel_len + COLLAR_HEIGHT / 2.0)
	collar.material_override = _make_metal_mat(col, met, 0.2)
	_visual_root.add_child(collar)

# === BARREL ===
func _build_barrel(barrel_r: float, barrel_len: float, col: Color, met: float, rough: float) -> void:
	var barrel_mesh := MeshInstance3D.new()
	var barrel := CylinderMesh.new()
	barrel.top_radius = barrel_r
	barrel.bottom_radius = barrel_r * 0.7
	barrel.height = barrel_len
	barrel_mesh.mesh = barrel
	barrel_mesh.rotation.x = PI / 2.0
	barrel_mesh.position.z = -(barrel_len / 2.0)
	barrel_mesh.material_override = _make_metal_mat(col, met, rough)
	_visual_root.add_child(barrel_mesh)

# === GRIP RINGS ===
# Pattern varies by tier: uniform, alternating, dense, or clustered
func _build_grip_rings(barrel_r: float, barrel_len: float, col: Color, met: float, pattern: Array) -> void:
	var grip_mat := _make_metal_mat(col.lightened(0.15), minf(met + 0.1, 1.0), 0.2)

	var grip_zone_start := barrel_len * 0.2
	var grip_zone_end := barrel_len * 0.75
	var grip_zone_len := grip_zone_end - grip_zone_start

	for ring_def in pattern:
		var pos_frac: float = ring_def[0]
		var height_mult: float = ring_def[1]
		var ring_z_from_front := grip_zone_start + pos_frac * grip_zone_len

		# Barrel tapers — interpolate radius at this position
		var taper_t := ring_z_from_front / barrel_len
		var local_r := lerpf(barrel_r, barrel_r * 0.7, taper_t)

		var ring := MeshInstance3D.new()
		var ring_cyl := CylinderMesh.new()
		ring_cyl.top_radius = local_r + GRIP_RING_EXTRA_R
		ring_cyl.bottom_radius = local_r + GRIP_RING_EXTRA_R
		ring_cyl.height = GRIP_RING_HEIGHT * height_mult
		ring.mesh = ring_cyl
		ring.rotation.x = PI / 2.0
		ring.position.z = -(barrel_len - ring_z_from_front)
		ring.material_override = grip_mat
		_visual_root.add_child(ring)

# === REAR COLLAR ===
func _build_rear_collar(barrel_r: float, col: Color, met: float) -> void:
	var rear_r := barrel_r * 0.7  # Matches barrel bottom taper
	var collar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = rear_r + COLLAR_EXTRA_R
	cyl.bottom_radius = rear_r + COLLAR_EXTRA_R
	cyl.height = COLLAR_HEIGHT
	collar.mesh = cyl
	collar.rotation.x = PI / 2.0
	collar.position.z = COLLAR_HEIGHT / 2.0
	collar.material_override = _make_metal_mat(col, met, 0.2)
	_visual_root.add_child(collar)

# === SHAFT + STEM ===
func _build_shaft() -> void:
	var shaft_mat := _make_metal_mat(Color(0.2, 0.2, 0.2), 0.6, 0.3)

	var shaft_mesh := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = SHAFT_RADIUS
	shaft.bottom_radius = SHAFT_RADIUS
	shaft.height = SHAFT_LENGTH
	shaft_mesh.mesh = shaft
	shaft_mesh.rotation.x = PI / 2.0
	shaft_mesh.position.z = SHAFT_LENGTH / 2.0
	shaft_mesh.material_override = shaft_mat
	_visual_root.add_child(shaft_mesh)

	# Flight stem — tiny ring where flights slot in
	var stem := MeshInstance3D.new()
	var stem_cyl := CylinderMesh.new()
	stem_cyl.top_radius = SHAFT_RADIUS + 0.002
	stem_cyl.bottom_radius = SHAFT_RADIUS + 0.002
	stem_cyl.height = 0.005
	stem.mesh = stem_cyl
	stem.rotation.x = PI / 2.0
	stem.position.z = SHAFT_LENGTH
	stem.material_override = shaft_mat
	_visual_root.add_child(stem)

# === FLIGHTS ===
# Four individual fins in a cross pattern (N, S, E, W) with standard shield profile.
# Narrow stem point, steep leading edge, broad flat top, wide trailing edge.
# N/S fins use the front country colour, E/W use the back.
func _build_flights(cols: Dictionary, sheen: bool, gold_edge: bool) -> void:
	var front_mat := StandardMaterial3D.new()
	front_mat.albedo_color = cols["front"]
	front_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if sheen:
		front_mat.metallic = 0.2
		front_mat.roughness = 0.4
	else:
		front_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var back_mat := StandardMaterial3D.new()
	back_mat.albedo_color = cols["back"]
	back_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if sheen:
		back_mat.metallic = 0.2
		back_mat.roughness = 0.4
	else:
		back_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var flight_base_z := SHAFT_LENGTH + 0.003
	var flight_mesh := _create_flight_shape()

	# Flight container — allows independent scaling (e.g. 1.5x on splash screen)
	_flight_root = Node3D.new()
	_flight_root.scale = Vector3(flight_scale, flight_scale, flight_scale)
	_visual_root.add_child(_flight_root)

	# North fin (+Y) — front colour
	var n_fin := MeshInstance3D.new()
	n_fin.mesh = flight_mesh
	n_fin.position = Vector3(0, 0, flight_base_z)
	n_fin.material_override = front_mat
	_flight_root.add_child(n_fin)

	# South fin (-Y) — front colour (flip 180 around Z)
	var s_fin := MeshInstance3D.new()
	s_fin.mesh = flight_mesh
	s_fin.position = Vector3(0, 0, flight_base_z)
	s_fin.rotation.z = PI
	s_fin.material_override = front_mat
	_flight_root.add_child(s_fin)

	# East fin (+X) — back colour (rotate -90 around Z)
	var e_fin := MeshInstance3D.new()
	e_fin.mesh = flight_mesh
	e_fin.position = Vector3(0, 0, flight_base_z)
	e_fin.rotation.z = -PI / 2.0
	e_fin.material_override = back_mat
	_flight_root.add_child(e_fin)

	# West fin (-X) — back colour (rotate +90 around Z)
	var w_fin := MeshInstance3D.new()
	w_fin.mesh = flight_mesh
	w_fin.position = Vector3(0, 0, flight_base_z)
	w_fin.rotation.z = PI / 2.0
	w_fin.material_override = back_mat
	_flight_root.add_child(w_fin)

	# Gold trailing edge — premium darts only
	if gold_edge:
		var gold_mat := StandardMaterial3D.new()
		gold_mat.albedo_color = Color(0.85, 0.7, 0.0)
		gold_mat.metallic = 0.9
		gold_mat.roughness = 0.15

		var edge_z := flight_base_z + FLIGHT_WIDTH
		var edge_depth := 0.003
		var trail_h := FLIGHT_HEIGHT * 0.45  # Matches trailing edge height
		_add_flight_piece(
			Vector3(FLIGHT_THICKNESS + 0.001, trail_h, edge_depth),
			Vector3(0, trail_h / 2.0, edge_z + edge_depth / 2.0),
			gold_mat
		)
		_add_flight_piece(
			Vector3(FLIGHT_THICKNESS + 0.001, trail_h, edge_depth),
			Vector3(0, -trail_h / 2.0, edge_z + edge_depth / 2.0),
			gold_mat
		)
		_add_flight_piece(
			Vector3(trail_h, FLIGHT_THICKNESS + 0.001, edge_depth),
			Vector3(trail_h / 2.0, 0, edge_z + edge_depth / 2.0),
			gold_mat
		)
		_add_flight_piece(
			Vector3(trail_h, FLIGHT_THICKNESS + 0.001, edge_depth),
			Vector3(-trail_h / 2.0, 0, edge_z + edge_depth / 2.0),
			gold_mat
		)

# Creates a standard/shield dart flight profile as a custom mesh.
# Leading edge rises at 45 degrees from the shaft axis.
# Broad shield body with wide trailing edge.
func _create_flight_shape() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var H := FLIGHT_HEIGHT
	var W := FLIGHT_WIDTH

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	# 6-vertex shield flight profile
	# Leading edge at exactly 45 deg: rises H in Y over H in Z (tan(45)=1)
	# Then broad shield body with wide trailing edge
	verts.append(Vector3(0, 0, 0))                   # 0: stem point (attaches to shaft)
	verts.append(Vector3(0, H, H))                    # 1: 45-deg leading edge reaches full height
	verts.append(Vector3(0, H, W * 0.70))              # 2: flat top plateau continues
	verts.append(Vector3(0, H * 0.85, W * 0.90))      # 3: upper trailing corner rounds
	verts.append(Vector3(0, H * 0.45, W))              # 4: trailing edge centre (wide)
	verts.append(Vector3(0, 0, W * 0.88))              # 5: bottom trailing corner

	var n := Vector3(1, 0, 0)
	for _i in range(6):
		normals.append(n)

	# Fan triangulation from vertex 0
	indices.append_array([0, 1, 2, 0, 2, 3, 0, 3, 4, 0, 4, 5])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# ─────────────────────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────────────────────

func _add_flight_piece(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.position = pos
	mesh_inst.material_override = mat
	_flight_root.add_child(mesh_inst)

func _make_metal_mat(col: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = metallic
	mat.roughness = roughness
	return mat

# ─────────────────────────────────────────────────────────
#  PHYSICS (unchanged across tiers)
# ─────────────────────────────────────────────────────────

func _setup_physics() -> void:
	var col_shape := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	var data := DartData.get_tier(_tier)
	shape.radius = data["barrel_radius"] * 2.5
	col_shape.shape = shape
	col_shape.position = Vector3(0, 0, -(data["barrel_length"] + TIP_LENGTH))
	add_child(col_shape)

	mass = 0.05
	gravity_scale = 1.0
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _stuck:
		return

	# Orient dart along its velocity vector
	if linear_velocity.length() > 0.5:
		var vel_dir := linear_velocity.normalized()
		look_at(global_position + vel_dir, Vector3.UP)

	# Bouncing darts skip the miss timeout — they'll be cleaned up after 2s
	if _bouncing:
		return

	# Safety timeout — if the dart has been flying too long, register a miss
	_flight_time += delta
	if _flight_time > MISS_TIMEOUT:
		_register_miss()

func _on_body_entered(body: Node) -> void:
	if _stuck or _bouncing:
		return

	# Score from where the dart enters the board surface (barrel front / tip start),
	# NOT the tip end deep inside the board. The player judges the score by where
	# the barrel sits on the board, so we score at the barrel front.
	var data := DartData.get_tier(_tier)
	var tip_local := Vector3(0, 0, -data["barrel_length"])
	var tip_world := global_transform * tip_local
	var hit_pos_2d := Vector2(tip_world.x, tip_world.y)
	var dist_from_centre := hit_pos_2d.length() / BoardData.BOARD_RADIUS

	if body.name == "BackWall" or dist_from_centre > BoardData.DOUBLE_OUTER_R:
		_stuck = true
		freeze = true
		_hit_score = {"number": 0, "multiplier": 0, "label": "Miss", "total": 0}
		dart_hit.emit(_hit_score, hit_pos_2d)
		return

	# Check for bounce-out (wire deflection)
	if BoardData.check_bounce_out(hit_pos_2d, _tier):
		_bouncing = true
		_hit_score = {"number": 0, "multiplier": 0, "label": "BOUNCE OUT", "total": 0, "bounce_out": true}
		dart_hit.emit(_hit_score, hit_pos_2d)
		_do_bounce_out()
		return

	# Normal hit — stick in the board
	_stuck = true
	freeze = true
	_hit_score = BoardData.get_score(hit_pos_2d)
	dart_hit.emit(_hit_score, hit_pos_2d)

func _register_miss() -> void:
	if _stuck:
		return
	_stuck = true
	freeze = true
	_hit_score = {"number": 0, "multiplier": 0, "label": "Miss", "total": 0}
	dart_hit.emit(_hit_score, Vector2(global_position.x, global_position.y))

func _do_bounce_out() -> void:
	# Prevent re-collision with board or back wall
	contact_monitor = false
	# Slightly exaggerated gravity for a satisfying fall
	gravity_scale = 1.5
	# Rebound velocity: bounces back toward player with random scatter
	linear_velocity = Vector3(
		randf_range(-0.3, 0.3),
		randf_range(0.0, 0.8),
		randf_range(2.0, 3.5)
	)
	# After 2 seconds, stop processing (dart will be cleaned up normally)
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(func() -> void:
		_stuck = true
		freeze = true
	)

func is_stuck() -> bool:
	return _stuck

func get_hit_score() -> Dictionary:
	return _hit_score

func get_tier() -> int:
	return _tier
