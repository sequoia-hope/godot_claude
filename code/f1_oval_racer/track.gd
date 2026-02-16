extends Node3D
## Oval Track Generator
## Creates: oval racing track, stadium seating, pit area

const TRACK_LENGTH: float = 80.0  # Length of straight sections
const TRACK_WIDTH: float = 12.0  # Track width
const CURVE_RADIUS: float = 25.0  # Radius of curved ends
const TRACK_SEGMENTS: int = 24  # Segments per curve

var track_color = Color(0.3, 0.3, 0.35)  # Asphalt gray
var grass_color = Color(0.3, 0.6, 0.2)  # Bright Nintendo green
var kerb_red = Color(0.9, 0.2, 0.2)
var kerb_white = Color(0.95, 0.95, 0.95)
var stadium_color = Color(0.7, 0.7, 0.75)
var seat_colors = [Color(0.9, 0.2, 0.2), Color(0.2, 0.4, 0.9), Color(0.9, 0.8, 0.1), Color(0.2, 0.8, 0.3)]

func _ready() -> void:
	generate_track()

func generate_track() -> void:
	_create_ground()
	_create_track_surface()
	_create_kerbs()
	_create_start_finish_line()
	_create_stadium_seating()
	_create_pit_area()
	print("Track generated!")

func _create_ground() -> void:
	# Large grass plane
	var ground = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	ground.name = "Ground"

	var mat = StandardMaterial3D.new()
	mat.albedo_color = grass_color
	mat.roughness = 0.9
	ground.material_override = mat

	add_child(ground)

	# Ground collision
	var static_body = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(200, 0.1, 200)
	collision.shape = shape
	collision.position.y = -0.05
	static_body.add_child(collision)
	ground.add_child(static_body)

func _create_track_surface() -> void:
	var track_node = Node3D.new()
	track_node.name = "TrackSurface"
	add_child(track_node)

	# Track material
	var mat = StandardMaterial3D.new()
	mat.albedo_color = track_color
	mat.roughness = 0.8

	# Create the oval track using SurfaceTool
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)

	var track_points = _get_oval_track_points(0)  # Center line
	var inner_points = _get_oval_track_points(-TRACK_WIDTH / 2.0)
	var outer_points = _get_oval_track_points(TRACK_WIDTH / 2.0)

	# Create track surface quads
	for i in range(inner_points.size()):
		var next_i = (i + 1) % inner_points.size()

		var v1 = inner_points[i]
		var v2 = outer_points[i]
		var v3 = inner_points[next_i]
		var v4 = outer_points[next_i]

		v1.y = 0.02
		v2.y = 0.02
		v3.y = 0.02
		v4.y = 0.02

		# Two triangles for quad
		st.add_vertex(v1)
		st.add_vertex(v2)
		st.add_vertex(v3)

		st.add_vertex(v2)
		st.add_vertex(v4)
		st.add_vertex(v3)

	var mesh = MeshInstance3D.new()
	mesh.mesh = st.commit()
	track_node.add_child(mesh)

func _get_oval_track_points(offset: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var half_length = TRACK_LENGTH / 2.0
	var radius = CURVE_RADIUS + offset

	# Top straight (going right, +X direction)
	for i in range(10):
		var t = float(i) / 9.0
		var x = lerp(-half_length, half_length, t)
		points.append(Vector3(x, 0, -CURVE_RADIUS - offset))

	# Right curve (semicircle)
	for i in range(TRACK_SEGMENTS + 1):
		var angle = -PI / 2.0 + (float(i) / float(TRACK_SEGMENTS)) * PI
		var x = half_length + cos(angle) * radius
		var z = sin(angle) * radius
		points.append(Vector3(x, 0, z))

	# Bottom straight (going left, -X direction)
	for i in range(10):
		var t = float(i) / 9.0
		var x = lerp(half_length, -half_length, t)
		points.append(Vector3(x, 0, CURVE_RADIUS + offset))

	# Left curve (semicircle)
	for i in range(TRACK_SEGMENTS + 1):
		var angle = PI / 2.0 + (float(i) / float(TRACK_SEGMENTS)) * PI
		var x = -half_length + cos(angle) * radius
		var z = sin(angle) * radius
		points.append(Vector3(x, 0, z))

	return points

func _create_kerbs() -> void:
	# Red and white kerbs on track edges
	var kerbs = Node3D.new()
	kerbs.name = "Kerbs"
	add_child(kerbs)

	var inner_points = _get_oval_track_points(-TRACK_WIDTH / 2.0 - 0.5)
	var outer_points = _get_oval_track_points(TRACK_WIDTH / 2.0 + 0.5)

	# Create kerb strips
	_create_kerb_strip(kerbs, inner_points, true)
	_create_kerb_strip(kerbs, outer_points, false)

func _create_kerb_strip(parent: Node3D, points: Array[Vector3], is_inner: bool) -> void:
	var kerb_width = 1.0
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Alternating red/white material - just use red for simplicity
	var mat = StandardMaterial3D.new()
	mat.albedo_color = kerb_red
	mat.roughness = 0.7
	st.set_material(mat)

	for i in range(points.size()):
		var next_i = (i + 1) % points.size()
		var p1 = points[i]
		var p2 = points[next_i]

		# Direction and perpendicular
		var dir = (p2 - p1).normalized()
		var perp = Vector3(-dir.z, 0, dir.x) * kerb_width * (1.0 if is_inner else -1.0)

		var v1 = p1
		var v2 = p1 + perp
		var v3 = p2
		var v4 = p2 + perp

		v1.y = 0.03
		v2.y = 0.03
		v3.y = 0.03
		v4.y = 0.03

		st.add_vertex(v1)
		st.add_vertex(v2)
		st.add_vertex(v3)

		st.add_vertex(v2)
		st.add_vertex(v4)
		st.add_vertex(v3)

	var mesh = MeshInstance3D.new()
	mesh.mesh = st.commit()
	parent.add_child(mesh)

func _create_start_finish_line() -> void:
	# White checkered start/finish line
	var line = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(TRACK_WIDTH, 0.02, 2.0)
	line.mesh = box
	line.position = Vector3(0, 0.03, -CURVE_RADIUS)
	line.name = "StartFinishLine"

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.roughness = 0.5
	line.material_override = mat

	add_child(line)

func _create_stadium_seating() -> void:
	var stadium = Node3D.new()
	stadium.name = "Stadium"
	add_child(stadium)

	# Stands positioned outside the track, facing inward
	var track_edge = CURVE_RADIUS + TRACK_WIDTH / 2.0 + 3.0  # Just outside kerbs

	# North stands (top straight) - face south (+Z direction)
	_create_straight_stands(stadium, Vector3(0, 0, -track_edge), true, TRACK_LENGTH * 0.7)
	# South stands (bottom straight) - face north (-Z direction)
	_create_straight_stands(stadium, Vector3(0, 0, track_edge), false, TRACK_LENGTH * 0.7)

	# Curved end stands
	_create_curved_stands(stadium, Vector3(TRACK_LENGTH / 2.0, 0, 0), true)  # East end
	_create_curved_stands(stadium, Vector3(-TRACK_LENGTH / 2.0, 0, 0), false)  # West end

func _create_straight_stands(parent: Node3D, base_pos: Vector3, faces_positive_z: bool, length: float) -> void:
	var stands = Node3D.new()
	stands.position = base_pos
	parent.add_child(stands)

	var rows = 5
	var row_height = 1.2
	var row_depth = 1.8
	var seat_width = 2.5
	var num_sections = int(length / seat_width)

	# Direction multiplier: stands tier AWAY from track
	var z_dir = -1.0 if faces_positive_z else 1.0

	for row in range(rows):
		for section in range(num_sections):
			var seat = MeshInstance3D.new()
			var box = BoxMesh.new()
			box.size = Vector3(seat_width - 0.2, row_height * 0.4, row_depth - 0.3)
			seat.mesh = box

			var x = (section - num_sections / 2.0 + 0.5) * seat_width
			var y = row * row_height + row_height * 0.3
			var z = row * row_depth * z_dir  # Tier away from track
			seat.position = Vector3(x, y, z)

			# Colorful seats
			var mat = StandardMaterial3D.new()
			mat.albedo_color = seat_colors[(row + section) % seat_colors.size()]
			mat.roughness = 0.8
			seat.material_override = mat

			stands.add_child(seat)

	# Back wall behind the top row
	var wall = MeshInstance3D.new()
	var wall_box = BoxMesh.new()
	wall_box.size = Vector3(length + 4, rows * row_height + 2, 0.8)
	wall.mesh = wall_box
	var wall_z = (rows * row_depth + 1.0) * z_dir
	wall.position = Vector3(0, rows * row_height / 2.0 + 0.5, wall_z)

	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = stadium_color
	wall_mat.roughness = 0.7
	wall.material_override = wall_mat
	stands.add_child(wall)

func _create_curved_stands(parent: Node3D, center: Vector3, is_east_end: bool) -> void:
	var stands = Node3D.new()
	stands.position = center
	parent.add_child(stands)

	var rows = 4
	var row_height = 1.2
	var base_radius = CURVE_RADIUS + TRACK_WIDTH / 2.0 + 5.0  # Outside the curve
	var sections = 10

	# Angle range for the semicircle
	var start_angle = -PI / 2.0 if is_east_end else PI / 2.0
	var end_angle = PI / 2.0 if is_east_end else PI * 1.5

	for row in range(rows):
		var radius = base_radius + row * 2.0  # Each row further out
		for i in range(sections):
			var t = float(i) / float(sections - 1)
			var angle = lerpf(start_angle, end_angle, t)

			var seat = MeshInstance3D.new()
			var box = BoxMesh.new()
			box.size = Vector3(2.5, row_height * 0.4, 1.5)
			seat.mesh = box

			seat.position = Vector3(cos(angle) * radius, row * row_height + row_height * 0.3, sin(angle) * radius)
			# Face toward track center
			seat.rotation.y = angle + (PI / 2.0 if is_east_end else -PI / 2.0)

			var mat = StandardMaterial3D.new()
			mat.albedo_color = seat_colors[(row + i) % seat_colors.size()]
			mat.roughness = 0.8
			seat.material_override = mat

			stands.add_child(seat)

func _create_pit_area() -> void:
	var pit = Node3D.new()
	pit.name = "PitArea"
	pit.position = Vector3(0, 0, 0)  # Center of oval
	add_child(pit)

	# Pit building
	var building = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(30, 4, 8)
	building.mesh = box
	building.position = Vector3(0, 2, 0)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.9, 0.95)
	mat.roughness = 0.6
	building.material_override = mat
	pit.add_child(building)

	# Pit roof (red)
	var roof = MeshInstance3D.new()
	var roof_box = BoxMesh.new()
	roof_box.size = Vector3(32, 0.5, 10)
	roof.mesh = roof_box
	roof.position = Vector3(0, 4.25, 0)

	var roof_mat = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.8, 0.1, 0.1)
	roof_mat.roughness = 0.5
	roof.material_override = roof_mat
	pit.add_child(roof)

	# Pit lane markers (boxes representing garage bays)
	for i in range(5):
		var bay = MeshInstance3D.new()
		var bay_box = BoxMesh.new()
		bay_box.size = Vector3(5, 0.05, 6)
		bay.mesh = bay_box
		bay.position = Vector3((i - 2) * 6, 0.03, 5)

		var bay_mat = StandardMaterial3D.new()
		bay_mat.albedo_color = Color(0.4, 0.4, 0.45) if i % 2 == 0 else Color(0.5, 0.5, 0.55)
		bay_mat.roughness = 0.7
		bay.material_override = bay_mat
		pit.add_child(bay)

	# Tire stacks (colorful!)
	var tire_positions = [Vector3(-12, 0, -2), Vector3(12, 0, -2), Vector3(-8, 0, 6), Vector3(8, 0, 6)]
	for pos in tire_positions:
		_create_tire_stack(pit, pos)

func _create_tire_stack(parent: Node3D, position: Vector3) -> void:
	var stack = Node3D.new()
	stack.position = position
	parent.add_child(stack)

	var tire_colors = [Color(0.1, 0.1, 0.1), Color(0.15, 0.15, 0.15)]

	for layer in range(3):
		for i in range(3):
			var tire = MeshInstance3D.new()
			var torus = TorusMesh.new()
			torus.inner_radius = 0.2
			torus.outer_radius = 0.5
			tire.mesh = torus

			var angle = float(i) * 2.0 * PI / 3.0 + layer * 0.5
			var radius = 0.4
			tire.position = Vector3(cos(angle) * radius, layer * 0.35 + 0.25, sin(angle) * radius)
			tire.rotation.x = PI / 2.0

			var mat = StandardMaterial3D.new()
			mat.albedo_color = tire_colors[(layer + i) % 2]
			mat.roughness = 0.9
			tire.material_override = mat

			stack.add_child(tire)

func get_start_position() -> Vector3:
	# Start on the top straight, just before the start/finish line
	return Vector3(-5, 0.5, -CURVE_RADIUS)

func get_start_rotation() -> float:
	# Face +X direction (along the track) - in Godot, -PI/2 rotates from -Z to +X
	return -PI / 2.0
