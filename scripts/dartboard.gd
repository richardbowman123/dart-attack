extends Node3D
class_name Dartboard

const BOARD_THICKNESS := 0.05
const RING_SEGMENTS := 48
const WEDGE_SEGMENTS := 6

var _board_body: StaticBody3D
var _back_wall: StaticBody3D

func _ready() -> void:
	_build_board()

func get_board_body() -> StaticBody3D:
	return _board_body

func get_back_wall() -> StaticBody3D:
	return _back_wall

func _build_board() -> void:
	# Black surround (non-scoring border)
	_add_flat_ring(
		BoardData.BOARD_RADIUS * BoardData.DOUBLE_OUTER_R,
		BoardData.BOARD_RADIUS * BoardData.SURROUND_R,
		BoardData.COL_BOARD_SURROUND, -0.002
	)

	# Bullseye (red centre disc)
	_add_flat_disc(BoardData.BOARD_RADIUS * BoardData.BULLSEYE_R, BoardData.COL_BULLSEYE, 0.005)

	# Outer bull (green ring)
	_add_flat_ring(
		BoardData.BOARD_RADIUS * BoardData.BULLSEYE_R,
		BoardData.BOARD_RADIUS * BoardData.OUTER_BULL_R,
		BoardData.COL_OUTER_BULL, 0.004
	)

	# 20 segments, each with 4 zones
	for i in range(20):
		var angles := BoardData.get_segment_angles(i)
		var a0: float = angles[0]
		var a1: float = angles[1]
		var r := BoardData.BOARD_RADIUS

		# Inner single
		_add_flat_wedge(a0, a1,
			r * BoardData.OUTER_BULL_R, r * BoardData.TREBLE_INNER_R,
			BoardData.get_segment_colour(i, false), 0.001)
		# Treble
		_add_flat_wedge(a0, a1,
			r * BoardData.TREBLE_INNER_R, r * BoardData.TREBLE_OUTER_R,
			BoardData.get_segment_colour(i, true), 0.002)
		# Outer single
		_add_flat_wedge(a0, a1,
			r * BoardData.TREBLE_OUTER_R, r * BoardData.DOUBLE_INNER_R,
			BoardData.get_segment_colour(i, false), 0.001)
		# Double
		_add_flat_wedge(a0, a1,
			r * BoardData.DOUBLE_INNER_R, r * BoardData.DOUBLE_OUTER_R,
			BoardData.get_segment_colour(i, true), 0.002)

	# Shared wire material — dark charcoal with metallic sheen
	var wire_mat := StandardMaterial3D.new()
	wire_mat.albedo_color = BoardData.COL_WIRE
	wire_mat.metallic = 0.75
	wire_mat.roughness = 0.35

	# Wire rings (TorusMesh for each concentric ring)
	var wire_radii := [
		BoardData.BULLSEYE_R, BoardData.OUTER_BULL_R,
		BoardData.TREBLE_INNER_R, BoardData.TREBLE_OUTER_R,
		BoardData.DOUBLE_INNER_R, BoardData.DOUBLE_OUTER_R
	]
	for wr in wire_radii:
		_add_wire_ring(BoardData.BOARD_RADIUS * wr, wire_mat)

	# Wire spokes (CylinderMesh for each radial divider)
	for i in range(20):
		var angles := BoardData.get_segment_angles(i)
		_add_wire_spoke(angles[0], wire_mat)

	# Number labels
	for i in range(20):
		_add_number_label(i)

	# Board collision (the actual scoring surface)
	_board_body = StaticBody3D.new()
	_board_body.name = "BoardBody"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var surround_size := BoardData.BOARD_RADIUS * BoardData.SURROUND_R * 2.2
	box.size = Vector3(surround_size, surround_size, BOARD_THICKNESS)
	col.shape = box
	_board_body.add_child(col)
	_board_body.position = Vector3(0, 0, -BOARD_THICKNESS / 2.0)
	add_child(_board_body)

	# Back wall — catches missed darts so they don't fly off to infinity
	_back_wall = StaticBody3D.new()
	_back_wall.name = "BackWall"
	var wall_col := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(12.0, 12.0, 0.2)
	wall_col.shape = wall_box
	_back_wall.add_child(wall_col)
	_back_wall.position = Vector3(0, 0, -0.3)
	add_child(_back_wall)


# ── Mesh builders using indexed triangles (reliable on mobile renderer) ──

func _add_flat_disc(radius: float, colour: Color, z: float) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	# Centre vertex
	verts.append(Vector3(0, 0, z))
	normals.append(Vector3(0, 0, 1))

	# Ring of outer vertices
	for i in range(RING_SEGMENTS):
		var angle := float(i) / float(RING_SEGMENTS) * TAU
		verts.append(Vector3(cos(angle) * radius, sin(angle) * radius, z))
		normals.append(Vector3(0, 0, 1))

	# Triangles from centre to each edge pair
	for i in range(RING_SEGMENTS):
		var next := (i + 1) % RING_SEGMENTS
		indices.append(0)
		indices.append(i + 1)
		indices.append(next + 1)

	_create_mesh(verts, normals, indices, colour)

func _add_flat_ring(inner_r: float, outer_r: float, colour: Color, z: float) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	for i in range(RING_SEGMENTS):
		var angle := float(i) / float(RING_SEGMENTS) * TAU
		var c := cos(angle)
		var s := sin(angle)
		verts.append(Vector3(c * inner_r, s * inner_r, z))  # inner
		normals.append(Vector3(0, 0, 1))
		verts.append(Vector3(c * outer_r, s * outer_r, z))  # outer
		normals.append(Vector3(0, 0, 1))

	for i in range(RING_SEGMENTS):
		var next := (i + 1) % RING_SEGMENTS
		var i0 := i * 2      # inner current
		var i1 := i * 2 + 1  # outer current
		var i2 := next * 2   # inner next
		var i3 := next * 2 + 1  # outer next
		# Two triangles per quad
		indices.append(i0)
		indices.append(i1)
		indices.append(i2)
		indices.append(i2)
		indices.append(i1)
		indices.append(i3)

	_create_mesh(verts, normals, indices, colour)

func _add_flat_wedge(a_start: float, a_end: float, inner_r: float, outer_r: float, colour: Color, z: float) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var steps := WEDGE_SEGMENTS

	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var angle := lerpf(a_start, a_end, t)
		var c := cos(angle)
		var s := sin(angle)
		verts.append(Vector3(c * inner_r, s * inner_r, z))
		normals.append(Vector3(0, 0, 1))
		verts.append(Vector3(c * outer_r, s * outer_r, z))
		normals.append(Vector3(0, 0, 1))

	for i in range(steps):
		var i0 := i * 2
		var i1 := i * 2 + 1
		var i2 := (i + 1) * 2
		var i3 := (i + 1) * 2 + 1
		indices.append(i0)
		indices.append(i1)
		indices.append(i2)
		indices.append(i2)
		indices.append(i1)
		indices.append(i3)

	_create_mesh(verts, normals, indices, colour)

func _create_mesh(verts: PackedVector3Array, norms: PackedVector3Array, indices: PackedInt32Array, colour: Color) -> void:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)

	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	add_child(inst)

func _add_wire_ring(radius: float, mat: StandardMaterial3D) -> void:
	var wire_thickness := 0.006  # ~1mm real-world wire radius
	var torus := TorusMesh.new()
	# inner_radius = inner edge of the donut, outer_radius = outer edge
	torus.inner_radius = maxf(radius - wire_thickness, 0.001)
	torus.outer_radius = radius + wire_thickness
	torus.rings = 48
	torus.ring_segments = 8

	var inst := MeshInstance3D.new()
	inst.mesh = torus
	inst.material_override = mat
	# Torus is generated in XZ plane — rotate to lie in board's XY plane
	inst.rotation.x = PI / 2.0
	inst.position.z = 0.008
	add_child(inst)

func _add_wire_spoke(angle: float, mat: StandardMaterial3D) -> void:
	var inner_r := BoardData.BOARD_RADIUS * BoardData.OUTER_BULL_R
	var outer_r := BoardData.BOARD_RADIUS * BoardData.DOUBLE_OUTER_R
	var spoke_len := outer_r - inner_r
	var mid_r := (inner_r + outer_r) / 2.0

	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.006
	cyl.bottom_radius = 0.006
	cyl.height = spoke_len

	var inst := MeshInstance3D.new()
	inst.mesh = cyl
	inst.material_override = mat
	# Cylinder axis is Y by default. Rotate around Z so the axis
	# points along the spoke direction in the XY plane.
	inst.rotation.z = angle - PI / 2.0
	# Position at the midpoint of the spoke, just above the board surface
	inst.position = Vector3(cos(angle) * mid_r, sin(angle) * mid_r, 0.008)
	add_child(inst)

func _add_number_label(segment_index: int) -> void:
	var number: int = BoardData.SEGMENT_ORDER[segment_index]
	var angles := BoardData.get_segment_angles(segment_index)
	var mid_angle: float = (angles[0] + angles[1]) / 2.0
	var label_r := BoardData.BOARD_RADIUS * BoardData.NUMBER_RING_R

	var label := Label3D.new()
	label.text = str(number)
	label.font_size = 64
	label.pixel_size = 0.005
	label.modulate = Color.WHITE
	label.outline_modulate = Color.BLACK
	label.outline_size = 12
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector3(cos(mid_angle) * label_r, sin(mid_angle) * label_r, 0.01)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	add_child(label)
