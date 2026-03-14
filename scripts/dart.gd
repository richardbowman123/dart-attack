extends RigidBody3D
class_name Dart

const TIP_LENGTH := 0.04
const SHAFT_LENGTH := 0.06
const SHAFT_RADIUS := 0.004
const FLIGHT_WIDTH := 0.035
const FLIGHT_HEIGHT := 0.03
const FLIGHT_THICKNESS := 0.002
const MISS_TIMEOUT := 4.0  # Seconds before auto-registering a miss

var _stuck := false
var _hit_score := {}
var _tier: int = 0
var _flight_time := 0.0

signal dart_hit(score_data: Dictionary, hit_pos: Vector2)

static func create(tier: int = 0) -> Dart:
	var dart := Dart.new()
	dart._tier = tier
	return dart

func _ready() -> void:
	_build_visual()
	_setup_physics()

func _build_visual() -> void:
	var data := DartData.get_tier(_tier)
	var barrel_r: float = data["barrel_radius"]
	var barrel_len: float = data["barrel_length"]
	var barrel_col: Color = data["barrel_color"]
	var barrel_met: float = data["barrel_metallic"]
	var flight_col: Color = data["flight_color"]

	# === TIP (sharp point, faces -Z toward the board) ===
	var tip_mesh := MeshInstance3D.new()
	var tip_cone := CylinderMesh.new()
	tip_cone.top_radius = 0.0
	tip_cone.bottom_radius = barrel_r * 0.4
	tip_cone.height = TIP_LENGTH
	tip_mesh.mesh = tip_cone
	tip_mesh.rotation.x = PI / 2.0
	tip_mesh.position.z = -(barrel_len + TIP_LENGTH / 2.0)

	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.85, 0.85, 0.88)
	tip_mat.metallic = 1.0
	tip_mat.roughness = 0.2
	tip_mesh.material_override = tip_mat
	add_child(tip_mesh)

	# === BARREL (main body) ===
	var barrel_mesh := MeshInstance3D.new()
	var barrel := CylinderMesh.new()
	barrel.top_radius = barrel_r
	barrel.bottom_radius = barrel_r * 0.7
	barrel.height = barrel_len
	barrel_mesh.mesh = barrel
	barrel_mesh.rotation.x = PI / 2.0
	barrel_mesh.position.z = -(barrel_len / 2.0)

	var barrel_mat := StandardMaterial3D.new()
	barrel_mat.albedo_color = barrel_col
	barrel_mat.metallic = barrel_met
	barrel_mat.roughness = 0.3
	barrel_mesh.material_override = barrel_mat
	add_child(barrel_mesh)

	# === SHAFT (thin connector behind barrel) ===
	var shaft_mesh := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = SHAFT_RADIUS
	shaft.bottom_radius = SHAFT_RADIUS
	shaft.height = SHAFT_LENGTH
	shaft_mesh.mesh = shaft
	shaft_mesh.rotation.x = PI / 2.0
	shaft_mesh.position.z = SHAFT_LENGTH / 2.0

	var shaft_mat := StandardMaterial3D.new()
	shaft_mat.albedo_color = Color(0.2, 0.2, 0.2)
	shaft_mat.metallic = 0.6
	shaft_mesh.material_override = shaft_mat
	add_child(shaft_mesh)

	# === FLIGHTS (two crossed fins at the back) ===
	var flight_mat := StandardMaterial3D.new()
	flight_mat.albedo_color = flight_col
	flight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var fin_v := MeshInstance3D.new()
	var fin_v_mesh := BoxMesh.new()
	fin_v_mesh.size = Vector3(FLIGHT_THICKNESS, FLIGHT_HEIGHT * 2.0, FLIGHT_WIDTH)
	fin_v.mesh = fin_v_mesh
	fin_v.position.z = SHAFT_LENGTH + FLIGHT_WIDTH / 2.0
	fin_v.material_override = flight_mat
	add_child(fin_v)

	var fin_h := MeshInstance3D.new()
	var fin_h_mesh := BoxMesh.new()
	fin_h_mesh.size = Vector3(FLIGHT_HEIGHT * 2.0, FLIGHT_THICKNESS, FLIGHT_WIDTH)
	fin_h.mesh = fin_h_mesh
	fin_h.position.z = SHAFT_LENGTH + FLIGHT_WIDTH / 2.0
	fin_h.material_override = flight_mat
	add_child(fin_h)

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

	# Safety timeout — if the dart has been flying too long, register a miss
	_flight_time += delta
	if _flight_time > MISS_TIMEOUT:
		_register_miss()

func _on_body_entered(body: Node) -> void:
	if _stuck:
		return
	_stuck = true
	freeze = true

	# Score from the tip position, not the body centre.
	# The tip is offset along the dart's -Z axis by (barrel_length + TIP_LENGTH).
	# Using the body centre caused trebles to score as singles because the body
	# is displaced inward from the tip when the dart approaches at an angle.
	var data := DartData.get_tier(_tier)
	var tip_local := Vector3(0, 0, -(data["barrel_length"] + TIP_LENGTH))
	var tip_world := global_transform * tip_local
	var hit_pos_2d := Vector2(tip_world.x, tip_world.y)
	var dist_from_centre := hit_pos_2d.length() / BoardData.BOARD_RADIUS

	if body.name == "BackWall" or dist_from_centre > BoardData.DOUBLE_OUTER_R:
		# Missed the scoring area
		_hit_score = {"number": 0, "multiplier": 0, "label": "Miss", "total": 0}
	else:
		_hit_score = BoardData.get_score(hit_pos_2d)

	dart_hit.emit(_hit_score, hit_pos_2d)

func _register_miss() -> void:
	if _stuck:
		return
	_stuck = true
	freeze = true
	_hit_score = {"number": 0, "multiplier": 0, "label": "Miss", "total": 0}
	dart_hit.emit(_hit_score, Vector2(global_position.x, global_position.y))

func is_stuck() -> bool:
	return _stuck

func get_hit_score() -> Dictionary:
	return _hit_score

func get_tier() -> int:
	return _tier
